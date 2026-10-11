# V11 compatibility repair

This installer repairs the dependency assumptions behind the reported failure. The uploaded place contains `ServerMain` at **ServerScriptService/Services/ServerMain**. Earlier installation code searched only directly under ServerScriptService and assumed the V9 economy hooks already existed.

## Install in Roblox Studio

1. Open your current game and stop Play.
2. On GitHub, open `Huss-A-Bomb-V11.txt` and choose **Raw** to copy all code, or **Download raw file** to save it for Notepad. Use the current file from the review branch; an earlier downloaded copy still contains the old checks.
3. Open Studio's **View → Command Bar**, paste the complete file, and press Enter.
4. Read Output. Successful installation prints the discovered ServerMain path, the economy action, and the backup folder. A complete rerun prints **V11 already installed**.
5. Save a separate place copy, then test solo and with two players.

The `.txt` and `.command.luau` installers contain equivalent code. Do not place the installer in an ordinary runtime Script.

## Supported source versions

| Component | Verified handling |
| --- | --- |
| ServerMain | Finds the existing Script at root or inside Services; preserves its location and boot targets. |
| RoundService and BombService | Recognizes the supplied V6 voting/AFK sources, known V9 hooks, or complete V11. Adds the missing hooks using exact source edits. |
| EconomyServiceV9 | Creates the V11-compatible module if absent; migrates the known V9 implementation; refuses an unrelated existing module. |
| HudController | Supports V10 installed over V8 or V9, plus V11. Adds missing progression/collection callbacks while retaining the approved style, voting, AFK and round handlers. |
| MovementEffectsV8 | Adds the server-selected trail palette to the verified V8 implementation, or retains the known V9 palette integration. |
| SnappyMovement | Supports the verified V7 controller and V11 boost integration. Existing speeds, dodge cooldown, shift-lock handling and input bindings are retained. |
| World | Uses the twelve V4 movement maps and V7 lobby, or the completed V11 versions. The existing vote service remains in charge. |

The installer also verifies Shared/Net/Remotes, GameConfig, the V6 vote service, AFK and dodge server scripts, ClientMain, their remote types, map floors/spawns and lobby spawn. Known literal GameConfig settings may vary; configuration code with an unknown structure is not executed or rewritten.

## What the safety checks do

Source markers alone are insufficient. The installer checks normalized source fingerprints, applies exact unique edits, and checks the resulting source versions. Unknown scripts and incomplete/manual integrations stop before replacement. In particular, the older `previous-integration` V3 map protocol is different and is not silently converted.

After compatibility checks pass, fresh temporary ModuleScripts compile the generated source inside uncalled functions. The installer does not run game modules, start the round loop, or access live saves while checking syntax. A compiler error stops installation and removes the temporary probes.

Original edited scripts and replaced world objects are archived under `ServerStorage/ExpansionV11Backup_<timestamp>`. Script copies record their original paths; executable backup copies are disabled. Commit failures restore original source and world parents and remove newly added systems. A complete rerun does not create another economy, duplicate clients, or enlarge maps again.

## If compatibility still fails

Read the **entire preflight error** in Output. It identifies the actual path, missing dependency, ambiguous owner, unsupported version, or source fingerprint. The installer preserves the project instead of guessing. If your scripts were edited after the supplied place, their exact current source or an updated `.rbxl` is needed to add a verified adapter. Do not remove the version checks or rename unrelated scripts to satisfy them.

Validation includes the supplied script layout, the reported missing-economy combination, the older supported V9 combination, preserved voting/AFK behavior, syntax failures, duplicate ownership, transaction rollback and repeated installation. Tests use Luau and Roblox test doubles. Native Studio rendering, physics, live networking and published DataStore behavior still need a playtest.
