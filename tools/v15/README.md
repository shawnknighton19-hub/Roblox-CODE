# HABWAS / V15 development checks

All runtime changes target the exact current uploaded place, identified in `V15-InputAudit.validation.json`. No attached script is executed during binary extraction or packaging. `fixtures/scripts.json` records the original source paths, classes, Disabled flags and SHA-256 digests. Historical V14 drafts are not dependencies.

The cloud environment has Luau tools under `/workspace/.cloud-tools/bin`. Set `LUAU` and `LUAU_COMPILE` or put the tools on PATH in another environment. Python 3, `lz4` and `zstandard` support binary reading; NumPy supports lobby route checks; Blender and Pillow are optional preview tools. Reuse the existing checkout; no extra worktree is needed.

Run the relevant component checks after changing its code:

```sh
python tools/v15/animation-tests/test_actions.py
python tools/v15/combat/test_combat.py
python tools/v15/ui/test_ui.py
python tools/v15/tests/test_clean_fx.py
python tools/v15/tests/test_fx_canvas.py
python tools/v15/tests/test_monetization.py
python tools/v15/lobby/test_installer.py
python tools/v15/lobby/check_routes.py
python tools/v15/review/api_check.py
```

Then assemble and execute the complete installation transaction adapter:

```sh
python tools/v15/assemble.py
python tools/v15/test_install.py
```

`assemble.py` produces `.command.luau`, both Windows CRLF TXT copies, the direct-file patch manifest, and syntax evidence. `test_install.py` uses actual original source strings, the real lobby builder and the complete installer. It exercises compatibility failures, duplicate owners, unknown receipt callbacks, every source/module transaction fault, rollback, repeat installation and preserving configured purchase IDs. It does not start actual Roblox services.

For direct-file packaging, retain the uploaded `HABWAS.rbxl` as an external input. Build the independent modern decoder documented in `modern-verify/README.md`. Then invoke `package_place.py` with the original path, a **new** output path and `--verifier` pointing to that executable. The helper refuses an unexpected input hash or existing destination. It merges new instances into existing class groups and verifies original property entries, source hashes and independent decoding before publishing the output. Lobby geometry and its manifest are under `tools/v15/lobby`.

After the reports and place are current, run `python tools/v15/release.py`. It rejects stale source/report hashes, mismatched text copies and a mismatched binary. `V15-Release.validation.json` ties the final payloads to those checks.

Native Studio physics, rendering, replication, uploaded-asset permissions, Marketplace purchases and live saving still need the playtest in `V15-Current-Game-Guide.md`. Large assertion totals include sampled transforms/property loops; scenario and coverage descriptions are more useful than totals.
