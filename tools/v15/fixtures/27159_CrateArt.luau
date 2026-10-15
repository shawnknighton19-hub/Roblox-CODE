--!nonstrict
-- HAB_CRATE_GUI_4. A crate built for GUI ViewportFrames, not placed in the map.
local A={}
local V,CF=Vector3.new,CFrame.new
local gold=Color3.fromRGB(255,207,108)
local dark=Color3.fromRGB(19,20,35)
local function part(parent,name,cf,size,color,shape)
 local p=Instance.new('Part');p.Name=name;p.CFrame=cf;p.Size=size
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Color=color;p.Material=Enum.Material.SmoothPlastic;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=shape end;p.Parent=parent;return p
end
function A.Mount(view,category,color)
 local world=Instance.new('WorldModel');world.Name='CrateDisplay';world.Parent=view
 local camera=Instance.new('Camera');camera.FieldOfView=34;camera.Parent=view;view.CurrentCamera=camera
 view.Ambient=Color3.fromRGB(185,183,207);view.LightColor=Color3.fromRGB(255,245,215);view.LightDirection=V(-1,-1,-.5)
 local body,lid,locks={},{},{}
 local hinge=CF(0,2.9,-1.8)
 local function add(name,cf,size,c,isLid,shape)
  local p=part(world,name,cf,size,c,shape)
  local list=isLid and lid or body;list[#list+1]={p,isLid and hinge:ToObjectSpace(cf) or cf};return p
 end
 add('Interior bottom',CF(0,.25,0),V(5.6,.3,3.8),dark)
 add('Front panel',CF(0,1.45,1.98),V(5.65,2.6,.3),color:Lerp(dark,.38))
 add('Rear panel',CF(0,1.45,-1.98),V(5.65,2.6,.3),color:Lerp(dark,.52))
 for _,x in ipairs({-2.83,2.83}) do
  add('Side panel',CF(x,1.45,0),V(.32,2.6,3.8),color:Lerp(dark,.53))
  for _,z in ipairs({-1.8,1.8}) do
   add('Corner cap',CF(x,1.5,z),V(.42,2.85,.45),gold)
   for y=.45,2.5,.66 do add('Rivet',CF(x, y,z+(.22*(z>0 and 1 or -1))),V(.14,.14,.14),dark, false,Enum.PartType.Ball) end
  end
 end
 for _,y in ipairs({.2,2.8}) do
  for _,z in ipairs({-2.08,2.08}) do add('Gilt rim',CF(0,y,z),V(6,.2,.22),gold) end
  for _,x in ipairs({-2.9,2.9}) do add('Gilt side rim',CF(x,y,0),V(.2,.2,4.35),gold) end
 end
 for _,x in ipairs({-1.85,1.85}) do
  add('Front clasp band',CF(x,1.45,2.16),V(.34,2.65,.12),gold)
  add('Lid band',CF(x,3.25,0),V(.36,.2,4.3),gold,true)
 end
 -- Fitted stepped cap, with a physical hinge origin.
 add('Lower lid',CF(0,3.05,0),V(6.1,.35,4.45),gold,true)
 add('Inlaid lid',CF(0,3.29,0),V(5.7,.24,4.12),color:Lerp(dark,.15),true)
 add('Lid center',CF(0,3.48,0),V(4.65,.15,3.0),dark,true)
 local seal=add('Seal',CF(0,2.05,2.27),V(.88,1.15,.22),gold)
 locks[#locks+1]=seal
 local jewel=add('Seal jewel',CF(0,2.14,2.43)*CFrame.Angles(0,0,math.pi/4),V(.52,.52,.16),color)
 locks[#locks+1]=jewel
 for _,x in ipairs({-2.5,2.5}) do
  for _,z in ipairs({-1.5,1.5}) do add('Feet',CF(x,-.03,z),V(.72,.35,.74),dark) end
 end
 -- A different emblem on each chest (not a painted-on text label).
 if category=='Aura' then
  for i=0,7 do local a=i*math.pi/4;add('Halo ornament',CF(math.cos(a)*.87,3.75,math.sin(a)*.87),V(.23,.24,.46),gold,true) end
 elseif category=='Trail' then
  for _,x in ipairs({-.7,.7}) do add('Jet nozzle',CF(x,3.83,0)*CFrame.Angles(0,0,math.pi/2),V(.55,.7,.7),color,true,Enum.PartType.Cylinder) end
 elseif category=='BombFX' then
  add('Bomb emblem',CF(0,4,0),V(1.3,1.3,1.3),dark,true,Enum.PartType.Ball)
  add('Fuse',CF(.18,4.79,0)*CFrame.Angles(0,0,-.4),V(.17,.48,.17),gold,true)
 elseif category=='KillFX' then
  for i=0,5 do local a=i*math.pi/3;add('Nova shard',CF(math.cos(a)*.65,3.85,math.sin(a)*.65)*CFrame.Angles(0,-a,0),V(.22,.32,.9),color,true) end
 else
  for i=-1,1 do add('Weave slash',CF(i*.55,3.77,0)*CFrame.Angles(0,.45,0),V(.18,.25,1.9),gold,true) end
 end
 local core=part(world,'Opening light',CF(0,1.8,0),V(.3,.3,.3),color,Enum.PartType.Ball);core.Transparency=1
 local h={World=world,Camera=camera,View=view,Core=core}
 function h:Pose(yaw,opening,shake,rise)
  if not self.World.Parent then return end
  local t=CF(shake or 0,rise or 0,0)*CFrame.Angles(0,yaw or 0,0)
  for _,r in ipairs(body) do r[1].CFrame=t*r[2] end
  for _,r in ipairs(lid) do r[1].CFrame=t*hinge*CFrame.Angles(-math.rad(108)*(opening or 0),0,0)*r[2] end
  for _,p in ipairs(locks) do p.Transparency=math.clamp(opening or 0,0,1) end
  core.Size=V(1,1,1)*(.3+(opening or 0)*1.8)
  core.CFrame=t*CF(0,2+(opening or 0)*3.4,0);core.Transparency=1-(opening or 0)*.55
  camera.CFrame=CFrame.lookAt(V(10,8,15),V(0,1.9,0))
 end
 function h:Destroy() self.World:Destroy();self.Camera:Destroy() end
 h:Pose(0,0,0,0)
 return h
end
return A

