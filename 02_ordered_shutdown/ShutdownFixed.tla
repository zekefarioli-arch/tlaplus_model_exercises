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
=============================================================================
