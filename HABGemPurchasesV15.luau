--!nonstrict
-- The sole ProcessReceipt owner. A purchase is granted only after the existing
-- profile service confirms the Gem balance AND purchase ledger entry were saved.
local Marketplace=game:GetService('MarketplaceService')
local Players=game:GetService('Players')
local Pack=game:GetService('ReplicatedStorage'):WaitForChild('HABHalloween')
local Settings=require(Pack:WaitForChild('Settings'))
local S={}
local started,configured=false,false
local products,byKey,metadata={},{},{}
local function validId(value)
    return type(value)=='number' and value==value and value>0 and value%1==0 and value<=9007199254740991
end
local function refresh(product)
    local cached=metadata[product.Key]
    local now=os.clock()
    if cached and (cached.Busy or now<cached.NextCheck) then return cached end
    cached=cached or {};metadata[product.Key]=cached
    cached.Busy=true
    local ok,info=pcall(Marketplace.GetProductInfo,Marketplace,product.ProductId,Enum.InfoType.Product)
    local price=ok and type(info)=='table' and info.PriceInRobux
    cached.Available=product.SalesEnabled~=false and ok and type(info)=='table' and info.IsForSale~=false
        and type(price)=='number' and price==price and price>=0 and price%1==0
    cached.Price=cached.Available and price or nil
    cached.Name=ok and type(info)=='table' and type(info.Name)=='string' and info.Name or product.Name
    cached.Reason=ok and 'This Gem pack is not currently on sale.' or 'Roblox shop information is temporarily unavailable.'
    cached.NextCheck=now+(ok and 120 or 15)
    cached.Busy=false
    return cached
end
function S.Offers()
    local result={}
    if not configured then return result end
    for _,product in ipairs(Settings.GemProducts) do
        if products[product.ProductId] and product.SalesEnabled~=false then
            local cached=metadata[product.Key]
            if cached and cached.Available and os.clock()<cached.NextCheck then
                result[#result+1]={Key=product.Key,Name=cached.Name,Gems=product.Gems,
                    ProductId=product.ProductId,PriceInRobux=cached.Price}
            end
            if not cached or os.clock()>=cached.NextCheck then task.spawn(refresh,product) end
        end
    end
    return result
end
function S.Prompt(key)
    local product=byKey[key]
    if not configured or not product or product.SalesEnabled==false then
        return nil,'This Gem pack is unavailable.'
    end
    local cached=refresh(product)
    if not cached.Available then return nil,cached.Reason or 'Checking Roblox shop. Try again shortly.' end
    return product.ProductId,nil
end
function S.Init(Economy)
    if started then return configured end
    assert(type(Economy)=='table' and type(Economy.HABProcessGemReceipt)=='function','[HAB Gems] Durable receipt service is missing.')
    if Pack:GetAttribute('HABReceiptConflict')==true then
        warn('[HAB Gems] Another receipt handler was detected. Robux packs remain unavailable.')
        return false
    end
    local count=0
    for _,product in ipairs(Settings.GemProducts) do
        assert(product.ProductId==0 or validId(product.ProductId),'[HAB Gems] Invalid Developer Product ID.')
        assert(validId(product.Gems),'[HAB Gems] Invalid Gem amount.')
        assert(type(product.Key)=='string' and #product.Key>0,'[HAB Gems] Invalid pack key.')
        if product.ProductId>0 then
            assert(not products[product.ProductId] and not byKey[product.Key],'[HAB Gems] Duplicate pack ID or key.')
            products[product.ProductId]=product;byKey[product.Key]=product;count+=1
        end
    end
    started=true
    Marketplace.ProcessReceipt=function(info)
        if type(info)~='table' or not validId(info.ProductId) or not products[info.ProductId]
            or not validId(info.PlayerId) or type(info.PurchaseId)~='string' or #info.PurchaseId<1 or #info.PurchaseId>200 then
            warn('[HAB Gems] Unknown or invalid receipt deferred; never acknowledged without its configured grant.')
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        local player=Players:GetPlayerByUserId(info.PlayerId)
        if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
        local deadline=os.clock()+12
        while player.Parent==Players and player:GetAttribute('HussEconomyReady')~=true and os.clock()<deadline do task.wait(.2) end
        if player.Parent~=Players or player:GetAttribute('HussEconomyReady')~=true then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        local ok,confirmed=pcall(Economy.HABProcessGemReceipt,info)
        if ok and confirmed==true then return Enum.ProductPurchaseDecision.PurchaseGranted end
        if not ok then warn('[HAB Gems] Receipt retained for retry: '..tostring(confirmed)) end
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    configured=count>0
    for _,product in pairs(products) do if product.SalesEnabled~=false then task.spawn(refresh,product) end end
    print('[HAB V15 Gems] '..count..' receipt products configured; every grant requires a confirmed profile save.')
    return configured
end
return S
