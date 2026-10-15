--!nonstrict
-- HAB_PLAY_POLISH_8. Reference-HUD components, larger targets, and a dedicated ability picker.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local GuiService=game:GetService('GuiService')
local Market=game:GetService('MarketplaceService')
local X=RS:WaitForChild('HABExpansion')
local Config=require(X.Config)
local Pack=RS:WaitForChild('HABHalloween')
local me=Players.LocalPlayer
local V2=Vector2.new
return function(onAction)
 local T=require(Pack.HABReferenceTheme)();local C=T.C
 local links,pageLinks,previews={},{},{}
 local live=true;local busy=false;local seq=0;local width,height=940,610
 local state={Ready=false,Ability=Config.DefaultAbility};local messageUntil=0;local syncAt=0
 local pending={};local Hud={};local draw,request,show,hide
 local abilityPage=1;local armedAbility=nil;local abilityPrices={}
 local function make(cls,parent,props) local o=Instance.new(cls);for k,v in pairs(props or {}) do o[k]=v end;o.Parent=parent;return o end
 local function link(event,fn,list) local c=event:Connect(fn);table.insert(list or links,c);return c end
 local function clear(list) for _,v in ipairs(list) do v:Disconnect() end;table.clear(list) end
 local function rect(o,x,y,w,h) o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(w,h) end
 local function round(o,n)
  local r=o:FindFirstChildOfClass('UICorner');if r then r.CornerRadius=UDim.new(0,n) else T.Rounded(o,n) end
  local rim=o:FindFirstChild('InnerRim');local rc=rim and rim:FindFirstChildOfClass('UICorner');if rc then rc.CornerRadius=UDim.new(0,math.max(6,n-4)) end
 end
 local function label(parent,name,s,size,color)
  local p=T.Text(parent,name,s,0,0,100,30,size,color or C.white)
  p.TextWrapped=true;p.TextTruncate=Enum.TextTruncate.None;p.ZIndex=parent.ZIndex+18
  return p
 end
 local function button(parent,name,s,color,fn,list)
  T.Tones[name]=color
  local b=T.Button(parent,name,s,fn,false,list or links);round(b,19)
  b.TextSize=20;b.TextTruncate=Enum.TextTruncate.None
  local caption=b:FindFirstChild('ButtonCaption');if caption then caption.TextWrapped=true end
  return b
 end
 local function active()
  local c=me.Character;local h=c and c:FindFirstChildOfClass('Humanoid')
  return me:GetAttribute('InRound')==true and h~=nil and h.Health>0
 end
 local function selected()
  local key=me:GetAttribute('HABAbility') or state.Ability or Config.DefaultAbility
  for _,a in ipairs(Config.Abilities) do if a.Key==key then return a end end
  return Config.Abilities[3]
 end
 local pg=me:WaitForChild('PlayerGui')
 for _,name in ipairs({'HABActionHUD','HABAbilityPicker'}) do local old=pg:FindFirstChild(name);if old then old:Destroy() end end
 local gui=make('ScreenGui',pg,{Name='HABActionHUD',ResetOnSpawn=false,DisplayOrder=125,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local canvas=make('Frame',gui,{Name='ActionCanvas',Size=UDim2.fromScale(1,1),BackgroundTransparency=1,BorderSizePixel=0})
 local row=make('Frame',canvas,{Name='RoundActions',BackgroundTransparency=1,AnchorPoint=V2(.5,1),Position=UDim2.new(.5,0,1,-160),Size=UDim2.fromOffset(560,74)})
 local buttons={}
 buttons.Ability=button(row,'PolishAbility','OVERDRIVE',C.cyan,function() onAction('Ability') end)
 buttons.Swing=button(row,'PolishSwing','TAG',C.red,function() onAction('Swing') end)
 buttons.Throw=button(row,'PolishThrow','THROW',C.gold,function() onAction('Throw') end)
 local meters={}
 for key,b in pairs(buttons) do
  local rail=make('Frame',b,{Name='CooldownRail',Position=UDim2.new(0,14,1,-11),Size=UDim2.new(1,-28,0,4),BackgroundColor3=C.ink,BorderSizePixel=0,ZIndex=b.ZIndex+12})
  T.Rounded(rail,2)
  local fill=make('Frame',rail,{Name='CooldownFill',Size=UDim2.fromScale(1,1),BackgroundColor3=C.white,BorderSizePixel=0,ZIndex=rail.ZIndex+1});T.Rounded(fill,2)
  meters[key]=fill
 end
 local notice=label(canvas,'HitFeedback','',22,C.gold);notice.AnchorPoint=V2(.5,1);notice.TextXAlignment=Enum.TextXAlignment.Center
 local pickerGui=make('ScreenGui',pg,{Name='HABAbilityPicker',ResetOnSpawn=false,DisplayOrder=218,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 local cover=make('TextButton',pickerGui,{Name='AbilityBackdrop',Text='',Modal=true,AutoButtonColor=false,Visible=false,Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BackgroundTransparency=.3,BorderSizePixel=0})
 local window=T.Panel(cover,'AbilityLoadout',width,height,3,C.cyan);round(window,26);window.AnchorPoint=V2(.5,.5);window.Position=UDim2.fromScale(.5,.5)
 local fit=make('UIScale',window,{Scale=1})
 local title=label(window,'AbilityTitle','CHOOSE YOUR ABILITY',32,C.white)
 local hint=label(window,'AbilityHint','Choose one balanced ability.',15,C.gold)
 local close=button(window,'AbilityClose','X',C.red,function() hide() end)
 local body=make('ScrollingFrame',window,{Name='AbilityCards',BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),ScrollBarThickness=5,ScrollBarImageColor3=C.cyan,ClipsDescendants=true,ZIndex=26})
 local footer=label(window,'AbilityStatus','Loading your saved loadout...',14,C.gold)
 local function clearPage()
  clear(pageLinks)
  for _,p in ipairs(previews) do if p.Stop then p:Stop() end end;table.clear(previews)
  body:ClearAllChildren()
 end
 local previewOK,FX=pcall(function() return require(Pack.FXCanvas) end)
 local function art(parent,a,x,y,w,h)
  local frame=make('Frame',parent,{Name='AbilityPreview',BackgroundColor3=C.ink,BackgroundTransparency=.06,BorderSizePixel=0,ClipsDescendants=true,ZIndex=parent.ZIndex+17})
  rect(frame,x,y,w,h);T.Rounded(frame,18)
  local ok,handle=false,nil
  if previewOK then ok,handle=pcall(FX.Mount,frame,a.Effect,6) end
  if ok and handle then previews[#previews+1]=handle else
   local icon=T.Emblem(frame,'STATS',math.min(w,h)*.6,a.Color);icon.AnchorPoint=V2(.5,.5);icon.Position=UDim2.fromScale(.5,.5)
  end
 end
 draw=function()
  if not live or not cover.Visible then return end
  clearPage()
  local screen=cover.AbsoluteSize;if screen.X<1 then screen=V2(1280,720) end
  fit.Scale=math.min(1,math.max(.45,screen.Y/620))
  width=math.min(980,(screen.X-24)/fit.Scale);height=math.min(720,(screen.Y-24)/fit.Scale)
  window.Size=UDim2.fromOffset(width,height)
  rect(title,24,20,width-110,43);title.TextSize=width<500 and 24 or 32
  rect(close,width-76,19,52,50)
  hint.Text=tostring(state.Coins or 0)..' COINS  •  '..tostring(state.Gems or 0)..' GEMS  •  ONE EQUIPPED'
  rect(hint,24,69,width-48,42);hint.TextSize=width<490 and 12 or 15
  rect(body,16,125,width-32,height-205);rect(footer,24,height-56,width-48,39)
  local bw=width-46;local cols=bw>=640 and 2 or 1;local gap=20;local cw=(bw-gap*(cols-1))/cols
  local pages=math.max(1,math.ceil(#Config.Abilities/cols));abilityPage=math.clamp(abilityPage,1,pages)
  local first=(abilityPage-1)*cols+1;local ch=346
  for index=first,math.min(#Config.Abilities,first+cols-1) do
   local a=Config.Abilities[index];local owned=a.Currency=='Free' or (state.Abilities and state.Abilities[a.Key]==true)
   local equipped=(me:GetAttribute('HABAbility') or state.Ability)==a.Key
   local f=T.Panel(body,'AbilityCard_'..a.Key,cw-8,ch,28,a.Color);round(f,26);rect(f,6+(index-first)*(cw+gap),6,cw-8,ch)
   local name=label(f,'Name',a.Name,23,a.Color);rect(name,16,14,cw-40,37);name.TextXAlignment=Enum.TextXAlignment.Center
   art(f,a,(cw-150)/2,61,142,100)
   local details=label(f,'Description',a.Description,14,C.white);rect(details,20,171,cw-48,80);details.TextXAlignment=Enum.TextXAlignment.Center
   local cd=label(f,'Cooldown',a.Cooldown..'s COOLDOWN  •  '..(owned and 'UNLOCKED' or a.Currency=='Robux' and 'PERMANENT PASS' or 'PERMANENT UNLOCK'),11,C.gold)
   rect(cd,16,254,cw-40,23);cd.TextXAlignment=Enum.TextXAlignment.Center
   local caption,disabled,passId='EQUIP',false,nil
   if equipped then caption='EQUIPPED';disabled=true
   elseif not owned then
    if a.Currency=='Robux' then
     for _,pass in ipairs(Config.Passes) do if pass.Key==a.PassKey then passId=pass.Id end end
     if not passId or passId<=0 then caption='PASS NOT CONFIGURED';disabled=true
     else
      local cache=abilityPrices[passId]
      caption=cache and cache.price and ('UNLOCK  R$ '..cache.price) or 'LOADING PRICE...'
      disabled=not(cache and cache.price)
      if not cache then
       abilityPrices[passId]={loading=true}
       task.spawn(function()
        local ok,data=pcall(Market.GetProductInfoAsync,Market,passId,Enum.InfoType.GamePass)
        abilityPrices[passId]=ok and data.IsForSale and type(data.PriceInRobux)=='number' and {price=data.PriceInRobux} or {failed=true}
        if live and cover.Visible then draw() end
       end)
      elseif cache.failed then caption='PRICE UNAVAILABLE' end
     end
    else
     caption=(armedAbility==a.Key and 'CONFIRM  ' or 'UNLOCK  ')..a.Cost..' '..a.Currency:upper()
     disabled=(tonumber(state[a.Currency]) or 0)<a.Cost
     if disabled then caption='NEED '..a.Cost..' '..a.Currency:upper() end
    end
   end
   local buy=button(f,'SelectAbility_'..a.Key,caption,equipped and C.green or a.Color,function()
    if busy or not state.Ready then return end
    if owned then request('SelectAbility',a.Key)
    elseif a.Currency=='Robux' then request('PassPrompt',a.PassKey)
    elseif armedAbility~=a.Key then armedAbility=a.Key;footer.Text='Confirm this permanent unlock. Gems/Coins are saved together with ownership.';draw()
    else armedAbility=nil;request('BuyAbility',a.Key) end
   end,pageLinks)
   rect(buy,16,289,cw-40,48);buy.TextSize=width<480 and 15 or 18
   buy:SetAttribute('HussSelected',equipped);buy:SetAttribute('HussDisabled',disabled or busy or not state.Ready)
  end
  local previous=button(body,'PreviousAbilities','< BACK',C.violet,function() abilityPage-=1;armedAbility=nil;draw() end,pageLinks)
  rect(previous,6,ch+23,(bw-20)/2,46);previous:SetAttribute('HussDisabled',abilityPage<=1)
  local next=button(body,'NextAbilities','MORE  '..abilityPage..'/'..pages..' >',C.cyan,function() abilityPage+=1;armedAbility=nil;draw() end,pageLinks)
  rect(next,16+(bw-20)/2,ch+23,(bw-20)/2,46);next:SetAttribute('HussDisabled',abilityPage>=pages)
  body.CanvasSize=UDim2.fromOffset(0,ch+78)
 end
 request=function(action,key)
  if busy or not live then return end
  busy=true;seq=seq+1;local token=seq
  if action~='Sync' or not state.Ready then footer.Text=action=='SelectAbility' and 'Saving your ability...' or 'Loading your loadout...';draw() end
  task.delay(12,function()
   if live and busy and token==seq then busy=false;seq=seq+1;footer.Text='Loadout is unavailable. Reopen to retry.';draw() end
  end)
  task.spawn(function()
   local ok,res=pcall(X.Api.InvokeServer,X.Api,action,key)
   if not live or token~=seq then return end
   busy=false
   local priorAbility,priorReady=state.Ability,state.Ready
   local oldOwned=state.Abilities or {};local oldCoins,oldGems=state.Coins,state.Gems
   if ok and type(res)=='table' then
    if type(res.Profile)=='table' then state=res.Profile end
    if res.OK and res.PassId then
     local ok,why=pcall(Market.PromptGamePassPurchase,Market,me,res.PassId)
     if not ok then footer.Text='Purchase window unavailable: '..tostring(why) end
    end
    footer.Text=res.Message or (state.Ready and 'Equipped ability is saved. Use Q / Y during a round.' or 'Waiting for your saved profile. The default ability works in a round.')
   else footer.Text='Connection interrupted. Reopen this menu to retry.' end
   local changed=false
   for _,a in ipairs(Config.Abilities) do if (state.Abilities or {})[a.Key]~=oldOwned[a.Key] then changed=true;break end end
   if action~='Sync' or state.Ability~=priorAbility or state.Ready~=priorReady or changed or oldCoins~=state.Coins or oldGems~=state.Gems then draw() end
  end)
 end
 hide=function()
  if not cover.Visible then return end
  cover.Visible=false;clearPage()
  me:SetAttribute('HABAbilityMenuOpen',false)
  me:SetAttribute('HABExpansionOpen',false)
 end
 show=function()
  if active() then return end
  -- Existing menus listen to this shared modal flag, so inventory does not overlap the picker.
  me:SetAttribute('HABExpansionOpen',true);me:SetAttribute('HABAbilityMenuOpen',true)
  cover.Visible=true;draw();syncAt=os.clock()+5;request('Sync')
 end
 function Hud.OpenAbilities() if cover.Visible then hide() else show() end end
 function Hud.Notice(s,color,seconds)
  notice.Text=tostring(s or '');notice.TextColor3=color or C.gold;messageUntil=os.clock()+(seconds or 1.4)
 end
 function Hud.Pending(kind,untilAt) pending[kind]=untilAt end
 function Hud.Reply(e)
  pending[e.Action]=nil
  if e.OK~=true and e.Message then Hud.Notice(e.Message,C.gold,1.2) end
 end
 function Hud.Hit() Hud.Notice('TAGGED!',C.green,.65) end
 link(me:GetAttributeChangedSignal('HABAbilityMenuRequest'),show)
 link(me:GetAttributeChangedSignal('HABCollectionRequest'),hide)
 link(me:GetAttributeChangedSignal('HABExpansionRequest'),function()
  if me:GetAttribute('HABExpansionTab')~='ABILITIES' then hide() end
 end)
 link(me:GetAttributeChangedSignal('InRound'),function() if active() then hide() end end)
 link(me.CharacterRemoving,hide)
 link(me:GetAttributeChangedSignal('HABAbility'),draw)
 link(Input.InputBegan,function(i,processed)
  if processed or Input:GetFocusedTextBox() then return end
  if cover.Visible and (i.KeyCode==Enum.KeyCode.Escape or i.KeyCode==Enum.KeyCode.ButtonB) then hide() end
 end)
 link(Market.PromptGamePassPurchaseFinished,function(p,id,ok) if p==me and ok then task.delay(.5,function() if live then request('RefreshPasses') end end) end end)
 local lastScreen=Vector2.zero
 link(Run.RenderStepped,function()
  if not live then return end
  local screen=canvas.AbsoluteSize
  if screen.X<1 then return end
  if screen~=lastScreen then lastScreen=screen;if cover.Visible then draw() end end
  if cover.Visible and os.clock()>syncAt and not busy then syncAt=os.clock()+6;request('Sync') end
  local inRound=active();local c=me.Character
  local holding=inRound and c:GetAttribute('HussBombCarrier')==true
  local hr=c and c:FindFirstChild('HumanoidRootPart')
  local locked=not hr or hr.Anchored or me:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true
  local permittedThrow=holding and me:GetAttribute('HABPassThrow')==true
  local blocked=me:GetAttribute('HABExpansionOpen')==true or me:GetAttribute('HABCollectionOpen')==true
  row.Visible=inRound and not blocked
  local list={'Ability'};if holding then list[#list+1]='Swing' end;if permittedThrow then list[#list+1]='Throw' end
  buttons.Swing.Visible=holding;buttons.Throw.Visible=permittedThrow
  local total=math.min(screen.X-30,#list*188+(#list-1)*12)
  local cell=(total-(#list-1)*12)/#list
  row.Size=UDim2.fromOffset(total,76)
  row.Position=UDim2.new(.5,0,1,Input.TouchEnabled and -176 or -157)
  local now=workspace:GetServerTimeNow();local def=selected()
  for i,key in ipairs(list) do
   local b=buttons[key];rect(b,(i-1)*(cell+12),0,cell,76)
   b.TextSize=cell<145 and 14 or 19
   local attribute=key=='Ability' and 'HABAbilityReadyAt' or key=='Swing' and 'HABSwingReadyAt' or 'HABThrowReadyAt'
   local ready=tonumber(me:GetAttribute(attribute)) or 0
   if key=='Swing' then ready=math.max(ready,tonumber(me:GetAttribute('HABSwingUnlockAt')) or 0) end
   ready=math.max(ready,pending[key] or 0)
   local left=math.max(0,ready-now)
   local period=key=='Ability' and def.Cooldown or key=='Swing' and Config.Swing.Cooldown or Config.Throw.Cooldown
   local labelText=key=='Ability' and def.Name or key=='Swing' and 'TAG' or 'THROW'
   local blockedGuard=key=='Ability' and holding and def.Key=='Shield'
   local control=Input.TouchEnabled and 'TAP' or key=='Ability' and 'Q / Y' or key=='Swing' and 'CLICK / RT' or 'R / RB'
   b.Text=labelText..'\n'..(locked and 'STARTING...' or blockedGuard and 'NO GUARD WITH BOMB' or left>0 and string.format('%.1fs',left) or control)
   b:SetAttribute('HussDisabled',locked or blockedGuard or (key~='Swing' and left>.03))
   meters[key].Size=UDim2.fromScale(math.clamp(1-left/math.max(.01,period),0,1),1)
  end
  notice.Position=UDim2.new(.5,0,1,Input.TouchEnabled and -258 or -240)
  notice.Size=UDim2.fromOffset(math.min(540,screen.X-28),32)
  notice.Visible=not blocked and os.clock()<messageUntil
 end)
 function Hud.Destroy()
  if not live then return end
  live=false;hide();clear(links);clearPage();gui:Destroy();pickerGui:Destroy();T.Destroy()
 end
 return Hud
end


-- HAB_FUN_9
