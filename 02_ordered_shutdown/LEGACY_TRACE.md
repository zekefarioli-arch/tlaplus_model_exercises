# Legacy shutdown trace analysis

## The timeout and empty response defect

A premature status update occurs when a monitoring layer marks a service as stopped before its ordered teardown finishes. We can compare this fault to flipping a shop sign to closed while staff are still locking the internal safes. In the modelled service, shutting down requires flushing buffered data and terminating child processes in a strict order. Because this ordered shutdown took longer than a standard service stop, calling the standard library caused an unintended side effect.

Specifically, the standard library call timed out and returned an empty response while the ordered shutdown was still running. That empty response set the `status` variable to `"stopped"` before buffered data was flushed and before the processes had terminated. Consequently, the monitoring user interface became out of sync with the actual state of the service processes. Still, catching this discrepancy through empirical testing alone was difficult because standard smoke tests focused on normal response paths.

## Step-by-step state examination

When I modelled the naive behaviour in [ShutdownLegacy.tla](./ShutdownLegacy.tla) and ran TLC, it reproduced, as a two-state trace, the behaviour of a naive timeout handler. As recorded in [legacy_bug_trace.txt](./legacy_bug_trace.txt), the model checker needed only two states to expose the violation of `StatusConsistent`. In State 1, the system starts in its initial configuration where `status` equals `"running"` and `alive` equals `{1, 2, 3}`. At this initial point, `flushed` is `FALSE`, `stop_requested` is `FALSE`, and the controller sits at label `RequestStop`.

In State 2, the controller executes `RequestStop`, which models the standard library call timing out and returning an empty response. This transition sets `stop_requested` to `TRUE` and immediately updates `status` to `"stopped"` before `FlushStorage` or worker termination can run. At that exact state, `alive` still contains `{1, 2, 3}` and `flushed` remains `FALSE`, which violates `StatusConsistent`. Still, this sequential trace captures only the state invariant failure and abstracts away real-time clock durations.

## Engineering implications and wrapper fix

Reproducing this counterexample in TLA+ highlights why empirical test suites in development and acceptance environments cannot guarantee protocol correctness. Unit and integration tests sample only the scenarios we think to write, whereas TLC checks the invariant against every reachable state. In our specification, `StatusConsistent == (status = "stopped") => (alive = {} /\ flushed = TRUE)` turns the single-source-of-truth requirement into an exact mathematical predicate. Moreover, TLC pinpoints the state invariant violation in less than a second before any deployment takes place.

To eliminate this bug, a wrapper layer waits for all service processes to terminate before updating the state variable. In [ShutdownFixed.tla](./ShutdownFixed.tla), moving `status := "stopped"` to the final step after `alive = {} /\ flushed = TRUE` resolves the invariant violation completely. However, verifying this fix across three processes only proves a state invariant on a small finite model; larger systems require symbolic model checking to handle state-space explosion.
