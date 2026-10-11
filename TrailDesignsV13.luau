--!nonstrict
-- Twenty-five pooled, local-only trail sculptures. No assets, emitters, physics,
-- timers or per-frame Instances. The stand previews use the same geometry.
local Builder={Version=13,MaxParts=18,Lifetime=.72,StopFade=.36}
local V,CF,A=Vector3.new,CFrame.new,CFrame.Angles
local RGB=Color3.fromRGB
local GOLD,WHITE,DARK=RGB(255,214,68),RGB(245,252,255),RGB(32,39,59)
local CYAN,GREEN,PINK=RGB(80,233,255),RGB(114,236,107),RGB(255,135,205)
local NEON,METAL,SMOOTH=Enum.Material.Neon,Enum.Material.Metal,Enum.Material.SmoothPlastic
local BALL,CYL=Enum.PartType.Ball,Enum.PartType.Cylinder
local definitions={
 default={color={125,244,255},motion='bob',gap=1.8},
 aqua={color={72,211,255},motion='roll',gap=1.65},
 sunset={color={255,161,74},motion='spin',gap=1.9},
 royal={color={172,116,255},motion='bob',gap=1.8},
 lime={color={157,255,85},motion='rise',gap=1.7},
 rose={color={255,117,180},motion='tumble',gap=1.9},
 trail_ice={color={179,242,255},motion='roll',gap=1.65},
 trail_smoke={color={170,185,202},motion='rise',gap=1.75},
 trail_coins={color={255,224,85},motion='spin',gap=1.7},
 trail_ocean={color={73,238,218},motion='wave',gap=1.8},
 trail_berry={color={189,72,220},motion='tumble',gap=1.75},
 trail_volt={color={255,242,68},motion='zap',gap=1.65},
 trail_petals={color={255,185,214},motion='flutter',gap=1.75},
 trail_cosmic={color={141,142,255},motion='orbit',gap=2},
 trail_lava={color={255,79,43},motion='tumble',gap=1.8},
 trail_ghost={color={207,244,229},motion='float',gap=1.8},
 trail_neon={color={53,255,170},motion='circuit',gap=1.7},
 trail_party={color={255,132,222},motion='tumble',gap=1.85},
 trail_halo={color={255,224,125},motion='halo',gap=2.4,groups=2},
 trail_blizzard={color={195,235,255},motion='flutter',gap=1.75},
 trail_comet={color={93,203,255},motion='comet',gap=1.85},
 trail_eclipse={color={175,108,255},motion='orbit',gap=2},
 trail_overload={color={255,90,89},motion='zap',gap=1.8},
 trail_supernova={color={255,155,95},motion='spin',gap=2},
 trail_celebrate={color={255,223,71},motion='bob',gap=2},
}
Builder.Ids={}
for id in pairs(definitions) do table.insert(Builder.Ids,id) end
table.sort(Builder.Ids)

local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function finiteVector(v)
 return typeof(v)=='Vector3' and finite(v.X) and finite(v.Y) and finite(v.Z)
end
local function sculpt(model,id,color,index)
 local parts={}
 local function part(name,pos,size,tint,shape,material,rotation,alpha)
  local p=Instance.new(shape=='Wedge' and 'WedgePart' or 'Part')
  p.Name=name..'_'..index
  if p:IsA('Part') then p.Shape=shape or Enum.PartType.Block end
  p.Size=size;p.Color=tint or color;p.Material=material or SMOOTH
  p.Anchored=true;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
  p.Reflectance=material==METAL and .12 or 0;p.Transparency=1
  p.CFrame=CF(pos)*(rotation or CFrame.identity);p.Parent=model
  table.insert(parts,{object=p,localCF=p.CFrame,alpha=alpha or .08,size=size})
  return p
 end
 local function ball(name,pos,size,tint,material,alpha)
  return part(name,pos,type(size)=='number' and V(size,size,size) or size,tint,BALL,material,nil,alpha)
 end
 local function rod(name,a,b,width,tint,material)
  local delta=b-a
  local up=math.abs(delta.Unit:Dot(Vector3.yAxis))>.98 and Vector3.xAxis or Vector3.yAxis
  return part(name,(a+b)/2,V(width,width,delta.Magnitude),tint,nil,material or NEON,CFrame.lookAt(Vector3.zero,delta,up))
 end
 local function disk(name,pos,diameter,thickness,tint,rotation,material,alpha)
  return part(name,pos,V(thickness,diameter,diameter),tint,CYL,material or METAL,rotation or A(0,math.pi/2,0),alpha)
 end
 local function leaf(name,pos,tint,rotation)
  return part(name,pos,V(.36,.11,.2),tint or GREEN,BALL,SMOOTH,rotation)
 end

 if id=='default' then
  ball('LittleBomb',V(0,.05,0),.56,DARK,METAL)
  rod('BurningFuse',V(0,.3,0),V(.13,.53,0),.055,GOLD)
  ball('FuseSpark',V(.14,.54,0),.14,color,NEON)
  part('SpeedDash',V(0,-.25,.23),V(.09,.06,.68),WHITE,nil,NEON,A(.15,0,.1))
 elseif id=='aqua' then
  part('IceArrowLeft',V(-.2,0,0),V(.36,.56,.14),color,'Wedge',NEON,A(0,0,-.65))
  part('IceArrowRight',V(.2,0,0),V(.36,.56,.14),WHITE,'Wedge',SMOOTH,A(0,math.pi,.65))
  part('FrozenArrowTip',V(0,.4,0),V(.19,.4,.17),WHITE,'Wedge',NEON)
  rod('WindUnderline',V(-.43,-.27,0),V(.43,-.27,0),.055,color)
  part('ColdSlipstream',V(0,-.36,.35),V(.045,.045,.85),WHITE,nil,NEON)
 elseif id=='sunset' then
  ball('SunHeart',Vector3.zero,.4,GOLD,NEON)
  for n=0,3 do local t=n*math.pi/2
   part('SolarFlare',V(math.cos(t)*.33,math.sin(t)*.33,0),V(.09,.43,.23),n%2==0 and color or PINK,'Wedge',NEON,A(0,0,t-.65)*A(0,math.pi/2,0))
  end
 elseif id=='royal' then
  part('CrownBand',V(0,-.2,0),V(.78,.19,.15),GOLD,nil,METAL)
  for n=-1,1 do part('CrownPoint',V(n*.26,.11-math.abs(n)*.07,0),V(.15,.58-math.abs(n)*.08,.23),GOLD,'Wedge',METAL,A(0,0,n*.17)*A(0,math.pi/2,0)) end
  ball('CrownAmethyst',V(0,-.18,.105),.18,color,NEON)
 elseif id=='lime' then
  ball('AcidBubble',Vector3.zero,.64,color,SMOOTH,.55)
  ball('BubbleShine',V(-.13,.16,.26),V(.14,.22,.045),WHITE,NEON,.2)
  ball('PoisonCore',V(0,-.08,0),.28,RGB(63,109,39),NEON,.32)
  ball('RisingDrop',V(.4,.26,-.06),.23,color,NEON,.25)
  ball('SmallDrop',V(-.3,-.32,.03),.16,GREEN,SMOOTH,.3)
 elseif id=='rose' then
  ball('WrappedSweet',Vector3.zero,V(.52,.37,.37),color,SMOOTH)
  for _,side in ipairs({-1,1}) do part('CandyTwist',V(side*.39,0,0),V(.22,.38,.24),WHITE,'Wedge',SMOOTH,A(.15,0,side*math.pi/2)*A(0,math.pi/2,0)) end
  for _,x in ipairs({-.09,.09}) do part('SugarStripe',V(x,0,.175),V(.08,.3,.035),CYAN,nil,NEON,A(0,0,-.25)) end
 elseif id=='trail_ice' then
  for n=0,3 do local angle=(n-1.5)*.47
   part('CrystalSplinter',V(math.sin(angle)*.29,-math.abs(n-1.5)*.08,0),V(.19,.75-math.abs(n-1.5)*.2,.19),n%2==0 and WHITE or color,'Wedge',SMOOTH,A(.15,n*.6,-angle),.17)
  end
  ball('IceChip',V(.34,.42,.13),.11,WHITE,NEON)
 elseif id=='trail_smoke' then
  for n=0,3 do
   ball('BillowingPuff',V((n%2-.5)*.31,n*.21-.25,(n%3-1)*.12),.52+n*.09,n%2==0 and color or WHITE,SMOOTH,.76)
  end
 elseif id=='trail_coins' then
  disk('GoldCoin',Vector3.zero,.72,.1,GOLD)
  disk('CoinInset',V(0,0,.06),.53,.02,RGB(231,159,36))
  ball('StampedBomb',V(0,-.035,.09),V(.27,.27,.025),WHITE,METAL)
  rod('StampedFuse',V(.02,.08,.09),V(.12,.22,.09),.035,WHITE,METAL)
  part('CoinGlint',V(-.32,.34,0),V(.06,.22,.045),WHITE,nil,NEON,A(0,0,-.6))
 elseif id=='trail_ocean' then
  part('BreakingWave',V(0,-.08,0),V(.85,.48,.22),color,'Wedge',SMOOTH,A(0,0,-.12),.14)
  ball('WaveCrest',V(.14,.19,0),V(.65,.16,.25),WHITE,SMOOTH,.18)
  ball('SeaSpray',V(.47,.36,.02),.16,WHITE,NEON,.15)
  part('WaterRibbon',V(-.24,-.27,.25),V(.47,.06,.75),RGB(44,147,204),nil,NEON,A(0,.28,0),.35)
 elseif id=='trail_berry' then
  for n=0,2 do local t=n*math.pi*2/3
   ball('BerryFruit',V(math.cos(t)*.19,math.sin(t)*.19,0),.35,n%2==0 and color or RGB(105,58,182),SMOOTH)
  end
  leaf('BerryLeafLeft',V(-.13,.37,0),GREEN,A(0,0,-.35))
  leaf('BerryLeafRight',V(.13,.38,0),RGB(159,249,113),A(0,0,.4))
 elseif id=='trail_volt' then
  local points={V(-.58,.25,0),V(-.23,.16,0),V(-.34,-.09,0),V(.12,.08,0),V(.01,-.25,0),V(.55,-.12,0)}
  for n=1,5 do rod('LightningSegment',points[n],points[n+1],n==3 and .095 or .07,n%2==0 and WHITE or color) end
 elseif id=='trail_petals' then
  for n=0,4 do local t=n*math.pi*.4
   part('BlossomPetal',V(math.sin(t)*.24,math.cos(t)*.24,0),V(.25,.39,.12),n%2==0 and color or WHITE,BALL,SMOOTH,A(0,0,-t),.17)
  end
  ball('BlossomCenter',V(0,0,.1),.2,GOLD,NEON)
 elseif id=='trail_cosmic' then
  part('StarlightVertical',V(-.16,.04,0),V(.065,.72,.06),WHITE,nil,NEON,A(0,0,.2))
  part('StarlightHorizontal',V(-.16,.04,0),V(.56,.065,.06),color,nil,NEON,A(0,0,.2))
  ball('LittlePlanet',V(.35,-.22,.02),.31,RGB(234,141,200),SMOOTH)
  part('PlanetRing',V(.35,-.22,.02),V(.51,.035,.13),GOLD,nil,NEON,A(.3,0,-.35))
  ball('DistantStar',V(.37,.35,.03),.1,WHITE,NEON)
 elseif id=='trail_lava' then
  ball('MoltenHeart',Vector3.zero,.48,color,NEON)
  part('ObsidianCrust',V(-.14,-.02,.13),V(.38,.46,.19),DARK,'Wedge',SMOOTH,A(.2,.35,-.35))
  part('MoltenCrack',V(.13,0,.24),V(.055,.47,.05),GOLD,nil,NEON,A(0,0,.45))
  part('FallingCinder',V(.38,.38,-.08),V(.11,.27,.1),GOLD,'Wedge',NEON,A(0,0,-.2))
  ball('CoolingEmber',V(-.33,-.31,.04),.12,color,NEON)
 elseif id=='trail_ghost' then
  ball('GhostBody',V(0,.1,0),V(.54,.61,.24),color,SMOOTH,.35)
  part('GhostTail',V(.06,-.26,0),V(.19,.4,.4),WHITE,'Wedge',SMOOTH,A(0,0,.4)*A(0,math.pi/2,0),.42)
  for _,x in ipairs({-.11,.11}) do ball('GhostEye',V(x,.17,.13),V(.075,.13,.035),DARK,SMOOTH,.07) end
 elseif id=='trail_neon' then
  rod('CircuitTraceA',V(-.58,-.15,0),V(-.17,-.15,0),.055,color)
  rod('CircuitTraceB',V(-.17,-.15,0),V(-.17,.23,0),.055,color)
  rod('CircuitTraceC',V(-.17,.23,0),V(.48,.23,0),.055,color)
  for _,p in ipairs({V(-.58,-.15,0),V(.48,.23,0)}) do disk('CircuitTerminal',p,.16,.045,WHITE,nil,NEON) end
  part('CircuitChip',V(-.17,.04,0),V(.18,.22,.09),DARK,nil,METAL)
 elseif id=='trail_party' then
  ball('PartyBomb',Vector3.zero,.43,DARK,SMOOTH)
  rod('PartyFuse',V(0,.21,0),V(.1,.38,0),.04,GOLD)
  part('PinkStreamer',V(-.31,.09,0),V(.09,.42,.04),PINK,nil,NEON,A(0,0,-.48))
  part('BlueStreamer',V(.33,.17,.04),V(.09,.33,.04),CYAN,nil,NEON,A(0,0,.5))
  part('GoldConfetti',V(-.02,-.38,.03),V(.19,.13,.035),GOLD,nil,METAL,A(0,0,.8))
 elseif id=='trail_halo' then
  for n=0,7 do local t=(n+.5)*math.pi/4
   part('HaloArc',V(math.sin(t)*.52,math.cos(t)*.52,0),V(.405,.075,.075),GOLD,nil,NEON,A(0,0,-t),.18)
  end
  ball('HaloGleam',V(-.38,.38,.03),.18,WHITE,NEON)
 elseif id=='trail_blizzard' then
  for n=0,2 do local t=n*math.pi/3
   part('SnowflakeSpoke',Vector3.zero,V(.065,.91,.06),WHITE,nil,NEON,A(0,0,t))
   part('IceCrystalTip',V(math.sin(t)*.4,math.cos(t)*.4,0),V(.13,.22,.085),color,'Wedge',SMOOTH,A(0,0,-t))
  end
 elseif id=='trail_comet' then
  ball('CometHead',V(0,.12,0),.39,WHITE,NEON)
  for _,side in ipairs({-1,1}) do part('CometStream',V(side*.1,-.4,.03),V(.11,.99,.23),side==1 and color or RGB(114,157,255),'Wedge',NEON,A(0,0,-side*.16)*A(0,side*math.pi/2,0),.24) end
  ball('OrbitingFragment',V(.32,-.37,.09),.13,CYAN,NEON)
  part('TailSpark',V(-.3,-.67,0),V(.06,.29,.05),WHITE,nil,NEON,A(0,0,-.25))
 elseif id=='trail_eclipse' then
  disk('EclipseCorona',Vector3.zero,.79,.07,color,nil,NEON,.14)
  disk('EclipsingMoon',V(-.13,.075,.05),.65,.055,DARK,nil,SMOOTH,.03)
  part('DuskStar',V(.47,.34,0),V(.055,.22,.035),GOLD,nil,NEON,A(0,0,-.4))
  part('DuskGlimmer',V(-.39,-.36,0),V(.16,.045,.035),WHITE,nil,NEON,A(0,0,.4))
 elseif id=='trail_overload' then
  part('CapacitorCore',Vector3.zero,V(.27,.52,.21),DARK,nil,METAL)
  for _,y in ipairs({-.3,.3}) do part('PowerTerminal',V(0,y,0),V(.4,.105,.25),WHITE,nil,METAL) end
  rod('ArcingBoltA',V(-.51,.3,0),V(-.21,.04,.16),.075,color)
  rod('ArcingBoltB',V(-.21,.04,.16),V(.2,.15,.16),.08,WHITE)
  rod('ArcingBoltC',V(.2,.15,.16),V(.5,-.3,0),.075,color)
 elseif id=='trail_supernova' then
  for n=0,2 do part('NovaRay',Vector3.zero,V(.09,1.06-n*.08,.085),n%2==0 and color or PINK,nil,NEON,A(0,0,n*math.pi/3),.17) end
  ball('StarHeart',V(0,0,.08),.3,WHITE,NEON)
  for _,side in ipairs({-1,1}) do part('NovaFragment',V(side*.47,side*.33,.05),V(.19,.33,.11),GOLD,'Wedge',NEON,A(.2,0,side*.55)) end
 elseif id=='trail_celebrate' then
  ball('TrophyCup',V(0,.15,0),V(.49,.42,.23),GOLD,METAL)
  part('TrophyStem',V(0,-.16,0),V(.1,.28,.1),GOLD,nil,METAL)
  part('TrophyBase',V(0,-.32,0),V(.46,.09,.22),DARK,nil,METAL)
  for _,side in ipairs({-1,1}) do
   part('VictoryHandle',V(side*.3,.14,0),V(.19,.25,.09),WHITE,'Wedge',METAL,A(0,side==1 and 0 or math.pi,side*.2))
  end
  ball('VictoryMedal',V(0,.16,.14),.15,WHITE,NEON)
 end
 return parts
end

local Handle={};Handle.__index=Handle
function Handle:SetEnabled(enabled)
 if self.destroyed then return end
 enabled=enabled==true
 if self.enabled==enabled then return end
 self.enabled=enabled
 if enabled then
  table.clear(self.history);self.lastPosition=nil;self.lastTime=nil;self.stoppedAt=nil
  for _,group in ipairs(self.groups) do for _,p in ipairs(group) do p.object.Transparency=1 end end
 else self.stoppedAt=self.lastTime
 end
end
function Handle:Destroy()
 if self.destroyed then return end
 self.destroyed=true;self.enabled=false;self.Model:Destroy()
 table.clear(self.history);table.clear(self.groups)
end
local function motion(kind,phase,index,preview)
 local slow=preview and 0 or phase
 local side=math.sin(slow*2+index*1.3)
 if kind=='bob' then return CF(.15*side,.12*math.sin(slow*3+index),0)*A(0,.15*side,.12*side)
 elseif kind=='roll' then return CF(.17*side,.05*side,0)*A(0,.25*side,.3*side)
 elseif kind=='spin' then return A(.12*side,0,slow*1.6+index*.4)
 elseif kind=='rise' then return CF(.15*side,.15*index+.18*math.sin(slow+index),0)*A(0,0,.1*side)
 elseif kind=='tumble' then return A(slow*.8+index*.12,slow*.6,slow*1.2+index*.25)
 elseif kind=='wave' then return CF(.18*side,.14*math.sin(slow*3+index),0)*A(0,.15*side,.12*side)
 elseif kind=='zap' then return CF(.07*math.sin(slow*9+index),.05*math.cos(slow*11+index),0)*A(0,0,.12*side)
 elseif kind=='flutter' then return CF(.24*side,.16*math.cos(slow*2+index),0)*A(.35*side,.42*math.cos(slow+index),slow*.5)
 elseif kind=='orbit' then return CF(.21*side,.18*math.cos(slow*2+index),0)*A(0,.24*side,.2*side)
 elseif kind=='float' then return CF(.15*side,.22*math.sin(slow*2+index),0)*A(0,.2*side,.09*side)
 elseif kind=='circuit' then return CF(.08*side,0,0)*A(0,0,.08*side)
 elseif kind=='halo' then return A(.22*math.sin(slow+index),.25*math.cos(slow+index),slow*.4)
 elseif kind=='comet' then return CF(.1*side,0,0)*A(-.2,0,.14*side)
 end
 return CFrame.identity
end
local function sample(history,distance)
 local remaining=distance
 for n=1,#history-1 do
  local a,b=history[n],history[n+1];local segment=(a.position-b.position).Magnitude
  if segment>0 and remaining<=segment then
   local t=remaining/segment;local direction=a.direction:Lerp(b.direction,t)
   if direction.Magnitude<.01 then direction=a.direction end
   return a.position:Lerp(b.position,t),direction.Unit,a.time+(b.time-a.time)*t
  end
  remaining-=segment
 end
 return nil
end
function Handle:Step(rootCF,velocity,now,dt)
 if self.destroyed or (not self.enabled and #self.history==0) then return end
 if typeof(rootCF)~='CFrame' or not finiteVector(rootCF.Position) or not finiteVector(rootCF.LookVector) or not finiteVector(velocity) or not finite(now) or not finite(dt) then
  self.enabled=false;table.clear(self.history)
  for _,group in ipairs(self.groups) do for _,p in ipairs(group) do p.object.Transparency=1 end end
  return
 end
 local preview=self.preview
 local position=rootCF.Position+V(0,-1.65,0)
 local flat=V(velocity.X,0,velocity.Z)
 local direction=flat.Magnitude>.1 and flat.Unit or V(rootCF.LookVector.X,0,rootCF.LookVector.Z)
 if direction.Magnitude<.01 then direction=V(0,0,-1) else direction=direction.Unit end
 if not preview and self.enabled then
  if self.lastTime and (now<self.lastTime or now-self.lastTime>.4 or (position-self.lastPosition).Magnitude>16) then table.clear(self.history) end
  if #self.history==0 or (position-self.history[1].position).Magnitude>=.12 then
   table.insert(self.history,1,{position=position,direction=direction,time=now})
   while #self.history>64 do table.remove(self.history) end
  end
  while #self.history>1 and now-self.history[#self.history].time>1 do table.remove(self.history) end
  self.lastTime=now;self.lastPosition=position
 end
 for index,group in ipairs(self.groups) do
  local pos,dir,stamp
  if preview then
   pos=rootCF:PointToWorldSpace(V((index-(#self.groups+1)/2)*1.5,math.sin(index)*.18,math.sin(index*.9)*.32))
   dir=rootCF.LookVector;stamp=now
  else pos,dir,stamp=sample(self.history,.55+(index-1)*self.definition.gap) end
  local stopFade=self.stoppedAt and math.clamp((now-self.stoppedAt)/Builder.StopFade,0,1) or 0
  local visible=pos~=nil and stopFade<1 and (preview or now-stamp<Builder.Lifetime)
  if visible then
   local face=preview and rootCF.Rotation or CFrame.lookAt(Vector3.zero,dir)
   local base=CF(pos)*face*motion(self.definition.motion,now,index,preview)
   local fade=preview and 0 or math.max(stopFade,math.clamp((now-stamp-.16)/(Builder.Lifetime-.16),0,1))
   for _,p in ipairs(group) do
    p.object.CFrame=base*p.localCF
    p.object.Transparency=p.alpha+(1-p.alpha)*fade
   end
  else for _,p in ipairs(group) do p.object.Transparency=1 end end
 end
end

function Builder.Create(parent,item,options)
 local id=type(item)=='table' and item.id or item
 local definition=definitions[id]
 if not definition or (type(item)=='table' and item.category~='Trails') then return nil end
 if typeof(parent)~='Instance' then return nil end
 local preview=type(options)=='table' and options.Preview==true
 local model=Instance.new('Model');model.Name='HussTrail_'..id;model.Parent=parent
 model:SetAttribute('HussTrailId',id);model:SetAttribute('HussTrailDesignVersion',13);model:SetAttribute('Preview',preview)
 local color=RGB(table.unpack(definition.color))
 local handle=setmetatable({Model=model,PartCount=0,id=id,preview=preview,enabled=false,destroyed=false,definition=definition,groups={},history={}},Handle)
 for index=1,definition.groups or 3 do
  local parts=sculpt(model,id,color,index);table.insert(handle.groups,parts);handle.PartCount+=#parts
 end
 assert(handle.PartCount>0 and handle.PartCount<=Builder.MaxParts,'Trail sculpture exceeds its bounded pool')
 model:SetAttribute('PartCount',handle.PartCount)
 return handle
end
function Builder.Preview(parent,item)
 local handle=Builder.Create(parent,item,{Preview=true});if not handle then return nil end
 handle:SetEnabled(true);handle:Step(CFrame.identity,Vector3.zero,2,1/60)
 return handle.Model
end
return Builder
