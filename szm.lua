local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer
local PS = LP:WaitForChild("PlayerScripts")
local PC = PS:WaitForChild("PlayerClient")
local PR = PC:WaitForChild("ParryRequest")
local Swords = ReplicatedStorage:WaitForChild("Swords")

local Window = Library:CreateWindow({
    Title = "Byte",
    Size = Vector2.new(600, 400),
    Layout = "Bottom bar",
    MenuKey = Enum.KeyCode.RightShift,
    NotificationPosition = "BottomRight",
})

local Tabs = {
    Main = Window:AddTab("Main", "house"),
    Settings = Window:CreateSettingsTab(),
}

local WatermarkGui = Instance.new('ScreenGui')
WatermarkGui.Name = 'ByteWatermark'
WatermarkGui.ResetOnSpawn = false
WatermarkGui.IgnoreGuiInset = true
WatermarkGui.DisplayOrder = 999
WatermarkGui.Parent = (typeof(gethui) == 'function' and gethui()) or game:GetService('CoreGui')

local MainWM = Instance.new('Frame')
MainWM.Size = UDim2.fromOffset(0, 32)
MainWM.AutomaticSize = Enum.AutomaticSize.X
MainWM.Position = UDim2.new(0.5, 0, 0, 10)
MainWM.AnchorPoint = Vector2.new(0.5, 0)
MainWM.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainWM.BackgroundTransparency = 0.1
MainWM.BorderSizePixel = 0
MainWM.Parent = WatermarkGui

local MainLayout = Instance.new('UIListLayout')
MainLayout.FillDirection = Enum.FillDirection.Horizontal
MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
MainLayout.VerticalAlignment = Enum.VerticalAlignment.Center
MainLayout.Padding = UDim.new(0, 8)
MainLayout.Parent = MainWM

local MainPadding = Instance.new('UIPadding')
MainPadding.PaddingLeft = UDim.new(0, 10)
MainPadding.PaddingRight = UDim.new(0, 14)
MainPadding.Parent = MainWM

Instance.new('UICorner', MainWM).CornerRadius = UDim.new(0, 6)
local Stroke = Instance.new('UIStroke')
Stroke.Color = Color3.fromRGB(50, 50, 50)
Stroke.Thickness = 1
Stroke.Parent = MainWM

local Logo = Instance.new('ImageLabel')
Logo.Size = UDim2.fromOffset(20, 20)
Logo.BackgroundTransparency = 1
Logo.Image = "rbxassetid://95943456246483"
Logo.ScaleType = Enum.ScaleType.Fit
Logo.Parent = MainWM

local Name = Instance.new('TextLabel')
Name.Size = UDim2.fromOffset(0, 32)
Name.AutomaticSize = Enum.AutomaticSize.X
Name.BackgroundTransparency = 1
Name.Text = 'Byte'
Name.TextColor3 = Color3.new(1,1,1)
Name.TextSize = 14
Name.Font = Enum.Font.GothamBold
Name.LayoutOrder = 2
Name.Parent = MainWM

local Info = Instance.new('TextLabel')
Info.Size = UDim2.fromOffset(0, 32)
Info.AutomaticSize = Enum.AutomaticSize.X
Info.BackgroundTransparency = 1
Info.TextColor3 = Color3.fromRGB(220, 220, 220)
Info.TextSize = 13
Info.Font = Enum.Font.Gotham
Info.LayoutOrder = 3
Info.Parent = MainWM

local frames = 0
RunService.RenderStepped:Connect(function()
    frames = frames + 1
end)

task.spawn(function()
    while task.wait(1) do
        local realPing = 0
        local pingStat = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
        if pingStat then realPing = math.floor(pingStat:GetValue()) end
        Info.Text = string.format("%s | %d FPS | %d MS", os.date("%H:%M:%S"), frames, realPing)
        frames = 0
    end
end)

local AutoParryEnabled = false
local lastT = -math.huge
local ActiveBalls = {}
local currentMatch = nil
local currentDoom = nil
local parryCdEnd = 0
local duelOut = false
local userId = LP.UserId

LP:GetAttributeChangedSignal("Match"):Connect(function() currentMatch = LP:GetAttribute("Match") end)
LP:GetAttributeChangedSignal("LocalDoomedAt"):Connect(function() currentDoom = LP:GetAttribute("LocalDoomedAt") end)
LP:GetAttributeChangedSignal("ParryCooldownEnd"):Connect(function() parryCdEnd = LP:GetAttribute("ParryCooldownEnd") or 0 end)
LP:GetAttributeChangedSignal("DuelOut"):Connect(function() duelOut = LP:GetAttribute("DuelOut") end)

currentMatch = LP:GetAttribute("Match")
currentDoom = LP:GetAttribute("LocalDoomedAt")
parryCdEnd = LP:GetAttribute("ParryCooldownEnd") or 0
duelOut = LP:GetAttribute("DuelOut")

CollectionService:GetInstanceAddedSignal("Ball"):Connect(function(ball)
    ActiveBalls[ball] = true
end)
CollectionService:GetInstanceRemovedSignal("Ball"):Connect(function(ball)
    ActiveBalls[ball] = nil
end)
for _, ball in ipairs(CollectionService:GetTagged("Ball")) do
    ActiveBalls[ball] = true
end

local function ballOnMe()
    if not currentMatch then return false end
    for b in pairs(ActiveBalls) do
        if b.Parent then
            if (b:GetAttribute("Match") or "FFA") == currentMatch and b:GetAttribute("TargetUserId") == userId then
                return true
            end
        else
            ActiveBalls[b] = nil
        end
    end
    return false
end

local function go()
    local t = os.clock()
    if t - lastT < 0.05 then return end
    lastT = t
    PR:Fire(false)
end

RunService.Heartbeat:Connect(function()
    if not AutoParryEnabled or not currentMatch then return end
    
    local t = os.clock()
    if type(currentDoom) ~= "number" then return end
    local ttl = currentDoom - t
    if ttl <= 0 then return end
    
    local sNow = workspace:GetServerTimeNow()
    if sNow < parryCdEnd then return end
    
    local ch = LP.Character
    if not ch then return end
    local hm = ch:FindFirstChildOfClass("Humanoid")
    if not hm or hm.Health <= 0 or duelOut == true then return end

    if ballOnMe() then
        local pingVal = 0
        local pingStat = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
        if pingStat then pingVal = pingStat:GetValue() / 1000 end
        
        local dynamicLead = math.clamp(0.1 + pingVal, 0.12, 0.28)
        
        if ttl <= dynamicLead then
            go()
        end
    end
end)

local AntiLagEnabled = false
local AntiLag_Cache = {}
local AntiLag_Conns = {}
local AntiLag_Hidden = { Decoration = true }
local AntiLag_Terrain = workspace.Terrain
local AntiLag_Render = settings().Rendering

local function AL_Put(inst, prop, value)
    local ok, get = pcall(function() return inst[prop] end)
    if not ok then return end
    if get == value then return end
    
    if AntiLag_Hidden[prop] then
        if gethiddenproperty and sethiddenproperty then
            pcall(sethiddenproperty, inst, prop, value)
        end
    else
        pcall(function() inst[prop] = value end)
    end

    local props = AntiLag_Cache[inst]
    if not props then props = {}; AntiLag_Cache[inst] = props end
    if props[prop] == nil then props[prop] = get end
end

local function AL_Off(obj) AL_Put(obj, 'Enabled', false) end

local function AL_Apply(obj)
    local cls = obj.ClassName
    if cls == 'Atmosphere' then
        AL_Put(obj, 'Density', 0); AL_Put(obj, 'Haze', 0); AL_Put(obj, 'Glare', 0)
    elseif cls == 'Clouds' or cls == 'BloomEffect' or cls == 'BlurEffect'
        or cls == 'DepthOfFieldEffect' or cls == 'SunRaysEffect'
        or cls == 'ColorCorrectionEffect' or cls == 'ColorGradingEffect' then
        AL_Off(obj)
    end
end

local function AL_ApplyChild(obj)
    if not AntiLagEnabled then return end
    AL_Apply(obj)
    if obj:IsA('BloomEffect') or obj:IsA('BlurEffect') or obj:IsA('DepthOfFieldEffect')
        or obj:IsA('SunRaysEffect') or obj:IsA('ColorCorrectionEffect')
        or obj:IsA('ColorGradingEffect') or obj:IsA('Clouds') then
        table.insert(AntiLag_Conns, obj:GetPropertyChangedSignal('Enabled'):Connect(function()
            if AntiLagEnabled and obj.Parent and obj.Enabled then obj.Enabled = false end
        end))
    end
end

local function AL_Scan(root)
    if not root then return end
    for _, c in ipairs(root:GetChildren()) do AL_ApplyChild(c) end
end

local function AL_Restore()
    for inst, props in pairs(AntiLag_Cache) do
        if inst.Parent ~= nil then
            for prop, value in pairs(props) do
                if AntiLag_Hidden[prop] then
                    if sethiddenproperty then pcall(sethiddenproperty, inst, prop, value) end
                else
                    pcall(function() inst[prop] = value end)
                end
            end
        end
    end
    table.clear(AntiLag_Cache)
end

local function AL_ClearConns()
    for _, c in ipairs(AntiLag_Conns) do pcall(function() c:Disconnect() end) end
    table.clear(AntiLag_Conns)
end

local function StartAntiLag()
    if AntiLagEnabled then return end
    AntiLagEnabled = true
    
    if AntiLag_Render then AL_Put(AntiLag_Render, 'QualityLevel', Enum.QualityLevel.Level01) end
    AL_Put(Lighting, 'GlobalShadows', false)
    AL_Put(Lighting, 'EnvironmentDiffuseScale', 0)
    AL_Put(Lighting, 'EnvironmentSpecularScale', 0)
    AL_Put(AntiLag_Terrain, 'WaterWaveSize', 0)
    AL_Put(AntiLag_Terrain, 'WaterWaveSpeed', 0)
    AL_Put(AntiLag_Terrain, 'WaterReflectance', 0)
    
    AL_Scan(Lighting)
    AL_Scan(AntiLag_Terrain)
    if workspace.CurrentCamera then AL_Scan(workspace.CurrentCamera) end
    
    table.insert(AntiLag_Conns, Lighting.ChildAdded:Connect(AL_ApplyChild))
    if workspace.CurrentCamera then
        table.insert(AntiLag_Conns, workspace.CurrentCamera.ChildAdded:Connect(AL_ApplyChild))
    end
    table.insert(AntiLag_Conns, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
        if workspace.CurrentCamera and AntiLagEnabled then AL_Scan(workspace.CurrentCamera) end
    end))
    table.insert(AntiLag_Conns, AntiLag_Terrain.ChildAdded:Connect(AL_ApplyChild))
end

local function StopAntiLag()
    if not AntiLagEnabled then return end
    AntiLagEnabled = false
    AL_ClearConns()
    AL_Restore()
end

local UnlockAllEnabled = false
local localEquipped = "Katana"
local currentWeld, currentHandle, currentClone
local isSwinging = false

local EXACT_KATANA_C0 = CFrame.new(
    1.91326904, -0.555279553, 0.570863724, 
    -0.993200898, -0.116335914, -0.00423767185, 
    -0.116337016, 0.993209779, 1.20674376e-05, 
    0.00420749327, 0.000504983473, -0.999991059
)
local EXACT_SHARD_C0 = CFrame.new(
    1.64666748, 1.45924377, 0.309757233, 
    -0.98480022, -0.103766903, -0.139287427, 
    -0.103477016, 0.994587958, -0.00934135634, 
    0.139502928, 0.00521367695, -0.990207911
)

local ALL = {}
for _, s in ipairs(Swords:GetChildren()) do
    if s:IsA("Model") then table.insert(ALL, s.Name) end
end
local ALL_JSON = HttpService:JSONEncode(ALL)

if not getgenv().SlantHooked then
    getgenv().SlantHooked = true
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", function(self, key)
        if key == "GetAttribute" and typeof(self) == "Instance" then
            return function(_, attr)
                if self == LP then
                    if attr == "OwnedSwords" and UnlockAllEnabled then return ALL_JSON end
                    if attr == "EquippedSword" and UnlockAllEnabled then return localEquipped end
                elseif self.Parent == Swords and UnlockAllEnabled then
                    if attr == "Hidden" or attr == "MinRank" or attr == "OwnerOnly" then return nil end
                end
                return oldIndex(self, key)(self, attr)
            end
        end
        return oldIndex(self, key)
    end)
end

RunService.Heartbeat:Connect(function()
    if not UnlockAllEnabled then return end
    if LP:GetAttribute("OwnedSwords") ~= ALL_JSON then LP:SetAttribute("OwnedSwords", ALL_JSON) end
    if LP:GetAttribute("EquippedSword") ~= localEquipped then LP:SetAttribute("EquippedSword", localEquipped) end
    
    local char = LP.Character
    if char and char:GetAttribute("CurrentlyEquippedSword") ~= localEquipped then
        char:SetAttribute("CurrentlyEquippedSword", localEquipped)
    end
end)

local function updateVisualSword()
    if not UnlockAllEnabled then return end
    local char = LP.Character
    if not char then return end
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if not torso then return end

    local targetSwordModel = Swords:FindFirstChild(localEquipped)
    if not targetSwordModel then return end

    if char:FindFirstChild("Sword") then char.Sword:Destroy() end
    if currentClone then currentClone:Destroy() end

    currentClone = targetSwordModel:Clone()
    currentClone.Name = "Sword" 
    
    currentHandle = currentClone:FindFirstChild("SwordHandle") or currentClone:FindFirstChildWhichIsA("BasePart")
    if not currentHandle then return end
    currentClone.PrimaryPart = currentHandle

    local anims = targetSwordModel:FindFirstChild("Animations")
    if anims then
        if currentClone:FindFirstChild("Animations") then currentClone.Animations:Destroy() end
        anims:Clone().Parent = currentClone
    end

    for _, d in ipairs(currentClone:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = false
            d.CanCollide = false
            d.Massless = true
        end
        if d:IsA("ParticleEmitter") then CollectionService:AddTag(d, "SwordAura") end
        if d:IsA("Trail") then CollectionService:AddTag(d, "SwordTrail") end
    end

    if currentWeld then currentWeld:Destroy() end
    currentWeld = Instance.new("Weld")
    currentWeld.Name = "SwordJoint"
    currentWeld.Part0 = torso
    currentWeld.Part1 = currentHandle
    
    local normalBackSwords = {
        ["Katana"] = true, ["Shiro Katana"] = true, ["Black Sword"] = true, 
        ["Longsword"] = true, ["Thorn Katana"] = true, ["Aevum's Blade"] = true,
        ["Blue Laser Saber"] = true, ["Purple Laser Saber"] = true, 
        ["Green Laser Saber"] = true, ["Orange Laser Saber"] = true, ["Rapier"] = true
    }
    
    if normalBackSwords[localEquipped] then
        currentWeld.C0 = EXACT_KATANA_C0
    else
        currentWeld.C0 = EXACT_SHARD_C0
    end
    
    currentWeld.Parent = torso
    currentClone.Parent = char
end

local function playSwingEffect()
    if not UnlockAllEnabled or isSwinging or not currentWeld or not currentHandle or not currentClone then return end
    local char = LP.Character
    if not char then return end
    local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
    if not rightArm or not torso then return end

    isSwinging = true

    for _, d in ipairs(currentClone:GetDescendants()) do
        if d:IsA("Trail") or d:IsA("Beam") then d.Enabled = false end
    end

    currentWeld.Part0 = rightArm
    currentWeld.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(math.rad(90), 0, math.rad(90))

    LP:SetAttribute("SwingCount", os.clock())

    task.delay(0.6, function()
        if currentWeld and currentWeld.Parent then
            currentWeld.Part0 = torso
            local normalBackSwords = {
                ["Katana"] = true, ["Shiro Katana"] = true, ["Black Sword"] = true, 
                ["Longsword"] = true, ["Thorn Katana"] = true, ["Aevum's Blade"] = true,
                ["Blue Laser Saber"] = true, ["Purple Laser Saber"] = true, 
                ["Green Laser Saber"] = true, ["Orange Laser Saber"] = true, ["Rapier"] = true
            }
            if normalBackSwords[localEquipped] then
                currentWeld.C0 = EXACT_KATANA_C0
            else
                currentWeld.C0 = EXACT_SHARD_C0
            end

            task.delay(0.1, function()
                if currentClone and currentClone.Parent then
                    for _, d in ipairs(currentClone:GetDescendants()) do
                        if d:IsA("Trail") or d:IsA("Beam") then d.Enabled = true end
                    end
                end
                isSwinging = false
            end)
        end
    end)
end

PR.Event:Connect(playSwingEffect)

task.spawn(function()
    local inv = LP.PlayerGui:WaitForChild("InventoryGui", 60)
    if not inv then return end
    local function hookUI()
        for _, d in ipairs(inv:GetDescendants()) do
            if d:IsA("TextButton") and Swords:FindFirstChild(d.Name) and not d:GetAttribute("Hooked") then
                d:SetAttribute("Hooked", true)
                d.Activated:Connect(function()
                    if not UnlockAllEnabled then return end
                    localEquipped = d.Name
                    updateVisualSword()
                end)
            end
        end
    end
    hookUI()
    inv.DescendantAdded:Connect(hookUI)
end)

LP.CharacterAdded:Connect(function()
    task.wait(1.5)
    if UnlockAllEnabled then updateVisualSword() end
end)

local MainGroup = Tabs.Main:AddLeftGroupbox("Features", "shield")

local AutoParryToggle = MainGroup:AddToggle('Auto_Parry_Toggle', {
    Text = 'Auto Parry',
    Default = false,
    Callback = function(state)
        AutoParryEnabled = state
    end
})

AutoParryToggle:AddKeyPicker('Auto_Parry_Keybind', {
    Text = 'Auto Parry',
    Mode = 'Toggle',
})

MainGroup:AddToggle('Unlock_All_Toggle', {
    Text = 'Unlock All Swords',
    Default = false,
    Callback = function(state)
        UnlockAllEnabled = state
        if state then
            updateVisualSword()
        else
            if currentClone then currentClone:Destroy() end
            local char = LP.Character
            if char and char:FindFirstChild("Sword") then char.Sword:Destroy() end
        end
    end
})

local PerfGroup = Tabs.Main:AddRightGroupbox("Performance", "zap")
PerfGroup:AddToggle('Anti_Lag_Toggle', {
    Text = 'Enable Anti-Lag (FPS Boost)',
    Default = false,
    Tooltip = 'Disables post-processing, shadows, and water reflections to boost FPS.',
    Callback = function(state)
        if state then
            StartAntiLag()
        else
            StopAntiLag()
        end
    end
})

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
ThemeManager:SetFolder("Byte/Viz")
SaveManager:SetFolder("Byte/Viz")
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:LoadDefault()
pcall(function() SaveManager:LoadAutoloadConfig() end)

local SettingsGroup = Tabs.Settings:AddRightGroupbox("Script Control", "power")
SettingsGroup:AddButton({
    Text = "Unload Script",
    Callback = function()
        StopAntiLag()
        if currentClone then currentClone:Destroy() end
        Library:Unload()
        WatermarkGui:Destroy()
    end,
    Tooltip = "Unloads the script and restores everything.",
})

Window:Notify({ Title = "Byte", Content = "Loaded successfully", Duration = 4 })
