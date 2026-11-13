local repo = "https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "SaveManager.lua"))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer
local GEN = (rawget(_G, "Byte_THROW_GEN") or 0) + 1
rawset(_G, "Byte_THROW_GEN", GEN)

local function f1(p)
  local ok, v = pcall(require, p)
  return ok and v or nil
end

local controllers = LP:WaitForChild("PlayerScripts"):WaitForChild("Client"):WaitForChild("Controllers")

local G = {}
G.Data = f1(controllers:WaitForChild("DataController"))
G.Throw = f1(controllers:WaitForChild("ThrowController"))
G.Meter = f1(controllers:WaitForChild("ThrowMeter"))
G.Train = f1(controllers:WaitForChild("TrainingController"))
G.State = f1(controllers:WaitForChild("ClientState"))
G.Remotes = f1(ReplicatedStorage.Shared.Remotes)
G.Economy = f1(ReplicatedStorage.Config.AnimalEconomy)
G.Mut = f1(ReplicatedStorage.Shared.Mutations)
G.Foods = f1(ReplicatedStorage.Config.FoodsConfig)
G.Stands = f1(ReplicatedStorage.Config.StandsConfig)
G.Fence = f1(ReplicatedStorage.Config.FenceConfig)
G.Level = f1(ReplicatedStorage.Config.LevelConfig)
G.Areas = f1(ReplicatedStorage.Config.AreasConfig)
G.Fmt = f1(ReplicatedStorage.Shared.NumberFormat)
G.HUD = f1(controllers:WaitForChild("HUDController"))

local function get(key)
  return G.Data and G.Data:Get(key)
end

local function invoke(name, ...)
  local args = { ... }
  local ok, res = pcall(function()
    return G.Remotes.Invoke(name, table.unpack(args))
  end)
  if not ok then return { Ok = false, Reason = tostring(res) } end
  return type(res) == "table" and res or { Ok = false, Reason = "nil" }
end

local S = {
  throwMode = "Normal",
  sellRar = {},
  antiAfk = true,
  equipBest = true,
  tap = true,
  alive = true,
  fastEquip = true,
}

local connections = {}

if G.Meter and G.Meter.new then
  local orig = G.Meter.new
  G._origMeterNew = orig
  G.Meter.new = function(...)
    local obj = orig(...)
    if (S.throw or S.farm) and obj then
      pcall(function() obj:SetLocked(true) end)
    end
    return obj
  end
end

if G.HUD and G.HUD.SetGameplayVisible then
  local orig = G.HUD.SetGameplayVisible
  G._origSetGameplay = orig
  G.HUD.SetGameplayVisible = function(self, copy, ...)
    if not self and S.alive then
      copy = type(copy) == "table" and table.clone(copy) or {}
      for _, name in ipairs({ "Viz", "VizNotify", "ByteWatermark" }) do
        copy[name] = true
      end
    end
    return orig(self, copy, ...)
  end
end

local function setName(control, text)
  pcall(function() control:SetText(text) end)
end

local function loop(control, interval, fn)
  task.spawn(function()
    while S.alive do
      local ok, err = pcall(fn)
      if not ok and control then
        setName(control, "Error: " .. tostring(err))
      end
      task.wait(type(interval) == "function" and interval() or interval)
    end
  end)
end

local finishedCount = 0
if G.Throw and G.Throw.Finished then
  local ok, conn = pcall(function()
    return G.Throw.Finished:Connect(function() finishedCount += 1 end)
  end)
  if ok and conn then
    if type(conn) == "table" and type(conn.Disconnect) == "function" then
      table.insert(connections, conn)
    elseif type(conn) == "function" then
      table.insert(connections, { Disconnect = conn })
    end
  end
end

local meterRuns = 0
if G.Meter and G.Meter.Run then
  local origRun = G.Meter.Run
  G._origMeterRun = origRun
  G.Meter.Run = function(self, ...)
    meterRuns += 1
    if S.super and (tonumber(get("SuperThrows")) or 0) > 0 then
      invoke("Throw_UseSuper")
    end
    return origRun(self, ...)
  end
end

local function snapshotState()
  local animals = 0
  for _ in pairs(get("Animals") or {}) do animals += 1 end
  return {
    xp = tonumber(get("Xp")) or 0,
    level = tonumber(get("Level")) or 1,
    animals = animals,
    superThrows = tonumber(get("SuperThrows")) or 0,
    throws = tonumber(get("Throws")) or 0,
  }
end

local WatermarkGui = nil

local function CreateWatermark()
  if WatermarkGui then return WatermarkGui end

  local g = Instance.new("ScreenGui")
  g.Name = "ByteWatermark"
  g.ResetOnSpawn = false
  g.IgnoreGuiInset = true
  g.DisplayOrder = 999

  local parent
  if typeof(gethui) == "function" then
    local ok, hui = pcall(gethui)
    if ok and hui and pcall(function() g.Parent = hui end) then parent = hui end
  end
  if not parent then
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg and pcall(function() g.Parent = cg end) then parent = cg end
  end
  if not parent then
    local pg = LP:FindFirstChild("PlayerGui") or LP:WaitForChild("PlayerGui", 5)
    if pg and pcall(function() g.Parent = pg end) then parent = pg end
  end
  if not parent then g:Destroy() return nil end

  local frame = Instance.new("Frame")
  frame.Size = UDim2.fromOffset(0, 32)
  frame.AutomaticSize = Enum.AutomaticSize.X
  frame.Position = UDim2.new(0.5, 0, 0, 10)
  frame.AnchorPoint = Vector2.new(0.5, 0)
  frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
  frame.BackgroundTransparency = 0.1
  frame.BorderSizePixel = 0
  frame.Parent = g

  local layout = Instance.new("UIListLayout")
  layout.FillDirection = Enum.FillDirection.Horizontal
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.VerticalAlignment = Enum.VerticalAlignment.Center
  layout.Padding = UDim.new(0, 8)
  layout.Parent = frame

  local padding = Instance.new("UIPadding")
  padding.PaddingLeft = UDim.new(0, 10)
  padding.PaddingRight = UDim.new(0, 14)
  padding.Parent = frame

  Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

  local stroke = Instance.new("UIStroke")
  stroke.Color = Color3.fromRGB(50, 50, 50)
  stroke.Thickness = 1
  stroke.Parent = frame

  local logo = Instance.new("ImageLabel")
  logo.Size = UDim2.fromOffset(20, 20)
  logo.Position = UDim2.new(0, 8, 0.5, -10)
  logo.BackgroundTransparency = 1
  logo.Image = "rbxassetid://95943456246483"
  logo.ScaleType = Enum.ScaleType.Fit
  logo.Parent = frame

  local title = Instance.new("TextLabel")
  title.Size = UDim2.fromOffset(0, 32)
  title.AutomaticSize = Enum.AutomaticSize.X
  title.BackgroundTransparency = 1
  title.Text = "Byte"
  title.TextColor3 = Color3.new(1, 1, 1)
  title.TextSize = 14
  title.Font = Enum.Font.GothamBold
  title.TextXAlignment = Enum.TextXAlignment.Left
  title.LayoutOrder = 2
  title.Parent = frame

  local info = Instance.new("TextLabel")
  info.Size = UDim2.fromOffset(0, 32)
  info.AutomaticSize = Enum.AutomaticSize.X
  info.BackgroundTransparency = 1
  info.TextColor3 = Color3.fromRGB(220, 220, 220)
  info.TextSize = 13
  info.Font = Enum.Font.Gotham
  info.TextXAlignment = Enum.TextXAlignment.Left
  info.LayoutOrder = 3
  info.Parent = frame

  local frames, lastUpdate = 0, tick()
  local region = "Loading..."

  task.spawn(function()
    local function findRegion()
      local pg = LP:FindFirstChild("PlayerGui")
      if pg then
        for _, d in ipairs(pg:GetDescendants()) do
          if d:IsA("TextLabel") and d.Text:find("Server Region:") then
            return (string.gsub(d.Text, "Server Region:%s*", ""))
          end
        end
      end
      local jid = game.JobId
      if jid and #jid > 0 then return string.upper(string.sub(jid, 1, 4)) end
      return "Unknown"
    end
    region = findRegion()
  end)

  connections.Watermark_FPS = RunService.RenderStepped:Connect(function()
    frames = frames + 1
    local now = tick()
    if now - lastUpdate >= 1 then
      local ping = 0
      local p = Stats.Network.ServerStatsItem:FindFirstChild("Data Ping")
      if p then ping = math.floor(p:GetValue()) end
      info.Text = string.format("%s | %d FPS | %d MS | %s", os.date("%H:%M:%S"), math.floor(frames / (now - lastUpdate)), ping, region)
      frames, lastUpdate = 0, now
    end
  end)

  local dragging, start, startPos
  connections.Watermark_DragStart = frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      dragging, start, startPos = true, input.Position, frame.Position
    end
  end)
  connections.Watermark_DragMove = UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
      local d = input.Position - start
      frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
  end)
  connections.Watermark_DragEnd = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
      dragging = false
    end
  end)

  WatermarkGui = g
  return g
end

local NR_Enabled = false
local NR_Gen = 0
local NR_Store = {}
local NR_Pinned = { [Lighting] = true, [workspace.Terrain] = true }
local NR_HiddenParts = {}
local NR_HiddenGuis2 = {}
local NR_HiddenGuis = {}
local NR_LightingSeen = {}
local NR_FloorParts = {}
local NR_LobbyDestroyed = {}
local NR_InMatch = false
local NR_ZERO = NumberRange.new(0)

local NR_Render
pcall(function() NR_Render = settings().Rendering end)
if NR_Render then NR_Pinned[NR_Render] = true end

local NR_LIGHTING = {
  GlobalShadows = false, Brightness = 1, ClockTime = 14,
  ExposureCompensation = 0, EnvironmentDiffuseScale = 0,
  EnvironmentSpecularScale = 0, FogStart = math.huge, FogEnd = math.huge,
  ShadowSoftness = 0, Ambient = Color3.fromRGB(70, 70, 70), OutdoorAmbient = Color3.fromRGB(70, 70, 70),
}

local NR_MAP_FOLDERS = {
  Map = true, LobbySpawnPlate = true, Spawn = true, Leaderboards = true,
  Drones = true, ZombieCrownClash = true, PixelKillEvent = true,
  SummerEventBB = true, FriendCrate = true, MapBounds = true,
}
local NR_LOBBY_FOLDERS = {
  Spawn = true, Leaderboards = true, LobbySpawnPlate = true,
  Drones = true, ZombieCrownClash = true, PixelKillEvent = true,
  SummerEventBB = true, FriendCrate = true,
}
local NR_LOBBY_GUI = {
  LobbyTickets = true, LobbyLTMPack = true, LobbyJoinIssue = true,
  MobileLobbyPrompt = true, ServerBrowser = true, ServerBrowserOld = true,
  ServerSelection = true, ServerSelectionNew = true, ChooseMap = true,
  MapSelector = true, RankedQueue = true, RankedSelection = true,
  MatchFound = true, ChooserUI = true, WaitingScreen = true,
  TournamentWaiting = true, CutsceneWaiting = true, spawnTut = true,
}
local NR_WEAPON_NAMES = {
  Weapons = true, Weapon = true, Gun = true, Guns = true,
  ViewModel = true, Viewmodel = true, viewmodel = true,
  FPArms = true, FPSArms = true, Arms = true, ArmsFolder = true,
  Tool = true, Tools = true, EquippedTool = true, EquippedTools = true,
  Firearm = true, Firearms = true, Handgun = true, Rifle = true,
  Pistol = true, Shotgun = true, Melee = true, Blade = true,
  Sword = true, Knife = true, WeaponModel = true, WeaponModels = true,
  LocalWeapon = true, CharacterWeapons = true, HeldTool = true,
}

local function NR_isGameplay(inst)
  local p = inst
  while p and p ~= workspace do
    if p.Name == "Balls" or p.Name == "Alive" or p.Name == "Runtime" then return true end
    p = p.Parent
  end
  return false
end

local function NR_isIgnored(inst)
  local p = inst
  while p and p ~= workspace do
    if p:GetAttribute("NoRender_Ignore") then return true end
    p = p.Parent
  end
  return false
end

local function NR_isProtected(inst)
  if not inst then return false end
  if inst:IsA("Tool") or inst:FindFirstAncestorOfClass("Tool") then return true end
  local char = LP.Character
  if char and (inst == char or inst:IsDescendantOf(char)) then return true end
  local cam = workspace.CurrentCamera
  if cam and (inst == cam or inst:IsDescendantOf(cam)) then return true end
  local p = inst
  while p and p ~= workspace do
    if NR_WEAPON_NAMES[p.Name] then return true end
    p = p.Parent
  end
  local anc = inst:FindFirstAncestorOfClass("Model")
  if anc and anc:FindFirstChildOfClass("Humanoid") then return true end
  return false
end

local function NR_isMap(part)
  local p = part.Parent
  while p and p ~= workspace do
    if NR_MAP_FOLDERS[p.Name] then return true end
    p = p.Parent
  end
  return part.Anchored and not NR_isGameplay(part)
end

local function NR_get(inst, prop) return inst[prop] end
local function NR_put(inst, prop, val) inst[prop] = val end

local function NR_set(inst, prop, val)
  local getter, setter = NR_get, NR_put
  if prop == "Decoration" then getter, setter = gethiddenproperty, sethiddenproperty end
  if not (getter and setter) then return end
  local ok, cur = true, getter(inst, prop)
  if not ok or cur == val then return end
  setter(inst, prop, val)
  local props = NR_Store[inst] or {}
  NR_Store[inst] = props
  if props[prop] == nil then props[prop] = cur end
end

local function NR_restoreAll()
  for inst, props in pairs(NR_Store) do
    if NR_Pinned[inst] or inst.Parent then
      for prop, val in pairs(props) do
        local setter = (prop == "Decoration") and sethiddenproperty or NR_put
        if setter then setter(inst, prop, val) end
      end
    end
  end
  table.clear(NR_Store)
end

local function NR_off(obj) NR_set(obj, "Enabled", false) end
local function NR_hide(obj) NR_set(obj, "Transparency", 1) end
local function NR_offClear(obj) NR_set(obj, "Enabled", false); obj:Clear() end

local NR_HANDLERS = {
  ParticleEmitter = function(o) NR_set(o, "Lifetime", NR_ZERO); NR_offClear(o) end,
  Trail = NR_offClear, Beam = NR_off, Smoke = NR_off, Fire = NR_off, Sparkles = NR_off,
  Highlight = NR_off, Clouds = NR_off,
  PointLight = NR_off, SpotLight = NR_off, SurfaceLight = NR_off,
  BloomEffect = NR_off, BlurEffect = NR_off, ColorCorrectionEffect = NR_off,
  DepthOfFieldEffect = NR_off, SunRaysEffect = NR_off, ColorGradingEffect = NR_off,
  Decal = NR_hide, Texture = NR_hide,
  Explosion = function(o) NR_set(o, "Visible", false) end,
  Atmosphere = function(o) NR_set(o, "Density", 0); NR_set(o, "Haze", 0); NR_set(o, "Glare", 0) end,
  Sky = function(o) NR_set(o, "CelestialBodiesShown", false); NR_set(o, "StarCount", 0) end,
}

local function NR_apply(obj)
  if NR_isIgnored(obj) or NR_isProtected(obj) then return end
  local h = NR_HANDLERS[obj.ClassName]
  if h and not NR_isGameplay(obj) then h(obj) end
end

local function NR_applyLighting(prop)
  NR_set(Lighting, prop, NR_LIGHTING[prop])
  NR_LightingSeen[prop] = NR_get(Lighting, prop)
end

local function NR_optimize()
  for prop in pairs(NR_LIGHTING) do NR_applyLighting(prop) end
  for _, c in ipairs(Lighting:GetChildren()) do NR_apply(c) end
  NR_set(workspace.Terrain, "Decoration", false)
  NR_set(workspace.Terrain, "WaterWaveSize", 0)
  NR_set(workspace.Terrain, "WaterWaveSpeed", 0)
  NR_set(workspace.Terrain, "WaterReflectance", 0)
  if NR_Render then NR_set(NR_Render, "QualityLevel", Enum.QualityLevel.Level01) end
end

local function NR_clearRuntime(v)
  local name = v.Name
  if name:find("PortalFor_", 1, true) or name:find("WaypointFor_", 1, true) then return end
  if NR_isProtected(v) then return end
  Debris:AddItem(v, 0)
end

local function NR_hideMapPart(part)
  if not part:IsA("BasePart") or NR_isGameplay(part) or NR_isProtected(part) then return end
  if part.Name == "FLOOR" or part.Name == "INVISIBLE_FLOOR" then NR_FloorParts[part] = true return end
  if NR_FloorParts[part] or NR_HiddenParts[part] ~= nil then return end
  if not NR_isMap(part) then return end
  NR_HiddenParts[part] = part.Transparency
  part.Transparency = 1
end

local function NR_restoreParts()
  for part, t in pairs(NR_HiddenParts) do
    if part and part.Parent then part.Transparency = t end
  end
  table.clear(NR_HiddenParts)
end

local function NR_hideMapGui(obj)
  if not (obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") or obj:IsA("SelectionBox")) then return end
  if NR_isGameplay(obj) or NR_isIgnored(obj) or NR_isProtected(obj) then return end
  if NR_HiddenGuis2[obj] ~= nil then return end
  NR_HiddenGuis2[obj] = obj.Enabled
  obj.Enabled = false
end

local function NR_restoreGuis()
  for obj, e in pairs(NR_HiddenGuis2) do
    if obj and obj.Parent then obj.Enabled = e end
  end
  table.clear(NR_HiddenGuis2)
end

local function NR_hideLobbyGuis()
  local pg = LP:FindFirstChild("PlayerGui")
  if not pg then return end
  for _, gui in ipairs(pg:GetChildren()) do
    if NR_LOBBY_GUI[gui.Name] and gui:IsA("ScreenGui") and gui.Enabled then
      NR_HiddenGuis[gui] = true
      gui.Enabled = false
    end
  end
end

local function NR_restoreLobbyGuis()
  for gui in pairs(NR_HiddenGuis) do
    if gui and gui.Parent then gui.Enabled = true end
  end
  table.clear(NR_HiddenGuis)
end

local function NR_isInMatch()
  local char = LP.Character
  return char and char.Parent and char.Parent.Name == "Alive"
end

local function NR_destroyLobby()
  for _, v in ipairs(workspace:GetChildren()) do
    if NR_LOBBY_FOLDERS[v.Name] and not v:GetAttribute("NR_LobbyDestroyed") then
      v:SetAttribute("NR_LobbyDestroyed", true)
      NR_LobbyDestroyed[#NR_LobbyDestroyed + 1] = v
      v.Parent = nil
    end
  end
end

local function NR_restoreLobby()
  for _, v in ipairs(NR_LobbyDestroyed) do
    if v then
      pcall(function()
        v:SetAttribute("NR_LobbyDestroyed", nil)
        v.Parent = workspace
      end)
    end
  end
  table.clear(NR_LobbyDestroyed)
end

local function NR_checkMatch()
  if not NR_Enabled then return end
  local inMatch = NR_isInMatch()
  if inMatch and not NR_InMatch then NR_InMatch = true; NR_destroyLobby()
  elseif not inMatch and NR_InMatch then NR_InMatch = false; NR_restoreLobby() end
end

local function NR_process(v)
  if NR_isIgnored(v) or NR_isProtected(v) then return end
  NR_apply(v)
  NR_hideMapPart(v)
  NR_hideMapGui(v)
end

local function NR_enable()
  if NR_Enabled then return end
  NR_Enabled = true
  NR_Gen += 1
  local gen = NR_Gen
  local queue, idx = {}, 0
  local matchAt = 0

  NR_optimize()
  NR_hideLobbyGuis()

  connections.NR_Descendant = workspace.DescendantAdded:Connect(function(v)
    queue[#queue + 1] = v
  end)
  connections.NR_Drain = RunService.Heartbeat:Connect(function()
    if idx >= #queue then
      if #queue > 0 then table.clear(queue); idx = 0 end
      return
    end
    local deadline = os.clock() + 0.003
    while idx < #queue and os.clock() < deadline do
      idx += 1
      local v = queue[idx]
      if v and v.Parent then pcall(NR_process, v) end
    end
    if idx >= #queue then table.clear(queue); idx = 0 end
  end)
  connections.NR_LightingChild = Lighting.ChildAdded:Connect(NR_apply)
  connections.NR_GuiAdded = LP.PlayerGui.ChildAdded:Connect(function(gui)
    if NR_LOBBY_GUI[gui.Name] and gui:IsA("ScreenGui") and gui.Enabled then
      NR_HiddenGuis[gui] = true
      gui.Enabled = false
    end
  end)
  connections.NR_Match = RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - matchAt < 0.5 then return end
    matchAt = now
    NR_checkMatch()
  end)

  local rt = workspace:FindFirstChild("Runtime")
  if rt then
    connections.NR_Runtime = rt.ChildAdded:Connect(NR_clearRuntime)
    for _, v in ipairs(rt:GetChildren()) do NR_clearRuntime(v) end
  end

  task.spawn(function()
    local list = workspace:GetDescendants()
    local deadline = os.clock() + 0.004
    for i = 1, #list do
      if NR_Gen ~= gen then return end
      NR_process(list[i])
      if i % 64 == 0 and os.clock() > deadline then
        task.wait()
        deadline = os.clock() + 0.004
      end
    end
    while NR_Gen == gen do task.wait(10) end
  end)
end

local function NR_disable()
  if not NR_Enabled then return end
  NR_Enabled = false
  NR_Gen += 1
  for _, key in ipairs({ "NR_Descendant", "NR_Drain", "NR_LightingChild", "NR_GuiAdded", "NR_Match", "NR_Runtime" }) do
    if connections[key] then
      pcall(function() connections[key]:Disconnect() end)
      connections[key] = nil
    end
  end
  NR_restoreAll()
  NR_restoreLobbyGuis()
  NR_restoreLobby()
  NR_restoreParts()
  NR_restoreGuis()
  NR_InMatch = false
  table.clear(NR_FloorParts)
  table.clear(NR_LightingSeen)
end

local Window = Library:CreateWindow({
  Title = "Byte",
  Layout = "Bottom bar",
  MenuKey = Enum.KeyCode.RightShift,
})

local FarmTab = Window:AddTab("Farm", "sprout")
local UpgradeTab = Window:AddTab("Upgrades", "circle-arrow-up")
local RewardsTab = Window:AddTab("Rewards", "gift")
local SettingsTab = Window:CreateSettingsTab()

local FarmGroup = FarmTab:AddLeftGroupbox("Auto Farm", "repeat")
local ThrowGroup = FarmTab:AddRightGroupbox("Throw", "target")
local TrainGroup = FarmTab:AddLeftGroupbox("Train", "dumbbell")
local AnimalGroup = FarmTab:AddRightGroupbox("Animals", "paw-print")

local function buildZoneOptions()
  local lvl = tonumber(get("Level")) or 1
  local power = G.Level.ThrowPowerForLevel(lvl)
  local list = { "Max power" }
  for _, zone in ipairs(G.Areas and G.Areas.List or {}) do
    if power >= (zone.StartDistance or 0) then
      table.insert(list, zone.Name)
    else
      table.insert(list, ("🔒 %s (Lv %d)"):format(
        zone.Name, G.Level.LevelForDistance(zone.StartDistance)))
    end
  end
  return list
end

local function throwPowerForLevel(level)
  local base = G.Level.ThrowPowerForLevel(level)
  if S.zone and S.zone ~= "Max power" then
    for _, zone in ipairs(G.Areas.List) do
      if zone.Name == S.zone and zone.StartDistance and zone.Length then
        return math.min(base, zone.StartDistance + zone.Length * 0.95)
      end
    end
  end
  return base
end

local function zoneFor(power)
  local name = "-"
  for _, zone in ipairs(G.Areas.List) do
    if power >= (zone.StartDistance or 0) then name = zone.Name end
  end
  return name
end

local farmStatusLabel = FarmGroup:AddLabel("Auto Farm: OFF")
local function setFarmStatus(text) setName(FarmGroup:GetControl(farmStatusLabel), text) end

FarmGroup:AddToggle("AutoFarm", {
  Text = "Auto Farm (train -> throw)",
  Default = false,
  Callback = function(state)
    S.farm = state
    if G.Meter then
      G.Meter.TestAutoTap = (S.throw or S.farm) and 0.5 or nil
    end
    if not state and G.Train and G.Train.IsRunning() then
      pcall(G.Train.Stop)
    end
    if state and (tonumber(get("Stand")) or 0) < 1 then
      setFarmStatus("No stand owned — buy a pull-up bar first!")
    end
  end,
})

FarmGroup:AddToggle("FarmLvStop", {
  Text = "Throw When level up",
  Default = false,
  Callback = function(state) S.farmLvStop = state end,
})

FarmGroup:AddDropdown("FarmZone", {
  Text = "Target zone",
  Values = buildZoneOptions(),
  Default = "Max power",
  Callback = function(value)
    if type(value) == "string" and value:find("🔒", 1, true) then
      task.defer(function()
        pcall(function()
          Library.Options.FarmZone:SetValue(S.zone or "Max power")
        end)
      end)
      return
    end
    S.zone = value
  end,
})

task.spawn(function()
  local last = -1
  while S.alive do
    pcall(function()
      local lvl = tonumber(get("Level")) or 1
      if lvl ~= last then
        last = lvl
        local opts = buildZoneOptions()
        Library.Options.FarmZone:SetValues(opts)
        if S.zone and not table.find(opts, S.zone) then
          S.zone = "Max power"
          Library.Options.FarmZone:SetValue("Max power")
        end
      end
    end)
    task.wait(5)
  end
end)

FarmGroup:AddSlider("FarmThrows", {
  Text = "Throws per level",
  Min = 1, Max = 30, Default = 5, Increment = 1,
  Callback = function(v) S.farmThrows = v end,
})

FarmGroup:AddSlider("FarmTrainMax", {
  Text = "Train time per round (s)",
  Min = 30, Max = 900, Default = 300, Increment = 10,
  Callback = function(v) S.farmTrainMax = v end,
})

local function teleportToTraining()
  local area = workspace:FindFirstChild("TrainingArea", true)
  local part = area and (area.PrimaryPart or area:FindFirstChildWhichIsA("BasePart"))
  local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
  if not (part and root) then return false end
  if (root.Position - part.Position).Magnitude > 4 then
    root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
    task.wait(0.5)
  end
  return true
end

local function startTraining()
  if (tonumber(get("Stand")) or 0) < 1 then
    return false, "No stand owned"
  end
  if not teleportToTraining() then
    return false, "No training area"
  end
  task.spawn(G.Train.Start)
  task.wait(0.1)
  if G.Train.IsRunning() or (G.State and G.State.Busy) then
    return true, nil
  end
  return false, "Training failed to start"
end

local function doThrow()
  if G.Train and G.Train.IsRunning() then
    pcall(G.Train.Stop)
    local t = os.clock() + 5
    while G.Train.IsRunning() and os.clock() < t do
      task.wait(0.05)
    end
  end

  local t = os.clock() + 5
  while G.State.Busy and os.clock() < t do
    task.wait(0.05)
  end
  if G.State.Busy then
    return false
  end

  if S.throwMode == "Fast" then
    local AreaUtil = f1(ReplicatedStorage.Shared.AreaUtil)
    local launchPos = AreaUtil and AreaUtil.GetLaunchPosition and AreaUtil.GetLaunchPosition()

    local function snapToLaunch()
      if not launchPos then return end
      local char = LP.Character
      local root = char and char:FindFirstChild("HumanoidRootPart")
      if root then
        root.CFrame = CFrame.new(launchPos + Vector3.new(0, 3, 0))
      end
    end

    local char0 = LP.Character
    local root0 = char0 and char0:FindFirstChild("HumanoidRootPart")
    if root0 and launchPos and (root0.Position - launchPos).Magnitude > 8 then
      snapToLaunch()
      task.wait(0.3)
    end

    local start = invoke("Throw_Start")
    if not start.Ok then
      if start.Reason == "TooFar" then
        snapToLaunch()
        task.wait(0.6)
      else
        task.wait(2)
      end
      return false
    end

    if S.super and start.SuperOffer and (tonumber(start.Saved) or 0) > 0 then
      invoke("Throw_UseSuper")
      task.wait(0.2)
    end

    task.wait(0.2)

    pcall(function()
      if G.Remotes and G.Remotes.Event then
        G.Remotes.Event("Throw_MeterStarted"):FireServer()
      end
    end)

    task.wait(0.15)

    local resolve = invoke("Throw_Resolve", 1)
    if not resolve.Ok then
      pcall(function() invoke("Throw_Cancel") end)
      task.wait(2)
      return false
    end

    local flightTime = tonumber(resolve.FlightTime) or 3
    task.wait(flightTime + 2.5)

    pcall(function() invoke("Throw_Complete") end)

    task.wait(0.5)
    return true
  end

  local beforeFinished = finishedCount
  local beforeMeter = meterRuns
  local before = snapshotState()

  local ok = pcall(function() G.Throw.Start() end)
  if not ok then
    task.wait(3)
    return false
  end

  if finishedCount > beforeFinished then
    task.wait(2)
    return true
  end
  if meterRuns > beforeMeter then
    task.wait(2)
    return true
  end

  task.wait(1)
  local after = snapshotState()
  if after.throws > before.throws then return true end
  if after.animals > before.animals then return true end
  if after.xp > before.xp then return true end
  if after.level > before.level then return true end
  if after.superThrows < before.superThrows then return true end

  task.wait(2)
  return false
end

loop(farmStatusLabel, 1, function()
  if not S.farm then return end

  local function tick(phase)
    local lvl = tonumber(get("Level")) or 1
    local xp = tonumber(get("Xp")) or 0
    local need = G.Level.XpForLevel(lvl + 1)
    local targetPower = throwPowerForLevel(lvl)
    S.phase = phase
    setFarmStatus(("%s | Lv %d (%d/%d XP) | %d studs | %s"):format(
      phase, lvl, math.floor(xp), math.floor(need), math.floor(targetPower), zoneFor(targetPower)))
    return lvl
  end

  local training = tick("Training")
  local started = os.clock()

  while S.farm
    and not (S.farmLvStop and (tonumber(get("Level")) or 1) > training)
    and os.clock() - started < (S.farmTrainMax or 300) do
    if not G.Train.IsRunning() and not (G.State and G.State.Busy) then
      local ok, reason = startTraining()
      if not ok then
        tick(reason or "TrainingArea not found")
        task.wait(2)
      end
    end
    tick(("Training %ds/%ds"):format(math.floor(os.clock() - started), S.farmTrainMax or 300))
    task.wait(1)
  end

  if not S.farm then return end
  if G.Train.IsRunning() then pcall(G.Train.Stop) task.wait(1.5) end

  local count = 0
  local attempts = 0
  local maxAttempts = (S.farmThrows or 5) * 3
  local consecutiveFails = 0

  while S.farm and count < (S.farmThrows or 5) and attempts < maxAttempts do
    attempts += 1
    local curLvl = tonumber(get("Level")) or 1
    invoke("Player_SetThrowPower", throwPowerForLevel(curLvl))

    local retry = attempts - count
    if retry > 1 then
      tick(("Throwing %d/%d (retry %d)"):format(count + 1, S.farmThrows or 5, retry - 1))
    else
      tick(("Throwing %d/%d"):format(count + 1, S.farmThrows or 5))
    end

    if doThrow() then
      count += 1
      consecutiveFails = 0
    else
      consecutiveFails += 1
      if consecutiveFails >= 3 then
        tick(("Gave up after 3 failures: %d/%d"):format(count, S.farmThrows or 5))
        break
      end
      task.wait(0.5)
    end
  end

  invoke("Plot_EquipBest")
end)

local throwStatusLabel = ThrowGroup:AddLabel("Throws: 0 | -")
local throwCount = 0
local function setThrowStatus(msg)
  setName(ThrowGroup:GetControl(throwStatusLabel), ("Throws: %d | %s"):format(throwCount, msg))
end

ThrowGroup:AddToggle("AutoThrow", {
  Text = "Auto Throw (Perfect)",
  Default = false,
  Callback = function(state)
    S.throw = state
    if G.Meter then
      G.Meter.TestAutoTap = (S.throw or S.farm) and 0.5 or nil
    end
  end,
})

ThrowGroup:AddToggle("SuperThrow", {
  Text = "Use Super Throw",
  Default = false,
  Callback = function(state) S.super = state end,
})

ThrowGroup:AddDropdown("ThrowMode", {
  Text = "Throw mode",
  Values = { "Normal", "Fast" },
  Default = "Normal",
  Callback = function(v) S.throwMode = v end,
})

local lastAutoThrowLevel = -1
loop(nil, 1, function()
  if not S.throw or S.farm then
    lastAutoThrowLevel = -1
    return
  end
  local curLvl = tonumber(get("Level")) or 1
  if curLvl ~= lastAutoThrowLevel then
    lastAutoThrowLevel = curLvl
    invoke("Player_SetThrowPower", throwPowerForLevel(curLvl))
  end
  if doThrow() then
    throwCount += 1
    setThrowStatus("OK")
    task.wait(1.5)
  else
    setThrowStatus("Failed - retrying")
    task.wait(2)
  end
end)

local trainStatusLabel = TrainGroup:AddLabel("Auto Train: OFF")
local function setTrainStatus(text) setName(TrainGroup:GetControl(trainStatusLabel), text) end

TrainGroup:AddToggle("AutoTrain", {
  Text = "Auto Train",
  Default = false,
  Callback = function(state)
    S.train = state
    if not state and G.Train and G.Train.IsRunning() then
      pcall(G.Train.Stop)
    end
    if state and (tonumber(get("Stand")) or 0) < 1 then
      setTrainStatus("No stand owned — buy a pull-up bar first!")
    end
  end,
})

TrainGroup:AddToggle("AutoTapBonus", {
  Text = "Auto Tap Bonus",
  Default = true,
  Callback = function(state) S.tap = state end,
})

loop(trainStatusLabel, 2, function()
  if S.farm then setTrainStatus("Auto Farm is on") return end
  if not S.train or S.throw then setTrainStatus(S.throw and "Auto Throw is on" or "Auto Train: OFF") return end
  if G.Train.IsRunning() then setTrainStatus("Training...") return end
  if G.State and G.State.Busy then setTrainStatus("Busy: " .. tostring(G.State.Busy)) return end
  local ok, reason = startTraining()
  setTrainStatus(ok and "Start training" or (reason or "TrainingArea not found"))
end)

local equipStatusLabel = AnimalGroup:AddLabel("Equip: idle")

AnimalGroup:AddToggle("EquipBest", {
  Text = "Auto Equip Best Animal",
  Default = true,
  Callback = function(state) S.equipBest = state end,
})

AnimalGroup:AddToggle("FastEquip", {
  Text = "Fast Equip (1s interval, 3x burst)",
  Default = true,
  Tooltip = "Fills all 10 slots in ~4s instead of ~200s. Turn off if kicked.",
  Callback = function(state) S.fastEquip = state end,
})

local function countPlaced()
  local placed, total = 0, 0
  for _, a in pairs(get("Animals") or {}) do
    total += 1
    if type(a) == "table" and a.Placed then placed += 1 end
  end
  return placed, total
end

loop(equipStatusLabel, function() return S.fastEquip and 1 or 20 end, function()
  if not S.equipBest then return end
  local bursts = S.fastEquip and 3 or 1
  for i = 1, bursts do
    invoke("Plot_EquipBest")
    if i < bursts then task.wait(0.08) end
  end
  local placed, total = countPlaced()
  setName(AnimalGroup:GetControl(equipStatusLabel), ("Equip: %d/%d placed (%dx burst, %ss)"):format(
    placed, total, bursts, S.fastEquip and "1" or "20"))
end)

local UpgradeGroup = UpgradeTab:AddLeftGroupbox("Auto Upgrade", "circle-arrow-up")
local upgradeStatus = UpgradeGroup:AddLabel("-")
local function setUpgradeStatus(text) setName(UpgradeGroup:GetControl(upgradeStatus), text) end

UpgradeGroup:AddToggle("AutoStand", {
  Text = "Auto Upgrade Stand (train)",
  Default = false,
  Callback = function(state) S.stand = state end,
})

UpgradeGroup:AddToggle("AutoFence", {
  Text = "Auto Upgrade Fence (home)",
  Default = false,
  Callback = function(state) S.fence = state end,
})

UpgradeGroup:AddToggle("AutoBuyFood", {
  Text = "Auto Buy Best Food",
  Default = false,
  Callback = function(state) S.buyFood = state end,
})

UpgradeGroup:AddToggle("AutoEquipFood", {
  Text = "Auto Equip Best Food",
  Default = false,
  Callback = function(state) S.equipFood = state end,
})

loop(upgradeStatus, 3, function()
  local money = tonumber(get("Money")) or 0
  local log = {}

  if S.stand then
    local nextStand = G.Stands.Get((get("Stand") or 0) + 1)
    if nextStand then
      if money >= nextStand.Price then
        local r = invoke("Stand_Upgrade")
        table.insert(log, "Stand: " .. (r.Ok and nextStand.Name or tostring(r.Reason)))
      else
        table.insert(log, "Stand: need $" .. tostring(math.floor(nextStand.Price)))
      end
    else
      table.insert(log, "Stand: MAX")
    end
  end

  if S.fence then
    local fenceLvl = tonumber(get("FenceLevel") or get("Fence")) or 0
    local nextFence = G.Fence.Get(fenceLvl + 1)
    if nextFence then
      if money >= nextFence.Price then
        local r = invoke("Plot_UpgradeFence")
        if r.Ok then table.insert(log, "Fence: Lv " .. tostring(r.Level)) end
      else
        table.insert(log, "Fence: need $" .. tostring(math.floor(nextFence.Price)))
      end
    else
      table.insert(log, "Fence: MAX")
    end
  end

  if S.buyFood or S.equipFood then
    local owned = get("OwnedFoods") or {}
    local bestOwned
    local bought = 0
    for i = 1, G.Foods.Count() do
      local food = G.Foods.Get(i)
      local has = owned[i] == true or owned[tostring(i)] == true
      if food and not has and S.buyFood and money >= (food.Price or math.huge) then
        local r = invoke("Shop_Buy", i)
        if r.Ok then has = true; money -= food.Price; bought += 1 end
      end
      if has then bestOwned = i end
    end
    if bought > 0 then table.insert(log, "Bought " .. bought .. " food") end
    if S.equipFood and bestOwned and get("EquippedFood") ~= bestOwned then
      invoke("Shop_Equip", bestOwned)
      table.insert(log, "Equipped food #" .. bestOwned)
    end
  end

  if #log > 0 then setUpgradeStatus(table.concat(log, " | ")) end
end)

local SellGroup = UpgradeTab:AddRightGroupbox("Auto Sell", "coins")
local sellStatus = SellGroup:AddLabel("Sold: 0 | -")
local soldCount = 0
local soldLast = "-"
local function setSellStatus()
  setName(SellGroup:GetControl(sellStatus), ("Sold: %d | %s"):format(soldCount, soldLast))
end

SellGroup:AddToggle("AutoSell", {
  Text = "Auto Sell",
  Default = false,
  Callback = function(state) S.sell = state end,
})

SellGroup:AddDropdown("SellRar", {
  Text = "Sell rarities",
  Values = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine", "Celestial", "Eternal", "Cosmic", "Supreme", "Sovereign" },
  Multi = true,
  Default = { Common = true },
  Callback = function(value)
    S.sellRar = {}
    for name, on in pairs(value) do
      if on then S.sellRar[name] = true end
    end
  end,
})

SellGroup:AddButton({
  Text = "Sell All",
  Callback = function()
    local r = invoke("Plot_SellAll")
    soldLast = r.Ok and "Sell All OK" or tostring(r.Reason)
    setSellStatus()
  end,
})

loop(sellStatus, 5, function()
  if not S.sell then return end
  local soldThisPass = 0
  for key, animal in pairs(get("Animals") or {}) do
    if not S.sell then break end
    if type(animal) == "table" and not animal.Placed then
      local info = G.Economy.Get(animal.ModelName)
      if info and S.sellRar[info.Rarity] then
        local r = invoke("Plot_SellAnimal", key)
        if r.Ok then
          soldCount += 1
          soldThisPass += 1
          soldLast = tostring(animal.ModelName)
        else
          soldLast = tostring(r.Reason)
        end
        setSellStatus()
        task.wait(0.3)
      end
    end
  end
  if soldThisPass == 0 then
    soldLast = "nothing to sell"
    setSellStatus()
  end
end)

local RewardGroup = RewardsTab:AddLeftGroupbox("Rewards", "gift")
local rewardStatus = RewardGroup:AddLabel("Ready")

RewardGroup:AddToggle("ClaimOffline", {
  Text = "Auto Claim Offline",
  Default = true,
  Callback = function(state) S.offline = state end,
})

RewardGroup:AddToggle("ClaimFreeShop", {
  Text = "Auto Claim Free Shop",
  Default = true,
  Callback = function(state) S.free = state end,
})

loop(rewardStatus, 60, function()
  local log = {}
  if S.offline then
    local r = invoke("Offline_Claim")
    table.insert(log, r.Ok and "Offline OK" or ("Offline: " .. tostring(r.Reason)))
  end
  if S.free then
    local r = invoke("Shop_ClaimFree")
    table.insert(log, r.Ok and "Free OK" or ("Free: " .. tostring(r.Reason)))
  end
  setName(RewardGroup:GetControl(rewardStatus), table.concat(log, " | "))
end)

local SettingsGroup = SettingsTab:AddLeftGroupbox("Settings", "settings")

SettingsGroup:AddToggle("Watermark", {
  Text = "Watermark",
  Default = true,
  Callback = function(state)
    local g = CreateWatermark()
    if g then g.Enabled = state end
  end,
})

SettingsGroup:AddToggle("NoRender", {
  Text = "No Render (Anti-Lag)",
  Default = false,
  Tooltip = "Strips world effects, lighting and lobby — your character and weapons stay visible",
  Callback = function(state)
    if state then NR_enable() else NR_disable() end
  end,
})

SettingsGroup:AddToggle("AntiAFK", {
  Text = "Anti AFK",
  Default = true,
  Callback = function(state) S.antiAfk = state end,
})

SettingsGroup:AddDivider()

SettingsGroup:AddButton({
  Text = "Unload",
  Callback = function()
    S.alive = false
    S.farm = false
    S.throw = false
    S.train = false
    S.sell = false
    S.equipBest = false
    S.stand = false
    S.fence = false
    S.buyFood = false
    S.equipFood = false
    S.offline = false
    S.free = false
    S.tap = false
    S.antiAfk = false

    if G._origSetGameplay then G.HUD.SetGameplayVisible = G._origSetGameplay end
    if G.Meter then
      G.Meter.TestAutoTap = nil
      if G._origMeterNew then G.Meter.new = G._origMeterNew end
    end

    pcall(function() if G.Train.IsRunning() then G.Train.Stop() end end)

    for _, c in ipairs(connections) do
      if typeof(c) == "RBXScriptConnection" then pcall(function() c:Disconnect() end) end
    end
    table.clear(connections)

    NR_disable()

    if WatermarkGui then
      pcall(function() WatermarkGui:Destroy() end)
      WatermarkGui = nil
    end

    pcall(function() Library:Unload() end)
    rawset(getgenv and getgenv() or _G, "Byte_THROW", nil)
  end,
})

local idleConn = LP.Idled:Connect(function()
  if S.antiAfk then
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
  end
end)
table.insert(connections, idleConn)

local tapStatusLabel = TrainGroup:AddLabel("Tap: waiting")
local tapOk, tapFail, tapLastReason = 0, 0, "-"
local tapVisual = 0
local tapMethod = "-"
local function refreshTapStatus()
  pcall(function()
    tapStatusLabel:SetText(("Tap: %d ok / %d fail (%s) [%s]"):format(tapOk, tapFail, tapLastReason, tapMethod))
  end)
end

local function clickTapButton(btn)
  if not btn or not btn.Parent then return nil end

  if type(firesignal) == "function" then
    local ok = pcall(firesignal, btn.Activated)
    if ok then return "firesignal" end
  end

  if type(getconnections) == "function" then
    local ok, conns = pcall(getconnections, btn.Activated)
    if ok and type(conns) == "table" then
      for _, c in ipairs(conns) do
        if c.Enabled ~= false then
          if type(c.Fire) == "function" then
            if pcall(function() c:Fire() end) then return "conn-fire" end
            if pcall(c.Fire) then return "conn-fire" end
          elseif type(c.Function) == "function" then
            task.spawn(c.Function)
            return "conn-fn"
          end
        end
      end
    end
  end

  return nil
end

local function findAndClickTap()
  for i = 1, 20 do
    if i > 1 then task.wait(0.05) end
    local pg = LP:FindFirstChild("PlayerGui")
    local ts = pg and pg:FindFirstChild("TrainingSequence")
    if ts then
      for _, desc in ipairs(ts:GetDescendants()) do
        if desc.Name == "TapBonus" and desc:IsA("GuiButton") and desc.Parent and desc.Visible then
          local method = clickTapButton(desc)
          if method then return method end
        end
      end
    end
  end
  return nil
end

local tapConn = G.Remotes.Event("Training_Bonus").OnClientEvent:Connect(function(id)
  if not S.tap or id == nil then return end

  task.spawn(function()
    local method = findAndClickTap()
    if method then
      tapOk += 1
      tapVisual += 1
      tapMethod = method
      refreshTapStatus()
      return
    end

    local r = invoke("Training_TapBonus", id)
    if r.Ok then
      tapOk += 1
      tapMethod = "silent"
    else
      tapFail += 1
      tapLastReason = tostring(r.Reason or "?")
      tapMethod = "fail"
    end
    refreshTapStatus()
  end)
end)
table.insert(connections, tapConn)

ThemeManager:SetLibrary(Window)
SaveManager:SetLibrary(Window)
ThemeManager:SetFolder("Byte/ThrowFood")
SaveManager:SetFolder("Byte/ThrowFood")
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)
ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()

CreateWatermark()

rawset(getgenv and getgenv() or _G, "Byte_THROW", {
  state = S,
  modules = G,
  set_farm = function(on) Library.Toggles.AutoFarm:SetValue(on == true) end,
  set_throw = function(on) Library.Toggles.AutoThrow:SetValue(on == true) end,
  set_train = function(on) Library.Toggles.AutoTrain:SetValue(on == true) end,
  set_no_render = function(on) Library.Toggles.NoRender:SetValue(on == true) end,
})
