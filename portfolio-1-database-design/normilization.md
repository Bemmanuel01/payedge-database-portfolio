# Normilization: PayEdge Digital Bank 
**Normalization of the Database Design and Modelling**

This document explains how the PayEdge schema was reached by normalizing an initial flat design, and checks the final tables against 1NF, 2NF, 3NF and BCNF.

---

## 1. Starting point: an unnormalized design

A first, naive design for a customer statement might keep everything in one table. The rows below are illustrative.

| customer_name | email | account_numbers | account_types | balances | txn_refs | txn_amounts | beneficiaries |
|---|---|---|---|---|---|---|---|
| Adaeze Nwachukwu | adaeze@gmail.com | 8077343538, 0077343538 | SAVINGS, CURRENT | 250000, 1500000 | TXN-001, TXN-003 | 50000, 100000 | Emeka Okafor, Ahmed Musa |
| Adaeze Nwachukwu | adaeze@gmail.com | 8077343538 | SAVINGS | 250000 | TXN-006 | 30000 | Emeka Okafor |

### Problems with this design (anomalies)

| Anomaly | Example |
|---|---|
| **Update anomaly** | Adaeze's email appears on every row, so changing it means editing many rows. Missing one leaves contradictory data. |
| **Insertion anomaly** | A new account cannot be recorded until the customer has a transaction, because the transaction columns sit on the same row. |
| **Deletion anomaly** | Deleting Adaeze's only transaction row also deletes her account details and her beneficiaries. |
| **Redundancy** | The customer name, email and balance repeat across rows. |

---

## 2. First Normal Form (1NF)

**Rule:** Every column holds one atomic value, and there are no repeating groups.

**Violation:** `account_numbers`, `balances`, `txn_refs` and `beneficiaries` each store several values in one cell.

**Fix:** Each repeating group has its own row, then its own table:

- one row per account
- one row per transaction
- one row per beneficiary

After this step, every cell holds a single value.

---

## 3. Second Normal Form (2NF)

**Rule:** the table is in 1NF, and every non-key attribute depends on the whole primary key, not on part of it.

**Violation (in the intermediate design):** suppose accounts and transactions share a table with the composite key `(account_number, txn_ref)`. Then `account_type` and `balance` depend only on `account_number`, which is part of the key, and `amount` depends only on `txn_ref`.

**Fix:** separate them:

| Table | Key | Holds |
|---|---|---|
| `accounts` | `account_id` | account type, balance, status |
| `transactions` | `transaction_id` | amount, status, reference, narration |

The final schema uses single-column surrogate keys (`SERIAL`), so partial dependencies cannot arise in any table.

---

## 4. Third Normal Form (3NF)

**Rule:** the table is in 2NF, and no non-key attribute depends on another non-key attribute (no transitive dependency).

**Violation (in the intermediate design):** an `accounts` row that also stores `customer_name` and `customer_email` creates the chain `account_id -> customer_id -> customer_name`. The name depends on the customer, not on the account.

**Fix:** Customer details are kept only in `customers`, and the `accounts` has a foreign key `customer_id`.

---

## 5. Final schema and normal form check

| Table | Primary key | Key dependencies | Normal form |
|---|---|---|---|
| `customers` | `customer_id` | All attributes depend only on `customer_id`. `email`, `phone` and `bvn` are candidate keys. | BCNF |
| `accounts` | `account_id` | `customer_id` is a foreign key. `account_number` is a candidate key. | BCNF |
| `transactions` | `transaction_id` | `from_account_id` and `to_account_id` are foreign keys. `reference` is a candidate key. | BCNF |
| `beneficiaries` | `beneficiary_id` | Depends only on the key. `customer_id` is a foreign key. | BCNF |
| `loan_applications` | `loan_id` | Depends only on the key. Foreign keys to customers and accounts. | BCNF |
| `staff` | `staff_id` | `email` is a candidate key. | BCNF |
| `audit_logs` | `log_id` | `user_id` is a foreign key to `staff`. | 3NF (see section 6) |

Every table except `audit_logs`, each determinant is a candidate key, so the tables also satisfy **Boyce-Codd Normal Form (BCNF)**.

---

## 6. Deliberate exceptions and trade-offs

### 6.1 `accounts.balance` is derived data

A balance can in principle be computed by summing the transactions on the account. Storing it is technically redundant, but recalculating it for every balance check would be too slow. The balance is kept consistent by running each transfer inside **one atomic transaction** that updates both balances and inserts the transaction record (shown in Portfolio 3).

### 6.2 `audit_logs.record_id` is a polymorphic reference

`record_id` points at rows in different tables, depending on `table_affected`. A foreign key cannot express that, so it is a plain integer. The same applies to `old_value` and `new_value`, which are JSONB because each audited table changes different columns. Audit tables are append-only and must outlive the records they describe, so this denormalisation is intentional.

### 6.3 `beneficiaries.account_number` has no foreign key

A beneficiary may hold an account at another bank (GTBank, Access Bank). A foreign key to `accounts` would reject these valid rows. The trade-off is that the database cannot check beneficiaries who bank with PayEdge, so that check belongs in application logic or a trigger.

### 6.4 Nullable account columns in `transactions`

A deposit has no sender and a withdrawal has no receiver, so `from_account_id` and `to_account_id` can be NULL. The constraint `chk_txn_has_account` ensures that at least one of them is always present.

---

## 7. Summary

The design moved from one flat table to seven tables, each describing one entity, with relationships expressed through foreign keys. This removes the update, insertion and deletion anomalies in section 1 and stores each fact in one place. The exceptions in section 6 were chosen on purpose, each for a stated reason of performance, cross-bank data or auditability.


