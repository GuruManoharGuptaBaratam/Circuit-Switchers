# FSM Design Hand-Off

Owner: **Member 04 - Cache Controller FSM and Main-Memory Model**

This file is intentionally an integration hand-off, not a substitute implementation by Member 01. Member 04 should replace or extend it with the final state diagram and transition table that match `rtl/cache_controller.v`.

## Required behavior from the shared interface

The controller must support these externally visible phases:

1. Wait until `req_valid && req_ready` accepts one request.
2. Capture tag, index, and offset as stable `active_*` fields.
3. Observe `lookup_hit` after the selected cache line is available.
4. On a hit, return `cache_byte_data` without asserting `mem_req`.
5. On a miss, assert `mem_req` and wait for `mem_ready` while keeping the active address stable.
6. When memory responds, pulse `refill_write_en` and return `refill_byte_data`.
7. Pulse `resp_valid` for one cycle and become ready for the next request.

Illustrative state names such as `IDLE`, `LOOKUP`, `MEM_WAIT`, `REFILL`, and `RESPOND` are acceptable, but the final names and cycle timing belong to Member 04. The implemented state table must follow `docs/interface_contract.md`.

## Acceptance points

- Reset returns the controller to its idle state.
- One request is accepted only when `req_ready` is high.
- A hit never starts a memory request.
- A miss never writes the cache before `mem_ready`.
- Refill enable is a one-cycle pulse.
- Exactly one response pulse is produced per accepted request.
- Active request fields remain stable until completion.
