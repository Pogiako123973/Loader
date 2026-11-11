local Plrs=game:GetService("Players")
local LP=Plrs.LocalPlayer
local RS=game:GetService("ReplicatedStorage")
local WS=game:GetService("Workspace")
local RSv=game:GetService("RunService")
local RunSvc=RSv
local RunSv=RSv
local RunService=RSv
local UIS=game:GetService("UserInputService")
local Ltg=game:GetService("Lighting")
local HS=game:GetService("HttpService")
local PPS=game:GetService("ProximityPromptService")

local repo="https://raw.githubusercontent.com/viseamn/Visual/main/"
local Library=loadstring(game:HttpGet(repo.."Library.lua"))()
local ThemeManager=loadstring(game:HttpGet(repo.."ThemeManager.lua"))()
local SaveManager=loadstring(game:HttpGet(repo.."SaveManager.lua"))()

local Window=Library:CreateWindow({Title="Byte",Layout="Bottom bar",MenuKey=Enum.KeyCode.RightShift})
local VisualTab=Window:AddTab("Visuals","eye")
local PlayerTab=Window:AddTab("Player","user")
local AutomationTab=Window:AddTab("Automation","zap")
local ProtectionTab=Window:AddTab("Protection","shield")
local StairwellTab=Window:AddTab("Stairwell","layers")
local AlertsTab=Window:AddTab("Alerts","bell")
local SettingsTab=Window:CreateSettingsTab()

local MK=VisualTab:AddLeftGroupbox("ESP","eye")
local MKO=VisualTab:AddLeftGroupbox("ESP Options","sliders-horizontal")
local CAM=VisualTab:AddRightGroupbox("Camera","camera")
local FXG=VisualTab:AddRightGroupbox("Effects","sparkles")

local MV=PlayerTab:AddLeftGroupbox("Movement","move")
local VIS=PlayerTab:AddRightGroupbox("Vision","sun")

local BOT=AutomationTab:AddLeftGroupbox("Bots","cpu")
local ITM=AutomationTab:AddRightGroupbox("Prompts & Items","package")

local BYP=ProtectionTab:AddLeftGroupbox("Bypass","shield-check")
local IGN=ProtectionTab:AddLeftGroupbox("Ignores","shield-off")
local BLK=ProtectionTab:AddRightGroupbox("Blocks & Damage","ban")
local FLR=ProtectionTab:AddRightGroupbox("Floor & Extras","layers")

local WRP=StairwellTab:AddLeftGroupbox("Warps","map-pin")
local SIT=StairwellTab:AddLeftGroupbox("Items","package")
local HAZ=StairwellTab:AddRightGroupbox("Hazards","alert-triangle")
local CRK=StairwellTab:AddRightGroupbox("Creak","activity")

local ALR=AlertsTab:AddLeftGroupbox("Notifications","bell")

local Toggles,Options=Library.Toggles,Library.Options
local S={T={},UI={},Hooks={},Ex={}}
S.Ex.NotifyMaster=true
S.Ex.FeatureAlerts=true
S.Ex.ActionAlerts=true
local Funcs={}
local Esp={Tracked=setmetatable({},{__mode="k"}),Cfg={ShowNames=false,Enabled=false,FOV=70}}
local AI={Set=setmetatable({},{__mode="k"}),Static=setmetatable({},{__mode="k"}),Fired=setmetatable({},{__mode="k"}),Reason=setmetatable({},{__mode="k"}),Last=0}
local IF={Fakes={},Real=setmetatable({},{__mode="k"})}
local Mel={Orig=setmetatable({},{__mode="k"}),Scripts=setmetatable({},{__mode="k"}),Conn=nil,Loop=false}
local Stair={Creaks=setmetatable({},{__mode="k"}),Nodes={},Ducks={},Seen=setmetatable({},{__mode="k"}),Ducked=false,Nearest=nil,CartLast=0,TrashGen=0}
local St={Seen=setmetatable({},{__mode="k"}),Last={},ReadyAt=os.clock()+5,AtmoOrig=setmetatable({},{__mode="k"}),Light=nil,Fog=nil,LastLight=0}
local Mode={Name="Unknown"}

local function Notify(t,d,cat)
  if S.Ex.NotifyMaster==false then return end
  if cat=="feature" and S.Ex.FeatureAlerts==false then return end
  if cat=="action" and S.Ex.ActionAlerts==false then return end
  pcall(function() Window:Notify({Title=t,Content=d or "",Duration=3}) end)
end
local cC,cH,cR
local function GetChar()
  local c=LP.Character
  if c~=cC or not cH or cH.Parent~=c or not cR or cR.Parent~=c then
    cC=c; cH=c and c:FindFirstChildOfClass("Humanoid"); cR=c and c:FindFirstChild("HumanoidRootPart")
  end
  if cH and cR and cH.Health>0 then return cC,cH,cR end
end
local function Toggle(id,v) if S.Ex[id]==v then return end S.Ex[id]=v; if S.Hooks[id] then pcall(S.Hooks[id],v) end end
local function Set(id,v)
  local t=Toggles[id] or Options[id]
  if t and t.Value~=v then pcall(t.SetValue,t,v) end
  Toggle(id,v)
end

S.Hooks.WalkSpeed=function(v)
  local c,h=GetChar(); if not h then return end
  if v then St.HackWS=St.HackWS or h.WalkSpeed elseif St.HackWS then h.WalkSpeed=St.HackWS; St.HackWS=nil end
end
S.Hooks.Jump=function(v)
  local c,h=GetChar(); if not h then return end
  pcall(function() local ch=LP.Character; for n,val in pairs(ch:GetAttributes()) do local l=n:lower(); if type(val)=="boolean" and l:find("jump",1,true) and (l:find("can",1,true) or l:find("enable",1,true)) then ch:SetAttribute(n,true) end end end)
  if v then St.JP=St.JP or {h.JumpPower,h.UseJumpPower} else if St.JP then h.UseJumpPower,h.JumpPower=St.JP[2],St.JP[1]; St.JP=nil end end
end
S.Hooks.Slide=function(v)
  local ch=LP.Character; if not ch then return end
  for n,val in pairs(ch:GetAttributes()) do local l=n:lower(); if type(val)=="boolean" and l:find("slide",1,true) and (l:find("can",1,true) or l:find("enable",1,true)) then ch:SetAttribute(n,true) end end
end
S.Hooks.Flight=function(v) local c,h,r=GetChar(); if not h then return end; h.PlatformStand=v and true or false; if not v then r.AssemblyLinearVelocity=Vector3.zero end end
S.Hooks.Phasing=function(v) if not v then local ch=LP.Character; if ch then for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") and p:GetAttribute("R4NNC") then p.CanCollide=p:GetAttribute("R4NNC"); p:SetAttribute("R4NNC",nil) end end end end end
S.Hooks.BrightVision=function(v)
  if v then if not St.Light then St.Light={Brightness=Ltg.Brightness,ClockTime=Ltg.ClockTime,GlobalShadows=Ltg.GlobalShadows,Ambient=Ltg.Ambient,OutdoorAmbient=Ltg.OutdoorAmbient} end
  elseif St.Light then for k,val in pairs(St.Light) do pcall(function() Ltg[k]=val end) end St.Light=nil end
end
S.Hooks.NoFog=function(v)
  if v then if not St.Fog then St.Fog={FogEnd=Ltg.FogEnd,FogStart=Ltg.FogStart} end
  else if St.Fog then for k,val in pairs(St.Fog) do pcall(function() Ltg[k]=val end) end St.Fog=nil end
    for a,o in pairs(St.AtmoOrig) do if a.Parent then pcall(function() a.Density,a.Haze=o[1],o[2] end) end St.AtmoOrig[a]=nil end
  end
end
S.Hooks.NoClosetDelay=function() end
S.Hooks.NoAcceleration=function(v)
  local ch=LP.Character; if not ch then return end
  for _,p in ipairs(ch:GetDescendants()) do if p:IsA("BasePart") then
    if v then if p:GetAttribute("R4NAcc")==nil then p:SetAttribute("R4NAcc",HS:JSONEncode({p.CustomPhysicalProperties and {p.CustomPhysicalProperties.Density,p.CustomPhysicalProperties.Friction,p.CustomPhysicalProperties.Elasticity} or false})) end; local b=p.CustomPhysicalProperties; p.CustomPhysicalProperties=PhysicalProperties.new(100,b and b.Friction or 0.3,b and b.Elasticity or 0,1,1)
    else local a=p:GetAttribute("R4NAcc"); if a then local d=HS:JSONDecode(a); p.CustomPhysicalProperties=d and PhysicalProperties.new(d[1],d[2],d[3],1,1) or nil; p:SetAttribute("R4NAcc",nil) end end
  end end
end
S.Hooks.InstantPrompts=function(v)
  if v then
    task.spawn(function() local n=0 for _,d in ipairs(WS:GetDescendants()) do if not S.Ex.InstantPrompts then return end if d:IsA("ProximityPrompt") then if not d:GetAttribute("R4NHold") then d:SetAttribute("R4NHold",d.HoldDuration) end; d.HoldDuration=0 end; n=n+1; if n%400==0 then task.wait() end end end)
    if not St.PromptConn then St.PromptConn=WS.DescendantAdded:Connect(function(d) if S.Ex.InstantPrompts and d:IsA("ProximityPrompt") then task.defer(function() if not d:GetAttribute("R4NHold") then d:SetAttribute("R4NHold",d.HoldDuration) end; d.HoldDuration=0 end) end end) end
  else
    if St.PromptConn then St.PromptConn:Disconnect(); St.PromptConn=nil end
    for _,d in ipairs(WS:GetDescendants()) do if d:IsA("ProximityPrompt") and d:GetAttribute("R4NHold") then d.HoldDuration=d:GetAttribute("R4NHold"); d:SetAttribute("R4NHold",nil) end end
  end
end
S.Hooks.ItemSaver=function(v)
  if not fireproximityprompt then Notify("Item Saver","fireproximityprompt not supported","critical") return end
  if v then
    task.spawn(function() local n=0 for _,d in ipairs(WS:GetDescendants()) do if not S.Ex.ItemSaver then return end if d:IsA("ProximityPrompt") then pcall(Funcs.MakeFake,d) end; n=n+1; if n%400==0 then task.wait() end end end)
  else
    for fake,real in pairs(IF.Fakes) do pcall(function() if real and fake.Parent then real.Parent=fake.Parent end fake:Destroy() end) IF.Fakes[fake]=nil; if real then IF.Real[real]=nil end end
  end
end
S.Hooks.ACBypass=function(v)
  if not v and S.Globals and S.Globals.AnticheatDisabled then
    local rf=RS:FindFirstChild("RemotesFolder")
    if rf and rf:FindFirstChild("ClimbLadder") then pcall(function() rf.ClimbLadder:FireServer() end) end
    S.Globals.AnticheatDisabled=false
  end
end

local function GetPart(inst) if inst:IsA("BasePart") then return inst end if inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart",true) end end
local function PosOf(i) if not i then return nil end if i:IsA("BasePart") then return i.Position end if i:IsA("Model") then local ok,cf=pcall(i.GetPivot,i); return ok and cf.Position end local p=GetPart(i); return p and p.Position end

local ENTITY_NAMES={"RushMoving","AmbushMoving","BackdoorRush","A60","A120","GlitchRush","GlitchAmbush","Figure","FigureRig","FigureRagdoll","SeekMoving","Eyes","Halt","JeffTheKiller","Snare","Timothy","Void","Bob","ElGoblino","Dread","Grumble","QueenGrumble","Giggle","Gloombat","Firedamp","Lookman","BackdoorLookman","Haste","Groundskeeper","Caw","Monument","Surge","Mandrake","Eyestalk","Bramble","Grampy","WorldLotus","Honcho","Drone","ForgetMeNot","Teller","Alma","Portrait","Discoloration","Currents","Creak","NoiseModel","TV_Stand","Stem","Meld","Cobbler","Hijack","Crusher","Scribbles","DronesStampede","Ransom"}
local ENTITY_SET={}
for _,n in ipairs(ENTITY_NAMES) do ENTITY_SET[n:lower()]=true end
local function IsEntity(n) return ENTITY_SET[tostring(n):lower()]==true end

Funcs.MakeFake=function(real)
  if IF.Real[real] or not real:IsA("ProximityPrompt") or not fireproximityprompt then return end
  if not (real.Name=="UnlockPrompt" or real.Name=="SkullPrompt" or real.Name=="LockPrompt" or real.Name=="ThingToEnable" or real.Name=="FusesPrompt") then return end
  local parent=real.Parent; if not parent then return end
  local fake=real:Clone(); fake:SetAttribute("FakePrompt",true); fake.Parent=parent
  IF.Fakes[fake]=real; IF.Real[real]=fake
  real.Parent=WS:FindFirstChild("Drops") or WS
  real:GetPropertyChangedSignal("Enabled"):Connect(function() fake.Enabled=real.Enabled end)
  fake.Enabled=real.Enabled
end

PPS.PromptTriggered:Connect(function(pp)
  if not pp:GetAttribute("FakePrompt") then return end
  local real=IF.Fakes[pp]; if not real then return end
  local ch=LP.Character; if not ch then return end
  local has=false
  for _,n in ipairs({"Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool"}) do if ch:FindFirstChild(n) or (LP:FindFirstChild("Backpack") and LP.Backpack:FindFirstChild(n)) then has=true break end end
  if not has then return end
  local tool=ch:FindFirstChildOfClass("Tool")
  local rf=RS:FindFirstChild("RemotesFolder"); local drops=WS:FindFirstChild("Drops")
  local disp=tool and ({Lockpick="Lockpicks",SkeletonKey="Skeleton Key",Shears="Shears",Multitool="Multitool"})[tool.Name]
  if tool and disp and rf and rf:FindFirstChild("DropItem") and drops then
    local keep=false; for _,n in ipairs(S.Ex.ItemsToSave or {"Lockpicks","Skeleton Key","Shears","Multitool"}) do if n==disp then keep=true break end end
    if keep then
      drops.ChildAdded:Once(function(nt) local pk=nt:FindFirstChild("ModulePrompt") or nt:WaitForChild("ModulePrompt",3); if pk then pcall(fireproximityprompt,pk) end; pcall(fireproximityprompt,real) end)
      rf.DropItem:FireServer(tool); return
    end
  end
  pcall(fireproximityprompt,real)
end)

Funcs.AI_Blacklist={HidePrompt=true,RiftPrompt=true,StarRiftPrompt=true,InteractPrompt=true,ClimbPrompt=true,DonatePrompt=true,DialoguePrompt=true,RevivePrompt=true,EnterPrompt=true,AnimatePrompt=true,ToolEventPrompt=true,Prompt=true,PropPrompt=true,LongPushPrompt=true,BigPropPrompt=true,PushPrompt=true}
local function AIStaticSkip(pp)
  local at,ot=(pp.ActionText or ""):lower(),(pp.ObjectText or ""):lower()
  local n=(pp.Name or ""):lower()
  for _,w in ipairs({"sit","seat","chair","sofa","couch","bench","stool","throne","armchair","recliner","jeff","shop","purchase","buy","vendor","merchant","store","cashier","sell","donate","tithe","dialogue","talk","revive","emote","dance","gift"}) do
    if n:find(w,1,true) or at:find(w,1,true) or ot:find(w,1,true) then return true end
  end
  return false
end
local function AISkip(pp)
  if Funcs.AI_Blacklist[pp.Name] then AI.Reason[pp]="blacklist" return true end
  if pp:GetAttribute("FakePrompt") or pp:GetAttribute("AutoInteractIgnore") then AI.Reason[pp]="fake" return true end
  local par=pp.Parent; if not par then return true end
  local now=os.clock(); local ent=AI.Static[pp]
  if ent==nil or now-ent.t>2.5 then ent={v=AIStaticSkip(pp) and true or false,t=now}; AI.Static[pp]=ent end
  if ent.v then AI.Reason[pp]="static" return true end
  local drops=WS:FindFirstChild("Drops"); if drops and pp:IsDescendantOf(drops) then AI.Reason[pp]="drop" return true end
  local n=par.Name
  if n=="GlitchCube" or n=="TrackLever" or n=="Padlock" or n=="MinesAnchor" or n=="ElevatorBreaker" or n=="KeyObtainFake" or n=="TithingPlate" then return true end
  if par.Parent and (par.Parent.Name=="DoorFake" or par.Parent.Name=="FakeDoor" or par.Parent.Name=="IndustrialGate") then return true end
  if pp.Name=="ActivateEventPrompt" and pp.ActionText=="Close" then return true end
  AI.Reason[pp]=nil
  return false
end
local function AIMain(pp)
  local par=pp.Parent; if not par then return false end
  local pn=par.Name; local pname=pp.Name
  local isLock=pname=="UnlockPrompt" or pname=="SkullPrompt" or pname=="LockPrompt" or pname=="ThingToEnable" or pname=="FusesPrompt" or par:GetAttribute("Locked")==true
  if isLock then local has=false; local ch=LP.Character; local bp=LP:FindFirstChild("Backpack")
    for _,k in ipairs({"Key","GeneratorFuse","KeyBackdoor","KeyElectrical","KeyIron","Lockpick","SkeletonKey","Shears","Multitool"}) do if (ch and ch:FindFirstChild(k)) or (bp and bp:FindFirstChild(k)) then has=true break end end
    if not has then return false end
  end
  if pn=="Battery" then local ch=LP.Character; local t=ch and ch:FindFirstChildOfClass("Tool"); local bp=LP:FindFirstChild("Backpack"); if not t and not (bp and bp:FindFirstChild("BatteryPack")) then return false end end
  return true
end

task.spawn(function()
  while true do
    task.wait(S.Ex.AutoTrigger and 0.05 or 0.3)
    AI.Last=os.clock()
    if S.Ex.AutoTrigger then
      local ok,_,_,root=pcall(GetChar)
      if ok and root then
        local now=os.clock()
        local rp=root.Position
        local near={}
        for pp in pairs(AI.Set) do
          if pp.Parent and pp.Enabled then
            local ok2,p=pcall(PosOf,pp.Parent)
            if ok2 and p and (p-rp).Magnitude<=pp.MaxActivationDistance+12 then near[#near+1]=pp end
          end
        end
        for _,pp in ipairs(near) do
          pcall(function()
            if pp.Parent and pp.Enabled and (not AI.Fired[pp] or now-AI.Fired[pp]>0.12) then
              local p=PosOf(pp.Parent)
              if p and (p-rp).Magnitude<=pp.MaxActivationDistance+0.5 and not AISkip(pp) and AIMain(pp) then
                AI.Fired[pp]=now; if fireproximityprompt then pcall(fireproximityprompt,pp) end
              end
            end
          end)
        end
      end
    end
  end
end)
local WATCH={Padlock=true,MinesAnchor=true,ActivateEventPrompt=true,LootPrompt=true,Lava=true,ScaryWall=true,Seek_Arm=true,ChandelierObstruction=true,SeekFloodline=true,TriggerEventCollision=true,RoomsDoor_Entrance=true,ThingToOpen=true,MovingDoor=true,Wax_Door=true,Grinder1=true}
local Idx=setmetatable({},{__index=function(t,k) local s=setmetatable({},{__mode="k"}); rawset(t,k,s); return s end})
local function Index(d)
  local n=d.Name
  if WATCH[n] then Idx[n][d]=true end
  if d:IsA("ProximityPrompt") then
    AI.Set[d]=true
  elseif d:IsA("Model") then
    if d:GetAttribute("LoadModule")=="AnimatedObstacleKill" then Idx.Kill[d]=true end
    if n:find("[Cc][Rr][Ee][Aa][Kk]") then Stair.Creaks[d]=true end
  end
end
WS.DescendantAdded:Connect(Index)
task.spawn(function()
  local c=0
  for _,d in ipairs(WS:GetDescendants()) do
    Index(d); c=c+1
    if c%2000==0 then task.wait() end
  end
end)

local function Remotes() return RS:FindFirstChild("RemotesFolder") or RS:FindFirstChild("EntityInfo") or RS:FindFirstChild("Bricks") end
local function Rooms() return WS:FindFirstChild("CurrentRooms") end

local function SafeTP(target,hold)
  local char,_,root=GetChar(); if not char or not root then return false end
  local goal=typeof(target)=="CFrame" and target or CFrame.new(target)
  local saved={}
  for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then saved[p]=true; p.CanCollide=false end end
  for _=1,3 do char:PivotTo(goal); root.AssemblyLinearVelocity=Vector3.zero end
  task.spawn(function()
    local t0=os.clock()
    local conn; conn=RunSvc.Heartbeat:Connect(function()
      if os.clock()-t0>=(hold or 1.2) then conn:Disconnect(); for p in pairs(saved) do if p.Parent then p.CanCollide=true end end; return end
      local _,_,r2=GetChar(); if r2 and (r2.Position-goal.Position).Magnitude>3.5 then r2.Parent:PivotTo(goal) end
    end)
  end)
  return true
end

Funcs.GoTo=function(pred,label,extraRoots)
  task.spawn(function()
    local rooms=Rooms(); if not rooms then Notify(label,"Rooms not found","action") return end
    local list={}
    local function scan(root) local n=0 for _,d in ipairs(root:GetDescendants()) do local ok,hit=pcall(pred,d); if ok and hit then list[#list+1]=d end; n=n+1; if n%500==0 then task.wait() end end end
    scan(rooms)
    for _,r in ipairs(extraRoots or {}) do local rr=r(); if rr then scan(rr) end end
    local _,_,root=GetChar(); if not root then return end
    local best,bd
    for _,d in ipairs(list) do local p=PosOf(d); if p then local dist=(p-root.Position).Magnitude; if not bd or dist<bd then best,bd=d,dist end end end
    if best then local p=PosOf(best); if p then SafeTP(CFrame.new(p+Vector3.new(0,3,0))) Notify(label,"Teleported.","action") else Notify(label,"Not found.","action") end else Notify(label,"Not found.","action") end
  end)
end

Funcs.CompleteDam=function()
  local rooms=Rooms(); local char=GetChar(); if not rooms or not char then return end
  local pumps={}
  for _,o in ipairs(rooms:GetDescendants()) do if o.Name=="WaterPump" and o:IsA("Model") then pumps[#pumps+1]=o end end
  if #pumps==0 then Notify("Dam Seek","No water pumps found. Be in room 100.","action") return end
  task.spawn(function()
    local origin=char:GetPivot()
    table.sort(pumps,function(a,b) return a:GetPivot().Y>b:GetPivot().Y end)
    Notify("Dam Seek","Completing valves...","action")
    for _,pump in ipairs(pumps) do
      local t0=os.clock()
      while pump.Parent and os.clock()-t0<6 do
        task.wait(0.1)
        pcall(function() char:PivotTo(pump:GetPivot()) end)
        local prompt=pump:FindFirstChild("ValvePrompt",true)
        if prompt and prompt.Enabled and fireproximityprompt then pcall(fireproximityprompt,prompt) end
      end
    end
    pcall(function() char:PivotTo(origin) end)
    Notify("Dam Seek","Done.","action")
  end)
end

Funcs.CompleteCringle=function()
  local rooms=Rooms(); local char=GetChar(); if not rooms or not char then return end
  local p=rooms:FindFirstChild("RippleExitDoor",true)
  if p then SafeTP(p:GetPivot()); Notify("Cringle","Teleported to exit.","action") else Notify("Cringle","Exit not found.","action") end
end

Funcs.GetLibCode=function()
  local ch=LP.Character; if not ch then return nil end
  local paper=ch:FindFirstChild("LibraryHintPaper") or ch:FindFirstChild("LibraryHintPaperHard") or
    (LP:FindFirstChild("Backpack") and (LP.Backpack:FindFirstChild("LibraryHintPaper") or LP.Backpack:FindFirstChild("LibraryHintPaperHard")))
  if not paper or not paper:FindFirstChild("UI") then return nil end
  local pg=LP:FindFirstChild("PlayerGui")
  local permui=pg and pg:FindFirstChild("PermUI")
  local hints=permui and permui:FindFirstChild("Hints")
  if not hints then return nil end
  local code={"_","_","_","_","_"}
  for _,v in pairs(paper.UI:GetChildren()) do
    if v:IsA("ImageLabel") and v.Name~="Image" then
      for _,hh in pairs(hints:GetChildren()) do
        if hh:IsA("ImageLabel") and hh.Visible and v.ImageRectOffset==hh.ImageRectOffset then
          local idx=tonumber(v.Name)
          if idx and code[idx] then
            local tl=hh:FindFirstChild("TextLabel")
            if tl then code[idx]=tl.Text end
          end
        end
      end
    end
  end
  return table.concat(code)
end
local CL=Instance.new("PointLight")
CL.Range=10000
CL.Brightness=2
CL.Color=Color3.new(1,1,1)
S.Hooks.ClientGlow=function(v)
  if v then local _,_,r=GetChar(); if r then CL.Parent=r end else CL.Parent=nil end
end

Funcs.HookOxy=function(char)
  if not char then return end
  St.OxyLast=char:GetAttribute("Oxygen")
  if St.OxyConn then St.OxyConn:Disconnect() end
  St.OxyConn=char:GetAttributeChangedSignal("Oxygen"):Connect(function()
    local n=char:GetAttribute("Oxygen")
    if S.Ex.NotifyOxygen and type(n)=="number" and type(St.OxyLast)=="number" and n<St.OxyLast then
      Notify("Oxygen",math.floor(n*10)/10 .. "%","entity")
    end
    St.OxyLast=n
  end)
end
LP.CharacterAdded:Connect(Funcs.HookOxy)
if LP.Character then Funcs.HookOxy(LP.Character) end
LP.Idled:Connect(function()
  if S.Ex.DisableIdleKick then
    local vu=game:GetService("VirtualUser")
    vu:CaptureController()
    vu:ClickButton2(Vector2.new())
  end
end)
task.spawn(function()
  local HasteT=nil
  while true do
    task.wait(1.5)
    local fr=RS:FindFirstChild("FloorReplicated")
    local t=fr and fr:FindFirstChild("DigitalTimer")
    if t and HasteT~=t then
      HasteT=t
      St.HasteT=t
      if St.HasteConn then St.HasteConn:Disconnect() end
      St.HasteConn=t:GetPropertyChangedSignal("Value"):Connect(function()
        if not S.Ex.NotifyHaste then return end
        local v=math.max(0,math.floor(tonumber(t.Value) or 0))
        Notify("Haste",string.format("%02d:%02d",math.floor(v/60),v%60),"entity")
      end)
    end
  end
end)
task.spawn(function()
  local Notified=false
  while true do
    task.wait(0.4)
    if S.Ex.NotifyLibraryCode then
      local room=tonumber(LP:GetAttribute("CurrentRoom"))
      if room==50 then
        local code=Funcs.GetLibCode()
        if code and not code:find("_",1,true) and not Notified then
          Notified=true
          Notify("Library Code","Code: "..code,"action")
        end
      else
        Notified=false
      end
    end
  end
end)

task.spawn(function()
  local L={Pad=0,Anch=0,Guess=0,Loot=0}
  local LootOK=setmetatable({},{__mode="k"})
  local LOOT_WORDS={"drawer","goldpile","rolltop","chest","locker","wardrobe","desk","cabinet"}
  local function IsLootObj(obj)
    local v=LootOK[obj]
    if v==nil then
      v=false
      local n=obj.Name:lower()
      for _,w in ipairs(LOOT_WORDS) do if n:find(w,1,true) then v=true break end end
      LootOK[obj]=v
    end
    return v
  end
  local function NearPadlock(dist)
    for pd in pairs(Idx.Padlock) do
      if pd.Parent and pd:IsA("Model") and pd.PrimaryPart and LP:DistanceFromCharacter(pd.PrimaryPart.Position)<dist then return pd end
    end
  end
  while true do
    task.wait(0.15)
    local now=os.clock()
    local _,_,r=GetChar()
    if r then
      if S.Ex.AutoPadlock and now-L.Pad>0.3 then
        L.Pad=now
        if NearPadlock(S.Ex.AutoPadlockDist or 15) then
          local code=Funcs.GetLibCode()
          if code and not code:find("_",1,true) then
            local rf=Remotes()
            if rf and rf:FindFirstChild("PL") then pcall(function() rf.PL:FireServer(code) end) end
          end
        end
      end
      if S.Ex.AutoAnchors and now-L.Anch>0.4 then
        L.Anch=now
        local pg=LP:FindFirstChild("PlayerGui")
        local mu=pg and pg:FindFirstChild("MainUI")
        local ahf=mu and mu:FindFirstChild("AnchorHintFrame")
        local codeLabel=ahf and ahf:FindFirstChild("AnchorCode")
        local enteredLabel=ahf and ahf:FindFirstChild("Code")
        if codeLabel and enteredLabel then
          for anc in pairs(Idx.MinesAnchor) do
            if anc.Parent and anc:IsA("Model") and anc.PrimaryPart and not anc:GetAttribute("Activated") then
              local sg=anc:FindFirstChild("Sign")
              local sign=sg and sg:FindFirstChild("TextLabel")
              if sign and sign.Text==codeLabel.Text then
                local prompt=anc:FindFirstChild("ActivateEventPrompt")
                if prompt and LP:DistanceFromCharacter(anc.PrimaryPart.Position)<(prompt.MaxActivationDistance or 10) then
                  local remote=anc:FindFirstChild("AnchorRemote")
                  if remote then pcall(function() remote:InvokeServer(enteredLabel.Text) end) end
                end
              end
            end
          end
        end
      end
      if S.Ex.AutoLibraryGuess and now-L.Guess>0.5 then
        L.Guess=now
        if NearPadlock(15) then
          local code=Funcs.GetLibCode()
          if code then
            local guess=code:gsub("_",function() return tostring(math.random(0,9)) end)
            local rf=Remotes()
            if rf and rf:FindFirstChild("PL") then pcall(function() rf.PL:FireServer(guess) end) end
          end
        end
      end
      if S.Ex.AutoLoot and now-L.Loot>0.12 then
        L.Loot=now
        local range=S.Ex.AutoLootRange or 12
        local rp=r.Position
        for _,set in ipairs({Idx.ActivateEventPrompt,Idx.LootPrompt}) do
          for pp in pairs(set) do
            if pp.Parent and pp:IsA("ProximityPrompt") and pp.Enabled then
              local obj=pp.Parent.Parent
              if obj and IsLootObj(obj) and not pp:GetAttribute("Interactions") then
                local bp=(obj:IsA("Model") and obj.PrimaryPart) or obj:FindFirstChildWhichIsA("BasePart")
                if bp and (bp.Position-rp).Magnitude<=range then pcall(fireproximityprompt,pp) end
              end
            end
          end
        end
      end
    end
  end
end)

local function MainGame() local pg=LP:FindFirstChild("PlayerGui"); local mu=pg and pg:FindFirstChild("MainUI"); local ini=mu and mu:FindFirstChild("Initiator"); return ini and ini:FindFirstChild("Main_Game") end

local function SetupMinecart()
  task.spawn(function()
    local rooms=WS:WaitForChild("CurrentRooms",30); if not rooms then return end
    local function ScanCart(o)
      if o.Name=="RunnerNodes" then
        if Stair.Seen[o] then return end
        Stair.Seen[o]=true
        task.spawn(function()
          local function NodeId(n) return tonumber((n.Name:split("MinecartNode"))[2]) end
          local function Closest(node) local best,bd; local id=NodeId(node); for _,c in ipairs(o:GetChildren()) do local cid=NodeId(c); if c~=node and cid and id and cid>id then local d=(node.Position-c.Position).Magnitude; if not bd or d<bd then bd=d; best=c end end end return best end
          local function Dir(p1,p2) local r=p1.CFrame.RightVector:Dot(p1.Position-p2.Position); if r>0.5 then return "Left" elseif r<-0.5 then return "Right" end return "Straight" end
          for _,node in ipairs(o:GetChildren()) do if node:GetAttribute("ForceConnect") then local nx=Closest(node); if nx then node:SetAttribute("Turn",Dir(node,nx)); Stair.Nodes[#Stair.Nodes+1]=node end end end
        end)
      elseif o.Name=="DuckBoard" then Stair.Ducks[#Stair.Ducks+1]=o end
    end
    for _,d in ipairs(rooms:GetDescendants()) do ScanCart(d) end
    rooms.DescendantAdded:Connect(ScanCart)
  end)
end
SetupMinecart()

local function InCart() local cam=WS.CurrentCamera; return cam and cam:FindFirstChild("MinecartRig")~=nil end
pcall(function()
  local pm=require(LP.PlayerScripts:WaitForChild("PlayerModule"))
  local controls=pm:GetControls()
  local orig=controls.GetMoveVector
  controls.GetMoveVector=function(...)
    if S.Ex.CartPilot and Stair.Nearest and InCart() then
      local t=Stair.Nearest:GetAttribute("Turn")
      return t=="Left" and Vector3.new(-1,0,0) or t=="Right" and Vector3.new(1,0,0) or Vector3.zero
    end
    return orig(...)
  end
end)
RunSvc.Heartbeat:Connect(function()
  if not S.Ex.CartPilot or not InCart() or os.clock()-Stair.CartLast<0.1 then return end
  Stair.CartLast=os.clock()
  local near,nd
  for _,n in ipairs(Stair.Nodes) do if n.Parent then local d=LP:DistanceFromCharacter(n.Position); if d<30 and (not nd or d<nd) then near,nd=n,d end end end
  Stair.Nearest=near
  local duck=false
  for _,b in ipairs(Stair.Ducks) do if b.Parent and b.PrimaryPart and LP:DistanceFromCharacter(b.PrimaryPart.Position)<30 then duck=true break end end
  local mg=MainGame()
  if mg and mg.crouch then
    if duck and not Stair.Ducked then pcall(mg.crouch,true) Stair.Ducked=true
    elseif not duck and Stair.Ducked then pcall(mg.crouch,false) Stair.Ducked=false end
  end
end)

local function MeldRoot(inst)
  local p,i=inst,0
  while p and p~=WS and i<12 do if type(p.Name)=="string" and p.Name:lower():find("meld",1,true) and (p:IsA("Model") or p:IsA("Folder") or p:IsA("BasePart")) then return p end; p,i=p.Parent,i+1 end
end
local function MeldKeep(n)
  n=(n or ""):lower()
  for _,w in ipairs({"rope","cord","cable","chain","string","wire","door","gate","puerta","cuerda"}) do if n:find(w,1,true) then return true end end
end
local function MeldHandle(d)
  if S.Ex.StopMeldGrowth then
    if (d:IsA("Script") or d:IsA("LocalScript")) and (type(d.Name)=="string" and d.Name:lower():find("meld",1,true) or MeldRoot(d)) then
      if Mel.Scripts[d]==nil then Mel.Scripts[d]=d.Disabled end
      pcall(function() d.Disabled=true end)
    elseif d:IsA("ModuleScript") and type(d.Name)=="string" and d.Name:lower():find("meld",1,true) and not d.Name:find("_Disabled",1,true) then
      Mel.Scripts[d]=d.Name
      pcall(function() d.Name=d.Name.."_Disabled" end)
    end
  end
  if S.Ex.RemoveMeld and (d:IsA("BasePart") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Decal") or d:IsA("Texture")) then
    local root=MeldRoot(d)
    if root and not Plrs:GetPlayerFromCharacter(root) then
      local p,i=d,0; local keep=false
      while p and i<12 do if MeldKeep(p.Name) then keep=true break end; if p==root then break end; p,i=p.Parent,i+1 end
      if not keep then
        if d:IsA("BasePart") then
          if not Mel.Orig[d] then Mel.Orig[d]={T=d.Transparency,C=d.CanCollide,Tc=d.CanTouch} end
          d.Transparency,d.CanCollide,d.CanTouch=1,false,false
        elseif d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") or d:IsA("Light") then
          if not Mel.Orig[d] then Mel.Orig[d]={En=d.Enabled} end
          d.Enabled=false
        elseif d:IsA("Decal") or d:IsA("Texture") then
          if not Mel.Orig[d] then Mel.Orig[d]={T=d.Transparency} end
          d.Transparency=1
        end
      end
    end
  end
end
local function MeldScan()
  task.spawn(function()
    local n=0
    for _,scope in ipairs({WS,RS,LP:FindFirstChild("PlayerGui")}) do
      if scope then for _,d in ipairs(scope:GetDescendants()) do if not (S.Ex.StopMeldGrowth or S.Ex.RemoveMeld) then return end pcall(MeldHandle,d) n=n+1; if n%150==0 then task.wait() end end end end
    end
  end)
end
local function MeldRefresh()
  if S.Ex.StopMeldGrowth or S.Ex.RemoveMeld then
    if not Mel.Conn then Mel.Conn=WS.DescendantAdded:Connect(function(d) task.defer(pcall,MeldHandle,d) end) end
    MeldScan()
    if not Mel.Loop then Mel.Loop=true; task.spawn(function() while S.Ex.StopMeldGrowth or S.Ex.RemoveMeld do task.wait(20); MeldScan() end Mel.Loop=false end) end
  else
    if Mel.Conn then Mel.Conn:Disconnect(); Mel.Conn=nil end
    for obj,o in pairs(Mel.Orig) do
      pcall(function()
        if o.En~=nil then obj.Enabled=o.En
        elseif obj:IsA("BasePart") then obj.Transparency,obj.CanCollide,obj.CanTouch=o.T,o.C,o.Tc
        else obj.Transparency=o.T end
      end)
      Mel.Orig[obj]=nil
    end
    for obj,old in pairs(Mel.Scripts) do
      pcall(function() if typeof(old)=="string" then obj.Name=old else obj.Disabled=old end end)
      Mel.Scripts[obj]=nil
    end
  end
end
S.Hooks.StopMeldGrowth=function() MeldRefresh() end
S.Hooks.RemoveMeld=function() MeldRefresh() end

local function CrusherPass(del)
  local rooms=Rooms(); if not rooms then return end
  for _,room in ipairs(rooms:GetChildren()) do
    local assets=room:FindFirstChild("Assets")
    if assets then for _,cont in ipairs(assets:GetChildren()) do
      if cont.Name:find("^StairwellCrusherContainer") then
        local function UnderWall(d) local p=d.Parent; while p and p~=cont do if p.Name=="BasicWall" then return true end; p=p.Parent end return false end
        if del then
          local kill={}
          for _,d in ipairs(cont:GetDescendants()) do if d.Name~="BasicWall" and not UnderWall(d) then kill[#kill+1]=d end end
          for _,d in ipairs(kill) do if d.Parent then d:Destroy() end end
        else
          for _,d in ipairs(cont:GetDescendants()) do if d:IsA("BasePart") and d.CanCollide and not UnderWall(d) then d.CanCollide=false end end
          local crusher=cont:FindFirstChild("StairwellCrusher")
          if crusher then for _,n in ipairs({"OuterTrigger","CoreTrigger"}) do local t=crusher:FindFirstChild(n); if t then t:Destroy() end end end
        end
      end
    end end
  end
end
S.Hooks.NoCrushers=function(v) if v then task.spawn(function() while S.Ex.NoCrushers do pcall(CrusherPass,false); task.wait(0.5) end end) end end
S.Hooks.DeleteCrushers=function(v) if v then task.spawn(function() while S.Ex.DeleteCrushers do pcall(CrusherPass,true); task.wait(0.5) end end) end end
S.Hooks.RemoveMeldWalls=function(v) if v then task.spawn(function() while S.Ex.RemoveMeldWalls do local rooms=Rooms(); if rooms then for _,room in ipairs(rooms:GetChildren()) do for _,fn in ipairs({"Assets","Parts"}) do local f=room:FindFirstChild(fn); if f then for _,c in ipairs(f:GetChildren()) do if c.Name=="MeldWall" or c.Name=="Boleahghth29tdgfhy2thuy2htuu259uhh3u" then c:Destroy() end end end end; for _,n in ipairs({"MeldData","MeldPads","Meldview","Meld"}) do local o=room:FindFirstChild(n); if o and o:IsA("Folder") then o:Destroy() end end end end; task.wait(0.5) end end) end end
S.Hooks.NoiseTVOff=function(v)
  if v then task.spawn(function() while S.Ex.NoiseTVOff do local misc=WS:FindFirstChild("Misc"); if misc then for _,m in ipairs(misc:GetChildren()) do if m:IsA("Model") and m.Name=="TV_Stand" then local cf=m:GetPivot(); if cf.Position.Y>-119 then m:PivotTo(CFrame.new(cf.Position.X,-120,cf.Position.Z)) end end end end task.wait(0.25) end end) end
end
S.Hooks.AutoCollect=function(v)
  if v then task.spawn(function() while S.Ex.AutoCollect do local drops=WS:FindFirstChild("Drops"); local _,_,root=GetChar(); if drops and root then for _,it in ipairs(drops:GetChildren()) do if it:IsA("Model") then it:PivotTo(root.CFrame) elseif it:IsA("BasePart") then it.CFrame=root.CFrame end end end; task.wait(math.max(S.Ex.CollectInterval or 1,0.05)) end end) end
end
S.Hooks.AutoScrap=function(v)
  if v then task.spawn(function() while S.Ex.AutoScrap do
    local drops,rooms=WS:FindFirstChild("Drops"),Rooms()
    local _,_,root=GetChar()
    if drops and rooms and root then
      local best,bd
      for _,room in ipairs(rooms:GetChildren()) do local scr=room:FindFirstChild("StairwellScrapper",true); if scr then for _,o in ipairs(scr:GetDescendants()) do if o.Name=="Grinder1" and (o:IsA("Model") or o:IsA("BasePart")) then local d=(root.Position-o:GetPivot().Position).Magnitude; if not bd or d<bd then best,bd=o,d end end end end end
      if best then local cf=best:GetPivot(); for _,it in ipairs(drops:GetChildren()) do if it:IsA("Model") then it:PivotTo(cf) elseif it:IsA("BasePart") then it.CFrame=cf end end end
    end
    task.wait(math.max(S.Ex.CollectInterval or 1,0.05))
  end end) end
end
S.Hooks.OrbitDrops=function(v)
  if St.OrbitConn then St.OrbitConn:Disconnect(); St.OrbitConn=nil end
  if not v then return end
  local angle,last,pause=0,os.clock(),0
  St.OrbitConn=RunSvc.Heartbeat:Connect(function(dt)
    local _,_,root=GetChar(); local drops=WS:FindFirstChild("Drops")
    if not root or not drops then return end
    local list={} for _,it in ipairs(drops:GetChildren()) do if it:IsA("Model") or it:IsA("BasePart") then list[#list+1]=it end end
    if #list==0 then return end
    local now=os.clock()
    if now-last>=10 then last=now; pause=now+2; for _,it in ipairs(list) do if it:IsA("Model") then it:PivotTo(CFrame.new(root.Position)) elseif it:IsA("BasePart") then it.CFrame=CFrame.new(root.Position) end end end
    if now<pause then return end
    angle=angle+dt*(S.Ex.OrbitSpeed or 2)
    for i,it in ipairs(list) do
      local a=angle+((i-1)/#list)*math.pi*2
      local off=Vector3.new(math.cos(a)*(S.Ex.OrbitDistance or 5),S.Ex.OrbitHeight or 2,math.sin(a)*(S.Ex.OrbitDistance or 5))
      if it:IsA("Model") then it:PivotTo(CFrame.new(root.Position+off)) elseif it:IsA("BasePart") then it.CFrame=CFrame.new(root.Position+off) end
    end
  end)
end
S.Hooks.TrashLoop=function(v)
  Stair.TrashGen=Stair.TrashGen+1
  if not v then return end
  local my=Stair.TrashGen
  task.spawn(function()
    while S.Ex.TrashLoop and Stair.TrashGen==my do
      local rooms=Rooms()
      if rooms then
        for _,room in ipairs(rooms:GetChildren()) do
          local logic=room:FindFirstChild("StairwellLandingLogic")
          if logic then for _,m in ipairs(logic:GetChildren()) do
            if m:IsA("Model") then
              local prompts={}
              for _,o in ipairs(m:GetDescendants()) do if o:IsA("ProximityPrompt") then prompts[#prompts+1]=o end end
              if #prompts>0 then
                local char=GetChar(); if char then
                  char:PivotTo(m:GetPivot()+Vector3.new(0,5,0))
                  for _,p in ipairs(prompts) do if p.Parent and p.Enabled and fireproximityprompt then pcall(fireproximityprompt,p) end end
                  local rf=Remotes(); local drop=rf and rf:FindFirstChild("DropItem")
                  if drop then for _,t in ipairs(char:GetChildren()) do if t:IsA("Tool") then pcall(function() drop:FireServer(t) end) end end end
                end
                task.wait(1.5)
              end
            end
          end end
        end
      end
      task.wait(0.5)
    end
  end)
end
S.Hooks.CreakGlitch=function(v)
  if v then task.spawn(function()
    while S.Ex.CreakGlitch do
      local misc=WS:FindFirstChild("Misc"); local creak=WS:FindFirstChild("LiveEntities") and WS.LiveEntities:FindFirstChild("Creak")
      if creak then local cf=creak:GetPivot(); if misc then for _,m in ipairs(misc:GetChildren()) do if m.Name=="ShoppingCart" and m:IsA("Model") then m:PivotTo(cf) end end end end
      task.wait(0.1)
    end
  end) end
end

local function HookBypass(id)
  S.Hooks[id]=function(v)
    if v then
      for _,c in ipairs(WS:GetChildren()) do
        local n=c.Name:lower()
        if (id=="BypassGiggle" and n=="giggleceiling") or (id=="BypassDupe" and (n=="doorfake" or n=="fakedoor")) or (id=="BypassEyes" and (n=="eyes" or n=="lookman")) or (id=="BypassLookman" and (n=="lookman" or n=="backdoorlookman")) or (id=="BypassGloombatEggs" and n=="gloompile") or (id=="BypassVacuum" and n=="sideroomspace") or (id=="BypassSnare" and n=="snare") or (id=="BypassBanana" and n=="bananapeel") or (id=="BypassJeff" and n=="jeffthekiller") then
          for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanTouch=false; if id~="BypassSnare" and id~="BypassBanana" then p.CanCollide=false end end end
          if id=="BypassJeff" then local h=c:FindFirstChildOfClass("Humanoid"); if h then h.Health=0 end end
        end
      end
    end
  end
end
for _,id in ipairs({"BypassGiggle","BypassDupe","BypassEyes","BypassLookman","BypassGloombatEggs","BypassVacuum","BypassSnare","BypassBanana","BypassJeff"}) do HookBypass(id) end

S.Hooks.BypassSeekObstructions=function(v)
  for _,o in ipairs(WS:GetDescendants()) do
    if o.Name=="Seek_Arm" or o.Name=="ChandelierObstruction" then for _,p in ipairs(o:GetDescendants()) do if p:IsA("BasePart") then p.CanTouch=not v end end end
    if o.Name=="SeekFloodline" then o.CanCollide=v end
  end
end
S.Hooks.BypassKillbricks=function(v)
  for _,o in ipairs(WS:GetDescendants()) do if o.Name=="Lava" then o.CanTouch=not v end end
end
S.Hooks.BypassSeekingWall=function(v)
  for _,o in ipairs(WS:GetDescendants()) do if o.Name=="ScaryWall" then for _,p in ipairs(o:GetDescendants()) do if p:IsA("BasePart") then p.CanTouch=not v; p.CanCollide=not v end end end end
end

local function FindClientModule(name)
  local pg=LP:FindFirstChild("PlayerGui"); local mu=pg and pg:FindFirstChild("MainUI"); local ini=mu and mu:FindFirstChild("Initiator"); local mg=ini and ini:FindFirstChild("Main_Game"); local rl=mg and mg:FindFirstChild("RemoteListener"); local mods=rl and rl:FindFirstChild("Modules")
  if not mods then return nil end
  return mods:FindFirstChild(name) or mods:FindFirstChild(name.."_Disabled")
end
S.Hooks.RemoveScreech=function(v)
  local m=FindClientModule("Screech")
  if m then m.Name=v and "Screech_Disabled" or "Screech" end
  local fr=RS:FindFirstChild("FloorReplicated")
  if fr then for _,d in ipairs(fr:GetDescendants()) do if d.Name=="GlitchScreech" or d.Name=="GlitchScreech_Disabled" then d.Name=v and "GlitchScreech_Disabled" or "GlitchScreech" break end end end
end
S.Hooks.RemoveHalt=function(v) local m=FindClientModule("Shade"); if m then m.Name=v and "Shade_Disabled" or "Shade" end end
S.Hooks.RemoveA90=function(v) local m=FindClientModule("A90"); if m then m.Name=v and "A90_Disabled" or "A90" end end
S.Hooks.RemoveDread=function(v) local m=FindClientModule("Dread"); if m then m.Name=v and "Dread_Disabled" or "Dread" end end
S.Hooks.RemoveSurge=function(v) local ui=LP.PlayerGui:FindFirstChild("MainUI"); local mf=ui and ui:FindFirstChild("MainFrame"); local sv=mf and (mf:FindFirstChild("SurgeVignette") or mf:FindFirstChild("SurgeVignette_Disabled")); if sv then sv.Name=v and "SurgeVignette_Disabled" or "SurgeVignette" end end
S.Hooks.NoScreechDamage=function(v) end
S.Hooks.NoHaltDamage=function(v) end
S.Hooks.NoA90Damage=function(v) end
S.Hooks.NoSurgeDamage=function(v) end
S.Hooks.FigureGodmode=function() end
local OBST={ThingToOpen="RemoveBasementGate",MovingDoor="RemovePaintingsDoor",Wax_Door="RemoveSkeletonDoor"}
local function SetObstructionRemoved(obj,v)
  if not obj or not obj.Parent then return end
  if obj:GetAttribute("OrigPos")==nil then local ok,p=pcall(function() return obj:GetPivot() end); if ok then obj:SetAttribute("OrigPos",p) end end
  if v then obj:PivotTo(CFrame.new(-10000,-10000,-10000)) else local o=obj:GetAttribute("OrigPos"); if typeof(o)=="CFrame" then obj:PivotTo(o) end end
end
for objName,id in pairs(OBST) do
  S.Hooks[id]=function(v)
    task.spawn(function()
      while S.Ex[id] do
        for _,o in ipairs(WS:GetDescendants()) do if o.Name==objName and (o:IsA("Model") or o:IsA("BasePart")) then pcall(SetObstructionRemoved,o,v) end end
        task.wait(0.4)
      end
    end)
  end
end
S.Hooks.RemoveCutscenes=function(v)
  local CUTS={Figure=true,FigureEnd=true,FigureHotelEnd=true,FigureHotelFire=true,SeekIntroFools=true,SeekIntroHotel=true,SeekIntroMines=true,SeekIntroMines2=true,SerewSeekDrain=true,SewerSeekLower=true,GrumbleNestEnd=true,EyestalkIntro=true}
  local function Apply()
    local rl=MainGame() and MainGame():FindFirstChild("RemoteListener")
    local c1=rl and rl:FindFirstChild("Cutscenes")
    local c2=RS:FindFirstChild("FloorReplicated")
    for _,folder in ipairs({c1,c2}) do if folder then for _,o in ipairs(folder:GetChildren()) do if o:IsA("ModuleScript") then local base=o:GetAttribute("R4NOrig") or (o.Name:gsub("_Disabled$","")); if CUTS[base] then if o:GetAttribute("R4NOrig")==nil then o:SetAttribute("R4NOrig",base) end; local want=v and (base.."_Disabled") or base; if o.Name~=want then o.Name=want end end end end end end
  end
  task.spawn(function() for _=1,20 do if not S.Ex.RemoveCutscenes then return end pcall(Apply); task.wait(0.5) end end)
end
S.Hooks.DisableEntityJumpscares=function(v)
  local function Apply()
    local rl=MainGame() and MainGame():FindFirstChild("RemoteListener")
    local js=rl and (rl:FindFirstChild("Jumpscares") or rl:FindFirstChild("Jumpscares_Disabled"))
    if js then if js:GetAttribute("R4NOrig")==nil then js:SetAttribute("R4NOrig","Jumpscares") end; js.Name=v and "Jumpscares_Disabled" or "Jumpscares" end
    local fr=RS:FindFirstChild("FloorReplicated")
    if fr then for _,o in ipairs(fr:GetDescendants()) do if o:IsA("ModuleScript") then local b=o:GetAttribute("R4NOrig") or (o.Name:gsub("_Disabled$","")); if b:lower():find("jumpscare",1,true) and not b:lower():find("eyestalk",1,true) and not b:lower():find("groundskeeper",1,true) and not b:lower():find("monument",1,true) then if o:GetAttribute("R4NOrig")==nil then o:SetAttribute("R4NOrig",b) end; o.Name=v and (b.."_Disabled") or b end end end end
  end
  task.spawn(function() for _=1,20 do if not S.Ex.DisableEntityJumpscares then return end pcall(Apply); task.wait(0.5) end end)
end

S.Hooks.BypassFigure=function(v)
  Set("AutoHeartbeatMinigame",v); Set("CrouchSpoof",v); Set("FigureGodmode",v)
end

local function SetupACBypass()
  local hookmm=hookmetamethod; local nc=newcclosure; local gnm=getnamecallmethod
  if not (hookmm and nc and gnm) then return end
  S.Globals=S.Globals or {}
  S.Globals.AnticheatDisabled=false
  local MainHook
  MainHook=hookmm(game,"__namecall",nc(function(Self,...)
    local Args={...}; local Method=gnm()
    if Self.Name=="ClutchHeartbeat" and Method=="FireServer" and S.Ex.AutoHeartbeatMinigame then return end
    if Self.Name=="HideMonster" and Method=="FireServer" and S.Ex.AutoHeartbeatMinigame then return end
    if Self.Name=="Crouch" and Method=="FireServer" and S.Ex.CrouchSpoof then Args[1]=true Args[2]=true end
    return MainHook(Self,table.unpack(Args))
  end))
  local rf=Remotes()
  task.spawn(function()
    while not LP.Character do task.wait(0.2) end
    local ch=LP.Character
    task.spawn(function()
      while true do
        task.wait(0.25)
        if ch and ch.Parent then
          if ch:GetAttribute("Climbing")==true and S.Ex.ACBypass and not S.Globals.AnticheatDisabled then
            task.wait(0.25)
            pcall(function() ch:SetAttribute("Climbing",false) end)
            S.Globals.AnticheatDisabled=true
            Notify("AC Bypass","Anticheat disabled. Re-enables after a cutscene.","feature")
          end
        else ch=LP.Character end
      end
    end)
    if rf and rf:FindFirstChild("Cutscene") then
      rf.Cutscene.OnClientEvent:Connect(function(name)
        if S.Globals.AnticheatDisabled and not tostring(name):find("SewerSeek") then S.Globals.AnticheatDisabled=false end
      end)
    end
  end)
end
SetupACBypass()


local LoopGen={}
local function Loop(id,delay,fn)
  LoopGen[id]=(LoopGen[id] or 0)+1
  local my=LoopGen[id]
  if not S.Ex[id] then return end
  task.spawn(function()
    while S.Ex[id] and LoopGen[id]==my do
      pcall(fn)
      task.wait(type(delay)=="function" and delay() or delay)
    end
  end)
end

S.Hooks.A90Bypass=function()
  Loop("A90Bypass",0.23,function()
    local rf=Remotes(); local a=rf and rf:FindFirstChild("A90")
    if a then a:FireServer("didnt") end
  end)
end
S.Hooks.ObjectBypass=function()
  Loop("ObjectBypass",0.5,function()
    for o in pairs(Idx.Kill) do
      if o.Parent then
        for _,p in ipairs(o:GetDescendants()) do
          if p:IsA("BasePart") and (p.CanTouch or p.CanQuery) then p.CanTouch=false; p.CanQuery=false end
        end
      end
    end
  end)
end
S.Hooks.A000NoLock=function()
  Loop("A000NoLock",0.5,function()
    for o in pairs(Idx.RoomsDoor_Entrance) do
      if o.Parent then local p=o:FindFirstChild("EnterPrompt",true); if p and not p.Enabled then p.Enabled=true end end
    end
  end)
end
S.Hooks.NoCrushers=function() Loop("NoCrushers",0.5,function() CrusherPass(false) end) end
S.Hooks.DeleteCrushers=function() Loop("DeleteCrushers",0.5,function() CrusherPass(true) end) end

local MW_F={"Assets","Parts"}
local MW_N={"MeldData","MeldPads","Meldview","Meld"}
S.Hooks.RemoveMeldWalls=function()
  Loop("RemoveMeldWalls",0.5,function()
    local rooms=Rooms(); if not rooms then return end
    for _,room in ipairs(rooms:GetChildren()) do
      for _,fn in ipairs(MW_F) do
        local f=room:FindFirstChild(fn)
        if f then for _,c in ipairs(f:GetChildren()) do if c.Name=="MeldWall" or c.Name=="Boleahghth29tdgfhy2thuy2htuu259uhh3u" then c:Destroy() end end end
      end
      for _,n in ipairs(MW_N) do local o=room:FindFirstChild(n); if o and o:IsA("Folder") then o:Destroy() end end
    end
  end)
end
S.Hooks.NoiseTVOff=function()
  Loop("NoiseTVOff",0.25,function()
    local misc=WS:FindFirstChild("Misc"); if not misc then return end
    for _,m in ipairs(misc:GetChildren()) do
      if m.Name=="TV_Stand" and m:IsA("Model") then
        local cf=m:GetPivot()
        if cf.Position.Y>-119 then m:PivotTo(CFrame.new(cf.Position.X,-120,cf.Position.Z)) end
      end
    end
  end)
end

local function CollectDelay() return math.max(S.Ex.CollectInterval or 1,0.05) end
S.Hooks.AutoCollect=function()
  Loop("AutoCollect",CollectDelay,function()
    local drops=WS:FindFirstChild("Drops"); local _,_,root=GetChar()
    if not (drops and root) then return end
    for _,it in ipairs(drops:GetChildren()) do
      if it:IsA("Model") then it:PivotTo(root.CFrame) elseif it:IsA("BasePart") then it.CFrame=root.CFrame end
    end
  end)
end
S.Hooks.AutoScrap=function()
  Loop("AutoScrap",CollectDelay,function()
    local drops=WS:FindFirstChild("Drops"); local _,_,root=GetChar()
    if not (drops and root and Rooms()) then return end
    local best,bd
    for g in pairs(Idx.Grinder1) do
      if g.Parent and (g:IsA("Model") or g:IsA("BasePart")) then
        local d=(root.Position-g:GetPivot().Position).Magnitude
        if not bd or d<bd then best,bd=g,d end
      end
    end
    if not best then return end
    local cf=best:GetPivot()
    for _,it in ipairs(drops:GetChildren()) do
      if it:IsA("Model") then it:PivotTo(cf) elseif it:IsA("BasePart") then it.CFrame=cf end
    end
  end)
end
S.Hooks.CreakGlitch=function()
  Loop("CreakGlitch",0.1,function()
    local le=WS:FindFirstChild("LiveEntities"); local creak=le and le:FindFirstChild("Creak")
    local misc=WS:FindFirstChild("Misc")
    if not (creak and misc) then return end
    local cf=creak:GetPivot()
    for _,m in ipairs(misc:GetChildren()) do if m.Name=="ShoppingCart" and m:IsA("Model") then m:PivotTo(cf) end end
  end)
end
S.Hooks.RemoveSeekTrigger=function()
  Loop("RemoveSeekTrigger",0.1,function()
    local _,_,root=GetChar(); if not (root and firetouchinterest) then return end
    for o in pairs(Idx.TriggerEventCollision) do
      if o.Parent then
        for _,p in ipairs(o:GetChildren()) do
          if p:IsA("BasePart") then firetouchinterest(root,p,0); task.wait(); firetouchinterest(root,p,1) end
        end
      end
    end
  end)
end
S.Hooks.BypassSeek=function(v)
  Set("RemoveSeekTrigger",v)
  if not v then return end
  local fr=RS:FindFirstChild("FloorReplicated")
  if fr then
    for _,d in ipairs(fr:GetDescendants()) do
      if d:IsA("ModuleScript") then
        local l=d.Name:lower()
        if l:find("seek",1,true) and l:find("jumpscare",1,true) and not l:find("_disabled",1,true) then
          d:SetAttribute("R4NOrig",d.Name); d.Name=d.Name.."_Disabled"
        end
      end
    end
  end
end
S.Hooks.DeleteFigure=function()
  Loop("DeleteFigure",0.2,function()
    if not isnetworkowner then return end
    for _,c in ipairs(WS:GetChildren()) do
      local n=c.Name
      if n=="Figure" or n=="FigureRig" or n=="FigureRagdoll" then
        for _,p in ipairs(c:GetDescendants()) do
          if p:IsA("BasePart") and isnetworkowner(p) then p.Position=Vector3.new(-49999,-49999,-49999) end
        end
      end
    end
  end)
end
S.Hooks.AutoRevive=function()
  Loop("AutoRevive",0.5,function()
    if LP:GetAttribute("Alive")==false then
      local rf=Remotes()
      if rf and rf:FindFirstChild("Revive") then rf.Revive:FireServer() end
    end
  end)
end
local CRUC={"RushMoving","AmbushMoving","A60","A120","GlitchRush","GlitchAmbush","BackdoorRush"}
S.Hooks.InfCrucifix=function()
  Loop("InfCrucifix",0.1,function()
    local char=LP.Character; local rf=Remotes(); local drop=rf and rf:FindFirstChild("DropItem")
    if not (char and drop) then return end
    local tool=char:FindFirstChildOfClass("Tool")
    if not (tool and tool.Name=="Crucifix") then return end
    for _,n in ipairs(CRUC) do
      local e=WS:FindFirstChild(n); local pp=e and e.PrimaryPart
      if pp and LP:DistanceFromCharacter(pp.Position)<60 then
        drop:FireServer(tool)
        task.wait(0.5)
        local drops=WS:FindFirstChild("Drops"); local dr=drops and drops:FindFirstChild("Crucifix")
        local pk=dr and dr:FindFirstChildWhichIsA("ProximityPrompt",true)
        if pk and fireproximityprompt then fireproximityprompt(pk) end
        break
      end
    end
  end)
end

local function ObstSet(o,v)
  if o:GetAttribute("OrigPos")==nil then local ok,p=pcall(o.GetPivot,o); if ok then o:SetAttribute("OrigPos",p) end end
  if v then
    if o:GetPivot().Position.Y>-9000 then o:PivotTo(CFrame.new(-10000,-10000,-10000)) end
  else
    local p=o:GetAttribute("OrigPos"); if typeof(p)=="CFrame" then o:PivotTo(p) end
  end
end
for objName,id in pairs(OBST) do
  S.Hooks[id]=function(v)
    for o in pairs(Idx[objName]) do if o.Parent and (o:IsA("Model") or o:IsA("BasePart")) then pcall(ObstSet,o,v) end end
    Loop(id,0.5,function()
      for o in pairs(Idx[objName]) do if o.Parent and (o:IsA("Model") or o:IsA("BasePart")) then ObstSet(o,true) end end
    end)
  end
end

S.Hooks.BypassSeekObstructions=function(v)
  for _,n in ipairs({"Seek_Arm","ChandelierObstruction"}) do
    for o in pairs(Idx[n]) do
      if o.Parent then for _,p in ipairs(o:GetDescendants()) do if p:IsA("BasePart") then p.CanTouch=not v end end end
    end
  end
  for o in pairs(Idx.SeekFloodline) do if o.Parent and o:IsA("BasePart") then o.CanCollide=v end end
end
S.Hooks.BypassKillbricks=function(v)
  for o in pairs(Idx.Lava) do if o.Parent and o:IsA("BasePart") then o.CanTouch=not v end end
end
S.Hooks.BypassSeekingWall=function(v)
  for o in pairs(Idx.ScaryWall) do
    if o.Parent then for _,p in ipairs(o:GetDescendants()) do if p:IsA("BasePart") then p.CanTouch=not v; p.CanCollide=not v end end end
  end
end


RunSvc.Stepped:Connect(function()
  local char,hum,root=GetChar(); if not char then return end
  if S.Ex.Phasing then
    local pt=os.clock()
    if St.PhChar~=char or pt-(St.PhAt or 0)>1 then
      St.PhChar,St.PhAt,St.PhParts=char,pt,{}
      for _,p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
          St.PhParts[#St.PhParts+1]=p
          if p:GetAttribute("R4NNC")==nil then p:SetAttribute("R4NNC",p.CanCollide) end
        end
      end
    end
    for _,p in ipairs(St.PhParts) do if p.CanCollide then p.CanCollide=false end end
  end
  if S.Ex.FallGuard and root then
    if not St.LastSafe then St.LastSafe=root.CFrame end
    if hum.FloorMaterial~=Enum.Material.Air then St.LastSafe=root.CFrame end
    if root.Position.Y<St.LastSafe.Position.Y-60 and (S.Ex.Phasing or S.Ex.Flight) then root.CFrame=St.LastSafe+Vector3.new(0,3,0); root.AssemblyLinearVelocity=Vector3.zero end
  end
  if S.Ex.AntiSpeedBypass and hum then
    local want=S.Ex.WalkSpeedValue or 30
    if hum.WalkSpeed<want then hum.WalkSpeed=want end
  end
end)

RunSvc.Heartbeat:Connect(function(dt)
  local now=os.clock()
  local char,hum,root=GetChar(); if not char then return end
  if S.Ex.BrightVision and now-St.LastLight>0.2 then
    St.LastLight=now
    pcall(function() Ltg.Brightness=7.5; Ltg.ClockTime=14; Ltg.GlobalShadows=false; local amb=Color3.fromRGB(200,200,200); Ltg.Ambient=amb; Ltg.OutdoorAmbient=amb end)
  end
  if S.Ex.NoFog and now-(St.LastFog or 0)>0.2 then St.LastFog=now
    pcall(function() Ltg.FogEnd=100000; Ltg.FogStart=100000; for _,a in ipairs(Ltg:GetChildren()) do if a:IsA("Atmosphere") then if not St.AtmoOrig[a] then St.AtmoOrig[a]={a.Density,a.Haze} end; a.Density,a.Haze=0,0 end end end)
  end
  if S.Ex.WalkSpeed then local want=S.Ex.WalkSpeedValue or 30; if hum.WalkSpeed~=want then hum.WalkSpeed=want end end
  if S.Ex.Jump then local jp=S.Ex.JumpPower or 50; if not hum.UseJumpPower then hum.UseJumpPower=true end; if hum.JumpPower~=jp then hum.JumpPower=jp end end
  if S.Ex.Flight then
    local md=hum.MoveDirection
    local vert=0
    if UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump then vert=1 end
    if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vert=-1 end
    local fs=S.Ex.FlightSpeed or 40; root.AssemblyLinearVelocity=Vector3.new(md.X*fs,vert*fs,md.Z*fs)
  end
end)

UIS.JumpRequest:Connect(function()
  local _,hum=GetChar(); if not hum then return end
  if S.Ex.AirJump then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

RunSvc.RenderStepped:Connect(function()
  if S.Ex.FOVOverride then local cam=WS.CurrentCamera; if cam then cam.FieldOfView=Esp.Cfg.FOV end end
  if S.Ex.ThirdPerson then local cam=WS.CurrentCamera; if cam then cam.CFrame=cam.CFrame*CFrame.new(2,1,5) end end
  if S.Ex.ClientGlow then
    local _,_,r=GetChar()
    if r and CL.Parent~=r then CL.Parent=r end
  elseif CL.Parent then CL.Parent=nil end
end)

WS.ChildAdded:Connect(function(m)
  if not S.Ex.EntityAlerts then return end
  if not m:IsA("Model") or Plrs:GetPlayerFromCharacter(m) then return end
  if St.Seen[m] then return end
  if not IsEntity(m.Name) then return end
  St.Seen[m]=true
  local now=os.clock(); local cd=S.Ex.AlertCooldown or 4
  if St.Last[m.Name] and now-St.Last[m.Name]<cd then return end
  St.Last[m.Name]=now
  Notify(m.Name.." appeared!","Mode: "..(Mode.Name or "Unknown"),"entity")
end)

WS.ChildRemoved:Connect(function(m)
  if not S.Ex.EntityAlerts then return end
  if St.Seen[m] and IsEntity(m.Name) then
    if S.Ex.DespawnAlerts~=false then Notify(m.Name.." despawned","You're safe now","entity") end
  end
end)

for _,c in ipairs(WS:GetChildren()) do if c:IsA("Model") and IsEntity(c.Name) then St.Seen[c]=true end end

task.spawn(function()
  local gd=RS:WaitForChild("GameData",30)
  if not gd then return end
  local f=gd:FindFirstChild("Floor")
  task.wait(1)
  if f then
    local v=tostring(f.Value)
    if v=="Hotel" or v=="Mines" or v=="Backdoor" or v=="Outdoors" or v=="Archives" or v=="Stairwell" or v=="Rooms" or v=="Fools" or v=="Garden" then Mode.Name=v end
  end
end)

local ESP_CATS={"Doors","Keys","Gold","Chests","Drawers","Lockers","Items","Entities","Players","Wardrobes","Objectives","Stardust","Glitch","Lotus","Scanner","Stairs","Exit","Cart","Interactables"}
local NAMES_COL=Color3.fromRGB(255,60,60)
local function AddESP(cat,name)
  MK:AddToggle(cat,{Text=name,Default=false,Notify=false,Callback=function(v) Esp.Cfg[cat]=v; local any=false; for _,c in ipairs(ESP_CATS) do if Esp.Cfg[c] then any=true break end end; Esp.Cfg.Enabled=any end})
end
AddESP("Doors","Doors")
AddESP("Keys","Keys")
AddESP("Gold","Gold")
AddESP("Chests","Chests")
AddESP("Drawers","Drawers")
AddESP("Lockers","Lockers")
AddESP("Items","Items")
AddESP("Entities","Entities")
AddESP("Players","Players")
AddESP("Wardrobes","Hiding Spots")
AddESP("Objectives","Objectives")
AddESP("Stardust","Stardust")
AddESP("Glitch","Glitch Fragment")
AddESP("Lotus","Lotus Petals")
AddESP("Scanner","Scanner Module")
AddESP("Stairs","Stairs & Ladders")
AddESP("Exit","Emergency Exit")
AddESP("Cart","Shopping Cart")
AddESP("Interactables","Interactables")

MKO:AddToggle("ShowNames",{Text="Show Names",Default=false,Notify=false,Callback=function(v) Esp.Cfg.ShowNames=v end})
MKO:AddSlider("MinGoldValue",{Text="Min Gold Value",Min=0,Max=150,Default=0,Callback=function(v) S.Ex.MinGoldValue=v end})
MKO:AddButton({Text="Clear All",Callback=function()
  for _,cat in ipairs(ESP_CATS) do Esp.Cfg[cat]=false; if Toggles[cat] then pcall(function() Toggles[cat]:SetValue(false) end) end end
  Esp.Cfg.Enabled=false
end})

CAM:AddToggle("FOVOverride",{Text="FOV Override",Default=false,Notify=false,Callback=function(v) S.Ex.FOVOverride=v end})
CAM:AddSlider("FOVValue",{Text="Field of View",Min=1,Max=120,Default=70,Callback=function(v) Esp.Cfg.FOV=v end})
CAM:AddToggle("ThirdPerson",{Text="Third Person",Default=false,Notify=false,Callback=function(v) S.Ex.ThirdPerson=v end})

FXG:AddToggle("NoHideVignette",{Text="No Hide Vignette",Default=false,Notify=false,Callback=function(v) S.Ex.NoHideVignette=v end})
FXG:AddToggle("NoGlitchScare",{Text="No Glitch Scare",Default=false,Notify=false,Callback=function(v) S.Ex.NoGlitchScare=v; local fr=RS:FindFirstChild("ModulesClient") or RS:FindFirstChild("ClientModules"); local em=fr and fr:FindFirstChild("EntityModules"); if em then local m=em:FindFirstChild("Glitch"); if m then m.Name=v and "Glitch_Disabled" or "Glitch" end end end})
FXG:AddToggle("NoTimothyScare",{Text="No Timothy Scare",Default=false,Notify=false,Callback=function(v) local fr=RS:FindFirstChild("ModulesClient") or RS:FindFirstChild("ClientModules"); local em=fr and fr:FindFirstChild("EntityModules"); if em then local m=em:FindFirstChild("SpiderJumpscare"); if m then m.Name=v and "SpiderJumpscare_Disabled" or "SpiderJumpscare" end end end})
FXG:AddToggle("NoVoidScare",{Text="No Void Scare",Default=false,Notify=false,Callback=function(v) local fr=RS:FindFirstChild("ModulesClient") or RS:FindFirstChild("ClientModules"); local em=fr and fr:FindFirstChild("EntityModules"); if em then local m=em:FindFirstChild("Void"); if m then m.Name=v and "Void_Disabled" or "Void" end end end})
FXG:AddToggle("NoCamShake",{Text="No Camera Shake",Default=false,Notify=false,Callback=function(v) S.Ex.NoCamShake=v end})
FXG:AddToggle("NoCamBob",{Text="No Camera Bob",Default=false,Notify=false,Callback=function(v) S.Ex.NoCamBob=v end})
FXG:AddToggle("NoFiredamp",{Text="No Firedamp",Default=false,Notify=false,Callback=function(v) S.Ex.NoFiredamp=v end})

MV:AddToggle("WalkSpeed",{Text="Walk Speed",Default=false,Notify=false,Callback=function(v) Toggle("WalkSpeed",v) end})
MV:AddSlider("WalkSpeedValue",{Text="Speed Amount",Min=1,Max=100,Default=30,Callback=function(v) S.Ex.WalkSpeedValue=v end})
MV:AddToggle("AntiSpeedBypass",{Text="Anti Speed Bypass",Default=false,Notify=false,Callback=function(v) S.Ex.AntiSpeedBypass=v end})
MV:AddToggle("Jump",{Text="Jump",Default=false,Notify=false,Callback=function(v) Toggle("Jump",v) end})
MV:AddSlider("JumpPower",{Text="Jump Power",Min=20,Max=120,Default=50,Callback=function(v) S.Ex.JumpPower=v end})
MV:AddToggle("AirJump",{Text="Air Jump",Default=false,Notify=false,Callback=function(v) S.Ex.AirJump=v end})
MV:AddToggle("Slide",{Text="Slide",Default=false,Notify=false,Callback=function(v) Toggle("Slide",v) end})
MV:AddSlider("SlideSpeed",{Text="Slide Speed",Min=30,Max=90,Default=55,Callback=function(v) S.Ex.SlideSpeed=v end})
MV:AddToggle("Flight",{Text="Flight",Default=false,Notify=false,Callback=function(v) Toggle("Flight",v) end})
MV:AddSlider("FlightSpeed",{Text="Flight Speed",Min=10,Max=90,Default=40,Callback=function(v) S.Ex.FlightSpeed=v end})
MV:AddToggle("Phasing",{Text="Phase",Default=false,Notify=false,Callback=function(v) Toggle("Phasing",v) end})
MV:AddToggle("NoClosetDelay",{Text="No Closet Delay",Default=false,Notify=false,Callback=function(v) S.Ex.NoClosetDelay=v end})
MV:AddToggle("NoAcceleration",{Text="No Acceleration",Default=false,Notify=false,Callback=function(v) Toggle("NoAcceleration",v) end})
MV:AddToggle("DisableIdleKick",{Text="Disable Idle Kick",Default=false,Notify=false,Callback=function(v) S.Ex.DisableIdleKick=v end})

VIS:AddToggle("BrightVision",{Text="Bright Vision",Default=false,Notify=false,Callback=function(v) Toggle("BrightVision",v) end})
VIS:AddToggle("NoFog",{Text="No Fog",Default=false,Notify=false,Callback=function(v) Toggle("NoFog",v) end})
VIS:AddToggle("ClientGlow",{Text="Client Glow",Default=false,Notify=false,Callback=function(v) Toggle("ClientGlow",v) end})

BOT:AddToggle("CartPilot",{Text="Cart Pilot",Default=false,Notify=false,Callback=function(v) S.Ex.CartPilot=v end})
BOT:AddButton({Text="Complete Dam Seek",Callback=function() Funcs.CompleteDam() end})
BOT:AddButton({Text="Complete Cringle",Callback=function() Funcs.CompleteCringle() end})

ITM:AddToggle("InstantPrompts",{Text="Instant Prompts",Default=false,Notify=false,Callback=function(v) Toggle("InstantPrompts",v) end})
ITM:AddToggle("AutoTrigger",{Text="Auto Trigger",Default=false,Notify=false,Callback=function(v) S.Ex.AutoTrigger=v end})
ITM:AddToggle("ItemSaver",{Text="Item Saver",Default=false,Notify=false,Callback=function(v) Toggle("ItemSaver",v) end})
ITM:AddDropdown("ItemsToSave",{Text="Items to Save",Values={"Lockpicks","Skeleton Key","Shears","Multitool"},Multi=true,Default={"Lockpicks","Skeleton Key","Shears","Multitool"},Callback=function(v) local out={}; for k,val in pairs(v) do if val then out[#out+1]=k end end; S.Ex.ItemsToSave=out end})
ITM:AddToggle("AutoPadlock",{Text="Auto Unlock Padlock",Default=false,Notify=false,Callback=function(v) S.Ex.AutoPadlock=v end})
ITM:AddSlider("AutoPadlockDist",{Text="Padlock Distance",Min=5,Max=50,Default=15,Callback=function(v) S.Ex.AutoPadlockDist=v end})
ITM:AddToggle("AutoLibraryGuess",{Text="Auto Library Guess",Default=false,Notify=false,Callback=function(v) S.Ex.AutoLibraryGuess=v end})
ITM:AddToggle("AutoAnchors",{Text="Auto Solve Anchors",Default=false,Notify=false,Callback=function(v) S.Ex.AutoAnchors=v end})
ITM:AddToggle("AutoLoot",{Text="Auto Loot Nearby",Default=false,Notify=false,Callback=function(v) S.Ex.AutoLoot=v end})
ITM:AddSlider("AutoLootRange",{Text="Auto Loot Range",Min=3,Max=30,Default=12,Callback=function(v) S.Ex.AutoLootRange=v end})

BYP:AddToggle("ACBypass",{Text="AC Bypass",Default=false,Notify=false,Callback=function(v) Toggle("ACBypass",v) end})
BYP:AddToggle("AutoHeartbeatMinigame",{Text="Auto Heartbeat Minigame",Default=false,Notify=false,Callback=function(v) S.Ex.AutoHeartbeatMinigame=v end})
BYP:AddToggle("A90Bypass",{Text="Bypass A-90",Default=false,Notify=false,Callback=function(v) Toggle("A90Bypass",v) end})
BYP:AddToggle("ObjectBypass",{Text="Object Bypass",Default=false,Notify=false,Callback=function(v) Toggle("ObjectBypass",v) end})
BYP:AddToggle("FallGuard",{Text="Fall Guard",Default=false,Notify=false,Callback=function(v) S.Ex.FallGuard=v end})
BYP:AddToggle("BypassSeek",{Text="Bypass Seek",Default=false,Notify=false,Callback=function(v) Toggle("BypassSeek",v) end})
BYP:AddToggle("BypassFigure",{Text="Bypass Figure",Default=false,Notify=false,Callback=function(v) Toggle("BypassFigure",v) end})

IGN:AddToggle("BypassGiggle",{Text="Ignore Giggle",Default=false,Notify=false,Callback=function(v) Toggle("BypassGiggle",v) end})
IGN:AddToggle("BypassDupe",{Text="Ignore Dupe",Default=false,Notify=false,Callback=function(v) Toggle("BypassDupe",v) end})
IGN:AddToggle("BypassEyes",{Text="Ignore Eyes",Default=false,Notify=false,Callback=function(v) Toggle("BypassEyes",v) end})
IGN:AddToggle("BypassLookman",{Text="Ignore Lookman",Default=false,Notify=false,Callback=function(v) Toggle("BypassLookman",v) end})
IGN:AddToggle("BypassGloombatEggs",{Text="Ignore Gloombat Eggs",Default=false,Notify=false,Callback=function(v) Toggle("BypassGloombatEggs",v) end})
IGN:AddToggle("BypassSeekObstructions",{Text="Ignore Seek Obstructions",Default=false,Notify=false,Callback=function(v) Toggle("BypassSeekObstructions",v) end})
IGN:AddToggle("BypassVacuum",{Text="Ignore Vacuum",Default=false,Notify=false,Callback=function(v) Toggle("BypassVacuum",v) end})
IGN:AddToggle("BypassKillbricks",{Text="Ignore Killbricks",Default=false,Notify=false,Callback=function(v) Toggle("BypassKillbricks",v) end})
IGN:AddToggle("BypassSeekingWall",{Text="Ignore Seeking Wall",Default=false,Notify=false,Callback=function(v) Toggle("BypassSeekingWall",v) end})
IGN:AddToggle("BypassSnare",{Text="Ignore Snare",Default=false,Notify=false,Callback=function(v) Toggle("BypassSnare",v) end})
IGN:AddToggle("BypassBanana",{Text="Ignore Banana",Default=false,Notify=false,Callback=function(v) Toggle("BypassBanana",v) end})
IGN:AddToggle("BypassJeff",{Text="Ignore Jeff",Default=false,Notify=false,Callback=function(v) Toggle("BypassJeff",v) end})

BLK:AddToggle("RemoveScreech",{Text="Block Screech",Default=false,Notify=false,Callback=function(v) Toggle("RemoveScreech",v) end})
BLK:AddToggle("RemoveHalt",{Text="Block Halt",Default=false,Notify=false,Callback=function(v) Toggle("RemoveHalt",v) end})
BLK:AddToggle("RemoveA90",{Text="Block A-90",Default=false,Notify=false,Callback=function(v) Toggle("RemoveA90",v) end})
BLK:AddToggle("RemoveDread",{Text="Block Dread",Default=false,Notify=false,Callback=function(v) Toggle("RemoveDread",v) end})
BLK:AddToggle("RemoveSurge",{Text="Block Surge",Default=false,Notify=false,Callback=function(v) Toggle("RemoveSurge",v) end})
BLK:AddToggle("NoScreechDamage",{Text="No Screech Damage",Default=false,Notify=false,Callback=function(v) S.Ex.NoScreechDamage=v end})
BLK:AddToggle("NoHaltDamage",{Text="No Halt Damage",Default=false,Notify=false,Callback=function(v) S.Ex.NoHaltDamage=v end})
BLK:AddToggle("NoA90Damage",{Text="No A-90 Damage",Default=false,Notify=false,Callback=function(v) S.Ex.NoA90Damage=v end})
BLK:AddToggle("NoSurgeDamage",{Text="No Surge Damage",Default=false,Notify=false,Callback=function(v) S.Ex.NoSurgeDamage=v end})

FLR:AddToggle("RemoveSeekTrigger",{Text="No Seek Trigger",Default=false,Notify=false,Callback=function(v) Toggle("RemoveSeekTrigger",v) end})
FLR:AddToggle("DeleteFigure",{Text="Delete Figure",Default=false,Notify=false,Callback=function(v) Toggle("DeleteFigure",v) end})
FLR:AddToggle("AutoRevive",{Text="Endless Revives",Default=false,Notify=false,Callback=function(v) Toggle("AutoRevive",v) end})
FLR:AddToggle("FigureGodmode",{Text="Figure Godmode",Default=false,Notify=false,Callback=function(v) S.Ex.FigureGodmode=v end})
FLR:AddToggle("RemoveBasementGate",{Text="Remove Basement Gate",Default=false,Notify=false,Callback=function(v) Toggle("RemoveBasementGate",v) end})
FLR:AddToggle("RemovePaintingsDoor",{Text="Remove Paintings Door",Default=false,Notify=false,Callback=function(v) Toggle("RemovePaintingsDoor",v) end})
FLR:AddToggle("RemoveSkeletonDoor",{Text="Remove Skeleton Door",Default=false,Notify=false,Callback=function(v) Toggle("RemoveSkeletonDoor",v) end})
FLR:AddToggle("A000NoLock",{Text="A-000 Door No Lock",Default=false,Notify=false,Callback=function(v) Toggle("A000NoLock",v) end})
FLR:AddToggle("InfCrucifix",{Text="Endless Crucifix",Default=false,Notify=false,Callback=function(v) Toggle("InfCrucifix",v) end})
FLR:AddToggle("RemoveCutscenes",{Text="Skip Cutscenes",Default=false,Notify=false,Callback=function(v) Toggle("RemoveCutscenes",v) end})
FLR:AddToggle("DisableEntityJumpscares",{Text="Skip Jumpscares",Default=false,Notify=false,Callback=function(v) Toggle("DisableEntityJumpscares",v) end})

WRP:AddButton({Text="Go to Fire Alarm",Callback=function() Funcs.GoTo(function(d) return (d:IsA("Model") or d:IsA("BasePart")) and (d.Name=="StairwellFireAlarm" or tostring(d.Name):lower():find("firealarm",1,true)) end,"Fire Alarm") end})
WRP:AddButton({Text="Go to Emergency Exit",Callback=function() Funcs.GoTo(function(d) return (d:IsA("Model") or d:IsA("BasePart")) and (d.Name=="ExitSignStairwell" or tostring(d.Name):lower():find("exitsign",1,true)) end,"Emergency Exit") end})
WRP:AddButton({Text="Go to Depot",Callback=function() Funcs.GoTo(function(d) return (d:IsA("Model") or d:IsA("BasePart")) and (d.Name=="StairwellScrapper" or tostring(d.Name):lower():find("scrapper",1,true)) end,"Depot") end})
WRP:AddButton({Text="Go to Shopping Cart",Callback=function() Funcs.GoTo(function(d) return d.Name=="ShoppingCart" end,"Shopping Cart",{function() return WS:FindFirstChild("Misc") end}) end})

SIT:AddButton({Text="Collect All Items",Callback=function()
  if not fireproximityprompt then Notify("Collect All","fireproximityprompt not available","action") return end
  task.spawn(function()
    local char,_,root=GetChar(); if not char then return end
    local origin=root.CFrame
    local rooms=Rooms(); if not rooms then return end
    local list={}
    for _,d in ipairs(rooms:GetDescendants()) do if d:IsA("ProximityPrompt") and d.Enabled and d.Parent then local n=(d.Name or ""):lower(); local objn=(d.ObjectText or ""):lower(); if not (n:find("hide",1,true) or n:find("climb",1,true) or n:find("unlock",1,true) or n:find("lock",1,true) or objn:find("ladder",1,true)) then list[#list+1]=d end end end
    for _,pp in ipairs(list) do
      if pp.Parent and pp.Enabled then
        local p=PosOf(pp.Parent); local _,_,r2=GetChar()
        if p and r2 and (p-r2.Position).Magnitude>math.max(pp.MaxActivationDistance-3,3) then SafeTP(CFrame.new(p+Vector3.new(0,3,0)),0.5); task.wait(0.25) end
        for _=1,3 do pcall(fireproximityprompt,pp) task.wait(0.08) end
      end
    end
    SafeTP(origin,0.8)
    Notify("Collect All",#list.." prompts triggered.","action")
  end)
end})
SIT:AddButton({Text="Collect Dropped",Callback=function()
  local drops=WS:FindFirstChild("Drops"); local _,_,root=GetChar(); if not drops or not root then return end
  local n=0
  for _,it in ipairs(drops:GetChildren()) do if it:IsA("Model") then it:PivotTo(root.CFrame); n=n+1 elseif it:IsA("BasePart") then it.CFrame=root.CFrame; n=n+1 end end
  Notify("Collect Dropped",n.." items moved.","action")
end})
SIT:AddToggle("AutoCollect",{Text="Auto Collect",Default=false,Notify=false,Callback=function(v) Toggle("AutoCollect",v) end})
SIT:AddSlider("CollectInterval",{Text="Interval (seconds)",Min=0,Max=60,Default=1,Callback=function(v) S.Ex.CollectInterval=v end})
SIT:AddToggle("AutoScrap",{Text="Auto Scrap",Default=false,Notify=false,Callback=function(v) Toggle("AutoScrap",v) end})
SIT:AddToggle("DropsCounter",{Text="Drops Counter",Default=false,Notify=false,Callback=function(v) S.Ex.DropsCounter=v end})
SIT:AddToggle("OrbitDrops",{Text="Orbit Drops",Default=false,Notify=false,Callback=function(v) Toggle("OrbitDrops",v) end})
SIT:AddSlider("OrbitHeight",{Text="Orbit Height",Min=-20,Max=20,Default=2,Callback=function(v) S.Ex.OrbitHeight=v end})
SIT:AddSlider("OrbitDistance",{Text="Orbit Distance",Min=0,Max=50,Default=5,Callback=function(v) S.Ex.OrbitDistance=v end})
SIT:AddSlider("OrbitSpeed",{Text="Orbit Speed",Min=0,Max=20,Default=2,Callback=function(v) S.Ex.OrbitSpeed=v end})
SIT:AddToggle("TrashLoop",{Text="Go to Trash & Drop",Default=false,Notify=false,Callback=function(v) Toggle("TrashLoop",v) end})

HAZ:AddToggle("NoCrushers",{Text="No Crushers",Default=false,Notify=false,Callback=function(v) Toggle("NoCrushers",v) end})
HAZ:AddToggle("DeleteCrushers",{Text="Delete Crushers",Default=false,Notify=false,Callback=function(v) Toggle("DeleteCrushers",v) end})
HAZ:AddToggle("RemoveMeldWalls",{Text="Remove Meld Walls",Default=false,Notify=false,Callback=function(v) Toggle("RemoveMeldWalls",v) end})
HAZ:AddToggle("StopMeldGrowth",{Text="Stop Meld Growth",Default=false,Notify=false,Callback=function(v) Toggle("StopMeldGrowth",v) end})
HAZ:AddToggle("RemoveMeld",{Text="Remove Meld",Default=false,Notify=false,Callback=function(v) Toggle("RemoveMeld",v) end})
HAZ:AddToggle("NoiseTVOff",{Text="Noise TV Off",Default=false,Notify=false,Callback=function(v) Toggle("NoiseTVOff",v) end})
HAZ:AddButton({Text="Bring Carts",Callback=function()
  local _,_,root=GetChar(); if not root then return end
  local n=0
  local misc=WS:FindFirstChild("Misc")
  if misc then for _,m in ipairs(misc:GetChildren()) do if m.Name=="ShoppingCart" and m:IsA("Model") then m:PivotTo(root.CFrame*CFrame.new(0,0,-6)); n=n+1 end end end
  Notify("Carts",n.." carts moved.","action")
end})
HAZ:AddToggle("CreakGlitch",{Text="Break Creak",Default=false,Notify=false,Callback=function(v) Toggle("CreakGlitch",v) end})
HAZ:AddButton({Text="Open Cubby Doors",Callback=function()
  if not fireproximityprompt then Notify("Cubby Doors","fireproximityprompt not available","action") return end
  task.spawn(function()
    local rooms=Rooms(); if not rooms then return end
    local n=0
    for _,d in ipairs(rooms:GetDescendants()) do
      if d:IsA("ProximityPrompt") and d.Enabled and d.Parent then
        local cur,depth,hit=d.Parent,0,false
        while cur and cur~=WS and depth<6 do if tostring(cur.Name):lower():find("cubby",1,true) then hit=true break end cur,depth=cur.Parent,depth+1 end
        if hit then local at=(d.ActionText or ""):lower(); if not at:find("close",1,true) then pcall(fireproximityprompt,d); n=n+1; task.wait(0.06) end end
      end
    end
    Notify("Cubby Doors",n.." prompts triggered.","action")
  end)
end})

CRK:AddToggle("CreakRageText",{Text="Creak Rage Text",Default=false,Notify=false,Callback=function(v) S.Ex.CreakRageText=v end})
CRK:AddSlider("CreakRageRange",{Text="Creak Rage Range",Min=10,Max=300,Default=60,Callback=function(v) S.Ex.CreakRageRange=v end})

ALR:AddToggle("NotifyMaster",{Text="Master Notifications",Default=true,Notify=false,Callback=function(v) S.Ex.NotifyMaster=v end})
ALR:AddToggle("FeatureAlerts",{Text="Feature Alerts",Default=true,Notify=false,Callback=function(v) S.Ex.FeatureAlerts=v end})
ALR:AddToggle("ActionAlerts",{Text="Action Alerts",Default=true,Notify=false,Callback=function(v) S.Ex.ActionAlerts=v end})
ALR:AddToggle("EntityAlerts",{Text="Entity Alerts",Default=false,Notify=false,Callback=function(v) S.Ex.EntityAlerts=v end})
ALR:AddToggle("DespawnAlerts",{Text="Despawn Alerts",Default=true,Notify=false,Callback=function(v) S.Ex.DespawnAlerts=v end})
ALR:AddSlider("AlertCooldown",{Text="Cooldown (seconds)",Min=0,Max=30,Default=4,Callback=function(v) S.Ex.AlertCooldown=v end})
ALR:AddToggle("NotifyLibraryCode",{Text="Notify Library Code",Default=false,Notify=false,Callback=function(v) S.Ex.NotifyLibraryCode=v end})
ALR:AddToggle("NotifyOxygen",{Text="Notify Oxygen",Default=false,Notify=false,Callback=function(v) S.Ex.NotifyOxygen=v end})
ALR:AddToggle("NotifyHaste",{Text="Notify Haste",Default=false,Notify=false,Callback=function(v) S.Ex.NotifyHaste=v end})

local ESPGui=Instance.new("ScreenGui")
ESPGui.Name="Byte_ESP"
ESPGui.ResetOnSpawn=false
ESPGui.IgnoreGuiInset=true
ESPGui.DisplayOrder=999
local okp=pcall(function() ESPGui.Parent=(gethui and gethui()) or game:GetService("CoreGui") end)
if not okp then ESPGui.Parent=LP:WaitForChild("PlayerGui") end
local ESPHolder=Instance.new("Folder")
ESPHolder.Name="Byte_ESP_H"
ESPHolder.Parent=ESPGui

local function ESPFree(e)
  if e.HL then pcall(e.HL.Destroy,e.HL) end
  if e.BB then pcall(e.BB.Destroy,e.BB) end
  e.HL,e.BB,e.TL=nil,nil,nil
end
local function ESPBuild(inst,label,cat)
  local part=GetPart(inst); if not part then return nil end
  local hl=Instance.new("Highlight")
  hl.Adornee=inst
  hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
  hl.FillColor=NAMES_COL
  hl.OutlineColor=NAMES_COL
  hl.FillTransparency=0.75
  hl.OutlineTransparency=0
  hl.Parent=ESPHolder
  local bb=Instance.new("BillboardGui")
  bb.Adornee=part
  bb.AlwaysOnTop=true
  bb.Size=UDim2.fromOffset(300,80)
  bb.StudsOffset=Vector3.new(0,2,0)
  bb.LightInfluence=0
  bb.ResetOnSpawn=false
  bb.Enabled=false
  bb.Parent=ESPHolder
  local tl=Instance.new("TextLabel")
  tl.BackgroundTransparency=1
  tl.Size=UDim2.fromScale(1,1)
  tl.Font=Enum.Font.GothamBold
  tl.TextSize=20
  tl.TextColor3=NAMES_COL
  tl.TextStrokeTransparency=0.3
  tl.Parent=bb
  return {Inst=inst,Cat=cat,Label=label,Part=part,HL=hl,BB=bb,TL=tl}
end

local RoomCache=setmetatable({},{__mode="k"})
local function RoomModels(room)
  local c=RoomCache[room]
  local t=os.clock()
  if not c or t-c.t>2.5 then
    local list,n={},0
    for _,d in ipairs(room:GetDescendants()) do if d:IsA("Model") then n=n+1; list[n]=d end end
    c={t=t,list=list}; RoomCache[room]=c
  end
  return c.list
end
local function ESPScan()
  if not Esp.Cfg.Enabled then
    for inst,e in pairs(Esp.Tracked) do ESPFree(e); Esp.Tracked[inst]=nil end
    return
  end
  local char,_,root=GetChar(); if not root then return end
  local rp=root.Position
  for inst,e in pairs(Esp.Tracked) do if not inst.Parent then ESPFree(e); Esp.Tracked[inst]=nil end end
  local rooms=Rooms(); if not rooms then return end
  local cur=tonumber(LP:GetAttribute("CurrentRoom")) or 0
  for _,room in ipairs(rooms:GetChildren()) do
    local rn=tonumber(room.Name); if not rn then continue end
    if rn>=cur and rn<=cur+1 then
      for _,d in ipairs(RoomModels(room)) do
        if d.Parent then
          local cat,label
          if d:IsA("Model") then
            local n=d.Name
            if Esp.Cfg.Doors and n=="Door" then cat,label="Doors","Door "..(rn+1) end
            if not cat and Esp.Cfg.Chests and (n=="ChestBox" or n=="ChestBoxLocked") then cat,label="Chests",n=="ChestBoxLocked" and "Locked Chest" or "Chest" end
            if not cat and Esp.Cfg.Drawers and tostring(n):lower():find("drawer",1,true) then cat,label="Drawers","Drawer" end
            if not cat and Esp.Cfg.Wardrobes and (n=="Wardrobe" or n=="Bed" or n=="Locker" or n=="Toolshed") then cat,label="Wardrobes",n end
            if not cat and Esp.Cfg.Entities and IsEntity(n) then cat,label="Entities",n end
            if not cat and Esp.Cfg.Objectives and (n=="LeverForGate" or n=="TimerLever" or n=="LiveHintBook" or n=="LiveBreakerPolePickup" or n=="StairwellFireAlarm" or n=="Sally's Toy" or n=="SallysToy") then cat,label="Objectives",n end
            if not cat and Esp.Cfg.Keys and (n=="KeyObtain" or n=="ElectricalKeyObtain" or n=="FuseObtain") then cat,label="Keys",n end
            if not cat and Esp.Cfg.Gold and n=="GoldPile" then
              local gv=tonumber(d:GetAttribute("GoldValue")) or 0
              if gv>=(S.Ex.MinGoldValue or 0) then cat,label="Gold","Gold ["..gv.."]" end
            end
            if not cat and Esp.Cfg.Stardust and (n=="Stardust" or n=="StardustPickup") then cat,label="Stardust","Stardust" end
            if not cat and Esp.Cfg.Glitch and (n=="GlitchCube" or n=="GlitchFragment") then cat,label="Glitch","Glitch Fragment" end
            if not cat and Esp.Cfg.Lotus and n=="LotusPetal" then cat,label="Lotus","Lotus Petal" end
            if not cat and Esp.Cfg.Scanner and n=="ScannerModule" then cat,label="Scanner","Scanner Module" end
            if not cat and Esp.Cfg.Stairs and (n=="Stairs" or n=="Ladder" or n=="Staircase") then cat,label="Stairs",n end
            if not cat and Esp.Cfg.Exit and n=="ExitSignStairwell" then cat,label="Exit","Emergency Exit" end
            if not cat and Esp.Cfg.Cart and n=="ShoppingCart" then cat,label="Cart","Shopping Cart" end
          end
          if cat and label then
            if not Esp.Tracked[d] then
              local e=ESPBuild(d,label,cat)
              if e then Esp.Tracked[d]=e end
            end
          end
        end
      end
    end
  end
  for _,p in ipairs(Plrs:GetPlayers()) do
    if p~=LP and p.Character and Esp.Cfg.Players and p.Character.Parent then
      if not Esp.Tracked[p.Character] then
        local e=ESPBuild(p.Character,p.DisplayName or p.Name,"Players")
        if e then Esp.Tracked[p.Character]=e end
      end
    end
  end
  for inst,e in pairs(Esp.Tracked) do
    local part=e.Part
    if part and part.Parent then
      local cat=e.Cat
      local enabled=Esp.Cfg[cat]
      local d=(part.Position-rp).Magnitude
      if enabled and d<=400 then
        e.HL.Enabled=true
        if Esp.Cfg.ShowNames then
          e.BB.Enabled=true
          local unit=d*0.28
          local txt=e.Label.."\n["..math.floor(unit+0.5).."m]"; if e.TL.Text~=txt then e.TL.Text=txt end
        else
          e.BB.Enabled=false
        end
      else
        e.HL.Enabled=false
        e.BB.Enabled=false
      end
    end
  end
end

task.spawn(function()
  while true do
    pcall(ESPScan)
    task.wait(0.35)
  end
end)

task.spawn(function()
  while true do
    task.wait(0.5)
    if S.Ex.CreakRageText then
      local _,_,root=GetChar()
      if root then
        local best,bd
        for m in pairs(Stair.Creaks) do if m.Parent then local p=PosOf(m); if p then local d=(p-root.Position).Magnitude; if d<=S.Ex.CreakRageRange and (not bd or d<bd) then best,bd=m,d end end end end
        if best then local pct=best:GetAttribute("Aggression"); if not pct then local i=0; for _,d in ipairs(best:GetDescendants()) do for k,v in pairs(d:GetAttributes()) do local lk=k:lower(); if type(v)=="number" and (lk:find("aggress",1,true) or lk:find("aggro",1,true) or lk:find("rage",1,true)) then pct=v break end end; i=i+1; if pct or i>100 then break end end end; local txt="Rage: "..(pct and (math.floor(pct*100+0.5).."%") or "??%"); if txt~=St.LastCreak then St.LastCreak=txt; Notify("Creak",txt,"feature") end end
      end
    end
  end
end)

task.spawn(function()
  while true do
    task.wait(0.5)
    if S.Ex.DropsCounter then
      local drops=WS:FindFirstChild("Drops")
      local n=0
      if drops then for _,d in ipairs(drops:GetChildren()) do if d:IsA("Model") or d:IsA("BasePart") then n=n+1 end end end
      if n~=St.LastDrops then St.LastDrops=n; pcall(function() Window:Notify({Title="Drops",Content="Items: "..n,Duration=1}) end) end
    end
  end
end)

ThemeManager:SetLibrary(Window)
SaveManager:SetLibrary(Window)
ThemeManager:SetFolder("Byte/Byte")
SaveManager:SetFolder("Byte/Byte")
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)
ThemeManager:LoadDefault()
SaveManager:LoadAutoloadConfig()

Notify("Byte","Script loaded","critical")
