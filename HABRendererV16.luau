--!nonstrict
-- HAB_CRATE_UPGRADE_2. Original synchronized pack layers with reserved detonation capacity.
local Run=game:GetService('RunService')
assert(Run:IsClient(),'Renderer is client only')
local Players=game:GetService('Players')
local Input=game:GetService('UserInputService')
local Content=game:GetService('ContentProvider')
local Effects=require(assert(script.Parent:WaitForChild('Effects',15),'Effects missing'))
local Native=require(assert(script.Parent:WaitForChild('NativeFX',15),'NativeFX missing'))
local R={};local live={};local fetched={};local retryAt={};local inFlight=0
local player=Players.LocalPlayer
local folder=Instance.new('Folder');folder.Name='HABHalloweenLocalFX';folder.Parent=workspace
local CAP=Input.TouchEnabled and 36 or 72
local RESERVE=6
local function reduced() return player:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function fade(alpha)
    return NumberSequence.new({NumberSequenceKeypoint.new(0,alpha),NumberSequenceKeypoint.new(.82,alpha),NumberSequenceKeypoint.new(1,1)})
end
function R.Preload(id)
    if Native.Has(id) then Native.Preload(id);return end
    local effect=Effects[id]
    if not effect or fetched[id]=='ready' or fetched[id]=='loading' or os.clock()<(retryAt[id] or 0) or inFlight>=3 then return end
    fetched[id]='loading';inFlight=inFlight+1
    task.spawn(function()
        local assets={'rbxassetid://'..effect.colour}
        if effect.mono~='' then assets[#assets+1]='rbxassetid://'..effect.mono end
        local failed=false
        local ok=pcall(function()
            Content:PreloadAsync(assets,function(asset,status)
                if status~=Enum.AssetFetchStatus.Success then
                    failed=true
                    warn('[HAB Pack] Texture could not load: '..asset..'. Check permissions for this experience.')
                end
            end)
        end)
        fetched[id]=ok and not failed and 'ready' or 'unavailable'
        if fetched[id]=='unavailable' then retryAt[id]=os.clock()+60 end
        inFlight=inFlight-1
    end)
end
function R.Status(id) return Native.Has(id) and Native.Status(id) or fetched[id] end
function R.Play(id,where,size,offset,follow,opacity,priority)
    if Native.Has(id) then return Native.Play(id,where,size,offset,follow,opacity,priority) end
    local effect=Effects[id]
    if not effect or reduced() then return nil end
    local now=os.clock()
    for i=#live,1,-1 do
        local h=live[i]
        if not h.Attachment or not h.Attachment.Parent or h.End<=now then h:Stop();table.remove(live,i) end
    end
    if priority then
        while #live>=CAP do
            local index=1
            for i,h in ipairs(live) do if not h.Priority then index=i;break end end
            table.remove(live,index):Stop()
        end
    elseif #live>=CAP-RESERVE then return nil end
    R.Preload(id)
    local host,attachment
    if typeof(where)=='Instance' and where:IsA('BasePart') and where.Parent then
        attachment=Instance.new('Attachment');attachment.Name='HABPack_'..id
        attachment.Position=offset or Vector3.zero;attachment.Parent=where
    else
        local cf=typeof(where)=='CFrame' and where or typeof(where)=='Vector3' and CFrame.new(where) or nil
        if not cf then return nil end
        host=Instance.new('Part');host.Name='HABPackBurst';host.Size=Vector3.new(.1,.1,.1);host.CFrame=cf
        host.Transparency=1;host.Anchored=true;host.CanCollide=false;host.CanTouch=false;host.CanQuery=false;host.CastShadow=false;host.Parent=folder
        attachment=Instance.new('Attachment');attachment.Name='HABPack_'..id;attachment.Parent=host
    end
    local width=math.clamp(size or 3,.5,priority and 19 or 12)/math.max(.1,effect.fit)
    local life=effect.lifetime
    local emitters={}
    local function layer(name,asset,scale,colour,emission,alpha,z,brightness)
        if asset=='' then return end
        local e=Instance.new('ParticleEmitter');e.Name=name;e.Texture='rbxassetid://'..asset
        e.Rate=0;e.Enabled=false;e.Lifetime=NumberRange.new(life);e.Speed=NumberRange.new(0)
        e.SpreadAngle=Vector2.zero;e.Rotation=NumberRange.new(0);e.RotSpeed=NumberRange.new(0)
        e.FlipbookLayout=Enum.ParticleFlipbookLayout.Grid4x4;e.FlipbookMode=Enum.ParticleFlipbookMode.OneShot
        e.FlipbookStartRandom=false;e.FlipbookBlendFrames=true;e.Orientation=Enum.ParticleOrientation.FacingCamera
        e.Size=NumberSequence.new(width*scale);e.LightInfluence=0;e.LightEmission=emission;e.Brightness=brightness
        e.Color=ColorSequence.new(colour);e.Transparency=fade(math.max(alpha,opacity or 0));e.ZOffset=z
        e.LockedToPart=follow==true;e.Parent=attachment
        emitters[#emitters+1]=e
    end
    local hue,saturation=effect.glow:ToHSV()
    layer('Backing',effect.mono,1.03,Color3.fromHSV(hue,math.max(saturation,.35),.07),0,.65,-.2,1)
    layer('Body',effect.colour,1,Color3.new(1,1,1),.5,0,.12,1.7)
    layer('Glow',effect.colour,1.04,Color3.new(1,1,1),1,.67,.18,1.0)
    local handle={Attachment=attachment,Host=host,End=now+life+4,Priority=priority==true}
    function handle:Stop()
        if self.Attachment then self.Attachment:Destroy();self.Attachment=nil end
        if self.Host then self.Host:Destroy();self.Host=nil end
    end
    live[#live+1]=handle
    task.spawn(function()
        local deadline=os.clock()+3
        while fetched[id]=='loading' and os.clock()<deadline and handle.Attachment do task.wait(.05) end
        handle.End=os.clock()+life+.2
        if handle.Attachment and handle.Attachment.Parent and not reduced() then
            for _,e in ipairs(emitters) do if e.Parent then e:Emit(1) end end
        end
    end)
    return handle
end
Run.Heartbeat:Connect(function()
    local now=os.clock();local off=reduced()
    for i=#live,1,-1 do
        local h=live[i]
        if off or now>=h.End or not h.Attachment or not h.Attachment.Parent then h:Stop();table.remove(live,i) end
    end
end)
-- HAB_CRATES_REPAIR_3

local ExpandedCatalog=require(script.Parent.Catalog)
local AbilityConfig=require(script.Parent.Parent.HABExpansion.Config)
local abilityArt={}
for _,definition in ipairs(AbilityConfig.Abilities) do if type(definition.Effect)=='string' then abilityArt[definition.Effect]=true end end
local function allowedVisual(id,item,options)
 if options and options.Ability==true and abilityArt[id]==true then return true end
 return item and (item.Category=='Trail' or item.Category=='Aura') and not item.RetiredFinisher
end
local originalPlay,originalPreload,originalStatus=R.Play,R.Preload,R.Status
local function sourceFor(id)
 local item=ExpandedCatalog.ById[id]
 return item and item.SourceId or id,item
end
function R.Preload(id) local source=sourceFor(id);return originalPreload(source) end
function R.Status(id) local source=sourceFor(id);return originalStatus(source) end
function R.Play(id,where,size,offset,follow,opacity,priority,options)
 local source,item=sourceFor(id)
 if item and (item.RetiredFinisher or item.Type=='KillSound') then return nil end
 options=type(options)=='table' and options or {}
 if not allowedVisual(id,item,options) then return nil end
 local amount=math.clamp(tonumber(size) or 4,.4,19)
 local handle=originalPlay(source,where,amount,offset,follow,opacity,priority)
 if handle and options.Tint then
  local function match(o)
   if o:IsA('ParticleEmitter') or o:IsA('Beam') or o:IsA('Trail') then
    local keys={}
    for _,k in ipairs(o.Color.Keypoints) do keys[#keys+1]=ColorSequenceKeypoint.new(k.Time,k.Value:Lerp(options.Tint,.45)) end
    o.Color=ColorSequence.new(keys)
   end
  end
  if handle.Attachment then for _,o in ipairs(handle.Attachment:GetDescendants()) do match(o) end end
 end
 if handle and item and item.Tint then
  local function tint(o)
   if o:IsA('ParticleEmitter') or o:IsA('Beam') or o:IsA('Trail') then
    local keys={}
    for _,k in ipairs(o.Color.Keypoints) do keys[#keys+1]=ColorSequenceKeypoint.new(k.Time,k.Value:Lerp(item.Tint,.70)) end
    o.Color=ColorSequence.new(keys)
   end
  end
  if handle.Attachment then for _,o in ipairs(handle.Attachment:GetDescendants()) do tint(o) end end
  if not handle.Attachment and handle.Objects then for _,o in pairs(handle.Objects) do if typeof(o)=='Instance' then tint(o) end end end
 end
 return handle
end

return R
-- HAB_EXPANSION_7

-- HAB_FUN_9
