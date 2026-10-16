local root=owner.Character.HumanoidRootPart
local P=owner
local active,dismissed,page,chosen,message,messageOk
local profile,busy,remote
local renderCalls=0
local updateApproach
local locker=Instance.new('Part');locker.CFrame=CFrame.new(0,3,0)
locker:SetAttribute('HussShopCategory','Emotes')
root.CFrame=CFrame.new(0,3,0)
owner:SetAttribute('HABCollectionRequest',nil)
local CollectionService={GetTagged=function() return {locker} end}
local function playerRoot() return root end
local function details(anchor) return anchor:GetAttribute('HussShopCategory') end
local function isNear(anchor,distance) return (root.Position-anchor.Position).Magnitude<=distance end
local function close() active=nil end
local function render() renderCalls+=1 end
local function unlockCursor() end
local function request() end
