# Independent V11 integration review

Reviewed the production catalog, EconomyServiceV11, CosmeticsServiceV11, combat/round patch hooks, PracticeServiceV11, and the HUD's profile/category interfaces against CONTRACT.md.

## Result

No unresolved blocker found in the reviewed gameplay/economy interfaces. Independent controlled-yield tests passed **62 assertions**: 39 retained persistence checks and 23 new V11 assertions. The exact economy/catalog hashes are recorded in `review/validation.json`.

One packaging defect was caught during review: `return Patch` had accidentally been inserted inside the practice replacement string rather than at the patch module's end. The practice owner corrected this and recompiled the resulting RoundService before freeze. This was a transient conversion error, not a remaining limitation.

## Verified

- V1 profile migration adds categories, Kills and FinalStands while retaining balances, legacy equipped/owned trails, daily claim state and unknown extra fields. The installed module and DataStore names remain compatible with V9.
- The catalog contains exactly 25 bombs, 25 trails, 10 titles and 8 emotes, including free category starters. All original six trail IDs and prices remain valid.
- Independent category purchases deduct authoritative catalog prices once, preserve other category selections, and survive a save already yielding, leave, and rejoin.
- Unowned category equips, malformed purchase payloads, and invented stat/reward actions are rejected. New stats share the canonical leaderstats fields used by the UI/native player list.
- Last-passer kill accounting is recorded before the victim's health becomes zero. A new cycle's initial/random carrier explosion supplies a nil last passer, preventing stale prior-cycle credit. Duplicate elimination, eliminated-actor transfers and wrong passer relations cannot add a kill.
- FinalStands require exactly two eligible surviving roster members and settle once with the match result. Abort discards pending match statistics.
- Practice bot facades are not Player instances and cannot create rewarded matches or persistence entries, even if their table imitates Player methods. Practice disconnect/death/second-player cancellation and facade lifecycle were also reviewed directly.
- Cosmetics derives server appearance from server-published equipped attributes. Emote requests accept only the equipped emote when the profile is ready, the player is alive, stationary, and outside a round; movement, damage, timeout and character changes stop an active emote.
- Category IDs and ownership arrays are within the expanded HUD's limits. No client-selected price or stat total is accepted by the economy remote.

## Validation limits

Execution here uses Luau and controlled Roblox mocks. Actual Studio rendering, humanoid physics/pathfinding, client/server replication, and live DataStore availability were not exercised. The parent agent owns exact patched Bomb/Round/movement execution tests and the final transactional installer checks; those are separate from these 62 independent economy assertions.

Run the independent suite with `python3 /workspace/scratch/expansion-v11/review/run.py`.
