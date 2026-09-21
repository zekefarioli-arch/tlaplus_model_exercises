# 01-hourclock: a 12-hour clock in TLA+

This is the first spec of my TLA+ learning plan. It models a clock that shows only the hour, from 1 to 12, and moves forward one hour at a time. I chose it because it is the smallest system I could think of that still has a state, an initial condition and a step, in the same way as a light switch has two states and one action that flips them.

## Method

Before writing any TLA+, I describe the system in informal mathematics, following Lamport's "Thinking Above the Code". For this spec that means five items: the variables, the initial states, the steps, the invariants, and what must eventually happen. Only after that do I translate the description into the specification and configure TLC.

## Files

- `HourClock.tla`: the specification.
- `HourClock.cfg`: the TLC configuration, where I declare the initial predicate, the next-state relation and the invariants to check.

## Next step

Once the spec passes in TLC, I will break it on purpose by changing the step, and I will read the error trace that TLC produces to find the cause myself. I will write down here what the trace taught me.
