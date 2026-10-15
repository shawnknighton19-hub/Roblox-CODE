--!nonstrict
-- HAB_COLLECTIONS_6 | Two main pages: crates and one inventory for sealed crates AND owned effects.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Http=game:GetService('HttpService')
local Marketplace=game:GetService('MarketplaceService')
local me=Players.LocalPlayer
local pg=me:WaitForChild('PlayerGui')
local Pack=RS:WaitForChild('HABHalloween')
local T=require(Pack:WaitForChild('HABReferenceTheme'))()
local C=T.C
-- HAB_PLAY_POLISH_8. More breathing room; same reference palette, fonts, outlines and gloss.
local function bubble(o,radius)
 local c=o:FindFirstChildOfClass('UICorner')
 if c then c.CornerRadius=UDim.new(0,radius) else T.Rounded(o,radius) end
 local rim=o:FindFirstChild('InnerRim');local rc=rim and rim:FindFirstChildOfClass('UICorner')
 if rc then rc.CornerRadius=UDim.new(0,math.max(8,radius-4)) end
end
local Model=require(Pack:WaitForChild('CollectionViewModel'))
local links,pageLinks,confirmLinks={},{},{}
local artifacts,animated,modalArtifacts={},{},{}
local alive=true
local function link(event,fn,list) local c=event:Connect(fn);table.insert(list or links,c);return c end
local function clear(list) for _,c in ipairs(list) do c:Disconnect() end;table.clear(list) end
local function make(class,parent,p) local o=Instance.new(class);for k,v in pairs(p or {}) do o[k]=v end;o.Parent=parent;return o end
local function rect(o,x,y,w,h) o.Position=UDim2.fromOffset(x,y);o.Size=UDim2.fromOffset(w,h) end
local function text(parent,s,points,color)
 local t=T.Text(parent,'Caption',s,0,0,100,24,points or 16,color or C.white)
 t.TextWrapped=true;t.TextTruncate=Enum.TextTruncate.None;t.ZIndex=parent.ZIndex+15
 return t
end
local function button(parent,name,s,color,fn,bucket)
 T.Tones[name]=color or C.cyan
 local b=T.Button(parent,name,s,fn or function() end,false,bucket or pageLinks)
 local delta=parent.ZIndex+18-b.ZIndex;b.ZIndex=b.ZIndex+delta
 for _,o in ipairs(b:GetDescendants()) do if o:IsA('GuiObject') then o.ZIndex=o.ZIndex+delta end end
 bubble(b,18)
 b.TextTruncate=Enum.TextTruncate.None
 local caption=b:FindFirstChild('ButtonCaption');if caption then caption.TextWrapped=true end
 return b
end
local function disabled(b,v) b:SetAttribute('HussDisabled',v==true) end
local function card(parent,name,color,w,h)
 local p=T.Panel(parent,name,w or 100,h or 100,parent.ZIndex+1,color or C.cyan)
 bubble(p,25)
 return p
end
local function flat(parent,name,x,y,w,h)
 return make('Frame',parent,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=parent.ZIndex+22})
end
local function scroll(parent,name,x,y,w,h)
 return make('ScrollingFrame',parent,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,
  BorderSizePixel=0,ScrollBarThickness=5,ScrollBarImageColor3=C.cyan,CanvasSize=UDim2.new(),ClipsDescendants=true,ZIndex=parent.ZIndex+22})
end
local function keep(a) if a then artifacts[#artifacts+1]=a end;return a end
local function fmt(n) return tostring(math.floor(n or 0)):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','') end
local function reduced() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
for _,name in ipairs({'HABReliquaryGui','HABCrateLauncher','HABCrateOpening'}) do local old=pg:FindFirstChild(name);if old then old:Destroy() end end
local gui=make('ScreenGui',pg,{Name='HABReliquaryGui',ResetOnSpawn=false,DisplayOrder=210,IgnoreGuiInset=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local backdrop=make('TextButton',gui,{Name='CollectionBackdrop',Size=UDim2.fromScale(1,1),Text='',AutoButtonColor=false,Modal=true,
 BackgroundColor3=C.ink,BackgroundTransparency=.32,BorderSizePixel=0,Visible=false,ZIndex=1})
local root=card(backdrop,'CollectionWindow',C.cyan,1040,760)
root.AnchorPoint=Vector2.new(.5,.5);root.Position=UDim2.fromScale(.5,.5)
local scale=make('UIScale',root,{Scale=1})
local brand=text(root,'H U S S  A  B O M B',11,C.green)
local heading=text(root,'CRATES',34,C.white)
local balance=text(root,'LOADING YOUR PROFILE',15,C.cyan)
local close=button(root,'Close','X',C.red,nil,links)
local tabs={};local body=flat(root,'PageBody',22,165,996,438)
local gemsButton=button(root,'OpenGems','GEMS +',C.cyan,nil,links)
local backButton=button(root,'BackToItems','< BACK',C.gold,nil,links);backButton.Visible=false
local notice=text(root,'',13,C.white)
local saveText=text(root,'',10,C.muted)
local resume=button(root,'Resume','RESUME TRANSACTION',C.gold,nil,links);resume.Visible=false
local w,h,bw,bh=1040,760,996,438
local current='CRATES';local category=nil;local selected=nil;local page=1
local inventoryFilter='All';local focusId=nil
local state=Model.Empty()
local Catalog,Canvas,Art,Reveal,API,Events
local loaded=false;local busy=false;local pending=nil;local serial=0;local generation=0;local lastSync=0;local prices={};local shown={}
local confirmation=nil;local lastSize=Vector2.zero
local render,request,show,hide,revealReceipt
local function viewKey(v)
 return table.concat({tostring(v.Ready),tostring(v.Revision),tostring(v.Gems),tostring(v.Coins),tostring(v.RandomAllowed)},'|')
end
local function say(s) notice.Text=tostring(s or '') end
local function clearBody()
 clear(pageLinks)
 for _,a in ipairs(artifacts) do if a.Stop then a:Stop() elseif a.Destroy then a:Destroy() end end
 table.clear(artifacts);table.clear(animated)
 body:ClearAllChildren()
end
local function stopConfirm()
 clear(confirmLinks)
 for _,a in ipairs(modalArtifacts) do if a.Stop then a:Stop() elseif a.Destroy then a:Destroy() end end
 table.clear(modalArtifacts)
 if confirmation then confirmation:Destroy();confirmation=nil end
end
local function fit()
 local screen=backdrop.AbsoluteSize
 if screen.X<1 or screen.Y<1 then local cam=workspace.CurrentCamera;screen=cam and cam.ViewportSize or Vector2.new(1280,720) end
 local factor=math.min(1,math.max(.3,(screen.Y-20)/600))
 w=math.min(1080,math.max(310,(screen.X-24)/factor));h=math.min(910,(screen.Y-24)/factor)
 factor=math.min(factor,(screen.X-20)/w);scale.Scale=factor;root.Size=UDim2.fromOffset(w,h)
 local short=h<680
 brand.Visible=not short;rect(brand,26,13,w-112,17)
 local wide=w>=740
 rect(heading,26,short and 17 or 34,wide and w-355 or w-108,43);heading.TextSize=wide and 33 or 25
 rect(close,w-74,short and 16 or 25,50,49);balance.Visible=false
 local y=short and 74 or 96
 local gap=14;local tw=(w-52-gap*2)/3
 for i,name in ipairs({'CRATES','INVENTORY','ROBUX'}) do
  local b=tabs[name];if b then rect(b,26+(i-1)*(tw+gap),y,tw,48);b.TextSize=w<500 and 14 or 20 end
 end
 gemsButton.Visible=wide;rect(gemsButton,w-293,short and 18 or 36,202,42);gemsButton.TextSize=17
 backButton.Visible=current=='GEMS' or current=='QUESTS';rect(backButton,26,y+62,116,44);backButton.TextSize=16
 local bodyY=y+66+(backButton.Visible and 57 or 0)
 bw=w-52;bh=h-bodyY-67;rect(body,26,bodyY,bw,bh)
 rect(notice,26,h-55,w-52,29);rect(saveText,26,h-23,w-52,17)
 rect(resume,w-267,h-59,241,45)
 if pending then notice.Size=UDim2.fromOffset(math.max(70,w-305),35) end
end

local function pool(cat) return Model.Pool(state,cat) end
local function has(list,id) for _,v in ipairs(list) do if v==id then return true end end;return false end
local function ownedCount(cat)
 local n=0;for _,id in ipairs(Catalog.Crates[cat].Items) do if state.Owned[id] then n=n+1 end end;return n
end
local function preview(parent,id,x,y,size,layerLimit)
 local box=flat(parent,'AnimatedVFXPreview',x,y,size,size)
 box.ClipsDescendants=true
 box.Rotation=0;box.BackgroundTransparency=.06;box.BackgroundColor3=C.ink
 T.Rounded(box,10)
 local ok,handle=pcall(Canvas.Mount,box,id,layerLimit or 8)
 if ok and handle then keep(handle) else
  local t=text(box,'PREVIEW UNAVAILABLE',11,C.white);rect(t,4,4,size-8,size-8);t.TextXAlignment=Enum.TextXAlignment.Center
  warn('[HAB Collections] Preview failed for '..tostring(id)..': '..tostring(handle))
 end
 return box
end
local function chest(parent,cat,x,y,width,height)
 local view=make('ViewportFrame',parent,{Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(width,height),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=parent.ZIndex+22})
 local a=keep(Art.Mount(view,cat,Catalog.Crates[cat].Color));animated[#animated+1]=a
 return view
end
local function selectCategory(cat)
 category=cat;selected=nil;page=1;render()
end
local function categoryBar(y)
 local s=scroll(body,'Categories',2,y,bw-4,43);s.ScrollingDirection=Enum.ScrollingDirection.X;s.CanvasSize=UDim2.fromOffset(#Catalog.Order*151,0);s.ScrollBarThickness=2
 for i,cat in ipairs(Catalog.Order) do
  local b=button(s,'Category_'..cat,Catalog.Crates[cat].Label,Catalog.Crates[cat].Color,function() selectCategory(cat) end)
  rect(b,5+(i-1)*151,3,140,32);b.TextSize=13;b:SetAttribute('HussSelected',category==cat)
 end
end
local function confirm(title,description,caption,callback,rewardIds)
 if confirmation then return end
 local cover=make('TextButton',root,{Name='ConfirmTransaction',Text='',AutoButtonColor=false,Modal=true,Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BackgroundTransparency=.18,BorderSizePixel=0,ZIndex=90})
 confirmation=cover
 local box=T.Panel(cover,'Confirmation',math.min(570,w-28),342,91,C.gold)
 box.AnchorPoint=Vector2.new(.5,.5);box.Position=UDim2.fromScale(.5,.5)
 local t=text(box,title,26,C.gold);rect(t,20,16,box.Size.X.Offset-40,54)
 local d=text(box,description,14,C.white);rect(d,20,82,box.Size.X.Offset-40,164)
 local cancel=button(box,'Close','CANCEL',C.red,function() stopConfirm() end,confirmLinks)
 local yes=button(box,'Confirm',caption,C.green,function() stopConfirm();callback() end,confirmLinks)
 rect(cancel,18,277,(box.Size.X.Offset-48)/2,48);rect(yes,30+(box.Size.X.Offset-48)/2,277,(box.Size.X.Offset-48)/2,48)
 yes.TextSize=16
 if rewardIds and #rewardIds>0 then
  local list=scroll(box,'ConfirmedOutcomeList',20,80,box.Size.X.Offset-40,165);list.Visible=false
  for i,id in ipairs(rewardIds) do
   local item=Catalog.Get(id)
   local line=text(list,(item and item.Name or id)..'  '..string.format('%.6f%%',100/#rewardIds),12,C.white)
   rect(line,5,(i-1)*28,list.Size.X.Offset-17,26)
  end
  list.CanvasSize=UDim2.fromOffset(0,#rewardIds*28)
  local details=make('TextButton',box,{Name='OutcomeDetails',Text='VIEW REWARDS & ODDS',TextSize=11,Font=Enum.Font.GothamBold,
   BackgroundTransparency=1,TextColor3=C.cyan,Position=UDim2.fromOffset(20,247),Size=UDim2.fromOffset(box.Size.X.Offset-40,22),ZIndex=box.ZIndex+24})
  link(details.Activated,function() list.Visible=not list.Visible;d.Visible=not list.Visible;details.Text=list.Visible and 'BACK TO CONFIRMATION' or 'VIEW REWARDS & ODDS' end,confirmLinks)
 end
end
local function transact(action,payload)
 if busy or pending then return end
 pending={Action=action,Payload=payload};request(action,payload)
end
local function purchase(direct)
 if busy or pending or not state.Ready then return end
 local crate=Catalog.Crates[category];local p=pool(category);local n=#p.Items
 if not p.CanBuy then say('This collection is complete or already covered by your stored crates.');return end
 if not direct and not state.RandomAllowed then say(state.PolicyMessage);return end
 if direct and not has(p.Items,selected) then say('Choose an unowned, unreserved effect.');return end
 local cost=direct and math.ceil(crate.Price*(n+1)/2) or crate.Price
 if state.Gems<cost then current='GEMS';render();say('Not enough Gems. Claim quests or buy Gems.');return end
 local payload={Category=category,Token=Http:GenerateGUID(false),Revision=state.Revision,Choice=direct and selected or nil}
 local desc=direct and ('Contents: '..Catalog.ById[selected].Name..'. 100% chance.')
  or (Model.Odds(n)..'\nNo duplicates. The remaining odds update as effects are owned or reserved. See CONTENTS & ODDS for every outcome.')
 confirm('STORE '..crate.Label:upper()..' CRATE',desc..'\n\n'..cost..' Gems. Stored unopened in your inventory.','BUY & STORE',function()
  if state.Revision~=payload.Revision then render();say('Your inventory changed. Review the new odds and confirm again.');return end
  transact('BuyCrate',payload)
 end,not direct and table.clone(p.Items) or nil)
end
local function storedAction(stored,refund)
 if busy or pending or not state.Ready then return end
 local payload={Crate=stored.Id,Token=Http:GenerateGUID(false),Revision=state.Revision}
 local desc,title,caption
 if refund then
  title='REFUND SEALED CRATE';caption='REFUND'
  desc='Remove this unopened crate from inventory and return exactly '..stored.Cost..' Gems.\nNo effect is awarded.'
 else
  if stored.Mode=='Random' and not state.RandomAllowed then say('Random opening is unavailable. Use REFUND to recover this crate\'s Gems.');return end
  local n=#pool(stored.Category).Items
  if stored.Mode=='Random' and n<1 then say('No available contents. Refund this crate instead.');return end
  title='OPEN ONE STORED CRATE';caption='OPEN CRATE'
  desc=stored.Mode=='Guaranteed' and ('Contents: '..(Catalog.ById[stored.Choice] and Catalog.ById[stored.Choice].Name or stored.Choice)..' (100%).')
   or ('One of '..n..' available effects. Each outcome: '..string.format('%.4f%%',100/math.max(1,n))..'.\nUse VIEW REWARDS & ODDS for the complete list. Percentages are rounded.')
  desc=desc..'\n\nConsumes ONE stored crate. Costs NO additional Gems. Your saved reward then receives its opening animation.'
 end
 confirm(title,desc,caption,function()
  if state.Revision~=payload.Revision then render();say('Your inventory changed. Confirm again with the updated contents.');return end
  transact(refund and 'RefundStored' or 'OpenStored',payload)
 end,not refund and stored.Mode=='Random' and table.clone(pool(stored.Category).Items) or nil)
end
local function pagers(parent,y,total,pageSize)
 local maxPage=math.max(1,math.ceil(total/pageSize));page=math.clamp(page,1,maxPage)
 if maxPage<=1 then return end
 local narrow=bw<450;local ww=narrow and 62 or 140
 local left=button(parent,'Previous',narrow and '<' or '< PREVIOUS',C.cyan,function() page=page-1;render() end)
 local right=button(parent,'Next',narrow and '>' or 'NEXT >',C.cyan,function() page=page+1;render() end)
 rect(left,4,y,ww,46);rect(right,bw-ww-4,y,ww,46);left.TextSize=18;right.TextSize=18
 disabled(left,page<=1);disabled(right,page>=maxPage)
 local t=text(parent,page..' / '..maxPage,16,C.muted);t.TextXAlignment=Enum.TextXAlignment.Center
 rect(t,ww+12,y,bw-2*ww-24,45)
end
local function cardLayout(availableHeight)
 local cols=bw>=660 and 2 or 1
 local gap=24;local cw=(bw-16-gap*(cols-1))/cols
 local rows=availableHeight>=552 and 2 or 1
 local ch=rows==2 and math.floor((availableHeight-32)/2) or math.clamp(availableHeight-12,270,346)
 return cols,rows,cw,ch,gap,cols*rows
end

local function overview()
 local s=scroll(body,'CrateShopCards',0,0,bw,bh)
 local cols=bw>=660 and 2 or 1;local gap=24;local cw=(bw-16-(cols-1)*gap)/cols;local ch=368
 for i,cat in ipairs(Catalog.Order) do
  local crate=Catalog.Crates[cat]
  local f=card(s,'CrateCard_'..cat,crate.Color,cw,ch)
  rect(f,6+((i-1)%cols)*(cw+gap),6+math.floor((i-1)/cols)*(ch+gap),cw,ch)
  local t=text(f,crate.Name:upper(),26,crate.Color);rect(t,18,16,cw-36,40);t.TextXAlignment=Enum.TextXAlignment.Center
  chest(f,cat,12,59,cw-24,174)
  local info=text(f,tostring(state.StoredCounts[cat] or 0)..' unopened',14,C.muted);rect(info,18,235,cw-36,27);info.TextXAlignment=Enum.TextXAlignment.Center
  local p=pool(cat)
  local buy=button(f,'Buy_'..cat,state.RandomAllowed and (crate.Price..' GEMS • BUY CRATE') or 'CHOOSE CONTENTS',crate.Color,function()
   category=cat;if state.RandomAllowed then purchase(false) else page=1;render() end
  end)
  rect(buy,18,274,cw-36,50);buy.TextSize=19;disabled(buy,busy or pending~=nil or not state.Ready or not p.CanBuy)
  local contents=make('TextButton',f,{Name='Contents_'..cat,Text='VIEW CONTENTS & ODDS',TextSize=13,Font=Enum.Font.GothamBold,
   TextColor3=C.white,BackgroundTransparency=1,Size=UDim2.fromOffset(cw-36,38),Position=UDim2.fromOffset(18,327),ZIndex=f.ZIndex+24})
  link(contents.Activated,function() selectCategory(cat) end,pageLinks)
 end
 s.CanvasSize=UDim2.fromOffset(0,math.ceil(#Catalog.Order/cols)*(ch+gap)+12)
end

-- A single large effect preview with one equipment action. No separate effect-only inventory.
local function inspectEffect(id,canChoose)
 local item=Catalog.Get(id)
 if not item or confirmation then return end
 local width=math.min(530,w-28);local height=math.min(590,h-20)
 local cover=make('TextButton',root,{Name='EffectInspector',Text='',AutoButtonColor=false,Modal=true,
  Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BackgroundTransparency=.16,BorderSizePixel=0,ZIndex=90})
 confirmation=cover
 local box=T.Panel(cover,'EffectInspectorPanel',width,height,91,item.Color)
 box.AnchorPoint=Vector2.new(.5,.5);box.Position=UDim2.fromScale(.5,.5);bubble(box,27)
 local title=text(box,item.Name:upper(),26,C.white);rect(title,20,18,width-91,50)
 local x=button(box,'CloseEffect','X',C.red,function() stopConfirm() end,confirmLinks);rect(x,width-67,17,47,47)
 local artSize=math.max(90,math.min(290,width-50,height-269))
 local art=flat(box,'LargeEffectPreview',(width-artSize)/2,72,artSize,artSize)
 art.BackgroundTransparency=.06;art.BackgroundColor3=C.ink;art.ClipsDescendants=true
 local ok,handle=pcall(Canvas.Mount,art,id,12)
 if ok and handle then modalArtifacts[#modalArtifacts+1]=handle else
  local fail=text(art,'PREVIEW UNAVAILABLE',13,C.white);rect(fail,5,artSize/2-20,artSize-10,40)
 end
 local crate=Catalog.Crates[item.Category]
 local status=state.Owned[id] and (state.Equipped[item.Category]==id and 'EQUIPPED' or 'OWNED') or 'CRATE CONTENTS'
 local info=text(box,crate.Label..'  /  '..status,13,C.gold);rect(info,18,80+artSize,width-36,27);info.TextXAlignment=Enum.TextXAlignment.Center
 local desc=text(box,item.Description or crate.Description,13,C.muted);rect(desc,20,114+artSize,width-40,48);desc.TextXAlignment=Enum.TextXAlignment.Center
 local caption,callback,off='LOCKED',function() end,true
 if state.Owned[id] then
  local equipped=state.Equipped[item.Category]==id
  caption=equipped and 'UNEQUIP' or item.Type=='KillSound' and 'EQUIP SOUND' or 'EQUIP EFFECT'
  callback=function() stopConfirm();request('Equip',{Category=item.Category,Item=equipped and '' or id}) end
  off=busy or pending~=nil or not state.Ready
 elseif canChoose and has(pool(item.Category).Items,id) then
  local n=#pool(item.Category).Items;local cost=math.ceil(crate.Price*(n+1)/2)
  caption='GUARANTEED  '..cost..' GEMS'
  callback=function() stopConfirm();category=item.Category;selected=id;purchase(true) end
  off=busy or pending~=nil or not state.Ready or not pool(item.Category).CanBuy
 end
 local action=button(box,'EffectAction',caption,C.green,callback,confirmLinks)
 rect(action,20,height-101,width-40,52);action.TextSize=width<380 and 16 or 21;disabled(action,off)
 local done=make('TextButton',box,{Name='BackFromEffect',Text='BACK',TextSize=12,Font=Enum.Font.GothamBold,TextColor3=C.white,
  BackgroundTransparency=1,Position=UDim2.fromOffset(20,height-44),Size=UDim2.fromOffset(width-40,35),ZIndex=box.ZIndex+18})
 link(done.Activated,stopConfirm,confirmLinks)
end

local function collection()
 local cat=category or Catalog.Order[1];category=cat
 local crate=Catalog.Crates[cat];local p=pool(cat);local eligible={}
 for _,id in ipairs(p.Items) do eligible[id]=true end
 local back=button(body,'BackToCrates','< CRATES',C.violet,function() category=nil;page=1;render() end)
 rect(back,4,0,122,46);back.TextSize=17
 local title=text(body,crate.Name:upper(),bw<500 and 20 or 28,crate.Color);rect(title,144,0,bw-150,46)
 local odds=text(body,Model.Odds(#p.Items),13,C.gold);rect(odds,6,56,bw-12,34)
 local available=math.max(125,bh-212)
 local s=scroll(body,'CrateContents',0,100,bw,available)
 local ids={};for _,id in ipairs(crate.Items) do ids[#ids+1]=id end
 table.sort(ids,function(a,b) if Catalog.ById[a].Name==Catalog.ById[b].Name then return a<b end;return Catalog.ById[a].Name<Catalog.ById[b].Name end)
 local cols,rows,cw,ch,gap,pageSize=cardLayout(available)
 page=math.clamp(page,1,math.max(1,math.ceil(#ids/pageSize)))
 local index=0
 for i=(page-1)*pageSize+1,math.min(page*pageSize,#ids) do
  local id=ids[i];local item=Catalog.ById[id]
  local f=card(s,'Content_'..id,item.Color,cw,ch);rect(f,6+(index%cols)*(cw+gap),6+math.floor(index/cols)*(ch+gap),cw,ch);index=index+1
  local art=math.min(cw-46,ch-122,192);preview(f,id,(cw-art)/2,18,art,7)
  local title=text(f,item.Name,23,C.white);rect(title,16,ch-98,cw-32,46);title.TextXAlignment=Enum.TextXAlignment.Center
  local st=text(f,state.Owned[id] and 'OWNED' or p.Reserved[id] and 'RESERVED' or eligible[id] and string.format('%.6f%%',100/math.max(1,#p.Items)) or 'NOT AVAILABLE',13,eligible[id] and C.gold or C.muted)
  rect(st,16,ch-49,cw-32,29);st.TextXAlignment=Enum.TextXAlignment.Center
  local hit=make('TextButton',f,{Name='InspectContent_'..id,Text='',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=f.ZIndex+45,AutoButtonColor=false})
  link(hit.Activated,function() inspectEffect(id,true) end,pageLinks)
 end
 s.CanvasSize=UDim2.fromOffset(0,math.ceil(index/cols)*(ch+gap)+12)
 pagers(body,bh-104,#ids,pageSize)
 local b=button(body,'BuyCollection',state.RandomAllowed and ('BUY & STORE • '..crate.Price..' GEMS') or 'SELECT AN EFFECT ABOVE',C.green,function() purchase(false) end)
 rect(b,6,bh-50,bw-12,48);b.TextSize=19
 disabled(b,busy or pending~=nil or not state.Ready or not state.RandomAllowed or not p.CanBuy)
end


local filters={{'All','ALL'},{'Crates','CRATES'},{'Aura','AURAS'},{'Trail','TRAILS'},{'BombFX','BOMB'},{'KillFX','KILL SOUNDS'},{'DodgeFX','DODGES'}}
local function filterMenu()
 if confirmation then return end
 local width=math.min(540,w-24);local cols=width>=440 and 2 or 1
 local height=math.min(h-28,110+math.ceil(#filters/cols)*64)
 local cover=make('TextButton',root,{Name='InventoryFilterPicker',Text='',AutoButtonColor=false,Modal=true,Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BackgroundTransparency=.16,BorderSizePixel=0,ZIndex=90})
 confirmation=cover
 local box=T.Panel(cover,'ChooseInventoryFilter',width,height,91,C.cyan);bubble(box,26);box.AnchorPoint=Vector2.new(.5,.5);box.Position=UDim2.fromScale(.5,.5)
 local title=text(box,'SHOW IN INVENTORY',24,C.white);rect(title,20,20,width-96,49)
 local x=button(box,'CloseFilter','X',C.red,stopConfirm,confirmLinks);rect(x,width-65,19,46,47)
 local list=scroll(box,'Filters',16,86,width-32,height-102)
 local cw=(width-44-(cols-1)*14)/cols
 for i,pair in ipairs(filters) do
  local key,caption=pair[1],pair[2]
  local b=button(list,'Filter_'..key,caption,C.cyan,function() inventoryFilter=key;page=1;stopConfirm();render() end,confirmLinks)
  rect(b,5+((i-1)%cols)*(cw+14),5+math.floor((i-1)/cols)*64,cw,50);b.TextSize=18;b:SetAttribute('HussSelected',inventoryFilter==key)
 end
 list.CanvasSize=UDim2.fromOffset(0,math.ceil(#filters/cols)*64+7)
end
local function inventory()
 local crates,effects=Model.Count(state)
 local filterName='ALL ITEMS';for _,f in ipairs(filters) do if f[1]==inventoryFilter then filterName=f[2] end end
 local choice=button(body,'InventoryFilter',filterName..'  v',C.cyan,filterMenu)
 rect(choice,6,1,math.min(215,bw*.55),48);choice.TextSize=bw<450 and 17 or 20
 local label=text(body,tostring(effects)..' effects / '..crates..' crates',bw<450 and 12 or 16,C.muted)
 rect(label,math.min(215,bw*.55)+22,1,bw-math.min(215,bw*.55)-28,48);label.TextXAlignment=Enum.TextXAlignment.Right
 local rows=Model.Inventory(Catalog,state,inventoryFilter)
 local available=math.max(150,bh-119)
 local s=scroll(body,'UnifiedInventoryGrid',0,63,bw,available)
 local cols,gridRows,cw,ch,gap,pageSize=cardLayout(available)
 page=math.clamp(page,1,math.max(1,math.ceil(#rows/pageSize)))
 if focusId then
  for i,row in ipairs(rows) do if row.Id==focusId then page=math.ceil(i/pageSize);break end end
  focusId=nil
 end
 local index=0
 for i=(page-1)*pageSize+1,math.min(page*pageSize,#rows) do
  local row=rows[i];local color=row.Color or C.cyan
  local f=card(s,'Inventory_'..row.Key,row.Equipped and C.green or color,cw,ch)
  rect(f,6+(index%cols)*(cw+gap),6+math.floor(index/cols)*(ch+gap),cw,ch);index=index+1
  local art=math.min(cw-46,ch-138,196)
  if row.Kind=='Crate' then chest(f,row.Category,18,14,cw-36,art+8)
  elseif not row.Missing then preview(f,row.Id,(cw-art)/2,17,art,7)
  else local missing=text(f,'LEGACY EFFECT',18,C.muted);rect(missing,18,40,cw-36,art) end
  local title=text(f,row.Name,23,C.white);rect(title,18,ch-111,cw-36,47);title.TextXAlignment=Enum.TextXAlignment.Center
  if row.Kind=='Crate' then
   local qty=text(f,'SEALED  x'..row.Count,13,C.gold);rect(qty,16,8,cw-32,23)
   local b=button(f,'Open_'..row.Crate.Id,'OPEN CRATE',C.green,function() storedAction(row.Crate,false) end)
   rect(b,16,ch-56,cw-89,47);b.TextSize=19;disabled(b,busy or pending~=nil or not state.Ready or (row.Crate.Mode=='Random' and not state.RandomAllowed))
   local more=button(f,'CrateInfo_'..row.Crate.Id,'...',C.cyan,function() storedAction(row.Crate,true) end)
   rect(more,cw-64,ch-56,48,47);more.TextSize=22;disabled(more,busy or pending~=nil or not state.Ready)
  else
   local b=button(f,'View_'..row.Id,row.Equipped and 'EQUIPPED • VIEW' or 'VIEW EFFECT',row.Equipped and C.green or color,function()
    if not row.Missing then inspectEffect(row.Id,false) else say('This saved effect is missing from the catalog: '..row.Id) end
   end)
   rect(b,16,ch-57,cw-32,47);b.TextSize=19
   local hit=make('TextButton',f,{Name='Inspect_'..row.Id,Text='',BackgroundTransparency=1,Size=UDim2.new(1,0,1,-64),ZIndex=f.ZIndex+45,AutoButtonColor=false})
   link(hit.Activated,function() if not row.Missing then inspectEffect(row.Id,false) end end,pageLinks)
  end
 end
 s.CanvasSize=UDim2.fromOffset(0,math.ceil(index/cols)*(ch+gap)+12)
 if #rows==0 then
  local title=text(s,not state.Ready and 'LOADING YOUR INVENTORY...' or 'NO ITEMS IN THIS FILTER',22,C.white);rect(title,16,24,bw-32,70);title.TextXAlignment=Enum.TextXAlignment.Center
  local desc=text(s,not state.Ready and 'Waiting for your saved profile.' or 'Opened effects and your sealed crates appear here.',15,C.muted);rect(desc,16,98,bw-32,64);desc.TextXAlignment=Enum.TextXAlignment.Center
  local b=button(s,'InventoryEmptyAction',inventoryFilter~='All' and 'SHOW ALL ITEMS' or 'SHOP CRATES',C.violet,function()
   if inventoryFilter~='All' then inventoryFilter='All' else current='CRATES';category=nil end
   page=1;render()
  end);rect(b,16,175,bw-32,49)
  s.CanvasSize=UDim2.fromOffset(0,238)
 end
 pagers(body,bh-48,#rows,pageSize)
end

local function supplemental()
 local s=scroll(body,'GemsAndQuests',0,0,bw,bh)
 local y=6
 local function row(title,description,caption,color,fn,off,isGem)
  local rh=bw<580 and 242 or 190
  local f=card(s,'ShopOffer',color,bw-16,rh);rect(f,6,y,bw-16,rh)
  if isGem then local gem=T.Gem(f,bw<580 and 74 or 86);gem.Position=UDim2.fromOffset(12,bw<580 and 63 or 31) end
  local x=isGem and (bw<580 and 99 or 112) or 16
  local t=text(f,title,bw<580 and 20 or 27,color);rect(t,bw<580 and 16 or x,12,bw-(bw<580 and 55 or x+39),44)
  local d=text(f,description,bw<580 and 12 or 14,C.white);rect(d,x,60,bw-x-39,bw<580 and 85 or 46)
  local b=button(f,'Offer_'..y,caption,color,fn);rect(b,14,rh-59,bw-44,48);b.TextSize=17;disabled(b,off)
  y=y+rh+18;return b
 end
 if current=='QUESTS' then
  for _,q in ipairs(state.Quests or {}) do
   local allowed=state.Ready and q.Progress>=q.Target and not q.Claimed
   row(q.Title:upper(),q.Progress..' / '..q.Target..'   •   +'..q.Coins..' COINS   + '..q.Gems..' GEMS',q.Claimed and 'CLAIMED' or allowed and 'CLAIM REWARDS' or 'IN PROGRESS',C.gold,function() request('ClaimQuest',q.Id) end,busy or pending~=nil or not allowed,false)
  end
  if #(state.Quests or {})==0 then row('DAILY QUESTS','Your quest record is loading. Multiplayer quests award Gems.','REFRESH',C.gold,function() request('Sync') end,busy,false) end
 else
  row(fmt(state.Gems)..' GEMS','Gems buy crates for your inventory. Earn them from quests or buy a configured Gem pack.','EARN GEMS • QUESTS',C.cyan,function() current='QUESTS';page=1;render() end,false,true)
  if #(state.Products or {})==0 then
   row('GEM PACKS','Robux packs are not configured for this experience. Quest Gems still work.','VIEW QUESTS',C.violet,function() current='QUESTS';render() end,false,true)
  end
  for _,offer in ipairs(state.Products or {}) do
   local offerKey=offer.Key;local productId=offer.ProductId
   local cache=prices[productId]
   local caption=cache and cache.Price and ('BUY • R$ '..cache.Price) or cache and cache.Failed and 'PRICE UNAVAILABLE' or 'LOADING PRICE...'
   row(fmt(offer.Gems)..' GEMS • '..offer.Name, 'Added to your saved Gem balance after Roblox confirms your purchase.',caption,C.cyan,function() request('GemPrompt',offerKey) end,busy or pending~=nil or not state.Ready or not(cache and cache.Price),true)
   if not cache then
    prices[productId]={Loading=true}
    task.spawn(function()
     local ok,info=pcall(Marketplace.GetProductInfoAsync,Marketplace,productId,Enum.InfoType.Product)
     prices[productId]=ok and type(info)=='table' and type(info.PriceInRobux)=='number' and {Price=info.PriceInRobux} or {Failed=true}
     if alive and backdrop.Visible and current=='GEMS' then render() end
    end)
   end
  end
 end
 s.CanvasSize=UDim2.fromOffset(0,y+6)
end
render=function()
 if not alive then return end
 clearBody();fit()
 local accent=({CRATES=C.violet,INVENTORY=C.gold,EFFECTS=C.green,GEMS=C.cyan,QUESTS=C.gold})[current] or C.cyan
 heading.Text=({CRATES='CRATES',INVENTORY='MY INVENTORY',GEMS='GEMS',QUESTS='QUESTS'})[current]
 gemsButton.Text=state.Ready and (fmt(state.Gems)..' GEMS +') or 'GEMS +'
 heading.TextColor3=accent
 balance.Text=state.Ready and (fmt(state.Coins)..' COINS     •     '..fmt(state.Gems)..' GEMS') or 'CONNECTING TO YOUR SAVED PROFILE...'
 for name,b in pairs(tabs) do b:SetAttribute('HussSelected',(name=='ROBUX' and current=='GEMS') or name==current) end
 resume.Visible=pending~=nil;disabled(resume,busy)
 if not loaded then local t=text(body,'LOADING YOUR COLLECTIONS...',24,C.white);rect(t,20,50,bw-40,90);return end
 if not backdrop.Visible then return end
 if current=='CRATES' and not category then overview()
 elseif current=='CRATES' then collection()
 elseif current=='INVENTORY' then inventory()
 else supplemental() end
end
revealReceipt=function(receipt,demo)
 if not loaded or not Catalog.Get(receipt.Item) then return end
 generation=generation+1;local g=generation
 local oldTab,oldCategory,oldSelected,oldPage=current,category,selected,page
 backdrop.Visible=false;clearBody()
 Reveal.Play(receipt,function()
  if not alive or g~=generation or me:GetAttribute('InRound')==true then return end
  if demo then current,category,selected,page=oldTab,oldCategory,oldSelected,oldPage
  else current='INVENTORY';category=nil;inventoryFilter='All';selected=receipt.Item;focusId=receipt.Item;page=1 end
  backdrop.Visible=true;me:SetAttribute('HABCollectionOpen',true);render();request('Sync')
 end,demo)
end
request=function(action,payload)
 if not loaded or busy or not alive then return end
 if pending and action~=pending.Action and action~='Sync' then say('Resume your pending transaction first.');return end
 busy=true;serial=serial+1;local token=serial;local g=generation
 if action~='Sync' then stopConfirm();say('Saving your change...');render() end
 task.delay(25,function()
  if alive and busy and token==serial then busy=false;serial=serial+1;render();say(pending and 'Save/connection delayed. RESUME keeps the same transaction ID.' or 'Connection delayed. Try again.') end
 end)
 task.spawn(function()
  local ok,result=pcall(API.InvokeServer,API,action,payload)
  if not alive or token~=serial then return end
  busy=false
  if not ok or type(result)~='table' then render();say('Connection interrupted. Use RESUME for a pending transaction.');return end
  local before=viewKey(state)
  if type(result.Profile)=='table' then
   state=Model.Accept(state,result.Profile)
  end
  if pending and action==pending.Action and result.Pending~=true and (result.Profile or result.Receipt) then pending=nil end
  if result.OK and result.Receipt and result.Receipt.Kind=='Buy' then current='INVENTORY';category=nil;inventoryFilter='All';page=1 end
  if action~='Sync' or viewKey(state)~=before then render() end
  if action~='Sync' or result.OK~=true then say(result.Message or 'Your inventory is ready.') end
  if action=='GemPrompt' and result.OK and type(result.ProductId)=='number' then
   local good,err=pcall(Marketplace.PromptProductPurchase,Marketplace,me,result.ProductId)
   if not good then say('Roblox purchase window unavailable: '..tostring(err)) end
  end
  local receipt=result.OK and result.Receipt
  if receipt and receipt.Kind=='Open' and Catalog.Get(receipt.Item) and not shown[receipt.Token] then
   if g==generation and backdrop.Visible and me:GetAttribute('InRound')~=true then shown[receipt.Token]=true;revealReceipt(receipt,false)
   else say('Opening completed. Your effect is in INVENTORY.') end
  end
 end)
end
hide=function()
 generation=generation+1;backdrop.Visible=false;stopConfirm();clearBody()
 if Reveal then Reveal.Stop() end
 me:SetAttribute('HABCollectionOpen',false)
end
show=function(tab)
 if me:GetAttribute('InRound')==true then return end
 if Reveal and Reveal.IsPlaying() then return end
 if tab=='EFFECTS' then tab='INVENTORY' end
 if tab=='CRATES' or tab=='INVENTORY' or tab=='GEMS' or tab=='QUESTS' then
  current=tab;category=nil;selected=nil;page=1;inventoryFilter='All'
 end
 generation=generation+1
 backdrop.Visible=true;me:SetAttribute('HABCollectionOpen',true);render()
 if loaded then lastSync=os.clock();request('Sync') end
end
for _,name in ipairs({'CRATES','INVENTORY','ROBUX'}) do
 tabs[name]=button(root,'Nav'..name,name,({CRATES=C.violet,INVENTORY=C.gold,EFFECTS=C.green,GEMS=C.cyan,ROBUX=C.cyan,QUESTS=C.gold})[name],function()
  if confirmation then return end
  current=name=='ROBUX' and 'GEMS' or name;category=nil;selected=nil;inventoryFilter='All';page=1;render()
 end,links)
end
link(close.Activated,hide)
link(gemsButton.Activated,function() if not confirmation and not busy then current='GEMS';category=nil;page=1;render() end end)
link(backButton.Activated,function() if not confirmation then current='INVENTORY';inventoryFilter='All';category=nil;page=1;render() end end)
link(resume.Activated,function() if pending and not busy then request(pending.Action,pending.Payload) end end)
link(me:GetAttributeChangedSignal('HABCollectionRequest'),function() show(me:GetAttribute('HABCollectionTab') or 'CRATES') end)
link(me:GetAttributeChangedSignal('HABExpansionOpen'),function() if me:GetAttribute('HABExpansionOpen')==true then hide() end end)
link(me:GetAttributeChangedSignal('InRound'),function() if me:GetAttribute('InRound')==true then hide() end end)
link(me.CharacterRemoving,hide)
link(me:GetAttributeChangedSignal('HussEconomyReady'),function()
 if loaded and backdrop.Visible and not busy then lastSync=0 end
end)
link(Input.InputBegan,function(input,processed)
 if processed or Input:GetFocusedTextBox() then return end
 if input.KeyCode==Enum.KeyCode.J then if backdrop.Visible then hide() else show('CRATES') end
 elseif backdrop.Visible and (input.KeyCode==Enum.KeyCode.Escape or input.KeyCode==Enum.KeyCode.ButtonB) then if confirmation then stopConfirm() else hide() end end
end)
link(Run.RenderStepped,function()
 if not alive then return end
 local size=backdrop.AbsoluteSize
 if size~=lastSize then lastSize=size;if backdrop.Visible then stopConfirm();render() else fit() end end
 if not backdrop.Visible then return end
 local now=os.clock()
 for i,a in ipairs(animated) do a:Pose(reduced() and 0 or math.sin(now*.45+i)*.12,0,0,reduced() and 0 or math.sin(now*1.1+i)*.07) end
 local status=me:GetAttribute('HussSaveStatus') or state.SaveStatus or 'LOADING'
 saveText.Text=status=='SAVED' and 'SAVED' or 'SAVE: '..status
 saveText.TextColor3=status=='SAVED' and C.green or C.gold
 if loaded and now-lastSync>7 and not busy and not pending and not confirmation then lastSync=now;request('Sync') end
end)
link(script.Destroying,function()
 alive=false;generation=generation+1;clear(links);stopConfirm();clearBody();if Reveal then Reveal.Stop() end
 me:SetAttribute('HABCollectionOpen',false);T.Destroy();gui:Destroy()
end)
fit()
task.spawn(function()
 local ok,err=xpcall(function()
  Catalog=require(assert(Pack:WaitForChild('Catalog',20),'Catalog missing'))
  Canvas=require(assert(Pack:WaitForChild('FXCanvas',20),'FXCanvas missing'))
  Art=require(assert(Pack:WaitForChild('CrateArt',20),'CrateArt missing'))
  Reveal=require(assert(Pack:WaitForChild('CrateReveal',20),'CrateReveal missing'))
  API=assert(Pack:WaitForChild('Api',20),'Crate Api missing');Events=assert(Pack:WaitForChild('Events',20),'Crate events missing')
  link(Events.OnClientEvent,function(action) if action=='Show' then show('CRATES') end end)
  loaded=true;render();request('Sync')
 end,debug.traceback)
 if not ok then warn('[HAB Collections] '..tostring(err));say('A collection component did not load. See [HAB Collections] in Output.') end
end)
print('[HAB Polish] Roomy inventory: 1-4 large animated cards per page; same saves and crate transactions.')
-- HAB_EXPANSION_7


-- HAB_FUN_9
