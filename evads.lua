local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local ReplicatedStorage= game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local VirtualUser      = game:GetService("VirtualUser")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Window = Library:CreateWindow({
    Title    = "Evade | Viz",
    Layout   = "Bottom bar",
    MenuKey  = Enum.KeyCode.RightShift,
    DPIScale = 1,          
    CanvasGroups = false,   
})

local MainTab    = Window:AddTab("Main",   "house")
local PlayerTab  = Window:AddTab("Player", "user")
local CombatTab  = Window:AddTab("Combat", "sword")
local AutoTab    = Window:AddTab("Auto",   "repeat-2")
local ESPTab     = Window:AddTab("ESP",    "eye")
local VisualTab  = Window:AddTab("Visual", "camera")
local UtilityTab = Window:AddTab("Utility", "wrench")
local Settings   = Window:CreateSettingsTab()

local PlayerModule       = LocalPlayer.PlayerScripts.PlayerModule
local ControlModule      = require(PlayerModule.ControlModule)
local CharacterService   = require(ReplicatedStorage.Services.Asset.CharacterService)
local InteractionTypes   = require(ReplicatedStorage.Services.Asset.InteractionService.InteractionTypes)
local Movement           = require(ReplicatedStorage.Objects.Game.Character.Client.Movement)
local ClientItemService  = require(ReplicatedStorage.Services.Items.ClientItemService)
local Portal             = require(ReplicatedStorage.Objects.Game.Tool.Tasks.Types.Portal)
local DefaultKeybinds    = require(ReplicatedStorage.Services.Client.KeybindService.DefaultKeybinds)
local ServerStateRegistryService = require(ReplicatedStorage.Services.Data.ServerStateRegistryService)
local RagdollModule      = require(ReplicatedStorage.Objects.Game.Character.Rig.Ragdoll)
local DeathFeed          = require(ReplicatedStorage.Services.UI.GameUIService.Types.DeathFeed)
local ColaModule         = require(ReplicatedStorage.Tools.Cola)
local JumpPadModule      = require(ReplicatedStorage.Items.BaseItems.Loadout.Deployables.JumpPad.Modules.Client)
local MaterialService    = game:GetService("MaterialService")
local Events
do
    local RS = ReplicatedStorage
    local descs = RS:GetDescendants()

    local function findRemote(name)
        for _, d in ipairs(descs) do
            if d.Name == name and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent")) then
                return d
            end
        end
        return nil
    end
    local function findFolder(name)
        for _, d in ipairs(descs) do
            if d.Name == name and d:IsA("Folder") then
                return d
            end
        end
        return nil
    end

    local candidate =
        (RS:FindFirstChild("Shared")
            and RS.Shared:FindFirstChild("Core")
            and RS.Shared.Core:FindFirstChild("Events"))
        or RS:FindFirstChild("Events")

    if candidate and candidate:FindFirstChild("Interact") then
        Events = candidate
    else
        local t = {}
        local missing = {}
        for _, name in ipairs({
            "Interact", "ToolAction", "CharacterTask",
            "UpdateCharacterDataRegistry", "SetPlayerMode",
            "Vote", "SharedUISetType",
        }) do
            local r = findRemote(name)
            if r then t[name] = r
            else table.insert(missing, name) end
        end
        local vipRemote = findRemote("VIPCommand")
        if vipRemote then
            t.Admin = { VIPCommand = vipRemote }
        else
            local adminFolder = findFolder("Admin")
            if adminFolder then
                for _, d in ipairs(adminFolder:GetDescendants()) do
                    if d.Name == "VIPCommand" and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent")) then
                        t.Admin = { VIPCommand = d }
                        break
                    end
                end
                t.Admin = t.Admin or adminFolder
            end
        end
        Events = t
    end
end

local Interact       = Events and Events.Interact
local CharacterTask  = Events and Events.CharacterTask
local _setId, _getId
do
    local function findFn(names)
        for _, n in ipairs(names) do
            local ok, env = pcall(getfenv, 0)
            if ok and type(env) == "table" and type(env[n]) == "function" then
                return env[n]
            end
            local gv = getgenv and getgenv() or {}
            if type(gv[n]) == "function" then return gv[n] end
            if type(_G[n]) == "function" then return _G[n] end
        end
        return nil
    end
    _setId = findFn({"setthreadidentity", "set_thread_identity", "setidentity", "set_identity"})
    _getId = findFn({"getthreadidentity", "get_thread_identity", "getidentity", "get_identity"})
end

function FireClient(path, ...)
    if not (getconnections and path) then return end
    local conns = getconnections(path.OnClientEvent)
    if not conns or #conns == 0 then return end
    local prev
    if _setId then
        if _getId then
            local ok, r = pcall(_getId)
            if ok and type(r) == "number" then prev = r end
        end
        pcall(_setId, 2)
    end

    for _, c in ipairs(conns) do
        pcall(c.Function, ...)
    end

    if _setId and prev then
        pcall(_setId, prev)
    end
end

local Character, Humanoid, HumanoidRootPart, CharacterTag
local ModifiedMovementValues = {}
local ReapplyFunctions = {}

local function setupCharacter(character)
    Character        = character
    Humanoid         = character:FindFirstChildOfClass("Humanoid")
    HumanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    CharacterTag     = character:GetAttribute("Tag")
    
    ModifiedMovementValues["Friction"] = 5 
    
    task.spawn(function()
        task.wait(0.1)
        if CharacterTag and CharacterTask then
            FireClient(CharacterTask, CharacterTag, "ModifyMovement", { "Friction", 5 })
        end
    end)
    
    task.spawn(function()
        task.wait(1)
        if CharacterTag and CharacterTask then
            for MovementType, value in pairs(ModifiedMovementValues) do
                if not (MovementType == "Friction" and value < 0) then
                    FireClient(CharacterTask, CharacterTag, "ModifyMovement", { MovementType, value })
                end
            end
        end
        for _, func in ipairs(ReapplyFunctions) do
            pcall(func)
        end
    end)
end

if LocalPlayer.Character then setupCharacter(LocalPlayer.Character) end
LocalPlayer.CharacterAdded:Connect(setupCharacter)

function GetCharacterTag(character)
    if not character then return nil end
    return character:GetAttribute("Tag")
end

function MovementValueSet(MovementType, value)
    ModifiedMovementValues[MovementType] = value
    if not CharacterTag then
        CharacterTag = GetCharacterTag(LocalPlayer.Character)
    end
    if CharacterTag and CharacterTask then
        FireClient(CharacterTask, CharacterTag, "ModifyMovement", { MovementType, value })
    end
end

(function()
    local CollectAvoidGroup = MainTab:AddRightGroupbox("Auto Farm Event", "box")

    CollectAvoidGroup:AddToggle("CollectItemsToggle", {
        Text    = "Collect Event Items",
        Default = false,
        Callback = function(state)
            getgenv()._evadeCollectItems = state
            if not state then return end
            task.spawn(function()
                while getgenv()._evadeCollectItems do
                    task.wait(0.2)
                    pcall(function()
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local effects = Workspace:FindFirstChild("Effects")
                            local tickets = effects and effects:FindFirstChild("Tickets")
                            if tickets then
                                local ticket = tickets:GetChildren()[1]
                                if ticket and ticket:FindFirstChild("HumanoidRootPart") then
                                    hrp.CFrame = CFrame.new(ticket.HumanoidRootPart.Position)
                                end
                            end
                        end
                    end)
                end
            end)
        end,
    })

    CollectAvoidGroup:AddToggle("AvoidBotToggle", {
        Text    = "Avoid Nextbot",
        Default = false,
        Callback = function(state)
            getgenv()._evadeAvoidBot = state
            if not state then return end
            task.spawn(function()
                while getgenv()._evadeAvoidBot do
                    task.wait(0.1)
                    pcall(function()
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local nearestDist = 30
                            local nearestAI   = nil
                            local playersFolder = Workspace:FindFirstChild("Players")
                            if playersFolder then
                                for _, model in ipairs(playersFolder:GetChildren()) do
                                    if model:GetAttribute("AI") == true and model:FindFirstChild("HumanoidRootPart") then
                                        local d = (hrp.Position - model.HumanoidRootPart.Position).Magnitude
                                        if d < nearestDist then
                                            nearestDist = d
                                            nearestAI   = model
                                        end
                                    end
                                end
                            end

                            if nearestAI then
                                local map = Workspace:FindFirstChild("Map")
                                local itemSpawns = map and map:FindFirstChild("ItemSpawns")
                                if itemSpawns then
                                    local list = {}
                                    for _, v in ipairs(itemSpawns:GetChildren()) do
                                        if v.Name == "ItemSpawn" then table.insert(list, v) end
                                    end
                                    if #list > 0 then
                                        local spawn = list[math.random(1, #list)]
                                        hrp.CFrame = spawn.CFrame
                                    end
                                end
                            end
                        end
                    end)
                end
            end)
        end,
    })
end)()

local CarryGroup = MainTab:AddRightGroupbox("Carry", "users")

local function CanBeCarried(value)
    for _, interaction in ipairs(InteractionTypes.Revive.Interactions) do
        if interaction.Name == "Carry" then
            interaction.Requirements.CanBeCarried = value
        end
    end
end

CarryGroup:AddToggle("ForceCarry", {
    Text    = "Force Enable Everyone's Carry",
    Default = false,
    Keybind = "K",
    Callback = function(state)
        if state then CanBeCarried(nil) else CanBeCarried(true) end
    end,
})

local UnlockAllGroup = MainTab:AddLeftGroupbox("Unlock All", "unlock")
UnlockAllGroup:AddToggle("EnableUnlockAll", {
    Text = "Enable Unlock All",
    Default = false,
    Callback = function(state)
        if state then
            do
                local RS = ReplicatedStorage
                local registry = require(RS.Items.Registry)
                local skins = require(RS.Items.Skins)
                local ownedBitset = require(RS.Shared.UserData.Codecs.OwnedBitset)
                local inv = require(RS.Client.Services.UserData.Inventory)
                local slotsModule = require(RS.Client.UI.Menu.Pages.Inventory.Slots)
                local Store = require(RS.Client.Services.UserData.Inventory.Store)
                local CharacterService = require(RS.Services.Asset.CharacterService)
                local DataRegistryModule = require(RS.Objects.Game.Character.DataRegistry)
                local Board = require(RS.Client.UI.Menu.Pages.Inventory.Board)
                local Picker = require(RS.Client.UI.Menu.Pages.Inventory.Picker)
                local Details = require(RS.Client.UI.Menu.Pages.Inventory.Details)

                local function unfreeze(tbl) if setreadonly then pcall(setreadonly, tbl, false) end end
                local function refreeze(tbl) if setreadonly then pcall(setreadonly, tbl, true) end end

                unfreeze(ownedBitset)
                if not ownedBitset.__ORIG_HAS then
                    ownedBitset.__ORIG_HAS = ownedBitset.Has
                    ownedBitset.__ORIG_FOREACH = ownedBitset.ForEach
                end
                local origHas = ownedBitset.__ORIG_HAS
                local origForEach = ownedBitset.__ORIG_FOREACH
                local realBuffer = Store:Get("OwnedBits")

                local ALLOWED_IDS, allowedMap = {}, {}
                local BLOCKED = { Primary = true, Secondary = true, Melee = true, Power = true, Utility = true, Deployable = true, Consumable = true, Tool = true, Perk = true }

                for id, _ in pairs(registry.GetAll()) do
                    local config = registry.GetConfig(id)
                    local slotType = config and config.EquipInfo and config.EquipInfo.SlotType
                    local isSkin = skins.BaseOf(id) ~= nil
                    local allow = false
                    
                    if isSkin then
                        if origHas(realBuffer, skins.BaseOf(id)) then allow = true end
                    elseif not slotType or not BLOCKED[slotType] then
                        allow = true
                    end
                    
                    if allow then
                        table.insert(ALLOWED_IDS, id)
                        allowedMap[id] = true
                    end
                end

                ownedBitset.Has = function(buf, id) 
                    if allowedMap[id] then return true end 
                    return origHas(buf, id) 
                end

                ownedBitset.ForEach = function(buf, cb) 
                    local seen = {}
                    origForEach(buf, function(id)
                        seen[id] = true
                        cb(id)
                    end)
                    for i = 1, #ALLOWED_IDS do
                        local id = ALLOWED_IDS[i]
                        if not seen[id] then
                            seen[id] = true
                            cb(id)
                        end
                    end
                end
                refreeze(ownedBitset)

                getgenv().fakeEquipped = getgenv().fakeEquipped or {}
                getgenv().fakeData = getgenv().fakeData or { Cosmetic = {}, Unusual = {}, Character = {}, CarryAnimation = {}, Tool = {} }
                getgenv().fakeNametag = getgenv().fakeNametag or nil
                getgenv().fakeSkins = getgenv().fakeSkins or {} 
                getgenv().fakeBoombox = getgenv().fakeBoombox or nil

                local UNLOCKALL_PATH = "Byte/Evade/unlockall.txt"
                local function saveUnlockAllState()
                    if not (writefile and isfolder and makefolder) then return end
                    pcall(function()
                        if not isfolder("Byte") then makefolder("Byte") end
                        if not isfolder("Byte/Evade") then makefolder("Byte/Evade") end
                        local lines = {}
                        for slotKey, itemId in pairs(getgenv().fakeEquipped or {}) do
                            if type(slotKey) == "string" and type(itemId) == "number" then
                                table.insert(lines, "E|" .. slotKey .. "|" .. tostring(itemId))
                            end
                        end
                        if getgenv().fakeNametag then
                            table.insert(lines, "N|" .. tostring(getgenv().fakeNametag))
                        end
                        for baseId, skinId in pairs(getgenv().fakeSkins or {}) do
                            if type(baseId) == "number" and type(skinId) == "number" then
                                table.insert(lines, "S|" .. tostring(baseId) .. "|" .. tostring(skinId))
                            end
                        end
                        if getgenv().fakeBoombox then
                            table.insert(lines, "B|" .. tostring(getgenv().fakeBoombox))
                        end
                        writefile(UNLOCKALL_PATH, table.concat(lines, "\n"))
                    end)
                end
                local function rebuildFakeDataFromState()
                    local fakes = getgenv().fakeData
                    if not fakes then return end
                    for k in pairs(fakes) do fakes[k] = {} end
                    for _, itemId in pairs(getgenv().fakeEquipped or {}) do
                        local slotType = (inv.GetItemSlotType and inv.GetItemSlotType(itemId)) or "Cosmetic"
                        fakes[slotType] = fakes[slotType] or {}
                        fakes[slotType][itemId] = true
                    end
                    for _, skinId in pairs(getgenv().fakeSkins or {}) do
                        fakes.Tool = fakes.Tool or {}
                        fakes.Tool[skinId] = true
                    end
                end
                local function loadUnlockAllState()
                    if not (readfile and isfile) then return end
                    local ok, content = pcall(function()
                        if not isfile(UNLOCKALL_PATH) then return nil end
                        return readfile(UNLOCKALL_PATH)
                    end)
                    if not ok or not content or content == "" then return end
                    getgenv().fakeEquipped = {}
                    getgenv().fakeSkins = {}
                    getgenv().fakeNametag = nil
                    getgenv().fakeBoombox = nil
                    for line in content:gmatch("[^\r\n]+") do
                        local kind, a, b = line:match("^(%a)|([^|]*)|?([^|]*)$")
                        if kind == "E" and a and b and b ~= "" then
                            getgenv().fakeEquipped[a] = tonumber(b)
                        elseif kind == "N" and a and a ~= "" then
                            getgenv().fakeNametag = tonumber(a)
                        elseif kind == "S" and a and b and b ~= "" then
                            getgenv().fakeSkins[tonumber(a)] = tonumber(b)
                        elseif kind == "B" and a and a ~= "" then
                            getgenv().fakeBoombox = tonumber(a)
                        end
                    end
                    rebuildFakeDataFromState()
                    
                    local charData = CharacterService:GetCharacterFromPlayer(LocalPlayer)
                    if charData and charData.DataRegistry then
                        pcall(function()
                            DataRegistryModule.ServerToClient(charData.DataRegistry, charData.DataRegistry.Data)
                        end)
                    end
                end

                local currentActiveSlot = nil

                unfreeze(Picker)
                local origPickerOpen = Picker.Open
                Picker.Open = function(self, slotObj, ...)
                    if self and self.Key then currentActiveSlot = self.Key end
                    return origPickerOpen(self, slotObj, ...)
                end
                refreeze(Picker)

                unfreeze(Details)
                local origDetailsOpen = Details.Open
                Details.Open = function(self, slotObj, ...)
                    if self and self.Key then currentActiveSlot = self.Key end
                    return origDetailsOpen(self, slotObj, ...)
                end
                refreeze(Details)

                for id, _ in pairs(registry.GetAll()) do
                    local config = registry.GetConfig(id)
                    if config and config.EquipInfo and config.EquipInfo.SlotType == "Boombox" then
                        getgenv().fakeBoombox = id
                        break
                    end
                end

                local function getExactSlotKey(slotType)
                    if slotType == "Cosmetic" then
                        if not getgenv().fakeEquipped["CosmeticSlot_1"] then return "CosmeticSlot_1" end
                        if not getgenv().fakeEquipped["CosmeticSlot_2"] then return "CosmeticSlot_2" end
                        return "CosmeticSlot_1"
                    elseif slotType == "Unusual" then return "UnusualSlot"
                    elseif slotType == "Character" then return "CharacterSlot"
                    elseif slotType == "Nametag" then return "NametagSlot"
                    elseif slotType == "CarryAnimation" then return "CarryAnimationSlot"
                    elseif slotType == "Boombox" then return "BoomboxSlot"
                    elseif slotType == "Light" then return "LightSlot"
                    elseif slotType == "Utility" then return "UtilitySlot"
                    elseif slotType == "Power" then return "PowerSlot"
                    elseif slotType == "Emote" then
                        for i=1, 12 do
                            local k = "EmoteSlot_" .. i
                            if not getgenv().fakeEquipped[k] then return k end
                        end
                        return "EmoteSlot_1"
                    elseif slotType == "Consumable" then
                        for i=1, 4 do
                            local k = "ConsumableSlot_" .. i
                            if not getgenv().fakeEquipped[k] then return k end
                        end
                        return "ConsumableSlot_1"
                    elseif slotType == "Perk" then
                        if not getgenv().fakeEquipped["PerkSlot_1"] then return "PerkSlot_1" end
                        return "PerkSlot_2"
                    end
                    return slotType .. "Slot"
                end

                local function forceUIRefresh()
                    pcall(function() Board.Refresh() end)
                    pcall(function() Picker.Refresh() end)
                    pcall(function() Details.Refresh() end)
                end

                local pendingRebuild = false
                local function forceVisualRebuild() pendingRebuild = true end

                RunService.Heartbeat:Connect(function()
                    if pendingRebuild then
                        local char = LocalPlayer.Character
                        if char then
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            if hum and hum.FloorMaterial ~= Enum.Material.Air then
                                pendingRebuild = false
                                local charData = CharacterService:GetCharacterFromPlayer(LocalPlayer)
                                if charData and charData.Rig then
                                    charData.Rig.Built = false
                                    pcall(function() charData.DataRegistry:SetTerm("Cosmetics", table.clone(charData.DataRegistry.Data["Cosmetics"])) end)
                                    pcall(function() charData.DataRegistry:SetTerm("ToolSkins", table.clone(charData.DataRegistry.Data["ToolSkins"])) end)
                                    pcall(function() charData.DataRegistry:SetTerm("Nametag", charData.DataRegistry.Data["Nametag"]) end)
                                    pcall(function() charData.DataRegistry:SetTerm("Boombox", charData.DataRegistry.Data["Boombox"]) end)
                                end
                            end
                        end
                    end
                end)

                task.spawn(function()
                    while task.wait(0.5) do
                        local charData = CharacterService:GetCharacterFromPlayer(LocalPlayer)
                        if charData and charData.Rig and charData.Rig.BoomboxAsset then
                            local boombox = charData.Rig.BoomboxAsset
                            if boombox and boombox.Parent then
                                for _, part in ipairs(boombox:GetDescendants()) do
                                    if part:IsA("BasePart") and part.Transparency < 1 then
                                        part.Transparency = 1
                                    elseif (part:IsA("Decal") or part:IsA("Texture")) and part.Transparency < 1 then
                                        part.Transparency = 1
                                    elseif (part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Trail")) and part.Enabled then
                                        part.Enabled = false
                                    elseif part:IsA("Light") and part.Enabled then
                                        part.Enabled = false
                                    end
                                end
                            end
                        end
                    end
                end)

                unfreeze(DataRegistryModule)
                if not DataRegistryModule.__ORIG_S2C then
                    DataRegistryModule.__ORIG_S2C = DataRegistryModule.ServerToClient
                    DataRegistryModule.ServerToClient = function(self, data)
                        if self.Parent and self.Parent.Local == true then
                            local fakes = getgenv().fakeData
                            if data.Cosmetics then
                                local merged = table.clone(data.Cosmetics)
                                for id in pairs(fakes.Cosmetic or {}) do if not table.find(merged, id) then table.insert(merged, id) end end
                                for id in pairs(fakes.Unusual or {}) do if not table.find(merged, id) then table.insert(merged, id) end end
                                for id in pairs(fakes.Character or {}) do if not table.find(merged, id) then table.insert(merged, id) end end
                                for id in pairs(fakes.CarryAnimation or {}) do if not table.find(merged, id) then table.insert(merged, id) end end
                                data.Cosmetics = merged
                            end
                            if data.ToolSkins then
                                local merged = table.clone(data.ToolSkins)
                                for _, skinId in pairs(getgenv().fakeSkins) do if not table.find(merged, skinId) then table.insert(merged, skinId) end end
                                for id in pairs(fakes.Tool or {}) do if not table.find(merged, id) then table.insert(merged, id) end end
                                data.ToolSkins = merged
                            end
                            if getgenv().fakeNametag then data.Nametag = getgenv().fakeNametag end
                            if getgenv().fakeEquipped["BoomboxSlot"] then data.Boombox = getgenv().fakeEquipped["BoomboxSlot"] end
                        end
                        return DataRegistryModule.__ORIG_S2C(self, data)
                    end
                end
                refreeze(DataRegistryModule)

                unfreeze(inv)
                if not inv.__ORIG_EQ then
                    inv.__ORIG_EQ = inv.Equip
                    inv.__ORIG_UNEQ = inv.Unequip
                    inv.__ORIG_GETEQ = inv.GetEquipped
                    inv.__ORIG_ISEQ = inv.IsEquipped
                    inv.__ORIG_PICK = inv.PickSkin
                    inv.__ORIG_GETWORN = inv.GetWornSkin
                    inv.__ORIG_GETSKIN = inv.GetSkin
                    inv.__ORIG_SWAP = inv.Swap
                end

                inv.Equip = function(self, a, b)
                    local itemId = type(a) == "number" and a or (type(b) == "number" and b or nil)
                    local slotKey = type(a) == "string" and a or (type(b) == "string" and b or nil)

                    if itemId and allowedMap[itemId] and not origHas(realBuffer, itemId) then
                        local slotType = inv.GetItemSlotType(itemId) or "Cosmetic"
                        
                        if not slotKey then 
                            slotKey = currentActiveSlot or getExactSlotKey(slotType) 
                        end

                        local oldItem = getgenv().fakeEquipped[slotKey]
                        if oldItem and oldItem ~= itemId then
                            local oldSlotType = inv.GetItemSlotType(oldItem) or "Cosmetic"
                            if getgenv().fakeData[oldSlotType] then
                                getgenv().fakeData[oldSlotType][oldItem] = nil
                            end
                        end

                        getgenv().fakeEquipped[slotKey] = itemId
                        getgenv().fakeData[slotType] = getgenv().fakeData[slotType] or {}
                        getgenv().fakeData[slotType][itemId] = true
                        
                        if slotType == "Nametag" then 
                            getgenv().fakeNametag = itemId
                            if LocalPlayer.Character then
                                LocalPlayer.Character:SetAttribute("Nametag", itemId)
                            end
                        end
                        if slotType == "Unusual" then getgenv().fakeEquipped["BoomboxSlot"] = getgenv().fakeBoombox end

                        forceVisualRebuild()
                        forceUIRefresh()
                        saveUnlockAllState()
                        return true
                    end
                    return inv.__ORIG_EQ(self, a, b)
                end

                inv.Unequip = function(self, a)
                    local slotKey = a
                    if type(a) == "number" then
                        for k, v in pairs(getgenv().fakeEquipped) do
                            if v == a then slotKey = k; break end
                        end
                    end

                    if type(slotKey) == "string" and getgenv().fakeEquipped[slotKey] then
                        local idToRemove = getgenv().fakeEquipped[slotKey]
                        getgenv().fakeEquipped[slotKey] = nil
                        local slotType = inv.GetItemSlotType(idToRemove) or "Cosmetic"
                        if getgenv().fakeData[slotType] then getgenv().fakeData[slotType][idToRemove] = nil end
                        
                        if slotType == "Nametag" then 
                            getgenv().fakeNametag = nil 
                            if LocalPlayer.Character then
                                LocalPlayer.Character:SetAttribute("Nametag", nil)
                            end
                        end
                        if slotType == "Unusual" then getgenv().fakeEquipped["BoomboxSlot"] = nil end
                        
                        forceVisualRebuild()
                        forceUIRefresh()
                        saveUnlockAllState()
                        return true
                    end
                    return inv.__ORIG_UNEQ(self, a)
                end

                inv.Swap = function(self, k1, k2)
                    local item1 = getgenv().fakeEquipped[k1]
                    local item2 = getgenv().fakeEquipped[k2]
                    getgenv().fakeEquipped[k1] = item2
                    getgenv().fakeEquipped[k2] = item1
                    
                    forceVisualRebuild()
                    forceUIRefresh()
                    saveUnlockAllState()
                    return true
                end

                inv.GetEquipped = function(self, key)
                    if key and getgenv().fakeEquipped[key] then return getgenv().fakeEquipped[key] end
                    return inv.__ORIG_GETEQ(self, key)
                end

                inv.IsEquipped = function(self, id)
                    for k, v in pairs(getgenv().fakeEquipped) do if v == id then return true, k end end
                    return inv.__ORIG_ISEQ(self, id)
                end

                inv.PickSkin = function(self, baseId, skinId)
                    if baseId then
                        local targetSkin = skinId
                        if not targetSkin or not allowedMap[targetSkin] then
                            for id, _ in pairs(registry.GetAll()) do
                                if skins.BaseOf(id) == baseId and allowedMap[id] then
                                    targetSkin = id
                                    break
                                end
                            end
                        end
                        if targetSkin then
                            getgenv().fakeSkins[baseId] = targetSkin
                            getgenv().fakeData.Tool[targetSkin] = true
                            
                            forceVisualRebuild()
                            forceUIRefresh()
                            saveUnlockAllState()
                            return true
                        end
                    end
                    return inv.__ORIG_PICK(self, baseId, skinId)
                end

                inv.GetWornSkin = function(self, baseId)
                    if getgenv().fakeSkins[baseId] then return getgenv().fakeSkins[baseId] end
                    return inv.__ORIG_GETWORN(self, baseId)
                end

                inv.GetSkin = function(self, baseId)
                    if getgenv().fakeSkins[baseId] then return getgenv().fakeSkins[baseId] end
                    return inv.__ORIG_GETSKIN(self, baseId)
                end
                refreeze(inv)

                unfreeze(slotsModule)
                if not slotsModule.__ORIG_EQIN then slotsModule.__ORIG_EQIN = slotsModule.EquippedIn end
                slotsModule.EquippedIn = function(slotObj)
                    local key = slotObj and slotObj.Key
                    if key and getgenv().fakeEquipped[key] then return getgenv().fakeEquipped[key] end
                    return slotsModule.__ORIG_EQIN(slotObj)
                end
                refreeze(slotsModule)
                loadUnlockAllState()
                forceVisualRebuild()
                forceUIRefresh()
                task.delay(0.2, function()
                    forceVisualRebuild()
                    forceUIRefresh()
                end)
            end
        end
    end,
})

local BounceGroup = PlayerTab:AddLeftGroupbox("Modify Bounce", "arrow-up-circle")

local BounceSpeed       = 0
local bounceConnection  = nil

BounceGroup:AddToggle("BounceEnabled", {
    Text    = "Modify Multiplier",
    Default = false,
    Keybind = "B",
    Callback = function(state)
        if bounceConnection then bounceConnection:Disconnect(); bounceConnection = nil end
        if state then
            bounceConnection = RunService.RenderStepped:Connect(function()
                local char = LocalPlayer.Character
                if not char then return end
                local hum = char:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then hum.WalkSpeed = BounceSpeed end
            end)
        else
            local char = LocalPlayer.Character
            local hum  = char and char:FindFirstChild("Humanoid")
            if hum then hum.WalkSpeed = 0 end
        end
    end,
})

BounceGroup:AddInput("VelocityMultiplier", {
    Text        = "Multiplier Value",
    Placeholder = "80",
    Numeric     = true,
    Default     = "0",
    Callback = function(value) BounceSpeed = tonumber(value) or 0 end,
})

local SuperGroup = PlayerTab:AddRightGroupbox("Super Bounce", "move-up")

local BounceHeight          = 190
local SuperBounceEnabled    = false
local BounceMultiplier      = 5
local FallSpeedThreshold    = 69
local EdgeTrimpEnabled      = false
local edgeTrimpConnection   = nil
local edgeCharConnection    = nil
local LastFloorMaterial     = Enum.Material.Air
local LastPosition          = Vector3.zero

local function triggerSuperBounce()
    if not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hum and hrp then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
        hrp.Velocity = Vector3.new(hrp.Velocity.X, BounceHeight, hrp.Velocity.Z)
    end
end

SuperGroup:AddInput("BounceHeight", {
    Text = "Bounce Height", Placeholder = "190", Numeric = true, Default = "190",
    Callback = function(v) BounceHeight = tonumber(v) or 50 end,
})

SuperGroup:AddToggle("SuperBounceToggle", {
    Text = "Super Bounce", Default = false, Keybind = "N",
    Callback = function(s) SuperBounceEnabled = s end,
})

SuperGroup:AddKeybind("SuperBounceTrigger", {
    Text    = "Trigger Super Bounce",
    Default = Enum.KeyCode.M,
    Callback = function()
        if SuperBounceEnabled then triggerSuperBounce() end
    end,
})

local function handleEdgeCharAdded(ch)
    Character        = ch
    Humanoid         = ch:WaitForChild("Humanoid")
    HumanoidRootPart = ch:WaitForChild("HumanoidRootPart")
    LastPosition     = HumanoidRootPart.Position
    LastFloorMaterial= Enum.Material.Air
end

SuperGroup:AddToggle("ModifyEdgeTrimp", {
    Text = "Modify Edge Trimp", Default = false, Keybind = "T",
    Callback = function(state)
        EdgeTrimpEnabled = state
        if state then
            if LocalPlayer.Character then handleEdgeCharAdded(LocalPlayer.Character) end
            edgeCharConnection = LocalPlayer.CharacterAdded:Connect(handleEdgeCharAdded)
            edgeTrimpConnection = RunService.Heartbeat:Connect(function(dt)
                if not (Character and Humanoid and HumanoidRootPart) then return end
                local curPos = HumanoidRootPart.Position
                local vel    = (curPos - LastPosition) / math.max(dt, 1e-4)
                LastPosition = curPos

                local curMat  = Humanoid.FloorMaterial
                local falling = Humanoid:GetState() == Enum.HumanoidStateType.Freefall
                             or Humanoid:GetState() == Enum.HumanoidStateType.Jumping

                local edge = (curMat ~= LastFloorMaterial and curMat == Enum.Material.Air and not falling)
                if edge and Humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                    if vel.Y < -FallSpeedThreshold then
                        local bounce = math.abs(vel.Y) * BounceMultiplier
                        HumanoidRootPart.Velocity = Vector3.new(
                            HumanoidRootPart.Velocity.X, bounce, HumanoidRootPart.Velocity.Z)
                    end
                end
                LastFloorMaterial = curMat
            end)
        else
            if edgeTrimpConnection then edgeTrimpConnection:Disconnect(); edgeTrimpConnection = nil end
            if edgeCharConnection  then edgeCharConnection:Disconnect();  edgeCharConnection  = nil end
        end
    end,
})

SuperGroup:AddInput("EdgeHeightMultiplier", {
    Text = "Bounce Height Multiplier", Placeholder = "5", Numeric = true, Default = "5",
    Callback = function(v)
        local n = tonumber(v); if n and n > 0 then BounceMultiplier = n end
    end,
})

SuperGroup:AddInput("EdgeFallThreshold", {
    Text = "Falling Threshold", Placeholder = "69", Numeric = true, Default = "69",
    Callback = function(v)
        local n = tonumber(v); if n and n > 0 then FallSpeedThreshold = n end
    end,
})

local MobileGroup = PlayerTab:AddLeftGroupbox("Mobile Support", "smartphone")

getgenv().lagSwitchEnabled = false
getgenv().lagDuration = 0.5
getgenv().lagMethod = "CPU Cycle"

getgenv().triggerLag = function()
    local duration = getgenv().lagDuration or 0.5
    local method = getgenv().lagMethod or "CPU Cycle"
    
    if method == "CPU Cycle" then
        pcall(function() setfflag("MaxMissedWorldStepsRemembered", "1") end)
        local start = tick()
        while tick() - start < duration do
            local a = math.random(1, 1000000) * math.random(1, 1000000)
            a = a / math.random(1, 10000)
        end
    elseif method == "OS.ClockFFlag" then
        pcall(function() setfflag("MaxMissedWorldStepsRemembered", "10000001000000") end)
        local start = tick()
        while tick() - start < duration do end
    end
end

local lagGui = Instance.new("ScreenGui")
lagGui.Name = "LagSwitchGUI"
lagGui.ResetOnSpawn = false
lagGui.IgnoreGuiInset = true
lagGui.DisplayOrder = 99999 
lagGui.Parent = PlayerGui

local lagBtn = Instance.new("TextButton")
lagBtn.Name = "LagButton"
lagBtn.Size = UDim2.new(0, 80, 0, 40)
lagBtn.Position = UDim2.new(0.8, 0, 0.5, 0)
lagBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
lagBtn.BackgroundTransparency = 0.3
lagBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
lagBtn.Text = "LAG"
lagBtn.Font = Enum.Font.GothamBold
lagBtn.TextSize = 16
lagBtn.Visible = false
lagBtn.Parent = lagGui
Instance.new("UICorner", lagBtn).CornerRadius = UDim.new(0, 8)

local dragging, dragInput, dragStart, startPos
lagBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = lagBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
lagBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        lagBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

lagBtn.MouseButton1Down:Connect(function()
    if getgenv().lagSwitchEnabled then
        task.spawn(getgenv().triggerLag)
    end
end)

MobileGroup:AddKeybind("LagSwitchKey", {
    Text = "Trigger Lag Switch (Keybind)", 
    Default = Enum.KeyCode.L,
    Callback = function() 
        task.spawn(getgenv().triggerLag) 
    end,
})

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.L then
        if getgenv().triggerLag then
            task.spawn(getgenv().triggerLag)
        end
    end
end)

MobileGroup:AddDropdown("LagMethodDropdown", {
    Text = "Lag Method", Values = {"CPU Cycle", "OS.ClockFFlag"}, Default = "CPU Cycle",
    Callback = function(v) getgenv().lagMethod = v end,
})

MobileGroup:AddInput("LagDurationInput", {
    Text = "Lag Duration (seconds)", Default = "0.5", Numeric = true,
    Callback = function(v) local n = tonumber(v); if n and n > 0 then getgenv().lagDuration = n end end,
})

MobileGroup:AddToggle("LagSwitchToggle", {
    Text = "Enable Lag Switch", Default = false,
    Callback = function(state) 
        getgenv().lagSwitchEnabled = state 
        if not state and lagBtn then
            lagBtn.Visible = false 
        end
    end,
})

MobileGroup:AddToggle("LagSwitchBtnToggle", {
    Text = "Show Lag Switch Button", Default = false,
    Callback = function(state) 
        if lagBtn then lagBtn.Visible = state end
    end,
})
local activeMobileButtons = {}

local function createMobileBtn(name, text, pos, toggleObj)
    local gui = Instance.new("ScreenGui")
    gui.Name = "Mobile_" .. name
    gui.ResetOnSpawn = false
    gui.Parent = PlayerGui

    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Size = UDim2.new(0, 60, 0, 60)
    btn.Position = pos
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    btn.BackgroundTransparency = 0.3
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = gui
    
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 255, 0)
    stroke.Thickness = 2
    stroke.Parent = btn

    local dragging, dragInput, dragStart, startPos
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    btn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    btn.MouseButton1Click:Connect(function()
        toggleObj:Set(not toggleObj.Value)
    end)
    
    table.insert(activeMobileButtons, gui)
    return btn
end

MobileGroup:AddToggle("EnableMobileUI", {
    Text = "Enable Mobile Quick Actions",
    Default = false,
    Callback = function(state)
        if not state then
            for _, gui in pairs(activeMobileButtons) do gui:Destroy() end
            activeMobileButtons = {}
            return
        end
        
        createMobileBtn("Fly", "FLY", UDim2.new(0.1, 0, 0.3, 0), Library.Options.FlyToggle)
        createMobileBtn("Slide", "SLIDE", UDim2.new(0.1, 0, 0.4, 0), Library.Options.InfiniteSlideToggle)
        createMobileBtn("Noclip", "NOCLIP", UDim2.new(0.1, 0, 0.5, 0), Library.Options.noclipCFrame)
        createMobileBtn("Bhop", "BHOP", UDim2.new(0.1, 0, 0.6, 0), Library.Options.BhopToggle)
        
        if Library.Options.AutoCarryToggle then
            createMobileBtn("Carry", "CARRY", UDim2.new(0.1, 0, 0.7, 0), Library.Options.AutoCarryToggle)
        end
        
        local lagToggleProxy = {
            Value = false,
            Set = function(self, val)
                self.Value = val
                getgenv().lagSwitchEnabled = val
                if Library.Options.LagSwitchToggle then
                    Library.Options.LagSwitchToggle:Set(val)
                end
                if val and getgenv().triggerLag then
                    task.spawn(getgenv().triggerLag)
                end
            end
        }
        createMobileBtn("Lag", "LAG", UDim2.new(0.1, 0, 0.8, 0), lagToggleProxy)
    end,
})

local FlyGroup = PlayerTab:AddLeftGroupbox("Fly & Slide", "zap")
local fly_speed   = 150
local flying      = false
local freezeY     = nil
local infiniteSlide = false
local slideFriction = -8
local lastFriction  = nil

local emoteSpeedEnabled = false
local emoteSpeedType = "Blatant"
local emoteSpeedValue = 1000
local emoteAccelerationValue = -2
local applyUnwalkableEmoteSpeed = false
local activeMovement = nil

local originalRegistry = Movement.RegistryTermUpdated
Movement.RegistryTermUpdated = function(self, term)
    if term == "Emote" then
        activeMovement = self
        local id = self.DataRegistry:Get("Emote")
        if id and id ~= 0 then
            local item = ClientItemService:GetItemFromID(id)
            local mult = item and (require(item).EmoteInfo or {}).SpeedMult or 1
            if emoteSpeedEnabled and emoteSpeedType == "Blatant" then
                if applyUnwalkableEmoteSpeed and mult <= 0 then
                    mult = 1
                end
                self.MoveStats:SpeedChange("Emote", mult * (emoteSpeedValue / 1000))
            else
                self.MoveStats:SpeedChange("Emote", mult)
            end
        else
            self.MoveStats:SpeedChange("Emote", nil)
        end
        return
    end
    originalRegistry(self, term)
end

local function RefreshEmoteSpeed()
    if activeMovement then
        Movement.RegistryTermUpdated(activeMovement, "Emote")
    end
end

local defaultMovementValues = {
    SprintAcceleration = 1, SprintCap = 2, RunAccel = 1,
    Friction = 5, RunDeaccel = 700,
    AirStrafeAcceleration = 182, AirAcceleration = 1,
    Speed = 1500, JumpHeight = 3, JumpCap = 1,
    WalkSpeedMultiplier = 1, JumpSpeedMultiplier = 1.45,
    GroundedDistCheck = 2.9,
}

local autoJumpEnabled = false
local bhopHoldEnabled = false
local accelerationMethod = "Acceleration"
local accelerationValue = -0.2
local autoAccelerationEnabled = false
local maxAcceleration = 3
local minAcceleration = -1
local maxAutoAccelSpeed = 70
local autoJumpType = "Simulation"
local AutowallHop = false
local lastBhopFriction = nil

local function getCurrentSpeed(character)
    if not character then return 0 end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    for _, child in ipairs(hrp:GetChildren()) do
        if child:IsA("LinearVelocity") and child.Name:find("LinearVelocity") then
            local pv = child.PlaneVelocity
            return (pv.X * pv.X + pv.Y * pv.Y) ^ 0.5
        end
    end
    local vel = hrp.AssemblyLinearVelocity
    return (vel.X * vel.X + vel.Z * vel.Z) ^ 0.5
end

local originalMovementUpdate = Movement.Update
Movement.Update = function(self, ...)
    originalMovementUpdate(self, ...)

    if flying then
        local hrp = self.Character and self.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local mv = ControlModule:GetMoveVector()
            local camCF = Workspace.CurrentCamera.CFrame
            local dir = Vector3.zero
            if mv.Magnitude > 0.01 then
                dir = (camCF.LookVector * -mv.Z + camCF.RightVector * mv.X).Unit * fly_speed
            end
            if dir.Magnitude > 0.1 then freezeY = nil
            elseif not freezeY then freezeY = hrp.Position.Y end

            if self.DataRegistry then self.DataRegistry:Set("Velocity", dir * 90) end
            hrp.AssemblyLinearVelocity = dir
            if freezeY and dir.Magnitude <= 0.1 then
                local p = hrp.Position
                hrp.CFrame = CFrame.new(p.X, freezeY, p.Z) * (hrp.CFrame - hrp.CFrame.Position)
            end
        end
    end

    local char = self.Character
    local hum  = char and char:FindFirstChild("Humanoid")
    if hum then
        local grounded = self.DataRegistry:Get("Grounded")
        local desiredBhopFriction = nil

        if accelerationMethod == "Acceleration" then
            local isBhopActive = autoJumpEnabled or (bhopHoldEnabled and hum.Jump == true)
            if isBhopActive and not grounded then
                local currentSpeed = getCurrentSpeed(self.Character)
                if autoAccelerationEnabled then
                    if currentSpeed > maxAutoAccelSpeed then desiredBhopFriction = maxAcceleration
                    elseif currentSpeed < maxAutoAccelSpeed then desiredBhopFriction = minAcceleration
                    else desiredBhopFriction = accelerationValue end
                else
                    desiredBhopFriction = accelerationValue
                end
            end
        end

        if desiredBhopFriction ~= lastBhopFriction then
            if desiredBhopFriction ~= nil then
                MovementValueSet("Friction", desiredBhopFriction)
            else
                if not infiniteSlide or not (self.State == "Slide" or self.State == "EmotingSlide" or self.State == "CarrySlide") then
                    MovementValueSet("Friction", defaultMovementValues.Friction)
                end
            end
            lastBhopFriction = desiredBhopFriction
        end

        if autoJumpEnabled and grounded then
            if autoJumpType == "Realistic" then self:AttemptJump()
            else hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end

        if bhopHoldEnabled and grounded and hum.Jump == true then
            self:AttemptJump()
        end

        if (self.State == "WallrunRight" or self.State == "WallrunLeft") and AutowallHop then
            self:AttemptJump()
        end
    end

    if hum then
        local data = CharacterService:GetCharacterFromPlayer(LocalPlayer)
        local movementData = data and data.Movement
        local state = movementData and movementData.State or self.State
        local isSlide = (state == "Slide" or state == "EmotingSlide" or state == "CarrySlide")
        local isEmoteSlideAccel = (state == "EmotingSlide")

        local target = nil

        if isSlide and infiniteSlide then
            target = slideFriction
        end

        if isEmoteSlideAccel and emoteSpeedEnabled and emoteSpeedType == "Legit" then
            target = emoteAccelerationValue
        end

        if target ~= lastFriction then
            if target ~= nil then
                MovementValueSet("Friction", target)
            else
                MovementValueSet("Friction", defaultMovementValues.Friction)
            end
            lastFriction = target
        end
    end
end

FlyGroup:AddToggle("FlyToggle", {
    Text = "Fly", Default = false, Keybind = "F",
    Callback = function(s) flying = s; if not s then freezeY = nil end end,
})

FlyGroup:AddInput("FlySpeedInput", {
    Text = "Fly Speed", Placeholder = "150", Numeric = true, Default = "150",
    Callback = function(v)
        local n = tonumber(v); if n and n > 0 then fly_speed = n end
    end,
})

FlyGroup:AddToggle("InfiniteSlideToggle", {
    Text = "Infinite Slide", Default = false, Keybind = "J",
    Callback = function(s) infiniteSlide = s end,
})

FlyGroup:AddInput("SlideFrictionInput", {
    Text = "Slide Friction (Negative)", Placeholder = "-8", Default = "-8",
    Callback = function(v)
        local n = tonumber(v); if n then slideFriction = n end
    end,
})

local noclipConn = nil
local noclipEnabled = false
local wallHelpers, origWallImpact

local function hookWallImpact()
    if origWallImpact then return true end
    local ok, mod = pcall(function()
        return require(ReplicatedStorage.Objects.Game.Character.Client.Movement.MoveFunction.Functions.Helpers)
    end)
    if not ok or type(mod) ~= "table" or type(mod.WallImpact) ~= "function" then return false end
    if setreadonly then pcall(setreadonly, mod, false) end
    wallHelpers, origWallImpact = mod, mod.WallImpact
    mod.WallImpact = function(_, _, _, _, _, _, vel) return vel end
    return true
end

local function unhookWallImpact()
    if wallHelpers and origWallImpact then wallHelpers.WallImpact = origWallImpact end
    wallHelpers, origWallImpact = nil, nil
end

local function setCharCollide(char, state)
    for _, p in pairs(char:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = state end
    end
end

FlyGroup:AddToggle("noclipCFrame", {
    Text = "Noclip", Default = false, Keybind = "X",
    Callback = function(state)
        noclipEnabled = state
        if state then
            if not LocalPlayer.Character then return end
            if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
            local hooked = hookWallImpact()
            noclipConn = RunService.RenderStepped:Connect(function()
                local char = LocalPlayer.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then return end
                setCharCollide(char, false)
                if not hooked then
                    local mv = hum.MoveDirection
                    if mv.Magnitude > 0 then hrp.CFrame = hrp.CFrame + mv * 0.1 end
                end
            end)
        else
            if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
            unhookWallImpact()
            local char = LocalPlayer.Character
            if char then setCharCollide(char, true) end
        end
    end,
})

LocalPlayer.CharacterAdded:Connect(function(ch)
    if noclipEnabled then task.wait(0.5); setCharCollide(ch, false) end
end)
local RampGroup = PlayerTab:AddRightGroupbox("Ramp Booster & Water", "waves")

local rampBoostMultiplier  = 2
local rampBoostConnection  = nil
local waterRenderConnection= nil

RampGroup:AddToggle("RampBoosterToggle", {
    Text = "Ramp Booster", Default = false, Keybind = "R",
    Callback = function(state)
        if rampBoostConnection then rampBoostConnection:Disconnect(); rampBoostConnection = nil end
        if state then
            local armed = true
            rampBoostConnection = RunService.Heartbeat:Connect(function(dt)
                local char = LocalPlayer.Character
                local hum  = char and char:FindFirstChildOfClass("Humanoid")
                local root = hum and (hum.RootPart or char.PrimaryPart)
                if not root then return end
                local vel = root.AssemblyLinearVelocity
                local vy  = vel.Y
                local grav= workspace.Gravity
                local jumpSpeed = hum.UseJumpPower and hum.JumpPower
                                  or math.sqrt(2 * grav * hum.JumpHeight)
                local limit = jumpSpeed + grav * dt
                if not armed and vy <= 0 then armed = true end
                if armed and vy > limit then
                    armed = false
                    root.AssemblyLinearVelocity =
                        Vector3.new(vel.X, vy * rampBoostMultiplier, vel.Z)
                end
            end)
        end
    end,
})

RampGroup:AddInput("RampBoosterMultiplierInput", {
    Text = "Ramp Booster Multiplier", Placeholder = "2", Default = "2",
    Callback = function(v)
        local n = tonumber(v); if n and n > 0 then rampBoostMultiplier = n end
    end,
})

RampGroup:AddToggle("WalkOnWater", {
    Text = "Walk On Water", Default = false, Keybind = "V",
    Callback = function(state)
        local partsFolder = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Parts")
        if not partsFolder then return end
        local waterFolder = partsFolder:FindFirstChild("Water")
        if not waterFolder then return end
        local fakeWater = partsFolder:FindFirstChild("FakeWater")
        if not fakeWater then
            fakeWater = Instance.new("Folder")
            fakeWater.Name = "FakeWater"
            fakeWater.Parent = partsFolder
        end
        if state then
            if waterRenderConnection then waterRenderConnection:Disconnect() end
            waterRenderConnection = RunService.RenderStepped:Connect(function()
                for _, part in ipairs(waterFolder:GetChildren()) do
                    if part:IsA("BasePart") and part.Parent ~= fakeWater then
                        part.CanCollide = true
                        part.Parent = fakeWater
                    end
                end
            end)
        else
            if waterRenderConnection then waterRenderConnection:Disconnect(); waterRenderConnection = nil end
            for _, part in ipairs(fakeWater:GetChildren()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.Parent = waterFolder
                end
            end
        end
    end,
})

local TpGroup = PlayerTab:AddLeftGroupbox("Teleport Walk", "navigation")

local TpwalkValue   = 1
local tpwalkEnabled = false
local tpwalkConn    = nil

local function startTpwalk()
    if tpwalkConn then tpwalkConn:Disconnect(); tpwalkConn = nil end
    tpwalkEnabled = true
    tpwalkConn = RunService.RenderStepped:Connect(function()
        if not tpwalkEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChild("Humanoid")
        if not hrp or not hum then return end
        local mv = hum.MoveDirection
        if mv.Magnitude > 0 then
            hrp.AssemblyLinearVelocity = Vector3.new(
                mv.X * 10 * TpwalkValue, hrp.AssemblyLinearVelocity.Y, mv.Z * 10 * TpwalkValue)
        end
    end)
end

local function stopTpwalk()
    tpwalkEnabled = false
    if tpwalkConn then tpwalkConn:Disconnect(); tpwalkConn = nil end
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0) end
end

TpGroup:AddToggle("TPWALKToggle", {
    Text = "Teleport Walk", Default = false, Keybind = "Y",
    Callback = function(s)
        if s then startTpwalk() else stopTpwalk() end
    end,
})

TpGroup:AddSlider("TPWALKSlider", {
    Text = "Teleport Walk Value", Min = 1, Max = 200, Default = 1,
    Callback = function(v) TpwalkValue = v end,
})

local EmoteGroup = PlayerTab:AddRightGroupbox("Emote Speed", "fast-forward")

EmoteGroup:AddToggle("EmoteSpeedToggle", {
    Text = "Enable Emote Speed", Default = false, Keybind = "E",
    Callback = function(v) emoteSpeedEnabled = v; RefreshEmoteSpeed() end,
})

EmoteGroup:AddDropdown("EmoteSpeedType", {
    Text = "Emote Speed Type", Values = {"Blatant", "Legit"}, Default = "Blatant",
    Callback = function(v) emoteSpeedType = v; RefreshEmoteSpeed() end,
})

EmoteGroup:AddInput("EmoteSpeedInput", {
    Text = "Emote Speed Value", Default = "1000", Numeric = true,
    Callback = function(v) emoteSpeedValue = tonumber(v) or 1000; RefreshEmoteSpeed() end,
})

EmoteGroup:AddToggle("ApplyUnwalkableEmoteSpeed", {
    Text = "Apply Unwalkable Emote Speed", Default = false,
    Callback = function(v) applyUnwalkableEmoteSpeed = v; RefreshEmoteSpeed() end,
})

EmoteGroup:AddInput("EmoteAccelerationInput", {
    Text = "Emote Acceleration (Negative)", Default = "-2",
    Callback = function(v) emoteAccelerationValue = tonumber(v) or -2 end,
})

EmoteGroup:AddButton({
    Text = "Reset Emote Speed",
    Callback = function()
        emoteSpeedValue = 1000
        emoteAccelerationValue = -2
        emoteSpeedType = "Blatant"
        -- Update UI elements visually
        if Library.Options.EmoteSpeedInput then Library.Options.EmoteSpeedInput:SetValue("1000") end
        if Library.Options.EmoteAccelerationInput then Library.Options.EmoteAccelerationInput:SetValue("-2") end
        if Library.Options.EmoteSpeedType then Library.Options.EmoteSpeedType:SetValue("Blatant") end
        RefreshEmoteSpeed()
    end,
})

local ModifyGroup = PlayerTab:AddRightGroupbox("Modification", "sliders-horizontal")

local function addMoveInput(id, label, key)
    ModifyGroup:AddInput(id, {
        Text = label,
        Default = tostring(defaultMovementValues[key] or 0),
        Numeric = true,
        Callback = function(v)
            local n = tonumber(v); if n then MovementValueSet(key, n) end
        end,
    })
end

addMoveInput("SpeedInput",                  "Speed",                   "Speed")
addMoveInput("JumpHeightInput",             "Jump Height",             "JumpHeight")
addMoveInput("JumpCapInput",                "Jump Cap",                "JumpCap")
addMoveInput("JumpSpeedMultiplierInput",    "Jump Speed Multiplier",   "JumpSpeedMultiplier")
addMoveInput("AirStrafeAccelerationInput",  "Air Strafe Acceleration", "AirStrafeAcceleration")
addMoveInput("AirAccelerationInput",        "Air Acceleration",        "AirAcceleration")
addMoveInput("SprintCapInput",              "Sprint Cap",              "SprintCap")
addMoveInput("SprintAccelerationInput",     "Sprint Acceleration",     "SprintAcceleration")
addMoveInput("RunAccelInput",               "Run Acceleration",        "RunAccel")
addMoveInput("RunDeaccelInput",             "Run Deacceleration",      "RunDeaccel")
addMoveInput("FrictionInput",               "Friction",                "Friction")
addMoveInput("WalkSpeedMultiplierInput",    "Walk Speed Multiplier",   "WalkSpeedMultiplier")
addMoveInput("GroundedDistCheckInput",      "Grounded Distance Check", "GroundedDistCheck")

function GetStatus(player)
    local character = player and player.Character
    if not character then return "DEAD" end
    local charData = CharacterService:GetCharacterFromPlayer(player)
    if charData and charData.DataRegistry:Get("Downed") then return "DOWNED" end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then return "ALIVE" end
    return "DEAD"
end

function isPlayerDowned(player)
    return GetStatus(player) == "DOWNED"
end

function isPlayerRagdolled(player)
    if not player or not player.Character then return false end
    local char = player.Character
    if char:FindFirstChild("RagdollConstraints") then return true end
    local charData = CharacterService:GetCharacterFromPlayer(player)
    if charData and charData.DataRegistry and charData.DataRegistry:Get("Ragdolling") then return true end
    if char.PrimaryPart and char.PrimaryPart.Anchored then return true end
    return false
end

function isModelDowned(model)
    if not model then return false end
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health <= 0 then return true end
    if model:GetAttribute("Downed") == true then return true end
    return false
end
do
local CombatGroup = CombatTab:AddLeftGroupbox("Combat Mods", "crosshair")
local DefibGroup  = CombatTab:AddRightGroupbox("Defibrillator Aura", "heart-pulse")

CombatGroup:AddButton({
    Text = "Visual Infinite Ammo",
    Callback = function()
        for _, tool in ipairs(ReplicatedStorage.Tools:GetChildren()) do
            if tool:IsA("ModuleScript") then
                local success, module = pcall(require, tool)
                if success and module and module.Tasks then
                    for _, task in ipairs(module.Tasks) do
                        if task.ResourceInfo and task.ResourceInfo.Type == "Clip" then
                            task.ResourceInfo.Reserve = 9999999999
                            task.ResourceInfo.Cap = 9999999999
                        end
                    end
                end
            end
        end
    end,
})

CombatGroup:AddButton({
    Text = "Visual No Tool Delay",
    Callback = function()
        local function setFastShoot(data)
            if type(data) ~= "table" then return end
            for key, value in pairs(data) do
                if key == "Cooldown" and type(value) == "number" then
                    data[key] = 1 / 65536
                elseif type(value) == "table" then
                    setFastShoot(value)
                end
            end
        end
        for _, tool in pairs(ReplicatedStorage.Tools:GetChildren()) do
            if tool:IsA("ModuleScript") then
                local success, toolData = pcall(require, tool)
                if success and type(toolData) == "table" and toolData.Tasks then
                    for _, task in ipairs(toolData.Tasks) do
                        for _, func in ipairs(task.Functions or {}) do
                            for _, activation in ipairs(func.Activations or {}) do
                                for _, method in ipairs(activation.Methods or {}) do
                                    if method.Info then setFastShoot(method.Info) end
                                end
                            end
                        end
                        for _, autoFunc in ipairs(task.AutomaticFunctions or {}) do
                            for _, method in ipairs(autoFunc.Methods or {}) do
                                if method.Info then setFastShoot(method.Info) end
                            end
                        end
                    end
                end
            end
        end
    end,
})

CombatGroup:AddButton({
    Text = "Disable Weapon Spread",
    Callback = function()
        for _, tool in ipairs(ReplicatedStorage.Tools:GetChildren()) do
            if tool:IsA("ModuleScript") then
                local success, module = pcall(require, tool)
                if success and module and module.Tasks then
                    for _, task in ipairs(module.Tasks) do
                        if task.MethodReferences and task.MethodReferences.Projectile and task.MethodReferences.Projectile.Info and task.MethodReferences.Projectile.Info.SpreadInfo then
                            task.MethodReferences.Projectile.Info.SpreadInfo.MaxSpread = 0
                            task.MethodReferences.Projectile.Info.SpreadInfo.MinSpread = 0
                        end
                    end
                end
            end
        end
    end,
})

CombatGroup:AddButton({
    Text = "Infinite Range",
    Callback = function()
        local function setInfiniteRange(data)
            if type(data) ~= "table" then return end
            for key, value in pairs(data) do
                if (key == "Range" or key == "LungeRange" or key == "HearingRange") and type(value) == "number" then
                    data[key] = math.huge
                elseif key == "DamageDistanceInterval" and type(value) == "table" and #value >= 2 then
                    value[2] = math.huge
                elseif type(value) == "table" then
                    setInfiniteRange(value)
                end
            end
        end
        for _, tool in pairs(ReplicatedStorage.Tools:GetChildren()) do
            if tool:IsA("ModuleScript") then
                local success, toolData = pcall(require, tool)
                if success and type(toolData) == "table" and toolData.Tasks then
                    for _, task in ipairs(toolData.Tasks) do
                        for _, func in ipairs(task.Functions or {}) do
                            for _, activation in ipairs(func.Activations or {}) do
                                for _, method in ipairs(activation.Methods or {}) do
                                    if method.Info then setInfiniteRange(method.Info) end
                                end
                            end
                        end
                        for _, autoFunc in ipairs(task.AutomaticFunctions or {}) do
                            for _, method in ipairs(autoFunc.Methods or {}) do
                                if method.Info then setInfiniteRange(method.Info) end
                            end
                        end
                    end
                end
            end
        end
    end,
})

CombatGroup:AddButton({
    Text = "Portal Bypass",
    Callback = function()
        Portal.IsPortalPossible = function(...) return true end
    end,
})

CombatGroup:AddButton({
    Text = "Bypass 'TooMany' Consumables Limit",
    Callback = function()
        for i = 1, 4 do
            local a = PlayerGui:FindFirstChild("Shared") and PlayerGui.Shared:FindFirstChild("HUD") and PlayerGui.Shared.HUD:FindFirstChild("Interactors")
            if a then a = a:FindFirstChild("Popups") end
            if a then a = a:FindFirstChild("Usables") end
            if a then a = a:FindFirstChild("Wheel") end
            if a then
                local b = a:FindFirstChild("Item" .. i) and a:FindFirstChild("Item" .. i):FindFirstChild("Icon")
                if b and b:FindFirstChild("TooMany") then b.TooMany:Destroy() end
            end
        end
    end,
})

local defibrillator = {
    Equipped = false,
    AuraEnabled = false,
    AuraRange = 20,
    Connection = nil,
    EquipDelay = 0,
    ReviveDelay = 0
}

local function StopReviveAura()
    defibrillator.AuraEnabled = false
    if defibrillator.Connection then defibrillator.Connection:Disconnect(); defibrillator.Connection = nil end
    if defibrillator.Equipped then
        pcall(function()
            Events.UpdateCharacterDataRegistry:FireServer({ buffer.fromstring("\8\0"), buffer.fromstring("\1") })
        end)
        defibrillator.Equipped = false
    end
end

local function StartReviveAura()
    if defibrillator.Connection then StopReviveAura() end
    defibrillator.AuraEnabled = true
    defibrillator.Connection = RunService.Heartbeat:Connect(function()
        if not defibrillator.AuraEnabled then return end
        local found = false
        local localChar = LocalPlayer.Character
        local localPos = localChar and localChar:FindFirstChild("HumanoidRootPart")
        if not localPos then return end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and isPlayerDowned(player) then
                local character = player.Character
                local targetHRP = character and character:FindFirstChild("HumanoidRootPart")
                if targetHRP then
                    local distance = (localPos.Position - targetHRP.Position).Magnitude
                    local range = defibrillator.AuraRange
                    if range == "inf" or (type(range) == "number" and distance <= range) then
                        found = true
                        local tag = character:GetAttribute("Tag")
                        if tag then
                            if not defibrillator.Equipped then
                                if defibrillator.EquipDelay > 0 then task.wait(defibrillator.EquipDelay) end
                                pcall(function()
                                    Events.UpdateCharacterDataRegistry:FireServer({ buffer.fromstring("\008\000"), buffer.fromstring("\003") })
                                end)
                                defibrillator.Equipped = true
                            end
                            if defibrillator.ReviveDelay > 0 then task.wait(defibrillator.ReviveDelay) end
                            pcall(function()
                                Events.ToolAction:FireServer(buffer.fromstring("\001\001\001\001"), tag)
                            end)
                        end
                    end
                end
            end
        end
        if not found and defibrillator.Equipped then
            pcall(function()
                Events.UpdateCharacterDataRegistry:FireServer({ buffer.fromstring("\8\0"), buffer.fromstring("\1") })
            end)
            defibrillator.Equipped = false
        end
    end)
end

DefibGroup:AddToggle("DefibAuraToggle", {
    Text = "Defibrillator Aura", Default = false, Keybind = "Z",
    Callback = function(state)
        if state then StartReviveAura() else StopReviveAura() end
    end,
})

DefibGroup:AddInput("AuraRange", {
    Text = "Aura Range", Placeholder = "20 or inf", Default = "20",
    Callback = function(value)
        if value == "inf" then
            defibrillator.AuraRange = "inf"
        else
            local num = tonumber(value)
            if num then defibrillator.AuraRange = num end
        end
    end,
})

DefibGroup:AddInput("EquipDelay", {
    Text = "Equip Delay (seconds)", Default = "0",
    Callback = function(value) defibrillator.EquipDelay = tonumber(value) or 0 end,
})

DefibGroup:AddInput("ReviveDelay", {
    Text = "Revive Delay (seconds)", Default = "0",
    Callback = function(value) defibrillator.ReviveDelay = tonumber(value) or 0 end,
})
end

do
local AutoJoinGroup   = AutoTab:AddLeftGroupbox("Auto Join", "log-in")
local SpamGroup       = AutoTab:AddRightGroupbox("Keybind Spam", "keyboard")
local BhopGroup       = AutoTab:AddLeftGroupbox("Bhop & Accel", "wind")
local WalkCrouchGroup = AutoTab:AddRightGroupbox("Walk & Crouch", "footprints")
local CarryVoteGroup  = AutoTab:AddLeftGroupbox("Carry & Vote", "users")
local ReviveGroup     = AutoTab:AddRightGroupbox("Revive & Whistle", "heart")

function SendKeybindEvent(key, bool)
    pcall(function()
        ReplicatedStorage.Services.Client.KeybindService.SendKeybindEvent:Fire({ Key = key, Down = bool })
    end)
end

local changePlayerMode = Events and Events.SetPlayerMode
local isRejoiningRespawn = false
local autoJoinEnabled = false
local joinConn = nil
local respawnConn = nil
local lastFireTime = 0

local function isMenuActuallyVisible()
    local menu = PlayerGui:FindFirstChild("Menu")
    if not menu then return false end
    if menu:IsA("ScreenGui") or menu:IsA("LayerCollector") then
        return menu.Enabled == true
    end
    if menu:IsA("GuiObject") then
        return menu.Visible == true
    end
    for _, child in ipairs(menu:GetDescendants()) do
        if child:IsA("GuiObject") and child.Visible then
            return true
        end
    end
    return false
end

local function checkAndFire()
    if not autoJoinEnabled then return end

    local isDead = false

    local deathGui = PlayerGui:FindFirstChild("Shared")
    if deathGui then
        local respawn = deathGui:FindFirstChild("Respawn")
        if respawn then
            local types = respawn:FindFirstChild("Types")
            if types then
                local death = types:FindFirstChild("Death")
                if death and death.Visible then isDead = true end
            end
        end
    end

    if not isDead and isMenuActuallyVisible() then
        isDead = true
    end

    if isDead then
        if not isRejoiningRespawn then isRejoiningRespawn = true end
        local currentTime = tick()
        if currentTime - lastFireTime >= 10 then
            if changePlayerMode then
                pcall(function() changePlayerMode:FireServer(true) end)
            end
            lastFireTime = currentTime
        end
    else
        isRejoiningRespawn = false
    end
end

AutoJoinGroup:AddToggle("AutoJoinToggle", {
    Text = "Auto Join", Default = false,
    Callback = function(state)
        autoJoinEnabled = state
        if state then
            if not joinConn then joinConn = RunService.RenderStepped:Connect(checkAndFire) end
            if not respawnConn then
                respawnConn = LocalPlayer.CharacterAdded:Connect(function()
                    isRejoiningRespawn = false
                    lastFireTime = 0
                end)
            end
        else
            if joinConn then joinConn:Disconnect(); joinConn = nil end
            if respawnConn then respawnConn:Disconnect(); respawnConn = nil end
            isRejoiningRespawn = false
            lastFireTime = 0
        end
    end,
})

local SpamKeybind = { Enabled = false, Connection = nil, Delay = 0.6, LastTick = os.clock(), KeybindTarget = "None" }
local KeybindType = { HasSeen = {}, KeyList = {} }

for bindName, data in pairs(DefaultKeybinds) do
    if type(data) == "table" and data.Type then
        local t = tostring(data.Type)
        if not KeybindType.HasSeen[t] then
            KeybindType.HasSeen[t] = true
            table.insert(KeybindType.KeyList, t)
        end
    end
end

SpamGroup:AddToggle("SpamKeybindToggle", {
    Text = "Enable Spam Keybind", Default = false,
    Callback = function(state)
        SpamKeybind.Enabled = state
        if state then
            local isDown = false
            SpamKeybind.Connection = RunService.RenderStepped:Connect(function()
                if os.clock() - SpamKeybind.LastTick >= SpamKeybind.Delay and SpamKeybind.Enabled then
                    SpamKeybind.LastTick = os.clock()
                    SendKeybindEvent(SpamKeybind.KeybindTarget, isDown)
                    isDown = not isDown
                end
            end)
        else
            if SpamKeybind.Connection then SpamKeybind.Connection:Disconnect(); SpamKeybind.Connection = nil end
        end
    end,
})

SpamGroup:AddInput("SpamDelay", {
    Text = "Keybind Delay", Default = "0.6", Numeric = true,
    Callback = function(v) SpamKeybind.Delay = tonumber(v) or 0.6 end,
})

SpamGroup:AddDropdown("SpamKeyType", {
    Text = "Keybind Type", Values = KeybindType.KeyList, Default = "None",
    Callback = function(v) SpamKeybind.KeybindTarget = v end,
})

local function updateBhopEnabled()
    local shouldEnable = (autoJumpEnabled or bhopHoldEnabled) and accelerationMethod == "Acceleration"
    MovementValueSet("BhopEnabled", shouldEnable)
end

BhopGroup:AddToggle("BhopToggle", {
    Text = "Bhop", Default = false, Keybind = "B",
    Callback = function(s) autoJumpEnabled = s; updateBhopEnabled() end,
})

BhopGroup:AddToggle("BhopHoldToggle", {
    Text = "Bhop Hold Jump", Default = false,
    Callback = function(s) bhopHoldEnabled = s; updateBhopEnabled() end,
})

BhopGroup:AddDropdown("BhopMode", {
    Text = "Bhop Mode", Values = {"No Acceleration", "Acceleration"}, Default = "Acceleration",
    Callback = function(v)
        accelerationMethod = v
        updateBhopEnabled()
        if not (autoJumpEnabled or bhopHoldEnabled) then
            MovementValueSet("Friction", defaultMovementValues.Friction)
            lastBhopFriction = nil
        end
    end,
})

BhopGroup:AddInput("BhopAccelInput", {
    Text = "Bhop Acceleration", Default = "-0.2", Numeric = true,
    Callback = function(v) local n = tonumber(v); if n then accelerationValue = n end end,
})

BhopGroup:AddDropdown("AutoJumpType", {
    Text = "Auto Jump Mode", Values = {"Simulation", "Realistic"}, Default = "Simulation",
    Callback = function(v) autoJumpType = v end,
})

BhopGroup:AddToggle("AutoWallHop", {
    Text = "Auto Wall Hop", Default = false,
    Callback = function(s) AutowallHop = s end,
})

BhopGroup:AddToggle("AutoAccelerationToggle", {
    Text = "Auto Acceleration (Legit)", Default = false,
    Callback = function(s) autoAccelerationEnabled = s end,
})

BhopGroup:AddInput("MaxAccelInput", { Text = "Max Acceleration", Default = "3", Numeric = true, Callback = function(v) local n = tonumber(v); if n then maxAcceleration = n end end })
BhopGroup:AddInput("MinAccelInput", { Text = "Min Acceleration", Default = "-1", Numeric = true, Callback = function(v) local n = tonumber(v); if n then minAcceleration = n end end })
BhopGroup:AddInput("MaxSpeedInput", { Text = "Max Speed", Default = "70", Numeric = true, Callback = function(v) local n = tonumber(v); if n and n > 0 then maxAutoAccelSpeed = n end end })

local MOVE_DIRECTION = Vector3.new(0, 0, 1)
local oldGetMoveVector = nil
local jumpConnection = nil
local lastVelocity = Vector3.new()

WalkCrouchGroup:AddToggle("AutoWalkToggle", {
    Text = "Auto Walk", Default = false,
    Callback = function(state)
        if state then
            if ControlModule then
                oldGetMoveVector = ControlModule.GetMoveVector
                ControlModule.GetMoveVector = function(...)
                    local input = oldGetMoveVector(...)
                    return input.Magnitude > 0.1 and input or MOVE_DIRECTION
                end
            end
            if not jumpConnection then
                jumpConnection = RunService.Heartbeat:Connect(function()
                    local char = LocalPlayer.Character
                    if not char then return end
                    local humanoid = char:FindFirstChild("Humanoid")
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    if not humanoid or not rootPart then return end
                    local pState = humanoid:GetState()
                    if pState == Enum.HumanoidStateType.Jumping then
                        if lastVelocity.Magnitude > 0 then
                            local currentVel = rootPart.AssemblyLinearVelocity
                            if currentVel.Magnitude < lastVelocity.Magnitude then
                                rootPart.AssemblyLinearVelocity = Vector3.new(lastVelocity.X, currentVel.Y, lastVelocity.Z)
                            end
                        end
                        lastVelocity = rootPart.AssemblyLinearVelocity
                    elseif pState == Enum.HumanoidStateType.Landed then
                        lastVelocity = Vector3.new()
                    end
                end)
            end
        else
            if ControlModule and oldGetMoveVector then
                ControlModule.GetMoveVector = oldGetMoveVector
                oldGetMoveVector = nil
            end
            if jumpConnection then jumpConnection:Disconnect(); jumpConnection = nil end
        end
    end,
})

WalkCrouchGroup:AddInput("AutoWalkDir", {
    Text = "Move Direction", Default = "0 0 1",
    Callback = function(value)
        local x, y, z = value:match("([%d.-]+)%s+([%d.-]+)%s+([%d.-]+)")
        if x and y and z then MOVE_DIRECTION = Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
    end,
})

local CrouchDelay = 0
local arg_v784 = 0
local arg_v785 = false
local AutoCrouch = false
local AutoCrouchMode = "Air"
local crouchConnection = nil

WalkCrouchGroup:AddToggle("AutoCrouchToggle", {
    Text = "Auto Crouch", Default = false, Keybind = "C",
    Callback = function(state)
        AutoCrouch = state
        if state then
            if crouchConnection then return end
            crouchConnection = RunService.RenderStepped:Connect(function()
                if not AutoCrouch then SendKeybindEvent("Crouching", false); return end
                local char = LocalPlayer.Character
                if not char or not char:FindFirstChild("Humanoid") then return end
                local hum = char.Humanoid
                local isAir = (hum.FloorMaterial == Enum.Material.Air) and (hum:GetState() ~= Enum.HumanoidStateType.Seated)
                
                if AutoCrouchMode == "Spam" then
                    if tick() - arg_v784 >= CrouchDelay then
                        arg_v785 = not arg_v785
                        SendKeybindEvent("Crouching", arg_v785)
                        arg_v784 = tick()
                    end
                elseif AutoCrouchMode == "Normal" then SendKeybindEvent("Crouching", true)
                elseif AutoCrouchMode == "Air" and isAir then SendKeybindEvent("Crouching", true)
                elseif AutoCrouchMode == "Ground" and not isAir then SendKeybindEvent("Crouching", true)
                else SendKeybindEvent("Crouching", false) end
            end)
        else
            if crouchConnection then crouchConnection:Disconnect(); crouchConnection = nil end
            arg_v784 = 0; arg_v785 = false
            SendKeybindEvent("Crouching", false)
        end
    end,
})

WalkCrouchGroup:AddDropdown("CrouchMode", {
    Text = "Auto Crouch Mode", Values = {"Air", "Spam", "Ground", "Normal"}, Default = "Air",
    Callback = function(v)
        AutoCrouchMode = v
        arg_v784 = 0; arg_v785 = false
        if v ~= "Spam" then SendKeybindEvent("Crouching", false) end
    end,
})

WalkCrouchGroup:AddInput("CrouchDelay", {
    Text = "Spam Delay (seconds)", Default = "0", Numeric = true,
    Callback = function(v) CrouchDelay = tonumber(v) or 0 end,
})

local AutoCarry = false
local AutoCarryConnection = nil
local lastCarryAttempt = 0
local carryCooldown = 0.5
local autoCarryRange = 10
local dropCooldownTime = 2.5         
local walkAwayDist     = 15          

local dropCooldownEnd = {}           
local currentlyHeldTag = nil       

local carryStates = { "Carry", "CarrySlide", "CarrySlideAir", "CarryAir", "Carried", "CarryMove", "CarryIdle" }

local function findPlayerByTag(tag)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and p.Character:GetAttribute("Tag") == tag then
            return p
        end
    end
    return nil
end

CarryVoteGroup:AddToggle("AutoCarryToggle", {
    Text = "Auto Carry", Default = false, Keybind = "X",
    Callback = function(state)
        AutoCarry = state
        if AutoCarryConnection then
            AutoCarryConnection:Disconnect()
            AutoCarryConnection = nil
        end
        if not state then
            dropCooldownEnd = {}
            currentlyHeldTag = nil
            return
        end
        AutoCarryConnection = RunService.Heartbeat:Connect(function()
            if not AutoCarry then return end
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local charData = CharacterService:GetCharacterFromPlayer(LocalPlayer)
            if not charData or not charData.Movement then return end

            local pState = charData.Movement.State
            local isCarrying = table.find(carryStates, pState) ~= nil

            if currentlyHeldTag and not isCarrying then
                dropCooldownEnd[currentlyHeldTag] = tick() + dropCooldownTime
                currentlyHeldTag = nil
            end

            for tag, untilT in pairs(dropCooldownEnd) do
                if tick() >= untilT then
                    dropCooldownEnd[tag] = nil
                else
                    local p = findPlayerByTag(tag)
                    if not p or not p.Character then
                        dropCooldownEnd[tag] = nil   
                    else
                        local otherHRP = p.Character:FindFirstChild("HumanoidRootPart")
                        if otherHRP and (hrp.Position - otherHRP.Position).Magnitude > walkAwayDist then
                            dropCooldownEnd[tag] = nil 
                        end
                    end
                end
            end

            if isCarrying then
                local nearestTag = nil
                local nearestDist = 15
                for _, other in ipairs(Players:GetPlayers()) do
                    if other == LocalPlayer then continue end
                    local otherChar = other.Character
                    if otherChar and isPlayerDowned(other) then
                        local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
                        if otherHRP then
                            local d = (hrp.Position - otherHRP.Position).Magnitude
                            if d < nearestDist then
                                nearestDist = d
                                nearestTag = otherChar:GetAttribute("Tag")
                            end
                        end
                    end
                end
                if nearestTag then
                    currentlyHeldTag = nearestTag
                    dropCooldownEnd[nearestTag] = nil 
                end
                return
            end

            if tick() - lastCarryAttempt < carryCooldown then return end

            local bestTag = nil
            local bestDist = math.huge
            for _, other in ipairs(Players:GetPlayers()) do
                if other == LocalPlayer then continue end
                local otherChar = other.Character
                if not otherChar then continue end
                if not isPlayerDowned(other) then continue end
                if isPlayerRagdolled(other) then continue end

                local otherHRP = otherChar:FindFirstChild("HumanoidRootPart")
                if not otherHRP then continue end

                local tag = otherChar:GetAttribute("Tag")
                if not tag then continue end

                local untilT = dropCooldownEnd[tag]
                if untilT and tick() < untilT then continue end

                local dist = (hrp.Position - otherHRP.Position).Magnitude
                if dist > autoCarryRange then continue end

                if dist < bestDist then
                    bestDist = dist
                    bestTag = tag
                end
            end

            if bestTag then
                pcall(function() Interact:FireServer("Carry", bestTag) end)
                lastCarryAttempt = tick()
            end
        end)
    end,
})

CarryVoteGroup:AddInput("AutoCarryDropCD", {
    Text = "Auto Carry Drop Cooldown (s)",
    Default = tostring(dropCooldownTime),
    Numeric = true,
    Callback = function(v)
        local n = tonumber(v)
        if n and n >= 0 then dropCooldownTime = n end
    end,
})

CarryVoteGroup:AddInput("AutoCarryWalkAway", {
    Text = "Auto Carry Walk-Away Reset (studs)",
    Default = tostring(walkAwayDist),
    Numeric = true,
    Callback = function(v)
        local n = tonumber(v)
        if n and n > 0 then walkAwayDist = n end
    end,
})

CarryVoteGroup:AddInput("AutoCarryRange", {
    Text = "Auto Carry Grab Range (studs)",
    Default = tostring(autoCarryRange),
    Numeric = true,
    Callback = function(v)
        local n = tonumber(v)
        if n and n > 0 then autoCarryRange = n end
    end,
})

CarryVoteGroup:AddKeybind("AutoCarryClearCD", {
    Text = "Force Reset All Drop Cooldowns",
    Default = Enum.KeyCode.Unknown,
    Callback = function()
        dropCooldownEnd = {}
    end,
})

local AutoVote = { Enabled = false, Map = 1, Mode = 1, Connections = { Map = nil, Mode = nil } }
local function getVotePopup()
    if not Events or not Events.Vote then return nil end
    local shared = PlayerGui:FindFirstChild("Shared")
    local popups = shared and shared:FindFirstChild("Popups")
    if popups then
        local voteActive = popups:FindFirstChild("VoteActive")
        if voteActive and voteActive.Visible then return voteActive end
        local vote = popups:FindFirstChild("Vote")
        if vote and vote.Visible then return vote end
    end
    return nil
end

CarryVoteGroup:AddToggle("AutoVoteMapToggle", {
    Text = "Auto Vote Map", Default = false,
    Callback = function(state)
        if state then
            if AutoVote.Connections.Map then AutoVote.Connections.Map:Disconnect() end
            AutoVote.Connections.Map = RunService.Heartbeat:Connect(function()
                if getVotePopup() and Events.Vote then Events.Vote:FireServer(AutoVote.Map) end
            end)
        else
            if AutoVote.Connections.Map then AutoVote.Connections.Map:Disconnect(); AutoVote.Connections.Map = nil end
        end
    end,
})

CarryVoteGroup:AddDropdown("AutoVoteMapSelect", {
    Text = "Vote Map", Values = { "Map 1", "Map 2", "Map 3", "Map 4" }, Default = "Map 1",
    Callback = function(v) AutoVote.Map = tonumber(v:match("%d+")) end,
})

CarryVoteGroup:AddToggle("AutoVoteModeToggle", {
    Text = "Auto Vote Game Mode", Default = false,
    Callback = function(state)
        if state then
            if AutoVote.Connections.Mode then AutoVote.Connections.Mode:Disconnect() end
            AutoVote.Connections.Mode = RunService.Heartbeat:Connect(function()
                if getVotePopup() and Events.Vote then Events.Vote:FireServer(AutoVote.Mode, true) end
            end)
        else
            if AutoVote.Connections.Mode then AutoVote.Connections.Mode:Disconnect(); AutoVote.Connections.Mode = nil end
        end
    end,
})

CarryVoteGroup:AddDropdown("AutoVoteModeSelect", {
    Text = "Vote Mode", Values = { "Mode 1", "Mode 2", "Mode 3", "Mode 4" }, Default = "Mode 1",
    Callback = function(v) AutoVote.Mode = tonumber(v:match("%d+")) end,
})

local SelfRevive = { Method = "Spawnpoint", Enabled = false, HasRevived = false, LastSavedPosition = nil, IsProcessing = false, LastRespawnTime = 0, Connections = { Heartbeat = nil, Character = nil } }

local function SelfReviveRespawn()
    if tick() - SelfRevive.LastRespawnTime < 0.5 or SelfRevive.IsProcessing then return end
    SelfRevive.LastRespawnTime = tick()
    local char = LocalPlayer.Character
    if not char then return end
    local charData = CharacterService:GetCharacterFromPlayer(LocalPlayer)
    if not (charData and charData.DataRegistry:Get("Downed")) then return end
    
    SelfRevive.IsProcessing = true
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if SelfRevive.Method == "Spawnpoint" then
        if not SelfRevive.HasRevived then
            SelfRevive.HasRevived = true
            if changePlayerMode then pcall(function() changePlayerMode:FireServer(true) end) end
            SelfRevive.IsProcessing = false
            task.delay(10, function() SelfRevive.HasRevived = false end)
        else
            SelfRevive.IsProcessing = false
        end
    elseif SelfRevive.Method == "Fake Revive" then
        local savedPos = hrp and hrp.CFrame.Position
        task.spawn(function()
            if changePlayerMode then pcall(function() changePlayerMode:FireServer(true) end) end
            local newChar
            repeat newChar = LocalPlayer.Character; task.wait() until newChar and newChar:FindFirstChild("HumanoidRootPart") and newChar ~= char
            if newChar then
                local newHRP = newChar:FindFirstChild("HumanoidRootPart")
                if savedPos and newHRP then task.wait(0.1); newHRP.CFrame = CFrame.new(savedPos) end
            end
            SelfRevive.IsProcessing = false
        end)
    else
        SelfRevive.IsProcessing = false
    end
end

ReviveGroup:AddToggle("SelfReviveToggle", {
    Text = "Auto Self Revive", Default = false,
    Callback = function(state)
        SelfRevive.Enabled = state
        if state then
            if not SelfRevive.Connections.Heartbeat then
                SelfRevive.Connections.Heartbeat = RunService.Heartbeat:Connect(function()
                    if not SelfRevive.Enabled then return end
                    local charData = CharacterService:GetCharacterFromPlayer(LocalPlayer)
                    if charData and charData.DataRegistry:Get("Downed") then SelfReviveRespawn() end
                end)
            end
            if not SelfRevive.Connections.Character then
                SelfRevive.Connections.Character = LocalPlayer.CharacterAdded:Connect(function()
                    SelfRevive.HasRevived = false
                    SelfRevive.IsProcessing = false
                    SelfRevive.LastSavedPosition = nil
                end)
            end
        else
            if SelfRevive.Connections.Heartbeat then SelfRevive.Connections.Heartbeat:Disconnect(); SelfRevive.Connections.Heartbeat = nil end
            if SelfRevive.Connections.Character then SelfRevive.Connections.Character:Disconnect(); SelfRevive.Connections.Character = nil end
            SelfRevive.HasRevived = false
            SelfRevive.IsProcessing = false
        end
    end,
})

ReviveGroup:AddDropdown("SelfReviveMethod", {
    Text = "Self Revive Method", Values = { "Spawnpoint", "Fake Revive" }, Default = "Spawnpoint",
    Callback = function(v) SelfRevive.Method = v end,
})

ReviveGroup:AddButton({
    Text = "Manual Revive",
    Callback = function() SelfReviveRespawn() end,
})

ReviveGroup:AddButton({
    Text = "Force Respawn",
    Callback = function()
        if changePlayerMode then changePlayerMode:FireServer(true) end
    end,
})

local AutoWhistle = false
local autoWhistleConnection = nil
local lastWhistle = 0

ReviveGroup:AddToggle("AutoWhistleToggle", {
    Text = "Auto Whistle", Default = false,
    Callback = function(state)
        AutoWhistle = state
        if state then
            if not autoWhistleConnection then
                lastWhistle = tick()
                autoWhistleConnection = RunService.Heartbeat:Connect(function()
                    if not AutoWhistle then return end
                    if tick() - lastWhistle >= 1 then
                        lastWhistle = tick()
                        pcall(function()
                            ReplicatedStorage.Services.Client.KeybindService.SendKeybindEvent:Fire({ Down = true, Key = "Whistle" })
                        end)
                    end
                end)
            end
        else
            AutoWhistle = false
            if autoWhistleConnection then autoWhistleConnection:Disconnect(); autoWhistleConnection = nil end
        end
    end,
})
end

local function isNPCModel(model)
    if not model or not model:IsA("Model") then return false end
    if model:GetAttribute("AI") == true then return true end
    if model:FindFirstChild("HumanoidRootPart") and model:FindFirstChild("Humanoid") then
        local parent = model.Parent
        if parent and parent.Name == "Players" and model:GetAttribute("AI") == true then return true end
    end
    return false
end
do
local ESPManager = {
    Enabled = false,
    AliveElements = {}, DownedElements = {}, NPCElements = {},
    Settings = { Boxes = false, BoxType = "2D", Names = false },
    DownedSettings = { Boxes = false, BoxType = "2D", Names = false },
    NPCSettings = { Boxes = false, BoxType = "2D", Names = false },
    Connections = { Render = nil, RenderCheck = nil, RigAdded = nil, RigRemoved = nil, PlayerAdded = nil, PlayerRemoving = nil },
    Rendering = true, WindowFocused = true, LastRenderTime = tick(),
    HighlightCache = {}, RigOwner = {}, PlayerRigs = {}, RigCache = {}, LastRigUpdate = 0
}

local tracerGui = nil
local tracerEntries = {}
local playerTracersEnabled, downedTracersEnabled, botTracersEnabled = false, false, false

local function getTracerGui()
    if tracerGui and tracerGui.Parent then return tracerGui end
    local parentGui = PlayerGui
    if not parentGui then return nil end
    local gui = Instance.new("ScreenGui")
    gui.Name = "Tracer GUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = -2147483648
    gui.Parent = parentGui
    tracerGui = gui
    return gui
end

local function cleanupTracerESP()
    for _, data in pairs(tracerEntries) do
        if data.pivot then data.pivot:Destroy() end
    end
    tracerEntries = {}
    if tracerGui then tracerGui:Destroy(); tracerGui = nil end
end

local function ensureTracer(key, color)
    local data = tracerEntries[key]
    if data and data.pivot and data.pivot.Parent then
        if data.line then data.line.BackgroundColor3 = color end
        return data
    end
    local gui = getTracerGui()
    if not gui then return nil end
    local pivot = Instance.new("Frame")
    pivot.Name = "Tracer_" .. tostring(key)
    pivot.AnchorPoint = Vector2.new(0.5, 0.5)
    pivot.Position = UDim2.fromScale(0.5, 1)
    pivot.Size = UDim2.fromOffset(1, 1)
    pivot.BackgroundTransparency = 1
    pivot.Visible = false
    pivot.ZIndex = -2147483648
    pivot.Parent = gui
    
    local line = Instance.new("Frame")
    line.Name = "Line"
    line.AnchorPoint = Vector2.new(0.5, 1)
    line.Position = UDim2.fromScale(0.5, 0.5)
    line.Size = UDim2.fromOffset(2, 0)
    line.BackgroundColor3 = color
    line.BorderSizePixel = 0
    line.ZIndex = -2147483648
    line.Parent = pivot
    
    data = { pivot = pivot, line = line, lastPos = data and data.lastPos or nil }
    tracerEntries[key] = data
    return data
end

local function drawTracer(data, worldPos, color)
    if not data or not data.pivot or not data.line then return end
    local camera = Workspace.CurrentCamera
    if not camera or not worldPos then data.pivot.Visible = false; return end
    
    data.line.BackgroundColor3 = color
    local screenPos = camera:WorldToViewportPoint(worldPos)
    local viewport = camera.ViewportSize
    local dirX = screenPos.X - (viewport.X * 0.5)
    local dirY = screenPos.Y - viewport.Y
    
    if screenPos.Z < 0 then dirX = -dirX; dirY = -dirY end
    if dirX ~= dirX or dirY ~= dirY then data.pivot.Visible = false; return end
    
    data.pivot.Visible = true
    data.pivot.Rotation = math.deg(math.atan2(dirX, -dirY))
    data.line.Size = UDim2.fromOffset(2, math.sqrt(dirX * dirX + dirY * dirY))
end

local function tracerAnyEnabled()
    return playerTracersEnabled or downedTracersEnabled or botTracersEnabled
end

local function sweepDeadTracers(alive)
    for key, data in pairs(tracerEntries) do
        if not alive[key] then
            if data.pivot then data.pivot:Destroy() end
            tracerEntries[key] = nil
        end
    end
end

local function getPartPos(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst.Position end
    local hrp = inst:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    if inst.PrimaryPart then return inst.PrimaryPart.Position end
    for _, child in ipairs(inst:GetChildren()) do
        if child:IsA("BasePart") then return child.Position end
    end
    return nil
end

local function trackTracer(key, inst, color)
    local data = ensureTracer(key, color)
    if not data then return end
    local pos = getPartPos(inst)
    if pos then data.lastPos = pos end
    if data.lastPos then drawTracer(data, data.lastPos, color) else data.pivot.Visible = false end
end

local function updateTracerESP()
    if not tracerAnyEnabled() then cleanupTracerESP(); return end
    local alive = {}
    if playerTracersEnabled or downedTracersEnabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local downed = false
                pcall(function() downed = isPlayerDowned(plr) end)
                if downed and downedTracersEnabled then
                    local key = "downed_" .. plr.UserId
                    alive[key] = true
                    trackTracer(key, plr.Character, Color3.fromRGB(255, 255, 0))
                elseif (not downed) and playerTracersEnabled then
                    local key = "player_" .. plr.UserId
                    alive[key] = true
                    trackTracer(key, plr.Character, Color3.fromRGB(0, 255, 0))
                end
            end
        end
    end
    if botTracersEnabled then
        local playersFolder = Workspace:FindFirstChild("Players")
        if playersFolder then
            for index, model in ipairs(playersFolder:GetChildren()) do
                if model:IsA("Model") and model:GetAttribute("AI") == true then
                    local key = "bot_" .. index
                    alive[key] = true
                    trackTracer(key, model, Color3.fromRGB(255, 0, 0))
                end
            end
        end
    end
    sweepDeadTracers(alive)
end

local lastTracerUpdate = 0
RunService.RenderStepped:Connect(function()
    if tracerAnyEnabled() and tick() - lastTracerUpdate >= 0.03 then
        lastTracerUpdate = tick()
        updateTracerESP()
    end
end)

local RingHighlightManager = {
    PlayerEnabled = false, DownedEnabled = false, NPCEnabled = false,
    PlayerHighlights = {}, DownedHighlights = {}, NPCHighlights = {},
    Connection = nil, TagToRig = {}
}

local function IsLocalPlayerModel(model)
    if not model then return false end
    if model == LocalPlayer.Character then return true end
    if model.Name == LocalPlayer.Name or model.Name == tostring(LocalPlayer.UserId) then return true end
    local attrName = model:GetAttribute("Name")
    if attrName == LocalPlayer.Name or attrName == LocalPlayer.DisplayName then return true end
    local attrTag = model:GetAttribute("Tag")
    if attrTag == LocalPlayer.Name or attrTag == LocalPlayer.DisplayName then return true end
    local userId = model:GetAttribute("UserId") or model:GetAttribute("PlayerUserId")
    if typeof(userId) == "number" and userId == LocalPlayer.UserId then return true end
    return false
end

local function BuildRigIndex()
    RingHighlightManager.TagToRig = {}
    local rigsFolder = Workspace:FindFirstChild("Rigs")
    if not rigsFolder then return end
    for _, rig in ipairs(rigsFolder:GetChildren()) do
        if rig:IsA("Model") then
            local tag = rig:GetAttribute("Tag")
            if tag ~= nil then RingHighlightManager.TagToRig[tag] = rig end
        end
    end
end

local function ApplyHighlight(storage, rig, color)
    if not rig then return end
    local cham = storage[rig]
    if not cham or not cham.Parent then
        cham = Instance.new("Highlight")
        cham.Name                 = "Ring_ESP_Cham"
        cham.FillTransparency     = 0.5  
        cham.OutlineTransparency  = 0.30
        cham.DepthMode            = Enum.HighlightDepthMode.AlwaysOnTop
        cham.Parent               = rig
        storage[rig] = cham
    end
    cham.FillColor    = color
    cham.OutlineColor = color
end

local function SweepStorage(storage, seen)
    for rig, highlight in pairs(storage) do
        if not seen[rig] then
            if highlight and highlight.Parent then highlight:Destroy() end
            storage[rig] = nil
        end
    end
end

local function ClearAllRings()
    SweepStorage(RingHighlightManager.PlayerHighlights, {})
    SweepStorage(RingHighlightManager.DownedHighlights, {})
    SweepStorage(RingHighlightManager.NPCHighlights, {})
end

local function UpdateRings()
    if not (RingHighlightManager.PlayerEnabled or RingHighlightManager.DownedEnabled or RingHighlightManager.NPCEnabled) then ClearAllRings(); return end
    BuildRigIndex()
    local playersFolder = Workspace:FindFirstChild("Players")
    if not playersFolder then ClearAllRings(); return end
    
    local seenPlayer, seenDowned, seenNPC = {}, {}, {}
    for _, model in ipairs(playersFolder:GetChildren()) do
        if model:IsA("Model") and not IsLocalPlayerModel(model) then
            local tag = model:GetAttribute("Tag")
            local rig = tag and RingHighlightManager.TagToRig[tag]
            if rig then
                if model:GetAttribute("AI") == true then
                    if RingHighlightManager.NPCEnabled then
                        seenNPC[rig] = true
                        ApplyHighlight(RingHighlightManager.NPCHighlights, rig, Color3.fromRGB(255, 0, 0))
                    end
                else
                    if isModelDowned(model) then
                        if RingHighlightManager.DownedEnabled then
                            seenDowned[rig] = true
                            ApplyHighlight(RingHighlightManager.DownedHighlights, rig, Color3.fromRGB(255, 255, 0))
                        end
                    elseif RingHighlightManager.PlayerEnabled then
                        seenPlayer[rig] = true
                        ApplyHighlight(RingHighlightManager.PlayerHighlights, rig, Color3.fromRGB(0, 255, 0))
                    end
                end
            end
        end
    end
    SweepStorage(RingHighlightManager.PlayerHighlights, seenPlayer)
    SweepStorage(RingHighlightManager.DownedHighlights, seenDowned)
    SweepStorage(RingHighlightManager.NPCHighlights, seenNPC)
end

local function EnsureRingConnection()
    if RingHighlightManager.PlayerEnabled or RingHighlightManager.DownedEnabled or RingHighlightManager.NPCEnabled then
        if not RingHighlightManager.Connection then
            RingHighlightManager.Connection = RunService.RenderStepped:Connect(UpdateRings)
        end
        UpdateRings()
    else
        if RingHighlightManager.Connection then RingHighlightManager.Connection:Disconnect(); RingHighlightManager.Connection = nil end
        ClearAllRings()
    end
end

-- ESP Core
local function getDistanceFromCamera(targetPosition)
    local camera = Workspace.CurrentCamera
    if not camera then return 0 end
    return (targetPosition - camera.CFrame.Position).Magnitude
end

local function calculateBoxScale(distance)
    if distance <= 17 then return 1 end
    return math.max(17 / distance, 0.013)
end

local function getRootPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function createBillboardForModel(model, name, color)
    local existing = model:FindFirstChild("ESP_Billboard")
    if existing then existing:Destroy() end
    local rootPart = getRootPart(model)
    if not rootPart then return nil end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Billboard"
    billboard.Adornee = rootPart
    billboard.Parent = rootPart
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.ClipsDescendants = false
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Active = true
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundTransparency = 1
    mainFrame.Parent = billboard
    
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = color
    nameLabel.TextSize = 14
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    nameLabel.TextStrokeTransparency = 0.3
    nameLabel.Parent = mainFrame
    
    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Name = "DistanceLabel"
    distanceLabel.Size = UDim2.new(1, 0, 0, 16)
    distanceLabel.Position = UDim2.new(0, 0, 0, 20)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = ""
    distanceLabel.TextColor3 = color
    distanceLabel.TextSize = 12
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    distanceLabel.TextStrokeTransparency = 0.3
    distanceLabel.Parent = mainFrame
    
    return { billboard = billboard, nameLabel = nameLabel, distanceLabel = distanceLabel }
end

local function updateBillboard(billboardData, name, distance, color)
    if not billboardData then return end
    if name then billboardData.nameLabel.Text = name; billboardData.nameLabel.TextColor3 = color end
    if distance then billboardData.distanceLabel.Text = string.format("%.1f studs", distance); billboardData.distanceLabel.TextColor3 = color end
    billboardData.nameLabel.Visible = name ~= nil
    billboardData.distanceLabel.Visible = distance ~= nil
end

local function create2DBoxForModel(model, color, scale)
    local rootPart = getRootPart(model)
    if not rootPart then return nil end
    local existing = model:FindFirstChild("ESP_2DBox")
    if existing then existing:Destroy() end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_2DBox"
    billboard.Adornee = rootPart
    billboard.Parent = rootPart
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 80 * scale, 0, 100 * scale)
    billboard.ClipsDescendants = false
    
    local boxFrame = Instance.new("Frame")
    boxFrame.Size = UDim2.new(1, 0, 1, 0)
    boxFrame.BackgroundTransparency = 1
    boxFrame.BorderSizePixel = 0
    boxFrame.Parent = billboard
    
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Thickness = math.max(1.5 * scale, 1)
    uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    uiStroke.Color = color
    uiStroke.Parent = boxFrame
    
    return { billboard = billboard, boxFrame = boxFrame, stroke = uiStroke, scale = scale }
end

local function update2DBox(boxData, color, scale)
    if not boxData then return end
    if boxData.stroke then boxData.stroke.Color = color; boxData.stroke.Thickness = math.max(1.5 * scale, 1) end
    if boxData.billboard then boxData.billboard.Size = UDim2.new(0, 80 * scale, 0, 100 * scale) end
    boxData.scale = scale
end

local function remove2DBox(model)
    local rootPart = getRootPart(model)
    if rootPart then local box = rootPart:FindFirstChild("ESP_2DBox"); if box then box:Destroy() end end
end

local function create3DBoxForModel(model, color, size)
    local rootPart = getRootPart(model)
    if not rootPart then return nil end
    local folder = model:FindFirstChild("ESP_3DBox")
    if folder then folder:Destroy() end
    folder = Instance.new("Folder")
    folder.Name = "ESP_3DBox"
    folder.Parent = model
    size = size or Vector3.new(4, 5, 3)
    local offsetX, offsetY, offsetZ = size.X / 2, size.Y / 2, size.Z / 2
    
    local edges = {
        {Vector3.new(0, offsetY, offsetZ), Vector3.new(size.X, 0.1, 0.1), "TopFront"},
        {Vector3.new(0, offsetY, -offsetZ), Vector3.new(size.X, 0.1, 0.1), "TopBack"},
        {Vector3.new(-offsetX, offsetY, 0), Vector3.new(0.1, 0.1, size.Z), "TopLeft"},
        {Vector3.new(offsetX, offsetY, 0), Vector3.new(0.1, 0.1, size.Z), "TopRight"},
        {Vector3.new(0, -offsetY, offsetZ), Vector3.new(size.X, 0.1, 0.1), "BottomFront"},
        {Vector3.new(0, -offsetY, -offsetZ), Vector3.new(size.X, 0.1, 0.1), "BottomBack"},
        {Vector3.new(-offsetX, -offsetY, 0), Vector3.new(0.1, 0.1, size.Z), "BottomLeft"},
        {Vector3.new(offsetX, -offsetY, 0), Vector3.new(0.1, 0.1, size.Z), "BottomRight"},
        {Vector3.new(-offsetX, 0, offsetZ), Vector3.new(0.1, size.Y, 0.1), "FrontLeft"},
        {Vector3.new(offsetX, 0, offsetZ), Vector3.new(0.1, size.Y, 0.1), "FrontRight"},
        {Vector3.new(-offsetX, 0, -offsetZ), Vector3.new(0.1, size.Y, 0.1), "BackLeft"},
        {Vector3.new(offsetX, 0, -offsetZ), Vector3.new(0.1, size.Y, 0.1), "BackRight"}
    }
    
    for _, edge in ipairs(edges) do
        local adornment = Instance.new("BoxHandleAdornment")
        adornment.Adornee = rootPart
        adornment.Size = edge[2]
        adornment.CFrame = CFrame.new(edge[1])
        adornment.Color3 = color
        adornment.Transparency = 0.2
        adornment.AlwaysOnTop = true
        adornment.Visible = true
        adornment.Parent = folder
    end
    return folder
end

local function update3DBoxColor(model, color)
    local folder = model:FindFirstChild("ESP_3DBox")
    if folder then
        for _, adornment in ipairs(folder:GetChildren()) do
            if adornment:IsA("BoxHandleAdornment") then adornment.Color3 = color end
        end
    end
end

local function remove3DBox(model)
    local folder = model:FindFirstChild("ESP_3DBox")
    if folder then folder:Destroy() end
end



local function cleanupElements(elementsTable)
    for model, esp in pairs(elementsTable) do
        if esp.box2D then remove2DBox(model) end
        if esp.box3D then remove3DBox(model) end
        if esp.billboard then
            local rootPart = getRootPart(model)
            if rootPart then local bill = rootPart:FindFirstChild("ESP_Billboard"); if bill then bill:Destroy() end end
        end
    end
    table.clear(elementsTable)
end

local function cleanupESP()
    cleanupElements(ESPManager.AliveElements)
    cleanupElements(ESPManager.DownedElements)
    cleanupElements(ESPManager.NPCElements)
end

local function updateGenericESP(targets, color, settings, elementsTable, skipHighlights)
    local currentTargets = {}
    for _, target in ipairs(targets) do
        local model = target.model
        if model and model.Parent then
            local rootPart = getRootPart(model)
            if rootPart then
                currentTargets[model] = true
                if not elementsTable[model] then elementsTable[model] = {} end
                local esp = elementsTable[model]
                local dist = getDistanceFromCamera(rootPart.Position)
                local scale = calculateBoxScale(dist)
                
                if settings.Boxes then
                    if settings.BoxType == "3D" then
                        if not esp.box3D then esp.box3D = create3DBoxForModel(model, color) else update3DBoxColor(model, color) end
                        if esp.box2D then remove2DBox(model); esp.box2D = nil end
                    else
                        if not esp.box2D then esp.box2D = create2DBoxForModel(model, color, scale) else update2DBox(esp.box2D, color, scale) end
                        if esp.box3D then remove3DBox(model); esp.box3D = nil end
                    end
                else
                    if esp.box2D then remove2DBox(model); esp.box2D = nil end
                    if esp.box3D then remove3DBox(model); esp.box3D = nil end
                end
                
                if settings.Names or settings.Distance then
                    if not esp.billboard then esp.billboard = createBillboardForModel(model, target.name, color) end
                    updateBillboard(esp.billboard, settings.Names and target.name or nil, settings.Distance and dist or nil, color)
                else
                    if esp.billboard then
                        local root = getRootPart(model)
                        if root then local bill = root:FindFirstChild("ESP_Billboard"); if bill then bill:Destroy() end end
                        esp.billboard = nil
                    end
                end
                

            end
        end
    end
    
    for model, esp in pairs(elementsTable) do
        if not currentTargets[model] then
            if esp.box2D then remove2DBox(model) end
            if esp.box3D then remove3DBox(model) end
            if esp.billboard then
                local root = getRootPart(model)
                if root then local bill = root:FindFirstChild("ESP_Billboard"); if bill then bill:Destroy() end end
            end
            elementsTable[model] = nil
        end
    end
end

local function updateESP()
    if not ESPManager.Rendering or not ESPManager.WindowFocused or not Workspace.CurrentCamera then return end
    
    if tick() - ESPManager.LastRigUpdate > 5 then
        ESPManager.RigCache = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and string.find(obj.Name, "Rigs") then table.insert(ESPManager.RigCache, obj) end
        end
        ESPManager.LastRigUpdate = tick()
    end
    
    local aliveTargets, downedTargets, NPCTargets = {}, {}, {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local hum = player.Character:FindFirstChild("Humanoid")
            if hum then
                if isPlayerDowned(player) then table.insert(downedTargets, {model = player.Character, name = player.Name})
                elseif hum.Health > 0 then table.insert(aliveTargets, {model = player.Character, name = player.Name}) end
            end
        end
    end
    
    local playersFolder = Workspace:FindFirstChild("Players")
    if playersFolder then
        for _, model in ipairs(playersFolder:GetChildren()) do
            if model:IsA("Model") and model:GetAttribute("AI") == true then table.insert(NPCTargets, {model = model, name = model.Name}) end
        end
    end
    for _, rig in ipairs(ESPManager.RigCache) do
        if rig:GetAttribute("AI") == true then table.insert(NPCTargets, {model = rig, name = rig.Name}) end
    end
    
    updateGenericESP(aliveTargets, Color3.fromRGB(0, 255, 0), ESPManager.Settings, ESPManager.AliveElements, false)
    updateGenericESP(downedTargets, Color3.fromRGB(255, 255, 0), ESPManager.DownedSettings, ESPManager.DownedElements, false)
    updateGenericESP(NPCTargets, Color3.fromRGB(255, 0, 0), ESPManager.NPCSettings, ESPManager.NPCElements, false)
end

local function StartESP()
    ESPManager.Enabled = true
    if ESPManager.Connections.Render then ESPManager.Connections.Render:Disconnect() end
    local lastUpdate = 0
    ESPManager.Connections.Render = RunService.RenderStepped:Connect(function()
        ESPManager.LastRenderTime = tick()
        ESPManager.Rendering = true
        if tick() - lastUpdate >= 0.03 then
            lastUpdate = tick()
            updateESP()
        end
    end)
end

local function StopESP()
    ESPManager.Enabled = false
    if ESPManager.Connections.Render then ESPManager.Connections.Render:Disconnect(); ESPManager.Connections.Render = nil end
    cleanupESP()
end

UserInputService.WindowFocusReleased:Connect(function() ESPManager.WindowFocused = false; ESPManager.Rendering = false; cleanupESP() end)
UserInputService.WindowFocused:Connect(function() ESPManager.WindowFocused = true; ESPManager.Rendering = true end)

local PlayerESPGroup = ESPTab:AddLeftGroupbox("Player ESP", "user")
local DownedESPGroup = ESPTab:AddRightGroupbox("Downed ESP", "heart-crack")
local NPCESPGroup    = ESPTab:AddLeftGroupbox("NPC ESP", "skull")

PlayerESPGroup:AddToggle("PlayerNames", { Text = "Player Names", Default = false, Callback = function(s) ESPManager.Settings.Names = s; if s then StartESP() else updateESP() end end })
PlayerESPGroup:AddToggle("PlayerBoxes", { Text = "Player Boxes", Default = false, Callback = function(s) ESPManager.Settings.Boxes = s; if s then StartESP() else updateESP() end end })
PlayerESPGroup:AddDropdown("PlayerBoxType", { Text = "Box Type", Values = {"2D", "3D"}, Default = "2D", Callback = function(v) ESPManager.Settings.BoxType = v; if ESPManager.Settings.Boxes then updateESP() end end })
PlayerESPGroup:AddToggle("PlayerRingHighlight", { Text = "Player Ring Highlight", Default = false, Callback = function(s) RingHighlightManager.PlayerEnabled = s; EnsureRingConnection() end })

DownedESPGroup:AddToggle("DownedNames", { Text = "Downed Names", Default = false, Callback = function(s) ESPManager.DownedSettings.Names = s; if s then StartESP() else updateESP() end end })
DownedESPGroup:AddToggle("DownedBoxes", { Text = "Downed Boxes", Default = false, Callback = function(s) ESPManager.DownedSettings.Boxes = s; if s then StartESP() else updateESP() end end })
DownedESPGroup:AddDropdown("DownedBoxType", { Text = "Box Type", Values = {"2D", "3D"}, Default = "2D", Callback = function(v) ESPManager.DownedSettings.BoxType = v; if ESPManager.DownedSettings.Boxes then updateESP() end end })
DownedESPGroup:AddToggle("DownedRingHighlight", { Text = "Downed Ring Highlight", Default = false, Callback = function(s) RingHighlightManager.DownedEnabled = s; EnsureRingConnection() end })

NPCESPGroup:AddToggle("NPCNames", { Text = "NPC Names", Default = false, Callback = function(s) ESPManager.NPCSettings.Names = s; if s then StartESP() else updateESP() end end })
NPCESPGroup:AddToggle("NPCBoxes", { Text = "NPC Boxes", Default = false, Callback = function(s) ESPManager.NPCSettings.Boxes = s; if s then StartESP() else updateESP() end end })
NPCESPGroup:AddDropdown("NPCBoxType", { Text = "Box Type", Values = {"2D", "3D"}, Default = "2D", Callback = function(v) ESPManager.NPCSettings.BoxType = v; if ESPManager.NPCSettings.Boxes then updateESP() end end })
NPCESPGroup:AddToggle("NPCRingHighlight", { Text = "NPC Ring Highlight", Default = false, Callback = function(s) RingHighlightManager.NPCEnabled = s; EnsureRingConnection() end })
end

local VisGroup = VisualTab:AddLeftGroupbox("Visuals", "monitor")
local MiscGroup = VisualTab:AddRightGroupbox("Misc", "wrench")

local cameraStretchConnection
local stretchHorizontal = 0.80
local stretchVertical = 0.80

VisGroup:AddToggle("CameraStretchToggle", {
    Text = "Camera Stretch", Default = false,
    Callback = function(state)
        if state then
            if cameraStretchConnection then cameraStretchConnection:Disconnect() end
            cameraStretchConnection = RunService.RenderStepped:Connect(function()
                local Camera = Workspace.CurrentCamera
                Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, stretchHorizontal, 0, 0, 0, stretchVertical, 0, 0, 0, 1)
            end)
        else
            if cameraStretchConnection then cameraStretchConnection:Disconnect(); cameraStretchConnection = nil end
        end
    end,
})

VisGroup:AddInput("CameraStretchH", {
    Text = "Stretch Horizontal", Default = "0.80", Numeric = true,
    Callback = function(v) local n = tonumber(v); if n then stretchHorizontal = n end end,
})

VisGroup:AddInput("CameraStretchV", {
    Text = "Stretch Vertical", Default = "0.80", Numeric = true,
    Callback = function(v) local n = tonumber(v); if n then stretchVertical = n end end,
})

local fadeConnection = nil
local fadeEnabled = false
VisGroup:AddToggle("DisableFadeEffect", {
    Text = "Disable Fade Effect", Default = false,
    Callback = function(state)
        fadeEnabled = state
        if fadeConnection then fadeConnection:Disconnect(); fadeConnection = nil end
        local coverScreen = PlayerGui:FindFirstChild("Shared") and PlayerGui.Shared:FindFirstChild("Popups") and PlayerGui.Shared.Popups:FindFirstChild("CoverScreen")
        if not coverScreen then return end
        if state then
            coverScreen.Visible = false
            fadeConnection = coverScreen:GetPropertyChangedSignal("Visible"):Connect(function()
                if fadeEnabled and coverScreen.Visible then coverScreen.Visible = false end
            end)
        else
            coverScreen.Visible = true
        end
    end,
})

local FullBright = false
local fullBrightConnection
local originalBrightness = Lighting.Brightness
local originalAmbient = Lighting.Ambient
local originalOutdoorAmbient = Lighting.OutdoorAmbient

local function applyFullBright()
    Lighting.Brightness = 1
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
    Lighting.ColorShift_Top = Color3.new(1, 1, 1)
end

VisGroup:AddToggle("FullBrightToggle", {
    Text = "Full Bright", Default = false,
    Callback = function(state)
        FullBright = state
        if state then
            applyFullBright()
            if fullBrightConnection then fullBrightConnection:Disconnect() end
            fullBrightConnection = RunService.Heartbeat:Connect(function()
                if FullBright then applyFullBright() end
            end)
        else
            if fullBrightConnection then fullBrightConnection:Disconnect(); fullBrightConnection = nil end
            Lighting.Brightness = originalBrightness
            Lighting.Ambient = originalAmbient
            Lighting.OutdoorAmbient = originalOutdoorAmbient
        end
    end,
})

local originalFogEnd = Lighting.FogEnd
local originalAtmospheres = {}
for _, v in pairs(Lighting:GetDescendants()) do
    if v:IsA("Atmosphere") then table.insert(originalAtmospheres, v) end
end

VisGroup:AddToggle("NoFogToggle", {
    Text = "Remove Fog", Default = false,
    Callback = function(state)
        if state then
            Lighting.FogEnd = 1000000
            for _, v in pairs(Lighting:GetDescendants()) do
                if v:IsA("Atmosphere") then v:Destroy() end
            end
        else
            Lighting.FogEnd = originalFogEnd
            for _, atmos in pairs(originalAtmospheres) do
                if not atmos.Parent then
                    local newAtmos = Instance.new("Atmosphere")
                    newAtmos.Density = atmos.Density
                    newAtmos.Offset = atmos.Offset
                    newAtmos.Color = atmos.Color
                    newAtmos.Decay = atmos.Decay
                    newAtmos.Glare = atmos.Glare
                    newAtmos.Haze = atmos.Haze
                    newAtmos.Parent = Lighting
                end
            end
        end
    end,
})

local _originals = { Set = nil, CharacterDiedSimple = nil }
VisGroup:AddToggle("AlwaysDeathFeed", {
    Text = "Always Show Death Feed", Default = false,
    Callback = function(s)
        if s then
            if not _originals.Set then
                _originals.Set = DeathFeed.Set
                _originals.CharacterDiedSimple = DeathFeed.CharacterDiedSimple
                DeathFeed.Set = function(self, eventType, data)
                    if eventType == "Death" then self:CharacterDied(data) else _originals.Set(self, eventType, data) end
                end
                DeathFeed.CharacterDiedSimple = function(self, data) return self:CharacterDied(data) end
            end
        else
            if _originals.Set then
                DeathFeed.Set = _originals.Set
                DeathFeed.CharacterDiedSimple = _originals.CharacterDiedSimple
                _originals.Set = nil
                _originals.CharacterDiedSimple = nil
            end
        end
    end,
})

if hookfunction then
    local info = ColaModule.Tasks[1].AutomaticFunctions[2].Methods[1].Info
    local endlessColaEnabled = false
    local modifyColaEnabled = false
    local customDuration = tonumber(info.Duration) or 10
    local customSpeedBoost = tonumber(info.SpeedBoost) or 15

    local function ColaVignette()
        local duration = modifyColaEnabled and customDuration or info.Duration
        FireClient(Events.SharedUISetType, "Vignette", info.Color, duration, true)
    end
    local function ColaSpeedBoost(Type)
        local character = LocalPlayer.Character
        if character and character:GetAttribute("Tag") then
            local speed = modifyColaEnabled and customSpeedBoost or info.SpeedBoost
            local duration = modifyColaEnabled and customDuration or info.Duration
            FireClient(Events.CharacterTask, character:GetAttribute("Tag"), "Movement", {
                SpeedChange = { Value = speed, Type = Type or "Cola", Length = duration }
            })
        end
    end

    local gmt = getrawmetatable(game)
    local oldNamecall = gmt.__namecall
    local isColaHooked = false
    local function applyColaHook()
        if isColaHooked then return end
        setreadonly(gmt, false)
        gmt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            local args = { ... }
            if self == Events.ToolAction and (method == "FireServer" or method == "fireServer") then
                for _, v in ipairs(args) do
                    if typeof(v) == "buffer" then
                        local content = buffer.tostring(v)
                        if content == "\1\1\1" and endlessColaEnabled then return end
                        if content == "\1\2\1" then
                            if endlessColaEnabled then
                                ColaSpeedBoost(); task.wait(); ColaVignette(); return
                            elseif modifyColaEnabled then
                                task.spawn(function() ColaSpeedBoost("FakeCola"); ColaVignette() end); return
                            end
                        end
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(gmt, true)
        isColaHooked = true
    end
    local function removeColaHook()
        if not isColaHooked then return end
        setreadonly(gmt, false); gmt.__namecall = oldNamecall; setreadonly(gmt, true); isColaHooked = false
    end
    local function checkColaHookStatus()
        if endlessColaEnabled or modifyColaEnabled then applyColaHook() else removeColaHook() end
    end

    VisGroup:AddToggle("EndlessCola", {
        Text = "Endless Cola", Default = false,
        Callback = function(s) endlessColaEnabled = s; checkColaHookStatus() end,
    })
    VisGroup:AddToggle("ColaBooster", {
        Text = "Cola Booster", Default = false,
        Callback = function(s) modifyColaEnabled = s; checkColaHookStatus() end,
    })
    VisGroup:AddInput("ColaDuration", {
        Text = "Cola Duration", Default = tostring(customDuration),
        Callback = function(v) local n = tonumber(v); if n then customDuration = n end end,
    })
    VisGroup:AddInput("ColaSpeed", {
        Text = "Cola Speed Boost", Default = tostring(customSpeedBoost),
        Callback = function(v) local n = tonumber(v); if n then customSpeedBoost = n end end,
    })
end

local AntiAFKConnection
MiscGroup:AddToggle("AntiAFK", {
    Text = "Anti AFK", Default = false,
    Callback = function(s)
        if s then
            AntiAFKConnection = LocalPlayer.Idled:Connect(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
            end)
        else
            if AntiAFKConnection then AntiAFKConnection:Disconnect(); AntiAFKConnection = nil end
        end
    end,
})

local OriginalRagdollFunctions = {}
MiscGroup:AddToggle("AntiRagdoll", {
    Text = "Anti Ragdoll", Default = false,
    Callback = function(s)
        if s then
            if not OriginalRagdollFunctions.Ragdoll then
                OriginalRagdollFunctions.Ragdoll = RagdollModule.Ragdoll
                OriginalRagdollFunctions.StartRagdoll = RagdollModule.StartRagdoll
                RagdollModule.Ragdoll = function(self, isPermanent, impulseData, ragdollConfig)
                    if ragdollConfig and ragdollConfig.Model then self:EndRagdoll(ragdollConfig.Model) end
                end
                RagdollModule.StartRagdoll = function() end
            end
        else
            if OriginalRagdollFunctions.Ragdoll then
                RagdollModule.Ragdoll = OriginalRagdollFunctions.Ragdoll
                RagdollModule.StartRagdoll = OriginalRagdollFunctions.StartRagdoll
                OriginalRagdollFunctions = {}
            end
        end
    end,
})

MiscGroup:AddButton({
    Text = "Hop in Random Vehicle",
    Callback = function()
        local vehicles = Workspace:FindFirstChild("Vehicles")
        if vehicles and #vehicles:GetChildren() > 0 then
            Interact:FireServer("Vehicle", vehicles:GetChildren()[math.random(1, #vehicles:GetChildren())]:GetAttribute("Tag"))
        end
    end,
})

if UserInputService.TouchEnabled then
    local activeDirections = { left = false, right = false, up = false, down = false }
    local activeTouches = {}
    local isMovementEnabled = false
    local movementButtons = {}
    local visibilityConnection = nil
    local MOVE_DIRECTION = Vector3.new(0, 0, 0)

    local function setMovementVector(direction)
        MOVE_DIRECTION = direction
        if ControlModule then
            local originalGetMove = ControlModule.GetMoveVector
            ControlModule.GetMoveVector = function(...)
                local input = originalGetMove(...)
                if input.Magnitude > 0.1 then return input end
                return MOVE_DIRECTION
            end
        end
    end

    local function resetAllDirections()
        activeDirections.left = false; activeDirections.right = false; activeDirections.up = false; activeDirections.down = false
        activeTouches = {}
        setMovementVector(Vector3.new(0, 0, 0))
    end

    local function createTouchButton(config)
        local button = Instance.new("ImageButton")
        button.Name = config.Name
        button.ImageRectOffset = Vector2.new(1, 146)
        button.ImageRectSize = Vector2.new(144, 144)
        button.AutoButtonColor = false
        button.AnchorPoint = config.AnchorPoint or Vector2.new(0, 0.5)
        button.BackgroundColor3 = Color3.new(0, 0, 0)
        button.BackgroundTransparency = 0.5
        button.Position = config.Position
        button.Size = config.Size
        button.Parent = config.Parent
        button.Visible = false
        Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
        
        local textLabel = Instance.new("TextLabel")
        textLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
        textLabel.Text = config.Text
        textLabel.TextColor3 = Color3.new(1, 1, 1)
        textLabel.TextScaled = true
        textLabel.BackgroundTransparency = 1
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.Parent = button

        button.MouseButton1Down:Connect(function() if isMovementEnabled then config.Callback(true) end end)
        button.MouseButton1Up:Connect(function() if isMovementEnabled then config.Callback(false) end end)
        button.MouseLeave:Connect(function() if isMovementEnabled then config.Callback(false) end end)

        local function inButton(pos)
            local abs = button.AbsolutePosition
            local size = button.AbsoluteSize
            return pos.X >= abs.X and pos.X <= abs.X + size.X
               and pos.Y >= abs.Y and pos.Y <= abs.Y + size.Y
        end
        UserInputService.InputBegan:Connect(function(input, processed)
            if processed or input.UserInputType ~= Enum.UserInputType.Touch then return end
            if inButton(input.Position) then
                if isMovementEnabled then config.Callback(true) end
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                if isMovementEnabled then config.Callback(false) end
            end
        end)
        return button
    end

    local function updateMovementSystem()
        local buttonState = false
        local exitVehicle = PlayerGui:FindFirstChild("Game") and PlayerGui.Game:FindFirstChild("HUD") and PlayerGui.Game.HUD:FindFirstChild("Mobile") and PlayerGui.Game.HUD.Mobile:FindFirstChild("Center") and PlayerGui.Game.HUD.Mobile.Center:FindFirstChild("Interact") and PlayerGui.Game.HUD.Mobile.Center.Interact:FindFirstChild("Interact") and PlayerGui.Game.HUD.Mobile.Center.Interact.Interact:FindFirstChild("ExitVehicle")
        if exitVehicle then buttonState = exitVehicle.Visible end
        
        isMovementEnabled = buttonState
        if not isMovementEnabled then resetAllDirections() end
        for _, button in pairs(movementButtons) do
            if button and button.Parent then button.Visible = isMovementEnabled end
        end
    end

    MiscGroup:AddToggle("CarsTouchHUD", {
        Text = "Cars Touch HUD", Default = false,
        Callback = function(c)
            if c then
                local rightPanel = PlayerGui:FindFirstChild("Game") and PlayerGui.Game:FindFirstChild("HUD") and PlayerGui.Game.HUD:FindFirstChild("Mobile") and PlayerGui.Game.HUD.Mobile:FindFirstChild("Right")
                local leftPanel = PlayerGui:FindFirstChild("Game") and PlayerGui.Game:FindFirstChild("HUD") and PlayerGui.Game.HUD:FindFirstChild("Mobile") and PlayerGui.Game.HUD.Mobile:FindFirstChild("Left") and PlayerGui.Game.HUD.Mobile.Left:FindFirstChild("Mobile")
                local exitVehicleParent = PlayerGui:FindFirstChild("Game") and PlayerGui.Game:FindFirstChild("HUD") and PlayerGui.Game.HUD:FindFirstChild("Mobile") and PlayerGui.Game.HUD.Mobile:FindFirstChild("Center") and PlayerGui.Game.HUD.Mobile.Center:FindFirstChild("Interact") and PlayerGui.Game.HUD.Mobile.Center.Interact:FindFirstChild("Interact")
                
                if rightPanel and leftPanel and exitVehicleParent then
                    movementButtons.VUp = createTouchButton({ Name = "VUp", Parent = rightPanel, Text = "↑", Position = UDim2.new(-1.5, 0, -0.7, 0), Size = UDim2.new(1.39, 0, 1.39, 0), Callback = function(p) activeDirections.up = p; setMovementVector(Vector3.new(0, 0, activeDirections.down and 1 or (activeDirections.up and -1 or 0))) end })
                    movementButtons.VDown = createTouchButton({ Name = "VDown", Parent = rightPanel, Text = "↓", Position = UDim2.new(-3.2, 0, -0.7, 0), Size = UDim2.new(1.39, 0, 1.39, 0), Callback = function(p) activeDirections.down = p; setMovementVector(Vector3.new(0, 0, activeDirections.down and 1 or (activeDirections.up and -1 or 0))) end })
                    movementButtons.VLeft = createTouchButton({ Name = "VLeft", Parent = leftPanel, Text = "←", Position = UDim2.new(0.4, 0, 0.66, 0), Size = UDim2.new(0.3, 0, 0.3, 0), Callback = function(p) activeDirections.left = p; setMovementVector(Vector3.new(activeDirections.right and 1 or (activeDirections.left and -1 or 0), 0, 0)) end })
                    movementButtons.VRight = createTouchButton({ Name = "VRight", Parent = leftPanel, Text = "→", Position = UDim2.new(0.8, 0, 0.66, 0), Size = UDim2.new(0.3, 0, 0.3, 0), Callback = function(p) activeDirections.right = p; setMovementVector(Vector3.new(activeDirections.right and 1 or (activeDirections.left and -1 or 0), 0, 0)) end })
                    
                    if visibilityConnection then visibilityConnection:Disconnect() end
                    visibilityConnection = exitVehicleParent.ChildAdded:Connect(updateMovementSystem)
                    updateMovementSystem()
                end
            else
                for _, btn in pairs(movementButtons) do if btn and btn.Parent then btn:Destroy() end end
                movementButtons = {}
                if visibilityConnection then visibilityConnection:Disconnect(); visibilityConnection = nil end
                isMovementEnabled = false
                resetAllDirections()
            end
        end,
    })
end

MiscGroup:AddButton({
    Text = "Redeem All Codes",
    Callback = function()
        local RemoteEvent
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d.Name == "RedeemCode" and d:IsA("RemoteEvent") then RemoteEvent = d; break end
        end
        if not RemoteEvent then return end
        
        local URL = "https://web-wacker.netlify.app/api/raw?url=https%3A%2F%2Fevade-nextbot.fandom.com%2Fwiki%2FCodes"
        local success, content = pcall(function() return game:HttpGet(URL, true) end)
        if not success or not content then return end
        
        local codes = {}
        for code in content:gmatch("<td[^>]*>%s*<code[^>]*>(.-)</code>") do
            code = code:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"):gsub("&quot;", '"'):match("^%s*(.-)%s*$")
            if #code > 0 then table.insert(codes, code) end
        end
        
        task.spawn(function()
            for i, code in ipairs(codes) do
                pcall(function() RemoteEvent:FireServer(code) end)
                FireClient(Events.SharedUISetType, "Notification", "Message", "Redeeming ["..i.."/"..#codes.."]: "..code, "Info")
                task.wait(4)
            end
        end)
    end,
})

local UtilGroup = UtilityTab:AddLeftGroupbox("Utility Tools", "tool")
local PhysicsGroup = UtilityTab:AddRightGroupbox("Physics & Environment", "move-3d")
local PerfGroup = UtilityTab:AddLeftGroupbox("Performance", "zap")

UtilGroup:AddToggle("InvisWallsCollide", {
    Text = "Invis Walls Collide", Default = true, Keybind = "H",
    Callback = function(state)
        local invisPartsFolder = Workspace:FindFirstChild("Map")
        if invisPartsFolder then invisPartsFolder = invisPartsFolder:FindFirstChild("InvisParts") end
        if not invisPartsFolder then
            invisPartsFolder = Workspace:FindFirstChild("Game")
            if invisPartsFolder then
                invisPartsFolder = invisPartsFolder:FindFirstChild("Map")
                if invisPartsFolder then invisPartsFolder = invisPartsFolder:FindFirstChild("InvisParts") end
            end
        end
        if invisPartsFolder then
            for _, obj in ipairs(invisPartsFolder:GetDescendants()) do
                if obj:IsA("BasePart") then obj.CanCollide = state end
            end
        else
            Window:Notify({ Title = "Error", Content = "InvisParts folder not found", Icon = "circle-x" })
        end
    end,
})

UtilGroup:AddInput("TimeChangerInput", {
    Text = "Set Time (HH:MM)", Placeholder = "12:00", Default = "12:00",
    Callback = function(value)
        value = value:gsub("^%s*(.-)%s*$", "%1")
        local h_str, m_str = value:match("(%d+):(%d+)")
        if h_str and m_str then
            local h, m = tonumber(h_str), tonumber(m_str)
            if h and m and h >= 0 and h <= 23 and m >= 0 and m <= 59 then
                Lighting.ClockTime = h + (m / 60)
            else
                Window:Notify({ Title = "Invalid Time", Content = "Please enter a valid time between 00:00 and 23:59.", Icon = "clock" })
            end
        else
            Window:Notify({ Title = "Invalid Format", Content = "Please use the HH:MM format.", Icon = "clock" })
        end
    end,
})

local originalGameGravity = Workspace.Gravity
local CustomGravity = false
local GravityValue = Workspace.Gravity

PhysicsGroup:AddToggle("GravityToggle", {
    Text = "Custom Gravity", Default = false, Keybind = "G",
    Callback = function(state)
        CustomGravity = state
        Workspace.Gravity = state and GravityValue or originalGameGravity
    end,
})
PhysicsGroup:AddInput("GravityInput", {
    Text = "Gravity Value", Default = tostring(originalGameGravity), Numeric = true,
    Callback = function(v)
        local num = tonumber(v)
        if num then
            GravityValue = num
            if CustomGravity then Workspace.Gravity = num end
        end
    end,
})

local JumpPadValue = 360
local originalUse = JumpPadModule.Use
PhysicsGroup:AddToggle("JumpPadToggle", {
    Text = "Jump Pad Bounce Modifier", Default = false,
    Callback = function(state)
        if state then
            JumpPadModule.Use = function(p1, p2)
                if p2 == nil or (p2 ~= LocalPlayer.Character or p2:GetAttribute("JumpPadInEffect") == true) then
                    return originalUse(p1, p2)
                end
                p1.Model.AnimationController:LoadAnimation(p1.Model.Animations.Use):Play(0.1)
                p1.Model.BoundingBox.Launch:Play()
                LocalPlayer.Character.HumanoidRootPart:ApplyImpulse(Vector3.new(0, JumpPadValue, 0))
                p2:SetAttribute("JumpPadInEffect", true)
                task.spawn(function()
                    task.wait(1.5)
                    p2:SetAttribute("JumpPadInEffect", nil)
                end)
            end
        else
            JumpPadModule.Use = originalUse
        end
    end,
})
PhysicsGroup:AddInput("JumpPadValueInput", {
    Text = "Jump Value", Default = "360", Numeric = true,
    Callback = function(v) local n = tonumber(v); if n then JumpPadValue = n end end,
})

local NoRender = false
local NoRenderColor = Color3.fromRGB(0, 0, 0)
PerfGroup:AddToggle("NoRenderToggle", {
    Text = "No Render", Default = false,
    Callback = function(state)
        NoRender = state
        RunService:Set3dRenderingEnabled(not state)
        if state then
            local gui = Instance.new("ScreenGui")
            gui.Name = "NoRenderBackground"
            gui.DisplayOrder = -99999
            gui.IgnoreGuiInset = true
            gui.ResetOnSpawn = false
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, 0, 1, 0)
            frame.BackgroundColor3 = NoRenderColor
            frame.BorderSizePixel = 0
            frame.Parent = gui
            gui.Parent = PlayerGui
        else
            local gui = PlayerGui:FindFirstChild("NoRenderBackground")
            if gui then gui:Destroy() end
        end
    end,
})
PerfGroup:AddColorPicker("NoRenderColor", {
    Text = "No Render Color", Default = Color3.fromRGB(0, 0, 0),
    Callback = function(color)
        NoRenderColor = color
        if NoRender then
            local gui = PlayerGui:FindFirstChild("NoRenderBackground")
            if gui and gui:FindFirstChildOfClass("Frame") then
                gui:FindFirstChildOfClass("Frame").BackgroundColor3 = color
            end
        end
    end,
})

PerfGroup:AddButton({
    Text = "Remove Textures",
    Callback = function()
        for _, part in ipairs(Workspace:GetDescendants()) do
            if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
                part.Material = Enum.Material.SmoothPlastic
                if part:IsA("MeshPart") and part.TextureID ~= "" then part.TextureID = "" end
                for _, tex in ipairs(part:GetChildren()) do
                    if tex:IsA("Texture") or tex:IsA("Decal") then tex.Texture = "rbxassetid://0" end
                end
            end
        end
        Window:Notify({ Title = "Textures Removed", Content = "All textures and materials have been removed", Icon = "check" })
    end,
})

PerfGroup:AddButton({
    Text = "Clear MaterialService",
    Callback = function()
        for _, child in ipairs(MaterialService:GetChildren()) do child:Destroy() end
        Window:Notify({ Title = "MaterialService Cleared", Content = "All materials removed from MaterialService", Icon = "check" })
    end,
})

PerfGroup:AddButton({
    Text = "Low Quality",
    Callback = function()
        for _, v in next, game:GetDescendants() do
            if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("BasePart") then
                v.Material = Enum.Material.SmoothPlastic
            end
            if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Explosion") or v:IsA("Sparkles") or v:IsA("Fire") then
                v.Enabled = false
            end
            if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") then
                v.Enabled = false
            end
            if v:IsA("Decal") or v:IsA("Texture") then v.Texture = "" end
            if v:IsA("Sky") then v.Parent = nil end
        end
        Window:Notify({ Title = "Low Quality", Content = "Textures, effects, and lighting optimized.", Icon = "check" })
    end,
})

if LocalPlayer:GetAttribute("VIPCommandsAccess") == true then
    local SelectedMapSetting = "BrickMaze"
    local function isValidMap(mapName)
        local mapsFolder = ReplicatedStorage:FindFirstChild("Info")
        if mapsFolder then mapsFolder = mapsFolder:FindFirstChild("Maps") end
        if mapsFolder then
            for _, map in ipairs(mapsFolder:GetChildren()) do
                if map.Name == mapName then return true end
            end
        end
        return false
    end

    VIPGroup:AddButton({
        Text = "VIP CMD Macro",
        Callback = function()
            local BaseURL = "https://darahub.pages.dev"
            loadstring(game:HttpGet(BaseURL .. "/api/script/Tools/EvadeCMDMacroGUI.lua"))()
        end,
    })
    
    VIPGroup:AddInput("MapSettingsInput", {
        Text = "Set Map Settings", Default = "BrickMaze", Placeholder = "Enter map name",
        Callback = function(value) SelectedMapSetting = value end,
    })
    
    VIPGroup:AddButton({
        Text = "Add Map",
        Callback = function()
            if SelectedMapSetting and SelectedMapSetting ~= "" then
                if isValidMap(SelectedMapSetting) then
                    pcall(function()
                        Events.Admin.VIPCommand:FireServer("AddMap", SelectedMapSetting)
                        Window:Notify({ Title = "Custom Server", Content = "Added map: " .. SelectedMapSetting, Icon = "check" })
                    end)
                else
                    Window:Notify({ Title = "Custom Server", Content = "Invalid map name: " .. SelectedMapSetting, Icon = "x" })
                end
            end
        end,
    })
    
    VIPGroup:AddButton({
        Text = "Remove Map",
        Callback = function()
            if SelectedMapSetting and SelectedMapSetting ~= "" then
                if isValidMap(SelectedMapSetting) then
                    pcall(function()
                        Events.Admin.VIPCommand:FireServer("RemoveMap", SelectedMapSetting)
                        Window:Notify({ Title = "Custom Server", Content = "Removed map: " .. SelectedMapSetting, Icon = "check" })
                    end)
                else
                    Window:Notify({ Title = "Custom Server", Content = "Invalid map name: " .. SelectedMapSetting, Icon = "x" })
                end
            end
        end,
    })
end

ThemeManager:SetLibrary(Window)
SaveManager:SetLibrary(Window)
ThemeManager:SetFolder("EvadeViz")
SaveManager:SetFolder("EvadeViz")

SaveManager:BuildConfigSection(Settings)
ThemeManager:ApplyToTab(Settings)

ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
