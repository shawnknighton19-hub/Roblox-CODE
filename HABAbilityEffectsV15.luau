--!nonstrict
-- Small native geometry cues complement the action poses. No PNG billboards, camera shake, or physics.
local FX={Version=15}
local V,CF=Vector3.new,CFrame.new
local palettes={Shield=Color3.fromRGB(102,226,255),Leap=Color3.fromRGB(180,158,255),Speed=Color3.fromRGB(255,194,76),Decoy=Color3.fromRGB(255,149,213),Jester=Color3.fromRGB(255,211,96),Bubble=Color3.fromRGB(127,242,226),Pogo=Color3.fromRGB(186,157,255),Disco=Color3.fromRGB(255,133,217),Confetti=Color3.fromRGB(112,224,255)}
function FX.new(parent,player,touch)
 local self={Groups={},Parent=parent,Player=player,MaxGroups=touch and 4 or 6,MaxParts=touch and 108 or 164,Parts=0,Stopped=false}
 local function low() return player:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
 local function remove(g)
  for _,o in ipairs(g.Parts) do o:Destroy();self.Parts-=1 end
  table.clear(g.Parts)
 end
 local function group(kind,root,time,duration,color)
  if self.Stopped or low() or not root or not root.Parent then return nil end
  while #self.Groups>=self.MaxGroups do remove(table.remove(self.Groups,1)) end
  local g={Kind=kind,Root=root,At=time,Duration=duration,Color=color,Parts={},Items={},Frame=root.CFrame}
  self.Groups[#self.Groups+1]=g;return g
 end
 local function part(g,name,size,shape,color,alpha)
  if self.Parts>=self.MaxParts then return nil end
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.Shape=shape or Enum.PartType.Block;p.Color=color or g.Color
  p.Material=Enum.Material.Neon;p.Transparency=alpha or .25;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Massless=true
  p.CFrame=g.Frame;p.Parent=self.Parent;g.Parts[#g.Parts+1]=p;self.Parts+=1;return p
 end
 local function item(g,kind,index,p,extra)
  if p then local entry=extra or {};entry.Kind=kind;entry.Index=index;entry.Part=p;g.Items[#g.Items+1]=entry end
 end
 local function ring(g,count,radius,height,alpha)
  for i=1,count do item(g,'Ring',i,part(g,'AbilityRing',V(.07,.07,radius*.45),nil,nil,alpha),{Count=count,Radius=radius,Height=height}) end
 end
 local function cloneBody(g,offset,disco)
  local character=g.Root.Parent;local count=0
  for _,body in ipairs(character:GetChildren()) do
   if body:IsA('BasePart') and body.Name~='HumanoidRootPart' and body.Name~='ActiveBomb' and body.Transparency<.95 and count<16 and self.Parts<self.MaxParts then
    local ok,p=pcall(body.Clone,body)
    if not ok or not p then p=Instance.new('Part');p.Size=body.Size end
    for _,child in ipairs(p:GetChildren()) do if not child:IsA('SpecialMesh') then child:Destroy() end end
    p.Name='AbilityDecoyBody';p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Massless=true
    p.Material=Enum.Material.ForceField;p.Color=g.Color;p.Transparency=.47;p.LocalTransparencyModifier=0
    local frame=g.Frame*CF(offset,0,.9)*g.Root.CFrame:ToObjectSpace(body.CFrame)
    p.CFrame=frame;p.Parent=self.Parent;g.Parts[#g.Parts+1]=p;self.Parts+=1;count+=1
    item(g,'Decoy',count,p,{Frame=frame,Disco=disco,Side=offset})
   end
  end
 end
 function self:Ability(e,root)
  local kind=e.Ability;if not palettes[kind] then return end
  local length=.55
  if kind=='Shield' then length=math.min(1.2,tonumber(e.Duration) or 1)
  elseif kind=='Decoy' or kind=='Disco' or kind=='Jester' then length=math.min(2.4,tonumber(e.Duration) or 2.4)
  elseif kind=='Bubble' then length=1.1 end
  local g=group(kind,root,e.Time,length,palettes[kind]);if not g then return end
  if kind=='Shield' then
   local orb=part(g,'PhaseGuardShell',V(5.7,5.7,5.7),Enum.PartType.Ball,nil,.86)
   if orb then orb.Material=Enum.Material.ForceField;item(g,'Shield',1,orb) end
   ring(g,12,2.55,-1.9,.45)
  elseif kind=='Decoy' or kind=='Disco' then
   if kind=='Disco' then cloneBody(g,-2.45,true);cloneBody(g,2.45,true);ring(g,8,2.5,-2.65,.55)
   else cloneBody(g,0,false) end
  elseif kind=='Jester' then
   for i=1,3 do
    for axis=1,2 do item(g,'Star',i,part(g,'JesterStar',axis==1 and V(.62,.14,.12) or V(.14,.62,.12),nil,nil,.18),{Axis=axis}) end
   end
  elseif kind=='Bubble' then
   for i=1,8 do item(g,'Bubble',i,part(g,'SoapBubble',V(.32+(i%3)*.15,.32+(i%3)*.15,.32+(i%3)*.15),Enum.PartType.Ball,nil,.58)) end
  elseif kind=='Confetti' then
   for i=1,12 do item(g,'Confetti',i,part(g,'CannonConfetti',V(.14,.29,.055),nil,i%3==0 and Color3.fromRGB(255,220,104) or i%2==0 and Color3.fromRGB(255,145,207) or g.Color,.2)) end
  elseif kind=='Leap' or kind=='Pogo' then ring(g,12,1.25,-2.55,.3)
  elseif kind=='Speed' then
   for i=1,6 do item(g,'Speed',i,part(g,'OverdriveKick',V(.11,.11,.7),nil,nil,.3)) end
  end
 end
 function self:Swing(root,at,mirror)
  local g=group('Swing',root,at,.17,Color3.fromRGB(255,235,167));if not g then return end
  g.Mirror=mirror
  for i=1,5 do item(g,'Swing',i,part(g,'SwingGlint',V(.055,.055,.38),nil,nil,.32)) end
 end
 function self:Impact(kind,root,position,at)
  local g=group(kind,root,at,kind=='Block' and .32 or .24,kind=='Block' and palettes.Shield or Color3.fromRGB(255,225,129));if not g then return end
  g.Frame=CF(position)
  for i=1,kind=='Block' and 8 or 6 do item(g,'Impact',i,part(g,'ContactSpark',V(.07,.07,.3),nil,nil,.15),{Count=kind=='Block' and 8 or 6}) end
 end
 function self:Step(now)
  if self.Stopped then return end
  for index=#self.Groups,1,-1 do
   local g=self.Groups[index];local age=now-g.At;local h=g.Root.Parent and g.Root.Parent:FindFirstChildOfClass('Humanoid')
   local invalid=not g.Root.Parent or not h or h.Health<=0 or low()
   if not invalid and g.Kind=='Shield' then
    local charge=g.Root.Parent:GetAttribute('HABShieldCharge')
    if type(charge)=='number' and charge>0 then g.ShieldConfirmed=true
    elseif g.ShieldConfirmed or age>.2 then invalid=true end
   end
   if invalid or age>=g.Duration then remove(g);table.remove(self.Groups,index)
   else
    local u=math.clamp(age/g.Duration,0,1);local fade=math.clamp((u-.57)/.43,0,1);local t=math.max(age,0)
    for _,d in ipairs(g.Items) do
     local p=d.Part;local cf=g.Root.CFrame;local alpha=.3+fade*.7
     if d.Kind=='Decoy' then
      cf=d.Frame
      if d.Disco then cf=g.Frame*CF(d.Side,math.sin(t*9)*.055,.9)*CFrame.Angles(0,math.sin(t*6)*.035,0)*(g.Frame*CF(d.Side,0,.9)):ToObjectSpace(d.Frame) end
      alpha=.47+fade*.53
     elseif d.Kind=='Shield' then cf=g.Root.CFrame;alpha=.86+fade*.14
     elseif d.Kind=='Ring' then
      local launch=g.Kind=='Leap' or g.Kind=='Pogo';local radius=d.Radius+(launch and u*1.7 or math.sin(t*5)*.04)
      local theta=d.Index/d.Count*math.pi*2
      cf=(launch and g.Frame or g.Root.CFrame)*CF(math.cos(theta)*radius,d.Height,math.sin(theta)*radius)*CFrame.Angles(0,-theta,0)
      alpha=(launch and .25 or .5)+fade*(launch and .75 or .5)
     elseif d.Kind=='Star' then
      local theta=d.Index/3*math.pi*2+t*3
      cf=g.Root.CFrame*CF(math.cos(theta)*1.75,1.7+math.sin(theta*2)*.15,math.sin(theta)*1.75)*CFrame.Angles(0,-theta,t*1.8)
      alpha=.22+fade*.78
     elseif d.Kind=='Bubble' then
      local birth=(d.Index-1)*.065;local progress=math.clamp((t-birth)/.65,0,1)
      cf=g.Root.CFrame*CF(math.sin(d.Index*2.7)*(.3+progress),-.9+progress*1.6,1.1+progress*2.4)
      alpha=t<birth and 1 or .58+progress*.42
     elseif d.Kind=='Confetti' then
      local theta=d.Index*2.4;local speed=2.1+(d.Index%3)*.5
      cf=g.Frame*CF(math.cos(theta)*speed*t,1.3+(2.5+math.sin(theta))*t-3*t*t,-1.3-3*t)*CFrame.Angles(t*5,theta+t*4,t*7)
      alpha=.2+fade*.8
     elseif d.Kind=='Speed' then
      local side=d.Index%2==0 and 1 or -1
      cf=g.Root.CFrame*CF(side*(.6+u*.45),-1+(d.Index%3)*.35,1+u*2.5+(d.Index%3)*.4)*CFrame.Angles(.2,side*.2,0)
     elseif d.Kind=='Swing' then
      local side=g.Mirror and -1 or 1;local theta=-.95+(d.Index-1)*.24+u*.8
      cf=g.Root.CFrame*CF(math.sin(theta)*2.2*side,.4,-math.cos(theta)*2.2)*CFrame.Angles(0,-theta*side,0)
      alpha=.3+u*.7
     elseif d.Kind=='Impact' then
      local theta=d.Index/d.Count*math.pi*2;local radius=.3+u*1.2
      cf=g.Frame*CF(math.cos(theta)*radius,math.sin(theta)*radius,0)*CFrame.Angles(0,math.pi/2,theta)
      alpha=.15+u*.85
     end
     p.CFrame=cf;p.Transparency=math.clamp(alpha,0,1)
    end
   end
  end
 end
 function self:Destroy() if self.Stopped then return end;self.Stopped=true;for _,g in ipairs(self.Groups) do remove(g) end;table.clear(self.Groups) end
 return self
end
return FX
