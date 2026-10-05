# Ordered shutdown design

## Model sizing and process hierarchy

An ordered shutdown sequence resembles a staged factory shutdown where downstream conveyor belts must halt before upstream sorting arms power down. If an upstream machine continues feeding items while downstream belts stop, parts spill onto the factory floor. In my model of a generic service, three worker processes form an explicit linear dependency chain. Process 2 cannot terminate before process 1 finishes, and process 3 cannot terminate before process 2 completes.

For the model sizing, I chose three processes because three is the smallest set that verifies transitive ordering behaviour. With two processes, we can only verify pairwise precedence, whereas three processes reveal whether middle stages skip dependencies. Moreover, restricting the process set to three keeps the reachable state graph at 780 distinct states during TLC model checking. Still, this three-process model abstracts away larger cluster topologies where dozens of workers cause state-space explosion.

## State variables and data domain

State variables capture the internal runtime coordinates and external observable status of a service instance. We can picture a physical server chassis fitted with status lights, internal disk activity lamps, and running process indicators. In this specification, I define four core variables: `alive`, `flushed`, `status`, and `stop_requested`, plus a bounded `cycles` counter. The variable `alive` tracks the set of active worker identifiers, taking values from the subsets of `{1, 2, 3}`.

Regarding internal durability, `flushed` is a boolean flag that records whether buffered data has been flushed to persistent storage. In contrast, `status` represents the state variable read by the monitoring user interface, taking either `"running"` or `"stopped"`. The boolean variable `stop_requested` records whether an operator has issued a stop action to the service instance. However, representing the status variable as a two-valued string omits intermediate draining labels that some monitoring consoles display.

## Initial system state

The initial state predicate establishes the baseline configuration of the service before any shutdown command arrives. We can think of a running backend service handling live client sessions under normal traffic conditions. In this initial state, all three ordered processes are active, so `alive` equals the complete set `{1, 2, 3}`. Furthermore, buffered data has not yet been flushed for shutdown, which means that `flushed` starts as `FALSE`.

For the monitoring interface, the state variable `status` begins with the string `"running"`, and `stop_requested` starts as `FALSE`. This configuration ensures that no teardown step executes before an explicit stop action is triggered by an operator. In the same vein, the initial predicate rules out partially initialised instances where workers fail during startup. Still, assuming a clean starting state excludes recovery scenarios where processes restart after an unexpected host crash.

## Naive timeout behaviour versus wrapper steps

In the failure scenario this model captures, using the standard library stop call causes an unintended side effect during service shutdown. Because flushing buffered data and terminating processes in strict order took longer, the call timed out and returned an empty response. That empty response caused the caller to set `status` to `"stopped"` before data was flushed and before all processes terminated. Consequently, the monitoring user interface reported the service as stopped while background processes were still flushing and shutting down.

To solve this problem, the model uses a wrapper layer that acts as the single source of truth for the status variable. In our corrected PlusCal model, the controller flushes storage after `stop_requested` becomes `TRUE`, and workers `1..3` terminate in strict sequential order. Only after `alive = {} /\ flushed = TRUE` holds does the wrapper move `status` to `"stopped"` in the final step. Still, waiting synchronously for sequential process termination increases total shutdown duration compared to unordered termination.

## State invariants and model boundaries

State invariants define boolean predicates that must hold across every reachable state discovered by the TLC model checker. We can think of mechanical interlocks inside an industrial press that prevent the blade from dropping while a guard door remains open. In our model, the primary safety invariant is `StatusConsistent == (status = "stopped") => (alive = {} /\ flushed = TRUE)`. This formula states that the `status` variable must never report `"stopped"` before data is flushed and all processes have terminated.

Alongside `TypeOK`, I also define the ordering invariant `OrderConsistent == (1 \in alive => 2 \in alive) /\ (2 \in alive => 3 \in alive)`. Together, these state invariants verify that worker 2 never terminates before worker 1, and worker 3 never exits before worker 2. When TLC checks `ShutdownFixed.tla`, it confirms that all three state invariants hold across every reachable state in the model. However, this specification checks three state invariants and one liveness property (`StopCompletes`) across three processes; expressing richer temporal properties requires linear or branching temporal logics (LTL and CTL).
