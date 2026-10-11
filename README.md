## Bomb expansion (V11)

For Windows, open [Huss-A-Bomb-V11.txt](Huss-A-Bomb-V11.txt) on GitHub and use **Download raw file**. Open the saved file in Notepad, select all, copy, and paste into Roblox Studio's Command Bar with Play stopped. This file uses Windows line endings and contains the same complete installer as the files below.

Open `Install-Bomb-Expansion-V11.txt`, copy the entire file, stop Play in your current Roblox Studio place, and paste into **View → Command Bar**. Press Enter, wait for **V11 installed**, save, then Play. The TXT files use Windows line endings and contain the same complete code as `.command.luau`.

The repaired installer supports the supplied original Bomb Tag server scripts with a V10 HUD, V7 movement/lobby and V4 maps, including projects that never installed V9 progression. It locates `ServerMain` inside `ServerScriptService/Services` or at the server root, safely adds a missing economy module, and adapts verified V8 effects and V10-on-V8 HUD sources. Existing V9 and complete V11 installations are also supported. It compares actual source versions and dependencies before applying exact patches; unknown edits, duplicate owners and incompatible older V3 integrations stop with their paths and diagnostic details. See [V11 compatibility and installation](V11-Compatibility-Guide.md).

Before writing changes, it uses fresh, inert ModuleScripts to compile every staged script and the required unchanged dependencies in Studio. This parses the source without starting gameplay or accessing DataStores. It requires no downloads, web requests, plugins, or animation IDs during installation.

The lobby now has four physical shops for **25 bomb skins, 25 trails, 10 titles, and 8 emotes**. Approach a stall and use its prompt to open that category. Purchases use existing earned Coins. Each category includes a free starter. The enlarged shop and stats panels retain the approved checkerboard, bright bevels and bold outlined text. The collection index lists every item, description, rarity and ownership status. Choose an owned emote, equip it, and use Play/Stop while standing still in the lobby. Titles appear above characters.

Four lobby boards show current-server Wins, Kills and Final Stands, plus cached global Wins. These use the same authoritative stats as Roblox's player list and the HUD. **Final Stands** count reaching the last two living players; **Kills** credit the last successful passer when that bomb eliminates its next holder. Round statistics settle at match completion. Existing balances, owned trails and saves migrate additively using the same `HussEconomyV9` and `HussWinsV9` stores and profile keys.

The twelve existing maps retain their authored structures and layouts with larger dimensions, bomb landmarks and high-resolution glossy signs. Sky Garden, Sunset Docks, Frostfall Village and Sunstone Bazaar grow 24% in each horizontal dimension; the other eight grow 10%. The vote library includes three new maps: **Fuseworks** (280 × 210 studs), **Detonator Plaza** (232 × 244), and **Payload Port** (326 × 174). Broad ramps connect the raised routes without jumping. The installer also refreshes the current arena and vote previews, and measures the lobby against all fifteen maps to retain a 96-stud separation.

Solo practice now uses three server-controlled bots that chase, flee, pass the real bomb, sprint and dodge under the game's movement limits. It runs for at least 60 seconds and stops when another player joins matchmaking. Bots simulate player actions; they do not reproduce human decision-making. Practice awards no Coins or persistent stats. A server-confirmed perfect weave during the first 0.22 seconds of dodge immunity, within bomb-transfer range of the carrier, produces a short sound cue and grants **+6 walking/sprinting speed for two seconds**. It can trigger once per dodge; the 1.5-second cooldown remains unchanged.

Installation stages the world and source edits, archives originals in `ServerStorage/ExpansionV11Backup_<timestamp>`, and rolls back if a commit fails. A verified complete V11 rerun performs its checks and leaves scripts and geometry unchanged. Missing owned V11 modules can be repaired without rebuilding completed maps. Lighting and music settings are preserved. Studio economy testing uses temporary preview data; published servers use the existing persistence system.

The repaired installer passed **92 installation/failure scenarios with 4,994 assertions**, **272 checks on the actual authored-world upgrade and rerun**, and compilation of **26 installed-source outputs** across the original and V9 paths. Additional checks cover source compatibility, preserved gameplay, the V10-on-V8 HUD, effects, movement and dependencies; an independent review passed 44 checks. See `Install-Bomb-Expansion-V11.validation.json`, `V11Compatibility.validation.json` and `V11-Compatibility-Review.md`. The existing component reports cover economy migration/purchases, cosmetics, practice, perfect-weave timing and 9,705 map geometry checks. Native Roblox Studio rendering, physics/pathfinding, multiplayer replication and live DataStores were unavailable here. Before publishing, playtest shop purchase/equip, emote cancellation, solo bots, a two-player bomb round, both elevated routes on each new map, and published-server save/rejoin behavior.

`HudV11-*-Preview.png`, `BombSkinsV11-Preview.png`, `WorldV11-NewMaps-Preview.png`, and `LobbyV11-Preview.png` are offline previews from the authored code and geometry, with approximate fonts and materials. Existing `.rbxl` files below contain older updates; use the V11 installer for this expansion.

---

## Reference-style HUD (V10)

Stop Play, paste `Install-Reference-Hud-V10.command.luau` into the Command Bar, then save and press Play to see the new client HUD.

The command restyles the existing V8 or V9 HUD with chunky outlines, bright checkerboard surfaces, inset highlights and illustrated shop cards. Existing gameplay and economy callbacks are retained. Its original module is archived in `ServerStorage/ReferenceHUDBackup_<timestamp>`.

The user narrowed this update to the UI. Graphics investigation and drafts are not part of the delivered V10 update; the HUD command does not change lighting, sky, shadows, map geometry or movement.

The visual shop continues to sell earned-Coin trail colors. The reference's gamepass prices and gift buttons are not added as nonfunctional controls. With V9 installed, Coins, quests, purchases and player-list synchronization continue to use the existing server system. V10 does not install an economy into a V8-only game.

Compilation, 699 V9 HUD assertions, 475 independent V8 assertions, and 13 installer scenarios with 352 assertions passed. The installer tests cover exact source backups, source-write verification, rollback and repeat installation. `HudV10-*-Preview.png` files render the generated UI with demo data and approximate fonts; they are not Roblox Studio screenshots. Native rendering and input still need a Studio playtest.

---

## Sky, progression, shop and synchronized player stats (V9)

After V8, stop Play and paste all of `Install-Economy-Sky-Hud-V9.command.luau` into Studio's Command Bar. Save, then Play. Installation stages the new economy module, source changes and graphics objects before committing. Originals and lighting settings are archived in `ServerStorage` by the installer; a failed commit restores them. It does not connect to DataStores or execute the economy during installation.

The outdoor presentation now uses a warm afternoon sun, pastel blue atmospheric horizon, soft clouds, and restrained bloom and sun rays. Sky textures are verified Roblox built-ins, with a different orientation and atmospheric treatment; they are not newly painted textures. Existing map geometry, lobby clearance and movement physics remain intact.

The unified glossy HUD adds a Coins wallet and Quests, Shop and Leaderboards pages. Completed multiplayer rounds award 20 Coins; the winner earns another 80. Solo practice does not award progression. Daily quests reward completing three rounds (100 Coins), passing the bomb ten times (150), and winning once (200); progress settles at round completion and rewards are claimed manually. Quests reset at 00:00 UTC. The server validates every reward, purchase, ownership check and quest claim.

The first shop sells cosmetic trail palettes: Classic is free; Arctic Rush costs 250 Coins, Solar Rush 400, Royal Rush 600, Toxic Rush 800 and Candy Rush 1,000. Purchasing also equips the trail. Equipped colors appear on sprint and weave effects for local and remote players and persist with the profile. There are no Robux products, randomized purchases or movement advantages.

`leaderstats.Wins` and `leaderstats.Coins` are authoritative and shared by Roblox's native player list, the HUD wallet and the live server leaderboard. The native player list stays available through its usual Roblox controls. The HUD avoids its desktop corner. A separate all-time Wins leaderboard reads a cached ordered store; temporary global-board errors do not affect profiles or the server list.

`EconomyServiceV9.luau` uses one persistent profile for Coins, Wins, lifetime progression, owned/equipped trails and daily quest state. Published servers use session ownership, bounded retries, periodic saves and leave/shutdown saves. A failed or incompatible profile load pauses earning and spending instead of replacing stored progress with zero. Studio always uses a temporary preview: purchases and rewards reset when the test ends, and global rankings are unavailable. Native published-server persistence and networking still need playtesting.

Keep the DataStore names **HussEconomyV9** and **HussWinsV9** stable in future updates; changing their names creates a different record set. Profile schema is `v=1`, keyed by `u<UserId>`. The server catalog is the single source for prices and shop display. Tests and offline previews are delivered alongside the source; older `.rbxl` files do not contain V9.

---

## Glossy HUD, movement effects and lobby clearance (V8)

After installing V7, stop Play and paste all of `Install-Glossy-Hud-Effects-V8.command.luau` into Studio's Command Bar. Save, then Play. The installer backs up edited scripts, replaced lighting effects, the prior lobby pivot and the previous movement-effects script in `ServerStorage/GlossyEffectsBackup_<timestamp>`. It stages changes and restores original state if installation fails.

The lobby is measured against every map template at its actual runtime position and against the current arena. When necessary it moves horizontally to leave a 96-stud gap; its height, rotation, existing objects and LobbySpawn instance remain intact. Repeating the installer does not keep moving it. Map templates, voting, arena placement and round scripts remain unchanged.

The HUD now uses colorful glossy cyan, violet, gold, green and pink surfaces, rounded edges, bevels and bold outlined text. Existing responsive layouts and real game controls remain in place. Selected map votes stay visibly green through hover/focus; expired votes show their closed state and cannot submit. `HudV8-Lobby-Preview.png` and `HudV8-Match-Preview.png` are offline previews from the actual generated UI, with approximate fonts and gradients; they are not Studio screenshots.

Graphics changes add mild color correction and replace the old strong Bloom with a restrained glow. Existing sky, atmosphere, time and depth-of-field settings remain unchanged. `MovementEffectsV8.client.luau` adds narrow cyan sprint wakes, gold weave bursts and small grounded dust puffs. It honors Reduced Motion, culls distant characters and caps effect allocations. It does not write camera transforms, character facing, movement speeds or animation joints; V7 shift lock and the faster V6 dodge remain in charge.

V8 removes the default plastic footstep loop and suppresses native character Running sounds for both Sound and AudioPlayer. New timed footsteps layer short portions of Roblox's built-in landing and scuff recordings, with surface-dependent tone, bounded cadence, moving-platform compensation and a separate voice pool. These are custom arrangements of existing recordings, not newly uploaded recordings. Walking, sprinting and nearby players receive grounded footsteps; dodging, air, death, ragdoll and pause suppress them. Full-track music IDs and separate music/SFX controls are preserved. No audio uploads are needed for these footsteps.

Validation covers Luau compilation, HUD lifecycle and input, actual map/lobby geometry, effects and audio callbacks, bounded resources, respawns, repeated installation and injected rollback failures. Offline audio renders check the exact sample mix for clipping and release tails. Native Studio rendering, physics and listening remain outstanding. Test a map vote, lobby respawn, all eight dodge directions under shift lock, sprint/stop, stone/grass/metal footsteps and Reduced Motion. Older `.rbxl` files do not contain V8; this update is delivered as Command Bar code.

---

## Simpler lobby, full music tracks and shift-lock dodge (V7)

With the previous V6 update installed, stop Play and paste all of `Install-Simple-Lobby-ShiftLock-V7.command.luau` into Studio's Command Bar. Save, then Play. The installer archives the old lobby and four edited scripts under `ServerStorage/SimpleLobbyShiftLockBackup_<timestamp>` and preserves the lobby spawn's world position.

The Conservatory keeps its bomb fountain, sheltered galleries, gardens, benches and two wide ramps. Removing paving joints, repeated trim and small decoration reduces the lobby from 1,074 to 285 parts. Six connected routes remain usable without jumping. `LobbyBuilderV7.luau` is the editable builder; the V7 previews are offline geometry renders, not Studio screenshots.

The existing shift-lock controller now owns character facing throughout directional dodges, and SnappyMovement yields its rotation writes while that constraint is enabled. Movement resumes travel-facing rotation when shift lock is inactive. Camera changes, respawn, menus, focus changes and blocked character states are covered by callback tests. V6 speed, distance curve, steering, .72-second duration and 1.5-second cooldown remain unchanged.

V7 removes the generated background notes and drums while retaining game sound effects and separate music/SFX controls. Put permitted Roblox audio asset IDs in `MUSIC` at the top of the installer: Lobby and Chase are sufficient; Duel is optional. Blank installer values preserve existing IDs. When no Duel ID is stored, the Chase track continues without restarting. Without configured, accessible audio, there is no background music. See `Music-Setup-V7.md` for Creator Store and upload instructions; no full-song generator or new music tracks are included.

Validation includes Luau compilation, 4,558 lobby geometry checks, 201 audio runtime assertions, combined movement/shift-lock callback tests, and 37 installer cases with 1,952 assertions. Native Studio physics, rendering and audio playback still need checking: test all eight dodge directions while rotating the camera, both lobby ramps, respawn, and music permissions. All twelve maps, voting, server immunity and action animation poses remain intact. Existing `.rbxl` files are older versions; V7 is delivered as Command Bar code.

---

## Music, sound, lobby and action dodge (V6)

After installing V5, paste all of `Install-Lobby-Audio-Action-V6.command.luau` into Roblox Studio's Command Bar **with Play stopped**. Save, then Play. It installs the new lobby and audio LocalScript, updates the dodge and movement constants, and adds music/SFX controls to the existing HUD. The twelve maps and their vote service remain intact. The installer preserves the old LobbySpawn world position and archives the old lobby and edited scripts in `ServerStorage/LobbyAudioActionBackup_<timestamp>`.

The new Conservatory lobby has a central bomb fountain, limestone arrival gate, copper-roof galleries with twelve named map displays, planted courtyards, benches, broad promenades and an elevated pavilion. Its 1,074 anchored parts use 61 colliders; two 24-stud ramps climb five studs at 11.77 degrees. Spawn, route and containment checks pass. `LobbyBuilderV6.luau` provides editable geometry; `LobbyV6.validation.json` records analytic checks. Decorative map reliefs are original abstract displays; the HUD remains the interactive map browser/voting interface.

`DodgeActionV6.client.luau` gives the eight directions sharper, asymmetric shoulder/arm/leg poses and brief trails. Burst duration is .72 seconds instead of .95. Walking/sprinting forward launch speeds become 74/76 instead of 50/52, with an 84 cap; drag is reduced. Unobstructed 60 FPS callback integration measures 33.17/34.67 studs, previously 25.99/27.89. Cooldown remains 1.5 seconds; server immunity remains .45 seconds. Walking/sprinting speeds remain 24/32, and jumping stays disabled. Actual collision, slopes and frame timing can affect travel.

`GameAudioV6.client.luau` uses Roblox-bundled samples for an original sequenced lobby/chase/final-duel score and game/UI cues. It requires no uploaded animation or audio assets. These are original rhythmic/tonal arrangements, not imported commercial songs. Music and SFX can be muted separately in Settings. Optional local player attributes `HussMusicVolume` and `HussSFXVolume` accept 0–1. Optional workspace attributes `HussLobbyMusicId`, `HussChaseMusicId` and `HussDuelMusicId` accept your own permitted Roblox audio IDs; inaccessible custom audio falls back to the bundled-sample score.

The V6 installer requires the previous V5 script signatures. Unknown or partially modified movement tuning stops before changes. It stages the complete new lobby and script source probes before committing, and restores originals if a commit operation fails. It does not change Animate, DodgeIFrameServer, RoundService or map templates.

Validation covers Luau compilation, exact movement-source differences, unchanged cooldown/immunity, HUD regression/settings, audio event/lifecycle behavior, lobby geometry and installer rollback. Offline geometry and pose previews are derived from actual authored code, not Studio screenshots. Roblox Studio rendering, animation blending, multiplayer latency and final listening/volume checks remain untested here. Test with two players: walk both lobby ramps, dodge in all directions, pass/explode the bomb, respawn, vote, toggle AFK and mute both audio groups before publishing.

Older `.rbxl` artifacts below remain earlier versions; V6 is delivered as a pasteable installer.

---

## HUD and directional dodge / weave (V5)

Paste the entire `Install-Hud-And-Dodge-V5.command.luau` into Roblox Studio's Command Bar with Play stopped, in the supplied **HELP FOR AI HUSSABOMB 2.rbxl** or its V3/V4 upgraded version. Save, then Play. The installer is standalone and requires no downloaded animation IDs, web requests, plugins, or loadstring. Original scripts are cloned into `ServerStorage/HudMotionBackup_<timestamp>` before installation.

The unified HUD includes compact match status, player health, live bomb fuse/carrier, segmented dodge cooldown and server-confirmed immunity, separate lobby menu buttons, real stats, AFK controls, three-card map voting with live 3D previews, a twelve-map browser, results, countdowns and notifications. Dark panels, fine outlines, lime highlights, bold white text and red close buttons follow the requested visual direction. Reduced motion is a session preference. Keyboard movement remains WASD, Left Shift and directional Space; this update does not add touch/gamepad movement bindings.

Eight procedural R6/R15 dodge poses provide anticipation, guarded forward slips, side weaves, backward recoil, diagonal blends and recovery. Brief hand trails can be disabled through reduced motion. The owner animates immediately; other clients animate accepted server dodge broadcasts. Existing movement physics, 1.5-second client cooldown and 0.45-second server immunity are unchanged. Normal walking/running animations continue; the old shared dodge clip is suppressed while V5 is enabled. Maps and lobby geometry are unchanged.

Sources: `HudControllerV5.luau` and `DodgeWeaveV5.client.luau`. The installer replaces the existing HUD module, installs the motion LocalScript, minimally patches SnappyMovement/Animate/DodgeIFrameServer, and disables the separate legacy voting and AFK clients to prevent duplicate interfaces. Existing PixelHealthGui is hidden while the new HUD is active.

Validation includes Luau compilation, mocked UI lifecycle/events and eleven responsive layouts, pose mathematics and cleanup, server acceptance/expiry, repeat installation, exact gameplay-source preservation and injected rollback failures. Reports: `HudV5.validation.json` and `HudMotionV5.validation.json`. Native Roblox Studio rendering, animation blending, multiplayer latency and device performance have not been tested here. Use Studio's two-player server test to check all eight dodge directions, bomb transfers, immunity expiry, respawn, voting and AFK before publishing.

`HudV5-Match-Preview.png`, `HudV5-Vote-Preview.png` and `DodgeWeaveV5-Poses.png` are offline previews derived from the authored code. They are not Studio screenshots; font rendering, map materials and animation blending can differ.

The `.rbxl` files further below are earlier V3 deliverables and do not contain this V5 update.

---

## Movement-focused rebuild (V4)

Use `Update-All-12-Movement-Maps.command.luau` in Roblox Studio Command Bar, with Play stopped, in the supplied Huss A Bomb place or the earlier upgraded place. This is a standalone readable installer: no web requests, external assets, compression, or plugins. It replaces all twelve maps and vote previews, preserves the lobby and gameplay scripts, and archives old content under ServerStorage/MovementMapsBackup_*. It fixes preview framing and map-label compatibility. Save the place after installing.

V4 source: `MovementMapBuilder.luau`; offline contact sheet: `MovementMaps-Preview.png`. Distinct polygon footprints, 15,653 parts across all templates, 192 spawn markers, 24 ramps, slopes no more than 14.04 degrees. `MovementMaps.validation.json` records 7,764 analytic checks, with zero errors or width warnings. Installer mocks cover original and repeat installation, unsupported source, build failure, terrain-copy failure and commit rollback. These checks do not replace native Roblox Studio multiplayer/physics and device-performance testing.

Only the known old harbor terrain region is cleared when the legacy active flag is true and the migration flag is absent. Its voxels are copied into the archive before clearing. Unknown terrain is preserved. The game remains a no-jump run/sprint/dodge game.

The `.rbxl` files below belong to the earlier V3 delivery; this V4 update is delivered as Command Bar code.

---

# Huss A Bomb — twelve detailed maps

Based on the supplied **HELP FOR AI HUSSABOMB 2.rbxl**. The original upload is unchanged.

Open **Huss A Bomb - Twelve Detailed Maps.rbxl** in Roblox Studio. All twelve templates, the active arena, twelve vote previews and the garden lobby are already authored as editable Parts/Models. The existing V6 service continues to offer three random maps per vote.

For a clean editor view, stop Play, open View → Command Bar and run:

```lua
require(game:GetService("ServerStorage"):WaitForChild("DetailedMapInstaller")).Rebuild()
```

This rebuilds the authored maps from the included source and removes the old procedural harbor terrain **inside the same region owned by the original SunsetDocksTerrainV9 script**. Terrain outside that region is preserved. The binary place retains the original terrain bytes; without this editor command the same scoped cleanup runs when Play starts. Save As a new place after the editor rebuild.

Alternatively, open **Install-All-12-Maps.luau**, copy its entire contents, and paste into the Command Bar of your original latest place with Play stopped. It is a complete, self-contained installer with all map, installer and HUD source included. It does not download assets or use loadstring.

## Maps

| Map | Footprint in studs | Main feature |
| --- | --- | --- |
| Sky Garden | 156 × 144 | Stone arcade terrace and fountain courtyard |
| Neon District | 180 × 160 | Shops, boulevards and a covered metro skywalk |
| Crystal Cavern | 184 × 164 | Crystal formations and an excavation gallery |
| Clockwork Foundry | 228 × 186 | Boiler yard, furnace hall and gantry crossing |
| Frostfall Village | 224 × 180 | Alpine lodge promenade and water-garden bridge |
| Sunstone Bazaar | 190 × 172 | Market stalls and sandstone arcade |
| Emerald Ruins | 204 × 184 | Overgrown cloisters and sanctuary bridge |
| Pirate Cove | 226 × 184 | Playable ship deck, gangways and customs passage |
| Stardust Carnival | 214 × 202 | Midway stalls, carousel and raised stage promenade |
| Ember Keep | 218 × 204 | Battlements, gatehouse gallery and courtyard |
| Orbital Station | 246 × 192 | Research pods and connected observation walks |

Raised gameplay routes use continuous ramps, 16–24 studs wide, with slopes below 18 degrees. Connected elevated areas have at least two ramp approaches. Buildings, roofs and rides used as scenery are not required routes. Every map has sixteen distributed ground spawn markers with clearance from solid structures and overhead raycast hits.

`MapPreview-All12.png` shows an offline reconstruction of the generated geometry, not Roblox Studio screenshots. Roblox lighting, materials, terrain and camera behavior will differ.

## Preservation and sources

Original maps, previews, lobby, current arena and the three changed script sources are archived in `ServerStorage/DetailedMapUpgradeBackup`. Rebuilding makes a new dated backup folder. Existing older backups in the supplied game are retained.

- `MapBuilder.luau`: deterministic geometry builder; included as `ServerStorage.DetailedMapBuilder`.
- `DetailedMapInstaller.luau`: staged rebuild with archival and preview generation.
- `HudController.luau`: latest HUD, with the Maps page reading `CurrentVotedMap`.
- `BombTagVoteClientV6.luau`: latest voting UI, with automatic preview framing and cached geometry when counts change.
- `SunsetDocksTerrainV9.luau`: scoped one-time cleanup replacing the retired harbor sculptor.
- `Install-All-12-Maps.luau`: complete copyable installer for the latest original upload.

RoundService, V6 server voting, GameConfig, movement, AFK, bomb logic and unrelated objects/scripts are unchanged. `previous-integration/` contains earlier unfinished integration work and is not used by this place.

## Validation and Studio check

All six delivered Luau files compile. Analytic geometry checks pass for 192 spawn positions, 26 ramps, their landings and connected elevated areas. Installer mock checks cover repeated rebuilds, archive preservation, preview pruning, arena placement and injected build failure. The HUD's 530 existing mock assertions pass. These checks do not simulate Roblox physics or networking.

An independent Roblox binary decoder reads the final place without new warnings. All 31,152 original instances are preserved; 19,988 instances were added. Only three original Source properties and the parent table changed; 2,296 original chunks remain byte-for-byte identical. Reports are alongside the place.

In Studio, use Start Server with two players, vote through the maps, and test sprinting/dodging up and down each ramp and across joins. Check bomb transfers, round returns to the lobby, AFK behavior and preview performance. Studio playtesting and multiplayer performance have not been run here.
