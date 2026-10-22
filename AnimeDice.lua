local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local RS = ReplicatedStorage

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/viseamn/Visual/main/Library.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/viseamn/Visual/main/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/viseamn/Visual/main/SaveManager.lua"))()

Library.Unloaded = false
local Connections = {}
local Window
local Tabs

local Framework = RS:WaitForChild("Framework")
local Network = RS:WaitForChild("Network")

local function requireModule(path)
    if not path then return nil end
    local success, result = pcall(require, path)
    if success then return result end
    return nil
end

local Dice = requireModule(Framework.Features.Rolling.Dice)
local Upgrades = requireModule(Framework.Features.Upgrades.Upgrades)
local PlotConfig = requireModule(Framework.Features.Plot.PlotConfig)
local EntryRegistry = requireModule(Framework.Features.Inventory.EntryRegistry)
local UnitUtil = requireModule(Framework.Features.Inventory.Kinds.Unit.UnitUtil)
local DataController = requireModule(Framework.Features.Data.DataController)
local QuestConfig = requireModule(Framework.Features.Quests.QuestConfig)
local TowerController = requireModule(Framework.Features.Towers.TowerController)
local TowersConfig = requireModule(Framework.Features.Towers.Towers)
local TreeStructure = requireModule(Framework.Features.Upgrades.TreeStructure)

local BoostConfig = requireModule(Framework.Features.Inventory.Kinds.Boost.BoostConfig)
local SpinConfig = requireModule(Framework.Features.Inventory.Kinds.Spin.SpinConfig)

local Remotes = {
    RollDice = Network.RollService.RF.RollDice,
    EquipDice = Network.DiceShopService.RE.EquipDice,
    BuyDice = Network.DiceShopService.RE.BuyDice,
    CollectBalance = Network.PlotService.RE.CollectBalance,
    LevelUpSlot = Network.PlotService.RE.LevelUpSlot,
    Rebirth = Network.RebirthService.RE.Rebirth,
    EquipBest = Network.PlotService.RE.EquipBest,
    BuyUpgrade = Network.RE.BuyUpgrade,
    BoostUse = Network.BoostService.RE.Use,
}

local NewRemotes = {
    SellInventory = Network.SellService.RF.SellInventory,
    QuestClaim = Network.QuestService.RE.Claim,
    GradeRoll = Network.GradeService.RE.Roll,
    TraitRoll = Network.TraitService.RE.Roll,
    SetLocked = Network.UnitService.RE.SetLocked,
    RedeemCode = Network.CodesService.RE.RedeemCode,
    DailyReward = Network.DailyRewardService.RE.Claim,
    OfflineEarnings = Network.OfflineEarningsService.RE.Claim,
    GroupReward = Network.GroupRewardService.RE.Claim,
    EquipBestTowerTeam = Network.Towers.RE.EquipBestTowerTeam,
    CancelTower = Network.Towers.RF.CancelTower,
}

local function safeFire(remote, ...)
    if not remote then return end
    pcall(remote.FireServer, remote, ...)
end

local function safeInvoke(remote, ...)
    if not remote then return end
    local success, result = pcall(remote.InvokeServer, remote, ...)
    return success and result or nil
end

local function getMaxSlots()
    if not PlotConfig then return 7 end
    local success, slots = pcall(function() return PlotConfig.GetMaxSlots(0) end)
    if success and type(slots) == "number" and slots > 0 then return slots end
    return 7
end

local function getOwnedUnitNames()
    local rawData = DataController and DataController.___X
    local owned = {}
    if rawData and rawData.Inventory then
        for _, v in pairs(rawData.Inventory) do
            if type(v) == "table" and v.name then
                owned[v.name] = true
            end
        end
    end
    local list = {}
    for name in pairs(owned) do table.insert(list, name) end
    table.sort(list)
    return list
end

local function getInventoryTable()
    if not DataController then return {} end
    local success, inv = pcall(function()
        if type(DataController.Inventory) == "function" then
            return DataController.Inventory()
        elseif DataController.___X and type(DataController.___X.Inventory) == "function" then
            return DataController.___X.Inventory()
        elseif DataController.___X and type(DataController.___X.Inventory) == "table" then
            return DataController.___X.Inventory
        end
        return {}
    end)
    return (success and type(inv) == "table") and inv or {}
end

local function getUnitUUID(name)
    local rawData = DataController and DataController.___X
    if not rawData or not rawData.Inventory then return nil end
    for uuid, data in pairs(rawData.Inventory) do
        if type(data) == "table" and data.name == name then
            return uuid
        end
    end
    return nil
end

local function tableContains(tbl, val)
    if not tbl then return false end
    for _, v in pairs(tbl) do
        if v == val then return true end
    end
    return false
end

local function isPotionActive(uuid)
    local active = DataController.ActiveEntries() or {}
    local entry = active[uuid]
    if not entry then return false end
    
    local remaining = tonumber(entry.remaining)
    if remaining and remaining > 0 then
        local startedAt = tonumber(entry.startedAt)
        if startedAt then
            remaining = remaining - math.max(0, workspace:GetServerTimeNow() - startedAt)
        end
        return remaining > 1
    end
    
    local expiresAt = tonumber(entry.expiresAt)
    if expiresAt then
        return (expiresAt - os.time()) > 1
    end
    
    return false
end

local maxSlots = getMaxSlots()
local ownedUnitNames = getOwnedUnitNames()

local unitDropdownValues = { "None" }
for _, name in ipairs(ownedUnitNames) do
    table.insert(unitDropdownValues, name)
end

local potionNames = {}
if BoostConfig and BoostConfig.entries then
    for k in pairs(BoostConfig.entries) do table.insert(potionNames, k) end
end
if SpinConfig and SpinConfig.entries then
    for k in pairs(SpinConfig.entries) do table.insert(potionNames, k) end
end
table.sort(potionNames)

local towerList = {}
if TowersConfig and TowersConfig.GetAll then
    for k in pairs(TowersConfig.GetAll()) do table.insert(towerList, k) end
    table.sort(towerList)
end

local config = {
    autoRoll = false, autoCollect = false, autoRebirth = false, autoQuest = false, autoEquipBuyDice = false, autoEquipBest = false,
    autoLevelUp = false, upgradeRarities = {}, upgradeChars = {}, upgradeLevelLimit = 0, autoBuyUpgrade = false,
    autoSell = false, keepEquipped = true, keepRarity = "Mythical", targetRarity = "Rare",
    autoGrade = false, autoGradeUnit = "None", keepGrades = {},
    autoTrait = false, autoTraitUnit = "None", keepTraits = {},
    autoLock = false, lockRarities = {},
    autoUsePotions = false, autoPotionTargets = {},
    autoDailyReward = false, autoOfflineEarnings = false, autoGroupReward = false,
    autoTower = false, autoTowerMode = towerList[1] or "Infinity Tower", autoTowerRotate = false, autoTowerRotateMaps = {},
    autoTowerRunsPerMap = 1, autoTowerStopFloor = 0, autoEquipBestTower = false, hideTowerCombatUI = false, rotateIndex = 1
}

local rarityRanks = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythical = 6, Divine = 7, Exotic = 8, Celestial = 9, Secret1 = 10, Secret2 = 11, Heavenly = 12, Galactic = 13 }
local rarityList = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Divine", "Exotic", "Celestial", "Secret1", "Secret2", "Heavenly", "Galactic" }

local function getUnitRarity(unitData)
    if not EntryRegistry then return "Unknown" end
    local entryConfig = EntryRegistry.getEntryConfig(unitData.name)
    if not entryConfig then return "Unknown" end
    if type(entryConfig.getRarity) == "function" then
        local success, rarity = pcall(entryConfig.getRarity, unitData.attributes or {})
        if success and type(rarity) == "string" then return rarity end
    end
    return entryConfig.rarity or "Unknown"
end

local function doAutoSell()
    local inv = getInventoryTable()
    local uuidsToSell = {}
    local equipped = nil
    
    pcall(function()
        if DataController and type(DataController.Dice) == "function" then equipped = DataController.Dice() end
    end)

    local minRank = rarityRanks[config.keepRarity] or 6

    for uuid, entry in pairs(inv) do
        if type(entry) == "table" and entry.name then
            local isEquipped = (config.keepEquipped and equipped == entry.name)
            local diceData = Dice.Get(entry.name)
            local shouldSell = true
            
            if diceData then
                local entryRank = rarityRanks[diceData.rarity] or 99
                if entryRank >= minRank then shouldSell = false end
            end
            if isEquipped then shouldSell = false end

            if shouldSell then table.insert(uuidsToSell, uuid) end
        end
    end

    if #uuidsToSell > 0 then
        pcall(function() NewRemotes.SellInventory:InvokeServer(uuidsToSell) end)
    end
end

local function isUpgradeOwned(name)
    local success, result = pcall(function() return DataController.Upgrades[name]() == true end)
    if not success then
        pcall(function()
            local upgradeState = DataController.Upgrades[name]
            if type(upgradeState) == "boolean" then result = upgradeState
            elseif type(upgradeState) == "table" and upgradeState.___X == true then result = true end
        end)
    end
    return result == true
end

local function getCurrentTowerFloor()
    local floor = 0
    pcall(function()
        local root = LocalPlayer.PlayerGui:FindFirstChild("Root")
        local tower = root and root:FindFirstChild("Tower")
        if tower then
            local screen = tower:FindFirstChild("Screen")
            local hidden = tower:FindFirstChild("Hidden")
            if screen and screen.Visible and screen:FindFirstChild("Floor") then
                floor = tonumber(string.match(screen.Floor.Text, "%d+")) or 0
            elseif hidden and hidden.Visible and hidden:FindFirstChild("Label") then
                floor = tonumber(string.match(hidden.Label.Text, "%d+")) or 0
            end
        end
    end)
    return floor
end

Window = Library:CreateWindow({
    Title = "Byte",
    Size = Vector2.new(640, 460),
    Layout = "Bottom bar",
    MenuKey = Enum.KeyCode.RightShift,
    NotificationPosition = "BottomRight"
})

Tabs = {
    Main = Window:AddTab("Main", "dices"),
    Unit = Window:AddTab("Unit", "sparkles"),
    Tower = Window:AddTab("Tower", "castle"),
    Settings = Window:AddTab("Settings", "settings")
}

local Main_AutoRoll_Group = Tabs.Main:AddLeftGroupbox("Auto Roll", "dices")
Main_AutoRoll_Group:AddToggle('AutoRoll_Toggle', {
    Text = 'Instant Auto Roll',
    Default = false,

    Callback = function(state)
        config.autoRoll = state
    end
})

local Main_AutoEquip_Group = Tabs.Main:AddLeftGroupbox("Auto Equip", "sword")
Main_AutoEquip_Group:AddToggle('AutoEquip_Toggle', {
    Text = 'Auto Equip Best Units',
    Default = false,

    Callback = function(state)
        config.autoEquipBest = state
    end
})

local Main_AutoCollect_Group = Tabs.Main:AddLeftGroupbox("Auto Collect", "coins")
Main_AutoCollect_Group:AddToggle('AutoCollect_Toggle', {
    Text = 'Auto Collect Money',
    Default = false,

    Callback = function(state)
        config.autoCollect = state
    end
})

local Main_AutoRebirth_Group = Tabs.Main:AddLeftGroupbox("Auto Rebirth", "refresh-cw")
Main_AutoRebirth_Group:AddToggle('AutoRebirth_Toggle', {
    Text = 'Enable Auto Rebirth',
    Default = false,

    Callback = function(state)
        config.autoRebirth = state
    end
})

local Main_Potion_Group = Tabs.Main:AddLeftGroupbox("Auto Potions", "flask-conical")
Main_Potion_Group:AddToggle('AutoUsePotions_Toggle', {
    Text = 'Auto Use Potions',
    Default = false,

    Callback = function(state)
        config.autoUsePotions = state
    end
})

Main_Potion_Group:AddDropdown('AutoUsePotionTarget_Dropdown', {
    Text = 'Potions',
    Values = potionNames,
    Default = {},
    Multi = true,
    
    Callback = function(state)
        config.autoPotionTargets = state
    end
})

local Main_BuyDice_Group = Tabs.Main:AddRightGroupbox("Auto Buy Dice", "shopping-cart")
Main_BuyDice_Group:AddToggle('AutoBuyDice_Toggle', {
    Text = 'Auto Equip / Buy Best Dice',
    Default = false,

    Callback = function(state)
        config.autoEquipBuyDice = state
    end
})

local Main_Upgrades_Group = Tabs.Main:AddRightGroupbox("Auto Upgrades", "zap")
Main_Upgrades_Group:AddToggle('AutoBuyUpgrade_Toggle', {
    Text = 'Auto Buy All Affordable Upgrades',
    Default = false,

    Callback = function(state)
        config.autoBuyUpgrade = state
    end
})

local Main_Quests_Group = Tabs.Main:AddRightGroupbox("Auto Quests", "scroll")
Main_Quests_Group:AddToggle('AutoQuest_Toggle', {
    Text = 'Auto Claim Quest',
    Default = false,

    Callback = function(state)
        config.autoQuest = state
    end
})

local Main_Rewards_Group = Tabs.Main:AddRightGroupbox("Auto Rewards", "gift")
Main_Rewards_Group:AddToggle('DailyReward_Toggle', {
    Text = 'Auto Claim Daily Reward',
    Default = false,

    Callback = function(state)
        config.autoDailyReward = state
    end
})

Main_Rewards_Group:AddToggle('OfflineEarnings_Toggle', {
    Text = 'Auto Claim Offline Earnings',
    Default = false,

    Callback = function(state)
        config.autoOfflineEarnings = state
    end
})

Main_Rewards_Group:AddToggle('GroupReward_Toggle', {
    Text = 'Auto Claim Group Reward',
    Default = false,

    Callback = function(state)
        config.autoGroupReward = state
    end
})

local isRedeemingCodes = false
local attemptedCodes = {}

Main_Rewards_Group:AddButton({
    Text = 'Redeem All Codes',
    Callback = function()
        if isRedeemingCodes then return end
        isRedeemingCodes = true
        local codeList = {"Halloween", "JpCoooooode", "UPDATE8", "50KCCU", "sorry4delay", "UPDATE7", "UPDATE6", "400KLIKES", "UPDATE5", "250KLIKES", "UPDATE4", "100KLIKES", "40KCCU", "30KCCU", "20KCCU", "10KCCU", "5KCCU", "1KCCU", "UPDATE3", "UPDATE2", "UPDATE1", "RELEASE", "JPCALLING"}
        
        task.spawn(function()
            local redeemed = {}
            pcall(function()
                local rc = DataController.RedeemedCodes
                if not rc and DataController.___X then rc = DataController.___X.RedeemedCodes end
                if type(rc) == "function" then rc = rc() end
                if type(rc) == "table" and rc.___X then rc = rc.___X end
                if type(rc) == "table" then redeemed = rc end
            end)
            
            local codesToSend = {}
            for _, code in ipairs(codeList) do
                local normCode = string.upper(code:gsub("^%s+", ""):gsub("%s+$", ""))
                local isAlreadyRedeemed = false
                
                pcall(function()
                    isAlreadyRedeemed = redeemed[normCode]
                end)
                
                if not isAlreadyRedeemed and not attemptedCodes[normCode] then 
                    table.insert(codesToSend, normCode) 
                end
            end
            
            local count = 0
            for _, code in ipairs(codesToSend) do
                if Library.Unloaded then break end
                safeFire(NewRemotes.RedeemCode, code)
                attemptedCodes[code] = true
                count += 1
                task.wait(0.55)
            end
            
            if count > 0 then Window:Notify({ Title = "Codes", Content = "Successfully sent " .. count .. " codes!", Duration = 4 })
            else Window:Notify({ Title = "Codes", Content = "All available codes already redeemed.", Duration = 4 }) end
            isRedeemingCodes = false
        end)
    end
})

local Unit_Upgrade_Group = Tabs.Unit:AddLeftGroupbox("Upgrade Units", "arrow-up")
Unit_Upgrade_Group:AddToggle('AutoLevelUp_Toggle', {
    Text = 'Auto Upgrade Placed Units',
    Default = false,

    Callback = function(state)
        config.autoLevelUp = state
    end
})

Unit_Upgrade_Group:AddDropdown('AutoUpgradeRarity_Dropdown', {
    Text = 'Rarities',
    Values = rarityList,
    Default = {},
    Multi = true,
    
    Callback = function(state)
        config.upgradeRarities = state
    end
})

Unit_Upgrade_Group:AddDropdown('AutoUpgradeCharacters_Dropdown', {
    Text = 'Characters (Owned Only)',
    Values = ownedUnitNames,
    Default = {},
    Multi = true,
    
    Callback = function(state)
        config.upgradeChars = state
    end
})

Unit_Upgrade_Group:AddSlider('AutoUpgradeLevelLimit_Slider', {
    Text = 'Level Limit (0 = Max)',
    Default = 0,
    Min = 0,
    Max = 200,
    Increment = 1,
    
    Callback = function(state)
        config.upgradeLevelLimit = state
    end
})

local Unit_Grade_Group = Tabs.Unit:AddLeftGroupbox("Grade", "gem")
Unit_Grade_Group:AddToggle('AutoGrade_Toggle', {
    Text = 'Auto Grade',
    Default = false,

    Callback = function(state)
        config.autoGrade = state
    end
})

Unit_Grade_Group:AddDropdown('AutoGradeUnit_Dropdown', {
    Text = 'Unit',
    Values = unitDropdownValues,
    Default = "None",
    Multi = false,
    
    Callback = function(state)
        config.autoGradeUnit = state
    end
})

Unit_Grade_Group:AddDropdown('AutoGradeTarget_Dropdown', {
    Text = 'Keep Grades',
    Values = { "D", "C", "B", "A", "S", "S+", "Z", "Z+" },
    Default = { "S", "S+", "Z", "Z+" },
    Multi = true,
    
    Callback = function(state)
        config.keepGrades = state
    end
})

local Unit_Trait_Group = Tabs.Unit:AddLeftGroupbox("Traits", "sparkles")
Unit_Trait_Group:AddToggle('AutoTrait_Toggle', {
    Text = 'Auto Trait',
    Default = false,

    Callback = function(state)
        config.autoTrait = state
    end
})

Unit_Trait_Group:AddDropdown('AutoTraitUnit_Dropdown', {
    Text = 'Unit',
    Values = unitDropdownValues,
    Default = "None",
    Multi = false,
    
    Callback = function(state)
        config.autoTraitUnit = state
    end
})

Unit_Trait_Group:AddDropdown('AutoTraitTarget_Dropdown', {
    Text = 'Keep Traits',
    Values = { "Shogun", "Samurai", "Transcendent", "Monarch", "Divine", "Godly" },
    Default = { "Shogun", "Samurai", "Transcendent", "Monarch" },
    Multi = true,
    
    Callback = function(state)
        config.keepTraits = state
    end
})

local Unit_Lock_Group = Tabs.Unit:AddRightGroupbox("Lock", "lock")
Unit_Lock_Group:AddToggle('AutoLock_Toggle', {
    Text = 'Auto Lock',
    Default = false,

    Callback = function(state)
        config.autoLock = state
    end
})

Unit_Lock_Group:AddDropdown('AutoLockRarity_Dropdown', {
    Text = 'Rarities to Lock',
    Values = rarityList,
    Default = {},
    Multi = true,
    
    Callback = function(state)
        config.lockRarities = state
    end
})

local Unit_Sell_Group = Tabs.Unit:AddRightGroupbox("Sell", "trash")
Unit_Sell_Group:AddToggle('AutoSell_Toggle', {
    Text = 'Auto Sell on Full Inventory',
    Default = false,

    Callback = function(state)
        config.autoSell = state
    end
})

Unit_Sell_Group:AddToggle('KeepEquipped_Toggle', {
    Text = 'Keep Equipped Unit',
    Default = true,

    Callback = function(state)
        config.keepEquipped = state
    end
})

Unit_Sell_Group:AddDropdown('KeepRarity_Dropdown', {
    Text = 'Keep Rarity (or higher)',
    Values = rarityList,
    Default = "Mythical",
    Multi = false,
    
    Callback = function(state)
        config.keepRarity = state
    end
})

Unit_Sell_Group:AddDropdown('TargetRarity_Dropdown', {
    Text = 'Mass Sell Target Rarity',
    Values = rarityList,
    Default = "Rare",
    Multi = false,
    
    Callback = function(state)
        config.targetRarity = state
    end
})

Unit_Sell_Group:AddButton({
    Text = 'Force Sell Junk Now',
    Callback = function()
        doAutoSell()
        Window:Notify({ Title = "Byte", Content = "Triggered manual junk sell.", Duration = 3 })
    end
})

Unit_Sell_Group:AddButton({
    Text = 'Sell ALL of Target Rarity',
    Callback = function()
        local inv = getInventoryTable()
        local uuidsToSell = {}
        local equipped = nil
        pcall(function() if DataController and type(DataController.Dice) == "function" then equipped = DataController.Dice() end end)
        for uuid, entry in pairs(inv) do
            if type(entry) == "table" and entry.name then
                local isEquipped = (config.keepEquipped and equipped == entry.name)
                local diceData = Dice.Get(entry.name)
                if diceData and diceData.rarity == config.targetRarity and not isEquipped then table.insert(uuidsToSell, uuid) end
            end
        end
        if #uuidsToSell > 0 then
            pcall(function() NewRemotes.SellInventory:InvokeServer(uuidsToSell) end)
            Window:Notify({ Title = "Byte", Content = "Sold " .. #uuidsToSell .. " " .. config.targetRarity .. " units.", Duration = 3 })
        else Window:Notify({ Title = "Byte", Content = "No " .. config.targetRarity .. " units found.", Duration = 3 }) end
    end
})

local Tower_Main_Group = Tabs.Tower:AddLeftGroupbox("Tower", "castle")
Tower_Main_Group:AddToggle('AutoTower_Toggle', {
    Text = 'Auto Tower',
    Default = false,

    Callback = function(state)
        config.autoTower = state
    end
})

Tower_Main_Group:AddDropdown('AutoTowerMode_Dropdown', {
    Text = 'Mode',
    Values = towerList,
    Default = towerList[1] or "Infinity Tower",
    Multi = false,
    
    Callback = function(state)
        config.autoTowerMode = state
    end
})

Tower_Main_Group:AddToggle('AutoTowerRotate_Toggle', {
    Text = 'Auto Rotate Maps',
    Default = false,

    Callback = function(state)
        config.autoTowerRotate = state
    end
})

Tower_Main_Group:AddDropdown('AutoTowerRotateMaps_Dropdown', {
    Text = 'Rotation Maps',
    Values = towerList,
    Default = {},
    Multi = true,
    
    Callback = function(state)
        config.autoTowerRotateMaps = state
    end
})

Tower_Main_Group:AddSlider('AutoTowerRunsPerMap_Slider', {
    Text = 'Runs Per Map',
    Default = 1,
    Min = 1,
    Max = 20,
    Increment = 1,
    
    Callback = function(state)
        config.autoTowerRunsPerMap = state
    end
})

Tower_Main_Group:AddSlider('AutoTowerStopFloor_Slider', {
    Text = 'Stop At Floor',
    Default = 0,
    Min = 0,
    Max = 1000,
    Increment = 1,
    
    Callback = function(state)
        config.autoTowerStopFloor = state
    end
})

Tower_Main_Group:AddToggle('AutoEquipBestTower_Toggle', {
    Text = 'Auto Equip Best',
    Default = false,

    Callback = function(state)
        config.autoEquipBestTower = state
    end
})

Tower_Main_Group:AddToggle('HideTowerCombatUI_Toggle', {
    Text = 'Hide Tower Combat UI',
    Default = false,

    Callback = function(state)
        config.hideTowerCombatUI = state
    end
})

local Settings_Menu_Group = Tabs.Settings:AddLeftGroupbox("Menu", "menu")
Settings_Menu_Group:AddButton({
    Text = 'Unload',
    Callback = function()
        Library.Unloaded = true
        for _, conn in ipairs(Connections) do pcall(function() conn:Disconnect() end) end
        table.clear(Connections)
        Library:Unload()
    end
})

task.spawn(function()
    while not Library.Unloaded do
        if config.autoRoll then
            local success, result = pcall(Remotes.RollDice.InvokeServer, Remotes.RollDice)
            if success and result and result[1] and result[1].result then
                pcall(function()
                    local cutsceneUI = LocalPlayer.PlayerGui:FindFirstChild("CutsceneBlackFade")
                    if cutsceneUI then cutsceneUI:Destroy() end
                    local rollingUI = LocalPlayer.PlayerGui:FindFirstChild("Rolling")
                    if rollingUI then rollingUI.Visible = false end
                end)
            end
            task.wait(0.1)
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if config.autoCollect then
            for slot = 1, maxSlots do
                pcall(function() Remotes.CollectBalance:FireServer(slot) end)
            end
        end
        
        if config.autoLevelUp then
            local rawData = DataController and DataController.___X
            if rawData and rawData.Inventory and rawData.Slots then
                local currentMoney = tonumber(rawData.Money) or 0
                local upgradedAny = false
                for slot = 1, maxSlots do
                    if not config.autoLevelUp then break end
                    local slotData = rawData.Slots[slot] or rawData.Slots[tostring(slot)]
                    if type(slotData) == "table" and type(slotData.unitId) == "string" then
                        local unitData = rawData.Inventory[slotData.unitId]
                        if type(unitData) == "table" then
                            local charMatch = (next(config.upgradeChars) == nil) or config.upgradeChars[unitData.name]
                            local rarityMatch = (next(config.upgradeRarities) == nil) or config.upgradeRarities[getUnitRarity(unitData)]
                            local levelMatch = (config.upgradeLevelLimit == 0) or ((tonumber(unitData.attributes and unitData.attributes.level) or 1) < config.upgradeLevelLimit)
                            
                            if charMatch and rarityMatch and levelMatch then
                                local cost = tonumber(UnitUtil.GetLevelPrice(unitData.name, unitData.attributes)) or 10
                                if currentMoney >= cost then
                                    safeFire(Remotes.LevelUpSlot, slot)
                                    currentMoney -= cost
                                    upgradedAny = true
                                    task.wait(0.1)
                                end
                            end
                        end
                    end
                end
                if not upgradedAny then task.wait(0.5) end
            else
                task.wait(0.5)
            end
        else
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if config.autoEquipBest then safeFire(Remotes.EquipBest) end
        
        if config.autoEquipBuyDice then
            local currentMoney = 0
            local currentDice = nil
            pcall(function()
                if DataController then
                    if type(DataController.Money) == "function" then currentMoney = DataController.Money() end
                    if type(DataController.Dice) == "function" then currentDice = DataController.Dice() end
                end
            end)

            if currentMoney > 0 and Dice and Dice.GetAll then
                local allDice = Dice.GetAll()
                local bestDiceName, bestDicePrice = nil, -1
                for name, data in pairs(allDice) do
                    if data.price and data.price > 0 and currentMoney >= data.price and data.price > bestDicePrice and currentDice ~= name then
                        bestDiceName, bestDicePrice = name, data.price
                    end
                end
                if bestDiceName then
                    safeFire(Remotes.BuyDice, bestDiceName, false)
                    task.wait(1.5)
                    safeFire(Remotes.EquipDice, bestDiceName)
                end
            end
        end
        
        if config.autoRebirth then
            local currentMoney = 0
            pcall(function() currentMoney = tonumber(DataController.Money()) or 0 end)
            if currentMoney > 0 then 
                safeFire(Remotes.Rebirth) 
                task.wait(5)
            end
        end

        if config.autoUsePotions and next(config.autoPotionTargets) ~= nil then
            local inv = getInventoryTable()
            for uuid, item in pairs(inv) do
                if type(item) == "table" and item.name and config.autoPotionTargets[item.name] then
                    if not isPotionActive(uuid) then
                        safeFire(Remotes.BoostUse, uuid)
                        task.wait(0.2)
                    end
                end
            end
        end
        
        if config.autoBuyUpgrade then
            local currentMoney = 0
            pcall(function() currentMoney = tonumber(DataController.Money()) or 0 end)
            if currentMoney > 0 and Upgrades and TreeStructure then
                local boughtThisTick = {}
                for _ = 1, 50 do
                    local cheapestPrice, bestUpgrade = nil, nil
                    local queue, head = { "Start" }, 1
                    while head <= #queue do
                        local children = TreeStructure.GetChildren(queue[head])
                        head += 1
                        if children then
                            for _, childName in ipairs(children) do
                                if isUpgradeOwned(childName) or boughtThisTick[childName] then
                                    table.insert(queue, childName)
                                else
                                    local upgradeData = Upgrades[childName]
                                    if upgradeData and upgradeData.price and currentMoney >= tonumber(upgradeData.price) then
                                        if not cheapestPrice or tonumber(upgradeData.price) < cheapestPrice then
                                            cheapestPrice, bestUpgrade = tonumber(upgradeData.price), childName
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if bestUpgrade then
                        safeFire(Remotes.BuyUpgrade, bestUpgrade)
                        boughtThisTick[bestUpgrade] = true
                        currentMoney -= cheapestPrice
                        task.wait(0.1)
                    else break end
                end
            end
        end
        
        if config.autoDailyReward then safeFire(NewRemotes.DailyReward) end
        if config.autoOfflineEarnings then safeFire(NewRemotes.OfflineEarnings) end
        if config.autoGroupReward then safeFire(NewRemotes.GroupReward) end
        
        task.wait(1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if config.autoGrade and config.autoGradeUnit ~= "None" then
            local uuid = getUnitUUID(config.autoGradeUnit)
            if uuid and DataController and DataController.___X and DataController.___X.Inventory[uuid] then
                local currentGrade = DataController.___X.Inventory[uuid].attributes and DataController.___X.Inventory[uuid].attributes.grade or "D"
                if not tableContains(config.keepGrades, currentGrade) then
                    safeFire(NewRemotes.GradeRoll, uuid, true)
                    task.wait(1)
                end
            end
        end
        
        if config.autoTrait and config.autoTraitUnit ~= "None" then
            local uuid = getUnitUUID(config.autoTraitUnit)
            if uuid and DataController and DataController.___X and DataController.___X.Inventory[uuid] then
                local currentTrait = DataController.___X.Inventory[uuid].attributes and DataController.___X.Inventory[uuid].attributes.trait or "None"
                if not tableContains(config.keepTraits, currentTrait) then
                    safeFire(NewRemotes.TraitRoll, uuid, true)
                    task.wait(1)
                end
            end
        end
        
        if config.autoLock and next(config.lockRarities) ~= nil then
            local rawData = DataController and DataController.___X
            if rawData and rawData.Inventory then
                local toLock = {}
                for uuid, data in pairs(rawData.Inventory) do
                    if type(data) == "table" and data.name and not (data.attributes and data.attributes.locked == true) then
                        local entryConfig = EntryRegistry and EntryRegistry.getEntryConfig(data.name)
                        local rarity = "Common"
                        if entryConfig then
                            if type(entryConfig.getRarity) == "function" then
                                local success, r = pcall(entryConfig.getRarity, data.attributes or {})
                                if success and type(r) == "string" then rarity = r end
                            else rarity = entryConfig.rarity or "Common" end
                        end
                        if tableContains(config.lockRarities, rarity) then toLock[uuid] = true end
                    end
                end
                if next(toLock) ~= nil then
                    safeFire(NewRemotes.SetLocked, toLock)
                    task.wait(1)
                end
            end
        end
        task.wait(1.5)
    end
end)

task.spawn(function()
    local runsCompleted, savedPositions, isCurrentlyHidden = 0, {}, false
    while not Library.Unloaded do
        if config.hideTowerCombatUI then
            local root = LocalPlayer.PlayerGui:FindFirstChild("Root")
            local tower = root and root:FindFirstChild("Tower")
            if tower then
                local screen, hidden, background = tower:FindFirstChild("Screen"), tower:FindFirstChild("Hidden"), tower:FindFirstChild("Background")
                local isVisible = (screen and screen.Visible) or (hidden and hidden.Visible)
                if isVisible then
                    if not isCurrentlyHidden then
                        savedPositions = {}
                        for _, gui in pairs({screen, hidden, background}) do
                            if gui and gui:IsA("GuiObject") then savedPositions[gui.Name] = gui.Position end
                        end
                        isCurrentlyHidden = true
                    end
                    for _, gui in pairs({screen, hidden, background}) do
                        if gui and gui:IsA("GuiObject") then gui.Position = UDim2.fromScale(4, 4) end
                    end
                elseif isCurrentlyHidden then
                    for _, gui in pairs({screen, hidden, background}) do
                        if gui and gui:IsA("GuiObject") and savedPositions[gui.Name] then gui.Position = savedPositions[gui.Name] end
                    end
                    isCurrentlyHidden = false
                end
            end
        elseif isCurrentlyHidden then
            for _, gui in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if gui:IsA("GuiObject") and savedPositions[gui.Name] then gui.Position = savedPositions[gui.Name] end
            end
            isCurrentlyHidden = false
        end
        
        if config.autoTower and TowerController then
            local currentFloor = getCurrentTowerFloor()
            if config.autoTowerStopFloor > 0 and currentFloor >= config.autoTowerStopFloor then
                safeInvoke(NewRemotes.CancelTower)
                task.wait(3)
                currentFloor = 0
            end
            
            if currentFloor == 0 then
                local mapsToUse = {}
                if config.autoTowerRotate and next(config.autoTowerRotateMaps) ~= nil then
                    for mapName, _ in pairs(config.autoTowerRotateMaps) do table.insert(mapsToUse, mapName) end
                    table.sort(mapsToUse)
                else mapsToUse = towerList end
                
                local currentMap = config.autoTowerMode
                if config.autoTowerRotate and #mapsToUse > 0 then
                    if not config.rotateIndex or config.rotateIndex < 1 or config.rotateIndex > #mapsToUse then config.rotateIndex = 1 end
                    currentMap = mapsToUse[config.rotateIndex]
                end
                
                if currentMap and currentMap ~= "" then
                    local teamValid = false
                    pcall(function() local team = DataController.TowerTeam(); if type(team) == "table" and #team > 0 then teamValid = true end end)
                    if teamValid then
                        if config.autoEquipBestTower then safeFire(NewRemotes.EquipBestTowerTeam); task.wait(0.5) end
                        local success, result = pcall(function() return TowerController.startTower(currentMap) end)
                        if success and result == true then
                            runsCompleted += 1
                            if runsCompleted >= config.autoTowerRunsPerMap then
                                runsCompleted = 0
                                if config.autoTowerRotate then config.rotateIndex += 1 end
                            end
                            task.wait(5)
                        else task.wait(3) end
                    else task.wait(2) end
                end
            end
        end
        task.wait(1)
    end
end)

task.spawn(function()
    while not Library.Unloaded do
        if config.autoQuest and QuestConfig then
            local serverTime = math.floor(workspace:GetServerTimeNow())
            for periodName, periodData in pairs(QuestConfig.Periods) do
                local questData = nil
                pcall(function()
                    if type(DataController.Quests) == "function" then questData = DataController.Quests()[periodName]
                    elseif type(DataController.Quests) == "table" then questData = DataController.Quests[periodName] end
                end)
                if questData and questData.progress and questData.claimed then
                    local expiresAt = tonumber(questData.expiresAt)
                    if not expiresAt or expiresAt == 0 or expiresAt > serverTime then
                        for _, quest in ipairs(periodData.quests) do
                            if type(quest) == "table" and quest.id and not questData.claimed[quest.id] then
                                if (tonumber(questData.progress[quest.id]) or 0) >= (tonumber(quest.target) or math.huge) then
                                    safeFire(NewRemotes.QuestClaim, periodName, quest.id, expiresAt)
                                    task.wait(0.25)
                                end
                            end
                        end
                    end
                end
            end
        end
        task.wait(5)
    end
end)

local TextNotification = Network.NotificationService and Network.NotificationService.RE and Network.NotificationService.RE.TextNotification
if TextNotification then
    Connections[#Connections+1] = TextNotification.OnClientEvent:Connect(function(data)
        if Library.Unloaded or not config.autoSell then return end
        local text = ""
        if type(data) == "string" then text = data
        elseif type(data) == "table" then text = data.message or data.Text or data.Description or "" end
        if string.find(string.lower(tostring(text)), "inventory is full") or string.find(string.lower(tostring(text)), "storage is full") then
            task.delay(0.5, function() if not Library.Unloaded and config.autoSell then doAutoSell() end end)
        end
    end)
end

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("Byte")
SaveManager:SetFolder("Byte/anime-dice")
SaveManager:IgnoreThemeSettings()

ThemeManager:ApplyToTab(Tabs.Settings)
ThemeManager:LoadDefault()

SaveManager:BuildConfigSection(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

Window:Notify({ Title = "Byte", Content = "Loaded successfully.", Duration = 5 })
