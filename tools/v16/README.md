# Fresh HABWAS / V16 development

Use the existing checkout. The tracked `HABWAS.rbxl` is the immutable input; `place_patch.json` identifies its SHA-256. No V15 runtime source is installed. Selected binary codecs, reflection metadata and exact original script fixtures under `tools/v15` are shared development tooling.

The configured environment already has Luau under `/workspace/.cloud-tools/bin`, Python with `lz4`, `zstandard` and NumPy, the pinned Go geometry encoder, and a modern Rust RBXL verifier. Blender/Pillow are optional for offline previews. Do not replace the original upload when rebuilding.

Relevant source checks:

```sh
python tools/v16/animation-tests/test_actions.py
python tools/v16/weave/test_weave.py
python tools/v16/animation-tests/test_weave_integration.py
python tools/v16/tests/test_effect_cleanup.py
python tools/v16/review/test_boot.py --manifest tools/v16/place_patch.json --new-maps
python tools/v16/review/api_check.py
```

The bootstrap test executes the actual four server Scripts and complete transitive modules with deterministic service doubles. The geometry route tests inspect the generated solids. Assertion totals include sampled pose/property loops; scenario coverage matters more than raw totals. Native Studio execution is not claimed.

`maps/export.py` and `lobby/export.py` execute the actual Luau builders with a geometry adapter and serialize their instances using the pinned encoder in `tools/v15/lobby/encoder`. Use `--help` for output/tool paths. `lobby/mutations.py` derives exact original/new property records, including CFrame attributes used by rotating shop displays. Regenerate the geometry manifests and checks when editing builders. Large intermediate JSON/render outputs belong in scratch directories.

Assemble the complete Command Bar payload and Windows CRLF TXT with:

```sh
python tools/v16/assemble.py
```

The assembly includes exact original/target compatibility checks, inert syntax probes, staged maps, independent rollback journals and safe reruns. It does not call live game services during preflight.

Package a **new** output file using the modern verifier documented in `tools/v15/modern-verify/README.md`:

```sh
python tools/v16/package_place.py HABWAS.rbxl HABWAS-Polished-V16.rbxl --verifier /path/to/hab-rbxl-verify
python tools/v16/release_check.py
```

The packager refuses an existing destination or changed input. It preserves original class groups, verifies every original entry in rewritten property arrays, archives replaced world roots, journals moved booth properties and checks the encoded file with a second decoder. `release_check.py` rejects stale source/report hashes or inconsistent installer/TXT/game artifacts.

See `V16-Install-and-Playtest.md` for the user-facing Studio checks and recovery instructions.
