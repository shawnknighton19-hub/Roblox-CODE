local results={}
local function check(condition,message)assert(condition,message)end
local b=baselineEnvironment({storeFails=true});local p=b:add(701)
local ok,why=b:boot()
check(not ok and tostring(why):find('publish this place',1,true),'baseline must reproduce primary handle failure: '..tostring(why))
b:step(0)
check(not table.find(b.prints,'[RoundService] INITIALIZED'),'baseline must abort before rounds')
results.baselineFailure=tostring(why)
local ordered=baselineEnvironment({orderedFails=true});ordered:add(701)
local ok2,why2=ordered:boot()
check(not ok2 and tostring(why2):find('OrderedDataStore unavailable',1,true),'baseline ordered handle failure must abort too')
results.baselineOrderedFailure=tostring(why2)
local e=patchedEnvironment({storeFails=true,orderedFails=true});local a=e:add(701)
local good,problem=e:boot();check(good,problem)
e:bootOthers();e:step(30)
check(#e.errors==0,table.concat(e.errors,'\n'))
for _,s in ipairs(e.warnings)do check(not s:find('ROUND ERROR',1,true),s)end
check(table.find(e.prints,'[RoundService] INITIALIZED')~=nil,'patched round init must execute')
check(a:GetAttribute('HussEconomyReady')==false,'unavailable profiles must stay locked')
check(e.updates==0 and next(e.durable)==nil,'no temporary profile writes')
results.scenarios={'primary datastore acquisition failure','ordered datastore acquisition failure','protected bootstrap with persistent data unavailable'}
results.patchedPhases={};for _,v in ipairs(e.events)do if v.remote=='RoundState' or v.remote=='BombTagVoteV6' or v.remote=='BombState'then results.patchedPhases[#results.patchedPhases+1]={remote=v.remote,time=v.time,state=v.args[1]}end end
results.patchedWarnings=e.warnings
results.modules=e.loaded


local function clean(env)
 check(#env.errors==0,table.concat(env.errors,'\n'))
 for _,message in ipairs(env.warnings)do
  check(not message:find('ROUND ERROR',1,true),message)
  check(not message:find('Profile startup failed',1,true),message)
 end
end
local function runUntil(env,predicate,seconds)
 local deadline=env.now+seconds
 repeat env:step(.25);clean(env)until predicate()or env.now>=deadline
 check(predicate(),'Expected state not reached by '..env.now)
end
local function phases(env)
 local out,seen={},{}
 for _,event in ipairs(env.events)do if event.remote=='RoundState'then
  local phase=event.args[1].State;if not seen[phase]then seen[phase]=true;out[#out+1]=phase end
 end end;return out
end
check(e:hasPhase('PRACTICE'),'actual original practice must start despite missing platform stores')
local E=e:module('ServerScriptService/Services/EconomyServiceV9')
check(E.HABCanShop(a)==false,'shop cannot spend unavailable profile')
check(E.HABBuyAbility(a,'Hammer')==false,'ability purchases cannot use unavailable profile')
local settings=e:module('ReplicatedStorage/HABHalloween/Settings')
settings.GemProducts[1].ProductId=91234
check(E.HABProcessGemReceipt({PlayerId=a.UserId,ProductId=91234,PurchaseId='missing-store'})==false,'known receipt must defer unavailable profile')
check(e.updates==0,'unavailable receipt must not write a temporary ledger')

local normal=baselineEnvironment();local n1,n2=normal:add(701),normal:add(702)
local normalOK,normalWhy=normal:boot();check(normalOK,normalWhy);normal:bootOthers()
runUntil(normal,function()return normal:hasPhase('RESULT')end,55)
check(normal:hasPhase('FINAL_DUEL'),'two-player baseline final duel preserved')
check(normal.durable.u701.Coins+normal.durable.u702.Coins==120,'ordinary real-player round settles 100 + 20 coins')
check(normal.durable.u701.Wins+normal.durable.u702.Wins==1,'one true winner settles')
normal:step(7);clean(normal)
check(n1:GetAttribute('InRound')==false and n2:GetAttribute('InRound')==false,'result returns both players to lobby')
results.scenarios[#results.scenarios+1]='unmodified baseline two-player round, results, rewards and lobby return'
results.baselineNormalPhases=phases(normal)

local localFile=patchedEnvironment({unpublished=true,storeFails=true,orderedFails=true})
local f1,f2=localFile:add(701),localFile:add(702)
check(localFile:boot());localFile:bootOthers()
runUntil(localFile,function()return localFile:hasPhase('RESULT')end,55)
check(not f1:GetAttribute('HussEconomyReady') and not f2:GetAttribute('HussEconomyReady'),'unpublished match never fakes loaded profiles')
check(localFile.updates==0 and next(localFile.durable)==nil,'unpublished match cannot write unsaved currency')
check(localFile.storeCalls<=12 and localFile.orderedCalls<=12,'shared acquisition retry remains throttled')
results.scenarios[#results.scenarios+1]='unpublished two-player round continues with no temporary economy'

local rankOnly=patchedEnvironment({orderedFails=true,studio=false});local r1,r2=rankOnly:add(701),rankOnly:add(702)
check(rankOnly:boot());rankOnly:bootOthers()
runUntil(rankOnly,function()return rankOnly:hasPhase('RESULT')end,55)
check(r1:GetAttribute('HussEconomyReady') and r2:GetAttribute('HussEconomyReady'),'ranking outage must not lock healthy player records')
check(rankOnly.storeName=='HussEconomyV9' and rankOnly.orderedName=='HussWinsV9','live store identities unchanged')
local ER=rankOnly:module('ServerScriptService/Services/EconomyServiceV9');ER.GetBoard();rankOnly:step(0)
check(ER.GetBoard().status=='unavailable','ranking failure reported honestly')
check(rankOnly.durable.u701.Coins+rankOnly.durable.u702.Coins==120,'ranking outage leaves saved rewards intact')
results.scenarios[#results.scenarios+1]='ordered-store outage preserves profiles and ordinary rewards'

local recovery=patchedEnvironment({storeFails=true,orderedFails=true});local recovered=recovery:add(701)
check(recovery:boot());recovery:bootOthers();recovery:step(11);clean(recovery)
check(not recovered:GetAttribute('HussEconomyReady') and recovery.updates==0,'profiles locked before handle recovery')
recovery.options.storeFails=false;recovery.options.orderedFails=false
runUntil(recovery,function()return recovered:GetAttribute('HussEconomyReady')end,15)
check(recovery.storeName=='HussEconomyV9_StudioTest' and recovery.orderedName=='HussWinsV9_StudioTest','isolated Studio identities unchanged')
local EE=recovery:module('ServerScriptService/Services/EconomyServiceV9')
EE.Init();EE.Init()
check(#recovery.services.ReplicatedStorage.HussEconomyV9.OnServerEvent.links==1,'repeated Init does not duplicate handlers')
local recoverySettings=recovery:module('ReplicatedStorage/HABHalloween/Settings');local product=recoverySettings.GemProducts[1];product.ProductId=91234
local receiptResult
recovery.task.spawn(function()receiptResult=EE.HABProcessGemReceipt({PlayerId=701,ProductId=91234,PurchaseId='confirmed'})end)
runUntil(recovery,function()return receiptResult~=nil end,24)
check(receiptResult==true and recovery.durable.u701.Gems==product.Gems,'recovered receipt acknowledged only after durable ledger')
local repeatResult=EE.HABProcessGemReceipt({PlayerId=701,ProductId=91234,PurchaseId='confirmed'})
check(repeatResult==true and recovery.durable.u701.Gems==product.Gems,'durable receipt remains idempotent')
results.scenarios[#results.scenarios+1]='store recovery, isolated identities, idempotent Init and durable receipts'

local unavailableWrites=patchedEnvironment({updateFails=true});local locked=unavailableWrites:add(701)
check(unavailableWrites:boot());unavailableWrites:bootOthers();unavailableWrites:step(85);clean(unavailableWrites)
check(locked:GetAttribute('HussSaveStatus')=='UNAVAILABLE' and not locked:GetAttribute('HussEconomyReady'),'failed profile API request reaches explicit unavailable state')
check(next(unavailableWrites.durable)==nil,'UpdateAsync failures never replace existing records with defaults')
check(unavailableWrites:hasPhase('PRACTICE'),'API permission failure does not stop practice')
results.scenarios[#results.scenarios+1]='profile API access failure stays fail closed while practice runs'

local solo=patchedEnvironment();local s1=solo:add(701);check(solo:boot());solo:bootOthers()
runUntil(solo,function()return solo:hasPhase('PRACTICE')end,30)
check(solo.services.Workspace:FindFirstChild('HussPracticeBots')~=nil,'actual practice creates NPC opponents')
solo:step(70);clean(solo)
local sd=solo.durable.u701
check(sd.Coins==0 and sd.Wins==0 and sd.GamesPlayed==0 and sd.Kills==0 and sd.FinalStands==0,'practice never updates coins or player stats')
results.scenarios[#results.scenarios+1]='real solo bot practice leaves coins and competitive stats unchanged'

local afk=patchedEnvironment();local afker=afk:add(701);afker:SetAttribute('BombTagAFK',true)
check(afk:boot());afk:bootOthers();afk:step(35);clean(afk)
check(not afk:hasPhase('STARTING'),'all-AFK lobby never starts a round')
afk.services.ReplicatedStorage.BombTagAFKRequest.OnServerEvent:Fire(afker,false)
runUntil(afk,function()return afk:hasPhase('PRACTICE')end,30)
afk.services.ReplicatedStorage.BombTagAFKRequest.OnServerEvent:Fire(afker,true)
check(afker:GetAttribute('BombTagAFK')==false,'original AFK remote refuses toggling mid-round')
local joined=afk:add(702);afk:step(.25);clean(afk)
check(afk.services.Workspace:FindFirstChild('HussPracticeBots')==nil,'second real player cancels solo practice immediately')
runUntil(afk,function()return afk:hasPhase('FINAL_DUEL')end,30)
results.scenarios[#results.scenarios+1]='AFK pause/resume and second-player transition from practice to real match'
local alternate=patchedEnvironment({storeFails=true,orderedFails=true});local altPlayer=alternate:add(701)
alternate:bootOthers();alternate:step(0);clean(alternate)
check(alternate:boot());runUntil(alternate,function()return alternate:hasPhase('PRACTICE')end,30)
check(not altPlayer:GetAttribute('HussEconomyReady')and alternate.updates==0,'CrateBoot-first order remains fail closed')
check(#alternate.services.ReplicatedStorage.HussEconomyV9.OnServerEvent.links==1,'Alternate bootstrap order cannot duplicate economy connections')
results.scenarios[#results.scenarios+1]='CrateBoot-first startup ordering preserves playable practice and locked profiles'
local shops=patchedEnvironment();local shopper=shops:add(701)
check(shops:boot());shops:bootOthers();shops:step(0);clean(shops)
local shopEconomy=shops:module('ServerScriptService/Services/EconomyServiceV9')
check(shopEconomy.GrantOwner(shopper,'coins',1000)==true,'owner grant provides actual test wallet')
local shop=shops.services.Workspace.Lobby['V11 Bomb Exchange']['Bombs kiosk']['Browse Bombs']
local root=shopper.Character.HumanoidRootPart
root.Position=shop.Position+Vector3.new(40,0,0)
shops.services.ReplicatedStorage.HussEconomyV9.OnServerEvent:Fire(shopper,'Buy','bomb_cherry',71)
check(shopEconomy.HABCrateProfile(shopper).Coins==1000,'distant request cannot buy bomb skin')
root.Position=shop.Position+Vector3.new(0,0,2)
shops.services.ReplicatedStorage.HussEconomyV9.OnServerEvent:Fire(shopper,'Buy','bomb_cherry',72)
check(shopEconomy.HABCrateProfile(shopper).Coins==800 and shopper:GetAttribute('HussBombId')=='bomb_cherry','real moved anchor authorizes purchase and equips actual item')
check(shopEconomy.HABCanShop(shopper)==true,'crate UI remains available for an eligible loaded lobby player')
results.scenarios[#results.scenarios+1]='relocated original tagged kiosk permits nearby purchases and rejects distant requests'
results.patchedNormalPhases=phases(localFile)
results.loadedModuleCount=#e.loaded
results.modules=e.loaded
print('BOOT_REPORT='..json(results))
