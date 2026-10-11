-- HUSS A BOMB V6: MUSIC, GAME SOUNDS, LOBBY AND ACTION DODGE
-- Requires the previous V5 HUD/dodge update. Stop Play, paste, save, then Play.
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'Stop Play before installing.')
local starter=game:GetService('StarterPlayer')
local scripts=starter.StarterPlayerScripts
local controllers=scripts:FindFirstChild('Controllers')
local hud=controllers and controllers:FindFirstChild('HudController')
local movement=scripts:FindFirstChild('SnappyMovement')
local animate=starter.StarterCharacterScripts:FindFirstChild('Animate')
local server=game:GetService('ServerScriptService'):FindFirstChild('DodgeIFrameServer')
local motion=scripts:FindFirstChild('DodgeWeaveV5')
local oldLobby=workspace:FindFirstChild('Lobby')
local oldSpawn=oldLobby and oldLobby:FindFirstChild('LobbySpawn')
local oldAudio=scripts:FindFirstChild('GameAudioV6')
assert(hud and hud:IsA('ModuleScript') and movement and movement:IsA('LocalScript') and animate and server and motion and motion:IsA('LocalScript'),'Install the previous V5 HUD/dodge update first. Nothing changed.')
assert(hud.Source:find('-- HUSS A BOMB / unified',1,true) and movement.Source:find('-- HussDodgeV5',1,true) and animate.Source:find('-- HussDodgeV5',1,true) and server.Source:find('-- HussDodgeV5',1,true),'V5 script signatures are missing. Nothing changed.')
assert(oldLobby and oldLobby:IsA('Model') and oldSpawn and oldSpawn:IsA('SpawnLocation'),'Workspace.Lobby.LobbySpawn must be a SpawnLocation. Nothing changed.')
assert(not oldAudio or oldAudio:IsA('LocalScript'),'GameAudioV6 exists but is not a LocalScript. Nothing changed.')
local sources={}

sources.Audio=[==[--!nonstrict
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
local asset={tone='volume_slider.ogg',hit='action_jump_land.mp3',swish='action_get_up.mp3',click='action_jump.mp3',boom='impact_explosion_03.mp3',step='action_footsteps_plastic.mp3'}
local links,people,ui,legacy,legacyGroups,queue={},{},{},{},{},{}
local voices,musicVoices,legacyAudio={},{},{}
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
for i=1,12 do musicVoices[i]={sound=sound(music),group=music,untilAt=0} end
local gain={tone=1.5,hit=3,swish=6,click=3,boom=.7,step=1}
local function play(pool,key,level,speed,lifetime,parent)
 level*=gain[key] or 1
 local now=os.clock();local chosen=pool[1]
 for _,voice in ipairs(pool) do if voice.untilAt<=now then chosen=voice;break elseif voice.untilAt<chosen.untilAt then chosen=voice end end
 if not chosen.sound.Parent then chosen.sound=sound(chosen.group) end
 local v=chosen.sound;v:Stop();v.Parent=parent and parent.Parent and parent or root
 v.Name='Huss_'..key;v.SoundId='rbxasset://sounds/'..asset[key];v.PlaybackSpeed=speed or 1;v.Volume=level;v.TimePosition=0
 chosen.untilAt=now+(lifetime or 1);chosen.started=now;chosen.level=level;v:Play()
end
local function cue(key,level,speed,parent)
 if stopped or P:GetAttribute('HussSFXMuted')==true then return end
 play(voices,key,level or .16,speed or 1,key=='boom' and 2.8 or 1,parent)
end
local function phrase(notes,level)
 for i,n in ipairs(notes) do table.insert(queue,{at=os.clock()+(i-1)*.09,note=n,level=level or .18}) end
end
local function audioLevel(o,saved)
 saved.applied=saved.level*sfx.Volume;o.Volume=saved.applied
end
local function settings()
 sfx.Volume=P:GetAttribute('HussSFXMuted')==true and 0 or volume('HussSFXVolume',.8)
 for group,value in pairs(legacyGroups) do if group.Parent then group.Volume=value*sfx.Volume end end
 for o,saved in pairs(legacyAudio) do if o.Parent then audioLevel(o,saved) end end
 if P:GetAttribute('HussMusicMuted')==true then music.Volume=0 end
 if P:GetAttribute('HussSFXMuted')==true then table.clear(queue) end
end
local function adopt(o)
 if o:IsA('AudioPlayer') and not legacyAudio[o] then
  local saved={level=o.Volume};legacyAudio[o]=saved
  saved.link=o:GetPropertyChangedSignal('Volume'):Connect(function() if o.Volume~=saved.applied then saved.level=o.Volume;audioLevel(o,saved) end end)
  audioLevel(o,saved);return
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
 if legacyAudio[o] then local saved=legacyAudio[o];saved.link:Disconnect();o.Volume=saved.level;legacyAudio[o]=nil end
end)
local function targetScene()
 if not playing() then return 'Lobby' end
 if phase=='FINAL_DUEL' then return 'Duel' end
 if phase=='ROUND' or phase=='STARTING' or phase=='PRACTICE' then return 'Chase' end
 return 'Lobby'
end
local custom=sound(music);custom.Name='OwnedMusic';custom.Looped=true
local customId=''
local function configured(name)
 local id=workspace:GetAttribute('Huss'..name..'MusicId')
 if type(id)=='number' then id=tostring(math.floor(math.max(0,finite(id,0)))) end
 if type(id)~='string' then return '' end
 local digits=id:match('^rbxassetid://(%d+)$') or id:match('^(%d+)$')
 return digits and tonumber(digits)>0 and 'rbxassetid://'..digits or ''
end
local function updateScene()
 local nextScene=targetScene();local id=configured(nextScene)
 if scene==nextScene and customId==id then return end
 scene=nextScene;customId=id;sceneAt=os.clock();lastStep=-1
 custom:Stop();custom.SoundId=id;custom.Volume=0
 for _,v in ipairs(musicVoices) do v.sound:Stop();v.untilAt=0 end
 if id~='' then custom:Play() end
 root:SetAttribute('Scene',scene)
end
local progression={0,-5,-2,-7}
local arpeggio={0,7,10,14,7,3,10,7}
local function score(now)
 local bpm=scene=='Duel' and 150 or scene=='Chase' and 124 or 88
 local step=math.floor((now-sceneAt)*bpm/30)
 if step==lastStep then return end;lastStep=step
 if P:GetAttribute('HussMusicMuted')==true or (customId~='' and custom.IsLoaded) then return end
 local beat=step%16;local chord=progression[math.floor(step/16)%4+1]
 local dense=scene~='Lobby'
 if step%2==0 or (dense and step%4==3) then
  local note=chord+arpeggio[math.floor(step/2)%8+1]
  play(musicVoices,'tone',dense and .13 or .09,2^(note/12),.58)
 end
 if beat%4==0 then
  play(musicVoices,'hit',dense and .11 or .055,.62,.3)
  play(musicVoices,'tone',dense and .095 or .065,2^((chord-12)/12),.7)
 elseif dense and beat%4==2 then play(musicVoices,'hit',.055,1.7,.14) end
 if scene=='Duel' and beat%2==1 then play(musicVoices,'click',.035,1.8,.09) end
end
local actions={DiveForward=true,DiveBack=true,DiveLeft=true,DiveRight=true,DiveForwardLeft=true,DiveForwardRight=true,DiveBackLeft=true,DiveBackRight=true}
local function dodge(player,action)
 if not actions[action] or not rate('dodge'..player.UserId,.15) then return end
 local c=player.Character;local r=c and c:FindFirstChild('HumanoidRootPart')
 if player==P and people[player] then people[player].readyAt=os.clock()+1.5 end
 cue('swish',player==P and .3 or .19,action:find('Back') and 1.3 or 1.6,r)
 cue('hit',player==P and .065 or .04,1.4,r)
end
local function disconnectCharacter(record)
 clear(record.charLinks)
 if record.foot then record.foot:Destroy();record.foot=nil end
 record.character=nil;record.humanoid=nil;record.root=nil;record.readyAt=nil
end
local function bindCharacter(player,c)
 local record=people[player];if not record then return end
 disconnectCharacter(record);record.character=c
 if not c then return end
 local function discover(o)
  if o:IsA('Humanoid') then record.humanoid=o elseif o.Name=='HumanoidRootPart' and o:IsA('BasePart') then record.root=o end
 end
 for _,o in ipairs(c:GetChildren()) do discover(o) end
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
local function nativeFootsteps()
 local ps=P:FindFirstChild('PlayerScripts');local script=ps and ps:FindFirstChild('Footsteps');return script and script:IsA('LocalScript') and not script.Disabled
end
local function feet()
 local native=nativeFootsteps()
 for _,record in pairs(people) do
  local c,h,r=record.character,record.humanoid,record.root
  if c and c.Parent and h and r and r.Parent then
   local running=r:FindFirstChild('Running');local velocity=r.AssemblyLinearVelocity;local speed=Vector3.new(velocity.X,0,velocity.Z).Magnitude
   local moving=(record.player~=P or not native) and not (running and (running:IsA('Sound') or running:IsA('AudioPlayer')) and running.IsPlaying and running.Volume>0)
    and h.Health>0 and not r.Anchored and h.FloorMaterial~=Enum.Material.Air and not h.Sit and not h.PlatformStand
    and c:GetAttribute('MovementState')~='Dive' and speed>5 and (record.player~=P or h.MoveDirection.Magnitude>.05)
   if moving and not record.foot then
    record.foot=make('Sound',r,{Name='HussFootsteps',SoundId='rbxasset://sounds/'..asset.step,SoundGroup=sfx,Looped=true,Volume=.225,RollOffMinDistance=6,RollOffMaxDistance=48})
   end
   if record.foot then
    if moving then record.foot.PlaybackSpeed=math.clamp(speed/20,1,1.85);if not record.foot.IsPlaying then record.foot:Play() end
    elseif record.foot.IsPlaying then record.foot:Stop() end
   end
  end
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
 local now=os.clock();updateScene();score(now)
 local localState=people[P]
 if localState and localState.readyAt and now>=localState.readyAt then
  localState.readyAt=nil
  if localState.character and localState.character.Parent and localState.humanoid and localState.humanoid.Health>0 then cue('tone',.08,1.33) end
 end
 local duck=modal and .56 or (bomb and owner==P.UserId and .68 or 1)
 local target=P:GetAttribute('HussMusicMuted')==true and 0 or volume('HussMusicVolume',.5)*duck
 music.Volume+=(target-music.Volume)*math.min(1,dt*6)
 if customId~='' and custom.IsLoaded then custom.Volume=math.min(.65,custom.Volume+dt*.45) end
 for _,pool in ipairs({voices,musicVoices}) do for _,v in ipairs(pool) do
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
 footAt+=dt;if footAt>=.1 then footAt=0;feet() end
end)
local function cleanup()
 if stopped then return end;stopped=true;clear(links)
 for _,bucket in pairs(ui) do clear(bucket) end;table.clear(ui)
 local list={};for player in pairs(people) do table.insert(list,player) end;for _,player in ipairs(list) do removePlayer(player) end
 for o,saved in pairs(legacy) do if o.Parent and o.SoundGroup==sfx then o.SoundGroup=saved.group end end
 for group,value in pairs(legacyGroups) do if group.Parent then group.Volume=value end end
 for o,saved in pairs(legacyAudio) do saved.link:Disconnect();if o.Parent then o.Volume=saved.level end end
 for _,pool in ipairs({voices,musicVoices}) do for _,v in ipairs(pool) do v.sound:Destroy() end end
 table.clear(queue);custom:Destroy();music:Destroy();sfx:Destroy();root:Destroy()
end
local stop=make('BindableEvent',root,{Name='Stop'});link(stop.Event,cleanup);link(script.Destroying,cleanup)
settings();updateScene()
]==]

sources.Motion=[==[--!nonstrict
-- V6 ACTION DODGE: shoulder drive, lateral power-step, braced backstep.
-- Cosmetic R6/R15 joints only. SnappyMovement owns speed, collisions and cooldown.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local me = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"):WaitForChild("DodgeIFrameRequest")
local DURATION = .72
local CF, V = CFrame.new, Vector3.new
local active, players, connections = {}, {}, {}
local stopped = false

local directions = {
	DiveForward={0,1}, DiveBack={0,-1}, DiveLeft={-1,0}, DiveRight={1,0},
	DiveForwardLeft={-.7071,.7071}, DiveForwardRight={.7071,.7071},
	DiveBackLeft={-.7071,-.7071}, DiveBackRight={.7071,-.7071},
}
-- time, blend, compression, lean, guard, stride: snap-load, burst, reach, plant, recover.
local keys = {
	{0,0,0,0,0,0}, {.045,.88,.58,-.18,.85,-.5},
	{.135,1,1,1,1,1}, {.28,1,.84,.92,.94,.68},
	{.46,.84,.48,.48,.58,-.32}, {.60,.30,.1,.09,.15,.12},
	{DURATION,0,0,0,0,0},
}
local roles = {
	Torso="root", LowerTorso="root", UpperTorso="waist", Head="neck",
	["Left Arm"]="leftArm", ["Right Arm"]="rightArm",
	["Left Leg"]="leftHip", ["Right Leg"]="rightHip",
	LeftUpperArm="leftArm", RightUpperArm="rightArm",
	LeftLowerArm="leftElbow", RightLowerArm="rightElbow",
	LeftUpperLeg="leftHip", RightUpperLeg="rightHip",
	LeftLowerLeg="leftKnee", RightLowerLeg="rightKnee",
	LeftFoot="leftAnkle", RightFoot="rightAnkle",
}
local function sample(t)
	for i=2,#keys do
		local b,a = keys[i],keys[i-1]
		if t<=b[1] then
			local u=math.clamp((t-a[1])/(b[1]-a[1]),0,1)
			u=u*u*(3-2*u)
			local result={}
			for j=2,6 do result[j-1]=a[j]+(b[j]-a[j])*u end
			return result
		end
	end
	return {0,0,0,0,0}
end
local function pose(role,r15,d,s)
	local _,dip,lean,guard,stride=table.unpack(s)
	local side,front=d[1],d[2]
	local forward,back=math.max(front,0),math.max(-front,0)
	local bank=side~=0 and side or (front>0 and -.26 or .18)
	local pitch=(-34*forward+19*back-12*math.abs(side))*lean
	local roll=-bank*27*lean
	local yaw=(side*16+(side==0 and front*12 or 0))*lean
	local hip=(r15 and 32*dip or 0)-(r15 and pitch*.34 or pitch*.92)
	local lead=(side<0 and -1 or 1)*(25*stride+12*back*lean)
	local armDrive=(front*42+side*32)*lean
	local x,y,z,rx,ry,rz=0,0,0,0,0,0
	if role=="root" then
		x,y,z=side*.32*lean,(r15 and -.18 or .12+.26*math.abs(side))*dip,-forward*.22*lean
		rx,ry,rz=pitch*(r15 and .34 or 1),yaw,roll*(r15 and .52 or 1)
	elseif role=="waist" then rx,ry,rz=pitch*.66,side*14*lean,roll*.48
	elseif role=="neck" then rx,ry,rz=-pitch*.70,-yaw*.65,-roll*.5
	elseif role=="leftArm" then
		rx,ry,rz=16+47*guard+armDrive,-18*guard,-14-16*guard+side*9*lean
	elseif role=="rightArm" then
		rx,ry,rz=16+47*guard-armDrive,18*guard,14+16*guard+side*9*lean
	elseif role=="leftElbow" then rx=30+45*guard+math.max(armDrive,0)*.3
	elseif role=="rightElbow" then rx=30+45*guard+math.max(-armDrive,0)*.3
	elseif role=="leftHip" then rx,ry,rz=hip+lead,-side*8*lean,-9*dip-roll*.42
	elseif role=="rightHip" then rx,ry,rz=hip-lead,-side*8*lean,9*dip-roll*.42
	elseif role=="leftKnee" then rx=-56*dip-math.max(lead,0)*.45
	elseif role=="rightKnee" then rx=-56*dip-math.max(-lead,0)*.45
	elseif role=="leftAnkle" or role=="rightAnkle" then rx=26*dip
	end
	return CF(x,y,z)*CFrame.Angles(math.rad(rx),math.rad(ry),math.rad(rz))
end
local function restore(state)
	for _,j in ipairs(state.joints) do
		if j.base then
			if j.motor.Parent and j.motor.Transform==j.applied then
				j.motor.Transform=j.base
			end
			j.base,j.applied=nil,nil
		end
	end
end
local function cancel(state)
	restore(state)
	state.started=nil
	for _,trail in ipairs(state.trails) do trail.Enabled=false end
end
local function blocked(state)
	local h,c,r=state.humanoid,state.character,state.root
	if not c.Parent or not h.Parent or h.Health<=0 or not r.Parent or r.Anchored then return true end
	if state.player:GetAttribute("HussGamePaused")==true or workspace:GetAttribute("HussGamePaused")==true then return true end
	if c:GetAttribute("Ragdolled")==true or c:GetAttribute("IsRagdoll")==true or h.PlatformStand or h.Sit then return true end
	local mode=h:GetState()
	return mode==Enum.HumanoidStateType.Dead or mode==Enum.HumanoidStateType.Ragdoll
		or mode==Enum.HumanoidStateType.Physics or mode==Enum.HumanoidStateType.Seated
end
local function trailFor(state,part)
	if not part then return end
	local a,b=Instance.new("Attachment"),Instance.new("Attachment")
	a.Name,b.Name="HussDodgeTrailTop","HussDodgeTrailBottom"
	a.Position,b.Position=V(0,-part.Size.Y*.2,0),V(0,-part.Size.Y*.45,0)
	a.Parent,b.Parent=part,part
	local t=Instance.new("Trail")
	t.Name="HussActionBurst"
	t.Attachment0,t.Attachment1=a,b
	t.Lifetime=.115
	t.MinLength=.12
	t.LightEmission=.7
	t.Color=ColorSequence.new(Color3.fromRGB(225,255,238),Color3.fromRGB(137,244,177))
	t.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.52),NumberSequenceKeypoint.new(1,1)})
	t.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)})
	t.FaceCamera=true
	t.Enabled=false
	t.Parent=part
	table.insert(state.trails,t)
	for _,object in ipairs({a,b,t}) do table.insert(state.effects,object) end
end
local function start(state,action,age)
	if not directions[action] or blocked(state) or workspace:GetAttribute("HussDodgeV5")~=true then return end
	age=age or 0
	if age>=DURATION then return end
	cancel(state)
	state.direction=directions[action]
	state.started=os.clock()-math.max(age,0)
	if #state.effects==0 then
		trailFor(state,state.character:FindFirstChild(state.r15 and "LeftHand" or "Left Arm"))
		trailFor(state,state.character:FindFirstChild(state.r15 and "RightHand" or "Right Arm"))
	end
end
local function dispose(state)
	if not state then return end
	cancel(state)
	for _,connection in ipairs(state.connections) do connection:Disconnect() end
	for _,effect in ipairs(state.effects) do effect:Destroy() end
	active[state.player]=nil
end
local function characterAdded(player,character)
	local record=players[player]
	if not record then return end
	record.generation+=1
	local generation=record.generation
	dispose(active[player])
	task.spawn(function()
		local h=character:WaitForChild("Humanoid",10)
		local root=character:WaitForChild("HumanoidRootPart",10)
		if stopped or players[player]~=record or record.generation~=generation
			or player.Character~=character or not h or not root then return end
		local state={player=player,character=character,humanoid=h,root=root,
			r15=h.RigType==Enum.HumanoidRigType.R15,joints={},connections={},effects={},trails={}}
		local function add(j)
			if not j:IsA("Motor6D") or not j.Part1 or not j.Part0 then return end
			local role=roles[j.Part1.Name]
			if role then table.insert(state.joints,{motor=j,role=role}) end
		end
		for _,j in ipairs(character:GetDescendants()) do add(j) end
		table.insert(state.connections,character.DescendantAdded:Connect(add))
		table.insert(state.connections,h.Died:Connect(function() cancel(state) end))
		active[player]=state
		if player==me then
			table.insert(state.connections,character:GetAttributeChangedSignal("MovementActionId"):Connect(function()
				local action=character:GetAttribute("MovementAction")
				if action=="DiveEnd" then cancel(state) else start(state,action,0) end
			end))
		end
	end)
end
local function addPlayer(player)
	if players[player] then return end
	local record={generation=0}
	players[player]=record
	record.added=player.CharacterAdded:Connect(function(c) characterAdded(player,c) end)
	record.removing=player.CharacterRemoving:Connect(function()
		record.generation+=1
		dispose(active[player])
	end)
	if player.Character then characterAdded(player,player.Character) end
end
local function removePlayer(player)
	local record=players[player]
	if not record then return end
	record.generation+=1
	record.added:Disconnect()
	record.removing:Disconnect()
	dispose(active[player])
	players[player]=nil
end
table.insert(connections,Players.PlayerAdded:Connect(addPlayer))
table.insert(connections,Players.PlayerRemoving:Connect(removePlayer))
for _,player in ipairs(Players:GetPlayers()) do addPlayer(player) end
table.insert(connections,remote.OnClientEvent:Connect(function(player,action,stamp)
	if player==me or type(stamp)~="number" or stamp~=stamp or math.abs(stamp)==math.huge
		or stamp>workspace:GetServerTimeNow()+1 or not directions[action] then return end
	local state=active[player]
	if state and (not state.lastStamp or stamp>state.lastStamp) then
		state.lastStamp=stamp
		start(state,action,workspace:GetServerTimeNow()-stamp)
	end
end))
-- Restore before Animator evaluation; sample its fresh result after evaluation.
table.insert(connections,RunService.PreAnimation:Connect(function()
	for _,state in pairs(active) do restore(state) end
end))
table.insert(connections,RunService.PreSimulation:Connect(function()
	for _,state in pairs(active) do
		if state.started then
			local elapsed=os.clock()-state.started
			if elapsed>=DURATION or blocked(state) or workspace:GetAttribute("HussDodgeV5")~=true then
				cancel(state)
			else
				local s=sample(elapsed)
				for _,j in ipairs(state.joints) do
					local motor=j.motor
					if motor.Parent and motor.Enabled then
						local axes=motor.C0.Rotation
						local target=axes:Inverse()*pose(j.role,state.r15,state.direction,s)*axes
						j.base=motor.Transform
						j.applied=j.base:Lerp(target,s[1])
						motor.Transform=j.applied
					end
				end
				local trails=elapsed>.035 and elapsed<.30 and me:GetAttribute("HussReducedMotion")~=true
					and workspace:GetAttribute("HussReducedMotion")~=true
				for _,trail in ipairs(state.trails) do trail.Enabled=trails end
			end
		end
	end
end))
table.insert(connections,script.Destroying:Connect(function()
	stopped=true
	for _,connection in ipairs(connections) do connection:Disconnect() end
	local list={}
	for player in pairs(players) do table.insert(list,player) end
	for _,player in ipairs(list) do removePlayer(player) end
end))
]==]

local patchHUD=(function()
-- Return a minimal, repeatable V5/V6 HUD source patch.
return function(source)
 assert(source:find('local HUD = {}',1,true) and source:find('HussReducedMotion',1,true), 'Install the previous V5 HUD update first. Nothing changed.')
 local first=source:find(' elseif menu=="SETTINGS" then',1,true)
 local last=first and source:find(' elseif menu=="MAPS" then',first+1,true)
 assert(first and last,'HUD Settings section differs. Nothing changed.')
 local settings=[=[ elseif menu=="SETTINGS" then
  -- HussAudioV6: session preferences consumed by GameAudioV6.
  block("AUDIO MIX","Original lobby music, a faster chase arrangement, and responsive game sounds. Adjust each layer below.",C.green,112)
  local function audioToggle(name,caption,attribute)
   local muted=P:GetAttribute(attribute)==true
   local b=button(U.Body,name,caption..(muted and " / OFF" or " / ON"),function()
    P:SetAttribute(attribute,P:GetAttribute(attribute)~=true); buildPage()
   end,false,pageLinks)
   b.TextColor3=muted and C.muted or C.green
   b.Position=UDim2.fromOffset(0,y); b.Size=UDim2.new(1,-6,0,48); y+=60
  end
  audioToggle("Music","MUSIC","HussMusicMuted")
  audioToggle("SoundEffects","SOUND EFFECTS","HussSFXMuted")
  block("MOTION & EFFECTS",reduced() and "Reduced motion is on. HUD transitions and dodge trails are disabled." or "Full motion is on. Crisp transitions and short dodge trails give feedback during the action.",C.green,122)
  local b=button(U.Body,"Motion",reduced() and "ENABLE FULL MOTION" or "REDUCE MOTION",function()
   P:SetAttribute("HussReducedMotion",not reduced()); for _,t in pairs(tweens) do t:Cancel() end; U.CountScale.Scale=1; U.WindowScale.Scale=1; U.NoticeScale.Scale=1; buildPage()
  end,false,pageLinks)
  b.Position=UDim2.fromOffset(0,y); b.Size=UDim2.new(1,-6,0,48); y+=64
  block("SESSION PREFERENCES","Your audio and motion choices apply to this play session.",C.muted,92)
]=]
 source=source:sub(1,first-1)..settings..source:sub(last)
 local old='U.DashTitle.Text=now-dodgeAt<.95 and direction or "DODGE / WEAVE"'
 local new='U.DashTitle.Text=now-dodgeAt<num(workspace:GetAttribute("HussDodgeDuration"),.95) and direction or "DODGE / WEAVE"'
 if not source:find(new,1,true) then
  local a,b=source:find(old,1,true); assert(a,'HUD dodge timing differs. Nothing changed.')
  source=source:sub(1,a-1)..new..source:sub(b+1)
 end
 return source
end

end)()

local patchMovement=(function()
-- Replace only the approved motion constants; preserve input, collision, camera,
-- steering, cooldown, existing V5 cosmetic replication and server validation.
return function(source)
 assert(type(source)=="string", "SnappyMovement source is missing.")
 local changes={
  {"DIVE_MIN_START_SPEED",50,74},
  {"DIVE_MOMENTUM_BONUS",20,44},
  {"DIVE_MAX_START_SPEED",60,84},
  {"DIVE_DURATION",.95,.72},
  {"DIVE_EARLY_DRAG",1.15,1.0},
  {"DIVE_LATE_DRAG",3.20,2.70},
 }
 local function constant(name)
  local pattern="local%s+"..name.."%s*=%s*([%d%.]+)"
  local value,count
  local _,n=source:gsub(pattern,function(match) value=tonumber(match) end)
  assert(n==1 and value, "Unexpected movement constant: "..name..". Nothing changed.")
  return value,pattern
 end
 for _,unchanged in ipairs({{"DIVE_COOLDOWN",1.5},{"WALK_SPEED",24},{"SPRINT_SPEED",32}}) do
  assert(constant(unchanged[1])==unchanged[2],"Movement contract differs: "..unchanged[1]..". Nothing changed.")
 end
 local old,new=0,0
 for _,c in ipairs(changes) do
  local value=constant(c[1]); assert(value==c[2] or value==c[3],"Custom movement tuning found: "..c[1]..". Nothing changed.")
  if value==c[2] then old+=1 else new+=1 end
 end
 assert(old==#changes or new==#changes,"Partially updated movement tuning found. Nothing changed.")
 if old==#changes then
  for _,c in ipairs(changes) do
   local _,pattern=constant(c[1]); local n
   source,n=source:gsub(pattern,"local "..c[1].." = "..tostring(c[3]),1)
   assert(n==1,"Movement patch failed: "..c[1])
  end
 end
 if not source:find("-- HussActionV6",1,true) then source..="\n-- HussActionV6: .72s burst; 1.5s cooldown and .45s server immunity are unchanged.\n" end
 return source
end

end)()

local buildLobby=(function()
--!nonstrict
-- HUSS A BOMB / The Conservatory. Editable parts, continuous no-jump routes.
-- Build(parent[, origin]) returns Lobby with its direct child LobbySpawn.
local Builder={}
local V,C,R,M=Vector3.new,CFrame.new,Color3.fromRGB,Enum.Material
local ink,stone,cream,wood=R(27,39,38),R(151,170,151),R(230,227,205),R(105,73,52)
local sage,leaf,lime,gold=R(97,131,107),R(57,99,71),R(180,248,126),R(225,187,104)
local geometry
local function group(parent,name)
 local g=Instance.new('Model');g.Name=name;g.Parent=parent;return g
end
local function part(parent,name,x,y,z,w,h,d,color,material,solid,rotation,class)
 local p=Instance.new(class or 'Part');p.Name=name;p.Size=V(w,h,d);p.CFrame=C(x,y,z)*(rotation or CFrame.identity)
 p.Color=color;p.Material=material or M.Concrete;p.Anchored=true;p.CanCollide=solid~=false;p.CanTouch=false;p.CanQuery=p.CanCollide
 p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Parent=parent;return p
end
local function trim(p,n,x,y,z,w,h,d,color,mat,rot) return part(p,n,x,y,z,w,h,d,color,mat,false,rot) end
local function beam(p,n,a,b,w,h,color,mat,solid)
 local q=(a+b)/2;return part(p,n,q.X,q.Y,q.Z,w,h,(b-a).Magnitude,color,mat,solid,CFrame.lookAt(a,b).Rotation)
end
local function cylinder(p,n,x,y,z,diameter,height,color,mat,solid)
 local o=part(p,n,x,y,z,height,diameter,diameter,color,mat,solid,CFrame.Angles(0,0,math.pi/2));o.Shape=Enum.PartType.Cylinder;return o
end
local function ball(p,n,x,y,z,w,h,d,color,mat)
 local o=trim(p,n,x,y,z,w,h,d,color,mat or M.Grass);o.Shape=Enum.PartType.Ball;return o
end
local function label(parent,title,subtitle,x,y,z,width,height,rotation,color)
 local b=trim(parent,'Enamel / '..title,x,y,z,width,height,.4,ink,M.Metal,rotation)
 local ui=Instance.new('SurfaceGui');ui.Name='Lettering';ui.Face=Enum.NormalId.Back;ui.CanvasSize=Vector2.new(1000,300);ui.LightInfluence=.1;ui.Parent=b
 local function line(t,top,h,size,c)
  local l=Instance.new('TextLabel');l.BackgroundTransparency=1;l.Size=UDim2.new(1,-40,0,h);l.Position=UDim2.fromOffset(20,top)
  l.Font=Enum.Font.GothamBold;l.Text=t;l.TextSize=size;l.TextColor3=c;l.TextWrapped=true;l.Parent=ui
 end
 line(title,26,140,66,color or cream);line(subtitle,177,82,33,R(166,190,168))
 return b
end
local function paving(p,x,z,w,d,y,color)
 trim(p,'Limestone paving',x,y+.035,z,w,.05,d,color or cream,M.Limestone)
 for a=-w/2+8,w/2-.5,8 do trim(p,'Flush stone joint',x+a,y+.066,z,.07,.015,d,stone,M.Concrete) end
 for b=-d/2+8,d/2-.5,8 do trim(p,'Flush stone joint',x,y+.067,z+b,w,.015,.07,stone,M.Concrete) end
end
local function rail(p,a,b)
 beam(p,'Continuous guard',a+V(0,1.8,0),b+V(0,1.8,0),.65,3.6,ink,M.Metal,true).Transparency=1
 beam(p,'Bronze handrail',a+V(0,3.7,0),b+V(0,3.7,0),.38,.38,gold,M.Metal,false)
 beam(p,'Lower rail',a+V(0,1,0),b+V(0,1,0),.22,.22,ink,M.Metal,false)
 local n=math.ceil((b-a).Magnitude/6)
 for i=0,n do local q=a:Lerp(b,i/n);trim(p,'Guard upright',q.X,q.Y+1.8,q.Z,.36,3.6,.36,ink,M.Metal) end
end
local function lamp(p,x,y,z,height)
 trim(p,'Lamp plinth',x,y+.2,z,1.8,.4,1.8,cream,M.Limestone)
 trim(p,'Lamp post',x,y+height/2,z,.45,height,.45,ink,M.Metal)
 trim(p,'Lantern cap',x,y+height+.2,z,1.7,.35,1.7,ink,M.Metal)
 local glow=trim(p,'Warm lantern',x,y+height-.65,z,1.05,1.4,1.05,R(255,226,159),M.Neon)
 for _,s in ipairs({-1,1}) do trim(p,'Lantern frame',x+s*.64,y+height-.6,z,.12,1.6,1.4,ink,M.Metal) end
 -- Only six architectural lamps cast local light; neon details do not.
 local light=Instance.new('PointLight');light.Color=R(255,226,172);light.Brightness=.65;light.Range=17;light.Shadows=false;light.Parent=glow
end
local function bench(p,x,y,z,turn)
 local g=group(p,'Social bench');local basis=C(x,y,z)*CFrame.Angles(0,turn or 0,0)
 local function b(n,px,py,pz,w,h,d,color,mat,solid)
  local q=part(g,n,px,py,pz,w,h,d,color,mat,solid);q.CFrame=basis*q.CFrame
 end
 b('Smooth bench body',0,1.25,0,9,2.5,3.2,wood,M.WoodPlanks,true)
 for i=0,4 do b('Seat slat',-3.8+i*1.9,2.63,0,1.65,.2,3.4,wood:Lerp(cream,.15),M.Wood,false) end
 b('Backrest',0,3.4,-1.65,9,1.7,.28,wood,M.Wood,false)
 for _,s in ipairs({-1,1}) do b('Armrest',s*4.3,3.15,0,.34,.38,3.5,ink,M.Metal,false) end
end
local function tree(p,x,y,z,height,seed)
 trim(p,'Branching trunk',x,y+height*.35,z,1.5,height*.7,1.5,wood,M.Wood)
 for i=1,3 do
  local a=i*2.094+seed;local q=V(x+math.cos(a)*3,y+height*.7,z+math.sin(a)*3)
  beam(p,'Tree branch',V(x,y+height*.42,z),q,.65,.7,wood,M.Wood,false)
  ball(p,'Leaf crown',q.X,q.Y+2,q.Z,8,8,8,leaf:Lerp(sage,i*.1))
 end
 ball(p,'Upper crown',x,y+height,z,9,8,9,leaf:Lerp(sage,.33))
end
local function garden(p,x,z,w,d,treeHeight)
 local g=group(p,'Raised garden')
 part(g,'Smooth planter collision',x,1.35,z,w,2.7,d,stone,M.Limestone,true)
 trim(g,'Planter coping',x,2.73,z,w+.3,.22,d+.3,cream,M.Limestone)
 trim(g,'Soil bed',x,2.87,z,w-1,.18,d-1,R(57,57,42),M.Ground)
 for i=1,5 do
  local px=x+(i-3)*(w-3)/5
  ball(g,'Low hedge',px,3.7,z-d*.22,3.4,2.1,3.4,leaf)
  for j=1,2 do
   local fx=px+(j-1.5)*1.2;local fz=z+d*.25
   trim(g,'Lavender stem',fx,3.4,fz,.14,1.1,.14,sage,M.Grass)
   ball(g,'Lavender bloom',fx,4,fz,.8,.9,.8,R(158+i*5,148,190))
  end
 end
 if treeHeight then tree(g,x,2.9,z,treeHeight,x*.07) end
end
local function arch(p,x,y,z,width,height)
 for _,s in ipairs({-1,1}) do
  part(p,'Gate pier',x+s*width/2,y+height/2,z,2.8,height,3.6,stone,M.Limestone,true)
  trim(p,'Gate foot',x+s*width/2,y+.45,z,3.5,.9,4.2,cream,M.Limestone)
  trim(p,'Gate capital',x+s*width/2,y+height-.1,z,4,.7,4.3,cream,M.Limestone)
 end
 beam(p,'Gate crown',V(x-width/2,y+height,z),V(x+width/2,y+height,z),4,1.4,cream,M.Limestone,false)
 for i=0,12 do
  local t=math.pi*i/12
  trim(p,'Sculpted arch stone',x+math.cos(t)*width/2,y+height+math.sin(t)*5,z,width*.09,1.3,3.2,cream,M.Limestone,CFrame.Angles(0,0,t-math.pi/2))
 end
end
local function ramp(p,name,x)
 local a,b=V(x,0,-24),V(x,5,-48);local rotation=CFrame.Angles(0,math.pi,0)
 part(p,name,x,2.5,-36,24,5,24,cream,M.Limestone,true,rotation,'WedgePart'):SetAttribute('NoJumpRoute',true)
 rail(p,a+V(-11.7,0,0),b+V(-11.7,0,0));rail(p,a+V(11.7,0,0),b+V(11.7,0,0))
 for i=1,4 do local q=a:Lerp(b,i/5);trim(p,'Flush bronze ramp inlay',q.X,q.Y+.025,q.Z,22.8,.025,.14,gold,M.Metal,CFrame.Angles(math.atan(5/24),0,0)) end
 table.insert(geometry.Ramps,{Name=name,X1=x,Z1=-24,X2=x,Z2=-48,BaseY=0,Rise=5,Run=24,Width=24,SlopeDegrees=math.deg(math.atan(5/24))})
end
function Builder.Build(parent,origin)
 geometry={Version=6,Name='The Conservatory',Width=204,Depth=188,Ramps={},Decks={},Routes={},Spawns={}}
 local model=group(parent,'Lobby');model:SetAttribute('HussLobbyVersion',6);model:SetAttribute('MapWidth',204);model:SetAttribute('MapDepth',188)
 model:SetAttribute('Design','The Conservatory / original social courtyard')
 local floor=part(model,'Floor',0,-3,0,204,6,188,sage,M.Grass,true);model.PrimaryPart=floor
 local walks=group(model,'Continuous promenades')
 paving(walks,0,0,92,128,0,cream);paving(walks,0,70,62,28,.001,cream)
 paving(walks,-76,7,46,76,.002,cream);paving(walks,76,7,46,76,.002,cream)
 paving(walks,0,36,164,24,.003,cream);paving(walks,0,-16,140,16,.004,cream)
 -- Flush octagonal plaza inlay; decorative geometry never catches the character.
 for i=0,7 do
  local angle=math.pi/8+i*math.pi/4;local x,z=math.sin(angle)*33,math.cos(angle)*33
  trim(walks,'Octagonal border',x,.085,z,27.4,.035,.55,gold,M.Metal,CFrame.Angles(0,angle,0))
 end
 local fountain=group(model,'The Fuse / fountain monument')
 cylinder(fountain,'Fountain plinth',0,.24,0,32,.48,stone,M.Limestone,false)
 cylinder(fountain,'Smooth fountain collision',0,1.6,0,27,3.2,stone,M.Limestone,true)
 cylinder(fountain,'Dark water basin',0,3.23,0,24,.15,R(49,109,102),M.Glass,false).Transparency=.24
 for i=0,15 do
  local a=i*math.pi/8;local x,z=math.sin(a)*13.7,math.cos(a)*13.7
  trim(fountain,'Segmented limestone rim',x,3.25,z,5.5,.65,1.4,cream,M.Limestone,CFrame.Angles(0,a,0))
  if i%2==0 then cylinder(fountain,'Fountain spill',x*.7,3.6,z*.7,.26,1.3,R(154,236,205),M.Neon,false) end
 end
 cylinder(fountain,'Hero pedestal',0,4.5,0,7,3.2,ink,M.Metal,false)
 cylinder(fountain,'Pedestal bronze ring',0,5.7,0,7.5,.35,gold,M.Metal,false)
 ball(fountain,'Polished bomb sculpture',0,9.6,0,9.5,9.5,9.5,ink,M.Metal)
 cylinder(fountain,'Fuse socket',0,14.6,0,2,1.1,gold,M.Metal,false)
 beam(fountain,'Sculpted fuse',V(0,15,0),V(1.4,17,.2),.55,.55,wood,M.Wood,false)
 ball(fountain,'Fuse ember',1.4,17,.2,1.5,1.5,1.5,lime,M.Neon)
 for i=0,7 do local a=i*math.pi/4;trim(fountain,'Pedestal rivet',math.sin(a)*3.6,5.6,math.cos(a)*3.6,.25,.25,.25,gold,M.Metal) end
 label(fountain,'PASS THE PRESSURE','RUN  /  SPRINT  /  DODGE',0,2.1,13.65,14,2.2,nil,gold)
 local terrace=group(model,'North terrace / gathering pavilion')
 part(terrace,'Terrace deck',0,2.5,-68,148,5,40,stone,M.Limestone,true)
 paving(terrace,0,-68,147.8,39.8,5,cream)
 trim(terrace,'Terrace fascia',0,4.4,-47.92,148,1.1,.18,cream,M.Limestone)
 table.insert(geometry.Decks,{Name='North terrace',X=0,Y=5,Z=-68,Width=148,Depth=40,SolidBase=true})
 ramp(terrace,'West promenade ramp',-54);ramp(terrace,'East promenade ramp',54)
 for _,ends in ipairs({{-74,-66},{-42,42},{66,74}}) do rail(terrace,V(ends[1],5,-48),V(ends[2],5,-48)) end
 rail(terrace,V(-74,5,-88),V(74,5,-88));rail(terrace,V(-74,5,-48),V(-74,5,-88));rail(terrace,V(74,5,-48),V(74,5,-88))
 for _,x in ipairs({-30,30}) do for _,z in ipairs({-57,-80}) do
  part(terrace,'Pavilion column',x,12.5,z,2.2,15,2.2,stone,M.Limestone,true)
  trim(terrace,'Column base',x,5.35,z,3.2,.7,3.2,cream,M.Limestone);trim(terrace,'Column capital',x,19.7,z,3.4,.7,3.4,cream,M.Limestone)
  for _,s in ipairs({-1,1}) do trim(terrace,'Column groove',x+s*.65,12.5,z+1.12,.1,12,.04,cream,M.Limestone) end
 end end
 trim(terrace,'Pavilion entablature',0,20,-68.5,67,1.1,30,cream,M.Limestone)
 trim(terrace,'Pavilion copper roof',0,21,-68.5,69,1.1,32,sage,M.Metal)
 for i=-3,3 do trim(terrace,'Roof standing seam',i*9,21.6,-68.5,.2,.18,31,gold,M.Metal) end
 for i=-8,8 do trim(terrace,'Cornice dentil',i*3.8,19.4,-53.3,1.2,.8,.7,stone,M.Limestone) end
 label(terrace,'HUSS A BOMB','THE CONSERVATORY',0,15.8,-55.1,48,5.2,nil,lime)
 label(terrace,'THE NEXT CHASE STARTS HERE','CHOOSE YOUR ARENA IN THE MAP VOTE',0,10.2,-80.4,40,4.6,nil,cream)
 for _,x in ipairs({-52,52}) do bench(terrace,x,5,-79,0);lamp(terrace,x,5,-84,8) end
 local planting=group(model,'Courtyard gardens')
 for _,s in ipairs({-1,1}) do
  garden(planting,s*56,57,20,22,12);garden(planting,s*84,67,18,26,15)
  garden(planting,s*84,-54,14,24,13);garden(planting,s*22,-31,15,13,nil)
  lamp(planting,s*39,0,59,11);lamp(planting,s*41,0,-8,11)
  bench(planting,s*29,0,51,0)
 end
 local maps={'Sky Garden','Sunset Docks','Frostfall Village','Sunstone Bazaar','Neon District','Clockwork Foundry','Orbital Station','Stardust Carnival','Crystal Cavern','Emerald Ruins','Pirate Cove','Ember Keep'}
 local wings=group(model,'Map galleries / social loggias')
 for _,s in ipairs({-1,1}) do
  local x=s*80;local turn=CFrame.Angles(0,-s*math.pi/2,0)
  for _,z in ipairs({-30,44}) do for _,px in ipairs({s*70,s*97}) do
   part(wings,'Loggia column',px,7.8,z,2.1,15.6,2.1,stone,M.Limestone,true)
   trim(wings,'Loggia capital',px,15.4,z,3.5,.6,3.5,cream,M.Limestone)
  end end
  trim(wings,'Loggia entablature',x,15.9,7,39,1,73,cream,M.Limestone)
  trim(wings,'Loggia copper roof',x,16.9,7,40,1.1,74,sage,M.Metal)
  for z=-27,41,8.5 do trim(wings,'Copper roof seam',x,17.5,z,39,.15,.17,gold,M.Metal) end
  label(wings,s<0 and 'THE ARENAS' or 'THE CHASE','EXPLORE MAPS IN THE LOBBY MENU',s*63,12,7,45,3.5,turn,lime)
  for i=1,6 do
   local z=-22+(i-1)*11.2;local name=maps[i+(s>0 and 6 or 0)]
   local base=part(wings,'Gallery alcove',s*94,3.2,z,5,6.4,9.5,ink,M.Metal,true)
   label(wings,name:upper(),'RUN  /  SPRINT  /  DODGE',s*91.3,5.1,z,8.7,2.3,turn,cream)
   for j=1,3 do
    local tint=({sage,gold,R(136,175,190),R(193,141,112),R(147,160,197),R(204,113,90)})[i]
    trim(wings,'Abstract arena relief',s*91.15,2+j*.22,z+(j-2)*2.2,.4,1.3+j*.6,1.6,tint,M.Concrete)
   end
   trim(wings,'Gallery bronze reveal',s*91.3,.6,z,.3,.15,8.7,gold,M.Metal)
  end
  bench(wings,s*85.5,0,29,s*math.pi/2);bench(wings,s*85.5,0,-15,s*math.pi/2)
 end
 local welcome=group(model,'Arrival gate')
 arch(welcome,0,0,79,50,16)
 label(welcome,'HUSS A BOMB','RUN  /  SPRINT  /  DODGE',0,19.8,81,34,4.5,nil,lime)
 label(welcome,'WELCOME TO THE CHASE','NO JUMPING. KEEP YOUR FEET MOVING.',0,19.8,77,34,4.5,CFrame.Angles(0,math.pi,0),cream)
 for _,s in ipairs({-1,1}) do
  label(welcome,s<0 and 'THE RULES' or 'TAKE A BREATHER',s<0 and 'PASS THE BOMB. SURVIVE THE FUSE.' or 'USE GO AFK IN YOUR LOBBY MENU.',s*20,5,70,14,5,CFrame.Angles(0,s*.2,0),cream)
  trim(welcome,'Arrival board post',s*20,2,70,.7,4,.7,ink,M.Metal)
 end
 local edge=group(model,'Island edge / continuous containment')
 for _,s in ipairs({-1,1}) do
  part(edge,'East west wall',s*101,3,0,2,6,188,stone,M.Limestone,true)
  trim(edge,'East west coping',s*101,6.05,0,2.5,.45,188,cream,M.Limestone)
  part(edge,'North south wall',0,3,s*93,200,6,2,stone,M.Limestone,true)
  trim(edge,'North south coping',0,6.05,s*93,200,.45,2.5,cream,M.Limestone)
  for z=-84,84,14 do
   trim(edge,'Boundary pilaster',s*99.8,3,z,.5,6,2,cream,M.Limestone)
   trim(edge,'Boundary cap',s*101,6.6,z,3,.75,3,stone,M.Limestone)
  end
  for x=-84,84,14 do trim(edge,'Boundary pilaster',x,3,s*91.8,2,6,.5,cream,M.Limestone) end
 end
 local backdrop=group(model,'Garden skyline / non-colliding scenery')
 for _,s in ipairs({-1,1}) do for i=1,6 do
  local x=s*(111+(i%2)*8);local z=-83+(i-1)*32
  tree(backdrop,x,-2,z,22+(i%3)*3,i*.7)
  ball(backdrop,'Distant limestone boulder',x,-2,z,14,10,15,stone,M.Rock)
 end end
 local spawn=part(model,'LobbySpawn',0,.5,64,8,1,8,cream,M.SmoothPlastic,false,nil,'SpawnLocation')
 spawn.Transparency=1;spawn.Neutral=true;spawn.Duration=0;spawn.Enabled=true
 table.insert(geometry.Spawns,{Name='LobbySpawn',X=0,Y=.5,Z=64})
 local function route(name,width,points) table.insert(geometry.Routes,{Name=name,Width=width,Points=points}) end
 local function p(x,y,z) return {X=x,Y=y,Z=z} end
 for _,s in ipairs({-1,1}) do
  route((s<0 and 'West' or 'East')..' arrival circuit',12,{p(0,0,64),p(0,0,40),p(s*36,0,40),p(s*36,0,0),p(s*36,0,-16),p(s*54,0,-16),p(s*54,0,-24),p(s*54,5,-48),p(s*54,5,-65),p(0,5,-65)})
  route((s<0 and 'West' or 'East')..' gallery access',10,{p(s*36,0,36),p(s*77,0,36),p(s*77,0,7),p(s*54,0,7),p(s*36,0,7)})
 end
 route('Fountain south promenade',12,{p(-36,0,26),p(0,0,26),p(36,0,26)})
 route('Fountain north promenade',10,{p(-36,0,-19),p(0,0,-19),p(36,0,-19)})
 if origin then for _,o in ipairs(model:GetDescendants()) do if o:IsA('BasePart') then o.CFrame=origin*o.CFrame end end end
 return model
end
function Builder.GetGeometry() return geometry end
return Builder

end)()

local edits={{hud,patchHUD(hud.Source)},{movement,patchMovement(movement.Source)},{motion,sources.Motion}}
local storage=game:GetService('ServerStorage')
local backup=Instance.new('Folder');backup.Name='LobbyAudioActionBackup_'..os.time()
while storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local staging=Instance.new('Folder');staging.Name='V6Staging'
local audio=Instance.new('LocalScript');audio.Name='GameAudioV6';audio.Disabled=true
local newLobby,originalSources=nil,{}
local oldFlag=workspace:GetAttribute('HussDodgeV5')
local oldDuration=workspace:GetAttribute('HussDodgeDuration')
local oldMotionDisabled=motion.Disabled
local oldAudioDisabled=oldAudio and oldAudio.Disabled
local oldLobbyParent=oldLobby.Parent
local oldAudioParent=oldAudio and oldAudio.Parent
local ok,err=pcall(function()
 for _,edit in ipairs(edits) do
  local object,source=edit[1],edit[2]
  assert(object.Archivable,object.Name..' must be Archivable. Nothing changed.')
  originalSources[object]=object.Source
  local copy=object:Clone();if copy:IsA('BaseScript') then copy.Disabled=true end;copy.Parent=backup
  local probe=Instance.new(object.ClassName)
  local written,message=pcall(function() probe.Source=source end);probe:Destroy();assert(written,message)
 end
 audio.Source=sources.Audio
 newLobby=buildLobby.Build(staging)
 assert(newLobby and newLobby:IsA('Model') and newLobby.Name=='Lobby' and newLobby.Parent==staging,'Lobby construction failed.')
 local spawn=newLobby:FindFirstChild('LobbySpawn')
 assert(spawn and spawn:IsA('SpawnLocation'),'New lobby is missing its SpawnLocation.')
 -- Preserve the existing spawn location; the new lobby can be far from the arena.
 newLobby:PivotTo(newLobby:GetPivot()+(oldSpawn.Position-spawn.Position))
end)
if not ok then audio:Destroy();staging:Destroy();backup:Destroy();error('Preflight stopped; originals preserved: '..tostring(err)) end
ok,err=pcall(function()
 backup.Parent=storage
 for _,edit in ipairs(edits) do edit[1].Source=edit[2] end
 oldLobby.Parent=backup
 if oldAudio then oldAudio.Disabled=true;oldAudio.Parent=backup end
 workspace:SetAttribute('HussDodgeV5',true)
 workspace:SetAttribute('HussDodgeDuration',.72)
 motion.Disabled=false
 newLobby.Parent=workspace
 audio.Parent=scripts;audio.Disabled=false
end)
if not ok then
 local failures={}
 local function restore(fn) local success,message=pcall(fn);if not success then table.insert(failures,tostring(message)) end end
 restore(function() audio:Destroy() end)
 restore(function() newLobby:Destroy() end)
 for object,source in pairs(originalSources) do restore(function() object.Source=source end) end
 restore(function() oldLobby.Parent=oldLobbyParent end)
 if oldAudio then restore(function() oldAudio.Parent=oldAudioParent;oldAudio.Disabled=oldAudioDisabled end) end
 restore(function() motion.Disabled=oldMotionDisabled end)
 restore(function() workspace:SetAttribute('HussDodgeV5',oldFlag) end)
 restore(function() workspace:SetAttribute('HussDodgeDuration',oldDuration) end)
 staging:Destroy()
 if #failures==0 then backup:Destroy();error('Installation rolled back: '..tostring(err)) end
 error('Installation stopped. Backups: ServerStorage/'..backup.Name..'. Restore errors: '..table.concat(failures,'; ')..'. Original error: '..tostring(err))
end
staging:Destroy()
print('V6 installed: music, game sounds, new lobby and faster action dodge. Cooldown remains 1.5s.')
print('Original lobby and scripts: ServerStorage/'..backup.Name..'. Save the place, then press Play.')
