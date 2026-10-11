--!nonstrict
-- HussCosmeticsV12: sculpted bombs and stationary lobby emotes; never changes movement.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local C=require(RS:WaitForChild('HussCatalogV11'))
local BombSkinBuilder=require(RS:WaitForChild('BombSkinBuilderV12'))
local S={};local states={};local started=false
local function item(p,attribute,category)
 local entry=p and C.ById[p:GetAttribute(attribute)]
 return entry and entry.category==category and entry or C.ById[C.Defaults[category]]
end
function S.ApplyBomb(player,bomb)
 return BombSkinBuilder.Apply(bomb,item(player,'HussBombId','Bombs'))
end
local function stop(p)
 local s=states[p];if s then s.active=nil end
 p:SetAttribute('HussEmotePlaying',nil);p:SetAttribute('HussEmoteStarted',nil)
end
local function stationary(p)
 local c=p.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local r=c and c:FindFirstChild('HumanoidRootPart')
 if not h or not r or h.Health<=0 or p:GetAttribute('InRound')==true or h.MoveDirection.Magnitude>.05 or r.AssemblyLinearVelocity.Magnitude>2 or h.Sit or h.PlatformStand or r.Anchored or h.FloorMaterial==Enum.Material.Air then return end
 if p:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true or c:GetAttribute('Ragdolled')==true or c:GetAttribute('IsRagdoll')==true then return end
 local action=c:GetAttribute('MovementAction');if type(action)=='string' and action:sub(1,4)=='Dive' and action~='DiveEnd' then return end
 return c,h,r
end
function S.Init()
 if started then return end;started=true
 local remote=RS:FindFirstChild('HussCosmeticsV11') or Instance.new('RemoteEvent');assert(remote:IsA('RemoteEvent'),'HussCosmeticsV11 must be a RemoteEvent');remote.Name='HussCosmeticsV11';remote.Parent=RS
 local function add(p) states[p]={nextAt=0};stop(p) end
 Players.PlayerAdded:Connect(add);Players.PlayerRemoving:Connect(function(p) states[p]=nil end)
 for _,p in ipairs(Players:GetPlayers()) do add(p) end
 remote.OnServerEvent:Connect(function(p,action,id)
  local s=states[p];if not s then return end
  if action=='StopEmote' then if s.active then stop(p) end;return end
  if action~='Emote' or os.clock()<s.nextAt or p:GetAttribute('HussEconomyReady')~=true then return end
  local equipped=p:GetAttribute('HussEmoteId');local entry=C.ById[equipped]
  if not entry or entry.category~='Emotes' or (id~=nil and id~=equipped) then return end
  local c,h,r=stationary(p);if not c then return end
  s.nextAt=os.clock()+1.25;s.active={character=c,health=h.Health,position=r.Position,untilAt=os.clock()+6}
  p:SetAttribute('HussEmoteStarted',workspace:GetServerTimeNow());p:SetAttribute('HussEmotePlaying',equipped)
 end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.1 then return end;elapsed=0
  for p,s in pairs(states) do if s.active then
   local c,h,r=stationary(p);local a=s.active
   if not c or c~=a.character or h.Health<a.health or (r.Position-a.position).Magnitude>.3 or os.clock()>=a.untilAt then stop(p) end
  end end
 end)
end
return S
