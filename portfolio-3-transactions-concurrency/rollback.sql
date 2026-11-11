-- ============================================================
-- Demo 2 - Rollback



-- ============================================================
-- DEMO 2: Rollback
-- This demonstrates Atomicity and consistency (A constraint violation cancels the whole transaction).
-- ============================================================
--
-- OBJECTIVE
-- I wanted to show that a transaction is all-or-nothing, first with a rollback I chose to run, and then with a rollback forced by a failed constraint.
--
-- SETUP
-- I used one psql window (Terminal A). Starting balances after Demo 1: account 1 = 200000, account 3 = 125000, account 4 = 12000.
--
-- NB: Part 2b contains a statement that fails on purpose, so I ran each block one at a time and did not run the file as one script.
-- ============================================================

-- ============================================================
-- PART 2a: A manual rollback
-- ============================================================
BEGIN;

UPDATE accounts SET balance = balance - 30000 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 30000 WHERE account_id = 3;

SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;
-- OBSERVATION: The query inside the transaction shows 170000 and 155000.

ROLLBACK;

SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;
-- OBSERVATION:  After the rollback,the transaction shows 200000 and 125000. Both changes were undone as one unit.

-- ============================================================
-- PART 2b: A rollback caused by an error, Account 4 holds only 12000, so taking 50000 out of it must fail.
-- ============================================================

BEGIN;

-- Step 1: a credit of 50000 to account 3. This succeeded.
UPDATE accounts SET balance = balance + 50000 WHERE account_id = 3;

-- Step 2: a debit of 50000 from account 4. This is designed to fail.
UPDATE accounts SET balance = balance - 50000 WHERE account_id = 4;
-- OBSERVATION: This gives an ERROR, new row for relation "accounts" violates check constraint "chk_balance". My prompt changed from =*# to =!#,
-- meaning PostgreSQL had marked my transaction as failed.

SELECT balance FROM accounts WHERE account_id = 3;
-- OBSERVATION: This gives an ERROR as current transaction is aborted, commands ignored until end of transaction block.

ROLLBACK;

SELECT account_id, balance
FROM accounts
WHERE account_id IN (3, 4)
ORDER BY account_id;
-- OBSERVATION: account 3 = 125000 and account 4 = 12000.

-- ============================================================
-- CONCLUSION:
-- 1. Atomicity: the credit to account 3 had already succeeded, but it was undone when the debit from account 4 failed.
-- 2. Consistency: the chk_balance constraint stopped the database from ever holding a negative balance.
-- 3. PostgreSQL is strict: after an error, every command is refused until the transaction ends. This is why savepoints (Demo 3) are useful.
-- ============================================================