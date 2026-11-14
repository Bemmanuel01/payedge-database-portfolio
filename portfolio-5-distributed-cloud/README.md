# Portfolio 5: Distributed and Cloud Database

**Case study:** PayEdge Digital Bank
**Tools:** MongoDB Atlas (free M0 cluster), PostgreSQL 17, IntelliJ IDEA
---

## 1. Objective

This portfolio looks at PayEdge as a distributed, cloud-hosted system. It covers:

- **Deployment:** the Atlas cluster that hosts the MongoDB data
- **Replication:** how the cluster's three nodes keep copies of the data
- **Sharding:** which shard key suits the `transactions` collection, judged by measuring my own data
- **Partitioning:** a working PostgreSQL partitioned table with a measured comparison
- **Availability and consistency:** how PayEdge's components trade one against the other

I separate what I built and observed from what I designed or discussed, because the free tier cannot do everything a production system would.

---

## 2. Repository Contents

| File | Purpose |
|---|---|
| `partitioning.sql` | PostgreSQL partitioning: tables, row counts, pruning and timing, as a first-person record |
| `shard_key_analysis.js` | Aggregations that measure three candidate shard keys, with my observations |
| `cloud_architecture.md` | Replication, sharding, availability, consistency and cloud deployment |
| `distributed_screenshots/` | Contains screenshots and output of query ran and evidence |
| `Benjamin_Emmanuel_README.md` | Portfolio 5 (Distributed Cloud) Report. |

---

## 3. Deployment

| Item | Observed |
|---|---|
| Cluster | `Cluster0`, FREE (M0), status ACTIVE |
| Provider and region | AWS, Paris (eu-west-3), one region |
| Type | Replica set with 3 nodes |
| Server version | 8.0.37 |
| Storage | 135.74 MB of 512 MB used (27%) |
| Backups and auto-scaling | Both OFF |
| Security | A database user with a password, and an IP access list. Credentials are not stored in the repository |

---

## 4. Replication

The Atlas Metrics page shows the three members of the replica set: **one primary** (`shard-00-02`) and **two secondaries** (`shard-00-00` and `shard-00-01`).

- All writes go to the primary, which sends them to the secondaries.
- A write that requests a majority is acknowledged when 2 of 3 members have it.
- If the primary fails, the secondaries elect a new one. Three members tolerate one failure.
- The hostnames contain `shard-00` because Atlas names replica set members that way. The cluster is **not sharded**.

The free tier does not allow failover, so I did not observe an election, and I did not measure replication lag. The description above is how a replica set works, not a result from my cluster.

---

## 5. Sharding: shard-key analysis

The free tier cannot be sharded. I measured three candidate keys on my 800 transactions to judge them.

| Candidate | Observed | Verdict |
|---|---|---|
| `customerId` | 5 values: 226, 212, 127, 123, 112 | Too few values in my sample, and one customer's documents share a key value and cannot be split |
| `fromAccount` | 7 accounts plus a `null` group of 110 (the deposits) | The `null` group would form one chunk, and received-money queries do not use this field |
| `timestamp` (by month) | 157, 274, 266, 103 | Always increasing, so all new writes go to the newest range (a hot shard) |

**Design:** a compound key `{ customerId: 1, timestamp: 1 }`, so a query for one customer in a date range goes to one shard, writes are spread across customers, and a busy customer's history can split by time. I did not run the `sh.shardCollection` command, because the cluster cannot shard.

---

## 6. Partitioning in PostgreSQL

I created `transactions_partitioned`, partitioned by `transaction_date` into five quarterly partitions plus a default partition, and copied in the 500,013 rows of `transactions`.

| Check | Result |
|---|---|
| Data range | 2025-11-08 to 2026-11-10, covered by the partition boundaries |
| Rows per partition | 72,978 / 122,813 / 124,377 / 126,129 / 53,716, and 0 in the default partition |
| Reconciliation | 500,013 rows in both tables, a difference of 0 |

(The 500,013 is the 500,010 rows I seeded in Portfolio 2 plus the three `DEMO-` rows from Portfolio 3.)

**Partition pruning.** The question was the number and total of transactions in Q3 2026. Each query was run twice, and the second run is recorded.

| Table | Plan | Pages touched | Execution time |
|---|---|---|---|
| Original | Parallel Seq Scan, 2 workers, whole table | 6,667 | 76.1 ms |
| Partitioned | Seq Scan on `transactions_p2026_q3` only | 1,682 | 25.1 ms |

- Only one of the six partitions was scanned, because the query filtered on the partition key. A query with no date filter scanned all six.
- That is about 4 times fewer pages and about 3 times faster.
- The original table still read 919 pages from outside PostgreSQL's memory on its second run, while the partition was served entirely from memory. I therefore do not credit all of the time difference to pruning.
- **Trade-off:** the primary key had to include `transaction_date`, so `reference` is no longer unique across the whole table.
- This is partitioning on **one server**, not sharding.

---

## 7. Availability and consistency

| Component | Choice |
|---|---|
| PostgreSQL ledger (transfers, balances, loans) | Consistency first |
| MongoDB profiles and history | Tunable: primary reads and majority writes for anything involving money, secondary reads for reporting and history |

Read preference and write concern are described in `cloud_architecture.md` as design decisions. **I did not demonstrate them.**

---

## 8. Evidence

Screenshots are stored in `screenshots/`.

| File | Shows |
|---|---|
| `1b_atlas_clusters_overview.png` | Cluster0: FREE, running, AWS Paris, 3-node replica set, version 8.0.37 |
| `1a_atlas_project_overview.png` | Tier, data size, backups OFF, auto-scaling OFF |
| `2_replica_set_members.png` | One primary and two secondaries |
| `3_network_access.png` | The IP access list (addresses blurred) |
| `4_database_access.png` | The database user and its role |
| `5_shardkey_customerid.png` | Transactions per `customerId` |
| `6_shardkey_fromaccount.png` | Transactions per `fromAccount`, including the `null` group |
| `7_shardkey_timestamp.png` | Transactions per month |
| `8_partition_row_counts.png` | Rows in each partition |
| `8a_partition_date_range.png` | Earliest and latest transaction dates |
| `8b_row_reconciliation.png` | 500,013, 500,013 and a difference of 0 |
| `9_partition_pruning.png` | The partitioned query touching only the Q3 partition |
| `10_no_partitioning.png` | The same query on the original table |
| `11_all_partitions-plan.png` | The query with no date filter scanning all six partitions |

---

## 9. Short Technical Reflection

**Design choices:** I analysed shard keys by measuring my own data before choosing one, so the recommendation rests on counts and not on guesses. I built partitioning in PostgreSQL because I could not shard on the free tier, and the same idea (split by a key and skip what a query does not need) could still be measured. I kept the document clear about what I built, what I designed and what I only discussed.

**Challenges faced:**

- *Limitation on the free tier:* It has no sharding, no backups and no failover testing, so parts of this portfolio had to be design and analysis, not demonstration.
- *A query error:* My first partition-count query failed with `column "partition" does not exist`, because an `ORDER BY` can use an output alias only on its own and not inside an expression. I repeated the expression instead.
- *A fair comparison:* My first run on the original table read 1,047 pages from outside PostgreSQL's memory and took 155.7 ms, which overstated the gap. I reran both queries and compared the second runs (76.1 ms against 25.1 ms), and I leaned on the page counts, which do not depend on caching.
- *A row-count mismatch:* The tables held 500,013 rows, not the 500,010 I expected. I traced the extra three to the `DEMO-` rows from Portfolio 3 and confirmed the partitioned copy matched the original exactly.
- *Reading the cluster correctly.* The host names contain `shard-00`, which looks like sharding, so I checked and confirmed the cluster is a single replica set.
- *My own security settings.* Reviewing the Atlas pages, I found my database user is broader than needed and the IP list has accumulated several addresses, so I recorded both as things to tighten.

**Lessons learned:**

1. A good shard key needs many distinct values, an even spread, and a match with how the data is read. A key that only increases (like a timestamp) creates a hot shard.
2. Partitioning and sharding use the same idea, but partitioning stays on one server and sharding spreads across servers.
3. Constraints change under partitioning: a unique key must include the partition key.
4. Honest evidence matters. A cold run and a warm run cannot be compared, and a timing difference should not be credited to one cause alone.
5. Availability and consistency are chosen per component. A bank can keep its ledger consistent and still serve history from secondaries.

---

## 10. References and AI Use Declaration

**References**

- PostgreSQL Global Development Group. *PostgreSQL 17 Documentation*: Table Partitioning. https://www.postgresql.org/docs/17/
- MongoDB, Inc. *MongoDB Manual*: Replication, Sharding, Read Preference and Write Concern. https://www.mongodb.com/docs/manual/
- MongoDB, Inc. *MongoDB Atlas Documentation*: Free Cluster Limitations. https://www.mongodb.com/docs/atlas/
- Brewer, E. (2000). Towards robust distributed systems (the CAP theorem).

**AI Use Declaration**

- *Tool used:* Claude (Anthropic).
- *Used for:* explaining replication, sharding, partitioning and the CAP trade-off, drafting the SQL and aggregation commands, and structuring this report.
- *How the output was verified:* I ran every query and aggregation myself, in PostgreSQL 17 and MongoDB Atlas. The counts, plans, page numbers, timings and cluster details in this report come from my own screenshots. I corrected an error in one query, repeated the timings for a fair comparison.
