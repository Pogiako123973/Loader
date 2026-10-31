if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

local Byte = {}

Byte.Config = {
    UiRepo = "https://raw.githubusercontent.com/viseamn/Visual/main/",
    SaveFolder = "Byte/MM2",
    LoadTimeout = 10,
    AlertTries = 20,
    AlertRetry = 0.5,
    JobFailLimit = 5,
    JobFailWindow = 10,
    StatusRefresh = 1,
    TickDelay = 0.5,
    RoleRefresh = 1,
    ShootStands = { Vector3.new(0, 0, 6), Vector3.new(0, 0, -6), Vector3.new(6, 0, 0), Vector3.new(-6, 0, 0), Vector3.new(0, 6, 3) },
    ShootAttempts = 3,
    ShootConfirm = 0.8,
    ShootSettle = 0.25,
    ShootReturn = 0.3,
    ShootCooldown = 1.2,
    StabCooldown = 0.9,
    BusyTimeout = 6,
    StabOffset = 2,
    KillAuraRange = 18,
    GunGrabHold = 0.35,
    FlingForce = 9e4,
    FlingTime = 2.5,
    FarmSpeed = 25,
    FarmSpeedMax = 25,
    FarmMurdererRadius = 30,
    FarmArrive = 1.5,
    FarmBrake = 20,
    FarmGroundLift = 4,
    FarmGroundReach = 400,
    FarmIdleWait = 0.3,
    FarmSettle = 0.15,
    FarmSkipTime = 4,
    FlySpeed = 70,
    InvisHeight = -1000,
    InvisTransparency = 0.5,
    SpeedDefault = 16,
    JumpDefault = 50,
    LobbyName = "RegularLobby",
    XRayTransparency = 0.6,
    FlingVelocityCap = 120,
    VictimPriority = { Sheriff = 1, Hero = 1, Innocent = 2 },
    Colors = {
        Murderer = Color3.fromHSV(0, 0.75, 1),
        Sheriff = Color3.fromHSV(0.6, 0.7, 1),
        Hero = Color3.fromHSV(0.14, 0.8, 1),
        Innocent = Color3.fromHSV(0.33, 0.6, 0.95),
        Gun = Color3.fromHSV(0.12, 0.9, 1),
        Coin = Color3.fromHSV(0.15, 0.6, 1),
    },
}

local Config = Byte.Config

Byte.State = {
    Alive = true,
    Conns = {},
    Roles = {},
    LastRoleFetch = 0,
    LastShoot = 0,
    LastStab = 0,
    ActionBusy = false,
    BusySince = 0,
    ShootBusy = false,
    KillBusy = false,
    FarmBusy = false,
    FarmHome = nil,
    FarmMover = nil,
    Bag = { Current = 0, Max = 0 },
    SkippedCoins = {},
    NoclipConn = nil,
    NoclipSaved = {},
    InvisConn = nil,
    FocusPart = nil,
    FlyConn = nil,
    FlyVelocity = nil,
    Hook = nil,
    XRayMap = nil,
    XRayParts = {},
    Esp = { Players = {}, Gun = nil },
    LightingDefaults = nil,
    Halted = {},
    CachedMurderer = nil,
    Opt = {
        AutoGrabGun = false,
        AutoShoot = false,
        SilentAim = false,
        SilentAimV2 = false,
        AutoKillAll = false,
        KillAura = false,
        KnifeAim = false,
        AntiFling = false,
        XRay = false,
        Aimbot = false,
        AimSmooth = 70,
        EspPlayers = false,
        EspGun = false,
        SpeedOn = false,
        WalkSpeed = 24,
        JumpOn = false,
        JumpPower = 70,
        InfJump = false,
        Noclip = false,
        Fly = false,
        Invisible = false,
        Fullbright = false,
        AntiAfk = false,
        TrollTarget = nil,
        AutoFarm = false,
        FarmSpeed = 25,
        ResetWhenFull = false,
        UnlockAll = false,
    },
}

local State = Byte.State

for _, name in ipairs({ "Util", "Round", "Sheriff", "Murderer", "Troll", "Aim", "Movement", "Esp", "Visual", "Session", "Scheduler", "Farm", "UnlockAll" }) do
    Byte[name] = {}
end

function Byte.Util.Try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[Byte]", err) end
    return ok, err
end

function Byte.Util.Alert(text)
    warn("[Byte] " .. text)
    task.spawn(function()
        local starterGui = game:GetService("StarterGui")
        for _ = 1, Config.AlertTries do
            if pcall(starterGui.SetCore, starterGui, "SendNotification", { Title = "Byte", Text = text, Duration = 10 }) then
                return
            end
            task.wait(Config.AlertRetry)
        end
    end)
end

function Byte.Util.LoadLibrary()
    local function fetch(name)
        local url = Config.UiRepo .. name
        local ok, chunk = pcall(function() return loadstring(game:HttpGet(url)) end)
        if not ok or type(chunk) ~= "function" then return nil end
        local ok2, lib = pcall(chunk)
        if not ok2 or type(lib) ~= "table" then return nil end
        return lib
    end
    local Lib = fetch("Library.lua")
    if not Lib then
        Byte.Util.Alert("Could not load the Byte menu.")
        return nil
    end
    return {
        Library = Lib,
        Themes = fetch("ThemeManager.lua"),
        Save = fetch("SaveManager.lua"),
    }
end

function Byte.Util.Mount(instance)
    local ok, hui = pcall(gethui)
    if ok and typeof(hui) == "Instance" and pcall(function() instance.Parent = hui end) then return end
    if pcall(function() instance.Parent = game:GetService("CoreGui") end) then return end
    instance.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", Config.LoadTimeout)
end

function Byte.Util.Connect(signal, fn)
    local conn = signal:Connect(fn)
    table.insert(State.Conns, conn)
    return conn
end

function Byte.Util.Root(player)
    local character = (player or LocalPlayer).Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

function Byte.Util.Humanoid(player)
    local character = (player or LocalPlayer).Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

function Byte.Util.Tool(player, name)
    local character = player.Character
    local backpack = player:FindFirstChild("Backpack")
    return (character and character:FindFirstChild(name)) or (backpack and backpack:FindFirstChild(name))
end

function Byte.Util.Busy()
    return State.ActionBusy and os.clock() - State.BusySince < Config.BusyTimeout
end

function Byte.Util.SetBusy(busy)
    State.ActionBusy = busy
    State.BusySince = os.clock()
end

function Byte.Util.WarpAndReturn(targetCFrame, action)
    local root = Byte.Util.Root()
    local char = LocalPlayer.Character
    if not root or not char or not targetCFrame or Byte.Util.Busy() then return false end
    Byte.Util.SetBusy(true)
    
    local home = root.CFrame
    local oldVel = root.AssemblyLinearVelocity
    
    char:PivotTo(targetCFrame)
    root.AssemblyLinearVelocity = Vector3.zero
    RunService.Heartbeat:Wait() 
    
    local ok = Byte.Util.Try(function()
        action()
    end)
    
    if char.Parent then
        char:PivotTo(home)
        local newRoot = Byte.Util.Root()
        if newRoot then 
            newRoot.AssemblyLinearVelocity = oldVel * 0.5 
        end
    end
    
    Byte.Util.SetBusy(false)
    return ok
end

function Byte.Util.IsDead(player)
    local h = Byte.Util.Humanoid(player)
    return not h or h.Health <= 0
end

Byte.GameLib = {}
local GameLib = Byte.GameLib

function GameLib.Remote(folder, name, class)
    local remote = folder and folder:FindFirstChild(name)
    remote = remote or ReplicatedStorage:FindFirstChild(name, true)
    return remote and remote:IsA(class) and remote or nil
end

do
    local remotes = ReplicatedStorage:WaitForChild("Remotes", Config.LoadTimeout)
    local gameplay = remotes and remotes:WaitForChild("Gameplay", Config.LoadTimeout)
    GameLib.PlayerData = GameLib.Remote(gameplay, "GetCurrentPlayerData", "RemoteFunction")
    GameLib.CoinCollected = GameLib.Remote(gameplay, "CoinCollected", "BaseRemoteEvent")
    GameLib.CoinsStarted = GameLib.Remote(gameplay, "CoinsStarted", "BaseRemoteEvent")
    GameLib.RoundStart = GameLib.Remote(gameplay, "RoundStart", "BaseRemoteEvent")
end

function Byte.Round.RefreshRoles()
    if os.clock() - State.LastRoleFetch < Config.RoleRefresh then return end
    State.LastRoleFetch = os.clock()
    if not GameLib.PlayerData then return end
    local ok, roster = pcall(GameLib.PlayerData.InvokeServer, GameLib.PlayerData)
    if ok and type(roster) == "table" then State.Roles = roster end
end

function Byte.Round.RoleOf(player)
    local entry = State.Roles[player.Name]
    if entry and not entry.Dead and entry.Role then return entry.Role end
    if Byte.Util.Tool(player, "Knife") then return "Murderer" end
    if Byte.Util.Tool(player, "Gun") then return "Sheriff" end
    return entry and entry.Dead and "Dead" or "Innocent"
end

function Byte.Round.FindByRole(role)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and Byte.Round.RoleOf(player) == role and Byte.Util.Root(player) then
            return player
        end
    end
    return nil
end

function Byte.Round.Map()
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name ~= Config.LobbyName and child:IsA("Model") and child:FindFirstChild("CoinContainer") then
            return child
        end
    end
    return nil
end

function Byte.Round.IAmPlaying()
    local entry = State.Roles[LocalPlayer.Name]
    local humanoid = Byte.Util.Humanoid()
    return Byte.Round.Map() ~= nil and humanoid ~= nil and humanoid.Health > 0 and entry ~= nil and not entry.Dead
end

function Byte.Round.GunDrop()
    local map = Byte.Round.Map()
    return (map and map:FindFirstChild("GunDrop", true)) or workspace:FindFirstChild("GunDrop")
end

function Byte.Movement.SetNoclip(enabled)
    if State.NoclipConn then State.NoclipConn:Disconnect(); State.NoclipConn = nil end
    if not enabled then Byte.Movement.RestoreCollision(); return end
    local saved = State.NoclipSaved
    State.NoclipConn = Byte.Util.Connect(RunService.Stepped, function()
        local character = LocalPlayer.Character
        if not character then return end
        for _, part in ipairs(character:GetChildren()) do
            if not part:IsA("BasePart") then continue end
            if saved[part] == nil then saved[part] = part.CanCollide end
            part.CanCollide = false
        end
    end)
end

function Byte.Movement.RestoreCollision()
    for part, canCollide in pairs(State.NoclipSaved) do
        if part.Parent then part.CanCollide = canCollide end
    end
    table.clear(State.NoclipSaved)
end

function Byte.Movement.RefreshNoclip()
    Byte.Movement.SetNoclip(State.Opt.Noclip or State.FarmBusy)
end

function Byte.Movement.Apply()
    local humanoid = Byte.Util.Humanoid()
    if not humanoid then return end
    local opt = State.Opt
    if opt.SpeedOn then humanoid.WalkSpeed = opt.WalkSpeed end
    if opt.JumpOn then humanoid.UseJumpPower = true; humanoid.JumpPower = opt.JumpPower end
end

function Byte.Movement.RestoreSpeed()
    local h = Byte.Util.Humanoid(); if h then h.WalkSpeed = Config.SpeedDefault end
end

function Byte.Movement.RestoreJump()
    local h = Byte.Util.Humanoid(); if h then h.JumpPower = Config.JumpDefault end
end

function Byte.Movement.InitInfJump()
    Byte.Util.Connect(UserInputService.JumpRequest, function()
        local h = Byte.Util.Humanoid()
        if State.Opt.InfJump and h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end

function Byte.Movement.SetInvis(enabled)
    State.Opt.Invisible = enabled
    local char = LocalPlayer.Character
    local hum = Byte.Util.Humanoid()
    local root = Byte.Util.Root()

    if not enabled then
        if State.InvisConn then State.InvisConn:Disconnect(); State.InvisConn = nil end
        if State.FocusPart then State.FocusPart:Destroy(); State.FocusPart = nil end
        if hum and root then pcall(function() LocalPlayer.ReplicationFocus = root end) end
        if char then
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    if part.Name ~= "HumanoidRootPart" then part.Transparency = 0 end
                elseif part:IsA("Decal") then
                    part.Transparency = 0
                end
            end
        end
        return
    end

    if not root or not hum then return end
    
    if not State.FocusPart then
        State.FocusPart = Instance.new("Part")
        State.FocusPart.Name = "ByteInvisFocus"
        State.FocusPart.Transparency = 1
        State.FocusPart.CanCollide = false
        State.FocusPart.CanQuery = false
        State.FocusPart.CanTouch = false
        State.FocusPart.Anchored = true
        State.FocusPart.Parent = workspace
    end
    pcall(function() LocalPlayer.ReplicationFocus = State.FocusPart end)

    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            if part.Name == "HumanoidRootPart" then
                part.Transparency = 1
            else
                part.Transparency = Config.InvisTransparency
            end
        elseif part:IsA("Decal") then
            part.Transparency = Config.InvisTransparency
        end
    end

    if State.InvisConn then State.InvisConn:Disconnect() end
    State.InvisConn = RunService.Heartbeat:Connect(function()
        if not State.Opt.Invisible or not root.Parent or not hum then return end
        
        local realCF = root.CFrame
        local oldOffset = hum.CameraOffset
        local hiddenCF = realCF * CFrame.new(0, Config.InvisHeight, 0)
        
        if State.FocusPart then State.FocusPart.CFrame = realCF end

        root.CFrame = hiddenCF
        hum.CameraOffset = hiddenCF:ToObjectSpace(CFrame.new(realCF.Position)).Position
        
        RunService.RenderStepped:Wait()
        
        root.CFrame = realCF
        hum.CameraOffset = oldOffset
    end)
end

function Byte.Movement.SetFly(enabled)
    if State.FlyConn then State.FlyConn:Disconnect(); State.FlyConn = nil end
    if State.FlyVelocity then State.FlyVelocity:Destroy(); State.FlyVelocity = nil end
    local h = Byte.Util.Humanoid(); if h then h.PlatformStand = false end
    if not enabled then return end
    local mover = Instance.new("BodyVelocity")
    mover.MaxForce = Vector3.one * 1e9
    mover.Velocity = Vector3.zero
    State.FlyVelocity = mover
    State.FlyConn = Byte.Util.Connect(RunService.RenderStepped, function()
        local root, hum = Byte.Util.Root(), Byte.Util.Humanoid()
        if not root or not hum then return end
        mover.Parent = root
        hum.PlatformStand = true
        local vertical = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and 1 or 0)
        mover.Velocity = (hum.MoveDirection + Vector3.yAxis * vertical) * Config.FlySpeed
    end)
end

function Byte.Movement.AntiFlingStep()
    if not State.Opt.AntiFling then return end
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player ~= LocalPlayer and player.Character
        if character then
            for _, part in ipairs(character:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
    local root = Byte.Util.Root()
    if root and not Byte.Util.Busy() and not State.Opt.Fly and root.AssemblyLinearVelocity.Magnitude > Config.FlingVelocityCap then
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
end

function Byte.Sheriff.Gun() return Byte.Util.Tool(LocalPlayer, "Gun") end

function Byte.Sheriff.Equip(tool)
    local h = Byte.Util.Humanoid()
    if h and tool.Parent ~= LocalPlayer.Character then h:EquipTool(tool) end
end

function Byte.Sheriff.ClearStand(target, targetRoot)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, target.Character }
    for _, offset in ipairs(Config.ShootStands) do
        local pos = (targetRoot.CFrame * CFrame.new(offset)).Position
        if not workspace:Raycast(pos, targetRoot.Position - pos, params) then
            return CFrame.lookAt(pos, targetRoot.Position)
        end
    end
    return CFrame.lookAt((targetRoot.CFrame * CFrame.new(Config.ShootStands[1])).Position, targetRoot.Position)
end

function Byte.Sheriff.ShootTarget(target)
    local gun, targetRoot = Byte.Sheriff.Gun(), Byte.Util.Root(target)
    if not gun or not targetRoot or os.clock() - State.LastShoot < Config.ShootCooldown then return false end
    State.LastShoot = os.clock()
    Byte.Sheriff.Equip(gun)
    return Byte.Util.WarpAndReturn(Byte.Sheriff.ClearStand(target, targetRoot), function()
        task.wait(Config.ShootSettle)
        local root = Byte.Util.Root()
        local attachment = root and root:FindFirstChild("GunRaycastAttachment")
        local aimRoot = Byte.Util.Root(target) or targetRoot
        gun.Shoot:FireServer(attachment and attachment.WorldCFrame or root.CFrame, aimRoot.CFrame)
        task.wait(Config.ShootReturn)
    end)
end

function Byte.Sheriff.ShootMurderer()
    Byte.Round.RefreshRoles()
    local murderer = Byte.Round.FindByRole("Murderer")
    if not murderer then return false, "No murderer found" end
    for _ = 1, Config.ShootAttempts do
        if not Byte.Sheriff.Gun() then break end
        Byte.Sheriff.ShootTarget(murderer)
        task.wait(Config.ShootConfirm)
        if Byte.Util.IsDead(murderer) then return true, murderer.Name end
        task.wait(math.max(0, Config.ShootCooldown - Config.ShootConfirm))
    end
    return false, murderer.Name .. " survived"
end

function Byte.Sheriff.AutoShootStep()
    if not State.Opt.AutoShoot or State.ShootBusy or not Byte.Sheriff.Gun() or not Byte.Round.IAmPlaying() then return end
    State.ShootBusy = true
    task.spawn(function()
        Byte.Util.Try(Byte.Sheriff.ShootMurderer)
        State.ShootBusy = false
    end)
end

function Byte.Sheriff.GrabGun()
    local drop = Byte.Round.GunDrop()
    if not drop or Byte.Sheriff.Gun() or not Byte.Round.IAmPlaying() then return false end
    local part = drop:IsA("BasePart") and drop or drop:FindFirstChildWhichIsA("BasePart", true)
    if not part then return false end
    return Byte.Util.WarpAndReturn(part.CFrame, function()
        local root = Byte.Util.Root()
        if root and type(firetouchinterest) == "function" then
            pcall(function()
                firetouchinterest(root, part, 0)
                firetouchinterest(root, part, 1)
            end)
        end
        task.wait(Config.GunGrabHold)
    end)
end

function Byte.Sheriff.AutoGrabStep()
    if State.Opt.AutoGrabGun and Byte.Round.RoleOf(LocalPlayer) ~= "Murderer" and Byte.Round.GunDrop() then
        task.spawn(Byte.Sheriff.GrabGun)
    end
end

function Byte.Murderer.Knife() return Byte.Util.Tool(LocalPlayer, "Knife") end

function Byte.Murderer.Stab(target)
    local knife, targetRoot = Byte.Murderer.Knife(), Byte.Util.Root(target)
    if not knife or not targetRoot then return false end
    Byte.Sheriff.Equip(knife)
    local events = knife:FindFirstChild("Events")
    if not events then return false end
    local stand = targetRoot.CFrame * CFrame.new(0, 0, Config.StabOffset)
    return Byte.Util.WarpAndReturn(stand, function()
        events.KnifeStabbed:FireServer()
        task.wait()
        local aimRoot = Byte.Util.Root(target) or targetRoot
        events.HandleTouched:FireServer(aimRoot)
        task.wait(Config.StabCooldown)
    end)
end

function Byte.Murderer.Victims()
    local victims = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local humanoid = Byte.Util.Humanoid(player)
        local entry = State.Roles[player.Name]
        local inRound = entry == nil or not entry.Dead
        if player ~= LocalPlayer and humanoid and humanoid.Health > 0 and inRound and Byte.Util.Root(player) then
            table.insert(victims, player)
        end
    end
    table.sort(victims, function(a, b)
        return (Config.VictimPriority[Byte.Round.RoleOf(a)] or 3) < (Config.VictimPriority[Byte.Round.RoleOf(b)] or 3)
    end)
    return victims
end

function Byte.Murderer.KillAll()
    if not Byte.Murderer.Knife() then return 0 end
    local kills = 0
    for _, victim in ipairs(Byte.Murderer.Victims()) do
        if not State.Alive or not Byte.Murderer.Knife() then break end
        if Byte.Murderer.Stab(victim) then kills = kills + 1 end
    end
    return kills
end

function Byte.Murderer.AutoKillStep()
    if not State.Opt.AutoKillAll or State.KillBusy or not Byte.Murderer.Knife() or not Byte.Round.IAmPlaying() then return end
    State.KillBusy = true
    task.spawn(function()
        Byte.Util.Try(Byte.Murderer.KillAll)
        State.KillBusy = false
    end)
end

function Byte.Murderer.KillAuraStep()
    local knife, root = Byte.Murderer.Knife(), Byte.Util.Root()
    if not State.Opt.KillAura or not knife or not root or os.clock() - State.LastStab < Config.StabCooldown then return end
    local events = knife:FindFirstChild("Events")
    for _, victim in ipairs(Byte.Murderer.Victims()) do
        local victimRoot = Byte.Util.Root(victim)
        if events and victimRoot and (victimRoot.Position - root.Position).Magnitude <= Config.KillAuraRange then
            State.LastStab = os.clock()
            Byte.Sheriff.Equip(knife)
            events.KnifeStabbed:FireServer()
            events.HandleTouched:FireServer(victimRoot)
            return
        end
    end
end

function Byte.Murderer.NearestVictimRoot(origin)
    local best, bestDistance
    for _, victim in ipairs(Byte.Murderer.Victims()) do
        local victimRoot = Byte.Util.Root(victim)
        local distance = victimRoot and (victimRoot.Position - origin).Magnitude
        if distance and (not bestDistance or distance < bestDistance) then
            best, bestDistance = victimRoot, distance
        end
    end
    return best
end

function Byte.Sheriff.SyncAimHook()
    local wanted = State.Alive and (State.Opt.SilentAim or State.Opt.SilentAimV2 or State.Opt.KnifeAim)
    if wanted and not State.Hook then
        Byte.Util.Try(Byte.Sheriff.InstallAimHook)
    elseif not wanted and State.Hook then
        local restore = State.Hook
        State.Hook = nil
        Byte.Util.Try(restore)
    end
end

function Byte.Sheriff.InstallAimHook()
    if type(hookmetamethod) ~= "function" or type(checkcaller) ~= "function" or type(getnamecallmethod) ~= "function" then
        Byte.Util.Alert("This executor cannot hook the aim function")
        return
    end

    local original
    original = hookmetamethod(game, "__namecall", function(self, ...)
        if not State.Alive or getnamecallmethod() ~= "FireServer" or checkcaller() then
            return original(self, ...)
        end
        
        local parent = self.Parent
        local opt = State.Opt
        
        if (opt.SilentAim or opt.SilentAimV2) and self.Name == "Shoot" and parent and parent.Name == "Gun" then
            local murdererRoot = nil
            
            if opt.SilentAimV2 and State.CachedMurderer then
                murdererRoot = State.CachedMurderer
            end
            
            if not murdererRoot and opt.SilentAim then
                local murderer = Byte.Round.FindByRole("Murderer")
                murdererRoot = murderer and Byte.Util.Root(murderer)
            end
            
            if murdererRoot then
                local args = {...}
                if opt.SilentAimV2 then
                    args[1] = murdererRoot.CFrame + Vector3.new(0, 3, 0)
                    args[2] = murdererRoot.CFrame
                else
                    args[2] = murdererRoot.CFrame
                end
                return original(self, unpack(args))
            end
        elseif opt.KnifeAim and self.Name == "KnifeThrown" and parent and parent.Name == "Events" then
            local origin = ...
            local victimRoot = Byte.Murderer.NearestVictimRoot(origin.Position)
            if victimRoot then
                return original(self, origin, victimRoot.Position)
            end
        end
        return original(self, ...)
    end)
    
    State.Hook = function()
        hookmetamethod(game, "__namecall", original)
    end
end

function Byte.Troll.Target()
    return State.Opt.TrollTarget and Players:FindFirstChild(State.Opt.TrollTarget)
end

function Byte.Troll.Fling(target)
    local root, targetRoot = Byte.Util.Root(), Byte.Util.Root(target)
    if not root or not targetRoot or Byte.Util.Busy() then return false end
    Byte.Util.SetBusy(true)
    local home = root.CFrame
    local spin = Instance.new("BodyAngularVelocity")
    spin.MaxTorque = Vector3.one * math.huge
    spin.AngularVelocity = Vector3.new(0, Config.FlingForce, 0)
    spin.Parent = root
    Byte.Movement.SetNoclip(true)
    local started = os.clock()
    while os.clock() - started < Config.FlingTime do
        local currentTarget = Byte.Util.Root(target)
        if not currentTarget or not root.Parent then break end
        root.CFrame = currentTarget.CFrame
        root.AssemblyLinearVelocity = Vector3.zero
        RunService.Heartbeat:Wait()
    end
    spin:Destroy()
    if root.Parent then
        root.AssemblyAngularVelocity = Vector3.zero
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = home
    end
    Byte.Util.SetBusy(false)
    Byte.Movement.RefreshNoclip()
    return true
end

function Byte.Aim.Target()
    if Byte.Murderer.Knife() then return Byte.Murderer.Victims()[1] end
    return Byte.Round.FindByRole("Murderer")
end

function Byte.Aim.Step(dt)
    if not State.Opt.Aimbot then return end
    local target = Byte.Aim.Target()
    local head = target and target.Character and target.Character:FindFirstChild("Head")
    if not head then return end
    local camera = workspace.CurrentCamera
    local goal = CFrame.lookAt(camera.CFrame.Position, head.Position)
    local alpha = 1 - (State.Opt.AimSmooth / 100) ^ (dt * 60)
    camera.CFrame = camera.CFrame:Lerp(goal, math.clamp(alpha, 0, 1))
end

function Byte.Esp.Init()
    Byte.Esp.Folder = Instance.new("Folder")
    Byte.Esp.Folder.Name = game:GetService("HttpService"):GenerateGUID(false)
    Byte.Util.Mount(Byte.Esp.Folder)
end

function Byte.Esp.MakeHighlight(adornee, color)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = 0.65
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = adornee
    highlight.Parent = Byte.Esp.Folder
    return highlight
end

function Byte.Esp.MakeLabel(adornee, color)
    local gui = Instance.new("BillboardGui")
    gui.Size = UDim2.fromOffset(180, 30)
    gui.StudsOffset = Vector3.new(0, 3.5, 0)
    gui.AlwaysOnTop = true
    gui.Adornee = adornee
    local label = Instance.new("TextLabel")
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.4
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = gui
    gui.Parent = Byte.Esp.Folder
    return gui, label
end

function Byte.Esp.DropEntry(entry)
    if entry then
        if entry.Highlight then entry.Highlight:Destroy() end
        if entry.Gui then entry.Gui:Destroy() end
    end
end

function Byte.Esp.RefreshPlayers()
    local entries = State.Esp.Players
    for _, player in ipairs(Players:GetPlayers()) do
        local character, root = player.Character, Byte.Util.Root(player)
        local entry = entries[player]
        local role = Byte.Round.RoleOf(player)
        local visible = State.Opt.EspPlayers and player ~= LocalPlayer and character and root and role ~= "Dead"
        if not visible then
            Byte.Esp.DropEntry(entry)
            entries[player] = nil
        else
            if not entry or entry.Character ~= character then
                Byte.Esp.DropEntry(entry)
                local gui, label = Byte.Esp.MakeLabel(root, Color3.new(1, 1, 1))
                entry = { Character = character, Highlight = Byte.Esp.MakeHighlight(character, Color3.new(1, 1, 1)), Gui = gui, Label = label }
                entries[player] = entry
            end
            local color = Config.Colors[role] or Config.Colors.Innocent
            entry.Highlight.FillColor, entry.Highlight.OutlineColor, entry.Label.TextColor3 = color, color, color
            entry.Label.Text = string.format("%s [%s]", player.DisplayName, role)
        end
    end
    for player, entry in pairs(entries) do
        if not player.Parent then
            Byte.Esp.DropEntry(entry)
            entries[player] = nil
        end
    end
end

function Byte.Esp.RefreshGun()
    local drop = State.Opt.EspGun and Byte.Round.GunDrop()
    local entry = State.Esp.Gun
    if entry and entry.Adornee == drop then return end
    Byte.Esp.DropEntry(entry)
    State.Esp.Gun = nil
    if drop then
        local gui, label = Byte.Esp.MakeLabel(drop, Config.Colors.Gun)
        label.Text = "GUN DROP"
        State.Esp.Gun = { Adornee = drop, Highlight = Byte.Esp.MakeHighlight(drop, Config.Colors.Gun), Gui = gui }
    end
end

function Byte.Esp.Destroy()
    if Byte.Esp.Folder then Byte.Esp.Folder:Destroy() end
    table.clear(State.Esp.Players)
    State.Esp.Gun = nil
end

function Byte.Visual.SetFullbright(enabled)
    if enabled and not State.LightingDefaults then
        State.LightingDefaults = { Ambient = Lighting.Ambient, Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows }
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e9
        Lighting.GlobalShadows = false
    elseif not enabled and State.LightingDefaults then
        for property, value in pairs(State.LightingDefaults) do Lighting[property] = value end
        State.LightingDefaults = nil
    end
end

function Byte.Visual.ClearXRay()
    for part, original in pairs(State.XRayParts) do
        if part.Parent then part.Transparency = original end
    end
    table.clear(State.XRayParts)
    State.XRayMap = nil
end

function Byte.Visual.XRayStep()
    if not State.Opt.XRay then
        if State.XRayMap then Byte.Visual.ClearXRay() end
        return
    end
    local map = Byte.Round.Map()
    if not map or State.XRayMap == map then return end
    Byte.Visual.ClearXRay()
    State.XRayMap = map
    local coins = map:FindFirstChild("CoinContainer")
    for _, part in ipairs(map:GetDescendants()) do
        if part:IsA("BasePart") and not (coins and part:IsDescendantOf(coins)) then
            State.XRayParts[part] = part.Transparency
            part.Transparency = math.max(part.Transparency, Config.XRayTransparency)
        end
    end
end

function Byte.Session.InitAntiAfk()
    Byte.Util.Connect(LocalPlayer.Idled, function()
        if State.Opt.AntiAfk then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end

function Byte.Farm.NearestCoin(map, origin)
    local murderer = not Byte.Murderer.Knife() and Byte.Round.FindByRole("Murderer")
    local threat = murderer and Byte.Util.Root(murderer)
    local best, bestDistance
    for _, coin in ipairs(map.CoinContainer:GetChildren()) do
        local visual = coin:FindFirstChild("CoinVisual")
        local skippedAt = State.SkippedCoins[coin]
        local skipped = skippedAt and os.clock() - skippedAt < Config.FarmSkipTime
        local dangerous = threat and (coin.Position - threat.Position).Magnitude < Config.FarmMurdererRadius
        if coin:IsA("BasePart") and visual and not visual:GetAttribute("Collected") and not skipped and not dangerous then
            local distance = (coin.Position - origin).Magnitude
            if not bestDistance or distance < bestDistance then
                best, bestDistance = coin, distance
            end
        end
    end
    return best
end

function Byte.Farm.BagFull()
    return State.Bag.Max > 0 and State.Bag.Current >= State.Bag.Max
end

function Byte.Farm.CanRun()
    return State.Alive and State.Opt.AutoFarm and Byte.Round.IAmPlaying() and not Byte.Farm.BagFull()
end

function Byte.Farm.AttachMover(root)
    local attachment = Instance.new("Attachment")
    attachment.Parent = root
    local mover = Instance.new("LinearVelocity")
    mover.Attachment0 = attachment
    mover.MaxForce = math.huge
    mover.RelativeTo = Enum.ActuatorRelativeTo.World
    mover.VectorVelocity = Vector3.zero
    mover.Parent = root
    State.FarmMover = { Attachment = attachment, Velocity = mover }
    return mover
end

function Byte.Farm.DetachMover()
    local mover = State.FarmMover
    if mover then
        mover.Velocity:Destroy()
        mover.Attachment:Destroy()
        State.FarmMover = nil
    end
end

function Byte.Farm.GlideTo(position)
    local root = Byte.Util.Root()
    local mover = State.FarmMover
    if not root or not mover or mover.Velocity.Parent ~= root then
        Byte.Farm.DetachMover()
        mover = root and { Velocity = Byte.Farm.AttachMover(root) }
    end
    while mover and Byte.Farm.CanRun() and root.Parent do
        local delta = position - root.Position
        if delta.Magnitude <= Config.FarmArrive then
            break
        end
        mover.Velocity.VectorVelocity = delta.Unit * math.min(State.Opt.FarmSpeed, delta.Magnitude * Config.FarmBrake)
        RunService.Heartbeat:Wait()
    end
    if mover then
        mover.Velocity.VectorVelocity = Vector3.zero
    end
end

function Byte.Farm.Run()
    local root = Byte.Util.Root()
    if root then
        Byte.Farm.AttachMover(root)
    end
    Byte.Movement.RefreshNoclip()
    State.FarmHome = root and root.CFrame
    while Byte.Farm.CanRun() do
        local map, hrp = Byte.Round.Map(), Byte.Util.Root()
        local coin = map and hrp and Byte.Farm.NearestCoin(map, hrp.Position)
        if coin and not Byte.Util.Busy() then
            Byte.Farm.GlideTo(coin.Position)
            task.wait(Config.FarmSettle)
            State.SkippedCoins[coin] = os.clock()
        else
            local mover = State.FarmMover
            if mover then
                mover.Velocity.VectorVelocity = Vector3.zero
            end
            task.wait(Config.FarmIdleWait)
        end
    end
end

function Byte.Farm.Settle()
    local root, home = Byte.Util.Root(), State.FarmHome
    State.FarmHome = nil
    if not root then return end
    root.AssemblyLinearVelocity = Vector3.zero
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    local ground = workspace:Raycast(root.Position + Vector3.new(0, Config.FarmGroundLift, 0), Vector3.new(0, -Config.FarmGroundReach, 0), params)
    if ground or not home then return end
    root.CFrame = home
end

function Byte.Farm.Step()
    if State.FarmBusy or not Byte.Farm.CanRun() then return end
    State.FarmBusy = true
    task.spawn(function()
        local ok = Byte.Util.Try(Byte.Farm.Run)
        Byte.Farm.DetachMover()
        Byte.Farm.Settle()
        State.FarmBusy = false
        Byte.Movement.RefreshNoclip()

        local humanoid = Byte.Util.Humanoid()
        if ok and humanoid and State.Opt.ResetWhenFull and Byte.Farm.BagFull() then
            humanoid.Health = 0
        end
    end)
end

function Byte.Farm.InitBagTracking()
    if not GameLib.CoinCollected then
        warn("[Byte] CoinCollected remote not found — bag counter will not update")
    end
    if not GameLib.CoinsStarted then
        warn("[Byte] CoinsStarted remote not found — bag counter may stay stale")
    end
    if GameLib.CoinCollected then
        Byte.Util.Connect(GameLib.CoinCollected.OnClientEvent, function(a, b, c)
            local newCurrent, newMax
            if typeof(a) == "Instance" or type(a) == "string" then
                newCurrent = tonumber(b) or 0
                newMax = tonumber(c) or 0
            else
                newCurrent = tonumber(a) or 0
                newMax = tonumber(b) or 0
            end
            State.Bag.Current = newCurrent
            if newMax > 0 then State.Bag.Max = newMax end
        end)
    end
    if GameLib.CoinsStarted then
        Byte.Util.Connect(GameLib.CoinsStarted.OnClientEvent, function()
            State.Bag.Current, State.Bag.Max = 0, 0
            table.clear(State.SkippedCoins)
        end)
    end
    if not GameLib.RoundStart then return end
    Byte.Util.Connect(GameLib.RoundStart.OnClientEvent, function()
        State.Bag.Current, State.Bag.Max = 0, 0
        table.clear(State.Roles)
    end)
end

local ua_data = nil
local ua_backup = nil
local ua_originalKnife = nil
local ua_originalGun = nil
local ua_selectedKnife = nil
local ua_selectedGun = nil
local ua_savePath = "Byte_Skins.txt"

local function getUAData()
    local url = "https://raw.githubusercontent.com/Pogiako123973/mm2/refs/heads/main/mm2meshes.lua"
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or not body then return nil end
    local success, data = pcall(function() return loadstring(body)() end)
    if success then return data end
    return nil
end

local function findUAMeshAndTexture(node)
    if not node or type(node) ~= "table" then return nil end
    local props = node.Props
    if props then
        local meshId = props.MeshId or props.MeshID
        if meshId and meshId ~= "" then
            return {
                meshid = meshId,
                textureid = props.TextureId or props.TextureID or "",
                scale = props.Scale or Vector3.new(0.045,0.045,0.045),
                size = props.Size or Vector3.new(0.045,0.045,0.045)
            }
        end
    end
    if node.Display and type(node.Display) == "table" then
        for _, child in ipairs(node.Display) do
            local res = findUAMeshAndTexture(child)
            if res then return res end
        end
    end
    return nil
end

local function getUAWeaponData(name)
    if not ua_data or not ua_data[name] then return nil end
    return findUAMeshAndTexture(ua_data[name])
end

local function applyUAWeaponMesh(refPart, weaponData, weaponName, weapontype)
    if not weaponData or not weaponData.meshid then return end

    if weaponData.meshid:find("79401392") then
        if weapontype == "Gun" then
            local tool = refPart:FindFirstAncestorOfClass("Tool")
            if tool then tool.Grip = CFrame.fromMatrix(Vector3.new(0, -0.699999988, -0.300000012), Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, -1, 0)) end
        end
    elseif weaponData.meshid:find("6600918074") then
        if weapontype == "Gun" then
            local tool = refPart:FindFirstAncestorOfClass("Tool")
            if tool then tool.Grip = CFrame.new(1, -0.359999988, 0.00000012, 0, 0, 1, 0, 1, 0, -1, 0, 0) end
        end
    else
        if weapontype == "Gun" then
            local tool = refPart:FindFirstAncestorOfClass("Tool")
            if tool then tool.Grip = CFrame.fromMatrix(Vector3.new(0, -0.5, 0.7), Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), Vector3.new(0, 0, 1)) end
        end
    end

    if refPart:IsA("MeshPart") then
        local specialMesh = refPart:FindFirstChildOfClass("SpecialMesh")
        if specialMesh then specialMesh:Destroy() end
        refPart.Size = weaponData.size
        refPart.MeshId = weaponData.meshid
        refPart.TextureID = weaponData.textureid
    else
        local mesh = refPart:FindFirstChildOfClass("SpecialMesh")
        if not mesh then
            mesh = Instance.new("SpecialMesh")
            mesh.Name = "Mesh"
            mesh.Parent = refPart
        end
        refPart.Size = weaponData.size
        mesh.MeshId = weaponData.meshid
        mesh.TextureId = weaponData.textureid
        mesh.Scale = weaponData.scale
    end
end

local function updateUAInventory()
    pcall(function()
        local InventoryModule = require(game.ReplicatedStorage.Modules.InventoryModule)
        if type(filtergc) == "function" then
            local ok, res = pcall(function() return filtergc("table", {Keys = {"UpdateInventory"}}, true) end)
            if ok and res and res.UpdateInventory then
                local UpdateInventory = res.UpdateInventory
                for key, func in pairs(getgc()) do
                    if typeof(func) == "function" and islclosure(func) and debug.info(func, "l") == 122 and #debug.getupvalues(func) == 2 then
                        UpdateInventory(debug.getupvalue(func, 2), InventoryModule.MyInventory)
                    end
                end
            end
        end
    end)
end

function Byte.UnlockAll.SaveSelection()
    pcall(function()
        local ProfileData = require(game.ReplicatedStorage.Modules.ProfileData)
        if writefile then
            local currentKnife = ProfileData.Weapons.Equipped.Knife or "nil"
            local currentGun = ProfileData.Weapons.Equipped.Gun or "nil"
            writefile(ua_savePath, currentKnife .. "|" .. currentGun)
            ua_selectedKnife = ProfileData.Weapons.Equipped.Knife
            ua_selectedGun = ProfileData.Weapons.Equipped.Gun
        end
    end)
end

local ua_initialized = false
local ua_ignoreAutoSave = 0

function Byte.UnlockAll.Init()
    if ua_initialized then return end
    ua_initialized = true
    ua_data = getUAData()
    
    if isfile and isfile(ua_savePath) then
        local success, content = pcall(readfile, ua_savePath)
        if success and content then
            local parts = content:split("|")
            if #parts == 2 then
                ua_selectedKnife = parts[1] ~= "nil" and parts[1] or nil
                ua_selectedGun = parts[2] ~= "nil" and parts[2] or nil
            end
        end
    end

    Byte.Util.Connect(game.Workspace.ChildAdded, function(ch)
        if State.Opt.UnlockAll and ch and ch:IsA("BasePart") and ch.Name == "StuckKnife" then
            local mesh = ch:WaitForChild("Mesh", 3)
            if mesh then
                pcall(function()
                    local ProfileData = require(game.ReplicatedStorage.Modules.ProfileData)
                    local equippedKnifeName = ProfileData.Weapons.Equipped.Knife
                    local knifedata = getUAWeaponData(equippedKnifeName)
                    if knifedata then
                        mesh.MeshId = knifedata.meshid
                        mesh.TextureId = knifedata.textureid
                        mesh.Scale = knifedata.scale
                    end
                end)
            end
        end
    end)
end

function Byte.UnlockAll.Toggle(enabled, silent)
    local NotifyFn = Byte.Notify or Byte.Util.Alert
    
    if enabled then
        if not ua_data then Byte.UnlockAll.Init() end
        if not ua_data then return NotifyFn("Failed to load Unlock All data", "Error") end

        local ok, ProfileData = pcall(function() return require(game.ReplicatedStorage.Modules.ProfileData) end)
        local ok2, Sync = pcall(function() return require(game.ReplicatedStorage.Database.Sync) end)
        if not ok or not ok2 then return NotifyFn("Failed to access ProfileData", "Error") end

        if not ua_backup then
            ua_backup = {}
            for k, v in pairs(ProfileData.Weapons.Owned) do ua_backup[k] = v end
            ua_originalKnife = ProfileData.Weapons.Equipped.Knife or "Default Knife"
            ua_originalGun = ProfileData.Weapons.Equipped.Gun or "Default Gun"
        end

        for name, itemData in pairs(Sync.Weapons) do
            itemData.SortWithinGroup = itemData.SortWithinGroup or 0
            itemData.SortGroup = itemData.SortGroup or nil
            itemData.Name = itemData.Name or itemData.ItemName or name
            itemData.Rarity = itemData.Rarity or "Common"

            if Sync.Rarities[itemData.Rarity] then
                local info = getUAWeaponData(name)
                if info and info.meshid and info.textureid and info.scale and info.size then
                    ProfileData.Weapons.Owned[name] = 1
                end
            end
        end

        if ua_selectedKnife then ProfileData.Weapons.Equipped.Knife = ua_selectedKnife end
        if ua_selectedGun then ProfileData.Weapons.Equipped.Gun = ua_selectedGun end
        ua_ignoreAutoSave = os.clock() + 2

        updateUAInventory()
        if not silent then NotifyFn("Unlock All Enabled", "Success") end
    else
        local ok, ProfileData = pcall(function() return require(game.ReplicatedStorage.Modules.ProfileData) end)
        if ok and ua_backup then
            Byte.UnlockAll.SaveSelection()

            for k in pairs(ProfileData.Weapons.Owned) do
                ProfileData.Weapons.Owned[k] = ua_backup[k]
            end
            
            ProfileData.Weapons.Equipped.Knife = ua_originalKnife
            ProfileData.Weapons.Equipped.Gun = ua_originalGun
            ua_ignoreAutoSave = os.clock() + 2
            
            ua_backup = nil
            updateUAInventory()
            
            local char = LocalPlayer.Character
            if char then
                for _, tool in ipairs(char:GetChildren()) do
                    if tool:IsA("Tool") then
                        local handle = tool:FindFirstChild("Handle")
                        if handle then
                            local mesh = handle:FindFirstChildOfClass("SpecialMesh")
                            if mesh then mesh:Destroy() end
                        end
                    end
                end
            end

            if not silent then NotifyFn("Unlock All Disabled", "Success") end
        end
    end
end

function Byte.UnlockAll.Step()
    pcall(function()
        local ProfileData = require(game.ReplicatedStorage.Modules.ProfileData)
        local equippedKnifeName = ProfileData.Weapons.Equipped.Knife
        local equippedGunName = ProfileData.Weapons.Equipped.Gun

        if os.clock() > ua_ignoreAutoSave then
            if equippedKnifeName and equippedKnifeName ~= "nil" and equippedKnifeName ~= "Default Knife" and equippedKnifeName ~= ua_selectedKnife then
                ua_selectedKnife = equippedKnifeName
                if writefile then pcall(writefile, ua_savePath, tostring(equippedKnifeName) .. "|" .. tostring(equippedGunName or "nil")) end
            end
            if equippedGunName and equippedGunName ~= "nil" and equippedGunName ~= "Default Gun" and equippedGunName ~= ua_selectedGun then
                ua_selectedGun = equippedGunName
                if writefile then pcall(writefile, ua_savePath, tostring(equippedKnifeName or "nil") .. "|" .. tostring(equippedGunName)) end
            end
        end

        if not State.Opt.UnlockAll or not ua_data then return end
        
        local char = LocalPlayer.Character
        if not char then return end

        for _, tool in pairs(char:GetChildren()) do
            if tool and tool:IsA("Tool") then
                local itemType = tool:GetAttribute("ItemType")
                local Handle = tool:FindFirstChild("Handle")
                if Handle then
                    if itemType == "Knife" and equippedKnifeName then
                        local knifedata = getUAWeaponData(equippedKnifeName)
                        if knifedata then applyUAWeaponMesh(Handle, knifedata, equippedKnifeName, "Knife") end
                    elseif itemType == "Gun" and equippedGunName then
                        local gundata = getUAWeaponData(equippedGunName)
                        if gundata then applyUAWeaponMesh(Handle, gundata, equippedGunName, "Gun") end
                    end
                end
            end
        end

        local DisplayRefGun = char:FindFirstChild("DisplayRefGun")
        if DisplayRefGun and DisplayRefGun.Value and equippedGunName then
            local gundata = getUAWeaponData(equippedGunName)
            if gundata then applyUAWeaponMesh(DisplayRefGun.Value, gundata, equippedGunName) end
        end

        local DisplayRefKnife = char:FindFirstChild("DisplayRefKnife")
        if DisplayRefKnife and DisplayRefKnife.Value and equippedKnifeName then
            local knifedata = getUAWeaponData(equippedKnifeName)
            if knifedata then applyUAWeaponMesh(DisplayRefKnife.Value, knifedata, equippedKnifeName) end
        end
    end)
end

Byte.Scheduler.Jobs = {
    Tick = {
        { "Roles", Byte.Round.RefreshRoles },
        { "Cache Murderer", function()
            if State.Opt.SilentAimV2 then
                local remotes = ReplicatedStorage:FindFirstChild("Remotes")
                local extras = remotes and remotes:FindFirstChild("Extras")
                local dataRemote = extras and extras:FindFirstChild("GetPlayerData")
                if dataRemote then
                    local ok, data = pcall(dataRemote.InvokeServer, dataRemote)
                    if ok and type(data) == "table" then
                        for plrName, info in pairs(data) do
                            if info.Role == "Murderer" and not info.Dead then
                                local murd = Players:FindFirstChild(plrName)
                                State.CachedMurderer = murd and Byte.Util.Root(murd)
                                break
                            end
                        end
                    end
                end
            else
                State.CachedMurderer = nil
            end
        end },
        { "Auto Farm", Byte.Farm.Step, "AutoFarm" },
        { "Unlock All", Byte.UnlockAll.Step, "UnlockAll" },
        { "X-Ray", Byte.Visual.XRayStep, "XRay" },
        { "Movement", Byte.Movement.Apply, { "SpeedOn", "JumpOn" } },
        { "Auto Grab Gun", Byte.Sheriff.AutoGrabStep, "AutoGrabGun" },
        { "Auto Shoot", Byte.Sheriff.AutoShootStep, "AutoShoot" },
        { "Auto Kill All", Byte.Murderer.AutoKillStep, "AutoKillAll" },
        { "Role ESP", Byte.Esp.RefreshPlayers, "EspPlayers" },
        { "Gun ESP", Byte.Esp.RefreshGun, "EspGun" },
    },
    Stepped = { { "Anti Fling", Byte.Movement.AntiFlingStep, "AntiFling" } },
    Render = { { "Aimbot", Byte.Aim.Step, "Aimbot" } },
    Heartbeat = { { "Kill Aura", Byte.Murderer.KillAuraStep, "KillAura" } },
}

function Byte.Scheduler.OnToggles(job)
    local on = {}
    if not Byte.Library or job[3] == nil then return on end
    for _, idx in ipairs(type(job[3]) == "table" and job[3] or { job[3] }) do
        local toggle = Byte.Library.Toggles[idx]
        if toggle and toggle.Value then on[#on + 1] = toggle end
    end
    return on
end

function Byte.Scheduler.Halt(job, err)
    local reason = tostring(err):match("^[^\n]*")
    job.Streak = nil
    if #Byte.Scheduler.OnToggles(job) == 0 then
        job.Stopped = true
        warn("[Byte] " .. job[1] .. " paused until turned on:", reason)
        return
    end
    job.Halting = true
    warn("[Byte] " .. job[1] .. " stopped:", reason)
    table.insert(State.Halted, { job, reason })
end

function Byte.Scheduler.Run(job, ...)
    if job.Halting then return end
    if job.Stopped then
        if #Byte.Scheduler.OnToggles(job) == 0 then return end
        job.Stopped = nil
    end
    local ok, err = pcall(job[2], ...)
    if ok then
        job.Streak = nil
        return
    end
    local streak = job.Streak
    if not streak then
        streak = { count = 0, since = os.clock() }
        job.Streak = streak
        warn("[Byte] " .. job[1] .. ":", err)
    end
    streak.count += 1
    if job[3] == nil or streak.count < Config.JobFailLimit or os.clock() - streak.since < Config.JobFailWindow then return end
    Byte.Scheduler.Halt(job, err)
end

function Byte.Scheduler.RunLane(lane, ...)
    for _, job in ipairs(Byte.Scheduler.Jobs[lane]) do
        Byte.Scheduler.Run(job, ...)
    end
end

function Byte.Scheduler.Boot(_notify)
    Byte.Esp.Init()
    Byte.Farm.InitBagTracking()
    Byte.UnlockAll.Init()
    
    Byte.Util.Connect(LocalPlayer.CharacterAdded, function()
        task.wait(0.5)
        if State.Opt.Invisible then
            Byte.Movement.SetInvis(true)
        end
    end)
    Byte.Util.Connect(RunService.Stepped, function() Byte.Scheduler.RunLane("Stepped") end)
    Byte.Movement.InitInfJump()
    Byte.Session.InitAntiAfk()
    Byte.Util.Connect(RunService.RenderStepped, function(dt) Byte.Scheduler.RunLane("Render", dt) end)
    Byte.Util.Connect(RunService.Heartbeat, function() Byte.Scheduler.RunLane("Heartbeat") end)
    task.spawn(function()
        while State.Alive do
            Byte.Scheduler.RunLane("Tick")
            task.wait(Config.TickDelay)
        end
    end)
end

function Byte.Scheduler.Stop()
    if not State.Alive then return end
    State.Alive = false
    getgenv().ByteUnload = nil
    
    pcall(Byte.Sheriff.SyncAimHook)
    
    for _, conn in ipairs(State.Conns) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(State.Conns)

    pcall(Byte.Movement.SetFly, false)
    pcall(Byte.Movement.SetNoclip, false)
    pcall(Byte.Movement.SetInvis, false)
    pcall(Byte.Farm.DetachMover)
    
    pcall(function()
        if State.Opt.SpeedOn then Byte.Movement.RestoreSpeed() end
        if State.Opt.JumpOn then Byte.Movement.RestoreJump() end
    end)

    pcall(Byte.Visual.SetFullbright, false)
    pcall(Byte.Visual.ClearXRay)
    
    pcall(function()
        if State.Opt.UnlockAll then Byte.UnlockAll.Toggle(false, true) end
    end)
    
    pcall(Byte.Esp.Destroy)

    Byte.Library = nil
    Byte.ThemeManager = nil
    Byte.SaveManager = nil
    Byte.Notify = nil
    table.clear(State.Halted)
end

local function BuildInterface()
    local bundle = Byte.Util.LoadLibrary()
    if not bundle then return false end

    local Library = bundle.Library
    local ThemeManager = bundle.Themes
    local SaveManager = bundle.Save
    Byte.Library = Library
    Byte.ThemeManager = ThemeManager
    Byte.SaveManager = SaveManager

    local Window = Library:CreateWindow({
        Title = "Byte",
        Size = Vector2.new(720, 480),
        Layout = "Bottom bar",
        MenuKey = Enum.KeyCode.RightShift,
        NotificationPosition = "BottomRight",
    })

    local opt = State.Opt

    local function Notify(text, kind)
        local icon = "info"
        if kind == "Success" then icon = "check"
        elseif kind == "Warning" then icon = "alert-triangle"
        elseif kind == "Error" then icon = "x"
        end
        pcall(function()
            Window:Notify({ Title = "Byte", Content = tostring(text), Icon = icon })
        end)
    end
    Byte.Notify = Notify

    local function Bind(idx)
        return function(value) opt[idx] = value end
    end

    local function AimHookBind(idx)
        return function(value)
            opt[idx] = value
            Byte.Sheriff.SyncAimHook()
        end
    end

    local function Picked(idx)
        local optObj = Library.Options[idx]
        if optObj and optObj.Value ~= nil then opt[idx] = optObj.Value end
        return opt[idx]
    end

    local function FlingAsync(target)
        if target then task.spawn(Byte.Troll.Fling, target) end
    end

    local MainTab = Window:AddTab("Main", "house")
    local farmBox = MainTab:AddLeftGroupbox("Farm", "coins")
    farmBox:AddToggle("AutoFarm", {
        Text = "Auto Farm Coins",
        Default = false,
        Callback = Bind("AutoFarm"),
    }):AddKeyPicker("AutoFarmKey", { Default = "None", Mode = "Toggle" })
    farmBox:AddSlider("FarmSpeed", {
        Text = "Speed",
        Min = 16, Max = Config.FarmSpeedMax, Default = Config.FarmSpeed, Rounding = 0,
        Callback = function(value) opt.FarmSpeed = tonumber(value) or Config.FarmSpeed end,
    })
    farmBox:AddToggle("ResetWhenFull", {
        Text = "Reset At Bag Full",
        Default = false,
        Callback = Bind("ResetWhenFull"),
    })
    local bagLabel = farmBox:AddLabel("Bag: 0 / 0")

    local skinBox = MainTab:AddRightGroupbox("Skin Unlocker", "shirt")
    skinBox:AddToggle("UnlockAll", {
        Text = "Unlock All Skins",
        Default = false,
        Callback = function(value)
            opt.UnlockAll = value
            task.spawn(function() Byte.UnlockAll.Toggle(value) end)
        end,
    })

    task.spawn(function()
        while State.Alive do
            pcall(function()
                local text
                if State.Bag.Max > 0 then
                    text = string.format("Bag: %d / %d", State.Bag.Current, State.Bag.Max)
                else
                    text = string.format("Bag: %d / ?", State.Bag.Current)
                end
                bagLabel:SetText(text)
            end)
            task.wait(0.5)
        end
    end)

    local CombatTab = Window:AddTab("Combat", "crosshair")

    local sheriffBox = CombatTab:AddLeftGroupbox("Sheriff", "shield")
    sheriffBox:AddToggle("SilentAim", {
        Text = "Silent Aim",
        Default = false,
        Callback = AimHookBind("SilentAim"),
    }):AddKeyPicker("SilentAimKey", { Default = "None", Mode = "Toggle" })
    sheriffBox:AddToggle("SilentAimV2", {
        Text = "Wall Bang",
        Default = false,
        Callback = AimHookBind("SilentAimV2"),
    }):AddKeyPicker("SilentAimV2Key", { Default = "None", Mode = "Toggle" })
    sheriffBox:AddToggle("AutoShoot", {
        Text = "Auto Kill Murderer",
        Default = false,
        Callback = Bind("AutoShoot"),
    }):AddKeyPicker("AutoShootKey", { Default = "None", Mode = "Toggle" })
    sheriffBox:AddButton({
        Text = "Kill Murderer Now",
        Callback = function()
            local ok, detail = Byte.Sheriff.ShootMurderer()
            Notify(ok and ("Shot " .. tostring(detail)) or tostring(detail or "You need the gun"), ok and "Success" or "Warning")
        end,
    })
    sheriffBox:AddToggle("AutoGrabGun", {
        Text = "Auto Tp to Gun",
        Default = false,
        Callback = Bind("AutoGrabGun"),
    }):AddKeyPicker("AutoGrabGunKey", { Default = "None", Mode = "Toggle" })
    sheriffBox:AddButton({
        Text = "Tp To Gun Now",
        Callback = function()
            local got = Byte.Sheriff.GrabGun()
            Notify(got and "Gun grabbed" or "No gun on the ground", got and "Success" or "Warning")
        end,
    })

    local murdererBox = CombatTab:AddRightGroupbox("Murderer", "sword")
    murdererBox:AddToggle("AutoKillAll", {
        Text = "Auto Kill All",
        Default = false,
        Callback = Bind("AutoKillAll"),
    }):AddKeyPicker("AutoKillAllKey", { Default = "None", Mode = "Toggle" })
    murdererBox:AddButton({
        Text = "Kill All Now",
        Callback = function()
            task.spawn(function()
                Notify(string.format("Killed %d players", Byte.Murderer.KillAll()))
            end)
        end,
    })
    murdererBox:AddToggle("KillAura", {
        Text = "Kill Aura",
        Default = false,
        Callback = Bind("KillAura"),
    }):AddKeyPicker("KillAuraKey", { Default = "None", Mode = "Toggle" })
    murdererBox:AddToggle("KnifeAim", {
        Text = "Knife Throw Aim",
        Default = false,
        Callback = AimHookBind("KnifeAim"),
    })

    local aimBox = CombatTab:AddRightGroupbox("Aimbot", "crosshair")
    aimBox:AddToggle("Aimbot", {
        Text = "Aimbot",
        Default = false,
        Callback = Bind("Aimbot"),
    }):AddKeyPicker("AimbotKey", { Default = "Q", Mode = "Hold" })
    aimBox:AddSlider("AimSmooth", {
        Text = "Smoothness",
        Min = 0, Max = 95, Default = opt.AimSmooth, Rounding = 0, Suffix = "%",
        Callback = function(value) opt.AimSmooth = tonumber(value) or 0 end,
    })

    local PlayerTab = Window:AddTab("Player", "user")

    local targetBox = PlayerTab:AddLeftGroupbox("Target", "target")
    targetBox:AddDropdown("TrollTarget", {
        Text = "Player",
        SpecialType = "Player",
        Searchable = true,
        Callback = function(value) opt.TrollTarget = value end,
    })
    targetBox:AddButton({
        Text = "Fling",
        Callback = function()
            Picked("TrollTarget")
            FlingAsync(Byte.Troll.Target())
        end,
    })
    targetBox:AddButton({
        Text = "Fling Murderer",
        Callback = function()
            FlingAsync(Byte.Round.FindByRole("Murderer"))
        end,
    })
    targetBox:AddButton({
        Text = "Fling Everyone",
        DoubleClick = true,
        Callback = function()
            task.spawn(function()
                for _, player in ipairs(Players:GetPlayers()) do
                    if player == LocalPlayer or not Byte.Util.Root(player) then continue end
                    Byte.Troll.Fling(player)
                end
            end)
        end,
    })

    local moveBox = PlayerTab:AddLeftGroupbox("Movement", "footprints")
    moveBox:AddToggle("SpeedOn", {
        Text = "Walk Speed",
        Default = false,
        Callback = function(value)
            opt.SpeedOn = value
            if not value then Byte.Movement.RestoreSpeed() end
        end,
    })
    moveBox:AddSlider("WalkSpeed", {
        Text = "Speed",
        Min = 16, Max = 120, Default = opt.WalkSpeed, Rounding = 0,
        Callback = function(value) opt.WalkSpeed = tonumber(value) or Config.SpeedDefault end,
    })
    moveBox:AddToggle("JumpOn", {
        Text = "Jump Power",
        Default = false,
        Callback = function(value)
            opt.JumpOn = value
            if not value then Byte.Movement.RestoreJump() end
        end,
    })
    moveBox:AddSlider("JumpPower", {
        Text = "Power",
        Min = 50, Max = 200, Default = opt.JumpPower, Rounding = 0,
        Callback = function(value) opt.JumpPower = tonumber(value) or Config.JumpDefault end,
    })

    local extraBox = PlayerTab:AddRightGroupbox("Extra", "sparkles")
    extraBox:AddToggle("AntiFling", {
        Text = "Anti Fling",
        Default = false,
        Callback = Bind("AntiFling"),
    })
    extraBox:AddToggle("InfJump", {
        Text = "Infinite Jump",
        Default = false,
        Callback = Bind("InfJump"),
    })
    extraBox:AddToggle("Noclip", {
        Text = "Noclip",
        Default = false,
        Callback = function(value)
            opt.Noclip = value
            Byte.Movement.RefreshNoclip()
        end,
    }):AddKeyPicker("NoclipKey", { Default = "None", Mode = "Toggle" })
    extraBox:AddToggle("Fly", {
        Text = "Fly",
        Default = false,
        Callback = function(value)
            opt.Fly = value
            Byte.Movement.SetFly(value)
        end,
    }):AddKeyPicker("FlyKey", { Default = "None", Mode = "Toggle" })
    extraBox:AddToggle("Invisible", {
        Text = "Invisibility",
        Default = false,
        Callback = function(value)
            Byte.Movement.SetInvis(value)
        end,
    }):AddKeyPicker("InvisKey", { Default = "None", Mode = "Toggle" })

    local VisualTab = Window:AddTab("Visuals", "eye")
    local espBox = VisualTab:AddLeftGroupbox("ESP", "scan-eye")
    espBox:AddToggle("EspPlayers", {
        Text = "Role ESP",
        Default = false,
        Callback = Bind("EspPlayers"),
    })
    espBox:AddToggle("EspGun", {
        Text = "Gun Drop ESP",
        Default = false,
        Callback = Bind("EspGun"),
    })

    local worldBox = VisualTab:AddRightGroupbox("World", "globe")
    worldBox:AddToggle("XRay", {
        Text = "X-Ray",
        Default = false,
        Callback = Bind("XRay"),
    })
    worldBox:AddToggle("Fullbright", {
        Text = "Fullbright",
        Default = false,
        Callback = function(value)
            opt.Fullbright = value
            Byte.Visual.SetFullbright(value)
        end,
    })
    worldBox:AddToggle("AntiAfk", {
        Text = "Anti AFK",
        Default = false,
        Callback = Bind("AntiAfk"),
    })

    if ThemeManager then
        pcall(function()
            ThemeManager:SetLibrary(Library)
            ThemeManager:SetFolder(Config.SaveFolder)
        end)
    end
    if SaveManager then
        pcall(function()
            SaveManager:SetLibrary(Library)
            SaveManager:SetFolder(Config.SaveFolder)
        end)
    end

    pcall(function()
        local settings = Window:CreateSettingsTab()
        if ThemeManager then
            ThemeManager:ApplyToTab(settings)
            ThemeManager:LoadDefault()
        end
        if SaveManager then
            SaveManager:BuildConfigSection(settings)
            SaveManager:LoadAutoloadConfig()
        end

        local unloadBox = settings:AddLeftGroupbox("Session", "power")
        unloadBox:AddButton({
            Text = "Unload Byte",
            DoubleClick = true,
            Callback = function()
                if getgenv().ByteUnload then
                    getgenv().ByteUnload()
                end
            end,
        })
    end)

    local originalUnload = Library.Unload
    Library.Unload = function(...)
        pcall(Byte.Scheduler.Stop)
        return originalUnload(...)
    end

    getgenv().ByteUnload = function()
        pcall(function() Library:Unload() end)
    end

    local function ReportHalts()
        while #State.Halted > 0 do
            local halt = table.remove(State.Halted, 1)
            local job = halt[1]
            for _, toggle in ipairs(Byte.Scheduler.OnToggles(job)) do
                toggle:SetValue(false)
            end
            job.Halting = nil
            Notify(job[1] .. " stopped: " .. halt[2], "Warning")
        end
    end

    task.spawn(function()
        while State.Alive do
            ReportHalts()
            task.wait(Config.StatusRefresh)
        end
    end)

    pcall(function() Byte.Scheduler.Boot(Notify) end)
    Notify("Loaded", "Success")
    return true
end

if getgenv().ByteUnload then
    pcall(getgenv().ByteUnload)
end

if BuildInterface() then
end
