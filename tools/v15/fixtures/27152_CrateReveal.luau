--!nonstrict
-- HAB EXPANSION 7. Saved reward first; the scrolling collection showcase never rerolls it.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Market=game:GetService('MarketplaceService')
local Debris=game:GetService('Debris')
local SoundService=game:GetService('SoundService')
local Catalog=require(script.Parent.Catalog)
local Config=require(RS.HABExpansion.Config)
local Art=require(script.Parent.CrateArt)
local Canvas=require(script.Parent.FXCanvas)
local Theme=require(script.Parent.HABReferenceTheme)
local me=Players.LocalPlayer
local R={};local active=nil
local function make(cls,parent,p) local o=Instance.new(cls);for k,v in pairs(p or {}) do o[k]=v end;o.Parent=parent;return o end
local function low() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function cue(id,default,volume,speed)
 if me:GetAttribute('HussSFXMuted') then return end
 local s=make('Sound',SoundService,{SoundId=id>0 and ('rbxassetid://'..id) or default,Volume=volume*math.clamp(me:GetAttribute('HussSFXVolume') or .8,0,1),PlaybackSpeed=speed or 1})
 s:Play();Debris:AddItem(s,3)
end
function R.IsPlaying() return active~=nil end
function R.Stop()
 if not active then return end
 local a=active;active=nil
 for _,c in ipairs(a.Links) do c:Disconnect() end
 for _,fx in ipairs(a.Previews) do fx:Stop() end
 a.Art:Destroy();a.Theme.Destroy();a.Gui:Destroy()
 if a.Done then task.defer(a.Done) end
end
function R.Play(receipt,done,demo)
 R.Stop()
 local item=type(receipt)=='table' and Catalog.Get(receipt.Item)
 if not item or me:GetAttribute('InRound') then if done then task.defer(done) end;return end
 local T=Theme();local C=T.C;local crate=Catalog.Crates[item.Category]
 local gui=make('ScreenGui',me:WaitForChild('PlayerGui'),{Name='HABCrateOpening',DisplayOrder=242,ResetOnSpawn=false,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local backdrop=make('TextButton',gui,{Size=UDim2.fromScale(1,1),Text='',Modal=true,AutoButtonColor=false,BackgroundColor3=C.ink,BackgroundTransparency=.16,BorderSizePixel=0})
 local panel=T.Panel(backdrop,'OpeningWindow',860,650,3,crate.Color);panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5)
 local fit=make('UIScale',panel,{Scale=1})
 local function label(value,x,y,w,h,points,color)
  local p=T.Text(panel,'OpeningCaption',value,x,y,w,h,points,color or C.white,Enum.TextXAlignment.Center)
  p.TextWrapped=true;p.TextTruncate=Enum.TextTruncate.None;p.ZIndex=18;return p
 end
 label(crate.Name:upper(),25,18,810,30,22,C.gold)
 local headline=label('UNSEALING YOUR CRATE',25,54,810,42,32)
 local sub=label(demo and 'PREVIEW ONLY • NO REWARD / NO CHARGE' or 'Collection showcase • your server-selected reward is already saved.',30,101,800,27,13,C.white)
 local view=make('ViewportFrame',panel,{Position=UDim2.fromOffset(25,126),Size=UDim2.fromOffset(810,289),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=7})
 local art=Art.Mount(view,item.Category,crate.Color)
 local a={Gui=gui,Art=art,Theme=T,Done=done,Links={},Previews={}};active=a
 local band=make('Frame',panel,{Position=UDim2.fromOffset(30,342),Size=UDim2.fromOffset(800,163),ClipsDescendants=true,BackgroundColor3=C.ink,BackgroundTransparency=.1,BorderSizePixel=0,ZIndex=12});T.Rounded(band,12)
 local strip=make('Frame',band,{Size=UDim2.fromOffset(1550,160),BackgroundTransparency=1,ZIndex=13})
 local pool=crate.Items
 local cards={};local winIndex=9
 local seed=0;for i=1,#tostring(receipt.Token or item.Id) do seed=(seed*31+string.byte(tostring(receipt.Token or item.Id),i))%2147483647 end
 local random=Random.new(seed)
 for i=1,winIndex+2 do
  local id=i==winIndex and item.Id or pool[random:NextInteger(1,#pool)]
  local meta=Catalog.Get(id)
  local tile=make('Frame',strip,{Position=UDim2.fromOffset((i-1)*154,5),Size=UDim2.fromOffset(144,153),BackgroundColor3=C.panel,BorderSizePixel=0,ZIndex=14});T.Rounded(tile,11);T.Edge(tile,C.ink,3)
  local box=make('Frame',tile,{Position=UDim2.fromOffset(8,4),Size=UDim2.fromOffset(128,113),BackgroundTransparency=1,ClipsDescendants=true,ZIndex=15})
  local fx=Canvas.Mount(box,id,4);if fx then a.Previews[#a.Previews+1]=fx end
  local name=T.Text(tile,'RewardName',meta.Name,6,117,132,30,12,meta.Color,Enum.TextXAlignment.Center);name.TextWrapped=true;name.ZIndex=21
  cards[i]=tile
 end
 local marker=make('Frame',band,{AnchorPoint=Vector2.new(.5,0),Position=UDim2.fromScale(.5,0),Size=UDim2.fromOffset(3,163),BackgroundColor3=C.gold,BorderSizePixel=0,ZIndex=25})
 local fxBox=make('Frame',panel,{Position=UDim2.fromOffset(255,166),Size=UDim2.fromOffset(350,325),BackgroundTransparency=1,ClipsDescendants=true,Visible=false,ZIndex=20})
 local rewardFX=Canvas.Mount(fxBox,item.Id,10);if rewardFX then rewardFX.Paused=true;a.Previews[#a.Previews+1]=rewardFX end
 local name=label(item.Name:upper(),24,512,812,50,29,item.Color:Lerp(C.white,.18));name.Visible=false
 local control=T.Button(panel,'Continue','OPENING...',function() end);control.AnchorPoint=Vector2.new(.5,1);control.Position=UDim2.new(.5,0,1,-23);control.Size=UDim2.fromOffset(300,48);control.TextSize=18;control.ZIndex=30
 local close=T.Button(panel,'Close','X',R.Stop);close.Position=UDim2.fromOffset(794,17);close.Size=UDim2.fromOffset(42,38);close.ZIndex=32
 for _,b in ipairs({control,close}) do
  for _,child in ipairs(b:GetDescendants()) do if child:IsA('GuiObject') then child.ZIndex=b.ZIndex+2 end end
 end
 local pass
 for _,p in ipairs(Config.Passes) do if p.Key=='FastOpen' then pass=p;break end end
 local skip,finished,opened=false,false,false
 local lastPrompt=-10;local start=os.clock();local duration=math.clamp(Config.RevealSeconds,6,10);local tickIndex=0
 local function advance()
  if finished then R.Stop();return end
  if demo or low() or me:GetAttribute('HABPassFastOpen')==true then skip=true;return end
  if pass and pass.Id>0 and os.clock()-lastPrompt>3 then
   lastPrompt=os.clock();pcall(Market.PromptGamePassPurchase,Market,me,pass.Id)
  else sub.Text='Fast Open is a permanent pass. Your reward is saved; closing is always free.' end
 end
 a.Links[#a.Links+1]=control.Activated:Connect(advance)
 a.Links[#a.Links+1]=Input.InputBegan:Connect(function(i,processed)
  if not processed and not Input:GetFocusedTextBox() and (i.KeyCode==Enum.KeyCode.Escape or i.KeyCode==Enum.KeyCode.ButtonB) then R.Stop() end
 end)
 a.Links[#a.Links+1]=me:GetAttributeChangedSignal('InRound'):Connect(function() if me:GetAttribute('InRound') then R.Stop() end end)
 a.Links[#a.Links+1]=me.CharacterRemoving:Connect(R.Stop)
 a.Links[#a.Links+1]=Run.RenderStepped:Connect(function()
  if active~=a then return end
  local screen=backdrop.AbsoluteSize;fit.Scale=math.min(1,math.max(.05,(screen.X-18)/860),math.max(.05,(screen.Y-18)/650))
  local elapsed=os.clock()-start;local minimal=low();local time=(skip or minimal) and duration or math.min(elapsed,duration)
  local entry=1-(1-math.clamp(time/.75,0,1))^3
  local charge=math.clamp((time-.6)/1.1,0,1);local o=math.clamp((time-1.6)/.9,0,1);local opening=1-(1-o)^3
  local shake=not minimal and time>.7 and time<2 and math.sin(time*38)*.06*charge or 0
  art:Pose((1-entry)*-.8+math.sin(elapsed*.5)*.03,opening,shake,(1-entry)*-1.3)
  art.Camera.FieldOfView=34-charge*3+opening*3
  if opening>.8 and not opened then opened=true;cue(Config.Audio.CrateOpenId,'rbxasset://sounds/action_jump_land.mp3',.13,.7) end
  local run=math.clamp((time-1.65)/(duration-2.65),0,1)
  local eased=1-(1-run)^3
  local origin=400-72;local target=origin-(winIndex-1)*154
  strip.Position=UDim2.fromOffset(origin+(target-origin)*eased,0)
  local current=math.floor((origin-strip.Position.X.Offset)/154)+1
  if current~=tickIndex and run>0 and run<1 and not minimal then tickIndex=current;cue(Config.Audio.CrateTickId,'rbxasset://sounds/volume_slider.ogg',.045,1.25) end
  if time>=duration-.95 then
   band.Visible=false;view.ImageTransparency=.68;fxBox.Visible=true;if rewardFX then rewardFX.Paused=false end
   name.Visible=true;headline.Text=demo and 'OPENING PREVIEW' or 'NEW EFFECT UNLOCKED'
  elseif time>1.6 then headline.Text='REVEALING YOUR COLLECTION' end
  if time>=duration then finished=true;control.Text='CONTINUE';sub.Text=demo and 'Preview finished. Nothing was purchased.' or 'Saved to INVENTORY. Select the effect to equip.'
  elseif demo or me:GetAttribute('HABPassFastOpen')==true then control.Text='SKIP ANIMATION'
  else control.Text=pass and pass.Id>0 and 'FAST OPEN • GAME PASS' or 'OPENING...' end
 end)
end
return R
-- HAB_EXPANSION_7
