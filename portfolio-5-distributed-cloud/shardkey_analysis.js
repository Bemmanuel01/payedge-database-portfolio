/*
 * ============================================================
 * Shard-key analysis on the transactions collection
 * ============================================================
 *
 * OBJECTIVE:
 * Sharding splits a collection across servers using a shard key. A poor key puts most of the data or traffic on one shard (a "hot" shard).
 * I could not shard my cluster, so I measured three candidate keys on my own data to judge them, and I describe the design I would use.
 *
 * SETUP:
 * Database payedge, collection transactions, 800 documents, on my free Atlas cluster (Cluster0, AWS Paris, 3-node replica set).
 * The free tier cannot be sharded, so the sh.* commands at the end are the design and were not run.
 *
 * HOW IT WAS RUN?
 * 1. I used the Aggregations tab in the Atlas Data Explorer. This file records the equivalent mongosh commands.
 * 2. Lines marked OUTPUT are what I saw on my screen after running the script or query.
 * ============================================================
 */

use payedge

// ============================================================
// Candidate 1: customerId
// ============================================================
db.transactions.aggregate([
    {$group: {_id:"$customerId", transactions: {$sum:1}}},
    {$sort: {transactions:-1}}
])
// OUTPUT:
//   customer 1   226
//   customer 5   212
//   customer 2   127
//   customer 3   123
//   customer 4   112

// Total = 226 + 212 + 127 + 123 + 112 = 800.
//    - Only 5 distinct values. Customers 1 and 5 each own two accounts and have about twice the traffic of customer 4 (226 against 112).
//    - In production there would be millions of customers, so customerId would have high cardinality. In my sample, 5 values are too few to
//      show good splitting. A second problem is that every document for one customer has the SAME key value, and MongoDB cannot split a chunk
//      between documents that share one key value, so a very busy customer would become a chunk that cannot be divided.

// ============================================================
// Candidate 2: fromAccount
// ============================================================
db.transactions.aggregate([
    {$group: {_id:"$fromAccount", transactions: {$sum:1}}},
    {$sort: {transactions:-1}}
])
// OUTPUT:
//      8 groups (7 account numbers plus null). The preview showed the first-five:
//      "0077343538" = 113
//      "9144577709" = 112
//      null         = 110
//      "7034567890" = 108
//      "8155609905" = 92
//      Total (first-five) = 535
//
//      The null group holds 110 documents, which is exactly my 110 deposits, because a deposit has no sender.
//      Every deposit would share the same key value (null) and land in one chunk, and a query for money received by an
//      account would not include fromAccount, so it would have to ask every shard.

// ============================================================
// Candidate 3: timestamp, grouped by month
// ============================================================
db.transactions.aggregate([
    { $group: {
            _id: { $dateToString: { format: "%Y-%m", date: "$timestamp" } },
            transactions: { $sum: 1 } } },
    { $sort: { _id: 1 } }
])
// OUTPUT:
//   2026-08 = 157   (a partial month, my data starts mid-August)
//   2026-09 = 274
//   2026-10 = 266
//   2026-11 = 103   (a partial month, my data ends 12 November)

// Total =  157 + 274 + 266 + 103 = 800.
// A timestamp increases, so that every new transaction has a value larger than all existing ones. With a range-based key, every new
// write goes to the shard holding the newest range (the November bucket here) while the older shards sit idle. That is a hot shard.

// ============================================================
// The design I would use (NOT run: the free tier cannot shard)
// ============================================================
// sh.enableSharding("payedge")
// sh.shardCollection("payedge.transactions", { customerId: 1, timestamp: 1 })

// ============================================================
// CONCLUSION:
//      - customerId alone has too few values in my sample and cannot split a busy customer.
//        fromAccount has a null group and does not match how PayEdge reads data. timestamp alone creates a hot shard.
//      - I would choose the compound key { customerId, timestamp }. PayEdge's main read is "one customer's transactions in a date
//        range", so a query that names the customer goes to one shard.
//      - Writes are spread across many customers, and adding timestamp lets a very busy customer's history split into smaller chunks,
//        ordered by time.
//      - A hashed customerId would also spread customers evenly and still send a single-customer query to one shard,
//        but it cannot split one busy customer's documents, and it cannot support a range on customerId.
//        Queries across all customers by date go to every shard under either choice.
//      - I measured only the spread of my small data set. I did not measure real shard performance, because I could not create shards.
// ============================================================