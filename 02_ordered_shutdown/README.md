# Ordered shutdown verification

## Problem background and architectural model

An ordered shutdown sequence ensures that concurrent software services terminate without losing buffered data or desynchronising monitoring state. We can think of an industrial manufacturing cell where material cutters must halt before waste extractors shut off their fans. In this project, I model the ordered shutdown of a generic service node in PlusCal, a pattern common to backend services. Modelling the behaviour abstractly allows us to verify the state transitions without reference to any particular implementation.

Consider a monitoring console that provides actions to enable, disable, start, and stop application instances across server groups. A service whose shutdown must flush data and terminate processes in a strict order is hard to wrap in a generic stop action. If the standard library call times out because the ordered teardown takes longer to complete, and the timeout returns an empty response, a naive caller may set the state variable to `"stopped"` before the processes have finished.

Consequently, the monitoring user interface becomes out of sync with the actual runtime state of the processes. A fix is a wrapper layer that waits for all processes to terminate before updating the state variable. Still, while smoke tests and acceptance testing can build confidence, empirical tests cannot guarantee correctness across every scenario.

## Model structure and state variables

State abstraction isolates the essential variables required to verify safety invariants across every reachable state of the shutdown protocol. We can picture a server control panel equipped with three process indicator lamps, a storage flush light, and a status display. In my PlusCal specification, the model state consists of `alive`, `flushed`, `status`, and `stop_requested`, alongside a bounded `cycles` counter. The set `alive` represents the three ordered service processes; it starts as `{1, 2, 3}` during normal operation.

Regarding model sizing, I modelled three ordered processes because three is the minimum number needed to test transitive ordering dependencies. Process 2 cannot terminate before process 1 finishes, and process 3 cannot terminate before process 2 exits cleanly. Furthermore, the boolean variable `flushed` explicitly separates buffered data flushing from worker process termination inside the state machine. However, modelling only three processes keeps the state graph small, whereas larger production clusters face severe state-space explosion.

## The timeout bug and TLC counterexample

The legacy specification models the naive behaviour where a standard library timeout updated the status variable prematurely. Because flushing data and stopping processes `1 -> 2 -> 3` in strict order took longer, the standard call timed out early. When that call returned an empty response, the handler immediately set `status` to `"stopped"` before teardown had actually completed. In [ShutdownLegacy.tla](./ShutdownLegacy.tla), I captured this exact sequence and defined the state invariant `StatusConsistent` to test whether the status remained accurate.

The invariant `StatusConsistent == (status = "stopped") => (alive = {} /\ flushed = TRUE)` states that `status` must never report `"stopped"` early. When I ran TLC on [ShutdownLegacy.tla](./ShutdownLegacy.tla), the model checker violated `StatusConsistent` in two states and produced the exact counterexample trace. As documented in [LEGACY_TRACE.md](./LEGACY_TRACE.md), State 2 shows `status = "stopped"` while `alive` still equals `{1, 2, 3}` and `flushed` is `FALSE`. Still, reproducing this timing discrepancy with manual tests is unreliable because it depends on exact shutdown duration thresholds.

## The wrapper solution and state invariant verification

The corrected specification in [ShutdownFixed.tla](./ShutdownFixed.tla) models the wrapper layer that acts as the single source of truth for node status. Instead of updating `status` when the stop command arrives, the controller flushes storage and waits for `alive = {} /\ flushed = TRUE`. Meanwhile, each worker process in `1..3` checks an explicit guard requiring all lower-numbered processes to leave `alive` first. Only after data is flushed and all three processes have terminated in strict order does the wrapper set `status := "stopped"`.

Furthermore, the model includes idempotent stop request handling and a clean restart rule across bounded shutdown cycles. Duplicate stop signals have no effect while teardown is running, and restarts are permitted only when `status = "stopped" /\ alive = {}`. When I moved the status update to the final step, TLC verified that `StatusConsistent` and `OrderConsistent` held across all 780 reachable states. Moreover, the controller and the workers are declared `fair`, and TLC also verifies `StopCompletes == stop_requested ~> (status = "stopped")`, which says that every stop request ends in a stopped node. Without the fairness assumption TLC rejects this property, because it finds a behaviour that stutters forever. However, this is the only temporal property so far, and it is far from the LTL and CTL work I want to do.

## Verification workflow and execution commands

Verifying both PlusCal specifications requires running the `pcal.trans` translator before invoking the TLC model checker from the Linux command line. We run the following terminal commands to translate both modules, reproduce the legacy counterexample trace, and verify the fixed wrapper specification:

```bash
java -cp /tmp/tla2tools.jar pcal.trans 02_ordered_shutdown/ShutdownLegacy.tla
java -XX:+UseParallelGC -cp /tmp/tla2tools.jar tlc2.TLC -workers auto 02_ordered_shutdown/ShutdownLegacy.tla -config 02_ordered_shutdown/ShutdownLegacy.cfg
java -cp /tmp/tla2tools.jar pcal.trans 02_ordered_shutdown/ShutdownFixed.tla
java -XX:+UseParallelGC -cp /tmp/tla2tools.jar tlc2.TLC -workers auto 02_ordered_shutdown/ShutdownFixed.tla -config 02_ordered_shutdown/ShutdownFixed.cfg
```

On `ShutdownLegacy`, TLC fails immediately on `StatusConsistent` and outputs the two-state trace where `status` becomes `"stopped"` early. On `ShutdownFixed`, TLC explores 2,695 generated states and 780 distinct states with zero invariant violations and no violation of `StopCompletes` in under one second. Still, scaling this verification to larger process groups will require symbolic model checking and abstraction techniques to handle state-space explosion.
