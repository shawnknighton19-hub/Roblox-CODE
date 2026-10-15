--!nonstrict
-- HAB_CRATE_UPGRADE_2. Default detonation + equipped last-giver VFX + compact kill feed.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Input=game:GetService('UserInputService')
local Debris=game:GetService('Debris')
local Pack=RS:WaitForChild('HABHalloween')
local Catalog=require(assert(Pack:WaitForChild('Catalog',15),'Catalog missing'))
local Render=require(assert(Pack:WaitForChild('Renderer',15),'Renderer missing'))
local Tween=game:GetService('TweenService')
local me=Players.LocalPlayer
local KillSound=require(Pack.HABKillSoundPlayer)
local function reduced() return me:GetAttribute('HussReducedMotion')==true or workspace:GetAttribute('HussReducedMotion')==true end
local function new(class,parent,props) local o=Instance.new(class);for k,v in pairs(props) do o[k]=v end;o.Parent=parent;return o end
local pg=me:WaitForChild('PlayerGui')
local old=pg:FindFirstChild('HABKillFeed');if old then old:Destroy() end
local gui=new('ScreenGui',pg,{Name='HABKillFeed',ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=180})
local holder=new('Frame',gui,{AnchorPoint=Vector2.new(0,0),Position=UDim2.fromOffset(14,80),Size=UDim2.fromOffset(288,140),BackgroundTransparency=1})
local rows={};local seen={};local seenOrder={};local lastSize=Vector2.zero
local white=Color3.fromRGB(248,250,255);local gold=Color3.fromRGB(255,218,66)
local function addFeed(e)
    local credited=e.Cause=='BOMB' and e.KillerUserId~=0 and e.KillerName~=''
    local title=credited and (e.KillerName..'  >  '..e.VictimName) or (e.VictimName..(e.Cause=='BOMB' and '  •  FUSE EXPIRED' or '  •  ELIMINATED'))
    local row=new('Frame',holder,{Size=UDim2.new(1,0,0,42),BackgroundColor3=Color3.fromRGB(33,40,61),BackgroundTransparency=.08,BorderSizePixel=0})
    new('UICorner',row,{CornerRadius=UDim.new(0,16)})
    local accent=new('Frame',row,{Size=UDim2.new(0,3,1,-10),Position=UDim2.fromOffset(0,5),BackgroundColor3=gold,BorderSizePixel=0})
    local t=new('TextLabel',row,{Position=UDim2.fromOffset(10,3),Size=UDim2.new(1,-20,0,22),BackgroundTransparency=1,
        Text=title,Font=Enum.Font.GothamBold,TextSize=13,TextColor3=white,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,RichText=false})
    local sub=new('TextLabel',row,{Position=UDim2.fromOffset(10,25),Size=UDim2.new(1,-20,0,13),BackgroundTransparency=1,
        Text=(credited and 'BOMB TRANSFER' or 'ARENA')..(e.Practice and '  /  PRACTICE' or ''),Font=Enum.Font.GothamBold,TextSize=9,TextColor3=gold,TextXAlignment=Enum.TextXAlignment.Left})
    table.insert(rows,1,{row=row,t=t,sub=sub,accent=accent,at=os.clock()})
    while #rows>3 do table.remove(rows).row:Destroy() end
end
local function detonate(e)
    local camera=workspace.CurrentCamera
    if not camera or (camera.CFrame.Position-e.Position).Magnitude>350 then return end
    if reduced() then return end
    -- This explosion is VISUAL ONLY. BombService already chose/killed exactly one victim.
    local explosion=Instance.new('Explosion')
    explosion.Name='HABCosmeticDetonation';explosion.BlastRadius=8;explosion.BlastPressure=0
    explosion.DestroyJointRadiusPercent=0;explosion.ExplosionType=Enum.ExplosionType.NoCraters
    explosion.Position=e.Position;explosion.Visible=true;explosion.Parent=workspace
    Debris:AddItem(explosion,3)
    -- Guaranteed visible fallback even when custom textures are unavailable.
    local orb=new('Part',workspace,{Name='HABDetonationCore',Shape=Enum.PartType.Ball,Size=Vector3.new(1,1,1),CFrame=CFrame.new(e.Position),
        Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false,Material=Enum.Material.Neon,
        Color=Color3.fromRGB(255,184,92),Transparency=.2})
    Tween:Create(orb,TweenInfo.new(.36,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.new(13,13,13),Transparency=1}):Play()
    Debris:AddItem(orb,.45)
    local host=new('Part',workspace,{Name='HABDetonationParticles',Size=Vector3.new(.1,.1,.1),CFrame=CFrame.new(e.Position),
        Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,Transparency=1})
    local att=new('Attachment',host,{})
    local sparks=new('ParticleEmitter',att,{Texture='rbxasset://textures/particles/sparkles_main.dds',Enabled=false,Rate=0,
        Speed=NumberRange.new(13,26),Lifetime=NumberRange.new(.25,.65),SpreadAngle=Vector2.new(180,180),
        LightEmission=.75,Color=ColorSequence.new(Color3.fromRGB(255,179,85)),Size=NumberSequence.new(.25),
        Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})})
    sparks:Emit(24);Debris:AddItem(host,1)

end

local connection=Pack.Events.OnClientEvent:Connect(function(action,e)
    if action~='Detonation' or type(e)~='table' or type(e.Id)~='string' or seen[e.Id] then return end
    if typeof(e.Position)~='Vector3' or type(e.Time)~='number' or e.Time~=e.Time then return end
    local age=workspace:GetServerTimeNow()-e.Time
    if age>8 or age< -1 then return end
    seen[e.Id]=true;seenOrder[#seenOrder+1]=e.Id
    if #seenOrder>128 then seen[table.remove(seenOrder,1)]=nil end
    e.VictimName=tostring(e.VictimName or 'Player'):sub(1,64)
    e.KillerName=tostring(e.KillerName or ''):sub(1,64)
    addFeed(e)
    if e.Cause=='BOMB' and e.KillerUserId~=0 and e.EffectId then
     local ok,err=pcall(KillSound.Play,e.EffectId,e.Position,false)
     if not ok then warn('[HAB Kill Sound] '..tostring(err)) end
    end
    local ok,err=pcall(detonate,e)
    if not ok then warn('[HAB Detonation] '..tostring(err)) end
end)
local heartbeat=Run.RenderStepped:Connect(function()
    local camera=workspace.CurrentCamera
    local size=camera and camera.ViewportSize or Vector2.new(1280,720)
    local compact=size.X<780 or Input.TouchEnabled
    gui.Enabled=me:GetAttribute('HABModalOwnerV15')==nil
    if size~=lastSize then
        lastSize=size;holder.Size=UDim2.fromOffset(math.min(288,size.X-28),140)
        holder.Position=UDim2.fromOffset(14,compact and (size.Y<430 and 78 or 152) or 80)
    end
    local now=os.clock()
    for i=#rows,1,-1 do
        local v=rows[i];local age=now-v.at
        if age>=6 then v.row:Destroy();table.remove(rows,i)
        else
            v.row.Visible=not compact or i==1
            v.row.Position=UDim2.fromOffset(0,(i-1)*46)
            local fade=math.clamp((age-5)/1,0,1)
            v.row.BackgroundTransparency=.08+.92*fade
            v.t.TextTransparency=fade;v.sub.TextTransparency=fade;v.accent.BackgroundTransparency=fade
        end
    end
end)
script.Destroying:Connect(function() connection:Disconnect();heartbeat:Disconnect();gui:Destroy() end)
-- HAB_CRATES_REPAIR_3
print('[HAB Combat FX] Cosmetic explosions, last-giver effects and kill feed ready.')



-- HAB_FUN_9
