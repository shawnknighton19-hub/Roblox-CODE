--!nonstrict
-- V15: an open, soft-edged bomb plaza around the user's existing functional booths.
-- Build() is pure geometry. Plan()/Apply() preserve all live booth anchors and LobbySpawn.
local B={Version=15}
local V,CF,R=Vector3.new,CFrame.new,Color3.fromRGB
local ink=R(22,30,61)
local paper=R(234,245,255)
local mist=R(192,218,236)
local cyan=R(62,230,255)
local violet=R(196,131,255)
local gold=R(255,218,48)
local grass=R(90,168,133)
local white=R(255,255,255)
local ARCHIVE_NAMES={'Promenades','Bomb fountain','North terrace','Gardens and seating','Arrival','Boundary'}
B.ArchiveNames=table.freeze(ARCHIVE_NAMES)
local LOCKER_TEXT={
 {Path='V11 Bomb Exchange/Emotes kiosk/EMOTES/HussSignV11/Body/Heading',Old='EMOTES',New='LOCKER'},
 {Path='V11 Bomb Exchange/Emotes kiosk/EMOTES/HussSignV11/Body/Subtitle',Old='SHOW YOUR STYLE',New='YOUR EFFECTS COLLECTION'},
 {Path='V11 Bomb Exchange/Emotes kiosk/ShopPanelV12/ShopIdleV12/Body/Title',Old='EMOTES EXCHANGE',New='LOCKER'},
 {Path='V11 Bomb Exchange/Emotes kiosk/ShopPanelV12/ShopIdleV12/Body/Hint',Old='WALK UP TO BROWSE',New='WALK UP TO BROWSE'},
 {Path='V11 Bomb Exchange/Emotes kiosk/ShopPanelV12/ShopIdleV12/Body/Details',Old='CELEBRATE EVERY CLOSE CALL',New='TRAILS • COSMETICS • COLLECTION'},
}

local function model(parent,name)
 local o=Instance.new('Model');o.Name=name;o.Parent=parent;return o
end
local function part(parent,name,position,size,color,solid,rotation,kind)
 local o=Instance.new(kind or 'Part');o.Name=name;o.Size=size
 o.CFrame=CF(position)*(rotation or CFrame.identity);o.Color=color;o.Material=Enum.Material.SmoothPlastic
 o.Anchored=true;o.CanCollide=solid==true;o.CanTouch=false;o.CanQuery=solid==true
 o.CastShadow=solid==true;o.TopSurface=Enum.SurfaceType.Smooth;o.BottomSurface=Enum.SurfaceType.Smooth
 o.Parent=parent;return o
end
local function cylinder(parent,name,x,y,z,diameter,height,color,solid)
 local o=part(parent,name,V(x,y,z),V(height,diameter,diameter),color,solid,CFrame.Angles(0,0,math.pi/2))
 o.Shape=Enum.PartType.Cylinder;return o
end
local function ball(parent,name,x,y,z,w,h,d,color,solid)
 local o=part(parent,name,V(x,y,z),V(w,h,d),color,solid);o.Shape=Enum.PartType.Ball;return o
end
-- Rounded rectangles are six real primitives. Tiny cap-height offsets prevent coplanar
-- overlapping faces from flickering. Flat decorations never add collision seams.
local function rounded(parent,name,x,y,z,w,h,d,r,color,solid)
 local g=model(parent,name)
 part(g,'Center',V(x,y,z),V(w-2*r,h,d),color,solid)
 part(g,'Cross',V(x,y,z),V(w,h+.002,d-2*r),color,solid)
 local cornerIndex=0
 for _,sx in ipairs({-1,1}) do for _,sz in ipairs({-1,1}) do
  cornerIndex+=1
  cylinder(g,'Corner',x+sx*(w/2-r),y,z+sz*(d/2-r),2*r,h+.004+cornerIndex*.002,color,solid)
 end end
 return g
end
local function sign(parent,title,subtitle,x,y,z,w,h,color)
 local board=part(parent,title,V(x,y,z),V(w,h,.28),ink,false)
 local gui=Instance.new('SurfaceGui');gui.Name='BubblySign';gui.Face=Enum.NormalId.Back
 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=70
 gui.LightInfluence=0;gui.AlwaysOnTop=false;gui.MaxDistance=180;gui.Parent=board
 local background=Instance.new('Frame');background.Name='Card';background.Size=UDim2.fromScale(1,1)
 background.BackgroundColor3=color;background.BorderSizePixel=0;background.Parent=gui
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.2,0);corner.Parent=background
 local stroke=Instance.new('UIStroke');stroke.Color=ink;stroke.Thickness=4;stroke.Parent=background
 local sheen=Instance.new('Frame');sheen.Name='Gloss';sheen.Position=UDim2.fromScale(.035,.055)
 sheen.Size=UDim2.fromScale(.93,.34);sheen.BackgroundColor3=white;sheen.BackgroundTransparency=.82
 sheen.BorderSizePixel=0;sheen.Parent=background
 local glossCorner=Instance.new('UICorner');glossCorner.CornerRadius=UDim.new(.4,0);glossCorner.Parent=sheen
 for i,value in ipairs({title,subtitle}) do
  local label=Instance.new('TextLabel');label.Name=i==1 and 'Heading' or 'Subtitle';label.BackgroundTransparency=1
  label.Position=UDim2.fromScale(.04,i==1 and .08 or .63);label.Size=UDim2.fromScale(.92,i==1 and .54 or .25)
  label.Text=value;label.TextScaled=true;label.TextColor3=white;label.TextStrokeColor3=ink
  label.TextStrokeTransparency=i==1 and .05 or .15;label.Font=Enum.Font.GothamBold
  label.Parent=background
 end
 return board
end
local function capsule(parent,name,x,y,z,w,h,d,color,solid)
 local g=model(parent,name)
 if w>=d then
  local r=d/2
  part(g,'Middle',V(x,y,z),V(math.max(.01,w-d),h,d),color,solid)
  for _,s in ipairs({-1,1}) do cylinder(g,'Round end',x+s*(w/2-r),y,z,d,h+.004,color,solid) end
 else
  local r=w/2
  part(g,'Middle',V(x,y,z),V(w,h,math.max(.01,d-w)),color,solid)
  for _,s in ipairs({-1,1}) do cylinder(g,'Round end',x,y,z+s*(d/2-r),w,h+.004,color,solid) end
 end
 return g
end
local function safety(parent,name,x,z,w,d,y)
 -- Smooth capsule edges use six pieces, with no posts or ornate rail clutter.
 capsule(parent,name,x,y+1.35,z,w,2.7,d,ink,true)
 capsule(parent,name..' cushion',x,y+2.78,z,w+.08,.22,d+.08,mist,false)
end
local function tree(parent,x,z)
 local g=model(parent,'Soft planter')
 cylinder(g,'Planter',x,.8,z,11,1.6,ink,true)
 cylinder(g,'Rim',x,1.67,z,11.4,.15,mist,false)
 cylinder(g,'Grass',x,1.78,z,10.2,.08,grass,false)
 cylinder(g,'Trunk',x,4,z,1.1,4.5,R(124,92,78),false)
 ball(g,'Canopy',x,8.3,z,9.5,8.1,9.5,grass,false)
 ball(g,'Crown',x-1.5,10.1,z+.2,6.6,5.8,6.6,R(133,207,159),false)
end
local function booth(parent,name,title,subtitle,x,z,color,panel)
 local g=model(parent,name)
 g:SetAttribute('HABPolishV15Booth',true)
 rounded(g,'Base',x,.22,z,18,.44,11,2,ink,false)
 part(g,'Counter',V(x,1.75,z+1.1),V(14,3.5,4),ink,true)
 rounded(g,'Counter top',x,3.55,z+1.1,15,.4,4.8,1.8,color,false)
 for _,s in ipairs({-1,1}) do
  cylinder(g,'Pillar',x+s*7.1,7,z-3,1.05,14,ink,true)
 end
 rounded(g,'Canopy',x,14,z,18.5,.8,10,2,color,false)
 part(g,'Canopy gleam',V(x,14.45,z+3),V(13,.08,.3),white,false)
 sign(g,title,subtitle,x,10.8,z+2.3,15,4.5,color)
 local socket=part(g,'BrowseStand',V(x,4.2,z+5.5),V(1,1,1),color,false);socket.Transparency=1
 local prompt=Instance.new('ProximityPrompt');prompt.Name='BrowsePolishedStand';prompt.ActionText='Browse'
 prompt.ObjectText=title;prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX
 prompt.MaxActivationDistance=12;prompt.HoldDuration=0;prompt.RequiresLineOfSight=false
 prompt:SetAttribute('HABOpenPanel',panel);prompt:SetAttribute('HABOffer','');prompt.Parent=socket
 return g
end
function B.Build(parent,origin)
 origin=origin or CF(0,1.5,86.66000366210938)
 local root=model(parent,'HABPolishedLobbyV15');root:SetAttribute('HABLobbyPolishVersion',15)
 root:SetAttribute('MapWidth',204);root:SetAttribute('MapDepth',188)
 local plaza=model(root,'Open plaza')
 rounded(plaza,'Soft dark border',0,.025,5,164,.04,150,19,ink,false)
 rounded(plaza,'Ivory paving',0,.060,5,161,.020,147,18,paper,false)
 -- Wide paths, no decorative bollards, steps, or obstacles across circulation routes.
 rounded(plaza,'Arrival lane',0,.085,49,24,.008,68,9,mist,false)
 rounded(plaza,'Shop lane',0,.101,3,162,.008,25,10,mist,false)
 for _,s in ipairs({-1,1}) do
  rounded(plaza,'Shop apron',s*77,.120,3,18,.008,76,5,paper,false)
  rounded(plaza,'Color marker',s*77,.140,3,2,.008,58,0.8,s<0 and cyan or violet,false)
 end
 local focal=model(root,'Bomb landmark')
 cylinder(focal,'Low round pedestal',0,.4,0,16,.8,ink,true)
 cylinder(focal,'Bright lip',0,.84,0,15.8,.08,cyan,false)
 cylinder(focal,'Soft top',0,.9,0,14.7,.1,mist,false)
 local bomb=ball(focal,'Bomb',0,5.7,0,9.6,9.6,9.6,ink,true);bomb.Material=Enum.Material.Metal
 cylinder(focal,'Fuse collar',0,10.3,0,2.4,1.1,gold,false)
 local fuse=part(focal,'Bent fuse',V(.65,11.35,0),V(.7,2.2,.7),gold,false,CFrame.Angles(0,0,-.55))
 ball(focal,'Fuse cap',1.2,12.25,0,1.3,1.3,1.3,gold,false)
 ball(focal,'Soft highlight',-2.6,7.8,3.15,1.8,2.1,.25,paper,false)
 sign(focal,'HUSS A BOMB','RUN  •  DODGE  •  PASS',0,2.25,7.9,13,3.1,cyan)
 local north=model(root,'Leaderboard terrace')
 -- Existing leaderboard feet are Y+5; the retained overlook is also Y+5.
 part(north,'Deck',V(0,2.5,-68),V(148,5,44),mist,true)
 rounded(north,'Deck top',0,5.025,-68,147,.04,43,3,paper,false)
 for _,s in ipairs({-1,1}) do
  local x=s*54
  local ramp=part(north,'No-jump ramp',V(x,2.5,-34),V(28,5,24),mist,true,CFrame.Angles(0,math.pi,0),'WedgePart')
  ramp:SetAttribute('NoJumpRoute',true);ramp:SetAttribute('Rise',5);ramp:SetAttribute('Run',24)
  part(north,'Ramp accent',V(x,2.51,-34),V(2,.025,math.sqrt(24*24+25)),cyan,false,CFrame.Angles(math.atan(5/24),0,0))
  safety(north,'Terrace outer rail',s*73,-68,1.5,44,5)
  safety(north,'Terrace inner front',s*19.5,-46,39,1.5,5)
  safety(north,'Terrace outer front',s*71,-46,6,1.5,5)
  -- Leave the current overlook's 18-stud connector clear at the north center.
  safety(north,'Rear rail',s*41.5,-89,64,1.5,5)
 end
 local edges=model(root,'Quiet edges')
 for _,s in ipairs({-1,1}) do
  safety(edges,'Side edge',s*100,0,2.5,184,0)
  safety(edges,'Arrival edge',s*53,92,94,2.5,0)
  tree(edges,s*88,74)
 end
 -- Two clearly signed destinations reuse the existing server-authoritative expansion UI.
 local shops=model(root,'Utility booths')
 booth(shops,'Abilities booth','ABILITIES','PICK YOUR PLAYSTYLE',-54,50,cyan,'ABILITIES')
 booth(shops,'Passes booth','PASSES','PERMANENT PERKS',54,50,gold,'PASSES')
 for _,o in ipairs(root:GetDescendants()) do
  if o:IsA('BasePart') then o.CFrame=origin*o.CFrame end
 end
 return root
end
local function exact(parent,name,class)
 local found
 for _,o in ipairs(parent:GetChildren()) do if o.Name==name then assert(not found,'Duplicate '..name);found=o end end
 assert(found and found:IsA(class),'Expected '..parent:GetFullName()..'/'..name..' ('..class..')');return found
end
function B.Plan(lobby)
 assert(lobby and lobby:IsA('Model'),'Workspace/Lobby must be a Model')
 local spawn=exact(lobby,'LobbySpawn','SpawnLocation');local floor=exact(lobby,'Floor','BasePart')
 assert(math.abs(floor.Size.X-204)<.05 and math.abs(floor.Size.Z-188)<.05 and math.abs(floor.Size.Y-6)<.05,'Lobby footprint differs; preserve the current lobby for review')
 assert(math.abs(floor.CFrame.UpVector.Y-1)<.001,'Lobby floor is tilted; cannot safely build a level plaza')
 local origin=floor.CFrame*CF(0,floor.Size.Y/2,0)
 local rel=origin:PointToObjectSpace(spawn.Position)
 assert(math.abs(rel.X)<1 and math.abs(rel.Z-64)<1 and math.abs(rel.Y-.5)<1,'LobbySpawn does not match the verified no-jump plaza')
 local exchange=exact(lobby,'V11 Bomb Exchange','Model')
 local anchors={Bombs=V(-79.5,5.5,-17),Trails=V(-79.5,5.5,20),Titles=V(79.5,5.5,-17),Emotes=V(79.5,5.5,20)}
 for _,name in ipairs({'Bombs','Trails','Titles','Emotes'}) do
  local kiosk=exact(exchange,name..' kiosk','Model');local anchor=exact(kiosk,'Browse '..name,'BasePart')
  assert((origin:PointToObjectSpace(anchor.Position)-anchors[name]).Magnitude<.1,'The '..name..' stand moved; review its approach before rebuilding')
 end
 exact(exchange,'Lobby leaderboards','Model')
 local expansion=exact(lobby,'HABExpansionLobby','Model')
 for _,name in ipairs({'Bundle_Cyber','Bundle_Solar','Bundle_Glacier','Bundle_Phantom','CrateStand','SpectatorOverlook','InvisibleLobbyBarrier'}) do
  exact(expansion,name,'Model')
 end
 local bundleAnchors={Bundle_Cyber=V(-28,3.6,68.3),Bundle_Glacier=V(28,3.6,68.3),Bundle_Solar=V(52,3.6,-7.7),Bundle_Phantom=V(-52,3.6,-7.7),CrateStand=V(68,3.8,35.5)}
 for name,position in pairs(bundleAnchors) do
  local anchor=exact(expansion:FindFirstChild(name),'BrowseStand','BasePart')
  assert((origin:PointToObjectSpace(anchor.Position)-position).Magnitude<.1,'The '..name..' stand moved; review its approach before rebuilding')
 end
 local replace=lobby:FindFirstChild('HABPolishedLobbyV15')
 if replace then assert(replace:IsA('Model') and replace:GetAttribute('HABLobbyPolishVersion')==15,'Unrecognized existing HABPolishedLobbyV15') end
 local move={}
 for _,name in ipairs(ARCHIVE_NAMES) do local o=lobby:FindFirstChild(name);if o then assert(o:IsA('Model'),'Unexpected old architecture '..name);table.insert(move,o) end end
 local labels={}
 for _,entry in ipairs(LOCKER_TEXT) do
  local label=lobby
  for name in entry.Path:gmatch('[^/]+') do label=exact(label,name,'Instance') end
  assert(label:IsA('TextLabel') and (label.Text==entry.Old or label.Text==entry.New),'Unrecognized locker sign text at '..entry.Path)
  if label.Text~=entry.New then table.insert(labels,{Label=label,Old=label.Text,New=entry.New,Path=entry.Path}) end
 end
 return {Lobby=lobby,Origin=origin,Move=move,Previous=replace,Spawn=spawn,Floor=floor,LabelChanges=labels}
end
function B.Apply(lobby,backup)
 assert(backup and backup:IsA('Folder') and backup:IsDescendantOf(game:GetService('ServerStorage')),'Provide a backup Folder inside ServerStorage before applying')
 local plan=B.Plan(lobby)
 -- Everything that can fail during construction happens before live objects are moved.
 local staged=B.Build(nil,plan.Origin)
 local moved={}
 local labelBackup=Instance.new('Folder');labelBackup.Name='LobbySignTextV15'
 for i,entry in ipairs(plan.LabelChanges) do
  local record=Instance.new('StringValue');record.Name='OriginalText'..i;record.Value=entry.Old
  record:SetAttribute('OriginalPath','Workspace/Lobby/'..entry.Path);record:SetAttribute('InstalledText',entry.New);record.Parent=labelBackup
 end
 local function restoreLabels()
  for _,entry in ipairs(plan.LabelChanges) do entry.Label.Text=entry.Old end
  labelBackup:Destroy()
 end
 local ok,err=pcall(function()
  for _,o in ipairs(plan.Move) do table.insert(moved,{o,o.Parent});o.Parent=backup end
  if plan.Previous then table.insert(moved,{plan.Previous,plan.Previous.Parent});plan.Previous.Parent=backup end
  staged.Parent=lobby
  for _,entry in ipairs(plan.LabelChanges) do entry.Label.Text=entry.New end
  if #plan.LabelChanges>0 then labelBackup.Parent=backup else labelBackup:Destroy() end
 end)
 if not ok then
  staged:Destroy()
  restoreLabels()
  for i=#moved,1,-1 do moved[i][1].Parent=moved[i][2] end
  error('Lobby polish rolled back: '..tostring(err))
 end
 local undone=false
 local function undo()
  if undone then return end
  assert(staged.Parent==lobby,'Lobby changed after this transaction; preserve it for review')
  staged:Destroy()
  restoreLabels()
  for i=#moved,1,-1 do moved[i][1].Parent=moved[i][2] end
  undone=true
 end
 return staged,{Archived=#moved,PreservedSpawn=plan.Spawn,PreservedFloor=plan.Floor,SignChanges=#plan.LabelChanges,Undo=undo}
end
return B
