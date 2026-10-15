--!nonstrict
-- HAB EXPANSION 7. The server verifies game-pass entitlements; Gems retain ONE receipt handler.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Market=game:GetService('MarketplaceService')
local X=RS:WaitForChild('HABExpansion')
local Config=require(X.Config)
local Economy=require(script.Parent.EconomyServiceV9)
local S={};local started=false;local states={};local nextAt={};local offers={}
for _,v in ipairs(Config.Passes) do offers[v.Key]={Definition=v,Kind='Pass'} end
for _,v in ipairs(Config.Bundles) do offers[v.Key]={Definition=v,Kind='Bundle'} end
local function idValid(n) return type(n)=='number' and n==n and n>0 and n%1==0 and n<=9007199254740991 end
function S.Has(p,key)
 local s=states[p];return s and s.Owned[key]==true or false
end
local function deliver(p,key)
 for _,a in ipairs(Config.Abilities) do if a.PassKey==key and a.Currency=='Robux' then return Economy.HABGrantAbilityPass(p,a.Key) end end
 if key=='VIP' then return Economy.HABGrantVIP(p) end
 local offer=offers[key]
 if offer and offer.Kind=='Bundle' then return Economy.HABGrantBundle(p,key) end
 return true
end
local function refresh(p)
 local s=states[p]
 if not s or s.Busy then return end
 s.Busy=true
 for key,offer in pairs(offers) do
  if not p.Parent or states[p]~=s then break end
  local id=offer.Definition.Id
  if idValid(id) then
   local ok,owned=pcall(Market.UserOwnsGamePassAsync,Market,p.UserId,id)
   if ok and owned then s.Owned[key]=true end
   -- On a network failure retain a previously verified entitlement for this server.
   if s.Owned[key] then
    p:SetAttribute('HABPass'..key,true)
    local granted,why=deliver(p,key)
    if not granted then s.Pending=true end
   end
  end
 end
 s.Busy=false;s.Checked=true;p:SetAttribute('HABPassesChecked',true)
end
local function snapshot(p)
 local profile=Economy.HABExpansionProfile(p)
 local s=states[p]
 profile.Passes={}
 for key in pairs(offers) do profile.Passes[key]=s and s.Owned[key]==true or false end
 profile.Checked=s and s.Checked or false
 return profile
end
function S.Init()
 if started then return end;started=true
 local ids={}
 for key,offer in pairs(offers) do
  local id=offer.Definition.Id
  assert(type(id)=='number' and id>=0 and id%1==0,'Invalid pass ID for '..key)
  if id>0 then assert(not ids[id],'A pass ID is assigned to multiple offers');ids[id]=key end
 end
 local function add(p)
  states[p]={Owned={},Checked=false,Busy=false}
  p:GetAttributeChangedSignal('HussEconomyReady'):Connect(function()
   if p:GetAttribute('HussEconomyReady') then
    local s=states[p];if s then for key in pairs(s.Owned) do deliver(p,key) end end
   end
  end)
  task.spawn(refresh,p)
 end
 Players.PlayerAdded:Connect(add);Players.PlayerRemoving:Connect(function(p) states[p]=nil;nextAt[p]=nil end)
 for _,p in ipairs(Players:GetPlayers()) do add(p) end
 Market.PromptGamePassPurchaseFinished:Connect(function(p,id,purchased)
  if purchased and ids[id] and states[p] then
   -- The server purchase event is trusted, followed by the normal ownership refresh.
   local key=ids[id];states[p].Owned[key]=true;p:SetAttribute('HABPass'..key,true)
   deliver(p,key);task.spawn(refresh,p)
  end
 end)
 X.Api.OnServerInvoke=function(p,action,key)
  if type(action)~='string' or #action>20 or (key~=nil and (type(key)~='string' or #key>32)) then return {OK=false,Message='Invalid request.'} end
  local now=os.clock();if now<(nextAt[p] or 0) then return {OK=false,Message='Please wait.'} end;nextAt[p]=now+.22
  local ok,message,passId=true,nil,nil
  if action=='SelectAbility' then ok,message=Economy.HABSetAbility(p,key)
  elseif action=='BuyAbility' then ok,message=Economy.HABBuyAbility(p,key)
  elseif action=='EquipBundle' then
   if not S.Has(p,key) then ok=false;message='You do not own this bundle.'
   else ok,message=Economy.HABEquipBundle(p,key) end
  elseif action=='PassPrompt' then
   local offer=offers[key]
   if p:GetAttribute('InRound')==true then ok=false;message='Visit the shop in the lobby.'
   elseif not offer or not idValid(offer.Definition.Id) then ok=false;message='The developer has not configured this pass yet.'
   elseif S.Has(p,key) then ok=false;message='Already owned.'
   else passId=offer.Definition.Id end
  elseif action=='RefreshPasses' then
   local s=states[p]
   if s and now>(s.NextRefresh or 0) then s.NextRefresh=now+12;task.spawn(refresh,p) end
  elseif action~='Sync' then ok=false;message='Unknown request.' end
  return {OK=ok,Message=message,PassId=passId,Profile=snapshot(p)}
 end
 task.spawn(function()
  while script.Parent do
   task.wait(25)
   for p,s in pairs(states) do
    if p:GetAttribute('HussEconomyReady') then for key in pairs(s.Owned) do deliver(p,key) end end
   end
  end
 end)
 print('[HAB Passes] Guaranteed bundles and permanent passes ready; zero IDs are disabled.')
end
return S

-- HAB_FUN_9
