# V13 independent compatibility review

Reviewed the uploaded Animate controller, existing V12 dodge/panic controllers, new animation and trail code, and the V13 installer against Roblox API documentation and deterministic execution checks.

## Findings addressed

- The uploaded Animate used custom R6 clips on every rig and loaded every track without failure isolation. A failed first clip could prevent the remaining controller from initializing. V13 selects rig-compatible fallback clips, preserves reviewed custom R6 IDs, and handles each clip independently.
- `Animator:LoadAnimation()` returning without an error does not establish that a clip loaded. V13 checks for positive track length with a bounded wait. Fallback clips load independently so a denied custom asset does not block movement visuals.
- Animation replication requires an Animator initially created on the server. V13 identifies the server-created Animator and waits for the character to enter Workspace before loading tracks. Existing dodge and panic controllers keep their procedural joint ownership.
- `DodgeActionV6` and movement effects require `Workspace.HussDodgeV5 == true`. The V13 transaction restores this switch after verifying the exact controller sources, saves its former value in the backup, and restores it on rollback. A custom non-boolean value stops preflight.
- The new animation server controller is searched for throughout ServerScriptService before installation. A misplaced or duplicate copy stops preflight rather than adding a second controller.
- Streamed-out heads could retain a stale title reference. The updated collection runtime clears the old title and binds a replacement BasePart head.

## API checks

Roblox's current [Avatar Settings documentation](https://create.roblox.com/docs/studio/avatar-settings) places rig selection at **File → Avatar Settings → top ⋯ menu → R6** and explicitly states that these underlying experience settings are not accessible to scripts. V13 reports the required manual save/publish step. It does not invent a `StarterPlayer.CharacterRigType` property.

[Animator documentation](https://create.roblox.com/docs/reference/engine/classes/Animator#LoadAnimation) requires an Animator in Workspace and server creation for replication. [AnimationTrack.Length](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack#Length) is zero until loading completes. [Animation export instructions](https://create.roblox.com/docs/animation/editor#export-an-animation) explain selecting the group creator for group-owned games.

Trail previews use supported ViewportFrame, WorldModel, Model bounding-box and Camera APIs. The physical shop's GUI helpers retain their GuiObject check before reading ZIndex; SurfaceGui has no ZIndex property.

Run the additional property/enum review with:

```bash
python tools/v13/tests/test_trail_api.py --report
```

This runs all 25 actual trail designs through moving, stopping and preview creation/destruction paths. It checks every Model/Part/WedgePart property write against a small recorded Roblox API allowlist, including read-only status, and checks Material/PartType enum membership. The report contains API provenance and source hashes. Repeated property-write counts measure execution coverage, not that many distinct behavior tests.

## Limits

The workspace has Luau and deterministic Roblox test doubles, not Roblox Studio. These checks cannot confirm native rendering, asset ownership permission, the live experience's rig setting, or multiplayer animation replication. The publish/playtest steps in `V13-Animation-Trails-Guide.md` remain required. No additional blocking source/API issue was found in this review.
