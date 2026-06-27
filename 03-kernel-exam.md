# 03 — Kernel Exam: The Flow-Equation Scheduler in Linux, + The Zombie Fix

**Series:** Isomorphic Scheduler · Paper 03 companion
**For:** a Claude Code agent (or human) implementing and testing in the Linux kernel
**Reference artifact:** `iso_flow.py` @ commit `b10a01f`
**Goal:** implement the flow-equation scheduler (priority as a routed flow rate;
`eff(p) = base(p) + Σ eff(w)` over waiters) as a real Linux scheduling policy, test
it under priority-inversion workloads via UML, then containers; **and** implement a
new exit-notification syscall that eliminates zombies by the same conservation
principle.

> **TruthSeed (exam):** `iso-sched-03-kernel:flow-and-no-zombies`
> Two applications of one principle — a stranded claim should flow to whoever can
> use it, and nothing should be held that no one will collect. (1) A blocked
> task's scheduling weight flows down the wait-edge to its lock holder, so
> priority inversion never forms, validated against a real inversion workload.
> (2) A dead task's exit state is held only if someone will collect it; if the
> collector said "len-0 buffer / I don't care" or is itself gone, the state is
> reclaimed at once. No zombies anywhere.

---

## PART A — THE FLOW-EQUATION SCHEDULER

### A0. What we are porting

The toy (`iso_flow.py`) schedules by *effective rate*: each instant, runnable tasks
split the CPU in proportion to `eff(p) = base_rate(p) + Σ eff(w)` over every task
`w` blocked on `p`, transitively. A blocked task is not runnable, so its rate flows
down its wait-edge into the holder it is blocked on. Consequences validated in the
toy: a high task blocked on a low holder pours its weight into the holder (holder's
effective share jumps; an unrelated busy task does NOT feast); the holder clears
its critical section fast; the instant the lock frees the flow reverts with no
penalty (memoryless). Priority inversion is structurally absent.

This is, in effect, **priority inheritance expressed as a weight flow** rather than
as a boost-and-restore protocol. Linux already has priority inheritance for
`rt_mutex` (PI futexes); the exam's novelty is expressing it as a conserved-weight
flow on the *fair* scheduler's weights, computed from the wait-graph, with no
stored boost to restore.

### A1. Where it lands in the kernel

Two viable implementation targets — pick based on effort/fidelity tradeoff:

**Option 1 (recommended first): a CFS/EEVDF weight modifier.**
Linux's fair scheduler (CFS, now EEVDF in 6.6+) already does weighted
proportional share: each task has a weight derived from nice value, and CPU is
shared in proportion to weight. The flow equation maps cleanly:
- `base_rate(p)` ↔ the task's nice-derived weight.
- `eff(p)` ↔ an *effective weight* = own weight + Σ effective weight of tasks
  blocked on a lock `p` holds.
- Implement by, when a task blocks on a kernel mutex/futex, adding its effective
  weight to the holder's effective weight (transitively), and removing it on
  release. Feed effective weight into the EEVDF/CFS share calculation instead of
  the static weight.
- This is close to PI-futex mechanics but applied to fair-share weights and
  computed from the wait-graph rather than stored per-mutex.

**Option 2 (deeper, more invasive): a new `sched_class`.**
A standalone scheduling class `SCHED_FLOW` that maintains the wait-graph and does
the instantaneous rate-proportional split directly. More faithful to the toy, far
more work, and must interoperate with the existing classes. Treat as stretch.

Start with Option 1. The hook points:
- `__mutex_lock` / `rt_mutex` slow path, and the futex wait path: on enqueue to a
  wait, record the wait-edge (waiter → owner) and propagate effective weight up the
  chain (mirror `rt_mutex_adjust_prio_chain`, but summing weights, not taking max).
- lock release / wake: tear down the edge, recompute effective weight (just drop
  the waiter's contribution — memoryless, nothing stored to "restore").
- `update_curr` / place_entity: use effective weight in the share/vruntime
  calculation.

**Key difference from classical PI to preserve:** classical PI takes the *max*
priority along the chain. The flow equation *sums* effective rates. Implement the
sum (that is the conserved-flow semantics: the holder catches the *total* energy of
everyone waiting on it, not just the most urgent). Document the divergence and
measure both if feasible.

### A2. Test harness — UML first, then containers

Progression, cheapest to most realistic:

1. **UML (User Mode Linux).** Build the patched kernel as a UML binary; boot it
   with a minimal rootfs. Fast iteration, easy instrumentation, no risk to host.
   Run the inversion microbenchmark (A3) here first.
2. **Docker / OCI containers on the patched kernel.** Once UML passes, boot the
   patched kernel on a VM (or bare metal) and run the same workloads inside
   containers, to confirm the scheduler behaves under cgroup CPU controllers and
   container PID namespaces.
3. **Native.** Final: native boot, real multi-core, real workloads.

### A3. The inversion microbenchmark (the core test)

Reproduce the Mars Pathfinder shape and measure inversion exposure:
- **LOW** (nice +10): acquires shared mutex S, holds it across a bounded critical
  section, releases.
- **HIGH** (nice −10): periodically must acquire S; blocks when LOW holds it.
- **MED** (nice 0): CPU-bound busy loop, never touches S.
- Pin all three to ONE CPU (force contention).

Metrics to collect (per scheduler config):
- **HIGH's blocking time** (acquire request → grant). The inversion is unbounded
  under stock CFS without PI; bounded under flow.
- **MED's CPU share while HIGH is blocked.** Stock CFS: MED feasts (this is the
  bug). Flow: MED is throttled because LOW caught HIGH's weight — confirm MED's
  share drops and LOW's rises, matching the toy's 0.77/0.23 split.
- **Throughput / completion time** of HIGH.

Compare four configs: (a) stock CFS no PI, (b) stock + PI-futex, (c) flow scheduler
(sum), (d) flow scheduler (max, to compare against classical PI). Expected: (c) and
(d) both bound HIGH's blocking and stop MED feasting; (c) routes the *total* waiter
weight (more aggressive holder boost when many wait).

Instrument with ftrace / sched tracepoints and/or bpftrace; record the wait-edge
propagation events.

### A4. Acceptance criteria (Part A)

1. Patched kernel builds and boots under UML.
2. Inversion microbenchmark shows: under flow, HIGH's blocking time is bounded and
   MED's share collapses while HIGH is blocked (LOW catches the flow) — versus
   stock CFS where MED feasts and HIGH's blocking is unbounded.
3. The flow reverts on release with no residual boost (verify: after S is freed,
   LOW's effective weight returns to its base — memoryless, nothing "restored"
   because nothing was stored).
4. Same behavior holds inside a container on the patched kernel.
5. A `FINDINGS.md`: what broke, what the wait-graph propagation cost in practice,
   and whether sum-vs-max materially changed outcomes.

---

## PART B — THE ZOMBIE FIX (bonus, same principle)

### B0. The principle, restated for process exit

A zombie is a dead task whose exit state (PID, exit code, rusage) is held in the
process table *because someone might collect it via `wait()`*. It is a **stranded
claim**: state retained for a collector who may never come (parent never `wait`s,
parent is buggy, parent died). Today Linux patches this with scattered mechanisms —
`SA_NOCLDWAIT` (discard status, no zombie), `SIG_IGN` on SIGCHLD (auto-reap),
reparent-to-init/subreaper (PID 1 collects orphans). These are partial and opt-in.

The conservation principle says: **hold the exit state only if someone will
actually collect it. If the collector declared it does not care, or the collector
is gone, reclaim immediately.** No state is held that no one will read.

### B1. The new syscall

Design a syscall by which a parent (or any waiter) registers, *in advance*, exactly
where it wants a child's result delivered — and crucially, declares when it does
*not* care:

```
// Register interest in a child's exit result, delivered into `buf` on exit.
//   buf, buflen : where the kernel writes the exit result when the child exits.
//                  Layout: { int exit_code; struct rusage ru; } (or a versioned
//                  struct). Kernel fills it and (optionally) wakes a futex/eventfd.
//   if buflen == 0  => caller does NOT care about the exit code/rusage.
//                      The kernel must NOT create a zombie for this child:
//                      reclaim its task_struct/exit state immediately on exit.
//   flags : e.g. FLOW_EXIT_EVENTFD (signal an eventfd), FLOW_EXIT_FUTEX (wake a
//           futex word at buf), FLOW_EXIT_ONESHOT, etc.
//
// Returns 0 on success.
long sys_flow_reap(pid_t child, void __user *buf, size_t buflen, int flags);
```

Semantics (the two rules that kill all zombies):

1. **len-0 buffer ⇒ "I don't care about the exit code."** Equivalent to a precise,
   per-child `SA_NOCLDWAIT`: the child's exit state is reclaimed the instant it
   exits; no zombie is ever created for it. (Generalizes the existing flag from
   "all children" to "this child, declared up front.")

2. **Parent gone ⇒ "I don't care either."** If the registered collector (or the
   parent, if none registered) has itself exited by the time the child exits,
   there is no one to deliver to, so the exit state is reclaimed immediately rather
   than reparented-and-held. (Generalizes orphan reaping: instead of reparenting to
   PID 1 and *hoping* PID 1 `wait`s, the kernel reclaims directly because the
   collector is provably gone.)

When `buflen > 0` and the collector is alive: on child exit, the kernel writes
`{exit_code, rusage}` into `buf`, optionally signals the eventfd/futex named in
`flags`, and reclaims the task — no `wait()` call required, no zombie window beyond
the write. The result is *pushed* to the buffer rather than *pulled* by `wait()`.

### B2. Why this kills zombies everywhere

- **Forgotten `wait()` (the Go `cmd.Start()` bug, PHP-FPM, etc.):** if the parent
  used `flow_reap` with len-0, there is nothing to forget — the kernel reclaims on
  exit. If it used len>0, the result is delivered to the buffer without a `wait()`
  call, so "forgetting to wait" cannot strand state.
- **Buggy/blocked parent:** delivery is a kernel-side push on child exit, not a
  parent-side pull, so a parent stuck in IO or missing a SIGCHLD handler does not
  create a zombie.
- **Dead parent / orphan:** rule 2 reclaims immediately instead of reparenting and
  hoping. No dependence on PID 1 or a subreaper calling `wait()`.

This is the exit-path image of the scheduler result: the scheduler refuses to
strand a *scheduling claim* on a blocked task (it flows to the holder); the exit
path refuses to strand *exit state* on a dead task (it is delivered or reclaimed,
never held for an absent collector). Both are conservation: don't hold what no one
will convert/collect.

### B3. Implementation sketch (kernel)

- Add a per-`task_struct` field: an optional "exit delivery target"
  (`struct flow_reap_target { struct task_struct *collector; void __user *buf;
  size_t buflen; int flags; struct eventfd_ctx *efd; }`), set by `sys_flow_reap`.
- In `do_exit` / `exit_notify` (kernel/exit.c): if the exiting task has a
  delivery target:
    - if `buflen == 0`: skip zombie creation entirely — go straight to
      `release_task`-equivalent after recording nothing.
    - if `buflen > 0` and `collector` is alive: copy the result to `buf` (carefully
      — `buf` is in the collector's address space; use the same machinery as
      `waitid`'s `copy_to_user` of `siginfo`/`rusage`, attached to the collector mm),
      signal eventfd/futex, then `release_task`.
    - if the collector is gone (check at exit time): reclaim immediately (rule 2).
- Interaction with `wait()`/`waitid`: a child claimed by `flow_reap` should be
  invisible to the parent's `wait()` (its status was redirected), exactly as a
  `SA_NOCLDWAIT` child is. Define this precedence explicitly.
- Security/lifetime: pin the collector's mm or use a deferred-work context so the
  `copy_to_user` target is valid at child-exit time; handle the
  collector-exits-after-registering-but-before-child race (falls to rule 2).

### B4. Test plan (Part B)

- **No-zombie under forgotten wait:** spawn a child with `flow_reap(child, NULL, 0,
  0)`, let the child exit, never `wait()`; assert no `Z` entry ever appears in
  `/proc` and the PID is freed. Stress: spawn 100k such children, assert PID table
  never accumulates defunct entries (the `pid_max` exhaustion failure mode is gone).
- **Result delivery without wait:** `flow_reap(child, &buf, sizeof buf, EVENTFD)`,
  child exits with code 42; assert `buf.exit_code == 42`, rusage populated, eventfd
  signaled, and no zombie window (poll `/proc` tightly).
- **Dead-parent reclaim:** parent registers (or not), parent exits before child;
  child then exits; assert child's state is reclaimed immediately, not reparented
  and held. Compare against stock kernel (which reparents to PID 1).
- **Precedence vs wait():** confirm a `flow_reap`-claimed child is not also
  reportable by `wait()` (no double-reap, no lost status).
- Container test: same under a PID namespace where the namespace's PID 1 is NOT a
  proper init (the classic "Docker app as PID 1 doesn't reap" case) — assert
  zombies still do not accumulate, because reclaim no longer depends on PID 1.

### B5. Acceptance criteria (Part B)

1. `sys_flow_reap` implemented; len-0 path creates no zombie; len>0 path delivers
   result to buffer + eventfd/futex without a `wait()` call.
2. Dead-collector path reclaims immediately (no reparent-and-hold).
3. 100k forgotten-wait children leave zero defunct entries and do not grow the PID
   table.
4. Works inside a PID namespace with a non-reaping PID 1 (the Docker case).
5. `FINDINGS.md`: the `copy_to_user`-at-exit lifetime issues, the wait() precedence
   decision, and any race that required care.

---

## Out of scope (both parts)

- Upstreaming / mainline submission (this is a research exam, not a patch series).
- Real-time correctness proofs of the flow scheduler (separate from the blocking
  bound *measurement* in A3).
- ABI stability of `flow_reap`'s buffer struct (version it, but do not promise
  stability).
- Replacing all of `wait()`/`waitid` — `flow_reap` is additive; the legacy path
  stays for compatibility.

## The unifying note (for the FINDINGS and the paper)

Both parts are the same sentence: **do not hold a claim that no one will convert.**
The scheduler will not let a blocked task hold a scheduling claim it cannot use —
the claim flows to the holder who can. The exit path will not let a dead task hold
exit state no one will collect — it is delivered to whoever asked, or reclaimed if
no one did. Stranded claims are the disease in both the deadlock/inversion world
and the zombie world; conservation — route it to who can use it, or reclaim it — is
the cure in both. Energy flows where attention goes; and where no attention goes,
nothing is held.
