# Twelve-hour clock specification

## System overview and model sizing

A discrete clock specification models time as an ordered sequence of discrete state transitions. We can think of a standard analogue wall clock whose single hour hand steps forward between numbered positions on a circular dial. In this project, I specified a twelve-hour clock to learn state invariants in pure TLA+ before modelling concurrent systems. However, this minimalist scope ignores minutes and sub-second precision; it serves only as a foundation for learning formal state machines.

## State transitions without a program counter

Formal specifications in pure TLA+ describe systems through mathematical relations rather than sequential computer instructions. When I write standard backend software, I usually think of execution as a sequence of lines steered by an invisible program counter. In contrast, TLA+ defines execution purely as a pair of predicates: an initial condition `Init` and a next-state relation `Next`. Still, specifying systems in this declarative style forces us to write explicit priming equations for every variable that changes.

Moreover, the next-state relation relies on an explicit conditional branch to reset the counter when it reaches twelve. The formula `hr' = IF hr # 12 THEN hr + 1 ELSE 1` ensures that the transition stays confined within the twelve-hour set. Because pure TLA+ lacks built-in looping constructs, we must encode wrap-around behaviour through pure propositional logic. However, declaring actions as raw logical relations becomes mentally demanding once a system requires ordered multi-step phases.

## Safety invariants and counterexample analysis

A safety invariant is a boolean formula that must evaluate to true across every reachable state of a formal specification. In this model, I declared `TypeOK == hr \in (1 .. 12)` to guarantee that `hr` never exceeds twelve or drops below one. As documented in the [broken trace investigation](./BROKEN_TRACE.md), TLC generated an exact two-state counterexample when I omitted the conditional reset. However, verifying a single-variable type invariant does not address the concurrent process ordering challenges found in distributed services.

## Terminal execution and verification commands

Running the TLC model checker from the terminal provides immediate feedback on state-space exploration and state invariant satisfaction across all reachable states. For this twelve-hour clock project, we execute the model checker from the command line using the official standalone Java archive:

```bash
java -XX:+UseParallelGC -cp /tmp/tla2tools.jar tlc2.TLC -workers auto 01_hour_clock/HourClock.tla -config 01_hour_clock/HourClock.cfg
```

When TLC evaluates this configuration, it reports twelve distinct states generated across a complete search depth of one. Besides, the breadth-first search algorithm verifies that every initial state transitions safely into another valid hour without deadlocks. Still, executing standalone Java commands manually becomes cumbersome during rapid iterations; a shell script would automate these checks, but I have not written one yet.

## The limits of pure TLA+ for sequential workflows

Pure TLA+ excels at modelling declarative relations, but it introduces heavy syntactic overhead for multi-step procedural logic. In real backend services, operations proceed through explicit sequential phases: receiving a command, flushing data, and terminating processes in order. If I model such phased algorithms in pure TLA+, I must manually declare program counters and manage transition guards for every step. Therefore, my next project in [02_ordered_shutdown](../02_ordered_shutdown) uses PlusCal to model an ordered service shutdown sequence from memory.
