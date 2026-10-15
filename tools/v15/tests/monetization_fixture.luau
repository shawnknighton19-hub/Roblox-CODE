local assertions=0
local function check(condition, message)
    assertions+=1
    assert(condition, message or 'assertion '..assertions)
end
local function signal()
    local callbacks={}
    local s={}
    function s:Connect(fn)
        local c={Connected=true}
        function c:Disconnect() self.Connected=false end
        callbacks[#callbacks+1]={fn,c}
        return c
    end
    function s:Fire(...) for _,item in ipairs(callbacks) do if item[2].Connected then item[1](...) end end end
    return s
end
local function environment()
    local e={now=100,warnings={},prints={},requests=0,ownsRequests=0,grants=0,attempts=0,threads={},records={}}
    e.os={clock=function() return e.now end,time=function() return math.floor(e.now) end}
    e.warn=function(message) e.warnings[#e.warnings+1]=message end
    e.print=function(message) e.prints[#e.prints+1]=message end
    e.Enum={InfoType={GamePass='GamePass',Product='Product'},ProductPurchaseDecision={NotProcessedYet='defer',PurchaseGranted='grant'}}
    e.players={PlayerAdded=signal(),PlayerRemoving=signal()}
    e.player={UserId=77,Parent=e.players,attrs={},signals={}}
    function e.player:GetAttribute(key) return self.attrs[key] end
    function e.player:SetAttribute(key,value)
        self.attrs[key]=value
        if self.signals[key] then self.signals[key]:Fire() end
    end
    function e.player:GetAttributeChangedSignal(key)
        self.signals[key]=self.signals[key] or signal()
        return self.signals[key]
    end
    function e.players:GetPlayers() return {e.player} end
    function e.players:GetPlayerByUserId(id) if id==77 and e.player.Parent==self then return e.player end end
    e.market={PromptGamePassPurchaseFinished=signal()}
    function e.market:GetProductInfo(id,kind)
        e.requests+=1
        if e.metadataError then error('metadata unavailable') end
        if e.info then return e.info(id,kind) end
        return {Name='Official Offer',IsForSale=true,PriceInRobux=123}
    end
    function e.market:UserOwnsGamePassAsync(userId,id)
        e.ownsRequests+=1
        if e.ownershipError then error('ownership unavailable') end
        return e.owned and e.owned[id]==true or false
    end
    e.config={Passes={{Key='VIP',Name='VIP',Id=0},{Key='Disco',Name='Disco',Id=0}},Bundles={{Key='Solar',Name='Solar',Id=0}},Abilities={{Key='Disco',Currency='Robux',PassKey='Disco'}}}
    e.settings={GemProducts={{Key='pouch',Name='Gem Pouch',ProductId=0,Gems=100}}}
    e.economy={}
    function e.economy.HABExpansionProfile() if e.profileError then error('profile failed') end return {Ready=e.player:GetAttribute('HussEconomyReady')==true} end
    local granted={}
    local function grant(_,key)
        e.attempts+=1
        if e.grantError then error('grant failed') end
        if not e.player:GetAttribute('HussEconomyReady') then return false end
        if not granted[key] then granted[key]=true;e.grants+=1 end
        return true
    end
    e.economy.HABGrantVIP=function(p) return grant(p,'VIP') end
    e.economy.HABGrantBundle=grant
    e.economy.HABGrantAbilityPass=grant
    e.economy.HABSetAbility=function() return true end
    e.economy.HABBuyAbility=function() return true end
    e.economy.HABEquipBundle=function() return true end
    e.economy.HABProcessGemReceipt=function() return e.confirmed==true end
    e.pack={Settings=e.settings,attrs={}}
    function e.pack:WaitForChild(name) return self[name] end
    function e.pack:GetAttribute(name) return self.attrs[name] end
    e.expansion={Config=e.config,Api={}}
    e.rs={HABExpansion=e.expansion,HABHalloween=e.pack}
    function e.rs:WaitForChild(name) return self[name] end
    e.game={}
    function e.game:GetService(name) return ({Players=e.players,MarketplaceService=e.market,ReplicatedStorage=e.rs})[name] end
    e.require=function(module) return module end
    e.script={Parent={EconomyServiceV9=e.economy}}
    e.task={}
    function e.task.spawn(fn,...)
        local thread=coroutine.create(fn)
        local ok,problem=coroutine.resume(thread,...)
        assert(ok,problem)
        if coroutine.status(thread)~='dead' then e.threads[#e.threads+1]=thread end
    end
    e.task.wait=function(seconds) return coroutine.yield(seconds or .01) end
    function e.run(fn,...)
        local thread=coroutine.create(fn)
        local results=table.pack(coroutine.resume(thread,...))
        local steps=0
        while results[1] and coroutine.status(thread)~='dead' do
            e.now+=results[2] or .01
            steps+=1;assert(steps<1000,'unbounded wait')
            if e.onWait then e.onWait(steps) end
            results=table.pack(coroutine.resume(thread))
        end
        assert(results[1],results[2])
        return table.unpack(results,2,results.n)
    end
    e.save=function(r) if not e.saveFails then r.savedRevision=r.revision end end
    function e.api(action,key)
        e.now+=.3
        return e.run(e.expansion.Api.OnServerInvoke,e.player,action,key)
    end
    return e
end
