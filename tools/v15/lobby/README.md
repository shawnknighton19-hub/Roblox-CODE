# V15 lobby polish

`LobbyBuilderV15.luau` replaces the ornate architecture around the current HABWAS booths with an open ivory plaza, a smaller bomb landmark, soft navy rails, two planters, and compact Abilities/Passes booths. The existing booth positions, shop tags, distance anchors, leaderboards, spectator overlook, Floor, LobbySpawn, and Lobby model identity remain intact. The retired Emotes booth keeps its compatibility names and receives visible Locker signage; `StandShopV15` opens the existing effects collection there.

The new work remains inside the existing 204 × 188 stud floor footprint. Existing leaderboard and overlook access uses two 28 stud wide ramps with a five stud rise over 24 studs. No stairs or jumping are required.

## Integration

- `Build(parent, origin?)` creates a new `HABPolishedLobbyV15` Model. Use `nil` parent to stage. The origin is the current Floor top-center CFrame; the default matches the uploaded HABWAS file.
- `Plan(lobby)` validates the exact original floor, spawn position, booth approaches, required subtrees, and expected original/already-updated Locker text. It returns the six old architecture Models to archive, any previous V15 root, and four effective label changes.
- `Apply(lobby, backupFolderInServerStorage)` builds before moving any live objects, then archives the old architecture and installs the addition. It returns `newModel, result`. `result.Undo()` reverses the completed operation if the enclosing installer fails afterward; it is idempotent and must be called before a subsequent lobby transaction. The backup also records each original sign text and its full path.
- Repeated installation replaces the generated V15 root without duplicating prompts. Original booths are neither cloned nor moved.
- Generated `PASSES` and `ABILITIES` ProximityPrompts use the existing `HABOpenPanel` routing. They add no scripts, remotes, or client authority over purchases.

For direct place packaging, the frozen `world-manifest.json` and `generated.rbxl` live beside these scripts. The manifest records the binary SHA256 and uses a repository-relative geometry path. Archive refs 6809, 6824, 6872, 7021, 7124, and 7169 under the installation backup. Parent generated root `HABPolishedLobbyV15` under the existing `Workspace/Lobby`. Apply only the listed original `Text` property edits and record originals in the installer restore manifest.

## Verification

`test_installer.py` executes the real builder through the deterministic Instance adapter. It covers initial installation, rerunning, unsafe preflight cases, failure during archiving, failure during final commit, and reversing completed transactions.

`check_routes.py` checks the combined geometry of the generated addition and the actual decoded retained parts. It tests spawn access, all eleven shop destinations, both ramps, four leaderboards, spectator access, four stud body clearance, and bounds. This is analytic geometry validation, not Roblox Humanoid or PathfindingService testing.

`export.py` uses the existing repository environment's Luau/Instance adapter and pinned reflection serializer, then independently decodes all 275 generated instances and their 3,294 property values. It handles the current UICorner serialization migration. All geometry adapters and analytic helpers are tracked in this repository. The filtered 13 KB reflection snapshot and pinned Go encoder source are included here. The retained-part fixture records the SHA256 of the uploaded HABWAS input; passing `--original /path/to/HABWAS.rbxl` verifies that input and its hierarchy before reusing the fixture. Unknown input versions stop for review.

`render.py` renders the exported real parts in Blender. Preview typography and lighting are approximate; the previews are not Roblox screenshots. Flat primitive assemblies separate overlapping top faces by tiny offsets to prevent visible coplanar flicker.

## Portable commands

From the repository root, with Python 3.10+, NumPy, zstandard, and the Luau CLI installed:

```sh
python tools/v15/lobby/test_installer.py
python tools/v15/lobby/check_routes.py
python tools/v15/lobby/check_routes.py --original /path/to/HABWAS.rbxl
python tools/v15/lobby/prepare_manifest.py --original /path/to/HABWAS.rbxl
```

Every command defaults to a fresh temporary output directory. Use `--out-dir` to keep outputs in a chosen directory and `--report` on the test/check scripts to save the validation report elsewhere. Find Luau on PATH, set `LUAU_BINARY`, or pass `--luau`. The environment's repository-adjacent `.cloud-tools/bin/luau` is also detected.

To regenerate the binary from the actual builder, install Go 1.23+ and run:

```sh
python tools/v15/lobby/export.py --go /path/to/go --out-dir /tmp/hab-lobby-export
```

The encoder dependencies are pinned in `encoder/go.mod` and `go.sum`; the first Go build may download them. You can instead pass `--encoder /path/to/previously/built/geometry-encoder`. Regeneration writes only to the selected output directory and does not overwrite the frozen packaging binary.

To render the exact exported geometry with Blender:

```sh
blender -b -P tools/v15/lobby/render.py -- --out-dir /tmp/hab-lobby-preview
```

The original game binary is not vendored. `original-lobby-fixture.json` contains only retained lobby part geometry and a few sign preview labels, exported from the verified upload.
