# Portfolio 3: Transactions and Concurrency

**Case study:** PayEdge Digital Bank

**Tools:** PostgreSQL 17, `psql` (two terminal sessions), pgAdmin 4, IntelliJ IDEA

---

## 1. Objective

This portfolio demonstrates how PostgreSQL keeps a banking database correct when operations fail or run at the same time. It covers:

- **Commit:** making a transfer permanent
- **Rollback:** undoing a transaction, by choice and because of an error
- **Savepoints:** undoing part of a transaction and keeping the rest
- **A concurrency problem:** the lost update, reproduced on purpose
- **Concurrency control:** row-level locking that prevents it
- **Isolation:** what one transaction can see while another is running, compared across two isolation levels

All demos use real PayEdge accounts from the sample data.

---

## 2. Repository Contents

| File | Purpose |
|---|---|
| `atomic_commit.sql` | Demo 1: a committed transfer, with isolation between two sessions |
| `rollback.sql` | Demo 2: a manual rollback and a rollback caused by a constraint violation |
| `save_point.sql` | Demo 3: partial rollback with a savepoint |
| `lost_update.sql` | Demo 4: the lost update problem and two fixes |
| `isolation_levels.sql` | Demo 5: READ COMMITTED compared with REPEATABLE READ |
| `reset_demo.sql` | Restores the sample balances and removes demo transactions |
| `transaction_screenshots/` | Screenshots of every runs |
| `README.md` | Portfolio 3 Report |

Each script is recorded based on what I ran and what I observed. The demos need two live sessions, so the scripts are documentation and are not meant to run as a single file. `reset_demo.sql` is the only one that is safe to run whole.

---

## 3. Environment and Method

| Item | Detail |
|---|---|
| Database | `payedge_db` on PostgreSQL 17 |
| Sessions | Two PowerShell windows, each running `psql` (Terminal A and Terminal B) |
| Why not IntelliJ | IntelliJ consoles can share one database session, which would hide the isolation behaviour. Separate `psql` windows guarantee two independent sessions. |
| Default isolation level | `read committed` (confirmed with `SHOW default_transaction_isolation;`) |
| Evidence | The `psql` prompt shows the transaction state: `=#` idle, `=*#` transaction open, `=!#` transaction failed |

Accounts used:

| Account | Owner | Used in |
|---|---|---|
| 1 | Adaeze (savings) | Demos 1, 2, 3 |
| 3 | Emeka (savings) | Demos 1, 2 |
| 4 | Fatima (savings, balance 12,000) | Demo 2 (insufficient funds) |
| 2 | Adaeze (current, balance 1,500,000) | Demos 4 and 5 |

---

## 4. Demonstrations and Results

### Demo 1: A committed transfer (atomicity, isolation, durability)

I transferred 50,000 from account 1 to account 3 inside one transaction, locking both rows with `SELECT ... FOR UPDATE` in a fixed order.

| Moment | Terminal A | Terminal B |
|---|---|---|
| Transaction open, not committed | 200,000 and 125,000 | **250,000 and 75,000** (old values) |
| After `COMMIT` | | 200,000 and 125,000 |
| Total of both accounts | | **325,000**, unchanged |

- **Atomicity:** the debit, the credit and the transaction record (`DEMO-COMMIT-001`) succeeded together, and the total stayed at 325,000.
- **Isolation:** Terminal B could not see my uncommitted changes.
- **Durability:** the committed transfer survived an unexpected computer shutdown between demos.

### Demo 2: Rollback

| Part | What I did | Result |
|---|---|---|
| 2a: manual rollback | Moved 30,000 between accounts 1 and 3, then ran `ROLLBACK` | Balances were 170,000 and 155,000 inside the transaction and **200,000 and 125,000** after the rollback |
| 2b: rollback after an error | Credited account 3, then tried to take 50,000 from account 4 (balance 12,000) | `ERROR: ... violates check constraint "chk_balance"`, then `ERROR: current transaction is aborted`. After `ROLLBACK`, account 3 was back at **125,000** and account 4 at **12,000** |

In part 2b, the credit to account 3 had already succeeded but was undone when the debit failed, which shows atomicity. The `chk_balance` constraint stopped the database from ever holding a negative balance, which shows consistency. The prompt changed from `=*#` to `=!#` when the error occurred.

### Demo 3: Savepoint

In Demo 2 an error forced me to discard the whole transaction. With a savepoint I could undo only the failed step.

| Step | Prompt | Result |
|---|---|---|
| Valid withdrawal of 5,000, then `SAVEPOINT` | `=*#` | Transaction open |
| Withdrawal of 999,999 | `=!#` | `chk_balance` violated. The `DETAIL` line showed a balance of -804,999.00, which confirms the first withdrawal was still in effect. |
| `ROLLBACK TO SAVEPOINT` | `=*#` | Transaction usable again, first withdrawal kept |
| Record the rejected attempt, then `COMMIT` | `=#` | Final balance of account 1: **195,000** |

The database held three demo rows afterwards: `DEMO-COMMIT-001` (SUCCESS), `DEMO-SP-001` (SUCCESS) and `DEMO-SP-002` (FAILED).

### Demo 4: The lost update and two fixes

Customer A withdraws 100,000 and customer B withdraws 200,000 from account 2 at the same time. The correct final balance is **1,200,000**.

| Part | Approach | Final balance | What happened |
|---|---|---|---|
| 4a | Each session read the balance, calculated the new value, and wrote it back as a fixed number | **1,300,000** | B silently overwrote A. 100,000 was lost and PostgreSQL raised no error. |
| 4b | Atomic relative update: `SET balance = balance - x` | **1,200,000** | Terminal B **hung** until A committed, then applied its subtraction to the latest value |
| 4c | Pessimistic lock: `SELECT ... FOR UPDATE` | **1,200,000** | Terminal B hung at its `SELECT`, and after A committed it read **1,400,000**, not the stale 1,500,000 |

Both fixes work through **row-level locking**, which forces the sessions to take turns. The cost is waiting: B was delayed until A committed.

### Demo 5: Isolation levels

The same sequence of events was run at two levels. Terminal A read account 2 inside a transaction, Terminal B then added 100,000 to the same row, and Terminal A read it again.

| Level | First read | Second read (same transaction) | Observation |
|---|---|---|---|
| READ COMMITTED (default) | 1,500,000 | **1,600,000** | A non-repeatable read: the value changed inside one transaction |
| REPEATABLE READ | 1,500,000 | **1,500,000** | A stable snapshot. After `COMMIT`, a fresh read showed 1,600,000 |

In part 5c, at REPEATABLE READ, Terminal A tried to change the row after Terminal B had committed a change to it:

```
ERROR:  could not serialize access due to concurrent update
```

PostgreSQL refused to let A overwrite a row that changed after its snapshot, which prevents the lost update from Demo 4a. The application is expected to catch this error and retry the whole transaction.

---

## 5. How PostgreSQL Achieves This

PostgreSQL uses **multi-version concurrency control (MVCC)**. Each transaction sees a version of the data, so readers do not block writers and writers do not block readers. Locks only matter when two sessions try to write the **same row**, which is why Terminal B waited in Demos 4b and 4c but never waited when it was only reading.

| Concept | Where I observed it |
|---|---|
| Atomicity | Demo 1 (total unchanged), Demo 2b (credit undone) |
| Consistency | Demo 2b and Demo 3 (`chk_balance` blocked a negative balance) |
| Isolation | Demo 1 (B could not see uncommitted changes), Demo 5 (snapshot) |
| Durability | Demo 1 (the committed transfer survived a shutdown) |
| Concurrency problem | Demo 4a (lost update) |
| Concurrency control | Demos 4b and 4c (row locks), Demo 5c (serialization error) |

**Note:** I did not demonstrate deadlocks or the SERIALIZABLE level, and PostgreSQL's `READ UNCOMMITTED` behaves as `READ COMMITTED`, so dirty reads are not possible in PostgreSQL.

---

## 6. Testing Notes

- Every demo started from a known balance, and I reset the data after each part (`reset_demo.sql` for the sample accounts, or a single `UPDATE` for account 2).
- The `psql` prompt (`=#`, `=*#`, `=!#`) was kept visible as evidence of transaction state.
- Typing mistakes (`accoun_id`, `BEGI`) were rejected by PostgreSQL with syntax errors and had no effect, because no transaction was open at the time.
- Typing `BEGIN` while a transaction was already open printed `WARNING: there is already a transaction in progress` and had no effect.
- Demo data uses references starting with `DEMO-`, so the reset script removes only those rows and never touches the 500,000 seeded transactions from Portfolio 2.

---

## 7. Evidence

Screenshots are stored in `transaction_screenshots/`.

| File | Shows |
|---|---|
| `1_baseline.png` | Starting balances |
| `2_terminal_A_before_commit.png` | Terminal A with the transaction open (`=*#`) |
| `3_terminal_B_isolated.png` | Terminal B seeing old balances, then the new ones |
| `4_terminal_B_after.png` | New balances and the unchanged total of 325,000 |
| `5_manual_rollback.png` | Manual rollback restoring 200,000 and 125,000 |
| `6_rollback_error.png` | `chk_balance` error, aborted transaction, final balances |
| `7-savepoint.png` | Prompt moving `=*#`, `=!#`, `=*#` around the savepoint |
| `8_demo_rows.png` | The three `DEMO-` transaction rows |
| `9_lost_update_baseline.png` | Account 2 at 1,500,000 |
| `10_row_lock_waiting.png` | Terminal B waiting on a row lock |
| `11_fix_atomic_update.png` | Final balance of 1,200,000 after the atomic update |
| `12_fix_for_update.png` | Terminal B blocked, then reading 1,400,000 |
| `13_default_isolation.png` | `read committed` |
| `14_read_committed.png` | Balance changing from 1,500,000 to 1,600,000 |
| `15_repeatable_read.png` | Balance staying at 1,500,000 inside the transaction |
| `16_serialization_error.png` | The serialization error and the `=!#` prompt |

---

## 8. Technical Reflection

**Design choices.** I used two separate `psql` windows because IntelliJ consoles can share one session, and a shared session would have made isolation and locking invisible. I built every demo on constraints the schema already enforced (`chk_balance`, foreign keys), so the errors came from real design rules, not from invented failures. I also wrote a reset script so that each demo could start from a known state and be repeated.

**Challenges:**

- *Getting `psql` working.* Windows did not recognise `psql`, so I added the PostgreSQL `bin` folder to the PATH for each window. I also learned that `psql` hides the password completely while it is typed, which at first made it look as if typing was not working.
- *Losing both terminals.* My computer shut down unexpectedly partway through. I checked the database afterwards and found that the committed demo rows and balances were intact, which was durability working in practice, while anything uncommitted had been discarded.
- *Order-sensitive demos.* The lost update only happens if Terminal B reads before Terminal A writes, so I had to follow the sequence exactly and keep switching windows carefully.
- *Small mistakes.* I mistyped a column name and a command, and once typed `BEGIN` twice. Each produced a harmless error or warning, which showed me how PostgreSQL reports problems.


**Lessons learned.**

1. A transaction is all-or-nothing, and PostgreSQL is strict: after any error, every command is refused until the transaction ends, unless a savepoint lets me recover.
2. A bug like the lost update gives no error, which makes it more dangerous than a failure. The safe fixes are to let the database do the arithmetic (`balance = balance - x`) or to lock the row when reading it.
3. Higher isolation protects the transaction but moves the burden to the application, which must catch serialization errors and retry.
4. Locks cost waiting time, so the choice between them is a trade-off between correctness and speed.
5. Repeatable demos need a known starting state, and a reset script is part of the evidence.

---

## 9. References and AI Use Declaration

**References:**

- PostgreSQL Global Development Group. *PostgreSQL 17 Documentation*: Transaction Isolation, Explicit Locking, and SAVEPOINT. https://www.postgresql.org/docs/17/
- Elmasri, R. and Navathe, S. (2016). *Fundamentals of Database Systems*. Pearson.

**AI Use Declaration:**

- *Tool used:* Claude (Anthropic).
- *Used for:* explaining transaction and isolation concepts, drafting the demonstration sequences, and structuring this report.
- *How the output was verified:* I ran every demonstration myself in two `psql` sessions against PostgreSQL 17. The balances, error messages and prompts recorded in this report come from my own runs, and the screenshots are from my own machine. I corrected typing errors as they occurred and reviewed the interpretation, and I can explain each result.

