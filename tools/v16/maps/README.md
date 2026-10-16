The V16 map builder replaces the fifteen arenas from the pristine HABWAS place.
It keeps the original names, map-vote identities, direct `Floor`/`Spawns`
contracts, and existing gameplay scripts. The original HUD is outside this work.

`MapBuilderV16.luau` has three creation-only entry points:

- `Build(name, parent, origin)` creates one named arena with its floor top at
  `origin` (default zero). A failed build destroys its staged model.
- `BuildAll(parent)` returns a staged `MapLibrary` folder containing all fifteen.
- `BuildArchive(options)` returns a detached container with `MapLibrary`,
  `BombTagV6Previews`, `BombTagPreviewGalleryV5`, and `Maps`. Options default to
  `VotedMap="Sunset Docks"`, `MapName="Sky Garden"`, and anchor `(0,-27,-190)`.

The root installer owns dependency checks, originals backup, folder replacement,
and repeat-install detection. The builder never deletes existing instances or
changes scripts. `world-manifest.json` binds the exact builder and geometry
hashes, identifies the four original roots to archive, and specifies destinations.
Anchor movement is owned by the separate lobby manifest.

The layouts range from 192 to 280 studs wide and 184 to 240 deep. They include a
cross-shaped orbital station, irregular pirate island, rear city skywalk,
castle battlement, lodge balcony, cave causeway, L-shaped docks, oval carnival,
merchant terrace, factory runway, and freight bridge. Each has sixteen clear
spawns, two independent ramp entrances, low cover, native bomb landmarks, and
high-resolution outlined sign lettering. Detail is native geometry with no
scripts, particle textures, decals, sounds, or imported models in the export.

Reproduce the validation with installed Luau, Python (NumPy/Pillow/msgpack), Go,
and optionally Blender. Run from the repository root; use a scratch output
directory so generated adapters and compiler caches are not committed:

```sh
python3 tools/v16/maps/export.py --out-dir /tmp/hab-maps-v16 --luau /path/to/luau
python3 tools/v16/maps/check_routes.py /tmp/hab-maps-v16/generated.raw.json --out /tmp/hab-maps-v16/route-validation.json
python3 tools/v16/maps/test_regressions.py /tmp/hab-maps-v16/generated.raw.json --out /tmp/hab-maps-v16/regression-validation.json
blender -b -t 6 -P tools/v16/maps/render.py -- --scene /tmp/hab-maps-v16/generated.raw.json --out-dir /tmp/hab-maps-v16/previews
python3 tools/v16/maps/gallery.py /tmp/hab-maps-v16/previews MapsV16-Preview.png
python3 tools/v16/maps/freeze.py /tmp/hab-maps-v16
```

`export.py` executes the actual builder with the existing deterministic Instance
adapter, converts against the pinned official Roblox reflection schema, and
checks every serialized property after a binary encode/decode. `check_routes.py`
uses analytic part geometry, a two-stud grid, and a two-stud avatar clearance
radius. It checks all spawn pairs, exact spawn footprints, ramp grades and
samples, independently usable ramp entrances, and actual visual regressions
found during rendering. Mutation tests demonstrate rejection of reversed or
noncolliding ramps, duplicate spawns, and coplanar paint/foundation geometry.

These checks do not simulate Roblox Humanoid physics, network latency, bot AI,
or rendering. The preview is an offline render of the actual generated parts.
Studio multiplayer testing remains necessary before publishing.
