# Formal specifications with TLA+ and PlusCal

## Repository overview and motivation

Formal specification provides a mathematical foundation for verifying concurrent backend architectures before committing code to production. We can compare formal modelling to the stress calculations that structural engineers perform on paper before pouring suspension bridge anchors. In this repository, I document my progression learning TLA+ and PlusCal to move from empirical testing to formal verification. Specifying state machines mathematically allows us to catch subtle ordering bugs that escape ordinary unit and integration test suites.

For these projects, I focus specifically on discrete state transitions, process ordering constraints, and safety invariant verification. Empirical testing samples only a small fraction of concurrent executions; in contrast, the TLC model checker verifies every reachable state. Moreover, writing formal specifications forces me to define explicit state invariants before writing concrete application code. Still, checking three state invariants and one liveness property across small models leaves richer temporal logic and state-space explosion as clear next steps.

## Included projects

The repository contains two verified projects organised sequentially to trace my progression from pure TLA+ to concurrent PlusCal. In [01_hour_clock](./01_hour_clock), the first specification models a discrete twelve-hour clock in pure TLA+ and analyses a counterexample in [BROKEN_TRACE.md](./01_hour_clock/BROKEN_TRACE.md). In [02_ordered_shutdown](./02_ordered_shutdown), the second project models an ordered service shutdown in PlusCal across three ordered processes. It reproduces a timeout bug in [ShutdownLegacy.tla](./02_ordered_shutdown/ShutdownLegacy.tla) and verifies the wrapper solution in [ShutdownFixed.tla](./02_ordered_shutdown/ShutdownFixed.tla).

Regarding engineering complexity, the second project separates data flushing from ordered process termination across three concurrent workers. While the twelve-hour clock model explores only twelve states, the ordered shutdown model explores 780 distinct states across interleaved transitions. Furthermore, the second directory includes a design document and trace analysis explaining every modelling decision in detail. However, this model checks a state invariant across only three processes, whereas larger distributed systems face severe state-space explosion.

## Verification environment and tooling

Verifying formal specifications locally requires a standard Java runtime environment and the official standalone distribution archive of `tla2tools.jar`. On any Linux development machine, we can download the archive directly into `/tmp` and run the verification toolchain using these terminal commands:

```bash
curl -sL https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar -o /tmp/tla2tools.jar
java -cp /tmp/tla2tools.jar pcal.trans SpecName.tla
java -XX:+UseParallelGC -cp /tmp/tla2tools.jar tlc2.TLC -workers auto SpecName.tla -config SpecName.cfg
```

After `pcal.trans` updates the generated TLA+ translation block inside the module, we invoke the TLC model checker with parallel garbage collection. Executing TLC with automatic worker threads allows us to verify hundreds of reachable states within a single second. Still, running explicit Java command lines manually becomes repetitive during iterative modelling; a shell script would remove that repetition, but I have not written one yet.

## Methodological takeaways and next steps

The central lesson from this repository is that passing empirical test suites in development and acceptance environments cannot guarantee correctness. Safety invariants such as `StatusConsistent` verify that the status variable never reports `"stopped"` before data is flushed and all processes terminate. When the original behaviour updated the status early after a timeout, TLC immediately reproduced, as a two-state trace, the premature status that a naive timeout handler produces. After moving the status update to the final step, TLC verified that the invariant held across every reachable state. I then added weak fairness to the controller and the workers and checked `StopCompletes`, a liveness property stating that every stop request ends in `"stopped"`; without the fairness assumption TLC rejects it, so the check is not vacuous.

Still, building these specifications showed me how much mathematical theory remains beyond basic state invariants. Whereas my PlusCal model checks three safety invariants and a single liveness property across three processes, real distributed systems require richer linear and branching temporal logics. Therefore, my next goal is to study LTL, CTL, and symbolic model checking techniques that address state-space explosion.
