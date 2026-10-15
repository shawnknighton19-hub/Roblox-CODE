do
    local e=environment()
    local ids=loadIds(e)
    local config={Passes={{Key='VIP'}},Bundles={{Key='Solar'}}}
    ids.ApplyExpansion(config)
    check(config.Passes[1].Id==0 and config.Bundles[1].Id==0,'zero IDs disabled')
    ids.Passes.VIP=555;ids.Bundles.Solar=555
    check(not pcall(ids.ApplyExpansion,config),'duplicate pass ID rejected')
    ids.Bundles.Solar=0;ids.Passes.VIP=-1
    check(not pcall(ids.ApplyExpansion,config),'negative ID rejected')
    ids.Passes.VIP=0/0
    check(not pcall(ids.ApplyExpansion,config),'NaN ID rejected')
    ids.Passes.VIP=1.5
    check(not pcall(ids.ApplyExpansion,config),'fractional ID rejected')
    ids.Passes.VIP=555;ids.ApplyExpansion(config)
    check(config.Passes[1].Id==555,'configured ID applied')
    local settings={GemProducts={{Key='pouch'},{Key='chest'}}}
    ids.GemProducts.pouch=900;ids.GemProducts.chest=900
    check(not pcall(ids.ApplySettings,settings),'duplicate products rejected')
    ids.GemProducts.chest=0;ids.GemSalesEnabled.pouch=false;ids.ApplySettings(settings)
    check(settings.GemProducts[1].ProductId==900 and not settings.GemProducts[1].SalesEnabled,'retired ID retains receipt identity')
end
do
    local e=environment();local passes=loadPasses(e);passes.Init()
    check(e.requests==0 and e.ownsRequests==0,'zero IDs never query ownership/metadata')
    local sync=e.api('Sync');check(not sync.Profile.Offers.VIP.Configured,'unconfigured offer')
    e.player:SetAttribute('HussEconomyReady',true)
    check(not e.api('PassPrompt','VIP').OK,'zero ID cannot prompt')
    e.market.PromptGamePassPurchaseFinished:Fire(e.player,999,true)
    check(not passes.Has(e.player,'VIP') and e.grants==0,'foreign purchase cannot unlock')
end
do
    local e=environment();e.config.Passes[1].Id=101;e.config.Bundles[1].Id=102;e.owned={[101]=true}
    local passes=loadPasses(e);passes.Init()
    check(passes.Has(e.player,'VIP'),'server verified ownership before profile')
    check(e.grants==0 and e.attempts==1,'late profile defers permanent grant')
    e.player:SetAttribute('HussEconomyReady',true)
    check(e.grants==1,'profile ready completes pending grant')
    local sync=e.api('Sync');check(sync.Profile.Offers.VIP.PriceInRobux==123,'live Roblox price')
    check(sync.Profile.Offers.VIP.Name=='Official Offer','live offer name')
    check(not e.api('PassPrompt','VIP').OK,'owned pass cannot reprompt')
    check(e.api('PassPrompt','Solar').PassId==102,'unowned verified sale prompts')
    e.player:SetAttribute('InRound',true)
    check(not e.api('PassPrompt','Solar').OK,'in-round prompting blocked')
    e.player:SetAttribute('InRound',false);e.player:SetAttribute('HussPracticeActive',true)
    check(not e.api('PassPrompt','Solar').OK,'practice prompting blocked')
    e.player:SetAttribute('HussPracticeActive',false)
    e.ownershipError=true;e.now+=30;e.api('RefreshPasses')
    check(passes.Has(e.player,'VIP'),'transient ownership failure retains verified pass')
    e.market.PromptGamePassPurchaseFinished:Fire(e.player,102,false)
    check(not passes.Has(e.player,'Solar'),'cancel does not grant')
    e.market.PromptGamePassPurchaseFinished:Fire(e.player,102,true)
    check(passes.Has(e.player,'Solar') and e.grants==2,'server purchase event delivers')
    e.market.PromptGamePassPurchaseFinished:Fire(e.player,102,true)
    check(e.grants==2,'duplicate completion remains idempotent')
    e.profileError=true
    check(not e.api('Sync').OK,'profile error is reported, not unhandled')
    e.players.PlayerRemoving:Fire(e.player)
    check(not passes.Has(e.player,'VIP'),'leave clears server entitlement cache')
end
do
    local e=environment();e.config.Passes[1].Id=101;e.player:SetAttribute('HussEconomyReady',true)
    e.metadataError=true;local passes=loadPasses(e);passes.Init()
    check(not e.api('PassPrompt','VIP').OK,'metadata failure blocks prompt')
    e.metadataError=false;e.info=function() return {IsForSale=false,PriceInRobux=500} end;e.now+=16
    check(not e.api('PassPrompt','VIP').OK,'off-sale pass blocks prompt')
    e.info=function() return {IsForSale=true,PriceInRobux=79} end;e.now+=121
    check(e.api('PassPrompt','VIP').PassId==101,'metadata recovers without restart')
end
do
    local e=environment();local gems=loadGems(e)
    check(not gems.Init(e.economy),'zero configured products stay unavailable')
    check(type(e.market.ProcessReceipt)=='function','zero IDs still defer past receipts')
    check(e.run(e.market.ProcessReceipt,{PlayerId=77,ProductId=1,PurchaseId='old'})=='defer','unknown past receipt not lost')
    local handler=e.market.ProcessReceipt;gems.Init(e.economy)
    check(e.market.ProcessReceipt==handler,'Init idempotent single owner')
    check(#gems.Offers()==0 and gems.Prompt('pouch')==nil,'zero products never advertised')
end
do
    local e=environment();e.pack.attrs.HABReceiptConflict=true
    local original=function() return 'original' end;e.market.ProcessReceipt=original
    local gems=loadGems(e)
    check(not gems.Init(e.economy) and e.market.ProcessReceipt==original,'conflicting owner retained; shop unavailable')
end
do
    local e=environment();e.settings.GemProducts[1].ProductId=500
    e.info=function() return {Name='Pouch',PriceInRobux=49} end
    local gems=loadGems(e);check(gems.Init(e.economy),'configured receipt owner')
    check(#gems.Offers()==1 and gems.Offers()[1].PriceInRobux==49,'Product metadata may omit IsForSale')
    check(gems.Prompt('pouch')==500,'verified product prompt')
    local receipt={PlayerId=77,ProductId=500,PurchaseId='valid'}
    check(e.run(e.market.ProcessReceipt,receipt)=='defer','profile never ready -> retry')
    e.onWait=function(step) if step==2 then e.player:SetAttribute('HussEconomyReady',true) end end
    e.confirmed=true
    check(e.run(e.market.ProcessReceipt,receipt)=='grant','late profile readiness delivers')
    e.onWait=nil;e.confirmed=false
    check(e.run(e.market.ProcessReceipt,receipt)=='defer','unconfirmed save never acknowledged')
    e.economy.HABProcessGemReceipt=function() error('DataStore timeout') end
    check(e.run(e.market.ProcessReceipt,receipt)=='defer','error defers purchase')
    check(e.run(e.market.ProcessReceipt,{PlayerId=77,ProductId=500,PurchaseId=''})=='defer','empty purchase token rejected')
    check(e.run(e.market.ProcessReceipt,{PlayerId=77,ProductId=501,PurchaseId='a'})=='defer','unknown product rejected')
    e.player.Parent=nil
    check(e.run(e.market.ProcessReceipt,receipt)=='defer','absent player retries')
    e.player.Parent=e.players;e.player:SetAttribute('HussEconomyReady',false)
    e.onWait=function() e.player.Parent=nil end
    check(e.run(e.market.ProcessReceipt,receipt)=='defer','leave during load retries')
    e.info=function() return {IsForSale=false,PriceInRobux=49} end;e.now+=121
    check(gems.Prompt('pouch')==nil,'explicit product off-sale blocks prompts')
    e.settings.GemProducts[1].SalesEnabled=false
    check(gems.Prompt('pouch')==nil and #gems.Offers()==0,'retired pack not advertised')
    e.player.Parent=e.players;e.player:SetAttribute('HussEconomyReady',true)
    e.economy.HABProcessGemReceipt=function() return true end
    check(e.run(e.market.ProcessReceipt,receipt)=='grant','retired product still fulfills paid receipt')
end
do
    local e=environment();e.settings.GemProducts[1].ProductId=500
    local r={ready=true,data={Gems=0,HABGemReceipts={}},revision=0,savedRevision=0}
    e.records[e.player]=r
    local economy=loadReceipt(e)
    local receipt={PlayerId=77,ProductId=500,PurchaseId='purchase-one'}
    check(e.run(economy.HABProcessGemReceipt,receipt),'saved receipt confirms')
    check(r.data.Gems==100 and r.savedRevision==1,'gems and receipt saved together')
    check(e.run(economy.HABProcessGemReceipt,receipt) and r.data.Gems==100,'same-server duplicate no double grant')
    r.gemReceiptRevisions=nil
    check(e.run(economy.HABProcessGemReceipt,receipt) and r.data.Gems==100,'loaded durable ledger no double grant')
    local mismatch={PlayerId=77,ProductId=501,PurchaseId='purchase-one'}
    e.settings.GemProducts[2]={ProductId=501,Gems=750}
    check(not e.run(economy.HABProcessGemReceipt,mismatch),'purchase token bound to original product')
    local pending={PlayerId=77,ProductId=500,PurchaseId='purchase-two'}
    e.saveFails=true
    check(not e.run(economy.HABProcessGemReceipt,pending),'failed save never acknowledged')
    check(r.data.Gems==200,'retryable pending balance credited once')
    check(not e.run(economy.HABProcessGemReceipt,pending) and r.data.Gems==200,'retry during save failure no duplication')
    e.saveFails=false
    check(e.run(economy.HABProcessGemReceipt,pending) and r.data.Gems==200,'recovery confirms same pending receipt')
    r.lost=true
    check(not e.run(economy.HABProcessGemReceipt,{PlayerId=77,ProductId=500,PurchaseId='lost'}),'lost lease prevents grant')
    r.lost=false;r.data.Gems=2147483640
    check(not e.run(economy.HABProcessGemReceipt,{PlayerId=77,ProductId=500,PurchaseId='full'}),'full balance no partial paid grant')
    check(r.data.Gems==2147483640 and not r.data.HABGemReceipts.full,'full balance and ledger unchanged')
    r.data.Gems=0;r.savedRevision=r.revision;e.saveFails=true
    local overlapping={PlayerId=77,ProductId=500,PurchaseId='overlap'}
    local a=coroutine.create(economy.HABProcessGemReceipt)
    check(coroutine.resume(a,overlapping),'first overlapping callback begins')
    local b=coroutine.create(economy.HABProcessGemReceipt)
    check(coroutine.resume(b,overlapping),'second overlapping callback begins')
    check(r.data.Gems==100,'overlapping callbacks only one grant')
    r.savedRevision=r.revision
    local okA,resultA=coroutine.resume(a);local okB,resultB=coroutine.resume(b)
    check(okA and resultA and okB and resultB,'both overlapping callbacks acknowledge same saved receipt')
end
print('MONETIZATION_ASSERTIONS='..assertions)
