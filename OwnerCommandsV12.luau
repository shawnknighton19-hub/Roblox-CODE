--!nonstrict
-- Server-only owner tools. No RemoteEvent accepts a grant or an owner identity.
local Players=game:GetService('Players')
local GroupService=game:GetService('GroupService')
local TextChatService=game:GetService('TextChatService')
local RS=game:GetService('ReplicatedStorage')
local Catalog=require(RS:WaitForChild('HussCatalogV11'))
local O={}
local started=false
local cache={group=0,id=nil,expires=0,busy=false}
local buckets={}
local aliases={['/grant']=true,['/hussgrant']=true}
local categories={bomb='Bombs',bombs='Bombs',trail='Trails',trails='Trails',title='Titles',titles='Titles',emote='Emotes',emotes='Emotes'}
local function realPlayer(player)
 return typeof(player)=='Instance' and player:IsA('Player') and player.Parent==Players and type(player.UserId)=='number' and player.UserId>0 and player.UserId%1==0
end
function O.IsOwner(player)
 if not realPlayer(player) or type(game.CreatorId)~='number' or game.CreatorId<=0 or game.CreatorId%1~=0 then return false end
 if game.CreatorType==Enum.CreatorType.User then return player.UserId==game.CreatorId end
 if game.CreatorType~=Enum.CreatorType.Group then return false end
 local group=game.CreatorId
 if cache.group~=group then cache={group=group,id=nil,expires=0,busy=false} end
 if os.clock()>=cache.expires then
  if cache.busy then return false end
  cache.busy=true
  local ok,info=pcall(GroupService.GetGroupInfoAsync,GroupService,group)
  local id=ok and type(info)=='table' and type(info.Owner)=='table' and info.Owner.Id or nil
  -- Refresh transfers within 30 seconds. A failed/ownerless lookup never retains access.
  cache.id=type(id)=='number' and id>0 and id%1==0 and id or nil
  cache.expires=os.clock()+(cache.id and 30 or 5)
  cache.busy=false
 end
 return realPlayer(player) and game.CreatorType==Enum.CreatorType.Group and game.CreatorId==group and player.UserId==cache.id
end
local function allow(player)
 local now=os.clock()
 local b=buckets[player] or {at=now,tokens=2};buckets[player]=b
 b.tokens=math.min(2,b.tokens+math.max(0,now-b.at));b.at=now
 if b.tokens<1 then return false end
 b.tokens-=1;return true
end
local function feedback(player,ok,message)
 if not realPlayer(player) then return end
 local remote=RS:FindFirstChild('HussEconomyV9')
 if remote and remote:IsA('RemoteEvent') then remote:FireClient(player,{kind='OwnerCommand',ok=ok,message=message}) end
end
local function handle(economy,player,message)
 if type(message)~='string' or #message>160 or message:find('[%z\1-\8\11\12\14-\31]') then return end
 local words={};for word in message:gmatch('%S+') do table.insert(words,word);if #words>8 then return end end
 if not words[1] or not aliases[words[1]:lower()] or not O.IsOwner(player) or not allow(player) then return end
 local kind=words[2] and words[2]:lower() or 'help'
 if kind=='help' and #words<=2 then
  feedback(player,true,'Owner only: /grant coins 10000 | /grant all (unlock every cosmetic; keep equipment).')
  feedback(player,true,'/grant bomb bomb_nova | /grant trail trail_comet | /grant title title_legend | /grant emote emote_robot. An individual item is unlocked and equipped.')
  feedback(player,true,'/grant list bombs (also trails, titles, emotes) lists item IDs. Self grants do not change wins, kills, final stands or quests. Studio balances are temporary.')
  return
 end
 if kind=='list' and #words==3 and categories[words[3]:lower()] then
  local wanted=categories[words[3]:lower()];local rows={}
  for _,item in ipairs(Catalog.Items) do if item.category==wanted then
   table.insert(rows,item.id..' = '..item.name)
   if #rows==5 then feedback(player,true,table.concat(rows,' | '));table.clear(rows) end
  end end
  if #rows>0 then feedback(player,true,table.concat(rows,' | ')) end
  return
 end
 if (kind=='all' and #words~=2) or (kind=='coins' and #words~=3) or (kind~='all' and kind~='coins' and (not categories[kind] or #words<3)) then
  feedback(player,false,'Use /grant help for the owner commands.');return
 end
 local value=#words>=3 and table.concat(words,' ',3) or nil
 local ok,messageOut=economy.GrantOwner(player,kind,value)
 feedback(player,ok,messageOut)
end
function O.Init(economy)
 if started then return end
 assert(type(economy)=='table' and type(economy.GrantOwner)=='function','OwnerCommandsV12 needs the V12 economy API')
 started=true
 Players.PlayerRemoving:Connect(function(player) buckets[player]=nil end)
 if TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
  -- Leave other developers' commands untouched and disable this feature on conflicts.
  for _,child in ipairs(TextChatService:GetDescendants()) do
   if child:IsA('TextChatCommand') and (aliases[child.PrimaryAlias:lower()] or aliases[child.SecondaryAlias:lower()] or child.Name=='HussOwnerGrantV12') then
    warn('[Huss V12 owner commands] /grant or /hussgrant already belongs to '..child:GetFullName()..'. Owner commands were not registered.');return
   end
  end
  local command=Instance.new('TextChatCommand');command.Name='HussOwnerGrantV12'
  command.PrimaryAlias='/grant';command.SecondaryAlias='/hussgrant';command.AutocompleteVisible=false;command.Enabled=true
  command:SetAttribute('HussOwnerCommandVersion',12)
  command.Triggered:Connect(function(source,message)
   if typeof(source)~='Instance' or not source:IsA('TextSource') then return end
   local player=Players:GetPlayerByUserId(source.UserId)
   if player then handle(economy,player,message) end
  end)
  command.Parent=TextChatService
 elseif TextChatService.ChatVersion==Enum.ChatVersion.LegacyChatService then
  local function attach(player) player.Chatted:Connect(function(message) handle(economy,player,message) end) end
  Players.PlayerAdded:Connect(attach)
  for _,player in ipairs(Players:GetPlayers()) do attach(player) end
 else warn('[Huss V12 owner commands] Unsupported chat version; owner commands are disabled.') end
end
return O
