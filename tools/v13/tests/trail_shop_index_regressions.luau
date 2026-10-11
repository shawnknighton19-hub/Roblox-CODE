node('Category_Trails',hud).Activated:Fire()
local indexTrailCount=0
local indexRenderConnections=RunService.RenderStepped:Count()
local previousModels={}
for page=1,5 do
 for _,model in ipairs(previousModels) do check(model._destroyed,'previous Index page destroys its preview model') end
 previousModels={}
 local pageCount=0
 for _,item in ipairs(productionCatalog.Items) do if item.category=='Trails' then
  local card=node('Collectible_'..item.id,hud)
  if card then
   local model=inspectTrailPreview(card:FindFirstChild('TrailPreview'),item.id)
   if model then table.insert(previousModels,model) end
   pageCount+=1;indexTrailCount+=1
  end
 end end
 check(pageCount>0 and pageCount<=6,'Index page has at most six trail previews')
 if page<5 then node('CollectionNext',hud).Activated:Fire() end
end
check(indexTrailCount==25,'all 25 trails appear as actual geometry in Index')
check(RunService.RenderStepped:Count()==indexRenderConnections,'Index trail previews add no per-frame subscriptions')
local locked=node('Item_trail_celebrate',hud)
check(locked and locked:GetAttribute('HussDisabled'),'last locked trail remains equip-only in Index')
node('Category_Bombs',hud).Activated:Fire()
for _,model in ipairs(previousModels) do check(model._destroyed,'changing category destroys Index trail preview') end
check(not hud:FindFirstChild('TrailPreview',true),'no trail preview remains after changing category')
