V15 combat adapts the active scripts extracted from the user's `HABWAS.rbxl`.
`patches.json` records the exact source references, hierarchy paths and hashes.
The six replacements keep their existing Studio instance names.

Run the portable regression suite with:

```sh
python tools/v15/combat/test_combat.py
```

The suite compiles all six replacements and executes the production contact
rules, action service and dodge server in a deterministic Roblox API adapter.
It also executes the production carrier lifecycle and movement speed helpers.
Raycasts, replication and Humanoid physics are adapted; this is not a native
Roblox Studio playtest. `CombatV15.validation.json` records the source hashes.

Changes:

- The last fraction of a swing's active contact window survives a server tick
  crossing into recovery. History older than 85 ms is not rewound.
- Projectile contact accounts for the target and projectile moving over the
  same interval. A wall always ends the projectile, including after a dodge.
- Contact events identify the attacker, receiver and attack type for the new
  strike, impact and parry animation clips. One attack transfers at most once.
- The server records a dodge only after validating it. Swing, throw and ability
  activation wait for the existing 0.72-second weave animation to finish.
  Swing cooldown remains 0.48 seconds and dodge cooldown remains 1.5 seconds.
- Ability activation during the player's own attack is rejected without
  consuming its cooldown. All nine ability definitions keep their ownership
  checks, durations, cooldowns and mechanical effects.
- Leap and Pogo retain the explicit ability launch. Ordinary jump is unchanged.
  Failed network-owner queries use the server launch path.
- A carrier walks at 27 and sprints at 35 instead of the base 24/32, retaining
  the existing three-point sprint advantage and adding it to walking. Practice
  bots use the same bonus. Death, transfer and removal clear the old carrier.
  The dodge speed cap remains 84; temporary boost caps remain unchanged.

The gameplay continues using the existing economy, reward eligibility, AFK,
map voting, practice isolation, pass entitlement and round state services.
