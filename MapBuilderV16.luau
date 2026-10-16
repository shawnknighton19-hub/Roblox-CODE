--!nonstrict
-- HAB V16: fifteen authored arenas. Build only stages new instances; it never
-- deletes existing maps, changes scripts, or starts services. The installer owns
-- backups and swaps. All dimensions are studs; floor top is origin.Y.
local Builder = {}
local V, C, R, M = Vector3.new, CFrame.new, Color3.fromRGB, Enum.Material
local ink, paper = R(24,32,55), R(245,248,255)
local gold, cyan = R(255,196,55), R(40,202,240)
local Catalog = {
 {Name="Orbital Station", W=244,D=216, Ground=R(92,110,147),Accent=cyan,Trim=R(166,127,255),Shape="octagon",Route="Twin airlocks and a reactor promenade"},
 {Name="Pirate Cove",W=256,D=208,Ground=R(232,202,137),Accent=R(255,116,84),Trim=R(55,185,178),Shape="island",Route="Ship deck, beach circuit and treasure quay"},
 {Name="Neon District",W=240,D=208,Ground=R(75,91,131),Accent=R(241,102,204),Trim=cyan,Shape="city",Route="Cross-town skywalk and four broad street blocks"},
 {Name="Emerald Ruins",W=212,D=228,Ground=R(121,167,115),Accent=R(74,224,173),Trim=gold,Shape="diamond",Route="Temple terrace and split garden courtyards"},
 {Name="Sky Garden",W=224,D=204,Ground=R(145,199,147),Accent=R(112,194,251),Trim=R(250,184,219),Shape="garden",Route="Flower terrace and two wide orchard loops"},
 {Name="Ember Keep",W=248,D=224,Ground=R(131,111,125),Accent=R(255,144,61),Trim=R(255,213,95),Shape="keep",Route="Raised battlement and a three-lane castle yard"},
 {Name="Clockwork Foundry",W=264,D=200,Ground=R(119,132,147),Accent=R(255,192,70),Trim=R(70,202,191),Shape="hexagon",Route="Assembly deck and asymmetric boiler lanes"},
 {Name="Frostfall Village",W=252,D=216,Ground=R(221,237,246),Accent=R(96,199,239),Trim=R(238,129,145),Shape="village",Route="Lodge balcony, frozen square and cottage streets"},
 {Name="Crystal Cavern",W=192,D=200,Ground=R(129,132,181),Accent=R(178,139,255),Trim=R(88,221,233),Shape="cavern",Route="Prism causeway with open crystal bends"},
 {Name="Sunset Docks",W=268,D=218,Ground=R(176,151,124),Accent=R(255,169,92),Trim=R(79,191,212),Shape="dock",Route="Long loading quay and offset warehouse circuit"},
 {Name="Sunstone Bazaar",W=236,D=228,Ground=R(229,191,136),Accent=R(244,117,116),Trim=R(74,194,190),Shape="bazaar",Route="Merchant terrace and open market avenues"},
 {Name="Stardust Carnival",W=268,D=220,Ground=R(146,137,180),Accent=R(244,132,199),Trim=R(255,208,76),Shape="carnival",Route="Show stage, big-top midway and ticket loops"},
 {Name="Fuseworks",W=228,D=240,Ground=R(127,151,156),Accent=R(255,188,65),Trim=R(92,213,174),Shape="fuse",Route="Long fuse assembly deck between two workshop lanes"},
 {Name="Detonator Plaza",W=216,D=184,Ground=R(176,190,213),Accent=R(111,170,255),Trim=R(255,185,86),Shape="plaza",Route="Compact button plaza and four park pockets"},
 {Name="Payload Port",W=280,D=204,Ground=R(136,160,176),Accent=R(245,171,64),Trim=R(75,202,184),Shape="port",Route="Cargo bridge, crane court and staggered freight lanes"},
}
Builder.Catalog = Catalog
local function folder(parent,name,class)
 local o=Instance.new(class or "Folder");o.Name=name;o.Parent=parent;return o
end
local function part(s,parent,name,x,y,z,w,h,d,color,collide,material,rotation,class)
 local o=Instance.new(class or "Part");o.Name=name;o.Size=V(w,h,d)
 o.CFrame=C(x,y,z)*(rotation or C());o.Color=color or paper;o.Material=material or M.SmoothPlastic
 o.Anchored=true;o.CanCollide=collide==true;o.CanTouch=false;o.CanQuery=o.CanCollide
 o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth;o.CastShadow=true
 o.Parent=parent
 if collide then table.insert(s.Solids,o) end
 return o
end
local function block(s,p,n,x,y,z,w,h,d,c,material)
 return part(s,p,n,x,y,z,w,h,d,c,true,material)
end
local function detail(s,p,n,x,y,z,w,h,d,c,material,rotation)
 return part(s,p,n,x,y,z,w,h,d,c,false,material,rotation)
end
local function ball(s,p,n,x,y,z,d,c,collide)
 local a=part(s,p,n,x,y,z,d,d,d,c,collide);a.Shape=Enum.PartType.Ball;return a
end
local function disc(s,p,n,x,y,z,d,h,c,collide)
 local a=part(s,p,n,x,y,z,h,d,d,c,collide,M.SmoothPlastic,CFrame.Angles(0,0,math.pi/2));a.Shape=Enum.PartType.Cylinder;return a
end
local function beam(s,p,n,a,b,w,h,c,collide)
 local q=(a+b)/2;local direction=(b-a).Unit
 local up=math.abs(direction.Y)>.98 and V(1,0,0) or V(0,1,0)
 return part(s,p,n,q.X,q.Y,q.Z,w,h,(b-a).Magnitude,c,collide,M.SmoothPlastic,CFrame.lookAt(q,b,up).Rotation)
end
local function sign(s,p,text,x,y,z,w,h,color,turn)
 local cf=CFrame.Angles(0,turn or 0,0)
 local a=detail(s,p,"Outlined sign",x,y,z,w+.7,h+.7,.65,ink,nil,cf)
 local board=detail(s,p,"Glossy sign",x,y,z+.39,w,h,.18,color,nil,cf)
 local gui=folder(board,"HighResolutionLettering","SurfaceGui")
 gui.Face=Enum.NormalId.Back;gui.CanvasSize=Vector2.new(1600,400);gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize
 gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.MaxDistance=350
 local gloss=folder(gui,"Top shine","Frame");gloss.Size=UDim2.fromScale(1,.38);gloss.BackgroundColor3=paper;gloss.BackgroundTransparency=.84;gloss.BorderSizePixel=0
 local label=folder(gui,"Heading","TextLabel");label.Size=UDim2.fromScale(.94,.9);label.Position=UDim2.fromScale(.03,.05)
 label.BackgroundTransparency=1;label.Font=Enum.Font.GothamBlack;label.Text=text;label.TextScaled=true
 label.TextColor3=paper;label.TextStrokeColor3=ink;label.TextStrokeTransparency=0
 return a
end
local function outlineBox(s,p,n,x,z,w,d,h,color)
 local g=folder(p,n,"Model")
 block(s,g,"Clean collision",x,h/2,z,w,h,d,ink)
 detail(s,g,"Color body",x,h/2+.04,z,w-.8,h-.55,d-.8,color)
 detail(s,g,"Gloss cap",x,h+.06,z,w-.9,.16,d-.9,color:Lerp(paper,.17))
 return g
end
local function cover(s,p,x,z,w,d,color,h)
 return outlineBox(s,p,"Low cover",x,z,w,d,h or 4.6,color)
end
local function bomb(s,p,x,y,z,size,color)
 local g=folder(p,"Bomb landmark","Model")
 local enamel=color or ink:Lerp(paper,.08)
 ball(s,g,"Bomb shell",x,y,z,size,enamel:Lerp(ink,.18),false)
 ball(s,g,"Enamel highlight",x,y+size*.05,z+size*.025,size*.94,enamel,false)
 disc(s,g,"Fuse collar",x,y+size*.47,z,size*.3,size*.16,gold,false)
 beam(s,g,"Curved fuse A",V(x,y+size*.54,z),V(x+size*.12,y+size*.78,z),size*.07,size*.07,ink,false)
 beam(s,g,"Curved fuse B",V(x+size*.12,y+size*.78,z),V(x+size*.28,y+size*.82,z),size*.07,size*.07,paper,false)
 ball(s,g,"Spark",x+size*.29,y+size*.82,z,size*.15,gold,false)
 ball(s,g,"Gloss spot",x-size*.22,y+size*.24,z+size*.37,size*.12,paper,false)
 return g
end
local function plinth(s,p,x,z,d,h,color)
 disc(s,p,"Outlined plinth",x,h/2,z,d,h,ink,true)
 disc(s,p,"Enamel rim",x,h+.02,z,d-.6,.18,color,false)
end
local function tree(s,p,x,z,style,scale)
 local k=scale or 1;local g=folder(p,"Sculpted tree","Model")
 disc(s,g,"Rounded planter",x,.6,z,7*k,1.2,ink,true)
 disc(s,g,"Soil",x,1.25,z,6.4*k,.12,R(112,137,94),false)
 block(s,g,"Trunk",x,4*k,z,1.8*k,8*k,1.8*k,R(115,88,77))
 if style=="palm" then
  for i=0,4 do local a=i*math.pi*2/5
   local leaf=detail(s,g,"Palm frond",x+math.cos(a)*3*k,10*k,z+math.sin(a)*3*k,9*k,.7*k,3*k,R(89,182,127),nil,CFrame.Angles(0,-a,.17));leaf.Shape=Enum.PartType.Ball
  end
 else
  for i=0,2 do
   local c=style=="snow" and paper or (style=="pink" and R(248,169,200) or R(101,184,121))
   local a=ball(s,g,"Rounded crown",x+(i-1)*2*k,(9+i%2*2)*k,z+(i%2)*2*k,(8-i*.6)*k,c,false);a.Size=V(8-i*.6,6,7)*k
  end
 end
end
local function crate(s,p,x,z,size,color)
 local g=outlineBox(s,p,"Bomb cargo",x,z,size,size,size*.75,color)
 for _,k in ipairs({-.28,.28}) do detail(s,g,"Cargo band",x+size*k,size*.38,z,.55,size*.77,size+.14,ink) end
 bomb(s,g,x,size*.43,z+size*.505,size*.32,gold)
 return g
end
local function building(s,p,name,x,z,w,d,h,color,roof)
 local g=outlineBox(s,p,name,x,z,w,d,h,color)
 detail(s,g,"Roof ink lip",x,h+.6,z,w+1.8,1.2,d+1.8,ink)
 detail(s,g,"Colored roof",x,h+1.26,z,w+1.05,.24,d+1.05,roof or s.Entry.Trim)
 detail(s,g,"Door inset",x,3,z+d/2+.08,4.5,6,.18,ink)
 detail(s,g,"Door window",x,4.1,z+d/2+.2,3,2,.12,cyan)
 for _,k in ipairs({-.3,.3}) do
  detail(s,g,"Outlined window",x+w*k,h*.49,z+d/2+.09,w*.22,4.5,.2,ink)
  detail(s,g,"Window glass",x+w*k,h*.49,z+d/2+.22,w*.22-.5,3.9,.14,paper:Lerp(s.Entry.Accent,.23))
  detail(s,g,"Window mullion",x+w*k,h*.49,z+d/2+.31,.3,3.9,.12,ink)
 end
 sign(s,g,name:upper(),x,h-2.4,z+d/2+.4,w*.88,3.8,s.Entry.Accent)
 return g
end
local function stall(s,p,name,x,z,w,c)
 local g=outlineBox(s,p,name,x,z,w,6,3.6,c)
 for _,k in ipairs({-1,1}) do detail(s,g,"Canopy post",x+k*(w/2-.5),6,z,.7,12,.7,ink) end
 detail(s,g,"Canopy outline",x,11.9,z,w+2,.8,9,ink)
 for k=-2,2 do detail(s,g,"Canvas stripe",x+k*w/5,12.35,z,w/5,.25,8.5,k%2==0 and c or paper) end
 sign(s,g,name:upper(),x,8.5,z+3.9,w-1,3,c)
 bomb(s,g,x,5.4,z,3.3,c)
end
local function crystal(s,p,x,z,h,c)
 local g=folder(p,"Crystal cluster","Model")
 disc(s,g,"Crystal collision base",x,2,z,9,4,ink,true)
 for i=0,2 do
  local a=detail(s,g,"Faceted crystal",x+(i-1)*2.5,h*(.45-i*.08),z+(i%2)*2,4,h*(.85-i*.12),4,c:Lerp(paper,i*.1),nil,CFrame.Angles(.06*i,.6+i,.13*(i-1)))
  detail(s,g,"Crystal glint",a.Position.X-1,a.Position.Y,a.Position.Z+2,.35,a.Size.Y*.65,.12,paper)
 end
end
local function road(s,p,x,z,w,d,c)
 s.RoadLayers=(s.RoadLayers or 0)+1
 detail(s,p,"Flush route surface",x,.025+s.RoadLayers*.022,z,w,.018,d,c or s.Entry.Ground:Lerp(paper,.28))
end
local function terrace(s,p,name,x,z,w,d,h,axis,run,color)
 assert(run>=h*4 and h<=12,"Unsafe ramp grade")
 local g=folder(p,name,"Model");local deck=block(s,g,"Walkable deck",x,h/2,z,w,h,d,ink)
 deck:SetAttribute("HABWalkableV16",true)
 detail(s,g,"Deck enamel",x,h+.015,z,w-.1,.025,d-.1,color or s.Entry.Ground:Lerp(paper,.33))
 local rw=axis=="X" and math.min(d-2,24) or math.min(w-2,24)
 for _,side in ipairs({-1,1}) do
  local target=V(x,h,z)+(axis=="X" and V(side*w/2,0,0) or V(0,0,side*d/2))
  local start=target+(axis=="X" and V(side*run,-h,0) or V(0,-h,side*run))
  local delta=V(target.X-start.X,0,target.Z-start.Z);local q=(start+target)/2
  local ramp=part(s,g,"No-jump ramp",q.X,q.Y,q.Z,rw,h,run,color or s.Entry.Accent,true,M.SmoothPlastic,CFrame.lookAt(q,q-delta).Rotation,"WedgePart")
  ramp:SetAttribute("HABRampV16",true);ramp:SetAttribute("Width",rw);ramp:SetAttribute("Rise",h);ramp:SetAttribute("Run",run)
  ramp:SetAttribute("Start",start);ramp:SetAttribute("End",target)
  -- Flush painted approach marks do not introduce a curb at the ramp foot.
  local foot=start+delta.Unit*2
  detail(s,g,"Ramp approach stripe",foot.X,.025,foot.Z,axis=="X" and 1 or rw,.035,axis=="X" and rw or 1,paper)
 end
 -- Side rails leave both ends completely open. No narrow decorative posts.
 for _,side in ipairs({-1,1}) do
  if axis=="X" then
   block(s,g,"Deck safety rail",x,h+1.6,z+side*(d/2-.6),w-1,3.2,1.2,ink)
   detail(s,g,"Rail color",x,h+3.23,z+side*(d/2-.6),w-1,.15,1.25,s.Entry.Accent)
  else
   block(s,g,"Deck safety rail",x+side*(w/2-.6),h+1.6,z,1.2,3.2,d-1,ink)
   detail(s,g,"Rail color",x+side*(w/2-.6),h+3.23,z,1.25,.15,d-1,s.Entry.Accent)
  end
 end
 s.Deck={X=x,Z=z,Width=w,Depth=d,Height=h,Axis=axis}
 return g
end
local function polygon(e)
 local x,z=e.W/2,e.D/2
 local shapes={
  octagon={{-.6,-1},{.6,-1},{.6,-.6},{1,-.6},{1,.6},{.6,.6},{.6,1},{-.6,1},{-.6,.6},{-1,.6},{-1,-.6},{-.6,-.6}},
  island={{-.82,-.85},{-.2,-1},{.66,-.91},{1,-.48},{.88,.62},{.28,1},{-.67,.88},{-1,.22},{-.98,-.4}},
  city={{-.8,-1},{.8,-1},{1,-.72},{1,.6},{.6,1},{-.82,1},{-1,.72},{-1,-.72}},
  diamond={{-.6,-1},{.6,-1},{1,-.42},{1,.42},{.6,1},{-.6,1},{-1,.42},{-1,-.42}},
  garden={{-.7,-1},{.7,-1},{1,-.54},{1,.54},{.7,1},{-.7,1},{-1,.54},{-1,-.54}},
  keep={{-.85,-1},{.85,-1},{1,-.85},{1,.75},{.76,1},{-.76,1},{-1,.75},{-1,-.85}},
  hexagon={{-.78,-1},{.78,-1},{1,0},{.78,1},{-.78,1},{-1,0}},
  village={{-.8,-.91},{.5,-1},{.97,-.55},{1,.4},{.7,.93},{-.5,1},{-1,.55},{-.97,-.5}},
  cavern={{-.7,-1},{.6,-.94},{1,-.4},{.96,.55},{.48,1},{-.65,.94},{-1,.35},{-.96,-.5}},
  dock={{-1,-.8},{-.45,-1},{1,-1},{1,.1},{.45,.1},{.45,1},{-.9,1},{-1,.65}},
  bazaar={{-.82,-1},{.6,-1},{1,-.6},{1,.7},{.76,1},{-.76,1},{-1,.7},{-1,-.78}},
  carnival={{-1,0},{-.87,-.5},{-.5,-.87},{0,-1},{.5,-.87},{.87,-.5},{1,0},{.87,.5},{.5,.87},{0,1},{-.5,.87},{-.87,.5}},
  fuse={{-.78,-1},{.78,-1},{1,-.65},{1,.65},{.78,1},{-.78,1},{-1,.65},{-1,-.65}},
  plaza={{-.85,-1},{.85,-1},{1,-.8},{1,.8},{.85,1},{-.85,1},{-1,.8},{-1,-.8}},
  port={{-.9,-1},{.9,-1},{1,-.65},{1,.65},{.72,1},{-.9,1},{-1,.8},{-1,-.8}},
 }
 local out={};for _,q in ipairs(shapes[e.Shape]) do table.insert(out,V(q[1]*x,0,q[2]*z)) end;return out
end
local function triangle(s,p,a,b,c,thickness,color,collide,name)
 local ab,ac,bc=b-a,c-a,c-b
 if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
 elseif ac:Dot(ac)>bc:Dot(bc) then a,b=b,a end
 ab,ac,bc=b-a,c-a,c-b
 local right=ac:Cross(ab).Unit;local back=bc.Unit;local up=bc:Cross(right).Unit
 local height=math.abs(ab:Dot(up))
 for i,info in ipairs({{(a+b)/2,right,back,math.abs(ab:Dot(back))},{(a+c)/2,-right,-back,math.abs(ac:Dot(back))}}) do
  if info[4]>.005 then
   local q=info[1];local o=part(s,p,name,q.X,q.Y,q.Z,thickness,height,info[4],color,collide,nil,nil,"WedgePart")
   o.CFrame=CFrame.fromMatrix(q,info[2],up,info[3]);o:SetAttribute("HABGroundV16",true)
  end
 end
end
local function inside(poly,x,z,margin)
 local yes=false;local j=#poly
 for i,a in ipairs(poly) do
  local b=poly[j]
  if (a.Z>z)~=(b.Z>z) and x<(b.X-a.X)*(z-a.Z)/(b.Z-a.Z)+a.X then yes=not yes end
  local edge=b-a;local q=V(x,0,z)-a;local t=math.clamp(q:Dot(edge)/edge:Dot(edge),0,1)
  if (q-edge*t).Magnitude<(margin or 0) then return false end
  j=i
 end
 return yes
end
local function foundation(s,m)
 local e=s.Entry;local ground=folder(m,"Arena foundation","Model")
 local ref=part(s,m,"Floor",0,-2,0,e.W,4,e.D,e.Ground,false);ref.Transparency=1;ref.CastShadow=false;m.PrimaryPart=ref
 for i,a in ipairs(s.Polygon) do
  local b=s.Polygon[i%#s.Polygon+1]
  -- The dark lower shell ends below the colored floor: no coplanar surfaces.
  triangle(s,ground,V(0,-2.48,0),a-V(0,2.48,0),b-V(0,2.48,0),4.6,ink,false,"Bold foundation")
  triangle(s,ground,V(0,-1.4,0),a-V(0,1.4,0),b-V(0,1.4,0),2.8,e.Ground,true,"Continuous floor")
  beam(s,ground,"Perimeter wall",a+V(0,1.8,0),b+V(0,1.8,0),1.6,3.6,ink,true)
  beam(s,ground,"Colored perimeter cap",a+V(0,3.62,0),b+V(0,3.62,0),1.7,.18,e.Accent,false)
  local boundary=beam(s,ground,"Arena safety boundary",a+V(0,34,0),b+V(0,34,0),1,68,ink,true)
  boundary.Transparency=1;boundary.CastShadow=false;boundary:SetAttribute("HABBoundaryV16",true)
 end
end

local Layouts={}
function Layouts.Orbital(s,p)
 local e=s.Entry
 road(s,p,0,0,184,120,R(124,145,178))
 road(s,p,0,0,26,178,ink:Lerp(e.Ground,.65));road(s,p,0,0,202,24,ink:Lerp(e.Ground,.65))
 local deck=terrace(s,p,"Reactor promenade",0,0,42,58,8,"Z",40,R(164,184,212))
 bomb(s,deck,0,17,0,14,e.Accent);disc(s,deck,"Reactor socket",0,8.6,0,19,1.2,ink,false)
 for _,k in ipairs({-1,1}) do
  building(s,p,k<0 and "AIRLOCK 01" or "AIRLOCK 02",k*70,-46,28,25,17,R(169,183,213),e.Trim)
  cover(s,p,k*63,30,30,10,e.Trim,5)
  disc(s,p,"Landing ring",k*61, .025,68,19,.04,ink,false)
  disc(s,p,"Landing surface",k*61,.055,68,17,.03,e.Accent,false)
  for j=-1,1 do detail(s,p,"Runway bar",k*74,.06,j*17,18,.08,.8,paper) end
 end
 sign(s,p,"FUSE REACTOR",0,17,-88,33,6,e.Trim)
end
function Layouts.Pirate(s,p)
 local e=s.Entry
 road(s,p,32,0,34,151,R(244,218,166));road(s,p,0,54,173,23,R(244,218,166))
 local ship=terrace(s,p,"Bomb brigantine",-32,-4,38,70,8,"Z",38,R(185,126,85))
 for k=-3,3 do detail(s,ship,"Deck plank seam",-32+k*4,8.05,-4,.18,.03,68,ink:Lerp(R(185,126,85),.7)) end
 detail(s,ship,"Mast",-32,18,-11,1.4,23,1.4,ink)
 detail(s,ship,"Cream sail",-32,22,-11,22,14,.5,paper)
 bomb(s,ship,-32,22,-10.55,8,e.Accent)
 sign(s,ship,"FUSE & SAIL",-32,11,30,31,4,e.Accent)
 building(s,p,"TREASURE",59,-46,31,25,15,R(185,134,94),e.Trim)
 for _,q in ipairs({{62,18},{69,55},{-80,-46},{-79,47}}) do tree(s,p,q[1],q[2],"palm",1.1) end
 cover(s,p,57,21,22,10,e.Trim,4.8)
 crate(s,p,18,-58,10,e.Accent);crate(s,p,83,17,11,e.Accent)
 plinth(s,p,58,58,14,1.8,e.Trim);bomb(s,p,58,7.6,58,10,gold)
end
function Layouts.Neon(s,p)
 local e=s.Entry
 road(s,p,0,0,190,34,R(106,118,155));road(s,p,0,0,31,172,R(106,118,155))
 terrace(s,p,"Crosstown skywalk",0,-28,76,26,7,"X",42,R(168,175,216))
 for _,q in ipairs({{-61,-57,"POP FUSE",R(165,132,214)},{61,-57,"BOMB MART",R(92,175,191)},{-61,52,"DODGE CLUB",R(218,129,176)},{61,52,"QUICK FUSE",R(139,161,218)}}) do
  building(s,p,q[3],q[1],q[2],31,27,19,q[4],e.Trim)
 end
 for _,k in ipairs({-1,1}) do
  cover(s,p,k*35,45,9,19,e.Accent,4.5)
  detail(s,p,"Street center marking",k*62,.055,0,19,.08,1.1,gold)
 end
 bomb(s,p,0,21,-45,11,e.Accent)
 detail(s,p,"Station sign support",0,12,-45,1,24,1,ink)
 sign(s,p,"NEON LINE",0,15,-43,22,4,e.Trim)
end
function Layouts.Emerald(s,p)
 local e=s.Entry
 road(s,p,0,16,30,158,R(167,197,149));road(s,p,0,20,160,24,R(167,197,149))
 terrace(s,p,"Temple terrace",0,-45,66,32,8,"X",38,R(204,215,174))
 local temple=building(s,p,"THE FIRST FUSE",0,-82,37,19,18,R(177,192,151),e.Trim)
 bomb(s,temple,0,29,-82,13,e.Accent)
 for _,k in ipairs({-1,1}) do
  local g=cover(s,p,k*48,24,18,22,R(164,190,139),5)
  detail(s,g,"Ancient gold inlay",k*48,5.15,24,13,.1,17,gold)
  tree(s,p,k*68,-5,"garden",1)
  tree(s,p,k*48,70,"garden",1.15)
  block(s,p,"Temple arch pillar",k*25,7,70,4,14,4,ink)
 end
 detail(s,p,"Temple arch header",0,14.4,70,54,2.8,5,R(185,204,159))
 sign(s,p,"EMERALD RUINS",0,14.5,73,38,5,e.Accent)
 plinth(s,p,0,17,15,1.2,e.Trim);bomb(s,p,0,6,17,8,e.Accent)
end
function Layouts.Sky(s,p)
 local e=s.Entry
 road(s,p,0,0,185,28,R(213,223,179));road(s,p,0,0,28,166,R(213,223,179))
 local deck=terrace(s,p,"Bloom terrace",0,-2,58,34,7,"X",34,R(232,233,209))
 disc(s,deck,"Flower fountain base",0,7.8,-2,14,1.6,ink,false)
 disc(s,deck,"Fountain blue top",0,8.65,-2,12.7,.15,e.Accent,false)
 bomb(s,deck,0,14,-2,9,e.Trim)
 for _,q in ipairs({{-57,-56},{57,-56},{-57,56},{57,56}}) do
  local g=cover(s,p,q[1],q[2],20,16,R(97,164,106),3.6)
  tree(s,g,q[1],q[2],"pink",1)
 end
 for _,k in ipairs({-1,1}) do
  cover(s,p,k*31,51,8,21,e.Trim,3.8)
  detail(s,p,"Garden pergola post",k*12,7,-66,1.2,14,1.2,ink)
 end
 detail(s,p,"Pergola canopy",0,14.5,-66,29,1.5,16,paper)
 for i=-3,3 do detail(s,p,"Pergola rafter",i*4,15.5,-66,1,1,18,e.Accent) end
 sign(s,p,"SKY GARDEN",0,10,-57,26,5,e.Trim)
end
function Layouts.Ember(s,p)
 local e=s.Entry
 road(s,p,0,8,32,168,R(170,142,142));road(s,p,0,13,196,26,R(170,142,142))
 terrace(s,p,"Fuse battlement",0,-46,92,28,10,"X",43,R(196,164,147))
 local keep=building(s,p,"EMBER KEEP",0,-85,42,20,23,R(179,127,112),e.Accent)
 bomb(s,keep,0,36,-85,16,e.Trim)
 for _,k in ipairs({-1,1}) do
  local tower=outlineBox(s,p,"Outlined turret",k*72,55,23,23,13,R(174,133,131))
  for i=-1,1 do detail(s,tower,"Castle crenel",k*72+i*8,15.3,55,5,4,23,e.Accent) end
  cover(s,p,k*36,20,19,10,e.Accent,5)
  cover(s,p,k*77,-9,17,15,R(163,125,130),5)
 end
 sign(s,p,"KEEP YOUR COOL",0,11,70,30,5,e.Accent)
end
function Layouts.Clockwork(s,p)
 local e=s.Entry
 road(s,p,0,0,212,26,R(166,173,176));road(s,p,-35,0,28,161,R(166,173,176))
 terrace(s,p,"Inspection conveyor",31,0,35,65,8,"Z",38,R(180,186,178))
 for z=-24,24,8 do detail(s,p,"Conveyor marking",31,8.05,z,29,.06,.8,gold) end
 local forge=building(s,p,"CLOCKWORK",-67,-47,35,26,19,R(112,164,163),e.Accent)
 for _,x in ipairs({-77,-57}) do disc(s,forge,"Exhaust stack",x,26,-50,6,15,ink,false);disc(s,forge,"Stack ring",x,33,-50,7,1,e.Trim,false) end
 plinth(s,p,-43,25,23,5,e.Accent);bomb(s,p,-43,14,25,16,e.Trim)
 for _,q in ipairs({{84,-36},{86,31},{-83,48}}) do crate(s,p,q[1],q[2],14,e.Accent) end
 cover(s,p,-7,-34,12,21,e.Trim,5);cover(s,p,-5,43,12,20,e.Trim,5)
 sign(s,p,"MIND THE FUSE",31,14,-48,27,4,e.Accent)
end
function Layouts.Frost(s,p)
 local e=s.Entry
 road(s,p,0,10,32,163,R(175,210,227));road(s,p,0,20,197,26,R(175,210,227))
 terrace(s,p,"Lodge balcony",0,-48,68,27,8,"X",38,R(194,216,230))
 building(s,p,"FROSTFALL LODGE",0,-82,38,20,19,R(136,178,206),e.Trim)
 for _,k in ipairs({-1,1}) do
  building(s,p,k<0 and "COCOA" or "FUSE SHOP",k*66,49,30,25,14,R(183,159,177),paper)
  tree(s,p,k*84,-28,"snow",1.2)
  cover(s,p,k*40,13,19,9,R(182,215,234),4.2)
 end
 plinth(s,p,0,23,20,1.6,e.Accent)
 disc(s,p,"Frozen fountain",0,1.73,23,18,.15,R(143,213,240),false)
 bomb(s,p,0,8,23,11,e.Trim)
 for _,q in ipairs({{-39,72},{39,72},{-47,-79},{47,-79}}) do tree(s,p,q[1],q[2],"snow",.8) end
end
function Layouts.Crystal(s,p)
 local e=s.Entry
 road(s,p,0,0,135,24,R(174,165,205))
 terrace(s,p,"Prism causeway",0,0,34,48,7,"Z",34,R(193,191,225))
 for _,q in ipairs({{-52,-44,20},{49,-43,23},{-55,32,17},{53,34,19},{-24,-76,15},{23,74,13}}) do crystal(s,p,q[1],q[2],q[3],e.Trim:Lerp(e.Accent,(q[3]-13)/13)) end
 cover(s,p,-46,0,12,19,R(162,144,198),5);cover(s,p,46,0,12,19,R(162,144,198),5)
 bomb(s,p,0,14,0,10,e.Accent)
 sign(s,p,"CRYSTAL CAVERN",0,17,-77,38,6,e.Accent)
end
function Layouts.Sunset(s,p)
 local e=s.Entry
 road(s,p,35,0,27,170,R(204,177,140));road(s,p,-30,42,178,25,R(204,177,140))
 local quay=terrace(s,p,"Sunset loading quay",-39,0,37,90,8,"Z",36,R(207,161,112))
 for z=-38,38,8 do detail(s,quay,"Quay plank seam",-39,8.04,z,33,.04,.18,ink:Lerp(e.Ground,.6)) end
 building(s,p,"FUSE FREIGHT",69,-47,41,28,19,R(103,163,181),e.Accent)
 for _,q in ipairs({{7,38},{93,-7},{7,-57},{-92,-39},{-91,39}}) do crate(s,p,q[1],q[2],q[1]==7 and 15 or 12,e.Trim) end
 cover(s,p,5,68,27,8,e.Accent,5)
 plinth(s,p,-39,-11,18,1.5,e.Accent)
 bomb(s,quay,-39,17,-11,12,e.Accent)
 detail(s,p,"Harbor crane column",92,20,-67,4,40,4,ink)
 detail(s,p,"Harbor crane boom",68,39,-67,52,3,3,e.Accent)
 detail(s,p,"Crane cable",47,26,-67,.35,24,.35,ink)
 bomb(s,p,47,13,-67,7,e.Trim)
end
function Layouts.Sunstone(s,p)
 local e=s.Entry
 road(s,p,0,6,29,182,R(243,215,171));road(s,p,0,31,180,24,R(243,215,171))
 terrace(s,p,"Merchant terrace",47,-3,30,62,8,"Z",37,R(239,207,158))
 building(s,p,"SUNSTONE EXCHANGE",-47,-69,42,24,17,R(207,152,125),e.Trim)
 stall(s,p,"FUSE FRUIT",-57,6,20,e.Accent)
 stall(s,p,"SPARK SPICE",-57,59,20,e.Trim)
 plinth(s,p,-4,12,18,1.8,e.Accent);bomb(s,p,-4,8,12,11,e.Trim)
 tree(s,p,-81,-27,"palm",1.1);tree(s,p,78,55,"palm",1.1)
 for _,q in ipairs({{1,-57},{75,-55},{-12,72}}) do crate(s,p,q[1],q[2],9,e.Trim) end
 sign(s,p,"RUN THE MARKET",47,16,-3,26,5,e.Accent)
end
function Layouts.Stardust(s,p)
 local e=s.Entry
 road(s,p,0,15,33,174,R(199,173,212));road(s,p,0,15,210,30,R(199,173,212))
 local stage=terrace(s,p,"Starburst stage",0,-45,72,29,8,"X",38,R(222,184,220))
 for _,x in ipairs({-29,29}) do detail(s,stage,"Stage arch post",x,18,-56,2,22,2,ink) end
 detail(s,stage,"Stage arch header",0,29,-56,60,2,2,e.Trim)
 bomb(s,stage,0,20,-56,15,e.Accent)
 sign(s,stage,"THE BIG BOOM",0,27,-53,39,5,e.Trim)
 stall(s,p,"POP BOMBS",-64,43,24,e.Accent);stall(s,p,"PRIZE FUSE",64,43,24,e.Trim)
 for _,k in ipairs({-1,1}) do
  disc(s,p,"Ticket island",k*70,1.5,-10,21,3,ink,true)
  disc(s,p,"Ticket island enamel",k*70,3.05,-10,20,.13,e.Trim,false)
  bomb(s,p,k*70,10,-10,12,e.Accent)
  cover(s,p,k*33,68,14,13,e.Accent,4.2)
 end
end
function Layouts.Fuse(s,p)
 local e=s.Entry
 road(s,p,0,0,164,27,R(180,191,185));road(s,p,-46,0,24,198,R(180,191,185));road(s,p,46,0,24,198,R(180,191,185))
 local assembly=terrace(s,p,"Fuse assembly runway",0,0,29,102,8,"Z",37,R(206,203,163))
 for z=-42,42,12 do detail(s,assembly,"Assembly dashed lane",0,8.06,z,1.3,.08,5,gold) end
 for _,q in ipairs({{-72,-50,"FUSE CO.",15},{72,-50,"SPARK LAB",15},{-72,47,"PACKING",9},{72,47,"QUALITY",9}}) do
  building(s,p,q[3],q[1],q[2],25,27,q[4],R(106,163,154),e.Accent)
 end
 for _,x in ipairs({-69,69}) do
  plinth(s,p,x,0,16,4,e.Accent);bomb(s,p,x,10.5,0,12,e.Trim)
 end
 sign(s,p,"FUSEWORKS",0,16,-57,25,5,e.Accent)
end
function Layouts.Detonator(s,p)
 local e=s.Entry
 road(s,p,0,0,180,29,R(212,217,234));road(s,p,0,0,27,147,R(212,217,234))
 local deck=terrace(s,p,"Detonator pavilion",0,0,32,36,6,"X",30,R(226,228,244))
 disc(s,deck,"Button housing",0,6.6,0,11,1.2,ink,false)
 disc(s,deck,"Big red button",0,8,0,9.5,2,R(250,102,120),false)
 bomb(s,deck,0,16,0,10,e.Accent)
 for _,q in ipairs({{-58,-44},{58,-44},{-58,44},{58,44}}) do
  cover(s,p,q[1],q[2],22,16,R(134,184,156),3.6)
  tree(s,p,q[1],q[2],"garden",.9)
 end
 building(s,p,"DETONATOR HQ",0,-66,34,18,16,R(153,175,221),e.Trim)
 for _,k in ipairs({-1,1}) do cover(s,p,k*29,54,9,17,e.Trim,4.2) end
 sign(s,p,"KEEP IT MOVING",0,10,65,30,5,e.Accent)
end
function Layouts.Payload(s,p)
 local e=s.Entry
 road(s,p,0,18,232,30,R(182,192,194));road(s,p,0,0,31,173,R(182,192,194))
 terrace(s,p,"Payload loading bridge",0,-23,78,28,9,"X",43,R(203,201,178))
 for _,q in ipairs({{-91,-58,32,20,e.Trim},{76,-60,44,22,e.Accent},{-77,58,45,20,e.Accent},{77,48,34,25,e.Trim}}) do
  local g=outlineBox(s,p,"Freight container",q[1],q[2],q[3],q[4],12,q[5])
  for k=-2,2 do detail(s,g,"Container panel",q[1]+k*q[3]/6,6,q[2]+q[4]/2+.08,.35,10,.15,ink:Lerp(q[5],.5)) end
  sign(s,g,"FUSE CARGO",q[1],8,q[2]+q[4]/2+.3,q[3]-3,3.8,q[5])
 end
 crate(s,p,-34,32,13,e.Trim);crate(s,p,35,48,15,e.Accent)
 detail(s,p,"Gantry column",-29,20,-76,3,40,3,ink)
 detail(s,p,"Gantry column",29,20,-76,3,40,3,ink)
 detail(s,p,"Gantry top",0,40,-76,64,4,5,e.Accent)
 detail(s,p,"Crane cable",0,25,-76,.35,28,.35,ink)
 bomb(s,p,0,12,-76,12,e.Trim)
 sign(s,p,"PAYLOAD PORT",0,36,-73,43,6,e.Accent)
end
local LayoutKeys={"Orbital","Pirate","Neon","Emerald","Sky","Ember","Clockwork","Frost","Crystal","Sunset","Sunstone","Stardust","Fuse","Detonator","Payload"}

-- Theme-specific silhouettes and restrained surface detail. These are authored
-- around the large, already-clear routes; small trim never becomes collision.
local function roof(s,p,x,z,w,d,base,rise,color)
 for _,side in ipairs({-1,1}) do
  for layer=0,1 do
   local rw,rd=w+2.5-layer*.55,d+2.5-layer*.55
   part(s,p,layer==0 and "Roof ink edge" or "Pitched roof",x,base+rise/2+layer*.22,z+side*rd/4,rw,rise,rd/2,layer==0 and ink or color,false,nil,CFrame.Angles(0,side<0 and 0 or math.pi,0),"WedgePart")
  end
 end
 beam(s,p,"Roof ridge",V(x-w/2-1,base+rise+.28,z),V(x+w/2+1,base+rise+.28,z),.6,.6,ink,false)
end
local function gear(s,p,x,y,z,radius,color)
 -- A real 3D cog outline with twelve broad teeth, not a texture billboard.
 local face=part(s,p,"Gear hub",x,y,z,2,radius*2,radius*2,ink,false,nil,CFrame.Angles(0,math.pi/2,0));face.Shape=Enum.PartType.Cylinder
 local inner=part(s,p,"Gear enamel",x,y,z+.08,2.2,radius*1.62,radius*1.62,color,false,nil,CFrame.Angles(0,math.pi/2,0));inner.Shape=Enum.PartType.Cylinder
 for i=0,11 do local a=i*math.pi/6
  detail(s,p,"Cog tooth",x+math.cos(a)*radius,y+math.sin(a)*radius,z,3.6,4.5,2.6,ink,nil,CFrame.Angles(0,0,a-math.pi/2))
 end
 local axle=part(s,p,"Gear axle",x,y,z+.15,3,radius*.45,radius*.45,ink,false,nil,CFrame.Angles(0,math.pi/2,0));axle.Shape=Enum.PartType.Cylinder
end
local function flowerbed(s,p,x,z,w,d,c)
 local bed=cover(s,p,x,z,w,d,R(101,161,116),1.1)
 for i=-2,2 do
  local bx=x+i*w/6
  detail(s,bed,"Flower stem",bx,1.8,z,.25,1.4,.25,ink)
  ball(s,bed,"Round blossom",bx,2.7,z,1.8,c,false)
  ball(s,bed,"Flower center",bx,3.1,z+.4,.65,gold,false)
 end
end
local function arch(s,p,x,z,w,h,color)
 for _,side in ipairs({-1,1}) do
  block(s,p,"Arch pillar",x+side*w/2,h/2,z,3.4,h,4.8,ink)
  detail(s,p,"Pillar enamel",x+side*w/2,h/2,z,2.7,h-.6,5,color)
 end
 detail(s,p,"Arch lintel",x,h,z,w+4,3.8,5.6,ink)
 detail(s,p,"Arch colored inset",x,h+.3,z,w+3.3,2.9,5.9,color)
end
local function themes(s,p,key)
 local e=s.Entry
 if key=="Orbital" then
  -- A wide radar dish at the far edge and soft, rounded airlock roofs.
  for _,x in ipairs({-70,70}) do
   local cap=ball(s,p,"Rounded pressure dome",x,18,-46,25,e.Trim,false);cap.Size=V(27,9,24)
   for _,offset in ipairs({-8,8}) do detail(s,p,"Airlock rib",x+offset,15,-32,1.2,13,1,paper) end
  end
  block(s,p,"Radar pedestal",0,7,-84,4,14,4,ink)
  local dish=ball(s,p,"Radar dish",0,15,-84,23,paper,false);dish.Size=V(25,6,25)
  detail(s,p,"Radar antenna",0,21,-84,.75,13,.75,e.Accent);ball(s,p,"Radar tip",0,27,-84,2.4,e.Trim,false)
  for _,x in ipairs({-31,31}) do
   for _,z in ipairs({-63,63}) do detail(s,p,"Airlock direction tile",x,.04,z,4,.06,12,e.Accent) end
  end
 elseif key=="Pirate" then
  for _,side in ipairs({-1,1}) do
   detail(s,p,"Ship gunwale",-32+side*18,11.6,-4,1.5,1.7,69,ink)
   for z=-26,18,22 do
    local ring=part(s,p,"Brass porthole",-32+side*19.1,5.4,z,.45,4.6,4.6,gold,false);ring.Shape=Enum.PartType.Cylinder
    local pane=part(s,p,"Porthole glass",-32+side*19.4,5.4,z,.25,3.4,3.4,ink,false);pane.Shape=Enum.PartType.Cylinder
   end
  end
  roof(s,p,59,-46,31,25,16.2,6,e.Trim)
  for _,q in ipairs({{74,64},{-94,-18},{-85,70}}) do
   local rock=ball(s,p,"Beach boulder",q[1],1.6,q[2],8,R(198,180,139),false);rock.Size=V(10,3.3,8)
  end
  -- Native water inlays are flush walkable visual sandbars, never kill pits.
  disc(s,p,"Tidal pool ink",78,.025,-1,18,.035,ink,false)
  disc(s,p,"Tidal blue",78,.05,-1,16.9,.03,e.Trim,false)
 elseif key=="Neon" then
  for _,q in ipairs({{-61,-57,31,27,19,10},{61,-57,31,27,19,16},{-61,52,31,27,19,6},{61,52,31,27,19,9}}) do
   outlineBox(s,p,"City roof tower",q[1],q[2],q[3]*.62,q[4]*.62,q[5]+q[6],e.Trim)
   for y=22,q[5]+q[6]-2,5 do
    for _,xx in ipairs({-5,5}) do detail(s,p,"Tower lit window",q[1]+xx,y,q[2]+q[4]*.315,3,2.5,.2,paper) end
   end
  end
  for _,z in ipairs({-30,24}) do
   for x=-10,10,5 do detail(s,p,"Pedestrian crossing",x,.045,z,3,.06,8,paper) end
  end
  for _,x in ipairs({-98,98}) do
   detail(s,p,"Street lamp",x,7,-7,.7,14,.7,ink)
   detail(s,p,"Lamp arm",x-3,14,-7,6,.8,.8,ink)
   detail(s,p,"Lamp lens",x-5,13.6,-7,3,.45,2,paper)
  end
 elseif key=="Emerald" then
  -- The ruin is an open garden temple, with broken-corner stonework.
  roof(s,p,0,-82,37,19,19.4,5,e.Trim)
  for _,x in ipairs({-15,15}) do detail(s,p,"Temple column",x,10,-71,3,17,3,paper:Lerp(e.Ground,.22)) end
  for _,x in ipairs({-48,48}) do
   disc(s,p,"Relic socket",x,5.7,24,11,1.2,ink,false)
   detail(s,p,"Carved emerald obelisk",x,10.5,24,4.7,9,4.7,e.Accent,nil,CFrame.Angles(0,math.pi/4,0))
   ball(s,p,"Relic pearl",x,16,24,4,gold,false)
  end
  flowerbed(s,p,-70,52,11,7,R(245,185,119));flowerbed(s,p,70,52,11,7,R(245,185,119))
  for _,q in ipairs({{-68,-70},{67,-74}}) do
   detail(s,p,"Broken relic slab",q[1],2,q[2],13,4,9,R(166,187,145),nil,CFrame.Angles(0,.28,0))
  end
 elseif key=="Sky" then
  for _,q in ipairs({{-57,-56},{57,-56},{-57,56},{57,56}}) do
   disc(s,p,"Round lawn inset",q[1],.02,q[2],37,.03,R(114,183,121),false)
  end
  flowerbed(s,p,-23,-51,11,7,e.Trim);flowerbed(s,p,23,-51,11,7,e.Trim)
  flowerbed(s,p,-70,28,17,7,e.Trim);flowerbed(s,p,70,28,17,7,e.Trim)
  for _,x in ipairs({-72,72}) do
   block(s,p,"Garden bench seat",x,1.7,-21,12,3.4,4,paper)
   detail(s,p,"Garden bench back",x,5,-23,12,4,.7,e.Accent)
  end
 elseif key=="Ember" then
  for _,x in ipairs({-17,17}) do
   disc(s,p,"Keep turret shaft",x,17,-86,14,34,ink,false)
   disc(s,p,"Keep turret enamel",x,17.2,-86,12.5,33,R(182,134,119),false)
   disc(s,p,"Turret crown",x,34,-86,16,2,ink,false)
   for i=0,5 do local a=i*math.pi/3
    detail(s,p,"Crown battlement",x+math.cos(a)*6.2,36.4,-86+math.sin(a)*6.2,3.8,4.7,3.8,e.Accent)
   end
  end
  for _,x in ipairs({-72,72}) do
   sign(s,p,"BOMB GUARD",x,9,67,19,4,e.Accent)
   detail(s,p,"Keep banner pole",x,22,55,.6,17,.6,ink)
   detail(s,p,"Keep banner",x+4,26,55,8,10,.4,e.Trim)
  end
  for x=-34,34,17 do detail(s,p,"Battlement crenel",x,14,-59,8,6,3,R(184,141,129)) end
 elseif key=="Clockwork" then
  gear(s,p,-67,25,-32,12,e.Accent)
  gear(s,p,-43,16,26,10,e.Trim)
  for _,x in ipairs({-7,66}) do
   detail(s,p,"Overhead pipe riser",x,14,-16,2.4,28,2.4,ink)
   detail(s,p,"Pipe enamel",x,14,-16,1.8,27.5,1.8,e.Accent)
  end
  beam(s,p,"Overhead pipe",V(-7,28,-16),V(66,28,-16),2.4,2.4,e.Accent,false)
  for _,q in ipairs({{84,-36},{86,31}}) do
   disc(s,p,"Valve pedestal",q[1],14,q[2],8,3,ink,false)
   gear(s,p,q[1],18,q[2],5,e.Trim)
  end
 elseif key=="Frost" then
  roof(s,p,0,-82,38,20,20.3,7,paper)
  for _,x in ipairs({-66,66}) do
   roof(s,p,x,49,30,25,15.4,8,paper)
   detail(s,p,"Cottage chimney",x-8,24,47,4,13,4,ink)
   detail(s,p,"Chimney snow cap",x-8,30.7,47,5,.6,5,paper)
   for i=-2,2 do detail(s,p,"Lodge roof icicle",x+i*5,16.5,63.5,.5,2+(i%2),.5,e.Accent) end
  end
  for _,q in ipairs({{-91,51},{92,43},{-39,-61},{39,-61}}) do
   local b=ball(s,p,"Sculpted snow bank",q[1],.8,q[2],11,paper,false);b.Size=V(15,1.7,8)
  end
 elseif key=="Crystal" then
  -- Cave shoulders live along the perimeter; the center stays open to chase.
  for _,q in ipairs({{-66,-62,13},{-80,-19,17},{-76,56,13},{64,-60,18},{78,4,15},{65,65,13}}) do
   part(s,p,"Cave shoulder",q[1],q[3]/2,q[2],15,q[3],13,R(103,109,154),true,nil,CFrame.Angles(0,.35,0))
   detail(s,p,"Faceted rock cap",q[1],q[3]-1,q[2],13,4,11,R(145,142,191),nil,CFrame.Angles(.15,.35,.1))
  end
  for _,x in ipairs({-12,12}) do crystal(s,p,x,-77,15,e.Trim) end
  disc(s,p,"Prismatic pool edge",-45,.025,56,16,.04,ink,false)
  disc(s,p,"Prismatic pool",-45,.05,56,14.7,.035,e.Trim,false)
 elseif key=="Sunset" then
  roof(s,p,69,-47,41,28,20.4,7,e.Accent)
  for _,z in ipairs({-37,-19,0,19,37}) do
   for _,x in ipairs({-59,-19}) do disc(s,p,"Quay mooring post",x,4,z,3,8,ink,false);disc(s,p,"Mooring brass cap",x,8.2,z,4,.4,e.Accent,false) end
  end
  for _,x in ipairs({-100,-82}) do
   detail(s,p,"Pier bollard",x,2,2,3,4,3,ink)
   detail(s,p,"Pier cap",x,4.2,2,5,.5,4,e.Accent)
  end
  for x=-105,49,14 do detail(s,p,"Quayside plank seam",x,.04,82,.17,.05,18,ink:Lerp(e.Ground,.7)) end
 elseif key=="Sunstone" then
  roof(s,p,-47,-69,42,24,18.3,6,e.Accent)
  for _,x in ipairs({-62,-32}) do
   disc(s,p,"Bazaar tower",x,15,-69,10,30,ink,false)
   disc(s,p,"Bazaar tower enamel",x,15,-69,9,29.5,R(230,179,129),false)
   local dome=ball(s,p,"Bazaar dome",x,30,-69,13,e.Trim,false);dome.Size=V(13,9,13)
   ball(s,p,"Dome finial",x,36,-69,2,gold,false)
  end
  arch(s,p,-5,75,26,14,e.Accent)
  for _,z in ipairs({-18,15}) do
   detail(s,p,"Terrace rug border",47,8.05,z,25,.05,19,ink)
   detail(s,p,"Terrace patterned rug",47,8.09,z,23,.035,17,e.Accent)
   detail(s,p,"Rug diamond",47,8.12,z,8,.03,8,e.Trim,nil,CFrame.Angles(0,math.pi/4,0))
  end
 elseif key=="Stardust" then
  -- Compact ferris-wheel landmark at the far edge; no moving collision.
  local cx,cy,cz=-70,22,-70
  for _,side in ipairs({-1,1}) do beam(s,p,"Wheel support",V(cx+side*13,0,cz+6),V(cx,cy,cz),2.5,2.5,ink,true) end
  for i=0,11 do
   local a=i*math.pi/6;local b=(i+1)*math.pi/6
   local q=V(cx+math.cos(a)*17,cy+math.sin(a)*17,cz)
   local r=V(cx+math.cos(b)*17,cy+math.sin(b)*17,cz)
   beam(s,p,"Ferris rim",q,r,1.5,1.5,e.Trim,false)
   beam(s,p,"Ferris spoke",V(cx,cy,cz),q,.45,.45,paper,false)
   if i%2==0 then detail(s,p,"Round gondola",q.X,q.Y-2,q.Z,6,4,5,e.Accent);detail(s,p,"Gondola roof",q.X,q.Y+.4,q.Z,6.7,.65,5.7,ink) end
  end
  bomb(s,p,cx,cy,cz+2.5,8,e.Trim)
  for _,x in ipairs({-64,64}) do roof(s,p,x,43,26,10,12.5,8,x<0 and e.Accent or e.Trim) end
  for _,x in ipairs({-21,21}) do detail(s,p,"Midway bunting pole",x,14,39,.6,28,.6,ink) end
  beam(s,p,"Bunting rope",V(-21,27,39),V(21,27,39),.3,.3,ink,false)
  for i=-3,3 do detail(s,p,"Bunting pennant",i*5,25,39,3.4,3.5,.2,i%2==0 and e.Trim or e.Accent) end
 elseif key=="Fuse" then
  for _,x in ipairs({-72,72}) do
   for _,z in ipairs({-50,47}) do
    local front=z>0
    roof(s,p,x,z,25,27,front and 10.3 or 16.3,front and 4 or 5,e.Accent)
    detail(s,p,"Factory exhaust",x-7,front and 16 or 24,z-7,4,front and 8 or 14,4,ink)
    detail(s,p,"Exhaust enamel",x-7,front and 16 or 24,z-7,3.3,front and 7.4 or 13.4,3.3,e.Trim)
   end
  end
  for _,x in ipairs({-69,69}) do
   gear(s,p,x,10,1,8,e.Accent)
  end
  for _,z in ipairs({-24,24}) do
   for _,side in ipairs({-1,1}) do detail(s,p,"Runway gantry post",side*13,17,z,.8,18,.8,ink) end
   detail(s,p,"Runway gantry",0,26,z,27,1.5,2,e.Trim)
   detail(s,p,"Gantry warning stripe",0,26.8,z,14,.15,2.1,e.Accent)
  end
 elseif key=="Detonator" then
  for _,q in ipairs({{-58,-44},{58,-44},{-58,44},{58,44}}) do disc(s,p,"Rounded park pocket",q[1],.02,q[2],35,.035,R(152,190,162),false) end
  roof(s,p,0,-66,34,18,17.4,5,e.Trim)
  flowerbed(s,p,-79,6,11,7,R(245,159,192));flowerbed(s,p,79,6,11,7,R(245,159,192))
  for _,x in ipairs({-80,80}) do
   detail(s,p,"Plaza clock pole",x,9,-25,1,18,1,ink)
   local clock=part(s,p,"Round clock face",x,19,-25,.6,7,7,paper,false,nil,CFrame.Angles(0,math.pi/2,0));clock.Shape=Enum.PartType.Cylinder
   detail(s,p,"Clock hand",x,20,-24.5,.4,3,.2,ink)
   detail(s,p,"Clock hand",x+1,19,-24.5,2,.4,.2,ink)
  end
 elseif key=="Payload" then
  for _,q in ipairs({{-91,-58,32,20},{76,-60,44,22},{-77,58,45,20},{77,48,34,25}}) do
   for _,side in ipairs({-1,1}) do
    detail(s,p,"Container corner casting",q[1]+side*(q[3]/2-.6),6,q[2],1.2,12.5,q[4]+.3,ink)
   end
   for _,z in ipairs({-1,1}) do detail(s,p,"Container roof rail",q[1],12.4,q[2]+z*(q[4]/2-.7),q[3],.7,.7,paper) end
  end
  for _,x in ipairs({-29,29}) do
   for y=4,34,10 do detail(s,p,"Gantry caution band",x,y,-76,3.3,2.8,3.3,e.Accent) end
  end
  for _,z in ipairs({-5,29}) do
   for x=-96,96,24 do detail(s,p,"Port road chevron",x,.05,z,6,.06,1.5,gold,nil,CFrame.Angles(0,.45,0)) end
  end
 end
end

local function spawnClear(s,x,z)
 if not inside(s.Polygon,x,z,9) then return false end
 for _,o in ipairs(s.Solids) do
  if not o:GetAttribute("HABGroundV16") and not o:GetAttribute("HABBoundaryV16") then
   local localPoint=o.CFrame:PointToObjectSpace(V(x,2,z))
   -- Conservatively avoid all ramp footprints, cover and architecture; no
   -- world raycast is needed while models are detached in ServerStorage.
   if math.abs(localPoint.X)<o.Size.X/2+4 and math.abs(localPoint.Z)<o.Size.Z/2+4 and o.Position.Y+o.Size.Y/2>.2 then return false end
  end
 end
 for _,q in ipairs(s.SpawnPositions) do if (V(x,0,z)-q).Magnitude<13 then return false end end
 return true
end
local function spawns(s,m)
 local f=folder(m,"Spawns")
 for i=1,16 do
  local chosen
  local base=(i-1)*math.pi*2/16
  for _,radius in ipairs({.80,.73,.86,.65,.57,.49}) do
   for _,offset in ipairs({0,.055,-.055,.11,-.11,.17,-.17,.24,-.24,.30,-.30}) do
    local a=base+offset;local x=math.cos(a)*s.Entry.W*.5*radius;local z=math.sin(a)*s.Entry.D*.5*radius
    if spawnClear(s,x,z) then chosen=V(x,0,z);break end
   end
   if chosen then break end
  end
  assert(chosen,"No clear spawn sector "..i.." in "..s.Entry.Name)
  table.insert(s.SpawnPositions,chosen)
  local marker=part(s,f,string.format("Spawn%02d",i),chosen.X,.2,chosen.Z,4,.4,4,paper,false)
  marker.Transparency=1;marker.CastShadow=false;marker.CFrame=CFrame.lookAt(chosen+V(0,.2,0),V(0,.2,0))
  marker:SetAttribute("HABSpawnV16",true)
  disc(s,m,"Flush spawn rim",chosen.X,.025,chosen.Z,5.4,.04,ink:Lerp(s.Entry.Ground,.6),false)
  disc(s,m,"Flush spawn pad",chosen.X,.055,chosen.Z,4.7,.035,s.Entry.Ground:Lerp(paper,.35),false)
 end
end
function Builder.Build(name,parent,origin)
 local entry,index
 for i,e in ipairs(Catalog) do if e.Name==name then entry,index=e,i;break end end
 assert(entry,"Unknown HAB map: "..tostring(name))
 assert(parent==nil or typeof(parent)=="Instance","Build parent must be an Instance or nil")
 origin=origin or V(0,0,0);assert(typeof(origin)=="Vector3","Build origin must be Vector3")
 local model=folder(nil,name,"Model")
 local ok,err=pcall(function()
  model:SetAttribute("HABMapVersion",16);model:SetAttribute("HABWorldVersion",16);model:SetAttribute("DisplayName",name);model:SetAttribute("VotedMap",name)
  model:SetAttribute("NoJumpRequired",true);model:SetAttribute("RouteDescription",entry.Route)
  model:SetAttribute("MapWidth",entry.W);model:SetAttribute("MapDepth",entry.D)
  local s={Entry=entry,Solids={},Polygon=polygon(entry),SpawnPositions={}}
  foundation(s,model)
  local geometry=folder(model,"Themed architecture","Model")
  Layouts[LayoutKeys[index]](s,geometry)
  themes(s,geometry,LayoutKeys[index])
  spawns(s,model)
  model:SetAttribute("DeckCenter",V(s.Deck.X,s.Deck.Height,s.Deck.Z))
  model:SetAttribute("DeckAxis",s.Deck.Axis)
  local count=0;for _,d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") then count+=1 end end
  assert(count<=400,"Map part budget exceeded: "..name.." ("..count..")")
  model:SetAttribute("BasePartCount",count)
  -- PrimaryPart top is the anchor contract used by unmodified map voting.
  if origin.Magnitude>0 then model:PivotTo(model:GetPivot()+origin) end
 end)
 if not ok then model:Destroy();error("[HAB Maps V16 / "..name.."] "..tostring(err),2) end
 model.Parent=parent;return model
end
function Builder.BuildAll(parent)
 local staging=folder(nil,"MapLibrary")
 local ok,err=pcall(function() for _,e in ipairs(Catalog) do Builder.Build(e.Name,staging) end end)
 if not ok then staging:Destroy();error(err,2) end
 staging:SetAttribute("HABMapVersion",16);staging:SetAttribute("HABWorldVersion",16);staging.Parent=parent;return staging
end
function Builder.BuildArchive(options)
 options=options or {}
 local root=folder(nil,"HABMapsV16Staging")
 local ok,err=pcall(function()
  local maps=Builder.BuildAll(root)
  local previews=folder(root,"BombTagV6Previews")
  for _,m in ipairs(maps:GetChildren()) do local c=m:Clone();c.Parent=previews end
  local legacy=folder(root,"BombTagPreviewGalleryV5")
  for _,name in ipairs({"Sky Garden","Sunset Docks","Neon District","Crystal Cavern"}) do local c=maps:FindFirstChild(name):Clone();c.Parent=legacy end
  local active=folder(root,"Maps")
  local name=options.VotedMap or "Sunset Docks"
  local template=maps:FindFirstChild(name);assert(template,"Active voted map missing: "..tostring(name))
  local c=template:Clone();c.Name=options.MapName or "Sky Garden"
  local origin=options.Anchor or V(0,-27,-190)
  c:PivotTo(c:GetPivot()+origin);c:SetAttribute("DisplayName",name);c:SetAttribute("VotedMap",name);c.Parent=active
  for _,f in ipairs(root:GetChildren()) do f:SetAttribute("HABWorldVersion",16) end
 end)
 if not ok then root:Destroy();error("[HAB Maps V16 archive] "..tostring(err),2) end
 return root
end
return Builder
