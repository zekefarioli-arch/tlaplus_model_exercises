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
=============================================================================
