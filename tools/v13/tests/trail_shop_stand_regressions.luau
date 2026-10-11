local function inspectTrailPreview(viewport,id)
 check(viewport and viewport:IsA('ViewportFrame'),'real ViewportFrame for '..id)
 if not viewport then return end
 local world=viewport:FindFirstChildOfClass('WorldModel')
 local model=world and world:FindFirstChildOfClass('Model')
 check(model~=nil,'actual shared trail sculpture for '..id)
 if not model then return end
 check(model:GetAttribute('HussTrailId')==id and model:GetAttribute('Preview')==true,'preview shows the selected trail identity '..id)
 local cam=viewport.CurrentCamera
 local vertical=math.tan(math.rad(cam.FieldOfView)*.5)
 local horizontal=vertical*viewport.Size.X.Offset/viewport.Size.Y.Offset
 local count,hasDetail,fits,safe=0,false,true,true
 for _,part in ipairs(model:GetDescendants()) do
  if part:IsA('BasePart') then
   count+=1
   if part.Name~='Part' then hasDetail=true end
   safe=safe and part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery
   for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
    local point=part.CFrame:PointToWorldSpace(Vector3.new(part.Size.X*x,part.Size.Y*y,part.Size.Z*z)*.5)
    local cameraPoint=cam.CFrame:PointToObjectSpace(point)
    local depth=-cameraPoint.Z
    fits=fits and depth>0 and math.abs(cameraPoint.X)/depth<horizontal*.99 and math.abs(cameraPoint.Y)/depth<vertical*.99
   end end end
  else
   safe=safe and not part:IsA('ParticleEmitter') and not part:IsA('Beam') and not part:IsA('Trail')
  end
 end
 check(count>3 and count<=TrailDesigns.MaxParts and hasDetail,'bounded sculpted trail detail for '..id)
 check(safe,'static nonphysical trail preview without emitters for '..id)
 check(fits,'all geometry corners fit trail preview camera for '..id)
 return model
end
local standTrailCount=0
move('Trails',8)
local renderConnections=RunService.RenderStepped:Count()
local oldPreview
for page=1,5 do
 for _,item in ipairs(productionCatalog.Items) do if item.category=='Trails' then
  local choice=node('Select_'..item.id)
  if choice then
   choice.Activated:Fire()
   if oldPreview then check(oldPreview._destroyed,'previous stand preview destroyed on selection') end
   local viewport=node('SelectedTrailPreview')
   oldPreview=inspectTrailPreview(viewport,item.id)
   local previewCount=0
   for _,v in ipairs(shop():GetDescendants()) do if v:IsA('ViewportFrame') then previewCount+=1 end end
   check(previewCount==1,'single preview per physical shop selection')
   standTrailCount+=1
  end
 end end
 if page<5 then node('Next').Activated:Fire() end
end
check(standTrailCount==25,'all 25 trails selectable and sculpted at physical stand')
check(RunService.RenderStepped:Count()==renderConnections,'stand trail previews add no per-frame subscriptions')
player:SetAttribute('HussReducedMotion',true)
local stablePart=oldPreview:FindFirstChildWhichIsA('BasePart',true)
local stableCF=stablePart and stablePart.CFrame
tickFrame(.2)
check(stablePart and stablePart.CFrame==stableCF,'trail preview remains fixed with reduced motion')
move('Trails',16)
check(oldPreview._destroyed,'walking away destroys trail preview')
player:SetAttribute('HussReducedMotion',false)
