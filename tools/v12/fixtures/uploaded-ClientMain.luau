--!nonstrict

local ReplicatedStorage =
	game:GetService("ReplicatedStorage")

local Shared =
	ReplicatedStorage:WaitForChild("Shared")

local Controllers =
	script.Parent:WaitForChild("Controllers")

------------------------------------------------------------
-- BOMB TAG REMOTES
------------------------------------------------------------

local Remotes =
	require(
		Shared.Net.Remotes
	)

Remotes.Init()

------------------------------------------------------------
-- KEEP BOMB TAG HUD
------------------------------------------------------------

local HudController =
	require(
		Controllers:WaitForChild(
			"HudController"
		)
	)

HudController.Init()

------------------------------------------------------------
-- IMPORTANT
--
-- MovementController and MovementAnimationController
-- are intentionally NOT initialized anymore.
--
-- The imported R6 movement pack now controls movement.
------------------------------------------------------------

print(
	"[ClientMain] Bomb Tag running with R6 movement pack"
)