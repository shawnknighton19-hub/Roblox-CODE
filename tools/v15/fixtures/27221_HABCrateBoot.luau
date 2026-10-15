
--!nonstrict
-- HAB_CRATE_GUI_4 | Explicit startup state, not silent failure.
local RS=game:GetService('ReplicatedStorage')
local pack=RS:WaitForChild('HABHalloween',20)
if not pack then warn('[HAB BOOT] HABHalloween is missing');return end
pack:SetAttribute('HABServerState','STARTING')
local ok,err=xpcall(function()
 local services=assert(script.Parent:WaitForChild('Services',15),'Services missing')
 local module=assert(services:WaitForChild('HABCrateService',15),'HABCrateService missing')
 require(module).Init()
end,debug.traceback)
if not ok then
 pack:SetAttribute('HABServerState','ERROR')
 pack:SetAttribute('HABServerIssue',tostring(err):sub(1,1500))
 warn('[HAB BOOT] '..tostring(err))
end

