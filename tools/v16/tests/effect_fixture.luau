services.RunService.IsClient=function() return true end
services.RunService.RenderStepped=signal()
services.UserInputService={TouchEnabled=false}
services.ContentProvider={PreloadAsync=function(_,assets,fn) for _,asset in ipairs(assets) do fn(asset,Enum.AssetFetchStatus.Success) end end}
services.StarterGui={SetCoreGuiEnabled=function() end}
Vector2.zero=Vector2.new(0,0)
function Color3:ToHSV() return .3,.5,1 end
function Color3.fromHSV() return Color3.new(.5,1,.6) end
local Random={new=function() return {} end}
Enum.ParticleFlipbookLayout.GetEnumItems=function() return {{Value=0,Name='None'},{Value=1,Name='Grid4x4'}} end
local pack=Instance.new('Folder',services.ReplicatedStorage);pack.Name='HABHalloween'
local expansion=Instance.new('Folder',services.ReplicatedStorage);expansion.Name='HABExpansion'
local fx=Instance.new('RemoteEvent',expansion);fx.Name='FX';fx.OnClientEvent=signal()
local modules={}
for _,name in ipairs({'Catalog','Settings','Effects','NativeFX','ExtraFXData','HABEffectNames','HABKillSounds','HABKillSoundPlayer','Renderer'}) do
 modules[name]=Instance.new('ModuleScript',pack);modules[name].Name=name
end
local configModule=Instance.new('ModuleScript',expansion);configModule.Name='Config'
script.Parent=pack
local config,effects,settings,names,sounds,catalog
local extra={Templates={},Properties={}}
local calls={}
local native={Has=function(id) return extra.Templates[id]~=nil end,Preload=function() end,Status=function() return 'ready' end}
native.Play=function(id,where,size,offset,follow,opacity,priority)
 local handle={End=clock+.7,Stopped=false,Stop=function(self) self.Stopped=true end}
 calls[#calls+1]={id=id,where=where,size=size,handle=handle}
 return handle
end
local soundPreview={Mount=function(parent,id) local h={};h.Stop=function() end;return h end}
local abilityCalls={}
local abilityRenderer={Play=function(...)
 local args={...};abilityCalls[#abilityCalls+1]=args
 return {Stopped=false,Stop=function(self) self.Stopped=true end}
end}
local require=function(object)
 if object==configModule then return config end
 if object==modules.Catalog then return catalog end
 if object==modules.Settings then return settings end
 if object==modules.Effects then return effects end
 if object==modules.NativeFX then return native end
 if object==modules.ExtraFXData then return extra end
 if object==modules.HABEffectNames then return names end
 if object==modules.HABKillSounds then return sounds end
 if object==modules.HABKillSoundPlayer then return soundPreview end
 if object==modules.Renderer then return abilityRenderer end
 error('Unexpected require '..tostring(object and object.Name))
end
local checks=0
local function check(ok,message) checks+=1;assert(ok,message or tostring(checks)) end
local savedState={Owned={},Equipped={},StoredCrates={},Pools={},Ready=true,HasInventory=true}
