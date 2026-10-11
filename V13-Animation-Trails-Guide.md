# V13: published animations and sculpted trails

## Set the published game to R6

In Roblox Studio, open **File → Avatar Settings** (also available from the Avatar tab). Open the **⋯ menu at the top** and choose **R6**. Save the avatar settings and publish the place again. Leave the running Roblox session and join a new server to test the published change.

Roblox documents this setting in [Avatar Settings](https://create.roblox.com/docs/studio/avatar-settings). These experience settings are not accessible to ordinary scripts. The Command Bar installer does **not** pretend to change them or replace your character with a different avatar.

Your supplied animation controller uses custom R6 animation IDs for every rig. It also loads tracks without protecting against individual failures and creates a missing Animator on the client. Those are concrete problems in the code; the exact error in your live server cannot be observed from this workspace.

## Install the update

Install V12 first if it is not already installed. Open **Huss-A-Bomb-V13.txt**, click **Raw**, select all and copy. Stop Play in Studio, open **View → Command Bar**, paste the whole file, and press Enter. Check Output for the installation result and any required setting steps. Save and publish after applying the update.

V13 is a complete incremental installer containing its own code payloads. It verifies the existing V12 scripts and animation controller, compiles the proposed sources without running gameplay, and backs up changed scripts under `ServerStorage/TrailAnimationV13Backup_<timestamp>`. The backup contains a restore manifest. It preserves maps, voting, AFK, movement tuning, owner commands, balances, purchases, and bomb skins. Unknown script variants stop installation with their paths instead of bypassing compatibility checks.

## Animation recovery

The repaired controller retains your custom idle, walk, run and fall IDs on R6. Each track loads independently, alongside its rig-matched Roblox default. If a custom track fails or never becomes usable, that state uses its default when available and reports the problem in Output. R15 spawns use compatible default tracks while you correct the R6 setting. This does not make R15 the intended rig for the rest of the game.

The server ensures that characters have an Animator for replication. The installer also restores the `HussDodgeV5` enable flag required by the verified procedural dodge controller, backing up its old value. Existing procedural dodge and bomb panic animations retain control of their poses; the update does not change speed, dodge distance, cooldowns or immunity.

If Output reports that a custom animation is unavailable or not authorized, publish that animation under the correct creator and use its permitted asset ID. For a group-owned experience, choose that group in the Animation Editor's **Creator** field when publishing the animation. See Roblox's [animation export instructions](https://create.roblox.com/docs/animation/editor#export-an-animation). Default clips provide a fallback when available; the code cannot grant access to a private animation.

## Trail collection

All 25 existing trail items keep their IDs, names, prices, ownership and equipped selections. New models and motion distinguish the effects instead of relying on color swaps. The lobby stand and collection Index show previews from the same trail builder used in play. The [trail gallery](TrailDesignsV13-Preview.png) is an offline render of the actual models.

Equipped effects appear while sprinting and weaving. They are local cosmetic geometry with no collision or movement advantage. Nearby-character and part limits keep the effect count bounded, and Reduced Motion suppresses them. Titles, emotes and perfect-weave feedback are preserved. Practice still awards no Coins, statistics or quest progress.

## Verify after publishing

Join a new server and check idle, walk, sprint, dodge, bomb panic and respawn. Confirm the character has **Torso**, **Left Arm** and **Right Arm** (R6), rather than UpperTorso and segmented limbs. Test with a second player to check animation replication. Equip several trails, inspect their stand/Index previews, then test sprint, weave, stopping, respawning and Reduced Motion.

Luau and deterministic Roblox API tests run in this workspace. Native Studio rendering, live animation asset permissions, multiplayer replication and the published avatar setting still require the above playtest.
