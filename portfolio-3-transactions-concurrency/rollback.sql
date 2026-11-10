-- ============================================================
-- Demo 2 - Rollback

-- DEMONSTRATES: Atomicity and consistency
--              (A constraint violation cancels the whole transaction).

-- REQUIRES: One psql session (Terminal A).
-- STARTING BALANCES (after Demo 1): account 1 = 200000,
--                                   account 3 = 125000, account 4 = 12000.
-- Part 2b contains a statement that fails on purpose. Run each block one at a time.
-- ============================================================

-- ============================================================
-- Part 2a: Manual rollback
-- ============================================================
BEGIN;

UPDATE accounts SET balance = balance - 30000 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 30000 WHERE account_id = 3;

-- Inside the transaction: expected 170000 and 155000
SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;

ROLLBACK;

-- After the rollback: expected 200000 and 125000 (nothing changed)
SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;

-- ============================================================
-- Part 2b: Rollback caused by an error
-- Account 4 holds only 12000, so taking 50000 out of it must fail.
-- ============================================================
BEGIN;

UPDATE accounts SET balance = balance + 50000 WHERE account_id = 3;
UPDATE accounts SET balance = balance - 50000 WHERE account_id = 4;

SELECT balance FROM accounts WHERE account_id = 3;

-- The only way out of an aborted transaction is to end it
ROLLBACK;
-- Expected: account 3 back to 125000 (the earlier credit was undone together with the failed debit) and account 4 still 12000

SELECT account_id, balance
FROM accounts
WHERE account_id IN (3, 4)
ORDER BY account_id;