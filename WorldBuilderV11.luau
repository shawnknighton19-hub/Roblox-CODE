--!nonstrict
-- HussWorld11. Staged clones only; never edits the running world or Lighting.
local B={}
local V,C,R,M=Vector3.new,CFrame.new,Color3.fromRGB,Enum.Material
local ink,white,gold=R(18,27,36),R(255,250,233),R(255,205,35)
local teal,pink=R(34,218,229),R(236,89,159)
local function group(parent,name,class) local o=Instance.new(class or 'Model');o.Name=name;o.Parent=parent;return o end
local function part(parent,name,x,y,z,w,h,d,color,solid,rot,class)
 local o=Instance.new(class or 'Part');o.Name=name;o.Size=V(w,h,d);o.CFrame=C(x,y,z)*(rot or CFrame.identity);o.Color=color;o.Material=M.SmoothPlastic
 o.Anchored=true;o.CanCollide=solid==true;o.CanTouch=false;o.CanQuery=o.CanCollide;o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth;o.Parent=parent;return o
end
local function beam(parent,name,a,b,w,h,color,solid)
 local p=(a+b)/2;local delta=b-a;local up=math.abs(delta.Unit.Y)>.99 and V(1,0,0) or V(0,1,0);return part(parent,name,p.X,p.Y,p.Z,w,h,delta.Magnitude,color,solid,CFrame.lookAt(a,b,up).Rotation)
end
local function ball(parent,name,x,y,z,size,color)
 local o=part(parent,name,x,y,z,size,size,size,color);o.Shape=Enum.PartType.Ball;return o
end
local function cylinder(parent,name,x,y,z,d,h,color,solid)
 local o=part(parent,name,x,y,z,h,d,d,color,solid,CFrame.Angles(0,0,math.pi/2));o.Shape=Enum.PartType.Cylinder;return o
end
local function ui(parent,class,props)
 local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o
end
local function rounded(parent,r) ui(parent,'UICorner',{CornerRadius=UDim.new(0,r)}) end
local function edge(parent,color,w) ui(parent,'UIStroke',{Color=color,Thickness=w or 4,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function lettering(parent,name,value,position,size,color)
 local o=ui(parent,'TextLabel',{Name=name,Text=value,Position=position,Size=size,BackgroundTransparency=1,Font=Enum.Font.FredokaOne,TextScaled=true,TextWrapped=true,TextColor3=color or white,TextStrokeTransparency=1,ZIndex=4})
 ui(o,'UIStroke',{Color=ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual});return o
end
local function face(panel,title,sub,color,board)
 local old=panel:FindFirstChildOfClass('SurfaceGui');if old then old:Destroy() end
 local gui=ui(panel,'SurfaceGui',{Name=board and 'BoardGui' or 'HussSignV11',Face=Enum.NormalId.Back,SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud,PixelsPerStud=80,LightInfluence=0,Brightness=1,AlwaysOnTop=false,MaxDistance=160})
 local body=ui(gui,'Frame',{Name='Body',Size=UDim2.fromScale(1,1),BackgroundColor3=board and ink or color,BorderSizePixel=0});rounded(body,18);edge(body,ink,8)
 ui(body,'UIGradient',{Color=ColorSequence.new(white,R(129,163,159)),Rotation=90})
 local header=board and .17 or 1
 for row=0,3 do for col=0,11 do if (row+col)%2==0 then
  ui(body,'Frame',{Name='Checker',Position=UDim2.fromScale(col/12,row*header/4),Size=UDim2.fromScale(1/12,header/4),BackgroundColor3=white,BackgroundTransparency=.9,BorderSizePixel=0,ZIndex=2})
 end end end
 local shine=ui(body,'Frame',{Name='Gloss',Position=UDim2.fromScale(.015,.015),Size=UDim2.fromScale(.97,header*.37),BackgroundColor3=white,BackgroundTransparency=.86,BorderSizePixel=0,ZIndex=2});rounded(shine,12)
 local rim=ui(body,'Frame',{Name='InnerRim',Position=UDim2.fromScale(.01,.025),Size=UDim2.fromScale(.98,.95),BackgroundTransparency=1,ZIndex=3});rounded(rim,15);edge(rim,board and color or color:Lerp(white,.55),5)
 lettering(body,'Heading',title,UDim2.fromScale(.035,.04),UDim2.fromScale(.93,board and .12 or sub~='' and .51 or .9),board and color or white)
 if board then
  for i=1,10 do lettering(body,'Row'..i,'',UDim2.fromScale(.055,.18+(i-1)*.068),UDim2.fromScale(.89,.058),white).Font=Enum.Font.GothamBlack end
  lettering(body,'Status','Loading server records…',UDim2.fromScale(.04,.89),UDim2.fromScale(.92,.062),color).Font=Enum.Font.GothamBold
 elseif sub~='' then lettering(body,'Subtitle',sub,UDim2.fromScale(.05,.61),UDim2.fromScale(.9,.29),white).Font=Enum.Font.GothamBlack end
 return gui
end
local function sign(parent,title,sub,x,y,z,w,h,color,rot)
 local p=part(parent,title,x,y,z,w,h,.5,ink,false,rot);face(p,title,sub,color);return p
end
local function bomb(parent,x,y,z,s,color)
 local g=group(parent,'Bomb display')
 cylinder(g,'Bomb base',x,y+s*.14,z,s*1.15,s*.28,ink)
 local orb=ball(g,'Bomb shell',x,y+s*.75,z,s,color);orb.Material=M.Metal
 cylinder(g,'Fuse cap',x,y+s*1.26,z,s*.28,s*.18,gold)
 beam(g,'Curved fuse',V(x,y+s*1.32,z),V(x+s*.22,y+s*1.62,z),s*.07,s*.07,white)
 local ember=ball(g,'Fuse ember',x+s*.22,y+s*1.64,z,s*.14,gold);ember.Material=M.Neon
 for i=-1,1 do part(g,'Shell shine',x+s*.17+i*s*.1,y+s*.91,z+s*.435,s*.055,s*.3,s*.06,white,false,CFrame.Angles(0,0,-.2)) end
 return g
end
local function rail(parent,a,b,color)
 beam(parent,'Guard collision',a+V(0,1.6,0),b+V(0,1.6,0),.5,3.2,ink,true).Transparency=1
 beam(parent,'Bright handrail',a+V(0,3.3,0),b+V(0,3.3,0),.38,.38,color)
 beam(parent,'Lower rail',a+V(0,1,0),b+V(0,1,0),.2,.2,ink)
 local count=math.ceil((b-a).Magnitude/10);for i=0,count do local q=a:Lerp(b,i/count);part(parent,'Rail post',q.X,q.Y+1.6,q.Z,.35,3.2,.35,ink) end
end
local pavingLevel=0
local function paving(parent,x,z,w,d,color,y)
 pavingLevel+=1;y=(y or 0)+pavingLevel*.002
 local p=part(parent,'Inlaid route',x,(y or 0)+.055,z,w,.07,d,color);p.Material=M.Concrete
 for xx=-w/2+8,w/2-1,8 do part(parent,'Paving seam',x+xx,(y or 0)+.097,z,.06,.012,d,color:Lerp(ink,.17)) end
 for zz=-d/2+8,d/2-1,8 do part(parent,'Paving seam',x,(y or 0)+.097,z+zz,w,.012,.06,color:Lerp(ink,.17)) end
end
local function deck(parent,e,name,x,z,w,d,y,color)
 part(parent,name,x,y-.6,z,w,1.2,d,color,true)
 for _,xx in ipairs({x-w/2+2,x+w/2-2}) do for _,zz in ipairs({z-d/2+2,z+d/2-2}) do part(parent,'Deck pillar',xx,(y-1.2)/2,zz,1.6,y-1.2,1.6,ink,true) end end
 paving(parent,x,z,w-.8,d-.8,color:Lerp(white,.1),y)
 table.insert(e.Decks,{Name=name,X=x,Z=z,Y=y,Width=w,Depth=d,Clearance=y-1.2,SolidBase=false})
end
local function ramp(parent,e,name,x1,z1,x2,z2,rise,width,color)
 local a,b=V(x1,0,z1),V(x2,rise,z2);local delta=V(x2-x1,0,z2-z1);local run=delta.Magnitude;local q=(a+b)/2
 assert(width>=24 and math.deg(math.atan(rise/run))<=14,'Unsafe no-jump route')
 local turn=CFrame.lookAt(q,q-delta).Rotation
 part(parent,name,q.X,q.Y,q.Z,width,rise,run,color,true,turn,'WedgePart'):SetAttribute('NoJumpRoute',true)
 local side=V(delta.Z,0,-delta.X).Unit*(width/2-.25);rail(parent,a+side,b+side,gold);rail(parent,a-side,b-side,gold)
 for i=1,math.floor(run/6)-1 do local at=a:Lerp(b,i*6/run);part(parent,'Flush grip',at.X,at.Y+.025,at.Z,width-1,.03,.16,white,false,turn*CFrame.Angles(-math.atan(rise/run),0,0)) end
 table.insert(e.Ramps,{Name=name,X1=x1,Z1=z1,X2=x2,Z2=z2,BaseY=0,Rise=rise,Run=run,Width=width,SlopeDegrees=math.deg(math.atan(rise/run))})
end
local function building(parent,name,x,z,w,d,h,color,accent)
 local g=group(parent,name);local body=part(g,'Smooth facade collision',x,h/2,z,w,h,d,color,true);body.Material=M.Brick
 for _,y in ipairs({.4,h*.5,h-.4}) do part(g,'Facade trim',x,y,z,w+.5,.55,d+.5,white) end
 for _,s in ipairs({-1,1}) do
  for xx=-w/2+4,w/2-1,7 do
   part(g,'Window recess',x+xx,h*.48,z+s*(d/2+.12),4.6,6,.2,ink)
   part(g,'Tinted glass',x+xx,h*.48,z+s*(d/2+.25),3.9,5.3,.13,accent:Lerp(ink,.35))
   part(g,'Window bar',x+xx,h*.48,z+s*(d/2+.34),.16,5.3,.12,white)
   part(g,'Window sill',x+xx,h*.48-2.9,z+s*(d/2+.38),5,.35,.65,white)
  end
  part(g,'Corner upright',x+s*(w/2-.4),h/2,z+d/2+.1,.8,h,.4,white)
  part(g,'Rooftop rim',x+s*(w/2-.2),h+1.5,z,.5,3,d,ink)
 end
 part(g,'Roof coping',x,h+.3,z,w+1,.6,d+1,accent)
 -- Facades use one smooth solid; glazing, awnings and service details cannot snag a dodge.
 part(g,'Closed door frame',x,3.4,z+d/2+.37,5,6.8,.45,white)
 part(g,'Closed door',x,3.1,z+d/2+.65,4.3,6.2,.12,ink)
 part(g,'Door handle',x+1.3,3,z+d/2+.75,.18,.8,.14,gold)
 for _,side in ipairs({-1,1}) do for zz=-d/2+5,d/2-2,7 do
  part(g,'Side window frame',x+side*(w/2+.12),h*.5,z+zz,.2,6,4.5,ink)
  part(g,'Side glazing',x+side*(w/2+.25),h*.5,z+zz,.12,5.3,3.8,accent:Lerp(white,.2))
  part(g,'Side mullion',x+side*(w/2+.32),h*.5,z+zz,.1,5.3,.18,white)
 end end
 if name=='Boom Bakery' or name=='Bomb Boutique' or name=='Fuse Flowers' or name=='Pop Arcade' then
  for i=0,math.floor((w-2)/2)-1 do part(g,'Shop canopy stripe',x-w/2+2+i*2,7.5,z+d/2+2,2,.3,4.2,i%2==0 and accent or white,false,CFrame.Angles(.1,0,0)) end
  for _,side in ipairs({-1,1}) do part(g,'Awning brace',x+side*(w*.38),6.9,z+d/2+1.4,.16,.2,3,ink,false,CFrame.Angles(-.3,0,0)) end
 else
  for i=0,2 do
   part(g,'Service vent',x-w*.3+i*w*.3,h+.9,z-d*.3,3.2,1.3,2.8,ink)
   for j=-1,1 do part(g,'Vent fin',x-w*.3+i*w*.3+j*.7,h+1.6,z-d*.3,.18,.08,2.5,white) end
  end
 end
 sign(g,name:upper(),'BOMB CO.',x,h-2,z+d/2+.5,w-2,3.4,accent)
 bomb(g,x,h+.6,z,math.min(9,w*.27),accent)
 return g
end
local function crate(parent,x,z,w,color)
 part(parent,'Cargo collision',x,w*.4,z,w,w*.8,w,color,true)
 for _,s in ipairs({-1,1}) do
  part(parent,'Steel crate band',x+s*w*.29,w*.4,z,.3,w*.8+.1,w+.1,ink)
  beam(parent,'Cargo diagonal',V(x-w/2,w*.12,z+s*(w/2+.1)),V(x+w/2,w*.68,z+s*(w/2+.1)),.4,.2,white)
 end
 sign(parent,'BOMB','',x,w*.42,z+w/2+.18,w*.64,w*.25,gold)
end
local function tree(parent,x,z,s,color)
 cylinder(parent,'Garden pot',x,.8,z,6*s,1.6,ink,true)
 part(parent,'Trunk',x,4*s,z,1.1*s,8*s,1.1*s,R(116,76,50))
 for i=0,3 do local a=i*2.2;local o=ball(parent,'Canopy',x+math.cos(a)*2*s,(8+i%2*2)*s,z+math.sin(a)*2*s,8*s,color);o.Size=V(8,6,8)*s end
end
local function inside(poly,x,z)
 local yes=false;local j=#poly
 for i,a in ipairs(poly) do local b=poly[j];if (a[2]>z)~=(b[2]>z) and x<(b[1]-a[1])*(z-a[2])/(b[2]-a[2])+a[1] then yes=not yes end;j=i end
 return yes
end
local function ground(model,e)
 local floor=part(model,'Floor',0,-2,0,e.Width,4,e.Depth,e.Color);floor.Transparency=1;model.PrimaryPart=floor
 local land=group(model,'Landform')
 for z=-e.Depth/2+1,e.Depth/2-1,2 do
  local xs={};local j=#e.Polygon
  for i,a in ipairs(e.Polygon) do local b=e.Polygon[j];if (a[2]>z)~=(b[2]>z) then table.insert(xs,a[1]+(z-a[2])*(b[1]-a[1])/(b[2]-a[2])) end;j=i end
  table.sort(xs);for i=1,#xs-1,2 do local p=part(land,'GroundTile',(xs[i]+xs[i+1])/2,-2,z,xs[i+1]-xs[i],4,2,e.Color,true);p.Material=e.Material end
 end
 e.Floor={Width=e.Width,Depth=e.Depth,Y=0}
 local border=group(model,'Bomb district boundary')
 for i,a in ipairs(e.Polygon) do local b=e.Polygon[i%#e.Polygon+1];local p,q=V(a[1],0,a[2]),V(b[1],0,b[2])
  beam(border,'Arena limit',p+V(0,30,0),q+V(0,30,0),1.2,60,ink,true).Transparency=1
  beam(border,'Foundation fascia',p-V(0,2,0),q-V(0,2,0),3,4,ink)
  rail(border,p,q,e.Accent)
  local count=math.ceil((q-p).Magnitude/22);for j=0,count do local at=p:Lerp(q,j/count);part(border,'Edge light pillar',at.X,3.5,at.Z,.6,7,.6,ink);local orb=ball(border,'Edge light',at.X,7.2,at.Z,1.2,e.Accent);orb.Material=M.Neon end
 end
end
local function spawns(model,e)
 local blocked={}
 for _,p in ipairs(model:GetDescendants()) do if p:IsA('BasePart') and p.CanCollide then
  local h=p.Size/2;local cf=p.CFrame;local ex=math.abs(cf.RightVector.X)*h.X+math.abs(cf.UpVector.X)*h.Y+math.abs(cf.LookVector.X)*h.Z
  local ey=math.abs(cf.RightVector.Y)*h.X+math.abs(cf.UpVector.Y)*h.Y+math.abs(cf.LookVector.Y)*h.Z;local ez=math.abs(cf.RightVector.Z)*h.X+math.abs(cf.UpVector.Z)*h.Y+math.abs(cf.LookVector.Z)*h.Z
  if p.Position.Y+ey>.3 then table.insert(blocked,{p.Position.X,p.Position.Z,ex+5,ez+5}) end
 end end
 local choices={}
 for x=-e.Width/2+12,e.Width/2-12,6 do for z=-e.Depth/2+12,e.Depth/2-12,6 do
  local clear=true;for _,o in ipairs({{0,0},{6,0},{-6,0},{0,6},{0,-6}}) do if not inside(e.Polygon,x+o[1],z+o[2]) then clear=false end end
  if clear then for _,b in ipairs(blocked) do if math.abs(x-b[1])<b[3] and math.abs(z-b[2])<b[4] then clear=false;break end end end
  if clear then table.insert(choices,{x,z}) end
 end end
 assert(#choices>=16,'Insufficient spawns in '..e.Name);local chosen={};local folder=group(model,'Spawns','Folder')
 for i=1,16 do
  local best,score=1,-1;for j,q in ipairs(choices) do local n=#chosen==0 and q[1]^2+q[2]^2 or math.huge;for _,v in ipairs(chosen) do n=math.min(n,(q[1]-v[1])^2+(q[2]-v[2])^2) end;if n>score then score=n;best=j end end
  local q=table.remove(choices,best);table.insert(chosen,q);local name=string.format('Spawn%02d',i)
  local p=part(folder,name,q[1],.25,q[2],4,.2,4,white);p.Transparency=1;p.CastShadow=false;table.insert(e.Spawns,{Name=name,X=q[1],Y=.25,Z=q[2]})
 end
end
local definitions={
 {Name='Fuseworks',Width=280,Depth=210,Polygon={{-140,-60},{-100,-105},{100,-105},{140,-60},{140,65},{103,105},{-98,105},{-140,65}},Color=R(119,133,145),Material=M.Concrete,Accent=R(255,166,37)},
 {Name='Detonator Plaza',Width=232,Depth=244,Polygon={{-48,-122},{48,-122},{116,-54},{116,54},{48,122},{-48,122},{-116,54},{-116,-54}},Color=R(103,152,117),Material=M.Grass,Accent=R(60,224,180)},
 {Name='Payload Port',Width=326,Depth=174,Polygon={{-163,-60},{-128,-87},{115,-87},{163,-35},{163,65},{115,87},{-125,87},{-163,52}},Color=R(156,168,173),Material=M.Concrete,Accent=R(58,194,247)},
}
local function buildFuse(model,e)
 local g=group(model,'Fuse assembly works')
 paving(g,0,35,162,84,R(186,189,179));paving(g,0,-59,180,42,R(153,166,177));paving(g,-45,-4,32,148,R(195,198,183));paving(g,45,-4,32,148,R(195,198,183))
 deck(g,e,'Assembly gantry',0,-58,152,28,8,R(99,140,156))
 for _,s in ipairs({-1,1}) do
  ramp(g,e,(s<0 and 'West' or 'East')..' gantry ramp',s*64,16,s*64,-44,8,24,R(176,188,186))
  building(g,s<0 and 'Fuse Lab' or 'Shell Press',s*106,3,32,38,23,R(93,122,145),e.Accent)
  building(g,s<0 and 'Packing' or 'Dispatch',s*102,-73,30,28,18,R(81,114,129),teal)
  for _,z in ipairs({54,82}) do crate(g,s*112,z,11,s<0 and e.Accent or teal) end
  rail(g,V(s*76,8,-44),V(s*76,8,-72),gold)
 end
 rail(g,V(-76,8,-72),V(76,8,-72),gold);rail(g,V(-52,8,-44),V(52,8,-44),gold)
 cylinder(g,'Reactor island collision',0,2.1,16,22,4.2,ink,true);bomb(g,0,4.2,16,16,e.Accent)
 for _,s in ipairs({-1,1}) do
  part(g,'Production arch column',s*24,11,71,2.5,22,2.5,ink,true);part(g,'Arch sleeve',s*24,9,71,3.3,4,3.3,e.Accent)
 end
 part(g,'Production arch beam',0,22.5,71,51,3,4,ink);sign(g,'FUSEWORKS','PASS THE PRESSURE',0,23,73.2,35,6,e.Accent)
 for i=-3,3 do part(g,'Route hazard stripe',i*5,.11,69,2.8,.035,8,gold,false,CFrame.Angles(0,-.3,0)) end
 for i=-2,2 do cylinder(g,'Vent stack',i*7,18,-95,4,10,ink);cylinder(g,'Vent collar',i*7,21,-95,5,1,e.Accent) end
end
local function buildPlaza(model,e)
 local g=group(model,'Detonator town square')
 paving(g,0,20,62,172,R(235,218,182));paving(g,0,20,190,34,R(235,218,182));paving(g,0,-64,113,47,R(194,188,177))
 deck(g,e,'Bomb balcony',0,-70,104,32,8,R(237,193,107))
 for _,s in ipairs({-1,1}) do
  ramp(g,e,(s<0 and 'West' or 'East')..' plaza promenade',s*40,0,s*40,-54,8,24,R(246,221,164))
  building(g,s<0 and 'Boom Bakery' or 'Pop Arcade',s*81,27,29,34,21,s<0 and R(220,145,102) or R(118,146,211),s<0 and gold or pink)
  building(g,s<0 and 'Fuse Flowers' or 'Bomb Boutique',s*50,81,29,25,17,s<0 and R(170,124,185) or R(116,168,171),s<0 and pink or teal)
  tree(g,s*88,-40,.95,R(59,154,94));tree(g,s*18,103,.75,R(80,169,92))
  rail(g,V(s*52,8,-54),V(s*52,8,-86),e.Accent)
 end
 rail(g,V(-52,8,-86),V(52,8,-86),e.Accent);rail(g,V(-28,8,-54),V(28,8,-54),e.Accent)
 building(g,'Detonator Hall',0,-103,48,18,24,R(118,162,144),gold)
 cylinder(g,'Plaza fountain collision',0,1.8,28,17,3.6,R(160,162,167),true);cylinder(g,'Fountain water',0,3.65,28,14,.2,teal);bomb(g,0,3.8,28,9,gold)
 sign(g,'DETONATOR PLAZA','KEEP YOUR COOL',0,18,-53.6,36,5,e.Accent)
 for _,s in ipairs({-1,1}) do part(g,'Balcony sign support',s*16,12,-56,.45,8,.45,ink) end
 for i=-4,4 do part(g,'Crosswalk',i*5,.12,53,3,.035,9,white) end
 for _,x in ipairs({-102,102}) do part(g,'Street lamp',x,6,13,.5,12,.5,ink);ball(g,'Lamp globe',x,12,13,2,gold) end
end
local function buildPort(model,e)
 local g=group(model,'Bomb cargo terminal')
 local water=part(g,'Harbor water',0,-1.3,0,370,.25,245,R(46,137,161));water.Material=M.Glass;water.Transparency=.2
 paving(g,0,0,285,32,R(193,190,166));paving(g,-40,54,194,30,R(202,201,185));paving(g,-40,-53,194,30,R(202,201,185))
 building(g,'Payload Depot',-79,0,52,48,25,R(72,118,148),gold)
 deck(g,e,'Dock lookout',79,0,44,54,8,R(107,158,182))
 ramp(g,e,'North loading ramp',79,-78,79,-27,8,24,R(205,196,164));ramp(g,e,'South loading ramp',79,78,79,27,8,24,R(205,196,164))
 rail(g,V(57,8,-27),V(57,8,27),teal);rail(g,V(101,8,-27),V(101,8,27),teal)
 for _,z in ipairs({-27,27}) do rail(g,V(57,8,z),V(67,8,z),teal);rail(g,V(91,8,z),V(101,8,z),teal) end
 for _,s in ipairs({-1,1}) do
  for i=0,2 do crate(g,4+i*16,s*53,12,({gold,teal,pink})[i+1]) end
  crate(g,-143,s*33,12,e.Accent);bomb(g,-139,0,s*60,7,gold)
 end
 local crane=group(g,'Gantry crane')
 for _,x in ipairs({-134,-111}) do part(crane,'Crane support',x,17,-54,3,34,3,gold,true);part(crane,'Crane foot',x,1,-54,8,2,8,ink) end
 part(crane,'Crane boom',-104,34,-54,72,4,5,gold);beam(crane,'Hoist cable',V(-79,32,-54),V(-79,13,-54),.22,.22,ink);bomb(crane,-79,9,-54,5,ink)
 local ship=group(g,'Offshore payload ship')
 part(ship,'Ship hull',-23,-.9,-110,111,5,25,R(43,63,88));part(ship,'Ship deck',-23,2,-110,104,1,23,white)
 part(ship,'Ship bow',40,-.9,-110,25,5,23,R(43,63,88),false,CFrame.Angles(0,math.pi/2,0),'WedgePart')
 for _,side in ipairs({-1,1}) do
  beam(ship,'Ship safety rail',V(-74,5,-110+side*10),V(27,5,-110+side*10),.25,.3,white)
  for x=-72,27,11 do part(ship,'Ship railing post',x,3.7,-110+side*10,.25,2.6,.25,ink) end
 end
 building(ship,'Harbor Tug',-66,-111,15,14,14,R(62,115,163),gold)
 for i=-1,2 do bomb(ship,i*19,2.8,-110,10,({teal,gold,pink})[(i+2)%3+1]) end
 sign(g,'PAYLOAD PORT','SPECIAL DELIVERY',79,17,1,30,5,e.Accent)
 for _,x in ipairs({65,93}) do part(g,'Lookout sign pole',x,11,0,.5,6,.5,ink) end
end
local builders={buildFuse,buildPlaza,buildPort}
local scales={['Sky Garden']=1.24,['Sunset Docks']=1.24,['Frostfall Village']=1.24,['Sunstone Bazaar']=1.24,['Neon District']=1.1,['Clockwork Foundry']=1.1,['Orbital Station']=1.1,['Stardust Carnival']=1.1,['Crystal Cavern']=1.1,['Emerald Ruins']=1.1,['Pirate Cove']=1.1,['Ember Keep']=1.1}
local function restyle(model)
 local list={};for _,o in ipairs(model:GetDescendants()) do if o:IsA('SurfaceGui') then table.insert(list,o) end end
 for _,gui in ipairs(list) do
  local panel=gui.Parent
  if panel and panel:IsA('BasePart') and gui.Name~='HussSignV11' and gui.Name~='BoardGui' then
   local labels={};for _,t in ipairs(gui:GetChildren()) do if t:IsA('TextLabel') then table.insert(labels,t) end end
   if #labels>0 then
    local title=labels[1].Text;local sub=#labels>1 and labels[2].Text or '';local color=labels[1].TextColor3 or gold;local oldFace=gui.Face
    face(panel,title,sub,color).Face=oldFace
   end
  end
 end
end
local function upgrade(model,factor)
 if model:GetAttribute('BombTagGenerated')=='HussWorld11' then return end
 assert(model:GetAttribute('BombTagGenerated')=='HussWorld4','Install the movement maps first: '..model.Name)
 local floor=model:FindFirstChild('Floor');assert(floor and floor:IsA('BasePart'),'Map Floor missing')
 local center=V(floor.Position.X,floor.Position.Y+floor.Size.Y/2,floor.Position.Z)
 for _,p in ipairs(model:GetDescendants()) do if p:IsA('BasePart') then p.Size*=factor;p.CFrame=C(center+(p.Position-center)*factor)*p.CFrame.Rotation end end
 model:SetAttribute('MapWidth',model:GetAttribute('MapWidth')*factor);model:SetAttribute('MapDepth',model:GetAttribute('MapDepth')*factor)
 model:SetAttribute('HussWorldScale',factor);model:SetAttribute('BombTagGenerated','HussWorld11');model:SetAttribute('MovementDesign','Wider authored routes; connected ramps; no jumping')
 restyle(model)
 local additions=group(model,'Bomb district identity');local count=0
 -- Roof-only displays preserve every established running route and spawn.
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA('BasePart') and (p.Name=='Roof coping' or p.Name=='Ventilation unit' or p.Name=='Roof ridge') and count<5 then
   count+=1;local top=p.Position.Y+p.Size.Y/2;local size=math.min(8,p.Size.X*.28+3)
   bomb(additions,p.Position.X,top+.2,p.Position.Z,size,({gold,teal,pink})[(count-1)%3+1])
  end
 end
 local sourceName=model.Name
 for _,o in ipairs(model:GetDescendants()) do if o:IsA('SurfaceGui') and o.Name=='HussSignV11' then
  local sub=o.Body:FindFirstChild('Subtitle');if sub then sub.Text='BOMB DISTRICT  •  '..sourceName:upper() end
 end end
end
local function lobbyUpgrade(original)
 local lobby=original:Clone();assert(lobby,'Unable to clone Lobby')
 local version=lobby:GetAttribute('HussLobbyVersion');assert(version==7 or version==11,'Install the V7 lobby before this expansion.')
 if version==11 then return lobby end
 local floor=lobby:FindFirstChild('Floor');assert(floor and floor:IsA('BasePart'),'Lobby floor missing')
 local origin=C(floor.Position.X,floor.Position.Y+floor.Size.Y/2,floor.Position.Z)*floor.CFrame.Rotation
 local addition=group(nil,'V11 Bomb Exchange')
 local gallery=lobby:FindFirstChild('Shaded galleries');if gallery then gallery:Destroy() end
 local categories={'Bombs','Trails','Titles','Emotes'};local accents={gold,teal,pink,R(151,114,246)}
 for i,category in ipairs(categories) do
  local s=i<=2 and -1 or 1;local z=i%2==1 and -17 or 20;local station=group(addition,category..' kiosk')
  local color=accents[i]
  part(station,'Kiosk backdrop',0,6,-5.5,24,12,1.2,ink,true)
  part(station,'Counter',0,2,4.7,23,4,4.8,color,true)
  part(station,'Counter rim',0,4.2,4.7,24,.4,5.2,white)
  for _,x in ipairs({-11,11}) do part(station,'Awning pole',x,6.5,1,1,13,1,ink,true) end
  part(station,'Canopy',0,13.2,0,27,.7,14,color)
  for stripe=-5,5 do part(station,'Canopy stripe',stripe*2.4,13.6,0,1.2,.04,14,white) end
  sign(station,category:upper(),category=='Bombs' and '25 BOMB SKINS' or category=='Trails' and '25 TRAIL EFFECTS' or category=='Titles' and 'MAKE A NAME' or 'SHOW YOUR STYLE',0,10.4,7.1,25,4.8,color)
  bomb(station,0,4.5,-1,6,color)
  local anchor=part(station,'Browse '..category,0,5.5,7.5,1,1,1,color);anchor.Transparency=1
  local prompt=ui(anchor,'ProximityPrompt',{Name='BrowseShop',ActionText='Browse '..category,ObjectText='BOMB EXCHANGE',KeyboardKeyCode=Enum.KeyCode.E,GamepadKeyCode=Enum.KeyCode.ButtonX,HoldDuration=0,MaxActivationDistance=14,RequiresLineOfSight=false})
  prompt:SetAttribute('HussShopCategory',category)
  local transform=origin*C(s*87,0,z)*CFrame.Angles(0,-s*math.pi/2,0)
  for _,p in ipairs(station:GetDescendants()) do if p:IsA('BasePart') then p.CFrame=transform*p.CFrame end end
 end
 local boards=group(addition,'Lobby leaderboards')
 for i,stat in ipairs({'Wins','Kills','FinalStands','GlobalWins'}) do
  local x=-54+(i-1)*36;local color=accents[i]
  local panel=part(boards,stat..' board',x,13,-74,28,13,.6,ink,true);panel:SetAttribute('HussBoardStat',stat)
  face(panel,stat=='FinalStands' and 'FINAL STANDS' or stat=='GlobalWins' and 'GLOBAL WINS' or stat:upper(),'',color,true)
  for _,s in ipairs({-1,1}) do part(boards,'Board stand',x+s*10,6.2,-74,1.2,2.4,2,color) end
 end
 for _,p in ipairs(boards:GetDescendants()) do if p:IsA('BasePart') then p.CFrame=origin*p.CFrame end end
 -- Remove the old rear text, which would sit directly behind the new scoreboards.
 local terrace=lobby:FindFirstChild('North terrace');local old=terrace and terrace:FindFirstChild('YOUR NEXT CHASE');if old then old:Destroy() end
 local banner=terrace and terrace:FindFirstChild('HUSS A BOMB');if banner and banner:IsA('BasePart') then banner.CFrame=origin*C(0,21,-52) end
 addition.Parent=lobby;restyle(lobby);lobby:SetAttribute('HussLobbyVersion',11)
 return lobby
end
function B.Build(library,lobby)
 assert(library and library:IsA('Folder') and lobby and lobby:IsA('Model'),'MapLibrary and Lobby are required.')
 local staged=group(nil,'MapLibrary','Folder');local newLobby;local geometry={}
 local ok,message=pcall(function()
  for name,factor in pairs(scales) do
   local source=library:FindFirstChild(name);assert(source and source:IsA('Model'),'Missing original movement map: '..name)
   local copy=source:Clone();assert(copy,'Unable to clone '..name);copy.Parent=staged;upgrade(copy,factor)
  end
  for index,definition in ipairs(definitions) do
   local existing=library:FindFirstChild(definition.Name);assert(not existing or existing:GetAttribute('BombTagGenerated')=='HussWorld11','Unrelated map has the new name '..definition.Name)
   local e=table.clone(definition);e.Version='HussWorld11';e.Ramps={};e.Decks={};e.Spawns={};e.Routes={};e.Obstacles={}
   local map=group(staged,e.Name);map:SetAttribute('BombTagGenerated','HussWorld11');map:SetAttribute('MapWidth',e.Width);map:SetAttribute('MapDepth',e.Depth);map:SetAttribute('DisplayName',e.Name);map:SetAttribute('MovementDesign','Two exits per elevation; wide no-jump routes')
   pavingLevel=0;ground(map,e);builders[index](map,e);spawns(map,e);table.insert(geometry,e)
  end
  -- Retain independently added maps rather than silently deleting user content.
  for _,other in ipairs(library:GetChildren()) do if not staged:FindFirstChild(other.Name) then local copy=other:Clone();assert(copy,'Unable to preserve '..other.Name);copy.Parent=staged end end
  newLobby=lobbyUpgrade(lobby)
 end)
 if not ok then staged:Destroy();if newLobby then newLobby:Destroy() end;error(message) end
 return {Library=staged,Lobby=newLobby,Geometry=geometry}
end
return B
