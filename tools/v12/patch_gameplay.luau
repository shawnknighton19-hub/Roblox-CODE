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
