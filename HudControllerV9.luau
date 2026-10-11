--!nonstrict
-- HUSS A BOMB / unified match, lobby, voting and map gallery HUD.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Run = game:GetService("RunService")
local Tween = game:GetService("TweenService")
local Input = game:GetService("UserInputService")
local Gui = game:GetService("GuiService")
local P = Players.LocalPlayer
local Remotes = require(RS.Shared.Net.Remotes)
local Config = require(RS.Shared.Config.GameConfig)
local HUD = {}
-- HussGlossV8
local rgb=Color3.fromRGB
local C={ink=rgb(13,17,43),panel=rgb(35,40,83),line=rgb(114,144,209),white=rgb(255,255,255),muted=rgb(204,217,246),green=rgb(165,255,113),red=rgb(255,108,131),gold=rgb(255,216,106),cyan=rgb(97,232,255),violet=rgb(192,150,255)}
local tones={STATS=rgb(157,96,23),CONTROLS=rgb(17,123,157),["HOW TO PLAY"]=rgb(105,63,178),MAPS=rgb(28,121,82),SETTINGS=rgb(158,58,123),Close=rgb(195,45,72),AFK=rgb(54,78,138),VoteReopen=rgb(143,88,23),Continue=rgb(28,121,82),Music=rgb(79,59,145),SoundEffects=rgb(20,108,134),Motion=rgb(105,63,178)}
tones.SHOP=rgb(151,66,160);tones.QUESTS=rgb(185,104,22);tones.LEADERBOARDS=rgb(31,111,157)
local panelTones={MatchStatus=rgb(19,79,122),Identity=rgb(69,43,126),MatchInfo=rgb(47,66,131),Bomb=rgb(108,60,30),Dodge=rgb(21,82,91),LobbyFooter=rgb(59,47,111),Notification=rgb(39,64,112)}
local U, links, charLinks, pageLinks, hidden, tweens = {},{},{},{},{},{}
local started, epoch, menu, phase, duration, phaseAt, alive = false,0,nil,"WAITING",0,0,nil
local bomb, owner, carrier, fuseEnd, fuseLength = false,0,"",0,14
local character, humanoid, dodgeAt, direction = nil,nil,-math.huge,"DODGE / WEAVE"
local winner, resultDismissed, countdown, countUntil = "",false,nil,0
local options, counts, selection, voteOpen, voteEnd, voteChosen, voteResultUntil, voteDismissed = {},{},nil,false,0,nil,0,false
local previewFolder, voteRemote, afkRemote, voteLink, pageName, mapIndex = nil,nil,nil,nil,nil,1
local lastSize, tickTime, statTime, noticeUntil = Vector2.zero,0,0,0
-- HussEconomyHudV9
local economy,ecoLink,profile,board,busy,serial=nil,nil,nil,nil,nil,0
local rosterLinks={}
local ecoMessage
local refresh, layout, openMenu, buildPage
local phases = {WAITING="WAITING FOR PLAYERS",INTERMISSION="NEXT MATCH",STARTING="GET READY",PRACTICE="PRACTICE",PRACTICE_ENDING="PLAYER JOINING",ROUND="MATCH LIVE",FINAL_DUEL="FINAL DUEL",RESULT="ROUND COMPLETE"}
local function num(v,f) return type(v)=="number" and v==v and math.abs(v)<math.huge and v or f end
local function connect(signal,fn,bucket) local c=signal:Connect(fn); table.insert(bucket or links,c); return c end
local function clear(bucket) for _,c in ipairs(bucket) do c:Disconnect() end; table.clear(bucket) end
local function make(class,parent,props)
 local o=Instance.new(class); for k,v in pairs(props or {}) do o[k]=v end; o.Parent=parent; return o
end
local function rounded(o,r) make("UICorner",o,{CornerRadius=UDim.new(0,r or 5)}) end
local function frame(parent,name,x,y,w,h,color,z)
 return make("Frame",parent,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.panel,BorderSizePixel=0,ZIndex=z or parent.ZIndex or 1})
end
local function stroke(o,color) return make("UIStroke",o,{Color=color or C.line,Thickness=2,Transparency=.12,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function text(parent,name,value,x,y,w,h,size,color,align)
 local o=make("TextLabel",parent,{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,Font=Enum.Font.GothamBlack,TextSize=size,TextColor3=color or C.white,TextStrokeColor3=C.ink,TextStrokeTransparency=.18,TextXAlignment=align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=(parent.ZIndex or 1)+2})
 return o
end
local function motion(o,goal,t)
 if tweens[o] then tweens[o]:Cancel(); tweens[o]=nil end
 if P:GetAttribute("HussReducedMotion")==true then for k,v in pairs(goal) do o[k]=v end; return end
 local a=Tween:Create(o,TweenInfo.new(t or .16,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),goal); tweens[o]=a
 local done; done=a.Completed:Connect(function() if tweens[o]==a then tweens[o]=nil end; if done then done:Disconnect() end end); a:Play()
end
local function gloss(o)
 o.ClipsDescendants=true
 make("UIGradient",o,{Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(141,156,207)),Rotation=90})
 local shine=frame(o,"Gloss",3,3,1,14,C.white,o.ZIndex+1)
 shine.Size=UDim2.new(1,-6,0,14);shine.BackgroundTransparency=.84;shine.Active=false;shine.Selectable=false;rounded(shine,7)
 local bevel=frame(o,"Bevel",3,0,1,4,C.ink,o.ZIndex+1)
 bevel.Position=UDim2.new(0,3,1,-7);bevel.Size=UDim2.new(1,-6,0,4);bevel.BackgroundTransparency=.42;bevel.Active=false;bevel.Selectable=false;rounded(bevel,2)
end
local function panel(parent,name,w,h,z,accent)
 local o=frame(parent,name,0,0,w,h,panelTones[name] or C.panel,z)
 o.BackgroundTransparency=0;rounded(o,14);local rim=stroke(o,accent or C.cyan);gloss(o)
 return o,rim
end
local function button(parent,name,caption,callback,danger,bucket)
 local tone=danger and tones.Close or tones[name] or rgb(54,76,139)
 local b=make("TextButton",parent,{Name=name,Text=caption,TextTruncate=Enum.TextTruncate.AtEnd,Size=UDim2.fromOffset(120,44),BackgroundColor3=tone,TextColor3=C.white,TextStrokeColor3=C.ink,TextStrokeTransparency=.12,Font=Enum.Font.GothamBlack,TextSize=13,AutoButtonColor=false,BorderSizePixel=0,ZIndex=(parent.ZIndex or 1)+3})
 rounded(b,10);local rim=stroke(b,danger and C.red or tone:Lerp(C.white,.56));gloss(b)
 local focused=false
 local function paint()
  local selected=b:GetAttribute("HussSelected")==true;local disabled=b:GetAttribute("HussDisabled")==true
  local color=selected and rgb(39,115,65) or (disabled and C.panel or tone)
  b.Interactable=not disabled;b.Selectable=not disabled
  motion(rim,{Color=selected and C.green or (focused and not disabled and C.white or (disabled and C.line or tone:Lerp(C.white,.56)))})
  motion(b,{BackgroundColor3=focused and not disabled and color:Lerp(C.white,.13) or color})
 end
 local function focus(on) focused=on;paint() end
 connect(b.MouseEnter,function() focus(true) end,bucket);connect(b.MouseLeave,function() focus(false) end,bucket)
 connect(b.SelectionGained,function() focus(true) end,bucket);connect(b.SelectionLost,function() focus(false) end,bucket)
 connect(b:GetAttributeChangedSignal("HussSelected"),paint,bucket);connect(b:GetAttributeChangedSignal("HussDisabled"),paint,bucket)
 connect(b.Activated,function() if b:GetAttribute("HussDisabled")~=true then callback() end end,bucket);return b
end
local function bar(parent,name,color)
 local track=frame(parent,name,12,0,100,4,C.ink,parent.ZIndex+1); rounded(track,2)
 local fill=frame(track,"Fill",0,0,100,4,color,track.ZIndex+1); fill.Size=UDim2.fromScale(1,1); rounded(fill,2)
 return track,fill
end
local function align(o,x,y,ax,ay) o.AnchorPoint=Vector2.new(ax or 0,ay or 0); o.Position=UDim2.fromOffset(x,y) end
local function numberStat(key)
 local folder=P:FindFirstChild("leaderstats"); local v=folder and folder:FindFirstChild(key)
 if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return num(v.Value) end
 return num(P:GetAttribute(key))
end
local function formatted(v) return tostring(math.floor(v)):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","") end
local function mapName() return tostring(workspace:GetAttribute("CurrentVotedMap") or Config.MapName or "ARENA") end
local function inRound() return P:GetAttribute("InRound")==true end
local function reduced() return P:GetAttribute("HussReducedMotion")==true end
local function announce(title,body,color)
 if not started then return end
 U.NoticeTitle.Text,U.NoticeBody.Text=title,body; U.NoticeTitle.TextColor3=color or C.green
 noticeUntil=time()+2.2; U.Notice.Visible=true; U.NoticeScale.Scale=reduced() and 1 or .95; motion(U.NoticeScale,{Scale=1},.2)
end
local function view(parent)
 local v=make("ViewportFrame",parent,{Name="ArenaPreview",BackgroundColor3=Color3.fromRGB(41,56,51),BorderSizePixel=0,Ambient=Color3.fromRGB(205,218,210),LightColor=Color3.fromRGB(255,240,204),LightDirection=Vector3.new(-1,-1,-.5),ZIndex=parent.ZIndex+1})
 rounded(v,4); local world=make("WorldModel",v); local camera=make("Camera",v,{FieldOfView=42}); v.CurrentCamera=camera
 return {frame=v,world=world,camera=camera,name=nil}
end
local function fit(v)
 if not v.center then return end
 local size=v.frame.AbsoluteSize; local ratio=size.X/math.max(size.Y,1)
 local angle=math.atan(math.tan(math.rad(v.camera.FieldOfView/2))*math.min(1,ratio))
 local distance=v.radius/math.max(.1,math.sin(angle))*1.12
 v.camera.CFrame=CFrame.lookAt(v.center+Vector3.new(1,.86,1).Unit*distance,v.center)
end
local function loadPreview(v,name)
 if v.name==name then fit(v); return end
 v.world:ClearAllChildren(); v.name=nil; v.center=nil
 local source=previewFolder and previewFolder:FindFirstChild(name or "")
 if not source or not source:IsA("Model") then return end
 local copy=source:Clone(); copy.Parent=v.world
 for _,o in ipairs(copy:GetDescendants()) do
  if o:IsA("LuaSourceContainer") or o:IsA("SurfaceGui") or o:IsA("BillboardGui") or o:IsA("Light") or o.Name=="Spawns" or (o:IsA("BasePart") and o.Transparency>=1) then o:Destroy() end
 end
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
  card(menu=='SHOP' and 'TRAIL COLLECTION' or 'DAILY QUESTS',menu=='SHOP' and 'Earn coins by playing. Equip a color for your sprint and weave.' or 'Complete these goals, then claim your coins. Quests reset at 00:00 UTC.',C.gold,108)
  if profile.mode=='preview' then card('STUDIO PREVIEW','Preview progress is temporary. Your live saved record is separate.',C.gold,90) end
  if menu=='SHOP' then
   local columns=width>=560 and 2 or 1;local start=y
   for index,item in ipairs(profile.Catalog) do
    local owned=profile.Owned[item.id];local equipped=profile.Equipped==item.id;local poor=not owned and (coins==nil or coins<item.price)
    local c=card(item.name:upper(),equipped and 'EQUIPPED' or owned and 'OWNED' or formatted(item.price)..' COINS',item.color,156);c.BackgroundColor3=item.color:Lerp(C.ink,.72)
    c.Size=UDim2.new(1/columns,-(columns==2 and 9 or 6),0,156);c.Position=UDim2.new((index-1)%columns/columns,0,0,start+math.floor((index-1)/columns)*168)
    local swatch=frame(c,'TrailSample',14,70,60,5,item.color,c.ZIndex+2);rounded(swatch,3)
    action(c,'Item_'..item.id,busy and 'PLEASE WAIT…' or equipped and 'EQUIPPED' or owned and 'EQUIP' or poor and 'NEED MORE COINS' or 'BUY • '..formatted(item.price),function() request(owned and 'Equip' or 'Buy',item.id) end,equipped or poor)
   end
   y=start+math.ceil(#profile.Catalog/columns)*168
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
 U.Gui=make("ScreenGui",pg,{Name="BombTagHUD",ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=160,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 U.Root=frame(U.Gui,"SafeArea",0,0,1,1,C.ink,1); U.Root.Size=UDim2.fromScale(1,1); U.Root.BackgroundTransparency=1
 U.Top=panel(U.Root,"MatchStatus",302,74,5)
 text(U.Top,"Brand","H U S S  A  B O M B",15,8,223,14,10,C.green)
 U.Phase=text(U.Top,"Phase","WAITING FOR PLAYERS",15,27,265,22,17)
 U.Timer=text(U.Top,"Timer","",230,7,56,17,13,C.green,Enum.TextXAlignment.Right)
 U.Sub=text(U.Top,"Subtitle","RUN. PASS. SURVIVE.",15,54,270,12,10,C.muted)
 U.Identity=panel(U.Root,"Identity",206,66,5)
 U.Avatar=make("ImageLabel",U.Identity,{Name="Portrait",Position=UDim2.fromOffset(10,10),Size=UDim2.fromOffset(44,44),BackgroundColor3=C.ink,BorderSizePixel=0,ZIndex=7}); rounded(U.Avatar,22);stroke(U.Avatar,C.violet)
 text(U.Identity,"Player",P.DisplayName:upper(),64,9,132,17,12)
 U.HealthText=text(U.Identity,"Vitals","100 / 100",64,29,132,16,11,C.muted)
 U.HealthTrack,U.HealthFill=bar(U.Identity,"Health",C.green); U.HealthTrack.Position=UDim2.fromOffset(64,52); U.HealthTrack.Size=UDim2.fromOffset(132,4)
 U.Wallet=panel(U.Root,'Wallet',206,42,6,C.gold)
 U.Wallet.BackgroundColor3=rgb(133,82,24)
 local coin=frame(U.Wallet,'Coin',10,8,26,26,C.gold,8);rounded(coin,13);stroke(coin,rgb(255,241,170));text(coin,'Symbol','$',0,0,26,26,18,C.white,Enum.TextXAlignment.Center)
 U.Coins=text(U.Wallet,'Coins','— COINS',46,8,148,26,16,C.white)
 U.Info=panel(U.Root,"MatchInfo",202,66,5)
 U.Alive=text(U.Info,"Alive","",12,9,178,23,20,C.white,Enum.TextXAlignment.Right)
 U.Map=text(U.Info,"Map","",12,38,178,16,11,C.green,Enum.TextXAlignment.Right)
 U.Bomb,U.BombRim=panel(U.Root,"Bomb",234,138,7,C.gold)
 U.BombCaption=text(U.Bomb,"Caption","BOMB IN PLAY",14,11,206,17,11,C.gold)
 U.BombTime=text(U.Bomb,"Fuse","00.0",12,31,164,54,43); U.BombTime.Font=Enum.Font.GothamBlack
 text(U.Bomb,"Unit","SEC",181,62,39,17,10,C.muted)
 U.Carrier=text(U.Bomb,"Carrier","",14,91,206,17,12,C.white)
 U.FuseTrack,U.FuseFill=bar(U.Bomb,"FuseRail",C.gold); U.FuseTrack.Position=UDim2.fromOffset(14,121); U.FuseTrack.Size=UDim2.fromOffset(206,5)
 U.Dash=panel(U.Root,"Dodge",358,77,6,C.green)
 U.DashTitle=text(U.Dash,"Action","DODGE / WEAVE",14,10,214,22,15)
 U.DashState=text(U.Dash,"State","READY",230,10,112,22,15,C.green,Enum.TextXAlignment.Right)
 U.DashHint=text(U.Dash,"Input","MOVE + SPACE",14,36,220,15,10,C.muted)
 U.Immunity=text(U.Dash,"Immunity","",199,36,145,15,10,C.green,Enum.TextXAlignment.Right)
 U.Segments={}; for i=1,12 do U.Segments[i]=frame(U.Dash,"Charge"..i,14+(i-1)*27.5,62,24,4,C.green,8) end
 U.Lobby=frame(U.Root,"LobbyMenu",0,0,186,318,C.ink,10); U.Lobby.BackgroundTransparency=1
 text(U.Lobby,"Section","L O B B Y  /  M E N U",3,0,180,16,10,C.gold)
 U.MenuScroll=make("ScrollingFrame",U.Lobby,{Name="MenuOptions",Position=UDim2.fromOffset(0,26),Size=UDim2.new(1,0,1,-26),BackgroundTransparency=1,ClipsDescendants=true,BorderSizePixel=0,ScrollBarThickness=2,CanvasSize=UDim2.fromOffset(0,446),ScrollBarImageColor3=C.green,ZIndex=10})
 for i,name in ipairs({"QUESTS","SHOP","LEADERBOARDS","STATS","MAPS","SETTINGS","CONTROLS","HOW TO PLAY"}) do
  local b=button(U.MenuScroll,name,name.."   ›",function() openMenu(name) end)
  b.Size=UDim2.new(1,-4,0,48); b.Position=UDim2.fromOffset(2,(i-1)*56); b.TextXAlignment=Enum.TextXAlignment.Left
  make("UIPadding",b,{PaddingLeft=UDim.new(0,13)}); frame(b,"Accent",0,13,3,22,C.white,b.ZIndex+1)
 end
 U.LobbyFooter=panel(U.Root,"LobbyFooter",246,81,6)
 U.Wins=text(U.LobbyFooter,"Record","",12,7,222,18,12,C.green)
 U.AFK=button(U.LobbyFooter,"AFK","GO AFK",function() if not inRound() and afkRemote then afkRemote:FireServer(P:GetAttribute("BombTagAFK")~=true) end end)
 U.AFK.Position=UDim2.fromOffset(10,29); U.AFK.Size=UDim2.fromOffset(226,44)
 U.VoteReopen=button(U.Root,"VoteReopen","CHOOSE A MAP",function() voteDismissed=false; menu=nil; refresh() end); U.VoteReopen.Size=UDim2.fromOffset(202,44)
 U.Notice=panel(U.Root,"Notification",362,62,35); U.NoticeScale=make("UIScale",U.Notice,{Scale=1})
 U.NoticeTitle=text(U.Notice,"Title","",14,8,334,17,12,C.green,Enum.TextXAlignment.Center)
 U.NoticeBody=text(U.Notice,"Message","",14,31,334,17,12,C.white,Enum.TextXAlignment.Center)
 U.Count=frame(U.Root,"Countdown",0,0,220,168,C.ink,40); U.Count.BackgroundColor3=rgb(102,61,170);U.Count.BackgroundTransparency=.08;rounded(U.Count,24);stroke(U.Count,C.gold);gloss(U.Count)
 U.CountText=text(U.Count,"Number","",0,0,220,133,112,C.white,Enum.TextXAlignment.Center); U.CountText.Font=Enum.Font.GothamBlack
 U.CountLabel=text(U.Count,"Caption","GET READY TO RUN",0,145,220,20,12,C.green,Enum.TextXAlignment.Center)
 U.CountScale=make("UIScale",U.Count,{Scale=1})
 U.Shade=frame(U.Root,"ModalShade",0,0,1,1,C.ink,50); U.Shade.Size=UDim2.fromScale(1,1); U.Shade.BackgroundTransparency=.32; U.Shade.Active=true
 U.Window=panel(U.Shade,"Window",660,456,51,C.green); U.WindowScale=make("UIScale",U.Window,{Scale=1})
 U.WindowBrand=text(U.Window,"Brand","H U S S  A  B O M B",22,15,440,17,11,C.green)
 U.WindowTitle=text(U.Window,"Title","",22,39,510,37,29)
 U.Close=button(U.Window,"Close","X",function()
  if U.Mode=="vote" then voteDismissed=true elseif U.Mode=="result" then resultDismissed=true else menu=nil end
  Gui.SelectedObject=nil; refresh()
 end,true); U.Close.Position=UDim2.new(1,-60,0,16); U.Close.Size=UDim2.fromOffset(44,44)
 frame(U.Window,"Divider",22,91,1,1,C.line,53).Size=UDim2.new(1,-44,0,1)
 U.Body=make("ScrollingFrame",U.Window,{Position=UDim2.fromOffset(22,107),Size=UDim2.new(1,-44,1,-125),BackgroundTransparency=1,ClipsDescendants=true,BorderSizePixel=0,ScrollBarThickness=3,ScrollBarImageColor3=C.green,CanvasSize=UDim2.fromOffset(0,0),ZIndex=53})
 U.Vote=make("ScrollingFrame",U.Window,{Name="VoteCards",Position=UDim2.fromOffset(22,107),Size=UDim2.fromOffset(616,327),BackgroundTransparency=1,ClipsDescendants=true,BorderSizePixel=0,ScrollBarThickness=2,ScrollBarImageColor3=C.green,CanvasSize=UDim2.fromOffset(0,0),ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=53})
 U.Cards={}
 for i=1,3 do
  local index=i; local b=button(U.Vote,"Map"..i,"",function()
   if voteOpen and workspace:GetServerTimeNow()<voteEnd and not inRound() and P:GetAttribute("BombTagAFK")~=true and options[index] and voteRemote then
    selection=options[index]; voteRemote:FireServer("Vote",selection); refresh()
   end
  end)
  local v=view(b); local caption=text(b,"Name","",10,176,175,40,15); caption.TextWrapped=true
  local amount=text(b,"Votes","",10,230,175,19,12,C.green)
  local status=text(b,"Selection","",10,258,175,17,10,C.muted)
  U.Cards[i]={button=b,view=v,title=caption,count=amount,status=status,rim=b:FindFirstChildOfClass("UIStroke")}
 end
 U.VoteFooter=text(U.Window,"VoteFooter","",22,0,616,21,11,C.muted)
end
local function availableMaps()
 local names={}; if previewFolder then for _,m in ipairs(previewFolder:GetChildren()) do if m:IsA("Model") then table.insert(names,m.Name) end end end
 table.sort(names); return names
end
buildPage=function()
 clear(pageLinks); U.Body:ClearAllChildren(); U.Body.CanvasPosition=Vector2.zero; U.Gallery=nil
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
  if label then label.TextColor3=C.white; label.TextSize=29; label.Font=Enum.Font.GothamBlack end
  block("ANOTHER ROUND. ANOTHER CHANCE.","Read the route. Time your weave. Keep the fuse moving.",C.muted,94)
  local b=button(U.Body,"Continue","CONTINUE  ›",function() resultDismissed=true; refresh() end,false,pageLinks)
  b.Position=UDim2.fromOffset(0,y); b.Size=UDim2.new(1,-6,0,48); y+=60
 elseif menu=="STATS" then
  local any=false
  for _,key in ipairs({"Wins","Coins","Gems","GamesPlayed"}) do
   local value=numberStat(key)
   if value~=nil then block(key=="GamesPlayed" and "GAMES PLAYED" or key:upper(),formatted(value),C.green,86); any=true end
  end
  if not any then block("YOUR RECORD","Your stats will appear when your player record is ready.",C.green,100) end
 elseif menu=="CONTROLS" then
  block("MOVE / SPRINT","W A S D to move. Hold LEFT SHIFT to sprint.",C.green,92)
  block("DODGE / WEAVE","Move + SPACE to dodge in that direction. SPACE alone does nothing. There is no jumping.",C.green,118)
  block("PASS THE BOMB","Get close to another player to pass it. These movement bindings use a keyboard.",C.gold,104)
 elseif menu=="HOW TO PLAY" then
  block("01 / THE FUSE NEVER RESETS","The bomb passes on contact. Its timer keeps counting down after every transfer.",C.green,108)
  block("02 / COMMIT TO YOUR ESCAPE","Use running lanes and ramps. Your dodge grants a short server-confirmed immunity window.",C.green,112)
  block("03 / BE THE LAST ONE STANDING","Break away when you are safe. Close the gap when carrying. One player survives the final duel.",C.gold,110)
 elseif menu=="SETTINGS" then
  -- HussAudioV6: session preferences consumed by GameAudioV6.
  block("AUDIO MIX","Control the soundtrack and game sounds separately. Adjust each layer below.",C.green,112)
  local function audioToggle(name,caption,attribute)
   local muted=P:GetAttribute(attribute)==true
   local b=button(U.Body,name,caption..(muted and " / OFF" or " / ON"),function()
    P:SetAttribute(attribute,P:GetAttribute(attribute)~=true); buildPage()
   end,false,pageLinks)
   b.TextColor3=muted and C.muted or C.green
   b.Position=UDim2.fromOffset(0,y); b.Size=UDim2.new(1,-6,0,48); y+=60
  end
  audioToggle("Music","MUSIC","HussMusicMuted")
  audioToggle("SoundEffects","SOUND EFFECTS","HussSFXMuted")
  block("MOTION & EFFECTS",reduced() and "Reduced motion is on. HUD transitions and movement trails are disabled." or "Full motion is on. Glossy transitions and movement effects give feedback during the action.",C.green,122)
  local b=button(U.Body,"Motion",reduced() and "ENABLE FULL MOTION" or "REDUCE MOTION",function()
   P:SetAttribute("HussReducedMotion",not reduced()); for _,t in pairs(tweens) do t:Cancel() end; U.CountScale.Scale=1; U.WindowScale.Scale=1; U.NoticeScale.Scale=1; buildPage()
  end,false,pageLinks)
  b.Position=UDim2.fromOffset(0,y); b.Size=UDim2.new(1,-6,0,48); y+=64
  block("SESSION PREFERENCES","Your audio and motion choices apply to this play session.",C.muted,92)
 elseif menu=="MAPS" then
  local names=availableMaps(); mapIndex=math.clamp(mapIndex,1,math.max(1,#names)); local name=names[mapIndex]
  local v=view(U.Body); U.Gallery=v; v.frame.Size=UDim2.new(1,-6,0,208); loadPreview(v,name); y=220
  local title=text(U.Body,"MapTitle",name and name:upper() or "NO MAP PREVIEW",0,y,width-6,32,22); title.TextWrapped=true; y+=38
  local source=name and previewFolder:FindFirstChild(name); local w=source and num(source:GetAttribute("MapWidth")); local d=source and num(source:GetAttribute("MapDepth"))
  text(U.Body,"MapDetail",name==mapName() and "CURRENT ARENA" or (w and d and string.format("%d × %d STUDS",w,d) or "RUN / SPRINT / DODGE"),0,y,width-6,20,11,C.green); y+=32
  local prev=button(U.Body,"Previous","‹  PREVIOUS",function() if #names>0 then mapIndex=(mapIndex-2)%#names+1; buildPage() end end,false,pageLinks)
  prev.Position=UDim2.fromOffset(0,y); prev.Size=UDim2.new(.5,-9,0,48)
  local nextButton=button(U.Body,"Next","NEXT  ›",function() if #names>0 then mapIndex=mapIndex%#names+1; buildPage() end end,false,pageLinks)
  nextButton.Position=UDim2.new(.5,3,0,y); nextButton.Size=UDim2.new(.5,-9,0,48); y+=60
 end
 U.Body.CanvasSize=UDim2.fromOffset(0,y)
end
openMenu=function(name)
 if inRound() then return end
 menu=menu==name and nil or name;ecoMessage=nil;refresh()
 if menu and Input:GetLastInputType().Name:find("Gamepad") then Gui.SelectedObject=U.Close end
end
layout=function()
 local size=U.Root.AbsoluteSize; if size.X<1 or size.Y<1 then return end
 lastSize=size; local w,h=size.X,size.Y; local short=h<430; local landscape=short and w>=500; local compact=w<780 and not landscape; U.Short=short
 U.Top.Size=UDim2.fromOffset(math.min(landscape and 210 or 302,w-24),74); align(U.Top,w/2,12,.5,0)
 local identityWidth=landscape and 128 or (compact and math.min(206,(w-36)/2) or 206)
 U.Identity.Size=UDim2.fromOffset(identityWidth,66); align(U.Identity,12,compact and 96 or 12)
 local ix=landscape and 12 or 64; U.Avatar.Visible=not landscape
 U.Identity.Player.Position=UDim2.fromOffset(ix,9); U.Identity.Player.Size=UDim2.new(1,-ix-10,0,17); U.HealthText.Position=UDim2.fromOffset(ix,29); U.HealthText.Size=UDim2.new(1,-ix-10,0,16); U.HealthTrack.Position=UDim2.fromOffset(ix,52); U.HealthTrack.Size=UDim2.new(1,-ix-10,0,4)
 U.Top.Brand.Size=UDim2.new(1,-82,0,14); U.Phase.Size=UDim2.new(1,-30,0,22); U.Phase.TextSize=landscape and 13 or 17; U.Timer.Position=UDim2.new(1,-72,0,7); U.Sub.Size=UDim2.new(1,-30,0,12)
 U.Info.Size=UDim2.fromOffset((compact or landscape) and identityWidth or 202,66); align(U.Info,w-12,compact and 96 or 12,1,0)
 U.Alive.Size=UDim2.new(1,-24,0,23); U.Alive.TextSize=landscape and 14 or 20; U.Map.TextSize=landscape and 9 or 11; U.Map.Size=UDim2.new(1,-24,0,16)
 local bw=short and 180 or math.min(234,w-24); local bh=short and (landscape and h<280 and 76 or 86) or 138
 U.Bomb.Size=UDim2.fromOffset(bw,bh); align(U.Bomb,landscape and 12 or w-12,(compact and 174 or 96),landscape and 0 or 1,0)
 U.BombCaption.Size=UDim2.new(1,-28,0,17); U.BombTime.Position=UDim2.fromOffset(12,short and 26 or 31); U.BombTime.Size=UDim2.fromOffset(bw-60,short and 31 or 54); U.BombTime.TextSize=short and 29 or 43
 U.Bomb.Unit.Position=UDim2.new(1,-45,0,short and 39 or 62)
 U.Carrier.Visible=bh>=86; U.Carrier.Position=UDim2.fromOffset(14,short and 59 or 91); U.Carrier.Size=UDim2.new(1,-28,0,17)
 U.FuseTrack.Position=UDim2.fromOffset(14,short and bh-7 or 121); U.FuseTrack.Size=UDim2.new(1,-28,0,5)
 local dashW=math.min(358,w-24); U.Dash.Size=UDim2.fromOffset(dashW,77); align(U.Dash,w/2,h-14,.5,1)
 U.DashState.Position=UDim2.new(1,-124,0,10); U.DashTitle.Size=UDim2.new(1,-142,0,22); U.Immunity.Position=UDim2.new(1,-159,0,36)
 for i,seg in ipairs(U.Segments) do seg.Position=UDim2.fromOffset(14+(i-1)*(dashW-28)/12,62); seg.Size=UDim2.fromOffset((dashW-28)/12-3,4) end
 -- Keep desktop's upper-right clear for Roblox's native player list.
 U.Tight=compact or landscape
 U.Wallet.Size=UDim2.fromOffset(landscape and 128 or identityWidth,42)
 U.WalletLobbyY=compact and 96 or 12;align(U.Wallet,12,U.WalletLobbyY)
 U.Coins.TextSize=U.Tight and 11 or 15;U.Coins.Size=UDim2.new(1,-54,0,26)
 if not compact and not landscape then align(U.Info,w/2,94,.5,0);align(U.Bomb,12,140) end
 local top=compact and 174 or 102; local available=math.max(78,h-top-112); local menuH=math.min(318,available)
 U.Lobby.Size=UDim2.fromOffset(w<420 and 174 or 186,menuH); align(U.Lobby,12,math.max(top,(h-menuH)/2-16))
 U.LobbyFooter.Size=UDim2.fromOffset(math.min(246,w-24),81); align(U.LobbyFooter,landscape and w-12 or 12,h-12,landscape and 1 or 0,1)
 U.AFK.Size=UDim2.new(1,-20,0,44); align(U.VoteReopen,w-12,h-12,1,1)
 local nw=math.min(362,w-24); U.Notice.Size=UDim2.fromOffset(nw,62); align(U.Notice,w/2,compact and math.min(324,h-165) or 180,.5,0)
 U.NoticeTitle.Size=UDim2.new(1,-28,0,17); U.NoticeBody.Size=UDim2.new(1,-28,0,17)
 align(U.Count,w/2,h*.45,.5,.5)
 local ww=math.min(720,w-24); local wh=math.min(w<540 and 584 or 456,h-24)
 U.Window.Size=UDim2.fromOffset(ww,wh); align(U.Window,w/2,h/2,.5,.5)
 U.WindowTitle.Size=UDim2.new(1,-104,0,37); U.WindowBrand.Size=UDim2.new(1,-104,0,17)
 local vw,vh=ww-44,wh-157; U.Vote.Size=UDim2.fromOffset(vw,vh)
 local vertical=w<540
 for i,e in ipairs(U.Cards) do
  local cw=vertical and vw or (vw-20)/3; local ch=vertical and math.max(96,(vh-16)/3) or vh
  e.button.Size=UDim2.fromOffset(cw,ch); e.button.Position=UDim2.fromOffset(vertical and 0 or (i-1)*(cw+10),vertical and (i-1)*(ch+8) or 0)
  local pw=vertical and math.min(112,cw*.36) or cw-12; local ph=vertical and ch-12 or math.max(38,ch-105)
  e.view.frame.Position=UDim2.fromOffset(6,6); e.view.frame.Size=UDim2.fromOffset(pw,ph)
  local small=not vertical and ch<150; e.view.frame.Visible=not small
  local tx=vertical and pw+17 or 10; local tw=cw-tx-8
  e.title.Position=UDim2.fromOffset(tx,(vertical or small) and 8 or ph+15); e.title.Size=UDim2.fromOffset(tw,vertical and math.min(38,ch-44) or 37); e.title.TextSize=vertical and 13 or 14
  e.count.Position=UDim2.fromOffset(tx,vertical and ch-42 or (small and 48 or ch-49)); e.count.Size=UDim2.fromOffset(tw,18)
  e.status.Position=UDim2.fromOffset(tx,vertical and ch-23 or ch-25); e.status.Size=UDim2.fromOffset(tw,16); fit(e.view)
 end
 U.Vote.CanvasSize=UDim2.fromOffset(0,vertical and 3*(math.max(96,(vh-16)/3)+8)-8 or vh)
 U.VoteFooter.Position=UDim2.fromOffset(22,wh-35); U.VoteFooter.Size=UDim2.new(1,-44,0,21)
 if U.Mode and U.Mode~="vote" then buildPage() end
end
refresh=function()
 if not U.Gui then return end
 local now,server=time(),workspace:GetServerTimeNow(); local playing=inRound(); local afk=P:GetAttribute("BombTagAFK")==true
 if playing then menu=nil; voteDismissed=true end
 local voting=(voteOpen or now<voteResultUntil) and not playing and not afk and not voteDismissed
 local mode=voting and "vote" or (phase=="RESULT" and not resultDismissed and "result") or (menu and "menu") or nil
 local key=mode=="menu" and menu or mode
 if key~=pageName then
  pageName=key; U.Mode=mode
  U.WindowScale.Scale=(not mode or reduced()) and 1 or .965; motion(U.WindowScale,{Scale=1},.22)
  clear(pageLinks); U.Body:ClearAllChildren(); U.Gallery=nil; U.Vote.CanvasPosition=Vector2.zero
  U.Body.Visible=mode~=nil and mode~="vote"; U.Vote.Visible=mode=="vote"; U.VoteFooter.Visible=mode=="vote"
  if mode and mode~="vote" then buildPage() end
 end
 U.Shade.Visible=mode~=nil; U.WindowTitle.Text=mode=="vote" and (voteOpen and "CHOOSE YOUR ARENA" or "ARENA SELECTED") or (mode=="result" and "ROUND RESULTS" or menu or "")
 U.WindowBrand.Text=mode=="vote" and "N E X T  M A T C H  /  M A P  V O T E" or "H U S S  A  B O M B"
 U.Lobby.Visible=not playing and not mode and not voteOpen and countdown==nil
 U.LobbyFooter.Visible=not playing and not mode and not voteOpen
 U.VoteReopen.Visible=voteOpen and voteDismissed and not playing and not afk and not mode
 U.Identity.Visible=playing and not mode and phase~="RESULT"
 U.Wallet.Visible=not mode and (not playing or not U.Tight);U.Wallet.Position=UDim2.fromOffset(12,playing and 86 or U.WalletLobbyY);local coins=profile and profile.ready and numberStat("Coins") or nil;U.Coins.Text=coins~=nil and (coins>=1000000 and string.format("%.1f%s",coins/(coins>=1000000000 and 1000000000 or 1000000),coins>=1000000000 and "B" or "M") or formatted(coins)).." COINS" or (profile and profile.mode=="unavailable" and "UNAVAILABLE" or "LOADING…")
 U.Info.Visible=not mode; U.Top.Visible=not mode
 U.Dash.Visible=playing and not mode and phase~="RESULT"
 U.Bomb.Visible=bomb and not mode and (phase=="ROUND" or phase=="FINAL_DUEL")
 U.Notice.Visible=now<noticeUntil and not mode and countdown==nil and not U.Short
 U.Count.Visible=countdown~=nil and now<countUntil and not mode
 if countdown and now>=countUntil then countdown=nil end
 U.Phase.Text=(phase=="WAITING" and duration>0) and "NEXT MATCH" or (phases[phase] or "HUSS A BOMB")
 local remaining=math.max(0,math.ceil(duration-(now-phaseAt)))
 U.Timer.Text=(phase=="ROUND" or phase=="FINAL_DUEL" or (phase=="WAITING" and duration<=0)) and "" or tostring(remaining).."s"
 U.Sub.Text=afk and "AFK / MATCHMAKING PAUSED" or (phase=="FINAL_DUEL" and "ONE FUSE. TWO PLAYERS." or "RUN. PASS. SURVIVE.")
 U.Alive.Text=tostring(alive or #Players:GetPlayers())..(alive and "  ALIVE" or "  PLAYERS")
 U.Map.Text=playing and U.Tight and U.Coins.Text or mapName():upper()
 local wins=numberStat("Wins"); U.Wins.Text=wins and formatted(wins).."  WINS" or "READY FOR YOUR NEXT ROUND"
 U.AFK.Text=afk and "RETURN TO MATCHMAKING" or "GO AFK  /  MATCHMAKING ON"
 U.AFK.TextColor3=afk and C.gold or C.green
 if humanoid then
  local hp,max=math.max(0,humanoid.Health),math.max(1,humanoid.MaxHealth)
  U.HealthText.Text=string.format("%d / %d",math.ceil(hp),math.ceil(max)); U.HealthFill.Size=UDim2.fromScale(math.clamp(hp/max,0,1),1); U.HealthFill.BackgroundColor3=hp/max<=.3 and C.red or C.green
 end
 local wait=math.max(0,1.5-(now-dodgeAt)); local immunity=character and server<num(character:GetAttribute("BombTagIFrameUntil"),0)
 U.DashTitle.Text=now-dodgeAt<num(workspace:GetAttribute("HussDodgeDuration"),.95) and direction or "DODGE / WEAVE"
 U.DashState.Text=wait<=0 and "READY" or string.format("%.1fs",wait); U.DashState.TextColor3=wait<=0 and C.green or C.gold
 U.DashHint.Text=Input:GetLastInputType()==Enum.UserInputType.Touch and "KEYBOARD: MOVE + SPACE" or (Input:GetLastInputType().Name:find("Gamepad") and "KEYBOARD: MOVE + SPACE" or "MOVE + SPACE  /  DODGE")
 U.Immunity.Text=immunity and "IMMUNE" or ""
 local charge=1-wait/1.5; for i,seg in ipairs(U.Segments) do seg.BackgroundColor3=charge>=i/12 and C.green or C.line; seg.BackgroundTransparency=charge>=i/12 and 0 or .7 end
 if bomb then
  local left=math.max(0,fuseEnd-server); local mine=owner==P.UserId; local danger=left<=3
  U.BombCaption.Text=mine and "YOU HAVE THE BOMB" or "BOMB IN PLAY"; U.BombCaption.TextColor3=mine and C.red or C.gold
  U.BombTime.Text=string.format("%04.1f",left); U.BombTime.TextColor3=danger and C.red or C.white
  U.Carrier.Text=mine and "CLOSE THE GAP. PASS IT." or carrier
  U.BombRim.Color=(mine or danger) and C.red or C.gold; U.Bomb.BackgroundColor3=(mine or danger) and rgb(117,35,64) or panelTones.Bomb; U.FuseFill.BackgroundColor3=(mine or danger) and C.red or C.gold
  U.FuseFill.Size=UDim2.fromScale(math.clamp(left/math.max(.1,fuseLength),0,1),1)
 end
 if mode=="vote" then
  for i,e in ipairs(U.Cards) do
   local name=options[i]; e.button.Visible=name~=nil
   if name then
    e.title.Text=name:upper(); e.count.Text=tostring(counts[name] or 0).." VOTES"; local selected=selection==name
    e.status.Text=voteChosen==name and not voteOpen and "SELECTED ARENA" or (selected and "YOUR VOTE" or "TAP TO VOTE")
    e.button:SetAttribute("HussSelected",selected or (not voteOpen and voteChosen==name))
    e.button:SetAttribute("HussDisabled",not voteOpen or server>=voteEnd)
    e.status.TextColor3=(selected or voteChosen==name) and C.green or C.muted
    if voteOpen and server>=voteEnd then e.status.Text="VOTING CLOSED" end
    loadPreview(e.view,name)
   end
  end
  U.VoteFooter.Text=voteOpen and (string.format("%ds REMAINING",math.max(0,math.ceil(voteEnd-server))).."  /  PICK YOUR NEXT CHASE") or tostring(voteChosen or "")
 end
end
local function bindCharacter(new)
 clear(charLinks); character=new; humanoid=nil; dodgeAt=-math.huge
 if not new then return end
 humanoid=new:FindFirstChildOfClass("Humanoid")
 connect(new.ChildAdded,function(child) if child:IsA("Humanoid") then humanoid=child end end,charLinks)
 local last=new:GetAttribute("MovementActionId")
 connect(new:GetAttributeChangedSignal("MovementActionId"),function()
  local id=new:GetAttribute("MovementActionId"); if id==last then return end; last=id
  local action=tostring(new:GetAttribute("MovementAction") or "")
  if action:sub(1,4)=="Dive" and action~="DiveEnd" and action~="DiveRecover" then
   dodgeAt=time(); direction=(action:sub(5):gsub("(%l)(%u)","%1 %2")):upper(); direction="WEAVE "..direction
  end
 end,charLinks)
end
local function onRound(data)
 if type(data)~="table" or type(data.State)~="string" then return end
 local previous=phase; phase=data.State; duration=math.max(0,num(data.TimeLeft,0)); phaseAt=time()
 alive=(phase=="ROUND" or phase=="FINAL_DUEL") and num(data.Alive,phase=="FINAL_DUEL" and 2 or nil) or nil; if alive then alive=math.max(0,math.floor(alive)) end
 if phase=="STARTING" and duration>=1 and duration<=3 then
  local value=tostring(math.ceil(duration)); if countdown~=value then
   countdown=value; countUntil=time()+1.2; U.CountText.Text=value; U.CountText.TextColor3=C.white; U.CountLabel.Text="GET READY TO RUN"; U.CountScale.Scale=reduced() and 1 or .82; motion(U.CountScale,{Scale=1},.23)
  end
 elseif (phase=="ROUND" or phase=="FINAL_DUEL" or phase=="PRACTICE") and previous=="STARTING" then
  countdown="GO!"; countUntil=time()+.7; U.CountText.Text="GO!"; U.CountText.TextColor3=C.green; U.CountLabel.Text="RUN. PASS. SURVIVE."
 else countdown=nil end
 if phase=="RESULT" and previous~="RESULT" then winner=type(data.Winner)=="string" and data.Winner or ""; resultDismissed=false; menu=nil; noticeUntil=0 end
 if phase=="RESULT" or phase=="WAITING" or phase=="INTERMISSION" then bomb=false end
 refresh()
end
local function onBomb(data)
 if type(data)~="table" then return end
 local previousOwner=owner; local event=type(data.Event)=="string" and data.Event or ""
 bomb=data.Active==true; owner=num(data.CarrierUserId,0); carrier=type(data.CarrierName)=="string" and data.CarrierName or "PLAYER"
 fuseEnd=num(data.EndTime,0)
 if event=="Started" then fuseLength=math.max(.1,fuseEnd-workspace:GetServerTimeNow()) end
 if event=="Exploded" then announce(owner==P.UserId and "ELIMINATED" or "PLAYER ELIMINATED",carrier.." ran out of time.",C.red)
 elseif bomb and owner==P.UserId and previousOwner~=owner then announce("YOU HAVE THE BOMB","Find a player. Pass the pressure.",C.red)
 elseif event=="Transferred" and previousOwner==P.UserId then announce("BOMB PASSED","Keep moving. The fuse is still live.",C.green) end
 refresh()
end
local function onVote(kind,data)
 if type(data)~="table" then return end
 if kind=="Open" or kind=="Sync" then
  local valid={}; if type(data.Options)=="table" then for _,name in ipairs(data.Options) do if type(name)=="string" and #valid<3 then table.insert(valid,name) end end end
  options=valid; voteOpen=data.Open==true and #options>0; voteEnd=num(data.EndsAt,0); voteChosen=nil; voteResultUntil=0
  if kind=="Open" then selection=nil; voteDismissed=false end
  if voteOpen then menu=nil; resultDismissed=true end
 elseif kind=="Result" then
  voteOpen=false; voteChosen=type(data.Chosen)=="string" and data.Chosen or nil; voteResultUntil=time()+1
 elseif kind=="Close" then voteOpen=false; voteResultUntil=0
 elseif kind~="Counts" then return end
 if type(data.Counts)=="table" then
  local clean={}; for _,name in ipairs(options) do clean[name]=math.max(0,math.floor(num(data.Counts[name],0))) end; counts=clean
 end
 refresh()
end
function HUD.Init()
 if started then return end
 started=true; epoch+=1; local session=epoch
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
  elseif child.Name=="BombTagAFKRequest" and child:IsA("RemoteEvent") then afkRemote=child
  elseif child.Name=="BombTagV6Previews" and child:IsA("Folder") and child~=previewFolder then
   previewFolder=child; for _,e in ipairs(U.Cards) do e.view.name=nil end
   if menu=="MAPS" and U.Mode=="menu" then buildPage() end
  end
 end
 connect(RS.ChildAdded,attach)
 connect(RS.ChildRemoved,function(child)
  if child==economy then economy=nil;profile=nil;busy=nil;if ecoLink then ecoLink:Disconnect();ecoLink=nil end;ecoRefresh() end
  if child==voteRemote then voteRemote=nil; if voteLink then voteLink:Disconnect(); voteLink=nil end end
  if child==afkRemote then afkRemote=nil end
  if child==previewFolder then previewFolder=nil end
 end)
 for _,child in ipairs(RS:GetChildren()) do attach(child) end
 connect(P.CharacterAdded,bindCharacter); connect(P.CharacterRemoving,function(old) if character==old then bindCharacter(nil) end end); bindCharacter(P.Character)
 connect(P:GetAttributeChangedSignal("InRound"),refresh); connect(P:GetAttributeChangedSignal("BombTagAFK"),refresh)
 local function hideLegacy(child)
  if child:IsA("ScreenGui") and (child.Name=="PixelHealthGui" or child.Name=="BombTagV6VoteGui" or child.Name=="BombTagAFKGui") then hidden[child]=child.Enabled; child.Enabled=false end
 end
 local pg=P:WaitForChild("PlayerGui"); connect(pg.ChildAdded,hideLegacy); for _,child in ipairs(pg:GetChildren()) do hideLegacy(child) end
 connect(Input.InputBegan,function(input,processed)
  if processed or Input:GetFocusedTextBox() then return end
  if input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB then
   if U.Mode=="vote" then voteDismissed=true elseif U.Mode=="result" then resultDismissed=true else menu=nil end; Gui.SelectedObject=nil; refresh()
  end
 end)
 connect(Run.RenderStepped,function(dt)
  tickTime+=dt; statTime+=dt
  if U.Root.AbsoluteSize~=lastSize then layout() end
  if tickTime>=1/30 then tickTime=0; refresh() end
  if statTime>=1 then statTime=0; if menu=="STATS" and U.Mode=="menu" then local pos=U.Body.CanvasPosition; buildPage(); U.Body.CanvasPosition=pos end end
 end)
 task.spawn(function()
  local ok,url=pcall(function() return Players:GetUserThumbnailAsync(P.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100) end)
  if ok and started and epoch==session then U.Avatar.Image=url end
 end)
 refresh()
end
function HUD.Destroy()
 if not started then return end
 started=false; epoch+=1; clear(links); clear(charLinks); clear(pageLinks)
 for _,bucket in pairs(rosterLinks) do clear(bucket) end;table.clear(rosterLinks)
 economy=nil;ecoLink=nil;profile=nil;board=nil;busy=nil
 for _,t in pairs(tweens) do t:Cancel() end; table.clear(tweens)
 for o,enabled in pairs(hidden) do if o.Parent then o.Enabled=enabled end end; table.clear(hidden)
 if U.Gui then if Gui.SelectedObject and Gui.SelectedObject:IsDescendantOf(U.Gui) then Gui.SelectedObject=nil end; U.Gui:Destroy() end
 U={}; character=nil; humanoid=nil; voteLink=nil; lastSize=Vector2.zero
end
return HUD
