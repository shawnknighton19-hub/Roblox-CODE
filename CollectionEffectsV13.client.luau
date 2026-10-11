--!nonstrict
-- HussCollectionEffectsV13: sculpted path trails with bounded local rendering; preserves titles, emotes and perfect-weave feedback.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Sound=game:GetService('SoundService')
local C=require(RS:WaitForChild('HussCatalogV11'))
local TrailDesigns=require(RS:WaitForChild('HussTrailDesignsV13'))
local me=Players.LocalPlayer
local states,links={},{}
local stopped,allocated=false,0
local V,CF=Vector3.new,CFrame.new
local folder=Instance.new('Folder');folder.Name='HussCollectionEffectsV13';folder.Parent=workspace
local MAX_TRAILS,MAX_DISTANCE,FADE_GRACE=10,90,(TrailDesigns.StopFade or .36)+.05
local function make(class,parent,props)
 local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o
end
local function link(signal,fn,bucket) table.insert(bucket or links,signal:Connect(fn)) end
local function clear(bucket) for _,c in ipairs(bucket) do c:Disconnect() end;table.clear(bucket) end
local function reduced() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function entry(s,attribute,category)
 local i=C.ById[s.p:GetAttribute(attribute)];return i and i.category==category and i or C.ById[C.Defaults[category]]
end
local function tint(i) return Color3.fromRGB(table.unpack(i.color)) end
local function destroyTrail(s)
 if not s.trail then return end
 s.trail.handle:Destroy();s.trail=nil;allocated-=1
end
local function poseEnd(s)
 if s.pose then for joint,original in pairs(s.pose.originals) do if joint.Parent then joint.C0=original end end;s.pose=nil end
end
local function reset(s)
 destroyTrail(s);poseEnd(s)
 if s.title then s.title:Destroy();s.title=nil end
 if s.burst then s.burst:Destroy();s.burst=nil end
 if s.hDeath then s.hDeath:Disconnect();s.hDeath=nil end
 clear(s.charLinks);s.character=nil;s.h=nil;s.root=nil;s.refreshParts=nil
end
local tones={1.45,1.9}
local cues={}
for n=1,2 do cues[n]=make('Sound',Sound,{Name='HussPerfectWeaveV11',SoundId='rbxasset://sounds/volume_slider.ogg',PlaybackSpeed=tones[n],Volume=0}) end
local cueSerial=0
local function cue()
 if me:GetAttribute('HussSFXMuted')==true then return end
 cueSerial+=1;local serial=cueSerial
 for n,sound in ipairs(cues) do task.delay((n-1)*.085,function()
  if stopped or serial~=cueSerial or me:GetAttribute('HussSFXMuted')==true then return end
  local group=Sound:FindFirstChild('HussSFXV6');sound.SoundGroup=group and group:IsA('SoundGroup') and group or nil
  sound.Volume=.22*(sound.SoundGroup and 1 or math.clamp(tonumber(me:GetAttribute('HussSFXVolume')) or .8,0,1));sound:Stop();sound:Play()
 end) end
end
link(me:GetAttributeChangedSignal('HussSFXMuted'),function() if me:GetAttribute('HussSFXMuted')==true then cueSerial+=1;for _,sound in ipairs(cues) do sound:Stop() end end end)
local function perfect(s)
 if not s.character or not s.root or not s.root.Parent then return end
 local stamp=s.character:GetAttribute('HussPerfectWeaveAt')
 if type(stamp)~='number' or stamp~=stamp or stamp==s.lastPerfect or math.abs(workspace:GetServerTimeNow()-stamp)>1 then return end
 s.lastPerfect=stamp;if s.p==me then cue() end
 if reduced() then return end
 local camera=workspace.CurrentCamera;if not camera or (camera.CFrame.Position-s.root.Position).Magnitude>100 then return end
 if s.burst then s.burst:Destroy() end
 s.burst=make('Highlight',s.character,{Name='HussPerfectWeave',Adornee=s.character,DepthMode=Enum.HighlightDepthMode.Occluded,FillColor=Color3.fromRGB(147,255,137),OutlineColor=Color3.new(1,1,1),FillTransparency=.85,OutlineTransparency=.2})
 s.burstUntil=os.clock()+.3
end
local function bindCharacter(s,c)
 reset(s);s.generation+=1;local generation=s.generation
 s.character=c;s.lastPerfect=c:GetAttribute('HussPerfectWeaveAt')
 local function refreshParts()
  if stopped or states[s.p]~=s or s.generation~=generation or s.p.Character~=c then return end
  local h=c:FindFirstChildOfClass('Humanoid');local root=c:FindFirstChild('HumanoidRootPart')
  if root and not root:IsA('BasePart') then root=nil end
  if s.root~=root then destroyTrail(s);poseEnd(s);s.root=root end
  if s.h~=h then
   if s.hDeath then s.hDeath:Disconnect();s.hDeath=nil end
   poseEnd(s);s.h=h
   if h then s.hDeath=h.Died:Connect(function() if s.h==h then reset(s) end end) end
  end
 end
 s.refreshParts=refreshParts
 link(c.DescendantAdded,function(o) if o.Name=='HumanoidRootPart' or o:IsA('Humanoid') then refreshParts() end end,s.charLinks)
 link(c:GetAttributeChangedSignal('HussPerfectWeaveAt'),function() if s.character==c then perfect(s) end end,s.charLinks)
 refreshParts()
end
local function add(p)
 if states[p] then return end
 local s={p=p,links={},charLinks={},generation=0};states[p]=s
 link(p.CharacterAdded,function(c) bindCharacter(s,c) end,s.links)
 link(p.CharacterRemoving,function() s.generation+=1;reset(s) end,s.links)
 if p.Character then bindCharacter(s,p.Character) end
end
local function remove(p) local s=states[p];if s then s.generation+=1;reset(s);clear(s.links);states[p]=nil end end
local function title(s)
 local i=entry(s,'HussTitleId','Titles')
 local head=s.character:FindFirstChild('Head')
 if s.title and (not head or not head:IsA('BasePart') or s.title.Parent~=head) then s.title:Destroy();s.title=nil end
 if not head or not head:IsA('BasePart') then return end
 if not s.title then
  s.title=make('BillboardGui',head,{Name='HussTitleV11',Adornee=head,Size=UDim2.fromOffset(240,34),StudsOffsetWorldSpace=V(0,2.15,0),MaxDistance=85,AlwaysOnTop=false})
  make('TextLabel',s.title,{Name='Title',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.FredokaOne,TextSize=20,TextStrokeTransparency=.05,TextStrokeColor3=Color3.fromRGB(12,19,28),TextColor3=tint(i),Text=i.name})
 end
 if s.title:GetAttribute('Item')~=i.id then s.title:SetAttribute('Item',i.id);s.title.Title.Text=i.name;s.title.Title.TextColor3=tint(i) end
end
local function trail(s,i)
 if s.trail and s.trail.id~=i.id then destroyTrail(s) end
 if s.trail then return s.trail end
 if allocated>=MAX_TRAILS then return end
 local handle=TrailDesigns.Create(folder,i,{Preview=false})
 local t={id=i.id,handle=handle,lastActive=os.clock()};s.trail=t;allocated+=1
 return t
end
local jointNames={RightShoulder='right',LeftShoulder='left',['Right Shoulder']='right',['Left Shoulder']='left',Waist='body',RootJoint='body',Neck='neck',RightHip='rightLeg',LeftHip='leftLeg',['Right Hip']='rightLeg',['Left Hip']='leftLeg'}
local function emote(s,now,near)
 local id=s.p:GetAttribute('HussEmotePlaying');local stamp=s.p:GetAttribute('HussEmoteStarted');local i=C.ById[id]
 local action=s.character:GetAttribute('MovementAction')
 if not near or not i or i.category~='Emotes' or type(stamp)~='number' or stamp~=stamp or s.p:GetAttribute('InRound')==true or s.h.MoveDirection.Magnitude>.05 or s.root.AssemblyLinearVelocity.Magnitude>2 or s.h.Sit or s.h.PlatformStand or (type(action)=='string' and action:sub(1,4)=='Dive' and action~='DiveEnd') then poseEnd(s);return end
 local age=workspace:GetServerTimeNow()-stamp;if age<0 or age>6.2 then poseEnd(s);return end
 if s.pose and (s.pose.id~=id or s.pose.stamp~=stamp) then poseEnd(s) end
 if not s.pose then
  local pose={id=id,stamp=stamp,originals={},joints={}};s.pose=pose
  for _,joint in ipairs(s.character:GetDescendants()) do if joint:IsA('Motor6D') and jointNames[joint.Name] then
   local key=jointNames[joint.Name]
   -- Prefer the R15 waist over its root joint. Never move the physical root.
   if key~='body' or joint.Name=='Waist' or not pose.joints.body then pose.joints[key]=joint end
   pose.originals[joint]=joint.C0
  end end
 end
 local wave=math.sin(age*7);local beat=math.sin(age*5);local step=math.sin(age*8)
 local angles={right=V(0,0,0),left=V(0,0,0),body=V(0,0,0),neck=V(0,0,0),rightLeg=V(0,0,0),leftLeg=V(0,0,0)}
 if i.style=='wave' then angles.right=V(0,0,2.25+wave*.25);angles.neck=V(0,0,.08)
 elseif i.style=='cheer' then angles.right=V(0,0,2.5+beat*.2);angles.left=V(0,0,-2.5-beat*.2);angles.body=V(.08*beat,0,0)
 elseif i.style=='salute' then angles.right=V(-.2,0,-2.6);angles.neck=V(-.08,0,0)
 elseif i.style=='shuffle' then angles.right=V(step*.4,0,.25);angles.left=V(-step*.4,0,-.25);angles.body=V(0,beat*.25,step*.1);angles.rightLeg=V(step*.15,0,0);angles.leftLeg=V(-step*.15,0,0)
 elseif i.style=='robot' then local tick=math.floor(age*3)%4;angles.right=V(tick%2==0 and -.8 or .4,0,.8);angles.left=V(tick%2==0 and .4 or -.8,0,-.8);angles.neck=V(0,(tick-1.5)*.16,0)
 elseif i.style=='victory' then angles.right=V(-.25,0,2.6);angles.left=V(-.25,0,-2.6);angles.body=V(.08*beat,0,beat*.14)
 elseif i.style=='spin' then angles.body=V(0,age*2.5,0);angles.right=V(0,0,1.25);angles.left=V(0,0,-1.25)
 elseif i.style=='charge' then angles.right=V(.5,0,.75);angles.left=V(.5,0,-.75);angles.body=V(-.12+beat*.025,0,0);angles.neck=V(.12,0,0) end
 local strength=math.min(1,age/.18)*(reduced() and .5 or 1)
 for name,joint in pairs(s.pose.joints) do if joint.Parent then local a=angles[name]*strength;local original=s.pose.originals[joint];joint.C0=CF(original.Position)*CFrame.Angles(a.X,a.Y,a.Z)*original.Rotation end end
end
link(Players.PlayerAdded,add);link(Players.PlayerRemoving,remove)
for _,p in ipairs(Players:GetPlayers()) do add(p) end
link(Run.Heartbeat,function(dt)
 local camera=workspace.CurrentCamera;local now=os.clock();local low=reduced()
 local candidates={}
 for _,s in pairs(states) do
  -- Streamed characters can lose/reacquire their root without CharacterAdded firing.
  if s.character and (not s.root or not s.root.Parent or not s.h or not s.h.Parent) and s.refreshParts then s.refreshParts() end
  if s.root and s.h and s.character and s.root.Parent and s.character:IsDescendantOf(workspace) then
   local distance=camera and (camera.CFrame.Position-s.root.Position).Magnitude or math.huge
   local near=distance<MAX_DISTANCE
   if s.burst and (low or now>=s.burstUntil) then s.burst:Destroy();s.burst=nil end
   if near and s.h.Health>0 then title(s) elseif s.title then s.title:Destroy();s.title=nil end
   emote(s,now,near)
   local v=s.root.AssemblyLinearVelocity;local speed=V(v.X,0,v.Z).Magnitude
   local i=entry(s,'HussTrailId','Trails')
   if s.trail and s.trail.id~=i.id then destroyTrail(s) end
   local safe=near and not low and speed<100 and s.h.Health>0 and not s.h.Sit and not s.h.PlatformStand and not s.root.Anchored and s.h.FloorMaterial~=Enum.Material.Air and s.character:GetAttribute('Ragdolled')~=true and s.character:GetAttribute('IsRagdoll')~=true and s.p:GetAttribute('HussGamePaused')~=true and workspace:GetAttribute('HussGamePaused')~=true
   local active=safe and speed>27
   if active or (safe and s.trail and now-s.trail.lastActive<FADE_GRACE) then
    table.insert(candidates,{s=s,item=i,active=active,distance=distance,velocity=v})
   end
  else
   destroyTrail(s);poseEnd(s)
   if s.title then s.title:Destroy();s.title=nil end
   if s.burst then s.burst:Destroy();s.burst=nil end
  end
 end
 -- Select before allocating, so a local player's trail cannot be crowded out by remotes.
 -- Running characters win over distant fading wakes; the nearest nine remotes get the budget.
 table.sort(candidates,function(a,b)
  if (a.s.p==me)~=(b.s.p==me) then return a.s.p==me end
  if a.active~=b.active then return a.active end
  if a.distance~=b.distance then return a.distance<b.distance end
  return a.s.p.UserId<b.s.p.UserId
 end)
 local selected,rendering={},{};local remoteCount=0
 for _,candidate in ipairs(candidates) do
  local localPlayer=candidate.s.p==me
  if localPlayer or remoteCount<MAX_TRAILS-1 then
   selected[candidate.s]=true;table.insert(rendering,candidate)
   if not localPlayer then remoteCount+=1 end
  end
 end
 for _,s in pairs(states) do if not selected[s] then destroyTrail(s) end end
 for _,candidate in ipairs(rendering) do
  local s=candidate.s;local t=trail(s,candidate.item)
  if t then
   if candidate.active then t.lastActive=now end
   t.handle:SetEnabled(candidate.active)
   t.handle:Step(s.root.CFrame,candidate.velocity,now,math.clamp(dt,0,.1))
  end
 end
end)
link(script.Destroying,function()
 stopped=true;cueSerial+=1;clear(links)
 local list={};for p in pairs(states) do table.insert(list,p) end;for _,p in ipairs(list) do remove(p) end
 for _,sound in ipairs(cues) do sound:Destroy() end;folder:Destroy()
end)
