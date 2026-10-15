--!nonstrict
-- HAB FUN 9. Eight starter sound recipes, made from the existing game's Roblox built-in samples.
-- Custom licensed audio IDs override each recipe through HABExpansion.Config.CustomKillAudio.
local C=require(script.Parent.Parent.HABExpansion.Config)
local M={Items={},ById={}}
local function cue(file,at,pitch,gain) return {File='rbxasset://sounds/'..file,At=at,Pitch=pitch,Gain=gain} end
local function add(id,name,color,cues,exclusive)
 local a={Id=id,Name=name,Color=color,Cues=cues,Exclusive=exclusive==true,CustomId=C.CustomKillAudio and C.CustomKillAudio[id] or 0,Duration=2.2}
 M.Items[#M.Items+1]=a;M.ById[id]=a
end
add('ks_pop','Cartoon Pop',Color3.fromRGB(255,164,112),{cue('action_jump_land.mp3',0,1.7,.8),cue('volume_slider.ogg',.045,1.45,.5)})
add('ks_boop','Tiny Boop',Color3.fromRGB(127,231,235),{cue('volume_slider.ogg',0,1.65,.7)})
add('ks_victory','Victory Chimes',Color3.fromRGB(255,220,110),{cue('volume_slider.ogg',0,1,.55),cue('volume_slider.ogg',.11,1.25,.55),cue('volume_slider.ogg',.23,1.5,.6)})
add('ks_bonk','Bonk!',Color3.fromRGB(199,149,255),{cue('action_jump_land.mp3',0,.65,1),cue('volume_slider.ogg',.05,.65,.32)})
add('ks_spring','Spring Squeak',Color3.fromRGB(144,234,135),{cue('action_jump.mp3',0,.82,.7),cue('volume_slider.ogg',.13,1.65,.38)})
add('ks_arcade','Arcade Clear',Color3.fromRGB(110,171,255),{cue('volume_slider.ogg',0,1.5,.5),cue('volume_slider.ogg',.09,1.1,.5),cue('volume_slider.ogg',.2,1.75,.55)})
add('ks_fizzle','Fuse Fizzle',Color3.fromRGB(255,137,183),{cue('action_get_up.mp3',0,.68,.8),cue('action_jump_land.mp3',.2,1.9,.35)})
add('ks_drum','Comedy Thump',Color3.fromRGB(247,202,128),{cue('action_jump_land.mp3',0,.72,.65),cue('action_jump_land.mp3',.14,1.3,.65),cue('volume_slider.ogg',.25,1.2,.3)})
local recipes={Phantom={cue('volume_slider.ogg',0,.65,.65),cue('action_get_up.mp3',.13,.8,.5)},Solar={cue('action_jump_land.mp3',0,1.4,.7),cue('volume_slider.ogg',.09,1.75,.5)},Cyber={cue('volume_slider.ogg',0,1.8,.6),cue('volume_slider.ogg',.09,1.35,.6)},Glacier={cue('volume_slider.ogg',0,1.3,.5),cue('volume_slider.ogg',.15,1.6,.55)}}
for _,b in ipairs(C.Bundles) do for _,fx in ipairs(b.Items) do if fx.Slot=='KillFX' then add(fx.Id,fx.Name,b.Color,recipes[b.Key] or recipes.Cyber,true) end end end
return M
