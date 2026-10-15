

local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local module = require(script.ModuleScript)
local ragParts = script.RagdollParts:GetChildren()
local r6Client = script.R6RagdollClient


PhysicsService:RegisterCollisionGroup("Ragdoll")

local function SetupRagdoll(char)
	CollectionService:AddTag(char,"Rig")
	if game.Players:GetPlayerFromCharacter(char) then
		local humanoid = char.Humanoid
		char.Head.Size = Vector3.new(1, 1, 1)
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false

		local clones = {}
		for _, v in ipairs(ragParts) do
			clones[v.Name] = v:Clone()
		end

		local folder1 = Instance.new("Folder")
		folder1.Name = "RagdollConstraints"
		for _, v in pairs(clones) do
			if v:IsA("Attachment") then
				v.Parent = char[v:GetAttribute("Parent")]
			elseif v:IsA("BallSocketConstraint") then
				v.Attachment0 = clones[v:GetAttribute("0")]
				v.Attachment1 = clones[v:GetAttribute("1")]
				v.Parent = folder1
			end
		end
		folder1.Parent = char
		local folder2 = Instance.new("Folder")
		folder2.Name = "Motors"
		local value
		for _, v in ipairs(char.Torso:GetChildren()) do
			if v:IsA("Motor6D") then
				value = Instance.new("ObjectValue")
				value.Value = v
				value.Parent = folder2
			end
		end
		folder2.Parent = folder1 
		
		char.ChildAdded:Connect(function(bool)
			if bool.Name == "Ragdoll" then
				module:Ragdoll(char)
			end
		end)
		char.ChildRemoved:Connect(function(bool)
			if bool.Name == "Ragdoll" and not char:FindFirstChild("Ragdoll") then
				module:Unragdoll(char)
			end
		end)
		
		r6Client:Clone().Parent = char
	else
		require(script.ModuleScript):Setup(char)
	end
end

for i,part in pairs(workspace:GetDescendants()) do
	local char = part.Parent
	pcall(function()

		if char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") and not char:FindFirstChild("RagdollConstraints") then
			SetupRagdoll(char)
		end

	end) 
end

workspace.DescendantAdded:Connect(function(part)
	local char = part.Parent
	pcall(function()
		
		if char:FindFirstChild("Humanoid") and char:FindFirstChild("HumanoidRootPart") and not char:FindFirstChild("RagdollConstraints") then
			SetupRagdoll(char)
		end
		
	end) 
end)
