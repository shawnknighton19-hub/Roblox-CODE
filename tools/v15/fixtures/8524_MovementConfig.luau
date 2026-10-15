--!nonstrict

local MovementConfig = {}

------------------------------------------------------------
-- NORMAL MOVEMENT
------------------------------------------------------------

GameConfig = nil -- intentionally unused safety against typo

MovementConfig.BaseWalkSpeed = 25
MovementConfig.SprintSpeed = 34
MovementConfig.WalkSpeedResponse = 18

------------------------------------------------------------
-- JUMP
------------------------------------------------------------

MovementConfig.JumpPower = 52

------------------------------------------------------------
-- GLOBAL SPEED CAP
------------------------------------------------------------

MovementConfig.MaxMovementSpeed = 43

------------------------------------------------------------
-- SLIDE
------------------------------------------------------------

-- Sliding uses the speed you actually have.
MovementConfig.SlideMinimumEntrySpeed = 7

-- Very small conversion bonus.
MovementConfig.SlideEntryMomentumMultiplier = 1.03

MovementConfig.SlideFriction = 18

MovementConfig.SlideMaximumDuration = 0.90

MovementConfig.SlideStopSpeed = 7

MovementConfig.SlideCancelDelay = 0.13

MovementConfig.SlideCooldown = 0.18

MovementConfig.SlideSteerRate = 5.2

------------------------------------------------------------
-- SLIDE-CANCEL MOMENTUM
------------------------------------------------------------

MovementConfig.MomentumCarryDuration = 0.34

MovementConfig.MomentumCarryFriction = 25

MovementConfig.MomentumCarrySteerRate = 8

------------------------------------------------------------
-- EVASIVE MOVEMENT
------------------------------------------------------------

-- ALL Q evasive moves share this cooldown.
--
-- The cooldown begins when the move STARTS.
--
-- Therefore you can only begin one Q move every
-- 1.5 seconds.
MovementConfig.WeaveCooldown = 1.5

------------------------------------------------------------
-- LEFT / RIGHT WEAVE
------------------------------------------------------------

-- A + Q and D + Q still use your existing momentum.
--
-- They redirect movement instead of giving you free speed.

MovementConfig.SideWeaveMinimumSpeed = 13

MovementConfig.SideWeaveDuration = 0.24

MovementConfig.SideWeaveFriction = 10

MovementConfig.SideWeaveTurnRate = 28

------------------------------------------------------------
-- FORWARD DASH
------------------------------------------------------------

-- W + Q
--
-- Short fixed burst.
--
-- 38 studs/sec for 0.16 seconds is only about
-- 6 studs of raw travel.
MovementConfig.ForwardDashSpeed = 38

MovementConfig.ForwardDashDuration = 0.16

------------------------------------------------------------
-- BACK DASH
------------------------------------------------------------

-- S + Q
--
-- Slightly weaker than forward dash.
--
-- 30 studs/sec for 0.16 seconds is roughly
-- 4.8 studs of raw travel.
MovementConfig.BackDashSpeed = 30

MovementConfig.BackDashDuration = 0.16

------------------------------------------------------------
-- AIR CONTROL
------------------------------------------------------------

-- Q evasive moves are ground-only.
--
-- Normal jumping still has mild directional control.
MovementConfig.AirTurnRate = 3.5

------------------------------------------------------------
-- CAMERA
------------------------------------------------------------

MovementConfig.NormalFOV = 70

MovementConfig.SprintFOV = 79

MovementConfig.SlideFOV = 84

MovementConfig.FOVResponseSpeed = 11

------------------------------------------------------------
-- SLIDE CAMERA
------------------------------------------------------------

MovementConfig.SlideCameraOffset =
	Vector3.new(
		0,
		-1.15,
		0
	)

MovementConfig.CameraOffsetResponseSpeed = 14

------------------------------------------------------------
-- DEBUG
------------------------------------------------------------

MovementConfig.DebugPrints = false

return MovementConfig