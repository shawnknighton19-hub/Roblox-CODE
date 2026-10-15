--!nonstrict

local AnimationConfig = {}

------------------------------------------------------------
-- IMPORTANT
------------------------------------------------------------

-- Paste animations that your Roblox experience has
-- permission to use.
--
-- You can paste either:
--
-- "1234567890"
--
-- or:
--
-- "rbxassetid://1234567890"
--
-- Leave an ID blank and that custom animation will simply
-- be skipped.
--
-- Roblox's normal Animate script will still handle basic
-- idle/walk movement when custom tracks are blank.

------------------------------------------------------------
-- LOCOMOTION
------------------------------------------------------------

AnimationConfig.SprintAnimationId = ""

------------------------------------------------------------
-- SLIDE
------------------------------------------------------------

AnimationConfig.SlideStartAnimationId = ""
AnimationConfig.SlideLoopAnimationId = ""
AnimationConfig.SlideEndAnimationId = ""

------------------------------------------------------------
-- DODGE / WEAVE
------------------------------------------------------------

AnimationConfig.WeaveLeftAnimationId = ""
AnimationConfig.WeaveRightAnimationId = ""
AnimationConfig.WeaveForwardAnimationId = ""
AnimationConfig.WeaveBackAnimationId = ""

------------------------------------------------------------
-- AIR
------------------------------------------------------------

AnimationConfig.JumpAnimationId = ""
AnimationConfig.FallAnimationId = ""
AnimationConfig.LandAnimationId = ""

------------------------------------------------------------
-- BLENDING
------------------------------------------------------------

AnimationConfig.DefaultFadeTime = 0.08

AnimationConfig.WeaveFadeTime = 0.04
AnimationConfig.SlideFadeTime = 0.06

------------------------------------------------------------
-- SLIDE
------------------------------------------------------------

-- How soon after SlideStart the loop may take over.
AnimationConfig.SlideLoopDelay = 0.16

------------------------------------------------------------
-- ANIMATION SPEED REFERENCES
------------------------------------------------------------

-- The sprint animation plays at normal speed around this
-- movement speed.
AnimationConfig.SprintReferenceSpeed = 34

-- Slide loop playback changes slightly with physical
-- movement speed.
AnimationConfig.SlideReferenceSpeed = 32

------------------------------------------------------------
-- CAMERA DODGE POLISH
------------------------------------------------------------

-- This works even before you upload custom animations.
AnimationConfig.EnableWeaveCameraTilt = true

AnimationConfig.WeaveCameraRollDegrees = 3.5
AnimationConfig.WeaveCameraPitchDegrees = 1.5

AnimationConfig.WeaveCameraEffectDuration = 0.24

return AnimationConfig