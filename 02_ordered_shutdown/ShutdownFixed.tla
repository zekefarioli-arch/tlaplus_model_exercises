---------------------------- MODULE ShutdownFixed ----------------------------
(*
 * Corrected shutdown sequence for a service node.
 * Uses concurrent PlusCal processes for the controller and workers.
 * The controller initiates shutdown and flushes storage, then awaits
 * full worker termination before setting status to "stopped".
 * Workers terminate in strict sequential order: 1 before 2, 2 before 3.
 *)
EXTENDS Naturals, FiniteSets

(* --algorithm ShutdownFixed
variables
    alive = {1, 2, 3},
    flushed = FALSE,
    status = "running",
    stop_requested = FALSE;

process controller = 0
begin
    RequestStop:
        stop_requested := TRUE;
    FlushStorage:
        flushed := TRUE;
    AwaitCompletion:
        await alive = {} /\ flushed = TRUE;
    MarkStopped:
        status := "stopped";
end process;

process worker \in 1..3
begin
    WaitTurn:
        await stop_requested /\ flushed /\ \A prev \in 1..(self - 1) : prev \notin alive;
    Terminate:
        alive := alive \ {self};
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "10f43f2f" /\ chksum(tla) = "465f5c66")
VARIABLES alive, flushed, status, stop_requested, pc

vars == << alive, flushed, status, stop_requested, pc >>

ProcSet == {0} \cup (1..3)

Init == (* Global variables *)
        /\ alive = {1, 2, 3}
        /\ flushed = FALSE
        /\ status = "running"
        /\ stop_requested = FALSE
        /\ pc = [self \in ProcSet |-> CASE self = 0 -> "RequestStop"
                                        [] self \in 1..3 -> "WaitTurn"]

RequestStop == /\ pc[0] = "RequestStop"
               /\ stop_requested' = TRUE
               /\ pc' = [pc EXCEPT ![0] = "FlushStorage"]
               /\ UNCHANGED << alive, flushed, status >>

FlushStorage == /\ pc[0] = "FlushStorage"
                /\ flushed' = TRUE
                /\ pc' = [pc EXCEPT ![0] = "AwaitCompletion"]
                /\ UNCHANGED << alive, status, stop_requested >>

AwaitCompletion == /\ pc[0] = "AwaitCompletion"
                   /\ alive = {} /\ flushed = TRUE
                   /\ pc' = [pc EXCEPT ![0] = "MarkStopped"]
                   /\ UNCHANGED << alive, flushed, status, stop_requested >>

MarkStopped == /\ pc[0] = "MarkStopped"
               /\ status' = "stopped"
               /\ pc' = [pc EXCEPT ![0] = "Done"]
               /\ UNCHANGED << alive, flushed, stop_requested >>

controller == RequestStop \/ FlushStorage \/ AwaitCompletion \/ MarkStopped

WaitTurn(self) == /\ pc[self] = "WaitTurn"
                  /\ stop_requested /\ flushed /\ \A prev \in 1..(self - 1) : prev \notin alive
                  /\ pc' = [pc EXCEPT ![self] = "Terminate"]
                  /\ UNCHANGED << alive, flushed, status, stop_requested >>

Terminate(self) == /\ pc[self] = "Terminate"
                   /\ alive' = alive \ {self}
                   /\ pc' = [pc EXCEPT ![self] = "Done"]
                   /\ UNCHANGED << flushed, status, stop_requested >>

worker(self) == WaitTurn(self) \/ Terminate(self)

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == controller
           \/ (\E self \in 1..3: worker(self))
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
