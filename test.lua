local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"

local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Players               = game:GetService("Players")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local RunService            = game:GetService("RunService")
local UserInputService      = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Lighting              = game:GetService("Lighting")
local Workspace             = game:GetService("Workspace")
local VirtualUser           = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

local Window = Library:CreateWindow({
    Title    = "Junkyard",
    Layout   = "Bottom bar",
    MenuKey  = Enum.KeyCode.RightShift,
    Size     = Vector2.new(720, 500),
})

local Tabs = {
    Info     = Window:AddTab("Info", "info"),
    Main     = Window:AddTab("Main", "gamepad-2"),
    Visuals  = Window:AddTab("Visuals", "eye"),
    Player   = Window:AddTab("Player", "person-standing"),
    Settings = Window:CreateSettingsTab(),
}

local S = {
    WalkSpeedOn = false, WalkSpeedValue = 32,
    InfJumpOn = false,
    NoClipOn = false,
    FlyOn = false, FlySpeed = 60,
    InstantPPOn = false,
    AntiAfkOn = false,
    FpsBoostOn = false,
    TrashEspOn = false,
    AutoClaimCompress = false,
    AutoClaimSmelt = false,
    AutoUpgradePlot = false,
}
local Alive = true
local Conn = {}
local function track(c) table.insert(Conn, c); return c end

local Snap = { Inst = {}, Fps = {}, Esp = {} }
local function getHum()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local InfoUser = Tabs.Info:AddLeftGroupbox("User", "circle-user")
InfoUser:AddLabel("DisplayName: " .. LocalPlayer.DisplayName)
InfoUser:AddLabel("Username: @" .. LocalPlayer.Name)
InfoUser:AddLabel("UserId: " .. tostring(LocalPlayer.UserId))

local execName = "Unknown"
if identifyexecutor then
    local ok, n = pcall(identifyexecutor)
    if ok and n then execName = tostring(n) end
end
InfoUser:AddLabel("Executor: " .. execName)

local function clip(s)
    if setclipboard then setclipboard(s)
    elseif toclipboard then toclipboard(s) end
end
InfoUser:AddButton({ Text = "Copy Username",
    Callback = function() clip(LocalPlayer.Name) end })
InfoUser:AddButton({ Text = "Copy Profile Link",
    Callback = function()
        clip("https://www.roblox.com/users/" .. tostring(LocalPlayer.UserId) .. "/profile")
    end })

local InfoSess = Tabs.Info:AddRightGroupbox("Session", "signal")
local L_Sess    = InfoSess:AddLabel("Session: 0s")
local L_Players = InfoSess:AddLabel("Players: 0/0")
local L_Ping    = InfoSess:AddLabel("Ping: -- ms")
InfoSess:AddLabel("JobId: " .. string.sub(tostring(game.JobId), 1, 20) .. "...")
InfoSess:AddButton({ Text = "Rejoin Place",
    Callback = function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
    end })
InfoSess:AddButton({ Text = "Copy JobId",
    Callback = function() clip(game.JobId) end })

local startClock = os.clock()
task.spawn(function()
    while Alive do
        task.wait(1)
        local secs = math.floor(os.clock() - startClock)
        L_Sess.Text = ("Session: %02d:%02d:%02d"):format(
            math.floor(secs/3600), math.floor(secs%3600/60), secs%60)
        L_Players.Text = ("Players: %d/%d"):format(#Players:GetPlayers(), Players.MaxPlayers)
        local ok, ping = pcall(function()
            return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        L_Ping.Text = "Ping: " .. (ok and (ping .. " ms") or "n/a")
    end
end)

local StatGrp = Tabs.Main:AddRightGroupbox("Player", "activity")
local L_Cash   = StatGrp:AddLabel("Cash: $0")
local L_Plot   = StatGrp:AddLabel("Plot: 0/0")
local L_Weight = StatGrp:AddLabel("Weight: 0/0 kg")
local L_Income = StatGrp:AddLabel("Income: $0/s")

local function refreshStats()
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    local Cash = ls and ls:FindFirstChild("Cash")
    L_Cash.Text   = ("Cash: $%d"):format(Cash and Cash.Value or 0)
    L_Plot.Text   = ("Plot: %d/%d"):format(
        LocalPlayer:GetAttribute("PlotPlacedCount") or 0,
        LocalPlayer:GetAttribute("PlotCapacity") or 0)
    L_Weight.Text = ("Weight: %s/%s kg"):format(
        tostring(LocalPlayer:GetAttribute("CurrentWeightKg") or 0),
        tostring(LocalPlayer:GetAttribute("MaxWeightKg") or 0))
    L_Income.Text = ("Income: $%d/s"):format(LocalPlayer:GetAttribute("PlotIncomePerSecond") or 0)
end
for _, a in ipairs({"PlotPlacedCount","PlotCapacity","CurrentWeightKg","MaxWeightKg","PlotIncomePerSecond","PlotUpgradeLevel"}) do
    track(LocalPlayer:GetAttributeChangedSignal(a):Connect(refreshStats))
end
task.spawn(function()
    local ls = LocalPlayer:WaitForChild("leaderstats", 30)
    local Cash = ls and ls:WaitForChild("Cash", 30)
    if Cash then
        track(Cash:GetPropertyChangedSignal("Value"):Connect(refreshStats))
    end
    refreshStats()
end)

local compressorRemote = ReplicatedStorage:WaitForChild("TrashCompressorRemote", 10)
if compressorRemote then
    track(compressorRemote.OnClientEvent:Connect(function(kind, data)
        if not S.AutoClaimCompress then return end
        if kind == "Update" and type(data) == "table" and data.ClaimReady == true then
            pcall(function() compressorRemote:FireServer("Claim") end)
        end
    end))
end
Tabs.Main:AddLeftGroupbox("Compressor", "zap"):AddToggle("AutoClaimCompress", {
    Text = "Auto-claim compressor",
    Default = false,
    Tooltip = "Fires the same 'Claim' the UI fires when ClaimReady is true",
    Callback = function(v) S.AutoClaimCompress = v end,
})

-- Auto-claim smelter
local smelterRemote = ReplicatedStorage:WaitForChild("MeltingMachineRemote", 10)
if smelterRemote then
    track(smelterRemote.OnClientEvent:Connect(function(kind, data)
        if not S.AutoClaimSmelt then return end
        if kind == "Update" and type(data) == "table" and data.ClaimReady == true then
            pcall(function() smelterRemote:FireServer("Claim") end)
        end
    end))
end
Tabs.Main:AddRightGroupbox("Smelter", "flame"):AddToggle("AutoClaimSmelt", {
    Text = "Auto-claim smelter",
    Default = false,
    Callback = function(v) S.AutoClaimSmelt = v end,
})

local UpgradePlotRequest = ReplicatedStorage:FindFirstChild("UpgradePlotRequest")
if not UpgradePlotRequest then
    task.spawn(function()
        UpgradePlotRequest = ReplicatedStorage:WaitForChild("UpgradePlotRequest", 30)
    end)
end
local PlotGrp = Tabs.Main:AddLeftGroupbox("Plot", "house")
PlotGrp:AddButton({
    Text = "Upgrade Plot Now",
    Callback = function()
        if UpgradePlotRequest and UpgradePlotRequest:IsA("RemoteEvent") then
            UpgradePlotRequest:FireServer()
        end
    end,
})
PlotGrp:AddToggle("AutoUpgradePlot", {
    Text = "Auto-upgrade (when affordable)",
    Default = false,
    Tooltip = "Checks PlotNextUpgradeCost every 2s",
    Callback = function(v) S.AutoUpgradePlot = v end,
})
task.spawn(function()
    while Alive do
        task.wait(2)
        if S.AutoUpgradePlot and UpgradePlotRequest and UpgradePlotRequest:IsA("RemoteEvent") then
            local ls = LocalPlayer:FindFirstChild("leaderstats")
            local Cash = ls and ls:FindFirstChild("Cash")
            local cost = tonumber(LocalPlayer:GetAttribute("PlotNextUpgradeCost"))
            if Cash and cost and Cash.Value >= cost then
                pcall(function() UpgradePlotRequest:FireServer() end)
            end
        end
    end
end)

local Actions = Tabs.Main:AddRightGroupbox("Quick Actions", "rabbit")
Actions:AddButton({
    Text = "Open Shop",
    Callback = function()
        local req = ReplicatedStorage:FindFirstChild("OpenCashShopRequest")
        if req and req:IsA("BindableEvent") then req:Fire("CONTAINERS") end
    end,
})
Actions:AddButton({
    Text = "Toggle Freecam",
    Callback = function()
        local req = ReplicatedStorage:FindFirstChild("FreecamRemote")
        if req and req:IsA("RemoteEvent") then req:FireServer("Toggle") end
    end,
})
Actions:AddButton({
    Text = "Teleport to Base",
    Callback = function()
        local req = ReplicatedStorage:FindFirstChild("TeleportMenuRequest")
        if req and req:IsA("RemoteEvent") then req:FireServer("Base") end
    end,
})

local rarityColors = {
    Common = Color3.fromRGB(200,200,200), Uncommon = Color3.fromRGB(85,170,85),
    Rare = Color3.fromRGB(80,150,255),   Epic = Color3.fromRGB(170,85,255),
    Legendary = Color3.fromRGB(255,170,0), Mythic = Color3.fromRGB(255,70,70),
    Secret = Color3.fromRGB(255,55,55),
}
local trashFolders = {"SpawnedTrash", "DroppedTrash"}

local function trashRarity(o)
    for _, k in ipairs({"Rarity","TrashRarity","ItemRarity"}) do
        local v = o:GetAttribute(k)
        if typeof(v) == "string" and v ~= "" then return v end
    end
    return "Common"
end
local function isTrash(o)
    if not o or not o.Parent then return false end
    for _, n in ipairs(trashFolders) do
        if o.Parent.Name == n then return true end
    end
    return false
end
local function makeESP(o)
    if not isTrash(o) then return end
    if Snap.Esp[o] and Snap.Esp[o].Parent then return end
    local c = rarityColors[trashRarity(o)] or rarityColors.Common
    local h = Instance.new("Highlight")
    h.Name = "Viz_TrashESP"
    h.Adornee = o
    h.FillColor = c
    h.FillTransparency = 0.65
    h.OutlineColor = c
    h.OutlineTransparency = 0
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = Workspace
    Snap.Esp[o] = h
end
local function clearESP()
    for _, h in pairs(Snap.Esp) do
        if h.Parent then h:Destroy() end
    end
    table.clear(Snap.Esp)
end

Tabs.Visuals:AddLeftGroupbox("Trash ESP", "eye"):AddToggle("TrashEsp", {
    Text = "Highlight world trash",
    Default = false,
    Tooltip = "Purely visual. Colors follow Rarity attribute.",
    Callback = function(on)
        S.TrashEspOn = on
        if not on then clearESP(); return end
        task.spawn(function()
            while S.TrashEspOn do
                for _, n in ipairs(trashFolders) do
                    local f = Workspace:FindFirstChild(n)
                    if f then
                        for _, t in ipairs(f:GetChildren()) do makeESP(t) end
                    end
                end
                for o, h in pairs(Snap.Esp) do
                    if not isTrash(o) then
                        if h.Parent then h:Destroy() end
                        Snap.Esp[o] = nil
                    end
                end
                task.wait(0.5)
            end
        end)
    end,
})

local defMaxPrompts = ProximityPromptService.MaxPromptsVisible
Tabs.Visuals:AddRightGroupbox("Prompts", "hand"):AddToggle("RaisePromptLimit", {
    Text = "Raise prompt limit (16 → 100)",
    Default = false,
    Callback = function(on)
        ProximityPromptService.MaxPromptsVisible = on and 100 or defMaxPrompts
    end,
})

local Move = Tabs.Player:AddLeftGroupbox("Movement", "person-standing")
Move:AddToggle("WalkSpeedEnabled", {
    Text = "WalkSpeed",
    Default = false,
    Callback = function(on)
        S.WalkSpeedOn = on
        if on then
            task.spawn(function()
                while S.WalkSpeedOn do
                    local h = getHum()
                    if h then h.WalkSpeed = S.WalkSpeedValue end
                    task.wait(0.1)
                end
            end)
        else
            local h = getHum()
            if h then h.WalkSpeed = 16 end
        end
    end,
})
Move:AddSlider("WalkSpeedValue", {
    Text = "WalkSpeed amount",
    Min = 16, Max = 250, Default = 32, Rounding = 0,
    Callback = function(v)
        S.WalkSpeedValue = v
        if S.WalkSpeedOn then
            local h = getHum()
            if h then h.WalkSpeed = v end
        end
    end,
})
Move:AddToggle("InfJump", {
    Text = "Infinite Jump",
    Default = false,
    Callback = function(v) S.InfJumpOn = v end,
})
track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Space and S.InfJumpOn then
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))
Move:AddToggle("NoClip", {
    Text = "NoClip",
    Default = false,
    Callback = function(on)
        S.NoClipOn = on
        if on then
            task.spawn(function()
                while S.NoClipOn do
                    local c = LocalPlayer.Character
                    if c then
                        for _, p in ipairs(c:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide = false end
                        end
                    end
                    task.wait(0.1)
                end
                local c = LocalPlayer.Character
                if c then
                    for _, p in ipairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = true end
                    end
                end
            end)
        end
    end,
})

local FlyGrp = Tabs.Player:AddRightGroupbox("Fly", "plane")
FlyGrp:AddToggle("Fly", {
    Text = "Fly",
    Default = false,
    Callback = function(on)
        S.FlyOn = on
        if not on then
            local hrp = getHRP()
            if hrp then hrp.AssemblyLinearVelocity = Vector3.zero end
            return
        end
        task.spawn(function()
            while S.FlyOn do
                local hrp = getHRP()
                local cam = Workspace.CurrentCamera
                if hrp and cam and not UserInputService:GetFocusedTextBox() then
                    local dir = Vector3.zero
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
                    hrp.AssemblyLinearVelocity = dir.Magnitude > 0 and dir.Unit * S.FlySpeed or Vector3.zero
                end
                task.wait()
            end
        end)
    end,
})
FlyGrp:AddSlider("FlySpeed", {
    Text = "Fly speed",
    Min = 10, Max = 400, Default = 60, Rounding = 0,
    Callback = function(v) S.FlySpeed = v end,
})

Tabs.Player:AddRightGroupbox("Prompts", "hand"):AddToggle("InstantPP", {
    Text = "Instant ProximityPrompt",
    Default = false,
    Tooltip = "Sets HoldDuration=0 on all prompts. Pickup still fires the hold events the server expects.",
    Callback = function(on)
        S.InstantPPOn = on
        if not on then
            for p, snap in pairs(Snap.Inst) do
                if p and p.Parent then
                    p.HoldDuration = snap.HoldDuration
                    p.MaxActivationDistance = snap.MaxActivationDistance
                    p.RequiresLineOfSight = snap.RequiresLineOfSight
                end
            end
            table.clear(Snap.Inst)
            return
        end
        local function apply(p)
            if not p:IsA("ProximityPrompt") then return end
            if Snap.Inst[p] == nil then
                Snap.Inst[p] = {
                    HoldDuration = p.HoldDuration,
                    MaxActivationDistance = p.MaxActivationDistance,
                    RequiresLineOfSight = p.RequiresLineOfSight,
                }
            end
            p.HoldDuration = 0
            p.RequiresLineOfSight = false
        end
        for _, d in ipairs(Workspace:GetDescendants()) do apply(d) end
        track(Workspace.DescendantAdded:Connect(function(d)
            if S.InstantPPOn then apply(d) end
        end))
    end,
})


local MenuGrp = Tabs.Settings:AddLeftGroupbox("Menu", "settings")
MenuGrp:AddToggle("AntiAfk", {
    Text = "Anti-AFK",
    Default = false,
    Callback = function(v) S.AntiAfkOn = v end,
})
track(LocalPlayer.Idled:Connect(function()
    if not S.AntiAfkOn then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))

MenuGrp:AddToggle("FpsBoost", {
    Text = "FPS Boost",
    Default = false,
    Tooltip = "Hides particles, trails, beams, fire, smoke, sparkles and shadows",
    Callback = function(on)
        S.FpsBoostOn = on
        local function strip(o)
            if not (o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam")
                or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles")) then return end
            if Snap.Fps[o] then return end
            Snap.Fps[o] = { Enabled = o.Enabled }
            o.Enabled = false
        end
        if not on then
            for o, snap in pairs(Snap.Fps) do
                if o and o.Parent then o.Enabled = snap.Enabled end
            end
            table.clear(Snap.Fps)
            return
        end
        for _, d in ipairs(Workspace:GetDescendants()) do strip(d) end
        if Snap.Fps[Lighting] == nil then
            Snap.Fps[Lighting] = { GlobalShadows = Lighting.GlobalShadows }
            Lighting.GlobalShadows = false
        end
        track(Workspace.DescendantAdded:Connect(function(d)
            if S.FpsBoostOn then strip(d) end
        end))
    end,
})

MenuGrp:AddToggle("Disable3D", {
    Text = "Disable 3D Rendering",
    Default = false,
    Tooltip = "Needs executor with Set3dRenderingEnabled support",
    Callback = function(on)
        pcall(function() RunService:Set3dRenderingEnabled(not on) end)
    end,
})

local CfgGrp = Tabs.Settings:AddLeftGroupbox("Script", "save")
CfgGrp:AddButton({
    Text = "Unload Script",
    Callback = function()
        Alive = false
        S.WalkSpeedOn = false; S.NoClipOn = false; S.FlyOn = false; S.TrashEspOn = false
        S.AutoClaimCompress = false; S.AutoClaimSmelt = false; S.AutoUpgradePlot = false
        S.AntiAfkOn = false; S.FpsBoostOn = false
        for _, c in ipairs(Conn) do pcall(function() c:Disconnect() end) end
        table.clear(Conn)
        clearESP()
        pcall(function() RunService:Set3dRenderingEnabled(true) end)
        local ok = pcall(function()
            if Library.Unload then Library:Unload() end
        end)
        if not ok then
            local sg = PlayerGui:FindFirstChild("Viz")
            if sg then sg:Destroy() end
        end
    end,
})

ThemeManager:SetLibrary(Window)
SaveManager:SetLibrary(Window)
ThemeManager:SetFolder("JunkyardHub")
SaveManager:SetFolder("JunkyardHub")

SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
