--!nonstrict
-- HAB_UNIQUE_BOOST_2 | 25 independent cosmetic boost recipes.
-- NO WalkSpeed, velocity, input, cooldown, jump or swimming changes.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Catalog=require(RS:WaitForChild('HussCatalogV11'))
local me=Players.LocalPlayer
local V,CF=Vector3.new,CFrame
local WHITE=Color3.fromRGB(244,247,255)
local GOLD=Color3.fromRGB(255,216,97)
local rng=Random.new()
local MAX_SETS = Input.TouchEnabled and 3 or 5
local PART_BUDGET = Input.TouchEnabled and 400 or 850
local allocated = 0
local FAR = 110

local states,links,stopped={},{},false
local budgetClock,accum,frameAverage=0,0,1/60
local world=Instance.new('Folder');world.Name='HABUniqueBoostVFX';world.Parent=workspace
local TEXTURES={fire='rbxasset://textures/particles/fire_main.dds',smoke='rbxasset://textures/particles/smoke_main.dds',spark='rbxasset://textures/particles/sparkles_main.dds'}
local actions={DiveForward=true,DiveBack=true,DiveLeft=true,DiveRight=true,DiveForwardLeft=true,DiveForwardRight=true,DiveBackLeft=true,DiveBackRight=true}
local function make(class,parent,props)
 local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o
end
local function link(signal,fn,bucket)
 local c=signal:Connect(fn);local list=bucket or links;list[#list+1]=c;return c
end
local function clearLinks(list) for _,c in ipairs(list) do c:Disconnect() end;table.clear(list) end
local function reduced() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function takePart(f)
 local p=table.remove(f.free)
 if p then return p end
 if allocated>=PART_BUDGET or #f.parts>=f.limit then return nil end
 p=make('Part',f.folder,{Name='CosmeticBoostGeometry',Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,
  TopSurface=Enum.SurfaceType.Smooth,BottomSurface=Enum.SurfaceType.Smooth,Size=V(.1,.1,.1),Transparency=1})
 f.parts[#f.parts+1]=p;allocated=allocated+1
 return p
end
local function recycle(g)
 for _,a in ipairs(g.atoms) do a.p.Transparency=1;g.f.free[#g.f.free+1]=a.p end
end
local function clearParticles(f)
 for _,e in ipairs(f.emitters) do e.Enabled=false;e.Rate=0;e:Clear() end
 for _,g in ipairs(f.groups) do recycle(g) end
 table.clear(f.groups)
end
local function destroyFx(s)
 local f=s.fx;if not f then return end
 for _,a in ipairs(f.attachments) do a:Destroy() end
 if f.folder then f.folder:Destroy() end
 allocated=math.max(0,allocated-#f.parts);s.fx=nil
end
local function destroyCharacter(s)
    clearLinks(s.charLinks)
    destroyFx(s)

    s.c=nil
    s.h=nil
    s.r=nil
    s.ground=nil
    s.previous=nil
    s.pending=false
    s.dodgeUntil=0
    s.weaveSerial=0
    s.motionUntil=0
    s.lastWeave=nil
end

local function blocked(s)
 local id=s.p:GetAttribute('HABPackTrail')
 if type(id)=='string' and id~='' then return true end
    local c,h,r=s.c,s.h,s.r

    if not c or not c.Parent
        or not h or not h.Parent
        or not r or not r.Parent then
        return true
    end

    local state=h:GetState()

    return h.Health<=0
        or r.Anchored
        or h.Sit
        or h.PlatformStand
        or c:GetAttribute('Ragdolled')==true
        or c:GetAttribute('IsRagdoll')==true
        or s.p:GetAttribute('HussGamePaused')==true
        or workspace:GetAttribute('HussGamePaused')==true
        or state==Enum.HumanoidStateType.Physics
        or state==Enum.HumanoidStateType.Ragdoll
        or state==Enum.HumanoidStateType.Seated
        or state==Enum.HumanoidStateType.Swimming
end

local function beginDodge(s,age)
    if age<-.15 or age>=.72 or blocked(s) then
        return
    end

    local now=os.clock()

    if s.lastWeave and now-s.lastWeave<.1 then
        return
    end

    s.lastWeave=now
    s.dodgeUntil=now+.72-math.max(0,age)
    s.pending=age<.3
    s.weaveSerial=(s.weaveSerial or 0)+1

    budgetClock=0
end

local function bind(s,c)
 s.generation=s.generation+1;local token=s.generation;destroyCharacter(s)
 task.spawn(function()
  local h=c:WaitForChild('Humanoid',12);local r=c:WaitForChild('HumanoidRootPart',12)
  if stopped or states[s.p]~=s or token~=s.generation or s.p.Character~=c or not h or not r then return end
  s.c,s.h,s.r=c,h,r
  s.ray=RaycastParams.new();s.ray.FilterType=Enum.RaycastFilterType.Exclude
  s.ray.FilterDescendantsInstances={c,world};s.ray.IgnoreWater=true;s.ray.RespectCanCollide=true;s.ray.CollisionGroup=r.CollisionGroup
  s.groundAt=0;s.usedAt=0;s.dodgeUntil=0
  link(h.Died,function() destroyFx(s) end,s.charLinks)
  if s.p==me then link(c:GetAttributeChangedSignal('MovementActionId'),function()
   local action=c:GetAttribute('MovementAction')
   if actions[action] then beginDodge(s,0) elseif action=='DiveEnd' then s.dodgeUntil=0 end
  end,s.charLinks) end
 end)
end
local function addPlayer(p)
 if states[p] then return end
 local s={p=p,links={},charLinks={},generation=0,allowed=false,pending=false,dodgeUntil=0};states[p]=s
 link(p.CharacterAdded,function(c) bind(s,c) end,s.links)
 link(p.CharacterRemoving,function() s.generation=s.generation+1;destroyCharacter(s) end,s.links)
 if p.Character then bind(s,p.Character) end
end
local function removePlayer(p)
 local s=states[p];if not s then return end
 s.generation=s.generation+1;destroyCharacter(s);clearLinks(s.links);states[p]=nil
end
local function selected(s)
 local i=Catalog.ById[s.p:GetAttribute('HussTrailId')]
 if not i or i.category~='Trails' then i=Catalog.ById[Catalog.Defaults.Trails] end
 return i
end
local function grounded(s,now)
    if now<(s.groundAt or 0) then
        return s.ground
    end

    s.groundAt=now+.08

    local r,h,c=s.r,s.h,s.c
    local leg=c:FindFirstChild('Left Leg')

    local height=math.clamp(
        h.HipHeight+r.Size.Y*.5+(leg and leg.Size.Y or 0),
        1.6,
        12
    )

    local foot=c:FindFirstChild('LeftFoot') or leg or r
    s.ray.CollisionGroup=foot.CollisionGroup

    local hit

    for _,offset in ipairs({
        V(0,0,0),
        V(.7,0,0),
        V(-.7,0,0)
    }) do
        local result=workspace:Raycast(
            r.Position+V(0,.5,0)+offset,
            V(0,-height-2,0),
            s.ray
        )

        if result and result.Normal.Y>.35 then
            hit=result
            break
        end
    end

    if not hit and h.FloorMaterial~=Enum.Material.Air then
        hit={
            Position=r.Position-V(0,height,0),
            Normal=V(0,1,0)
        }
    end

    s.ground=hit
    return hit
end

local Recipes={}
local function nozzle(f,name,texture,rate,size,life,speed,color,offset,spread,alpha,accel)
 local a=make('Attachment',f.root,{Name='HABUnique_'..name})
 local e=make('ParticleEmitter',a,{
  Name=name,Texture=TEXTURES[texture],Enabled=false,Rate=0,EmissionDirection=Enum.NormalId.Front,
  Lifetime=NumberRange.new(life*.7,life),Speed=NumberRange.new(speed*.7,speed),SpreadAngle=Vector2.new(spread,spread),
  Color=ColorSequence.new(color,color:Lerp(WHITE,.12)),LightEmission=texture=='smoke' and .15 or .8,
  LightInfluence=texture=='smoke' and .4 or 0,Drag=1.4,Acceleration=accel or V(0,0,0),
  LockedToPart=false,VelocityInheritance=0,Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(-35,35),
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*.25),NumberSequenceKeypoint.new(.4,size),NumberSequenceKeypoint.new(1,size*.4)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,alpha),NumberSequenceKeypoint.new(.4,alpha+.08),NumberSequenceKeypoint.new(1,1)}),
 })
 f.attachments[#f.attachments+1]=a;f.emitters[#f.emitters+1]=e
 local n={a=a,e=e,rate=rate,offset=offset or V(0,0,0)};f.nozzles[#f.nozzles+1]=n
 return n
end
local function group(f,frame,life,velocity,gravity,spin,scale,flicker)
    local follow=f.followPart

    local g={
        f=f,
        frame=frame,
        life=life,
        age=0,
        velocity=velocity or V(0,0,0),
        gravity=gravity or V(0,0,0),
        spin=spin or V(0,0,0),
        scale=scale,
        atoms={},
        flicker=flicker,
        effectSize=f.spawnSize or 1,
        follow=follow,
        localFrame=follow and follow.CFrame:ToObjectSpace(frame)
    }

    if follow then
        g.velocity=g.velocity*.12
        g.gravity=g.gravity*.12
    end

    f.groups[#f.groups+1]=g
    return g
end

local function atom(g,shape,cf,size,color,alpha,mat,endColor)
    local p=takePart(g.f)
    if not p then return end

    local s=g.effectSize

    p.Shape=shape or Enum.PartType.Block
    p.Material=mat or Enum.Material.Neon
    p.Color=color

    p.Size=V(
        math.max(.01,size.X*s),
        math.max(.01,size.Y*s),
        math.max(.01,size.Z*s)
    )

    p.CFrame=g.frame*CF.new(cf.Position*s)*cf.Rotation
    p.Transparency=alpha or 0

    g.atoms[#g.atoms+1]={
        p=p,
        cf=cf,
        size=size,
        color=color,
        alpha=alpha or 0,
        endColor=endColor
    }
end

local function block(g,cf,size,c,a,mat,endColor) atom(g,Enum.PartType.Block,cf,size,c,a,mat,endColor) end
local function orb(g,cf,size,c,a,mat,endColor) atom(g,Enum.PartType.Ball,cf,size,c,a,mat,endColor) end
local function rod(g,a,b,width,c,alpha,mat)
 if (b-a).Magnitude<.01 then return end
 local up=math.abs((b-a).Unit.Y)>.98 and V(1,0,0) or V(0,1,0)
 block(g,CF.lookAt((a+b)/2,b,up),V(width,width,(b-a).Magnitude),c,alpha,mat)
end
local function ring(g,center,radius,width,c,n,tilt,alpha)
 n=n or 10;tilt=tilt or CF.identity
 for i=0,n-1 do
  local a,b=i*2*math.pi/n,(i+1)*2*math.pi/n
  local pa=(center*tilt):PointToWorldSpace(V(math.cos(a)*radius,math.sin(a)*radius,0))
  local pb=(center*tilt):PointToWorldSpace(V(math.cos(b)*radius,math.sin(b)*radius,0))
  rod(g,pa,pb,width,c,alpha or .12)
 end
end
local function shard(g,cf,length,width,c,alpha)
 -- Tapered crystal made from three decreasing prisms, not a plain cube.
 for j=0,2 do
  block(g,cf*CF.new(0,0,-j*length*.25),V(width*(1-j*.3),width*(1-j*.3),length*.45),c,alpha or .1)
 end
end
local function crown(g,c)
 ring(g,CF.new(),.42,.1,GOLD,8,CF.Angles(math.pi/2,0,0),.06)
 for j=0,4 do
  local a=j*math.pi*2/5;local x,z=math.cos(a)*.42,math.sin(a)*.42
  block(g,CF.new(x,.22,z),V(.14,.5,.14),GOLD,.08)
  orb(g,CF.new(x,.5,z),V(.18,.18,.18),c,.02)
 end
end
local function snowflake(g,size,c)
 for j=0,5 do
  local a=j*math.pi/3;local dir=V(math.cos(a),math.sin(a),0)
  rod(g,V(0,0,0),dir*size,.065,c,.07)
  for _,side in ipairs({-1,1}) do
   local turn=V(math.cos(a+side*.75),math.sin(a+side*.75),0)
   rod(g,dir*size*.57,dir*size*.57+turn*size*.28,.05,c,.1)
  end
 end
end
local function bloom(g,c)
 for j=0,4 do
  local a=j*math.pi*2/5
  orb(g,CF.new(math.cos(a)*.3,math.sin(a)*.3,0)*CF.Angles(0,0,a),V(.48,.23,.09),c,.13,Enum.Material.SmoothPlastic)
 end
 orb(g,CF.new(0,0,.04),V(.18,.18,.12),GOLD,.08)
end
local function sample(f,frame,life,speed,spin,gravity,scale)
 return group(f,frame,life,frame.LookVector*(speed or 0),gravity,spin,scale)
end
local function add(id,interval,build,emit)
 assert(not Recipes[id],'Duplicate effect: '..id)
 Recipes[id]={interval=interval,build=build,emit=emit}
end
local function none() end

-- 01 Classic: tightly focused paired turbine jets, mechanical diamond exhaust.
add('default',.14,function(f)
 for _,side in ipairs({-1,1}) do
  nozzle(f,'ClassicTwinJet','fire',35,.46,.23,22,f.color,V(side*.6,0,0),4,.12)
 end
end,function(f,cf,b)
 local g=sample(f,cf,.36,11,V(0,0,3),nil,function(t) return 1-t*.5 end)
 for _,side in ipairs({-1,1}) do
  block(g,CF.new(side*.6,0,-.9)*CF.Angles(0,0,math.pi/4),V(.35,.35,.16),WHITE,.12)
 end
end)

-- 02 Arctic Rush: two counter-rotating frost turbines shed curved blade fans.
add('aqua',.20,function(f)
 nozzle(f,'ColdBreath','smoke',16,.55,.4,10,Color3.fromRGB(182,237,255),V(0,.05,-.3),8,.7,V(0,.6,0))
end,function(f,cf,b)
 for _,side in ipairs({-1,1}) do
  local g=sample(f,cf*CF.new(side*.65,0,-.8),.48,7,V(0,0,side*8),nil,function(t) return .7+t*.5 end)
  for j=0,3 do
   local a=j*math.pi/2
   block(g,CF.Angles(0,0,a)*CF.new(.28,0,0)*CF.Angles(0,0,.55),V(.47,.11,.09),f.color,.15,Enum.Material.Glass)
  end
 end
end)

-- 03 Solar Rush: rolling orange fire tongues, rising ember balls; no icy rings.
add('sunset',.13,function(f)
 nozzle(f,'SolarFlame','fire',38,1.18,.55,15,f.color,V(0,.12,0),14,.22,V(0,3,0))
 nozzle(f,'HotEmbers','spark',18,.12,.6,22,GOLD,V(0,.1,0),32,.12,V(0,2,0))
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(rng:NextNumber(-.6,.6),.15,-1),.42,9,V(2,3,0),V(0,3,0),function(t) return 1-t*.75 end)
 orb(g,CF.new(),V(.34,.42,.7),GOLD,.12)
 orb(g,CF.new(0,0,.1),V(.24,.26,.32),WHITE,.08)
end)

-- 04 Royal Rush: recognizable little jeweled crowns and tumbling diamonds.
add('royal',.26,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.15,-1.1),.74,5,V(.2,3.7,.3),V(0,1.1,0))
 crown(g,f.color)
 block(g,CF.new(-.7,.1,0)*CF.Angles(.6,.6,.6),V(.23,.23,.23),f.color,.06)
end)

-- 05 Toxic Rush: wobbling transparent gas bubbles with smaller nested bubbles.
add('lime',.17,function(f)
 nozzle(f,'AcidVapor','smoke',13,.72,.62,5,f.color,V(0,0,-.3),20,.82,V(0,2,0))
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(rng:NextNumber(-.55,.55),0,-.9),.78,4,V(0,1,0),V(0,2,0),function(t) return .45+1.3*t end)
 orb(g,CF.new(),V(.62,.62,.62),f.color,.55,Enum.Material.Glass)
 orb(g,CF.new(.27,.15,.04),V(.29,.29,.29),f.color:Lerp(WHITE,.3),.38,Enum.Material.Glass)
 orb(g,CF.new(-.1,.12,-.28),V(.13,.13,.13),WHITE,.25)
end)

-- 06 Candy Rush: rolling striped peppermints and soft cotton-candy wisps.
add('rose',.23,function(f)
 nozzle(f,'CandyFloss','smoke',12,.55,.42,6,Color3.fromRGB(255,201,231),V(0,.1,-.4),13,.76,V(0,1,0))
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(rng:NextNumber(-.5,.5),0,-1),.64,7,V(6,5,2),V(0,-1,0))
 atom(g,Enum.PartType.Cylinder,CF.Angles(0,0,math.pi/2),V(.17,.58,.58),WHITE,.12,Enum.Material.SmoothPlastic)
 for j=0,3 do block(g,CF.new(0,.095,0)*CF.Angles(0,j*math.pi/2+.3,0)*CF.new(.12,0,0),V(.3,.03,.09),f.color,.08,Enum.Material.SmoothPlastic) end
end)

-- 07 Ice Shards: sharp three-prism slivers spray in a low fan.
add('trail_ice',.15,none,function(f,cf,b)
 for j=-1,1 do
  local g=sample(f,cf*CF.Angles(0,j*.35,0)*CF.new(0,.1,-.8),.48,12,V(1,4,j*4),V(0,-5,0),function(t) return 1-t*.45 end)
  shard(g,CF.Angles(.25,j*.5,0),.8,.16,j==0 and WHITE or f.color,.15)
 end
end)

-- 08 Smoke Screen: a soft, non-glowing charcoal plume with rolling smoke lobes.
add('trail_smoke',.25,function(f)
 nozzle(f,'RollingSmoke','smoke',25,1.45,.72,5,f.color,V(0,.05,0),17,.8,V(0,1.9,0))
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(rng:NextNumber(-.35,.35),.1,-1),.85,3,V(.8,.5,1),V(0,1,0),function(t) return .3+1.4*t end)
 for j=0,2 do orb(g,CF.new(j*.22-.2,j*.18,0),V(.65,.6,.7),f.color:Lerp(Color3.new(.15,.18,.2),j*.18),.82,Enum.Material.SmoothPlastic) end
end)

-- 09 Coin Shower: actual spinning gold coins, with raised centers and gravity.
add('trail_coins',.17,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(rng:NextNumber(-.7,.7),.3,-.8),.68,8,V(6,8,1),V(0,-10,0))
 atom(g,Enum.PartType.Cylinder,CF.identity,V(.11,.52,.52),f.color,.05,Enum.Material.Metal)
 atom(g,Enum.PartType.Cylinder,CF.new(.064,0,0),V(.025,.34,.34),GOLD:Lerp(WHITE,.3),.07,Enum.Material.Neon)
end)

-- 10 Ocean Foam: two low breaking-wave crescents and sprays of white foam.
add('trail_ocean',.22,function(f)
 nozzle(f,'SaltSpray','spark',15,.16,.45,11,WHITE,V(0,-.1,0),35,.45,V(0,-3,0))
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,-.2,-1),.62,4,V(0,.35,0),nil,function(t) return .7+t*.6 end)
 for _,side in ipairs({-1,1}) do
  for j=0,4 do
   local a=j*.33
   local x=side*(.3+math.sin(a)*.65);local z=-math.cos(a)*.65
   orb(g,CF.new(x,.09+math.sin(a)*.15,z),V(.23,.19,.37),j>2 and WHITE or f.color,.28,Enum.Material.Glass)
  end
 end
end)

-- 11 Berry Blast: bouncy berry bunches with a green leaf, not a pulse recolor.
add('trail_berry',.26,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(rng:NextNumber(-.4,.4),.25,-.8),.65,6,V(2,6,2),V(0,-6,0))
 for _,p in ipairs({V(-.15,.1,0),V(.15,.1,0),V(0,-.16,0),V(0,.03,-.18)}) do orb(g,CF.new(p),V(.33,.33,.33),f.color,.12,Enum.Material.SmoothPlastic) end
 orb(g,CF.new(.1,.37,0)*CF.Angles(0,0,-.6),V(.29,.1,.14),Color3.fromRGB(92,230,83),.1,Enum.Material.SmoothPlastic)
end)

-- 12 Voltage: jittering forked electric discharges, brief enough to stay readable.
add('trail_volt',.15,none,function(f,cf,b)
 local g=group(f,cf,.23,V(0,0,0),nil,nil,nil,true)
 local last=V(0,.15,-.4);local points={last}
 for j=1,5 do
  local p=V(rng:NextNumber(-.7,.7),rng:NextNumber(-.05,.5),-.4-j*.43)
  rod(g,last,p,.065,f.color,.08);last=p;points[#points+1]=p
 end
 rod(g,points[3],points[3]+V(.65,.15,-.42),.045,WHITE,.2)
 rod(g,points[5],points[5]+V(-.6,.4,-.3),.045,f.color,.12)
end)

-- 13 Petal Parade: full five-petal blossoms peel off into slow fluttering petals.
add('trail_petals',.30,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.3,-1),.92,3,V(.4,1.2,1.7),V(0,.2,0))
 bloom(g,f.color)
 for _,side in ipairs({-1,1}) do
  local q=sample(f,cf*CF.new(side*.6,.2,-.7),.75,5,V(4,side*2,1),V(0,-1,0))
  orb(q,CF.identity,V(.37,.15,.08),f.color:Lerp(WHITE,.2),.15,Enum.Material.SmoothPlastic)
 end
end)

-- 14 Cosmic Dust: rotating constellations joined by dim starlight threads.
add('trail_cosmic',.32,function(f)
 nozzle(f,'Stardust','spark',12,.11,.75,4,f.color,V(0,.2,0),35,.45,V(0,.35,0))
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.4,-1.2),.88,3,V(0,0,1.5))
 local p={V(-.55,-.15,0),V(.1,.45,0),V(.62,-.05,0),V(.05,-.36,0)}
 for i,v in ipairs(p) do
  rod(g,v+V(-.1,0,0),v+V(.1,0,0),.065,WHITE,.1)
  rod(g,v+V(0,-.1,0),v+V(0,.1,0),.065,WHITE,.1)
  if i>1 then rod(g,p[i-1],v,.025,f.color,.5) end
 end
end)

-- 15 Lava Leak: obsidian fragments split by molten seams; no fire-jet base.
add('trail_lava',.21,function(f)
 nozzle(f,'CoolingCinders','spark',13,.12,.4,7,Color3.fromRGB(255,130,34),V(0,0,-.3),25,.3,V(0,-4,0))
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(rng:NextNumber(-.65,.65),.1,-.7),.66,7,V(4,3,1),V(0,-4,0),function(t) return 1-t*.35 end)
 block(g,CF.Angles(.3,.3,.2),V(.55,.38,.5),Color3.fromRGB(42,29,31),.1,Enum.Material.Slate)
 for j=-1,1 do rod(g,V(j*.16,-.2,.27),V(j*.08,.2,.27),.055,f.color,.06) end
end)

-- 16 Ghost Step: tiny spectral faces and fading boot-shaped echoes.
add('trail_ghost',.34,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.4,-1),.92,2,V(0,.7,0),V(0,1.3,0),function(t) return .7+t*.45 end)
 orb(g,CF.identity,V(.6,.75,.4),f.color,.66,Enum.Material.Glass)
 for _,side in ipairs({-1,1}) do orb(g,CF.new(side*.13,.1,.2),V(.1,.14,.05),Color3.fromRGB(51,83,94),.4,Enum.Material.SmoothPlastic) end
 for j=-1,1 do orb(g,CF.new(j*.17,-.41,0),V(.17,.36,.17),f.color,.72,Enum.Material.Glass) end
 local q=sample(f,cf*CF.new(f.count%2==0 and -.45 or .45,-.3,-.6),.6,0,nil,nil,function(t) return 1+t*.3 end)
 orb(q,CF.identity,V(.34,.09,.74),f.color,.6,Enum.Material.Glass)
end)

-- 17 Neon Circuit: flat right-angle circuit traces with square terminal nodes.
add('trail_neon',.22,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,-.4,-.8),.65,0)
 local side=f.count%2==0 and 1 or -1
 local p={V(0,0,0),V(0,0,-.7),V(side*.65,0,-.7),V(side*.65,0,-1.5)}
 for i=2,#p do rod(g,p[i-1],p[i],.08,f.color,.14) end
 for _,i in ipairs({1,4}) do block(g,CF.new(p[i]),V(.22,.1,.22),WHITE,.15) end
end)

-- 18 Party Fuse: sideways streamers and spinning confetti rectangles.
add('trail_party',.20,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.3,-.6),.72,6,V(1,4,2),V(0,-3,0))
 for j=1,7 do
  local c=Color3.fromHSV((f.count*.13+j*.13)%1,.8,1)
  block(g,CF.new(rng:NextNumber(-.85,.85),rng:NextNumber(0,.65),rng:NextNumber(-.5,.5))*CF.Angles(j,j*.4,0),V(.18,.04,.35),c,.15,Enum.Material.SmoothPlastic)
 end
 for _,side in ipairs({-1,1}) do
  local q=sample(f,cf*CF.new(side*.55,.15,-.7),.63,5,V(0,0,side*3),V(0,-1,0))
  local prev=V(0,0,0)
  for j=1,5 do local p=V(math.sin(j*1.1)*.25,j*.12,-j*.12);rod(q,prev,p,.06,f.color,.1);prev=p end
 end
end)

-- 19 Golden Halo: large, hollow gold rings expand away from the feet.
add('trail_halo',.28,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.15,-.8),.72,7,V(0,0,.7),nil,function(t) return .35+t*1.25 end)
 ring(g,CF.identity,.75,.09,GOLD,12,nil,.14)
 ring(g,CF.identity,.48,.045,WHITE,10,nil,.3)
end)

-- 20 Blizzard: six-armed snowflakes and sideways snow flurries.
add('trail_blizzard',.30,function(f)
 nozzle(f,'DrivenSnow','spark',23,.11,.8,10,WHITE,V(0,.2,0),50,.35,V(0,-.3,0))
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(rng:NextNumber(-.5,.5),.3,-1),.82,5,V(0,0,2.7),V(0,-.6,0))
 snowflake(g,.65,WHITE)
end)

-- 21 Comet Tail: one blue-white nucleus, one narrow long dust wake.
add('trail_comet',.17,function(f)
 nozzle(f,'CometPlasma','fire',25,.55,.32,26,f.color,V(0,.25,-.4),3,.25)
 nozzle(f,'CometDust','spark',30,.1,.55,32,WHITE,V(0,.25,-.4),6,.28)
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.25,-1),.37,18,V(0,0,0),nil,function(t) return 1-t*.65 end)
 orb(g,CF.identity,V(.4,.4,.65),WHITE,.07)
 for j=-1,1 do shard(g,CF.new(j*.13,0,-.35-j*.1),1.35,.1,f.color,.28) end
end)

-- 22 Eclipse Wake: a dark orb passes across a broken violet corona.
add('trail_eclipse',.36,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.25,-1),.88,3,V(0,1,1),nil,function(t) return .7+t*.35 end)
 orb(g,CF.identity,V(.75,.75,.45),Color3.fromRGB(22,15,39),.32,Enum.Material.SmoothPlastic)
 for j=0,7 do
  local a=.25+j*.58;local b=a+.4
  rod(g,V(math.cos(a)*.44,math.sin(a)*.44,-.07),V(math.cos(b)*.44,math.sin(b)*.44,-.07),.085,f.color,.16)
 end
end)

-- 23 Overload: scarlet reactor cages compress then blow outward into panels.
add('trail_overload',.32,function(f)
 nozzle(f,'ReactorFragments','spark',15,.16,.3,17,f.color,V(0,.1,0),23,.3)
end,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.2,-.8),.55,5,V(1,2,1),nil,function(t) return t<.32 and 1-t or .55+(t-.32)*2.5 end)
 orb(g,CF.identity,V(.24,.24,.24),WHITE,.16)
 for j=0,5 do
  local a=j*math.pi/3
  block(g,CF.Angles(0,0,a)*CF.new(.42,0,0),V(.16,.35,.4),f.color,.18)
 end
end)

-- 24 Supernova Wake: brief star cores bloom into radiating spokes, then vanish.
add('trail_supernova',.40,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.3,-1),.65,3,V(.4,.2,1.3),nil,function(t) return .18+t*1.7 end)
 orb(g,CF.identity,V(.22,.22,.22),WHITE,.1)
 for j=0,7 do
  local a=j*math.pi/4;local dir=V(math.cos(a),math.sin(a),0)
  rod(g,dir*.2,dir*(j%2==0 and .78 or .53),.085,j%2==0 and f.color or GOLD,.15)
 end
end)

-- 25 Victory Parade: little trophies, laurel sprigs and falling gold streamers.
add('trail_celebrate',.38,none,function(f,cf,b)
 local g=sample(f,cf*CF.new(0,.35,-.9),.85,4,V(0,2,0),V(0,-.6,0))
 orb(g,CF.new(0,.24,0),V(.55,.47,.45),GOLD,.08,Enum.Material.Metal)
 block(g,CF.new(0,-.1,0),V(.13,.35,.13),GOLD,.08)
 block(g,CF.new(0,-.3,0),V(.48,.09,.34),GOLD,.12,Enum.Material.Metal)
 for _,side in ipairs({-1,1}) do
  ring(g,CF.new(side*.3,.26,0),.18,.055,GOLD,6,nil,.16)
  for j=0,2 do
   orb(g,CF.new(side*(.48-j*.055),-.22+j*.16,0)*CF.Angles(0,0,side*.6),V(.1,.25,.07),f.color,.15,Enum.Material.Metal)
  end
 end
end)

local count=0
for _,item in ipairs(Catalog.Items) do
 if item.category=='Trails' then
  count=count+1
  if not Recipes[item.id] then warn('[HAB Unique Boost] New trail has no authored recipe: '..item.id) end
 end
end
--------------------------------------------------
-- INDIVIDUAL TRAIL SETTINGS
-- {body size, idle aura, emission cost, weave style}
--------------------------------------------------

local Looks={
    default={1.35,false,2,'wind'},
    aqua={1.45,true,8,'frost'},
    sunset={1.55,true,2,'fire'},
    royal={1.7,true,19,'gold'},
    lime={1.7,true,3,'mist'},
    rose={1.55,false,5,'petal'},

    trail_ice={1.65,false,9,'frost'},
    trail_smoke={1.6,true,3,'mist'},
    trail_coins={1.8,false,2,'gold'},
    trail_ocean={1.65,false,10,'wind'},
    trail_berry={1.75,false,5,'petal'},
    trail_volt={1.7,true,7,'electric'},
    trail_petals={1.7,false,8,'petal'},
    trail_cosmic={1.65,true,11,'star'},
    trail_lava={1.65,true,4,'fire'},
    trail_ghost={1.65,true,7,'mist'},
    trail_neon={1.65,true,5,'electric'},
    trail_party={1.65,false,17,'petal'},
    trail_halo={1.9,true,22,'gold'},
    trail_blizzard={1.6,true,18,'frost'},
    trail_comet={1.65,false,10,'star'},
    trail_eclipse={1.9,true,9,'star'},
    trail_overload={1.8,true,7,'electric'},
    trail_supernova={2,true,9,'star'},
    trail_celebrate={1.75,false,21,'gold'},
}

local function look(item)
    return Looks[item.id] or Looks.default
end

local function scaledSequence(sequence,multiplier)
    local keys={}

    for _,k in ipairs(sequence.Keypoints) do
        keys[#keys+1]=NumberSequenceKeypoint.new(
            k.Time,
            k.Value*multiplier,
            k.Envelope*multiplier
        )
    end

    return NumberSequence.new(keys)
end

local function room(f,cost)
    return #f.free+math.max(
        0,
        math.min(f.limit-#f.parts,PART_BUDGET-allocated)
    )>=cost
end

local function findHand(c,side)
    local p=
        c:FindFirstChild(side..'Hand')
        or c:FindFirstChild(side..' Arm')
        or c:FindFirstChild(side..'LowerArm')

    return p and p:IsA('BasePart') and p or nil
end

--------------------------------------------------
-- BUILD MATCHING FOOT AND ARM EFFECTS
--------------------------------------------------

local function createFx(s,item)
    local f={
        id=item.id,
        root=s.r,
        recipe=Recipes[item.id] or Recipes.default,
        look=look(item),

        attachments={},
        emitters={},
        nozzles={},
        parts={},
        free={},
        groups={},
        hands={},

        count=0,
        next=0,
        handAt=0,
        handIndex=0,
        weaveSeen=0,
        echoUntil=0,
        echoAt=0,

        limit=s.p==me
            and (Input.TouchEnabled and 210 or 400)
            or (Input.TouchEnabled and 65 or 100),

        color=Color3.fromRGB(table.unpack(item.color))
    }

    f.folder=make('Folder',world,{
        Name='Unique_'..s.p.UserId..'_'..item.id
    })

    s.fx=f
    f.recipe.build(f)

    for _,side in ipairs({'Left','Right'}) do
        local limb=findHand(s.c,side)

        if limb then
            local hand={
                part=limb,
                offset=V(0,-limb.Size.Y*.35,0),
                nozzles={}
            }

            f.hands[#f.hands+1]=hand

            local seen={}

            for _,n in ipairs(f.nozzles) do
                if not seen[n.e.Name] then
                    seen[n.e.Name]=true

                    local att=make('Attachment',limb,{
                        Name='HABArm_'..n.e.Name
                    })

                    local e=n.e:Clone()

                    e.Size=scaledSequence(
                        e.Size,
                        f.look[1]*.60
                    )

                    e.Speed=NumberRange.new(
                        e.Speed.Min*.65,
                        e.Speed.Max*.65
                    )

                    e.Enabled=false
                    e.Rate=0
                    e.Parent=att

                    hand.nozzles[#hand.nozzles+1]={
                        a=att,
                        e=e,
                        rate=n.rate*.6
                    }

                    f.attachments[#f.attachments+1]=att
                    f.emitters[#f.emitters+1]=e
                end
            end
        end
    end

    for _,n in ipairs(f.nozzles) do
        n.e.Size=scaledSequence(n.e.Size,f.look[1])
    end

    return f
end

--------------------------------------------------
-- ANIMATE AND RECYCLE COSMETIC GEOMETRY
--------------------------------------------------

local function animateGeometry(f,dt)
    for i=#f.groups,1,-1 do
        local g=f.groups[i]
        g.age=g.age+dt

        if g.age>=g.life
            or (g.follow and not g.follow.Parent) then

            recycle(g)
            table.remove(f.groups,i)
        else
            local t=g.age/g.life

            local size=math.max(
                .03,
                (g.scale and g.scale(t) or 1)*g.effectSize
            )

            local frame=
                g.follow and g.follow.CFrame*g.localFrame
                or g.frame

            local position=
                frame.Position
                +g.velocity*g.age
                +g.gravity*(.5*g.age*g.age)

            local transform=
                CF.new(position)
                *frame.Rotation
                *CF.Angles(
                    g.spin.X*g.age,
                    g.spin.Y*g.age,
                    g.spin.Z*g.age
                )

            local fade=math.clamp(t^1.65,0,1)

            if g.flicker and math.floor(g.age*22)%3==1 then
                fade=1
            end

            for _,a in ipairs(g.atoms) do
                a.p.CFrame=
                    transform
                    *CF.new(a.cf.Position*size)
                    *a.cf.Rotation

                a.p.Size=V(
                    math.max(.01,a.size.X*size),
                    math.max(.01,a.size.Y*size),
                    math.max(.01,a.size.Z*size)
                )

                a.p.Transparency=a.alpha+(1-a.alpha)*fade

                if a.endColor then
                    a.p.Color=a.color:Lerp(a.endColor,t)
                end
            end
        end
    end
end

local function emitRecipe(f,frame,dash,size,follow)
    if not room(f,f.look[3]) then return end

    f.count=f.count+1
    f.spawnSize=size
    f.followPart=follow

    f.recipe.emit(f,frame,dash)

    f.spawnSize=nil
    f.followPart=nil
end

--------------------------------------------------
-- WEAVE AFTERIMAGES
-- Copies only body-part silhouettes, never scripts or hitboxes.
--------------------------------------------------

local function echo(s,f)
    local body={}

    for _,p in ipairs(s.c:GetChildren()) do
        if p:IsA('BasePart')
            and p.Name~='HumanoidRootPart'
            and p.Transparency<.95 then

            body[#body+1]=p
        end
    end

    if not room(f,#body) then return end

    local g=group(f,s.r.CFrame,.23)

    for _,p in ipairs(body) do
        atom(
            g,
            p:IsA('Part') and p.Shape or Enum.PartType.Block,
            s.r.CFrame:ToObjectSpace(p.CFrame),
            p.Size*.98,
            f.color:Lerp(WHITE,.18),
            .79,
            Enum.Material.Neon
        )
    end
end

--------------------------------------------------
-- DIRECTIONAL WEAVE BURSTS
--------------------------------------------------

local function weave(s,f,now)
    f.weaveSeen=s.weaveSerial or 0
    f.echoUntil=now+.32
    f.echoAt=now

    -- No screen flash, camera shake, hitbox, speed or i-frame changes.
    if not room(f,30) then return end

    local v=s.r.AssemblyLinearVelocity
    local direction=V(v.X,0,v.Z)

    if direction.Magnitude<1 then
        direction=s.r.CFrame.LookVector
    end

    direction=V(direction.X,0,direction.Z)

    if direction.Magnitude<.1 then
        direction=V(0,0,-1)
    end

    local frame=CF.lookAt(
        s.r.Position,
        s.r.Position+direction.Unit
    )

    local style=f.look[4]

    local g=group(
        f,frame,.42,nil,nil,V(0,3,0),
        function(t)
            return .65+t*1.3
        end
    )

    if style=='electric' then
        -- Forked electricity tears outward from both sides.
        for _,side in ipairs({-1,1}) do
            local last=V(side*.9,-.3,.4)

            for j=1,6 do
                local nextPoint=V(
                    side*(.9+j*.32),
                    rng:NextNumber(-.5,.6),
                    .4+j*.55
                )

                rod(g,last,nextPoint,.13,f.color,.18)
                last=nextPoint
            end
        end

    elseif style=='mist' then
        -- Soft spectral/colored smoke rather than bright rings.
        for j=1,6 do
            orb(
                g,
                CF.new(
                    rng:NextNumber(-2,2),
                    -.6,
                    rng:NextNumber(-1,1)
                ),
                V(1.4,1.7,1.4),
                f.color,
                .88,
                Enum.Material.SmoothPlastic
            )
        end

    elseif style=='star' then
        -- Expanding stellar corona.
        ring(
            g,CF.identity,
            1.7,.1,f.color,12,nil,.32
        )

        for j=0,7 do
            local a=j*math.pi/4

            rod(
                g,
                V(math.cos(a)*1.9,math.sin(a)*1.9,0),
                V(math.cos(a)*2.8,math.sin(a)*2.8,.3),
                .1,
                WHITE,
                .45
            )
        end

    else
        -- Paired crescents follow the actual dodge direction.
        for _,side in ipairs({-1,1}) do
            local previous

            for j=0,9 do
                local a=-1.1+j*.25

                local point=V(
                    side*math.cos(a)*2.1,
                    math.sin(a)*.65,
                    math.sin(a)*2.4
                )

                if previous then
                    rod(
                        g,previous,point,
                        style=='gold' and .13 or .09,
                        style=='gold' and GOLD or f.color,
                        .24
                    )
                end

                previous=point
            end
        end
    end

    for _,hand in ipairs(f.hands) do
        for _,n in ipairs(hand.nozzles) do
            n.e:Emit(Input.TouchEnabled and 5 or 10)
        end
    end
end

local function handFrame(hand,back,idle)
    local pos=hand.part.CFrame:PointToWorldSpace(hand.offset)

    local direction=
        idle and V(.1,.7,.2).Unit
        or back

    return CF.lookAt(pos,pos+direction)
end

--------------------------------------------------
-- CONTINUOUS EFFECT OUTPUT
--------------------------------------------------

local function update(s,dt,now,quality)
    if s.fx then
        animateGeometry(s.fx,dt)
    end

    if blocked(s) or not s.allowed then
        destroyFx(s)
        s.pending=false
        return
    end

    local item=selected(s)

    if not item then
        destroyFx(s)
        return
    end

    if s.fx and s.fx.id~=item.id then
        destroyFx(s)
    end

    local r=s.r

    if s.previous and (r.Position-s.previous).Magnitude>55 then
        if s.fx then
            clearParticles(s.fx)
            s.fx.echoUntil=0
        end

        s.pending=false
        s.dodgeUntil=0
        s.groundAt=0
    end

    s.previous=r.Position

    local velocity=r.AssemblyLinearVelocity
    local hit=grounded(s,now)

    if hit and hit.Instance and hit.Instance:IsA('BasePart') then
        velocity=
            velocity
            -hit.Instance:GetVelocityAtPosition(hit.Position)
    end

    local flat=V(velocity.X,0,velocity.Z)

    local climb=
        s.h:GetState()==Enum.HumanoidStateType.Climbing
        and velocity.Magnitude>1

    if flat.Magnitude>2 or climb then
        s.motionUntil=now+.16
    end

    local moving=now<(s.motionUntil or 0)
    local dash=now<(s.dodgeUntil or 0)
    local idle=not moving and not dash

    local on=
        (moving or dash or look(item)[2])
        and s.p:GetAttribute('HussEmotePlaying')==nil

    if not on then
        s.pending=false

        if s.fx then
            for _,e in ipairs(s.fx.emitters) do
                e.Enabled=false
                e.Rate=0
            end

            if now-s.usedAt>1.4 then
                destroyFx(s)
            end
        end

        return
    end

    s.usedAt=now

    local f=s.fx or createFx(s,item)

    local back=
        flat.Magnitude>.5 and -flat.Unit
        or -r.CFrame.LookVector

    local factor=quality*(s.p==me and 1 or .42)
    local power=idle and .24 or (dash and 2.2 or 1.55)
    local cap=Input.TouchEnabled and 75 or 140

    local groundPos=
        hit and hit.Position
        or r.Position-V(0,2.8,0)

    local base=
        V(r.Position.X,groundPos.Y+.8,r.Position.Z)
        +back*.7

    local footCF=CF.lookAt(base,base+back)

    -- Foot/back emitters.
    for _,n in ipairs(f.nozzles) do
        n.a.CFrame=r.CFrame:ToObjectSpace(
            footCF*CF.new(n.offset)
        )

        n.e.Rate=
            hit and math.clamp(
                n.rate*power*factor*1.4,
                0,
                cap
            )
            or 0

        n.e.Enabled=n.e.Rate>0
    end

    -- Matching emitters attached to both hands/arms.
    for _,hand in ipairs(f.hands) do
        if hand.part.Parent then
            local cf=handFrame(hand,back,idle)

            for _,n in ipairs(hand.nozzles) do
                n.a.CFrame=
                    hand.part.CFrame:ToObjectSpace(cf)

                n.e.Rate=math.clamp(
                    n.rate*power*factor*1.4,
                    0,
                    cap
                )

                n.e.Enabled=true
            end
        end
    end

    if s.pending then
        weave(s,f,now)
        s.pending=false
        f.next=0
        f.handAt=0
    end

    if now<f.echoUntil and now>=f.echoAt then
        f.echoAt=now+(Input.TouchEnabled and .12 or .085)
        echo(s,f)
    end

    -- Preserve the selected trail's original geometry recipe.
    if now>=f.next and hit then
        f.next=now+math.max(
            .07,
            f.recipe.interval
                *(idle and 2.4 or .62)
                /math.max(.4,factor)
        )

        emitRecipe(
            f,
            footCF,
            dash,
            f.look[1]*(idle and .60 or 1),
            nil
        )
    end

    -- Alternate recipe geometry between the two arms.
    -- Idle aura geometry follows its hand; moving geometry falls behind.
    if #f.hands>0 and now>=f.handAt then
        f.handAt=now+math.max(
            .11,
            f.recipe.interval
                *(idle and 1.8 or .75)
                /math.max(.45,factor)
        )

        f.handIndex=f.handIndex%#f.hands+1

        local hand=f.hands[f.handIndex]

        if hand.part.Parent then
            local cf=handFrame(hand,back,idle)

            emitRecipe(
                f,
                cf,
                dash,
                f.look[1]*.72,
                idle and hand.part or nil
            )
        end
    end
end

--------------------------------------------------
-- PLAYER LIFECYCLE AND PERFORMANCE LIMITS
--------------------------------------------------

link(Players.PlayerAdded,addPlayer)
link(Players.PlayerRemoving,removePlayer)

for _,p in ipairs(Players:GetPlayers()) do
    addPlayer(p)
end

local warnedReduced=false

link(Run.Heartbeat,function(dt)
    frameAverage=frameAverage*.96+math.min(dt,.2)*.04
    accum=accum+dt

    if accum<1/30 then
        return
    end

    local step=math.min(accum,.12)
    accum=0

    local now=os.clock()

    if reduced() then
        if not warnedReduced then
            warnedReduced=true

            warn(
                '[HAB Effects] Reduced Motion is ON; '
                .. 'cosmetic trails/auras are hidden.'
            )
        end

        for _,s in pairs(states) do
            destroyFx(s)
            s.pending=false
        end

        return
    end

    warnedReduced=false

    local camera=workspace.CurrentCamera
    if not camera then return end

    if now>=budgetClock then
        budgetClock=now+.12

        local candidates={}

        for _,s in pairs(states) do
            s.allowed=false

            if not blocked(s) then
                local item=selected(s)
                local velocity=s.r.AssemblyLinearVelocity

                local moving=
                    V(velocity.X,0,velocity.Z).Magnitude>2
                    or (
                        s.h:GetState()==Enum.HumanoidStateType.Climbing
                        and velocity.Magnitude>1
                    )

                s.distance=
                    (s.r.Position-camera.CFrame.Position).Magnitude

                if item
                    and (s.p==me or s.distance<FAR)
                    and (
                        moving
                        or look(item)[2]
                        or now<s.dodgeUntil
                        or s.fx~=nil
                    ) then

                    candidates[#candidates+1]=s
                end
            end
        end

        table.sort(candidates,function(a,b)
            if a.p==me then return b.p~=me end
            if b.p==me then return false end
            return a.distance<b.distance
        end)

        for i=1,math.min(MAX_SETS,#candidates) do
            candidates[i].allowed=true
        end
    end

    local quality=
        (Input.TouchEnabled and .72 or 1)
        *(frameAverage>1/35 and .7 or 1)

    for _,s in pairs(states) do
        if s.r then
            local ok,err=pcall(update,s,step,now,quality)

            if not ok then
                destroyFx(s)

                if now>(s.warnAt or 0) then
                    s.warnAt=now+10

                    warn(
                        '[HAB Arm/Weave] '
                        .. s.p.Name
                        .. ': '
                        .. tostring(err)
                    )
                end
            end
        end
    end
end)

task.spawn(function()
 local shared=RS:WaitForChild('Shared',20);local net=shared and shared:WaitForChild('Net',20)
 local remote=net and net:WaitForChild('DodgeIFrameRequest',20)
 if stopped or not remote or not remote:IsA('RemoteEvent') then return end
 link(remote.OnClientEvent,function(p,action,stamp)
  if p==me or not actions[action] or type(stamp)~='number' or stamp~=stamp then return end
  local s=states[p]
  if s and (not s.lastStamp or stamp>s.lastStamp) then s.lastStamp=stamp;beginDodge(s,workspace:GetServerTimeNow()-stamp) end
 end)
end)
link(script.Destroying,function()
 stopped=true;clearLinks(links)
 local list={};for p in pairs(states) do list[#list+1]=p end
 for _,p in ipairs(list) do removePlayer(p) end
 world:Destroy()
end)
print('[HAB Unique Boost] '..count..' catalog trails; 25 independent recipes loaded.')


-- HAB_TRAIL_VISIBILITY_3

-- HAB_ARMS_AURAS_WEAVES_4

-- HAB_HALLOWEEN_CRATES_1
