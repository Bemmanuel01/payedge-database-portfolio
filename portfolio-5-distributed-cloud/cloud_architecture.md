# Distributed and Cloud Architecture for PayEdge Digital Bank

**Portfolio 5: Distributed and Cloud Database Exercise**

This document describes how PayEdge's data is deployed and how it would be replicated, partitioned, sharded and kept available and consistent. It separates what I **built and observed** from what I **designed or discussed**, because my free-tier cluster cannot do everything a production system would.

---

## 1. Deployment
| Item | Observed |
|---|---|
| Cloud database | MongoDB Atlas, cluster `Cluster0` |
| Tier | FREE (M0) |
| Provider and region | AWS, Paris (eu-west-3), one region |
| Cluster type | Replica set with 3 nodes |
| Server version | 8.0.37 |
| Storage | 135.74 MB used of 512 MB (27%) |
| Connections | 2 of a 500 limit at the time of the screenshot |
| Backups | OFF |
| Auto-scaling | OFF |
| Relational database | PostgreSQL 17, one local server (`payedge_db`) |

The 135.74 MB is a figure for the whole cluster. It most likely includes the `sample_mflix` sample database that Atlas offers, so it does not measure the PayEdge data alone.

---

## 2. Replication

### My Observation:

The Atlas Metrics page lists three members. One is the **primary** (marked P) and two are **secondaries** (marked S):

| Host | Role |
|---|---|
| `...shard-00-00...:27017` | Secondary |
| `...shard-00-01...:27017` | Secondary |
| `...shard-00-02...:27017` | Primary |

The hostnames contain `shard-00` because Atlas uses that naming for replica set members. This cluster is **not sharded**: it is one replica set.

### How it works:

- All writes go to the primary, which records them and sends them to the secondaries.
- A write that asks for a **majority** is acknowledged once 2 of the 3 members have it.
- If the primary fails, the secondaries hold an **election** and one of them becomes the new primary.
- Three members tolerate **one** failure. With one member down, the other two still form a majority. With two down, the cluster can no longer elect a primary or accept writes.

### My Limitation:

The free tier does not let me trigger a failover, so I did not observe an election. I also did not measure replication lag. The statements above describe how a replica set works and are not results from my cluster.

My PostgreSQL server is a single local instance with no replica. If it stopped, the ledger would be unavailable. In production I would add a standby server fed by streaming replication, with automatic failover. Synchronous replication would guarantee that no committed transfer is lost on failover, at the cost of slower commits. Asynchronous replication is faster but can lose the last few transactions. I have not built this.

---

## 3. Partitioning (built) and sharding (designed)

Both split a large collection by a key. **Partitioning** splits it into pieces on one server. **Sharding** spreads the pieces across several servers.

### Partitioning in PostgreSQL (built and measured)

I created a copy of the transactions table partitioned by `transaction_date`, with five quarterly partitions and a default partition, and copied in all 500,013 rows. The copy reconciled with the original (500,013, 500,013 and a difference of 0).

| Query: transactions in Q3 2026 | Plan | Pages touched | Execution time |
|---|---|---|---|
| Original table | Parallel Seq Scan over the whole table | 6,667 | 76.1 ms |
| Partitioned table | Seq Scan on `transactions_p2026_q3` only | 1,682 | 25.1 ms |

PostgreSQL skipped the other partitions before reading anything (partition pruning). A query with no date filter scanned all six partitions. That is about 4 times fewer pages and about 3 times faster. I do not credit all of the time difference to pruning, because the original table still read 919 pages from outside PostgreSQL's memory on its second run while the partition came entirely from memory.

**Trade-off I met:** a unique constraint on a partitioned table must include the partition key, so the primary key became `(transaction_id, transaction_date)` and `reference` is no longer unique across the whole table.

### Sharding in MongoDB (designed, not run)

The free tier cannot be sharded, so I analysed three candidate shard keys on my 800 transactions:

| Candidate | Observed | Problem |
|---|---|---|
| `customerId` | 5 values: 226, 212, 127, 123, 112 | Too few values in my sample, and one customer's documents share a key value and cannot be split. Customers with two accounts carry about twice the traffic |
| `fromAccount` | 7 accounts plus a `null` group of 110 (the deposits) | The `null` group would form one chunk. Queries about money received do not use this field |
| `timestamp` | 4 months: 157, 274, 266, 103 | Always increasing, so every new write goes to the newest range (a hot shard) |

**My design:** a compound key `{ customerId: 1, timestamp: 1 }`.

```javascript
sh.enableSharding("payedge")
sh.shardCollection("payedge.transactions", { customerId: 1, timestamp: 1 })
```

- PayEdge's main read is "one customer's transactions in a date range", so a query that names the customer is sent to one shard.
- Writes are spread across many customers.
- `timestamp` lets a very busy customer's history split into smaller chunks.

A hashed `customerId` would also spread customers evenly and still target single-customer queries, but it cannot split one busy customer's documents. Queries across all customers by date go to every shard under either design. This analysis measured the spread of my data and not real shard performance.

---

## 4. Availability and consistency

The CAP theorem says that during a network partition a distributed system must choose between consistency and availability.

| PayEdge component | Choice | Reason |
|---|---|---|
| Ledger in PostgreSQL (transfers, balances, loans) | **Consistency first (CP)** | A wrong balance is worse than a brief outage. Portfolio 3 showed the constraints, row locks and isolation that protect it |
| Customer profiles and transaction history in MongoDB | **Tunable** | Reads can lean towards availability for history and dashboards |

### MongoDB settings that control the trade-off (discussed, not demonstrated)

| Setting | Effect |
|---|---|
| Read from the **primary** (the default) | Always sees the latest committed data |
| Read from a **secondary** | Can answer when the primary is busy, but may return slightly stale data because of replication lag. Suitable for history and dashboards, not for balances |
| Write concern `w: 1` | Acknowledged when the primary has the write. Faster, but the write can be lost if the primary fails before replicating it |
| Write concern `w: "majority"` | Acknowledged when 2 of 3 members have it. Survives a failover. Slower. Atlas connection strings normally set this by default |

My rule for PayEdge: anything involving money reads from the primary and writes with majority. Reporting and history may read from secondaries.

I did not run a read-preference or write-concern demonstration, so these are design decisions and not measured results.

---

## 5. Cloud deployment review

### What I observed in the Atlas security pages:

- **Database user:** one user, `payedge_admin`, with the role `readWriteAnyDatabase` on **All Resources**. That is broader than the application needs. Least privilege would limit it to read and write on the `payedge` database only.
- **IP access list:** several addresses are allowed, accumulated as I connected from different networks, and one entry is marked "Created as part of the Auto Setup process". A production list should contain only the addresses that need access, and I should delete the ones I no longer use. I blurred the addresses in my screenshot.
- **Credentials:** the database password is not stored in the repository or in any screenshot.

### Limits of the free tier:

| Free M0 cluster | Consequence for PayEdge |
|---|---|
| No sharding | Sharding is a design, backed by data analysis |
| Backups off | No recovery from deletion or corruption. A bank would need continuous backups and a tested restore |
| One region | A regional outage would affect all three nodes. Multi-region replica sets need a paid tier |
| No failover testing, shared resources, 512 MB storage | Fine for coursework, not for production |

### Region and data protection

My cluster is in Paris. For a real PayEdge, storing Nigerian customers' personal data outside Nigeria is a cross-border transfer, and the Nigeria Data Protection Act 2023 regulates such transfers. I have not verified the exact conditions here, so before choosing a production region I would check them and also consider a region closer to Nigeria (for example AWS Cape Town, subject to availability on a paid tier).

---

## 6. Summary

| Topic | Status |
|---|---|
| Deployment | **Observed**: Atlas free cluster, AWS Paris, 3 nodes |
| Replication | **Observed**: one primary and two secondaries. Failover **not tested** |
| Partitioning | **Built and measured** in PostgreSQL |
| Sharding | **Designed** from measured data. Not run |
| Availability and consistency | **Discussed** (CAP, read preference, write concern). Not demonstrated |
| Security and region | **Reviewed** from my own settings |

The deployment shows how the pieces fit together, and the limits show what a production PayEdge would still need: backups, multi-region replication, a sharded transactions collection, a PostgreSQL standby, and a narrower database user.
