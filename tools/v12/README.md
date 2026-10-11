# V12 installer build and verification

`Install-Bomb-Expansion-V12.command.luau` is a complete, offline Roblox Studio Command Bar installer. `Huss-A-Bomb-V12.txt` and `Install-Bomb-Expansion-V12.txt` contain identical text with Windows CRLF line endings. No HTTP loader or asset execution is used.

Run these commands from the repository root with Python 3 and the official Luau CLI available:

```sh
python tools/v12/assemble.py
python tools/v12/test_install.py
python tools/v12/test_install.py --full-world
python tools/v12/test_install.py --compile-installed
python tools/v12/test_upgrade.py
python tools/v12/test_upgrade.py --full-world
python tools/v12/summarize_validation.py
```

Set `LUAU` and `LUAU_COMPILE` if the executables are not on `PATH`. Generated test programs, logs, emitted installed sources, and detailed JSON reports go to the operating system's temporary directory under `huss-v12-installer-tests`; set `V12_TEST_OUTPUT` to choose another directory. `assembly.json` records the bundled component hashes and Windows text equivalence.

The fixtures are source snapshots from the supplied Roblox project and its reviewed historical installers. Legacy adapters accept reviewed historical sources and reject custom or partial variants. V12 modules are compared with their complete canonical source. Existing V11 maps, active arena, and previews retain object identity while a lobby clone receives the physical shop panels. Upgrades preserve existing runtime module names and persistent economy store identifiers.

The test harness runs real production source adapters, complete installer transactions, inert script compilation, and actual authored world generators. It checks source/parent failure rollback, ambiguous/missing dependencies, unexpected custom scripts, map and lobby structure, chat alias conflicts, full reruns, and repair of missing owned modules. Its deterministic Instance adapter does **not** simulate Roblox rendering, Humanoid physics, networking, DataStores, or native Studio security. Native Studio one-player/two-player playtests remain necessary.

In Studio, installation requires Play to be stopped. The installer recursively locates `ServerMain`, verifies dependency sources and classes, syntax-compiles each resulting script inside an uncalled function, and makes backups before committing changes. On a complete repeat it verifies the same checks and exits without a new backup or duplicated systems. Runtime owner commands must not already persist in `TextChatService` in Edit mode; any `/grant` or `/hussgrant` collision is reported without overwriting it.
