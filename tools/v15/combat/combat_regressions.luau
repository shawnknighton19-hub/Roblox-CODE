-- Geometry: moving targets, zero travel, tangent, invalid inputs and turn limits.
near(Rules.MovingSphere(V(0,0,0),V(0,0,-10),V(0,0,-5),V(0,0,-5),1),.4,'earliest sphere contact')
check(Rules.MovingSphere(V(0,0,0),V(0,0,-6),V(4,0,-3),V(-4,0,-3),.4)~=nil,'runner crossing projectile')
check(Rules.MovingSphere(V(0,0,0),V(0,0,-6),V(4,0,-3),V(4,0,-3),.4)==nil,'parallel miss')
near(Rules.MovingSphere(V(0,0,0),V(0,0,0),V(0,0,0),V(0,0,0),1),0,'initial overlap')
check(Rules.MovingSphere(V(0,0,0),V(0,0,0),V(4,0,0),V(4,0,0),1)==nil,'stationary miss')
check(Rules.MovingSphere(V(0,0,0),V(0,0,-10),V(1,0,-5),V(1,0,-5),1)~=nil,'tangent is contact')
check(Rules.MovingSphere(V(0/0,0,0),V(0,0,0),V(0,0,0),V(0,0,0),1)==nil,'NaN rejected')
check(Rules.MovingSphere(V(0,0,0),V(0,0,0),V(0,0,0),V(0,0,0),100)==nil,'oversized radius rejected')
local turn=Rules.Turn(V(0,0,-1),V(1,0,0),math.rad(30))
near(turn.X,.5,'turn direction');near(turn.Z,-math.sqrt(3)/2,'turn clamp')
check(Rules.Swing(V(0,0,0),V(0,0,3),V(0,0,-1),Config.Swing)==nil,'behind attacker rejected')
check(Rules.Swing(V(0,0,0),V(0,9,-3),V(0,0,-1),Config.Swing)==nil,'floor above rejected')

do
 local e=scenario();e:tick();e:request('Swing')
 local start=e:last('Swing');check(start and start.Character==e.ac,'accepted swing has character')
 near(start.Windup,Config.Swing.Windup);near(start.ContactAt,e.now+Config.Swing.Windup)
 e:time(.03);check(e:tick()==nil,'windup cannot hit')
 e:time(.03);check(e:tick()==e.b,'valid hit at active window')
 local hit=e:last('TagHit');check(hit.Target==e.b and hit.TargetCharacter==e.bc and hit.AttackKind=='Swing','hit animation contract')
 check(e:tick()==nil and e:count('TagHit')==1,'one transfer per swing')
 e:request('Swing');check(e:last('ActionReply').OK==false,'cooldown rejects immediate duplicate')
end
for _,restriction in ipairs({'noncarrier','afk','paused','anchored','seated','ragdoll','dead','fuse'}) do
 local e=scenario()
 if restriction=='noncarrier' then e.service.SetCarrier(e.b,e.now+30,e.now,nil,0)
 elseif restriction=='afk' then e.a:SetAttribute('BombTagAFK',true)
 elseif restriction=='paused' then e.workspace:SetAttribute('HussGamePaused',true)
 elseif restriction=='anchored' then e.ar.Anchored=true
 elseif restriction=='seated' then e.ah.Sit=true
 elseif restriction=='ragdoll' then e.ac:SetAttribute('Ragdolled',true)
 elseif restriction=='dead' then e.ah.Health=0
 elseif restriction=='fuse' then e.service.SetCarrier(e.a,e.now,e.now,nil,0) end
 e:request('Swing');check(e:last('ActionReply').OK==false and e:count('Swing')==0,'reject '..restriction)
end
do
 local e=scenario();e.wallZ=-2;e:tick();e:request('Swing');e:time(.07)
 check(e:tick()==nil,'wall blocks melee');check(e:count('TagHit')==0,'wall emits no hit')
end
do
 local e=scenario();e.service.SetCarrier(e.a,e.now+30,e.now,e.b.UserId,e.now+1)
 e:request('Swing');e:time(.07);check(e:tick()==nil,'antitagback enforced')
end
do
 local e=scenario();local c=e:actor(3,V(0,3,-5));e:tick();e:request('Swing');e:time(.07)
 check(e:tick()==e.b,'equal candidates choose stable lower UserId')
end
do
 local e=scenario();e:position(e.br,V(3.4,3,-.5));e:tick();e:request('Swing');e:time(.06);e:tick()
 e:position(e.br,V(-3.4,3,-.5));e:time(.04)
 check(e:tick()==e.b,'swept contact catches crossing between outside endpoints')
end
do
 local e=scenario();e:position(e.br,V(0,3,-11));e:tick();e:request('Swing')
 e:time(.26);e:position(e.br,V(0,3,-9));e:tick()
 e:time(.05);e:position(e.br,V(0,3,-5))
 check(e:tick()==e.b,'last active interval survives tick crossing recovery')
end
do
 local e=scenario();e:position(e.br,V(0,3,-11));e:tick();e:request('Swing')
 e:time(.26);e:position(e.br,V(0,3,-10));e:tick()
 e:time(.05);e:position(e.br,V(0,3,-6))
 check(e:tick()==nil,'target enters only after active window; no late hit')
 check(e:last('SwingEnd').Result=='MISS','clipped miss ends attack')
end
do
 local e=scenario();e:request('Swing');e:time(.40)
 check(e:tick()==nil,'stale final sample discarded')
end
do
 local e=scenario();e.service.SetCarrier(e.a,e.now+30,e.now+.1,nil,0);e:request('Swing')
 check(e:count('Swing')==0,'input during final arming recovery is queued')
 e:time(.11);check(e:tick()==nil and e:count('Swing')==1,'queued swing starts at server unlock')
 e:time(.06);check(e:tick()==e.b,'queued swing gets normal contact window')
end
do
 local e=scenario();local bot,root=e:actor(-1,V(0,3,2),true)
 e.service.SetCarrier(bot,e.now+30,e.now,nil,0)
 check(e.service.Tick({bot,e.a,e.b},e.now)==nil,'practice bot starts authored attack')
 e:time(.07);check(e.service.Tick({bot,e.a,e.b},e.now)==e.a,'practice bot uses same authorized contact')
 check(e:last('TagHit').Actor==bot.Character,'bot animation actor is character')
end
do
 local e=scenario();e.bc:SetAttribute('HABShieldUntil',e.now+1);e.bc:SetAttribute('HABShieldCharge',1)
 e:request('Swing');e:time(.07);check(e:tick()==nil,'shield blocks transfer')
 check(e.bc:GetAttribute('HABShieldCharge')==0,'one shield charge consumed')
 local block=e:last('ShieldBlock');check(block.Actor==e.b and block.Target==e.b and block.Attacker==e.a and block.AttackerCharacter==e.ac and block.AttackKind=='Swing','parry animation contract')
 check(e:last('SwingEnd').Result=='BLOCKED','blocked attack ends')
end
do
 local e=scenario();e.bc:SetAttribute('BombTagIFrameUntil',e.now+1)
 e:request('Swing');e:time(.07);check(e:tick()==nil,'iframe prevents transfer');e:time(.03);e:tick()
 check(e.perfect==1,'perfect weave requested once per attack')
end
do
 local e=scenario();e:request('Throw');check(e:last('ActionReply').OK==false,'throw requires server pass')
 e.passes.Throw=true;e:request('Throw',nil,2,V(0,0,1));check(e:last('ActionReply').OK==false,'backwards throw rejected')
 e:request('Throw',nil,3,V(0/0,0,0));check(e:last('ActionReply').OK==false,'nonfinite throw rejected')
 e:request('Throw',nil,4);check(e:last('ActionReply').OK==true,'owned throw accepted')
 e:time(.05);check(e:tick()==e.b,'throw transfers once');check(e:last('TagHit').AttackKind=='Throw','throw contact animation type')
 check(e:tick()==nil,'throw cannot transfer twice')
end
do
 local e=scenario();e.passes.Throw=true;e:position(e.br,V(3.2,3.5,-3.4));e:tick();e:request('Throw')
 e:position(e.br,V(-3.2,3.5,-3.4));e:time(.05)
 check(e:tick()==e.b,'throw hits crossing runner whose endpoints miss projectile')
end
do
 local e=scenario();e.passes.Throw=true;e.wallZ=-2;e:request('Throw');e:time(.05)
 check(e:tick()==nil and e:last('ThrowEnd')~=nil,'wall terminates throw')
end
do
 local e=scenario();e.passes.Throw=true;e.wallZ=-8;e:position(e.br,V(0,3,-5));e.bc:SetAttribute('BombTagIFrameUntil',e.now+1)
 e:request('Throw');e:time(.1);check(e:tick()==nil,'throw dodged before wall')
 check(e:last('ThrowEnd')~=nil,'same-tick wall still ends dodged projectile')
 e.wallZ=nil;e.bc:SetAttribute('BombTagIFrameUntil',0);e:time(.05);check(e:tick()==nil,'projectile cannot resume beyond wall')
end
do
 local e=scenario();e.passes.Throw=true;e:request('Throw');e:time(.2)
 check(e:tick()==nil and e:last('ThrowEnd').Result=='CANCELLED','suspended server frame cancels stale projectile')
end
-- Every currently shipped ability retains its ownership gate and cooldown.
check(#Config.Abilities==9,'fixture contains nine current abilities')
for _,ability in ipairs(Config.Abilities) do
 local e=scenario();e.selected=ability.Key
 if ability.Key=='Shield' then e.service.SetCarrier(e.b,e.now+30,e.now,nil,0) end
 e:request('Ability');local reply=e:last('ActionReply');local event=e:last('Ability')
 check(reply.OK==true and event.Ability==ability.Key,'accepted '..ability.Key)
 near(reply.ReadyAt,e.now+ability.Cooldown,'unchanged ability cooldown '..ability.Key)
 check(event.Character==e.ac and event.Mechanic==(ability.Mechanic or ability.Key),'animation mechanic '..ability.Key)
 if (ability.Mechanic or ability.Key)=='Speed' then
  near(e.ac:GetAttribute('HABSpeedBonus'),ability.Bonus);near(e.ac:GetAttribute('HABSpeedUntil'),e.now+ability.Duration)
 elseif (ability.Mechanic or ability.Key)=='Leap' then
  check(event.LaunchOnClient==true,'client owner launch only after approval');near(event.Velocity,ability.Velocity)
 elseif ability.Key=='Shield' then check(e.ac:GetAttribute('HABShieldCharge')==1,'shield armed') end
 e:request('Ability',nil,2);check(e:last('ActionReply').OK==false,'ability cooldown '..ability.Key)
 local locked=scenario();locked.selected=ability.Key;locked.owned=false;locked:request('Ability')
 check(locked:last('ActionReply').OK==false and locked:count('Ability')==0,'ability ownership '..ability.Key)
end
do
 local e=scenario();e.selected='Shield';e:request('Ability');check(e:last('ActionReply').OK==false,'carrier cannot shield')
end
for _,state in ipairs({'air','ceiling','falling'}) do
 local e=scenario();e.selected='Leap'
 if state=='air' then e.ground=false elseif state=='ceiling' then e.ceilingY=5 else e.ar.AssemblyLinearVelocity=V(0,-30,0) end
 e:request('Ability');check(e:last('ActionReply').OK==false and e:count('Ability')==0,'leap rejects '..state)
 check((e.a:GetAttribute('HABAbilityReadyAt') or 0)==0,'rejection spends no cooldown')
end
for _,state in ipairs({'server','failed-owner-query'}) do
 local e=scenario();e.selected='Pogo';e.serverOwned=state=='server';e.ownerError=state=='failed-owner-query'
 e:request('Ability');check(e:last('Ability').LaunchOnClient==false,'safe launch routing '..state)
 near(e.ar.AssemblyLinearVelocity.Y,52,'server launch '..state)
end
do
 local e=scenario();e:request('Swing');e:request('Ability',nil,2)
 check(e:last('ActionReply').OK==false and e:count('Ability')==0,'ability waits for bomb action')
 check((e.a:GetAttribute('HABAbilityReadyAt') or 0)==0,'busy reject does not consume ability')
end
do
 local e=scenario();e.ac:SetAttribute('HussDodgeStartedAt',e.now);e:request('Swing')
 check(e:last('ActionReply').OK==false,'server dodge recovery blocks swing')
 e:request('Ability',nil,2);check(e:last('ActionReply').OK==false,'server dodge recovery blocks ability')
 e:time(.40);e:request('Swing',nil,3);check(e:last('ActionReply').OK==false,'mid-weave cannot land invisible strike')
 e.passes.Throw=true;e:request('Throw',nil,4);check(e:last('ActionReply').OK==false,'mid-weave cannot throw without release animation')
 e:time(.33);e:request('Ability',nil,5);check(e:last('ActionReply').OK==true,'recovery expires')
end
-- Validate original dodge script itself stamps only server-approved requests.
do
 local e=scenario();evaluate(dodgeSource,e.env)
 e.dodge.OnServerEvent:Fire(e.a,V(0,0,-1),'DiveForward')
 near(e.ac:GetAttribute('HussDodgeStartedAt'),e.now,'validated dodge recorded server-side')
 near(e.a:GetAttribute('HABSwingUnlockAt'),e.now+.72,'client receives actual attack unlock')
 near(e.ac:GetAttribute('BombTagIFrameUntil'),e.now+.45,'original iframe duration')
 e:time(.2);e.dodge.OnServerEvent:Fire(e.a,V(0,0,-1),'DiveForward')
 near(e.ac:GetAttribute('HussDodgeStartedAt'),e.now-.2,'rejected cooldown does not refresh stamp')
 e:time(1.2);e.ac:SetAttribute('HussBombCarrier',true);e.dodge.OnServerEvent:Fire(e.a,V(0,0,-1),'DiveForward')
 near(e.ac:GetAttribute('HussDodgeStartedAt'),e.now,'carrier dodge still stamped');near(e.ac:GetAttribute('BombTagIFrameUntil'),0,'carrier never immune')
 e:time(1.4);e.ah.Sit=true;e.dodge.OnServerEvent:Fire(e.a,V(0,0,-1),'DiveForward')
 near(e.ac:GetAttribute('HussDodgeStartedAt'),e.now-1.4,'seated dodge rejected')
 e.ah.Sit=false;e.dodge.OnServerEvent:Fire(e.a,V(0/0,0,0),'DiveForward')
 near(e.ac:GetAttribute('HussDodgeStartedAt'),e.now-1.4,'invalid direction cannot mint timestamp')
end
-- Execute the production carrier lifecycle helpers, with no visual constructors.
do
 local source=assert(bombSource:match('(local CARRIER_SPEED_BONUS.-)local BombService = {}'))
 local env={};local api=evaluate(source..'\nreturn {Set=updateCarrierStatus,Clear=clearCarrierStatus}',env)
 local e=scenario();api.Set(e.a)
 near(e.ac:GetAttribute('HABCarrierSpeedBonus'),3,'carrier +3');check(e.ac:GetAttribute('HussBombCarrier')==true,'carrier marked')
 api.Set(e.b);near(e.ac:GetAttribute('HABCarrierSpeedBonus'),0,'old carrier cleared');near(e.bc:GetAttribute('HABCarrierSpeedBonus'),3,'new carrier bonus')
 e.ah.Died:Fire();near(e.bc:GetAttribute('HABCarrierSpeedBonus'),3,'old carrier death cannot clear current carrier')
 e.bh.Died:Fire();near(e.bc:GetAttribute('HABCarrierSpeedBonus'),0,'death clears speed')
 api.Set(e.a);e.ac.AncestryChanged:Fire(e.ac,nil);near(e.ac:GetAttribute('HABCarrierSpeedBonus'),0,'removal clears speed')
 api.Set(e.a);api.Clear();near(e.ac:GetAttribute('HABCarrierSprintBonus'),0,'legacy speed attribute cleared too')
end
-- Exercise the actual speed helper in both walking/sprint states; no motor mock.
do
 local source=assert(movementSource:match('(local function boostedSpeed.-)local function cameraOwnsFacing'))
 local e=scenario();local speed=evaluate(source..'\nreturn boostedSpeed',{player=e.a,character=e.ac,workspace=e.workspace,SPRINT_SPEED=32})
 near(speed(24),24);near(speed(32),32)
 e.ac:SetAttribute('HussBombCarrier',true);e.ac:SetAttribute('HABCarrierSpeedBonus',3)
 near(speed(24),27,'walking carrier');near(speed(32),35,'sprint carrier')
 e.ac:SetAttribute('HABCarrierSpeedBonus',100);near(speed(32),35,'bounded carrier bonus')
 e.ac:SetAttribute('HABSpeedBonus',6);e.ac:SetAttribute('HABSpeedUntil',e.now+3)
 near(speed(32),41,'existing ability stack')
 e.ac:SetAttribute('HussPerfectBoostUntil',e.now+1);near(speed(32),47,'existing total cap')
 e:time(4);near(speed(32),35,'temporary boosts expire')
 e.a:SetAttribute('InRound',false);near(speed(24),24,'lobby ignores all combat bonuses')
 check(movementSource:find('local DIVE_MAX_START_SPEED = 84',1,true)~=nil,'dodge cap preserved')
 check(movementSource:find('local DIVE_COOLDOWN = 1.5',1,true)~=nil,'dodge cooldown preserved')
 check(practiceSource:find('local speed=(bot.speed or 24)+boost+math.clamp(carrierBonus,0,3)',1,true)~=nil,'practice movement same modest carrier bonus')
end
print('COMBAT_ASSERTIONS='..checks)
