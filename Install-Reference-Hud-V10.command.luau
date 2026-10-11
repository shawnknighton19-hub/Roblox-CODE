-- HUSS A BOMB V10: REFERENCE-STYLE HUD
-- Run in Studio's Command Bar with Play stopped. Supports the V8 or V9 HUD.
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'Stop Play before installing the HUD.')
local starter=game:GetService('StarterPlayer'):FindFirstChild('StarterPlayerScripts')
local controllers=starter and starter:FindFirstChild('Controllers')
local hud=controllers and controllers:FindFirstChild('HudController')
assert(hud and hud:IsA('ModuleScript'),'StarterPlayerScripts/Controllers/HudController is missing. Nothing changed.')
local storage=game:GetService('ServerStorage')

local patchHUD=(function()
-- V10 reference styling. Uses GUI shapes only; no external image assets or paid-product controls.
return function(source)
 local marker='-- HussReferenceHudV10'
 assert(source:find('-- HussGlossV8',1,true),'Install V8 or V9 before this HUD update. Nothing changed.')
 if source:find(marker,1,true) then assert(source:find('local function emblem',1,true),'Incomplete V10 HUD.');return source end
 local economy=source:find('-- HussEconomyHudV9',1,true)~=nil
 local function replace(old,new)
  local a,b=source:find(old,1,true);assert(a and not source:find(old,b+1,true),'Unexpected HUD section: '..old:sub(1,42));source=source:sub(1,a-1)..new..source:sub(b+1)
 end
 local function section(first,last,value)
  local a=source:find(first,1,true);local b=a and source:find(last,a+1,true);assert(a and b,'HUD styling section changed.');source=source:sub(1,a-1)..value..'\n'..source:sub(b)
 end
 section('local C={','local U, links',[=[-- HussReferenceHudV10
local C={ink=rgb(13,20,28),panel=rgb(35,40,50),line=rgb(101,135,163),white=rgb(255,255,255),muted=rgb(233,244,255),green=rgb(106,255,76),red=rgb(255,76,98),gold=rgb(255,218,48),cyan=rgb(62,230,255),violet=rgb(196,131,255)}
local tones={STATS=rgb(255,159,29),CONTROLS=rgb(57,154,255),['HOW TO PLAY']=rgb(170,82,246),MAPS=rgb(29,193,182),SETTINGS=rgb(232,85,188),Close=rgb(248,64,90),AFK=rgb(70,140,230),VoteReopen=rgb(255,179,23),Continue=rgb(30,220,91),Music=rgb(155,89,245),SoundEffects=rgb(30,196,218),Motion=rgb(166,83,231),SHOP=rgb(15,220,102),QUESTS=rgb(255,169,22),LEADERBOARDS=rgb(255,199,24),Home=rgb(37,218,248),Hub=rgb(255,199,24)}
local panelTones={MatchStatus=rgb(21,170,234),Identity=rgb(140,80,218),MatchInfo=rgb(24,128,207),Bomb=rgb(245,149,25),Dodge=rgb(21,175,107),LobbyFooter=rgb(110,84,205),Notification=rgb(27,152,211),Wallet=rgb(250,181,25)}]=])
 replace('TextStrokeTransparency=.18','TextStrokeTransparency=1')
 -- Both supported HUD versions use this return immediately after text construction.
 replace(' return o\nend\nlocal function motion',[=[ local outline=make('UIStroke',o,{Color=C.ink,Thickness=size>=18 and 2.3 or 1.3,Transparency=0,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 o.Font=size>=18 and Enum.Font.FredokaOne or Enum.Font.GothamBlack
 return o
end
local function motion]=])
 section('local function gloss(o)','local function bar(parent',[=[local function edge(o,color,width)
 return make('UIStroke',o,{Color=color,Thickness=width or 3,Transparency=0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function gloss(o,checks)
 o.ClipsDescendants=false
 make('UIGradient',o,{Color=ColorSequence.new(C.white,rgb(159,205,181)),Rotation=90})
 local bottom=frame(o,'DropEdge',3,0,1,7,C.ink,o.ZIndex+1);bottom.Position=UDim2.new(0,3,1,-7);bottom.Size=UDim2.new(1,-6,0,7);rounded(bottom,5)
 if checks then
  local tile=frame(o,'Checkers',4,4,1,1,C.white,o.ZIndex+1);tile.Size=UDim2.new(1,-8,1,-13);tile.BackgroundTransparency=1;tile.ClipsDescendants=true;rounded(tile,8)
  for row=0,3 do for col=0,11 do if (row+col)%2==0 then
   local cell=frame(tile,'Tile',0,0,1,1,C.white,tile.ZIndex);cell.Position=UDim2.fromScale(col/12,row/4);cell.Size=UDim2.fromScale(1/12,1/4);cell.BackgroundTransparency=.9
  end end end
 end
 local shine=frame(o,'Gloss',4,4,1,1,C.white,o.ZIndex+2);shine.Size=UDim2.new(1,-8,.45,-4);shine.BackgroundTransparency=checks and .86 or .96;rounded(shine,8)
 local inset=frame(o,'InnerRim',4,4,1,1,C.white,o.ZIndex+2);inset.Size=UDim2.new(1,-8,1,-12);inset.BackgroundTransparency=1;rounded(inset,8)
 return edge(inset,C.white:Lerp(o.BackgroundColor3,.45),2)
end
local function emblem(parent,kind,size,color)
 local host=frame(parent,'Illustration',0,0,size,size,C.white,parent.ZIndex+4);host.BackgroundTransparency=1
 local unit=size/100;local z=host.ZIndex
 local function part(name,x,y,w,h,tint,radius,angle,line)
  local p=frame(host,name,x*unit,y*unit,w*unit,h*unit,tint,z);if radius then rounded(p,radius*unit) end
  p.Rotation=angle or 0;if line~=false then edge(p,C.ink,math.max(2,4*unit)) end;return p
 end
 local bright=color or C.gold
 if kind=='SHOP' then
  part('Bundle',15,31,70,47,rgb(25,155,68),6,-12);part('CashTop',15,19,70,42,rgb(103,241,93),5,-12)
  part('CashBand',42,18,19,58,C.gold,2,-12);part('BandShine',45,20,5,50,rgb(255,245,151),1,-12,false)
 elseif kind=='Home' then
  part('Roof',24,12,52,52,rgb(68,161,255),3,45);part('House',23,43,55,44,rgb(53,139,242),4)
  part('Door',44,61,18,28,rgb(97,225,255),4,0,false)
 elseif kind=='Hub' or kind=='LEADERBOARDS' or kind=='STATS' then
  part('LeftHandle',9,23,27,34,C.gold,12);part('RightHandle',65,23,27,34,C.gold,12)
  part('Stem',44,55,13,25,rgb(244,166,33),3);part('Base',26,78,48,13,C.gold,4)
  part('Cup',24,13,52,49,rgb(255,197,32),16);part('CupShine',32,22,34,8,rgb(255,242,128),4,0,false)
 elseif kind=='QUESTS' then
  part('Paper',22,12,57,75,rgb(255,237,166),6,5);part('Clip',36,5,30,17,rgb(255,174,28),4)
  part('CheckShort',34,49,12,27,rgb(51,192,76),3,-42,false);part('CheckLong',49,31,12,45,rgb(51,192,76),3,35,false)
 elseif kind=='SETTINGS' then
  for i=0,3 do part('Cog',40,6,20,88,rgb(242,178,242),4,i*45) end
  part('Gear',20,20,60,60,rgb(242,178,242),30);part('Center',37,37,26,26,rgb(131,61,166),13)
 elseif kind=='MAPS' then
  part('Map',15,17,71,64,rgb(120,244,176),5,-6);part('Route1',23,42,56,10,rgb(247,246,174),2,-24,false)
  part('Pin',47,25,27,27,rgb(249,93,101),14);part('PinPoint',52,44,16,16,rgb(249,93,101),2,45,false)
 elseif kind=='CONTROLS' or kind=='HOW TO PLAY' then
  part('Key',12,24,76,53,rgb(163,220,255),12);part('Cross1',27,36,9,29,rgb(39,77,122),2,0,false);part('Cross2',17,46,29,9,rgb(39,77,122),2,0,false)
  part('Dot1',61,38,11,11,C.gold,6,0,false);part('Dot2',68,55,11,11,C.red,6,0,false)
 else
  -- A distinct large comet illustration previews the trail's actual server color.
  part('TailLong',3,55,70,14,bright,7,-25);part('TailMiddle',12,32,58,14,bright:Lerp(C.white,.3),7,-25)
  part('TailShort',27,14,39,12,bright,6,-25)
  part('Burst',49,24,43,43,bright,5,45);part('Core',60,35,21,21,bright:Lerp(C.white,.78),4,45,false)
  part('Spark',79,4,10,10,C.white,2,45,false);part('SmallSpark',32,84,7,7,bright,2,45,false)
 end
 return host
end
local function panel(parent,name,w,h,z,accent)
 local o=frame(parent,name,0,0,w,h,panelTones[name] or C.panel,z)
 o.BackgroundTransparency=0;rounded(o,14);edge(o,C.ink,4)
 local rim=gloss(o,panelTones[name]~=nil);rim.Color=accent or C.white:Lerp(o.BackgroundColor3,.35)
 return o,rim
end
local function button(parent,name,caption,callback,danger,bucket)
 local purchase=name:sub(1,5)=='Item_' or name:sub(1,6)=='Quest_'
 local tone=danger and tones.Close or purchase and rgb(25,227,48) or tones[name:sub(1,3)=='Nav' and name:sub(4) or name] or rgb(47,175,228)
 local b=make('TextButton',parent,{Name=name,Text=caption,TextTransparency=1,TextStrokeTransparency=1,TextTruncate=Enum.TextTruncate.AtEnd,Size=UDim2.fromOffset(120,44),BackgroundColor3=tone,TextColor3=C.white,Font=Enum.Font.GothamBlack,TextSize=16,AutoButtonColor=false,BorderSizePixel=0,ZIndex=(parent.ZIndex or 1)+3})
 rounded(b,12);edge(b,C.ink,4);local rim=gloss(b,true)
 local label=text(b,'ButtonCaption',caption,5,-2,110,44,16,C.white,Enum.TextXAlignment.Center);label.Size=UDim2.new(1,-10,1,0);label.ZIndex=b.ZIndex+6
 local function captionUpdate()
  label.Text=b.Text;label.TextColor3=b.TextColor3;label.TextSize=b.TextSize;label.TextTruncate=b.TextTruncate;label.TextXAlignment=b.TextXAlignment;label.Font=b.TextSize>=18 and Enum.Font.FredokaOne or Enum.Font.GothamBlack
  label:FindFirstChildOfClass('UIStroke').Thickness=b.TextSize>=18 and 2.6 or 1.5
 end
 for _,key in ipairs({'Text','TextColor3','TextSize','TextTruncate','TextXAlignment'}) do connect(b:GetPropertyChangedSignal(key),captionUpdate,bucket) end
 local focused=false
 local function paint()
  local selected=b:GetAttribute('HussSelected')==true;local disabled=b:GetAttribute('HussDisabled')==true
  local color=selected and rgb(47,222,66) or (disabled and rgb(83,110,93) or tone)
  b.Interactable=not disabled;b.Selectable=not disabled
  motion(rim,{Color=selected and C.gold or (focused and not disabled and C.white or color:Lerp(C.white,.45))})
  motion(b,{BackgroundColor3=focused and not disabled and color:Lerp(C.white,.14) or color})
 end
 local function focus(on) focused=on;paint() end
 connect(b.MouseEnter,function() focus(true) end,bucket);connect(b.MouseLeave,function() focus(false) end,bucket)
 connect(b.SelectionGained,function() focus(true) end,bucket);connect(b.SelectionLost,function() focus(false) end,bucket)
 connect(b:GetAttributeChangedSignal('HussSelected'),paint,bucket);connect(b:GetAttributeChangedSignal('HussDisabled'),paint,bucket)
 connect(b.Activated,function() if b:GetAttribute('HussDisabled')~=true then callback() end end,bucket);captionUpdate();return b
end]=])
 replace('U.AFK.Text=afk and \"RETURN TO MATCHMAKING\" or \"GO AFK  /  MATCHMAKING ON\"','U.AFK.Text=afk and \"RETURN TO PLAY\" or \"GO AFK\"')
 -- Menu callbacks and names are preserved, so gamepad focus and real pages still work.
 replace('local b=button(U.MenuScroll,name,name.."   ›",function() openMenu(name) end)',[=[local titles={QUESTS='Quests',SHOP='Shop',LEADERBOARDS='Hub',STATS='Stats',MAPS='Maps',SETTINGS='Settings',CONTROLS='Controls',['HOW TO PLAY']='How to Play'}
  local b=button(U.MenuScroll,name,titles[name] or name,function() openMenu(name) end)]=])
 replace('b.Size=UDim2.new(1,-4,0,48); b.Position=UDim2.fromOffset(2,(i-1)*56); b.TextXAlignment=Enum.TextXAlignment.Left',[=[b.Size=UDim2.new(1,-12,0,54);b.Position=UDim2.fromOffset(6,5+(i-1)*65);b.TextXAlignment=Enum.TextXAlignment.Left;b.TextSize=name=='HOW TO PLAY' and 17 or 23
  local icon=emblem(b,name,39);icon.Position=UDim2.fromOffset(8,4)
  local label=b.ButtonCaption;label.Position=UDim2.fromOffset(52,-2);label.Size=UDim2.new(1,-60,1,0)]=])
 replace('make("UIPadding",b,{PaddingLeft=UDim.new(0,13)}); frame(b,"Accent",0,13,3,22,C.white,b.ZIndex+1)','b:SetAttribute("HussReferenceButton",true)')
 replace('CanvasSize=UDim2.fromOffset(0,'..(economy and '446' or '278')..')','CanvasSize=UDim2.fromOffset(0,'..(economy and '525' or '330')..')')
 replace('w<420 and 174 or 186','w<420 and 180 or 214')
 replace('text(U.Lobby,"Section","L O B B Y  /  M E N U",3,0,180,16,10,C.gold)','text(U.Lobby,"Section","LOBBY",8,0,180,16,12,C.white)')
 replace('local ww=math.min(720,w-24); local wh=math.min(w<540 and 584 or 456,h-24)','local ww=math.min(940,w-24);local wh=math.min(w<540 and 650 or 620,h-24)')
 replace('U.WindowTitle=text(U.Window,"Title","",22,39,510,37,29)','U.WindowTitle=text(U.Window,"Title","",22,35,510,43,34)')
 if economy then
  replace('U.Wallet.BackgroundColor3=rgb(133,82,24)','U.Wallet.BackgroundColor3=panelTones.Wallet')
  replace("card(menu=='SHOP' and 'TRAIL COLLECTION' or 'DAILY QUESTS',menu=='SHOP' and 'Earn coins by playing. Equip a color for your sprint and weave.' or 'Complete these goals, then claim your coins. Quests reset at 00:00 UTC.',C.gold,108)",[=[card(menu=='SHOP' and 'TRAIL COLLECTION' or 'DAILY QUESTS',menu=='SHOP' and 'Your color. Your escape. Earn coins, unlock a trail, make it yours.' or 'Complete these goals, then claim your coins. Quests reset at 00:00 UTC.',C.gold,menu=='SHOP' and 82 or 108)]=])
  section('   local columns=width>=560 and 2 or 1;local start=y','  else\n   for _,q in ipairs(profile.Quests)',[=[   local columns=width>=810 and 3 or width>=520 and 2 or 1;local start=y;local height=324
   for index,item in ipairs(profile.Catalog) do
    local owned=profile.Owned[item.id];local equipped=profile.Equipped==item.id;local poor=not owned and (coins==nil or coins<item.price)
    local c=card(item.name:upper(),equipped and 'Your active sprint + weave trail' or owned and 'Owned • ready to equip' or formatted(item.price)..' COINS\nSprint + weave color',item.color,height)
    c.Size=UDim2.new(1/columns,-16,0,height);c.Position=UDim2.new((index-1)%columns/columns,7,0,start+math.floor((index-1)/columns)*(height+20)+5)
    c.BackgroundColor3=item.color:Lerp(C.ink,.86);local inner=c:FindFirstChild('InnerRim');local rim=inner and inner:FindFirstChildOfClass('UIStroke');if rim then rim.Color=item.color;rim.Thickness=4 end
    c.Gloss:Destroy();local gradient=c:FindFirstChildOfClass('UIGradient');if gradient then gradient.Color=ColorSequence.new(rgb(60,67,70),C.white) end
    local art=emblem(c,'Trail',142,item.color);art.AnchorPoint=Vector2.new(.5,0);art.Position=UDim2.new(.5,0,0,13)
    local title=c.Heading;title.Position=UDim2.new(0,10,0,162);title.Size=UDim2.new(1,-20,0,36);title.TextSize=24;title.Font=Enum.Font.FredokaOne;title:FindFirstChildOfClass('UIStroke').Thickness=2.5;title.TextXAlignment=Enum.TextXAlignment.Center
    local body=c.Description;body.Position=UDim2.new(0,14,0,202);body.Size=UDim2.new(1,-28,0,44);body.TextSize=15;body.TextXAlignment=Enum.TextXAlignment.Center
    local b=action(c,'Item_'..item.id,busy and 'PLEASE WAIT…' or equipped and 'EQUIPPED' or owned and 'EQUIP' or poor and 'NEED MORE COINS' or 'BUY • '..formatted(item.price),function() request(owned and 'Equip' or 'Buy',item.id) end,equipped or poor)
    b.Position=UDim2.new(0,14,1,-67);b.Size=UDim2.new(1,-28,0,51);b.TextSize=poor and 14 or 20
   end
   y=start+math.ceil(#profile.Catalog/columns)*(height+20)+5]=])
  replace(' U.Body=make("ScrollingFrame",U.Window,',[=[ U.Navigation=frame(U.Window,'Navigation',22,89,1,64,C.white,54);U.Navigation.BackgroundTransparency=1;U.Navigation.Size=UDim2.new(1,-44,0,64)
 for index,entry in ipairs({{'Hub','LEADERBOARDS'},{'Home',false},{'SHOP','SHOP'}}) do
  local b=button(U.Navigation,'Nav'..entry[1],entry[1]=='SHOP' and 'Shop' or entry[1],function() if entry[2] then openMenu(entry[2]) else menu=nil;refresh() end end)
  b.BackgroundColor3=tones[entry[1]];b.Size=UDim2.new(1/3,-10,1,0);b.Position=UDim2.new((index-1)/3,5,0,0);b.TextSize=26
  local icon=emblem(b,entry[1],44);icon.Position=UDim2.fromOffset(9,6)
  b.ButtonCaption.Position=UDim2.fromOffset(59,-2);b.ButtonCaption.Size=UDim2.new(1,-65,1,0)
 end
 U.Body=make("ScrollingFrame",U.Window,]=])
  replace(' U.Shade.Visible=mode~=nil;',[=[ local tight=U.Window.Size.Y.Offset<340;local tabs=mode=='menu' and not tight
 U.Navigation.Visible=tabs
 U.WindowBrand.Visible=not tight;U.WindowTitle.Position=UDim2.fromOffset(22,tight and 8 or 35);U.WindowTitle.TextSize=tight and 25 or 34;U.Close.Position=UDim2.new(1,-60,0,tight and 8 or 16)
 U.Window.Divider.Position=UDim2.fromOffset(22,tight and 52 or 81)
 U.Body.Position=UDim2.fromOffset(22,tight and 57 or tabs and 170 or 107);U.Body.Size=UDim2.new(1,-44,1,tight and -67 or tabs and -190 or -125)
 local small=U.Window.Size.X.Offset<520
 for _,b in ipairs(U.Navigation:GetChildren()) do if b:IsA('TextButton') then
  b.Illustration.Visible=not small;b.ButtonCaption.Position=UDim2.fromOffset(small and 5 or 59,-2);b.ButtonCaption.Size=UDim2.new(1,small and -10 or -65,1,0);b.TextSize=small and 17 or 26
 end end
 U.Shade.Visible=mode~=nil;]=])
 end
 return source
end

end)()

local original=hud.Source
local updated=patchHUD(original)
assert(type(updated)=='string' and #updated>0,'HUD patch returned no source. Nothing changed.')
assert(hud.Archivable,'Set HudController.Archivable to true, then rerun. Nothing changed.')
local backup=Instance.new('Folder');backup.Name='ReferenceHUDBackup_'..os.time()
while storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local ok,err=pcall(function()
 local copy=hud:Clone();assert(copy,'Unable to clone the HUD.');copy.Parent=backup
 assert(copy.Source==original,'HUD backup source does not match the original.')
 local probe=Instance.new('ModuleScript')
 local written,message=pcall(function() probe.Source=updated end);probe:Destroy();assert(written,message)
end)
if not ok then backup:Destroy();error('HUD preflight stopped; original preserved: '..tostring(err)) end
ok,err=pcall(function()
 backup.Parent=storage;hud.Source=updated
 assert(hud.Source==updated,'Studio did not retain the new HUD source.')
end)
if not ok then
 local restored,message=pcall(function() hud.Source=original;assert(hud.Source==original,'Original source readback failed.') end)
 if restored then backup:Destroy();error('HUD installation rolled back: '..tostring(err)) end
 error('HUD installation stopped. Restore HudController from ServerStorage/'..backup.Name..'. '..tostring(message)..'. Original error: '..tostring(err))
end
print('REFERENCE HUD V10 INSTALLED AND VERIFIED')
print(updated:find('-- HussEconomyHudV9',1,true) and 'V9 coins, quests and shop remain connected.' or 'V8 menus preserved. V9 economy is not installed by this style update.')
print('Backup: ServerStorage/'..backup.Name..'. Save the place, then press Play to see the new HUD.')
