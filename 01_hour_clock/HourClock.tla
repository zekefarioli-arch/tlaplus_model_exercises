----------------------------- MODULE HourClock -----------------------------
(*
 * A simple 12-hour clock based on Leslie Lamport's TLA+ video course.
 * The variable hr represents the current hour displayed by the clock.
 *)
EXTENDS Naturals

VARIABLE hr

Init == hr \in (1 .. 12)

Next == hr' = IF hr # 12 THEN hr + 1 ELSE 1

Spec == Init /\ [][Next]_hr

(* Type invariant ensuring the hour remains within the 12-hour cycle *)
TypeOK == hr \in (1 .. 12)

=============================================================================
