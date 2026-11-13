local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Shooter = ReplicatedStorage:WaitForChild("Shooter", 20)

local LP = Players.LocalPlayer
local Player = LP
local Local_Player_Name = LP.Name
local GEN = (rawget(_G, "Byte_SHOOTER_GEN") or 0) + 1
rawset(_G, "Byte_SHOOTER_GEN", GEN)

local _ScriptUnloaded = false
local Connections_Manager = {}
local tearing = false

local BallsFolder = workspace:FindFirstChild("Balls")
local AliveFolder = workspace:FindFirstChild("Alive")
local RuntimeFolder = workspace:FindFirstChild("Runtime")

local function alive()
    return rawget(_G, "Byte_SHOOTER_GEN") == GEN
end

local S = { gp = false, sb = false, passes = 0 }
local O = {}
local pass

local function req(name)
    local inst = Shooter and Shooter:FindFirstChild(name)
    if not inst then return nil end
    local ok, m = pcall(require, inst)
    if ok and type(m) == "table" then return m end
    return nil
end

local function find_pass()
    local order = { "MinigunTrial", "WeaponsPanel", "SandboxPanel", "HUD", "SideBar", "MainMenu", "Sandbox", "TracerPass" }
    for _, name in ipairs(order) do
        local m = req(name)
        if m then
            for _, fn in pairs(m) do
                if type(fn) == "function" then
                    for i = 1, 40 do
                        local ok, v = pcall(debug.getupvalue, fn, i)
                        if not ok then break end
                        if type(v) == "table" then
                            local c = rawget(v, "ctx")
                            if type(c) == "table" then
                                local p = rawget(c, "pass")
                                if type(p) == "table" and type(rawget(p, "isOwned")) == "function" then
                                    return p
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function persist()
    if tearing then return end
    pcall(function()
        workspace:SetAttribute("ANON_GP", S.gp)
        workspace:SetAttribute("ANON_SB", S.sb)
    end)
end

local function apply_gp(on)
    pass = pass or find_pass()
    if pass then
        if on then
            if not O.is_owned then O.is_owned = pass.isOwned end
            pass.isOwned = function() return true end
        elseif O.is_owned then
            pass.isOwned = O.is_owned
        end
    end

    local gate = req("PassGate")
    if gate then
        if on then
            if not O.gate then O.gate = { wait = gate.wait, owned = gate.owned, confirm = gate.confirm } end
            gate.wait = function() return true end
            gate.owned = function() return true end
            gate.confirm = function() return true end
        elseif O.gate then
            gate.wait, gate.owned, gate.confirm = O.gate.wait, O.gate.owned, O.gate.confirm
        end
    end

    local tracer = req("TracerPass")
    if tracer and type(tracer.isOwned) == "function" then
        if on then
            if not O.tracer then O.tracer = tracer.isOwned end
            tracer.isOwned = function() return true end
        elseif O.tracer then
            tracer.isOwned = O.tracer
        end
    end

    S.gp = on
    S.passes = on and 7 or 0
    persist()
end

local function apply_sb(on)
    local sandbox = req("Sandbox")
    if sandbox then
        pcall(sandbox.forceOwned, on)
        pcall(sandbox.setActive, on)
        S.sb = on and sandbox.active == true
    end
    persist()
end

local Window = Library:CreateWindow({
    Title = "Byte",
    Layout = "Bottom bar",
    MenuKey = Enum.KeyCode.RightShift,
})

local Main = Window:AddTab("Main", "house")
local Settings = Window:CreateSettingsTab()
local Group = Main:AddLeftGroupbox("Shooter", "sliders-horizontal")

Group:AddToggle("AllGamepasses", {
    Text = "All Gamepasses",
    Default = false,
    Callback = function(value)
        if not alive() then return end
        apply_gp(value)
    end,
})

Group:AddToggle("SandboxMode", {
    Text = "Unlock Sandbox",
    Default = false,
    Callback = function(value)
        if not alive() then return end
        apply_sb(value)
    end,
})

Group:AddButton({
    Text = "Reset Hooks",
    Callback = function()
        apply_sb(false)
        apply_gp(false)
        Library.Toggles.AllGamepasses:SetValue(false)
        Library.Toggles.SandboxMode:SetValue(false)
    end,
})

local WatermarkGui = nil

local function CreateWatermark()
    if WatermarkGui then return WatermarkGui end

    local g = Instance.new('ScreenGui')
    g.Name = 'ByteWatermark'
    g.ResetOnSpawn = false
    g.IgnoreGuiInset = true
    g.DisplayOrder = 999
    g.Enabled = true

    local parent
    if typeof(gethui) == 'function' then
        local ok, hui = pcall(gethui)
        if ok and hui then
            if pcall(function() g.Parent = hui end) then
                parent = hui
            end
        end
    end
    if not parent then
        local ok, cg = pcall(function() return game:GetService('CoreGui') end)
        if ok and cg then
            if pcall(function() g.Parent = cg end) then
                parent = cg
            end
        end
    end
    if not parent then
        local pg = LP:FindFirstChild('PlayerGui') or LP:WaitForChild('PlayerGui', 5)
        if pg then
            if pcall(function() g.Parent = pg end) then
                parent = pg
            end
        end
    end
    if not parent then
        g:Destroy()
        return nil
    end

    local frame = Instance.new('Frame')
    frame.Size = UDim2.fromOffset(0, 32)
    frame.AutomaticSize = Enum.AutomaticSize.X
    frame.Position = UDim2.new(0.5, 0, 0, 10)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = g

    local layout = Instance.new('UIListLayout')
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 8)
    layout.Parent = frame

    local padding = Instance.new('UIPadding')
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 14)
    padding.Parent = frame

    Instance.new('UICorner', frame).CornerRadius = UDim.new(0, 6)

    local stroke = Instance.new('UIStroke')
    stroke.Color = Color3.fromRGB(50, 50, 50)
    stroke.Thickness = 1
    stroke.Parent = frame

    local logo = Instance.new('ImageLabel')
    logo.Size = UDim2.fromOffset(20, 20)
    logo.Position = UDim2.new(0, 8, 0.5, -10)
    logo.BackgroundTransparency = 1
    logo.Image = "rbxassetid://95943456246483"
    logo.ScaleType = Enum.ScaleType.Fit
    logo.Parent = frame

    local name = Instance.new('TextLabel')
    name.Size = UDim2.fromOffset(0, 32)
    name.AutomaticSize = Enum.AutomaticSize.X
    name.BackgroundTransparency = 1
    name.Text = 'Byte'
    name.TextColor3 = Color3.new(1, 1, 1)
    name.TextSize = 14
    name.Font = Enum.Font.GothamBold
    name.TextXAlignment = Enum.TextXAlignment.Left
    name.LayoutOrder = 2
    name.Parent = frame

    local info = Instance.new('TextLabel')
    info.Size = UDim2.fromOffset(0, 32)
    info.AutomaticSize = Enum.AutomaticSize.X
    info.BackgroundTransparency = 1
    info.TextColor3 = Color3.fromRGB(220, 220, 220)
    info.TextSize = 13
    info.Font = Enum.Font.Gotham
    info.TextXAlignment = Enum.TextXAlignment.Left
    info.LayoutOrder = 3
    info.Parent = frame

    local frames, lastUpdate = 0, tick()
    local cachedRegion = "Loading..."

    task.spawn(function()
        local function FindServerText()
            local playerGui = LP:FindFirstChild("PlayerGui")
            if playerGui then
                for _, desc in ipairs(playerGui:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Text:find("Server Region:") then
                        return string.gsub(desc.Text, "Server Region:%s*", "")
                    end
                end
            end
            local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
            if ok and coreGui then
                for _, desc in ipairs(coreGui:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Text:find("Server Region:") then
                        return string.gsub(desc.Text, "Server Region:%s*", "")
                    end
                end
            end
            local jid = game.JobId
            if jid and #jid > 0 then
                return string.upper(string.sub(jid, 1, 4))
            end
            return "Unknown"
        end
        cachedRegion = FindServerText()
    end)

    Connections_Manager['Watermark_FPS'] = RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = tick()
        if now - lastUpdate >= 1 then
            local realPing = 0
            local pingStat = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
            if pingStat then
                realPing = math.floor(pingStat:GetValue())
            end
            info.Text = string.format("%s | %d FPS | %d MS | %s", os.date("%H:%M:%S"), math.floor(frames / (now - lastUpdate)), realPing, cachedRegion)
            frames = 0
            lastUpdate = now
        end
    end)

    local dragging, dragStart, startPos
    Connections_Manager['Watermark_DragStart'] = frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, frame.Position
        end
    end)
    Connections_Manager['Watermark_DragMove'] = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    Connections_Manager['Watermark_DragEnd'] = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    WatermarkGui = g
    return g
end

local NR_Enabled = false
local NR_Gen = 0
local NR_Store = {}
local NR_Pinned = {}
local NR_HIDDEN = { Decoration = true }
local NR_Terrain = workspace.Terrain
local NR_Render = nil
pcall(function() NR_Render = settings().Rendering end)
local NR_HiddenParts = {}
local NR_HiddenGuis2 = {}
local NR_HiddenGuis = {}
local NR_LightingSeen = {}
local NR_ZERO_LIFETIME = NumberRange.new(0)

NR_Pinned[Lighting] = true
NR_Pinned[NR_Terrain] = true
if NR_Render then NR_Pinned[NR_Render] = true end

local NR_MAP_FOLDER_NAMES = {
    Map=true,LobbySpawnPlate=true,Spawn=true,Leaderboards=true,
    Drones=true,ZombieCrownClash=true,PixelKillEvent=true,
    SummerEventBB=true,FriendCrate=true,MapBounds=true,
}
local NR_DIRECT_WORKSPACE_PARTS = { FakeSky=true }
local NR_LOBBY_GUI_NAMES = {
    LobbyTickets=true,LobbyLTMPack=true,LobbyJoinIssue=true,
    MobileLobbyPrompt=true,ServerBrowser=true,ServerBrowserOld=true,
    ServerSelection=true,ServerSelectionNew=true,ChooseMap=true,
    MapSelector=true,RankedQueue=true,RankedSelection=true,
    MatchFound=true,ChooserUI=true,WaitingScreen=true,
    TournamentWaiting=true,CutsceneWaiting=true,spawnTut=true,
}
local NR_LIGHTING = {
    GlobalShadows=false,Brightness=1,ClockTime=14,
    ExposureCompensation=0,EnvironmentDiffuseScale=0,
    EnvironmentSpecularScale=0,FogStart=math.huge,FogEnd=math.huge,
    ShadowSoftness=0,
    Ambient=Color3.fromRGB(70,70,70),
    OutdoorAmbient=Color3.fromRGB(70,70,70),
}
local NR_CONNECTIONS = {
    'NR_Descendant','NR_DescDrain','NR_LightingChild','NR_LightingProp',
    'NR_Runtime','NR_MapDescendant','NR_GuiAdded','NR_GraySkyForce','NR_MapChanged','NR_MapRemoved','NR_MatchCheck',
}

local NR_WEAPON_NAMES = {
    Weapons = true, Weapon = true, Gun = true, Guns = true,
    ViewModel = true, Viewmodel = true, viewmodel = true,
    FPArms = true, FPSArms = true, Arms = true, ArmsFolder = true,
    Tool = true, Tools = true, EquippedTool = true, EquippedTools = true,
    Firearm = true, Firearms = true, Handgun = true, Rifle = true,
    Pistol = true, Shotgun = true, Melee = true, Blade = true,
    Sword = true, Knife = true, WeaponModel = true, WeaponModels = true,
    LocalWeapon = true, CharacterWeapons = true, HeldTool = true,
}

local function NR_IsGameplayAncestor(inst)
    local p = inst
    while p and p ~= workspace do
        if (BallsFolder and p == BallsFolder) or (AliveFolder and p == AliveFolder) or (RuntimeFolder and p == RuntimeFolder) then
            return true
        end
        p = p.Parent
    end
    return false
end

local function NR_IsProtected(inst)
    if not inst then return false end

    if inst:IsA("Tool") then return true end
    if inst:FindFirstAncestorOfClass("Tool") then return true end

    local char = LP.Character
    if char and (inst == char or inst:IsDescendantOf(char)) then return true end

    local cam = workspace.CurrentCamera
    if cam and (inst == cam or inst:IsDescendantOf(cam)) then return true end

    local p = inst
    while p and p ~= workspace do
        local n = p.Name
        if NR_WEAPON_NAMES[n] then return true end
        p = p.Parent
    end

    local anc = inst:FindFirstAncestorOfClass("Model")
    if anc then
        local hum = anc:FindFirstChildOfClass("Humanoid")
        if hum then return true end
    end

    return false
end

local function NR_IsIgnored(inst)
    local p = inst
    while p and p ~= workspace do
        if p:GetAttribute('NoRender_Ignore') then return true end
        p = p.Parent
    end
    return false
end

local function NR_IsMapDescendant(part)
    local p = part.Parent
    while p and p ~= workspace do
        if NR_MAP_FOLDER_NAMES[p.Name] then return true end
        p = p.Parent
    end
    return part.Anchored and not NR_IsGameplayAncestor(part)
end

local function NR_Get(inst, prop) return inst[prop] end
local function NR_Put(inst, prop, value) inst[prop] = value end

local function NR_Set(inst, prop, value)
    local get, put = NR_Get, NR_Put
    if NR_HIDDEN[prop] then
        get = gethiddenproperty
        put = sethiddenproperty
    end
    if not (get and put) then return end
    local ok, cur = true, get(inst, prop)
    if not ok or cur == value then return end
    put(inst, prop, value)
    local props = NR_Store[inst]
    if not props then props = {}; NR_Store[inst] = props end
    if props[prop] == nil then props[prop] = cur end
end

local function NR_RestoreAll()
    for inst, props in pairs(NR_Store) do
        if NR_Pinned[inst] or inst.Parent ~= nil then
            for prop, value in pairs(props) do
                local put = NR_HIDDEN[prop] and sethiddenproperty or NR_Put
                if put then put(inst, prop, value) end
            end
        end
    end
    table.clear(NR_Store)
end

local function NR_Prune()
    for inst in pairs(NR_Store) do
        if not NR_Pinned[inst] and inst.Parent == nil then NR_Store[inst] = nil end
    end
end

local function NR_Off(obj) NR_Set(obj, 'Enabled', false) end
local function NR_Hide(obj) NR_Set(obj, 'Transparency', 1) end
local function NR_OffAndClear(obj) NR_Set(obj, 'Enabled', false); obj:Clear() end

local NR_HANDLERS = {
    ParticleEmitter = function(obj) NR_Set(obj,'Lifetime',NR_ZERO_LIFETIME); NR_OffAndClear(obj) end,
    Trail=NR_OffAndClear,
    Beam=NR_Off,Smoke=NR_Off,Fire=NR_Off,Sparkles=NR_Off,
    Highlight=NR_Off,Clouds=NR_Off,
    PointLight=NR_Off,SpotLight=NR_Off,SurfaceLight=NR_Off,
    BloomEffect=NR_Off,BlurEffect=NR_Off,ColorCorrectionEffect=NR_Off,
    DepthOfFieldEffect=NR_Off,SunRaysEffect=NR_Off,ColorGradingEffect=NR_Off,
    Decal=NR_Hide,Texture=NR_Hide,
    Explosion=function(obj) NR_Set(obj,'Visible',false) end,
    Atmosphere=function(obj)
        NR_Set(obj,'Density',0); NR_Set(obj,'Haze',0); NR_Set(obj,'Glare',0)
    end,
    Sky=function(obj)
        NR_Set(obj,'CelestialBodiesShown',false); NR_Set(obj,'StarCount',0)
    end,
}

local function NR_Apply(obj)
    if NR_IsIgnored(obj) then return end
    if NR_IsProtected(obj) then return end
    local handler = NR_HANDLERS[obj.ClassName]
    if handler and not NR_IsGameplayAncestor(obj) then handler(obj) end
end

local function NR_ApplyLighting(prop)
    NR_Set(Lighting, prop, NR_LIGHTING[prop])
    local ok, now = true, NR_Get(Lighting, prop)
    if ok then NR_LightingSeen[prop] = now end
end

local function NR_OptimizeWorld()
    for prop in pairs(NR_LIGHTING) do NR_ApplyLighting(prop) end
    for _, c in ipairs(Lighting:GetChildren()) do NR_Apply(c) end
    NR_Set(NR_Terrain,'Decoration',false)
    NR_Set(NR_Terrain,'WaterWaveSize',0)
    NR_Set(NR_Terrain,'WaterWaveSpeed',0)
    NR_Set(NR_Terrain,'WaterReflectance',0)
    NR_Set(NR_Terrain,'WaterTransparency',1)
    if NR_Render then NR_Set(NR_Render,'QualityLevel',Enum.QualityLevel.Level01) end
end

local function NR_OnLightingChanged(prop)
    if NR_LIGHTING[prop] == nil then return end
    local ok, now = true, NR_Get(Lighting, prop)
    if not ok or now == NR_LightingSeen[prop] then return end
    local props = NR_Store[Lighting]
    if props then props[prop] = now end
    NR_ApplyLighting(prop)
end

local function NR_ClearRuntime(v)
    local name = v.Name
    if name:find('PortalFor_',1,true) or name:find('WaypointFor_',1,true) then return end
    if NR_IsProtected(v) then return end
    Debris:AddItem(v, 0)
end

local NR_FloorParts = {}

local function NR_FindFloor()
    table.clear(NR_FloorParts)
    local Map = workspace:FindFirstChild('Map')
    if not Map then return false end
    local found = false
    for _, v in ipairs(Map:GetDescendants()) do
        if v:IsA('BasePart') and (v.Name == 'FLOOR' or v.Name == 'INVISIBLE_FLOOR') then
            NR_FloorParts[v] = true
            found = true
        end
    end
    return found
end

local function NR_RescanFloorAndUnhide()
    if not NR_Enabled then return end
    table.clear(NR_FloorParts)
    local Map = workspace:FindFirstChild('Map')
    if Map then
        for _, v in ipairs(Map:GetDescendants()) do
            if v:IsA('BasePart') and (v.Name == 'FLOOR' or v.Name == 'INVISIBLE_FLOOR') then
                NR_FloorParts[v] = true
                if NR_HiddenParts[v] ~= nil then
                    v.Transparency = NR_HiddenParts[v]
                    NR_HiddenParts[v] = nil
                end
            end
        end
    end
    for part in pairs(NR_HiddenParts) do
        if part and part.Parent == nil then NR_HiddenParts[part] = nil end
    end
end

local NR_FloorScanToken = 0

local function NR_WatchMapForFloor()
    NR_FloorScanToken += 1
    local token = NR_FloorScanToken
    task.spawn(function()
        for _ = 1, 60 do
            if token ~= NR_FloorScanToken or not NR_Enabled then return end
            if NR_FindFloor() then
                NR_RescanFloorAndUnhide()
                return
            end
            task.wait(0.1)
        end
        if token == NR_FloorScanToken and NR_Enabled then NR_RescanFloorAndUnhide() end
    end)
end

local function NR_HideMapPart(part)
    if not part:IsA('BasePart') then return end
    if NR_IsGameplayAncestor(part) then return end
    if NR_IsProtected(part) then return end
    if part.Name == 'FLOOR' or part.Name == 'INVISIBLE_FLOOR' then
        NR_FloorParts[part] = true
        return
    end
    if NR_FloorParts[part] then return end
    if NR_HiddenParts[part] ~= nil then return end
    if part.Parent == workspace and NR_DIRECT_WORKSPACE_PARTS[part.Name] then
        NR_HiddenParts[part] = part.Transparency
        part.Transparency = 1
        return
    end
    if not NR_IsMapDescendant(part) then return end
    NR_HiddenParts[part] = part.Transparency
    part.Transparency = 1
end

local function NR_RestoreMapParts()
    for part, t in pairs(NR_HiddenParts) do
        if part and part.Parent then part.Transparency = t end
    end
    table.clear(NR_HiddenParts)
end

local function NR_HideMapGui(obj)
    if not (obj:IsA('BillboardGui') or obj:IsA('SurfaceGui') or obj:IsA('SelectionBox')) then return end
    if NR_IsGameplayAncestor(obj) or NR_IsIgnored(obj) then return end
    if NR_IsProtected(obj) then return end
    if NR_HiddenGuis2[obj] ~= nil then return end
    NR_HiddenGuis2[obj] = obj.Enabled
    obj.Enabled = false
end

local function NR_RestoreMapGuis()
    for obj, enabled in pairs(NR_HiddenGuis2) do
        if obj and obj.Parent then obj.Enabled = enabled end
    end
    table.clear(NR_HiddenGuis2)
end

local function NR_HideLobbyGuis()
    local PlayerGui = LP:FindFirstChild('PlayerGui')
    if not PlayerGui then return end
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if NR_LOBBY_GUI_NAMES[gui.Name] and gui:IsA('ScreenGui') and gui.Enabled then
            NR_HiddenGuis[gui] = true
            gui.Enabled = false
        end
    end
end

local function NR_RestoreLobbyGuis()
    for gui in pairs(NR_HiddenGuis) do
        if gui and gui.Parent then gui.Enabled = true end
    end
    table.clear(NR_HiddenGuis)
end

local NR_LOBBY_FOLDERS = {
    Spawn = true, Leaderboards = true, LobbySpawnPlate = true,
    Drones = true, ZombieCrownClash = true, PixelKillEvent = true,
    SummerEventBB = true, FriendCrate = true,
}

local NR_LobbyDestroyed = {}
local NR_InMatch = false

local function NR_IsInMatch()
    local char = LP.Character
    if not char or not char.Parent then return false end
    if AliveFolder then return char.Parent == AliveFolder end
    return false
end

local function NR_DestroyLobby()
    for _, v in ipairs(workspace:GetChildren()) do
        if NR_LOBBY_FOLDERS[v.Name] and not v:GetAttribute("NR_LobbyDestroyed") then
            v:SetAttribute("NR_LobbyDestroyed", true)
            NR_LobbyDestroyed[#NR_LobbyDestroyed + 1] = v
            v.Parent = nil
        end
    end
end

local function NR_RestoreLobby()
    for _, v in ipairs(NR_LobbyDestroyed) do
        if v then
            local ok, isDestroyed = pcall(function() return v:GetAttribute("NR_LobbyDestroyed") end)
            if ok and isDestroyed then
                pcall(function()
                    v:SetAttribute("NR_LobbyDestroyed", nil)
                    v.Parent = workspace
                end)
            end
        end
    end
    table.clear(NR_LobbyDestroyed)
end

local function NR_CheckMatchState()
    if not NR_Enabled then return end
    local inMatch = NR_IsInMatch()
    if inMatch and not NR_InMatch then
        NR_InMatch = true
        NR_DestroyLobby()
    elseif not inMatch and NR_InMatch then
        NR_InMatch = false
        NR_RestoreLobby()
    end
end

local function NR_IsGraySkyOn()
    local ok, result = pcall(function()
        return LP.PlayerGui.Settings.Frame.Frame['Misc/Gray Sky'].Button.TextLabel.Text == 'Active'
    end)
    return ok and result
end

local function NR_ApplyGraySky()
    if not NR_IsGraySkyOn() then return end
    Lighting.Ambient = Color3.fromRGB(70,70,70)
    Lighting.OutdoorAmbient = Color3.fromRGB(70,70,70)
    Lighting.Brightness = 1
    Lighting.ClockTime = 12
    Lighting.FogStart = math.huge
    Lighting.FogEnd = math.huge
    for _, c in ipairs(Lighting:GetChildren()) do
        if c:IsA('Sky') then
            c.CelestialBodiesShown = true
            c.StarCount = 3000
        elseif c:IsA('Atmosphere') then
            c.Density = 0; c.Haze = 0; c.Glare = 0
        elseif c:IsA('BloomEffect') or c:IsA('BlurEffect')
            or c:IsA('ColorCorrectionEffect') or c:IsA('SunRaysEffect')
            or c:IsA('DepthOfFieldEffect') then
            c.Enabled = false
        end
    end
end

local function NR_ProcessObj(v)
    if NR_IsIgnored(v) then return end
    if NR_IsProtected(v) then return end
    if v:IsA("BillboardGui") and v.Name == "SOF_ComboCounter" then return end
    NR_Apply(v)
    NR_HideMapPart(v)
    NR_HideMapGui(v)
end

local function NR_Enable()
    if NR_Enabled then return end
    NR_Enabled = true
    NR_Gen += 1
    local gen = NR_Gen
    local NR_DescQueue, NR_DescIdx = {}, 0
    local NR_MatchCheckAt, NR_GraySkyAt = 0, 0

    NR_OptimizeWorld()
    NR_HideLobbyGuis()
    NR_ApplyGraySky()
    NR_FindFloor()

    local Map = workspace:FindFirstChild('Map')
    if Map then
        Connections_Manager['NR_MapChanged'] = Map.ChildAdded:Connect(function(child)
            if not NR_Enabled then return end
            if not child:IsA('Model') then return end
            task.defer(NR_WatchMapForFloor)
        end)
        Connections_Manager['NR_MapRemoved'] = Map.ChildRemoved:Connect(function(child)
            if not NR_Enabled then return end
            if not child:IsA('Model') then return end
            task.defer(NR_RescanFloorAndUnhide)
        end)
    end

    Connections_Manager['NR_GraySkyForce'] = Lighting.Changed:Connect(function()
        if not NR_Enabled then return end
        local now = os.clock()
        if now - NR_GraySkyAt < 0.25 then return end
        NR_GraySkyAt = now
        task.defer(NR_ApplyGraySky)
    end)
    Connections_Manager['NR_GuiAdded'] = LP.PlayerGui.ChildAdded:Connect(function(gui)
        if not NR_Enabled then return end
        if NR_LOBBY_GUI_NAMES[gui.Name] and gui:IsA('ScreenGui') and gui.Enabled then
            NR_HiddenGuis[gui] = true
            gui.Enabled = false
        end
    end)
    Connections_Manager['NR_Descendant'] = workspace.DescendantAdded:Connect(function(v)
        NR_DescQueue[#NR_DescQueue + 1] = v
    end)
    Connections_Manager['NR_DescDrain'] = RunService.Heartbeat:Connect(function()
        if NR_DescIdx >= #NR_DescQueue then
            if #NR_DescQueue > 0 then
                table.clear(NR_DescQueue)
                NR_DescIdx = 0
            end
            return
        end
        local deadline = os.clock() + 0.003
        while NR_DescIdx < #NR_DescQueue and os.clock() < deadline do
            NR_DescIdx += 1
            local v = NR_DescQueue[NR_DescIdx]
            if v and v.Parent then pcall(NR_ProcessObj, v) end
        end
        if NR_DescIdx >= #NR_DescQueue then
            table.clear(NR_DescQueue)
            NR_DescIdx = 0
        end
    end)
    Connections_Manager['NR_LightingChild'] = Lighting.ChildAdded:Connect(NR_Apply)
    Connections_Manager['NR_LightingProp'] = Lighting.Changed:Connect(NR_OnLightingChanged)
    if RuntimeFolder then
        Connections_Manager['NR_Runtime'] = RuntimeFolder.ChildAdded:Connect(NR_ClearRuntime)
        for _, v in ipairs(RuntimeFolder:GetChildren()) do NR_ClearRuntime(v) end
    end
    Connections_Manager['NR_MatchCheck'] = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - NR_MatchCheckAt < 0.5 then return end
        NR_MatchCheckAt = now
        NR_CheckMatchState()
    end)

    task.spawn(function()
        local list = workspace:GetDescendants()
        local deadline = os.clock() + 0.004
        for i = 1, #list do
            if NR_Gen ~= gen then return end
            NR_ProcessObj(list[i])
            if i % 64 == 0 and os.clock() > deadline then
                task.wait()
                deadline = os.clock() + 0.004
            end
        end
        list = nil
        task.spawn(function()
            for _ = 1, 20 do
                if NR_Gen ~= gen then return end
                NR_RescanFloorAndUnhide()
                task.wait(0.25)
            end
        end)
        while NR_Gen == gen do
            task.wait(10)
            NR_Prune()
        end
    end)
end

local function NR_Disable()
    if not NR_Enabled then return end
    NR_Enabled = false
    NR_Gen += 1
    for _, key in ipairs(NR_CONNECTIONS) do
        local conn = Connections_Manager[key]
        if conn then conn:Disconnect(); Connections_Manager[key] = nil end
    end
    NR_RestoreAll()
    NR_RestoreLobbyGuis()
    NR_RestoreLobby()
    NR_RestoreMapParts()
    NR_RestoreMapGuis()
    NR_InMatch = false
    table.clear(NR_FloorParts)
    table.clear(NR_LightingSeen)
end

local PerfMode_Enabled = false
local PerfMode_Conns = {}

local function PerfMode_Apply(obj)
    if not PerfMode_Enabled then return end
    local cls = obj.ClassName
    if cls == 'Atmosphere' then
        pcall(function() obj.Density = 0; obj.Haze = 0; obj.Glare = 0 end)
    elseif cls == 'Clouds' or cls == 'BloomEffect' or cls == 'BlurEffect'
        or cls == 'DepthOfFieldEffect' or cls == 'SunRaysEffect'
        or cls == 'ColorCorrectionEffect' or cls == 'ColorGradingEffect' then
        pcall(function() obj.Enabled = false end)
    end
end

local function PerfMode_Start()
    if PerfMode_Enabled then return end
    PerfMode_Enabled = true
    pcall(function()
        local render = settings().Rendering
        render.QualityLevel = Enum.QualityLevel.Level01
    end)
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    end)
    pcall(function()
        workspace.Terrain.WaterWaveSize = 0
        workspace.Terrain.WaterWaveSpeed = 0
        workspace.Terrain.WaterReflectance = 0
    end)
    for _, c in ipairs(Lighting:GetChildren()) do PerfMode_Apply(c) end
    for _, c in ipairs(workspace.Terrain:GetChildren()) do PerfMode_Apply(c) end
    if workspace.CurrentCamera then
        for _, c in ipairs(workspace.CurrentCamera:GetChildren()) do PerfMode_Apply(c) end
    end
    PerfMode_Conns[#PerfMode_Conns + 1] = Lighting.ChildAdded:Connect(PerfMode_Apply)
end

local function PerfMode_Stop()
    PerfMode_Enabled = false
    for _, c in ipairs(PerfMode_Conns) do pcall(function() c:Disconnect() end) end
    table.clear(PerfMode_Conns)
end

local PerfGroup = Main:AddRightGroupbox("Performance", "gauge")

PerfGroup:AddToggle("Watermark", {
    Text = "Watermark",
    Default = true,
    Callback = function(state)
        local g = CreateWatermark()
        if g then g.Enabled = state end
    end,
})

PerfGroup:AddToggle("NoRender", {
    Text = "No Render",
    Default = false,
    Tooltip = "Disables all effects, post-processing and lighting detail. Your character and weapons are kept visible.",
    Callback = function(state)
        if state then NR_Enable() else NR_Disable() end
    end,
})

PerfGroup:AddToggle("PerformanceMode", {
    Text = "Performance Mode",
    Default = false,
    Tooltip = "Lowers render quality, disables shadows and post-processing",
    Callback = function(state)
        if state then PerfMode_Start() else PerfMode_Stop() end
    end,
})

local function namecall_hook()
    local mt = getrawmetatable(game)
    local old = mt.__namecall
    setreadonly(mt, false)
    local hooked
    hooked = newcclosure(function(self, ...)
        if getnamecallmethod() == "UserOwnsGamePassAsync" and S.gp then
            return true
        end
        return old(self, ...)
    end)
    mt.__namecall = hooked
    setreadonly(mt, true)
    return function()
        setreadonly(mt, false)
        if mt.__namecall == hooked then
            mt.__namecall = old
        end
        setreadonly(mt, true)
    end
end

local function teardown()
    tearing = true
    _ScriptUnloaded = true
    NR_Disable()
    PerfMode_Stop()
    if WatermarkGui then
        WatermarkGui:Destroy()
        WatermarkGui = nil
    end
    apply_sb(false)
    apply_gp(false)
    if Library.Toggles and Library.Toggles.AllGamepasses then
        Library.Toggles.AllGamepasses:SetValue(false)
    end
    if Library.Toggles and Library.Toggles.SandboxMode then
        Library.Toggles.SandboxMode:SetValue(false)
    end
    for _, conn in pairs(Connections_Manager) do
        if typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        elseif type(conn) == "table" then
            for _, c in pairs(conn) do
                if typeof(c) == "RBXScriptConnection" then
                    pcall(function() c:Disconnect() end)
                end
            end
        end
    end
    table.clear(Connections_Manager)
    rawset(getgenv and getgenv() or _G, "Byte_SHOOTER", nil)
end

namecall_hook()

ThemeManager:SetLibrary(Window)
SaveManager:SetLibrary(Window)
ThemeManager:SetFolder("Byte/Shooter")
SaveManager:SetFolder("Byte/Shooter")
SaveManager:BuildConfigSection(Settings)
ThemeManager:ApplyToTab(Settings)
ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()

CreateWatermark()

if workspace:GetAttribute("ANON_GP") == true then
    Library.Toggles.AllGamepasses:SetValue(true)
end
if workspace:GetAttribute("ANON_SB") == true then
    Library.Toggles.SandboxMode:SetValue(true)
end

rawset(getgenv and getgenv() or _G, "Byte_SHOOTER", {
    state = S,
    set_gp = function(on)
        Library.Toggles.AllGamepasses:SetValue(on == true)
    end,
    set_sb = function(on)
        Library.Toggles.SandboxMode:SetValue(on == true)
    end,
    set_no_render = function(on)
        Library.Toggles.NoRender:SetValue(on == true)
    end,
    set_perf_mode = function(on)
        Library.Toggles.PerformanceMode:SetValue(on == true)
    end,
    pass = function()
        return pass
    end,
    teardown = teardown,
})
