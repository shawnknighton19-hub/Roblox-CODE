--!nonstrict
-- A literal-only comparison. Never executes user-edited configuration source.
-- Allows only numeric IDs and GemSalesEnabled booleans in the supplied formatting.
local M={}
local passKeys={'FastOpen','Throw','VIP','Disco','Confetti','Phantom','Solar','Cyber','Glacier'}
local productKeys={'pouch','chest','vault'}
function M.Normalize(source)
 if type(source)~='string' then return nil,'Monetization source must be a string.' end
 local values={Passes={},Products={},Sales={}}
 for _,group in ipairs({{passKeys,values.Passes},{productKeys,values.Products}}) do
  local used={}
  for _,key in ipairs(group[1]) do
   local valid=true
   local count
   source,count=source:gsub('('..key..' = )(%d+)',function(prefix,literal)
    local value=tonumber(literal)
    if not value or value<0 or value>9007199254740991 or value%1~=0 then valid=false end
    if value and value>0 and used[value] then valid=false end
    if value and value>0 then used[value]=true end
    group[2][key]=value
    return prefix..'0'
   end)
   if count~=1 or not valid then return nil,'Invalid or duplicate '..key..' ID. Keep the supplied formatting and use a nonnegative integer.' end
  end
 end
 for _,key in ipairs(productKeys) do
  local valid=true
  local count
  source,count=source:gsub('('..key..' = )(%a+)',function(prefix,literal)
   if literal~='true' and literal~='false' then valid=false end
   values.Sales[key]=literal=='true'
   return prefix..'true'
  end)
  if count~=1 or not valid then return nil,'Invalid '..key..' sale switch. Use true or false in the supplied formatting.' end
 end
 return source,values
end
function M.Compatible(expected,current)
 local wanted,why=M.Normalize(expected)
 if not wanted then return false,'Bundled configuration is invalid: '..tostring(why) end
 local actual,values=M.Normalize(current)
 if not actual then return false,values end
 if wanted~=actual then return false,'Configuration contains changes beyond the supported ID and sale-switch literals. Preserve it and review manually.' end
 return true,values
end
return M
