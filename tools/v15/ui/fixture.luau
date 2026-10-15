camera.CFrame=CFrame.new(0,10,30)
local coreEmotesEnabled=true
services.StarterGui={SetCoreGuiEnabled=function(_,kind,enabled) if kind==Enum.CoreGuiType.EmotesMenu then coreEmotesEnabled=enabled end end}
local cache={}
local function module(parent,name,value)
 local m=Instance.new('ModuleScript',parent);m.Name=name;cache[m]=value;return m
end
local oldRequire=require
local function require(m) if cache[m]~=nil then return cache[m] end;return oldRequire(m) end
local Modal=(function() {{HABModalV15.luau}} end)()
local Layout=(function() {{HABUILayoutV15.luau}} end)()
local Theme=(function() {{HABReferenceThemeV15.luau}} end)()
module(ReplicatedStorage,'HABModalV15',Modal)
module(ReplicatedStorage,'HABUILayoutV15',Layout)
local Catalog=(function() {{CATALOG}} end)()
module(ReplicatedStorage,'HussCatalogV11',Catalog)
module(ReplicatedStorage,'BombSkinBuilderV12',{Apply=function() end})
local pack=Instance.new('Folder',ReplicatedStorage);pack.Name='HABHalloween'
module(pack,'HABReferenceTheme',Theme)
local expansion=Instance.new('Folder',ReplicatedStorage);expansion.Name='HABExpansion'
local ability={Key='Speed',Name='OVERDRIVE',Currency='Free',Description='Brief speed boost.',Cooldown=20,Color=Color3.fromRGB(255,185,68)}
local configValue={DefaultAbility='Speed',Abilities={ability,{Key='Shield',Name='PHASE GUARD',Currency='Free',Description='Block one hit.',Cooldown=18,Color=Color3.fromRGB(94,226,255)}},Passes={{Key='Throw',Id=0,Name='Bomb Pitcher',Description='Throw your bomb.',Color=Color3.fromRGB(255,111,82)}},Bundles={},Swing={Cooldown=.48},Throw={Cooldown=12}}
module(expansion,'Config',configValue)
local api=Instance.new('RemoteFunction',expansion);api.Name='Api'
local profile={Ready=true,Ability='Speed',Abilities={Speed=true,Shield=true},Passes={},Offers={},Coins=1200,Gems=100}
api._response=function(action,key) if action=='SelectAbility' then profile.Ability=key;player:SetAttribute('HABAbility',key) end;return {OK=true,Profile=profile} end
local http={GenerateGUID=function() return 'test-token' end};services.HttpService=http
local market={PromptGamePassPurchaseFinished=signal(),calls={}}
function market:GetProductInfoAsync(id) return {IsForSale=true,PriceInRobux=99} end
function market:PromptGamePassPurchase(p,id) table.insert(self.calls,{'Pass',id}) end
function market:PromptProductPurchase(p,id) table.insert(self.calls,{'Product',id}) end
services.MarketplaceService=market
local collectionCatalog={Order={},Items={},ById={},Crates={},Get=function() return nil end}
local vm={Empty=function() return {Ready=false,Owned={},Equipped={},Products={},Quests={},StoredCrates={},StoredCounts={},Pools={},HasInventory=false,RandomAllowed=false} end,Accept=function(old,new) return new end,Pool=function() return {Items={},Reserved={},RandomStored=0,CanBuy=false} end,Inventory=function() return {} end,Count=function() return 0,0 end,Odds=function() return '' end}
module(pack,'CollectionViewModel',vm);module(pack,'Catalog',collectionCatalog)
module(pack,'FXCanvas',{Mount=function() return {Stop=function() end} end});module(pack,'CrateArt',{Mount=function() return {Pose=function() end,Destroy=function() end} end});module(pack,'CrateReveal',{Stop=function() end,IsPlaying=function() return false end})
local crateApi=Instance.new('RemoteFunction',pack);crateApi.Name='Api';crateApi._response=function() local p=vm.Empty();p.Ready=true;p.Gems=50;p.Coins=100;return {OK=true,Profile=p} end
local events=Instance.new('RemoteEvent',pack);events.Name='Events'
local economy=Instance.new('RemoteEvent',ReplicatedStorage);economy.Name='HussEconomyV9'
local cosmetics=Instance.new('RemoteEvent',ReplicatedStorage);cosmetics.Name='HussCosmeticsV11'
local tags={};services.CollectionService={}
function services.CollectionService:HasTag(o,key) return tags[o] and tags[o][key]==true end
function services.CollectionService:GetTagged(key) local out={};for o,t in pairs(tags) do if t[key] then table.insert(out,o) end end;return out end
local bound={}
function RunService:BindToRenderStep(name,priority,fn) bound[name]=fn end
function RunService:UnbindFromRenderStep(name) bound[name]=nil end
local lobby=Instance.new('Model',workspace);lobby.Name='Lobby'
local booth=Instance.new('Model',lobby);booth.Name='BombsKiosk'
local anchor=Instance.new('Part',booth);anchor.Name='ShopAnchorV12';anchor.Position=Vector3.new(0,0,0);tags[anchor]={HussShopStandV12=true}
anchor:SetAttribute('HussShopCategory','Bombs');anchor:SetAttribute('HussShopStandEnabled',true)
local panel=Instance.new('Part',booth);panel.Name='ShopPanelV12';panel:SetAttribute('HussShopPanelVersion',12)
local hrp=Instance.new('Part',character);hrp.Name='HumanoidRootPart';hrp.Position=Vector3.new(100,0,0)
character.Parent=workspace
local script=Instance.new('LocalScript')
local HUD=(function() {{HudControllerV15.luau}} end)()
HUD.Init()
local actionCalls={}
local Combat=(function() {{HABCombatHUDV15.luau}} end)()(function(key) actionCalls[#actionCalls+1]=key end)
local storeScript=Instance.new('LocalScript')
;(function() local script=storeScript {{HABExpansionClientV15.client.luau}} end)()
local crateScript=Instance.new('LocalScript')
;(function() local script=crateScript {{HABCrateShopClientV15.client.luau}} end)()
local standScript=Instance.new('LocalScript')
;(function() local script=standScript {{StandShopV15.client.luau}} end)()
local killScript=Instance.new('LocalScript')
services.Debris={AddItem=function() end}
module(pack,'Renderer',{})
module(pack,'HABKillSoundPlayer',{Play=function() end})
;(function() local script=killScript {{HABCombatFXV15.client.luau}} end)()
local function node(name,parent) return (parent or playerGui):FindFirstChild(name,true) end
local function press(name,parent) local b=assert(node(name,parent),'Missing '..name);b.Activated:Fire();return b end
local function pump() for _=1,3 do tickFrame(.04) end end
pump()
local hud=node('BombTagHUD');local menu=node('MenuOptions',hud)
local count=0;for _,b in ipairs(menu:GetChildren()) do if b:IsA('TextButton') then count+=1 end end
check(count==4,'four-entry lobby dock')
check(coreEmotesEnabled==false,'retired Roblox emote menu stays hidden')
press('AFK',hud)
check(serverCalls[#serverCalls].remote=='BombTagAFKRequest' and serverCalls[#serverCalls].args[1]==true,'AFK uses existing server request')
player:SetAttribute('BombTagAFK',true);pump();check(node('AFK',hud).Text=='RETURN TO PLAY','AFK acknowledgement reflected')
player:SetAttribute('BombTagAFK',false)
voteRemote.OnClientEvent:Fire('Open',{Open=true,Options={'Sky Garden','Sunset Docks','Frostfall Village'},EndsAt=clockNow+20,Counts={}});pump()
check(Modal.Current()=='hud' and node('VoteCards',hud).Visible,'server vote opens modal')
press('Map1',hud);check(serverCalls[#serverCalls].remote=='BombTagVoteV6' and serverCalls[#serverCalls].args[1]=='Vote' and serverCalls[#serverCalls].args[2]=='Sky Garden','map vote callback unchanged')
press('Close',hud);pump();check(node('VoteReopen',hud).Visible,'vote can be reopened')
press('VoteReopen',hud);check(node('VoteCards',hud).Visible,'vote reopening restores cards')
voteRemote.OnClientEvent:Fire('Close',{});pump()
press('MENU',menu);check(Modal.Current()=='hud','core Menu owns modal')
check(node('Menu_STATS',hud)~=nil and node('Menu_SETTINGS',hud)~=nil,'secondary stats/settings accessible')
press('Menu_STATS',hud);check(node('Stat_Kills',hud)~=nil,'kills stats page retained')
press('Close',hud);check(Modal.Current()==nil,'close clears core ownership')
press('MENU',menu);press('Menu_SETTINGS',hud);press('Music',hud)
check(player:GetAttribute('HussMusicMuted')==true,'settings music toggle preserved')
press('Motion',hud);check(player:GetAttribute('HussReducedMotion')==true,'reduced-motion preference preserved')
press('Motion',hud);press('Close',hud)

press('ABILITIES',menu);pump();check(Modal.Current()=='abilities','dock opens real ability picker')
check(player:GetAttribute('HABExpansionOpen')==true and player:GetAttribute('HABAbilityMenuOpen')==true,'ability input flags consistent')
player:SetAttribute('HABExpansionTab','PASSES');player:SetAttribute('HABExpansionRequest',2);pump()
check(Modal.Current()=='store' and not node('AbilityBackdrop').Visible,'store replaces ability picker')
check(node('PassBuy_Throw'):GetAttribute('HussDisabled')==true,'unconfigured pass unavailable')
profile.Offers.Throw={Configured=true,Available=true,Id=123,PriceInRobux=99}
player:SetAttribute('HABExpansionRequest',3);pump();check(node('PassBuy_Throw'):GetAttribute('HussDisabled')==false,'server verified offer enables pass')
player:SetAttribute('HABCollectionTab','INVENTORY');player:SetAttribute('HABCollectionRequest',1);pump()
check(Modal.Current()=='collection' and player:GetAttribute('HABExpansionOpen')==false,'collection replaces store')
check(node('CollectionBackdrop').Visible,'collection visible')
press('Close',node('HABReliquaryGui'));pump();check(Modal.Current()==nil,'collection close releases ownership')
press('INDEX',menu);pump();check(Modal.Current()=='hud','locker opens core modal')
local snapshot={kind='Profile',ready=true,requestId=1,mode='live',Coins=1000,Owned={'bomb_classic','default','title_rookie'},EquippedByCategory={Bombs='bomb_classic',Trails='default',Titles='title_rookie'},Catalog=Catalog.Items,Quests={}}
economy.OnClientEvent:Fire(snapshot);pump()
check(node('Category_Bombs',hud) and node('Category_Trails',hud) and node('Category_Titles',hud),'locker categories retained')
check(not node('Category_Emotes',hud),'retired emotes remain absent')
press('Close',hud)
hrp.Position=Vector3.new(0,0,0);pump();check(Modal.Current()=='stand','walking into booth opens physical shop')
check(node('HussStandShopV12')~=nil,'physical SurfaceGui created')
player:SetAttribute('HABAbilityMenuRequest',7);pump();check(Modal.Current()=='abilities','picker closes nearby stand')
check(node('HussStandShopV12')==nil,'previous booth SurfaceGui destroyed')
press('AbilityClose')
local lockerBooth=Instance.new('Model',lobby);lockerBooth.Name='EmotesKiosk'
local lockerAnchor=Instance.new('Part',lockerBooth);lockerAnchor.Name='ShopAnchorV12';lockerAnchor.Position=Vector3.new(30,0,0)
lockerAnchor:SetAttribute('HussShopCategory','Emotes');lockerAnchor:SetAttribute('HussShopStandEnabled',true);tags[lockerAnchor]={HussShopStandV12=true}
local lockerPanel=Instance.new('Part',lockerBooth);lockerPanel.Name='ShopPanelV12';lockerPanel:SetAttribute('HussShopPanelVersion',12)
hrp.Position=Vector3.new(30,0,0);pump()
check(Modal.Current()=='collection' and player:GetAttribute('HABCollectionTab')=='INVENTORY','retired emote booth opens actual effects collection')
check(node('HussStandShopV12')==nil,'repurposed booth cannot display retired emote Buy controls')
press('Close',node('HABReliquaryGui'));pump();check(Modal.Current()==nil,'dismissed locker does not immediately reopen')
player:SetAttribute('InRound',true);pump();check(Modal.Current()==nil,'round start closes lobby menus')
check(not node('Wallet',hud).Visible and not node('GemWallet',hud).Visible,'wallets hidden during match')
check(node('PolishAbility').Visible and not node('PolishSwing').Visible and not node('PolishThrow').Visible,'runner sees only ability')
character:SetAttribute('HussBombCarrier',true);pump();check(node('PolishSwing').Visible and not node('PolishThrow').Visible,'carrier sees tag; no unowned throw')
player:SetAttribute('HABPassThrow',true);pump();check(node('PolishThrow').Visible,'owned throw appears for carrier')
press('PolishAbility');press('PolishSwing');press('PolishThrow');check(table.concat(actionCalls,',')=='Ability,Swing,Throw','actual button callbacks preserved')
player:SetAttribute('HABAbilityReadyAt',clockNow+4);pump();check(node('PolishAbility'):GetAttribute('HussDisabled')==true,'ability cooldown disables input')
character:SetAttribute('HussBombCarrier',false);pump();check(not node('PolishSwing').Visible and not node('PolishThrow').Visible,'carrier actions clear after pass')
remoteObjects.BombState.OnClientEvent:Fire({Active=true,CarrierUserId=42,CarrierName='Tester',EndTime=clockNow+10,Event='Started'})
remoteObjects.RoundState.OnClientEvent:Fire({State='ROUND',Alive=2});pump()
check(node('Bomb',hud).Visible,'live fuse remains visible')
local dimensions={{1920,1044,false},{1280,684,false},{390,808,true},{320,444,true},{844,354,true},{568,284,true},{640,320,true},{568,240,true}}
local function overlap(a,b) return a.x<b.x+b.w and a.x+a.w>b.x and a.y<b.y+b.h and a.y+a.h>b.y end
for _,d in ipairs(dimensions) do
 for actions=1,3 do
  local l=Layout.Measure(d[1],d[2],d[3],actions)
  for _,key in ipairs({'status','fuse','actions','weave','dock'}) do
   local b=l[key];check(b.x>=0 and b.y>=0 and b.x+b.w<=d[1] and b.y+b.h<=d[2],key..' within '..d[1]..'x'..d[2])
  end
  check(not overlap(l.status,l.fuse),'status/fuse separation')
  check(not overlap(l.fuse,l.weave),'fuse/weave separation')
  check(not overlap(l.weave,l.actions),'weave/action separation')
  check(l.actions.h>=48,'minimum action target')
 end
end
-- Execute the actual GUI layout after each viewport change, including inset.
for _,d in ipairs(dimensions) do
 camera.ViewportSize=Vector2.new(d[1],d[2]+insetTop);UserInputService.TouchEnabled=d[3];pump()
 local l=Layout.Measure(d[1],d[2],d[3],1)
 local status=node('MatchStatus',hud);local fuse=node('Bomb',hud);local actions=node('RoundActions')
 check(status.AbsolutePosition.X==l.status.x and status.AbsolutePosition.Y==l.status.y+insetTop,'actual HUD status uses shared layout')
 check(fuse.AbsolutePosition.X==l.fuse.x and fuse.AbsolutePosition.Y==l.fuse.y+insetTop,'actual HUD fuse uses shared layout')
 check(actions.AbsolutePosition.Y==l.actions.y+insetTop,'actual combat row uses shared layout')
end
player:SetAttribute('HussReducedMotion',true)
for i=1,4 do events.OnClientEvent:Fire('Detonation',{Id='test'..i,Position=Vector3.zero,Time=clockNow,Cause='ARENA',KillerUserId=0,VictimName='Player '..i}) end
pump()
local feed=node('HABKillFeed');local feedRows=feed:GetChildren()[1]:GetChildren()
check(#feedRows==3,'kill feed capped at three rows')
local visibleRows=0;for _,r in ipairs(feedRows) do if r.Visible then visibleRows+=1 end end
check(visibleRows==1,'touch feed shows only most recent elimination')
Modal.Acquire('test',function() end);pump();check(feed.Enabled==false,'kill feed hides behind modal')
Modal.Release('test');pump();check(feed.Enabled==true,'kill feed restores after modal')
player:SetAttribute('HussReducedMotion',false)
-- Owner transfer deliberately runs a previous release; it must not clear the next owner.
local closed=0
Modal.Acquire('old',function() closed+=1;Modal.Release('old') end)
Modal.Acquire('next',function() end)
check(closed==1 and Modal.Current()=='next' and player:GetAttribute('HABModalOwnerV15')=='next','atomic modal transfer')
Modal.Release('old');check(Modal.Current()=='next','stale close cannot clear new panel')
Modal.Release('next');check(player:GetAttribute('HABModalOwnerV15')==nil,'ownership attribute cleared')
local function encode(value)
 if value==nil then return 'null' end
 local kind=type(value)
 if kind=='boolean' or kind=='number' then return tostring(value) end
 if kind=='string' then return '"'..value:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')..'"' end
 local out={};for i,v in ipairs(value) do out[#out+1]=encode(v) end
 return '['..table.concat(out,',')..']'
end
local function snapshot(name)
 local records={}
 for _,o in ipairs(playerGui:GetDescendants()) do if o:IsA('GuiObject') then
  local visible=true;local at=o;local order=0
  while at and at~=playerGui do
   if at:IsA('GuiObject') and at.Visible==false then visible=false end
   if at:IsA('ScreenGui') then order=at.DisplayOrder or 0;if at.Enabled==false then visible=false end end
   at=at.Parent
  end
  if visible then
   local pos,size=o.AbsolutePosition,o.AbsoluteSize
   local color=o.BackgroundColor3 or Color3.new(0,0,0)
   local tc=o.TextColor3 or Color3.new(1,1,1);local corner=o:FindFirstChildOfClass('UICorner')
   local stroke=o:FindFirstChildOfClass('UIStroke')
   local strColor=stroke and stroke.Color or Color3.new(0,0,0)
   local txt=(o.TextTransparency or 0)<.99 and (o.Text or '') or ''
   if size.X>0 and size.Y>0 then records[#records+1]={o.Name,pos.X,pos.Y,size.X,size.Y,order*1000+o.ZIndex,color.R,color.G,color.B,o.BackgroundTransparency or 0,corner and corner.CornerRadius.Offset or 0,txt,o.TextSize or 14,tc.R,tc.G,tc.B,o.TextXAlignment and o.TextXAlignment.Name or 'Center',o.Rotation or 0,stroke and stroke.Thickness or 0,strColor.R,strColor.G,strColor.B} end
  end
 end end
 print('UI_SNAPSHOT '..encode({name,camera.ViewportSize.X,camera.ViewportSize.Y,records}))
end
camera.ViewportSize=Vector2.new(1280,720);UserInputService.TouchEnabled=false
player:SetAttribute('HussEconomyReady',true);player:SetAttribute('Coins',1000);player:SetAttribute('Gems',50)
hrp.Position=Vector3.new(100,0,0);player:SetAttribute('InRound',false);remoteObjects.RoundState.OnClientEvent:Fire({State='INTERMISSION',TimeLeft=20});tickFrame(7);pump();snapshot('lobby')
press('INDEX',menu);pump();snapshot('locker');press('Close',hud)
player:SetAttribute('InRound',true);character:SetAttribute('HussBombCarrier',true);player:SetAttribute('HABAbilityReadyAt',0)
remoteObjects.RoundState.OnClientEvent:Fire({State='ROUND',Alive=8});remoteObjects.BombState.OnClientEvent:Fire({Active=true,CarrierUserId=42,CarrierName='Tester',EndTime=clockNow+7.8,Event='Started'});pump();snapshot('match')
HUD.Destroy();Combat.Destroy();storeScript:Destroy();crateScript:Destroy();standScript:Destroy();killScript:Destroy()
check(not node('BombTagHUD') and not node('HABActionHUD') and not node('HABExpansionGui'),'UI cleanup destroys screens')
assert(#failures==0,table.concat(failures,'\n'))
print('UI_V15 '..checks..' assertions passed')
