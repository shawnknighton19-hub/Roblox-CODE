-- HUSS A BOMB V11 COMPATIBILITY INSTALLER
-- Paste the entire script into Roblox Studio's Command Bar with Play stopped.
-- Local, source-verified migration. No HTTP, asset loader or gameplay module execution.
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'V11: Stop Play before installing. Nothing changed.')
local storage=game:GetService('ServerStorage')
local replicated=game:GetService('ReplicatedStorage')
local server=game:GetService('ServerScriptService')
local starterRoot=game:GetService('StarterPlayer')
local issues,notes={},{}
local function problem(message) table.insert(issues,tostring(message)) end
local function note(message) table.insert(notes,tostring(message)) end
local function path(object) return object and object:GetFullName() or '(missing)' end
local function canonical(source) return source:gsub('\r\n','\n'):match('^%s*(.-)%s*$') end
local function fingerprint(source)
 source=canonical(source);local a,b=1,0
 for i=1,#source do a=(a+source:byte(i))%65521;b=(b+a)%65521 end
 return #source,b*65536+a
end
local function unique(parent,name,class,recursive,optional)
 local found={}
 if parent then for _,object in ipairs(recursive and parent:GetDescendants() or parent:GetChildren()) do
  if object.Name==name then table.insert(found,object) end
 end end
 if #found==0 then if not optional then problem(path(parent)..'/'..name..' is missing; expected '..class..'.') end;return nil end
 if #found~=1 then
  local locations={};for _,object in ipairs(found) do table.insert(locations,path(object)..' ('..object.ClassName..')') end
  problem('Ambiguous '..name..': '..table.concat(locations,', ')..'. Keep one active owner; nothing will be guessed.');return nil
 end
 local object=found[1]
 if not object:IsA(class) then problem(path(object)..' is '..object.ClassName..'; expected '..class..'.');return nil end
 return object
end
local function stopPreflight()
 if #issues>0 then error('V11 compatibility preflight stopped. Originals preserved.\n- '..table.concat(issues,'\n- '),0) end
end
local function attempt(label,fn)
 local ok,result=pcall(fn)
 if not ok then problem(label..': '..tostring(result));return nil end
 return result
end

local gameplayAdapter=(function()
-- V11 compatibility adapter: verified uploaded V6/AFK, V9 economy, or full V11.
-- Full normalized source fingerprints are checked before any exact, unique edit.
-- All functions return strings only; installation/backup/rollback belongs to caller.
local Compat={}
local function normalize(source)
 assert(type(source)=='string','Expected readable source text; nothing changed.')
 source=source:gsub('\r\n','\n')
 if source:sub(1,3)==string.char(239,187,191) then source=source:sub(4) end
 return (source:gsub('^%s+',''):gsub('%s+$',''))
end
function Compat.Fingerprint(source)
 source=normalize(source)
 local a,b=5381,2166136261
 for i=1,#source do
  local x=source:byte(i)
  a=(a*33+x)%4294967291
  b=(b*65599+x)%4294967279
 end
 return string.format('%d:%08x:%08x',#source,a,b)
end
local Known={
 Main={['885:ce2918ba:fa013302']='Uploaded',['965:f0276cf6:68b0fa72']='V9',['1050:fe193541:4179e92e']='V11'},
 Round={['21588:26caf1f9:1b8c1816']='Uploaded',['21087:ee2201de:a0c1c2de']='V9',['21043:230100af:ed56a242']='V11'},
 Bomb={['12904:5712c657:06331ded']='Uploaded',['13035:890b580f:70784e55']='V9',['13683:5783794e:74cae3bf']='V11'},
}
local UnsupportedV3={Main='1018:ae5188eb:a66da2cb',Round='21161:315db319:8c760ffb'}
function Compat.Classify(kind,source)
 assert(Known[kind],'Unknown compatibility component '..tostring(kind))
 local fingerprint=Compat.Fingerprint(source)
 local variant=Known[kind][fingerprint]
 if variant then return variant end
 if UnsupportedV3[kind]==fingerprint then
  return nil,kind..' is the older V3 MapService integration. Its voting/state-sync protocol is different from this V6/AFK project; keep it unchanged and export that complete project for a separate adapter.'
 end
 return nil,kind..' source is not a verified uploaded, V9, or complete V11 version ('..fingerprint..'). Partial installs and custom edits are not overwritten. Export this script from Studio so its actual code can be adapted.'
end
local EconomyPatch=(function()
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
local CorePatch=(function()
-- V11 server combat/stat hooks and movement integration. No cooldown changes.
local P={}
local function replace(s,old,new,label)
 local a,b=s:find(old,1,true);assert(a and not s:find(old,b+1,true),'Unexpected '..label..'. Nothing changed.')
 return s:sub(1,a-1)..new..s:sub(b+1)
end
function P.Bomb(s)
 if s:find('-- HussCombatHooksV11',1,true) then
  assert(s:find('PerfectWeave.Try(carrier,candidate',1,true) and s:find('Economy.Elimination(lastPasser,victim)',1,true),'Incomplete V11 bomb hooks.');return s
 end
 assert(s:find('-- HussEconomyHooksV9',1,true),'Install V9 progression first.')
 s=replace(s,'local BombService = {}',[[-- HussCombatHooksV11
local Cosmetics=require(script.Parent:WaitForChild('CosmeticsServiceV11'))
local PerfectWeave=require(script.Parent:WaitForChild('PerfectWeaveServiceV11'))
local currentActor=nil
local BombService = {}]],'BombService declaration')
 s=replace(s,'\tactiveBombPart = bomb\n\tactiveHighlight = highlight','\tactiveBombPart = bomb\n\tactiveHighlight = highlight\n\tCosmetics.ApplyBomb(player,bomb)','bomb appearance')
 s=replace(s,'\tbombRemote:FireAllClients({','\tcurrentActor=active and carrier or nil\n\tbombRemote:FireAllClients({','bomb state')
 s=replace(s,'function BombService.Init()',[[function BombService.GetCarrier() return currentActor end
function BombService.Init()]],'bomb initialization')
 s=replace(s,'\tlocal endTime =\n','\tlocal lastPasser=nil\n\tlocal endTime =\n','bomb cycle state')
 s=replace(s,'\t\tif not isAlive(carrier) then','\t\tif not isAlive(carrier) then\n\t\t\tlastPasser=nil','carrier reassignment')
 s=replace(s,'\t\t\t\t\tif hasDodgeIFrames(candidate) then\n\t\t\t\t\t\tcontinue',[[					if hasDodgeIFrames(candidate) then
						PerfectWeave.Try(carrier,candidate,previousPositions[carrier.UserId],previousPositions[candidate.UserId],protectedUserId,protectedUntil)
						continue]],'immune tag check')
 s=replace(s,'Economy.Pass(oldCarrier,carrier)','lastPasser=oldCarrier\n\t\t\t\t\t\tEconomy.Pass(oldCarrier,carrier)','successful pass')
 s=replace(s,'\tlocal victim = carrier','\tif #aliveProvider()<=1 then BombService.Stop();return nil end\n\tlocal victim = carrier','final cancellation check')
 s=replace(s,'\tif victim and isAlive(victim) then','\tif victim and isAlive(victim) then\n\t\tEconomy.Elimination(lastPasser,victim)','elimination credit')
 return s
end
function P.Round(s)
 if s:find('-- HussFinalStandV11',1,true) then assert(s:find('Economy.FinalStand(alivePlayers)',1,true),'Incomplete Final Stand hook.');return s end
 assert(s:find('-- HussEconomyHooksV9',1,true),'Install V9 progression first.')
 return replace(s,'\t\tif finalDuel\n\t\t\tand not finalDuelAnnounced then',[[		if finalDuel
			and not finalDuelAnnounced then
			-- HussFinalStandV11
			Economy.FinalStand(alivePlayers)]],'final duel transition')
end
function P.Movement(s)
 if s:find('-- HussPerfectMovementV11',1,true) then assert(s:find('local function boostedSpeed',1,true),'Incomplete V11 boost.');return s end
 assert(s:find('-- HussShiftLockV7',1,true),'Install the V7 movement update first.')
 s=replace(s,'local function cameraOwnsFacing()',[[-- HussPerfectMovementV11
local function boostedSpeed(base)
 local untilTime=character and character:GetAttribute('HussPerfectBoostUntil')
 if player:GetAttribute('InRound')==true and type(untilTime)=='number' and workspace:GetServerTimeNow()<untilTime then return base+6 end
 return base
end
local function cameraOwnsFacing()]],'movement helpers')
 local function speed(pattern,expected)
  local n;s,n=s:gsub(pattern,function(left,name) return left..'boostedSpeed('..name..')' end);assert(n==expected,'Movement assignments changed.')
 end
 speed('(humanoid%.WalkSpeed%s*=%s*)(WALK_SPEED)',3)
 speed('(humanoid%.WalkSpeed%s*=%s*)(SPRINT_SPEED)',2)
 speed('(desiredSpeed%s*=%s*)(WALK_SPEED)',1)
 speed('(desiredSpeed%s*=%s*)(SPRINT_SPEED)',1)
 return s
end
return P

end)()
local PracticePatch=(function()
-- Strict practice integration; multiplayer economy flow remains unchanged.
local Patch={}
function Patch.Round(source)
 local marker='-- HussPracticeHooksV11'
 if source:find(marker,1,true) then
  assert(source:find('Practice.Run(player,{',1,true) and source:find('Practice.Stop()',1,true),'Incomplete V11 practice integration. Nothing changed.');return source
 end
 assert(source:find('-- HussEconomyHooksV9',1,true),'Install V9 before practice. Nothing changed.')
 local function replace(old,new)
  local a,b=source:find(old,1,true);assert(a and not source:find(old,b+1,true),'Round service differs: '..old:sub(1,50)..'. Nothing changed.')
  source=source:sub(1,a-1)..new..source:sub(b+1)
 end
 replace('local RoundService = {}',marker.."\nlocal Practice=require(script.Parent:WaitForChild('PracticeServiceV11'))\nlocal RoundService = {}")
 local a=assert(source:find('local function runSoloPractice()',1,true))
 local b=assert(source:find('------------------------------------------------------------\n-- AWARD WIN',a+1,true))
 source=source:sub(1,a-1)..[[local function runSoloPractice()
 Economy.AbortRound()
 local players=getMatchmakingPlayers()
 if #players~=1 then return end
 local player=players[1]
 Practice.Run(player,{
  Spawns=getSpawnParts(),Ground=groundCharacter,Duration=math.max(60,GameConfig.SoloPracticeSeconds),
  Running=function() return running end,
  Send=function(state,timeLeft,alive)
   roundRemote:FireAllClients({State=state,TimeLeft=timeLeft,Alive=alive,Winner=''})
  end,
 })
end

]]..source:sub(b)
 replace('local function returnEveryoneToLobby()','local function returnEveryoneToLobby()\n\tPractice.Stop()')
 replace('\t\tif not success then','\t\tif not success then\n\t\t\tPractice.Stop()')
 return source
end
return Patch

end)()
local MainPatch=(function()
return function(source)
 local marker='-- HussExpansionBootV11'
 local call="require(Services:WaitForChild('CosmeticsServiceV11')).Init()"
 if source:find(marker,1,true) then assert(source:find(call,1,true),'Incomplete V11 boot. Nothing changed.');return source end
 local old="require(Services:WaitForChild('EconomyServiceV9')).Init()"
 local a,b=source:find(old,1,true);assert(a and not source:find(old,b+1,true),'Unexpected economy startup. Nothing changed.')
 return source:sub(1,a-1)..old..'\n'..marker..'\n'..call..source:sub(b+1)
end

end)()
local function adapt(kind,source)
 local variant,why=Compat.Classify(kind,source)
 assert(variant,why)
 -- Normalize only harmless file encoding/newline/outer whitespace differences.
 source=normalize(source)
 if variant=='V11' then return source end
 if variant=='Uploaded' then source=EconomyPatch[kind](source) end
 if kind=='Main' then source=MainPatch(source)
 elseif kind=='Bomb' then source=CorePatch.Bomb(source)
 elseif kind=='Round' then source=PracticePatch.Round(CorePatch.Round(source)) end
 local final,detail=Compat.Classify(kind,source)
 assert(final=='V11','Internal '..kind..' output verification failed: '..tostring(detail)..'. Nothing changed.')
 return source
end
function Compat.Main(source) return adapt('Main',source) end
function Compat.Round(source) return adapt('Round',source) end
function Compat.Bomb(source) return adapt('Bomb',source) end
return Compat

end)()

local uiAdapter=(function()
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

end)()

local movementAdapter=(function()
-- V11 server combat/stat hooks and movement integration. No cooldown changes.
local P={}
local function replace(s,old,new,label)
 local a,b=s:find(old,1,true);assert(a and not s:find(old,b+1,true),'Unexpected '..label..'. Nothing changed.')
 return s:sub(1,a-1)..new..s:sub(b+1)
end
function P.Movement(s)
 if s:find('-- HussPerfectMovementV11',1,true) then assert(s:find('local function boostedSpeed',1,true),'Incomplete V11 boost.');return s end
 assert(s:find('-- HussShiftLockV7',1,true),'Install the V7 movement update first.')
 s=replace(s,'local function cameraOwnsFacing()',[[-- HussPerfectMovementV11
local function boostedSpeed(base)
 local untilTime=character and character:GetAttribute('HussPerfectBoostUntil')
 if player:GetAttribute('InRound')==true and type(untilTime)=='number' and workspace:GetServerTimeNow()<untilTime then return base+6 end
 return base
end
local function cameraOwnsFacing()]],'movement helpers')
 local function speed(pattern,expected)
  local n;s,n=s:gsub(pattern,function(left,name) return left..'boostedSpeed('..name..')' end);assert(n==expected,'Movement assignments changed.')
 end
 speed('(humanoid%.WalkSpeed%s*=%s*)(WALK_SPEED)',3)
 speed('(humanoid%.WalkSpeed%s*=%s*)(SPRINT_SPEED)',2)
 speed('(desiredSpeed%s*=%s*)(WALK_SPEED)',1)
 speed('(desiredSpeed%s*=%s*)(SPRINT_SPEED)',1)
 return s
end
local function canonical(s) return s:gsub('\r\n','\n'):match('^%s*(.-)%s*$') end
local function fingerprint(s)
 s=canonical(s);local a,b=1,0
 for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
 return #s..':'..(b*65536+a)
end
local expected={["22071:2609543984"]='V7',["22462:528550178"]='V11'}
local apply=P.Movement
function P.IdentifyMovement(source)
 local id=fingerprint(source);local version=expected[id]
 assert(version,'SnappyMovement source is not a verified V7/V11 version (fingerprint '..id..'). No changes were made; provide the current source for review.')
 return version
end
function P.Movement(source)
 local version=P.IdentifyMovement(source)
 if version=='V11' then return source end
 local result=apply(source:gsub('\r\n','\n'))
 assert(fingerprint(result)=="22462:528550178",'Movement adapter output differs from the verified V11 result.')
 return result
end
return P

end)()

local dependencyValidator=(function()
local function canonical(s) return s:gsub('\r\n','\n'):match('^%s*(.-)%s*$') end
local function fingerprint(s)
 s=canonical(s);local a,b=1,0
 for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
 return #s..':'..(b*65536+a)
end
local known={
 Remotes={["1719:1737753784"]=true},
 MapVote={["4995:3112494590"]=true},
 AFK={["3768:2633261036"]=true},
 ClientMain={["1025:267261944"]=true},
 Dodge={["9272:1815088008"]=true,["9680:1349820738"]=true},
}
local configTypes={MinimumPlayers="number",AbsoluteMinimumPlayers="number",AutoStartMinSeconds="number",AutoStartMaxSeconds="number",ForceStartAfterSeconds="number",IntermissionSeconds="number",RoundStartCountdownSeconds="number",ResultsSeconds="number",SoloPracticeSeconds="number",MapName="string",NormalBombFuseSeconds="number",FinalDuelBombFuseSeconds="number",BombTagRadius="number",AntiTagBackSeconds="number",NewCarrierLockSeconds="number",BetweenBombsSeconds="number",TagCheckInterval="number",DebugPrints="boolean"}
local configFingerprint="3381:79344004"
-- Validates the existing dependency graph without requiring live game modules.
local D={}
function D.Validate(c)
 local issues,sources={},{}
 local function issue(message) table.insert(issues,message) end
 local function path(o) return o and o:GetFullName() or '<missing>' end
 local function child(parent,name,class,optional)
  if not parent then return nil end
  local matches={}
  for _,o in ipairs(parent:GetChildren()) do if o.Name==name then table.insert(matches,o) end end
  if #matches==0 and optional then return nil end
  if #matches~=1 then issue(path(parent)..'.'..name..': expected exactly one '..class..', found '..#matches);return nil end
  local o=matches[1]
  if not o:IsA(class) then issue(path(o)..': expected '..class..', found '..o.ClassName);return nil end
  return o
 end
 local function named(root,name,class)
  if not root then return nil end
  local found={}
  for _,o in ipairs(root:GetDescendants()) do if o.Name==name then table.insert(found,o) end end
  if #found~=1 then issue(path(root)..': expected one '..name..', found '..#found);return nil end
  local o=found[1]
  if not o:IsA(class) then issue(path(o)..': expected '..class..', found '..o.ClassName);return nil end
  return o
 end
 local function verified(o,kind)
  if not o then return end
  table.insert(sources,o)
  local ok,source=pcall(function() return o.Source end)
  if not ok then issue(path(o)..': Source is not readable');return end
  local id=fingerprint(source)
  if not known[kind][id] then issue(path(o)..': unknown '..kind..' source ('..id..'); preserve it and review compatibility before installation') end
  if o:IsA('BaseScript') and o.Disabled then issue(path(o)..': required script is disabled') end
 end
 local shared=child(c.replicated,'Shared','Folder')
 local net=child(shared,'Net','Folder')
 local configFolder=child(shared,'Config','Folder')
 local remotes=child(net,'Remotes','ModuleScript')
 local config=child(configFolder,'GameConfig','ModuleScript')
 verified(remotes,'Remotes')
 verified(child(c.services,'BombTagMapVoteServiceV6','ModuleScript'),'MapVote')
 verified(named(c.server,'BombTagAFKServer','Script'),'AFK')
 verified(named(c.server,'DodgeIFrameServer','Script'),'Dodge')
 local client=named(c.starter,'ClientMain','LocalScript');verified(client,'ClientMain')
 if client and c.hud then
  local controllers=child(client.Parent,'Controllers','Folder')
  local actual=child(controllers,'HudController','ModuleScript')
  if actual and actual~=c.hud then issue(path(client)..': starts a different HudController than the selected installer target') end
 end
 child(c.replicated,'BombTagVoteV6','RemoteEvent')
 child(c.replicated,'BombTagAFKRequest','RemoteEvent')
 child(net,'DodgeIFrameRequest','RemoteEvent',true)
 local remoteFolder=child(c.replicated,'BombTagRemotes','Folder',true)
 child(remoteFolder,'RoundState','RemoteEvent',true)
 child(remoteFolder,'BombState','RemoteEvent',true)
 -- Known Remotes.Init and DodgeIFrameServer create these optional remotes at runtime.
 if config then
  table.insert(sources,config)
  local seen,values,lines={},{},{}
  local ok,source=pcall(function() return config.Source end)
  if not ok then issue(path(config)..': Source is not readable') else
   for line in (source:gsub('\r\n','\n')..'\n'):gmatch('(.-)\n') do
    local left,key,value=line:match('^(%s*GameConfig%.([%w_]+)%s*=%s*)(.-)%s*$')
    if key then
     local kind=configTypes[key]
     if not kind or seen[key] then issue(path(config)..': unsupported or duplicate assignment '..key) end
     seen[key]=true
     if kind=='number' then
      local n=tonumber(value)
      if not n or n~=n or math.abs(n)==math.huge then issue(path(config)..': '..key..' must be a finite numeric literal')
      else values[key]=n;if n<0 then issue(path(config)..': '..key..' must not be negative') end end
     elseif kind=='boolean' then
      if value~='true' and value~='false' then issue(path(config)..': '..key..' must be true or false') end
     elseif kind=='string' then
      local q=value:sub(1,1);local content=value:sub(2,-2)
      if (q~='"' and q~="'") or value:sub(-1)~=q or #content==0 or content:find('[%c\\"\']') then
       issue(path(config)..': MapName must be a plain quoted map name')
      end
     end
     line=left..'<'..key..'>'
    end
    table.insert(lines,line)
   end
   for key in pairs(configTypes) do if not seen[key] then issue(path(config)..': missing GameConfig.'..key) end end
   if fingerprint(table.concat(lines,'\n'))~=configFingerprint then
    issue(path(config)..': configuration structure differs from the reviewed module; only its literal settings may vary')
   end
   for _,key in ipairs({'AbsoluteMinimumPlayers','MinimumPlayers','NormalBombFuseSeconds','FinalDuelBombFuseSeconds','BombTagRadius','TagCheckInterval'}) do
    if values[key] and values[key]<=0 then issue(path(config)..': '..key..' must be positive') end
   end
   for _,key in ipairs({'AbsoluteMinimumPlayers','MinimumPlayers'}) do
    if values[key] and values[key]%1~=0 then issue(path(config)..': '..key..' must be a whole player count') end
   end
   if values.AutoStartMaxSeconds and values.AutoStartMinSeconds and values.AutoStartMaxSeconds<values.AutoStartMinSeconds then
    issue(path(config)..': AutoStartMaxSeconds is smaller than AutoStartMinSeconds')
   end
  end
 end
 return {issues=issues,sources=sources}
end
return D

end)()

local worldBuilder=(function()
--!nonstrict
-- HussWorld11. Staged clones only; never edits the running world or Lighting.
local B={}
local V,C,R,M=Vector3.new,CFrame.new,Color3.fromRGB,Enum.Material
local ink,white,gold=R(18,27,36),R(255,250,233),R(255,205,35)
local teal,pink=R(34,218,229),R(236,89,159)
local function group(parent,name,class) local o=Instance.new(class or 'Model');o.Name=name;o.Parent=parent;return o end
local function part(parent,name,x,y,z,w,h,d,color,solid,rot,class)
 local o=Instance.new(class or 'Part');o.Name=name;o.Size=V(w,h,d);o.CFrame=C(x,y,z)*(rot or CFrame.identity);o.Color=color;o.Material=M.SmoothPlastic
 o.Anchored=true;o.CanCollide=solid==true;o.CanTouch=false;o.CanQuery=o.CanCollide;o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth;o.Parent=parent;return o
end
local function beam(parent,name,a,b,w,h,color,solid)
 local p=(a+b)/2;local delta=b-a;local up=math.abs(delta.Unit.Y)>.99 and V(1,0,0) or V(0,1,0);return part(parent,name,p.X,p.Y,p.Z,w,h,delta.Magnitude,color,solid,CFrame.lookAt(a,b,up).Rotation)
end
local function ball(parent,name,x,y,z,size,color)
 local o=part(parent,name,x,y,z,size,size,size,color);o.Shape=Enum.PartType.Ball;return o
end
local function cylinder(parent,name,x,y,z,d,h,color,solid)
 local o=part(parent,name,x,y,z,h,d,d,color,solid,CFrame.Angles(0,0,math.pi/2));o.Shape=Enum.PartType.Cylinder;return o
end
local function ui(parent,class,props)
 local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o
end
local function rounded(parent,r) ui(parent,'UICorner',{CornerRadius=UDim.new(0,r)}) end
local function edge(parent,color,w) ui(parent,'UIStroke',{Color=color,Thickness=w or 4,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function lettering(parent,name,value,position,size,color)
 local o=ui(parent,'TextLabel',{Name=name,Text=value,Position=position,Size=size,BackgroundTransparency=1,Font=Enum.Font.FredokaOne,TextScaled=true,TextWrapped=true,TextColor3=color or white,TextStrokeTransparency=1,ZIndex=4})
 ui(o,'UIStroke',{Color=ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual});return o
end
local function face(panel,title,sub,color,board)
 local old=panel:FindFirstChildOfClass('SurfaceGui');if old then old:Destroy() end
 local gui=ui(panel,'SurfaceGui',{Name=board and 'BoardGui' or 'HussSignV11',Face=Enum.NormalId.Back,SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud,PixelsPerStud=80,LightInfluence=0,Brightness=1,AlwaysOnTop=false,MaxDistance=160})
 local body=ui(gui,'Frame',{Name='Body',Size=UDim2.fromScale(1,1),BackgroundColor3=board and ink or color,BorderSizePixel=0});rounded(body,18);edge(body,ink,8)
 ui(body,'UIGradient',{Color=ColorSequence.new(white,R(129,163,159)),Rotation=90})
 local header=board and .17 or 1
 for row=0,3 do for col=0,11 do if (row+col)%2==0 then
  ui(body,'Frame',{Name='Checker',Position=UDim2.fromScale(col/12,row*header/4),Size=UDim2.fromScale(1/12,header/4),BackgroundColor3=white,BackgroundTransparency=.9,BorderSizePixel=0,ZIndex=2})
 end end end
 local shine=ui(body,'Frame',{Name='Gloss',Position=UDim2.fromScale(.015,.015),Size=UDim2.fromScale(.97,header*.37),BackgroundColor3=white,BackgroundTransparency=.86,BorderSizePixel=0,ZIndex=2});rounded(shine,12)
 local rim=ui(body,'Frame',{Name='InnerRim',Position=UDim2.fromScale(.01,.025),Size=UDim2.fromScale(.98,.95),BackgroundTransparency=1,ZIndex=3});rounded(rim,15);edge(rim,board and color or color:Lerp(white,.55),5)
 lettering(body,'Heading',title,UDim2.fromScale(.035,.04),UDim2.fromScale(.93,board and .12 or sub~='' and .51 or .9),board and color or white)
 if board then
  for i=1,10 do lettering(body,'Row'..i,'',UDim2.fromScale(.055,.18+(i-1)*.068),UDim2.fromScale(.89,.058),white).Font=Enum.Font.GothamBlack end
  lettering(body,'Status','Loading server records…',UDim2.fromScale(.04,.89),UDim2.fromScale(.92,.062),color).Font=Enum.Font.GothamBold
 elseif sub~='' then lettering(body,'Subtitle',sub,UDim2.fromScale(.05,.61),UDim2.fromScale(.9,.29),white).Font=Enum.Font.GothamBlack end
 return gui
end
local function sign(parent,title,sub,x,y,z,w,h,color,rot)
 local p=part(parent,title,x,y,z,w,h,.5,ink,false,rot);face(p,title,sub,color);return p
end
local function bomb(parent,x,y,z,s,color)
 local g=group(parent,'Bomb display')
 cylinder(g,'Bomb base',x,y+s*.14,z,s*1.15,s*.28,ink)
 local orb=ball(g,'Bomb shell',x,y+s*.75,z,s,color);orb.Material=M.Metal
 cylinder(g,'Fuse cap',x,y+s*1.26,z,s*.28,s*.18,gold)
 beam(g,'Curved fuse',V(x,y+s*1.32,z),V(x+s*.22,y+s*1.62,z),s*.07,s*.07,white)
 local ember=ball(g,'Fuse ember',x+s*.22,y+s*1.64,z,s*.14,gold);ember.Material=M.Neon
 for i=-1,1 do part(g,'Shell shine',x+s*.17+i*s*.1,y+s*.91,z+s*.435,s*.055,s*.3,s*.06,white,false,CFrame.Angles(0,0,-.2)) end
 return g
end
local function rail(parent,a,b,color)
 beam(parent,'Guard collision',a+V(0,1.6,0),b+V(0,1.6,0),.5,3.2,ink,true).Transparency=1
 beam(parent,'Bright handrail',a+V(0,3.3,0),b+V(0,3.3,0),.38,.38,color)
 beam(parent,'Lower rail',a+V(0,1,0),b+V(0,1,0),.2,.2,ink)
 local count=math.ceil((b-a).Magnitude/10);for i=0,count do local q=a:Lerp(b,i/count);part(parent,'Rail post',q.X,q.Y+1.6,q.Z,.35,3.2,.35,ink) end
end
local pavingLevel=0
local function paving(parent,x,z,w,d,color,y)
 pavingLevel+=1;y=(y or 0)+pavingLevel*.002
 local p=part(parent,'Inlaid route',x,(y or 0)+.055,z,w,.07,d,color);p.Material=M.Concrete
 for xx=-w/2+8,w/2-1,8 do part(parent,'Paving seam',x+xx,(y or 0)+.097,z,.06,.012,d,color:Lerp(ink,.17)) end
 for zz=-d/2+8,d/2-1,8 do part(parent,'Paving seam',x,(y or 0)+.097,z+zz,w,.012,.06,color:Lerp(ink,.17)) end
end
local function deck(parent,e,name,x,z,w,d,y,color)
 part(parent,name,x,y-.6,z,w,1.2,d,color,true)
 for _,xx in ipairs({x-w/2+2,x+w/2-2}) do for _,zz in ipairs({z-d/2+2,z+d/2-2}) do part(parent,'Deck pillar',xx,(y-1.2)/2,zz,1.6,y-1.2,1.6,ink,true) end end
 paving(parent,x,z,w-.8,d-.8,color:Lerp(white,.1),y)
 table.insert(e.Decks,{Name=name,X=x,Z=z,Y=y,Width=w,Depth=d,Clearance=y-1.2,SolidBase=false})
end
local function ramp(parent,e,name,x1,z1,x2,z2,rise,width,color)
 local a,b=V(x1,0,z1),V(x2,rise,z2);local delta=V(x2-x1,0,z2-z1);local run=delta.Magnitude;local q=(a+b)/2
 assert(width>=24 and math.deg(math.atan(rise/run))<=14,'Unsafe no-jump route')
 local turn=CFrame.lookAt(q,q-delta).Rotation
 part(parent,name,q.X,q.Y,q.Z,width,rise,run,color,true,turn,'WedgePart'):SetAttribute('NoJumpRoute',true)
 local side=V(delta.Z,0,-delta.X).Unit*(width/2-.25);rail(parent,a+side,b+side,gold);rail(parent,a-side,b-side,gold)
 for i=1,math.floor(run/6)-1 do local at=a:Lerp(b,i*6/run);part(parent,'Flush grip',at.X,at.Y+.025,at.Z,width-1,.03,.16,white,false,turn*CFrame.Angles(-math.atan(rise/run),0,0)) end
 table.insert(e.Ramps,{Name=name,X1=x1,Z1=z1,X2=x2,Z2=z2,BaseY=0,Rise=rise,Run=run,Width=width,SlopeDegrees=math.deg(math.atan(rise/run))})
end
local function building(parent,name,x,z,w,d,h,color,accent)
 local g=group(parent,name);local body=part(g,'Smooth facade collision',x,h/2,z,w,h,d,color,true);body.Material=M.Brick
 for _,y in ipairs({.4,h*.5,h-.4}) do part(g,'Facade trim',x,y,z,w+.5,.55,d+.5,white) end
 for _,s in ipairs({-1,1}) do
  for xx=-w/2+4,w/2-1,7 do
   part(g,'Window recess',x+xx,h*.48,z+s*(d/2+.12),4.6,6,.2,ink)
   part(g,'Tinted glass',x+xx,h*.48,z+s*(d/2+.25),3.9,5.3,.13,accent:Lerp(ink,.35))
   part(g,'Window bar',x+xx,h*.48,z+s*(d/2+.34),.16,5.3,.12,white)
   part(g,'Window sill',x+xx,h*.48-2.9,z+s*(d/2+.38),5,.35,.65,white)
  end
  part(g,'Corner upright',x+s*(w/2-.4),h/2,z+d/2+.1,.8,h,.4,white)
  part(g,'Rooftop rim',x+s*(w/2-.2),h+1.5,z,.5,3,d,ink)
 end
 part(g,'Roof coping',x,h+.3,z,w+1,.6,d+1,accent)
 -- Facades use one smooth solid; glazing, awnings and service details cannot snag a dodge.
 part(g,'Closed door frame',x,3.4,z+d/2+.37,5,6.8,.45,white)
 part(g,'Closed door',x,3.1,z+d/2+.65,4.3,6.2,.12,ink)
 part(g,'Door handle',x+1.3,3,z+d/2+.75,.18,.8,.14,gold)
 for _,side in ipairs({-1,1}) do for zz=-d/2+5,d/2-2,7 do
  part(g,'Side window frame',x+side*(w/2+.12),h*.5,z+zz,.2,6,4.5,ink)
  part(g,'Side glazing',x+side*(w/2+.25),h*.5,z+zz,.12,5.3,3.8,accent:Lerp(white,.2))
  part(g,'Side mullion',x+side*(w/2+.32),h*.5,z+zz,.1,5.3,.18,white)
 end end
 if name=='Boom Bakery' or name=='Bomb Boutique' or name=='Fuse Flowers' or name=='Pop Arcade' then
  for i=0,math.floor((w-2)/2)-1 do part(g,'Shop canopy stripe',x-w/2+2+i*2,7.5,z+d/2+2,2,.3,4.2,i%2==0 and accent or white,false,CFrame.Angles(.1,0,0)) end
  for _,side in ipairs({-1,1}) do part(g,'Awning brace',x+side*(w*.38),6.9,z+d/2+1.4,.16,.2,3,ink,false,CFrame.Angles(-.3,0,0)) end
 else
  for i=0,2 do
   part(g,'Service vent',x-w*.3+i*w*.3,h+.9,z-d*.3,3.2,1.3,2.8,ink)
   for j=-1,1 do part(g,'Vent fin',x-w*.3+i*w*.3+j*.7,h+1.6,z-d*.3,.18,.08,2.5,white) end
  end
 end
 sign(g,name:upper(),'BOMB CO.',x,h-2,z+d/2+.5,w-2,3.4,accent)
 bomb(g,x,h+.6,z,math.min(9,w*.27),accent)
 return g
end
local function crate(parent,x,z,w,color)
 part(parent,'Cargo collision',x,w*.4,z,w,w*.8,w,color,true)
 for _,s in ipairs({-1,1}) do
  part(parent,'Steel crate band',x+s*w*.29,w*.4,z,.3,w*.8+.1,w+.1,ink)
  beam(parent,'Cargo diagonal',V(x-w/2,w*.12,z+s*(w/2+.1)),V(x+w/2,w*.68,z+s*(w/2+.1)),.4,.2,white)
 end
 sign(parent,'BOMB','',x,w*.42,z+w/2+.18,w*.64,w*.25,gold)
end
local function tree(parent,x,z,s,color)
 cylinder(parent,'Garden pot',x,.8,z,6*s,1.6,ink,true)
 part(parent,'Trunk',x,4*s,z,1.1*s,8*s,1.1*s,R(116,76,50))
 for i=0,3 do local a=i*2.2;local o=ball(parent,'Canopy',x+math.cos(a)*2*s,(8+i%2*2)*s,z+math.sin(a)*2*s,8*s,color);o.Size=V(8,6,8)*s end
end
local function inside(poly,x,z)
 local yes=false;local j=#poly
 for i,a in ipairs(poly) do local b=poly[j];if (a[2]>z)~=(b[2]>z) and x<(b[1]-a[1])*(z-a[2])/(b[2]-a[2])+a[1] then yes=not yes end;j=i end
 return yes
end
local function ground(model,e)
 local floor=part(model,'Floor',0,-2,0,e.Width,4,e.Depth,e.Color);floor.Transparency=1;model.PrimaryPart=floor
 local land=group(model,'Landform')
 for z=-e.Depth/2+1,e.Depth/2-1,2 do
  local xs={};local j=#e.Polygon
  for i,a in ipairs(e.Polygon) do local b=e.Polygon[j];if (a[2]>z)~=(b[2]>z) then table.insert(xs,a[1]+(z-a[2])*(b[1]-a[1])/(b[2]-a[2])) end;j=i end
  table.sort(xs);for i=1,#xs-1,2 do local p=part(land,'GroundTile',(xs[i]+xs[i+1])/2,-2,z,xs[i+1]-xs[i],4,2,e.Color,true);p.Material=e.Material end
 end
 e.Floor={Width=e.Width,Depth=e.Depth,Y=0}
 local border=group(model,'Bomb district boundary')
 for i,a in ipairs(e.Polygon) do local b=e.Polygon[i%#e.Polygon+1];local p,q=V(a[1],0,a[2]),V(b[1],0,b[2])
  beam(border,'Arena limit',p+V(0,30,0),q+V(0,30,0),1.2,60,ink,true).Transparency=1
  beam(border,'Foundation fascia',p-V(0,2,0),q-V(0,2,0),3,4,ink)
  rail(border,p,q,e.Accent)
  local count=math.ceil((q-p).Magnitude/22);for j=0,count do local at=p:Lerp(q,j/count);part(border,'Edge light pillar',at.X,3.5,at.Z,.6,7,.6,ink);local orb=ball(border,'Edge light',at.X,7.2,at.Z,1.2,e.Accent);orb.Material=M.Neon end
 end
end
local function spawns(model,e)
 local blocked={}
 for _,p in ipairs(model:GetDescendants()) do if p:IsA('BasePart') and p.CanCollide then
  local h=p.Size/2;local cf=p.CFrame;local ex=math.abs(cf.RightVector.X)*h.X+math.abs(cf.UpVector.X)*h.Y+math.abs(cf.LookVector.X)*h.Z
  local ey=math.abs(cf.RightVector.Y)*h.X+math.abs(cf.UpVector.Y)*h.Y+math.abs(cf.LookVector.Y)*h.Z;local ez=math.abs(cf.RightVector.Z)*h.X+math.abs(cf.UpVector.Z)*h.Y+math.abs(cf.LookVector.Z)*h.Z
  if p.Position.Y+ey>.3 then table.insert(blocked,{p.Position.X,p.Position.Z,ex+5,ez+5}) end
 end end
 local choices={}
 for x=-e.Width/2+12,e.Width/2-12,6 do for z=-e.Depth/2+12,e.Depth/2-12,6 do
  local clear=true;for _,o in ipairs({{0,0},{6,0},{-6,0},{0,6},{0,-6}}) do if not inside(e.Polygon,x+o[1],z+o[2]) then clear=false end end
  if clear then for _,b in ipairs(blocked) do if math.abs(x-b[1])<b[3] and math.abs(z-b[2])<b[4] then clear=false;break end end end
  if clear then table.insert(choices,{x,z}) end
 end end
 assert(#choices>=16,'Insufficient spawns in '..e.Name);local chosen={};local folder=group(model,'Spawns','Folder')
 for i=1,16 do
  local best,score=1,-1;for j,q in ipairs(choices) do local n=#chosen==0 and q[1]^2+q[2]^2 or math.huge;for _,v in ipairs(chosen) do n=math.min(n,(q[1]-v[1])^2+(q[2]-v[2])^2) end;if n>score then score=n;best=j end end
  local q=table.remove(choices,best);table.insert(chosen,q);local name=string.format('Spawn%02d',i)
  local p=part(folder,name,q[1],.25,q[2],4,.2,4,white);p.Transparency=1;p.CastShadow=false;table.insert(e.Spawns,{Name=name,X=q[1],Y=.25,Z=q[2]})
 end
end
local definitions={
 {Name='Fuseworks',Width=280,Depth=210,Polygon={{-140,-60},{-100,-105},{100,-105},{140,-60},{140,65},{103,105},{-98,105},{-140,65}},Color=R(119,133,145),Material=M.Concrete,Accent=R(255,166,37)},
 {Name='Detonator Plaza',Width=232,Depth=244,Polygon={{-48,-122},{48,-122},{116,-54},{116,54},{48,122},{-48,122},{-116,54},{-116,-54}},Color=R(103,152,117),Material=M.Grass,Accent=R(60,224,180)},
 {Name='Payload Port',Width=326,Depth=174,Polygon={{-163,-60},{-128,-87},{115,-87},{163,-35},{163,65},{115,87},{-125,87},{-163,52}},Color=R(156,168,173),Material=M.Concrete,Accent=R(58,194,247)},
}
local function buildFuse(model,e)
 local g=group(model,'Fuse assembly works')
 paving(g,0,35,162,84,R(186,189,179));paving(g,0,-59,180,42,R(153,166,177));paving(g,-45,-4,32,148,R(195,198,183));paving(g,45,-4,32,148,R(195,198,183))
 deck(g,e,'Assembly gantry',0,-58,152,28,8,R(99,140,156))
 for _,s in ipairs({-1,1}) do
  ramp(g,e,(s<0 and 'West' or 'East')..' gantry ramp',s*64,16,s*64,-44,8,24,R(176,188,186))
  building(g,s<0 and 'Fuse Lab' or 'Shell Press',s*106,3,32,38,23,R(93,122,145),e.Accent)
  building(g,s<0 and 'Packing' or 'Dispatch',s*102,-73,30,28,18,R(81,114,129),teal)
  for _,z in ipairs({54,82}) do crate(g,s*112,z,11,s<0 and e.Accent or teal) end
  rail(g,V(s*76,8,-44),V(s*76,8,-72),gold)
 end
 rail(g,V(-76,8,-72),V(76,8,-72),gold);rail(g,V(-52,8,-44),V(52,8,-44),gold)
 cylinder(g,'Reactor island collision',0,2.1,16,22,4.2,ink,true);bomb(g,0,4.2,16,16,e.Accent)
 for _,s in ipairs({-1,1}) do
  part(g,'Production arch column',s*24,11,71,2.5,22,2.5,ink,true);part(g,'Arch sleeve',s*24,9,71,3.3,4,3.3,e.Accent)
 end
 part(g,'Production arch beam',0,22.5,71,51,3,4,ink);sign(g,'FUSEWORKS','PASS THE PRESSURE',0,23,73.2,35,6,e.Accent)
 for i=-3,3 do part(g,'Route hazard stripe',i*5,.11,69,2.8,.035,8,gold,false,CFrame.Angles(0,-.3,0)) end
 for i=-2,2 do cylinder(g,'Vent stack',i*7,18,-95,4,10,ink);cylinder(g,'Vent collar',i*7,21,-95,5,1,e.Accent) end
end
local function buildPlaza(model,e)
 local g=group(model,'Detonator town square')
 paving(g,0,20,62,172,R(235,218,182));paving(g,0,20,190,34,R(235,218,182));paving(g,0,-64,113,47,R(194,188,177))
 deck(g,e,'Bomb balcony',0,-70,104,32,8,R(237,193,107))
 for _,s in ipairs({-1,1}) do
  ramp(g,e,(s<0 and 'West' or 'East')..' plaza promenade',s*40,0,s*40,-54,8,24,R(246,221,164))
  building(g,s<0 and 'Boom Bakery' or 'Pop Arcade',s*81,27,29,34,21,s<0 and R(220,145,102) or R(118,146,211),s<0 and gold or pink)
  building(g,s<0 and 'Fuse Flowers' or 'Bomb Boutique',s*50,81,29,25,17,s<0 and R(170,124,185) or R(116,168,171),s<0 and pink or teal)
  tree(g,s*88,-40,.95,R(59,154,94));tree(g,s*18,103,.75,R(80,169,92))
  rail(g,V(s*52,8,-54),V(s*52,8,-86),e.Accent)
 end
 rail(g,V(-52,8,-86),V(52,8,-86),e.Accent);rail(g,V(-28,8,-54),V(28,8,-54),e.Accent)
 building(g,'Detonator Hall',0,-103,48,18,24,R(118,162,144),gold)
 cylinder(g,'Plaza fountain collision',0,1.8,28,17,3.6,R(160,162,167),true);cylinder(g,'Fountain water',0,3.65,28,14,.2,teal);bomb(g,0,3.8,28,9,gold)
 sign(g,'DETONATOR PLAZA','KEEP YOUR COOL',0,18,-53.6,36,5,e.Accent)
 for _,s in ipairs({-1,1}) do part(g,'Balcony sign support',s*16,12,-56,.45,8,.45,ink) end
 for i=-4,4 do part(g,'Crosswalk',i*5,.12,53,3,.035,9,white) end
 for _,x in ipairs({-102,102}) do part(g,'Street lamp',x,6,13,.5,12,.5,ink);ball(g,'Lamp globe',x,12,13,2,gold) end
end
local function buildPort(model,e)
 local g=group(model,'Bomb cargo terminal')
 local water=part(g,'Harbor water',0,-1.3,0,370,.25,245,R(46,137,161));water.Material=M.Glass;water.Transparency=.2
 paving(g,0,0,285,32,R(193,190,166));paving(g,-40,54,194,30,R(202,201,185));paving(g,-40,-53,194,30,R(202,201,185))
 building(g,'Payload Depot',-79,0,52,48,25,R(72,118,148),gold)
 deck(g,e,'Dock lookout',79,0,44,54,8,R(107,158,182))
 ramp(g,e,'North loading ramp',79,-78,79,-27,8,24,R(205,196,164));ramp(g,e,'South loading ramp',79,78,79,27,8,24,R(205,196,164))
 rail(g,V(57,8,-27),V(57,8,27),teal);rail(g,V(101,8,-27),V(101,8,27),teal)
 for _,z in ipairs({-27,27}) do rail(g,V(57,8,z),V(67,8,z),teal);rail(g,V(91,8,z),V(101,8,z),teal) end
 for _,s in ipairs({-1,1}) do
  for i=0,2 do crate(g,4+i*16,s*53,12,({gold,teal,pink})[i+1]) end
  crate(g,-143,s*33,12,e.Accent);bomb(g,-139,0,s*60,7,gold)
 end
 local crane=group(g,'Gantry crane')
 for _,x in ipairs({-134,-111}) do part(crane,'Crane support',x,17,-54,3,34,3,gold,true);part(crane,'Crane foot',x,1,-54,8,2,8,ink) end
 part(crane,'Crane boom',-104,34,-54,72,4,5,gold);beam(crane,'Hoist cable',V(-79,32,-54),V(-79,13,-54),.22,.22,ink);bomb(crane,-79,9,-54,5,ink)
 local ship=group(g,'Offshore payload ship')
 part(ship,'Ship hull',-23,-.9,-110,111,5,25,R(43,63,88));part(ship,'Ship deck',-23,2,-110,104,1,23,white)
 part(ship,'Ship bow',40,-.9,-110,25,5,23,R(43,63,88),false,CFrame.Angles(0,math.pi/2,0),'WedgePart')
 for _,side in ipairs({-1,1}) do
  beam(ship,'Ship safety rail',V(-74,5,-110+side*10),V(27,5,-110+side*10),.25,.3,white)
  for x=-72,27,11 do part(ship,'Ship railing post',x,3.7,-110+side*10,.25,2.6,.25,ink) end
 end
 building(ship,'Harbor Tug',-66,-111,15,14,14,R(62,115,163),gold)
 for i=-1,2 do bomb(ship,i*19,2.8,-110,10,({teal,gold,pink})[(i+2)%3+1]) end
 sign(g,'PAYLOAD PORT','SPECIAL DELIVERY',79,17,1,30,5,e.Accent)
 for _,x in ipairs({65,93}) do part(g,'Lookout sign pole',x,11,0,.5,6,.5,ink) end
end
local builders={buildFuse,buildPlaza,buildPort}
local scales={['Sky Garden']=1.24,['Sunset Docks']=1.24,['Frostfall Village']=1.24,['Sunstone Bazaar']=1.24,['Neon District']=1.1,['Clockwork Foundry']=1.1,['Orbital Station']=1.1,['Stardust Carnival']=1.1,['Crystal Cavern']=1.1,['Emerald Ruins']=1.1,['Pirate Cove']=1.1,['Ember Keep']=1.1}
local function restyle(model)
 local list={};for _,o in ipairs(model:GetDescendants()) do if o:IsA('SurfaceGui') then table.insert(list,o) end end
 for _,gui in ipairs(list) do
  local panel=gui.Parent
  if panel and panel:IsA('BasePart') and gui.Name~='HussSignV11' and gui.Name~='BoardGui' then
   local labels={};for _,t in ipairs(gui:GetChildren()) do if t:IsA('TextLabel') then table.insert(labels,t) end end
   if #labels>0 then
    local title=labels[1].Text;local sub=#labels>1 and labels[2].Text or '';local color=labels[1].TextColor3 or gold;local oldFace=gui.Face
    face(panel,title,sub,color).Face=oldFace
   end
  end
 end
end
local function upgrade(model,factor)
 if model:GetAttribute('BombTagGenerated')=='HussWorld11' then return end
 assert(model:GetAttribute('BombTagGenerated')=='HussWorld4','Install the movement maps first: '..model.Name)
 local floor=model:FindFirstChild('Floor');assert(floor and floor:IsA('BasePart'),'Map Floor missing')
 local center=V(floor.Position.X,floor.Position.Y+floor.Size.Y/2,floor.Position.Z)
 for _,p in ipairs(model:GetDescendants()) do if p:IsA('BasePart') then p.Size*=factor;p.CFrame=C(center+(p.Position-center)*factor)*p.CFrame.Rotation end end
 model:SetAttribute('MapWidth',model:GetAttribute('MapWidth')*factor);model:SetAttribute('MapDepth',model:GetAttribute('MapDepth')*factor)
 model:SetAttribute('HussWorldScale',factor);model:SetAttribute('BombTagGenerated','HussWorld11');model:SetAttribute('MovementDesign','Wider authored routes; connected ramps; no jumping')
 restyle(model)
 local additions=group(model,'Bomb district identity');local count=0
 -- Roof-only displays preserve every established running route and spawn.
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA('BasePart') and (p.Name=='Roof coping' or p.Name=='Ventilation unit' or p.Name=='Roof ridge') and count<5 then
   count+=1;local top=p.Position.Y+p.Size.Y/2;local size=math.min(8,p.Size.X*.28+3)
   bomb(additions,p.Position.X,top+.2,p.Position.Z,size,({gold,teal,pink})[(count-1)%3+1])
  end
 end
 local sourceName=model.Name
 for _,o in ipairs(model:GetDescendants()) do if o:IsA('SurfaceGui') and o.Name=='HussSignV11' then
  local sub=o.Body:FindFirstChild('Subtitle');if sub then sub.Text='BOMB DISTRICT  •  '..sourceName:upper() end
 end end
end
local function lobbyUpgrade(original)
 local lobby=original:Clone();assert(lobby,'Unable to clone Lobby')
 local version=lobby:GetAttribute('HussLobbyVersion');assert(version==7 or version==11,'Install the V7 lobby before this expansion.')
 if version==11 then return lobby end
 local floor=lobby:FindFirstChild('Floor');assert(floor and floor:IsA('BasePart'),'Lobby floor missing')
 local origin=C(floor.Position.X,floor.Position.Y+floor.Size.Y/2,floor.Position.Z)*floor.CFrame.Rotation
 local addition=group(nil,'V11 Bomb Exchange')
 local gallery=lobby:FindFirstChild('Shaded galleries');if gallery then gallery:Destroy() end
 local categories={'Bombs','Trails','Titles','Emotes'};local accents={gold,teal,pink,R(151,114,246)}
 for i,category in ipairs(categories) do
  local s=i<=2 and -1 or 1;local z=i%2==1 and -17 or 20;local station=group(addition,category..' kiosk')
  local color=accents[i]
  part(station,'Kiosk backdrop',0,6,-5.5,24,12,1.2,ink,true)
  part(station,'Counter',0,2,4.7,23,4,4.8,color,true)
  part(station,'Counter rim',0,4.2,4.7,24,.4,5.2,white)
  for _,x in ipairs({-11,11}) do part(station,'Awning pole',x,6.5,1,1,13,1,ink,true) end
  part(station,'Canopy',0,13.2,0,27,.7,14,color)
  for stripe=-5,5 do part(station,'Canopy stripe',stripe*2.4,13.6,0,1.2,.04,14,white) end
  sign(station,category:upper(),category=='Bombs' and '25 BOMB SKINS' or category=='Trails' and '25 TRAIL EFFECTS' or category=='Titles' and 'MAKE A NAME' or 'SHOW YOUR STYLE',0,10.4,7.1,25,4.8,color)
  bomb(station,0,4.5,-1,6,color)
  local anchor=part(station,'Browse '..category,0,5.5,7.5,1,1,1,color);anchor.Transparency=1
  local prompt=ui(anchor,'ProximityPrompt',{Name='BrowseShop',ActionText='Browse '..category,ObjectText='BOMB EXCHANGE',KeyboardKeyCode=Enum.KeyCode.E,GamepadKeyCode=Enum.KeyCode.ButtonX,HoldDuration=0,MaxActivationDistance=14,RequiresLineOfSight=false})
  prompt:SetAttribute('HussShopCategory',category)
  local transform=origin*C(s*87,0,z)*CFrame.Angles(0,-s*math.pi/2,0)
  for _,p in ipairs(station:GetDescendants()) do if p:IsA('BasePart') then p.CFrame=transform*p.CFrame end end
 end
 local boards=group(addition,'Lobby leaderboards')
 for i,stat in ipairs({'Wins','Kills','FinalStands','GlobalWins'}) do
  local x=-54+(i-1)*36;local color=accents[i]
  local panel=part(boards,stat..' board',x,13,-74,28,13,.6,ink,true);panel:SetAttribute('HussBoardStat',stat)
  face(panel,stat=='FinalStands' and 'FINAL STANDS' or stat=='GlobalWins' and 'GLOBAL WINS' or stat:upper(),'',color,true)
  for _,s in ipairs({-1,1}) do part(boards,'Board stand',x+s*10,6.2,-74,1.2,2.4,2,color) end
 end
 for _,p in ipairs(boards:GetDescendants()) do if p:IsA('BasePart') then p.CFrame=origin*p.CFrame end end
 -- Remove the old rear text, which would sit directly behind the new scoreboards.
 local terrace=lobby:FindFirstChild('North terrace');local old=terrace and terrace:FindFirstChild('YOUR NEXT CHASE');if old then old:Destroy() end
 local banner=terrace and terrace:FindFirstChild('HUSS A BOMB');if banner and banner:IsA('BasePart') then banner.CFrame=origin*C(0,21,-52) end
 addition.Parent=lobby;restyle(lobby);lobby:SetAttribute('HussLobbyVersion',11)
 return lobby
end
function B.Build(library,lobby)
 assert(library and library:IsA('Folder') and lobby and lobby:IsA('Model'),'MapLibrary and Lobby are required.')
 local staged=group(nil,'MapLibrary','Folder');local newLobby;local geometry={}
 local ok,message=pcall(function()
  for name,factor in pairs(scales) do
   local source=library:FindFirstChild(name);assert(source and source:IsA('Model'),'Missing original movement map: '..name)
   local copy=source:Clone();assert(copy,'Unable to clone '..name);copy.Parent=staged;upgrade(copy,factor)
  end
  for index,definition in ipairs(definitions) do
   local existing=library:FindFirstChild(definition.Name);assert(not existing or existing:GetAttribute('BombTagGenerated')=='HussWorld11','Unrelated map has the new name '..definition.Name)
   local e=table.clone(definition);e.Version='HussWorld11';e.Ramps={};e.Decks={};e.Spawns={};e.Routes={};e.Obstacles={}
   local map=group(staged,e.Name);map:SetAttribute('BombTagGenerated','HussWorld11');map:SetAttribute('MapWidth',e.Width);map:SetAttribute('MapDepth',e.Depth);map:SetAttribute('DisplayName',e.Name);map:SetAttribute('MovementDesign','Two exits per elevation; wide no-jump routes')
   pavingLevel=0;ground(map,e);builders[index](map,e);spawns(map,e);table.insert(geometry,e)
  end
  -- Retain independently added maps rather than silently deleting user content.
  for _,other in ipairs(library:GetChildren()) do if not staged:FindFirstChild(other.Name) then local copy=other:Clone();assert(copy,'Unable to preserve '..other.Name);copy.Parent=staged end end
  newLobby=lobbyUpgrade(lobby)
 end)
 if not ok then staged:Destroy();if newLobby then newLobby:Destroy() end;error(message) end
 return {Library=staged,Lobby=newLobby,Geometry=geometry}
end
return B

end)()

local placementBuilder=(function()
-- Staged V11 lobby clearance: all fifteen arenas at their actual runtime positions.
local World={}
local V=Vector3.new
local function bounds(model,delta,out)
 out=out or {MinX=math.huge,MaxX=-math.huge,MinZ=math.huge,MaxZ=-math.huge}
 for _,p in ipairs(model:GetDescendants()) do if p:IsA('BasePart') then
  local c,h=p.CFrame,p.Size*.5
  local r,u,l=c.RightVector,c.UpVector,c.LookVector
  local x=math.abs(r.X)*h.X+math.abs(u.X)*h.Y+math.abs(l.X)*h.Z
  local z=math.abs(r.Z)*h.X+math.abs(u.Z)*h.Y+math.abs(l.Z)*h.Z
  local q=p.Position+delta
  out.MinX=math.min(out.MinX,q.X-x);out.MaxX=math.max(out.MaxX,q.X+x)
  out.MinZ=math.min(out.MinZ,q.Z-z);out.MaxZ=math.max(out.MaxZ,q.Z+z)
 end end
 assert(out.MinX<math.huge,'Missing world geometry. Nothing changed.')
 return out
end
local function clear(a,b,gap)
 return a.MaxX<=b.MinX-gap or a.MinX>=b.MaxX+gap or a.MaxZ<=b.MinZ-gap or a.MinZ>=b.MaxZ+gap
end
function World.Plan(lobby,library,maps,anchor)
 assert(lobby and lobby:IsA('Model') and library and maps and anchor and anchor:IsA('BasePart'),'Lobby or map containers missing. Nothing changed.')
 local spawn=lobby:FindFirstChild('LobbySpawn')
 assert(spawn and spawn:IsA('SpawnLocation'),'LobbySpawn is missing. Nothing changed.')
 local arena,count=nil,0
 for _,model in ipairs(library:GetChildren()) do if model:IsA('Model') then
  local floor=model:FindFirstChild('Floor',true) or model.PrimaryPart
  assert(floor and floor:IsA('BasePart'),'Map floor missing: '..model.Name)
  -- Match MapService and map voting: floor-top translation, no anchor rotation.
  local top=floor.Position+V(0,floor.Size.Y/2,0)
  arena=bounds(model,anchor.Position-top,arena);count+=1
 end end
 assert(count>0,'MapLibrary is empty. Nothing changed.')
 if #maps:GetDescendants()>0 then arena=bounds(maps,Vector3.zero,arena) end
 local box=bounds(lobby,Vector3.zero)
 local delta,gap=Vector3.zero,96
 if not clear(box,arena,gap-.01) then
  local options={V(arena.MinX-gap-.05-box.MaxX,0,0),V(arena.MaxX+gap+.05-box.MinX,0,0),V(0,0,arena.MinZ-gap-.05-box.MaxZ),V(0,0,arena.MaxZ+gap+.05-box.MinZ)}
  delta=options[1]
  for _,offset in ipairs(options) do if offset.Magnitude<delta.Magnitude then delta=offset end end
 end
 return {Lobby=lobby,Spawn=spawn,OldParent=lobby.Parent,OldSpawnPosition=spawn.Position,OldPivot=lobby:GetPivot(),NewPivot=lobby:GetPivot()+delta,Delta=delta,ArenaBounds=arena,Gap=gap,TemplateCount=count}
end
function World.Apply(plan)
 assert(plan.Lobby.Parent==plan.OldParent and plan.Lobby:FindFirstChild('LobbySpawn')==plan.Spawn,'Lobby changed during installation.')
 if plan.Delta.Magnitude>0 then plan.Lobby:PivotTo(plan.NewPivot) end
 assert((plan.Spawn.Position-plan.OldSpawnPosition-plan.Delta).Magnitude<.02,'Lobby spawn alignment failed.')
 assert(clear(bounds(plan.Lobby,Vector3.zero),plan.ArenaBounds,plan.Gap-.01),'Lobby clearance failed.')
end
return World

end)()

local economySource=[==[--!nonstrict
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
]==]

local catalogSource=[==[--!nonstrict
-- HussCatalogV11: every item is bought with earned Coins; cosmetic effects only.
local C={Items={},ById={},Categories={'Bombs','Trails','Titles','Emotes'},Defaults={Bombs='bomb_classic',Trails='default',Titles='title_rookie',Emotes='emote_wave'}}
local function add(category,rows)
 for _,r in ipairs(rows) do
  local item={id=r[1],name=r[2],price=r[3],color=r[4],style=r[5],description=r[6],rarity=r[7] or 'Common',category=category}
  assert(not C.ById[item.id],'Duplicate catalog ID');C.ById[item.id]=item;table.insert(C.Items,item)
 end
end
add('Bombs',{
 {'bomb_classic','Classic Fuse',0,{44,48,58},'smooth','The original black bomb and golden fuse.'},
 {'bomb_cherry','Cherry Pop',200,{255,69,92},'smooth','A juicy red shell with a bright fuse.'},
 {'bomb_cobalt','Cobalt Core',250,{47,134,255},'banded','Electric blue with a steel equator.'},
 {'bomb_mint','Mint Condition',300,{78,244,183},'banded','Fresh mint panels and a cool band.'},
 {'bomb_taxi','Taxi Trouble',350,{255,211,48},'hazard','Yellow caution markings on a hot delivery.'},
 {'bomb_candy','Candy Capsule',400,{255,123,206},'banded','Pink sugar stripes with a white highlight.'},
 {'bomb_orange','Citrus Charge',450,{255,157,45},'panel','A peeled orange pattern with plenty of punch.'},
 {'bomb_arctic','Arctic Fuse',500,{140,234,255},'orb','Icy light locked inside a frosted shell.','Rare'},
 {'bomb_ember','Ember Egg',600,{255,106,43},'reactor','A glowing ember inside a dark cage.','Rare'},
 {'bomb_toxic','Toxic Tank',700,{143,255,60},'hazard','Acid green warning stripes. Handle carefully.','Rare'},
 {'bomb_royal','Royal Rumble',800,{177,105,255},'ring','Purple enamel with a golden orbit.','Rare'},
 {'bomb_disco','Disco Disaster',900,{233,109,255},'panel','Bright mirrored facets ready for the dance floor.','Rare'},
 {'bomb_gift','Surprise Package',1000,{255,85,129},'gift','A wrapped present with an explosive bow.','Rare'},
 {'bomb_bee','Bumble Blast',1100,{255,213,60},'banded','Black and yellow stripes with a busy fuse.','Rare'},
 {'bomb_prism','Prism Pop',1250,{147,203,255},'panel','A pastel crystal with contrasting facets.','Epic'},
 {'bomb_saturn','Saturn Sphere',1400,{246,179,115},'ring','A little planet with a tilted orbit.','Epic'},
 {'bomb_abyss','Abyss Pearl',1600,{99,88,215},'orb','Deep violet light under a midnight shell.','Epic'},
 {'bomb_spike','Iron Urchin',1800,{150,174,193},'spike','A metal shell wearing a ring of blunt studs.','Epic'},
 {'bomb_plasma','Plasma Pulse',2000,{86,255,238},'reactor','A cyan reactor with a bright inner core.','Epic'},
 {'bomb_sakura','Sakura Surprise',2200,{255,175,207},'orb','Soft blossom pink with pearly accents.','Epic'},
 {'bomb_gold','Golden Fuse',2500,{255,207,62},'banded','Polished gold for a very expensive mistake.','Legendary'},
 {'bomb_void','Void Star',2800,{139,78,246},'spike','Dark violet armor around an eerie star.','Legendary'},
 {'bomb_solar','Solar Furnace',3200,{255,158,54},'reactor','A small sun held inside its safety cage.','Legendary'},
 {'bomb_nova','Supernova',3600,{255,89,167},'ring','A pink stellar core with a luminous orbit.','Legendary'},
 {'bomb_champion','Champion Charge',4200,{255,227,104},'gift','A golden trophy package for the last survivor.','Legendary'},
})
add('Trails',{
 {'default','Classic',0,{125,244,255},'ribbon','The familiar cyan sprint and golden weave.'},
 {'aqua','Arctic Rush',250,{72,211,255},'ribbon','A crisp blue ribbon for clean escapes.'},
 {'sunset','Solar Rush',400,{255,161,74},'sparks','Orange embers follow your acceleration.'},
 {'royal','Royal Rush',600,{172,116,255},'stars','Violet stars mark a royal escape.','Rare'},
 {'lime','Toxic Rush',800,{157,255,85},'bubbles','Bright green bubbles spill behind you.','Rare'},
 {'rose','Candy Rush',1000,{255,117,180},'confetti','Pink candy confetti follows every burst.','Rare'},
 {'trail_ice','Ice Shards',500,{179,242,255},'sparks','Pale crystal sparks scatter from your heels.'},
 {'trail_smoke','Smoke Screen',550,{170,185,202},'smoke','A soft silver plume marks your path.'},
 {'trail_coins','Coin Shower',650,{255,224,85},'confetti','Golden flecks make every run look valuable.','Rare'},
 {'trail_ocean','Ocean Foam',700,{73,238,218},'bubbles','Turquoise bubbles wash across your wake.','Rare'},
 {'trail_berry','Berry Blast',850,{189,72,220},'pulse','A rich berry pulse surges behind you.','Rare'},
 {'trail_volt','Voltage',950,{255,242,68},'lightning','A jagged yellow flash follows quick turns.','Rare'},
 {'trail_petals','Petal Parade',1100,{255,185,214},'confetti','Pastel petals drift across the arena.','Rare'},
 {'trail_cosmic','Cosmic Dust',1250,{141,142,255},'stars','A starlit indigo path for close calls.','Epic'},
 {'trail_lava','Lava Leak',1400,{255,79,43},'sparks','Hot red sparks burst from your sprint.','Epic'},
 {'trail_ghost','Ghost Step',1500,{207,244,229},'smoke','A pale mist traces your narrow escapes.','Epic'},
 {'trail_neon','Neon Circuit',1700,{53,255,170},'lightning','Green circuit flashes race along your trail.','Epic'},
 {'trail_party','Party Fuse',1900,{255,132,222},'confetti','Bright party pieces make a joyful mess.','Epic'},
 {'trail_halo','Golden Halo',2100,{255,224,125},'pulse','A warm golden pulse lights the finish.','Epic'},
 {'trail_blizzard','Blizzard',2300,{195,235,255},'stars','A cold burst of snowbright stars.','Epic'},
 {'trail_comet','Comet Tail',2600,{93,203,255},'sparks','Brilliant blue sparks streak through the arena.','Legendary'},
 {'trail_eclipse','Eclipse Wake',2900,{175,108,255},'smoke','Purple dusk follows your footsteps.','Legendary'},
 {'trail_overload','Overload',3200,{255,90,89},'lightning','Scarlet energy crackles after each weave.','Legendary'},
 {'trail_supernova','Supernova Wake',3600,{255,155,95},'pulse','A bright solar pulse marks a perfect escape.','Legendary'},
 {'trail_celebrate','Victory Parade',4200,{255,223,71},'confetti','A shower of gold for the arena champion.','Legendary'},
})
add('Titles',{
 {'title_rookie','Fuse Rookie',0,{235,243,255},'title','Your first name in the bomb arena.'},
 {'title_runner','Quick Feet',250,{86,219,255},'title','A title for runners who keep moving.'},
 {'title_courier','Special Delivery',450,{255,181,67},'title','Always ready to hand over the hot package.'},
 {'title_dancer','Danger Dancer',700,{255,126,188},'title','A little style in the danger zone.','Rare'},
 {'title_wire','Live Wire',950,{184,255,82},'title','Charged up and hard to catch.','Rare'},
 {'title_calm','Cool Under Fire',1300,{120,220,255},'title','Keep your head when the timer runs low.','Epic'},
 {'title_stand','Last One Standing',1800,{255,201,82},'title','A bold title for your collection.','Epic'},
 {'title_fuse','Fuse Master',2200,{197,125,255},'title','Wear your explosive ambitions.','Epic'},
 {'title_untouch','Untouchable',2800,{128,255,206},'title','Make every near miss look effortless.','Legendary'},
 {'title_legend','Bomb Legend',3600,{255,226,97},'title','The golden name above the arena.','Legendary'},
})
add('Emotes',{
 {'emote_wave','Friendly Wave',0,{93,211,255},'wave','Say hello in the lobby.'},
 {'emote_cheer','Fuse Cheer',300,{255,206,79},'cheer','Raise your arms and cheer for the next round.'},
 {'emote_salute','Bomb Squad Salute',500,{124,231,160},'salute','A sharp salute before the action.'},
 {'emote_shuffle','Lobby Shuffle',800,{255,140,209},'shuffle','A playful side to side dance.','Rare'},
 {'emote_robot','Circuit Robot',1100,{119,197,255},'robot','Move like a mechanical bomb defuser.','Rare'},
 {'emote_victory','Victory Bounce',1500,{255,211,83},'victory','Celebrate with a grounded victory pose.','Epic'},
 {'emote_spin','Disco Spin',2000,{194,141,255},'spin','Turn up the style with a spinning dance.','Epic'},
 {'emote_charge','Power Up',2600,{255,126,91},'charge','Gather your energy for the next match.','Legendary'},
})
return C
]==]

local cosmeticsSource=[==[--!nonstrict
-- HussCosmeticsV11: owned cosmetics and stationary lobby emotes; never changes movement.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local C=require(RS:WaitForChild('HussCatalogV11'))
local S={};local states={};local started=false
local V,CF=Vector3.new,CFrame.new
local function item(p,attribute,category)
 local entry=p and C.ById[p:GetAttribute(attribute)]
 return entry and entry.category==category and entry or C.ById[C.Defaults[category]]
end
function S.ApplyBomb(player,bomb)
 if not bomb or not bomb:IsA('BasePart') then return end
 local old=bomb:FindFirstChild('HussBombSkin');if old then old:Destroy() end
 local skin=item(player,'HussBombId','Bombs');local color=Color3.fromRGB(table.unpack(skin.color))
 local folder=Instance.new('Folder');folder.Name='HussBombSkin';folder.Parent=bomb
 bomb:SetAttribute('HussBombId',skin.id);bomb.Color=color;bomb.Material=Enum.Material.Metal;bomb.Reflectance=.12;bomb.Transparency=0
 if bomb:IsA('Part') then bomb.Shape=skin.style=='gift' and Enum.PartType.Block or Enum.PartType.Ball end
 local white=Color3.fromRGB(255,242,185);local dark=Color3.fromRGB(27,30,39);local gold=Color3.fromRGB(255,208,51)
 local function part(name,position,size,tint,shape,material,rotation)
  local p=Instance.new('Part');p.Name=name;p.Shape=shape or Enum.PartType.Block;p.Size=size;p.Color=tint;p.Material=material or Enum.Material.Metal
  p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Anchored=false
  p.CFrame=bomb.CFrame*CF(position)*(rotation or CFrame.identity);p.Parent=folder
  local weld=Instance.new('WeldConstraint');weld.Part0=bomb;weld.Part1=p;weld.Parent=p;return p
 end
 local function bead(position,tint,size) return part('Accent',position,V(size,size,size),tint,Enum.PartType.Ball) end
 local function ring(tint,radius,tilt,y)
  local axis=CFrame.Angles(tilt or 0,0,0)
  for n=0,9 do local angle=n*math.pi/5;local point=axis:PointToWorldSpace(V(math.cos(angle)*radius,0,math.sin(angle)*radius))+V(0,y or 0,0)
   part('Ring',point,V(.14,.14,radius*.66),tint,nil,Enum.Material.Neon,axis*CFrame.Angles(0,-angle,0))
  end
 end
 local function studs(count,tint,radius,size)
  for n=0,count-1 do local a=n*math.pi*2/count;bead(V(math.cos(a)*radius,0,math.sin(a)*radius),tint,size) end
 end
 -- Every skin keeps a visible fuse and the game's original red carrier warning.
 part('FuseSocket',V(0,1.08,0),V(.42,.2,.42),dark,Enum.PartType.Cylinder,nil,CFrame.Angles(0,0,math.pi/2))
 part('Fuse',V(.1,1.36,0),V(.16,.5,.16),gold,nil,nil,CFrame.Angles(0,0,-.3))
 part('FuseTip',V(.18,1.63,0),V(.22,.22,.22),white,Enum.PartType.Ball,Enum.Material.Neon)
 local style,id=skin.style,skin.id
 if style=='banded' then ring(id=='bomb_bee' and dark or id=='bomb_candy' and white or gold,1.14,0,0)
 elseif style=='hazard' then
  for n=0,7 do local a=n*math.pi/4;part('WarningStripe',V(math.cos(a)*1.05,0,math.sin(a)*1.05),V(.26,.62,.1),dark,nil,nil,CFrame.Angles(0,math.pi/2-a,.35)) end
 elseif style=='panel' then
  for n=0,7 do local a=n*math.pi/4;local tint=id=='bomb_disco' and Color3.fromHSV(n/8,.65,1) or color:Lerp(white,n%2==0 and .55 or .15)
   part('Facet',V(math.cos(a)*.99,0,math.sin(a)*.99),V(.64,.85,.14),tint,nil,Enum.Material.Glass,CFrame.Angles(0,math.pi/2-a,0))
  end
 elseif style=='orb' then
  bomb.Material=Enum.Material.Glass;bomb.Transparency=.38
  part('InnerCore',V(0,0,0),V(1.5,1.5,1.5),color,Enum.PartType.Ball,Enum.Material.Neon);studs(6,white,1.12,.21)
 elseif style=='ring' then ring(id=='bomb_royal' and gold or color:Lerp(white,.5),1.45,.45,0)
 elseif style=='spike' then
  for n=0,7 do local a=n*math.pi/4;part('BluntStud',V(math.cos(a)*1.13,0,math.sin(a)*1.13),V(.35,.35,.48),color:Lerp(dark,.45),nil,nil,CFrame.Angles(0,math.pi/2-a,.35)) end
 elseif style=='gift' then
  part('RibbonX',V(0,0,0),V(2.29,2.29,.3),gold);part('RibbonZ',V(0,0,0),V(.3,2.29,2.29),gold)
  part('BowLeft',V(-.3,1.27,0),V(.55,.17,.4),white,nil,nil,CFrame.Angles(0,0,-.3));part('BowRight',V(.3,1.27,0),V(.55,.17,.4),white,nil,nil,CFrame.Angles(0,0,.3))
 elseif style=='reactor' then
  bomb.Material=Enum.Material.Neon
  for n=0,5 do local a=n*math.pi/3;part('Cage',V(math.cos(a)*.86,0,math.sin(a)*.86),V(.19,1.86,.19),dark) end
  part('CapTop',V(0,.9,0),V(1.35,.22,1.35),dark);part('CapBottom',V(0,-.9,0),V(1.35,.22,1.35),dark)
 end
 -- Distinct details separate same-family shells, rather than relying on recolors alone.
 if id=='bomb_cherry' then part('Leaf',V(.54,1.17,0),V(.72,.1,.36),Color3.fromRGB(86,185,64),nil,nil,CFrame.Angles(0,0,.3))
 elseif id=='bomb_cobalt' then studs(4,white,1.17,.18)
 elseif id=='bomb_mint' then part('MintStripe',V(0,0,0),V(.18,2.29,2.29),white)
 elseif id=='bomb_candy' then studs(5,white,1.16,.25)
 elseif id=='bomb_orange' then part('CitrusLeaf',V(-.35,1.09,0),V(.55,.12,.35),Color3.fromRGB(94,184,58))
 elseif id=='bomb_arctic' then part('IceCrystal',V(0,-.92,0),V(.6,.6,.6),white,nil,Enum.Material.Glass,CFrame.Angles(.4,.4,.4))
 elseif id=='bomb_toxic' then bead(V(0,0,1.13),dark,.45)
 elseif id=='bomb_royal' or id=='bomb_champion' then for n=-1,1 do part('CrownPoint',V(n*.46,1.15,-.4),V(.2,.55,.22),gold,nil,nil,CFrame.Angles(0,0,n*-.3)) end
 elseif id=='bomb_bee' then for _,side in ipairs({-1,1}) do local wing=part('Wing',V(side*.9,.65,0),V(.6,.14,1.1),white,Enum.PartType.Ball,Enum.Material.Glass,CFrame.Angles(0,0,side*.35));wing.Transparency=.4 end
 elseif id=='bomb_prism' then bomb.Material=Enum.Material.Glass;bomb.Transparency=.2;part('CrystalTip',V(0,-1.05,0),V(.58,.58,.58),white,nil,Enum.Material.Glass,CFrame.Angles(.6,.4,.8))
 elseif id=='bomb_saturn' then studs(3,dark,1.08,.2)
 elseif id=='bomb_abyss' then bomb.Color=dark;bomb.Transparency=.55;ring(color,1.14,1.2,0)
 elseif id=='bomb_plasma' then ring(color:Lerp(white,.5),1.16,0,0)
 elseif id=='bomb_sakura' then for n=0,4 do local a=n*math.pi*.4;bead(V(math.cos(a)*.33,math.sin(a)*.33,1.02),white,.38) end
 elseif id=='bomb_gold' then bomb.Reflectance=.38;studs(6,white,1.15,.15)
 elseif id=='bomb_void' then bomb.Color=dark;bead(V(0,0,1.08),color,.64)
 elseif id=='bomb_solar' then studs(6,gold,1.15,.25)
 elseif id=='bomb_nova' then ring(Color3.fromRGB(122,238,255),1.35,-.7,0) end
end
local function stop(p)
 local s=states[p];if s then s.active=nil end
 p:SetAttribute('HussEmotePlaying',nil);p:SetAttribute('HussEmoteStarted',nil)
end
local function stationary(p)
 local c=p.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local r=c and c:FindFirstChild('HumanoidRootPart')
 if not h or not r or h.Health<=0 or p:GetAttribute('InRound')==true or h.MoveDirection.Magnitude>.05 or r.AssemblyLinearVelocity.Magnitude>2 or h.Sit or h.PlatformStand or r.Anchored or h.FloorMaterial==Enum.Material.Air then return end
 if p:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true or c:GetAttribute('Ragdolled')==true or c:GetAttribute('IsRagdoll')==true then return end
 local action=c:GetAttribute('MovementAction');if type(action)=='string' and action:sub(1,4)=='Dive' and action~='DiveEnd' then return end
 return c,h,r
end
function S.Init()
 if started then return end;started=true
 local remote=RS:FindFirstChild('HussCosmeticsV11') or Instance.new('RemoteEvent');assert(remote:IsA('RemoteEvent'),'HussCosmeticsV11 must be a RemoteEvent');remote.Name='HussCosmeticsV11';remote.Parent=RS
 local function add(p) states[p]={nextAt=0};stop(p) end
 Players.PlayerAdded:Connect(add);Players.PlayerRemoving:Connect(function(p) states[p]=nil end)
 for _,p in ipairs(Players:GetPlayers()) do add(p) end
 remote.OnServerEvent:Connect(function(p,action,id)
  local s=states[p];if not s then return end
  if action=='StopEmote' then if s.active then stop(p) end;return end
  if action~='Emote' or os.clock()<s.nextAt or p:GetAttribute('HussEconomyReady')~=true then return end
  local equipped=p:GetAttribute('HussEmoteId');local entry=C.ById[equipped]
  if not entry or entry.category~='Emotes' or (id~=nil and id~=equipped) then return end
  local c,h,r=stationary(p);if not c then return end
  s.nextAt=os.clock()+1.25;s.active={character=c,health=h.Health,position=r.Position,untilAt=os.clock()+6}
  p:SetAttribute('HussEmoteStarted',workspace:GetServerTimeNow());p:SetAttribute('HussEmotePlaying',equipped)
 end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.1 then return end;elapsed=0
  for p,s in pairs(states) do if s.active then
   local c,h,r=stationary(p);local a=s.active
   if not c or c~=a.character or h.Health<a.health or (r.Position-a.position).Magnitude>.3 or os.clock()>=a.untilAt then stop(p) end
  end end
 end)
end
return S
]==]

local practiceSource=[==[--!nonstrict
-- HussPracticeV11: server-owned NPC practice, never economy participants.
local Players=game:GetService('Players')
local RunService=game:GetService('RunService')
local Paths=game:GetService('PathfindingService')
local Bomb=require(script.Parent:WaitForChild('BombService'))
local Config=require(game:GetService('ReplicatedStorage').Shared.Config.GameConfig)
local P={}
local active
local V=Vector3.new
local names={'Fuse','Sparky','Boomer'}
local colors={Color3.fromRGB(49,205,255),Color3.fromRGB(255,188,44),Color3.fromRGB(183,107,250)}
local function flat(v) return V(v.X,0,v.Z) end
local function unit(v) return v.Magnitude>.01 and v.Unit or V(1,0,0) end
local function root(actor) return actor and actor.Character and actor.Character:FindFirstChild('HumanoidRootPart') end
local function living(actor)
 local h=actor and actor.Character and actor.Character:FindFirstChildOfClass('Humanoid')
 return actor and actor.Parent and actor:GetAttribute('InRound')==true and h and h.Health>0 and root(actor)~=nil
end
local function solo(player)
 local count=0
 for _,p in ipairs(Players:GetPlayers()) do if p:GetAttribute('BombTagAFK')~=true then count+=1;if p~=player then return false end end end
 return count==1 and player.Parent==Players and player:GetAttribute('BombTagAFK')~=true
end
local function valid(session)
 return active==session and not session.cancelled and solo(session.player) and living(session.player) and session.context.Running() and workspace:GetServerTimeNow()<session.deadline
end
local function actors(session)
 if not valid(session) then return {} end
 local list={session.player}
 for _,bot in ipairs(session.bots) do if living(bot.actor) then table.insert(list,bot.actor) end end
 return list
end
function P.Stop()
 local session=active;if not session then return end
 session.cancelled=true;active=nil
 for _,connection in ipairs(session.connections) do connection:Disconnect() end
 for _,bot in ipairs(session.bots) do
  bot.token+=1;bot.actor.Parent=nil
  if bot.path then bot.path:Destroy();bot.path=nil end
 end
 if session.folder then session.folder:Destroy() end
 Bomb.Stop()
end
local function createBot(session,index,spawnPart)
 local model=Instance.new('Model');model.Name=names[index];model:SetAttribute('HussPracticeBot',true)
 local collisionGroup=root(session.player).CollisionGroup
 local function part(name,size,position,color,collide)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=CFrame.new(position);p.Color=color;p.Material=Enum.Material.SmoothPlastic
  p.CanCollide=collide==true;p.CanTouch=false;p.CollisionGroup=collisionGroup;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=model;return p
 end
 local ink=Color3.fromRGB(29,35,51);local color=colors[index]
 local r=part('HumanoidRootPart',V(2,2,1),V(0,3,0),ink,false);r.Transparency=1
 local torso=part('Torso',V(2,2,1),V(0,3,0),color,true)
 local head=part('Head',V(2,1,1),V(0,4.5,0),Color3.fromRGB(255,222,141),true)
 local leftArm=part('Left Arm',V(1,2,1),V(-1.5,3,0),color,false)
 local rightArm=part('Right Arm',V(1,2,1),V(1.5,3,0),color,false)
 local leftLeg=part('Left Leg',V(1,2,1),V(-.5,1,0),ink,false)
 local rightLeg=part('Right Leg',V(1,2,1),V(.5,1,0),ink,false)
 local joints={}
 local function joint(name,a,b,offset)
  local j=Instance.new('Motor6D');j.Name=name;j.Part0=a;j.Part1=b;j.C0=CFrame.new(offset);j.C1=CFrame.new();j.Parent=a;joints[name]={motor=j,base=j.C0};return j
 end
 joint('RootJoint',r,torso,V(0,0,0));joint('Neck',torso,head,V(0,1.5,0))
 joint('Left Shoulder',torso,leftArm,V(-1.5,0,0));joint('Right Shoulder',torso,rightArm,V(1.5,0,0))
 joint('Left Hip',torso,leftLeg,V(-.5,-2,0));joint('Right Hip',torso,rightLeg,V(.5,-2,0))
 local face=Instance.new('SurfaceGui');face.Name='Face';face.Face=Enum.NormalId.Front;face.CanvasSize=Vector2.new(256,128);face.Parent=head
 local expression=Instance.new('TextLabel');expression.Size=UDim2.fromScale(1,1);expression.BackgroundTransparency=1;expression.Text='• ᴗ •';expression.Font=Enum.Font.GothamBlack;expression.TextSize=80;expression.TextColor3=ink;expression.Parent=face
 local badge=Instance.new('BillboardGui');badge.Name='PracticeBadge';badge.Size=UDim2.fromOffset(190,35);badge.StudsOffset=V(0,2,0);badge.AlwaysOnTop=false;badge.MaxDistance=120;badge.Adornee=head;badge.Parent=head
 local label=Instance.new('TextLabel');label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.Font=Enum.Font.FredokaOne;label.TextSize=20;label.TextStrokeTransparency=0;label.TextColor3=color;label.Text=names[index]..' • PRACTICE';label.Parent=badge
 local humanoid=Instance.new('Humanoid');humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;humanoid.WalkSpeed=24;humanoid.UseJumpPower=true;humanoid.JumpPower=0;humanoid.JumpHeight=0;humanoid.AutoJumpEnabled=false;humanoid.MaxSlopeAngle=38;humanoid.Parent=model;humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
 model.PrimaryPart=r;model.Parent=session.folder
 session.context.Ground(model,spawnPart)
 for _,o in ipairs(model:GetChildren()) do if o:IsA('BasePart') then o.Anchored=false;o:SetNetworkOwner(nil) end end
 local actor={UserId=-index,Name=names[index],DisplayName=names[index],Character=model,Parent=session.folder}
 function actor:GetAttribute(name) return model:GetAttribute(name) end
 function actor:SetAttribute(name,value) model:SetAttribute(name,value) end
 actor:SetAttribute('InRound',true)
 local bot={actor=actor,root=r,h=humanoid,joints=joints,side=index%2==0 and 1 or -1,nextThink=0,nextPath=0,token=0,lastDodge=-math.huge,position=r.Position,stuckAt=workspace:GetServerTimeNow(),waypoints={},waypoint=1}
 table.insert(session.bots,bot)
 table.insert(session.connections,humanoid.Died:Connect(function() actor:SetAttribute('InRound',false);bot.token+=1 end))
 return bot
end
local function params(session)
 local rp=RaycastParams.new();rp.FilterType=Enum.RaycastFilterType.Exclude;rp.FilterDescendantsInstances={session.folder,session.player.Character};rp.IgnoreWater=true;rp.RespectCanCollide=true;return rp
end
local function floorAt(session,position)
 local hit=workspace:Raycast(position+V(0,4,0),V(0,-16,0),session.ray)
 return hit and hit.Normal.Y>.65 and hit.Position or nil
end
local function free(session,from,direction,distance)
 if workspace:Raycast(from,direction*distance,session.ray) then return false end
 return floorAt(session,from+direction*distance)~=nil
end
local function steer(session,bot,desired)
 local dir=unit(flat(desired));local from=bot.root.Position
 if free(session,from,dir,6) then return dir end
 for _,angle in ipairs({.65,-.65,1.3,-1.3,2,-2,math.pi}) do
  local rotated=CFrame.Angles(0,angle*bot.side,0):VectorToWorldSpace(dir)
  if free(session,from,rotated,6) then return rotated end
 end
 return Vector3.zero
end
local function route(session,bot,goal,now)
 if bot.pending or now<bot.nextPath then return end
 bot.nextPath=now+1.1;bot.pending=true;bot.token+=1;local token=bot.token;local start=bot.root.Position
 task.spawn(function()
  local path=Paths:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=false,AgentCanClimb=false,WaypointSpacing=5,Costs={Water=math.huge}})
  local ok=pcall(function() path:ComputeAsync(start,goal) end)
  -- ComputeAsync cannot be interrupted, so allow just one worker per bot and
  -- discard stale results. A late result can never recreate a stopped session.
  if active~=session or session.cancelled or bot.token~=token or not living(bot.actor) then path:Destroy();return end
  bot.pending=false
  if ok and path.Status==Enum.PathStatus.Success and workspace:GetServerTimeNow()-now<3 then
   if bot.path then bot.path:Destroy() end;bot.path=path;bot.waypoints=path:GetWaypoints();bot.waypoint=math.min(2,#bot.waypoints)
  else path:Destroy();bot.waypoints={};bot.waypoint=1 end
 end)
end
local function dodge(session,bot,direction,now)
 if direction.Magnitude<.1 or now-bot.lastDodge<1.5 or bot.h.FloorMaterial==Enum.Material.Air or not free(session,bot.root.Position,direction,10) then return end
 bot.lastDodge=now;bot.dodgeAt=now;bot.velocity=direction*math.clamp(bot.h.WalkSpeed+44,74,84);bot.h.AutoRotate=false
 local character=bot.actor.Character
 character:SetAttribute('BombTagIFrameUntil',now+.45);character:SetAttribute('HussDodgeStartedAt',now)
 character:SetAttribute('MovementAction','DiveForward');character:SetAttribute('MovementActionId',(character:GetAttribute('MovementActionId') or 0)+1)
end
local function think(session,bot,now)
 if now<bot.nextThink then return end;bot.nextThink=now+.16+math.random()*.16
 local carrier=Bomb.GetCarrier();local current=bot.root.Position;local goal
 local danger=carrier and carrier~=bot.actor and root(carrier)
 if carrier==bot.actor then
  local distance=math.huge
  for _,actor in ipairs(actors(session)) do if actor~=bot.actor then
   local other=root(actor);local d=(other.Position-current).Magnitude
   if d<distance then distance=d;goal=other.Position+flat(other.AssemblyLinearVelocity)*.12 end
  end end
 elseif danger and (danger.Position-current).Magnitude<65 then
  local away=unit(flat(current-danger.Position));local side=V(-away.Z,0,away.X)*bot.side
  local candidate=current+unit(away+side*.42)*32
  goal=floorAt(session,candidate) and candidate or nil
  local distance=(danger.Position-current).Magnitude
  if distance<14 and distance>3 and math.random()<.7 then dodge(session,bot,steer(session,bot,away+side),now) end
 end
 if not goal then
  if not bot.roam or (bot.roam-current).Magnitude<8 or now>(bot.roamAt or 0) then
   local spawn=session.context.Spawns[math.random(1,#session.context.Spawns)];bot.roam=spawn.Position+V(0,3,0);bot.roamAt=now+5
  end
  goal=bot.roam
 end
 if (current-bot.position).Magnitude>2 then bot.position=current;bot.stuckAt=now
 elseif now-bot.stuckAt>1.4 then bot.side=-bot.side;bot.roam=nil;bot.nextPath=0;bot.waypoints={};bot.stuckAt=now;goal=current+V(17*bot.side,0,11) end
 bot.goal=goal
 local distance=(goal-current).Magnitude
 bot.speed=(carrier==bot.actor or danger and (danger.Position-current).Magnitude<45 or distance>30) and 32 or 24
 if distance>7 then route(session,bot,goal,now) end
end
local function animate(bot,now,speed,diving)
 local swing=math.sin(now*(speed>25 and 15 or 11))*math.min(speed/32,.85)
 for name,record in pairs(bot.joints) do
  local pose=CFrame.new()
  if name=='RootJoint' then pose=CFrame.Angles(diving and -.65 or -.08,0,diving and bot.side*.18 or 0)
  elseif name:find('Shoulder',1,true) then pose=CFrame.Angles(diving and -1.2 or (name=='Left Shoulder' and swing or -swing),0,0)
  elseif name:find('Hip',1,true) then pose=CFrame.Angles(diving and .45 or (name=='Left Hip' and -swing or swing),0,0) end
  record.motor.C0=record.base*pose
 end
end
local function move(session,bot,dt,now)
 if not living(bot.actor) then return end
 think(session,bot,now)
 local target=bot.goal or bot.root.Position
 local waypoint=bot.waypoints[bot.waypoint]
 if waypoint then
  if (waypoint.Position-bot.root.Position).Magnitude<6 then bot.waypoint+=1;waypoint=bot.waypoints[bot.waypoint] end
  if waypoint and waypoint.Action~=Enum.PathWaypointAction.Jump then target=waypoint.Position end
 end
 local direction=steer(session,bot,target-bot.root.Position)
 local boost=(bot.actor.Character:GetAttribute('HussPerfectBoostUntil') or 0)>now and 6 or 0
 local speed=(bot.speed or 24)+boost
 local elapsed=bot.dodgeAt and now-bot.dodgeAt or 1
 local diving=elapsed<.72
 if diving then
  local t=math.clamp(elapsed/.72,0,1);local smooth=t*t*(3-2*t)
  if t>.34 then local control=math.clamp((t-.34)/(.86-.34),0,1);control=control*control*(3-2*control);bot.velocity=bot.velocity:Lerp(direction*bot.velocity.Magnitude,1-math.exp(-5.5*control*dt)) end
  bot.velocity*=math.exp(-(1+1.7*smooth)*dt)
  local handoff=math.clamp((t-.55)/.45,0,1);handoff=handoff*handoff*(3-2*handoff)
  bot.velocity=bot.velocity:Lerp(direction*speed,1-math.exp(-8.5*handoff*dt))
  if not free(session,bot.root.Position,unit(bot.velocity),math.max(4,bot.velocity.Magnitude*dt+2)) then bot.velocity=Vector3.zero end
  bot.h.WalkSpeed=speed*handoff
  local v=bot.root.AssemblyLinearVelocity;bot.root.AssemblyLinearVelocity=V(bot.velocity.X,v.Y,bot.velocity.Z)
  if bot.velocity.Magnitude>.1 then bot.root.CFrame=CFrame.lookAt(bot.root.Position,bot.root.Position+unit(bot.velocity)) end
 else bot.h.AutoRotate=true;bot.h.WalkSpeed=speed end
 bot.h:Move(direction,false);animate(bot,now,flat(bot.root.AssemblyLinearVelocity).Magnitude,diving)
end
function P.Run(player,context)
 P.Stop()
 if not solo(player) or not living(player) or #context.Spawns<2 then return end
 local session={player=player,character=player.Character,context=context,bots={},connections={},deadline=workspace:GetServerTimeNow()+math.clamp(context.Duration or 30,15,180)}
 active=session
 local ok,message=xpcall(function()
  local folder=Instance.new('Folder');folder.Name='HussPracticeBots';folder.Parent=workspace;session.folder=folder
  local spawns=table.clone(context.Spawns);local playerRoot=root(player)
  table.sort(spawns,function(a,b) return (a.Position-playerRoot.Position).Magnitude>(b.Position-playerRoot.Position).Magnitude end)
  for index=1,math.min(3,#spawns-1) do createBot(session,index,spawns[index]) end
  session.ray=params(session)
  local function check() if not valid(session) then P.Stop() end end
  local function watch(p) table.insert(session.connections,p:GetAttributeChangedSignal('BombTagAFK'):Connect(check));check() end
  table.insert(session.connections,Players.PlayerAdded:Connect(watch));table.insert(session.connections,Players.PlayerRemoving:Connect(function(p) if p==player then P.Stop() end end))
  for _,p in ipairs(Players:GetPlayers()) do watch(p);if active~=session then return end end
  table.insert(session.connections,player.CharacterAdded:Connect(function() P.Stop() end))
  table.insert(session.connections,session.character:FindFirstChildOfClass('Humanoid').Died:Connect(function() P.Stop() end))
  local nextUpdate=0
  table.insert(session.connections,RunService.Heartbeat:Connect(function(dt)
   local moved,err=pcall(function()
    if not valid(session) then P.Stop();return end
    local now=workspace:GetServerTimeNow()
    for _,bot in ipairs(session.bots) do move(session,bot,math.min(dt,.1),now) end
    if now>=nextUpdate then nextUpdate=now+.25;context.Send('PRACTICE',math.ceil(session.deadline-now),#actors(session)) end
   end)
   if not moved then session.error=err;P.Stop() end
  end))
  while valid(session) and #actors(session)>1 do
   Bomb.RunBombCycle(function() return actors(session) end,#actors(session)==2 and Config.FinalDuelBombFuseSeconds or Config.NormalBombFuseSeconds)
   local untilTime=workspace:GetServerTimeNow()+Config.BetweenBombsSeconds
   while valid(session) and workspace:GetServerTimeNow()<untilTime do task.wait(.05) end
  end
 end,debug.traceback)
 if active==session then P.Stop() end
 if not ok or session.error then error(message or session.error) end
end
return P
]==]

local weaveSource=[==[--!nonstrict
-- HussPerfectWeaveV11: a server-confirmed avoided tag, once per accepted dodge.
local Config=require(game:GetService('ReplicatedStorage').Shared.Config.GameConfig)
local W={}
local function root(actor)
 local c=actor and actor.Character
 local h=c and c:FindFirstChildOfClass('Humanoid')
 local r=c and c:FindFirstChild('HumanoidRootPart')
 if not h or h.Health<=0 or not r or r.Anchored or h.Sit or h.PlatformStand then return nil end
 if actor:GetAttribute('InRound')~=true then return nil end
 return r,c
end
local function finite(v)
 return typeof(v)=='Vector3' and v.X==v.X and v.Y==v.Y and v.Z==v.Z and v.Magnitude<1000000
end
function W.Try(carrier,target,previousCarrier,previousTarget,protectedId,protectedUntil)
 if carrier==target or not carrier or not target then return false end
 local now=workspace:GetServerTimeNow()
 if target.UserId==protectedId and now<(protectedUntil or 0) then return false end
 local a,ca=root(carrier);local b,cb=root(target)
 if not a or not b then return false end
 local ends=cb:GetAttribute('BombTagIFrameUntil')
 if type(ends)~='number' or ends~=ends then return false end
 local age=now-(ends-.45)
 if age<0 or age>.22 or now>=ends or cb:GetAttribute('HussPerfectDodgeUsed')==ends then return false end
 local ac,bc=a.Position,b.Position
 local ap=finite(previousCarrier) and previousCarrier or ac
 local bp=finite(previousTarget) and previousTarget or bc
 if not finite(ac) or not finite(bc) or (ac-ap).Magnitude>20 or (bc-bp).Magnitude>20 then return false end
 local start=bp-ap;local finish=bc-ac;local delta=finish-start
 local t=delta:Dot(delta)>1e-5 and math.clamp(-start:Dot(delta)/delta:Dot(delta),0,1) or 0
 local distance=math.min(finish.Magnitude,(start+delta*t).Magnitude)
 if distance>Config.BombTagRadius or finish.Magnitude>Config.BombTagRadius+6 then return false end
 local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude;ray.FilterDescendantsInstances={ca,cb};ray.IgnoreWater=true
 if finish.Magnitude>.01 and workspace:Raycast(ac,finish,ray) then return false end
 cb:SetAttribute('HussPerfectDodgeUsed',ends)
 cb:SetAttribute('HussPerfectBoostUntil',now+2)
 cb:SetAttribute('HussPerfectWeaveAt',now)
 return true
end
return W
]==]

local collectionSource=[==[--!nonstrict
-- HussCollectionEffectsV11: bounded local trails, titles, stationary emotes and perfect-weave feedback.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Sound=game:GetService('SoundService')
local C=require(RS:WaitForChild('HussCatalogV11'))
local me=Players.LocalPlayer
local states,links={},{}
local stopped,allocated=false,0
local V,CF=Vector3.new,CFrame.new
local folder=Instance.new('Folder');folder.Name='HussCollectionEffectsV11';folder.Parent=workspace
local variants={};local counts={}
for _,i in ipairs(C.Items) do if i.category=='Trails' then counts[i.style]=(counts[i.style] or 0)+1;variants[i.id]=counts[i.style] end end
local function make(class,parent,props)
 local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o
end
local function link(signal,fn,bucket) table.insert(bucket or links,signal:Connect(fn)) end
local function clear(bucket) for _,c in ipairs(bucket) do c:Disconnect() end;table.clear(bucket) end
local function reduced() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function entry(s,attribute,category)
 local i=C.ById[s.p:GetAttribute(attribute)];return i and i.category==category and i or C.ById[C.Defaults[category]]
end
local function tint(i) return Color3.fromRGB(table.unpack(i.color)) end
local function destroyTrail(s)
 if not s.trail then return end
 for _,o in ipairs(s.trail.objects) do o:Destroy() end;s.trail=nil;allocated-=1
end
local function poseEnd(s)
 if s.pose then for joint,original in pairs(s.pose.originals) do if joint.Parent then joint.C0=original end end;s.pose=nil end
end
local function reset(s)
 destroyTrail(s);poseEnd(s)
 if s.title then s.title:Destroy();s.title=nil end
 if s.burst then s.burst:Destroy();s.burst=nil end
 clear(s.charLinks);s.character=nil;s.h=nil;s.root=nil
end
local tones={1.45,1.9}
local cues={}
for n=1,2 do cues[n]=make('Sound',Sound,{Name='HussPerfectWeaveV11',SoundId='rbxasset://sounds/volume_slider.ogg',PlaybackSpeed=tones[n],Volume=0}) end
local cueSerial=0
local function cue()
 if me:GetAttribute('HussSFXMuted')==true then return end
 cueSerial+=1;local serial=cueSerial
 for n,sound in ipairs(cues) do task.delay((n-1)*.085,function()
  if stopped or serial~=cueSerial or me:GetAttribute('HussSFXMuted')==true then return end
  local group=Sound:FindFirstChild('HussSFXV6');sound.SoundGroup=group and group:IsA('SoundGroup') and group or nil
  sound.Volume=.22*(sound.SoundGroup and 1 or math.clamp(tonumber(me:GetAttribute('HussSFXVolume')) or .8,0,1));sound:Stop();sound:Play()
 end) end
end
link(me:GetAttributeChangedSignal('HussSFXMuted'),function() if me:GetAttribute('HussSFXMuted')==true then cueSerial+=1;for _,sound in ipairs(cues) do sound:Stop() end end end)
local function perfect(s)
 local stamp=s.character:GetAttribute('HussPerfectWeaveAt')
 if type(stamp)~='number' or stamp~=stamp or stamp==s.lastPerfect or math.abs(workspace:GetServerTimeNow()-stamp)>1 then return end
 s.lastPerfect=stamp;if s.p==me then cue() end
 if reduced() then return end
 local camera=workspace.CurrentCamera;if not camera or (camera.CFrame.Position-s.root.Position).Magnitude>100 then return end
 if s.burst then s.burst:Destroy() end
 s.burst=make('Highlight',s.character,{Name='HussPerfectWeave',Adornee=s.character,DepthMode=Enum.HighlightDepthMode.Occluded,FillColor=Color3.fromRGB(147,255,137),OutlineColor=Color3.new(1,1,1),FillTransparency=.85,OutlineTransparency=.2})
 s.burstUntil=os.clock()+.3
end
local function bindCharacter(s,c)
 reset(s);s.generation+=1;local generation=s.generation
 task.spawn(function()
  local h=c:WaitForChild('Humanoid',10);local root=c:WaitForChild('HumanoidRootPart',10)
  if stopped or states[s.p]~=s or s.generation~=generation or s.p.Character~=c or not h or not root then return end
  s.character=c;s.h=h;s.root=root;s.lastPerfect=c:GetAttribute('HussPerfectWeaveAt')
  link(c:GetAttributeChangedSignal('HussPerfectWeaveAt'),function() if s.character==c then perfect(s) end end,s.charLinks)
  link(h.Died,function() reset(s) end,s.charLinks)
 end)
end
local function add(p)
 if states[p] then return end
 local s={p=p,links={},charLinks={},generation=0};states[p]=s
 link(p.CharacterAdded,function(c) bindCharacter(s,c) end,s.links)
 link(p.CharacterRemoving,function() s.generation+=1;reset(s) end,s.links)
 if p.Character then bindCharacter(s,p.Character) end
end
local function remove(p) local s=states[p];if s then s.generation+=1;reset(s);clear(s.links);states[p]=nil end end
local function title(s)
 local i=entry(s,'HussTitleId','Titles')
 local head=s.character:FindFirstChild('Head');if not head then return end
 if not s.title then
  s.title=make('BillboardGui',head,{Name='HussTitleV11',Adornee=head,Size=UDim2.fromOffset(240,34),StudsOffsetWorldSpace=V(0,2.15,0),MaxDistance=85,AlwaysOnTop=false})
  make('TextLabel',s.title,{Name='Title',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.FredokaOne,TextSize=20,TextStrokeTransparency=.05,TextStrokeColor3=Color3.fromRGB(12,19,28),TextColor3=tint(i),Text=i.name})
 end
 if s.title:GetAttribute('Item')~=i.id then s.title:SetAttribute('Item',i.id);s.title.Title.Text=i.name;s.title.Title.TextColor3=tint(i) end
end
local function trail(s,i)
 if s.trail and s.trail.id~=i.id then destroyTrail(s) end
 if s.trail then return s.trail end
 if allocated>=(s.p==me and 10 or 9) then return end;allocated+=1
 local t={id=i.id,objects={},nextEmit=0};s.trail=t
 local function obj(class,parent,props) local o=make(class,parent,props);table.insert(t.objects,o);return o end
 local color=tint(i);local variant=variants[i.id] or 1;local style=i.style
 local a=obj('Attachment',s.root,{Name='HussCollectionWake',Position=V(0,-1.5,.5)})
 t.emitter=obj('ParticleEmitter',a,{Name='CollectionTrail',Texture='rbxasset://textures/particles/'..((style=='smoke' or style=='bubbles' or style=='pulse') and 'smoke_main.dds' or 'sparkles_main.dds'),Enabled=false,Rate=0,
  Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.3),color),LightEmission=style=='smoke' and .15 or .7,LightInfluence=.1,
  Lifetime=NumberRange.new(.16+variant*.025,.3+variant*.025),Speed=NumberRange.new(style=='sparks' and 3 or .5,style=='sparks' and 6 or 2),
  SpreadAngle=Vector2.new(style=='lightning' and 5 or 30+variant*5,style=='lightning' and 5 or 35),EmissionDirection=Enum.NormalId.Back,
  Acceleration=V(0,style=='bubbles' and 2 or style=='confetti' and -4 or 0,0),Drag=1,Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(style=='confetti' and -120 or -20,style=='confetti' and 120 or 20),
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,style=='smoke' and .45 or style=='pulse' and .6 or .17+variant*.02),NumberSequenceKeypoint.new(1,style=='smoke' and 1.1 or style=='bubbles' and .4 or 0)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,style=='smoke' and .72 or .2),NumberSequenceKeypoint.new(1,1)})})
 if style=='ribbon' or style=='lightning' or style=='pulse' then
  local b=obj('Attachment',s.root,{Name='HussCollectionEdge',Position=V(0,-1.3,.5)})
  t.ribbon=obj('Trail',s.root,{Name='CollectionRibbon',Attachment0=a,Attachment1=b,FaceCamera=true,Enabled=false,Lifetime=.12+variant*.018,MinLength=style=='lightning' and .65 or .1,MaxLength=8,
   Color=ColorSequence.new(color,Color3.new(1,1,1)),LightEmission=.8,Transparency=NumberSequence.new(.3,1),WidthScale=NumberSequence.new(1,0)})
 end
 -- Small geometry distinguishes bubbles, paper confetti and pulse discs without uploaded textures.
 if style=='bubbles' or style=='confetti' or style=='pulse' then
  t.shapes={}
  for n=1,3 do local p=obj('Part',folder,{Name='CollectionAccent',Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,Material=Enum.Material.Neon,
   Shape=style=='bubbles' and Enum.PartType.Ball or style=='pulse' and Enum.PartType.Cylinder or Enum.PartType.Block,
   Size=style=='bubbles' and V(.15,.15,.15) or style=='pulse' and V(.03,.36,.36) or V(.12,.04,.22),Color=color,Transparency=.35})
   table.insert(t.shapes,p)
  end
 end
 return t
end
local jointNames={RightShoulder='right',LeftShoulder='left',['Right Shoulder']='right',['Left Shoulder']='left',Waist='body',RootJoint='body',Neck='neck',RightHip='rightLeg',LeftHip='leftLeg',['Right Hip']='rightLeg',['Left Hip']='leftLeg'}
local function emote(s,now,near)
 local id=s.p:GetAttribute('HussEmotePlaying');local stamp=s.p:GetAttribute('HussEmoteStarted');local i=C.ById[id]
 local action=s.character:GetAttribute('MovementAction')
 if not near or not i or i.category~='Emotes' or type(stamp)~='number' or stamp~=stamp or s.p:GetAttribute('InRound')==true or s.h.MoveDirection.Magnitude>.05 or s.root.AssemblyLinearVelocity.Magnitude>2 or s.h.Sit or s.h.PlatformStand or (type(action)=='string' and action:sub(1,4)=='Dive' and action~='DiveEnd') then poseEnd(s);return end
 local age=workspace:GetServerTimeNow()-stamp;if age<0 or age>6.2 then poseEnd(s);return end
 if s.pose and (s.pose.id~=id or s.pose.stamp~=stamp) then poseEnd(s) end
 if not s.pose then
  local pose={id=id,stamp=stamp,originals={},joints={}};s.pose=pose
  for _,joint in ipairs(s.character:GetDescendants()) do if joint:IsA('Motor6D') and jointNames[joint.Name] then
   local key=jointNames[joint.Name]
   -- Prefer the R15 waist over its root joint. Never move the physical root.
   if key~='body' or joint.Name=='Waist' or not pose.joints.body then pose.joints[key]=joint end
   pose.originals[joint]=joint.C0
  end end
 end
 local wave=math.sin(age*7);local beat=math.sin(age*5);local step=math.sin(age*8)
 local angles={right=V(0,0,0),left=V(0,0,0),body=V(0,0,0),neck=V(0,0,0),rightLeg=V(0,0,0),leftLeg=V(0,0,0)}
 if i.style=='wave' then angles.right=V(0,0,2.25+wave*.25);angles.neck=V(0,0,.08)
 elseif i.style=='cheer' then angles.right=V(0,0,2.5+beat*.2);angles.left=V(0,0,-2.5-beat*.2);angles.body=V(.08*beat,0,0)
 elseif i.style=='salute' then angles.right=V(-.2,0,-2.6);angles.neck=V(-.08,0,0)
 elseif i.style=='shuffle' then angles.right=V(step*.4,0,.25);angles.left=V(-step*.4,0,-.25);angles.body=V(0,beat*.25,step*.1);angles.rightLeg=V(step*.15,0,0);angles.leftLeg=V(-step*.15,0,0)
 elseif i.style=='robot' then local tick=math.floor(age*3)%4;angles.right=V(tick%2==0 and -.8 or .4,0,.8);angles.left=V(tick%2==0 and .4 or -.8,0,-.8);angles.neck=V(0,(tick-1.5)*.16,0)
 elseif i.style=='victory' then angles.right=V(-.25,0,2.6);angles.left=V(-.25,0,-2.6);angles.body=V(.08*beat,0,beat*.14)
 elseif i.style=='spin' then angles.body=V(0,age*2.5,0);angles.right=V(0,0,1.25);angles.left=V(0,0,-1.25)
 elseif i.style=='charge' then angles.right=V(.5,0,.75);angles.left=V(.5,0,-.75);angles.body=V(-.12+beat*.025,0,0);angles.neck=V(.12,0,0) end
 local strength=math.min(1,age/.18)*(reduced() and .5 or 1)
 for name,joint in pairs(s.pose.joints) do if joint.Parent then local a=angles[name]*strength;local original=s.pose.originals[joint];joint.C0=CF(original.Position)*CFrame.Angles(a.X,a.Y,a.Z)*original.Rotation end end
end
link(Players.PlayerAdded,add);link(Players.PlayerRemoving,remove)
for _,p in ipairs(Players:GetPlayers()) do add(p) end
link(Run.Heartbeat,function()
 local camera=workspace.CurrentCamera;local now=os.clock();local low=reduced()
 for _,s in pairs(states) do if s.root and s.character and s.root.Parent then
  local near=camera and (camera.CFrame.Position-s.root.Position).Magnitude<90
  if s.burst and (low or now>=s.burstUntil) then s.burst:Destroy();s.burst=nil end
  if near and s.h.Health>0 then title(s) elseif s.title then s.title:Destroy();s.title=nil end
  emote(s,now,near)
  local v=s.root.AssemblyLinearVelocity;local speed=V(v.X,0,v.Z).Magnitude
  local i=entry(s,'HussTrailId','Trails')
  local active=near and not low and i.id~='default' and speed>27 and speed<100 and s.h.Health>0 and not s.h.Sit and not s.h.PlatformStand and not s.root.Anchored and s.h.FloorMaterial~=Enum.Material.Air and s.character:GetAttribute('Ragdolled')~=true and s.character:GetAttribute('IsRagdoll')~=true and s.p:GetAttribute('HussGamePaused')~=true and workspace:GetAttribute('HussGamePaused')~=true
  if active then
   local t=trail(s,i)
   if t then
    if t.ribbon then t.ribbon.Enabled=true end
    if now>=t.nextEmit then t.emitter:Emit(i.style=='smoke' and 1 or 2);t.nextEmit=now+.09 end
    if t.shapes then for n,p in ipairs(t.shapes) do
     local lag=n*.045;local wave=math.sin(now*7+n)*.45
     p.CFrame=CF(s.root.Position-v*lag+V(wave,-1.25+n*.08,0))*CFrame.Angles(i.style=='pulse' and 0 or now*2,n,math.pi/2)
    end end
   end
  else destroyTrail(s) end
 end end
end)
link(script.Destroying,function()
 stopped=true;cueSerial+=1;clear(links)
 local list={};for p in pairs(states) do table.insert(list,p) end;for _,p in ipairs(list) do remove(p) end
 for _,sound in ipairs(cues) do sound:Destroy() end;folder:Destroy()
end)
]==]

local boardsSource=[==[--!nonstrict
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
]==]

-- Discover the actual place. Names are not treated as proof of compatibility.
local starter=unique(starterRoot,'StarterPlayerScripts','StarterPlayerScripts',false)
local services=unique(server,'Services','Folder',false)
local hud=unique(starter,'HudController','ModuleScript',true)
local main=unique(server,'ServerMain','Script',true)
local round=unique(services,'RoundService','ModuleScript',false)
local bomb=unique(services,'BombService','ModuleScript',false)
local economy=unique(services,'EconomyServiceV9','ModuleScript',false,true)
local movement=unique(starter,'SnappyMovement','LocalScript',true)
local effects=unique(starter,'MovementEffectsV8','LocalScript',true)
local originalLibrary=unique(storage,'MapLibrary','Folder',false)
local originalLobby=unique(workspace,'Lobby','Model',false)
local originalPreviews=unique(replicated,'BombTagV6Previews','Folder',false,true)
local maps=unique(workspace,'Maps','Folder',false)
local anchor=unique(workspace,'ActiveArenaAnchor','BasePart',false)
local originalArena
if maps then for _,object in ipairs(maps:GetChildren()) do if object:IsA('Model') then
 if originalArena then problem('Workspace.Maps has multiple active arenas; the installer cannot safely choose one.') end
 originalArena=object
end end end
if not originalArena then problem('Workspace.Maps needs one active arena Model.') end
local function validateSpawns(model)
 if not model then return end
 unique(model,'Floor','BasePart',false)
 local spawns=unique(model,'Spawns','Folder',false)
 if spawns then
  local count=0;for _,object in ipairs(spawns:GetChildren()) do if object:IsA('BasePart') then count+=1 end end
  if count<16 then problem(path(spawns)..' needs at least sixteen BasePart spawns; found '..count..'.') end
 end
end
if originalLobby then unique(originalLobby,'Floor','BasePart',false);unique(originalLobby,'LobbySpawn','SpawnLocation',false) end
validateSpawns(originalArena)
for _,object in ipairs({main,movement,effects}) do if object and object.Disabled then problem(path(object)..' is disabled. The installer preserves this setting; enable the intended owner before installing.') end end
local edits,additions,dependencySources={},{},{}
local function edit(object,adapter)
 if not object then return end
 local source=attempt(path(object),function() return adapter(object.Source) end)
 if type(source)=='string' then table.insert(edits,{object,source}) end
end
edit(main,gameplayAdapter.Main);edit(round,gameplayAdapter.Round);edit(bomb,gameplayAdapter.Bomb)
edit(hud,uiAdapter.HUD);edit(movement,movementAdapter.Movement);edit(effects,uiAdapter.Effects)
if economy then
 local length,sum=fingerprint(economy.Source)
 if (length==14880 and sum==1268984491) or canonical(economy.Source)==canonical(economySource) then table.insert(edits,{economy,economySource})
 else problem(path(economy)..' has unsupported source ('..length..' bytes; checksum '..sum..'). Its existing saves and source will not be overwritten.') end
elseif services then table.insert(additions,{services,'ModuleScript','EconomyServiceV9',economySource}) end
if replicated and services and starter then
 for _,entry in ipairs({
  {replicated,'ModuleScript','HussCatalogV11',catalogSource},
  {services,'ModuleScript','CosmeticsServiceV11',cosmeticsSource},
  {services,'ModuleScript','PracticeServiceV11',practiceSource},
  {services,'ModuleScript','PerfectWeaveServiceV11',weaveSource},
  {starter,'LocalScript','CollectionEffectsV11',collectionSource},
  {starter,'LocalScript','LobbyBoardsV11',boardsSource},
 }) do table.insert(additions,entry) end
end
for _,entry in ipairs(additions) do
 local old=unique(entry[1],entry[3],entry[2],true,true);entry[5]=old
 if old then
  if old.Parent~=entry[1] then problem(path(old)..' is in an unexpected container; expected '..path(entry[1])..'. No duplicate will be installed.') end
  if canonical(old.Source)~=canonical(entry[4]) then problem(path(old)..' already contains different source. No unrelated script will be replaced.') end
  if old:IsA('BaseScript') and old.Disabled then problem(path(old)..' is disabled; enable the intended V11 system before reinstalling.') end
 end
end
for _,pair in ipairs({{'HussEconomyV9',economy},{'HussCosmeticsV11',services and services:FindFirstChild('CosmeticsServiceV11')}}) do
 local remote=unique(replicated,pair[1],'RemoteEvent',false,true)
 if remote and not pair[2] then problem(path(remote)..' has no verified owning service. Its ownership must be resolved before installation.') end
end
local context={server=server,replicated=replicated,storage=storage,starter=starter,services=services,main=main,round=round,bomb=bomb,hud=hud,movement=movement,effects=effects,library=originalLibrary,lobby=originalLobby,maps=maps,anchor=anchor,economy=economy}
local validation=attempt('Installation dependencies',function() return dependencyValidator.Validate(context) end)
if type(validation)=='table' then
 for _,message in ipairs(validation.issues or {}) do problem(message) end
 dependencySources=validation.sources or {}
 for _,message in ipairs(validation.notes or {}) do note(message) end
end
local originalNames={'Sky Garden','Sunset Docks','Frostfall Village','Sunstone Bazaar','Neon District','Clockwork Foundry','Orbital Station','Stardust Carnival','Crystal Cavern','Emerald Ruins','Pirate Cove','Ember Keep'}
local worldComplete=originalLobby and originalLobby:GetAttribute('HussLobbyVersion')==11
local worldCount,knownCount=0,0
if originalLibrary then
 local seen={}
 for _,model in ipairs(originalLibrary:GetChildren()) do
  if seen[model.Name] then problem('Duplicate map name in MapLibrary: '..model.Name) end;seen[model.Name]=true
  if model:IsA('Model') then
   worldCount+=1
   local version=model:GetAttribute('BombTagGenerated')
   if version=='HussWorld4' or version=='HussWorld11' then
    knownCount+=1
    validateSpawns(model)
    local floor=model:FindFirstChild('Floor')
    if floor and version=='HussWorld4' and (type(model:GetAttribute('MapWidth'))~='number' or type(model:GetAttribute('MapDepth'))~='number') then problem(path(model)..' is missing its authored map dimensions.') end
    if version~='HussWorld11' then worldComplete=false end
   end
  end
 end
 for _,name in ipairs(originalNames) do
  local model=originalLibrary:FindFirstChild(name)
  if not model or not model:IsA('Model') or (model:GetAttribute('BombTagGenerated')~='HussWorld4' and model:GetAttribute('BombTagGenerated')~='HussWorld11') then problem('Missing verified authored map: '..name) end
 end
 if knownCount<12 then problem('MapLibrary does not contain the twelve verified Huss movement maps. Existing map voting will be preserved.') end
 for _,name in ipairs({'Fuseworks','Detonator Plaza','Payload Port'}) do
  local model=originalLibrary:FindFirstChild(name)
  if not model then worldComplete=false
  elseif not model:IsA('Model') or model:GetAttribute('BombTagGenerated')~='HussWorld11' then problem(path(model)..' conflicts with a V11 featured map name; it will not be replaced.');worldComplete=false end
 end
end
if originalLobby and originalLobby:GetAttribute('HussLobbyVersion')~=7 and originalLobby:GetAttribute('HussLobbyVersion')~=11 then problem(path(originalLobby)..' is not a verified V7/V11 lobby; its geometry will be preserved.') end
if not worldComplete then
 for _,model in ipairs({originalLibrary,originalLobby,originalArena}) do if model then
  for _,object in ipairs(model:GetDescendants()) do if object:IsA('BaseScript') and not object.Disabled then problem(path(object)..' is an enabled script inside geometry scheduled for cloning. Its behavior needs verification before the world can be upgraded.') end end
 end end
end
stopPreflight()
note('ServerMain: '..path(main))
note('Gameplay: '..path(round)..'; '..path(bomb))
note(economy and ('Economy: verified existing '..path(economy)) or ('Economy: add '..path(services)..'.EconomyServiceV9'))
local staging=Instance.new('Folder');staging.Name='ExpansionV11Preflight_'..os.time()
while storage:FindFirstChild(staging.Name) do staging.Name..='_' end
staging.Parent=storage
local function compileSource(label,source)
 -- require executes this outer return only. The original script body remains inert.
 -- Each fresh ModuleScript avoids require's cache and compiles LocalScripts/Scripts too.
 local probe=Instance.new('ModuleScript');probe.Name='SyntaxProbe';probe.Parent=staging
 local ok,message=pcall(function()
  probe.Source='return function()\n'..source..'\nend\n'
  assert(probe.Source=='return function()\n'..source..'\nend\n','Source write/read verification failed')
  assert(type(require(probe))=='function','Syntax probe returned unexpected content')
 end)
 probe:Destroy()
 if not ok then problem(label..': Luau syntax check failed: '..tostring(message)) end
end
for _,entry in ipairs(edits) do compileSource(path(entry[1]),entry[2]) end
for _,entry in ipairs(additions) do compileSource(path(entry[1])..'.'..entry[3],entry[4]) end
for _,object in ipairs(dependencySources) do compileSource(path(object),object.Source) end
if #issues>0 then staging:Destroy();stopPreflight() end
local changes={}
for _,entry in ipairs(edits) do if entry[1].Source~=entry[2] then table.insert(changes,entry) end end
local missing=false
for _,entry in ipairs(additions) do if not entry[5] then missing=true end end
local previewsComplete=originalPreviews and #originalPreviews:GetChildren()==worldCount
if previewsComplete then for _,model in ipairs(originalLibrary:GetChildren()) do if model:IsA('Model') then
 local preview=originalPreviews:FindFirstChild(model.Name)
 if not preview or not preview:IsA('Model') then previewsComplete=false;break end
end end end
if worldComplete and previewsComplete and #changes==0 and not missing and workspace:GetAttribute('HussExpansionVersion')==11 then
 staging:Destroy()
 for _,message in ipairs(notes) do print('[V11] '..message) end
 print('V11 already installed: source compatibility, dependencies and Luau syntax verified. No systems duplicated; maps left unchanged.')
 return
end
local backup=Instance.new('Folder');backup.Name='ExpansionV11Backup_'..os.time()
while storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local sourceBackups=Instance.new('Folder');sourceBackups.Name='Scripts';sourceBackups.Parent=backup
local worldBackups=Instance.new('Folder');worldBackups.Name='World';worldBackups.Parent=backup
local originals,newObjects,moved={},{},{}
local built,newPreviews,newArena,chosen
local oldChosen=workspace:GetAttribute('CurrentVotedMap')
local oldVersion=workspace:GetAttribute('HussExpansionVersion')
local ok,err=pcall(function()
 for _,entry in ipairs(changes) do
  local object=entry[1];assert(object.Archivable,path(object)..' must be Archivable so it can be backed up.')
  originals[object]=object.Source
  local copy=object:Clone();assert(copy,'Unable to back up '..path(object));copy.Parent=sourceBackups
  copy:SetAttribute('OriginalPath',path(object))
  if copy:IsA('BaseScript') then copy:SetAttribute('OriginalDisabled',copy.Disabled);copy.Disabled=true end
 end
 for _,entry in ipairs(additions) do if not entry[5] then
  local object=Instance.new(entry[2]);object.Name=entry[3];object.Parent=staging;object.Source=entry[4]
  if object:IsA('BaseScript') then object.Disabled=false end
  assert(object.Source==entry[4],'Source write/read verification failed for '..entry[3]);table.insert(newObjects,{object,entry[1]})
 end end
 if not worldComplete then
  built=worldBuilder.Build(originalLibrary,originalLobby)
  assert(built and built.Library and built.Lobby,'World generator returned no staged world.')
  built.Library.Parent=staging;built.Lobby.Parent=staging
  -- Keep already upgraded new arenas intact in partially installed places.
  for _,name in ipairs({'Fuseworks','Detonator Plaza','Payload Port'}) do
   local existing=originalLibrary:FindFirstChild(name)
   if existing and existing:GetAttribute('BombTagGenerated')=='HussWorld11' then
    local generated=built.Library:FindFirstChild(name);if generated then generated:Destroy() end
    local copy=existing:Clone();assert(copy,'Unable to preserve '..name);copy.Parent=built.Library
   end
  end
 end
 local library=built and built.Library or originalLibrary
 if built or not previewsComplete then
  newPreviews=Instance.new('Folder');newPreviews.Name='BombTagV6Previews';newPreviews.Parent=staging
  local mapCount=0
  for _,map in ipairs(library:GetChildren()) do if map:IsA('Model') then
   mapCount+=1
   assert(map:FindFirstChild('Floor') and map:FindFirstChild('Spawns') and #map.Spawns:GetChildren()>=16,'Incomplete map: '..map.Name)
   local preview=map:Clone();assert(preview,'Map preview cannot be cloned.');preview.Parent=newPreviews
   for _,object in ipairs(preview:GetDescendants()) do
    if object.Name=='Spawns' or object:IsA('LuaSourceContainer') or object:IsA('SurfaceGui') or object:IsA('Light') or (object:IsA('BasePart') and object.Transparency>=1) then object:Destroy() end
   end
  end end
  assert(mapCount>=15,'Expected fifteen completed maps.')
 end
 if built then
  local template=library:FindFirstChild(oldChosen or '') or library:FindFirstChild(originalArena:GetAttribute('VotedMap') or '') or library:FindFirstChild('Sky Garden')
  assert(template,'Unable to select the existing active map.');chosen=template.Name;newArena=template:Clone();assert(newArena,'Cannot clone active arena');newArena.Parent=staging;newArena.Name=originalArena.Name
  local floor=newArena.Floor;newArena:PivotTo(newArena:GetPivot()+anchor.Position-(floor.Position+Vector3.new(0,floor.Size.Y/2,0)))
  newArena:SetAttribute('DisplayName',chosen);newArena:SetAttribute('VotedMap',chosen)
  local empty=Instance.new('Folder');empty.Parent=staging
  local placement=placementBuilder.Plan(built.Lobby,library,empty,anchor);placementBuilder.Apply(placement);empty:Destroy()
 end
 local manifest={'V11 compatibility backup','ServerMain: '..path(main),'','RESTORE SOURCES (copies under Scripts; each has OriginalPath):'}
 for _,entry in ipairs(changes) do table.insert(manifest,path(entry[1])) end
 table.insert(manifest,'');table.insert(manifest,'ADDED SYSTEMS (remove only these objects when undoing this install):')
 for _,entry in ipairs(newObjects) do table.insert(manifest,path(entry[2])..'.'..entry[1].Name) end
 table.insert(manifest,'');table.insert(manifest,'ARCHIVED WORLD OBJECTS (move originals under World back to these locations):')
 if built then for _,object in ipairs({originalLibrary,originalLobby,originalArena}) do table.insert(manifest,path(object)) end end
 if newPreviews and originalPreviews then table.insert(manifest,path(originalPreviews)) end
 if newPreviews and not originalPreviews then table.insert(manifest,'Added preview folder: '..path(replicated)..'.BombTagV6Previews') end
 table.insert(manifest,'');table.insert(manifest,'Restore Workspace attributes from OriginalCurrentVotedMap and OriginalExpansionVersion on this backup folder. A missing attribute means remove it.')
 local record=Instance.new('StringValue');record.Name='RestoreManifest';record.Value=table.concat(manifest,'\n');record.Parent=backup
 backup:SetAttribute('OriginalCurrentVotedMap',oldChosen);backup:SetAttribute('OriginalExpansionVersion',oldVersion)
 backup:SetAttribute('Installer','V11 compatibility installer');backup:SetAttribute('ServerMainPath',path(main))
end)
if not ok then
 if built then if built.Library then built.Library:Destroy() end;if built.Lobby then built.Lobby:Destroy() end end
 staging:Destroy();backup:Destroy();error('V11 staging stopped; originals preserved: '..tostring(err),0)
end
local function archive(object)
 if object then table.insert(moved,{object,object.Parent});object.Parent=worldBackups end
end
ok,err=pcall(function()
 backup.Parent=storage
 for _,entry in ipairs(newObjects) do entry[1].Parent=entry[2] end
 for _,entry in ipairs(changes) do entry[1].Source=entry[2];assert(entry[1].Source==entry[2],'Source write failed: '..path(entry[1])) end
 if built then
  archive(originalLibrary);archive(originalLobby);archive(originalArena)
  built.Library.Parent=storage;built.Lobby.Parent=workspace;newArena.Parent=maps
  workspace:SetAttribute('CurrentVotedMap',chosen)
 end
 if newPreviews then archive(originalPreviews);newPreviews.Parent=replicated end
 workspace:SetAttribute('HussExpansionVersion',11)
end)
if not ok then
 local failures={}
 local function restore(fn) local success,message=pcall(fn);if not success then table.insert(failures,tostring(message)) end end
 for _,entry in ipairs(newObjects) do restore(function() entry[1]:Destroy() end) end
 if built then restore(function() built.Library:Destroy() end);restore(function() built.Lobby:Destroy() end) end
 if newPreviews then restore(function() newPreviews:Destroy() end) end
 if newArena then restore(function() newArena:Destroy() end) end
 for i=#moved,1,-1 do local pair=moved[i];restore(function() pair[1].Parent=pair[2] end) end
 for object,source in pairs(originals) do restore(function() object.Source=source end) end
 restore(function() workspace:SetAttribute('CurrentVotedMap',oldChosen);workspace:SetAttribute('HussExpansionVersion',oldVersion) end)
 staging:Destroy()
 if #failures==0 then backup:Destroy();error('V11 installation rolled back: '..tostring(err)..'. Originals restored.',0) end
 error('V11 stopped. Restore from ServerStorage/'..backup.Name..'. Restore errors: '..table.concat(failures,'; ')..'. Original error: '..tostring(err),0)
end
staging:Destroy()
for _,message in ipairs(notes) do print('[V11] '..message) end
print('V11 installed: compatible source, dependency and Luau syntax checks passed. Gameplay, voting, AFK, movement and HUD callbacks retained.')
print('25 bombs, 25 trails, titles, emotes, physical shops and boards, practice bots and fifteen maps. Studio progression is temporary.')
print('Backup: ServerStorage/'..backup.Name..'. Save a new place copy, then playtest with one and two players.')
