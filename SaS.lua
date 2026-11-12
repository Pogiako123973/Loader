local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = ReplicatedStorage:WaitForChild("Client")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local AbilityConfig = require(Shared.Config.AbilityConfig)
local EnemyConfig = require(Shared.Config.EnemyConfig)
local SettingsController = require(Client.Controllers.SettingsController)
local PlayerState = require(Client.Core.PlayerState)
local Shields = require(Shared.Combat.Shields)
local LocalEnemyRegistry = require(Client.Core.LocalEnemyRegistry)
local Progression = require(Shared.Rules.Progression)
local PowerConfig = require(Shared.Config.PowerConfig)
local CardConfig = require(Shared.Config.CardConfig)
local BaseConfig = require(Shared.Config.BaseConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local PlaceConfig = require(Shared.Config.PlaceConfig)
local Big = require(Shared.Util.Big)
local CardIndex = require(Shared.Rules.CardIndex)

local State = {
    DamageMult = 10,
    TargetRange = 60,
    AutoAbil = false,
    IgnoreDamage = false,
    AutoNuke = false,
    AutoBuyUpgrades = false,
    AutoEquipBest = false,
    AutoPlaceBest = false,
    AutoBuyTrails = false,
    AutoBuyAuras = false,
    AutoRebirth = false,
    AutoOpenPacks = false,
    AutoBankPacks = false,
    AutoClaimAll = false,
    AutoFuseAll = false,
    AutoSacrifice = false,
    SacrificeRarities = {"Common", "Uncommon", "Rare"},
    SacrificeKeep = 1,
    LastClaim = {},
    Target = nil,
    LastCast = {},
}

do
    local Stats = game:GetService('Stats')
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
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
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

    RunService.RenderStepped:Connect(function()
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
    Main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, Main.Position
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
end

local World1Data = {
    { Area = "Ruin", Boss = "NoobKing", BossPos = Vector3.new(0, 0.6, -324), Mobs = {"Noob"}, MobPos = {Vector3.new(0, 0.6, -172)} },
    { Area = "Forest", Boss = "Outlaw", BossPos = Vector3.new(0, 0.6, -848), Mobs = {"BaconHair"}, MobPos = {Vector3.new(-60, 0.6, -502), Vector3.new(60, 0.6, -607), Vector3.new(-60, 0.6, -695)} },
    { Area = "Desert", Boss = "SandSultan", BossPos = Vector3.new(0, 0.6, -1395), Mobs = {"DesertRaider"}, MobPos = {Vector3.new(65, 0.6, -1010), Vector3.new(-65, 0.6, -1110), Vector3.new(40, 0.6, -1225)} },
    { Area = "Frozen Peaks", Boss = "DominusFrigidus", BossPos = Vector3.new(0, 0.6, -1990), Mobs = {"FrostNinja"}, MobPos = {Vector3.new(60, 0.6, -1600), Vector3.new(70, 0.6, -1730), Vector3.new(-60, 0.6, -1810)} },
    { Area = "Volcano", Boss = "DominusInfernus", BossPos = Vector3.new(0, 0.6, -2605), Mobs = {"MagmaImp"}, MobPos = {Vector3.new(-60, 0.6, -2160), Vector3.new(60, 0.6, -2290), Vector3.new(-70, 0.6, -2430)} },
    { Area = "Toxic Wasteland", Boss = "DominusVespertilio", BossPos = Vector3.new(0, 0.6, -3265), Mobs = {"ToxicScavenger"}, MobPos = {Vector3.new(-60, 0.6, -2810), Vector3.new(60, 0.6, -2975), Vector3.new(-60, 0.6, -3110)} },
    { Area = "Thunder Peaks", Boss = "DominusAureus", BossPos = Vector3.new(0, 0.6, -3955), Mobs = {"Valkyrie"}, MobPos = {Vector3.new(-60, 0.6, -3470), Vector3.new(60, 0.6, -3640), Vector3.new(-60, 0.6, -3785)} },
    { Area = "Shadow Realm", Boss = "DominusFormidulosus", BossPos = Vector3.new(0, 0.6, -4677), Mobs = {"ShadowNinja"}, MobPos = {Vector3.new(-60, 0.6, -4160), Vector3.new(60, 0.6, -4320), Vector3.new(-60, 0.6, -4480)} },
    { Area = "Cosmos", Boss = "DominusAstra", BossPos = Vector3.new(0, 0.6, -5427), Mobs = {"StarTrooper"}, MobPos = {Vector3.new(-60, 0.6, -4890), Vector3.new(60, 0.6, -5060), Vector3.new(-60, 0.6, -5220)} },
    { Area = "Empyrean Palace", Boss = "DominusEmpyreus", BossPos = Vector3.new(0, 0.6, -6202), Mobs = {"EmpyreanKnight"}, MobPos = {Vector3.new(-60, 0.6, -5640), Vector3.new(60, 0.6, -5810), Vector3.new(-60, 0.6, -5960)} },
}

local World2Data = {
    { Area = "RiftHall", Boss = "DarkApprentice", BossPos = Vector3.new(0, 0.6, -395), Mobs = {"OmegaKnight", "OmegaMage"}, MobPos = {Vector3.new(35, 0.6, -217), Vector3.new(-45, 0.6, -281), Vector3.new(46, 0.6, -281)} },
    { Area = "Palace", Boss = "CrimsonVoidcaller", BossPos = Vector3.new(0, 0.6, -868), Mobs = {"CrimsonSentinel", "RiftCantor"}, MobPos = {Vector3.new(-20, 0.6, -550), Vector3.new(22, 0.6, -680)} },
    { Area = "Stage3", Boss = "GrimGlow", BossPos = Vector3.new(0, -0.4, -1521), Mobs = {"WanwoodAcolyte", "CursedWarden"}, MobPos = {Vector3.new(25, -0.4, -1060), Vector3.new(-32, -0.4, -1150), Vector3.new(31, -0.4, -1270)} },
    { Area = "Stage4", Boss = "SolemnDarkOne", BossPos = Vector3.new(-25, 0.6, -2196), Mobs = {"DungeonHeadsman", "CandleVotary"}, MobPos = {Vector3.new(-18, -0.4, -1790), Vector3.new(6, -0.4, -1960)} },
    { Area = "Stage5", Boss = "FoolOfTheFederation", BossPos = Vector3.new(0, 5.6, -2764), Mobs = {"FederationJester"}, MobPos = {Vector3.new(-35, 1.6, -2505), Vector3.new(35, 1.6, -2575), Vector3.new(-35, 1.6, -2645)} },
    { Area = "AmberCanyon", Boss = "ViscountOfTheFederation", BossPos = Vector3.new(0, 7.1, -3418), Mobs = {"AmberSentry"}, MobPos = {Vector3.new(-60, 7.1, -2987), Vector3.new(60, 7.1, -3113), Vector3.new(-70, 7.1, -3249)} },
    { Area = "EmeraldGrotto", Boss = "EarlOfTheFederation", BossPos = Vector3.new(0, 7.1, -4033), Mobs = {"EmeraldWarden"}, MobPos = {Vector3.new(60, 7.1, -3631), Vector3.new(70, 7.1, -3764), Vector3.new(-60, 7.1, -3846)} },
    { Area = "CopperRuins", Boss = "DisgracedBaronOfTheFederation", BossPos = Vector3.new(0, 7.1, -4693), Mobs = {"CopperRevenant"}, MobPos = {Vector3.new(-60, 7.1, -4238), Vector3.new(60, 7.1, -4403), Vector3.new(-60, 7.1, -4538)} },
    { Area = "AmethystFields", Boss = "ArchdukeOfTheFederation", BossPos = Vector3.new(0, 7.1, -5383), Mobs = {"AmethystCourtier"}, MobPos = {Vector3.new(-60, 7.1, -4898), Vector3.new(60, 7.1, -5068), Vector3.new(-60, 7.1, -5213)} },
    { Area = "CrimsonGardens", Boss = "DukeOfTheFederation", BossPos = Vector3.new(0, 7.1, -6105), Mobs = {"CrimsonRonin"}, MobPos = {Vector3.new(-60, 7.1, -5588), Vector3.new(60, 7.1, -5748), Vector3.new(-60, 7.1, -5908)} },
    { Area = "VioletTundra", Boss = "LadyOfTheFederation", BossPos = Vector3.new(0, 7.1, -6855), Mobs = {"FrostlitHerald"}, MobPos = {Vector3.new(-60, 7.1, -6358), Vector3.new(-70, 7.1, -6535), Vector3.new(60, 7.1, -6643)} },
    { Area = "SapphireLagoon", Boss = "LordOfTheFederation", BossPos = Vector3.new(0, 7.1, -7812), Mobs = {"TideKnight"}, MobPos = {Vector3.new(70, 7.1, -7152), Vector3.new(-70, 7.1, -7322), Vector3.new(60, 7.1, -7492)} },
}

local DropdownList = {}
for _, data in ipairs(World1Data) do table.insert(DropdownList, "W1 | " .. data.Area) end
for _, data in ipairs(World2Data) do table.insert(DropdownList, "W2 | " .. data.Area) end

local FarmState = {
    Enabled = false,
    BossOnly = false,
    SelectedLocations = {"Ruin", "Forest", "Desert"},
    CurrentAreaIndex = 1,
    AreaTime = 0,
    CurrentTarget = nil,
    TargetTime = 0,
    HoverCFrame = nil,
    IgnoredEnemies = {},
}

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local enemyClaim = remotes:FindFirstChild("EnemyClaim")
local benchStop = remotes:FindFirstChild("BenchStop")
local enemiesFolder = Workspace:WaitForChild("Enemies", 10)

local killEnemy, nukeAllInRange

local Window = Library:CreateWindow({
    Title = "Steal a Superpower",
    Layout = "Bottom bar",
    MenuKey = Enum.KeyCode.RightShift,
})

local Combat = Window:AddTab("Combat", "sword")
local WorldFarm = Window:AddTab("World farm", "globe")
local Dungeon = Window:AddTab("Auto Farm", "door-open")
local SettingsTab = Window:CreateSettingsTab()

local DamageGroup = Combat:AddLeftGroupbox("Damage boost", "zap")
local AutoGroup = Combat:AddRightGroupbox("Automatic combat", "crosshair")

local BoostDamageToggle = DamageGroup:AddToggle("BoostDamage", { Text = "Boost Damage", Default = false, Notify = true, Callback = function(v) LocalPlayer:SetAttribute("DamageMultiplier", v and State.DamageMult or 1) end })
BoostDamageToggle:AddKeyPicker("BoostDamage_Keybind", { Text = "Boost Damage", Mode = "Toggle" })

local IgnoreDamageToggle = DamageGroup:AddToggle("IgnoreDamage", { Text = "No Damage/Stun", Default = false, Notify = true, Callback = function(v) State.IgnoreDamage = v; setIgnoreDamage(v) end })
IgnoreDamageToggle:AddKeyPicker("IgnoreDamage_Keybind", { Text = "No Damage/Stun", Mode = "Toggle" })

DamageGroup:AddSlider("DamageMultSlider", { Text = "Damage multiplier", Min = 1, Max = 1e308, Default = 1e6, Callback = function(v) State.DamageMult = v; if Library.Options.BoostDamage and Library.Options.BoostDamage.Value then LocalPlayer:SetAttribute("DamageMultiplier", v) end end })

local AutoAttackToggle = AutoGroup:AddToggle("AutoAttack", { Text = "Auto attack", Default = false, Notify = true, Callback = function(v) SettingsController.Set("AutoAttack", v) end })
AutoAttackToggle:AddKeyPicker("AutoAttack_Keybind", { Text = "Auto primary attack", Mode = "Toggle" })

local AutoAbilitiesToggle = AutoGroup:AddToggle("AutoAbilities", { Text = "Auto abilities", Default = false, Notify = true, Callback = function(v) State.AutoAbil = v end })
AutoAbilitiesToggle:AddKeyPicker("AutoAbilities_Keybind", { Text = "Auto abilities", Mode = "Toggle" })

local AutoNukeToggle = AutoGroup:AddToggle("AutoNuke", { Text = "Kill Aura", Default = false, Notify = true, Callback = function(v) State.AutoNuke = v end })
AutoNukeToggle:AddKeyPicker("AutoNuke_Keybind", { Text = "Kill Aura", Mode = "Toggle" })

AutoGroup:AddSlider("TargetRangeSlider", { Text = "Target range", Min = 10, Max = 1000, Default = 60, Callback = function(v) State.TargetRange = v end })

local AutoFarmGroup = WorldFarm:AddLeftGroupbox("Auto Features", "bot")
local AutoFarmGroupRight = WorldFarm:AddRightGroupbox("More Features", "bot")

local AutoBuyUpgradesToggle = AutoFarmGroup:AddToggle("AutoBuyUpgrades", { Text = "Auto buy upgrades", Default = false, Notify = true, Callback = function(v) State.AutoBuyUpgrades = v end })
AutoBuyUpgradesToggle:AddKeyPicker("AutoBuyUpgrades_Keybind", { Text = "Auto buy upgrades", Mode = "Toggle" })

local AutoEquipBestToggle = AutoFarmGroup:AddToggle("AutoEquipBest", { Text = "Auto equip best cards", Default = false, Notify = true, Callback = function(v) State.AutoEquipBest = v end })
AutoEquipBestToggle:AddKeyPicker("AutoEquipBest_Keybind", { Text = "Auto equip best cards", Mode = "Toggle" })

local AutoPlaceBestToggle = AutoFarmGroup:AddToggle("AutoPlaceBest", { Text = "Auto place best cards in plot", Default = false, Notify = true, Callback = function(v) State.AutoPlaceBest = v end })
AutoPlaceBestToggle:AddKeyPicker("AutoPlaceBest_Keybind", { Text = "Auto place best cards", Mode = "Toggle" })

local AutoClaimAllToggle = AutoFarmGroup:AddToggle("AutoClaimAll", { Text = "Auto claim all rewards", Default = false, Notify = true, Callback = function(v) State.AutoClaimAll = v end })
AutoClaimAllToggle:AddKeyPicker("AutoClaimAll_Keybind", { Text = "Auto claim all rewards", Mode = "Toggle" })

local AutoFuseAllToggle = AutoFarmGroup:AddToggle("AutoFuseAll", { Text = "Auto fuse all cards", Default = false, Notify = true, Callback = function(v) State.AutoFuseAll = v end })
AutoFuseAllToggle:AddKeyPicker("AutoFuseAll_Keybind", { Text = "Auto fuse all cards", Mode = "Toggle" })

local AutoRebirthToggle = AutoFarmGroupRight:AddToggle("AutoRebirth", { Text = "Auto rebirth", Default = false, Notify = true, Callback = function(v) State.AutoRebirth = v end })
AutoRebirthToggle:AddKeyPicker("AutoRebirth_Keybind", { Text = "Auto rebirth", Mode = "Toggle" })

local AutoOpenPacksToggle = AutoFarmGroupRight:AddToggle("AutoOpenPacks", { Text = "Auto open packs", Default = false, Notify = true, Callback = function(v) State.AutoOpenPacks = v end })
AutoOpenPacksToggle:AddKeyPicker("AutoOpenPacks_Keybind", { Text = "Auto open packs", Mode = "Toggle" })

local AutoBankPacksToggle = AutoFarmGroupRight:AddToggle("AutoBankPacks", { Text = "Auto bank packs", Default = false, Notify = true, Callback = function(v) State.AutoBankPacks = v end })
AutoBankPacksToggle:AddKeyPicker("AutoBankPacks_Keybind", { Text = "Auto bank packs", Mode = "Toggle" })

local AutoBuyTrailsToggle = AutoFarmGroupRight:AddToggle("AutoBuyTrails", { Text = "Auto buy best trail", Default = false, Notify = true, Callback = function(v) State.AutoBuyTrails = v end })
AutoBuyTrailsToggle:AddKeyPicker("AutoBuyTrails_Keybind", { Text = "Auto buy best trail", Mode = "Toggle" })

local AutoBuyAurasToggle = AutoFarmGroupRight:AddToggle("AutoBuyAuras", { Text = "Auto buy best aura", Default = false, Notify = true, Callback = function(v) State.AutoBuyAuras = v end })
AutoBuyAurasToggle:AddKeyPicker("AutoBuyAuras_Keybind", { Text = "Auto buy best aura", Mode = "Toggle" })

local ShardGroup = Dungeon:AddRightGroupbox("Shard Farming", "sprout")

local AutoSacrificeToggle = ShardGroup:AddToggle("AutoSacrifice", { Text = "Auto sacrifice cards for shards", Default = false, Notify = true, Callback = function(v) State.AutoSacrifice = v end })
AutoSacrificeToggle:AddKeyPicker("AutoSacrifice_Keybind", { Text = "Auto sacrifice", Mode = "Toggle" })

ShardGroup:AddDropdown("SacrificeRarities", {
    Text = "Rarities to sacrifice",
    Values = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "God", "Secret", "Cosmic", "Ancient", "Cursed", "Omega", "Ethereal", "Divine", "Void"},
    Default = {"Common", "Uncommon", "Rare"},
    Multi = true,
    Callback = function(v)
        State.SacrificeRarities = {}
        for k, val in pairs(v) do
            if val then table.insert(State.SacrificeRarities, k) end
        end
    end,
})

ShardGroup:AddSlider("SacrificeKeep", {
    Text = "Keep at least N of each card",
    Min = 1,
    Max = 10,
    Default = 1,
    Rounding = 0,
    Callback = function(v) State.SacrificeKeep = v end,
})

local FarmGroup = Dungeon:AddLeftGroupbox("Auto Farm", "crosshair")

local FarmEnabledToggle = FarmGroup:AddToggle("FarmEnabled", {
    Text = "Enable Auto Farm",
    Default = false,
    Notify = true,
    Callback = function(v) 
        FarmState.Enabled = v 
        FarmState.CurrentAreaIndex = 1
        FarmState.AreaTime = 0
        FarmState.CurrentTarget = nil
        table.clear(FarmState.IgnoredEnemies)
        if not v then FarmState.HoverCFrame = nil end 
    end,
})
FarmEnabledToggle:AddKeyPicker("FarmEnabled_Keybind", { Text = "Enable Auto Farm", Mode = "Toggle" })

local FarmBossOnlyToggle = FarmGroup:AddToggle("FarmBossOnly", { Text = "Farm Bosses Only", Default = false, Notify = true, Callback = function(v) FarmState.BossOnly = v; FarmState.CurrentTarget = nil end })
FarmBossOnlyToggle:AddKeyPicker("FarmBossOnly_Keybind", { Text = "Farm Bosses Only", Mode = "Toggle" })
FarmGroup:AddDropdown("FarmAreas", {
    Text = "Select Areas to Farm",
    Values = DropdownList,
    Default = {"W1 | Ruin", "W1 | Forest", "W1 | Desert"},
    Multi = true,
    Callback = function(v) 
        FarmState.SelectedLocations = {}
        for k, val in pairs(v) do
            if val then 
                local cleanName = string.match(k, "| (.*)") or k
                table.insert(FarmState.SelectedLocations, cleanName) 
            end
        end
        FarmState.CurrentAreaIndex = 1
        FarmState.AreaTime = 0
        FarmState.CurrentTarget = nil; 
        table.clear(FarmState.IgnoredEnemies)
    end,
})

local oldAbsorb = Shields.Absorb
local oldGuarded = Shields.Guarded

function setIgnoreDamage(active)
    if active then
        Shields.Absorb = function(character, ...) if character == LocalPlayer.Character then return true, false end return oldAbsorb(character, ...) end
        Shields.Guarded = function(character) if character == LocalPlayer.Character then return true end return oldGuarded(character) end
    else
        Shields.Absorb = oldAbsorb; Shields.Guarded = oldGuarded
    end
end

killEnemy = function(model)
    if not (model and model.Parent) then return false end
    if model:GetAttribute("Dead") or model:GetAttribute("DeadLocal") then return false end
    if type(LocalEnemyRegistry.Damage) == "function" then
        pcall(LocalEnemyRegistry.Damage, model, math.huge, Vector3.zero, "Hit", true)
    end
    if enemyClaim then pcall(function() enemyClaim:FireServer(model) end) end
    return true
end

nukeAllInRange = function(range)
    local char = LocalPlayer.Character
    if not char then return 0 end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return 0 end
    local n = 0
    for _, model in ipairs(CollectionService:GetTagged(EnemyConfig.Tag)) do
        local eroot = model:FindFirstChild("HumanoidRootPart")
        if eroot and (eroot.Position - root.Position).Magnitude <= range then
            if killEnemy(model) then n = n + 1 end
        end
    end
    return n
end

RunService.Heartbeat:Connect(function()
    if FarmState.Enabled and FarmState.HoverCFrame and LocalPlayer.Character and LocalPlayer.Character.Parent then
        LocalPlayer.Character:PivotTo(FarmState.HoverCFrame)
    end
end)

-- ============================================================
-- AUTO FARM CORE (STRICT 10s AREA TIMER)
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.1)
        if FarmState.Enabled and LocalPlayer.Character and LocalPlayer.Character.Parent then
            LocalPlayer:SetAttribute("DamageMultiplier", math.huge)
            if benchStop then benchStop:FireServer() end
            
            if #FarmState.SelectedLocations == 0 then
                FarmState.HoverCFrame = nil
                continue
            end
            
            if FarmState.CurrentAreaIndex > #FarmState.SelectedLocations then
                FarmState.CurrentAreaIndex = 1
            end
            
            local currentArea = FarmState.SelectedLocations[FarmState.CurrentAreaIndex]
            local areaData = nil
            for _, data in ipairs(World1Data) do
                if data.Area == currentArea then areaData = data; break end
            end
            if not areaData then
                for _, data in ipairs(World2Data) do
                    if data.Area == currentArea then areaData = data; break end
                end
            end

            if not areaData then
                FarmState.CurrentAreaIndex = FarmState.CurrentAreaIndex + 1
                continue
            end
            
            FarmState.AreaTime = FarmState.AreaTime + 0.1
            local pos = LocalPlayer.Character:GetPivot().Position
            
            local target = nil
            local bossModel = nil
            local bestMob = nil
            local bestMobDist = math.huge
            
            if enemiesFolder then
                for _, e in ipairs(enemiesFolder:GetChildren()) do
                    if e:IsA("Model") and not (e:GetAttribute("Dead") or e:GetAttribute("DeadLocal")) and not FarmState.IgnoredEnemies[e] then
                        if e.Name == areaData.Boss then
                            bossModel = e
                        elseif not FarmState.BossOnly and table.find(areaData.Mobs, e.Name) then
                            local d = (e:GetPivot().Position - pos).Magnitude
                            if d < bestMobDist then
                                bestMob = e
                                bestMobDist = d
                            end
                        end
                    end
                end
            end

            if FarmState.BossOnly then
                target = bossModel
                if not target then
                    FarmState.CurrentAreaIndex = FarmState.CurrentAreaIndex + 1
                    FarmState.AreaTime = 0
                    FarmState.CurrentTarget = nil
                    continue
                end
            else
                local closestDist = math.huge
                if bossModel then
                    target = bossModel
                    closestDist = (bossModel:GetPivot().Position - pos).Magnitude
                end
                if bestMob then
                    local d = (bestMob:GetPivot().Position - pos).Magnitude
                    if d < closestDist then
                        target = bestMob
                    end
                end
            end

            if FarmState.AreaTime > 10 then
                FarmState.CurrentAreaIndex = FarmState.CurrentAreaIndex + 1
                FarmState.AreaTime = 0
                FarmState.CurrentTarget = nil
                table.clear(FarmState.IgnoredEnemies)
                continue
            end

            if target then
                if FarmState.CurrentTarget ~= target then
                    FarmState.CurrentTarget = target
                    FarmState.TargetTime = 0
                end
                FarmState.TargetTime = FarmState.TargetTime + 0.1
                
                if FarmState.TargetTime > 3 then
                    FarmState.IgnoredEnemies[target] = true
                    FarmState.CurrentTarget = nil
                    target = nil
                end
            else
                FarmState.CurrentTarget = nil
            end

            if target then
                FarmState.HoverCFrame = CFrame.lookAt(target:GetPivot().Position + Vector3.new(0, 25, 0), target:GetPivot().Position)
                killEnemy(target)
            else
                local hoverPos = areaData.BossPos
                if not FarmState.BossOnly and #areaData.MobPos > 0 then
                    hoverPos = areaData.MobPos[1]
                end
                FarmState.HoverCFrame = CFrame.lookAt(hoverPos + Vector3.new(0, 25, 0), hoverPos)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        if State.AutoAbil and LocalPlayer.Character and PlayerState.Data then
            local target = FarmState.CurrentTarget or CollectionService:GetTagged(EnemyConfig.Tag)[1]
            if target and target:FindFirstChild("HumanoidRootPart") then
                local troot = target.HumanoidRootPart
                local now = os.clock()
                local loadout = AbilityConfig.Loadout(PlayerState.Data)
                local primary = AbilityConfig.Primary(PlayerState.Data)
                
                if primary then
                    local def = AbilityConfig.Get(primary.Id)
                    if def and now - (State.LastCast[primary.Id] or 0) >= (def.Cooldown or 0.5) then
                        State.LastCast[primary.Id] = now
                        Remotes.UseAbility:FireServer(primary.Card, primary.Id, troot.Position, def.Predict, 1)
                    end
                end
                for _, entry in ipairs(loadout) do
                    if entry.Id ~= (primary and primary.Id) then
                        local def = AbilityConfig.Get(entry.Id)
                        if def and not def.HoldStep and now - (State.LastCast[entry.Id] or 0) >= (def.Cooldown or 0.5) then
                            State.LastCast[entry.Id] = now
                            Remotes.UseAbility:FireServer(entry.Card, entry.Id, troot.Position, def.Predict, 2)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.25)
        if State.AutoNuke then nukeAllInRange(State.TargetRange) end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if State.AutoBuyUpgrades and PlayerState.Data then
            local Data = PlayerState.Data
            local benchLvl = Data.Base.Bench or 1
            if benchLvl < BaseConfig.BenchMaxLevel and Big.ge(Data.Cash, tostring(BaseConfig.BenchCost(benchLvl))) then
                pcall(function() Remotes.BenchUpgrade:FireServer() end); task.wait(0.3)
            end
            for _, upgrade in pairs(Progression.Upgrades) do
                local level = Progression.UpgradeLevel(Data, upgrade.Id)
                if level < upgrade.MaxLevel and Big.ge(Data.Cash, tostring(Progression.UpgradeCost(upgrade.Id, level))) then
                    pcall(function() Remotes.BuyUpgrade:InvokeServer(upgrade.Id) end); task.wait(0.3); break
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1.5)
        if State.AutoEquipBest and Remotes:FindFirstChild("EquipBest") then pcall(function() Remotes.EquipBest:InvokeServer() end) end
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        if State.AutoPlaceBest and PlayerState.Data then
            local Data = PlayerState.Data
            local holders, changed = BaseConfig.BestHolders(Data)
            if changed then
                local bases = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Bases")
                if bases then
                    for _, plot in ipairs(bases:GetChildren()) do
                        if plot:GetAttribute("Owner") == LocalPlayer.UserId then
                            local bestButton = plot:FindFirstChild("BestButton")
                            local pressPart = bestButton and (bestButton:FindFirstChild("Press") or bestButton.PrimaryPart)
                            local prompt = bestButton and bestButton:FindFirstChild("BestPrompt", true)
                            if pressPart and prompt and LocalPlayer.Character then
                                local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if root then
                                    local old = root.CFrame
                                    LocalPlayer.Character:PivotTo(pressPart.CFrame + Vector3.new(0, 3, 0))
                                    task.wait(0.2); pcall(function() fireproximityprompt(prompt) end)
                                    task.wait(0.5); LocalPlayer.Character:PivotTo(old)
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1.5)
        local data = PlayerState.Data
        if data then
            if State.AutoBuyTrails then
                local kindConfig = CosmeticConfig.Kinds.Trail
                local owned = data[kindConfig.Owned] or {}
                local bestId, bestStat = nil, -1
                for _, item in ipairs(kindConfig.ShopItems) do
                    if (item.World == nil or item.World == PlaceConfig.World) and not item.RobuxOnly then
                        local canAfford = type(item.Price) == "number" and Big.ge(data.Cash, tostring(item.Price))
                        if owned[item.Id] or canAfford then
                            local stat = item.Speed or 0
                            if stat > bestStat then bestStat = stat; bestId = item.Id end
                        end
                    end
                end
                if bestId then
                    if not owned[bestId] then pcall(function() Remotes.BuyCosmetic:InvokeServer("Trail", bestId) end); task.wait(0.5) end
                    pcall(function() Remotes.EquipCosmetic:InvokeServer("Trail", bestId) end)
                end
            end
            if State.AutoBuyAuras then
                local kindConfig = CosmeticConfig.Kinds.Aura
                local owned = data[kindConfig.Owned] or {}
                local bestId, bestStat = nil, -1
                for _, item in ipairs(kindConfig.ShopItems) do
                    if (item.World == nil or item.World == PlaceConfig.World) and not item.RobuxOnly then
                        local canAfford = type(item.Price) == "number" and Big.ge(data.Cash, tostring(item.Price))
                        if owned[item.Id] or canAfford then
                            local stat = item.Multiplier or 0
                            if stat > bestStat then bestStat = stat; bestId = item.Id end
                        end
                    end
                end
                if bestId then
                    if not owned[bestId] then pcall(function() Remotes.BuyCosmetic:InvokeServer("Aura", bestId) end); task.wait(0.5) end
                    pcall(function() Remotes.EquipCosmetic:InvokeServer("Aura", bestId) end)
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if State.AutoRebirth and PlayerState.Data then
            local data = PlayerState.Data
            if PowerConfig.Level(data.Power) >= Progression.RebirthLevelRequirement(data.Rebirths or 0) then
                pcall(function() Remotes.Rebirth:InvokeServer() end); task.wait(2)
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if State.AutoOpenPacks and PlayerState.Data and PlayerState.Data.Packs then
            for packName, count in pairs(PlayerState.Data.Packs) do
                if count > 0 then pcall(function() Remotes.OpenPack:InvokeServer(packName, count) end); task.wait(0.25) end
            end
        end
    end
end)

task.spawn(function()
    local isBanking = false
    while true do
        task.wait(1)
        if State.AutoBankPacks and not isBanking then
            local carried = LocalPlayer:GetAttribute("CarriedPacks") or ""
            local capacity = tonumber(LocalPlayer:GetAttribute("CarryCapacity")) or 5
            local count = 0
            for _ in string.gmatch(carried, "[^;]+") do count = count + 1 end
            if count >= capacity and count > 0 then
                isBanking = true
                local oldPos = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if oldPos then oldPos = oldPos.Position end
                pcall(function() Remotes.TeleportHome:FireServer() end); task.wait(2)
                if oldPos then pcall(function() LocalPlayer.Character:PivotTo(CFrame.new(oldPos)) end) end
                isBanking = false
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        if State.AutoClaimAll and Remotes then
            local now = os.clock()
            for _, name in ipairs({"DailyClaim", "ForeverClaim", "OfflineCollect"}) do
                local last = State.LastClaim[name]
                if last == nil or now - last >= 60 then
                    State.LastClaim[name] = now
                    local r = Remotes:FindFirstChild(name)
                    if r then pcall(function() r:InvokeServer() end) end
                    task.wait(0.6)
                end
            end
            local li = State.LastClaim.Index
            if li == nil or now - li >= 120 then
                State.LastClaim.Index = now
                local ci = Remotes:FindFirstChild("ClaimIndex")
                if ci and CardIndex and PlayerState.Data then
                    for _, section in ipairs(CardIndex.Sections) do
                        if section.Reward and CardIndex.CanClaim(PlayerState.Data, section.Rarity) then
                            pcall(function() ci:InvokeServer(section.Rarity) end)
                            task.wait(0.4)
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if State.AutoFuseAll and Remotes then
            local now = os.clock()
            local last = State.LastFuse
            if last == nil or now - last >= 30 then
                State.LastFuse = now
                local r = Remotes:FindFirstChild("FuseAll")
                if r then pcall(function() r:InvokeServer() end) end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(5)
        if State.AutoSacrifice and Remotes and PlayerState.Data and CardConfig and CardConfig.ById then
            local Data = PlayerState.Data
            local cards = Data.Cards
            if type(cards) == "table" then
                local protected = {}
                for _, field in ipairs({"Equipped", "Placed", "Loadout"}) do
                    local t = Data[field]
                    if type(t) == "table" then
                        for k, v in pairs(t) do
                            if type(k) == "string" then protected[k] = true end
                            if type(v) == "string" then protected[v] = true end
                        end
                    end
                end
                local raritySet = {}
                for _, r in ipairs(State.SacrificeRarities) do raritySet[r] = true end
                local sac = Remotes:FindFirstChild("Sacrifice")
                if sac then
                    for cardId, entry in pairs(cards) do
                        if type(entry) == "table" then
                            local def = CardConfig.ById[cardId]
                            local count = tonumber(entry.Count) or 0
                            if def and raritySet[def.Rarity] and count > State.SacrificeKeep and not protected[cardId] then
                                local excess = count - State.SacrificeKeep
                                local ok = pcall(function() sac:InvokeServer(cardId, excess) end)
                                if not ok then
                                    pcall(function() sac:InvokeServer(cardId) end)
                                end
                                task.wait(0.4)
                            end
                        end
                    end
                end
            end
        end
    end
end)


function stopAll()
    if Library.Options.BoostDamage then Library.Options.BoostDamage:SetValue(false) end
    if Library.Options.IgnoreDamage then Library.Options.IgnoreDamage:SetValue(false) end
    if Library.Options.AutoAttack then Library.Options.AutoAttack:SetValue(false) end
    if Library.Options.AutoAbilities then Library.Options.AutoAbilities:SetValue(false) end
    if Library.Options.AutoNuke then Library.Options.AutoNuke:SetValue(false) end
    if Library.Options.AutoBuyUpgrades then Library.Options.AutoBuyUpgrades:SetValue(false) end
    if Library.Options.AutoEquipBest then Library.Options.AutoEquipBest:SetValue(false) end
    if Library.Options.AutoPlaceBest then Library.Options.AutoPlaceBest:SetValue(false) end
    if Library.Options.AutoBuyTrails then Library.Options.AutoBuyTrails:SetValue(false) end
    if Library.Options.AutoBuyAuras then Library.Options.AutoBuyAuras:SetValue(false) end
    if Library.Options.AutoRebirth then Library.Options.AutoRebirth:SetValue(false) end
    if Library.Options.AutoOpenPacks then Library.Options.AutoOpenPacks:SetValue(false) end
    if Library.Options.AutoBankPacks then Library.Options.AutoBankPacks:SetValue(false) end
    if Library.Options.AutoClaimAll then Library.Options.AutoClaimAll:SetValue(false) end
    if Library.Options.AutoFuseAll then Library.Options.AutoFuseAll:SetValue(false) end
    if Library.Options.AutoSacrifice then Library.Options.AutoSacrifice:SetValue(false) end
    if Library.Options.FarmEnabled then Library.Options.FarmEnabled:SetValue(false) end
    if Library.Options.FarmBossOnly then Library.Options.FarmBossOnly:SetValue(false) end

    LocalPlayer:SetAttribute("DamageMultiplier", 1)
    SettingsController.Set("AutoAttack", false)
    State.AutoAbil = false
    State.IgnoreDamage = false
    State.AutoNuke = false
    State.AutoBuyUpgrades = false
    State.AutoEquipBest = false
    State.AutoPlaceBest = false
    State.AutoBuyTrails = false
    State.AutoBuyAuras = false
    State.AutoRebirth = false
    State.AutoOpenPacks = false
    State.AutoBankPacks = false
    State.AutoClaimAll = false
    State.AutoFuseAll = false
    State.AutoSacrifice = false
    FarmState.Enabled = false
    setIgnoreDamage(false)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.F6 then stopAll() end
end)

ThemeManager:SetLibrary(Window)
SaveManager:SetLibrary(Window)
ThemeManager:SetFolder("StealASuperpower")
SaveManager:SetFolder("StealASuperpower")
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)
ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
