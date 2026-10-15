--!nonstrict
-- HussPerfectWeaveV11: a server-confirmed avoided tag, once per accepted dodge.
local Config=require(game:GetService('ReplicatedStorage').Shared.Config.GameConfig)
local W={}
local function root(actor)
 local c=actor and actor.Character
 local h=c and c:FindFirstChildOfClass('Humanoid')
 local r=c and c:FindFirstChild('HumanoidRootPart')
 if not h or h.Health<=0 or not r or r.Anchored or h.Sit or h.PlatformStand then return nil end
 if actor:GetAttribute('InRound')~=true then return nil end
 return r,c
end
local function finite(v)
 return typeof(v)=='Vector3' and v.X==v.X and v.Y==v.Y and v.Z==v.Z and v.Magnitude<1000000
end
function W.Try(carrier,target,previousCarrier,previousTarget,protectedId,protectedUntil)
 if carrier==target or not carrier or not target then return false end
 local now=workspace:GetServerTimeNow()
 if target.UserId==protectedId and now<(protectedUntil or 0) then return false end
 local a,ca=root(carrier);local b,cb=root(target)
 if not a or not b or cb:GetAttribute('HussBombCarrier')==true then return false end
 local ends=cb:GetAttribute('BombTagIFrameUntil')
 if type(ends)~='number' or ends~=ends then return false end
 local age=now-(ends-.45)
 if age<0 or age>.22 or now>=ends or cb:GetAttribute('HussPerfectDodgeUsed')==ends then return false end
 local ac,bc=a.Position,b.Position
 local ap=finite(previousCarrier) and previousCarrier or ac
 local bp=finite(previousTarget) and previousTarget or bc
 if not finite(ac) or not finite(bc) or (ac-ap).Magnitude>20 or (bc-bp).Magnitude>20 then return false end
 local start=bp-ap;local finish=bc-ac;local delta=finish-start
 local t=delta:Dot(delta)>1e-5 and math.clamp(-start:Dot(delta)/delta:Dot(delta),0,1) or 0
 local distance=math.min(finish.Magnitude,(start+delta*t).Magnitude)
 if distance>Config.BombTagRadius or finish.Magnitude>Config.BombTagRadius+6 then return false end
 local ray=RaycastParams.new();ray.FilterType=Enum.RaycastFilterType.Exclude;ray.FilterDescendantsInstances={ca,cb};ray.IgnoreWater=true
 if finish.Magnitude>.01 and workspace:Raycast(ac,finish,ray) then return false end
 cb:SetAttribute('HussPerfectDodgeUsed',ends)
 cb:SetAttribute('HussPerfectBoostUntil',now+2)
 cb:SetAttribute('HussPerfectWeaveAt',now)
 return true
end
return W

-- HAB_HALLOWEEN_CRATES_1
