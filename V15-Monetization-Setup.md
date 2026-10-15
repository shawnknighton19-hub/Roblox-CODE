# Make your game passes and Gem packs available

V15 prepares the shop and verifies purchases on the server. Roblox must issue the real pass and product IDs before players can buy anything. All supplied IDs are **0**, so unconfigured offers show **Coming soon** or remain hidden. A suggested price is never displayed as a live selling price.

## 1. Create the passes in your experience

Open [Creator Dashboard](https://create.roblox.com/dashboard/creations), choose your published **Huss A Bomb experience**, then **Monetization → Passes → Create a Pass**. Use your own icons and descriptions. Open each created pass, enable its sale in **Sales**, and choose its Robux price. Copy its **pass ID** from the dashboard; an uploaded icon's image ID is a different thing.

| Config key | Pass name | Actual benefit | Optional starting price |
| --- | --- | --- | ---: |
| `FastOpen` | Fast Open | Skip the crate reveal animation. The reward and odds stay the same. | 79 |
| `Throw` | Bomb Pitcher | Unlock the existing aimed bomb throw with its 12-second cooldown. | 249 |
| `VIP` | Spotlight VIP | Permanent Spotlight title and subtle gold 3D aura. Cosmetic only. | 149 |
| `Disco` | Disco Double | Unlock the Disco Double ability. Decoys do not block hits or grant immunity. | 99 |
| `Confetti` | Confetti Cannon | Unlock the Confetti Cannon ability and its existing brief speed bonus. | 79 |
| `Phantom` | Phantom Sovereign | Guaranteed Phantom bomb skin and its named cosmetic set. | 299 |
| `Solar` | Solar Overdrive | Guaranteed Solar bomb skin and its named cosmetic set. | 299 |
| `Cyber` | Cyberstorm | Guaranteed Cyber bomb skin and its named cosmetic set. | 349 |
| `Glacier` | Glacial Monarch | Guaranteed Glacial bomb skin and its named cosmetic set. | 349 |

These are existing offers and benefits. The prices in the last column are optional starting suggestions. Set the actual prices in Creator Dashboard. Roblox's purchase dialog controls the final charge, including any regional or personalized price.

## 2. Create the repeatable Gem packs

In the **same experience**, open **Monetization → Developer Products → Create a Developer Product**. Create these three products and copy their **Developer Product IDs**.

| Config key | Product name | Gems delivered per purchase | Optional starting price |
| --- | --- | ---: | ---: |
| `pouch` | Gem Pouch | 100 | 49 Robux |
| `chest` | Gem Chest | 300 | 129 Robux |
| `vault` | Gem Vault | 750 | 299 Robux |

Use Developer Products for Gems because players can buy them repeatedly. Do not create a game pass for a Gem pack. Do not reuse a sold product ID for a different Gem amount. To stop offering a pack, keep its ID and set its `GemSalesEnabled` entry to `false`; this lets outstanding purchases finish correctly.

## 3. Enter all IDs in one place

After installing V15, open **ReplicatedStorage → HABMonetizationConfigV15** in Explorer. Replace only the appropriate zeroes:

```lua
Passes = {
    FastOpen = 0,
    Throw = 0,
    VIP = 0,
    Disco = 0,
    Confetti = 0,
},
Bundles = {Phantom = 0, Solar = 0, Cyber = 0, Glacier = 0},
GemProducts = {pouch = 0, chest = 0, vault = 0},
GemSalesEnabled = {pouch = true, chest = true, vault = true},
```

Leave any unfinished offer at `0`. Use plain integer IDs without quotation marks. Do not paste the example zeroes over IDs you have already configured. Expansion Config and Halloween Settings read this module, so there is no second set of IDs to maintain.

Save and **Publish to Roblox**, then join a **new server**. Changing the script while a server is running does not reload its cached configuration.

## 4. Check the finished purchase flow

1. Visit the lobby booths. Each configured, on-sale offer should show a Roblox price. A metadata request failure temporarily disables that offer and retries; it does not invent a price.
2. Open and cancel the Roblox purchase prompt first. Cancellation must not grant an item or Gems.
3. If using a real purchase to test, remember Roblox may charge actual Robux. Confirm that a permanent pass remains owned after leaving and rejoining, and that the correct bundle, title or ability is delivered after your profile loads.
4. Confirm that a Gem purchase increases the saved balance by exactly the advertised amount. Rejoin and check the same balance. Gems are acknowledged only after the profile's balance and purchase ledger are confirmed saved.
5. Test on an account that does not already own the pass. A game owner does not automatically own every game pass, and `/grant` does not simulate Roblox pass ownership.

The existing random-crate policy check remains active. Accounts restricted from paid random items receive guaranteed purchase options. Policy lookup failures also use guaranteed options until Roblox provides a permitted response. A purchased pass does not bypass those restrictions or improve crate odds.

## If an offer does not appear

- Check that the ID belongs to the correct pass or product **in this experience** and that the pass is on sale.
- Check server Output for `[HAB Passes]` or `[HAB Gems]`. Invalid or duplicate IDs produce a specific error.
- Wait for the saved profile to finish loading and return to the lobby before buying.
- Keep **HABGemPurchases** as the only `MarketplaceService.ProcessReceipt` owner. V15 preserves deferred receipts when product IDs are still zero and refuses to replace a detected competing handler.
- Keep existing sold IDs configured even when taking packs off sale. Unknown receipts return `NotProcessedYet` for Roblox to retry; they never grant an arbitrary pack.

Official references: [passes](https://create.roblox.com/docs/production/monetization/passes), [developer products](https://create.roblox.com/docs/production/monetization/developer-products), and [paid random items](https://create.roblox.com/docs/production/monetization/virtual-items#random-virtual-items).

Automated checks execute the actual Luau server modules and the uploaded economy receipt function with service doubles. They cover duplicate and overlapping receipts, failed saves, profile loading, ownership failures and sale metadata. They do not constitute a real Roblox purchase or native Studio playtest.
