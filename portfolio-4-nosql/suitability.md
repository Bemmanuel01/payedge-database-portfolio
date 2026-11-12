# Suitability of the NoSQL Model for PayEdge Digital Bank

**Portfolio 4: NoSQL and Advanced Data Models | MIT 8103**

PayEdge does not need to choose between PostgreSQL and MongoDB. Each fits different data, and a bank can run both. This is called polyglot persistence. This document explains where the document model fits, where it does not, and where a graph database would fit.

---

## 1. Summary

| PayEdge data | Best fit | Reason |
|---|---|---|
| Transfers, balances, loans (the ledger) | **PostgreSQL** | Needs ACID, constraints and row locks, all demonstrated in Portfolios 1 and 3 |
| Customer profile (details, accounts, beneficiaries, loans, preferences) | **MongoDB documents** | Read as one unit, so one document replaces four joined tables |
| Transaction history and event logs | **MongoDB collection** | Flexible fields, high volume, written once and read often |
| Relationships between accounts, devices and people (fraud rings) | **Graph database** (discussed, not built) | Multi-hop relationship queries |

---

## 2. Why documents suit the customer profile

In PostgreSQL, one customer's information is spread across `customers`, `accounts`, `beneficiaries` and `loan_applications`. Showing a profile page means joining all four. In MongoDB, I stored each customer as one document, with accounts, beneficiaries and loans embedded inside it.

- **Data read together is stored together.** One lookup returns the whole profile.
- **No join for related data.** My aggregation (`$unwind` then `$group`) calculated the total balance per customer directly from the embedded accounts. Ngozi Obi came out at 2,340,000 across two accounts, Adaeze Nwachukwu at 1,750,000, and so on, with no join.
- **Nested queries are natural.** Dot notation reached inside arrays (`accounts.accountType`), and `$elemMatch` made two conditions apply to the same account.
- **Sensitive data can be reduced.** The document stores a masked BVN (`bvnMasked`), not the full number, because a profile page does not need it.

---

## 3. Why transactions are a separate collection

I did not embed transactions inside the customer document. A customer's history grows without limit, and a single MongoDB document is capped at 16 MB, so an embedded history would keep growing the customer document and eventually hit the cap. Transactions are separate documents that point back to the customer through `customerId` and the account numbers. The rule I used is to embed data that is small and read together, and to reference data that grows without limit.

The generated collection also shows the flexible schema. Of 800 transactions, **313 carry a `device` and `location`**, and the other 487 do not. Deposits have no `fromAccount` and withdrawals have no `toAccount`: those fields are simply absent. In PostgreSQL, every row would carry every column, and adding a new one would need an `ALTER TABLE`.

---

## 4. Where documents do not fit

**Transfers.** A transfer must debit one account and credit another, atomically, with a balance that can never go negative. In Portfolio 3 I demonstrated this with PostgreSQL: commit, rollback, a `CHECK` constraint on the balance, and row locks that stopped a lost update. MongoDB can run multi-document transactions on a replica set, but PayEdge's ledger already has these guarantees in PostgreSQL, so moving it would add risk with no benefit.

**The balances in my customer documents are a snapshot.** PostgreSQL remains the source of truth. If both copies were updated independently, they could disagree.

---

## 5. Trade-offs of the document model

| Trade-off | Effect |
|---|---|
| **Duplication.** Embedding copies data, such as a beneficiary's name | Updating one fact may mean updating several documents, with no automatic consistency |
| **Document size.** One document is limited to 16 MB | Unbounded lists must be referenced, not embedded |
| **Flexible schema.** MongoDB accepts any shape by default | Mistakes are not caught unless validation rules are added. A `$jsonSchema` validator could enforce rules such as "a deposit has no `fromAccount`", but I did not build one |
| **Indexes cost storage and write time.** Same as in PostgreSQL | See section 6 |

---

## 6. Indexing evidence

The query was "customer 1's failed transactions since 13 October 2026". I tested it on the 800-document `transactions` collection.

| Query | Stage | Documents examined | Index keys examined | Returned | Time |
|---|---|---|---|---|---|
| Customer 1, FAILED, since 13 Oct (before index) | COLLSCAN | 800 | 0 | 4 | 0 ms |
| Same query (after index) | IXSCAN + FETCH | 4 | 4 | 4 | 0 ms |
| `{ channel: "mobile" }` (field not in the index) | COLLSCAN | 800 | 0 | 187 | 0 ms |

The compound index `{ customerId: 1, status: 1, timestamp: -1 }` puts the equality fields first and the range field last. It reduced the documents examined from 800 to 4, which is 200 times fewer, and every document it read was one that was returned.

The execution time was 0 ms before and after because 800 documents is a tiny collection, so I do not claim a speed-up. The evidence is the change in plan and in documents examined, which would become a large time difference on millions of documents. The index took 24.6 kB, and it must be maintained on every insert. The `channel` test confirms that an index only helps queries that use its fields.

---

## 7. A second NoSQL model: graph databases (discussion only)

I did not build a graph database, but fraud detection is the PayEdge problem where one would help most.

**The idea.** A graph database stores **nodes** (things) and **edges** (relationships between them). For PayEdge:

- Nodes: `Customer`, `Account`, `Device`
- Edges: `OWNS` (customer to account), `SENT_MONEY_TO` (account to account), `USED_DEVICE` (account to device)

**The question it answers well.** "Which accounts share a device with an account that has already been flagged for fraud?" That is a relationship query that can run several hops deep:

```cypher
MATCH (flagged:Account {status: 'FLAGGED'})-[:USED_DEVICE]->(d:Device)
      <-[:USED_DEVICE]-(other:Account)
WHERE other <> flagged
RETURN other.accountNumber, d.deviceId
```

In PostgreSQL this needs self-joins, and each extra hop adds another join or a recursive query. In a graph database, following relationships is the core operation, so deeper questions such as "money passed through three accounts that share one device" stay simple to write.

**Link to my data.** My generated transactions already carry `device.deviceId` and the account numbers, which are the raw material for these edges. The device IDs are random, so I draw no fraud conclusions from them.

**Why not use a graph for everything.**

| Reason | Detail |
|---|---|
| It is a specialist tool | It is best for relationship-heavy questions, not for storing ledger rows or profiles |
| It is another system to run | The data has to be copied in from PostgreSQL and kept in sync |
| The ledger needs PostgreSQL's guarantees | Balances, constraints and locks stay where Portfolio 3 showed they work |

The sensible design is a graph store **alongside** PostgreSQL, fed from it, used for fraud investigation only.

---

## 8. Conclusion

MongoDB documents suit PayEdge's customer profiles and transaction history, because the data is read together, grows in different shapes, and benefits from embedding or referencing by design. PostgreSQL stays in charge of transfers, balances and loans, where strict consistency matters. A graph database would add value for fraud investigation. The choice depends on how each kind of data is read and written, which is why PayEdge benefits from using more than one database.
