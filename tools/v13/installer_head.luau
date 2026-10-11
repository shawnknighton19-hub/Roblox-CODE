-- HUSS A BOMB V13 — MOVEMENT ANIMATION REPAIR + 25 TRAIL DESIGNS
-- Paste the ENTIRE script into Studio's Command Bar with Play stopped.
-- Requires the verified V12 installation. No network downloads or gameplay modules run here.
-- IMPORTANT: File > Avatar Settings > ... menu > R6 must be saved separately, then publish.
-- Roblox does not expose the experience's rig setting as StarterPlayer.CharacterRigType.
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'V13: Stop Play before installing. Nothing changed.')
local storage=game:GetService('ServerStorage')
local replicated=game:GetService('ReplicatedStorage')
local server=game:GetService('ServerScriptService')
local starterRoot=game:GetService('StarterPlayer')
local issues,notes={},{ }
local function problem(message) table.insert(issues,tostring(message)) end
local function note(message) table.insert(notes,tostring(message)) end
local function path(object) return object and object:GetFullName() or '(missing)' end
local function canonical(source) return source:gsub('\r\n','\n'):match('^%s*(.-)%s*$') end
local function unique(parent,name,class,recursive,optional)
 local found={}
 if parent then for _,object in ipairs(recursive and parent:GetDescendants() or parent:GetChildren()) do
  if object.Name==name then table.insert(found,object) end
 end end
 if #found==0 then if not optional then problem(path(parent)..'.'..name..' is missing; expected '..class..'.') end;return nil end
 if #found~=1 then
  local locations={};for _,object in ipairs(found) do table.insert(locations,path(object)..' ('..object.ClassName..')') end
  problem('Ambiguous '..name..': '..table.concat(locations,', ')..'. No duplicate system will be added.');return nil
 end
 local object=found[1]
 if not object:IsA(class) then problem(path(object)..' is '..object.ClassName..'; expected '..class..'.');return nil end
 return object
end
local function stopPreflight()
 if #issues>0 then error('V13 compatibility preflight stopped. Originals preserved.\n- '..table.concat(issues,'\n- '),0) end
end
local function attempt(label,fn)
 local ok,result=pcall(fn)
 if not ok then problem(label..': '..tostring(result));return nil end
 return result
end
local function r6Reminder()
 warn('[V13 REQUIRED PUBLISH STEP] In Studio open File > Avatar Settings > the ... menu > R6, save the setting, then Publish to Roblox. Join a NEW server. This installer cannot change Roblox experience rig settings.')
end
