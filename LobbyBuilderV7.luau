--!nonstrict
-- V7: calmer courtyard; no-jump routes.
local B={}
local V,C,R,M=Vector3.new,CFrame.new,Color3.fromRGB,Enum.Material
local ink,stone,cream,wood=R(27,39,38),R(151,170,151),R(230,227,205),R(105,73,52)
local sage,leaf,lime,gold=R(97,131,107),R(57,99,71),R(180,248,126),R(225,187,104)
local data
local function group(p,n) local g=Instance.new('Model');g.Name=n;g.Parent=p;return g end
local function part(p,n,x,y,z,w,h,d,c,m,solid,rot,class)
 local o=Instance.new(class or 'Part');o.Name=n;o.Size=V(w,h,d);o.CFrame=C(x,y,z)*(rot or CFrame.identity)
 o.Color=c;o.Material=m or M.Limestone;o.Anchored=true;o.CanCollide=solid==true;o.CanTouch=false;o.CanQuery=o.CanCollide
 o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth;o.Parent=p;return o
end
local function beam(p,n,a,b,w,h,c,solid)
 local q=(a+b)/2;return part(p,n,q.X,q.Y,q.Z,w,h,(b-a).Magnitude,c,M.Metal,solid,CFrame.lookAt(a,b).Rotation)
end
local function round(p,n,x,y,z,w,h,d,c,ball)
 local o=part(p,n,x,y,z,ball and w or h,ball and h or w,d,c,ball and M.Grass or M.Limestone,false,ball and CFrame.identity or CFrame.Angles(0,0,math.pi/2))
 o.Shape=ball and Enum.PartType.Ball or Enum.PartType.Cylinder;return o
end
local function label(p,title,sub,x,y,z,w,h,rot)
 local board=part(p,title,x,y,z,w,h,.4,ink,M.Metal,false,rot)
 local ui=Instance.new('SurfaceGui');ui.Face=Enum.NormalId.Back;ui.CanvasSize=Vector2.new(1000,300);ui.LightInfluence=.1;ui.Parent=board
 for i,t in ipairs({title,sub}) do
  local l=Instance.new('TextLabel');l.BackgroundTransparency=1;l.Size=UDim2.new(1,-40,0,i==1 and 140 or 82);l.Position=UDim2.fromOffset(20,i==1 and 26 or 177)
  l.Font=Enum.Font.GothamBold;l.Text=t;l.TextSize=i==1 and 66 or 33;l.TextColor3=i==1 and lime or cream;l.TextWrapped=true;l.Parent=ui
 end
end
local function pave(p,x,z,w,d,y)
 part(p,'Paving',x,y+.035,z,w,.05,d,cream)
end
local function rail(p,a,b)
 beam(p,'Smooth guard',a+V(0,1.8,0),b+V(0,1.8,0),.6,3.6,ink,true).Transparency=1
 beam(p,'Handrail',a+V(0,3.7,0),b+V(0,3.7,0),.4,.4,gold)
 beam(p,'Lower rail',a+V(0,1,0),b+V(0,1,0),.2,.2,ink)
 local n=math.ceil((b-a).Magnitude/16)
 for i=0,n do local q=a:Lerp(b,i/n);part(p,'Post',q.X,q.Y+1.8,q.Z,.4,3.6,.4,ink,M.Metal) end
end
local function bench(p,x,y,z,turn)
 local g=group(p,'Bench');local cf=C(x,y,z)*CFrame.Angles(0,turn or 0,0)
 local function b(n,px,py,pz,w,h,d,c,solid)
  local o=part(g,n,px,py,pz,w,h,d,c,M.WoodPlanks,solid);o.CFrame=cf*o.CFrame;return o
 end
 b('Smooth collision',0,1.25,0,9,2.5,3.2,wood,true).Transparency=1
 b('Seat',0,2.4,0,9,.35,3.2,wood)
 b('Back',0,3.3,-1.5,9,1.6,.3,wood)
 for _,s in ipairs({-1,1}) do b('Leg',s*3.5,1.1,0,.7,2.2,2.7,ink) end
end
local function lamp(p,x,y,z)
 part(p,'Lamp post',x,y+4,z,.45,8,.45,ink,M.Metal)
 local o=part(p,'Lantern',x,y+8,z,1.2,1.5,1.2,R(255,226,159),M.Neon)
 part(p,'Lantern cap',x,y+8.9,z,1.8,.3,1.8,ink,M.Metal)
 local light=Instance.new('PointLight');light.Color=R(255,226,172);light.Brightness=.6;light.Range=16;light.Shadows=false;light.Parent=o
end
local function garden(p,x,z,w,d,height)
 local g=group(p,'Garden')
 part(g,'Planter',x,1.35,z,w,2.7,d,stone,nil,true)
 part(g,'Coping',x,2.73,z,w+.3,.22,d+.3,cream)
 part(g,'Soil',x,2.87,z,w-1,.18,d-1,R(57,57,42),M.Ground)
 for i=-1,1 do round(g,'Hedge',x+i*(w-4)/3,3.9,z+d*.2,(w-2)/3,2.4,4,leaf,true) end
 if height then
  part(g,'Trunk',x,3+height*.35,z-2,1.5,height*.7,1.5,wood,M.Wood)
  round(g,'Canopy',x,3+height*.8,z-2,12,10,12,leaf,true)
  round(g,'Crown',x+2,3+height,z-2,9,7,9,sage,true)
 end
end
local function ramp(p,name,x)
 local a,b=V(x,0,-24),V(x,5,-48)
 part(p,name,x,2.5,-36,24,5,24,cream,nil,true,CFrame.Angles(0,math.pi,0),'WedgePart'):SetAttribute('NoJumpRoute',true)
 rail(p,a+V(-11.7,0,0),b+V(-11.7,0,0));rail(p,a+V(11.7,0,0),b+V(11.7,0,0))
 table.insert(data.Ramps,{Name=name,X1=x,Z1=-24,X2=x,Z2=-48,BaseY=0,Rise=5,Run=24,Width=24,SlopeDegrees=math.deg(math.atan(5/24))})
end
function B.Build(parent,origin)
 data={Version=7,Name='The Conservatory',Width=204,Depth=188,Ramps={},Decks={},Routes={},Spawns={}}
 local model=group(parent,'Lobby');model:SetAttribute('HussLobbyVersion',7);model:SetAttribute('MapWidth',204);model:SetAttribute('MapDepth',188)
 local floor=part(model,'Floor',0,-3,0,204,6,188,sage,M.Grass,true);model.PrimaryPart=floor
 local paths=group(model,'Promenades')
 pave(paths,0,0,92,128,0);pave(paths,0,70,62,28,.001)
 for _,s in ipairs({-1,1}) do pave(paths,s*76,7,46,76,.002) end
 pave(paths,0,36,164,24,.003);pave(paths,0,-16,140,16,.004)
 for i=0,7 do local a=math.pi/8+i*math.pi/4;part(paths,'Plaza border',math.sin(a)*33,.085,math.cos(a)*33,27.4,.035,.5,gold,M.Metal,false,CFrame.Angles(0,a,0)) end
 local f=group(model,'Bomb fountain')
 round(f,'Plinth',0,.24,0,32,.48,32,stone)
 round(f,'Basin',0,1.6,0,27,3.2,27,cream).CanCollide=true
 round(f,'Water',0,3.23,0,24,.15,24,R(49,109,102)).Material=M.Glass
 round(f,'Pedestal',0,4.5,0,7,3.2,7,ink)
 local bomb=round(f,'Bomb sculpture',0,9.4,0,9.5,9.5,9.5,ink,true);bomb.Material=M.Metal
 round(f,'Fuse socket',0,14.3,0,2,1.1,2,gold)
 beam(f,'Fuse',V(0,14.8,0),V(1.4,16.8,.2),.55,.55,gold)
 round(f,'Ember',1.4,16.8,.2,1.4,1.4,1.4,lime,true).Material=M.Neon
 label(f,'PASS THE PRESSURE','RUN / SPRINT / DODGE',0,2.1,13.65,14,2.2)
 local t=group(model,'North terrace')
 part(t,'Terrace deck',0,2.5,-68,148,5,40,stone,nil,true);pave(t,0,-68,147.8,39.8,5)
 table.insert(data.Decks,{Name='North terrace',X=0,Y=5,Z=-68,Width=148,Depth=40,SolidBase=true})
 ramp(t,'West promenade ramp',-54);ramp(t,'East promenade ramp',54)
 for _,ends in ipairs({{-74,-66},{-42,42},{66,74}}) do rail(t,V(ends[1],5,-48),V(ends[2],5,-48)) end
 rail(t,V(-74,5,-88),V(74,5,-88));rail(t,V(-74,5,-48),V(-74,5,-88));rail(t,V(74,5,-48),V(74,5,-88))
 for _,x in ipairs({-30,30}) do for _,z in ipairs({-57,-80}) do
  part(t,'Pavilion column',x,12.5,z,2.2,15,2.2,stone,nil,true)
  part(t,'Capital',x,19.7,z,3.2,.6,3.2,cream)
 end end
 part(t,'Pavilion eave',0,20,-68.5,67,1.1,30,cream);part(t,'Pavilion roof',0,21,-68.5,69,1.1,32,sage,M.Metal)
 label(t,'HUSS A BOMB','THE CONSERVATORY',0,15.8,-55.1,48,5.2)
 label(t,'YOUR NEXT CHASE','CHOOSE YOUR ARENA IN THE MAP VOTE',0,10.2,-80.4,40,4.6)
 local g=group(model,'Gardens and seating')
 for _,s in ipairs({-1,1}) do
  bench(t,s*52,5,-79);lamp(t,s*52,5,-84)
  garden(g,s*56,57,20,22,12);garden(g,s*84,67,18,26,15)
  garden(g,s*84,-54,14,24,13);garden(g,s*22,-31,15,13)
  lamp(g,s*39,0,59);lamp(g,s*41,0,-8);bench(g,s*29,0,51)
 end
 local wings=group(model,'Shaded galleries')
 for _,s in ipairs({-1,1}) do
  local turn=CFrame.Angles(0,-s*math.pi/2,0)
  for _,z in ipairs({-30,44}) do for _,x in ipairs({s*70,s*97}) do
   part(wings,'Gallery column',x,7.8,z,2.1,15.6,2.1,stone,nil,true)
   part(wings,'Capital',x,15.4,z,3.2,.6,3.2,cream)
  end end
  part(wings,'Gallery eave',s*80,15.9,7,39,1,73,cream);part(wings,'Gallery roof',s*80,16.9,7,40,1.1,74,sage,M.Metal)
  label(wings,s<0 and 'THE ARENAS' or 'THE CHASE','TAKE A MOMENT BETWEEN ROUNDS',s*63,12,7,45,3.5,turn)
  for i,name in ipairs(s<0 and {'EXPLORE','CHOOSE','PLAY'} or {'RUN','PASS','SURVIVE'}) do
   local z=-17+(i-1)*24;part(wings,'Gallery panel',s*97,4.5,z,3,9,14,stone,nil,true)
   label(wings,name,'HUSS A BOMB',s*95.3,5.2,z,12,4,turn)
  end
  bench(wings,s*85.5,0,21,s*math.pi/2);bench(wings,s*85.5,0,-5,s*math.pi/2)
 end
 local gate=group(model,'Arrival')
 for _,s in ipairs({-1,1}) do part(gate,'Gate pier',s*25,8,79,2.8,16,3.6,stone,nil,true);part(gate,'Gate capital',s*25,16,79,4,.7,4.2,cream) end
 part(gate,'Gate beam',0,16.5,79,54,1.4,4,cream)
 label(gate,'HUSS A BOMB','RUN / SPRINT / DODGE',0,17.1,81.3,34,4.5)
 local edge=group(model,'Boundary')
 for _,s in ipairs({-1,1}) do
  part(edge,'Side wall',s*101,3,0,2,6,188,stone,nil,true);part(edge,'Coping',s*101,6.05,0,2.5,.45,188,cream)
  part(edge,'End wall',0,3,s*93,200,6,2,stone,nil,true);part(edge,'Coping',0,6.05,s*93,200,.45,2.5,cream)
 end
 local spawn=part(model,'LobbySpawn',0,.5,64,8,1,8,cream,nil,false,nil,'SpawnLocation');spawn.Transparency=1;spawn.Neutral=true;spawn.Duration=0;spawn.Enabled=true
 table.insert(data.Spawns,{Name='LobbySpawn',X=0,Y=.5,Z=64})
 local function p(x,y,z) return {X=x,Y=y,Z=z} end
 local function route(name,width,points) table.insert(data.Routes,{Name=name,Width=width,Points=points}) end
 for _,s in ipairs({-1,1}) do
  route((s<0 and 'West' or 'East')..' arrival circuit',12,{p(0,0,64),p(0,0,40),p(s*36,0,40),p(s*36,0,0),p(s*36,0,-16),p(s*54,0,-16),p(s*54,0,-24),p(s*54,5,-48),p(s*54,5,-65),p(0,5,-65)})
  route((s<0 and 'West' or 'East')..' gallery access',10,{p(s*36,0,36),p(s*77,0,36),p(s*77,0,7),p(s*54,0,7),p(s*36,0,7)})
 end
 route('Fountain south promenade',12,{p(-36,0,26),p(0,0,26),p(36,0,26)})
 route('Fountain north promenade',10,{p(-36,0,-19),p(0,0,-19),p(36,0,-19)})
 if origin then for _,o in ipairs(model:GetDescendants()) do if o:IsA('BasePart') then o.CFrame=origin*o.CFrame end end end
 return model
end
function B.GetGeometry() return data end
return B
