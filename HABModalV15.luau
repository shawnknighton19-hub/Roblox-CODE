--!strict
-- One local owner for screen menus and physical stand browsing.
-- The client exposes an attribute for movement/action input gates; grants no authority.
local Players=game:GetService('Players')
local player=Players.LocalPlayer
local owner:string?=nil
local closeOwner:(()->())?=nil
local Modal={}
function Modal.Current():string? return owner end
function Modal.Acquire(key:string,close:()->())
 assert(type(key)=='string' and #key>0 and type(close)=='function','Modal owner and closer required')
 if owner==key then closeOwner=close;return end
 local previous=closeOwner
 -- Transfer first: an old panel's Release must never release the new owner.
 owner=key;closeOwner=close
 if player then player:SetAttribute('HABModalOwnerV15',key) end
 if previous then
  local ok,why=pcall(previous)
  if not ok then warn('[HAB UI] Closing previous menu: '..tostring(why)) end
 end
end
function Modal.Release(key:string)
 if owner~=key then return end
 owner=nil;closeOwner=nil
 if player then player:SetAttribute('HABModalOwnerV15',nil) end
end
return Modal
