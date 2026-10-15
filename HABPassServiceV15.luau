--!nonstrict
-- Server authority for existing permanent passes/bundles. No Studio ownership bypass.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Market = game:GetService('MarketplaceService')
local X = RS:WaitForChild('HABExpansion')
local Config = require(X.Config)
local Economy = require(script.Parent.EconomyServiceV9)
local S = {}
local started = false
local states, nextAt, offers, ids = {}, {}, {}, {}
for _, value in ipairs(Config.Passes) do offers[value.Key] = {Definition=value, Kind='Pass'} end
for _, value in ipairs(Config.Bundles) do offers[value.Key] = {Definition=value, Kind='Bundle'} end
local function validId(value)
    return type(value)=='number' and value==value and value>0 and value%1==0 and value<=9007199254740991
end
local function metadata(offer, force)
    local now = os.clock()
    if offer.Busy or (not force and now < (offer.NextCheck or 0)) then return end
    offer.Busy = true
    local ok, info = pcall(Market.GetProductInfo, Market, offer.Definition.Id, Enum.InfoType.GamePass)
    offer.Busy = false
    local price = ok and type(info)=='table' and info.PriceInRobux
    local available = ok and type(info)=='table' and info.IsForSale==true
        and type(price)=='number' and price==price and price>=0 and price%1==0
    offer.Available = available == true
    offer.Price = available and price or nil
    offer.LiveName = ok and type(info)=='table' and type(info.Name)=='string' and info.Name or nil
    offer.Reason = available and nil or (ok and 'Not currently on sale.' or 'Roblox shop information is temporarily unavailable.')
    offer.NextCheck = now + (ok and 120 or 15)
end
function S.Has(player, key)
    local state = states[player]
    return state and state.Owned[key]==true or false
end
local function deliver(player, key)
    for _, ability in ipairs(Config.Abilities) do
        if ability.PassKey==key and ability.Currency=='Robux' then return Economy.HABGrantAbilityPass(player, ability.Key) end
    end
    if key=='VIP' then return Economy.HABGrantVIP(player) end
    if offers[key] and offers[key].Kind=='Bundle' then return Economy.HABGrantBundle(player,key) end
    return true
end
local function safeDeliver(player, key)
    local ok, result = pcall(deliver, player, key)
    if not ok then warn('[HAB Passes] Delivery will retry for '..key..': '..tostring(result)) end
    return ok and result==true
end
local function refresh(player)
    local state = states[player]
    if not state or state.Busy then return end
    state.Busy = true
    local allChecked = true
    for key, offer in pairs(offers) do
        if player.Parent~=Players or states[player]~=state then break end
        if validId(offer.Definition.Id) then
            local ok, owned = pcall(Market.UserOwnsGamePassAsync, Market, player.UserId, offer.Definition.Id)
            if player.Parent~=Players or states[player]~=state then break end
            if ok and owned==true then state.Owned[key]=true end
            if not ok then allChecked=false end
            -- A temporary ownership request failure must not remove a verified entitlement.
            if state.Owned[key] then
                player:SetAttribute('HABPass'..key,true)
                safeDeliver(player,key)
            end
        end
    end
    state.Busy = false
    state.Checked = allChecked
    if states[player]==state and player.Parent==Players then player:SetAttribute('HABPassesChecked',allChecked) end
end
local function snapshot(player)
    local profile = Economy.HABExpansionProfile(player)
    local state = states[player]
    profile.Passes, profile.Offers = {}, {}
    for key, offer in pairs(offers) do
        local configured = validId(offer.Definition.Id)
        local owned = state and state.Owned[key]==true or false
        profile.Passes[key] = owned
        profile.Offers[key] = {
            Configured=configured, Available=configured and offer.Available==true,
            Owned=owned, Id=offer.Definition.Id, Kind=offer.Kind,
            Name=offer.LiveName or offer.Definition.Name, PriceInRobux=offer.Price,
            Reason=configured and (offer.Reason or 'Checking Roblox shop…') or 'Coming soon.',
        }
        if configured and os.clock()>=(offer.NextCheck or 0) then task.spawn(metadata,offer,false) end
    end
    profile.Checked = state and state.Checked or false
    return profile
end
function S.Init()
    if started then return end
    for key, offer in pairs(offers) do
        local id = offer.Definition.Id
        assert(id==0 or validId(id),'[HAB Passes] Invalid ID for '..key)
        if id>0 then
            assert(not ids[id],'[HAB Passes] One ID is assigned to several offers.')
            ids[id]=key
        end
    end
    started = true
    local function add(player)
        if states[player] then return end
        local state = {Owned={}, Checked=false, Busy=false}
        states[player] = state
        state.ReadyConnection = player:GetAttributeChangedSignal('HussEconomyReady'):Connect(function()
            if player:GetAttribute('HussEconomyReady') and states[player]==state then
                for key in pairs(state.Owned) do safeDeliver(player,key) end
            end
        end)
        task.spawn(refresh,player)
    end
    Players.PlayerAdded:Connect(add)
    Players.PlayerRemoving:Connect(function(player)
        local state=states[player]
        if state and state.ReadyConnection then state.ReadyConnection:Disconnect() end
        states[player]=nil; nextAt[player]=nil
    end)
    for _, player in ipairs(Players:GetPlayers()) do add(player) end
    for _, offer in pairs(offers) do if validId(offer.Definition.Id) then task.spawn(metadata,offer,false) end end
    Market.PromptGamePassPurchaseFinished:Connect(function(player, id, purchased)
        local state, key = states[player], ids[id]
        if purchased==true and state and key then
            -- This is Roblox's SERVER purchase-completion signal, never a client remote.
            state.Owned[key]=true
            player:SetAttribute('HABPass'..key,true)
            safeDeliver(player,key)
            task.spawn(refresh,player)
        end
    end)
    X.Api.OnServerInvoke = function(player, action, key)
        if type(action)~='string' or #action>20 or (key~=nil and (type(key)~='string' or #key>32)) then
            return {OK=false,Message='Invalid request.'}
        end
        local now = os.clock()
        if now<(nextAt[player] or 0) then return {OK=false,Message='Please wait.'} end
        nextAt[player]=now+.22
        local worked, result = xpcall(function()
            local ok, message, passId = true, nil, nil
            if action=='SelectAbility' then ok,message=Economy.HABSetAbility(player,key)
            elseif action=='BuyAbility' then ok,message=Economy.HABBuyAbility(player,key)
            elseif action=='EquipBundle' then
                if not S.Has(player,key) then ok=false;message='Bundle ownership is still loading or is not owned.'
                else ok,message=Economy.HABEquipBundle(player,key) end
            elseif action=='PassPrompt' then
                local offer=offers[key]
                if player:GetAttribute('InRound')==true or player:GetAttribute('HussPracticeActive')==true then
                    ok=false;message='Visit the shop in the lobby.'
                elseif player:GetAttribute('HussEconomyReady')~=true then ok=false;message='Your saved profile is still loading.'
                elseif not offer or not validId(offer.Definition.Id) then ok=false;message='This offer is coming soon.'
                elseif S.Has(player,key) then ok=false;message='Already owned.'
                else
                    metadata(offer,false)
                    if offer.Available then passId=offer.Definition.Id
                    else ok=false;message=offer.Reason or 'Checking Roblox shop. Please try again.' end
                end
            elseif action=='RefreshPasses' then
                local state=states[player]
                if state and now>(state.NextRefresh or 0) then state.NextRefresh=now+12;task.spawn(refresh,player) end
            elseif action~='Sync' then ok=false;message='Unknown request.' end
            return {OK=ok,Message=message,PassId=passId,Profile=snapshot(player)}
        end,debug.traceback)
        if worked then return result end
        warn('[HAB Passes] Request failed: '..tostring(result))
        return {OK=false,Message='The shop is temporarily unavailable. Your saved items are safe.'}
    end
    task.spawn(function()
        while script.Parent do
            task.wait(25)
            for player, state in pairs(states) do
                if player:GetAttribute('HussEconomyReady') then for key in pairs(state.Owned) do safeDeliver(player,key) end end
                if not state.Checked then task.spawn(refresh,player) end
            end
        end
    end)
    print('[HAB V15 Passes] Verified entitlements and live Roblox shop metadata ready. Zero IDs are unavailable.')
end
return S
