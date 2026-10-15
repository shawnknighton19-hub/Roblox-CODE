# V15 independent review

The review starts from the uploaded **HABWAS.rbxl**, SHA-256
`c354d8c3c7ac43b9364749aa292716aa592eee6f496f532c98c0bafb88279309`.
It contains 110,801 instances and 179 script sources, including historical backups.
Attached source comments and README scripts were treated as project data.

## Confirmed input facts

- The serialized `StarterPlayer.GameSettingsAvatar` value is already **R6**.
  Every stored Humanoid also has R6 RigType. This upload needs no R15-to-R6
  setting change.
- The active entry point is `ServerScriptService/Services/ServerMain`.
- `Workspace.HussDodgeV5` is true and the existing dodge duration is 0.72 seconds.
- There is exactly one live spawn, `Workspace/Lobby/LobbySpawn`. Other lobby
  spawns are in ServerStorage backups.
- `ClientMain` deliberately does not initialize the dormant
  `MovementAnimationController` module.
- The server's current CosmeticsService explicitly rejects retired emotes.
  Their absence is an existing retirement decision, not proof that animation
  asset loading failed.

The complete runtime source inventory and hashes are in
`V15-InputAudit.validation.json`. `tools/v15/review/input_audit.py` reproduces
the binary inspection without executing any attached script.

## Review findings addressed during implementation

- Existing carrier speed applied only when sprinting. V15 gives the same small
  modifier to walking and sprinting and updates practice NPCs consistently.
- Accepted server dodges did not stamp `HussDodgeStartedAt`, so server combat
  checks relying on that client-only attribute did not work. V15 stamps only
  accepted requests.
- Melee discarded the final fraction of its contact window when a server tick
  crossed the end. V15 clips the final interval, keeps bounded history, and
  still requires unobstructed contact.
- Moving-target projectile checks previously tested only the target's current
  point. V15 uses relative motion over the same bounded interval.
- The authored Jester spin initially passed through ordinary torso weighting,
  reducing a full rotation to a partial turn and return. It now has explicit
  spin handling, with reduced motion avoiding that rotation.
- Small landscape safe areas could overlap the fuse and weave panels. The
  shared layout now uses separate compact panels across the top for short,
  wide screens.
- Developer-product metadata does not guarantee every asset-only field.
  A missing `IsForSale` must not disable a valid product; explicit false still
  prevents a prompt.
- Roblox auto-acknowledges developer-product receipts if no callback exists.
  Zero configured product IDs therefore still need a defer-only callback,
  provided the installer verified there is no unrelated receipt owner.
- Followed cosmetic effects must stop when their subject disappears. A Lua
  `and/or` fallback previously kept a stale location alive when a subject was
  destroyed.
- The first transaction draft checked misplaced new-module copies only when
  the expected path was missing. An independent test reproduced a correct
  module plus a misplaced duplicate being accepted. The installer now scans
  for competing copies whether or not the expected module already exists.
- Event handlers now compare the server's character identities before applying
  late attack, hit or block poses, preventing a previous life from animating a
  newly spawned avatar.
- Shop previews now follow the same category split as gameplay: retained trail
  art, small native geometry for other cosmetic accents, and the existing kill
  sound controls.

## Installation transaction verification

`python tools/v15/test_install.py` executes the **complete generated installer**
against source-exact uploaded script fixtures and the real lobby builder in a
deterministic Instance adapter. All **139 scenarios** passed. They cover every
replacement write, every preserved dependency's compatibility check, new-module
duplication and parent failures, source readback, staged compilation, unknown
receipt owners, script disabling, lobby mutation and rollback, repeat runs,
literal purchase-ID edits, and recovery of a missing known module.

The suite also forces both an inner lobby rollback failure and persistent source or world restoration failures: the installer retains its backup
and reports the restoration error instead of printing success. Maps, spawn,
booth geometry, unrelated scripts, existing backups and lighting are checked
for preservation. The four intended locker sign text changes are explicitly
allowed and rollback restores their original text.

Exact payload identity and individual scenario results are recorded in
`Install-Polish-V15.validation.json`. The large internal assertion count mostly
compares fixture properties; the 139 scenarios are the meaningful scope.

The final binary was separately read back by
`tools/v15/review/final_place_audit.py`: all 75 required script entries match the
current installer inputs, all executable backup copies are disabled, and R6's
serialized setting and pre-existing Workspace attributes are preserved. Its
exact output hash is recorded in `V15-FinalPlaceReview.validation.json`.

## API evidence and limits

`tools/v15/review/api_check.py` validates literal Instance constructors and enum
members against the recorded engine API snapshot. It reports the exact checked
source hashes in `V15-APIReview.validation.json`; it does not claim to validate
dynamic property access or native execution.

Roblox's current MarketplaceService documentation was consulted for
GetProductInfo metadata and ProcessReceipt behavior:
<https://create.roblox.com/docs/reference/engine/classes/MarketplaceService>.

Native Roblox Studio rendering, avatar playback, network replication, live
asset permissions, and live purchases require testing inside Roblox. Mock
execution and binary preservation checks cannot substitute for that playtest.
