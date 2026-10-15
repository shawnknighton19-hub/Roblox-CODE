local function priorSettings()
local function previousSettings()
--!nonstrict
-- HAB_CRATE_UPGRADE_2. Server validates every purchase and currency change.
-- Replace the ZERO ProductId values only with YOUR experience's Developer Product IDs.
-- Do not reuse a ProductId for a different gem amount after selling it.
local S = {}
S.GemProducts = {
    {Key="pouch", Name="Gem Pouch", Gems=100, ProductId=0},
    {Key="chest", Name="Gem Chest", Gems=300, ProductId=0},
    {Key="vault", Name="Gem Vault", Gems=750, ProductId=0},
}
S.CratePrices = {Aura=40, Trail=30, BombFX=40, KillFX=50}
S.QuestGemRewards = {rounds=15, passes=25, wins=50}
S.TagRadiusBonus = 0.75 -- 5 -> 5.75 studs in the supplied game; walls and target immunity still apply.
S.RevealSeconds = 4.2
-- Reserved for later cosmetics. These are NOT purchasable or usable abilities yet.
S.FutureCosmeticSlots = {DodgeFX=false, AbilityFX=false}
return S

end
local S=previousSettings()
assert(type(S)=='table','Settings must return a table')
S.CratePrices=S.CratePrices or {}
for slot,price in pairs({Aura=40,Trail=30,BombFX=40,KillFX=50,DodgeFX=45}) do
 if S.CratePrices[slot]==nil then S.CratePrices[slot]=price end
end
S.GemProducts=S.GemProducts or {}
S.QuestGemRewards=S.QuestGemRewards or {rounds=15,passes=25,wins=50}
S.RevealSeconds=S.RevealSeconds or 4.2
S.TagRadiusBonus=S.TagRadiusBonus or .75
S.FutureCosmeticSlots={DodgeFX=true,AbilityFX=false}
-- HAB_CRATE_GUI_4. Ability gameplay is future work, not sold as a working ability.
return S

end
local S=priorSettings()
local IDS={pouch=0,chest=0,vault=0}for _,p in ipairs(S.GemProducts) do if IDS[p.Key] and IDS[p.Key]>0 then p.ProductId=IDS[p.Key] end end
S.RevealSeconds=7.2
require(game:GetService('ReplicatedStorage'):WaitForChild('HABMonetizationConfigV15')).ApplySettings(S)
return S
-- HAB_EXPANSION_7
