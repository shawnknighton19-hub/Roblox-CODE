--!nonstrict
-- HAB_CRATES_REPAIR_3 | Sanitized native pack effects, no imported scripts.
local Run=game:GetService('RunService')
assert(Run:IsClient(),'Native effect renderer is client only')
local Input=game:GetService('UserInputService')
local Content=game:GetService('ContentProvider')
local Players=game:GetService('Players')
local Data=require(assert(script.Parent:WaitForChild('ExtraFXData',20),'ExtraFXData missing'))
local R={}
local active={}
local layerCount=0
local MAX=Input.TouchEnabled and 190 or 420
local PER=Input.TouchEnabled and 20 or 38
local root=Instance.new('Folder');root.Name='HABNativePackVFX';root.Parent=workspace
local status,retry,queue={},{},{}
local workers=0
local issues={}
local enumKinds={EmissionDirection='NormalId',FlipbookLayout='ParticleFlipbookLayout',FlipbookMode='ParticleFlipbookMode',
 Orientation='ParticleOrientation',Shape='ParticleEmitterShape',ShapeInOut='ParticleEmitterShapeInOut',
 ShapeStyle='ParticleEmitterShapeStyle',TextureMode='TextureMode'}
local ranges={Lifetime=true,Speed=true,RotSpeed=true,Rotation=true,FlipbookFramerate=true}
local sequences={Size=true,Transparency=true,Squash=true,WidthScale=true}
local scaled={Size=true,Speed=true,Acceleration=true,ZOffset=true,Width0=true,Width1=true,CurveSize0=true,CurveSize1=true,TextureLength=true,MaxLength=true,MinLength=true}
local function reduced()
 return Players.LocalPlayer:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true
end
local function warnOnce(key,message)
 if not issues[key] then issues[key]=true;warn('[HAB Pack] '..message) end
end
local function convert(key,value,scale)
 local multiplier=scaled[key] and scale or 1
 if enumKinds[key] then
  for _,item in ipairs(Enum[enumKinds[key]]:GetEnumItems()) do if item.Value==value then return item end end
  error('Unknown enum value for '..key)
 end
 if key=='Color' then
  local keys={}
  for _,v in ipairs(value) do keys[#keys+1]=ColorSequenceKeypoint.new(v[1],Color3.new(v[2],v[3],v[4])) end
  return ColorSequence.new(keys)
 end
 if sequences[key] then
  local keys={}
  for _,v in ipairs(value) do keys[#keys+1]=NumberSequenceKeypoint.new(v[1],v[2]*multiplier,v[3]*multiplier) end
  return NumberSequence.new(keys)
 end
 if ranges[key] then
  if type(value)=='table' then return NumberRange.new(value[1]*multiplier,value[2]*multiplier) end
  return value*multiplier -- Trail.Lifetime is a scalar, not ParticleEmitter.Lifetime
 end
 if key=='Acceleration' then return Vector3.new(value[1],value[2],value[3])*scale end
 if key=='SpreadAngle' then return Vector2.new(value[1],value[2]) end
 if type(value)=='number' then return value*multiplier end
 return value
end
local function apply(o,props,scale)
 -- Layout is set before flipbook details. A bad optional property must not kill the shop.
 if props.FlipbookLayout~=nil then
  local ok,err=pcall(function() o.FlipbookLayout=convert('FlipbookLayout',props.FlipbookLayout,scale) end)
  if not ok then warnOnce('layout',tostring(err)) end
 end
 for key,value in pairs(props) do
  if key~='FlipbookLayout' then
   local ok,err=pcall(function() o[key]=convert(key,value,scale) end)
   if not ok then warnOnce(o.ClassName..key,o.ClassName..'.'..key..': '..tostring(err)) end
  end
 end
end
local function frame(values,scale,center,limit)
 center=center or Vector3.zero
 local p=(Vector3.new(values[1],values[2],values[3])-center)*scale
 -- Imported demonstrations sometimes retain coordinates hundreds of studs from their root.
 limit=limit or 18
 if p.Magnitude>limit then p=p.Unit*limit end
 return CFrame.new(p)*CFrame.new(0,0,0,table.unpack(values,4,12))
end
local fits={}
local function fitted(t)
 if fits[t] then return fits[t] end
 local entries,x,y,z={}, {},{},{}
 for _,entry in ipairs(t.Entries) do
  local class,props=table.unpack(Data.Properties[entry[2]])
  local minAlpha=1
  for _,k in ipairs(props.Transparency or {{0,0,0}}) do minAlpha=math.min(minAlpha,k[2]-(k[3] or 0)) end
  local visible=(props.Texture and props.Texture~='') or class=='Beam' or class=='Trail'
  if visible and minAlpha<.995 then
   local size=0
   for _,k in ipairs(props.Size or {}) do size=math.max(size,k[2]+(k[3] or 0)) end
   if class~='ParticleEmitter' then size=math.max(props.Width0 or 0,props.Width1 or 0,.2) end
   if size>.005 then
    entries[#entries+1]=entry
    x[#x+1]=entry[3][1];y[#y+1]=entry[3][2];z[#z+1]=entry[3][3]
   end
  end
 end
 local function median(v) table.sort(v);return v[math.max(1,math.ceil(#v*.5))] or 0 end
 local center=Vector3.new(median(x),median(y),median(z))
 local radii={}
 for _,entry in ipairs(entries) do
  local props=Data.Properties[entry[2]][2];local size=0
  for _,k in ipairs(props.Size or {}) do size=math.max(size,k[2]+(k[3] or 0)) end
  local dist=(Vector3.new(table.unpack(entry[3],1,3))-center).Magnitude
  radii[#radii+1]=dist+size*.5
  if entry[1]~=1 then radii[#radii+1]=(Vector3.new(table.unpack(entry[4],1,3))-center).Magnitude end
 end
 table.sort(radii)
 local radius=math.clamp(radii[math.max(1,math.ceil(#radii*.85))] or 3,3,150)
 local f={Entries=entries,Center=center,Radius=radius};fits[t]=f;return f
end
local function beginPreload(id)
 local t=Data.Templates[id]
 if not t or status[id]=='ready' or status[id]=='loading' or os.clock()<(retry[id] or 0) then return end
 status[id]='loading';queue[#queue+1]=id
end
function R.Preload(id) beginPreload(id) end
function R.Status(id) return status[id] or 'not loaded' end
function R.Has(id) return Data.Templates[id]~=nil end
function R.Info(id) return Data.Templates[id] end
local function pump()
 while workers<2 and #queue>0 do
  local id=table.remove(queue,1);workers=workers+1
  task.spawn(function()
   local all,seen={},{}
   for _,e in ipairs(Data.Templates[id].Entries) do
    local p=Data.Properties[e[2]][2];local asset=p.Texture
    if asset and asset~='' and not seen[asset] then seen[asset]=true;all[#all+1]=asset end
   end
   local bad=false
   local ok,err=pcall(function()
    Content:PreloadAsync(all,function(asset,result)
     if result~=Enum.AssetFetchStatus.Success then bad=true;warnOnce(asset,'Asset unavailable: '..asset..'. Grant this experience access or replace it with an authorized upload.') end
    end)
   end)
   status[id]=ok and not bad and 'ready' or 'asset unavailable'
   if not ok then warnOnce('load_'..id,tostring(err)) end
   retry[id]=os.clock()+45;workers=workers-1
  end)
 end
end
function R.Play(id,where,size,offset,follow,opacity,priority)
 local t=Data.Templates[id]
 if not t or reduced() then return end
 local fit=fitted(t)
 if #fit.Entries==0 then warnOnce(id..'empty','No visible layers in '..id);return end
 if priority then
  local needed=math.min(PER,#fit.Entries)
  while MAX-layerCount<needed and #active>0 do
   local index=1
   for i,h in ipairs(active) do if not h.Priority then index=i;break end end
   table.remove(active,index):Stop()
  end
 elseif layerCount>=MAX-40 then return end
 beginPreload(id)
 local at,subject
 if typeof(where)=='Instance' and where:IsA('BasePart') then subject=where;at=where.CFrame*CFrame.new(offset or Vector3.zero)
 elseif typeof(where)=='CFrame' then at=where
 elseif typeof(where)=='Vector3' then at=CFrame.new(where)
 else return end
 local host=Instance.new('Part');host.Name='Pack_'..id;host.Size=Vector3.new(.1,.1,.1);host.CFrame=at
 host.Anchored=true;host.Transparency=1;host.CanCollide=false;host.CanTouch=false;host.CanQuery=false;host.CastShadow=false;host.Parent=root
 local scale=math.clamp((size or 7)/math.max(3,fit.Radius),.03,3)
 local h={Host=host,Attachment=host,End=os.clock()+math.min(t.Duration,5)+10,Priority=priority==true,Jobs={},Objects={},Layers=0,Id=id,
  Born=os.clock(),Started=false,Subject=follow and subject or nil,Offset=offset or Vector3.zero,CountBudget=Input.TouchEnabled and 240 or 650}
 function h:Stop()
  if self.Stopped then return end;self.Stopped=true
  layerCount=math.max(0,layerCount-self.Layers)
  if self.Host then self.Host:Destroy() end
  self.Host=nil;self.Attachment=nil
 end
 local function attachment(cf)
  local a=Instance.new('Attachment');a.CFrame=cf;a.Parent=host;return a
 end
 local available=math.min(PER,MAX-layerCount,#fit.Entries)
 -- Sample very large assemblies evenly; all authored definitions remain in ExtraFXData.
 for i=1,available do
  local entry=fit.Entries[math.min(#fit.Entries,math.floor((i-.5)*#fit.Entries/available)+1)]
  local definition=Data.Properties[entry[2]]
  local class,props=definition[1],definition[2]
  local o=Instance.new(class)
  o.Name='Imported_'..class
  apply(o,props,scale)
  o.Enabled=false
  local attrs=entry[1]==1 and entry[4] or entry[5]
  local delay=math.clamp(attrs.EmitDelay or 0,0,1.3)
  local duration=math.clamp(attrs.EmitDuration or .35,0,1.6)
  if entry[1]==1 then
   o.Rate=math.min(o.Rate*1.35,Input.TouchEnabled and 28 or 55)
   o.TimeScale=math.max(.5,o.TimeScale)
   pcall(function() o.LocalTransparencyModifier=0 end)
   o.Brightness=math.clamp(o.Brightness*1.25,.9,2.4)
   o.LightInfluence=math.min(o.LightInfluence,.3)
   local speedCap=math.max(3,(size or 7)*1.2)
   o.Speed=NumberRange.new(math.clamp(o.Speed.Min,-speedCap,speedCap),math.clamp(o.Speed.Max,-speedCap,speedCap))
   if follow then o.LockedToPart=true end
   local keys={}
   for _,k in ipairs(o.Transparency.Keypoints) do
    local a=math.clamp(k.Value<.995 and k.Value*.76 or k.Value,0,1)
    keys[#keys+1]=NumberSequenceKeypoint.new(k.Time,a,math.max(0,math.min(k.Envelope,a,1-a)))
   end
   o.Transparency=NumberSequence.new(keys)
   o.Lifetime=NumberRange.new(math.min(o.Lifetime.Min,5),math.min(o.Lifetime.Max,5))
   o.Parent=attachment(frame(entry[3],scale,fit.Center,math.max(1,(size or 7)*(follow and .7 or 1))))
   h.Jobs[#h.Jobs+1]={Object=o,At=delay,Amount=math.clamp(math.ceil((attrs.EmitCount or 6)*1.35),1,32),Duration=duration}
  else
   o.Attachment0=attachment(frame(entry[3],scale,fit.Center,math.max(1,(size or 7)*(follow and .7 or 1))));o.Attachment1=attachment(frame(entry[4],scale,fit.Center,math.max(1,(size or 7)*(follow and .7 or 1))));o.Parent=host
   h.Jobs[#h.Jobs+1]={Object=o,At=delay,Duration=math.max(.15,duration),Amount=0}
  end
  h.Objects[#h.Objects+1]=o;h.Layers=h.Layers+1;layerCount=layerCount+1
 end
 active[#active+1]=h
 return h
end
Run.Heartbeat:Connect(function()
 pump()
 local now=os.clock()
 for i=#active,1,-1 do
  local h=active[i]
  if h.Stopped or reduced() or not h.Host or not h.Host.Parent or now>=h.End or (h.Subject and not h.Subject.Parent) then
   h:Stop();table.remove(active,i)
  else
   if h.Subject then h.Host.CFrame=h.Subject.CFrame*CFrame.new(h.Offset) end
   if not h.Started and (status[h.Id]=='ready' or status[h.Id]=='asset unavailable' or now-h.Born>4) then
    h.Started=now;h.End=now+math.min(Data.Templates[h.Id].Duration,5)+.4
   end
   if h.Started then
    local age=now-h.Started
    for _,job in ipairs(h.Jobs) do
     if not job.Fired and age>=job.At then
      job.Fired=true;job.Until=age+job.Duration
      if job.Object:IsA('ParticleEmitter') then
       local amount=math.min(job.Amount,math.max(0,h.CountBudget))
       h.CountBudget=h.CountBudget-amount
       if amount>0 then job.Object:Emit(amount) end
       job.Object.Enabled=job.Duration>0
      else job.Object.Enabled=true end
     end
     if job.Fired and age>=job.Until then job.Object.Enabled=false end
    end
   end
  end
 end
end)
return R



-- HAB_FUN_9
