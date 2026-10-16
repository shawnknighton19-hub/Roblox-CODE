# V16 original-style lobby

`LobbyBuilderV16.luau` preserves the original lobby floor, spawn instance, fountain, arrival architecture, promenades, and every shop model. Four category kiosks form the west row; four premium bundles form the east row. Crates, abilities and passes share the southeast approach. The existing leaderboard group faces inward from the rear. The former emotes kiosk is labeled Locker and its category remains compatible with the narrow StandShopV16 routing fix.

The original five-stud-high terrace is widened into a rounded observation deck. Its front edge is Z=-39.7, while the arena anchor moves from Z=-245 to Z=-190. At maximum map depth, 30.3 studs separate the arena and balcony. Invisible collision barriers prevent a weave from leaving the lobby and are excluded from camera queries. Existing maps/gameplay control access to the arena.

`Plan(lobby, arenaAnchor)` checks known original or installed V16 anchor poses, floor, spawn and sign text before changes. `Apply(lobby, backupFolder, arenaAnchor)` builds geometry before touching the world, clones every moved model into ServerStorage, records original text and arena position, archives the five replacement groups, and returns an idempotent `Undo` callback. All descendant part frames, model pivots and CFrame attributes move together, including animated bomb display origins. No running scripts are inserted by this geometry module.

## Reproduce

Use Python 3 with numpy, a Luau CLI, and the tracked Go encoder. Supply the exact pristine HABWAS upload; `mutations.py` verifies its SHA-256. It must never receive the rejected V15 place.

```sh
python tools/v16/lobby/export.py --out-dir /tmp/hab-lobby-v16 --luau /path/to/luau --go /path/to/go
python tools/v16/lobby/mutations.py --base /path/to/HABWAS.rbxl --luau /path/to/luau
python tools/v16/lobby/freeze.py --export-dir /tmp/hab-lobby-v16
python tools/v16/lobby/scene.py --generated /tmp/hab-lobby-v16/generated.raw.json --original /path/to/HABWAS.rbxl --out-dir /tmp/hab-lobby-v16
python tools/v16/lobby/test_installer.py --luau /path/to/luau --report LobbyInstallerV16.validation.json
python tools/v16/lobby/check_routes.py --scene /tmp/hab-lobby-v16/combined.raw.json --generated /tmp/hab-lobby-v16/generated.raw.json --maps /path/to/maps/generated.raw.json --report LobbyV16.validation.json
```

The encoder performs an independent decode and checks every generated property. `mutations.py` uses exact singleton property hashes and preserves untouched attribute bytes. The geometry-only retained fixture was independently decoded from the pristine upload, includes its checksum, and has no runtime scripts. `scene.py --decoded-original` can regenerate it from a pinned Go decoder property dump.

Optional offline previews require Blender. These are geometry previews with approximate fonts, not Roblox screenshots:

```sh
blender -b --python tools/v16/lobby/render.py -- --scene /tmp/hab-lobby-v16/combined.raw.json --out-dir /tmp/hab-lobby-v16
python tools/v16/lobby/scene.py --generated /tmp/hab-lobby-v16/generated.raw.json --original /path/to/HABWAS.rbxl --spectator-maps /path/to/maps/generated.raw.json --out-dir /tmp/hab-spectator-v16
blender -b --python tools/v16/lobby/render.py -- --scene /tmp/hab-spectator-v16/combined.raw.json --out-dir /tmp/hab-spectator-v16 --spectator
```

The spectator preview adds illustrative block avatars at real spawn points solely to show player scale; those preview markers are not included in the place. Sightline checks use five ordinary eye-height viewing positions, real spawn/head samples, and standing-clear ground and elevated deck samples for each map. The frozen set exposes 288 of 317 movement-lane/deck samples and 211 of 240 spawn-head samples; all 15 maps have visible major movement lanes. Map cover can still obscure players during normal play. Collision and sightline results are analytic; Roblox Humanoid and camera playtesting remains required.
