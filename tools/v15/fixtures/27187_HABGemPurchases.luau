
--!nonstrict
-- HAB_CRATE_UPGRADE_2. This is the ONE ProcessReceipt owner for configured Gem products.
local Marketplace=game:GetService('MarketplaceService')
local Players=game:GetService('Players')
local Settings=require(game:GetService('ReplicatedStorage'):WaitForChild('HABHalloween'):WaitForChild('Settings'))
local S={};local started=false;local configured=false
function S.Init(Economy)
    if started then return configured end
    started=true
    local known={};local count=0
    for _,p in ipairs(Settings.GemProducts) do
        assert(type(p.ProductId)=='number' and p.ProductId>=0 and p.ProductId%1==0,'Invalid Developer Product ID')
        assert(type(p.Gems)=='number' and p.Gems>0 and p.Gems%1==0,'Invalid Gem amount')
        if p.ProductId>0 then
            assert(not known[p.ProductId],'Duplicate Gem product ID')
            known[p.ProductId]=true;count=count+1
        end
    end
    if count==0 then
        print('[HAB Gems] Quest Gems active; no Robux products configured. Receipt callback not changed.')
        return false
    end
    configured=true
    Marketplace.ProcessReceipt=function(info)
        if type(info)~='table' or not known[info.ProductId] then
            warn('[HAB Gems] Unknown receipt product. Not acknowledged; configure its product handler.')
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        local player=Players:GetPlayerByUserId(info.PlayerId)
        if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
        -- Allow the profile loader to finish, without spending a receipt on an empty profile.
        local untilAt=os.clock()+12
        while player.Parent==Players and player:GetAttribute('HussEconomyReady')~=true and os.clock()<untilAt do task.wait(.2) end
        local ok,confirmed=pcall(Economy.HABProcessGemReceipt,info)
        if ok and confirmed then
            return Enum.ProductPurchaseDecision.PurchaseGranted
        end
        if not ok then warn('[HAB Gems] Receipt retry required: '..tostring(confirmed)) end
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    print('[HAB Gems] '..count..' Robux products configured; grants require saved receipts.')
    return true
end
-- HAB_CRATES_REPAIR_3
return S


