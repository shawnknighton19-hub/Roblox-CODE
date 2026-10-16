--!nonstrict
-- V16 grounded action weave choreography. No assets, Instances or gameplay writes.
-- Local axes are the character's axes: +X right, -Z forward. All angles are degrees.
local A = {Duration = .72}
local CF, rad = CFrame.new, math.rad
A.Directions = {
	DiveForward={0,1}, DiveBack={0,-1}, DiveLeft={-1,0}, DiveRight={1,0},
	DiveForwardLeft={-.70710678,.70710678}, DiveForwardRight={.70710678,.70710678},
	DiveBackLeft={-.70710678,-.70710678}, DiveBackRight={.70710678,-.70710678},
}
A.Roles = {
	Torso="root", LowerTorso="root", UpperTorso="waist", Head="neck",
	["Left Arm"]="leftArm", ["Right Arm"]="rightArm",
	["Left Leg"]="leftHip", ["Right Leg"]="rightHip",
	LeftUpperArm="leftArm", RightUpperArm="rightArm",
	LeftLowerArm="leftElbow", RightLowerArm="rightElbow",
	LeftUpperLeg="leftHip", RightUpperLeg="rightHip",
	LeftLowerLeg="leftKnee", RightLowerLeg="rightKnee",
	LeftFoot="leftAnkle", RightFoot="rightAnkle",
}
-- Time / blend / load / drive / shoulder turn / reaching step / planting step / recoil.
-- The middle hold reads during the existing movement burst; recovery ends with that burst.
local keys = {
	{0,    0,   0,   0,    0,    0,    0,   0},
	{.045, .88, .72,-.18, -.16, -.22,  0,   0},
	{.115, 1,   1,  .88,  .78,  .78,  0,   0},
	{.205, 1,   .9, 1,    1,    1,    .08, 0},
	{.315, 1,   .62,.7,   .65,  .48,  .3,  0},
	{.425, .92, .3, .16,  .08, -.38,  1,   .15},
	{.525, .62, .12,-.15,-.15, -.18,  .62, 1},
	{.625, .18, .02,0,    0,    .02,  .08, .22},
	{.72,  0,   0,  0,    0,    0,    0,   0},
}
local function channels(t)
	for i=2,#keys do
		local a,b=keys[i-1],keys[i]
		if t<=b[1] then
			local u=math.clamp((t-a[1])/(b[1]-a[1]),0,1)
			u=u*u*(3-2*u)
			local out={}
			for j=2,8 do out[j-1]=a[j]+(b[j]-a[j])*u end
			return out
		end
	end
	return {0,0,0,0,0,0,0}
end
local function frame(x,y,z,rx,ry,rz)
	return CF(x,y,z)*CFrame.Angles(rad(rx),rad(ry),rad(rz))
end
function A.Sample(action, elapsed, r15, reducedMotion)
	local direction=A.Directions[action]
	if not direction or type(elapsed)~="number" or elapsed~=elapsed or elapsed<0 or elapsed>=A.Duration then
		return {Weight=0, Poses={}}
	end
	local w,load,drive,turn,reach,plant,recoil=table.unpack(channels(elapsed))
	local side,front=direction[1],direction[2]
	local lateral=math.abs(side)
	local forward,back=math.max(front,0),math.max(-front,0)
	local lead=side~=0 and (side>0 and 1 or -1) or 1
	local intensity=reducedMotion and .72 or 1
	-- Forward rolls a shoulder past the carrier; side dodges power-step; back dodges brace.
	local pitch=(-49*forward+27*back-22*lateral)*drive+8*recoil-9*load*(1-math.abs(drive))
	local roll=(-37*side-22*forward*(1-lateral)+8*back*(1-lateral))*drive
	local yaw=(24*side-25*forward*(1-lateral)+12*back*(1-lateral))*turn
	pitch,roll,yaw=pitch*intensity,roll*intensity,yaw*intensity
	local p={}
	local rootShare=r15 and .44 or 1
	p.root=frame(side*.26*drive,0,-forward*.17*drive+back*.08*drive,
		pitch*rootShare,yaw*.72,roll*(r15 and .56 or 1))
	p.waist=frame(0,0,0,pitch*.56,yaw*.28,roll*.44)
	-- Head stays on the opponent while the shoulder passes underneath.
	p.neck=frame(0,0,0,-pitch*.78,-yaw*.82,-roll*.72)
	for _,entry in ipairs({{"left",-1},{"right",1}}) do
		local name,sign=entry[1],entry[2]
		local leading=sign==lead and 1 or -1
		local guard=load*(45+38*back)
		local pump=(-leading*57*forward+leading*14*lateral)*drive
		local armPitch=14+guard+pump+18*plant*leading-12*recoil
		local armYaw=sign*(12*load+20*forward*turn)-yaw*.2
		local armRoll=sign*(16+22*load+19*lateral*drive)-side*15*drive
		p[name.."Arm"]=frame(0,0,0,armPitch,armYaw,armRoll)
		p[name.."Elbow"]=frame(0,0,0,36+49*load+18*back*drive,0,0)
		-- R6 has rigid legs: counter-bank the hip, then reach and cross-step at recovery.
		local counterPitch=-pitch*(r15 and .44 or .92)
		local hipPitch=counterPitch+(r15 and 31*load or 0)
			+leading*(forward*34-back*25)*reach-leading*18*plant
		local hipRoll=-roll*(r15 and .48 or .86)+sign*(7*load+19*lateral*reach)
		p[name.."Hip"]=frame(0,0,0,hipPitch,-yaw*.28+leading*5*turn,hipRoll)
		p[name.."Knee"]=frame(0,0,0,-(45+leading*12)*load-18*math.max(leading*reach,0),0,0)
		p[name.."Ankle"]=frame(0,0,0,24*load+7*plant,0,-hipRoll*.35)
	end
	return {Weight=w, Poses=p}
end

-- Bind axes differ between R6 shoulders/hips and R15 joints. Author poses in body axes.
function A.JointTransform(joint, pose)
	local axes=joint.C0.Rotation
	return axes:Inverse()*pose*axes
end

-- Forward kinematics only: never move an actual BasePart. This keeps the lowest foot
-- on its normal plane as the torso ducks, including rotated R6 hip bind frames.
function A.FootHeight(joints, root, transforms, feet)
	local frames={[root]=CFrame.new()}
	for _=1,7 do
		local advanced=false
		for _,record in ipairs(joints) do
			local j=record.motor
			if j.Parent and j.Enabled and j.Part0 and j.Part1 and frames[j.Part0] and not frames[j.Part1] then
				frames[j.Part1]=frames[j.Part0]*j.C0*(transforms and transforms[j] or CFrame.new())*j.C1:Inverse()
				advanced=true
			end
		end
		if not advanced then break end
	end
	local lowest
	for _,foot in ipairs(feet) do
		local cf=frames[foot]
		if cf and foot.Parent then
			local half=foot.Size*.5
			local extent=math.abs(cf.RightVector.Y)*half.X+math.abs(cf.UpVector.Y)*half.Y+math.abs(cf.LookVector.Y)*half.Z
			local y=cf.Position.Y-extent
			lowest=lowest and math.min(lowest,y) or y
		end
	end
	return lowest
end
return A
