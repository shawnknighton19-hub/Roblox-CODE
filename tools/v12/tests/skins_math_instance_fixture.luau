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
