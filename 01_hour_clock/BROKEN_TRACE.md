# Broken trace investigation

## The broken transition experiment

An unguarded transition is a state machine step that fails to constrain the successor state within the intended domain. We can think of an analogue wall clock whose mechanical gear slips off its dial peg instead of rotating back to one. In this experiment, I deliberately altered the `Next` action to `hr' = hr + 1` by removing the conditional guard. So the successor state can escape the set of twelve valid hours; the variable simply grows without any natural ceiling.

For this experiment, I configured TLC to check the state invariant `TypeOK` alongside the broken specification. The model checker immediately flagged the unbounded step during its breadth-first exploration of the reachable states. However, this simple failure highlights a broader design problem; pure arithmetic cannot represent cyclic domains without explicit conditional logic. Finally, the unguarded formulation costs us correctness because the model checker cannot find a closed cycle of states.

## The raw TLC counterexample

When we run the TLC model checker against the unguarded transition formula, the engine halts immediately upon finding an invariant violation. The following console output shows the exact two-state counterexample trace produced by TLC when verifying the broken clock specification from the terminal:

```text
Error: Invariant TypeOK is violated.
Error: The behavior up to this point is:
State 1: <Initial predicate>
hr = 12

State 2: <Next line 12, col 9 to line 12, col 20 of module HourClock>
hr = 13

24 states generated, 13 distinct states found, 0 states left on queue.
The depth of the complete state graph search is 2.
The average outdegree of the complete state graph is 0 (minimum is 0, the maximum 0 and the 95th percentile is 0).
Finished in 00s at (2026-09-30 17:04:12)
```

Regarding the state exploration, TLC stopped immediately after identifying thirteen distinct states in the breadth-first queue. The engine evaluated twenty-four state transitions before reporting the state invariant violation to the terminal. Moreover, the tool terminated with an exit code of twelve; this exit code indicates that an invariant was violated. Still, reading raw terminal traces manually becomes harder when specifications contain dozens of concurrent variables.

## Step-by-step trace walkthrough

A counterexample trace represents a sequence of concrete states leading from an initial condition to an illegal state. In State 1, we observe that TLC chooses `hr = 12` from the twelve possibilities declared in the initial predicate. The model checker tests all initial values in parallel; here it selects the exact boundary value that exposes our missing guard. Furthermore, this initial state satisfies `TypeOK` because twelve belongs to the set of valid natural hours.

In State 2, we follow the transition through the broken `Next` action to `hr = 13`. The formula evaluates `12 + 1` directly because we removed the conditional branch that resets the counter to one. Consequently, `TypeOK` evaluates to false; thirteen does not belong to the set of natural numbers up to twelve. Still, TLC halts before generating further numbers, which keeps our counterexample trace short and deterministic.

## Engineering takeaway

State invariants act as mathematical safety boundaries across every reachable state of a formal specification. When I write backend services, I often rely on database column constraints to reject invalid integer values before persistence occurs. In TLA+, the `TypeOK` formula serves that exact purpose by bounding variable values during exhaustive state exploration. Besides, writing explicit state invariants forces us to define valid operational ranges before we model multi-process transitions.

Regarding model correctness, restoring the conditional guard in `Next` immediately eliminates this unbounded trajectory. The fix ensures that state twelve loops back to state one; this produces a closed state graph of twelve states. However, checking a single variable in pure TLA+ does not capture ordered process dependencies during service teardown. Therefore, our next step moves to PlusCal to model three ordered processes and data flushing in a service shutdown sequence.
