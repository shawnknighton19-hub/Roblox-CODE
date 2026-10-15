--!nonstrict
-- HAB_FUN_9. Local, bounded audio from a SERVER detonation or an explicit preview click.
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
assert(Run:IsClient(),'Sound renderer is client only')
local Debris=game:GetService('Debris')
local Sounds=game:GetService('SoundService')
local Definitions=require(script.Parent.HABKillSounds)
local me=Players.LocalPlayer
local M={};local active={};local previewAt=0
local function muted() return me:GetAttribute('HussSFXMuted')==true end
function M.Play(id,pos,preview)
 local def=Definitions.ById[id];if not def or muted() then return end
 if preview then if os.clock()<previewAt then return end;previewAt=os.clock()+.8 end
 for i=#active,1,-1 do if not active[i].Parent then table.remove(active,i) end end
 while #active>=4 do local h=table.remove(active,1);if h.Parent then h:Destroy() end end
 local host
 if typeof(pos)=='Vector3' then
  local cam=workspace.CurrentCamera;if not cam or (pos-cam.CFrame.Position).Magnitude>110 then return end
  host=Instance.new('Part');host.Name='HABKillSound';host.Size=Vector3.new(.1,.1,.1);host.CFrame=CFrame.new(pos)
  host.Anchored=true;host.CanCollide=false;host.CanQuery=false;host.CanTouch=false;host.Transparency=1;host.Parent=workspace
 else host=Instance.new('Folder');host.Name='HABSoundPreview';host.Parent=Sounds end
 active[#active+1]=host;Debris:AddItem(host,3)
 local cues=def.CustomId>0 and {{File='rbxassetid://'..def.CustomId,At=0,Pitch=1,Gain=1}} or def.Cues
 for _,cue in ipairs(cues) do
  task.delay(cue.At,function()
   if not host.Parent or muted() then return end
   local s=Instance.new('Sound');s.Name=def.Name;s.SoundId=cue.File;s.Volume=.34*cue.Gain*math.clamp(tonumber(me:GetAttribute('HussSFXVolume')) or .8,0,1)
   s.PlaybackSpeed=cue.Pitch;s.RollOffMinDistance=10;s.RollOffMaxDistance=95;s.RollOffMode=Enum.RollOffMode.InverseTapered
   s.Parent=host;s:Play()
  end)
 end
end
function M.Mount(parent,id)
 local def=Definitions.ById[id];if not def then return end
 local h={};local links={};local labels={};local open=true;local width=parent.AbsoluteSize.X
 local frame=Instance.new('Frame');frame.Name='KillSoundPreview';frame.BackgroundTransparency=1;frame.Size=UDim2.fromScale(1,1);frame.Parent=parent
 local name=Instance.new('TextLabel');name.BackgroundTransparency=1;name.Size=UDim2.new(1,-8,.26,0);name.Position=UDim2.fromOffset(4,3);name.Text='♪';name.Font=Enum.Font.FredokaOne;name.TextScaled=true;name.TextColor3=def.Color;name.ZIndex=parent.ZIndex+3;name.Parent=frame
 for i=1,11 do
  local bar=Instance.new('Frame');bar.BorderSizePixel=0;bar.AnchorPoint=Vector2.new(.5,.5);bar.Position=UDim2.fromScale(.12+(i-1)*.076,.47);bar.Size=UDim2.fromScale(.037,.12);bar.BackgroundColor3=def.Color;bar.ZIndex=parent.ZIndex+3;bar.Parent=frame
  local round=Instance.new('UICorner');round.CornerRadius=UDim.new(1,0);round.Parent=bar;labels[#labels+1]=bar
 end
 local button=Instance.new('TextButton');button.Name='PlayKillSound';button.Size=UDim2.new(.9,0,.24,0);button.Position=UDim2.fromScale(.05,.73);button.BackgroundColor3=def.Color
 button.Text='PLAY SOUND';button.Font=Enum.Font.FredokaOne;button.TextColor3=Color3.fromRGB(255,255,255);button.TextScaled=true;button.ZIndex=parent.ZIndex+5;button.Parent=frame
 local padding=Instance.new('UIPadding');padding.PaddingLeft=UDim.new(0,8);padding.PaddingRight=UDim.new(0,8);padding.PaddingTop=UDim.new(0,5);padding.PaddingBottom=UDim.new(0,5);padding.Parent=button
 local round=Instance.new('UICorner');round.CornerRadius=UDim.new(0,12);round.Parent=button
 links[#links+1]=button.Activated:Connect(function() M.Play(id,nil,true) end)
 local elapsed=0
 links[#links+1]=Run.RenderStepped:Connect(function(dt)
  elapsed+=dt;if elapsed<.05 then return end;elapsed=0
  if not frame.Parent then h:Stop();return end
  local low=me:GetAttribute('HussReducedMotion')==true
  for i,bar in ipairs(labels) do bar.Size=UDim2.fromScale(.037,low and .15 or .08+math.abs(math.sin(os.clock()*2.5+i*.8))*.22) end
 end)
 function h:Stop() if not open then return end;open=false;for _,l in ipairs(links) do l:Disconnect() end;frame:Destroy() end
 return h
end
return M
