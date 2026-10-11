-- V11 compatibility adapters. Only verified source variants are accepted.
-- Normalizes Windows line endings and outer whitespace, never custom edits.
local A={}
local function canonical(source)
 assert(type(source)=='string','Expected readable script Source. Nothing changed.')
 return (source:gsub('\r\n','\n'):match('^%s*(.-)%s*$'))
end
local function fingerprint(source)
 source=canonical(source)
 local a,b,rolling=1,0,0
 for i=1,#source do
  local byte=source:byte(i)
  a=(a+byte)%65521;b=(b+a)%65521;rolling=(rolling*131+byte)%4294967296
 end
 return string.format('%d:%u:%u',#source,b*65536+a,rolling)
end
local HUD_KNOWN={
 ['43156:1708150693:1771661251']='V10-on-V8',
 ['56155:3359992364:4165224053']='V10-on-V9',
 ['63383:1602472467:4134607965']='V11',
}
local EFFECTS_KNOWN={
 ['8340:3348510511:2148878879']='EffectsV8',
 ['8874:2348936961:606902339']='EffectsV9',
}
local function identify(source,known,label)
 local key=fingerprint(source);local version=known[key]
 assert(version,'Unsupported or partially modified '..label..' source ('..key..'). Expected a verified historical version; source was not overwritten. Nothing changed.')
 return version
end
function A.IdentifyHUD(source) return identify(source,HUD_KNOWN,'HudController') end
function A.IdentifyEffects(source) return identify(source,EFFECTS_KNOWN,'MovementEffectsV8') end
local function addEconomy(source)
 local function replace(old,new)
  local first,last=source:find(old,1,true)
  assert(first and not source:find(old,last+1,true),'HUD compatibility patch anchor mismatch. Nothing changed.')
  source=source:sub(1,first-1)..new..source:sub(last+1)
 end
 replace([=[
local previewFolder, voteRemote, afkRemote, voteLink, pageName, mapIndex = nil,nil,nil,nil,nil,1
local lastSize, tickTime, statTime, noticeUntil = Vector2.zero,0,0,0
local refresh, layout, openMenu, buildPage
local phases = {WAITING="WAITING FOR PLAYERS",INTERMISSION="NEXT MATCH",STARTING="GET READY",PRACTICE="PRACTICE",PRACTICE_ENDING="PLAYER JOINING",ROUND="MATCH LIVE",FINAL_DUEL="FINAL DUEL",RESULT="ROUND COMPLETE"}
]=],[=[
local previewFolder, voteRemote, afkRemote, voteLink, pageName, mapIndex = nil,nil,nil,nil,nil,1
local lastSize, tickTime, statTime, noticeUntil = Vector2.zero,0,0,0
-- HussEconomyHudV9
local economy,ecoLink,profile,board,busy,serial=nil,nil,nil,nil,nil,0
local rosterLinks={}
local ecoMessage
local refresh, layout, openMenu, buildPage
local phases = {WAITING="WAITING FOR PLAYERS",INTERMISSION="NEXT MATCH",STARTING="GET READY",PRACTICE="PRACTICE",PRACTICE_ENDING="PLAYER JOINING",ROUND="MATCH LIVE",FINAL_DUEL="FINAL DUEL",RESULT="ROUND COMPLETE"}
]=])
 replace([=[
local function stroke(o,color) return make("UIStroke",o,{Color=color or C.line,Thickness=2,Transparency=.12,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function text(parent,name,value,x,y,w,h,size,color,align)
 local o=make("TextLabel",parent,{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,Font=Enum.Font.GothamBold,TextSize=size,TextColor3=color or C.white,TextStrokeColor3=C.ink,TextStrokeTransparency=1,TextXAlignment=align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=(parent.ZIndex or 1)+2})
 local outline=make('UIStroke',o,{Color=C.ink,Thickness=size>=18 and 2.3 or 1.3,Transparency=0,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 o.Font=size>=18 and Enum.Font.FredokaOne or Enum.Font.GothamBlack
]=],[=[
local function stroke(o,color) return make("UIStroke",o,{Color=color or C.line,Thickness=2,Transparency=.12,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function text(parent,name,value,x,y,w,h,size,color,align)
 local o=make("TextLabel",parent,{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,Font=Enum.Font.GothamBlack,TextSize=size,TextColor3=color or C.white,TextStrokeColor3=C.ink,TextStrokeTransparency=1,TextXAlignment=align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=(parent.ZIndex or 1)+2})
 local outline=make('UIStroke',o,{Color=C.ink,Thickness=size>=18 and 2.3 or 1.3,Transparency=0,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 o.Font=size>=18 and Enum.Font.FredokaOne or Enum.Font.GothamBlack
]=])
 replace([=[
 local cf,size=copy:GetBoundingBox(); v.name=name; v.center=cf.Position; v.radius=math.max(size.Magnitude/2,1); fit(v)
end
local function makeUI()
 local pg=P:WaitForChild("PlayerGui"); local old=pg:FindFirstChild("BombTagHUD"); if old then old:Destroy() end
]=],[=[
 local cf,size=copy:GetBoundingBox(); v.name=name; v.center=cf.Position; v.radius=math.max(size.Magnitude/2,1); fit(v)
end
local function ecoRefresh()
 if U.Mode=='menu' and (menu=='SHOP' or menu=='QUESTS' or menu=='LEADERBOARDS') then local pos=U.Body.CanvasPosition;buildPage();U.Body.CanvasPosition=pos end
end
local function request(action,id)
 if busy or not economy then return end
 serial+=1;local ticket=serial;local generation=epoch;busy=ticket;ecoMessage=nil
 economy:FireServer(action,id,ticket);ecoRefresh()
 task.delay(10,function()
  if started and epoch==generation and busy==ticket then busy=nil;ecoMessage='This is taking longer than expected. Please try again.';ecoRefresh() end
 end)
end
local function cleanText(v,f) return type(v)=='string' and v:sub(1,90) or f or '' end
local function amount(v) return math.clamp(math.floor(num(v,0)),0,1000000000000) end
local function receive(data)
 if type(data)~='table' then return end
 if data.kind=='Profile' then
  local p={ready=data.ready==true,mode=cleanText(data.mode),Equipped=cleanText(data.Equipped),Catalog={},Quests={},Owned={},resetsAt=amount(data.resetsAt)}
  if type(data.Owned)=='table' then for i,id in ipairs(data.Owned) do if i>32 then break end;if type(id)=='string' then p.Owned[id:sub(1,90)]=true end end end
  if type(data.Catalog)=='table' then for i,item in ipairs(data.Catalog) do
   if i>12 then break end
   if type(item)=='table' and type(item.id)=='string' then
    local color=type(item.color)=='table' and item.color or {};table.insert(p.Catalog,{id=cleanText(item.id),name=cleanText(item.name,'Trail'),price=amount(item.price),color=rgb(math.clamp(num(color[1],255),0,255),math.clamp(num(color[2],255),0,255),math.clamp(num(color[3],255),0,255))})
   end
  end end
  if type(data.Quests)=='table' then for i,q in ipairs(data.Quests) do
   if i>12 then break end
   if type(q)=='table' and type(q.id)=='string' then table.insert(p.Quests,{id=cleanText(q.id),title=cleanText(q.title,'Daily quest'),target=math.max(1,amount(q.target)),progress=amount(q.progress),reward=amount(q.reward),claimed=q.claimed==true}) end
  end end
  profile=p
 elseif data.kind=='Board' then
  board={status=cleanText(data.status),rows={}}
  if type(data.rows)=='table' then for i,r in ipairs(data.rows) do
   if i>25 then break end
   if type(r)=='table' then table.insert(board.rows,{name=cleanText(r.name,'Player'),wins=amount(r.wins)}) end
  end end
 else return end
 if busy==data.requestId then
  busy=nil
  if type(data.message)=='string' and data.message~='' then ecoMessage=cleanText(data.message);announce(data.ok==true and 'ALL SET!' or 'PLEASE TRY AGAIN',cleanText(data.message),data.ok==true and C.green or C.gold) end
 end
 ecoRefresh()
end
local function watchPlayer(player)
 if rosterLinks[player] then clear(rosterLinks[player]) end
 local bucket={};rosterLinks[player]=bucket
 local function update() if player==P then U.Identity.Player.Text=player.DisplayName:upper() end;ecoRefresh() end
 local function value(v) if v:IsA('IntValue') or v:IsA('NumberValue') then connect(v.Changed,update,bucket) end end
 local function folder(f)
  if f.Name=='leaderstats' then connect(f.ChildAdded,function() watchPlayer(player) end,bucket);connect(f.ChildRemoved,function() watchPlayer(player) end,bucket);for _,v in ipairs(f:GetChildren()) do value(v) end end
 end
 connect(player.ChildAdded,function() watchPlayer(player) end,bucket);connect(player.ChildRemoved,function() watchPlayer(player) end,bucket)
 connect(player:GetPropertyChangedSignal('DisplayName'),update,bucket)
 for _,f in ipairs(player:GetChildren()) do folder(f) end
 update()
end
local function economyPage(block,width)
 local y=0
 local function card(title,body,color,height)
  local before=#U.Body:GetChildren();block(title,body,color,height);local o=U.Body:GetChildren()[before+1];y+=height+12;return o
 end
 local function action(parent,name,caption,fn,disabled)
  local b=button(parent,name,caption,fn,false,pageLinks);b.Position=UDim2.new(0,12,1,-56);b.Size=UDim2.new(1,-24,0,44);b:SetAttribute('HussDisabled',busy~=nil or disabled==true);return b
 end
 if ecoMessage then card('UPDATE',ecoMessage,C.gold,100) end
 if menu=='LEADERBOARDS' then
  card('THIS SERVER','The same Wins and Coins shown in the Roblox player list.',C.cyan,88)
  local list=Players:GetPlayers()
  local function stat(p,key) local f=p:FindFirstChild('leaderstats');local v=f and f:FindFirstChild(key);return v and (v:IsA('IntValue') or v:IsA('NumberValue')) and amount(v.Value) or 0 end
  table.sort(list,function(a,b) local aw,bw=stat(a,'Wins'),stat(b,'Wins');return aw==bw and a.UserId<b.UserId or aw>bw end)
  for i,p in ipairs(list) do card(i..'. '..p.DisplayName,formatted(stat(p,'Wins'))..' WINS   •   '..formatted(stat(p,'Coins'))..' COINS',p==P and C.gold or C.white,86) end
  local message=not board and 'Load the global wins leaderboard.' or board.status=='ready' and 'Most wins across all servers. Updates about every 2 minutes.' or board.status=='loading' and 'Loading global wins…' or board.status=='preview' and 'Play the published game for global rankings.' or 'Global rankings are temporarily unavailable.'
  local c=card('GLOBAL WINS',message,C.violet,158)
  action(c,'LoadBoard',busy and 'LOADING…' or 'REFRESH GLOBAL WINS',function() request('Board') end,not economy)
  if board and board.status=='ready' then for i,row in ipairs(board.rows) do card('#'..i..'  '..row.name,formatted(row.wins)..' WINS',C.gold,86) end end
 elseif not profile or not profile.ready then
  local c=card('YOUR PLAYER RECORD',profile and profile.mode=='unavailable' and 'Your saved record is unavailable. Please rejoin before earning or spending.' or 'Connecting to your saved coins, quests and collection…',C.gold,180)
  action(c,'RetryProfile',busy and 'CONNECTING…' or 'REFRESH STATUS',function() request('Sync') end,not economy)
 else
  local coins=numberStat('Coins')
  card(menu=='SHOP' and 'TRAIL COLLECTION' or 'DAILY QUESTS',menu=='SHOP' and 'Your color. Your escape. Earn coins, unlock a trail, make it yours.' or 'Complete these goals, then claim your coins. Quests reset at 00:00 UTC.',C.gold,menu=='SHOP' and 82 or 108)
  if profile.mode=='preview' then card('STUDIO PREVIEW','Preview progress is temporary. Your live saved record is separate.',C.gold,90) end
  if menu=='SHOP' then
   local columns=width>=810 and 3 or width>=520 and 2 or 1;local start=y;local height=324
   for index,item in ipairs(profile.Catalog) do
    local owned=profile.Owned[item.id];local equipped=profile.Equipped==item.id;local poor=not owned and (coins==nil or coins<item.price)
    local c=card(item.name:upper(),equipped and 'Your active sprint + weave trail' or owned and 'Owned • ready to equip' or formatted(item.price)..' COINS\nSprint + weave color',item.color,height)
    c.Size=UDim2.new(1/columns,-16,0,height);c.Position=UDim2.new((index-1)%columns/columns,7,0,start+math.floor((index-1)/columns)*(height+20)+5)
    c.BackgroundColor3=item.color:Lerp(C.ink,.86);local inner=c:FindFirstChild('InnerRim');local rim=inner and inner:FindFirstChildOfClass('UIStroke');if rim then rim.Color=item.color;rim.Thickness=4 end
    c.Gloss:Destroy();local gradient=c:FindFirstChildOfClass('UIGradient');if gradient then gradient.Color=ColorSequence.new(rgb(60,67,70),C.white) end
    local art=emblem(c,'Trail',142,item.color);art.AnchorPoint=Vector2.new(.5,0);art.Position=UDim2.new(.5,0,0,13)
    local title=c.Heading;title.Position=UDim2.new(0,10,0,162);title.Size=UDim2.new(1,-20,0,36);title.TextSize=24;title.Font=Enum.Font.FredokaOne;title:FindFirstChildOfClass('UIStroke').Thickness=2.5;title.TextXAlignment=Enum.TextXAlignment.Center
    local body=c.Description;body.Position=UDim2.new(0,14,0,202);body.Size=UDim2.new(1,-28,0,44);body.TextSize=15;body.TextXAlignment=Enum.TextXAlignment.Center
    local b=action(c,'Item_'..item.id,busy and 'PLEASE WAIT…' or equipped and 'EQUIPPED' or owned and 'EQUIP' or poor and 'NEED MORE COINS' or 'BUY • '..formatted(item.price),function() request(owned and 'Equip' or 'Buy',item.id) end,equipped or poor)
    b.Position=UDim2.new(0,14,1,-67);b.Size=UDim2.new(1,-28,0,51);b.TextSize=poor and 14 or 20
   end
   y=start+math.ceil(#profile.Catalog/columns)*(height+20)+5
  else
   for _,q in ipairs(profile.Quests) do
    local done=q.progress>=q.target
    local c=card(q.title:upper(),math.min(q.progress,q.target)..' / '..q.target..'   •   +'..formatted(q.reward)..' COINS',C.green,166);c.BackgroundColor3=rgb(28,76,73)
    local rail,fill=bar(c,'QuestProgress',C.green);rail.Position=UDim2.fromOffset(14,74);rail.Size=UDim2.new(1,-28,0,7);fill.Size=UDim2.fromScale(math.clamp(q.progress/q.target,0,1),1)
    action(c,'Quest_'..q.id,busy and 'PLEASE WAIT…' or q.claimed and 'CLAIMED' or done and 'CLAIM REWARD' or 'IN PROGRESS',function() request('Claim',q.id) end,q.claimed or not done)
   end
  end
 end
 return y
end
local function makeUI()
 local pg=P:WaitForChild("PlayerGui"); local old=pg:FindFirstChild("BombTagHUD"); if old then old:Destroy() end
]=])
 replace([=[
 U.Sub=text(U.Top,"Subtitle","RUN. PASS. SURVIVE.",15,54,270,12,10,C.muted)
 U.Identity=panel(U.Root,"Identity",206,66,5)
 U.Avatar=make("ImageLabel",U.Identity,{Name="Portrait",Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(44,44),BackgroundColor3=C.ink,BorderSizePixel=0,ZIndex=7}); rounded(U.Avatar,4)
 text(U.Identity,"Player",P.DisplayName:upper(),64,9,132,17,12)
 U.HealthText=text(U.Identity,"Vitals","100 / 100",64,29,132,16,11,C.muted)
 U.HealthTrack,U.HealthFill=bar(U.Identity,"Health",C.green); U.HealthTrack.Position=UDim2.fromOffset(64,52); U.HealthTrack.Size=UDim2.fromOffset(132,4)
 U.Info=panel(U.Root,"MatchInfo",202,66,5)
 U.Alive=text(U.Info,"Alive","",12,9,178,23,20,C.white,Enum.TextXAlignment.Right)
]=],[=[
 U.Sub=text(U.Top,"Subtitle","RUN. PASS. SURVIVE.",15,54,270,12,10,C.muted)
 U.Identity=panel(U.Root,"Identity",206,66,5)
 U.Avatar=make("ImageLabel",U.Identity,{Name="Portrait",Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(44,44),BackgroundColor3=C.ink,BorderSizePixel=0,ZIndex=7}); rounded(U.Avatar,22);stroke(U.Avatar,C.violet)
 text(U.Identity,"Player",P.DisplayName:upper(),64,9,132,17,12)
 U.HealthText=text(U.Identity,"Vitals","100 / 100",64,29,132,16,11,C.muted)
 U.HealthTrack,U.HealthFill=bar(U.Identity,"Health",C.green); U.HealthTrack.Position=UDim2.fromOffset(64,52); U.HealthTrack.Size=UDim2.fromOffset(132,4)
 U.Wallet=panel(U.Root,'Wallet',206,42,6,C.gold)
 U.Wallet.BackgroundColor3=panelTones.Wallet
 local coin=frame(U.Wallet,'Coin',10,8,26,26,C.gold,8);rounded(coin,13);stroke(coin,rgb(255,241,170));text(coin,'Symbol','$',0,0,26,26,18,C.white,Enum.TextXAlignment.Center)
 U.Coins=text(U.Wallet,'Coins','— COINS',46,8,148,26,16,C.white)
 U.Info=panel(U.Root,"MatchInfo",202,66,5)
 U.Alive=text(U.Info,"Alive","",12,9,178,23,20,C.white,Enum.TextXAlignment.Right)
]=])
 replace([=[
 U.Lobby=frame(U.Root,"LobbyMenu",0,0,186,318,C.ink,10); U.Lobby.BackgroundTransparency=1
 text(U.Lobby,"Section","LOBBY",8,0,180,16,12,C.white)
 U.MenuScroll=make("ScrollingFrame",U.Lobby,{Name="MenuOptions",Position=UDim2.fromOffset(0,26),Size=UDim2.new(1,0,1,-26),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.fromOffset(0,330),ScrollBarImageColor3=C.green,ZIndex=10})
 for i,name in ipairs({"STATS","CONTROLS","HOW TO PLAY","MAPS","SETTINGS"}) do
  local titles={QUESTS='Quests',SHOP='Shop',LEADERBOARDS='Hub',STATS='Stats',MAPS='Maps',SETTINGS='Settings',CONTROLS='Controls',['HOW TO PLAY']='How to Play'}
  local b=button(U.MenuScroll,name,titles[name] or name,function() openMenu(name) end)
]=],[=[
 U.Lobby=frame(U.Root,"LobbyMenu",0,0,186,318,C.ink,10); U.Lobby.BackgroundTransparency=1
 text(U.Lobby,"Section","LOBBY",8,0,180,16,12,C.white)
 U.MenuScroll=make("ScrollingFrame",U.Lobby,{Name="MenuOptions",Position=UDim2.fromOffset(0,26),Size=UDim2.new(1,0,1,-26),BackgroundTransparency=1,ClipsDescendants=true,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.fromOffset(0,525),ScrollBarImageColor3=C.green,ZIndex=10})
 for i,name in ipairs({"QUESTS","SHOP","LEADERBOARDS","STATS","MAPS","SETTINGS","CONTROLS","HOW TO PLAY"}) do
  local titles={QUESTS='Quests',SHOP='Shop',LEADERBOARDS='Hub',STATS='Stats',MAPS='Maps',SETTINGS='Settings',CONTROLS='Controls',['HOW TO PLAY']='How to Play'}
  local b=button(U.MenuScroll,name,titles[name] or name,function() openMenu(name) end)
]=])
 replace([=[
 U.NoticeTitle=text(U.Notice,"Title","",14,8,334,17,12,C.green,Enum.TextXAlignment.Center)
 U.NoticeBody=text(U.Notice,"Message","",14,31,334,17,12,C.white,Enum.TextXAlignment.Center)
 U.Count=frame(U.Root,"Countdown",0,0,220,168,C.ink,40); U.Count.BackgroundTransparency=1
 U.CountText=text(U.Count,"Number","",0,0,220,133,112,C.white,Enum.TextXAlignment.Center); U.CountText.Font=Enum.Font.GothamBlack
 U.CountLabel=text(U.Count,"Caption","GET READY TO RUN",0,145,220,20,12,C.green,Enum.TextXAlignment.Center)
]=],[=[
 U.NoticeTitle=text(U.Notice,"Title","",14,8,334,17,12,C.green,Enum.TextXAlignment.Center)
 U.NoticeBody=text(U.Notice,"Message","",14,31,334,17,12,C.white,Enum.TextXAlignment.Center)
 U.Count=frame(U.Root,"Countdown",0,0,220,168,C.ink,40); U.Count.BackgroundColor3=rgb(102,61,170);U.Count.BackgroundTransparency=.08;rounded(U.Count,24);stroke(U.Count,C.gold);gloss(U.Count)
 U.CountText=text(U.Count,"Number","",0,0,220,133,112,C.white,Enum.TextXAlignment.Center); U.CountText.Font=Enum.Font.GothamBlack
 U.CountLabel=text(U.Count,"Caption","GET READY TO RUN",0,145,220,20,12,C.green,Enum.TextXAlignment.Center)
]=])
 replace([=[
 end,true); U.Close.Position=UDim2.new(1,-60,0,16); U.Close.Size=UDim2.fromOffset(44,44)
 frame(U.Window,"Divider",22,91,1,1,C.line,53).Size=UDim2.new(1,-44,0,1)
 U.Body=make("ScrollingFrame",U.Window,{Position=UDim2.fromOffset(22,107),Size=UDim2.new(1,-44,1,-125),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.green,CanvasSize=UDim2.fromOffset(0,0),ZIndex=53})
 U.Vote=make("ScrollingFrame",U.Window,{Name="VoteCards",Position=UDim2.fromOffset(22,107),Size=UDim2.fromOffset(616,327),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=C.green,CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=53})
 U.Cards={}
 for i=1,3 do
]=],[=[
 end,true); U.Close.Position=UDim2.new(1,-60,0,16); U.Close.Size=UDim2.fromOffset(44,44)
 frame(U.Window,"Divider",22,91,1,1,C.line,53).Size=UDim2.new(1,-44,0,1)
 U.Navigation=frame(U.Window,'Navigation',22,89,1,64,C.white,54);U.Navigation.BackgroundTransparency=1;U.Navigation.Size=UDim2.new(1,-44,0,64)
 for index,entry in ipairs({{'Hub','LEADERBOARDS'},{'Home',false},{'SHOP','SHOP'}}) do
  local b=button(U.Navigation,'Nav'..entry[1],entry[1]=='SHOP' and 'Shop' or entry[1],function() if entry[2] then openMenu(entry[2]) else menu=nil;refresh() end end)
  b.BackgroundColor3=tones[entry[1]];b.Size=UDim2.new(1/3,-10,1,0);b.Position=UDim2.new((index-1)/3,5,0,0);b.TextSize=26
  local icon=emblem(b,entry[1],44);icon.Position=UDim2.fromOffset(9,6)
  b.ButtonCaption.Position=UDim2.fromOffset(59,-2);b.ButtonCaption.Size=UDim2.new(1,-65,1,0)
 end
 U.Body=make("ScrollingFrame",U.Window,{Position=UDim2.fromOffset(22,107),Size=UDim2.new(1,-44,1,-125),BackgroundTransparency=1,ClipsDescendants=true,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.green,CanvasSize=UDim2.fromOffset(0,0),ZIndex=53})
 U.Vote=make("ScrollingFrame",U.Window,{Name="VoteCards",Position=UDim2.fromOffset(22,107),Size=UDim2.fromOffset(616,327),BackgroundTransparency=1,ClipsDescendants=true,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=C.green,CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=53})
 U.Cards={}
 for i=1,3 do
]=])
 replace([=[
 local width=math.max(200,U.Window.Size.X.Offset-44); local y=0
 local function block(title,body,color,height)
  local card=panel(U.Body,title,width-6,height or 100,54)
  card.Position=UDim2.fromOffset(0,y); card.Size=UDim2.new(1,-6,0,height or 100)
  text(card,"Heading",title,14,10,width-34,22,15,color or C.green)
  local label=text(card,"Description",body,14,38,width-34,(height or 100)-48,13,C.muted)
  label.TextWrapped=true; label.TextTruncate=Enum.TextTruncate.None; label.TextYAlignment=Enum.TextYAlignment.Top
  y+=(height or 100)+12
 end
 if U.Mode=="result" then
  block("LAST PLAYER STANDING",winner~="" and winner or "No survivor this round.",C.green,130)
  local title=U.Body:GetChildren()[1]; local label=title and title:FindFirstChild("Description")
]=],[=[
 local width=math.max(200,U.Window.Size.X.Offset-44); local y=0
 local function block(title,body,color,height)
  local card=panel(U.Body,title,width-6,height or 100,54,color)
  card.Position=UDim2.fromOffset(0,y); card.Size=UDim2.new(1,-6,0,height or 100)
  text(card,"Heading",title,14,10,width-34,22,15,color or C.green).Size=UDim2.new(1,-28,0,22)
  local label=text(card,"Description",body,14,38,width-34,(height or 100)-48,13,C.muted)
  label.Size=UDim2.new(1,-28,0,(height or 100)-48);label.TextWrapped=true; label.TextTruncate=Enum.TextTruncate.None; label.TextYAlignment=Enum.TextYAlignment.Top
  y+=(height or 100)+12
 end
 if menu=='SHOP' or menu=='QUESTS' or menu=='LEADERBOARDS' then
  y=economyPage(block,width)
 elseif U.Mode=="result" then
  block("LAST PLAYER STANDING",winner~="" and winner or "No survivor this round.",C.green,130)
  local title=U.Body:GetChildren()[1]; local label=title and title:FindFirstChild("Description")
]=])
 replace([=[
openMenu=function(name)
 if inRound() then return end
 menu=menu==name and nil or name; refresh()
 if menu and Input:GetLastInputType().Name:find("Gamepad") then Gui.SelectedObject=U.Close end
end
]=],[=[
openMenu=function(name)
 if inRound() then return end
 menu=menu==name and nil or name;ecoMessage=nil;refresh()
 if menu and Input:GetLastInputType().Name:find("Gamepad") then Gui.SelectedObject=U.Close end
end
]=])
 replace([=[
 U.DashState.Position=UDim2.new(1,-124,0,10); U.DashTitle.Size=UDim2.new(1,-142,0,22); U.Immunity.Position=UDim2.new(1,-159,0,36)
 for i,seg in ipairs(U.Segments) do seg.Position=UDim2.fromOffset(14+(i-1)*(dashW-28)/12,62); seg.Size=UDim2.fromOffset((dashW-28)/12-3,4) end
 local top=compact and 96 or 102; local available=math.max(78,h-top-112); local menuH=math.min(318,available)
 U.Lobby.Size=UDim2.fromOffset(w<420 and 180 or 214,menuH); align(U.Lobby,12,math.max(top,(h-menuH)/2-16))
 U.LobbyFooter.Size=UDim2.fromOffset(math.min(246,w-24),81); align(U.LobbyFooter,12,h-12,0,1)
 U.AFK.Size=UDim2.new(1,-20,0,44); align(U.VoteReopen,w-12,h-12,1,1)
 local nw=math.min(362,w-24); U.Notice.Size=UDim2.fromOffset(nw,62); align(U.Notice,w/2,compact and 180 or 100,.5,0)
 U.NoticeTitle.Size=UDim2.new(1,-28,0,17); U.NoticeBody.Size=UDim2.new(1,-28,0,17)
 align(U.Count,w/2,h*.45,.5,.5)
]=],[=[
 U.DashState.Position=UDim2.new(1,-124,0,10); U.DashTitle.Size=UDim2.new(1,-142,0,22); U.Immunity.Position=UDim2.new(1,-159,0,36)
 for i,seg in ipairs(U.Segments) do seg.Position=UDim2.fromOffset(14+(i-1)*(dashW-28)/12,62); seg.Size=UDim2.fromOffset((dashW-28)/12-3,4) end
 -- Keep desktop's upper-right clear for Roblox's native player list.
 U.Tight=compact or landscape
 U.Wallet.Size=UDim2.fromOffset(landscape and 128 or identityWidth,42)
 U.WalletLobbyY=compact and 96 or 12;align(U.Wallet,12,U.WalletLobbyY)
 U.Coins.TextSize=U.Tight and 11 or 15;U.Coins.Size=UDim2.new(1,-54,0,26)
 if not compact and not landscape then align(U.Info,w/2,94,.5,0);align(U.Bomb,12,140) end
 local top=compact and 174 or 102; local available=math.max(78,h-top-112); local menuH=math.min(318,available)
 U.Lobby.Size=UDim2.fromOffset(w<420 and 180 or 214,menuH); align(U.Lobby,12,math.max(top,(h-menuH)/2-16))
 U.LobbyFooter.Size=UDim2.fromOffset(math.min(246,w-24),81); align(U.LobbyFooter,landscape and w-12 or 12,h-12,landscape and 1 or 0,1)
 U.AFK.Size=UDim2.new(1,-20,0,44); align(U.VoteReopen,w-12,h-12,1,1)
 local nw=math.min(362,w-24); U.Notice.Size=UDim2.fromOffset(nw,62); align(U.Notice,w/2,compact and math.min(324,h-165) or 180,.5,0)
 U.NoticeTitle.Size=UDim2.new(1,-28,0,17); U.NoticeBody.Size=UDim2.new(1,-28,0,17)
 align(U.Count,w/2,h*.45,.5,.5)
]=])
 replace([=[
  if mode and mode~="vote" then buildPage() end
 end
 U.Shade.Visible=mode~=nil; U.WindowTitle.Text=mode=="vote" and (voteOpen and "CHOOSE YOUR ARENA" or "ARENA SELECTED") or (mode=="result" and "ROUND RESULTS" or menu or "")
 U.WindowBrand.Text=mode=="vote" and "N E X T  M A T C H  /  M A P  V O T E" or "H U S S  A  B O M B"
]=],[=[
  if mode and mode~="vote" then buildPage() end
 end
 local tight=U.Window.Size.Y.Offset<340;local tabs=mode=='menu' and not tight
 U.Navigation.Visible=tabs
 U.WindowBrand.Visible=not tight;U.WindowTitle.Position=UDim2.fromOffset(22,tight and 8 or 35);U.WindowTitle.TextSize=tight and 25 or 34;U.Close.Position=UDim2.new(1,-60,0,tight and 8 or 16)
 U.Window.Divider.Position=UDim2.fromOffset(22,tight and 52 or 81)
 U.Body.Position=UDim2.fromOffset(22,tight and 57 or tabs and 170 or 107);U.Body.Size=UDim2.new(1,-44,1,tight and -67 or tabs and -190 or -125)
 local small=U.Window.Size.X.Offset<520
 for _,b in ipairs(U.Navigation:GetChildren()) do if b:IsA('TextButton') then
  b.Illustration.Visible=not small;b.ButtonCaption.Position=UDim2.fromOffset(small and 5 or 59,-2);b.ButtonCaption.Size=UDim2.new(1,small and -10 or -65,1,0);b.TextSize=small and 17 or 26
 end end
 U.Shade.Visible=mode~=nil; U.WindowTitle.Text=mode=="vote" and (voteOpen and "CHOOSE YOUR ARENA" or "ARENA SELECTED") or (mode=="result" and "ROUND RESULTS" or menu or "")
 U.WindowBrand.Text=mode=="vote" and "N E X T  M A T C H  /  M A P  V O T E" or "H U S S  A  B O M B"
]=])
 replace([=[
 U.VoteReopen.Visible=voteOpen and voteDismissed and not playing and not afk and not mode
 U.Identity.Visible=playing and not mode and phase~="RESULT"
 U.Info.Visible=not mode; U.Top.Visible=not mode
 U.Dash.Visible=playing and not mode and phase~="RESULT"
]=],[=[
 U.VoteReopen.Visible=voteOpen and voteDismissed and not playing and not afk and not mode
 U.Identity.Visible=playing and not mode and phase~="RESULT"
 U.Wallet.Visible=not mode and (not playing or not U.Tight);U.Wallet.Position=UDim2.fromOffset(12,playing and 86 or U.WalletLobbyY);local coins=profile and profile.ready and numberStat("Coins") or nil;U.Coins.Text=coins~=nil and (coins>=1000000 and string.format("%.1f%s",coins/(coins>=1000000000 and 1000000000 or 1000000),coins>=1000000000 and "B" or "M") or formatted(coins)).." COINS" or (profile and profile.mode=="unavailable" and "UNAVAILABLE" or "LOADING…")
 U.Info.Visible=not mode; U.Top.Visible=not mode
 U.Dash.Visible=playing and not mode and phase~="RESULT"
]=])
 replace([=[
 U.Sub.Text=afk and "AFK / MATCHMAKING PAUSED" or (phase=="FINAL_DUEL" and "ONE FUSE. TWO PLAYERS." or "RUN. PASS. SURVIVE.")
 U.Alive.Text=tostring(alive or #Players:GetPlayers())..(alive and "  ALIVE" or "  PLAYERS")
 U.Map.Text=mapName():upper()
 local wins=numberStat("Wins"); U.Wins.Text=wins and formatted(wins).."  WINS" or "READY FOR YOUR NEXT ROUND"
 U.AFK.Text=afk and "RETURN TO PLAY" or "GO AFK"
]=],[=[
 U.Sub.Text=afk and "AFK / MATCHMAKING PAUSED" or (phase=="FINAL_DUEL" and "ONE FUSE. TWO PLAYERS." or "RUN. PASS. SURVIVE.")
 U.Alive.Text=tostring(alive or #Players:GetPlayers())..(alive and "  ALIVE" or "  PLAYERS")
 U.Map.Text=playing and U.Tight and U.Coins.Text or mapName():upper()
 local wins=numberStat("Wins"); U.Wins.Text=wins and formatted(wins).."  WINS" or "READY FOR YOUR NEXT ROUND"
 U.AFK.Text=afk and "RETURN TO PLAY" or "GO AFK"
]=])
 replace([=[
 previewFolder=nil; voteRemote=nil; afkRemote=nil; voteLink=nil
 options={}; counts={}; selection=nil; tickTime=0; statTime=0; phase="WAITING"; phaseAt=time(); duration=0; alive=nil; menu=nil; pageName=nil; voteOpen=false; voteResultUntil=0; voteDismissed=false; bomb=false; owner=0; resultDismissed=false; countdown=nil; noticeUntil=0
 makeUI(); layout()
 connect(Remotes.Get("RoundState").OnClientEvent,onRound); connect(Remotes.Get("BombState").OnClientEvent,onBomb)
 local function attach(child)
  if child.Name=="BombTagVoteV6" and child:IsA("RemoteEvent") and child~=voteRemote then
   if voteLink then voteLink:Disconnect() end
   voteRemote=child; voteLink=connect(child.OnClientEvent,onVote); child:FireServer("Sync")
]=],[=[
 previewFolder=nil; voteRemote=nil; afkRemote=nil; voteLink=nil
 options={}; counts={}; selection=nil; tickTime=0; statTime=0; phase="WAITING"; phaseAt=time(); duration=0; alive=nil; menu=nil; pageName=nil; voteOpen=false; voteResultUntil=0; voteDismissed=false; bomb=false; owner=0; resultDismissed=false; countdown=nil; noticeUntil=0
 profile=nil;board=nil;busy=nil;economy=nil;ecoLink=nil;ecoMessage=nil
 makeUI(); layout()
 connect(Players.PlayerAdded,watchPlayer)
 connect(Players.PlayerRemoving,function(p) if rosterLinks[p] then clear(rosterLinks[p]);rosterLinks[p]=nil end;task.defer(function() if started and epoch==session then ecoRefresh() end end) end)
 for _,p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
 connect(Remotes.Get("RoundState").OnClientEvent,onRound); connect(Remotes.Get("BombState").OnClientEvent,onBomb)
 local function attach(child)
  if child.Name=='HussEconomyV9' and child:IsA('RemoteEvent') and child~=economy then
   if ecoLink then ecoLink:Disconnect() end;economy=child;ecoLink=connect(child.OnClientEvent,receive);busy=nil;request('Sync')
  elseif child.Name=="BombTagVoteV6" and child:IsA("RemoteEvent") and child~=voteRemote then
   if voteLink then voteLink:Disconnect() end
   voteRemote=child; voteLink=connect(child.OnClientEvent,onVote); child:FireServer("Sync")
]=])
 replace([=[
 connect(RS.ChildAdded,attach)
 connect(RS.ChildRemoved,function(child)
  if child==voteRemote then voteRemote=nil; if voteLink then voteLink:Disconnect(); voteLink=nil end end
  if child==afkRemote then afkRemote=nil end
]=],[=[
 connect(RS.ChildAdded,attach)
 connect(RS.ChildRemoved,function(child)
  if child==economy then economy=nil;profile=nil;busy=nil;if ecoLink then ecoLink:Disconnect();ecoLink=nil end;ecoRefresh() end
  if child==voteRemote then voteRemote=nil; if voteLink then voteLink:Disconnect(); voteLink=nil end end
  if child==afkRemote then afkRemote=nil end
]=])
 replace([=[
 if not started then return end
 started=false; epoch+=1; clear(links); clear(charLinks); clear(pageLinks)
 for _,t in pairs(tweens) do t:Cancel() end; table.clear(tweens)
 for o,enabled in pairs(hidden) do if o.Parent then o.Enabled=enabled end end; table.clear(hidden)
]=],[=[
 if not started then return end
 started=false; epoch+=1; clear(links); clear(charLinks); clear(pageLinks)
 for _,bucket in pairs(rosterLinks) do clear(bucket) end;table.clear(rosterLinks)
 economy=nil;ecoLink=nil;profile=nil;board=nil;busy=nil
 for _,t in pairs(tweens) do t:Cancel() end; table.clear(tweens)
 for o,enabled in pairs(hidden) do if o.Parent then o.Enabled=enabled end end; table.clear(hidden)
]=])
 assert(A.IdentifyHUD(source)=='V10-on-V9','HUD economy adaptation did not produce a verified version. Nothing changed.')
 return source
end
local patchHudV11=(function()
-- V11 retains the reference-style HUD and adds bounded, server-backed collections.
return function(source)
 local marker='-- HussCollectionHudV11'
 assert(source:find('-- HussReferenceHudV10',1,true) and source:find('-- HussEconomyHudV9',1,true),'Install V9 economy and V10 HUD before V11. Nothing changed.')
 if source:find(marker,1,true) then assert(source:find('local function collectionPage',1,true),'Incomplete V11 HUD.');return source end
 local function replace(old,new)
  local a,b=source:find(old,1,true);assert(a and not source:find(old,b+1,true),'Unexpected HUD section: '..old:sub(1,42));source=source:sub(1,a-1)..new..source:sub(b+1)
 end
 local function section(first,last,value)
  local a=source:find(first,1,true);local b=a and source:find(last,a+1,true);assert(a and b,'HUD collection section changed.');source=source:sub(1,a-1)..value..'\n'..source:sub(b)
 end
 replace('local rosterLinks={}',[[-- HussCollectionHudV11
local rosterLinks={}
local category,collectionPageNumber,cosmetics='Bombs',1,nil
local categories={'Bombs','Trails','Titles','Emotes'}
local defaults={Bombs='bomb_classic',Trails='default',Titles='title_rookie',Emotes='emote_wave'}
local categoryColors={Bombs=rgb(255,164,38),Trails=rgb(81,225,255),Titles=rgb(202,128,255),Emotes=rgb(255,111,184)}
tones.INDEX=rgb(55,155,239)
local emoteAt=-math.huge]])
 replace("(menu=='SHOP' or menu=='QUESTS' or menu=='LEADERBOARDS')","(menu=='SHOP' or menu=='INDEX' or menu=='QUESTS' or menu=='LEADERBOARDS' or menu=='STATS')")
 replace("Equipped=cleanText(data.Equipped),Catalog={}","Equipped=cleanText(data.Equipped),EquippedByCategory={},Catalog={}")
 replace("  if type(data.Owned)=='table'",[[  for _,name in ipairs(categories) do p.EquippedByCategory[name]=type(data.EquippedByCategory)=='table' and cleanText(data.EquippedByCategory[name],defaults[name]) or (name=='Trails' and p.Equipped or defaults[name]) end
  if type(data.Owned)=='table']])
 replace('if i>32 then break end','if i>100 then break end')
 replace("if i>12 then break end\n   if type(item)","if i>100 then break end\n   if type(item)")
 replace("name=cleanText(item.name,'Trail'),price=amount(item.price)","name=cleanText(item.name,'Cosmetic'),category=defaults[item.category] and item.category or 'Trails',description=cleanText(item.description,'Equip this cosmetic to make it yours.'),rarity=cleanText(item.rarity,'Common'),style=cleanText(item.style),price=amount(item.price)")
 replace("local function economyPage(block,width)",[[local function playEmote(id)
 if inRound() or not cosmetics or not profile or not profile.ready or not profile.Owned[id] or profile.EquippedByCategory.Emotes~=id then return end
 if P:GetAttribute('HussEmotePlaying')==id then cosmetics:FireServer('StopEmote')
 elseif time()-emoteAt>=1.3 then emoteAt=time();cosmetics:FireServer('Emote',id) end
end
local function collectionPage(width,y)
 local ownedCount,total=0,0;local list={}
 for _,item in ipairs(profile.Catalog) do if item.category==category then table.insert(list,item);total+=1;if profile.Owned[item.id] then ownedCount+=1 end end end
 local indexMode=menu=='INDEX';local cols=width>=810 and 3 or width>=520 and 2 or 1
 local pageSize=6;local pageCount=math.max(1,math.ceil(total/pageSize));collectionPageNumber=math.clamp(collectionPageNumber,1,pageCount)
 local h=text(U.Body,'CollectionHeading',category:upper()..'  '..ownedCount..'/'..total,5,y,width-124,34,23,categoryColors[category]);h.TextSize=width<350 and 18 or 23
 local switch=button(U.Body,'CollectionSwitch',indexMode and 'SHOP' or 'INDEX',function() menu=indexMode and 'SHOP' or 'INDEX';pageName=nil;refresh() end,false,pageLinks)
 switch.Position=UDim2.new(1,-110,0,y);switch.Size=UDim2.fromOffset(102,38);y+=42
 local tabCols=width<520 and 2 or 4
 for i,name in ipairs(categories) do
  local b=button(U.Body,'Category_'..name,name:upper(),function() category=name;collectionPageNumber=1;ecoMessage=nil;buildPage() end,false,pageLinks)
  b.Position=UDim2.new((i-1)%tabCols/tabCols,5,0,y+math.floor((i-1)/tabCols)*53);b.Size=UDim2.new(1/tabCols,-14,0,44);b.TextSize=width<350 and 13 or 16;b:SetAttribute('HussSelected',category==name)
 end
 y+=math.ceil(4/tabCols)*53+4
 local caption=indexMode and 'Every collectible. Your owned items are marked.' or category=='Emotes' and 'Equip an emote, then stand still in the lobby to play it.' or 'Earn coins in multiplayer. Choose your own look.'
 text(U.Body,'CollectionDescription',caption,6,y,width-18,32,width<350 and 11 or 14,C.muted).TextWrapped=true;y+=40
 local start=y;local height=indexMode and 290 or 340;local count=0;local coins=numberStat('Coins')
 for i=(collectionPageNumber-1)*pageSize+1,math.min(collectionPageNumber*pageSize,total) do
  local item=list[i];local owned=profile.Owned[item.id]==true;local equipped=profile.EquippedByCategory[category]==item.id;local poor=not owned and (coins==nil or coins<item.price)
  local accent=item.color:Lerp(C.white,item.color.R+item.color.G+item.color.B<1 and .55 or .2)
  local c=panel(U.Body,'Collectible_'..item.id,250,height,54,accent);c.Position=UDim2.new(count%cols/cols,7,0,start+math.floor(count/cols)*(height+20));c.Size=UDim2.new(1/cols,-16,0,height);count+=1
  c.BackgroundColor3=item.color:Lerp(C.ink,.86);c.Gloss:Destroy();c.InnerRim:FindFirstChildOfClass('UIStroke').Thickness=4
  local g=c:FindFirstChildOfClass('UIGradient');if g then g.Color=ColorSequence.new(rgb(60,67,70),C.white) end
  local art=emblem(c,category,indexMode and 88 or 102,item.color);art.AnchorPoint=Vector2.new(.5,0);art.Position=UDim2.new(.5,0,0,10)
  local nameY=indexMode and 99 or 112
  local title=text(c,'ItemName',item.name:upper(),9,nameY,240,48,23,accent,Enum.TextXAlignment.Center);title.Size=UDim2.new(1,-18,0,48);title.TextWrapped=true
  local rarity=text(c,'Rarity',item.rarity:upper()..' • '..(owned and (equipped and 'EQUIPPED' or 'OWNED') or 'LOCKED'),9,nameY+50,240,22,12,owned and C.green or C.gold,Enum.TextXAlignment.Center);rarity.Size=UDim2.new(1,-18,0,22)
  local description=text(c,'ItemDescription',item.description,14,nameY+76,228,indexMode and 46 or 44,12,C.white,Enum.TextXAlignment.Center);description.Size=UDim2.new(1,-28,0,indexMode and 46 or 44);description.TextWrapped=true
  if indexMode then
   local price=text(c,'Price',item.price==0 and 'FREE STARTER' or formatted(item.price)..' COINS',12,height-41,230,27,18,C.gold,Enum.TextXAlignment.Center);price.Size=UDim2.new(1,-24,0,27)
  else
   local caption=busy and 'PLEASE WAIT…' or equipped and 'EQUIPPED' or owned and 'EQUIP' or poor and 'NEED '..formatted(item.price)..' COINS' or item.price==0 and 'UNLOCK FREE' or 'BUY • '..formatted(item.price)
   local b=button(c,'Item_'..item.id,caption,function() request(owned and 'Equip' or 'Buy',item.id) end,false,pageLinks)
   b.Position=UDim2.new(0,14,1,-106);b.Size=UDim2.new(1,-28,0,47);b.TextSize=poor and 13 or 18;b:SetAttribute('HussDisabled',busy~=nil or equipped or poor)
   if category=='Emotes' then
    local use=button(c,'Play_'..item.id,P:GetAttribute('HussEmotePlaying')==item.id and 'STOP EMOTE' or equipped and 'PLAY EMOTE' or 'EQUIP TO PLAY',function() playEmote(item.id) end,false,pageLinks);use.Position=UDim2.new(0,14,1,-51);use.Size=UDim2.new(1,-28,0,44);use.TextSize=13;use:SetAttribute('HussDisabled',not owned or not equipped or not cosmetics or inRound())
   else local price=text(c,'Price',owned and 'COSMETIC • NO STAT ADVANTAGE' or formatted(item.price)..' COINS',14,height-40,240,27,11,C.gold,Enum.TextXAlignment.Center);price.Size=UDim2.new(1,-28,0,27) end
  end
 end
 y=start+math.ceil(count/cols)*(height+20)
 if total==0 then text(U.Body,'EmptyCollection','The collection is loading. Refresh your player record.',5,y,width-16,60,16,C.gold).TextWrapped=true;y+=75 end
 local function pageButton(name,caption,delta,x)
  local b=button(U.Body,name,caption,function() collectionPageNumber=math.clamp(collectionPageNumber+delta,1,pageCount);buildPage() end,false,pageLinks);b.Position=UDim2.new(x,5,0,y);b.Size=UDim2.new(.5,-14,0,46);b:SetAttribute('HussDisabled',delta<0 and collectionPageNumber==1 or delta>0 and collectionPageNumber==pageCount)
 end
 pageButton('CollectionPrevious','‹ PREVIOUS',-1,0);pageButton('CollectionNext','NEXT ›',1,.5);y+=58
 text(U.Body,'CollectionPage','PAGE '..collectionPageNumber..' / '..pageCount..' • '..total..' '..category:upper(),5,y,width-16,26,14,C.muted,Enum.TextXAlignment.Center)
 return y+40
end
local function economyPage(block,width)]])
 replace("  card(menu=='SHOP' and 'TRAIL COLLECTION' or 'DAILY QUESTS',menu=='SHOP' and 'Your color. Your escape. Earn coins, unlock a trail, make it yours.' or 'Complete these goals, then claim your coins. Quests reset at 00:00 UTC.',C.gold,menu=='SHOP' and 82 or 108)","  if menu=='QUESTS' then card('DAILY QUESTS','Complete these goals, then claim your coins. Quests reset at 00:00 UTC.',C.gold,108) end")
 section("  if menu=='SHOP' then\n   local columns=", "  else\n   for _,q in ipairs(profile.Quests)","  if menu=='SHOP' or menu=='INDEX' then\n   y=collectionPage(width,y)")
 replace("if menu=='SHOP' or menu=='QUESTS' or menu=='LEADERBOARDS' then","if menu=='SHOP' or menu=='INDEX' or menu=='QUESTS' or menu=='LEADERBOARDS' then")
 replace('"QUESTS","SHOP","LEADERBOARDS","STATS"','"QUESTS","SHOP","INDEX","LEADERBOARDS","STATS"')
 replace("SHOP='Shop',LEADERBOARDS='Hub'","SHOP='Shop',INDEX='Index',LEADERBOARDS='Hub'")
 replace('CanvasSize=UDim2.fromOffset(0,525)','CanvasSize=UDim2.fromOffset(0,590)')
 section(' elseif menu=="STATS" then',' elseif menu=="CONTROLS" then',[[ elseif menu=="STATS" then
  local cols=width>=520 and 2 or 1;local i=0
  for _,entry in ipairs({{'Wins','VICTORIES',C.gold},{'Coins','COINS',C.green},{'Kills','BOMB KILLS',C.red},{'FinalStands','FINAL STANDS',C.violet},{'GamesPlayed','ROUNDS PLAYED',C.cyan},{'Passes','BOMB PASSES',C.gold}}) do
   local value=numberStat(entry[1]);local c=panel(U.Body,'Stat_'..entry[1],200,132,54,entry[3]);c.Size=UDim2.new(1/cols,-16,0,132);c.Position=UDim2.new(i%cols/cols,7,0,math.floor(i/cols)*148);i+=1
   text(c,'StatLabel',entry[2],14,12,200,26,16,entry[3]).Size=UDim2.new(1,-28,0,26)
   text(c,'StatValue',value~=nil and formatted(value) or '—',14,47,200,61,36,C.white).Size=UDim2.new(1,-28,0,61)
  end
  y=math.ceil(i/cols)*148
  block('PLAY FOR THE FINISH','Final Stand: reach the last two players. Bomb Kill: your last pass leaves another player holding the bomb when it explodes. Solo practice does not award stats.',C.gold,130)]] )
 replace(" if kind=='SHOP' then",[[ if kind=='Bombs' then
  part('Fuse',53,7,11,35,rgb(244,198,100),4,-24);part('Spark',59,4,19,19,C.gold,3,45)
  part('BombBody',16,27,70,65,bright,32);part('BombShine',30,40,17,10,bright:Lerp(C.white,.8),6,-30,false)
  part('Band',18,62,66,12,bright:Lerp(C.ink,.5),4,0,false)
 elseif kind=='Emotes' then
  part('Head',39,6,24,24,bright,14);part('Body',38,36,26,31,bright,9)
  part('LeftArm',12,34,36,12,bright,6,-30);part('RightArm',59,28,36,12,bright,6,-45)
  part('LeftLeg',27,64,14,29,bright,6,23);part('RightLeg',58,64,14,29,bright,6,-23)
 elseif kind=='Titles' or kind=='INDEX' then
  part('Badge',15,24,70,51,bright,8);part('Ribbon',29,64,15,29,bright:Lerp(C.ink,.25),3,15);part('Ribbon2',57,64,15,29,bright:Lerp(C.ink,.25),3,-15)
  part('Star',38,31,26,26,C.gold,3,45);part('StarCenter',41,34,20,20,C.white,3,0,false)
 elseif kind=='SHOP' then]])
 replace("formatted(stat(p,'Wins'))..' WINS   •   '..formatted(stat(p,'Coins'))..' COINS',p==P and C.gold or C.white,86)","formatted(stat(p,'Wins'))..' WINS   •   '..formatted(stat(p,'Coins'))..' COINS\\n'..formatted(stat(p,'Kills'))..' KILLS   •   '..formatted(stat(p,'FinalStands'))..' FINAL STANDS',p==P and C.gold or C.white,100)")
 replace('local ww=math.min(940,w-24);local wh=math.min(w<540 and 650 or 620,h-24)','local ww=math.min(1040,w-24);local wh=math.min(w<540 and 690 or 680,h-24)')
 replace('local function update() if player==P then U.Identity.Player.Text=player.DisplayName:upper() end;ecoRefresh() end','local function update() if player==P then U.Identity.Player.Text=player.DisplayName:upper() end;ecoRefresh() end\n if player==P then for _,key in ipairs({"GamesPlayed","Passes","HussEmotePlaying"}) do connect(player:GetAttributeChangedSignal(key),update,bucket) end end')
 replace('if statTime>=1 then statTime=0; if menu=="STATS" and U.Mode=="menu" then local pos=U.Body.CanvasPosition; buildPage(); U.Body.CanvasPosition=pos end end','if statTime>=1 then statTime=0 end')
 replace(' U.Bomb.Visible=bomb and not mode and (phase=="ROUND" or phase=="FINAL_DUEL")',' U.Bomb.Visible=bomb and not mode and (phase=="ROUND" or phase=="FINAL_DUEL" or phase=="PRACTICE")')
 replace('alive=(phase=="ROUND" or phase=="FINAL_DUEL") and','alive=(phase=="ROUND" or phase=="FINAL_DUEL" or phase=="PRACTICE") and')
 replace('  if child.Name==\'HussEconomyV9\'',[[  if child.Name=='HussCosmeticsV11' and child:IsA('RemoteEvent') then cosmetics=child;ecoRefresh()
  elseif child.Name=='HussEconomyV9']])
 replace('  if child==economy then', '  if child==cosmetics then cosmetics=nil;ecoRefresh() end\n  if child==economy then')
 replace(' profile=nil;board=nil;busy=nil;economy=nil;ecoLink=nil;ecoMessage=nil',' profile=nil;board=nil;busy=nil;economy=nil;ecoLink=nil;ecoMessage=nil;cosmetics=nil;category="Bombs";collectionPageNumber=1')
 replace(' connect(Players.PlayerAdded,watchPlayer)',[[ connect(game:GetService('ProximityPromptService').PromptTriggered,function(prompt,player)
  local chosen=prompt:GetAttribute('HussShopCategory')
  local part=prompt.Parent;local root=P.Character and P.Character:FindFirstChild('HumanoidRootPart')
  if player==P and not inRound() and defaults[chosen] and prompt.Enabled and part and part:IsA('BasePart') and part:IsDescendantOf(workspace) and root and (root.Position-part.Position).Magnitude<=prompt.MaxActivationDistance+3 then
   category=chosen;collectionPageNumber=1;menu='SHOP';pageName=nil;ecoMessage=nil;refresh()
  end
 end)
 connect(Players.PlayerAdded,watchPlayer)]])
 replace(' economy=nil;ecoLink=nil;profile=nil;board=nil;busy=nil',' economy=nil;ecoLink=nil;profile=nil;board=nil;busy=nil;cosmetics=nil')
 return source
end

end)()
local patchEffectsV9=(function()
-- Server-selected shop colors apply to the existing sprint and dodge trails.
return function(source)
 local marker='-- HussTrailShopV9'
 assert(source:find('-- HussMovementEffectsV8',1,true),'Install V8 movement effects first. Nothing changed.')
 if source:find(marker,1,true) then
  assert(source:find("GetAttributeChangedSignal('HussTrailColor')",1,true),'Incomplete V9 trail update. Nothing changed.')
  return source
 end
 local function replace(old,new)
  local a,b=source:find(old,1,true)
  assert(a and not source:find(old,b+1,true),'Unexpected movement effects section. Nothing changed.')
  source=source:sub(1,a-1)..new..source:sub(b+1)
 end
 replace('local function effects(s)',[[-- HussTrailShopV9
local function palette(s)
 local color=s.p:GetAttribute('HussTrailColor')
 s.sprintColor=cyan;s.dodgeColor=gold
 if typeof(color)=='Color3' then
  s.sprintColor=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.38),color)
  s.dodgeColor=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.72),color)
 end
 for _,t in ipairs(s.trails) do t.Color=s.mode=='dodge' and s.dodgeColor or s.sprintColor end
end
local function effects(s)]])
 replace('link(h.Died,function() clear(s,true) end,s.links)',[[palette(s)
  link(p:GetAttributeChangedSignal('HussTrailColor'),function() palette(s) end,s.links)
  link(h.Died,function() clear(s,true) end,s.links)]])
 replace('t.Color=dodge and gold or cyan','t.Color=dodge and s.dodgeColor or s.sprintColor')
 return source
end

end)()
function A.HUD(source)
 local version=A.IdentifyHUD(source)
 if version=='V11' then return source,version end
 local result=canonical(source)
 if version=='V10-on-V8' then result=addEconomy(result) end
 result=patchHudV11(result)
 assert(A.IdentifyHUD(result)=='V11','HUD V11 verification failed. Nothing changed.')
 return result..'\n',version
end
function A.Effects(source)
 local version=A.IdentifyEffects(source)
 if version=='EffectsV9' then return source,version end
 local result=patchEffectsV9(canonical(source))
 assert(A.IdentifyEffects(result)=='EffectsV9','Trail palette verification failed. Nothing changed.')
 return result..'\n',version
end
return A
