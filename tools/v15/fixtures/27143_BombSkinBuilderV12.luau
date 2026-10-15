--!nonstrict
-- Shared, deterministic bomb sculptures for the carrier and the stand's 3D preview.
-- All extras are welded cosmetic geometry. The gameplay collision sphere is unchanged.
local Builder={}
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles
local RGB=Color3.fromRGB
local BALL,CYL=Enum.PartType.Ball,Enum.PartType.Cylinder
local METAL,NEON,GLASS=Enum.Material.Metal,Enum.Material.Neon,Enum.Material.Glass
local DARK,WHITE,GOLD=RGB(25,29,40),RGB(255,245,211),RGB(255,203,49)
local GREEN=RGB(79,165,65)

function Builder.Apply(bomb,skin,options)
 if not bomb or not bomb:IsA('BasePart') or type(skin)~='table' or skin.category~='Bombs' then return nil end
 local preview=type(options)=='table' and options.Preview==true
 local old=bomb:FindFirstChild('HussBombSkin');if old then old:Destroy() end
 local folder=Instance.new('Folder');folder.Name='HussBombSkin';folder.Parent=bomb
 local color=RGB(table.unpack(skin.color));local id=skin.visualBase or skin.id
 bomb.Color=color;bomb.Material=METAL;bomb.Reflectance=.16;bomb.Transparency=0
 bomb.CanCollide=false;bomb.CanTouch=false;bomb.CanQuery=false;bomb.Massless=true
 if preview then bomb.Anchored=true end
 if bomb:IsA('Part') then bomb.Shape=BALL end
 bomb:SetAttribute('HussBombId',skin.id);bomb:SetAttribute('HussBombSculptureVersion',12)
 local count=0
 local function part(name,pos,size,tint,shape,material,rotation,transparency)
  local p=Instance.new(shape=='Wedge' and 'WedgePart' or 'Part')
  p.Name=name;if p:IsA('Part') then p.Shape=shape or Enum.PartType.Block end
  p.Size=size;p.Color=tint or color;p.Material=material or METAL;p.Reflectance=p.Material==METAL and .12 or 0
  p.Transparency=transparency or 0;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Anchored=preview
  p.CFrame=bomb.CFrame*CF(pos)*(rotation or CFrame.identity);p.Parent=folder
  if not preview then local w=Instance.new('WeldConstraint');w.Name='CosmeticWeld';w.Part0=bomb;w.Part1=p;w.Parent=p end
  count+=1;return p
 end
 local function ball(name,pos,size,tint,material,rotation,transparency)
  return part(name,pos,type(size)=='number' and V(size,size,size) or size,tint,BALL,material,rotation,transparency)
 end
 -- Roblox cylinders use their X axis for length. The default disk lies in XZ.
 local function disk(name,pos,diameter,thickness,tint,rotation,material)
  return part(name,pos,V(thickness,diameter,diameter),tint,CYL,material,rotation or A(0,0,math.pi/2))
 end
 local function rod(name,a,b,width,tint,material)
  local delta=b-a;local up=math.abs(delta.Unit:Dot(Vector3.yAxis))>.98 and Vector3.xAxis or Vector3.yAxis
  return part(name,(a+b)/2,V(width,width,delta.Magnitude),tint,nil,material,CF():ToObjectSpace(CFrame.lookAt(Vector3.zero,delta,up)))
 end
 local function leaf(name,pos,size,tint,rotation)
  return ball(name,pos,size,tint or GREEN,METAL,rotation or A(0,0,.4))
 end
 local function ring(name,tint,radius,rotation,center,segments,width,material)
  local axis=rotation or CFrame.identity;center=center or Vector3.zero;segments=segments or 10;width=width or .12
  local chord=2*radius*math.sin(math.pi/segments)*1.06
  for n=0,segments-1 do local a=(n+.5)*math.pi*2/segments
   local offset=axis:VectorToWorldSpace(V(math.cos(a)*radius,0,math.sin(a)*radius))
   part(name..tostring(n+1),center+offset,V(width,width,chord),tint,nil,material or METAL,axis*A(0,-a,0))
  end
 end
 local function star(name,pos,size,tint,material)
  disk(name..'Center',pos,size*.55,.09,tint,A(0,math.pi/2,0),material)
  for n=0,4 do local a=n*math.pi*.4
   part(name..'Point'..n,pos+V(math.sin(a)*size*.25,math.cos(a)*size*.25,0),V(size*.22,size*.5,.1),tint,'Wedge',material,A(0,0,-a))
  end
 end
 local function particles(name,host,tint,rate,kind)
  if preview then return end
  local at=Instance.new('Attachment');at.Name=name..'Origin';at.Parent=host
  local emitter=Instance.new('ParticleEmitter');emitter.Name=name
  emitter.Texture=kind=='smoke' and 'rbxasset://textures/particles/smoke_main.dds' or 'rbxasset://textures/particles/sparkles_main.dds'
  emitter.Color=ColorSequence.new(tint,tint:Lerp(WHITE,.55));emitter.Rate=rate;emitter.Lifetime=NumberRange.new(.28,.6)
  emitter.Speed=NumberRange.new(.3,1.25);emitter.SpreadAngle=Vector2.new(35,35);emitter.EmissionDirection=Enum.NormalId.Top
  emitter.Acceleration=V(0,.7,0);emitter.Drag=2;emitter.LightEmission=kind=='smoke' and .25 or .65;emitter.LightInfluence=.4
  emitter.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,kind=='smoke' and .2 or .09),NumberSequenceKeypoint.new(.3,kind=='smoke' and .35 or .14),NumberSequenceKeypoint.new(1,0)})
  emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(.7,.55),NumberSequenceKeypoint.new(1,1)})
  emitter.Rotation=NumberRange.new(0,360);emitter.RotSpeed=NumberRange.new(-45,45);emitter.LockedToPart=false;emitter.Parent=at
 end
 local function glow(host,tint)
  if preview then return end
  local light=Instance.new('PointLight');light.Name='SkinGlow';light.Color=tint;light.Range=4;light.Brightness=.35;light.Shadows=false;light.Parent=host
 end

 -- Every sculpture keeps a round, readable bomb body and the same unmistakable fuse.
 disk('FuseCollar',V(0,1.08,0),.48,.24,DARK)
 rod('FuseLower',V(0,1.16,0),V(.08,1.46,0),.13,GOLD)
 rod('FuseCurl',V(.08,1.46,0),V(.27,1.62,0),.12,WHITE)
 local tip=ball('FuseSpark',V(.29,1.65,0),.19,WHITE,NEON)
 particles('FuseSparks',tip,GOLD,3,'spark')

 if id=='bomb_classic' then
  disk('CopperEquator',V(0,-.08,0),2.265,.12,RGB(167,108,63))
  for _,x in ipairs({-.48,0,.48}) do ball('CopperRivet',V(x,.25,1.02-math.abs(x)*.13),.13,GOLD) end
  part('FoundryPlate',V(0,-.4,1.025),V(.74,.33,.1),DARK)
  part('FoundryStripe',V(0,-.4,1.09),V(.45,.065,.04),RGB(188,201,213))
 elseif id=='bomb_cherry' then
  bomb.Material=Enum.Material.SmoothPlastic;bomb.Reflectance=.24
  rod('CherryStem',V(-.25,.95,0),V(-.48,1.42,0),.1,RGB(98,72,42))
  leaf('CherryLeaf',V(-.76,1.32,0),V(.76,.12,.37),GREEN,A(0,.1,-.35))
  local fruit=ball('CherryCompanion',V(.95,.54,.22),.64,RGB(182,27,50))
  rod('CompanionStem',V(.94,.77,.22),V(.67,1.21,.02),.07,GREEN)
  ball('CherryShine',V(-.4,.5,.9),V(.18,.38,.06),WHITE,Enum.Material.SmoothPlastic,A(0,0,-.3))
  ball('CompanionShine',V(1.03,.67,.5),.1,WHITE)
 elseif id=='bomb_cobalt' then
  disk('TurbineHousing',V(0,0,1.02),1.46,.22,DARK,A(0,math.pi/2,0))
  disk('TurbineCore',V(0,0,1.17),.53,.08,RGB(150,239,255),A(0,math.pi/2,0),NEON)
  for n=0,6 do local a=n*math.pi*2/7
   part('TurbineBlade',V(math.sin(a)*.45,math.cos(a)*.45,1.15),V(.18,.44,.1),RGB(168,199,228),nil,METAL,A(0,0,-a+.38))
  end
  for _,s in ipairs({-1,1}) do
   part('CobaltSideArmor',V(s*.91,.1,0),V(.3,1.35,.75),color,nil,METAL,A(0,0,-s*.25))
   rod('CoolingPipe',V(s*.82,-.6,.49),V(s*.72,.77,.49),.14,WHITE)
  end
  glow(tip,color)
 elseif id=='bomb_mint' then
  disk('PeppermintRim',V(0,0,1.035),1.65,.15,WHITE,A(0,math.pi/2,0))
  disk('MintFace',V(0,0,1.13),1.44,.08,RGB(52,197,146),A(0,math.pi/2,0))
  for n=0,5 do local a=n*math.pi/3
   leaf('PeppermintSwirl',V(math.sin(a)*.37,math.cos(a)*.37,1.19),V(.28,.73,.07),WHITE,A(0,0,-a+.36))
  end
  ball('MintCenter',V(0,0,1.24),.22,WHITE)
  leaf('MintLeafLeft',V(-.7,.89,.1),V(.74,.13,.33),GREEN,A(0,.2,-.35))
  leaf('MintLeafRight',V(-.33,1,.16),V(.48,.1,.26),RGB(122,205,72),A(0,.2,.5))
 elseif id=='bomb_taxi' then
  part('TaxiWindscreen',V(0,.3,1.02),V(1.15,.46,.15),RGB(32,71,92),nil,GLASS)
  part('WindowDivider',V(0,.3,1.115),V(.07,.47,.04),DARK)
  for _,s in ipairs({-1,1}) do
   ball('Headlight',V(s*.51,-.17,1.03),V(.31,.24,.13),WHITE,NEON)
   for _,z in ipairs({-.47,.47}) do
    disk('TaxiTire',V(s*1.01,-.54,z),.64,.3,DARK,CFrame.identity)
    disk('TaxiWheelHub',V(s*1.19,-.54,z),.33,.05,RGB(199,213,220),CFrame.identity)
   end
  end
  part('TaxiBumper',V(0,-.56,.96),V(1.31,.15,.19),DARK)
  part('TaxiRoofSign',V(-.4,1.02,0),V(.66,.36,.38),WHITE)
  for n=0,3 do part('TaxiChecker',V(-.49+n*.325,-.02,1.12),V(.15,.13,.04),n%2==0 and DARK or WHITE) end
  part('TaxiSignStripe',V(-.4,1.03,.205),V(.48,.1,.025),DARK)
 elseif id=='bomb_candy' then
  bomb.Material=Enum.Material.SmoothPlastic
  for _,s in ipairs({-1,1}) do
   part('CandyWrapper',V(s*1.25,0,0),V(.58,.94,.67),WHITE,'Wedge',Enum.Material.SmoothPlastic,A(.4,0,s*math.pi/2))
   disk('WrapperKnot',V(s*1.05,0,0),.59,.17,RGB(244,70,143),CFrame.identity)
  end
  disk('SugarRibbon',Vector3.zero,2.29,.2,WHITE,A(.18,0,.55))
  for n=0,4 do local a=n*math.pi*.4
   part('CandySprinkle',V(math.sin(a)*.61,math.cos(a)*.61,1.01),V(.12,.25,.07),n%2==0 and RGB(93,234,249) or GOLD,nil,Enum.Material.SmoothPlastic,A(0,0,a))
  end
 elseif id=='bomb_orange' then
  bomb.Material=Enum.Material.SmoothPlastic
  disk('CitrusPith',V(0,0,1.015),1.68,.15,WHITE,A(0,math.pi/2,0))
  disk('CitrusFlesh',V(0,0,1.11),1.45,.08,RGB(255,177,37),A(0,math.pi/2,0))
  for n=0,7 do local a=n*math.pi/4
   rod('CitrusSegment',V(0,0,1.17),V(math.sin(a)*.7,math.cos(a)*.7,1.17),.045,WHITE)
  end
  ball('CitrusHeart',V(0,0,1.19),.16,WHITE)
  leaf('OrangeLeaf',V(-.47,1.08,0),V(.78,.12,.37),GREEN,A(0,0,-.28))
  rod('PeelCurlUpper',V(-.88,.56,.1),V(-1.25,.15,.2),.17,color)
  rod('PeelCurlLower',V(-1.25,.15,.2),V(-1.04,-.32,.24),.17,color)
 elseif id=='bomb_arctic' then
  bomb.Material=GLASS;bomb.Transparency=.24
  ball('FrozenHeart',Vector3.zero,1.67,RGB(114,212,244),NEON)
  for n=0,4 do local a=n*math.pi*2/5
   part('IceCrownShard',V(math.sin(a)*.87,.64,math.cos(a)*.87),V(.33,.96,.32),WHITE,'Wedge',GLASS,A(.15,a,.2),.18)
  end
  for _,s in ipairs({-1,1}) do
   part('HangingIcicle',V(s*.51,-.92,.47),V(.23,.71,.3),RGB(190,246,255),'Wedge',GLASS,A(0,0,math.pi),.16)
  end
  star('Snowflake',V(0,.05,1.08),.75,WHITE,NEON)
  particles('IceCrystals',tip,RGB(160,240,255),3,'spark')
 elseif id=='bomb_ember' then
  bomb.Color=RGB(47,37,36);bomb.Material=Enum.Material.Slate;bomb.Reflectance=0
  local points={V(-.7,.62,.68),V(-.32,.34,1.02),V(-.1,-.07,1.14),V(.42,-.23,1.05),V(.63,-.72,.66)}
  for n=1,#points-1 do rod('MoltenCrack',points[n],points[n+1],.11,RGB(255,133,28),NEON) end
  rod('CrackFork',points[2],V(.2,.74,.82),.08,GOLD,NEON)
  rod('CrackFork',points[3],V(-.63,-.39,.88),.075,color,NEON)
  for n=0,4 do local a=n*math.pi*2/5
   part('ObsidianShellShard',V(math.sin(a)*.94,.04,math.cos(a)*.94),V(.52,.77,.22),RGB(63,49,46),'Wedge',Enum.Material.Slate,A(.08,a,.18))
  end
  ball('ExposedEmber',V(.7,.41,.74),V(.28,.5,.1),color,NEON,A(0,.7,-.4))
  particles('EscapingEmbers',tip,color,5,'spark');glow(tip,color)
 elseif id=='bomb_toxic' then
  bomb.Material=GLASS;bomb.Transparency=.22
  ball('AcidReservoir',V(0,-.18,0),V(1.75,1.55,1.75),RGB(146,255,51),NEON)
  disk('TankBase',V(0,-.84,0),1.75,.25,DARK);disk('TankLid',V(0,.81,0),1.8,.24,DARK)
  for _,s in ipairs({-1,1}) do
   part('TankRail',V(s*.92,0,-.22),V(.16,1.6,.17),RGB(173,192,117))
   rod('PressureHose',V(s*.93,.55,-.2),V(s*1.2,.27,-.05),.17,DARK)
   rod('PressureHose',V(s*1.2,.27,-.05),V(s*1.13,-.4,.2),.17,DARK)
  end
  disk('WarningBadge',V(0,.05,1.045),.88,.12,GOLD,A(0,math.pi/2,0))
  for n=0,2 do local a=n*math.pi*2/3
   part('RadiationBlade',V(math.sin(a)*.23,.05+math.cos(a)*.23,1.125),V(.22,.3,.035),DARK,'Wedge',METAL,A(0,0,-a))
  end
  ball('RadiationDot',V(0,.05,1.15),.13,DARK)
  particles('ToxicVapor',tip,color,3,'smoke')
 elseif id=='bomb_royal' then
  bomb.Material=Enum.Material.SmoothPlastic
  disk('CrownBand',V(0,.78,0),1.95,.22,GOLD)
  for n=0,4 do local a=n*math.pi*2/5
   part('CrownPoint',V(math.sin(a)*.79,1.075,math.cos(a)*.79),V(.33,.67,.2),GOLD,'Wedge',METAL,A(0,a,0))
   ball('CrownJewel',V(math.sin(a)*.88,.8,math.cos(a)*.88),.2,n%2==0 and RGB(246,74,131) or RGB(91,224,255),GLASS)
  end
  part('RoyalSash',V(0,-.17,.98),V(1.65,.2,.11),GOLD,nil,METAL,A(0,0,-.4))
  part('RoyalCrest',V(0,.08,1.12),V(.39,.51,.16),RGB(253,84,134),nil,GLASS,A(0,0,math.pi/4))
 elseif id=='bomb_disco' then
  bomb.Reflectance=.3
  for row=-1,1 do local radius=row==0 and 1.05 or .91
   for n=0,5 do local a=n*math.pi/3+row*.15
    part('MirrorTile',V(math.sin(a)*radius,row*.5,math.cos(a)*radius),V(.56,.44,.09),Color3.fromHSV((n+row*2)%9/9,.34,1),nil,METAL,A(row*-.35,a,0))
   end
  end
  for _,s in ipairs({-1,1}) do
   disk('HeadphoneCushion',V(s*1.11,.17,0),.82,.19,DARK,CFrame.identity)
   disk('HeadphoneShell',V(s*1.25,.17,0),.64,.13,RGB(232,90,244),CFrame.identity,NEON)
   rod('HeadphoneBand',V(s*1.14,.47,0),V(s*.8,1.03,0),.12,DARK)
  end
  particles('DiscoGlints',tip,RGB(246,142,255),3,'spark')
 elseif id=='bomb_gift' then
  bomb.Material=Enum.Material.SmoothPlastic
  disk('RibbonVertical',Vector3.zero,2.29,.2,GOLD,CFrame.identity)
  disk('RibbonHorizontal',Vector3.zero,2.29,.21,GOLD)
  leaf('BowLoopLeft',V(-.37,1.04,.27),V(.8,.2,.42),WHITE,A(0,0,-.45))
  leaf('BowLoopRight',V(.37,1.04,.27),V(.8,.2,.42),WHITE,A(0,0,.45))
  ball('BowKnot',V(0,1.05,.34),.24,GOLD)
  rod('GiftTagString',V(.79,.56,.36),V(1.12,.11,.48),.045,WHITE)
  part('GiftTag',V(1.08,-.09,.54),V(.38,.53,.08),WHITE,nil,METAL,A(0,-.4,-.25))
  ball('GiftTagSeal',V(1.08,-.09,.61),.18,color)
 elseif id=='bomb_bee' then
  bomb.Material=Enum.Material.SmoothPlastic
  for _,y in ipairs({-.52,0,.52}) do disk('BeeStripe',V(0,y,0),y==0 and 2.27 or 2.01,.2,DARK) end
  for _,s in ipairs({-1,1}) do
   leaf('BeeWing',V(s*1.17,.46,-.14),V(1.05,.13,1.25),WHITE,A(0,s*.3,s*.48)).Transparency=.25
   rod('BeeAntenna',V(s*.35,.94,.25),V(s*.63,1.38,.26),.065,DARK)
   ball('AntennaTip',V(s*.63,1.38,.26),.16,DARK)
   ball('BeeEye',V(s*.32,.25,1.025),V(.19,.29,.09),DARK)
  end
  part('BeeStinger',V(0,-.28,-1.12),V(.38,.35,.54),DARK,'Wedge',METAL,A(math.pi/2,0,0))
 elseif id=='bomb_prism' then
  bomb.Material=GLASS;bomb.Transparency=.2
  ball('OpalHeart',Vector3.zero,1.45,RGB(185,227,255),NEON)
  local pastel={RGB(170,236,255),RGB(241,173,255),RGB(161,255,218),RGB(248,213,132),RGB(170,188,255),RGB(255,166,202)}
  for n=0,5 do local a=n*math.pi/3
   part('CrystalFacet',V(math.sin(a)*.99,0,math.cos(a)*.99),V(.65,1.5,.24),pastel[n+1],nil,GLASS,A(0,a,.24),.13)
   part('CrystalTooth',V(math.sin(a)*.72,-.86,math.cos(a)*.72),V(.35,.63,.28),pastel[n+1],'Wedge',GLASS,A(0,a,math.pi),.12)
  end
  particles('PrismaticGlints',tip,WHITE,3,'spark')
 elseif id=='bomb_saturn' then
  for _,y in ipairs({-.52,0,.52}) do disk('PlanetBand',V(0,y,0),y==0 and 2.27 or 2.01,.12,RGB(205,135,92)) end
  ring('SaturnRing',RGB(255,228,166),1.51,A(.38,0,-.28),Vector3.zero,12,.17)
  ball('SmallMoon',V(1.51,.82,.27),.43,RGB(195,221,249))
  ball('TinyMoon',V(-1.4,-.72,-.19),.24,WHITE)
 elseif id=='bomb_abyss' then
  bomb.Color=RGB(57,48,99);bomb.Material=GLASS;bomb.Transparency=.22
  ball('PearlHeart',Vector3.zero,1.5,color,NEON)
  for n=0,6 do local a=n*math.pi*2/7
   part('ClamShellFlute',V(math.sin(a)*.78,-.74,math.cos(a)*.78),V(.57,.7,.4),RGB(61,92,110),'Wedge',METAL,A(-.3,a,0))
   ball('PearlRim',V(math.sin(a)*.99,-.46,math.cos(a)*.99),.15,RGB(121,230,218),NEON)
  end
  for _,s in ipairs({-1,1}) do leaf('DeepSeaFin',V(s*1.01,.25,-.22),V(.65,.1,.82),RGB(85,125,151),A(.3,0,s*.6)) end
  particles('AbyssMist',tip,RGB(119,126,238),2,'smoke')
 elseif id=='bomb_spike' then
  bomb.Color=RGB(87,104,122);bomb.Reflectance=.3
  disk('IronSeam',Vector3.zero,2.28,.15,DARK)
  for n=0,7 do local a=n*math.pi/4
   part('UrchinSpike',V(math.sin(a)*1.05,.1,math.cos(a)*1.05),V(.4,.57,.68),RGB(169,188,201),'Wedge',METAL,A(math.pi/2,a,0))
  end
  for _,s in ipairs({-1,1}) do part('ShoulderSpike',V(s*.68,.88,0),V(.39,.72,.38),RGB(188,204,215),'Wedge',METAL,A(0,0,-s*.5)) end
  disk('IronFacePlate',V(0,.08,1.03),.75,.18,DARK,A(0,math.pi/2,0))
  part('IronBolt',V(0,.08,1.15),V(.38,.38,.12),WHITE,nil,METAL,A(0,0,math.pi/4))
 elseif id=='bomb_plasma' then
  bomb.Material=GLASS;bomb.Transparency=.38
  ball('PlasmaHeart',Vector3.zero,1.7,RGB(81,255,223),NEON)
  disk('ReactorUpperCap',V(0,.84,0),1.66,.23,DARK);disk('ReactorLowerCap',V(0,-.84,0),1.66,.23,DARK)
  for n=0,5 do local a=n*math.pi/3
   part('PlasmaCageRib',V(math.sin(a)*.94,0,math.cos(a)*.94),V(.14,1.68,.16),RGB(118,144,153),nil,METAL,A(0,a,0))
  end
  ring('PlasmaCoil',RGB(176,255,234),1.16,A(.4,0,0),Vector3.zero,10,.09,NEON)
  for _,s in ipairs({-1,1}) do
   disk('PowerTerminal',V(s*1.05,0,0),.53,.36,DARK,CFrame.identity)
   disk('TerminalLight',V(s*1.255,0,0),.32,.06,color,CFrame.identity,NEON)
  end
  glow(tip,color)
 elseif id=='bomb_sakura' then
  bomb.Material=Enum.Material.SmoothPlastic;bomb.Reflectance=.24
  rod('BlossomBranch',V(-.74,-.5,.73),V(.5,.7,.75),.08,RGB(101,63,62))
  rod('BlossomTwig',V(-.07,.14,1.08),V(-.61,.53,.89),.055,RGB(101,63,62))
  for index,center in ipairs({V(-.47,.32,1.04),V(.42,.57,.91),V(.1,-.35,1.08)}) do
   for n=0,4 do local a=n*math.pi*.4
    leaf('SakuraPetal'..index,center+V(math.sin(a)*.16,math.cos(a)*.16,0),V(.2,.3,.075),index==2 and WHITE or RGB(255,217,232),A(0,0,-a))
   end
   ball('BlossomCenter',center+V(0,0,.04),.13,GOLD)
  end
  leaf('SakuraLeaf',V(-.84,.64,.17),V(.63,.1,.28),RGB(133,187,104),A(0,.2,-.4))
  particles('FallingBlossomGlints',tip,RGB(255,180,212),2,'spark')
 elseif id=='bomb_gold' then
  bomb.Reflectance=.36
  disk('MintedCoinRim',V(0,0,1.03),1.31,.18,RGB(152,99,20),A(0,math.pi/2,0))
  disk('MintedCoinFace',V(0,0,1.145),1.12,.075,RGB(255,228,116),A(0,math.pi/2,0))
  star('GoldenSeal',V(0,0,1.205),.64,RGB(178,111,24),METAL)
  for _,s in ipairs({-1,1}) do for n=0,3 do
   leaf('GildedLaurel',V(s*(.7+.09*math.sin(n)),(n-1.5)*.32,.91),V(.18,.39,.09),RGB(255,236,140),A(0,0,s*(.45+n*.1)))
  end end
  particles('GoldDust',tip,GOLD,3,'spark')
 elseif id=='bomb_void' then
  bomb.Color=RGB(25,21,39);bomb.Reflectance=.05
  disk('VoidAperture',V(0,.04,1.02),1.25,.1,RGB(128,54,245),A(0,math.pi/2,0),NEON)
  star('VoidStarArmor',V(0,.04,1.105),1.56,RGB(51,36,78),METAL)
  ball('BlackHole',V(0,.04,1.205),V(.4,.4,.08),RGB(12,9,24),Enum.Material.SmoothPlastic)
  for n=0,3 do local a=n*math.pi/2+.45
   part('VoidArmorShard',V(math.sin(a)*1.035,.04,math.cos(a)*1.035),V(.5,.84,.36),RGB(67,45,108),'Wedge',METAL,A(0,a,.45))
  end
  particles('VoidWisp',tip,RGB(142,82,231),3,'smoke');glow(tip,RGB(125,57,213))
 elseif id=='bomb_solar' then
  bomb.Material=NEON;bomb.Color=RGB(255,157,29)
  for n=0,7 do local a=n*math.pi/4
   part('SolarHeatFin',V(math.sin(a)*1.08,.02,math.cos(a)*1.08),V(.23,1.02,.51),RGB(97,61,38),'Wedge',METAL,A(0,a,.21))
  end
  disk('FurnaceCrown',V(0,.84,0),1.62,.18,RGB(95,62,36));disk('FurnaceBase',V(0,-.86,0),1.55,.2,RGB(95,62,36))
  disk('FurnaceDoorRim',V(0,0,1.035),1.31,.16,RGB(90,55,32),A(0,math.pi/2,0))
  disk('FurnaceWindow',V(0,0,1.135),1.03,.07,RGB(255,229,80),A(0,math.pi/2,0),NEON)
  for _,y in ipairs({-.31,0,.31}) do part('FurnaceGrate',V(0,y,1.19),V(.94,.08,.06),RGB(97,61,38)) end
  particles('SolarEmbers',tip,RGB(255,167,54),5,'spark');glow(tip,GOLD)
 elseif id=='bomb_nova' then
  bomb.Material=GLASS;bomb.Transparency=.24
  ball('NovaCore',Vector3.zero,1.67,RGB(255,74,151),NEON)
  ring('NovaCyanOrbit',RGB(111,232,255),1.48,A(.66,0,-.38),Vector3.zero,10,.11,NEON)
  ring('NovaRoseOrbit',RGB(255,177,219),1.39,A(-.62,0,.51),Vector3.zero,10,.09,NEON)
  star('NovaBurst',V(0,.08,1.06),.89,WHITE,NEON)
  particles('StellarSparks',tip,RGB(255,190,236),4,'spark');glow(tip,RGB(234,96,183))
 elseif id=='bomb_champion' then
  bomb.Reflectance=.27
  for _,s in ipairs({-1,1}) do
   local points={V(s*.94,.57,0),V(s*1.42,.66,0),V(s*1.63,.28,0),V(s*1.54,-.2,0),V(s*1.13,-.43,0),V(s*.86,-.28,0)}
   for n=1,#points-1 do rod('TrophyHandle',points[n],points[n+1],.15,GOLD) end
   for n=0,2 do leaf('VictoryLaurel',V(s*(.68+n*.04),(n-1)*.32,.94),V(.18,.36,.09),RGB(255,242,171),A(0,0,s*.52)) end
  end
  disk('TrophyStem',V(0,-1.07,0),.36,.42,GOLD)
  part('TrophyPlinth',V(0,-1.34,0),V(1.06,.19,.9),DARK)
  part('WinnerPlaque',V(0,-1.33,.465),V(.58,.11,.025),GOLD)
  for n=-1,1 do part('VictoryRibbon',V(n*.13,-.04,1.1),V(.12,1.17,.06),n==0 and WHITE or n==-1 and RGB(239,74,89) or RGB(55,151,239)) end
  disk('ChampionMedal',V(0,-.25,1.15),.76,.12,GOLD,A(0,math.pi/2,0))
  star('ChampionStar',V(0,-.25,1.24),.43,WHITE,METAL)
  particles('ChampionGlints',tip,GOLD,3,'spark')
 end
 folder:SetAttribute('DetailPartCount',count);folder:SetAttribute('Preview',preview)

 if skin.bundleOnly then
  -- Guaranteed edition silhouette: separate from its standard base, not a gameplay hitbox.
  local tint=RGB(table.unpack(skin.color))
  ring('ExclusiveOrbit',tint,1.4,A(.65,0,.35),V(0,0,0),12,.085,NEON)
  star('BundleCrest',V(0,.1,1.28),.60,GOLD,NEON)
  for _,side in ipairs({-1,1}) do
   part('ExclusiveCrownFin',V(side*.78,.96,-.22),V(.16,.58,.32),tint,'Wedge',METAL,A(0,0,-side*.32))
  end
 end
 return folder
end
return Builder
-- HAB_EXPANSION_7
