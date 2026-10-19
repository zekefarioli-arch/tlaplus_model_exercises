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
=============================================================================
