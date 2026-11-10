- ============================================================
-- DEMO 3 - Savepoint
--
-- DEMONSTRATES: Partial rollback. Work done before a savepoint is
--               kept, and work after it is undone, so one failed
--               step does not destroy the whole transaction.
--
-- REQUIRES: One psql session (Terminal A).
-- STARTING BALANCE (after Demos 1 and 2): account 1 = 200000.
-- ============================================================

BEGIN;
UPDATE accounts SET balance = balance - 5000 WHERE account_id = 1;

INSERT INTO transactions
(from_account_id, transaction_type, amount, status, reference, narration)
VALUES
    (1, 'WITHDRAWAL', 5000, 'SUCCESS', 'DEMO-SP-001', 'Demo: first withdrawal');

SAVEPOINT after_first_withdrawal;

-- (EXPECTED ERROR: violates check constraint "chk_balance")
UPDATE accounts SET balance = balance - 999999 WHERE account_id = 1;
ROLLBACK TO SAVEPOINT after_first_withdrawal;

INSERT INTO transactions
(from_account_id, transaction_type, amount, status, reference, narration)
VALUES
    (1, 'WITHDRAWAL', 999999, 'FAILED', 'DEMO-SP-002', 'Rejected: insufficient funds');

COMMIT;

-- ---- Verification ----
SELECT account_id, balance
FROM accounts
WHERE account_id = 1;

SELECT reference, transaction_type, amount, status, narration
FROM transactions
WHERE reference LIKE 'DEMO-%'
ORDER BY transaction_id;