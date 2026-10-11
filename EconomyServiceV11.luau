--!nonstrict
-- HussEconomyV9: persisted store identity is permanent.
-- HussEconomyV11: additive collection migration and authoritative multiplayer stats.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local DS=game:GetService('DataStoreService')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local E={}
local PREVIEW=Run:IsStudio()
local MAX,LEASE=2000000000,180
local Catalog=require(RS:WaitForChild('HussCatalogV11'))
local catalog,items,defaults=Catalog.Items,Catalog.ById,Catalog.Defaults
local quests={{id='rounds',title='Complete 3 rounds',target=3,reward=100},{id='passes',title='Pass the bomb 10 times',target=10,reward=150},{id='wins',title='Win a round',target=1,reward=200}}
local records,byUser,match={},{},nil
local remote,store,ordered,started,closing
local board={kind='Board',status=PREVIEW and 'preview' or 'loading',rows={},updatedAt=0}
local boardAt,boardBusy,boardWanted=0,false,false
local names={}
local save
local function integer(n) return type(n)=='number' and n==n and n>=0 and n<=MAX and n%1==0 end
local function copy(t) local out={};for k,v in pairs(t) do out[k]=type(v)=='table' and copy(v) or v end;return out end
local function day() return math.floor(os.time()/86400) end
local function migrate(old)
 local d=copy(old)
 d.Kills=d.Kills or 0;d.FinalStands=d.FinalStands or 0
 d.EquippedByCategory=d.EquippedByCategory or {}
 for category,id in pairs(defaults) do
  d.Owned[id]=true
  if not d.EquippedByCategory[category] then d.EquippedByCategory[category]=category=='Trails' and d.Equipped or id end
 end
 return d
end
local function fresh()
 return migrate({v=1,Coins=0,Wins=0,GamesPlayed=0,Passes=0,Owned={default=true},Equipped='default',Day=day(),Progress={rounds=0,passes=0,wins=0},Claimed={}})
end
local function valid(d)
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
local function touch(r) r.revision+=1 end
local function rollover(r)
 if r.data and r.data.Day~=day() then r.data.Day=day();r.data.Progress={rounds=0,passes=0,wins=0};r.data.Claimed={};touch(r) end
end
local function writable(r)
 return r and r.ready and not r.closed and not r.lost and (PREVIEW or os.time()<r.expires-10)
end
local function sync(r,requestId,ok,message)
 if not r.player.Parent then return end
 local ready=writable(r)==true
 if ready then rollover(r) end
 local d=r.data
 local out={kind='Profile',requestId=requestId,ok=ok~=false,ready=ready,mode=ready and (PREVIEW and 'preview' or 'live') or (r.loading and 'loading' or 'unavailable'),message=message or r.message,Catalog=catalog,Quests={},Owned={},Coins=d and d.Coins or 0,Wins=d and d.Wins or 0,GamesPlayed=d and d.GamesPlayed or 0,Passes=d and d.Passes or 0,Equipped=d and d.Equipped or 'default',EquippedByCategory=d and copy(d.EquippedByCategory) or copy(defaults),Kills=d and d.Kills or 0,FinalStands=d and d.FinalStands or 0,resetsAt=(day()+1)*86400}
 for _,q in ipairs(quests) do local row=copy(q);row.progress=d and math.min(d.Progress[q.id],q.target) or 0;row.claimed=d and d.Claimed[q.id]==true or false;table.insert(out.Quests,row) end
 for _,item in ipairs(catalog) do if d and d.Owned[item.id] then table.insert(out.Owned,item.id) end end
 r.player:SetAttribute('HussEconomyReady',ready)
 if d then
  r.coins.Value=d.Coins;r.wins.Value=d.Wins;r.kills.Value=d.Kills;r.finalStands.Value=d.FinalStands
  r.player:SetAttribute('GamesPlayed',d.GamesPlayed);r.player:SetAttribute('Passes',d.Passes)
  r.player:SetAttribute('HussBombId',d.EquippedByCategory.Bombs)
  r.player:SetAttribute('HussTitleId',d.EquippedByCategory.Titles)
  r.player:SetAttribute('HussEmoteId',d.EquippedByCategory.Emotes)
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
save=function(r,release)
 if release then r.release=true end
 if r.saving or r.loading or r.done then return end
 if PREVIEW or not r.data or r.lost then if r.release then retire(r) end;return end
 r.saving=true
 task.spawn(function()
  repeat
   while not r.release and os.clock()<(r.nextSaveAt or 0) do task.wait(math.min(.25,r.nextSaveAt-os.clock())) end
   local final=r.release==true
   local snapshot,revision=copy(r.data),r.revision
   local expiry=os.time()+LEASE
   if final then snapshot.Lease=nil else snapshot.Lease={token=r.token,expires=expiry} end
   local ok,result=retry(function()
    return store:UpdateAsync('u'..r.player.UserId,function(old)
     -- Never reacquire an expired lease using stale in-memory currency.
     if not valid(old) or not old.Lease or old.Lease.token~=r.token or old.Lease.expires<=os.time() then return nil end
     return copy(snapshot)
    end)
   end)
   r.nextSaveAt=os.clock()+10
   if ok and result and (final or (result.Lease and result.Lease.token==r.token)) then
    r.savedRevision=revision;r.savedWins=snapshot.Wins;r.expires=expiry;r.message=nil
    boardWrite(r)
    if final then retire(r);break end
    sync(r)
   elseif ok then
    r.lost=true;r.ready=false;r.message='Progress is locked because this session expired. Rejoin to reload safely.'
    sync(r,nil,false,r.message)
    if r.release then retire(r) end
    break
   else
    r.message='Saving is delayed. Progress is not yet confirmed saved.'
    sync(r)
    if r.release then retire(r);warn('[HussEconomyV9] Final save failed for '..r.player.UserId) end
    break
   end
  until not r.release and r.revision==revision
  r.saving=false
 end)
end
local function load(r,previous)
 if previous and not previous.done then
  local deadline=os.clock()+20
  repeat task.wait(.2) until previous.done or os.clock()>=deadline or r.closed
 end
 if r.closed then r.loading=false;retire(r);return end
 if previous and not previous.done then r.loading=false;r.message='Your previous session is still closing. Rejoin shortly.';sync(r);return end
 byUser[r.player.UserId]=r
 if PREVIEW then r.data=fresh();r.expires=math.huge
 else
  local ok,result=retry(function()
   return store:UpdateAsync('u'..r.player.UserId,function(old)
    if old~=nil and not valid(old) then return nil end
    local d=old or fresh()
    if d.Lease and d.Lease.token~=r.token and d.Lease.expires>os.time() then return nil end
    local value=migrate(d);value.Lease={token=r.token,expires=os.time()+LEASE};return value
   end)
  end)
  if ok and valid(result) and result.Lease and result.Lease.token==r.token then
   r.data=copy(result);r.data.Lease=nil;r.expires=result.Lease.expires
  else r.message='Progress could not be loaded safely. Rejoin shortly; purchases and rewards are paused.' end
 end
 r.loading=false
 if r.closed then save(r,true);return end
 r.ready=r.data~=nil;sync(r)
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
 local r={player=p,coins=stat('Coins'),wins=stat('Wins'),kills=stat('Kills'),finalStands=stat('FinalStands'),token=game.JobId..':'..Http:GenerateGUID(false),loading=true,revision=0,savedRevision=0,tokens=8,rateAt=os.clock()}
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
  local q;for _,entry in ipairs(quests) do if entry.id==id then q=entry;break end end
  if not q or d.Claimed[id] or d.Progress[id]<q.target then sync(r,requestId,false,'This quest is not ready to claim.');return end
  d.Claimed[id]=true;d.Coins=math.min(MAX,d.Coins+q.reward);touch(r);sync(r,requestId,true,'Quest reward claimed!');save(r);return
 end
 local item=items[id]
 if not item then sync(r,requestId,false,'Unknown item.');return end
 if d.Owned[id] and d.EquippedByCategory[item.category]==id then sync(r,requestId,true,'Already equipped.');return end
 if action=='Buy' and not d.Owned[id] then
  if d.Coins<item.price then sync(r,requestId,false,'You need more Coins.');return end
  d.Coins-=item.price;d.Owned[id]=true
 elseif not d.Owned[id] then sync(r,requestId,false,'Unlock this item first.');return end
 d.EquippedByCategory[item.category]=id
 if item.category=='Trails' then d.Equipped=id end
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
 if not PREVIEW then store=DS:GetDataStore('HussEconomyV9');ordered=DS:GetOrderedDataStore('HussWinsV9') end
 remote=RS:FindFirstChild('HussEconomyV9')
 if not remote then remote=Instance.new('RemoteEvent');remote.Name='HussEconomyV9';remote.Parent=RS end
 assert(remote:IsA('RemoteEvent'),'HussEconomyV9 must be a RemoteEvent')
 remote.OnServerEvent:Connect(request)
 Players.PlayerAdded:Connect(setup)
 Players.PlayerRemoving:Connect(function(p) local r=records[p];if r then r.closed=true;r.ready=false;save(r,true) end end)
 for _,p in ipairs(Players:GetPlayers()) do setup(p) end
 task.spawn(function()
  local saveAt=os.clock()+45
  while not closing do
   task.wait(5)
   for _,r in pairs(records) do if r.ready and not writable(r) and not r.closed then sync(r) end end
   if os.clock()>=saveAt then saveAt=os.clock()+45;for _,r in pairs(records) do save(r) end end
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
return E
