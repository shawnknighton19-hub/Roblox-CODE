local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

-- Makes hands interact with head better
local head = char:WaitForChild("Head")
head.Size = Vector3.new(1,1,1)

char.ChildAdded:Connect(function(force)
	if force.Name == "Ragdoll" then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		hrp:ApplyAngularImpulse(Vector3.new(-force.Value, 0, 0))
	end
end)
char.ChildRemoved:Connect(function(bool)
	if bool.Name == "Ragdoll" and not char:FindFirstChild("Ragdoll") then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)