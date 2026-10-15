# Huss-A-Bomb V15 — current-place polish

This update is built from **HABWAS.rbxl**, the latest place you supplied. It does not require installing the older V9–V14 commands first. The finished place and Command Bar installer contain the same V15 source changes.

## Open the finished game

Download **Huss-A-Bomb-V15.rbxl** using GitHub's **Download raw file** button. In Roblox Studio, use **File → Open from File** and select the downloaded `.rbxl`. Save a local copy, then test the update. Publish to your **existing experience** when ready so its existing player data and offers remain associated with that experience.

The file includes originals under `ServerStorage/HABPolishV15FileBackup`. Your uploaded file has not been modified. The game's current R6 setting is retained.

## Alternatively, update your open HABWAS project

1. Open **Huss-A-Bomb-V15.txt** and click **Raw**, or download it and open it in Notepad.
2. Press **Ctrl+A**, then **Ctrl+C** to copy the entire file.
3. Stop Play in Studio. Open **Command Bar** from Studio's View/Window menu or toolbar, paste the complete script, and press Enter.
4. Wait for **“V15 installed”** in Output. Save, then press Play.

Use either the finished place or the installer. Running the installer on an intact V15 place performs compatibility checks and leaves it unchanged. It preserves valid IDs you have entered in the new central configuration.

If Output says **“compatibility checks stopped,”** nothing was installed. The message names the script or object that differs. Do not delete the checks: they protect edits made after the uploaded HABWAS version. Share the complete error and the changed project for an adaptation.

The command needs no HTTP downloads, plugins, asset uploads or DataStore access. It verifies the actual `ServerScriptService/Services/ServerMain`, existing dependencies, script enable states and lobby anchors. Unknown receipt handlers, modified source and duplicate system names stop installation. New code is compiled inside uncalled functions before the transaction begins.

## What changed

**Animations and contact.** Three bomb-strike poses, a throw, hit recoil, shield block and nine separate ability poses now use authored joint keyframes with anticipation and recovery. The pose system blends with locomotion, yields to dodging and handles respawn. The panic run yields to the current action and uses fewer tears. These new action poses need no uploaded animation IDs. Your existing base locomotion and dodge controllers remain in place; permissions on any old custom animation assets still belong to your experience's Roblox configuration.

Manual attacks retain server authority. Swept contact checks handle moving targets, avoid hits through walls and prevent repeated transfers from one swing. Attacks wait for the existing dodge to finish, avoiding an invisible attack during a weave. The current attack and dodge cooldowns remain unchanged. The carrier now receives **+3 walking and sprint speed**; the previous sprint advantage is preserved and also applies when walking. Practice bots use the same carrier advantage.

**Abilities and effects.** All nine existing abilities have distinct poses and restrained native geometry. Shield, movement bursts and cosmetic doubles retain their server rules. Decoys are visual copies without scripts or collision. Imported PNG effects remain available for trails. Aura, bomb and dodge cosmetics keep their ownership and IDs but now render smaller 3D accents, including in collection previews. The old duplicate ability-effect controller is disabled and backed up.

**Interface.** Four rounded lobby buttons replace the crowded permanent menu. Match status, fuse and action controls have clearer spacing, and menus share one owner so they close each other correctly. Existing voting, AFK, quests, wallet, stats and collections retain their callbacks. A duplicate legacy health UI is disabled. The former retired-emote stand opens the Effects collection; this update does not revive retired emote sales.

**Lobby.** An open, rounded bomb plaza replaces six decorative architecture groups. Existing shop models, collection booths, leaderboard displays, spawn and spectator overlook remain in place. Broad ramps connect the raised plaza without requiring jumping. Added Passes and Abilities booths open the existing menus. All playable maps, vote templates, lobby location and map separation are preserved.

**Purchases.** Nine existing pass/bundle offers and three Gem developer products use one central configuration and real Roblox sale metadata. Unconfigured offers cannot be purchased. Server ownership checks, paid-random-item policy handling and durable receipt saving remain in place. See [V15-Monetization-Setup.md](V15-Monetization-Setup.md) to create the official offers and enter their IDs. No official offers have been created in your Roblox account by this update.

Solo practice still awards **no Coins, persistent competitive stats or quest progress**. Existing saved balances, owned cosmetics and progression data are not reset.

## Before publishing

The code passed Luau compilation, component checks, installer transaction tests and independent binary-file validation. These checks use offline Roblox API adapters; they do not replace a Studio playtest.

Use Studio's server/client test with two players to check:

- Alternating strikes, a miss, a wall obstruction, shield block, perfect weave and bomb transfer during sprinting.
- Each owned ability, carrier panic and animation cleanup after death or respawn.
- Solo practice reward exclusion, map voting, AFK and round completion.
- Booth approach/leave, menu switching, trail previews and all lobby ramps.
- Published-game animation permissions, save/rejoin and purchases after entering real IDs.

Original movement uses **Space** for weave. The attack/ability UI reflects its existing keyboard/controller/touch bindings; this update does not add a new mobile weave input. Reduced Motion suppresses optional poses/effects where supported by the existing game.

## Restore

For a Command Bar install, the backup is `ServerStorage/HABPolishV15Backup_<timestamp>`. For the downloadable place it is `ServerStorage/HABPolishV15FileBackup`. Read its `RestoreManifest` before restoring: it lists added modules and how to restore original sources, enable states, archived lobby models and the version attribute. Backed-up scripts are disabled; do not drag them into an executing container as duplicates.

An installation error attempts to restore the originals automatically. If restoration itself fails, Output names the retained backup and each restoration error. Keep that backup and your pre-install local save.

## Previews

[Action poses](ActionAnimationsV15-Poses.png), [animated pose preview](ActionAnimationsV15-Preview.gif), [lobby HUD](previews/v15-ui/lobby.png) and [match HUD](previews/v15-ui/match.png) are offline previews derived from the authored transforms and UI tree. Roblox rendering, fonts, camera and live movement may differ.
