--!nonstrict
-- V16: the original conservatory with organized shopping and an open spectator edge.
-- This module builds geometry only when called from the stopped-Studio installer.
local B={Version=16}
local V,CF,R=Vector3.new,CFrame.new,Color3.fromRGB
local ink,stone,cream,wood=R(27,39,38),R(151,170,151),R(230,227,205),R(105,73,52)
local sage,leaf,gold=R(97,131,107),R(57,99,71),R(225,187,104)
local cyan,violet=R(65,213,236),R(180,140,232)
local Z0=86.66000366210938
local function yaw(x,y,z,degrees)
 return CF(x,y,z)*CFrame.Angles(0,math.rad(degrees),0)
end
local ARCHIVES={'North terrace','Gardens and seating','Boundary','HABExpansionLobby/SpectatorOverlook','HABExpansionLobby/InvisibleLobbyBarrier'}
B.ArchivePaths=table.freeze(ARCHIVES)
local SIGN_CHANGES={
 {'V11 Bomb Exchange/Emotes kiosk/EMOTES/HussSignV11/Body/Heading','EMOTES','LOCKER'},
 {'V11 Bomb Exchange/Emotes kiosk/EMOTES/HussSignV11/Body/Subtitle','SHOW YOUR STYLE','YOUR EFFECTS COLLECTION'},
 {'V11 Bomb Exchange/Emotes kiosk/ShopPanelV12/ShopIdleV12/Body/Title','EMOTES EXCHANGE','YOUR LOCKER'},
 {'V11 Bomb Exchange/Emotes kiosk/ShopPanelV12/ShopIdleV12/Body/Details','CELEBRATE EVERY CLOSE CALL','BROWSE YOUR OWNED EFFECTS'},
}
local function layouts()
 return {
  {Path='V11 Bomb Exchange/Bombs kiosk',Anchor='Browse Bombs',Old=yaw(-79.5,7,69.66000366210938,90),New=yaw(-79.5,7,44,90)},
  {Path='V11 Bomb Exchange/Trails kiosk',Anchor='Browse Trails',Old=yaw(-79.5,7,106.66000366210938,90),New=yaw(-79.5,7,79,90)},
  {Path='V11 Bomb Exchange/Titles kiosk',Anchor='Browse Titles',Old=yaw(79.5,7,69.66000366210938,-90),New=yaw(-79.5,7,114,90)},
  {Path='V11 Bomb Exchange/Emotes kiosk',Anchor='Browse Emotes',Old=yaw(79.5,7,106.66000366210938,-90),New=yaw(-79.5,7,149,90)},
  {Path='HABExpansionLobby/Bundle_Cyber',Anchor='BrowseStand',Old=yaw(-28,5.099999904632568,154.9600067138672,0),New=yaw(81.2,5.099999904632568,44,-90)},
  {Path='HABExpansionLobby/Bundle_Solar',Anchor='BrowseStand',Old=yaw(52,5.099999904632568,78.96000671386719,0),New=yaw(81.2,5.099999904632568,72,-90)},
  {Path='HABExpansionLobby/Bundle_Glacier',Anchor='BrowseStand',Old=yaw(28,5.099999904632568,154.9600067138672,0),New=yaw(81.2,5.099999904632568,100,-90)},
  {Path='HABExpansionLobby/Bundle_Phantom',Anchor='BrowseStand',Old=yaw(-52,5.099999904632568,78.96000671386719,0),New=yaw(81.2,5.099999904632568,128,-90)},
  {Path='HABExpansionLobby/CrateStand',Anchor='BrowseStand',Old=yaw(68,5.300000190734863,122.16000366210938,0),New=yaw(26,5.300000190734863,150.5,180)},
  -- The whole four-board group turns toward arrivals, clearing the arena sightline.
  {Path='V11 Bomb Exchange/Lobby leaderboards',Anchor='Wins board',Old=yaw(-54,14.5,12.660003662109375,0),New=yaw(54,9.5,175,180)},
 }
end
function B.GetLayout()
 local out=layouts()
 for _,entry in ipairs(out) do entry.Delta=entry.New*entry.Old:Inverse() end
 return out
end
local function model(parent,name)
 local o=Instance.new('Model');o.Name=name;o.Parent=parent;return o
end
local function part(parent,name,x,y,z,w,h,d,color,solid,rotation,kind)
 local o=Instance.new(kind or 'Part');o.Name=name;o.Size=V(w,h,d);o.CFrame=CF(x,y,z)*(rotation or CFrame.identity)
 o.Color=color;o.Material=Enum.Material.SmoothPlastic;o.Anchored=true;o.CanCollide=solid==true
 o.CanTouch=false;o.CanQuery=solid==true;o.CastShadow=solid==true
 o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth;o.Parent=parent;return o
end
local function disc(parent,name,x,y,z,w,h,d,color,solid)
 local o=part(parent,name,x,y,z,h,w,d,color,solid,CFrame.Angles(0,0,math.pi/2));o.Shape=Enum.PartType.Cylinder;return o
end
local function ball(parent,name,x,y,z,w,h,d,color)
 local o=part(parent,name,x,y,z,w,h,d,color,false);o.Shape=Enum.PartType.Ball;return o
end
local function rounded(parent,name,x,y,z,w,h,d,r,color,solid)
 local g=model(parent,name)
 part(g,'Center',x,y,z,w-2*r,h,d,color,solid)
 part(g,'Cross',x,y,z,w,h+.002,d-2*r,color,solid)
 local i=0
 for _,sx in ipairs({-1,1}) do for _,sz in ipairs({-1,1}) do
  i+=1;disc(g,'Soft corner',x+sx*(w/2-r),y,z+sz*(d/2-r),2*r,h+.004+i*.002,2*r,color,solid)
 end end
 return g
end
local function sign(parent,title,subtitle,x,y,z,w,h,tone,rotation)
 local board=part(parent,title,x,y,z,w,h,.3,ink,false,rotation)
 local gui=Instance.new('SurfaceGui');gui.Name='HABSignV16';gui.Face=Enum.NormalId.Back
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=72;gui.LightInfluence=0;gui.MaxDistance=220;gui.Parent=board
 local body=Instance.new('Frame');body.Name='Body';body.Size=UDim2.fromScale(1,1);body.BackgroundColor3=tone;body.BorderSizePixel=0;body.Parent=gui
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.12,0);corner.Parent=body
 local outline=Instance.new('UIStroke');outline.Color=ink;outline.Thickness=4;outline.Parent=body
 local gloss=Instance.new('Frame');gloss.Name='Gloss';gloss.Size=UDim2.fromScale(.96,.3);gloss.Position=UDim2.fromScale(.02,.04);gloss.BackgroundColor3=R(255,255,255);gloss.BackgroundTransparency=.82;gloss.BorderSizePixel=0;gloss.Parent=body
 for i,text in ipairs({title,subtitle}) do
  local label=Instance.new('TextLabel');label.Name=i==1 and 'Heading' or 'Subtitle';label.BackgroundTransparency=1
  label.Position=UDim2.fromScale(.04,i==1 and .08 or .62);label.Size=UDim2.fromScale(.92,i==1 and .52 or .28)
  label.Text=text;label.TextScaled=true;label.TextColor3=R(255,255,255);label.TextStrokeColor3=ink;label.TextStrokeTransparency=.05
  label.Font=Enum.Font.GothamBold;label.Parent=body
 end
 return board
end
local function beam(parent,name,a,b,width,height,color,solid)
 local center=(a+b)/2
 return part(parent,name,center.X,center.Y,center.Z,width,height,(b-a).Magnitude,color,solid,CFrame.lookAt(a,b).Rotation)
end
local function rail(parent,a,b)
 -- A low visual rail leaves players visible below; the invisible wall stops a weave escape.
 beam(parent,'Low viewing rail',a+V(0,2.6,0),b+V(0,2.6,0),.42,.42,gold,false)
 local glass=beam(parent,'Clear guard',a+V(0,1.35,0),b+V(0,1.35,0),.24,2.7,cyan,false);glass.Material=Enum.Material.Glass;glass.Transparency=.78
 local blocker=beam(parent,'Invisible safety boundary',a+V(0,45,0),b+V(0,45,0),.6,90,ink,true);blocker.Transparency=1;blocker.CanQuery=false;blocker.CastShadow=false
 local n=math.ceil((b-a).Magnitude/24)
 for i=0,n do local p=a:Lerp(b,i/n);part(parent,'Rail post',p.X,p.Y+1.35,p.Z,.6,2.7,.6,stone,true) end
end
local function planter(parent,x,z)
 local g=model(parent,'Corner garden')
 disc(g,'Planter',x,2.5,z,11,2,11,stone,true)
 disc(g,'Cream rim',x,3.56,z,11.3,.15,11.3,cream,false)
 disc(g,'Soil',x,3.65,z,9.8,.08,9.8,ink,false)
 part(g,'Trunk',x,6,z,1.1,5,1.1,wood,false).Material=Enum.Material.Wood
 ball(g,'Canopy',x,10,z,9,8,9,leaf);ball(g,'Crown',x+1,12,z,6,5,6,sage)
end
local function bench(parent,x,z,rotation)
 local g=model(parent,'Courtyard bench');local cf=CF(x,1.5,z)*CFrame.Angles(0,rotation,0)
 for _,v in ipairs({{'Seat',0,1.6,0,9,.4,2.7,wood},{'Back',0,2.4,-1.2,9,1.6,.35,wood},{'Leg',-3,.8,0,.5,1.6,2.4,ink},{'Leg',3,.8,0,.5,1.6,2.4,ink}}) do
  local o=part(g,v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],true);o.CFrame=cf*o.CFrame
 end
end
local function utility(parent,name,title,subtitle,x,tone,panel)
 local g=model(parent,name);local cf=yaw(x,1.5,155,180)
 part(g,'Counter',0,1.8,0,16,3.6,5,stone,true)
 part(g,'Counter top',0,3.8,0,17,.4,5.8,cream,false)
 for _,s in ipairs({-1,1}) do part(g,'Canopy support',s*7,7.5,-3,.9,15,.9,wood,true) end
 part(g,'Canopy',0,15,-.5,18,.65,10,cream,false)
 for i=-3,3 do part(g,'Canopy stripe',i*2.4,15.36,-.5,1.2,.05,10,tone,false) end
 sign(g,title,subtitle,0,11.3,3.4,15,4.1,tone)
 local anchor=part(g,'BrowseStand',0,4,5.5,1,1,1,tone,false);anchor.Transparency=1
 local prompt=Instance.new('ProximityPrompt');prompt.Name='BrowseUtilities';prompt.ActionText='Browse';prompt.ObjectText=title
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX;prompt.RequiresLineOfSight=false;prompt.MaxActivationDistance=12;prompt.HoldDuration=0
 prompt:SetAttribute('HABOpenPanel',panel);prompt:SetAttribute('HABOffer','');prompt.Parent=anchor
 for _,o in ipairs(g:GetDescendants()) do if o:IsA('BasePart') then o.CFrame=cf*o.CFrame end end
 return g
end
function B.Build(parent)
 local root=model(parent,'HABLobbyLayoutV16');root:SetAttribute('HABLobbyLayoutVersion',16)
 local terraces=model(root,'Open spectator terrace')
 -- Same five-stud terrace height as the original. The viewing footprint is a broad capsule.
 rounded(terraces,'Terrace foundation',0,4,0,148,5,80,10,stone,true)
 rounded(terraces,'Terrace paving',0,6.53,0,147,.04,79,9.5,cream,false)
 -- An unobstructed 128-stud front edge, with two short rounded corner segments.
 local front={V(-74,6.5,0),V(-74,6.5,-28),V(-71,6.5,-35),V(-64,6.5,-39.7),V(64,6.5,-39.7),V(71,6.5,-35),V(74,6.5,-28),V(74,6.5,0)}
 for i=1,#front-1 do rail(terraces,front[i],front[i+1]) end
 for _,s in ipairs({-1,1}) do
  rail(terraces,V(s*74,6.5,0),V(s*74,6.5,40))
  rail(terraces,V(s*.4,6.5,40),V(s*39,6.5,40))
  rail(terraces,V(s*69,6.5,40),V(s*74,6.5,40))
  local ramp=part(terraces,'Broad no-jump ramp',s*54,4,52,28,5,24,cream,true,CFrame.Angles(0,math.pi,0),'WedgePart')
  ramp:SetAttribute('NoJumpRoute',true);ramp:SetAttribute('Rise',5);ramp:SetAttribute('Run',24)
 end
 local inlays=model(terraces,'Spectator floor accents')
 part(inlays,'Gold arrival inlay',0,6.565,31,104,.025,.3,gold,false)
 for _,side in ipairs({-1,1}) do
  local x=side*63
  disc(inlays,'Bomb emblem rim',x,6.57,14,10,.025,10,side<0 and cyan or gold,false)
  disc(inlays,'Bomb emblem',x,6.59,14,8.8,.025,8.8,ink,false)
  part(inlays,'Fuse inlay',x+3,6.61,9.5,.65,.025,3,cream,false,CFrame.Angles(0,-.5,0))
 end
 local walks=model(root,'Organized market walks')
 -- Same cream paving as the original. Dedicated shop approaches stay out of the center runway.
 part(walks,'West shopping walk',-73,1.58,97,20,.06,138,cream,false)
 part(walks,'East bundle walk',73,1.58,88,20,.06,120,cream,false)
 part(walks,'Utility approach',48,1.59,144,68,.06,14,cream,false)
 part(walks,'Rear board walk',0,1.57,168.5,146,.04,12,cream,false)
 local gardens=model(root,'Light courtyard planting')
 for _,s in ipairs({-1,1}) do planter(gardens,s*88,173);planter(gardens,s*89,14);bench(gardens,s*48,113,-s*math.pi/2) end
 local edge=model(root,'Perimeter')
 for _,s in ipairs({-1,1}) do
  part(edge,'Original-style side wall',s*101,4.5,Z0,2,6,188,stone,true)
  part(edge,'Cream coping',s*101,7.55,Z0,2.5,.4,188,cream,false)
  local boundary=part(edge,'Side invisible boundary',s*102,46.5,Z0,1,90,188,ink,true);boundary.Transparency=1;boundary.CanQuery=false;boundary.CastShadow=false
  -- Join outer wall to the raised terrace: no opening around the spectator edge.
  local join=part(edge,'North wing boundary',s*88,46.5,-7.34,28,90,1,ink,true);join.Transparency=1;join.CanQuery=false;join.CastShadow=false
  part(edge,'North wing wall',s*88,4.5,-6.34,28,6,2,stone,true)
 end
 part(edge,'Arrival wall',0,4.5,179.66,200,6,2,stone,true)
 part(edge,'Arrival coping',0,7.55,179.66,200,.4,2.5,cream,false)
 local rear=part(edge,'Arrival invisible boundary',0,46.5,180.66,204,90,1,ink,true);rear.Transparency=1;rear.CanQuery=false;rear.CastShadow=false
 local utilities=model(root,'Utilities row')
 utility(utilities,'Abilities booth','ABILITIES','CHOOSE YOUR PLAYSTYLE',48,cyan,'ABILITIES')
 utility(utilities,'Passes booth','PASSES','PERMANENT PERKS',70,gold,'PASSES')
 return root
end
local function find(root,path)
 local node=root
 for name in path:gmatch('[^/]+') do
  local found
  for _,c in ipairs(node:GetChildren()) do if c.Name==name then assert(not found,'Duplicate '..path);found=c end end
  assert(found,'Missing '..root:GetFullName()..'/'..path);node=found
 end
 return node
end
local function close(a,b)
 local aa,bb={a:GetComponents()},{b:GetComponents()}
 for i=1,12 do if math.abs(aa[i]-bb[i])>.002 then return false end end
 return true
end
function B.Plan(lobby,arenaAnchor)
 assert(lobby and lobby:IsA('Model'),'Workspace/Lobby missing')
 assert(not lobby:FindFirstChild('HABPolishedLobbyV15'),'V16 targets HABWAS or V16; restore HABWAS before installing')
 local floor=find(lobby,'Floor');local spawn=find(lobby,'LobbySpawn')
 assert(floor:IsA('BasePart') and floor.Size==V(204,6,188) and close(floor.CFrame,CF(0,-1.5,Z0)),'Unrecognized lobby floor')
 assert(spawn:IsA('SpawnLocation') and close(spawn.CFrame,CF(0,2,150.66000366210938)),'Unrecognized LobbySpawn')
 assert(arenaAnchor and arenaAnchor:IsA('BasePart'),'ActiveArenaAnchor missing')
 local previous=lobby:FindFirstChild('HABLobbyLayoutV16')
 if previous then assert(previous:IsA('Model') and previous:GetAttribute('HABLobbyLayoutVersion')==16,'Unknown V16 lobby root') end
 local expectedArena=previous and CF(0,-27,-190) or CF(0,-27,-245)
 assert(close(arenaAnchor.CFrame,expectedArena),'ActiveArenaAnchor moved unexpectedly')
 local moves={}
 for _,entry in ipairs(layouts()) do
  local obj=find(lobby,entry.Path);assert(obj:IsA('Model'),'Expected booth Model '..entry.Path)
  local anchor=find(obj,entry.Anchor);assert(anchor:IsA('BasePart'),'Missing anchor '..entry.Path)
  assert(close(anchor.CFrame,previous and entry.New or entry.Old),'Booth layout differs at '..entry.Path..'; stopping before modification')
  if not previous then table.insert(moves,{Model=obj,Delta=entry.New*anchor.CFrame:Inverse(),Path=entry.Path}) end
 end
 local archives={}
 if not previous then for _,path in ipairs(ARCHIVES) do local o=find(lobby,path);assert(o:IsA('Model'),'Expected original architecture Model');table.insert(archives,o) end end
 local texts={}
 for _,row in ipairs(SIGN_CHANGES) do
  local label=find(lobby,row[1]);assert(label:IsA('TextLabel'),'Expected original world sign '..row[1])
  assert(label.Text==row[2] or label.Text==row[3],'World sign text differs at '..row[1])
  if label.Text~=row[3] then table.insert(texts,{Label=label,Path=row[1],Before=label.Text,After=row[3]}) end
 end
 return {Lobby=lobby,Previous=previous,Moves=moves,Archives=archives,Texts=texts,Arena=arenaAnchor,ArenaBefore=arenaAnchor.CFrame}
end
function B.Apply(lobby,backup,arenaAnchor)
 assert(backup and backup:IsA('Folder') and backup:IsDescendantOf(game:GetService('ServerStorage')),'Provide a ServerStorage backup Folder')
 local plan=B.Plan(lobby,arenaAnchor)
 local staged=B.Build(nil)
 local moved,transforms,clones={},{},{}
 local journal
 local function restore()
  for i=#transforms,1,-1 do
   local row=transforms[i]
   for _,p in ipairs(row.Parts) do p[1].CFrame=p[2] end
   for _,p in ipairs(row.Pivots) do p[1].WorldPivot=p[2] end
   for _,a in ipairs(row.Attributes) do a[1]:SetAttribute(a[2],a[3]) end
  end
  arenaAnchor.CFrame=plan.ArenaBefore
  for _,row in ipairs(plan.Texts) do row.Label.Text=row.Before end
  for i=#moved,1,-1 do moved[i][1].Parent=moved[i][2] end
 end
 local ok,err=pcall(function()
  journal=Instance.new('Folder');journal.Name='LobbyTransformJournalV16';journal.Parent=backup;table.insert(clones,journal)
  local originalArena=Instance.new('CFrameValue');originalArena.Name='OriginalActiveArenaAnchor';originalArena.Value=plan.ArenaBefore;originalArena.Parent=journal
  for _,row in ipairs(plan.Texts) do
   local saved=Instance.new('StringValue');saved.Name='OriginalSignText';saved.Value=row.Before;saved:SetAttribute('OriginalPath','Workspace/Lobby/'..row.Path);saved.Parent=journal
   row.Label.Text=row.After
  end
  for _,move in ipairs(plan.Moves) do
   local clone=move.Model:Clone();assert(clone,'Cannot back up non-archivable booth '..move.Path);clone.Name='Original '..move.Model.Name;clone:SetAttribute('OriginalPath','Workspace/Lobby/'..move.Path);clone.Parent=backup;table.insert(clones,clone)
   local snapshot={Parts={},Pivots={},Attributes={}};table.insert(transforms,snapshot)
   local all={move.Model};for _,o in ipairs(move.Model:GetDescendants()) do table.insert(all,o) end
   for _,o in ipairs(all) do
    if o:IsA('BasePart') then table.insert(snapshot.Parts,{o,o.CFrame})
    elseif o:IsA('Model') then table.insert(snapshot.Pivots,{o,o:GetPivot()}) end
    for name,value in pairs(o:GetAttributes()) do if typeof(value)=='CFrame' then table.insert(snapshot.Attributes,{o,name,value}) end end
   end
   for _,p in ipairs(snapshot.Parts) do p[1].CFrame=move.Delta*p[2] end
   for _,p in ipairs(snapshot.Pivots) do p[1].WorldPivot=move.Delta*p[2] end
   for _,a in ipairs(snapshot.Attributes) do a[1]:SetAttribute(a[2],move.Delta*a[3]) end
  end
  for _,o in ipairs(plan.Archives) do table.insert(moved,{o,o.Parent});o.Parent=backup end
  if plan.Previous then table.insert(moved,{plan.Previous,plan.Previous.Parent});plan.Previous.Parent=backup end
  arenaAnchor.CFrame=CF(0,-27,-190)
  staged.Parent=lobby
 end)
 if not ok then
  staged:Destroy();restore();for _,o in ipairs(clones) do o:Destroy() end
  error('V16 lobby rolled back: '..tostring(err))
 end
 local undone=false
 return staged,{Moves=#transforms,Archived=#moved,Undo=function()
  if undone then return end
  assert(staged.Parent==lobby,'Lobby changed after this transaction')
  staged:Destroy();restore();for _,o in ipairs(clones) do o:Destroy() end;undone=true
 end}
end
return B
