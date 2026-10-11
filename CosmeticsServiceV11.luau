--!nonstrict
-- HussCosmeticsV11: owned cosmetics and stationary lobby emotes; never changes movement.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local C=require(RS:WaitForChild('HussCatalogV11'))
local S={};local states={};local started=false
local V,CF=Vector3.new,CFrame.new
local function item(p,attribute,category)
 local entry=p and C.ById[p:GetAttribute(attribute)]
 return entry and entry.category==category and entry or C.ById[C.Defaults[category]]
end
function S.ApplyBomb(player,bomb)
 if not bomb or not bomb:IsA('BasePart') then return end
 local old=bomb:FindFirstChild('HussBombSkin');if old then old:Destroy() end
 local skin=item(player,'HussBombId','Bombs');local color=Color3.fromRGB(table.unpack(skin.color))
 local folder=Instance.new('Folder');folder.Name='HussBombSkin';folder.Parent=bomb
 bomb:SetAttribute('HussBombId',skin.id);bomb.Color=color;bomb.Material=Enum.Material.Metal;bomb.Reflectance=.12;bomb.Transparency=0
 if bomb:IsA('Part') then bomb.Shape=skin.style=='gift' and Enum.PartType.Block or Enum.PartType.Ball end
 local white=Color3.fromRGB(255,242,185);local dark=Color3.fromRGB(27,30,39);local gold=Color3.fromRGB(255,208,51)
 local function part(name,position,size,tint,shape,material,rotation)
  local p=Instance.new('Part');p.Name=name;p.Shape=shape or Enum.PartType.Block;p.Size=size;p.Color=tint;p.Material=material or Enum.Material.Metal
  p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Anchored=false
  p.CFrame=bomb.CFrame*CF(position)*(rotation or CFrame.identity);p.Parent=folder
  local weld=Instance.new('WeldConstraint');weld.Part0=bomb;weld.Part1=p;weld.Parent=p;return p
 end
 local function bead(position,tint,size) return part('Accent',position,V(size,size,size),tint,Enum.PartType.Ball) end
 local function ring(tint,radius,tilt,y)
  local axis=CFrame.Angles(tilt or 0,0,0)
  for n=0,9 do local angle=n*math.pi/5;local point=axis:PointToWorldSpace(V(math.cos(angle)*radius,0,math.sin(angle)*radius))+V(0,y or 0,0)
   part('Ring',point,V(.14,.14,radius*.66),tint,nil,Enum.Material.Neon,axis*CFrame.Angles(0,-angle,0))
  end
 end
 local function studs(count,tint,radius,size)
  for n=0,count-1 do local a=n*math.pi*2/count;bead(V(math.cos(a)*radius,0,math.sin(a)*radius),tint,size) end
 end
 -- Every skin keeps a visible fuse and the game's original red carrier warning.
 part('FuseSocket',V(0,1.08,0),V(.42,.2,.42),dark,Enum.PartType.Cylinder,nil,CFrame.Angles(0,0,math.pi/2))
 part('Fuse',V(.1,1.36,0),V(.16,.5,.16),gold,nil,nil,CFrame.Angles(0,0,-.3))
 part('FuseTip',V(.18,1.63,0),V(.22,.22,.22),white,Enum.PartType.Ball,Enum.Material.Neon)
 local style,id=skin.style,skin.id
 if style=='banded' then ring(id=='bomb_bee' and dark or id=='bomb_candy' and white or gold,1.14,0,0)
 elseif style=='hazard' then
  for n=0,7 do local a=n*math.pi/4;part('WarningStripe',V(math.cos(a)*1.05,0,math.sin(a)*1.05),V(.26,.62,.1),dark,nil,nil,CFrame.Angles(0,math.pi/2-a,.35)) end
 elseif style=='panel' then
  for n=0,7 do local a=n*math.pi/4;local tint=id=='bomb_disco' and Color3.fromHSV(n/8,.65,1) or color:Lerp(white,n%2==0 and .55 or .15)
   part('Facet',V(math.cos(a)*.99,0,math.sin(a)*.99),V(.64,.85,.14),tint,nil,Enum.Material.Glass,CFrame.Angles(0,math.pi/2-a,0))
  end
 elseif style=='orb' then
  bomb.Material=Enum.Material.Glass;bomb.Transparency=.38
  part('InnerCore',V(0,0,0),V(1.5,1.5,1.5),color,Enum.PartType.Ball,Enum.Material.Neon);studs(6,white,1.12,.21)
 elseif style=='ring' then ring(id=='bomb_royal' and gold or color:Lerp(white,.5),1.45,.45,0)
 elseif style=='spike' then
  for n=0,7 do local a=n*math.pi/4;part('BluntStud',V(math.cos(a)*1.13,0,math.sin(a)*1.13),V(.35,.35,.48),color:Lerp(dark,.45),nil,nil,CFrame.Angles(0,math.pi/2-a,.35)) end
 elseif style=='gift' then
  part('RibbonX',V(0,0,0),V(2.29,2.29,.3),gold);part('RibbonZ',V(0,0,0),V(.3,2.29,2.29),gold)
  part('BowLeft',V(-.3,1.27,0),V(.55,.17,.4),white,nil,nil,CFrame.Angles(0,0,-.3));part('BowRight',V(.3,1.27,0),V(.55,.17,.4),white,nil,nil,CFrame.Angles(0,0,.3))
 elseif style=='reactor' then
  bomb.Material=Enum.Material.Neon
  for n=0,5 do local a=n*math.pi/3;part('Cage',V(math.cos(a)*.86,0,math.sin(a)*.86),V(.19,1.86,.19),dark) end
  part('CapTop',V(0,.9,0),V(1.35,.22,1.35),dark);part('CapBottom',V(0,-.9,0),V(1.35,.22,1.35),dark)
 end
 -- Distinct details separate same-family shells, rather than relying on recolors alone.
 if id=='bomb_cherry' then part('Leaf',V(.54,1.17,0),V(.72,.1,.36),Color3.fromRGB(86,185,64),nil,nil,CFrame.Angles(0,0,.3))
 elseif id=='bomb_cobalt' then studs(4,white,1.17,.18)
 elseif id=='bomb_mint' then part('MintStripe',V(0,0,0),V(.18,2.29,2.29),white)
 elseif id=='bomb_candy' then studs(5,white,1.16,.25)
 elseif id=='bomb_orange' then part('CitrusLeaf',V(-.35,1.09,0),V(.55,.12,.35),Color3.fromRGB(94,184,58))
 elseif id=='bomb_arctic' then part('IceCrystal',V(0,-.92,0),V(.6,.6,.6),white,nil,Enum.Material.Glass,CFrame.Angles(.4,.4,.4))
 elseif id=='bomb_toxic' then bead(V(0,0,1.13),dark,.45)
 elseif id=='bomb_royal' or id=='bomb_champion' then for n=-1,1 do part('CrownPoint',V(n*.46,1.15,-.4),V(.2,.55,.22),gold,nil,nil,CFrame.Angles(0,0,n*-.3)) end
 elseif id=='bomb_bee' then for _,side in ipairs({-1,1}) do local wing=part('Wing',V(side*.9,.65,0),V(.6,.14,1.1),white,Enum.PartType.Ball,Enum.Material.Glass,CFrame.Angles(0,0,side*.35));wing.Transparency=.4 end
 elseif id=='bomb_prism' then bomb.Material=Enum.Material.Glass;bomb.Transparency=.2;part('CrystalTip',V(0,-1.05,0),V(.58,.58,.58),white,nil,Enum.Material.Glass,CFrame.Angles(.6,.4,.8))
 elseif id=='bomb_saturn' then studs(3,dark,1.08,.2)
 elseif id=='bomb_abyss' then bomb.Color=dark;bomb.Transparency=.55;ring(color,1.14,1.2,0)
 elseif id=='bomb_plasma' then ring(color:Lerp(white,.5),1.16,0,0)
 elseif id=='bomb_sakura' then for n=0,4 do local a=n*math.pi*.4;bead(V(math.cos(a)*.33,math.sin(a)*.33,1.02),white,.38) end
 elseif id=='bomb_gold' then bomb.Reflectance=.38;studs(6,white,1.15,.15)
 elseif id=='bomb_void' then bomb.Color=dark;bead(V(0,0,1.08),color,.64)
 elseif id=='bomb_solar' then studs(6,gold,1.15,.25)
 elseif id=='bomb_nova' then ring(Color3.fromRGB(122,238,255),1.35,-.7,0) end
end
local function stop(p)
 local s=states[p];if s then s.active=nil end
 p:SetAttribute('HussEmotePlaying',nil);p:SetAttribute('HussEmoteStarted',nil)
end
local function stationary(p)
 local c=p.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local r=c and c:FindFirstChild('HumanoidRootPart')
 if not h or not r or h.Health<=0 or p:GetAttribute('InRound')==true or h.MoveDirection.Magnitude>.05 or r.AssemblyLinearVelocity.Magnitude>2 or h.Sit or h.PlatformStand or r.Anchored or h.FloorMaterial==Enum.Material.Air then return end
 if p:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true or c:GetAttribute('Ragdolled')==true or c:GetAttribute('IsRagdoll')==true then return end
 local action=c:GetAttribute('MovementAction');if type(action)=='string' and action:sub(1,4)=='Dive' and action~='DiveEnd' then return end
 return c,h,r
end
function S.Init()
 if started then return end;started=true
 local remote=RS:FindFirstChild('HussCosmeticsV11') or Instance.new('RemoteEvent');assert(remote:IsA('RemoteEvent'),'HussCosmeticsV11 must be a RemoteEvent');remote.Name='HussCosmeticsV11';remote.Parent=RS
 local function add(p) states[p]={nextAt=0};stop(p) end
 Players.PlayerAdded:Connect(add);Players.PlayerRemoving:Connect(function(p) states[p]=nil end)
 for _,p in ipairs(Players:GetPlayers()) do add(p) end
 remote.OnServerEvent:Connect(function(p,action,id)
  local s=states[p];if not s then return end
  if action=='StopEmote' then if s.active then stop(p) end;return end
  if action~='Emote' or os.clock()<s.nextAt or p:GetAttribute('HussEconomyReady')~=true then return end
  local equipped=p:GetAttribute('HussEmoteId');local entry=C.ById[equipped]
  if not entry or entry.category~='Emotes' or (id~=nil and id~=equipped) then return end
  local c,h,r=stationary(p);if not c then return end
  s.nextAt=os.clock()+1.25;s.active={character=c,health=h.Health,position=r.Position,untilAt=os.clock()+6}
  p:SetAttribute('HussEmoteStarted',workspace:GetServerTimeNow());p:SetAttribute('HussEmotePlaying',equipped)
 end)
 local elapsed=0
 Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<.1 then return end;elapsed=0
  for p,s in pairs(states) do if s.active then
   local c,h,r=stationary(p);local a=s.active
   if not c or c~=a.character or h.Health<a.health or (r.Position-a.position).Magnitude>.3 or os.clock()>=a.untilAt then stop(p) end
  end end
 end)
end
return S
