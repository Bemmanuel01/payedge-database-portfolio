-- ============================================================
-- DEMO 1 - Atomic Commit
--
-- DEMONSTRATES: The demo demonstrates Atomicity, durability, and isolation (uncommitted changes are invisible to other sessions).
--
-- OBJECTIVE: I wanted to show atomicity, isolation and durability with a real transfer of 50,000 naira from account 1 (Adaeze, savings) to account 3 (Emeka, savings).
--
-- SETUP
-- I opened two PowerShell windows and connected each to payedge_db with psql. I call them Terminal A and Terminal B.
-- I used psql instead of IntelliJ consoles because IntelliJ can share one database session between consoles,
-- which would have hidden the isolation behavior. The starting balances I recorded were account 1 = 250000 and account 3 = 75000.
--
-- NB: This file is a record of what I ran. The two terminals must be used live, so I did not run it as one script.
-- ============================================================

-- Terminal A: I checked the starting balances
SELECT account_id, account_number, balance
FROM accounts
WHERE account_id IN (1, 3, 4)
ORDER BY account_id;

-- Terminal A: I started the transfer
BEGIN;

-- I locked both rows, always in account order, so nobody else could change them while I worked.
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

-- Inside my open transaction I checked the new balances.
SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;


-- Terminal B: while A was still open
SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;

-- OBSERVATION: 250000 and 75000, the OLD values. Terminal B could not see my uncommitted changes in Terminal A. This is isolation.

-- Terminal A: I made the changes permanent
COMMIT;

-- Terminal B: after the commit
SELECT account_id, balance
FROM accounts
WHERE account_id IN (1, 3)
ORDER BY account_id;
-- OBSERVATION: 200000 and 125000. The committed change became visible.

SELECT SUM(balance) AS total
FROM accounts
WHERE account_id IN (1, 3);

-- OBSERVATION: 325000.00, the same as the original 250000 + 75000 (No money was created or lost).

-- ============================================================
-- CONCLUSION:
-- 1. Atomicity: the debit, the credit and the transaction record succeeded together. The total stayed at 325000.
-- 2. Isolation: Terminal B saw only the old balances until I committed.
-- 3. Durability: the committed transfer, DEMO-COMMIT-001, remained in the database. It was still there after my computer shut down unexpectedly between demos.
-- ============================================================