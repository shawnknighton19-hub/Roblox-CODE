--!nonstrict
-- V15: trails keep their imported preview; non-trail accents use native geometry.
-- Legacy trail code is lazy and byte-preserved below, including its bounded update loop.
local function legacyTrailCanvas()
--!nonstrict
-- HAB_COLLECTIONS_6. Actual pack textures in a bounded 2D animated preview.
-- This does not change the native world renderer or grant texture permissions.
local Run=game:GetService('RunService')
local Players=game:GetService('Players')
local Catalog=require(script.Parent.Catalog)
local Data=require(script.Parent.ExtraFXData)
local F={};local live={};local warned={};local elapsed=0
local function finite(v) return type(v)=='number' and v==v and v>-math.huge and v<math.huge end
local function mean(v,default)
 if finite(v) then return v end
 if type(v)=='table' and finite(v[1]) and finite(v[2]) then return (v[1]+v[2])*.5 end
 return default
end
local function number(keys,t,default)
 if finite(keys) then return keys end
 if type(keys)~='table' or #keys==0 then return default end
 if t<=keys[1][1] then return keys[1][2] end
 for i=2,#keys do
  local a,b=keys[i-1],keys[i]
  if t<=b[1] then return a[2]+(b[2]-a[2])*math.clamp((t-a[1])/math.max(.0001,b[1]-a[1]),0,1) end
 end
 return keys[#keys][2]
end
local function extrema(keys,maximum,default)
 if finite(keys) then return keys end
 if type(keys)~='table' or #keys==0 then return default end
 local n=maximum and -math.huge or math.huge
 for _,k in ipairs(keys) do if type(k)=='table' and finite(k[2]) then n=maximum and math.max(n,k[2]) or math.min(n,k[2]) end end
 return finite(n) and n or default
end
local function tint(keys,t)
 if type(keys)~='table' or #keys==0 then return Color3.new(1,1,1) end
 local a,b=keys[1],keys[#keys]
 for i=2,#keys do if t<=keys[i][1] then a,b=keys[i-1],keys[i];break end end
 local c=Color3.new(a[2],a[3],a[4]):Lerp(Color3.new(b[2],b[3],b[4]),math.clamp((t-a[1])/math.max(.001,b[1]-a[1]),0,1))
 -- Lift nearly-black thumbnail ink for readability; world materials stay untouched.
 if c.R+c.G+c.B<.3 then c=c:Lerp(Color3.fromRGB(132,145,176),.55) end
 return c
end
local gridValues={}
for _,e in ipairs(Enum.ParticleFlipbookLayout:GetEnumItems()) do gridValues[e.Value]=({Grid2x2=2,Grid4x4=4,Grid8x8=8})[e.Name] or 1 end
local function visible(o)
 local n=o
 while n do
  if n:IsA('GuiObject') and not n.Visible then return false end
  if n:IsA('ScreenGui') then return n.Enabled end
  n=n.Parent
 end
 return false
end
local function sprites(parent,texture,grid,z)
 local m=Instance.new('Frame');m.Name='SpriteClip';m.AnchorPoint=Vector2.new(.5,.5)
 m.Size=UDim2.fromScale(.72,.72);m.Position=UDim2.fromScale(.5,.5)
 m.BackgroundTransparency=1;m.BorderSizePixel=0;m.ClipsDescendants=true;m.ZIndex=z;m.Rotation=0;m.Parent=parent
 local i=Instance.new('ImageLabel');i.Name='PackArtwork';i.BackgroundTransparency=1;i.BorderSizePixel=0
 i.Image=texture;i.Size=UDim2.fromScale(grid,grid);i.ImageTransparency=0;i.ScaleType=Enum.ScaleType.Stretch;i.ZIndex=z;i.Parent=m
 return m,i
end
local function showStatus(h,status,message)
 h.Status=status
 if h.Parent and h.Parent.Parent then h.Parent:SetAttribute('HABFXPreviewStatus',status) end
 h.Label.Visible=message~=nil;h.Label.Text=message or ''
end
function F.Mount(parent,id,layerLimit)
 local sound=script.Parent:FindFirstChild('HABKillSounds')
 if sound and require(sound).ById[id] then return require(script.Parent.HABKillSoundPlayer).Mount(parent,id) end

 local item=Catalog.Get(id)
 if not item then return nil end
 local sourceId=item.SourceId or id
 local h={Parent=parent,Id=id,Sprites={},Time=0,Paused=false,Stopped=false,Age=0,Status='LOADING',Tint=item.Tint}
 local label=Instance.new('TextLabel');label.Name='PreviewStatus';label.BackgroundTransparency=1
 label.Size=UDim2.new(1,-12,0,42);label.Position=UDim2.new(0,6,.5,-21)
 label.TextWrapped=true;label.TextSize=12;label.Font=Enum.Font.GothamBold;label.TextColor3=Color3.fromRGB(232,240,255)
 label.ZIndex=parent.ZIndex+35;label.Parent=parent;h.Label=label
 local t=Data.Templates[sourceId]
 if not t then
  local e=Catalog.Effects[sourceId]
  if e and e.colour and tostring(e.colour)~='' then
   local m,i=sprites(parent,'rbxassetid://'..e.colour,4,parent.ZIndex+2)
   m.Size=UDim2.fromScale(.96,.96)
   h.Sprites[1]={Mask=m,Image=i,Atlas=true,Life=math.max(.2,e.lifetime or 1)}
   if item.Tint then i.ImageColor3=Color3.new(1,1,1):Lerp(item.Tint,.7) end
  end
 else
  local candidates,seen={},{}
  -- Select usable visible layers FIRST. Empty helper layers cannot consume the preview budget.
  for order,entry in ipairs(t.Entries or {}) do
   local definition=Data.Properties[entry[2]]
   local p=definition and definition[2]
   if type(p)=='table' and type(p.Texture)=='string' and p.Texture~='' then
    local alpha=extrema(p.Transparency,false,0)
    local maximum=extrema(p.Size,true,mean(p.Width0,2))
    if alpha<.995 and maximum>0 then
     local key=tostring(entry[2])
     if not seen[key] then
      seen[key]=true
      local a=(entry[1]==1 and entry[4] or entry[5]) or {}
      candidates[#candidates+1]={P=p,Entry=entry,Order=order,Kind=definition[1],Max=maximum,
       Score=maximum*(1-alpha),Delay=math.clamp(a.EmitDelay or 0,0,.5)}
     end
    end
   end
  end
  table.sort(candidates,function(a,b) if a.Score==b.Score then return a.Order<b.Order end;return a.Score>b.Score end)
  local cap=math.clamp(layerLimit or 10,1,12)
  local count=math.min(cap,#candidates)
  local radius=math.max(1,t.Radius or 4)
  local maxSize=0
  for i=1,count do maxSize=math.max(maxSize,candidates[i].Max) end
  maxSize=math.max(.1,maxSize)
  -- Broad layers behind detailed ones.
  for n=1,count do
   local c=candidates[n];local p=c.P;local grid=gridValues[p.FlipbookLayout] or 1
   local m,i=sprites(parent,p.Texture,grid,parent.ZIndex+1+n)
   local cf=c.Entry[3] or {0,0,0}
   h.Sprites[#h.Sprites+1]={Mask=m,Image=i,P=p,Grid=grid,Max=c.Max,Normalize=maxSize,
    Life=math.clamp(mean(p.Lifetime,1)/math.max(.1,p.TimeScale or 1),.35,3),Delay=c.Delay,
    X=math.clamp((cf[1] or 0)/radius*.15,-.16,.16),Y=math.clamp(-(cf[2] or 0)/radius*.15,-.16,.16),
    Spin=mean(p.RotSpeed,0),Rotation=mean(p.Rotation,0),Order=n,Beam=c.Kind~='ParticleEmitter'}
  end
 end
 function h:Stop()
  if self.Stopped then return end;self.Stopped=true
  for _,s in ipairs(self.Sprites) do s.Mask:Destroy() end
  self.Label:Destroy()
 end
 function h:Retry()
  self.Age=0;showStatus(self,'LOADING','Loading preview...')
  for _,s in ipairs(self.Sprites) do local image=s.Image.Image;s.Image.Image='';s.Image.Image=image end
 end
 showStatus(h,'LOADING',#h.Sprites==0 and 'No preview texture in this preset' or 'Loading preview...')
 if #h.Sprites==0 then showStatus(h,'NO_TEXTURE','No preview texture in this preset') end
 live[#live+1]=h
 return h
end
local function step(h,dt,low)
 h.Age=h.Age+dt;h.Time=h.Time+dt
 local loaded=0
 for _,s in ipairs(h.Sprites) do
  if s.Image.IsLoaded then loaded=loaded+1 end
  if s.Atlas then
   local frame=low and 7 or math.floor(((h.Time+s.Life*.32)/s.Life)*16)%16
   s.Image.Position=UDim2.fromScale(-(frame%4),-math.floor(frame/4))
  else
   -- Start on a useful frame instead of a transparent first frame; loop the real curves.
   local cycle=s.Life+.14
   local age=low and s.Life*.34 or ((h.Time+s.Life*.34)%cycle)
   local t=math.clamp(age/s.Life,0,1)
   local size=math.clamp(number(s.P.Size,t,s.Max)/s.Normalize*.88,.12,.96)
   local squash=math.clamp(number(s.P.Squash,t,0),-.65,1)
   s.Mask.Size=UDim2.fromScale(math.min(1.1,size*(1+math.max(0,squash))),math.min(1.1,size*(1+math.max(0,-squash))))
   s.Mask.Position=UDim2.fromScale(.5+s.X,.5+s.Y)
   -- Atlas clip parents always remain axis-aligned.
   s.Mask.Rotation=0;s.Image.Rotation=s.Grid>1 and 0 or s.Rotation+(low and 0 or s.Spin*age)
   s.Image.ImageColor3=tint(s.P.Color,t)
   if h.Tint then s.Image.ImageColor3=s.Image.ImageColor3:Lerp(h.Tint,.70) end
   s.Image.ImageTransparency=age>s.Life and 1 or math.clamp(number(s.P.Transparency,t,0),0,1)
   local frame=s.Grid==1 and 0 or math.min(s.Grid*s.Grid-1,math.floor(t*s.Grid*s.Grid))
   s.Image.Position=UDim2.fromScale(-(frame%s.Grid),-math.floor(frame/s.Grid))
  end
 end
 if #h.Sprites>0 then
  if loaded>0 then showStatus(h,loaded==#h.Sprites and 'READY' or 'PARTIAL',nil)
  elseif h.Age>12 then
   showStatus(h,'UNAVAILABLE','Preview unavailable\nItem ownership is unchanged')
   if not warned[h.Id] then
    warned[h.Id]=true
    warn('[HAB Preview] Artwork did not load for '..h.Id..'. Check its texture access/moderation. This is not an inventory deletion.')
   end
  end
 end
end
Run.RenderStepped:Connect(function(dt)
 elapsed=elapsed+math.min(dt,.1);if elapsed<1/30 then return end
 local stepTime=elapsed;elapsed=0
 local player=Players.LocalPlayer
 local low=player:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true
 for i=#live,1,-1 do
  local h=live[i]
  if h.Stopped or not h.Parent.Parent then h:Stop();table.remove(live,i)
  elseif not h.Paused and visible(h.Parent) then
   local ok,err=pcall(step,h,stepTime,low)
   if not ok then
    for _,s in ipairs(h.Sprites) do s.Mask.Visible=false end
    showStatus(h,'ERROR','Preview unavailable');h.Paused=true
    warn('[HAB Preview] '..h.Id..': '..tostring(err))
   end
  end
 end
end)
return F
-- HAB_EXPANSION_7

-- HAB_FUN_9

end
local Catalog=require(script.Parent.Catalog)
local F={Version=15}
local legacy
local function round(parent,radius)
 local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,radius);corner.Parent=parent
end
local function nativePreview(parent,id,item)
 local frame=Instance.new('Frame');frame.Name='NativeAccentPreview';frame.Size=UDim2.fromScale(1,1)
 frame.BackgroundTransparency=1;frame.BorderSizePixel=0;frame.ZIndex=parent.ZIndex+1;frame.Parent=parent
 local view=Instance.new('ViewportFrame');view.Name='Geometry';view.BackgroundTransparency=1
 view.Size=UDim2.fromScale(.98,.78);view.Position=UDim2.fromScale(.01,.01);view.ZIndex=parent.ZIndex+2
 view.Ambient=Color3.fromRGB(185,195,219);view.LightColor=Color3.fromRGB(255,248,229)
 view.LightDirection=Vector3.new(-1,-1,-1);view.Parent=frame
 local world=Instance.new('WorldModel');world.Name='Accent';world.Parent=view
 local camera=Instance.new('Camera');camera.FieldOfView=32
 camera.CFrame=CFrame.lookAt(Vector3.new(6,4.7,7),Vector3.new(0,.25,0));camera.Parent=view;view.CurrentCamera=camera
 local color=typeof(item.Tint)=='Color3' and item.Tint or typeof(item.Color)=='Color3' and item.Color or Color3.fromRGB(139,224,255)
 local function part(name,size,position,shape,tint)
  local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=position;p.Shape=shape or Enum.PartType.Block
  p.Color=tint or color;p.Material=Enum.Material.Neon;p.Anchored=true;p.Massless=true
  p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=world
  return p
 end
 if item.Category=='BombFX' then
  local bomb=part('Bomb',Vector3.new(1.7,1.7,1.7),CFrame.new(),Enum.PartType.Ball,Color3.fromRGB(38,47,66))
  bomb.Material=Enum.Material.SmoothPlastic
  local fuse=part('Fuse',Vector3.new(.13,.55,.13),CFrame.new(.13,.99,0)*CFrame.Angles(0,0,-.35),nil,Color3.fromRGB(255,212,111))
  fuse.Material=Enum.Material.SmoothPlastic
  for i=1,4 do local a=i*math.pi/2
   part('OrbitSpark',Vector3.new(.23,.23,.23),CFrame.new(math.cos(a)*1.35,math.sin(a*2)*.18,math.sin(a)*1.35),Enum.PartType.Ball)
  end
 elseif item.Category=='Aura' then
  for i=1,6 do local a=i*math.pi/3
   part('AuraSegment',Vector3.new(.16,.12,.58),CFrame.new(math.cos(a)*1.5,0,math.sin(a)*1.5)*CFrame.Angles(0,-a,0))
  end
 else
  for i=1,5 do local a=(i-3)*.42
   part('AccentSpark',Vector3.new(.13,.13,.55),CFrame.new(math.sin(a)*1.55,math.cos(a)*1.4-.9,0)*CFrame.Angles(0,0,-a))
  end
 end
 local label=Instance.new('TextLabel');label.Name='PreviewStatus';label.BackgroundColor3=Color3.fromRGB(34,43,65)
 label.BackgroundTransparency=.14;label.BorderSizePixel=0;label.AnchorPoint=Vector2.new(.5,1)
 label.Size=UDim2.new(.9,0,.20,0);label.Position=UDim2.fromScale(.5,.98)
 label.Font=Enum.Font.GothamBold;label.Text='3D ACCENT';label.TextSize=12;label.TextScaled=true
 label.TextColor3=Color3.fromRGB(235,246,255);label.ZIndex=parent.ZIndex+4;label.Parent=frame
 local limit=Instance.new('UITextSizeConstraint');limit.MinTextSize=8;limit.MaxTextSize=13;limit.Parent=label
 local padding=Instance.new('UIPadding');padding.PaddingTop=UDim.new(0,3);padding.PaddingBottom=UDim.new(0,3);padding.Parent=label
 round(label,8)
 parent:SetAttribute('HABFXPreviewStatus','READY')
 local h={Parent=parent,Id=id,Status='READY',Paused=false,Stopped=false,Label=label,Frame=frame}
 function h:Stop()
  if self.Stopped then return end;self.Stopped=true;frame:Destroy()
 end
 h.Destroy=h.Stop
 function h:Retry() if not self.Stopped then self.Status='READY';parent:SetAttribute('HABFXPreviewStatus','READY') end end
 return h
end
function F.Mount(parent,id,layerLimit)
 local sound=script.Parent:FindFirstChild('HABKillSounds')
 if sound and require(sound).ById[id] then
  local h=require(script.Parent.HABKillSoundPlayer).Mount(parent,id)
  if h and not h.Destroy then h.Destroy=h.Stop end
  return h
 end
 local item=Catalog.Get(id)
 if not item then return nil end
 if item.Category=='Trail' then
  if not legacy then legacy=legacyTrailCanvas() end
  local h=legacy.Mount(parent,id,layerLimit)
  if h and not h.Destroy then h.Destroy=h.Stop end
  return h
 end
 return nativePreview(parent,id,item)
end
return F
