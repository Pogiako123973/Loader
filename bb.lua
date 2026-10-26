local Env: any = getgenv()
if Env.Visual_Unload then pcall(Env.Visual_Unload) end
repeat task.wait() until game:IsLoaded()
Env.Unlock_Enabled = (Env.Unlock_Enabled == nil) and false or Env.Unlock_Enabled
_G.__TitleState = _G.__TitleState or { Selected = nil }
Env.Selected_Finisher = Env.Selected_Finisher or false
Env.FinisherEquipped = Env.FinisherEquipped or {}
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
Env.WantImmortality = false
pcall(function() game:GetService('RunService'):UnbindFromRenderStep("CamFix") end)
local Debris = game:GetService('Debris')
local TweenService = game:GetService('TweenService')
local Stats = game:GetService('Stats')
local Pings = Stats.Network.ServerStatsItem['Data Ping']

local PING_SAMPLE_INTERVAL = 0.05
local PING_ALPHA_UP, PING_ALPHA_DOWN = 0.4, 0.08
local PING_JITTER_WEIGHT = 1.5
local Ping_Mean, Ping_Jitter, Comp_Ping, Ping_Sample_At = nil, 0, 0, 0

local function Get_Comp_Ping()
    local Now = os.clock()
    if Now - Ping_Sample_At < PING_SAMPLE_INTERVAL then return Comp_Ping end
    Ping_Sample_At = Now

    local Raw = math.clamp(Pings:GetValue(), 0, 500)
    if not Ping_Mean then
        Ping_Mean = Raw
    else
        local Diff = Raw - Ping_Mean
        Ping_Mean += Diff * (Diff > 0 and PING_ALPHA_UP or PING_ALPHA_DOWN)
        Ping_Jitter += (math.abs(Diff) - Ping_Jitter) * PING_ALPHA_DOWN
    end
    Comp_Ping = math.clamp(Ping_Mean + Ping_Jitter * PING_JITTER_WEIGHT, 0, 500)
    return Comp_Ping
end

local GuiService = game:GetService('GuiService')
local Lighting = game:GetService('Lighting')
local Menu_Is_Open = false

local BallsFolder = workspace:WaitForChild("Balls")
local AliveFolder = workspace:WaitForChild("Alive")
local RuntimeFolder = workspace:WaitForChild("Runtime")

local Connections_Manager = {}
local _ScriptUnloaded = false

Connections_Manager['GuiService_MenuOpened'] = GuiService.MenuOpened:Connect(function()
    Menu_Is_Open = true
end)

Connections_Manager['GuiService_MenuClosed'] = GuiService.MenuClosed:Connect(function()
    Menu_Is_Open = false
end)

do
    local WatermarkGui = Instance.new('ScreenGui')
    WatermarkGui.Name = 'ByteWatermark'
    WatermarkGui.ResetOnSpawn = false
    WatermarkGui.IgnoreGuiInset = true
    WatermarkGui.DisplayOrder = 999
    WatermarkGui.Parent = (typeof(gethui) == 'function' and gethui()) or game:GetService('CoreGui')
    WatermarkGui.Enabled = false

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
            local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
            if playerGui then
                for _, desc in ipairs(playerGui:GetDescendants()) do
                    if desc:IsA("TextLabel") and desc.Text:find("Server Region:") then
                        return string.gsub(desc.Text, "Server Region:%s*", "")
                    end
                end
            end
            
            local coreGui = game:GetService("CoreGui")
            if coreGui then
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
local Parry_Input_Method = "Remote"
local KEYPRESS_INTERVAL = 0.06
local Keypress_Last_Fire = 0

local Player = Players.LocalPlayer
local Server_Ball_Positions = setmetatable({}, { __mode = 'k' })
local Library = nil
local ThemeManager = nil  
local SaveManager = nil
local Window = nil

local Auto_Parry = {}

do
    local AnimationController = require(ReplicatedStorage.Controllers.AnimationController)
    local SwordApi = require(ReplicatedStorage.Shared.SwordAPI)
    local Swords = require(ReplicatedStorage.Shared.ReplicatedInstances.Swords)

    Auto_Parry.Parry_Animation = function()
        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local Animator = Humanoid and Humanoid:FindFirstChildOfClass("Animator")
        if not Animator then
            return
        end

        local Attribute = Character:GetAttribute("CurrentlyEquippedSword") or Player:GetAttribute("CurrentlyEquippedSword")
        if not Attribute then
            return
        end

        local SwordInfo = Swords:GetSword(Attribute)
        if not SwordInfo or Character ~= Player.Character then
            return
        end

        local Tracks = {}
        for _, Animation in SwordApi:GetAnimations(Character, {"Parry", "GrabParry"}, SwordInfo.AnimationType, SwordInfo.SwordType) do
            Tracks[#Tracks + 1] = AnimationController:LoadAnimation(Animator, Animation, true)
        end

        for _, track in AnimationController:GetPlayingAnimationTracks(Animator) do
            local Name = track.Name
            if Name == 'GrabParry' or Name == 'Grab' or Name == 'SuccessParry' or Name == 'Success' then
                track:Stop(track:GetAttribute('StopFadeTime') or 0.1)
            end
        end

        for _, track in ipairs(Tracks) do
            local speed = track:GetAttribute("PlaySpeed") or 1
            track.Priority = Enum.AnimationPriority.Action4
            track.Looped = false
            track:Play(track:GetAttribute("PlayFadeTime") or 0, track:GetAttribute("PlayWeight") or 1, speed)
            track.TimePosition = 0
            Character:SetAttribute("ParryTime", math.max(Character:GetAttribute("ParryTime") or 0, track.Length == 0 and 1 or (track.Length - track.TimePosition) * speed))
        end
    end

    Connections_Manager['Parry Animation Success'] = ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
        if _ScriptUnloaded then return end
        local Character = Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass('Humanoid')
        local Animator = Humanoid and Humanoid:FindFirstChildOfClass('Animator')
        if not Animator then return end

        for _, track in Animator:GetPlayingAnimationTracks() do
            if track.Name == 'GrabParry' or track.Name == 'Grab' or track.Name == 'Parry' then
                track:Stop(track:GetAttribute('StopFadeTime') or 0.1)
            end
        end
    end)
end

-- remote
local function Child(parent, name)
    return parent:WaitForChild(name, 10)
end

local Upvalues = ((debug and debug.getupvalues) or getupvalues)(require(
    Child(Child(Child(ReplicatedStorage, "Controllers"), "SwordsController \012"), "PRY")
))
local Key, Hash, JobId = Upvalues[3][3], Upvalues[8], game.JobId

if Hash:find("PARRY_HASH_FAKE", 1, true) then
    Hash = nil
end

local Encoded = table.create(#Upvalues[7])

for i = 1, #Upvalues[7] do
    Encoded[i] = string.char(
        (Upvalues[7]:byte(i) - 32 + JobId:byte((i - 1) % #JobId + 1)) % 95 + 32
    )
end

local Remote = Child(
    Child(Child(Child(Child(ReplicatedStorage, "Packages"), "_Index"), "sleitnick_net@0.1.0"), "net"),
    "RE/" .. crypt.hash(
        table.concat(Encoded) .. "bd93afff-8aba-409d-9946-a875f6c33087" .. JobId,
        "sha256"
    )
)

local function Parry_Token()
    local Pad = Upvalues[4](Key, 'TIME')
    local ST = tostring(math.floor(workspace:GetServerTimeNow() * 100))
    local TK = {}
    for i = 1, #ST do
        TK[i] = string.char(bit32.bxor((string.byte(ST, i) + i) % 256, string.byte(Pad, (i - 1) % #Pad + 1)))
    end
    return table.concat(TK)
end

task.spawn(function()
    local Net_Folder
    Net_Folder = ReplicatedStorage.Packages._Index['sleitnick_net@0.1.0'].net
    if not Net_Folder then return end

    for _, Remote in Net_Folder:GetChildren() do
        if Remote:IsA('UnreliableRemoteEvent') and Remote.Name ~= 'URE/ReplicateBallPosition' then
            Connections_Manager['Real Ball Position - ' .. Remote.Name] = Remote.OnClientEvent:Connect(function(Ball, Server_Position)
                if typeof(Ball) ~= 'Instance' then return end
                if not Ball.Parent then
                    Server_Ball_Positions[Ball] = nil
                    return
                end
                if typeof(Server_Position) == 'Vector3' then
                    Server_Ball_Positions[Ball] = Server_Position
                end
            end)
        end
    end
end)

local function GetBallPosition(ball)
    return Server_Ball_Positions[ball] or ball.Position
end

function Auto_Parry.Get_Balls(single)
    local List = {}
    local Folder = BallsFolder
    if not Folder or Folder.Parent ~= workspace then
        Folder = workspace:FindFirstChild('Balls')
        BallsFolder = Folder
    end
    if not Folder then
        if single then return nil end
        return List
    end

    for _, Ball in ipairs(Folder:GetChildren()) do
        if Ball:IsA('BasePart') and Ball:GetAttribute('realBall') == true then
            if single then return Ball end
            List[#List + 1] = Ball
        end
    end

    if single then return nil end
    return List
end

local Target_Ball = nil

function Auto_Parry.Get_Targeting_Balls()
    return Target_Ball
end

local CURVE_DOT_THRESHOLD = 0.5

function Auto_Parry.Is_Curved(Offset, Velocity, Ball_Velocity)
    if Ball_Velocity:Dot(Offset) < 0 then return true end

    local Speed = Velocity.Magnitude
    if Speed < 0.001 then return true end
    local Distance = Offset.Magnitude
    if Distance < 0.001 then return false end
    return Offset:Dot(Velocity) / (Distance * Speed) < CURVE_DOT_THRESHOLD
end

local Local_Player_Name = Player.Name

local Vector2_Mouse_Location = nil
local Is_Mobile = UserInputService.TouchEnabled
if Is_Mobile then Parry_Input_Method = "Remote" end

local RT_Random = Random.new()

function Auto_Parry.Parry_Data(Parry_Type)
    local Cam = workspace.CurrentCamera
    local ViewportSize = Cam.ViewportSize
    
    local Mouse_X, Mouse_Y
    if Is_Mobile then
        Mouse_X = ViewportSize.X * 0.5
        Mouse_Y = ViewportSize.Y * 0.5
    else
        local Mouse_Location = UserInputService:GetMouseLocation()
        Mouse_X = Mouse_Location.X
        Mouse_Y = Mouse_Location.Y
    end
    Vector2_Mouse_Location = {Mouse_X, Mouse_Y}

    local Events = {}
    local Character = Player.Character
    local MyRoot = Character and Character.PrimaryPart
    local Cam_Pos = Cam.CFrame.Position

    if not MyRoot then
        return {0, CFrame.new(Cam_Pos, Cam_Pos + Cam.CFrame.LookVector), Events, Vector2_Mouse_Location}
    end

    local My_Pos = MyRoot.Position
    local My_Name = Player.Name

    local Mouse_Direction = nil
    local Best_Target = nil
    local Best_Dot = -math.huge
    local candidates = Parry_Type == 'RandomTarget' and {} or nil

    if Parry_Type == 'Dot' or Parry_Type == 'InstaDot' then
        local Mouse_Ray = Cam:ScreenPointToRay(Mouse_X, Mouse_Y)
        Mouse_Direction = Mouse_Ray.Direction
    end

    for _, Instance in AliveFolder:GetChildren() do
        local Target_Root = Instance.PrimaryPart
        if Target_Root then
            local Target_Pos = Target_Root.Position
            Events[Instance.Name] = Cam:WorldToScreenPoint(Target_Pos)

            if Instance.Name ~= My_Name then
                if Parry_Type == 'Dot' or Parry_Type == 'InstaDot' then
                    local Enemy_Direction = (Target_Pos - Cam_Pos).Unit
                    local Dot = Mouse_Direction:Dot(Enemy_Direction)
                    if Dot > Best_Dot then
                        Best_Dot = Dot
                        Best_Target = Instance
                    end
                elseif Parry_Type == 'RandomTarget' then
                    local pos, onScreen = Cam:WorldToScreenPoint(Target_Pos)
                    if onScreen then
                        candidates[#candidates + 1] = { Instance, pos }
                    end
                end
            end
        end
    end

    if Parry_Type == 'Camera' then
        return {0, CFrame.new(Cam_Pos, Cam_Pos + Cam.CFrame.LookVector), Events, Vector2_Mouse_Location}
    end

    if Parry_Type == 'Backward' then
        local Backwards_Direction = -Cam.CFrame.LookVector * 10000
        Backwards_Direction = Vector3.new(Backwards_Direction.X, 0, Backwards_Direction.Z)
        return {0, CFrame.new(Cam_Pos, Cam_Pos + Backwards_Direction), Events, Vector2_Mouse_Location}
    end

    if Parry_Type == 'Random' then
        return {0, CFrame.new(Cam_Pos, Vector3.new(math.random(-3000, 3000), math.random(-3000, 3000), math.random(-3000, 3000))), Events, Vector2_Mouse_Location}
    end

    if Parry_Type == 'Dot' then
        local Target_Position = (Best_Target and Best_Target.PrimaryPart)
            and Best_Target.PrimaryPart.Position
            or (My_Pos + Cam.CFrame.LookVector * 1000)

        local Aimed_Position = CFrame.lookAt(My_Pos, Target_Position + Vector3.new(0, 2, 0))
        return {0, Aimed_Position, Events, Vector2_Mouse_Location}
    end

    if Parry_Type == 'InstaDot' then
        local Target_Position = (Best_Target and Best_Target.PrimaryPart)
            and Best_Target.PrimaryPart.Position
            or (My_Pos + Cam.CFrame.LookVector * 1000)

        local Aimed_Position = CFrame.lookAt(My_Pos, Target_Position)
        local Screen_Pos = Cam:WorldToScreenPoint(Target_Position)
        return {0, Aimed_Position, Events, {Screen_Pos.X, Screen_Pos.Y}}
    end

    if Parry_Type == 'RandomTarget' then
        local pick
        if candidates and #candidates > 0 then
            pick = candidates[RT_Random:NextInteger(1, #candidates)][1]
        end

        if pick then
            local aimAt = pick.PrimaryPart.Position + Vector3.new(
                RT_Random:NextNumber(-1.8, 1.8),
                RT_Random:NextNumber(-0.6, 1.8),
                RT_Random:NextNumber(-1.8, 1.8)
            )
            local pos = Cam:WorldToScreenPoint(aimAt)
            return {
                0,
                CFrame.new(My_Pos, aimAt),
                Events,
                { pos.X + RT_Random:NextNumber(-45, 45), pos.Y + RT_Random:NextNumber(-45, 45) },
            }
        end

        local randDir = Vector3.new(
            RT_Random:NextNumber(-3000, 3000),
            RT_Random:NextNumber(-3000, 3000),
            RT_Random:NextNumber(-3000, 3000)
        )
        return {
            0,
            CFrame.new(Cam_Pos, Cam_Pos + randDir),
            Events,
            {
                Cam.ViewportSize.X / 2 + RT_Random:NextNumber(-80, 80),
                Cam.ViewportSize.Y / 2 + RT_Random:NextNumber(-80, 80),
            },
        }
    end

    return {0, CFrame.new(Cam_Pos, Cam_Pos + Cam.CFrame.LookVector), Events, Vector2_Mouse_Location}
end

local Auto_Abilities = {'Calming Deflection', 'Raging Deflection', 'Rapture', 'Aerodynamic Slash', 'Slashes of Fury', 'Singularity'}
local Protect_Abilities = {'Calming Deflection', 'Raging Deflection', 'Rapture', 'Aerodynamic Slash', 'Forcefield', 'Singularity', 'Invisibility', 'Telekinesis', 'Ninja Dash', 'Continuity Zero', 'Infinity', 'Time Hole', 'Dribble', 'Slashes of Fury', 'Phantom', 'Dragon Spirit', 'Quantum Arena'}
local Use_Ability = ReplicatedStorage.Remotes.AbilityButtonPress

local function Get_Hotbar_Gradient(Slot)
    local PlayerGui = Player:FindFirstChild('PlayerGui')
    local Hotbar = PlayerGui and PlayerGui:FindFirstChild('Hotbar')
    local Button = Hotbar and Hotbar:FindFirstChild(Slot)
    return Button and Button:FindFirstChildOfClass('UIGradient')
end

local Parried = false
local Last_Parry = 0
local Parries = 0

local function Find_Target()
    for _, Ball in BallsFolder:GetChildren() do
        if Ball:GetAttribute('realBall') and Ball:GetAttribute('target') == Local_Player_Name then
            return Ball
        end
    end
end

local function On_Target_Changed(Ball)
    if Ball == Target_Ball then Parried = false end
    Target_Ball = Find_Target()
end

local Parry_Times = {}
local PARRY_HISTORY = 1

local function Note_Parry(Now)
    Parry_Times[#Parry_Times + 1] = Now
    while Parry_Times[1] and Now - Parry_Times[1] > PARRY_HISTORY do
        table.remove(Parry_Times, 1)
    end
end

local function Recent_Parries(Now, Window)
    local Count = 0
    for i = #Parry_Times, 1, -1 do
        if Now - Parry_Times[i] > Window then break end
        Count += 1
    end
    return Count
end

local Clash_Info = setmetatable({}, { __mode = 'k' })

local function Record_Target(Ball)
    local Now, Target = os.clock(), Ball:GetAttribute('target')
    if not Target or Target == '' then return end

    local Info = Clash_Info[Ball]
    if not Info then
        Clash_Info[Ball] = { Time = Now, Target = Target }
        return
    end
    Info.Previous, Info.Time, Info.Target = Info.Target, Now, Target
end

local Ball_Watch = {}
Connections_Manager['Target_Ball_Watch'] = Ball_Watch

local function Watch_Ball(Ball)
    Ball_Watch[Ball] = Ball:GetAttributeChangedSignal('target'):Connect(function()
        Record_Target(Ball)
        On_Target_Changed(Ball)
    end)
    Record_Target(Ball)
    On_Target_Changed(Ball)
end

for _, Ball in BallsFolder:GetChildren() do Watch_Ball(Ball) end
Connections_Manager['Target_Ball_Added'] = BallsFolder.ChildAdded:Connect(Watch_Ball)
Connections_Manager['Target_Ball_Removed'] = BallsFolder.ChildRemoved:Connect(function(Ball)
    if Ball_Watch[Ball] then Ball_Watch[Ball]:Disconnect(); Ball_Watch[Ball] = nil end
    Clash_Info[Ball] = nil
    On_Target_Changed(Ball)
end)

function Auto_Parry.Parry(Parry_Type, Silent)
    if Parry_Input_Method == "Keypress" then
        local now = os.clock()
        if (now - Keypress_Last_Fire) < KEYPRESS_INTERVAL then
            return false
        end
        Keypress_Last_Fire = now

        if not isrbxactive() or Menu_Is_Open then
            Parry_Input_Method = "Remote"
            Auto_Parry.Parry(Parry_Type)
            Parry_Input_Method = "Keypress"
            return true
        end

        keypress(0x46)
        keyrelease(0x46)

        if Env.Cooldown_Protection and (now - Last_Parry) > 0.5 then
            task.delay(0.15, function()
                if Parried then return end
                local Character = Player.Character
                local Abilities = Character and Character:FindFirstChild('Abilities')
                if not Abilities then return end
                for _, Ability in Protect_Abilities do
                    if Abilities:FindFirstChild(Ability) and Abilities[Ability].Enabled then
                        Use_Ability:Fire()
                        break
                    end
                end
            end)
        end
        return true
    end

    local Parry_Data = Auto_Parry.Parry_Data(Parry_Type)
    Remote:FireServer(Hash, Key, Parry_Token(), Parry_Data[1], Parry_Data[2], Parry_Data[3], Parry_Data[4], false)

    if not Silent and not Connections_Manager['Manual Spam'] then
        Auto_Parry.Parry_Animation()
    end
    
    if Parries >= 7 then return false end

    Parries += 1
    task.delay(0.05, function()
        if Parries > 0 then Parries -= 1 end
    end)
end

local GlowSettings = {
    Enabled = false,
    LifetimeMul = 1.4,
    MinLifetime = 0.3,
    LightEmission = 1,
    LightInfluence = 0,
    Color = ColorSequence.new(Color3.new(1, 1, 1)),
    Transparency = NumberSequence.new(0)
}

local ActiveBalls = {}
local BallTrailConnections = {}

local SUPPRESS_FOLDER_NAMES = { clash = true, Runtime = true }

local OriginalTrailData = setmetatable({}, {__mode = "k"})

local function BoostTrail(ball, trail)
    if trail:GetAttribute("GlowBoosted") then return end
    local original = {
        Lifetime = trail.Lifetime,
        LightEmission = trail.LightEmission,
        LightInfluence = trail.LightInfluence,
        Color = trail.Color,
        Transparency = trail.Transparency,
    }
    trail.Lifetime = math.max(GlowSettings.MinLifetime, original.Lifetime) * GlowSettings.LifetimeMul
    trail.LightEmission = GlowSettings.LightEmission
    trail.LightInfluence = GlowSettings.LightInfluence
    trail.Color = GlowSettings.Color
    trail.Transparency = GlowSettings.Transparency
    trail:SetAttribute("GlowBoosted", true)
    local data = OriginalTrailData[ball] or {}
    data[trail] = original
    OriginalTrailData[ball] = data
end

local function AddGlow(ball)
    if not GlowSettings.Enabled then return end
    if not ball or not ball:IsA("BasePart") then return end
    if ActiveBalls[ball] then return end

    ActiveBalls[ball] = true

    for _, child in ipairs(ball:GetDescendants()) do
        if child:IsA("Trail") then BoostTrail(ball, child) end
    end

    if BallTrailConnections[ball] then
        BallTrailConnections[ball]:Disconnect()
    end
    BallTrailConnections[ball] = ball.DescendantAdded:Connect(function(child)
        if child:IsA("Trail") then BoostTrail(ball, child) end
    end)
end

local function UnboostBallTrails(ball)
    local data = OriginalTrailData[ball]
    if not data then return end
    for trail, original in pairs(data) do
        if trail and trail.Parent then
            trail.Lifetime = original.Lifetime
            trail.LightEmission = original.LightEmission
            trail.LightInfluence = original.LightInfluence
            trail.Color = original.Color
            trail.Transparency = original.Transparency
            trail:SetAttribute("GlowBoosted", nil)
        end
    end
    OriginalTrailData[ball] = nil
end

local function RemoveGlow(ball)
    if not ball then return end

    if BallTrailConnections[ball] then
        BallTrailConnections[ball]:Disconnect()
        BallTrailConnections[ball] = nil
    end

    UnboostBallTrails(ball)

    for _, v in ipairs(ball:GetDescendants()) do
        if (v:IsA("Trail") or v:IsA("Beam") or v:IsA("ParticleEmitter")) and v:GetAttribute("ClientGlowDisabled") then
            v.Enabled = true
            v:SetAttribute("ClientGlowDisabled", nil)
        end
    end

    ActiveBalls[ball] = nil
end

local function SweepExistingClashEffects()
    task.spawn(function()
        local YIELD = 1500
        local Iter = 0
        for _, v in ipairs(workspace:GetDescendants()) do
            Iter += 1
            if (Iter % YIELD) == 0 then task.wait() end
            if not GlowSettings.Enabled then return end
            if not v:GetAttribute("ClientGlowDisabled") then
                local p = v.Parent
                local isClash = false
                while p and p ~= workspace do
                    if p.Name == "clash" or p.Name == "Runtime" then isClash = true; break end
                    p = p.Parent
                end
                if isClash then
                    local ok = pcall(function() v.Enabled = false end)
                    if ok then
                        v:SetAttribute("ClientGlowDisabled", true)
                        if v:IsA("ParticleEmitter") then pcall(function() v:Clear() end) end
                    end
                end
            end
        end
    end)
end

local function DisconnectGlowListeners()
    for _, key in ipairs({ 'Glow_DescendantAdded', 'Glow_BallRemoved', 'Glow_BallAdded' }) do
        local conn = Connections_Manager[key]
        if conn then
            conn:Disconnect()
            Connections_Manager[key] = nil
        end
    end
end

local function ConnectGlowListeners()
    if not Connections_Manager['Glow_DescendantAdded'] then
        Connections_Manager['Glow_DescendantAdded'] = workspace.DescendantAdded:Connect(function(v)
            if not GlowSettings.Enabled then return end
            if not v:IsA("Trail") and not v:IsA("Beam") and not v:IsA("ParticleEmitter") then return end
            task.defer(function()
                if not v.Parent then return end
                local p = v.Parent
                while p and p ~= workspace do
                    if SUPPRESS_FOLDER_NAMES[p.Name] then
                        v.Enabled = false
                        v:SetAttribute("ClientGlowDisabled", true)
                        if v:IsA("ParticleEmitter") then v:Clear() end
                        return
                    end
                    p = p.Parent
                end
            end)
        end)
    end

    if not Connections_Manager['Glow_BallRemoved'] then
        Connections_Manager['Glow_BallRemoved'] = BallsFolder.ChildRemoved:Connect(function(ball)
            RemoveGlow(ball)
        end)
    end

    if not Connections_Manager['Glow_BallAdded'] then
        Connections_Manager['Glow_BallAdded'] = BallsFolder.ChildAdded:Connect(function(ball)
            task.wait(0.05)
            AddGlow(ball)
        end)
    end
end

local function SetBallGlow(state)
    GlowSettings.Enabled = state

    for ball in pairs(ActiveBalls) do
        RemoveGlow(ball)
    end

    if state then
        ConnectGlowListeners()
        for _, ball in ipairs(BallsFolder:GetChildren()) do
            AddGlow(ball)
        end
        SweepExistingClashEffects()
    else
        DisconnectGlowListeners()
    end
end

local SkinChanger = {}
local Billboard_Banner = {}
local SkinCache_Folder = Instance.new('Folder')
local SkinOriginal_Folder = Instance.new('Folder')

local SkinConfig = {
    Current_User_ID = nil,
    Cache_User_ID = nil,
    Default_Description = nil,
    Original_Captured = false,
    Applied_Characters = {},
    Preset_Skins = {
        ['Headless'] = {
            Name = 'Headless',
            Description = '',
            Apply = function(character) SkinChanger.SetHeadlessState(character, true) end,
            Restore = function(character) SkinChanger.SetHeadlessState(character, false) end
        },
        ['Korblox'] = {
            Name = 'Korblox Deathspeaker',
            Description = '',
            Apply = function(character) SkinChanger.SetKorbloxState(character, true) end,
            Restore = function(character) SkinChanger.SetKorbloxState(character, false) end
        }
    },
    Active_Presets = {}
}

local function Skin_ApplyDescription(Humanoid, Desc)
    if not Humanoid or not Desc then return false end
    local methods = {
        { name = 'ApplyDescription', args = function() return { Desc } end },
        { name = 'ApplyDescriptionClientServer', args = function() return { Desc } end },
    }
    for _, m in ipairs(methods) do
        local has = false
        has = typeof(Humanoid[m.name]) == 'function'
        if has then
            local ok = true, (function() Humanoid[m.name](Humanoid, table.unpack(m.args())) end)()
            if ok then return true end
        end
    end
    return false
end

local function Skin_FindAttach(Character, name)
    for _, part in pairs(Character:GetChildren()) do
        if part:IsA('BasePart') then
            local att = part:FindFirstChild(name)
            if att and att:IsA('Attachment') then return att end
        end
    end
    return nil
end

local function Skin_WeldAccessory(Character, Acc)
    local Handle = Acc:FindFirstChild('Handle')
    if not Handle then Acc.Parent = Character; return end
    for _, w in pairs(Handle:GetChildren()) do
        if w:IsA('Weld') or w:IsA('Motor6D') or w:IsA('WeldConstraint') then w:Destroy() end
    end
    local handleAtt = Handle:FindFirstChildOfClass('Attachment')
    local charAtt = handleAtt and Skin_FindAttach(Character, handleAtt.Name)
    local part1, c0, c1
    if charAtt then
        part1 = charAtt.Parent
        c0 = handleAtt.CFrame
        c1 = charAtt.CFrame
    else
        part1 = Character:FindFirstChild('Head') or Character:FindFirstChild('HumanoidRootPart')
        c0 = CFrame.new()
        c1 = CFrame.new(0, 0.5, 0)
    end
    if not part1 then Acc.Parent = Character; return end
    Handle.Anchored = false
    Handle.CanCollide = false
    Handle.Massless = true
    local weld = Instance.new('Weld')
    weld.Name = 'SkinWeld'
    weld.Part0 = Handle
    weld.Part1 = part1
    weld.C0 = c0
    weld.C1 = c1
    weld.Parent = Handle
    Acc.Parent = Character
end

local Skin_BodyParts = { 'Head', 'Torso', 'Left Arm', 'Right Arm', 'Left Leg', 'Right Leg' }

local function Skin_IsTopItem(v)
    return v:IsA('Accessory') or v:IsA('Shirt') or v:IsA('Pants') or v:IsA('ShirtGraphic')
        or v:IsA('CharacterMesh') or v:IsA('BodyColors')
end

local function Skin_IsPartVisual(v, isHead)
    if v:IsA('DataModelMesh') then return true end
    return isHead and (v:IsA('Decal') or v:IsA('SurfaceAppearance') or v:IsA('FaceControls'))
end

local function Skin_StripAppearance(Character)
    for _, v in pairs(Character:GetChildren()) do
        if Skin_IsTopItem(v) then v:Destroy() end
    end
    for _, name in ipairs(Skin_BodyParts) do
        local part = Character:FindFirstChild(name)
        if part then
            for _, d in pairs(part:GetChildren()) do
                if Skin_IsPartVisual(d, name == 'Head') then d:Destroy() end
            end
        end
    end
end

local function Skin_BuildDummy(userId)
    local dummy
    do
        local desc = Players:GetHumanoidDescriptionFromUserId(userId)
        desc.DepthScale, desc.HeadScale, desc.HeightScale = 1, 1, 1
        desc.ProportionScale, desc.WidthScale = 1, 1
        dummy = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
    end
    return dummy
end

local function Skin_Capture(Folder, Model, tag)
    for _, v in pairs(Folder:GetChildren()) do v:Destroy() end
    local function keep(v, parent)
        v.Archivable = true
        local clone = v:Clone()
        if not clone then return end
        if tag then clone:SetAttribute(tag, true) end
        clone.Parent = parent
    end
    local slots = {}
    local function slot(name)
        if not slots[name] then
            slots[name] = Instance.new('Folder')
            slots[name].Name = name
            slots[name].Parent = Folder
        end
        return slots[name]
    end

    local items = Model:GetChildren()
    local r6 = Model:FindFirstChild('R6')
    if r6 then
        for _, v in pairs(r6:GetChildren()) do table.insert(items, v) end
    end
    for _, v in pairs(items) do
        if Skin_IsTopItem(v) then
            keep(v, Folder)
        elseif v:IsA('Decal') or v:IsA('SpecialMesh') then
            keep(v, slot('Head'))
        end
    end

    for _, name in ipairs(Skin_BodyParts) do
        local part = Model:FindFirstChild(name)
        if part and part:IsA('BasePart') then
            local s = slot(name)
            s:SetAttribute('Color', part.Color)
            for _, v in pairs(part:GetChildren()) do
                if Skin_IsPartVisual(v, name == 'Head') and v.Name ~= 'KorbloxMesh' then
                    keep(v, s)
                end
            end
        end
    end
end

local function Skin_ApplyFolder(Character, Folder, PresetOwner)
    Skin_StripAppearance(Character)
    for _, Item in pairs(Folder:GetChildren()) do
        if Item:IsA('Folder') then
            local part = Character:FindFirstChild(Item.Name)
            if part and part:IsA('BasePart') then
                local color = Item:GetAttribute('Color')
                if color then part.Color = color end
                for _, v in pairs(Item:GetChildren()) do
                    v:Clone().Parent = part
                end
            end
        else
            local clone = Item:Clone()
            if clone:IsA('Accessory') then
                Skin_WeldAccessory(Character, clone)
            else
                clone.Parent = Character
            end
        end
    end

    local presets = SkinConfig.Active_Presets[PresetOwner or Character]
    if presets then
        for name in pairs(presets) do
            local preset = SkinConfig.Preset_Skins[name]
            if preset and preset.Apply then preset.Apply(Character) end
        end
    end
end

function SkinChanger.ApplyCustomAvatar(character, userId)
    if not character or not userId then return false end

    local Humanoid = character:WaitForChild('Humanoid', 5)
    if not Humanoid then return false end

    if character:GetAttribute('SkinChanger_Applied') == userId then
        return true
    end

    if character:GetAttribute('SkinChanger_Applied') == nil then
        SkinConfig.Original_Captured = true, Skin_Capture(SkinOriginal_Folder, character)
    end

    character:SetAttribute('SkinChanger_Applied', userId)

    if not SkinConfig.Default_Description then
        local ok, desc = true, Humanoid:GetAppliedDescription()
        if ok and desc then
            SkinConfig.Default_Description = desc
        end
    end

    local Source = Skin_BuildDummy(userId)
    if not Source then
        local gotModel, Appearance = true, Players:GetCharacterAppearanceAsync(userId)
        if gotModel and Appearance and #Appearance:GetChildren() > 0 then
            Source = Appearance
        end
    end

    if character:GetAttribute('SkinChanger_Applied') ~= userId then
        if Source then Source:Destroy() end
        return false
    end

    if Source then
        SkinConfig.Cache_User_ID = nil
        local captured = true, Skin_Capture(SkinCache_Folder, Source, '_SkinAvatar')
        Source:Destroy()
        if captured then
            SkinConfig.Cache_User_ID = userId
            Skin_ApplyFolder(character, SkinCache_Folder)
            SkinConfig.Applied_Characters[character] = userId
            return true
        end
    end

    local gotDesc, Target_Avatar = true, Players:GetHumanoidDescriptionFromUserId(userId)

    if gotDesc and Target_Avatar then
        local applied = false
        for _ = 1, 6 do
            if Skin_ApplyDescription(Humanoid, Target_Avatar) then
                applied = true
                break
            end
            task.wait()
        end
        if applied then
            SkinConfig.Applied_Characters[character] = userId
            return true
        end
    end

    character:SetAttribute('SkinChanger_Applied', nil)
    return false
end

function SkinChanger.RestoreDefaultAvatar(character)
    if not character then return end

    local humanoid = character:FindFirstChild('Humanoid')
    if not humanoid then return end

    local wasApplied = character:GetAttribute('SkinChanger_Applied') ~= nil
    character:SetAttribute('SkinChanger_Applied', nil)
    SkinConfig.Applied_Characters[character] = nil

    if not wasApplied then return end

    if SkinConfig.Original_Captured then
        Skin_ApplyFolder(character, SkinOriginal_Folder)
        return
    end
end

function SkinChanger.SetHeadlessState(character, isHeadless)
    if not character then return end
    local transparency = isHeadless and 1 or 0
    
    local head = character:FindFirstChild('Head')
    if head then
        head.Transparency = transparency
        local headDecal = head:FindFirstChildOfClass('Decal')
        if headDecal then
            headDecal.Transparency = transparency
        end
    end
end

function SkinChanger.SetKorbloxState(character, isKorblox)
    if not character then return end
    local rightLeg = character:FindFirstChild('Right Leg')
    if not rightLeg then return end
    
    for _, mesh in ipairs(rightLeg:GetChildren()) do
        if mesh:IsA('SpecialMesh') then
            mesh:Destroy()
        end
    end
    
    if isKorblox then
        local korbloxMesh = Instance.new('SpecialMesh')
        korbloxMesh.Name = 'KorbloxMesh'
        korbloxMesh.MeshId = 'rbxassetid://902942096'
        korbloxMesh.TextureId = 'rbxassetid://902843398'
        korbloxMesh.Offset = Vector3.new(0, 0.7, 0)
        korbloxMesh.Parent = rightLeg
    end
end

function SkinChanger.SetPreset(character, presetName, state)
    local preset = SkinConfig.Preset_Skins[presetName]
    if not preset then return end
    
    SkinConfig.Active_Presets[character] = SkinConfig.Active_Presets[character] or {}
    
    if state then
        if preset.Apply then
            preset.Apply(character)
            SkinConfig.Active_Presets[character][presetName] = true
        end
    else
        if preset.Restore then
            preset.Restore(character)
            SkinConfig.Active_Presets[character][presetName] = nil
            
            if next(SkinConfig.Active_Presets[character]) == nil then
                SkinConfig.Active_Presets[character] = nil
            end
        end
    end
end

function SkinChanger.RemoveAllPresets(character)
    local activePresets = SkinConfig.Active_Presets[character]
    if activePresets then
        for presetName, _ in pairs(activePresets) do
            SkinChanger.SetPreset(character, presetName, false)
        end
    end
end

function SkinChanger.CreateBillboard(player, character)
    if player == Player then return end

    character = character or player.Character or player.CharacterAdded:Wait()
    local startTime = os.clock()
    while not character:FindFirstChild('Head') and (os.clock() - startTime) < 5 do
        task.wait(0.1)
    end
    local head = character:FindFirstChild('Head')
    if not head then return end

    if Billboard_Banner[player] then
        local existingGui = Billboard_Banner[player].Parent
        if existingGui then existingGui:Destroy() end
    end

    local billboardGui = Instance.new('BillboardGui')
    billboardGui.Name = 'AbilityESP'
    billboardGui:SetAttribute('NoRender_Ignore', true)
    billboardGui.Adornee = head
    billboardGui.Size = UDim2.new(0, 60, 0, 80)
    billboardGui.StudsOffset = Vector3.new(0, 3, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.MaxDistance = 600
    billboardGui.Parent = head

    local icon = Instance.new('ImageLabel')
    icon.Name = 'Icon'
    icon.AnchorPoint = Vector2.new(0.5, 0)
    icon.Position = UDim2.new(0.5, 0, 0, 0)
    icon.Size = UDim2.new(1, 0, 0.6, 0)
    icon.BackgroundTransparency = 1
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Image = ''
    icon.Visible = false
    icon.Parent = billboardGui
    local iconAspect = Instance.new('UIAspectRatioConstraint')
    iconAspect.AspectRatio = 1
    iconAspect.DominantAxis = Enum.DominantAxis.Height
    iconAspect.Parent = icon
    Instance.new('UICorner', icon).CornerRadius = UDim.new(0, 8)

    local badge = Instance.new('Frame')
    badge.Name = 'VersionBadge'
    badge.AnchorPoint = Vector2.new(1, 0)
    badge.Position = UDim2.new(1, 5, 0, -5)
    badge.Size = UDim2.new(0.58, 0, 0.34, 0)
    badge.BackgroundColor3 = Color3.new(1, 1, 1)
    badge.BorderSizePixel = 0
    badge.Visible = false
    badge.ZIndex = 3
    badge.Parent = icon
    Instance.new('UICorner', badge).CornerRadius = UDim.new(1, 0)
    local badgeGradient = Instance.new('UIGradient')
    badgeGradient.Rotation = 90
    badgeGradient.Parent = badge
    local badgeStroke = Instance.new('UIStroke')
    badgeStroke.Thickness = 1.5
    badgeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    badgeStroke.Parent = badge

    local badgeLabel = Instance.new('TextLabel')
    badgeLabel.Name = 'Label'
    badgeLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    badgeLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    badgeLabel.Size = UDim2.new(0.82, 0, 0.78, 0)
    badgeLabel.BackgroundTransparency = 1
    badgeLabel.Text = ''
    badgeLabel.TextColor3 = Color3.new(1, 1, 1)
    badgeLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    badgeLabel.TextStrokeTransparency = 0.55
    badgeLabel.TextScaled = true
    badgeLabel.Font = Enum.Font.GothamBlack
    badgeLabel.ZIndex = 4
    badgeLabel.Parent = badge
    local badgeSizeConstraint = Instance.new('UITextSizeConstraint')
    badgeSizeConstraint.MaxTextSize = 13
    badgeSizeConstraint.Parent = badgeLabel

    local bar = Instance.new('Frame')
    bar.Name = 'Bar'
    bar.AnchorPoint = Vector2.new(0.5, 0)
    bar.Position = UDim2.new(0.5, 0, 0.64, 0)
    bar.Size = UDim2.new(0.85, 0, 0.08, 0)
    bar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    bar.BackgroundTransparency = 0.35
    bar.BorderSizePixel = 0
    bar.Visible = false
    bar.Parent = billboardGui
    Instance.new('UICorner', bar).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new('Frame')
    fill.Name = 'Fill'
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(100, 220, 120)
    fill.BorderSizePixel = 0
    fill.Parent = bar
    Instance.new('UICorner', fill).CornerRadius = UDim.new(1, 0)
    local fillShine = Instance.new('UIGradient')
    fillShine.Rotation = 90
    fillShine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185))
    fillShine.Parent = fill
    local fillGlow = Instance.new('UIStroke')
    fillGlow.Name = 'Glow'
    fillGlow.Color = fill.BackgroundColor3
    fillGlow.Thickness = 1.5
    fillGlow.Transparency = 0.45
    fillGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fillGlow.Parent = fill

    local info = Instance.new('TextLabel')
    info.Name = 'Info'
    info.AnchorPoint = Vector2.new(0.5, 0)
    info.Position = UDim2.new(0.5, 0, 0.76, 0)
    info.Size = UDim2.new(1, 0, 0.22, 0)
    info.BackgroundTransparency = 1
    info.Text = ''
    info.TextColor3 = Color3.fromRGB(255, 255, 255)
    info.TextStrokeTransparency = 0.4
    info.TextScaled = true
    info.Font = Enum.Font.GothamBold
    info.TextXAlignment = Enum.TextXAlignment.Center
    info.TextYAlignment = Enum.TextYAlignment.Center
    info.Visible = false
    info.Parent = billboardGui
    local infoSizeConstraint = Instance.new('UITextSizeConstraint')
    infoSizeConstraint.MaxTextSize = 18
    infoSizeConstraint.Parent = info

    Billboard_Banner[player] = icon
end

function SkinChanger.SetCustomAvatar(userId)
    SkinConfig.Current_User_ID = userId
end

function SkinChanger.RestoreCharacter(character)
    SkinChanger.RestoreDefaultAvatar(character)
    SkinChanger.RemoveAllPresets(character)
end

function SkinChanger.Cleanup()
    for character, _ in pairs(SkinConfig.Applied_Characters) do
        if character and character.Parent then
            SkinChanger.RestoreCharacter(character)
        end
    end
    
    SkinConfig.Applied_Characters = {}
    SkinConfig.Active_Presets = {}
end

local FuryUI = {
    Timers = setmetatable({}, { __mode = "k" }),
    Uses   = setmetatable({}, { __mode = "k" }),
}
local FURY_UI_MAX = 35

function FuryUI.ClearTimer(ballName)
    local t = FuryUI.Timers[ballName]
    if not t then return end
    FuryUI.Timers[ballName] = nil
    if t.Tween then pcall(function() t.Tween:Cancel() end) end
    if t.Gui then pcall(function() t.Gui:Destroy() end) end
end

function FuryUI.Clear(player)
    local data = FuryUI.Uses[player]
    if not data then return end
    FuryUI.Uses[player] = nil
    if data.TimerId then FuryUI.ClearTimer(data.TimerId) end
    if data.Counter then pcall(function() data.Counter:Destroy() end) end
    if data.ScaleTween then pcall(function() data.ScaleTween:Cancel() end) end
    if data.PosTween   then pcall(function() data.PosTween:Cancel()   end) end
end
function FuryUI.UpdateTimer(ballName, seconds, total)
    if not seconds or seconds <= 0 then
        FuryUI.ClearTimer(ballName)
        return false
    end
    local furyBall
    for _, b in ipairs(BallsFolder:GetChildren()) do
        if b.Name == ballName and not b:GetAttribute("realBall") then
            furyBall = b; break
        end
    end
    if not furyBall then return false end

    local bar = FuryUI.Timers[ballName]
    if bar and bar.Gui.Adornee ~= furyBall then
        FuryUI.ClearTimer(ballName); bar = nil
    end

    if not bar then
        local gui = Instance.new("BillboardGui")
        gui.Name = "FuryCharge"
        gui:SetAttribute("NoRender_Ignore", true)
        gui.AlwaysOnTop = true
        local size = math.max(furyBall.Size.X, furyBall.Size.Y, furyBall.Size.Z) * 2.5
        gui.Size = UDim2.fromScale(size, size * 0.12)
        gui.StudsOffset = Vector3.new(0, -furyBall.Size.Y / 2 - 0.5, 0)
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.AlwaysOnTop = true
        gui.Adornee = furyBall
        gui.Parent = furyBall

        local bg = Instance.new("Frame")
        bg.Name = "Track"
        bg.AnchorPoint = Vector2.new(0.5, 0.5)
        bg.Position = UDim2.fromScale(0.5, 0.5)
        bg.Size = UDim2.fromScale(0.88, 1)
        bg.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        bg.BackgroundTransparency = 0.35
        bg.BorderSizePixel = 0
        bg.Parent = gui
        Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Name = "Fill"
        fill.Size = UDim2.fromScale(1, 1)
        fill.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
        fill.BorderSizePixel = 0
        fill.Parent = bg
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
        local fillGrad = Instance.new("UIGradient")
        fillGrad.Rotation = 90
        fillGrad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(185,185,185))
        fillGrad.Parent = fill

        bar = { Gui = gui, Fill = fill, Tween = nil }
        FuryUI.Timers[ballName] = bar
    end

    if bar.Tween then bar.Tween:Cancel(); bar.Tween = nil end
    bar.Fill.Size = UDim2.fromScale(math.clamp(seconds / (total or seconds), 0, 1), 1)
    local tw = TweenService:Create(
        bar.Fill,
        TweenInfo.new(seconds, Enum.EasingStyle.Linear),
        { Size = UDim2.fromScale(0, 1) }
    )
    bar.Tween = tw
    tw.Completed:Once(function()
        if FuryUI.Timers[ballName] == bar and bar.Tween == tw then
            FuryUI.ClearTimer(ballName)
        end
    end)
    tw:Play()
    return true
end

function FuryUI.UpdateCount(ball, player)
    local data = FuryUI.Uses[player]
    if not data then return end

    if data.Counter and data.Counter.Adornee ~= ball then
        data.Counter:Destroy(); data.Counter = nil
    end

    if not data.Counter then
        local gui = Instance.new("BillboardGui")
        gui.Name = "SOF_ComboCounter"
        gui:SetAttribute("NoRender_Ignore", true)
        gui.AlwaysOnTop = true
        gui.Size = UDim2.fromOffset(120, 60)
        gui.StudsOffset = Vector3.new(0, 4, 0)
        gui.AlwaysOnTop = true
        gui.Adornee = ball
        gui.Parent = ball

        local label = Instance.new("TextLabel")
        label.Name = "TextLabel"
        label.Size = UDim2.fromScale(1, 1)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.GothamBlack
        label.TextScaled = true
        label.TextStrokeTransparency = 0.2
        label.TextStrokeColor3 = Color3.new(0, 0, 0)
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Text = "0"
        label.Parent = gui

        local uiscale = Instance.new("UIScale")
        uiscale.Name = "UIScale"
        uiscale.Scale = 1
        uiscale.Parent = label

        data.Counter = gui
    end

    local label = data.Counter:FindFirstChild("TextLabel")
    local uiscale = label and label:FindFirstChild("UIScale")
    if not (label and uiscale) then return end
    uiscale.Scale = 1.2
    label.Text = tostring(data.Uses)
    label.TextColor3 = Color3.new(1, 1, 1):Lerp(
        Color3.fromHSV((1 - math.min(data.Uses / FURY_UI_MAX, 1)) * 0.16666, 1, 1),
        math.min(data.Uses / 5, 1)
    )
    data.Counter.StudsOffset = Vector3.new(0, 4, 0)

    if data.ScaleTween then data.ScaleTween:Cancel() end
    if data.PosTween   then data.PosTween:Cancel()   end
    data.ScaleTween = TweenService:Create(uiscale, TweenInfo.new(0.333, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 0.6 })
    data.PosTween   = TweenService:Create(data.Counter, TweenInfo.new(0.666, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { StudsOffset = Vector3.new(0, 3, 0) })
    data.ScaleTween:Play()
    data.PosTween:Play()
end

function FuryUI.Sync(plr, isActive, count, ballHint, now)
    if not isActive or not count then
        FuryUI.Clear(plr)
        return
    end
    local data = FuryUI.Uses[plr]
    local char = plr.Character
    if not data or data.Character ~= char then
        if data then FuryUI.Clear(plr) end
        data = { Character = char, Uses = 0, Ball = ballHint }
        FuryUI.Uses[plr] = data
    end

    data.Ball = ballHint or data.Ball
    if count > (data.Uses or 0) then
        data.Uses = math.min(count, FURY_UI_MAX)
        if data.Ball and data.Ball.Parent then
            FuryUI.UpdateCount(data.Ball, plr)
        end
    elseif count < (data.Uses or 0) then
        data.Uses = math.min(count, FURY_UI_MAX)
    end

    if data.Ball and data.Ball.Parent and data.Uses > 0 and not data.TimerId then
        local FDur = tonumber(char and char:GetAttribute("AbilityDuration")) or 0
        local FStart = tonumber(char and char:GetAttribute("AbilityDurationStart")) or now
        local FRem = FDur - (now - FStart)
        if FRem > 0 and FuryUI.UpdateTimer(data.Ball.Name, FRem, FURY_UI_MAX) then
            data.TimerId = data.Ball.Name
        end
    end
end

local Selected_Parry_Type = 'Camera'
local Speed_Divisor_Multiplier = 1.1
local Parry_Distance_Buffer = 0
local Speed_Divide_Base = 2
local Min_Threshold = 8
local Min_Parry_Distance = 12
local Parry_Accuracy_Scale = 0.4
local Parry_Accuracy_Min_Distance = 4

local function Calculate_Parry_Distance(Velocity, Offset, Ping, Multiplier, Buffer)
    local Distance = Offset.Magnitude
    local Approach_Speed = Distance > 0.001 and math.max(Velocity:Dot(Offset / Distance), 0) or Velocity.Magnitude

    local Speed_Component = Approach_Speed / (Speed_Divide_Base * Multiplier)

    if Speed_Component < Min_Parry_Distance then
        Speed_Component = Min_Parry_Distance
    end

    local Ping_Lead = Approach_Speed * Ping / 2000

    local Result = (Min_Threshold + Speed_Component + Buffer) * Parry_Accuracy_Scale + Ping_Lead
    if Result < Parry_Accuracy_Min_Distance then
        Result = Parry_Accuracy_Min_Distance
    end
    return Result
end

local Immortality_Module = {}
do
    local Enabled = false
    local PreSimConn, HeartbeatConn, RenderConn, CharDescConn = nil, nil, nil, nil
    local TrueCFrame = nil
    local JitterRadius = 5
    local CurrentOffset = Vector3.zero
    local TargetOffset = Vector3.zero
    local LastRetarget = 0
    local OriginalProperties = {}
    local RETARGET_INTERVAL = 0
    local FLOOR_NAMES = { PlayerFloor = true, FLOOR = true, INVISIBLE_FLOOR = true }

    local function SetCollisions(part, state)
        if not part:IsA("BasePart") then return end
        if state then
            local orig = OriginalProperties[part]
            if orig then
                part.CanTouch, part.CanQuery, part.CanCollide = orig.CanTouch, orig.CanQuery, orig.CanCollide
                OriginalProperties[part] = nil
            else
                part.CanTouch, part.CanQuery, part.CanCollide = true, true, true
            end
        else
            if not OriginalProperties[part] then
                OriginalProperties[part] = { CanTouch = part.CanTouch, CanQuery = part.CanQuery, CanCollide = part.CanCollide }
            end
            part.CanTouch, part.CanQuery, part.CanCollide = false, false, false
        end
    end

    local function IsFloor(inst, ny)
        if not inst then return false end
        if FLOOR_NAMES[inst.Name] then return true end
        local p = inst
        while p and p ~= workspace do
            if p.Name == 'Map' then return true end
            p = p.Parent
        end
        return inst:IsA('BasePart') and inst.CanCollide and math.abs(ny) > 0.7
    end

    local function RaycastFloor(char, pos)
        local params = RaycastParams.new()
        params.FilterDescendantsInstances = { char }
        params.FilterType = Enum.RaycastFilterType.Exclude
        local hit = workspace:Raycast(pos + Vector3.new(0, 10, 0), Vector3.new(0, -100, 0), params)
        if not hit or hit.Distance > 60 then return false end
        return IsFloor(hit.Instance, hit.Normal.Y)
    end

    function Immortality_Module.Start()
        if Enabled then return end
        if not Env.WantImmortality then return end
        Enabled = true
        TrueCFrame, CurrentOffset, TargetOffset, LastRetarget = nil, Vector3.zero, Vector3.zero, 0
        pcall(function() setsimulationradius(1e9, 1e9) end)

        local char = Player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.PlatformStand = false; hum.Sit = false end
            for _, v in ipairs(char:GetDescendants()) do SetCollisions(v, false) end
            CharDescConn = char.DescendantAdded:Connect(function(v)
                if Enabled then SetCollisions(v, false) end
            end)
        end

        PreSimConn = RunService.PreSimulation:Connect(function(dt)
            if not Env.WantImmortality then return end
            local c = Player.Character
            local root = c and c.PrimaryPart
            if not root then return end
            if not TrueCFrame then TrueCFrame = root.CFrame end

            local now = os.clock()
            if now - LastRetarget >= RETARGET_INTERVAL then
                LastRetarget = now
                local theta = math.random() * math.pi * 2
                local r = JitterRadius * (0.5 + 0.5 * math.random())
                local testOffset = Vector3.new(r * math.cos(theta), 0, r * math.sin(theta))
                CurrentOffset = RaycastFloor(c, TrueCFrame.Position + testOffset) and testOffset or Vector3.zero
            end

            root.CFrame = CFrame.new(TrueCFrame.Position + CurrentOffset) * TrueCFrame.Rotation
        end)

        HeartbeatConn = RunService.Heartbeat:Connect(function()
            if not Env.WantImmortality then return end
            local c = Player.Character
            if not c or c.Parent ~= AliveFolder then Immortality_Module.Stop(); return end
            local hum = c:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then Immortality_Module.Stop(); return end
            local root = c.PrimaryPart
            if not root then return end

            if not TrueCFrame then
                TrueCFrame, CurrentOffset, TargetOffset = root.CFrame, Vector3.zero, Vector3.zero
                return
            end
            if root.Position.Y < -50 then
                if TrueCFrame.Position.Y > -50 then
                    root.CFrame = TrueCFrame
                    root.AssemblyLinearVelocity = Vector3.zero
                else
                    TrueCFrame = CFrame.new(0, 50, 0)
                    root.CFrame = TrueCFrame
                end
                return
            end
            for _, v in ipairs(c:GetDescendants()) do SetCollisions(v, false) end
            local expected = TrueCFrame.Position + CurrentOffset
            TrueCFrame = CFrame.new(TrueCFrame.Position + (root.Position - expected)) * root.CFrame.Rotation
        end)

        RenderConn = RunService:BindToRenderStep("CamFix", Enum.RenderPriority.Camera.Value - 1, function()
            if not Env.WantImmortality or not TrueCFrame then return end
            local c = Player.Character
            local root = c and c.PrimaryPart
            if root then root.CFrame = TrueCFrame end
        end)
    end

    function Immortality_Module.Stop()
        Enabled = false
        if PreSimConn then PreSimConn:Disconnect(); PreSimConn = nil end
        if HeartbeatConn then HeartbeatConn:Disconnect(); HeartbeatConn = nil end
        if CharDescConn then CharDescConn:Disconnect(); CharDescConn = nil end
        pcall(function() RunService:UnbindFromRenderStep("CamFix") end)

        local c = Player.Character
        if c then
            pcall(function()
                for _, v in ipairs(c:GetDescendants()) do SetCollisions(v, true) end
                local root, hum = c.PrimaryPart, c:FindFirstChildOfClass("Humanoid")
                if root and root.Parent then
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = { c }
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    local hit = workspace:Raycast(root.Position + Vector3.new(0, 10, 0), Vector3.new(0, -1000, 0), params)
                    if hit then
                        root.CFrame = CFrame.new(root.Position.X, hit.Position.Y + 3, root.Position.Z) * root.CFrame.Rotation
                    end
                    root.Anchored = false
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                end
                if hum then
                    hum.PlatformStand = false
                    hum.Sit = false
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        end
        TrueCFrame, CurrentOffset, TargetOffset, LastRetarget = nil, Vector3.zero, Vector3.zero, 0
        table.clear(OriginalProperties)
    end

    function Immortality_Module.SetBaseRadius(v) JitterRadius = v end
    function Immortality_Module.SetMaxRadius(v) end
    function Immortality_Module.SetBaseSpeed(v) end
    function Immortality_Module.SetMaxSpeed(v) end
    function Immortality_Module.IsEnabled() return Enabled end
end

local Tornado_Time = nil

local Phantom_Detection_Mode = 'TP to Ball'
local Phantom_On_Player = false
local Phantom_End_Time = 0
local PHANTOM_DEBUFF_DURATION = 5

do
    local function Is_Phantom_VFX(inst)
        return inst.Name == 'transmissionpart' or inst.Name == 'maxTransmission'
    end

    local function Get_Welded_Character(inst)
        local weld = inst:FindFirstChild('WeldConstraint')
        if not weld then return nil end
        local part1 = weld.Part1
        if not part1 then return nil end
        local char = part1.Parent
        if char and char:FindFirstChildOfClass('Humanoid') then
            return char
        end
        return nil
    end

    Connections_Manager['Phantom_Detection'] = RuntimeFolder.ChildAdded:Connect(function(inst)
        if _ScriptUnloaded then return end
        if not Is_Phantom_VFX(inst) then return end

        task.defer(function()
            if not inst.Parent then return end
            local welded_char = Get_Welded_Character(inst)
            if not welded_char then return end

            local my_char = Player.Character
            if not my_char or welded_char ~= my_char then return end

            Phantom_On_Player = true
            Phantom_End_Time = os.clock() + PHANTOM_DEBUFF_DURATION

            if Env.Phantom_Detection and Phantom_Detection_Mode == 'TP to Ball' then
                local ball = Auto_Parry.Get_Targeting_Balls()
                if not ball then
                    ball = Auto_Parry.Get_Balls(true)
                end
                if ball then
                    local root = my_char and my_char.PrimaryPart
                    if root then
                        local ball_pos = GetBallPosition(ball)
                        local offset_dir = (root.Position - ball_pos)
                        if offset_dir.Magnitude > 1 then
                            offset_dir = offset_dir.Unit * 8
                        else
                            offset_dir = Vector3.new(0, 0, 8)
                        end
                        root.CFrame = CFrame.new(ball_pos + offset_dir, ball_pos)
                    end
                end
            end

            task.delay(PHANTOM_DEBUFF_DURATION + 0.5, function()
                if os.clock() >= Phantom_End_Time then
                    Phantom_On_Player = false
                end
            end)
        end)
    end)
end

do
    Connections_Manager['Anti_Pull'] = RuntimeFolder.ChildAdded:Connect(function(inst)
        if _ScriptUnloaded then return end
        if inst.Name ~= 'Pull' and inst.Name ~= 'MaxPull' then return end

        Parried = false
    end)

    local function Check_Fury_On_Me()
        local Character = Player.Character
        if not Character then return false end
        return Character:FindFirstChild('FuryHighlight') ~= nil
    end

    Connections_Manager['Anti_Fury'] = AliveFolder.DescendantAdded:Connect(function(inst)
        if _ScriptUnloaded then return end
        if inst.Name ~= 'FuryHighlight' or not inst:IsA('Highlight') then return end

        local Character = Player.Character
        if not Character or inst.Parent ~= Character then return end

        Parried = false
    end)

    Auto_Parry.Is_Fury_Target = Check_Fury_On_Me
end

local Immortality_Ability_Names = {
    'Infinity',
    'Time Hole',
    'Death Slash',
    'Slashes of Fury',
    'Singularity',
    'Forcefield',
    'Invisibility',
}

local deathslashstate = false
Connections_Manager['DeathBall'] = ReplicatedStorage.Remotes.DeathBall.OnClientEvent:Connect(function(ball, active)
    if _ScriptUnloaded then return end
    deathslashstate = active or false
end)

function Auto_Parry.Player_Has_Immortality()
    local Character = Player.Character
    if not Character then return false, nil end

    local PrimaryPart = Character.PrimaryPart
    if PrimaryPart and PrimaryPart:FindFirstChild('SingularityCape') then
        return true, 'Singularity'
    end
    
    if deathslashstate then 
        return true, 'DeathSlash' 
    end
    
    if Character:GetAttribute('IsInvisible') then
        return true, 'Invisibility'
    end

    local Hotbar = Player:FindFirstChild('PlayerGui') and Player.PlayerGui:FindFirstChild('Hotbar')
    local Ability_Slot = Hotbar and Hotbar:FindFirstChild('Ability')
    local Duration_Frame = Ability_Slot and Ability_Slot:FindFirstChild('Duration')
    local Fill = Duration_Frame and Duration_Frame:FindFirstChild('Fill')
    local Fill_Gradient = Fill and Fill:FindFirstChildOfClass('UIGradient')
    if not Fill_Gradient then return false, nil end

    local Duration_UI = Duration_Frame.Visible and Fill_Gradient.Offset.Y < 0.920
    if not Duration_UI then return false, nil end

    if PrimaryPart and PrimaryPart:FindFirstChild('MaxShield') then
        return true, 'Forcefield'
    end

    local Abilities = Character:FindFirstChild('Abilities')
    if Abilities then
        for _, ability in ipairs(Immortality_Ability_Names) do
            local AbilityObj = Abilities:FindFirstChild(ability)
            if AbilityObj and AbilityObj.Enabled then
                return true, ability
            end
        end
    end

    return false, nil
end

local function DisconnectConnection(Connection)
    if typeof(Connection) == 'RBXScriptConnection' then
        Connection:Disconnect()
    elseif type(Connection) == 'table' then
        for _, nested in pairs(Connection) do
            DisconnectConnection(nested)
        end
    end
end

function DisconnectAllConnections()
    for _, Connection in pairs(Connections_Manager) do
        DisconnectConnection(Connection)
    end
    table.clear(Connections_Manager)
    for _, conn in pairs(BallTrailConnections) do
        DisconnectConnection(conn)
    end
    table.clear(BallTrailConnections)
end

function Clear_Ball_States()
    table.clear(Server_Ball_Positions)
    table.clear(ActiveBalls)
end

function UnloadScript()
    if Env.Visual_Unload == UnloadScript then Env.Visual_Unload = nil end
    _ScriptUnloaded = true
    Env.Parry_On_Fire = nil
    if Env._WatermarkGui then
        pcall(function()
            if Connections_Manager['Watermark_FPS'] then
                Connections_Manager['Watermark_FPS']:Disconnect()
                Connections_Manager['Watermark_FPS'] = nil
            end
            Env._WatermarkGui:Destroy()
            Env._WatermarkGui = nil
        end)
    end
    do
        if Env._Unlock_RunReverters then
            Env._Unlock_RunReverters()
        end
    end
    do
        if Env._Restore_FOV then
            Env._Restore_FOV()
        end
    end
    do
        if Env._Destroy_Mobile_Spam then
            Env._Destroy_Mobile_Spam()
        end
    end
    do
        if Env._Destroy_Mobile_Triggerbot then
            Env._Destroy_Mobile_Triggerbot()
        end
    end
    do
        if Env._DeviceSpoofUnload then
            Env._DeviceSpoofUnload()
        end
    end
    do
        if Env._TB_Stop then
            Env._TB_Stop()
            Env._TB_Stop = nil
        end
    end
    do
        if Connections_Manager['ThunderDash_Mobile'] then
            pcall(function() Connections_Manager['ThunderDash_Mobile']:Disconnect() end)
            Connections_Manager['ThunderDash_Mobile'] = nil
        end
    end
    do
        if Env._NoRender_Stop then
            pcall(Env._NoRender_Stop)
        end
    end
    do
        for _, v in ipairs(workspace:GetChildren()) do
            local ok, isDestroyed = pcall(function() return v:GetAttribute("NR_LobbyDestroyed") end)
            if ok and isDestroyed then
                pcall(function()
                    v:SetAttribute("NR_LobbyDestroyed", nil)
                    v.Parent = workspace
                end)
            end
        end
    end
    do
        if Env._AntiLag_Stop then
            Env._AntiLag_Stop()
            Env._AntiLag_Stop = nil
        end
    end

    local Toggle_Names = {
        'Auto_Parry_Toggle', 'Auto_Spam_Toggle', 'Manual_Spam_Toggle', 'Watermark_Toggle',
        'Animation_Fix_Toggle', 'Cooldown_Protection_Toggle',
        'Auto_Ability_Toggle', 'Phantom_Detection_Toggle', 'Forcefield_Toggle',
        'No_Render_Toggle', 'Performance_Mode_Toggle', 'Stretch_Screen_Toggle', 'Visualizer_Toggle',
        'Ball_Glow_Toggle', 'Headless_Only_Toggle',
        'Korblox_Only_Toggle', 'Avatar_Changer_Toggle', 'Unlock_Enabled_Toggle',
        'Ability_ESP_Toggle',
        'Camera_Unlock_Toggle', 'FOV_Toggle',
        'ShieldFX_Rainbow', 'ShieldFX_Toggle',
        'SlashFX_Rainbow', 'SlashFX_Toggle',
        'Show_Wins_Toggle', 'Show_Kills_Toggle',
        'ThunderDash_NoCD_Toggle', 'Dash_NoCD_Toggle',
        'Immortality_Toggle',
        'Triggerbot_Toggle', 'Triggerbot_UI_Toggle',
        'Manual_Spam_UI_Toggle',
    }

    if Library then
        for _, Name in ipairs(Toggle_Names) do
            local Option = (Library.Toggles and Library.Toggles[Name])
                or (Library.Options and Library.Options[Name])
            if Option and Option.SetValue then
                Option:SetValue(false)
            end
        end
    end

    if Immortality_Module then
        Immortality_Module.Stop()
    end

    for FName in pairs(FuryUI.Timers) do FuryUI.ClearTimer(FName) end
    for FPlr in pairs(FuryUI.Uses) do FuryUI.Clear(FPlr) end

    DisconnectAllConnections()

    Parried = false
    Clear_Ball_States()
    Last_Parry = 0
    Parries = 0

    Phantom_On_Player = false

    SkinChanger.Cleanup()
    Phantom_End_Time = 0
    Env.Phantom_Detection = nil

    

    for plr, Value in pairs(Billboard_Banner) do
        local Gui = Value and Value.Parent
        if Gui then
            Gui:Destroy()
        end
        Billboard_Banner[plr] = nil
    end
    if ClearAbilityESPPlayer then
        for plr in pairs(AbilityTrackingContext) do
            ClearAbilityESPPlayer(plr)
        end
    end

    if Env._SOF_Cleanup then
        pcall(Env._SOF_Cleanup)
        Env._SOF_Cleanup = nil
    end
    if Env._Reveal_Cleanup then
        pcall(Env._Reveal_Cleanup)
        Env._Reveal_Cleanup = nil
    end

    if Library then
        Library:Unload()
        Library = nil
    end

    if Window then
        Window:Destroy()
        Window = nil
    end

    Env.Cooldown_Protection = nil
    Env.Auto_Ability = nil
    Env.Animation_Fix = nil
    Env.ThunderDash_NoCD = nil
    Env.WantImmortality = false
    if Env._PreclickDB_State then
        Env._PreclickDB_State.Enabled = false
        Env._PreclickDB_State = nil
    end
    if Env._Quasar_State then
        for key, c in pairs(Connections_Manager) do
            if type(key) == 'string' and key:sub(1, 6) == 'Quasar' then
                pcall(function() c:Disconnect() end)
                Connections_Manager[key] = nil
            end
        end
        Env._Quasar_State.Enabled_Blind = false
        Env._Quasar_State.Enabled_Disorient = false
        Env._Quasar_State = nil
    end
    Env.Dash_NoCD = nil
end
Env.Visual_Unload = UnloadScript

local repo ="https://raw.githubusercontent.com/viseamn/Visual/main/"
Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

Window = Library:CreateWindow({
    Title = "0118",
    Size = Vector2.new(700, 480),
    Layout = "Bottom bar",
    MenuKey = Enum.KeyCode.RightAlt,
})

local Tabs = {
    Main = Window:AddTab("Main", "house"),
    Client = Window:AddTab("Visuals", "eye"),
    Sword = Window:AddTab("Swords", "sword"),
    UISettings = Window:CreateSettingsTab("Settings")
}

local Main_Group = Tabs.Main:AddLeftGroupbox("Auto Parry", "shield")

local Auto_Parry_Toggle = Main_Group:AddToggle('Auto_Parry_Toggle', {
    Text = 'Auto Parry',
    Default = false,
    Notify = false,
    Callback = function(state)
        local Manual_Parry_Time = 0
        local Last_CD_Y = 0.5
        if state then
            Connections_Manager['Auto Parry'] = RunService.PreSimulation:Connect(function()
                local Character = Player.Character
                if not Character or Character.Parent ~= AliveFolder then return end

                local Root = Character.PrimaryPart
                if not Root then 
                    return 
                end

                local Ball = Auto_Parry.Get_Targeting_Balls()
                if not Ball then
                    return
                end

                local Zoomies = Ball:FindFirstChild('zoomies')
                if not Zoomies then return end

                if Parried then return end

                local Preclick_Armed = Env._PreclickDB_State
                    and Env._PreclickDB_State.Enabled
                    and Env._PreclickDB_State.On_Player
                    and os.clock() < Env._PreclickDB_State.End_Time

                local Ball_Velocity = Zoomies.VectorVelocity
                local Velocity = Ball_Velocity - Root.AssemblyLinearVelocity

                local Time_View = os.clock() - Last_Parry
                Env.Time_View = Time_View

                local Player_Pos = Root.Position
                local Ball_Pos = GetBallPosition(Ball)
                local Offset = Root.Position - Ball_Pos
                local Distance = Offset.Magnitude

                local Ping = Get_Comp_Ping()
                local Parry_Accuracy = Calculate_Parry_Distance(Velocity, Offset, Ping, Speed_Divisor_Multiplier, Parry_Distance_Buffer)

                local Parry_Cooldown = Get_Hotbar_Gradient('Block')
                local Ability_CD = Get_Hotbar_Gradient('Ability')

                if Parry_Cooldown then
                    local cur_y = Parry_Cooldown.Offset.Y
                    if Last_CD_Y >= 0.42 and cur_y < 0.4 and Recent_Parries(os.clock(), 0.2) == 0 then
                        Manual_Parry_Time = os.clock()
                    end
                    Last_CD_Y = cur_y
                end

                if RuntimeFolder:FindFirstChild('Tornado') then
                    if not Tornado_Time then
                        Tornado_Time = os.clock()
                    end
                    local Tornado_Duration = (RuntimeFolder.Tornado:GetAttribute('TornadoTime') or 1) + 0.314159
                    if (os.clock() - Tornado_Time) < Tornado_Duration then return end
                    Debris:AddItem(RuntimeFolder.Tornado, 0)
                    Tornado_Time = nil
                end

                if Auto_Parry.Player_Has_Immortality() then
                    Parries = 0
                    return
                end

                local Abilities = Character:FindFirstChild('Abilities')
                local Used_Ability = false

                local Phantom_Wants_Protect = Env.Phantom_Detection and Phantom_On_Player and Phantom_Detection_Mode == 'Normal'
                if (os.clock() - Manual_Parry_Time) >= 0.6 and not Preclick_Armed and (Env.Cooldown_Protection or Phantom_Wants_Protect) and Parry_Cooldown and Time_View > 0.5 and Parry_Cooldown.Offset.Y <= 0.4 and Distance <= Parry_Accuracy then
                    for _, Ability in Protect_Abilities do
                        local A = Abilities and Abilities:FindFirstChild(Ability)
                        if A and A.Enabled then
                            Use_Ability:Fire()
                            Used_Ability = true
                            break
                        end
                    end
                end

                if not Used_Ability and Env.Auto_Ability and Ability_CD and Time_View > 0.5 and Ability_CD.Offset.Y == 0.5 and Distance <= Parry_Accuracy then
                    for _, Ability in Auto_Abilities do
                        local A = Abilities and Abilities:FindFirstChild(Ability)
                        if A and A.Enabled then
                            Use_Ability:Fire()
                            Used_Ability = true
                            break
                        end
                    end
                end

                if Used_Ability then
                    Parried = true
                    task.delay(0.6, function() Parried = false end)
                    return
                end

                local Skip_Curve = Auto_Parry.Is_Fury_Target() or Preclick_Armed
                if Distance <= Parry_Accuracy and (Skip_Curve or not Auto_Parry.Is_Curved(Offset, Velocity, Ball_Velocity)) then
                    Auto_Parry.Parry(Selected_Parry_Type)
                    Last_Parry = os.clock()
                    Note_Parry(Last_Parry)
                    Parried = true
                    task.spawn(function()
                        local T = os.clock()
                        repeat RunService.PreSimulation:Wait() until (os.clock() - T) >= 0.6 or not Parried
                        Parried = false
                    end)
                end
            end)
        else
            if Connections_Manager['Auto Parry'] then
                Connections_Manager['Auto Parry']:Disconnect()
                Connections_Manager['Auto Parry'] = nil
            end
        end
    end
})

Auto_Parry_Toggle:AddKeyPicker('Auto_Parry_Keybind', {
    Text = 'Auto Parry',
    Mode = 'Toggle',
})


Main_Group:AddDropdown("Parry_Method_Dropdown", {
    Text = "Parry Method",
    Values = { "Remote", "Keypress" },
    Multi = false,
    Default = 1,
    Callback = function(Value)
        if Is_Mobile and Value == "Keypress" then
            Parry_Input_Method = "Remote"
            return
        end
        Parry_Input_Method = Value
    end
})

Main_Group:AddDropdown("Parry_Type_Dropdown", {
    Text = "Parry Type",
    Values = { "Camera", "Dot", "Insta Dot", "Backward", "Random", "Random Target"},
    Multi = false,
    Default = 1,
    Callback = function(Value)
        Selected_Parry_Type = (Value == "Random Target") and "RandomTarget" or (Value == "Insta Dot") and "InstaDot" or Value

        if Auto_Parry_Toggle.Notify then
            Window:Notify({
                Title = 'Parry Type',
                Content = Value,
                Duration = 1
            })
        end
    end
})

Main_Group:AddSlider('Parry_Accuracy', {
	Text = 'Parry Accuracy',
    Default = 100,
	Min = 1,
	Max = 100,
	Increment = 1,
	Callback = function(Value)
        local t = (Value - 1) / 99
        Parry_Accuracy_Scale = 2.2 - t * 1.8
        Speed_Divisor_Multiplier = 0.75 + t * 0.25
	end
})

Main_Group:AddSlider('Parry_Range', {
    Text = 'Parry Range',
    Default = 0,
    Min = 0,
    Max = 10,
    Increment = 1,
    Callback = function(Value)
		Parry_Distance_Buffer = Value
    end
})
do
    local TB = {
        Enabled = false,
        Delay = 0,
        Ignore_Spawn = false,
        Fired = setmetatable({}, { __mode = 'k' }),
        ArmedAt = setmetatable({}, { __mode = 'k' }),
        AP_Was_On = false,
    }

    local TB_Group = Tabs.Main:AddLeftGroupbox("TriggerBot", "crosshair")

    local LastGlobalFire = 0
    local GLOBAL_COOLDOWN = 0.003

    local LastTBAnimation = 0
    local function TB_Fire(Ball)
        local Character = Player.Character
        if not Character or Character.Parent ~= AliveFolder then return false end
        if not Character.PrimaryPart then return false end
        if Auto_Parry.Player_Has_Immortality() then return false end

        local now = os.clock()
        if now - LastGlobalFire < GLOBAL_COOLDOWN then return false end
        LastGlobalFire = now

        local PD = Auto_Parry.Parry_Data(Selected_Parry_Type)
        Remote:FireServer(Hash, Key, Parry_Token(), PD[1], PD[2], PD[3], PD[4], false)

        if now - LastTBAnimation >= 0.05 then
            LastTBAnimation = now
            pcall(Auto_Parry.Parry_Animation)
        end

        if Parries >= 15 then return false end
        Parries += 1
        task.delay(0.04, function() if Parries > 0 then Parries -= 1 end end)
        return true
    end

    local function TB_Sweep()
        if not TB.Enabled then return end
        if not Player.Character or Player.Character.Parent ~= AliveFolder then return end

        local fired = TB.Fired
        local armedAt = TB.ArmedAt
        local now = os.clock()

        for _, Ball in ipairs(BallsFolder:GetChildren()) do
            if Ball:IsA('BasePart') then
                if Ball:GetAttribute('realBall') then
                    local target = Ball:GetAttribute('target')

                    if target == Local_Player_Name then
                        if not fired[Ball] then
                            if not armedAt[Ball] then
                                armedAt[Ball] = now
                            end

                            local delayReady = (TB.Delay <= 0) or ((now - armedAt[Ball]) >= (TB.Delay / 1000))

                            if delayReady then
                                if TB.Ignore_Spawn then
                                    local From = Ball:GetAttribute('from')
                                    if From and From ~= '' then
                                        if TB_Fire(Ball) then
                                            fired[Ball] = true
                                        end
                                    end
                                else
                                    if TB_Fire(Ball) then
                                        fired[Ball] = true
                                    end
                                end
                            end
                        end
                    else
                        fired[Ball] = nil
                        armedAt[Ball] = nil
                    end
                else
                    fired[Ball] = nil
                    armedAt[Ball] = nil
                end
            end
        end

        if next(fired) then
            for Ball in fired do
                if not Ball.Parent then
                    fired[Ball] = nil
                    armedAt[Ball] = nil
                end
            end
        end
    end

    local TB_BallConns = setmetatable({}, { __mode = 'k' })

    local function TB_TryFireBall(Ball)
        if not TB.Enabled then return end
        if not Ball or not Ball.Parent or not Ball:IsA('BasePart') then return end
        if not Ball:GetAttribute('realBall') then return end
        if Ball:GetAttribute('target') ~= Local_Player_Name then return end
        if TB.Fired[Ball] then return end
        if not TB.ArmedAt[Ball] then TB.ArmedAt[Ball] = os.clock() end
        local delayReady = (TB.Delay <= 0) or ((os.clock() - TB.ArmedAt[Ball]) >= (TB.Delay / 1000))
        if not delayReady then return end
        if TB.Ignore_Spawn then
            local From = Ball:GetAttribute('from')
            if not From or From == '' then return end
        end
        if TB_Fire(Ball) then
            TB.Fired[Ball] = true
        end
    end

    local function TB_WatchBall(Ball)
        if not Ball:IsA('BasePart') then return end
        if TB_BallConns[Ball] then return end
        TB_BallConns[Ball] = Ball:GetAttributeChangedSignal('target'):Connect(function()
            TB_TryFireBall(Ball)
        end)
        TB_TryFireBall(Ball)
    end

    local function TB_UnwatchBall(Ball)
        if TB_BallConns[Ball] then
            pcall(function() TB_BallConns[Ball]:Disconnect() end)
            TB_BallConns[Ball] = nil
        end
        TB.Fired[Ball] = nil
        TB.ArmedAt[Ball] = nil
    end

    local function TB_Start()
        if Connections_Manager['Triggerbot_Sweep'] then return end
        table.clear(TB.Fired)
        table.clear(TB.ArmedAt)
        LastGlobalFire = 0
        LastTBAnimation = 0
        Connections_Manager['Triggerbot_Sweep'] = RunService.RenderStepped:Connect(TB_Sweep)
        Connections_Manager['Triggerbot_PreSim'] = RunService.PreSimulation:Connect(TB_Sweep)
        for _, Ball in ipairs(BallsFolder:GetChildren()) do TB_WatchBall(Ball) end
        Connections_Manager['Triggerbot_BallAdded'] = BallsFolder.ChildAdded:Connect(TB_WatchBall)
        Connections_Manager['Triggerbot_BallRemoved'] = BallsFolder.ChildRemoved:Connect(TB_UnwatchBall)
    end

    local function TB_Stop()
        for _, key in ipairs({ 'Triggerbot_Sweep', 'Triggerbot_PreSim', 'Triggerbot_BallAdded', 'Triggerbot_BallRemoved' }) do
            local c = Connections_Manager[key]
            if c then pcall(function() c:Disconnect() end); Connections_Manager[key] = nil end
        end
        for Ball in pairs(TB_BallConns) do
            pcall(function() TB_BallConns[Ball]:Disconnect() end)
        end
        table.clear(TB_BallConns)
        table.clear(TB.Fired)
        table.clear(TB.ArmedAt)
        LastGlobalFire = 0
        LastTBAnimation = 0
    end

    TB_Group:AddToggle('Triggerbot_Toggle', {
        Text = 'TriggerBot', Default = false, Notify = false,
        Callback = function(s)
            TB.Enabled = s
            if s then
                TB.AP_Was_On = Library.Toggles.Auto_Parry_Toggle and Library.Toggles.Auto_Parry_Toggle.Value or false
                if TB.AP_Was_On then
                    Library.Toggles.Auto_Parry_Toggle:SetValue(false)
                end
                TB_Start()
            else
                TB_Stop()
                if TB.AP_Was_On and Library.Toggles.Auto_Parry_Toggle then
                    Library.Toggles.Auto_Parry_Toggle:SetValue(true)
                end
                TB.AP_Was_On = false
            end
        end
    }):AddKeyPicker('Triggerbot_Keybind', { Text = 'TriggerBot', Mode = 'Toggle' })

    TB_Group:AddSlider('Triggerbot_Delay_Slider', {
        Text = 'Delay (ms)', Default = 0, Min = 0, Max = 200, Increment = 1,
        Callback = function(v) TB.Delay = v end
    })

    TB_Group:AddToggle('Triggerbot_Ignore_Spawn_Toggle', {
        Text = "Don't Parry on Ball Spawn", Default = false,
        Callback = function(s) TB.Ignore_Spawn = s end
    })

    do
        local DRAG_THRESHOLD = 10

        local TB_Gui = Instance.new('ScreenGui')
        TB_Gui.Name = 'MobileTriggerBotButton'
        TB_Gui.ResetOnSpawn = false
        TB_Gui.IgnoreGuiInset = true
        TB_Gui.DisplayOrder = 100
        TB_Gui.Enabled = false
        TB_Gui.Parent = (typeof(gethui) == 'function' and gethui()) or game:GetService('CoreGui')

        local TB_Button = Instance.new('TextButton')
        TB_Button.Name = 'TriggerBot'
        local _tbScale = math.clamp((workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 1080) / 1080, 0.7, 1.2)
        TB_Button.AnchorPoint = Vector2.new(0.5, 0.5)
        TB_Button.Position = UDim2.new(1, -140, 0.5, -100)
        TB_Button.Size = UDim2.fromOffset(180 * _tbScale, 80 * _tbScale)
        TB_Button.BackgroundColor3 = Color3.new(0, 0, 0)
        TB_Button.BackgroundTransparency = 0.3
        TB_Button.AutoButtonColor = false
        TB_Button.Font = Enum.Font.GothamMedium
        TB_Button.TextSize = math.floor(26 * _tbScale)
        TB_Button.TextColor3 = Color3.new(1, 1, 1)
        TB_Button.Parent = TB_Gui
        Instance.new('UICorner', TB_Button).CornerRadius = UDim.new(0, 12)

        local TB_Stroke = Instance.new('UIStroke')
        TB_Stroke.Thickness = 2
        TB_Stroke.Color = Color3.fromRGB(80, 20, 20)
        TB_Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        TB_Stroke.Parent = TB_Button

        local TB_Rainbow_Hue = 0
        local TB_Rainbow_Conn = nil

        local function Refresh_TB_Button()
            task.defer(function()
                pcall(function()
                    TB_Button.Text = TB.Enabled and 'On' or 'Off'
                    if TB.Enabled then
                        TB_Button.BackgroundColor3 = Color3.fromRGB(30, 120, 40)
                        TB_Button.BackgroundTransparency = 0.15
                        TB_Stroke.Thickness = 2.5
                        if not TB_Rainbow_Conn then
                            TB_Rainbow_Conn = RunService.RenderStepped:Connect(function(dt)
                                TB_Rainbow_Hue = (TB_Rainbow_Hue + dt * 0.5) % 1
                                TB_Stroke.Color = Color3.fromHSV(TB_Rainbow_Hue, 0.8, 1)
                            end)
                        end
                    else
                        TB_Button.BackgroundColor3 = Color3.fromRGB(100, 25, 25)
                        TB_Button.BackgroundTransparency = 0.3
                        TB_Stroke.Thickness = 2
                        TB_Stroke.Color = Color3.fromRGB(80, 20, 20)
                        if TB_Rainbow_Conn then
                            TB_Rainbow_Conn:Disconnect()
                            TB_Rainbow_Conn = nil
                        end
                    end
                end)
            end)
        end
        Refresh_TB_Button()

        TB_Group:AddToggle('Triggerbot_UI_Toggle', {
            Text = 'UI for Mobile',
            Default = false,
            Tooltip = 'Shows a draggable button to toggle TriggerBot',
            Callback = function(state)
                TB_Gui.Enabled = state
                Refresh_TB_Button()
            end
        })

        local Drag_Input, Drag_Start, Start_Position, Dragged = nil, nil, nil, false

        Connections_Manager['Mobile_TB_Input'] = TB_Button.InputBegan:Connect(function(Input)
            if Input.UserInputType ~= Enum.UserInputType.Touch
                and Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                return
            end
            Drag_Input, Drag_Start, Start_Position, Dragged = Input, Input.Position, TB_Button.Position, false
        end)

        Connections_Manager['Mobile_TB_Drag'] = UserInputService.InputChanged:Connect(function(Input)
            if not Drag_Input then return end
            if Input ~= Drag_Input and Input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

            local Delta = Input.Position - Drag_Start
            if not Dragged and Delta.Magnitude < DRAG_THRESHOLD then return end
            Dragged = true
            TB_Button.Position = UDim2.new(
                Start_Position.X.Scale, Start_Position.X.Offset + Delta.X,
                Start_Position.Y.Scale, Start_Position.Y.Offset + Delta.Y
            )
        end)

        Connections_Manager['Mobile_TB_Release'] = UserInputService.InputEnded:Connect(function(Input)
            if Input ~= Drag_Input then return end
            Drag_Input = nil
            if not Dragged then
                TB.Enabled = not TB.Enabled
                if TB.Enabled then
                    TB_Start()
                else
                    TB_Stop()
                end
                if Library.Toggles.Triggerbot_Toggle then
                    Library.Toggles.Triggerbot_Toggle:SetValue(TB.Enabled)
                end
                Refresh_TB_Button()
            end
        end)

        Env._Destroy_Mobile_Triggerbot = function()
            if TB_Rainbow_Conn then TB_Rainbow_Conn:Disconnect(); TB_Rainbow_Conn = nil end
            for _, k in ipairs({ 'Mobile_TB_Input', 'Mobile_TB_Drag', 'Mobile_TB_Release' }) do
                if Connections_Manager[k] then
                    Connections_Manager[k]:Disconnect()
                    Connections_Manager[k] = nil
                end
            end
            TB_Gui:Destroy()
            Env._Destroy_Mobile_Triggerbot = nil
        end
    end

    Env._TB_Stop = TB_Stop
end

do
    local D = {
        Enabled = false,
        On_Player = false,
        End_Time = 0,
        Ball_Reset = 0,
        Chance = 0.5,
        Watch = nil,
        Rng = Random.new(),
        Balls = BallsFolder,
        Alive = AliveFolder,
    }

    local function SnapBalls()
        local pname = Local_Player_Name
        local list = D.Balls
        if not list then return nil end
        local snaps, n = {}, 0
        for _, b in ipairs(list:GetChildren()) do
            if b:GetAttribute('realBall') and b:GetAttribute('target') == pname then
                local z = b:FindFirstChild('zoomies')
                if z and z.VectorVelocity.Magnitude > 30 then
                    snaps[b] = GetBallPosition(b)
                    n += 1
                end
            end
        end
        return n > 0 and snaps or nil
    end

    local function AnyMoved(snaps, thr)
        if not snaps then return false end
        for b, p1 in pairs(snaps) do
            if b.Parent and (GetBallPosition(b) - p1).Magnitude > thr then
                return true
            end
        end
        return false
    end

    local function IncomingReal()
        local char = Player.Character
        if not char then return false end
        local root = char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
        if not root then return false end
        local pname = Local_Player_Name
        local list = D.Balls
        if not list then return false end
        local ppos = root.Position
        local plrs = Players:GetPlayers()
        for _, b in ipairs(list:GetChildren()) do
            if b:GetAttribute('realBall') and b:GetAttribute('target') == pname then
                local z = b:FindFirstChild('zoomies')
                if z then
                    local v = z.VectorVelocity
                    if v.Magnitude > 30 then
                        local bp = GetBallPosition(b)
                        local to = ppos - bp
                        if to.Magnitude > 0.5 and v.Unit:Dot(to.Unit) > 0.3 then
                            return true
                        end
                        local held = false
                        for _, p in ipairs(plrs) do
                            if p ~= Player and p.Character then
                                local pr = p.Character:FindFirstChild('HumanoidRootPart')
                                if pr and (pr.Position - bp).Magnitude < 6 then
                                    held = true
                                    break
                                end
                            end
                        end
                        if not held then return true end
                    end
                end
            end
        end
        return false
    end

    local function Fire()
        local tv = os.clock() - Last_Parry
        if tv > 0.5 then
            pcall(Auto_Parry.Parry_Animation)
        end
        Auto_Parry.Parry(Selected_Parry_Type)
        Last_Parry = os.clock()
    end

    local function OnFakeHighlight(child)
        if not D.Enabled or child.Name ~= 'FAKE_HIGHLIGHT' then return end
        if D.On_Player and os.clock() < D.End_Time then return end
        if IncomingReal() then return end
        if os.clock() - D.Ball_Reset < 0.3 then return end
        if D.Rng:NextNumber() >= D.Chance then return end

        local snaps = SnapBalls()
        task.delay(0.03, function()
            if not D.Enabled or not child.Parent then return end
            if AnyMoved(snaps, 4) then return end
            D.On_Player = true
            D.End_Time = math.max(D.End_Time, os.clock() + 2)
            Fire()
        end)
    end

    local function Bind(char)
        if D.Watch then D.Watch:Disconnect(); D.Watch = nil end
        if not char then return end
        D.Watch = char.ChildAdded:Connect(OnFakeHighlight)
        local existing = char:FindFirstChild('FAKE_HIGHLIGHT')
        if existing then task.spawn(OnFakeHighlight, existing) end
    end

    local function Start()
        if D.Enabled then return end
        D.Enabled = true
        Bind(Player.Character)
        Connections_Manager['PreclickDB_Char'] = Player.CharacterAdded:Connect(Bind)
        Connections_Manager['PreclickDB_BallAdd'] = BallsFolder.ChildAdded:Connect(function(b)
            D.Ball_Reset = os.clock()
            Connections_Manager['PreclickDB_' .. b.Name .. tostring(b:GetDebugId())] =
                b:GetAttributeChangedSignal('target'):Connect(function()
                    D.Ball_Reset = os.clock()
                end)
        end)
        for _, b in ipairs(BallsFolder:GetChildren()) do
            D.Ball_Reset = os.clock()
        end
    end

    local function Stop()
        D.Enabled = false
        D.On_Player = false
        D.End_Time = 0
        if D.Watch then D.Watch:Disconnect(); D.Watch = nil end
        for k, c in pairs(Connections_Manager) do
            if type(k) == 'string' and k:sub(1, 11) == 'PreclickDB_' then
                pcall(function() c:Disconnect() end)
                Connections_Manager[k] = nil
            end
        end
    end

    Env._PreclickDB_State = D

    local G = Tabs.Main:AddLeftGroupbox("Preclick Dribble", "hand")
    local T = G:AddToggle('Preclick_DB_Toggle', {
        Text = 'Preclick Dribble',
        Default = false,
        Notify = false,
        Callback = function(s) if s then Start() else Stop() end end,
    })
    T:AddKeyPicker('Preclick_DB_Keybind', { Text = 'Preclick Dribble', Mode = 'Toggle' })
    G:AddSlider('Preclick_DB_Chance', {
        Text = 'Chance (%)',
        Default = 50, Min = 0, Max = 100, Increment = 5,
        Callback = function(v) D.Chance = v / 100 end,
    })
    G:AddSlider('Preclick_DB_Delay', {
        Text = 'Confirm Delay (ms)',
        Default = 30, Min = 10, Max = 120, Increment = 5,
        Callback = function(v) D.ConfirmDelay = v / 1000 end,
    })
end

local Auto_Spam_Group = Tabs.Main:AddRightGroupbox("Clashing", "square-mouse-pointer")

local SPAM_BASE, SPAM_MAX_RANGE = 8, 40
local SPAM_HOLD = 0.12
local SPAM_PARRIES = 3
local SPAM_PRESETS = {
    { Window = 0.6, Lead = 0.12 },
    { Window = 0.5, Lead = 0.10 },
    { Window = 0.4, Lead = 0.08 },
}
local Spam_Preset = SPAM_PRESETS[2]
local Spam_Hold_Until, Last_Spam = 0, 0
local Clash_Ball = nil
local SPAM_LEAVE_DOT = 0.7

local function Check_Clash(Ball, Info, Root, Move_Direction, Ping, Now, Locked)
    if not Info or Ball.Parent ~= BallsFolder or not Ball:GetAttribute('realBall') then return 'leave' end
    local Preset = Spam_Preset
    if Locked then
        if Now - Info.Time > Preset.Window then return 'leave' end
    elseif Recent_Parries(Now, Preset.Window) < SPAM_PARRIES then
        return 'leave'
    end

    if Info.Target ~= Local_Player_Name and Info.Previous ~= Local_Player_Name then return 'leave' end

    local Zoomies = Ball:FindFirstChild('zoomies')
    if not Zoomies then return 'leave' end
    local Ball_Velocity = Zoomies.VectorVelocity
    local Offset = Root.Position - GetBallPosition(Ball)

    local Flat = Vector3.new(Offset.X, 0, Offset.Z)
    if Flat.Magnitude > 0.001 and Move_Direction:Dot(Flat.Unit) > SPAM_LEAVE_DOT then
        return 'leave'
    end

    if Info.Target == Local_Player_Name
        and Auto_Parry.Is_Curved(Offset, Ball_Velocity - Root.AssemblyLinearVelocity, Ball_Velocity) then
        return 'pause'
    end

    local Spam_Range = math.min(SPAM_BASE + Ball_Velocity.Magnitude * (Ping / 2000 + Preset.Lead), SPAM_MAX_RANGE)
    return Offset.Magnitude <= Spam_Range and 'spam' or 'idle'
end

local Auto_Spam_Toggle = Auto_Spam_Group:AddToggle('Auto_Spam_Toggle', {
    Text = 'Auto Spam',
    Default = false,
    Notify = false,

    Callback = function(state)
        DisconnectConnection(Connections_Manager['Auto Spam'])
        Connections_Manager['Auto Spam'] = nil
        Spam_Hold_Until, Clash_Ball = 0, nil
        if not state then return end

        local function Spam_Step()
            local Character = Player.Character
            if not Character or Character.Parent ~= AliveFolder then return end

            local Root = Character.PrimaryPart
            if not Root then return end

            if Auto_Parry.Player_Has_Immortality() then
                Parries = 0
                Spam_Hold_Until, Clash_Ball = 0, nil
                return
            end

            local Now, Ping = os.clock(), Get_Comp_Ping()
            local Humanoid = Character:FindFirstChildOfClass('Humanoid')
            local Move_Direction = Humanoid and Humanoid.MoveDirection or Vector3.zero

            if Clash_Ball then
                local State = Check_Clash(Clash_Ball, Clash_Info[Clash_Ball], Root, Move_Direction, Ping, Now, true)
                if State == 'spam' then
                    Spam_Hold_Until = Now + SPAM_HOLD
                elseif State == 'pause' then
                    Spam_Hold_Until = 0
                elseif State == 'leave' then
                    Spam_Hold_Until, Clash_Ball = 0, nil
                    table.clear(Parry_Times)
                    return
                end
            end

            if not Clash_Ball then
                for Ball, Info in Clash_Info do
                    if Check_Clash(Ball, Info, Root, Move_Direction, Ping, Now, false) == 'spam' then
                        Clash_Ball, Spam_Hold_Until = Ball, Now + SPAM_HOLD
                        break
                    end
                end
            end
            if Now >= Spam_Hold_Until then return end

            Auto_Parry.Parry(Selected_Parry_Type, Now - Last_Spam < SPAM_HOLD)
            Last_Spam = Now

            if Env.Animation_Fix and Parry_Input_Method ~= 'Keypress' and not Is_Mobile then
                pcall(function()
                    keypress(0x46)
                    keyrelease(0x46)
                end)
            end
        end

        Connections_Manager['Auto Spam'] = {
            RunService.PreSimulation:Connect(Spam_Step),
            RunService.PostSimulation:Connect(Spam_Step),
        }
    end
})

Auto_Spam_Toggle:AddKeyPicker('Auto_Spam_Keybind', {
    Text = 'Auto Spam',
    Mode = 'Toggle',
})

Auto_Spam_Group:AddSlider('Auto_Spam_Threshold_Slider', {
    Text = 'Threshold',
    Tooltip = '1 = fast, 2 = mid, 3 = slow',
    Min = 1,
    Max = 3,
    Default = 2,
    Increment = 1,
    Callback = function(value)
        Spam_Preset = SPAM_PRESETS[value] or SPAM_PRESETS[2]
    end,
})

local Manual_Spam_Toggle
do
    local DRAG_THRESHOLD = 10

    local Spam_Gui = Instance.new('ScreenGui')
    Spam_Gui.Name = 'MobileSpamButton'
    Spam_Gui.ResetOnSpawn = false
    Spam_Gui.IgnoreGuiInset = true
    Spam_Gui.DisplayOrder = 100
    Spam_Gui.Enabled = false
    Spam_Gui.Parent = (typeof(gethui) == 'function' and gethui()) or game:GetService('CoreGui')

    local Spam_Button = Instance.new('TextButton')
    Spam_Button.Name = 'Spam'
    local _spamScale = math.clamp((workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 1080) / 1080, 0.7, 1.2)
    Spam_Button.AnchorPoint = Vector2.new(0.5, 0.5)
    Spam_Button.Position = UDim2.new(1, -140, 0.5, 0)
    Spam_Button.Size = UDim2.fromOffset(180 * _spamScale, 80 * _spamScale)
    Spam_Button.BackgroundColor3 = Color3.new(0, 0, 0)
    Spam_Button.BackgroundTransparency = 0.3
    Spam_Button.AutoButtonColor = false
    Spam_Button.Font = Enum.Font.GothamMedium
    Spam_Button.TextSize = math.floor(26 * _spamScale)
    Spam_Button.TextColor3 = Color3.new(1, 1, 1)
    Spam_Button.Parent = Spam_Gui
    Instance.new('UICorner', Spam_Button).CornerRadius = UDim.new(0, 12)

    local Spam_Stroke = Instance.new('UIStroke')
    Spam_Stroke.Thickness = 2
    Spam_Stroke.Color = Color3.fromRGB(80, 20, 20)
    Spam_Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    Spam_Stroke.Parent = Spam_Button

    local Spam_Rainbow_Hue = 0
    local Spam_Rainbow_Conn = nil

    local function Refresh_Spam_Button()
        local on = false
        if Library and Library.Toggles and Library.Toggles.Manual_Spam_Toggle then
            on = Library.Toggles.Manual_Spam_Toggle.Value == true
        else
            on = Connections_Manager['Manual Spam'] ~= nil
        end
        task.defer(function()
            pcall(function()
                Spam_Button.Text = on and 'On' or 'Off'
                if on then
                    Spam_Button.BackgroundColor3 = Color3.fromRGB(30, 120, 40)
                    Spam_Button.BackgroundTransparency = 0.15
                    Spam_Stroke.Thickness = 2.5
                    if not Spam_Rainbow_Conn then
                        Spam_Rainbow_Conn = RunService.RenderStepped:Connect(function(dt)
                            Spam_Rainbow_Hue = (Spam_Rainbow_Hue + dt * 0.5) % 1
                            Spam_Stroke.Color = Color3.fromHSV(Spam_Rainbow_Hue, 0.8, 1)
                        end)
                    end
                else
                    Spam_Button.BackgroundColor3 = Color3.fromRGB(100, 25, 25)
                    Spam_Button.BackgroundTransparency = 0.3
                    Spam_Stroke.Thickness = 2
                    Spam_Stroke.Color = Color3.fromRGB(80, 20, 20)
                    if Spam_Rainbow_Conn then
                        Spam_Rainbow_Conn:Disconnect()
                        Spam_Rainbow_Conn = nil
                    end
                end
            end)
        end)
    end

    local function Start_Manual_Spam()
        if Connections_Manager['Manual Spam'] then return end
        Connections_Manager['Manual Spam'] = RunService.PreRender:Connect(function()
            local Character = Player.Character
            if not Character or Character.Parent ~= AliveFolder then
                return
            end

            local Ball = Auto_Parry.Get_Balls(true)
            if not Ball or not Ball:FindFirstChild('zoomies') then
                return
            end

            Auto_Parry.Parry(Selected_Parry_Type)

            if Env.Animation_Fix and Parry_Input_Method ~= 'Keypress' and not Is_Mobile then
                pcall(function()
                    keypress(0x46)
                    keyrelease(0x46)
                end)
            end
        end)
        Refresh_Spam_Button()
    end

    local function Stop_Manual_Spam()
        if Connections_Manager['Manual Spam'] then
            Connections_Manager['Manual Spam']:Disconnect()
            Connections_Manager['Manual Spam'] = nil
        end
        Refresh_Spam_Button()
    end

    Refresh_Spam_Button()

    Manual_Spam_Toggle = Auto_Spam_Group:AddToggle('Manual_Spam_Toggle', {
        Text = 'Manual Spam',
        Default = false,
        Notify = false,
        Tooltip = 'On mobile this shows the spam button instead of spamming',

        Callback = function(state)
            if state then
                Start_Manual_Spam()
            else
                Stop_Manual_Spam()
            end
            Refresh_Spam_Button()
        end
    })

    Manual_Spam_Toggle:AddKeyPicker('Manual_Spam_Keybind', {
        Text = 'Manual Spam',
        Mode = 'Toggle',
    })

    Auto_Spam_Group:AddToggle('Manual_Spam_UI_Toggle', {
        Text = 'Manual Spam UI for Mobile',
        Default = false,
        Tooltip = 'Shows a draggable button to toggle Manual Spam',
        Callback = function(state)
            Spam_Gui.Enabled = state
            Refresh_Spam_Button()
        end
    })

    local Drag_Input, Drag_Start, Start_Position, Dragged = nil, nil, nil, false

    Spam_Button.InputBegan:Connect(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.Touch
            and Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        Drag_Input, Drag_Start, Start_Position, Dragged = Input, Input.Position, Spam_Button.Position, false
    end)

    Connections_Manager['Mobile_Spam_Drag'] = UserInputService.InputChanged:Connect(function(Input)
        if not Drag_Input then return end
        if Input ~= Drag_Input and Input.UserInputType ~= Enum.UserInputType.MouseMovement then return end

        local Delta = Input.Position - Drag_Start
        if not Dragged and Delta.Magnitude < DRAG_THRESHOLD then return end
        Dragged = true
        Spam_Button.Position = UDim2.new(
            Start_Position.X.Scale, Start_Position.X.Offset + Delta.X,
            Start_Position.Y.Scale, Start_Position.Y.Offset + Delta.Y
        )
    end)

    Connections_Manager['Mobile_Spam_Release'] = UserInputService.InputEnded:Connect(function(Input)
        if Input ~= Drag_Input then return end
        Drag_Input = nil
        if not Dragged then
            if Library.Toggles.Manual_Spam_Toggle then
                Library.Toggles.Manual_Spam_Toggle:SetValue(not Library.Toggles.Manual_Spam_Toggle.Value)
            elseif Connections_Manager['Manual Spam'] then
                Stop_Manual_Spam()
            else
                Start_Manual_Spam()
            end
        end
    end)

    Env._Destroy_Mobile_Spam = function()
        if Spam_Rainbow_Conn then Spam_Rainbow_Conn:Disconnect(); Spam_Rainbow_Conn = nil end
        Spam_Gui:Destroy()
        Env._Destroy_Mobile_Spam = nil
    end
end

Auto_Spam_Group:AddDivider()

local Animation_Fix_Toggle = Auto_Spam_Group:AddToggle('Animation_Fix_Toggle', {
    Text = 'Animation Fix',
    Default = false,

    Callback = function(state)
        Env.Animation_Fix = state
    end
})

local Phantom_Group = Tabs.Main:AddRightGroupbox("Phantom Detection", "ghost")

Phantom_Group:AddToggle('Phantom_Detection_Toggle', {
    Text = 'Phantom Detection',
    Default = false,
    Notify = false,

    Callback = function(state)
        Env.Phantom_Detection = state
    end
})

Phantom_Group:AddDropdown('Phantom_Detection_Mode_Dropdown', {
    Text = 'Phantom Mode',
    Values = { 'TP to Ball', 'Normal' },
    Multi = false,
    Default = 1,
    Callback = function(Value)
        if Value and Value ~= '' then
            Phantom_Detection_Mode = Value
        end
    end
})

local CD_Protection_Group = Tabs.Main:AddRightGroupbox("Abilities", "shield-alert")

local Auto_Ability_Toggle = CD_Protection_Group:AddToggle('Auto_Ability_Toggle', {
    Text = 'Auto Abilities',
    Default = false,
    Notify = false,

    Callback = function(state)
        Env.Auto_Ability = state
    end
})

Auto_Ability_Toggle:AddKeyPicker('Auto_Ability_Keybind', {
    Text = 'Auto Abilities',
    Mode = 'Toggle',
})

local Cooldown_Protection_Toggle = CD_Protection_Group:AddToggle('Cooldown_Protection_Toggle', {
    Text = 'Cooldown Protection',
    Default = false,
    Notify = false,

    Callback = function(state)
        Env.Cooldown_Protection = state
    end
})

Cooldown_Protection_Toggle:AddKeyPicker('Cooldown_Protection_Keybind', {
    Text = 'Cooldown Protection',
    Mode = 'Toggle',
})

CD_Protection_Group:AddToggle('ThunderDash_NoCD_Toggle', {
    Text = 'Thunder Dash No-CD',
    Default = false,
    Callback = function(state)
        Env.ThunderDash_NoCD = state
        if state then
            pcall(function()
                local abilitiesData = require(ReplicatedStorage.Shared.Abilities)
                local td = abilitiesData.All['Thunder Dash']
                if td then
                    Env._TD_OrigCD = td.cooldown
                    Env._TD_OrigReduction = td.cooldownReductionPerUpgrade
                    td.cooldown = 0.1
                    td.cooldownReductionPerUpgrade = 0
                end
                if abilitiesData.getAbilityCooldown and not Env._TD_OrigGetCD then
                    Env._TD_OrigGetCD = abilitiesData.getAbilityCooldown
                    abilitiesData.getAbilityCooldown = function(player, abilityName, level)
                        if Env.ThunderDash_NoCD and abilityName == 'Thunder Dash' then return 0.1 end
                        if Env.Dash_NoCD and abilityName == 'Dash' then return 0.1 end
                        return Env._TD_OrigGetCD(player, abilityName, level)
                    end
                end
            end)
            Connections_Manager['ThunderDash_NoCD'] = RunService.Heartbeat:Connect(function()
                if not Env.ThunderDash_NoCD then return end
                local Character = Player.Character
                if not Character then return end
                pcall(function() Character:SetAttribute('CooldownExpiration', 0) end)
                pcall(function()
                    local Hotbar = Player:FindFirstChild('PlayerGui') and Player.PlayerGui:FindFirstChild('Hotbar')
                    local Ability = Hotbar and Hotbar:FindFirstChild('Ability')
                    if Ability then
                        local Red = Ability:FindFirstChild('Red')
                        if Red then Red.Visible = false end
                    end
                end)
            end)
            local PlaceGhost
            pcall(function()
                local m = ReplicatedStorage.Shared:FindFirstChild('PlaceGhost')
                if m then PlaceGhost = require(m) end
            end)
            Connections_Manager['ThunderDash_NoCD_Input'] = UserInputService.InputBegan:Connect(function(input, gp)
                if gp then return end
                if not Env.ThunderDash_NoCD then return end
                local bound = false
                pcall(function()
                    local C = ReplicatedStorage:FindFirstChild('Controllers')
                    if C then
                        local ok, Settings = pcall(require, C:FindFirstChild('SettingsController'))
                        if ok and Settings and Settings.UseBind then
                            local ok2, ret = pcall(Settings.UseBind, Settings, input, 'Ability')
                            if ok2 and ret then bound = true end
                        end
                    end
                end)
                if not bound and input.KeyCode == Enum.KeyCode.Q then bound = true end
                if not bound then return end
                local C = Player.Character
                if not C or C.Parent ~= AliveFolder then return end
                local HRP = C:FindFirstChild('HumanoidRootPart')
                local Hum = C:FindFirstChildOfClass('Humanoid')
                if not HRP or not Hum then return end
                if Hum.MoveDirection == Vector3.zero then return end
                local upgradeLevel = 0
                pcall(function()
                    local AU = require(ReplicatedStorage.Shared.AbilityUtils)
                    upgradeLevel = AU.getAbilityUpgrade(Player, 'Thunder Dash') or 0
                end)
                local startPos = HRP.Position
                local ghostColor = upgradeLevel < 2 and Color3.fromRGB(255, 246, 120) or Color3.fromRGB(179, 0, 255)
                if PlaceGhost then pcall(PlaceGhost, C, {lifetime = 1, animationDelay = 0.5, color = ghostColor}) end
                task.spawn(function()
                    task.wait(0.05)
                    local endPos = HRP.Position
                    if (endPos - startPos).Magnitude < 2 then return end
                    pcall(function()
                        local TDSource = ReplicatedStorage.Shared.Abilities:FindFirstChild('Thunder Dash')
                        if not TDSource then return end
                        local tdPart = TDSource:FindFirstChild('ThunderDash')
                        if tdPart then
                            local fx = tdPart:Clone()
                            fx.Anchored = true
                            fx.Position = endPos
                            pcall(function() fx.WeldConstraint:Destroy() end)
                            fx.Parent = RuntimeFolder
                            if upgradeLevel >= 2 then
                                fx.Attachment.L1.Color = ColorSequence.new(Color3.fromRGB(179, 0, 255))
                            end
                            fx.Attachment.L1:Emit(10)
                            fx.sound1:Play()
                            if upgradeLevel >= 2 then fx.sound2.PlaybackSpeed = 1.5 end
                            fx.sound2:Play()
                            Debris:AddItem(fx, 3)
                        end
                        local tdAddon = TDSource:FindFirstChild('ThunderDashAddon')
                        if tdAddon then
                            local fx2 = tdAddon:Clone()
                            fx2.Position = startPos
                            fx2.Anchored = true
                            fx2.Parent = RuntimeFolder
                            if upgradeLevel >= 2 then
                                fx2.Attachment.L1.Color = ColorSequence.new(Color3.fromRGB(179, 0, 255))
                            end
                            fx2.Attachment.L1:Emit(10)
                            Debris:AddItem(fx2, 3)
                        end
                    end)
                    if PlaceGhost then
                        task.wait(0.05)
                        pcall(PlaceGhost, C, {lifetime = 1, animationDelay = 0.5, color = ghostColor})
                    end
                end)
            end)
        else
            if Connections_Manager['ThunderDash_NoCD'] then
                Connections_Manager['ThunderDash_NoCD']:Disconnect()
                Connections_Manager['ThunderDash_NoCD'] = nil
            end
            if Connections_Manager['ThunderDash_NoCD_Input'] then
                Connections_Manager['ThunderDash_NoCD_Input']:Disconnect()
                Connections_Manager['ThunderDash_NoCD_Input'] = nil
            end
            pcall(function()
                local abilitiesData = require(ReplicatedStorage.Shared.Abilities)
                local td = abilitiesData.All['Thunder Dash']
                if td then
                    if Env._TD_OrigCD ~= nil then td.cooldown = Env._TD_OrigCD; Env._TD_OrigCD = nil end
                    if Env._TD_OrigReduction ~= nil then td.cooldownReductionPerUpgrade = Env._TD_OrigReduction; Env._TD_OrigReduction = nil end
                end
                if Env._TD_OrigGetCD then
                    abilitiesData.getAbilityCooldown = Env._TD_OrigGetCD
                    Env._TD_OrigGetCD = nil
                end
            end)
        end
    end
})

CD_Protection_Group:AddToggle('Dash_NoCD_Toggle', {
    Text = 'Dash No-CD',
    Default = false,
    Callback = function(state)
        Env.Dash_NoCD = state
        if state then
            pcall(function()
                local abilitiesData = require(ReplicatedStorage.Shared.Abilities)
                local d = abilitiesData.All['Dash']
                if d then
                    Env._D_OrigCD = d.cooldown
                    Env._D_OrigReduction = d.cooldownReductionPerUpgrade
                    d.cooldown = 0.1
                    d.cooldownReductionPerUpgrade = 0
                end
                if abilitiesData.getAbilityCooldown and not Env._D_OrigGetCD then
                    Env._D_OrigGetCD = abilitiesData.getAbilityCooldown
                    abilitiesData.getAbilityCooldown = function(player, abilityName, level)
                        if Env.Dash_NoCD and abilityName == 'Dash' then return 0.1 end
                        if Env.ThunderDash_NoCD and abilityName == 'Thunder Dash' then return 0.1 end
                        return Env._D_OrigGetCD(player, abilityName, level)
                    end
                end
            end)
            local _ATH = nil
            pcall(function()
                _ATH = require(ReplicatedStorage.Shared.AbilityTimelineHandler)
            end)
            Connections_Manager['Dash_NoCD'] = RunService.Heartbeat:Connect(function()
                if not Env.Dash_NoCD then return end
                local Character = Player.Character
                if not Character then return end
                pcall(function() Character:SetAttribute('CooldownExpiration', 0) end)
                pcall(function()
                    local Hotbar = Player:FindFirstChild('PlayerGui') and Player.PlayerGui:FindFirstChild('Hotbar')
                    local Ability = Hotbar and Hotbar:FindFirstChild('Ability')
                    if Ability then
                        local Red = Ability:FindFirstChild('Red')
                        if Red then Red.Visible = false end
                    end
                end)
            end)
        else
            if Connections_Manager['Dash_NoCD'] then
                Connections_Manager['Dash_NoCD']:Disconnect()
                Connections_Manager['Dash_NoCD'] = nil
            end
            pcall(function()
                local abilitiesData = require(ReplicatedStorage.Shared.Abilities)
                local d = abilitiesData.All['Dash']
                if d then
                    if Env._D_OrigCD ~= nil then d.cooldown = Env._D_OrigCD; Env._D_OrigCD = nil end
                    if Env._D_OrigReduction ~= nil then d.cooldownReductionPerUpgrade = Env._D_OrigReduction; Env._D_OrigReduction = nil end
                end
                if Env._D_OrigGetCD then
                    abilitiesData.getAbilityCooldown = Env._D_OrigGetCD
                    Env._D_OrigGetCD = nil
                end
            end)
        end
    end
})

do
    local _DashVFX_LastFire = 0

    local function Dash_NoCD_SpawnVFX(hrp)
        if not Env.Dash_NoCD then return end
        local now = tick()
        if (now - _DashVFX_LastFire) < 0.12 then return end
        _DashVFX_LastFire = now
        pcall(function()
            local DashSource = ReplicatedStorage.Shared.Abilities:FindFirstChild('Dash')
            if not DashSource then return end
            local dashTemplate = DashSource:FindFirstChild('Dash')
            if not dashTemplate then return end
            local fx = dashTemplate:Clone()
            fx.Name = 'dash'
            fx.CFrame = hrp.CFrame
            local weld = fx:FindFirstChild('WeldConstraint')
            if weld then weld.Part0 = fx; weld.Part1 = hrp end
            local subpart = fx:FindFirstChild('part')
            if subpart then
                local subweld = subpart:FindFirstChild('WeldConstraint')
                if subweld then subweld.Part0 = subpart; subweld.Part1 = fx end
                subpart.CFrame = hrp.CFrame * CFrame.new(0, 0, -3.5)
            end
            fx.Parent = RuntimeFolder
            local att = fx:FindFirstChild('Attachment')
            if att then
                local dust = att:FindFirstChild('dust')
                if dust then dust.Enabled = true end
            end
            local swoosh = fx:FindFirstChild('Swoosh')
            if swoosh then swoosh:Play() end
            local maxswos = fx:FindFirstChild('maxswos')
            if maxswos then maxswos:Play() end
            task.delay(0.16, function()
                pcall(function()
                    if att then
                        local dust = att:FindFirstChild('dust')
                        if dust then dust.Enabled = false end
                    end
                end)
            end)
            Debris:AddItem(fx, 1.5)
        end)
        local ShockwaveEffect
        pcall(function() ShockwaveEffect = require(ReplicatedStorage.Shared.ShockwaveEffect) end)
        if ShockwaveEffect then
            for i = 0, 2 do
                task.delay(i * 0.1, function()
                    pcall(function()
                        ShockwaveEffect({
                            cframe = CFrame.new(hrp.Position),
                            diameter = 20,
                            duration = 0.25,
                            color = Color3.fromRGB(255, 255, 255),
                            orientation = 'Vertical',
                            targetTransparency = 1,
                        })
                    end)
                end)
            end
        end
    end

    local _DashHRP_Conn = nil

    local function Dash_NoCD_BindCharacter(char)
        if _DashHRP_Conn then _DashHRP_Conn:Disconnect(); _DashHRP_Conn = nil end
        if not char then return end
        local hrp = char:WaitForChild('HumanoidRootPart', 5)
        if not hrp then return end
        _DashHRP_Conn = hrp.ChildAdded:Connect(function(child)
            if not Env.Dash_NoCD then return end
            if child.ClassName ~= 'Attachment' then return end
            local dashVel = child:FindFirstChild('Dash')
            if not dashVel then task.wait(); dashVel = child:FindFirstChild('Dash') end
            if not dashVel or not dashVel:IsA('LinearVelocity') then return end
            if char:GetAttribute('AbilityActive') then return end
            Dash_NoCD_SpawnVFX(hrp)
        end)
    end

    Dash_NoCD_BindCharacter(Player.Character)
    Connections_Manager['Dash_NoCD_CharAdded'] = Player.CharacterAdded:Connect(function(char)
        task.wait(0.1)
        Dash_NoCD_BindCharacter(char)
    end)
end

if Is_Mobile then
    task.spawn(function()
        local pg = Player:FindFirstChild('PlayerGui') or Player:WaitForChild('PlayerGui', 10)
        local hotbar = pg and (pg:FindFirstChild('Hotbar') or pg:WaitForChild('Hotbar', 10))
        local ability = hotbar and (hotbar:FindFirstChild('Ability') or hotbar:WaitForChild('Ability', 10))
        if ability and ability:IsA('GuiButton') then
            Connections_Manager['ThunderDash_Mobile'] = ability.Activated:Connect(function()
                if _ScriptUnloaded or not Env.ThunderDash_NoCD then return end
                local C = Player.Character
                if not C or C.Parent ~= AliveFolder then return end
                local HRP = C:FindFirstChild('HumanoidRootPart')
                local Hum = C:FindFirstChildOfClass('Humanoid')
                if not HRP or not Hum or Hum.MoveDirection == Vector3.zero then return end
                pcall(function()
                    local ThunderDashSource = ReplicatedStorage.Shared.Abilities:FindFirstChild('Thunder Dash')
                    if not ThunderDashSource then return end
                    local tdPart = ThunderDashSource:FindFirstChild('ThunderDash')
                    if not tdPart then return end
                    local startPos = HRP.Position
                    task.spawn(function()
                        task.wait(0.05)
                        local endPos = HRP.Position
                        if (endPos - startPos).Magnitude < 2 then return end
                        local fx = tdPart:Clone()
                        fx.Anchored = true
                        fx.Position = endPos
                        pcall(function() fx.WeldConstraint:Destroy() end)
                        fx.Parent = workspace
                        if fx.Attachment and fx.Attachment.L1 then
                            fx.Attachment.L1:Emit(10)
                        end
                        pcall(function() fx.sound1:Play() end)
                        pcall(function() fx.sound2:Play() end)
                        Debris:AddItem(fx, 3)
                    end)
                end)
            end)
        end
    end)
end

Connections_Manager['ThunderDash_NoCD_Input_TopLevel'] = UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not Env.ThunderDash_NoCD then return end
    local bound = false
    pcall(function()
        local C = ReplicatedStorage:FindFirstChild('Controllers')
        if C then
            local ok, Settings = pcall(require, C:FindFirstChild('SettingsController'))
            if ok and Settings and Settings.UseBind then
                local ok2, ret = pcall(Settings.UseBind, Settings, input, 'Ability')
                if ok2 and ret then bound = true end
            end
        end
    end)
    if not bound and input.KeyCode == Enum.KeyCode.Q then bound = true end
    if not bound then return end

    local C = Player.Character
    if not C or C.Parent ~= AliveFolder then return end
    local HRP = C:FindFirstChild('HumanoidRootPart')
    local Hum = C:FindFirstChildOfClass('Humanoid')
    if not HRP or not Hum then return end
    if Hum.MoveDirection == Vector3.zero then return end

    local upgradeLevel = 0
    pcall(function()
        local AU = require(ReplicatedStorage.Shared.AbilityUtils)
        upgradeLevel = AU.getAbilityUpgrade(Player, 'Thunder Dash') or 0
    end)
    local startPos = HRP.Position

    local PlaceGhost
    pcall(function()
        local PlaceGhostModule = ReplicatedStorage.Shared:FindFirstChild('PlaceGhost')
        if PlaceGhostModule then PlaceGhost = require(PlaceGhostModule) end
    end)
    local ghostColor = upgradeLevel < 2 and Color3.fromRGB(255, 246, 120) or Color3.fromRGB(179, 0, 255)
    if PlaceGhost then
        pcall(PlaceGhost, C, {lifetime = 1, animationDelay = 0.5, color = ghostColor})
    end

    pcall(function()
        local ThunderDashSource = ReplicatedStorage.Shared.Abilities:FindFirstChild('Thunder Dash')
        if not ThunderDashSource then return end
        local tdAddon = ThunderDashSource:FindFirstChild('ThunderDashAddon')
        if not tdAddon then return end
        local fx2 = tdAddon:Clone()
        fx2.Position = startPos
        fx2.Anchored = true
        fx2.Parent = workspace
        if upgradeLevel >= 2 then
            fx2.Attachment.L1.Color = ColorSequence.new(Color3.fromRGB(179, 0, 255))
        end
        fx2.Attachment.L1.Transparency = NumberSequence.new(0)
        fx2.Attachment.L1.Size = NumberSequence.new(6)
        fx2.Attachment.L1.Brightness = 3
        fx2.Attachment.L1.Lifetime = NumberRange.new(0.3, 0.6)
        fx2.Attachment.L1:Emit(10)
        Debris:AddItem(fx2, 3)
    end)

    pcall(function()
        local ThunderDashSource = ReplicatedStorage.Shared.Abilities:FindFirstChild('Thunder Dash')
        if not ThunderDashSource then return end
        local tdPart = ThunderDashSource:FindFirstChild('ThunderDash')
        if not tdPart then return end
        local snd = tdPart:FindFirstChild('sound1')
        local snd2 = tdPart:FindFirstChild('sound2')
        if snd then
            local s = snd:Clone(); s.Parent = HRP; s:Play()
            Debris:AddItem(s, 2)
        end
        if snd2 then
            local s = snd2:Clone()
            if upgradeLevel >= 2 then s.PlaybackSpeed = 1.5 end
            s.Parent = HRP; s:Play()
            Debris:AddItem(s, 2)
        end
    end)

    task.spawn(function()
        task.wait(0.05)
        local endPos = HRP.Position
        if (endPos - startPos).Magnitude < 2 then return end

        pcall(function()
            local ThunderDashSource = ReplicatedStorage.Shared.Abilities:FindFirstChild('Thunder Dash')
            if not ThunderDashSource then return end
            local tdPart = ThunderDashSource:FindFirstChild('ThunderDash')
            if not tdPart then return end
            local fx1 = tdPart:Clone()
            fx1.Anchored = true
            fx1.Position = endPos
            pcall(function() fx1.WeldConstraint:Destroy() end)
            pcall(function() fx1.sound1:Destroy() end)
            pcall(function() fx1.sound2:Destroy() end)
            fx1.Parent = workspace
            if upgradeLevel >= 2 then
                fx1.Attachment.L1.Color = ColorSequence.new(Color3.fromRGB(179, 0, 255))
            end
            fx1.Attachment.L1.Transparency = NumberSequence.new(0)
            fx1.Attachment.L1.Size = NumberSequence.new(6)
            fx1.Attachment.L1.Brightness = 3
            fx1.Attachment.L1.Lifetime = NumberRange.new(0.3, 0.6)
            fx1.Attachment.L1:Emit(10)
            task.wait(0.05)
            fx1.Attachment.L1:Emit(10)
            Debris:AddItem(fx1, 3)
        end)
        if PlaceGhost then
            task.wait(0.05)
            pcall(PlaceGhost, C, {lifetime = 1, animationDelay = 0.5, color = ghostColor})
        end

        pcall(function()
            local dir = (endPos - startPos)
            local dist = dir.Magnitude
            local segments = math.clamp(math.floor(dist / 4), 5, 12)
            local flatDir = Vector3.new(dir.X, 0, dir.Z)
            local perp = flatDir.Magnitude > 0 and flatDir.Unit:Cross(Vector3.new(0, 1, 0)) or Vector3.new(1, 0, 0)
            local points = {}
            local boltColor = ColorSequence.new(Color3.fromRGB(180, 0, 160))
            local zigSign = 1
            for i = 0, segments do
                local t = i / segments
                local pos = startPos:Lerp(endPos, t) + Vector3.new(0, 1, 0)
                if i > 0 and i < segments then
                    local amp = math.random(15, 30) / 10
                    local edgeFade = math.min(t, 1 - t) * 2
                    pos = pos + perp * (zigSign * amp * math.clamp(edgeFade, 0.3, 1)) + Vector3.new(0, math.random(-3, 3) / 10, 0)
                    zigSign = -zigSign
                end
                table.insert(points, pos)
            end
            local container = Instance.new('Folder')
            container.Name = 'ThunderBolt'
            container.Parent = workspace
            for i = 1, #points - 1 do
                local pA = Instance.new('Part')
                pA.Anchored, pA.CanCollide, pA.Transparency = true, false, 1
                pA.Size = Vector3.new(0.1, 0.1, 0.1)
                pA.Position = points[i]
                pA.Parent = container
                local pB = Instance.new('Part')
                pB.Anchored, pB.CanCollide, pB.Transparency = true, false, 1
                pB.Size = Vector3.new(0.1, 0.1, 0.1)
                pB.Position = points[i + 1]
                pB.Parent = container
                local a0 = Instance.new('Attachment', pA)
                local a1 = Instance.new('Attachment', pB)
                local bolt = Instance.new('Beam')
                bolt.Attachment0, bolt.Attachment1 = a0, a1
                bolt.Width0, bolt.Width1 = 1.4, 1.4
                bolt.LightEmission, bolt.LightInfluence = 1, 0
                bolt.Brightness = 5
                bolt.FaceCamera, bolt.Segments = true, 1
                bolt.Color = boltColor
                bolt.Transparency = NumberSequence.new(0)
                bolt.Parent = pA
            end
            task.wait(0.15)
            for _, desc in container:GetDescendants() do
                if desc:IsA('Beam') then desc.Transparency = NumberSequence.new(0.6) end
            end
            task.wait(0.1)
            for _, desc in container:GetDescendants() do
                if desc:IsA('Beam') then desc.Transparency = NumberSequence.new(0.9) end
            end
            task.wait(0.05)
            container:Destroy()
        end)
    end)
end)

local Immortality_Group = Tabs.Main:AddRightGroupbox({
    Name = "Semi-Immortality", 
    Icon = "shield-check", 
})

local Immortality_Toggle = Immortality_Group:AddToggle('Immortality_Toggle', {
    Text = 'Semi-Immortality (BETA)',
    Default = false,
    Notify = false,

    Callback = function(state)
        Env.WantImmortality = state
        
        if state then
            local char = Player.Character
            if char and char.Parent == AliveFolder then
                Immortality_Module.Start()
            end
        else
            Immortality_Module.Stop()
        end
    end
})

Connections_Manager['Immortality_AutoStart'] = AliveFolder.ChildAdded:Connect(function(child)
    if child == Player.Character and Env.WantImmortality then
        task.wait(1.5)
        if Env.WantImmortality and Player.Character == child then
            Immortality_Module.Start()
        end
    end
end)

Immortality_Toggle:AddKeyPicker('Immortality_Keybind', {
    Text = 'Immortality',
    Mode = 'Toggle',
})

Immortality_Group:AddSlider('Immortality_BaseRadius', {
    Text = 'Base Radius',
    Default = 5,
    Min = 3,
    Max = 50,
    Increment = 1,
    Callback = function(Value)
        Immortality_Module.SetBaseRadius(Value)
    end
})

Immortality_Group:AddSlider('Immortality_MaxRadius', {
    Text = 'Max Radius',
    Default = 24,
    Min = 10,
    Max = 100,
    Increment = 1,
    Callback = function(Value)
        Immortality_Module.SetMaxRadius(Value)
    end
})

Immortality_Group:AddSlider('Immortality_MaxSpeed', {
    Text = 'Max Spin Speed',
    Default = 90,
    Min = 30,
    Max = 400,
    Increment = 5,
    Callback = function(Value)
        Immortality_Module.SetMaxSpeed(Value)
    end
})



do
local CameraUnlocked = false
local MaxZoom = 75

local function ApplyCameraSettings()
    Player.CameraMode = Enum.CameraMode.Classic
    Player.CameraMinZoomDistance = 0.5
    Player.CameraMaxZoomDistance = CameraUnlocked and MaxZoom or 70
end

local Camera_Group = Tabs.Client:AddLeftGroupbox("Camera", "camera")

Camera_Group:AddToggle("Camera_Unlock_Toggle", {
    Text = "Unlock Camera",
    Default = true,
    Callback = function(state)
        CameraUnlocked = state
        ApplyCameraSettings()
    end
})

Camera_Group:AddSlider("Camera_Zoom_Slider", {
    Text = "Max Zoom Distance",
    Default = 75,
    Min = 5,
    Max = 200,
    Increment = 1,
    Callback = function(Value)
        MaxZoom = Value
        if CameraUnlocked then
            ApplyCameraSettings()
        end
    end
})

ApplyCameraSettings()

local Stretch_Value = 1

Camera_Group:AddToggle("Stretch_Screen_Toggle", {
    Text = "Stretch Screen",
    Default = false,
    Callback = function(state)
        if state then
            if not Connections_Manager['Stretch_Screen'] then
                Connections_Manager['Stretch_Screen'] = RunService.RenderStepped:Connect(
                    function()
                        local cam = workspace.CurrentCamera
                        if not cam then return end
                        cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, Stretch_Value, 0, 0, 0, 1)
                    end
                )
            end
        else
            if Connections_Manager['Stretch_Screen'] then
                Connections_Manager['Stretch_Screen']:Disconnect()
                Connections_Manager['Stretch_Screen'] = nil
            end
        end
    end
})

Camera_Group:AddSlider("Stretch_Value_Slider", {
    Text = "Stretch Value",
    Default = 1,
    Min = 0.1,
    Max = 1,
    Increment = 0.01,
    Callback = function(Value)
        Stretch_Value = Value
    end
})

local FOV_Enabled = false
local FOV_Value = 70
local FOV_Original = nil

local function Restore_FOV()
    if FOV_Original ~= nil then
        workspace.CurrentCamera.FieldOfView = FOV_Original
        FOV_Original = nil
    end
end
Env._Restore_FOV = Restore_FOV

Camera_Group:AddToggle("FOV_Toggle", {
    Text = "FOV",
    Default = false,
    Callback = function(state)
        FOV_Enabled = state
        if state then
            if FOV_Original == nil then
                FOV_Original = workspace.CurrentCamera.FieldOfView
            end
            workspace.CurrentCamera.FieldOfView = FOV_Value
        else
            Restore_FOV()
        end
    end
})

Camera_Group:AddSlider("FOV_Slider", {
    Text = "FOV",
    Default = 70,
    Min = 70,
    Max = 120,
    Increment = 1,
    Callback = function(Value)
        FOV_Value = Value
        if FOV_Enabled then
            workspace.CurrentCamera.FieldOfView = Value
        end
    end
})
end
do
    local Viz_Group = Tabs.Client:AddLeftGroupbox("Visualizer", "wallpaper")
    local VizEnabled, VizColor = false, Color3.new(0, 1, 0)
    local RING_COUNT = 30
    local Viz, VizFolder = table.create(RING_COUNT), nil
    local Viz_CFrame, Viz_Radius = CFrame.new(), 15

    local OFFSETS, ROTATIONS = table.create(RING_COUNT), table.create(RING_COUNT)
    for i = 1, RING_COUNT do
        local angle = (i / RING_COUNT) * math.pi * 2
        OFFSETS[i] = Vector3.new(math.cos(angle), 0, math.sin(angle))
        ROTATIONS[i] = CFrame.Angles(0, -angle - math.pi / 2, 0)
    end

    local function DestroyVizParts()
        if VizFolder then VizFolder:Destroy() VizFolder = nil end
        table.clear(Viz)
        Viz_CFrame, Viz_Radius = CFrame.new(), 15
    end

    local function CreateVizParts()
        DestroyVizParts()
        VizFolder = Instance.new("Folder")
        VizFolder.Name = "ParryVizFolder"
        VizFolder:SetAttribute("NoRender_Ignore", true)
        VizFolder.Parent = workspace

        for i = 1, RING_COUNT do
            local p = Instance.new("Part")
            p.Name, p.Material, p.Color = "Viz_" .. i, Enum.Material.Neon, VizColor
            p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
            p.Size = Vector3.zero
            p.Parent = VizFolder
            Viz[i] = p
        end
    end

    local function CalcVizRadius()
        local ball = Auto_Parry.Get_Targeting_Balls() or Auto_Parry.Get_Balls(true)
        local zoomies = ball and ball:FindFirstChild('zoomies')
        local character = Player.Character
        local root = character and character.PrimaryPart
        if zoomies and root then
            return Calculate_Parry_Distance(zoomies.VectorVelocity - root.AssemblyLinearVelocity, root.Position - GetBallPosition(ball), Get_Comp_Ping(), Speed_Divisor_Multiplier, Parry_Distance_Buffer)
        end
        return 15
    end

    local function StopVisualizer()
        if Connections_Manager['Visualizer'] then
            Connections_Manager['Visualizer']:Disconnect()
            Connections_Manager['Visualizer'] = nil
        end
        if Connections_Manager['Viz_CharacterAdded'] then
            Connections_Manager['Viz_CharacterAdded']:Disconnect()
            Connections_Manager['Viz_CharacterAdded'] = nil
        end
        DestroyVizParts()
    end

    local function StartVisualizer()
        if not Connections_Manager['Viz_CharacterAdded'] then
            Connections_Manager['Viz_CharacterAdded'] = Player.CharacterAdded:Connect(function(char)
                DestroyVizParts()
                if VizEnabled then CreateVizParts() end
                char:WaitForChild('Humanoid').Died:Once(DestroyVizParts)
            end)
        end

        if not Connections_Manager['Visualizer'] then
            Connections_Manager['Visualizer'] = RunService.RenderStepped:Connect(function(dt)
                local root = Player.Character and Player.Character.PrimaryPart
                if not root then return end

                local Target_Radius = CalcVizRadius()
                if Target_Radius > Viz_Radius then
                    Viz_Radius = Target_Radius
                else
                    Viz_Radius = Viz_Radius + (Target_Radius - Viz_Radius) * math.min(1, dt * 8)
                end
                Viz_CFrame = CFrame.new(root.Position)

                local partLength = (math.pi * 2 * Viz_Radius) / RING_COUNT
                local partSize = Vector3.new(partLength, 0.20, 0.4)

                for i = 1, RING_COUNT do
                    local part = Viz[i]
                    if part then
                        part.Size = partSize
                        part.CFrame = Viz_CFrame * CFrame.new(OFFSETS[i] * Viz_Radius) * ROTATIONS[i]
                    end
                end
            end)
        end
    end

    local Visualizer_Toggle = Viz_Group:AddToggle('Visualizer_Toggle', {
        Text = 'Visualizer', Tooltip = 'Shows parry range visualization', Default = false,
        Callback = function(state)
            VizEnabled = state
            if state then
                CreateVizParts()
                StartVisualizer()
            else
                StopVisualizer()
            end
        end
    })

    Visualizer_Toggle:AddColorPicker({
        SaveId = "Visualizer_Color", Name = "Visualizer Color", Default = Color3.new(0, 1, 0),
        Callback = function(color)
            VizColor = color
            for i = 1, RING_COUNT do
                if Viz[i] then Viz[i].Color = color end
            end
        end
    })
end
do
do
local VFX_Group = Tabs.Client:AddRightGroupbox("VFX","sparkles")
local NR_Enabled = false
local NR_Gen = 0
local NR_Store = {}
local NR_Pinned = {}
local NR_HIDDEN = { Decoration = true }
local NR_Terrain = workspace.Terrain
local NR_Render = settings().Rendering
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

local function NR_IsGameplayAncestor(inst)
    local p = inst
    while p and p ~= workspace do
        if p == BallsFolder or p == AliveFolder or p == RuntimeFolder then return true end
        p = p.Parent
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
    if NR_HIDDEN[prop] then get, put = gethiddenproperty, sethiddenproperty end
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
        if part and part.Parent == nil then
            NR_HiddenParts[part] = nil
        end
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
        if token == NR_FloorScanToken and NR_Enabled then
            NR_RescanFloorAndUnhide()
        end
    end)
end


local function NR_HideMapPart(part)
    if not part:IsA('BasePart') then return end
    if NR_IsGameplayAncestor(part) then return end
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
    local PlayerGui = Player:FindFirstChild('PlayerGui')
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
    Spawn = true,
    Leaderboards = true,
    LobbySpawnPlate = true,
    Drones = true,
    ZombieCrownClash = true,
    PixelKillEvent = true,
    SummerEventBB = true,
    FriendCrate = true,
}

local NR_LobbyDestroyed = {}
local NR_InMatch = false

local function NR_IsInMatch()
    local char = Player.Character
    if not char or not char.Parent then return false end
    return char.Parent == AliveFolder
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
        return Player.PlayerGui.Settings.Frame.Frame['Misc/Gray Sky'].Button.TextLabel.Text == 'Active'
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
    Connections_Manager['NR_MapChanged'] = workspace:FindFirstChild('Map').ChildAdded:Connect(function(child)
        if not NR_Enabled then return end
        if not child:IsA('Model') then return end
        task.defer(NR_WatchMapForFloor)
    end)
    Connections_Manager['NR_MapRemoved'] = workspace:FindFirstChild('Map').ChildRemoved:Connect(function(child)
        if not NR_Enabled then return end
        if not child:IsA('Model') then return end
        task.defer(NR_RescanFloorAndUnhide)
    end)


    Connections_Manager['NR_GraySkyForce'] = Lighting.Changed:Connect(function()
        if not NR_Enabled then return end
        local now = os.clock()
        if now - NR_GraySkyAt < 0.25 then return end
        NR_GraySkyAt = now
        task.defer(NR_ApplyGraySky)
    end)
    Connections_Manager['NR_GuiAdded'] = Player.PlayerGui.ChildAdded:Connect(function(gui)
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
    Connections_Manager['NR_Runtime'] = RuntimeFolder.ChildAdded:Connect(NR_ClearRuntime)
    Connections_Manager['NR_MapDescendant'] = nil
    Connections_Manager['NR_MatchCheck'] = RunService.Heartbeat:Connect(function()
        local now = os.clock()
        if now - NR_MatchCheckAt < 0.5 then return end
        NR_MatchCheckAt = now
        NR_CheckMatchState()
    end)

    for _, v in ipairs(RuntimeFolder:GetChildren()) do NR_ClearRuntime(v) end

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

VFX_Group:AddToggle('No_Render_Toggle', {
    Text    = 'No Render',
    Tooltip = 'Disables all effects, post-processing and lighting detail, and drops render quality',
    Default = false,
    Callback = function(state)
        if state then NR_Enable() else NR_Disable() end
    end,
})

Env._NoRender_Stop = function()
    pcall(NR_Disable)
    if Env._NoRender_Stop then Env._NoRender_Stop = nil end
end

Env._AntiLag_Stop = (function()
    local enabled = false
    local cache = {}
    local conns = {}
    local hidden = { Decoration = true }
    local terrain = workspace.Terrain
    local render = settings().Rendering

    local function put(inst, prop, value)
        local get, set = inst[prop], nil
        if hidden[prop] then
            if not gethiddenproperty or not sethiddenproperty then return end
            get = gethiddenproperty(inst, prop)
            if get == value then return end
            sethiddenproperty(inst, prop, value)
        else
            if get == value then return end
            inst[prop] = value
        end
        local props = cache[inst]
        if not props then props = {}; cache[inst] = props end
        if props[prop] == nil then props[prop] = get end
    end

    local function off(obj) put(obj, 'Enabled', false) end

    local function apply(obj)
        local cls = obj.ClassName
        if cls == 'Atmosphere' then
            put(obj, 'Density', 0); put(obj, 'Haze', 0); put(obj, 'Glare', 0)
        elseif cls == 'Clouds' or cls == 'BloomEffect' or cls == 'BlurEffect'
            or cls == 'DepthOfFieldEffect' or cls == 'SunRaysEffect'
            or cls == 'ColorCorrectionEffect' or cls == 'ColorGradingEffect' then
            off(obj)
        end
    end

    local function applyChild(obj)
        if not enabled then return end
        apply(obj)
        if obj:IsA('BloomEffect') or obj:IsA('BlurEffect') or obj:IsA('DepthOfFieldEffect')
            or obj:IsA('SunRaysEffect') or obj:IsA('ColorCorrectionEffect')
            or obj:IsA('ColorGradingEffect') or obj:IsA('Clouds') then
            conns[#conns + 1] = obj:GetPropertyChangedSignal('Enabled'):Connect(function()
                if enabled and obj.Parent and obj.Enabled then obj.Enabled = false end
            end)
        end
    end

    local function scan(root)
        if not root then return end
        for _, c in ipairs(root:GetChildren()) do applyChild(c) end
    end

    local function restore()
        for inst, props in pairs(cache) do
            if inst.Parent ~= nil then
                for prop, value in pairs(props) do
                    if hidden[prop] then
                        if sethiddenproperty then pcall(sethiddenproperty, inst, prop, value) end
                    else
                        pcall(function() inst[prop] = value end)
                    end
                end
            end
        end
        table.clear(cache)
    end

    local function clearConns()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        table.clear(conns)
    end

    local function start()
        if enabled then return end
        enabled = true
        put(render, 'QualityLevel', Enum.QualityLevel.Level01)
        put(Lighting, 'GlobalShadows', false)
        put(Lighting, 'EnvironmentDiffuseScale', 0)
        put(Lighting, 'EnvironmentSpecularScale', 0)
        put(terrain, 'WaterWaveSize', 0)
        put(terrain, 'WaterWaveSpeed', 0)
        put(terrain, 'WaterReflectance', 0)
        scan(Lighting)
        scan(terrain)
        scan(workspace.CurrentCamera)
        Connections_Manager['AntiLag_LightingChild'] = Lighting.ChildAdded:Connect(applyChild)
        Connections_Manager['AntiLag_CameraChild'] = workspace.CurrentCamera.ChildAdded:Connect(applyChild)
        Connections_Manager['AntiLag_CameraChanged'] = workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
            local cam = workspace.CurrentCamera
            if cam and enabled then scan(cam) end
        end)
        Connections_Manager['AntiLag_TerrainChild'] = terrain.ChildAdded:Connect(applyChild)
    end

    local function stop()
        if not enabled then return end
        enabled = false
        clearConns()
        for _, key in ipairs({ 'AntiLag_LightingChild', 'AntiLag_CameraChild', 'AntiLag_CameraChanged', 'AntiLag_TerrainChild' }) do
            local c = Connections_Manager[key]
            if c then pcall(function() c:Disconnect() end) Connections_Manager[key] = nil end
        end
        restore()
    end

    VFX_Group:AddToggle('Performance_Mode_Toggle', {
        Text = 'Performance Mode',
        Tooltip = 'Lowers render quality, disables shadows and post-processing; fully reversible',
        Default = false,
        Callback = function(state)
            if state then start() else stop() end
        end,
    })

    return stop
end)()


local Ball_Glow_Toggle = VFX_Group:AddToggle('Ball_Glow_Toggle', {
    Text = 'Long Trail',
    Default = false,

    Callback = function(state)
        SetBallGlow(state)
    end
})
end
local Leaderboard_Group = Tabs.Client:AddRightGroupbox("Leaderboard", "trophy")

local Reveal_Stats = {
    Wins  = { Attribute = 'PlayerWins',  Enabled = false },
    Elims = { Attribute = 'PlayerElims', Enabled = false },
}

local Reveal_Server  = setmetatable({}, { __mode = 'k' })
local Reveal_Written = setmetatable({}, { __mode = 'k' })
local Reveal_Hooked  = setmetatable({}, { __mode = 'k' })
local Reveal_Conns   = {}

local function Reveal_Choose(serverValue, realValue)
    return realValue
end

local function Reveal_Apply(player, statName)
    local ls = player:FindFirstChild('leaderstats')
    local stat = ls and ls:FindFirstChild(statName)
    if not (stat and stat:IsA('IntValue')) then return end

    local info = Reveal_Stats[statName]
    if Reveal_Server[stat] == nil then Reveal_Server[stat] = stat.Value end

    local target = Reveal_Server[stat]
    local real = player:GetAttribute(info.Attribute)
    if info.Enabled and type(real) == 'number' then
        target = Reveal_Choose(Reveal_Server[stat], real)
    end

    if type(target) == 'number' and stat.Value ~= target then
        Reveal_Written[stat] = target
        stat.Value = target
    end
end

local function Reveal_HookStat(player, stat)
    if Reveal_Hooked[stat] or not Reveal_Stats[stat.Name] then return end
    Reveal_Hooked[stat] = true

    table.insert(Reveal_Conns, stat.Changed:Connect(function(value)
        if value == Reveal_Written[stat] then
            Reveal_Written[stat] = nil
            return
        end
        Reveal_Server[stat] = value
        Reveal_Apply(player, stat.Name)
    end))
    Reveal_Apply(player, stat.Name)
end

local function Reveal_HookPlayer(player)
    local function HookLeaderstats(ls)
        for _, stat in ipairs(ls:GetChildren()) do Reveal_HookStat(player, stat) end
        table.insert(Reveal_Conns, ls.ChildAdded:Connect(function(stat) Reveal_HookStat(player, stat) end))
    end

    local ls = player:FindFirstChild('leaderstats')
    if ls then HookLeaderstats(ls) end
    table.insert(Reveal_Conns, player.ChildAdded:Connect(function(child)
        if child.Name == 'leaderstats' then HookLeaderstats(child) end
    end))

    for statName, info in pairs(Reveal_Stats) do
        table.insert(Reveal_Conns, player:GetAttributeChangedSignal(info.Attribute):Connect(function()
            Reveal_Apply(player, statName)
        end))
    end
end

local function Reveal_Refresh()
    local active = Reveal_Stats.Wins.Enabled or Reveal_Stats.Elims.Enabled

    for _, player in ipairs(Players:GetPlayers()) do
        for statName in pairs(Reveal_Stats) do Reveal_Apply(player, statName) end
    end

    if active and not Connections_Manager['Reveal_Stats'] then
        for _, player in ipairs(Players:GetPlayers()) do Reveal_HookPlayer(player) end
        Connections_Manager['Reveal_Stats'] = Players.PlayerAdded:Connect(Reveal_HookPlayer)
    elseif not active and Connections_Manager['Reveal_Stats'] then
        Connections_Manager['Reveal_Stats']:Disconnect()
        Connections_Manager['Reveal_Stats'] = nil
        for _, conn in ipairs(Reveal_Conns) do conn:Disconnect() end
        table.clear(Reveal_Conns)
        table.clear(Reveal_Hooked)
        table.clear(Reveal_Server)
        table.clear(Reveal_Written)
    end
end

Leaderboard_Group:AddToggle('Show_Wins_Toggle', {
    Text    = 'Show Wins',
    Default = false,
    Callback = function(state)
        Reveal_Stats.Wins.Enabled = state
        Reveal_Refresh()
    end,
})

Leaderboard_Group:AddToggle('Show_Kills_Toggle', {
    Text    = 'Show Elims',
    Default = false,
    Callback = function(state)
        Reveal_Stats.Elims.Enabled = state
        Reveal_Refresh()
    end,
})

Env._Reveal_Cleanup = function()
    for _, conn in ipairs(Reveal_Conns) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(Reveal_Conns)
    table.clear(Reveal_Hooked)
    table.clear(Reveal_Server)
    table.clear(Reveal_Written)
end

local Appearance_Group = Tabs.Client:AddRightGroupbox("Appearance", "person-standing")

local function CreateSkinToggle(group, toggleName, text, presetName)
    group:AddToggle(toggleName, {
        Text = text,
        Default = false,
        Callback = function(state)
            local connKey = 'Skin_' .. presetName
            
            if state then
                local char = Player.Character
                if char then
                    SkinChanger.SetPreset(char, presetName, true)
                end
                
                Connections_Manager[connKey] = Player.CharacterAppearanceLoaded:Connect(function(newChar)
                    task.defer(function()
                        SkinChanger.SetPreset(newChar, presetName, true)
                    end)
                end)
            else
                if Connections_Manager[connKey] then
                    Connections_Manager[connKey]:Disconnect()
                    Connections_Manager[connKey] = nil
                end
                
                if Player.Character then
                    SkinChanger.SetPreset(Player.Character, presetName, false)
                end
            end
        end,
    })
end

CreateSkinToggle(Appearance_Group, 'Headless_Only_Toggle', 'Headless', 'Headless')
CreateSkinToggle(Appearance_Group, 'Korblox_Only_Toggle', 'Korblox', 'Korblox')

local Forcefield_Original = setmetatable({}, { __mode = 'k' })
local R6_PARTS = { 'Head', 'Torso', 'Left Arm', 'Right Arm', 'Left Leg', 'Right Leg' }

local function Apply_Forcefield(character, color)
    if not character then return end
    color = color or Color3.fromRGB(0, 170, 255)

    for _, name in ipairs(R6_PARTS) do
        local part = character:FindFirstChild(name)
        if part and part:IsA('BasePart') then
            if not Forcefield_Original[part] then
                Forcefield_Original[part] = {
                    Material = part.Material,
                    Color = part.Color,
                    Reflectance = part.Reflectance,
                    Transparency = part.Transparency,
                }
            end
            part.Material = Enum.Material.ForceField
            part.Color = color
            part.Reflectance  = 0
            part.Transparency = Forcefield_Original[part].Transparency
        end
    end

    for _, acc in ipairs(character:GetChildren()) do
        if acc:IsA('Accessory') then
            local handle = acc:FindFirstChild('Handle')
            if handle and handle:IsA('BasePart') then
                if not Forcefield_Original[handle] then
                    Forcefield_Original[handle] = {
                        Material = handle.Material,
                        Color = handle.Color,
                        Reflectance  = handle.Reflectance,
                        Transparency = handle.Transparency,
                    }
                end
                handle.Material = Enum.Material.ForceField
                handle.Color = color
                handle.Reflectance  = 0
                handle.Transparency = Forcefield_Original[handle].Transparency
            end
        end
    end
end

local function Remove_Forcefield(character)
    if not character then return end
    for part, orig in pairs(Forcefield_Original) do
        if part and part:IsDescendantOf(character) then
            part.Material     = orig.Material
            part.Color = orig.Color
            part.Reflectance  = orig.Reflectance
            part.Transparency = orig.Transparency
            Forcefield_Original[part] = nil
        end
    end
end

local Forcefield_Color = Color3.fromRGB(0, 170, 255)

local Forcefield_Toggle = Appearance_Group:AddToggle('Forcefield_Toggle', {
    Text    = 'Forcefield',
    Default = false,

    Callback = function(state)
        local connKey = 'Forcefield_Appearance'
        
        if state then
            local char = Player.Character
            if char then
                Apply_Forcefield(char, Forcefield_Color)
            end
            
            Connections_Manager[connKey] = Player.CharacterAppearanceLoaded:Connect(function(newChar)
                task.defer(function()
                    Apply_Forcefield(newChar, Forcefield_Color)
                end)
            end)
        else
            if Connections_Manager[connKey] then
                Connections_Manager[connKey]:Disconnect()
                Connections_Manager[connKey] = nil
            end
            
            if Player.Character then
                Remove_Forcefield(Player.Character)
            end
        end
    end,
})

Forcefield_Toggle:AddColorPicker({
    SaveId = 'Forcefield_Color',
    Default = Color3.fromRGB(0, 170, 255),
    Name = 'Forcefield Color',
    Transparency = 0,
    Callback = function(color)
        Forcefield_Color = color
        if Forcefield_Toggle.Value then
            Apply_Forcefield(Player.Character, color)
        end
    end,
})

Appearance_Group:AddDivider()

local Avatar_Changer_Toggle = Appearance_Group:AddToggle('Avatar_Changer_Toggle', {
    Text = 'Avatar Changer',
    Default = false,

    Callback = function(state)
        if state then
            task.spawn(function()
                local Character = Player.Character or Player.CharacterAdded:Wait()
                if Character and SkinConfig.Current_User_ID then
                    SkinChanger.ApplyCustomAvatar(Character, SkinConfig.Current_User_ID)
                end
            end)

            Connections_Manager['Avatar Changer'] = Player.CharacterAppearanceLoaded:Connect(function()
                if SkinConfig.Current_User_ID then
                    local Character = Player.Character
                    if Character then
                        SkinChanger.ApplyCustomAvatar(Character, SkinConfig.Current_User_ID)
                    end
                end
            end)
        else
            SkinChanger.RestoreCharacter(Player.Character)
            if Connections_Manager['Avatar Changer'] then
                Connections_Manager['Avatar Changer']:Disconnect()
                Connections_Manager['Avatar Changer'] = nil
            end
        end
    end,
})

Appearance_Group:AddInput('Avatar_Changer_Textbox', {
    Text = 'Avatar ID/Username',
    Default = '',
    Placeholder = 'Username or UserID',
    Numeric = false,
    Finished = true,

    Callback = function(Value)
        if not Value or Value == '' then
            return
        end

        task.spawn(function()
            local ID = tonumber(Value)

            if not ID then
                local success, result
                for _ = 1, 5 do
                    success, result = true, Players:GetUserIdFromNameAsync(Value)
                    if success and result then break end
                    task.wait(0.5)
                end

                if not (success and result) then
                    if Window then
                        Window:Notify({
                            Title = 'Avatar Changer',
                            Content = 'Could not find user: ' .. tostring(Value),
                            Duration = 2,
                        })
                    end
                    return
                end

                ID = result
            end

            SkinChanger.SetCustomAvatar(ID)

            if Library.Toggles.Avatar_Changer_Toggle and Library.Toggles.Avatar_Changer_Toggle.Value then
                local Character = Player.Character or Player.CharacterAdded:Wait()
                if Character then
                    local ok = SkinChanger.ApplyCustomAvatar(Character, ID)
                    if Window then
                        Window:Notify({
                            Title = 'Avatar Changer',
                            Content = ok and ('Applied avatar (ID ' .. tostring(ID) .. ')') or 'Failed to apply avatar',
                            Duration = 3,
                        })
                    end
                end
            end
        end)
    end
})
end
local Passive_Abilities = {
    ['Quad Jump'] = true, 
    ['Luck'] = true, 
    ['Reaper'] = true,  
    ['Misfortune'] = true,  
    ['Martyrdom'] = true,  
    ['Golden Ball'] = true,  
    ['Tact'] = true,  
    ['Scopophobia'] = true,  
    ['Bounty'] = true,  
    ['Qi-Charge'] = true,
    ['Virus'] = true,
}

local Charge_Abilities = {
    ['Guardian Angel'] = {
        ChargeAttr = 'GuardianAngelParriesLeft',
        MaxCharges = 2,
        MaxChargesByLevel = { [0] = 1, [1] = 2 },
        NextUseAttr = 'GuardianAngelNextUse'
    },
    ['Quantum Arena'] = {
        ChargeAttr = 'QuantumArenaCharge',
        MaxCharges = 3,
    },
    ['Necromancer'] = {
        ChargeAttr = 'NecromancersLeft',
        MaxChargesAttr = 'NecromancersMax',
    },
}

task.spawn(function()
    local TextChatService = game:GetService("TextChatService")
    local HttpService = game:GetService("HttpService")
    local PlayerGui = Player:WaitForChild("PlayerGui")
    local UnlockSavePath = "Vanana/unlock_save.json"
    local UnlockSettings = { FinisherEquipped = {}, FakeFavorites = {}, FakeDeleted = {}, EmoteSlots = {} }
    local CanPersistUnlockSettings = (typeof(writefile) == "function")
        and (typeof(readfile) == "function")
        and (typeof(isfile) == "function")

    local RestoreCallbacks, DisabledGameConnections = {}, {}
    local UnlockConnections = {}
    local SuspendCallbacks = {}
    local IsUnlockSuspended = false
    local IsUnlockDisposed = false
    local ClearFinisherClones
    local StopFinisherPlayback
    local IsAccessoryVisibilityLoopCancelled = false
    local AccessoryVisibilityGeneration = 0
    local SelectedExplosionName
    local LastFakeSwordName

    local function EnsureUnlockSaveFolder()
        if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder("Vanana") then
            makefolder("Vanana")
        end
    end
    local FavoriteOverrides = UnlockSettings.FakeFavorites
    local function LoadUnlockSettings()
        if not CanPersistUnlockSettings then
            return
        end
        EnsureUnlockSaveFolder()
        if isfile(UnlockSavePath) then
            local ok, data = pcall(HttpService.JSONDecode, HttpService, readfile(UnlockSavePath))
            if ok and type(data) == "table" then
                UnlockSettings.FinisherEquipped = data.FinisherEquipped or {}
                local loadedFavs = data.FakeFavorites or {}
                for k, v in pairs(loadedFavs) do
                    FavoriteOverrides[k] = v
                end
                UnlockSettings.FakeFavorites = FavoriteOverrides
                if data.FakeShowAccessoryPerSword then
                    UnlockSettings.FakeShowAccessoryPerSword = data.FakeShowAccessoryPerSword
                end
                if data.FakeDeleted then
                    UnlockSettings.FakeDeleted = data.FakeDeleted
                end
                if type(data.EmoteSlots) == "table" then
                    UnlockSettings.EmoteSlots = data.EmoteSlots
                end
                if data.LastSword then
                    UnlockSettings.LastSword = data.LastSword
                    LastFakeSwordName = data.LastSword
                end
                if data.LastExplosion then
                    UnlockSettings.LastExplosion = data.LastExplosion
                end
            end
        end
        for name, on in pairs(UnlockSettings.FinisherEquipped) do
            Env.FinisherEquipped[name] = on
        end
    end

    local SaveUnlockSettings
    do
        local pending = false
        SaveUnlockSettings = function()
            if not CanPersistUnlockSettings or pending then
                return
            end
            pending = true
            task.delay(0.3, function()
                pending = false
                EnsureUnlockSaveFolder()
                UnlockSettings.FinisherEquipped = Env.FinisherEquipped
                UnlockSettings.FakeFavorites = FavoriteOverrides or UnlockSettings.FakeFavorites or {}
                UnlockSettings.FakeDeleted = UnlockSettings.FakeDeleted or {}
                if Env.Unlock_Enabled and not IsUnlockSuspended then
                    UnlockSettings.LastSword = LastFakeSwordName or UnlockSettings.LastSword
                    UnlockSettings.LastExplosion = SelectedExplosionName or UnlockSettings.LastExplosion
                end
                writefile(UnlockSavePath, HttpService:JSONEncode(UnlockSettings))
            end)
        end
    end

    LoadUnlockSettings()

    local function RegisterRestoreCallback(fn)
        table.insert(RestoreCallbacks, fn)
    end
    local function RegisterSuspendCallback(fn)
        table.insert(SuspendCallbacks, fn)
    end
    local function DisableGameConnection(c)
        if _ScriptUnloaded or IsUnlockDisposed then
            return
        end
        if c and c.Disable then
            table.insert(DisabledGameConnections, c)
            if Env.Unlock_Enabled and not IsUnlockSuspended then
                c:Disable()
            end
        end
    end
    local function ConnectUnlockSignal(signal, callback)
        if _ScriptUnloaded or IsUnlockDisposed then
            if not callback and signal then
                signal:Disconnect()
            end
            return nil
        end
        local c = signal
        if callback then
            c = signal:Connect(function(...)
                if _ScriptUnloaded or not Env.Unlock_Enabled or IsUnlockSuspended or IsUnlockDisposed then
                    return
                end
                return callback(...)
            end)
        end
        if c then
            table.insert(UnlockConnections, c)
        end
        return c
    end
    local function DisconnectSignals(connections)
        for _, connection in pairs(connections) do
            if connection and connection.Disconnect then
                connection:Disconnect()
            end
        end
        table.clear(connections)
    end
    local function DisableTrackedGameConnections()
        for _, c in ipairs(DisabledGameConnections) do
            do
                if c.Disable then
                    c:Disable()
                end
            end
        end
    end
    local function SuspendUnlockAll()
        if IsUnlockSuspended then
            return
        end
        IsUnlockSuspended = true
        IsAccessoryVisibilityLoopCancelled = true
        AccessoryVisibilityGeneration += 1
        for _, c in ipairs(DisabledGameConnections) do
            do
                if c.Enable then
                    c:Enable()
                end
            end
        end
        if StopFinisherPlayback then
            StopFinisherPlayback()
        end
        if ClearFinisherClones then
            ClearFinisherClones()
        end
        for i = #SuspendCallbacks, 1, -1 do
            SuspendCallbacks[i]()
        end
    end
    local function ResumeUnlockAll()
        if _ScriptUnloaded or IsUnlockDisposed then
            return
        end
        IsUnlockSuspended = false
        IsAccessoryVisibilityLoopCancelled = false
        DisableTrackedGameConnections()
    end
    local function DisposeUnlockAll()
        if IsUnlockDisposed then
            return
        end
        Env.Unlock_Enabled = false
        IsUnlockDisposed = true
        SuspendUnlockAll()
        DisconnectSignals(UnlockConnections)
        if Env._Unlock_RestoreTextChatHook then
            Env._Unlock_RestoreTextChatHook()
        end
        for i = #RestoreCallbacks, 1, -1 do
            RestoreCallbacks[i]()
        end
    end
    Env._Unlock_RunReverters = DisposeUnlockAll
    local function RunUnlockStep(name, fn)
        if type(fn) ~= "function" then
            return
        end
        local ok, err = pcall(fn)
        if not ok then
            warn("[Unlocker] " .. name .. " failed: " .. tostring(err))
        end
    end

    do
        local EmoteSession, EmoteSessionGeneration, AreEmotesDisposed = nil, 0, false
        local function IsEmoteUnlockEnabled()
            return not _ScriptUnloaded
                and not IsUnlockDisposed
                and not IsUnlockSuspended
                and not AreEmotesDisposed
                and Env.Unlock_Enabled
        end
        local function StopEmotePlayback(CurrentEmoteSession)
            local EmotePlayback = CurrentEmoteSession.Playback
            CurrentEmoteSession.Playback = nil
            if not EmotePlayback then
                return
            end
            DisconnectSignals(EmotePlayback.Connections)
            EmotePlayback.Trove:Destroy()
            do
                if EmotePlayback.Character:GetAttribute("Emoting") == EmotePlayback.Name then
                    EmotePlayback.Character:SetAttribute("Emoting", EmotePlayback.PreviousEmoting)
                end
            end
        end
        local function DisposeEmoteSession()
            EmoteSessionGeneration = EmoteSessionGeneration + 1
            local CurrentEmoteSession = EmoteSession
            EmoteSession = nil
            if not CurrentEmoteSession then
                return
            end
            StopEmotePlayback(CurrentEmoteSession)
            DisconnectSignals(CurrentEmoteSession.Connections)
            for _, hook in ipairs(CurrentEmoteSession.Hooks) do
                if hook.Module[hook.Method] == hook.Wrapper then
                    hook.Module[hook.Method] = hook.Original
                end
            end
            for button, snapshot in pairs(CurrentEmoteSession.OriginalButtons) do
                if button.Parent then
                    for _, attribute in ipairs({ "EmoteId", "EmoteName", "Icon" }) do
                        button:SetAttribute(attribute, snapshot[attribute])
                    end
                    if button:IsA("ImageButton") or button:IsA("ImageLabel") then
                        button.Image = snapshot.Image
                    end
                    local vector = button:FindFirstChild("Vector")
                    if vector and snapshot.VectorImage then
                        vector.Image = snapshot.VectorImage
                    end
                    local title = button:FindFirstChild("Title")
                    if title and snapshot.TitleText then
                        title.Text = snapshot.TitleText
                    end
                end
            end
            if CurrentEmoteSession.View and type(CurrentEmoteSession.View.Destroy) == "function" then
                CurrentEmoteSession.View:Destroy()
            end
            if CurrentEmoteSession.Container then
                CurrentEmoteSession.Container:Destroy()
            end
            if CurrentEmoteSession.Source then
                CurrentEmoteSession.Source.Visible = CurrentEmoteSession.SourceVisible
            end
            for _, method in ipairs({ "UpdateHolderEmotes", "UpdateMenuContentEmotes", "updateCenterText" }) do
                if type(CurrentEmoteSession.Wheel[method]) == "function" then
                    CurrentEmoteSession.Wheel[method](CurrentEmoteSession.Wheel)
                end
            end
        end
        local function InitializeEmoteUnlocks()
            if not IsEmoteUnlockEnabled() then
                return
            end
            if EmoteSession then
                if EmoteSession.Gui and EmoteSession.Gui.Parent then
                    EmoteSession.Refresh()
                    return
                end
                DisposeEmoteSession()
            end
            EmoteSessionGeneration = EmoteSessionGeneration + 1
            local EmoteInitializationGeneration = EmoteSessionGeneration
            local function BuildEmoteCatalog()
                if
                    EmoteInitializationGeneration ~= EmoteSessionGeneration
                    or not IsEmoteUnlockEnabled()
                    or EmoteSession
                then
                    return true
                end
                local EmoteWheelGui = PlayerGui:FindFirstChild("EmoteWheel")
                local EmoteWheelList = EmoteWheelGui and EmoteWheelGui:FindFirstChild("List")
                local OriginalEmoteContent = EmoteWheelList and EmoteWheelList:FindFirstChild("Content")
                local EmoteCardTemplate = OriginalEmoteContent
                    and OriginalEmoteContent:FindFirstChild("TEMPLATE", true)
                local MiscFolder = ReplicatedStorage:FindFirstChild("Misc")
                local EmotesFolder = MiscFolder and MiscFolder:FindFirstChild("Emotes")
                if not EmoteWheelGui or not OriginalEmoteContent or not EmotesFolder then
                    return false
                end
                local controllers = ReplicatedStorage:FindFirstChild("Controllers")
                local shared = ReplicatedStorage:FindFirstChild("Shared")
                local packages = ReplicatedStorage:FindFirstChild("Packages")
                local wheelModule = controllers and controllers:FindFirstChild("EmoteWheelController")
                local controllerModule = controllers and controllers:FindFirstChild("EmoteController")
                local sharedModule = shared and shared:FindFirstChild("EmotesShared")
                local troveModule = packages and packages:FindFirstChild("Trove")
                if not wheelModule or not controllerModule or not sharedModule or not troveModule then
                    return false
                end
                local EmoteWheelController = require(wheelModule)
                local EmoteController = require(controllerModule)
                local EmotesModule = require(sharedModule)
                local TroveModule = require(troveModule)
                local itemInfoModule = shared:FindFirstChild("ItemInfo")
                local EmoteItemInfo = itemInfoModule and require(itemInfoModule).Emote or {}
                if type(EmotesModule.Play) ~= "function" then
                    return false
                end
                if EmoteInitializationGeneration ~= EmoteSessionGeneration or not IsEmoteUnlockEnabled() then
                    return true
                end
                local CurrentEmoteSession = {
                    Gui = EmoteWheelGui,
                    Wheel = EmoteWheelController,
                    Source = OriginalEmoteContent,
                    SourceVisible = OriginalEmoteContent.Visible,
                    Connections = {},
                    Hooks = {},
                    Catalog = {},
                    Cards = {},
                    OriginalButtons = {},
                }
                EmoteSession = CurrentEmoteSession
                local function IsCurrentEmoteSession()
                    return EmoteSession == CurrentEmoteSession
                        and EmoteInitializationGeneration == EmoteSessionGeneration
                        and IsEmoteUnlockEnabled()
                end
                local function ConnectEmoteSignal(signal, callback)
                    local connection = signal:Connect(function(...)
                        if IsCurrentEmoteSession() then
                            return callback(...)
                        end
                    end)
                    CurrentEmoteSession.Connections[#CurrentEmoteSession.Connections + 1] = connection
                end
                local catalog = {}
                if #EmotesFolder:GetChildren() == 0 then
                    EmoteSession = nil
                    return false
                end
                for _, EmoteAnimation in ipairs(EmotesFolder:GetChildren()) do
                    if
                        EmoteAnimation:IsA("Animation")
                        and EmoteAnimation.AnimationId ~= ""
                        and EmoteAnimation.AnimationId ~= "rbxassetid://0"
                    then
                        CurrentEmoteSession.Catalog[EmoteAnimation.Name] = EmoteAnimation
                        catalog[#catalog + 1] = EmoteAnimation
                    end
                end
                if #catalog == 0 then
                    EmoteSession = nil
                    return false
                end
                table.sort(catalog, function(a, b)
                    local an, bn =
                        a:GetAttribute("EmoteName") or a.Name, b:GetAttribute("EmoteName") or b.Name
                    return an == bn and a.Name < b.Name or an < bn
                end)
                local slots = {}
                for key, name in
                    pairs(type(UnlockSettings.EmoteSlots) == "table" and UnlockSettings.EmoteSlots or {})
                do
                    local slot = tonumber(key)
                    if
                        slot
                        and slot == math.floor(slot)
                        and slot >= 1
                        and slot <= 40
                        and type(name) == "string"
                        and CurrentEmoteSession.Catalog[name]
                    then
                        slots[tostring(slot)] = name
                    end
                end
                UnlockSettings.EmoteSlots = slots
                local function UpdateEmoteButton(button, EmoteAnimation)
                    local info = EmoteItemInfo[EmoteAnimation.Name] or {}
                    local name = EmoteAnimation:GetAttribute("EmoteName")
                        or info.DisplayName
                        or EmoteAnimation.Name
                    local icon = EmoteAnimation:GetAttribute("Icon") or info.Icon or ""
                    button:SetAttribute("EmoteId", EmoteAnimation.Name)
                    button:SetAttribute("EmoteName", name)
                    button:SetAttribute("Icon", icon)
                    local vector = button:FindFirstChild("Vector")
                    if vector then
                        vector.Image = icon
                    elseif button:IsA("ImageButton") then
                        button.Image = icon
                    end
                    local label = button:FindFirstChild("ItemName")
                        or button:FindFirstChild("Title")
                        or button:FindFirstChild("Text")
                    if label and label:IsA("TextLabel") then
                        label.Text = name
                    end
                end
                local function UpdateEmoteSlot(button, animation)
                    if not CurrentEmoteSession.OriginalButtons[button] then
                        local vector = button:FindFirstChild("Vector")
                        local title = button:FindFirstChild("Title")
                        CurrentEmoteSession.OriginalButtons[button] = {
                            EmoteId = button:GetAttribute("EmoteId"),
                            EmoteName = button:GetAttribute("EmoteName"),
                            Icon = button:GetAttribute("Icon"),
                            Image = (button:IsA("ImageButton") or button:IsA("ImageLabel")) and button.Image,
                            VectorImage = vector and vector.Image,
                            TitleText = title and title.Text,
                        }
                    end
                    UpdateEmoteButton(button, animation)
                end
                CurrentEmoteSession.Refresh = function()
                    if not IsCurrentEmoteSession() then
                        return
                    end
                    local wheelGui, menu =
                        EmoteWheelGui:FindFirstChild("Wheel"), EmoteWheelGui:FindFirstChild("Menu")
                    local holder = wheelGui and wheelGui:FindFirstChild("Holder")
                    local menuContent = menu and menu:FindFirstChild("Content")
                    local page = math.clamp(math.floor(tonumber(EmoteWheelController.page) or 1), 1, 5)
                    for key, name in pairs(UnlockSettings.EmoteSlots) do
                        local slot, EmoteAnimation = tonumber(key), CurrentEmoteSession.Catalog[name]
                        if slot and EmoteAnimation then
                            if holder and math.floor((slot - 1) / 8) + 1 == page then
                                local button = holder:FindFirstChild(tostring((slot - 1) % 8 + 1))
                                if button then
                                    UpdateEmoteSlot(button, EmoteAnimation)
                                end
                            end
                            local button = menuContent and menuContent:FindFirstChild(tostring(slot))
                            if button then
                                UpdateEmoteSlot(button, EmoteAnimation)
                            end
                        end
                    end
                end
                local function PlayEmote(name)
                    if not IsCurrentEmoteSession() then
                        return
                    end
                    local EmoteCharacter, EmoteAnimation = Player.Character, CurrentEmoteSession.Catalog[name]
                    local EmoteHumanoid = EmoteCharacter and EmoteCharacter:FindFirstChildOfClass("Humanoid")
                    if
                        not EmoteAnimation
                        or not EmoteHumanoid
                        or EmoteHumanoid.Health <= 0
                        or EmoteHumanoid.MoveDirection.Magnitude > 0
                    then
                        return
                    end
                    StopEmotePlayback(CurrentEmoteSession)
                    local EmotePlayback = {
                        Character = EmoteCharacter,
                        Trove = TroveModule.new(),
                        Connections = {},
                        Name = EmoteAnimation:GetAttribute("EmoteName") or name,
                        PreviousEmoting = EmoteCharacter:GetAttribute("Emoting"),
                    }
                    CurrentEmoteSession.Playback = EmotePlayback
                    EmoteCharacter:SetAttribute("Emoting", EmotePlayback.Name)
                    local function WatchEmotePlayback(signal, callback)
                        EmotePlayback.Connections[#EmotePlayback.Connections + 1] = signal:Connect(callback)
                    end
                    WatchEmotePlayback(EmoteHumanoid:GetPropertyChangedSignal("MoveDirection"), function()
                        if
                            CurrentEmoteSession.Playback == EmotePlayback
                            and EmoteHumanoid.MoveDirection.Magnitude > 0
                        then
                            StopEmotePlayback(CurrentEmoteSession)
                        end
                    end)
                    WatchEmotePlayback(EmoteHumanoid.Died, function()
                        if CurrentEmoteSession.Playback == EmotePlayback then
                            StopEmotePlayback(CurrentEmoteSession)
                        end
                    end)
                    EmotesModule:Play(
                        EmoteCharacter,
                        EmotePlayback.Trove,
                        name,
                        true,
                        workspace:GetServerTimeNow(),
                        1,
                        nil,
                        false
                    )
                    if
                        CurrentEmoteSession.Playback == EmotePlayback
                        and (not IsCurrentEmoteSession() or Player.Character ~= EmoteCharacter)
                    then
                        StopEmotePlayback(CurrentEmoteSession)
                    end
                end
                local function HookEmoteMethod(module, method, wrap)
                    local original = module[method]
                    if type(original) ~= "function" then
                        return
                    end
                    local wrapper = wrap(original)
                    CurrentEmoteSession.Hooks[#CurrentEmoteSession.Hooks + 1] =
                        { Module = module, Method = method, Original = original, Wrapper = wrapper }
                    module[method] = wrapper
                end
                local excluded = {}
                for _, child in ipairs(OriginalEmoteContent:GetChildren()) do
                    if child:IsA("GuiObject") then
                        excluded[child] = child.Archivable
                        child.Archivable = false
                    end
                end
                for _, child in ipairs(OriginalEmoteContent:GetDescendants()) do
                    if child:IsA("GuiButton") and excluded[child] == nil then
                        excluded[child] = child.Archivable
                        child.Archivable = false
                    end
                end
                local sourceArchivable = OriginalEmoteContent.Archivable
                OriginalEmoteContent.Archivable = true
                local EmoteCatalogContainer = OriginalEmoteContent:Clone()
                OriginalEmoteContent.Archivable = sourceArchivable
                for child, archivable in pairs(excluded) do
                    child.Archivable = archivable
                end
                if not EmoteCatalogContainer then
                    DisposeEmoteSession()
                    return true
                end
                CurrentEmoteSession.Container = EmoteCatalogContainer
                EmoteCatalogContainer.Name = "UnlockAllEmoteContent"
                local IsScrollingContainer = EmoteCatalogContainer:IsA("ScrollingFrame")
                if IsScrollingContainer then
                    EmoteCatalogContainer.CanvasPosition = Vector2.zero
                    EmoteCatalogContainer.AutomaticCanvasSize = Enum.AutomaticSize.None
                    EmoteCatalogContainer.ScrollingDirection = Enum.ScrollingDirection.Y
                    EmoteCatalogContainer.ScrollingEnabled = true
                    EmoteCatalogContainer.ScrollBarThickness =
                        math.max(OriginalEmoteContent.ScrollBarThickness, 6)
                end
                EmoteCatalogContainer.Visible = true
                EmoteCatalogContainer.Parent = OriginalEmoteContent.Parent
                OriginalEmoteContent.Visible = false
                ConnectEmoteSignal(OriginalEmoteContent:GetPropertyChangedSignal("Visible"), function()
                    if OriginalEmoteContent.Visible then
                        OriginalEmoteContent.Visible = false
                    end
                end)
                local grid = EmoteCatalogContainer:FindFirstChildWhichIsA("UIGridLayout")
                if not grid then
                    grid = Instance.new("UIGridLayout")
                    grid.CellSize = UDim2.fromOffset(100, 100)
                    grid.CellPadding = UDim2.fromOffset(8, 8)
                    grid.SortOrder = Enum.SortOrder.LayoutOrder
                    grid.Parent = EmoteCatalogContainer
                end
                local function ResizeCanvas()
                    if grid and IsScrollingContainer then
                        EmoteCatalogContainer.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 8)
                    end
                end
                if grid then
                    ConnectEmoteSignal(grid:GetPropertyChangedSignal("AbsoluteContentSize"), ResizeCanvas)
                end
                local search = EmoteWheelList:FindFirstChild("SearchInput", true)
                local function Filter()
                    local query = string.lower(search and search.Text or ""):match("^%s*(.-)%s*$")
                    for _, entry in ipairs(CurrentEmoteSession.Cards) do
                        entry.Button.Visible = query == "" or string.find(entry.Search, query, 1, true) ~= nil
                    end
                    ResizeCanvas()
                end
                if search then
                    ConnectEmoteSignal(search:GetPropertyChangedSignal("Text"), Filter)
                end
                local SelectedEmoteSlot = 1
                local function WatchEmoteSlots(container)
                    if not container then
                        return
                    end
                    for _, button in ipairs(container:GetChildren()) do
                        local slot = tonumber(button.Name)
                        if slot and button:IsA("GuiButton") then
                            ConnectEmoteSignal(button.Activated, function()
                                SelectedEmoteSlot = slot
                            end)
                        end
                    end
                end
                local wheel = EmoteWheelGui:FindFirstChild("Wheel")
                local menu = EmoteWheelGui:FindFirstChild("Menu")
                WatchEmoteSlots(wheel and wheel:FindFirstChild("Holder"))
                WatchEmoteSlots(menu and menu:FindFirstChild("Content"))
                local function ApplySelectedEmote(name)
                    if not IsCurrentEmoteSession() or not CurrentEmoteSession.Catalog[name] then
                        return
                    end
                    local slot = math.floor(tonumber(EmoteWheelController.selected) or SelectedEmoteSlot)
                    if EmoteWheelController.type == "Menu" then
                        slot = math.clamp(slot, 1, 40)
                    else
                        local page = math.clamp(math.floor(tonumber(EmoteWheelController.page) or 1), 1, 5)
                        slot = math.clamp(slot, 1, 8) + (page - 1) * 8
                    end
                    local key = tostring(slot)
                    if UnlockSettings.EmoteSlots[key] ~= name then
                        UnlockSettings.EmoteSlots[key] = name
                        SaveUnlockSettings()
                    end
                    CurrentEmoteSession.Refresh()
                    if type(EmoteWheelController.updateCenterText) == "function" then
                        EmoteWheelController.updateCenterText(EmoteWheelController)
                    end
                end
                local YieldDeadline = os.clock() + 0.002
                local function YieldIfBusy()
                    if os.clock() >= YieldDeadline then
                        RunService.Heartbeat:Wait()
                        YieldDeadline = os.clock() + 0.002
                    end
                    return IsCurrentEmoteSession()
                end
                local function BuildFallbackCards()
                    for index, EmoteAnimation in ipairs(catalog) do
                        if not YieldIfBusy() then
                            return false
                        end
                        local EmoteCard
                        if EmoteCardTemplate and EmoteCardTemplate:IsA("GuiObject") then
                            local archivable = EmoteCardTemplate.Archivable
                            EmoteCardTemplate.Archivable = true
                            EmoteCard = EmoteCardTemplate:Clone()
                            EmoteCardTemplate.Archivable = archivable
                        else
                            EmoteCard = Instance.new("ImageButton")
                            EmoteCard.Size = UDim2.fromOffset(100, 100)
                            EmoteCard.BackgroundTransparency = 1
                            local label = Instance.new("TextLabel")
                            label.Name = "Title"
                            label.Size = UDim2.new(1, 0, 0, 24)
                            label.Position = UDim2.new(0, 0, 1, -24)
                            label.BackgroundTransparency = 1
                            label.TextColor3 = Color3.new(1, 1, 1)
                            label.TextScaled = true
                            label.Parent = EmoteCard
                        end
                        EmoteCard.Name = "UnlockEmote_" .. EmoteAnimation.Name
                        EmoteCard.LayoutOrder = index
                        UpdateEmoteButton(EmoteCard, EmoteAnimation)
                        for _, childName in ipairs({ "Lock", "Favorite", "Delete" }) do
                            local child = EmoteCard:FindFirstChild(childName)
                            if child and child:IsA("GuiObject") then
                                child.Visible = false
                            end
                        end
                        EmoteCard.Visible = true
                        EmoteCard.Parent = EmoteCatalogContainer
                        CurrentEmoteSession.Cards[#CurrentEmoteSession.Cards + 1] = {
                            Button = EmoteCard,
                            Search = string.lower(
                                (EmoteAnimation:GetAttribute("EmoteName") or EmoteAnimation.Name)
                                    .. " "
                                    .. EmoteAnimation.Name
                            ),
                        }
                        local button = EmoteCard:IsA("GuiButton") and EmoteCard
                            or EmoteCard:FindFirstChildWhichIsA("GuiButton", true)
                        if button then
                            ConnectEmoteSignal(button.Activated, function()
                                ApplySelectedEmote(EmoteAnimation.Name)
                            end)
                        end
                    end
                    return true
                end
                HookEmoteMethod(EmoteController, "Play", function(original)
                    return function(self, name, ...)
                        if IsCurrentEmoteSession() and CurrentEmoteSession.Catalog[name] then
                            return PlayEmote(name)
                        end
                        return original(self, name, ...)
                    end
                end)
                for _, method in ipairs({ "UpdateHolderEmotes", "UpdateMenuContentEmotes", "updatePage" }) do
                    HookEmoteMethod(EmoteWheelController, method, function(original)
                        return function(self, ...)
                            local results = table.pack(original(self, ...))
                            CurrentEmoteSession.Refresh()
                            return table.unpack(results, 1, results.n)
                        end
                    end)
                end
                ConnectEmoteSignal(Player.CharacterAdded, function()
                    StopEmotePlayback(CurrentEmoteSession)
                end)
                ConnectEmoteSignal(Player.CharacterAppearanceLoaded, function()
                    CurrentEmoteSession.Refresh()
                end)
                ConnectEmoteSignal(EmoteWheelGui.AncestryChanged, function()
                    if not EmoteWheelGui.Parent then
                        DisposeEmoteSession()
                    end
                end)
                local inventoryModule = shared:FindFirstChild("Inventory")
                local inventorySharedModule = inventoryModule and inventoryModule:FindFirstChild("Shared")
                local trading = controllers:FindFirstChild("Trading")
                local inventoryControllerModule = trading and trading:FindFirstChild("InventoryController")
                if inventoryModule and inventorySharedModule and inventoryControllerModule then
                    local InventoryClient = require(inventoryModule).Client
                    local InventoryShared = require(inventorySharedModule)
                    local InventoryController = require(inventoryControllerModule)
                    local inventory = InventoryClient:GetInventory()
                    local emoteInventory = table.clone(inventory.Emote or {})
                    local ownedNames = {}
                    for _, owned in pairs(emoteInventory) do
                        if type(owned) == "table" and owned.Name then
                            ownedNames[owned.Name] = true
                        end
                    end
                    local itemsByName, itemsList, idsByKey = {}, {}, {}
                    for _, animation in ipairs(catalog) do
                        if not ownedNames[animation.Name] then
                            local item = { Name = animation.Name, Id = "UnlockAll:Emote:" .. animation.Name, CreatedAt = 0 }
                            itemsByName[item.Name] = item
                            itemsList[#itemsList + 1] = item
                            local key = InventoryShared:ItemToKey("Emote", item, { "Id" })
                            idsByKey[key] = item.Id
                        end
                    end
                    HookEmoteMethod(InventoryClient, "GetInventory", function(original)
                        return function(self, ...)
                            local real = original(self, ...)
                            if not IsCurrentEmoteSession() then
                                return real
                            end
                            local merged = table.clone(real)
                            merged.Emote = table.clone(real.Emote or {})
                            for _, item in pairs(itemsByName) do
                                merged.Emote[item.Id] = item
                            end
                            return merged
                        end
                    end)
                    HookEmoteMethod(InventoryClient, "GetItem", function(original)
                        return function(self, itemType, id, ...)
                            local name = itemType == "Emote" and tostring(id):match("^UnlockAll:Emote:(.+)$")
                            if IsCurrentEmoteSession() and name and itemsByName[name] then
                                return itemsByName[name]
                            end
                            return original(self, itemType, id, ...)
                        end
                    end)
                    HookEmoteMethod(InventoryClient, "FindItemsWithKey", function(original)
                        return function(self, itemType, key, ...)
                            if IsCurrentEmoteSession() and itemType == "Emote" and idsByKey[key] then
                                return { idsByKey[key] }
                            end
                            return original(self, itemType, key, ...)
                        end
                    end)
                    if type(InventoryShared.CreateFakeReplion) == "function"
                        and type(InventoryController.CreateInventory) == "function"
                        and type(EmoteWheelController.populateEmoteList) == "function" then
                        local replion = InventoryShared.CreateFakeReplion()
                        replion.Data = { Inventory = { Emote = emoteInventory } }
                        local caller = { Replion = replion }
                        HookEmoteMethod(InventoryController, "CreateInventory", function(original)
                            return function(self, config, ...)
                                if not IsCurrentEmoteSession() or config.InventoryType ~= "Emote" then
                                    return original(self, config, ...)
                                end
                                if CurrentEmoteSession.View then
                                    return CurrentEmoteSession.View
                                end
                                local options = table.clone(config)
                                options.Caller = caller
                                options.Container = EmoteCatalogContainer
                                options.WatchOnChange = false
                                options.FindItemsWithKey = function(itemType, key)
                                    local id = itemType == "Emote" and idsByKey[key]
                                    if id then
                                        return emoteInventory[id] and { id } or {}
                                    end
                                    return InventoryShared:FindItemsWithKey(caller, itemType, key)
                                end
                                local onSlotCreated = options.OnSlotCreated
                                options.OnSlotCreated = function(itemType, item, key, button, trove)
                                    if onSlotCreated then
                                        onSlotCreated(itemType, item, key, button, trove)
                                    end
                                    if item and itemsByName[item.Name] and button then
                                        if typeof(getconnections) == "function" then
                                            for _, connection in ipairs(getconnections(button.Activated)) do
                                                connection:Disconnect()
                                            end
                                        end
                                        ConnectEmoteSignal(button.Activated, function()
                                            ApplySelectedEmote(item.Name)
                                        end)
                                    end
                                end
                                CurrentEmoteSession.View = original(self, options, ...)
                                return CurrentEmoteSession.View
                            end
                        end)
                        local createSortOptions = InventoryController.CreateSortOptions
                        if type(createSortOptions) == "function" then
                            InventoryController.CreateSortOptions = function() end
                        end
                        local populated = pcall(EmoteWheelController.populateEmoteList, EmoteWheelController)
                        InventoryController.CreateSortOptions = createSortOptions
                        if populated and CurrentEmoteSession.View then
                            local view = CurrentEmoteSession.View
                            if type(view.TriggerUpdate) == "function" then
                                for _, item in ipairs(itemsList) do
                                    if not YieldIfBusy() then
                                        return true
                                    end
                                    if not emoteInventory[item.Id] then
                                        emoteInventory[item.Id] = item
                                        view.TriggerUpdate(item, "Insert")
                                    end
                                end
                            end
                            EmoteCatalogContainer.Visible = true
                            OriginalEmoteContent.Visible = false
                        end
                    end
                end
                if not CurrentEmoteSession.View then
                    if not BuildFallbackCards() then
                        return true
                    end
                    Filter()
                end
                CurrentEmoteSession.Refresh()
                return true
            end
            local function TryBuild()
                local ok, built = pcall(BuildEmoteCatalog)
                if ok then
                    return built
                end
                warn("[Unlocker] Emote unlock failed: " .. tostring(built))
                DisposeEmoteSession()
                return true
            end
            if TryBuild() then
                return
            end
            task.spawn(function()
                while
                    EmoteInitializationGeneration == EmoteSessionGeneration
                    and IsEmoteUnlockEnabled()
                    and not EmoteSession
                do
                    if TryBuild() then
                        return
                    end
                    task.wait(0.25)
                end
            end)
        end
        Env._Unlock_InitializeEmotes = InitializeEmoteUnlocks
        RegisterSuspendCallback(DisposeEmoteSession)
        RegisterRestoreCallback(function()
            AreEmotesDisposed = true
            DisposeEmoteSession()
            if Env._Unlock_InitializeEmotes == InitializeEmoteUnlocks then
                Env._Unlock_InitializeEmotes = nil
            end
        end)
        ConnectUnlockSignal(PlayerGui.ChildAdded, function(child)
            if child.Name == "EmoteWheel" then
                task.defer(InitializeEmoteUnlocks)
            end
        end)
    end

    local function IsLocalPlayerName(name)
        return type(name) == "string" and (name == Player.DisplayName or name == Player.Name)
    end
    local function GetEquippedFinisherName()
        if not Env.Unlock_Enabled then
            return false
        end
        local sword = Env.Sword_Name
        return (sword and Env.FinisherEquipped[sword]) and sword or false
    end

    local FinishersController = require(ReplicatedStorage.Controllers.FinishersController)
    local RecentKillWindowSeconds = 4
    local LastVictimClone, LastKillTime, IsFinisherPlaying = nil, 0, false
    local FinisherClonesByName, LastVictimName = {}, nil
    local CachedOpponentCharacters = {}

    local function TrackOpponentCharacter(OpponentPlayer)
        if OpponentPlayer == Player then
            return
        end
        if OpponentPlayer.Character then
            CachedOpponentCharacters[OpponentPlayer] = OpponentPlayer.Character
        end
        ConnectUnlockSignal(OpponentPlayer.CharacterAdded, function(OpponentCharacter)
            CachedOpponentCharacters[OpponentPlayer] = OpponentCharacter
        end)
    end
    for _, OpponentPlayer in ipairs(Players:GetPlayers()) do
        TrackOpponentCharacter(OpponentPlayer)
    end
    ConnectUnlockSignal(Players.PlayerAdded, TrackOpponentCharacter)
    ConnectUnlockSignal(Players.PlayerRemoving, function(OpponentPlayer)
        CachedOpponentCharacters[OpponentPlayer] = nil
    end)

    local function CreateFinisherCharacterClone(character)
        local clone = character:Clone()
        for _, desc in ipairs(clone:GetDescendants()) do
            if desc:IsA("Script") or desc:IsA("LocalScript") then
                desc:Destroy()
            end
        end
        for _, child in ipairs(clone:GetChildren()) do
            if child:IsA("Tool") then
                child:Destroy()
            end
        end
        local OpponentHumanoid = clone:FindFirstChildOfClass("Humanoid")
        if OpponentHumanoid then
            OpponentHumanoid.Health, OpponentHumanoid.BreakJointsOnDeath = OpponentHumanoid.MaxHealth, false
            if not OpponentHumanoid:FindFirstChildOfClass("Animator") then
                Instance.new("Animator").Parent = OpponentHumanoid
            end
        end
        local CloneRoot = clone:FindFirstChild("HumanoidRootPart")
        if CloneRoot then
            clone.PrimaryPart = CloneRoot
        end
        for _, desc in ipairs(clone:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.Anchored, desc.CanCollide, desc.Massless = false, false, true
            end
        end
        clone.Parent = workspace
        return clone
    end

    local function CacheFinisherClone(name, displayName, clone)
        local entry = { clone = clone }
        FinisherClonesByName[name] = entry
        if displayName then
            FinisherClonesByName[displayName] = entry
        end
    end

    local function EnsureFinisherClone(victimName)
        local entry = FinisherClonesByName[victimName]
        if entry and entry.clone and entry.clone.Parent then
            return
        end
        for _, OpponentPlayer in ipairs(Players:GetPlayers()) do
            if
                OpponentPlayer ~= Player
                and (OpponentPlayer.Name == victimName or OpponentPlayer.DisplayName == victimName)
            then
                local OpponentCharacter, OpponentHumanoid =
                    OpponentPlayer.Character,
                    OpponentPlayer.Character and OpponentPlayer.Character:FindFirstChildOfClass("Humanoid")
                if OpponentCharacter and OpponentHumanoid and OpponentHumanoid.Health > 0 then
                    if entry and entry.clone then
                        entry.clone:Destroy()
                    end
                    local clone = CreateFinisherCharacterClone(OpponentCharacter)
                    local CloneRoot = clone:FindFirstChild("HumanoidRootPart")
                    if CloneRoot then
                        CloneRoot.Anchored = true
                        CloneRoot.CFrame = CFrame.new(0, -500, 0)
                    end
                    CacheFinisherClone(OpponentPlayer.Name, OpponentPlayer.DisplayName, clone)
                end
                break
            end
        end
    end

    ClearFinisherClones = function()
        for k, entry in pairs(FinisherClonesByName) do
            if entry and entry.clone then
                entry.clone:Destroy()
            end
            FinisherClonesByName[k] = nil
        end
    end

    local function TakeFinisherClone(victimName)
        local entry = FinisherClonesByName[victimName]
        if not entry or not entry.clone or not entry.clone.Parent then
            return nil
        end
        for k, v in pairs(FinisherClonesByName) do
            if v == entry then
                FinisherClonesByName[k] = nil
            end
        end
        return entry.clone
    end

    local function FindVictimCharacter(victimName)
        local victim = Players:FindFirstChild(victimName)
        if victim then
            return victim.Character or CachedOpponentCharacters[victim]
        end
        for OpponentPlayer, OpponentCharacter in pairs(CachedOpponentCharacters) do
            if
                (OpponentPlayer.Name == victimName or OpponentPlayer.DisplayName == victimName)
                and OpponentCharacter
            then
                return OpponentCharacter
            end
        end
    end

    local OriginalTeleportHandlers = {}
    for _, c in getconnections(ReplicatedStorage.Remotes.LocalTeleport.OnClientEvent) do
        if c and c.Function then
            table.insert(OriginalTeleportHandlers, { conn = c, func = c.Function })
            DisableGameConnection(c)
        end
    end
    local DeferredTeleportArguments = nil
    local FinisherPlaybackState = nil
    StopFinisherPlayback = function(expectedState, replayTeleport)
        if expectedState and FinisherPlaybackState ~= expectedState then
            return false
        end
        local state = FinisherPlaybackState
        FinisherPlaybackState = nil
        IsFinisherPlaying = false
        local teleport = DeferredTeleportArguments
        DeferredTeleportArguments = nil
        if state then
            do
                if state.Root and state.Root.Parent then
                    state.Root.CFrame = state.CFrame
                    state.Root.Anchored = state.Anchored
                end
            end
            state.VictimClone:Destroy()
            state.KillerClone:Destroy()
        end
        if LastVictimClone then
            LastVictimClone:Destroy()
        end
        LastVictimClone, LastVictimName = nil, nil
        if replayTeleport ~= false and teleport then
            for _, entry in ipairs(OriginalTeleportHandlers) do
                entry.func(table.unpack(teleport, 1, teleport.n))
            end
        end
        return true
    end
    ConnectUnlockSignal(ReplicatedStorage.Remotes.LocalTeleport.OnClientEvent, function(...)
        if Env.Unlock_Enabled and IsFinisherPlaying then
            DeferredTeleportArguments = table.pack(...)
            return
        end
        for _, entry in ipairs(OriginalTeleportHandlers) do
            entry.func(...)
        end
    end)

    ConnectUnlockSignal(Player.CharacterAdded, function()
        StopFinisherPlayback(nil, false)
        ClearFinisherClones()
    end)

    local PlayFinisherRemote = ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/PlayFinisher"]
    local HasServerFinisherPlayed = false
    for _, c in getconnections(PlayFinisherRemote.OnClientEvent) do
        if c and c.Function then
            local originalHandler = c.Function
            DisableGameConnection(c)
            ConnectUnlockSignal(
                PlayFinisherRemote.OnClientEvent,
                function(finisherName, killerPlayer, victimPlayer, ...)
                    local EquippedFinisherName = GetEquippedFinisherName()
                    if killerPlayer == Player and EquippedFinisherName then
                        HasServerFinisherPlayed = true
                        originalHandler(EquippedFinisherName, killerPlayer, victimPlayer, ...)
                    else
                        originalHandler(finisherName, killerPlayer, victimPlayer, ...)
                    end
                end
            )
            break
        end
    end

    ConnectUnlockSignal(ReplicatedStorage.Remotes.Killed.OnClientEvent, function(victimName)
        if not GetEquippedFinisherName() or IsLocalPlayerName(victimName) then
            return
        end
        LastVictimName = victimName
        EnsureFinisherClone(victimName)
        local victimChar = FindVictimCharacter(victimName)
        if not victimChar then
            return
        end
        local prevClone = LastVictimClone
        if prevClone then
            task.delay(0.6, function()
                if prevClone ~= LastVictimClone then
                    prevClone:Destroy()
                end
            end)
        end
        local clone = CreateFinisherCharacterClone(victimChar)
        do
            local CloneRoot = clone:FindFirstChild("HumanoidRootPart")
            if CloneRoot then
                CloneRoot.Anchored = true
                CloneRoot.CFrame = CFrame.new(0, -500, 0)
            end
        end
        LastVictimClone, LastKillTime, HasServerFinisherPlayed = clone, os.clock(), false
    end)

    ConnectUnlockSignal(ReplicatedStorage.Remotes.WinnerText.OnClientEvent, function(text)
        if IsFinisherPlaying then
            return
        end
        if type(text) ~= "string" then
            return
        end
        local winner = string.match(text, "^(.-)%s+[Ww]ins?!?$")
        if not winner then
            winner = (text:gsub("%s*[Ww]ins?!?%s*$", ""))
        end
        winner = winner and winner:match("^%s*(.-)%s*$")
        if not IsLocalPlayerName(winner) then
            return
        end
        local activeFinisher = GetEquippedFinisherName()
        if not activeFinisher then
            return
        end
        if HasServerFinisherPlayed then
            HasServerFinisherPlayed = false
            return
        end

        local lastVictim = TakeFinisherClone(LastVictimName)
        if not lastVictim then
            EnsureFinisherClone(LastVictimName)
            lastVictim = TakeFinisherClone(LastVictimName)
        end
        if not lastVictim then
            for name in pairs(FinisherClonesByName) do
                lastVictim = TakeFinisherClone(name)
                if lastVictim then
                    break
                end
            end
        end
        if not lastVictim and not LastVictimClone then
            return
        end
        if not lastVictim and (os.clock() - LastKillTime) > RecentKillWindowSeconds then
            LastVictimClone:Destroy()
            LastVictimClone = nil
            return
        end

        local killerChar = Player.Character
        if not killerChar then
            return
        end
        local killerClone = CreateFinisherCharacterClone(killerChar)
        local victimClone = lastVictim or LastVictimClone
        local vhrp = victimClone:FindFirstChild("HumanoidRootPart")
        if vhrp then
            vhrp.Anchored = false
        end
        if lastVictim and LastVictimClone then
            LastVictimClone:Destroy()
        end
        LastVictimClone = nil
        IsFinisherPlaying = true

        local centerCFrame
        local balls = workspace:FindFirstChild("Balls")
        if balls then
            local bp = balls:FindFirstChildWhichIsA("BasePart", true)
            if bp then
                centerCFrame = CFrame.new(bp.Position + Vector3.new(0, 3, 0))
            end
        end
        if not centerCFrame then
            local CloneRoot = killerChar:FindFirstChild("HumanoidRootPart")
            centerCFrame = CloneRoot and CFrame.new(CloneRoot.Position) or CFrame.new(0, 50, 0)
        end
        do
            local vh = victimClone:FindFirstChild("HumanoidRootPart")
            if vh then
                vh.CFrame = centerCFrame
            end
        end
        do
            local kh = killerClone:FindFirstChild("HumanoidRootPart")
            if kh then
                kh.CFrame = centerCFrame * CFrame.new(0, 0, 4)
            end
        end

        local realHRP = killerChar:FindFirstChild("HumanoidRootPart")
        local state = {
            Root = realHRP,
            CFrame = realHRP and realHRP.CFrame,
            Anchored = realHRP and realHRP.Anchored,
            KillerClone = killerClone,
            VictimClone = victimClone,
        }
        FinisherPlaybackState = state
        if realHRP then
            realHRP.Anchored = true
            realHRP.CFrame = CFrame.new(0, -500, 0)
        end
        local played = pcall(
            FinishersController.PlayFinisher,
            FinishersController,
            activeFinisher,
            killerClone,
            victimClone,
            centerCFrame,
            workspace:GetServerTimeNow()
        )
        if FinisherPlaybackState ~= state then
            return
        end
        if
            not played
            or _ScriptUnloaded
            or not Env.Unlock_Enabled
            or IsUnlockSuspended
            or IsUnlockDisposed
        then
            StopFinisherPlayback(state)
            return
        end

        task.spawn(function()
            local duration = 5
            do
                local df = ReplicatedStorage.Misc.DataFinishers:FindFirstChild(activeFinisher)
                if df then
                    duration = df:GetAttribute("Duration") or 5
                end
            end
            task.wait(duration + 0.5)
            if not StopFinisherPlayback(state) then
                return
            end
            if _ScriptUnloaded or not Env.Unlock_Enabled or IsUnlockSuspended or IsUnlockDisposed then
                return
            end
            if Env.Sword_Name and Player.Character == killerChar then
                task.defer(function()
                    if _ScriptUnloaded or not Env.Unlock_Enabled or IsUnlockSuspended or IsUnlockDisposed then
                        return
                    end
                    local KillerCharacter = Player.Character
                    if KillerCharacter ~= killerChar then
                        return
                    end
                    for _, child in ipairs(KillerCharacter:GetChildren()) do
                        if child:IsA("Tool") then
                            child:Destroy()
                        end
                    end
                    task.wait()
                    if
                        _ScriptUnloaded
                        or not Env.Unlock_Enabled
                        or IsUnlockSuspended
                        or IsUnlockDisposed
                        or Player.Character ~= KillerCharacter
                    then
                        return
                    end
                    local Swords = require(ReplicatedStorage.Shared.ReplicatedInstances.Swords)
                    Swords:ForceEquipSwordTo(KillerCharacter, Env.Sword_Name)
                    if Env._Sword_Function then
                        Env._Sword_Function(Env.Sword_Name)
                    end
                end)
            end
        end)
    end)

    local IsInventoryUnlockInitialized = false
    local function InitializeInventoryUnlocks()
        if _ScriptUnloaded or IsUnlockDisposed or IsInventoryUnlockInitialized or not Env.Unlock_Enabled then
            return
        end
        IsInventoryUnlockInitialized = true
        local ShopController = require(ReplicatedStorage.Controllers.UI.ShopController)
        local InventoryController = require(ReplicatedStorage.Controllers.Trading.InventoryController)
        local function RefreshInventoryPage(itemType)
            local page = ShopController._inventoryPages and ShopController._inventoryPages[itemType]
            if not page then
                return
            end
            if page.MarkDirty then
                page.MarkDirty(nil, true, true)
            elseif page.Scroll and page.Scroll.Sort then
                page.Scroll.Sort()
            end
        end

        local InventoryUnlockGeneration = 0
        local IsInventoryUnlockWorkerRunning = false

        local function DisableSignalAndGetOriginalHandler(signal)
            local fn
            for _, c in getconnections(signal) do
                if c and c.Function then
                    fn = fn or c.Function
                    if c.Disable then
                        DisableGameConnection(c)
                    end
                end
            end
            return fn
        end

        local UnlockableItemTypes = { Sword = true, Explosion = true }
        local UnlockableItemCategories = { "Sword", "Explosion" }
        local OriginalOwnershipByItem = {}
        local InventoryClient = require(ReplicatedStorage.Shared.Inventory).Client
        local CatalogLoadTimes = {}

        local function ReadItemField(Value, field)
            local value = Value[field]
            if type(value) == "table" and type(value.Get) == "function" then
                return value:Get()
            end
            return value
        end

        local function WriteItemField(Value, field, value)
            local state = Value[field]
            if type(state) == "table" and type(state.Set) == "function" then
                state:Set(value)
            else
                Value[field] = value
            end
        end

        local function LoadUnlockableCatalogs()
            for _, Category in ipairs(UnlockableItemCategories) do
                if not Env.Unlock_Enabled or IsUnlockSuspended or IsUnlockDisposed then
                    return
                end
                local now = os.clock()
                local list = ShopController._virtualItems and ShopController._virtualItems[Category]
                if
                    not CatalogLoadTimes[Category]
                    or ((not list or next(list) == nil) and now - CatalogLoadTimes[Category] >= 2)
                then
                    CatalogLoadTimes[Category] = now
                    if type(ShopController._loadInventoryPage) == "function" then
                        ShopController._loadInventoryPage(Category)
                    end
                end
            end
        end

        local function AreUnlockableCatalogsLoaded()
            for _, Category in ipairs(UnlockableItemCategories) do
                local list = ShopController._virtualItems and ShopController._virtualItems[Category]
                if not list or next(list) == nil then
                    return false
                end
            end
            return true
        end

        local function ApplyLocalOwnership()
            local updates = 0
            if not Env.Unlock_Enabled or IsUnlockSuspended or IsUnlockDisposed then
                return updates
            end
            for _, Category in ipairs(UnlockableItemCategories) do
                local Shop_List = ShopController._virtualItems and ShopController._virtualItems[Category]
                if not Shop_List then
                    continue
                end
                local page = ShopController._inventoryPages and ShopController._inventoryPages[Category]
                local items, seen = {}, {}
                for _, Value in pairs(Shop_List) do
                    if type(Value) == "table" and not seen[Value] then
                        seen[Value] = true
                        items[#items + 1] = Value
                    end
                end
                for _, Value in ipairs(items) do
                    if Value.Name == "Base Sword" or Value.Name == "Explosion Normal" then
                        continue
                    end
                    local owned = ReadItemField(Value, "OwnsItem") == true
                    if not owned or OriginalOwnershipByItem[Value] then
                        if
                            UnlockSettings.FakeDeleted
                            and UnlockSettings.FakeDeleted[Category]
                            and UnlockSettings.FakeDeleted[Category][Value.Name]
                        then
                            continue
                        end
                        local entry = OriginalOwnershipByItem[Value]
                        if not entry then
                            entry = {
                                type = Category,
                                OwnsItem = ReadItemField(Value, "OwnsItem"),
                                Section = ReadItemField(Value, "Section"),
                                ForceHide = ReadItemField(Value, "ForceHide"),
                                InventoryKey = Value.InventoryKey,
                                Key = Value.Key,
                                Aliases = {},
                            }
                            OriginalOwnershipByItem[Value] = entry
                        end
                        if not entry.CanonicalKey or entry.Item ~= Value.Item or entry.Name ~= Value.Name then
                            local ok, key = pcall(InventoryClient.ItemToKey, InventoryClient, Category, Value.Item)
                            entry.CanonicalKey = ok and key or Value.Name
                            entry.Item = Value.Item
                            entry.Name = Value.Name
                            entry.Hidden = string.find(Value.Name or "", "Awakened", 1, true) ~= nil
                        end
                        local key, hidden = entry.CanonicalKey, entry.Hidden
                        local changed = not owned
                            or ReadItemField(Value, "Section") ~= "Owned"
                            or ReadItemField(Value, "ForceHide") ~= hidden
                            or Value.InventoryKey ~= key
                            or Value.Key ~= key
                        if key and Shop_List[key] ~= Value then
                            if Shop_List[key] == nil then
                                entry.Aliases[#entry.Aliases + 1] = { List = Shop_List, Key = key }
                                Shop_List[key] = Value
                                changed = true
                            end
                        end
                        if changed then
                            updates += 1
                            Value.InventoryKey = key
                            Value.Key = key
                            WriteItemField(Value, "OwnsItem", true)
                            WriteItemField(Value, "Section", "Owned")
                            WriteItemField(Value, "ForceHide", hidden)
                        end
                        if page and page.MarkDirty and (changed or entry.LastPage ~= page) then
                            updates += 1
                            page.MarkDirty(Value, false, true)
                            entry.LastPage = page
                        end
                    end
                end
            end
            return updates
        end

        local function RefreshInventoryUnlocks()
            if
                IsInventoryUnlockWorkerRunning
                or not Env.Unlock_Enabled
                or IsUnlockSuspended
                or IsUnlockDisposed
            then
                return
            end
            IsInventoryUnlockWorkerRunning = true
            InventoryUnlockGeneration += 1
            local myToken = InventoryUnlockGeneration
            task.spawn(function()
                local reportedError, idlePasses = false, 0
                while
                    myToken == InventoryUnlockGeneration
                    and Env.Unlock_Enabled
                    and not IsUnlockSuspended
                    and not IsUnlockDisposed
                do
                    local ok, updates = pcall(function()
                        LoadUnlockableCatalogs()
                        if myToken ~= InventoryUnlockGeneration then
                            return 0
                        end
                        return ApplyLocalOwnership()
                    end)
                    if not ok and not reportedError then
                        warn("[Unlocker] Inventory refresh failed: " .. tostring(updates))
                    end
                    reportedError = not ok
                    if ok and updates == 0 and AreUnlockableCatalogsLoaded() then
                        idlePasses += 1
                        if idlePasses >= 3 then
                            break
                        end
                    else
                        idlePasses = 0
                    end
                    task.wait(1)
                end
                if myToken == InventoryUnlockGeneration then
                    IsInventoryUnlockWorkerRunning = false
                end
            end)
        end
        Env._Unlock_DoUnlockAll = RefreshInventoryUnlocks

        do
            local GuiHandler = require(ReplicatedStorage.ClientGameModules.GuiHandler)
            if GuiHandler and GuiHandler.OnGuiOpen then
                ConnectUnlockSignal(GuiHandler:OnGuiOpen("Shop", function()
                    if not Env.Unlock_Enabled then
                        return
                    end
                    task.delay(0.3, function()
                        if not Env.Unlock_Enabled then
                            return
                        end
                        RefreshInventoryUnlocks()
                        if Env._Unlock_ReapplyFavorites then
                            Env._Unlock_ReapplyFavorites()
                        end
                    end)
                end))
            end
        end

        local OriginalSwordName = nil
        local function RememberOriginalSword()
            if OriginalSwordName then
                return
            end
            local char = Player.Character
            OriginalSwordName = (char and char:GetAttribute("CurrentlyEquippedSword")) or "Base Sword"
        end
        RememberOriginalSword()
        Env._Unlock_CaptureOriginalSword = function()
            OriginalSwordName = nil
            RememberOriginalSword()
        end
        RegisterSuspendCallback(function()
            InventoryUnlockGeneration += 1
            table.clear(CatalogLoadTimes)
            IsInventoryUnlockWorkerRunning = false
            for Value, entry in pairs(OriginalOwnershipByItem) do
                WriteItemField(Value, "OwnsItem", entry.OwnsItem)
                WriteItemField(Value, "Section", entry.Section)
                WriteItemField(Value, "ForceHide", entry.ForceHide)
                Value.InventoryKey = entry.InventoryKey
                Value.Key = entry.Key
                for _, alias in ipairs(entry.Aliases) do
                    if alias.List[alias.Key] == Value then
                        alias.List[alias.Key] = nil
                    end
                end
                local page = ShopController._inventoryPages and ShopController._inventoryPages[entry.type]
                if page and page.MarkDirty then
                    page.MarkDirty(Value, false, true)
                end
            end
            table.clear(OriginalOwnershipByItem)
            for _, Category in ipairs(UnlockableItemCategories) do
                RefreshInventoryPage(Category)
            end
            ShopController._selectedItem = nil
        end)

        local function MergeUnlockedInventoryItems(inventoryType, requested, real, keyed)
            local result = type(real) == "table" and real or {}
            if requested ~= nil and #result > 0 then
                return result
            end
            local list = ShopController._virtualItems and ShopController._virtualItems[inventoryType]
            local deleted = UnlockSettings.FakeDeleted and UnlockSettings.FakeDeleted[inventoryType] or {}
            if requested ~= nil then
                local item = list and list[requested]
                local name = item and item.Name or requested
                if deleted[name] then
                    return {}
                end
                return { requested }
            end
            local merged, seen = {}, {}
            for _, item in ipairs(result) do
                merged[#merged + 1] = item
                local key = type(item) == "table" and (item.Key or item.Name) or item
                if key then
                    seen[key] = true
                end
            end
            for _, item in pairs(list or {}) do
                local key = keyed and (item.InventoryKey or item.Key or item.Name) or item.Name
                if key and not seen[key] and not deleted[item.Name] then
                    merged[#merged + 1] = key
                    seen[key] = true
                end
            end
            return merged
        end

        local Inventory_Shared = require(ReplicatedStorage.Shared.Inventory.Shared)
        if typeof(Inventory_Shared.FindItems) == "function" then
            local realFindItems
            realFindItems = hookfunction(
                Inventory_Shared.FindItems,
                function(self, caller, inventoryType, itemName, filter)
                    if not Env.Unlock_Enabled or not UnlockableItemTypes[inventoryType] then
                        return realFindItems(self, caller, inventoryType, itemName, filter)
                    end
                    local real = realFindItems(self, caller, inventoryType, itemName, filter)
                    return MergeUnlockedInventoryItems(inventoryType, itemName, real, false)
                end
            )
            RegisterRestoreCallback(function()
                hookfunction(Inventory_Shared.FindItems, realFindItems)
            end)
        end

        local function HookInventoryLookup(method, keyed)
            local original = InventoryClient[method]
            if type(original) ~= "function" then
                return
            end
            local wrapper = function(self, inventoryType, requested, ...)
                if not Env.Unlock_Enabled or not UnlockableItemTypes[inventoryType] then
                    return original(self, inventoryType, requested, ...)
                end
                local real = original(self, inventoryType, requested, ...)
                return MergeUnlockedInventoryItems(inventoryType, requested, real, keyed)
            end
            InventoryClient[method] = wrapper
            RegisterRestoreCallback(function()
                if InventoryClient[method] == wrapper then
                    InventoryClient[method] = original
                end
            end)
        end
        HookInventoryLookup("FindItems", false)
        HookInventoryLookup("FindItemsWithKey", true)
        if Env.Unlock_Enabled then
            RefreshInventoryUnlocks()
        end

        local Shop = PlayerGui:WaitForChild("Shop")
        local EquipItemButton = Shop.Holder.InfoBG.BuyButton
        local Swords = require(ReplicatedStorage.Shared.ReplicatedInstances.Swords)
        local FavoriteButton = Shop.Holder.Favorite
        local DeleteButton = Shop.Holder.InfoBG.Delete
        local EquipFinisherButton = Shop.Holder.InfoBG.Equips.Finisher
        local EquipAccessoryButton = Shop.Holder.InfoBG.Equips.EquipAccessory
        local FavoriteItemTypes = { Sword = true, Explosion = true, Ability = true }
        local OriginalFavoriteFields = {}
        local FavoriteButtonIcons = {
            [true] = { Image = "rbxassetid://15697987058", HoverImage = "rbxassetid://15697983062" },
            [false] = { Image = "rbxassetid://15697981750", HoverImage = "rbxassetid://15697987058" },
        }

        local function FindVirtualItem(itemType, name)
            for key, item in pairs(ShopController._virtualItems[itemType] or {}) do
                if item and (item.Name == name or key == name) then
                    return item
                end
            end
        end

        local function IsFavorite(itemType, name)
            local names = FavoriteOverrides[itemType]
            if Env.Unlock_Enabled and names and names[name] ~= nil then
                return names[name] == true
            end
            for _, item in pairs(ShopController._virtualItems[itemType] or {}) do
                if item.Name == name and item.IsFavorited == true then
                    return true
                end
            end
            return false
        end

        local function RefreshFavoriteButton()
            if not Env.Unlock_Enabled then
                return
            end
            local SelectedItem = ShopController._selectedItem
            if not SelectedItem or not FavoriteItemTypes[SelectedItem.type] then
                return
            end
            for k, v in pairs(FavoriteButtonIcons[IsFavorite(SelectedItem.type, SelectedItem.name)]) do
                FavoriteButton[k] = v
            end
        end

        local function ApplyFavoriteOverrides(itemType)
            local names = FavoriteOverrides[itemType]
            if not names then
                return false
            end
            local changed = false
            for _, item in pairs(ShopController._virtualItems[itemType] or {}) do
                local state = names[item.Name]
                if state ~= nil then
                    if not OriginalFavoriteFields[item] then
                        OriginalFavoriteFields[item] = {
                            Name_ = item.Name_,
                            LayoutOrder = item.LayoutOrder,
                            IsFavorited = item.IsFavorited,
                        }
                    end
                    if state then
                        item.IsFavorited = true
                        item.Name_ = "#\0|" .. (item.Name or "")
                        item.LayoutOrder = -1000000000
                    else
                        local orig = OriginalFavoriteFields[item]
                        item.IsFavorited = false
                        item.Name_ = (orig.Name_ or item.Name or ""):gsub("^#", "")
                        item.LayoutOrder = orig.LayoutOrder
                        if item.Type == "Ability" and orig.IsFavorited then
                            item.LayoutOrder = (item.OriginalLayoutOrder or 0)
                        end
                    end
                    changed = true
                end
            end
            return changed
        end

        local FavoritePages = {}
        local function WatchFavoritePage(itemType)
            local page = ShopController._inventoryPages[itemType]
            if not page or FavoritePages[page] then
                return
            end
            local original = page.MarkDirty
            local queued = false
            local wrapper
            wrapper = function(...)
                original(...)
                if not Env.Unlock_Enabled or queued then
                    return
                end
                queued = true
                task.defer(function()
                    queued = false
                    if not Env.Unlock_Enabled or page.MarkDirty ~= wrapper then
                        return
                    end
                    if ApplyFavoriteOverrides(itemType) then
                        original(nil, false, true)
                    end
                    RefreshFavoriteButton()
                end)
            end
            FavoritePages[page] = original
            page.MarkDirty = wrapper
            RegisterRestoreCallback(function()
                if page.MarkDirty == wrapper then
                    page.MarkDirty = original
                end
            end)
        end

        local function SortInventoryPage(itemType)
            WatchFavoritePage(itemType)
            RefreshInventoryPage(itemType)
        end

        local function SetFavoriteOverride(itemType, name, state, skipSave)
            FavoriteOverrides[itemType] = FavoriteOverrides[itemType] or {}
            FavoriteOverrides[itemType][name] = state == true
            ApplyFavoriteOverrides(itemType)
            SortInventoryPage(itemType)
            RefreshFavoriteButton()
            if not skipSave then
                SaveUnlockSettings()
            end
        end

        Env._Unlock_ReapplyFavorites = function()
            if not Env.Unlock_Enabled then
                return
            end
            for itemType in pairs(FavoriteItemTypes) do
                SortInventoryPage(itemType)
            end
            RefreshFavoriteButton()
        end

        RegisterSuspendCallback(function()
            for item, orig in pairs(OriginalFavoriteFields) do
                item.Name_ = orig.Name_
                item.LayoutOrder = orig.LayoutOrder
                item.IsFavorited = orig.IsFavorited
            end
            table.clear(OriginalFavoriteFields)
            for itemType in pairs(FavoriteItemTypes) do
                local page = ShopController._inventoryPages[itemType]
                local original = page and FavoritePages[page]
                if original then
                    original(nil, true, true)
                end
            end
        end)

        if Env.Unlock_Enabled then
            Env._Unlock_ReapplyFavorites()
        end

        local RefreshSelectedItemUI
        local IsSelectedItemRefreshPending = false
        local function QueueSelectedItemRefresh()
            if IsSelectedItemRefreshPending then
                return
            end
            IsSelectedItemRefreshPending = true
            task.defer(function()
                IsSelectedItemRefreshPending = false
                if Env.Unlock_Enabled and not IsUnlockDisposed and RefreshSelectedItemUI then
                    RefreshSelectedItemUI()
                end
            end)
        end
        ConnectUnlockSignal(ShopController.itemSelected, QueueSelectedItemRefresh)
        local OriginalFavoriteHandler = DisableSignalAndGetOriginalHandler(FavoriteButton.Activated)
        ConnectUnlockSignal(FavoriteButton.Activated, function(...)
            if not Env.Unlock_Enabled then
                if OriginalFavoriteHandler then
                    OriginalFavoriteHandler(...)
                end
                return
            end
            local SelectedItem = ShopController._selectedItem
            if not SelectedItem or not FavoriteItemTypes[SelectedItem.type] then
                if OriginalFavoriteHandler then
                    OriginalFavoriteHandler(...)
                end
                return
            end
            SetFavoriteOverride(
                SelectedItem.type,
                SelectedItem.name,
                not IsFavorite(SelectedItem.type, SelectedItem.name)
            )
            RefreshFavoriteButton()
        end)

        local DeleteItemPromptController = require(ReplicatedStorage.Controllers.DeleteItemPromptController)
        local ItemInfo = require(ReplicatedStorage.Shared.ItemInfo)
        do
            local VC = require(ReplicatedStorage.Common.Utils.Utilities.ValueConvertor)
            if VC and VC.ShrinkNumber then
                local realShrink = VC.ShrinkNumber
                local shrinkWrapper = function(self, n, ...)
                    if type(n) == "table" and type(n.Get) == "function" then
                        n = n:Get()
                    end
                    if type(n) == "number" then
                        return realShrink(self, n, ...)
                    end
                    return ""
                end
                VC.ShrinkNumber = shrinkWrapper
                RegisterRestoreCallback(function()
                    if VC.ShrinkNumber == shrinkWrapper then
                        VC.ShrinkNumber = realShrink
                    end
                end)
            end
        end
        local OriginalDeleteHandler = DisableSignalAndGetOriginalHandler(DeleteButton.Activated)

        local function RemoveVirtualItem(itemType, name)
            local list = ShopController._virtualItems[itemType]
            if not list then
                return
            end
            local removed = {}
            for key, item in pairs(list) do
                if item and (item.Name == name or key == name) then
                    removed[item] = true
                end
            end
            for key, item in pairs(list) do
                if removed[item] then
                    list[key] = nil
                end
            end
            for item in pairs(removed) do
                OriginalOwnershipByItem[item] = nil
                if item.Trove then
                    item.Trove:Destroy()
                end
            end
            RefreshInventoryPage(itemType)
        end

        local function DeleteLocalInventoryItem(itemType, name)
            if itemType == "Sword" and Env.Sword_Name == name then
                Env.Sword_Name = "Base Sword"
                LastFakeSwordName = "Base Sword"
                UnlockSettings.LastSword = LastFakeSwordName
                Env.FinisherEquipped[name] = nil
                Env.Selected_Finisher = Env.FinisherEquipped["Base Sword"] and "Base Sword" or false
                local Base = Swords:GetSword("Base Sword")
                if Base then
                    Swords:ForceEquipSwordTo(Player.Character, Base.Name)
                    if Env._Sword_Function then
                        Env._Sword_Function(Base.Name)
                    end
                end
            else
                Env.FinisherEquipped[name] = nil
            end
            UnlockSettings.FakeDeleted[itemType] = UnlockSettings.FakeDeleted[itemType] or {}
            UnlockSettings.FakeDeleted[itemType][name] = true
            SaveUnlockSettings()
            RemoveVirtualItem(itemType, name)
            ShopController._selectedItem = nil
        end

        ConnectUnlockSignal(DeleteButton.Activated, function(...)
            if not Env.Unlock_Enabled then
                if OriginalDeleteHandler then
                    return OriginalDeleteHandler(...)
                end
                return
            end
            local SelectedItem = ShopController._selectedItem
            if not SelectedItem or (SelectedItem.type ~= "Sword" and SelectedItem.type ~= "Explosion") then
                return
            end
            local SelectedItemType, SelectedItemName = SelectedItem.type, SelectedItem.name
            local info = ItemInfo[SelectedItemType] and ItemInfo[SelectedItemType][SelectedItemName]
            DeleteItemPromptController:PromptConfirmation({
                PromptType = "Single",
                Description = `Are you sure you want to delete x1 {(info and info.DisplayName) or SelectedItemName}? This cannot be undone.`,
            }, function(confirmed)
                if confirmed then
                    DeleteLocalInventoryItem(SelectedItemType, SelectedItemName)
                end
            end)
        end)

        local realCanDelete = ShopController._canDelete
        ShopController._canDelete = function(self, itemType, itemKey)
            if not Env.Unlock_Enabled then
                return realCanDelete(self, itemType, itemKey)
            end
            local hasReal = false
            do
                local DeleteInventoryClient = require(ReplicatedStorage.Shared.Inventory).Client
                local items = DeleteInventoryClient:FindItemsWithKey(itemType, itemKey)
                hasReal = items and #items > 0
            end
            if not hasReal then
                if itemKey == "Base Sword" or itemKey == "Explosion Normal" then
                    return false, "Cannot delete base items"
                end
                return true
            end
            return realCanDelete(self, itemType, itemKey)
        end

        local realAddToMultiDelete = ShopController._addToMultiDelete
        ShopController._addToMultiDelete = function(self, itemType, inventoryKey)
            if not Env.Unlock_Enabled then
                return realAddToMultiDelete(self, itemType, inventoryKey)
            end
            local hasReal = false
            do
                local DeleteInventoryClient = require(ReplicatedStorage.Shared.Inventory).Client
                local items = DeleteInventoryClient:FindItemsWithKey(itemType, inventoryKey)
                hasReal = items and #items > 0
            end
            if hasReal then
                return realAddToMultiDelete(self, itemType, inventoryKey)
            end
            if inventoryKey == "Base Sword" or inventoryKey == "Explosion Normal" then
                return
            end
            if not self._multiDelete or not self._multiDelete[itemType] then
                return
            end
            local bucket = self._multiDelete[itemType][inventoryKey]
            if bucket and #bucket >= 1 then
                return
            end
            if not bucket then
                self._multiDelete[itemType][inventoryKey] = {}
            end
            table.insert(self._multiDelete[itemType][inventoryKey], inventoryKey)
            local VirtualItem = self._virtualItems[itemType] and self._virtualItems[itemType][inventoryKey]
            if VirtualItem then
                if VirtualItem.InDeleteMulti then
                    VirtualItem.InDeleteMulti:Set(#self._multiDelete[itemType][inventoryKey])
                end
                VirtualItem.ForceHide:Set(true)
            end
            self:_updateMultiDelete()
        end

        local realUpdateMultiDelete = ShopController._updateMultiDelete
        ShopController._updateMultiDelete = function(self)
            if not Env.Unlock_Enabled or not self._multiDelete then
                realUpdateMultiDelete(self)
                return
            end
            local ScrollingFrame = Shop.Holder.DeleteItems.List.ContentsCanvas.ScrollingFrame
            for _, child in ipairs(ScrollingFrame:GetChildren()) do
                if child:IsA("GuiObject") and child:GetAttribute("_FakeEntry") then
                    local fType = child:GetAttribute("_FakeType")
                    local fKey = child.Name
                    if
                        not fType
                        or not self._multiDelete[fType]
                        or not self._multiDelete[fType][fKey]
                        or #self._multiDelete[fType][fKey] <= 0
                    then
                        child:Destroy()
                    end
                end
            end
            for iType, keys in pairs(self._multiDelete) do
                for key, ids in pairs(keys) do
                    if #ids <= 0 then
                        continue
                    end
                    local isFake = false
                    do
                        local DeleteInventoryClient = require(ReplicatedStorage.Shared.Inventory).Client
                        local items = DeleteInventoryClient:FindItemsWithKey(iType, key)
                        isFake = not items or #items <= 0
                    end
                    if not isFake then
                        continue
                    end
                    local existing = ScrollingFrame:FindFirstChild(key)
                    if existing and not existing:GetAttribute("_FakeEntry") then
                        existing = nil
                    end
                    if not existing then
                        local template = ScrollingFrame:FindFirstChild("UIListLayout")
                            and ScrollingFrame.UIListLayout:FindFirstChild("Template")
                        if template then
                            local entry = template:Clone()
                            entry.Name = key
                            entry.Visible = true
                            entry:SetAttribute("_FakeEntry", true)
                            entry:SetAttribute("_FakeType", iType)
                            entry:SetAttribute("InventoryType", iType)
                            local function removeOne()
                                if
                                    not self._multiDelete
                                    or not self._multiDelete[iType]
                                    or not self._multiDelete[iType][key]
                                then
                                    return
                                end
                                table.remove(self._multiDelete[iType][key], 1)
                                if #self._multiDelete[iType][key] <= 0 then
                                    self._multiDelete[iType][key] = nil
                                    entry:Destroy()
                                    local VirtualItem = self._virtualItems[iType]
                                        and self._virtualItems[iType][key]
                                    if VirtualItem then
                                        VirtualItem.ForceHide:Set(false)
                                        VirtualItem.Section:Set("Owned")
                                    end
                                end
                                local VirtualItem = self._virtualItems[iType]
                                    and self._virtualItems[iType][key]
                                if VirtualItem and VirtualItem.InDeleteMulti then
                                    local remaining = (
                                        self._multiDelete[iType] and self._multiDelete[iType][key]
                                    )
                                            and #self._multiDelete[iType][key]
                                        or 0
                                    VirtualItem.InDeleteMulti:Set(remaining)
                                end
                                self:_updateMultiDelete()
                            end
                            ConnectUnlockSignal(entry.Button.Activated, removeOne)
                            ConnectUnlockSignal(entry.Button.Item.Activated, removeOne)
                            entry.Parent = ScrollingFrame
                            existing = entry
                        end
                    end
                    if existing then
                        local info = ItemInfo[iType] and ItemInfo[iType][key]
                        local displayName = (info and info.DisplayName) or key
                        existing.Button.Label.Text = displayName
                        existing.Button.Item.Label.Text = "x" .. #ids
                        if info and info.Icon then
                            existing.Button.Item.Vector.Image = info.Icon
                        end
                    end
                end
            end
            realUpdateMultiDelete(self)
        end

        local realConfirmHandler = nil
        do
            local ConfirmDeleteButton = Shop.Holder.DeleteItems.List.Buttons.Delete
            local CancelDeleteButton = Shop.Holder.DeleteItems.List.Buttons.Cancel
            for _, c in getconnections(ConfirmDeleteButton.Activated) do
                if c and c.Function then
                    realConfirmHandler = c.Function
                    DisableGameConnection(c)
                    break
                end
            end
            ConnectUnlockSignal(ConfirmDeleteButton.Activated, function()
                if not Env.Unlock_Enabled or not ShopController._multiDelete then
                    if realConfirmHandler then
                        return realConfirmHandler()
                    end
                    return
                end
                local LocalItemsToDelete = {}
                local OwnedItemsToDelete = {}
                local LocalDeleteCount, OwnedDeleteCount = 0, 0
                for itemType, keys in pairs(ShopController._multiDelete) do
                    for key, ids in pairs(keys) do
                        if #ids <= 0 then
                            continue
                        end
                        local isFake = false
                        do
                            local DeleteInventoryClient = require(ReplicatedStorage.Shared.Inventory).Client
                            local items = DeleteInventoryClient:FindItemsWithKey(itemType, key)
                            isFake = not items or #items <= 0
                        end
                        if isFake then
                            table.insert(LocalItemsToDelete, { type = itemType, name = key })
                            LocalDeleteCount += 1
                        else
                            if not OwnedItemsToDelete[itemType] then
                                OwnedItemsToDelete[itemType] = {}
                            end
                            for _, id in ipairs(ids) do
                                table.insert(OwnedItemsToDelete[itemType], id)
                            end
                            OwnedDeleteCount += #ids
                        end
                    end
                end
                local DeleteCount = LocalDeleteCount + OwnedDeleteCount
                if DeleteCount == 0 then
                    ShopController._multiDelete = nil
                    ShopController:_updateMultiDeleteVisbility()
                    ShopController:_updateMultiDelete()
                    return
                end
                DeleteItemPromptController:PromptConfirmation({
                    PromptType = "Single",
                    Description = "Are you sure you want to delete x"
                        .. DeleteCount
                        .. " items? This cannot be undone.",
                }, function(confirmed)
                    if confirmed then
                        for _, item in ipairs(LocalItemsToDelete) do
                            DeleteLocalInventoryItem(item.type, item.name)
                        end
                        if OwnedDeleteCount > 0 then
                            do
                                local Net = require(ReplicatedStorage.Packages.Net)
                                Net:Invoke("RequestDelete", OwnedItemsToDelete)
                            end
                        end
                    else
                        for _, item in ipairs(LocalItemsToDelete) do
                            local VirtualItem = ShopController._virtualItems[item.type]
                                and ShopController._virtualItems[item.type][item.name]
                            if VirtualItem then
                                VirtualItem.ForceHide:Set(false)
                                VirtualItem.InDeleteMulti:Set(0)
                                VirtualItem.Section:Set("Owned")
                            end
                        end
                    end
                    ShopController._multiDelete = nil
                    ShopController:_updateMultiDeleteVisbility()
                    ShopController:_updateMultiDelete()
                end)
            end)
            local realCancelHandler = nil
            for _, c in getconnections(CancelDeleteButton.Activated) do
                if c and c.Function then
                    realCancelHandler = c.Function
                    DisableGameConnection(c)
                    break
                end
            end
            ConnectUnlockSignal(CancelDeleteButton.Activated, function()
                if not Env.Unlock_Enabled then
                    if realCancelHandler then
                        return realCancelHandler()
                    end
                    return
                end
                if ShopController._multiDelete then
                    for itemType, keys in pairs(ShopController._multiDelete) do
                        for key, ids in pairs(keys) do
                            if #ids <= 0 then
                                continue
                            end
                            local isFake = false
                            do
                                local DeleteInventoryClient =
                                    require(ReplicatedStorage.Shared.Inventory).Client
                                local items = DeleteInventoryClient:FindItemsWithKey(itemType, key)
                                isFake = not items or #items <= 0
                            end
                            if isFake then
                                local VirtualItem = ShopController._virtualItems[itemType]
                                    and ShopController._virtualItems[itemType][key]
                                if VirtualItem then
                                    VirtualItem.ForceHide:Set(false)
                                    VirtualItem.InDeleteMulti:Set(0)
                                    VirtualItem.Section:Set("Owned")
                                end
                            end
                        end
                    end
                end
                ShopController._multiDelete = nil
                ShopController:_updateMultiDeleteVisbility()
                ShopController:_updateMultiDelete()
            end)
        end

        local OriginalFinisherEquipHandler = DisableSignalAndGetOriginalHandler(EquipFinisherButton.Activated)
        ConnectUnlockSignal(EquipFinisherButton.Activated, function(...)
            if not Env.Unlock_Enabled then
                if OriginalFinisherEquipHandler then
                    return OriginalFinisherEquipHandler(...)
                end
                return
            end
            local SelectedItem = ShopController._selectedItem
            if
                not SelectedItem
                or SelectedItem.type ~= "Sword"
                or not SelectedItem.data
                or not SelectedItem.data.HasFinisher
            then
                return
            end
            local sn = SelectedItem.name
            if Env.FinisherEquipped[sn] then
                Env.FinisherEquipped[sn] = nil
                if Env.Sword_Name == sn then
                    Env.Selected_Finisher = false
                end
                EquipFinisherButton.Image = "rbxassetid://15452544682"
                EquipFinisherButton.Label.Text = "EQUIP"
            else
                Env.FinisherEquipped[sn] = true
                if Env.Sword_Name == sn then
                    Env.Selected_Finisher = sn
                end
                EquipFinisherButton.Image = "rbxassetid://15452502387"
                EquipFinisherButton.Label.Text = "UNEQUIP"
            end
            SaveUnlockSettings()
            QueueSelectedItemRefresh()
        end)

        local AccessoryVisibilityBySword = UnlockSettings.FakeShowAccessoryPerSword or {}
        local function GetSelectedSwordAccessoryVisibility()
            local sword = Env.Sword_Name
            if sword and AccessoryVisibilityBySword[sword] ~= nil then
                return AccessoryVisibilityBySword[sword]
            end
            return false
        end
        local OriginalAccessoryTransparency = {}

        local function SetAccessoryVisible(visible)
            local char = Player.Character
            if not char then
                return
            end
            local SwordAccessories = char:FindFirstChild("SwordAccessories")
            if not SwordAccessories then
                return
            end
            if visible then
                for desc, origT in pairs(OriginalAccessoryTransparency) do
                    if desc and desc.Parent then
                        if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
                            desc.Transparency = origT
                        elseif
                            desc:IsA("ParticleEmitter")
                            or desc:IsA("Trail")
                            or desc:IsA("Beam")
                            or desc:IsA("PointLight")
                            or desc:IsA("SpotLight")
                            or desc:IsA("SurfaceLight")
                        then
                            desc.Enabled = origT
                        end
                    end
                end
                OriginalAccessoryTransparency = {}
            else
                OriginalAccessoryTransparency = {}
                for _, desc in ipairs(SwordAccessories:GetDescendants()) do
                    if desc:IsA("BasePart") or desc:IsA("Decal") or desc:IsA("Texture") then
                        OriginalAccessoryTransparency[desc] = desc.Transparency
                        desc.Transparency = 1
                    elseif
                        desc:IsA("ParticleEmitter")
                        or desc:IsA("Trail")
                        or desc:IsA("Beam")
                        or desc:IsA("PointLight")
                        or desc:IsA("SpotLight")
                        or desc:IsA("SurfaceLight")
                    then
                        OriginalAccessoryTransparency[desc] = desc.Enabled
                        desc.Enabled = false
                    end
                end
            end
            char:SetAttribute("HasAccessoryEquipped", visible)
        end
        local function RefreshAccessoryButton()
            local SelectedItem = ShopController._selectedItem
            if not SelectedItem or SelectedItem.type ~= "Sword" then
                EquipAccessoryButton.Visible = false
                return
            end
            local data = SelectedItem.data
            if not data or not data.AccessoryToggleable then
                EquipAccessoryButton.Visible = false
                return
            end
            if data.AccessoryUnlockable and not Env.Unlock_Enabled then
                local item = FindVirtualItem("Sword", SelectedItem.name)
                local hasAcc = false
                if item then
                    hasAcc = item.HasAccessory and item.HasAccessory:Get()
                end
                if not hasAcc then
                    EquipAccessoryButton.Visible = false
                    return
                end
            end
            EquipAccessoryButton.Visible = true
            EquipAccessoryButton.HoverImage = "rbxassetid://14783051124"
            EquipAccessoryButton.ImageColor3 = Color3.new(1, 1, 1)
            local show = false
            show = UnlockSettings.FakeShowAccessoryPerSword
                and UnlockSettings.FakeShowAccessoryPerSword[SelectedItem.name] == true
            EquipAccessoryButton.Image = show and "rbxassetid://15452502387" or "rbxassetid://15452544682"
            EquipAccessoryButton.Label.Text = show and "UNEQUIP ACCESSORY" or "EQUIP ACCESSORY"
        end

        ConnectUnlockSignal(Player:GetAttributeChangedSignal("ShowSwordAccessory"), function()
            QueueSelectedItemRefresh()
        end)

        local OriginalAccessoryEquipHandler =
            DisableSignalAndGetOriginalHandler(EquipAccessoryButton.Activated)
        local IsAccessoryTogglePending = false
        ConnectUnlockSignal(EquipAccessoryButton.Activated, function(...)
            if IsAccessoryTogglePending then
                return
            end
            IsAccessoryTogglePending = true
            task.delay(0.2, function()
                IsAccessoryTogglePending = false
            end)
            local SelectedItem = ShopController._selectedItem
            if
                not SelectedItem
                or SelectedItem.type ~= "Sword"
                or not SelectedItem.data
                or not SelectedItem.data.AccessoryToggleable
            then
                if OriginalAccessoryEquipHandler then
                    return OriginalAccessoryEquipHandler(...)
                end
                return
            end
            local sword = SelectedItem.name
            local current = UnlockSettings.FakeShowAccessoryPerSword
                and UnlockSettings.FakeShowAccessoryPerSword[sword] == true
            local newState = not current
            if not UnlockSettings.FakeShowAccessoryPerSword then
                UnlockSettings.FakeShowAccessoryPerSword = {}
            end
            UnlockSettings.FakeShowAccessoryPerSword[sword] = newState
            IsAccessoryVisibilityLoopCancelled = true
            Player:SetAttribute("ShowSwordAccessory", newState)
            if newState then
                local char = Player.Character
                if char then
                    local SwordAccessories = char:FindFirstChild("SwordAccessories")
                    if SwordAccessories then
                        SwordAccessories:ClearAllChildren()
                    end
                    local targetSword = Env.Sword_Name
                    if char:GetAttribute("CurrentlyEquippedSword") == targetSword then
                        Swords:ForceEquipSwordTo(char, "Base Sword")
                    end
                    Swords:ForceEquipSwordTo(char, targetSword)
                    if Env._Sword_Function then
                        Env._Sword_Function(targetSword)
                    end
                end
                OriginalAccessoryTransparency = {}
            else
                SetAccessoryVisible(false)
            end
            EquipAccessoryButton.Image = newState and "rbxassetid://15452502387" or "rbxassetid://15452544682"
            EquipAccessoryButton.Label.Text = newState and "UNEQUIP ACCESSORY" or "EQUIP ACCESSORY"
            SaveUnlockSettings()
        end)

        local OriginalBuyHandlers = {}
        for _, c in getconnections(EquipItemButton.Activated) do
            if c and c.Function then
                table.insert(OriginalBuyHandlers, c.Function)
            end
        end
        DisableSignalAndGetOriginalHandler(EquipItemButton.Activated)

        local RefreshSwordUI = nil
        for _, Connection in getconnections(ReplicatedStorage.Remotes.FireSwordInfo.OnClientEvent) do
            if Connection and Connection.Function then
                RefreshSwordUI = Connection.Function
                DisableGameConnection(Connection)
            end
        end
        Env._Sword_Function = RefreshSwordUI

        local OriginalParryEffectHandler = nil
        for _, c in getconnections(ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent) do
            if c and c.Function then
                OriginalParryEffectHandler = c.Function
            end
        end
        if OriginalParryEffectHandler then
            for _, c in getconnections(ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent) do
                if c and c.Function then
                    DisableGameConnection(c)
                end
            end
        end

        local VFXController = require(ReplicatedStorage.Controllers.VFXController)
        local original = VFXController.PlayExplosion
        RegisterRestoreCallback(function()
            VFXController.PlayExplosion = original
        end)

        local SwordSelectionVersion = 0
        local RestoredSwordWatch
        local function WatchRestoredSword(char, restored)
            if RestoredSwordWatch then
                RestoredSwordWatch:Disconnect()
                RestoredSwordWatch = nil
            end
            if not restored or restored.Parent ~= char then
                return
            end
            local childConn, ancestryConn
            local watch = {}
            function watch:Disconnect()
                if childConn then
                    childConn:Disconnect()
                end
                if ancestryConn then
                    ancestryConn:Disconnect()
                end
                if RestoredSwordWatch == self then
                    RestoredSwordWatch = nil
                end
            end
            childConn = char.ChildAdded:Connect(function(child)
                if child == restored then
                    return
                end
                task.defer(function()
                    if
                        not Env.Unlock_Enabled
                        and child.Parent == char
                        and child:GetAttribute("_equippedSword")
                    then
                        if restored.Parent == char then
                            restored:Destroy()
                        end
                        watch:Disconnect()
                    end
                end)
            end)
            ancestryConn = restored.AncestryChanged:Connect(function()
                if restored.Parent ~= char then
                    watch:Disconnect()
                end
            end)
            RestoredSwordWatch = watch
        end

        RegisterSuspendCallback(function()
            SwordSelectionVersion += 1
            UnlockSettings.LastSword = LastFakeSwordName or UnlockSettings.LastSword
            UnlockSettings.LastExplosion = SelectedExplosionName or UnlockSettings.LastExplosion
            SaveUnlockSettings()
            local realSword = OriginalSwordName or "Base Sword"
            Env.Sword_Name, Env.Selected_Finisher = realSword, false
            local SwordData = Swords:GetSword(realSword)
            if SwordData and Player.Character then
                local char = Player.Character
                WatchRestoredSword(char, Swords:ForceEquipSwordTo(char, SwordData.Name))
                if RefreshSwordUI then
                    RefreshSwordUI(SwordData.Name)
                end
            end
            SelectedExplosionName = nil
        end)

        local function HookSelectedExplosionEffect()
            VFXController.PlayExplosion = function(
                self,
                name,
                position,
                ball,
                character,
                attributionCharacter,
                kill
            )
                if
                    Env.Unlock_Enabled
                    and SelectedExplosionName
                    and SelectedExplosionName ~= ""
                    and kill
                    and attributionCharacter == Player.Character
                then
                    name = SelectedExplosionName
                end
                return original(self, name, position, ball, character, attributionCharacter, kill)
            end
        end

        Env._Unlock_ReequipLast = function()
            if not Env.Unlock_Enabled or IsUnlockSuspended or IsUnlockDisposed then
                return
            end
            if RestoredSwordWatch then
                RestoredSwordWatch:Disconnect()
            end
            SelectedExplosionName = UnlockSettings.LastExplosion
            HookSelectedExplosionEffect()
            local swordName = LastFakeSwordName or UnlockSettings.LastSword
            local SwordData = swordName and Swords:GetSword(swordName)
            if SwordData then
                LastFakeSwordName = SwordData.Name
                SwordSelectionVersion += 1
                local selectionVersion = SwordSelectionVersion
                Env.Sword_Name = SwordData.Name
                Env.Selected_Finisher = Env.FinisherEquipped[SwordData.Name] and SwordData.Name or false
                local char = Player.Character
                if char then
                    local restoredModel = Swords:ForceEquipSwordTo(char, SwordData.Name)
                    task.spawn(function()
                        local equippedModel = restoredModel
                        for _ = 1, 30 do
                            task.wait(0.1)
                            if selectionVersion ~= SwordSelectionVersion or not Env.Unlock_Enabled
                                or IsUnlockSuspended or IsUnlockDisposed or Player.Character ~= char then
                                return
                            end
                            local correctModel = equippedModel and equippedModel.Parent == char
                            for _, child in ipairs(char:GetChildren()) do
                                if child ~= equippedModel and child:GetAttribute("_equippedSword") then
                                    correctModel = false
                                    break
                                end
                            end
                            if not correctModel then
                                equippedModel = Swords:ForceEquipSwordTo(char, SwordData.Name)
                            end
                        end
                    end)
                    if selectionVersion ~= SwordSelectionVersion or not Env.Unlock_Enabled then
                        return
                    end
                    if RefreshSwordUI then
                        RefreshSwordUI(SwordData.Name)
                    end
                    local show = GetSelectedSwordAccessoryVisibility()
                    Player:SetAttribute("ShowSwordAccessory", show)
                    SetAccessoryVisible(show)
                end
            end
            if RefreshSelectedItemUI then
                RefreshSelectedItemUI()
            end
        end

        local FakeSwordCharacterConnections = {}
        local IsFakeSwordCheckQueued = false
        local LastFakeSwordEquipTime, FakeSwordEquipBurst = 0, 0
        local function NeedsFakeSwordEquip(char, fakeSwordName)
            local hasFakeModel = false
            for _, child in ipairs(char:GetChildren()) do
                if child:GetAttribute("_equippedSword") then
                    if child.Name ~= fakeSwordName then
                        return true
                    end
                    hasFakeModel = true
                elseif child.Name == fakeSwordName and child:IsA("Model") then
                    hasFakeModel = true
                end
            end
            return not hasFakeModel
        end
        local function QueueFakeSwordCheck(char)
            if IsFakeSwordCheckQueued then
                return
            end
            IsFakeSwordCheckQueued = true
            task.defer(function()
                IsFakeSwordCheckQueued = false
                if
                    not Env.Unlock_Enabled
                    or IsUnlockSuspended
                    or IsUnlockDisposed
                    or Player.Character ~= char
                then
                    return
                end
                local fakeSwordName = LastFakeSwordName or UnlockSettings.LastSword
                local SwordData = fakeSwordName and Swords:GetSword(fakeSwordName)
                if not SwordData or not NeedsFakeSwordEquip(char, SwordData.Name) then
                    return
                end
                local cooldown = 0.3 - (os.clock() - LastFakeSwordEquipTime)
                if cooldown > 0 then
                    task.delay(cooldown, QueueFakeSwordCheck, char)
                    return
                end
                FakeSwordEquipBurst = (os.clock() - LastFakeSwordEquipTime < 3) and FakeSwordEquipBurst + 1 or 1
                LastFakeSwordEquipTime = os.clock()
                if FakeSwordEquipBurst > 6 then
                    if FakeSwordEquipBurst == 7 then
                        warn("[Unlocker] Fake sword keeps getting replaced: " .. SwordData.Name)
                    end
                    return
                end
                Env.Sword_Name = SwordData.Name
                Env.Selected_Finisher = Env.FinisherEquipped[SwordData.Name] and SwordData.Name or false
                Swords:ForceEquipSwordTo(char, SwordData.Name)
                if RefreshSwordUI then
                    RefreshSwordUI(SwordData.Name)
                end
            end)
        end
        local function WatchFakeSwordCharacter(char)
            DisconnectSignals(FakeSwordCharacterConnections)
            if not char then
                return
            end
            local function onChange()
                QueueFakeSwordCheck(char)
            end
            FakeSwordCharacterConnections[1] =
                char:GetAttributeChangedSignal("CurrentlyEquippedSword"):Connect(onChange)
            FakeSwordCharacterConnections[2] = char.ChildAdded:Connect(onChange)
        end
        WatchFakeSwordCharacter(Player.Character)
        local FakeSwordRespawnConnection = Player.CharacterAdded:Connect(WatchFakeSwordCharacter)
        RegisterRestoreCallback(function()
            FakeSwordRespawnConnection:Disconnect()
            DisconnectSignals(FakeSwordCharacterConnections)
        end)

        ConnectUnlockSignal(EquipItemButton.Activated, function(...)
            local SelectedCatalogItem = ShopController._selectedItem
            if not SelectedCatalogItem then
                return
            end
            local SelectedItemType, SelectedItemName = SelectedCatalogItem.type, SelectedCatalogItem.name
            if
                not Env.Unlock_Enabled or (SelectedItemType ~= "Sword" and SelectedItemType ~= "Explosion")
            then
                for _, handler in ipairs(OriginalBuyHandlers) do
                    handler(...)
                end
                return
            end
            if SelectedItemType == "Explosion" and SelectedExplosionName == SelectedItemName then
                EquipItemButton.PriceTag.TextLabel.Text = "Equipped"
                return
            end
            if SelectedItemType == "Sword" then
                SwordSelectionVersion += 1
                local selectionVersion = SwordSelectionVersion
                RememberOriginalSword()
                local oldSword = Env.Sword_Name
                if oldSword and oldSword ~= SelectedItemName then
                    Env.FinisherEquipped[oldSword] = nil
                end

                local Sword_Model = Swords:GetSword(SelectedItemName)
                local char = Player.Character
                if not Sword_Model or not char then
                    return
                end
                local ok, model = pcall(Swords.ForceEquipSwordTo, Swords, char, Sword_Model.Name)
                if selectionVersion ~= SwordSelectionVersion or not Env.Unlock_Enabled then
                    return
                end
                if
                    not ok
                    or not model
                    or model.Parent ~= char
                    or char ~= Player.Character
                then
                    EquipItemButton.PriceTag.TextLabel.Text = "Equip"
                    warn("[Unlocker] Sword model did not finish equipping: " .. tostring(SelectedItemName))
                    return
                end
                Env.Sword_Name = Sword_Model.Name
                Env.Selected_Finisher = Env.FinisherEquipped[Sword_Model.Name] and Sword_Model.Name or false
                EquipItemButton.PriceTag.TextLabel.Text = "Equipped"
                if RefreshSwordUI then
                    RefreshSwordUI(Sword_Model.Name)
                end
                LastFakeSwordName = Sword_Model.Name
                UnlockSettings.LastSword = LastFakeSwordName
                SaveUnlockSettings()
                IsAccessoryVisibilityLoopCancelled = false
                AccessoryVisibilityGeneration += 1
                local accessoryGeneration = AccessoryVisibilityGeneration
                local SavedAccessoryVisibility = AccessoryVisibilityBySword[Sword_Model.Name]
                if SavedAccessoryVisibility == nil then
                    AccessoryVisibilityBySword[Sword_Model.Name] = false
                end
                UnlockSettings.FakeShowAccessoryPerSword = AccessoryVisibilityBySword
                task.spawn(function()
                    local char = Player.Character
                    if not char then
                        return
                    end
                    local show = AccessoryVisibilityBySword[Sword_Model.Name] or false
                    for _ = 1, 20 do
                        task.wait(0.1)
                        if
                            IsAccessoryVisibilityLoopCancelled
                            or accessoryGeneration ~= AccessoryVisibilityGeneration
                            or selectionVersion ~= SwordSelectionVersion
                            or not Env.Unlock_Enabled
                        then
                            return
                        end
                        if not char or char ~= Player.Character then
                            return
                        end
                        Player:SetAttribute("ShowSwordAccessory", show)
                        SetAccessoryVisible(show)
                    end
                end)
                QueueSelectedItemRefresh()
            elseif SelectedItemType == "Explosion" then
                EquipItemButton.PriceTag.TextLabel.Text = "Equipped"
                SelectedExplosionName = SelectedItemName
                UnlockSettings.LastExplosion = SelectedItemName
                HookSelectedExplosionEffect()
                SaveUnlockSettings()
                QueueSelectedItemRefresh()
            end
        end)

        if OriginalParryEffectHandler then
            ConnectUnlockSignal(ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent, function(...)
                local Args = { ... }
                if Env.Unlock_Enabled and Env.Sword_Name then
                    local Sword = Swords:GetSword(Env.Sword_Name)
                    local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                    if Sword and (Args[4] == hrp or tostring(Args[4]) == Player.Name) then
                        Args[1], Args[3] = Sword.SlashName, Sword.Name
                    end
                end
                return OriginalParryEffectHandler(unpack(Args))
            end)
        end

        ConnectUnlockSignal(Player.CharacterAppearanceLoaded, function()
            if not Env.Unlock_Enabled then
                return
            end
            local char = Player.Character
            if not char then
                return
            end
            for _ = 1, 80 do
                task.wait(0.05)
                if not Env.Unlock_Enabled then
                    return
                end
                local c = Player.Character
                if not c or c ~= char then
                    return
                end
                if c:GetAttribute("CurrentlyEquippedSword") then
                    break
                end
            end
            if not Env.Unlock_Enabled then
                return
            end
            local c = Player.Character
            if not c or c ~= char then
                return
            end
            local fakeSwordName = LastFakeSwordName or UnlockSettings.LastSword or Env.Sword_Name
            local fakeSwordData = fakeSwordName and Swords:GetSword(fakeSwordName)
            if not fakeSwordData then
                return
            end
            fakeSwordName = fakeSwordData.Name
            Env.Sword_Name = fakeSwordName
            local selectionVersion = SwordSelectionVersion
            for i = 1, 5 do
                task.delay(i * 1, function()
                    if Player.Character ~= c or selectionVersion ~= SwordSelectionVersion then
                        return
                    end
                    if not Env.Unlock_Enabled or IsUnlockSuspended or IsUnlockDisposed then
                        return
                    end
                    if c:GetAttribute("CurrentlyEquippedSword") ~= fakeSwordName then
                        Swords:ForceEquipSwordTo(c, fakeSwordName)
                        if RefreshSwordUI then
                            RefreshSwordUI(fakeSwordName)
                        end
                    end
                end)
            end

            Swords:ForceEquipSwordTo(c, fakeSwordName)
            if RefreshSwordUI then
                RefreshSwordUI(fakeSwordName)
            end
            Env.Selected_Finisher = (Env.Sword_Name and Env.FinisherEquipped[Env.Sword_Name])
                    and Env.Sword_Name
                or false
            local show = GetSelectedSwordAccessoryVisibility()
            Player:SetAttribute("ShowSwordAccessory", show)
            SetAccessoryVisible(show)
        end)

        RefreshSelectedItemUI = function()
            RefreshAccessoryButton()
            local SelectedItem = ShopController._selectedItem
            if not SelectedItem then
                return
            end
            if ShopController._multiDelete then
                return
            end
            do
                local isUnlockType = Env.Unlock_Enabled
                    and (SelectedItem.type == "Sword" or SelectedItem.type == "Explosion")
                DeleteButton.Visible = isUnlockType
                if
                    Env.Unlock_Enabled
                    and SelectedItem.type == "Sword"
                    and SelectedItem.data
                    and SelectedItem.data.HasFinisher
                then
                    EquipFinisherButton.Visible = true
                    EquipFinisherButton.HoverImage = "rbxassetid://14783051124"
                    EquipFinisherButton.ImageColor3 = Color3.new(1, 1, 1)
                    local equipped = Env.FinisherEquipped[SelectedItem.name]
                    EquipFinisherButton.Image = equipped and "rbxassetid://15452502387"
                        or "rbxassetid://15452544682"
                    EquipFinisherButton.Label.Text = equipped and "UNEQUIP" or "EQUIP"
                else
                    EquipFinisherButton.Visible = false
                end
                if isUnlockType then
                    EquipItemButton.Visible = true
                    local isEquipped = (SelectedItem.type == "Sword" and Env.Sword_Name == SelectedItem.name)
                        or (SelectedItem.type == "Explosion" and SelectedExplosionName == SelectedItem.name)
                    EquipItemButton.PriceTag.TextLabel.Text = isEquipped and "Equipped" or "Equip"
                end
                if FavoriteItemTypes[SelectedItem.type] then
                    FavoriteButton.Visible = true
                    FavoriteButton:SetAttribute("Visible", true)
                    RefreshFavoriteButton()
                end
            end
        end

        Env._Unlock_RefreshSelected = RefreshSelectedItemUI
    end

    if Env.Unlock_Enabled then
        RunUnlockStep("Inventory", InitializeInventoryUnlocks)
        RunUnlockStep("Re-equip sword", Env._Unlock_ReequipLast)
        task.spawn(RunUnlockStep, "Emotes", Env._Unlock_InitializeEmotes)
    end
    Env._Unlock_Initialize = InitializeInventoryUnlocks

    local function ColorToHex(c)
        return string.format(
            "#%02X%02X%02X",
            math.floor(c.R * 255 + 0.5),
            math.floor(c.G * 255 + 0.5),
            math.floor(c.B * 255 + 0.5)
        )
    end
    local function BuildSelectedTitleMarkup()
        local SelectedTitle = _G.__TitleState.Selected
        return SelectedTitle
                and string.format(
                    '<font color="%s">%s</font>',
                    ColorToHex(SelectedTitle.Color),
                    SelectedTitle.Text
                )
            or ""
    end

    local AreTitlesInitialized = false
    local function InitializeTitles()
        if AreTitlesInitialized then
            return
        end
        AreTitlesInitialized = true
        if not Env.Unlock_Enabled then
            return
        end

        local ProfileTitlePaths = {
            { "Customize", "Profile", "Playerprofile", "Details", "Title" },
            { "Customize", "PlayerCard", "Title" },
        }

        local function IsLocalProfileCard(ProfileCard)
            if not ProfileCard then
                return false
            end
            for _, desc in ipairs(ProfileCard:GetDescendants()) do
                if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
                    local LabelText = desc.Text
                    if
                        LabelText
                        and (
                            LabelText == Player.Name
                            or LabelText == Player.DisplayName
                            or string.find(LabelText, Player.DisplayName, 1, true)
                        )
                    then
                        return true
                    end
                end
            end
            return false
        end

        local function FindProfileTitleLabels()
            local TitleLabels = {}
            local ProfileCard = PlayerGui:FindFirstChild("ProfileCard")
            if not ProfileCard or not IsLocalProfileCard(ProfileCard) then
                return TitleLabels
            end
            for _, path in ipairs(ProfileTitlePaths) do
                local node = ProfileCard
                for _, n in ipairs(path) do
                    if node then
                        node = node:FindFirstChild(n)
                    end
                end
                if node and (node:IsA("TextLabel") or node:IsA("TextButton") or node:IsA("TextBox")) then
                    table.insert(TitleLabels, node)
                end
            end
            return TitleLabels
        end

        local function RefreshProfileTitle()
            if not Env.Unlock_Enabled then
                return
            end
            local SelectedTitleMarkup = BuildSelectedTitleMarkup()
            for _, lbl in ipairs(FindProfileTitleLabels()) do
                do
                    lbl.RichText, lbl.Visible, lbl.TextTransparency = true, true, 0
                    if lbl.TextSize == 0 then
                        lbl.TextSize = 18
                    end
                    if lbl.TextColor3 == Color3.new(0, 0, 0) then
                        lbl.TextColor3 = Color3.new(1, 1, 1)
                    end
                    if lbl.Text ~= SelectedTitleMarkup then
                        lbl.Text = SelectedTitleMarkup
                    end
                end
            end
        end

        local ProfileTitleConnections = {}
        local WatchedProfileLabels = setmetatable({}, { __mode = "k" })
        local IsProfileTitleRefreshPending = false
        local function QueueProfileTitleRefresh()
            if IsProfileTitleRefreshPending or _ScriptUnloaded or IsUnlockDisposed then
                return
            end
            IsProfileTitleRefreshPending = true
            task.defer(function()
                IsProfileTitleRefreshPending = false
                if not _ScriptUnloaded and not IsUnlockDisposed then
                    RefreshProfileTitle()
                end
            end)
        end
        local function WatchProfileLabel(label)
            if
                WatchedProfileLabels[label]
                or not (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox"))
            then
                return
            end
            WatchedProfileLabels[label] = true
            ProfileTitleConnections[#ProfileTitleConnections + 1] =
                label:GetPropertyChangedSignal("Text"):Connect(QueueProfileTitleRefresh)
            ProfileTitleConnections[#ProfileTitleConnections + 1] = label.AncestryChanged:Connect(function()
                QueueProfileTitleRefresh()
            end)
        end
        local function WatchProfileCard(card)
            for _, descendant in ipairs(card:GetDescendants()) do
                WatchProfileLabel(descendant)
            end
            QueueProfileTitleRefresh()
        end
        Connections_Manager["ProfileCard_Descendant"] = PlayerGui.DescendantAdded:Connect(function(descendant)
            if descendant:FindFirstAncestor("ProfileCard") then
                WatchProfileLabel(descendant)
                QueueProfileTitleRefresh()
            end
        end)
        Connections_Manager["ProfileCard_Title"] = PlayerGui.ChildAdded:Connect(function(child)
            if child.Name == "ProfileCard" then
                WatchProfileCard(child)
            end
        end)
        RegisterRestoreCallback(function()
            DisconnectSignals(ProfileTitleConnections)
            table.clear(WatchedProfileLabels)
            Env._Unlock_RefreshTitle = nil
        end)
        Env._Unlock_RefreshTitle = QueueProfileTitleRefresh
        local existingCard = PlayerGui:FindFirstChild("ProfileCard")
        if existingCard then
            WatchProfileCard(existingCard)
        end

        task.spawn(function()
            local TitleCatalog = require(ReplicatedStorage.Shared:WaitForChild("TitleData"))
            if not TitleCatalog then
                return
            end
            local TitleList = PlayerGui:WaitForChild("Settings")
                :WaitForChild("Frame")
                :WaitForChild("Frame")
                :WaitForChild("SettingTitles")
                :WaitForChild("TitleList")
            local needed = #TitleCatalog + 1
            for _ = 1, 60 do
                local count = 0
                for _, c in ipairs(TitleList:GetChildren()) do
                    if c:IsA("ImageButton") then
                        count += 1
                    end
                end
                if count >= needed then
                    break
                end
                task.wait(0.25)
            end
            local TitleRows = {}
            for _, TitleRow in ipairs(TitleList:GetChildren()) do
                if TitleRow:IsA("ImageButton") then
                    table.insert(TitleRows, TitleRow)
                end
            end
            table.sort(TitleRows, function(a, b)
                return a.LayoutOrder < b.LayoutOrder
            end)
            for Index, TitleEntry in ipairs(TitleCatalog) do
                local TitleRow = TitleRows[Index + 1]
                if not TitleRow then
                    break
                end
                local TitleLabel = TitleRow:FindFirstChild("TextLabel")
                if TitleLabel and TitleEntry.Tag then
                    TitleLabel.Text = TitleEntry.Tag.Text
                    TitleLabel.TextColor3 = TitleEntry.Tag.Color
                end
                TitleRow.Name = TitleEntry.Name or TitleRow.Name
                TitleRow.Visible = true
            end
            local SelectedTitleRow = nil
            for i, TitleRow in ipairs(TitleRows) do
                local rowIndex = i
                ConnectUnlockSignal(TitleRow.Activated, function()
                    SelectedTitleRow = TitleRow
                    local TitleEntry = TitleCatalog[rowIndex - 1]
                    _G.__TitleState.Selected = (rowIndex > 1 and TitleEntry)
                            and { Text = TitleEntry.Tag.Text, Color = TitleEntry.Tag.Color }
                        or nil
                    for _, Other in ipairs(TitleRows) do
                        local SelectionHighlight = Other:FindFirstChild("Selected")
                        if SelectionHighlight then
                            SelectionHighlight.Visible = (Other == SelectedTitleRow)
                        end
                    end
                    QueueProfileTitleRefresh()
                end)
            end
        end)

        QueueProfileTitleRefresh()
        do
            if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                local OriginalChatMessageHandler = TextChatService.OnIncomingMessage
                TextChatService.OnIncomingMessage = function(message)
                    local props = Instance.new("TextChatMessageProperties")
                    if
                        Env.Unlock_Enabled
                        and message.TextSource
                        and message.TextSource.UserId == Player.UserId
                    then
                        local SelectedTitle = _G.__TitleState.Selected
                        if SelectedTitle then
                            props.PrefixText = string.format(
                                '<font color="%s">[%s]</font> <font color="%s">%s</font>',
                                ColorToHex(SelectedTitle.Color),
                                SelectedTitle.Text,
                                ColorToHex(SelectedTitle.Color),
                                Player.DisplayName
                            )
                        end
                    end
                    return props
                end
                Env._Unlock_RestoreTextChatHook = function()
                    TextChatService.OnIncomingMessage = OriginalChatMessageHandler
                end
            end
        end
    end

    if Env.Unlock_Enabled then
        InitializeTitles()
    end
    Env._Unlock_InitializeTitles = InitializeTitles

    local UnlockControlsGroup = Tabs.Sword:AddLeftGroupbox("Swords Changer", "swords")
    UnlockControlsGroup:AddToggle("Unlock_Enabled_Toggle", {
        Text = "Enable Unlocker",
        Default = Env.Unlock_Enabled and true or false,
        Tooltip = "Unlock swords, explosions, finishers and emotes.",
        Callback = function(state)
            if _ScriptUnloaded or IsUnlockDisposed then
                return
            end
            local wasEnabled = Env.Unlock_Enabled
            Env.Unlock_Enabled = state
            if state then
                ResumeUnlockAll()
                RunUnlockStep("Inventory", Env._Unlock_Initialize)
                if not wasEnabled then
                    RunUnlockStep("Capture sword", Env._Unlock_CaptureOriginalSword)
                end
                RunUnlockStep("Titles", Env._Unlock_InitializeTitles)
                RunUnlockStep("Refresh title", Env._Unlock_RefreshTitle)
                RunUnlockStep("Unlock all", Env._Unlock_DoUnlockAll)
                RunUnlockStep("Favorites", Env._Unlock_ReapplyFavorites)
                RunUnlockStep("Selected item", Env._Unlock_RefreshSelected)
                RunUnlockStep("Re-equip sword", Env._Unlock_ReequipLast)
                task.spawn(RunUnlockStep, "Emotes", Env._Unlock_InitializeEmotes)
                SaveUnlockSettings()
            else
                if not _ScriptUnloaded then
                    SuspendUnlockAll()
                end
            end
        end,
    })
end)

do
    local DEFAULT_COLOR = Color3.fromRGB(255, 0, 0)
    local FOLDER_KIND = { ParticleShine = "shield", ParryFX = "slash" }
    local TINT = {
        ParticleEmitter = { "Color", true },
        Beam = { "Color", true },
        Trail = { "Color", true },
        Decal = { "Color", false },
        Texture = { "Color", false },
        PointLight = { "Color", false },
        SpotLight = { "Color", false },
        SurfaceLight = { "Color", false },
        ImageLabel = { "ImageColor3", false },
        ImageButton = { "ImageColor3", false },
        Highlight = { "FillColor", false },
    }

    local function NewCfg(kind)
        return {
            Kind = kind,
            Enabled = false,
            Color = DEFAULT_COLOR,
            Seq = ColorSequence.new(DEFAULT_COLOR),
            Rainbow = false,
            PickerColor = DEFAULT_COLOR,
            Thread = nil,
        }
    end
    local Shield, Slash = NewCfg("shield"), NewCfg("slash")
    local Cfgs = { shield = Shield, slash = Slash }

    local Original = setmetatable({}, { __mode = "k" })
    local RuntimeConn, CharDescConn, RespawnConn
    local BoundChar, Monitoring

    local function GetFXKind(i)
        local k = FOLDER_KIND[i.Name]
        if k then return k end
        local p = i.Parent
        for _ = 1, 8 do
            if not p or p == workspace then return nil end
            k = FOLDER_KIND[p.Name]
            if k then return k end
            p = p.Parent
        end
        return nil
    end

    local function Untrack(i, restore)
        local rec = Original[i]
        if not rec then return end
        if rec.PropConn then rec.PropConn:Disconnect() end
        if rec.DestroyConn then rec.DestroyConn:Disconnect() end
        if restore and i.Parent then
            i[rec.Prop] = rec.Value
        end
        Original[i] = nil
    end

    local function UntrackKind(kind)
        local list = {}
        for i, rec in pairs(Original) do
            if rec.Kind == kind then
                list[#list + 1] = i
            end
        end
        for n = 1, #list do Untrack(list[n], true) end
    end

    local function ApplyTint(i, rec)
        local cfg = Cfgs[rec.Kind]
        if not (cfg and cfg.Enabled) then return end
        rec.Applying = true
        i[rec.Prop] = rec.IsSeq and cfg.Seq or cfg.Color
        rec.Applying = false
    end

    local function Track(i, kind)
        if Original[i] then return end
        local tint = TINT[i.ClassName]
        if not tint then return end
        kind = kind or GetFXKind(i)
        local cfg = kind and Cfgs[kind]
        if not (cfg and cfg.Enabled) then return end
        local prop, isSeq = tint[1], tint[2]
        local ok, orig = true, i[prop]
        if not ok then return end
        local rec = { Prop = prop, Value = orig, Kind = kind, IsSeq = isSeq, Applying = false }
        Original[i] = rec
        rec.PropConn = i:GetPropertyChangedSignal(prop):Connect(function()
            if rec.Applying then return end
            if i.Parent then ApplyTint(i, rec) end
        end)
        rec.DestroyConn = i.Destroying:Connect(function()
            Untrack(i, false)
        end)
        ApplyTint(i, rec)
    end

    local function TrackFolder(folder, kind)
        if not (folder and kind and Cfgs[kind].Enabled) then return end
        Track(folder, kind)
        local desc = folder:GetDescendants()
        for n = 1, #desc do Track(desc[n], kind) end
    end

    local function RetintKind(kind)
        for i, rec in pairs(Original) do
            if rec.Kind == kind and i.Parent then ApplyTint(i, rec) end
        end
    end

    local function CommitColor(cfg, color)
        cfg.Color = color
        cfg.Seq = ColorSequence.new(color)
        if cfg.Enabled then RetintKind(cfg.Kind) end
    end

    local function ScanNamed(root)
        if not root then return end
        local k = FOLDER_KIND[root.Name]
        if k then TrackFolder(root, k) end
        local desc = root:GetDescendants()
        for n = 1, #desc do
            local d = desc[n]
            k = FOLDER_KIND[d.Name]
            if k then TrackFolder(d, k) end
        end
    end

    local function OnDescendant(d)
        local k = FOLDER_KIND[d.Name]
        if k then
            TrackFolder(d, k)
            return
        end
        if TINT[d.ClassName] then Track(d) end
    end

    local function BindChar(char)
        if BoundChar ~= char then
            if CharDescConn then CharDescConn:Disconnect() end
            BoundChar = char
            CharDescConn = char and char.DescendantAdded:Connect(OnDescendant) or nil
            Connections_Manager['FX_CharDesc'] = CharDescConn
        end
        ScanNamed(char)
    end

    local function BindRuntime()
        if RuntimeConn then return end
        local runtime = workspace:FindFirstChild("Runtime")
        if not runtime then return end
        RuntimeConn = runtime.ChildAdded:Connect(function(c)
            local k = FOLDER_KIND[c.Name]
            if k then TrackFolder(c, k) end
        end)
        Connections_Manager['FX_Runtime'] = RuntimeConn
        local children = runtime:GetChildren()
        for n = 1, #children do
            local c = children[n]
            local k = FOLDER_KIND[c.Name]
            if k then TrackFolder(c, k) end
        end
    end

    local function StartMonitor()
        if not Monitoring then
            Monitoring = true
            if not RespawnConn then
                RespawnConn = Player.CharacterAdded:Connect(BindChar)
                Connections_Manager['FX_Respawn'] = RespawnConn
            end
            BindRuntime()
        end
        BindChar(Player.Character)
    end

    local function StopMonitorIfIdle()
        if Shield.Enabled or Slash.Enabled then return end
        Monitoring = false
        BoundChar = nil
        if CharDescConn then CharDescConn:Disconnect(); CharDescConn = nil; Connections_Manager['FX_CharDesc'] = nil end
        if RuntimeConn then RuntimeConn:Disconnect(); RuntimeConn = nil; Connections_Manager['FX_Runtime'] = nil end
        if RespawnConn then RespawnConn:Disconnect(); RespawnConn = nil; Connections_Manager['FX_Respawn'] = nil end
    end

    local function StartRainbow(cfg)
        if cfg.Thread or not cfg.Enabled then return end
        cfg.Thread = task.spawn(function()
            local hue = 0
            while cfg.Rainbow and cfg.Enabled do
                hue = (hue + 0.01) % 1
                cfg.Color = Color3.fromHSV(hue, 1, 1)
                cfg.Seq = ColorSequence.new(cfg.Color)
                RetintKind(cfg.Kind)
                task.wait(0.05)
            end
            cfg.Thread = nil
        end)
    end

    local function SetEnabled(cfg, state)
        cfg.Enabled = state
        if state then
            StartMonitor()
            if cfg.Rainbow then StartRainbow(cfg) end
        else
            UntrackKind(cfg.Kind)
            StopMonitorIfIdle()
        end
    end

    local BS_Group = Tabs.Sword:AddRightGroupbox("Shield & Slash FX", "sparkle")

    local function AddFX(cfg, id, label)
        local tog = BS_Group:AddToggle(id .. "_Toggle", {
            Text = label,
            Default = false,
            Callback = function(state)
                SetEnabled(cfg, state)
            end,
        })
        tog:AddColorPicker({
            SaveId  = id .. "_Color",
            Name    = label .. " Color",
            Default = DEFAULT_COLOR,
            Callback = function(color)
                cfg.PickerColor = color
                if not cfg.Rainbow then CommitColor(cfg, color) end
            end,
        })
        BS_Group:AddToggle(id .. "_Rainbow", {
            Text     = "Rainbow",
            Default  = false,
            Callback = function(state)
                cfg.Rainbow = state
                if state then StartRainbow(cfg)
                else CommitColor(cfg, cfg.PickerColor) end
            end,
        })
    end

    AddFX(Shield, "ShieldFX", "Shield FX")
    AddFX(Slash, "SlashFX", "Slash FX")

    local Rewards_Group = Tabs.Sword:AddRightGroupbox("Rewards", "gift")
    local _RW = { Items = {}, Running = false }

    _RW.Items[1] = { ID = "Claim_Daily_Rewards", Name = "Auto Claim Daily", Interval = 5, Next = 0, Enabled = false }
    _RW.Items[2] = { ID = "Claim_Playtime_Rewards", Name = "Auto Claim Playtime", Interval = 5, Next = 0, Enabled = false }
    _RW.Items[3] = { ID = "Claim_Battlepass_Rewards", Name = "Auto Claim BP Rewards", Interval = 5, Next = 0, Enabled = false }
    _RW.Items[4] = { ID = "Auto_Wheel_Spins", Name = "Auto Spin Wheel", Interval = 12, Next = 0, Enabled = false }

    for _, item in ipairs(_RW.Items) do
        item.Locked = (item.ID == "Claim_Battlepass_Rewards")
        Rewards_Group:AddToggle(item.ID .. '_Toggle', {
            Text = item.Name, Default = false,
            Status = item.Locked and "Locked" or nil,
            StatusSubtitle = "BAC Detected",
            Callback = function(state)
                if item.Locked then
                    item.Enabled = false
                    return
                end
                item.Enabled = state
            end
        })
    end

    task.spawn(function()
        local PG = Player:WaitForChild('PlayerGui', 10)
        local Data = require(ReplicatedStorage.Packages.Replion).Client:WaitReplion("Data")
        local Ctrl = ReplicatedStorage.Controllers
        local BPD = nil
        pcall(function() BPD = require(ReplicatedStorage.Shared.InfiniteBattlepass.InfiniteBattlepassData) end)

        local function FG(...)
            local c = PG
            for _, n in ipairs({...}) do c = c and c:FindFirstChild(n); if not c then return nil end end
            return c
        end

        local function FB(btn, cs)
            if not btn or not btn.Visible then return false end
            for _, cn in getconnections(btn.Activated) do
                if cn.Enabled and cn.Function and getfenv(cn.Function).script == cs then cn:Fire(); return true end
            end
            return false
        end

        local RF = {}

        RF["Claim_Daily_Rewards"] = function()
            local lt = Data:Get("CurrentDailyLoginType")
            local ld = Data:Get({"DailyLoginData", lt})
            if not ld or not ld.NextClaim then return end
            if (lt ~= "D30" and lt ~= "Longterm") then return end
            if workspace:GetServerTimeNow() < ld.NextClaim then return end
            local gui = FG("DailyLogin_" .. lt .. "_Rewards")
            if gui then
                local btn = lt == "D30" and gui.Page.Rewards:FindFirstChild("Day" .. ld.DaysClaimedStreak + 1, true) or (gui.Frame and gui.Frame.Claim)
                pcall(function() FB(btn, Ctrl.UI.DailyLoginController) end)
            end
            if BPD and BPD.isEnabled() then
                local bg = FG("BattlepassDailyLogin", "Background", "Frame", "ScrollingFrame")
                if bg then
                    for _, ch in bg:GetChildren() do
                        if ch:GetAttribute("State") == "Claimable" then
                            pcall(function() FB(ch:FindFirstChild("Claim"), Player:WaitForChild("PlayerScripts").Client.UIBinders.BattlepassDailyLogin) end)
                            break
                        end
                    end
                end
            end
            local wb = Data:Get("WelcomeBackEvent")
            if wb and workspace:GetServerTimeNow() < (wb.EventEndTime or 0) then
                local days = FG("NewWelcomeBack", "Frame", "Views", "Login", "Days")
                if days then
                    for _, ch in days:GetChildren() do
                        local cb = ch:FindFirstChild("Claim")
                        local ix = ch.LayoutOrder
                        if cb and cb.Visible and ix <= wb.DailyLoginStreak and not wb.ClaimedDailyRewards[ix] then
                            pcall(function() for _, cn in getconnections(cb.MouseButton1Click) do if cn.Enabled and cn.Function and getfenv(cn.Function).script == Ctrl.WelcomeBackController.EventControllers.Login then cn:Fire(); break end end end)
                            break
                        end
                    end
                end
            end
        end

        RF["Claim_Playtime_Rewards"] = function()
            local ptI = require(ReplicatedStorage.Common.PlaytimeRewardsInfo).Rewards
            local ptD = Data:Get("PlaytimeRewardsData")
            if ptD then
                for ix, rw in pairs(ptI) do
                    if not ptD.ClaimedRewards[tostring(ix)] and workspace:GetServerTimeNow() >= ptD.TimerStart + rw.Duration then
                        pcall(function() FB(FG("PlaytimeRewards","PlaytimeRewards","Page","List","RewardsList",tostring(ix),"ClaimButton"), Ctrl.UI.PlaytimeRewardsController) end)
                        break
                    end
                end
            end
            if BPD and BPD.isEnabled() then
                local bpPT = require(ReplicatedStorage.Shared.Battlepass.BattlepassPlaytimeRewardsData)
                local cl = Data:Get("ClaimedPlaytimeRewards") or {}
                for ix, rw in pairs(bpPT) do
                    if rw.Seconds <= (Data:Get("SecondsPlayedToday") or 0) and not table.find(cl, ix) then
                        local g = FG("BattlepassPlaytimeRewards","PlaytimeRewards","MainFrame","Grid",tostring(ix))
                        if g then pcall(function() FB(g.Claim.Claim, Ctrl.Battlepass.BattlepassPlaytimeRewardsController) end) end
                        break
                    end
                end
            end
            local qs = Data:Get("CurrentQuests") or {}
            local qd = require(ReplicatedStorage.Shared.Quests)
            for _, qi in pairs(qs) do
                local df = qd[qi]
                if df and (Data:Get({"QuestStats", df.stat}) or 0) >= df.goal and not table.find(Data:Get("QuestsAwarded") or {}, qi) then
                    pcall(function() FB(FG("NewDailyQuests","Holder","Quests",qi,"Intermediate"), Ctrl.UI.QuestsController) end)
                end
            end
        end

        RF["Claim_Battlepass_Rewards"] = function()
            if not BPD or not BPD.isEnabled() then return end
            local ca = FG("Battlepass","Main","Background","Left","ClaimAll")
            if ca and ca.Visible then pcall(function() FB(ca, Ctrl.Battlepass.BattlepassTierController) end) end
        end

        RF["Auto_Wheel_Spins"] = function()
            if (Data:Get("rolls") or 0) <= 0 then return end

            local wheelGui = FG("Wheel", "Default")
            if wheelGui and wheelGui:GetAttribute("Spinning") then
                wheelGui:SetAttribute("Spinning", false)
            end

            local Utils = require(ReplicatedStorage.Common.Utils)
            pcall(function()
                Utils.Network:Invoke("SpinWheel")
            end)
        end

        _RW.Running = true
        while not _ScriptUnloaded and _RW.Running do
            for _, r in ipairs(_RW.Items) do
                if r.Enabled and os.clock() >= r.Next and RF[r.ID] then
                    r.Next = os.clock() + r.Interval
                    pcall(RF[r.ID])
                end
            end
            task.wait(1)
        end
    end)
end

do
    local HttpService = game:GetService("HttpService")
    local TeleportService = game:GetService("TeleportService")
    local GENV = getgenv()

    GENV.txtDeviceSpoofType = GENV.txtDeviceSpoofType or "PC"

    local Group = Tabs.Sword:AddLeftGroupbox("Device Spoofer", "monitor")

    Group:AddDropdown("DeviceSpoof_Type", {
        Text = "Device",
        Values = { "PC", "Mobile", "Console" },
        Multi = false,
        Default = "PC",
        Callback = function(Value)
            GENV.txtDeviceSpoofType = Value
        end,
    })

    local function Notify(title, content, duration)
        if Window and Window.Notify then
            pcall(function()
                Window:Notify({ Title = title, Content = content, Duration = duration or 3 })
            end)
        end
    end

    do
        local applied = GENV.txtDeviceSpoofApplied
        if type(applied) == "table" and applied.JobId == game.JobId and applied.Device then
            local label = (applied.Device == "Phone" or applied.Device == "Tablet") and "Mobile" or applied.Device
            task.defer(function()
                Notify("Device Spoofer", "Active: " .. tostring(label), 3)
            end)
        end
    end

    Group:AddButton({
        Text = "Apply & Rejoin",
        Callback = function()
            local deviceType = GENV.txtDeviceSpoofType
            local opt = Library and Library.Options and Library.Options.DeviceSpoof_Type
            if opt then
                local ok, val = pcall(function() return opt.Value end)
                if ok and type(val) == "string" and (val == "PC" or val == "Mobile" or val == "Console") then
                    deviceType = val
                end
            end
            deviceType = deviceType or "PC"
            GENV.txtDeviceSpoofType = deviceType

            local spoofDevice = (deviceType == "Mobile") and "Phone" or deviceType
            local displayName = (spoofDevice == "Phone" or spoofDevice == "Tablet") and "Mobile" or spoofDevice

            local query = [[local Source = %q
            if not game:IsLoaded() then game.Loaded:Wait() end
            local Queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
            local Players = game:GetService('Players')
            local Player = Players.LocalPlayer or Players.PlayerAdded:Wait()
            local Environment = getgenv()
            if Environment.txtDeviceSpoofQueue then
                Environment.txtDeviceSpoofQueue:Disconnect()
            end
            local Queued = false
            Environment.txtDeviceSpoofQueue = Player.OnTeleport:Connect(function()
                if not Queued then
                    Queue(Source:format(Source))
                    Queued = true
                end
            end)
            local Device = ]] .. HttpService:JSONEncode(spoofDevice) .. [[
            if game.GameId ~= ]] .. tostring(game.GameId) .. [[ then return end
            local Previous = Environment.txtDeviceSpoofRun
            if Previous and Previous.JobId == game.JobId and Previous.Device == Device then return end
            if Previous and Previous.Restore then Previous.Restore() end
            local Run = { Device = Device, JobId = game.JobId }
            Environment.txtDeviceSpoofRun = Run
            while not workspace:GetAttribute('ClientModulesLoaded') do
                workspace:GetAttributeChangedSignal('ClientModulesLoaded'):Wait()
            end
            if Environment.txtDeviceSpoofRun ~= Run then return end
            local ReplicatedStorage = game:GetService('ReplicatedStorage')
            local Listener = require(ReplicatedStorage:WaitForChild('ClientGameModules'):WaitForChild('DeviceListener'))
            local Observe = Listener.Observe

            local function Apply(Callback)
                if Run.Restore then Run.Restore() end
                task.spawn(function()
                    local Success, Result = pcall(function()
                        Callback(Device)
                        Callback(Listener.Device)
                    end)
                    if not Success then
                        Environment.txtDeviceSpoofRun = nil
                        error(Result, 0)
                    end
                    Environment.txtDeviceSpoofApplied = { Device = Device, JobId = game.JobId }
                    pcall(function()
                        workspace:SetAttribute("txtDeviceSpoof_" .. Player.UserId, Device)
                    end)
                end)
            end

            for _, Connection in Listener.OnChange:GetConnections() do
                if debug.info(Connection._fn, 's') == 'ReplicatedStorage.Controllers.PlayerProfileController' then
                    Apply(Connection._fn)
                    return
                end
            end

            local function ObserveDevice(Self, Callback)
                if debug.info(Callback, 's') == 'ReplicatedStorage.Controllers.PlayerProfileController' then
                    Apply(Callback)
                    return Self.OnChange:Connect(Callback)
                end
                return Observe(Self, Callback)
            end

            Run.Restore = function()
                if Listener.Observe == ObserveDevice then Listener.Observe = Observe end
                Run.Restore = nil
            end
            Listener.Observe = ObserveDevice
            ]]

            local concatenated = query:format(query)

            if GENV.txtDeviceSpoofQueue then
                GENV.txtDeviceSpoofQueue:Disconnect()
                GENV.txtDeviceSpoofQueue = nil
            end

            local queue = queue_on_teleport or queueonteleport
                or (syn and syn.queue_on_teleport)
                or (fluxus and fluxus.queue_on_teleport)

            if not queue then
                Notify("Device Spoofer", "Executor does not support queue_on_teleport.", 4)
                return
            end

            queue(concatenated)

            Notify("Device Spoofer", "Spoofing as " .. tostring(displayName) .. ", rejoining...", 3)
            task.wait(0.2)

            if not pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, game.JobId, Player) then
                pcall(function()
                    game:GetService("ExperienceService"):LaunchExperience({ placeId = game.PlaceId, gameInstanceId = game.JobId })
                end)
            end
        end,
    })

    Env._DeviceSpoofUnload = function()
        if GENV.txtDeviceSpoofQueue then
            pcall(function() GENV.txtDeviceSpoofQueue:Disconnect() end)
            GENV.txtDeviceSpoofQueue = nil
        end
        Notify("Device Spoofer", "Restored", 2)
        Env._DeviceSpoofUnload = nil
    end
end

do
    local Q = {
        Enabled_Blind = false,
        Enabled_Disorient = false,
        Active_Until = 0,
        Saved_Atmosphere = nil,
        Saved_Camera = nil,
        Conns = {},
    }

    local function Track(key, c)
        if c then
            Q.Conns[#Q.Conns + 1] = c
            Connections_Manager[key] = c
        end
    end

    local function Untrack(key, c)
        if c then pcall(function() c:Disconnect() end) end
        if Connections_Manager[key] == c then Connections_Manager[key] = nil end
    end

    local function ClearBlindness(atmosphere)
        local Light = workspace:FindFirstChildOfClass("Lighting") or Lighting
        if atmosphere then
            local s = Q.Saved_Atmosphere
            atmosphere.Density = s and s.Density or 0
            atmosphere.Offset = s and s.Offset or 0
            atmosphere.Haze = s and s.Haze or 0
            atmosphere.Glare = s and s.Glare or 0
            if s then
                atmosphere.Color = s.Color
                atmosphere.Decay = s.Decay
            end
            return
        end
        local blind = Light:FindFirstChild("Blindness")
        if blind and blind:IsA("Atmosphere") then
            ClearBlindness(blind)
        end
        for _, v in ipairs(workspace:GetChildren()) do
            if v:IsA("Atmosphere") and v.Name == "Blindness" then
                ClearBlindness(v)
            end
        end
    end

    local function KillBlindGui()
        local pg = Player:FindFirstChild("PlayerGui")
        if not pg then return end
        for _, v in ipairs(pg:GetDescendants()) do
            if v:IsA("ImageLabel") or v:IsA("Frame") then
                if v.Name == "Blindness" or v.Name == "Blind" or v.Name == "QuasarBlind" then
                    v.Visible = false
                end
            end
        end
    end

    local function OnQuasar(plr, char)
        if char ~= Player.Character then return end
        local upg = plr and plr:FindFirstChild("Upgrades")
        upg = upg and upg:FindFirstChild("Quasar")
        Q.Active_Until = os.clock() + 5 + (upg and upg.Value or 0)
        if Q.Enabled_Blind then
            ClearBlindness()
            KillBlindGui()
        end
        if Q.Enabled_Disorient and Q.Saved_Camera then
            local cam = workspace.CurrentCamera
            if cam then
                local rot = Q.Saved_Camera.Rotation
                cam.CFrame = CFrame.new(cam.CFrame.Position) * rot
            end
        end
    end

    local function OnBlindnessChanged()
        if not Q.Enabled_Blind then return end
        if os.clock() >= Q.Active_Until then return end
        local blind = Lighting:FindFirstChild("Blindness")
        if blind and blind.Enabled then blind.Enabled = false end
        KillBlindGui()
    end

    local function OnAtmosphereAdded(inst)
        if not Q.Enabled_Blind then return end
        if not inst:IsA("Atmosphere") then return end
        if os.clock() < Q.Active_Until and inst.Name == "Blindness" then
            ClearBlindness(inst)
        elseif inst.Name ~= "Blindness" then
            Q.Saved_Atmosphere = {
                Density = inst.Density, Offset = inst.Offset,
                Haze = inst.Haze, Glare = inst.Glare,
                Color = inst.Color, Decay = inst.Decay,
            }
        end
    end

    local function Start()
        local remote = ReplicatedStorage:FindFirstChild("Remotes")
        if remote then
            local ev = remote:FindFirstChild("PlrQuasared")
            if ev then
                Track("Quasar_Event", ev.OnClientEvent:Connect(function(plr, char)
                    OnQuasar(plr, char)
                end))
            end
        end
        Track("Quasar_BlindProp", Lighting:GetPropertyChangedSignal("Enabled"):Connect(OnBlindnessChanged))
        local blind = Lighting:FindFirstChild("Blindness")
        if blind then
            Track("Quasar_BlindProp2", blind:GetPropertyChangedSignal("Enabled"):Connect(OnBlindnessChanged))
        end
        Track("Quasar_Atmo", workspace.ChildAdded:Connect(OnAtmosphereAdded))
        Track("Quasar_Cam", RunService.PreRender:Connect(function()
            local cam = workspace.CurrentCamera
            if cam then Q.Saved_Camera = cam.CFrame end
        end))
        for _, v in ipairs(Lighting:GetChildren()) do
            if v:IsA("Atmosphere") and v.Name ~= "Blindness" and not Q.Saved_Atmosphere then
                Q.Saved_Atmosphere = {
                    Density = v.Density, Offset = v.Offset,
                    Haze = v.Haze, Glare = v.Glare,
                    Color = v.Color, Decay = v.Decay,
                }
            end
        end
    end

    local function Stop()
        for k, c in pairs(Q.Conns) do
            pcall(function() c:Disconnect() end)
            Q.Conns[k] = nil
        end
        for key, c in pairs(Connections_Manager) do
            if type(key) == "string" and key:sub(1, 6) == "Quasar" then
                pcall(function() c:Disconnect() end)
                Connections_Manager[key] = nil
            end
        end
        Q.Active_Until = 0
        Q.Saved_Camera = nil
    end

    Env._Quasar_State = Q

    local G = Tabs.Sword:AddLeftGroupbox("Anti-Quasar", "eye-off")
    G:AddToggle('Quasar_Blind_Toggle', {
        Text = 'Anti Blind',
        Default = false,
        Callback = function(s)
            Q.Enabled_Blind = s
            if s then
                Start()
                ClearBlindness()
                KillBlindGui()
            else
                Stop()
            end
        end,
    })
    G:AddToggle('Quasar_Disorient_Toggle', {
        Text = 'Anti Disorient',
        Default = false,
        Callback = function(s)
            Q.Enabled_Disorient = s
            if s and not Q.Saved_Camera then
                Start()
            elseif not s and not Q.Enabled_Blind then
                Stop()
            end
        end,
    })
end

local ESP_Group = Tabs.Client:AddLeftGroupbox("ESP", "palette")

local FuryStartCount = {}
local FuryResult = {}
local FURY_RESULT_HOLD = 5

local function GetServerParryCount(plr)
    return plr:GetAttribute('ServerParryCount')
        or (plr.Character and plr.Character:GetAttribute('ServerParryCount'))
        or 0
end

local function GetFuryCount(plr)
    return math.max(GetServerParryCount(plr) - (FuryStartCount[plr] or 0), 0)
end

local SOF_Connections = {}

local function SetupSOF_Tracker(plr)
    if plr == Player or not plr.Character then return end
    if SOF_Connections[plr] then return end

    local char = plr.Character
    local conn = char:GetAttributeChangedSignal("AbilityActive"):Connect(function()
        if _ScriptUnloaded then return end
        local active = char:GetAttribute("AbilityActive")
        local ability = plr:GetAttribute('EquippedAbility') or plr:GetAttribute('CurrentlyEquippedAbility')

        if active and ability == "Slashes of Fury" then
            FuryStartCount[plr] = GetServerParryCount(plr)
            FuryResult[plr] = nil
        elseif not active and FuryStartCount[plr] then
            FuryResult[plr] = { GetFuryCount(plr), workspace:GetServerTimeNow() + FURY_RESULT_HOLD }
            FuryStartCount[plr] = nil
        end
    end)
    SOF_Connections[plr] = conn
end

for _, plr in ipairs(Players:GetPlayers()) do
    task.spawn(SetupSOF_Tracker, plr)
    Connections_Manager['SOF_Char_' .. plr.UserId] = plr.CharacterAdded:Connect(function()
        task.wait(1); SetupSOF_Tracker(plr)
    end)
end
Connections_Manager['SOF_PlayerAdded'] = Players.PlayerAdded:Connect(function(plr)
    task.wait(1); SetupSOF_Tracker(plr)
    Connections_Manager['SOF_Char_' .. plr.UserId] = plr.CharacterAdded:Connect(function()
        task.wait(1); SetupSOF_Tracker(plr)
    end)
end)
Connections_Manager['SOF_PlayerRemoving'] = Players.PlayerRemoving:Connect(function(plr)
    if SOF_Connections[plr] then SOF_Connections[plr]:Disconnect(); SOF_Connections[plr] = nil end
    local key = 'SOF_Char_' .. plr.UserId
    if Connections_Manager[key] then Connections_Manager[key]:Disconnect(); Connections_Manager[key] = nil end
    FuryStartCount[plr] = nil
    FuryResult[plr] = nil
end)
Env._SOF_Cleanup = function()
    for plr, c in pairs(SOF_Connections) do
        pcall(function() c:Disconnect() end)
        SOF_Connections[plr] = nil
    end
end

local Ability_Module
task.spawn(function()
    Ability_Module = require(ReplicatedStorage.Shared.Abilities)
end)

local function GetAbilityCooldownSafe(subject, abilityName)
    if Ability_Module and Ability_Module.getAbilityCooldown then
        local ok, cd = true, Ability_Module.getAbilityCooldown(subject, abilityName)
        if ok then return cd end
    end
    return nil
end

local function GetEquippedAbility(plr)
    return plr:GetAttribute('EquippedAbility') or plr:GetAttribute('CurrentlyEquippedAbility')
end

local function GetUpgradeLevel(plr, char, abilityName)
    local level = nil

    if Ability_Module and Ability_Module.getUpgradeLevel and abilityName and (plr or char) then
        local ok, result = true, Ability_Module.getUpgradeLevel(plr or char, abilityName)
        if ok and type(result) == 'number' then
            level = result
        end
    end

    if level == nil and plr and abilityName then
        local upgrades = plr:FindFirstChild('Upgrades')
        if upgrades then
            local compact = abilityName:gsub(' ', '')
            local val = upgrades:FindFirstChild(abilityName) or upgrades:FindFirstChild(compact)
            if val and (val:IsA('IntValue') or val:IsA('NumberValue')) then
                level = val.Value
            end
        end
    end
    if level == nil and char then
        level = char:GetAttribute('AbilityUpgrade')
    end
    if type(level) ~= 'number' then return 0 end
    return math.max(0, math.floor(level))
end

local function ReadChargeAttr(char, player, attr)
    local value = char:GetAttribute(attr)
    if value == nil and player then
        value = player:GetAttribute(attr)
    end
    if value == nil then
        local abilityFolder = char:FindFirstChild("Abilities")
        value = abilityFolder and abilityFolder:GetAttribute(attr)
    end
    return value
end

local function GetChargeInfo(char, abilityName)
    local chargeData = Charge_Abilities[abilityName]
    if not chargeData then return nil end

    local player = Players:GetPlayerFromCharacter(char)

    local maxCharges = chargeData.MaxCharges or 2
    local byLevel = chargeData.MaxChargesByLevel
    if byLevel then
        local level = GetUpgradeLevel(player, char, abilityName)
        while level > 0 and byLevel[level] == nil do level -= 1 end
        maxCharges = byLevel[level] or maxCharges
    end
    if chargeData.MaxChargesAttr then
        maxCharges = ReadChargeAttr(char, player, chargeData.MaxChargesAttr) or maxCharges
    end

    local charges = math.min(ReadChargeAttr(char, player, chargeData.ChargeAttr) or maxCharges, maxCharges)

    local nextUseCD = nil
    if chargeData.NextUseAttr then
        local nextUse = ReadChargeAttr(char, player, chargeData.NextUseAttr)
        if nextUse then
            local remaining = nextUse - workspace:GetServerTimeNow()
            if remaining > 0 then
                nextUseCD = tick() + remaining
            end
        end
    end

    return {
        Charges = charges,
        MaxCharges = maxCharges,
        CDEnd = nextUseCD
    }
end

local COLOR_READY  = Color3.fromRGB(100, 220, 120)
local COLOR_CD = Color3.fromRGB(225, 95, 85)
local COLOR_ACTIVE = Color3.fromRGB(90, 190, 255)
local COLOR_CHARGE = Color3.fromRGB(255, 200, 70)

local BADGE_TIERS = {
    { Color3.fromRGB(95, 185, 255),  Color3.fromRGB(35, 105, 215), Color3.fromRGB(15, 45, 95) },
    { Color3.fromRGB(200, 130, 255), Color3.fromRGB(120, 55, 210), Color3.fromRGB(55, 20, 95) },
    { Color3.fromRGB(255, 225, 110), Color3.fromRGB(235, 145, 25), Color3.fromRGB(110, 60, 5) },
}

local function ChargeDisplay(charges, max, remaining, timerFormat)
    local fraction = (max > 0) and (charges / max) or 0
    local color = (charges >= max) and COLOR_READY or COLOR_CHARGE
    local text = string.format("%d/%d", charges, max)
    if remaining and remaining > 0 then
        text = text .. "  " .. string.format(timerFormat or "%.0f", remaining)
    end
    return fraction, color, text
end

local function UpdateVersionBadge(badge, level)
    local tier = math.clamp(level, 1, #BADGE_TIERS)
    local label = badge:FindFirstChild('Label')
    if label then
        local text = 'V' .. tostring(level)
        if label.Text ~= text then label.Text = text end
    end
    if badge:GetAttribute('Tier') == tier then return end
    badge:SetAttribute('Tier', tier)
    local colors = BADGE_TIERS[tier]
    local gradient = badge:FindFirstChildOfClass('UIGradient')
    if gradient then gradient.Color = ColorSequence.new(colors[1], colors[2]) end
    local stroke = badge:FindFirstChildOfClass('UIStroke')
    if stroke then stroke.Color = colors[3] end
end

local AbilityActiveStart = {}
local CooldownExpiration = {}
local CooldownTotal = {}
local AbilityActiveDuration = {}
local LastAbilityActiveState = {}
local AbilityTrackingContext = {}

local function UpdateActiveTimer(plr, now, active, previouslyActive)
    local duration = tonumber(plr:GetAttribute("AbilityDuration"))
    if not active or not duration or duration <= 0 then
        AbilityActiveStart[plr] = nil
        AbilityActiveDuration[plr] = nil
        return
    end
    if not previouslyActive or not AbilityActiveStart[plr] or AbilityActiveDuration[plr] ~= duration then
        AbilityActiveStart[plr] = now
        AbilityActiveDuration[plr] = duration
    end
end

local function ActiveTimerDisplay(startTime, duration, now)
    if startTime and duration and duration > 0 then
        local remaining = math.max(0, duration - (now - startTime))
        if remaining > 0 then
            return math.clamp(remaining / duration, 0, 1), string.format("%.1f", remaining)
        end
    end
    return nil, ""
end

local FURY_REQUIRED_PARRIES = 35
local FURY_RESULT_HOLD = 5

local function GetUpgradedMaxCharges(plr, abilityName)
    return GetUpgradeLevel(plr, plr.Character, abilityName) > 0 and 3 or 2
end

local DribbleCharges = {}
local DribbleRefillTimes = {}

local function OnDribbleImmunity(Instance)
    if Instance.Name ~= "DRIBBLE_IMMUNITY" then
        return
    end

    local Character = Instance:FindFirstAncestorOfClass("Model")
    local Enemy = Character and Players:GetPlayerFromCharacter(Character)

    if not Enemy then
        return
    end

    local MaxCharges = GetUpgradedMaxCharges(Enemy, "Dribble")
    DribbleCharges[Enemy] = math.min(DribbleCharges[Enemy] or MaxCharges, MaxCharges)

    DribbleCharges[Enemy] = math.max(DribbleCharges[Enemy] - 1, 0)

    local Cooldown = GetAbilityCooldownSafe(Enemy, "Dribble")

    if Cooldown and Cooldown > 0 then
        DribbleRefillTimes[Enemy] = DribbleRefillTimes[Enemy] or {}
        table.insert(DribbleRefillTimes[Enemy], workspace:GetServerTimeNow() + Cooldown)
    end
end

local DragonSpiritCharges = {}
local DragonSpiritRefillTimes = {}

local function OnGuardianDragon(instance)
    if instance.Name ~= "GUARDIAN_DRAGON" then
        return
    end

    for _, player in Players:GetPlayers() do
        if GetEquippedAbility(player) == "Dragon Spirit" then
            local MaxCharges = GetUpgradedMaxCharges(player, "Dragon Spirit")
            DragonSpiritCharges[player] = math.min(DragonSpiritCharges[player] or MaxCharges, MaxCharges)

            DragonSpiritCharges[player] = math.max(DragonSpiritCharges[player] - 1, 0)

            local cd = GetAbilityCooldownSafe(player, "Dragon Spirit")

            if cd and cd > 0 then
                local now = workspace:GetServerTimeNow()
                if not DragonSpiritRefillTimes[player] or DragonSpiritRefillTimes[player] <= now then
                    DragonSpiritRefillTimes[player] = now + cd - 1
                end
            end
        end
    end
end

local function StartAbilityChargeMonitors()
    if not Connections_Manager['Dribble Event Monitor'] then
        Connections_Manager['Dribble Event Monitor'] = AliveFolder.DescendantAdded:Connect(OnDribbleImmunity)
    end
    if not Connections_Manager['Dragon Spirit Event Monitor'] then
        Connections_Manager['Dragon Spirit Event Monitor'] = RuntimeFolder.ChildAdded:Connect(OnGuardianDragon)
    end
end

local function StopAbilityChargeMonitors()
    for _, key in ipairs({ 'Dribble Event Monitor', 'Dragon Spirit Event Monitor' }) do
        local conn = Connections_Manager[key]
        if conn then
            conn:Disconnect()
            Connections_Manager[key] = nil
        end
    end
end

local function ClearAbilityESPPlayer(plr)
    DribbleCharges[plr] = nil
    DribbleRefillTimes[plr] = nil
    DragonSpiritCharges[plr] = nil
    DragonSpiritRefillTimes[plr] = nil
    AbilityActiveStart[plr] = nil
    CooldownExpiration[plr] = nil
    CooldownTotal[plr] = nil
    AbilityActiveDuration[plr] = nil
    LastAbilityActiveState[plr] = nil
    AbilityTrackingContext[plr] = nil
    FuryStartCount[plr] = nil
    FuryResult[plr] = nil
    FuryUI.Clear(plr)
end

local Billboard_Pending = {}
local function EnsureBillboard(plr)
    if plr == Player then return end

    local char = plr.Character
    if not char then return end

    local label = Billboard_Banner[plr]
    local gui = label and label.Parent

    if gui and gui.Adornee and gui.Adornee:IsDescendantOf(char) then
        gui.Enabled = true 
        return
    end

    if Billboard_Pending[plr] then return end

    Billboard_Pending[plr] = true
    task.spawn(function()
        SkinChanger.CreateBillboard(plr, plr.Character)
        Billboard_Pending[plr] = nil
    end)
end

local Ability_ESP_Toggle = ESP_Group:AddToggle('Ability_ESP_Toggle', {
    Text = 'Ability ESP',
    Default = false,
    Callback = function(state)
        if state then
            StartAbilityChargeMonitors()

            if not Connections_Manager['Billboard_PlayerRemoving'] then
                Connections_Manager['Billboard_PlayerRemoving'] = Players.PlayerRemoving:Connect(function(Instance)
                    local banner = Billboard_Banner[Instance]
                    if banner and banner.Parent then
                        banner.Parent:Destroy()
                    end
                    Billboard_Banner[Instance] = nil
                    Billboard_Pending[Instance] = nil
                    ClearAbilityESPPlayer(Instance)
                end)
            end

            if Connections_Manager['Ability ESP'] then
                Connections_Manager['Ability ESP']:Disconnect()
                Connections_Manager['Ability ESP'] = nil
            end

            Connections_Manager['Ability ESP'] = RunService.Heartbeat:Connect(function()
                local Data_Abilities = ReplicatedStorage.Misc.DataAbilities
                local Now = workspace:GetServerTimeNow()


                for Enemy, RefillTimes in DribbleRefillTimes do
                    local Dribble_Max = GetUpgradedMaxCharges(Enemy, "Dribble")
                    while RefillTimes[1] and Now >= RefillTimes[1] do
                        table.remove(RefillTimes, 1)
                        DribbleCharges[Enemy] = math.min((DribbleCharges[Enemy] or 0) + 1, Dribble_Max)
                    end
                    if not RefillTimes[1] then DribbleRefillTimes[Enemy] = nil end
                end

                for player, nextRefill in DragonSpiritRefillTimes do
                    if Now >= nextRefill then
                        local Dragon_Max = GetUpgradedMaxCharges(player, "Dragon Spirit")
                        DragonSpiritCharges[player] = math.min((DragonSpiritCharges[player] or 0) + 1, Dragon_Max)

                        if DragonSpiritCharges[player] < Dragon_Max then
                            DragonSpiritRefillTimes[player] = Now + (GetAbilityCooldownSafe(player, "Dragon Spirit") or 0)
                        else
                            DragonSpiritRefillTimes[player] = nil
                        end
                    end
                end

                for _, Value in Players:GetPlayers() do
                    if Value ~= Player and not Value.Character and AbilityTrackingContext[Value] then
                        ClearAbilityESPPlayer(Value)
                    end
                    if Value and Value ~= Player and Value.Character then
                        local EquippedAbility = GetEquippedAbility(Value)
                        local SampleKey = tostring(EquippedAbility) .. ":" .. tostring(GetUpgradeLevel(Value, Value.Character, EquippedAbility))
                        local Context = AbilityTrackingContext[Value]
                        if not Context or Context.Character ~= Value.Character or Context.Key ~= SampleKey or Context.Parent ~= Value.Character.Parent then
                            ClearAbilityESPPlayer(Value)
                            AbilityTrackingContext[Value] = { Character = Value.Character, Key = SampleKey, Parent = Value.Character.Parent }
                        end
                        local Current_Active_State = Value.Character:GetAttribute("AbilityActive") == true
                        local Previous_Active_State = LastAbilityActiveState[Value]

                        if Previous_Active_State == nil then
                            Previous_Active_State = false
                        end

                        UpdateActiveTimer(Value, Now, Current_Active_State, Previous_Active_State)

                        if Current_Active_State ~= Previous_Active_State then
                            if Current_Active_State then
                                local Active_Ability_Name = EquippedAbility

                                if not Active_Ability_Name then
                                    continue
                                end

                                local Cooldown = GetAbilityCooldownSafe(Value, Active_Ability_Name)
                                local StartTime = Now

                                if Cooldown and Cooldown > 0 then
                                    CooldownExpiration[Value] = StartTime + Cooldown
                                    CooldownTotal[Value] = Cooldown
                                end
                            end

                            LastAbilityActiveState[Value] = Current_Active_State
                        end

                        EnsureBillboard(Value)

                        local Ability_Name = GetEquippedAbility(Value)
                        local Icon = Billboard_Banner[Value]
                        local Gui = Icon and Icon.Parent

                        if Icon and Gui then
                            local Bar = Gui:FindFirstChild("Bar")
                            local Fill = Bar and Bar:FindFirstChild("Fill")
                            local Info = Gui:FindFirstChild("Info")

                            if not Ability_Name then
                                Icon.Visible = false
                                if Bar then Bar.Visible = false end
                                if Info then Info.Visible = false end
                            else
                                local head = Gui.Adornee
                                local cam = workspace.CurrentCamera
                                if head and cam then
                                    local dist = (cam.CFrame.Position - head.Position).Magnitude
                                    local screen = math.clamp(cam.ViewportSize.Y / 1080, 0.7, 1.5)
                                    local s = math.clamp(1.3 - dist / 200, 0.85, 1.25) * screen
                                    Gui.Size = UDim2.new(0, 60 * s, 0, 80 * s)
                                end

                                local Ability_Data = Data_Abilities:FindFirstChild(Ability_Name)
                                local Ability_Icon = Ability_Data and Ability_Data:GetAttribute("Icon")
                                local Upgraded_Icon = Ability_Data and Ability_Data:GetAttribute("Icon1")
                                local Upgrade_Level = GetUpgradeLevel(Value, Value.Character, Ability_Name)

                                if Upgrade_Level > 0 and Upgraded_Icon and Upgraded_Icon ~= "" then
                                    Ability_Icon = Upgraded_Icon
                                end

                                if Ability_Icon and Ability_Icon ~= "" then
                                    if Icon.Image ~= Ability_Icon then Icon.Image = Ability_Icon end
                                    Icon.Visible = true
                                else
                                    Icon.Visible = false
                                end

                                local Badge = Icon:FindFirstChild('VersionBadge')
                                if Badge then
                                    if Icon.Visible and Upgrade_Level > 0 then
                                        UpdateVersionBadge(Badge, Upgrade_Level)
                                        Badge.Visible = true
                                    else
                                        Badge.Visible = false
                                    end
                                end

                                local barFraction = nil
                                local barColor = COLOR_READY
                                local infoText = ""

                                local Is_Passive = Passive_Abilities[Ability_Name]
                                local Is_Charge = Charge_Abilities[Ability_Name]

                                local Fury_Result = FuryResult[Value]
                                if Fury_Result and Now >= Fury_Result[2] then
                                    FuryResult[Value] = nil
                                    Fury_Result = nil
                                    FuryUI.Clear(Value)
                                end

                                if Is_Passive then
                                elseif Ability_Name == "Slashes of Fury" and (FuryStartCount[Value] or Fury_Result) then
                                    barFraction = nil
                                    infoText = ""

                                    local Is_Active = FuryStartCount[Value] ~= nil
                                    local Count = Is_Active and GetFuryCount(Value) or (Fury_Result and Fury_Result[1]) or 0
                                    local HintBall = nil
                                    if Is_Active then
                                        for _, b in ipairs(BallsFolder:GetChildren()) do
                                            if not b:GetAttribute("realBall") then
                                                HintBall = b; break
                                            end
                                        end
                                    end
                                    FuryUI.Sync(Value, Is_Active, Count, HintBall, Now)
                                elseif Ability_Name == "Dribble" then
                                    local Max = GetUpgradedMaxCharges(Value, "Dribble")
                                    local NextRefill = DribbleRefillTimes[Value] and DribbleRefillTimes[Value][1]
                                    barFraction, barColor, infoText = ChargeDisplay(
                                        math.min(DribbleCharges[Value] or Max, Max), Max,
                                        NextRefill and NextRefill - Now)
                                elseif Ability_Name == "Dragon Spirit" then
                                    local Max = GetUpgradedMaxCharges(Value, "Dragon Spirit")
                                    local NextRefill = DragonSpiritRefillTimes[Value]
                                    barFraction, barColor, infoText = ChargeDisplay(
                                        math.min(DragonSpiritCharges[Value] or Max, Max), Max,
                                        NextRefill and NextRefill - Now)
                                elseif Is_Charge then
                                    local Charge_Info = GetChargeInfo(Value.Character, Ability_Name)

                                    if Charge_Info then
                                        barFraction, barColor, infoText = ChargeDisplay(
                                            Charge_Info.Charges, Charge_Info.MaxCharges,
                                            Charge_Info.CDEnd and Charge_Info.CDEnd - tick())
                                    end
                                else
                                    if Current_Active_State then
                                        barColor = COLOR_ACTIVE
                                        if AbilityActiveStart[Value] and AbilityActiveDuration[Value] then
                                            barFraction, infoText = ActiveTimerDisplay(AbilityActiveStart[Value], AbilityActiveDuration[Value], Now)
                                        else
                                            barFraction = 1
                                            infoText = ""
                                        end
                                    else
                                        local Expire = CooldownExpiration[Value]

                                        if Expire then
                                            local remaining = Expire - Now
                                            if remaining > 0 then
                                                local total = CooldownTotal[Value] or remaining
                                                barFraction = (total > 0) and (remaining / total) or 0
                                                barColor = COLOR_CD
                                                infoText = string.format("%.1f", remaining)
                                            else
                                                CooldownExpiration[Value] = nil
                                                CooldownTotal[Value] = nil
                                                barFraction = 1
                                                barColor = COLOR_READY
                                            end
                                        else
                                            barFraction = 1
                                            barColor = COLOR_READY
                                        end
                                    end
                                end

                                if Bar and Fill then
                                    if barFraction and Icon.Visible then
                                        Bar.Visible = true
                                        Fill.Size = UDim2.new(math.clamp(barFraction, 0, 1), 0, 1, 0)
                                        Fill.BackgroundColor3 = barColor
                                        local Glow = Fill:FindFirstChild('Glow')
                                        if Glow then
                                            Glow.Color = barColor
                                            Glow.Enabled = barFraction > 0
                                        end
                                    else
                                        Bar.Visible = false
                                    end
                                end

                                if Info then
                                    if infoText ~= "" and Icon.Visible then
                                        Info.Text = infoText
                                        Info.Visible = true
                                    else
                                        Info.Visible = false
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        else
            StopAbilityChargeMonitors()

            if Connections_Manager['Ability ESP'] then
                Connections_Manager['Ability ESP']:Disconnect()
                Connections_Manager['Ability ESP'] = nil
            end
            if Connections_Manager['Billboard_PlayerRemoving'] then
                Connections_Manager['Billboard_PlayerRemoving']:Disconnect()
                Connections_Manager['Billboard_PlayerRemoving'] = nil
            end

            for plr, Value in pairs(Billboard_Banner) do
                local Gui = Value and Value.Parent
                if Gui then
                    Gui.Enabled = false
                end
            end
            table.clear(Billboard_Pending)
        end
    end,
})

Ability_ESP_Toggle:AddKeyPicker('Ability_ESP_Keybind', {
    Text = 'Ability ESP',
    Mode = 'Toggle',
})

Connections_Manager['Runtime_Tornado'] = RuntimeFolder.ChildAdded:Connect(function(Value)
    if Value.Name == 'Tornado' then
        Tornado_Time = os.clock()

        local nested = Connections_Manager['Runtime_Tornado_Nested']
        if type(nested) ~= 'table' then
            nested = {}
            Connections_Manager['Runtime_Tornado_Nested'] = nested
        end

        nested[#nested + 1] = Value:GetAttributeChangedSignal('TornadoTime'):Connect(function()
            Tornado_Time = os.clock()
        end)

        nested[#nested + 1] = Value.Destroying:Connect(function()
            Tornado_Time = nil
        end)
    end
end)

if not Is_Mobile then
    local Parry_Key_Binds = {
        [Enum.KeyCode.One] = 'Camera',
        [Enum.KeyCode.Two] = 'Dot',
        [Enum.KeyCode.Three] = 'InstaDot',
        [Enum.KeyCode.Four] = 'Backward',
        [Enum.KeyCode.Five] = 'Random',
        [Enum.KeyCode.Six] = 'RandomTarget'
    }

    Connections_Manager['Parry_Type_Keybinds'] = UserInputService.InputBegan:Connect(function(Input, Value)
        if _ScriptUnloaded then return end
        if Value then return end

        local New_Type = Parry_Key_Binds[Input.KeyCode]

        if New_Type then
            Selected_Parry_Type = New_Type

            if Library.Options.Parry_Type_Dropdown then
                local Display = (New_Type == 'RandomTarget') and 'Random Target' or (New_Type == 'InstaDot') and 'Insta Dot' or New_Type
                Library.Options.Parry_Type_Dropdown:SetValue(Display)
            end
        end
    end)
end

local Menu_Group = Tabs.UISettings:AddLeftGroupbox("Menu", "menu")

Menu_Group:AddToggle('Watermark_Toggle', {
    Text = 'Watermark',
    Default = true,
    Callback = function(state)
        if Env._WatermarkGui then
            Env._WatermarkGui.Enabled = state
        end
    end
})

Menu_Group:AddButton({
    Text = 'Unload',
    Callback = function()
        Window:Dialog({
            Title = 'Unload',
            Content = 'Are you SURE?',
            OnConfirm = UnloadScript,
        })
    end
})

if Is_Mobile then
    task.spawn(function()
        local ok = pcall(function()
            if Library.MobileToggle or Library.UniversalMobileButton or Library.ToggleButton then
                error('has_mobile')
            end
        end)
        if ok then
            local btn = Instance.new('TextButton')
            btn.Name = 'ByteMobileMenu'
            btn.Size = UDim2.fromOffset(56, 56)
            btn.Position = UDim2.new(0, 12, 0.5, -28)
            btn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
            btn.BackgroundTransparency = 0.15
            btn.Text = '☰'
            btn.TextSize = 26
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.Font = Enum.Font.GothamBold
            btn.AutoButtonColor = false
            btn.Parent = (typeof(gethui) == 'function' and gethui()) or game:GetService('CoreGui')
            Instance.new('UICorner', btn).CornerRadius = UDim.new(1, 0)
            local stroke = Instance.new('UIStroke', btn)
            stroke.Color = Color3.fromRGB(60, 60, 60)
            stroke.Thickness = 1
            btn.Activated:Connect(function()
                if Library and Library.Toggle then
                    pcall(function() Library:Toggle() end)
                end
            end)
        end
    end)
end

SaveManager:SetLibrary(Library)
if ThemeManager then
    ThemeManager:SetLibrary(Library)
end

SaveManager:IgnoreThemeSettings()

if ThemeManager then
    ThemeManager:SetFolder("Vanana")
end
SaveManager:SetFolder("Vanana")

SaveManager:BuildConfigSection(Tabs.UISettings)
if ThemeManager then
    ThemeManager:ApplyToTab(Tabs.UISettings)
end

SaveManager:LoadAutoloadConfig()

Env.WantImmortality = false
if Library and Library.Toggles and Library.Toggles.Immortality_Toggle then
    pcall(function() Library.Toggles.Immortality_Toggle:SetValue(false) end)
end

task.spawn(function()
    while not _ScriptUnloaded do
        if not Library or not Library.Window then break end
        task.wait(0.5)
    end
    if not _ScriptUnloaded then
        UnloadScript()
    end
end)
