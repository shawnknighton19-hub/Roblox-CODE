--!nonstrict
-- Pure additive migration. Old ledgers/owned IDs remain; retired items leave the storefront.
local M={}
local MAX=2000000000
local function int(x) return type(x)=='number' and x==x and x>=0 and x%1==0 and x<=MAX end
function M.Valid(d)
 if d==nil then return true end
 if type(d)~='table' or d.Version~=1 or type(d.Ability)~='string' or #d.Ability>32 or type(d.Bundles)~='table' then return false end
 for _,field in ipairs({'Bundles','Abilities'}) do
  if d[field]~=nil then
   if type(d[field])~='table' then return false end
   local n=0;for k,v in pairs(d[field]) do n+=1;if n>64 or type(k)~='string' or #k>32 or type(v)~='boolean' then return false end end
  end
 end
 return true
end
-- Archive values are validated before a loaded profile can be migrated or saved.
function M.ValidArchive(a)
 if a==nil then return true end
 if type(a)~='table' or a.Version~=9 then return false end
 local ceiling=MAX*1000
 for _,key in ipairs({'RefundGems','PendingGems'}) do
  local v=a[key]
  if type(v)~='number' or v~=v or v<0 or v%1~=0 or v>ceiling then return false end
 end
 for _,key in ipairs({'Emotes','Finishers'}) do
  if type(a[key])~='table' then return false end
  local count=0
  for id,owned in pairs(a[key]) do
   count=count+1
   if count>1000 or type(id)~='string' or #id>64 or type(owned)~='boolean' then return false end
  end
 end
 if type(a.RefundedCrates)~='table' then return false end
 local count=0
 for token,crate in pairs(a.RefundedCrates) do
  count=count+1
  if count>1000 or type(token)~='string' or #token>64 or type(crate)~='table' or crate.Category~='KillFX' or not int(crate.Cost) then return false end
 end
 return a.PendingGems<=a.RefundGems
end
function M.Apply(d,catalog,oldCatalog,config)
 local x=d.HABExpansion;x.Abilities=x.Abilities or {}
 for _,a in ipairs(config.Abilities) do if a.Currency=='Free' then x.Abilities[a.Key]=true end end
 if d.HABRetirement9 then
  local debt=d.HABRetirement9.PendingGems or 0
  if type(debt)=='number' and debt==debt and debt>0 and debt<=MAX*1000 then local grant=math.min(debt,MAX-d.Gems);d.Gems+=grant;d.HABRetirement9.PendingGems=debt-grant end
  return d
 end
 local h=d.HABHalloween
 local archive={Version=9,Emotes={},Finishers={},RefundedCrates={},RefundGems=0,PendingGems=0}
 d.HABRetirement9=archive
 local hadFinisher=false
 for id,owned in pairs(h.Owned) do
  local item=catalog.ById[id]
  if owned and item and item.RetiredFinisher then hadFinisher=true;archive.Finishers[id]=true end
 end
 -- Compensation: the whole starter sound set for anyone who owned a retired finisher.
 if hadFinisher then for _,id in ipairs(catalog.Crates.KillFX.Items) do h.Owned[id]=true end end
 local selected=h.Equipped.KillFX
 if selected and catalog.ById[selected] and catalog.ById[selected].RetiredFinisher then h.Equipped.KillFX=hadFinisher and 'ks_pop' or '' end
 if h.Last and catalog.ById[h.Last] and catalog.ById[h.Last].RetiredFinisher then h.Last=nil end
 local refund=0
 for id,stored in pairs(d.HABCrateInventory.Stored) do
  if stored.Category=='KillFX' then
   archive.RefundedCrates[id]=stored
   refund+=stored.Cost
   d.HABCrateInventory.Stored[id]=nil
  end
 end
 archive.RefundGems=refund
 local grant=math.min(refund,MAX-d.Gems);d.Gems+=grant;archive.PendingGems=refund-grant
 for id,owned in pairs(d.Owned) do
  local item=oldCatalog.ById[id]
  if owned and item and item.category=='Emotes' then archive.Emotes[id]=true end
 end
 -- No emote coin refund is inferred: old inventory doesn't record purchase vs free owner grants.
 -- Their original ownership and receipts are retained, not erased.
 return d
end
function M.Ability(config,key)
 for _,a in ipairs(config.Abilities) do if a.Key==key then return a end end
end
function M.CanUse(data,def)
 return def and (def.Currency=='Free' or (data.HABExpansion.Abilities and data.HABExpansion.Abilities[def.Key]==true)) or false
end
function M.PlanBuy(data,def)
 if not def then return nil,'Unknown ability.' end
 if M.CanUse(data,def) then return nil,'Already unlocked.' end
 if def.Currency~='Coins' and def.Currency~='Gems' then return nil,'This ability requires its Roblox pass.' end
 if not int(def.Cost) or def.Cost<1 then return nil,'Invalid price; no charge.' end
 if not int(data[def.Currency]) or data[def.Currency]<def.Cost then return nil,'Not enough '..def.Currency..'.' end
 return {Currency=def.Currency,Cost=def.Cost,Key=def.Key}
end
return M
