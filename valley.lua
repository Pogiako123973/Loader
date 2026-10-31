local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Hub = {
    genv = (getgenv and getgenv()) or _G,
    cleaned = false,
}
if Hub.genv.ByteUnload then
    pcall(Hub.genv.ByteUnload)
end

local LocalPlayer = Players.LocalPlayer
local COH = ReplicatedStorage:WaitForChild("ChickenOrHero")
local Movement = COH:WaitForChild("Movement")
local MovementProfiles = require(Movement:WaitForChild("MovementProfiles"))
local BoostInput = require(Movement:WaitForChild("BoostInput"))
local Game = COH:WaitForChild("Game")
local Session = Game:WaitForChild("Session")
local ContactCatchConfig = require(Game:WaitForChild("ContactCatchConfig"))
local TacklePrediction = require(Game:WaitForChild("TacklePrediction"))
local MeleeEvent = Game:WaitForChild("MeleeEvent")
local RescueConfig = require(Game:WaitForChild("RescueConfig"))
local MapVoteState = Game:WaitForChild("MapVoteState")
local MapVoteEvent = Game:WaitForChild("MapVoteEvent")
local RESCUE_RANGE = math.max(3, tonumber(RescueConfig.Range) or 6) - 0.25
local RESCUE_HOLD = math.max(0.1, tonumber(RescueConfig.HoldSeconds) or 1.2)
local RESCUE_FINISH_GRACE = math.max(0.1, tonumber(RescueConfig.FinishGrace) or 0.5)
local RescueEvent = Game:WaitForChild("RescueEvent")
local Gear = COH:WaitForChild("Gear")
local GearCatalog = require(Gear:WaitForChild("GearCatalog"))
local Weapons = COH:WaitForChild("Weapons")
local SkinCatalog = require(Weapons:WaitForChild("SkinCatalog"))
local StorefrontClient = require(Weapons:WaitForChild("StorefrontClient"))
local KnifeClips = require(Weapons:WaitForChild("KnifeClips"))
local successDual, DualWield = pcall(require, Weapons:WaitForChild("DualWield"))
local ArmoryEvent = COH:WaitForChild("Weapons"):WaitForChild("ArmoryEvent")
local SpinWheelEvent = COH:WaitForChild("SpinWheelEvent")
local JourneyConfig = require(COH:WaitForChild("Progression"):WaitForChild("JourneyConfig"))
local JourneyEvent = COH:WaitForChild("Progression"):WaitForChild("JourneyEvent")
local PlayerPreferences = COH:WaitForChild("Game"):WaitForChild("PlayerPreferences")
local Presentation = COH:WaitForChild("Presentation")
local HudNavigation = require(Presentation:WaitForChild("HudNavigation"))

local SETTINGS = {
    notifications = true,
    runnerEnabled = true,
    strategy = "Hero",
    customSpeed = false,
    speedMultiplier = 1.0,
    autoGems = true,
    autoCandy = true,
    gemScanInterval = 0.25,
    gemMaxDistance = 220,
    gemCollectDistance = 3.1,
    autoRevive = true,
    reviveBeforeGems = true,
    reviveMaxDistance = 220,
    avoidCatchers = true,
    predictionTime = 0.65,
    avoidStrength = 2.2,
    panicDistance = 15,
    safezoneDepthRatio = 0.52,
    safezoneValidationRatio = 0.44,
    safezoneEdgeMargin = 4.5,
    edgeRayHeight = 12,
    edgeRayDepth = 52,
    edgeLookAhead = 14,
    edgeSecondLookAhead = 28,
    autoDash = true,
    dashCooldown = 0.85,
    dashDistance = 48,
    dashClosingSpeed = 10,
    smoothMovement = true,
    turnRate = 9,
    emergencySafeZone = true,
    showThreats = true,
    showGoal = true,
    corridorEnabled = true,
    corridorMinWidth = 4.25,
    corridorCenterRange = 26,
    corridorLockTime = 1.65,
    corridorPassDistance = 20,
    corridorApproachDistance = 60,
    sideGapEnabled = true,
    sideGapAngles = {18, 30, 42, 54, 68, 82},
    sideGapMinClearance = 3.5,
    sideGapCommitTime = 0.8,
    sideGapForwardBias = 6.5,

    catcherChase = true,
    catcherCustomSpeed = false,
    catcherSpeedMultiplier = 1.0,
    catcherPrediction = 0.45,
    catcherSmoothing = 6,
    smartPriority = true,
    catcherAttackPriority = "Smart",
    autoTackle = true,
    tackleRange = 8.5,
    tackleCooldown = 1.1,
    autoMelee = true,
    meleeRange = 7.5,
    meleeCooldown = 0.85,
    smoothTurn = true,
    turnRateCatcher = 14,
    followTarget = true,

    showHitboxes = true,
    showGoalUtility = true,
    showThreatUtility = false,
    showDebugUI = false,
    showPath = true,
    cameraFollow = true,
    cameraResponse = 0.25,
    autoSpinWheel = false,
    wheelSpinInterval = 6,
    wheelMinimumCredits = 1,
    wheelAnnounce = true,
    autoClaimJourneyRewards = false,
    journeyClaimAnnounce = true,
    autoMapVote = false,
    mapVoteAnnounce = true,
    mapVoteSelections = {},
    disableBuiltinAFK = false,
}

local function notify(title, content, duration)
    if SETTINGS.notifications == false then
        return
    end
    task.spawn(function()
        local timeout = os.clock() + 3
        while not getgenv().Window and os.clock() < timeout do
            task.wait(0.1)
        end
        
        if getgenv().Window and getgenv().Window.Notify then
            pcall(function()
                getgenv().Window:Notify({
                    Title = title or "Byte",
                    Content = content or "",
                    Duration = duration or 3,
                })
            end)
        elseif Library and Library.Notify then
            pcall(function()
                Library:Notify(title or "Byte", content or "", duration or 3)
            end)
        else
            pcall(function()
                StarterGui:SetCore("SendNotification", {
                    Title = title or "Byte",
                    Text = content or "",
                    Duration = duration or 3,
                })
            end)
        end
    end)
end

local runtime = {
    profile = nil,
    profileRole = nil,
    runnerTick = 0,
    runnerPlanAt = -math.huge,
    runnerPlanDirection = Vector3.zero,
    runnerPlanGoal = Vector3.zero,
    catcherTick = 0,
    utilityTick = 0,
    lastMove = os.clock(),
    lastMovePosition = nil,
    moveCommandAt = -math.huge,
    stuck = false,
    path = Vector3.zero,
    goal = nil,
    goalMode = "SafeZone",
    goalSide = nil,
    assistMode = nil,
    assistTarget = nil,
    assistSince = -math.huge,
    gemTarget = nil,
    gemIgnored = {},
    gemScanAt = -math.huge,
    reviveTarget = nil,
    reviveStarted = false,
    reviveStartAt = 0,
    reviveInputToken = 0,
    catchers = {},
    catcherCacheAt = 0,
    threats = {},
    threatAt = 0,
    threatHistory = {},
    dashAt = -math.huge,
    dashStatus = "idle",
    dashLastRequestAt = -math.huge,
    dashLastCount = nil,
    ping = 0,
    pingAt = 0,
    armory = {loaded = false, abilities = {}},
    armoryAt = -math.huge,
    catcherTargets = {},
    catcherTargetAt = 0,
    catcherTarget = nil,
    edgeRisk = false,
    edgeDirection = Vector3.zero,
    catcherPath = Vector3.zero,
    catcherVelocity = {},
    meleeId = 0,
    lastMelee = -math.huge,
    lastTackle = -math.huge,
    mapCacheAt = -math.huge,
    mapCache = nil,
    edgeCheckAt = -math.huge,
    edgeCheckPosition = nil,
    edgeCheckDirection = Vector3.zero,
    edgeCheckGoal = Vector3.zero,
    edgeRecoveryAt = -math.huge,
    edgeRecoveryDirection = Vector3.zero,
    edgeRecoveryUntil = -math.huge,
    stuckRecoveryUntil = -math.huge,
    stuckRecoveryDirection = Vector3.zero,
    safeCheckAt = -math.huge,
    safeCheckPosition = nil,
    safeCheckA = false,
    safeCheckB = false,
    routeActive = false,
    routeComplete = false,
    routeStartSide = nil,
    routeTargetSide = nil,
    routeCompletePosition = nil,
    routeCompleteAt = -math.huge,
    corridorActive = false,
    corridorGoal = Vector3.zero,
    corridorCenter = Vector3.zero,
    corridorAxis = Vector3.zero,
    corridorGapWidth = 0,
    corridorStartedAt = -math.huge,
    sideGapDirection = Vector3.zero,
    sideGapUntil = -math.huge,
    sideGapReason = "",
    wheelScanAt = -math.huge,
    wheelActionAt = -math.huge,
    wheelStatus = "disabled",
    wheelLastButton = nil,
    wheelSpinCount = 0,
    wheelCredits = 0,
    wheelNextFreeAt = 0,
    wheelPurchasesAvailable = false,
    wheelDiscountAvailable = false,
    wheelStateRequestAt = -math.huge,
    wheelSpinRequestAt = -math.huge,
    wheelEventReady = false,
    wheelSpinning = false,
    wheelLastStateAt = -math.huge,
    wheelStatusAt = -math.huge,
    wheelNextAttemptAt = -math.huge,
    wheelMinimumCredits = 1,
    afkOverrideStatus = "disabled",
    afkOverrideLastRequestAt = -math.huge,
    afkOverrideRequestInterval = 2.0,
    afkOverrideInLobby = false,
    afkOverrideRequestCount = 0,
    journeyScanAt = -math.huge,
    journeyStatus = "disabled",
    journeyClaimCount = 0,
    journeyLastClaimAt = -math.huge,
    journeyClaimedButtons = {},
    journeyLoaded = false,
    journeySeasonId = nil,
    journeyRequestAt = -math.huge,
    journeyClaimInFlight = false,
    journeyLastStateAt = -math.huge,
    journeyTier = 1,
    journeyPremium = false,
    journeyClaims = {},
    journeyLastClaimResultAt = -math.huge,
    mapVoteScanAt = -math.huge,
    mapVoteStatus = "disabled",
    mapVoteOptions = {},
    mapVoteLastActionAt = -math.huge,
    mapVoteOpen = false,
    mapVotePhase = "Waiting",
    mapVoteToken = nil,
    mapVoteOptionIds = {},
    mapVoteLastStateAt = -math.huge,
    debugLastError = nil,
    debugLastErrorAt = -math.huge,
    debugEnabled = false,
    debugGui = nil,
    debugLabel = nil,
    debugPanelAt = -math.huge,
    journeyNextClaimAt = -math.huge,
    journeyManualPending = false,
}

local safezone = {
    map = nil,
    a = nil,
    b = nil,
    cached = false,
}

local visuals = {
    goal = nil,
    threats = {},
    hitboxes = {},
}

local pathVisual = {
    beam = nil,
    startAtt = nil,
    endAtt = nil,
    endPart = nil,
    character = nil,
}

local function clearPathVisual()
    if pathVisual.beam then pcall(function() pathVisual.beam:Destroy() end) end
    if pathVisual.endPart then pcall(function() pathVisual.endPart:Destroy() end) end
    pathVisual.beam = nil
    pathVisual.startAtt = nil
    pathVisual.endAtt = nil
    pathVisual.endPart = nil
    pathVisual.character = nil
end

local function ensurePathVisual()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        if pathVisual.beam then pathVisual.beam.Enabled = false end
        return false
    end

    if pathVisual.character ~= char or not pathVisual.beam or not pathVisual.beam.Parent then
        clearPathVisual()

        local startAtt = Instance.new("Attachment")
        startAtt.Name = "BytePathStart"
        startAtt.Position = Vector3.new(0, -2, 0)
        startAtt.Parent = root

        local endPart = Instance.new("Part")
        endPart.Name = "BytePathEnd"
        endPart.Anchored = true
        endPart.CanCollide = false
        endPart.CanQuery = false
        endPart.CanTouch = false
        endPart.CastShadow = false
        endPart.Transparency = 1
        endPart.Size = Vector3.new(0.2, 0.2, 0.2)
        endPart.Parent = workspace

        local endAtt = Instance.new("Attachment")
        endAtt.Name = "BytePathEndAtt"
        endAtt.Parent = endPart

        local beam = Instance.new("Beam")
        beam.Name = "BytePathBeam"
        beam.Attachment0 = startAtt
        beam.Attachment1 = endAtt
        beam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 128))
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.Width0 = 0.45
        beam.Width1 = 0.12
        beam.FaceCamera = true
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(0.65, 0.35),
            NumberSequenceKeypoint.new(1, 1),
        })
        beam.Segments = 6
        beam.Parent = startAtt

        pathVisual.beam = beam
        pathVisual.startAtt = startAtt
        pathVisual.endAtt = endAtt
        pathVisual.endPart = endPart
        pathVisual.character = char
    end

    return true
end

local function updatePathVisual()
    if not SETTINGS.showPath then
        if pathVisual.beam then pathVisual.beam.Enabled = false end
        return
    end

    local lp = Players.LocalPlayer
    if lp:GetAttribute("InMatch") ~= true
        or (lp:GetAttribute("GameRole") or "Lobby") ~= "Runner"
        or (lp:GetAttribute("RunState") or "Idle") ~= "Active"
        or not SETTINGS.runnerEnabled then
        if pathVisual.beam then pathVisual.beam.Enabled = false end
        return
    end

    if not ensurePathVisual() then return end

    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local startX = root.Position.X
    local startY = root.Position.Y - 2
    local startZ = root.Position.Z

    -- Prefer the real goal point (safe zone deep point).
    -- If none (e.g. route just completed or assist mode), fall back to a medium-length direction line.
    local targetX, targetZ
    local goal = runtime.goal
    if goal then
        targetX = goal.X
        targetZ = goal.Z
    else
        local path = runtime.path
        if path.Magnitude < 0.05 then
            pathVisual.beam.Enabled = false
            return
        end
        local dir = path.Unit
        targetX = startX + dir.X * 30
        targetZ = startZ + dir.Z * 30
    end

    local dx = targetX - startX
    local dz = targetZ - startZ
    local length = math.sqrt(dx * dx + dz * dz)
    if length < 1 then
        pathVisual.beam.Enabled = false
        return
    end

    pathVisual.beam.Enabled = true

    local endWorld = Vector3.new(targetX, startY, targetZ)
    pathVisual.endPart.CFrame = CFrame.new(endWorld)

    local color
    if runtime.goalMode == "Gem" then
        color = Color3.fromRGB(255, 200, 50)
    elseif runtime.goalMode == "Revive" then
        color = Color3.fromRGB(80, 160, 255)
    else
        color = Color3.fromRGB(0, 255, 128)
    end
    pathVisual.beam.Color = ColorSequence.new(color)
end

local MAP_VOTE_SLOT_IDS = {"Map 1", "Map 2", "Map 3"}

local TACKLE_VARIANT_REACH = {
    ["Short Dive"] = 4.5,
    ["Medium Dive"] = 5.5,
    ["Long Dive"] = 6.5,
}

local function tackleVariantReach(character)
    if not character then return 4 end
    local variant = character:GetAttribute("TackleVariant")
    if type(variant) == "string" and TACKLE_VARIANT_REACH[variant] then
        return TACKLE_VARIANT_REACH[variant]
    end
    return 4
end

local function flat(v)
    return Vector3.new(v.X, 0, v.Z)
end

local function getCharacter(player)
    return (player or LocalPlayer).Character
end

local function getHumanoid(player)
    local c = getCharacter(player)
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

local function getRoot(player)
    local c = getCharacter(player)
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function getRole()
    return LocalPlayer:GetAttribute("GameRole") or "Lobby"
end

local function getRunState()
    return LocalPlayer:GetAttribute("RunState") or "Idle"
end

local function isRunnerActive()
    if LocalPlayer:GetAttribute("InMatch") ~= true then return false end
    if getRole() ~= "Runner" then return false end
    return getRunState() == "Active"
end

local function isCatcherActive()
    if LocalPlayer:GetAttribute("InMatch") ~= true then return false end
    if getRole() ~= "Catcher" then return false end
    return getRunState() == "Active"
end

local function canMove()
    if LocalPlayer:GetAttribute("ClientReady") ~= true then return false end
    if Session:GetAttribute("GlobalPaused") == true then return false end
    if Session:GetAttribute("MapChanging") == true then return false end
    local c = getCharacter()
    if not c then return false end
    if c:GetAttribute("Ragdolled") == true then return false end
    if c:GetAttribute("GearMotion") == true then return false end
    if c:GetAttribute("MovementLocked") == true then return false end
    local h = getHumanoid()
    if not h or h.Health <= 0 then return false end
    if h.PlatformStand or h.Sit then return false end
    return true
end

local function getBaseSpeed(role)
    role = role or getRole()
    if runtime.profile and runtime.profileRole == role then
        return runtime.profile.MaxSpeed or 16
    end
    local ok, profile = pcall(MovementProfiles.get, role, LocalPlayer)
    if ok and profile then
        runtime.profile = profile
        runtime.profileRole = role
        return profile.MaxSpeed or 16
    end
    return 16
end

local function getRunnerSpeed()
    local speed = math.max(getBaseSpeed("Runner"), 1)
    if SETTINGS.customSpeed then
        speed *= math.clamp(SETTINGS.speedMultiplier, 1, 2)
    end
    return speed
end

local function getCatcherSpeed()
    local speed = math.max(getBaseSpeed("Catcher"), 1)
    if SETTINGS.catcherCustomSpeed then
        speed *= math.clamp(SETTINGS.catcherSpeedMultiplier, 1, 2)
    end
    return speed
end

local function restoreNativeWalkSpeed()
    local hum = getHumanoid()
    local character = getCharacter()
    if not hum or not character then return end
    local native = tonumber(character:GetAttribute("MovementSpeed"))
    if native and native > 0 then
        hum.WalkSpeed = native
    end
end

local function refreshPing(now)
    if now - runtime.pingAt < 0.5 then return end
    runtime.pingAt = now
    local value = 0
    pcall(function()
        value = LocalPlayer:GetNetworkPing() * 0.5
    end)
    runtime.ping = math.max(value, 0)
end

local function getMap()
    local now = os.clock()
    if now - runtime.mapCacheAt < 0.35 then
        return runtime.mapCache
    end
    runtime.mapCacheAt = now
    local handle = Game:FindFirstChild("ActiveMap")
    if handle and handle:IsA("ObjectValue") and handle.Value and handle.Value:IsDescendantOf(workspace) then
        runtime.mapCache = handle.Value
        return runtime.mapCache
    end
    local found = nil
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:FindFirstChild("Field") then
            found = obj
            break
        end
    end
    runtime.mapCache = found
    return found
end

local edgeRayCache = {
    map = nil,
    field = nil,
    invisWall = nil,
    params = nil,
    wallParams = nil,
}

local function resolveActiveField(map)
    if not map then return nil end
    local field = map:FindFirstChild("Field")
    if field then return field end
    return map:FindFirstChild("Field", true)
end

local function resolveActiveInvisWall(field)
    if not field then return nil end
    return field:FindFirstChild("InvisWall", true)
end

local function refreshEdgeRayCache()
    local map = getMap()
    local field = resolveActiveField(map)
    local wall = resolveActiveInvisWall(field)
    local include = field or map
    if edgeRayCache.map == map and edgeRayCache.field == field and edgeRayCache.invisWall == wall and edgeRayCache.params then
        return
    end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = include and {include} or {}
    params.IgnoreWater = true
    edgeRayCache.map = map
    edgeRayCache.field = field
    edgeRayCache.invisWall = wall
    edgeRayCache.params = params
    edgeRayCache.wallParams = nil
end

local function getEdgeRayParams()
    refreshEdgeRayCache()
    return edgeRayCache.params
end

local function getInvisWallParams()
    refreshEdgeRayCache()
    local wall = edgeRayCache.invisWall
    if not wall or not wall:IsDescendantOf(workspace) then
        edgeRayCache.invisWall = nil
        edgeRayCache.wallParams = nil
        return nil
    end
    if edgeRayCache.wallParams then return edgeRayCache.wallParams end
    local wallParams = RaycastParams.new()
    wallParams.FilterType = Enum.RaycastFilterType.Include
    wallParams.FilterDescendantsInstances = {wall}
    wallParams.IgnoreWater = true
    edgeRayCache.wallParams = wallParams
    return wallParams
end

local function invisWallHit(position, direction, distance)
    local dir = flat(direction)
    if dir.Magnitude < 0.05 then return nil end
    local params = getInvisWallParams()
    if not params then return nil end
    dir = dir.Unit
    local origin = Vector3.new(position.X, position.Y + 2.5, position.Z)
    return workspace:Raycast(origin, dir * distance, params)
end

local function floorRay(point, y)
    local map = getMap()
    if not map then return true end
    local params = getEdgeRayParams()
    if not params or #params.FilterDescendantsInstances == 0 then return false end
    local origin = Vector3.new(point.X, math.max(y + 12, point.Y + 10), point.Z)
    local direction = Vector3.new(0, -(SETTINGS.edgeRayHeight + SETTINGS.edgeRayDepth), 0)
    local hit = workspace:Raycast(origin, direction, params)
    return hit ~= nil and hit.Normal.Y >= 0.35
end

local function hasFloorAt(point, y)
    return floorRay(point, y)
end

local function getPlayfieldCenter()
    if safezone.a and safezone.b then return (safezone.a.center + safezone.b.center) * 0.5 end
    if safezone.a then return safezone.a.center end
    if safezone.b then return safezone.b.center end
    return nil
end

local function groundSupportScore(position, direction, y)
    local dir = flat(direction)
    if dir.Magnitude < 0.05 then return 0 end
    dir = dir.Unit
    local side = Vector3.new(-dir.Z, 0, dir.X)
    local score = 0
    if hasFloorAt(position + dir * 6, y) then score += 2 end
    if hasFloorAt(position + dir * 14, y) then score += 2 end
    if hasFloorAt(position + dir * 24, y) then score += 1 end
    if hasFloorAt(position + dir * 14 + side * 3, y) then score += 1 end
    if hasFloorAt(position + dir * 14 - side * 3, y) then score += 1 end
    return score
end

local function boundaryInwardDirection(position, y)
    local dirs = {Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)}
    local outward = Vector3.zero
    local missing = 0
    for _, dir in ipairs(dirs) do
        local wallHit = invisWallHit(position, dir, 9)
        if wallHit or not hasFloorAt(position + dir * 7, y) then
            outward += dir
            missing += 1
        end
    end
    if missing == 0 or outward.Magnitude < 0.05 then return Vector3.zero end
    local inward = flat(-outward)
    if inward.Magnitude < 0.05 then return Vector3.zero end
    inward = inward.Unit
    if groundSupportScore(position, inward, y) < 3 then return Vector3.zero end
    return inward
end

local function edgeDirectionClear(position, direction, y, distance)
    local dir = flat(direction)
    if dir.Magnitude < 0.05 then return false end
    dir = dir.Unit
    if invisWallHit(position, dir, math.max(8, distance)) then return false end
    local score = groundSupportScore(position, dir, y)
    if distance <= 14 then return score >= 4 end
    return score >= 5
end

local function edgeRiskForDirection(position, direction, y)
    local dir = flat(direction)
    if dir.Magnitude < 0.05 then return true end
    dir = dir.Unit
    return not edgeDirectionClear(position, dir, y, SETTINGS.edgeLookAhead)
        or not edgeDirectionClear(position, dir, y, SETTINGS.edgeSecondLookAhead)
end

local function rotateEdge(dir, angle)
    local r = math.rad(angle)
    local c = math.cos(r)
    local s = math.sin(r)
    return Vector3.new(dir.X * c - dir.Z * s, 0, dir.X * s + dir.Z * c)
end

local function chooseEdgeDirection(position, desired, goal, y)
    local dir = flat(desired)
    if dir.Magnitude < 0.05 then return Vector3.zero, false end
    dir = dir.Unit
    local now = os.clock()
    if runtime.edgeCheckPosition and runtime.edgeCheckDirection.Magnitude > 0.05
        and now - runtime.edgeCheckAt < 0.055
        and flat(position - runtime.edgeCheckPosition).Magnitude < 2.5
        and runtime.edgeCheckDirection:Dot(dir) > 0.96
        and runtime.edgeCheckGoal.Magnitude > 0.05
        and flat(goal - runtime.edgeCheckGoal).Magnitude < 8 then
        return runtime.edgeDirection, runtime.edgeRisk
    end
    local boundary = boundaryInwardDirection(position, y)
    local desiredRisk = edgeRiskForDirection(position, dir, y)
    local nearBoundary = boundary.Magnitude > 0.05 and boundary:Dot(dir) < 0.35
    runtime.edgeCheckAt = now
    runtime.edgeCheckPosition = position
    runtime.edgeCheckDirection = dir
    runtime.edgeCheckGoal = flat(goal)
    if not desiredRisk and not nearBoundary then
        runtime.edgeDirection = dir
        runtime.edgeRisk = false
        return dir, false
    end
    local toGoal = flat(goal - position)
    if toGoal.Magnitude < 0.05 then toGoal = dir else toGoal = toGoal.Unit end
    local inward = boundary
    if inward.Magnitude < 0.05 then
        local center = getPlayfieldCenter()
        if center then
            inward = flat(center - position)
            if inward.Magnitude > 0.05 then inward = inward.Unit end
        end
    end
    local candidates = {}
    local function addCandidate(v)
        v = flat(v)
        if v.Magnitude < 0.05 then return end
        v = v.Unit
        for _, item in ipairs(candidates) do
            if item:Dot(v) > 0.985 then return end
        end
        candidates[#candidates + 1] = v
    end
    addCandidate(inward)
    addCandidate(toGoal)
    addCandidate(dir)
    local base = inward.Magnitude > 0.05 and inward or dir
    for _, angle in ipairs({-35, 35, -70, 70, 90, -90, 135, -135, 180}) do
        addCandidate(rotateEdge(base, angle))
    end
    local best = nil
    local bestScore = -math.huge
    for _, candidate in ipairs(candidates) do
        local support = groundSupportScore(position, candidate, y)
        if support >= 6 then
            local score = support * 4.5 + candidate:Dot(toGoal) * 5
            if inward.Magnitude > 0.05 then
                score += candidate:Dot(inward) * (nearBoundary and 10 or 5)
            end
            if candidate:Dot(dir) > 0 then score += 2 end
            if score > bestScore then
                bestScore = score
                best = candidate
            end
        end
    end
    if best then
        runtime.edgeDirection = best
        runtime.edgeRisk = true
        runtime.edgeRecoveryAt = now
        return best, true
    end
    if inward.Magnitude > 0.05 then
        runtime.edgeDirection = inward
        runtime.edgeRisk = true
        runtime.edgeRecoveryAt = now
        return inward, true
    end
    runtime.edgeDirection = -dir
    runtime.edgeRisk = true
    runtime.edgeRecoveryAt = now
    return -dir, true
end

local function findZone(parent, names)
    for _, name in ipairs(names) do
        local direct = parent:FindFirstChild(name)
        if direct then return direct end
    end
    for _, obj in ipairs(parent:GetDescendants()) do
        local lower = obj.Name:lower()
        for _, name in ipairs(names) do
            if lower == name:lower() then return obj end
        end
    end
    return nil
end

local function getBounds(instance)
    if not instance then return nil end
    local minP = Vector3.new(math.huge, math.huge, math.huge)
    local maxP = Vector3.new(-math.huge, -math.huge, -math.huge)
    local found = false
    local function add(part)
        local p = part.Position
        local h = part.Size * 0.5
        minP = Vector3.new(math.min(minP.X, p.X - h.X), math.min(minP.Y, p.Y - h.Y), math.min(minP.Z, p.Z - h.Z))
        maxP = Vector3.new(math.max(maxP.X, p.X + h.X), math.max(maxP.Y, p.Y + h.Y), math.max(maxP.Z, p.Z + h.Z))
        found = true
    end
    if instance:IsA("BasePart") then add(instance) end
    for _, obj in ipairs(instance:GetDescendants()) do
        if obj:IsA("BasePart") then add(obj) end
    end
    if not found then return nil end
    return minP, maxP
end

local function buildZone(instance)
    local minP, maxP = getBounds(instance)
    if not minP then return nil end
    return {
        instance = instance,
        name = instance.Name,
        min = minP,
        max = maxP,
        center = (minP + maxP) * 0.5,
    }
end

local function refreshSafezones()
    local map = getMap()
    if safezone.cached and safezone.map == map
        and safezone.a and safezone.b
        and safezone.a.instance and safezone.a.instance.Parent
        and safezone.b.instance and safezone.b.instance.Parent then
        return
    end
    safezone.map = map
    safezone.a = nil
    safezone.b = nil
    safezone.cached = true
    local field = map and map:FindFirstChild("Field")
    if not field then return end
    local a = findZone(field, {"SafezoneASide", "SafeZoneASide"})
    local b = findZone(field, {"SafezoneBSide", "SafeZoneBSide"})
    safezone.a = buildZone(a)
    safezone.b = buildZone(b)
end

local function inZone(position, zone)
    if not zone then return false end
    return position.X >= zone.min.X and position.X <= zone.max.X
        and position.Z >= zone.min.Z and position.Z <= zone.max.Z
        and position.Y >= zone.min.Y - 8 and position.Y <= zone.max.Y + 8
end

local function currentZone(position)
    if inZone(position, safezone.a) then return safezone.a end
    if inZone(position, safezone.b) then return safezone.b end
    return nil
end

local function zoneInwardDirection(zone, other)
    if not zone then return Vector3.zero end
    local delta = other and flat(zone.center - other.center) or Vector3.zero
    if delta.Magnitude > 0.05 then
        if math.abs(delta.X) >= math.abs(delta.Z) then
            return Vector3.new(delta.X >= 0 and 1 or -1, 0, 0)
        end
        return Vector3.new(0, 0, delta.Z >= 0 and 1 or -1)
    end
    if zone.instance and zone.instance:IsA("BasePart") then
        local look = flat(zone.instance.CFrame.LookVector)
        if look.Magnitude > 0.05 then
            if math.abs(look.X) >= math.abs(look.Z) then
                return Vector3.new(look.X >= 0 and 1 or -1, 0, 0)
            end
            return Vector3.new(0, 0, look.Z >= 0 and 1 or -1)
        end
    end
    return Vector3.zero
end

local function zoneAxisHalfExtent(zone, inward)
    if not zone then return 0 end
    local size = zone.max - zone.min
    if math.abs(inward.X) >= math.abs(inward.Z) then return math.abs(size.X) * 0.5 end
    return math.abs(size.Z) * 0.5
end

local function zoneDeepPoint(zone, other, y)
    if not zone then return nil end
    local inward = zoneInwardDirection(zone, other)
    local half = zoneAxisHalfExtent(zone, inward)
    local edgeMargin = math.min(SETTINGS.safezoneEdgeMargin, math.max(0, half - 0.75))
    local depth = math.min(math.max(0, half - edgeMargin), half * SETTINGS.safezoneDepthRatio)
    local xMargin = math.min(edgeMargin, math.max(0, (zone.max.X - zone.min.X) * 0.5 - 0.75))
    local zMargin = math.min(edgeMargin, math.max(0, (zone.max.Z - zone.min.Z) * 0.5 - 0.75))
    local ratios = {SETTINGS.safezoneDepthRatio, 0.46, 0.40, 0.34}
    for _, ratio in ipairs(ratios) do
        local candidateDepth = math.min(math.max(0, half - edgeMargin), half * ratio)
        local point = zone.center + inward * candidateDepth
        point = Vector3.new(
            math.clamp(point.X, zone.min.X + xMargin, zone.max.X - xMargin),
            y,
            math.clamp(point.Z, zone.min.Z + zMargin, zone.max.Z - zMargin)
        )
        if edgeDirectionClear(point, inward, y, 6) and edgeDirectionClear(point, -inward, y, 4) then
            return point
        end
    end
    local point = zone.center + inward * depth
    return Vector3.new(
        math.clamp(point.X, zone.min.X + xMargin, zone.max.X - xMargin),
        y,
        math.clamp(point.Z, zone.min.Z + zMargin, zone.max.Z - zMargin)
    )
end

local function inValidatedZone(position, zone, other)
    if not zone or not inZone(position, zone) then return false end
    local inward = zoneInwardDirection(zone, other)
    if inward.Magnitude < 0.05 then return false end
    local half = zoneAxisHalfExtent(zone, inward)
    local margin = math.min(SETTINGS.safezoneEdgeMargin, math.max(0, half - 0.75))
    local xOk = position.X >= zone.min.X + margin and position.X <= zone.max.X - margin
    local zOk = position.Z >= zone.min.Z + margin and position.Z <= zone.max.Z - margin
    if not xOk or not zOk then return false end
    local depth = flat(position - zone.center):Dot(inward)
    local required = math.min(math.max(0, half - margin), half * SETTINGS.safezoneValidationRatio)
    return depth >= required and hasFloorAt(position, position.Y)
end

local function zoneCenter(zone, y)
    if not zone then return nil end
    return Vector3.new(zone.center.X, y, zone.center.Z)
end

local function detectRoundStartZone(position, a, b)
    local inA = inZone(position, a)
    local inB = inZone(position, b)
    if inA and not inB then return a end
    if inB and not inA then return b end
    local da = flat(position - a.center).Magnitude
    local db = flat(position - b.center).Magnitude
    return da <= db and a or b
end

local function beginRunnerRound(position)
    refreshSafezones()
    local a = safezone.a
    local b = safezone.b
    if not a or not b then
        runtime.routeActive = false
        runtime.routeComplete = false
        runtime.routeStartSide = nil
        runtime.routeTargetSide = nil
        runtime.routeCompletePosition = nil
        runtime.routeCompleteAt = -math.huge
        runtime.goalSide = nil
        runtime.goal = nil
        return nil, nil
    end
    local start = detectRoundStartZone(position, a, b)
    local target = start == a and b or a
    runtime.routeActive = true
    runtime.routeComplete = false
    runtime.routeStartSide = start.name
    runtime.routeTargetSide = target.name
    runtime.routeCompletePosition = nil
    runtime.routeCompleteAt = -math.huge
    runtime.goalSide = target.name
    runtime.goal = zoneDeepPoint(target, start, position.Y) or zoneCenter(target, position.Y)
    runtime.safeCheckAt = -math.huge
    runtime.safeCheckPosition = nil
    return runtime.goal, target
end

local function chooseSafeGoal(position)
    refreshSafezones()
    local a = safezone.a
    local b = safezone.b
    if not a or not b then
        runtime.goal = nil
        runtime.goalSide = nil
        runtime.routeActive = false
        runtime.routeComplete = false
        runtime.routeStartSide = nil
        runtime.routeTargetSide = nil
        runtime.routeCompletePosition = nil
        runtime.routeCompleteAt = -math.huge
        return nil, nil
    end
    if not runtime.routeActive or not runtime.routeTargetSide then
        return beginRunnerRound(position)
    end
    if runtime.routeComplete then return nil, nil end
    local now = os.clock()
    if not runtime.safeCheckPosition
        or now - runtime.safeCheckAt >= 0.08
        or flat(position - runtime.safeCheckPosition).Magnitude >= 2.0 then
        runtime.safeCheckAt = now
        runtime.safeCheckPosition = position
        runtime.safeCheckA = inValidatedZone(position, a, b)
        runtime.safeCheckB = inValidatedZone(position, b, a)
    end
    local target = runtime.routeTargetSide == a.name and a or b
    local other = target == a and b or a
    if (target == a and runtime.safeCheckA) or (target == b and runtime.safeCheckB) then
        runtime.routeComplete = true
        runtime.routeCompletePosition = position
        runtime.routeCompleteAt = now
        runtime.goal = nil
        runtime.goalSide = target.name
        return nil, target
    end
    runtime.goalSide = target.name
    if not runtime.goal then
        runtime.goal = zoneDeepPoint(target, other, position.Y) or zoneCenter(target, position.Y)
    else
        runtime.goal = Vector3.new(runtime.goal.X, position.Y, runtime.goal.Z)
    end
    return runtime.goal, target
end

local function getSafeFallback(position)
    refreshSafezones()
    local a = safezone.a
    local b = safezone.b
    if not a or not b then return nil end
    local target
    if runtime.routeTargetSide == a.name then target = a
    elseif runtime.routeTargetSide == b.name then target = b
    elseif runtime.goalSide == a.name then target = a
    elseif runtime.goalSide == b.name then target = b
    elseif inZone(position, a) and not inZone(position, b) then target = b
    elseif inZone(position, b) and not inZone(position, a) then target = a
    else target = b end
    return zoneDeepPoint(target, target == a and b or a, position.Y) or zoneCenter(target, position.Y)
end

local function isGemObject(obj)
    if not obj:IsA("BasePart") then return false end
    return obj.Name:sub(1, 4) == "Gem_"
end

local function isCandyObject(obj)
    if not obj:IsA("BasePart") then return false end
    return obj.Name:sub(1, 6) == "Candy_"
end

local function refreshGems(now, position)
    if now - runtime.gemScanAt < SETTINGS.gemScanInterval then return end
    runtime.gemScanAt = now
    local best, bestDistance
    local folders = {"LocalRunnerGems"}
    if SETTINGS.autoCandy then
        table.insert(folders, "LocalRunnerCandyCorn")
    end
    for _, folderName in ipairs(folders) do
        local folder = workspace:FindFirstChild(folderName)
        if folder then
            for _, obj in ipairs(folder:GetChildren()) do
                if obj:IsA("BasePart") and obj.Parent then
                    local d = flat(obj.Position - position).Magnitude
                    local vertical = math.abs(obj.Position.Y - position.Y)
                    local ignored = runtime.gemIgnored[obj]
                    if d <= SETTINGS.gemMaxDistance and vertical <= 5
                        and (not ignored or now >= ignored) then
                        if not bestDistance or d < bestDistance then
                            best = obj
                            bestDistance = d
                        end
                    end
                end
            end
        end
    end
    runtime.gemTarget = best
end

local function findDownedPlayer(position)
    local best, bestDistance
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Parent then
            local c = player.Character
            local root = c and c:FindFirstChild("HumanoidRootPart")
            if root and c:GetAttribute("RescueAvailable") == true and c:GetAttribute("Ragdolled") == true then
                local helper = c:GetAttribute("RescueHelperId")
                if helper == nil or helper == LocalPlayer.UserId then
                    local d = flat(root.Position - position).Magnitude
                    if d <= SETTINGS.reviveMaxDistance and (not bestDistance or d < bestDistance) then
                        best = player
                        bestDistance = d
                    end
                end
            end
        end
    end
    return best
end

local function cancelRevive()
    if runtime.reviveTarget and runtime.reviveStarted then
        pcall(function()
            RescueEvent:FireServer("Cancel", runtime.reviveTarget.UserId)
        end)
    end
    runtime.reviveTarget = nil
    runtime.reviveStarted = false
    runtime.reviveStartAt = 0
end

local function hasReviveLineOfSight(target)
    local myRoot = getRoot()
    local targetRoot = target and getRoot(target)
    if not myRoot or not targetRoot then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {myRoot.Parent, targetRoot.Parent}
    params.RespectCanCollide = true
    pcall(function() params.CollisionGroup = "CoHRunner" end)
    local ok, result = pcall(function()
        return workspace:Raycast(myRoot.Position, targetRoot.Position - myRoot.Position, params)
    end)
    return ok and result == nil
end

local function updateRevive(now, position)
    if not SETTINGS.autoRevive then
        cancelRevive()
        return nil
    end
    local target = runtime.reviveTarget
    local root = target and getRoot(target)
    if not target or not target.Parent or not root or target.Character:GetAttribute("RescueAvailable") ~= true or target.Character:GetAttribute("Ragdolled") ~= true then
        cancelRevive()
        target = nil
    end
    if not target then
        target = findDownedPlayer(position)
        if not target then return nil end
        runtime.reviveTarget = target
    end
    root = getRoot(target)
    if not root then
        cancelRevive()
        return nil
    end
    runtime.goalMode = "Revive"
    local distance = flat(root.Position - position).Magnitude
    if distance > math.max(RESCUE_RANGE, SETTINGS.reviveMaxDistance) then
        cancelRevive()
        return nil
    end
    if distance <= RESCUE_RANGE then
        if not runtime.reviveStarted and now < runtime.reviveStartAt then
            return root.Position
        end
        if hasReviveLineOfSight(target) then
            if not runtime.reviveStarted then
                runtime.reviveStarted = true
                runtime.reviveStartAt = now
                pcall(function()
                    RescueEvent:FireServer("Begin", target.UserId)
                end)
            elseif now - runtime.reviveStartAt >= RESCUE_HOLD then
                pcall(function()
                    RescueEvent:FireServer("Finish", target.UserId)
                end)
                runtime.reviveStarted = false
                runtime.reviveStartAt = now + RESCUE_FINISH_GRACE + 0.5
            end
        end
    else
        if runtime.reviveStarted then cancelRevive() end
    end
    return root.Position
end

local function refreshCatchers(now)
    if now - runtime.catcherCacheAt < 0.12 then return end
    runtime.catcherCacheAt = now
    local list = runtime.catchers
    table.clear(list)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Parent and player:GetAttribute("GameRole") == "Catcher" and player:GetAttribute("RunState") == "Active" then
            local c = player.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if h and h.Health > 0 and r and c:GetAttribute("Ragdolled") ~= true and c:GetAttribute("MovementLocked") ~= true then
                list[#list + 1] = player
            end
        end
    end
end

local function updateThreats(now, position)
    if now - runtime.threatAt < 0.035 then return runtime.threats end 
    runtime.threatAt = now
    table.clear(runtime.threats)
    local runRoot = getRoot()
    local runVelocity = runRoot and flat(runRoot.AssemblyLinearVelocity) or Vector3.zero
    local runSpeed = math.max(getRunnerSpeed(), 1)
    if runVelocity.Magnitude < 3 and runtime.path.Magnitude > 0.05 then
        runVelocity = runtime.path.Unit * runSpeed
    end
    local nowServer = 0
    pcall(function()
        nowServer = workspace:GetServerTimeNow()
    end)
    for _, player in ipairs(runtime.catchers) do
        local root = getRoot(player)
        if root then
            local current = flat(root.Position)
            local offset = current - position
            local distance = offset.Magnitude
            if distance <= 110 then
                local velocity = flat(root.AssemblyLinearVelocity)
                local history = runtime.threatHistory[player]
                if not history then
                    history = {position = current, velocity = velocity, time = now}
                    runtime.threatHistory[player] = history
                end
                local historyDt = now - history.time
                local acceleration = Vector3.zero
                if historyDt > 0.02 and historyDt < 0.2 then
                    acceleration = (velocity - history.velocity) / historyDt
                    if acceleration.Magnitude > 80 then acceleration = acceleration.Unit * 80 end
                end
                history.position = current
                history.velocity = velocity
                history.time = now
                local relative = current - position
                local relativeVelocity = velocity - runVelocity
                local relSpeedSq = relativeVelocity:Dot(relativeVelocity)
                local closestTime = 0
                if relSpeedSq > 0.25 then
                    closestTime = math.clamp(-relative:Dot(relativeVelocity) / relSpeedSq, 0, 1.5)
                end
                local prediction = math.clamp(SETTINGS.predictionTime + runtime.ping * 0.85, 0.28, 1.15)
                local velocityFactor = math.clamp(velocity.Magnitude / math.max(runSpeed, 1), 0.65, 1.25)
                prediction = math.clamp(prediction * velocityFactor, 0.28, 1.15)
                local character = player.Character
                local tackle = character and character:GetAttribute("TackleActive") == true
                local tackleDirection = character and character:GetAttribute("TackleDirection")
                if typeof(tackleDirection) ~= "Vector3" then tackleDirection = Vector3.zero end
                tackleDirection = flat(tackleDirection)
                if tackleDirection.Magnitude < 0.05 then tackleDirection = velocity end
                if tackleDirection.Magnitude < 0.05 then tackleDirection = flat(root.CFrame.LookVector) end
                if tackleDirection.Magnitude > 0.05 then tackleDirection = tackleDirection.Unit end
                if tackle then prediction = math.min(1.8, prediction + 0.35) end
                local relativeFuture = relative + relativeVelocity * prediction + acceleration * (0.5 * prediction * prediction)
                local futureDistance = relativeFuture.Magnitude
                local danger = math.max(8, tonumber(ContactCatchConfig.MinForward) or 0)
                    + math.max(0, tonumber(ContactCatchConfig.HandRadius) or 0)
                    + math.max(0, tonumber(ContactCatchConfig.ContactPadding) or 0)
                    + math.max(0, tonumber(ContactCatchConfig.RunnerRadius) or 0)
                if tackle then
                    danger += 10 + math.min(tackleVariantReach(character), 10)
                elseif velocity.Magnitude > runSpeed * 0.8 then
                    danger += 3
                end
                local closing = 0
                if distance > 0.05 then
                    closing = math.max(0, velocity:Dot(-offset.Unit))
                end
                local timeToDanger = math.huge
                if closing > 0.5 then
                    timeToDanger = math.max(0, (distance - danger) / closing)
                elseif distance <= danger then
                    timeToDanger = 0
                end
                local interceptTime = math.min(closestTime, prediction)
                if timeToDanger < interceptTime then interceptTime = timeToDanger end
                local interceptCatcher = current + velocity * interceptTime + acceleration * (0.5 * interceptTime * interceptTime)
                local interceptRunner = position + runVelocity * interceptTime
                local interceptGap = flat(interceptCatcher - interceptRunner).Magnitude
                local predicted = current + velocity * prediction + acceleration * (0.5 * prediction * prediction)
                if tackle and tackleDirection.Magnitude > 0.05 then
                    local duration = tonumber(character:GetAttribute("TackleDuration")) or 0.45
                    local started = tonumber(character:GetAttribute("TackleStartedAt")) or 0
                    local elapsed = nowServer > 0 and math.max(0, nowServer - started) or 0
                    local activeTime = math.clamp(duration - elapsed, 0, prediction)
                    local dashSpeed = math.max(velocity.Magnitude, runSpeed * 2.4)
                    local tackleTravel = math.min(dashSpeed * activeTime, danger + 20)
                    predicted = current + tackleDirection * tackleTravel
                    local tackleTime = math.min(interceptTime, activeTime)
                    interceptCatcher = current + tackleDirection * math.min(dashSpeed * tackleTime, danger + 20)
                    interceptGap = flat(interceptCatcher - interceptRunner).Magnitude
                end
                local collisionRisk = timeToDanger <= math.min(prediction + 0.05, 0.65)
                    or interceptGap <= danger * 1.25
                    or (tackle and interceptGap <= danger * 2.0)
                local preTackle = closing >= math.max(6.5, runSpeed * 0.35) and distance <= 55
                runtime.threats[#runtime.threats + 1] = {
                    player = player,
                    root = root,
                    position = current,
                    velocity = velocity,
                    acceleration = acceleration,
                    distance = distance,
                    closing = closing,
                    predicted = predicted,
                    intercept = interceptCatcher,
                    interceptRunner = interceptRunner,
                    interceptTime = math.max(0, interceptTime),
                    interceptGap = interceptGap,
                    danger = danger,
                    tackle = tackle,
                    collisionRisk = collisionRisk,
                    preTackle = preTackle,
                    timeToDanger = timeToDanger,
                }
            end
        end
    end
    table.sort(runtime.threats, function(a, b)
        if a.collisionRisk ~= b.collisionRisk then return a.collisionRisk end
        if a.timeToDanger ~= b.timeToDanger then return a.timeToDanger < b.timeToDanger end
        if a.tackle ~= b.tackle then return a.tackle end
        if a.interceptGap ~= b.interceptGap then return a.interceptGap < b.interceptGap end
        return a.distance < b.distance
    end)
    for player, history in pairs(runtime.threatHistory) do
        if not player.Parent or now - history.time > 1.2 then
            runtime.threatHistory[player] = nil
        end
    end
    return runtime.threats
end

local function rotate(dir, angle)
    local r = math.rad(angle)
    local c = math.cos(r)
    local s = math.sin(r)
    return Vector3.new(dir.X * c - dir.Z * s, 0, dir.X * s + dir.Z * c)
end

local function routeClear(position, direction, threats)
    if direction.Magnitude < 0.05 then return -math.huge end
    local dir = direction.Unit
    local speed = math.max(getRunnerSpeed(), 1)
    local clearance = math.huge
    local samples = {0.05, 0.10, 0.18, 0.26, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.95}
    for _, t in ipairs(samples) do
        local runner = position + dir * speed * t
        for _, threat in ipairs(threats) do
            local catchPos
            if threat.tackle and flat(threat.intercept - threat.position).Magnitude > 0.05 then
                local tackleDir = flat(threat.intercept - threat.position).Unit
                local tackleTime = math.min(t, math.max(threat.interceptTime, 0.12))
                local tackleSpeed = math.max(threat.velocity.Magnitude, speed * 2.4)
                catchPos = threat.position + tackleDir * math.min(tackleSpeed * tackleTime, threat.danger + 20)
            else
                catchPos = threat.position + threat.velocity * t + threat.acceleration * (0.5 * t * t)
            end
            local safe = flat(runner - catchPos).Magnitude - threat.danger
            if safe < clearance then clearance = safe end
        end
    end
    return clearance
end

local function addDirection(list, direction)
    direction = flat(direction)
    if direction.Magnitude < 0.05 then return end
    direction = direction.Unit
    for _, item in ipairs(list) do
        if item:Dot(direction) > 0.985 then return end
    end
    list[#list + 1] = direction
end

local function corridorAxes(position, goal)
    refreshSafezones()
    local a = safezone.a
    local b = safezone.b
    if not a or not b then return nil, nil, nil end
    local axis = flat(b.center - a.center)
    if axis.Magnitude < 0.05 then return nil, nil, nil end
    if math.abs(axis.X) >= math.abs(axis.Z) then
        axis = Vector3.new(axis.X >= 0 and 1 or -1, 0, 0)
    else
        axis = Vector3.new(0, 0, axis.Z >= 0 and 1 or -1)
    end
    local toGoal = flat(goal - position)
    if toGoal.Magnitude > 0.05 and axis:Dot(toGoal) < 0 then axis = -axis end
    local lateral = Vector3.new(-axis.Z, 0, axis.X)
    local center = (a.center + b.center) * 0.5
    return axis, lateral, center
end

local function clearCorridorLock()
    runtime.corridorActive = false
    runtime.corridorGoal = Vector3.zero
    runtime.corridorCenter = Vector3.zero
    runtime.corridorAxis = Vector3.zero
    runtime.corridorGapWidth = 0
    runtime.corridorStartedAt = -math.huge
end

local function findCorridorGoal(position, goal, threats, now)
    if not SETTINGS.corridorEnabled or #threats < 2 then
        clearCorridorLock()
        return nil
    end
    local axis, lateral, center = corridorAxes(position, goal)
    if not axis then
        clearCorridorLock()
        return nil
    end
    local forwardDistance = (center - position):Dot(axis)
    if forwardDistance < -12 or forwardDistance > SETTINGS.corridorApproachDistance then
        clearCorridorLock()
        return nil
    end
    local lineLat = center:Dot(lateral)
    local blockers = {}
    for _, threat in ipairs(threats) do
        local longitudinal = math.abs((threat.position - center):Dot(axis))
        local lateralPos = (threat.position - center):Dot(lateral)
        if longitudinal <= SETTINGS.corridorCenterRange and threat.distance <= 100 then
            blockers[#blockers + 1] = {
                threat = threat,
                lateral = lateralPos,
                buffer = math.clamp(threat.danger * 0.38, 2.25, 5.25),
            }
        end
    end
    if #blockers < 2 then
        if runtime.corridorActive and now - runtime.corridorStartedAt <= SETTINGS.corridorLockTime then
            return runtime.corridorGoal
        end
        clearCorridorLock()
        return nil
    end
    table.sort(blockers, function(x, y) return x.lateral < y.lateral end)
    local bestCenter = nil
    local bestWidth = -math.huge
    local bestScore = -math.huge
    local low = math.huge
    local high = -math.huge
    for _, item in ipairs(blockers) do
        low = math.min(low, item.lateral - item.buffer)
        high = math.max(high, item.lateral + item.buffer)
    end
    local gaps = {}
    for i = 1, #blockers - 1 do
        local left = blockers[i].lateral + blockers[i].buffer
        local right = blockers[i + 1].lateral - blockers[i + 1].buffer
        if right > left then
            gaps[#gaps + 1] = {left = left, right = right, center = (left + right) * 0.5}
        end
    end
    local lateralMin = math.min(low - 9, lineLat - 28)
    local lateralMax = math.max(high + 9, lineLat + 28)
    if blockers[1].lateral - blockers[1].buffer > lateralMin then
        gaps[#gaps + 1] = {
            left = lateralMin,
            right = blockers[1].lateral - blockers[1].buffer,
            center = (lateralMin + blockers[1].lateral - blockers[1].buffer) * 0.5,
        }
    end
    if blockers[#blockers].lateral + blockers[#blockers].buffer < lateralMax then
        gaps[#gaps + 1] = {
            left = blockers[#blockers].lateral + blockers[#blockers].buffer,
            right = lateralMax,
            center = (blockers[#blockers].lateral + blockers[#blockers].buffer + lateralMax) * 0.5,
        }
    end
    for _, gap in ipairs(gaps) do
        local width = gap.right - gap.left
        if width >= SETTINGS.corridorMinWidth then
            local lateralOffset = gap.center - lineLat
            local linePoint = center + lateral * lateralOffset
            local aheadPoint = linePoint + axis * SETTINGS.corridorPassDistance
            local entryPoint = linePoint - axis * math.min(12, math.max(6, forwardDistance * 0.15))
            local entryClear = routeClear(position, flat(entryPoint - position), threats)
            local passClear = routeClear(position, flat(aheadPoint - position), threats)
            local edgeSafe = edgeDirectionClear(linePoint - axis * 4, axis, position.Y, 8)
            local centrality = 1 - math.min(math.abs(lateralOffset) / 28, 1)
            local score = width * 2.8 + centrality * 6 + math.min(passClear, 15) * 1.4 + math.min(entryClear, 10)
            if edgeSafe then score += 4 else score -= 6 end
            if passClear < -1.5 or entryClear < -1.5 then score -= 20 end
            if score > bestScore then
                bestScore = score
                bestCenter = gap.center
                bestWidth = width
            end
        end
    end
    if not bestCenter then
        if runtime.corridorActive and now - runtime.corridorStartedAt <= SETTINGS.corridorLockTime then
            local lockedProgress = (position - runtime.corridorCenter):Dot(runtime.corridorAxis)
            if lockedProgress > -8 and lockedProgress < SETTINGS.corridorPassDistance + 10 then
                return runtime.corridorGoal
            end
        end
        clearCorridorLock()
        return nil
    end
    if runtime.corridorActive then
        local sameAxis = runtime.corridorAxis:Dot(axis) > 0.98
        local sameCenter = math.abs((runtime.corridorCenter - center):Dot(lateral) - (bestCenter - lineLat)) <= 5
        local progress = (position - runtime.corridorCenter):Dot(runtime.corridorAxis)
        if sameAxis and sameCenter and progress > -10 and progress < SETTINGS.corridorPassDistance + 12 then
            return runtime.corridorGoal
        end
    end
    local gapOffset = bestCenter - lineLat
    local linePoint = center + lateral * gapOffset
    local passPoint = linePoint + axis * SETTINGS.corridorPassDistance
    runtime.corridorActive = true
    runtime.corridorGoal = Vector3.new(passPoint.X, position.Y, passPoint.Z)
    runtime.corridorCenter = linePoint
    runtime.corridorAxis = axis
    runtime.corridorGapWidth = bestWidth
    runtime.corridorStartedAt = now
    return runtime.corridorGoal
end

local function corridorDirection(position, goal, threats)
    local desired = flat(goal - position)
    if desired.Magnitude < 0.05 then return Vector3.zero end
    desired = desired.Unit
    local candidates = {}
    if runtime.sideGapDirection.Magnitude > 0.05 and os.clock() < runtime.sideGapUntil then
        addDirection(candidates, runtime.sideGapDirection)
    end
    addDirection(candidates, desired)
    for _, angle in ipairs({12, -12, 24, -24, 38, -38, 52, -52, 70, -70, 90, -90}) do
        addDirection(candidates, rotate(desired, angle))
    end
    local best = desired
    local bestScore = -math.huge
    for _, candidate in ipairs(candidates) do
        local progress = candidate:Dot(desired)
        if progress >= -0.05 then
            local clearance = routeClear(position, candidate, threats)
            local score = progress * 8 + math.min(clearance, 16) * 2.2
            if clearance < 0 then
                score -= math.abs(clearance) * 16
            elseif clearance < 4 then
                score -= (4 - clearance) * 7
            end
            if score > bestScore then
                bestScore = score
                best = candidate
            end
        end
    end
    return best.Unit
end

local function chooseSideGapDirection(position, desired, threats)
    if not SETTINGS.sideGapEnabled or #threats == 0 then return nil, nil, -math.huge end
    local front = flat(desired)
    if front.Magnitude < 0.05 then return nil, nil, -math.huge end
    front = front.Unit
    local lateral = Vector3.new(-front.Z, 0, front.X)
    local nearest = nil
    local nearestDistance = math.huge
    for _, threat in ipairs(threats) do
        local rel = flat(threat.predicted - position)
        if rel.Magnitude > 0.05 then
            local forward = rel:Dot(front)
            local lateralOffset = math.abs(rel:Dot(lateral))
            if forward > 0 and forward <= 34 and lateralOffset <= 16 and threat.distance < nearestDistance then
                nearest = threat
                nearestDistance = threat.distance
            end
        end
    end
    if not nearest then return nil, nil, -math.huge end
    local rel = flat(nearest.predicted - position)
    local forwardGap = rel:Dot(front)
    local lateralOffset = rel:Dot(lateral)
    local frontBlocked = forwardGap > 0 and forwardGap < math.max(12, nearest.danger * 2.2)
        and math.abs(lateralOffset) < 13
    if not frontBlocked then return nil, nil, -math.huge end
    local candidates = {}
    for _, angle in ipairs(SETTINGS.sideGapAngles) do
        local rad = math.rad(angle)
        local c = math.cos(rad)
        local sn = math.sin(rad)
        local leftDir = (front * c + lateral * sn)
        local rightDir = (front * c - lateral * sn)
        candidates[#candidates + 1] = {dir = leftDir.Unit, side = "left"}
        candidates[#candidates + 1] = {dir = rightDir.Unit, side = "right"}
    end
    local best, bestScore, bestSide = nil, -math.huge, nil
    for _, item in ipairs(candidates) do
        local candidate = item.dir
        local clearance = routeClear(position, candidate, threats)
        local support = groundSupportScore(position, candidate, position.Y)
        local wallBlocked = invisWallHit(position, candidate, 16) ~= nil
        if not wallBlocked and support >= 3 and clearance >= -1 then
            local forwardProgress = candidate:Dot(front)
            local sideProgress = math.abs(candidate:Dot(lateral))
            local score = forwardProgress * SETTINGS.sideGapForwardBias
                + sideProgress * 7
                + math.min(clearance, 14) * 3.2
                + support * 1.4
            local towardCatcher = rel:Dot(lateral)
            local away = item.side == "left" and -towardCatcher or towardCatcher
            score += math.clamp(away / 10, -1, 1) * 4
            if clearance >= SETTINGS.sideGapMinClearance then score += 5 end
            if score > bestScore then
                best = candidate
                bestScore = score
                bestSide = item.side
            end
        end
    end
    if best then return best, bestSide, bestScore end
    return nil, nil, -math.huge
end

local function chooseRunnerDirection(position, goal, threats)
    local desired = flat(goal - position)
    if desired.Magnitude < 0.05 then return Vector3.zero end
    desired = desired.Unit
    
    local panic = false
    if #threats > 0 and threats[1].distance <= SETTINGS.panicDistance then
        panic = true
    end
    
    local sideGap, sideName = chooseSideGapDirection(position, desired, threats)
    if sideGap and not panic then
        runtime.sideGapDirection = sideGap
        runtime.sideGapUntil = os.clock() + SETTINGS.sideGapCommitTime
        runtime.sideGapReason = "front-blocked:" .. tostring(sideName)
        return sideGap
    elseif runtime.sideGapDirection.Magnitude > 0.05 and os.clock() < runtime.sideGapUntil then
        local clear = routeClear(position, runtime.sideGapDirection, threats)
        if clear >= 0 and not invisWallHit(position, runtime.sideGapDirection, 14) then
            return runtime.sideGapDirection
        end
    else
        runtime.sideGapDirection = Vector3.zero
        runtime.sideGapReason = ""
    end
    
    if not SETTINGS.avoidCatchers or #threats == 0 then
        runtime.sideGapDirection = Vector3.zero
        runtime.sideGapUntil = -math.huge
        runtime.sideGapReason = ""
        return desired
    end
    
    local candidates = {}
    addDirection(candidates, desired)
    for _, angle in ipairs({10, -10, 22, -22, 34, -34, 48, -48, 62, -62, 76, -76, 88, -88, 105, -105, 125, -125}) do
        addDirection(candidates, rotate(desired, angle))
    end
    
    if panic then
        local escape = flat(position - threats[1].position)
        if escape.Magnitude > 0.05 then
            addDirection(candidates, escape.Unit)
            addDirection(candidates, rotate(escape.Unit, 45))
            addDirection(candidates, rotate(escape.Unit, -45))
        end
    end
    
    local blocker = threats[1]
    local nearestScore = math.huge
    for _, threat in ipairs(threats) do
        local toThreat = flat(threat.position - position)
        local ahead = toThreat:Dot(desired)
        local distance = toThreat.Magnitude
        if ahead > 0 and distance < nearestScore then
            nearestScore = distance
            blocker = threat
        end
    end
    
    if blocker then
        local toBlocker = flat(blocker.position - position)
        if toBlocker.Magnitude > 0.05 then
            local lateral = Vector3.new(-desired.Z, 0, desired.X)
            local side = toBlocker:Dot(lateral) >= 0 and -1 or 1
            addDirection(candidates, (desired + lateral * side * 0.55).Unit)
            addDirection(candidates, (desired + lateral * side * 0.95).Unit)
            addDirection(candidates, (desired - lateral * side * 0.55).Unit)
            addDirection(candidates, (desired - lateral * side * 0.95).Unit)
        end
    end
    
    if runtime.stuck then
        local lateral = Vector3.new(-desired.Z, 0, desired.X)
        addDirection(candidates, lateral)
        addDirection(candidates, -lateral)
        local center = getPlayfieldCenter()
        if center then addDirection(candidates, flat(center - position)) end
    end
    
    local best = desired
    local bestScore = -math.huge
    local emergency = false
    for _, threat in ipairs(threats) do
        if threat.collisionRisk or threat.tackle or (threat.preTackle and threat.closing > 0) then
            emergency = true
            break
        end
    end
    
    for _, candidate in ipairs(candidates) do
        local progress = candidate:Dot(desired)
        local clearance = routeClear(position, candidate, threats)
        local wallBlocked = invisWallHit(position, candidate, 18) ~= nil
        
        if not wallBlocked then
            if not panic and not emergency and progress < 0.04 then
                continue
            end
            
            local score = progress * 10
            local avoidMultiplier = panic and (SETTINGS.avoidStrength * 2) or SETTINGS.avoidStrength
            
            score += math.min(clearance, 25) * 2.5 * avoidMultiplier
            if clearance < 0 then
                score -= math.abs(clearance) * 22 * avoidMultiplier
            elseif clearance < 6 then
                score -= (6 - clearance) * 6 * avoidMultiplier
            end
            
            if progress > 0.18 and math.abs(candidate:Dot(desired)) < 0.96 and not panic then
                score += math.min(math.max(clearance, 0), 8) * 1.15
            end
            
            for _, threat in ipairs(threats) do
                local away = flat(position - threat.intercept)
                if away.Magnitude > 0.05 then
                    local urgency = math.clamp(
                        1 - math.min(threat.interceptGap, threat.timeToDanger * math.max(threat.closing, 1)) / math.max(threat.danger * 3, 1),
                        0, 1
                    )
                    local weight = (threat.collisionRisk and 18 or 5) * avoidMultiplier
                    if threat.tackle then weight *= 1.6 end
                    score += candidate:Dot(away.Unit) * urgency * weight
                end
            end
            
            if runtime.edgeRisk then
                local inward = runtime.edgeDirection
                if inward.Magnitude > 0.05 then
                    score += candidate:Dot(inward.Unit) * (panic and 2 or 8)
                end
            end
            
            if score > bestScore then
                bestScore = score
                best = candidate
            end
        end
    end
    if best.Magnitude < 0.05 then return desired end
    return best.Unit
end

local function chooseDashDirection(position, direction, threats)
    local desired = flat(direction)
    local root = getRoot()
    if desired.Magnitude < 0.05 and root then
        desired = flat(root.CFrame.LookVector)
    end
    if desired.Magnitude < 0.05 then return Vector3.zero end
    desired = desired.Unit
    
    local candidates = {}
    addDirection(candidates, desired)
    for _, angle in ipairs({15, -15, 30, -30, 45, -45, 60, -60, 75, -75, 90, -90, 135, -135, 180}) do
        addDirection(candidates, rotate(desired, angle))
    end
    
    if runtime.edgeRisk and runtime.edgeDirection.Magnitude > 0.05 then
        addDirection(candidates, runtime.edgeDirection)
        addDirection(candidates, rotate(runtime.edgeDirection, 45))
        addDirection(candidates, rotate(runtime.edgeDirection, -45))
    end
    
    local best = desired
    local bestScore = -math.huge
    
    for _, candidate in ipairs(candidates) do
        local clearance = routeClear(position, candidate, threats)
        local progress = candidate:Dot(desired)
        
        local dashDistance = 45 
        local dashDest = position + candidate * dashDistance
        
        local score = progress * 8 + math.min(clearance, 25) * 5.0
        
        if clearance < 0 then
            score -= math.abs(clearance) * 40
        end
        
        for _, threat in ipairs(threats) do
            local futureThreatPos = threat.position + threat.velocity * 0.35
            local gapAtDest = flat(dashDest - futureThreatPos).Magnitude
            
            if gapAtDest < threat.danger * 1.5 then
                score -= (threat.danger * 1.5 - gapAtDest) * 25
            end
        end
        
        if score > bestScore then
            bestScore = score
            best = candidate
        end
    end
    return best.Unit
end

local function getAbilityKey()
    local state = runtime.armory
    if type(state) ~= "table" or state.loaded ~= true then return nil end
    local candidates = {}
    local function add(value)
        if type(value) ~= "string" or value == "" then return end
        for i = 1, #candidates do
            if candidates[i] == value then return end
        end
        candidates[#candidates + 1] = value
    end
    local ok, value = pcall(GearCatalog.equippedForRole, state, "Runner")
    if ok then add(value) end
    ok, value = pcall(GearCatalog.equippedForRole, "Runner", state)
    if ok then add(value) end
    ok, value = pcall(GearCatalog.equippedForRole, "Runner")
    if ok then add(value) end
    add(state.equippedAbility)
    add(state.RunnerAbility)
    add(state.runnerAbility)
    local equipped = state.equipped or state.Equipped or state.loadout or state.Loadout
    if type(equipped) == "table" then
        add(equipped.Runner)
        add(equipped.runner)
        add(equipped.Ability)
        add(equipped.ability)
    end
    for i = 1, #candidates do
        local key = candidates[i]
        local okDef, def = pcall(GearCatalog.get, key)
        if okDef and def and def.Kind == "Ability" then
            if (not def.UseRole or def.UseRole == "Runner")
                and type(state.abilities) == "table"
                and state.abilities[key] == true then
                return key
            end
        end
    end
    return nil
end

local function requestDash(direction, now)
    if not SETTINGS.autoDash or not isRunnerActive() then return false end
    local character = getCharacter()
    local root = getRoot()
    if not character or not root then
        runtime.dashStatus = "no-character"
        return false
    end
    local okAvailable, available = pcall(BoostInput.available, LocalPlayer)
    if not okAvailable then
        runtime.dashStatus = "available-error: " .. tostring(available)
        return false
    end
    if available ~= true then
        local cooldownUntil = tonumber(character:GetAttribute("DashCooldownUntil")) or 0
        runtime.dashStatus = cooldownUntil > os.clock() and "cooldown" or "not-available"
        return false
    end
    local cooldownUntil = tonumber(character:GetAttribute("DashCooldownUntil")) or 0
    if os.clock() < cooldownUntil then
        runtime.dashStatus = "cooldown"
        return false
    end
    if now - runtime.dashAt < SETTINGS.dashCooldown then
        runtime.dashStatus = "local-cooldown"
        return false
    end
    local hum = getHumanoid()
    local dir = hum and flat(hum.MoveDirection) or Vector3.zero
    if dir.Magnitude < 0.05 then dir = flat(direction) end
    if dir.Magnitude < 0.05 then dir = flat(root.CFrame.LookVector) end
    if dir.Magnitude < 0.05 then
        runtime.dashStatus = "no-direction"
        return false
    end
    local beforeCount = tonumber(character:GetAttribute("DashCount")) or 0
    local okRequest, result = pcall(BoostInput.request, nil)
    runtime.dashLastRequestAt = now
    runtime.dashLastCount = beforeCount
    if not okRequest then
        runtime.dashStatus = "request-error: " .. tostring(result)
        return false
    end
    if result == false then
        runtime.dashStatus = "request-rejected"
        return false
    end
    runtime.dashAt = now
    runtime.dashStatus = "requested:waiting-game-client"
    return true
end

local function shouldDash(position, threats, goalDistance)
    if not SETTINGS.autoDash or not isRunnerActive() then return false end
    local now = os.clock()
    if now - runtime.dashAt < 0.20 then return false end 
    if #threats == 0 then return false end
    
    local nearestDistance = math.huge
    local surroundedCount = 0
    local immediateDanger = false
    local imminentTime = math.huge
    
    for _, threat in ipairs(threats) do
        if threat.distance < nearestDistance then nearestDistance = threat.distance end
        if threat.distance <= 40 then surroundedCount += 1 end
        
        local gap = tonumber(threat.interceptGap) or math.huge
        local danger = math.max(tonumber(threat.danger) or 4, 4)
        imminentTime = math.min(imminentTime, tonumber(threat.timeToDanger) or math.huge)
        
        if threat.tackle and (gap <= danger * 1.25 or (threat.timeToDanger or math.huge) <= 0.35 or threat.distance <= 12) then
            immediateDanger = true
        elseif threat.preTackle and (gap <= danger * 1.15 and (threat.timeToDanger or math.huge) <= 0.45) then
            immediateDanger = true
        elseif threat.collisionRisk and (gap <= danger * 1.1 and (threat.timeToDanger or math.huge) <= 0.4) then
            immediateDanger = true
        end
    end
    
    local currentPath = runtime.path
    local pathBlocked = false
    if currentPath.Magnitude > 0.05 then
        local pathClearance = routeClear(position, currentPath, threats)
        if pathClearance < -1.0 then pathBlocked = true end
    end
    
    if immediateDanger then return true end
    
    if surroundedCount >= 2 and nearestDistance <= 25 then return true end
    if pathBlocked and nearestDistance <= 20 and imminentTime <= 0.6 then return true end
    
    return false
end

local function runnerGoal(position, now)
    runtime.goalMode = "SafeZone"
    local goal = select(1, chooseSafeGoal(position))
    if not goal and SETTINGS.emergencySafeZone then
        goal = getSafeFallback(position)
    end
    runtime.goal = goal
    return goal
end

local function routeDistance(position, goal, target)
    local a = flat(position)
    local b = flat(goal)
    local p = flat(target)
    local line = b - a
    local lengthSquared = line:Dot(line)
    if lengthSquared < 0.01 then return (p - a).Magnitude, 0 end
    local t = math.clamp((p - a):Dot(line) / lengthSquared, 0, 1)
    local closest = a + line * t
    return (p - closest).Magnitude, t
end

local function validReviveTarget(target)
    if not target or not target.Parent then return false end
    local character = target.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    if character:GetAttribute("RescueAvailable") ~= true or character:GetAttribute("Ragdolled") ~= true then return false end
    local helper = character:GetAttribute("RescueHelperId")
    return helper == nil or helper == LocalPlayer.UserId
end

local function chooseAssistTarget(position, safeGoal, now)
    if not safeGoal then
        runtime.assistMode = nil
        runtime.assistTarget = nil
        return nil, nil
    end
    local currentAssist = runtime.assistTarget
    if runtime.assistMode == "Revive" then
        if validReviveTarget(currentAssist) then
            local targetRoot = getRoot(currentAssist)
            if targetRoot then
                local distance = flat(targetRoot.Position - position).Magnitude
                local lateral = routeDistance(position, safeGoal, targetRoot.Position)
                if runtime.reviveStarted or distance <= SETTINGS.reviveMaxDistance and (lateral <= 24 or distance <= RESCUE_RANGE + 5) then
                    return currentAssist, "Revive"
                end
            end
        end
        if runtime.reviveStarted then return currentAssist, "Revive" end
        runtime.assistMode = nil
        runtime.assistTarget = nil
    elseif runtime.assistMode == "Gem" then
        if currentAssist and currentAssist.Parent then
            local distance = flat(currentAssist.Position - position).Magnitude
            local lateral = routeDistance(position, safeGoal, currentAssist.Position)
            if distance <= SETTINGS.gemMaxDistance and lateral <= 18 then
                return currentAssist, "Gem"
            end
        end
        runtime.assistMode = nil
        runtime.assistTarget = nil
    end
    local reviveCandidate
    if SETTINGS.autoRevive then
        local target = findDownedPlayer(position)
        if target then
            local targetRoot = getRoot(target)
            if targetRoot then
                local distance = flat(targetRoot.Position - position).Magnitude
                local lateral, t = routeDistance(position, safeGoal, targetRoot.Position)
                if distance <= SETTINGS.reviveMaxDistance and t <= 1.05 and (lateral <= 24 or distance <= RESCUE_RANGE + 5) then
                    reviveCandidate = target
                end
            end
        end
    end
    local gemCandidate
    if SETTINGS.autoGems then
        refreshGems(now, position)
        local gem = runtime.gemTarget
        if gem and gem.Parent then
            local distance = flat(gem.Position - position).Magnitude
            local lateral, t = routeDistance(position, safeGoal, gem.Position)
            if distance <= SETTINGS.gemMaxDistance and t <= 1.05 and lateral <= 18 then
                gemCandidate = gem
            end
        end
    end
    if SETTINGS.reviveBeforeGems and reviveCandidate then
        runtime.assistMode = "Revive"
        runtime.assistTarget = reviveCandidate
        runtime.assistSince = now
        return reviveCandidate, "Revive"
    end
    if gemCandidate then
        runtime.assistMode = "Gem"
        runtime.assistTarget = gemCandidate
        runtime.assistSince = now
        return gemCandidate, "Gem"
    end
    if reviveCandidate then
        runtime.assistMode = "Revive"
        runtime.assistTarget = reviveCandidate
        runtime.assistSince = now
        return reviveCandidate, "Revive"
    end
    return nil, nil
end

local function handleGemArrival(position, now)
    local gem = runtime.gemTarget
    if not gem or not gem.Parent then return end
    local dist = flat(gem.Position - position).Magnitude
    local vertical = math.abs(gem.Position.Y - position.Y)
    if dist <= SETTINGS.gemCollectDistance and vertical <= 5 then
        runtime.gemIgnored[gem] = now + 0.35
        runtime.gemTarget = nil
    end
end

local function movementStuck(now, position)
    local previous = runtime.lastMovePosition
    if not previous then
        runtime.lastMovePosition = position
        runtime.lastMove = now
        runtime.stuck = false
        return
    end
    if flat(position - previous).Magnitude >= 0.5 then
        runtime.lastMovePosition = position
        runtime.lastMove = now
        runtime.stuck = false
    elseif now - runtime.lastMove > 0.55 then
        runtime.stuck = true
        runtime.lastMove = now
        runtime.lastMovePosition = position
    end
end

local function runnerStep(now, dt)
    local role = getRole()
    local state = getRunState()
    if role ~= "Runner" or state ~= "Active" then
        runtime.path = Vector3.zero
        runtime.runnerPlanAt = -math.huge
        runtime.runnerPlanDirection = Vector3.zero
        runtime.runnerPlanGoal = Vector3.zero
        runtime.goal = nil
        runtime.goalSide = nil
        runtime.goalMode = "SafeZone"
        runtime.routeActive = false
        runtime.routeComplete = false
        runtime.routeStartSide = nil
        runtime.routeTargetSide = nil
        runtime.routeCompletePosition = nil
        runtime.routeCompleteAt = -math.huge
        clearCorridorLock()
        runtime.edgeRisk = false
        runtime.edgeDirection = Vector3.zero
        runtime.sideGapDirection = Vector3.zero
        runtime.sideGapUntil = -math.huge
        runtime.sideGapReason = ""
        runtime.assistMode = nil
        runtime.assistTarget = nil
        if runtime.reviveStarted then cancelRevive() end
        return
    end
    if not SETTINGS.runnerEnabled then return end
    local root = getRoot()
    local hum = getHumanoid()
    if not root or not hum then return end
    if not canMove() then
        runtime.path = Vector3.zero
        return
    end
    refreshPing(now)
    refreshSafezones()
    refreshCatchers(now)
    local position = root.Position
    local baseGoal = runnerGoal(position, now)
    if runtime.routeComplete then
        local targetZone = runtime.routeTargetSide == (safezone.a and safezone.a.name) and safezone.a or safezone.b
        local movedFromCompletion = runtime.routeCompletePosition and flat(position - runtime.routeCompletePosition).Magnitude or 0
        local newRoundPosition = targetZone and inZone(position, targetZone) and movedFromCompletion >= 5 and now - runtime.routeCompleteAt >= 0.25
        if newRoundPosition then
            runtime.routeActive = false
            runtime.routeComplete = false
            runtime.routeStartSide = nil
            runtime.routeTargetSide = nil
            runtime.routeCompletePosition = nil
            runtime.routeCompleteAt = -math.huge
            runtime.goal = nil
            runtime.goalSide = nil
            baseGoal = runnerGoal(position, now)
        end
        if runtime.routeComplete then
            clearCorridorLock()
            runtime.path = Vector3.zero
            runtime.goalMode = "SafeZone"
            runtime.assistMode = nil
            runtime.assistTarget = nil
            if runtime.reviveStarted then cancelRevive() end
            hum:Move(Vector3.zero, false)
            return
        end
    end
    if not baseGoal then
        local fallback = getSafeFallback(position)
        if fallback then
            baseGoal = fallback
            runtime.goal = fallback
            runtime.goalMode = "SafeZone"
        else
            local forward = flat(root.CFrame.LookVector)
            if forward.Magnitude > 0.05 then
                baseGoal = position + forward.Unit * 40
            end
        end
    end
    if not baseGoal then
        hum:Move(Vector3.zero, false)
        runtime.path = Vector3.zero
        return
    end
    local assistTarget, assistMode = chooseAssistTarget(position, baseGoal, now)
    local movementGoal = baseGoal
    if assistTarget and assistMode == "Revive" then
        runtime.reviveTarget = assistTarget
        local targetRoot = getRoot(assistTarget)
        if targetRoot then
            local targetPosition = targetRoot.Position
            local distance = flat(targetPosition - position).Magnitude
            if distance <= RESCUE_RANGE + 0.75 or runtime.reviveStarted then
                updateRevive(now, position)
            end
            if not runtime.reviveStarted and distance > RESCUE_RANGE then
                movementGoal = targetPosition
            elseif runtime.reviveStarted then
                movementGoal = targetPosition
            end
        end
    elseif assistTarget and assistMode == "Gem" and assistTarget.Parent then
        movementGoal = assistTarget.Position
        runtime.goalMode = "Gem"
    else
        runtime.goalMode = "SafeZone"
    end
    if runtime.reviveStarted then
        local targetRoot = runtime.reviveTarget and getRoot(runtime.reviveTarget)
        if targetRoot then
            local reviveDistance = flat(targetRoot.Position - position).Magnitude
            if reviveDistance > RESCUE_RANGE + 1.25 then
                cancelRevive()
            else
                hum:Move(Vector3.zero, false)
                runtime.path = Vector3.zero
                return
            end
        else
            cancelRevive()
        end
    end
    movementStuck(now, position)
    local threats = updateThreats(now, position)
    local distanceToGoal = flat(movementGoal - position).Magnitude
    local arriveDistance = runtime.goalMode == "Gem" and SETTINGS.gemCollectDistance or 2.5
    if distanceToGoal <= arriveDistance then
        if runtime.goalMode == "Gem" then
            handleGemArrival(position, now)
            runtime.assistMode = nil
            runtime.assistTarget = nil
            runtime.goalMode = "SafeZone"
            movementGoal = baseGoal
        elseif runtime.goalMode == "SafeZone" then
            local nextGoal = select(1, chooseSafeGoal(position))
            if runtime.routeComplete then
                hum:Move(Vector3.zero, false)
                runtime.path = Vector3.zero
                return
            end
            movementGoal = nextGoal or baseGoal
            runtime.goal = movementGoal
        end
    end
    if not movementGoal then
        hum:Move(Vector3.zero, false)
        runtime.path = Vector3.zero
        return
    end
    local direction = flat(movementGoal - position)
    if direction.Magnitude < 0.05 then
        hum:Move(Vector3.zero, false)
        runtime.path = Vector3.zero
        return
    end
    if runtime.goalMode == "SafeZone" and runtime.goal then
        movementGoal = Vector3.new(runtime.goal.X, position.Y, runtime.goal.Z)
        direction = flat(movementGoal - position)
        if direction.Magnitude < 0.05 then
            local nextGoal = select(1, chooseSafeGoal(position))
            movementGoal = nextGoal or movementGoal
            runtime.goal = movementGoal
            direction = flat(movementGoal - position)
            if direction.Magnitude < 0.05 then
                hum:Move(Vector3.zero, false)
                runtime.path = Vector3.zero
                return
            end
        end
    end
    direction = direction.Unit
    local corridorGoal = nil
    if runtime.goalMode == "SafeZone" and SETTINGS.avoidCatchers and #threats >= 2 then
        corridorGoal = findCorridorGoal(position, movementGoal, threats, now)
        if corridorGoal then
            movementGoal = corridorGoal
            direction = flat(corridorGoal - position)
            if direction.Magnitude > 0.05 then
                direction = corridorDirection(position, corridorGoal, threats)
            end
        end
    elseif runtime.corridorActive then
        clearCorridorLock()
    end
    if SETTINGS.avoidCatchers and #threats > 0 and not (corridorGoal and direction.Magnitude > 0.05) then
        direction = chooseRunnerDirection(position, movementGoal, threats)
    elseif SETTINGS.avoidCatchers and #threats > 0 and corridorGoal then
        direction = chooseRunnerDirection(position, movementGoal, threats)
        if runtime.corridorActive then
            direction = corridorDirection(position, movementGoal, threats)
        end
    end
    if runtime.corridorActive then
        local axis = runtime.corridorAxis
        local progress = (position - runtime.corridorCenter):Dot(axis)
        if progress >= SETTINGS.corridorPassDistance + 3 then clearCorridorLock() end
    end
    local hardThreat = threats[1]
    local hardDodge = false
    if SETTINGS.avoidCatchers and hardThreat and (hardThreat.collisionRisk or hardThreat.tackle or hardThreat.preTackle and hardThreat.closing > 0) then
        local escape = flat(position - hardThreat.intercept)
        if escape.Magnitude > 0.05 then
            local escapeDir = escape.Unit
            local candidates = {escapeDir, rotate(escapeDir, 35), rotate(escapeDir, -35), rotate(escapeDir, 70), rotate(escapeDir, -70)}
            if runtime.corridorActive then
                local forward = flat(runtime.corridorGoal - position)
                if forward.Magnitude > 0.05 then
                    local keep = {}
                    for _, candidate in ipairs(candidates) do
                        if candidate:Dot(forward.Unit) > 0.05 then keep[#keep + 1] = candidate end
                    end
                    candidates = keep
                end
            end
            local best = direction
            local bestClearance = routeClear(position, direction, threats)
            local forward = flat(movementGoal - position)
            local forwardUnit = forward.Magnitude > 0.05 and forward.Unit or direction
            local nearestGap = hardThreat.interceptGap
            local allowReverse = nearestGap <= hardThreat.danger * 0.52
            local foundForward = false
            for _, candidate in ipairs(candidates) do
                local progress = candidate:Dot(forwardUnit)
                if progress >= 0.08 then
                    foundForward = true
                elseif not allowReverse then
                    continue
                end
                local clear = routeClear(position, candidate, threats)
                local adjusted = clear + progress * 2.5
                local bestAdjusted = bestClearance + best:Dot(forwardUnit) * 2.5
                if adjusted > bestAdjusted then
                    best = candidate
                    bestClearance = clear
                end
            end
            local emergency = hardThreat.interceptGap <= hardThreat.danger * (runtime.corridorActive and 1.05 or 1.35)
            if emergency or bestClearance < 3 then
                direction = best
                hardDodge = true
            elseif foundForward then
                hardDodge = false
            end
        end
    end
    local nearestThreat
    local nearestDistance = math.huge
    for _, threat in ipairs(threats) do
        if threat.distance < nearestDistance then
            nearestDistance = threat.distance
            nearestThreat = threat
        end
    end
    if SETTINGS.emergencySafeZone and nearestThreat and nearestDistance <= SETTINGS.panicDistance and runtime.stuck then
        local fallback = getSafeFallback(position)
        if fallback then
            local safeDirection = flat(fallback - position)
            if safeDirection.Magnitude > 0.05 then
                direction = safeDirection.Unit
                movementGoal = fallback
                runtime.goalMode = "SafeZone"
                runtime.assistMode = nil
                runtime.assistTarget = nil
            end
        end
    end
    local nowEdge = now
    local edgeDirection, edgeRisk = chooseEdgeDirection(position, direction, movementGoal, position.Y)
    runtime.edgeRisk = edgeRisk
    runtime.edgeDirection = edgeDirection
    if edgeRisk and edgeDirection.Magnitude > 0.05 then
        if runtime.edgeRecoveryDirection.Magnitude < 0.05
            or nowEdge >= runtime.edgeRecoveryUntil
            or runtime.edgeRecoveryDirection:Dot(edgeDirection) < 0.92 then
            runtime.edgeRecoveryDirection = edgeDirection.Unit
            runtime.edgeRecoveryAt = nowEdge
            runtime.edgeRecoveryUntil = nowEdge + 0.72
        end
        direction = runtime.edgeRecoveryDirection
        hardDodge = true
    elseif nowEdge >= runtime.edgeRecoveryUntil then
        runtime.edgeRecoveryDirection = Vector3.zero
    end
    if runtime.stuck and movementGoal then
        local center = getPlayfieldCenter()
        local recovery = center and flat(center - position) or flat(movementGoal - position)
        if recovery.Magnitude > 0.05 then
            recovery = recovery.Unit
            if runtime.stuckRecoveryDirection.Magnitude < 0.05
                or nowEdge >= runtime.stuckRecoveryUntil
                or runtime.stuckRecoveryDirection:Dot(recovery) < 0.75 then
                local candidates = {recovery, rotateEdge(recovery, 35), rotateEdge(recovery, -35), rotateEdge(recovery, 70), rotateEdge(recovery, -70)}
                local best = recovery
                local bestScore = -math.huge
                for _, candidate in ipairs(candidates) do
                    local support = groundSupportScore(position, candidate, position.Y)
                    local progress = candidate:Dot(recovery)
                    local score = support * 5 + progress * 4
                    if score > bestScore then
                        bestScore = score
                        best = candidate.Unit
                    end
                end
                runtime.stuckRecoveryDirection = best
                runtime.stuckRecoveryUntil = nowEdge + 0.85
            end
            direction = runtime.stuckRecoveryDirection
            hardDodge = true
        end
    elseif nowEdge >= runtime.stuckRecoveryUntil then
        runtime.stuckRecoveryDirection = Vector3.zero
    end
    if SETTINGS.smoothMovement and not hardDodge and runtime.path.Magnitude > 0.05 and not runtime.stuck then
        local alpha = math.clamp(SETTINGS.turnRate * math.clamp(dt or (1 / 60), 0.001, 0.1), 0, 1)
        local blended = flat(runtime.path:Lerp(direction, alpha))
        if blended.Magnitude > 0.05 then direction = blended.Unit end
    end
    runtime.path = direction
    if hum.AutoRotate ~= true then hum.AutoRotate = true end
    hum:Move(direction, false)
    local character = getCharacter()
    local dashCount = character and tonumber(character:GetAttribute("DashCount")) or nil
    if dashCount and runtime.dashLastCount ~= nil and dashCount ~= runtime.dashLastCount then
        runtime.dashStatus = "active:count " .. tostring(dashCount)
        runtime.dashLastCount = dashCount
    elseif runtime.dashLastRequestAt > 0 and now - runtime.dashLastRequestAt > 0.35
        and now - runtime.dashAt > 0.35 and runtime.dashStatus == "requested:waiting-game-client" then
        runtime.dashStatus = "no-dash-state-change"
    end
    local goalDistance = flat(movementGoal - position).Magnitude
    if shouldDash(position, threats, goalDistance) then
        local dashDir = chooseDashDirection(position, direction, threats)
        if runtime.sideGapDirection.Magnitude > 0.05 and os.clock() < runtime.sideGapUntil then
            dashDir = runtime.sideGapDirection
        elseif runtime.edgeRisk and runtime.edgeRecoveryDirection.Magnitude > 0.05 then
            dashDir = runtime.edgeRecoveryDirection
        elseif runtime.stuck and runtime.stuckRecoveryDirection.Magnitude > 0.05 then
            dashDir = runtime.stuckRecoveryDirection
        end
        requestDash(dashDir, now)
    end
end

local function refreshRunnerTargets(now)
    if now - runtime.catcherTargetAt < 0.15 then return end
    runtime.catcherTargetAt = now
    table.clear(runtime.catcherTargets)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Parent and player:GetAttribute("GameRole") == "Runner" and player:GetAttribute("RunState") == "Active" then
            local c = player.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            local r = c and c:FindFirstChild("HumanoidRootPart")
            if h and h.Health > 0 and r and c:GetAttribute("Ragdolled") ~= true then
                runtime.catcherTargets[#runtime.catcherTargets + 1] = player
            end
        end
    end
end

local function catcherVelocity(player, now)
    local root = getRoot(player)
    if not root then return Vector3.zero end
    local data = runtime.catcherVelocity[player]
    if not data then
        data = {velocity = flat(root.AssemblyLinearVelocity), time = now}
        runtime.catcherVelocity[player] = data
        return data.velocity
    end
    local raw = flat(root.AssemblyLinearVelocity)
    local dt = math.clamp(now - data.time, 0.01, 0.25)
    local alpha = math.clamp(dt * SETTINGS.catcherSmoothing, 0, 1)
    data.velocity = data.velocity:Lerp(raw, alpha)
    data.time = now
    return data.velocity
end

local function runnerSafeForCatcher(player)
    refreshSafezones()
    local root = getRoot(player)
    return root and currentZone(root.Position) ~= nil and (inZone(root.Position, safezone.a) or inZone(root.Position, safezone.b))
end

local function selectCatcherTarget(now, myPosition)
    refreshRunnerTargets(now)
    local best, bestScore
    local currentScore
    local currentTarget = runtime.catcherTarget
    local chaseSpeed = math.max(getCatcherSpeed(), 1)
    for _, player in ipairs(runtime.catcherTargets) do
        local root = getRoot(player)
        if root then
            local position = root.Position
            local velocity = catcherVelocity(player, now)
            local predicted = position + velocity * SETTINGS.catcherPrediction
            local distance = flat(position - myPosition).Magnitude
            local predictedDistance = flat(predicted - myPosition).Magnitude
            local safe = runnerSafeForCatcher(player)
            local timeToReach = predictedDistance / chaseSpeed
            local score = predictedDistance + math.min(timeToReach * 10, 30) + distance * 0.05
            if SETTINGS.smartPriority and velocity.Magnitude >= 4 then score -= 6 end
            if safe then score += 18 end
            if player == currentTarget then currentScore = score end
            if not bestScore or score < bestScore then
                best = player
                bestScore = score
            end
        end
    end
    if currentTarget and currentScore and bestScore and currentTarget ~= best and currentScore <= bestScore + 8 then
        best = currentTarget
    end
    runtime.catcherTarget = best
    return best
end

local function catcherDirection(root, predicted, dt)
    local direction = flat(predicted - root.Position)
    if direction.Magnitude < 0.05 then return Vector3.zero end
    direction = direction.Unit
    if SETTINGS.smoothTurn and runtime.catcherPath and runtime.catcherPath.Magnitude > 0.05 then
        local alpha = math.clamp(1 - math.exp(-math.max(SETTINGS.turnRateCatcher, 1) * math.max(dt, 0.01)), 0, 1)
        local blended = runtime.catcherPath:Lerp(direction, alpha)
        if blended.Magnitude > 0.05 then direction = blended.Unit end
    end
    runtime.catcherPath = direction
    return direction
end

local function tackleRunning()
    local c = getCharacter()
    return c and c:GetAttribute("TackleActive") == true
end

local function catcherAttack(target, now, root)
    if not target or not root or tackleRunning() then return end
    local targetRoot = getRoot(target)
    if not targetRoot then return end
    local targetVelocity = catcherVelocity(target, now)
    local meleeLead = (ContactCatchConfig.Windup or 0.15) + (ContactCatchConfig.ActiveDuration or 0.1) * 0.5 + runtime.ping
    local meleePos = targetRoot.Position + targetVelocity * meleeLead
    local tacklePos = targetRoot.Position + targetVelocity * runtime.ping
    local meleeReady = SETTINGS.autoMelee and now - runtime.lastMelee >= SETTINGS.meleeCooldown
        and flat(meleePos - root.Position).Magnitude <= SETTINGS.meleeRange
    local tackleReady = SETTINGS.autoTackle and now - runtime.lastTackle >= SETTINGS.tackleCooldown
        and flat(tacklePos - root.Position).Magnitude <= SETTINGS.tackleRange
    local function fireMelee()
        local myRoot = getRoot()
        if not myRoot then return end
        local look = flat(myRoot.CFrame.LookVector)
        if look.Magnitude < 0.01 then return end
        local guid = HttpService:GenerateGUID(false)
        local nowServer = workspace:GetServerTimeNow()
        pcall(function()
            MeleeEvent:FireServer({
                id = guid,
                at = nowServer,
                direction = look.Unit,
                position = myRoot.Position,
            })
        end)
        runtime.meleeId += 1
        runtime.lastMelee = now
    end

    if SETTINGS.catcherAttackPriority == "Tackle First" then
        if tackleReady then
            pcall(TacklePrediction.request)
            runtime.lastTackle = now
            return
        end
        if meleeReady then
            fireMelee()
        end
    elseif SETTINGS.catcherAttackPriority == "Melee First" then
        if meleeReady then
            fireMelee()
            return
        end
        if tackleReady then
            pcall(TacklePrediction.request)
            runtime.lastTackle = now
        end
    else
        if targetVelocity.Magnitude >= 5 and tackleReady then
            pcall(TacklePrediction.request)
            runtime.lastTackle = now
        elseif meleeReady then
            fireMelee()
        elseif tackleReady then
            pcall(TacklePrediction.request)
            runtime.lastTackle = now
        end
    end
end

local function catcherStep(now, dt)
    if not isCatcherActive() then
        runtime.catcherTarget = nil
        runtime.catcherPath = Vector3.zero
        return
    end
    local root = getRoot()
    local hum = getHumanoid()
    if not root or not hum or hum.Health <= 0 or hum.PlatformStand or hum.Sit then return end
    refreshPing(now)
    local needsTarget = SETTINGS.catcherChase or SETTINGS.autoTackle or SETTINGS.autoMelee or SETTINGS.followTarget
    if not needsTarget then
        runtime.catcherTarget = nil
        runtime.catcherPath = Vector3.zero
        return
    end
    local target = selectCatcherTarget(now, root.Position)
    if not target then
        runtime.catcherTarget = nil
        return
    end
    local targetRoot = getRoot(target)
    if not targetRoot then
        runtime.catcherTarget = nil
        return
    end
    local velocity = catcherVelocity(target, now)
    local predicted = targetRoot.Position + velocity * SETTINGS.catcherPrediction
    local direction = catcherDirection(root, predicted, dt)
    if SETTINGS.catcherChase and direction.Magnitude > 0.05 then
        hum.AutoRotate = true
        hum:Move(direction, false)
    end
    if SETTINGS.autoTackle or SETTINGS.autoMelee then
        catcherAttack(target, now, root)
    end
    if SETTINGS.followTarget then
        local camera = workspace.CurrentCamera
        if camera then
            camera.CFrame = camera.CFrame:Lerp(
                CFrame.lookAt(camera.CFrame.Position, predicted + Vector3.new(0, 1.5, 0)),
                math.clamp(SETTINGS.cameraResponse, 0.01, 1)
            )
        end
    end
end

local function cleanupVisuals()
    if visuals.goal and visuals.goal.Parent then visuals.goal:Destroy() end
    visuals.goal = nil
    for key, part in pairs(visuals.threats) do
        if part.Parent then part:Destroy() end
        visuals.threats[key] = nil
    end
    for key, part in pairs(visuals.hitboxes) do
        if part.Parent then part:Destroy() end
        visuals.hitboxes[key] = nil
    end
    clearPathVisual()
end

local function requestJourneyState(force)
    local now = os.clock()
    if not force and now - runtime.journeyRequestAt < 1.5 then return false end
    runtime.journeyRequestAt = now
    local ok = pcall(function() JourneyEvent:FireServer("Get") end)
    if not ok then
        runtime.journeyStatus = "Journey state request failed"
        return false
    end
    return true
end

local function journeyClaimableCount()
    if not runtime.journeyLoaded then return 0 end
    local trackId = JourneyConfig.TrackId
    local tier = math.max(1, tonumber(runtime.journeyTier) or 1)
    local premium = runtime.journeyPremium == true
    local claims = runtime.journeyClaims or {}
    local count = 0
    for index = 1, tier do
        local rewardTier = JourneyConfig.Rewards[index]
        if rewardTier then
            local freeReward = rewardTier.Free
            if freeReward and claims[trackId .. ":" .. tostring(freeReward.Key)] ~= true then count += 1 end
            if premium then
                local premiumReward = rewardTier.Premium
                if premiumReward and claims[trackId .. ":" .. tostring(premiumReward.Key)] ~= true then count += 1 end
            end
        end
    end
    return count
end

local function journeyClaimOnce(manual)
    if not SETTINGS.autoClaimJourneyRewards and not manual then
        runtime.journeyStatus = "disabled"
        return false
    end
    if LocalPlayer:GetAttribute("InMatch") == true then
        runtime.journeyStatus = "waiting for lobby"
        return false
    end
    local now = os.clock()
    if now < (runtime.journeyNextClaimAt or -math.huge) then return false end
    if runtime.journeyClaimInFlight then
        runtime.journeyStatus = "claim request pending"
        return false
    end
    if not runtime.journeyLoaded then
        runtime.journeyManualPending = manual == true or runtime.journeyManualPending
        runtime.journeyStatus = "loading journey state"
        requestJourneyState(true)
        return false
    end
    local seasonId = runtime.journeySeasonId or JourneyConfig.SeasonId
    if type(seasonId) ~= "string" or seasonId == "" then
        runtime.journeyStatus = "season unavailable"
        return false
    end
    local available = journeyClaimableCount()
    if available <= 0 and not manual then
        runtime.journeyStatus = "no claimable rewards"
        runtime.journeyNextClaimAt = now + 2.5
        return false
    end
    runtime.journeyClaimInFlight = true
    runtime.journeyManualPending = false
    runtime.journeyLastClaimAt = now
    runtime.journeyNextClaimAt = now + 2.5
    runtime.journeyStatus = available > 0 and string.format("claiming %d reward%s", available, available == 1 and "" or "s") or "claiming available rewards"
    local fired = pcall(function() JourneyEvent:FireServer("ClaimAll", nil, seasonId) end)
    if not fired then
        runtime.journeyClaimInFlight = false
        runtime.journeyStatus = "claim request failed"
        runtime.journeyNextClaimAt = now + 1
        return false
    end
    task.delay(1.25, function()
        if runtime.journeyClaimInFlight then
            runtime.journeyClaimInFlight = false
            runtime.journeyStatus = "waiting for confirmation"
            requestJourneyState(true)
        end
    end)
    return true
end

local function wheelServerNow()
    local ok, value = pcall(function() return workspace:GetServerTimeNow() end)
    if ok and type(value) == "number" then return value end
    return os.time()
end

local function wheelCooldownRemaining()
    local nextFreeAt = tonumber(runtime.wheelNextFreeAt) or 0
    if nextFreeAt <= 0 then return 0 end
    if nextFreeAt < 100000000 then return math.max(0, nextFreeAt) end
    return math.max(0, nextFreeAt - wheelServerNow())
end

local function wheelUpdateStatus(status)
    runtime.wheelStatus = tostring(status or runtime.wheelStatus or "waiting")
    runtime.wheelStatusAt = os.clock()
end

local function wheelRequestState(now, force)
    if not force and now - runtime.wheelStateRequestAt < 1.25 then return false end
    runtime.wheelStateRequestAt = now
    local ok = pcall(function() SpinWheelEvent:FireServer("State") end)
    runtime.wheelEventReady = ok
    if ok then return true end
    wheelUpdateStatus("state request failed")
    return false
end

local function wheelApplyState(payload)
    if type(payload) ~= "table" then return end
    runtime.wheelCredits = tonumber(payload.credits) or 0
    runtime.wheelNextFreeAt = tonumber(payload.nextFreeAt) or 0
    runtime.wheelPurchasesAvailable = payload.purchasesAvailable == true
    runtime.wheelDiscountAvailable = payload.discountAvailable == true
end

local function wheelCanSpinNow(manual)
    if not SETTINGS.autoSpinWheel and not manual then return false, "disabled" end
    if LocalPlayer:GetAttribute("InMatch") == true then return false, "cannot spin in match" end
    if runtime.wheelSpinning then return false, "spinning" end
    local now = os.clock()
    local nextAttempt = tonumber(runtime.wheelNextAttemptAt) or -math.huge
    if now < nextAttempt then return false, string.format("cooldown %.1fs", nextAttempt - now) end
    local minimum = math.max(1, math.floor(tonumber(SETTINGS.wheelMinimumCredits) or 1))
    local credits = math.floor(tonumber(runtime.wheelCredits) or 0)
    if credits < minimum then return false, string.format("not enough credits (%d/%d)", credits, minimum) end
    return true, "ready"
end

local function wheelNotify(title, content)
    if not SETTINGS.wheelAnnounce then return end
    notify(title, content, 2.5)
end

local function wheelSpinOnce(manual)
    local allowed, reason = wheelCanSpinNow(manual)
    if not allowed then
        wheelUpdateStatus(reason)
        return false
    end
    local now = os.clock()
    local delay = math.clamp(tonumber(SETTINGS.wheelSpinInterval) or 6, 5.5, 30)
    runtime.wheelSpinning = true
    runtime.wheelSpinRequestAt = now
    runtime.wheelNextAttemptAt = now + delay
    runtime.wheelActionAt = now
    runtime.wheelSpinCount += 1
    wheelUpdateStatus("spin requested")
    local fired = pcall(function() SpinWheelEvent:FireServer("Spin") end)
    if not fired then
        runtime.wheelSpinning = false
        runtime.wheelNextAttemptAt = now + 1
        wheelUpdateStatus("spin request failed")
        return false
    end
    if manual then
        wheelNotify("Wheel", "Spin request sent.")
    else
        wheelNotify("Auto Spin", string.format("Spin #%d fired.", runtime.wheelSpinCount))
    end
    task.delay(0.85, function()
        runtime.wheelSpinning = false
        wheelRequestState(os.clock(), true)
    end)
    return true
end

local function autoSpinWheelStep(now)
    if not SETTINGS.autoSpinWheel then
        wheelUpdateStatus("disabled")
        return
    end
    wheelRequestState(now, false)
    local allowed, reason = wheelCanSpinNow(false)
    if allowed then
        wheelSpinOnce(false)
        return
    end
    wheelUpdateStatus(reason)
end

local MAP_VOTE_SLOT_IDS_UI = {"Map 1", "Map 2", "Map 3"}

local function getSelectedMapSlot()
    local selections = SETTINGS.mapVoteSelections or {}
    local selected = selections[1]
    if selected and table.find(MAP_VOTE_SLOT_IDS_UI, selected) then
        return selected
    end
    return nil
end

local function readMapVoteState()
    if not MapVoteState or not MapVoteState:IsA("StringValue") then
        runtime.mapVoteOpen = false
        runtime.mapVotePhase = "Unavailable"
        return nil
    end
    local ok, state = pcall(function()
        return HttpService:JSONDecode(MapVoteState.Value)
    end)
    if not ok or type(state) ~= "table" then
        runtime.mapVoteOpen = false
        runtime.mapVotePhase = "Waiting"
        return nil
    end
    local options = type(state.options) == "table" and state.options or {}
    local ids = {}
    for index = 1, math.min(#options, #MAP_VOTE_SLOT_IDS_UI) do
        local option = options[index]
        if type(option) == "table" then
            ids[index] = option.id or option.Id or option.key or option.Key
        end
    end
    runtime.mapVoteOptionIds = ids
    runtime.mapVoteToken = state.token
    runtime.mapVotePhase = tostring(state.phase or "Waiting")
    runtime.mapVoteOpen = runtime.mapVotePhase == "Voting"
    runtime.mapVoteLastStateAt = os.clock()
    return state
end

local function mapVoteOnce(manual)
    if not SETTINGS.autoMapVote and not manual then
        runtime.mapVoteStatus = "disabled"
        return false
    end
    if LocalPlayer:GetAttribute("InMatch") == true then
        runtime.mapVoteStatus = "waiting for lobby"
        return false
    end
    if LocalPlayer:GetAttribute("ClientReady") ~= true then
        runtime.mapVoteStatus = "waiting for client"
        return false
    end
    if Session:GetAttribute("GlobalPaused") == true then
        runtime.mapVoteStatus = "paused"
        return false
    end
    local state = readMapVoteState()
    if not state or runtime.mapVotePhase ~= "Voting" then
        runtime.mapVoteStatus = "waiting for vote"
        return false
    end
    local selected = getSelectedMapSlot()
    if not selected then
        runtime.mapVoteStatus = "choose Map 1, 2, or 3"
        return false
    end
    local index = table.find(MAP_VOTE_SLOT_IDS_UI, selected)
    local optionId = index and runtime.mapVoteOptionIds[index]
    if optionId == nil then
        runtime.mapVoteStatus = selected .. " unavailable"
        return false
    end
    local token = runtime.mapVoteToken
    if token == nil then
        runtime.mapVoteStatus = "vote token unavailable"
        return false
    end
    local votes = type(state.votes) == "table" and state.votes or nil
    local currentVote = votes and (votes[tostring(LocalPlayer.UserId)] or votes[LocalPlayer.UserId]) or nil
    if currentVote == optionId then
        runtime.mapVoteStatus = selected .. " already selected"
        return true
    end
    local now = os.clock()
    if now - runtime.mapVoteLastActionAt < 0.75 then return false end
    local fired = pcall(function()
        MapVoteEvent:FireServer("Vote", optionId, token)
    end)
    if not fired then
        runtime.mapVoteStatus = "vote request failed"
        return false
    end
    runtime.mapVoteLastActionAt = now
    runtime.mapVoteStatus = selected .. " vote sent"
    if SETTINGS.mapVoteAnnounce then
        notify("Map Vote", selected .. " selected.", 2.5)
    end
    return true
end

ArmoryEvent.OnClientEvent:Connect(function(kind, state)
    if kind == "State" and type(state) == "table" then
        runtime.armory = state
        runtime.armory.abilities = runtime.armory.abilities or {}
    end
end)

RescueEvent.OnClientEvent:Connect(function(kind, id)
    if kind == "Cancelled" and runtime.reviveTarget and runtime.reviveTarget.UserId == id then
        runtime.reviveStarted = false
        runtime.reviveStartAt = 0
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    runtime.profile = nil
    runtime.profileRole = nil
    runtime.lastMovePosition = nil
    runtime.moveCommandAt = -math.huge
    runtime.goal = nil
    runtime.goalMode = "SafeZone"
    runtime.goalSide = nil
    runtime.routeActive = false
    runtime.routeComplete = false
    runtime.routeStartSide = nil
    runtime.routeTargetSide = nil
    runtime.routeCompletePosition = nil
    runtime.routeCompleteAt = -math.huge
    runtime.gemTarget = nil
    runtime.reviveTarget = nil
    runtime.reviveStarted = false
    runtime.reviveStartAt = 0
    runtime.threatHistory = {}
    runtime.threats = {}
    runtime.catchers = {}
    runtime.catcherTargets = {}
    runtime.dashAt = -math.huge
    runtime.dashStatus = "idle"
    runtime.dashLastRequestAt = -math.huge
    runtime.dashLastCount = nil
    runtime.edgeRecoveryDirection = Vector3.zero
    runtime.edgeRecoveryUntil = -math.huge
    runtime.stuckRecoveryDirection = Vector3.zero
    runtime.stuckRecoveryUntil = -math.huge
    runtime.armoryAt = -math.huge
    runtime.armory = {loaded = false, abilities = {}}
    runtime.wheelScanAt = -math.huge
    runtime.wheelActionAt = -math.huge
    runtime.wheelStatus = SETTINGS.autoSpinWheel and "starting" or "disabled"
    runtime.wheelLastButton = nil
    runtime.wheelCredits = 0
    runtime.wheelNextFreeAt = 0
    runtime.wheelPurchasesAvailable = false
    runtime.wheelDiscountAvailable = false
    runtime.wheelStateRequestAt = -math.huge
    runtime.wheelSpinRequestAt = -math.huge
    runtime.wheelNextAttemptAt = -math.huge
    runtime.wheelEventReady = false
    runtime.wheelSpinning = false
    runtime.wheelLastStateAt = -math.huge
    runtime.wheelStatusAt = -math.huge
    runtime.wheelMinimumCredits = 1
end)

pcall(function() ArmoryEvent:FireServer("Get") end)

SpinWheelEvent.OnClientEvent:Connect(function(kind, payload)
    if kind == "State" and type(payload) == "table" then
        wheelApplyState(payload)
        runtime.wheelLastStateAt = os.clock()
        if payload.result or payload.message then runtime.wheelSpinning = false end
        if SETTINGS.autoSpinWheel then
            local credits = tonumber(runtime.wheelCredits) or 0
            local minimum = math.max(1, math.floor(tonumber(SETTINGS.wheelMinimumCredits) or 1))
            if credits >= minimum then
                wheelUpdateStatus("ready")
            else
                wheelUpdateStatus(string.format("waiting - credits %d/%d", math.floor(credits), minimum))
            end
            task.defer(function()
                if SETTINGS.autoSpinWheel and LocalPlayer:GetAttribute("InMatch") ~= true then
                    autoSpinWheelStep(os.clock())
                end
            end)
        end
        return
    end
    if kind == "PromptProduct" then
        runtime.wheelPurchasesAvailable = true
        wheelUpdateStatus("free credits unavailable")
        return
    end
    if type(kind) == "table" and payload == nil then
        wheelApplyState(kind)
        if SETTINGS.autoSpinWheel then
            wheelUpdateStatus("state refreshed")
            task.defer(function() autoSpinWheelStep(os.clock()) end)
        end
    end
end)

JourneyEvent.OnClientEvent:Connect(function(action, data)
    if action ~= "State" or type(data) ~= "table" then return end
    local seasonId = data.seasonId or JourneyConfig.SeasonId
    if JourneyConfig.SeasonId and seasonId ~= JourneyConfig.SeasonId then return end
    local wasClaiming = runtime.journeyClaimInFlight
    runtime.journeyLoaded = data.loaded == true
    runtime.journeySeasonId = seasonId
    runtime.journeyTier = tonumber(data.tier) or 1
    runtime.journeyPremium = data.premium == true
    runtime.journeyClaims = type(data.claims) == "table" and data.claims or {}
    runtime.journeyLastStateAt = os.clock()
    if wasClaiming then
        runtime.journeyClaimInFlight = false
        runtime.journeyClaimCount += 1
        runtime.journeyLastClaimResultAt = os.clock()
    end
    if data.message and tostring(data.message) ~= "" then
        runtime.journeyStatus = tostring(data.message)
    elseif runtime.journeyLoaded then
        local remaining = journeyClaimableCount()
        runtime.journeyStatus = remaining > 0 and string.format("%d reward%s available", remaining, remaining == 1 and "" or "s") or "ready"
    else
        runtime.journeyStatus = "loading journey state"
    end
    if (SETTINGS.autoClaimJourneyRewards or runtime.journeyManualPending) and runtime.journeyLoaded and LocalPlayer:GetAttribute("InMatch") ~= true and not runtime.journeyClaimInFlight then
        local remaining = journeyClaimableCount()
        if remaining > 0 or runtime.journeyManualPending then
            local manualPending = runtime.journeyManualPending == true
            task.delay(0.15, function()
                if (SETTINGS.autoClaimJourneyRewards or manualPending) and LocalPlayer:GetAttribute("InMatch") ~= true then
                    journeyClaimOnce(manualPending)
                end
            end)
        end
    end
end)

task.spawn(function()
    requestJourneyState(true)
    while task.wait(1.5) do
        if LocalPlayer:GetAttribute("InMatch") ~= true then
            requestJourneyState(false)
            if SETTINGS.autoClaimJourneyRewards and runtime.journeyLoaded and not runtime.journeyClaimInFlight then
                journeyClaimOnce(false)
            end
        end
    end
end)

local Window = Library:CreateWindow({
    Title = "Byte",
    Layout = "Bottom bar",
    MenuKey = Enum.KeyCode.RightShift,
})
getgenv().Window = Window

local RunnerTab = Window:AddTab("Runner", "footprints")
local CatcherTab = Window:AddTab("Catcher", "crosshair")
local WheelTab = Window:AddTab("Wheel", "rotate-cw")
local JourneyTab = Window:AddTab("Journey", "gift")

local RunnerMovement = RunnerTab:AddLeftGroupbox("Automation", "footprints")
RunnerMovement:AddToggle("runnerEnabled", {
    Text = "Auto Run",
    Default = true,
    Callback = function(v)
        SETTINGS.runnerEnabled = v == true
        if not SETTINGS.runnerEnabled then
            runtime.path = Vector3.zero
            runtime.goal = nil
            runtime.assistMode = nil
            runtime.assistTarget = nil
            runtime.sideGapDirection = Vector3.zero
            runtime.sideGapUntil = -math.huge
            cancelRevive()
        end
    end,
})
RunnerMovement:AddToggle("autoRevive", {
    Text = "Auto Revive Players",
    Default = true,
    Callback = function(v)
        SETTINGS.autoRevive = v == true
        if not v then cancelRevive() end
    end,
})

local UnlockAllGroup = RunnerTab:AddLeftGroupbox("Unlock All", "unlock")

getgenv().ByteKnifeUnlocker = (function()
    local isEnabled = false
    local currentKnifeModel = nil
    local holdTrack = nil
    local swingTrack = nil
    local lastSwing = 0
    local uiHooked = false
    
    local SAVE_FILE = "Byte/HussValley/LastEquippedKnife.txt"
    
    if makefolder then
        pcall(makefolder, "Byte")
        pcall(makefolder, "Byte/HussValley")
    end

    local function saveKnife(id)
        if writefile then pcall(writefile, SAVE_FILE, id) end
        getgenv().Byte_LastKnife = id
    end
    
    local function loadKnife()
        if isfile and isfile(SAVE_FILE) then
            local ok, data = pcall(readfile, SAVE_FILE)
            if ok and type(data) == "string" and data ~= "" then return data end
        end
        return getgenv().Byte_LastKnife
    end
    
    local spoofedEquipped = loadKnife()

    local ALL_IDS = {}
    for _, id in ipairs(SkinCatalog.Order) do if type(id) == "string" then ALL_IDS[id] = true end end
    for id in pairs(SkinCatalog.Skins) do ALL_IDS[id] = true end

    local function forceOwned(state)
        if type(state) ~= "table" then return end
        if type(state.owned) ~= "table" then state.owned = {} end
        for id in pairs(ALL_IDS) do state.owned[id] = true end
        if spoofedEquipped then state.equipped = spoofedEquipped end
    end

    local oldUpdate = StorefrontClient.update
    StorefrontClient.update = function(self, state)
        if isEnabled then forceOwned(state) end
        return oldUpdate(self, state)
    end

    local function hookUI()
        if uiHooked then return end
        local armoryGui = LocalPlayer.PlayerGui:FindFirstChild("ValleyArmory")
        if not armoryGui then return end
        local actionBtn = armoryGui.Overlay.Canvas.Details.Action
        
        if getconnections then
            for _, conn in ipairs(getconnections(actionBtn.Activated)) do
                if conn.Function then
                    local oldFunc = conn.Function
                    conn:Disable()
                    actionBtn.Activated:Connect(function()
                        if not isEnabled then return pcall(oldFunc, actionBtn) end
                        local title = armoryGui.Overlay.Canvas.Details.Title.Text
                        local foundId = nil
                        for id, data in pairs(SkinCatalog.Skins) do
                            if data.Name == title then foundId = id break end
                        end
                        if foundId then
                            spoofedEquipped = foundId
                            saveKnife(foundId) 
                            task.spawn(function() pcall(function() ArmoryEvent:FireServer("Get") end) end)
                            applyVisualKnife(spoofedEquipped)
                        else
                            pcall(oldFunc, actionBtn)
                        end
                    end)
                    uiHooked = true
                end
            end
        end
    end

    local function cleanUp()
        if currentKnifeModel then currentKnifeModel:Destroy(); currentKnifeModel = nil end
        if holdTrack then holdTrack:Stop() end
        if swingTrack then swingTrack:Stop() end
        
        local char = LocalPlayer.Character
        if char then
            for _, child in ipairs(char:GetChildren()) do
                if child:IsA("Model") or child:IsA("Tool") then
                    for _, desc in ipairs(child:GetDescendants()) do
                        if desc:IsA("BasePart") then desc.Transparency = desc:GetAttribute("OriginalTransparency") or 0 end
                        if desc:IsA("ParticleEmitter") or desc:IsA("Beam") then desc.Enabled = true end
                    end
                end
            end
        end
    end

    local function playAnim(actionName)
        local char = LocalPlayer.Character
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
        if not currentKnifeModel or not animator then return end

        local animId = KnifeClips.id(currentKnifeModel, actionName)
        if not animId then return end

        local anim = Instance.new("Animation")
        anim.AnimationId = animId
        
        if actionName == "Hold" then
            if holdTrack then holdTrack:Stop() end
            holdTrack = animator:LoadAnimation(anim)
            holdTrack.Priority = Enum.AnimationPriority.Action
            holdTrack.Looped = true
            holdTrack:Play(0.1)
        elseif actionName == "Stab" then
            if swingTrack then swingTrack:Stop() end
            swingTrack = animator:LoadAnimation(anim)
            swingTrack.Priority = Enum.AnimationPriority.Action2
            swingTrack:Play(0.1)
            task.delay(swingTrack.Length - 0.1, function()
                if currentKnifeModel and holdTrack and not holdTrack.IsPlaying then
                    holdTrack:Play(0.1)
                end
            end)
        end
    end

    function applyVisualKnife(knifeId)
        local char = LocalPlayer.Character
        if not char then return end
        
        local rightArm = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
        local leftArm = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm")
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if not rightArm or not torso or not leftArm then return end
        
        local knifeModel = Weapons.Models:FindFirstChild(knifeId)
        if not knifeModel then return end
        
        cleanUp()
        
        local gripC0 = knifeModel:GetAttribute("GripC0") or CFrame.new(-0.006, -0.856, -0.063)
        local stowedOffset = knifeModel:GetAttribute("StowedOffset") or CFrame.new(0, 0, 0.84)
        local isDual = knifeModel:GetAttribute("IsDualWield") == true

        local realKnife = char:FindFirstChild("EquippedDagger") or char:FindFirstChildWhichIsA("Tool")
        if realKnife then
            for _, desc in ipairs(realKnife:GetDescendants()) do
                if desc:IsA("BasePart") then
                    desc:SetAttribute("OriginalTransparency", desc.Transparency)
                    desc.Transparency = 1
                elseif desc:IsA("ParticleEmitter") or desc:IsA("Beam") then
                    desc.Enabled = false
                end
            end
        end

        local clone = knifeModel:Clone()
        clone.Name = knifeId
        currentKnifeModel = clone
        
        local handle = clone:FindFirstChild("Handle")
        local blade = clone:FindFirstChild("Blade")
        local stowedBlade = clone:FindFirstChild("StowedBlade")

        for _, desc in ipairs(clone:GetDescendants()) do
            if desc.Name == "HeldVFX_CurveBend" then 
                desc.Transparency = 1
            elseif desc:IsA("BasePart") then
                desc.Anchored = false; desc.CanCollide = false; desc.Massless = true
            end
        end

        clone.Parent = char
        local role = LocalPlayer:GetAttribute("GameRole") or "Lobby"
        local isCatcher = (role == "Catcher" or role == "Chaser" or role == "Catch" or role == "ChaserTeam")

        if isCatcher then
            if blade then blade.Transparency = 0 end
            if stowedBlade then stowedBlade.Transparency = 1 end
            if handle then handle.Transparency = 0 end
            
            local rightMotor = Instance.new("Motor6D")
            rightMotor.Name = "Handle"
            rightMotor.Part0 = rightArm
            rightMotor.Part1 = handle
            rightMotor.C0 = gripC0
            rightMotor.Parent = rightArm
            
            if isDual and successDual and DualWield then
                pcall(function() DualWield.attach(clone, leftArm) end)
            end
            playAnim("Hold")
        else
            if blade then blade.Transparency = 1 end
            if handle then handle.Transparency = 1 end
            if stowedBlade then stowedBlade.Transparency = 0 end

            local rightWeld = Instance.new("Weld")
            rightWeld.Name = "StowedDagger"
            rightWeld.Part0 = torso
            rightWeld.Part1 = stowedBlade
            rightWeld.C0 = stowedOffset
            rightWeld.Parent = stowedBlade
            
            local handleWeld = Instance.new("Weld")
            handleWeld.Part0 = stowedBlade
            handleWeld.Part1 = handle
            handleWeld.Parent = handle

            if isDual and successDual and DualWield then
                pcall(function() DualWield.stow(clone, torso) end)
            end
        end
    end

    local inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not isEnabled or gameProcessed then return end
        local role = LocalPlayer:GetAttribute("GameRole") or "Lobby"
        local isCatcher = (role == "Catcher" or role == "Chaser" or role == "Catch" or role == "ChaserTeam")
        
        if isCatcher and currentKnifeModel and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.Space) then
            if os.clock() - lastSwing > 0.3 then
                lastSwing = os.clock()
                if holdTrack then holdTrack:Stop() end
                playAnim("Stab")
            end
        end
    end)

    task.spawn(function()
        while true do
            task.wait(1)
            if isEnabled and getconnections then
                for _, conn in ipairs(getconnections(UserInputService.InputBegan)) do
                    local func = conn.Function
                    if func then
                        local src = debug.info(func, "s")
                        if src and string.find(src, "KnifeClipPreview") then
                            conn:Disable()
                        end
                    end
                end
            end
        end
    end)

    local roleConn = LocalPlayer:GetAttributeChangedSignal("GameRole"):Connect(function()
        if not isEnabled then return end
        task.wait(0.5)
        applyVisualKnife(spoofedEquipped or SkinCatalog.Default)
    end)

    local charConn = LocalPlayer.CharacterAdded:Connect(function()
        if not isEnabled then return end
        task.wait(1.5)
        applyVisualKnife(spoofedEquipped or SkinCatalog.Default)
    end)

    local armoryConn = ArmoryEvent.OnClientEvent:Connect(function(kind, state)
        if not isEnabled then return end
        if kind == "State" and type(state) == "table" then
            task.delay(0.5, hookUI)
        end
    end)

    return {
        Enable = function()
            isEnabled = true
            if not spoofedEquipped then
                spoofedEquipped = loadKnife()
            end
            pcall(function() ArmoryEvent:FireServer("Get") end)
            task.spawn(function()
                while isEnabled do
                    task.wait(2)
                    pcall(function() ArmoryEvent:FireServer("Get") end)
                end
            end)
            if LocalPlayer.Character then applyVisualKnife(spoofedEquipped or SkinCatalog.Default) end
        end,
        Disable = function()
            isEnabled = false
            cleanUp()
            spoofedEquipped = nil
        end
    }
end)()

UnlockAllGroup:AddToggle("unlockAllKnives", {
    Text = "Visual Unlock All",
    Default = false,
    Callback = function(v)
        SETTINGS.knifeUnlockEnabled = v
        if v then
            getgenv().ByteKnifeUnlocker.Enable()
            notify("Byte", "Visual Knife Unlocker Enabled", 3)
        else
            getgenv().ByteKnifeUnlocker.Disable()
            notify("Byte", "Visual Knife Unlocker Disabled", 3)
        end
    end,
})

local RunnerSafety = RunnerTab:AddRightGroupbox("Protection/Gems", "shield")
RunnerSafety:AddToggle("reviveBeforeGems", {
    Text = "Revive First",
    Default = true,
    Callback = function(v)
        SETTINGS.reviveBeforeGems = v == true
    end,
})
RunnerSafety:AddToggle("autoGems", {
    Text = "Auto Collect Gems",
    Default = true,
    Callback = function(v)
        SETTINGS.autoGems = v == true
        if not v then runtime.gemTarget = nil end
    end,
})
RunnerSafety:AddToggle("autoCandy", {
    Text = "Auto Collect Candy Corn",
    Default = true,
    Callback = function(v)
        SETTINGS.autoCandy = v == true
        if not v then runtime.gemTarget = nil end
    end,
})
RunnerSafety:AddToggle("avoidCatchers", {
    Text = "Avoid Catchers",
    Default = true,
    Callback = function(v)
        SETTINGS.avoidCatchers = v == true
    end,
})
RunnerSafety:AddToggle("autoDash", {
    Text = "Auto Dash",
    Default = true,
    Callback = function(v)
        SETTINGS.autoDash = v == true
    end,
})
RunnerSafety:AddSlider("predictionTime", {
    Text = "Runner Threat Prediction",
    Min = 0.25,
    Max = 1.1,
    Default = 0.65,
    Rounding = 2,
    Callback = function(v)
        local snapped = math.floor(((tonumber(v) or 0.65) + 0.025) / 0.05) * 0.05
        snapped = math.clamp(snapped, 0.25, 1.1)
        snapped = math.floor(snapped * 100 + 0.5) / 100
        SETTINGS.predictionTime = snapped
        if math.abs(snapped - v) > 0.001 and Options and Options.predictionTime then
            pcall(function() Options.predictionTime:SetValue(snapped) end)
        end
    end,
})
RunnerSafety:AddSlider("panicDistance", {
    Text = "Threat Distance",
    Min = 8,
    Max = 25,
    Default = 15,
    Rounding = 0,
    Callback = function(v)
        local snapped = math.floor((tonumber(v) or 15) + 0.5)
        snapped = math.clamp(snapped, 8, 25)
        SETTINGS.panicDistance = snapped
        if Options and Options.panicDistance then
            pcall(function() Options.panicDistance:SetValue(snapped) end)
        end
    end,
})

local RunnerSmoothing = RunnerTab:AddRightGroupbox("Movement", "move")
RunnerSmoothing:AddToggle("smoothMovement", {
    Text = "Smooth Direction Changes",
    Default = true,
    Callback = function(v)
        SETTINGS.smoothMovement = v == true
    end,
})
RunnerSmoothing:AddToggle("emergencySafeZone", {
    Text = "Emergency Safe Zone",
    Default = true,
    Callback = function(v)
        SETTINGS.emergencySafeZone = v == true
    end,
})
RunnerSmoothing:AddSlider("avoidStrength", {
    Text = "Avoidance Strength",
    Min = 0.5,
    Max = 2.5,
    Default = 1.8,
    Rounding = 1,
    Callback = function(v)
        local snapped = math.floor(((tonumber(v) or 1.8) + 0.05) / 0.1) * 0.1
        snapped = math.clamp(snapped, 0.5, 2.5)
        snapped = math.floor(snapped * 10 + 0.5) / 10
        SETTINGS.avoidStrength = snapped
        if Options and Options.avoidStrength then
            pcall(function() Options.avoidStrength:SetValue(snapped) end)
        end
    end,
})

RunnerSmoothing:AddToggle("showPath", {
    Text = "Show Path Line",
    Default = true,
    Callback = function(v)
        SETTINGS.showPath = v == true
        if not v and pathVisual.beam then
            pathVisual.beam.Enabled = false
        end
    end,
})

local CatcherCombat = CatcherTab:AddLeftGroupbox("Targeting and Combat", "crosshair")
CatcherCombat:AddToggle("catcherChase", {
    Text = "Auto Chase",
    Default = true,
    Callback = function(v)
        SETTINGS.catcherChase = v == true
        if not SETTINGS.catcherChase then
            runtime.catcherTarget = nil
            runtime.catcherPath = Vector3.zero
        end
    end,
})
CatcherCombat:AddDropdown("catcherAttackPriority", {
    Text = "Attack Priority",
    Values = {"Smart", "Tackle First", "Melee First"},
    Default = "Smart",
    Callback = function(v)
        if type(v) == "table" then v = v[1] end
        if v == "Smart" or v == "Tackle First" or v == "Melee First" then
            SETTINGS.catcherAttackPriority = v
        end
    end,
})
CatcherCombat:AddToggle("smartPriority", {
    Text = "Smart Targeting",
    Default = true,
    Callback = function(v)
        SETTINGS.smartPriority = v == true
    end,
})

local CatcherMovement = CatcherTab:AddRightGroupbox("Movement", "move")
CatcherMovement:AddToggle("smoothTurn", {
    Text = "Smooth Turning",
    Default = true,
    Callback = function(v)
        SETTINGS.smoothTurn = v == true
    end,
})
CatcherMovement:AddSlider("turnRateCatcher", {
    Text = "Turn Response",
    Min = 5,
    Max = 30,
    Default = 14,
    Rounding = 0,
    Callback = function(v)
        local snapped = math.floor((tonumber(v) or 14) + 0.5)
        snapped = math.clamp(snapped, 5, 30)
        SETTINGS.turnRateCatcher = snapped
        if Options and Options.turnRateCatcher then
            pcall(function() Options.turnRateCatcher:SetValue(snapped) end)
        end
    end,
})
CatcherMovement:AddToggle("followTarget", {
    Text = "Follow Target (Camera)",
    Default = false,
    Callback = function(v)
        SETTINGS.followTarget = v == true
    end,
})

local WheelAuto = WheelTab:AddLeftGroupbox("Automatic Spin", "rotate-cw")
WheelAuto:AddToggle("autoSpinWheel", {
    Text = "Enable Auto Spin",
    Default = false,
    Callback = function(v)
        SETTINGS.autoSpinWheel = v == true
        runtime.wheelSpinning = false
        runtime.wheelNextAttemptAt = -math.huge
        if SETTINGS.autoSpinWheel then
            runtime.wheelStatus = "refreshing state"
            wheelRequestState(os.clock(), true)
            notify("Auto Spin", "Started.", 2.5)
        else
            runtime.wheelStatus = "disabled"
            notify("Auto Spin", "Stopped.", 2.5)
        end
    end,
})
WheelAuto:AddSlider("wheelSpinInterval", {
    Text = "Delay Between Spins",
    Min = 5.5,
    Max = 30,
    Default = 6,
    Rounding = 1,
    Callback = function(v)
        local snapped = math.floor(((tonumber(v) or 6) + 0.25) / 0.5) * 0.5
        snapped = math.clamp(snapped, 5.5, 30)
        snapped = math.floor(snapped * 10 + 0.5) / 10
        SETTINGS.wheelSpinInterval = snapped
        if Options and Options.wheelSpinInterval then
            pcall(function() Options.wheelSpinInterval:SetValue(snapped) end)
        end
    end,
})
WheelAuto:AddSlider("wheelMinimumCredits", {
    Text = "Minimum Credits",
    Min = 1,
    Max = 50,
    Default = 1,
    Rounding = 0,
    Callback = function(v)
        local snapped = math.floor((tonumber(v) or 1) + 0.5)
        snapped = math.clamp(snapped, 1, 50)
        SETTINGS.wheelMinimumCredits = snapped
        runtime.wheelMinimumCredits = snapped
        if Options and Options.wheelMinimumCredits then
            pcall(function() Options.wheelMinimumCredits:SetValue(snapped) end)
        end
    end,
})
WheelAuto:AddToggle("wheelAnnounce", {
    Text = "Spin Notification",
    Default = true,
    Callback = function(v)
        SETTINGS.wheelAnnounce = v == true
    end,
})

local WheelRewardsGroup = WheelTab:AddRightGroupbox("Auto Claim", "gift")
WheelRewardsGroup:AddToggle("autoClaimJourneyRewards", {
    Text = "Auto Claim Journey Rewards",
    Default = false,
    Callback = function(v)
        SETTINGS.autoClaimJourneyRewards = v == true
        runtime.journeyClaimInFlight = false
        runtime.journeyNextClaimAt = -math.huge
        if SETTINGS.autoClaimJourneyRewards then
            runtime.journeyStatus = "checking rewards"
            requestJourneyState(true)
        else
            runtime.journeyManualPending = false
            runtime.journeyStatus = "disabled"
        end
    end,
})

local MapVoteTab = Window:AddTab("Map Vote", "map")
local Settings = Window:CreateSettingsTab()

local MapVoteGroup = MapVoteTab:AddLeftGroupbox("Voting", "map")

SETTINGS.mapVoteSelections = {"Map 1"}

MapVoteGroup:AddDropdown("mapVoteChoice", {
    Text = "Preferred Map",
    Values = {"Map 1", "Map 2", "Map 3"},
    Default = "Map 1",
    Callback = function(v)
        local selected = v
        if type(v) == "table" then selected = v[1] end
        selected = tostring(selected or "")
        if table.find({"Map 1", "Map 2", "Map 3"}, selected) then
            SETTINGS.mapVoteSelections = {selected}
            runtime.mapVoteStatus = selected .. " selected"
            if SETTINGS.autoMapVote then
                task.defer(function() mapVoteOnce(false) end)
            end
        end
    end,
})

MapVoteGroup:AddToggle("autoMapVote", {
    Text = "Auto Vote",
    Default = false,
    Callback = function(v)
        SETTINGS.autoMapVote = v == true
        runtime.mapVoteLastActionAt = -math.huge
        if SETTINGS.autoMapVote then
            runtime.mapVoteStatus = "starting"
            readMapVoteState()
            task.defer(function() mapVoteOnce(false) end)
        else
            runtime.mapVoteStatus = "disabled"
        end
    end,
})

MapVoteGroup:AddToggle("mapVoteAnnounce", {
    Text = "Vote Notification",
    Default = true,
    Callback = function(v)
        SETTINGS.mapVoteAnnounce = v == true
    end,
})

local SettingsInterface = Settings:AddLeftGroupbox("Interface", "layers")
SettingsInterface:AddToggle("notifications", {
    Text = "Notifications",
    Default = true,
    Callback = function(v)
        SETTINGS.notifications = v == true
    end,
})

local SettingsControls = Settings:AddRightGroupbox("Controls", "power")
SettingsControls:AddButton({
    Text = "Unload All",
    DoubleClick = true,
    Callback = function()
        if Hub.cleanup then
            Hub.cleanup()
        end
    end,
})

task.spawn(function()
    while MapVoteState and MapVoteState.Parent do
        task.wait(0.5)
        readMapVoteState()
        if SETTINGS.autoMapVote then
            mapVoteOnce(false)
        end
    end
end)

if MapVoteState and MapVoteState:IsA("StringValue") then
    MapVoteState.Changed:Connect(function()
        readMapVoteState()
        if SETTINGS.autoMapVote then
            task.defer(function() mapVoteOnce(false) end)
        end
    end)
end

local RENDER_NAME = "Byte_Controller"
RunService:UnbindFromRenderStep(RENDER_NAME)
RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Input.Value, function(dt)
    local now = os.clock()
    local ok, err = pcall(runnerStep, now, dt)
    if not ok then warn("[Byte Runner]", err) end
    ok, err = pcall(catcherStep, now, dt)
    if not ok then warn("[Byte Catcher]", err) end
    pcall(updatePathVisual)
    if SETTINGS.autoSpinWheel and now - runtime.utilityTick >= 0.25 then
        runtime.utilityTick = now
        pcall(autoSpinWheelStep, now)
    end
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("Byte")
SaveManager:SetFolder("Byte/Configs")
ThemeManager:LoadDefault()

SaveManager:BuildConfigSection(Settings) 

SaveManager:LoadAutoloadConfig()

local function cleanup()
    if Hub.cleaned then return end
    Hub.cleaned = true
    pcall(function() RunService:UnbindFromRenderStep("Byte_Controller") end)
    pcall(function() cancelRevive() end)
    pcall(cleanupVisuals)
    pcall(clearPathVisual)
    if runtime.debugGui and runtime.debugGui.Parent then
        pcall(function() runtime.debugGui:Destroy() end)
    end
    if Hub.idleConn then
        pcall(function() Hub.idleConn:Disconnect() end)
        Hub.idleConn = nil
    end
    pcall(function() Library:Unload() end)
end

Hub.cleanup = cleanup
Hub.genv.ByteUnload = cleanup

notify("Byte", "Loaded. Auto Run is enabled by default.", 3)
