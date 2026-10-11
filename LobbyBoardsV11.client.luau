--!nonstrict
-- HussLobbyBoardsV11: public lobby signs share the authoritative player stats.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local P=Players.LocalPlayer
local valid={Wins=true,Kills=true,FinalStands=true,GlobalWins=true}
local boards,watchers,links={},{},{}
local remote,remoteLink,global,nextRequest=nil,nil,nil,0
local dirty,elapsed,alive=true,0,true
local function connect(signal,fn,list) local c=signal:Connect(fn);table.insert(list or links,c);return c end
local function clear(list) for _,c in ipairs(list) do c:Disconnect() end;table.clear(list) end
local function number(v) return type(v)=='number' and v==v and math.clamp(math.floor(v),0,2000000000) or 0 end
local function stat(p,key) local f=p:FindFirstChild('leaderstats');local v=f and f:FindFirstChild(key);return v and (v:IsA('IntValue') or v:IsA('NumberValue')) and number(v.Value) or 0 end
local function watch(p)
 if watchers[p] then clear(watchers[p]) end
 local list={};watchers[p]=list
 local function changed() dirty=true end
 connect(p.ChildAdded,function() watch(p) end,list);connect(p.ChildRemoved,function() watch(p) end,list)
 connect(p:GetPropertyChangedSignal('DisplayName'),changed,list)
 local f=p:FindFirstChild('leaderstats')
 if f then
  connect(f.ChildAdded,function() watch(p) end,list);connect(f.ChildRemoved,function() watch(p) end,list)
  for _,v in ipairs(f:GetChildren()) do if v:IsA('IntValue') or v:IsA('NumberValue') then connect(v.Changed,changed,list) end end
 end
 dirty=true
end
local function detect(o)
 if o:IsA('SurfaceGui') and o.Name=='BoardGui' then
  local part=o.Parent
  if part and part:IsA('BasePart') and valid[part:GetAttribute('HussBoardStat')] then boards[o]=part:GetAttribute('HussBoardStat');dirty=true end
 end
end
local function attach(o)
 if o.Name~='HussEconomyV9' or not o:IsA('RemoteEvent') or o==remote then return end
 if remoteLink then remoteLink:Disconnect() end;remote=o;global=nil;nextRequest=0;dirty=true
 remoteLink=connect(o.OnClientEvent,function(data)
  if type(data)~='table' or data.kind~='Board' then return end
  global={status=type(data.status)=='string' and data.status or 'unavailable',rows={}}
  if type(data.rows)=='table' then for i,row in ipairs(data.rows) do
   if i>10 then break end
   if type(row)=='table' and type(row.name)=='string' then table.insert(global.rows,{name=row.name:sub(1,64),value=number(row.wins)}) end
  end end
  dirty=true
 end)
end
local function render()
 local roster=Players:GetPlayers();local sorted={}
 for gui,key in pairs(boards) do
  if not gui:IsDescendantOf(workspace) then boards[gui]=nil;continue end
  local body=gui:FindFirstChild('Body');if not body then continue end
  local rows,status={}
  if key=='GlobalWins' then
   rows=global and global.rows or {}
   status=not global and 'LOADING GLOBAL WINS…' or global.status=='ready' and 'ALL SERVERS • UPDATES EVERY 2 MINUTES' or global.status=='preview' and 'GLOBAL RANKINGS IN THE PUBLISHED GAME' or global.status=='loading' and 'LOADING GLOBAL WINS…' or 'GLOBAL RANKINGS TEMPORARILY UNAVAILABLE'
  else
   if not sorted[key] then
    local list=table.clone(roster);table.sort(list,function(a,b) local av,bv=stat(a,key),stat(b,key);return av==bv and a.UserId<b.UserId or av>bv end)
    local result={};for i,p in ipairs(list) do if i>10 then break end;table.insert(result,{name=p.DisplayName,value=stat(p,key)}) end;sorted[key]=result
   end
   rows=sorted[key];status='THIS SERVER • MULTIPLAYER RECORDS'
  end
  for i=1,10 do local label=body:FindFirstChild('Row'..i);if label and label:IsA('TextLabel') then local row=rows[i];label.Text=row and string.format('%02d   %s   •   %d',i,row.name,row.value) or '';label.TextTruncate=Enum.TextTruncate.AtEnd end end
  local label=body:FindFirstChild('Status');if label and label:IsA('TextLabel') then label.Text=status end
 end
end
connect(Players.PlayerAdded,watch)
connect(Players.PlayerRemoving,function(p) if watchers[p] then clear(watchers[p]);watchers[p]=nil end;dirty=true end)
for _,p in ipairs(Players:GetPlayers()) do watch(p) end
connect(workspace.DescendantAdded,function(o) task.defer(function() if alive then detect(o);if o.Name=='Body' or o.Name=='Status' or o.Name:match('^Row%d+$') then dirty=true end end end) end)
connect(workspace.DescendantRemoving,function(o) if boards[o] then boards[o]=nil end end)
for _,o in ipairs(workspace:GetDescendants()) do detect(o) end
connect(RS.ChildAdded,attach)
connect(RS.ChildRemoved,function(o) if o==remote then if remoteLink then remoteLink:Disconnect() end;remote=nil;global=nil;dirty=true end end)
for _,o in ipairs(RS:GetChildren()) do attach(o) end
connect(Run.Heartbeat,function(dt)
 elapsed+=dt;if elapsed<.5 then return end;elapsed=0
 if dirty then dirty=false;render() end
 if remote and P:GetAttribute('InRound')~=true and time()>=nextRequest then
  for _,key in pairs(boards) do if key=='GlobalWins' then nextRequest=time()+120;remote:FireServer('Board');break end end
 end
end)
connect(script.Destroying,function() alive=false;clear(links);for _,list in pairs(watchers) do clear(list) end;table.clear(watchers);table.clear(boards) end)
