-- ============================================================
--  Reset script for the Portfolio 3 demos
-- ============================================================
--
-- PURPOSE
-- The demos in this portfolio change account balances and add demo transactions. I wrote this script to restore the seven sample
-- accounts to their original balances and to remove only my demo transactions, so that I can repeat a demo from a known state.
--
-- WHEN TO RUN
-- I run it only when my balances no longer match the values the demo expects, or before I repeat a demo. If a transaction is still
-- open, I run ROLLBACK; first.
--
-- WHAT IT DOES
-- It does not touch the 500,000 seeded transactions from Portfolio 2 (their references start with SEED-), the 5,000
-- seeded accounts, or any customer data. It deletes only rows whose reference starts with DEMO-.
--
-- HOW I RUN IT (inside psql, using a backslash and forward slashes
-- in the path):
--   \i 'C:/Users/DELL/Desktop/Java Project/advanced-database-portfolio/portfolio-3-transactions-concurrency/reset_demo.sql'
-- ============================================================

-- I wrapped the reset in one transaction so it is all-or-nothing.

BEGIN;

UPDATE accounts SET balance =  250000.00, updated_at = NOW() WHERE account_id = 1;
UPDATE accounts SET balance = 1500000.00, updated_at = NOW() WHERE account_id = 2;
UPDATE accounts SET balance =   75000.00, updated_at = NOW() WHERE account_id = 3;
UPDATE accounts SET balance =   12000.00, updated_at = NOW() WHERE account_id = 4;
UPDATE accounts SET balance =  890000.00, updated_at = NOW() WHERE account_id = 5;
UPDATE accounts SET balance =  340000.00, updated_at = NOW() WHERE account_id = 6;
UPDATE accounts SET balance = 2000000.00, updated_at = NOW() WHERE account_id = 7;

DELETE FROM transactions WHERE reference LIKE 'DEMO-%';

COMMIT;

-- I check the result.
-- Expected balances: account 1 = 250000, account 2 = 1500000,
--                    account 3 = 75000,  account 4 = 12000.

SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 2, 3, 4)
ORDER BY account_id;

-- Expected: 0 demo transactions remain.
SELECT COUNT(*) AS demo_rows_left
FROM transactions
WHERE reference LIKE 'DEMO-%';