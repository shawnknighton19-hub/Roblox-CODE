--!nonstrict
-- HAB_COLLECTIONS_5 | Pure, server-side crate inventory rules. No network/data-store calls.
local R={}
local slots={Aura=true,Trail=true,BombFX=true,KillFX=true,DodgeFX=true}
local modes={Random=true,Guaranteed=true}
local kinds={Buy=true,Open=true,Refund=true}
local MAX=2000000000
R.MaxStored=250
R.MaxReceipts=4096
local function integer(n,max)
 return type(n)=='number' and n==n and n>=0 and n%1==0 and n<=(max or MAX)
end
function R.Token(s)
 return type(s)=='string' and #s>=12 and #s<=64 and s:match('^[%w%-]+$')~=nil
end
function R.Fresh() return {v=1,Stored={},Receipts={}} end
function R.Valid(v)
 if v==nil then return true end -- An older profile is migrated, not reset.
 if type(v)~='table' or v.v~=1 or type(v.Stored)~='table' or type(v.Receipts)~='table' then return false end
 local n=0
 for id,c in pairs(v.Stored) do
  n=n+1
  if n>R.MaxStored or not R.Token(id) or type(c)~='table' or not slots[c.Category]
   or not modes[c.Mode] or not integer(c.Cost) or c.Cost<1 or not integer(c.At)
   or (c.Mode=='Guaranteed' and (type(c.Choice)~='string' or #c.Choice<1 or #c.Choice>64))
   or (c.Mode=='Random' and c.Choice~=nil) then return false end
 end
 n=0
 for id,t in pairs(v.Receipts) do
  n=n+1
  if n>R.MaxReceipts or not R.Token(id) or type(t)~='table' or not kinds[t.Kind]
   or not R.Token(t.Crate) or not slots[t.Category] or not integer(t.Cost) or not integer(t.At)
   or (t.Kind=='Open' and (type(t.Item)~='string' or #t.Item<1 or #t.Item>64)) then return false end
 end
 if v.LastOpen~=nil and (not R.Token(v.LastOpen) or not v.Receipts[v.LastOpen] or v.Receipts[v.LastOpen].Kind~='Open') then return false end
 return true
end
function R.Pool(data,catalog,category)
 local crate=catalog.Crates[category]
 if not crate then return {},0,{} end
 local owned=data.HABHalloween.Owned
 local reserved={};local randomCount=0
 for _,stored in pairs(data.HABCrateInventory.Stored) do
  if stored.Category==category then
   if stored.Mode=='Guaranteed' then reserved[stored.Choice]=true else randomCount=randomCount+1 end
  end
 end
 local pool={}
 for _,id in ipairs(crate.Items) do
  if not owned[id] and not reserved[id] then pool[#pool+1]=id end
 end
 return pool,randomCount,reserved
end
function R.PlanBuy(data,catalog,category,choice,randomAllowed)
 local crate=type(category)=='string' and catalog.Crates[category]
 if not crate or not integer(crate.Price) or crate.Price<1 then return nil,'Unknown crate or invalid price.' end
 local total=0;for _ in pairs(data.HABCrateInventory.Stored) do total=total+1 end
 if total>=R.MaxStored then return nil,'Your crate inventory is full. Open or refund a stored crate first.' end
 local pool,randomCount=R.Pool(data,catalog,category)
 if #pool<=randomCount then return nil,'You already own or have stored enough crates to finish this collection.' end
 local mode,cost='Random',crate.Price
 if choice~=nil then
  local found=false
  if type(choice)=='string' then for _,id in ipairs(pool) do if id==choice then found=true;break end end end
  if not found then return nil,'Select an unowned, unreserved effect for a guaranteed crate.' end
  mode='Guaranteed';cost=math.ceil(crate.Price*(#pool+1)/2)
 elseif randomAllowed~=true then
  return nil,'Random crates are unavailable for this account. Choose a guaranteed effect.'
 end
 if data.Gems<cost then return nil,'Not enough Gems. Claim quests or visit the Gems shop.' end
 return {Category=category,Mode=mode,Choice=choice,Cost=cost,Pool=#pool}
end
function R.Snapshot(data,catalog)
 local inv=data.HABCrateInventory
 local list,counts,pools={},{},{}
 for _,category in ipairs(catalog.Order) do counts[category]=0 end
 for id,c in pairs(inv.Stored) do
  list[#list+1]={Id=id,Category=c.Category,Mode=c.Mode,Choice=c.Choice,Cost=c.Cost,At=c.At}
  counts[c.Category]=(counts[c.Category] or 0)+1
 end
 table.sort(list,function(a,b) if a.At==b.At then return a.Id<b.Id end;return a.At<b.At end)
 for _,category in ipairs(catalog.Order) do
  local ids,random,reserved=R.Pool(data,catalog,category)
  pools[category]={Items=ids,RandomStored=random,Reserved=reserved,CanBuy=#ids>random}
 end
 return list,counts,pools
end
return R

