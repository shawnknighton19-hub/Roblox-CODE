--!nonstrict
-- HUSS A BOMB / The Conservatory. Editable parts, continuous no-jump routes.
-- Build(parent[, origin]) returns Lobby with its direct child LobbySpawn.
local Builder={}
local V,C,R,M=Vector3.new,CFrame.new,Color3.fromRGB,Enum.Material
local ink,stone,cream,wood=R(27,39,38),R(151,170,151),R(230,227,205),R(105,73,52)
local sage,leaf,lime,gold=R(97,131,107),R(57,99,71),R(180,248,126),R(225,187,104)
local geometry
local function group(parent,name)
 local g=Instance.new('Model');g.Name=name;g.Parent=parent;return g
end
local function part(parent,name,x,y,z,w,h,d,color,material,solid,rotation,class)
 local p=Instance.new(class or 'Part');p.Name=name;p.Size=V(w,h,d);p.CFrame=C(x,y,z)*(rotation or CFrame.identity)
 p.Color=color;p.Material=material or M.Concrete;p.Anchored=true;p.CanCollide=solid~=false;p.CanTouch=false;p.CanQuery=p.CanCollide
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local function trim(p,n,x,y,z,w,h,d,color,mat,rot) return part(p,n,x,y,z,w,h,d,color,mat,false,rot) end
local function beam(p,n,a,b,w,h,color,mat,solid)
 local q=(a+b)/2;return part(p,n,q.X,q.Y,q.Z,w,h,(b-a).Magnitude,color,mat,solid,CFrame.lookAt(a,b).Rotation)
end
local function cylinder(p,n,x,y,z,diameter,height,color,mat,solid)
 local o=part(p,n,x,y,z,height,diameter,diameter,color,mat,solid,CFrame.Angles(0,0,math.pi/2));o.Shape=Enum.PartType.Cylinder;return o
end
local function ball(p,n,x,y,z,w,h,d,color,mat)
 local o=trim(p,n,x,y,z,w,h,d,color,mat or M.Grass);o.Shape=Enum.PartType.Ball;return o
end
local function label(parent,title,subtitle,x,y,z,width,height,rotation,color)
 local b=trim(parent,'Enamel / '..title,x,y,z,width,height,.4,ink,M.Metal,rotation)
 local ui=Instance.new('SurfaceGui');ui.Name='Lettering';ui.Face=Enum.NormalId.Back;ui.CanvasSize=Vector2.new(1000,300);ui.LightInfluence=.1;ui.Parent=b
 local function line(t,top,h,size,c)
  local l=Instance.new('TextLabel');l.BackgroundTransparency=1;l.Size=UDim2.new(1,-40,0,h);l.Position=UDim2.fromOffset(20,top)
  l.Font=Enum.Font.GothamBold;l.Text=t;l.TextSize=size;l.TextColor3=c;l.TextWrapped=true;l.Parent=ui
 end
 line(title,26,140,66,color or cream);line(subtitle,177,82,33,R(166,190,168))
 return b
end
local function paving(p,x,z,w,d,y,color)
 trim(p,'Limestone paving',x,y+.035,z,w,.05,d,color or cream,M.Limestone)
 for a=-w/2+8,w/2-.5,8 do trim(p,'Flush stone joint',x+a,y+.066,z,.07,.015,d,stone,M.Concrete) end
 for b=-d/2+8,d/2-.5,8 do trim(p,'Flush stone joint',x,y+.067,z+b,w,.015,.07,stone,M.Concrete) end
end
local function rail(p,a,b)
 beam(p,'Continuous guard',a+V(0,1.8,0),b+V(0,1.8,0),.65,3.6,ink,M.Metal,true).Transparency=1
 beam(p,'Bronze handrail',a+V(0,3.7,0),b+V(0,3.7,0),.38,.38,gold,M.Metal,false)
 beam(p,'Lower rail',a+V(0,1,0),b+V(0,1,0),.22,.22,ink,M.Metal,false)
 local n=math.ceil((b-a).Magnitude/6)
 for i=0,n do local q=a:Lerp(b,i/n);trim(p,'Guard upright',q.X,q.Y+1.8,q.Z,.36,3.6,.36,ink,M.Metal) end
end
local function lamp(p,x,y,z,height)
 trim(p,'Lamp plinth',x,y+.2,z,1.8,.4,1.8,cream,M.Limestone)
 trim(p,'Lamp post',x,y+height/2,z,.45,height,.45,ink,M.Metal)
 trim(p,'Lantern cap',x,y+height+.2,z,1.7,.35,1.7,ink,M.Metal)
 local glow=trim(p,'Warm lantern',x,y+height-.65,z,1.05,1.4,1.05,R(255,226,159),M.Neon)
 for _,s in ipairs({-1,1}) do trim(p,'Lantern frame',x+s*.64,y+height-.6,z,.12,1.6,1.4,ink,M.Metal) end
 -- Only six architectural lamps cast local light; neon details do not.
 local light=Instance.new('PointLight');light.Color=R(255,226,172);light.Brightness=.65;light.Range=17;light.Shadows=false;light.Parent=glow
end
local function bench(p,x,y,z,turn)
 local g=group(p,'Social bench');local basis=C(x,y,z)*CFrame.Angles(0,turn or 0,0)
 local function b(n,px,py,pz,w,h,d,color,mat,solid)
  local q=part(g,n,px,py,pz,w,h,d,color,mat,solid);q.CFrame=basis*q.CFrame
 end
 b('Smooth bench body',0,1.25,0,9,2.5,3.2,wood,M.WoodPlanks,true)
 for i=0,4 do b('Seat slat',-3.8+i*1.9,2.63,0,1.65,.2,3.4,wood:Lerp(cream,.15),M.Wood,false) end
 b('Backrest',0,3.4,-1.65,9,1.7,.28,wood,M.Wood,false)
 for _,s in ipairs({-1,1}) do b('Armrest',s*4.3,3.15,0,.34,.38,3.5,ink,M.Metal,false) end
end
local function tree(p,x,y,z,height,seed)
 trim(p,'Branching trunk',x,y+height*.35,z,1.5,height*.7,1.5,wood,M.Wood)
 for i=1,3 do
  local a=i*2.094+seed;local q=V(x+math.cos(a)*3,y+height*.7,z+math.sin(a)*3)
  beam(p,'Tree branch',V(x,y+height*.42,z),q,.65,.7,wood,M.Wood,false)
  ball(p,'Leaf crown',q.X,q.Y+2,q.Z,8,8,8,leaf:Lerp(sage,i*.1))
 end
 ball(p,'Upper crown',x,y+height,z,9,8,9,leaf:Lerp(sage,.33))
end
local function garden(p,x,z,w,d,treeHeight)
 local g=group(p,'Raised garden')
 part(g,'Smooth planter collision',x,1.35,z,w,2.7,d,stone,M.Limestone,true)
 trim(g,'Planter coping',x,2.73,z,w+.3,.22,d+.3,cream,M.Limestone)
 trim(g,'Soil bed',x,2.87,z,w-1,.18,d-1,R(57,57,42),M.Ground)
 for i=1,5 do
  local px=x+(i-3)*(w-3)/5
  ball(g,'Low hedge',px,3.7,z-d*.22,3.4,2.1,3.4,leaf)
  for j=1,2 do
   local fx=px+(j-1.5)*1.2;local fz=z+d*.25
   trim(g,'Lavender stem',fx,3.4,fz,.14,1.1,.14,sage,M.Grass)
   ball(g,'Lavender bloom',fx,4,fz,.8,.9,.8,R(158+i*5,148,190))
  end
 end
 if treeHeight then tree(g,x,2.9,z,treeHeight,x*.07) end
end
local function arch(p,x,y,z,width,height)
 for _,s in ipairs({-1,1}) do
  part(p,'Gate pier',x+s*width/2,y+height/2,z,2.8,height,3.6,stone,M.Limestone,true)
  trim(p,'Gate foot',x+s*width/2,y+.45,z,3.5,.9,4.2,cream,M.Limestone)
  trim(p,'Gate capital',x+s*width/2,y+height-.1,z,4,.7,4.3,cream,M.Limestone)
 end
 beam(p,'Gate crown',V(x-width/2,y+height,z),V(x+width/2,y+height,z),4,1.4,cream,M.Limestone,false)
 for i=0,12 do
  local t=math.pi*i/12
  trim(p,'Sculpted arch stone',x+math.cos(t)*width/2,y+height+math.sin(t)*5,z,width*.09,1.3,3.2,cream,M.Limestone,CFrame.Angles(0,0,t-math.pi/2))
 end
end
local function ramp(p,name,x)
 local a,b=V(x,0,-24),V(x,5,-48);local rotation=CFrame.Angles(0,math.pi,0)
 part(p,name,x,2.5,-36,24,5,24,cream,M.Limestone,true,rotation,'WedgePart'):SetAttribute('NoJumpRoute',true)
 rail(p,a+V(-11.7,0,0),b+V(-11.7,0,0));rail(p,a+V(11.7,0,0),b+V(11.7,0,0))
 for i=1,4 do local q=a:Lerp(b,i/5);trim(p,'Flush bronze ramp inlay',q.X,q.Y+.025,q.Z,22.8,.025,.14,gold,M.Metal,CFrame.Angles(math.atan(5/24),0,0)) end
 table.insert(geometry.Ramps,{Name=name,X1=x,Z1=-24,X2=x,Z2=-48,BaseY=0,Rise=5,Run=24,Width=24,SlopeDegrees=math.deg(math.atan(5/24))})
end
function Builder.Build(parent,origin)
 geometry={Version=6,Name='The Conservatory',Width=204,Depth=188,Ramps={},Decks={},Routes={},Spawns={}}
 local model=group(parent,'Lobby');model:SetAttribute('HussLobbyVersion',6);model:SetAttribute('MapWidth',204);model:SetAttribute('MapDepth',188)
 model:SetAttribute('Design','The Conservatory / original social courtyard')
 local floor=part(model,'Floor',0,-3,0,204,6,188,sage,M.Grass,true);model.PrimaryPart=floor
 local walks=group(model,'Continuous promenades')
 paving(walks,0,0,92,128,0,cream);paving(walks,0,70,62,28,.001,cream)
 paving(walks,-76,7,46,76,.002,cream);paving(walks,76,7,46,76,.002,cream)
 paving(walks,0,36,164,24,.003,cream);paving(walks,0,-16,140,16,.004,cream)
 -- Flush octagonal plaza inlay; decorative geometry never catches the character.
 for i=0,7 do
  local angle=math.pi/8+i*math.pi/4;local x,z=math.sin(angle)*33,math.cos(angle)*33
  trim(walks,'Octagonal border',x,.085,z,27.4,.035,.55,gold,M.Metal,CFrame.Angles(0,angle,0))
 end
 local fountain=group(model,'The Fuse / fountain monument')
 cylinder(fountain,'Fountain plinth',0,.24,0,32,.48,stone,M.Limestone,false)
 cylinder(fountain,'Smooth fountain collision',0,1.6,0,27,3.2,stone,M.Limestone,true)
 cylinder(fountain,'Dark water basin',0,3.23,0,24,.15,R(49,109,102),M.Glass,false).Transparency=.24
 for i=0,15 do
  local a=i*math.pi/8;local x,z=math.sin(a)*13.7,math.cos(a)*13.7
  trim(fountain,'Segmented limestone rim',x,3.25,z,5.5,.65,1.4,cream,M.Limestone,CFrame.Angles(0,a,0))
  if i%2==0 then cylinder(fountain,'Fountain spill',x*.7,3.6,z*.7,.26,1.3,R(154,236,205),M.Neon,false) end
 end
 cylinder(fountain,'Hero pedestal',0,4.5,0,7,3.2,ink,M.Metal,false)
 cylinder(fountain,'Pedestal bronze ring',0,5.7,0,7.5,.35,gold,M.Metal,false)
 ball(fountain,'Polished bomb sculpture',0,9.6,0,9.5,9.5,9.5,ink,M.Metal)
 cylinder(fountain,'Fuse socket',0,14.6,0,2,1.1,gold,M.Metal,false)
 beam(fountain,'Sculpted fuse',V(0,15,0),V(1.4,17,.2),.55,.55,wood,M.Wood,false)
 ball(fountain,'Fuse ember',1.4,17,.2,1.5,1.5,1.5,lime,M.Neon)
 for i=0,7 do local a=i*math.pi/4;trim(fountain,'Pedestal rivet',math.sin(a)*3.6,5.6,math.cos(a)*3.6,.25,.25,.25,gold,M.Metal) end
 label(fountain,'PASS THE PRESSURE','RUN  /  SPRINT  /  DODGE',0,2.1,13.65,14,2.2,nil,gold)
 local terrace=group(model,'North terrace / gathering pavilion')
 part(terrace,'Terrace deck',0,2.5,-68,148,5,40,stone,M.Limestone,true)
 paving(terrace,0,-68,147.8,39.8,5,cream)
 trim(terrace,'Terrace fascia',0,4.4,-47.92,148,1.1,.18,cream,M.Limestone)
 table.insert(geometry.Decks,{Name='North terrace',X=0,Y=5,Z=-68,Width=148,Depth=40,SolidBase=true})
 ramp(terrace,'West promenade ramp',-54);ramp(terrace,'East promenade ramp',54)
 for _,ends in ipairs({{-74,-66},{-42,42},{66,74}}) do rail(terrace,V(ends[1],5,-48),V(ends[2],5,-48)) end
 rail(terrace,V(-74,5,-88),V(74,5,-88));rail(terrace,V(-74,5,-48),V(-74,5,-88));rail(terrace,V(74,5,-48),V(74,5,-88))
 for _,x in ipairs({-30,30}) do for _,z in ipairs({-57,-80}) do
  part(terrace,'Pavilion column',x,12.5,z,2.2,15,2.2,stone,M.Limestone,true)
  trim(terrace,'Column base',x,5.35,z,3.2,.7,3.2,cream,M.Limestone);trim(terrace,'Column capital',x,19.7,z,3.4,.7,3.4,cream,M.Limestone)
  for _,s in ipairs({-1,1}) do trim(terrace,'Column groove',x+s*.65,12.5,z+1.12,.1,12,.04,cream,M.Limestone) end
 end end
 trim(terrace,'Pavilion entablature',0,20,-68.5,67,1.1,30,cream,M.Limestone)
 trim(terrace,'Pavilion copper roof',0,21,-68.5,69,1.1,32,sage,M.Metal)
 for i=-3,3 do trim(terrace,'Roof standing seam',i*9,21.6,-68.5,.2,.18,31,gold,M.Metal) end
 for i=-8,8 do trim(terrace,'Cornice dentil',i*3.8,19.4,-53.3,1.2,.8,.7,stone,M.Limestone) end
 label(terrace,'HUSS A BOMB','THE CONSERVATORY',0,15.8,-55.1,48,5.2,nil,lime)
 label(terrace,'THE NEXT CHASE STARTS HERE','CHOOSE YOUR ARENA IN THE MAP VOTE',0,10.2,-80.4,40,4.6,nil,cream)
 for _,x in ipairs({-52,52}) do bench(terrace,x,5,-79,0);lamp(terrace,x,5,-84,8) end
 local planting=group(model,'Courtyard gardens')
 for _,s in ipairs({-1,1}) do
  garden(planting,s*56,57,20,22,12);garden(planting,s*84,67,18,26,15)
  garden(planting,s*84,-54,14,24,13);garden(planting,s*22,-31,15,13,nil)
  lamp(planting,s*39,0,59,11);lamp(planting,s*41,0,-8,11)
  bench(planting,s*29,0,51,0)
 end
 local maps={'Sky Garden','Sunset Docks','Frostfall Village','Sunstone Bazaar','Neon District','Clockwork Foundry','Orbital Station','Stardust Carnival','Crystal Cavern','Emerald Ruins','Pirate Cove','Ember Keep'}
 local wings=group(model,'Map galleries / social loggias')
 for _,s in ipairs({-1,1}) do
  local x=s*80;local turn=CFrame.Angles(0,-s*math.pi/2,0)
  for _,z in ipairs({-30,44}) do for _,px in ipairs({s*70,s*97}) do
   part(wings,'Loggia column',px,7.8,z,2.1,15.6,2.1,stone,M.Limestone,true)
   trim(wings,'Loggia capital',px,15.4,z,3.5,.6,3.5,cream,M.Limestone)
  end end
  trim(wings,'Loggia entablature',x,15.9,7,39,1,73,cream,M.Limestone)
  trim(wings,'Loggia copper roof',x,16.9,7,40,1.1,74,sage,M.Metal)
  for z=-27,41,8.5 do trim(wings,'Copper roof seam',x,17.5,z,39,.15,.17,gold,M.Metal) end
  label(wings,s<0 and 'THE ARENAS' or 'THE CHASE','EXPLORE MAPS IN THE LOBBY MENU',s*63,12,7,45,3.5,turn,lime)
  for i=1,6 do
   local z=-22+(i-1)*11.2;local name=maps[i+(s>0 and 6 or 0)]
   local base=part(wings,'Gallery alcove',s*94,3.2,z,5,6.4,9.5,ink,M.Metal,true)
   label(wings,name:upper(),'RUN  /  SPRINT  /  DODGE',s*91.3,5.1,z,8.7,2.3,turn,cream)
   for j=1,3 do
    local tint=({sage,gold,R(136,175,190),R(193,141,112),R(147,160,197),R(204,113,90)})[i]
    trim(wings,'Abstract arena relief',s*91.15,2+j*.22,z+(j-2)*2.2,.4,1.3+j*.6,1.6,tint,M.Concrete)
   end
   trim(wings,'Gallery bronze reveal',s*91.3,.6,z,.3,.15,8.7,gold,M.Metal)
  end
  bench(wings,s*85.5,0,29,s*math.pi/2);bench(wings,s*85.5,0,-15,s*math.pi/2)
 end
 local welcome=group(model,'Arrival gate')
 arch(welcome,0,0,79,50,16)
 label(welcome,'HUSS A BOMB','RUN  /  SPRINT  /  DODGE',0,19.8,81,34,4.5,nil,lime)
 label(welcome,'WELCOME TO THE CHASE','NO JUMPING. KEEP YOUR FEET MOVING.',0,19.8,77,34,4.5,CFrame.Angles(0,math.pi,0),cream)
 for _,s in ipairs({-1,1}) do
  label(welcome,s<0 and 'THE RULES' or 'TAKE A BREATHER',s<0 and 'PASS THE BOMB. SURVIVE THE FUSE.' or 'USE GO AFK IN YOUR LOBBY MENU.',s*20,5,70,14,5,CFrame.Angles(0,s*.2,0),cream)
  trim(welcome,'Arrival board post',s*20,2,70,.7,4,.7,ink,M.Metal)
 end
 local edge=group(model,'Island edge / continuous containment')
 for _,s in ipairs({-1,1}) do
  part(edge,'East west wall',s*101,3,0,2,6,188,stone,M.Limestone,true)
  trim(edge,'East west coping',s*101,6.05,0,2.5,.45,188,cream,M.Limestone)
  part(edge,'North south wall',0,3,s*93,200,6,2,stone,M.Limestone,true)
  trim(edge,'North south coping',0,6.05,s*93,200,.45,2.5,cream,M.Limestone)
  for z=-84,84,14 do
   trim(edge,'Boundary pilaster',s*99.8,3,z,.5,6,2,cream,M.Limestone)
   trim(edge,'Boundary cap',s*101,6.6,z,3,.75,3,stone,M.Limestone)
  end
  for x=-84,84,14 do trim(edge,'Boundary pilaster',x,3,s*91.8,2,6,.5,cream,M.Limestone) end
 end
 local backdrop=group(model,'Garden skyline / non-colliding scenery')
 for _,s in ipairs({-1,1}) do for i=1,6 do
  local x=s*(111+(i%2)*8);local z=-83+(i-1)*32
  tree(backdrop,x,-2,z,22+(i%3)*3,i*.7)
  ball(backdrop,'Distant limestone boulder',x,-2,z,14,10,15,stone,M.Rock)
 end end
 local spawn=part(model,'LobbySpawn',0,.5,64,8,1,8,cream,M.SmoothPlastic,false,nil,'SpawnLocation')
 spawn.Transparency=1;spawn.Neutral=true;spawn.Duration=0;spawn.Enabled=true
 table.insert(geometry.Spawns,{Name='LobbySpawn',X=0,Y=.5,Z=64})
 local function route(name,width,points) table.insert(geometry.Routes,{Name=name,Width=width,Points=points}) end
 local function p(x,y,z) return {X=x,Y=y,Z=z} end
 for _,s in ipairs({-1,1}) do
  route((s<0 and 'West' or 'East')..' arrival circuit',12,{p(0,0,64),p(0,0,40),p(s*36,0,40),p(s*36,0,0),p(s*36,0,-16),p(s*54,0,-16),p(s*54,0,-24),p(s*54,5,-48),p(s*54,5,-65),p(0,5,-65)})
  route((s<0 and 'West' or 'East')..' gallery access',10,{p(s*36,0,36),p(s*77,0,36),p(s*77,0,7),p(s*54,0,7),p(s*36,0,7)})
 end
 route('Fountain south promenade',12,{p(-36,0,26),p(0,0,26),p(36,0,26)})
 route('Fountain north promenade',10,{p(-36,0,-19),p(0,0,-19),p(36,0,-19)})
 if origin then for _,o in ipairs(model:GetDescendants()) do if o:IsA('BasePart') then o.CFrame=origin*o.CFrame end end end
 return model
end
function Builder.GetGeometry() return geometry end
return Builder
