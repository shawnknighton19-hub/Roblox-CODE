# HABWAS polish V16

This build starts from the untouched `HABWAS.rbxl`. It keeps that game's HUD, round rules, AFK handling, saved profiles, no-jump movement and map voting. Do not apply V15 first.

## Open the finished game

1. Open **HABWAS-Polished-V16.rbxl** on GitHub and click **Download raw file** (the download-arrow button).
2. In Roblox Studio, use **File → Open from File** and select the downloaded `.rbxl`.
3. Save it as a separate place while testing. The repository still contains your untouched `HABWAS.rbxl`.

Opening a downloaded place does not publish it or change your experience's avatar settings. Publish to the correct existing experience when your tests are complete. Its original locomotion assets still need permission for that experience; the new action and weave poses use joint transforms and require no new uploaded animation IDs.

## Alternatively, update the original with one command

Open **HABWAS-Polish-V16.txt** and click **Download raw file**. Open the downloaded file in Notepad, press **Ctrl+A**, then **Ctrl+C**. In Studio, open the original `HABWAS.rbxl`, stop Play, open **View → Command Bar**, paste the entire text and press Enter. You do not need to paste or install the individual modules.

The command checks the actual source and world layout, stages replacements, compiles inert functions, and creates backups before committing changes. Unknown edits stop installation with their paths. It accepts the original HABWAS or its own verified V16 result; it does not bypass a V15 or unrelated-version mismatch. A complete rerun does not add duplicate maps, controllers or backups.

Use Output to distinguish **V16 installed** from a compatibility or rollback error. Installation success means the checked changes were committed; it is not a multiplayer playtest. Save only after reviewing Output.

## What changed

- The lobby retains its fountain, arrival architecture and original style. The booths are arranged along its sides, leaderboards move behind the viewing area, and a broad balcony overlooks the active match. It is a spectator area, not an entrance into a live round.
- All 15 named voting maps receive new layouts, different footprints and themed structures. Broad ramps reach raised routes without jumping. Signs use bold outlined lettering and glossy colors that fit the existing GUI.
- Eight directional weave poses and fifteen action variants add stronger body movement, including strikes, throws, reactions and gestures for the nine abilities. The existing physical movement, cooldowns and server hit rules are preserved. See [animation details](V16-Animation-Notes.md).
- Trails, auras, ability effects, bomb models, kill sounds and necessary gameplay indicators remain. Extra bomb/dodge/death cosmetics and panic tears are removed. Owned items are retained; unopened crates for removed visual categories remain refundable. The former Emotes kiosk opens the existing inventory.
- Save-service handle errors no longer abort the bootstrap before rounds initialize. Profiles remain unavailable until loading succeeds; the patch does not invent temporary balances or change store names. Global ranking availability is handled separately.

The main HUD is the original HABWAS design. Small existing shop/ability-preview edits reflect the removed categories; this build does not install the rejected V15 interface or its combat changes. Lighting and sky settings are preserved.

## Studio checks before publishing

1. Run a solo session: confirm practice begins, bots play, and coins, statistics and quest progress do not increase.
2. Start a two-player test: vote, enter a round, pass/strike/throw the bomb, reach the final duel and return to the lobby. Toggle AFK and confirm matchmaking responds.
3. Test all weave directions with shift lock, sprint, a bomb strike during recovery, each unlocked ability, death/respawn and Reduced Motion. Check both players' views.
4. Watch a match from the balcony. Try its ramps and boundary, approach every booth, and read all four boards. Vote through the maps and check raised routes, spawn clearance and narrow corners with actual avatars.
5. Check equipped trails and auras, ability previews, inventory, kill sounds and refunds. In a published test, verify existing saved ownership and Roblox asset permissions.

Automated checks run actual Luau sources with platform test doubles and verify exported geometry, route connectivity, source preservation and binary decoding. Offline previews are not Studio screenshots. Native character physics, camera feel, rendering, streaming, animation blending, multiplayer replication and live purchases still require Studio/published testing.

## Backups and recovery

The finished game contains `ServerStorage/HABPolishV16FileBackup`. The command creates a timestamped `HABPolishV16Backup_…` folder. Each includes original script sources and a restore manifest; world backups preserve the replaced map folders and lobby architecture. Script copies are disabled.

The easiest full rollback is to reopen the untouched **HABWAS.rbxl**. For selective recovery, follow the backup's restore manifest, including moved booth transforms and display-origin attributes. Do not run backup scripts. If an installation error says rollback could not complete, keep its backup and error output rather than rerunning blindly.
