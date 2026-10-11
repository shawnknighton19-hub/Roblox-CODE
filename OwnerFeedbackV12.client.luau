--!nonstrict
-- Private server responses for owner commands, independent of open HUD menus.
local RS=game:GetService('ReplicatedStorage')
local TextChatService=game:GetService('TextChatService')
local StarterGui=game:GetService('StarterGui')
local queue={}
local working=false
local alive=true
local remote,connection
local function escape(text)
 return (text:gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;'))
end
local function flush()
 if working then return end;working=true
 while alive and #queue>0 do
  local row=table.remove(queue,1);local shown=false
  for attempt=1,10 do
   if not alive then break end
   local ok,result=pcall(function()
    if TextChatService.ChatVersion==Enum.ChatVersion.TextChatService then
     local channels=TextChatService:FindFirstChild('TextChannels')
     local channel=channels and (channels:FindFirstChild('RBXGeneral') or channels:FindFirstChild('RBXSystem') or channels:FindFirstChildOfClass('TextChannel'))
     if not channel then return false end
     channel:DisplaySystemMessage('<font color="'..(row.ok and '#72F5A8' or '#FFD166')..'">[Owner] '..escape(row.message)..'</font>')
    else StarterGui:SetCore('ChatMakeSystemMessage',{Text='[Owner] '..row.message,Color=row.ok and Color3.fromRGB(114,245,168) or Color3.fromRGB(255,209,102)}) end
    return true
   end)
   if ok and result then shown=true;break end
   if attempt<10 then task.wait(.5) end
  end
  if alive and not shown then pcall(StarterGui.SetCore,StarterGui,'SendNotification',{Title='Owner command',Text=row.message,Duration=10}) end
 end
 working=false
end
local function attach(child)
 if child.Name~='HussEconomyV9' or not child:IsA('RemoteEvent') or child==remote then return end
 if connection then connection:Disconnect() end
 remote=child
 connection=remote.OnClientEvent:Connect(function(data)
  if type(data)~='table' or data.kind~='OwnerCommand' or type(data.message)~='string' or #data.message>2048 then return end
  if #queue>=12 then table.remove(queue,1) end
  table.insert(queue,{ok=data.ok==true,message=data.message});task.spawn(flush)
 end)
end
local added=RS.ChildAdded:Connect(attach)
local removed=RS.ChildRemoved:Connect(function(child)
 if child==remote then if connection then connection:Disconnect() end;connection=nil;remote=nil end
end)
for _,child in ipairs(RS:GetChildren()) do attach(child) end
script.Destroying:Connect(function()
 alive=false;table.clear(queue);added:Disconnect();removed:Disconnect()
 if connection then connection:Disconnect() end
end)
