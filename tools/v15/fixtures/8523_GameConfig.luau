--!nonstrict

local GameConfig = {}

------------------------------------------------------------
-- PLAYER / ROUND REQUIREMENTS
------------------------------------------------------------

-- Two or more players = normal Bomb Tag.
-- One player is still allowed to start for solo practice.
GameConfig.MinimumPlayers = 2

-- The game may begin as long as at least one player exists.
GameConfig.AbsoluteMinimumPlayers = 1

------------------------------------------------------------
-- AUTOMATIC ROUND START
------------------------------------------------------------

-- Round begins after a random amount of time between
-- 10 and 15 seconds, regardless of player count.
GameConfig.AutoStartMinSeconds = 10
GameConfig.AutoStartMaxSeconds = 15

------------------------------------------------------------
-- OLD TIMER VALUES
------------------------------------------------------------

-- These remain here for compatibility with any older
-- RoundService code still referencing them.
--
-- They are harmless if the current RoundService does not
-- use them.
GameConfig.ForceStartAfterSeconds = 10
GameConfig.IntermissionSeconds = 5

------------------------------------------------------------
-- DRAMATIC ROUND COUNTDOWN
------------------------------------------------------------

-- Final dramatic countdown:
--
-- GAME IS ABOUT TO BEGIN
-- 3
-- 2
-- 1
-- GO!
GameConfig.RoundStartCountdownSeconds = 3

------------------------------------------------------------
-- RESULTS
------------------------------------------------------------

GameConfig.ResultsSeconds = 6

------------------------------------------------------------
-- SOLO PRACTICE
------------------------------------------------------------

-- If only one player exists when the round starts,
-- that player gets movement practice instead of a fake win.
GameConfig.SoloPracticeSeconds = 30

------------------------------------------------------------
-- MAP
------------------------------------------------------------

GameConfig.MapName = "Sky Garden"

------------------------------------------------------------
-- BOMB
------------------------------------------------------------

-- Normal bomb fuse.
GameConfig.NormalBombFuseSeconds = 14

-- Shorter fuse when only two players remain.
GameConfig.FinalDuelBombFuseSeconds = 9

-- Distance needed to pass the bomb.
GameConfig.BombTagRadius = 5

-- Stops the new bomb carrier from instantly returning
-- the bomb to the previous carrier.
GameConfig.AntiTagBackSeconds = 1.15

-- Prevents extremely fast multi-passes within one moment.
GameConfig.NewCarrierLockSeconds = 0.18

-- Pause after somebody explodes.
GameConfig.BetweenBombsSeconds = 1.5

------------------------------------------------------------
-- TAG DETECTION
------------------------------------------------------------

-- Roughly 33 checks per second.
GameConfig.TagCheckInterval = 0.03

------------------------------------------------------------
-- DEBUG
------------------------------------------------------------

GameConfig.DebugPrints = true

return GameConfig