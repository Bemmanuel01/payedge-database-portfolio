-- ============================================================
-- Horizontal partitioning in PostgreSQL
-- ============================================================
--
-- OBJECTIVE:
-- Sharding splits a large table across several servers. I cannot shard on a single local PostgreSQL server,
-- but I can show the same core idea on one server: split the transactions table by a key (the date) and
-- let the engine skip the pieces a query does not need. This is called partitioning, and the engine's skipping is called partition pruning.
--
-- SETUP
-- Database payedge_db on PostgreSQL 17. The source table is transactions, with 500,013 rows (the 500,010 rows I seeded in Portfolio 2,
-- with the 3 DEMO rows from Portfolio 3).
--
-- NB:- This is a record of what I ran. I ran each block on its own in the IntelliJ console and did not run the file as one script, because the
-- INSERT copies 500,013 rows and cannot be repeated without clearing the partitioned table first.
-- ============================================================

-- ------------------------------------------------------------
-- Step 1: Partition date range of the data
-- ------------------------------------------------------------
SELECT MIN(transaction_date) AS earliest, MAX(transaction_date) AS latest, COUNT(*) AS total
FROM transactions;
-- OBSERVATION: earliest 2025-11-08 22:16:55, latest 2026-11-10 13:55:19, total 500013.
--              The earliest date falls inside the 2025 Q4 partition (1 Oct 2025 to 1 Jan 2026) and the latest inside the 2026 Q4 partition (1 Oct 2026 to 1 Jan 2027),
--              so the partition boundaries cover the whole data range and the default partition stays empty.
--              Total: 500013.

-- ------------------------------------------------------------
-- Step 2: Partitioned table
-- ------------------------------------------------------------

CREATE TABLE transactions_partitioned (
    transaction_id INT NOT NULL,
    from_account_id INT,
    to_account_id INT,
    transaction_type VARCHAR(20) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    reference VARCHAR(50)   NOT NULL,
    narration VARCHAR(255),
    transaction_date TIMESTAMP NOT NULL,
    PRIMARY KEY (transaction_id, transaction_date),
    CONSTRAINT chk_part_amount CHECK (amount > 0)
) PARTITION BY RANGE (transaction_date);

-- DESIGN NOTE: PostgreSQL only allows a unique constraint on a
-- partitioned table if it includes the partition key. The primary key
-- therefore had to include transaction_date, and I could not keep a
-- UNIQUE constraint on reference alone. Uniqueness of reference is no
-- longer enforced across the whole table. I also did not add foreign
-- keys to the partitioned copy.

-- ------------------------------------------------------------
-- Step 3: Quarterly partitions and a default partition
-- ------------------------------------------------------------
CREATE TABLE transactions_p2025_q4 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');
CREATE TABLE transactions_p2026_q1 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');
CREATE TABLE transactions_p2026_q2 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-04-01') TO ('2026-07-01');
CREATE TABLE transactions_p2026_q3 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-07-01') TO ('2026-10-01');
CREATE TABLE transactions_p2026_q4 PARTITION OF transactions_partitioned
    FOR VALUES FROM ('2026-10-01') TO ('2027-01-01');
-- Any row outside those ranges goes here instead of failing the insert.
CREATE TABLE transactions_p_default PARTITION OF transactions_partitioned DEFAULT;

-- ------------------------------------------------------------
-- Step 4: Insert data and refreshed the statistics
-- ------------------------------------------------------------
INSERT INTO transactions_partitioned
(transaction_id, from_account_id, to_account_id, transaction_type, amount,
 status, reference, narration, transaction_date)
SELECT transaction_id, from_account_id, to_account_id, transaction_type, amount,
       status, reference, narration, transaction_date
FROM transactions;

ANALYZE transactions_partitioned;

-- ------------------------------------------------------------
-- Step 5: Partitioned Transaction Rows
-- ------------------------------------------------------------
SELECT tableoid::regclass AS partition, COUNT(*) AS row_count
FROM transactions_partitioned
GROUP BY tableoid
ORDER BY tableoid::regclass::text;
-- OBSERVATION:
--   transactions_p2025_q4 = 72,978
--   transactions_p2026_q1 = 122,813
--   transactions_p2026_q2 = 124,377
--   transactions_p2026_q3 = 126,129
--   transactions_p2026_q4 = 53,716   (the smallest, because the data stops in early November)
--   transactions_p_default not listed, so 0 rows which add up to 500,013.


SELECT (SELECT COUNT(*) FROM transactions)             AS original_rows,
       (SELECT COUNT(*) FROM transactions_partitioned) AS partitioned_rows,
       (SELECT COUNT(*) FROM transactions)
           - (SELECT COUNT(*) FROM transactions_partitioned) AS difference;
-- OBSERVATION:
-- original rows = 500013, partition_rows = 500013 and difference = 0.

-- ------------------------------------------------------------
-- Step 6: Partition pruning
-- The question: how many transactions, and what total, in Q3 2026?
-- I ran each query twice and recorded the second run, because the first run of the original table also had to read pages that were not yet in
-- PostgreSQL's memory showed read=1047 and took 155.7 ms.
-- ------------------------------------------------------------

-- On the original, unpartitioned table:
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(amount)
FROM transactions
WHERE transaction_date >= '2026-07-01' AND transaction_date < '2026-10-01';
-- OBSERVATION (second run):
--   1. Parallel Seq Scan on transactions, with 2 workers.
--   2. Buffers: shared hit=5748, read=919, so 6,667 pages in total.
--   3. Rows removed by the filter: 124,628 per process (3 processes), which is 373,884 rows discarded.
--   4. The 126,129 rows kept plus 373,884 discarded is 500,013, so it read the whole table.
--   5. Execution Time: 76.088 ms.

-- On the partitioned table:
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*), SUM(amount)
FROM transactions_partitioned
WHERE transaction_date >= '2026-07-01' AND transaction_date < '2026-10-01';
-- OBSERVATION (second run):
--   1. Seq Scan on transactions_p2026_q3 ONLY. The other four partitions and the default partition do not appear in the plan.
--   2. Buffers: shared hit=1682, with no reads.
--   3. Execution Time: 25.091 ms.

-- NB: With no date filter, nothing can be pruned.

EXPLAIN SELECT COUNT(*) FROM transactions_partitioned;
-- OBSERVATION: a Parallel Append over all six partitions, including the default one.

-- ============================================================
-- CONCLUSION:
--      1. Pages touched: 6,667 on the original table against 1,682 on the single partition, which is about 4 times fewer. That matches the Q3 partition
--         holding about a quarter of the rows (126,129 of 500,013).
--      2. Time: 76.1 ms against 25.1 ms, about 3 times faster. The first run of the partitioned query took 21.6 ms, so repeated timings vary by a few
--         milliseconds, and I treat the figure as approximate.
--      3. Caching: the original table still showed 919 pages read on its second run, while the partition was served entirely from memory. I think part
--         of the time difference comes from the smaller partition fitting in memory more easily, so I do not credit all of it to pruning alone.
--      4. The partition key matters: the pruning only happened because the query filtered on transaction_date. The query with no date filter scanned every partition.
--      5. Limits: this is partitioning on one server, not sharding. The pieces are not spread across machines.
--         The trade-off I met was that the primary key had to include the partition key, so reference is no longer unique across the whole table.
-- ============================================================
