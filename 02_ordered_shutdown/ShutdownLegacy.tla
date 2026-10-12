--------------------------- MODULE ShutdownLegacy ---------------------------
(*
 * Legacy (naive) shutdown sequence for a service node.
 * Because the ordered shutdown takes longer, the standard call times out and
 * returns an empty response, setting status to "stopped" before data is flushed.
 *)
EXTENDS Naturals, FiniteSets

(* --algorithm ShutdownLegacy
variables
    alive = {1, 2, 3},
    flushed = FALSE,
    status = "running",
    stop_requested = FALSE;

process controller = 0
begin
    RequestStop:
        stop_requested := TRUE;
        status := "stopped"; \* Standard call times out and returns empty response, setting status early
    FlushStorage:
        flushed := TRUE;
    StopWorker1:
        alive := alive \ {1};
    StopWorker2:
        alive := alive \ {2};
    StopWorker3:
        alive := alive \ {3};
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "3e38b84b" /\ chksum(tla) = "98399b52")
VARIABLES alive, flushed, status, stop_requested, pc

vars == << alive, flushed, status, stop_requested, pc >>

ProcSet == {0}

Init == (* Global variables *)
        /\ alive = {1, 2, 3}
        /\ flushed = FALSE
        /\ status = "running"
        /\ stop_requested = FALSE
        /\ pc = [self \in ProcSet |-> "RequestStop"]

RequestStop == /\ pc[0] = "RequestStop"
               /\ stop_requested' = TRUE
               /\ status' = "stopped"
               /\ pc' = [pc EXCEPT ![0] = "FlushStorage"]
               /\ UNCHANGED << alive, flushed >>

FlushStorage == /\ pc[0] = "FlushStorage"
                /\ flushed' = TRUE
                /\ pc' = [pc EXCEPT ![0] = "StopWorker1"]
                /\ UNCHANGED << alive, status, stop_requested >>

StopWorker1 == /\ pc[0] = "StopWorker1"
               /\ alive' = alive \ {1}
               /\ pc' = [pc EXCEPT ![0] = "StopWorker2"]
               /\ UNCHANGED << flushed, status, stop_requested >>

StopWorker2 == /\ pc[0] = "StopWorker2"
               /\ alive' = alive \ {2}
               /\ pc' = [pc EXCEPT ![0] = "StopWorker3"]
               /\ UNCHANGED << flushed, status, stop_requested >>

StopWorker3 == /\ pc[0] = "StopWorker3"
               /\ alive' = alive \ {3}
               /\ pc' = [pc EXCEPT ![0] = "Done"]
               /\ UNCHANGED << flushed, status, stop_requested >>

controller == RequestStop \/ FlushStorage \/ StopWorker1 \/ StopWorker2
                 \/ StopWorker3

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == controller
           \/ Terminating

Spec == Init /\ [][Next]_vars

Termination == <>(\A self \in ProcSet: pc[self] = "Done")

\* END TRANSLATION 

\* Invariants
TypeOK ==
    /\ alive \in SUBSET (1 .. 3)
    /\ flushed \in BOOLEAN
    /\ status \in {"running", "stopped"}
    /\ stop_requested \in BOOLEAN

StatusConsistent ==
    (status = "stopped") => (alive = {} /\ flushed = TRUE)

OrderConsistent ==
    /\ (1 \in alive => 2 \in alive)
    /\ (2 \in alive => 3 \in alive)

=============================================================================
