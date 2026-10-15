-- HUSS A BOMB V15 | COMPLETE POLISH FOR THE UPLOADED HABWAS PLACE
-- Paste ALL of this script into Studio's Command Bar with Play stopped.
-- Offline install: exact-source compatibility checks, inert compilation, backups and rollback.
-- Your existing maps, saved profiles, voting, AFK and no-jump movement are preserved.
local Run=game:GetService('RunService')
assert(Run:IsStudio() and not Run:IsRunning(),'V15: Stop Play and run this in Roblox Studio. Nothing changed.')
local Storage=game:GetService('ServerStorage')
local Replicated=game:GetService('ReplicatedStorage')
local Server=game:GetService('ServerScriptService')
local issues={}
local function problem(message) issues[#issues+1]=tostring(message) end
local function canonical(text) return text:gsub('\r\n','\n'):match('^%s*(.-)%s*$') end
local function stop()
 if #issues>0 then error('V15 compatibility checks stopped; existing game preserved.\n- '..table.concat(issues,'\n- '),0) end
end
local function full(o) return o and o:GetFullName() or '(missing)' end
local function find(path,optional)
 local parts=string.split(path,'/');local current=game:GetService(parts[1])
 for i=2,#parts do
  local matches={}
  for _,o in ipairs(current:GetChildren()) do if o.Name==parts[i] then matches[#matches+1]=o end end
  if #matches~=1 then
   if #matches>1 or not optional then problem(path..': '..(#matches==0 and 'missing '..parts[i] or 'duplicate '..parts[i])) end
   return nil
  end
  current=matches[1]
 end
 return current
end
local function try(label,fn)
 local ok,result=pcall(fn);if not ok then problem(label..': '..tostring(result));return nil end;return result
end
