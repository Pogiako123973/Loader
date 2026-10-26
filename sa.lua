if not game:IsLoaded() then
    game.Loaded:Wait()
end

if not LPH_OBFUSCATED then
    LPH_JIT, LPH_JIT_MAX, LPH_NO_VIRTUALIZE = function(fn) return fn end, function(fn) return fn end, function(fn) return fn end
end

local environment = getgenv and getgenv() or _G
if type(environment.ByteUnload) == "function" then
    pcall(environment.ByteUnload)
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local osClock = os.clock

local Byte = setmetatable({}, {
    __newindex = function(self, key, value)
        rawset(self, key, value)
    end,
})

Byte.Config = {
    UiSource = "https://raw.githubusercontent.com/viseamn/Visual/main/Library.lua",
    ThemeSource = "https://raw.githubusercontent.com/viseamn/Visual/main/ThemeManager.lua",
    SaveSource = "https://raw.githubusercontent.com/viseamn/Visual/main/SaveManager.lua",
    SaveFolder = "Byte",
    LoadTimeout = 10,
    AlertTries = 20,
    AlertGap = 0.5,
    RequireTimeout = 5,
    RequireBudget = 15,
    MaxFails = 5,
    FailWindow = 10,
    FovColor = Color3.fromRGB(232, 160, 76),
    CombatToggles = { "Aimbot", "SilentAim", "Ragebot", "TriggerBot", "NoRecoil", "NoSpread", "InstantScope" },
    ModuleFeatures = {
        EntityService = { "Aimbot", "SilentAim", "Ragebot", "TriggerBot" },
        CombatService = { "SilentAim", "Ragebot", "TriggerBot", "NoRecoil", "NoSpread", "InstantScope" },
        CameraController = { "SilentAim", "Ragebot" },
        WeaponConfig = { "UnlockAllSkins" },
        GachaService = { "AutoOpenCases" },
        WeaponService = { "AutoSell" },
        QuestService = { "AutoClaimQuest" },
        GameService = { "FastRespawn" },
    },
    SkinMainRows = 4,
    SkinGroupRows = 3,
    EconomyInterval = 1,
    JoinText = "Touch to Join",
    JoinRange = 400,
    JoinRetry = 3,
    StatusInterval = 1,
    OpenDelay = 0.6,
    ClaimDelay = 0.5,
    FireInterval = 0.12,
    LookSettle = 0.1,
    TriggerRange = 2000,
    EspInterval = 0.15,
    EspGrace = 1,
    ResultWait = 3,
    AimRenderPriority = Enum.RenderPriority.Camera.Value + 5,
}

Byte.State = {
    Alive = true,
    Connections = {},
    Halted = {},
    Notices = {},
    EspSnapshot = {},
}

Byte.Options = {
    AntiAfk = false,

    InfiniteDash = false,
    FastRespawn = false,
    AutoJoin = false,
    SkinChanger = false,
    SkinRarities = {},

    AutoOpenCases = false,
    OpenCount = 1,
    AutoSell = false,
    SellRarities = {},
    MaxSellPrice = 500,
    KeepPerRarity = 0,
    AutoClaimQuest = false,

    Aimbot = false,
    SilentAim = false,
    Ragebot = false,
    InstantScope = false,
    HitChance = 100,
    HeadChance = 100,
    TriggerBot = false,
    NoRecoil = false,
    NoSpread = false,
    AimTeamCheck = true,
    AimWallCheck = true,
    AimSmooth = 1,
    AimPrediction = 60,
    ShowFov = false,
    AimFov = 150,
    AimPriority = "Crosshair",
    AimMaxDistance = 1000,
    AimBone = "Head",
}

Byte.Util = {}
local Util = Byte.Util

local function Resolve(...)
    for index = 1, select("#", ...) do
        local candidate = select(index, ...)
        if type(candidate) == "function" then
            return candidate
        end
    end
    return nil
end

Util.Request = Resolve(request, http_request, syn and syn.request, http and http.request)
Util.SetClipboard = Resolve(setclipboard, toclipboard)
Util.GetHui = Resolve(gethui, get_hidden_gui)
Util.GetUpvalue = Resolve(getupvalue, debug.getupvalue)
Util.GetUpvalues = Resolve(getupvalues, debug.getupvalues)
Util.GetRawMetatable = Resolve(getrawmetatable)

Byte.Probes = {}

function Byte.Probes.LookSpoof()
    if not (Util.GetRawMetatable and Util.GetUpvalues) then return false end
    local marker, meta = {}, { __metatable = "locked" }
    local proxy = setmetatable({}, meta)
    local function Holder() return marker end

    local ok, found = pcall(function()
        if Util.GetRawMetatable(proxy) ~= meta then return false end
        for _, value in pairs(Util.GetUpvalues(Holder)) do
            if value == marker then return true end
        end
        return false
    end)
    return ok and found == true
end

Byte.Caps = setmetatable({}, {
    __index = function(caps, name)
        local probe = Byte.Probes[name]
        if probe then
            local has = probe()
            rawset(caps, name, has)
            return has
        end
        local lib = Byte.Library
        if not (lib and lib.Compat) then return false end
        return lib.Compat.Caps[name] == true
    end,
})

function Util.HttpGet(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then
        return body
    end
    if not Util.Request then
        error("HttpGet failed: " .. url)
    end

    local sent, response = pcall(Util.Request, { Url = url, Method = "GET" })
    if not sent then error(response) end
    local status = type(response) == "table" and tonumber(response.StatusCode) or nil
    if status == 200 and type(response.Body) == "string" then
        return response.Body
    end
    error("HttpGet " .. url .. ": status " .. tostring(status))
end

function Util.Alert(text, detail)
    warn("[Byte] menu: " .. tostring(detail or text))
    task.spawn(function()
        local lib = Byte.Library
        for _ = 1, Byte.Config.AlertTries do
            if lib and lib.Notify then
                local ok = pcall(lib.Notify, lib, "Byte", text)
                if ok then return end
            end
            local shown = pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
                Title = "Byte",
                Text = tostring(text),
                Duration = 10,
            })
            if shown then return end
            task.wait(Byte.Config.AlertGap)
        end
    end)
end

function Util.LoadViz()
    local okLib, libSrc = pcall(Util.HttpGet, Byte.Config.UiSource)
    if not okLib or type(libSrc) ~= "string" then
        Util.Alert("Could not download the menu. Check your connection and run again.", libSrc)
        return nil
    end
    local chunk, problem = loadstring(libSrc)
    if type(chunk) ~= "function" then
        Util.Alert("The menu failed to load on this executor: " .. tostring(problem))
        return nil
    end
    local ran, lib = pcall(chunk)
    if not ran or type(lib) ~= "table" then
        Util.Alert("The menu failed to load on this executor: " .. tostring(lib))
        return nil
    end

    local theme, save
    local okTheme, themeSrc = pcall(Util.HttpGet, Byte.Config.ThemeSource)
    if okTheme and type(themeSrc) == "string" then
        local c = loadstring(themeSrc)
        if c then local ok, r = pcall(c) if ok then theme = r end end
    end
    local okSave, saveSrc = pcall(Util.HttpGet, Byte.Config.SaveSource)
    if okSave and type(saveSrc) == "string" then
        local c = loadstring(saveSrc)
        if c then local ok, r = pcall(c) if ok then save = r end end
    end
    return lib, theme, save
end

function Util.Try(label, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[Byte] " .. label .. ": " .. tostring(err))
    end
    return ok
end

function Util.Copy(text)
    if Util.SetClipboard then
        Util.SetClipboard(text)
        return true
    end
    return false
end

function Util.Overlay()
    local screen = Byte.State.Overlay
    if screen and screen.Parent then return screen end

    screen = Instance.new("ScreenGui")
    screen.Name = "ByteOverlay"
    screen.IgnoreGuiInset = true
    screen.ResetOnSpawn = false
    screen.DisplayOrder = 50
    local mounts = { function() return game:GetService("CoreGui") end }
    if Util.GetHui then table.insert(mounts, 1, Util.GetHui) end
    for _, mount in ipairs(mounts) do
        if pcall(function() screen.Parent = mount() end) and screen.Parent then break end
    end
    if not screen.Parent then
        screen.Parent = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", Byte.Config.LoadTimeout)
    end
    Byte.State.Overlay = screen
    return screen
end

function Util.SortedKeys(map)
    local keys = {}
    for key in pairs(map or {}) do
        keys[#keys + 1] = tostring(key)
    end
    table.sort(keys)
    return keys
end

function Util.SetFromList(list)
    local set = {}
    for key, value in pairs(list or {}) do
        if type(key) == "number" then
            set[value] = true
        elseif value then
            set[key] = true
        end
    end
    return set
end

function Byte:Connect(signal, handler)
    local connection = signal:Connect(handler)
    table.insert(self.State.Connections, connection)
    return connection
end

Byte.GameLib = { Config = {}, Service = {}, Missing = {}, LoadEnds = nil }
local GameLib = Byte.GameLib

function GameLib.RequireWithin(module, asGame)
    local done, ok, loaded = false, false, nil
    task.spawn(function()
        if asGame then
            pcall(setthreadidentity, 2)
            local read, identity = pcall(getthreadidentity)
            if not (read and identity == 2) then
                done = true
                return
            end
        end
        ok, loaded = pcall(require, module)
        done = true
    end)

    local deadline = osClock() + Byte.Config.RequireTimeout
    if GameLib.LoadEnds then deadline = math.min(deadline, GameLib.LoadEnds) end
    while not done and osClock() < deadline do
        task.wait()
    end
    return done, ok, loaded
end

function GameLib.Require(module)
    if GameLib.LoadEnds and osClock() >= GameLib.LoadEnds then
        GameLib.Missing[module.Name] = true
        warn("[Byte] require " .. module.Name .. ": load budget spent")
        return nil
    end

    local finished, ok, loaded = GameLib.RequireWithin(module, false)
    if ok then return loaded end
    if finished then
        local _, again, retried = GameLib.RequireWithin(module, true)
        if again then return retried end
    end
    GameLib.Missing[module.Name] = true
    warn("[Byte] require " .. module.Name .. ": " .. (finished and tostring(loaded) or "timed out"))
    return nil
end

local function RequireChild(parent, name)
    local child = parent and parent:FindFirstChild(name)
    if not (child and child:IsA("ModuleScript")) then
        child = ReplicatedStorage:FindFirstChild(name, true)
    end
    if not (child and child:IsA("ModuleScript")) then
        GameLib.Missing[name] = "Absent"
        warn("[Byte] module " .. name .. " not found, features that need it are blocked")
        return nil
    end
    return GameLib.Require(child)
end

do
    local configFolder = ReplicatedStorage:FindFirstChild("Config")
    local remoteFolder = ReplicatedStorage:FindFirstChild("Remote")
    local constantFolder = ReplicatedStorage:FindFirstChild("Constant")
    GameLib.LoadEnds = osClock() + Byte.Config.RequireBudget

    for _, name in ipairs({ "WeaponConfig", "WrapConfig", "QuestConfig" }) do
        GameLib.Config[name] = RequireChild(configFolder, name)
    end
    GameLib.RarityColor = RequireChild(constantFolder, "RarityColor")

    local serviceNames = {
        "StatusService", "GachaService", "WeaponService", "QuestService", "EntityService",
        "CombatService", "GameService",
    }
    for _, name in ipairs(serviceNames) do
        GameLib.Service[name] = RequireChild(remoteFolder, name)
    end
    GameLib.CameraController = RequireChild(ReplicatedStorage:FindFirstChild("Client"), "CameraController")
    GameLib.WeaponController = RequireChild(ReplicatedStorage:FindFirstChild("Client"), "WeaponController")
    local gameService = remoteFolder and remoteFolder:FindFirstChild("GameService")
    GameLib.RoomManager = RequireChild(gameService, "RoomManager")
    GameLib.Status = RequireChild(constantFolder, "Status")
    GameLib.LoadEnds = nil
end

Byte.Player = { Client = LocalPlayer }

function Byte.Player:Bind(character)
    self.Character = character
    self.Humanoid = character:WaitForChild("Humanoid", Byte.Config.LoadTimeout)
    self.Root = character:WaitForChild("HumanoidRootPart", Byte.Config.LoadTimeout)
end

function Byte.Player:IsAlive()
    return self.Humanoid ~= nil and self.Humanoid.Health > 0 and self.Root ~= nil and self.Root.Parent ~= nil
end

function Byte.Player:Coin()
    local service = GameLib.Service.StatusService
    if not service then return nil end
    local key = GameLib.Status and GameLib.Status.Eco_Coin or "Eco_Coin"
    local ok, value = pcall(function() return service.GetStatus(key) end)
    return ok and tonumber(value) or nil
end

Byte.Entity = {}

function Byte.Entity.Service()
    return GameLib.Service.EntityService
end

function Byte.Entity.List()
    local service = Byte.Entity.Service()
    if not service then return {} end
    local ok, focused = pcall(function() return service.WorldManager:GetFocusedEntities() end)
    if not ok or type(focused) ~= "table" then return {} end
    return focused._items or focused.Items or focused
end

function Byte.Entity.Local()
    local service = Byte.Entity.Service()
    if not service then return nil end
    local ok, entity = pcall(function() return service.GetLocalEntity() end)
    if ok and entity then return entity end
    ok, entity = pcall(function() return service:GetLocalEntity() end)
    return ok and entity or nil
end

local function TryCall(object, method)
    if type(object) ~= "table" and typeof(object) ~= "Instance" then return nil, false end
    local call = object[method]
    if type(call) ~= "function" then return nil, false end
    local ok, value = pcall(call, object)
    if ok then return value, true end
    return nil, false
end

function Byte.Entity.IsLocal(entity)
    local value, called = TryCall(entity, "IsLocalEntity")
    if called then return value == true end
    return entity == Byte.Entity.Local()
end

function Byte.Entity.Team(entity)
    local inst = entity and entity.Instance
    if typeof(inst) == "Instance" then
        local team = inst:GetAttribute("Team")
        if team ~= nil then return tostring(team) end
    end
    local char = Byte.Entity.Character(entity)
    local team = char and char:GetAttribute("Team")
    return team ~= nil and tostring(team) or nil
end

function Byte.Entity.Friendly(entity)
    local char = Byte.Entity.Character(entity)
    local marks = Workspace:FindFirstChild("Highlight")
    if char and marks then
        local friendly = marks:FindFirstChild("Friendly")
        if friendly and char:IsDescendantOf(friendly) then return true end
        if char:IsDescendantOf(marks) then return false end
    end

    if Byte.Match.ModeSet() ~= "TDM" then return false end
    local mine = Byte.Entity.Team(Byte.Entity.Local())
    local theirs = Byte.Entity.Team(entity)
    return mine ~= nil and mine == theirs
end

function Byte.Entity.Health(entity)
    if not entity then return 0, 0 end
    local health = entity.Health or select(1, TryCall(entity, "GetHealth")) or 0
    local maxHealth = entity.MaxHealth or select(1, TryCall(entity, "GetMaxHealth")) or 0
    return health, maxHealth
end

function Byte.Entity.Character(entity)
    local humanoid = entity and entity.Humanoid
    if humanoid and humanoid.Parent then return humanoid.Parent end
    return entity and entity.Character or nil
end

function Byte.Entity.Root(entity)
    local character = Byte.Entity.Character(entity)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head") or character.PrimaryPart
end

Byte.Match = {}

function Byte.Match.Info()
    local rooms = GameLib.RoomManager
    local ok, room = pcall(function() return rooms and rooms.GetFocusedRoom() end)
    if not ok or type(room) ~= "table" then return nil, nil end
    return room.Mode, room.Map
end

function Byte.Match.ModeSet()
    local rooms = GameLib.RoomManager
    local ok, room = pcall(function() return rooms and rooms.GetFocusedRoom() end)
    return ok and type(room) == "table" and room.ModeSet or nil
end

function Byte.Match.InRound()
    return LocalPlayer:GetAttribute("combatPaused") == false
end

Byte.Faults = { Streaks = {}, Said = {} }

function Byte.Faults.Say(name, err)
    local text, now = tostring(err), osClock()
    local last = Byte.Faults.Said[name]
    if last and last[1] == text and now - last[2] < Byte.Config.FailWindow then return end
    Byte.Faults.Said[name] = { text, now }
    warn("[Byte] " .. name .. ": " .. text)
end

function Byte.Faults.Clear(name)
    Byte.Faults.Streaks[name] = nil
end

function Byte.Faults.Wanted(toggles)
    for _, key in ipairs(toggles) do
        if Byte.Options[key] then return true end
    end
    return false
end

function Byte.Faults.Stop(name, err, toggles, restore)
    warn("[Byte] " .. name .. " stopped: " .. tostring(err))
    for _, key in ipairs(toggles) do
        Byte.Options[key] = false
    end
    if restore then Util.Try(name .. " restore", restore) end
    table.insert(Byte.State.Halted, { name, tostring(err):match("^[^\n]*"), toggles })
end

function Byte.Faults.Report(name, err, toggles, restore)
    local now = osClock()
    local streak = Byte.Faults.Streaks[name]
    if not streak or (streak.Halted and Byte.Faults.Wanted(toggles)) then
        streak = { Count = 0, First = now, Warned = false, Halted = false }
        Byte.Faults.Streaks[name] = streak
    end
    streak.Count += 1
    if streak.Count == 1 then Byte.Faults.Say(name, err) end
    if streak.Warned then return streak.Halted end
    if streak.Count < Byte.Config.MaxFails or now - streak.First < Byte.Config.FailWindow then return false end

    streak.Warned = true
    if #toggles == 0 then
        warn("[Byte] " .. name .. " keeps failing: " .. tostring(err))
        return false
    end
    streak.Halted = true
    Byte.Faults.Stop(name, err, toggles, restore)
    return true
end

Byte.Scheduler = { Jobs = {}, Booted = false }

function Byte.Scheduler.Every(name, interval, work, toggles, restore)
    Byte.Scheduler.Jobs[name] = { Interval = interval, Fn = work, Last = 0, Running = false, Toggles = toggles or {}, Restore = restore }
end

function Byte.Scheduler.Revive(name, job)
    if not Byte.Faults.Wanted(job.Toggles) then return false end
    job.Halted = false
    Byte.Faults.Clear(name)
    return true
end

function Byte.Scheduler.Settle(name, job)
    local err = job.Error
    job.Error = nil
    if err then
        job.Halted = Byte.Faults.Report(name, err, job.Toggles, job.Restore)
    else
        Byte.Faults.Clear(name)
    end
end

function Byte.Scheduler.Step()
    if not Byte.State.Alive then return end
    local now = osClock()
    for name, job in pairs(Byte.Scheduler.Jobs) do
        if job.Running then continue end
        if job.Error ~= nil then Byte.Scheduler.Settle(name, job) end
        if job.Halted and not Byte.Scheduler.Revive(name, job) then continue end
        if now - job.Last < job.Interval then continue end

        job.Last = now
        job.Running = true
        task.spawn(function()
            local ok, err = pcall(job.Fn)
            job.Error = (not ok) and tostring(err) or false
            job.Running = false
        end)
    end
end

function Byte.Scheduler.Boot()
    if Byte.Scheduler.Booted then return end
    Byte.Scheduler.Booted = true
    Byte:Connect(RunService.Heartbeat, Byte.Scheduler.Step)
end

Byte.Player.AntiAfk = { Connection = nil, Status = "Off" }

function Byte.Player.AntiAfk.OnIdled()
    if not Byte.Options.AntiAfk then return end
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.zero)
end

function Byte.Player.AntiAfk.Start()
    Byte.Options.AntiAfk = true
    if not Byte.Player.AntiAfk.Connection then
        Byte.Player.AntiAfk.Connection = Byte:Connect(LocalPlayer.Idled, Byte.Player.AntiAfk.OnIdled)
    end
    Byte.Player.AntiAfk.Status = "Armed"
end

function Byte.Player.AntiAfk.Stop()
    Byte.Options.AntiAfk = false
    local conn = Byte.Player.AntiAfk.Connection
    Byte.Player.AntiAfk.Connection = nil
    if conn then conn:Disconnect() end
    Byte.Player.AntiAfk.Status = "Off"
end

function Byte.Player.AntiAfk.GetStatus()
    return Byte.Player.AntiAfk.Status
end

Byte.Player.Respawn = { Status = "Off", Count = 0, Fired = false }

function Byte.Player.Respawn.IsDead()
    local state = LocalPlayer:GetAttribute("State")
    if state == "Dead" or state == "Died" then return true end
    local hum = Byte.Player.Humanoid
    return hum ~= nil and hum.Health <= 0
end

function Byte.Player.Respawn.Fire()
    local gameService = Byte.GameLib.Service.GameService
    if gameService then
        if type(gameService.FastRespawn) == "function" then
            pcall(gameService.FastRespawn, gameService)
            return
        end
        if type(gameService.Respawn) == "function" then
            pcall(gameService.Respawn, gameService)
            return
        end
    end
    local folder = ReplicatedStorage:FindFirstChild("Remote")
    local service = folder and folder:FindFirstChild("GameService")
    local remote = service and service:FindFirstChild("Respawn")
    if remote and remote:IsA("RemoteEvent") then remote:FireServer() end
end

function Byte.Player.Respawn.Reset()
    Byte.Player.Respawn.Fired = false
end

function Byte.Player.Respawn.Step()
    local respawn = Byte.Player.Respawn
    if not Byte.Options.FastRespawn then
        respawn.Status = "Off"
        return
    end
    if not respawn.IsDead() then
        respawn.Fired = false
        respawn.Status = "Alive · respawns " .. respawn.Count
        return
    end

    respawn.Status = "Respawning"
    if respawn.Fired then return end
    respawn.Fired = true
    respawn.Count += 1
    respawn.Fire()
end

function Byte.Player.Respawn.GetStatus()
    return Byte.Player.Respawn.Status
end

Byte.Player.Join = { Status = "Off", LastTry = 0 }

function Byte.Player.Join.Pad()
    local lobby = Workspace:FindFirstChild("Lobby")
    local start = lobby and lobby:FindFirstChild("Start")
    local pad = start and start:FindFirstChild("Touch", true)
    if not (pad and pad:IsA("BasePart")) then return nil end
    for _, label in ipairs(start:GetDescendants()) do
        if label:IsA("TextLabel") and label.Text:find(Byte.Config.JoinText, 1, true) then return pad end
    end
    return nil
end

function Byte.Player.Join.Step()
    local join = Byte.Player.Join
    if not Byte.Options.AutoJoin then
        join.Status = "Off"
        return
    end

    local root = Byte.Player.Root
    local pad = join.Pad()
    if not (root and root.Parent and pad) then
        join.Status = pad and "Waiting for character" or "In a round"
        return
    end
    if (root.Position - pad.Position).Magnitude > Byte.Config.JoinRange then
        join.Status = "In a round"
        return
    end
    if osClock() - join.LastTry < Byte.Config.JoinRetry then return end
    join.LastTry = osClock()
    join.Status = "Joining"
    firetouchinterest(root, pad, 0)
    task.wait(0.1)
    firetouchinterest(root, pad, 1)
end

Byte.Movement = { Booted = false, Dash = nil, Resolving = false }

function Byte.Movement.FindDash()
    local client = ReplicatedStorage:FindFirstChild("Client")
    local helper = client and client:FindFirstChild("CombatHelper")
    local dash = helper and helper:FindFirstChild("Dash")
    if dash and dash:IsA("ModuleScript") then return dash end
    helper = ReplicatedStorage:FindFirstChild("CombatHelper", true)
    dash = helper and helper:FindFirstChild("Dash")
    return dash and dash:IsA("ModuleScript") and dash or nil
end

function Byte.Movement.ResolveDash()
    local found = Byte.Movement.FindDash()
    Byte.Movement.Dash = found and GameLib.Require(found) or false
    Byte.Movement.Resolving = false
end

function Byte.Movement.DashHelper()
    local dash = Byte.Movement.Dash
    if dash ~= nil then return dash or nil end
    if Byte.Movement.Resolving then return nil end
    Byte.Movement.Resolving = true
    task.spawn(Byte.Movement.ResolveDash)
    return nil
end

function Byte.Movement.OnStepped()
    if not Byte.Options.InfiniteDash then return end
    local dash = Byte.Movement.DashHelper()
    if dash and dash.RefreshNextDashTime then pcall(dash.RefreshNextDashTime) end
end

function Byte.Movement.Start()
    if Byte.Movement.Booted then return end
    Byte.Movement.Booted = true
    Byte:Connect(RunService.Stepped, Byte.Movement.OnStepped)
end

function Byte.Movement.GetStatus()
    return Byte.Options.InfiniteDash and "Infinite dash" or "Off"
end

Byte.Esp = { Count = 0, Rows = {} }

function Byte.Esp.Enabled()
    local toggle = Byte.UI and Byte.UI.Get and Byte.UI.Get("EspEnabled")
    return toggle ~= nil and toggle.Value == true
end

function Byte.Esp.KeyOf(entity, char)
    local inst = entity.Instance
    if typeof(inst) == "Instance" then return inst end
    return char or entity
end

function Byte.Esp.Row(entity)
    if type(entity) ~= "table" or Byte.Entity.IsLocal(entity) then return nil end
    local char = Byte.Entity.Character(entity)
    local health, maxHealth = Byte.Entity.Health(entity)
    if not char or health <= 0 then return nil end

    local player = Players:GetPlayerFromCharacter(char)
    return {
        Model = char,
        Name = player and player.DisplayName or char.Name,
        Health = health,
        MaxHealth = maxHealth > 0 and maxHealth or 100,
        Friendly = Byte.Entity.Friendly(entity),
        Root = Byte.Entity.Root(entity),
    }
end

function Byte.Esp.Expire(seen, now)
    local grace = Byte.Config.EspGrace
    for key, held in pairs(Byte.Esp.Rows) do
        if seen[key] then continue end
        local row = held.Row
        local alive = row.Model.Parent and row.Root and row.Root.Parent
        if now - held.Seen > grace or not alive then Byte.Esp.Rows[key] = nil end
    end
end

function Byte.Esp.Step()
    if not Byte.Esp.Enabled() then
        table.clear(Byte.Esp.Rows)
        Byte.State.EspSnapshot = {}
        Byte.Esp.Count = 0
        if Byte.EspDrawing then Byte.EspDrawing.Update() end
        return
    end

    local now, seen = osClock(), {}
    for _, entity in pairs(Byte.Entity.List()) do
        local row = Byte.Esp.Row(entity)
        if not row then continue end
        local key = Byte.Esp.KeyOf(entity, row.Model)
        local held = Byte.Esp.Rows[key]
        if not row.Root and held then row.Root = held.Row.Root end
        seen[key] = true
        Byte.Esp.Rows[key] = { Row = row, Seen = now }
    end
    Byte.Esp.Expire(seen, now)

    local snapshot = {}
    for _, held in pairs(Byte.Esp.Rows) do
        table.insert(snapshot, held.Row)
    end
    Byte.State.EspSnapshot = snapshot
    Byte.Esp.Count = #snapshot
    if Byte.EspDrawing then Byte.EspDrawing.Update() end
end

function Byte.Esp.Targets()
    return Byte.State.EspSnapshot
end

function Byte.Esp.GetStatus()
    if not Byte.Esp.Enabled() then return "Off" end
    return Byte.Esp.Count .. " targets"
end

Byte.EspDrawing = { Highlights = {} }

Byte.EspDrawing.FriendFill    = Color3.fromRGB(60, 220, 60)
Byte.EspDrawing.FriendOutline = Color3.fromRGB(40, 160, 40)
Byte.EspDrawing.EnemyFill     = Color3.fromRGB(220, 60, 60)
Byte.EspDrawing.EnemyOutline  = Color3.fromRGB(160, 40, 40)

function Byte.EspDrawing.Clear()
    for _, hl in pairs(Byte.EspDrawing.Highlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    table.clear(Byte.EspDrawing.Highlights)
end

function Byte.EspDrawing.ApplyColors(hl, friendly)
    if friendly then
        hl.FillColor    = Byte.EspDrawing.FriendFill
        hl.OutlineColor = Byte.EspDrawing.FriendOutline
    else
        hl.FillColor    = Byte.EspDrawing.EnemyFill
        hl.OutlineColor = Byte.EspDrawing.EnemyOutline
    end
end

function Byte.EspDrawing.MakeCham(char, friendly)
    local hl = Instance.new("Highlight")
    hl.Name          = "Byte"
    hl.DepthMode     = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee       = char
    hl.FillTransparency    = 0.5
    hl.OutlineTransparency = 0
    Byte.EspDrawing.ApplyColors(hl, friendly)
    hl.Parent = char
    return hl
end

function Byte.EspDrawing.Update()
    if not Byte.Esp.Enabled() then
        Byte.EspDrawing.Clear()
        return
    end
    local seen = {}
    for _, row in ipairs(Byte.State.EspSnapshot) do
        local char = row.Model
        if char and char.Parent then
            seen[char] = true
            local hl = Byte.EspDrawing.Highlights[char]
            if not hl or not hl.Parent then
                hl = Byte.EspDrawing.MakeCham(char, row.Friendly)
                Byte.EspDrawing.Highlights[char] = hl
            else
                if hl.Adornee ~= char then hl.Adornee = char end
                Byte.EspDrawing.ApplyColors(hl, row.Friendly)
            end
        end
    end
    for key, hl in pairs(Byte.EspDrawing.Highlights) do
        if not seen[key] or not hl.Parent then
            if hl.Parent then hl:Destroy() end
            Byte.EspDrawing.Highlights[key] = nil
        end
    end
end

local function AwaitChange(before, probe)
    local deadline = osClock() + Byte.Config.ResultWait
    local now = probe()
    while now == before and osClock() < deadline do
        task.wait(0.2)
        now = probe()
    end
    return now
end

Byte.Shop = { Status = "Off", LastResult = "" }

function Byte.Shop.Cases()
    local service = GameLib.Service.GachaService
    local store = service and service.LocalGachaStore
    local cases = store and store.Data
    if type(cases) ~= "table" then return {} end
    local keys = {}
    for key, entry in pairs(cases) do
        local owned = type(entry) == "table" and entry.Owned or entry
        if tonumber(owned) and owned > 0 then keys[#keys + 1] = tostring(key) end
    end
    table.sort(keys)
    return keys
end

function Byte.Shop.Owned(caseKey)
    local service = GameLib.Service.GachaService
    if not service then return 0 end
    local ok, owned = pcall(function() return service.GetGachaCount(caseKey) end)
    return ok and tonumber(owned) or 0
end

function Byte.Shop.Open(caseKey, count)
    local service = GameLib.Service.GachaService
    if not service then return 0 end
    local before = Byte.Shop.Owned(caseKey)
    count = math.min(count, before)
    if count < 1 then return 0 end

    local ok, err = pcall(function() return service.Gacha(caseKey, count) end)
    if not ok then
        warn("[Byte] open " .. caseKey .. ": " .. tostring(err))
        return 0
    end
    local after = AwaitChange(before, function() return Byte.Shop.Owned(caseKey) end)
    return math.max(before - after, 0)
end

function Byte.Shop.OpenAllNow()
    local opened = 0
    for _, caseKey in ipairs(Byte.Shop.Cases()) do
        local owned = Byte.Shop.Owned(caseKey)
        if owned < 1 then continue end
        opened += Byte.Shop.Open(caseKey, math.min(owned, math.max(Byte.Options.OpenCount, 1)))
        task.wait(Byte.Config.OpenDelay)
    end
    Byte.Shop.LastResult = opened > 0 and (opened .. " cases opened") or "no case opened"
    return Byte.Shop.LastResult
end

function Byte.Shop.Step()
    if not Byte.Options.AutoOpenCases then Byte.Shop.Status = "Off" return end
    Byte.Shop.Status = "Opening owned cases"
    Byte.Shop.OpenAllNow()
end

function Byte.Shop.GetStatus()
    return Byte.Options.AutoOpenCases and Byte.Shop.Status or "Off"
end

Byte.Sell = { Status = "Off", LastResult = "" }

function Byte.Sell.RarityOf(weaponName)
    local skin = tostring(weaponName):match("%.(.+)$")
    local wraps = GameLib.Config.WrapConfig
    local entry = skin and type(wraps) == "table" and wraps[skin]
    return type(entry) == "table" and entry.Rarity or nil
end

function Byte.Sell.Rarities()
    local wraps = GameLib.Config.WrapConfig
    if type(wraps) ~= "table" then return {} end
    local seen = {}
    for _, entry in pairs(wraps) do
        if type(entry) == "table" and entry.Rarity then seen[tostring(entry.Rarity)] = true end
    end
    return Util.SortedKeys(seen)
end

function Byte.Sell.Inventory()
    local service = GameLib.Service.WeaponService
    local ok, content = pcall(function() return service and service.GetContent() end)
    if not ok or type(content) ~= "table" then return {} end

    local list = {}
    for uid, weapon in pairs(content) do
        if type(weapon) == "table" then
            list[#list + 1] = {
                Uid = uid,
                Name = weapon.Name or tostring(uid),
                Rarity = Byte.Sell.RarityOf(weapon.Name),
                Price = tonumber(weapon.Price) or 0,
                Wear = tonumber(weapon.WearFactor) or 0,
            }
        end
    end
    return list
end

function Byte.Sell.Equipped()
    local combat = GameLib.Service.CombatService
    if not combat then return nil end
    local ok, weapons = pcall(function() return combat.GetWeapons() end)
    if not ok or type(weapons) ~= "table" then return nil end

    local set, count = {}, 0
    for _, weapon in pairs(weapons) do
        if type(weapon) == "table" and type(weapon.Name) == "string" then
            set[weapon.Name] = true
            count += 1
        end
    end
    return count > 0 and set or nil
end

function Byte.Sell.Pick()
    local equipped = Byte.Sell.Equipped()
    if not equipped then return nil end
    local wanted = Util.SetFromList(Byte.Options.SellRarities)
    local ceiling = Byte.Options.MaxSellPrice

    local owned = Byte.Sell.Inventory()
    table.sort(owned, function(left, right) return left.Price > right.Price end)

    local kept, uids = {}, {}
    for _, weapon in ipairs(owned) do
        if not (weapon.Rarity and wanted[weapon.Rarity]) or equipped[weapon.Name] then continue end
        kept[weapon.Rarity] = (kept[weapon.Rarity] or 0) + 1
        if kept[weapon.Rarity] <= Byte.Options.KeepPerRarity then continue end
        if ceiling <= 0 or weapon.Price <= ceiling then table.insert(uids, weapon.Uid) end
    end
    return uids
end

function Byte.Sell.SellNow()
    local service = GameLib.Service.WeaponService
    if not service then Byte.Sell.LastResult = "no service" return Byte.Sell.LastResult end

    local uids = Byte.Sell.Pick()
    if not uids then
        Byte.Sell.LastResult = "equipped weapons unknown, nothing sold"
        return Byte.Sell.LastResult
    end
    if #uids == 0 then
        Byte.Sell.LastResult = "nothing to sell"
        return Byte.Sell.LastResult
    end

    local countBefore, coinBefore = #Byte.Sell.Inventory(), Byte.Player:Coin()
    local ok, err = pcall(function() return service.Sell(uids) end)
    if not ok then
        Byte.Sell.LastResult = "sell failed: " .. tostring(err)
        return Byte.Sell.LastResult
    end

    local countAfter = AwaitChange(countBefore, function() return #Byte.Sell.Inventory() end)
    local coinAfter = Byte.Player:Coin()
    local gained = (coinBefore and coinAfter) and (" · +" .. (coinAfter - coinBefore) .. " coin") or ""
    Byte.Sell.LastResult = math.max(countBefore - countAfter, 0) .. " sold" .. gained
    return Byte.Sell.LastResult
end

function Byte.Sell.Step()
    if not Byte.Options.AutoSell then Byte.Sell.Status = "Off" return end
    Byte.Sell.Status = Byte.Sell.SellNow()
end

function Byte.Sell.GetStatus()
    return Byte.Options.AutoSell and Byte.Sell.Status or "Off"
end

Byte.Collect = { Status = "Off", LastResult = "" }

function Byte.Collect.IsClaimed(questId)
    local service = GameLib.Service.QuestService
    local ok, claimed = pcall(function() return service.IsClaimed(questId) end)
    return ok and claimed == true
end

function Byte.Collect.Claimable()
    local service = GameLib.Service.QuestService
    local quests = GameLib.Config.QuestConfig
    if not (service and type(quests) == "table") then return {} end

    local list = {}
    for questId in pairs(quests) do
        local asked, finished = pcall(function() return service.IsFinished(questId) end)
        if asked and finished and not Byte.Collect.IsClaimed(questId) then
            list[#list + 1] = questId
        end
    end
    return list
end

function Byte.Collect.ClaimNow()
    local service = GameLib.Service.QuestService
    if not service then Byte.Collect.LastResult = "no service" return Byte.Collect.LastResult end

    local ids = Byte.Collect.Claimable()
    if #ids == 0 then
        Byte.Collect.LastResult = "nothing to claim"
        return Byte.Collect.LastResult
    end

    local claimed = 0
    for _, questId in ipairs(ids) do
        local ok, err = pcall(function() return service.ClaimReward(questId) end)
        if not ok then
            warn("[Byte] claim " .. tostring(questId) .. ": " .. tostring(err))
        elseif AwaitChange(false, function() return Byte.Collect.IsClaimed(questId) end) then
            claimed += 1
        end
        task.wait(Byte.Config.ClaimDelay)
    end
    Byte.Collect.LastResult = claimed .. "/" .. #ids .. " quests claimed"
    return Byte.Collect.LastResult
end

function Byte.Collect.Step()
    if not Byte.Options.AutoClaimQuest then Byte.Collect.Status = "Off" return end
    Byte.Collect.Status = Byte.Collect.ClaimNow()
end

function Byte.Collect.GetStatus()
    return Byte.Options.AutoClaimQuest and Byte.Collect.Status or "Off"
end

Byte.Combat = { State = "Idle", Status = "Off", Target = nil, Part = nil, Look = nil, Bound = false, LastShot = 0, Circle = nil, OriginFn = nil, OriginParams = nil, LookSource = nil, LookHolders = nil, LockedSince = 0 }

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

function Byte.Combat.AimActive() return Byte.Options.Aimbot == true end
function Byte.Combat.SilentActive() return Byte.Options.SilentAim == true or Byte.Options.Ragebot == true end
function Byte.Combat.Active()
    local opts = Byte.Options
    return opts.Aimbot or opts.SilentAim or opts.Ragebot or opts.TriggerBot or opts.ShowFov
end

function Byte.Combat.BonePart(entity, bone)
    local char = Byte.Entity.Character(entity)
    if not char then return nil end
    local collider = char:FindFirstChild("Collider")
    bone = bone or Byte.Options.AimBone or "Head"
    return collider and (collider:FindFirstChild(bone) or collider:FindFirstChild("Head"))
        or char:FindFirstChild("Head")
        or Byte.Entity.Root(entity)
end

function Byte.Combat.Filter()
    local cam = Workspace.CurrentCamera
    aimParams.FilterDescendantsInstances = { cam, Byte.Entity.Character(Byte.Entity.Local()) }
    return cam
end

function Byte.Combat.Origin()
    local originFn = Byte.Combat.OriginFn
    if not originFn then
        local camCtrl = Byte.GameLib.CameraController
        originFn = camCtrl and camCtrl.GetCombatOriginFn and camCtrl.GetCombatOriginFn()
        Byte.Combat.OriginFn = originFn
    end
    if originFn then
        local ok, origin, detect = pcall(originFn)
        if ok and typeof(origin) == "CFrame" then return origin, detect end
    end
    return Workspace.CurrentCamera.CFrame, nil
end

function Byte.Combat.Visible(part, char)
    Byte.Combat.Filter()
    local origin = Byte.Combat.Origin().Position
    local hit = Workspace:Raycast(origin, part.Position - origin, aimParams)
    return hit ~= nil and hit.Instance:IsDescendantOf(char)
end

function Byte.Combat.IsEnemy(entity)
    if type(entity) ~= "table" or Byte.Entity.IsLocal(entity) then return false end
    if Byte.Options.AimTeamCheck and Byte.Entity.Friendly(entity) then return false end
    local inst = entity.Instance
    if typeof(inst) == "Instance" and inst:GetAttribute("State") == "Dead" then return false end
    return Byte.Entity.Health(entity) > 0
end

function Byte.Combat.Predict(part)
    local lead = (Byte.Options.AimPrediction or 0) / 1000
    if lead <= 0 then return part.Position end
    return part.Position + part.AssemblyLinearVelocity * lead
end

function Byte.Combat.AimCenter(cam)
    if Byte.Options.AimPriority == "Mouse" then
        local inset = game:GetService("GuiService"):GetGuiInset()
        return UserInputService:GetMouseLocation() - inset
    end
    return cam.ViewportSize / 2
end

function Byte.Combat.UsesFov()
    if Byte.Options.Ragebot then return false end
    local mode = Byte.Options.AimPriority
    return mode == "Crosshair" or mode == "Mouse"
end

function Byte.Combat.Score(entity, part, cam, center, origin)
    local dist = (part.Position - origin).Magnitude
    if dist > Byte.Options.AimMaxDistance then return nil end

    if Byte.Combat.UsesFov() then
        local screen, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen then return nil end
        local gap = (Vector2.new(screen.X, screen.Y) - center).Magnitude
        if gap > Byte.Options.AimFov then return nil end
        return gap
    end
    if Byte.Options.AimPriority == "Health" then
        return Byte.Entity.Health(entity) * 10000 + dist
    end
    return dist
end

function Byte.Combat.SelectTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local center = Byte.Combat.AimCenter(cam)
    local origin = cam.CFrame.Position
    local best, bestPart, bestScore

    for _, entity in pairs(Byte.Entity.List()) do
        if not Byte.Combat.IsEnemy(entity) then continue end
        local part = Byte.Combat.BonePart(entity)
        if not part then continue end
        local score = Byte.Combat.Score(entity, part, cam, center, origin)
        if not score or (bestScore and score >= bestScore) then continue end
        if (Byte.Options.AimWallCheck or Byte.Options.Ragebot) and not Byte.Combat.Visible(part, Byte.Entity.Character(entity)) then continue end
        best, bestPart, bestScore = entity, part, score
    end
    return best, bestPart
end

function Byte.Combat.BindCamera()
    if Byte.Combat.Bound then return end
    Byte.Combat.Bound = true
    RunService:BindToRenderStep("ByteAim", Byte.Config.AimRenderPriority, function()
        local cam = Workspace.CurrentCamera
        local part = Byte.Combat.Part
        if not (Byte.Combat.AimActive() and part and part.Parent) then
            Byte.Combat.Look = nil
            return
        end
        local origin = cam.CFrame.Position
        local want = (Byte.Combat.Predict(part) - origin).Unit
        local smooth = math.max(Byte.Options.AimSmooth or 1, 1)
        local look = Byte.Combat.Look or cam.CFrame.LookVector
        look = smooth <= 1 and want or look:Lerp(want, 1 / smooth).Unit
        Byte.Combat.Look = look
        cam.CFrame = CFrame.lookAt(origin, origin + look)
    end)
end

function Byte.Combat.UnbindCamera()
    if not Byte.Combat.Bound then return end
    Byte.Combat.Bound = false
    RunService:UnbindFromRenderStep("ByteAim")
end

function Byte.Combat.CrosshairOnEnemy()
    Byte.Combat.Filter()
    local origin = Byte.Combat.Origin()
    local hit = Workspace:Raycast(origin.Position, origin.LookVector * Byte.Config.TriggerRange, aimParams)
    if not hit then return false end
    for _, entity in pairs(Byte.Entity.List()) do
        local char = Byte.Entity.Character(entity)
        if char and hit.Instance:IsDescendantOf(char) then return Byte.Combat.IsEnemy(entity) end
    end
    return false
end

function Byte.Combat.Fire()
    local now = os.clock()
    if now - Byte.Combat.LastShot < Byte.Config.FireInterval then return false end
    Byte.Combat.LastShot = now

    local _, shooter = Byte.Combat.Shooter()
    if not shooter then return false end

    local ok, fired = pcall(shooter.LocalShoot, shooter)
    if not ok then warn("[Byte] shoot:", fired) end
    return ok and fired ~= nil
end

function Byte.Combat.Shooter()
    local combat = Byte.GameLib.Service.CombatService
    local weapon = combat and combat.GetCurrentWeapon()
    return weapon, weapon and weapon._Shootable
end

Byte.Combat.SilentSaved = setmetatable({}, { __mode = "k" })

function Byte.Combat.OriginOverride()
    if Byte.Combat.OriginParams ~= nil then return Byte.Combat.OriginParams or nil end
    if not Byte.Caps.Upvalues then return nil end
    local camCtrl = Byte.GameLib.CameraController
    local ok, holder = pcall(function() return Util.GetUpvalue(camCtrl.GetCombatOriginFn(), 1) end)
    local params = ok and type(holder) == "table" and type(holder.TempParams) == "table" and holder.TempParams
    Byte.Combat.OriginParams = params or false
    return params or nil
end

function Byte.Combat.ShootAt(shooter, entity, part, opts)
    local params = Byte.Combat.OriginOverride()
    local start = Byte.Combat.Origin().Position
    local aim = Byte.Combat.Predict(part)
    opts = type(opts) == "table" and opts or {}
    opts.Target = entity.Instance
    opts.TargetHeadshot = part.Name == "Head" or nil
    local ok, localPos = pcall(function() return entity:GetPivot(true):PointToObjectSpace(aim) end)
    if ok then opts.TargetPos = localPos end

    local saved = { params.CameraCFrame, params.SubjectDistance, params.MouseLockOffset }
    params.CameraCFrame, params.SubjectDistance, params.MouseLockOffset = CFrame.lookAt(start, aim), 0, Vector3.zero
    local fired, shot = pcall(shooter.Shoot, shooter, start, (aim - start).Unit, opts)
    params.CameraCFrame, params.SubjectDistance, params.MouseLockOffset = saved[1], saved[2], saved[3]
    if not fired then warn("[Byte] silent:", shot) end
    return fired and shot or nil
end

function Byte.Combat.SilentShoot(shooter, opts)
    local saved = Byte.Combat.SilentSaved[shooter]
    local entity = Byte.Combat.Target
    if not (Byte.Combat.SilentActive() and entity and Byte.Combat.OriginOverride()) then return saved.Fn(shooter, opts) end
    if math.random(100) > Byte.Options.HitChance then return saved.Fn(shooter, opts) end

    local bone = math.random(100) <= Byte.Options.HeadChance and "Head" or "Body"
    local part = Byte.Combat.BonePart(entity, bone)
    if not (part and part.Parent) then return saved.Fn(shooter, opts) end
    return Byte.Combat.ShootAt(shooter, entity, part, opts)
end

function Byte.Combat.ReportedLook(...)
    local look = Byte.Combat.LookSource(...)
    local part = Byte.Combat.Part
    if typeof(look) ~= "CFrame" or not (Byte.Combat.SilentActive() and Byte.Combat.Target and part and part.Parent) then return look end
    return CFrame.lookAt(look.Position, Byte.Combat.Predict(part))
end

function Byte.Combat.LookTables()
    local camCtrl = Byte.GameLib.CameraController
    local tables = {}
    if type(camCtrl) ~= "table" then return tables end
    if rawget(camCtrl, "GetCFrame") and not table.isfrozen(camCtrl) then tables[1] = camCtrl end
    local meta = Util.GetRawMetatable and Util.GetRawMetatable(camCtrl)
    local index = type(meta) == "table" and rawget(meta, "__index")
    if type(index) == "table" then index = { index } elseif type(index) == "function" and Util.GetUpvalues then index = Util.GetUpvalues(index) else index = {} end
    for _, holder in pairs(index) do
        if type(holder) == "table" and type(rawget(holder, "GetCFrame")) == "function" and not table.isfrozen(holder) then
            tables[#tables + 1] = holder
        end
    end
    return tables
end

function Byte.Combat.ApplyLook()
    if Byte.Combat.LookSource ~= nil then return end
    local tables = Byte.Combat.LookTables()
    if #tables == 0 then
        Byte.Combat.LookSource = false
        return
    end
    Byte.Combat.LookSource = rawget(tables[1], "GetCFrame")
    Byte.Combat.LookHolders = tables
    for _, holder in ipairs(tables) do rawset(holder, "GetCFrame", Byte.Combat.ReportedLook) end
end

function Byte.Combat.RestoreLook()
    local source = Byte.Combat.LookSource
    if not source then
        Byte.Combat.LookSource = nil
        return
    end
    for _, holder in ipairs(Byte.Combat.LookHolders or {}) do
        if rawget(holder, "GetCFrame") == Byte.Combat.ReportedLook then rawset(holder, "GetCFrame", source) end
    end
    Byte.Combat.LookSource, Byte.Combat.LookHolders = nil, nil
end

function Byte.Combat.ApplySilent()
    local _, shooter = Byte.Combat.Shooter()
    if type(shooter) ~= "table" or rawget(shooter, "LocalShoot") == Byte.Combat.SilentShoot then return end
    if type(shooter.Shoot) ~= "function" then return end
    Byte.Combat.SilentSaved[shooter] = { Raw = rawget(shooter, "LocalShoot"), Fn = shooter.LocalShoot }
    rawset(shooter, "LocalShoot", Byte.Combat.SilentShoot)
end

function Byte.Combat.RestoreSilent()
    for shooter, saved in pairs(Byte.Combat.SilentSaved) do
        rawset(shooter, "LocalShoot", saved.Raw)
    end
    table.clear(Byte.Combat.SilentSaved)
end

Byte.Combat.ScopeSaved = setmetatable({}, { __mode = "k" })

function Byte.Combat.ApplyInstantScope()
    local weapon = Byte.Combat.Shooter()
    local cfg = weapon and weapon.Config
    if type(cfg) ~= "table" or rawget(cfg, "AimTime") == 0 then return end
    if not Byte.Combat.ScopeSaved[cfg] then
        Byte.Combat.ScopeSaved[cfg] = { rawget(cfg, "AimTime"), rawget(cfg, "DelayTime") }
    end
    rawset(cfg, "AimTime", 0)
    rawset(cfg, "DelayTime", 0)
end

function Byte.Combat.RestoreScope()
    for cfg, saved in pairs(Byte.Combat.ScopeSaved) do
        rawset(cfg, "AimTime", saved[1])
        rawset(cfg, "DelayTime", saved[2])
    end
    table.clear(Byte.Combat.ScopeSaved)
end

function Byte.Combat.MakeCircle()
    local color = Byte.Config.FovColor
    if Byte.Caps.Drawing then
        local circle = Drawing.new("Circle")
        circle.Thickness, circle.NumSides, circle.Filled = 1.5, 64, false
        circle.Color = color
        return { Drawing = circle }
    end

    local ring = Instance.new("Frame")
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.BackgroundTransparency = 1
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = ring
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Thickness = 1.5
    stroke.Parent = ring
    ring.Parent = Util.Overlay()
    return { Frame = ring }
end

function Byte.Combat.SetCircleVisible(visible)
    local circle = Byte.Combat.Circle
    if not circle then return end
    if circle.Drawing then circle.Drawing.Visible = visible else circle.Frame.Visible = visible end
end

function Byte.Combat.UpdateCircle()
    local active = Byte.Options.Aimbot or Byte.Options.SilentAim or Byte.Options.Ragebot
    if not Byte.Options.ShowFov or not active then
        Byte.Combat.SetCircleVisible(false)
        return
    end
    local circle = Byte.Combat.Circle
    if not circle then
        circle = Byte.Combat.MakeCircle()
        Byte.Combat.Circle = circle
    end

    local center = Byte.Combat.AimCenter(Workspace.CurrentCamera)
    local radius = Byte.Options.AimFov
    if circle.Drawing then
        circle.Drawing.Position, circle.Drawing.Radius, circle.Drawing.Visible = center, radius, true
        return
    end
    circle.Frame.Position = UDim2.fromOffset(center.X, center.Y)
    circle.Frame.Size = UDim2.fromOffset(radius * 2, radius * 2)
    circle.Frame.Visible = true
end

function Byte.Combat.DrawCircle()
    local ok, err = pcall(Byte.Combat.UpdateCircle)
    if ok then
        Byte.Faults.Clear("FOV circle")
    else
        Byte.Faults.Report("FOV circle", err, { "ShowFov" })
    end
end

Byte.Combat.RecoilSaved = setmetatable({}, { __mode = "k" })
Byte.Combat.ZoomSaved = setmetatable({}, { __mode = "k" })

function Byte.Combat.ApplyNoRecoil()
    local weapon = Byte.Combat.Shooter()
    local cfg = weapon and weapon.Config
    if type(cfg) ~= "table" then return end
    if type(cfg.RecoilZoom) == "number" and cfg.RecoilZoom ~= 0 then
        Byte.Combat.ZoomSaved[cfg] = Byte.Combat.ZoomSaved[cfg] or cfg.RecoilZoom
        cfg.RecoilZoom = 0
    end
    for _, key in ipairs({ "Recoil", "RecoilAiming" }) do
        local recoil = cfg[key]
        if type(recoil) == "table" and recoil.Degree ~= 0 then
            if Byte.Combat.RecoilSaved[recoil] == nil then Byte.Combat.RecoilSaved[recoil] = recoil.Degree end
            recoil.Degree = 0
        end
    end
end

Byte.Combat.SpreadSaved = setmetatable({}, { __mode = "k" })

function Byte.Combat.ZeroSpread() return 0 end

function Byte.Combat.ApplyNoSpread()
    local _, shooter = Byte.Combat.Shooter()
    if type(shooter) ~= "table" or rawget(shooter, "GetCurrentSpread") == Byte.Combat.ZeroSpread then return end
    Byte.Combat.SpreadSaved[shooter] = { rawget(shooter, "GetCurrentSpread") }
    rawset(shooter, "GetCurrentSpread", Byte.Combat.ZeroSpread)
end

function Byte.Combat.RestoreSpread()
    for shooter, original in pairs(Byte.Combat.SpreadSaved) do
        rawset(shooter, "GetCurrentSpread", original[1])
    end
    table.clear(Byte.Combat.SpreadSaved)
end

function Byte.Combat.RestoreRecoil()
    for recoil, degree in pairs(Byte.Combat.RecoilSaved) do recoil.Degree = degree end
    for cfg, zoom in pairs(Byte.Combat.ZoomSaved) do cfg.RecoilZoom = zoom end
    table.clear(Byte.Combat.RecoilSaved)
    table.clear(Byte.Combat.ZoomSaved)
end

function Byte.Combat.Patches()
    if not Byte.State.Alive then return end
    local opts = Byte.Options

    if opts.NoRecoil then
        Byte.Combat.ApplyNoRecoil()
    elseif next(Byte.Combat.RecoilSaved) or next(Byte.Combat.ZoomSaved) then
        Byte.Combat.RestoreRecoil()
    end
    if opts.NoSpread then
        Byte.Combat.ApplyNoSpread()
    elseif next(Byte.Combat.SpreadSaved) then
        Byte.Combat.RestoreSpread()
    end
    if opts.InstantScope or opts.Ragebot or opts.SilentAim then
        Byte.Combat.ApplyInstantScope()
    elseif next(Byte.Combat.ScopeSaved) then
        Byte.Combat.RestoreScope()
    end

    if Byte.Combat.SilentActive() then
        Byte.Combat.ApplySilent()
        Byte.Combat.ApplyLook()
        return
    end
    if next(Byte.Combat.SilentSaved) then Byte.Combat.RestoreSilent() end
    Byte.Combat.RestoreLook()
end

function Byte.Combat.Aim(mode)
    local target, part = Byte.Combat.SelectTarget()
    if target ~= Byte.Combat.Target then Byte.Combat.LockedSince = os.clock() end
    Byte.Combat.Target, Byte.Combat.Part = target, part
    Byte.Combat.State = target and "Locked" or "Acquire"
    local char = target and Byte.Entity.Character(target)
    Byte.Combat.Status = mode .. " · " .. (char and char.Name or "no target")
end

function Byte.Combat.Step()
    Byte.Combat.Patches()
    if not Byte.Combat.Active() then
        if Byte.Combat.State ~= "Idle" then Byte.Combat.Stop() end
        return
    end
    if not Byte.Match.InRound() then
        Byte.Combat.Target, Byte.Combat.Part = nil, nil
        Byte.Combat.State, Byte.Combat.Status = "Wait", "Waiting for round"
        return
    end

    local mode = Byte.Match.Info() or "?"
    if Byte.Combat.AimActive() then Byte.Combat.BindCamera() else Byte.Combat.UnbindCamera() end
    if Byte.Combat.AimActive() or Byte.Combat.SilentActive() then
        Byte.Combat.Aim(mode)
    else
        Byte.Combat.Target, Byte.Combat.Part = nil, nil
        Byte.Combat.State, Byte.Combat.Status = "Ready", mode .. " · aim idle"
    end

    local settled = Byte.Combat.Target ~= nil and os.clock() - Byte.Combat.LockedSince >= Byte.Config.LookSettle
    local shoot = (Byte.Options.Ragebot and settled) or (Byte.Options.TriggerBot and Byte.Combat.CrosshairOnEnemy())
    if shoot and Byte.Combat.Fire() then Byte.Combat.State = "Fired" end
end

function Byte.Combat.Stop()
    Byte.Combat.UnbindCamera()
    Byte.Combat.Target, Byte.Combat.Part = nil, nil
    Byte.Combat.State, Byte.Combat.Status = "Idle", "Off"
end

function Byte.Combat.Rest()
    local undo = {
        Byte.Combat.Stop, Byte.Combat.RestoreRecoil, Byte.Combat.RestoreSpread,
        Byte.Combat.RestoreScope, Byte.Combat.RestoreSilent, Byte.Combat.RestoreLook,
    }
    for _, restore in ipairs(undo) do
        Util.Try("combat restore", restore)
    end
end

function Byte.Combat.Unload()
    Byte.Combat.Rest()
    local circle = Byte.Combat.Circle
    Byte.Combat.Circle = nil
    if not circle then return end
    if circle.Frame then
        circle.Frame:Destroy()
    else
        pcall(function() circle.Drawing:Remove() end)
    end
end

function Byte.Combat.GetStatus() return Byte.Combat.Status end

Byte.Skin = {
    Catalog = {}, Types = {}, Rarities = {}, Labels = {}, Images = {}, Colors = {},
    Chosen = {}, Saved = setmetatable({}, { __mode = "k" }), Status = "Off",
    RarityRank = { Common = 1, UnCommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mystic = 6 },
    Hidden = { Charm = true },
}

function Byte.Skin.Classify(cfg)
    if type(cfg) ~= "table" then return nil end
    local ok, kind, family = pcall(function() return cfg.WeaponType, cfg.Family end)
    if not ok or type(kind) ~= "string" or type(family) ~= "string" then return nil end
    if Byte.Skin.Hidden[kind] or family:find("^Base") then return nil end
    return kind, family
end

do
    local configs = Byte.GameLib.Config.WeaponConfig or {}
    for key, cfg in pairs(configs) do
        if type(key) ~= "string" then continue end
        local kind, family = Byte.Skin.Classify(cfg)
        if not kind then continue end
        local byFamily = Byte.Skin.Catalog[kind]
        if not byFamily then
            byFamily = {}
            Byte.Skin.Catalog[kind] = byFamily
            table.insert(Byte.Skin.Types, kind)
        end
        byFamily[family] = byFamily[family] or {}
        local rarity = tostring(cfg.Rarity or "Common")
        table.insert(byFamily[family], { key, rarity, type(cfg.Display) == "string" and cfg.Display or key, type(cfg.Image) == "string" and cfg.Image or nil })
        if not table.find(Byte.Skin.Rarities, rarity) then table.insert(Byte.Skin.Rarities, rarity) end
    end
    table.sort(Byte.Skin.Types)
    table.sort(Byte.Skin.Rarities, function(left, right)
        local rankLeft, rankRight = Byte.Skin.RarityRank[left] or 0, Byte.Skin.RarityRank[right] or 0
        if rankLeft ~= rankRight then return rankLeft > rankRight end
        return left < right
    end)
    for _, byFamily in pairs(Byte.Skin.Catalog) do
        for _, list in pairs(byFamily) do
            table.sort(list, function(left, right)
                local rankLeft, rankRight = Byte.Skin.RarityRank[left[2]] or 0, Byte.Skin.RarityRank[right[2]] or 0
                if rankLeft ~= rankRight then return rankLeft > rankRight end
                return left[3] < right[3]
            end)
        end
    end
end

function Byte.Skin.Families(kind)
    return Util.SortedKeys(Byte.Skin.Catalog[kind])
end

function Byte.Skin.List(kind, family, rarities)
    local list = Byte.Skin.Catalog[kind] and Byte.Skin.Catalog[kind][family]
    local names = {}
    if not list then return names end
    local filter = rarities and next(rarities) ~= nil and rarities or nil
    for _, skin in ipairs(list) do
        if filter and not filter[skin[2]] then continue end
        local label = string.format("[%s] %s", skin[2], skin[3])
        if Byte.Skin.Labels[label] and Byte.Skin.Labels[label] ~= skin[1] then label = label .. " · " .. skin[1] end
        Byte.Skin.Labels[label] = skin[1]
        Byte.Skin.Images[label] = skin[4]
        local colors = Byte.GameLib.RarityColor
        Byte.Skin.Colors[label] = type(colors) == "table" and typeof(colors[skin[2]]) == "Color3" and colors[skin[2]] or nil
        names[#names + 1] = label
    end
    return names
end

function Byte.Skin.Choose(family, label)
    Byte.Skin.Chosen[family] = label and Byte.Skin.Labels[label] or nil
end

function Byte.Skin.ClearAll() table.clear(Byte.Skin.Chosen) end

function Byte.Skin.Carried()
    local combat = Byte.GameLib.Service.CombatService
    if not combat then return {} end
    local ok, weapons = pcall(function() return combat.GetWeapons() end)
    local list = {}
    if ok and type(weapons) == "table" then
        for _, weapon in pairs(weapons) do
            if type(weapon) == "table" and weapon.Name then list[#list + 1] = weapon end
        end
    end
    local held = combat.GetCurrentWeapon()
    if held and not table.find(list, held) then list[#list + 1] = held end
    return list
end

function Byte.Skin.Rebuild(weapon)
    local controllers = Byte.GameLib.WeaponController
    local entity = Byte.GameLib.Service.EntityService.LocalEntity
    if not (controllers and entity and weapon.Controller) then return end
    weapon.Controller:Destroy()
    controllers.Create(entity, weapon)
end

function Byte.Skin.Apply(weapon, key)
    local cfg = Byte.GameLib.Config.WeaponConfig[key]
    if not cfg then return end
    if not Byte.Skin.Saved[weapon] then Byte.Skin.Saved[weapon] = { weapon.Name, weapon.Config } end
    weapon.Name, weapon.Config = key, cfg
    Byte.Skin.Rebuild(weapon)
end

function Byte.Skin.Revert(weapon)
    local saved = Byte.Skin.Saved[weapon]
    if not saved then return end
    weapon.Name, weapon.Config = saved[1], saved[2]
    Byte.Skin.Saved[weapon] = nil
    Byte.Skin.Rebuild(weapon)
end

function Byte.Skin.Restore()
    for weapon in pairs(Byte.Skin.Saved) do Byte.Skin.Revert(weapon) end
end

function Byte.Skin.Step()
    if not Byte.Options.SkinChanger then
        if next(Byte.Skin.Saved) then Byte.Skin.Restore() end
        Byte.Skin.Status = "Off"
        return
    end

    local applied = 0
    for _, weapon in ipairs(Byte.Skin.Carried()) do
        local saved = Byte.Skin.Saved[weapon]
        local originalCfg = saved and saved[2] or weapon.Config
        local _, family = Byte.Skin.Classify(originalCfg)
        local key = family and Byte.Skin.Chosen[family]
        if key then
            if weapon.Name ~= key then Byte.Skin.Apply(weapon, key) end
            applied += 1
        elseif saved then
            Byte.Skin.Revert(weapon)
        end
    end
    Byte.Skin.Status = applied > 0 and (applied .. " weapon(s) skinned") or "Pick a skin"
end

function Byte.Skin.GetStatus() return Byte.Skin.Status end

Byte.UI = { SkinRefill = {} }
local Library, T, ThemeManager, SaveManager

function Byte.UI.Get(id)
    if not Library then return nil end
    if Library.Options and Library.Options[id] then return Library.Options[id] end
    if Library.Toggles and Library.Toggles[id] then return Library.Toggles[id] end
    return nil
end

function Byte.UI.Detach(handler)
    return function(...)
        local packed = table.pack(...)
        task.defer(function()
            local ok, err = pcall(handler, table.unpack(packed, 1, packed.n))
            if not ok then warn("[Byte] ui: " .. tostring(err)) end
        end)
    end
end

function Byte.UI.StartStop(module)
    return Byte.UI.Detach(function(on)
        if on then module.Start() else module.Stop() end
    end)
end

function Byte.UI.Bind(widget, key, transform)
    local function Apply(value)
        if transform then value = transform(value) end
        Byte.Options[key] = value
    end
    if widget and widget.Value ~= nil then
        pcall(Apply, widget.Value)
    end
    if widget and widget.OnChanged then
        local ok, err = pcall(function() widget:OnChanged(Apply) end)
        if not ok then warn("[Byte] bind " .. key .. ": " .. tostring(err)) end
    end
    return widget
end



function Byte.UI.Notice(title, text, kind)
    table.insert(Byte.State.Notices, { title, tostring(text), kind })
end



function Byte.UI.GuardSilent()
    local reason = T("Not supported on this executor", "Not supported on this executor")
    for _, idx in ipairs({ "SilentAim", "Ragebot" }) do
        Library.Compat.NeedCap(idx, "Upvalues")
        if not Byte.Caps.LookSpoof then Library.Compat.Block(idx, reason) end
    end
end

function Byte.UI.BuildCombat(window)
    local tab = window:AddTab(T("Combat", "Combat"), "crosshair", T("Aimbot and firing", "Aimbot and firing"))

    local aim = tab:AddLeftGroupbox(T("Aimbot", "Aimbot"), "crosshair")
    aim:AddToggle("Aimbot", {
        Text = T("Aimbot", "Aimbot"),
        Tooltip = T("Locks onto the enemy nearest your crosshair", "Locks onto the enemy nearest your crosshair"),
        Default = false,
    })
    aim:AddDropdown("AimPriority", { Text = T("Target priority", "Target priority"), Values = { "Crosshair", "Mouse", "Distance", "Health" }, Default = "Crosshair" })
    aim:AddSlider("AimMaxDistance", { Text = T("Max aim distance", "Max aim distance"), Min = 50, Max = 2000, Default = 1000, Suffix = "m" })
    aim:AddDropdown("AimBone", { Text = T("Aim part", "Aim part"), Values = { "Head", "Body", "Arm", "Leg" }, Default = "Head" })
    aim:AddSlider("AimSmooth", { Text = T("Smoothness", "Smoothness"), Min = 1, Max = 20, Default = 1 })
    aim:AddSlider("AimPrediction", { Text = T("Prediction", "Prediction"), Min = 0, Max = 200, Default = 60, Suffix = "ms" })
    aim:AddSlider("AimFov", { Text = T("FOV", "FOV"), Min = 20, Max = 600, Default = 150, Suffix = "px" })
    aim:AddToggle("ShowFov", { Text = T("Show FOV circle", "Show FOV circle"), Default = false })
    aim:AddCheckbox("AimWallCheck", { Text = T("Visible only", "Visible only"), Default = true })
    aim:AddCheckbox("AimTeamCheck", { Text = T("Team check", "Team check"), Default = true })

    local rage = tab:AddRightGroupbox(T("Rage", "Rage"), "zap")
    rage:AddToggle("Ragebot", {
        Text = T("Ragebot", "Ragebot"),
        Tooltip = T("Shoots every visible enemy on its own, view stays still", "Shoots every visible enemy on its own, view stays still"),
        Default = false,
    })
    rage:AddToggle("SilentAim", {
        Text = T("Silent aim", "Silent aim"),
        Tooltip = T("Shots land on the target inside the FOV, your view never moves", "Shots land on the target inside the FOV, your view never moves"),
        Default = false,
    })
    rage:AddSlider("HitChance", { Text = T("Hit chance", "Hit chance"), Min = 0, Max = 100, Default = 100, Suffix = "%" })
    rage:AddSlider("HeadChance", { Text = T("Headshot chance", "Headshot chance"), Min = 0, Max = 100, Default = 100, Suffix = "%" })
    rage:AddToggle("InstantScope", {
        Text = T("Fast scope", "Fast scope"),
        Tooltip = T("Cuts the wait before the scope is ready", "Cuts the wait before the scope is ready"),
        Default = false,
    })

    local fire = tab:AddRightGroupbox(T("Firing", "Firing"), "target")
    fire:AddToggle("TriggerBot", {
        Text = T("Trigger bot", "Trigger bot"),
        Tooltip = T("Fires the moment your crosshair is on an enemy", "Fires the moment your crosshair is on an enemy"),
        Default = false,
    })
    fire:AddToggle("NoSpread", {
        Text = T("No spread", "No spread"),
        Tooltip = T("Shots stay accurate while moving or jumping", "Shots stay accurate while moving or jumping"),
        Default = false,
    })
    fire:AddToggle("NoRecoil", {
        Text = T("No recoil", "No recoil"),
        Tooltip = T("Camera no longer kicks when firing", "Camera no longer kicks when firing"),
        Default = false,
    })

    Byte.UI.GuardSilent()
end

function Byte.UI.BuildPlayer(window)
    local tab = window:AddTab(T("Player", "Player"), "user", T("Respawn and utility", "Respawn and utility"))

    local util = tab:AddLeftGroupbox(T("Utility", "Utility"), "settings")
    util:AddToggle("FastRespawn", {
        Text = T("Fast respawn", "Fast respawn"),
        Tooltip = T("Back in the fight the moment you die", "Back in the fight the moment you die"),
        Default = false,
    })
    util:AddToggle("AutoJoin", {
        Text = T("Auto join round", "Auto join round"),
        Tooltip = T("Joins the next round from the lobby by itself", "Joins the next round from the lobby by itself"),
        Default = false,
    })
    Library.Compat.NeedCap("AutoJoin", "Touch")
    util:AddToggle("AntiAfk", {
        Text = T("Anti AFK", "Anti AFK"),
        Default = false,
        Callback = Byte.UI.StartStop(Byte.Player.AntiAfk),
    })

    util:AddToggle("EspEnabled", {
        Text = T("Enable ESP", "Enable ESP"),
        Tooltip = T("Shows name and health over enemies", "Shows name and health over enemies"),
        Default = false,
    })

    local move = tab:AddRightGroupbox(T("Movement", "Movement"), "zap")
    move:AddToggle("InfiniteDash", {
        Text = T("Infinite dash", "Infinite dash"),
        Tooltip = T("Dash again without waiting (FFA/TDM)", "Dash again without waiting (FFA/TDM)"),
        Default = false,
    })
end

Byte.UI.SkinKinds = {
    Sniper = { "Snipers", "Snipers", "crosshair" },
    Rifle = { "Rifles", "Rifles", "target" },
    Melee = { "Knives", "Knives", "swords" },
    Glove = { "Gloves", "Gloves", "shield" },
}

function Byte.UI.BuildSkinGroup(tab, kind, left)
    local meta = Byte.UI.SkinKinds[kind] or { kind, kind, "star" }
    local group = left and tab:AddLeftGroupbox(T(meta[1], meta[2]), meta[3]) or tab:AddRightGroupbox(T(meta[1], meta[2]), meta[3])
    local families = Byte.Skin.Families(kind)
    local weaponIdx, skinIdx = "Skin" .. kind .. "Weapon", "Skin" .. kind .. "Pick"

    local function Family()
        local picker = Byte.UI.Get(weaponIdx)
        return picker and picker.Value
    end

    local function Refill()
        local picker = Byte.UI.Get(skinIdx)
        if picker and picker.SetValues then
            pcall(picker.SetValues, picker, Byte.Skin.List(kind, Family(), Util.SetFromList(Byte.Options.SkinRarities)))
        end
    end
    table.insert(Byte.UI.SkinRefill, Refill)

    group:AddDropdown(weaponIdx, { Text = T("Weapon", "Weapon"), Values = families, Default = families[1], Searchable = true, Callback = function() Refill() end })
    group:AddDropdown(skinIdx, {
        Text = T("Skin", "Skin"),
        Values = Byte.Skin.List(kind, families[1], {}),
        Searchable = true,
        AllowNull = true,
        Callback = function(label)
            if Family() then Byte.Skin.Choose(Family(), label) end
        end,
    })
    group:AddButton({ Text = T("Use default skin", "Use default skin"), Callback = function()
        if Family() then Byte.Skin.Choose(Family(), nil) end
        local picker = Byte.UI.Get(skinIdx)
        if picker and picker.SetValue then pcall(picker.SetValue, picker, nil) end
    end })
end

function Byte.UI.BuildSkins(window)
    Byte.UI.SkinRefill = {}
    local tab = window:AddTab(T("Skins", "Skins"), "star", T("Every weapon, knife and glove skin", "Every weapon, knife and glove skin"))

    local main = tab:AddLeftGroupbox(T("Skin Changer", "Skin Changer"), "star")
    main:AddToggle("SkinChanger", { Text = T("Skin changer", "Skin changer"), Description = T("Pick any skin per weapon, only you see it", "Pick any skin per weapon, only you see it") })
    local filter = main:AddDropdown("SkinRarities", {
        Text = T("Show rarities", "Show rarities"),
        Description = T("Empty shows everything", "Empty shows everything"),
        Values = Byte.Skin.Rarities,
        Multi = true,
        Default = {},
        AllowNull = true,
    })
    Byte.UI.Bind(filter, "SkinRarities")
    filter:OnChanged(function()
        for _, refill in ipairs(Byte.UI.SkinRefill) do refill() end
    end)
    main:AddButton({ Text = T("Reset all skins", "Reset all skins"), Style = "Warning", Func = function()
        Byte.Skin.ClearAll()
        for _, kind in ipairs(Byte.Skin.Types) do
            local picker = Library.Options["Skin" .. kind .. "Pick"]
            if picker then picker:SetValue(nil) end
        end
    end })

    local leftRows, rightRows = Byte.Config.SkinMainRows, 0
    for _, kind in ipairs(Byte.Skin.Types) do
        local left = leftRows < rightRows
        Util.Try("skins " .. kind, Byte.UI.BuildSkinGroup, tab, kind, left)
        if left then
            leftRows += Byte.Config.SkinGroupRows
        else
            rightRows += Byte.Config.SkinGroupRows
        end
    end
end



function Byte.UI.SellSet(keep)
    local kept, sell = Util.SetFromList(keep), {}
    for _, rarity in ipairs(Byte.Sell.Rarities()) do
        if not kept[rarity] then sell[rarity] = true end
    end
    return sell
end

function Byte.UI.KeepFromSold(sold)
    local selling, keep = Util.SetFromList(sold), {}
    for _, rarity in ipairs(Byte.Sell.Rarities()) do
        if not selling[rarity] then table.insert(keep, rarity) end
    end
    return keep
end

function Byte.UI.AdoptOldSellSave(group, keep)
    local old = group:AddDropdown("SellRarities", {
        Text = T("Sell rarities", "Sell rarities"),
        Values = Byte.Sell.Rarities(),
        Multi = true,
        Default = {},
        AllowNull = true,
    })
    if not old then return end
    pcall(function() if old.SetVisible then old:SetVisible(false) end end)
    pcall(function() old.Serialize = false end)
    pcall(function()
        old.Deserialize = function(_, saved)
            if keep and keep.SetValue then keep:SetValue(Byte.UI.KeepFromSold(saved)) end
        end
    end)
end

function Byte.UI.BuildEconomy(window)
    local tab = window:AddTab(T("Economy", "Economy"), "coins", T("Cases, selling, quests", "Cases, selling, quests"))

    local cases = tab:AddLeftGroupbox(T("Cases", "Cases"), "box")
    cases:AddToggle("AutoOpenCases", { Text = T("Auto open owned cases", "Auto open owned cases"), Default = false })
    cases:AddSlider("OpenCount", { Text = T("Open per case", "Open per case"), Min = 1, Max = 10, Default = 1 })
    cases:AddButton({ Text = T("Open All Now", "Open All Now"), Callback = Byte.UI.Detach(function()
        Byte.UI.Notice(T("Cases", "Cases"), Byte.Shop.OpenAllNow(), "Coin")
    end) })

    local sell = tab:AddRightGroupbox(T("Sell", "Sell"), "shop")
    local keep = sell:AddDropdown("KeepRarities", {
        Text = T("Never sell", "Never sell"),
        Values = Byte.Sell.Rarities(),
        Multi = true,
        Default = {},
        AllowNull = true,
    })
    Byte.UI.Bind(keep, "SellRarities", Byte.UI.SellSet)
    Byte.UI.AdoptOldSellSave(sell, keep)
    sell:AddToggle("AutoSell", { Text = T("Auto sell", "Auto sell"), Default = false })
    sell:AddSlider("MaxSellPrice", { Text = T("Max price to sell", "Max price to sell"), Tooltip = T("Keeps anything worth more (0 = no limit)", "Keeps anything worth more (0 = no limit)"), Min = 0, Max = 100000, Default = 500 })
    sell:AddSlider("KeepPerRarity", { Text = T("Keep per rarity", "Keep per rarity"), Min = 0, Max = 20, Default = 0 })
    sell:AddButton({ Text = T("Sell Now", "Sell Now"), Callback = Byte.UI.Detach(function()
        Byte.UI.Notice(T("Sell", "Sell"), Byte.Sell.SellNow(), "Coin")
    end) })
    sell:AddButton({ Text = T("Refresh rarities", "Refresh rarities"), Callback = Byte.UI.Detach(function()
        if keep and keep.SetValues then pcall(keep.SetValues, keep, Byte.Sell.Rarities()) end
        Byte.Options.SellRarities = Byte.UI.SellSet(keep and keep.Value)
    end) })

    local quest = tab:AddLeftGroupbox(T("Quests", "Quests"), "list")
    quest:AddToggle("AutoClaimQuest", { Text = T("Auto claim quests", "Auto claim quests"), Default = false })
    quest:AddButton({ Text = T("Claim Now", "Claim Now"), Callback = Byte.UI.Detach(function()
        Byte.UI.Notice(T("Quests", "Quests"), Byte.Collect.ClaimNow(), "Success")
    end) })
end

function Byte.UI.ShowHalted()
    local queue = Byte.State.Halted
    if #queue == 0 then return end
    local stopped = table.clone(queue)
    table.clear(queue)

    for _, halt in ipairs(stopped) do
        local name, reason, toggles = halt[1], halt[2], halt[3]
        for _, key in ipairs(toggles) do
            local toggle = Byte.UI.Get(key)
            if toggle and toggle.Value == true then
                Util.Try("halt " .. key, toggle.SetValue, toggle, false)
            end
        end
        Library:Notify("Byte", name .. " stopped: " .. reason, 6, "Error")
    end
end

function Byte.UI.ShowNotices()
    local queue = Byte.State.Notices
    if #queue == 0 then return end
    local pending = table.clone(queue)
    table.clear(queue)
    for _, notice in ipairs(pending) do
        Library:Notify(notice[1], notice[2], 4, notice[3])
    end
end

function Byte.UI.Pump()
    Util.Try("halts", Byte.UI.ShowHalted)
    Util.Try("notices", Byte.UI.ShowNotices)
end

function Byte.UI.BlockMissing()
    local unsupported = T("Not available on this executor", "Not available on this executor")
    local outdated = T("Changed by a game update, wait for a script update", "Changed by a game update, wait for a script update")
    for module, features in pairs(Byte.Config.ModuleFeatures) do
        local missing = GameLib.Missing[module]
        if not missing then continue end
        for _, idx in ipairs(features) do
            Library.Compat.Block(idx, missing == "Absent" and outdated or unsupported)
        end
    end

    if not Byte.Movement.FindDash() then
        warn("[Byte] module CombatHelper.Dash not found, Infinite dash is blocked")
        Library.Compat.Block("InfiniteDash", outdated)
    end
end

function Byte.UI.Build()
    local window = Library.Window

    Util.Try("combat tab", Byte.UI.BuildCombat, window)
    Util.Try("player tab", Byte.UI.BuildPlayer, window)
    Util.Try("skins tab", Byte.UI.BuildSkins, window)
    Util.Try("economy tab", Byte.UI.BuildEconomy, window)

    Util.Try("settings tab", function()
        if window.CreateSettingsTab then
            local settings = window:CreateSettingsTab()
            if ThemeManager and ThemeManager.ApplyToTab and settings then
                pcall(function() ThemeManager:ApplyToTab(settings) end)
            end
            if SaveManager and SaveManager.BuildConfigSection and settings then
                pcall(function() SaveManager:BuildConfigSection(settings) end)
            end
        elseif window.AddSettingsTab then
            window:AddSettingsTab()
        end
    end)

    for _, key in ipairs({ "AimFov", "AimBone", "AimPriority", "AimMaxDistance",
        "Aimbot", "AimSmooth", "AimPrediction", "ShowFov", "AimWallCheck", "AimTeamCheck",
        "SilentAim", "Ragebot", "InstantScope", "HitChance", "HeadChance", "TriggerBot", "NoRecoil", "NoSpread",
        "FastRespawn", "InfiniteDash", "SkinChanger", "OpenCount", "MaxSellPrice", "KeepPerRarity",
        "AutoOpenCases", "AutoSell", "AutoClaimQuest" }) do
        local widget = Byte.UI.Get(key)
        if widget then Util.Try("bind " .. key, Byte.UI.Bind, widget, key) end
    end
    Util.Try("missing modules", Byte.UI.BlockMissing)
    Byte:Connect(RunService.RenderStepped, Byte.Combat.DrawCircle)

    Library:Every(Byte.Config.StatusInterval, Byte.UI.Pump)
end

local function BuildInterface()
    local lib, theme, save = Util.LoadViz()
    if not lib then return false end
    Library = lib
    Byte.Library = lib
    ThemeManager = theme
    SaveManager = save

    T = function(en, th) return en end

    local caps = {}
    local function TryHas(fn) local ok, v = pcall(fn) return ok and v == true end
    caps.Drawing = TryHas(function() return Drawing ~= nil and Drawing.new ~= nil end)
    caps.HookFunction = TryHas(function() return type(hookfunction) == "function" end)
    caps.Namecall = TryHas(function() return type(hookmetamethod) == "function" end)
    caps.Gc = TryHas(function() return type(getgc) == "function" end)
    caps.Upvalues = TryHas(function() return type(getupvalues) == "function" end)
        or TryHas(function() return type(debug.getupvalues) == "function" end)
    caps.Connections = TryHas(function() return type(getconnections) == "function" end)
    caps.FileSystem = TryHas(function() return type(writefile) == "function" end)
    caps.Touch = true

    Library.Compat = {
        Caps = caps,
        NeedCap = function() end,
        Block = function(id, reason)
            local widget = Byte.UI.Get(id)
            if widget then
                if widget.SetDisabled then pcall(widget.SetDisabled, widget, true) end
                if widget.SetVisible then pcall(widget.SetVisible, widget, false) end
            end
            warn("[Byte] " .. id .. " blocked: " .. tostring(reason))
        end,
    }

    local everyConnections = {}
    function Library:Every(interval, fn)
        local acc = 0
        local conn = RunService.Heartbeat:Connect(function(dt)
            acc += dt
            if acc >= interval then
                acc = 0
                pcall(fn)
            end
        end)
        everyConnections[#everyConnections + 1] = conn
        return conn
    end

    function Library:Notify(title, text, duration, kind)
        local win = Library.Window
        if win and win.Notify then
            local ok, err = pcall(function()
                win:Notify({
                    Title = tostring(title),
                    Content = tostring(text),
                    Icon = (kind == "Error" and "x") or (kind == "Success" and "check") or "bell",
                })
            end)
            if ok then return end
            warn("[Byte] notify: " .. tostring(err))
        end
        pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = tonumber(duration) or 4,
        })
    end

    function Library:LoadAutoloadConfig()
        if SaveManager and SaveManager.LoadAutoloadConfig then
            pcall(SaveManager.LoadAutoloadConfig, SaveManager)
        end
    end

    if not Library.Unload then
        function Library:Unload() end
    end

    if ThemeManager and ThemeManager.SetLibrary then
        pcall(function()
            ThemeManager:SetLibrary(Library)
            ThemeManager:SetFolder(Byte.Config.SaveFolder)
            ThemeManager:LoadDefault()
        end)
    end
    if SaveManager and SaveManager.SetLibrary then
        pcall(function()
            SaveManager:SetLibrary(Library)
            SaveManager:SetFolder(Byte.Config.SaveFolder)
        end)
    end

    local window
    local ok, err = pcall(function()
        window = Library:CreateWindow({
            Title = "Byte",
            SubTitle = "by xDTaraZ",
            MenuKey = Enum.KeyCode.LeftControl,
            Layout = "Bottom bar",
            AutoHide = false,
            NotificationPosition = "BottomRight",
        })
    end)
    if not ok or not window then
        Util.Alert("The menu failed to load on this executor: " .. tostring(err), err)
        return false
    end
    Library.Window = window

    Util.Try("ui build", Byte.UI.Build)

    if Library.OnUnload then
        pcall(function() Library:OnUnload(function() Byte:Unload() end) end)
    end

    task.defer(Util.Try, "boot", Byte.Boot)
    task.defer(Util.Try, "autoload config", function()
        if SaveManager and SaveManager.LoadAutoloadConfig then
            pcall(SaveManager.LoadAutoloadConfig, SaveManager)
        end
    end)

    return true
end

function Byte.BuildWatermark()
    local Stats = game:GetService("Stats")

    local WatermarkGui = Instance.new("ScreenGui")
    WatermarkGui.Name = "ByteWatermark"
    WatermarkGui.ResetOnSpawn = false
    WatermarkGui.IgnoreGuiInset = true
    WatermarkGui.DisplayOrder = 999
    local parentGui = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    pcall(function() WatermarkGui.Parent = parentGui end)
    if not WatermarkGui.Parent then
        WatermarkGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local Main = Instance.new("Frame")
    Main.Size = UDim2.fromOffset(0, 32)
    Main.AutomaticSize = Enum.AutomaticSize.X
    Main.Position = UDim2.new(0.5, 0, 0, 10)
    Main.AnchorPoint = Vector2.new(0.5, 0)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Main.BackgroundTransparency = 0.1
    Main.BorderSizePixel = 0
    Main.Parent = WatermarkGui

    local MainLayout = Instance.new("UIListLayout")
    MainLayout.FillDirection = Enum.FillDirection.Horizontal
    MainLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MainLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    MainLayout.Padding = UDim.new(0, 8)
    MainLayout.Parent = Main

    local MainPadding = Instance.new("UIPadding")
    MainPadding.PaddingLeft = UDim.new(0, 10)
    MainPadding.PaddingRight = UDim.new(0, 14)
    MainPadding.Parent = Main

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = Main

    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(50, 50, 50)
    Stroke.Thickness = 1
    Stroke.Parent = Main

    local Logo = Instance.new("ImageLabel")
    Logo.Size = UDim2.fromOffset(20, 20)
    Logo.BackgroundTransparency = 1
    Logo.Image = "rbxassetid://95943456246483"
    Logo.ScaleType = Enum.ScaleType.Fit
    Logo.Parent = Main

    local Name = Instance.new("TextLabel")
    Name.Size = UDim2.fromOffset(0, 32)
    Name.AutomaticSize = Enum.AutomaticSize.X
    Name.BackgroundTransparency = 1
    Name.Text = "Byte"
    Name.TextColor3 = Color3.new(1, 1, 1)
    Name.TextSize = 14
    Name.Font = Enum.Font.GothamBold
    Name.TextXAlignment = Enum.TextXAlignment.Left
    Name.LayoutOrder = 2
    Name.Parent = Main

    local Info = Instance.new("TextLabel")
    Info.Size = UDim2.fromOffset(0, 32)
    Info.AutomaticSize = Enum.AutomaticSize.X
    Info.BackgroundTransparency = 1
    Info.TextColor3 = Color3.fromRGB(220, 220, 220)
    Info.TextSize = 13
    Info.Font = Enum.Font.Gotham
    Info.TextXAlignment = Enum.TextXAlignment.Left
    Info.LayoutOrder = 3
    Info.Parent = Main

    local function GetServerRegion()
        local ok, attr = pcall(function() return LocalPlayer:GetAttribute("ServerRegion") end)
        if ok and type(attr) == "string" and attr ~= "" then return attr end

        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, desc in ipairs(playerGui:GetDescendants()) do
                if desc:IsA("TextLabel") and desc.Text ~= "" then
                    local region = desc.Text:match("Server Region:%s*(.+)")
                    if not region and desc.Text:match("^United States$") then
                        region = "United States"
                    end
                    if not region and desc.Text:match("^Singapore$") then
                        region = "Singapore"
                    end
                    if not region and desc.Text:match("^Germany$") then
                        region = "Germany"
                    end
                    if not region and desc.Text:match("^Brazil$") then
                        region = "Brazil"
                    end
                    
                    if region then return region end
                end
            end
        end

        local gameService = Byte.GameLib.Service.GameService
        if gameService and gameService.GetServerRegion then
            local ok, region = pcall(function() return gameService.GetServerRegion() end)
            if ok and type(region) == "string" and region ~= "" then return region end
        end

        local jid = game.JobId
        if jid and #jid > 0 then return string.upper(string.sub(jid, 1, 4)) end
        return "Unknown"
    end

    local cachedRegion = GetServerRegion()
    task.spawn(function()
        while task.wait(15) do
            cachedRegion = GetServerRegion()
        end
    end)

    local frames = 0
    local lastUpdate = os.clock()
    Byte.State.WatermarkConnection = Byte:Connect(RunService.RenderStepped, function()
        frames = frames + 1
        local now = os.clock()
        if now - lastUpdate >= 1 then
            local realPing = 0
            local pingStat = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
            if pingStat then
                local ok, v = pcall(function() return pingStat:GetValue() end)
                if ok and type(v) == "number" then realPing = math.floor(v) end
            end

            Info.Text = string.format("%s | %d FPS | %d MS | %s",
                os.date("%H:%M:%S"),
                math.floor(frames / (now - lastUpdate)),
                realPing,
                cachedRegion)

            frames = 0
            lastUpdate = now
        end
    end)

    local dragging, dragStart, startPos
    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    Byte.State.WatermarkGui = WatermarkGui
end

function Byte.Boot()
    pcall(Byte.BuildWatermark)

    Byte:Connect(LocalPlayer.CharacterAdded, function(character)
        Byte.Player.Respawn.Reset()
        Byte.Player:Bind(character)
    end)

    Util.Try("movement", Byte.Movement.Start)

    Byte.Scheduler.Every("Combat", 0.03, Byte.Combat.Step, Byte.Config.CombatToggles, Byte.Combat.Rest)
    Byte.Scheduler.Every("ESP", Byte.Config.EspInterval, Byte.Esp.Step)
    Byte.Scheduler.Every("Fast Respawn", 0.1, Byte.Player.Respawn.Step, { "FastRespawn" })
    Byte.Scheduler.Every("Auto Join", 1, Byte.Player.Join.Step, { "AutoJoin" })
    Byte.Scheduler.Every("Skin Changer", 0.5, Byte.Skin.Step, { "SkinChanger" }, Byte.Skin.Restore)
    Byte.Scheduler.Every("Auto Open Cases", Byte.Config.EconomyInterval, Byte.Shop.Step, { "AutoOpenCases" })
    Byte.Scheduler.Every("Auto Sell", Byte.Config.EconomyInterval, Byte.Sell.Step, { "AutoSell" })
    Byte.Scheduler.Every("Auto Claim Quests", Byte.Config.EconomyInterval, Byte.Collect.Step, { "AutoClaimQuest" })
    Util.Try("scheduler", Byte.Scheduler.Boot)
end

function Byte:Unload()
    self.State.Alive = false
    for key, value in pairs(self.Options) do
        if value == true then self.Options[key] = false end
    end
    Byte.Combat.Unload()
    if Byte.Skin and Byte.Skin.Stop then Byte.Skin.Stop() end
    if Byte.Skin and Byte.Skin.Restore then pcall(Byte.Skin.Restore) end
    if Byte.EspDrawing then Byte.EspDrawing.Clear() end
    for _, connection in ipairs(self.State.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.State.Connections)

    local overlay = self.State.Overlay
    self.State.Overlay = nil
    if overlay then overlay:Destroy() end

    if self.State.WatermarkGui then
        pcall(function() self.State.WatermarkGui:Destroy() end)
        self.State.WatermarkGui = nil
    end
    self.State.WatermarkConnection = nil

    if environment.ByteUnload == Byte.UnloadHook then environment.ByteUnload = nil end
end

function Byte.UnloadHook()
    if Byte.Library and not Byte.Library.Unloaded then
        Byte.Library:Unload()
    else
        Byte:Unload()
    end
end

environment.ByteUnload = Byte.UnloadHook

if LocalPlayer.Character then
    Byte.Player:Bind(LocalPlayer.Character)
end

BuildInterface()
