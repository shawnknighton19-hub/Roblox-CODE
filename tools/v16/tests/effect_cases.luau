check(table.concat(catalog.Order,',')=='Aura,Trail,KillFX','only desired visual collections and audio stay visible')
for id,oldItem in pairs(originalCatalog.ById) do
 local item=catalog.ById[id]
 check(item~=nil,'every saved ID retained')
 check(item.Name==oldItem.Name and item.Category==oldItem.Category and item.SourceId==oldItem.SourceId,'art source/category/name retained')
 check(item.Tint==oldItem.Tint or (item.Tint and oldItem.Tint and item.Tint.R==oldItem.Tint.R and item.Tint.G==oldItem.Tint.G and item.Tint.B==oldItem.Tint.B),'bundle tint retained')
end
for category,oldCrate in pairs(originalCatalog.Crates) do
 check(catalog.Crates[category].Price==oldCrate.Price and #catalog.Crates[category].Items==#oldCrate.Items,'original price/item validation retained')
end
local root=owner.Character.HumanoidRootPart
local function particleCount()
 local count=0;for _,instance in ipairs(workspace:GetDescendants()) do if instance:IsA('ParticleEmitter') then count+=1 end end;return count
end
for _,id in ipairs({'JackOLanternBloom','combat_00094','FieryJackOLantern','ks_pop','unknown'}) do
 check(renderer.Play(id,root,4)==nil,'extra cosmetics cannot render: '..id)
end
for _,id in ipairs({'JackOLanternSwirl','JackOLanternWisp'}) do
 local before=particleCount();local h=renderer.Play(id,root,4)
 check(h~=nil and particleCount()>before,'original Aura/Trail PNG layer renders')
 h:Stop()
end
local count=#calls
check(renderer.Play('combat_00094',root,4,nil,true,0,true,{Ability=true})~=nil and #calls==count+1,'approved ability effect still renders')
check(renderer.Play('combat_00011',root,4,nil,true,0,true,{Ability=true})==nil,'unconfigured art cannot claim ability context')
local screen=Instance.new('ScreenGui',services.ReplicatedStorage);screen.Enabled=true
local function box() local f=Instance.new('Frame',screen);f.ZIndex=1;return f end
for _,id in ipairs({'JackOLanternSwirl','JackOLanternWisp'}) do
 local frame=box();local h=canvas.Mount(frame,id,8)
 check(h~=nil and #h.Sprites==1,'original preview available')
 check(h.Sprites[1].Image.Image=='rbxassetid://'..effects[id].colour,'exact original PNG preview texture')
 h:Stop();check(#frame:GetChildren()==0,'original preview cleanup')
end
local frame=box();check(canvas.Mount(frame,'JackOLanternBloom',8)==nil and #frame:GetChildren()==0,'removed preview creates nothing')
check(canvas.Mount(box(),'combat_00094',8)==nil,'Dodge cosmetic not previewed')
local abilityPreview=canvas.Mount(box(),'combat_00094',8,{Ability=true})
check(abilityPreview~=nil,'same art permitted in actual ability preview');abilityPreview:Stop()
check(canvas.Mount(box(),'ks_pop',8)~=nil,'sound preview retained')
savedState.Owned={JackOLanternBloom=true,combat_00094=true,JackOLanternSwirl=true,JackOLanternWisp=true,ks_pop=true}
savedState.StoredCrates={{Id='retired-stored',Category='BombFX',Mode='Random',Cost=40,At=1},{Id='kept-stored',Category='Aura',Mode='Random',Cost=40,At=2}}
local rows=model.Inventory(catalog,savedState,'All')
check(#rows==5,'two stored crates and three retained owned items shown')
local archived
for _,row in ipairs(rows) do
 if row.Kind=='Crate' and row.Category=='BombFX' then archived=row end
 if row.Kind=='Effect' then check(row.Category~='BombFX' and row.Category~='DodgeFX','removed owned effect hidden') end
end
check(archived and archived.RefundOnly and archived.Crate.Cost==40,'retired crate remains accessible for exact refund')
local crates,effectCount=model.Count(savedState)
check(crates==2 and effectCount==3,'inventory count matches retained items')
check(savedState.Owned.JackOLanternBloom and savedState.Owned.combat_00094,'projection never deletes ownership')
for _,category in ipairs({'BombFX','DodgeFX'}) do
 check(serviceGuard('BuyCrate',{Category=category}).OK==false,'direct removed purchase denied')
 check(serviceGuard('Equip',{Category=category,Item='some-id'}).OK==false,'direct removed equip denied')
 check(serviceGuard('Equip',{Category=category,Item=''})==nil,'old effect can be unequipped')
end
check(serviceGuard('OpenStored',{Crate='retired-stored'}).OK==false,'removed stored crate cannot reopen hidden visual')
check(serviceGuard('RefundStored',{Crate='retired-stored'})==nil,'existing saved refund path retained')
check(serviceGuard('BuyCrate',{Category='Aura'})==nil and serviceGuard('BuyCrate',{Category='KillFX'})==nil,'Aura and audio buying unchanged')
owner.Character:SetAttribute('HussBombCarrier',true)
local state={character=owner.Character,h=owner.Character.Humanoid,root=root,head=owner.Character.Head,player=owner,dodgeUntil=0}
check(not panicGuard(state,clock,clock),'panic runs for authoritative carrier')
owner.Character:SetAttribute('HABActionPoseUntil',clock+.4)
check(panicGuard(state,clock,clock),'panic yields to action pose')
owner.Character:SetAttribute('HABActionPoseUntil',nil);owner.Character:SetAttribute('HABWeavePoseUntil',clock+.4)
check(panicGuard(state,clock,clock),'panic yields to weave')
owner.Character:SetAttribute('HABWeavePoseUntil',clock-.01)
check(not panicGuard(state,clock,clock),'panic resumes after action recovery')
startAbilities()
local eventId=0
for _,definition in ipairs(config.Abilities) do
 eventId+=1;owner.Character:SetAttribute('HABShieldCharge',1)
 local before=#abilityCalls
 fx.OnClientEvent:Fire({Kind='Ability',Id=eventId,Time=clock,Actor=owner,Ability=definition.Key,Until=clock+(definition.Duration or 1)})
 check(#abilityCalls==before+1,'one accepted effect for '..definition.Key)
 check(abilityCalls[#abilityCalls][1]==definition.Effect and abilityCalls[#abilityCalls][8].Ability==true,'original ability art and explicit context')
 fx.OnClientEvent:Fire({Kind='Ability',Id=eventId,Time=clock,Actor=owner,Ability=definition.Key})
 check(#abilityCalls==before+1,'duplicate ability event ignored')
 if definition.Key=='Shield' then
  local shell=workspace.HABFunAbilityCosmetics:FindFirstChild('PhaseGuardCosmetic')
  check(shell and shell.Material==Enum.Material.ForceField,'original Shield shell exists')
  owner.Character:SetAttribute('HABShieldCharge',0);services.RunService.Heartbeat:Fire(.02)
  check(not shell.Parent,'shield charge consumption cleans shell')
 end
 clock+=4;services.RunService.Heartbeat:Fire(.05)
 check(#workspace.HABFunAbilityCosmetics:GetChildren()==0,'ability lifecycle clears geometry')
end
local before=#abilityCalls
fx.OnClientEvent:Fire({Kind='ShieldBlock',Time=clock,Actor=owner,Position=root.Position})
check(#abilityCalls==before+1 and abilityCalls[#abilityCalls][1]=='combat_00094','original ShieldBlock cue retained by one owner')
fx.OnClientEvent:Fire({Kind='ShieldBlock',Time=clock,Actor=owner,Position=root.Position})
check(#abilityCalls==before+1,'original no-Id ShieldBlock packet deduplicates')
clock+=1;services.RunService.Heartbeat:Fire(.05)
local oldCharacter=Instance.new('Model',workspace)
fx.OnClientEvent:Fire({Kind='Ability',Id=110,Time=clock,Actor=owner,Character=oldCharacter,Ability='Shield'})
check(#abilityCalls==before+1,'stale respawn ability packet discarded')
owner.Character:SetAttribute('HABShieldCharge',0)
fx.OnClientEvent:Fire({Kind='Ability',Id=111,Time=clock,Actor=owner,Character=owner.Character,Ability='Shield',Until=clock+1})
local waitingShell=workspace.HABFunAbilityCosmetics:FindFirstChild('PhaseGuardCosmetic')
clock+=.1;services.RunService.Heartbeat:Fire(.05)
check(waitingShell and waitingShell.Parent,'shield survives brief attribute replication delay')
owner.Character:SetAttribute('HABShieldCharge',1);services.RunService.Heartbeat:Fire(.02)
owner.Character:SetAttribute('HABShieldCharge',0);services.RunService.Heartbeat:Fire(.02)
check(not waitingShell.Parent,'acknowledged shield charge removal cleans shell')
before=#abilityCalls-1
owner:SetAttribute('HussReducedMotion',true)
fx.OnClientEvent:Fire({Kind='Ability',Id=100,Time=clock,Actor=owner,Ability='Disco'})
check(#abilityCalls==before+1,'Reduced Motion suppresses ability cosmetics')
owner:SetAttribute('HussReducedMotion',false)
fx.OnClientEvent:Fire({Kind='Ability',Id=101,Time=clock-3,Actor=owner,Ability='Disco'})
check(#abilityCalls==before+1,'stale ability event discarded')
script.Destroying:Fire()
check(not workspace:FindFirstChild('HABFunAbilityCosmetics'),'ability listener teardown cleans folder')
print('V16_EFFECT_ASSERTIONS='..checks)
