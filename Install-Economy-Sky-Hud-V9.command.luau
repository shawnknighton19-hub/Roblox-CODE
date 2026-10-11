-- HUSS A BOMB V9: SKY, GLOSSY HUD, COINS, QUESTS AND COSMETIC SHOP
-- Requires V8. Stop Play, paste this entire block into Studio's Command Bar, then save.
-- Studio uses temporary profiles; published servers save progression automatically.
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'Stop Play before installing.')
local storage=game:GetService('ServerStorage')
local lighting=game:GetService('Lighting')
local terrain=workspace:FindFirstChildOfClass('Terrain')
local scripts=game:GetService('StarterPlayer').StarterPlayerScripts
local controllers=scripts:FindFirstChild('Controllers')
local hud=controllers and controllers:FindFirstChild('HudController')
local audio=scripts:FindFirstChild('GameAudioV6')
local effects=scripts:FindFirstChild('MovementEffectsV8')
local server=game:GetService('ServerScriptService')
local main=server:FindFirstChild('ServerMain')
local services=server:FindFirstChild('Services')
local round=services and services:FindFirstChild('RoundService')
local bomb=services and services:FindFirstChild('BombService')
local previousEconomy=services and services:FindFirstChild('EconomyServiceV9')
local economyRemote=game:GetService('ReplicatedStorage'):FindFirstChild('HussEconomyV9')
assert(hud and hud:IsA('ModuleScript') and audio and audio:IsA('LocalScript') and effects and effects:IsA('LocalScript'),'Install the previous V8 update first. Nothing changed.')
assert(hud.Source:find('-- HussGlossV8',1,true) and audio.Source:find('-- HussFootstepsV8',1,true) and effects.Source:find('-- HussMovementEffectsV8',1,true),'V8 signatures are missing. Nothing changed.')
assert(main and main:IsA('Script') and round and round:IsA('ModuleScript') and bomb and bomb:IsA('ModuleScript') and terrain,'Original server services or Terrain are missing. Nothing changed.')
assert(not previousEconomy or (previousEconomy:IsA('ModuleScript') and previousEconomy.Source:find('-- HussEconomyV9',1,true)),'An unrelated EconomyServiceV9 already exists. Nothing changed.')
assert(not economyRemote or (previousEconomy and economyRemote:IsA('RemoteEvent')),'An unrelated HussEconomyV9 remote already exists. Nothing changed.')

local patchHUD=(function()
-- V9 keeps one responsive HUD, backed by the same leaderstats as Roblox's player list.
return function(source)
 local marker='-- HussEconomyHudV9'
 assert(source:find('-- HussGlossV8',1,true),'Install V8 HUD first. Nothing changed.')
 if source:find(marker,1,true) then assert(source:find('local function economyPage',1,true),'Incomplete V9 HUD.');return source end
 local function replace(old,new)
  local a,b=source:find(old,1,true);assert(a and not source:find(old,b+1,true),'Unexpected HUD section: '..old:sub(1,36))
  source=source:sub(1,a-1)..new..source:sub(b+1)
 end
 replace('local refresh, layout, openMenu, buildPage',[[-- HussEconomyHudV9
local economy,ecoLink,profile,board,busy,serial=nil,nil,nil,nil,nil,0
local rosterLinks={}
local ecoMessage
local refresh, layout, openMenu, buildPage]])
 replace('local panelTones=',[[tones.SHOP=rgb(151,66,160);tones.QUESTS=rgb(185,104,22);tones.LEADERBOARDS=rgb(31,111,157)
local panelTones=]])
 replace('Font=Enum.Font.GothamBold,TextSize=size','Font=Enum.Font.GothamBlack,TextSize=size')
 replace('local shine=frame(o,"Gloss",3,3,1,10,C.white,o.ZIndex+1)','local shine=frame(o,"Gloss",3,3,1,14,C.white,o.ZIndex+1)')
 replace('shine.Size=UDim2.new(1,-6,0,10);shine.BackgroundTransparency=.87','shine.Size=UDim2.new(1,-6,0,14);shine.BackgroundTransparency=.84')
 replace('o.BackgroundTransparency=.035;rounded(o,12)','o.BackgroundTransparency=0;rounded(o,14)')
 replace('rounded(U.Avatar,4)','rounded(U.Avatar,22);stroke(U.Avatar,C.violet)')
 replace('local function makeUI()',[[local function ecoRefresh()
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
local function makeUI()]])
 replace(' U.Info=panel(U.Root,"MatchInfo",202,66,5)',[[ U.Wallet=panel(U.Root,'Wallet',206,42,6,C.gold)
 U.Wallet.BackgroundColor3=rgb(133,82,24)
 local coin=frame(U.Wallet,'Coin',10,8,26,26,C.gold,8);rounded(coin,13);stroke(coin,rgb(255,241,170));text(coin,'Symbol','$',0,0,26,26,18,C.white,Enum.TextXAlignment.Center)
 U.Coins=text(U.Wallet,'Coins','— COINS',46,8,148,26,16,C.white)
 U.Info=panel(U.Root,"MatchInfo",202,66,5)]])
 replace('CanvasSize=UDim2.fromOffset(0,278)','CanvasSize=UDim2.fromOffset(0,446)')
 replace('{"STATS","CONTROLS","HOW TO PLAY","MAPS","SETTINGS"}','{"QUESTS","SHOP","LEADERBOARDS","STATS","MAPS","SETTINGS","CONTROLS","HOW TO PLAY"}')
 replace('U.Count.BackgroundTransparency=1','U.Count.BackgroundColor3=rgb(102,61,170);U.Count.BackgroundTransparency=.08;rounded(U.Count,24);stroke(U.Count,C.gold);gloss(U.Count)')
 replace(' if U.Mode=="result" then\n  block(',[[ if menu=='SHOP' or menu=='QUESTS' or menu=='LEADERBOARDS' then
  y=economyPage(block,width)
 elseif U.Mode=="result" then
  block(]])
 replace(' local top=compact and 96 or 102;',[[ -- Keep desktop's upper-right clear for Roblox's native player list.
 U.Tight=compact or landscape
 U.Wallet.Size=UDim2.fromOffset(landscape and 128 or identityWidth,42)
 U.WalletLobbyY=compact and 96 or 12;align(U.Wallet,12,U.WalletLobbyY)
 U.Coins.TextSize=U.Tight and 11 or 15;U.Coins.Size=UDim2.new(1,-54,0,26)
 if not compact and not landscape then align(U.Info,w/2,94,.5,0);align(U.Bomb,12,140) end
 local top=compact and 174 or 102;]])
 replace('align(U.LobbyFooter,12,h-12,0,1)', 'align(U.LobbyFooter,landscape and w-12 or 12,h-12,landscape and 1 or 0,1)')
 replace('menu=menu==name and nil or name; refresh()', 'menu=menu==name and nil or name;ecoMessage=nil;refresh()')
 replace('text(card,"Heading",title,14,10,width-34,22,15,color or C.green)', 'text(card,"Heading",title,14,10,width-34,22,15,color or C.green).Size=UDim2.new(1,-28,0,22)')
 replace('label.TextWrapped=true; label.TextTruncate=', 'label.Size=UDim2.new(1,-28,0,(height or 100)-48);label.TextWrapped=true; label.TextTruncate=')
 replace('local card=panel(U.Body,title,width-6,height or 100,54)', 'local card=panel(U.Body,title,width-6,height or 100,54,color)')
 local clipped;source,clipped=source:gsub('BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=', 'BackgroundTransparency=1,ClipsDescendants=true,BorderSizePixel=0,ScrollBarThickness=');assert(clipped==3,'HUD scroll containers changed.')
 replace(' U.Info.Visible=not mode; U.Top.Visible=not mode',' U.Wallet.Visible=not mode and (not playing or not U.Tight);U.Wallet.Position=UDim2.fromOffset(12,playing and 86 or U.WalletLobbyY);local coins=profile and profile.ready and numberStat("Coins") or nil;U.Coins.Text=coins~=nil and (coins>=1000000 and string.format("%.1f%s",coins/(coins>=1000000000 and 1000000000 or 1000000),coins>=1000000000 and "B" or "M") or formatted(coins)).." COINS" or (profile and profile.mode=="unavailable" and "UNAVAILABLE" or "LOADING…")\n U.Info.Visible=not mode; U.Top.Visible=not mode')
 replace(' U.Map.Text=mapName():upper()', ' U.Map.Text=playing and U.Tight and U.Coins.Text or mapName():upper()')
 replace('align(U.Notice,w/2,compact and 180 or 100,.5,0)', 'align(U.Notice,w/2,compact and math.min(324,h-165) or 180,.5,0)')
 replace(' makeUI(); layout()',[[ profile=nil;board=nil;busy=nil;economy=nil;ecoLink=nil;ecoMessage=nil
 makeUI(); layout()
 connect(Players.PlayerAdded,watchPlayer)
 connect(Players.PlayerRemoving,function(p) if rosterLinks[p] then clear(rosterLinks[p]);rosterLinks[p]=nil end;task.defer(function() if started and epoch==session then ecoRefresh() end end) end)
 for _,p in ipairs(Players:GetPlayers()) do watchPlayer(p) end]])
 replace('  if child.Name=="BombTagVoteV6"',[[  if child.Name=='HussEconomyV9' and child:IsA('RemoteEvent') and child~=economy then
   if ecoLink then ecoLink:Disconnect() end;economy=child;ecoLink=connect(child.OnClientEvent,receive);busy=nil;request('Sync')
  elseif child.Name=="BombTagVoteV6"]])
 replace('  if child==voteRemote then',[[  if child==economy then economy=nil;profile=nil;busy=nil;if ecoLink then ecoLink:Disconnect();ecoLink=nil end;ecoRefresh() end
  if child==voteRemote then]])
 replace(' started=false; epoch+=1; clear(links); clear(charLinks); clear(pageLinks)',[[ started=false; epoch+=1; clear(links); clear(charLinks); clear(pageLinks)
 for _,bucket in pairs(rosterLinks) do clear(bucket) end;table.clear(rosterLinks)
 economy=nil;ecoLink=nil;profile=nil;board=nil;busy=nil]])
 return source
end

end)()

local patchEffects=(function()
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

local patchServer=(function()
-- V9: the economy owns progression; gameplay remains server-authoritative.
local Patch={}
local marker='-- HussEconomyHooksV9'
local function replace(source,old,new,label)
 local a,b=source:find(old,1,true)
 assert(a and not source:find(old,b+1,true),'Unexpected '..label..'. Nothing changed.')
 return source:sub(1,a-1)..new..source:sub(b+1)
end
local function removeSection(source,first,last)
 local a=source:find(first,1,true);local b=a and source:find(last,a+1,true)
 assert(a and b,'Server helper section differs. Nothing changed.')
 return source:sub(1,a-1)..source:sub(b)
end
local requireEconomy="local Economy=require(script.Parent:WaitForChild('EconomyServiceV9'))\n"
function Patch.Main(source)
 if source:find(marker,1,true) then
  assert(source:find("require(Services:WaitForChild('EconomyServiceV9')).Init()",1,true),'Incomplete V9 server boot. Nothing changed.');return source
 end
 return replace(source,'BombService.Init()',marker.."\nrequire(Services:WaitForChild('EconomyServiceV9')).Init()\nBombService.Init()",'server initialization')
end
function Patch.Round(source)
 if source:find(marker,1,true) then
  assert(source:find('Economy.BeginRound(getAlivePlayers())',1,true) and source:find('Economy.EndRound(winner)',1,true) and not source:find('wins.Value += 1',1,true),'Incomplete V9 round hooks. Nothing changed.');return source
 end
 source=replace(source,'local RoundService = {}',marker..'\n'..requireEconomy..'local RoundService = {}','round service')
 source=removeSection(source,'local function setupLeaderstats(player)','------------------------------------------------------------\n-- LOBBY SPAWN')
 source=replace(source,'\tsetupLeaderstats(\n\t\tplayer\n\t)\n','', 'legacy leaderstats call')
 source=removeSection(source,'local function awardWin(player)','------------------------------------------------------------\n-- BOMB MATCH')
 source=replace(source,'\t\tawardWin(\n\t\t\twinner\n\t\t)\n','', 'legacy win award')
 source=replace(source,'local function runBombMatch()','local function runBombMatch()\n\tEconomy.BeginRound(getAlivePlayers())','round start')
 source=replace(source,'\t-- RESULTS\n\t--------------------------------------------------------','\t-- RESULTS\n\t--------------------------------------------------------\n\n\tEconomy.EndRound(winner)','round result')
 source=replace(source,'local function returnEveryoneToLobby()','local function returnEveryoneToLobby()\n\tEconomy.AbortRound()','lobby cleanup')
 source=replace(source,'\t\tif not success then','\t\tif not success then\n\t\t\tEconomy.AbortRound()','round error cleanup')
 return source
end
function Patch.Bomb(source)
 if source:find(marker,1,true) then
  assert(source:find('Economy.Pass(oldCarrier,carrier)',1,true),'Incomplete V9 bomb hook. Nothing changed.');return source
 end
 source=replace(source,'local BombService = {}',marker..'\n'..requireEconomy..'local BombService = {}','bomb service')
 return replace(source,'\t\t\t\t\t\t\t"Transferred"\n\t\t\t\t\t\t)','\t\t\t\t\t\t\t"Transferred"\n\t\t\t\t\t\t)\n\t\t\t\t\t\tEconomy.Pass(oldCarrier,carrier)','successful bomb transfer')
end
return Patch

end)()

local graphics=(function()
-- Warm afternoon, a pastel horizon and soft clouds. No external sky asset required.
local G={}
function G.Plan(lighting,terrain)
 assert(lighting and lighting:IsA('Lighting') and terrain and terrain:IsA('Terrain'),'Lighting or Terrain is missing. Nothing changed.')
 local rgb=Color3.fromRGB
 local properties={TimeOfDay='14:40:00',Brightness=2.4,ExposureCompensation=.05,GlobalShadows=true,ShadowSoftness=.45,GeographicLatitude=26,
  Ambient=rgb(89,91,118),OutdoorAmbient=rgb(141,155,180),ColorShift_Top=rgb(12,7,0),ColorShift_Bottom=rgb(0,0,0),EnvironmentDiffuseScale=.7,EnvironmentSpecularScale=.65}
 local plan={Properties=properties,OriginalProperties={},Old={},New={}}
 for key in pairs(properties) do plan.OriginalProperties[key]=lighting[key] end
 local names={HussSkyV9='Sky',HussAtmosphereV9='Atmosphere',HussBloomV9='BloomEffect',HussColorV9='ColorCorrectionEffect',HussSunV9='SunRaysEffect',HussCloudsV9='Clouds',HussBloomV8='BloomEffect',HussColorV8='ColorCorrectionEffect'}
 for _,parent in ipairs({lighting,terrain}) do for _,o in ipairs(parent:GetChildren()) do
  assert(not names[o.Name] or o:IsA(names[o.Name]),'Unexpected graphics object: '..o.Name..'. Nothing changed.')
  local known=names[o.Name] or (o.Name=='Bloom' and o:IsA('BloomEffect')) or (o.Name=='SunRays' and o:IsA('SunRaysEffect'))
  if (parent==lighting and (known or o:IsA('Sky') or o:IsA('Atmosphere'))) or (parent==terrain and o:IsA('Clouds')) then table.insert(plan.Old,o) end
 end end
 local function add(class,name,props,target) table.insert(plan.New,{Class=class,Name=name,Properties=props,Target=target or 'Lighting'}) end
 local sky={CelestialBodiesShown=true,SunAngularSize=9,MoonAngularSize=8,StarCount=900,SkyboxOrientation=Vector3.new(0,32,0),SunTextureId='rbxasset://sky/sun.jpg',MoonTextureId='rbxasset://sky/moon.jpg'}
 for _,face in ipairs({'Bk','Dn','Ft','Lf','Rt','Up'}) do sky['Skybox'..face]='rbxasset://textures/sky/sky512_'..face:lower()..'.tex' end
 add('Sky','HussSkyV9',sky)
 add('Atmosphere','HussAtmosphereV9',{Density=.23,Offset=.18,Color=rgb(197,225,255),Decay=rgb(128,141,196),Glare=.08,Haze=.85})
 add('Clouds','HussCloudsV9',{Enabled=true,Cover=.32,Density=.4,Color=rgb(255,248,236)},'Terrain')
 add('ColorCorrectionEffect','HussColorV9',{Enabled=true,Brightness=.01,Contrast=.06,Saturation=.15,TintColor=rgb(255,250,244)})
 add('BloomEffect','HussBloomV9',{Enabled=true,Intensity=.14,Size=20,Threshold=1.25})
 add('SunRaysEffect','HussSunV9',{Enabled=true,Intensity=.025,Spread=.8})
 return plan
end
return G

end)()

local economySource=[==[--!nonstrict
-- HussEconomyV9: earned currency, daily quests and cosmetic trails. Server authority only.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local DS=game:GetService('DataStoreService')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local E={}
local PREVIEW=Run:IsStudio()
local MAX,LEASE=2000000000,180
local catalog={
 {id='default',name='Classic',price=0,color={125,244,255}},
 {id='aqua',name='Arctic Rush',price=250,color={72,211,255}},
 {id='sunset',name='Solar Rush',price=400,color={255,161,74}},
 {id='royal',name='Royal Rush',price=600,color={172,116,255}},
 {id='lime',name='Toxic Rush',price=800,color={157,255,85}},
 {id='rose',name='Candy Rush',price=1000,color={255,117,180}},
}
local quests={{id='rounds',title='Complete 3 rounds',target=3,reward=100},{id='passes',title='Pass the bomb 10 times',target=10,reward=150},{id='wins',title='Win a round',target=1,reward=200}}
local items={};for _,item in ipairs(catalog) do items[item.id]=item end
local records,byUser,match={},{},nil
local remote,store,ordered,started,closing
local board={kind='Board',status=PREVIEW and 'preview' or 'loading',rows={},updatedAt=0}
local boardAt,boardBusy,boardWanted=0,false,false
local names={}
local save,publish
local function integer(n) return type(n)=='number' and n==n and n>=0 and n<=MAX and n%1==0 end
local function copy(t) local out={};for k,v in pairs(t) do out[k]=type(v)=='table' and copy(v) or v end;return out end
local function day() return math.floor(os.time()/86400) end
local function fresh()
 return {v=1,Coins=0,Wins=0,GamesPlayed=0,Passes=0,Owned={default=true},Equipped='default',Day=day(),Progress={rounds=0,passes=0,wins=0},Claimed={}}
end
local function valid(d)
 if type(d)~='table' or d.v~=1 or not integer(d.Coins) or not integer(d.Wins) or not integer(d.GamesPlayed) or not integer(d.Passes) or not integer(d.Day) then return false end
 if type(d.Owned)~='table' or type(d.Progress)~='table' or type(d.Claimed)~='table' or not items[d.Equipped] or d.Owned[d.Equipped]~=true or d.Owned.default~=true then return false end
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
 local out={kind='Profile',requestId=requestId,ok=ok~=false,ready=ready,mode=ready and (PREVIEW and 'preview' or 'live') or (r.loading and 'loading' or 'unavailable'),message=message or r.message,Catalog=catalog,Quests={},Owned={},Coins=d and d.Coins or 0,Wins=d and d.Wins or 0,GamesPlayed=d and d.GamesPlayed or 0,Passes=d and d.Passes or 0,Equipped=d and d.Equipped or 'default',resetsAt=(day()+1)*86400}
 for _,q in ipairs(quests) do local row=copy(q);row.progress=d and math.min(d.Progress[q.id],q.target) or 0;row.claimed=d and d.Claimed[q.id]==true or false;table.insert(out.Quests,row) end
 for _,item in ipairs(catalog) do if d and d.Owned[item.id] then table.insert(out.Owned,item.id) end end
 r.player:SetAttribute('HussEconomyReady',ready)
 if d then
  r.coins.Value=d.Coins;r.wins.Value=d.Wins
  r.player:SetAttribute('GamesPlayed',d.GamesPlayed);r.player:SetAttribute('Passes',d.Passes)
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
    local value=copy(d);value.Lease={token=r.token,expires=os.time()+LEASE};return value
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
 local r={player=p,coins=stat('Coins'),wins=stat('Wins'),token=game.JobId..':'..Http:GenerateGUID(false),loading=true,revision=0,savedRevision=0,tokens=8,rateAt=os.clock()}
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
 if d.Owned[id] and d.Equipped==id then sync(r,requestId,true,'Trail already equipped.');return end
 if action=='Buy' and not d.Owned[id] then
  if d.Coins<item.price then sync(r,requestId,false,'You need more Coins.');return end
  d.Coins-=item.price;d.Owned[id]=true
 elseif not d.Owned[id] then sync(r,requestId,false,'Unlock this trail first.');return end
 d.Equipped=id;touch(r);sync(r,requestId,true,'Trail equipped!');save(r)
end
local function eligible(p)
 if typeof(p)~='Instance' or not p:IsA('Player') or p.Parent~=Players or p:GetAttribute('BombTagAFK')==true or p:GetAttribute('InRound')~=true then return false end
 local h=p.Character and p.Character:FindFirstChildOfClass('Humanoid')
 return h~=nil and h.Health>0
end
function E.BeginRound(players)
 match=nil
 local members,count={},0
 for _,p in ipairs(players) do if not members[p] and eligible(p) then members[p]={record=writable(records[p]) and records[p] or nil,passes=0,lastPass=-math.huge};count+=1 end end
 if count>=2 then match={members=members,started=os.clock()} end
end
function E.Pass(from,to)
 local current=match
 if not current or from==to or not current.members[from] or not current.members[to] or not eligible(from) or not eligible(to) then return end
 local member=current.members[from];local now=os.clock()
 if now-member.lastPass<.25 then return end
 member.lastPass=now;member.passes=math.min(MAX,member.passes+1)
end
function E.AbortRound() match=nil end
function E.EndRound(winner)
 local current=match;match=nil
 if not current then return end
 if winner and (not current.members[winner] or not eligible(winner)) then winner=nil end
 for p,member in pairs(current.members) do
  local r=member.record
  if r and records[p]==r and p.Parent==Players and writable(r) then
   rollover(r);local d=r.data;local won=p==winner
   d.GamesPlayed=math.min(MAX,d.GamesPlayed+1);d.Passes=math.min(MAX,d.Passes+member.passes)
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
]==]

assert(not previousEconomy or previousEconomy.Source==economySource,'EconomyServiceV9 was edited after installation. Nothing changed.')
local edits={{hud,patchHUD(hud.Source)},{effects,patchEffects(effects.Source)},{main,patchServer.Main(main.Source)},{round,patchServer.Round(round.Source)},{bomb,patchServer.Bomb(bomb.Source)}}
local plan=graphics.Plan(lighting,terrain)
local backup=Instance.new('Folder');backup.Name='EconomySkyHudBackup_'..os.time()
while storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local staging=Instance.new('Folder');staging.Name='V9Staging'
local oldLighting=Instance.new('Folder');oldLighting.Name='Lighting';oldLighting.Parent=backup
local oldTerrain=Instance.new('Folder');oldTerrain.Name='Terrain';oldTerrain.Parent=backup
local values=Instance.new('Folder');values.Name='LightingProperties';values.Parent=backup
local originalSources,oldParents,newGraphics={},{},{}
local newEconomy
local ok,err=pcall(function()
 backup:SetAttribute('AddedEconomyService',previousEconomy==nil)
 for _,edit in ipairs(edits) do
  local object,source=edit[1],edit[2]
  assert(object.Archivable,object.Name..' must be Archivable. Nothing changed.')
  originalSources[object]=object.Source
  local copy=object:Clone();assert(copy,'Unable to back up '..object.Name)
  if copy:IsA('BaseScript') then copy:SetAttribute('OriginalDisabled',copy.Disabled);copy.Disabled=true end
  copy.Parent=backup
  local probe=Instance.new(object.ClassName)
  local written,message=pcall(function() probe.Source=source end);probe:Destroy();assert(written,message)
 end
 for property,value in pairs(plan.OriginalProperties) do values:SetAttribute(property,value) end
 for _,effect in ipairs(plan.Old) do oldParents[effect]=effect.Parent end
 for _,spec in ipairs(plan.New) do
  assert(spec.Target=='Lighting' or spec.Target=='Terrain','Invalid graphics destination.')
  local effect=Instance.new(spec.Class);effect.Parent=staging;table.insert(newGraphics,{effect,spec.Target});effect.Name=spec.Name
  for property,value in pairs(spec.Properties) do effect[property]=value end
 end
 if not previousEconomy then
  newEconomy=Instance.new('ModuleScript');newEconomy.Parent=staging;newEconomy.Name='EconomyServiceV9';newEconomy.Source=economySource
 end
end)
if not ok then staging:Destroy();backup:Destroy();error('Preflight stopped; originals preserved: '..tostring(err)) end
ok,err=pcall(function()
 backup.Parent=storage
 if newEconomy then newEconomy.Parent=services end
 for _,edit in ipairs(edits) do edit[1].Source=edit[2] end
 for effect,parent in pairs(oldParents) do effect.Parent=parent==terrain and oldTerrain or oldLighting end
 for property,value in pairs(plan.Properties) do lighting[property]=value end
 for _,entry in ipairs(newGraphics) do entry[1].Parent=entry[2]=='Terrain' and terrain or lighting end
end)
if not ok then
 local failures={}
 local function restore(fn) local success,message=pcall(fn);if not success then table.insert(failures,tostring(message)) end end
 if newEconomy then restore(function() newEconomy:Destroy() end) end
 for _,entry in ipairs(newGraphics) do restore(function() entry[1]:Destroy() end) end
 for property,value in pairs(plan.OriginalProperties) do restore(function() lighting[property]=value end) end
 for effect,parent in pairs(oldParents) do restore(function() effect.Parent=parent end) end
 for object,source in pairs(originalSources) do restore(function() object.Source=source end) end
 staging:Destroy()
 if #failures==0 then backup:Destroy();error('Installation rolled back: '..tostring(err)) end
 error('Installation stopped. Backups: ServerStorage/'..backup.Name..'. Restore errors: '..table.concat(failures,'; ')..'. Original error: '..tostring(err))
end
staging:Destroy()
print('V9 installed: new sky and lighting, complete glossy HUD, coins, quests, cosmetic shop and synchronized leaderboards.')
print('Studio profiles are temporary. Published servers save progression. Maps, movement and music settings are unchanged.')
print('Backups: ServerStorage/'..backup.Name..'. Save the place, then press Play.')
