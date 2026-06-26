# 01 — Practical Exam: Budget-Based Deadlock Detection in a Real Lock Manager

**Series:** Isomorphic Scheduler · Paper 01 companion
**Audience:** a Claude (or human) engineer implementing the toy result against a production-shaped system
**Goal:** reproduce the *zero-false-positive, timer-free* detection result from Paper 01 inside a real database lock manager, and report where reality bends the toy.

> **TruthSeed (exam):** `iso-sched-01-exam:budget-in-real-lockmgr`
> A conserved per-transaction budget — drained on a blocked scheduling
> attempt, refilled on progress — detects true deadlock with no wall-clock
> timeout, distinguishing *slow* from *dead* in a real engine. Latency is
> bounded by budget size, not by a tuned `innodb_lock_wait_timeout`.

---

## Why this exam exists

The toy in `iso_deadlock.py` proves the mechanism in a vacuum: scripted
programs, one lock manager, deterministic round-robin. A real engine adds
everything the vacuum omitted — concurrent acquirers, lock *modes* (shared vs.
exclusive), upgrade requests, a real wait-for graph, and a scheduler we do not
control. The exam asks: **does the budget predicate survive contact with a real
wait-for graph, and does it beat the timeout it replaces?**

The honest answer we expect: the *cycle* half of the predicate is already how
real engines detect deadlock (InnoDB and PostgreSQL both build a wait-for graph
and look for cycles). The *novel* half is the **budget**, which replaces the
**timeout** that real engines fall back on when cycle detection is disabled,
deferred, or incomplete. So the exam is really: *can budget-exhaustion replace
`innodb_lock_wait_timeout` / `deadlock_timeout` with strictly more information?*

---

## Target systems (pick one)

### Option A — SQLite (easiest, recommended first)
SQLite serializes writers, so classic AB-BA deadlock between two writers does
not arise inside a single connection the way it does in InnoDB. But
`SQLITE_BUSY` across connections is exactly a **blocked scheduling attempt that
returns its budget unspent**. The exam in SQLite: wrap `sqlite3` connections in
a budget-tracking retry layer and show that budget exhaustion across `BUSY`
returns distinguishes a *contended-but-live* writer from a genuinely *wedged*
pair — without a busy-timeout pragma.

- Hook point: the `BUSY` handler. A live retry that eventually succeeds = spend.
  A retry that never succeeds while a reciprocal connection also spins = the
  cycle.
- Deliverable: `exam_sqlite.py` — two connections, reciprocal table locks via
  `BEGIN IMMEDIATE`, budget counter in the busy handler, no `busy_timeout`.

### Option B — MySQL/InnoDB (the real test)
InnoDB has a real wait-for graph and an automatic deadlock detector, plus
`innodb_lock_wait_timeout` as the fallback. The exam: run with
`innodb_deadlock_detect = OFF` (forcing reliance on the timeout fallback), then
show a **budget sidecar** that watches `INFORMATION_SCHEMA.INNODB_TRX` /
`data_lock_waits` and declares deadlock from budget exhaustion *before* the
timeout would fire, with no false positive on a slow-but-progressing trx.

- Hook point: poll `performance_schema.data_lock_waits` for who-waits-on-whom
  (the wait-for edges) and `INNODB_TRX.trx_rows_modified` as the **progress
  signal** (rows modified increasing = spend; flat while blocked = return).
- Deliverable: `exam_innodb.py` — sidecar process, two transactions in AB-BA,
  budget per `trx_id`, declare deadlock on floor+cycle.

---

## The mapping (toy → real)

| Toy concept (`iso_deadlock.py`) | SQLite | InnoDB |
|---|---|---|
| `attempt()` returns progress | retry succeeds / stmt commits a row | `trx_rows_modified` increased since last poll |
| `attempt()` returns blocked | `SQLITE_BUSY` | trx appears in `data_lock_waits` as a waiter |
| `budget` refill on progress | reset on successful stmt | reset when `trx_rows_modified` rises |
| `budget` drain on block | decrement per `BUSY` | decrement per poll while still waiting & flat |
| `waiting_on(p)` | which conn holds the wanted table | `data_lock_waits.blocking_trx_id` |
| closed wait-cycle | reciprocal `BUSY` between two conns | cycle in the `data_lock_waits` graph |
| `rounds_to_confirm` | retry budget (e.g. 3) | poll-rounds budget (e.g. 3) |

**The one rule that must hold:** the progress signal (`trx_rows_modified`, or a
committed row) is what refills the budget. If you refill on *anything else* —
on time elapsed, on poll count, on mere liveness of the connection — you have
smuggled a timer back in and the result is void. Budget may only be earned by
**conversion to progress**. That is the entire claim.

---

## What to measure

1. **False-positive rate on the slow case.** Run one transaction doing a long
   but unblocked batch (many rows, slow disk or `SELECT SLEEP` *between*
   committed statements — never *holding* while idle). Budget must never hit
   the floor. A timeout-based detector with a short timeout *will* false-fire
   here; record the timeout value at which it does.
2. **Detection latency on the true case.** Rounds from first mutual block to
   declaration. Should equal `rounds_to_confirm`, independent of wall clock.
3. **Comparison.** Same AB-BA workload under (a) native timeout, (b) native
   cycle detector, (c) budget sidecar. Report latency and false-positives for
   each. The expected story: budget matches the cycle detector on the true case
   and beats the timeout on the false case.

---

## Expected result (pre-registered — `(predicted)`)

- Budget detection declares the true AB-BA deadlock in `rounds_to_confirm`
  polls, matching InnoDB's native cycle detector and arriving **before**
  `innodb_lock_wait_timeout`.
- Budget detection produces **zero** false positives on the slow-but-progressing
  transaction, where any timeout short enough to be useful on the true case
  **will** false-fire.
- The crossover — a timeout that is both fast enough for the deadlock and slow
  enough to spare the slow trx — **does not exist** when the slow trx's honest
  work time exceeds the deadlock's acceptable detection latency. This is the
  gap budget closes: it reads *conversion*, not *duration*.

If any of these fail in the real engine, that failure is the Paper 02 seed.

---

## Reporting back

Fill this table and hand it to §6 of `paper01.md`:

```
engine: ____            (sqlite | innodb)
true-deadlock latency (budget):     ____ polls   /  ____ ms wall
true-deadlock latency (native cd):  ____ ms
true-deadlock latency (timeout):    ____ ms (at timeout = ____)
false-positive (budget):            yes / no
false-positive (timeout) at that timeout: yes / no
smuggled-timer audit: did budget refill ONLY on trx_rows_modified? yes / no
```

The last line is the integrity check. If "no," the run does not count.
