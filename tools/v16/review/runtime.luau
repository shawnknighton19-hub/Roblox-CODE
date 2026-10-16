-- Deterministic service adapter, not Roblox engine emulation.
-- Actual dependency modules and bootstrap execute unchanged in this adapter.
local function newEnvironment(options)
 options=options or {}
 local e={now=0,queue={},errors={},warnings={},prints={},events={},loaded={},storeCalls=0,orderedCalls=0,updates=0,durable=options.durable or {}}
 local function signal()
  local s={links={}}
  function s:Connect(fn) local c={Connected=true};function c:Disconnect()self.Connected=false end;s.links[#s.links+1]={fn,c};return c end
  function s:Once(fn)local link;link=self:Connect(function(...)link:Disconnect();fn(...)end);return link end
  function s:Fire(...)for _,v in ipairs(self.links)do if v[2].Connected then v[1](...)end end end
  function s:Wait() error('Unimplemented signal wait; fixture must produce the event before testing this path')end
  return s
 end
 local task={}
 local function enqueue(fn,delay,...)
  local args=table.pack(...);local co=type(fn)=='thread' and fn or coroutine.create(function()fn(table.unpack(args,1,args.n))end)
  table.insert(e.queue,{co=co,at=e.now+(delay or 0)});return co
 end
 function task.spawn(fn,...)return enqueue(fn,0,...)end
 task.defer=task.spawn
 function task.delay(delay,fn,...)return enqueue(fn,delay,...)end
 function task.wait(delay)return coroutine.yield(math.max(.001,delay or .03))end
 function task.cancel(co)for i=#e.queue,1,-1 do if e.queue[i].co==co then table.remove(e.queue,i)end end end
 local os={clock=function()return e.now end,time=function()return 1900000000+math.floor(e.now)end}
 local function words(...)local t={};for _,v in ipairs({...})do t[#t+1]=tostring(v)end;return table.concat(t,' ')end
 local warn=function(...)e.warnings[#e.warnings+1]=words(...)end
 local print=function(...)e.prints[#e.prints+1]=words(...)end
 local services={}
 local workspace
 local game={JobId='fixture-job',CreatorId=701,CreatorType=Enum.CreatorType.User,PlaceId=options.unpublished and 0 or 100}
 local Instance={};local baseNew=InstanceBase.new
 local propsDefault={}
 function Instance.new(class,parent)
  local o=baseNew(class)
  o._signals={};o.Destroying=signal();o.AncestryChanged=signal();o.ChildAdded=signal();o.DescendantAdded=signal()
  if o:IsA('BasePart')then o.AssemblyLinearVelocity=Vector3.zero;o.AssemblyAngularVelocity=Vector3.zero;o.Orientation=Vector3.zero;o.CollisionGroup='Default';o.Anchored=false end
  if class=='Humanoid'then o.MaxHealth=100;o.Health=100;o.RigType=Enum.HumanoidRigType.R6;o.HipHeight=0;o.MoveDirection=Vector3.zero;o.WalkSpeed=16;o.Died=signal();o.StateChanged=signal()end
  if class=='Player'then o.CharacterAdded=signal();o.CharacterRemoving=signal();o.Chatted=signal()end
  if class=='RemoteEvent'then
   o.OnServerEvent=signal();o.OnClientEvent=signal()
   o.FireAllClients=function(_,...)e.events[#e.events+1]={remote=o.Name,time=e.now,args=table.pack(...)}end
   o.FireClient=function(_,p,...)e.events[#e.events+1]={remote=o.Name,player=p,time=e.now,args=table.pack(...)}end
  end
  if class=='TextChatCommand'then o.PrimaryAlias='';o.SecondaryAlias='';o.Triggered=signal()end
  if class=='IntValue' or class=='BoolValue'then o.Value=class=='IntValue' and 0 or false end
  if class=='BindableEvent'then o.Event=signal();o.Fire=function(_,...)o.Event:Fire(...)end end
  if parent then o.Parent=parent end
  return o
 end
 local originalSetAttribute=methods.SetAttribute
 function methods:SetAttribute(k,v)local old=self:GetAttribute(k);originalSetAttribute(self,k,v);if old~=v and self._signals and self._signals[k]then self._signals[k]:Fire()end end
 function methods:GetAttributeChangedSignal(k)self._signals=self._signals or {};self._signals[k]=self._signals[k]or signal();return self._signals[k]end
 function methods:GetPropertyChangedSignal(k)return self:GetAttributeChangedSignal('property:'..k)end
 function methods:WaitForChild(name,timeout)local found=self:FindFirstChild(name);assert(found,'Fixture missing actual world dependency '..self:GetFullName()..'/'..name);return found end
 function methods:FindFirstChildWhichIsA(class,recurse)for _,v in ipairs(recurse and self:GetDescendants()or self:GetChildren())do if v:IsA(class)then return v end end end
 function methods:IsDescendantOf(parent)local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
 function methods:GetBoundingBox()return self:GetPivot(),Vector3.new(4,5,2)end
 function methods:SetStateEnabled()end
 function methods:ChangeState()end
 function methods:GetState()return Enum.HumanoidStateType.Running end
 function methods:SetNetworkOwner()end
 function methods:Move(direction)self.MoveDirection=direction end
 function methods:MoveTo(position)self.WalkToPoint=position end
 function methods:GetVelocityAtPosition()return self.AssemblyLinearVelocity end
 function methods:LoadCharacter()
  if self.Character then self.CharacterRemoving:Fire(self.Character);self.Character:Destroy()end
  local c=Instance.new('Model');c.Name=self.Name
  local h=Instance.new('Humanoid',c);local r=Instance.new('Part',c);r.Name='HumanoidRootPart';r.Size=Vector3.new(2,2,1)
  for _,n in ipairs({'Torso','Head','Left Arm','Right Arm','Left Leg','Right Leg'})do local p=Instance.new('Part',c);p.Name=n;p.Size=Vector3.new(1,2,1)end
  c.PrimaryPart=r;c.Parent=workspace;self.Character=c;self.CharacterAdded:Fire(c)
 end
 for _,name in ipairs({'Workspace','Players','ReplicatedStorage','ServerStorage','ServerScriptService','RunService','HttpService','DataStoreService','CollectionService','GroupService','TextChatService','PolicyService','ProximityPromptService','MarketplaceService','PathfindingService','Debris','TweenService','PhysicsService','SoundService','EncodingService'})do services[name]=Instance.new(name);services[name].Name=name end
 workspace=services.Workspace
 function game:GetService(name)assert(services[name],'Unimplemented service '..name);return services[name]end
 function game:BindToClose(fn)e.close=fn end
 workspace.GetServerTimeNow=function()return e.now end
 workspace.Raycast=function(_,origin,direction,params)
  if direction.Y>=-.5 then return nil end
  local arena=workspace:FindFirstChild('Maps');local model=arena and arena:FindFirstChild('Sky Garden');local floor=model and model:FindFirstChild('Floor')
  if not floor then return nil end
  local top=floor.Position.Y+floor.Size.Y*.5
  local distance=(top-origin.Y)/direction.Y
  if distance<0 or distance>1 then return nil end
  return {Instance=floor,Position=origin+direction*distance,Normal=Vector3.yAxis,Distance=(direction*distance).Magnitude}
 end
 services.RunService.Heartbeat=signal();services.RunService.Stepped=signal()
 services.RunService.IsStudio=function()return options.studio~=false end
 services.RunService.IsServer=function()return true end
 services.RunService.IsClient=function()return false end
 services.RunService.IsRunning=function()return true end
 local players=services.Players;players.PlayerAdded=signal();players.PlayerRemoving=signal()
 players.GetPlayers=methods.GetChildren
 players.GetPlayerByUserId=function(_,id)for _,p in ipairs(players:GetPlayers())do if p.UserId==id then return p end end end
 players.GetPlayerFromCharacter=function(_,c)for _,p in ipairs(players:GetPlayers())do if p.Character==c then return p end end end
 players.GetNameFromUserIdAsync=function(_,id)return 'User'..id end
 services.EncodingService.Base64Decode=function(_,value)assert(buffer.tostring(value)==originalArchiveBase64,'Unexpected packed archive');return buffer.fromstring('validated-archive')end
 services.EncodingService.GetDecompressedBufferSize=function()return #originalArchiveJSON end
 services.EncodingService.DecompressBuffer=function(_,packed)assert(buffer.tostring(packed)=='validated-archive');return buffer.fromstring(originalArchiveJSON)end
 services.HttpService.JSONDecode=function(_,data)assert(data==originalArchiveJSON,'Unexpected JSON input');return originalArchiveData end
 local serial=0;services.HttpService.GenerateGUID=function()serial+=1;return 'fixture-'..serial end
 services.TextChatService.ChatVersion=Enum.ChatVersion.TextChatService
 services.GroupService.GetGroupInfoAsync=function()return {Owner={Id=701}}end
 services.CollectionService.GetTagged=function(_,tag)local found={};for _,s in pairs(services)do for _,v in ipairs(s:GetDescendants())do if v:GetAttribute('FixtureTag')==tag or v._fixtureTags and table.find(v._fixtureTags,tag) then found[#found+1]=v end end end;return found end
 services.CollectionService.GetInstanceAddedSignal=function()return signal()end
 services.CollectionService.GetInstanceRemovedSignal=function()return signal()end
 services.PolicyService.GetPolicyInfoForPlayerAsync=function()return {ArePaidRandomItemsRestricted=false}end
 services.ProximityPromptService.PromptTriggered=signal()
 services.MarketplaceService.PromptGamePassPurchaseFinished=signal()
 services.MarketplaceService.UserOwnsGamePassAsync=function()return false end
 services.Debris.AddItem=function(_,o,t)task.delay(t or 0,function()o:Destroy()end)end
 services.TweenService.Create=function(_,o,info,props)return {Play=function()for k,v in pairs(props)do o[k]=v end end,Completed=signal()}end
 services.PathfindingService.CreatePath=function()return {ComputeAsync=function()end,Status=Enum.PathStatus.NoPath,Destroy=function()end,GetWaypoints=function()return {}end}end
 local function clone(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=clone(v)end;return out end
 local profile={}
 function profile:UpdateAsync(key,fn)
  e.updates+=1;if options.updateFails then error('DataStore API access denied by test')end
  local nextValue=fn(clone(e.durable[key]),{GetUserIds=function()return {}end,GetMetadata=function()return {}end})
  if nextValue~=nil then e.durable[key]=clone(nextValue)end
  return clone(nextValue)
 end
 local ranking={UpdateAsync=function(_,key,fn)return fn(0)end,GetSortedAsync=function()return {GetCurrentPage=function()return {}end}end}
 services.DataStoreService.GetDataStore=function(_,name)
  e.storeCalls+=1;e.storeName=name;if options.storeFails then error('You must publish this place to the web to access DataStore.')end;return profile
 end
 services.DataStoreService.GetOrderedDataStore=function(_,name)
  e.orderedCalls+=1;e.orderedName=name;if options.orderedFails then error('OrderedDataStore unavailable')end;return ranking
 end
 services.DataStoreService.GetRequestBudgetForRequestType=function()return 100 end
 local RaycastParams={new=function()return {}end}
 local OverlapParams={new=function()return {}end}
 local Random={new=function()return {NextInteger=function(_,a,b)return a end,NextNumber=function(_,a,b)return a or .5 end}end}
 local NumberSequence={new=function(...)return {...}end};local NumberSequenceKeypoint={new=function(...)return {...}end}
 local ColorSequence={new=function(...)return {...}end};local ColorSequenceKeypoint={new=function(...)return {...}end}
 local NumberRange={new=function(a,b)return {Min=a,Max=b or a}end}
 local TweenInfo={new=function(...)return {...}end}
 local PhysicalProperties={new=function(...)return {...}end}
 local sources,cache,loading={},{},{}
 local function require(module)
  assert(typeof(module)=='Instance' and module:IsA('ModuleScript'),'require needs a real ModuleScript fixture')
  if cache[module]then return cache[module]end
  assert(not loading[module],'Circular dependency '..module:GetFullName())
  local builder=sources[module:GetFullName()];assert(builder,'Missing actual module body '..module:GetFullName())
  loading[module]=true;local result=builder(module);loading[module]=nil;assert(result~=nil,'Module returned nil: '..module:GetFullName());cache[module]=result;e.loaded[#e.loaded+1]=module:GetFullName();return result
 end
 -- SOURCES_INSERT
 -- WORLD_INSERT
 function e:step(seconds)
  local target=self.now+seconds;local iterations=0
  while true do
   local index,at=nil,math.huge
   for i,q in ipairs(self.queue)do if q.at<at then at=q.at;index=i end end
   if not index or at>target then break end
   iterations+=1;assert(iterations<100000,'Scheduler runaway')
   local q=table.remove(self.queue,index);self.now=at
   local ok,delay=coroutine.resume(q.co)
   if not ok then self.errors[#self.errors+1]=tostring(delay)..'\n'..debug.traceback(q.co)
   elseif coroutine.status(q.co)~='dead'then q.at=self.now+(delay or .03);self.queue[#self.queue+1]=q end
  end
  self.now=target
 end
 function e:add(id)
  local p=Instance.new('Player');p.UserId=id;p.Name='User'..id;p.DisplayName=p.Name;p.Parent=players;p:LoadCharacter();players.PlayerAdded:Fire(p);return p
 end
 function e:remove(p)players.PlayerRemoving:Fire(p);p.Parent=nil end
 function e:bootOthers()
  for _,name in ipairs({'DodgeIFrameServer','BombTagAFKServer','HABCrateBoot'})do
   local node=services.ServerScriptService[name]
   local ok,why=pcall(sources[node:GetFullName()],node)
   assert(ok,why)
  end
 end
 function e:boot()
  local main=services.ServerScriptService.Services.ServerMain
  local ok,problem=pcall(sources[main:GetFullName()],main)
  return ok,problem
 end
 function e:module(path)local at=services;for name in path:gmatch('[^/]+')do at=at[name]end;return require(at)end
 function e:hasPhase(phase)for _,event in ipairs(self.events)do if event.remote=='RoundState'and event.args[1].State==phase then return true end end;return false end
 e.services=services;e.options=options;e.require=require;e.task=task
 task.spawn(function()while true do task.wait(1/30);services.RunService.Heartbeat:Fire(1/30)end end)
 return e
end
