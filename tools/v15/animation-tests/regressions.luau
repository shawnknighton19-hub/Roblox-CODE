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
local panic=panicExports.states[owner.Character]
check(panic and panicExports.blocked(panic,clock,clock),'panic yields action marker')
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
exports.Pose(owner,clock,'Swing',1);owner.Character:SetAttribute('HussDodgeStartedAt',clock);tick(.03)
check(exports.Poses[owner.Character]==nil,'serverdodge cancelsaction')
reset(owner)
exports.Pose(owner,clock,'Swing',1);owner.Character:SetAttribute('MovementAction','DiveLeft');owner.Character:SetAttribute('MovementActionId',99);tick(.03)
check(exports.Poses[owner.Character]==nil,'predictedlocaldodge cancelsaction')
for _,state in ipairs({'Ragdolled','IsRagdoll'}) do reset(owner);exports.Pose(owner,clock,'Swing',1);owner.Character:SetAttribute(state,true);tick(.02);check(not exports.Poses[owner.Character],state..' yields') end
reset(owner);exports.Pose(owner,clock,'Swing',1);owner.Character.Humanoid.Health=0;tick(.02);check(not exports.Poses[owner.Character],'deathcleans')
reset(owner);exports.Pose(owner,clock,'Swing',1);owner.CharacterRemoving:Fire(owner.Character);check(not exports.Poses[owner.Character],'respawncleans')
reset(owner)
owner:SetAttribute('HABModalOwnerV15','SHOP');local beforeRequests=#requests;exports.Send('Swing');check(#requests==beforeRequests,'modalblocksinput')
owner:SetAttribute('HABModalOwnerV15',nil);exports.Send('Swing');check(#requests==beforeRequests+1,'swingrequest')
local request=requests[#requests].Packet;check(exports.Poses[owner.Character]~=nil,'predictionstarts')
X.FX.OnClientEvent:Fire({Kind='ActionReply',Action='Swing',Request=request.Seq,OK=false})
check(not exports.Poses[owner.Character],'rejectedpredictionrestored')
reset(owner);reset(observer)
X.FX.OnClientEvent:Fire({Kind='TagHit',Actor=owner,Character=owner.Character,Target=observer,TargetCharacter=observer.Character,Time=clock,Id=1001,Position=observer.Character.HumanoidRootPart.Position})
check(exports.Poses[observer.Character] and exports.Poses[observer.Character].Name=='Hit','recipienthitreaction')
reset(observer)
X.FX.OnClientEvent:Fire({Kind='ShieldBlock',Actor=observer,Character=observer.Character,Target=observer,TargetCharacter=observer.Character,Attacker=owner,Time=clock,Id=1002,Position=observer.Character.HumanoidRootPart.Position})
check(exports.Poses[observer.Character].Name=='Block','defenderblockpose')
check(exports.Poses[owner.Character].Name=='Hit','attackerrecoil')
reset(owner);reset(observer)
local oldCharacter=Instance.new('Model')
X.FX.OnClientEvent:Fire({Kind='Swing',Actor=owner,Character=oldCharacter,Time=clock,Id=1003})
check(not exports.Poses[owner.Character],'oldlifeactoreventignored')
X.FX.OnClientEvent:Fire({Kind='TagHit',Actor=owner,Character=owner.Character,Target=observer,TargetCharacter=oldCharacter,Time=clock,Id=1004})
check(not exports.Poses[observer.Character],'oldlifetargeteventignored')
X.FX.OnClientEvent:Fire({Kind='ShieldBlock',Actor=observer,Character=observer.Character,Target=observer,TargetCharacter=observer.Character,Attacker=owner,AttackerCharacter=oldCharacter,Time=clock,Id=1005})
check(not exports.Poses[owner.Character],'oldlifeattackerrecoilignored')
-- Native effects use actual production constructors and every per-frame branch.
exports.Effects:Destroy()
local effectFolder=Instance.new('Folder',workspace)
local effect=NativeFX.new(effectFolder,owner,false)
local abilities={'Shield','Leap','Speed','Decoy','Jester','Bubble','Pogo','Disco','Confetti'}
owner.Character:SetAttribute('HABShieldCharge',nil)
effect:Ability({Ability='Shield',Time=clock,Duration=1},owner.Character.HumanoidRootPart)
effect:Step(clock+.1);check(effect.Parts>0,'shieldreplicationgrace')
owner.Character:SetAttribute('HABShieldCharge',1);effect:Step(clock+.12);check(effect.Parts>0,'shieldchargearrives')
owner.Character:SetAttribute('HABShieldCharge',0);effect:Step(clock+.14);check(effect.Parts==0,'consumedshieldclears')
for _,kind in ipairs(abilities) do
 owner.Character:SetAttribute('HABShieldCharge',1)
 effect:Ability({Ability=kind,Time=clock,Duration=1},owner.Character.HumanoidRootPart)
 check(effect.Parts>0,kind..' visualfeedback')
 local instances=nextID
 for frame=1,25 do effect:Step(clock+frame*.016) end
 check(nextID==instances,kind..' zero perframeallocations')
 for _,part in ipairs(effectFolder:GetChildren()) do
  check(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch and not part.CastShadow,kind..' effectcannotaffectphysics')
  check(finiteCF(part.CFrame) and part.Transparency>=0 and part.Transparency<=1,kind..' finitevisual')
  for _,child in ipairs(part:GetDescendants()) do check(child:IsA('SpecialMesh'),kind..' decoychildrenstripped') end
 end
 effect:Step(clock+3);check(effect.Parts==0 and #effect.Groups==0,kind..' expires')
end
for _=1,20 do effect:Ability({Ability='Disco',Time=clock,Duration=2.4},owner.Character.HumanoidRootPart) end
check(#effect.Groups<=effect.MaxGroups and effect.Parts<=effect.MaxParts,'boundeddecoygroupsandparts')
owner:SetAttribute('HussReducedMotion',true);effect:Step(clock+.01);check(effect.Parts==0,'reducedmotioncleans')
effect:Ability({Ability='Speed',Time=clock},owner.Character.HumanoidRootPart);check(effect.Parts==0,'reducedmotionavoidsnewfx')
owner:SetAttribute('HussReducedMotion',false)
effect:Swing(owner.Character.HumanoidRootPart,clock,false);effect:Impact('Hit',owner.Character.HumanoidRootPart,Vector3.zero,clock);effect:Step(clock+.08)
check(effect.Parts>0,'nativecontactcues');effect:Destroy();check(effect.Parts==0 and #effect.Groups==0,'effectsdestruction')
reset(owner);exports.Pose(owner,clock,'Swing',11);script.Destroying:Fire()
check(not exports.Poses[owner.Character] and owner.Character:GetAttribute('HABActionPoseUntil')==nil,'destroyrestoresposes')
check(not cas.Bound.HABAbility and not cas.Bound.HABThrow,'unbindsactions')
check(exports.Folder.Parent==nil,'localfolderdestroyed')
print('V15 actions: '..assertions..' assertions passed')
