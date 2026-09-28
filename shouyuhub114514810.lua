-- shouyuhub | Steal a Brainrot 完全統合版
-- Part 1: UI基盤 + XOCO防御系

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()

-- サービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local WS = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

-- ============================================================
-- メモリ
-- ============================================================
local Memory = getgenv().shouyuhubMem or {}
getgenv().shouyuhubMem = Memory

-- ============================================================
-- Window作成
-- ============================================================
local Window = Library:CreateWindow({
    Title = "shouyuhub",
    Footer = "Steal a Brainrot 統合",
    Center = true,
    AutoShow = true,
    ShowMobileButtons = false,
})

-- ============================================================
-- タブ
-- ============================================================
local TabDefense   = Window:AddTab({ Name = "防御" })
local TabTarget    = Window:AddTab({ Name = "ターゲット" })
local TabGrab      = Window:AddTab({ Name = "掴み" })
local TabAura      = Window:AddTab({ Name = "オーラ" })
local TabVisual    = Window:AddTab({ Name = "ビジュアル" })
local TabPlayer    = Window:AddTab({ Name = "プレイヤー" })
local TabMisc      = Window:AddTab({ Name = "その他" })
local TabKeybind   = Window:AddTab({ Name = "キーバインド" })

-- ============================================================
-- 共通ヘルパー
-- ============================================================
local function FWD(p, n, t)
    return p:FindFirstChild(n) or p:WaitForChild(n, t or 5)
end

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local BeingHeld = LP:WaitForChild("IsHeld", 10)
local CE = RS:FindFirstChild("CharacterEvents")
local StruggleEvent = CE and CE:FindFirstChild("Struggle")
local RagdollRemote = CE and CE:FindFirstChild("RagdollRemote")
local GCE = RS:FindFirstChild("GameCorrectionEvents")
local StopAllVelocity = GCE and GCE:FindFirstChild("StopAllVelocity")

-- ============================================================
-- XOCO 防御系
-- ============================================================
local DefenseGroup = TabDefense:AddLeftGroupbox("Anti Grab 系")

-- Anti Grab V2
local agConn = nil
local agEnabled = false

local function agStart()
    if agConn then agConn:Disconnect() end
    agConn = BeingHeld:GetPropertyChangedSignal("Value"):Connect(function()
        if not agEnabled or not BeingHeld.Value then return end
        local Char = LP.Character
        if not Char then return end
        local Root = Char:FindFirstChild("HumanoidRootPart")
        local Hum = Char:FindFirstChildOfClass("Humanoid")
        if not Root or not Hum then return end

        -- Collision off
        for _, p in pairs(Char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end

        -- Loop 1: Server defense
        task.spawn(function()
            while agEnabled and BeingHeld.Value do
                pcall(function()
                    if StruggleEvent then StruggleEvent:FireServer() end
                    if RagdollRemote then RagdollRemote:FireServer(Root, 0) end
                    if StopAllVelocity then StopAllVelocity:FireServer() end
                end)
                task.wait()
            end
        end)

        -- Loop 2: Physics state
        task.spawn(function()
            while agEnabled and BeingHeld.Value do
                pcall(function()
                    if Hum then
                        Hum.Sit = false
                        Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                        Hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
                    end
                    if Root then
                        Root.Anchored = true
                        Root.AssemblyLinearVelocity = Vector3.zero
                        Root.AssemblyAngularVelocity = Vector3.zero
                    end
                end)
                task.wait()
            end
            if Root then Root.Anchored = false end
        end)
    end)
    if BeingHeld.Value then
        -- すでに掴まれてる場合は即発動
        local fakeConn = BeingHeld:GetPropertyChangedSignal("Value")
        fakeConn:Disconnect()
    end
end

local function agStop()
    agEnabled = false
    if agConn then agConn:Disconnect(); agConn = nil end
    local c = LP.Character
    local r = c and c:FindFirstChild("HumanoidRootPart")
    if r then r.Anchored = false end
    if c then
        for _, p in pairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

DefenseGroup:AddToggle("AntiGrab", {
    Text = "Anti Grab V2",
    Default = false,
    Callback = function(v)
        agEnabled = v
        Memory.AntiGrab = v
        if v then agStart() else agStop() end
    end,
})

-- ============================================================
-- Anti Void (落ちない)
-- ============================================================
local antiVoidEnabled = false
local avOriginal = WS.FallenPartsDestroyHeight
DefenseGroup:AddToggle("AntiVoid", {
    Text = "Anti Void",
    Default = false,
    Callback = function(v)
        antiVoidEnabled = v
        Memory.AntiVoid = v
        if v then
            avOriginal = WS.FallenPartsDestroyHeight
            WS.FallenPartsDestroyHeight = 0/0
        else
            WS.FallenPartsDestroyHeight = avOriginal
        end
    end,
})

-- ============================================================
-- Auto Reset (Flying警告で自動リセット)
-- ============================================================
local autoResetConn = nil
DefenseGroup:AddToggle("AutoReset", {
    Text = "Auto Reset (Flying検知)",
    Default = false,
    Callback = function(v)
        Memory.AutoReset = v
        if autoResetConn then autoResetConn:Disconnect(); autoResetConn = nil end
        if v and GCE and GCE:FindFirstChild("GameCorrectionsNotify") then
            autoResetConn = GCE.GameCorrectionsNotify.OnClientEvent:Connect(function(r)
                if r == "Flying" then
                    local char = LP.Character
                    if char then
                        char:BreakJoints()
                        local h = char:FindFirstChildOfClass("Humanoid")
                        if h then h.Health = 0 end
                    end
                end
            end)
        end
    end,
})

-- ============================================================
-- Auto Leave (Flying 3回/秒でキック回避のため退出)
-- ============================================================
local autoLeaveConn = nil
DefenseGroup:AddToggle("AutoLeave", {
    Text = "Auto Leave (Flying連続検知)",
    Default = false,
    Callback = function(v)
        Memory.AutoLeave = v
        if autoLeaveConn then autoLeaveConn:Disconnect(); autoLeaveConn = nil end
        if v and GCE and GCE:FindFirstChild("GameCorrectionsNotify") then
            local times = {}
            autoLeaveConn = GCE.GameCorrectionsNotify.OnClientEvent:Connect(function(r)
                if r == "Flying" then
                    local now = os.clock()
                    table.insert(times, now)
                    for i = #times, 1, -1 do
                        if now - times[i] > 1 then table.remove(times, i) end
                    end
                    if #times >= 3 then
                        LP:Kick("shouyuhub: Auto Leave (Flying)")
                    end
                end
            end)
        end
    end,
})

-- ============================================================
-- Anti Explosion
-- ============================================================
local antiExpConn = nil
local antiExpEnabled = false
DefenseGroup:AddToggle("AntiExplosion", {
    Text = "Anti Explosion",
    Default = false,
    Callback = function(v)
        antiExpEnabled = v
        Memory.AntiExplosion = v
        if antiExpConn then antiExpConn:Disconnect(); antiExpConn = nil end
        if v then
            antiExpConn = WS.ChildAdded:Connect(function(model)
                if not antiExpEnabled then return end
                if model.Name == "Part" then
                    local hrp = getHRP()
                    if hrp and (model.Position - hrp.Position).Magnitude <= 20 then
                        hrp.Anchored = true
                        task.wait(0.05)
                        hrp.Anchored = false
                    end
                end
            end)
        end
    end,
})

-- ============================================================
-- Anti Burn
-- ============================================================
local burnConn = nil
DefenseGroup:AddToggle("AntiBurn", {
    Text = "Anti Burn",
    Default = false,
    Callback = function(v)
        Memory.AntiBurn = v
        if burnConn then burnConn:Disconnect(); burnConn = nil end
        if not v then return end
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local fireDebounce = hum:FindFirstChild("FireDebounce")
        if fireDebounce then
            burnConn = fireDebounce.Changed:Connect(function(isBurning)
                if isBurning then
                    local firePart = char:FindFirstChild("FirePlayerPart", true)
                    if firePart then
                        for _, o in ipairs(firePart:GetChildren()) do
                            if o:IsA("Sound") then o:Stop() end
                            if o:IsA("Light") or o:IsA("ParticleEmitter") then o.Enabled = false end
                        end
                        local canBurn = firePart:FindFirstChild("CanBurn")
                        if canBurn then canBurn.Value = false end
                    end
                    fireDebounce.Value = false
                end
            end)
        end
    end,
})

-- ============================================================
-- Anti Sticky
-- ============================================================
DefenseGroup:AddToggle("AntiSticky", {
    Text = "Anti Sticky",
    Default = false,
    Callback = function(v)
        Memory.AntiSticky = v
        local ps = LP:FindFirstChild("PlayerScripts")
        if ps then
            local s = ps:FindFirstChild("StickyPartsTouchDetection")
            if s then s.Disabled = v end
        end
    end,
})

-- ============================================================
-- Anti Ragdoll (常時)
-- ============================================================
local arConn = nil
DefenseGroup:AddToggle("AntiRagdoll", {
    Text = "Anti Ragdoll",
    Default = false,
    Callback = function(v)
        Memory.AntiRagdoll = v
        if arConn then arConn:Disconnect(); arConn = nil end
        if v then
            arConn = RunService.Heartbeat:Connect(function()
                local h = getHum()
                if h and h:GetState() == Enum.HumanoidStateType.Physics then
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
                end
            end)
        end
    end,
})

-- ============================================================
-- Anti Snowball
-- ============================================================
local asbEnabled = false
DefenseGroup:AddToggle("AntiSnowball", {
    Text = "Anti Snowball",
    Default = false,
    Callback = function(v)
        asbEnabled = v
        Memory.AntiSnowball = v
        if v then
            task.spawn(function()
                while asbEnabled do
                    task.wait(0.05)
                    pcall(function()
                        local hrp = getHRP()
                        if hrp and RagdollRemote then
                            RagdollRemote:FireServer(hrp, 0.5)
                        end
                    end)
                end
            end)
        end
    end,
})

-- ============================================================
-- キャラクターリスポーン時の再適用
-- ============================================================
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if agEnabled and BeingHeld and BeingHeld.Value then agStart() end
end)

-- ============================================================
-- 完了通知
-- ============================================================
Library:Notify({
    Title = "shouyuhub",
    Content = "Part 1 読み込み完了（防御系）",
    Duration = 3,
})

-- ============================================================
-- ターゲット管理（全スクリプト共通）
-- ============================================================
local TargetState = {
    Player = nil,
    Name = nil,
}

local function getPlayerList()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            table.insert(list, p.DisplayName .. " (@" .. p.Name .. ")")
        end
    end
    return list
end

local function getPlayerFromString(s)
    if not s or s == "" then return nil end
    local name = s:match("@(.-)%)")
    if name then return Players:FindFirstChild(name) end
    return nil
end

-- ============================================================
-- ターゲットタブ
-- ============================================================
local TargetGroup = TabTarget:AddLeftGroupbox("ターゲット選択")

local TargetDropdown
TargetDropdown = TargetGroup:AddDropdown("TargetDD", {
    Text = "プレイヤーを選択",
    Values = getPlayerList(),
    Default = nil,
    Callback = function(v)
        TargetState.Player = getPlayerFromString(v)
        TargetState.Name = TargetState.Player and TargetState.Player.Name or nil
    end,
})

TargetGroup:AddButton({
    Text = "リスト更新",
    Func = function()
        local newList = getPlayerList()
        -- ObsidianのDropdownはSetValuesで更新
        if TargetDropdown and TargetDropdown.SetValues then
            TargetDropdown:SetValues(newList)
        end
        Library:Notify({ Title = "shouyuhub", Content = "プレイヤーリスト更新", Duration = 2 })
    end,
})

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    if TargetDropdown and TargetDropdown.SetValues then
        TargetDropdown:SetValues(getPlayerList())
    end
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    if TargetDropdown and TargetDropdown.SetValues then
        TargetDropdown:SetValues(getPlayerList())
    end
end)

-- ============================================================
-- 共通ユーティリティ（ターゲット操作用）
-- ============================================================
local GrabEvents = RS:FindFirstChild("GrabEvents")
local SetNetworkOwner = GrabEvents and GrabEvents:FindFirstChild("SetNetworkOwner")
local DestroyGrabLine = GrabEvents and GrabEvents:FindFirstChild("DestroyGrabLine")
local CreateGrabLine = GrabEvents and GrabEvents:FindFirstChild("CreateGrabLine")

local function SetNetOwner(part, cf)
    if SetNetworkOwner and part then
        pcall(function() SetNetworkOwner:FireServer(part, cf or part.CFrame) end)
    end
end

local function Velocity(part, vel)
    if not part or not part.Parent then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e8, 1e8, 1e8)
    bv.Velocity = vel
    bv.Parent = part
    game:GetService("Debris"):AddItem(bv, 0.1)
end

-- ============================================================
-- ターゲット操作グループ
-- ============================================================
local TargetOps = TabTarget:AddRightGroupbox("ターゲット操作")

-- Kill Player
TargetOps:AddButton({
    Text = "選択したプレイヤーを Kill",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then
            Library:Notify({ Title = "shouyuhub", Content = "ターゲット未選択", Duration = 2 })
            return
        end
        local root = t.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local myHRP = getHRP()
        if not myHRP then return end
        local saved = myHRP.CFrame

        myHRP.CFrame = root.CFrame + Vector3.new(0, -6, 0)
        task.wait(0.1)
        for _ = 1, 4 do
            SetNetOwner(root, myHRP.CFrame)
            task.wait(0.05)
        end
        SetNetOwner(root)
        Velocity(root, Vector3.new(0, -1000, 0))
        task.wait(0.3)
        myHRP.CFrame = saved
    end,
})

-- Fling Target
TargetOps:AddButton({
    Text = "選択したプレイヤーを Fling",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        local root = t.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local myHRP = getHRP()
        if not myHRP then return end

        myHRP.CFrame = root.CFrame + Vector3.new(0, -6, 0)
        task.wait(0.1)
        for _ = 1, 4 do
            SetNetOwner(root, myHRP.CFrame)
            task.wait(0.05)
        end
        local dir = (root.Position - myHRP.Position).Unit
        Velocity(root, dir * 5000 + Vector3.new(0, 500, 0))
    end,
})

-- ============================================================
-- Blobman Kick (6秒キック移植)
-- ============================================================
local BlobGroup = TabTarget:AddRightGroupbox("Blobman Kick")

local function getBlobman()
    local inv = WS:FindFirstChild(LP.Name .. "SpawnedInToys")
    if inv then
        local v = inv:FindFirstChild("CreatureBlobman")
        if v and v:FindFirstChild("VehicleSeat") then return v end
    end
    for _, p in ipairs(WS:GetChildren()) do
        if p.Name == "CreatureBlobman" then
            local pv = p:FindFirstChild("PlayerValue")
            if pv and pv.Value == LP.Name and p:FindFirstChild("VehicleSeat") then
                return p
            end
        end
    end
    return nil
end

local function spawnBlobman()
    local hrp = getHRP()
    if not hrp then return nil end
    local menuToys = RS:FindFirstChild("MenuToys")
    local spawnRemote = menuToys and menuToys:FindFirstChild("SpawnToyRemoteFunction")
    if spawnRemote then
        pcall(function()
            spawnRemote:InvokeServer("CreatureBlobman", hrp.CFrame, Vector3.zero)
        end)
    end
    task.wait(1)
    return getBlobman()
end

local function destroyBlobman()
    local b = getBlobman()
    if b then
        local menuToys = RS:FindFirstChild("MenuToys")
        local destroy = menuToys and menuToys:FindFirstChild("DestroyToy")
        if destroy then pcall(function() destroy:FireServer(b) end) end
    end
end

local function blobKick(targetRoot)
    local b = getBlobman()
    if not b then
        b = spawnBlobman()
        if not b then return false end
    end

    local hum = getHum()
    local seat = b:FindFirstChild("VehicleSeat")
    if not hum or not seat then return false end

    if seat.Occupant ~= hum then
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
            task.wait(0.1)
            seat:Sit(hum)
            task.wait(0.5)
        end
    end

    local scriptObj = b:FindFirstChild("BlobmanSeatAndOwnerScript")
    local grabR = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
    local dropR = scriptObj and scriptObj:FindFirstChild("CreatureDrop")
    local lDet = b:FindFirstChild("LeftDetector")
    local lWeld = lDet and (lDet:FindFirstChild("LeftWeld") or lDet:FindFirstChild("RigidConstraint"))
    if not grabR or not dropR or not lDet or not lWeld then return false end

    local myRoot = getHRP()
    if not myRoot then return false end
    local savedPos = myRoot.CFrame
    myRoot.CFrame = targetRoot.CFrame
    task.wait(0.07)

    -- Grab self
    pcall(function() grabR:FireServer(lDet, myRoot, lWeld) end)
    task.wait(0.08)
    SetNetOwner(targetRoot)
    task.wait(0.08)
    targetRoot.CFrame = targetRoot.CFrame + Vector3.new(0, 16, 0)
    task.wait(0.08)
    if DestroyGrabLine then pcall(function() DestroyGrabLine:FireServer(targetRoot) end) end
    task.wait(0.08)
    pcall(function() grabR:FireServer(lDet, targetRoot, lWeld) end)
    task.wait(0.08)
    pcall(function() dropR:FireServer(lDet, targetRoot) end)
    task.wait(0.08)
    if DestroyGrabLine then pcall(function() DestroyGrabLine:FireServer(targetRoot) end) end

    myRoot.CFrame = savedPos
    task.wait(0.2)
    destroyBlobman()
    return true
end

BlobGroup:AddButton({
    Text = "▶ Blobman Kick 実行",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then
            Library:Notify({ Title = "shouyuhub", Content = "ターゲット未選択", Duration = 2 })
            return
        end
        local root = t.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local ok = blobKick(root)
        Library:Notify({
            Title = "shouyuhub",
            Content = ok and ("Kick: " .. t.Name) or "Kick失敗",
            Duration = 3,
        })
    end,
})

-- ============================================================
-- 掴み系
-- ============================================================
local GrabGroup = TabGrab:AddLeftGroupbox("掴み操作")

-- Grab Power
local grabPower = 750
GrabGroup:AddSlider("GrabPower", {
    Text = "掴みパワー",
    Default = 750,
    Min = 1,
    Max = 20000,
    Rounding = 0,
    Callback = function(v) grabPower = v; Memory.GrabPower = v end,
})

-- Strength Grab (掴んで投げる)
local strengthConn = nil
GrabGroup:AddToggle("StrengthGrab", {
    Text = "Strength Grab (掴んで投げる)",
    Default = false,
    Callback = function(v)
        Memory.StrengthGrab = v
        if strengthConn then strengthConn:Disconnect(); strengthConn = nil end
        if v then
            strengthConn = WS.ChildAdded:Connect(function(model)
                if model.Name == "GrabParts" then
                    local gp = model:FindFirstChild("GrabPart")
                    local wc = gp and gp:FindFirstChild("WeldConstraint")
                    local part1 = wc and wc.Part1
                    if part1 then
                        local vel = Instance.new("BodyVelocity", part1)
                        model:GetPropertyChangedSignal("Parent"):Connect(function()
                            if not model.Parent then
                                if UIS:GetLastInputType() == Enum.UserInputType.MouseButton2 then
                                    vel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                                    vel.Velocity = WS.CurrentCamera.CFrame.LookVector * grabPower
                                    game:GetService("Debris"):AddItem(vel, 1)
                                else
                                    vel:Destroy()
                                end
                            end
                        end)
                    end
                end
            end)
        end
    end,
})

-- Kill Grab
local killGrabConn = nil
GrabGroup:AddToggle("KillGrab", {
    Text = "Kill Grab (掴んだ瞬間キル)",
    Default = false,
    Callback = function(v)
        Memory.KillGrab = v
        if killGrabConn then killGrabConn:Disconnect(); killGrabConn = nil end
        if v then
            killGrabConn = WS.ChildAdded:Connect(function(m)
                if m.Name ~= "GrabParts" then return end
                task.wait(0.05)
                local gp = m:FindFirstChild("GrabPart")
                local wc = gp and gp:FindFirstChild("WeldConstraint")
                local p1 = wc and wc.Part1
                if p1 and p1.Parent and p1.Parent ~= LP.Character then
                    local char = p1.Parent
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        pcall(function()
                            hum.Health = 0
                            char:BreakJoints()
                        end)
                    end
                end
            end)
        end
    end,
})

-- Anti Kick Aura (自分の周りのNinja系を除去)
local antiKickAuraEnabled = false
local antiKickAuraConn = nil
GrabGroup:AddToggle("AntiKickAura", {
    Text = "Anti Kick Aura",
    Default = false,
    Callback = function(v)
        antiKickAuraEnabled = v
        Memory.AntiKickAura = v
        if antiKickAuraConn then antiKickAuraConn:Disconnect(); antiKickAuraConn = nil end
        if v then
            antiKickAuraConn = RunService.Heartbeat:Connect(function()
                if not antiKickAuraEnabled then return end
                local myRoot = getHRP()
                if not myRoot then return end
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LP then
                        local inv = WS:FindFirstChild(plr.Name .. "SpawnedInToys")
                        if inv then
                            for _, toyName in ipairs({"NinjaKunai", "NinjaShuriken", "AntiKick"}) do
                                local toy = inv:FindFirstChild(toyName)
                                if toy then
                                    local sp = toy:FindFirstChild("SoundPart")
                                    if sp then
                                        pcall(function() SetNetOwner(sp) end)
                                        if sp:FindFirstChild("PartOwner") and sp.PartOwner.Value == LP.Name then
                                            pcall(function() sp.CFrame = CFrame.new(0, 1000, 0) end)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end,
})

-- ============================================================
-- 完了通知
-- ============================================================
Library:Notify({
    Title = "shouyuhub",
    Content = "Part 2 読み込み完了（ターゲット・掴み）",
    Duration = 3,
})
-- ============================================================
-- オーラ設定
-- ============================================================
local AuraState = {
    Radius = 100,
    Height = 100,
    KillAura = false,
    VoidAura = false,
    RagdollAura = false,
    BlastAura = false,
    SpinAura = false,
    FlingAura = false,
    SlowLegsAura = false,
    IrritateAura = false,
    BlastPower = 5000,
    SpinSpeed = 100,
    FlingPower = 5000,
    SlowLegsSpeed = 5,
    IrritateIntensity = 30,
}

local auraAffected = {}
local auraTimer = 0

-- ============================================================
-- ヘルパー
-- ============================================================
local function GetNearPartsInSphere(origin, radius, height)
    local sphere = Instance.new("Part")
    sphere.Size = Vector3.new(radius * 2, height * 2, radius * 2)
    sphere.Position = origin
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.Transparency = 1
    sphere.Parent = WS
    local parts = WS:GetPartsInPart(sphere)
    sphere:Destroy()
    local result = {}
    for _, part in ipairs(parts) do
        local dist = (part.Position - origin).Magnitude
        local hDiff = math.abs(part.Position.Y - origin.Y)
        if dist <= radius and hDiff <= height / 2 then
            table.insert(result, part)
        end
    end
    return result
end

local function MakeSlowLegs(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = AuraState.SlowLegsSpeed
        auraAffected[char] = true
    end
end

local function IrritatePlayer(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for i = 1, 10 do
        task.spawn(function()
            task.wait(i * 0.05)
            local off = Vector3.new(
                math.random(-AuraState.IrritateIntensity, AuraState.IrritateIntensity),
                math.random(-AuraState.IrritateIntensity/2, AuraState.IrritateIntensity/2),
                math.random(-AuraState.IrritateIntensity, AuraState.IrritateIntensity)
            )
            Velocity(root, off)
        end)
    end
end

-- ============================================================
-- オーラ UI
-- ============================================================
local AuraToggleGroup = TabAura:AddLeftGroupbox("基本オーラ")

AuraToggleGroup:AddToggle("KillAura", {
    Text = "キルオーラ",
    Default = false,
    Callback = function(v) AuraState.KillAura = v; Memory.KillAura = v end,
})
AuraToggleGroup:AddToggle("VoidAura", {
    Text = "奈落オーラ",
    Default = false,
    Callback = function(v) AuraState.VoidAura = v; Memory.VoidAura = v end,
})
AuraToggleGroup:AddToggle("RagdollAura", {
    Text = "ラグドールオーラ",
    Default = false,
    Callback = function(v) AuraState.RagdollAura = v; Memory.RagdollAura = v end,
})
AuraToggleGroup:AddToggle("BlastAura", {
    Text = "ぶっ飛ばしオーラ",
    Default = false,
    Callback = function(v) AuraState.BlastAura = v; Memory.BlastAura = v end,
})
AuraToggleGroup:AddToggle("SpinAura", {
    Text = "回転オーラ",
    Default = false,
    Callback = function(v) AuraState.SpinAura = v; Memory.SpinAura = v end,
})
AuraToggleGroup:AddToggle("FlingAura", {
    Text = "投げ飛ばしオーラ",
    Default = false,
    Callback = function(v) AuraState.FlingAura = v; Memory.FlingAura = v end,
})
AuraToggleGroup:AddToggle("SlowLegsAura", {
    Text = "足遅オーラ",
    Default = false,
    Callback = function(v) AuraState.SlowLegsAura = v; Memory.SlowLegsAura = v end,
})
AuraToggleGroup:AddToggle("IrritateAura", {
    Text = "イライラオーラ",
    Default = false,
    Callback = function(v) AuraState.IrritateAura = v; Memory.IrritateAura = v end,
})

local AuraParamGroup = TabAura:AddRightGroupbox("パラメータ")

AuraParamGroup:AddSlider("AuraRadius", {
    Text = "オーラ半径",
    Default = 100,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(v) AuraState.Radius = v; Memory.AuraRadius = v end,
})
AuraParamGroup:AddSlider("AuraHeight", {
    Text = "オーラ高さ",
    Default = 100,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(v) AuraState.Height = v; Memory.AuraHeight = v end,
})
AuraParamGroup:AddSlider("BlastPower", {
    Text = "吹っ飛ばし威力",
    Default = 5000,
    Min = 1000,
    Max = 20000,
    Rounding = 0,
    Callback = function(v) AuraState.BlastPower = v; Memory.BlastPower = v end,
})
AuraParamGroup:AddSlider("SpinSpeed", {
    Text = "回転速度",
    Default = 100,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(v) AuraState.SpinSpeed = v; Memory.SpinSpeed = v end,
})
AuraParamGroup:AddSlider("FlingPower", {
    Text = "投げ飛ばし威力",
    Default = 5000,
    Min = 1000,
    Max = 20000,
    Rounding = 0,
    Callback = function(v) AuraState.FlingPower = v; Memory.FlingPower = v end,
})
AuraParamGroup:AddSlider("SlowLegsSpeed", {
    Text = "足の遅さ",
    Default = 5,
    Min = 1,
    Max = 16,
    Rounding = 0,
    Callback = function(v) AuraState.SlowLegsSpeed = v; Memory.SlowLegsSpeed = v end,
})
AuraParamGroup:AddSlider("IrritateIntensity", {
    Text = "イライラ強度",
    Default = 30,
    Min = 10,
    Max = 100,
    Rounding = 0,
    Callback = function(v) AuraState.IrritateIntensity = v; Memory.IrritateIntensity = v end,
})

-- ============================================================
-- オーラメインループ
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    auraTimer = auraTimer + dt
    local root = getHRP()
    if not root then return end

    if auraTimer < 0.5 then
        -- 対象プレイヤーへの継続効果
        for char, _ in pairs(auraAffected) do
            if char and char.Parent then
                if AuraState.SlowLegsAura then MakeSlowLegs(char) end
                if AuraState.IrritateAura then IrritatePlayer(char) end
                if AuraState.FlingAura then
                    local r = char:FindFirstChild("HumanoidRootPart")
                    if r then
                        local dir = Vector3.new(
                            math.random(-100, 100),
                            math.random(50, 100),
                            math.random(-100, 100)
                        ).Unit
                        Velocity(r, dir * (AuraState.FlingPower / 2))
                    end
                end
            else
                auraAffected[char] = nil
            end
        end
        return
    end
    auraTimer = 0

    local any = AuraState.KillAura or AuraState.VoidAura or AuraState.RagdollAura
        or AuraState.BlastAura or AuraState.SpinAura or AuraState.FlingAura
        or AuraState.SlowLegsAura or AuraState.IrritateAura
    if not any then return end

    local nearParts = GetNearPartsInSphere(root.Position, AuraState.Radius, AuraState.Height)
    for _, part in ipairs(nearParts) do
        if part.Name == "HumanoidRootPart" and not part:IsDescendantOf(LP.Character) then
            local char = part.Parent
            SetNetOwner(part)
            auraAffected[char] = true

            if AuraState.SlowLegsAura then MakeSlowLegs(char) end
            if AuraState.IrritateAura then IrritatePlayer(char) end

            if AuraState.BlastAura then
                local dir = (part.Position - root.Position).Unit
                Velocity(part, dir * AuraState.BlastPower)
            end
            if AuraState.SpinAura then
                local bav = Instance.new("BodyAngularVelocity")
                bav.MaxTorque = Vector3.new(1e8, 1e8, 1e8)
                bav.AngularVelocity = Vector3.new(0, AuraState.SpinSpeed, 0)
                bav.Parent = part
                game:GetService("Debris"):AddItem(bav, 0.1)
            end
            if AuraState.FlingAura then
                local dir = Vector3.new(
                    math.random(-100, 100),
                    math.random(50, 100),
                    math.random(-100, 100)
                ).Unit
                Velocity(part, dir * AuraState.FlingPower)
            end
            if AuraState.KillAura then
                SetNetOwner(part)
                Velocity(part, Vector3.new(0, -1000, 0))
            end
            if AuraState.VoidAura then
                Velocity(part, Vector3.new(0, 10000, 0))
            end
            if AuraState.RagdollAura and RagdollRemote then
                pcall(function() RagdollRemote:FireServer(part, 2) end)
            end
        end
    end
end)

-- ============================================================
-- 完了通知
-- ============================================================
Library:Notify({
    Title = "shouyuhub",
    Content = "Part 3 読み込み完了（オーラ）",
    Duration = 3,
})

-- ============================================================
-- オーラ共通ユーティリティ
-- ============================================================
local function getNearPartsInSphere(origin, radius, height)
    local sphere = Instance.new("Part")
    sphere.Size = Vector3.new(radius * 2, height * 2, radius * 2)
    sphere.Position = origin
    sphere.Anchored = true
    sphere.CanCollide = false
    sphere.Transparency = 1
    sphere.Parent = WS

    local parts = WS:GetPartsInPart(sphere)
    sphere:Destroy()

    local out = {}
    for _, p in ipairs(parts) do
        local dist = (p.Position - origin).Magnitude
        local hd = math.abs(p.Position.Y - origin.Y)
        if dist <= radius and hd <= height / 2 then
            table.insert(out, p)
        end
    end
    return out
end

local function MoveTo(part, targetCFrame)
    if not part or not part.Parent then return end
    for _, v in ipairs(part.Parent:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = false end
    end
    local b = Instance.new("BodyPosition")
    b.MaxForce = Vector3.new(1e8, 1e8, 1e8)
    b.Position = targetCFrame.Position
    b.P, b.D = 2e4, 5e3
    b.Parent = part
    game:GetService("Debris"):AddItem(b, 1)
end

-- ============================================================
-- オーラ設定
-- ============================================================
local AuraCfg = {
    Radius = 100,
    Height = 100,
    BlastPower = 5000,
    SpinSpeed = 100,
    FlingPower = 3000,
    SlowLegsSpeed = 5,
    IrritateIntensity = 30,
}

local affectedPlayers = {}
local flingMemory = {}
local auraTimer = 0

-- ============================================================
-- オーラ有効フラグ
-- ============================================================
local AuraOn = {
    Kill = false, Void = false, Ragdoll = false,
    Blast = false, Spin = false, Fling = false,
    SlowLegs = false, Irritate = false,
}

-- ============================================================
-- オーラタブ
-- ============================================================
local AuraGroup = TabAura:AddLeftGroupbox("基本オーラ")

AuraGroup:AddToggle("AKill", { Text="キルオーラ", Default=false, Callback=function(v) AuraOn.Kill=v; Memory.AuraKill=v end })
AuraGroup:AddToggle("AVoid", { Text="奈落オーラ", Default=false, Callback=function(v) AuraOn.Void=v; Memory.AuraVoid=v end })
AuraGroup:AddToggle("ARag", { Text="ラグドールオーラ", Default=false, Callback=function(v) AuraOn.Ragdoll=v; Memory.AuraRagdoll=v end })
AuraGroup:AddToggle("ABlast", { Text="吹っ飛ばしオーラ", Default=false, Callback=function(v) AuraOn.Blast=v; Memory.AuraBlast=v end })
AuraGroup:AddToggle("ASpin", { Text="回転オーラ", Default=false, Callback=function(v) AuraOn.Spin=v; Memory.AuraSpin=v end })
AuraGroup:AddToggle("AFling", { Text="投げ飛ばしオーラ", Default=false, Callback=function(v) AuraOn.Fling=v; Memory.AuraFling=v end })
AuraGroup:AddToggle("ASlow", { Text="足遅オーラ", Default=false, Callback=function(v) AuraOn.SlowLegs=v; Memory.AuraSlow=v end })
AuraGroup:AddToggle("AIrr", { Text="イライラオーラ", Default=false, Callback=function(v) AuraOn.Irritate=v; Memory.AuraIrr=v end })

local AuraParam = TabAura:AddRightGroupbox("パラメータ")

AuraParam:AddSlider("ARad", { Text="半径", Default=100, Min=10, Max=500, Rounding=0, Callback=function(v) AuraCfg.Radius=v; Memory.AuraRadius=v end })
AuraParam:AddSlider("AHei", { Text="高さ", Default=100, Min=10, Max=500, Rounding=0, Callback=function(v) AuraCfg.Height=v; Memory.AuraHeight=v end })
AuraParam:AddSlider("ABP", { Text="吹っ飛ばし威力", Default=5000, Min=1000, Max=10000, Rounding=0, Callback=function(v) AuraCfg.BlastPower=v end })
AuraParam:AddSlider("ASP", { Text="回転速度", Default=100, Min=10, Max=500, Rounding=0, Callback=function(v) AuraCfg.SpinSpeed=v end })
AuraParam:AddSlider("AFP", { Text="投げ飛ばし威力", Default=3000, Min=1000, Max=10000, Rounding=0, Callback=function(v) AuraCfg.FlingPower=v end })
AuraParam:AddSlider("ASS", { Text="足の遅さ", Default=5, Min=1, Max=16, Rounding=0, Callback=function(v) AuraCfg.SlowLegsSpeed=v end })
AuraParam:AddSlider("AII", { Text="イライラ強度", Default=30, Min=10, Max=100, Rounding=0, Callback=function(v) AuraCfg.IrritateIntensity=v end })

-- ============================================================
-- サブ機能
-- ============================================================
local function makeSlowLegs(char)
    local h = char:FindFirstChildOfClass("Humanoid")
    if h then h.WalkSpeed = AuraCfg.SlowLegsSpeed end
end

local function irritatePlayer(char)
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for i = 1, 10 do
        task.spawn(function()
            task.wait(i * 0.05)
            local off = Vector3.new(
                math.random(-AuraCfg.IrritateIntensity, AuraCfg.IrritateIntensity),
                math.random(-AuraCfg.IrritateIntensity/2, AuraCfg.IrritateIntensity/2),
                math.random(-AuraCfg.IrritateIntensity, AuraCfg.IrritateIntensity)
            )
            Velocity(root, off)
        end)
    end
end

-- ============================================================
-- オーラ メインループ
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    auraTimer = auraTimer + dt
    local root = getHRP()
    if not root then return end

    if auraTimer >= 0.5 then
        local anyOn = false
        for _, v in pairs(AuraOn) do if v then anyOn = true break end end

        if anyOn then
            local nearParts = getNearPartsInSphere(root.Position, AuraCfg.Radius, AuraCfg.Height)
            for _, p in ipairs(nearParts) do
                if p.Name == "HumanoidRootPart" and not p:IsDescendantOf(LP.Character) then
                    local char = p.Parent
                    SetNetOwner(p)
                    affectedPlayers[char] = true

                    if AuraOn.SlowLegs then makeSlowLegs(char) end
                    if AuraOn.Irritate then irritatePlayer(char) end

                    if AuraOn.Blast then
                        local dir = (p.Position - root.Position).Unit
                        Velocity(p, dir * AuraCfg.BlastPower)
                    end

                    if AuraOn.Spin then
                        local bav = Instance.new("BodyAngularVelocity")
                        bav.MaxTorque = Vector3.new(1e8, 1e8, 1e8)
                        bav.AngularVelocity = Vector3.new(0, AuraCfg.SpinSpeed, 0)
                        bav.Parent = p
                        game:GetService("Debris"):AddItem(bav, 0.1)
                    end

                    if AuraOn.Fling then
                        flingMemory[char] = true
                        local rd = Vector3.new(
                            math.random(-100, 100),
                            math.random(50, 100),
                            math.random(-100, 100)
                        ).Unit
                        Velocity(p, rd * AuraCfg.FlingPower)
                    end

                    if AuraOn.Kill then
                        MoveTo(p, CFrame.new(4096, -75, 4096))
                        Velocity(p, Vector3.new(0, -1000, 0))
                    end

                    if AuraOn.Void then
                        Velocity(p, Vector3.new(0, 10000, 0))
                    end

                    if AuraOn.Ragdoll then
                        local h = char:FindFirstChildOfClass("Humanoid")
                        if h and RagdollRemote then
                            pcall(function() RagdollRemote:FireServer(p, 3) end)
                        end
                    end
                end
            end
        end
        auraTimer = 0
    end

    -- 継続効果
    for char, _ in pairs(affectedPlayers) do
        if char and char.Parent then
            if AuraOn.SlowLegs then makeSlowLegs(char) end
            if AuraOn.Irritate then irritatePlayer(char) end
            if flingMemory[char] and AuraOn.Fling then
                local r = char:FindFirstChild("HumanoidRootPart")
                if r then
                    local rd = Vector3.new(
                        math.random(-100, 100),
                        math.random(50, 100),
                        math.random(-100, 100)
                    ).Unit
                    Velocity(r, rd * AuraCfg.FlingPower / 2)
                end
            end
        else
            affectedPlayers[char] = nil
            flingMemory[char] = nil
        end
    end
end)

-- ============================================================
-- 完了通知
-- ============================================================
Library:Notify({
    Title = "shouyuhub",
    Content = "Part 3 読み込み完了（オーラ系）",
    Duration = 3,
})

-- ============================================================
-- ビジュアル設定
-- ============================================================
local VisualState = {
    Fullbright = false,
    SkyboxEnabled = false,
    CurrentSkybox = "HD",
    Nebula = false,
    HatEnabled = false,
    HatColor = Color3.fromRGB(0, 255, 255),
    HatRainbow = false,
    TrailEnabled = false,
    ForceFieldEnabled = false,
    FFColor = Color3.fromRGB(128, 128, 128),
    TimeFreeze = false,
    TimeValue = 12,
    FOV = 70,
}

local Lighting = game:GetService("Lighting")
local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient = Lighting.Ambient,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
}

local hatParts = {}
local hatConn = nil
local trailParts = {}
local trailConn = nil
local ffConn = nil

local SkyboxAssets = {
    ["HD"] = {Bk="rbxassetid://16553658937", Dn="rbxassetid://16553660713", Ft="rbxassetid://16553662144", Lf="rbxassetid://16553664042", Rt="rbxassetid://16553665766", Up="rbxassetid://16553667750"},
    ["Galaxy"] = {Bk="rbxassetid://15983968922", Dn="rbxassetid://15983966825", Ft="rbxassetid://15983965025", Lf="rbxassetid://15983967420", Rt="rbxassetid://15983966246", Up="rbxassetid://15983964246"},
    ["Space"] = {Bk="rbxassetid://166509999", Dn="rbxassetid://166510057", Ft="rbxassetid://166510116", Lf="rbxassetid://166510092", Rt="rbxassetid://166510131", Up="rbxassetid://166510114"},
    ["Pink"] = {Bk="rbxassetid://12216109205", Dn="rbxassetid://12216109875", Ft="rbxassetid://12216109489", Lf="rbxassetid://12216110170", Rt="rbxassetid://12216110471", Up="rbxassetid://12216108877"},
    ["Sunset"] = {Bk="rbxassetid://600830446", Dn="rbxassetid://600831635", Ft="rbxassetid://600832720", Lf="rbxassetid://600886090", Rt="rbxassetid://600833862", Up="rbxassetid://600835177"},
    ["Snow"] = {Bk="rbxassetid://155657655", Dn="rbxassetid://155674246", Ft="rbxassetid://155657609", Lf="rbxassetid://155657671", Rt="rbxassetid://155657619", Up="rbxassetid://155674931"},
    ["Stormy"] = {Bk="rbxassetid://18703245834", Dn="rbxassetid://18703243349", Ft="rbxassetid://18703240532", Lf="rbxassetid://18703237556", Rt="rbxassetid://18703235430", Up="rbxassetid://18703232671"},
}

-- ============================================================
-- Skybox
-- ============================================================
local function applySkybox(name)
    local s = SkyboxAssets[name]
    if not s then return end
    local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky", Lighting)
    sky.Name = "shouyuhubSky"
    sky.SkyboxBk = s.Bk; sky.SkyboxDn = s.Dn
    sky.SkyboxFt = s.Ft; sky.SkyboxLf = s.Lf
    sky.SkyboxRt = s.Rt; sky.SkyboxUp = s.Up
end

local function removeSkybox()
    local sky = Lighting:FindFirstChild("shouyuhubSky")
    if sky then sky:Destroy() end
end

-- ============================================================
-- Hat
-- ============================================================
local function removeHat()
    for _, h in pairs(hatParts) do pcall(function() h:Destroy() end) end
    hatParts = {}
end

local function addHat()
    local char = LP.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    removeHat()
    local hat = Instance.new("Part")
    hat.Name = "shouyuhubHat"
    hat.Transparency = 0.3
    hat.Color = VisualState.HatColor
    hat.Material = Enum.Material.Neon
    hat.CanCollide = false
    hat.CanTouch = false
    hat.CanQuery = false
    hat.Massless = true
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshId = "rbxassetid://1033714"
    mesh.Scale = Vector3.new(2.4, 1.6, 2.4)
    mesh.Parent = hat
    local w = Instance.new("WeldConstraint")
    w.Part0 = head; w.Part1 = hat; w.Parent = hat
    hat.CFrame = head.CFrame * CFrame.new(0, 1.1, 0)
    hat.Parent = char
    hatParts[#hatParts + 1] = hat
end

-- ============================================================
-- Trail
-- ============================================================
local function removeTrail()
    for _, t in pairs(trailParts) do pcall(function() t:Destroy() end) end
    trailParts = {}
    local char = LP.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local a0 = hrp:FindFirstChild("shouyuhubAtt0"); if a0 then a0:Destroy() end
            local a1 = hrp:FindFirstChild("shouyuhubAtt1"); if a1 then a1:Destroy() end
        end
    end
end

local function addTrail()
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    removeTrail()

    local a0 = Instance.new("Attachment")
    a0.Name = "shouyuhubAtt0"
    a0.Position = Vector3.new(0, 2, 0)
    a0.Parent = hrp

    local a1 = Instance.new("Attachment")
    a1.Name = "shouyuhubAtt1"
    a1.Position = Vector3.new(0, -2, 0)
    a1.Parent = hrp

    local tr = Instance.new("Trail")
    tr.Attachment0 = a0; tr.Attachment1 = a1
    tr.Lifetime = 0.5
    tr.LightEmission = 0.2
    tr.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
    tr.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    tr.Parent = char
    trailParts[#trailParts + 1] = tr
end

-- ============================================================
-- ForceField
-- ============================================================
local origColors = {}
local function applyFF()
    local char = LP.Character
    if not char then return end
    origColors = {}
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "shouyuhubHat" then
            origColors[p] = {Color = p.Color, Material = p.Material}
            p.Color = VisualState.FFColor
            p.Material = Enum.Material.ForceField
        end
    end
end

local function removeFF()
    for p, d in pairs(origColors) do
        if p and p.Parent then
            p.Color = d.Color
            p.Material = d.Material
        end
    end
    origColors = {}
end

-- ============================================================
-- ビジュアルUI
-- ============================================================
local VisGroup = TabVisual:AddLeftGroupbox("基本ビジュアル")

VisGroup:AddToggle("Fullbright", {
    Text = "フルブライト",
    Default = false,
    Callback = function(v)
        VisualState.Fullbright = v; Memory.Fullbright = v
        if v then
            Lighting.Brightness = 3
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        else
            Lighting.Brightness = originalLighting.Brightness
            Lighting.GlobalShadows = originalLighting.GlobalShadows
            Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        end
    end,
})

VisGroup:AddToggle("TimeFreeze", {
    Text = "時間停止",
    Default = false,
    Callback = function(v)
        VisualState.TimeFreeze = v; Memory.TimeFreeze = v
    end,
})

VisGroup:AddSlider("TimeValue", {
    Text = "時間 (0-24)",
    Default = 12,
    Min = 0, Max = 24, Rounding = 0,
    Callback = function(v) VisualState.TimeValue = v end,
})

VisGroup:AddSlider("FOVSlider", {
    Text = "FOV",
    Default = 70,
    Min = 40, Max = 120, Rounding = 0,
    Callback = function(v)
        VisualState.FOV = v
        local cam = WS.CurrentCamera
        if cam then cam.FieldOfView = v end
    end,
})

local VisExtra = TabVisual:AddRightGroupbox("外見")

VisExtra:AddToggle("Hat", {
    Text = "帽子",
    Default = false,
    Callback = function(v)
        VisualState.HatEnabled = v; Memory.Hat = v
        if v then addHat() else removeHat() end
    end,
})

VisExtra:AddToggle("HatRainbow", {
    Text = "帽子レインボー",
    Default = false,
    Callback = function(v) VisualState.HatRainbow = v end,
})

VisExtra:AddToggle("Trail", {
    Text = "トレイル",
    Default = false,
    Callback = function(v)
        VisualState.TrailEnabled = v; Memory.Trail = v
        if v then addTrail() else removeTrail() end
    end,
})

VisExtra:AddToggle("ForceField", {
    Text = "ForceField",
    Default = false,
    Callback = function(v)
        VisualState.ForceFieldEnabled = v; Memory.ForceField = v
        if v then applyFF() else removeFF() end
    end,
})

-- ============================================================
-- スカイボックスUI
-- ============================================================
local SkyGroup = TabVisual:AddRightGroupbox("スカイボックス")

local skyNames = {}
for k in pairs(SkyboxAssets) do table.insert(skyNames, k) end
table.sort(skyNames)

local SkyDropdown
SkyDropdown = SkyGroup:AddDropdown("SkyDD", {
    Text = "スカイボックス選択",
    Values = skyNames,
    Default = "HD",
    Callback = function(v)
        VisualState.CurrentSkybox = v
        if VisualState.SkyboxEnabled then
            applySkybox(v)
        end
    end,
})

SkyGroup:AddToggle("SkyToggle", {
    Text = "スカイボックス適用",
    Default = false,
    Callback = function(v)
        VisualState.SkyboxEnabled = v; Memory.Skybox = v
        if v then
            applySkybox(VisualState.CurrentSkybox)
        else
            removeSkybox()
        end
    end,
})

SkyGroup:AddToggle("Nebula", {
    Text = "星雲エフェクト",
    Default = false,
    Callback = function(v)
        VisualState.Nebula = v; Memory.Nebula = v
        if v then
            local bl = Lighting:FindFirstChild("NebulaBloom") or Instance.new("BloomEffect")
            bl.Name = "NebulaBloom"; bl.Intensity = 0.7; bl.Size = 24; bl.Threshold = 1
            bl.Parent = Lighting
            local cc = Lighting:FindFirstChild("NebulaCC") or Instance.new("ColorCorrectionEffect")
            cc.Name = "NebulaCC"; cc.Saturation = 0.5; cc.Contrast = 0.2
            cc.TintColor = Color3.fromRGB(173, 216, 230)
            cc.Parent = Lighting
            Lighting.Ambient = Color3.fromRGB(173, 216, 230)
            Lighting.OutdoorAmbient = Color3.fromRGB(173, 216, 230)
            Lighting.FogStart = 100; Lighting.FogEnd = 500
        else
            local bl = Lighting:FindFirstChild("NebulaBloom"); if bl then bl:Destroy() end
            local cc = Lighting:FindFirstChild("NebulaCC"); if cc then cc:Destroy() end
            Lighting.Ambient = originalLighting.Ambient
            Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
            Lighting.FogStart = originalLighting.FogStart
            Lighting.FogEnd = originalLighting.FogEnd
        end
    end,
})

-- ============================================================
-- ビジュアルループ
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    -- 帽子レインボー
    if VisualState.HatEnabled and VisualState.HatRainbow then
        local col = Color3.fromHSV((tick() % 5) / 5, 1, 1)
        for _, h in pairs(hatParts) do
            if h and h.Parent then h.Color = col end
        end
    end

    -- ForceField レインボー
    if VisualState.ForceFieldEnabled then
        local col = VisualState.FFColor
        for p, _ in pairs(origColors) do
            if p and p.Parent and p.Material == Enum.Material.ForceField then
                p.Color = col
            end
        end
    end

    -- 時間停止
    if VisualState.TimeFreeze then
        Lighting.ClockTime = VisualState.TimeValue
    end

    -- フルブライト
    if VisualState.Fullbright then
        Lighting.Brightness = 3
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    end
end)

-- ============================================================
-- リスポーン時の再適用
-- ============================================================
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if VisualState.HatEnabled then addHat() end
    if VisualState.TrailEnabled then addTrail() end
    if VisualState.ForceFieldEnabled then applyFF() end
end)

-- ============================================================
-- 完了通知
-- ============================================================
Library:Notify({
    Title = "shouyuhub",
    Content = "Part 4 読み込み完了（ビジュアル系）",
    Duration = 3,
})
-- ============================================================
-- Aki Hub移植: 線香花火 / 羽 / 渦巻き
-- ============================================================
local AkiState = {
    SparklerEnabled = false,
    SparklerName = "Sparkler",
    Pattern = "Circle",
    Radius = 10,
    HeightOffset = 5,
    RotationSpeed = 1000,

    WingEnabled = false,
    WingTarget = "Sparkler",
    WingRadius = 10,
    WingHeight = 5,
    WingSpeed = 1000,
    WingSpread = 10,

    RotationEnabled = false,
    RotationTarget = "Sparkler",
    RotationRadius = 10,
    MinHeight = 2,
    MaxHeight = 8,
    RotationSpeed2 = 90,
    LiftSpeed = 1.5,
    LowerSpeed = 2.0,
}

local geometricList = {}
local geometricConn = nil
local tAccum = 0

local wingList = {}
local wingConn = nil

local rotationList = {}
local rotationConn = nil
local partStates = {}

-- ============================================================
-- 物理アタッチ/デタッチ
-- ============================================================
local function attachPhysics(p)
    if not p or not p.Parent then return nil, nil end
    pcall(function() p:SetNetworkOwner(LP) end)
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Massless = true
    p.AssemblyLinearVelocity = Vector3.zero
    p.AssemblyAngularVelocity = Vector3.zero
    local bp = p:FindFirstChild("BodyPosition") or Instance.new("BodyPosition")
    bp.Name = "BodyPosition"
    bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bp.P = 3e6
    bp.D = 2000
    bp.Position = p.Position
    bp.Parent = p
    local bg = p:FindFirstChild("BodyGyro") or Instance.new("BodyGyro")
    bg.Name = "BodyGyro"
    bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 3e6
    bg.D = 1000
    bg.CFrame = p.CFrame
    bg.Parent = p
    return bp, bg
end

local function detachPhysics(p)
    if not p or not p.Parent then return end
    local bp = p:FindFirstChild("BodyPosition"); if bp then bp:Destroy() end
    local bg = p:FindFirstChild("BodyGyro"); if bg then bg:Destroy() end
    p.CanCollide = true
    p.CanTouch = true
    p.CanQuery = true
    p.Massless = false
    pcall(function() p:SetNetworkOwner(nil) end)
end

-- ============================================================
-- 線香花火 パターン計算
-- ============================================================
local function getPatternTarget(i, n, t)
    local root = getHRP()
    if not root then return Vector3.new(0, 0, 0) end
    local phase = t * (AkiState.RotationSpeed / 100) + (i * 2 * math.pi / n)
    local R = AkiState.Radius
    local x, z, y = 0, 0, AkiState.HeightOffset
    local pat = AkiState.Pattern

    if pat == "Circle" then
        x = R * math.cos(phase)
        z = R * math.sin(phase)
    elseif pat == "Square" then
        local np = phase % (2 * math.pi)
        local side = math.floor(np / (math.pi / 2))
        local prog = (np % (math.pi / 2)) / (math.pi / 2)
        if side == 0 then x = R; z = -R + 2 * R * prog
        elseif side == 1 then x = R - 2 * R * prog; z = R
        elseif side == 2 then x = -R; z = R - 2 * R * prog
        else x = -R + 2 * R * prog; z = -R end
    elseif pat == "Triangle" then
        local np = phase % (2 * math.pi)
        local side = math.floor(np / (2 * math.pi / 3))
        local prog = (np % (2 * math.pi / 3)) / (2 * math.pi / 3)
        local angs = {math.pi/2, math.pi/2 + 2*math.pi/3, math.pi/2 + 4*math.pi/3}
        local x1 = R * math.cos(angs[side+1]); local z1 = R * math.sin(angs[side+1])
        local x2 = R * math.cos(angs[(side+1)%3+1]); local z2 = R * math.sin(angs[(side+1)%3+1])
        x = x1 + (x2-x1)*prog; z = z1 + (z2-z1)*prog
    elseif pat == "Pentagon" then
        local np = phase % (2 * math.pi)
        local side = math.floor(np / (2 * math.pi / 5))
        local prog = (np % (2 * math.pi / 5)) / (2 * math.pi / 5)
        local a1 = (side/5)*2*math.pi - math.pi/2
        local a2 = ((side+1)/5)*2*math.pi - math.pi/2
        local x1 = R*math.cos(a1); local z1 = R*math.sin(a1)
        local x2 = R*math.cos(a2); local z2 = R*math.sin(a2)
        x = x1 + (x2-x1)*prog; z = z1 + (z2-z1)*prog
    elseif pat == "Hexagon" then
        local np = phase % (2 * math.pi)
        local side = math.floor(np / (2 * math.pi / 6))
        local prog = (np % (2 * math.pi / 6)) / (2 * math.pi / 6)
        local a1 = (side/6)*2*math.pi
        local a2 = ((side+1)/6)*2*math.pi
        local x1 = R*math.cos(a1); local z1 = R*math.sin(a1)
        local x2 = R*math.cos(a2); local z2 = R*math.sin(a2)
        x = x1 + (x2-x1)*prog; z = z1 + (z2-z1)*prog
    elseif pat == "Octagon" then
        local np = phase % (2 * math.pi)
        local side = math.floor(np / (2 * math.pi / 8))
        local prog = (np % (2 * math.pi / 8)) / (2 * math.pi / 8)
        local a1 = (side/8)*2*math.pi
        local a2 = ((side+1)/8)*2*math.pi
        local x1 = R*math.cos(a1); local z1 = R*math.sin(a1)
        local x2 = R*math.cos(a2); local z2 = R*math.sin(a2)
        x = x1 + (x2-x1)*prog; z = z1 + (z2-z1)*prog
    elseif pat == "Star" then
        local outerR = R; local innerR = R * 0.5; local pts = 5
        local seg = phase % (2 * math.pi / pts)
        local pt = math.floor(phase / (2 * math.pi / pts))
        local rad = (pt % 2 == 0) and outerR or innerR
        local sa = pt * (2 * math.pi / pts)
        local ea = (pt + 1) * (2 * math.pi / pts)
        local prog = seg / (2 * math.pi / pts)
        x = math.cos(sa + (ea-sa)*prog) * rad
        z = math.sin(sa + (ea-sa)*prog) * rad
    elseif pat == "Heart" then
        local hp = phase * 2
        x = R * 16 * math.pow(math.sin(hp), 3) * 0.1
        z = R * (13*math.cos(hp) - 5*math.cos(2*hp) - 2*math.cos(3*hp) - math.cos(4*hp)) * 0.1
    elseif pat == "Spiral" then
        local sf = 0.5
        x = R * math.cos(phase) * math.exp(-sf * phase)
        z = R * math.sin(phase) * math.exp(-sf * phase)
    elseif pat == "Wave" then
        x = R * math.cos(phase)
        z = R * math.sin(phase * 2)
    elseif pat == "Infinity" then
        local ip = phase * 2
        x = R * math.cos(ip) / (1 + math.pow(math.sin(ip), 2))
        z = R * math.sin(ip) * math.cos(ip) / (1 + math.pow(math.sin(ip), 2))
    elseif pat == "Diamond" then
        local dp = phase % (math.pi / 2)
        local ds = math.floor(phase / (math.pi / 2)) % 4
        if ds == 0 then x = R*math.cos(dp); z = R*math.sin(dp)
        elseif ds == 1 then x = -R*math.sin(dp); z = R*math.cos(dp)
        elseif ds == 2 then x = -R*math.cos(dp); z = -R*math.sin(dp)
        else x = R*math.sin(dp); z = -R*math.cos(dp) end
    elseif pat == "Cross" then
        local cp = phase % (math.pi / 2)
        local cs = math.floor(phase / (math.pi / 2)) % 4
        if cs == 0 then x = R; z = R*math.tan(cp)
        elseif cs == 1 then x = R*math.tan(math.pi/2 - cp); z = R
        elseif cs == 2 then x = -R; z = -R*math.tan(cp)
        else x = -R*math.tan(math.pi/2 - cp); z = -R end
    elseif pat == "Arrow" then
        local ap = phase % (2 * math.pi / 3)
        local as = math.floor(phase / (2 * math.pi / 3)) % 3
        if as == 0 then x = R * (1 - ap / (2*math.pi/3)); z = 0
        elseif as == 1 then
            local a = math.pi/3
            x = R*math.cos(a)*(ap/(2*math.pi/3)); z = R*math.sin(a)*(ap/(2*math.pi/3))
        else
            local a = -math.pi/3
            x = R*math.cos(a)*(ap/(2*math.pi/3)); z = R*math.sin(a)*(ap/(2*math.pi/3))
        end
    elseif pat == "Butterfly" then
        local bp = phase * 2
        local v = math.exp(math.cos(bp)) - 2*math.cos(4*bp) - math.pow(math.sin(bp/12), 5)
        x = R * math.sin(bp) * v * 0.3
        z = R * math.cos(bp) * v * 0.3
    elseif pat == "Flower" then
        local petals = 6
        x = R * (1 + 0.3 * math.cos(petals * phase)) * math.cos(phase)
        z = R * (1 + 0.3 * math.cos(petals * phase)) * math.sin(phase)
    end

    return (root.CFrame * CFrame.new(x, y, z)).p
end

local function rescanGeometric()
    for _, r in ipairs(geometricList) do
        if r.part then detachPhysics(r.part) end
    end
    geometricList = {}
    local current = {}
    for _, d in ipairs(WS:GetDescendants()) do
        if d:IsA("Part") and d.Name:match(AkiState.SparklerName) and not d.Anchored then
            table.insert(current, {model = d.Parent or d, part = d})
        elseif d:IsA("Model") and d.Name:match(AkiState.SparklerName) then
            local p = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
            if p and not p.Anchored then table.insert(current, {model = d, part = p}) end
        end
    end
    for i, t in ipairs(current) do
        local bp, bg = attachPhysics(t.part)
        table.insert(geometricList, {model = t.model, part = t.part, id = i, bp = bp, bg = bg})
    end
end

local function startGeometric()
    if geometricConn then geometricConn:Disconnect() end
    tAccum = 0
    rescanGeometric()
    if #geometricList == 0 then return end
    geometricConn = RunService.Heartbeat:Connect(function(dt)
        local root = getHRP()
        if not root then return end
        tAccum = tAccum + dt
        for j = #geometricList, 1, -1 do
            local rec = geometricList[j]
            if not rec.part or not rec.part.Parent then
                table.remove(geometricList, j)
            else
                rec.part.AssemblyLinearVelocity = Vector3.zero
                rec.part.AssemblyAngularVelocity = Vector3.zero
                rec.bp.Position = getPatternTarget(j, #geometricList, tAccum)
                rec.bg.CFrame = root.CFrame
            end
        end
    end)
end

-- ============================================================
-- 羽モーション
-- ============================================================
local function getWingPosition(i, n, t)
    local root = getHRP()
    if not root then return Vector3.new(0, 0, 0) end
    local flap = t * (AkiState.WingSpeed / 500)
    local half = math.ceil(n / 2)
    local side = (i <= half) and 1 or -1
    local wi = (i <= half) and i or (i - half)
    local prog = wi / half
    local fa = math.sin(flap + prog * math.pi) * AkiState.WingSpread

    local x = side * (AkiState.WingRadius * prog + fa * 0.5)
    local y = AkiState.WingHeight + math.abs(math.sin(flap + prog * math.pi)) * (AkiState.WingSpread * 0.5)
    local z = math.sin(flap * 0.5) * (AkiState.WingRadius * 0.3) + (prog * AkiState.WingRadius * 0.2)
    return (root.CFrame * CFrame.new(x, y, z)).p
end

local function rescanWing()
    for _, r in ipairs(wingList) do
        if r.part then detachPhysics(r.part) end
    end
    wingList = {}
    local current = {}
    for _, d in ipairs(WS:GetDescendants()) do
        if d:IsA("Part") and d.Name:match(AkiState.WingTarget) and not d.Anchored then
            table.insert(current, {model = d.Parent or d, part = d})
        elseif d:IsA("Model") and d.Name:match(AkiState.WingTarget) then
            local p = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
            if p and not p.Anchored then table.insert(current, {model = d, part = p}) end
        end
    end
    for i, t in ipairs(current) do
        local bp, bg = attachPhysics(t.part)
        table.insert(wingList, {model = t.model, part = t.part, id = i, bp = bp, bg = bg})
    end
end

local function startWing()
    if wingConn then wingConn:Disconnect() end
    tAccum = 0
    rescanWing()
    if #wingList == 0 then return end
    wingConn = RunService.Heartbeat:Connect(function(dt)
        local root = getHRP()
        if not root then return end
        tAccum = tAccum + dt
        for j = #wingList, 1, -1 do
            local rec = wingList[j]
            if not rec.part or not rec.part.Parent then
                table.remove(wingList, j)
            else
                rec.bp.Position = getWingPosition(j, #wingList, tAccum)
                rec.bg.CFrame = root.CFrame
            end
        end
    end)
end

-- ============================================================
-- 渦巻き
-- ============================================================
local function rescanRotation()
    for _, r in ipairs(rotationList) do
        if r.part and r.part.Parent then detachPhysics(r.part) end
    end
    rotationList = {}
    partStates = {}
    local current = {}
    for _, d in ipairs(WS:GetDescendants()) do
        if d:IsA("Part") and d.Name:match(AkiState.RotationTarget) and not d.Anchored then
            table.insert(current, {model = d.Parent or d, part = d})
        elseif d:IsA("Model") and d.Name:match(AkiState.RotationTarget) then
            local p = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
            if p and not p.Anchored then table.insert(current, {model = d, part = p}) end
        end
    end
    for i, t in ipairs(current) do
        local bp, bg = attachPhysics(t.part)
        partStates[t.part] = {
            angle = math.rad(math.random(0, 360)),
            height = AkiState.MinHeight + (AkiState.MaxHeight - AkiState.MinHeight) * math.random(),
            isRising = math.random() > 0.5,
            heightOffset = math.random(0.2, 1.0),
        }
        table.insert(rotationList, {model = t.model, part = t.part, id = i, bp = bp, bg = bg, lastPosition = t.part.Position})
    end
end

local function getRotationPos(i, n, t, dt)
    local root = getHRP()
    if not root then return Vector3.new(0, 0, 0) end
    local rec = rotationList[i]
    if not rec or not partStates[rec.part] then return root.Position end
    local st = partStates[rec.part]
    st.angle = st.angle + math.rad(AkiState.RotationSpeed2 * dt)
    if st.angle > math.rad(360) then st.angle = st.angle - math.rad(360) end
    if st.isRising then
        st.height = st.height + AkiState.LiftSpeed * dt * st.heightOffset
        if st.height >= AkiState.MaxHeight then st.height = AkiState.MaxHeight; st.isRising = false end
    else
        st.height = st.height - AkiState.LowerSpeed * dt * st.heightOffset
        if st.height <= AkiState.MinHeight then st.height = AkiState.MinHeight; st.isRising = true end
    end
    local x = math.cos(st.angle) * AkiState.RotationRadius
    local z = math.sin(st.angle) * AkiState.RotationRadius
    return (root.CFrame * CFrame.new(x, st.height, z)).p
end

local function startRotation()
    if rotationConn then rotationConn:Disconnect() end
    rescanRotation()
    if #rotationList == 0 then return end
    rotationConn = RunService.Heartbeat:Connect(function(dt)
        local root = getHRP()
        if not root then return end
        for j = #rotationList, 1, -1 do
            local rec = rotationList[j]
            if not rec.part or not rec.part.Parent then
                partStates[rec.part] = nil
                table.remove(rotationList, j)
            else
                local tp = getRotationPos(j, #rotationList, 0, dt)
                if rec.lastPosition then
                    local sp = rec.lastPosition:Lerp(tp, 0.3)
                    rec.bp.Position = sp
                    rec.lastPosition = sp
                else
                    rec.bp.Position = tp
                    rec.lastPosition = tp
                end
                if partStates[rec.part] then
                    local toCenter = (root.Position - tp).Unit
                    local cf = CFrame.lookAt(tp, tp + toCenter)
                    cf = cf * CFrame.fromEulerAnglesXYZ(
                        math.rad(15 * math.sin(partStates[rec.part].angle)),
                        math.rad(10 * math.cos(partStates[rec.part].angle)),
                        0
                    )
                    rec.bg.CFrame = cf
                end
            end
        end
    end)
end

-- ============================================================
-- UI（その他タブ内）
-- ============================================================
local AkiGroup = TabMisc:AddLeftGroupbox("Aki Hub - 線香花火")

local patternList = {"Circle","Square","Triangle","Pentagon","Hexagon","Octagon","Star","Heart","Spiral","Wave","Infinity","Diamond","Cross","Arrow","Butterfly","Flower"}

AkiGroup:AddInput("SparklerName", {
    Text = "対象名 (部分一致)",
    Default = "Sparkler",
    Finished = true,
    Callback = function(v) AkiState.SparklerName = v ~= "" and v or "Sparkler" end,
})

AkiGroup:AddDropdown("AkiPattern", {
    Text = "パターン",
    Values = patternList,
    Default = "Circle",
    Callback = function(v) AkiState.Pattern = v; tAccum = 0 end,
})

AkiGroup:AddSlider("AkiRadius", {
    Text = "サイズ",
    Default = 10, Min = 2, Max = 150, Rounding = 0,
    Callback = function(v) AkiState.Radius = v end,
})

AkiGroup:AddSlider("AkiHeight", {
    Text = "高さ",
    Default = 5, Min = -100, Max = 100, Rounding = 0,
    Callback = function(v) AkiState.HeightOffset = v end,
})

AkiGroup:AddSlider("AkiRotSpd", {
    Text = "回転速度",
    Default = 1000, Min = 10, Max = 3000, Rounding = 0,
    Callback = function(v) AkiState.RotationSpeed = v end,
})

AkiGroup:AddToggle("AkiSparkler", {
    Text = "線香花火 有効",
    Default = false,
    Callback = function(v)
        AkiState.SparklerEnabled = v; Memory.AkiSparkler = v
        if v then startGeometric()
        else if geometricConn then geometricConn:Disconnect(); geometricConn = nil end end
    end,
})

local AkiWingGroup = TabMisc:AddRightGroupbox("Aki Hub - 羽モーション")

AkiWingGroup:AddInput("WingTarget", {
    Text = "対象名",
    Default = "Sparkler",
    Finished = true,
    Callback = function(v) AkiState.WingTarget = v ~= "" and v or "Sparkler" end,
})

AkiWingGroup:AddSlider("WingRadius", {
    Text = "羽サイズ",
    Default = 10, Min = 2, Max = 50, Rounding = 0,
    Callback = function(v) AkiState.WingRadius = v end,
})

AkiWingGroup:AddSlider("WingSpread", {
    Text = "広がり",
    Default = 10, Min = 1, Max = 30, Rounding = 0,
    Callback = function(v) AkiState.WingSpread = v end,
})

AkiWingGroup:AddSlider("WingHeight", {
    Text = "高さ",
    Default = 5, Min = -50, Max = 50, Rounding = 0,
    Callback = function(v) AkiState.WingHeight = v end,
})

AkiWingGroup:AddSlider("WingSpeed", {
    Text = "羽ばたき速度",
    Default = 1000, Min = 10, Max = 3000, Rounding = 0,
    Callback = function(v) AkiState.WingSpeed = v end,
})

AkiWingGroup:AddToggle("AkiWing", {
    Text = "羽モーション 有効",
    Default = false,
    Callback = function(v)
        AkiState.WingEnabled = v; Memory.AkiWing = v
        if v then startWing()
        else if wingConn then wingConn:Disconnect(); wingConn = nil end end
    end,
})

local AkiRotGroup = TabMisc:AddRightGroupbox("Aki Hub - 渦巻き")

AkiRotGroup:AddInput("RotTarget", {
    Text = "対象名",
    Default = "Sparkler",
    Finished = true,
    Callback = function(v) AkiState.RotationTarget = v ~= "" and v or "Sparkler" end,
})

AkiRotGroup:AddSlider("RotRadius", {
    Text = "回転半径",
    Default = 10, Min = 5, Max = 25, Rounding = 0,
    Callback = function(v) AkiState.RotationRadius = v end,
})

AkiRotGroup:AddSlider("RotMinH", {
    Text = "最低高さ",
    Default = 2, Min = 0, Max = 10, Rounding = 1,
    Callback = function(v) AkiState.MinHeight = v; if AkiState.MaxHeight <= v then AkiState.MaxHeight = v + 1 end end,
})

AkiRotGroup:AddSlider("RotMaxH", {
    Text = "最高高さ",
    Default = 8, Min = 5, Max = 20, Rounding = 1,
    Callback = function(v) AkiState.MaxHeight = v; if AkiState.MinHeight >= v then AkiState.MinHeight = v - 1 end end,
})

AkiRotGroup:AddSlider("RotSpd", {
    Text = "回転速度",
    Default = 90, Min = 30, Max = 300, Rounding = 0,
    Callback = function(v) AkiState.RotationSpeed2 = v end,
})

AkiRotGroup:AddToggle("AkiRotation", {
    Text = "渦巻き 有効",
    Default = false,
    Callback = function(v)
        AkiState.RotationEnabled = v; Memory.AkiRotation = v
        if v then startRotation()
        else if rotationConn then rotationConn:Disconnect(); rotationConn = nil end end
    end,
})

-- ============================================================
-- 完了通知
-- ============================================================
Library:Notify({
    Title = "shouyuhub",
    Content = "Part 5 読み込み完了（Aki Hub系）",
    Duration = 3,
})

-- ============================================================
-- プレイヤー設定
-- ============================================================
local PlayerCfg = {
    SpeedEnabled = false, SpeedValue = 16,
    JumpEnabled = false, JumpValue = 50,
    Noclip = false,
    MaxZoom = 128,
    SuperZoom = false,
}

local PlayerGroup = TabPlayer:AddLeftGroupbox("移動")

PlayerGroup:AddSlider("SpeedVal", {
    Text = "スピード値",
    Default = 16, Min = 16, Max = 200, Rounding = 0,
    Callback = function(v)
        PlayerCfg.SpeedValue = v; Memory.SpeedVal = v
        if PlayerCfg.SpeedEnabled then
            local h = getHum(); if h then h.WalkSpeed = v end
        end
    end,
})

PlayerGroup:AddToggle("SpeedEn", {
    Text = "スピードブースト",
    Default = false,
    Callback = function(v)
        PlayerCfg.SpeedEnabled = v; Memory.SpeedEn = v
        local h = getHum()
        if h then h.WalkSpeed = v and PlayerCfg.SpeedValue or 16 end
    end,
})

PlayerGroup:AddSlider("JumpVal", {
    Text = "ジャンプ力",
    Default = 50, Min = 50, Max = 500, Rounding = 0,
    Callback = function(v)
        PlayerCfg.JumpValue = v; Memory.JumpVal = v
        if PlayerCfg.JumpEnabled then
            local h = getHum(); if h then h.JumpPower = v; h.UseJumpPower = true end
        end
    end,
})

PlayerGroup:AddToggle("JumpEn", {
    Text = "ジャンプブースト",
    Default = false,
    Callback = function(v)
        PlayerCfg.JumpEnabled = v; Memory.JumpEn = v
        local h = getHum()
        if h then
            h.UseJumpPower = true
            h.JumpPower = v and PlayerCfg.JumpValue or 50
        end
    end,
})

PlayerGroup:AddToggle("Noclip", {
    Text = "ノークリップ",
    Default = false,
    Callback = function(v) PlayerCfg.Noclip = v; Memory.Noclip = v end,
})

PlayerGroup:AddButton({
    Text = "キャラクターリセット",
    Func = function()
        local c = LP.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.Health = 0 end
        end
    end,
})

-- ============================================================
-- カメラ
-- ============================================================
local PlayerCam = TabPlayer:AddRightGroupbox("カメラ")

PlayerCam:AddToggle("SuperZoom", {
    Text = "自由視点（超ズームアウト）",
    Default = false,
    Callback = function(v)
        PlayerCfg.SuperZoom = v; Memory.SuperZoom = v
        LP.CameraMaxZoomDistance = v and 50000 or PlayerCfg.MaxZoom
    end,
})

PlayerCam:AddSlider("ZoomDist", {
    Text = "ズーム距離",
    Default = 128, Min = 1, Max = 500, Rounding = 0,
    Callback = function(v)
        PlayerCfg.MaxZoom = v; Memory.ZoomDist = v
        if not PlayerCfg.SuperZoom then LP.CameraMaxZoomDistance = v end
    end,
})

-- ============================================================
-- ノークリップ & ステータスループ
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
    if PlayerCfg.Noclip then
        local c = LP.Character
        if c then
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
            end
        end
    end
    if PlayerCfg.SpeedEnabled then
        local h = getHum()
        if h and h.WalkSpeed ~= PlayerCfg.SpeedValue then h.WalkSpeed = PlayerCfg.SpeedValue end
    end
    if PlayerCfg.JumpEnabled then
        local h = getHum()
        if h then
            h.UseJumpPower = true
            if h.JumpPower ~= PlayerCfg.JumpValue then h.JumpPower = PlayerCfg.JumpValue end
        end
    end
end)

-- キャラクターリスポーン時の再適用
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if PlayerCfg.SpeedEnabled then
        local h = getHum(); if h then h.WalkSpeed = PlayerCfg.SpeedValue end
    end
    if PlayerCfg.JumpEnabled then
        local h = getHum()
        if h then h.UseJumpPower = true; h.JumpPower = PlayerCfg.JumpValue end
    end
end)

-- ============================================================
-- Silent Aim (Aki Hub移植)
-- ============================================================
local SilentAimCfg = { Enabled = false, Range = 30, OldNamecall = nil }

local function getClosestPlayerHead()
    local myRoot = getHRP()
    if not myRoot then return nil end
    local best, bestD = nil, SilentAimCfg.Range
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local h = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if h and hum and hum.Health > 0 then
                local d = (myRoot.Position - h.Position).Magnitude
                if d < bestD then bestD = d; best = h end
            end
        end
    end
    return best
end

local function hookSilentAim()
    if SilentAimCfg.OldNamecall then return end
    SilentAimCfg.OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if SilentAimCfg.Enabled and tostring(method) == "Raycast" and self == WS then
            local target = getClosestPlayerHead()
            if target then
                local origin = args[1] or Vector3.new()
                args[3] = (target.Position - origin).Unit
            end
        end
        return SilentAimCfg.OldNamecall(self, unpack(args))
    end)
end

local SilentGroup = TabPlayer:AddRightGroupbox("Silent Aim")

SilentGroup:AddSlider("SARange", {
    Text = "エイム範囲",
    Default = 30, Min = 5, Max = 100, Rounding = 0,
    Callback = function(v) SilentAimCfg.Range = v end,
})

SilentGroup:AddToggle("SAToggle", {
    Text = "Silent Aim ON/OFF",
    Default = false,
    Callback = function(v)
        SilentAimCfg.Enabled = v
        Memory.SilentAim = v
        if v then
            hookSilentAim()
            Library:Notify({ Title = "shouyuhub", Content = "Silent Aim 有効", Duration = 2 })
        else
            Library:Notify({ Title = "shouyuhub", Content = "Silent Aim 無効", Duration = 2 })
        end
    end,
})

-- ============================================================
-- キーバインド
-- ============================================================
local KeyGroup = TabKeybind:AddLeftGroupbox("アクション")

-- マウスTP
local mouse = LP:GetMouse()
KeyGroup:AddKeybind("MouseTP", {
    Text = "マウス位置へTP",
    Default = "X",
    Callback = function()
        local hrp = getHRP()
        if hrp then
            hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
        end
    end,
})

-- Blobmanに座る
local function sitOnBlobman()
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    if hum.SeatPart then return end

    local nearest, nd = nil, 40
    for _, m in ipairs(WS:GetDescendants()) do
        if m:IsA("Model") and m.Name == "CreatureBlobman" then
            local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
            if r then
                local d = (r.Position - hrp.Position).Magnitude
                if d < nd then nd = d; nearest = m end
            end
        end
    end
    if not nearest then return end

    local seat = nearest:FindFirstChildWhichIsA("Seat", true) or nearest:FindFirstChildWhichIsA("VehicleSeat", true)
    if not seat then return end
    hrp.CFrame = seat.CFrame * CFrame.new(0, 1.2, -1)
    task.wait(0.05)
    pcall(function() seat:Sit(hum) end)
end

KeyGroup:AddKeybind("SitBlob", {
    Text = "最寄りBlobmanに座る",
    Default = "Z",
    Callback = sitOnBlobman,
})

-- Follow & Stare
local followEnabled = false
KeyGroup:AddToggle("FollowStare", {
    Text = "Follow & Stare",
    Default = false,
    Callback = function(v)
        followEnabled = v
        if v then
            task.spawn(function()
                while followEnabled do
                    local plrs = Players:GetPlayers()
                    if #plrs > 0 then
                        local t = plrs[math.random(#plrs)]
                        if t ~= LP and t.Character then
                            local trp = t.Character:FindFirstChild("HumanoidRootPart")
                            local mrp = getHRP()
                            if trp and mrp then
                                mrp.CFrame = CFrame.new(trp.Position + trp.CFrame.LookVector * -2, trp.Position)
                            end
                        end
                    end
                    task.wait(0.3)
                end
            end)
        end
    end,
})

-- Fake Death
KeyGroup:AddToggle("FakeDeath", {
    Text = "Fake Death",
    Default = false,
    Callback = function(v)
        local c = LP.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        if not h then return end
        if v then
            h:ChangeState(Enum.HumanoidStateType.Physics)
            h.PlatformStand = true
        else
            h.PlatformStand = false
            h:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end,
})

-- ============================================================
-- その他タブ - ユーティリティ
-- ============================================================
local UtilGroup = TabMisc:AddLeftGroupbox("ユーティリティ")

UtilGroup:AddToggle("AutoResetFlying", {
    Text = "Auto Reset (Flying)",
    Default = false,
    Callback = function(v)
        Memory.AutoResetFlying = v
    end,
})

UtilGroup:AddButton({
    Text = "キャラリセット",
    Func = function()
        local c = LP.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.Health = 0 end
        end
    end,
})

UtilGroup:AddButton({
    Text = "Fall Height を無効化",
    Func = function()
        WS.FallenPartsDestroyHeight = 0/0
        Library:Notify({ Title = "shouyuhub", Content = "Fall Height 無効化", Duration = 2 })
    end,
})

UtilGroup:AddButton({
    Text = "Fall Height を復元",
    Func = function()
        WS.FallenPartsDestroyHeight = -100
        Library:Notify({ Title = "shouyuhub", Content = "Fall Height 復元", Duration = 2 })
    end,
})

-- ============================================================
-- 設定の保存（メモリ）
-- ============================================================
getgenv().shouyuhubMem = Memory

-- ============================================================
-- 完了通知
-- ============================================================
Library:Notify({
    Title = "shouyuhub",
    Content = "✅ 全機能読み込み完了！",
    Duration = 5,
})

print("========================================")
print("[shouyuhub] Steal a Brainrot 統合版 起動完了")
print("機能:")
print("- 防御系: Anti Grab / Void / Explosion / Burn / Sticky / Ragdoll / Snowball")
print("- ターゲット: Kill / Fling / Blobman Kick")
print("- 掴み: Strength / Kill Grab / Anti Kick Aura")
print("- オーラ: 8種類")
print("- ビジュアル: Fullbright / Skybox / Nebula / Hat / Trail / ForceField")
print("- Aki Hub: 線香花火16形状 / 羽 / 渦巻き")
print("- プレイヤー: Speed / Jump / Noclip / Silent Aim / Camera")
print("- キーバインド: Mouse TP / Sit Blobman / Follow / Fake Death")
print("========================================")
