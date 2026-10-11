# V11 compatibility installer independent review

Status: passed. No outstanding blocking findings.

The gameplay adapter classifies the complete normalized uploaded, V9, or V11 source before changing it. Each replacement additionally requires a unique exact anchor, and the result must match the reviewed full V11 source. Unknown/custom/partial sources are refused without writes. The existing Services lookup works for ServerMain at the server root or within ServerScriptService.Services.

The missing EconomyServiceV9 is added as a module in Services, with the existing V11 economy implementation and existing V9 storage identifiers. Boot still initializes Remotes before the services and starts RoundService last. This preserves the live game's vote and AFK protocols and avoids a second win award path.

The HUD adapter accepts the historical V10-on-V8 and V10-on-V9 branches, retaining the reference styling, existing callback paths, and round/bomb/vote/AFK behavior. MovementEffectsV8 gains the verified trail palette integration without replacing its animation/effect behavior. The movement adapter accepts complete reviewed V7/V11 sources only.

Dependency validation does not execute gameplay modules. Known code dependencies are fingerprinted in full. GameConfig accepts only its original assignment structure with finite numeric, Boolean, and plain quoted string literals; the remainder of the full module is fingerprinted after masking those values. This prevents arbitrary source from reaching the inert compile probes. Required remotes, startup paths, enabled owners, same-name conflicts, and required classes are checked before staging.

The installer compiles every prospective script body inside a fresh ModuleScript returning an uncalled function. All live edits and cloned world swaps follow successful compatibility/dependency/compile checks and backups. A complete V11 installation takes an idempotent no-op path; a failed commit restores source, geometry, attributes, and removes newly added systems.

One concrete review finding was corrected: complete V11-world repeats previously skipped the only LobbySpawn check. The installer now always validates lobby floor/spawn and active/template arena floor and real BasePart spawn counts, so missing geometry dependencies cannot be mislabeled as an already installed success.

Independent adapter checks: 44 assertions passed. These verify exact known full-output equality, BOM/CRLF handling for gameplay, refusal of custom source, idempotence, and unchanged AFK roster, voting cycle, lobby/spawn/grounding, freeze/release, timing, and bomb geometry/i-frame helpers. Their report is review/validation.json. Owner suites separately cover runtime gameplay, HUD/effects, dependencies, movement, and installer fault cases.

Limit: native Roblox Studio physics, pathfinding, DataStore access, ScriptEditor draft behavior, and the Studio ModuleScript require sandbox cannot be executed in this cloud workspace. Do not claim native Studio or live multiplayer was tested.

Final artifact: Install-Bomb-Expansion-V11.command.luau, SHA-256 `78d1d1f922ba576e22e86a91bc69a7aa82d3dfab7395029d867d9e4a79f618e9`, 187522 bytes. It exactly matches assembly of reviewed components, compiles with standalone Luau, and both Windows TXT aliases contain byte-equivalent code with CRLF line endings. Integrated owner suite: 92 scenarios / 4,994 assertions; three actual-world scenarios / 272 checks; 26 emitted-source compilations.
