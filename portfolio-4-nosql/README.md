# Portfolio 4: NoSQL and Advanced Data Models

**Case study:** PayEdge Digital Bank

**Tools:** MongoDB Atlas (free M0 cluster), Atlas Data Explorer, Java 21, IntelliJ IDEA

---

## 1. Objective

This portfolio models part of the PayEdge case study as a MongoDB **document database** and shows that the model works. It covers:

- designing documents for customer profiles and transaction history
- loading real and generated data into MongoDB Atlas
- querying nested fields and arrays, and running an aggregation that replaces a SQL join
- showing how an index changes a query plan, using Explain
- explaining where the document model suits PayEdge and where it does not, with a short discussion of a graph database

---

## 2. Repository Contents

| File | Purpose |
|---|---|
| `customers.json` | The five customer documents I inserted |
| `Transactions.java` | Java program that generates the 800 transaction documents |
| `transactions.json` | The generated documents, imported into Atlas |
| `queries.js` | Queries, aggregation and Explain tests, written as a first-person record |
| `suitability.md` | Explanation of suitability, including the graph database discussion |
| `nosql_screenshots/` | Screenshots of the portfolio |
| `README.md` | NoSql report |

---

## 3. Environment

| Item | Detail |
|---|---|
| Cluster | `Cluster0`, free M0 tier |
| Region and type | AWS Paris (eu-west-3), replica set with 3 nodes |
| Server version | 8.0.11 |
| Database | `payedge`, with two collections: `customers` and `transactions` |
| Backups | Inactive (not available on the free tier) |
| Access | A database user and an allowed IP address. The credentials are not stored in the repository |

The free cluster paused itself after a long period of inactivity, so I had to resume it and add my current IP address before I could connect.

---

## 4. Data Model

### 4.1 `customers`: one document per customer (5 documents)

Each document embeds the data that is read together with the customer:

```
customer
 ├─ identity and contact (fullName, email, phone, kycStatus, bvnMasked)
 ├─ accounts[]       (accountNumber, accountType, balance, status)
 ├─ beneficiaries[]  (name, accountNumber, bank)
 ├─ loans[]          (loanAmount, interestRate, tenureMonths, status, dates)
 └─ preferences      (transactionAlerts, language, dailyTransferLimit)
```

| PostgreSQL | MongoDB |
|---|---|
| `customers` row | The top-level document |
| `accounts` rows | Embedded `accounts` array |
| `beneficiaries` rows | Embedded `beneficiaries` array |
| `loan_applications` rows | Embedded `loans` array |

The balances are a snapshot of the original PostgreSQL sample data. PostgreSQL remains the source of truth. The BVN is stored masked (`bvnMasked`), because a profile does not need the full number.

### 4.2 `transactions`: separate documents (800 documents)

I kept transactions in their own collection instead of embedding them, because a customer's history grows without limit and a single document is capped at 16 MB. Each transaction points back through `customerId` and the account numbers.

I wrote a Java program, `Transactions.java`, to generate them (a fixed random seed makes the output repeatable). Optional fields appear on only some documents, to show the flexible schema.

| Measure | Result |
|---|---|
| Total documents | 800 |
| Transfers / deposits / withdrawals | 566 / 110 / 124 |
| With a `device` and `location` | 313 |
| Without them | 487 |
| FAILED | 74 |

---

## 5. Implementation Steps

1. Resumed the paused Atlas cluster, allowed my IP address, and created a database user.
2. Created the `payedge` database with the `customers` and `transactions` collections.
3. Inserted the five customer documents as a JSON array.
4. Ran `Transactions.java` (`java Transactions.java`), which wrote `transactions.json` with 800 documents.
5. Imported `transactions.json` into the `transactions` collection. *(Fill in how: Compass or the Atlas import option.)*
6. Checked the import: 800 documents, and `timestamp` stored as a Date.
7. Ran the queries and the aggregation.
8. Ran Explain before and after creating an index, and ran a failure test.

---

## 6. Results

### 6.1 Data checks

| Check | Result |
|---|---|
| Types add up | 566 + 110 + 124 = 800 |
| Deposits with no `fromAccount` | 110 of 110 |
| Withdrawals with no `toAccount` | 124 of 124 |
| `device` present / absent | 313 / 487, which also add up to 800 |

### 6.2 Queries on embedded data

| Query | Technique | Expected | Observed |
|---|---|---|---|
| Verified customers with a savings account | Dot notation into an array | 3 | *3* |
| Customers with an approved loan | Field inside embedded loans | 1 | *1* |
| A current account over 1,000,000 | `$elemMatch` on one array element | 1 | *1* |
| Daily limit of at least 500,000 | Nested object field | 2 | *2* |
| Beneficiaries at GTBank | Embedded array field | 1 | *1* |

### 6.3 Aggregation: total balance per customer

`$unwind` on the accounts, `$group` by customer, then `$sort` by total.

| Customer | Accounts | Total balance |
|---|---|---|
| Ngozi Obi | 2 | 2,340,000 |
| Adaeze Nwachukwu | 2 | 1,750,000 |
| Chidi Eze | 1 | 890,000 |
| Emeka Okafor | 1 | 75,000 |
| Fatima Bello | 1 | 12,000 |

The same answer in PostgreSQL needs a join between `customers` and `accounts`. In the document model, the accounts are already inside the customer.

### 6.4 Explain: before and after an index

Query: customer 1's failed transactions since 13 October 2026.

| Run | Stage | Documents examined | Index keys examined | Returned | Time |
|---|---|---|---|---|---|
| Before the index | COLLSCAN | 800 | 0 | 4 | 0 ms |
| After the index | IXSCAN + FETCH | 4 | 4 | 4 | 0 ms |
| `{ channel: "mobile" }`, not indexed | COLLSCAN | 800 | 0 | 187 | 0 ms |

The compound index was `{ customerId: 1, status: 1, timestamp: -1 }`, named `idx_customer_status_time`. It puts the two equality fields first and the range field last. It is 24.6 kB, and the status was READY.

- **Documents examined fell from 800 to 4**, which is 200 times fewer. The query returned 4 documents, which is 0.5% of the collection.
- **The time was 0 ms both times.** With 800 documents the collection is too small to show a time difference, so I make no speed claim. The evidence is the plan type and the examined count.
- **The index is specific.** The `channel` query still scanned everything, because that field is not in the index.

---

## 7. Evidence

Screenshots are stored in `screenshots/`.

| File | Shows |
|---|---|
| `1_atlas_cluster_overview.png` | Cluster0: FREE tier, running, 3-node replica set, Paris region |
| `2_atlas_database_created.png` | The `payedge` database with both collections |
| `3_customers_documents.png` | The customer documents, with embedded arrays |
| `4_transactions_imported.png` | `transactions` with a count of 800 |
| `5_flexible_schema.png` | The `device` filter result (313) |
| `6_query_verified_savings.png` | Verified customers with a savings account |
| `7_query_elemmatch.png` | The `$elemMatch` query |
| `8_aggregation_total_balance.png` | The aggregation and its five-row result |
| `9_indexes_before.png` | Only the `_id_` index (57.3 kB) |
| `10_explain_before.png` | COLLSCAN, 800 examined, 4 returned |
| `11_create_index.png` | The three index fields entered in order |
| `12_indexes_after.png` | Two indexes, the new one 24.6 kB and READY |
| `13_explain_after.png` | IXSCAN under FETCH, 4 examined |
| `14_explain_unindexed_field.png` | COLLSCAN again for the `channel` query |

The Explain screenshots show the plan but not the filter text, so the exact query is recorded in section 6.4 and in `queries.js`.

---

## 8. Suitability

The full explanation is in `suitability.md`:

- **Documents suit the customer profile and transaction history.** The data is read together, takes different shapes, and the history grows without limit.
- **PostgreSQL stays in charge of transfers, balances and loans**, which need ACID, constraints and row locking (Portfolios 1 and 3).
- **A graph database would suit fraud investigation**, where the question is about relationships several hops deep, such as accounts sharing a device with a flagged account. I discussed this and did not build it.

---

## 9. Short Technical Reflection

**Design choices:** I embedded the data that is read together (accounts, beneficiaries, loans) and kept the data that grows without limit (transactions) in a separate collection. I stored a masked BVN, because the profile does not need the full number. I wrote the transaction generator in Java, my main language, with a fixed random seed so anyone can reproduce the same 800 documents.

**Challenges faced.**

- *A paused cluster and a blocked IP.* The free cluster had paused itself, and Atlas would not let me connect until I resumed it and added my current IP address.
- *Importing the data.* The Add Data menu did not show the import option I expected, so I had to find another route to load the 800 documents. *Thus I used MongoDB Compass to import the data*
- *Counts that did not match the design.* My first two "field missing" counts (676 and 690) looked wrong. Cross-checking by transaction type (566 transfers, 110 deposits, 124 withdrawals) showed the data was correct: 676 and 690 equal the number of documents that **have** the field, so I had recorded the opposite condition. The correct "missing" counts are 110 and 124.
- *The index dialog.* It was a field builder, not a JSON box, so I added the three fields one row at a time and checked that the order matched the plan.
- *Explain showed 0 ms.* The collection is too small for the index to change the time, which taught me to report plan type and documents examined and to avoid claiming a speed-up.

**Lessons learned.**

1. Where data is read together, embedding removes the need for a join. Where it grows without limit, a reference is the safer design.
2. The same query went from examining 800 documents to 4. The plan and the examined count are the evidence of an index working, and they would become a large time difference at scale.
3. An index covers only the queries that use its fields in its order. Putting equality fields before range fields is what let one index serve this query.
4. A flexible schema is a convenience and a risk. MongoDB accepts any shape, so rules that PostgreSQL enforces with constraints have to be added as validation.
5. Different data suits different databases, which is why a bank can reasonably run PostgreSQL, MongoDB and, for fraud analysis, a graph database together.

---

## 10. References and AI Use Declaration

**References**

- MongoDB, Inc. *MongoDB Manual*: Data Modeling, Aggregation Pipeline, Indexes, and Explain Results. https://www.mongodb.com/docs/manual/
- MongoDB, Inc. *MongoDB Atlas Documentation*. https://www.mongodb.com/docs/atlas/

**AI Use Declaration**

- *Tool used:* Claude (Anthropic).
- *Used for:* explaining the document model and indexing, drafting the customer documents, the Java generator and the queries, and structuring this report.
- *How the output was verified:* I ran everything myself in MongoDB Atlas. The counts, plan types, documents examined and index size in this report come from my own screenshots. I cross-checked the data counts against the design.
