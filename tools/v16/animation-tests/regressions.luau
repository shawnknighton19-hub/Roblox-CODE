local kinds={'Swing','Hammer','Throw','Hit','Block','Shield','Leap','Speed','Decoy','Jester','Bubble','Pogo','Disco','Confetti'}
local function finiteCF(cf) for _,v in ipairs({cf:GetComponents()}) do if v~=v or math.abs(v)==math.huge then return false end end;return true end
local signatures={}
for _,kind in ipairs(kinds) do
 local clip=A.Clips[kind]
 check(clip and #clip.Frames>=4,kind..' authored keys')
 check(A.Sample(kind,-1)==nil and A.Sample(kind,0/0)==nil and A.Sample(kind,clip.Duration)==nil,kind..' boundedtime')
 local start=A.Sample(kind,0);check(start.Weight==0,kind..' entryneutral')
 local final=A.Sample(kind,clip.Duration-.00001)
 check(final.Weight<.00001,kind..' exitneutral')
 local signature={}
 for n=0,180 do
  local sample=A.Sample(kind,(n/181)*clip.Duration)
  check(sample.Weight>=0 and sample.Weight<=1,kind..' boundedblend')
  for _,role in ipairs(A.Roles) do
   local a=A.Transform(sample,role,false);local b=A.Transform(sample,role,true)
   check(finiteCF(a) and finiteCF(b),kind..' finiteR6R15 '..role)
   local w=A.Weight(sample,role,true,false);local reduced=A.Weight(sample,role,true,true)
   check(w>=0 and w<=1 and reduced<=w,kind..' legreducedweight')
  end
 end
 for _,at in ipairs({.15,.35,.6}) do
  local sample=A.Sample(kind,at*clip.Duration)
  for _,role in ipairs({'root','rightArm','leftArm'}) do for _,v in ipairs({A.Transform(sample,role,false):GetComponents()}) do signature[#signature+1]=string.format('%.3f',v) end end
 end
 local sig=table.concat(signature,',');check(not signatures[sig],kind..' uniquepose');signatures[sig]=kind
end
check(A.Resolve('Swing',1)=='Swing','right hook')
local name,mirror=A.Resolve('Swing',2);check(name=='Swing' and mirror,'left hook')
check(A.Resolve('Swing',3)=='Hammer','overhand hammer')
local mirrored=A.Sample('Swing',.14,{Mirror=true});local original=A.Sample('Swing',.14)
check(mirrored.Pose.leftArm[1]==original.Pose.rightArm[1] and mirrored.Pose.leftArm[2]==-original.Pose.rightArm[2],'mirroredlimbs canonicalaxes')
for _,contact in ipairs({.04,.055,.09,.12}) do
 local sample=A.Sample('Swing',contact,{Contact=contact,Duration=.48})
 check(math.abs(sample.Pose.rightArm[1]-94)<1e-8,'contactatserverwindow '..contact)
end
local spin=A.Sample('Jester',.81)
local cf=A.Transform(spin,'root',false);check(cf.LookVector.Z<-.98,'fullturnendsfacingforward')
local reduced=A.Transform(A.Sample('Jester',.46),'root',false,true);check(reduced.LookVector.Z<-.95,'reducedmotionspinremoved')
for _,p in ipairs({owner,r15}) do
 reset(p)
 for _,joint in ipairs(p.Character:GetDescendants()) do
  if joint:IsA('Motor6D') then
   local info=A.JointInfo(joint);check(info~=nil,'R6R15role')
   local clone=joint:Clone();clone.ClassName='AnimationConstraint'
   local modern=A.JointInfo(clone);check(modern and modern.Role==info.Role,'modernjointsamepublicaliases')
   clone.Part1=nil;local a0=Instance.new('Attachment',joint.Part0);a0.CFrame=joint.C0;local a1=Instance.new('Attachment',joint.Part1)
   clone.Attachment0=a0;clone.Attachment1=a1
   check(A.JointInfo(clone).Role==info.Role,'modernattachmentfallback')
   a0:Destroy();a1:Destroy();clone:Destroy()
  end
 end
 exports.Pose(p,clock,'Swing',1)
 check(exports.Poses[p.Character]~=nil,'pose starts '..p.Name)
 tick(.055)
 local count=0;for _,j in ipairs(exports.Poses[p.Character].Joints) do if not nearCF(j.Object.Transform,CFrame.identity) then count+=1 end end
 check(count>=4,'wholebody action '..p.Name)
 local root=p.Character.HumanoidRootPart;local originalFrame=root.CFrame;local velocity=root.AssemblyLinearVelocity
 check(root.CFrame==originalFrame and root.AssemblyLinearVelocity==velocity,'actionphysicsuntouched')
 tick(.6);check(exports.Poses[p.Character]==nil,'actionexpires')
end
reset(owner)
exports.Pose(owner,clock,'Speed',7);check(exports.Poses[owner.Character].Name=='Speed','abilitypose')
exports.Pose(owner,clock,'Swing',8);check(exports.Poses[owner.Character].Name=='Swing','attackoverridesability')
exports.Pose(owner,clock,'Hit',9);check(exports.Poses[owner.Character].Name=='Hit','hitoverridesattack')
exports.Pose(owner,clock,'Speed',10);check(exports.Poses[owner.Character].Name=='Hit','abilitydoesnotstomp reaction')
tick(.06)
local pose=exports.Poses[owner.Character]
local j=pose.Joints[1];local before=j.Before
services.RunService.PreAnimation:Fire()
check(j.Object.Transform==before,'ownedtransformrestorebeforeanimator')
local fresh=CFrame.Angles(.13,.06,.02);j.Object.Transform=fresh
services.RunService.PreSimulation:Fire(1/60)
check(j.Before==fresh,'freshanimatorevaluationused')
local external=CFrame.Angles(.7,.2,.1);j.Object.Transform=external
exports.Clear(owner.Character)
check(j.Object.Transform==external,'cleanupdoesnotoverwriteotherposeowner')
reset(owner)
exports.Pose(owner,clock,'Swing',1);owner.Character:SetAttribute('HABWeavePoseStartedAt',clock);owner.Character:SetAttribute('HABWeavePoseUntil',clock+.72);tick(.03)
check(exports.Poses[owner.Character]==nil,'newweave cancelsoldpredictedaction')
reset(owner)
exports.Pose(owner,clock,'Swing',1);owner.Character:SetAttribute('MovementAction','DiveLeft');owner.Character:SetAttribute('MovementActionId',99);tick(.03)
check(exports.Poses[owner.Character]==nil,'predictedlocaldodge cancelsaction')
for _,name in ipairs({'Shield','Speed','Decoy','Jester','Bubble','Disco','Confetti'}) do
 reset(owner);exports.Pose(owner,clock,name,31)
 for _=1,6 do
  tick(.035)
  local p=exports.Poses[owner.Character];local current,neutral={},{}
  for _,joint in ipairs(p.Joints) do current[joint.Object]=joint.Object.Transform;neutral[joint.Object]=CFrame.identity end
  local baseline=A.FootHeight(p.Joints,p.Root,neutral,p.Feet)
  local posed=A.FootHeight(p.Joints,p.Root,current,p.Feet)
  check(math.abs(baseline-posed)<1e-6,name..' groundedfeetstayongaitplane')
 end
end
for _,state in ipairs({'Ragdolled','IsRagdoll'}) do reset(owner);exports.Pose(owner,clock,'Swing',1);owner.Character:SetAttribute(state,true);tick(.02);check(not exports.Poses[owner.Character],state..' yields') end
reset(owner);exports.Pose(owner,clock,'Swing',1);owner.Character.Humanoid.Health=0;tick(.02);check(not exports.Poses[owner.Character],'deathcleans')
reset(owner);exports.Pose(owner,clock,'Swing',1);owner.CharacterRemoving:Fire(owner.Character);check(not exports.Poses[owner.Character],'respawncleans')
reset(owner)
owner:SetAttribute('HABCollectionOpen',true);local beforeRequests=#requests;exports.Send('Swing');check(#requests==beforeRequests,'originalcollectionblocksinput')
owner:SetAttribute('HABCollectionOpen',false);exports.Send('Swing');check(#requests==beforeRequests+1,'swingrequest')
local request=requests[#requests].Packet;check(exports.Poses[owner.Character]~=nil,'predictionstarts')
X.FX.OnClientEvent:Fire({Kind='ActionReply',Action='Swing',Request=request.Seq,OK=false})
check(not exports.Poses[owner.Character],'rejectedpredictionrestored')
reset(owner);reset(observer)
X.FX.OnClientEvent:Fire({Kind='TagHit',Actor=owner,Target=observer,Time=clock,Id=1001,Position=observer.Character.HumanoidRootPart.Position})
check(exports.Poses[observer.Character] and exports.Poses[observer.Character].Name=='Hit','recipienthitreaction')
reset(observer)
X.FX.OnClientEvent:Fire({Kind='ShieldBlock',Actor=observer,Time=clock,Id=1002,Position=observer.Character.HumanoidRootPart.Position})
check(exports.Poses[observer.Character].Name=='Block','defenderblockpose')
check(not exports.Poses[owner.Character],'originalblockdoesnotinventattacker')
reset(owner);reset(observer)
local oldCharacter=Instance.new('Model')
exports.Born[owner.Character]=clock
X.FX.OnClientEvent:Fire({Kind='Swing',Actor=owner,Time=clock-.5,Id=1003})
check(not exports.Poses[owner.Character],'oldlifeactorpacketignoredwithoutnewserverfields')
exports.Born[owner.Character]=-math.huge;exports.Born[observer.Character]=clock
X.FX.OnClientEvent:Fire({Kind='TagHit',Actor=owner,Target=observer,Time=clock-.5,Id=1004})
check(not exports.Poses[observer.Character],'oldlifetargetpacketignoredwithoutnewserverfields')
exports.Born[observer.Character]=-math.huge
-- Later server-approved attacks must remain visible: the original server allows them mid-weave.
reset(owner)
owner.Character:SetAttribute('HABWeavePoseStartedAt',clock-.2);owner.Character:SetAttribute('HABWeavePoseUntil',clock+.52)
owner.Character:SetAttribute('MovementAction','DiveRight');owner.Character:SetAttribute('MovementActionId',345)
exports.Pose(owner,clock,'Swing',19)
check(not exports.Poses[owner.Character],'predictionyieldsweave')
X.FX.OnClientEvent:Fire({Kind='Swing',Actor=owner,Time=clock,Id=1010,Request=19,Duration=.48})
check(exports.Poses[owner.Character] and exports.Poses[owner.Character].Name=='Swing','originalapprovedswingvisiblemidweave')
check(owner.Character:GetAttribute('HABActionPoseStartedAt')==clock,'acceptancemarkerusesauthoritativetime')
tick(.06);check(exports.Poses[owner.Character]~=nil,'acceptedposepersistsagainstolderweave')
owner.Character:SetAttribute('HABWeavePoseStartedAt',nil);owner.Character:SetAttribute('HABWeavePoseUntil',nil)
tick(.02);check(exports.Poses[owner.Character]~=nil,'weavecancellationdoesnotrestartfallbackclock')
owner.Character:SetAttribute('HABWeavePoseStartedAt',clock);owner.Character:SetAttribute('HABWeavePoseUntil',clock+.72)
tick(.02);check(not exports.Poses[owner.Character],'newweaveinterruptsolderacceptedaction')
-- All nine original-server ability packets play; owner launch is never skipped by visual suppression.
local abilities={'Shield','Leap','Speed','Decoy','Jester','Bubble','Pogo','Disco','Confetti'}
for index,name in ipairs(abilities) do
 reset(owner)
 X.FX.OnClientEvent:Fire({Kind='Ability',Actor=owner,Character=owner.Character,Ability=name,Mechanic=name,Time=clock,Id=2000+index,Request=100+index,Duration=1,Until=clock+1})
 check(exports.Poses[owner.Character] and exports.Poses[owner.Character].Name==name,name..' originalserverabilitypacket')
end
reset(owner)
owner:SetAttribute('HussReducedMotion',true)
local c=owner.Character;local v=Vector3.new(13,0,-17);c.HumanoidRootPart.AssemblyLinearVelocity=v
X.FX.OnClientEvent:Fire({Kind='Ability',Actor=owner,Character=c,Ability='Leap',Mechanic='Leap',Time=clock,Id=3000,Request=121,LaunchOnClient=true,Velocity=72})
check(c.HumanoidRootPart.AssemblyLinearVelocity.X==13 and c.HumanoidRootPart.AssemblyLinearVelocity.Y==72 and c.HumanoidRootPart.AssemblyLinearVelocity.Z==-17,'originalownerlaunchpreserveshorizontalvelocity')
X.FX.OnClientEvent:Fire({Kind='Ability',Actor=owner,Character=c,Ability='Speed',Mechanic='Speed',Time=clock,Id=3001,Request=122,Until=clock+3,Bonus=6})
check(c:GetAttribute('HABSpeedBonus')==6 and c:GetAttribute('HABSpeedUntil')==clock+3,'originalapprovedspeedmodifier')
reset(owner);exports.Pose(owner,clock,'Swing',11);script.Destroying:Fire()
check(not exports.Poses[owner.Character] and owner.Character:GetAttribute('HABActionPoseUntil')==nil,'destroyrestoresposes')
check(not cas.Bound.HABAbility and not cas.Bound.HABThrow,'unbindsactions')
check(exports.Folder.Parent==nil,'localfolderdestroyed')
print('V16 actions: '..assertions..' assertions passed')
