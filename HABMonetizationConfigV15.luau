--!nonstrict
-- Edit IDs HERE after creating the passes/products in THIS experience's Creator Dashboard.
-- 0 disables an offer. IDs are identifiers, not prices. Roblox controls the final purchase price.
-- Game passes are permanent. Gem packs are Developer Products, handled by HABGemPurchases.
local M = {
    Version = 15,
    Passes = {
        FastOpen = 0, -- Fast Open: skips reveal; never changes crate odds.
        Throw = 0, -- Bomb Pitcher: existing aimed throw, same cooldown.
        VIP = 0, -- Spotlight title and a subtle gold 3D aura.
        Disco = 0, -- Disco Double ability.
        Confetti = 0, -- Confetti Cannon ability.
    },
    Bundles = {Phantom = 0, Solar = 0, Cyber = 0, Glacier = 0},
    GemProducts = {pouch = 0, chest = 0, vault = 0}, -- 100, 300, 750 Gems respectively.
    -- Turn a pack off here without deleting its ID: past receipts must remain deliverable.
    GemSalesEnabled = {pouch = true, chest = true, vault = true},
}

local function id(value, label)
    assert(type(value) == 'number' and value == value and value >= 0
        and value <= 9007199254740991 and value % 1 == 0,
        '[HAB V15] '..label..' must be 0 or a positive integer Roblox ID.')
    return value
end
function M.ApplyExpansion(config)
    local used = {}
    for _, group in ipairs({{config.Passes, M.Passes}, {config.Bundles, M.Bundles}}) do
        for _, offer in ipairs(group[1]) do
            local value = id(group[2][offer.Key], 'pass '..tostring(offer.Key))
            assert(value == 0 or not used[value], '[HAB V15] Duplicate game-pass ID: '..tostring(value))
            if value > 0 then used[value] = true end
            offer.Id = value
        end
    end
    config.MonetizationVersion = 15
    return config
end
function M.ApplySettings(settings)
    local used = {}
    for _, offer in ipairs(settings.GemProducts) do
        local value = id(M.GemProducts[offer.Key], 'Gem product '..tostring(offer.Key))
        assert(value == 0 or not used[value], '[HAB V15] Duplicate Gem product ID: '..tostring(value))
        if value > 0 then used[value] = true end
        offer.ProductId = value
        offer.SalesEnabled = M.GemSalesEnabled[offer.Key] ~= false
    end
    return settings
end
return M
