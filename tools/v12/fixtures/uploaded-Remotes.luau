--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local REMOTE_FOLDER_NAME = "BombTagRemotes"

local REMOTE_NAMES = {
	"RoundState",
	"BombState",
}

local remoteFolder = nil

------------------------------------------------------------
-- INIT
------------------------------------------------------------

function Remotes.Init()
	if RunService:IsServer() then

		local existingFolder =
			ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)

		if existingFolder and existingFolder:IsA("Folder") then
			remoteFolder = existingFolder
		else
			if existingFolder then
				existingFolder:Destroy()
			end

			remoteFolder = Instance.new("Folder")
			remoteFolder.Name = REMOTE_FOLDER_NAME
			remoteFolder.Parent = ReplicatedStorage
		end

		for _, remoteName in ipairs(REMOTE_NAMES) do

			local existing =
				remoteFolder:FindFirstChild(remoteName)

			if not existing then
				local remote = Instance.new("RemoteEvent")
				remote.Name = remoteName
				remote.Parent = remoteFolder
			end
		end

	else

		remoteFolder =
			ReplicatedStorage:WaitForChild(REMOTE_FOLDER_NAME)

		for _, remoteName in ipairs(REMOTE_NAMES) do
			remoteFolder:WaitForChild(remoteName)
		end
	end
end

------------------------------------------------------------
-- GET
------------------------------------------------------------

function Remotes.Get(remoteName)

	assert(
		remoteFolder,
		"Remotes.Init() must run before Remotes.Get()"
	)

	local remote =
		remoteFolder:FindFirstChild(remoteName)

	assert(
		remote and remote:IsA("RemoteEvent"),
		"Remote does not exist: " .. tostring(remoteName)
	)

	return remote
end

return Remotes