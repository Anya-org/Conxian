# Protocol-first narrowing migration note

## Status

Planned narrowing in progress

## Why this note exists

`Conxian` is being aligned to the approved portfolio architecture as a protocol-first repository.

Under that architecture:
- `Conxian` owns protocol identity, protocol-adjacent artifacts, and canonical protocol-facing material
- gateway runtime and service concerns should live outside this repo

A gateway application subtree currently exists here. That overlap is scheduled for narrowing and relocation.

## What to expect

Upcoming cleanup work will:
- move gateway runtime concerns out of this repo over time
- preserve protocol-facing artifacts and identity here
- make the repo’s role more clearly protocol-first

## Working rule during migration

When editing gateway-related material in this repo:
- avoid expanding service/runtime ownership here
- treat protocol-facing artifacts as the long-term center of gravity
- assume gateway runtime concerns should converge elsewhere in the portfolio

## Reference

See the current protocol-first narrowing plan maintained in the portfolio architecture docs for the approved move/keep direction.
