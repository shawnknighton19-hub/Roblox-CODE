-- Signals and instances are narrow API adapters; production modules run intact.
local typeof=function(value)
 if type(value)=='table' then return value._instance and 'Instance' or value._kind or 'table' end
 return rawTypeof(value)
end
local V=Vector3.new
local checks=0
local function check(value,message)
 checks+=1;assert(value,message or ('check '..checks))
end
local function near(a,b,message) check(math.abs(a-b)<1e-7,message) end
local function signal()
 local s={listeners={}}
 function s:Connect(fn)
  local c={Connected=true};function c:Disconnect() self.Connected=false end
  self.listeners[#self.listeners+1]={fn,c};return c
 end
 function s:Fire(...)
  for _,entry in ipairs(self.listeners) do if entry[2].Connected then entry[1](...) end end
 end
 return s
end
local function node(class,name)
 local n={_instance=true,ClassName=class,Name=name or class,attributes={},children={},signals={},AncestryChanged=signal()}
 function n:IsA(kind) return self.ClassName==kind or (kind=='BasePart' and self.ClassName=='Part') end
 function n:GetAttribute(key) return self.attributes[key] end
 function n:SetAttribute(key,value)
  local old=self.attributes[key];self.attributes[key]=value
  if old~=value and self.signals[key] then self.signals[key]:Fire() end
 end
 function n:GetAttributeChangedSignal(key) self.signals[key]=self.signals[key] or signal();return self.signals[key] end
 function n:FindFirstChild(key) return self.children[key] end
 function n:WaitForChild(key) return assert(self.children[key] or self[key],'missing '..key) end
 function n:FindFirstChildOfClass(kind) for _,child in pairs(self.children) do if child:IsA(kind) then return child end end end
 function n:Destroy() self.Parent=nil;self.destroyed=true;self.AncestryChanged:Fire(self,nil) end
 function n:ChangeState(state) self.state=state end
 return n
end
local function put(parent,child) parent.children[child.Name]=child;parent[child.Name]=child;child.Parent=parent;return child end
local enum=setmetatable({}, {__index=function(t,key)
 local group=setmetatable({}, {__index=function(g,k) rawset(g,k,key..'.'..k);return rawget(g,k) end});rawset(t,key,group);return group
end})
local function evaluate(source,environment)
 local fn=assert(loadstring(source));setfenv(fn,setmetatable(environment,{__index=getfenv()}));return fn()
end
local Config=evaluate(configSource,{Color3=Color3})
local Rules=evaluate(rulesSource,{Vector3=Vector3,typeof=typeof})
local function scenario()
 local e={now=100,logs={},wallZ=nil,ceilingY=nil,ground=true,players={},perfect=0,passes={},owned=true,selected='Speed',delays={}}
 local workspace=node('Workspace','Workspace')
 function workspace:GetServerTimeNow() return e.now end
 function workspace:Raycast(origin,direction,params)
  check(params.RespectCanCollide==true,'all contact queries respect collision')
  local best
  local function plane(axis,value,normal)
   if not value or math.abs(direction[axis])<1e-8 then return end
   local alpha=(value-origin[axis])/direction[axis]
   if alpha>=0 and alpha<=1 and (not best or alpha<best.Alpha) then best={Position=origin+direction*alpha,Normal=normal,Alpha=alpha} end
  end
  plane('Z',e.wallZ,V(0,0,1))
  if direction.Y<0 and e.ground then plane('Y',0,V(0,1,0)) end
  if direction.Y>0 then plane('Y',e.ceilingY,V(0,-1,0)) end
  return best
 end
 e.workspace=workspace
 local players=node('Players','Players');players.PlayerAdded=signal();players.PlayerRemoving=signal()
 function players:GetPlayers() return table.clone(e.players) end
 local rs=node('ReplicatedStorage','ReplicatedStorage')
 local x=put(rs,node('Folder','HABExpansion'))
 put(x,node('ModuleScript','Config')).value=Config
 put(x,node('ModuleScript','CombatRules')).value=Rules
 local input=put(x,node('RemoteEvent','Action'));input.OnServerEvent=signal()
 local fx=put(x,node('RemoteEvent','FX'))
 function fx:FireAllClients(value) table.insert(e.logs,value) end
 function fx:FireClient(p,value) value.Recipient=p;table.insert(e.logs,value) end
 local shared=put(rs,node('Folder','Shared'));local net=put(shared,node('Folder','Net'))
 local dodge=put(net,node('RemoteEvent','DodgeIFrameRequest'));dodge.OnServerEvent=signal()
 function dodge:FireAllClients(...) e.dodgeEvent={...} end
 e.input=input;e.dodge=dodge
 local services=node('Folder','Services')
 local pass=put(services,node('ModuleScript','HABPassService'));pass.value={Init=function() end,Has=function(p,key) return e.passes[key]==true end}
 local economy=put(services,node('ModuleScript','EconomyServiceV9'))
 economy.value={HABSelectedAbility=function() return e.selected end,HABCanUseAbility=function() return e.owned end}
 put(services,node('ModuleScript','PerfectWeaveServiceV11')).value={Try=function() e.perfect+=1 end}
 local module=put(services,node('ModuleScript','HABActionService'))
 local game={};function game:GetService(name) return ({Players=players,ReplicatedStorage=rs,RunService={}})[name] end
 local env={game=game,workspace=workspace,Vector3=Vector3,Color3=Color3,typeof=typeof,Enum=enum,script=module,
  type=function(v) return type(v)=='table' and v._instance and 'userdata' or type(v) end,
  RaycastParams={new=function() return {} end},require=function(m) return assert(m.value) end,
  Instance={new=node},print=function() end,task={delay=function(dt,fn) e.delays[#e.delays+1]={e.now+dt,fn} end}}
 e.env=env
 function e:actor(id,position,bot)
  local p=node('Player','Player'..id);p.UserId=id;p.Parent=players;p.CharacterAdded=signal();p.DisplayName=p.Name
  local c=node('Model',p.Name);c.Parent=workspace;p.Character=c
  local h=put(c,node('Humanoid','Humanoid'));h.Health=100;h.HipHeight=0;h.Sit=false;h.PlatformStand=false;h.Died=signal();h.FloorMaterial=enum.Material.Grass
  local r=put(c,node('Part','HumanoidRootPart'));r.Position=position or V(0,3,0);r.Size=V(2,2,1);r.CFrame=CFrame.new(r.Position);r.AssemblyLinearVelocity=V(0,0,0);r.CollisionGroup='Players';r.Anchored=false
  function r:GetNetworkOwner() if e.ownerError then error('ownership unavailable') end;if e.serverOwned then return nil end;return p end
  put(c,node('Part','Torso')).Size=V(2,2,1)
  put(c,node('Part','Left Leg')).Size=V(1,2,1)
  p:SetAttribute('InRound',true)
  if bot then p._instance=nil;p.ClassName='Actor' else table.insert(e.players,p) end
  return p,r,h,c
 end
 e.a,e.ar,e.ah,e.ac=e:actor(1,V(0,3,0))
 e.b,e.br,e.bh,e.bc=e:actor(2,V(0,3,-5))
 e.service=evaluate(actionSource,env);e.service.Init()
 e.service.SetCarrier(e.a,e.now+30,e.now,nil,0)
 function e:time(dt) self.now+=dt end
 function e:request(kind,p,seq,direction)
  input.OnServerEvent:Fire(p or self.a,kind,{Seq=seq or 1,Direction=direction or V(0,0,-1)})
 end
 function e:tick() return self.service.Tick(self.players,self.now) end
 function e:last(kind)
  for i=#self.logs,1,-1 do if self.logs[i].Kind==kind then return self.logs[i] end end
 end
 function e:count(kind) local n=0;for _,v in ipairs(self.logs) do if v.Kind==kind then n+=1 end end;return n end
 function e:position(r,value) r.Position=value;r.CFrame=CFrame.new(value) end
 return e
end
