--!nonstrict
-- HAB EXPANSION 7. Same reference theme as the existing HUD, inventory and Gems screens.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Market=game:GetService('MarketplaceService')
local Input=game:GetService('UserInputService')
local Prompts=game:GetService('ProximityPromptService')
local me=Players.LocalPlayer
local X=RS:WaitForChild('HABExpansion')
local Config=require(X.Config)
local Pack=RS:WaitForChild('HABHalloween')
local T=require(Pack.HABReferenceTheme)()
local C=T.C
-- V15: store previews use game silhouettes; only Trail keeps PNG particles.
local Modal=require(RS:WaitForChild('HABModalV15'))
local Skins=require(RS.HussCatalogV11)
local Builder=require(RS.BombSkinBuilderV12)
local links,pageLinks,previews,views={},{},{},{}
local state={Ready=false,Passes={},Bundles={},Ability=Config.DefaultAbility}
local prices={};local busy=false;local current='ABILITIES';local chosen=nil;local dead=false
local render,show,hide,request
local function make(cls,parent,props) local p=Instance.new(cls);for k,v in pairs(props or {}) do p[k]=v end;p.Parent=parent;return p end
local function link(e,f,ls) local c=e:Connect(f);local b=ls or links;b[#b+1]=c;return c end
local function rect(o,x,y,w,h) o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(w,h) end
local function text(p,value,size,color)
 local t=T.Text(p,'Caption',value,0,0,100,26,size,color or C.white);t.TextWrapped=true;t.TextTruncate=Enum.TextTruncate.None;t.ZIndex=p.ZIndex+15;return t
end
local function button(p,name,value,color,fn,bucket)
 T.Tones[name]=color
 local b=T.Button(p,name,value,fn,false,bucket or pageLinks)
 local d=p.ZIndex+20-b.ZIndex;b.ZIndex=b.ZIndex+d
 for _,o in ipairs(b:GetDescendants()) do if o:IsA('GuiObject') then o.ZIndex=o.ZIndex+d end end
 return b
end
local gui=make('ScreenGui',me:WaitForChild('PlayerGui'),{Name='HABExpansionGui',ResetOnSpawn=false,DisplayOrder=212,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local backdrop=make('TextButton',gui,{Size=UDim2.fromScale(1,1),Text='',Modal=true,AutoButtonColor=false,BackgroundColor3=C.ink,BackgroundTransparency=.32,BorderSizePixel=0,Visible=false})
local panel=T.Panel(backdrop,'ExpansionWindow',980,680,3,C.cyan);panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
local scale=make('UIScale',panel,{Scale=1})
local title=text(panel,'ABILITIES',32,C.white);rect(title,24,31,830,42)
local brand=text(panel,'H U S S  A  B O M B',11,C.green);rect(brand,24,13,800,17)
local close=button(panel,'ExpansionClose','X',C.red,function() hide() end,links)
local body=make('ScrollingFrame',panel,{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(22,146),Size=UDim2.fromOffset(936,469),CanvasSize=UDim2.new(),ScrollBarThickness=5,ScrollBarImageColor3=C.cyan,ZIndex=25})
local notice=text(panel,'',13,C.gold);rect(notice,24,628,920,30)
local tabs={};local width=980
local function clear()
 for _,l in ipairs(pageLinks) do l:Disconnect() end;table.clear(pageLinks)
 for _,p in ipairs(previews) do if p.Stop then p:Stop() end end;table.clear(previews);table.clear(views)
 body:ClearAllChildren()
end
local function apiPrice(key,id)
 local offer=state.Offers and state.Offers[key]
 if not offer then return state.Ready and 'COMING SOON' or 'LOADING...',false end
 if offer.Available~=true or type(offer.PriceInRobux)~='number' then return 'COMING SOON',false end
 id=offer.Id
 local cached=prices[id]
 if not cached then
  prices[id]={Loading=true}
  task.spawn(function()
   local ok,info=pcall(Market.GetProductInfoAsync,Market,id,Enum.InfoType.GamePass)
   prices[id]=ok and type(info)=='table' and info.IsForSale and type(info.PriceInRobux)=='number' and {Price=info.PriceInRobux} or {Failed=true}
   if not dead and backdrop.Visible then render() end
  end)
 end
 -- Server verifies configuration; client query supports local price. Roblox confirms the final charge.
 return 'R$ '..tostring(cached and cached.Price or offer.PriceInRobux),true
end
local function preview(p,id,x,y,w,h)
 local frame=make('Frame',p,{BackgroundColor3=C.ink,BackgroundTransparency=.05,BorderSizePixel=0,ClipsDescendants=true,ZIndex=p.ZIndex+16})
 rect(frame,x,y,w,h);T.Rounded(frame,10)
 local icon=T.Emblem(frame,'Bombs',math.min(w,h)*.8,C.gold);icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5)
end
local function bombView(p,skin,x,y,w,h)
 local view=make('ViewportFrame',p,{BackgroundTransparency=1,BorderSizePixel=0,Ambient=Color3.fromRGB(175,185,209),LightColor=C.white,LightDirection=Vector3.new(-1,-1,-1),ZIndex=p.ZIndex+16})
 rect(view,x,y,w,h)
 local world=make('WorldModel',view);local cam=make('Camera',view,{FieldOfView=35,CFrame=CFrame.lookAt(Vector3.new(5,3.5,7),Vector3.new(0,.35,0))});view.CurrentCamera=cam
 local model=make('Model',world);local ball=make('Part',model,{Name='Bomb',Shape=Enum.PartType.Ball,Size=Vector3.new(2.25,2.25,2.25),Anchored=true,CanCollide=false,CFrame=CFrame.identity})
 Builder.Apply(ball,Skins.ById[skin],{Preview=true});model.PrimaryPart=ball
 views[#views+1]=model
end
request=function(action,key)
 if busy then return end;busy=true
 task.spawn(function()
  local ok,res=pcall(X.Api.InvokeServer,X.Api,action,key)
  busy=false;if dead then return end
  if ok and type(res)=='table' then
   if res.Profile then state=res.Profile end
   notice.Text=res.Message or ''
   if res.OK and res.PassId then
    local passOk,why=pcall(Market.PromptGamePassPurchase,Market,me,res.PassId)
    if not passOk then notice.Text='Purchase prompt unavailable: '..tostring(why) end
   end
  else notice.Text='Connection interrupted. Try again.' end
  if backdrop.Visible then render() end
 end)
end
render=function()
 clear();title.Text=current
 for name,b in pairs(tabs) do b:SetAttribute('HussSelected',name==current) end
 local bw=width-52;local gap=14;local cols=bw>690 and 2 or 1;local cw=(bw-gap*(cols-1))/cols
 local y=0;local count=0
 if current=='ABILITIES' then
  local compact=bw<500
  local caption=text(body,'ONE EQUIPPED ABILITY  •  ALL THREE ARE FREE  •  CHANGE IN THE LOBBY',compact and 11 or 13,C.gold);rect(caption,5,0,bw-10,compact and 45 or 34);y=compact and 53 or 44
  for _,a in ipairs(Config.Abilities) do
   local h=compact and 285 or 190
   local f=T.Panel(body,'Ability_'..a.Key,bw-8,h,27,a.Color);rect(f,4,y,bw-8,h)
   preview(f,a.Effect,12,compact and 55 or 16,compact and 106 or 144,compact and 115 or 148)
   local name=text(f,a.Name,compact and 21 or 22,a.Color);rect(name,compact and 14 or 170,13,compact and bw-38 or bw-203,34)
   local desc=text(f,a.Description,compact and 12 or 14,C.white);rect(desc,compact and 132 or 170,compact and 56 or 50,compact and bw-163 or bw-202,compact and 128 or 67)
   local b=button(f,'Equip_'..a.Key,state.Ability==a.Key and 'EQUIPPED' or 'EQUIP • FREE',C.green,function() request('SelectAbility',a.Key) end)
   rect(b,compact and 14 or 170,compact and h-58 or 130,compact and bw-40 or math.max(90,bw-202),43);b.TextSize=16;b:SetAttribute('HussDisabled',busy or not state.Ready or state.Ability==a.Key)
   local cd=text(f,a.Cooldown..'s COOLDOWN',11,C.gold);rect(cd,12,compact and 190 or 167,compact and bw-36 or 144,24)
   y=y+h+14
  end
 elseif current=='BUNDLES' then
  local compact=cw<360;local h=compact and 400 or 352;local stride=h+16
  for _,bundle in ipairs(Config.Bundles) do
   local col=count%cols;local row=math.floor(count/cols);count=count+1
   local f=T.Panel(body,'Bundle_'..bundle.Key,cw-8,h,27,bundle.Color);rect(f,col*(cw+gap)+4,row*stride,cw-8,h)
   local heading=text(f,bundle.Name,compact and 19 or 22,bundle.Color);rect(heading,13,9,cw-36,35)
   local exclusive=text(f,'BUNDLE-EXCLUSIVE EDITIONS • GUARANTEED ITEMS',10,C.gold);rect(exclusive,13,43,cw-36,compact and 33 or 22)
   local artY=compact and 82 or 68
   bombView(f,bundle.Skin,10,artY,(cw-30)*.47,130)
   preview(f,bundle.Items[1].Id,cw*.49,artY,cw*.45-16,130)
   local list=bundle.SkinName..' bomb'
   for _,fx in ipairs(bundle.Items) do list=list..'  +  '..fx.Name end
   local contents=text(f,list,13,C.white);rect(contents,14,artY+141,cw-36,compact and 106 or 66)
   local owned=state.Passes and state.Passes[bundle.Key]
   local price,ready=apiPrice(bundle.Key,bundle.Id)
   local b=button(f,'BundleBuy_'..bundle.Key,owned and 'EQUIP BUNDLE' or 'UNLOCK • '..price,bundle.Color,function()
    request(owned and 'EquipBundle' or 'PassPrompt',bundle.Key)
   end)
   rect(b,14,h-61,cw-36,43);b.TextSize=compact and 14 or 17;b:SetAttribute('HussDisabled',busy or not state.Ready or (not owned and not ready))
  end
  y=math.ceil(count/cols)*stride
 else
  local compact=bw<500
  for _,pass in ipairs(Config.Passes) do
   local h=compact and 250 or 177
   local f=T.Panel(body,'Pass_'..pass.Key,bw-8,h,27,pass.Color);rect(f,4,y,bw-8,h)
   local em=T.Emblem(f,pass.Key=='FastOpen' and 'CRATES' or 'STATS',compact and 80 or 96,pass.Color);em.Position=UDim2.fromOffset(16,compact and 62 or 22)
   local name=text(f,pass.Name:upper(),compact and 22 or 25,pass.Color);rect(name,compact and 14 or 127,12,compact and bw-40 or bw-158,34)
   local desc=text(f,pass.Description,compact and 12 or 14,C.white);rect(desc,compact and 112 or 127,compact and 55 or 48,compact and bw-145 or bw-158,compact and 115 or 55)
   local owned=state.Passes and state.Passes[pass.Key]
   local price,ready=apiPrice(pass.Key,pass.Id)
   local b=button(f,'PassBuy_'..pass.Key,owned and 'OWNED' or 'UNLOCK • '..price,pass.Color,function() request('PassPrompt',pass.Key) end)
   rect(b,compact and 14 or 127,h-60,compact and bw-40 or bw-158,42);b:SetAttribute('HussDisabled',busy or owned or not ready);b.TextSize=compact and 15 or 18
   y=y+h+15
  end
 end
 body.CanvasSize=UDim2.fromOffset(0,y+10)
end
hide=function()
 backdrop.Visible=false;Modal.Release('store');me:SetAttribute('HABExpansionOpen',false);clear()
end
show=function(tab,key)
 if me:GetAttribute('InRound')==true then return end
 if tab=='ABILITIES' then
  hide()
  me:SetAttribute('HABAbilityMenuRequest',(me:GetAttribute('HABAbilityMenuRequest') or 0)+1)
  return
 end
 current=(tab=='ABILITIES' or tab=='BUNDLES' or tab=='PASSES') and tab or 'BUNDLES'
 Modal.Acquire('store',hide)
 chosen=key;backdrop.Visible=true;me:SetAttribute('HABExpansionOpen',true);notice.Text='';render();request('Sync')
end
for i,name in ipairs({'ABILITIES','BUNDLES','PASSES','ROBUX'}) do
 local color=({ABILITIES=C.cyan,BUNDLES=C.violet,PASSES=C.gold,ROBUX=C.green})[name]
 tabs[name]=button(panel,'ExpansionTab_'..name,name,color,function()
  if name=='ROBUX' then hide();me:SetAttribute('HABCollectionTab','GEMS');me:SetAttribute('HABCollectionRequest',(me:GetAttribute('HABCollectionRequest') or 0)+1)
  elseif name=='ABILITIES' then show('ABILITIES')
  else current=name;render() end
 end,links)
end
link(me:GetAttributeChangedSignal('HABExpansionRequest'),function() show(me:GetAttribute('HABExpansionTab')) end)
link(me:GetAttributeChangedSignal('HABCollectionRequest'),hide)
link(me:GetAttributeChangedSignal('InRound'),function() if me:GetAttribute('InRound') then hide() end end)
link(Prompts.PromptTriggered,function(prompt,p)
 if p~=me or me:GetAttribute('InRound') then return end
 local kind=prompt:GetAttribute('HABOpenPanel')
 if kind=='CRATES' or kind=='INVENTORY' then hide();me:SetAttribute('HABCollectionTab',kind);me:SetAttribute('HABCollectionRequest',(me:GetAttribute('HABCollectionRequest') or 0)+1)
 elseif kind then show(kind,prompt:GetAttribute('HABOffer')) end
end)
link(Input.InputBegan,function(i,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if i.KeyCode==Enum.KeyCode.B and not me:GetAttribute('InRound') then if backdrop.Visible then hide() else show('BUNDLES') end
 elseif backdrop.Visible and (i.KeyCode==Enum.KeyCode.Escape or i.KeyCode==Enum.KeyCode.ButtonB) then hide() end
end)
link(Market.PromptGamePassPurchaseFinished,function(p) if p==me then task.delay(.4,function() if not dead then request('RefreshPasses') end end) end end)
local at=0;local syncAt=0;local lastSize=Vector2.zero
local standDisplays={};local standAt=0
link(Run.RenderStepped,function()
 if me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true then return end
 local now=os.clock();local cam=workspace.CurrentCamera;if not cam then return end
 if now>standAt then
  standAt=now+3;standDisplays={}
  local lobby=workspace:FindFirstChild('Lobby');local root=lobby and lobby:FindFirstChild('HABExpansionLobby')
  if root then for _,m in ipairs(root:GetDescendants()) do
   if m:IsA('Model') and m:GetAttribute('HABDisplay') then standDisplays[#standDisplays+1]={m,m:GetAttribute('HABDisplayOrigin')} end
  end end
 end
 for _,entry in ipairs(standDisplays) do
  local m,base=entry[1],entry[2]
  if m.Parent and typeof(base)=='CFrame' and (base.Position-cam.CFrame.Position).Magnitude<90 then
   m:PivotTo(base*CFrame.new(0,math.sin(now*1.3)*.14,0)*CFrame.Angles(0,now*.38,0))
  end
 end
end)
link(Run.RenderStepped,function(dt)
 if not backdrop.Visible then return end
 local screen=backdrop.AbsoluteSize
 local s=1;local ww=math.min(980,screen.X-24);local hh=math.min(680,screen.Y-24)
 scale.Scale=s;panel.Size=UDim2.fromOffset(ww,hh)
 if screen~=lastSize then
  lastSize=screen;width=ww;rect(title,24,31,ww-105,42);rect(close,ww-62,18,40,40)
  body.Size=UDim2.fromOffset(ww-44,math.max(80,hh-211));rect(notice,24,hh-52,ww-48,30)
  for i,name in ipairs({'ABILITIES','BUNDLES','PASSES','ROBUX'}) do local b=tabs[name];rect(b,22+(i-1)*(ww-44)/4,87,(ww-44)/4-8,40);b.TextSize=ww<530 and 12 or 17 end
  render()
 end
 for _,model in ipairs(views) do if model.Parent then model:PivotTo(CFrame.Angles(0,math.sin(os.clock()*.45)*.35,0)) end end
 if os.clock()>syncAt then syncAt=os.clock()+5;if not busy then request('Sync') end end
end)
-- V15: removed ambient pack spam around the lobby booths.
link(script.Destroying,function() dead=true;hide();for _,l in ipairs(links) do l:Disconnect() end;T.Destroy();gui:Destroy() end)
print('[HAB Expansion UI] Matching abilities, bundles, passes and Robux navigation ready.')

-- HAB_PLAY_POLISH_8

-- HAB_FUN_9
