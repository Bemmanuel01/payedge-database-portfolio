- ============================================================
-- DEMO 3 - Savepoint
--
-- This demonstrates partial rollback. Work done before a savepoint is kept, and work after it is undone,
-- so one failed step does not destroy the whole transaction.
--
-- OBJECTIVE
-- In Demo 2 an error forced me to throw away the whole transaction. Here I wanted to show how a savepoint
-- lets me undo only the failed step and keep the earlier work.
--
-- SETUP
-- One psql window (Terminal A). Starting balance: account 1 = 200000.
--
-- NB: One statement fails on purpose, so I ran the blocks one at a time.
-- ============================================================

BEGIN;

-- Step 1: a valid withdrawal of 5000.
UPDATE accounts SET balance = balance - 5000 WHERE account_id = 1;

INSERT INTO transactions
(from_account_id, transaction_type, amount, status, reference, narration)
VALUES
    (1, 'WITHDRAWAL', 5000, 'SUCCESS', 'DEMO-SP-001', 'Demo: first withdrawal');

-- I marked a point I could return to.
SAVEPOINT after_first_withdrawal;
-- OBSERVATION: my prompt was still =*# (transaction open).

-- Step 2: an impossible withdrawal of 999999.
UPDATE accounts SET balance = balance - 999999 WHERE account_id = 1;
-- OBSERVATION: An ERROR occurred and new row for relation "accounts" violates check constraint "chk_balance".
-- The DETAIL line showed the failing row with a balance of -804999.00, which is 195000 minus 999999.
-- This confirmed that my first withdrawal was still in effect. My prompt changed to =!# (transaction failed).

-- I undo only the failed step.
ROLLBACK TO SAVEPOINT after_first_withdrawal;
-- OBSERVATION: my prompt returned to =*#. The transaction was usable again, and my first withdrawal was still there.

-- I recorded the rejected attempt, as a real bank would.
INSERT INTO transactions
(from_account_id, transaction_type, amount, status, reference, narration)
VALUES
    (1, 'WITHDRAWAL', 999999, 'FAILED', 'DEMO-SP-002', 'Rejected: insufficient funds');

COMMIT;

-- ---- Verification ----
SELECT account_id, balance
FROM accounts
WHERE account_id = 1;
-- OBSERVATION: 195000.00 (200000 minus the first withdrawal of 5000).

SELECT reference, transaction_type, amount, status, narration
FROM transactions
WHERE reference LIKE 'DEMO-%'
ORDER BY transaction_id;
-- OBSERVATION: three rows: DEMO-COMMIT-001 (SUCCESS), DEMO-SP-001 (SUCCESS) and DEMO-SP-002 (FAILED).

-- ============================================================
-- CONCLUSION:
-- A full ROLLBACK (Demo 2) discards everything. ROLLBACK TO SAVEPOINT discards only the work after the savepoint,
-- so the first withdrawal survived and the failed attempt could still be recorded.
-- The prompt change from =!# back to =*# showed the transaction being rescued from its failed state.
-- ============================================================