
local function root(p) return p.Character:FindFirstChild('HumanoidRootPart') end
local function health(p) return p.Character:FindFirstChildOfClass('Humanoid') end
local function setup(positions)
 local s=fresh()
 s.cfg.BombTagRadius=5;s.cfg.TagCheckInterval=.03;s.cfg.NewCarrierLockSeconds=.18;s.cfg.AntiTagBackSeconds=1.15
 for i,p in ipairs(positions) do local actor=player(i,p);table.insert(s.players,actor) end
 local b=s:loadBomb()
 local function alive()
  local list={};for _,p in ipairs(s.players) do if p.Parent and p:GetAttribute('InRound')==true and health(p).Health>0 then table.insert(list,p) end end;return list
 end
 return s,b,alive
end
local function transfer(s) for _,e in ipairs(s.events) do if e[1]=='BombState' and e[2].Event=='Transferred' then return e[2] end end end
local function clearAttributes(s,label)
 for _,p in ipairs(s.players) do check(p.Character:GetAttribute('HussBombCarrier')~=true,label) end
end
-- The closest contact wins independently of candidate enumeration.
for _,reversed in ipairs({false,true}) do
 local s,b,alive=setup({0,4.8,1.5})
 if reversed then s.players[2],s.players[3]=s.players[3],s.players[2] end
 b.RunBombCycle(alive,.22)
 eq(transfer(s).CarrierUserId,3,'nearest eligible recipient ignores provider order')
 eq(s:count('Pass'),1,'one contact resolves once')
 eq(s:first('Elimination')[2].UserId,1,'last passer remains kill attribution')
 eq(s:first('Elimination')[3].UserId,3,'explosion attributed to selected actual carrier')
 eq(b.GetCarrier(),nil,'fuse clears carrier status')
 clearAttributes(s,'fuse clears all panic markers')
 for _,e in ipairs(s.events) do if e[1]=='BombState' and e[2].Active then eq(e[2].EndTime,.22,'transfer never resets fuse') end end
end
-- Equal contacts have deterministic UserId ordering (including bot negative IDs).
for _,reversed in ipairs({false,true}) do
 local s,b,alive=setup({0,2,-2});s.players[2].UserId=22;s.players[3].UserId=-3
 if reversed then s.players[2],s.players[3]=s.players[3],s.players[2] end
 b.RunBombCycle(alive,.22);eq(transfer(s).CarrierUserId,-3,'equal contacts use stable ID tie break')
end
-- Walls block direct and swept contacts; all actors excluded from collision ray.
do local s,b,alive=setup({0,3})
 s.ray=function(a,delta,p)
  eq(p.RespectCanCollide,true,'ray respects physical walls rather than decorative effects')
  eq(#p.FilterDescendantsInstances,2,'ray excludes both actors')
  return {Instance={}}
 end
 b.RunBombCycle(alive,.24);eq(s:count('Pass'),0,'solid divider blocks passing')
end
-- A wall-blocked nearest target must not hide another reachable target.
do local s,b,alive=setup({0,1,4})
 s.ray=function(a,delta) if delta.X>0 and delta.X<2 then return {} end end
 b.RunBombCycle(alive,.22);eq(transfer(s).CarrierUserId,3,'unreachable contact does not starve reachable target')
end
-- Crossing between samples at valid sprint/dodge speeds is detected.
do local s,b,alive=setup({0,12})
 s.cfg.NewCarrierLockSeconds=0;s.cfg.TagCheckInterval=.10
 s.wait=function() if s.now==.10 then root(s.players[1]).Position=vec(8,0,0);root(s.players[2]).Position=vec(1,0,0) end end
 b.RunBombCycle(alive,.15);eq(s:count('Pass'),1,'coherent high-speed crossing transfers')
end
-- A teleport path, stale tick, or replaced character cannot create a historical tag.
do local s,b,alive=setup({0,30});s.cfg.NewCarrierLockSeconds=0
 s.wait=function() if s.now==.03 then root(s.players[1]).Position=vec(60,0,0) end end
 b.RunBombCycle(alive,.07);eq(s:count('Pass'),0,'teleport crossing rejected')
end
do local s,b,alive=setup({0,12});s.cfg.NewCarrierLockSeconds=0;s.cfg.TagCheckInterval=.2
 s.wait=function() if s.now==.2 then root(s.players[1]).Position=vec(8,0,0);root(s.players[2]).Position=vec(1,0,0) end end
 b.RunBombCycle(alive,.25);eq(s:count('Pass'),0,'server-stall path rejected')
end
do local s,b,alive=setup({0,12});s.cfg.NewCarrierLockSeconds=0;s.cfg.TagCheckInterval=.1
 s.wait=function() if s.now==.1 then s.players[2]:LoadCharacter();root(s.players[1]).Position=vec(8,0,0);root(s.players[2]).Position=vec(1,0,0) end end
 b.RunBombCycle(alive,.15);eq(s:count('Pass'),0,'old character sample cannot sweep replacement')
end
-- Interpolation cannot pass through geometry even if the final sight line is clear.
do local s,b,alive=setup({0,12});s.cfg.NewCarrierLockSeconds=0;s.cfg.TagCheckInterval=.1
 s.wait=function() if s.now==.1 then root(s.players[1]).Position=vec(8,0,0);root(s.players[2]).Position=vec(1,0,0) end end
 s.ray=function(a,d) if a.X==0 and d.X==8 then return {} end end
 b.RunBombCycle(alive,.15);eq(s:count('Pass'),0,'wall-crossing swept motion rejected')
end
-- New carrier lock and tag-back protection remain unchanged.
do local s,b,alive=setup({0,1});b.RunBombCycle(alive,.17);eq(s:count('Pass'),0,'initial .18 second lock remains') end
do local s,b,alive=setup({0,1});b.RunBombCycle(alive,1.2);eq(s:count('Pass'),1,'1.15 second anti-tagback remains') end
do local s,b,alive=setup({0,1});b.RunBombCycle(alive,1.45);eq(s:count('Pass'),2,'tagback eventually becomes eligible') end
-- I-frames protect a target and still request one server perfect-weave decision.
do local s,b,alive=setup({0,2});s.players[2].Character:SetAttribute('BombTagIFrameUntil',10)
 b.RunBombCycle(alive,.24);eq(s:count('Pass'),0,'dodge immunity preserved');check(s:count('PerfectTry')>0,'perfect weave hook preserved')
end
do local s,b,alive=setup({0,2});s.players[2].Character:SetAttribute('BombTagIFrameUntil',10);s.ray=function() return {} end
 b.RunBombCycle(alive,.24);eq(s:count('PerfectTry'),0,'no perfect weave awarded through walls')
end
-- A sweep performed while immune does not become a retroactive pass after immunity ends.
do local s,b,alive=setup({0,12});s.cfg.NewCarrierLockSeconds=0;s.cfg.TagCheckInterval=.1
 s.players[2].Character:SetAttribute('BombTagIFrameUntil',.09)
 s.wait=function() if s.now==.1 then root(s.players[1]).Position=vec(8,0,0);root(s.players[2]).Position=vec(1,0,0) end end
 b.RunBombCycle(alive,.15);eq(s:count('Pass'),0,'expired iframe does not expose its historical path')
end
-- Stop after the last yield cancels even when the provider still contains actors.
do local s,b,alive=setup({0,40});s.wait=function() b.Stop() end
 b.RunBombCycle(alive,.03);eq(s:count('Elimination'),0,'explicit stop never explodes old carrier')
 for _,p in ipairs(s.players) do eq(health(p).Health,100,'stop preserves health') end
 clearAttributes(s,'stop clears panic marker')
end
-- Character death and removal clear the authoritative marker immediately.
for _,removal in ipairs({false,true}) do
 local s,b,alive=setup({0,40,80});local once=false
 s.wait=function()
  if not once then
   once=true;local p=s.players[1]
   check(p.Character:GetAttribute('HussBombCarrier')==true,'first carrier marked before interruption')
   if removal then p.Character.AncestryChanged:Fire(p.Character,nil) else health(p).Health=0;health(p).Died:Fire() end
   eq(p.Character:GetAttribute('HussBombCarrier'),false,'death/removal clears marker synchronously')
   eq(b.GetCarrier(),nil,'death/removal clears exposed carrier synchronously')
   b.Stop()
  end
 end
 b.RunBombCycle(alive,.1)
end
-- Assignment transfers the marker from the old character to the current one.
do local s,b,alive=setup({0,1});local observed=false
 s.wait=function() if transfer(s) then observed=true;eq(s.players[1].Character:GetAttribute('HussBombCarrier'),false,'old carrier marker removed');eq(s.players[2].Character:GetAttribute('HussBombCarrier'),true,'new carrier marker assigned') end end
 b.RunBombCycle(alive,.22);check(observed,'observed active transfer before explosion')
end
-- An in-round character refresh moves the visual and marker to the new rig.
do local s,b,alive=setup({0,40});local old=s.players[1].Character;local replaced=false;local observed=false
 s.wait=function()
  if not replaced then replaced=true;s.players[1]:LoadCharacter()
  elseif not observed then
   observed=true;eq(old:GetAttribute('HussBombCarrier'),false,'character replacement clears old marker')
   eq(s.players[1].Character:GetAttribute('HussBombCarrier'),true,'replacement rig marked as carrier')
   eq(b.GetCarrier(),s.players[1],'replacement preserves current actor identity')
  end
 end
 b.RunBombCycle(alive,.10);check(observed,'replacement observed before fuse expires')
end
-- Bot facade participates in exactly the same contact logic without Player-only APIs.
do local s,b,alive=setup({0,1});local bot=s.players[2];bot.ClassName='PracticeActor';bot.UserId=-101;bot.IsPracticeBot=true
 b.RunBombCycle(alive,.22);eq(transfer(s).CarrierUserId,-101,'practice bot receives bomb normally')
 eq(s:first('Pass')[3],bot,'economy receives original actor for its own practice exclusion')
 clearAttributes(s,'practice cleanup clears bot marker')
end
-- Untrusted/broad providers cannot turn inactive actors into valid recipients.
do local s,b,alive=setup({0,1});s.players[2]:SetAttribute('InRound',false)
 b.RunBombCycle(function() return s.players end,.22);eq(s:count('Pass'),0,'inactive target never eligible')
end
-- One actor cannot start a cycle; provider cancellation cannot damage survivors.
do local s,b,alive=setup({0});eq(b.RunBombCycle(alive,.1),nil,'solo actor not a valid cycle');eq(s:count('BombState'),0,'solo actor never assigned') end
do local s,b,alive=setup({0,40});local cancelled=false;s.wait=function() cancelled=true end
 b.RunBombCycle(function() return cancelled and {} or alive() end,.03)
 eq(s:count('Elimination'),0,'last-yield provider cancellation preserves player');clearAttributes(s,'provider cancellation clears markers')
end
-- Removed characters are excluded even when a provider has not noticed yet.
do local s,b,alive=setup({0,40});local once=false
 s.wait=function() if not once then once=true;s.players[1].Character.Parent=nil;s.players[1].Character.AncestryChanged:Fire(s.players[1].Character,nil) end end
 b.RunBombCycle(function() return s.players end,.1)
 eq(s:count('Elimination'),0,'removed rig is not reassigned by stale provider');clearAttributes(s,'removed rig markers remain cleared')
end
-- Non-finite positions cannot cause a contact or a Raycast error.
do local s,b,alive=setup({0,2});root(s.players[2]).Position=vec(0/0,0,0)
 b.RunBombCycle(alive,.22);eq(s:count('Pass'),0,'non-finite target root rejected')
end
-- An immune nearest target does not starve an eligible second target.
do local s,b,alive=setup({0,1,3});s.players[2].Character:SetAttribute('BombTagIFrameUntil',10)
 b.RunBombCycle(alive,.22);eq(transfer(s).CarrierUserId,3,'immune nearest player does not block eligible contact')
end
-- A repeated actor cannot manufacture the two actors required for a bomb cycle.
do local s,b,alive=setup({0})
 b.RunBombCycle(function() return {s.players[1],s.players[1]} end,.1)
 eq(s:count('BombState'),0,'duplicate actor filtered before cycle start')
end
-- Bounded history cannot tag an opponent who is already too far from contact.
do local s,b,alive=setup({0,14});s.cfg.NewCarrierLockSeconds=0;s.cfg.TagCheckInterval=.1
 s.wait=function() if s.now==.1 then root(s.players[1]).Position=vec(14,0,0);root(s.players[2]).Position=vec(0,0,0) end end
 b.RunBombCycle(alive,.15);eq(s:count('Pass'),0,'escaped target beyond short contact separation is safe')
end
-- Execute the actual perfect-weave module for a fast valid active dodge crossing.
do local s,b,alive=setup({0,12});s.cfg.NewCarrierLockSeconds=0;s.cfg.TagCheckInterval=.1
 local rs=s.env.game:GetService('ReplicatedStorage');rs.Shared=rs:WaitForChild('Shared')
 local actualWeave=s:load(Sources.Weave)
 s.env.script.Parent.PerfectWeaveServiceV11.Try=function(...) s:event('PerfectTry',...);return actualWeave.Try(...) end
 s.players[2].Character:SetAttribute('BombTagIFrameUntil',.45)
 s.wait=function() if s.now==.1 then root(s.players[1]).Position=vec(8,0,0);root(s.players[2]).Position=vec(1,0,0) end end
 b.RunBombCycle(alive,.15);eq(s:count('Pass'),0,'active swept dodge remains immune')
 eq(s:count('PerfectTry'),1,'accepted dodge window retains swept perfect-weave check')
 check(s:first('PerfectTry')[4]~=nil and s:first('PerfectTry')[5]~=nil,'perfect weave receives coherent historical positions')
 eq(s.players[2].Character:GetAttribute('HussPerfectDodgeUsed'),.45,'actual perfect-weave service consumes accepted dodge once')
 eq(s.players[2].Character:GetAttribute('HussPerfectBoostUntil'),2.1,'actual perfect-weave service grants temporary boost')
 eq(s.players[2].Character:GetAttribute('HussPerfectWeaveAt'),.1,'actual perfect-weave service emits cue timestamp')
end
print('BOMB_V12_CHECKS='..checks)
