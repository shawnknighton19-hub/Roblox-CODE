# V9 economy independent review

Status: complete, with no remaining blocker found in the reviewed source. The exact reviewed SHA-256 is recorded in `review/validation.json`. Native Roblox/DataStoreService runtime remains untested here.

## Findings and fixes

1. **Critical, fixed:** final saves originally used `final and nil or lease`, which always evaluates to a lease table in Luau. Normal departures would leave their profile locked for 180 seconds. The source now uses an explicit conditional, and tests prove final release stores no lease and immediate rejoin loads successfully.
2. **Improvement, applied:** purchases during an in-flight save previously waited until the periodic autosave for persistence. The final source uses captured revisions and a bounded follow-up save, coalesces writes for ten seconds, skips no-op equip writes, and interrupts that wait promptly for final release. Idle unchanged profiles still renew their lease.
3. The original direct win increment is removed by the server patch. Wins now have one authoritative award path.

## Independent execution

`review/run.py` embeds the actual current service into separately authored controlled-yield mocks and passes **39 assertions** covering:

- Profile load, purchase coin/inventory atomic snapshots, final release, immediate rejoin.
- A second purchase during a yielding first save, then either bounded follow-up persistence, departure, or shutdown.
- Snapshot isolation: a stored earlier snapshot does not acquire newer in-memory inventory/balance mutations.
- Leaving while load is in flight and releasing the newly acquired lease afterward.
- Foreign live leases, stale foreign-token writers, expired own-token writers, and disabling a lost session.
- Future/invalid schema and load outage preserve old data; neither becomes a fresh zero profile.
- UTC midnight clears prior-day progress and claimed state before accepting a request.
- Solo practice, AFK participants, non-roster transfer targets and fake winners cannot earn invalid rewards.
- Duplicate result and quest claim handling, owned-item checks, malformed requests, and server/native leaderstats synchronization.
- Ten-second write coalescing, no-op equip writes, final release interrupting cooldown, and idle lease renewal.

`review/test_hooks.luau` separately executes the real source patcher on the supplied Main/Round/Bomb sources and checks exact hook placement and idempotence. Begin/End hooks exist only on the real multiplayer match path; pass credit occurs only after the authoritative transfer; normal cleanup and errors abort pending match rewards.

## Code review conclusions

- Store callbacks verify both session token and unexpired stored lease before any save. Snapshots are deep copies and coin deduction/ownership are in one profile transaction.
- A failed load has no writable profile. The client cannot specify rewards, balances, win counts, prices, or arbitrary store keys.
- Remote actions and IDs are whitelisted and type/length checked. A per-player token bucket limits request handling.
- Match membership is captured server-side; completed-round and winner rewards are one-shot. Lifetime passes count valid transfers while daily quest progress is capped at its target.
- The global board is a wins-only view, cached for 120 seconds and requested on demand. Ordered writes use the maximum old/new saved Wins and run only after a successful profile save. They are throttled/budget checked and cannot roll a player's ranking backward.
- Preview sessions skip persistent and ordered data stores. Live load failures pause progression rather than overwriting data.

## Practical limits

Roblox can fail persistent writes during outages or terminate a server before queued operations finish. This implementation retries and protects previously stored data; it cannot guarantee every unsaved recent reward survives a platform failure. Global boards are eventual and can lag successful profile writes. Studio/native multiplayer testing is still required for the installed service and HUD.
