--!nonstrict
-- HAB_COLLECTIONS_6. Read-only UI projection of SERVER snapshots. Never grants ownership.
local M={}
local MAX=2000000000
local function finite(n) return type(n)=='number' and n==n and n>-math.huge and n<math.huge end
local function amount(n) return finite(n) and math.clamp(math.floor(n),0,MAX) or 0 end
local function copy(t)
 local o={};if type(t)=='table' then for k,v in pairs(t) do o[k]=v end end;return o
end
function M.Empty()
 return {Ready=false,CanOpen=false,Gems=0,Coins=0,Owned={},Equipped={},StoredCrates={},StoredCounts={},Pools={},Products={},Quests={},Revision=0,RandomAllowed=false,HasInventory=false}
end
function M.Owned(values)
 local out={}
 if type(values)~='table' then return out end
 local count=0
 for k,v in pairs(values) do
  count=count+1;if count>4096 then break end
  if type(k)=='string' and v==true then out[k]=true
  elseif type(k)=='number' then
   local id=type(v)=='string' and v or type(v)=='table' and (v.Id or v.id)
   if type(id)=='string' and #id<=128 then out[id]=true end
  end
 end
 return out
end
function M.Accept(previous,snapshot)
 if type(snapshot)~='table' then return previous,false end
 -- A late request must not erase a newer ownership/equipment snapshot.
 if finite(snapshot.Revision) and finite(previous.Revision) and snapshot.Revision<previous.Revision and previous.HasInventory then
  return previous,false
 end
 local out=copy(previous)
 for _,key in ipairs({'Ready','CanOpen','RandomAllowed','PolicyMessage','SaveStatus','ApiVersion','InventoryVersion','ServerState','ServerIssue','LastOpening','Products','Quests','ResetsAt'}) do
  if snapshot[key]~=nil then out[key]=snapshot[key] end
 end
 out.Ready=snapshot.Ready==true
 out.RandomAllowed=snapshot.RandomAllowed==true
 if snapshot.Gems~=nil then out.Gems=amount(snapshot.Gems) end
 if snapshot.Coins~=nil then out.Coins=amount(snapshot.Coins) end
 if finite(snapshot.Revision) then out.Revision=amount(snapshot.Revision) end
 -- Do not replace a previously received inventory with absent fields on a loading response.
 if type(snapshot.Owned)=='table' and (snapshot.Ready==true or not previous.HasInventory or next(snapshot.Owned)~=nil) then out.Owned=M.Owned(snapshot.Owned);out.HasInventory=true end
 if type(snapshot.Equipped)=='table' then out.Equipped=copy(snapshot.Equipped) end
 if type(snapshot.Pools)=='table' then out.Pools=snapshot.Pools end
 if type(snapshot.StoredCrates)=='table' and (snapshot.Ready==true or not previous.HasInventory or next(snapshot.StoredCrates)~=nil) then
  out.StoredCrates={};out.StoredCounts={}
  local count=0
  for k,v in pairs(snapshot.StoredCrates) do
   count=count+1;if count>500 then break end
   if type(v)=='table' and type(v.Category)=='string' then
    local id=v.Id or (type(k)=='string' and k)
    if type(id)=='string' then
     local c=copy(v);c.Id=id;c.Cost=amount(c.Cost);c.At=amount(c.At)
     out.StoredCrates[#out.StoredCrates+1]=c
     out.StoredCounts[c.Category]=(out.StoredCounts[c.Category] or 0)+1
    end
   end
  end
  table.sort(out.StoredCrates,function(a,b) if a.At==b.At then return a.Id<b.Id end;return a.At<b.At end)
 end
 out.Products=type(out.Products)=='table' and out.Products or {}
 out.Quests=type(out.Quests)=='table' and out.Quests or {}
 return out,true
end
function M.Pool(state,category)
 local p=state.Pools[category]
 if type(p)~='table' then return {Items={},Reserved={},RandomStored=0,CanBuy=false} end
 return {Items=type(p.Items)=='table' and p.Items or {},Reserved=type(p.Reserved)=='table' and p.Reserved or {},RandomStored=amount(p.RandomStored),CanBuy=p.CanBuy==true}
end
function M.Contains(list,id)
 for _,v in ipairs(list) do if v==id then return true end end;return false
end
function M.Odds(count)
 if count<1 then return 'No available rewards.' end
 return string.format('Available rewards: %.6f%% each (1/%d).',100/count,count)
end
function M.Count(state)
 local catalog=require(script.Parent.Catalog)
 local effects=0;for id,owned in pairs(state.Owned) do if owned==true and not(catalog.ById[id] and catalog.ById[id].RetiredFinisher) and not(catalog.ById[id] and catalog.DisabledVisualCategories and catalog.DisabledVisualCategories[catalog.ById[id].Category]) then effects=effects+1 end end
 return #state.StoredCrates,effects
end
function M.Inventory(catalog,state,filter,query)
 filter=filter or 'All';query=tostring(query or ''):lower()
 local rows,groups={},{}
 local rank={};for i,cat in ipairs(catalog.Order) do rank[cat]=i end
 local function matches(name,cat,kind,oldName)
  if filter~='All' and filter~='Effects' and filter~='Crates' and filter~=cat then return false end
  if filter=='Crates' and kind~='Crate' then return false end
  if filter=='Effects' and kind~='Effect' then return false end
  return query=='' or (name..' '..cat..' '..tostring(oldName or '')):lower():find(query,1,true)~=nil
 end
 for _,c in ipairs(state.StoredCrates) do
  local crate=catalog.Crates[c.Category]
  local retired=catalog.DisabledVisualCategories and catalog.DisabledVisualCategories[c.Category]==true
  local name=(crate and crate.Name or 'Stored crate')..(retired and ' • REFUND ONLY' or '')
  local key=c.Category..'|'..tostring(c.Mode)..'|'..tostring(c.Choice or '')..'|'..tostring(c.Cost)
  if matches(name,c.Category,'Crate') then
   local g=groups[key]
   if not g then
    g={Kind='Crate',Key=key,Name=name,Category=c.Category,Count=0,Crate=c,Color=crate and crate.Color,RefundOnly=retired}
    groups[key]=g;rows[#rows+1]=g
   end
   g.Count=g.Count+1
  end
 end
 for id,owned in pairs(state.Owned) do
  if owned==true then
   local item=catalog.ById[id]
   local name=item and item.Name or 'Legacy effect'
   local cat=item and item.Category or 'Unknown'
   if not(catalog.DisabledVisualCategories and catalog.DisabledVisualCategories[cat]) and not(item and item.RetiredFinisher) and matches(name,cat,'Effect',item and item.SourceName or id) then
    rows[#rows+1]={Kind='Effect',Key=id,Id=id,Name=name,Category=cat,Item=item,Missing=item==nil,Color=item and item.Color,Equipped=state.Equipped[cat]==id}
   end
  end
 end
 table.sort(rows,function(a,b)
  if a.Kind~=b.Kind then return a.Kind=='Crate' end
  if a.Kind=='Crate' and (rank[a.Category] or 99)~=(rank[b.Category] or 99) then return (rank[a.Category] or 99)<(rank[b.Category] or 99) end
  if a.Kind=='Effect' and a.Equipped~=b.Equipped then return a.Equipped==true end
  if a.Name~=b.Name then return a.Name<b.Name end
  return a.Key<b.Key
 end)
 return rows
end
return M


-- HAB_FUN_9
