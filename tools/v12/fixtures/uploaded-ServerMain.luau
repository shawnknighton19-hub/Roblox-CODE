--!nonstrict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local ServerScriptService =
	game:GetService("ServerScriptService")

local Shared =
	ReplicatedStorage:WaitForChild("Shared")

local Services =
	ServerScriptService:WaitForChild("Services")

------------------------------------------------------------
-- REMOTES FIRST
------------------------------------------------------------

local Remotes =
	require(
		Shared.Net.Remotes
	)

Remotes.Init()

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------

local BombService =
	require(
		Services.BombService
	)

local RoundService =
	require(
		Services.RoundService
	)

BombService.Init()

-- RoundService begins the actual game loop,
-- so it initializes last.
RoundService.Init()

print("[ServerMain] Bomb Tag server booted")