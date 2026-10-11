-- HUSS A BOMB V12 COMPATIBILITY INSTALLER
-- Paste the entire script into Roblox Studio's Command Bar with Play stopped.
-- Local, source-verified migration. No HTTP, asset loader or gameplay module execution.
local run=game:GetService('RunService')
assert(run:IsStudio() and not run:IsRunning(),'V12: Stop Play before installing. Nothing changed.')
local storage=game:GetService('ServerStorage')
local replicated=game:GetService('ReplicatedStorage')
local server=game:GetService('ServerScriptService')
local starterRoot=game:GetService('StarterPlayer')
local issues,notes={},{}
local function problem(message) table.insert(issues,tostring(message)) end
local function note(message) table.insert(notes,tostring(message)) end
local function path(object) return object and object:GetFullName() or '(missing)' end
local function canonical(source) return source:gsub('\r\n','\n'):match('^%s*(.-)%s*$') end
local function fingerprint(source)
 source=canonical(source);local a,b=1,0
 for i=1,#source do a=(a+source:byte(i))%65521;b=(b+a)%65521 end
 return #source,b*65536+a
end
local function unique(parent,name,class,recursive,optional)
 local found={}
 if parent then for _,object in ipairs(recursive and parent:GetDescendants() or parent:GetChildren()) do
  if object.Name==name then table.insert(found,object) end
 end end
 if #found==0 then if not optional then problem(path(parent)..'/'..name..' is missing; expected '..class..'.') end;return nil end
 if #found~=1 then
  local locations={};for _,object in ipairs(found) do table.insert(locations,path(object)..' ('..object.ClassName..')') end
  problem('Ambiguous '..name..': '..table.concat(locations,', ')..'. Keep one active owner; nothing will be guessed.');return nil
 end
 local object=found[1]
 if not object:IsA(class) then problem(path(object)..' is '..object.ClassName..'; expected '..class..'.');return nil end
 return object
end
local function stopPreflight()
 if #issues>0 then error('V12 compatibility preflight stopped. Originals preserved.\n- '..table.concat(issues,'\n- '),0) end
end
local function attempt(label,fn)
 local ok,result=pcall(fn)
 if not ok then problem(label..': '..tostring(result));return nil end
 return result
end
