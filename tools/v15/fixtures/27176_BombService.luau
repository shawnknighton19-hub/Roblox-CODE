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
local CrateService=require(script.Parent:WaitForChild('HABCrateService'))
local CrateCatalog=require(ReplicatedStorage:WaitForChild('HABHalloween'):WaitForChild('Catalog'))
local currentActor=nil
local carrierCharacter=nil
local carrierDiedConnection=nil
local carrierRemovedConnection=nil
local cycleGeneration=0

local function clearCarrierStatus()
 if carrierDiedConnection then carrierDiedConnection:Disconnect();carrierDiedConnection=nil end
 if carrierRemovedConnection then carrierRemovedConnection:Disconnect();carrierRemovedConnection=nil end
 if carrierCharacter then
  carrierCharacter:SetAttribute('HABCarrierSprintBonus',0)
  carrierCharacter:SetAttribute('HussBombCarrier',false)
  carrierCharacter=nil
 end
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
 character:SetAttribute('HABCarrierSprintBonus',CrateCatalog.CarrierSprintBonus)
 character:SetAttribute('BombTagIFrameUntil',0)
 character:SetAttribute('BombTagIFrameActive',false)
 local immune=character:FindFirstChild('DodgeIFrameHighlight');if immune then immune:Destroy() end
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
 if player and player.Character and player.Character:GetAttribute('HussBombCarrier')==true then return false end

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
-- SWING-TO-TAG / SERVER-VALIDATED THROWS
------------------------------------------------------------
local Actions=require(script.Parent.HABActionService)
function BombService.GetCarrier() return currentActor end
function BombService.Init()
 bombRemote=Remotes.Get('BombState')
 Actions.Init()
 print('[HAB Bomb] Swing-to-tag is active. Touching alone NEVER transfers the bomb.')
end
function BombService.Stop()
 cycleGeneration=cycleGeneration+1
 Actions.Stop()
 clearBombVisual()
 sendBombState(false,nil,0,'Stopped')
end
local function livingActors(provider)
 local out,seen={},{}
 for _,p in ipairs(provider()) do
  if not seen[p] and isAlive(p) then out[#out+1]=p;seen[p]=true end
 end
 return out
end
function BombService.RunBombCycle(aliveProvider,fuseSeconds)
 local alive=livingActors(aliveProvider)
 if #alive<=1 then return nil end
 cycleGeneration=cycleGeneration+1
 local generation=cycleGeneration
 local carrier=alive[math.random(1,#alive)]
 local lastPasser,lastBombOwner=nil,nil
 local now=workspace:GetServerTimeNow()
 local ending=now+fuseSeconds
 local locked=now+GameConfig.NewCarrierLockSeconds
 local protectedId,protectedUntil=nil,0
 local function assign(event)
  setCarrier(carrier,ending,event)
  Actions.SetCarrier(carrier,ending,locked,protectedId,protectedUntil)
 end
 assign('Started')
 while workspace:GetServerTimeNow()<ending do
  if generation~=cycleGeneration then return nil end
  now=workspace:GetServerTimeNow()
  alive=livingActors(aliveProvider)
  if #alive<=1 then BombService.Stop();return nil end
  if not isAlive(carrier) then
   carrier=alive[math.random(1,#alive)]
   lastPasser,lastBombOwner=nil,nil
   protectedId,protectedUntil=nil,0
   locked=now+GameConfig.NewCarrierLockSeconds
   assign('Reassigned')
  elseif carrierCharacter~=carrier.Character then
   lastPasser,lastBombOwner=nil,nil
   protectedId,protectedUntil=nil,0
   locked=now+GameConfig.NewCarrierLockSeconds
   assign('Reassigned')
  end
  local candidate=Actions.Tick(alive,now)
  if candidate and candidate~=carrier and isAlive(candidate) then
   local previous=carrier
   carrier=candidate
   protectedId=previous.UserId;protectedUntil=now+GameConfig.AntiTagBackSeconds
   locked=now+GameConfig.NewCarrierLockSeconds
   lastPasser=previous;lastBombOwner=CrateService.CaptureOwner(previous)
   Economy.Pass(previous,carrier)
   assign('Transferred')
  end
  task.wait(math.clamp(GameConfig.TagCheckInterval or .03,.02,.05))
 end
 if generation~=cycleGeneration then return nil end
 if #livingActors(aliveProvider)<=1 then BombService.Stop();return nil end
 Actions.Stop()
 local victim=carrier
 if victim and isAlive(victim) then
  Economy.Elimination(lastPasser,victim)
  local ok,err=pcall(CrateService.Elimination,lastPasser,victim,lastBombOwner)
  if not ok then warn('[HAB Bomb] Elimination VFX: '..tostring(err)) end
  sendBombState(false,victim,0,'Exploded')
  clearBombVisual()
  local h=getHumanoid(victim);if h then h.Health=0 end
 else BombService.Stop() end
 return victim
end
return BombService
-- HAB_HALLOWEEN_CRATES_1
-- HAB_CRATE_UPGRADE_2
-- HAB_EXPANSION_7
