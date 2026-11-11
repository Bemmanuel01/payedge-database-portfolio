-- ============================================================
-- DEMO 5: Isolation levels
-- ============================================================
--
-- OBJECTIVE
-- In Demo 1, there was isolation at PostgreSQL's default level. Here I wanted to compare READ COMMITTED with REPEATABLE READ,
-- using the same sequence of events at each level, to see what a transaction can and cannot see.

-- SETUP
-- Two psql windows (Terminal A and Terminal B) and account 2, with a starting balance of 1500000.
-- In every part, Terminal A reads the balance inside a transaction, then Terminal B changes the same
-- row, and then I observe what Terminal A sees.
--
-- NB: The demo needs two live sessions, so I did not run it as one script. I reset the balance to 1500000 after each part.
-- ============================================================

SHOW default_transaction_isolation;
-- OBSERVATION: read committed. I did not change the default.

SELECT account_id, balance FROM accounts WHERE account_id = 2;
-- OUTPUT: 1500000.00

-- ============================================================
-- PART 5a: READ COMMITTED (the default)
-- ============================================================

-- Terminal A:
BEGIN;
SELECT balance FROM accounts WHERE account_id = 2;
-- OUTPUT: 1500000.00

-- Terminal B (no BEGIN, so it commits straight away):
UPDATE accounts SET balance = balance + 100000 WHERE account_id = 2;

-- Terminal A, still inside the same transaction:
SELECT balance FROM accounts WHERE account_id = 2;
-- OBSERVATION: 1600000.00. The same query returned a different value inside one transaction. This is a non-repeatable read.
COMMIT;

-- Reset the balance to 1500000.00.
UPDATE accounts SET balance = 1500000.00 WHERE account_id = 2;

-- ============================================================
-- PART 5b: REPEATABLE READ
-- ============================================================

-- Terminal A:
BEGIN ISOLATION LEVEL REPEATABLE READ;
SHOW transaction_isolation;
-- OBSERVATION: repeatable read.
SELECT balance FROM accounts WHERE account_id = 2;
-- OUTPUT: 1500000.00

-- Terminal B:
UPDATE accounts SET balance = balance + 100000 WHERE account_id = 2;

-- Terminal A, still inside the same transaction:
SELECT balance FROM accounts WHERE account_id = 2;
-- OBSERVATION: 1500000.00. Terminal A kept seeing the snapshot it took at its first query, even though Terminal B had changed the row.
COMMIT;

SELECT balance FROM accounts WHERE account_id = 2;
-- OBSERVATION: 1600000.00. After my transaction ended, I saw the current committed value.

-- I reset the balance to 1500000.00.
UPDATE accounts SET balance = 1500000.00 WHERE account_id = 2;

-- ============================================================
-- PART 5c: REPEATABLE READ refuses a conflicting write
-- ============================================================

-- Terminal A:
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT balance FROM accounts WHERE account_id = 2;
-- OUTPUT: 1500000.00

-- Terminal B changed the same row and committed:
--   UPDATE accounts SET balance = balance + 100000 WHERE account_id = 2;

-- Terminal A tried to change the row from its old value:
UPDATE accounts SET balance = balance - 50000 WHERE account_id = 2;
-- OBSERVATION: An ERROR occurred, could not serialize access due to concurrent update.
-- My prompt changed from =*# to =!#, meaning the transaction had failed.
ROLLBACK;

-- I reset the balance. The final value was 1500000.00.
UPDATE accounts SET balance = 1500000.00 WHERE account_id = 2;

-- ============================================================
-- CONCLUSION:
-- 1. READ COMMITTED (5a): each statement sees whatever was committed at that moment, so the same row read twice can return different values.
-- 2. REPEATABLE READ (5b): the transaction works from a snapshot, so the same row read twice returns the same value.
-- 3. REPEATABLE READ (5c): PostgreSQL will not let a transaction overwrite a row that changed after its snapshot.
--    It raises a serialization error instead of silently losing the other session's update, as happened in Demo 4a. The application is
--    expected to catch this error and retry the whole transaction.
-- 4. PostgreSQL does this with MVCC: each transaction sees a version of the data, readers do not block writers, and locks matter only when
--    two sessions write the same row.
-- ============================================================