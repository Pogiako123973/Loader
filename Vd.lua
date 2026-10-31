repeat task.wait() until game:IsLoaded()

local Connections_Manager = {}
local UserInputService = game:GetService("UserInputService")
local Is_Mobile = UserInputService.TouchEnabled

local Players = game:GetService('Players')
local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild('PlayerGui')

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Remotes = ReplicatedStorage:WaitForChild('Remotes')

local Generator_Remote = Remotes:WaitForChild('Generator')
local Generator_Event = Generator_Remote:WaitForChild('SkillCheckEvent')
local Generator_Result = Generator_Remote:WaitForChild('SkillCheckResultEvent')

local Healing_Remote = Remotes:WaitForChild('Healing')
local Heal_Result = Healing_Remote:WaitForChild('SkillCheckResultEvent')
local Heal_Event = Remotes.Healing:WaitForChild('SkillCheckEvent')

local VirtualInputManager = game:GetService('VirtualInputManager')
local Byte = {}

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local HttpService = game:GetService("HttpService")
local Stats = game:GetService('Stats')
local Env = {}

local oldTweenCreate
oldTweenCreate = hookfunction(game:GetService("TweenService").Create, function(self, instance, tweenInfo, goals)
    if instance and instance.Name == "Line" and instance.Parent and instance.Parent.Name == "Check" and instance.Parent.Parent.Name == "SkillCheckPromptGui" then
        tweenInfo = TweenInfo.new(0.2, tweenInfo.EasingStyle, tweenInfo.EasingDirection, tweenInfo.RepeatCount, tweenInfo.Reverses, tweenInfo.DelayTime)
    end
    return oldTweenCreate(self, instance, tweenInfo, goals)
end)

local Character_ = Player.Character or Player.CharacterAdded:Wait()
local Humanoid_ = Character_:WaitForChild('Humanoid')

local Animator_ = Humanoid_:WaitForChild('Animator')
local Items_Remote = Remotes:WaitForChild('Items')
local Vaultbindable = Remotes.Window:WaitForChild("Vaultbindable")
local VaultEvent = Remotes.Window:WaitForChild("VaultEvent")
local ok_KB, KeybindsConfig = pcall(require, ReplicatedStorage.Modules.Survivors.KeybindsConfig)

local Parrying_Dagger_Event = Items_Remote:WaitForChild('Parrying Dagger')
local Parry_Remote = Parrying_Dagger_Event:WaitForChild('parry')

local Twist_of_Fate_Event = Items_Remote:WaitForChild('Twist of Fate')
local Fire_Remote = Twist_of_Fate_Event:WaitForChild('Fire')

local ThrowRemote = Items_Remote:FindFirstChild("Holy Water") and Items_Remote["Holy Water"]:FindFirstChild("Throw")
local RushRemote = Items_Remote:FindFirstChild("Riot Shield") and Items_Remote["Riot Shield"]:FindFirstChild("Rush")
local FlashlightActivate = Items_Remote:FindFirstChild("Flashlight") and Items_Remote.Flashlight:FindFirstChild("Activate")
local BandageFire = Items_Remote:FindFirstChild("Bandage") and Items_Remote.Bandage:FindFirstChild("Fire")
local AdrenalineShot = Items_Remote:FindFirstChild("Adrenaline Shot")
local UnHookEvent = Remotes.Carry:WaitForChild("UnHookEvent")
local SelfUnHookEvent = Remotes.Carry:WaitForChild("SelfUnHookEvent")
local HealEventRemote = Remotes.Healing:WaitForChild("HealEvent")

local Animation_Params = Instance.new('Animation')
Animation_Params.AnimationId = 'rbxassetid://109133187196613'

local Parry_Track = Animator_:LoadAnimation(Animation_Params)
Parry_Track.Priority = Enum.AnimationPriority.Action

local Game_Started = Remotes.Game.Start

local Attacks_Remote = Remotes:FindFirstChild("Attacks")
local Lunge_Remote = Attacks_Remote and Attacks_Remote:FindFirstChild("Lunge")
local BasicAttack_Remote = Attacks_Remote and Attacks_Remote:FindFirstChild("BasicAttack")
local Pallet_Remote = Remotes:FindFirstChild("Pallet")
local Jason_Remote = Pallet_Remote and Pallet_Remote:FindFirstChild("Jason")
local Stun_Remote = Jason_Remote and Jason_Remote:FindFirstChild("Stun")
local Stunover_Remote = Jason_Remote and Jason_Remote:FindFirstChild("Stunover")

if Game_Started then
    local sig = Game_Started.Event or Game_Started.OnClientEvent
    if sig then
        Connections_Manager['GameStart'] = sig:Connect(function()
            Animation_Params.AnimationId = 'rbxassetid://109133187196613'
            Parry_Track = Animator_:LoadAnimation(Animation_Params)
            Parry_Track.Priority = Enum.AnimationPriority.Action
        end)
    end
end

local Display_Names = {
    ["Motion Tracker"] = "Motion Tracker",
    ["Gate"] = "Gate",
    ["Flashlight"] = "Flashlight",
    ["Bandage"] = "Bandage",
    ["Parrying Dagger"] = "Parrying Dagger",
    ["Adrenaline Shot"] = "Adrenaline Shot",
    ["Shadow Clone"] = "Shadow Clone",
    ['Twist of Fate'] = 'Twist of Fate'
}

local State = {
    Unloaded = false,
    AutoParry = false,
    FastVault = false,
    FastSlide = false,
    InfSprint = false,
    AntiStun = false,
    FastRepair = false,
    AutoHeal = false,
    AutoUnhook = false,
    AutoSelfUnhook = false,
    AutoToF = false,
    AutoHolyWater = false,
    AutoRiot = false,
    AutoFlash = false,
    AutoAdren = false,
    AutoBandage = false,
    FastGenSkillCheck = false,
    InputDelayMS = 30,
    KillAura = false,
    SlashMode = "Rage",
    AuraRange = 500,
    SmartHitbox = false,
    AntiBlind = false,
    FreeTurn = false,
    NoParryCooldown = false,
    NoSlow = false,
    BypassGenPoint = false,
    NoFall = false,
    NoClip = false,
    InfiniteJump = false,
    Fullbright = false,
    AntiShake = false,
    NoFog = false,
    AntiAfk = false,
}

do
    local WatermarkGui = Instance.new('ScreenGui')
    WatermarkGui.Name = 'ByteWatermark'
    WatermarkGui.ResetOnSpawn = false
    WatermarkGui.IgnoreGuiInset = true
    WatermarkGui.DisplayOrder = 999
    WatermarkGui.Parent = (typeof(gethui) == 'function' and gethui()) or game:GetService('CoreGui')
    WatermarkGui.Enabled = true

    local Main = Instance.new('Frame')
    Main.Size = UDim2.fromOffset(0, 32)
    Main.AutomaticSize = Enum.AutomaticSize.X
    Main.Position = UDim2.new(0.5, 0, 0, 10)
    Main.AnchorPoint = Vector2.new(0.5, 0)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Main.BackgroundTransparency = 0.1
    Main.BorderSizePixel = 0
    Main.Parent = WatermarkGui

    local MainLayout = Instance.new('UIListLayout')
    MainLayout.FillDirection = Enum.FillDirection.Horizontal
    MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MainLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    MainLayout.Padding = UDim.new(0, 8)
    MainLayout.Parent = Main

    local MainPadding = Instance.new('UIPadding')
    MainPadding.PaddingLeft = UDim.new(0, 10)
    MainPadding.PaddingRight = UDim.new(0, 14)
    MainPadding.Parent = Main

    Instance.new('UICorner', Main).CornerRadius = UDim.new(0, 6)

    local Stroke = Instance.new('UIStroke')
    Stroke.Color = Color3.fromRGB(50, 50, 50)
    Stroke.Thickness = 1
    Stroke.Parent = Main

    local Logo = Instance.new('ImageLabel')
    Logo.Size = UDim2.fromOffset(20, 20)
    Logo.Position = UDim2.new(0, 8, 0.5, -10)
    Logo.BackgroundTransparency = 1
    Logo.Image = "rbxassetid://95943456246483"
    Logo.ScaleType = Enum.ScaleType.Fit
    Logo.Parent = Main

    local Name = Instance.new('TextLabel')
    Name.Size = UDim2.fromOffset(0, 32)
    Name.AutomaticSize = Enum.AutomaticSize.X
    Name.BackgroundTransparency = 1
    Name.Text = 'Byte'
    Name.TextColor3 = Color3.new(1,1,1)
    Name.TextSize = 14
    Name.Font = Enum.Font.GothamBold
    Name.TextXAlignment = Enum.TextXAlignment.Left
    Name.LayoutOrder = 2
    Name.Parent = Main

    local Info = Instance.new('TextLabel')
    Info.Size = UDim2.fromOffset(0, 32)
    Info.AutomaticSize = Enum.AutomaticSize.X
    Info.BackgroundTransparency = 1
    Info.TextColor3 = Color3.fromRGB(220, 220, 220)
    Info.TextSize = 13
    Info.Font = Enum.Font.Gotham
    Info.TextXAlignment = Enum.TextXAlignment.Left
    Info.LayoutOrder = 3
    Info.Parent = Main

    local frames, lastUpdate = 0, tick()
    local cachedRegion = "Loading..."

    task.spawn(function()
        local function FindServerText()
            local stats = game:GetService("Stats")
            if stats and stats.Network then
                local serverStats = stats.Network:FindFirstChild("ServerStatsItem")
                if serverStats then
                    local dataCenter = serverStats:FindFirstChild("Data Center Region")
                    if dataCenter and dataCenter:IsA("StringValue") then
                        return dataCenter.Value
                    end
                    local serverRegion = serverStats:FindFirstChild("Server Region")
                    if serverRegion and serverRegion:IsA("StringValue") then
                        return serverRegion.Value
                    end
                end
            end

            local coreGui = game:GetService("CoreGui")
            local devConsole = coreGui and coreGui:FindFirstChild("DevConsole")
            if devConsole then
                for _, desc in ipairs(devConsole:GetDescendants()) do
                    if desc:IsA("TextLabel") then
                        local match = string.match(desc.Text, "Server Region:%s*([%w%s]+)")
                        if match then return match end
                    end
                end
            end

            local function search(gui)
                if not gui then return nil end
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextLabel") or desc:IsA("TextButton") then
                        local match = string.match(desc.Text, "Server Region:%s*([%w%s]+)")
                        if match then return match end
                        match = string.match(desc.Text, "Region:%s*([%w%s]+)")
                        if match then return match end
                    end
                end
                return nil
            end

            local region = search(Players.LocalPlayer:FindFirstChild("PlayerGui"))
            if region then return region end
            region = search(coreGui)
            if region then return region end

            return "N/A"
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

            Info.Text = string.format("%s | %d FPS | %d MS | %s", os.date("%H:%M:%S"), math.floor(frames / (now - lastUpdate)), realPing, cachedRegion)

            frames = 0
            lastUpdate = now
        end
    end)

    local dragging, dragStart, startPos
    Connections_Manager['Watermark_DragStart'] = Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, Main.Position
        end
    end)
    Connections_Manager['Watermark_DragMove'] = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    Connections_Manager['Watermark_DragEnd'] = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    Env._WatermarkGui = WatermarkGui
end

local function EquipTool(name)
    local char = Player.Character
    local backpack = Player:FindFirstChild("Backpack")
    if not char or not char:FindFirstChild("Humanoid") then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find(name:lower()) then return t end
    end
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(name:lower()) then
                char.Humanoid:EquipTool(t)
                return t
            end
        end
    end
    return nil
end

function Byte.GetPart(Model)
    for _, Value in Model:GetDescendants() do
        if Value:IsA("BasePart") then return Value end
    end
    return nil
end

function Byte.Press()
    pcall(function()
        local survivorMob = PlayerGui:FindFirstChild("Survivor-mob")
        local controls    = survivorMob and survivorMob:FindFirstChild("Controls")
        local action      = controls and controls:FindFirstChild("action")
        if action then
            local c = action.AbsolutePosition + action.AbsoluteSize * 0.5
            VirtualInputManager:SendMouseButtonEvent(c.X, c.Y, 0, true,  game, 0)
            task.wait(0.01)
            VirtualInputManager:SendMouseButtonEvent(c.X, c.Y, 0, false, game, 0)
        end
    end)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.01)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
end

function Byte.Goal(Line, Goal)
    local Line_Angle = Line.Rotation % 360
    local Goal_Angle = Goal.Rotation % 360
    local Start_Angle = (Goal_Angle + 104) % 360
    local End_Angle  = (Goal_Angle + 114) % 360
    if Start_Angle > End_Angle then
        return Line_Angle >= Start_Angle or Line_Angle <= End_Angle
    else
        return Line_Angle >= Start_Angle and Line_Angle <= End_Angle
    end
end

function Byte.Get_GeneratorProgress(Generator)
    if not Generator then return 0 end
    local Generator_Progress = Generator:GetAttribute("RepairProgress")
    if typeof(Generator_Progress) ~= "number" then Generator_Progress = 0 end
    return math.clamp(Generator_Progress / 100, 0, 1)
end

function Byte.Get_ProgressColor(Percent)
    Percent = math.clamp(Percent, 0, 1)
    if Percent < 0.5 then
        local g = math.floor(Percent * 2 * 255)
        return Color3.fromRGB(255, g, 0)
    else
        local r = math.floor((1 - Percent) * 2 * 255)
        return Color3.fromRGB(r, 255, 0)
    end
end

function Byte.Is_Parry_Ready()
    local Survivor_Gui = PlayerGui:FindFirstChild('Survivor-mob') or PlayerGui:FindFirstChild('Survivor-con') or PlayerGui:FindFirstChild('Survivor')
    local Gen = Survivor_Gui and Survivor_Gui:FindFirstChild('Gen')
    local Item_Frame = Gen and Gen:FindFirstChild('ItemFrame')
    local Gui = Item_Frame and Item_Frame:FindFirstChild('Gui')
    local Bar = Gui and Gui:FindFirstChild('Bar')
    local UI_Gradient = Bar and Bar:FindFirstChild('UIGradient')
    return UI_Gradient ~= nil and UI_Gradient:IsA('UIGradient') and UI_Gradient.Offset.Y <= 0.25
end

function Byte.Play_Cooldown()
    local Survivor_Gui = PlayerGui:FindFirstChild('Survivor-mob') or PlayerGui:FindFirstChild('Survivor-con') or PlayerGui:FindFirstChild('Survivor')
    if Survivor_Gui then
        local Item_Frame = Survivor_Gui:FindFirstChild('Gen') and Survivor_Gui.Gen:FindFirstChild('ItemFrame')
        if Item_Frame and Item_Frame:FindFirstChild('Gui') then
            local Bar = Item_Frame.Gui:FindFirstChild('Bar')
            local UI_Gradient = Bar and Bar:FindFirstChild('UIGradient')
            local Parry_UI = Item_Frame:FindFirstChild('Gui')
            if Parry_UI then Parry_UI.ImageColor3 = Color3.fromRGB(77, 77, 77) end
            if UI_Gradient then
                UI_Gradient.Offset = Vector2.new(0, 0.75)
                local Tween = TweenService:Create(UI_Gradient, TweenInfo.new(50, Enum.EasingStyle.Linear), { Offset = Vector2.new(0, 0.25) })
                Tween:Play()
                Tween.Completed:Connect(function()
                    if UI_Gradient.Offset.Y <= 0.25 then
                        Parry_UI.ImageColor3 = Color3.fromRGB(255, 255, 255)
                    end
                end)
            end
        end
    end
end

function Byte.RotateTowardCamera()
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild('Humanoid')
    local PrimaryPart = Character:FindFirstChild("HumanoidRootPart")
    if not PrimaryPart then return end
    local look = workspace.CurrentCamera.CFrame.LookVector
    local Flat_look = Vector3.new(look.X, 0, look.Z)
    if Flat_look.Magnitude <= 0 then return end
    local Tween = TweenService:Create(PrimaryPart, TweenInfo.new(0.2, Enum.EasingStyle.Linear), {CFrame = CFrame.new(PrimaryPart.Position, PrimaryPart.Position + Flat_look.Unit)})
    Tween:Play()
    Tween.Completed:Connect(function()
        Humanoid.AutoRotate = true
        local Start = tick()
        Connections_Manager['Parry Animation'] = RunService.Heartbeat:Connect(function()
            if tick() - Start >= 0.8 then
                if Connections_Manager['Parry Animation'] then
                    Connections_Manager['Parry Animation']:Disconnect()
                    Connections_Manager['Parry Animation'] = nil
                end
                return
            end
            if PrimaryPart and PrimaryPart.Parent then
                PrimaryPart.CFrame = CFrame.new(PrimaryPart.Position, PrimaryPart.Position + Flat_look.Unit)
            else
                if Connections_Manager['Parry Animation'] then
                    Connections_Manager['Parry Animation']:Disconnect()
                    Connections_Manager['Parry Animation'] = nil
                end
            end
        end)
    end)
end

local ESP_Objects = {}
local ESP_Folder = Instance.new("Folder")
ESP_Folder.Name = "Byte_ESP"
ESP_Folder.Parent = game:GetService("CoreGui")

local function CreateESP(inst, text, color, isHighlight)
    if not inst or not inst.Parent then return nil end
    if ESP_Objects[inst] then return ESP_Objects[inst] end

    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP_BB"
    bb.Adornee = inst
    bb.Size = UDim2.new(0, 150, 0, 30)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = ESP_Folder

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.TextStrokeTransparency = 0
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.Parent = bb

    local hl = nil
    if isHighlight then
        hl = Instance.new("Highlight")
        hl.Adornee = inst
        hl.FillColor = color
        hl.FillTransparency = 0.5
        hl.OutlineColor = color
        hl.OutlineTransparency = 0
        hl.Parent = ESP_Folder
    end

    ESP_Objects[inst] = {BB = bb, Label = label, Highlight = hl}
    return ESP_Objects[inst]
end

local function CleanESP()
    for inst, data in pairs(ESP_Objects) do
        if not inst.Parent or not inst:IsDescendantOf(workspace) then
            data.BB:Destroy()
            if data.Highlight then data.Highlight:Destroy() end
            ESP_Objects[inst] = nil
        end
    end
end

local function ForceUpdateESP()
    local char = Player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local myPos = char.HumanoidRootPart.Position

    if Connections_Manager['ESP_Active'] then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local isKiller   = CollectionService:HasTag(p.Character, "Killer")
                local isSurvivor = CollectionService:HasTag(p.Character, "Survivor")

                if not isKiller and not isSurvivor then
                    local lower = ((p.Team and p.Team.Name) or ""):lower()
                    isKiller   = lower:find("killer")   ~= nil
                    isSurvivor = lower:find("survivor") ~= nil
                end

                local baseColor
                if isKiller then
                    baseColor = Color3.fromRGB(255, 50, 50)
                elseif isSurvivor then
                    baseColor = Color3.fromRGB(50, 255, 50)
                else
                    baseColor = Color3.fromRGB(200, 200, 200)
                end

                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local hooked  = p.Character:GetAttribute("IsHooked") == true
                local carried = p.Character:GetAttribute("IsCarried") == true
                local downed  = (p.Character:GetAttribute("Knocked") == true)
                            or (hum and hum.Health > 0 and hum.Health <= hum.MaxHealth * 0.5)

                local color = baseColor
                local tag = ""
                if hooked then
                    color = Color3.fromRGB(255, 255, 50)
                    tag = " [HOOKED]"
                elseif carried then
                    color = Color3.fromRGB(255, 165, 0)
                    tag = " [CARRIED]"
                elseif downed then
                    color = Color3.fromRGB(255, 200, 0)
                    tag = " [DOWNED]"
                end

                local dist = math.floor((p.Character.HumanoidRootPart.Position - myPos).Magnitude)
                local text = p.DisplayName .. " [" .. dist .. "m]" .. tag

                local data = CreateESP(p.Character, text, color, true)
                if data then
                    data.BB.Enabled = true
                    data.Label.Text       = text
                    data.Label.TextColor3 = color
                    if data.Highlight then
                        data.Highlight.Enabled          = true
                        data.Highlight.OutlineColor     = color
                        data.Highlight.FillColor        = color
                        data.Highlight.FillTransparency = 0.5
                    end
                end
            end
        end
    end

    if Connections_Manager['Gen_ESP_Active'] then
        for _, gen in ipairs(CollectionService:GetTagged("Generator")) do
            local isCompleted = gen:GetAttribute("Completed") == true
            local rawProg = gen:GetAttribute("RepairProgress") or 0
            local prog = math.floor(rawProg)

            if isCompleted or rawProg >= 99.5 then
                prog = 100
            end

            local color = prog >= 100 and Color3.fromRGB(50, 255, 50) or Color3.fromRGB(0, 255, 255)
            local text = "Gen: " .. prog .. "%"

            local data = CreateESP(gen, text, color, true)
            if data then
                data.BB.Enabled = true
                data.Label.Text = text
                data.Label.TextColor3 = color

                if data.Highlight then
                    data.Highlight.Enabled = true
                    data.Highlight.OutlineColor = color
                end
            end
        end
    end

    if Connections_Manager['Pallet_ESP_Active'] then
        for _, pPoint in ipairs(CollectionService:GetTagged("PalletPoint")) do
            if pPoint:IsA("BasePart") and pPoint.Parent then
                local target = pPoint.Parent
                if target.Name == "Intact" and target.Parent and target.Parent:IsA("Model") then
                    target = target.Parent
                end

                if target then
                    target:SetAttribute("__BytePallet", true)
                    local pos = pPoint.Position
                    local dist = math.floor((pos - myPos).Magnitude)
                    local text = "Pallet [" .. dist .. "m]"
                    local color = Color3.fromRGB(255, 150, 0)

                    local data = CreateESP(target, text, color, true)
                    if data then
                        data.BB.Adornee = target
                        data.BB.Enabled = true
                        data.Label.Text       = text
                        data.Label.TextColor3 = color
                        if data.Highlight then
                            data.Highlight.Adornee = target
                            data.Highlight.Enabled      = true
                            data.Highlight.OutlineColor = color
                            data.Highlight.FillColor    = color
                            data.Highlight.FillTransparency = 0.5
                        end
                    end
                end
            end
        end
    end

    if Connections_Manager['Vault_ESP_Active'] then
        for _, vault in ipairs(CollectionService:GetTagged("VaultPoint")) do
            if vault:IsA("BasePart") and vault.Parent then
                local target = vault.Parent and vault.Parent:IsA("Model") and vault.Parent or vault
                target:SetAttribute("__ByteVault", true)

                local pos = vault.Position
                local dist = math.floor((pos - myPos).Magnitude)
                local text = "Vault [" .. dist .. "m]"
                local color = Color3.fromRGB(50, 255, 50)

                local data = CreateESP(target, text, color, true)
                if data then
                    data.BB.Adornee = target
                    data.BB.Enabled = true
                    data.Label.Text       = text
                    data.Label.TextColor3 = color
                    if data.Highlight then
                        data.Highlight.Adornee = target
                        data.Highlight.Enabled      = true
                        data.Highlight.OutlineColor = color
                        data.Highlight.FillColor    = color
                        data.Highlight.FillTransparency = 0.5
                    end
                end
            end
        end
    end

    if Connections_Manager['Hooks_ESP_Active'] then
        local hooks = {}
        for _, v in ipairs(CollectionService:GetTagged("HookPoint")) do
            if v:IsA("BasePart") or v:IsA("Model") then table.insert(hooks, v) end
        end
        for _, v in ipairs(CollectionService:GetTagged("UnhookPoint")) do
            if v:IsA("BasePart") then table.insert(hooks, v) end
        end

        do
            for _, v in ipairs(hooks) do
                if v.Parent then
                    local target = v
                    if v:IsA("BasePart") and v.Parent and v.Parent:IsA("Model") then
                        target = v.Parent
                    end

                    local pos
                    if target:IsA("Model") then
                        pos = target.PrimaryPart and target.PrimaryPart.Position
                           or (target:FindFirstChildWhichIsA("BasePart") and target:FindFirstChildWhichIsA("BasePart").Position)
                    else
                        pos = target.Position
                    end

                    if pos then
                        target:SetAttribute("__ByteHook", true)
                        local dist = math.floor((pos - myPos).Magnitude)
                        local isUnhook = CollectionService:HasTag(v, "UnhookPoint")
                        local text = (isUnhook and "[UNHOOK] " or "[HOOK] ") .. dist .. "m"
                        local color = isUnhook and Color3.fromRGB(0, 220, 255) or Color3.fromRGB(255, 100, 255)
                        local data = CreateESP(target, text, color, true)
                        if data then
                            data.BB.Adornee = target
                            data.BB.Enabled = true
                            data.Label.Text       = text
                            data.Label.TextColor3 = color
                            if data.Highlight then
                                data.Highlight.Adornee = target
                                data.Highlight.Enabled      = true
                                data.Highlight.OutlineColor = color
                                data.Highlight.FillColor    = color
                                data.Highlight.FillTransparency = 0.5
                            end
                        end
                    end
                end
            end
        end
    end
end

Connections_Manager['ESP_Render'] = RunService.RenderStepped:Connect(function()
    if State.Unloaded then return end
    CleanESP()
    ForceUpdateESP()
end)

task.spawn(function()
    local sprintWasSetByUs = false
    while true do
        task.wait(0.3)
        if State.Unloaded then break end
        pcall(function()
            local character21 = Player.Character
            if not character21 then return end

            if State.FastVault then
                if character21:GetAttribute("vaultspeed") ~= 3.5 then
                    character21:SetAttribute("vaultspeed", 3.5)
                end
            else
                if character21:GetAttribute("vaultspeed") == 3.5 then
                    character21:SetAttribute("vaultspeed", 1)
                end
            end

            if State.FastSlide then
                if character21:GetAttribute("unhookspeed") ~= 3 then
                    character21:SetAttribute("unhookspeed", 3)
                end
            else
                if character21:GetAttribute("unhookspeed") == 3 then
                    character21:SetAttribute("unhookspeed", 1)
                end
            end

            if State.InfSprint then
                if not character21:GetAttribute("Sprinting") then
                    character21:SetAttribute("Sprinting", true)
                end
                sprintWasSetByUs = true
            elseif sprintWasSetByUs then
                if character21:GetAttribute("Sprinting") == true then
                    character21:SetAttribute("Sprinting", false)
                end
                sprintWasSetByUs = false
            end

            if State.FastGenSkillCheck then
                character21:SetAttribute("skillcheckspeed", 0.1)
            elseif State.FastRepair then
                character21:SetAttribute("repairboost", 2.5)
                character21:SetAttribute("skillcheckspeed", 1.5)
            else
                local scs = character21:GetAttribute("skillcheckspeed")
                if scs == 0.1 or scs == 1.5 then
                    character21:SetAttribute("skillcheckspeed", 1)
                end
                local rb = character21:GetAttribute("repairboost")
                if rb == 2.5 then
                    character21:SetAttribute("repairboost", 1)
                end
            end

            if State.AntiStun then
                if character21:GetAttribute("Immobile") then
                    character21:SetAttribute("Immobile", false)
                end
                if character21:GetAttribute("IsStunned") then
                    character21:SetAttribute("IsStunned", false)
                end
            end
        end)
    end
end)

task.spawn(function()
    local stuckSince = nil
    while true do
        task.wait(0.15)
        if State.Unloaded then break end
        local char = Player.Character
        if not char then stuckSince = nil; continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local check = char:FindFirstChild("CheckInterractable")
        if not hrp or not check then stuckSince = nil; continue end

        local anchored = hrp.Anchored
        local notActing = (not check:GetAttribute("isRepairing"))
            and (not check:GetAttribute("isHealing"))
            and (not check:GetAttribute("isExiting"))
            and (not check:GetAttribute("isUnhooking"))

        local moving = false
        local h = char:FindFirstChildOfClass("Humanoid")
        if h and h.MoveDirection.Magnitude > 0.05 then moving = true end
        if not moving then
            local uis = game:GetService("UserInputService")
            if uis:IsKeyDown(Enum.KeyCode.W) or uis:IsKeyDown(Enum.KeyCode.A)
                or uis:IsKeyDown(Enum.KeyCode.S) or uis:IsKeyDown(Enum.KeyCode.D)
                or uis:IsKeyDown(Enum.KeyCode.Up) or uis:IsKeyDown(Enum.KeyCode.Down)
                or uis:IsKeyDown(Enum.KeyCode.Left) or uis:IsKeyDown(Enum.KeyCode.Right) then
                moving = true
            end
        end

        if anchored and notActing and moving then
            stuckSince = stuckSince or tick()
            if tick() - stuckSince > 0.35 then
                pcall(function() hrp.Anchored = false end)
                if h then
                    pcall(function() h.AutoRotate = true end)
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.Landed) end)
                end
                stuckSince = nil
            end
        else
            stuckSince = nil
        end
    end
end)

task.spawn(function()
    local stuckAt, lastPos = nil, nil
    while true do
        task.wait(0.5)
        if State.Unloaded then break end
        local char = Player.Character
        if not char then
            stuckAt, lastPos = nil, nil
            continue
        end
        local check = char:FindFirstChild("CheckInterractable")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            stuckAt, lastPos = nil, nil
            continue
        end

        local vaulting = check and check:GetAttribute("isVaulting")
        local sliding = check and check:GetAttribute("isSliding")
        local tagged = CollectionService:HasTag(hrp, "doing action")

        if (vaulting or sliding or tagged) then
            local pos = hrp.Position
            if stuckAt then
                local moved = lastPos and (pos - lastPos).Magnitude or 0
                if (tick() - stuckAt) > 2.5 and moved < 2 then
                    pcall(function()
                        if check then
                            check:SetAttribute("isVaulting", false)
                            check:SetAttribute("isSliding", false)
                        end
                        CollectionService:RemoveTag(hrp, "doing action")
                    end)
                    stuckAt, lastPos = nil, nil
                else
                    lastPos = pos
                end
            else
                stuckAt, lastPos = tick(), pos
            end
        else
            stuckAt, lastPos = nil, nil
        end
    end
end)

task.spawn(function()
    local lastHeal       = {}
    local lastUnhook     = {}
    local lastSelfUnhook = 0

    while task.wait(0.5) do
        if State.Unloaded then break end
        local char = Player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
        local myHRP = char.HumanoidRootPart
        local check = char:FindFirstChild("CheckInterractable")
        local myHum = char:FindFirstChildOfClass("Humanoid")

        if State.AutoHeal and check and myHum and myHum.Health > 0
           and not check:GetAttribute("isHealing")
           and not char:GetAttribute("IsHooked")
           and not char:GetAttribute("IsCarried") then
            for _, p in ipairs(Players:GetPlayers()) do
                if p == Player or not p.Character then continue end
                if p.Team and p.Team.Name == "Killer" then continue end

                local tHum = p.Character:FindFirstChildOfClass("Humanoid")
                local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
                if not tHum or not tHRP then continue end
                if tHum.Health <= 0 or tHum.Health >= tHum.MaxHealth then continue end
                if p.Character:GetAttribute("IsHooked") or p.Character:GetAttribute("IsCarried") then continue end
                if (tHRP.Position - myHRP.Position).Magnitude >= 12 then continue end

                local now = tick()
                if now - (lastHeal[p.UserId] or 0) < 2 then continue end
                lastHeal[p.UserId] = now

                local requestId = tostring(math.random(1, 2^31 - 1))
                pcall(function()
                    check:SetAttribute("HealRequestId", requestId)
                    check:SetAttribute("isHealing", true)
                end)
                pcall(function()
                    HealEventRemote:FireServer(tHRP, true, requestId, char)
                end)
                task.delay(8, function()
                    local c = char and char:FindFirstChild("CheckInterractable")
                    if c and c:GetAttribute("HealRequestId") == requestId then
                        pcall(function() c:SetAttribute("isHealing", false) end)
                    end
                end)
                break
            end
        end

        if State.AutoUnhook and check and myHum and myHum.Health > 50
           and not check:GetAttribute("isUnhooking")
           and not char:GetAttribute("IsHooked")
           and not char:GetAttribute("IsCarried") then
            for _, p in ipairs(Players:GetPlayers()) do
                if p == Player or not p.Character then continue end
                if p.Team and p.Team.Name == "Killer" then continue end

                local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
                if not tHRP then continue end
                if not p.Character:GetAttribute("IsHooked") then continue end
                if (tHRP.Position - myHRP.Position).Magnitude > 14 then continue end

                local unhookPoint, bestDist = nil, math.huge
                for _, v in ipairs(CollectionService:GetTagged("UnhookPoint")) do
                    if v:IsA("BasePart") then
                        local d = (v.Position - tHRP.Position).Magnitude
                        if d < bestDist then bestDist = d; unhookPoint = v end
                    end
                end
                if not unhookPoint then continue end

                local now = tick()
                if now - (lastUnhook[p.UserId] or 0) < 2 then continue end
                lastUnhook[p.UserId] = now

                pcall(function() check:SetAttribute("isUnhooking", true) end)
                pcall(function()
                    UnHookEvent:FireServer(unhookPoint, char)
                end)
                task.delay(2, function()
                    local c = char and char:FindFirstChild("CheckInterractable")
                    if c then
                        pcall(function() c:SetAttribute("isUnhooking", false) end)
                    end
                end)
                break
            end
        end

        if State.AutoSelfUnhook and char:GetAttribute("IsHooked")
           and not char:GetAttribute("IsCarried")
           and not char:GetAttribute("Disabled")
           and (char:GetAttribute("HookCount") or 0) < 3 then
            local now = tick()
            if now - lastSelfUnhook >= 30 then
                lastSelfUnhook = now
                pcall(function()
                    SelfUnHookEvent:FireServer()
                end)
            end
        end
    end
end)

task.spawn(function()
    local flashlightOn = false

    while task.wait(0.2) do
        if State.Unloaded then break end
        local char = Player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then continue end
        local myHRP = char.HumanoidRootPart
        local myHum = char:FindFirstChildOfClass("Humanoid")
        if not myHum or myHum.Health <= 0 then continue end

        local function nearestKiller(maxDist, partName)
            local target, closest = nil, maxDist
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player and p.Character
                   and (CollectionService:HasTag(p.Character, "Killer")
                        or (p.Team and p.Team.Name == "Killer")) then
                    local part = p.Character:FindFirstChild(partName or "HumanoidRootPart")
                    if part then
                        local d = (part.Position - myHRP.Position).Magnitude
                        if d < closest then closest = d; target = p.Character end
                    end
                end
            end
            return target
        end

        if State.AutoToF and Fire_Remote then
            local tool = EquipTool("Twist of Fate")
            if tool then
                local target = nearestKiller(45)
                if target then
                    local tHRP = target.HumanoidRootPart
                    local targetPos = tHRP.Position + tHRP.AssemblyLinearVelocity * 0.15
                    pcall(function()
                        Fire_Remote:FireServer(tool, (targetPos - myHRP.Position).Unit)
                    end)
                    task.wait(1.5)
                end
            end
        end

        if State.AutoHolyWater and ThrowRemote then
            local tool = EquipTool("Holy Water")
            if tool then
                local target = nearestKiller(25)
                if target then
                    local dir = (target.HumanoidRootPart.Position - myHRP.Position).Unit
                    local vizname = tool:GetAttribute("vizname")
                    pcall(function()
                        ThrowRemote:FireServer(tool, dir, vizname)
                    end)
                    task.wait(2)
                end
            end
        end

        if State.AutoRiot and RushRemote then
            local tool = EquipTool("Riot Shield")
            if tool then
                local target = nearestKiller(15)
                if target then
                    local ok, KB = pcall(function()
                        return require(ReplicatedStorage.Modules.Survivors.KeybindsConfig)
                    end)
                    if ok and KB then
                        local bind = KB.getRaw("item")
                        pcall(function()
                            if bind == "MouseButton1" then
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 0)
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 0)
                            elseif bind == "MouseButton2" then
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 2, true, game, 0)
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, game, 0)
                            else
                                local code = Enum.KeyCode[bind]
                                if code then
                                    VirtualInputManager:SendKeyEvent(true,  code, false, game)
                                    VirtualInputManager:SendKeyEvent(false, code, false, game)
                                end
                            end
                        end)
                    end
                    task.wait(3)
                end
            end
        end

        if State.AutoFlash and FlashlightActivate then
            local tool = EquipTool("Flashlight")
            if tool then
                local target = nearestKiller(22, "Head")
                local part = tool.PrimaryPart or tool:FindFirstChildWhichIsA("BasePart")
                if part then
                    if target and not flashlightOn then
                        flashlightOn = true
                        pcall(function() FlashlightActivate:FireServer(part, true) end)
                    elseif not target and flashlightOn then
                        flashlightOn = false
                        pcall(function() FlashlightActivate:FireServer(part, false) end)
                    end
                end
            elseif flashlightOn then
                flashlightOn = false
            end
        end

        if State.AutoAdren and char:GetAttribute("Knocked") then
            if (char:GetAttribute("HealProgress") or 0) >= 15 and AdrenalineShot then
                local tool = EquipTool("Adrenaline")
                if tool and AdrenalineShot:FindFirstChild("Knocked") then
                    pcall(function()
                        AdrenalineShot.Knocked:FireServer(tool)
                    end)
                    task.wait(3)
                end
            end
        end

        if State.AutoBandage and not char:GetAttribute("Knocked") and BandageFire then
            local hp = myHum.Health
            if hp >= 50 and hp <= 80 then
                local tool = EquipTool("Bandage")
                if tool and (tool:GetAttribute("charge") or 0) > 0 then
                    local reqId = math.random(1, 2^31 - 1)
                    pcall(function()
                        BandageFire:FireServer(true, tool, reqId)
                    end)
                    task.delay(2, function()
                        pcall(function()
                            BandageFire:FireServer(false, tool, reqId)
                        end)
                    end)
                    task.wait(3)
                end
            end
        end
    end
end)

local Repo = 'https://raw.githubusercontent.com/viseamn/Visual/main/'
local Library      = loadstring(game:HttpGet(Repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(Repo .. 'ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(Repo .. 'SaveManager.lua'))()

local Options = Library.Options
local Toggles = Library.Toggles

local Window = Library:CreateWindow({
    Title                = 'Byte',
    Layout               = 'Bottom bar',
    MenuKey              = Enum.KeyCode.RightControl,
    NotificationPosition = 'BottomRight',
})

local Tabs = {
    ['Main']        = Window:AddTab('Main', 'user'),
    ['Items']       = Window:AddTab('Items', 'box'),
    ['Killer']      = Window:AddTab('Killer', 'target'),
    ['ESP']         = Window:AddTab('ESP', 'eye'),
    ['UI Settings'] = Window:CreateSettingsTab(),
}

local Main_Group = Tabs['Main']:AddLeftGroupbox('Automation', 'boxes')

Main_Group:AddToggle('Auto_Parry_Toggle', {
    Text = 'Auto Parry',
    Default = false,
    Callback = function(state) State.AutoParry = state end
})

Main_Group:AddDivider()

Main_Group:AddToggle('GeneratorSkillCheck', {
    Text = 'Generator',
    Default = false,
    Callback = function(value)
        State.FastGenSkillCheck = value
        if value then

            Connections_Manager['Generator'] = Generator_Event.OnClientEvent:Connect(function(generator, point)
                local Check_Gui = PlayerGui:WaitForChild('SkillCheckPromptGui')
                local Check = Check_Gui:WaitForChild('Check')
                local Line  = Check:WaitForChild('Line')
                local Goal  = Check:WaitForChild('Goal')

                if Connections_Manager['Live'] then
                    pcall(function() Connections_Manager['Live']:Disconnect() end)
                    Connections_Manager['Live'] = nil
                end

                Connections_Manager['Live'] = RunService.RenderStepped:Connect(function()
                    if not Check.Parent then
                        if Connections_Manager['Live'] then
                            Connections_Manager['Live']:Disconnect()
                            Connections_Manager['Live'] = nil
                        end
                        return
                    end

                    if not Check.Visible then return end
                    if Goal.Rotation == nil then return end

                    Line.Rotation = (Goal.Rotation + 109) % 360

                    if Is_Mobile then
                        Generator_Result:FireServer("success", 1, generator, point)
                    else
                        Byte.Press()
                    end

                    if Connections_Manager['Live'] then
                        Connections_Manager['Live']:Disconnect()
                        Connections_Manager['Live'] = nil
                    end
                end)
            end)
        else
            if Connections_Manager['Live'] then
                pcall(function() Connections_Manager['Live']:Disconnect() end)
                Connections_Manager['Live'] = nil
            end
            if Connections_Manager['Generator'] then
                pcall(function() Connections_Manager['Generator']:Disconnect() end)
                Connections_Manager['Generator'] = nil
            end
        end
    end,
})

Main_Group:AddToggle('HealSkillCheck', {
    Text = 'Heal',
    Default = false,
    Callback = function(value)
        if value then
            Connections_Manager['Heal'] = Heal_Event.OnClientEvent:Connect(function(target, point)
                local Check_Gui = PlayerGui:WaitForChild('SkillCheckPromptGui')
                local Check = Check_Gui:WaitForChild('Check')
                local Line  = Check:WaitForChild('Line')
                local Goal  = Check:WaitForChild('Goal')

                if Connections_Manager['Live 2'] then
                    pcall(function() Connections_Manager['Live 2']:Disconnect() end)
                    Connections_Manager['Live 2'] = nil
                end

                Connections_Manager['Live 2'] = RunService.RenderStepped:Connect(function()
                    if not Check.Parent then
                        if Connections_Manager['Live 2'] then
                            Connections_Manager['Live 2']:Disconnect()
                            Connections_Manager['Live 2'] = nil
                        end
                        return
                    end

                    if not Check.Visible then return end
                    if Goal.Rotation == nil then return end

                    if Byte.Goal(Line, Goal) then
                        if Is_Mobile then
                            Heal_Result:FireServer("success", 1, target, point)
                        else
                            Byte.Press()
                        end

                        if Connections_Manager['Live 2'] then
                            Connections_Manager['Live 2']:Disconnect()
                            Connections_Manager['Live 2'] = nil
                        end
                    end
                end)
            end)
        else
            if Connections_Manager['Live 2'] then
                pcall(function() Connections_Manager['Live 2']:Disconnect() end)
                Connections_Manager['Live 2'] = nil
            end
            if Connections_Manager['Heal'] then
                pcall(function() Connections_Manager['Heal']:Disconnect() end)
                Connections_Manager['Heal'] = nil
            end
        end
    end,
})

Main_Group:AddDivider()

Main_Group:AddButton({
    Text = "Instant Escape",
    Tooltip = "Instant Escape",
    Callback = function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local check = char:FindFirstChild("CheckInterractable")
        if check then
            pcall(function()
                check:SetAttribute("isRepairing", false)
                check:SetAttribute("isHealing", false)
                check:SetAttribute("isUnhooking", false)
                check:SetAttribute("isExiting", false)
                check:SetAttribute("isVaulting", false)
                check:SetAttribute("isSliding", false)
            end)
        end
        local best, bestDist
        for _, part in ipairs(CollectionService:GetTagged("EscapePart")) do
            if part:IsA("BasePart") and not part.CanCollide and part.Parent then
                local d = (part.Position - hrp.Position).Magnitude
                if not best or d < bestDist then best, bestDist = part, d end
            end
        end
        if not best then return end
        hrp.CFrame = best.CFrame + Vector3.new(0, 3, 0)
        hrp.AssemblyLinearVelocity = Vector3.zero
        if firetouchinterest then
            firetouchinterest(hrp, best, 0)
            firetouchinterest(hrp, best, 1)
        end
    end,
})

local Survivor_Right = Tabs['Main']:AddRightGroupbox("Survivor", "user")

Survivor_Right:AddToggle('FastVault',      { Text = 'Fast Vault',            Default = false, Callback = function(v) State.FastVault = v end })
Survivor_Right:AddToggle('FastSlide',      { Text = 'Fast Pallet Slide',     Default = false, Callback = function(v) State.FastSlide = v end })
Survivor_Right:AddToggle('InfSprint',      { Text = 'Infinite Sprint',       Default = false, Callback = function(v) State.InfSprint = v end })
Survivor_Right:AddToggle('FastRepair',     { Text = 'Fast Repair (Max)',     Default = false, Callback = function(v) State.FastRepair = v end })
Survivor_Right:AddToggle('AntiStun',       { Text = 'Anti Stun',             Default = false, Callback = function(v) State.AntiStun = v end })
Survivor_Right:AddToggle('AutoHeal',       { Text = 'Auto Heal Teammates',   Default = false, Callback = function(v) State.AutoHeal = v end })
Survivor_Right:AddToggle('AutoUnhook',     { Text = 'Auto Unhook Teammates', Default = false, Callback = function(v) State.AutoUnhook = v end })
Survivor_Right:AddToggle('AutoSelfUnhook', { Text = 'Auto Self Unhook',      Default = false, Callback = function(v) State.AutoSelfUnhook = v end })
Survivor_Right:AddToggle('NoParryCooldown', { Text = 'No Parry Cooldown',     Default = false, Callback = function(v) State.NoParryCooldown = v end })

local ParryClients = setmetatable({}, { __mode = "k" })
local LastParryScan = 0
task.spawn(function()
    while task.wait(0.05) do
        if State.Unloaded then break end
        if not State.NoParryCooldown then continue end
        pcall(function()
            if os.clock() - LastParryScan >= 1 then
                LastParryScan = os.clock()
                for _, obj in ipairs(getgc(true)) do
                    if type(obj) == "table"
                        and rawget(obj, "isParryOnCooldown") ~= nil
                        and rawget(obj, "isParryResolving") ~= nil
                        and rawget(obj, "parryEvent") ~= nil
                    then
                        ParryClients[obj] = true
                    end
                end
            end
            for client in pairs(ParryClients) do
                if client.isParryOnCooldown or client.isParryResolving then
                    if type(client._clearCooldown) == "function" then
                        pcall(function() client:_clearCooldown() end)
                    else
                        client.isParryOnCooldown = false
                        client.isParryResolving = false
                        client.cooldownToken = (client.cooldownToken or 0) + 1
                        for _, gradient in ipairs(client.gradients or {}) do
                            if gradient and gradient.Parent then
                                gradient.Offset = Vector2.new(0, 0.25)
                            end
                        end
                        if type(client._refreshVisual) == "function" then
                            pcall(function() client:_refreshVisual() end)
                        end
                    end
                end
            end
        end)
    end
end)

if getidentity() >= 7 then
    Survivor_Right:AddToggle('Silent_Aim_Toggle', {
        Text = 'Silent Aim (Gun)',
        Default = false,
        Callback = function(state) Toggles.Silent_Aim_Toggle.Value = state end
    })
end

local Items_Group = Tabs['Items']:AddLeftGroupbox("Item Automation", "box")
Items_Group:AddToggle('AutoToF',         { Text = 'Auto Shoot ToF (Revolver)', Default = false, Callback = function(v) State.AutoToF = v end })
Items_Group:AddToggle('AutoHolyWater',   { Text = 'Auto Throw Holy Water',     Default = false, Callback = function(v) State.AutoHolyWater = v end })
Items_Group:AddToggle('AutoRiot',        { Text = 'Auto Riot Shield Rush',     Default = false, Callback = function(v) State.AutoRiot = v end })
Items_Group:AddToggle('AutoFlash',       { Text = 'Auto Flashlight Blind',     Default = false, Callback = function(v) State.AutoFlash = v end })
Items_Group:AddToggle('AutoAdren',       { Text = 'Auto Adrenaline Revive',    Default = false, Callback = function(v) State.AutoAdren = v end })
Items_Group:AddToggle('AutoBandage',     { Text = 'Auto Bandage Heal',         Default = false, Callback = function(v) State.AutoBandage = v end })

local Esp_Group = Tabs['ESP']:AddLeftGroupbox('ESP Settings', 'eye')

Esp_Group:AddToggle('Killer_ESP', {
    Text = 'Killer & Survivor ESP',
    Default = false,
    Callback = function(value)
        Connections_Manager['ESP_Active'] = value
        if not value then
            for inst, data in pairs(ESP_Objects) do
                if data.BB and data.BB.Parent and inst:FindFirstChildOfClass("Humanoid") then
                    data.BB.Enabled = false
                    if data.Highlight then data.Highlight.Enabled = false end
                end
            end
        end
    end,
})

Esp_Group:AddToggle("Generators_ESP", {
    Text = "Generators ESP & Percentage",
    Default = false,
    Callback = function(value)
        Connections_Manager['Gen_ESP_Active'] = value
        if not value then
            for inst, data in pairs(ESP_Objects) do
                if inst:GetAttribute("RepairProgress") ~= nil then
                    data.BB.Enabled = false
                    if data.Highlight then data.Highlight.Enabled = false end
                end
            end
        end
    end,
})

Esp_Group:AddToggle("Hooks_ESP", {
    Text = "Hooks ESP",
    Default = false,
    Callback = function(value)
        Connections_Manager['Hooks_ESP_Active'] = value
        if not value then
            for inst, data in pairs(ESP_Objects) do
                if inst:GetAttribute("__ByteHook") then
                    data.BB.Enabled = false
                    if data.Highlight then data.Highlight.Enabled = false end
                end
            end
        end
    end,
})

Esp_Group:AddToggle("Pallets_ESP", {
    Text = "Pallets ESP",
    Default = false,
    Callback = function(value)
        Connections_Manager['Pallet_ESP_Active'] = value
        if not value then
            for inst, data in pairs(ESP_Objects) do
                if inst:GetAttribute("__BytePallet") then
                    data.BB.Enabled = false
                    if data.Highlight then data.Highlight.Enabled = false end
                end
            end
        end
    end,
})

Esp_Group:AddToggle("Vaults_ESP", {
    Text = "Window Vaults ESP",
    Default = false,
    Callback = function(value)
        Connections_Manager['Vault_ESP_Active'] = value
        if not value then
            for inst, data in pairs(ESP_Objects) do
                if inst:GetAttribute("__ByteVault") then
                    data.BB.Enabled = false
                    if data.Highlight then data.Highlight.Enabled = false end
                end
            end
        end
    end,
})

local Movement_Group = Tabs['ESP']:AddRightGroupbox("Movement", "user")
Movement_Group:AddToggle('NoSlow_Toggle', { Text = 'No Slow', Default = false, Callback = function(v) State.NoSlow = v end })
Movement_Group:AddToggle('BypassGenPoint_Toggle', { Text = 'Bypass Generator Point (Experimental)', Default = false, Callback = function(v) State.BypassGenPoint = v end })
Movement_Group:AddToggle('NoFall_Toggle', { Text = 'No Fall', Default = false, Callback = function(v) State.NoFall = v end })
Movement_Group:AddToggle('NoClip_Toggle', { Text = 'No Clip', Default = false, Callback = function(v) State.NoClip = v end })
Movement_Group:AddToggle('InfJump_Toggle', { Text = 'Infinite Jump', Default = false, Callback = function(v) State.InfiniteJump = v end })

local World_Group = Tabs['ESP']:AddRightGroupbox("World", "box")
World_Group:AddToggle('Fullbright_Toggle', { Text = 'Full Bright', Default = false, Callback = function(v) State.Fullbright = v end })
World_Group:AddToggle('AntiShake_Toggle', { Text = 'Anti Camera Shake', Default = false, Callback = function(v) State.AntiShake = v end })
World_Group:AddToggle('NoFog_Toggle', { Text = 'No Fog', Default = false, Callback = function(v) State.NoFog = v end })
World_Group:AddToggle('AntiAfk_Toggle', { Text = 'Anti AFK', Default = false, Callback = function(v) State.AntiAfk = v end })

local LightingSvc = game:GetService("Lighting")
local savedWorld = nil
local function SaveWorld()
    if savedWorld then return end
    savedWorld = {
        Brightness = LightingSvc.Brightness,
        ClockTime = LightingSvc.ClockTime,
        GlobalShadows = LightingSvc.GlobalShadows,
        Ambient = LightingSvc.Ambient,
        OutdoorAmbient = LightingSvc.OutdoorAmbient,
        FogEnd = LightingSvc.FogEnd,
        FogStart = LightingSvc.FogStart,
        Atmosphere = {},
    }
    for _, v in ipairs(LightingSvc:GetChildren()) do
        if v:IsA("Atmosphere") then savedWorld.Atmosphere[v] = v.Density end
    end
end
local function RestoreWorld()
    if not savedWorld then return end
    LightingSvc.Brightness = savedWorld.Brightness
    LightingSvc.ClockTime = savedWorld.ClockTime
    LightingSvc.GlobalShadows = savedWorld.GlobalShadows
    LightingSvc.Ambient = savedWorld.Ambient
    LightingSvc.OutdoorAmbient = savedWorld.OutdoorAmbient
    LightingSvc.FogEnd = savedWorld.FogEnd
    LightingSvc.FogStart = savedWorld.FogStart
    for atmo, density in pairs(savedWorld.Atmosphere) do
        if atmo and atmo.Parent then pcall(function() atmo.Density = density end) end
    end
    savedWorld = nil
end

Connections_Manager['Movement_World_Stepped'] = RunService.RenderStepped:Connect(function()
    if State.Unloaded then return end

    if State.Fullbright or State.NoFog then
        SaveWorld()
        if State.Fullbright then
            LightingSvc.Brightness = 2
            LightingSvc.ClockTime = 14
            LightingSvc.GlobalShadows = false
            LightingSvc.Ambient = Color3.new(1, 1, 1)
            LightingSvc.OutdoorAmbient = Color3.new(1, 1, 1)
        else
            LightingSvc.Brightness = savedWorld.Brightness
            LightingSvc.ClockTime = savedWorld.ClockTime
            LightingSvc.GlobalShadows = savedWorld.GlobalShadows
            LightingSvc.Ambient = savedWorld.Ambient
            LightingSvc.OutdoorAmbient = savedWorld.OutdoorAmbient
        end
        if State.NoFog then
            LightingSvc.FogEnd = 1e6
            LightingSvc.FogStart = 1e6
            for atmo in pairs(savedWorld.Atmosphere) do
                if atmo and atmo.Parent then pcall(function() atmo.Density = 0 end) end
            end
        else
            LightingSvc.FogEnd = savedWorld.FogEnd
            LightingSvc.FogStart = savedWorld.FogStart
            for atmo, density in pairs(savedWorld.Atmosphere) do
                if atmo and atmo.Parent then pcall(function() atmo.Density = density end) end
            end
        end
    elseif savedWorld then
        RestoreWorld()
    end
end)

local NoSlowState = { Lifted = nil, LiftedTo = nil }
local NO_SLOW_TARGET = 17

Connections_Manager['NoSlow_Stepped'] = RunService.Stepped:Connect(function()
    if State.Unloaded then return end
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if State.NoSlow then
        if hum.WalkSpeed > 0 and hum.WalkSpeed < NO_SLOW_TARGET then
            NoSlowState.Lifted   = NoSlowState.Lifted or hum.WalkSpeed
            NoSlowState.LiftedTo = NO_SLOW_TARGET
            hum.WalkSpeed = NO_SLOW_TARGET
        end
    elseif NoSlowState.Lifted then
        local before = NoSlowState.Lifted
        local wrote  = NoSlowState.LiftedTo
        NoSlowState.Lifted   = nil
        NoSlowState.LiftedTo = nil
        if math.abs(hum.WalkSpeed - wrote) < 0.01 then
            hum.WalkSpeed = before
        end
    end
end)

-- ==== Bypass Generator Point (Experimental) ====
-- 1. Strips "doing action" + "Blocked" tags from nearby GeneratorPoints so the prompt shows up
-- 2. Forces repair-related attributes (some may be server-read, some decorative)
-- Reverts on toggle off

local _bgpWasActive = false
local _bgpLastStrip = 0

Connections_Manager['BypassGenPoint_Render'] = RunService.RenderStepped:Connect(function()
    if State.Unloaded then return end
    local char = Player.Character

    if State.BypassGenPoint then
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        -- 1. Seat steal: strip tags from nearby generator points every 150ms
        local now = tick()
        if now - _bgpLastStrip > 0.15 then
            _bgpLastStrip = now
            for _, pt in ipairs(CollectionService:GetTagged("GeneratorPoint")) do
                if pt:IsA("BasePart") and not pt:IsDescendantOf(char) then
                    local d = (pt.Position - hrp.Position).Magnitude
                    if d < 12 then
                        if CollectionService:HasTag(pt, "doing action") then
                            CollectionService:RemoveTag(pt, "doing action")
                        end
                        if pt.Parent and CollectionService:HasTag(pt.Parent, "Blocked") then
                            CollectionService:RemoveTag(pt.Parent, "Blocked")
                        end
                    end
                end
            end
        end

        -- 2. Force attributes (may or may not be server-read)
        if char:GetAttribute("repairboost") ~= 5 then
            char:SetAttribute("repairboost", 5)
        end
        if char:GetAttribute("speedboost") ~= 3 then
            char:SetAttribute("speedboost", 3)
        end
        if char:GetAttribute("skillcheckfrequency") ~= 0.2 then
            char:SetAttribute("skillcheckfrequency", 0.2)
        end
        if char:GetAttribute("skillcheckspeed") ~= 0.1 then
            char:SetAttribute("skillcheckspeed", 0.1)
        end

        _bgpWasActive = true

    elseif _bgpWasActive and char then
        -- revert on toggle-off
        if char:GetAttribute("repairboost") == 5 then
            char:SetAttribute("repairboost", 1)
        end
        if char:GetAttribute("speedboost") == 3 then
            char:SetAttribute("speedboost", 1)
        end
        if char:GetAttribute("skillcheckfrequency") == 0.2 then
            char:SetAttribute("skillcheckfrequency", 1)
        end
        if char:GetAttribute("skillcheckspeed") == 0.1 then
            char:SetAttribute("skillcheckspeed", 1)
        end
        _bgpWasActive = false
    end
end)

local noclipSet = {}
Connections_Manager['NoClip_Stepped'] = RunService.Stepped:Connect(function()
    if State.Unloaded then return end
    if State.NoClip then
        local char = Player.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide and not noclipSet[part] then
                part.CanCollide = false
                noclipSet[part] = true
            end
        end
    elseif next(noclipSet) ~= nil then
        for part in pairs(noclipSet) do
            if part and part.Parent then
                pcall(function() part.CanCollide = true end)
            end
        end
        table.clear(noclipSet)
    end
end)

Connections_Manager['InfJump'] = UserInputService.JumpRequest:Connect(function()
    if State.Unloaded or not State.InfiniteJump then return end
    local char = Player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local vel = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = Vector3.new(vel.X, 50, vel.Z)
end)

local AntiAfkVu
pcall(function() AntiAfkVu = game:GetService("VirtualUser") end)
if AntiAfkVu then
    Connections_Manager['AntiAfk'] = Player.Idled:Connect(function()
        if State.Unloaded or not State.AntiAfk then return end
        pcall(function()
            AntiAfkVu:CaptureController()
            AntiAfkVu:ClickButton2(Vector2.zero)
        end)
    end)
end

local FallRemote = Remotes:FindFirstChild("Mechanics") and Remotes.Mechanics:FindFirstChild("Fall")
if FallRemote and hookmetamethod and checkcaller and getnamecallmethod then
    pcall(function()
        local originalNamecall
        originalNamecall = hookmetamethod(game, "__namecall", function(Self, ...)
            if not checkcaller() and Self == FallRemote and getnamecallmethod() == "FireServer" and State.NoFall and not State.Unloaded then
                return nil
            end
            return originalNamecall(Self, ...)
        end)
    end)
end

local ShakeRemote
do
    local GameFolder = Remotes:FindFirstChild("Game")
    if GameFolder then
        ShakeRemote = GameFolder:FindFirstChild("shake")
    end
    if not ShakeRemote then
        for _, v in ipairs(Remotes:GetDescendants()) do
            if v.Name:lower() == "shake" and (v:IsA("BindableEvent") or v:IsA("RemoteEvent")) then
                ShakeRemote = v
                break
            end
        end
    end
end

local ShakeMuted = {}
local function MuteShake()
    if not ShakeRemote then return end
    local sig = ShakeRemote:IsA("BindableEvent") and ShakeRemote.Event or ShakeRemote.OnClientEvent
    if not sig then return end
    local connectionsFn = getconnections or getsignalcons or get_signal_cons
    if not connectionsFn then return end
    pcall(function()
        for _, conn in ipairs(connectionsFn(sig)) do
            if conn.Enabled then
                local already = false
                for _, m in ipairs(ShakeMuted) do
                    if m == conn then already = true; break end
                end
                if not already then
                    pcall(function() conn:Disable() end)
                    table.insert(ShakeMuted, conn)
                end
            end
        end
    end)
end
local function UnmuteShake()
    for _, conn in ipairs(ShakeMuted) do
        pcall(function() conn:Enable() end)
    end
    ShakeMuted = {}
end

task.spawn(function()
    local wasOn = false
    while task.wait(0.2) do
        if State.Unloaded then break end
        if State.AntiShake then
            MuteShake()
            wasOn = true
        elseif wasOn then
            UnmuteShake()
            wasOn = false
        end
    end
end)

local Killer_Hunt = Tabs['Killer']:AddLeftGroupbox('Hunt', 'target')
Killer_Hunt:AddToggle('KillAura_Toggle', {
    Text = 'Auto Slash',
    Default = false,
    Callback = function(v) State.KillAura = v end,
})
Killer_Hunt:AddToggle('SmartHitbox_Toggle', {
    Text = 'Reach Assist',
    Default = false,
    Callback = function(v) State.SmartHitbox = v end,
})
Killer_Hunt:AddDropdown('SlashMode_Dropdown', {
    Text = 'Slash Mode',
    Values = { 'Rage', 'Legit' },
    Default = 'Rage',
    Multi = false,
    Callback = function(v) State.SlashMode = v end,
})
Killer_Hunt:AddSlider('AuraRange_Slider', {
    Text = 'Range',
    Min = 10,
    Max = 500,
    Default = 500,
    Rounding = 0,
    Suffix = 'm',
    Callback = function(v) State.AuraRange = v end,
})

local Killer_Defense = Tabs['Killer']:AddRightGroupbox('Defense', 'shield')
Killer_Defense:AddToggle('AntiStun_Toggle', {
    Text = 'Anti Pallet Stun',
    Default = false,
    Callback = function(v) State.AntiStun = v end,
})
Killer_Defense:AddToggle('AntiBlind_Toggle', {
    Text = 'Anti Blind',
    Default = false,
    Callback = function(v) State.AntiBlind = v end,
})
Killer_Defense:AddToggle('FreeTurn_Toggle', {
    Text = 'No Turn Limit',
    Default = false,
    Callback = function(v) State.FreeTurn = v end,
})

local function Byte_IsLocalKiller()
    local teamName = (Player.Team and Player.Team.Name or ""):lower()
    return teamName:find("killer") ~= nil
end

local function Byte_IsSurvivorPlayer(p)
    if p == Player or not p.Character then return false end
    if not p.Character:FindFirstChild("HumanoidRootPart") then return false end
    local teamName = (p.Team and p.Team.Name or ""):lower()
    if teamName:find("survivor") then return true end
    if teamName:find("killer") then return false end
    if teamName:find("spectator") then return false end
    if CollectionService:HasTag(p.Character, "Survivor") then return true end
    return false
end

local function Byte_GetSurvivors()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if Byte_IsSurvivorPlayer(p) then
            list[#list + 1] = p.Character
        end
    end
    return list
end

local function Byte_IsVulnerable(char)
    if not char or not char.Parent then return false end
    if char:GetAttribute("Knocked") then return false end
    if char:GetAttribute("IsHooked") then return false end
    if char:GetAttribute("IsCarried") then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    return true
end

local function Byte_GetNearestTarget(hrp, range)
    local best, bestDist
    for _, char in ipairs(Byte_GetSurvivors()) do
        if not Byte_IsVulnerable(char) then continue end
        local trp = char:FindFirstChild("HumanoidRootPart")
        if not trp then continue end
        local d = (trp.Position - hrp.Position).Magnitude
        if d <= range and (not best or d < bestDist) then
            best, bestDist = char, d
        end
    end
    return best
end

local function Byte_GetTargetInFront(hrp)
    local look = hrp.CFrame.LookVector
    local best, bestDist
    for _, char in ipairs(Byte_GetSurvivors()) do
        if not Byte_IsVulnerable(char) then continue end
        local trp = char:FindFirstChild("HumanoidRootPart")
        if not trp then continue end
        local offset = trp.Position - hrp.Position
        local d = offset.Magnitude
        if d > 0 and d <= 9 and look:Dot(offset.Unit) >= 0.5 then
            if not best or d < bestDist then
                best, bestDist = char, d
            end
        end
    end
    return best
end

local function Byte_RageSwing(target)
    if not (Lunge_Remote and BasicAttack_Remote) then return end
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local trp = target and target:FindFirstChild("HumanoidRootPart")
    if not (hrp and trp) then return end
    Lunge_Remote:FireServer()
    local start = os.clock()
    local fired = false
    while os.clock() - start < 0.61 do
        if State.Unloaded or not State.KillAura then break end
        if not hrp.Parent then break end
        if not (trp.Parent and target.Parent) then break end
        local behind = trp.Position - trp.CFrame.LookVector * 2
        hrp.CFrame = CFrame.lookAt(behind, trp.Position)
        if not fired and os.clock() - start >= 0.21 then
            fired = true
            BasicAttack_Remote:FireServer()
        end
        RunService.Heartbeat:Wait()
    end
end

local function Byte_LegitSwing(target)
    if not (Lunge_Remote and BasicAttack_Remote) then return end
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local trp = target and target:FindFirstChild("HumanoidRootPart")
    if not (hrp and trp) then return end
    if State.SmartHitbox then
        local offset = trp.Position - hrp.Position
        if offset.Magnitude > 4.2 then
            local spot = trp.Position - offset.Unit * 2
            hrp.CFrame = CFrame.lookAt(
                Vector3.new(spot.X, hrp.Position.Y, spot.Z),
                Vector3.new(trp.Position.X, hrp.Position.Y, trp.Position.Z)
            )
        end
    end
    Lunge_Remote:FireServer()
    task.wait(0.21)
    if State.KillAura and target.Parent then
        BasicAttack_Remote:FireServer()
    end
end

task.spawn(function()
    local lastSwing = 0
    while task.wait(0.1) do
        if State.Unloaded then break end
        if not State.KillAura then continue end
        if not (Lunge_Remote and BasicAttack_Remote) then continue end
        if not Byte_IsLocalKiller() then continue end
        local char = Player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        if char:GetAttribute("CarriedSurvivorId") then continue end
        if os.clock() - lastSwing < 1.1 then continue end
        local target
        if State.SlashMode == "Legit" then
            target = Byte_GetTargetInFront(hrp)
        else
            target = Byte_GetNearestTarget(hrp, State.AuraRange)
        end
        if not target then continue end
        lastSwing = os.clock()
        if State.SlashMode == "Legit" then
            Byte_LegitSwing(target)
        else
            Byte_RageSwing(target)
        end
    end
end)

local MutedStunConns = {}
local OwnAntiStunFns = {}

local function Byte_OnAntiStun()
    if not State.AntiStun then return end
    local char = Player.Character
    if char and Stunover_Remote then
        pcall(function() Stunover_Remote:FireServer(char) end)
    end
end

OwnAntiStunFns[Byte_OnAntiStun] = true

if Stun_Remote then
    local sig = Stun_Remote:IsA("BindableEvent") and Stun_Remote.Event or Stun_Remote.OnClientEvent
    if sig then
        Connections_Manager['AntiStun_Handler'] = sig:Connect(Byte_OnAntiStun)
    end
end

local function Byte_GetConnectionsFn()
    if getconnections then return getconnections end
    if getsignalcons then return getsignalcons end
    if get_signal_cons then return get_signal_cons end
    return nil
end

local function Byte_MuteStun()
    local gc = Byte_GetConnectionsFn()
    if not gc or not Stun_Remote then return end
    local sig = Stun_Remote:IsA("BindableEvent") and Stun_Remote.Event or Stun_Remote.OnClientEvent
    if not sig then return end
    pcall(function()
        for _, conn in ipairs(gc(sig)) do
            if conn.Enabled and not OwnAntiStunFns[conn.Function] then
                local already = false
                for _, m in ipairs(MutedStunConns) do
                    if m == conn then already = true; break end
                end
                if not already then
                    pcall(function() conn:Disable() end)
                    table.insert(MutedStunConns, conn)
                end
            end
        end
    end)
end

function Byte_UnmuteStun()
    for _, conn in ipairs(MutedStunConns) do
        pcall(function() conn:Enable() end)
    end
    MutedStunConns = {}
end

task.spawn(function()
    local wasOn = false
    while task.wait(0.2) do
        if State.Unloaded then break end
        if State.AntiStun then
            Byte_MuteStun()
            wasOn = true
        elseif wasOn then
            Byte_UnmuteStun()
            wasOn = false
        end
    end
end)

Connections_Manager['AntiStun_Attr'] = RunService.RenderStepped:Connect(function()
    if State.Unloaded or not State.AntiStun then return end
    local char = Player.Character
    if not char then return end
    if char:GetAttribute("IsStunned") then
        pcall(function() char:SetAttribute("IsStunned", false) end)
    end
    if char:GetAttribute("Immobile") then
        pcall(function() char:SetAttribute("Immobile", false) end)
    end
end)

Connections_Manager['AntiBlind_Render'] = RunService.RenderStepped:Connect(function()
    if State.Unloaded or not State.AntiBlind then return end
    local char = Player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        local blindness = tonumber(head:GetAttribute("Blindness")) or 0
        if blindness > 0 then
            pcall(function() head:SetAttribute("Blindness", 0) end)
        end
    end
    local cam = workspace.CurrentCamera
    if cam then
        for _, child in ipairs(cam:GetChildren()) do
            if child.Name == "FlashBlindColor" then
                pcall(function() child.Enabled = false end)
            elseif child.Name == "FlashBlindBlur" then
                pcall(function()
                    child.Enabled = false
                    child.Size = 0
                end)
            end
        end
    end
end)

Connections_Manager['FreeTurn_Render'] = RunService.RenderStepped:Connect(function()
    if State.Unloaded or not State.FreeTurn then return end
    local char = Player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.AutoRotate then return end
    if char:GetAttribute("overridelookscript") then return end
    if char:GetAttribute("Immobile") then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local look = cam.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude > 0 then
        hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flat)
    end
end)

function Byte:Parry()
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local Humanoid = Character:FindFirstChildOfClass('Humanoid')
    local PrimaryPart = Character:FindFirstChild("HumanoidRootPart")
    if not Humanoid or not PrimaryPart then return end

    local animator = Humanoid:FindFirstChildOfClass('Animator')
    if animator then
        local okLoad, fresh = pcall(function()
            return animator:LoadAnimation(Animation_Params)
        end)
        if okLoad and fresh then
            fresh.Priority = Enum.AnimationPriority.Action
            Parry_Track = fresh
            pcall(function() fresh:Play() end)
        end
    end

    Humanoid.AutoRotate = false
    pcall(Byte.RotateTowardCamera, Byte)
    CollectionService:AddTag(PrimaryPart, "doing action")

    pcall(function()
        local SlowRemote = Remotes:FindFirstChild("Mechanics")
            and Remotes.Mechanics:FindFirstChild("Slow")
        if SlowRemote and SlowRemote:IsA("BindableEvent") then
            SlowRemote:Fire(0, 1, 0)
        end
        Parry_Remote:FireServer(Character)
        Byte.Play_Cooldown()
    end)

    task.delay(0.3, function()
        if PrimaryPart and PrimaryPart.Parent then
            pcall(function() CollectionService:RemoveTag(PrimaryPart, "doing action") end)
        end
        if Humanoid and Humanoid.Parent then
            Humanoid.AutoRotate = true
        end
    end)
end

function Byte:ParryCheck(RootPart)
    if not RootPart or not RootPart.Parent then return end
    if not Player.Character then return end
    if not Player.Character:FindFirstChild("Parrying Dagger") then return end
    if not State.AutoParry then return end

    local myRP = Player.Character.PrimaryPart
              or Player.Character:FindFirstChild("HumanoidRootPart")
    if not myRP then return end

    local Direction = (myRP.Position - RootPart.Position).Unit
    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterDescendantsInstances = {Player.Character, RootPart.Parent}
    RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local Raycast = workspace:Raycast(myRP.Position, Direction, RaycastParams)

    if Raycast then return end

    local Selected_Killer
    for _, Value in Players:GetPlayers() do
        if Value ~= Player and Value.Team and Value.Team.Name == "Killer" then
            Selected_Killer = Value:GetAttribute("SelectedKiller")
            break
        end
    end

    local Dot_Product = Direction:Dot(RootPart.CFrame.LookVector)
    local Parry_CD_Bar = Byte.Is_Parry_Ready()
    local Distance = (myRP.Position - RootPart.Position).Magnitude
    local Velocity = RootPart.AssemblyLinearVelocity
    local Speed = Velocity.Magnitude
    local IsMoving = Speed
    local Move_Direction = Speed > 0.01 and Velocity.Unit or Vector3.zero
    local Align_Direction = (myRP.Position - RootPart.Position).Unit
    local Towards_Me = Move_Direction:Dot(Align_Direction) >= 0.8

    local Max_Distance
    local Humanoid = RootPart.Parent:FindFirstChildOfClass('Humanoid')
    if not Humanoid then return end
    local Move_Directions = Humanoid.MoveDirection
    local Verified_Moving = Move_Directions.Magnitude

    if IsMoving >= 5 and Towards_Me then
        Max_Distance = 17.5
    else
        if Selected_Killer == "Veil" then Max_Distance = 4.4
        elseif Selected_Killer == "Abysswalker" then Max_Distance = 6.66
        else Max_Distance = 4 end
    end

    if Selected_Killer == 'Abysswalker' and Distance <= 15 and Verified_Moving > 0 then Max_Distance = 17.5 end
    if Selected_Killer == 'Abysswalker' and Distance <= 25 and IsMoving >= 18 and Towards_Me then Max_Distance = 23.5 end

    local Max_Dot_Product = Distance / (Max_Distance * (Towards_Me and 1.25 or 1.1))

    if Parry_CD_Bar and Distance <= Max_Distance and Dot_Product >= Max_Dot_Product then
        Byte:Parry()
    end
end

function Byte:ParrySetup(Character)
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
                   or Character:WaitForChild("Humanoid", 10)
    if not Humanoid then return end

    local function findSwingArm()
        return Character:FindFirstChild("Right Arm")
            or Character:FindFirstChild("RightHand")
            or Character:FindFirstChild("RightLowerArm")
            or Character:FindFirstChild("RightUpperArm")
    end
    local RightArm = findSwingArm()
    if not RightArm then
        local deadline = tick() + 5
        while tick() < deadline and not RightArm do
            RightArm = findSwingArm()
            if not RightArm then task.wait(0.1) end
        end
    end
    if not RightArm then return end

    local RootPart = Humanoid.RootPart or Character:FindFirstChild("HumanoidRootPart")
    if not RootPart then return end

    local function safeCheck()
        pcall(Byte.ParryCheck, Byte, RootPart)
    end

    local Swing = RightArm:FindFirstChild("Swing")
    if Swing and Swing:IsA("Sound") then
        Swing.Played:Connect(safeCheck)
    end

    RightArm.ChildAdded:Connect(function(Child)
        if not Child:IsA("Sound") then return end
        safeCheck()
        if Child.IsPlaying then safeCheck() end
        Child.Played:Connect(safeCheck)
    end)

    local Active_Attacks = {}
    Humanoid.AnimationPlayed:Connect(function(Track)
        if Track.Looped then return end
        local Track_Priority = Track.Priority
        if Track_Priority ~= Enum.AnimationPriority.Action and Track_Priority ~= Enum.AnimationPriority.Action2 then return end
        local Animation = Track.Animation
        local ID = Animation and Animation.AnimationId
        if not ID then return end
        if Active_Attacks[ID] then return end

        safeCheck()
        Active_Attacks[ID] = true
        Track.Stopped:Once(function() Active_Attacks[ID] = nil end)
    end)
end

function Byte:PlayerSetup(Entity)
    if Entity.Character then Byte:ParrySetup(Entity.Character) end
    Entity.CharacterAdded:Connect(function(Character) Byte:ParrySetup(Character) end)
end

Players.PlayerAdded:Connect(function(Player_) Byte:PlayerSetup(Player_) end)
for _, Value in Players:GetPlayers() do
    if Value ~= Player then Byte:PlayerSetup(Value) end
end

Player.CharacterAdded:Connect(function(newCharacter)
    Animation_Params.AnimationId = 'rbxassetid://109133187196613'
    local newHumanoid = newCharacter:WaitForChild('Humanoid')
    local newAnimator = newHumanoid:WaitForChild('Animator')
    local ok, fresh = pcall(function()
        return newAnimator:LoadAnimation(Animation_Params)
    end)
    if ok and fresh then
        fresh.Priority = Enum.AnimationPriority.Action
        Parry_Track = fresh
    end
end)

local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu', 'wrench')
MenuGroup:AddButton({
    Text = 'Unload',
    Callback = function()
        State.Unloaded = true
        pcall(function() Byte_UnmuteStun() end)
        pcall(function() UnmuteShake() end)

        for name, conn in pairs(Connections_Manager) do
            if typeof(conn) == "RBXScriptConnection" then
                pcall(function() conn:Disconnect() end)
            end
        end

        pcall(function()
            local coreGui = game:GetService("CoreGui")
            local folder = coreGui:FindFirstChild("Byte_ESP")
            if folder then folder:Destroy() end
        end)
        table.clear(ESP_Objects)

        pcall(function()
            if Env and Env._WatermarkGui then
                Env._WatermarkGui:Destroy()
                Env._WatermarkGui = nil
            end
        end)

        pcall(function()
            local char = Player.Character
            if char then
                char:SetAttribute("vaultspeed", 1)
                char:SetAttribute("skillcheckspeed", 1)
                char:SetAttribute("unhookspeed", 1)
                char:SetAttribute("repairboost", 1)
                char:SetAttribute("Immobile", false)
                char:SetAttribute("IsStunned", false)
            end
        end)

        Library:Unload()
    end
})

MenuGroup:AddToggle('Watermark_Toggle', {
    Text = 'Watermark',
    Default = true,
    Callback = function(v)
        if Env and Env._WatermarkGui then
            Env._WatermarkGui.Enabled = v
        end
    end,
})

ThemeManager:SetLibrary(Window)
ThemeManager:SetFolder('Byte')
SaveManager:SetLibrary(Window)
SaveManager:SetFolder('Byte')
SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

local _lastParryTime = 0
Connections_Manager['AutoParry'] = RunService.PreSimulation:Connect(function()
    if State.Unloaded or not State.AutoParry then return end
    if tick() - _lastParryTime < 0.4 then return end
    local myChar = Player.Character
    if not myChar then return end
    local myRP = myChar.PrimaryPart or myChar:FindFirstChild("HumanoidRootPart")
    if not myRP then return end
    for _, Value in Players:GetPlayers() do
        if Value ~= Player and Value.Team and Value.Team.Name == 'Killer' then
            if not Value.Character then continue end
            local Right_Arm = Value.Character:FindFirstChild('Right Arm')
                or Value.Character:FindFirstChild('RightHand')
                or Value.Character:FindFirstChild('RightLowerArm')
                or Value.Character:FindFirstChild('RightUpperArm')
            if not Right_Arm then continue end
            local Selected_Killer
            for _, Values in Players:GetPlayers() do
                if Values ~= Player and Values.Team and Values.Team.Name == "Killer" then
                    Selected_Killer = Value:GetAttribute("SelectedKiller")
                    break
                end
            end

            local Max_Distance
            local HRP = Value.Character:FindFirstChild("HumanoidRootPart")
            if not HRP then continue end
            local Velocity = HRP.AssemblyLinearVelocity
            local Move_Direction = Velocity.Magnitude > 0.01 and Velocity.Unit or Vector3.zero
            local Align_Direction = (myRP.Position - HRP.Position).Unit
            local Towards_Me = Move_Direction:Dot(Align_Direction) >= 0.8

            if Selected_Killer == "Veil" then Max_Distance = 4.4
            elseif Selected_Killer == "Abysswalker" then Max_Distance = 6.66
            else Max_Distance = 4 end

            local Parry_CD_Bar = Byte.Is_Parry_Ready()
            local Distance = (myRP.Position - HRP.Position).Magnitude
            local Direction = (myRP.Position - HRP.Position).Unit
            local Dot_Product = Direction:Dot(HRP.CFrame.LookVector)
            local Max_Dot_Product = Distance / (Max_Distance * (Towards_Me and 1.25 or 1.1))

            for _, Part in Right_Arm:GetChildren() do
                if Part:IsA('Sound') and Part.IsPlaying then
                    if Parry_CD_Bar and Distance <= Max_Distance and Dot_Product >= Max_Dot_Product then
                        _lastParryTime = tick()
                        Byte:Parry()
                        Part:Stop()
                    end
                end
            end
        end
    end
end)

local HitPart = nil
Connections_Manager['SilentAim'] = RunService.Heartbeat:Connect(function()
    if State.Unloaded then return end
    if Player.Team and Player.Team.Name ~= "Spectator" and Player.Character and Player.Character.PrimaryPart then
        local Target = nil
        local Closest = math.huge
        for _, Value in Players:GetPlayers() do
            if Value == Player then continue end
            if Value.Team and Value.Team.Name == "Spectator" then continue end

            local Humanoid = (Value.Character and Value.Character:FindFirstChildOfClass("Humanoid"))
            local RootPart = (Humanoid and Humanoid.RootPart)
            if not RootPart then continue end

            local Position, Visible = workspace.CurrentCamera:WorldToScreenPoint(RootPart.Position)
            if not Visible then continue end

            local Distance = (Vector2.new(Position.X, Position.Y) - UserInputService:GetMouseLocation()).Magnitude
            if Distance > Closest then continue end

            local Direction = (RootPart.Position - Player.Character.PrimaryPart.Position).Unit * (RootPart.Position - Player.Character.PrimaryPart.Position).Magnitude
            local RaycastParams = RaycastParams.new()
            RaycastParams.FilterDescendantsInstances = {Player.Character, Value.Character}
            RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
            local Raycast = workspace:Raycast(Player.Character.PrimaryPart.Position, Direction, RaycastParams)

            if Raycast then continue end

            local TargetPart = Value.Character:FindFirstChild("Head") or RootPart
            Target = TargetPart
            Closest = Distance
            if Value.Team and Value.Team.Name == "Killer" then break end
        end
        HitPart = Target
    else
        HitPart = nil
    end
end)

if getidentity() >= 7 then
    local Namecall; Namecall = hookmetamethod(game, "__namecall", function(Self, ...)
        local Method = getnamecallmethod()
        local Args = {...}
        if not (checkcaller and checkcaller()) and Method == "FireServer" and Self == Fire_Remote and Toggles.Silent_Aim_Toggle.Value and HitPart then
            local Direction = CFrame.new(workspace.CurrentCamera.CFrame.Position, HitPart.Position)
            Args[2] = Direction.LookVector
            return Namecall(Self, unpack(Args))
        end
        return Namecall(Self, ...)
    end)
end
