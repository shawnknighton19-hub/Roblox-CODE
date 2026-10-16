--!nonstrict
-- HAB V16: authored, permission-free action clips. Transform-only: no avatar physics changes.
-- Coordinates are avatar-local (+X right, +Y up, -Z forward), degrees. Positive shoulder X reaches forward.
-- Each clip has anticipation, contact, overshoot and a smooth return to the live locomotion pose.
local A = {Version=16}
local roles = {"root","waist","neck","rightArm","leftArm","rightElbow","leftElbow","rightWrist","leftWrist","rightHip","leftHip","rightKnee","leftKnee","rightAnkle","leftAnkle"}
A.Roles=roles
local ZERO={0,0,0,0,0,0}
local function p(x,y,z,tx,ty,tz) return {x or 0,y or 0,z or 0,tx or 0,ty or 0,tz or 0} end
local function key(t,pose,ease) return {Time=t,Pose=pose or {},Ease=ease or "smooth"} end
local function clip(duration,frames,opts)
 local c=opts or {};c.Duration=duration;c.Frames=frames
 -- Every key is a complete pose. Missing channels return to neutral, never retain stale limb offsets.
 for _,frame in ipairs(frames) do for _,role in ipairs(roles) do frame.Pose[role]=frame.Pose[role] or ZERO end end
 return c
end
local clips={}
-- Three readable strikes: cross-body right hook, mirrored left hook, overhand hammer.
clips.Swing=clip(.48,{
 key(0),
 key(.095,{root=p(2,-23,-7,0,-.05,0),waist=p(-3,-18,-5),neck=p(-3,24,5),rightArm=p(28,-40,68),rightElbow=p(68),rightWrist=p(0,0,-14),leftArm=p(47,10,-24),leftElbow=p(80),rightHip=p(-7,7,2),leftHip=p(9,-5,-2)}),
 key(.115,{root=p(-7,18,4,0,-.04,-.045),waist=p(-5,27,6),neck=p(4,-24,-4),rightArm=p(94,55,-8),rightElbow=p(12),rightWrist=p(0,0,8),leftArm=p(18,-9,-30),leftElbow=p(75),rightHip=p(8,0,2),leftHip=p(-7,-8,-2)},"out"),
 key(.21,{root=p(-4,29,8,0,0,-.035),waist=p(-4,25,7),neck=p(2,-26,-6),rightArm=p(76,76,-20),rightElbow=p(38),leftArm=p(12,-18,-34),leftElbow=p(70),rightHip=p(9),leftHip=p(-7)}),
 key(.35,{root=p(1,-5,-1),waist=p(0,-5,-2),neck=p(0,5),rightArm=p(22,12,12),rightElbow=p(42),leftArm=p(20,0,-12),leftElbow=p(35)}),
 key(.48),
},{Contact=.115,Priority=30,LegWeight=.18})
clips.Hammer=clip(.48,{
 key(0),
 key(.095,{root=p(8,-12,-5,0,-.06,0),waist=p(10,-15),neck=p(-8,15),rightArm=p(153,-20,30),rightElbow=p(100),leftArm=p(55,12,-28),leftElbow=p(85),rightHip=p(-12),leftHip=p(12)}),
 key(.115,{root=p(-15,16,4,0,-.08,-.04),waist=p(-13,20,4),neck=p(12,-18,-3),rightArm=p(75,27,-8),rightElbow=p(7),rightWrist=p(20),leftArm=p(25,0,-35),leftElbow=p(65),rightHip=p(10),leftHip=p(-7)},"out"),
 key(.21,{root=p(-9,21,6,0,-.04,0),waist=p(-8,18,5),neck=p(8,-17,-4),rightArm=p(24,37,-15),rightElbow=p(20),leftArm=p(12,-12,-30),leftElbow=p(45)}),
 key(.35,{root=p(2,-3),waist=p(2,-4),rightArm=p(13,4,8),rightElbow=p(38),leftArm=p(15,0,-12),leftElbow=p(30)}),key(.48),
},{Contact=.115,Priority=30,LegWeight=.16})
clips.Throw=clip(.56,{
 key(0),
 key(.12,{root=p(4,-25,-5,0,-.05,0),waist=p(6,-26,-5),neck=p(-5,30,4),rightArm=p(158,-36,39),rightElbow=p(98),rightWrist=p(-18),leftArm=p(78,7,-14),leftElbow=p(17),rightHip=p(-9),leftHip=p(11)}),
 key(.18,{root=p(-12,17,6,0,-.06,-.045),waist=p(-12,29,8),neck=p(8,-26,-6),rightArm=p(99,15,2),rightElbow=p(4),rightWrist=p(22),leftArm=p(12,0,-30),leftElbow=p(80),rightHip=p(12),leftHip=p(-10)},"out"),
 key(.29,{root=p(-10,27,8,0,-.035,0),waist=p(-8,27,7),neck=p(8,-25,-5),rightArm=p(49,65,-23),rightElbow=p(34),leftArm=p(-5,-16,-38),leftElbow=p(57)}),
 key(.42,{root=p(1,-4),waist=p(1,-5),rightArm=p(16,5,13),rightElbow=p(34),leftArm=p(12,0,-12),leftElbow=p(28)}),key(.56),
},{Contact=.18,Priority=32,LegWeight=.17})
clips.Hit=clip(.42,{
 key(0),key(.045,{root=p(12,-9,7,0,.035,.06),waist=p(16,-12,8),neck=p(-12,9,-5),rightArm=p(27,-16,43),leftArm=p(24,14,-42),rightElbow=p(65),leftElbow=p(70),rightHip=p(-8),leftHip=p(8)},"out"),
 key(.115,{root=p(7,-6,5),waist=p(10,-9,5),neck=p(-6,8,-4),rightArm=p(43,-8,32),leftArm=p(42,8,-31),rightElbow=p(85),leftElbow=p(80)}),
 key(.26,{root=p(-3,3,-2),waist=p(-4,4,-2),neck=p(4,-3),rightArm=p(24,0,14),leftArm=p(22,0,-14),rightElbow=p(35),leftElbow=p(35)}),key(.42),
},{Priority=40,LegWeight=.12})
clips.Block=clip(.44,{
 key(0),key(.06,{root=p(7,7,-3,0,-.05,.025),waist=p(9,11,-3),neck=p(-8,-9,3),rightArm=p(98,30,12),leftArm=p(96,-28,-12),rightElbow=p(110),leftElbow=p(108),rightWrist=p(0,0,-15),leftWrist=p(0,0,15)},"out"),
 key(.15,{root=p(-4,-7,2,0,-.03,-.025),waist=p(-7,-10,2),neck=p(7,9,-2),rightArm=p(100,12,27),leftArm=p(102,-13,-25),rightElbow=p(65),leftElbow=p(65)}),
 key(.29,{root=p(1),rightArm=p(45,5,15),leftArm=p(45,-5,-15),rightElbow=p(65),leftElbow=p(65)}),key(.44),
},{Priority=45,LegWeight=.12})
clips.Shield=clip(.9,{
 key(0),key(.095,{root=p(-7,0,0,0,-.08,0),waist=p(-6),neck=p(9),rightArm=p(75,44,-9),leftArm=p(74,-44,9),rightElbow=p(95),leftElbow=p(95)}),
 key(.19,{root=p(1,0,0,0,-.025,0),waist=p(3),neck=p(-3),rightArm=p(101,-8,26),leftArm=p(101,8,-26),rightElbow=p(15),leftElbow=p(15),rightWrist=p(-12),leftWrist=p(-12)},"out"),
 key(.35,{root=p(-2),waist=p(-2),neck=p(3),rightArm=p(80,19,11),leftArm=p(80,-19,-11),rightElbow=p(60),leftElbow=p(60)}),
 key(.7,{root=p(-2),waist=p(-2),neck=p(3),rightArm=p(77,18,12),leftArm=p(77,-18,-12),rightElbow=p(62),leftElbow=p(62)}),key(.9),
},{Priority=25,LegWeight=.15})
clips.Leap=clip(.82,{
 key(0),key(.065,{root=p(-15,0,0,0,-.14,0),waist=p(-15),neck=p(20),rightArm=p(-27,-9,15),leftArm=p(-27,9,-15),rightElbow=p(40),leftElbow=p(40),rightHip=p(32),leftHip=p(32),rightKnee=p(-48),leftKnee=p(-48),rightAnkle=p(18),leftAnkle=p(18)}),
 key(.16,{root=p(5,0,0,0,.08,0),waist=p(8),neck=p(-8),rightArm=p(145,-7,19),leftArm=p(145,7,-19),rightElbow=p(14),leftElbow=p(14),rightHip=p(-16),leftHip=p(-13),rightKnee=p(-10),leftKnee=p(-10)},"out"),
 key(.31,{root=p(-9,9,-5,0,.03,0),waist=p(-10,10,-4),neck=p(12,-10,4),rightArm=p(58,-13,40),leftArm=p(88,10,-34),rightElbow=p(84),leftElbow=p(70),rightHip=p(65),leftHip=p(30),rightKnee=p(-83),leftKnee=p(-64),rightAnkle=p(23),leftAnkle=p(22)}),
 key(.55,{root=p(-5,3,-2),waist=p(-5,3),neck=p(7,-4),rightArm=p(30,-9,29),leftArm=p(37,8,-24),rightElbow=p(42),leftElbow=p(40),rightHip=p(18),leftHip=p(-5),rightKnee=p(-32),leftKnee=p(-19)}),key(.82),
},{Priority=25,LegWeight=1})
clips.Speed=clip(.6,{
 key(0),key(.075,{root=p(4,-12,-4,0,-.05,0),waist=p(5,-14,-4),neck=p(-4,13,3),rightArm=p(84,15,15),leftArm=p(-25,-12,-17),rightElbow=p(90),leftElbow=p(60)}),
 key(.16,{root=p(-12,8,4,0,-.03,0),waist=p(-14,10,5),neck=p(16,-10,-4),rightArm=p(-35,-8,18),leftArm=p(92,8,-16),rightElbow=p(45),leftElbow=p(90)},"out"),
 key(.32,{root=p(-8,-5,-2),waist=p(-10,-6,-3),neck=p(13,7,2),rightArm=p(74,6,12),leftArm=p(-24,-7,-12),rightElbow=p(86),leftElbow=p(50)}),key(.6),
},{Priority=20,LegWeight=.06})
clips.Decoy=clip(.72,{
 key(0),key(.12,{root=p(-5,22,7,0,-.04,0),waist=p(-5,22,6),neck=p(4,-22,-5),rightArm=p(68,58,-10),leftArm=p(26,0,-17),rightElbow=p(90),leftElbow=p(65)}),
 key(.25,{root=p(-3,-22,-5),waist=p(-4,-26,-6),neck=p(3,25,5),rightArm=p(70,-30,59),leftArm=p(65,15,-23),rightElbow=p(10),leftElbow=p(35),rightWrist=p(0,25,-13)},"out"),
 key(.41,{root=p(2,-13,-3),waist=p(3,-13,-3),neck=p(-2,17,3),rightArm=p(48,-32,48),leftArm=p(34,8,-20),rightElbow=p(25),leftElbow=p(35)}),key(.72),
},{Priority=20,LegWeight=.1})
clips.Jester=clip(1.05,{
 key(0),key(.13,{root=p(-4,-26,-9,0,-.06,0),waist=p(-3,-20,-7),neck=p(4,21,6),rightArm=p(12,-20,48),leftArm=p(35,16,-48),rightElbow=p(60),leftElbow=p(65)}),
 key(.29,{root=p(0,65,9,0,.035,0),waist=p(0,38,7),neck=p(0,-30,-6),rightArm=p(35,4,78),leftArm=p(35,-4,-78),rightElbow=p(17),leftElbow=p(17)},"linear"),
 key(.46,{root=p(0,170,0,0,.05,0),waist=p(0,38),neck=p(0,-25),rightArm=p(24,0,77),leftArm=p(24,0,-77),rightElbow=p(13),leftElbow=p(13)},"linear"),
 key(.64,{root=p(-4,285,-8,0,-.02,0),waist=p(-3,20,-6),neck=p(5,-20,5),rightArm=p(50,15,55),leftArm=p(50,-15,-55),rightElbow=p(55),leftElbow=p(55)},"linear"),
 key(.81,{root=p(2,361,3),waist=p(2,-4,2),neck=p(-2,3,-2),rightArm=p(55,10,24),leftArm=p(18,-8,-26),rightElbow=p(90),leftElbow=p(45)}),
 key(1.05,{root=p(0,360)}),
},{Priority=20,LegWeight=.08})
clips.Bubble=clip(.72,{
 key(0),key(.1,{root=p(-6,0,0,0,-.055,0),waist=p(-7),neck=p(10),rightArm=p(80,24,-2),leftArm=p(80,-24,2),rightElbow=p(95),leftElbow=p(95)}),
 key(.22,{root=p(1,0,0,0,.04,0),waist=p(4),neck=p(-5),rightArm=p(74,-18,58),leftArm=p(74,18,-58),rightElbow=p(16),leftElbow=p(16)},"out"),
 key(.39,{root=p(-8,7,4),waist=p(-10,9,4),neck=p(12,-9,-3),rightArm=p(-13,-10,23),leftArm=p(68,8,-20),rightElbow=p(45),leftElbow=p(85)}),key(.72),
},{Priority=20,LegWeight=.08})
clips.Pogo=clip(.88,{
 key(0),key(.075,{root=p(-12,0,0,0,-.18,0),waist=p(-10),neck=p(15),rightArm=p(45,13,14),leftArm=p(45,-13,-14),rightElbow=p(105),leftElbow=p(105),rightHip=p(38),leftHip=p(38),rightKnee=p(-58),leftKnee=p(-58),rightAnkle=p(20),leftAnkle=p(20)}),
 key(.19,{root=p(7,0,0,0,.085,0),waist=p(6),neck=p(-8),rightArm=p(136,0,32),leftArm=p(136,0,-32),rightElbow=p(12),leftElbow=p(12),rightHip=p(-10),leftHip=p(-10)},"out"),
 key(.37,{root=p(-5,-8,7),waist=p(-4,-8,6),neck=p(8,9,-5),rightArm=p(58,0,34),leftArm=p(62,0,-34),rightElbow=p(75),leftElbow=p(75),rightHip=p(42),leftHip=p(42),rightKnee=p(-65),leftKnee=p(-65)}),
 key(.59,{root=p(-8,3,-3,0,-.045,0),waist=p(-6,3,-3),neck=p(8,-3,2),rightArm=p(32,0,22),leftArm=p(32,0,-22),rightElbow=p(35),leftElbow=p(35),rightHip=p(16),leftHip=p(16),rightKnee=p(-27),leftKnee=p(-27)}),key(.88),
},{Priority=25,LegWeight=1})
clips.Disco=clip(1.15,{
 key(0),key(.14,{root=p(-5,-14,-9,0,-.055,0),waist=p(-4,-16,-7),neck=p(4,16,6),rightArm=p(82,26,12),leftArm=p(28,-14,-28),rightElbow=p(95),leftElbow=p(75)}),
 key(.31,{root=p(2,18,10,0,.04,0),waist=p(3,20,8),neck=p(-3,-19,-6),rightArm=p(145,-12,48),leftArm=p(16,-6,-34),rightElbow=p(5),leftElbow=p(45)},"out"),
 key(.49,{root=p(-3,-17,-8,0,-.04,0),waist=p(-3,-19,-7),neck=p(4,18,6),rightArm=p(63,9,20),leftArm=p(72,-18,-23),rightElbow=p(100),leftElbow=p(95)}),
 key(.67,{root=p(2,-18,-10,0,.035,0),waist=p(3,-20,-8),neck=p(-3,19,6),rightArm=p(18,6,34),leftArm=p(145,12,-48),rightElbow=p(45),leftElbow=p(5)},"out"),
 key(.87,{root=p(-2,6,3),waist=p(-2,7,3),neck=p(3,-7,-2),rightArm=p(60,10,27),leftArm=p(60,-10,-27),rightElbow=p(80),leftElbow=p(80)}),key(1.15),
},{Priority=20,LegWeight=.1})
clips.Confetti=clip(.8,{
 key(0),key(.13,{root=p(6,-20,-6,0,-.07,0),waist=p(7,-23,-5),neck=p(-6,23,4),rightArm=p(52,30,18),leftArm=p(67,-35,-5),rightElbow=p(110),leftElbow=p(110)}),
 key(.24,{root=p(-4,13,6),waist=p(-6,17,6),neck=p(6,-16,-5),rightArm=p(132,-6,24),leftArm=p(114,12,-26),rightElbow=p(8),leftElbow=p(12),rightWrist=p(-10),leftWrist=p(-10)},"out"),
 key(.34,{root=p(5,18,7,0,.025,.025),waist=p(7,18,7),neck=p(-6,-15,-5),rightArm=p(120,-9,36),leftArm=p(104,8,-35),rightElbow=p(42),leftElbow=p(45)}),
 key(.51,{root=p(-4,-6,-3),waist=p(-5,-7,-3),neck=p(6,7,2),rightArm=p(42,-5,27),leftArm=p(41,5,-26),rightElbow=p(55),leftElbow=p(55)}),key(.8),
},{Priority=20,LegWeight=.08})
-- Grounded anticipation is authored for the abilities too. Running legs retain their live
-- gait through LegWeight; the grounded preview reveals the braced feet and controlled dip.
local stances={
 Shield={8,8,7},Speed={-12,17,4},Decoy={11,-8,9},Jester={10,-10,6},
 Bubble={9,9,7},Disco={12,-12,8},Confetti={-10,14,8},
}
for name,stance in pairs(stances) do
 local c=clips[name]
 for _,frame in ipairs(c.Frames) do
  if frame.Time>0 and frame.Time<c.Duration then
   local load=math.sin(math.pi*frame.Time/c.Duration)
   if frame.Pose.rightHip==ZERO then frame.Pose.rightHip=p(stance[1]*load,stance[3]*load,5*load) end
   if frame.Pose.leftHip==ZERO then frame.Pose.leftHip=p(stance[2]*load,-stance[3]*load,-5*load) end
   if frame.Pose.rightKnee==ZERO then frame.Pose.rightKnee=p(-18*load) end
   if frame.Pose.leftKnee==ZERO then frame.Pose.leftKnee=p(-18*load) end
   if frame.Pose.rightAnkle==ZERO then frame.Pose.rightAnkle=p(9*load) end
   if frame.Pose.leftAnkle==ZERO then frame.Pose.leftAnkle=p(9*load) end
   local root=table.clone(frame.Pose.root);root[5]-=.065*load;frame.Pose.root=root
  end
 end
end
A.Clips=clips
A.JointRoles={Torso="root",LowerTorso="root",UpperTorso="waist",Head="neck",["Right Arm"]="rightArm",["Left Arm"]="leftArm",RightUpperArm="rightArm",LeftUpperArm="leftArm",RightLowerArm="rightElbow",LeftLowerArm="leftElbow",RightHand="rightWrist",LeftHand="leftWrist",["Right Leg"]="rightHip",["Left Leg"]="leftHip",RightUpperLeg="rightHip",LeftUpperLeg="leftHip",RightLowerLeg="rightKnee",LeftLowerLeg="leftKnee",RightFoot="rightAnkle",LeftFoot="leftAnkle"}
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function smooth(v) return v*v*(3-2*v) end
local function mirrorRole(role) return role:gsub("right","_LEFT_"):gsub("left","right"):gsub("_LEFT_","left") end
function A.Resolve(kind,sequence)
 if kind~="Swing" then return clips[kind] and kind or nil,false end
 local n=finite(sequence) and math.max(1,math.floor(sequence)) or 1
 return n%3==0 and "Hammer" or "Swing",n%3==2
end
function A.Duration(kind,options)
 local c=clips[kind];if not c then return 0 end
 local d=options and options.Duration
 return finite(d) and math.clamp(d,.24,2) or c.Duration
end
function A.Sample(kind,age,options)
 local c=clips[kind];if not c or not finite(age) or age<0 then return nil end
 options=options or {};local duration=A.Duration(kind,options)
 if age>=duration then return nil end
 local t=age*c.Duration/duration
 -- Keep strike contact aligned to the authoritative hit window, including changed tuning.
 if c.Contact and finite(options.Contact) then
  local at=math.clamp(options.Contact,.025,duration-.08)
  if age<=at then t=age/at*c.Contact else t=c.Contact+(age-at)/(duration-at)*(c.Duration-c.Contact) end
 end
 local a,b=c.Frames[1],c.Frames[#c.Frames]
 for i=2,#c.Frames do if t<=c.Frames[i].Time then a,b=c.Frames[i-1],c.Frames[i];break end end
 local u=math.clamp((t-a.Time)/math.max(.0001,b.Time-a.Time),0,1)
 if b.Ease=="out" then u=1-(1-u)^3 elseif b.Ease~="linear" then u=smooth(u) end
 local envelope=smooth(math.clamp(age/.045,0,1))*smooth(math.clamp((duration-age)/.16,0,1))
 local sample={Name=kind,Weight=envelope,Pose={},Priority=c.Priority,LegWeight=c.LegWeight,Duration=duration}
 for _,role in ipairs(roles) do
  local from,to=a.Pose[role],b.Pose[role];local values={}
  for n=1,6 do values[n]=from[n]+(to[n]-from[n])*u end
  local outputRole=role
  if options.Mirror then outputRole=mirrorRole(role);values[2]=-values[2];values[3]=-values[3];values[4]=-values[4] end
  sample.Pose[outputRole]=values
 end
 return sample
end
function A.JointInfo(joint)
 if not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return nil end
 local child=joint.Part1;local basis=joint.C0
 if not child and joint:IsA("AnimationConstraint") then
  local attachment=joint.Attachment1;child=attachment and attachment.Parent
  local origin=joint.Attachment0;basis=origin and origin.CFrame
 end
 local role=child and A.JointRoles[child.Name]
 if not role or not basis then return nil end
 return {Object=joint,Role=role,Axes=basis.Rotation}
end
function A.Transform(sample,role,r15,reduced)
 local values=sample.Pose[role] or ZERO
 local x,y,z,tx,ty,tz=table.unpack(values)
 if role=="root" and r15 then x*=.38;y*=.45;z*=.42
 elseif role=="waist" and r15 then x*=.62;y*=.55;z*=.58
 elseif role=="root" then
  -- R6 has no waist: merge the authored upper torso contribution into its sole torso joint.
  local upper=sample.Pose.waist or ZERO
  x=x*.38+upper[1]*.62;y=y*.45+upper[2]*.55;z=z*.42+upper[3]*.58
 end
 if sample.Name=="Jester" and role=="root" then
  -- The spin belongs to the cosmetic root, not the physical HumanoidRootPart or camera.
  -- Preserve the complete turn; a 360-degree finish is exactly the locomotion orientation.
  y=reduced and math.sin(math.rad(values[2]))*14 or values[2]
 end
 return CFrame.new(tx,ty,tz)*CFrame.Angles(math.rad(x),math.rad(y),math.rad(z))
end
function A.Weight(sample,role,moving,reduced)
 local w=sample.Weight
 if role:find("Hip") or role:find("Knee") or role:find("Ankle") then w*=moving and sample.LegWeight or math.max(.35,sample.LegWeight) end
 if reduced then w*=.55 end
 return w
end
-- Evaluate the joint chain without moving a part. Grounded actions keep the lowest
-- foot at the live Animator's plane while airborne abilities retain their leg tuck.
function A.FootHeight(joints,root,transforms,feet)
 local frames={[root]=CFrame.identity}
 for _=1,7 do
  local changed=false
  for _,record in ipairs(joints) do
   local joint=record.Object
   if joint.Parent and joint.Enabled and joint.Part0 and joint.Part1 and frames[joint.Part0] and not frames[joint.Part1] then
    frames[joint.Part1]=frames[joint.Part0]*joint.C0*(transforms[joint] or CFrame.identity)*joint.C1:Inverse()
    changed=true
   end
  end
  if not changed then break end
 end
 local lowest
 for _,foot in ipairs(feet) do
  local cf=frames[foot]
  if cf and foot.Parent then
   local half=foot.Size*.5
   local extent=math.abs(cf.RightVector.Y)*half.X+math.abs(cf.UpVector.Y)*half.Y+math.abs(cf.LookVector.Y)*half.Z
   local height=cf.Position.Y-extent
   lowest=lowest and math.min(lowest,height) or height
  end
 end
 return lowest
end
return A
