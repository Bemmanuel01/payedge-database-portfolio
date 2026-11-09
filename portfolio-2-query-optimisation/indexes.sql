-- INDEX

-- Speeds up lookups and joins on the sending account
CREATE INDEX idx_txn_from_account ON transactions (from_account_id);

-- Speeds up lookups and joins on the receiving account
CREATE INDEX idx_txn_to_account ON transactions (to_account_id);

-- Speeds up status plus date-range filters
CREATE INDEX idx_txn_status_date ON transactions (status, transaction_date DESC);

-- PostgreSQL does not index foreign key columns automatically
CREATE INDEX idx_accounts_customer ON accounts (customer_id);

ANALYZE;

-- Index list
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename IN ('transactions', 'accounts')
ORDER BY tablename, indexname;

SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'transactions'
ORDER BY pg_relation_size(indexrelid) DESC;

SELECT pg_size_pretty(pg_relation_size('transactions'))       AS table_size,
       pg_size_pretty(pg_total_relation_size('transactions')) AS total_size_with_indexes;

-- per index sizes
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'transactions'
ORDER BY pg_relation_size(indexrelid) DESC;