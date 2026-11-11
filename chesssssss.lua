local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

local ChessClient = ReplicatedStorage:WaitForChild("ChessClient")
local Chess = ReplicatedStorage:WaitForChild("Chess")

local App = require(ChessClient:WaitForChild("App"))
local Bot = require(Chess:WaitForChild("Bot"))
local Engine = require(Chess:WaitForChild("Engine"))
local Cosmetics = require(Chess:WaitForChild("Cosmetics"))

local okVortex, VortexBot = pcall(require, Chess:WaitForChild("VortexBot"))
if not okVortex then VortexBot = nil end

local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local BY_ID = Cosmetics.BY_ID
local tfind, tclone, mmax, mmin = table.find, table.clone, math.max, math.min

local suggestEnabled = false
local autoPlayEnabled = false
local adaptiveTimeEnabled = true
local useVortex = true
local preventRepetition = true
local searchDepth = 40
local searchTime = 6.0
local isThinking = false
local lastSuggestedPly = -1
local lastPlayedPly = -1
local lastInGameState = false
local autoHideWindowInGame = false
local hideTopbarInGame = false
local topbarHidden = false

local unlockEnabled = false
local unlockInstalled = false
local restoring = true
local startupEnabled = false
local saveQueued = false
local persisted = {}
local watchToken = 0
local restoreToken = 0

local allIds = {}
local fullInv = {}
for _, item in ipairs(Cosmetics.ITEMS) do
    if not item.free and not allIds[item.id] then
        allIds[item.id] = true
        fullInv[#fullInv + 1] = item.id
    end
end

local SAVE_FOLDER = "Byte/RoChess"
local SAVE_FILE = SAVE_FOLDER .. "/unlock_settings.json"

pcall(function()
    if makefolder and not isfolder("Byte") then makefolder("Byte") end
    if makefolder and not isfolder(SAVE_FOLDER) then makefolder(SAVE_FOLDER) end
end)

local function saveUnlockState()
    if not writefile then return end
    pcall(function()
        writefile(SAVE_FILE, HttpService:JSONEncode({
            enabled = unlockEnabled,
            eq = persisted,
        }))
    end)
end

local function queueSave()
    if saveQueued then return end
    saveQueued = true
    task.delay(0.4, function()
        saveQueued = false
        saveUnlockState()
    end)
end

local function loadUnlockState()
    if not isfile or not readfile or not isfile(SAVE_FILE) then return end
    local ok, content = pcall(readfile, SAVE_FILE)
    if not ok or type(content) ~= "string" or content == "" then return end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok2 or type(data) ~= "table" then return end
    startupEnabled = data.enabled == true
    if type(data.eq) == "table" then
        for kind, id in pairs(data.eq) do
            if type(kind) == "string" and BY_ID[id] ~= nil then
                persisted[kind] = id
            end
        end
    end
end

loadUnlockState()

local function setEquip(kind, id, force)
    if type(kind) ~= "string" then return end
    if restoring and not force then return end
    if id == nil or BY_ID[id] == nil then return end
    if persisted[kind] == id then return end
    persisted[kind] = id
    queueSave()
end

local function mergeEq(eq)
    if restoring then
        for kind, id in pairs(persisted) do
            eq[kind] = id
        end
    elseif App.cos and type(App.cos.eq) == "table" and App.cos.eq ~= eq then
        for kind, id in pairs(App.cos.eq) do
            eq[kind] = id
        end
    end
    if restoring and persisted.board then eq.board = persisted.board end
    if eq.board and App.settings then
        App.settings.theme = eq.board
    end
end

local function refreshPages()
    local pages = App.pages
    if not pages then return end
    if pages.inventory and pages.inventory.refresh then
        pcall(pages.inventory.refresh)
    end
    if pages.shop and pages.shop.refresh then
        pcall(pages.shop.refresh)
    end
end

local function patchCos(cos, full)
    cos.inv = tclone(fullInv)
    cos.eq = cos.eq or {}
    mergeEq(cos.eq)
    if full then
        cos.crates = mmax(tonumber(cos.crates) or 0, 9999)
        cos.prompted = true
    end
end

local function tryInstallUnlock()
    if unlockInstalled then return true end
    if not (App.owns and App.request and App.handlers and App.Shop and App.setCos) then
        return false
    end

    App.owns = function(id)
        if unlockEnabled and allIds[id] then return true end
        local def = BY_ID[id]
        if def == nil then return false end
        if def.free == true then return true end
        local inv = App.cos and App.cos.inv
        return inv ~= nil and tfind(inv, id) ~= nil
    end

    local origRequest = App.request
    App.request = function(req)
        local res = origRequest(req)
        if unlockEnabled and type(res) == "table" and res.cos then
            patchCos(res.cos, true)
        end
        return res
    end

    local origProfile = App.handlers.profile
    if origProfile then
        App.handlers.profile = function(profileData)
            if unlockEnabled and profileData and profileData.cos then
                patchCos(profileData.cos, false)
            end
            return origProfile(profileData)
        end
    end

    local origSetCos = App.setCos
    App.setCos = function(newCos)
        if unlockEnabled and type(newCos) == "table" then
            patchCos(newCos, true)
        end
        local res = origSetCos(newCos)
        if unlockEnabled then refreshPages() end
        return res
    end

    local origApplyCosmetics = App.applyCosmetics
    if origApplyCosmetics then
        App.applyCosmetics = function(...)
            if unlockEnabled and App.cos then
                patchCos(App.cos, true)
            end
            return origApplyCosmetics(...)
        end
    end

    if App.Shop.equip then
        local origEquip = App.Shop.equip
        App.Shop.equip = function(item)
            local kind = item and item.type
            if unlockEnabled and kind then
                if App.cos then
                    App.cos.eq = App.cos.eq or {}
                    App.cos.eq[kind] = item.id
                    if kind == "board" and App.settings then
                        App.settings.theme = item.id
                        if App.applySettings then pcall(App.applySettings) end
                    end
                end
                setEquip(kind, item.id, true)
            end
            local ok, err = pcall(origEquip, item)
            if unlockEnabled and App.cos then
                App.cos.eq = App.cos.eq or {}
                if kind and persisted[kind] then
                    App.cos.eq[kind] = persisted[kind]
                end
                pcall(App.setCos, App.cos)
            end
            return ok, err
        end
    end

    local origApplySettings = App.applySettings
    if origApplySettings then
        App.applySettings = function(...)
            if unlockEnabled and App.cos and App.cos.eq and App.settings then
                if restoring and persisted.board then
                    App.cos.eq.board = persisted.board
                end
                if App.cos.eq.board then
                    App.settings.theme = App.cos.eq.board
                elseif App.settings.theme then
                    App.cos.eq.board = App.settings.theme
                end
            end
            return origApplySettings(...)
        end
    end

    if App.loadoutFor then
        local origLoadoutFor = App.loadoutFor
        App.loadoutFor = function(session, side)
            local result = origLoadoutFor(session, side)
            local eq = App.cos and App.cos.eq
            if unlockEnabled and eq and session and side == (session.myColor or 1) then
                result.pieces = eq.pieces or result.pieces
                result.accessory = eq.accessory or result.accessory
                result.effect = eq.effect or result.effect
            end
            return result
        end
    end

    unlockInstalled = true
    return true
end

local function waitInstall(tries)
    for _ = 1, tries do
        if tryInstallUnlock() then return true end
        task.wait(0.1)
    end
    return false
end

task.spawn(waitInstall, 300)

local function restoreEquips(token)
    for _ = 1, 1200 do
        if App.cos or not unlockEnabled or token ~= restoreToken then break end
        task.wait(0.1)
    end
    if not unlockEnabled or token ~= restoreToken or not App.cos then return end

    App.cos.eq = App.cos.eq or {}
    mergeEq(App.cos.eq)
    pcall(App.setCos, App.cos)
    pcall(App.applyCosmetics)
    if App.applySettings then pcall(App.applySettings) end
    restoring = false
    refreshPages()
end

local function syncEquips()
    local eq = App.cos and App.cos.eq
    if type(eq) ~= "table" then return end
    if eq.board and App.settings and App.settings.theme ~= eq.board then
        App.settings.theme = eq.board
        if App.applySettings then pcall(App.applySettings) end
    end
    for kind, id in pairs(eq) do
        setEquip(kind, id)
    end
    for kind in pairs(persisted) do
        if eq[kind] == nil then
            persisted[kind] = nil
            queueSave()
        end
    end
end

local function startWatcher()
    watchToken += 1
    local token = watchToken
    task.spawn(function()
        while unlockEnabled and token == watchToken do
            task.wait(0.5)
            if unlockEnabled and not restoring then
                pcall(syncEquips)
            end
        end
    end)
end

local function setUnlock(v)
    if unlockEnabled == v then return end
    unlockEnabled = v
    restoring = true
    restoreToken += 1
    if v then
        local token = restoreToken
        startWatcher()
        task.spawn(function()
            waitInstall(100)
            restoreEquips(token)
        end)
    else
        watchToken += 1
        pcall(App.applyCosmetics)
        refreshPages()
    end
    saveUnlockState()
end

local Window = Library:CreateWindow({
    Title = "RoChess Engine+",
    Footer = "v2.2",
    Layout = "Bottom bar",
    MenuKey = Enum.KeyCode.RightShift,
    ToggleButton = true,
})

local MainTab = Window:AddTab("Main", "cpu")
local SettingsTab = Window:CreateSettingsTab()
local Group = MainTab:AddLeftGroupbox("Engine", "cpu")
local UnlockGroup = MainTab:AddRightGroupbox("Unlock", "lock")
local HideGroup = SettingsTab:AddLeftGroupbox("Auto-Hide", "eye")

local statusLabel = Group:AddLabel("Status: Ready")
local lastStatus = "Status: Ready"

local function setStatus(t)
    if t == lastStatus then return end
    lastStatus = t
    pcall(function()
        if statusLabel.SetText then
            statusLabel:SetText(t)
        else
            statusLabel.Text = t
        end
    end)
end

local function getSession() return App and App.session or nil end

local function isInLiveGame()
    local s = getSession()
    if not s then return false end
    if s.kind ~= "online" and s.kind ~= "bot" then return false end
    return not s.over
end

local function isPlayable(session)
    if not session or session.over then return false end
    local k = session.kind
    if k == "watch" or k == "review" or k == "idle" then return false end
    
    if k == "online" or k == "bot" then
        return session:isMyTurn()
    end
    
    return true
end

local function ensureBoardSized()
    local board = App and App.board
    if board then
        local ok, px = pcall(function() return board.sqPx end)
        if not ok or not px or px <= 0 then
            pcall(function() board:onResize() end)
        end
    end
end

local function effectiveTime()
    if not adaptiveTimeEnabled then return searchTime end
    local session = getSession()
    if not session or not session.clocks or not session.myColor then return searchTime end
    local remaining = (session.clocks[session.myColor] or 60000) / 1000
    local tcClass = session.tc and session.tc.class or "blitz"
    local cap
    if tcClass == "bullet" then cap = 0.5
    elseif tcClass == "blitz" then cap = 2.0
    else cap = 8.0 end
    return mmin(searchTime, cap, mmax(0.1, remaining / 25))
end

local function findBestAvoidingRepetition(fen, ucis, time, maxDepth, primaryResult)
    if not primaryResult or not primaryResult.best then return primaryResult end
    if primaryResult.mate and primaryResult.mate < 0 then return primaryResult end
    if primaryResult.score and primaryResult.score < -200 then return primaryResult end

    local engine = Engine.new(fen)
    for _, u in ipairs(ucis) do
        local m = engine:moveFromUci(u)
        if m then engine:makeMove(m) else break end
    end

    local primaryMove = engine:moveFromUci(primaryResult.best)
    if not primaryMove then return primaryResult end

    engine:makeMove(primaryMove)
    local repCount = engine:repetitionCount()
    engine:undoMove()

    if repCount < 3 then return primaryResult end

    local primaryUci = primaryResult.best
    local candidates = {}
    for _, m in ipairs(engine:legalMoves()) do
        if engine:moveToUci(m) ~= primaryUci then
            engine:makeMove(m)
            local r = engine:repetitionCount()
            engine:undoMove()
            if r < 3 then candidates[m] = true end
        end
    end

    if next(candidates) == nil then return primaryResult end

    local search = Bot.Search.new(engine)
    search.useQs = true
    local altDepth = mmin(maxDepth or 10, 10)
    local started = os.clock()
    search.deadline = started + mmax(time or 1.0, 1.5)
    search.soft = search.deadline
    search.sliceStart = started

    local scores = search:rootScores(altDepth)
    if not scores then return primaryResult end

    local bestAlt
    for _, entry in ipairs(scores) do
        if candidates[entry.move] and (not bestAlt or entry.score > bestAlt.score) then
            bestAlt = entry
        end
    end

    if not bestAlt or bestAlt.score <= 0 then return primaryResult end

    return {
        best = engine:moveToUci(bestAlt.move),
        score = bestAlt.score * engine.side,
        mate = nil,
        depth = altDepth,
        nodes = search.nodes,
        repetitionAvoided = true,
    }
end

local function runAnalysis()
    local session = getSession()
    if not session then return nil, "No game" end
    
    local fen = session.startFen or Engine.START_FEN
    local ucis = tclone(session.ucis)
    local t = effectiveTime()
    local engineFn = (useVortex and VortexBot and VortexBot.analyse) or (Bot and Bot.analyse)
    if not engineFn then return nil, "No engine" end
    
    local ok, res = pcall(engineFn, fen, ucis, t, searchDepth, {})
    if not ok then return nil, "Search error" end
    if not res or not res.best then return nil, "No move" end

    if preventRepetition then
        local pok, safe = pcall(findBestAvoidingRepetition, fen, ucis, t, 10, res)
        if pok and type(safe) == "table" and safe.best then
            res = safe
        end
    end

    return res, nil
end

local ARROW_COLOR = Color3.fromRGB(255, 80, 80)
local PROMO = { q = 5, r = 4, b = 3, n = 2 }

local function drawArrow(uci)
    ensureBoardSized()
    local from64 = Engine.algToIndex64(string.sub(uci, 1, 2))
    local to64 = Engine.algToIndex64(string.sub(uci, 3, 4))
    if not from64 or not to64 then return false end
    return (pcall(function()
        App.board:setArrow("hint", from64, to64, ARROW_COLOR, 0.3)
    end))
end

local function playMove(uci)
    local session = getSession()
    if not isPlayable(session) then return false, "Not playable" end
    
    local from64 = Engine.algToIndex64(string.sub(uci, 1, 2))
    local to64 = Engine.algToIndex64(string.sub(uci, 3, 4))
    if not from64 or not to64 then return false, "Invalid UCI" end
    
    local promo = PROMO[string.sub(uci, 5, 5)] or 0
    local ok, res = pcall(App.onBoardMove, from64, to64, promo, false)
    if not ok then return false, "Error" end
    return res ~= false, "OK"
end

local function fmtEval(score, mate)
    if mate then return "M" .. math.abs(mate) end
    if not score then return "?" end
    return string.format("%+.2f", score / 100)
end

local function executeSearch(play)
    if isThinking then return end
    isThinking = true
    setStatus("Status: Thinking...")
    task.spawn(function()
        local result, searchErr = runAnalysis()
        if not result then
            setStatus("Status: " .. tostring(searchErr))
            isThinking = false
            return
        end
        local drew = drawArrow(result.best)
        local tag = result.repetitionAvoided and " [no-rep]" or ""
        setStatus((drew and "Suggested: " or "Cannot draw: ") .. result.best
            .. " (" .. fmtEval(result.score, result.mate) .. " d" .. tostring(result.depth) .. ")" .. tag)
        if play then
            local ok2, msg = playMove(result.best)
            if ok2 then
                local s = getSession()
                if s then lastPlayedPly = #s.ucis end
            else
                setStatus("Play failed: " .. tostring(msg))
            end
        end
        isThinking = false
    end)
end

local TICK = 0.1
local acc = 0

RunService.Heartbeat:Connect(function(dt)
    acc += dt
    if acc < TICK then return end
    acc = 0

    local inGame = isInLiveGame()

    if hideTopbarInGame and inGame and not topbarHidden then
        pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", false)
        topbarHidden = true
    elseif (not hideTopbarInGame or not inGame) and topbarHidden then
        pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", true)
        topbarHidden = false
    end

    if autoHideWindowInGame and inGame and not lastInGameState then
        pcall(function() Window:SetVisible(false) end)
    end
    lastInGameState = inGame

    if isThinking then return end
    local session = getSession()
    if not session or not isPlayable(session) then return end
    local ply = #session.ucis

    if not (suggestEnabled or autoPlayEnabled) then return end

    if suggestEnabled and ply ~= lastSuggestedPly then
        lastSuggestedPly = ply
        executeSearch(false)
    end
    if autoPlayEnabled and ply ~= lastPlayedPly then
        lastPlayedPly = ply
        executeSearch(true)
    end
end)

Group:AddToggle("SuggestToggle", {
    Text = "Auto-Suggest Best Move",
    Default = false,
    Callback = function(v)
        suggestEnabled = v
        if v then lastSuggestedPly = -1 end
        if not v then pcall(function() App.board:setArrow("hint", nil) end) end
    end,
})

Group:AddToggle("AutoPlayToggle", {
    Text = "Auto-Play Best Move",
    Default = false,
    Callback = function(v)
        autoPlayEnabled = v
        if v then lastPlayedPly = -1 end
    end,
})

Group:AddToggle("AdaptiveTimeToggle", {
    Text = "Adaptive Time",
    Default = true,
    Callback = function(v) adaptiveTimeEnabled = v end,
})

Group:AddToggle("EngineToggle", {
    Text = "Use VortexBot (boss engine)",
    Default = true,
    Callback = function(v) useVortex = v end,
})

Group:AddToggle("PreventRepToggle", {
    Text = "Prevent Repetition Draw",
    Default = true,
    Callback = function(v) preventRepetition = v end,
})

Group:AddSlider("DepthSlider", {
    Text = "Search Depth Ceiling",
    Default = 40, Min = 1, Max = 64, Rounding = 0,
    Callback = function(v) searchDepth = v end,
})

Group:AddSlider("TimeSlider", {
    Text = "Max Search Time (s)",
    Default = 6.0, Min = 0.1, Max = 15.0, Rounding = 1,
    Callback = function(v) searchTime = v end,
})

Group:AddButton({
    Text = "Find Best Move (Hint)",
    Callback = function() executeSearch(false) end,
})

Group:AddButton({
    Text = "Play Best Move Now",
    Callback = function() executeSearch(true) end,
})

Group:AddButton({
    Text = "Clear Hint Arrow",
    Callback = function() pcall(function() App.board:setArrow("hint", nil) end) end,
})

UnlockGroup:AddToggle("UnlockInvToggle", {
    Text = "Unlock All Inventory",
    Default = false,
    Callback = function(v)
        setUnlock(v == true)
    end,
})

UnlockGroup:AddLabel("Unlock All Inventory")

UnlockGroup:AddButton({
    Text = "Force Refresh Inventory UI",
    Callback = function()
        pcall(App.applyCosmetics)
        refreshPages()
    end,
})

HideGroup:AddToggle("AutoHideWindowOnGameStart", {
    Text = "Hide Window When Game Starts",
    Default = false,
    Callback = function(v) autoHideWindowInGame = v end,
})

HideGroup:AddToggle("HideTopbarInGame", {
    Text = "Hide Roblox Topbar In Game",
    Default = false,
    Callback = function(v) hideTopbarInGame = v end,
})

HideGroup:AddLabel("Topbar restores automatically when the game ends")

ThemeManager:SetLibrary(Window)
SaveManager:SetLibrary(Window)
ThemeManager:SetFolder("RoChessEngine")
SaveManager:SetFolder("RoChessEngine")
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)
ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()
SaveManager:SetAutoSave(true)

setStatus("Status: Ready")

task.spawn(function()
    if not startupEnabled then return end
    local toggle = Library.Toggles and Library.Toggles.UnlockInvToggle
    if toggle and toggle.Value ~= true then
        pcall(function() toggle:SetValue(true) end)
    end
    setUnlock(true)
end)
