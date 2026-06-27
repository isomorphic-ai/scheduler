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

## PART A — THE FLOW-EQUATION SCHEDULER (REPLACE THE FAIR SCHEDULER)

### A0. What we are porting, and the actual goal

The toy (`iso_flow.py`) schedules by *effective rate*: each instant, runnable tasks
split the CPU in proportion to `eff(p) = base_rate(p) + Σ eff(w)` over every task
`w` blocked on `p`, transitively. A blocked task is not runnable, so its rate flows
down its wait-edge into the holder it is blocked on. Consequences validated in the
toy: a high task blocked on a low holder pours its weight into the holder (holder's
effective share jumps; an unrelated busy task does NOT feast); the holder clears
its critical section fast; the instant the lock frees the flow reverts with no
penalty (memoryless). Priority inversion is structurally absent.

**The goal is replacement, not addition.** This exam does NOT add a `SCHED_FLOW`
class beside CFS/EEVDF, and does NOT merely tweak a few weights inside the existing
fair scheduler. The goal is to make the flow equation *the* fair scheduler — the
policy that `SCHED_NORMAL`/`SCHED_BATCH` tasks (the vast majority of every Linux
system) actually run under. Effective weight, computed from the live wait-graph, is
the weight the fair-share engine uses, everywhere, by default. When this is done,
"priority inheritance" is not a feature the kernel offers; it is simply how the
scheduler weights tasks, and the PI-futex special case becomes redundant for the
fair class because the general flow already does it.

A `SCHED_FLOW` class or a thin weight-modifier is acceptable ONLY as a stepping
stone for the pre-check (A1), to validate the mechanism cheaply before committing
to the replacement. The deliverable is the replacement.

### A1. Pre-check first (cheap validation), then replace

**Stage 0 — pre-check (allowed shortcut, throwaway).** To de-risk before touching
the fair scheduler's core, first validate the flow mechanism the cheap way: a small
hook that, on a kernel mutex/futex block, adds the waiter's effective weight to the
holder and feeds it into the existing share calc. Run the A3 microbenchmark. If the
inversion collapses as predicted, the mechanism is sound and we proceed to
replacement. This stage is a throwaway probe, not the deliverable — do not polish
it.

**Stage 1 — replace the fair scheduler's weight with effective weight.** Make
effective weight the weight CFS/EEVDF uses, structurally:
- The fair scheduler (EEVDF in 6.6+, CFS before) computes each entity's CPU share /
  lag / vruntime from `load.weight` (derived from nice). Replace the *source* of
  that weight: an entity's scheduling weight becomes its **effective weight** =
  own nice-weight + Σ effective weight of all tasks currently blocked on a resource
  this entity holds, transitively over the wait-graph.
- This is not a per-mutex stored boost (that is classical PI). It is a property
  recomputed from the wait-graph: the weight a task is scheduled with at any instant
  is a pure function of the current wait-graph and the nice-weights. Memoryless: no
  stored boost to restore on release; when the edge disappears the weight
  recomputes.
- Every `SCHED_NORMAL` task is scheduled this way. The default behavior of the
  system changes: weight flows along dependency edges for all fair tasks.

### A2. Where it lands in the kernel (replacement)

The fair scheduler is `kernel/sched/fair.c`; weights live in `struct load_weight`
on each `struct sched_entity`, set from nice via `set_load_weight()` and consumed
throughout EEVDF/CFS (`update_curr`, `place_entity`, vruntime/lag, `calc_delta_fair`,
group shares in `calc_group_shares`).

The replacement touches three things:

1. **The wait-graph.** Maintain, per runqueue (and cross-CPU where a holder runs
   elsewhere), the edges "task W is blocked on a lock held by task O." Hook the
   block/wake paths: `__mutex_lock` slow path, rwsem, futex wait
   (`futex_wait_queue`), and the rt_mutex chain. On block, add edge W→O and
   propagate W's effective weight up the chain to O (and O's holders, transitively).
   On wake/release, remove the edge and recompute. This is structurally similar to
   `rt_mutex_adjust_prio_chain`, but it (a) **sums** weights instead of taking the
   max priority, and (b) applies to the **fair** class, not just rt_mutex.

2. **The weight source.** Introduce `effective_weight(se)` and route the fair
   scheduler's weight reads through it. Cleanest: keep `load.weight` as the base
   (nice-derived) and add `eff_weight` updated by the wait-graph propagation;
   change the consumers in `fair.c` to use `eff_weight`. Audit every site that
   reads `se->load.weight` for share/vruntime/lag and decide per site whether it
   should see base or effective (mostly effective; group accounting needs care).

3. **EEVDF lag/eligibility.** EEVDF computes lag and eligibility from weight.
   Effective weight changes a task's deserved share mid-flight when it catches
   flow; ensure lag accounting stays consistent when weight jumps up (holder
   catches a waiter) and down (lock released). This is the subtle part — a weight
   that changes at block/release time must not corrupt the EEVDF invariants
   (zero-lag sum, eligibility). Document how you keep the lag books balanced when
   effective weight changes; this is the conservation law (Paper 04, L1) showing up
   as "weight moved between entities must balance."

**Key semantic to preserve (sum, not max).** Classical PI takes the max priority
along the chain. The flow equation SUMS effective weights: a holder with three
high-weight waiters catches all three weights, not just the largest. This is the
conserved-flow semantics and the intended divergence from classical PI. Implement
the sum; the EEVDF lag bookkeeping above must balance against this sum.

### A2b. Risks specific to replacement (read before starting)

- **Every fair task is affected**, so a bug is a system-wide scheduling bug, not a
  contained class. Test on UML/VM only; never the dev host.
- **Group scheduling / cgroups.** `calc_group_shares` distributes a group's weight
  among its entities. Decide how effective weight composes with group shares
  (does a blocked task's flow cross the cgroup boundary to its holder in another
  group? Probably it must, since the dependency is real — but this has fairness and
  isolation implications worth measuring).
- **Cross-CPU wait-edges.** Holder may run on another CPU than the waiter. The
  propagation must reach the holder's runqueue (rq-lock ordering care, like the
  rt_mutex chain walk across CPUs).
- **Propagation cost.** A deep or wide wait-graph makes the transitive sum
  expensive on every block/wake. Bound it (cap chain depth like the rt_mutex chain
  limit, or memoize). Measure the overhead; this is a real cost the pre-check's
  toy did not have.
- **EEVDF invariants.** The hardest part. A live weight change must preserve the
  scheduler's lag/eligibility invariants or fairness silently breaks. Budget most
  of the effort here.

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

Compare configs: (a) stock CFS/EEVDF no PI, (b) stock + PI-futex, (c) the
**replaced fair scheduler** (effective weight, sum semantics), (d) optionally a max
variant to compare against classical PI. Expected: (c) bounds HIGH's blocking and
stops MED feasting *for ordinary `SCHED_NORMAL` tasks with no special API*, because
the fair scheduler itself now flows weight along wait-edges.

Instrument with ftrace / sched tracepoints and/or bpftrace; record the wait-edge
propagation events and the effective-weight changes.

### A4. Acceptance criteria (Part A)

1. **The fair scheduler is replaced**, not extended: `SCHED_NORMAL` tasks are
   scheduled by effective weight (own nice-weight + summed flow from blocked
   waiters) by default, with no opt-in API and no separate scheduling class. The
   pre-check probe (Stage 0) may exist in git history but is not the deliverable.
2. Patched kernel builds and boots under UML, then on a VM, with the replaced fair
   scheduler as the default for all normal tasks.
3. Inversion microbenchmark shows: under the replaced scheduler, ordinary nice-only
   tasks (no PI API) get bounded HIGH blocking and MED's share collapses while HIGH
   is blocked (LOW catches the flow) — versus stock where MED feasts.
4. The flow reverts on release with no residual boost (verify: after S is freed,
   LOW's effective weight returns to base — memoryless).
5. **EEVDF invariants preserved**: lag/eligibility accounting stays consistent
   across the live weight changes (no fairness drift, zero-lag-sum maintained).
   Demonstrate with a fairness benchmark (e.g. competing `stress-ng` / `hackbench`
   loads) that non-contending workloads are scheduled as fairly as stock.
6. Same behavior holds inside a container on the patched kernel, including across
   cgroup boundaries (document the cross-group flow decision).
7. A `FINDINGS.md`: what broke in the replacement, the wait-graph propagation cost
   under load, how EEVDF lag was kept balanced, the cross-cgroup-flow decision, and
   whether sum-vs-max materially changed outcomes.

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
