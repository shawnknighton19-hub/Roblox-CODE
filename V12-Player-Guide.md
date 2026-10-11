# Owner commands and lobby shops (V12)

## Install in Studio

Open `Huss-A-Bomb-V12.txt` on GitHub, click **Raw**, select all, and copy. In Roblox Studio, stop Play, open **View → Command Bar**, paste the entire script, and press Enter. Check Output for the installation result, save your place, and then start Play. The TXT contains the complete installer; you do not need to paste the individual modules.

This update keeps existing earned balances, purchases, map voting, AFK, movement, and the approved HUD style. It checks the source versions and required dependencies before writing changes. An unfamiliar script stops installation with its path; keep that diagnostic instead of removing the version check.

## Give yourself Coins or cosmetics

In the game's chat, use:

```text
/grant help
/grant coins 10000
/grant bomb Supernova
/grant trail Arctic Rush
/grant title Bomb Legend
/grant emote Disco Spin
/grant all
```

Catalog IDs also work, for example `/grant bomb bomb_nova`. `all` unlocks every catalog cosmetic; it does not fabricate wins, kills, Final Stands, or quest progress. Coins are granted separately. A grant never runs arbitrary code.

Only Roblox's recorded owner can use these commands. For a user-owned experience, that is its creator account. For a group-owned experience, that is the group's owner, not every group administrator. If ownership cannot be verified, the command refuses the grant. An unpublished local place with no creator ID cannot authorize an owner; test in a place published under your account. Commands give items to the person invoking them, not other players.

Studio uses temporary preview profiles, so Coins and items granted during a Studio test reset when that test ends. In the published game, grants use the existing saved profile. Solo practice still awards no Coins, persistent statistics, or quest progress; an explicit owner grant is a separate administrative action.

## Shop at the stands

Walk up to a Bombs, Trails, Titles, or Emotes counter in the lobby. Its physical panel becomes interactive automatically. Select an item, browse pages, and buy or equip it at the counter. Walking away, dying, or entering a round closes browsing. Purchases are checked on the server against the correct stand and your actual balance.

The global Shop buttons are removed. The collection Index remains available to browse your collection and equip owned items. Buying takes place at the stands.

## Bombs and carrier animation

The 25 bomb skins keep their existing IDs and prices, with new geometry and details matched to their names. Their extra parts are cosmetic and do not enlarge the transfer radius.

Bomb passing selects the nearest eligible contact and checks walls and sampled movement. Dodge immunity, the fuse, and the existing pass locks remain in force. The carrier gains a procedural panic pose and blue tear effects. Running and dodging still use the existing movement system; no animation upload is needed.

## Before publishing

Playtest the update with one player and two players. Check owner commands with the owner and a non-owner account; approach and leave each stand; purchase and equip a skin; pass the bomb while running past another player and around a wall; dodge while carrying; and confirm that solo practice leaves progression unchanged. Also check a published server's save and rejoin behavior.

Automated checks here run with Luau and Roblox API test doubles. Native Studio rendering, input, physics, replication, and live DataStores require these playtests.
