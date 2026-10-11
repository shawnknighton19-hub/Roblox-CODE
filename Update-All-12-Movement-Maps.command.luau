-- HUSS A BOMB / TWELVE MOVEMENT MAPS
-- Paste the complete script into Studio's Command Bar with Play stopped.
assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning(), "Stop Play first.")
local ss = game:GetService("ServerStorage")
local rs = game:GetService("ReplicatedStorage")
local starter = game:GetService("StarterPlayer").StarterPlayerScripts
local vote = starter:FindFirstChild("BombTagVoteClientV6")
local controllers = starter:FindFirstChild("Controllers")
local hud = controllers and controllers:FindFirstChild("HudController")
local legacy = game:GetService("ServerScriptService"):FindFirstChild("SunsetDocksTerrainV9")
local anchor, maps = workspace:FindFirstChild("ActiveArenaAnchor"), workspace:FindFirstChild("Maps")
local original = ss:FindFirstChild("MapLibrary")
assert(vote and vote:IsA("LocalScript") and anchor and anchor:IsA("BasePart") and maps and original,
  "Open your Huss A Bomb game first. Nothing was changed.")
local config = require(rs.Shared.Config.GameConfig)
assert(type(config.MapName) == "string" and config.MapName ~= "", "GameConfig.MapName is missing.")
local Builder = (function()
--!nonstrict
-- Original Bomb Tag environments. All traversable elevations have ramp access.
local MapBuilder={}
local V,C,R,M=Vector3.new,CFrame.new,Color3.fromRGB,Enum.Material
local dark,ivory,wood=R(38,46,49),R(224,219,199),R(118,79,51)
local function group(p,n)
 local o=Instance.new('Model');o.Name=n;o.Parent=p;return o
end
local function part(p,n,x,y,z,w,h,d,color,material,collide,rotation,class)
 local o=Instance.new(class or 'Part');o.Name=n;o.Size=V(w,h,d)
 o.CFrame=C(x,y,z)*(rotation or CFrame.identity);o.Color=color;o.Material=material or M.SmoothPlastic
 o.Anchored=true;o.CanCollide=collide~=false;o.CanTouch=false;o.CanQuery=o.CanCollide
 o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth;o.Parent=p;return o
end
local function detail(p,n,x,y,z,w,h,d,color,material,rotation)
 return part(p,n,x,y,z,w,h,d,color,material,false,rotation)
end
local function beam(p,n,a,b,w,h,color,material,collide)
 local q=(a+b)/2
 return part(p,n,q.X,q.Y,q.Z,w,h,(b-a).Magnitude,color,material,collide,CFrame.lookAt(a,b).Rotation)
end
local function cylinder(p,n,x,y,z,d,h,color,material,collide)
 local o=part(p,n,x,y,z,h,d,d,color,material,collide,CFrame.Angles(0,0,math.pi/2));o.Shape=Enum.PartType.Cylinder;return o
end
local function orb(p,n,x,y,z,s,color)
 local o=detail(p,n,x,y,z,s,s,s,color,M.Grass);o.Shape=Enum.PartType.Ball;return o
end
local function sign(p,title,x,y,z,w,color)
 local b=detail(p,'Enamel sign',x,y,z,w,2.7,.3,dark,M.Metal)
 local gui=Instance.new('SurfaceGui');gui.Face=Enum.NormalId.Back;gui.CanvasSize=Vector2.new(720,100);gui.LightInfluence=.2;gui.Parent=b
 local t=Instance.new('TextLabel');t.BackgroundTransparency=1;t.Size=UDim2.fromScale(1,1);t.Font=Enum.Font.GothamBold;t.TextSize=47;t.TextColor3=color;t.Text=title;t.Parent=gui
end
local pavingLayer=0
local function path(p,x,z,w,d,color,y)
 pavingLayer+=1
 y=(y or 0)+pavingLayer*.003
 detail(p,'Inlaid paving',x,y+.035,z,w,.055,d,color,M.Concrete)
 for a=-w/2+8,w/2-1,8 do detail(p,'Stone joint',x+a,y+.069,z,.065,.018,d,color:Lerp(dark,.14),M.Concrete) end
 for b=-d/2+8,d/2-1,8 do detail(p,'Stone joint',x,y+.069,z+b,w,.018,.065,color:Lerp(dark,.14),M.Concrete) end
end
local function rail(p,a,b,color)
 beam(p,'Smooth guard collision',a+V(0,1.7,0),b+V(0,1.7,0),.55,3.4,color,M.Metal,true).Transparency=1
 beam(p,'Handrail',a+V(0,3.4,0),b+V(0,3.4,0),.32,.35,color,M.Metal,false)
 beam(p,'Lower rail',a+V(0,1,0),b+V(0,1,0),.2,.2,color,M.Metal,false)
 local n=math.ceil((b-a).Magnitude/7)
 for i=0,n do local q=a:Lerp(b,i/n);detail(p,'Rail upright',q.X,q.Y+1.7,q.Z,.3,3.4,.3,color,M.Metal) end
end
local function deck(p,e,n,x,z,w,d,y,color,hollow)
 local h=hollow and 1 or y
 local o=part(p,n,x,y-h/2,z,w,h,d,color,M.Concrete,true)
 detail(p,'Deck fascia',x,y-.35,z+d/2+.05,w,.65,.12,ivory,M.Concrete)
 path(p,x,z,w-.6,d-.6,color:Lerp(ivory,.06),y)
 table.insert(e.Geometry.Decks,{Name=n,X=x,Z=z,Width=w,Depth=d,Y=y,Clearance=hollow and y-1 or 0,SolidBase=not hollow})
 return o
end
local function ramp(p,e,n,x1,z1,x2,z2,rise,width,color)
 local a,b=V(x1,0,z1),V(x2,rise,z2);local delta=V(x2-x1,0,z2-z1);local run=delta.Magnitude
 assert(width>=18 and math.deg(math.atan(rise/run))<=16,'Unsafe ramp '..n)
 local q=(a+b)/2;local turn=CFrame.lookAt(q,q-delta).Rotation
 local o=part(p,n,q.X,q.Y,q.Z,width,rise,run,color,M.Concrete,true,turn,'WedgePart')
 o:SetAttribute('NoJumpRoute',true)
 local side=V(delta.Z,0,-delta.X).Unit*(width/2-.25)
 rail(p,a+side,b+side,dark);rail(p,a-side,b-side,dark)
 for i=1,math.floor(run/5)-1 do local q2=a:Lerp(b,i*5/run)
  detail(p,'Flush ramp grip',q2.X,q2.Y+.025,q2.Z,width-1,.025,.16,color:Lerp(ivory,.32),M.Concrete,turn*CFrame.Angles(-math.atan(rise/run),0,0))
 end
 table.insert(e.Geometry.Ramps,{Name=n,X1=x1,Z1=z1,X2=x2,Z2=z2,BaseY=0,Rise=rise,Run=run,Width=width,SlopeDegrees=math.deg(math.atan(rise/run))})
 return o
end
local function arch(p,x,z,w,h,d,color)
 for _,s in ipairs({-1,1}) do
  part(p,'Arch pier',x+s*(w/2-1),h/2,z,2,h,d,color,M.Limestone,true)
  detail(p,'Pier capital',x+s*(w/2-1),h-.2,z,3,.6,d+.6,ivory,M.Limestone)
 end
 for i=0,10 do local t=math.pi*i/10
  detail(p,'Voussoir',x+math.cos(t)*(w/2-1),h+math.sin(t)*w*.22,z,w*.16,1.6,d,color:Lerp(ivory,(i%2)*.08),M.Limestone,CFrame.Angles(0,0,t-math.pi/2))
 end
end
local function building(p,n,x,z,w,d,h,color,accent,style)
 local g=group(p,n);local timber=style=='timber';local tech=style=='tech' or style=='industrial'
 local mat=timber and M.WoodPlanks or tech and M.Metal or M.Brick
 part(g,'Smooth building volume',x,h/2,z,w,h,d,color,mat,true)
 for _,y in ipairs({.6,h*.52,h-.4}) do detail(g,'Cornice',x,y,z,w+.8,.65,d+.8,ivory,M.Concrete) end
 for _,sx in ipairs({-1,1}) do
  for _,sz in ipairs({-1,1}) do detail(g,'Corner pilaster',x+sx*(w/2-.45),h/2,z+sz*(d/2+.08),.8,h,.45,color:Lerp(ivory,.38),mat) end
 end
 if style=='stone' or style=='sand' then
  for xx=-w/2+2,w/2-1,4 do detail(g,'Dentil stone',x+xx,h-.9,z+d/2+.55,1.1,.8,.8,color:Lerp(ivory,.4),M.Limestone) end
 elseif tech then
  for yy=2,h-2,4 do for _,sx in ipairs({-1,1}) do detail(g,'Service riser bracket',x+sx*(w/2-1),yy,z+d/2+.5,.6,.35,.65,dark,M.Metal) end end
 end
 local cols=math.max(2,math.floor(w/7));local rows=math.max(1,math.floor((h-3)/7))
 for row=1,rows do for col=1,cols do
  local wx=x-w/2+w*(col-.5)/cols;local wy=3+(row-.4)*(h-4)/rows
  for _,s in ipairs({-1,1}) do
   local wz=z+s*(d/2+.15);local winW=math.min(4.3,w/cols-1.3)
   detail(g,'Recessed window',wx,wy,wz,winW+1,4.6,.25,dark,M.Metal)
   detail(g,'Glazing',wx,wy,wz+s*.17,winW,3.8,.12,accent:Lerp(dark,.24),M.Glass)
   detail(g,'Mullion',wx,wy,wz+s*.26,.16,4,.12,ivory,M.Metal)
   detail(g,'Transom',wx,wy,wz+s*.26,winW,.18,.12,ivory,M.Metal)
   detail(g,'Projecting sill',wx,wy-2.1,wz,winW+1.1,.35,.9,ivory,M.Concrete)
   if timber or style=='sand' then for _,a in ipairs({-1,1}) do
    detail(g,'Window shutter',wx+a*(winW/2+.7),wy,wz,.8,4,.4,color:Lerp(dark,.25),M.WoodPlanks)
   end end
  end
 end end
 if timber or style=='stone' then
  for _,s in ipairs({-1,1}) do detail(g,'Pitched roof',x,h+2.2,z+s*d*.25,w+3,.7,d*.56,R(81,89,88),M.Slate,CFrame.Angles(s*math.rad(24),0,0)) end
  detail(g,'Roof ridge',x,h+4.5,z,w+3,.6,.65,ivory,M.Concrete)
  for i=-w/2+3,w/2-1,6 do detail(g,'Exposed timber',x+i,h/2,z+d/2+.4,.35,h,.4,wood,M.Wood) end
  detail(g,'Chimney',x+w*.28,h+5,z-d*.2,3,7,3,color,M.Brick)
 else
  detail(g,'Roof coping',x,h+.3,z,w+1.6,.6,d+1.6,color:Lerp(ivory,.25),M.Concrete)
  for _,s in ipairs({-1,1}) do detail(g,'Roof parapet',x+s*(w/2-.3),h+1.5,z,.7,2.4,d,color,M.Concrete) end
  detail(g,'Ventilation unit',x-w*.22,h+1.8,z,5,2.3,4,dark,M.Metal)
  for i=-2,2 do detail(g,'Vent grille',x-w*.22+i*.7,h+3,z,.2,.1,3,ivory,M.Metal) end
 end
 detail(g,'Door frame',x,3.2,z+d/2+.3,5,6.4,.4,ivory,M.Concrete)
 detail(g,'Inset closed door',x,3,z+d/2+.55,4.2,5.8,.15,dark,M.WoodPlanks)
 detail(g,'Brass handle',x+1.1,3,z+d/2+.7,.15,.8,.15,accent,M.Metal)
 if style=='city' or style=='sand' then
  detail(g,'Shop awning',x,7,z+d/2+2,w*.8,.3,4,accent,M.Fabric,CFrame.Angles(math.rad(8),0,0))
  for i=1,math.floor(w/3) do detail(g,'Awning stripe',x-w*.4+i*2.5,7.2,z+d/2+2,.7,.07,4,ivory,M.Fabric) end
 end
 sign(g,n:upper(),x,h-1.6,z+d/2+.5,math.min(w-2,24),accent)
 return g
end
local function bed(p,x,z,w,d,color)
 part(p,'Planter curb',x,.8,z,w,1.6,d,R(122,124,103),M.Slate,true)
 detail(p,'Garden soil',x,1.65,z,w-.8,.12,d-.8,R(77,80,51),M.Ground)
 for i=1,math.ceil(w*d/10) do
  local a=x-w/2+1+(i*3.7)%(w-2);local b=z-d/2+1+(i*5.9)%(d-2)
  detail(p,'Leaf sprig',a,2,b,.2,.8,.2,R(66,110,66),M.Grass)
  orb(p,'Blossom',a,2.6,b,.8,color:Lerp(ivory,(i%3)*.15))
 end
end
local function tree(p,x,z,s,snow)
 cylinder(p,'Root planter',x,.45,z,6*s,.9,R(119,125,96),M.Slate,true)
 detail(p,'Trunk',x,5*s,z,1.6*s,10*s,1.6*s,wood,M.Wood)
 if snow then
  for i=0,3 do local w=(13-i*2.8)*s
   detail(p,'Pine boughs',x,(7+i*3)*s,z,w,2.7*s,w,R(49,87+i*6,75),M.Grass,CFrame.Angles(0,i*.7,0))
   detail(p,'Snow cap',x,(8.5+i*3)*s,z,w*.94,.6*s,w*.94,R(229,237,232),M.Snow,CFrame.Angles(0,i*.7,0))
  end
 else
  for i=0,5 do local a=i*2.4;local q=orb(p,'Tree crown',x+math.cos(a)*3*s,(11+i%3*2)*s,z+math.sin(a)*3*s,9*s,R(80+i*4,124+i*5,67+i*3));q.Size=V(9,6,8)*s end
 end
end
local function rock(p,x,z,s,color)
 part(p,'Smooth rock collision',x,4*s,z,8*s,8*s,8*s,color,M.Rock,true).Transparency=1
 for i=0,4 do
  detail(p,'Faceted outcrop',x+math.cos(i*2.4)*2*s,(3+i*.6)*s,z+math.sin(i*2.4)*2*s,(6+i%2)*s,(7+i)*s,6*s,color:Lerp(ivory,(i%3)*.06),M.Rock,CFrame.Angles(.12*i,i*.9,.1*i))
 end
end
local function stall(p,x,z,w,color)
 local g=group(p,'Market stall')
 part(g,'Counter collision',x,1.8,z,w,3.6,5,wood,M.WoodPlanks,true)
 for _,s in ipairs({-1,1}) do detail(g,'Canopy post',x+s*(w/2-.5),5,z, .4,10,.4,dark,M.Wood) end
 for i=0,math.ceil(w/2)-1 do detail(g,'Striped awning',x-w/2+1+i*2,9.5,z,2,.25,9,i%2==0 and color or ivory,M.Fabric,CFrame.Angles(.09,0,0)) end
 for i=1,math.floor(w/3) do
  detail(g,'Produce box',x-w/2+i*3,3.8,z,2.5,.5,3,ivory,M.WoodPlanks)
  for j=-1,1 do orb(g,'Fresh produce',x-w/2+i*3,4.5,z+j*.7,.8,({R(213,102,73),R(221,176,75),R(112,159,79)})[i%3+1]) end
 end
end
local function crate(p,x,z,w,color)
 part(p,'Cargo crate',x,w*.4,z,w,w*.8,w,color or wood,M.WoodPlanks,true)
 for _,s in ipairs({-1,1}) do
  detail(p,'Cargo binding',x+s*w*.29,w*.4,z,.3,w*.8+.1,w+.1,dark,M.Metal)
  beam(p,'Crate diagonal',V(x-w/2,w*.08,z+s*(w/2+.07)),V(x+w/2,w*.72,z+s*(w/2+.07)),.45,.25,ivory,M.Wood,false)
 end
end
local function lamp(p,x,z,color)
 detail(p,'Lamp post',x,6,z,.4,12,.4,dark,M.Metal)
 detail(p,'Lamp bracket',x+.8,11.6,z,2,.25,.25,dark,M.Metal)
 detail(p,'Lantern case',x+1.4,11,z,1.9,2,1.9,dark,M.Metal)
 detail(p,'Lantern glass',x+1.4,11,z,1.5,1.5,1.5,color,M.Neon)
 detail(p,'Lantern cap',x+1.4,12.2,z,2.3,.3,2.3,dark,M.Metal)
end
local function pool(p,x,z,w,d,color)
 detail(p,'Reflective water',x,.1,z,w,.13,d,color,M.Glass).Transparency=.2
 for _,s in ipairs({-1,1}) do
  detail(p,'Flush pool edging',x+s*w/2,.11,z,.7,.15,d+.7,ivory,M.Concrete)
  detail(p,'Flush pool edging',x,.11,z+s*d/2,w+.7,.15,.7,ivory,M.Concrete)
 end
 for i=-w/2+3,w/2-2,6 do detail(p,'Water shimmer',x+i,.18,z,1,.012,d*.7,color:Lerp(ivory,.3),M.Glass) end
end
local function inside(poly,x,z)
 local yes=false;local j=#poly
 for i,a in ipairs(poly) do local b=poly[j]
  if (a[2]>z)~=(b[2]>z) and x<(b[1]-a[1])*(z-a[2])/(b[2]-a[2])+a[1] then yes=not yes end
  j=i
 end
 return yes
end
local function ground(m,e)
 local ref=part(m,'Floor',0,-2,0,e.Width,4,e.Depth,e.GroundColor,e.GroundMaterial,false);ref.Transparency=1;m.PrimaryPart=ref
 local p=group(m,'Landform')
 for z=-e.Depth/2+1,e.Depth/2-1,2 do
  local xs={};local j=#e.Polygon
  for i,a in ipairs(e.Polygon) do local b=e.Polygon[j]
   if (a[2]>z)~=(b[2]>z) then table.insert(xs,a[1]+(z-a[2])*(b[1]-a[1])/(b[2]-a[2])) end
   j=i
  end
  table.sort(xs)
  for i=1,#xs-1,2 do part(p,'GroundTile',(xs[i]+xs[i+1])/2,-2,z,xs[i+1]-xs[i],4,2,e.GroundColor,e.GroundMaterial,true) end
 end
 e.Geometry.Floor={Width=e.Width,Depth=e.Depth,Y=0}
end
local function scenery(m,e)
 local p=group(m,'Edge architecture');local poly=e.Polygon
 if e.Edge=='dock' or e.Edge=='pirate' then
  detail(p,'Harbor water',0,-1.4,0,e.Width+38,.3,e.Depth+38,R(51,117,130),M.Glass)
 end
 for i,a in ipairs(poly) do
  local b=poly[i%#poly+1];local v1,v2=V(a[1],0,a[2]),V(b[1],0,b[2]);local d=(v2-v1).Unit
  local out=V(d.Z,0,-d.X);local length=(v2-v1).Magnitude
  -- Polygons are counterclockwise in XZ; test the outward normal to handle either winding.
  if inside(poly,(v1.X+v2.X)/2+out.X,(v1.Z+v2.Z)/2+out.Z) then out=-out end
  local fence=beam(p,'Arena limit',v1+V(0,30,0),v2+V(0,30,0),1.5,60,dark,M.Concrete,true);fence.Transparency=1;fence.CastShadow=false
  beam(p,'Foundation cut',v1-V(0,3.5,0),v2-V(0,3.5,0),3,7,e.GroundColor:Lerp(dark,.25),M.Rock,false)
  local edge=e.Edge
  if edge=='garden' or edge=='ruin' or edge=='snow' then
   local n=math.ceil(length/7)
   for j=0,n do local q=v1:Lerp(v2,j/n)-out*3.2
    for k=1,3 do
     local o=orb(p,edge=='snow' and 'Snow drift' or 'Verge foliage',q.X+math.sin(j*2+k)*2,.25,q.Z+math.cos(j*2+k)*2,2.4,edge=='snow' and ivory or R(79+k*6,111+k*8,58+k*5));o.Size=V(3.8,.8,3.2)
    end
   end
  end
  if edge=='cave' or edge=='snow' or edge=='ruin' then
   local n=math.ceil(length/15)
   for j=0,n do local q=v1:Lerp(v2,j/n)+out*6
    rock(p,q.X,q.Z,edge=='cave' and 2.2 or 1.25,e.GroundColor:Lerp(dark,.15))
    if edge~='cave' and j%2==0 then tree(p,q.X+out.X*4,q.Z+out.Z*4,1.2,edge=='snow') end
   end
  elseif edge=='dock' or edge=='pirate' then
   beam(p,'Quay edge',v1+V(0,.3,0),v2+V(0,.3,0),2,.6,wood,M.WoodPlanks,false)
   local n=math.ceil(length/13)
   for j=0,n do local q=v1:Lerp(v2,j/n);cylinder(p,'Mooring pile',q.X,1,q.Z,1.8,5,wood,M.Wood,false) end
  elseif edge=='space' or edge=='industrial' then
   beam(p,'Edge bulkhead',v1+V(0,2,0),v2+V(0,2,0),2,4,dark,M.Metal,true)
   beam(p,'Guide light',v1+V(0,4.05,0),v2+V(0,4.05,0),.4,.2,e.Accent,M.Neon,false)
   local n=math.ceil(length/14)
   for j=0,n do local q=v1:Lerp(v2,j/n);detail(p,'Hull rib',q.X,3,q.Z,2,6,2,ivory,M.Metal) end
  else
   local c=edge=='garden' and R(98,127,73) or e.GroundColor:Lerp(ivory,.12)
   beam(p,'Perimeter curb',v1+V(0,1.7,0),v2+V(0,1.7,0),2.2,3.4,c,edge=='garden' and M.Grass or M.Brick,true)
   local n=math.ceil(length/17)
   for j=0,n do local q=v1:Lerp(v2,j/n)+out*2
    if edge=='garden' then tree(p,q.X,q.Z,.95,false)
    elseif edge=='castle' then detail(p,'Battlement cap',q.X,4,q.Z,4,3,3,ivory,M.Limestone)
    elseif edge=='carnival' then detail(p,'Festoon post',q.X,7,q.Z,.3,14,.3,dark,M.Metal);orb(p,'Festoon bulb',q.X,14,q.Z,1.3,e.Accent)
    else lamp(p,q.X,q.Z,e.Accent) end
   end
  end
 end
end

-- Four authored movement arenas: conservatory, working harbor, alpine village, textile market.
local function buildValley(m,e)
 local stone,wood,leaf=R(198,184,150),R(102,77,56),R(85,126,77)
 path(m,0,28,132,24,R(187,172,141));path(m,0,-25,20,116,R(187,172,141))
 building(m,"Glasshouse Manor",0,-66,54,18,25,R(211,201,175),R(73,112,94),"stone")
 sign(m,"THE GLASSHOUSE",0,14,-55,24,R(104,161,118))
 for _,x in ipairs({-65,65}) do
  building(m,"Garden Gatehouse",x/65*60,-66,18,18,17,stone,wood,"stone")
  arch(m,x,-13,23,13,7,stone);tree(m,x,50,1.1);bed(m,x,23,12,14,R(213,156,149))
  lamp(m,x,3,R(255,222,159));lamp(m,x,37,R(255,222,159))
 end
 deck(m,e,"Conservatory Walk",0,-25,92,24,8,stone)
 ramp(m,e,"West Garden Approach",-33,23,-33,-13,8,22,stone)
 ramp(m,e,"East Garden Approach",33,23,33,-13,8,22,stone)
 rail(m,V(-46,8,-37),V(46,8,-37),wood)
 rail(m,V(-46,8,-37),V(-46,8,-13),wood);rail(m,V(46,8,-37),V(46,8,-13),wood)
 rail(m,V(-21,8,-13),V(21,8,-13),wood)
 for _,x in ipairs({-39,-13,13,39}) do
  part(m,"Fluted Conservatory Column",x,14,-34,2.4,12,2.4,stone,M.Limestone,true)
  detail(m,"Carved Capital",x,19.6,-34,4.2,1,4.2,stone,M.Limestone)
  beam(m,"Roof Truss",V(x,20,-36),V(x,25,-25),.6,.7,wood,M.Wood,false)
  beam(m,"Roof Truss",V(x,25,-25),V(x,20,-14),.6,.7,wood,M.Wood,false)
 end
 detail(m,"Greenhouse Ridge",0,25,-25,88,.7,.8,wood,M.Wood)
 for _,s in ipairs({-1,1}) do
  local pane=detail(m,"Conservatory Glass Roof",0,22.5,-25+s*5.5,88,.18,12,R(153,193,172),M.Glass,CFrame.Angles(s*math.atan(5/11),0,0))
  pane.Transparency=.35
 end
 for z=-35,-15,5 do detail(m,"Roof Glazing Rib",0,20+math.max(0,5-math.abs(z+25)*.5),z,88,.4,.4,R(140,171,145),M.Metal) end
 pool(m,0,39,20,18,R(80,148,151));cylinder(m,"Fountain Plinth",0,1,39,8,2,stone,M.Limestone,true)
 cylinder(m,"Fountain Stem",0,4.5,39,2.4,5,stone,M.Limestone,true)
 cylinder(m,"Fountain Bowl",0,7.2,39,6,1.1,stone,M.Limestone,false)
 orb(m,"Fountain Finial",0,9,39,2,R(141,169,128))
 for _,x in ipairs({-34,34}) do
  bed(m,x,62,16,9,R(146,126,204));tree(m,x,78,.8)
  part(m,"Garden Bench Seat",x,1.8,48,11,.5,3,wood,M.Wood,true)
  for _,z in ipairs({46.8,49.2}) do for _,dx in ipairs({-4,4}) do detail(m,"Bench Leg",x+dx,.8,z,.5,1.6,.5,wood,M.Wood) end end
  for _,y in ipairs({2.8,3.7}) do detail(m,"Bench Back Slat",x,y,49.3,11,.55,.4,wood,M.Wood) end
  for _,dx in ipairs({-4,4}) do detail(m,"Bench Back Upright",x+dx,2.9,49.3,.45,2.6,.45,wood,M.Wood) end
 end
 arch(m,0,76,30,14,7,stone);sign(m,"SKY GARDEN",0,18,80,24,leaf)
 for _,v in ipairs({{-74,-35},{74,-35},{-51,77},{51,77}}) do tree(m,v[1],v[2],.8) end
end

local function buildDepot(m,e)
 local brick,steel,wood=R(139,81,61),R(57,73,78),R(147,109,72)
 path(m,7,1,184,29,R(106,104,91));path(m,-54,29,25,111,R(106,104,91))
 building(m,"West Freight House",-87,20,24,40,26,brick,steel,"industrial")
 building(m,"Harbor Customs",84,3,24,28,23,R(205,191,151),R(79,107,111),"industrial")
 building(m,"Boatswain Workshop",-35,67,50,18,19,R(169,137,96),steel,"timber")
 sign(m,"PORT AUTHORITY",84,15,18,21,R(232,175,83));sign(m,"SUNSET FREIGHT",-35,12,78,31,R(232,175,83))
 deck(m,e,"Cargo Transfer Quay",15,-44,106,30,9,wood)
 ramp(m,e,"West Quay Access",-74,-44,-38,-44,9,22,wood)
 ramp(m,e,"East Quay Access",104,-44,68,-44,9,22,wood)
 rail(m,V(-38,9,-59),V(68,9,-59),steel);rail(m,V(-38,9,-29),V(68,9,-29),steel)
 for _,x in ipairs({-9,29}) do
  part(m,"Gantry Leg",x,25,-55,3,32,3,R(213,148,62),M.Metal,true)
  detail(m,"Gantry Foot",x,10,-55,7,2,6,steel,M.Metal)
  beam(m,"Crane Cross Bracing",V(x,13,-54),V(x+5,34,-54),.65,.65,steel,M.Metal,false)
 end
 part(m,"Quayside Crane Beam",11,41,-55,57,3,7,R(213,148,62),M.Metal,false)
 beam(m,"Crane Jib",V(10,40,-55),V(10,40,-7),2,2,R(213,148,62),M.Metal,false)
 beam(m,"Tension Cable",V(10,46,-55),V(10,41,-7),.18,.18,steel,M.Metal,false)
 part(m,"Winch Cable",10,30,-8,.22,20,.22,steel,M.Metal,false)
 cylinder(m,"Cargo Hook",10,19,-8,2,1.4,steel,M.Metal,false)
 sign(m,"QUAY 04",49,14,-27,18,R(231,173,71))
 for _,v in ipairs({{-75,65},{-7,66},{30,63},{40,39},{-25,23}}) do
  crate(m,v[1],v[2],8,wood);crate(m,v[1]+9,v[2]+1,6,R(113,133,112))
 end
 for _,x in ipairs({-86,-56,-26,4,34,64}) do
  cylinder(m,"Mooring Bollard",x,1.8,-74,2.2,3.6,steel,M.Metal,true)
  detail(m,"Quay Edge Stripe",x,.05,-70,17,.1,1,R(230,194,108),M.SmoothPlastic)
 end
 for _,v in ipairs({{-68,-12},{57,16},{-63,45},{16,68}}) do lamp(m,v[1],v[2],R(255,202,138)) end
 for _,x in ipairs({-25,9,43}) do
  detail(m,"Freight Lane Stripe",x,.05,0,14,.1,.5,R(224,199,139),M.SmoothPlastic)
 end
end

local function buildFrost(m,e)
 local stone,timber,blue=R(182,192,192),R(90,69,56),R(112,161,170)
 path(m,2,-14,172,27,R(153,164,166));path(m,0,51,28,68,R(153,164,166))
 building(m,"Northstar Lodge",44,-51,60,24,29,R(181,155,119),timber,"timber")
 building(m,"Clockmaker's House",-54,-32,22,22,37,R(196,186,163),timber,"timber")
 sign(m,"NORTHSTAR LODGE",44,16,-37,32,blue)
 detail(m,"Clock Dial",-54,29,-20.6,8,8,.25,R(237,228,195),M.SmoothPlastic)
 for i=0,11 do local a=i*math.pi/6
  detail(m,"Clock Hour",-54+math.sin(a)*3.1,29+math.cos(a)*3.1,-20.35,.35,.55,.18,timber,M.Metal)
 end
 detail(m,"Clock Minute Hand",-54,30.2,-20.1,.28,2.7,.2,timber,M.Metal)
 detail(m,"Clock Hour Hand",-52.9,29,-20.05,2.5,.28,.2,timber,M.Metal)
 for _,x in ipairs({-44,43}) do
  building(m,"Alpine Cottage",x,61,28,20,18,R(183,164,136),blue,"timber")
  detail(m,"Snow Cornice",x,18,72,30,.8,2,R(240,246,245),M.Snow)
  for k=-10,10,4 do detail(m,"Icicle",x+k,16.6,72,.3,2,.3,R(183,224,231),M.Ice) end
 end
 deck(m,e,"Village Promenade",-4,18,80,24,7,timber)
 ramp(m,e,"West Promenade",-77,18,-44,18,7,22,timber)
 ramp(m,e,"East Promenade",69,18,36,18,7,22,timber)
 rail(m,V(-44,7,6),V(36,7,6),timber);rail(m,V(-44,7,30),V(36,7,30),timber)
 for x=-40,34,4 do detail(m,"Promenade Board",x,7.02,18,.14,.08,23,R(144,113,82),M.Wood) end
 for _,x in ipairs({-31,23}) do
  detail(m,"Bridge Lantern Post",x,11.7,7,.5,9.4,.5,timber,M.Wood)
  orb(m,"Warm Lantern",x,16.5,7,1.5,R(255,216,143))
 end
 pool(m,-9,-37,20,17,R(133,175,188));cylinder(m,"Well Collar",-9,1.1,-37,9,2.2,stone,M.Cobblestone,true)
 part(m,"Well Upright",-13,5,-37,.7,8,.7,timber,M.Wood,true)
 part(m,"Well Upright",-5,5,-37,.7,8,.7,timber,M.Wood,true)
 detail(m,"Well Canopy",-9,9,-37,13,1,10,timber,M.Wood)
 for _,v in ipairs({{-88,-36},{-87,49},{84,51},{88,-31},{-27,-77},{24,77}}) do tree(m,v[1],v[2],1.2,true) end
 for _,v in ipairs({{-34,-8},{67,-18},{-22,48},{23,47}}) do lamp(m,v[1],v[2],R(255,211,143)) end
 bed(m,-74,-68,13,10,R(116,139,131));bed(m,73,44,13,10,R(116,139,131))
end

local function buildBazaar(m,e)
 local stone,ochre,teal=R(210,172,112),R(177,100,61),R(63,135,130)
 path(m,0,30,31,119,R(186,142,91));path(m,0,10,178,23,R(186,142,91))
 building(m,"Caravanserai",-10,-75,44,18,28,stone,teal,"sand")
 building(m,"Potter's House",-75,15,20,28,23,R(189,127,83),teal,"sand")
 building(m,"Spice Merchant",78,15,26,28,25,R(222,188,132),ochre,"sand")
 sign(m,"THE SILK ROAD",-10,16,-64,30,teal)
 deck(m,e,"Silk Merchants' Arcade",8,-35,94,26,8,stone)
 ramp(m,e,"West Arcade Approach",-73,-35,-39,-35,8,22,stone)
 ramp(m,e,"East Arcade Approach",89,-35,55,-35,8,22,stone)
 rail(m,V(-39,8,-48),V(55,8,-48),ochre);rail(m,V(-39,8,-22),V(55,8,-22),ochre)
 for i,x in ipairs({-30,-5,20,45}) do
  part(m,"Arcade Column",x,14,-45,2.2,12,2.2,stone,M.Sandstone,true)
  detail(m,"Carved Column Capital",x,19.5,-45,4,.8,4,stone,M.Sandstone)
  local cloth=i%2==0 and teal or R(174,83,75)
  detail(m,"Silk Canopy",x,20,-35,24,.5,23,cloth,M.Fabric)
  for q=-10,10,5 do detail(m,"Canopy Tassel",x+q,19,-23.4,.45,2,.5,R(233,191,104),M.Fabric) end
 end
 for _,x in ipairs({-40,40}) do
  stall(m,x,27,14,x<0 and teal or R(182,94,81));stall(m,x,57,14,R(205,165,83))
  lamp(m,x,44,R(255,201,129))
 end
 pool(m,0,17,21,21,R(87,158,161))
 cylinder(m,"Octagonal Fountain Base",0,1,17,9,2,stone,M.Sandstone,true)
 cylinder(m,"Fountain Pedestal",0,4,17,3,4,stone,M.Sandstone,true)
 cylinder(m,"Fountain Bowl",0,6.2,17,7,1,teal,M.SmoothPlastic,false)
 arch(m,0,77,28,15,6,stone);sign(m,"SUNSTONE BAZAAR",0,19,81,25,teal)
 for _,v in ipairs({{-87,-33},{65,-72},{-66,62},{59,70}}) do
  tree(m,v[1],v[2],.75);cylinder(m,"Terracotta Urn",v[1]+5,1.4,v[2],2.5,2.8,ochre,M.Slate,true)
 end
 for _,z in ipairs({-4,46}) do
  beam(m,"Festival Cord",V(-55,17,z),V(55,17,z),.12,.12,ochre,M.Fabric,false)
  for x=-48,48,12 do detail(m,"Festival Pennant",x,15.9,z,3,2,.15,x%24==0 and teal or ochre,M.Fabric) end
 end
end

local natureDefs={
 {Id="valley",Name="Sky Garden",Width=180,Depth=196,Polygon={{-66,-94},{66,-94},{88,-64},{88,60},{62,94},{-62,94},{-88,60},{-88,-64}},Edge="garden",GroundColor=R(109,137,91),GroundMaterial=M.Grass,Accent=R(160,211,144),Build=buildValley},
 {Id="depot",Name="Sunset Docks",Width=238,Depth=190,Polygon={{-116,-78},{-52,-94},{78,-94},{116,-60},{116,40},{54,40},{54,88},{-92,88},{-116,58}},Edge="dock",GroundColor=R(127,126,111),GroundMaterial=M.Concrete,Accent=R(234,177,85),Build=buildDepot},
 {Id="frost",Name="Frostfall Village",Width=244,Depth=194,Polygon={{-114,-68},{-60,-94},{48,-94},{116,-48},{104,54},{40,94},{-62,88},{-120,26}},Edge="snow",GroundColor=R(223,232,228),GroundMaterial=M.Snow,Accent=R(152,211,227),Build=buildFrost},
 {Id="bazaar",Name="Sunstone Bazaar",Width=226,Depth=208,Polygon={{-108,-48},{-72,-94},{36,-100},{100,-60},{110,24},{62,88},{-18,100},{-92,66}},Edge="sand",GroundColor=R(213,184,139),GroundMaterial=M.Sand,Accent=R(228,183,102),Build=buildBazaar},
}

local function buildNeon(p,e)
 local ink,con,cyan,pink=R(37,43,59),R(74,78,91),R(54,234,232),R(255,99,184)
 path(p,0,0,172,32,R(41,47,60));path(p,0,0,30,146,R(41,47,60))
 for _,x in ipairs({-77,77}) do
  for i,z in ipairs({-48,24,56}) do
   local col=i%2==0 and cyan or pink
   building(p,'Shinjuku shopfront',x,z,i==2 and 18 or 26,i==2 and 14 or 30,i==2 and 18 or 24+i*5,ink,col,'city')
   sign(p,({'NOODLE HOUSE','ARCADE 24','NIGHT MARKET'})[i],x,18,z+(i==2 and 8 or 16),i==2 and 17 or 22,col)
   detail(p,'Illuminated canopy',x,11,z+(i==2 and 10 or 18),i==2 and 20 or 28,.5,7,col,M.Neon)
   for j=-1,1 do detail(p,'Paving lantern',x+j*7,.2,z+(i==2 and 14 or 24),2,.1,2,col,M.Neon) end
  end
 end
 for _,x in ipairs({-43,43}) do
  for _,z in ipairs({-53,48}) do
   path(p,x,z,30,26,R(89,96,108));bed(p,x,z+6,17,8,R(255,127,169));lamp(p,x-12,z-8,cyan)
  end
 end
 deck(p,e,'Metro concourse',0,-2,48,30,10,con,true)
 ramp(p,e,'Western metro approach',-66,-2,-24,-2,10,22,con)
 ramp(p,e,'Eastern metro approach',66,-2,24,-2,10,22,con)
 rail(p,V(-24,10,-17),V(24,10,-17),cyan);rail(p,V(-24,10,13),V(24,10,13),cyan)
 for _,x in ipairs({-18,18}) do
  for _,z in ipairs({-13,9}) do part(p,'Metro canopy column',x,11,z,1.5,22,1.5,ink,M.Metal,true) end
 end
 detail(p,'Folded station canopy',0,23,-2,50,1,32,ink,M.Metal)
 detail(p,'Station roof light',0,23.6,-2,46,.2,2,cyan,M.Neon)
 sign(p,'NEON / CENTRAL',0,20,14,38,cyan)
 for _,x in ipairs({-18,-9,0,9,18}) do detail(p,'Concourse floor guide',x,10.06,-2,1,.1,20,cyan,M.Neon) end
 for _,z in ipairs({-71,70}) do
  arch(p,0,z,38,15,3,ink);sign(p,z<0 and 'OLD QUARTER' or 'NIGHT EXPRESS',0,17,z+2,30,pink)
 end
 for _,x in ipairs({-58,58}) do for _,z in ipairs({-27,28}) do lamp(p,x,z,pink) end end
 for z=-60,60,12 do for _,x in ipairs({-9,9}) do detail(p,'Street lane marker',x,.09,z,.4,.04,5,R(196,198,158),M.Concrete) end end
end

local function buildFoundry(p,e)
 local iron,rust,amber=R(63,68,69),R(130,76,49),R(255,171,63)
 path(p,0,0,198,36,R(75,70,59));path(p,0,50,194,26,R(75,70,59))
 path(p,-62,-10,24,120,R(75,70,59));path(p,63,-6,24,120,R(75,70,59))
 building(p,'The crucible hall',0,-69,78,28,31,R(103,95,77),amber,'industrial')
 sign(p,'FOUNDRY / 07',0,27,-53,54,amber)
 for _,x in ipairs({-25,0,25}) do
  cylinder(p,'Tall brick flue',x,41,-73,5,20,rust,M.Brick,false)
  for y=34,49,5 do cylinder(p,'Flue iron collar',x,y,-73,5.7,.6,iron,M.Metal,false) end
 end
 building(p,'Compressor house',-88,-36,25,52,24,iron,amber,'industrial')
 building(p,'Boiler maintenance',80,-58,27,28,22,rust,amber,'industrial')
 deck(p,e,'Furnace inspection gantry',0,-32,100,22,10,iron,true)
 deck(p,e,'Return gantry',-39,-7,22,28,10,iron,true)
 ramp(p,e,'Casting yard incline',-39,51,-39,7,10,20,iron)
 ramp(p,e,'Service incline',90,-32,50,-32,10,20,iron)
 rail(p,V(-50,10,-43),V(50,10,-43),amber)
 rail(p,V(-28,10,-21),V(50,10,-21),amber)
 rail(p,V(-50,10,-43),V(-50,10,7),amber);rail(p,V(-28,10,-21),V(-28,10,7),amber)
 for _,x in ipairs({-40,0,40}) do
  part(p,'Overhead crane upright',x,20,-38,2,40,2,iron,M.Metal,true)
 end
 part(p,'Return gantry support',-48,4.5,3,2.5,9,2.5,iron,M.Metal,true)
 part(p,'Overhead crane truss',0,39,-38,100,3,4,rust,M.Metal,false)
 for x=-44,40,12 do beam(p,'Crane truss diagonal',V(x,37,-35),V(x+10,41,-35),.8,.8,amber,M.Metal,false) end
 cylinder(p,'Central furnace',0,11,-5,19,22,iron,M.Metal,true)
 for y=3,23,5 do cylinder(p,'Furnace binding',0,y,-5,21,.8,rust,M.Metal,false) end
 cylinder(p,'Furnace stack',0,31,-5,9,22,iron,M.Metal,false)
 detail(p,'Hot inspection port',0,8,4.6,8,7,.2,amber,M.Neon)
 for _,x in ipairs({-79,76}) do
  cylinder(p,'Pressure vessel',x,10,58,19,20,rust,M.Metal,true)
  for y=3,18,5 do cylinder(p,'Riveted tank band',x,y,58,20,.8,iron,M.Metal,false) end
  beam(p,'Elevated steam conduit',V(x,20,58),V(x,20,20),2,2,iron,M.Metal,false)
  for j=1,3 do crate(p,x+(x<0 and 19 or -19),62+(j-2)*8,6,R(130,108,66)) end
 end
 for _,x in ipairs({-97,96}) do for _,z in ipairs({-4,30}) do lamp(p,x,z,amber) end end
 for x=-18,18,9 do detail(p,'Loading bay hazard paint',x,.05,61,4,.1,16,amber,M.SmoothPlastic) end
end

local function buildOrbital(p,e)
 local shell,dark,aqua=R(190,203,216),R(39,52,73),R(76,225,255)
 path(p,0,0,200,34,R(64,81,102));path(p,0,0,36,154,R(64,81,102))
 for _,x in ipairs({-44,44}) do
  building(p,'Research habitat',x,-60,25,31,23,shell,aqua,'tech')
  sign(p,x<0 and 'BOTANICS' or 'NAVIGATION',x,18,-43,21,aqua)
  pool(p,x,-34,19,10,R(52,167,213))
  for j=-2,2 do detail(p,'Solar collector panel',x+j*4,27,-60,3.8,.3,14,R(37,82,140),M.Glass,CFrame.Angles(.25,0,0)) end
 end
 for _,x in ipairs({-93,93}) do
  building(p,'Docking airlock',x,0,24,35,23,dark,aqua,'tech')
  cylinder(p,'Radio dish pedestal',x,26,0,5,7,shell,M.Metal,false)
  orb(p,'Communications radome',x,33,0,13,shell)
 end
 local rx,rz=-16,-6
 cylinder(p,'Fusion reactor pedestal',rx,2,rz,29,4,dark,M.Metal,true)
 cylinder(p,'Fusion containment',rx,12,rz,18,20,shell,M.Metal,true).Transparency=1
 cylinder(p,'Energy core',rx,14,rz,15,19,aqua,M.Neon,false)
 for a=0,315,45 do
  local t=math.rad(a);local x,z=rx+math.cos(t)*11,rz+math.sin(t)*11
  part(p,'Reactor cage rib',x,15,z,2,24,2,dark,M.Metal,false)
 end
 for y=5,26,7 do cylinder(p,'Containment ring',rx,y,rz,25,1.2,dark,M.Metal,false) end
 orb(p,'Reactor beacon',rx,30,rz,4,aqua)
 deck(p,e,'Observation promenade',6,53,64,22,10,shell,true)
 ramp(p,e,'Dockside ascent',-66,53,-26,53,10,20,shell)
 ramp(p,e,'Reactor approach',27,2,27,42,10,20,shell)
 rail(p,V(-26,10,42),V(17,10,42),aqua);rail(p,V(-26,10,64),V(38,10,64),aqua)
 rail(p,V(38,10,42),V(38,10,64),aqua)
 for _,x in ipairs({-16,6,28}) do
  part(p,'Observation support',x,4.5,59,3,9,3,dark,M.Metal,true)
  part(p,'Observation console',x,12,60,8,4,3,dark,M.Metal,true)
  detail(p,'Telemetry display',x,14.1,60,7,.2,2,aqua,M.Neon)
 end
 for _,x in ipairs({-25,25}) do part(p,'Observation sign pylon',x,10,75,1.3,20,1.3,dark,M.Metal,true) end
 sign(p,'ORBITAL / OBSERVATION',0,20,75,49,aqua)
 for _,x in ipairs({-47,47}) do
  for _,z in ipairs({-18,26,75}) do
   lamp(p,x,z,aqua);detail(p,'Landing guide',x,.04,z-6,9,.08,1,aqua,M.Neon)
  end
 end
 for _,x in ipairs({-21,21}) do for z=-75,-39,12 do detail(p,'Launchway markers',x,.06,z,2,.1,5,aqua,M.Neon) end end
end

local function buildCarnival(p,e)
 local cream,red,gold=R(237,211,163),R(187,60,81),R(255,205,98)
 path(p,0,-14,30,151,R(195,163,114));path(p,0,24,182,28,R(195,163,114))
 building(p,'Wheel ticket pavilion',0,-66,28,17,12,cream,red,'timber')
 sign(p,'STARDUST / 1928',0,15,-55,39,gold)
 local center=V(0,39,-67)
 for i=0,15 do
  local a,b=i*math.pi/8,(i+1)*math.pi/8
  local av=center+V(math.cos(a)*26,math.sin(a)*26,0)
  local bv=center+V(math.cos(b)*26,math.sin(b)*26,0)
  beam(p,'Ferris rim',av,bv,1.2,1.2,gold,M.Metal,false)
  beam(p,'Ferris spoke',center,av,.7,.7,cream,M.Metal,false)
  orb(p,'Wheel festoon bulb',av.X,av.Y,av.Z+1,1.4,gold)
  if i%2==0 then
   detail(p,'Gondola basket',av.X,av.Y-3,av.Z+4,6,4,6,red,M.SmoothPlastic)
   detail(p,'Gondola awning',av.X,av.Y,av.Z+4,7,.5,7,cream,M.SmoothPlastic)
  end
 end
 beam(p,'Wheel support',V(-15,0,-67),center,3,3,red,M.Metal,false)
 beam(p,'Wheel support',V(15,0,-67),center,3,3,red,M.Metal,false)
 cylinder(p,'Carousel dais',-48,1,4,29,2,cream,M.WoodPlanks,true)
 cylinder(p,'Carousel crown',-48,15,4,34,2,red,M.SmoothPlastic,false)
 cylinder(p,'Carousel spindle',-48,8,4,3,14,gold,M.Metal,false)
 for i=0,7 do
  local a=i*math.pi/4;local x,z=-48+math.cos(a)*10,4+math.sin(a)*10
  part(p,'Carousel pole',x,8,z,.5,13,.5,gold,M.Metal,false)
  detail(p,'Carved carousel horse',x,5,z,5,2.4,2.5,cream,M.Wood)
  detail(p,'Carved neck',x+1.7,6.4,z,1.1,3,1.3,cream,M.Wood)
  detail(p,'Carved horse head',x+2.3,7.5,z,2.2,1.2,1.4,cream,M.Wood)
  detail(p,'Painted saddle',x-.5,6.3,z,1.5,.25,2.7,red,M.Wood)
  for _,sx in ipairs({-1.5,1.5}) do for _,sz in ipairs({-.8,.8}) do detail(p,'Carved leg',x+sx,3.1,z+sz,.5,2,.5,cream,M.Wood) end end
  orb(p,'Carousel crown bulb',-48+math.cos(a)*16,15,4+math.sin(a)*16,1.6,gold)
 end
 deck(p,e,'Bandstand stage',39,37,54,32,6,R(143,92,77),false)
 ramp(p,e,'Midway stage approach',39,-11,39,21,6,20,R(143,92,77))
 ramp(p,e,'Eastern stage exit',98,37,66,37,6,20,R(143,92,77))
 rail(p,V(12,6,21),V(29,6,21),gold);rail(p,V(49,6,21),V(66,6,21),gold)
 rail(p,V(12,6,21),V(12,6,53),gold);rail(p,V(12,6,53),V(66,6,53),gold)
 for _,x in ipairs({18,60}) do for _,z in ipairs({26,48}) do part(p,'Bandstand column',x,12,z,1.5,12,1.5,cream,M.Wood,true) end end
 detail(p,'Bandstand canopy',39,19,37,50,1.5,30,red,M.SmoothPlastic)
 sign(p,'THE STARLIGHT REVUE',39,18,53,47,gold)
 for _,x in ipairs({-75,-41,-7}) do stall(p,x,69,20,x==-41 and red or R(65,140,143));lamp(p,x+12,79,gold) end
 for _,x in ipairs({-54,54}) do stall(p,x,-37,18,red);lamp(p,x+13,-29,gold) end
 for _,x in ipairs({-91,88}) do tree(p,x,13,.8,false) end
 for _,z in ipairs({-16,45}) do lamp(p,-23,z,gold) end
 for _,x in ipairs({-88,88}) do detail(p,'Festoon mast',x,10,-18,.7,20,.7,cream,M.Wood) end
 local last=V(-88,21,-18)
 for x=-77,88,11 do local q=V(x,18+3*(x/88)^2,-18)
  beam(p,'Hanging light cable',last,q,.1,.1,red,M.Metal,false);orb(p,'Festoon globe',x,q.Y-.7,-18,1.1,gold);last=q
 end
end

local urbanDefs={
 {Id='neon',Name='Neon District',Width=210,Depth=188,Polygon={{-88,-94},{72,-94},{105,-72},{105,67},{72,94},{-69,94},{-105,61},{-105,-67}},Edge='city',GroundColor=R(57,62,76),GroundMaterial=M.Asphalt,Accent=R(54,234,232),Build=buildNeon},
 {Id='foundry',Name='Clockwork Foundry',Width=242,Depth=190,Polygon={{-106,-84},{-50,-95},{86,-95},{121,-58},{121,57},{80,95},{-105,95},{-121,43},{-121,-46}},Edge='industrial',GroundColor=R(101,88,68),GroundMaterial=M.Concrete,Accent=R(255,171,63),Build=buildFoundry},
 {Id='orbital',Name='Orbital Station',Width=236,Depth=192,Polygon={{-118,-42},{-78,-42},{-78,-96},{78,-96},{78,-42},{118,-42},{118,42},{78,42},{78,96},{-78,96},{-78,42},{-118,42}},Edge='space',GroundColor=R(124,143,162),GroundMaterial=M.Metal,Accent=R(76,225,255),Build=buildOrbital},
 {Id='carnival',Name='Stardust Carnival',Width=244,Depth=208,Polygon={{-45,-104},{45,-104},{102,-47},{122,32},{90,104},{-90,104},{-122,32},{-102,-47}},Edge='carnival',GroundColor=R(117,146,98),GroundMaterial=M.Grass,Accent=R(255,205,98),Build=buildCarnival},
}

local function buildCavern(m,e)
 local stone,ice,dark=R(68,80,94),R(112,229,237),R(31,43,58)
 local g=group(m,"The Sunken Prism")
 path(g,0,8,30,152,R(67,91,105));path(g,0,40,142,24,R(73,96,111))
 pool(g,0,43,68,35,R(33,112,140))
 cylinder(g,"Crystal island",0,1.6,43,17,3.2,stone,M.Slate,true)
 for i=1,7 do
  local a=i*2.4;local x,z=math.cos(a)*5,43+math.sin(a)*5
  part(g,"Prism",x,9+i%3*2,z,3,16+i%3*4,3,ice,M.Neon,false,CFrame.Angles(.12*math.cos(a),a,.17*math.sin(a)))
 end
 deck(g,e,"Mining gallery",0,-38,84,28,9,stone,true)
 ramp(g,e,"West gallery slope",-28,20,-28,-24,9,20,stone)
 ramp(g,e,"East gallery slope",28,20,28,-24,9,20,stone)
 rail(g,V(-42,9,-52),V(42,9,-52),dark);rail(g,V(-18,9,-24),V(18,9,-24),dark)
 for _,x in ipairs({-42,42}) do rail(g,V(x,9,-52),V(x,9,-24),dark) end
 for _,x in ipairs({-35,35}) do part(g,"Gallery pier",x,4,-43,5,8,7,dark,M.Slate,true) end
 arch(g,0,-72,40,27,8,stone)
 building(g,"Expedition office",-56,-65,25,18,18,R(77,101,119),ice,"industrial")
 sign(g,"PRISM EXPEDITION",0,21,-69,29,ice)
 for _,p in ipairs({{-73,-30},{73,-38},{70,24},{45,63},{-51,55},{-72,17},{47,-65}}) do
  rock(g,p[1],p[2],1.35,dark)
  for j=1,3 do
   part(g,"Mineral spear",p[1]+(j-2)*3,7+j,p[2]-3,2,12+j*2,2,j==2 and ice or R(134,114,218),M.Glass,false,CFrame.Angles(.12*j,j,.08*j))
  end
  lamp(g,p[1]+7,p[2]+4,ice)
 end
 for i=1,10 do local a=i*2.2;detail(g,"Ore seam",math.cos(a)*19,.09,43+math.sin(a)*22,3,.14,1.4,ice,M.Neon) end
 for _,x in ipairs({-67,65}) do
  beam(g,"Miner rail",V(x-4,.12,-14),V(x-4,.12,38),.25,.12,R(133,140,139),M.Metal,false)
  beam(g,"Miner rail",V(x+4,.12,-14),V(x+4,.12,38),.25,.12,R(133,140,139),M.Metal,false)
  for z=-12,36,6 do detail(g,"Rail sleeper",x,.08,z,10,.1,.8,R(92,83,76),M.WoodPlanks) end
 end
 crate(g,-57,-43,6,R(138,109,71));crate(g,50,-61,5,R(138,109,71))
end

local function buildEmerald(m,e)
 local stone,pale,moss=R(108,124,106),R(188,192,154),R(66,111,69)
 local g=group(m,"Cloister of the Lost Spring")
 path(g,-12,10,28,145,R(146,151,123));path(g,-12,-36,157,24,R(163,167,139))
 path(g,-23,54,112,22,R(144,153,120));pool(g,-20,39,44,24,R(63,145,129))
 building(g,"Sealed sanctuary",-14,-81,50,20,25,stone,pale,"stone")
 for _,x in ipairs({-32,-14,4}) do arch(g,x,-66,16,17,3,pale) end
 sign(g,"THE LOST SPRING",-14,25,-68,34,R(186,219,134))
 deck(g,e,"Cloister crossing",-12,-36,72,28,10,pale,true)
 ramp(g,e,"West cloister ramp",-88,-36,-48,-36,10,20,pale)
 ramp(g,e,"East cloister ramp",64,-36,24,-36,10,20,pale)
 rail(g,V(-48,10,-50),V(24,10,-50),stone);rail(g,V(-48,10,-22),V(24,10,-22),stone)
 for _,x in ipairs({-39,15}) do
  for _,z in ipairs({-45,-27}) do part(g,"Arcade support",x,4.4,z,4,8.8,4,stone,M.Limestone,true) end
 end
 arch(g,-12,7,34,21,6,pale)
 for _,p in ipairs({{-77,5},{-73,57},{27,68},{64,-72},{66,5}}) do
  cylinder(g,"Column footing",p[1],.7,p[2],9,1.4,pale,M.Limestone,true)
  cylinder(g,"Broken column",p[1],8,p[2],5,16,stone,M.Limestone,true)
  part(g,"Capital",p[1],16.3,p[2],8,1.8,8,pale,M.Limestone,false)
  for j=1,4 do orb(g,"Trailing ivy",p[1]+2.4*math.sin(j),17-j*2,p[2]+2.5,3,moss) end
 end
 for _,p in ipairs({{-77,-71},{-81,29},{30,44},{18,77},{73,-60}}) do tree(g,p[1],p[2],1.1,false) end
 bed(g,-57,73,22,8,R(131,176,92));bed(g,28,15,10,18,R(130,168,94))
 for _,x in ipairs({-35,-5}) do cylinder(g,"Spring pedestal",x,1,39,7,2,stone,M.Limestone,true);orb(g,"Lotus glow",x,3.7,39,3,R(182,232,151)) end
 for _,p in ipairs({{-64,-78},{54,-73},{-73,72},{30,80}}) do rock(g,p[1],p[2],.6,stone) end
end

local function buildPirate(m,e)
 local timber,oak,navy=R(109,69,43),R(173,127,78),R(40,66,77)
 local g=group(m,"The Gilded Gull")
 pool(g,26,-18,126,116,R(43,130,142))
 path(g,-43,-5,25,126,R(165,139,98));path(g,13,48,153,23,R(165,139,98))
 building(g,"The Crooked Compass",-82,-38,30,26,25,R(153,133,92),R(138,59,42),"timber")
 building(g,"Harbor chandlery",-81,23,28,24,19,R(196,177,123),navy,"timber")
 sign(g,"THE CROOKED COMPASS",-82,22,-23,25,R(238,192,101))
 deck(g,e,"Gilded Gull quarterdeck",22,-20,44,90,9,oak).Material=M.WoodPlanks
 detail(g,"Laid teak deck",22,9.09,-20,43.5,.045,89.5,oak,M.WoodPlanks)
 for i=1,5 do detail(g,"Tapered bow",22,4.5,-65-i*2+1,44*(1-i/6),9,2.2,timber,M.WoodPlanks) end
 for _,x in ipairs({0,44}) do beam(g,"Bow wale",V(x,4.5,-65),V(22,4.5,-76),1,9,timber,M.WoodPlanks,false) end
 ramp(g,e,"Port gangway",-43,-44,0,-44,9,22,timber)
 ramp(g,e,"Starboard gangway",87,8,44,8,9,22,timber)
 for _,r in ipairs({{0,-65,0,-55},{0,-33,0,25},{44,-65,44,-3},{44,19,44,25},{0,-65,44,-65},{0,25,44,25}}) do rail(g,V(r[1],9,r[2]),V(r[3],9,r[4]),timber) end
 for _,x in ipairs({0,44}) do
  for _,y in ipairs({2,5,8}) do detail(g,"Hull strake",x,y,-20,1,.65,90,timber,M.WoodPlanks) end
  for z=-57,18,15 do cylinder(g,"Brass porthole",x,5,z,2,.5,R(211,168,73),M.Metal,false).CFrame=C(x,5,z)*CFrame.Angles(0,0,math.pi/2) end
 end
 cylinder(g,"Mainmast",22,31,-20,3.4,44,timber,M.Wood,true)
 beam(g,"Sail spar",V(5,43,-20),V(39,43,-20),1.3,1.3,timber,M.Wood,false)
 for i=-3,3 do detail(g,"Billowed canvas",22+i*4,34,-20-math.cos(i*.44)*3.2,4.1,17,.35,R(239,221,174),M.Fabric,nil) end
 for _,x in ipairs({5,39}) do beam(g,"Rigging",V(22,52,-20),V(x,12,12),.18,.18,navy,M.Fabric,false) end
 part(g,"Pennant",28,50,-20,10,5,.25,R(139,51,38),M.Fabric,false)
 for _,x in ipairs({8,36}) do
  detail(g,"Stern cabin panel",x,12,20,6,6,3,navy,M.WoodPlanks)
  detail(g,"Cabin window",x,12,21.7,3,3,.2,R(255,202,107),M.Glass)
 end
 beam(g,"Figurehead",V(22,8,-63),V(22,13,-74),3,3,R(211,168,73),M.Wood,false)
 for _,z in ipairs({-53,-39,3,17}) do detail(g,"Deck brass inlay",22,9.16,z,27,.1,.25,R(199,159,80),M.Metal) end
 for _,z in ipairs({-46,4}) do
  part(g,"Cannon carriage",31,10,z,5,2,5,timber,M.WoodPlanks,false)
  beam(g,"Bronze cannon",V(28,12,z),V(36,13,z),2.4,2.4,navy,M.Metal,false)
 end
 for _,p in ipairs({{-100,0},{-62,39},{-71,-66},{67,52}}) do crate(g,p[1],p[2],6,oak) end
 stall(g,-26,60,18,R(149,62,43));stall(g,7,60,18,R(72,112,99))
 for _,p in ipairs({{-52,-65},{-62,6},{63,-59},{89,43}}) do lamp(g,p[1],p[2],R(255,199,111)) end
 for _,p in ipairs({{-98,40},{-91,-59},{77,63},{94,-30}}) do tree(g,p[1],p[2],1.15,false) end
end

local function buildEmber(m,e)
 local ash,stone,gold=R(66,67,71),R(117,115,107),R(210,151,68)
 local g=group(m,"The Ember Gate")
 path(g,0,6,32,162,R(135,124,103));path(g,0,42,174,25,R(130,122,105))
 building(g,"Keep of the Ashen Crown",0,-78,82,25,34,ash,gold,"stone")
 for _,x in ipairs({-28,0,28}) do arch(g,x,-62,22,26,5,stone) end
 sign(g,"THE ASHEN CROWN",0,34,-63,40,gold)
 deck(g,e,"Gatehouse wallwalk",0,-36,110,26,10,stone,true)
 for _,x in ipairs({-41,41}) do ramp(g,e,"Gatehouse approach",x,21,x,-23,10,22,stone) end
 rail(g,V(-55,10,-49),V(55,10,-49),ash);rail(g,V(-30,10,-23),V(30,10,-23),ash)
 for _,x in ipairs({-55,55}) do rail(g,V(x,10,-49),V(x,10,-23),ash) end
 arch(g,0,-4,34,24,7,stone)
 for _,x in ipairs({-74,74}) do
  cylinder(g,"Bastion plinth",x,1.6,-38,29,3.2,stone,M.Cobblestone,true)
  cylinder(g,"Round bastion",x,17,-38,25,34,ash,M.Cobblestone,true)
  for _,y in ipairs({7,21,33}) do cylinder(g,"Stone belt",x,y,-38,26,1.2,stone,M.Limestone,false) end
  for i=1,10 do local a=i*math.pi/5
   detail(g,"Crenellation",x+math.cos(a)*12,36,-38+math.sin(a)*12,4,5,4,stone,M.Limestone,CFrame.Angles(0,-a,0))
   if i%2==0 then detail(g,"Arrow slit",x+math.cos(a)*12.55,23,-38+math.sin(a)*12.55,1.4,7,.3,R(22,27,32),M.Slate,CFrame.Angles(0,-a+math.pi/2,0)) end
  end
  part(g,"War banner",x,20,-24.8,7,13,.25,R(129,39,30),M.Fabric,false)
 end
 building(g,"Courtyard smithy",-75,38,26,24,19,stone,R(164,87,46),"industrial")
 building(g,"Watch chapel",74,41,23,24,24,ash,gold,"stone")
 pool(g,0,53,36,25,R(103,65,44));cylinder(g,"Crown brazier",0,2,53,13,4,ash,M.Cobblestone,true)
 for i=1,6 do orb(g,"Embers",math.sin(i*2)*3,5+i%3,53+math.cos(i*2)*3,3,R(255,139+i*8,53)).Material=M.Neon end
 for _,p in ipairs({{-90,-4},{91,4},{-46,75},{43,75}}) do lamp(g,p[1],p[2],R(255,177,81)) end
 bed(g,-30,77,20,8,R(143,111,64));bed(g,30,77,20,8,R(143,111,64))
 crate(g,-61,66,6,R(114,80,48));crate(g,65,68,5,R(114,80,48))
end

local adventureDefs={
 {Id="cavern",Name="Crystal Cavern",Width=186,Depth=192,Polygon={{-60,-96},{52,-92},{91,-36},{86,57},{27,96},{-52,87},{-93,20},{-89,-47}},Edge="cave",GroundColor=R(46,61,75),GroundMaterial=M.Slate,Accent=R(112,229,237),Build=buildCavern},
 {Id="emerald",Name="Emerald Ruins",Width=208,Depth=208,Polygon={{-104,-74},{-58,-104},{52,-100},{94,-60},{94,28},{50,28},{50,94},{-62,94},{-104,45}},Edge="ruin",GroundColor=R(97,123,82),GroundMaterial=M.Grass,Accent=R(175,213,120),Build=buildEmerald},
 {Id="pirate",Name="Pirate Cove",Width=244,Depth=188,Polygon={{-118,-58},{-82,-86},{66,-86},{118,-30},{112,74},{64,94},{18,70},{-94,72},{-122,20}},Edge="pirate",GroundColor=R(187,163,111),GroundMaterial=M.Sand,Accent=R(241,184,87),Build=buildPirate},
 {Id="ember",Name="Ember Keep",Width=220,Depth=208,Polygon={{-110,-64},{-60,-104},{74,-104},{108,-62},{108,66},{56,96},{-48,96},{-110,44}},Edge="castle",GroundColor=R(102,100,84),GroundMaterial=M.Cobblestone,Accent=R(218,151,71),Build=buildEmber},
}

local catalog={}
for _,list in ipairs({natureDefs,urbanDefs,adventureDefs}) do for _,e in ipairs(list) do table.insert(catalog,e) end end
local function spawns(m,e)
 local blocked={}
 for _,p in ipairs(m:GetDescendants()) do if p:IsA('BasePart') and p.CanCollide then
  local h=p.Size/2;local cf=p.CFrame
  local ex=math.abs(cf.RightVector.X)*h.X+math.abs(cf.UpVector.X)*h.Y+math.abs(cf.LookVector.X)*h.Z
  local ey=math.abs(cf.RightVector.Y)*h.X+math.abs(cf.UpVector.Y)*h.Y+math.abs(cf.LookVector.Y)*h.Z
  local ez=math.abs(cf.RightVector.Z)*h.X+math.abs(cf.UpVector.Z)*h.Y+math.abs(cf.LookVector.Z)*h.Z
  if p.Position.Y+ey>.3 then table.insert(blocked,{p.Position.X,p.Position.Z,ex+4,ez+4}) end
 end end
 local candidates={}
 for x=-e.Width/2+10,e.Width/2-10,6 do for z=-e.Depth/2+10,e.Depth/2-10,6 do
  local clear=true
  for _,d in ipairs({{0,0},{5,0},{-5,0},{0,5},{0,-5}}) do if not inside(e.Polygon,x+d[1],z+d[2]) then clear=false end end
  if clear then for _,b in ipairs(blocked) do if math.abs(x-b[1])<b[3] and math.abs(z-b[2])<b[4] then clear=false;break end end end
  if clear then table.insert(candidates,{x,z}) end
 end end
 assert(#candidates>=16,'Insufficient spawn space: '..e.Name)
 local chosen={};local folder=Instance.new('Folder');folder.Name='Spawns';folder.Parent=m
 for i=1,16 do
  local best,score=1,-1
  for j,q in ipairs(candidates) do local s=#chosen==0 and q[1]^2+q[2]^2 or math.huge
   for _,v in ipairs(chosen) do s=math.min(s,(q[1]-v[1])^2+(q[2]-v[2])^2) end
   if s>score then score=s;best=j end
  end
  local q=table.remove(candidates,best);table.insert(chosen,q)
  local n=string.format('Spawn%02d',i);local o=part(folder,n,q[1],.25,q[2],4,.2,4,ivory,M.SmoothPlastic,false);o.Transparency=1;o.CastShadow=false
  table.insert(e.Geometry.Spawns,{Name=n,X=q[1],Z=q[2],Y=.25})
 end
end
function MapBuilder.BuildInto(parent)
 local maps={}
 for _,e in ipairs(catalog) do
  e.Geometry={Version='HussWorld4',Id=e.Id,Name=e.Name,Width=e.Width,Depth=e.Depth,Polygon=e.Polygon,Ramps={},Decks={},Spawns={},Routes={},Obstacles={}}
  local m=group(parent,e.Name)
  m:SetAttribute('BombTagGenerated','HussWorld4');m:SetAttribute('MapWidth',e.Width);m:SetAttribute('MapDepth',e.Depth);m:SetAttribute('DisplayName',e.Name)
  m:SetAttribute('MovementDesign','No jumping: broad ramps, connected routes, smooth collision')
  pavingLayer=0;ground(m,e);e.Build(m,e);scenery(m,e);spawns(m,e);table.insert(maps,m)
 end
 return maps
end
function MapBuilder.GetGeometry()
 local t={};for _,e in ipairs(catalog) do table.insert(t,e.Geometry) end;return t
end
function MapBuilder.GetCatalog()
 local t={};for _,e in ipairs(catalog) do table.insert(t,{Id=e.Id,Name=e.Name,Width=e.Width,Depth=e.Depth,Polygon=e.Polygon}) end;return t
end
return MapBuilder

end)()
local library, previews, backup = Instance.new("Folder"), Instance.new("Folder"), Instance.new("Folder")
library.Name, previews.Name = "MapLibrary", "BombTagV6Previews"
backup.Name = "MovementMapsBackup_" .. os.time()
while ss:FindFirstChild(backup.Name) do backup.Name ..= "_" end
local arena, chosen, cellOrigin, voxelCopy
local changes, moved = {}, {}
local function edit(object, source)
  assert(object.Archivable, object.Name .. " must be Archivable.")
  local copy = object:Clone()
  if copy:IsA("BaseScript") then copy.Disabled = true end
  copy.Parent = backup
  if source then
    copy.Source = source -- Check source-write access before the world swap.
    copy.Source = object.Source
    table.insert(changes, {object, object.Source, source})
  end
end
local ok, failure = pcall(function()
  local source = vote.Source
  if not source:find("entry.loadedName", 1, true) then
    local count
    source, count = source:gsub("world = world,", "world = world, camera = camera, loadedName = nil,", 1)
    assert(count == 1, "Unrecognized vote client. Nothing changed.")
    local replacement = [[
      if entry.loadedName ~= name then
        for _, child in ipairs(entry.world:GetChildren()) do child:Destroy() end
        local template = previews:FindFirstChild(name)
        if template and template:IsA("Model") then
          local model = template:Clone()
          model.Parent = entry.world
          local bounds, size = model:GetBoundingBox()
          local distance = math.max(size.Magnitude / 2, 1) / math.sin(math.rad(entry.camera.FieldOfView / 2)) * 1.08
          entry.camera.CFrame = CFrame.lookAt(bounds.Position + Vector3.new(1, 0.95, 1).Unit * distance, bounds.Position)
          entry.loadedName = name
        else entry.loadedName = nil end
      end]]
    source, count = source:gsub("for _, child in ipairs%(entry%.world:GetChildren%(%)%) do.-model:Clone%(%)%.Parent = entry%.world%s+end",
      function() return replacement end, 1)
    assert(count == 1, "Unrecognized vote previews. Nothing changed.")
  end
  edit(vote, source)
  if hud then
    local text = hud.Source
    local first, last = text:find('tostring(GameConfig.MapName or "Arena01"):upper()', 1, true)
    if first then text = text:sub(1, first - 1) .. 'tostring(workspace:GetAttribute("CurrentVotedMap") or GameConfig.MapName):upper()' .. text:sub(last + 1) end
    edit(hud, text)
  end
  if legacy then edit(legacy) end
  local built = Builder.BuildInto(library)
  assert(#built == 12 and #library:GetChildren() == 12, "Expected twelve maps.")
  for _, model in ipairs(built) do
    assert(model.PrimaryPart == model:FindFirstChild("Floor") and model.PrimaryPart and model:FindFirstChild("Spawns")
      and #model.Spawns:GetChildren() >= 16, "Incomplete map: " .. model.Name)
    local preview = model:Clone()
    for _, object in ipairs(preview:GetDescendants()) do
      if object.Name == "Spawns" or object:IsA("LuaSourceContainer") or object:IsA("SurfaceGui") or object:IsA("Light")
        or (object:IsA("BasePart") and object.Transparency >= 1) then object:Destroy() end
    end
    preview.Parent = previews
  end
  local template = library:FindFirstChild(workspace:GetAttribute("CurrentVotedMap") or "Sky Garden") or library:FindFirstChild("Sky Garden")
  chosen, arena = template.Name, template:Clone()
  arena.Name = config.MapName
  arena:PivotTo(arena:GetPivot() + anchor.Position - (arena.Floor.Position + Vector3.new(0, arena.Floor.Size.Y / 2, 0)))
  arena:SetAttribute("DisplayName", chosen)
  arena:SetAttribute("VotedMap", chosen)
  -- Save the exact legacy voxel region before retiring its old legacy.
  if workspace:GetAttribute("SunsetV9TerrainActive") == true and workspace:GetAttribute("DetailedMapsTerrainMigrated") == nil then
    local center, half = anchor.Position + Vector3.new(0, -7, 0), Vector3.new(233, 39, 201)
    local region = Region3.new(center - half, center + half):ExpandToGrid(4)
    local minimum, maximum = (region.CFrame.Position - region.Size / 2) / 4, (region.CFrame.Position + region.Size / 2) / 4 - Vector3.one
    cellOrigin = Vector3int16.new(minimum.X, minimum.Y, minimum.Z)
    voxelCopy = workspace.Terrain:CopyRegion(Region3int16.new(cellOrigin, Vector3int16.new(maximum.X, maximum.Y, maximum.Z)))
    voxelCopy.Name, voxelCopy.Parent = "LegacyHarborTerrain", backup
    voxelCopy:SetAttribute("CellOrigin", minimum)
  end
end)
if not ok then
  library:Destroy(); previews:Destroy(); backup:Destroy()
  if arena then arena:Destroy() end
  error("Build stopped; original maps preserved: " .. tostring(failure))
end
local function archive(object)
  if object then table.insert(moved, {object, object.Parent}); object.Parent = backup end
end
local oldDisabled = legacy and legacy.Disabled
ok, failure = pcall(function()
  backup.Parent = ss
  archive(original)
  archive(ss:FindFirstChild("DetailedMapBuilder"))
  archive(ss:FindFirstChild("DetailedMapInstaller"))
  archive(rs:FindFirstChild("BombTagV6Previews"))
  for _, object in ipairs(maps:GetChildren()) do if object:IsA("Model") then archive(object) end end
  for _, change in ipairs(changes) do change[1].Source = change[3] end
  if legacy then legacy.Disabled = true end
  library.Parent, previews.Parent, arena.Parent = ss, rs, maps
  if voxelCopy then
    workspace.Terrain:FillBlock(CFrame.new(anchor.Position + Vector3.new(0, -7, 0)), Vector3.new(466, 78, 402), Enum.Material.Air)
  end
end)
if not ok then
  library:Destroy(); previews:Destroy(); arena:Destroy()
  for _, pair in ipairs(moved) do pair[1].Parent = pair[2] end
  for _, change in ipairs(changes) do change[1].Source = change[2] end
  if legacy then legacy.Disabled = oldDisabled end
  if voxelCopy then workspace.Terrain:PasteRegion(voxelCopy, cellOrigin, true) end
  error("Install stopped; originals restored. " .. tostring(failure))
end
if voxelCopy then
  workspace:SetAttribute("SunsetV9TerrainActive", false)
  workspace:SetAttribute("DetailedMapsTerrainMigrated", 1)
end
workspace:SetAttribute("CurrentVotedMap", chosen)
print("Installed 12 movement maps and voting previews. Lobby preserved. Backup: ServerStorage/" .. backup.Name)
print("Save to File, then test with two players in Studio.")
