local samples={}
for _,r15Rig in ipairs({false,true}) do
 for _,phase in ipairs({0,math.pi/2,math.pi,math.pi*1.5}) do
  local p=newCharacter('Preview',r15Rig)
  local c=p.Character
  if r15Rig then
   c:Destroy()
   c=Instance.new('Model',workspace)
   local parts={}
   local function part(name,size)
    local o=Instance.new('Part',c);o.Name=name;o.Size=size;parts[name]=o;return o
   end
   part('HumanoidRootPart',Vector3.new(2,2,1)).CFrame=CFrame.new(0,3.1,0)
   part('LowerTorso',Vector3.new(1.8,.8,1));part('UpperTorso',Vector3.new(2,1.5,1));part('Head',Vector3.new(1.25,1.2,1.2))
   local function joint(name,from,to,c0,c1)
    local j=Instance.new('Motor6D',parts[from]);j.Name=name;j.Part0=parts[from];j.Part1=parts[to];j.C0=c0;j.C1=c1;j.Transform=CFrame.new();j.Enabled=true
   end
   joint('Root','HumanoidRootPart','LowerTorso',CFrame.new(),CFrame.new())
   joint('Waist','LowerTorso','UpperTorso',CFrame.new(0,.4,0),CFrame.new(0,-.75,0))
   joint('Neck','UpperTorso','Head',CFrame.new(0,.75,0),CFrame.new(0,-.6,0))
   for _,side in ipairs({-1,1}) do
    local n=side<0 and 'Left' or 'Right'
    part(n..'UpperArm',Vector3.new(.62,1.15,.62));part(n..'LowerArm',Vector3.new(.56,1.05,.56));part(n..'Hand',Vector3.new(.6,.5,.65))
    part(n..'UpperLeg',Vector3.new(.85,1.2,.85));part(n..'LowerLeg',Vector3.new(.75,1.15,.75));part(n..'Foot',Vector3.new(.8,.4,1.2))
    joint(n..'Shoulder','UpperTorso',n..'UpperArm',CFrame.new(side*1.3,.45,0),CFrame.new(0,.5,0))
    joint(n..'Elbow',n..'UpperArm',n..'LowerArm',CFrame.new(0,-.575,0),CFrame.new(0,.525,0))
    joint(n..'Wrist',n..'LowerArm',n..'Hand',CFrame.new(0,-.525,0),CFrame.new(0,.25,0))
    joint(n..'Hip','LowerTorso',n..'UpperLeg',CFrame.new(side*.5,-.4,0),CFrame.new(0,.6,0))
    joint(n..'Knee',n..'UpperLeg',n..'LowerLeg',CFrame.new(0,-.6,0),CFrame.new(0,.575,0))
    joint(n..'Ankle',n..'LowerLeg',n..'Foot',CFrame.new(0,-.575,0),CFrame.new(0,.2,.1))
   end
  end
  local roles={Torso='body',UpperTorso='body',Head='neck',['Left Arm']='leftArm',['Right Arm']='rightArm',LeftUpperArm='leftArm',RightUpperArm='rightArm',LeftLowerArm='leftElbow',RightLowerArm='rightElbow'}
  local joints={}
  for _,motor in ipairs(c:GetDescendants()) do if motor:IsA('Motor6D') then
   local role=roles[motor.Part1.Name]
   if role then
    local axes=motor.C0.Rotation
    local offset=axes:Inverse()*panicExports.pose(role,phase,1,r15Rig)*axes
    local upperArm=role=='leftArm' or role=='rightArm' or role=='leftElbow' or role=='rightElbow'
    motor.Transform=CFrame.new():Lerp(offset,upperArm and .86 or 1)
   elseif motor.Name:find('Hip',1,true) then
    local direction=motor.Name:find('Left',1,true) and -1 or 1
    local axes=motor.C0.Rotation
    motor.Transform=axes:Inverse()*CFrame.Angles(math.sin(phase)*.7*direction,0,0)*axes
   end
   table.insert(joints,motor)
  end end
  for _=1,8 do for _,j in ipairs(joints) do j.Part1.CFrame=j.Part0.CFrame*j.C0*j.Transform*j.C1:Inverse() end end
  local parts={}
  for _,part in ipairs(c:GetChildren()) do if part:IsA('BasePart') and part.Name~='HumanoidRootPart' then
   table.insert(parts,{Name=part.Name,Size={part.Size.X,part.Size.Y,part.Size.Z},CFrame={part.CFrame:GetComponents()}})
  end end
  local head=c.Head
  for _,side in ipairs({-1,1}) do
   for step=0,3 do
    local cf=head.CFrame*CFrame.new(side*(.3+step*.21),.1-step*.14,-.7+step*.04)
    table.insert(parts,{Name='Tear',Size={.1,.2,.1},CFrame={cf:GetComponents()}})
   end
  end
  table.insert(samples,{Rig=r15Rig and 'R15' or 'R6',Phase=phase,Parts=parts})
 end
end
print('PANIC_PREVIEW_JSON:'..json(samples))
