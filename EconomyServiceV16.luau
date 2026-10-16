--!nonstrict
-- HussEconomyV9: persisted store identity is permanent.
-- HussEconomyV12: additive collections, proximity purchases and owner-only self grants.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local DS=game:GetService('DataStoreService')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local CollectionService=game:GetService('CollectionService')
local OwnerCommands=require(script.Parent:WaitForChild('OwnerCommandsV12'))
local HABInventoryRules=require(script.Parent:WaitForChild('HABCrateInventoryRules'))
local E={}
local Retirement=require(script.Parent.HABRetirementRules)
local FunConfig=require(RS.HABExpansion.Config)
local HABCrates=require(RS:WaitForChild('HABHalloween'):WaitForChild('Catalog'))
local HABSettings=require(RS:WaitForChild('HABHalloween'):WaitForChild('Settings'))
local crateSync
-- HAB_UNIQUE_SAVE_2: persistent profiles; Studio uses an isolated test store.
local STUDIO=Run:IsStudio()
local ENVIRONMENT=STUDIO and 'STUDIO_TEST' or 'LIVE'
local STORE_NAME=STUDIO and 'HussEconomyV9_StudioTest' or 'HussEconomyV9'
local BOARD_NAME=STUDIO and 'HussWinsV9_StudioTest' or 'HussWinsV9'
local PREVIEW=false -- retained for compatibility with existing shop/board branches
local MAX,LEASE=2000000000,180
local Catalog=require(RS:WaitForChild('HussCatalogV11'))
local catalog,items,defaults=Catalog.Items,Catalog.ById,Catalog.Defaults
local quests={{id='rounds',title='Complete 3 rounds',target=3,reward=100},{id='passes',title='Pass the bomb 10 times',target=10,reward=150},{id='wins',title='Win a round',target=1,reward=200}}
for _,q in ipairs(quests) do
 q.gemReward=HABSettings.QuestGemRewards[q.id] or 0
 assert(type(q.gemReward)=='number' and q.gemReward>=0 and q.gemReward%1==0,'Invalid quest Gem reward')
end
local records,byUser,match={},{},nil
local remote,store,ordered,started,closing
-- V16: unavailable platform stores must not abort the gameplay bootstrap.
-- Missing handles never create temporary profiles or acknowledge purchases.
local storeRetryAt=0
local storeIssue,orderedIssue
local function acquireStores()
 if store and ordered then return true end
 if os.clock()<storeRetryAt then return false end
 storeRetryAt=os.clock()+5
 if not store then
  local ok,value=pcall(DS.GetDataStore,DS,STORE_NAME)
  if ok and value then store=value;storeIssue=nil
  else
   local issue=tostring(value)
   if issue~=storeIssue then warn('[HAB Save] Profile store unavailable; gameplay continues, saving/purchases stay paused: '..issue) end
   storeIssue=issue
  end
 end
 if not ordered then
  local ok,value=pcall(DS.GetOrderedDataStore,DS,BOARD_NAME)
  if ok and value then ordered=value;orderedIssue=nil
  else
   local issue=tostring(value)
   if issue~=orderedIssue then warn('[HAB Save] Rankings store unavailable; gameplay and loaded profiles continue: '..issue) end
   orderedIssue=issue
  end
 end
 return store~=nil and ordered~=nil
end
local board={kind='Board',status=PREVIEW and 'preview' or 'loading',rows={},updatedAt=0}
local boardAt,boardBusy,boardWanted=0,false,false
local names={}
local save
local function integer(n) return type(n)=='number' and n==n and n>=0 and n<=MAX and n%1==0 end
local function copy(t) local out={};for k,v in pairs(t) do out[k]=type(v)=='table' and copy(v) or v end;return out end
local function day() return math.floor(os.time()/86400) end
local function migrate(old)
 local d=copy(old)
 if d.HABExpansion==nil then d.HABExpansion={Version=1,Ability='Speed',Bundles={}} end
 if d.HABCrateInventory==nil then d.HABCrateInventory=HABInventoryRules.Fresh() end
 if d.Gems==nil then d.Gems=0 end
 if d.HABGemReceipts==nil then d.HABGemReceipts={} end
 d.HABHalloween=d.HABHalloween or {Version=1,Owned={},Equipped={},Receipts={}}
 for _,slot in ipairs(HABCrates.Order) do if d.HABHalloween.Equipped[slot]==nil then d.HABHalloween.Equipped[slot]='' end end
 d.Kills=d.Kills or 0;d.FinalStands=d.FinalStands or 0
 d.EquippedByCategory=d.EquippedByCategory or {}
 for category,id in pairs(defaults) do
  d.Owned[id]=true
  if not d.EquippedByCategory[category] then d.EquippedByCategory[category]=category=='Trails' and d.Equipped or id end
 end
 return Retirement.Apply(d,HABCrates,Catalog,FunConfig)
end
local function fresh()
 return migrate({v=1,Coins=0,Wins=0,GamesPlayed=0,Passes=0,Owned={default=true},Equipped='default',Day=day(),Progress={rounds=0,passes=0,wins=0},Claimed={}})
end
local function validCrates(h)
 if h==nil then return true end
 if type(h)~='table' or h.Version~=1 or type(h.Owned)~='table' or type(h.Equipped)~='table' or type(h.Receipts)~='table' then return false end
 for id,owned in pairs(h.Owned) do if type(id)~='string' or #id>64 or type(owned)~='boolean' then return false end end
 for _,slot in ipairs(HABCrates.Order) do
  local id=h.Equipped[slot]
  if id~=nil and id~='' then
   if type(id)~='string' or #id>64 or h.Owned[id]~=true then return false end
   local item=HABCrates.ById[id];if item and item.Category~=slot then return false end
  end
 end
 local n=0
 for token,r in pairs(h.Receipts) do
  n=n+1
  if n>4096 or type(token)~='string' or #token>64 or type(r)~='table' or r.Token~=token or type(r.Item)~='string'
   or #r.Item>64 or type(r.Category)~='string' or not integer(r.Cost) or not integer(r.At) or h.Owned[r.Item]~=true then return false end
 end
 return h.Last==nil or type(h.Last)=='string'
end
local function validGemFields(d)
 if d.Gems~=nil and not integer(d.Gems) then return false end
 if d.HABGemReceipts~=nil then
  if type(d.HABGemReceipts)~='table' then return false end
  local count=0
  for token,r in pairs(d.HABGemReceipts) do
   count=count+1
   if count>20000 or type(token)~='string' or #token<1 or #token>200
    or type(r)~='table' or type(r.ProductId)~='number' or r.ProductId~=r.ProductId
    or r.ProductId<1 or r.ProductId>9007199254740991 or r.ProductId%1~=0
    or not integer(r.Gems) or r.Gems<1 or not integer(r.At) then return false end
  end
 end
 return true
end
local function validExpansion(d) return Retirement.Valid(d) end
local function valid(d)
 if type(d)=='table' and not Retirement.ValidArchive(d.HABRetirement9) then return false end
 if type(d)=='table' and not validExpansion(d.HABExpansion) then return false end
 if type(d)=='table' and not HABInventoryRules.Valid(d.HABCrateInventory) then return false end
 if type(d)=='table' and not validGemFields(d) then return false end
 if type(d)=='table' and not validCrates(d.HABHalloween) then return false end
 if type(d)~='table' or d.v~=1 or not integer(d.Coins) or not integer(d.Wins) or not integer(d.GamesPlayed) or not integer(d.Passes) or not integer(d.Day) then return false end
 if type(d.Owned)~='table' or type(d.Progress)~='table' or type(d.Claimed)~='table' or not items[d.Equipped] or items[d.Equipped].category~='Trails' or d.Owned[d.Equipped]~=true or d.Owned.default~=true then return false end
 -- Optional fields permit old V9 saves. Invalid new fields fail closed instead of being reset.
 if (d.Kills~=nil and not integer(d.Kills)) or (d.FinalStands~=nil and not integer(d.FinalStands)) then return false end
 if d.EquippedByCategory~=nil then
  if type(d.EquippedByCategory)~='table' then return false end
  for _,category in ipairs(Catalog.Categories) do
   local id=d.EquippedByCategory[category]
   if id~=nil and (not items[id] or items[id].category~=category or d.Owned[id]~=true) then return false end
  end
  if d.EquippedByCategory.Trails~=nil and d.EquippedByCategory.Trails~=d.Equipped then return false end
 end
 for id,owned in pairs(d.Owned) do if type(id)~='string' or type(owned)~='boolean' then return false end end
 for _,q in ipairs(quests) do if not integer(d.Progress[q.id]) or (d.Claimed[q.id]~=nil and type(d.Claimed[q.id])~='boolean') then return false end end
 if d.Lease~=nil and (type(d.Lease)~='table' or type(d.Lease.token)~='string' or not integer(d.Lease.expires)) then return false end
 return true
end
local function touch(r) r.revision+=1;r.saveState='PENDING';r.player:SetAttribute('HussSaveStatus','PENDING') end
local function rollover(r)
 if r.data and r.data.Day~=day() then r.data.Day=day();r.data.Progress={rounds=0,passes=0,wins=0};r.data.Claimed={};touch(r) end
end
local function writable(r)
 return r and r.ready and not r.closed and not r.lost and (PREVIEW or os.time()<r.expires-30)
end
local function sync(r,requestId,ok,message)
 if not r.player.Parent then return end
 local ready=writable(r)==true
 if not ready and not message and not r.message then message='Saving or loading is unavailable. Purchases are paused to protect your progress.' end
 if ready then rollover(r) end
 local d=r.data
 local out={kind='Profile',requestId=requestId,ok=ok~=false,ready=ready,mode=ready and 'live' or (r.loading and 'loading' or 'unavailable'),saveState=r.saveState or 'LOADING',saveEnvironment=ENVIRONMENT,lastSavedAt=r.lastSavedAt or 0,message=message or r.message,Catalog={},Quests={},Owned={},Gems=d and d.Gems or 0,Coins=d and d.Coins or 0,Wins=d and d.Wins or 0,GamesPlayed=d and d.GamesPlayed or 0,Passes=d and d.Passes or 0,Equipped=d and d.Equipped or 'default',EquippedByCategory=d and copy(d.EquippedByCategory) or copy(defaults),Kills=d and d.Kills or 0,FinalStands=d and d.FinalStands or 0,resetsAt=(day()+1)*86400}
 for _,item in ipairs(catalog) do
  if not item.bundleOnly or (d and d.Owned[item.id]) then out.Catalog[#out.Catalog+1]=item end
 end
 for _,q in ipairs(quests) do local row=copy(q);row.progress=d and math.min(d.Progress[q.id],q.target) or 0;row.claimed=d and d.Claimed[q.id]==true or false;table.insert(out.Quests,row) end
 for _,item in ipairs(catalog) do if d and d.Owned[item.id] then table.insert(out.Owned,item.id) end end
 r.player:SetAttribute('HussEconomyReady',ready)
 r.player:SetAttribute('HussSaveStatus',r.saveState or 'LOADING')
 r.player:SetAttribute('HussLastSavedAt',r.lastSavedAt or 0)
 r.player:SetAttribute('HussDataEnvironment',ENVIRONMENT)
 if crateSync then crateSync(r) end
 if d then
  r.player:SetAttribute('HABAbility',d.HABExpansion and d.HABExpansion.Ability or 'Speed')
  r.gems.Value=d.Gems;r.player:SetAttribute('Gems',d.Gems)
  r.coins.Value=d.Coins;r.wins.Value=d.Wins;r.kills.Value=d.Kills;r.finalStands.Value=d.FinalStands
  r.player:SetAttribute('GamesPlayed',d.GamesPlayed);r.player:SetAttribute('Passes',d.Passes)
  r.player:SetAttribute('HussBombId',d.EquippedByCategory.Bombs)
  r.player:SetAttribute('HussTitleId',d.EquippedByCategory.Titles)
  r.player:SetAttribute('HussEmoteId','')
  r.player:SetAttribute('HussEmotePlaying',nil)
  local item=items[d.Equipped];r.player:SetAttribute('HussTrailId',item.id)
  r.player:SetAttribute('HussTrailColor',item.id~='default' and Color3.fromRGB(table.unpack(item.color)) or nil)
 end
 remote:FireClient(r.player,out)
end
local function retire(r)
 r.done=true
 if records[r.player]==r then records[r.player]=nil end
 if byUser[r.player.UserId]==r then byUser[r.player.UserId]=nil end
end
local function retry(fn)
 for attempt=1,3 do
  local ok,value=pcall(fn)
  if ok then return true,value end
  if attempt<3 then task.wait(attempt) end
 end
 return false,nil
end
local function boardWrite(r)
 if PREVIEW or r.boardBusy or not ordered or not r.savedWins or r.savedWins<1 or r.savedWins<=(r.boardWins or 0) then return end
 r.boardBusy=true
 local value=r.savedWins
 task.spawn(function()
  local ok=pcall(function()
   if DS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementSortedAsync)<1 then error('Budget') end
   ordered:UpdateAsync(tostring(r.player.UserId),function(old) return math.max(type(old)=='number' and old or 0,value) end)
  end)
  if ok then r.boardWins=math.max(r.boardWins or 0,value) end
  r.boardBusy=false
 end)
end
-- Saving is authoritative, serialized per player and idempotent across retries.
-- Live store/key identities remain HussEconomyV9 / u<UserId>.
local function persisted(value,info,player)
 -- Keep existing key metadata and privacy/user associations on every update.
 local ids=info and info:GetUserIds() or (player.UserId>0 and {player.UserId} or {})
 local metadata=info and info:GetMetadata() or {}
 return value,ids,metadata
end
local function saveStatus(r, state, message)
 r.saveState=state
 if message~=nil then r.message=message end
 if r.player.Parent==Players then
  r.player:SetAttribute('HussSaveStatus',state)
  r.player:SetAttribute('HussLastSavedAt',r.lastSavedAt or 0)
  r.player:SetAttribute('HussDataEnvironment',ENVIRONMENT)
 end
end
local function lostSession(r, message)
 r.lost=true;r.ready=false
 saveStatus(r,'LOCKED',message)
 warn('[HAB Save] '..r.player.UserId..': '..message)
 sync(r,nil,false,message)
end
save=function(r, release)
 if release then
  r.release=true
  r.releaseDeadline=r.releaseDeadline or (os.clock()+24)
 end
 if r.saving or r.loading or r.done then return end
 if not r.data or r.lost then if r.release then retire(r) end;return end
 r.saving=true
 task.spawn(function()
  local okWorker,workerError=xpcall(function()
   while not r.done do
    while not r.release and os.clock()<(r.nextSaveAt or 0) do task.wait(.15) end
    if r.lost then if r.release then retire(r) end;break end
    if os.time()>=r.expires then
     lostSession(r,'The profile lease expired. Rejoin to reload safely; this server will not overwrite it.')
     if r.release then retire(r) end
     break
    end
    local final=r.release==true
    local snapshot,revision=copy(r.data),r.revision
    local operation=Http:GenerateGUID(false)
    snapshot.HABLastWrite=operation
    saveStatus(r,'SAVING')
    local confirmed=false
    for attempt=1,5 do
     if r.releaseDeadline and os.clock()>=r.releaseDeadline then break end
     local expiry=os.time()+LEASE
     local rejected
     local ok,result=pcall(function()
      return store:UpdateAsync('u'..r.player.UserId,function(old,keyInfo)
       rejected=nil
       if not valid(old) then rejected='INVALID';return nil end
       -- A write can succeed even when its response is lost. Recognize it.
       if old.HABLastWrite==operation then return persisted(old,keyInfo,r.player) end
       if not old.Lease or old.Lease.token~=r.token or old.Lease.expires<=os.time() then
        rejected='LEASE';return nil
       end
       local value=copy(snapshot)
       if final then value.Lease=nil else value.Lease={token=r.token,expires=expiry} end
       return persisted(value,keyInfo,r.player)
      end)
     end)
     if ok and result and result.HABLastWrite==operation then
      confirmed=true;r.savedRevision=revision;r.savedWins=snapshot.Wins
      r.data.HABLastWrite=operation;r.lastSavedAt=os.time();r.message=nil
      r.nextSaveAt=os.clock()+5;r.nextRenewAt=os.clock()+40+math.random()*12
      if result.Lease and result.Lease.token==r.token then r.expires=result.Lease.expires end
      saveStatus(r,r.revision==revision and 'SAVED' or 'PENDING')
      boardWrite(r)
      if final then retire(r) else sync(r) end
      break
     elseif ok and rejected then
      lostSession(r,rejected=='INVALID'
       and 'Stored data changed unexpectedly. Saving is paused instead of resetting your inventory.'
       or 'Another session owns this profile. Rejoin to reload it safely.')
      if r.release then retire(r) end
      break
     else
      saveStatus(r,'RETRYING','Saving is delayed. Do not assume recent changes are saved yet.')
      r.lastSaveError=tostring(result)
      if not r.closed then sync(r,nil,false,r.message) end
      if attempt<5 then
       local delay=math.min(4,.65*2^(attempt-1))+.15*math.random()
       if r.releaseDeadline then delay=math.max(0,math.min(delay,r.releaseDeadline-os.clock())) end
       if delay>0 then task.wait(delay) end
      end
     end
    end
    if r.done or r.lost then break end
    if not confirmed then
     r.nextSaveAt=os.clock()+4
     if r.release then
      if os.clock()>=(r.releaseDeadline or 0) then
       warn('[HAB Save] Final write not confirmed for '..r.player.UserId..': '..tostring(r.lastSaveError))
       retire(r);break
      end
      task.wait(.4)
     else
      warn('[HAB Save] Retrying unconfirmed changes for '..r.player.UserId)
      break -- maintenance loop retries without discarding dirty data
     end
    elseif not r.release and r.revision==revision then
     break
    end
    -- Changes made while UpdateAsync yielded are saved in the next snapshot.
   end
  end,debug.traceback)
  r.saving=false
  if not okWorker then
   r.nextSaveAt=os.clock()+4
   saveStatus(r,'RETRYING','A save error occurred. Recent changes are not yet confirmed saved.')
   warn('[HAB Save] Worker error: '..tostring(workerError))
   if r.release and os.clock()>=(r.releaseDeadline or 0) then retire(r) end
  end
 end)
end
local function load(r,previous)
 local deadline=os.clock()+80
 if previous and not previous.done then
  while not previous.done and not r.closed and os.clock()<deadline do task.wait(.2) end
 end
 if r.closed then r.loading=false;retire(r);return end
 if previous and not previous.done then
  r.loading=false;saveStatus(r,'UNAVAILABLE','Your previous session is still saving. Rejoin in a moment.');sync(r,nil,false,r.message);return
 end
 byUser[r.player.UserId]=r
 saveStatus(r,'LOADING','Loading saved coins and cosmetics...')
 local delay=1
 while not r.closed and os.clock()<deadline do
  local reason
  local ok,result=pcall(function()
   return store:UpdateAsync('u'..r.player.UserId,function(old,keyInfo)
    reason=nil
    if old~=nil and not valid(old) then reason='INVALID';return nil end
    local data=old or fresh() -- default data only when the store confirms no record
    if data.Lease and data.Lease.token~=r.token and data.Lease.expires>os.time() then
     reason='BUSY';return nil
    end
    local value=migrate(data)
    value.Lease={token=r.token,expires=os.time()+LEASE}
    return persisted(value,keyInfo,r.player)
   end)
  end)
  if ok and result and valid(result) and result.Lease and result.Lease.token==r.token then
   r.data=copy(result);r.data.Lease=nil;r.expires=result.Lease.expires
   r.savedWins=result.Wins;r.lastSavedAt=os.time()
   r.nextRenewAt=os.clock()+35+math.random()*15;r.message=nil
   r.loading=false;r.ready=not r.closed
   saveStatus(r,'SAVED')
   if r.closed then save(r,true) else sync(r) end
   return
  end
  if ok and reason=='INVALID' then
   r.message='Your saved profile needs review. Nothing was reset; purchases and rewards are paused.'
   break
  end
  r.message=reason=='BUSY' and 'Your previous server is still saving. Waiting for your profile...'
   or 'Could not reach saved data. Retrying; no temporary balance will overwrite your progress.'
  saveStatus(r,'LOADING',r.message);sync(r,nil,false,r.message)
  r.lastLoadError=ok and tostring(reason) or tostring(result)
  task.wait(math.min(delay,math.max(.05,deadline-os.clock())))
  delay=math.min(5,delay*1.5)
 end
 r.loading=false;r.ready=false
 if r.closed then retire(r);return end
 saveStatus(r,'UNAVAILABLE',r.message or 'Saved data could not be loaded. Rejoin to try again.')
 warn('[HAB Save] Load unavailable for '..r.player.UserId..' in '..ENVIRONMENT..': '..tostring(r.lastLoadError))
 sync(r,nil,false,r.message)
end

local function setup(p)
 if records[p] then return end
 local stats=p:FindFirstChild('leaderstats')
 if not stats then stats=Instance.new('Folder');stats.Name='leaderstats';stats.Parent=p end
 assert(stats:IsA('Folder'),'leaderstats must be a Folder')
 local function stat(name)
  local n=stats:FindFirstChild(name)
  if not n then n=Instance.new('IntValue');n.Name=name;n.Parent=stats end
  assert(n:IsA('IntValue'),name..' must be an IntValue');return n
 end
 local previous=byUser[p.UserId]
 local r={player=p,gems=stat('Gems'),coins=stat('Coins'),wins=stat('Wins'),kills=stat('Kills'),finalStands=stat('FinalStands'),token=ENVIRONMENT..':'..game.JobId..':'..Http:GenerateGUID(false),loading=true,revision=0,savedRevision=0,tokens=8,rateAt=os.clock()}
 local primary=r.wins:FindFirstChild('IsPrimary')
 if not primary then primary=Instance.new('BoolValue');primary.Name='IsPrimary';primary.Parent=r.wins end
 if primary:IsA('BoolValue') then primary.Value=true end
 records[p]=r;p:SetAttribute('HussEconomyReady',false)
 task.spawn(load,r,previous)
end
local function refreshBoard()
 if PREVIEW or boardBusy or os.clock()<boardAt then return end
 boardBusy=true;boardAt=os.clock()+120
 task.spawn(function()
  local ok,rows=pcall(function()
   if DS:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.GetSortedAsync)<1 then error('Budget') end
   local page=ordered:GetSortedAsync(false,20):GetCurrentPage();local result={}
   for _,row in ipairs(page) do
    local id=tonumber(row.key)
    if id and id>0 and id%1==0 and integer(row.value) and row.value>0 then
     local name=names[id]
     if not name then local found,value=pcall(Players.GetNameFromUserIdAsync,Players,id);name=found and value or ('Player '..id);names[id]=name end
     table.insert(result,{userId=id,name=name,wins=row.value})
    end
   end
   return result
  end)
  if ok then board.rows=rows;board.updatedAt=os.time();board.status='ready';board.message=nil
  else board.status='unavailable';board.message='Global rankings are temporarily unavailable.' end
  boardBusy=false;remote:FireAllClients(board)
 end)
end
function E.GetBoard()
 boardWanted=true;refreshBoard();return copy(board)
end
local function nearShop(p,category)
 if p.Parent~=Players or p:GetAttribute('InRound')==true or p:GetAttribute('HussPracticeActive')==true then return false end
 local character=p.Character
 local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 local root=character and character:FindFirstChild('HumanoidRootPart')
 local lobby=workspace:FindFirstChild('Lobby')
 local exchange=lobby and lobby:FindFirstChild('V11 Bomb Exchange')
 local station=exchange and exchange:FindFirstChild(category..' kiosk')
 if not humanoid or not (humanoid.Health>0) or not root or not root:IsA('BasePart') or not station then return false end
 for _,anchor in ipairs(CollectionService:GetTagged('HussShopStandV12')) do
  if anchor:IsA('BasePart') and anchor.Parent==station and anchor.Name=='Browse '..category and anchor:GetAttribute('HussShopCategory')==category and anchor:GetAttribute('HussShopStandEnabled')==true and (root.Position-anchor.Position).Magnitude<=16 then return true end
 end
 return false
end
function E.GrantOwner(p,kind,value)
 if kind=='gems' then return E.HABGrantOwnerGems(p,value) end
 if kind=='emote' or kind=='emotes' then return false,'Emotes have been retired; ownership is archived.' end
 -- This API is never dispatched from OnServerEvent; repeat the authoritative check
 -- even when a caller has already checked a TextChatCommand's sender.
 if not OwnerCommands.IsOwner(p) then return false,'This command is only available to the game owner.' end
 local r=records[p]
 if not writable(r) then return false,'Progress is unavailable. Wait for your profile to load or rejoin safely.' end
 local now=os.clock()
 if now<(r.ownerGrantAt or -math.huge) then return false,'Please wait a moment before another grant.' end
 r.ownerGrantAt=now+.5
 if type(kind)~='string' or #kind>12 then return false,'Use /grant help for the owner commands.' end
 kind=kind:lower()
 local d=r.data;local message
 if kind=='coins' then
  if type(value)=='string' then
   if #value>10 or not value:match('^%d+$') then return false,'Enter a whole Coin amount from 1 to 2000000000.' end
   value=tonumber(value)
  end
  if not integer(value) or value<1 then return false,'Enter a whole Coin amount from 1 to 2000000000.' end
  local added=math.min(value,MAX-d.Coins)
  if added==0 then return false,'Your balance has reached the 2000000000 Coin limit.' end
  d.Coins+=added;message='Granted '..tostring(added)..' Coins. Balance: '..tostring(d.Coins)..'.'
 elseif kind=='all' then
  if value~=nil then return false,'Use /grant all without extra arguments.' end
  local count=0
  for _,item in ipairs(catalog) do if not d.Owned[item.id] then d.Owned[item.id]=true;count+=1 end end
  if count==0 then return true,'You already own every cosmetic. Coins are granted separately with /grant coins <amount>.' end
  message='Unlocked '..count..' cosmetics. Your current equipment is unchanged.'
 else
  local categories={bomb='Bombs',bombs='Bombs',trail='Trails',trails='Trails',title='Titles',titles='Titles',emote='Emotes',emotes='Emotes'}
  local category=categories[kind]
  if not category or type(value)~='string' or #value>64 then return false,'Use /grant help for the owner commands.' end
  local wanted=value:lower();local item=items[wanted]
  if not item then for _,entry in ipairs(catalog) do if entry.category==category and entry.name:lower()==wanted then item=entry;break end end end
  if not item or item.category~=category then return false,'Unknown '..category..' item. Use /grant list '..category:lower()..' for the exact names and IDs.' end
  if d.Owned[item.id] and d.EquippedByCategory[category]==item.id then return true,item.name..' is already owned and equipped.' end
  d.Owned[item.id]=true;d.EquippedByCategory[category]=item.id
  if category=='Trails' then d.Equipped=item.id;d.HABHalloween.Equipped.Trail='' end
  message=item.name..' unlocked and equipped.'
 end
 touch(r);sync(r);save(r)
 return true,message..(PREVIEW and ' Studio preview: not saved.' or (STUDIO and ' Studio test profile save requested; check HussSaveStatus for confirmation.' or ' Save requested; check HussSaveStatus for confirmation.'))
end
local function request(p,action,id,requestId)
 local r=records[p]
 if not r or r.closed or type(action)~='string' or #action>12 then return end
 if requestId~=nil and not integer(requestId) then return end
 local now=os.clock();r.tokens=math.min(8,r.tokens+(now-r.rateAt)*3);r.rateAt=now
 if r.tokens<1 then return end;r.tokens-=1
 if action=='Board' then
  boardWanted=true;refreshBoard();local response=copy(board);response.requestId=requestId;response.ok=board.status=='ready' or board.status=='preview';remote:FireClient(p,response);return
 end
 if action=='Sync' then sync(r,requestId);return end
 if action~='Buy' and action~='Equip' and action~='Claim' then return end
 if type(id)~='string' or #id>20 then sync(r,requestId,false,'Unknown item.');return end
 if not writable(r) then sync(r,requestId,false,'Progress is unavailable. Try rejoining shortly.');return end
 rollover(r)
 local d=r.data
 if action=='Claim' then
  local ok,message=E.HABClaimQuest(p,id)
  sync(r,requestId,ok,message)
  return
 end
 local item=items[id]
 if item and item.category=='Emotes' then sync(r,requestId,false,'Emotes have been retired.');return end
 if not item then sync(r,requestId,false,'Unknown item.');return end
 if item.bundleOnly and d.Owned[id]~=true then sync(r,requestId,false,'This is a guaranteed Robux bundle/pass cosmetic.');return end
 if action=='Buy' and not nearShop(p,item.category) then sync(r,requestId,false,'Walk up to the '..item.category..' stand in the lobby to shop.');return end
 if d.Owned[id] and d.EquippedByCategory[item.category]==id then
  if item.category=='Trails' and d.HABHalloween.Equipped.Trail~='' then d.HABHalloween.Equipped.Trail='';touch(r);sync(r);save(r) end
  sync(r,requestId,true,'Already equipped.');return
 end
 if action=='Buy' and not d.Owned[id] then
  if d.Coins<item.price then sync(r,requestId,false,'You need more Coins.');return end
  d.Coins-=item.price;d.Owned[id]=true
 elseif not d.Owned[id] then sync(r,requestId,false,'Unlock this item first.');return end
 d.EquippedByCategory[item.category]=id
 if item.category=='Trails' then d.Equipped=id;d.HABHalloween.Equipped.Trail='' end
 touch(r);sync(r,requestId,true,item.name..' equipped!');save(r)
end
local function eligible(p)
 if typeof(p)~='Instance' or not p:IsA('Player') or p.Parent~=Players or p:GetAttribute('BombTagAFK')==true or p:GetAttribute('InRound')~=true then return false end
 local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid')
 return h~=nil and h.Health>0
end
function E.BeginRound(players)
 match=nil
 local members,count={},0
 for _,p in ipairs(players) do if not members[p] and eligible(p) then members[p]={record=writable(records[p]) and records[p] or nil,passes=0,kills=0,finalStands=0,lastPass=-math.huge};count+=1 end end
 if count>=2 then match={members=members,lastPasser={},started=os.clock()} end
end
function E.Pass(from,to)
 local current=match
 if not current or from==to or not current.members[from] or not current.members[to] or current.members[from].eliminated or current.members[to].eliminated or not eligible(from) or not eligible(to) then return end
 current.lastPasser[to]=from
 local member=current.members[from];local now=os.clock()
 if now-member.lastPass<.25 then return end
 member.lastPass=now;member.passes=math.min(MAX,member.passes+1)
end
function E.FinalStand(players)
 local current=match
 if not current or current.finalStand or type(players)~='table' or #players~=2 or players[1]==players[2] then return end
 for _,p in ipairs(players) do if not current.members[p] or current.members[p].eliminated or not eligible(p) then return end end
 local living=0;for p,member in pairs(current.members) do if not member.eliminated and eligible(p) then living+=1 end end
 if living~=2 then return end
 current.finalStand=true
 for _,p in ipairs(players) do current.members[p].finalStands=1 end
end
function E.Elimination(killer,victim)
 local current=match;local member=current and current.members[victim]
 if not member or member.eliminated or not eligible(victim) then return end
 member.eliminated=true
 local attacker=current.members[killer]
 if killer~=victim and attacker and current.lastPasser[victim]==killer and typeof(killer)=='Instance' and killer.Parent==Players then
  attacker.kills=math.min(MAX,attacker.kills+1)
 end
 current.lastPasser[victim]=nil
end
function E.AbortRound() match=nil end
function E.EndRound(winner)
 local current=match;match=nil
 if not current then return end
 if winner and (not current.members[winner] or current.members[winner].eliminated or not eligible(winner)) then winner=nil end
 for p,member in pairs(current.members) do
  local r=member.record
  if r and records[p]==r and p.Parent==Players and writable(r) then
   rollover(r);local d=r.data;local won=p==winner
   d.GamesPlayed=math.min(MAX,d.GamesPlayed+1);d.Passes=math.min(MAX,d.Passes+member.passes)
   d.Kills=math.min(MAX,d.Kills+member.kills);d.FinalStands=math.min(MAX,d.FinalStands+member.finalStands)
   d.Coins=math.min(MAX,d.Coins+20+(won and 80 or 0));d.Wins=math.min(MAX,d.Wins+(won and 1 or 0))
   d.Progress.rounds=math.min(3,d.Progress.rounds+1);d.Progress.passes=math.min(10,d.Progress.passes+member.passes);d.Progress.wins=math.min(1,d.Progress.wins+(won and 1 or 0))
   touch(r);sync(r,nil,true,won and '+100 Coins • Victory!' or '+20 Coins • Round complete');save(r)
  end
 end
end
function E.Init()
 if started then return end;started=true
 acquireStores()
 print('[HAB Save] Persistent '..ENVIRONMENT..' profiles: '..STORE_NAME)
 remote=RS:FindFirstChild('HussEconomyV9')
 if not remote then remote=Instance.new('RemoteEvent');remote.Name='HussEconomyV9';remote.Parent=RS end
 assert(remote:IsA('RemoteEvent'),'HussEconomyV9 must be a RemoteEvent')
 remote.OnServerEvent:Connect(request)
 Players.PlayerAdded:Connect(setup)
 Players.PlayerRemoving:Connect(function(p) local r=records[p];if r then r.closed=true;r.ready=false;save(r,true) end end)
 for _,p in ipairs(Players:GetPlayers()) do setup(p) end
 OwnerCommands.Init(E)
 task.spawn(function()
  while not closing do
   task.wait(1)
   if not store or not ordered then acquireStores() end
   for _,r in pairs(records) do
    if r.data and not r.done and not r.loading then
     if r.release then save(r,true)
     elseif not r.lost then
      if os.time()>=r.expires then lostSession(r,'Profile lease expired; rejoin to reload saved progress.')
      elseif (r.revision>r.savedRevision and os.clock()>=(r.nextSaveAt or 0)) or os.clock()>=(r.nextRenewAt or 0) then save(r) end
     end
    end
   end
   if boardWanted then refreshBoard() end
  end
 end)
 game:BindToClose(function()
  closing=true;local deadline=os.clock()+25
  for _,r in pairs(records) do r.closed=true;r.ready=false;save(r,true) end
  repeat
   local pending=false;for _,r in pairs(records) do if not r.done then pending=true;break end end
   if not pending then break end;task.wait(.1)
  until os.clock()>=deadline
 end)
end
------------------------------------------------------------
-- HAB_HALLOWEEN_CRATES_1: one profile; coins + ownership together.
-- No second data store, leaderstats writes or client-supplied rewards.
------------------------------------------------------------
------------------------------------------------------------
-- HAB_CRATE_UPGRADE_2: gems, crates and receipts share the existing profile.
-- Gems are awarded ONLY by claimed quests or validated Developer Product receipts.
------------------------------------------------------------
crateSync=function(r)
    local d=r.data
    local h=d and d.HABHalloween
    for _,category in ipairs(HABCrates.Order) do
        local id=h and h.Equipped[category] or ''
        local item=HABCrates.ById[id]
        local allowed=writable(r) and item and item.Category==category and h.Owned[id]==true
        r.player:SetAttribute('HABPack'..category,allowed and id or '')
    end
end
local function crateProfile(r)
    if writable(r) then rollover(r) end
    local d=r.data
    local h=d and d.HABHalloween
    local qs={}
    for _,q in ipairs(quests) do
        qs[#qs+1]={Id=q.id,Title=q.title,Target=q.target,Progress=d and math.min(d.Progress[q.id],q.target) or 0,
            Claimed=d and d.Claimed[q.id]==true or false,Coins=q.reward,Gems=q.gemReward or 0}
    end
    return {Ready=writable(r)==true,Coins=d and d.Coins or 0,Gems=d and d.Gems or 0,
        Owned=h and copy(h.Owned) or {},Equipped=h and copy(h.Equipped) or {},
        Revision=r.revision or 0,SaveStatus=r.saveState or 'LOADING',Last=h and h.Last or nil,
        Quests=qs,ResetsAt=(day()+1)*86400}
end
function E.HABCrateProfile(player)
    local r=records[player]
    if not r then return {Ready=false,Coins=0,Gems=0,Owned={},Equipped={},Revision=0,SaveStatus='LOADING',Quests={}} end
    return crateProfile(r)
end
local function crateLobby(player)
    if typeof(player)~='Instance' or not player:IsA('Player') or player.Parent~=Players then return false end
    if player:GetAttribute('InRound')==true or player:GetAttribute('HussPracticeActive')==true then return false end
    local c=player.Character
    local h=c and c:FindFirstChildOfClass('Humanoid')
    local root=c and c:FindFirstChild('HumanoidRootPart')
    return h and h.Health>0 and root and root:IsA('BasePart') and not root.Anchored
end
-- The GUI is the shop: no physical stand/distance dependency.
local function nearCrate(player)
    return crateLobby(player)==true
end
function E.HABCanShop(player) return writable(records[player])==true and nearCrate(player)==true end
function E.HABCrateSelection(actor,category)
    if typeof(actor)~='Instance' or not actor:IsA('Player') then return nil end
    local r=records[actor]
    local h=r and writable(r) and r.data.HABHalloween
    local id=h and h.Equipped[category]
    local item=id and HABCrates.ById[id]
    return item and item.Category==category and h.Owned[id]==true and id or nil
end
function E.HABEquipCrate(player,category,id)
    local r=records[player]
    if not writable(r) or not crateLobby(player) then return false,'Load your profile and return to the lobby.' end
    if not HABCrates.Crates[category] or type(id)~='string' or #id>64 then return false,'Unknown equipment.' end
    local h=r.data.HABHalloween
    local item=HABCrates.ById[id]
    if item and item.RetiredFinisher then return false,'Finishers were replaced with kill sounds. Check your inventory.' end
    if id~='' and (not item or item.Category~=category or h.Owned[id]~=true) then return false,'You do not own this effect.' end
    if h.Equipped[category]==id then return true,'Already equipped.' end
    h.Equipped[category]=id
    touch(r);crateSync(r);sync(r);save(r)
    return true,id=='' and 'Effect removed; ownership retained.' or 'Effect equipped.'
end
function E.HABClaimQuest(player,id)
    local r=records[player]
    if not writable(r) then return false,'Saved progress is not ready.' end
    if type(id)~='string' or #id>20 then return false,'Unknown quest.' end
    rollover(r)
    local q
    for _,entry in ipairs(quests) do if entry.id==id then q=entry;break end end
    local d=r.data
    if not q or d.Claimed[id] or d.Progress[id]<q.target then return false,'This quest is not ready to claim.' end
    local gems=q.gemReward or 0
    if d.Gems>MAX-gems then return false,'Spend some Gems before claiming this reward.' end
    -- No yield between the claim flag and both currency awards.
    d.Claimed[id]=true
    d.Coins=math.min(MAX,d.Coins+q.reward)
    d.Gems=d.Gems+gems
    touch(r);sync(r);save(r)
    return true,'Quest claimed: +'..q.reward..' Coins and +'..gems..' Gems. Saving.'
end
function E.HABOpenCrate(player,category,requestId,revision,choice,allowRandom)
    local r=records[player]
    if not writable(r) then return false,'Your saved profile is not ready.' end
    if type(requestId)~='string' or #requestId<12 or #requestId>64 or not requestId:match('^[%w%-]+$') then return false,'Invalid request.' end
    local crate=HABCrates.Crates[category]
    if not crate then return false,'Unknown crate.' end
    local h=r.data.HABHalloween
    local receipt=h.Receipts[requestId]
    if receipt then
        if receipt.Category~=category then return false,'That request ID belongs to a different crate.' end
        return true,'Recovered the same opening; no second charge.',copy(receipt)
    end
    if not nearCrate(player) then return false,'Return to the lobby before opening a crate.' end
    if r.crateSaveRevision and (r.savedRevision or -1)<r.crateSaveRevision then return false,'Your previous crate is still saving.' end
    if os.clock()<(r.crateAt or 0) then return false,'Please wait before opening another crate.' end
    if type(revision)~='number' or revision~=r.revision then return false,'Inventory changed. Review the updated odds and confirm again.' end
    local remaining={}
    for _,id in ipairs(crate.Items) do if h.Owned[id]~=true then remaining[#remaining+1]=id end end
    local count=#remaining
    if count==0 then return false,'Collection complete. No Gems charged.' end
    -- Direct choice is offered to everyone; restricted accounts cannot roll.
    local direct=choice~=nil or allowRandom~=true
    local price=direct and math.ceil(crate.Price*(count+1)/2) or crate.Price
    local id
    if direct then
        if type(choice)~='string' or not table.find(remaining,choice) then return false,'Select an unowned effect for a guaranteed purchase.' end
        id=choice
    else
        id=remaining[math.random(1,count)]
    end
    if r.data.Gems<price then return false,'Not enough Gems. Complete quests or buy a Gem pack.' end
    local receiptCount=0
    for _ in pairs(h.Receipts) do receiptCount=receiptCount+1 end
    if receiptCount>=4096 then return false,'Crate receipt limit reached. No Gems charged.' end
    -- One atomic in-memory update. The existing save worker persists all fields together.
    r.data.Gems=r.data.Gems-price
    h.Owned[id]=true
    receipt={Token=requestId,Category=category,Item=id,Cost=price,Currency='Gems',At=os.time(),Pool=count,Random=not direct}
    h.Receipts[requestId]=receipt;h.Last=id
    r.crateAt=os.clock()+1.5
    touch(r);r.crateSaveRevision=r.revision
    r.crateTokenRevisions=r.crateTokenRevisions or {}
    r.crateTokenRevisions[requestId]=r.revision
    crateSync(r);sync(r);save(r)
    return true,'Reward selected. Confirming your save...',copy(receipt)
end
function E.HABConfirmCrate(player,token,seconds)
    local r=records[player]
    local receipt=r and r.data and r.data.HABHalloween.Receipts[token]
    if not receipt then return false end
    local revision=r.crateTokenRevisions and r.crateTokenRevisions[token]
    if not revision then return true end -- This receipt was loaded from a confirmed record.
    save(r)
    local deadline=os.clock()+math.clamp(seconds or 12,0,18)
    while (r.savedRevision or -1)<revision and not r.done and not r.lost and os.clock()<deadline do task.wait(.1) end
    return (r.savedRevision or -1)>=revision
end
local function positiveId(n)
    return type(n)=='number' and n==n and n>0 and n<=9007199254740991 and n%1==0
end
function E.HABProcessGemReceipt(info)
    -- Called only by MarketplaceService.ProcessReceipt in HABGemPurchases.
    if type(info)~='table' or type(info.PurchaseId)~='string' or #info.PurchaseId<1 or #info.PurchaseId>200
        or not positiveId(info.PlayerId) or not positiveId(info.ProductId) then return false end
    local product
    for _,entry in ipairs(HABSettings.GemProducts) do
        if entry.ProductId>0 and entry.ProductId==info.ProductId then product=entry;break end
    end
    if not product or not integer(product.Gems) or product.Gems<1 then return false end
    local player=Players:GetPlayerByUserId(info.PlayerId)
    local r=player and records[player]
    if not r or not writable(r) then return false end
    local ledger=r.data.HABGemReceipts
    local record=ledger[info.PurchaseId]
    if record and record.ProductId~=info.ProductId then return false end
    r.gemReceiptRevisions=r.gemReceiptRevisions or {}
    local needed=r.gemReceiptRevisions[info.PurchaseId]
    if record and not needed then return true end -- Already in the persisted profile when loaded.
    if not record then
        local count=0;for _ in pairs(ledger) do count=count+1 end
        if count>=20000 or r.data.Gems>MAX-product.Gems then
            warn('[HAB Gems] Receipt deferred: profile balance/receipt capacity. No partial grant: '..info.PurchaseId)
            return false
        end
        -- No yields: even overlapping receipt callbacks can add this receipt only once.
        r.data.Gems=r.data.Gems+product.Gems
        ledger[info.PurchaseId]={ProductId=info.ProductId,Gems=product.Gems,At=os.time()}
        touch(r);needed=r.revision;r.gemReceiptRevisions[info.PurchaseId]=needed
        sync(r,nil,true,'Gems delivered; confirming cloud save.')
    end
    save(r)
    local deadline=os.clock()+22
    while (r.savedRevision or -1)<needed and not r.done and not r.lost and os.clock()<deadline do task.wait(.1) end
    -- Never acknowledge a Robux receipt until the profile save containing its ledger entry is confirmed.
    return (r.savedRevision or -1)>=needed
end



------------------------------------------------------------
-- HAB_COLLECTIONS_5 | Currency and stored crates share this existing profile.
------------------------------------------------------------
local previousCrateProfile=E.HABCrateProfile
function E.HABCrateProfile(player)
 local out=previousCrateProfile(player)
 local r=records[player]
 out.InventoryVersion=5
 out.StoredCrates={};out.StoredCounts={};out.Pools={}
 if r and r.data and r.data.HABCrateInventory then
  out.StoredCrates,out.StoredCounts,out.Pools=HABInventoryRules.Snapshot(r.data,HABCrates)
  local inv=r.data.HABCrateInventory
  if inv.LastOpen then
   local receipt=inv.Receipts[inv.LastOpen]
   local revision=r.invTokenRevisions and r.invTokenRevisions[inv.LastOpen]
   if receipt and (not revision or (r.savedRevision or -1)>=revision) then
    out.LastOpening=copy(receipt);out.LastOpening.Token=inv.LastOpen
   end
  end
 end
 return out
end
local function inventoryReady(p,token,revision,kind,crateId,category,choice)
 local r=records[p]
 if not writable(r) then return nil,'Your saved profile is not ready. Nothing was spent.' end
 if not HABInventoryRules.Token(token) then return nil,'Invalid transaction ID.' end
 local inv=r.data.HABCrateInventory
 if not inv then return nil,'Rejoin to migrate your crate inventory.' end
 local old=inv.Receipts[token]
 if old then
  if old.Kind~=kind or (kind=='Buy' and (old.Category~=category or old.Choice~=choice))
   or (kind~='Buy' and old.Crate~=crateId) then return nil,'That transaction ID has already been used for another action.' end
  local result=copy(old);result.Token=token
  return r,nil,result
 end
 if not crateLobby(p) then return nil,'Return to the lobby first.' end
 if r.invRevision and (r.savedRevision or -1)<r.invRevision then return nil,'The previous inventory change is still saving. Please wait.' end
 if r.crateSaveRevision and (r.savedRevision or -1)<r.crateSaveRevision then return nil,'Your previous opening is still saving.' end
 if type(revision)~='number' or revision~=r.revision then return nil,'Inventory changed. Review the updated contents and confirm again.' end
 if os.clock()<(r.invAt or 0) then return nil,'Please wait a moment.' end
 local n=0;for _ in pairs(inv.Receipts) do n=n+1 end
 if n>=HABInventoryRules.MaxReceipts then return nil,'Transaction capacity reached. No charge or crate consumption occurred.' end
 return r
end
local function inventoryCommit(r,token,t)
 r.data.HABCrateInventory.Receipts[token]=t
 r.invAt=os.clock()+.6
 touch(r)
 r.invRevision=r.revision
 r.invTokenRevisions=r.invTokenRevisions or {}
 r.invTokenRevisions[token]=r.revision
 crateSync(r);sync(r);save(r)
 local response=copy(t);response.Token=token
 return true,'Confirming the save...',response
end
function E.HABBuyStoredCrate(p,category,token,revision,choice,randomAllowed)
 local r,err,previous=inventoryReady(p,token,revision,'Buy',nil,category,choice)
 if not r then return false,err end
 if previous then return true,'Purchase recovered; not charged twice.',previous end
 local plan,reason=HABInventoryRules.PlanBuy(r.data,HABCrates,category,choice,randomAllowed)
 if not plan then return false,reason end
 local inv=r.data.HABCrateInventory
 if inv.Stored[token] then return false,'Crate ID is already in use.' end
 -- No yield between Gem deduction, stored crate and transaction receipt.
 local at=os.time()
 r.data.Gems=r.data.Gems-plan.Cost
 inv.Stored[token]={Category=category,Mode=plan.Mode,Choice=plan.Choice,Cost=plan.Cost,At=at}
 return inventoryCommit(r,token,{Kind='Buy',Crate=token,Category=category,Choice=choice,
  Mode=plan.Mode,Cost=plan.Cost,At=at,Pool=plan.Pool})
end
function E.HABOpenStoredCrate(p,crateId,token,revision,randomAllowed)
 if not HABInventoryRules.Token(crateId) then return false,'Unknown stored crate.' end
 local r,err,previous=inventoryReady(p,token,revision,'Open',crateId)
 if not r then return false,err end
 if previous then return true,'Opening recovered; no second crate consumed.',previous end
 local inv=r.data.HABCrateInventory
 local stored=inv.Stored[crateId]
 if not stored then return false,'This crate is no longer in your inventory.' end
 local id,poolSize
 if stored.Mode=='Guaranteed' then
  id=stored.Choice;poolSize=1
  if not HABCrates.ById[id] or r.data.HABHalloween.Owned[id] then
   return false,'This guaranteed effect is already owned or unavailable. Refund this sealed crate instead.'
  end
 else
  if randomAllowed~=true then return false,'Random opening is unavailable for this account. Refund this sealed crate for its full Gem cost.' end
  local pool=HABInventoryRules.Pool(r.data,HABCrates,stored.Category)
  if #pool==0 then return false,'No unowned effects remain. Refund this sealed crate.' end
  poolSize=#pool;id=pool[math.random(1,#pool)]
 end
 if not HABCrates.ById[id] or HABCrates.ById[id].Category~=stored.Category then return false,'Effect catalog changed. Your crate was not consumed.' end
 -- The unopened item is removed and reward granted in ONE profile mutation.
 inv.Stored[crateId]=nil
 r.data.HABHalloween.Owned[id]=true
 r.data.HABHalloween.Last=id
 inv.LastOpen=token
 return inventoryCommit(r,token,{Kind='Open',Crate=crateId,Category=stored.Category,Item=id,
  Cost=0,At=os.time(),Pool=poolSize,Random=stored.Mode=='Random'})
end
function E.HABRefundStoredCrate(p,crateId,token,revision)
 if not HABInventoryRules.Token(crateId) then return false,'Unknown stored crate.' end
 local r,err,previous=inventoryReady(p,token,revision,'Refund',crateId)
 if not r then return false,err end
 if previous then return true,'Refund recovered; not granted twice.',previous end
 local inv=r.data.HABCrateInventory;local stored=inv.Stored[crateId]
 if not stored then return false,'This crate is no longer sealed in inventory.' end
 if r.data.Gems>MAX-stored.Cost then return false,'Spend Gems before requesting this refund.' end
 inv.Stored[crateId]=nil;r.data.Gems=r.data.Gems+stored.Cost
 return inventoryCommit(r,token,{Kind='Refund',Crate=crateId,Category=stored.Category,Cost=stored.Cost,At=os.time()})
end
function E.HABConfirmInventory(p,token,seconds)
 local r=records[p]
 local inv=r and r.data and r.data.HABCrateInventory
 if not inv or not inv.Receipts[token] then return false end
 local needed=r.invTokenRevisions and r.invTokenRevisions[token]
 if not needed then return true end -- Loaded from the confirmed profile.
 save(r)
 local untilAt=os.clock()+math.clamp(seconds or 12,0,18)
 while (r.savedRevision or -1)<needed and not r.done and not r.lost and os.clock()<untilAt do task.wait(.1) end
 return (r.savedRevision or -1)>=needed
end
-- Older clients cannot bypass the stored-crate workflow.
function E.HABOpenCrate()
 return false,'This version stores purchased crates. Rejoin, buy a crate, then open it from INVENTORY.'
end
function E.HABGrantOwnerGems(p,value)
 -- Server-side identity validation; never trust a client user ID or an owner flag.
 if not OwnerCommands.IsOwner(p) then return false,'Owner only.' end
 if type(value)~='string' or not value:match('^%d+$') or #value>7 then return false,'Use /grant gems 1000 (1 to 1000000).' end
 local amount=tonumber(value)
 if not amount or amount<1 or amount>1000000 then return false,'Use a whole amount from 1 to 1000000.' end
 local r=records[p]
 if not writable(r) then return false,'Load your saved profile first. No Gems granted.' end
 if os.clock()<(r.ownerGemAt or 0) then return false,'Wait before granting again.' end
 if r.data.Gems>MAX-amount then return false,'Gem balance limit reached.' end
 r.ownerGemAt=os.clock()+1
 r.data.Gems=r.data.Gems+amount
 touch(r);sync(r);save(r)
 return true,'Added '..amount..' Gems to YOUR saved profile. Save status: '..tostring(r.saveState or 'PENDING')
end


-- HAB_EXPANSION_7: additive profile fields; never a second data store or client-side grant.
local ExpansionConfig=require(RS.HABExpansion.Config)
local function expansion(r)
 r.data.HABExpansion=r.data.HABExpansion or {Version=1,Ability=ExpansionConfig.DefaultAbility,Bundles={}}
 return r.data.HABExpansion
end
function E.HABExpansionProfile(p)
 local r=records[p]
 if not writable(r) then return {Ready=false,Ability=ExpansionConfig.DefaultAbility,Bundles={},Abilities={},Coins=0,Gems=0,SaveStatus=r and r.saveState or 'LOADING'} end
 local d=expansion(r)
 return {Ready=true,Ability=d.Ability,Bundles=copy(d.Bundles),Abilities=copy(d.Abilities or {}),Coins=r.data.Coins,Gems=r.data.Gems,SaveStatus=r.saveState}
end
function E.HABCanUseAbility(p,key)
 local r=records[p];local def=Retirement.Ability(ExpansionConfig,key)
 if not def then return false end
 if def.Currency=='Free' then return true end
 return writable(r) and Retirement.CanUse(r.data,def)==true or false
end
function E.HABSelectedAbility(p)
 local r=records[p];local key=writable(r) and expansion(r).Ability or ExpansionConfig.DefaultAbility
 return E.HABCanUseAbility(p,key) and key or ExpansionConfig.DefaultAbility
end
function E.HABSetAbility(p,key)
 local r=records[p]
 if not writable(r) or not crateLobby(p) then return false,'Load your profile and return to the lobby.' end
 if not E.HABCanUseAbility(p,key) then return false,'Unlock this ability first.' end
 local d=expansion(r)
 if d.Ability~=key then d.Ability=key;touch(r);sync(r);save(r) end
 p:SetAttribute('HABAbility',key)
 return true,'Ability equipped. Saving.'
end
function E.HABBuyAbility(p,key)
 local r=records[p]
 if not writable(r) or not crateLobby(p) then return false,'Return to the lobby with your saved profile ready.' end
 local def=Retirement.Ability(ExpansionConfig,key)
 if def and Retirement.CanUse(r.data,def) then return true,'Already unlocked; no extra charge.' end
 if r.abilityPurchaseRevision and (r.savedRevision or -1)<r.abilityPurchaseRevision then return false,'Your last ability purchase is still saving.' end
 local plan,message=Retirement.PlanBuy(r.data,def)
 if not plan then return false,message end
 -- Ownership and balance change together; no yield and no second store.
 r.data[plan.Currency]-=plan.Cost
 local x=expansion(r);x.Abilities=x.Abilities or {};x.Abilities[key]=true
 touch(r);r.abilityPurchaseRevision=r.revision;sync(r);save(r)
 return true,def.Name..' unlocked. Saving; equip when ready.'
end
function E.HABGrantAbilityPass(p,key)
 -- Only HABPassService calls this after a server-verified entitlement.
 local r=records[p];local def=Retirement.Ability(ExpansionConfig,key)
 if not writable(r) or not def or def.Currency~='Robux' then return false end
 local d=expansion(r);d.Abilities=d.Abilities or {}
 if not d.Abilities[key] then d.Abilities[key]=true;touch(r);sync(r);save(r) end
 return true
end
local function bundle(key)
 for _,b in ipairs(ExpansionConfig.Bundles) do if b.Key==key then return b end end
end
function E.HABGrantBundle(p,key)
 local r=records[p];local b=bundle(key)
 if not writable(r) or not b then return false,'Profile unavailable.' end
 if not items[b.Skin] then return false,'Bundle skin is missing from catalog.' end
 for _,fx in ipairs(b.Items) do
  local item=HABCrates.ById[fx.Id]
  if not item or item.Category~=fx.Slot then return false,'Bundle effect missing from catalog.' end
 end
 local d=expansion(r);local changed=false
 if d.Bundles[key]~=true then d.Bundles[key]=true;changed=true end
 if r.data.Owned[b.Skin]~=true then r.data.Owned[b.Skin]=true;changed=true end
 for _,fx in ipairs(b.Items) do if r.data.HABHalloween.Owned[fx.Id]~=true then r.data.HABHalloween.Owned[fx.Id]=true;changed=true end end
 if changed then touch(r);crateSync(r);sync(r,nil,true,b.Name..' delivered. Saving.');save(r) end
 return true
end
function E.HABEquipBundle(p,key)
 local r=records[p];local b=bundle(key)
 if not writable(r) or not crateLobby(p) or not b then return false,'Return to the lobby with your profile loaded.' end
 if expansion(r).Bundles[key]~=true or r.data.Owned[b.Skin]~=true then return false,'Bundle ownership is not loaded.' end
 for _,fx in ipairs(b.Items) do if not r.data.HABHalloween.Owned[fx.Id] then return false,'Bundle is still being delivered.' end end
 r.data.EquippedByCategory.Bombs=b.Skin
 for _,fx in ipairs(b.Items) do r.data.HABHalloween.Equipped[fx.Slot]=fx.Id end
 touch(r);crateSync(r);sync(r);save(r)
 return true,b.Name..' equipped.'
end
function E.HABGrantVIP(p)
 local r=records[p]
 if not writable(r) then return false end
 local cfg=ExpansionConfig.VIP;local changed=false
 if not items[cfg.Title] or not HABCrates.ById[cfg.Effect] then return false end
 if not r.data.Owned[cfg.Title] then r.data.Owned[cfg.Title]=true;changed=true end
 if not r.data.HABHalloween.Owned[cfg.Effect] then r.data.HABHalloween.Owned[cfg.Effect]=true;changed=true end
 if changed then touch(r);sync(r,nil,true,'Spotlight VIP cosmetics delivered. Equip them from inventory.');save(r) end
 return true
end

return E


-- HAB_HALLOWEEN_CRATES_1

-- HAB_CRATE_UPGRADE_2

-- HAB_CRATE_GUI_4
-- HAB_EXPANSION_7

-- HAB_FUN_9
