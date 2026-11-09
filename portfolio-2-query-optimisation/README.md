# Portfolio 2: Query Processing and Optimisation

# Portfolio 2: Query Processing and Optimisation

**Course:** MIT 8103 Advanced Database Systems, MIVA Open University
**Case study:** PayEdge Digital Bank
**Tools:** PostgreSQL 17, IntelliJ IDEA (Database Tools), pgAdmin 4, `EXPLAIN (ANALYZE, BUFFERS)`

---

## 1. Objective

This portfolio demonstrates how the PostgreSQL query planner executes queries, how to read an execution plan, and how indexing changes the plan and the performance. It covers:

- writing analytical SQL queries on the PayEdge database (joins, a CTE, a window function, and a subquery)
- measuring a **baseline** with no supporting indexes
- creating indexes chosen for the actual query patterns
- measuring the **same queries again** and comparing plans, timings, buffer reads and storage cost

---

## 2. Repository Contents

| File | Purpose |
|---|---|
| `seed_volume.sql` | Generates test volume: 5,000 customers, 5,000 accounts, 500,000 transactions. For performance testing only. |
| `queries.sql` | Five business queries (Q1 to Q5) |
| `explain_queries.sql` | Three `EXPLAIN (ANALYZE, BUFFERS)` tests (A, B, C), run before and after indexing |
| `explain-before.txt` | Execution plans with no extra indexes (baseline) |
| `indexes.sql` | The index definitions |
| `explain-after.txt` | Execution plans after indexing |
| `analysis.md` | Full performance analysis and interpretation |
| `screenshots/` | Evidence (listed in section 7) |
| `README.md` | This report |

---

## 3. Implementation

### 3.1 Why test data was needed

The original sample data has only 10 transactions. On a table that small, PostgreSQL correctly chooses a sequential scan, so an index could never show a benefit. `seed_volume.sql` was written to add realistic volume.

| Table | Rows before | Rows after seeding |
|---|---|---|
| `customers` | 5 | 5,005 |
| `accounts` | 7 | 5,007 |
| `transactions` | 10 | 500,010 |

How the seed data was designed:

- **Customers:** Nigerian-style names, `@gmail.com` emails, real network prefixes (0802, 0803, 0806 and others) with non-sequential phone suffixes, and BVNs starting with `22`.
- **Accounts:** one per seeded customer, with the account number equal to the phone number without the leading 0, following the PayEdge rule.
- **Transactions:** account IDs are read from the `accounts` table, so foreign keys always resolve. The sender and receiver always differ. About 80% are `SUCCESS`, 10% `PENDING` and 10% `FAILED`, spread across the last 365 days.
- `ANALYZE` was run afterwards so the planner had accurate statistics.

The `transactions` table measured **52 MB**.

### 3.2 Business queries (`queries.sql`)

| Query | Business question | Technique |
|---|---|---|
| Q1 | Statement for one account | Joins, `OR` filter, `ORDER BY` |
| Q2 | Failed transactions in the last 30 days with the customer affected | Three-table join, status and date filter |
| Q3 | Monthly summary of successful transactions | CTE and aggregation |
| Q4 | Top 3 balances within each account type | Window function (`RANK() OVER (PARTITION BY ...)`) |
| Q5 | Accounts with above-average balance | Subquery |

Observed timings in IntelliJ before indexing: Q1 took about 2.2 s and Q2 about 0.98 s. These include fetching rows, so they are only a rough guide. The official measurements are the `EXPLAIN ANALYZE` figures below.

### 3.3 Method

1. Confirmed that only the automatic indexes existed (primary keys and UNIQUE columns).
2. Ran the three tests with `EXPLAIN (ANALYZE, BUFFERS)` and recorded the baseline. Each test was run twice, and the second run was recorded to avoid the cold-cache effect.
3. Created the indexes and ran `ANALYZE`.
4. Ran the **same three tests unchanged** and recorded the new plans.
5. Measured the storage cost of the indexes.

### 3.4 The three tests

```sql
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
```

### 3.5 Indexes created (`indexes.sql`)

```sql
CREATE INDEX idx_txn_from_account  ON transactions (from_account_id);
CREATE INDEX idx_txn_to_account    ON transactions (to_account_id);
CREATE INDEX idx_txn_status_date   ON transactions (status, transaction_date DESC);
CREATE INDEX idx_accounts_customer ON accounts (customer_id);
ANALYZE;
```

Each index was chosen for a specific query pattern: account lookups and joins (A, C), and status-by-date reporting (B). PostgreSQL does not index foreign key columns automatically, so `accounts.customer_id` was indexed for joins.

---

## 4. How to Reproduce

Run these steps in order on a database that already has `schema.sql` and `data.sql` loaded.

1. Run `seed_volume.sql` **once only**. A second run fails on the UNIQUE constraints.
2. Run `queries.sql` to view the business results.
3. Run `explain_queries.sql` and save the output as `explain-before.txt`. **Do this before creating the indexes.**
4. Run `indexes.sql`.
5. Run `explain_queries.sql` again, unchanged, and save the output as `explain-after.txt`.

---

## 5. Results

| Test | Plan before | Plan after | Time before | Time after | Speed-up |
|---|---|---|---|---|---|
| A: lookup by sender | Parallel Seq Scan | Bitmap Heap Scan (`idx_txn_from_account`) | 113.7 ms | 1.8 ms | about 62x |
| B: failed, last 30 days | Parallel Seq Scan | Bitmap Heap Scan (`idx_txn_status_date`) | 140.2 ms | 4.1 ms | about 34x |
| C: account statement | Parallel Seq Scan + Sort | BitmapOr of both account indexes + Sort | 503.8 ms | 0.4 ms | about 1,250x |

| Test | Pages read before | Pages read after |
|---|---|---|
| A | 6,667 | 93 |
| B | 6,667 | 3,121 |
| C | 6,739 | 192 |

| Storage | Before | After |
|---|---|---|
| Table plus indexes | 89 MB | 111 MB (+22 MB) |

The full interpretation is in `analysis.md`. In short:

- **Every test changed from a full table scan to an index-based plan**, and the planner's row estimates stayed close to the real counts.
- **Test C improved most.** The `OR` condition is answered by combining both account indexes (`BitmapOr`).
- **Test B improved least.** It still read about half the table's pages, because the matching rows are scattered across the table. An index helps in proportion to how selective the query is.
- **Indexes have a cost.** The three new indexes added 22 MB, and each one must be maintained on every write. The write overhead was not benchmarked, so it is noted as a known trade-off only.

---

## 6. Testing Notes

- Every read came from memory (`shared hit`, no `read`), so all timings are warm-cache figures. A cold cache would likely widen the gap.
- Test B returned 4,160 rows before and 4,154 after. The filter uses `NOW()`, which moved between runs, so a few rows at the 30-day boundary dropped out. The data was not changed.
- Timings from `EXPLAIN ANALYZE` measure query execution only. IntelliJ's displayed times also include fetching rows, so the two are not directly comparable.

---

## 7. Evidence

Screenshots are stored in `screenshots/`.

| File | Shows |
|---|---|
| `01-seed-customers.png` | Format check on the seeded customers |
| `02-seed-accounts.png` | Account count with unique account numbers |
| `03-seed-transactions.png` | Transaction count, distinct references, no self-transfers |
| `04-table-size.png` | `transactions` table size and total size |
| `05-query-q1.png` to `09-query-q5.png` | The five business queries and their results |
| `10-indexes-before.png` | Indexes present before the experiment |
| `11-explain-before-A.png` to `13-explain-before-C.png` | Baseline execution plans |
| `14-indexes-after.png` | Indexes after creation |
| `15-index-sizes.png` | Size of each index |
| `16-explain-after-A.png` to `18-explain-after-C.png` | Execution plans after indexing |

Plan text is also saved in `explain-before.txt` and `explain-after.txt`.

---

## 8. Short Technical Reflection

**Design choices.** I generated realistic data instead of copying random values, because the plans I was measuring depend on how data is distributed. I chose indexes to match specific query patterns (account lookups and status-by-date reports) and not to cover every column, because each index costs storage and slows writes. I measured with `EXPLAIN (ANALYZE, BUFFERS)` and kept the tests identical before and after, so the comparison was fair.

**Challenges faced.**

- *No visible benefit on small data.* With 10 transactions, an index could not help, so I had to build a 500,000-row dataset before there was anything to measure.
- *Unique, realistic values.* The seed data had to satisfy several UNIQUE constraints (email, phone, BVN, account number, reference) while still looking real. I learned that deriving values from a counter with a multiplier guarantees uniqueness, which `random()` cannot.
- *Two different timings.* IntelliJ showed Q1 at about 2.2 s, but `EXPLAIN ANALYZE` reported about 504 ms for the same work. The difference is row fetching and caching, which taught me to use one measurement method consistently.
- *Not every test improved equally.* Test B gained the least, and I had to read the plan (3,121 pages read) to understand why. The index avoided examining rows but could not avoid visiting the many pages where the matching rows were scattered.

**Lessons learned.**

1. An execution plan is evidence, and the node type, row estimates, and buffer counts explain why a query is fast or slow.
2. Indexes help in proportion to query selectivity and data layout, and they carry a storage cost (22 MB here).
3. Accurate statistics matter. Running `ANALYZE` after bulk loading is what allowed the planner to choose well.
4. A fair experiment needs a clean baseline. Capturing the plans before creating any index was essential.

---

## 9. References and AI Use Declaration

**References**

- PostgreSQL Global Development Group. *PostgreSQL 17 Documentation*: Using EXPLAIN, Indexes, and Planner Statistics. https://www.postgresql.org/docs/17/
- Elmasri, R. and Navathe, S. (2016). *Fundamentals of Database Systems*. Pearson.

**AI Use Declaration**

- *Tool used:* Claude (Anthropic).
- *Used for:* explaining how to read execution plans, drafting the seed-data and index SQL, and structuring this report and the analysis.
- *How the output was verified:* every statement was run in PostgreSQL 17 by me. The execution plans, timings, row counts and sizes in this report come from my own runs, and the screenshots are from my own machine. I reviewed the interpretation in `analysis.md` and can explain it.
