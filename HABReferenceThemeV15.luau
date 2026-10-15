--!nonstrict
-- HAB V15: shared soft glossy theme. Public API preserved for the current collection/store clients.
local Players=game:GetService('Players')
local Tween=game:GetService('TweenService')
return function()
 local P=Players.LocalPlayer
 local rgb=Color3.fromRGB
 local links,tweens={},{}
 local function connect(signal,fn,bucket)
  local c=signal:Connect(fn);table.insert(bucket or links,c);return c
 end
local C={ink=rgb(13,20,28),panel=rgb(33,40,61),line=rgb(104,132,177),white=rgb(255,255,255),muted=rgb(233,244,255),green=rgb(106,255,76),red=rgb(255,76,98),gold=rgb(255,218,48),cyan=rgb(62,230,255),violet=rgb(196,131,255)}
local tones={CRATES=rgb(155,83,238),INVENTORY=rgb(255,177,29),GEMS=rgb(23,188,237),STATS=rgb(255,159,29),CONTROLS=rgb(57,154,255),['HOW TO PLAY']=rgb(170,82,246),MAPS=rgb(29,193,182),SETTINGS=rgb(232,85,188),Close=rgb(248,64,90),AFK=rgb(70,140,230),VoteReopen=rgb(255,179,23),Continue=rgb(30,220,91),Music=rgb(155,89,245),SoundEffects=rgb(30,196,218),Motion=rgb(166,83,231),SHOP=rgb(15,220,102),QUESTS=rgb(255,169,22),LEADERBOARDS=rgb(255,199,24),Home=rgb(37,218,248),Hub=rgb(255,199,24)}
local panelTones={GemWallet=rgb(24,171,240),MatchStatus=rgb(21,170,234),Identity=rgb(140,80,218),MatchInfo=rgb(24,128,207),Bomb=rgb(245,149,25),Dodge=rgb(21,175,107),LobbyFooter=rgb(110,84,205),Notification=rgb(27,152,211),Wallet=rgb(250,181,25)}
local function make(class,parent,props)
 local o=Instance.new(class); for k,v in pairs(props or {}) do o[k]=v end; o.Parent=parent; return o
end
local function rounded(o,r) make("UICorner",o,{CornerRadius=UDim.new(0,r or 18)}) end
local function frame(parent,name,x,y,w,h,color,z)
 return make("Frame",parent,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundColor3=color or C.panel,BorderSizePixel=0,ZIndex=z or parent.ZIndex or 1})
end
local function stroke(o,color) return make("UIStroke",o,{Color=color or C.line,Thickness=2,Transparency=.12,ApplyStrokeMode=Enum.ApplyStrokeMode.Border}) end
local function text(parent,name,value,x,y,w,h,size,color,align)
 local o=make("TextLabel",parent,{Name=name,Text=value,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,Font=Enum.Font.GothamBlack,TextSize=size,TextColor3=color or C.white,TextStrokeColor3=C.ink,TextStrokeTransparency=1,TextXAlignment=align or Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=(parent.ZIndex or 1)+2})
 local outline=make('UIStroke',o,{Color=C.ink,Thickness=size>=18 and 1.5 or .65,Transparency=0,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
 o.Font=size>=18 and Enum.Font.FredokaOne or Enum.Font.GothamBlack
 return o
end
local function motion(o,goal,t)
 if tweens[o] then tweens[o]:Cancel(); tweens[o]=nil end
 if P:GetAttribute("HussReducedMotion")==true then for k,v in pairs(goal) do o[k]=v end; return end
 local a=Tween:Create(o,TweenInfo.new(t or .16,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),goal); tweens[o]=a
 local done; done=a.Completed:Connect(function() if tweens[o]==a then tweens[o]=nil end; if done then done:Disconnect() end end); a:Play()
end
local function edge(o,color,width)
 return make('UIStroke',o,{Color=color,Thickness=width or 3,Transparency=0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
local function gloss(o,checks)
 o.ClipsDescendants=false
 make('UIGradient',o,{Color=ColorSequence.new(C.white,rgb(181,201,235)),Rotation=90})
 local bottom=frame(o,'DropEdge',5,0,1,4,C.ink,o.ZIndex+1);bottom.Position=UDim2.new(0,5,1,-4);bottom.Size=UDim2.new(1,-10,0,4);bottom.BackgroundTransparency=.65;rounded(bottom,12)
 local shine=frame(o,'Gloss',5,4,1,1,C.white,o.ZIndex+2);shine.Size=UDim2.new(1,-10,.36,-2);shine.BackgroundTransparency=checks and .90 or .97;rounded(shine,16)
 local inset=frame(o,'InnerRim',3,3,1,1,C.white,o.ZIndex+2);inset.Size=UDim2.new(1,-6,1,-6);inset.BackgroundTransparency=1;rounded(inset,20)
 return edge(inset,C.white:Lerp(o.BackgroundColor3,.72),1)
end
local function emblem(parent,kind,size,color)
 local host=frame(parent,'Illustration',0,0,size,size,C.white,parent.ZIndex+4);host.BackgroundTransparency=1
 local unit=size/100;local z=host.ZIndex
 local function part(name,x,y,w,h,tint,radius,angle,line)
  local p=frame(host,name,x*unit,y*unit,w*unit,h*unit,tint,z);if radius then rounded(p,radius*unit) end
  p.Rotation=angle or 0;if line~=false then edge(p,C.ink,math.max(2,4*unit)) end;return p
 end
 local bright=color or C.gold
 if kind=='Shield' then
  part('Shield',24,15,53,65,bright,22);part('ShieldLight',34,24,11,44,C.white,6,0,false)
 elseif kind=='Speed' or kind=='Confetti' then
  for n=0,2 do part('Speed'..n,12+n*23,27,18,48,bright,8,24) end
 elseif kind=='Pulse' then
  part('Wave',12,12,76,76,bright,38);part('Core',29,29,42,42,C.ink,21,0,false);part('Pulse',42,42,16,16,C.white,8,0,false)
 elseif kind=='Blink' then
  part('Portal',20,10,60,80,bright,30);part('Center',34,24,32,52,C.ink,16,0,false)
 elseif kind=='Leap' or kind=='Pogo' then
  part('Launch',43,15,16,65,bright,8);part('Arrow1',27,15,17,37,bright,7,42);part('Arrow2',58,15,17,37,bright,7,-42)
 elseif kind=='Scare' then
  part('Ghost',18,17,65,69,bright,28);part('Eye1',33,37,10,17,C.ink,5,0,false);part('Eye2',59,37,10,17,C.ink,5,0,false)
 elseif kind=='Banana' then
  part('Banana',31,14,34,69,bright,18,-28);part('Stem',27,8,10,22,C.ink,5,-28,false)
 elseif kind=='Box' then
  part('Box',15,24,72,61,bright,13);part('Band',45,24,13,61,C.white,2,0,false)
 elseif kind=='Bubble' then
  part('Bubble1',15,21,47,47,bright,24);part('Bubble2',53,49,31,31,bright,16);part('Shine',27,28,10,10,C.white,5,0,false)
 elseif kind=='Decoy' or kind=='Disco' then
  part('TwinHead',15,23,20,20,bright,10);part('TwinBody',12,48,26,35,bright,10)
  part('Head',49,10,27,27,C.white,14);part('Body',44,43,38,45,bright,13)
 elseif kind=='Jester' then
  part('Hat',19,23,63,44,bright,16);part('HatLeft',18,7,21,33,bright,10,-24);part('HatRight',61,7,21,33,bright,10,24)
  part('BellLeft',13,2,18,18,C.white,9);part('BellRight',72,2,18,18,C.white,9);part('Brim',14,61,73,14,C.white,7)
 elseif kind=='GEMS' then
  part('Gem',27,26,48,48,C.cyan,6,45);part('Facet',33,25,17,43,C.white,3,45,false)
  part('Spark',72,11,12,12,C.white,3,45,false)
 elseif kind=='CRATES' or kind=='INVENTORY' then
  part('Chest',16,33,70,51,rgb(143,86,218),8);part('Lid',11,24,80,20,rgb(181,123,249),6)
  part('Band1',30,25,9,61,C.gold,3,0,false);part('Band2',63,25,9,61,C.gold,3,0,false)
  part('Latch',42,47,18,23,C.gold,3)
 elseif kind=='Bombs' then
  part('Fuse',53,7,11,35,rgb(244,198,100),4,-24);part('Spark',59,4,19,19,C.gold,3,45)
  part('BombBody',16,27,70,65,bright,32);part('BombShine',30,40,17,10,bright:Lerp(C.white,.8),6,-30,false)
  part('Band',18,62,66,12,bright:Lerp(C.ink,.5),4,0,false)
 elseif kind=='Emotes' then
  part('Head',39,6,24,24,bright,14);part('Body',38,36,26,31,bright,9)
  part('LeftArm',12,34,36,12,bright,6,-30);part('RightArm',59,28,36,12,bright,6,-45)
  part('LeftLeg',27,64,14,29,bright,6,23);part('RightLeg',58,64,14,29,bright,6,-23)
 elseif kind=='Titles' or kind=='INDEX' then
  part('Badge',15,24,70,51,bright,8);part('Ribbon',29,64,15,29,bright:Lerp(C.ink,.25),3,15);part('Ribbon2',57,64,15,29,bright:Lerp(C.ink,.25),3,-15)
  part('Star',38,31,26,26,C.gold,3,45);part('StarCenter',41,34,20,20,C.white,3,0,false)
 elseif kind=='SHOP' then
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
 o.BackgroundTransparency=0;rounded(o,24);edge(o,C.ink,2.5)
 local rim=gloss(o,panelTones[name]~=nil);rim.Color=accent or C.white:Lerp(o.BackgroundColor3,.35)
 return o,rim
end
local function button(parent,name,caption,callback,danger,bucket)
 local purchase=name:sub(1,5)=='Item_' or name:sub(1,6)=='Quest_'
 local tone=danger and tones.Close or purchase and rgb(25,227,48) or tones[name:sub(1,3)=='Nav' and name:sub(4) or name] or rgb(47,175,228)
 local b=make('TextButton',parent,{Name=name,Text=caption,TextTransparency=1,TextStrokeTransparency=1,TextTruncate=Enum.TextTruncate.AtEnd,Size=UDim2.fromOffset(120,44),BackgroundColor3=tone,TextColor3=C.white,Font=Enum.Font.GothamBlack,TextSize=16,AutoButtonColor=false,BorderSizePixel=0,ZIndex=(parent.ZIndex or 1)+3})
 rounded(b,18);edge(b,C.ink,2.5);local rim=gloss(b,true)
 local label=text(b,'ButtonCaption',caption,5,-2,110,44,16,C.white,Enum.TextXAlignment.Center);label.Size=UDim2.new(1,-10,1,0);label.ZIndex=b.ZIndex+6
 local function captionUpdate()
  label.Text=b.Text;label.TextColor3=b.TextColor3;label.TextSize=b.TextSize;label.TextTruncate=b.TextTruncate;label.TextXAlignment=b.TextXAlignment;label.Font=b.TextSize>=18 and Enum.Font.FredokaOne or Enum.Font.GothamBlack
  label:FindFirstChildOfClass('UIStroke').Thickness=b.TextSize>=18 and 1.5 or .65
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
end
 local function gem(parent,size)
  local host=frame(parent,'GemIllustration',0,0,size,size,C.cyan,(parent.ZIndex or 1)+4)
  host.BackgroundTransparency=1
  local k=size/100
  local jewel=frame(host,'Crystal',25*k,24*k,52*k,52*k,C.cyan,host.ZIndex)
  jewel.Rotation=45;rounded(jewel,6*k);edge(jewel,C.ink,math.max(2,4*k))
  local face=frame(jewel,'LightFacet',4*k,4*k,22*k,44*k,C.white,jewel.ZIndex+1)
  face.BackgroundTransparency=.43;rounded(face,3*k)
  local dark=frame(jewel,'DeepFacet',28*k,5*k,18*k,43*k,rgb(53,132,255),jewel.ZIndex+1)
  dark.BackgroundTransparency=.24;rounded(dark,3*k)
  local shine=frame(host,'Shine',65*k,8*k,9*k,9*k,C.white,host.ZIndex+2);shine.Rotation=45
  local small=frame(host,'SmallShine',15*k,71*k,6*k,6*k,C.white,host.ZIndex+2);small.Rotation=45
  return host
 end
 return {C=C,Tones=tones,PanelTones=panelTones,Text=text,Panel=panel,Button=button,Frame=frame,
  Rounded=rounded,Edge=edge,Gloss=gloss,Emblem=emblem,Gem=gem,Motion=motion,
  Destroy=function()
   for _,c in ipairs(links) do c:Disconnect() end;table.clear(links)
   for _,t in pairs(tweens) do t:Cancel() end;table.clear(tweens)
  end}
end
