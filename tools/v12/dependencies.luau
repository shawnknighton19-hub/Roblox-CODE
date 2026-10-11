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
