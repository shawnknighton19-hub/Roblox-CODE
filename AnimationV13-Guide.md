# Published animation repair

V13 replaces the reviewed `StarterPlayer/StarterCharacterScripts/Animate` controller and adds `ServerScriptService/Services/AnimationRuntimeV13`. It preserves your four configured R6 idle, walk, run and fall animation IDs. Your movement physics, procedural dodge and carrier panic controllers keep their existing jobs.

The original controller attempted all custom R6 clips regardless of the spawned rig. It also loaded each clip before connecting its animation update, so an early thrown load error could prevent every later state from starting. The uploaded file does **not** contain a blocking `WaitForChild("Torso")`; that is not the diagnosis for this particular source.

V13 loads clips independently, waits for a playable nonzero `AnimationTrack.Length`, and provides a separate Roblox fallback for each state. It tries your custom clips only on R6 characters. The server creates or marks its Animator so client playback uses the replicated Animator. If a custom asset cannot load, the warning includes its asset ID and the state that fell back. This does not grant asset permissions or convert an R6 animation into R15.

## Restore the intended R6 avatar

1. Stop Play in Studio and open **File → Avatar Settings** (also available from the **Avatar** tab).
2. Open the **… menu in the top bar** and select **R6**.
3. Save the avatar settings, publish the updated game, and join a **fresh server**.

Roblox documents that these underlying game defaults are not accessible with scripts. The installer cannot change this experience setting from the Command Bar, and it does not pretend to have changed it. See [Roblox Avatar Settings](https://create.roblox.com/docs/studio/avatar-settings).

If a custom clip still reports a load error, check that its animation asset is permitted for the published experience. For a group-owned game, publish the animation under the correct group or grant the experience access through Roblox's supported asset-permission controls. Keep the animation's rig type R6 and replace only its corresponding ID after testing it. V13 retains your IDs and reports failures; it cannot verify private asset permissions from this workspace.

## Verification

Run `python tools/v13/tests/test_animations.py` to compile and execute the actual client, server and source-adapter code against deterministic lifecycle and asset-loading simulations. The tests cover both thrown failures and successful `LoadAnimation` calls whose tracks remain zero length, independent fallback states, delayed custom availability, R15 fallback selection, replication-owner selection, cleanup and preservation of approved custom IDs.

These tests do not replace a published Roblox session. Confirm idle, walking, sprinting, falling, dodge, panic arms/tears, respawn and another player's animation playback in Studio and then in a fresh live server.
