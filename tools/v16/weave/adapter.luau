-- Deterministic math/Instance execution adapter for exporting generator geometry.
-- Does not simulate Roblox rendering, humanoids, collision or networking.
local rawTypeof = typeof
local Vector3, vectorMt = {}, {}
vectorMt.__index = function(t, k)
    if k == "Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z) end
    if k == "Unit" then local n=t.Magnitude; assert(n>0,"zero vector"); return Vector3.new(t.X/n,t.Y/n,t.Z/n) end
    return Vector3[k]
end
function Vector3.new(x,y,z) return setmetatable({_kind="Vector3",X=x or 0,Y=y or 0,Z=z or 0},vectorMt) end
vectorMt.__add=function(a,b) return Vector3.new(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vectorMt.__sub=function(a,b) return Vector3.new(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vectorMt.__unm=function(a) return Vector3.new(-a.X,-a.Y,-a.Z) end
vectorMt.__mul=function(a,b)
    if type(a)=="number" then return Vector3.new(a*b.X,a*b.Y,a*b.Z) end
    if type(b)=="number" then return Vector3.new(a.X*b,a.Y*b,a.Z*b) end
    return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z)
end
vectorMt.__div=function(a,b) return Vector3.new(a.X/b,a.Y/b,a.Z/b) end
vectorMt.__eq=function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
function Vector3:Dot(b) return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
function Vector3:Cross(b) return Vector3.new(self.Y*b.Z-self.Z*b.Y,self.Z*b.X-self.X*b.Z,self.X*b.Y-self.Y*b.X) end
function Vector3:Lerp(b,t) return self+(b-self)*t end
Vector3.zero=Vector3.new();Vector3.one=Vector3.new(1,1,1)
Vector3.xAxis=Vector3.new(1,0,0);Vector3.yAxis=Vector3.new(0,1,0);Vector3.zAxis=Vector3.new(0,0,1)
local Vector2={new=function(x,y) return {_kind="Vector2",X=x or 0,Y=y or 0} end}
local Color3, colorMt={},{}
colorMt.__index=Color3
function Color3.new(r,g,b) return setmetatable({_kind="Color3",R=r,G=g,B=b},colorMt) end
function Color3.fromRGB(r,g,b) return Color3.new(r/255,g/255,b/255) end
function Color3:Lerp(b,t) return Color3.new(self.R+(b.R-self.R)*t,self.G+(b.G-self.G)*t,self.B+(b.B-self.B)*t) end
local UDim={new=function(s,o) return {_kind="UDim",Scale=s or 0,Offset=o or 0} end}
local UDim2={}
function UDim2.new(xs,xo,ys,yo) return {_kind="UDim2",X=UDim.new(xs,xo),Y=UDim.new(ys,yo)} end
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local CFrame, frameMt={},{}
local function frame(p,m) return setmetatable({_kind="CFrame",p=p,m=m or {1,0,0,0,1,0,0,0,1}},frameMt) end
local function rotate(m,v) return Vector3.new(m[1]*v.X+m[2]*v.Y+m[3]*v.Z,m[4]*v.X+m[5]*v.Y+m[6]*v.Z,m[7]*v.X+m[8]*v.Y+m[9]*v.Z) end
frameMt.__index=function(t,k)
    if k=="Position" or k=="p" then return rawget(t,"p") end
    if k=="Rotation" then return frame(Vector3.zero,table.clone(t.m)) end
    if k=="X" or k=="Y" or k=="Z" then return t.p[k] end
    if k=="RightVector" then return Vector3.new(t.m[1],t.m[4],t.m[7]) end
    if k=="UpVector" then return Vector3.new(t.m[2],t.m[5],t.m[8]) end
    if k=="LookVector" then return Vector3.new(-t.m[3],-t.m[6],-t.m[9]) end
    return CFrame[k]
end
frameMt.__mul=function(a,b)
    if b._kind=="Vector3" then return a.p+rotate(a.m,b) end
    assert(b._kind=="CFrame")
    local m={}
    for r=0,2 do for c=0,2 do m[r*3+c+1]=a.m[r*3+1]*b.m[c+1]+a.m[r*3+2]*b.m[c+4]+a.m[r*3+3]*b.m[c+7] end end
    return frame(a.p+rotate(a.m,b.p),m)
end
frameMt.__add=function(a,b) return frame(a.p+b,table.clone(a.m)) end
frameMt.__sub=function(a,b) return frame(a.p-b,table.clone(a.m)) end
function CFrame.new(...)
    local a={...}
    if #a==0 then return frame(Vector3.zero) end
    if type(a[1])=="table" then
        if #a==2 then return CFrame.lookAt(a[1],a[2]) end
        return frame(a[1])
    end
    local m
    if #a==12 then m={table.unpack(a,4,12)} end
    return frame(Vector3.new(a[1],a[2],a[3]),m)
end
function CFrame.Angles(x,y,z)
    local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    return frame(Vector3.zero,{1,0,0,0,cx,-sx,0,sx,cx})*frame(Vector3.zero,{cy,0,sy,0,1,0,-sy,0,cy})*frame(Vector3.zero,{cz,-sz,0,sz,cz,0,0,0,1})
end
CFrame.fromEulerAnglesXYZ=CFrame.Angles
function CFrame.lookAt(pos,target,up)
    local back=(pos-target).Unit
    local right=(up or Vector3.yAxis):Cross(back).Unit
    local upwards=back:Cross(right)
    return frame(pos,{right.X,upwards.X,back.X,right.Y,upwards.Y,back.Y,right.Z,upwards.Z,back.Z})
end
function CFrame.fromMatrix(pos,right,up,back)
    back=back or right:Cross(up)
    return frame(pos,{right.X,up.X,back.X,right.Y,up.Y,back.Y,right.Z,up.Z,back.Z})
end
function CFrame:Inverse()
    local a=self.m;local m={a[1],a[4],a[7],a[2],a[5],a[8],a[3],a[6],a[9]}
    return frame(rotate(m,-self.p),m)
end
function CFrame:ToObjectSpace(b) return self:Inverse()*b end
function CFrame:ToWorldSpace(b) return self*b end
function CFrame:PointToObjectSpace(b) return self:Inverse()*b end
function CFrame:PointToWorldSpace(b) return self*b end
function CFrame:VectorToWorldSpace(b) return rotate(self.m,b) end
function CFrame:GetComponents() return self.p.X,self.p.Y,self.p.Z,table.unpack(self.m) end
CFrame.identity=CFrame.new()
local Enum=setmetatable({}, {__index=function(t,k)
    local group=setmetatable({}, {__index=function(g,n)
        local v={_kind="EnumItem",EnumType=k,Name=n};rawset(g,n,v);return v
    end});rawset(t,k,group);return group
end})
local function typeof(v) if type(v)=="table" and rawget(v,"_kind") then return v._kind end;return rawTypeof(v) end
local methods,mt,Instance={},{},{}
local nextID=0
mt.__index=function(t,k)
    if methods[k] then return methods[k] end
    if k=="Position" and t._props.CFrame then return t._props.CFrame.Position end
    if t._props[k]~=nil then return t._props[k] end
    for _,c in ipairs(t._children) do if c.Name==k then return c end end
    return nil
end
mt.__newindex=function(t,k,v)
    if k=="Parent" then
        local old=t._props.Parent
        if old then local i=table.find(old._children,t); if i then table.remove(old._children,i) end end
        if v then table.insert(v._children,t) end
    elseif k=="Position" and typeof(v)=="Vector3" then
        t._props.CFrame=CFrame.new(v)*(t._props.CFrame or CFrame.identity).Rotation;return
    end
    t._props[k]=v
end
function Instance.new(class,parent)
    nextID+=1
    local obj=setmetatable({_kind="Instance",_id=nextID,ClassName=class,_props={Name=class},_attrs={},_children={}},mt)
    if class=="Part" or class=="WedgePart" or class=="SpawnLocation" then
        obj.CFrame=CFrame.new();obj.Size=Vector3.new(4,1.2,2);obj.CanCollide=true;obj.CanQuery=true;obj.Transparency=0
    end
    if parent then obj.Parent=parent end
    return obj
end
function methods:IsA(c)
    return c==self.ClassName or c=="Instance" or (c=="BasePart" and (self.ClassName=="Part" or self.ClassName=="WedgePart" or self.ClassName=="SpawnLocation"))
end
function methods:GetChildren() return table.clone(self._children) end
function methods:GetDescendants()
    local out={};for _,c in ipairs(self._children) do table.insert(out,c); for _,d in ipairs(c:GetDescendants()) do table.insert(out,d) end end;return out
end
function methods:FindFirstChild(n,recurse)
    for _,c in ipairs(self._children) do if c.Name==n then return c end end
    if recurse then for _,c in ipairs(self._children) do local found=c:FindFirstChild(n,true);if found then return found end end end
    return nil
end
methods.WaitForChild=methods.FindFirstChild
function methods:FindFirstChildOfClass(c) for _,child in ipairs(self._children) do if child:IsA(c) then return child end end end
function methods:GetFullName() return (self.Parent and self.Parent:GetFullName().."." or "")..self.Name end
function methods:SetAttribute(k,v) self._attrs[k]=v end
function methods:GetAttribute(k) return self._attrs[k] end
function methods:GetAttributes() return table.clone(self._attrs) end
function methods:Destroy() self.Parent=nil;for _,c in ipairs(self:GetChildren()) do c:Destroy() end end
function methods:ClearAllChildren() for _,c in ipairs(self:GetChildren()) do c:Destroy() end end
function methods:GetPivot() return self.PrimaryPart and self.PrimaryPart.CFrame or self._props.WorldPivot or CFrame.new() end
function methods:PivotTo(cf)
    local delta=cf*self:GetPivot():Inverse()
    for _,v in ipairs(self:GetDescendants()) do if v:IsA("BasePart") then v.CFrame=delta*v.CFrame end end
    self.WorldPivot=cf
end
function methods:Clone()
    local mapping={}
    local function clone(original)
        local copy=Instance.new(original.ClassName);mapping[original]=copy
        copy._attrs=table.clone(original._attrs)
        for k,v in pairs(original._props) do if k~="Parent" then copy[k]=v end end
        for _,c in ipairs(original._children) do clone(c).Parent=copy end
        return copy
    end
    local out=clone(self)
    for old,copy in pairs(mapping) do for k,v in pairs(old._props) do if typeof(v)=="Instance" and k~="Parent" then copy[k]=mapping[v] or v end end end
    return out
end
local workspace=Instance.new("Workspace"); workspace.Name="Workspace"
local services={Workspace=workspace,ServerStorage=Instance.new("ServerStorage"),ReplicatedStorage=Instance.new("ReplicatedStorage"),Lighting=Instance.new("Lighting")}
local game={GetService=function(_,name) assert(services[name],"Unknown service "..name);return services[name] end}
local function json(value)
    local kind=type(value)
    if kind=="nil" then return "null" end
    if kind=="boolean" then return value and "true" or "false" end
    if kind=="number" then assert(value==value and math.abs(value)<math.huge,"nonfinite number");return string.format("%.17g",value) end
    if kind=="string" then
        return '"'..value:gsub('[%z\1-\31\\"]',function(c)
            if c=='"' then return '\\"' elseif c=='\\' then return '\\\\' else return string.format("\\u%04x",string.byte(c)) end
        end)..'"'
    end
    assert(kind=="table",kind)
    if rawget(value,"_kind")=="Instance" then return '{"_kind":"InstanceRef","id":'..value._id..'}' end
    local out={}
    if #value>0 then
        for i,v in ipairs(value) do out[i]=json(v) end
        return "["..table.concat(out,",").."]"
    end
    local keys={}; for key in pairs(value) do table.insert(keys,key) end;table.sort(keys)
    for _,key in ipairs(keys) do table.insert(out,json(key)..":"..json(value[key])) end
    return "{"..table.concat(out,",").."}"
end
local function exportNode(node)
    local props={};for k,v in pairs(node._props) do if k~="Parent" then props[k]=v end end
    local children={};for _,child in ipairs(node._children) do table.insert(children,exportNode(child)) end
    return {id=node._id,class=node.ClassName,props=props,attributes=node._attrs,children=children}
end

-- Deterministic lifecycle harness. Roblox Animator, physics and networking are not simulated.
local clock=100
local os={clock=function() return clock end}
local task={spawn=function(callback) callback() end}
local allSignals={}
local function signal()
	local s={list={}}
	function s:Connect(fn)
		local c={Connected=true,fn=fn}
		function c:Disconnect() self.Connected=false end
		table.insert(self.list,c)
		return c
	end
	function s:Fire(...)
		for _,c in ipairs(table.clone(self.list)) do if c.Connected then c.fn(...) end end
	end
	table.insert(allSignals,s)
	return s
end
local originalAttribute=methods.SetAttribute
function methods:GetAttributeChangedSignal(n)
	self._props.attributeSignals=self._props.attributeSignals or {}
	self._props.attributeSignals[n]=self._props.attributeSignals[n] or signal()
	return self._props.attributeSignals[n]
end
function methods:SetAttribute(n,v)
	local old=self:GetAttribute(n)
	originalAttribute(self,n,v)
	if old~=v and self._props.attributeSignals and self._props.attributeSignals[n] then
		self._props.attributeSignals[n]:Fire()
	end
end
function methods:GetState() return self.State or Enum.HumanoidStateType.Running end
function methods:GetServerTimeNow() return clock end
local ColorSequence={new=function(...) return {...} end}
local NumberSequence={new=function(...) return {...} end}
local NumberSequenceKeypoint={new=function(...) return {...} end}
local function quaternion(m)
	local tr=m[1]+m[5]+m[9]
	if tr>0 then local s=math.sqrt(tr+1)*2;return {(m[8]-m[6])/s,(m[3]-m[7])/s,(m[4]-m[2])/s,s/4} end
	if m[1]>m[5] and m[1]>m[9] then
		local s=math.sqrt(1+m[1]-m[5]-m[9])*2;return {s/4,(m[2]+m[4])/s,(m[3]+m[7])/s,(m[8]-m[6])/s}
	elseif m[5]>m[9] then
		local s=math.sqrt(1+m[5]-m[1]-m[9])*2;return {(m[2]+m[4])/s,s/4,(m[6]+m[8])/s,(m[3]-m[7])/s}
	else
		local s=math.sqrt(1+m[9]-m[1]-m[5])*2;return {(m[3]+m[7])/s,(m[6]+m[8])/s,s/4,(m[4]-m[2])/s}
	end
end
function CFrame:Lerp(b,t)
	local q,r=quaternion(self.m),quaternion(b.m)
	local dot=0
	for i=1,4 do dot+=q[i]*r[i] end
	if dot<0 then for i=1,4 do r[i]=-r[i] end;dot=-dot end
	local aWeight,bWeight=1-t,t
	if dot<.9995 then
		local theta=math.acos(math.clamp(dot,-1,1))
		aWeight=math.sin((1-t)*theta)/math.sin(theta)
		bWeight=math.sin(t*theta)/math.sin(theta)
	end
	local norm=0
	for i=1,4 do q[i]=q[i]*aWeight+r[i]*bWeight;norm+=q[i]^2 end
	norm=math.sqrt(norm)
	for i=1,4 do q[i]/=norm end
	local x,y,z,w=table.unpack(q)
	return frame(self.p:Lerp(b.p,t),{
		1-2*y*y-2*z*z,2*x*y-2*z*w,2*x*z+2*y*w,
		2*x*y+2*z*w,1-2*x*x-2*z*z,2*y*z-2*x*w,
		2*x*z-2*y*w,2*y*z+2*x*w,1-2*x*x-2*y*y,
	})
end
local function nearCF(a,b,epsilon)
	if (a.Position-b.Position).Magnitude>(epsilon or 1e-8) then return false end
	for i=1,9 do if math.abs(a.m[i]-b.m[i])>(epsilon or 1e-8) then return false end end
	return true
end
local playerService={PlayerAdded=signal(),PlayerRemoving=signal(),members={}}
function playerService:GetPlayers() return table.clone(self.members) end
services.Players=playerService
services.RunService={PreAnimation=signal(),PreSimulation=signal()}
local shared=Instance.new("Folder",services.ReplicatedStorage);shared.Name="Shared"
local net=Instance.new("Folder",shared);net.Name="Net"
local event=Instance.new("RemoteEvent",net);event.Name="DodgeIFrameRequest";event.OnClientEvent=signal()
local script=Instance.new("LocalScript");script.Destroying=signal()
local function makePlayer(name,r15)
	local p=Instance.new("Player");p.Name=name;p.CharacterAdded=signal();p.CharacterRemoving=signal()
	local c=Instance.new("Model",workspace);c.Name=name;c.DescendantAdded=signal();p.Character=c
	local h=Instance.new("Humanoid",c);h.Health=100;h.RigType=r15 and Enum.HumanoidRigType.R15 or Enum.HumanoidRigType.R6;h.Died=signal()
	local root=Instance.new("Part",c);root.Name="HumanoidRootPart";root.Anchored=false;root.CFrame=CFrame.new(0,3,0)
	local parts={HumanoidRootPart=root}
	local function part(n,size)
		local o=Instance.new("Part",c);o.Name=n;o.Size=size;parts[n]=o;return o
	end
	local function joint(n,from,to,c0,c1)
		local j=Instance.new("Motor6D",parts[from]);j.Name=n;j.Part0=parts[from];j.Part1=parts[to];j.C0=c0;j.C1=c1
		j.Transform=CFrame.new();j.Enabled=true;return j
	end
	if not r15 then
		part("Torso",Vector3.new(2,2,1));part("Head",Vector3.new(2,1,1))
		for _,n in ipairs({"Left Arm","Right Arm","Left Leg","Right Leg"}) do part(n,Vector3.new(1,2,1)) end
		local r=CFrame.Angles(-math.pi/2,0,math.pi)
		joint("RootJoint","HumanoidRootPart","Torso",r,r)
		joint("Neck","Torso","Head",CFrame.new(0,1,0)*r,CFrame.new(0,-.5,0)*r)
		for _,sign in ipairs({-1,1}) do
			local label=sign<0 and "Left" or "Right"
			local axis=CFrame.Angles(0,sign*math.pi/2,0)
			joint(label.." Shoulder","Torso",label.." Arm",CFrame.new(sign,.5,0)*axis,CFrame.new(-sign*.5,.5,0)*axis)
			joint(label.." Hip","Torso",label.." Leg",CFrame.new(sign,-1,0)*axis,CFrame.new(sign*.5,1,0)*axis)
		end
	else
		for _,n in ipairs({"LowerTorso","UpperTorso","Head","LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot","LeftHand","RightHand"}) do
			part(n,Vector3.new(1,1,1))
			joint(n.."Joint","HumanoidRootPart",n,CFrame.identity,CFrame.identity)
		end
	end
	table.insert(playerService.members,p)
	return p
end
local owner=makePlayer("Owner",false)
local observer=makePlayer("Observer",false)
local r15=makePlayer("R15",true)
playerService.LocalPlayer=owner
workspace:SetAttribute("HussDodgeV5",true)
local testExports

local NumberRange={new=function(a,b) return {Min=a,Max=b or a} end}
local RaycastParams={new=function() return {} end}
services.RunService.Heartbeat=signal()
workspace.CurrentCamera={CFrame=CFrame.new(0,8,8)}
local groundEnabled,groundSlope=true,1
local casts,emits=0,0
local floor=Instance.new('Part',workspace);floor.AssemblyLinearVelocity=Vector3.zero
function methods:GetVelocityAtPosition() return self.AssemblyLinearVelocity end
function methods:Raycast(origin,direction,params)
 casts+=1
 assert(params.RespectCanCollide==true and params.FilterType==Enum.RaycastFilterType.Exclude and params.FilterDescendantsInstances[1]:IsA('Model'),'self-excluding ground ray')
 if not groundEnabled or origin.Y>-direction.Y then return nil end
 return {Instance=floor,Position=Vector3.new(origin.X,0,origin.Z),Normal=Vector3.new(0,groundSlope,0),Distance=origin.Y}
end
function methods:Clear() self.ClearCount=(self.ClearCount or 0)+1 end
function methods:Emit(n) assert(n<=6 and n>0);self.EmitCount=(self.EmitCount or 0)+n;emits+=n end
local function initialize(p,speed)
 local c=p.Character;c:SetAttribute('MovementState',(speed or 0)>27 and 'Sprint' or 'Idle');local h=c.Humanoid;local r=c.HumanoidRootPart
 h.HipHeight=h.RigType==Enum.HumanoidRigType.R15 and 2 or 0;h.FloorMaterial=Enum.Material.Grass
 r.Size=Vector3.new(2,2,1);r.AssemblyLinearVelocity=Vector3.new(speed or 0,0,0)
end
for _,p in ipairs(playerService:GetPlayers()) do initialize(p,0) end
local delayTasks,pendingTasks=false,{}
task.spawn=function(callback) if delayTasks then table.insert(pendingTasks,callback) else callback() end end
local function flushTasks() local tasks=pendingTasks;pendingTasks={};for _,fn in ipairs(tasks) do fn() end end

function methods:IsDescendantOf(parent)
 local current=self.Parent
 while current do if current==parent then return true end;current=current.Parent end
 return false
end
local originalNew=Instance.new
local function events(object)
 for _,name in ipairs({'ChildAdded','ChildRemoved','DescendantAdded','DescendantRemoving','AncestryChanged','Destroying'}) do
  object[name]=object[name] or signal()
 end
end
Instance.new=function(class,parent) local object=originalNew(class,parent);events(object);return object end
events(workspace)
for _,object in ipairs(workspace:GetDescendants()) do events(object) end
for _,player in ipairs(playerService:GetPlayers()) do events(player) end
local function newCharacter(name,r15)
 local p=makePlayer(name,r15)
 initialize(p,32)
 events(p)
 for _,object in ipairs(p.Character:GetDescendants()) do events(object) end
 events(p.Character)
 return p
end
