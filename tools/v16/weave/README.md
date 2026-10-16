# V16 weave animation validation

These files validate the animation replacement against the original HABWAS protocol.
They do not run Roblox Studio or simulate collision, replication, or the Animator.

Production changes:

- Replace original ref **8437**, `StarterPlayer/StarterPlayerScripts/DodgeWeaveV5`, with `DodgeWeaveV16.client.luau`.
- Add ModuleScript `ReplicatedStorage/HABWeaveAnimationsV16` from `HABWeaveAnimationsV16.luau`.
- Keep original SnappyMovement, DodgeIFrameServer, RoundService, BombService and HABActionService unchanged.

The original movement controller still owns the 0.72-second dodge, speed, distance,
cooldown, facing and collision. The replacement only writes body joint `Transform`
and local animation ownership attributes. It creates no particles or images and
loads no external animation assets.

Run from the repository root:

```sh
python3 tools/v16/weave/test_weave.py
python3 tools/v16/weave/preview.py
```

Luau CLI and compiler default to `/workspace/.cloud-tools/bin`; set `LUAU` and
`LUAU_COMPILE` to override them. The optional preview needs NumPy and Pillow.
The vendored adapter supplies deterministic CFrame, Instance and signal behavior.
The suite uses a connected canonical R6 rig and a connected R15 skeleton, including
rotated R6 bind axes, then executes both actual production sources.

The suite covers all eight directions, bounded finite transforms, terminal foot
height, unchanged physics root, no accumulated transforms, fresh Animator pose
restoration, original local and remote events, late packets, invalid timestamps,
action/weave ownership, late rig setup, death, pause, respawn and teardown.
`WeaveV16.validation.json` records final source hashes and the measured foot-plane
errors. `WeaveV16-Poses.png` and `WeaveV16-Preview.gif` render the actual client
transforms on an offline block rig. The GIF plays at half speed for inspection.

Cross-system tests are maintained by the action animation implementation in
`tools/v16/animation-tests/test_weave_integration.py`; they execute both clients
in both callback registration orders.

Studio playtesting remains required for the final visual result during actual
movement, both avatar rig types, slopes, equipped trails, and online replication.
