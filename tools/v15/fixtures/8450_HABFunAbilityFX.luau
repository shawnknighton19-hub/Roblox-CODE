--!nonstrict
-- HAB_FUN_9. Cosmetic only; the ActionService decides unlocks, cooldowns and movement bonuses.
local RS=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local X=RS:WaitForChild('HABExpansion');local Config=require(X.Config)
local Render=require(RS:WaitForChild('HABHalloween').Renderer)
local me=Players.LocalPlayer
-- Remove Roblox's default emote menu as well; locomotion animations stay enabled.
local StarterGui=game:GetService('StarterGui')
task.spawn(function()
 for i=1,4 do
  local ok=pcall(StarterGui.SetCoreGuiEnabled,StarterGui,Enum.CoreGuiType.EmotesMenu,false)
  if ok then break end
  task.wait(.5)
 end
end)
local world=Instance.new('Folder');world.Name='HABFunAbilityCosmetics';world.Parent=workspace
local running={};local seen={};local sequence={};local connections={};local rng=Random.new()
local function low() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function part(name,cf,size,color,alpha,shape)
 local p=Instance.new('Part');p.Name=name;p.CFrame=cf;p.Size=size;p.Color=color;p.Transparency=alpha or .3
 p.Shape=shape or Enum.PartType.Ball;p.Material=Enum.Material.Neon;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=world
 return p
end
local function clear(g)
 for _,p in ipairs(g.Parts) do p:Destroy() end
 for _,h in ipairs(g.Handles) do h:Stop() end
 g.Parts={};g.Handles={}
end
local function copyBody(g,cf,disco)
 local rel=g.Root.CFrame
 for _,p in ipairs(g.Character:GetChildren()) do
  if p:IsA('BasePart') and p.Name~='HumanoidRootPart' and p.Name~='ActiveBomb' and p.Transparency<.95 then
   local ok,q=pcall(p.Clone,p)
   if not ok or not q then q=Instance.new('Part');q.Size=p.Size end
   q:ClearAllChildren();q.Name='CosmeticDecoy';q.Anchored=true;q.CanCollide=false;q.CanTouch=false;q.CanQuery=false;q.CastShadow=false
   q.Material=Enum.Material.Neon;q.Color=g.Def.Color;q.Transparency=.6;q.Parent=world
   q.CFrame=cf*rel:ToObjectSpace(p.CFrame)
   g.Parts[#g.Parts+1]=q;g.Decoys[#g.Decoys+1]={Part=q,Frame=q.CFrame,Disco=disco}
  end
 end
end
connections[#connections+1]=X.FX.OnClientEvent:Connect(function(e)
 if type(e)~='table' or e.Kind~='Ability' or type(e.Id)~='number' or type(e.Time)~='number' or math.abs(workspace:GetServerTimeNow()-e.Time)>2 or low() then return end
 if seen[e.Id] then return end;seen[e.Id]=true;sequence[#sequence+1]=e.Id;if #sequence>128 then seen[table.remove(sequence,1)]=nil end
 local c=typeof(e.Actor)=='Instance' and (e.Actor:IsA('Player') and e.Actor.Character or e.Actor:IsA('Model') and e.Actor)
 local root=c and c:FindFirstChild('HumanoidRootPart');local cam=workspace.CurrentCamera
 if not root or not cam or (root.Position-cam.CFrame.Position).Magnitude>110 then return end
 local def;for _,a in ipairs(Config.Abilities) do if a.Key==e.Ability then def=a;break end end;if not def then return end
 while #running>=(Input.TouchEnabled and 3 or 5) do clear(table.remove(running,1)) end
 local g={Root=root,Character=c,Def=def,Parts={},Decoys={},Handles={},At=os.clock(),Until=os.clock()+math.min(def.Duration or 1,3),EmitAt=0}
 if def.Key=='Decoy' then copyBody(g,root.CFrame*CFrame.new(0,0,1.7),false)
 elseif def.Key=='Disco' then copyBody(g,root.CFrame*CFrame.new(-2.6,0,.8),true);copyBody(g,root.CFrame*CFrame.new(2.6,0,.8),true) end
 if def.Key=='Bubble' or def.Key=='Jester' or def.Key=='Confetti' or def.Key=='Disco' then
  for i=1,(Input.TouchEnabled and 6 or 10) do
   local q=part('AbilityDecoration',root.CFrame,Vector3.new(.45,.45,.45),def.Color,.36,def.Key=='Confetti' and Enum.PartType.Block or Enum.PartType.Ball)
   g.Parts[#g.Parts+1]=q;g.Decoration=g.Decoration or {};g.Decoration[#g.Decoration+1]={Part=q,Phase=i*math.pi*.25,Radius=1.8+(i%3)*.25}
  end
 end
 running[#running+1]=g
end)
connections[#connections+1]=Run.Heartbeat:Connect(function()
 local now=os.clock()
 for i=#running,1,-1 do
  local g=running[i];local h=g.Character:FindFirstChildOfClass('Humanoid')
  if low() or not g.Root.Parent or not h or h.Health<=0 or now>g.Until or g.Character:GetAttribute('Ragdolled') then clear(g);table.remove(running,i)
  else
   local age=now-g.At;local alpha=math.clamp((now-(g.Until-.65))/.65,0,1)
   for _,d in ipairs(g.Decoys) do
    d.Part.CFrame=d.Frame*CFrame.new(0,d.Disco and math.sin(age*7)*.16 or 0,0)
    d.Part.Transparency=.6+alpha*.4
   end
   for j,d in ipairs(g.Decoration or {}) do
    local theta=d.Phase+age*(g.Def.Key=='Bubble' and .7 or 3.8)
    local height=g.Def.Key=='Jester' and 2.4 or g.Def.Key=='Disco' and -2.4 or math.sin(theta)*1.2
    d.Part.CFrame=g.Root.CFrame*CFrame.new(math.cos(theta)*d.Radius,height,math.sin(theta)*d.Radius)*CFrame.Angles(age*3,theta,theta*.5)
    d.Part.Transparency=.36+alpha*.64
   end
   if now>=g.EmitAt and g.Def.Key~='Leap' and g.Def.Key~='Pogo' then
    g.EmitAt=now+.7
    local ok,effect=pcall(Render.Play,g.Def.Effect,g.Root,6.2,Vector3.new(0,-.3,0),true,.24,false)
    if ok and effect then g.Handles[#g.Handles+1]=effect end
   end
  end
 end
end)
connections[#connections+1]=script.Destroying:Connect(function() for _,g in ipairs(running) do clear(g) end;for _,c in ipairs(connections) do c:Disconnect() end;world:Destroy() end)
