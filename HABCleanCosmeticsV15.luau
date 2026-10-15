--!nonstrict
-- Small geometric accents for non-trail cosmetics. Imported trail art keeps its renderer.
local Run=game:GetService('RunService')
assert(Run:IsClient(),'Cosmetic renderer is client only')
local Players=game:GetService('Players')
local Input=game:GetService('UserInputService')
local Catalog=require(script.Parent.Catalog)
local me=Players.LocalPlayer
local V,CF=Vector3.new,CFrame.new
local R={};local active={};local stopped=false
local folder=Instance.new('Folder');folder.Name='HABCleanCosmeticsV15';folder.Parent=workspace
local CAP=Input.TouchEnabled and 12 or 22
local WHITE=Color3.fromRGB(242,250,255)
local function off()
 return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true
  or me:GetAttribute('HussGamePaused')==true or workspace:GetAttribute('HussGamePaused')==true
end
local function frame(where,offset)
 if typeof(where)=='Instance' then
  if not where:IsA('BasePart') or not where.Parent then return nil end
  return where.CFrame*CF(offset or Vector3.zero)
 elseif typeof(where)=='CFrame' then return where*CF(offset or Vector3.zero)
 elseif typeof(where)=='Vector3' then return CF(where+(offset or Vector3.zero)) end
end
local function part(name,size,color,shape)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.Color=color;p.Shape=shape or Enum.PartType.Ball
 p.Material=Enum.Material.Neon;p.Anchored=true;p.Massless=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
 p.Transparency=1;p.Parent=folder;return p
end
function R.Play(id,where,size,offset,follow,opacity,priority,options)
 if stopped or off() then return nil end
 local origin=frame(where,offset);if not origin then return nil end
 local camera=workspace.CurrentCamera;if not camera or (camera.CFrame.Position-origin.Position).Magnitude>100 then return nil end
 local item=Catalog.ById[id]
 if item and (item.Category=='Trail' or item.RetiredFinisher or item.Type=='KillSound') then return nil end
 local kind=item and item.Category or 'Burst'
 if kind~='Aura' and kind~='BombFX' and kind~='DodgeFX' then kind='Burst' end
 local now=os.clock()
 for i=#active,1,-1 do if active[i].Stopped or now>=active[i].End then active[i]:Stop();table.remove(active,i) end end
 if #active>=CAP then
  if not priority then return nil end
  table.remove(active,1):Stop()
 end
 options=type(options)=='table' and options or {}
 local color=typeof(options.Tint)=='Color3' and options.Tint or item and (item.Tint or item.Color) or Color3.fromRGB(255,210,89)
 if typeof(color)~='Color3' then color=Color3.fromRGB(135,218,255) end
 local life=kind=='Aura' and 1.65 or kind=='BombFX' and 1.25 or .34
 local width=math.clamp(tonumber(size) or 3,.5,kind=='Aura' and 4.2 or 3.6)
 local alpha=math.clamp(tonumber(opacity) or .15,.05,.8)
 local h={Objects={},End=now+life,At=now,Stopped=false,Kind=kind,Origin=origin,Where=where,Offset=offset,Follow=follow==true,Width=width,Alpha=alpha,Life=life}
 function h:Stop()
  if self.Stopped then return end;self.Stopped=true
  for _,p in ipairs(self.Objects) do p:Destroy() end;table.clear(self.Objects)
 end
 local count=kind=='Aura' and 6 or kind=='BombFX' and 4 or 5
 for i=1,count do
  local dims=kind=='Aura' and V(.12,.10,.36) or kind=='BombFX' and V(.13,.13,.13) or V(.14,.14,.5)
  h.Objects[i]=part('HAB_'..kind,dims,i%3==0 and WHITE or color,kind=='BombFX' and Enum.PartType.Ball or Enum.PartType.Block)
 end
 active[#active+1]=h
 return h
end
local connection=Run.Heartbeat:Connect(function()
 local now=os.clock();local hidden=off();local camera=workspace.CurrentCamera
 for i=#active,1,-1 do
  local h=active[i];local origin=h.Origin
  if h.Follow then origin=frame(h.Where,h.Offset) end
  if hidden or h.Stopped or not origin or now>=h.End or not camera or (camera.CFrame.Position-origin.Position).Magnitude>110 then
   h:Stop();table.remove(active,i)
  else
   local t=math.clamp((now-h.At)/h.Life,0,1)
   local fade=math.clamp(t/.12,0,1)*(1-math.clamp((t-.72)/.28,0,1))
   for index,p in ipairs(h.Objects) do
    local theta=index*math.pi*2/#h.Objects
    if h.Kind=='Aura' then
     theta+=t*.38
     local radius=h.Width*.34
     p.CFrame=origin*CF(math.cos(theta)*radius,-2.65,math.sin(theta)*radius)*CFrame.Angles(0,-theta,0)
     p.Transparency=1-(1-math.max(.32,h.Alpha))*fade
    elseif h.Kind=='BombFX' then
     theta+=t*2.1
     p.CFrame=origin*CF(math.cos(theta)*h.Width*.26,math.sin(theta*2)*.18+.15,math.sin(theta)*h.Width*.26)
     p.Transparency=1-(1-math.max(.18,h.Alpha))*fade
    else
     local radius=(.25+t)*h.Width*.45
     local direction=V(math.cos(theta),math.sin(theta)*.65,0)
     p.CFrame=origin*CF(direction*radius)*CFrame.Angles(0,0,theta)*CFrame.Angles(0,math.pi/2,0)
     p.Size=V(.10,.10,.2+(1-t)*.5)
     p.Transparency=1-(1-h.Alpha)*(1-t)
    end
   end
  end
 end
end)
function R.Destroy()
 if stopped then return end;stopped=true;connection:Disconnect()
 for _,h in ipairs(active) do h:Stop() end;table.clear(active);folder:Destroy()
end
script.Destroying:Connect(R.Destroy)
return R
