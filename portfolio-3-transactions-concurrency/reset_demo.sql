-- ============================================================
-- RESET SCRIPT FOR THE DEMO

-- PURPOSE: Restores the seven sample accounts to their original
--          balances and removes only the demo transactions.
--
-- WHEN TO RUN: The demo is meant to run only when balances don't match
--              the values expected, or before repeating a demo.
--              If a transaction is still open, run ROLLBACK; first.
--
-- SAFEPOINT: The demo does not touch the 500,000 seeded transactions
--            (they use references starting with SEED-).
--
-- RUN IN psql:
--   /i 'C:/Users/DELL/Desktop/Java Project/advanced-database-portfolio/portfolio-3-transactions-concurrency/reset_demo.sql'
-- ============================================================

UPDATE accounts SET balance =  250000.00 WHERE account_id = 1;
UPDATE accounts SET balance = 1500000.00 WHERE account_id = 2;
UPDATE accounts SET balance =   75000.00 WHERE account_id = 3;
UPDATE accounts SET balance =   12000.00 WHERE account_id = 4;
UPDATE accounts SET balance =  890000.00 WHERE account_id = 5;
UPDATE accounts SET balance =  340000.00 WHERE account_id = 6;
UPDATE accounts SET balance = 2000000.00 WHERE account_id = 7;

DELETE FROM transactions WHERE reference LIKE 'DEMO-%';

-- Check the result (expected: 250000, 75000, 12000)
SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3, 4)
ORDER BY account_id;