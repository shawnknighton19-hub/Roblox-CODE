--!nonstrict
-- HAB_MOTION_REPAIR_1: titles + modern-joint emotes + perfect-weave feedback. Legacy trail rendering is disabled.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Sound=game:GetService('SoundService')
local C=require(RS:WaitForChild('HussCatalogV11'))
local me=Players.LocalPlayer
local states,links={},{}
local stopped,allocated=false,0
local noticeGui
local V,CF=Vector3.new,CFrame.new
local folder=Instance.new('Folder');folder.Name='HussCollectionEffectsV11';folder.Parent=workspace
local variants={};local counts={}
for _,i in ipairs(C.Items) do if i.category=='Trails' then counts[i.style]=(counts[i.style] or 0)+1;variants[i.id]=counts[i.style] end end
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
 for _,o in ipairs(s.trail.objects) do o:Destroy() end;s.trail=nil;allocated-=1
end
local function poseEnd(s)
 if s.pose then
  for _,record in pairs(s.pose.joints) do
   local j=record.motor
   if record.before and j.Parent and j.Transform==record.applied then j.Transform=record.before end
  end
  s.pose=nil
 end
end
local function reset(s)
 destroyTrail(s);poseEnd(s)
 if s.title then s.title:Destroy();s.title=nil end
 if s.burst then s.burst:Destroy();s.burst=nil end
 clear(s.charLinks);s.character=nil;s.h=nil;s.root=nil
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
 task.spawn(function()
  local h=c:WaitForChild('Humanoid',10);local root=c:WaitForChild('HumanoidRootPart',10)
  if stopped or states[s.p]~=s or s.generation~=generation or s.p.Character~=c or not h or not root then return end
  s.character=c;s.h=h;s.root=root;s.lastPerfect=c:GetAttribute('HussPerfectWeaveAt')
  link(c:GetAttributeChangedSignal('HussPerfectWeaveAt'),function() if s.character==c then perfect(s) end end,s.charLinks)
  link(h.Died,function() reset(s) end,s.charLinks)
 end)
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
 local head=s.character:FindFirstChild('Head');if not head then return end
 if not s.title then
  s.title=make('BillboardGui',head,{Name='HussTitleV11',Adornee=head,Size=UDim2.fromOffset(240,34),StudsOffsetWorldSpace=V(0,2.15,0),MaxDistance=85,AlwaysOnTop=false})
  make('TextLabel',s.title,{Name='Title',BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Font=Enum.Font.FredokaOne,TextSize=20,TextStrokeTransparency=.05,TextStrokeColor3=Color3.fromRGB(12,19,28),TextColor3=tint(i),Text=i.name})
 end
 if s.title:GetAttribute('Item')~=i.id then s.title:SetAttribute('Item',i.id);s.title.Title.Text=i.name;s.title.Title.TextColor3=tint(i) end
end
local function trail(s,i)
 if s.trail and s.trail.id~=i.id then destroyTrail(s) end
 if s.trail then return s.trail end
 if allocated>=(s.p==me and 10 or 9) then return end;allocated+=1
 local t={id=i.id,objects={},nextEmit=0};s.trail=t
 local function obj(class,parent,props) local o=make(class,parent,props);table.insert(t.objects,o);return o end
 local color=tint(i);local variant=variants[i.id] or 1;local style=i.style
 local a=obj('Attachment',s.root,{Name='HussCollectionWake',Position=V(0,-1.5,.5)})
 t.emitter=obj('ParticleEmitter',a,{Name='CollectionTrail',Texture='rbxasset://textures/particles/'..((style=='smoke' or style=='bubbles' or style=='pulse') and 'smoke_main.dds' or 'sparkles_main.dds'),Enabled=false,Rate=0,
  Color=ColorSequence.new(color:Lerp(Color3.new(1,1,1),.3),color),LightEmission=style=='smoke' and .15 or .7,LightInfluence=.1,
  Lifetime=NumberRange.new(.16+variant*.025,.3+variant*.025),Speed=NumberRange.new(style=='sparks' and 3 or .5,style=='sparks' and 6 or 2),
  SpreadAngle=Vector2.new(style=='lightning' and 5 or 30+variant*5,style=='lightning' and 5 or 35),EmissionDirection=Enum.NormalId.Back,
  Acceleration=V(0,style=='bubbles' and 2 or style=='confetti' and -4 or 0,0),Drag=1,Rotation=NumberRange.new(0,360),RotSpeed=NumberRange.new(style=='confetti' and -120 or -20,style=='confetti' and 120 or 20),
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,style=='smoke' and .45 or style=='pulse' and .6 or .17+variant*.02),NumberSequenceKeypoint.new(1,style=='smoke' and 1.1 or style=='bubbles' and .4 or 0)}),
  Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,style=='smoke' and .72 or .2),NumberSequenceKeypoint.new(1,1)})})
 if style=='ribbon' or style=='lightning' or style=='pulse' then
  local b=obj('Attachment',s.root,{Name='HussCollectionEdge',Position=V(0,-1.3,.5)})
  t.ribbon=obj('Trail',s.root,{Name='CollectionRibbon',Attachment0=a,Attachment1=b,FaceCamera=true,Enabled=false,Lifetime=.12+variant*.018,MinLength=style=='lightning' and .65 or .1,MaxLength=8,
   Color=ColorSequence.new(color,Color3.new(1,1,1)),LightEmission=.8,Transparency=NumberSequence.new(.3,1),WidthScale=NumberSequence.new(1,0)})
 end
 -- Small geometry distinguishes bubbles, paper confetti and pulse discs without uploaded textures.
 if style=='bubbles' or style=='confetti' or style=='pulse' then
  t.shapes={}
  for n=1,3 do local p=obj('Part',folder,{Name='CollectionAccent',Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,Material=Enum.Material.Neon,
   Shape=style=='bubbles' and Enum.PartType.Ball or style=='pulse' and Enum.PartType.Cylinder or Enum.PartType.Block,
   Size=style=='bubbles' and V(.15,.15,.15) or style=='pulse' and V(.03,.36,.36) or V(.12,.04,.22),Color=color,Transparency=.35})
   table.insert(t.shapes,p)
  end
 end
 return t
end
-- HAB_MOTION_REPAIR_1: one visual emote layer, after Animator evaluation.
local jointRoles = {
 Torso='body', LowerTorso='body', UpperTorso='waist', Head='neck',
 ['Right Arm']='right', ['Left Arm']='left',
 RightUpperArm='right', LeftUpperArm='left',
 RightLowerArm='rightElbow', LeftLowerArm='leftElbow',
 RightHand='rightWrist', LeftHand='leftWrist',
 ['Right Leg']='rightLeg', ['Left Leg']='leftLeg',
 RightUpperLeg='rightLeg', LeftUpperLeg='leftLeg',
 RightLowerLeg='rightKnee', LeftLowerLeg='leftKnee',
}
local function emote(s,now,near)
 local id=s.p:GetAttribute('HussEmotePlaying')
 local stamp=s.p:GetAttribute('HussEmoteStarted')
 local i=C.ById[id]
 if not near or not i or i.category~='Emotes' or type(stamp)~='number' or stamp~=stamp
  or s.p:GetAttribute('InRound')==true or s.h.Health<=0 or s.h.Sit or s.h.PlatformStand
  or s.root.Anchored or s.character:GetAttribute('Ragdolled')==true
  or s.character:GetAttribute('IsRagdoll')==true then poseEnd(s);return end
 local age=workspace:GetServerTimeNow()-stamp
 if age<0 or age>6.2 then poseEnd(s);return end
 if s.pose and (s.pose.id~=id or s.pose.stamp~=stamp) then poseEnd(s) end
 if not s.pose then
  local pose={id=id,stamp=stamp,joints={}}
  for _,joint in ipairs(s.character:GetDescendants()) do
   if joint:IsA('Motor6D') or joint:IsA('AnimationConstraint') then
    local child=joint.Part1
    local key=child and jointRoles[child.Name]
    if key and not pose.joints[key] then pose.joints[key]={motor=joint} end
   end
  end
  s.pose=pose
  if not next(pose.joints) then
   if not s.missingJointWarn then warn('[HAB Emotes] No supported avatar joints for '..s.p.Name);s.missingJointWarn=true end
   poseEnd(s);return
  end
 end
 local wave=math.sin(age*7)
 local beat=math.sin(age*5)
 local step=math.sin(age*8)
 local a={}
 if i.style=='wave' then
  a.right=V(-.12,0,2.18+wave*.2);a.rightElbow=V(-.55,0,0);a.rightWrist=V(0,.18*wave,0);a.neck=V(0,-.08,.07)
 elseif i.style=='cheer' then
  a.right=V(-.12,0,2.55+beat*.18);a.left=V(-.12,0,-2.55-beat*.18);a.body=V(.035*beat,0,.025*beat)
 elseif i.style=='salute' then
  a.right=V(-.45,0,2.3);a.rightElbow=V(-1,0,.2);a.neck=V(-.1,0,0)
 elseif i.style=='shuffle' then
  a.right=V(step*.42,0,.25);a.left=V(-step*.42,0,-.25);a.body=V(0,beat*.18,step*.055)
  a.rightLeg=V(step*.14,0,0);a.leftLeg=V(-step*.14,0,0)
 elseif i.style=='robot' then
  local tick=math.floor(age*3)%4
  a.right=V(tick%2==0 and -.8 or .35,0,.75);a.left=V(tick%2==0 and .35 or -.8,0,-.75)
  a.rightElbow=V(-.8,0,0);a.leftElbow=V(-.8,0,0);a.neck=V(0,(tick-1.5)*.15,0)
 elseif i.style=='victory' then
  a.right=V(-.25,0,2.55);a.left=V(-.25,0,-2.55);a.body=V(.055*beat,0,beat*.08)
 elseif i.style=='spin' then
  a.body=V(0,age*2.5,0);a.right=V(0,0,1.3);a.left=V(0,0,-1.3)
 elseif i.style=='charge' then
  a.right=V(.5,0,.75);a.left=V(.5,0,-.75);a.rightElbow=V(-.7,0,0);a.leftElbow=V(-.7,0,0)
  a.body=V(-.08+beat*.015,0,0);a.neck=V(.1,0,0)
 end
 local strength=math.min(1,age/.2)*math.clamp((6.05-age)/.2,0,1)
 if reduced() then strength=strength*.45 end
 for role,record in pairs(s.pose.joints) do
  local joint=record.motor
  if joint.Parent and joint.Enabled then
   local angle=a[role] or V(0,0,0)
   local axes=joint.C0.Rotation
   local target=axes:Inverse()*CFrame.Angles(angle.X,angle.Y,angle.Z)*axes
   record.before=joint.Transform
   record.applied=record.before:Lerp(target,strength)
   joint.Transform=record.applied
  end
 end
end
link(Run.PreAnimation,function()
 for _,s in pairs(states) do
  if s.pose then
   for _,record in pairs(s.pose.joints) do
    local j=record.motor
    if record.before and j.Parent and j.Transform==record.applied then j.Transform=record.before end
    record.before=nil;record.applied=nil
   end
  end
 end
end)
link(Run.PreSimulation,function()
 local camera=workspace.CurrentCamera
 for _,s in pairs(states) do
  if s.root and s.root.Parent and s.character then
   emote(s,os.clock(),s.p==me or (camera and (camera.CFrame.Position-s.root.Position).Magnitude<120))
  end
 end
end)
link(Players.PlayerAdded,add);link(Players.PlayerRemoving,remove)
for _,p in ipairs(Players:GetPlayers()) do add(p) end
link(Run.Heartbeat,function()
 local camera=workspace.CurrentCamera;local now=os.clock();local low=reduced()
 for _,s in pairs(states) do if s.root and s.character and s.root.Parent then
  local near=camera and (camera.CFrame.Position-s.root.Position).Magnitude<90
  if s.burst and (low or now>=s.burstUntil) then s.burst:Destroy();s.burst=nil end
  if near and s.h.Health>0 then title(s) elseif s.title then s.title:Destroy();s.title=nil end
  local v=s.root.AssemblyLinearVelocity;local speed=V(v.X,0,v.Z).Magnitude
  local i=entry(s,'HussTrailId','Trails')
  local active=false -- HAB_MOTION_REPAIR_1: boost rendering belongs to MovementEffectsV8 now.
  if active then
   local t=trail(s,i)
   if t then
    if t.ribbon then t.ribbon.Enabled=true end
    if now>=t.nextEmit then t.emitter:Emit(i.style=='smoke' and 1 or 2);t.nextEmit=now+.09 end
    if t.shapes then for n,p in ipairs(t.shapes) do
     local lag=n*.045;local wave=math.sin(now*7+n)*.45
     p.CFrame=CF(s.root.Position-v*lag+V(wave,-1.25+n*.08,0))*CFrame.Angles(i.style=='pulse' and 0 or now*2,n,math.pi/2)
    end end
   end
  else destroyTrail(s) end
 end end
end)
link(script.Destroying,function()
 stopped=true;cueSerial+=1;if noticeGui then noticeGui:Destroy() end;clear(links)
 local list={};for p in pairs(states) do table.insert(list,p) end;for _,p in ipairs(list) do remove(p) end
 for _,sound in ipairs(cues) do sound:Destroy() end;folder:Destroy()
end)

-- Small, nonblocking feedback for server-rejected emote requests.
noticeGui=make('ScreenGui',me:WaitForChild('PlayerGui'),{Name='HABEmoteNotice',ResetOnSpawn=false,DisplayOrder=190})
local noticeLabel=make('TextLabel',noticeGui,{Name='Message',AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-86),Size=UDim2.new(.8,0,0,46),BackgroundColor3=Color3.fromRGB(21,27,35),BackgroundTransparency=.15,TextColor3=Color3.fromRGB(255,225,158),TextSize=15,Font=Enum.Font.GothamMedium,TextWrapped=true,Visible=false})
make('UICorner',noticeLabel,{CornerRadius=UDim.new(0,8)})
make('UISizeConstraint',noticeLabel,{MaxSize=Vector2.new(550,60)})
local noticeUntil=0
link(me:GetAttributeChangedSignal('HABEmoteNotice'),function()
 local message=me:GetAttribute('HABEmoteStatus')
 if type(message)=='string' and message~='' then noticeLabel.Text=message;noticeLabel.Visible=true;noticeUntil=os.clock()+3 end
end)
link(Run.Heartbeat,function() if noticeLabel.Visible and os.clock()>noticeUntil then noticeLabel.Visible=false end end)
