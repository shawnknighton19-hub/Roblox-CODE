local module = {}
local Players = game:GetService("Players")

local PhysicsService = game:GetService("PhysicsService")
local ragParts = script.Parent.RagdollParts:GetChildren()

function module:Setup(char: Model)
	assert(
		Players:GetPlayerFromCharacter(char) == nil,
		"Setting up ragdoll on player characters is already done automatically"
	)

	local humanoid = char:FindFirstChild("Humanoid")
	assert(humanoid, "Can only set-up ragdoll on R6 humanoid rigs")
	assert(humanoid.RigType == Enum.HumanoidRigType.R6, "Can only set-up ragdoll on R6 humanoid rigs")
	assert(humanoid.RootPart ~= nil, "No RootPart was found in the provided rig")
	assert(char:FindFirstChild("HumanoidRootPart"), "No HumanoidRootPart was found in the provided rig")


	-- Setup ragdoll
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
 
	char.ChildAdded:Connect(function(force)
		if force.Name == "Ragdoll" then
			module:Ragdoll(char,force.Value)
		end
	end)
	
	char.ChildRemoved:Connect(function(bool)
		if bool.Name == "Ragdoll" and not char:FindFirstChild("Ragdoll") then
			module:Unragdoll(char)
		end
	end)

end

function module:Ragdoll(char: Model,Force)
	char.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	char.Humanoid.AutoRotate = false
	for _, v in ipairs(char.RagdollConstraints.Motors:GetChildren()) do
		v.Value.Enabled = false
	end

	for _, v in ipairs(char:GetChildren()) do
		if v:IsA("BasePart") then
			v.CollisionGroup = "Ragdoll"
		end
	end

 	char.HumanoidRootPart:ApplyAngularImpulse(Vector3.new(-Force, 0, 0))
end

function module:Unragdoll(char: Model)
	for i = 1,4 do
		char.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		task.wait()
	end
	
	for _, v in ipairs(char.RagdollConstraints.Motors:GetChildren()) do
		v.Value.Enabled = true
	end

	for _, v in ipairs(char:GetChildren()) do
		if v:IsA("BasePart") then
			v.CollisionGroup = "Default"
		end
	end
	char.Humanoid.AutoRotate = true
end

return module
