local PhysicsService = game:GetService("PhysicsService")
local PlayerGroup = PhysicsService:CreateCollisionGroup("p")

PhysicsService:CollisionGroupSetCollidable("p","p",false)

function NoCollision(Model)
	for k,v in pairs(Model:GetChildren()) do
		if v:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(v,"p")
		end
	end
end

for i,Child in workspace:GetDescendants() do
	if Child and Child:FindFirstChild("HumanoidRootPart") then
		NoCollision(Child)
	end
end

game.Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		wait()
		NoCollision(plr.Character)
	end)
end)

game:GetService("Workspace").ChildAdded:Connect(function(Child)
	if Child and Child:FindFirstChild("HumanoidRootPart") then
		NoCollision(Child)
	end
end)