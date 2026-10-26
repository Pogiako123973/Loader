local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title = "Byte",
    Size = Vector2.new(740, 660),
    Layout = "Bottom bar",
    MenuKey = Enum.KeyCode.RightShift,
    DPIScale = 1,
    NotificationPosition = "BottomRight",
})
getgenv().Library = Library
getgenv().Window = Window
Library.MenuOpen = true

local Tabs = {
    Combat = Window:AddTab("Combat", "crosshair"),
    Visuals = Window:AddTab("Visuals", "eye"),
    World = Window:AddTab("World", "globe"),
    Misc = Window:AddTab("Misc", "gun"),
    Optimizations = Window:AddTab("Optimizations", "zap"),
    Settings = Window:CreateSettingsTab(),
}

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local HttpService = cloneref(game:GetService("HttpService"))
local TweenService = cloneref(game:GetService("TweenService"))
local Lighting = cloneref(game:GetService("Lighting"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local TeleportService = game:GetService("TeleportService")

local gethui = gethui or get_hui or get_hidden_gui or function() return CoreGui end
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = cloneref(LocalPlayer:GetMouse())
local FirstPerson = workspace:FindFirstChild("ViewModels") and workspace.ViewModels:FindFirstChild("FirstPerson")

local function SafeRequire(parent, name)
    local m = parent and parent:FindFirstChild(name)
    if not m then return nil end
    local ok, res = pcall(require, m)
    return ok and res or nil
end

local function byte_debug(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    pcall(function() warn("[Byte Debug] " .. table.concat(parts, " ")) end)
end
getgenv().byte_debug = byte_debug

local Modules = ReplicatedStorage:FindFirstChild("Modules")
local item_lib = SafeRequire(Modules, "ItemLibrary")
local cosmetic_lib = SafeRequire(Modules, "CosmeticLibrary")
local enum_lib = SafeRequire(Modules, "EnumLibrary")
local utility = SafeRequire(Modules, "Utility")
local rep_class = SafeRequire(Modules, "ReplicatedClass")
local finishers = SafeRequire(Modules, "Finishers")
local tracer_effect = SafeRequire(LocalPlayer.PlayerScripts.Modules, "TracerEffect")

local fighter_controller = SafeRequire(LocalPlayer.PlayerScripts.Controllers, "FighterController")
local camera_controller = SafeRequire(LocalPlayer.PlayerScripts.Controllers, "CameraController")
local mechanics_controller = SafeRequire(LocalPlayer.PlayerScripts.Controllers, "MechanicsController")
local controls_controller = SafeRequire(LocalPlayer.PlayerScripts.Controllers, "ControlsController")
local player_data_controller = SafeRequire(LocalPlayer.PlayerScripts.Controllers, "PlayerDataController")
local local_fighter = fighter_controller and fighter_controller.LocalFighter

local gun = SafeRequire(LocalPlayer.PlayerScripts.Modules.ItemTypes, "Gun")
local melee = SafeRequire(LocalPlayer.PlayerScripts.Modules.ItemTypes, "Melee")
local katana = SafeRequire(LocalPlayer.PlayerScripts.Modules.Items, "Katana")
local client_viewmodel = SafeRequire(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem, "ClientViewModel")
local client_item = SafeRequire(LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter, "ClientItem")

local function notify(content, duration, title)
    pcall(function()
        Window:Notify({
            Title = title or "Byte",
            Content = tostring(content),
            Duration = duration or 3,
        })
    end)
end

local Signals = {}
local function giveSignal(conn)
    table.insert(Signals, conn)
    return conn
end
local function clearSignals()
    for _, c in ipairs(Signals) do pcall(function() c:Disconnect() end) end
    table.clear(Signals)
end

local UIColors = {
    MainColor = Color3.fromRGB(24, 24, 24),
    BackgroundColor = Color3.fromRGB(15, 15, 15),
    AccentColor = Color3.fromRGB(166, 93, 103),
    OutlineColor = Color3.new(0, 0, 0),
    FontColor = Color3.fromRGB(224, 212, 214),
}
local UIFont = Enum.Font.Code

local function CreateInst(class, props)
    local inst = type(class) == "string" and Instance.new(class) or class
    if props then for k, v in pairs(props) do inst[k] = v end end
    if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
        if not props or not props.Font then inst.Font = UIFont end
    end
    return inst
end

local function GetTextBounds(text, font, size, resolution)
    local clean = text:gsub("<br%s*/>", "\n"):gsub("<[^<>]->", "")
    local b = game:GetService("TextService"):GetTextSize(clean, size, font, resolution or Vector2.new(1920, 1080))
    return b.X, b.Y
end

local function MakeDraggable(instance, cutoff)
    cutoff = cutoff or 40
    local dragging, startPos, startInput = false, nil, nil
    giveSignal(instance.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if input.Position.Y - instance.AbsolutePosition.Y <= cutoff then
                dragging, startPos, startInput = true, instance.Position, input.Position
            end
        end
    end))
    giveSignal(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - startInput
            instance.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
    giveSignal(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
end

local function SetAccentTitle(label, text, accentPart)
    if not label then return end
    text, accentPart = text or "", accentPart or ""
    if accentPart == "" or not text:find(accentPart, 1, true) then
        label.RichText = false
        label.Text = text
        return
    end
    local i = text:find(accentPart, 1, true)
    local before, after = text:sub(1, i - 1), text:sub(i + #accentPart)
    local hex = UIColors.AccentColor:ToHex()
    label.RichText = true
    label.Text = string.format('<font color="#ffffff">%s</font><font color="#%s">%s</font><font color="#ffffff">%s</font>', before, hex, accentPart, after)
end

Library.RegistryMap = Library.RegistryMap or setmetatable({}, { __index = function() return { Properties = {} } end })
Library.AddToRegistry = Library.AddToRegistry or function() end
Library.RemoveFromRegistry = Library.RemoveFromRegistry or function() end
Library.GetDarkerColor = Library.GetDarkerColor or function(c) local h,s,v = Color3.toHSV(c); return Color3.fromHSV(h, s, v/1.5) end
Library.GetLighterColor = Library.GetLighterColor or function(c) local h,s,v = Color3.toHSV(c); return Color3.fromHSV(h, s*0.8, math.min(v*1.2,1)) end
Library.GetTextBounds = Library.GetTextBounds or GetTextBounds
Library.MakeDraggable = Library.MakeDraggable or MakeDraggable
Library.Create = Library.Create or CreateInst
Library.SetAccentTitle = Library.SetAccentTitle or SetAccentTitle
Library.ApplyPopupZIndex = Library.ApplyPopupZIndex or function() end

local ELI = {
    silent_aim = {
        enable=false, visualize=false, closest_part=false, hit_chance=100, riot_shield=false,
        show_fov=false, show_fill=false, fov_radius=180, lerp=0,
        follow_target=false, follow_gunpoint=false,
        fov_color=Color3.fromRGB(0,255,0), fov_color2=Color3.fromRGB(255,255,255),
        fov_fill_color=Color3.fromRGB(0,255,0), fov_fill_color2=Color3.fromRGB(255,255,255),
        fov_fill_transparency=0.6, fov_outline_transparency=0.2, fov_thickness=2, fov_rotation_speed=90,
    },
    aimbot = {
        enable=false, closest_part=false, smoothing=1, lerp=0,
        show_fov=false, show_fill=false, fov_radius=180,
        follow_target=false, follow_gunpoint=false,
        fov_color=Color3.fromRGB(0,255,0), fov_color2=Color3.fromRGB(255,255,255),
        fov_fill_color=Color3.fromRGB(0,255,0), fov_fill_color2=Color3.fromRGB(255,255,255),
        fov_fill_transparency=0.6, fov_outline_transparency=0.2, fov_thickness=2, fov_rotation_speed=90,
    },
    targeting = { max_distance=100, part="Head", visible_only=false, anti_katana=false, riot_shield=false, auto_shoot=false },
    triggerbot = { enable=false, team_check=false, reaction_time=0.05, shoot_delay=0.1, max_distance=500 },
    guns = { no_muzzle_flash=false, no_spread=false, force_modifier_enable=false, force_modifier_v=0, fast_fire=false },
    melee = { fast_swing=false },
    ragebot = { enable=false, ffa_mode=false, x=7, y=7, z=7, prediction=true, prediction_amount=1 },
    chams = {
        enable=false, team_check=false, mode="highlight",
        fill_color=Color3.fromRGB(0,170,255), fill_transparency=0.5,
        outline_color=Color3.fromRGB(255,255,255), outline_transparency=0,
        material="Neon", strip_textures=false, ghost=false,
    },
    hit_notify = { enable=false, duration=3, msg="Hit {target} for {damage}" },

    world = { anti_flashbang=false },
    camera = { third_person=false, stretched_res=false, stretched_res_amount=0.20, fov_changer=false, fov=80 },
    character = { fly=false, fly_speed=50 },
    movement = {
        walkspeed=false, walkspeed_multiplier=1.5,
        slide_boost=false, slide_boost_speed=60,
        infinite_double_jump=false, double_jump_height=false, double_jump_height_value=50,
        auto_slide=false,
    },
    device_spoof = { enable=false, type="MouseKeyboard" },
    auto_loadout = { enable=false, loadout={"Assault Rifle","Handgun","Fists","Grenade"} },
    auto_queue = { enable=false, queue_mode="" },
    auto_vote_map = { enable=false, map="" },
    spoof = {
        level={enable=false, value=9}, streak={enable=false, value=9},
        player_status={enable=false, select=""},
    },
    rank_spoof = { enable=false, rank="Arch Nemesis" },
    elo_spoof = { enable=false, value=60000 },
    name_spoof = { enable=false, display="", username="" },
    optimizations = {
        no_particles=false, no_shadows=false, no_postfx=false,
        low_quality=false, no_atmosphere=false, no_textures=false,
        fps_cap_enable=false, fps_cap=60,
    },
    cosmetic = {},
}
getgenv().byte = ELI
getgenv().silent_load = false
getgenv().ByteUnloaded = false

local spoof_old = {
    level = LocalPlayer:GetAttribute("Level"),
    streak = LocalPlayer:GetAttribute("StatisticDuelsWinStreak"),
    playerstatus = LocalPlayer:GetAttribute("PlayerStatus"),
    elo = LocalPlayer:GetAttribute("DisplayELO"),
}

local deflecting = {}
local function is_deflecting(plr) return deflecting[plr] end
local function has_riot(plr)
    if not plr then return false end
    local vm = workspace:FindFirstChild("ViewModels")
    if not vm then return false end
    return vm:FindFirstChild(plr.Name .. " - Riot Shield - Riot Shield") ~= nil
end

local function check_wall(part)
    if not part or not part.Parent then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, part.Parent }
    local result = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, params)
    return result == nil
end

local function closest_part(plr)
    if not plr or not plr.Character then return nil end
    local mouse_pos = Vector2.new(Mouse.X, Mouse.Y)
    local closest, closestp = math.huge, nil
    for _, v in ipairs(plr.Character:GetChildren()) do
        if v:IsA("BasePart") then
            local pos, on = Camera:WorldToViewportPoint(v.Position)
            if on then
                local d = (mouse_pos - Vector2.new(pos.X, pos.Y)).Magnitude
                if d <= closest then closest, closestp = d, v end
            end
        end
    end
    return closestp
end

local function getclosest()
    local closest = ELI.targeting.max_distance
    local player
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            local part = v.Character:FindFirstChild(ELI.targeting.part)
            local hum = v.Character:FindFirstChildOfClass("Humanoid")
            if part and hum and hum.Health > 0 then
                if not is_deflecting(v)
                    and v:GetAttribute("TeamID") ~= LocalPlayer:GetAttribute("TeamID")
                    and (not ELI.targeting.visible_only or check_wall(part))
                    and (not ELI.targeting.riot_shield or not has_riot(v)) then
                    local pos, on = Camera:WorldToViewportPoint(part.Position)
                    if on then
                        local d = (center - Vector2.new(pos.X, pos.Y)).Magnitude
                        if d < closest and d <= ELI.silent_aim.fov_radius then
                            player, closest = v, d
                        end
                    end
                end
            end
        end
    end
    return player
end

local function getclosest2()
    local closest = ELI.targeting.max_distance
    local player
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, v in ipairs(Players:GetPlayers()) do
        if v ~= LocalPlayer and v.Character then
            local part = v.Character:FindFirstChild(ELI.targeting.part)
            local hum = v.Character:FindFirstChildOfClass("Humanoid")
            if part and hum and hum.Health > 0 then
                if v:GetAttribute("TeamID") ~= LocalPlayer:GetAttribute("TeamID")
                    and not is_deflecting(v)
                    and (not ELI.targeting.visible_only or check_wall(part))
                    and (not ELI.targeting.riot_shield or not has_riot(v)) then
                    local pos, on = Camera:WorldToViewportPoint(part.Position)
                    if on then
                        local d = (center - Vector2.new(pos.X, pos.Y)).Magnitude
                        if d < closest and d < ELI.aimbot.fov_radius then
                            player, closest = v, d
                        end
                    end
                end
            end
        end
    end
    return player
end

if katana and katana._StartDeflecting then
    local old = katana._StartDeflecting
    katana._StartDeflecting = function(...)
        local args = { ... }
        local fighter = args[1] and args[1].ClientFighter
        local plr = fighter and fighter.Player
        if plr then
            deflecting[plr] = true
            task.delay(args[1].Info and args[1].Info.DeflectDuration or 0.1, function()
                deflecting[plr] = false
            end)
        end
        return old(table.unpack(args))
    end
    giveSignal({ Disconnect = function() katana._StartDeflecting = old end })
end

if utility and utility.Raycast then
    local old_raycast = utility.Raycast
    utility.Raycast = function(...)
        if ELI.silent_aim.enable and debug.info(3, "n") == "StartShooting" then
            if math.random(1, 100) <= ELI.silent_aim.hit_chance then
                local closest = getclosest()
                if closest and closest.Character then
                    local target_pos
                    if ELI.silent_aim.closest_part then
                        local part = closest_part(closest)
                        target_pos = part and part.Position
                    else
                        local char = closest.Character
                        local ap = char:FindFirstChild(ELI.targeting.part) or char:FindFirstChild("HitboxHead") or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                        target_pos = ap and ap.Position
                    end
                    if target_pos then
                        local args = { ... }
                        args[3] = target_pos
                        return old_raycast(table.unpack(args))
                    end
                end
            end
        end
        return old_raycast(...)
    end
    giveSignal({ Disconnect = function() utility.Raycast = old_raycast end })
end

local old_force_auto = {}
local fast_fire_dumping = false
if gun and gun.StartShooting then
    local old = gun.StartShooting
    gun.StartShooting = function(controller, is_empty, debounce)
        if not controller.ClientFighter or not controller.ClientFighter.IsLocalPlayer then
            return old(controller, is_empty, debounce)
        end
        if not is_empty and controller:Get("Ammo") <= 0 then return false end

        if ELI.guns.fast_fire and not is_empty then
            controller._shoot_cooldown = 0
            controller._is_revolver_quick_shooting = 0
            controller._reload_cooldown = 0
            controller._reload_cancel_cooldown = 0

            local result = { old(controller, is_empty, debounce) }
            controller._shoot_cooldown = 0

            if not fast_fire_dumping then
                fast_fire_dumping = true
                task.spawn(function()
                    while ELI.guns.fast_fire and not controller:IsEquipping() do
                        local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) 
                                     or UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch)
                        
                        if not holding then break end

                        local current_ammo = controller:Get("Ammo")
                        if controller._shot_but_ammo_hasnt_updated then
                            current_ammo = math.max(0, current_ammo - 1)
                        end
                        
                        if current_ammo <= 0 then break end

                        controller._shoot_cooldown = 0
                        pcall(function() controller.ClientFighter:Input("StartShooting") end)
                        
                        task.wait(0.02) 
                    end
                    fast_fire_dumping = false
                end)
            end

            if ELI.guns.no_spread then result[4] = true end
            return unpack(result)
        end

        local result = { old(controller, is_empty, debounce) }
        if ELI.guns.no_spread then result[4] = true end
        return unpack(result)
    end
    giveSignal({ Disconnect = function() gun.StartShooting = old end })
end

local fast_melee_dumping = false
if melee and melee.StartShooting then
    local old_melee = melee.StartShooting
    melee.StartShooting = function(controller, is_empty, attack_enum)
        if not controller.ClientFighter or not controller.ClientFighter.IsLocalPlayer then
            return old_melee(controller, is_empty, attack_enum)
        end

        if ELI.melee.fast_swing and not is_empty then
            controller._attack_cooldown = 0
            local result = { old_melee(controller, is_empty, attack_enum) }
            controller._attack_cooldown = 0

            if not fast_melee_dumping then
                fast_melee_dumping = true
                task.spawn(function()
                    while ELI.melee.fast_swing and not controller:IsEquipping() do
                        local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) 
                                     or UserInputService:IsMouseButtonPressed(Enum.UserInputType.Touch)
                        
                        if not holding then break end
                        if controller.Info.NeedsAmmoToAttack and controller:Get("Ammo") <= 0 then break end

                        controller._attack_cooldown = 0
                        pcall(function() controller.ClientFighter:Input("StartShooting") end)
                        
                        task.wait(0.04) 
                    end
                    fast_melee_dumping = false
                end)
            end
            return unpack(result)
        end

        return old_melee(controller, is_empty, attack_enum)
    end
    giveSignal({ Disconnect = function() melee.StartShooting = old_melee end })
end

if utility and utility.PlayParticles then
    local old = utility.PlayParticles
    utility.PlayParticles = function(s, p)
        if ELI.guns.no_muzzle_flash and p.Name == "_muzzle" then return end
        return old(s, p)
    end
    giveSignal({ Disconnect = function() utility.PlayParticles = old end })
end

giveSignal(RunService.Heartbeat:Connect(function()
    if ELI.aimbot.enable and camera_controller and camera_controller.MimicRotation then
        local closest = getclosest2()
        if closest and closest.Character and closest.Character:FindFirstChild(ELI.targeting.part) then
            local target_pos
            if ELI.aimbot.closest_part then
                local p = closest_part(closest)
                target_pos = p and p.Position or closest.Character[ELI.targeting.part].Position
            else
                target_pos = closest.Character[ELI.targeting.part].Position
            end
            pcall(function()
                camera_controller:MimicRotation(Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, target_pos), ELI.aimbot.smoothing))
            end)
        end
    end
end))

giveSignal(RunService.Heartbeat:Connect(function()
    if ELI.targeting.auto_shoot and local_fighter then
        local target = getclosest()
        if target and target.Character then
            setthreadidentity(2)
            pcall(function() local_fighter:Input("StartShooting") end)
            setthreadidentity(7)
        end
    end
end))

local triggerbot_shooting = false
giveSignal(task.spawn(function()
    while task.wait(0.05) do
        if not ELI.triggerbot.enable then continue end
        local hit = workspace:FindPartOnRayWithIgnoreList(
            Ray.new(Camera.CFrame.Position, Camera.CFrame.LookVector * 2500),
            { LocalPlayer.Character }
        )
        if hit and hit.Parent and hit.Parent:FindFirstChildWhichIsA("Humanoid") and hit.Parent.Humanoid.Health > 0 then
            local target_player = Players:GetPlayerFromCharacter(hit.Parent)
            if ELI.triggerbot.team_check and target_player
                and target_player:GetAttribute("TeamID") == LocalPlayer:GetAttribute("TeamID") then
                triggerbot_shooting = false
            else
                if not triggerbot_shooting then
                    task.wait(ELI.triggerbot.reaction_time)
                    triggerbot_shooting = true
                end
                if local_fighter then
                    setthreadidentity(2)
                    pcall(function() local_fighter:Input("StartShooting") end)
                    setthreadidentity(7)
                    task.wait(ELI.triggerbot.shoot_delay)
                end
            end
        else
            triggerbot_shooting = false
        end
    end
end))

local last_modifier_v = nil
giveSignal(RunService.Heartbeat:Connect(function()
    if not ELI.guns.force_modifier_enable then return end
    if last_modifier_v == ELI.guns.force_modifier_v then return end
    last_modifier_v = ELI.guns.force_modifier_v
    if item_lib and item_lib.Items then
        for _, v in pairs(item_lib.Items) do
            if v.InputSpammingEnabled then
                v.InputSpammingEnabled.StartShooting = ELI.guns.force_modifier_v
            end
        end
    end
end))

local RagebotService = { active=false, debounce=false, lastShot=0, connection=nil }
local DesyncService = { active=false, connection=nil, server=nil, client=nil, angle=0, speed=9000, fighter=local_fighter }

do
    local ref_update = camera_controller and camera_controller.Update
    if type(ref_update) == "function" then
        camera_controller.Update = function(...)
            if DesyncService.active and DesyncService.fighter and DesyncService.fighter.Entity and DesyncService.fighter.Entity.RootPart and DesyncService.client then
                DesyncService.fighter.Entity.RootPart.CFrame = DesyncService.client
            end
            return ref_update(...)
        end
        byte_debug("Hooked CameraController.Update")
    else
        byte_debug("CameraController.Update missing - desync camera-refresh disabled (harmless)")
    end
end

function DesyncService:Start(target)
    if self.active or not LocalPlayer.Character then return end
    if not self.fighter or not self.fighter.Entity.RootPart then return end
    self.active = true
    self.connection = RunService.Heartbeat:Connect(function()
        if not self.active then return end
        if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart")
            or not self.fighter or not self.fighter.Entity.RootPart then
            if self.client then self.fighter.Entity.RootPart.CFrame = self.client end
            self.active = false
            if self.connection then self.connection:Disconnect() end
            return
        end
        self.client = self.fighter.Entity.RootPart.CFrame
        local item = self.fighter.EquippedItem
        if not item then return end
        local targetPos = target.Character.HumanoidRootPart.Position
        if is_deflecting(target) or has_riot(target) then
            self.server = Vector3.new(0, 2^26, 0)
            return
        end
        if item.Name == "Slingshot" then
            self.server = Vector3.new(0, 2^26, 0)
        else
            self.server = targetPos + Vector3.new(ELI.ragebot.x, ELI.ragebot.y, ELI.ragebot.z)
        end
        self.fighter.Entity.RootPart.CFrame = CFrame.new(self.server)
    end)
    giveSignal(self.connection)
end

function DesyncService:Stop()
    if not self.active then return end
    if self.connection then self.connection:Disconnect(); self.connection = nil end
    if self.client and self.fighter and self.fighter.Entity.RootPart then
        self.fighter.Entity.RootPart.CFrame = self.client
    end
    self.active = false
    self.server = nil
    self.client = nil
end

function RagebotService:IsValid(plr)
    if not (plr and plr.Character and plr.Character:FindFirstChild("Humanoid")
        and plr.Character.Humanoid.Health > 0
        and plr:GetAttribute("EnvironmentID") == LocalPlayer:GetAttribute("EnvironmentID")) then
        return false
    end
    if not (plr.Character:FindFirstChild("HitboxHead") or plr.Character:FindFirstChild("Head")) then
        return false
    end
    if ELI.ragebot.ffa_mode then return true end
    return LocalPlayer:GetAttribute("TeamID") ~= plr:GetAttribute("TeamID")
end

function RagebotService:GetClosest()
    local closest, best = nil, math.huge
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and self:IsValid(plr) then
            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            local hp = plr.Character and (plr.Character:FindFirstChild("HitboxHead") or plr.Character:FindFirstChild("Head"))
            if hrp and hp then
                local pos, onScreen = Camera:WorldToViewportPoint(hp.Position)
                if onScreen then
                    local dist = (center - Vector2.new(pos.X, pos.Y)).Magnitude
                    if dist < best then closest, best = plr, dist end
                else
                    local d = LocalPlayer:DistanceFromCharacter(hp.Position)
                    if d < best then closest, best = plr, d end
                end
            end
        end
    end
    return closest
end

function RagebotService:FireWeapon(target)
    if not target or not target.Character or not local_fighter then return end
    if not utility or not enum_lib then byte_debug("FireWeapon: utility/enum_lib missing") return end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local repl = remotes and remotes:FindFirstChild("Replication")
    local fr = repl and repl:FindFirstChild("Fighter")
    local use_item = fr and fr:FindFirstChild("UseItem")
    if not use_item then byte_debug("FireWeapon: UseItem remote missing") return end
    local item = local_fighter.EquippedItem
    if not item or is_deflecting(target) or has_riot(target) then return end
    local head = target.Character:FindFirstChild("HitboxHead") or target.Character:FindFirstChild("Head")
    if not head then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local shootPos = DesyncService.active and DesyncService.server or LocalPlayer.Character.HumanoidRootPart.Position
    local aimPos = head.Position
    if ELI.ragebot.prediction then
        local troot = target.Character:FindFirstChild("HumanoidRootPart")
        if troot then
            local ping = 0.05
            pcall(function() ping = LocalPlayer:GetNetworkPing() end)
            aimPos = aimPos + troot.AssemblyLinearVelocity * math.clamp(ping, 0, 0.4) * (ELI.ragebot.prediction_amount or 1)
        end
    end
    local data = {
        [utf8.char(1)] = {
            [utf8.char(0)] = utility:EncodeCFrame(CFrame.new(shootPos, aimPos)),
            [utf8.char(1)] = utility:EncodeCFrame(CFrame.new(shootPos, aimPos)),
            [utf8.char(2)] = head,
        },
    }
    pcall(function()
        use_item:FireServer(item:Get("ObjectID"), enum_lib:ToEnum("StartShooting"), data, nil)
    end)
end

function RagebotService:Start()
    if self.connection then return end
    self.connection = RunService.Heartbeat:Connect(function()
        if not ELI.ragebot.enable then self:Stop() return end
        local target = self:GetClosest()
        if not target or not local_fighter then DesyncService:Stop() return end
        local item = local_fighter.EquippedItem
        if not item then DesyncService:Stop() return end
        if not fighter_controller or type(fighter_controller.GetFighter) ~= "function" then DesyncService:Stop() return end
        local tf = fighter_controller:GetFighter(target)
        if not tf or not tf.Entity or tf.Entity:Get("IsInvincible") then DesyncService:Stop() return end
        local vm = item.ViewModel
        if not vm then DesyncService:Stop() return end
        if item:Get("Ammo") and item:Get("Ammo") > 0 and not vm:IsAnimationPlaying("Reload") then
            if self.debounce == false then self.debounce = os.clock() + 0.5; return end
            if typeof(self.debounce) == "number" and os.clock() < self.debounce then return end
            if typeof(self.debounce) == "number" then self.debounce = true end
            DesyncService:Start(target)
            if DesyncService.server then self.lastShot = os.clock(); self:FireWeapon(target) end
        else
            if not vm:IsAnimationPlaying("Reload") then
                setthreadidentity(2); pcall(function() item:Input("StartReloading") end); setthreadidentity(7)
            end
        end
    end)
    giveSignal(self.connection)
end

function RagebotService:Stop()
    if self.connection then self.connection:Disconnect(); self.connection = nil end
    self.debounce = false    DesyncService:Stop()
end

giveSignal(workspace.DescendantAdded:Connect(function(child)
    if not ELI.ragebot.enable then return end
    if not (child:IsA("BasePart") or child:IsA("Model")) then return end
    if child.Name ~= "Slingshot" and child.Name ~= "CoreProjectile" and child.Name ~= "OuterProjectile" then return end
    task.spawn(function()
        task.wait(0.03)
        local proj = child:IsA("BasePart") and child or child:FindFirstChildWhichIsA("BasePart")
        if not proj then return end
        proj.CanTouch = true
        for _ = 1, 45 do
            if not ELI.ragebot.enable then break end
            local t = RagebotService:GetClosest()
            if t and t.Character then
                local hp = t.Character:FindFirstChild("HitboxHead") or t.Character:FindFirstChild("HumanoidRootPart")
                if hp and hp:IsA("BasePart") and hp.Parent and proj.Parent
                    and hp:IsDescendantOf(workspace) and proj:IsDescendantOf(workspace) then
                    pcall(firetouchinterest, hp, proj, 0)
                    pcall(firetouchinterest, hp, proj, 1)
                end
            end
            task.wait()
        end
    end)
end))

local chams_highlights, chams_bodies = {}, {}
local chams_material_presets = {
    Neon = { material = Enum.Material.Neon },
    ForceField = { material = Enum.Material.ForceField },
    Glass = { material = Enum.Material.Glass, reflectance = 0.10, transparency = 0.20 },
    Chrome = { material = Enum.Material.Metal, reflectance = 1.00 },
    Ice = { material = Enum.Material.Ice, reflectance = 0.35 },
    Ghost = { material = Enum.Material.Neon, transparency = 0.55 },
}

local function drop_highlight(plr)
    if chams_highlights[plr] then pcall(function() chams_highlights[plr]:Destroy() end); chams_highlights[plr] = nil end
end
local function restore_body(plr)
    local s = chams_bodies[plr]
    if not s then return end
    for part, props in pairs(s) do
        if part.Parent then
            part.Material, part.Color, part.Reflectance, part.Transparency = props.material, props.color, props.reflectance, props.transparency
            for tex, t in pairs(props.textures) do if tex.Parent then tex.Transparency = t end end
        end
    end
    chams_bodies[plr] = nil
end
local function apply_highlight(plr, char)
    local hl = chams_highlights[plr]
    if not hl or not hl.Parent then
        hl = Instance.new("Highlight")
        hl.Name = "byte_chams"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        chams_highlights[plr] = hl
        hl.Parent = char
    end
    hl.Adornee = char
    hl.FillColor = ELI.chams.fill_color
    hl.FillTransparency = ELI.chams.fill_transparency
    hl.OutlineColor = ELI.chams.outline_color
    hl.OutlineTransparency = ELI.chams.outline_transparency
end
local function apply_body(plr, char)
    local preset = chams_material_presets[ELI.chams.material] or chams_material_presets.Neon
    local saved = chams_bodies[plr] or {}
    chams_bodies[plr] = saved
    local tr = preset.transparency or 0
    if ELI.chams.ghost then tr = math.max(tr, 0.55) end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 1 then
            if not saved[part] then
                local tex = {}
                for _, t in ipairs(part:GetChildren()) do
                    if t:IsA("Decal") or t:IsA("Texture") then tex[t] = t.Transparency end
                end
                saved[part] = { material=part.Material, color=part.Color, reflectance=part.Reflectance, transparency=part.Transparency, textures=tex }
            end
            part.Material, part.Color, part.Reflectance, part.Transparency = preset.material, ELI.chams.fill_color, preset.reflectance or 0, tr
            if ELI.chams.strip_textures then
                for t in pairs(saved[part].textures) do if t.Parent then t.Transparency = 1 end end
            end
        end
    end
end
local function apply_chams(plr)
    if plr == LocalPlayer then return end
    local char = plr.Character
    if not char then drop_highlight(plr); restore_body(plr); return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then drop_highlight(plr); restore_body(plr); return end
    if ELI.chams.team_check and plr:GetAttribute("TeamID") == LocalPlayer:GetAttribute("TeamID") then
        drop_highlight(plr); restore_body(plr); return
    end
    if ELI.chams.mode == "chams" then
        drop_highlight(plr); apply_body(plr, char)
    else
        restore_body(plr); apply_highlight(plr, char)
    end
end

giveSignal(Players.PlayerRemoving:Connect(function(p)
    drop_highlight(p); restore_body(p)
end))

local chams_tick = 0
giveSignal(RunService.Heartbeat:Connect(function()
    if not ELI.chams.enable then
        if next(chams_highlights) or next(chams_bodies) then
            local kset = {}
            for p in pairs(chams_highlights) do kset[p] = true end
            for p in pairs(kset) do drop_highlight(p) end
            local bset = {}
            for p in pairs(chams_bodies) do bset[p] = true end
            for p in pairs(bset) do restore_body(p) end
        end
        return
    end
    chams_tick = chams_tick + 1
    if chams_tick % 2 ~= 0 then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then apply_chams(p) end
    end
    for p, hl in pairs(chams_highlights) do
        if not hl.Parent or not p.Parent then drop_highlight(p) end
    end
    for p in pairs(chams_bodies) do
        if not p.Parent or not p.Character or not p.Character.Parent then restore_body(p) end
    end
end))

if local_fighter and local_fighter.ReplicateFromServer then
    local old = local_fighter.ReplicateFromServer
    local_fighter.ReplicateFromServer = function(controller, _type, ...)
        if _type == "DamageNumberEffect" then
            local hit_root, hit_damage, is_headshot = ...
            if hit_root and hit_damage then
                local ch = hit_root.Parent
                if ch and ch:FindFirstChildOfClass("Humanoid") then
                    local part = is_headshot and "Head" or "Body"
                    if ELI.hit_notify.enable then
                        local msg = ELI.hit_notify.msg
                        msg = msg:gsub("{target}", ch.Name):gsub("{damage}", tostring(math.floor(hit_damage or 0))):gsub("{hitpart}", part)
                        task.spawn(function()
                            local id = getthreadidentity()
                            setthreadidentity(7)
                            notify(msg, ELI.hit_notify.duration, "Hit")
                            setthreadidentity(id)
                        end)
                    end
                end
            end
        end
        return old(controller, _type, ...)
    end
    giveSignal({ Disconnect = function() local_fighter.ReplicateFromServer = old end })
end

local tp_tick = 0
giveSignal(RunService.Heartbeat:Connect(function()
    if not ELI.camera.third_person then return end
    if not camera_controller or not camera_controller.CameraState then return end
    tp_tick = tp_tick + 1
    if tp_tick < 12 then return end
    tp_tick = 0
    if camera_controller.CameraState:GetPublicState() ~= camera_controller.CameraState.States.ThirdPerson then
        pcall(function() camera_controller.CameraState:TogglePOV() end)
    end
end))

giveSignal(RunService.RenderStepped:Connect(function()
    if ELI.camera.stretched_res then
        Camera.CFrame = Camera.CFrame * CFrame.new(0,0,0, 1,0,0, 0,ELI.camera.stretched_res_amount,0, 0,0,1)
    end
end))

giveSignal(RunService.RenderStepped:Connect(function()
    if ELI.camera.fov_changer then Camera.FieldOfView = ELI.camera.fov end
end))

local flash_setup = false
local flash1, flash2
giveSignal(RunService.Heartbeat:Connect(function()
    local want = ELI.world.anti_flashbang
    if want and not flash_setup then
        flash_setup = true
        flash1 = workspace.ChildAdded:Connect(function(v)
            if v.Name == "FlashbangEffect" then v:Destroy() end
        end)
        flash2 = LocalPlayer.PlayerGui.ChildAdded:Connect(function(v)
            if v.Name == "FlashbangGui" then v:Destroy() end
        end)
        giveSignal(flash1)
        giveSignal(flash2)
    elseif not want and flash_setup then
        flash_setup = false
        if flash1 then flash1:Disconnect(); flash1 = nil end
        if flash2 then flash2:Disconnect(); flash2 = nil end
    end
end))

giveSignal(RunService.Heartbeat:Connect(function()
    if not ELI.character.fly then return end
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = LocalPlayer.Character.HumanoidRootPart
    local mv = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv -= Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv -= Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then mv -= Vector3.new(0,1,0) end
    if mv.Magnitude > 0 then
        hrp.CFrame += mv.Unit * ELI.character.fly_speed * RunService.Heartbeat:Wait()
    else
        hrp.CFrame = CFrame.new(hrp.Position) * (hrp.CFrame - hrp.CFrame.Position)
    end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
end))

local ws_base, ws_applying = 16, false
local function ws_apply(hum)
    if not ELI.movement.walkspeed or not hum then return end
    ws_applying = true
    hum.WalkSpeed = ws_base * ELI.movement.walkspeed_multiplier
    ws_applying = false
end
local ws_conn = nil
local function ws_bind_clean(char)
    if ws_conn then pcall(function() ws_conn:Disconnect() end); ws_conn = nil end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    ws_base = hum.WalkSpeed
    ws_conn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if ws_applying then return end
        ws_base = hum.WalkSpeed
        ws_apply(hum)
    end)
    giveSignal(ws_conn)
    ws_apply(hum)
end
if LocalPlayer.Character then ws_bind_clean(LocalPlayer.Character) end
giveSignal(LocalPlayer.CharacterAdded:Connect(ws_bind_clean))

local ws_active = false
giveSignal(RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if ELI.movement.walkspeed then
        ws_active = true
        local want = ws_base * ELI.movement.walkspeed_multiplier
        if math.abs(hum.WalkSpeed - want) > 0.05 then
            ws_applying = true; hum.WalkSpeed = want; ws_applying = false
        end
    elseif ws_active then
        ws_active = false
        ws_applying = true; hum.WalkSpeed = ws_base; ws_applying = false
    end
end))

giveSignal(RunService.RenderStepped:Connect(function()
    if ELI.movement.slide_boost and mechanics_controller and mechanics_controller.IsSliding then
        pcall(function()
            mechanics_controller._sliding_velocity.Velocity =
                mechanics_controller._sliding_velocity.Velocity.Unit * ELI.movement.slide_boost_speed
        end)
    end
end))

giveSignal(RunService.Heartbeat:Connect(function()
    if not mechanics_controller then return end
    if ELI.movement.infinite_double_jump then
        pcall(function() mechanics_controller._double_jumps_used = {} end)
    end
    if ELI.movement.double_jump_height then
        pcall(function() mechanics_controller._original_jump_power = ELI.movement.double_jump_height_value end)
    end
    if ELI.movement.auto_slide and mechanics_controller.IsSprinting then
        pcall(function() mechanics_controller:Slide() end)
    end
end))

local last_attr = { level = nil, streak = nil, status = nil, elo = nil }
giveSignal(RunService.Heartbeat:Connect(function()
    if ELI.spoof.level.enable then
        local v = ELI.spoof.level.value
        if v ~= last_attr.level then
            last_attr.level = v
            pcall(function() LocalPlayer:SetAttribute("Level", v) end)
        end
    end
    if ELI.spoof.streak.enable then
        local v = ELI.spoof.streak.value
        if v ~= last_attr.streak then
            last_attr.streak = v
            pcall(function() LocalPlayer:SetAttribute("StatisticDuelsWinStreak", v) end)
        end
    end
    if ELI.spoof.player_status.enable and ELI.spoof.player_status.select ~= "" then
        local v = ELI.spoof.player_status.select
        if v ~= last_attr.status then
            last_attr.status = v
            pcall(function() LocalPlayer:SetAttribute("PlayerStatus", v) end)
        end
    end
    if ELI.elo_spoof.enable then
        local v = ELI.elo_spoof.value
        if v ~= last_attr.elo then
            last_attr.elo = v
            pcall(function() LocalPlayer:SetAttribute("DisplayELO", v) end)
        end
    end
end))

getgenv().txtDeviceSpoofType = getgenv().txtDeviceSpoofType or "PC"
local function ApplyDeviceSpoof()
    local deviceType = getgenv().txtDeviceSpoofType or "PC"
    local spoofDevice = (deviceType == "Mobile") and "Phone" or deviceType
    local queue = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if not queue then return notify("Executor does not support queue_on_teleport.") end
    local source = [[
        if not game:IsLoaded() then game.Loaded:Wait() end
        local Q = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport)
        local P = game:GetService('Players').LocalPlayer
        local Env = getgenv()
        if Env._devq then Env._devq:Disconnect() end
        local Qd = false
        Env._devq = P.OnTeleport:Connect(function()
            if not Qd then Q(source); Qd = true end
        end)
        local Device = ]] .. HttpService:JSONEncode(spoofDevice) .. [[
        if game.GameId ~= ]] .. tostring(game.GameId) .. [[ then return end
        while not workspace:GetAttribute('ClientModulesLoaded') do
            workspace:GetAttributeChangedSignal('ClientModulesLoaded'):Wait()
        end
        local RS = game:GetService('ReplicatedStorage')
        local Listener = require(RS:WaitForChild('ClientGameModules'):WaitForChild('DeviceListener'))
        local Observe = Listener.Observe
        for _, c in Listener.OnChange:GetConnections() do
            if debug.info(c._fn, 's') == 'ReplicatedStorage.Controllers.PlayerProfileController' then
                task.spawn(function() c._fn(Device); c._fn(Listener.Device) end); return
            end
        end
        local function ObserveDevice(Self, Cb)
            if debug.info(Cb, 's') == 'ReplicatedStorage.Controllers.PlayerProfileController' then
                task.spawn(function() Cb(Device); Cb(Listener.Device) end)
                return Self.OnChange:Connect(Cb)
            end
            return Observe(Self, Cb)
        end
        Listener.Observe = ObserveDevice
    ]]
    queue(source)
    notify("Spoofing as " .. deviceType .. ", rejoining...")
    task.wait(0.2)
    if not pcall(TeleportService.TeleportToPlaceInstance, TeleportService, game.PlaceId, game.JobId, LocalPlayer) then
        pcall(function()
            game:GetService("ExperienceService"):LaunchExperience({ placeId = game.PlaceId, gameInstanceId = game.JobId })
        end)
    end
end

local sorted_items = {}
if item_lib and item_lib.Items then
    for _, item in pairs(item_lib.Items) do
        if item.Name ~= "MISSING_WEAPON" then
            sorted_items[item.Class] = sorted_items[item.Class] or {}
            table.insert(sorted_items[item.Class], item.Name)
        end
    end
end

local pick_weapons = ReplicatedStorage.Remotes.Replication.Fighter.PickWeapons
local pages_cache = nil
giveSignal(task.spawn(function()
    while task.wait(0.5) do
        if not ELI.auto_loadout.enable or not local_fighter then continue end
        if not pages_cache then
            pages_cache = SafeRequire(LocalPlayer.PlayerScripts.Modules.UserInterface, "Pages")
        end
        local current = pages_cache and pages_cache.PageSystem and pages_cache.PageSystem.CurrentPage
        if local_fighter:Get("CanPickWeapons") == true and current and current.Name == "PickWeapons" then
            local payload = {}
            for i = 1, local_fighter:GetMaxEquippableWeapons() do
                payload[i] = ELI.auto_loadout.loadout[i]
            end
            pcall(function() pick_weapons:FireServer(payload) end)
        end
    end
end))

local vote_tick = 0
giveSignal(RunService.Heartbeat:Connect(function()
    if not ELI.auto_vote_map.enable or ELI.auto_vote_map.map == "" then return end
    vote_tick = vote_tick + 1
    if vote_tick < 60 then return end
    vote_tick = 0
    pcall(function() ReplicatedStorage.Remotes.Duels.Vote:FireServer(ELI.auto_vote_map.map) end)
end))

local clicked_queue = false
giveSignal(task.spawn(function()
    while task.wait(1) do
        if not ELI.auto_queue.enable or ELI.auto_queue.queue_mode == "" then continue end
        local in_match = false
        pcall(function() in_match = local_fighter and local_fighter:Get("IsInDuel") == true end)
        if in_match then
            clicked_queue = false
        elseif not clicked_queue then
            pcall(function() ReplicatedStorage.Remotes.Matchmaking.JoinQueue:InvokeServer(ELI.auto_queue.queue_mode) end)
            clicked_queue = true
        end
    end
end))

do
    local particle_saved = setmetatable({}, { __mode = "k" })
    local texture_saved = setmetatable({}, { __mode = "k" })
    local post_saved = setmetatable({}, { __mode = "k" })
    local orig_shadows, shadows_saved = nil, false
    local orig_quality, quality_saved = nil, false
    local orig_atmo, atmo_saved = nil, false
    local particle_classes = { ParticleEmitter=true, Trail=true, Smoke=true, Fire=true, Sparkles=true }
    local post_classes = { BloomEffect=true, BlurEffect=true, ColorCorrectionEffect=true, SunRaysEffect=true, DepthOfFieldEffect=true }
    local scanning = false

    local function applyParticle(inst, on)
        if not particle_classes[inst.ClassName] then return end
        if on then
            if particle_saved[inst] == nil then particle_saved[inst] = inst.Enabled end
            inst.Enabled = false
        elseif particle_saved[inst] ~= nil then
            inst.Enabled = particle_saved[inst]; particle_saved[inst] = nil
        end
    end
    local function applyTexture(inst, on)
        if not (inst:IsA("Decal") or inst:IsA("Texture")) then return end
        if on then
            if texture_saved[inst] == nil then texture_saved[inst] = inst.Transparency end
            inst.Transparency = 1
        elseif texture_saved[inst] ~= nil then
            inst.Transparency = texture_saved[inst]; texture_saved[inst] = nil
        end
    end
    local function applyPost(inst, on)
        if not post_classes[inst.ClassName] then return end
        if on then
            if post_saved[inst] == nil then post_saved[inst] = inst.Enabled end
            inst.Enabled = false
        elseif post_saved[inst] ~= nil then
            inst.Enabled = post_saved[inst]; post_saved[inst] = nil
        end
    end

    local function scanWorkspace()
        if scanning then return end
        scanning = true
        task.spawn(function()
            local list = workspace:GetDescendants()
            for i = 1, #list do
                applyParticle(list[i], ELI.optimizations.no_particles)
                applyTexture(list[i], ELI.optimizations.no_textures)
                if i % 800 == 0 then task.wait() end
            end
            scanning = false
        end)
    end
    local function scanLighting()
        for _, inst in ipairs(Lighting:GetDescendants()) do applyPost(inst, ELI.optimizations.no_postfx) end
    end
    local function applyShadows()
        if ELI.optimizations.no_shadows then
            if not shadows_saved then orig_shadows = Lighting.GlobalShadows; shadows_saved = true end
            Lighting.GlobalShadows = false
        elseif shadows_saved then
            Lighting.GlobalShadows = orig_shadows; shadows_saved = false
        end
    end
    local function applyQuality()
        pcall(function()
            local render = settings().Rendering
            if ELI.optimizations.low_quality then
                if not quality_saved then orig_quality = render.QualityLevel; quality_saved = true end
                render.QualityLevel = Enum.QualityLevel.Level01
            elseif quality_saved then
                render.QualityLevel = orig_quality; quality_saved = false
            end
        end)
    end
    local function applyAtmosphere()
        local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
        if ELI.optimizations.no_atmosphere then
            if atmo then
                if not atmo_saved then orig_atmo = atmo.Density; atmo_saved = true end
                atmo.Density = 0
            end
            local clouds = workspace.Terrain and workspace.Terrain:FindFirstChildOfClass("Clouds")
            if clouds then clouds.Enabled = false end
        else
            if atmo and atmo_saved then atmo.Density = orig_atmo; atmo_saved = false end
            local clouds = workspace.Terrain and workspace.Terrain:FindFirstChildOfClass("Clouds")
            if clouds then clouds.Enabled = true end
        end
    end
    local function applyFpsCap()
        if not setfpscap then return end
        pcall(setfpscap, ELI.optimizations.fps_cap_enable and ELI.optimizations.fps_cap or 1000)
    end

    giveSignal(workspace.DescendantAdded:Connect(function(inst)
        if ELI.optimizations.no_particles then applyParticle(inst, true) end
        if ELI.optimizations.no_textures then applyTexture(inst, true) end
    end))
    giveSignal(Lighting.DescendantAdded:Connect(function(inst)
        if ELI.optimizations.no_postfx then applyPost(inst, true) end
    end))

    getgenv().byte_apply_opt = function(kind)
        if kind == "particles" or kind == "textures" then scanWorkspace()
        elseif kind == "postfx" then scanLighting()
        elseif kind == "shadows" then applyShadows()
        elseif kind == "quality" then applyQuality()
        elseif kind == "atmosphere" then applyAtmosphere()
        elseif kind == "fpscap" then applyFpsCap()
        end
    end
end

do
    local RANK_ICONS = {
        ["Bronze"] = "rbxassetid://111599878354131",
        ["Silver"] = "rbxassetid://82834564754747",
        ["Gold"] = "rbxassetid://80716950169934",
        ["Diamond"] = "rbxassetid://131795064007344",
        ["Onyx"] = "rbxassetid://114166096331502",
        ["Nemesis"] = "rbxassetid://133903971285645",
        ["Arch Nemesis"] = "rbxassetid://134520747948636",
    }
    local function commas(n)
        local s = tostring(n)
        while true do
            local r
            s, r = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2")
            if r == 0 then break end
        end
        return s
    end
    local function rankIconFor(rank)
        if RANK_ICONS[rank] then return RANK_ICONS[rank] end
        local base = rank:gsub("%s*%d+%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
        return RANK_ICONS[base] or ""
    end
    local held = setmetatable({}, { __mode = "k" })
    local function anySpoofOn()
        return ELI.rank_spoof.enable or ELI.elo_spoof.enable or ELI.name_spoof.enable
    end
    local function lockText(label, value)
        if not label or not label:IsA("TextLabel") then return end
        if label.Text ~= value then label.Text = value end
        if held[label] then return end
        held[label] = true
        label:GetPropertyChangedSignal("Text"):Connect(function()
            if not anySpoofOn() then return end
            if label.Text ~= value then label.Text = value end
        end)
    end
    local function lockImage(img, value)
        if not img or not (img:IsA("ImageLabel") or img:IsA("ImageButton")) then return end
        if img.Image ~= value then img.Image = value end
        if held[img] then return end
        held[img] = true
        img:GetPropertyChangedSignal("Image"):Connect(function()
            if not ELI.rank_spoof.enable then return end
            if img.Image ~= value then img.Image = value end
        end)
    end
    local function nameMatches()
        local real = LocalPlayer.Name
        local disp = LocalPlayer.DisplayName
        return { [disp] = "display", [real] = "name", ["@" .. real] = "atname" }
    end
    local function spoofNameLabel(label)
        if not ELI.name_spoof.enable then return end
        local t = label.Text
        if t == "" then return end
        local disp = ELI.name_spoof.display ~= "" and ELI.name_spoof.display or LocalPlayer.DisplayName
        local user = ELI.name_spoof.username ~= "" and ELI.name_spoof.username or LocalPlayer.Name
        local kind = nameMatches()[t]
        if kind == "display" then lockText(label, disp)
        elseif kind == "name" then lockText(label, user)
        elseif kind == "atname" then lockText(label, "@" .. user) end
    end
    local function isMyRow(slot)
        local playerFrame = slot:FindFirstChild("Player")
        if not playerFrame then return false end
        local m = nameMatches()
        for _, node in ipairs(playerFrame:GetDescendants()) do
            if node:IsA("TextLabel") and m[node.Text] then return true end
        end
        return false
    end
    local function scan()
        if not anySpoofOn() then return end
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        if not gui then return end
        local mainGui = gui:FindFirstChild("MainGui")
        local rankOn = ELI.rank_spoof.enable
        local eloOn = ELI.elo_spoof.enable
        local nameOn = ELI.name_spoof.enable
        local rankText = ELI.rank_spoof.rank or ""
        local rankIcon = rankOn and rankIconFor(rankText) or ""
        local eloText = eloOn and commas(ELI.elo_spoof.value) or nil

        local roots = { mainGui, gui:FindFirstChild("PlayerList") }
        for _, root in ipairs(roots) do
            if root then
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA("TextLabel") then
                        if nameOn then spoofNameLabel(d) end
                        if d.Name == "CurrentELO" and eloText and d:FindFirstAncestor("ELOBar") then
                            lockText(d, eloText)
                        elseif (d.Name == "LeftRank" or d.Name == "RightRank") and rankOn and rankText ~= ""
                            and d:FindFirstAncestor("ELOBar") then
                            lockText(d, rankText)
                        end
                    end
                end
            end
        end

        if rankOn and rankIcon ~= "" then
            local list = gui:FindFirstChild("PlayerList")
                or (mainGui and mainGui:FindFirstChild("PlayerList"))
            if list then
                for _, slot in ipairs(list:GetDescendants()) do
                    if slot.Name == "PlayerListSlot" and isMyRow(slot) then
                        local stat = slot:FindFirstChild("Leaderstat")
                        local container = stat and stat:FindFirstChild("RankContainer")
                        if container then
                            for _, ic in ipairs(container:GetDescendants()) do
                                if ic.Name == "Icon" and (ic:IsA("ImageLabel") or ic:IsA("ImageButton")) then
                                    lockImage(ic, rankIcon)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    giveSignal(task.spawn(function()
        while not getgenv().ByteUnloaded do
            pcall(scan)
            task.wait(0.5)
        end
    end))
end

do
    local plrs = game:GetService("Players")
    local reps = game:GetService("ReplicatedStorage")
    local http = game:GetService("HttpService")

    local lp = plrs.LocalPlayer
    local lps = lp.PlayerScripts
    local ctrls = lps.Controllers
    local rmods = reps.Modules

    local elib = require(rmods:WaitForChild("EnumLibrary", 10))
    if elib then pcall(function() elib:WaitForEnumBuilder() end) end
    local clib = require(rmods:WaitForChild("CosmeticLibrary", 10))
    local ilib = require(rmods:WaitForChild("ItemLibrary", 10))
    local dctrl = require(ctrls:WaitForChild("PlayerDataController", 10))
    local coss = clib.Cosmetics

    local cdata = dctrl.CurrentData
    if not cdata then
        task.spawn(function()
            repeat task.wait() until dctrl.CurrentData
            cdata = dctrl.CurrentData
        end)
    end

    local Wraps, Charms = {}, {}
    local equip, favs = {}, {}
    local fcache = {}

    getgenv().byte_cosmetic_active = true

    local function active() return getgenv().byte_cosmetic_active == true end

    local function banned(n)
        if type(n) ~= "string" then return true end
        return n:find("MISSING_")
    end

    local function toenum(n)
        if not elib then return nil end
        local ok, id = pcall(elib.ToEnum, elib, n)
        return ok and id or nil
    end

    local function clonecos(name, ctype, inv, favonly)
        if banned(name) then return nil end
        local base = coss[name]
        if not base then base = { Name = name, Type = ctype, Rarity = "Common" } end
        local d = table.clone(base)
        d.Name = name
        d.Type = d.Type or ctype
        d.Seed = d.Seed or math.random(1, 1000000)
        local eid = toenum(name)
        if eid then d.Enum = eid; d.ObjectID = d.ObjectID or eid end
        if inv ~= nil then d.Inverted = inv end
        if favonly ~= nil then d.OnlyUseFavorites = favonly end
        return d
    end

    local savef = "Byte/skinconfig.json"

    local function savecfg()
        if not writefile then return end
        pcall(function()
            local cfg = { equipped = {}, favorites = favs, wraps = {}, charms = {} }
            for wep, cos in pairs(equip) do
                local slot = {}
                cfg.equipped[wep] = slot
                for ct, cd in pairs(cos) do
                    if cd and cd.Name and not banned(cd.Name) then
                        slot[ct] = { name = cd.Name, seed = cd.Seed, inverted = cd.Inverted }
                    end
                end
            end
            for wep, w in pairs(Wraps) do
                if w == false then cfg.wraps[wep] = false
                elseif w then cfg.wraps[wep] = { name = w.Name, inverted = w.Inverted } end
            end
            for wep, c in pairs(Charms) do
                if c == false then cfg.charms[wep] = false
                elseif c then cfg.charms[wep] = { name = c.Name } end
            end
            if makefolder then makefolder("Byte") end
            writefile(savef, http:JSONEncode(cfg))
        end)
    end

    local function loadcfg()
        if not readfile or not isfile or not isfile(savef) then return end
        pcall(function()
            local cfg = http:JSONDecode(readfile(savef))
            if cfg.equipped then
                for wep, cos in pairs(cfg.equipped) do
                    equip[wep] = {}
                    for ct, cd in pairs(cos) do
                        if not banned(cd.name) then
                            local cl = clonecos(cd.name, ct, cd.inverted)
                            if cl then
                                cl.Seed = cd.seed
                                equip[wep][ct] = cl
                            end
                        end
                    end
                end
            end
            if cfg.wraps then
                for wep, w in pairs(cfg.wraps) do
                    if w == false then Wraps[wep] = false
                    elseif type(w) == "table" and w.name and not banned(w.name) then
                        Wraps[wep] = { Name = w.name, Inverted = w.inverted == true }
                    end
                end
            end
            if cfg.charms then
                for wep, c in pairs(cfg.charms) do
                    if c == false then Charms[wep] = false
                    elseif type(c) == "table" and c.name and not banned(c.name) then
                        Charms[wep] = { Name = c.name }
                    end
                end
            end
            favs = cfg.favorites or {}
        end)
    end

    local finv = {}
    local function rebuildinv()
        table.clear(finv)
        for name in pairs(coss) do
            if not banned(name) then finv[name] = true end
        end
        for _, cos in pairs(equip) do
            for _, cd in pairs(cos) do
                if cd and cd.Name and not banned(cd.Name) then finv[cd.Name] = true end
            end
        end
    end

    rebuildinv()

    local cvm = client_viewmodel
    local ogw, ogGet, onew, ocvm
    if cvm then
        if cvm.GetWrap then
            ogw = cvm.GetWrap
            cvm.GetWrap = function(self)
                if not active() then return ogw(self) end
                local ci = self.ClientItem
                local wname = ci and ci.Name
                local wplr = ci and ci.ClientFighter and ci.ClientFighter.Player
                if wplr == lp and wname then
                    local pick = Wraps[wname]
                    if pick == false then return nil end
                    if pick then return pick end
                    local ueq = equip["IsUniversal"]
                    if ueq and ueq.Wrap then return ueq.Wrap end
                end
                return ogw(self)
            end
        end
        if cvm.Get then
            ogGet = cvm.Get
            cvm.Get = function(self, key)
                if active() and key == "Charm" then
                    local ci = self.ClientItem
                    local wname = ci and ci.Name
                    local wplr = ci and ci.ClientFighter and ci.ClientFighter.Player
                    if wplr == lp and wname then
                        local pick = Charms[wname]
                        if pick == false then return nil end
                        if pick then return pick end
                        local ueq = equip["IsUniversal"]
                        if ueq and ueq.Charm then return ueq.Charm end
                    end
                end
                return ogGet(self, key)
            end
        end
        if cvm.new then
            onew = cvm.new
            cvm.new = function(rdata, cliitm)
                local wplr = cliitm.ClientFighter and cliitm.ClientFighter.Player
                local wname = cliitm.Name
                
                if active() and wplr == lp and wname then
                    local eq = equip[wname] or {}
                    local ueq = equip["IsUniversal"] or {}
                    local cskin = eq.Skin or ueq.Skin
                    local cwrap = eq.Wrap or ueq.Wrap or Wraps[wname]
                    local ccharm = eq.Charm or ueq.Charm or Charms[wname]
                    
                    if rep_class then
                        local rcls = rep_class
                        local dk = rcls:ToEnum("Data")
                        rdata[dk] = rdata[dk] or {}
                        local slot = rdata[dk]
                        if cskin then slot[rcls:ToEnum("Skin")] = cskin end
                        if cwrap then slot[rcls:ToEnum("Wrap")] = cwrap end
                        if ccharm then slot[rcls:ToEnum("Charm")] = ccharm end
                    end
                end
                
                local res = onew(rdata, cliitm)
                
                if active() and wplr == lp and wname then
                    local eq = equip[wname] or {}
                    local ueq = equip["IsUniversal"] or {}
                    local cskin = eq.Skin or ueq.Skin
                    local cwrap = eq.Wrap or ueq.Wrap or Wraps[wname]
                    local ccharm = eq.Charm or ueq.Charm or Charms[wname]
                    
                    if cskin and res._UpdateSkin then pcall(function() res:_UpdateSkin() end) end
                    if cwrap and res._UpdateWrap then pcall(function() res:_UpdateWrap() end) end
                    if ccharm and res._UpdateCharm then pcall(function() res:_UpdateCharm() end) end
                end
                return res
            end
        end
    end
    
    local citem = client_item
    if citem and citem._CreateViewModel then
        ocvm = citem._CreateViewModel
        citem._CreateViewModel = function(self, vmref)
            local wname = self.Name
            local wplr = self.ClientFighter and self.ClientFighter.Player
            
            if active() and wplr == lp and vmref then
                local eq = equip[wname] or {}
                local ueq = equip["IsUniversal"] or {}
                local cskin = eq.Skin or ueq.Skin
                local cwrap = eq.Wrap or ueq.Wrap or Wraps[wname]
                local ccharm = eq.Charm or ueq.Charm or Charms[wname]
                
                local dk = self:ToEnum("Data")
                
                if vmref[dk] then
                    if cskin then vmref[dk][self:ToEnum("Skin")] = cskin; vmref[dk][self:ToEnum("Name")] = cskin.Name end
                    if cwrap then vmref[dk][self:ToEnum("Wrap")] = cwrap end
                    if ccharm then vmref[dk][self:ToEnum("Charm")] = ccharm end
                elseif vmref.Data then
                    if cskin then vmref.Data.Skin = cskin; vmref.Data.Name = cskin.Name end
                    if cwrap then vmref.Data.Wrap = cwrap end
                    if ccharm then vmref.Data.Charm = ccharm end
                end
            end
            return ocvm(self, vmref)
        end
    end

    local ogetwep = dctrl.GetWeaponData
    dctrl.GetWeaponData = function(self, wname)
        local data
        pcall(function() data = ogetwep(self, wname) end)
        if not active() then return data end

        local weq = equip[wname]
        local w = Wraps[wname]
        local c = Charms[wname]
        local has_override = weq or (w ~= nil) or (c ~= nil)

        if type(data) ~= "table" then
            if not has_override then return data end
            data = { Name = wname }
        end

        local merged = table.clone(data)
        merged.Name = wname
        merged.Weapon = wname
        if weq then for ct, cd in pairs(weq) do merged[ct] = cd end end
        if w == false then merged.Wrap = nil
        elseif w then merged.Wrap = w end
        if c == false then merged.Charm = nil
        elseif c then merged.Charm = c end
        return merged
    end

    local oget = dctrl.Get
    dctrl.Get = function(self, key)
        local data = oget(self, key)
        if not active() then return data end
        if key == "CosmeticInventory" then
            local proxy = {}
            if data then for k, v in pairs(data) do if not banned(k) then proxy[k] = v end end end
            for name in pairs(finv) do proxy[name] = true end
            return proxy
        end
        if key == "FavoritedCosmetics" then
            local res = data and table.clone(data) or {}
            for wep, fv in pairs(favs) do
                local slot = res[wep] or {}
                res[wep] = slot
                for name, isfav in pairs(fv) do
                    if not banned(name) then slot[name] = isfav end
                end
            end
            return res
        end
        return data
    end

    local function saferep(key)
        pcall(function()
            if not cdata and dctrl.CurrentData then cdata = dctrl.CurrentData end
            if cdata then cdata:Replicate(key) end
            local sig = dctrl:GetDataChangedSignal(key)
            if sig then sig:Fire() end
        end)
    end

    local fctrl
    pcall(function() fctrl = require(ctrls:WaitForChild("FighterController", 10)) end)

    local function getewep()
        if not fctrl then return nil end
        local fighter = fctrl:GetFighter(lp)
        if not fighter or not fighter.Items then return nil end
        for _, item in pairs(fighter.Items) do
            local isEq = false
            pcall(function() isEq = item:Get("IsEquipped") end)
            if isEq then return item.Name end
        end
        return nil
    end

    local function update_current_visuals()
        if not fctrl then return end
        local fighter = fctrl:GetFighter(lp)
        if not fighter or not fighter.Items then return end
        for _, item in pairs(fighter.Items) do
            local isEq = false
            pcall(function() isEq = item:Get("IsEquipped") end)
            if isEq then
                local wname = item.Name
                local vm = item.ViewModel
                if vm then
                    if vm._UpdateWrap then pcall(function() vm:_UpdateWrap() end) end
                    if vm._UpdateCharm then pcall(function() vm:_UpdateCharm() end) end
                    if vm._UpdateSkin then pcall(function() vm:_UpdateSkin() end) end
                end
            end
        end
    end

    local namecall_original
    if hookmetamethod then
        local rems = reps:FindFirstChild("Remotes")
        local drems = rems and rems:FindFirstChild("Data")
        local eqrem = drems and drems:FindFirstChild("EquipCosmetic")
        local favrem = drems and drems:FindFirstChild("FavoriteCosmetic")

        if eqrem then
            local oncall
            oncall = hookmetamethod(game, "__namecall", function(self, ...)
                if not active() then return oncall(self, ...) end
                if getnamecallmethod() ~= "FireServer" then return oncall(self, ...) end
                local args = { ... }

                if self == eqrem then
                    local wname, ctype, cname, opts = args[1], args[2], args[3], args[4] or {}

                    if ctype == "Wrap" then
                        if not cname or cname == "None" or cname == "" then
                            Wraps[wname] = false
                        elseif not banned(cname) then
                            Wraps[wname] = { Name = cname, Inverted = opts.IsInverted == true }
                        end
                        task.defer(function()
                            saferep("WeaponDataChanged")
                            update_current_visuals()
                            task.wait(0.15)
                            savecfg()
                        end)
                        return
                    end

                    if ctype == "Charm" then
                        if not cname or cname == "None" or cname == "" then
                            Charms[wname] = false
                        elseif not banned(cname) then
                            Charms[wname] = { Name = cname }
                        end
                        task.defer(function()
                            saferep("WeaponDataChanged")
                            update_current_visuals()
                            task.wait(0.15)
                            savecfg()
                        end)
                        return
                    end

                    if not cname or cname == "None" or cname == "" then
                        equip[wname] = equip[wname] or {}
                        equip[wname][ctype] = nil
                        if not next(equip[wname]) then equip[wname] = nil end
                        rebuildinv()
                        task.defer(function()
                            saferep("WeaponInventory")
                            update_current_visuals()
                            task.wait(0.2)
                            savecfg()
                        end)
                        return oncall(self, ...)
                    end

                    equip[wname] = equip[wname] or {}
                    local cloned = clonecos(cname, ctype, opts.IsInverted, opts.OnlyUseFavorites)
                    if cloned then equip[wname][ctype] = cloned end
                    if ctype == "Finisher" then fcache[wname] = cname end
                    rebuildinv()
                    task.defer(function()
                        saferep("WeaponInventory")
                        saferep("EquippedCosmetics")
                        saferep("WeaponDataChanged")
                        update_current_visuals()
                        task.wait(0.2)
                        savecfg()
                    end)
                    return
                end

                if self == favrem then
                    local fwep, fname, fstate = args[1], args[2], args[3]
                    if not fname or fname == "None" or fname == "" then return oncall(self, ...) end
                    if banned(fname) then return oncall(self, ...) end
                    favs[fwep] = favs[fwep] or {}
                    favs[fwep][fname] = fstate or nil
                    savecfg()
                    task.spawn(saferep, "FavoritedCosmetics")
                    return
                end

                return oncall(self, ...)
            end)
            namecall_original = oncall
        end
    end

    local ogvi = ilib.GetViewModelImageFromWeaponData
    ilib.GetViewModelImageFromWeaponData = function(self, wdata, hires)
        if not active() or not wdata then return ogvi(self, wdata, hires) end
        local wname = wdata.Name
        local weq = equip[wname]
        if weq and weq.Skin and wdata.Skin == weq.Skin then
            local sinfo = self.ViewModels[weq.Skin.Name]
            if sinfo then return sinfo[hires and "ImageHighResolution" or "Image"] or sinfo.Image end
        end
        return ogvi(self, wdata, hires)
    end

    loadcfg()
    rebuildinv()

    for wname, wdata in pairs(equip) do
        if wdata.Finisher and wdata.Finisher.Name then
            fcache[wname] = wdata.Finisher.Name
        end
    end

    local cent = SafeRequire(lps.Modules.ClientReplicatedClasses, "ClientEntity")
    local ofin
    if cent and cent._PlayFinisher then
        ofin = cent._PlayFinisher
        cent._PlayFinisher = function(self, fname, ...)
            if active() then
                local ewep = getewep() or "IsUniversal"
                local tfin = fcache[ewep] or (equip[ewep] and equip[ewep].Finisher and equip[ewep].Finisher.Name)
                if tfin then fname = tfin end
            end
            return ofin(self, fname, ...)
        end
    end

    local FinisherClass = SafeRequire(Modules, "Finisher")
    local ofin_new, ofin_play, finisher_func_name
    if FinisherClass then
        if FinisherClass.new then
            ofin_new = FinisherClass.new
            FinisherClass.new = function(self, fname, ...)
                if active() then
                    local ewep = getewep() or "IsUniversal"
                    local tfin = fcache[ewep] or (equip[ewep] and equip[ewep].Finisher and equip[ewep].Finisher.Name)
                    if tfin then fname = tfin end
                end
                return ofin_new(self, fname, ...)
            end
        end
        
        if FinisherClass.Play then
            finisher_func_name = "Play"
        elseif FinisherClass.PlayFinisher then
            finisher_func_name = "PlayFinisher"
        elseif FinisherClass.Start then
            finisher_func_name = "Start"
        end
        
        if finisher_func_name then
            ofin_play = FinisherClass[finisher_func_name]
            FinisherClass[finisher_func_name] = function(self, fname, ...)
                if active() then
                    local ewep = getewep() or "IsUniversal"
                    local tfin = fcache[ewep] or (equip[ewep] and equip[ewep].Finisher and equip[ewep].Finisher.Name)
                    if tfin then fname = tfin end
                end
                return ofin_play(self, fname, ...)
            end
        end
    end

    local FinisherModule = SafeRequire(Modules, "Finisher")
    local ofin_play, finisher_func_name
    if FinisherModule then
        if FinisherModule.Play then
            finisher_func_name = "Play"
        elseif FinisherModule.PlayFinisher then
            finisher_func_name = "PlayFinisher"
        elseif FinisherModule.Start then
            finisher_func_name = "Start"
        end
        
        if finisher_func_name then
            ofin_play = FinisherModule[finisher_func_name]
            FinisherModule[finisher_func_name] = function(self, fname, ...)
                if active() then
                    local ewep = getewep() or "IsUniversal"
                    local tfin = fcache[ewep] or (equip[ewep] and equip[ewep].Finisher and equip[ewep].Finisher.Name)
                    if tfin then fname = tfin end
                end
                return ofin_play(self, fname, ...)
            end
        end
    end

    getgenv().byte_cosmetic_cleanup = function()
        getgenv().byte_cosmetic_active = false
        table.clear(Wraps)
        table.clear(Charms)
        table.clear(equip)
        table.clear(fcache)
        table.clear(finv)
        favs = {}
        if cvm then
            if ogw then cvm.GetWrap = ogw end
            if ogGet then cvm.Get = ogGet end
            if onew then cvm.new = onew end
        end
        if citem and ocvm then citem._CreateViewModel = ocvm end
        if cent and ofin then cent._PlayFinisher = ofin end
        if FinisherClass then
            if ofin_new then FinisherClass.new = ofin_new end
            if ofin_play then FinisherClass[finisher_func_name] = ofin_play end
        end
        if FinisherModule and ofin_play then FinisherModule[finisher_func_name] = ofin_play end
        dctrl.GetWeaponData = ogetwep
        dctrl.Get = oget
        ilib.GetViewModelImageFromWeaponData = ogvi
        update_current_visuals()
        pcall(function()
            for _, key in ipairs({"WeaponDataChanged", "WeaponInventory", "EquippedCosmetics", "CosmeticInventory", "FavoritedCosmetics"}) do
                local sig = dctrl:GetDataChangedSignal(key)
                if sig then sig:Fire() end
            end
        end)
        if namecall_original and hookmetamethod then
            pcall(function() hookmetamethod(game, "__namecall", namecall_original) end)
        end
    end
end

do
    local sa = Tabs.Combat:AddLeftGroupbox("Silent Aim", "crosshair")
    local sa_toggle = sa:AddToggle("silent_aim_enable", {
        Text = "Enable Silent Aim", Default = false,
        Callback = function(v) ELI.silent_aim.enable = v end,
    })
    sa_toggle:AddKeyPicker("silent_aim_keybind", { Default = "None", Mode = "Toggle", Text = "Silent Aim" })

    sa:AddToggle("silent_aim_closest_part", {
        Text = "Closest", Default = false,
        Callback = function(v) ELI.silent_aim.closest_part = v end,
    })
    sa:AddToggle("silent_aim_visualize", {
        Text = "Visualize", Default = false,
        Callback = function(v) ELI.silent_aim.visualize = v end,
    })

    local sa_fov_toggle = sa:AddToggle("silent_aim_show_fov", {
        Text = "Show FOV", Default = false,
        Callback = function(v) ELI.silent_aim.show_fov = v end,
    })
    sa_fov_toggle:AddColorPicker({
        SaveId = "silent_aim_fov_color",
        Name = "FOV Color",
        Default = Color3.fromRGB(0,255,0),
        Callback = function(v) ELI.silent_aim.fov_color = v end,
    })
    sa_fov_toggle:AddColorPicker({
        SaveId = "silent_aim_fov_color2",
        Name = "FOV Color 2",
        Default = Color3.fromRGB(255,255,255),
        Callback = function(v) ELI.silent_aim.fov_color2 = v end,
    })

    sa:AddToggle("silent_aim_follow_target", {
        Text = "Follow Playerst", Default = false,
        Callback = function(v) ELI.silent_aim.follow_target = v end,
    })
    sa:AddSlider("silent_aim_fov_radius", {
        Text = "Radius", Suffix = "px", Min = 1, Max = 600, Default = 180, Rounding = 0,
        Callback = function(v) ELI.silent_aim.fov_radius = v end,
    })
    sa:AddSlider("silent_aim_fov_transparency", {
        Text = "FOV Transparency", Min = 0, Max = 1, Default = 0.2, Rounding = 2,
        Callback = function(v) ELI.silent_aim.fov_outline_transparency = v end,
    })
    sa:AddSlider("silent_aim_hit_chance", {
        Text = "Hit Chance", Suffix = "%", Min = 1, Max = 100, Default = 100, Rounding = 0,
        Callback = function(v) ELI.silent_aim.hit_chance = v end,
    })

    local ab = Tabs.Combat:AddLeftGroupbox("Aimbot", "target")
    local ab_toggle = ab:AddToggle("aimbot_enable", {
        Text = "Enable Aimbot", Default = false,
        Callback = function(v) ELI.aimbot.enable = v end,
    })
    ab_toggle:AddKeyPicker("aimbot_keybind", { Default = "None", Mode = "Toggle", Text = "Aimbot" })

    ab:AddToggle("aimbot_closest_part", {
        Text = "Closest", Default = false,
        Callback = function(v) ELI.aimbot.closest_part = v end,
    })

    local ab_fov_toggle = ab:AddToggle("aimbot_show_fov", {
        Text = "Show FOV", Default = false,
        Callback = function(v) ELI.aimbot.show_fov = v end,
    })
    ab_fov_toggle:AddColorPicker({
        SaveId = "aimbot_fov_color",
        Name = "FOV Color",
        Default = Color3.fromRGB(0,255,0),
        Callback = function(v) ELI.aimbot.fov_color = v end,
    })
    ab_fov_toggle:AddColorPicker({
        SaveId = "aimbot_fov_color2",
        Name = "FOV Color 2",
        Default = Color3.fromRGB(255,255,255),
        Callback = function(v) ELI.aimbot.fov_color2 = v end,
    })

    ab:AddToggle("aimbot_follow_target", {
        Text = "Follow Playerst", Default = false,
        Callback = function(v) ELI.aimbot.follow_target = v end,
    })
    ab:AddSlider("aimbot_fov_radius", {
        Text = "Radius", Suffix = "px", Min = 1, Max = 600, Default = 180, Rounding = 0,
        Callback = function(v) ELI.aimbot.fov_radius = v end,
    })
    ab:AddSlider("aimbot_smoothing", {
        Text = "Smoothing", Min = 0, Max = 1, Default = 1, Rounding = 2,
        Callback = function(v) ELI.aimbot.smoothing = v end,
    })

    local tg = Tabs.Combat:AddRightGroupbox("Targeting", "scan")
    tg:AddToggle("targeting_visible_only", {
        Text = "Visible Only", Default = false,
        Callback = function(v) ELI.targeting.visible_only = v end,
    })
    tg:AddToggle("targeting_auto_shoot", {
        Text = "Auto Shoot", Default = false,
        Callback = function(v) ELI.targeting.auto_shoot = v end,
    })
    tg:AddToggle("targeting_anti_katana", {
        Text = "Anti Katana", Default = false,
        Callback = function(v) ELI.targeting.anti_katana = v end,
    })
    tg:AddToggle("targeting_anti_riot", {
        Text = "Anti Riot Shield", Default = false,
        Callback = function(v) ELI.targeting.riot_shield = v end,
    })
    tg:AddDropdown("targeting_hit_part", {
        Text = "Hit Part",
        Values = { "Head", "HumanoidRootPart", "UpperTorso", "LowerTorso" },
        Default = "Head",
        AllowNull = true,
        Callback = function(v) ELI.targeting.part = v or "Head" end,
    })
    tg:AddSlider("targeting_max_distance", {
        Text = "Max Distance", Min = 100, Max = 700, Default = 100, Rounding = 0,
        Callback = function(v) ELI.targeting.max_distance = v end,
    })

    local tb = Tabs.Combat:AddRightGroupbox("Triggerbot", "crosshair")
    local tb_toggle = tb:AddToggle("triggerbot_enable", {
        Text = "Enable Triggerbot", Default = false,
        Callback = function(v) ELI.triggerbot.enable = v end,
    })
    tb_toggle:AddKeyPicker("triggerbot_keybind", { Default = "None", Mode = "Toggle", Text = "Triggerbot" })
    tb:AddToggle("triggerbot_team_check", {
        Text = "Team Check", Default = false,
        Callback = function(v) ELI.triggerbot.team_check = v end,
    })
    tb:AddSlider("triggerbot_reaction_time", {
        Text = "Reaction Time", Suffix = "s", Min = 0, Max = 2, Default = 0.05, Rounding = 2,
        Callback = function(v) ELI.triggerbot.reaction_time = v end,
    })
    tb:AddSlider("triggerbot_shoot_delay", {
        Text = "Shoot Delay", Suffix = "s", Min = 0, Max = 2, Default = 0.1, Rounding = 2,
        Callback = function(v) ELI.triggerbot.shoot_delay = v end,
    })

    local gn = Tabs.Combat:AddRightGroupbox("Guns", "crosshair")
    gn:AddToggle("guns_no_muzzle", {
        Text = "No Muzzle Flash", Default = false,
        Callback = function(v) ELI.guns.no_muzzle_flash = v end,
    })
    gn:AddToggle("guns_no_spread", {
        Text = "No Spread", Default = false,
        Callback = function(v) ELI.guns.no_spread = v end,
    })
    gn:AddToggle("guns_force_modifier", {
        Text = "Force Modifier", Default = false,
        Callback = function(v)
            ELI.guns.force_modifier_enable = v
            if v and item_lib and item_lib.Items then
                for i, item in pairs(item_lib.Items) do
                    if item.InputSpammingEnabled then old_force_auto[i] = item.InputSpammingEnabled.StartShooting end
                end
            elseif item_lib and item_lib.Items then
                for i, item in pairs(item_lib.Items) do
                    if item.InputSpammingEnabled and old_force_auto[i] ~= nil then
                        item.InputSpammingEnabled.StartShooting = old_force_auto[i]
                    end
                end
            end
        end,
    })
    gn:AddToggle("guns_fast_fire", {
        Text = "Rapid Fire", Default = false,
        Tooltip = "Fires the entire magazine instantly when you hold your mouse.",
        Callback = function(v) ELI.guns.fast_fire = v end,
    })
    gn:AddToggle("melee_fast_swing", {
        Text = "Rapid Melee", Default = false,
        Tooltip = "Spams melee attacks while holding your mouse button.",
        Callback = function(v) ELI.melee.fast_swing = v end,
    })

    local rg = Tabs.Combat:AddRightGroupbox("Ragebot", "flame")
    rg:AddLabel("warning:use at your own risk")
    rg:AddToggle("ragebot_enable", {
        Text = "Enable Ragebot", Default = false,
        Callback = function(v)
            ELI.ragebot.enable = v
            if v then RagebotService:Start() else RagebotService:Stop() end
        end,
    })
    rg:AddToggle("ragebot_ffa_mode", {
        Text = "FFA Mode", Default = false,
        Callback = function(v) ELI.ragebot.ffa_mode = v end,
    })
end

do
    local ch = Tabs.Visuals:AddLeftGroupbox("Chams", "eye")
    ch:AddToggle("chams_enable", {
        Text = "Enable Chams", Default = false,
        Callback = function(v) ELI.chams.enable = v end,
    })
    ch:AddToggle("chams_team_check", {
        Text = "Team Check", Default = false,
        Callback = function(v) ELI.chams.team_check = v end,
    })
    ch:AddDropdown("chams_mode", {
        Text = "Mode", Values = { "highlight", "chams" }, Default = "highlight",
        Callback = function(v) ELI.chams.mode = v end,
    })
    ch:AddColorPicker("chams_fill", {
        Default = Color3.fromRGB(0,170,255), Title = "Fill Color", Transparency = 0.5,
        Callback = function(c, t)
            ELI.chams.fill_color = c
            if t then ELI.chams.fill_transparency = t end
        end,
    })
    ch:AddColorPicker("chams_outline", {
        Default = Color3.fromRGB(255,255,255), Title = "Outline Color", Transparency = 0,
        Callback = function(c, t)
            ELI.chams.outline_color = c
            if t then ELI.chams.outline_transparency = t end
        end,
    })
    ch:AddDropdown("chams_material", {
        Text = "Material",
        Values = { "Neon", "ForceField", "Glass", "Chrome", "Ice", "Ghost" },
        Default = "Neon",
        Callback = function(v) ELI.chams.material = v end,
    })
    ch:AddToggle("chams_strip_textures", {
        Text = "Strip Textures", Default = false,
        Callback = function(v) ELI.chams.strip_textures = v end,
    })
    ch:AddToggle("chams_ghost", {
        Text = "Ghost", Default = false,
        Callback = function(v) ELI.chams.ghost = v end,
    })

    local hn = Tabs.Visuals:AddRightGroupbox("Hit Notify", "bell")
    hn:AddToggle("hit_notify_enable", {
        Text = "Enable Hit Notify", Default = false,
        Callback = function(v) ELI.hit_notify.enable = v end,
    })
    hn:AddSlider("hit_notify_duration", {
        Text = "Duration", Suffix = "s", Min = 1, Max = 5, Default = 3, Rounding = 1,
        Callback = function(v) ELI.hit_notify.duration = v end,
    })
    hn:AddInput("hit_notify_msg", {
        Text = "Message",
        Default = "Hit {target} for {damage}",
        Placeholder = "Hit {target} for {damage}",
        Finished = true,
        Callback = function(v) ELI.hit_notify.msg = v end,
    })
    hn:AddLabel("formats: {target}, {damage}, {hitpart}")
end

do
    local wr = Tabs.World:AddLeftGroupbox("World Removals", "trash-2")
    wr:AddToggle("world_anti_flashbang", {
        Text = "Anti Flashbang", Default = false,
        Callback = function(v) ELI.world.anti_flashbang = v end,
    })

    local ch = Tabs.World:AddLeftGroupbox("Character", "user")
    local fly_t = ch:AddToggle("char_fly", {
        Text = "Fly", Default = false,
        Callback = function(v) ELI.character.fly = v end,
    })
    fly_t:AddKeyPicker("char_fly_kb", { Default = "None", Mode = "Toggle", Text = "Fly" })
    ch:AddSlider("char_fly_speed", {
        Text = "Fly Speed", Min = 10, Max = 200, Default = 50, Rounding = 1,
        Callback = function(v) ELI.character.fly_speed = v end,
    })

    local mv = Tabs.World:AddRightGroupbox("Movement", "move")
    local ws_t = mv:AddToggle("move_walkspeed", {
        Text = "Walkspeed", Default = false,
        Callback = function(v) ELI.movement.walkspeed = v end,
    })
    ws_t:AddKeyPicker("move_walkspeed_kb", { Default = "None", Mode = "Toggle", Text = "Walkspeed" })
    mv:AddSlider("move_walkspeed_mult", {
        Text = "Multiplier", Suffix = "x", Min = 1, Max = 10, Default = 1.5, Rounding = 2,
        Callback = function(v) ELI.movement.walkspeed_multiplier = v end,
    })

    local sb_t = mv:AddToggle("move_slide_boost", {
        Text = "Slide Boost", Default = false,
        Callback = function(v) ELI.movement.slide_boost = v end,
    })
    sb_t:AddKeyPicker("move_slide_boost_kb", { Default = "None", Mode = "Toggle", Text = "Slide Boost" })
    mv:AddSlider("move_slide_boost_speed", {
        Text = "Slide Speed", Min = 1, Max = 100, Default = 60, Rounding = 0,
        Callback = function(v) ELI.movement.slide_boost_speed = v end,
    })

    local idj_t = mv:AddToggle("move_infinite_dj", {
        Text = "Infinite Double Jump", Default = false,
        Callback = function(v) ELI.movement.infinite_double_jump = v end,
    })
    idj_t:AddKeyPicker("move_infinite_dj_kb", { Default = "None", Mode = "Toggle", Text = "Infinite DJ" })

    mv:AddToggle("move_dj_height", {
        Text = "Double Jump Height", Default = false,
        Callback = function(v) ELI.movement.double_jump_height = v end,
    })
    mv:AddSlider("move_dj_height_value", {
        Text = "Jump Height", Min = 1, Max = 150, Default = 50, Rounding = 1,
        Callback = function(v) ELI.movement.double_jump_height_value = v end,
    })
    mv:AddToggle("move_auto_slide", {
        Text = "Auto Slide", Default = false,
        Callback = function(v) ELI.movement.auto_slide = v end,
    })

    local cm = Tabs.World:AddLeftGroupbox("Camera", "camera")
    local tp_t = cm:AddToggle("camera_third_person", {
        Text = "Third Person", Default = false,
        Callback = function(v) ELI.camera.third_person = v end,
    })
    tp_t:AddKeyPicker("camera_third_person_kb", { Default = "None", Mode = "Toggle", Text = "Third Person" })

    cm:AddToggle("camera_stretched_res", {
        Text = "Stretched Res", Default = false,
        Callback = function(v) ELI.camera.stretched_res = v end,
    })
    cm:AddSlider("camera_stretched_amount", {
        Text = "Stretch Amount", Min = 0.1, Max = 1, Default = 0.20, Rounding = 2,
        Callback = function(v) ELI.camera.stretched_res_amount = v end,
    })
    cm:AddToggle("camera_fov_enable", {
        Text = "FOV Changer", Default = false,
        Callback = function(v) ELI.camera.fov_changer = v end,
    })
    cm:AddSlider("camera_fov", {
        Text = "FOV", Min = 10, Max = 140, Default = 80, Rounding = 0,
        Callback = function(v) ELI.camera.fov = v end,
    })
end

do
    local iu = Tabs.Misc:AddLeftGroupbox("Inventory Unlocker", "unlock")
    if getgenv().byte_unlock_all == nil then getgenv().byte_unlock_all = true end
    iu:AddToggle("inv_unlock_all", {
        Text = "Unlock & Force Equip",
        Default = getgenv().byte_unlock_all,
        Tooltip = "Unlocks everything. Click any skin in the native shop to force-equip it.",
        Callback = function(v)
            getgenv().byte_unlock_all = v
            if v and getgenv().byte_do_full_unlock then
                getgenv().byte_do_full_unlock()
            end
        end,
    })
    iu:AddLabel("Click skins in the default game shop.")

    local ds = Tabs.Misc:AddLeftGroupbox("Device Spoof", "monitor")
    ds:AddDropdown("DeviceSpoof_Type", {
        Text = "Device", Values = { "PC", "Mobile", "Console" }, Default = "PC",
        Callback = function(v) getgenv().txtDeviceSpoofType = v end,
    })
    ds:AddButton({ Text = "Apply & Rejoin", Callback = ApplyDeviceSpoof })

    local al = Tabs.Misc:AddLeftGroupbox("Auto Loadout", "package")
    al:AddToggle("auto_loadout_enable", {
        Text = "Enable", Default = false,
        Callback = function(v) ELI.auto_loadout.enable = v end,
    })
    local classes = { "Primary", "Secondary", "Melee", "Utility" }
    local class_idx = { Primary=1, Secondary=2, Melee=3, Utility=4 }
    for _, cls in ipairs(classes) do
        local items = sorted_items[cls] or {}
        if #items == 0 then items = { "None" } end
        local default = ELI.auto_loadout.loadout[class_idx[cls]]
        local valid = false
        for _, item in ipairs(items) do
            if item == default then valid = true; break end
        end
        if not valid then default = items[1] end
        al:AddDropdown("auto_loadout_" .. cls:lower(), {
            Text = cls,
            Values = items,
            Default = default,
            Callback = function(v) ELI.auto_loadout.loadout[class_idx[cls]] = v end,
        })
    end

    local aq = Tabs.Misc:AddRightGroupbox("Auto Queue", "repeat")
    aq:AddToggle("auto_queue_enable", {
        Text = "Enable", Default = false,
        Callback = function(v) ELI.auto_queue.enable = v; if not v then clicked_queue = false end end,
    })
    aq:AddDropdown("auto_queue_mode", {
        Text = "Queue Mode",
        Values = { "1v1", "2v2", "3v3", "4v4", "5v5", "2v2_beginner" },
        Default = "1v1",
        AllowNull = true,
        Callback = function(v) ELI.auto_queue.queue_mode = v or "" end,
    })

    local av = Tabs.Misc:AddRightGroupbox("Auto Vote Map", "map")
    av:AddToggle("auto_vote_enable", {
        Text = "Enable", Default = false,
        Callback = function(v) ELI.auto_vote_map.enable = v end,
    })
    av:AddDropdown("auto_vote_map", {
        Text = "Map",
        Values = { "Arena","Big Graveyard","Docks","Splash","Bridge","Crossroads","Big Crossroads","Big Backrooms","Battleground","Big Arena","Construction","Playground","Onyx","Graveyard","Big Splash","Big Onyx","Backrooms","Station","Dimension" },
        Default = "Arena",
        AllowNull = true,
        Callback = function(v) ELI.auto_vote_map.map = v or "" end,
    })

    local sp = Tabs.Misc:AddLeftGroupbox("Spoofs", "fingerprint")
    sp:AddToggle("sp_status", {
        Text = "PlayerStatus Spoof", Default = false,
        Callback = function(v) ELI.spoof.player_status.enable = v end,
    })
    sp:AddDropdown("sp_status_val", {
        Text = "Status",
        Values = { "Online", "In Lobby", "In Match", "In Queue", "Away", "Do Not Disturb" },
        Default = "Online",
        Callback = function(v) ELI.spoof.player_status.select = v end,
    })
    sp:AddToggle("sp_level", {
        Text = "Level Spoof", Default = false,
        Callback = function(v)
            ELI.spoof.level.enable = v
            if not v then pcall(function() LocalPlayer:SetAttribute("Level", spoof_old.level) end) end
        end,
    })
    sp:AddInput("sp_level_val", { Text = "Level", Default = "9", Numeric = true, Finished = true,
        Callback = function(v) local n = tonumber(v); if n then ELI.spoof.level.value = n end end })
    sp:AddToggle("sp_streak", {
        Text = "Streak Spoof", Default = false,
        Callback = function(v)
            ELI.spoof.streak.enable = v
            if not v then pcall(function() LocalPlayer:SetAttribute("StatisticDuelsWinStreak", spoof_old.streak) end) end
        end,
    })
    sp:AddInput("sp_streak_val", { Text = "Streak", Default = "9", Numeric = true, Finished = true,
        Callback = function(v) local n = tonumber(v); if n then ELI.spoof.streak.value = n end end })
    sp:AddToggle("sp_elo", {
        Text = "ELO Spoof", Default = false,
        Callback = function(v)
            ELI.elo_spoof.enable = v
            if not v then pcall(function() LocalPlayer:SetAttribute("DisplayELO", spoof_old.elo) end) end
        end,
    })
    sp:AddInput("sp_elo_val", { Text = "ELO", Default = "60000", Numeric = true, Finished = true,
        Callback = function(v) local n = tonumber(v); if n then ELI.elo_spoof.value = n end end })
    sp:AddToggle("sp_rank", {
        Text = "Rank Spoof (visual only)", Default = false,
        Callback = function(v) ELI.rank_spoof.enable = v end,
    })
    sp:AddDropdown("sp_rank_val", {
        Text = "Rank",
        Values = { "Bronze","Silver","Gold","Diamond","Onyx","Nemesis","Arch Nemesis" },
        Default = "Arch Nemesis",
        Callback = function(v) ELI.rank_spoof.rank = v end,
    })

    local ns = Tabs.Misc:AddRightGroupbox("Name Spoof", "user-pen")
    ns:AddToggle("sp_name", {
        Text = "Enable", Default = false,
        Callback = function(v) ELI.name_spoof.enable = v end,
    })
    ns:AddInput("sp_name_display", {
        Text = "Display Name", Default = "", Placeholder = "display name", Finished = true,
        Callback = function(v) ELI.name_spoof.display = v or "" end,
    })
    ns:AddInput("sp_name_user", {
        Text = "Username", Default = "", Placeholder = "username", Finished = true,
        Callback = function(v) ELI.name_spoof.username = v or "" end,
    })
end

do
    local fb = Tabs.Optimizations:AddLeftGroupbox("FPS Boost", "zap")
    local apply = function(kind) pcall(function() getgenv().byte_apply_opt(kind) end) end
    fb:AddToggle("opt_no_particles", { Text = "Remove Particles & Effects", Default = false,
        Callback = function(v) ELI.optimizations.no_particles = v; apply("particles") end })
    fb:AddToggle("opt_no_shadows", { Text = "Disable Shadows", Default = false,
        Callback = function(v) ELI.optimizations.no_shadows = v; apply("shadows") end })
    fb:AddToggle("opt_no_postfx", { Text = "Disable Post Processing", Default = false,
        Callback = function(v) ELI.optimizations.no_postfx = v; apply("postfx") end })
    fb:AddToggle("opt_low_quality", { Text = "Low Render Quality", Default = false,
        Callback = function(v) ELI.optimizations.low_quality = v; apply("quality") end })
    fb:AddToggle("opt_no_atmosphere", { Text = "Disable Atmosphere & Clouds", Default = false,
        Callback = function(v) ELI.optimizations.no_atmosphere = v; apply("atmosphere") end })
    fb:AddToggle("opt_no_textures", { Text = "Remove Textures", Default = false,
        Callback = function(v) ELI.optimizations.no_textures = v; apply("textures") end })
    fb:AddButton({ Text = "Quick Boost (All)", Callback = function()
        Library.Toggles.opt_no_particles:SetValue(true)
        Library.Toggles.opt_no_shadows:SetValue(true)
        Library.Toggles.opt_no_postfx:SetValue(true)
        Library.Toggles.opt_low_quality:SetValue(true)
        Library.Toggles.opt_no_atmosphere:SetValue(true)
        notify("Applied FPS Boost")
    end })

    local fr = Tabs.Optimizations:AddRightGroupbox("Frame Rate", "gauge")
    fr:AddToggle("opt_fps_cap_enable", {
        Text = "Limit FPS", Default = false,
        Callback = function(v)
            ELI.optimizations.fps_cap_enable = v
            apply("fpscap")
            if v and not setfpscap then
                notify("Your executor has no setfpscap. Use the FFlag injector below then rejoin.")
            end
        end,
    })
    fr:AddSlider("opt_fps_cap", {
        Text = "FPS Limit", Min = 30, Max = 240, Default = 60, Rounding = 0,
        Callback = function(v) ELI.optimizations.fps_cap = v; apply("fpscap") end,
    })

end

local sfov_gui = Instance.new("ScreenGui")
sfov_gui.ResetOnSpawn = false
sfov_gui.IgnoreGuiInset = true
sfov_gui.Parent = gethui()
local sfov = Instance.new("Frame", sfov_gui)
sfov.BorderSizePixel = 0
sfov.Visible = false
sfov.BackgroundTransparency = 1
Instance.new("UICorner", sfov).CornerRadius = UDim.new(1,0)
local sfov_stroke = Instance.new("UIStroke", sfov)
sfov_stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local sfov_fill_grad = Instance.new("UIGradient", sfov)
local sfov_stroke_grad = Instance.new("UIGradient", sfov_stroke)

local afov_gui = Instance.new("ScreenGui")
afov_gui.ResetOnSpawn = false
afov_gui.IgnoreGuiInset = true
afov_gui.Parent = gethui()
local afov = Instance.new("Frame", afov_gui)
afov.BorderSizePixel = 0
afov.Visible = false
afov.BackgroundTransparency = 1
Instance.new("UICorner", afov).CornerRadius = UDim.new(1,0)
local afov_stroke = Instance.new("UIStroke", afov)
afov_stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
local afov_fill_grad = Instance.new("UIGradient", afov)
local afov_stroke_grad = Instance.new("UIGradient", afov_stroke)

local sfov_pos, sfov_radius = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2), ELI.silent_aim.fov_radius
local afov_pos, afov_radius = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2), ELI.aimbot.fov_radius
local fov_rotation = 0

local function GetMuzzlePos()
    if FirstPerson then
        for _, P in ipairs(FirstPerson:GetDescendants()) do
            if P.Name == "_muzzle" and P:IsA("Attachment") then
                local Pos = Camera:WorldToViewportPoint(P.WorldPosition)
                return Vector2.new(Pos.X, Pos.Y)
            end
        end
    end
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

giveSignal(RunService.Heartbeat:Connect(function(dt)
    local s_show = ELI.silent_aim.enable and ELI.silent_aim.show_fov
    local a_show = ELI.aimbot.enable and ELI.aimbot.show_fov
    if not s_show and not a_show then
        if sfov.Visible then sfov.Visible = false end
        if afov.Visible then afov.Visible = false end
        return
    end
    fov_rotation = (fov_rotation + ELI.silent_aim.fov_rotation_speed * dt) % 360
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    local smuzzle = center
    if ELI.silent_aim.follow_target then
        local t = getclosest()
        if t and t.Character and t.Character:FindFirstChild(ELI.targeting.part) then
            local pos, on = Camera:WorldToViewportPoint(t.Character[ELI.targeting.part].Position)
            smuzzle = on and Vector2.new(pos.X, pos.Y) or center
        end
    end

    local amuzzle = center
    if ELI.aimbot.follow_target then
        local t = getclosest2()
        if t and t.Character and t.Character:FindFirstChild(ELI.targeting.part) then
            local pos, on = Camera:WorldToViewportPoint(t.Character[ELI.targeting.part].Position)
            amuzzle = on and Vector2.new(pos.X, pos.Y) or center
        end
    end

    sfov_pos = sfov_pos:Lerp(smuzzle, 1)
    sfov_radius = sfov_radius + (ELI.silent_aim.fov_radius - sfov_radius) * 1
    afov_pos = afov_pos:Lerp(amuzzle, 1)
    afov_radius = afov_radius + (ELI.aimbot.fov_radius - afov_radius) * 1

    if s_show then
        sfov.Visible = true
        sfov.BackgroundTransparency = 1
        sfov.Size = UDim2.fromOffset(sfov_radius * 2, sfov_radius * 2)
        sfov.Position = UDim2.fromOffset(sfov_pos.X - sfov_radius, sfov_pos.Y - sfov_radius)
        sfov.Rotation = fov_rotation
        sfov_stroke.Color = ELI.silent_aim.fov_color
        sfov_stroke.Transparency = ELI.silent_aim.fov_outline_transparency
        sfov_stroke.Thickness = 2
        sfov_stroke_grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, ELI.silent_aim.fov_color),
            ColorSequenceKeypoint.new(1, ELI.silent_aim.fov_color2),
        })
        sfov_stroke_grad.Rotation = fov_rotation
    else
        sfov.Visible = false
    end

    if a_show then
        afov.Visible = true
        afov.BackgroundTransparency = 1
        afov.Size = UDim2.fromOffset(afov_radius * 2, afov_radius * 2)
        afov.Position = UDim2.fromOffset(afov_pos.X - afov_radius, afov_pos.Y - afov_radius)
        afov.Rotation = fov_rotation
        afov_stroke.Color = ELI.aimbot.fov_color
        afov_stroke.Transparency = ELI.aimbot.fov_outline_transparency
        afov_stroke.Thickness = 2
        afov_stroke_grad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, ELI.aimbot.fov_color),
            ColorSequenceKeypoint.new(1, ELI.aimbot.fov_color2),
        })
        afov_stroke_grad.Rotation = fov_rotation
    else
        afov.Visible = false
    end
end))

ThemeManager:SetLibrary(Window)
SaveManager:SetLibrary(Window)
ThemeManager:SetFolder("Byte/Viz")
SaveManager:SetFolder("Byte/Viz")
SaveManager:IgnoreThemeSettings()
ThemeManager:ApplyToTab(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:LoadDefault()
pcall(function() SaveManager:LoadAutoloadConfig() end)

do
    local unloadGroup = Tabs.Settings:AddRightGroupbox("Script Control", "power")
    unloadGroup:AddButton({
        Text = "Unload Script",
        Callback = function()
            if getgenv().ByteUnload then
                getgenv().ByteUnload()
            end
        end,
        Tooltip = "Unloads the script and restores all hooks and visuals.",
    })
end

local function Unload()
    clearSignals()
    getgenv().ByteUnloaded = true

    if getgenv().byte_cosmetic_cleanup then
        pcall(getgenv().byte_cosmetic_cleanup)
        getgenv().byte_cosmetic_cleanup = nil
    end

    for p in pairs(chams_highlights) do drop_highlight(p) end
    for p in pairs(chams_bodies) do restore_body(p) end

    if ELI.guns.force_modifier_enable and item_lib and item_lib.Items then
        for i, item in pairs(item_lib.Items) do
            if item.InputSpammingEnabled and old_force_auto[i] ~= nil then
                item.InputSpammingEnabled.StartShooting = old_force_auto[i]
            end
        end
        table.clear(old_force_auto)
    end


    pcall(function() sfov_gui:Destroy() end)
    pcall(function() afov_gui:Destroy() end)

    local cst = getgenv().byte_cosmetic_state
    if cst and cst.gui then pcall(function() cst.gui:Destroy() end) end

    RagebotService:Stop()
    DesyncService:Stop()
    pcall(function() Library:Unload() end)
end
getgenv().ByteUnload = Unload

notify("Byte loaded - right shift to open", 4)
