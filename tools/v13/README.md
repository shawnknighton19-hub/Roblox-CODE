# V13 installer tooling

Build the self-contained Studio update with `python tools/v13/assemble.py`.
The command writes the Luau installer and two identical Windows CRLF text copies,
then compiles the installer and records every input file hash in `assembly.json`.
Use `LUAU_COMPILE` or put `luau-compile` on PATH. `LUAU`/PATH similarly selects the
Luau interpreter for the tests; the cloud workspace binary is a fallback only.

Run `python tools/v13/test_install.py` for transactional installation tests. The
fixture contains the exact reviewed V12 gameplay/controller sources and original
dependency sources. It creates a deterministic Instance tree, runs the real shop
stand builder, and executes the entire V13 installer with genuine Luau syntax
probes. Temporary generated tests go to the system temporary directory, or
`V13_TEST_OUTPUT`. This harness does not simulate native animation replication,
asset permission checks, rendering, humanoids, or Roblox Studio services.

V13 changes only the reviewed HUD, catalog, collection effects, physical-shop
controller and Animate source. It adds the trail design module and server
animation runtime. Existing object names stay stable for their callers. Main,
round, economy, bomb transfer, practice, AFK, map voting, movement, procedural
dodge, panic animation and other dependencies are checked before any commit.
Unknown custom source is preserved with a diagnostic. Reviewed Animate source
may vary only in its four positive numeric base-animation IDs.

The transaction preserves map and lobby instance identities. It backs up changed
scripts and records every addition in `RestoreManifest`. It also backs up and
enables `Workspace.HussDodgeV5`, required by the verified procedural dodge owner.
That flag and `HussTrailAnimationVersion` roll back with source failures; the
existing `HussExpansionVersion` remains 12. A complete rerun checks compatibility
and syntax without adding duplicate objects or backup folders.

The published character rig still requires the owner to open **File > Avatar
Settings > ... > R6**, save, publish, and join a new server. The installer does not
pretend that `StarterPlayer.CharacterRigType` exists or change protected avatar
settings. Both first install and rerun print this required step.

Historical V11/V12 source files and installers are unchanged by this build.

Component regressions execute the actual Luau sources using deterministic Roblox
API test doubles. Run the affected suite after changing its source:

```sh
python tools/v13/tests/test_animations.py
python tools/v13/tests/test_trail_designs.py
python tools/v13/tests/test_trail_runtime.py
python tools/v13/tests/test_trail_shop.py --report
python tools/v13/tests/test_trail_api.py --report
```

After assembly and installer tests, run `python tools/v13/verify_release.py` to
check the payload, Windows copies, compilation and recorded source hashes. It
writes `V13-Release.validation.json`; it does not claim native Studio validation.
