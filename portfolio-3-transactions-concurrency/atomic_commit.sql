-- ============================================================
-- DEMONSTRATES: Atomicity, durability, and isolation
--               (uncommitted changes are invisible to other sessions).
--
-- REQUIRES: Two psql sessions, labelled Terminal A and Terminal B.
-- STARTING BALANCES: account 1 = 250000, account 3 = 75000.
-- Run each of the block in the terminal named in the comment, in order.
-- ============================================================

-- Terminal A: baseline
SELECT account_id, account_number, balance
FROM accounts
WHERE account_id IN (1, 3, 4)
ORDER BY account_id;

-- Terminal A: begin the transfer of 50,000 from account 1 to account 3

BEGIN;
SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id
    FOR UPDATE;

UPDATE accounts SET balance = balance - 50000, updated_at = NOW() WHERE account_id = 1;
UPDATE accounts SET balance = balance + 50000, updated_at = NOW() WHERE account_id = 3;

INSERT INTO transactions
(from_account_id, to_account_id, transaction_type, amount, status, reference, narration)
VALUES
    (1, 3, 'TRANSFER', 50000, 'SUCCESS', 'DEMO-COMMIT-001', 'Demo: committed transfer');


SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;



-- Terminal B:

SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;

-- Terminal A: make the changes permanent
COMMIT;

-- ---- Terminal B: after A has committed

SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;

SELECT SUM(balance) AS total
FROM accounts
WHERE account_id IN (1, 3);