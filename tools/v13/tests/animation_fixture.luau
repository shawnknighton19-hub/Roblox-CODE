local assertions=0
local function check(value, message)
 assertions+=1
 assert(value,message or ('assertion '..assertions))
end
local function signal()
 local listeners={}
 return {Connect=function(self,fn)
  local c={Connected=true};function c:Disconnect() self.Connected=false end
  table.insert(listeners,{fn=fn,c=c});return c
 end,Fire=function(self,...)
  for _,x in ipairs(table.clone(listeners)) do if x.c.Connected then x.fn(...) end end
 end,Count=function() local n=0;for _,x in ipairs(listeners) do if x.c.Connected then n+=1 end end;return n end}
end
local function vector(x,y,z) return {X=x,Y=y,Z=z,Magnitude=math.sqrt(x*x+y*y+z*z)} end
local function fixture(options)
 options=options or {}
 local f={now=0,queue={},objects={},tracks={},warnings={},loads={},failures=options.failures or {},spawned=0}
 local function spawn(fn,...)
  local args=table.pack(...)
  local co=coroutine.create(function() fn(table.unpack(args,1,args.n)) end)
  table.insert(f.queue,{co=co,due=f.now})
 end
 local function pump()
  local count=0
  while true do
   local index
   for i,q in ipairs(f.queue) do if q.due<=f.now+.00001 then index=i;break end end
   if not index then break end
   count+=1;assert(count<10000,'scheduler hung')
   local q=table.remove(f.queue,index)
   local ok,delay=coroutine.resume(q.co)
   assert(ok,delay)
   if coroutine.status(q.co)~='dead' then table.insert(f.queue,{co=q.co,due=f.now+(delay or .01)}) end
  end
 end
 local function instance(class,name)
  local o={ClassName=class,Name=name or class,children={},attrs={},Destroying=signal(),AncestryChanged=signal()}
  function o:IsA(c) return self.ClassName==c end
  function o:GetChildren() return table.clone(self.children) end
  function o:GetAttribute(k) return self.attrs[k] end
  function o:SetAttribute(k,v) self.attrs[k]=v end
  function o:FindFirstChild(n) for _,c in ipairs(self.children) do if c.Name==n then return c end end end
  function o:FindFirstChildOfClass(n) for _,c in ipairs(self.children) do if c.ClassName==n then return c end end end
  function o:WaitForChild(n,timeout)
   local deadline=f.now+(timeout or 10)
   while not self:FindFirstChild(n) and f.now<deadline do coroutine.yield(.05) end
   return self:FindFirstChild(n)
  end
  function o:IsDescendantOf(ancestor)
   local p=self.Parent
   while p do if p==ancestor then return true end;p=p.Parent end
   return false
  end
  function o:Destroy()
   self.destroyed=true;self.Destroying:Fire();self.Parent=nil
  end
  setmetatable(o,{__index=function(t,k) if k=='Parent' then return rawget(t,'_parent') end end,
   __newindex=function(t,k,v)
    if k=='Parent' then
     local old=rawget(t,'_parent')
     if old then for i,c in ipairs(old.children) do if c==t then table.remove(old.children,i);break end end end
     rawset(t,'_parent',v)
     if v then table.insert(v.children,t) end
    else rawset(t,k,v) end
   end})
  if class=='Animator' then
   function o:LoadAnimation(animation)
    table.insert(f.loads,animation.AnimationId)
    local failure=f.failures[animation.AnimationId]
    if failure=='throw' then error('asset blocked') end
    local ready=type(failure)=='number' and f.now+failure or failure=='never' and math.huge or f.now
    local track={animation=animation,plays=0,stops=0,adjusts=0,IsPlaying=false}
    setmetatable(track,{__index=function(_,k) if k=='Length' then return f.now>=ready and 1 or 0 end end})
    function track:Play(fade,weight,speed) if failure=='play' then error('play denied') end;self.plays+=1;self.IsPlaying=true;self.speed=speed end
    function track:Stop() self.stops+=1;self.IsPlaying=false end
    function track:AdjustSpeed(speed) self.adjusts+=1;self.speed=speed end
    function track:Destroy() self.destroyed=true;self.IsPlaying=false end
    table.insert(f.tracks,track)
    return track
   end
  end
  table.insert(f.objects,o)
  return o
 end
 f.instance=instance
 local ws=instance('Workspace');f.workspace=ws
 local run={PreAnimation=signal()};f.run=run
 local character=instance('Model','Character');character.Parent=options.outside and instance('Folder','NotWorkspace') or ws;f.character=character
 local humanoid=instance('Humanoid');humanoid.Parent=character;humanoid.Health=100;humanoid.Died=signal();humanoid.RigType=options.r15 and 'R15' or 'R6';humanoid.FloorMaterial='Grass';humanoid.MoveDirection=vector(0,0,0);humanoid.state='Running'
 function humanoid:GetState() return self.state end
 f.humanoid=humanoid
 local root=instance('Part','HumanoidRootPart');root.Parent=character;root.AssemblyLinearVelocity=vector(0,0,0);root.Anchored=false;f.root=root
 local player=instance('Player','Tester');player.Character=character;player.CharacterAdded=signal();player.CharacterRemoving=signal();f.player=player
 local players={PlayerAdded=signal(),PlayerRemoving=signal()}
 function players:GetPlayers() return {player} end
 function players:GetPlayerFromCharacter(c) return c==player.Character and player or nil end
 f.players=players
 local scriptObject=instance('LocalScript','Animate');scriptObject.Parent=character;f.script=scriptObject
 local env=setmetatable({game={GetService=function(_,n) return n=='Players' and players or n=='RunService' and run or error(n) end},
  workspace=ws,script=scriptObject,Instance={new=function(c) return instance(c) end},
  Vector3={new=vector},Enum={HumanoidRigType={R6='R6',R15='R15'},AnimationPriority={Idle='Idle',Movement='Movement'},
  Material={Air='Air'},HumanoidStateType={Dead='Dead',Ragdoll='Ragdoll',Physics='Physics',Seated='Seated'}},
  os={clock=function() return f.now end},task={spawn=spawn,wait=function(delay) return coroutine.yield(delay or .01) end},
  warn=function(...) table.insert(f.warnings,table.concat({...},' ')) end}, {__index=getfenv()})
 f.env=env
 function f:start(source)
  local fn,err=loadstring(source);assert(fn,err);setfenv(fn,env);spawn(fn);pump()
 end
 function f:step(seconds)
  local stop=self.now+seconds
  repeat self.now=math.min(stop,self.now+.05);pump();run.PreAnimation:Fire() until self.now>=stop
 end
 function f:animator(marked)
  local a=instance('Animator');a.Parent=humanoid;if marked~=false then a:SetAttribute('HussServerAnimatorV13',true) end;return a
 end
 function f:playing()
  local found
  for _,t in ipairs(self.tracks) do if t.IsPlaying then check(found==nil,'only one base track may play');found=t end end
  return found
 end
 function f:client()
  if not options.noAnimator then self:animator() end
  self:start(clientSource);self:step(.1)
 end
 return f
end
local CUSTOM={Idle='rbxassetid://86722180453998',Walk='rbxassetid://128318370222834',Run='rbxassetid://124106396906271',Fall='rbxassetid://103035488330716'}
local f=fixture();f:client()
check(#f.loads==8,'four independent custom and fallback clips')
check(f:playing().animation.AnimationId==CUSTOM.Idle,'custom idle preferred')
local idle=f:playing();f:step(.5);check(idle.plays==1,'no idle restart per frame')
f.humanoid.MoveDirection=vector(0,0,1);f.root.AssemblyLinearVelocity=vector(0,0,24);f.character:SetAttribute('MovementState','Run');f:step(.1)
check(f:playing().animation.AnimationId==CUSTOM.Walk,'walk selected')
f.character:SetAttribute('MovementState','Sprint');f.root.AssemblyLinearVelocity=vector(0,0,32);f:step(.1)
check(f:playing().animation.AnimationId==CUSTOM.Run,'sprint selected')
local run=f:playing();f:step(.5);check(run.plays==1,'no sprint restart per frame')
f.root.AssemblyLinearVelocity=vector(0,0,40);f:step(.1);check(run.adjusts==1 and run.speed==1.25,'speed adjustment without restart')
f.humanoid.FloorMaterial='Air';f:step(.1);check(f:playing().animation.AnimationId==CUSTOM.Fall,'fall independent')
f.root.Anchored=true;f:step(.1);check(f:playing().animation.AnimationId==CUSTOM.Idle,'round lock idle')
f.root.Anchored=false;f.player:SetAttribute('HussEmotePlaying','emote_wave');f:step(.1);check(f:playing()==nil,'emote owns posing')
f.player:SetAttribute('HussEmotePlaying',nil);f.humanoid.state='Ragdoll';f:step(.1);check(f:playing()==nil,'ragdoll owns posing')
f.humanoid.state='Running';f.humanoid.FloorMaterial='Grass';f:step(.1);check(f:playing()~=nil,'animation recovers after ragdoll')
for _,t in ipairs(f.tracks) do check(t.Priority~='Action','no asset dodge competing with V6') end
f.humanoid.Health=0;f.humanoid.Died:Fire();check(f.run.PreAnimation:Count()==0,'death disconnects update')
for _,t in ipairs(f.tracks) do check(t.destroyed,'death destroys every loaded track') end

local thrown=fixture({failures={[CUSTOM.Idle]='throw'}});thrown:client()
check(thrown:playing().animation.AnimationId=='rbxassetid://180435571','throw uses fallback')
check(#thrown.loads==8,'failed first load cannot abort others')
thrown.humanoid.MoveDirection=vector(0,0,1);thrown.root.AssemblyLinearVelocity=vector(0,0,32);thrown.character:SetAttribute('MovementState','Sprint');thrown:step(.1)
check(thrown:playing().animation.AnimationId==CUSTOM.Run,'other custom states unaffected')

local never=fixture({failures={[CUSTOM.Idle]='never'}});never:client()
check(never:playing().animation.AnimationId=='rbxassetid://180435571','zero-length custom never blocks fallback')
never:step(9);check(#never.warnings==1,'zero-length timeout warns once')
check(#never.queue==0,'zero-length bounded wait terminates')
check(never.warnings[1]:find('no playable clip',1,true)~=nil,'diagnostic distinguishes asynchronous load failure')
local deniedTrack
for _,t in ipairs(never.tracks) do if t.animation.AnimationId==CUSTOM.Idle then deniedTrack=t end end
check(deniedTrack.destroyed,'unusable zero-Length track destroyed')

local delayed=fixture({failures={[CUSTOM.Idle]=1}});delayed:client()
local prior=delayed:playing();check(prior.animation.AnimationId=='rbxassetid://180435571','default while custom loads')
delayed:step(1.1);check(delayed:playing().animation.AnimationId==CUSTOM.Idle,'late valid custom replaces fallback')
check(prior.stops==1,'replacement stops previous once')

local both=fixture({failures={[CUSTOM.Idle]='never',['rbxassetid://180435571']='never'}});both:client();both:step(9)
check(both:playing()==nil and #both.warnings==2,'both failed bounded and explicit')
both.humanoid.MoveDirection=vector(0,0,1);both.root.AssemblyLinearVelocity=vector(0,0,24);both:step(.1)
check(both:playing().animation.AnimationId==CUSTOM.Walk,'both failed idle does not stop walking')

local r15=fixture({r15=true});r15:client()
check(#r15.loads==4,'R15 loads only matched public fallback')
for _,id in ipairs(r15.loads) do for _,custom in pairs(CUSTOM) do check(id~=custom,'R15 never loads R6 custom clip') end end
check(r15:playing().animation.AnimationId=='rbxassetid://507766666','R15 idle fallback')
check(#r15.warnings==1 and r15.warnings[1]:find('Avatar Settings',1,true),'R15 warns manual rig setting')

local removed=fixture({failures={[CUSTOM.Idle]='never',[CUSTOM.Walk]='never'}});removed:client()
removed.character.Parent=nil;removed.character.AncestryChanged:Fire();removed:step(.2)
check(removed.run.PreAnimation:Count()==0,'removal cleans update')
check(#removed.queue==0,'removal stops pending load waits')
for _,t in ipairs(removed.tracks) do check(t.destroyed,'removal destroys loaded and pending tracks') end

local outside=fixture({outside=true});outside:client();check(#outside.loads==0,'never LoadAnimation outside Workspace')
outside.character.Parent=outside.workspace;outside:step(.2);check(#outside.loads==8,'load resumes after Workspace insertion')
local absent=fixture({outside=true});absent:client();absent:step(11);check(#absent.loads==0 and #absent.warnings==1,'outside Workspace startup bounded')
local missing=fixture({noAnimator=true});missing:client();missing:step(11)
check(#missing.loads==0 and #missing.warnings==1,'missing server Animator fails explicitly')
local unmarked=fixture({noAnimator=true});unmarked:animator(false);unmarked:client();unmarked:step(.2)
check(#unmarked.loads==0,'client-created unmarked Animator is not selected')
unmarked:animator(true);unmarked:step(.2);check(#unmarked.loads==8,'replicated marked Animator selected later')

local server=fixture({noAnimator=true});server:start(serverSource);server:step(.1)
local a=server.humanoid:FindFirstChildOfClass('Animator')
check(a~=nil and a:GetAttribute('HussServerAnimatorV13')==true,'server creates and marks Animator')
server.player.CharacterAdded:Fire(server.character);server:step(.1)
local count=0;for _,o in ipairs(server.humanoid.children) do if o.ClassName=='Animator' then count+=1 end end
check(count==1,'repeated CharacterAdded creates no duplicate Animator')
local existing=fixture({noAnimator=true});local original=existing:animator(false);existing:start(serverSource);existing:step(.1)
check(existing.humanoid:FindFirstChildOfClass('Animator')==original and original:GetAttribute('HussServerAnimatorV13'),'existing server Animator retained and marked')
local late=fixture({noAnimator=true});late.humanoid.Parent=nil;late:start(serverSource)
late.player.CharacterRemoving:Fire(late.character);late.player.Character=nil;late.humanoid.Parent=late.character;late:step(.2)
check(late.humanoid:FindFirstChildOfClass('Animator')==nil,'stale character task cannot initialize removed spawn')
local r15server=fixture({r15=true,noAnimator=true});r15server:start(serverSource);r15server:step(.1)
r15server.player.CharacterAdded:Fire(r15server.character);r15server:step(.1)
check(#r15server.warnings==1,'one server rig warning per player')
r15server.script:Destroy();check(r15server.players.PlayerAdded:Count()==0,'server script cleanup disconnects global listener')

local adapter=assert(loadstring(adapterSource))()
check(adapter.Adapt(oldSource,clientSource)==clientSource,'uploaded known source adapts')
check(adapter.Adapt(v5Source,clientSource)==clientSource,'V5 known source adapts')
check(adapter.Adapt(clientSource,clientSource)==clientSource,'target rerun exact')
local custom=oldSource:gsub('86722180453998','123456789012345',1)
local adapted=adapter.Adapt(custom,clientSource)
check(adapted:find('rbxassetid://123456789012345',1,true)~=nil,'approved custom idle ID retained')
check(adapter.Adapt(adapted,clientSource)==adapted,'configured target rerun stable')
local ok=pcall(adapter.Adapt,oldSource..'\nprint("unexpected")',clientSource);check(not ok,'extra executable source rejected')
ok=pcall(adapter.Adapt,oldSource:gsub('86722180453998','bad-id',1),clientSource);check(not ok,'malformed asset ID rejected')
ok=pcall(adapter.Adapt,oldSource:gsub('86722180453998','9007199254740992',1),clientSource);check(not ok,'unsafe imprecise asset number rejected')
local child={untouched=true};local obj={IsA=function(_,c)return c=='LocalScript'end,GetChildren=function()return{child}end}
check(#adapter.ValidateChildren(obj)==0 and child.untouched,'children preserved')
print('ANIMATION_ASSERTIONS='..assertions)
