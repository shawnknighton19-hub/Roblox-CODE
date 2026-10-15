# V15 interface polish

Run `python tools/v15/ui/test_ui.py` with Luau available on PATH (or set `LUAU`). The test executes the production UI files using existing GUI doubles and saved-profile/API fixtures. It does not run Roblox Studio. It emits `UIV15.validation.json` and a local `snapshots.json` containing the actual constructed GuiObject properties.

`python tools/v15/ui/render_preview.py tools/v15/ui/snapshots.json` renders approximate layout previews with Pillow. The backgrounds and fonts are illustrative; native viewport models, gradients, clipping and Roblox font metrics require Studio. Only lobby/match PNGs are exported; locker viewport models need native Studio rendering.

Production targets:

| Uploaded ref | Existing target | New source |
|---|---|---|
| 8417 | StarterPlayer/StarterPlayerScripts/Controllers/HudController | HudControllerV15.luau |
| 27172 | ReplicatedStorage/HABExpansion/HABCombatHUD | HABCombatHUDV15.luau |
| 27161 | ReplicatedStorage/HABHalloween/HABReferenceTheme | HABReferenceThemeV15.luau |
| 8449 | StarterPlayer/StarterPlayerScripts/HABExpansionClient | HABExpansionClientV15.client.luau |
| 8446 | StarterPlayer/StarterPlayerScripts/HABCrateShopClient | HABCrateShopClientV15.client.luau |
| 8444 | StarterPlayer/StarterPlayerScripts/StandShopV12 | StandShopV15.client.luau |
| 8447 | StarterPlayer/StarterPlayerScripts/HABCombatFX | HABCombatFXV15.client.luau |
| new | ReplicatedStorage/HABModalV15 | HABModalV15.luau |
| new | ReplicatedStorage/HABUILayoutV15 | HABUILayoutV15.luau |

Disable the exact uploaded legacy health UI (ref 8481 `StarterGui/StarterGui/Ui`). Its duplicate `PixelHealthGui` is already suppressed by the main HUD; disabling stops its unnecessary per-frame work. Keep the five existing active UI script names, replacing their source rather than adding parallel LocalScripts.

The modal singleton transfers ownership before invoking the previous panel's closer, so an old release cannot release the new panel. Input gates must respect local player attribute `HABModalOwnerV15` in addition to existing flags. Every panel retains its original economy, map-vote, AFK, shop/proximity, receipt and ability remotes. The three retained locker categories are Bombs, Trails and Titles; current retired emotes stay retired. Walking into the former Emotes kiosk now opens the existing Effects collection. Its identity/anchor remain intact; it never exposes retired emote purchase controls.

The shared FXCanvasV15 wrapper owns all visual preview dispatch: trails retain the uploaded particle art; non-trail cosmetics use the new 3D accents; kill sounds keep their audio controls. Store and ability clients use verified `Profile.Offers` and `Profile.Products`, with local Marketplace pricing as available. Missing products remain disabled.
