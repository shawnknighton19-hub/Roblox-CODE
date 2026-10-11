--!nonstrict
-- HUSS A BOMB V6. Original sample-based score; optional owned music IDs on workspace.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local SoundService=game:GetService('SoundService')
local P=Players.LocalPlayer
local Remotes=require(RS:WaitForChild('Shared'):WaitForChild('Net'):WaitForChild('Remotes'))
Remotes.Init()
local net=RS.Shared.Net:WaitForChild('DodgeIFrameRequest')
local function make(class,parent,props)
 local o=Instance.new(class);for k,v in pairs(props or {}) do o[k]=v end;o.Parent=parent;return o
end
local old=SoundService:FindFirstChild('HussAudioV6')
if old then local stop=old:FindFirstChild('Stop');if stop then stop:Fire() end;old:Destroy() end
local root=make('Folder',SoundService,{Name='HussAudioV6'})
local music=make('SoundGroup',SoundService,{Name='HussMusicV6',Volume=0})
local sfx=make('SoundGroup',SoundService,{Name='HussSFXV6',Volume=.8})
-- These filenames occur in the current Roblox deployment manifest; no external IDs required.
local asset={tone='volume_slider.ogg',hit='action_jump_land.mp3',swish='action_get_up.mp3',click='action_jump.mp3',boom='impact_explosion_03.mp3'}
local links,people,ui,legacy,legacyGroups,queue={},{},{},{},{},{}
local voices,musicVoices,legacyAudio,stepVoices={},{},{},{}
local stopped,phase,scene,sceneAt,lastStep=false,'WAITING','',0,-1
local bomb,owner,fuseEnd,lastTick=false,0,0,nil
local modal,lastCount,lastNotice=false,nil,{}
local voteRemote,voteLink=nil,nil
local function finite(n,f) return type(n)=='number' and n==n and math.abs(n)<math.huge and n or f end
local function link(signal,fn,bucket) local c=signal:Connect(fn);table.insert(bucket or links,c);return c end
local function clear(bucket) for _,c in ipairs(bucket) do c:Disconnect() end;table.clear(bucket) end
local function volume(attr,fallback) return math.clamp(finite(P:GetAttribute(attr),fallback),0,1) end
local function playing() return P:GetAttribute('InRound')==true end
local function rate(key,period)
 local now=os.clock();if now-(lastNotice[key] or -math.huge)<period then return false end;lastNotice[key]=now;return true
end
local function sound(group)
 return make('Sound',root,{SoundGroup=group,Volume=0,RollOffMode=Enum.RollOffMode.InverseTapered,RollOffMinDistance=8,RollOffMaxDistance=95})
end
for i=1,20 do voices[i]={sound=sound(sfx),group=sfx,untilAt=0} end
-- HussFootstepsV8
for i=1,12 do stepVoices[i]={sound=sound(sfx),group=sfx,untilAt=0} end
-- Music uses OwnedMusic; no synthetic note pool.
local gain={tone=1.5,hit=3,swish=6,click=3,boom=.7,step=1}
local function play(pool,key,level,speed,lifetime,parent,offset)
 level*=gain[key] or 1
 local now=os.clock();local chosen=pool[1]
 for _,voice in ipairs(pool) do if voice.untilAt<=now then chosen=voice;break elseif voice.untilAt<chosen.untilAt then chosen=voice end end
 if not chosen.sound.Parent then chosen.sound=sound(chosen.group) end
 local v=chosen.sound;v:Stop();v.Parent=parent and parent.Parent and parent or root
 v.Name='Huss_'..key;v.SoundId='rbxasset://sounds/'..asset[key];v.PlaybackSpeed=speed or 1;v.Volume=level;v.TimePosition=offset or 0
 chosen.untilAt=now+(lifetime or 1);chosen.started=now;chosen.level=level;v:Play()
end
local function cue(key,level,speed,parent)
 if stopped or P:GetAttribute('HussSFXMuted')==true then return end
 play(voices,key,level or .16,speed or 1,key=='boom' and 2.8 or 1,parent)
end
local function phrase(notes,level)
 for i,n in ipairs(notes) do table.insert(queue,{at=os.clock()+(i-1)*.09,note=n,level=level or .18}) end
end
local function nativeRunning(o)
 if o.Name~='Running' then return false end
 local p=o.Parent
 while p and p~=workspace do
  if p:IsA('Model') and Players:GetPlayerFromCharacter(p) then return true end
  p=p.Parent
 end
 return false
end
local function audioLevel(o,saved)
 saved.applied=nativeRunning(o) and 0 or saved.level*(saved.player and sfx.Volume or 1)
 if o.Volume~=saved.applied then o.Volume=saved.applied end
end
local function settings()
 sfx.Volume=P:GetAttribute('HussSFXMuted')==true and 0 or volume('HussSFXVolume',.8)
 for group,value in pairs(legacyGroups) do if group.Parent then group.Volume=value*sfx.Volume end end
 for o,saved in pairs(legacyAudio) do if o.Parent then audioLevel(o,saved) end end
 if P:GetAttribute('HussMusicMuted')==true then music.Volume=0 end
 if P:GetAttribute('HussSFXMuted')==true then table.clear(queue) end
end
local function adopt(o)
 if o:IsA('Sound') and (o.SoundGroup==sfx or o.SoundGroup==music) then return end
 if (o:IsA('AudioPlayer') or o:IsA('Sound')) and not legacyAudio[o] then
  local saved={level=o.Volume,player=o:IsA('AudioPlayer')};legacyAudio[o]=saved
  saved.name=o:GetPropertyChangedSignal('Name'):Connect(function() audioLevel(o,saved) end)
  saved.link=o:GetPropertyChangedSignal('Volume'):Connect(function() if o.Volume~=saved.applied then saved.level=o.Volume;audioLevel(o,saved) end end)
  audioLevel(o,saved)
 end
 if not o:IsA('Sound') or o.SoundGroup==sfx or o.SoundGroup==music or legacy[o] then return end
 local group=o.SoundGroup
 legacy[o]={group=group}
 if group then
  while group.Parent and group.Parent:IsA('SoundGroup') do group=group.Parent end
  if not legacyGroups[group] then legacyGroups[group]=group.Volume;group.Volume*=sfx.Volume end
 else o.SoundGroup=sfx end
end
for _,o in ipairs(workspace:GetDescendants()) do adopt(o) end
link(workspace.DescendantAdded,adopt)
link(workspace.DescendantRemoving,function(o)
 if legacy[o] then local saved=legacy[o];if o.SoundGroup==sfx then o.SoundGroup=saved.group end;legacy[o]=nil end
 if legacyAudio[o] then local saved=legacyAudio[o];saved.link:Disconnect();saved.name:Disconnect();o.Volume=saved.level;legacyAudio[o]=nil end
end)
local function targetScene()
 if not playing() then return 'Lobby' end
 if phase=='FINAL_DUEL' then return 'Duel' end
 if phase=='ROUND' or phase=='STARTING' or phase=='PRACTICE' then return 'Chase' end
 return 'Lobby'
end
local custom=sound(music);custom.Name='OwnedMusic';custom.Looped=true
local customId=''
-- HussMusicV7: full tracks only; final duel reuses Chase when unset.
local function readMusicId(name)
 local value=workspace:GetAttribute('Huss'..name..'MusicId')
 if type(value)=='number' then
  if not finite(value) or value<=0 or value%1~=0 or value>9007199254740991 then return '' end
  value=string.format('%.0f',value)
 end
 if type(value)~='string' then return '' end
 local digits=value:match('^rbxassetid://(%d+)$') or value:match('^(%d+)$')
 local id=digits and tonumber(digits)
 return id and finite(id) and id>0 and id<=9007199254740991 and 'rbxassetid://'..digits or ''
end
local function configured(name)
 local id=readMusicId(name)
 if id~='' then return id end
 if name=='Duel' then return readMusicId('Chase') end
 return ''
end
local function updateScene()
 local nextScene=targetScene();local id=configured(nextScene)
 if scene==nextScene and customId==id then return end
 scene=nextScene;root:SetAttribute('Scene',scene)
 if customId==id then return end -- Keep the same song playing across phase changes.
 customId=id;sceneAt=os.clock();lastStep=-1
 custom:Stop();custom.SoundId=id;custom.Volume=0
 for _,v in ipairs(musicVoices) do v.sound:Stop();v.untilAt=0 end
 if id~='' then custom:Play() end
 root:SetAttribute('Scene',scene)
end
local actions={DiveForward=true,DiveBack=true,DiveLeft=true,DiveRight=true,DiveForwardLeft=true,DiveForwardRight=true,DiveBackLeft=true,DiveBackRight=true}
local function dodge(player,action)
 if not actions[action] or not rate('dodge'..player.UserId,.15) then return end
 local c=player.Character;local r=c and c:FindFirstChild('HumanoidRootPart')
 if people[player] then
  people[player].dodgeUntil=os.clock()+.72
  if player==P then people[player].readyAt=os.clock()+1.5 end
 end
 cue('swish',player==P and .3 or .19,action:find('Back') and 1.3 or 1.6,r)
 cue('hit',player==P and .065 or .04,1.4,r)
end
local function disconnectCharacter(record)
 clear(record.charLinks)
 if record.foot then record.foot:Destroy();record.foot=nil end
 record.character=nil;record.humanoid=nil;record.root=nil;record.readyAt=nil;record.nextStep=nil;record.dodgeUntil=nil
end
local function bindCharacter(player,c)
 local record=people[player];if not record then return end
 disconnectCharacter(record);record.character=c
 if not c then return end
 local function discover(o)
  if o:IsA('Humanoid') then record.humanoid=o elseif o.Name=='HumanoidRootPart' and o:IsA('BasePart') then record.root=o end
 end
 for _,o in ipairs(c:GetChildren()) do discover(o) end
 for _,o in ipairs(c:GetDescendants()) do local saved=legacyAudio[o];if saved then audioLevel(o,saved) else adopt(o) end end
 link(c.ChildAdded,discover,record.charLinks)
 if player==P then link(c:GetAttributeChangedSignal('MovementActionId'),function() dodge(player,c:GetAttribute('MovementAction')) end,record.charLinks) end
end
local function addPlayer(player)
 if people[player] then return end
 local record={player=player,links={},charLinks={}};people[player]=record
 link(player.CharacterAdded,function(c) bindCharacter(player,c) end,record.links)
 link(player.CharacterRemoving,function() disconnectCharacter(record) end,record.links)
 if player.Character then bindCharacter(player,player.Character) end
end
local function removePlayer(player)
 local record=people[player];if not record then return end
 disconnectCharacter(record);clear(record.links);people[player]=nil
end
link(Players.PlayerAdded,addPlayer);link(Players.PlayerRemoving,removePlayer)
for _,player in ipairs(Players:GetPlayers()) do addPlayer(player) end
link(net.OnClientEvent,function(player,action,stamp)
 if player~=P and people[player] and finite(stamp) and math.abs(workspace:GetServerTimeNow()-stamp)<.7 then dodge(player,action) end
end)
local soft={Grass=true,Ground=true,Sand=true,Snow=true,Fabric=true,LeafyGrass=true,Mud=true}
local metal={Metal=true,DiamondPlate=true,CorrodedMetal=true}
local function feet()
 local now=os.clock();local camera=workspace.CurrentCamera;local candidates={}
 for _,record in pairs(people) do
  local c,h,r=record.character,record.humanoid,record.root
  local distance=camera and r and (camera.CFrame.Position-r.Position).Magnitude or math.huge
  local mode=h and h:GetState()
  local velocity=r and r.AssemblyLinearVelocity
  local valid=c and c.Parent and h and h.Parent==c and r and r.Parent and h.Health>0 and not r.Anchored
   and Vector3.new(velocity.X,0,velocity.Z).Magnitude>5
   and not h.Sit and not h.PlatformStand and distance<48 and sfx.Volume>0
   and (mode==Enum.HumanoidStateType.Running or mode==Enum.HumanoidStateType.RunningNoPhysics or mode==Enum.HumanoidStateType.Landed)
   and c:GetAttribute('MovementState')~='Dive' and c:GetAttribute('MovementState')~='Locked'
   and c:GetAttribute('Ragdolled')~=true and c:GetAttribute('IsRagdoll')~=true
   and record.player:GetAttribute('HussGamePaused')~=true and workspace:GetAttribute('HussGamePaused')~=true
   and now>=(record.dodgeUntil or 0) and (record.player~=P or h.MoveDirection.Magnitude>.05)
  if valid then table.insert(candidates,{record=record,distance=record.player==P and -1 or distance})
  else record.nextStep=nil end
 end
 table.sort(candidates,function(x,y) return x.distance<y.distance end)
 for i,entry in ipairs(candidates) do
  local record=entry.record;local r,h,c=record.root,record.humanoid,record.character
  if i>4 then record.nextStep=nil;continue end
  if not record.ray then
   record.ray=RaycastParams.new();record.ray.FilterType=Enum.RaycastFilterType.Exclude;record.ray.RespectCanCollide=true;record.ray.IgnoreWater=true
  end
  record.ray.FilterDescendantsInstances={c}
  local hit=workspace:Raycast(r.Position,Vector3.new(0,-math.max(3.4,h.HipHeight+r.Size.Y/2+.8),0),record.ray)
  local velocity=r.AssemblyLinearVelocity
  if hit and hit.Instance:IsA('BasePart') then velocity-=hit.Instance:GetVelocityAtPosition(hit.Position) end
  local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
  if not hit or speed<5 or math.abs(velocity.Y)>12 or (record.player==P and h.FloorMaterial==Enum.Material.Air) then record.nextStep=nil;continue end
  if now<(record.nextStep or 0) then continue end
  record.nextStep=now+math.clamp(7.8/speed,.2,.48)
  record.stride=(record.stride or 0)+1
  local variation=1+((record.stride*7%11)-5)*.009
  local name=hit.Material.Name;local gentle=soft[name];local hard=metal[name]
  local level=(record.player==P and 1 or .7)*math.clamp(speed/28,.7,1.2)
  play(stepVoices,'hit',level*(gentle and .032 or .045),variation*(hard and 1.3 or gentle and .98 or 1.1),.19,r,.033)
  play(stepVoices,'swish',level*(gentle and .01 or hard and .006 or .007),variation*1.1,.14,r,.12)
 end
end
link(Remotes.Get('RoundState').OnClientEvent,function(data)
 if type(data)~='table' or type(data.State)~='string' then return end
 local previous=phase;phase=data.State
 if phase=='STARTING' then
  local count=math.ceil(finite(data.TimeLeft,0))
  if count>=1 and count<=3 and count~=lastCount then lastCount=count;cue('tone',.28,1+(3-count)*.12) end
 elseif previous=='STARTING' and (phase=='ROUND' or phase=='PRACTICE') then phrase({0,7,12},.23);lastCount=nil
 else lastCount=nil end
 if phase=='FINAL_DUEL' and previous~=phase then phrase({0,3,7,12},.24) end
 if phase=='RESULT' and previous~=phase then
  phrase(data.Winner==P.DisplayName and {0,4,7,12,16,19} or {7,3,0},.19)
 end
 if phase=='RESULT' or phase=='WAITING' or phase=='INTERMISSION' then bomb=false end
 updateScene()
end)
link(Remotes.Get('BombState').OnClientEvent,function(data)
 if type(data)~='table' then return end
 local previous=owner;local event=data.Event
 bomb=data.Active==true;owner=finite(data.CarrierUserId,0);fuseEnd=finite(data.EndTime,0)
 if event=='Started' then lastTick=nil end
 if event=='Exploded' and rate('explode',.25) then
  local victim=Players:GetPlayerByUserId(owner);local c=victim and victim.Character;local r=c and c:FindFirstChild('HumanoidRootPart')
  if r or owner==P.UserId or playing() then cue('boom',owner==P.UserId and .55 or .34,.95,r) end
  if owner==P.UserId then phrase({7,3,-5},.17) end
 elseif bomb and owner==P.UserId and previous~=owner then phrase({0,3,7},.23)
 elseif event=='Transferred' then
  if previous==P.UserId then phrase({7,12},.16)
  else local carrier=Players:GetPlayerByUserId(owner);local c=carrier and carrier.Character;cue('swish',.14,1.7,c and c:FindFirstChild('HumanoidRootPart')) end
 end
end)
local function visible(button)
 local p=button
 while p and p~=P.PlayerGui do if p:IsA('GuiObject') and not p.Visible then return false end;p=p.Parent end
 return true
end
local function bindUI(o)
 if ui[o] or not o:IsDescendantOf(P.PlayerGui) then return end
 local screen=o:FindFirstAncestorOfClass('ScreenGui');if not screen or screen.Name~='BombTagHUD' then return end
 local bucket={};ui[o]=bucket
 if o:IsA('GuiButton') then
  link(o.MouseEnter,function() if visible(o) and rate('hover',.08) then cue('click',.04,1.75) end end,bucket)
  link(o.SelectionGained,function() if visible(o) and rate('hover',.08) then cue('click',.04,1.75) end end,bucket)
  link(o.Activated,function() if rate('click',.035) then cue('hit',.12,1.5);cue('tone',.075,o.Name=='Close' and .8 or 1.15) end end,bucket)
 elseif o.Name=='ModalShade' and o:IsA('Frame') then
  modal=o.Visible
  link(o:GetPropertyChangedSignal('Visible'),function() modal=o.Visible;cue('swish',.1,modal and 1.7 or 1.1) end,bucket)
 end
 if #bucket==0 then ui[o]=nil;return end
 link(o.Destroying,function() clear(bucket);ui[o]=nil;if o.Name=='ModalShade' then modal=false end end,bucket)
end
local pg=P:WaitForChild('PlayerGui');link(pg.DescendantAdded,bindUI);for _,o in ipairs(pg:GetDescendants()) do bindUI(o) end
local function attach(o)
 if o.Name=='BombTagVoteV6' and o:IsA('RemoteEvent') and o~=voteRemote then
  if voteLink then voteLink:Disconnect() end;voteRemote=o
  voteLink=link(o.OnClientEvent,function(kind,data)
   if kind=='Open' and not playing() and P:GetAttribute('BombTagAFK')~=true then phrase({0,7,10},.14)
   elseif kind=='Result' and type(data)=='table' and not playing() then phrase({7,12},.16) end
  end)
 end
end
link(RS.ChildAdded,attach);for _,o in ipairs(RS:GetChildren()) do attach(o) end
link(P:GetAttributeChangedSignal('BombTagAFK'),function() cue('tone',.15,P:GetAttribute('BombTagAFK')==true and .8 or 1.2) end)
link(P:GetAttributeChangedSignal('InRound'),updateScene)
for _,name in ipairs({'HussMusicMuted','HussSFXMuted','HussMusicVolume','HussSFXVolume'}) do link(P:GetAttributeChangedSignal(name),settings) end
for _,name in ipairs({'HussLobbyMusicId','HussChaseMusicId','HussDuelMusicId'}) do link(workspace:GetAttributeChangedSignal(name),updateScene) end
local footAt=0
link(Run.Heartbeat,function(dt)
 local now=os.clock();updateScene()
 local localState=people[P]
 if localState and localState.readyAt and now>=localState.readyAt then
  localState.readyAt=nil
  if localState.character and localState.character.Parent and localState.humanoid and localState.humanoid.Health>0 then cue('tone',.08,1.33) end
 end
 local duck=modal and .56 or (bomb and owner==P.UserId and .68 or 1)
 local target=P:GetAttribute('HussMusicMuted')==true and 0 or volume('HussMusicVolume',.5)*duck
 music.Volume+=(target-music.Volume)*math.min(1,dt*6)
 if customId~='' and custom.IsLoaded then custom.Volume=math.min(.65,custom.Volume+dt*.45) end
 for _,pool in ipairs({voices,musicVoices,stepVoices}) do for _,v in ipairs(pool) do
  if not v.sound.Parent then v.sound=sound(v.group);v.untilAt=0 end
  if v.untilAt>0 then
   if now>=v.untilAt then v.sound:Stop();v.sound.Parent=root;v.untilAt=0
   else v.sound.Volume=v.level*math.min(1,(v.untilAt-now)/.12) end
  end
 end end
 for i=#queue,1,-1 do local q=queue[i];if now>=q.at then cue('tone',q.level,2^(q.note/12));table.remove(queue,i) end end
 if bomb then
  local left=fuseEnd-workspace:GetServerTimeNow();local period=left<=3 and .22 or .65;local tick=math.floor(left/period)
  if left>0 and tick~=lastTick then
   lastTick=tick
   if owner==P.UserId or (playing() and left<=3) then cue('click',owner==P.UserId and .1 or .035,left<=3 and 1.8 or 1.2) end
  end
 end
 footAt+=dt;if footAt>=.05 then footAt=0;feet() end
end)
local function cleanup()
 if stopped then return end;stopped=true;clear(links)
 for _,bucket in pairs(ui) do clear(bucket) end;table.clear(ui)
 local list={};for player in pairs(people) do table.insert(list,player) end;for _,player in ipairs(list) do removePlayer(player) end
 for o,saved in pairs(legacy) do if o.Parent and o.SoundGroup==sfx then o.SoundGroup=saved.group end end
 for group,value in pairs(legacyGroups) do if group.Parent then group.Volume=value end end
 for o,saved in pairs(legacyAudio) do saved.link:Disconnect();saved.name:Disconnect();if o.Parent then o.Volume=saved.level end end
 for _,pool in ipairs({voices,musicVoices,stepVoices}) do for _,v in ipairs(pool) do v.sound:Destroy() end end
 table.clear(queue);custom:Destroy();music:Destroy();sfx:Destroy();root:Destroy()
end
local stop=make('BindableEvent',root,{Name='Stop'});link(stop.Event,cleanup);link(script.Destroying,cleanup)
settings();updateScene()

