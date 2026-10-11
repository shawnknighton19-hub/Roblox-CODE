--!nonstrict
-- HussBombContactV12: coherent swept contacts, deterministic selection and carrier presentation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage:WaitForChild("Shared")

local GameConfig =
	require(Shared.Config.GameConfig)

local Remotes =
	require(Shared.Net.Remotes)

-- HussEconomyHooksV9
local Economy=require(script.Parent:WaitForChild('EconomyServiceV9'))
-- HussCombatHooksV11
local Cosmetics=require(script.Parent:WaitForChild('CosmeticsServiceV11'))
local PerfectWeave=require(script.Parent:WaitForChild('PerfectWeaveServiceV11'))
local currentActor=nil
local carrierCharacter=nil
local carrierDiedConnection=nil
local carrierRemovedConnection=nil
local cycleGeneration=0

local function clearCarrierStatus()
 if carrierDiedConnection then carrierDiedConnection:Disconnect();carrierDiedConnection=nil end
 if carrierRemovedConnection then carrierRemovedConnection:Disconnect();carrierRemovedConnection=nil end
 if carrierCharacter then carrierCharacter:SetAttribute('HussBombCarrier',false);carrierCharacter=nil end
 currentActor=nil
end

local function updateCarrierStatus(actor)
 local character=actor and actor.Character
 if currentActor==actor and carrierCharacter==character then return end
 clearCarrierStatus()
 if not character then return end
 currentActor=actor
 carrierCharacter=character
 character:SetAttribute('HussBombCarrier',true)
 local function lostCharacter()
  if carrierCharacter==character then clearCarrierStatus() end
 end
 local humanoid=character:FindFirstChildOfClass('Humanoid')
 if humanoid then carrierDiedConnection=humanoid.Died:Connect(lostCharacter) end
 carrierRemovedConnection=character.AncestryChanged:Connect(function(_,parent)
  if parent==nil then lostCharacter() end
 end)
end
local BombService = {}

local bombRemote = nil

local activeBombPart = nil
local activeHighlight = nil

------------------------------------------------------------
-- PLAYER HELPERS
------------------------------------------------------------

local function getHumanoid(player)

	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player)

	local character = player.Character

	if not character then
		return nil
	end

	local root =
		character:FindFirstChild("HumanoidRootPart")

	if root and root:IsA("BasePart") then
		return root
	end

	return nil
end

local function isAlive(player)

	if not player then
		return false
	end

	if not player.Parent or not player.Character or not player.Character.Parent then
		return false
	end

	if player:GetAttribute("InRound") ~= true then
		return false
	end

	local humanoid = getHumanoid(player)

	if not humanoid then
		return false
	end

	return humanoid.Health > 0
end

------------------------------------------------------------
-- DODGE I-FRAMES
------------------------------------------------------------

local function hasDodgeIFrames(player)

	if not player then
		return false
	end

	local character = player.Character

	if not character then
		return false
	end

	local immuneUntil =
		character:GetAttribute("BombTagIFrameUntil")
		or 0

	return workspace:GetServerTimeNow()
		< immuneUntil
end

------------------------------------------------------------
-- BOMB VISUAL
------------------------------------------------------------

local function clearBombVisual()

	if activeBombPart then
		activeBombPart:Destroy()
		activeBombPart = nil
	end

	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

local function attachBombVisual(player)

	clearBombVisual()

	local character = player.Character

	if not character then
		return
	end

	local torso =
		character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")

	if not torso or not torso:IsA("BasePart") then
		return
	end

	--------------------------------------------------------
	-- BOMB
	--------------------------------------------------------

	local bomb = Instance.new("Part")

	bomb.Name = "ActiveBomb"

	bomb.Shape = Enum.PartType.Ball

	bomb.Size =
		Vector3.new(2.25, 2.25, 2.25)

	bomb.Color =
		Color3.fromRGB(32, 32, 38)

	bomb.Material =
		Enum.Material.Metal

	bomb.CanCollide = false
	bomb.CanTouch = false
	bomb.CanQuery = false

	bomb.Massless = true
	bomb.Anchored = false

	bomb.CFrame =
		torso.CFrame
		* CFrame.new(0, 1.2, 1.15)

	bomb.Parent = character

	local weld =
		Instance.new("WeldConstraint")

	weld.Part0 = torso
	weld.Part1 = bomb
	weld.Parent = bomb

	--------------------------------------------------------
	-- RED LIGHT
	--------------------------------------------------------

	local light =
		Instance.new("PointLight")

	light.Color =
		Color3.fromRGB(255, 60, 60)

	light.Brightness = 4
	light.Range = 13

	light.Parent = bomb

	--------------------------------------------------------
	-- BILLBOARD
	--------------------------------------------------------

	local billboard =
		Instance.new("BillboardGui")

	billboard.Name = "BombBillboard"

	billboard.Size =
		UDim2.fromOffset(160, 48)

	billboard.StudsOffset =
		Vector3.new(0, 2.6, 0)

	billboard.AlwaysOnTop = true
	billboard.Adornee = bomb

	billboard.Parent = bomb

	local label =
		Instance.new("TextLabel")

	label.Size =
		UDim2.fromScale(1, 1)

	label.BackgroundTransparency = 1

	label.Font =
		Enum.Font.GothamBlack

	label.Text = "💣 BOMB"

	label.TextColor3 =
		Color3.fromRGB(255, 80, 80)

	label.TextStrokeTransparency = 0.1
	label.TextScaled = true

	label.Parent = billboard

	--------------------------------------------------------
	-- CARRIER HIGHLIGHT
	--------------------------------------------------------

	local highlight =
		Instance.new("Highlight")

	highlight.Name =
		"BombCarrierHighlight"

	highlight.FillColor =
		Color3.fromRGB(255, 55, 55)

	highlight.FillTransparency = 0.72

	highlight.OutlineColor =
		Color3.fromRGB(255, 80, 80)

	highlight.OutlineTransparency = 0

	highlight.Parent = character

	activeBombPart = bomb
	activeHighlight = highlight
	Cosmetics.ApplyBomb(player,bomb)
end

------------------------------------------------------------
-- NETWORK
------------------------------------------------------------

local function sendBombState(
	active,
	carrier,
	endTime,
	eventName
)

	updateCarrierStatus(active and carrier or nil)
	bombRemote:FireAllClients({
		Active = active,

		CarrierUserId =
			carrier and carrier.UserId or 0,

		CarrierName =
			carrier and carrier.DisplayName or "",

		EndTime = endTime or 0,

		Event = eventName or "",
	})
end

local function setCarrier(
	player,
	endTime,
	eventName
)

	attachBombVisual(player)

	sendBombState(
		true,
		player,
		endTime,
		eventName
	)
end

------------------------------------------------------------
-- HIGH SPEED TAG DETECTION
------------------------------------------------------------

-- Samples belong to one server tick and one root instance. A new character,
-- long server stall or teleport must not leave a damaging path behind it.
local MAX_SWEEP_SECONDS=.12
local MAX_SWEEP_SPEED=120 -- covers the existing 84 stud/s weave with network slack
local SAMPLE_SLACK=2
local MAX_CONTACT_SEPARATION=6
local DISTANCE_EPSILON=.0001

local function finitePosition(position)
 return typeof(position)=='Vector3' and position.X==position.X
  and position.Y==position.Y and position.Z==position.Z
  and position.Magnitude<1000000
end

local function capture(actors,now)
 local samples={}
 for _,actor in ipairs(actors) do
  local root=getRoot(actor)
  if root and finitePosition(root.Position) then
   samples[actor.UserId]={Root=root,Position=root.Position,Time=now}
  end
 end
 return samples
end

local function previousPosition(actor,current,previous,now,lockedUntil)
 local old=previous[actor.UserId]
 if not old or old.Root~=current.Root or old.Time<lockedUntil then return nil end
 local elapsed=now-old.Time
 if elapsed<=0 or elapsed>MAX_SWEEP_SECONDS then return nil end
 local travel=(current.Position-old.Position).Magnitude
 if travel>MAX_SWEEP_SPEED*elapsed+SAMPLE_SLACK then return nil end
 return old.Position
end

local function closestContact(a0,a1,b0,b1)
 local start=b0-a0
 local delta=(b1-a1)-start
 local denominator=delta:Dot(delta)
 local alpha=denominator>1e-5 and math.clamp(-start:Dot(delta)/denominator,0,1) or 0
 return (start+delta*alpha).Magnitude,a0+(a1-a0)*alpha,b0+(b1-b0)*alpha
end

local function lineClear(a,b,parameters)
 local delta=b-a
 return delta.Magnitude<=.001 or workspace:Raycast(a,delta,parameters)==nil
end

local function contact(a,b,ap,bp,parameters)
 local direct=(b-a).Magnitude
 local distance=direct
 local ca,cb=a,b
 if ap and bp then
  local swept,sa,sb=closestContact(ap,a,bp,b)
  -- Check traveled segments as well: interpolation cannot cut through a wall.
  if swept<distance and lineClear(ap,a,parameters) and lineClear(bp,b,parameters) then
   distance,ca,cb=swept,sa,sb
  end
 end
 if distance>GameConfig.BombTagRadius then return nil end
 -- Never deliver a delayed-looking tag to someone who has already escaped.
 if direct>GameConfig.BombTagRadius+MAX_CONTACT_SEPARATION then return nil end
 if not lineClear(a,b,parameters) then return nil end
 if not lineClear(ca,cb,parameters) then
  if direct>GameConfig.BombTagRadius then return nil end
  distance=direct
 end
 return distance,direct
end

local function betterCandidate(candidate,distance,direct,best,bestDistance,bestDirect)
 if not best or distance<bestDistance-DISTANCE_EPSILON then return true end
 if math.abs(distance-bestDistance)>DISTANCE_EPSILON then return false end
 if direct<bestDirect-DISTANCE_EPSILON then return true end
 return math.abs(direct-bestDirect)<=DISTANCE_EPSILON and candidate.UserId<best.UserId
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------

function BombService.GetCarrier() return currentActor end
function BombService.Init()

	bombRemote =
		Remotes.Get("BombState")

	if GameConfig.DebugPrints then
		print("[BombService] Initialized")
	end
end

------------------------------------------------------------
-- STOP
------------------------------------------------------------

function BombService.Stop()

	cycleGeneration+=1

	clearBombVisual()

	sendBombState(
		false,
		nil,
		0,
		"Stopped"
	)
end

------------------------------------------------------------
-- BOMB CYCLE
------------------------------------------------------------

local function livingActors(aliveProvider)
 local actors,seen={},{}
 for _,actor in ipairs(aliveProvider()) do
  if not seen[actor] and isAlive(actor) then
   seen[actor]=true
   table.insert(actors,actor)
  end
 end
 return actors
end

function BombService.RunBombCycle(aliveProvider,fuseSeconds)
 local alivePlayers=livingActors(aliveProvider)
 if #alivePlayers<=1 then return nil end
 cycleGeneration+=1
 local cycle=cycleGeneration
 local carrier=alivePlayers[math.random(1,#alivePlayers)]
 local lastPasser=nil
 local startedAt=workspace:GetServerTimeNow()
 local endTime=startedAt+fuseSeconds
 local protectedUserId=nil
 local protectedUntil=0
 local carrierLockedUntil=startedAt+GameConfig.NewCarrierLockSeconds
 local previous=capture(alivePlayers,startedAt)
 setCarrier(carrier,endTime,'Started')

 while workspace:GetServerTimeNow()<endTime do
  if cycle~=cycleGeneration then return nil end
  local now=workspace:GetServerTimeNow()
  alivePlayers=livingActors(aliveProvider)
  if #alivePlayers<=1 then BombService.Stop();return nil end
  local samples=capture(alivePlayers,now)

  if not isAlive(carrier) then
   lastPasser=nil
   carrier=alivePlayers[math.random(1,#alivePlayers)]
   carrierLockedUntil=now+GameConfig.NewCarrierLockSeconds
   setCarrier(carrier,endTime,'Reassigned')
  elseif carrierCharacter~=carrier.Character then
   -- A refreshed character must never leave panic effects on the old rig.
   lastPasser=nil
   carrierLockedUntil=now+GameConfig.NewCarrierLockSeconds
   setCarrier(carrier,endTime,'Reassigned')
  end

  local carrierSample=samples[carrier.UserId]
  if now>=carrierLockedUntil and isAlive(carrier) and carrierSample then
   local excluded={}
   for _,actor in ipairs(alivePlayers) do
    if actor.Character then table.insert(excluded,actor.Character) end
   end
   local parameters=RaycastParams.new()
   parameters.FilterType=Enum.RaycastFilterType.Exclude
   parameters.FilterDescendantsInstances=excluded
   parameters.IgnoreWater=true
   parameters.RespectCanCollide=true
   local carrierPrevious=previousPosition(carrier,carrierSample,previous,now,carrierLockedUntil)
   local best,bestDistance,bestDirect=nil,math.huge,math.huge

   for _,candidate in ipairs(alivePlayers) do
    if candidate==carrier or not isAlive(candidate) then continue end
    if candidate.UserId==protectedUserId and now<protectedUntil then continue end
    local sample=samples[candidate.UserId]
    if not sample then continue end
    local candidateUnlockedAt=carrierLockedUntil
    if candidate.UserId==protectedUserId then candidateUnlockedAt=math.max(candidateUnlockedAt,protectedUntil) end
    local immuneUntil=candidate.Character:GetAttribute('BombTagIFrameUntil')
    if type(immuneUntil)=='number' and immuneUntil==immuneUntil then
     -- Active dodges may earn a perfect-weave cue from their accepted window;
     -- expired dodges must not expose that protected path to a later transfer.
     local boundary=immuneUntil>now and immuneUntil-.45 or immuneUntil
     candidateUnlockedAt=math.max(candidateUnlockedAt,boundary)
    end
    local candidatePrevious=previousPosition(candidate,sample,previous,now,candidateUnlockedAt)
    local distance,direct=contact(carrierSample.Position,sample.Position,carrierPrevious,candidatePrevious,parameters)
    if not distance then continue end
    if hasDodgeIFrames(candidate) then
     PerfectWeave.Try(carrier,candidate,carrierPrevious,candidatePrevious,protectedUserId,protectedUntil)
     continue
    end
    if betterCandidate(candidate,distance,direct,best,bestDistance,bestDirect) then
     best,bestDistance,bestDirect=candidate,distance,direct
    end
   end

   if best then
    local oldCarrier=carrier
    carrier=best
    protectedUserId=oldCarrier.UserId
    protectedUntil=now+GameConfig.AntiTagBackSeconds
    carrierLockedUntil=now+GameConfig.NewCarrierLockSeconds
    setCarrier(carrier,endTime,'Transferred')
    lastPasser=oldCarrier
    Economy.Pass(oldCarrier,carrier)
    if GameConfig.DebugPrints then print('[BombService]',oldCarrier.Name,'tagged',carrier.Name) end
   end
  end

  -- Replace rather than append: departed actors and old roots leave no history.
  previous=samples
  task.wait(GameConfig.TagCheckInterval)
 end

 if cycle~=cycleGeneration then return nil end
 if #livingActors(aliveProvider)<=1 then BombService.Stop();return nil end
 local victim=carrier
 if victim and isAlive(victim) then
  Economy.Elimination(lastPasser,victim)
  sendBombState(false,victim,0,'Exploded')
  clearBombVisual()
  local humanoid=getHumanoid(victim)
  if humanoid then humanoid.Health=0 end
  if GameConfig.DebugPrints then print('[BombService]',victim.Name,'exploded') end
 else
  BombService.Stop()
 end
 return victim
end

return BombService
