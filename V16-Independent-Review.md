# Independent V16 review

The baseline is the tracked `HABWAS.rbxl`, SHA-256 `c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309`. The previous V15 game is not the starting point.

## Confirmed startup fault and narrow correction

Original `ServerScriptService/Services/ServerMain` initializes Economy before BombService and RoundService. Original Economy.Init sets `started=true`, then calls `DataStoreService:GetDataStore` and `GetOrderedDataStore` without protection. Either getter throwing aborts that bootstrap before rounds start. This was reproduced by executing the exact original bootstrap and complete project module bodies with injected platform failures. Without the user's Studio Output, this is a confirmed failure path, not a confirmed diagnosis of their previous session.

`EconomyServiceV16.luau` protects the two handle acquisitions independently and retries unavailable handles every five seconds in the existing maintenance loop. It changes no store/key identities, profile format, lease rules, receipt logic, reward eligibility, or purchases. An unavailable profile remains unavailable. It never creates a temporary spendable balance, resets saved progress, or acknowledges an unconfirmed purchase. The original existing loader still stops after its bounded loading period; if platform access becomes available later, rejoin to load the profile.

The original ServerMain, RoundService, BombService, HABActionService, PracticeServiceV11 and SnappyMovement are preserved. The only Economy source changes are the acquisition helper, replacing the unprotected getters with that helper, and retrying it from maintenance.

## Executed integration checks

Run:

```sh
python tools/v16/review/test_boot.py --manifest tools/v16/place_patch.json --new-maps
python tools/v16/review/api_check.py
python tools/v16/review/test_install.py
```

The boot adapter executes all four active original server Scripts and all 30 required module bodies, including the original archive-decoding module and actual decoded archive/catalog. The optional manifest overlays the final V16 sources, and `--new-maps` executes MapBuilderV16.BuildAll before the original vote and round loop.

Scenarios cover both original unprotected getter failures; ordinary two-player rounds, final duel, results, saved rewards and lobby return; unavailable saving with playable rounds and no temporary economy; ordered rankings outage with healthy profiles; later store recovery and idempotent initialization; durable receipt confirmation/deduplication; failed UpdateAsync access; solo bots without coins or competitive stats; AFK pause/resume plus a second player changing practice into a real match; reversed CrateBoot/ServerMain startup order; and the relocated original tagged shop kiosk accepting nearby purchases while rejecting distant requests.

The platform services are deterministic doubles. The archive bytes are decoded and verified by Python, then exposed through the compression/JSON service adapter. Round raycasts use a test plane; this check is not a native physics, networking, visual, asset-permission, or published-server playtest. The separate geometry reports validate authored route geometry.

## Original world contracts retained

- One live SpawnLocation: `Workspace/Lobby/LobbySpawn`.
- ServerMain lives inside `ServerScriptService/Services`.
- MapLibrary contains 15 Model templates. Each requires a direct Floor BasePart and Spawns folder with direct BasePart markers. Practice requires at least two markers; the new templates provide sixteen.
- Voting offers three templates and aligns the chosen Floor's top to `Workspace/ActiveArenaAnchor`. The active clone is always named `Sky Garden`, from unchanged GameConfig, while DisplayName/VotedMap retain the chosen theme.
- `ReplicatedStorage/BombTagV6Previews` contains matching template names for the existing HUD. The old four-model PreviewGallery is a separate compatibility collection.
- One eligible player starts practice; two start a competitive match. AFK players are excluded. The original seven-second vote plus one-second result is followed by the configured ten-to-fifteen-second start timer, including its final three-second countdown.
- Live stores remain `HussEconomyV9` / `HussWinsV9`; Studio uses their `_StudioTest` counterparts.

## Animation and effect review

Current Roblox API metadata permits Motor6D and AnimationConstraint Transform, C0/C1 and Part0/Part1 access used by the new pose modules. Original movement remains the physics owner. Action/weave handoff uses the latest accepted timestamp; carrier panic yields while either owns the cosmetic pose.

Review found that the original ShieldBlock packet has no Id, while the initial V16 effect handler required one. This was corrected without changing the server protocol. The handler also now rejects previous-character ability packets and allows brief shield-charge replication delay before cleanup. Dedicated effect tests exercise those exact cases.

`V16-APIReview.validation.json` is a limited constructor/enum/public-member check, not proof that Roblox executes every API call successfully.

## Installer transaction verification

The installer transaction fixture is decoded directly from the original binary: all 179 source strings, exact parent identities, original map/spawn contracts and the complete 1,576-object lobby with real CFrames and typed attributes. It caught an incorrect initial assumption that the original arena Floor must collide; the uploaded Orbital Station already uses a noncollidable reference Floor, so that check was corrected to the actual contract.

The complete installer passes 48 scenarios covering installation and unchanged reruns, wrong-context/source/world rejection, syntax rejection, each modified source write and added-module parent failure, map replacement, lobby transformation/attachment, marker commit and source readback failures. Persistent restoration failures retain originals or an independent original lobby clone and report the retained backup. Syntax probes compile inert wrappers without executing attached gameplay code.

`InstallerV16.validation.json` binds these checks to the exact installer and builder hashes. All checks passed after the final map source freeze. The independently decoded final `HABWAS-Polished-V16.rbxl` also passed the complete installer's no-op contract with its live map and lobby graph unchanged. Reproduce that check with `python tools/v16/review/test_packaged_rerun.py HABWAS-Polished-V16.rbxl`; its result and artifact hashes are recorded in `PackagedRerunV16.validation.json`.
