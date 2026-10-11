-- HUSS A BOMB V10: CARTOON SKY AND LIGHTING
-- Run in Studio's Command Bar with Play stopped. Works independently of the HUD.
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'Stop Play before installing the sky.')
local lighting=game:GetService('Lighting')
local terrain=workspace:FindFirstChildOfClass('Terrain')
local storage=game:GetService('ServerStorage')
assert(terrain,'Workspace Terrain is missing. Nothing changed.')

local graphics=(function()
-- Sunny V10 environment. Six new sky faces from Roblox's documented skybox example.
local G={}
function G.Plan(lighting,terrain)
 assert(lighting and lighting:IsA('Lighting') and terrain and terrain:IsA('Terrain'),'Lighting or Terrain is missing. Nothing changed.')
 local rgb=Color3.fromRGB
 local properties={TimeOfDay='11:45:00',Brightness=2.8,ExposureCompensation=.08,GlobalShadows=true,ShadowSoftness=.35,GeographicLatitude=35,
  Ambient=rgb(96,116,151),OutdoorAmbient=rgb(148,172,199),ColorShift_Top=rgb(22,10,0),ColorShift_Bottom=rgb(0,0,0),EnvironmentDiffuseScale=.8,EnvironmentSpecularScale=.8}
 local plan={Properties=properties,OriginalProperties={},Old={},New={}}
 for key in pairs(properties) do plan.OriginalProperties[key]=lighting[key] end
 local names={HussSkyV10='Sky',HussAtmosphereV10='Atmosphere',HussBloomV10='BloomEffect',HussColorV10='ColorCorrectionEffect',HussSunV10='SunRaysEffect',HussCloudsV10='Clouds',HussSkyV9='Sky',HussAtmosphereV9='Atmosphere',HussBloomV9='BloomEffect',HussColorV9='ColorCorrectionEffect',HussSunV9='SunRaysEffect',HussCloudsV9='Clouds',HussBloomV8='BloomEffect',HussColorV8='ColorCorrectionEffect'}
 for _,parent in ipairs({lighting,terrain}) do for _,o in ipairs(parent:GetChildren()) do
  assert(not names[o.Name] or o:IsA(names[o.Name]),'Unexpected graphics object: '..o.Name..'. Nothing changed.')
  local known=names[o.Name] or (o.Name=='Bloom' and o:IsA('BloomEffect')) or (o.Name=='SunRays' and o:IsA('SunRaysEffect'))
  if (parent==lighting and (known or o:IsA('Sky') or o:IsA('Atmosphere'))) or (parent==terrain and o:IsA('Clouds')) then table.insert(plan.Old,o) end
 end end
 local function add(class,name,props,target) table.insert(plan.New,{Class=class,Name=name,Properties=props,Target=target or 'Lighting'}) end
 local sky={CelestialBodiesShown=true,SunAngularSize=10,MoonAngularSize=0,StarCount=0,SkyboxOrientation=Vector3.new(0,0,0),SunTextureId='rbxasset://sky/sun.jpg',MoonTextureId='rbxasset://sky/moon.jpg'}
 for face,id in pairs({Bk=162001887,Dn=161998893,Ft=162001897,Lf=162001904,Rt=162001919,Up=162001926}) do sky['Skybox'..face]='rbxassetid://'..id end
 add('Sky','HussSkyV10',sky)
 add('Atmosphere','HussAtmosphereV10',{Density=.18,Offset=.12,Color=rgb(178,216,255),Decay=rgb(115,145,192),Glare=.03,Haze=.35})
 add('Clouds','HussCloudsV10',{Enabled=true,Cover=.58,Density=.5,Color=rgb(255,250,241)},'Terrain')
 add('ColorCorrectionEffect','HussColorV10',{Enabled=true,Brightness=.015,Contrast=.12,Saturation=.23,TintColor=rgb(255,252,247)})
 add('BloomEffect','HussBloomV10',{Enabled=true,Intensity=.2,Size=22,Threshold=1.3})
 add('SunRaysEffect','HussSunV10',{Enabled=true,Intensity=.04,Spread=.8})
 return plan
end
return G

end)()

local plan=graphics.Plan(lighting,terrain)
local backup=Instance.new('Folder');backup.Name='CartoonSkyBackup_'..os.time()
while storage:FindFirstChild(backup.Name) do backup.Name..='_' end
local staging=Instance.new('Folder')
local oldLighting=Instance.new('Folder');oldLighting.Name='Lighting';oldLighting.Parent=backup
local oldTerrain=Instance.new('Folder');oldTerrain.Name='Terrain';oldTerrain.Parent=backup
local values=Instance.new('Folder');values.Name='LightingProperties';values.Parent=backup
local oldParents,newObjects={},{}
local function same(a,b)
 if typeof(a)~=typeof(b) then return false end
 if type(a)=='number' then return math.abs(a-b)<.0001 end
 if typeof(a)=='Color3' then return math.abs(a.R-b.R)+math.abs(a.G-b.G)+math.abs(a.B-b.B)<.0001 end
 if typeof(a)=='Vector3' then return (a-b).Magnitude<.0001 end
 return a==b
end
local ok,err=pcall(function()
 for key,value in pairs(plan.OriginalProperties) do values:SetAttribute(key,value) end
 for _,object in ipairs(plan.Old) do oldParents[object]=object.Parent end
 for _,spec in ipairs(plan.New) do
  assert(spec.Target=='Lighting' or spec.Target=='Terrain','Invalid graphics target.')
  local object=Instance.new(spec.Class);object.Parent=staging;object.Name=spec.Name
  table.insert(newObjects,{object=object,spec=spec})
  for key,value in pairs(spec.Properties) do object[key]=value end
 end
end)
if not ok then staging:Destroy();backup:Destroy();error('Sky preflight stopped; originals preserved: '..tostring(err)) end
ok,err=pcall(function()
 backup.Parent=storage
 for object,parent in pairs(oldParents) do object.Parent=parent==terrain and oldTerrain or oldLighting end
 for key,value in pairs(plan.Properties) do lighting[key]=value end
 for _,entry in ipairs(newObjects) do entry.object.Parent=entry.spec.Target=='Terrain' and terrain or lighting end
 -- Verify what Studio actually retained, including all six sky texture paths.
 for key,value in pairs(plan.Properties) do assert(same(lighting[key],value),'Lighting did not retain '..key) end
 for _,entry in ipairs(newObjects) do
  local object,spec=entry.object,entry.spec
  assert(object.Parent==(spec.Target=='Terrain' and terrain or lighting) and object.Name==spec.Name,'Missing '..spec.Name)
  for key,value in pairs(spec.Properties) do assert(same(object[key],value),spec.Name..' did not retain '..key) end
 end
end)
if not ok then
 local failures={}
 local function restore(fn) local worked,message=pcall(fn);if not worked then table.insert(failures,tostring(message)) end end
 for _,entry in ipairs(newObjects) do restore(function() entry.object:Destroy() end) end
 for key,value in pairs(plan.OriginalProperties) do restore(function() lighting[key]=value end) end
 for object,parent in pairs(oldParents) do restore(function() object.Parent=parent end) end
 for key,value in pairs(plan.OriginalProperties) do restore(function() assert(same(lighting[key],value),'Could not restore '..key) end) end
 for object,parent in pairs(oldParents) do restore(function() assert(object.Parent==parent,'Could not restore '..object.Name) end) end
 staging:Destroy()
 if #failures==0 then backup:Destroy();error('Sky installation rolled back: '..tostring(err)) end
 error('Sky installation stopped. Backup: ServerStorage/'..backup.Name..'. Restore errors: '..table.concat(failures,'; ')..'. Original error: '..tostring(err))
end
staging:Destroy()
print('CARTOON SKY V10 INSTALLED - SETTINGS VERIFIED')
for _,entry in ipairs(newObjects) do print(entry.object:GetFullName()) end
print('Lighting: '..lighting.TimeOfDay..', Brightness '..lighting.Brightness..', Exposure '..lighting.ExposureCompensation)
print('Backup: ServerStorage/'..backup.Name..'. Save the place. Look at the sky in Edit mode, then test Play.')
