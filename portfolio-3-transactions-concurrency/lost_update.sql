-- ============================================================
-- DEMO 4: The lost update and two fixes
--
-- OBJECTIVE
-- I wanted to reproduce a real concurrency problem, the lost update and then show two control mechanisms that prevent it.
--
-- SETUP
-- Two psql windows (Terminal A and Terminal B), and account 2, which the earlier demos had not touched. Starting balance: 1500000.
-- In every part, customer A withdraws 100000 and customer B withdraws 200000 at the same time, so the correct final balance is 1200000.
--
-- NB: The demo needs two live terminal sessions, so I did not run it as one script.
-- ============================================================

SELECT account_id, balance FROM accounts WHERE account_id = 2;
-- OUTPUT: 1500000.00

-- ============================================================
-- PART 1(a):Each session reads the balance, calculates the new value itself and writes it back as a fixed number.
-- ============================================================

-- Terminal A:
BEGIN;
SELECT balance FROM accounts WHERE account_id = 2;
-- OUTPUT: 1500000

-- Terminal B, before Terminal A wrote anything:
BEGIN;
SELECT balance FROM accounts WHERE account_id = 2;
-- OUTPUT: 1500000

-- Terminal A:
UPDATE accounts SET balance = 1400000 WHERE account_id = 2;
COMMIT;

-- Terminal B, still believing the balance was 1500000:
UPDATE accounts SET balance = 1300000 WHERE account_id = 2;
COMMIT;

SELECT account_id, balance FROM accounts WHERE account_id = 2;
-- OBSERVATION: 1300000.00 in both terminals. The correct balance was 1200000, so 100000 disappeared. PostgreSQL raised no error
-- Terminal B silently overwrote Terminal A's withdrawal.

-- I reset the balance before the next part.
UPDATE accounts SET balance = 1500000.00 WHERE account_id = 2;

-- ============================================================
-- PART 1(b): FIX 1, an atomic relative update instead of writing a number I had calculated,
-- I let the database subtract from the current value of the row.
-- ============================================================

-- Terminal A:
BEGIN;
UPDATE accounts SET balance = balance - 100000 WHERE account_id = 2;
-- I did not commit yet.

-- Terminal B:
BEGIN;
UPDATE accounts SET balance = balance - 200000 WHERE account_id = 2;
-- OBSERVATION: Terminal B hung. It was waiting for the row lock that Terminal A held.

-- Terminal A:
COMMIT;
-- OBSERVATION: Terminal B finished immediately after my commit.

-- Terminal B:
COMMIT;
SELECT account_id, balance FROM accounts WHERE account_id = 2;
-- OBSERVATION: 1200000.00, the correct balance

UPDATE accounts SET balance = 1500000.00 WHERE account_id = 2;

-- ============================================================
-- PART 1(c): FIX 2, pessimistic locking with SELECT ... FOR UPDATE
-- I locked the row at the moment I read it, which matters when the application must read a balance before deciding what to write.
-- ============================================================

-- Terminal A:
BEGIN;
SELECT balance FROM accounts WHERE account_id = 2 FOR UPDATE;

-- Terminal B:
BEGIN;
SELECT balance FROM accounts WHERE account_id = 2 FOR UPDATE;
-- OBSERVATION: Terminal B hung, waiting for Terminal A's lock.

-- Terminal A:
UPDATE accounts SET balance = 1400000 WHERE account_id = 2;
COMMIT;

-- Terminal B was released.
-- OBSERVATION: it read 1400000, my committed result, not the stale 1500000.

UPDATE accounts SET balance = 1400000 - 200000 WHERE account_id = 2;
COMMIT;
SELECT account_id, balance FROM accounts WHERE account_id = 2;
-- OBSERVATION: 1200000.00, the correct balance.

UPDATE accounts SET balance = 1500000.00 WHERE account_id = 2;

-- ============================================================
-- CONCLUSION:
-- The lost update happened because both sessions calculated a value from a stale read and wrote it as a fixed number,
-- so the second write replaced the first without any error. Both fixes work through row-level locking,
-- which forced Terminal B to take its turn:  1(b): balance = balance - x is applied to the latest committed row.
-- 1(c): FOR UPDATE makes the second session wait before it reads, so it calculates from the correct number.
-- Lock waits are the cost. Terminal B was delayed until Terminal A was committed.
-- ============================================================