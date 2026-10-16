--!nonstrict
-- HussStandShopV12: each player browses a private shop face on a real lobby counter.
-- The economy server validates ownership, price, readiness and proximity on every Buy.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local CollectionService=game:GetService('CollectionService')
local Input=game:GetService('UserInputService')
local Gui=game:GetService('GuiService')
local P=Players.LocalPlayer
local playerGui=P:WaitForChild('PlayerGui')
local Catalog=require(RS:WaitForChild('HussCatalogV11'))
local SkinBuilder=require(RS:WaitForChild('BombSkinBuilderV12'))
local colors={Bombs=Color3.fromRGB(255,173,37),Trails=Color3.fromRGB(45,216,245),Titles=Color3.fromRGB(196,115,255),Emotes=Color3.fromRGB(255,104,174)}
local ink,white,gold,green=Color3.fromRGB(15,22,33),Color3.fromRGB(255,251,240),Color3.fromRGB(255,221,65),Color3.fromRGB(40,229,79)
local links,pageLinks={},{},{}
local active,dismissed,remote,remoteLink,cosmetics,profile,busy=nil,nil,nil,nil,nil,nil,nil
local display,elapsed,serial,alive={},0,1000000000,true
local page,chosen,message,messageOk=1,nil,'',true
local priorMouseBehavior,priorMouseIcon,cursorBound=nil,nil,false
local render,close,updateApproach
local function connect(signal,fn,bucket) local c=signal:Connect(fn);table.insert(bucket or links,c);return c end
local function clear(bucket) for _,c in ipairs(bucket) do c:Disconnect() end;table.clear(bucket) end
local function make(class,parent,properties)
 local o=Instance.new(class);for k,v in pairs(properties or {}) do o[k]=v end;o.Parent=parent;return o
end
local function rounded(o,r) make('UICorner',o,{CornerRadius=UDim.new(0,r or 12)}) end
local function edge(o,color,width) return make('UIStroke',o,{Color=color,Thickness=width or 3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function text(parent,name,value,x,y,w,h,size,color)
 local o=make('TextLabel',parent,{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,TextColor3=color or white,Font=size>=24 and Enum.Font.FredokaOne or Enum.Font.GothamBold,TextSize=size,TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=(parent:IsA('GuiObject') and parent.ZIndex or 1)+3})
 make('UIStroke',o,{Color=ink,Thickness=size>=24 and 2.2 or 1.1,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual});return o
end
local function frame(parent,name,x,y,w,h,color)
 return make('Frame',parent,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color,BorderSizePixel=0,ZIndex=(parent:IsA('GuiObject') and parent.ZIndex or 1)+1})
end
local function gloss(o,color)
 rounded(o);edge(o,ink,4)
 make('UIGradient',o,{Color=ColorSequence.new(white,Color3.fromRGB(155,202,175)),Rotation=90})
 local checker=frame(o,'Checkers',5,5,1,1,color);checker.Size=UDim2.new(1,-10,1,-10);checker.BackgroundTransparency=1;checker.ClipsDescendants=true;rounded(checker,8)
 for row=0,1 do for column=0,7 do if (row+column)%2==0 then
  local tile=frame(checker,'Tile',0,0,1,1,white);tile.Position=UDim2.fromScale(column/8,row/2);tile.Size=UDim2.fromScale(1/8,.5);tile.BackgroundTransparency=.91
 end end end
 local shine=frame(o,'Gloss',4,4,1,1,white);shine.Size=UDim2.new(1,-8,.42,0);shine.BackgroundTransparency=.86;rounded(shine,9)
 local rim=frame(o,'Rim',5,5,1,1,color);rim.Size=UDim2.new(1,-10,1,-10);rim.BackgroundTransparency=1;rounded(rim,8);edge(rim,color:Lerp(white,.55),2)
end
local function button(parent,name,caption,x,y,w,h,color,fn,disabled)
 local b=make('TextButton',parent,{Name=name,Text='',Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=disabled and Color3.fromRGB(73,94,89) or color,AutoButtonColor=not disabled,BorderSizePixel=0,Selectable=not disabled,Interactable=not disabled,ZIndex=(parent:IsA('GuiObject') and parent.ZIndex or 1)+2})
 b:SetAttribute('HussDisabled',disabled==true);gloss(b,b.BackgroundColor3)
 text(b,'Caption',caption,5,0,w-10,h,24,disabled and Color3.fromRGB(215,224,222) or white)
 connect(b.Activated,function() if not disabled and active then fn() end end,pageLinks);return b
end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function amount(v) return finite(v) and math.clamp(math.floor(v),0,2000000000) or 0 end
local function formatted(v) return tostring(amount(v)):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','') end
local function playerRoot()
 if P:GetAttribute('InRound')==true or P:GetAttribute('HussPracticeActive')==true then return nil end
 local character=P.Character;local humanoid=character and character:FindFirstChildOfClass('Humanoid')
 local root=character and character:FindFirstChild('HumanoidRootPart')
 return humanoid and humanoid.Health>0 and root and root:IsA('BasePart') and root or nil
end
local function details(anchor)
 local lobby=workspace:FindFirstChild('Lobby')
 if not anchor or not anchor:IsA('BasePart') or not lobby or not anchor:IsDescendantOf(lobby) or not CollectionService:HasTag(anchor,'HussShopStandV12') or anchor:GetAttribute('HussShopStandEnabled')~=true then return end
 local category=anchor:GetAttribute('HussShopCategory')
 local panel=anchor.Parent and anchor.Parent:FindFirstChild('ShopPanelV12')
 if not colors[category] or not panel or not panel:IsA('BasePart') or panel:GetAttribute('HussShopPanelVersion')~=12 then return end
 return category,panel
end
local function isNear(anchor,radius)
 local root=playerRoot();local category,panel=details(anchor)
 return root and category and (root.Position-anchor.Position).Magnitude<=radius and category or nil,panel
end
local function obstructingHUD()
 local hud=playerGui:FindFirstChild('BombTagHUD');local safe=hud and hud:FindFirstChild('SafeArea');local shade=safe and safe:FindFirstChild('ModalShade')
 return shade and shade.Visible==true
end
local function restoreCursor()
 if cursorBound then Run:UnbindFromRenderStep('HussStandShopCursorV12');cursorBound=false end
 if priorMouseBehavior then Input.MouseBehavior=priorMouseBehavior;priorMouseBehavior=nil end
 if priorMouseIcon~=nil then Input.MouseIconEnabled=priorMouseIcon;priorMouseIcon=nil end
end
local function unlockCursor()
 if cursorBound then return end
 priorMouseBehavior=Input.MouseBehavior;priorMouseIcon=Input.MouseIconEnabled;cursorBound=true
 Run:BindToRenderStep('HussStandShopCursorV12',Enum.RenderPriority.Last.Value,function()
  if active and not obstructingHUD() and not Input:GetFocusedTextBox() then Input.MouseBehavior=Enum.MouseBehavior.Default;Input.MouseIconEnabled=true end
 end)
end
local function dropDisplay()
 clear(pageLinks)
 if display.gui then
  if Gui.SelectedObject and Gui.SelectedObject:IsDescendantOf(display.gui) then Gui.SelectedObject=nil end
  display.gui:Destroy()
 end
 if display.idle and display.idle.Parent then display.idle.Enabled=display.idleEnabled end
 display={}
end
close=function(suppress)
 if suppress then dismissed=active end
 active=nil;dropDisplay();restoreCursor();P:SetAttribute('HussShopBrowsingV12',nil)
end
local function inventory(category)
 local result={};for _,item in ipairs(Catalog.Items) do if item.category==category then table.insert(result,item) end end;return result
end
local function request(action,id)
 if busy or not remote or not active or not isNear(active,14) then return end
 if action~='Sync' and (not profile or not profile.ready) then return end
 if action~='Sync' then
  local item=Catalog.ById[id]
  if not item or item.category~=active:GetAttribute('HussShopCategory') then return end
 end
 serial+=1;if serial>=1900000000 then serial=1000000001 end
 local ticket=serial;busy={ticket=ticket,at=time()};message='';remote:FireServer(action,id,ticket);render()
 task.delay(10,function()
  if alive and busy and busy.ticket==ticket then busy=nil;message='No reply yet. Refresh your record before trying again.';messageOk=false;if active then render() end end
 end)
end
local function preview(parent,item)
 local color=Color3.fromRGB(table.unpack(item.color))
 if item.category=='Bombs' then
  local viewport=make('ViewportFrame',parent,{Name='SelectedBombPreview',Position=UDim2.fromOffset(32,37),Size=UDim2.fromOffset(320,164),BackgroundTransparency=1,Ambient=Color3.fromRGB(213,220,233),LightColor=white,LightDirection=Vector3.new(-1,-1,-.5),ZIndex=parent.ZIndex+2})
  local world=make('WorldModel',viewport)
  local core=make('Part',world,{Name='PreviewBomb',Size=Vector3.new(2.25,2.25,2.25),Shape=Enum.PartType.Ball,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false})
  SkinBuilder.Apply(core,item,{Preview=true})
  local camera=make('Camera',viewport,{FieldOfView=34,CFrame=CFrame.lookAt(Vector3.new(5,3.5,6),Vector3.new(0,.15,0))});viewport.CurrentCamera=camera
 elseif item.category=='Trails' then
  for i=1,5 do
   local streak=frame(parent,'TrailPreview'..i,66+(i%2)*35,43+i*23,230-i*20,13,color:Lerp(white,i*.1));streak.Rotation=-13;rounded(streak,7)
  end
  local head=frame(parent,'TrailHead',260,47,60,60,color);head.Rotation=45;rounded(head,16);edge(head,ink,4)
 elseif item.category=='Titles' then
  local badge=frame(parent,'TitleBadge',26,78,332,65,color);gloss(badge,color)
  text(badge,'Title',item.text or item.name,10,2,312,59,29,white)
 else
  -- The icon advertises an emote; PLAY below runs the actual equipped pose on your avatar.
  local head=frame(parent,'EmoteHead',164,48,44,44,color);rounded(head,24);edge(head,ink,3)
  local body=frame(parent,'EmoteBody',167,95,38,60,color);rounded(body,12)
  for _,limb in ipairs({{120,98,49,16,-28},{203,83,58,16,-45},{154,146,17,46,18},{204,146,17,46,-18}}) do
   local p=frame(parent,'EmoteLimb',limb[1],limb[2],limb[3],limb[4],color);p.Rotation=limb[5];rounded(p,8)
  end
 end
end
render=function()
 if not active then return end
 local category,panel=details(active);if not category then close();return end
 local hadSelection=display.gui and Gui.SelectedObject and Gui.SelectedObject:IsDescendantOf(display.gui)
 dropDisplay()
 local gui=make('SurfaceGui',playerGui,{Name='HussStandShopV12',Adornee=panel,Face=Enum.NormalId.Back,SizingMode=Enum.SurfaceGuiSizingMode.FixedSize,CanvasSize=Vector2.new(1140,432),LightInfluence=0,Brightness=1,AlwaysOnTop=false,MaxDistance=32,Active=true,ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local idle=panel:FindFirstChild('ShopIdleV12');display={gui=gui,idle=idle,idleEnabled=idle and idle.Enabled}
 if idle then idle.Enabled=false end
 local color=colors[category]
 local body=frame(gui,'ShopFace',0,0,1140,432,ink);rounded(body,24);edge(body,color,8);body.SelectionGroup=true
 local heading=frame(body,'Header',8,8,1124,56,color);gloss(heading,color)
 text(heading,'Category',category:upper()..' EXCHANGE',15,0,500,56,37).TextXAlignment=Enum.TextXAlignment.Left
 text(heading,'Coins',profile and profile.ready and formatted(profile.Coins)..' COINS' or 'CONNECTING…',645,0,455,56,31,gold).TextXAlignment=Enum.TextXAlignment.Right
 local list=inventory(category);local pages=math.max(1,math.ceil(#list/6));page=math.clamp(page,1,pages)
 if not chosen or not Catalog.ById[chosen] or Catalog.ById[chosen].category~=category then chosen=list[1] and list[1].id end
 local selectedButton
 for index=(page-1)*6+1,math.min(page*6,#list) do
  local item=list[index];local slot=index-(page-1)*6-1;local owned=profile and profile.Owned[item.id]==true;local equipped=profile and profile.EquippedByCategory[category]==item.id
  local x,y=18+(slot%2)*357,79+math.floor(slot/2)*83
  local card=button(body,'Select_'..item.id,'',x,y,345,73,chosen==item.id and color or Color3.fromRGB(55,68,86),function() chosen=item.id;message='';render() end,false)
  text(card,'ItemName',item.name,10,4,325,31,24,white)
  text(card,'ItemStatus',equipped and 'EQUIPPED' or owned and 'OWNED' or formatted(item.price)..' COINS',10,38,325,24,19,equipped and gold or owned and green or white)
  if chosen==item.id then edge(card,gold,4);selectedButton=card end
 end
 button(body,'Previous','‹ PREVIOUS',18,335,217,48,color,function() page=math.max(1,page-1);chosen=list[(page-1)*6+1].id;render() end,page==1)
 text(body,'Page','PAGE '..page..' / '..pages,244,340,250,42,24,color)
 button(body,'Next','NEXT ›',507,335,212,48,color,function() page=math.min(pages,page+1);chosen=list[(page-1)*6+1].id;render() end,page==pages)
 local selection=frame(body,'SelectedItem',736,78,386,305,color:Lerp(ink,.87));rounded(selection,15);edge(selection,color,3)
 local item=Catalog.ById[chosen]
 if item then
  text(selection,'SelectedName',item.name:upper(),10,5,366,34,27,color:Lerp(white,.25))
  preview(selection,item)
  text(selection,'Description',item.description or '',13,198,360,40,17,white)
  local owned=profile and profile.Owned[item.id]==true;local equipped=profile and profile.EquippedByCategory[category]==item.id
  local poor=not owned and profile and profile.Coins<item.price
  local caption=busy and 'PLEASE WAIT…' or (not profile or not profile.ready) and 'CONNECTING…' or equipped and 'EQUIPPED' or owned and 'EQUIP' or poor and 'NEED '..formatted(item.price)..' COINS' or 'BUY • '..formatted(item.price)
  local ready=profile and profile.ready and remote~=nil
  local buy=button(selection,'BuyEquip',caption,12,247,category=='Emotes' and 222 or 362,47,green,function() request(owned and 'Equip' or 'Buy',item.id) end,busy~=nil or not ready or equipped or poor)
  buy.Caption.TextSize=category=='Emotes' and 20 or 24
  if category=='Emotes' then
   local playing=P:GetAttribute('HussEmotePlaying')==item.id
   button(selection,'PlayEmote',playing and 'STOP' or 'PLAY',244,247,130,47,color,function() if cosmetics and equipped and isNear(active,14) then cosmetics:FireServer(playing and 'StopEmote' or 'Emote',playing and nil or item.id) end end,not ready or not owned or not equipped or not cosmetics)
  end
 end
 local status=message~='' and message or profile and profile.mode=='preview' and 'STUDIO PREVIEW • Temporary coins and collection. Walk away to close.' or 'Earn Coins in multiplayer • Choose an item • Walk away to close'
 text(body,'Status',status,20,388,940,34,message~='' and 18 or 20,messageOk and white or gold)
 button(body,'Refresh','↻',976,386,61,44,color,function() request('Sync') end,busy~=nil).Caption.TextSize=22
 button(body,'Close','×',1048,386,64,44,Color3.fromRGB(247,65,94),function() close(true) end,false).Caption.TextSize=28
 if (hadSelection or Input:GetLastInputType().Name:find('Gamepad')) and not obstructingHUD() then Gui.SelectedObject=selectedButton or selection:FindFirstChild('BuyEquip') end
end
local function receive(data)
 if type(data)~='table' or data.kind~='Profile' then return end
 local nextProfile={ready=data.ready==true,mode=type(data.mode)=='string' and data.mode or '',Coins=amount(data.Coins),Owned={},EquippedByCategory={}}
 if type(data.Owned)=='table' then for index,id in ipairs(data.Owned) do if index>100 then break end;if type(id)=='string' and Catalog.ById[id] then nextProfile.Owned[id]=true end end end
 if type(data.EquippedByCategory)=='table' then for category in pairs(colors) do local id=data.EquippedByCategory[category];if type(id)=='string' and Catalog.ById[id] and Catalog.ById[id].category==category then nextProfile.EquippedByCategory[category]=id end end end
 profile=nextProfile
 if busy and busy.ticket==data.requestId then busy=nil;message=type(data.message)=='string' and data.message:sub(1,130) or '';messageOk=data.ok==true end
 if active then render() end
end
local function attach(child)
 if child.Name=='HussEconomyV9' and child:IsA('RemoteEvent') and child~=remote then
  if remoteLink then remoteLink:Disconnect() end;remote=child;profile=nil;busy=nil;remoteLink=connect(remote.OnClientEvent,receive)
  remote:FireServer('Sync')
 elseif child.Name=='HussCosmeticsV11' and child:IsA('RemoteEvent') then cosmetics=child end
end
updateApproach=function()
 if active and not isNear(active,14) then close() end
 if dismissed and not isNear(dismissed,14) then dismissed=nil end
 if active then return end
 local root=playerRoot();if not root then return end
 local nearest,distance=nil,12
 for _,anchor in ipairs(CollectionService:GetTagged('HussShopStandV12')) do
  if anchor~=dismissed and details(anchor) then
   local d=(root.Position-anchor.Position).Magnitude
   if d<=distance then nearest=anchor;distance=d end
  end
 end
 if nearest then
  if nearest:GetAttribute('HussShopCategory')=='Emotes' then
   dismissed=nearest -- Reopen only after walking away, using the existing collection UI.
   P:SetAttribute('HABCollectionTab','INVENTORY')
   P:SetAttribute('HABCollectionRequest',(P:GetAttribute('HABCollectionRequest') or 0)+1)
   return
  end
  active=nearest;page=1;chosen=nil;message='';messageOk=true
  P:SetAttribute('HussShopBrowsingV12',active:GetAttribute('HussShopCategory'))
  render();unlockCursor()
  if remote and not profile and not busy then request('Sync') end
 end
end
connect(RS.ChildAdded,attach)
connect(RS.ChildRemoved,function(child)
 if child==remote then if remoteLink then remoteLink:Disconnect() end;remote=nil;profile=nil;busy=nil;if active then render() end end
 if child==cosmetics then cosmetics=nil;if active then render() end end
end)
for _,child in ipairs(RS:GetChildren()) do attach(child) end
connect(P:GetAttributeChangedSignal('InRound'),updateApproach)
connect(P:GetAttributeChangedSignal('HussPracticeActive'),updateApproach)
connect(P:GetAttributeChangedSignal('HussEmotePlaying'),function() if active then render() end end)
connect(P.CharacterRemoving,function() close();dismissed=nil end)
connect(Input.InputBegan,function(input,processed)
 if not processed and active and not Input:GetFocusedTextBox() and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then close(true) end
end)
connect(Run.Heartbeat,function(dt)
 elapsed+=dt;if elapsed<.1 then return end;elapsed=0;updateApproach()
end)
connect(script.Destroying,function()
 if not alive then return end;alive=false;close();clear(links);clear(pageLinks)
 remote=nil;remoteLink=nil;cosmetics=nil;profile=nil;busy=nil
end)
updateApproach()
