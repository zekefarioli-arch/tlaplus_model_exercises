---------------------------- MODULE ShutdownFixed ----------------------------
(*
 * Verified wrapper shutdown and restart sequence for a service node.
 * Features:
 *  - Strict worker termination order across three processes: 1 before 2, 2 before 3.
 *  - Buffered data flushed to storage before worker termination begins.
 *  - Wrapper waits until data is flushed and all processes terminate before setting status to "stopped".
 *  - Idempotent stop requests: duplicate stop signals have no effect during teardown.
 *  - Clean restart rule: restart allowed only when the node is stopped and fully drained.
 *)
EXTENDS Naturals, FiniteSets

CONSTANT MaxCycles

(* --algorithm ShutdownFixed
variables
    alive = {1, 2, 3},
    flushed = FALSE,
    status = "running",
    stop_requested = FALSE,
    cycles = 0;

process controller = 0
begin
    ControllerLoop:
        while cycles < MaxCycles do
            WaitForStop:
                await stop_requested /\ status = "running";
            FlushStorage:
                flushed := TRUE;
            AwaitCompletion:
                await alive = {} /\ flushed = TRUE;
            MarkStopped:
                status := "stopped";
            AwaitRestartOrFinish:
                await status = "running" \/ cycles >= MaxCycles;
        end while;
end process;

process worker \in 1..3
begin
    WorkerLoop:
        while cycles < MaxCycles do
            WaitTurn:
                await (status = "running" /\ stop_requested /\ flushed /\ \A prev \in 1..(self - 1) : prev \notin alive)
                      \/ (cycles >= MaxCycles /\ status = "stopped");
                if cycles >= MaxCycles /\ status = "stopped" then
                    goto WorkerDone;
                end if;
            Terminate:
                alive := alive \ {self};
            WaitRestart:
                await (self \in alive) \/ (cycles >= MaxCycles /\ status = "stopped");
                if cycles >= MaxCycles /\ status = "stopped" then
                    goto WorkerDone;
                end if;
        end while;
    WorkerDone:
        skip;
end process;

process operator = 4
begin
    OperatorLoop:
        while cycles < MaxCycles do
            either
                \* Send stop request (idempotent: ignored if already requested)
                RequestStop:
                    if ~stop_requested then
                        stop_requested := TRUE;
                    end if;
            or
                \* Clean restart rule: only enabled when node is stopped and fully drained
                await status = "stopped" /\ alive = {};
                RestartNode:
                    if cycles + 1 < MaxCycles then
                        alive := {1, 2, 3};
                        flushed := FALSE;
                        stop_requested := FALSE;
                        status := "running";
                    end if;
                    cycles := cycles + 1;
            end either;
        end while;
end process;

end algorithm; *)
\* BEGIN TRANSLATION (chksum(pcal) = "b9b03873" /\ chksum(tla) = "537ae0c1")
VARIABLES alive, flushed, status, stop_requested, cycles, pc

vars == << alive, flushed, status, stop_requested, cycles, pc >>

ProcSet == {0} \cup (1..3) \cup {4}

Init == (* Global variables *)
        /\ alive = {1, 2, 3}
        /\ flushed = FALSE
        /\ status = "running"
        /\ stop_requested = FALSE
        /\ cycles = 0
        /\ pc = [self \in ProcSet |-> CASE self = 0 -> "ControllerLoop"
                                        [] self \in 1..3 -> "WorkerLoop"
                                        [] self = 4 -> "OperatorLoop"]

ControllerLoop == /\ pc[0] = "ControllerLoop"
                  /\ IF cycles < MaxCycles
                        THEN /\ pc' = [pc EXCEPT ![0] = "WaitForStop"]
                        ELSE /\ pc' = [pc EXCEPT ![0] = "Done"]
                  /\ UNCHANGED << alive, flushed, status, stop_requested, 
                                  cycles >>

WaitForStop == /\ pc[0] = "WaitForStop"
               /\ stop_requested /\ status = "running"
               /\ pc' = [pc EXCEPT ![0] = "FlushStorage"]
               /\ UNCHANGED << alive, flushed, status, stop_requested, cycles >>

FlushStorage == /\ pc[0] = "FlushStorage"
                /\ flushed' = TRUE
                /\ pc' = [pc EXCEPT ![0] = "AwaitCompletion"]
                /\ UNCHANGED << alive, status, stop_requested, cycles >>

AwaitCompletion == /\ pc[0] = "AwaitCompletion"
                   /\ alive = {} /\ flushed = TRUE
                   /\ pc' = [pc EXCEPT ![0] = "MarkStopped"]
                   /\ UNCHANGED << alive, flushed, status, stop_requested, 
                                   cycles >>

MarkStopped == /\ pc[0] = "MarkStopped"
               /\ status' = "stopped"
               /\ pc' = [pc EXCEPT ![0] = "AwaitRestartOrFinish"]
               /\ UNCHANGED << alive, flushed, stop_requested, cycles >>

AwaitRestartOrFinish == /\ pc[0] = "AwaitRestartOrFinish"
                        /\ status = "running" \/ cycles >= MaxCycles
                        /\ pc' = [pc EXCEPT ![0] = "ControllerLoop"]
                        /\ UNCHANGED << alive, flushed, status, stop_requested, 
                                        cycles >>

controller == ControllerLoop \/ WaitForStop \/ FlushStorage
                 \/ AwaitCompletion \/ MarkStopped \/ AwaitRestartOrFinish

WorkerLoop(self) == /\ pc[self] = "WorkerLoop"
                    /\ IF cycles < MaxCycles
                          THEN /\ pc' = [pc EXCEPT ![self] = "WaitTurn"]
                          ELSE /\ pc' = [pc EXCEPT ![self] = "WorkerDone"]
                    /\ UNCHANGED << alive, flushed, status, stop_requested, 
                                    cycles >>

WaitTurn(self) == /\ pc[self] = "WaitTurn"
                  /\ (status = "running" /\ stop_requested /\ flushed /\ \A prev \in 1..(self - 1) : prev \notin alive)
                     \/ (cycles >= MaxCycles /\ status = "stopped")
                  /\ IF cycles >= MaxCycles /\ status = "stopped"
                        THEN /\ pc' = [pc EXCEPT ![self] = "WorkerDone"]
                        ELSE /\ pc' = [pc EXCEPT ![self] = "Terminate"]
                  /\ UNCHANGED << alive, flushed, status, stop_requested, 
                                  cycles >>

Terminate(self) == /\ pc[self] = "Terminate"
                   /\ alive' = alive \ {self}
                   /\ pc' = [pc EXCEPT ![self] = "WaitRestart"]
                   /\ UNCHANGED << flushed, status, stop_requested, cycles >>

WaitRestart(self) == /\ pc[self] = "WaitRestart"
                     /\ (self \in alive) \/ (cycles >= MaxCycles /\ status = "stopped")
                     /\ IF cycles >= MaxCycles /\ status = "stopped"
                           THEN /\ pc' = [pc EXCEPT ![self] = "WorkerDone"]
                           ELSE /\ pc' = [pc EXCEPT ![self] = "WorkerLoop"]
                     /\ UNCHANGED << alive, flushed, status, stop_requested, 
                                     cycles >>

WorkerDone(self) == /\ pc[self] = "WorkerDone"
                    /\ TRUE
                    /\ pc' = [pc EXCEPT ![self] = "Done"]
                    /\ UNCHANGED << alive, flushed, status, stop_requested, 
                                    cycles >>

worker(self) == WorkerLoop(self) \/ WaitTurn(self) \/ Terminate(self)
                   \/ WaitRestart(self) \/ WorkerDone(self)

OperatorLoop == /\ pc[4] = "OperatorLoop"
                /\ IF cycles < MaxCycles
                      THEN /\ \/ /\ pc' = [pc EXCEPT ![4] = "RequestStop"]
                              \/ /\ status = "stopped" /\ alive = {}
                                 /\ pc' = [pc EXCEPT ![4] = "RestartNode"]
                      ELSE /\ pc' = [pc EXCEPT ![4] = "Done"]
                /\ UNCHANGED << alive, flushed, status, stop_requested, cycles >>

RequestStop == /\ pc[4] = "RequestStop"
               /\ IF ~stop_requested
                     THEN /\ stop_requested' = TRUE
                     ELSE /\ TRUE
                          /\ UNCHANGED stop_requested
               /\ pc' = [pc EXCEPT ![4] = "OperatorLoop"]
               /\ UNCHANGED << alive, flushed, status, cycles >>

RestartNode == /\ pc[4] = "RestartNode"
               /\ IF cycles + 1 < MaxCycles
                     THEN /\ alive' = {1, 2, 3}
                          /\ flushed' = FALSE
                          /\ stop_requested' = FALSE
                          /\ status' = "running"
                     ELSE /\ TRUE
                          /\ UNCHANGED << alive, flushed, status, 
                                          stop_requested >>
               /\ cycles' = cycles + 1
               /\ pc' = [pc EXCEPT ![4] = "OperatorLoop"]

operator == OperatorLoop \/ RequestStop \/ RestartNode

(* Allow infinite stuttering to prevent deadlock on termination. *)
Terminating == /\ \A self \in ProcSet: pc[self] = "Done"
               /\ UNCHANGED vars

Next == controller \/ operator
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
    /\ cycles \in 0..MaxCycles

StatusConsistent ==
    (status = "stopped") => (alive = {} /\ flushed = TRUE)

OrderConsistent ==
    /\ (1 \in alive => 2 \in alive)
    /\ (2 \in alive => 3 \in alive)

=============================================================================
