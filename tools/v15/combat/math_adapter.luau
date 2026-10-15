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
