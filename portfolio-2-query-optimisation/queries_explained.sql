-- Test A: lookup by sending account

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM transactions WHERE from_account_id = 4242;

-- Test B: failed transactions in the last 30 days

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM transactions
WHERE status = 'FAILED' AND transaction_date >= NOW() - INTERVAL '30 days';

-- Test C: account statement (as in Q1)

EXPLAIN (ANALYZE, BUFFERS)
SELECT t.transaction_id, t.reference, t.amount, t.status, t.transaction_date
FROM transactions t
WHERE t.from_account_id = 1 OR t.to_account_id = 1
ORDER BY t.transaction_date DESC;