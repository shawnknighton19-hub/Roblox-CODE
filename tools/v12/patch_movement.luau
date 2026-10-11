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
