--!nonstrict
-- HussShopStandsV12. Apply only to a staged Lobby clone, never a live world.
local S={}
local CollectionService=game:GetService('CollectionService')
local categories={'Bombs','Trails','Titles','Emotes'}
local colors={Bombs=Color3.fromRGB(255,173,37),Trails=Color3.fromRGB(45,216,245),Titles=Color3.fromRGB(196,115,255),Emotes=Color3.fromRGB(255,104,174)}
local ink,white=Color3.fromRGB(15,22,33),Color3.fromRGB(255,250,239)
local function make(class,parent,properties)
 local o=Instance.new(class);for k,v in pairs(properties) do o[k]=v end;o.Parent=parent;return o
end
local function label(parent,name,value,y,height,size,color)
 local o=make('TextLabel',parent,{Name=name,Text=value,Position=UDim2.fromOffset(24,y),Size=UDim2.new(1,-48,0,height),BackgroundTransparency=1,Font=Enum.Font.FredokaOne,TextSize=size,TextColor3=color or white,TextWrapped=true,ZIndex=4})
 make('UIStroke',o,{Color=ink,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual});return o
end
local function stations(lobby)
 assert(lobby and lobby:IsA('Model'),'V12 shops need a Lobby Model.')
 local exchange=lobby:FindFirstChild('V11 Bomb Exchange')
 assert(exchange and exchange:IsA('Model'),'V12 shops need the verified V11 Bomb Exchange inside Lobby.')
 local found={}
 for _,category in ipairs(categories) do
  local station=exchange:FindFirstChild(category..' kiosk')
  assert(station and station:IsA('Model'),'Missing lobby '..category..' kiosk.')
  local anchor=station:FindFirstChild('Browse '..category)
  local counter=station:FindFirstChild('Counter')
  local prompt=anchor and anchor:FindFirstChild('BrowseShop')
  assert(anchor and anchor:IsA('BasePart') and counter and counter:IsA('BasePart'),'Missing '..category..' shop approach anchor or counter.')
  assert(prompt and prompt:IsA('ProximityPrompt') and prompt:GetAttribute('HussShopCategory')==category,'Unexpected '..category..' shop prompt; not overwritten.')
  table.insert(found,{category=category,station=station,anchor=anchor,counter=counter,prompt=prompt})
 end
 return found
end
function S.Validate(lobby)
 assert(lobby:GetAttribute('HussShopVersion')==12,'Lobby walk-up shops are not V12.')
 for _,entry in ipairs(stations(lobby)) do
  local panel=entry.station:FindFirstChild('ShopPanelV12')
  assert(panel and panel:IsA('BasePart') and panel:GetAttribute('HussShopPanelVersion')==12,'Missing V12 physical panel for '..entry.category..'.')
  assert(panel.Anchored and not panel.CanCollide and not panel.CanTouch and panel.CanQuery,'Shop panel flags changed for '..entry.category..'.')
  assert(panel.Size==Vector3.new(19,7.2,.24),'Unexpected shop panel size for '..entry.category..'.')
  assert(entry.anchor:GetAttribute('HussShopCategory')==entry.category and entry.anchor:GetAttribute('HussShopStandEnabled')==true and CollectionService:HasTag(entry.anchor,'HussShopStandV12'),'Invalid V12 approach anchor for '..entry.category..'.')
  assert(entry.prompt.Enabled==false,'Legacy shop prompt still enabled for '..entry.category..'.')
  local idle=panel:FindFirstChild('ShopIdleV12')
  assert(idle and idle:IsA('SurfaceGui') and idle.Face==Enum.NormalId.Back,'Missing idle shop face for '..entry.category..'.')
 end
 return true
end
function S.Apply(lobby)
 if lobby:GetAttribute('HussShopVersion')==12 then S.Validate(lobby);return lobby end
 assert(lobby:GetAttribute('HussShopVersion')==nil,'Unrecognized lobby shop version; not overwritten.')
 local entries=stations(lobby)
 -- Check every name before editing the staged clone.
 for _,entry in ipairs(entries) do
  assert(not entry.station:FindFirstChild('ShopPanelV12'),'Unrecognized ShopPanelV12 in '..entry.category..'; not overwritten.')
  assert(entry.anchor:GetAttribute('HussShopCategory')==nil and entry.anchor:GetAttribute('HussShopStandEnabled')==nil,'Unrecognized shop anchor metadata in '..entry.category..'; not overwritten.')
 end
 for _,entry in ipairs(entries) do
  local category,color=entry.category,colors[entry.category]
  -- Counter's local center is (0,2,4.7). Its outward face is local +Z.
  -- The panel covers the counter front, below the existing overhead sign.
  local panel=make('Part',entry.station,{Name='ShopPanelV12',Size=Vector3.new(19,7.2,.24),CFrame=entry.counter.CFrame*CFrame.new(0,2.3,2.67),Color=ink,Material=Enum.Material.SmoothPlastic,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=true,CastShadow=false,TopSurface=Enum.SurfaceType.Smooth,BottomSurface=Enum.SurfaceType.Smooth})
  panel:SetAttribute('HussShopPanelVersion',12)
  local gui=make('SurfaceGui',panel,{Name='ShopIdleV12',Face=Enum.NormalId.Back,SizingMode=Enum.SurfaceGuiSizingMode.FixedSize,CanvasSize=Vector2.new(1140,432),LightInfluence=0,Brightness=1,AlwaysOnTop=false,MaxDistance=90,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
  local body=make('Frame',gui,{Name='Body',Size=UDim2.fromScale(1,1),BackgroundColor3=color,BorderSizePixel=0,ClipsDescendants=true})
  make('UICorner',body,{CornerRadius=UDim.new(0,26)});make('UIStroke',body,{Color=ink,Thickness=12,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
  make('UIGradient',body,{Color=ColorSequence.new(white,Color3.fromRGB(120,167,161)),Rotation=90})
  for row=0,3 do for column=0,11 do if (row+column)%2==0 then
   make('Frame',body,{Name='Checker',Position=UDim2.fromScale(column/12,row/4),Size=UDim2.fromScale(1/12,1/4),BackgroundColor3=white,BackgroundTransparency=.9,BorderSizePixel=0,ZIndex=2})
  end end end
  label(body,'Title',category:upper()..' EXCHANGE',60,98,72)
  label(body,'Hint','WALK UP TO BROWSE',170,76,51)
  label(body,'Details',category=='Bombs' and '25 SIGNATURE BOMBS • EARN / COLLECT / EQUIP' or category=='Trails' and '25 TRAIL EFFECTS • MAKE AN ENTRANCE' or category=='Titles' and 'FIND YOUR NAME • SHOW YOUR STYLE' or 'CELEBRATE EVERY CLOSE CALL',274,56,28)
  entry.prompt.Enabled=false
  entry.anchor:SetAttribute('HussShopCategory',category)
  entry.anchor:SetAttribute('HussShopStandEnabled',true)
  entry.anchor:SetAttribute('HussShopRadius',12)
  CollectionService:AddTag(entry.anchor,'HussShopStandV12')
 end
 lobby:SetAttribute('HussShopVersion',12);S.Validate(lobby);return lobby
end
return S
