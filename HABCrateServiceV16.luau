
--!nonstrict
-- HAB_CRATE_UPGRADE_2. Server purchases, gem quests, policy-safe crates and bomb attribution.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Policy=game:GetService('PolicyService')
local Http=game:GetService('HttpService')
local Pack=RS:WaitForChild('HABHalloween')
local Catalog=require(assert(Pack:WaitForChild('Catalog',15),'Catalog missing'))
local Settings=require(assert(Pack:WaitForChild('Settings',15),'Settings missing'))
local Economy
local bootError='Starting profile service...'
local booting=false
local gemReady=false
local Proximity=game:GetService('ProximityPromptService')
local Api=Pack:WaitForChild('Api')
local Events=Pack:WaitForChild('Events')
local S={};local started=false;local policies={};local rates={};local bindings={}
local reported=setmetatable({},{__mode='k'})
local function label(actor)
    return actor and tostring(actor.DisplayName or actor.Name or 'Player'):sub(1,64) or ''
end
local function policyFor(p)
    local entry={random=false,reason='Policy is loading. Guaranteed purchases only.'}
    policies[p]=entry
    task.spawn(function()
        local ok,value=pcall(Policy.GetPolicyInfoForPlayerAsync,Policy,p)
        if policies[p]~=entry or p.Parent~=Players then return end
        entry.random=ok and type(value)=='table' and value.ArePaidRandomItemsRestricted==false
        entry.reason=entry.random and 'Every unowned item has equal odds. Or choose a guaranteed item.'
            or 'Random purchases are unavailable. Choose an exact item for the displayed guaranteed price.'
    end)
end
local function snapshot(p)
    local data=Economy and Economy.HABCrateProfile(p) or {Ready=false,Gems=0,Coins=0,Owned={},Equipped={},Revision=0,SaveStatus='UNAVAILABLE',Quests={}}
    data.ApiVersion=5;data.ServerReady=Economy~=nil;data.ServerMessage=bootError
    data.CanOpen=Economy and Economy.HABCanShop(p)==true or false
    local pol=policies[p]
    data.RandomAllowed=pol and pol.random==true or false
    data.PolicyMessage=pol and pol.reason or 'Guaranteed purchase mode.'
    data.Products={}
    for _,v in ipairs(Settings.GemProducts) do
        if v.ProductId>0 and gemReady then
            data.Products[#data.Products+1]={Key=v.Key,Name=v.Name,Gems=v.Gems,ProductId=v.ProductId}
        end
    end
    data.Order=Catalog.Order
    return data
end
local function permitted(p)
    local now=os.clock()
    local b=rates[p] or {tokens=8,at=now};rates[p]=b
    b.tokens=math.min(8,b.tokens+math.max(0,now-b.at)*2.5);b.at=now
    if b.tokens<1 then return false end
    b.tokens=b.tokens-1
    return true
end
local function triggerShop(prompt,p)
    local lobby=workspace:FindFirstChild('Lobby')
    local shop=lobby and lobby:FindFirstChild('HABCrateShop')
    if not shop or prompt.Name~='BrowseReliquary' or not prompt:IsDescendantOf(shop) then return end
    local point=prompt.Parent
    local root=p.Character and p.Character:FindFirstChild('HumanoidRootPart')
    if point:IsA('BasePart') and root and p:GetAttribute('InRound')~=true and (root.Position-point.Position).Magnitude<=26 then
        Events:FireClient(p,'Show')
    end
end
function S.CaptureOwner(actor)
    if not actor then return nil end
    return {UserId=actor.UserId or 0,Name=label(actor),KillFX=Economy and Economy.HABCrateSelection(actor,'KillFX') or nil,
        Practice=typeof(actor)~='Instance'}
end
local function dispatch(victim,owner,cause)
    local c=victim and victim.Character
    local h=c and c:FindFirstChildOfClass('Humanoid')
    if not h or reported[h] then return end
    reported[h]=true
    local root=c:FindFirstChild('HumanoidRootPart')
    local position=root and root.Position or c:GetPivot().Position
    if typeof(position)~='Vector3' or position.X~=position.X or position.Y~=position.Y or position.Z~=position.Z or position.Magnitude>1000000 then return end
    local killer=owner and owner.UserId~=(victim.UserId or 0) and owner or nil
    local id=killer and killer.KillFX
    if not id or not Catalog.ById[id] or Catalog.ById[id].Category~='KillFX' then id=nil end
    local event={Id=Http:GenerateGUID(false),Position=position,Time=workspace:GetServerTimeNow(),Cause=cause,
        VictimUserId=victim.UserId or 0,VictimName=label(victim),
        KillerUserId=killer and killer.UserId or 0,KillerName=killer and killer.Name or '',EffectId=id,
        Practice=typeof(victim)~='Instance' or (killer and killer.Practice==true) or victim:GetAttribute('HussPracticeActive')==true}
    -- Send to all clients: lobby spectators and the victim must also receive the feed.
    -- Each client distance-culls the VISUALS, not the kill feed.
    Events:FireAllClients('Detonation',event)
end
function S.Elimination(killer,victim,capturedOwner)
    -- Called before health is set to zero and before the bomb/character can be removed.
    -- The LAST successful giver owns this bomb. No victim's kill-FX fallback.
    dispatch(victim,capturedOwner or S.CaptureOwner(killer),'BOMB')
end
local function watchDeaths(p)
    local function character(c)
        task.spawn(function()
            local h=c:WaitForChild('Humanoid',12)
            if not h or p.Character~=c then return end
            local wasPlaying=p:GetAttribute('InRound')==true
            local leftAt=-math.huge
            local changed=p:GetAttributeChangedSignal('InRound'):Connect(function()
                if p:GetAttribute('InRound')==true then wasPlaying=true;leftAt=-math.huge
                elseif wasPlaying then leftAt=os.clock() end
            end)
            local died
            died=h.Died:Connect(function()
                if p.Character==c and (p:GetAttribute('InRound')==true or (wasPlaying and os.clock()-leftAt<.3)) then
                    dispatch(p,nil,'ELIMINATED')
                end
            end)
            c.Destroying:Once(function() changed:Disconnect();if died then died:Disconnect() end end)
        end)
    end
    p.CharacterAdded:Connect(character)
    if p.Character then character(p.Character) end
end
function S.Init()
    if started then return end
    started=true
    Pack:SetAttribute('HABServerState','STARTING')
    Pack:SetAttribute('HABServerIssue','')
    -- Bind the transport and prompt before any optional purchase integration.
    Proximity.PromptTriggered:Connect(triggerShop)
    Players.PlayerAdded:Connect(function(p) policyFor(p);watchDeaths(p) end)
    Players.PlayerRemoving:Connect(function(p) policies[p]=nil;rates[p]=nil end)
    for _,p in ipairs(Players:GetPlayers()) do policyFor(p);watchDeaths(p) end
    Api.OnServerInvoke=function(p,action,payload)
        if type(action)~='string' or #action>16 or not permitted(p) then
            return {OK=false,Message='Please wait a moment.',Profile=snapshot(p)}
        end
        if action=='Sync' then return {OK=true,Message=bootError,Profile=snapshot(p)} end
        if not Economy then return {OK=false,Message=bootError or 'Profile service is not ready.',Profile=snapshot(p)} end
        local success,result=xpcall(function()
            local ok,message,receipt,pending=true,nil,nil,false
            local removed=Catalog.DisabledVisualCategories or {}
            if action=='BuyCrate' and type(payload)=='table' and removed[payload.Category] then
                return {OK=false,Message='This visual collection is retired. Your saved items are preserved.',Profile=snapshot(p)}
            end
            if action=='Equip' and type(payload)=='table' and removed[payload.Category] and payload.Item~='' then
                return {OK=false,Message='This visual collection is retired. Your saved items are preserved.',Profile=snapshot(p)}
            end
            if action=='OpenStored' and type(payload)=='table' then
                for _,stored in ipairs(Economy.HABCrateProfile(p).StoredCrates or {}) do
                    if stored.Id==payload.Crate and removed[stored.Category] then
                        return {OK=false,Message='This retired crate can be refunded for its full saved Gem cost.',Profile=snapshot(p)}
                    end
                end
            end
            if action=='BuyCrate' or action=='OpenStored' or action=='RefundStored' then
                if type(payload)~='table' then return {OK=false,Message='Invalid inventory request.',Profile=snapshot(p)} end
                local pol=policies[p];local randomAllowed=pol and pol.random==true
                if action=='BuyCrate' then
                    ok,message,receipt=Economy.HABBuyStoredCrate(p,payload.Category,payload.Token,payload.Revision,payload.Choice,randomAllowed)
                elseif action=='OpenStored' then
                    ok,message,receipt=Economy.HABOpenStoredCrate(p,payload.Crate,payload.Token,payload.Revision,randomAllowed)
                else
                    ok,message,receipt=Economy.HABRefundStoredCrate(p,payload.Crate,payload.Token,payload.Revision)
                end
                if ok and receipt then
                    if Economy.HABConfirmInventory(p,receipt.Token,12) then
                        message=receipt.Kind=='Buy' and 'Crate saved to INVENTORY. It has NOT been opened.'
                            or receipt.Kind=='Open' and 'Effect unlocked and saved!' or 'Crate refunded and Gems saved.'
                    else
                        ok=false;pending=true;receipt=nil
                        message='Save confirmation delayed. RESUME preserves this transaction; no duplicate charge or consumption.'
                    end
                end
            elseif action=='Open' then
                ok=false;message='Crates are now stored. Buy a crate, then open it from INVENTORY.'
            elseif action=='Equip' then
                if type(payload)~='table' then return {OK=false,Message='Invalid equipment request.'} end
                ok,message=Economy.HABEquipCrate(p,payload.Category,payload.Item)
            elseif action=='ClaimQuest' then
                ok,message=Economy.HABClaimQuest(p,payload)
            elseif action=='GemPrompt' then
                if not gemReady then return {OK=false,Message='Robux packs are not configured or their receipt handler is unavailable.'} end
                if not Economy.HABCanShop(p) then return {OK=false,Message='Load your profile and return to the lobby.'} end
                for _,v in ipairs(Settings.GemProducts) do
                    if v.Key==payload and v.ProductId>0 then return {OK=true,ProductId=v.ProductId,Profile=snapshot(p)} end
                end
                return {OK=false,Message='This Gem product is not configured.'}
            else return {OK=false,Message='Unknown action.'} end
            return {OK=ok,Message=message,Receipt=receipt,Pending=pending,Profile=snapshot(p)}
        end,debug.traceback)
        if success then return result end
        warn('[HAB Crates] Request error: '..tostring(result))
        -- Do not tell the client to generate a new purchase token after an uncertain opening.
        return {OK=false,Pending=action=='BuyCrate' or action=='OpenStored' or action=='RefundStored',Message='Server error. See [HAB Crates] in Output; any opening token is retained.',Profile=snapshot(p)}
    end
    task.spawn(function()
        local ok,result=xpcall(function()
            local module=assert(script.Parent:WaitForChild('EconomyServiceV9',15),'EconomyServiceV9 missing')
            local value=require(module)
            for _,name in ipairs({'Init','HABCrateProfile','HABCanShop','HABBuyStoredCrate','HABOpenStoredCrate','HABRefundStoredCrate','HABConfirmInventory','HABEquipCrate','HABClaimQuest'}) do
                assert(type(value[name])=='function','Missing profile integration: '..name)
            end
            value.Init()
            return value
        end,debug.traceback)
        if not ok then
            bootError='Profile startup failed. See [HAB Crates] in server Output.'
            Pack:SetAttribute('HABServerState','ERROR');Pack:SetAttribute('HABServerIssue',tostring(result):sub(1,1500))
            warn('[HAB Crates] '..tostring(result))
            return
        end
        Economy=result;bootError=nil
        Pack:SetAttribute('HABServerState','READY')
        print('[HAB Crates] GUI SHOP READY / saved unopened crates / Gems / reference HUD')
        local gemOK,gemResult=pcall(function()
            if Pack:GetAttribute('HABReceiptConflict')==true then return false end
            return require(assert(script.Parent:WaitForChild('HABGemPurchases',15),'Gem handler missing')).Init(Economy)
        end)
        gemReady=gemOK and gemResult==true
        if not gemOK then warn('[HAB Gems] '..tostring(gemResult)..'. Quest Gems and the shop remain available.') end
        Pack:SetAttribute('HABRobuxReady',gemReady)
    end)
    task.delay(20,function()
        if not Economy and Pack:GetAttribute('HABServerState')=='STARTING' then
            bootError='Profile startup is delayed. Check the server Output for a missing dependency.'
            Pack:SetAttribute('HABServerState','WAITING');warn('[HAB Crates] '..bootError)
        end
    end)
end
-- HAB_CRATE_GUI_4
return S



-- HAB_COLLECTIONS_5
