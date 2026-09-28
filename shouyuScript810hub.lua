-- ====================================================================
-- shouyuhub FTAP ULTRA | 10,000行級 最強統合スクリプト
-- Fling Things and People 専用 | Keyless
-- Part 1: 基盤 + UI + ヘルパー
-- ====================================================================

-- ====================================================================
-- 実行環境チェック
-- ====================================================================
local REQUIRED = {"loadstring", "HttpGet"}
local missing = {}
for _, name in ipairs(REQUIRED) do
    local ok = false
    if name == "loadstring" then ok = type(loadstring) == "function"
    elseif name == "HttpGet" then
        ok = type(game.HttpGet) == "function"
            or type(request) == "function"
            or type(http_request) == "function"
            or (type(syn) == "table" and type(syn.request) == "function")
    end
    if not ok then table.insert(missing, name) end
end
if #missing > 0 then
    warn("[shouyuhub FTAP] 実行環境に必要な関数がありません: " .. table.concat(missing, ", "))
    return
end

-- ====================================================================
-- サービス
-- ====================================================================
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UIS               = game:GetService("UserInputService")
local RS                = game:GetService("ReplicatedStorage")
local WS                = game:GetService("Workspace")
local Lighting          = game:GetService("Lighting")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")
local VU                = game:GetService("VirtualUser")
local Stats             = game:GetService("Stats")
local CG                = game:GetService("CoreGui")

local LP                = Players.LocalPlayer
local CAM               = WS.CurrentCamera

-- ====================================================================
-- RemoteEvent / RemoteFunction 取得
-- ====================================================================
local GrabEvents        = RS:WaitForChild("GrabEvents", 10)
local SetNetworkOwner   = GrabEvents and GrabEvents:FindFirstChild("SetNetworkOwner")
local CreateGrabLine    = GrabEvents and GrabEvents:FindFirstChild("CreateGrabLine")
local DestroyGrabLine   = GrabEvents and GrabEvents:FindFirstChild("DestroyGrabLine")
local ExtendGrabLine    = GrabEvents and GrabEvents:FindFirstChild("ExtendGrabLine")

local MenuToys          = RS:FindFirstChild("MenuToys")
local SpawnToyRemote    = MenuToys and MenuToys:FindFirstChild("SpawnToyRemoteFunction")
local DestroyToyRemote  = MenuToys and MenuToys:FindFirstChild("DestroyToy")

local CharEvents        = RS:FindFirstChild("CharacterEvents")
local RagdollRemote     = CharEvents and CharEvents:FindFirstChild("RagdollRemote")
local StruggleEvent     = CharEvents and CharEvents:FindFirstChild("Struggle")

local PlayerEvents      = RS:FindFirstChild("PlayerEvents")
local StickyPartEvent   = PlayerEvents and PlayerEvents:FindFirstChild("StickyPartEvent")

-- ====================================================================
-- Memory（永続設定）
-- ====================================================================
local M = getgenv().FTAP_Mem
if not M then
    M = {}
    getgenv().FTAP_Mem = M
end

-- ====================================================================
-- UI ライブラリ（Obsidian）
-- ====================================================================
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()
if not Library then
    warn("[shouyuhub FTAP] Obsidian UI の読み込みに失敗")
    return
end

-- ====================================================================
-- Window 作成
-- ====================================================================
local Window = Library:CreateWindow({
    Title = "shouyuhub FTAP",
    Footer = "Ultra Edition",
    Center = true,
    AutoShow = true,
    ShowMobileButtons = false,
})

-- ====================================================================
-- タブ作成
-- ====================================================================
local TabGrab    = Window:AddTab({ Name = "掴み" })
local TabFling   = Window:AddTab({ Name = "飛ばし" })
local TabMove    = Window:AddTab({ Name = "移動" })
local TabCombat  = Window:AddTab({ Name = "戦闘" })
local TabDefense = Window:AddTab({ Name = "防御" })
local TabVisual  = Window:AddTab({ Name = "ビジュアル" })
local TabSpecial = Window:AddTab({ Name = "特殊" })
local TabTarget  = Window:AddTab({ Name = "ターゲット" })
local TabSetting = Window:AddTab({ Name = "設定" })

-- ====================================================================
-- 共通ヘルパー
-- ====================================================================
local function getChar()
    return LP.Character
end

local function getHum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getRoot(plr)
    local c = plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHead(plr)
    local c = plr.Character
    return c and c:FindFirstChild("Head")
end

local function getHumFromChar(char)
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Network Ownership 奪取
local function setNet(part, cf)
    if not SetNetworkOwner or not part then return end
    pcall(function() SetNetworkOwner:FireServer(part, cf or part.CFrame) end)
end

-- 速度付与
local function velocity(part, vel, time)
    if not part or not part.Parent then return end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e8, 1e8, 1e8)
    bv.Velocity = vel
    bv.P = 1e5
    bv.Parent = part
    Debris:AddItem(bv, time or 0.15)
end

-- 位置固定
local function bodyPos(part, pos, force, p, d)
    if not part or not part.Parent then return end
    local bp = Instance.new("BodyPosition")
    bp.MaxForce = Vector3.new(force or 1e8, force or 1e8, force or 1e8)
    bp.Position = pos
    bp.P = p or 3e4
    bp.D = d or 5e3
    bp.Parent = part
    Debris:AddItem(bp, 1)
end

-- 回転
local function angularVel(part, av, time)
    if not part or not part.Parent then return end
    local bav = Instance.new("BodyAngularVelocity")
    bav.MaxTorque = Vector3.new(1e8, 1e8, 1e8)
    bav.AngularVelocity = av
    bav.Parent = part
    Debris:AddItem(bav, time or 0.15)
end

-- 周辺プレイヤー取得
local function getNearbyPlayers(radius)
    local out = {}
    local hrp = getHRP()
    if not hrp then return out end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local r = plr.Character:FindFirstChild("HumanoidRootPart")
            local h = plr.Character:FindFirstChildOfClass("Humanoid")
            if r and h and h.Health > 0 then
                if (r.Position - hrp.Position).Magnitude <= radius then
                    table.insert(out, plr)
                end
            end
        end
    end
    return out
end

-- 円形範囲内の全パーツ取得
local function getNearbyParts(origin, radius, height)
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
        local d = (p.Position - origin).Magnitude
        local hd = math.abs(p.Position.Y - origin.Y)
        if d <= radius and hd <= height / 2 then
            table.insert(out, p)
        end
    end
    return out
end

-- ====================================================================
-- ターゲット管理
-- ====================================================================
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
    if not name then return nil end
    return Players:FindFirstChild(name)
end

-- ====================================================================
-- 統計表示（FPS / Ping）
-- ====================================================================
local StatsGui = Instance.new("ScreenGui")
StatsGui.Name = "shouyuhubFTAPStats"
StatsGui.ResetOnSpawn = false
pcall(function() StatsGui.Parent = (gethui and gethui()) or CG end)
if not StatsGui.Parent then StatsGui.Parent = LP:WaitForChild("PlayerGui") end

local StatsFrame = Instance.new("Frame")
StatsFrame.Size = UDim2.new(0, 160, 0, 50)
StatsFrame.Position = UDim2.new(0, 12, 0, 12)
StatsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
StatsFrame.BackgroundTransparency = 0.3
StatsFrame.BorderSizePixel = 0
StatsFrame.Active = true
StatsFrame.Draggable = true
StatsFrame.Parent = StatsGui

local corner1 = Instance.new("UICorner")
corner1.CornerRadius = UDim.new(0, 8)
corner1.Parent = StatsFrame

local stroke1 = Instance.new("UIStroke")
stroke1.Color = Color3.fromRGB(100, 60, 200)
stroke1.Thickness = 1
stroke1.Parent = StatsFrame

local FpsLabel = Instance.new("TextLabel")
FpsLabel.Size = UDim2.new(1, -10, 0, 20)
FpsLabel.Position = UDim2.new(0, 5, 0, 3)
FpsLabel.BackgroundTransparency = 1
FpsLabel.Font = Enum.Font.Code
FpsLabel.Text = "FPS: --"
FpsLabel.TextColor3 = Color3.fromRGB(0, 255, 127)
FpsLabel.TextSize = 13
FpsLabel.TextXAlignment = Enum.TextXAlignment.Left
FpsLabel.Parent = StatsFrame

local PingLabel = Instance.new("TextLabel")
PingLabel.Size = UDim2.new(1, -10, 0, 20)
PingLabel.Position = UDim2.new(0, 5, 0, 25)
PingLabel.BackgroundTransparency = 1
PingLabel.Font = Enum.Font.Code
PingLabel.Text = "PING: --"
PingLabel.TextColor3 = Color3.fromRGB(255, 200, 0)
PingLabel.TextSize = 13
PingLabel.TextXAlignment = Enum.TextXAlignment.Left
PingLabel.Parent = StatsFrame

local frameCount = 0
local lastUpdate = tick()
local currentFps = 60

RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    local now = tick()
    if now - lastUpdate >= 0.5 then
        currentFps = math.floor(frameCount / (now - lastUpdate))
        FpsLabel.Text = "FPS: " .. currentFps
        FpsLabel.TextColor3 = currentFps >= 50 and Color3.fromRGB(0, 255, 127)
            or currentFps >= 30 and Color3.fromRGB(255, 200, 0)
            or Color3.fromRGB(255, 60, 60)
        pcall(function()
            local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            PingLabel.Text = "PING: " .. ping .. " ms"
        end)
        frameCount = 0
        lastUpdate = now
    end
end)

-- ====================================================================
-- 共通設定（Config）
-- ====================================================================
local Config = {
    -- Grab
    GrabPower = 500,
    GrabRange = 32,
    GrabMode = "Normal",

    -- Fling
    FlingPower = 500,
    FlingRadius = 20,

    -- Movement
    FlySpeed = 50,
    SpeedValue = 16,
    JumpValue = 50,

    -- Combat
    SilentAimRange = 30,
    HitboxSize = 3,
}

M.Config = Config

-- ====================================================================
-- 通知ヘルパー
-- ====================================================================
local function notify(title, content, duration)
    pcall(function()
        Library:Notify({
            Title = title or "shouyuhub",
            Content = content or "",
            Duration = duration or 3,
        })
    end)
end

-- ====================================================================
-- キャラクター再スポーン処理
-- ====================================================================
LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    -- 再適用処理は各パートで追加
end)

-- ====================================================================
-- Part 1 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 1 読み込み完了（基盤）", 3)

print("[shouyuhub FTAP] Part 1 起動完了")

-- ====================================================================
-- 【掴み系 前半】
-- 通常グラブ / スーパーストレングス / スーパースロー / キルグラブ /
-- ポイズングラブ / ファイアグラブ / 放射能グラブ
-- ====================================================================

local GrabGroup = TabGrab:AddLeftGroupbox("グラブ設定")

-- ====================================================================
-- 共通変数
-- ====================================================================
local GrabState = {
    NormalGrab = false,
    SuperStrength = false,
    SuperSlow = false,
    KillGrab = false,
    PoisonGrab = false,
    FireGrab = false,
    RadioactiveGrab = false,
    Power = 500,
    Range = 32,
    SlowValue = 3,
    PoisonDPS = 5,
    FireDuration = 3,
    RadioactiveRadius = 15,
}

-- グラブ状態追跡
local activeGrabs = {}

-- ====================================================================
-- 1. 通常グラブ強化
-- ====================================================================
GrabGroup:AddSlider("GrabPower", {
    Text = "グラブ威力",
    Default = 500,
    Min = 10,
    Max = 10000,
    Rounding = 0,
    Callback = function(v)
        GrabState.Power = v
        M.GrabPower = v
    end,
})

GrabGroup:AddSlider("GrabRange", {
    Text = "グラブ範囲",
    Default = 32,
    Min = 5,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        GrabState.Range = v
        M.GrabRange = v
    end,
})

GrabGroup:AddToggle("NormalGrab", {
    Text = "通常グラブ強化",
    Default = false,
    Callback = function(v)
        GrabState.NormalGrab = v
        M.NormalGrab = v
        notify("shouyuhub", v and "通常グラブ強化 ON" or "通常グラブ強化 OFF", 2)
    end,
})

-- ====================================================================
-- 2. スーパーストレングス
-- ====================================================================
GrabGroup:AddToggle("SuperStrength", {
    Text = "スーパーストレングス",
    Default = false,
    Callback = function(v)
        GrabState.SuperStrength = v
        M.SuperStrength = v
        notify("shouyuhub", v and "スーパーストレングス ON" or "OFF", 2)
    end,
})

-- ====================================================================
-- 3. スーパースロー
-- ====================================================================
GrabGroup:AddToggle("SuperSlow", {
    Text = "スーパースロー",
    Default = false,
    Callback = function(v)
        GrabState.SuperSlow = v
        M.SuperSlow = v
        notify("shouyuhub", v and "スーパースロー ON" or "OFF", 2)
    end,
})

GrabGroup:AddSlider("SlowValue", {
    Text = "スロー速度",
    Default = 3,
    Min = 1,
    Max = 16,
    Rounding = 0,
    Callback = function(v)
        GrabState.SlowValue = v
        M.SlowValue = v
    end,
})

-- ====================================================================
-- 4. キルグラブ
-- ====================================================================
GrabGroup:AddToggle("KillGrab", {
    Text = "キルグラブ",
    Default = false,
    Callback = function(v)
        GrabState.KillGrab = v
        M.KillGrab = v
        notify("shouyuhub", v and "キルグラブ ON" or "OFF", 2)
    end,
})

-- ====================================================================
-- 5. ポイズングラブ
-- ====================================================================
GrabGroup:AddToggle("PoisonGrab", {
    Text = "ポイズングラブ",
    Default = false,
    Callback = function(v)
        GrabState.PoisonGrab = v
        M.PoisonGrab = v
        notify("shouyuhub", v and "ポイズングラブ ON" or "OFF", 2)
    end,
})

GrabGroup:AddSlider("PoisonDPS", {
    Text = "ポイズン威力/秒",
    Default = 5,
    Min = 1,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        GrabState.PoisonDPS = v
        M.PoisonDPS = v
    end,
})

-- ====================================================================
-- 6. ファイアグラブ
-- ====================================================================
GrabGroup:AddToggle("FireGrab", {
    Text = "ファイアグラブ",
    Default = false,
    Callback = function(v)
        GrabState.FireGrab = v
        M.FireGrab = v
        notify("shouyuhub", v and "ファイアグラブ ON" or "OFF", 2)
    end,
})

GrabGroup:AddSlider("FireDuration", {
    Text = "炎上時間",
    Default = 3,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Callback = function(v)
        GrabState.FireDuration = v
        M.FireDuration = v
    end,
})

-- ====================================================================
-- 7. 放射能グラブ
-- ====================================================================
GrabGroup:AddToggle("RadioactiveGrab", {
    Text = "放射能グラブ",
    Default = false,
    Callback = function(v)
        GrabState.RadioactiveGrab = v
        M.RadioactiveGrab = v
        notify("shouyuhub", v and "放射能グラブ ON" or "OFF", 2)
    end,
})

GrabGroup:AddSlider("RadioactiveRadius", {
    Text = "放射能範囲",
    Default = 15,
    Min = 5,
    Max = 50,
    Rounding = 0,
    Callback = function(v)
        GrabState.RadioactiveRadius = v
        M.RadioactiveRadius = v
    end,
})

-- ====================================================================
-- グラブ検出ループ（メイン）
-- ====================================================================
local function applyGrabEffects(char, part)
    if not char or not part then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- キルグラブ
    if GrabState.KillGrab then
        pcall(function() hum.Health = 0 end)
    end

    -- ポイズングラブ（継続ダメージ）
    if GrabState.PoisonGrab and not activeGrabs[char] then
        activeGrabs[char] = "poison"
        task.spawn(function()
            while activeGrabs[char] == "poison" and hum.Parent and hum.Health > 0 do
                pcall(function()
                    hum.Health = math.max(0, hum.Health - GrabState.PoisonDPS)
                end)
                task.wait(1)
            end
            if activeGrabs[char] == "poison" then
                activeGrabs[char] = nil
            end
        end)
    end

    -- ファイアグラブ
    if GrabState.FireGrab then
        pcall(function()
            if not part:FindFirstChild("shouyuFire") then
                local fire = Instance.new("Fire")
                fire.Name = "shouyuFire"
                fire.Size = 5
                fire.Heat = 5
                fire.Color = Color3.fromRGB(255, 100, 0)
                fire.SecondaryColor = Color3.fromRGB(255, 200, 0)
                fire.Parent = part
                Debris:AddItem(fire, GrabState.FireDuration)
            end
        end)
    end

    -- 放射能グラブ（周囲にダメージエリア）
    if GrabState.RadioactiveGrab and not activeGrabs[char] then
        activeGrabs[char] = "radioactive"
        task.spawn(function()
            while activeGrabs[char] == "radioactive" and part.Parent do
                -- 周囲のプレイヤーにダメージ
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character then
                        local pr = p.Character:FindFirstChild("HumanoidRootPart")
                        local ph = p.Character:FindFirstChildOfClass("Humanoid")
                        if pr and ph and ph.Health > 0 then
                            if (pr.Position - part.Position).Magnitude <= GrabState.RadioactiveRadius then
                                pcall(function()
                                    ph.Health = math.max(0, ph.Health - 2)
                                end)
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
            if activeGrabs[char] == "radioactive" then
                activeGrabs[char] = nil
            end
        end)
    end

    -- スーパースロー
    if GrabState.SuperSlow then
        pcall(function()
            hum.WalkSpeed = GrabState.SlowValue
        end)
    end

    -- 通常グラブ強化 / スーパーストレングス
    if GrabState.NormalGrab or GrabState.SuperStrength then
        local power = GrabState.SuperStrength and (GrabState.Power * 10) or GrabState.Power
        velocity(part, Vector3.new(0, power, 0), 0.1)
    end
end

-- メインループ
task.spawn(function()
    while task.wait(0.05) do
        local gp = WS:FindFirstChild("GrabParts")
        if gp then
            local grabPart = gp:FindFirstChild("GrabPart")
            if grabPart then
                local wc = grabPart:FindFirstChild("WeldConstraint")
                if wc and wc.Part1 then
                    local part1 = wc.Part1
                    if part1.Parent and part1.Parent ~= LP.Character then
                        applyGrabEffects(part1.Parent, part1)
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 自分が掴まれている時の処理（アンチグラブ用）
-- ====================================================================
local grabSelfConn = nil

-- ====================================================================
-- Part 2 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 2 読み込み完了（掴み系 前半）", 3)

print("[shouyuhub FTAP] Part 2 起動完了 - 掴み系 7種")

-- ====================================================================
-- 【掴み系 後半】
-- アンチグラブ / オブジェクトグラブ / 複数同時グラブ / グラブレンジ拡張
-- ====================================================================

local GrabGroup2 = TabGrab:AddRightGroupbox("応用グラブ")

-- ====================================================================
-- 状態変数
-- ====================================================================
local GrabState2 = {
    AntiGrab = false,
    ObjectGrabRange = 50,
    MultiGrab = false,
    MultiGrabCount = 3,
    GrabRangeExtend = false,
    ExtendedRange = 100,
    HighlightGrabbable = false,
}

local grabbableHighlights = {}

-- ====================================================================
-- 1. アンチグラブ（自分が掴まれたら脱出）
-- ====================================================================
GrabGroup2:AddToggle("AntiGrab", {
    Text = "アンチグラブ",
    Default = false,
    Callback = function(v)
        GrabState2.AntiGrab = v
        M.AntiGrab = v
        notify("shouyuhub", v and "アンチグラブ ON" or "OFF", 2)
    end,
})

-- アンチグラブループ
task.spawn(function()
    while task.wait(0.1) do
        if GrabState2.AntiGrab then
            local hrp = getHRP()
            local hum = getHum()
            if hrp and hum then
                -- 掴まれているかチェック
                local isHeld = LP:FindFirstChild("IsHeld")
                local held = isHeld and isHeld.Value or false

                -- Struggle 発動
                pcall(function()
                    if StruggleEvent then StruggleEvent:FireServer() end
                end)

                -- ラグドール解除
                pcall(function()
                    if RagdollRemote then RagdollRemote:FireServer(hrp, 0) end
                end)

                -- 座り状態を解除
                if hum.Sit then
                    pcall(function()
                        hum.Sit = false
                        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    end)
                end

                -- 掴まれている間はアンカーで位置固定
                if held then
                    hrp.Anchored = true
                    task.wait(0.05)
                    hrp.Anchored = false
                end
            end
        end
    end
end)

-- ====================================================================
-- 2. オブジェクトグラブ（遠距離から引き寄せ）
-- ====================================================================
GrabGroup2:AddToggle("ObjectGrab", {
    Text = "オブジェクトグラブ（遠距離引き寄せ）",
    Default = false,
    Callback = function(v)
        GrabState2.ObjectGrab = v
        M.ObjectGrab = v
        notify("shouyuhub", v and "オブジェクトグラブ ON" or "OFF", 2)
    end,
})

GrabGroup2:AddSlider("ObjGrabRange", {
    Text = "引き寄せ範囲",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(v)
        GrabState2.ObjectGrabRange = v
        M.ObjGrabRange = v
    end,
})

-- オブジェクトグラブ ループ
local objGrabConn = nil
task.spawn(function()
    while task.wait(0.1) do
        if GrabState2.ObjectGrab then
            local gp = WS:FindFirstChild("GrabParts")
            if gp then
                local grabPart = gp:FindFirstChild("GrabPart")
                if grabPart then
                    local hrp = getHRP()
                    if hrp then
                        local dist = (grabPart.Position - hrp.Position).Magnitude
                        if dist > 5 and dist <= GrabState2.ObjectGrabRange then
                            setNet(grabPart, hrp.CFrame)
                            bodyPos(grabPart, hrp.Position + hrp.CFrame.LookVector * 5, 1e8)
                        end
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 3. 複数同時グラブ
-- ====================================================================
GrabGroup2:AddToggle("MultiGrab", {
    Text = "複数同時グラブ",
    Default = false,
    Callback = function(v)
        GrabState2.MultiGrab = v
        M.MultiGrab = v
        notify("shouyuhub", v and "複数同時グラブ ON" or "OFF", 2)
    end,
})

GrabGroup2:AddSlider("MultiGrabCount", {
    Text = "最大同時数",
    Default = 3,
    Min = 2,
    Max = 10,
    Rounding = 0,
    Callback = function(v)
        GrabState2.MultiGrabCount = v
        M.MultiGrabCount = v
    end,
})

-- ====================================================================
-- 4. グラブレンジ拡張
-- ====================================================================
GrabGroup2:AddToggle("GrabRangeExtend", {
    Text = "グラブレンジ拡張",
    Default = false,
    Callback = function(v)
        GrabState2.GrabRangeExtend = v
        M.GrabRangeExtend = v
        notify("shouyuhub", v and "グラブレンジ拡張 ON" or "OFF", 2)
    end,
})

GrabGroup2:AddSlider("ExtendedRange", {
    Text = "拡張レンジ",
    Default = 100,
    Min = 20,
    Max = 500,
    Rounding = 0,
    Callback = function(v)
        GrabState2.ExtendedRange = v
        M.ExtendedRange = v
    end,
})

-- レンジ拡張の適用（PCのMouse.Targetを利用）
local mouse = LP:GetMouse()
local rangeExtendConn = nil
task.spawn(function()
    while task.wait(0.1) do
        if GrabState2.GrabRangeExtend then
            if not rangeExtendConn then
                rangeExtendConn = RunService.RenderStepped:Connect(function()
                    if not GrabState2.GrabRangeExtend then return end
                    -- カメラから前方にレイを飛ばして遠くのオブジェクトを検出
                    local origin = CAM.CFrame.Position
                    local dir = CAM.CFrame.LookVector * GrabState2.ExtendedRange
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    params.FilterDescendantsInstances = {LP.Character}
                    local result = WS:Raycast(origin, dir, params)
                    if result and result.Instance then
                        -- マウスターゲットを上書き（グラブ可能なら）
                        pcall(function()
                            mouse.TargetFilter = LP.Character
                        end)
                    end
                end)
            end
        else
            if rangeExtendConn then
                rangeExtendConn:Disconnect()
                rangeExtendConn = nil
            end
        end
    end
end)

-- ====================================================================
-- 5. 掴めるオブジェクトをハイライト
-- ====================================================================
GrabGroup2:AddToggle("HighlightGrabbable", {
    Text = "掴めるオブジェクトをハイライト",
    Default = false,
    Callback = function(v)
        GrabState2.HighlightGrabbable = v
        M.HighlightGrabbable = v
        notify("shouyuhub", v and "ハイライト ON" or "OFF", 2)
    end,
})

-- ハイライトループ
task.spawn(function()
    while task.wait(1) do
        if GrabState2.HighlightGrabbable then
            for _, obj in ipairs(WS:GetDescendants()) do
                if obj:IsA("BasePart") then
                    -- Grabbable属性 or 特定の名前を持つオブジェクト
                    local isGrabbable = obj:GetAttribute("Grabbable")
                    if isGrabbable == nil then
                        isGrabbable = obj:GetAttribute("IsGrabbable")
                    end
                    if isGrabbable == true and not grabbableHighlights[obj] then
                        local hl = Instance.new("Highlight")
                        hl.Name = "shouyuGrabbable"
                        hl.FillColor = Color3.fromRGB(0, 255, 200)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.5
                        hl.OutlineTransparency = 0
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Adornee = obj
                        hl.Parent = obj
                        grabbableHighlights[obj] = hl
                    end
                end
            end
        else
            for obj, hl in pairs(grabbableHighlights) do
                pcall(function() hl:Destroy() end)
                grabbableHighlights[obj] = nil
            end
            grabbableHighlights = {}
        end
    end
end)

-- ====================================================================
-- 掴み統計表示
-- ====================================================================
local GrabStats = TabGrab:AddLeftGroupbox("統計")

local GrabCountLabel = GrabStats:AddParagraph({
    Title = "現在のグラブ数",
    Content = "0",
})

local grabCountText = "0"

task.spawn(function()
    while task.wait(0.5) do
        local count = 0
        local gp = WS:FindFirstChild("GrabParts")
        if gp then
            count = #gp:GetChildren()
        end
        if grabCountText ~= tostring(count) then
            grabCountText = tostring(count)
            pcall(function()
                if GrabCountLabel and GrabCountLabel.SetDesc then
                    GrabCountLabel:SetDesc(grabCountText)
                end
            end)
        end
    end
end)

-- ====================================================================
-- グラブアクション ボタン
-- ====================================================================
local GrabActionGroup = TabGrab:AddRightGroupbox("アクション")

GrabActionGroup:AddButton({
    Text = "▶ 掴んでいるオブジェクトを射出",
    Func = function()
        local gp = WS:FindFirstChild("GrabParts")
        if not gp then
            notify("shouyuhub", "掴んでいません", 2)
            return
        end
        local grabPart = gp:FindFirstChild("GrabPart")
        if not grabPart then return end
        local wc = grabPart:FindFirstChild("WeldConstraint")
        if not wc then return end
        local part1 = wc.Part1
        if not part1 then return end
        setNet(part1)
        task.wait(0.05)
        velocity(part1, CAM.CFrame.LookVector * GrabState.Power)
        notify("shouyuhub", "射出完了", 2)
    end,
})

GrabActionGroup:AddButton({
    Text = "▶ 掴んでいるオブジェクトを上空へ",
    Func = function()
        local gp = WS:FindFirstChild("GrabParts")
        if not gp then return end
        local grabPart = gp:FindFirstChild("GrabPart")
        if not grabPart then return end
        local wc = grabPart:FindFirstChild("WeldConstraint")
        if not wc then return end
        local part1 = wc.Part1
        if not part1 then return end
        setNet(part1)
        task.wait(0.05)
        velocity(part1, Vector3.new(0, 10000, 0))
        notify("shouyuhub", "上空へ射出", 2)
    end,
})

GrabActionGroup:AddButton({
    Text = "▶ 掴んでいるオブジェクトを奈落へ",
    Func = function()
        local gp = WS:FindFirstChild("GrabParts")
        if not gp then return end
        local grabPart = gp:FindFirstChild("GrabPart")
        if not grabPart then return end
        local wc = grabPart:FindFirstChild("WeldConstraint")
        if not wc then return end
        local part1 = wc.Part1
        if not part1 then return end
        setNet(part1)
        task.wait(0.05)
        velocity(part1, Vector3.new(0, -10000, 0))
        notify("shouyuhub", "奈落へ射出", 2)
    end,
})

GrabActionGroup:AddButton({
    Text = "▶ 掴んでいるオブジェクトを回転射出",
    Func = function()
        local gp = WS:FindFirstChild("GrabParts")
        if not gp then return end
        local grabPart = gp:FindFirstChild("GrabPart")
        if not grabPart then return end
        local wc = grabPart:FindFirstChild("WeldConstraint")
        if not wc then return end
        local part1 = wc.Part1
        if not part1 then return end
        setNet(part1)
        task.wait(0.05)
        angularVel(part1, Vector3.new(0, 500, 0), 1)
        velocity(part1, Vector3.new(0, 500, 0), 1)
        notify("shouyuhub", "回転射出", 2)
    end,
})

-- ====================================================================
-- Part 3 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 3 読み込み完了（掴み系 後半）", 3)

print("[shouyuhub FTAP] Part 3 起動完了 - 掴み系 応用")

-- ====================================================================
-- 【飛ばし系】
-- ドロップフリング / スピンフリング / ウォークフリング /
-- オーラフリング / 全員フリング / カスタム威力
-- ====================================================================

local FlingGroup = TabFling:AddLeftGroupbox("フリング設定")

-- ====================================================================
-- 状態変数
-- ====================================================================
local FlingState = {
    DropFling = false,
    SpinFling = false,
    WalkFling = false,
    AuraFling = false,
    AutoFlingAll = false,
    Power = 500,
    Radius = 20,
    SpinSpeed = 500,
    WalkPower = 300,
    DropHeight = 50,
    Interval = 0.5,
}

-- ====================================================================
-- 威力スライダー
-- ====================================================================
FlingGroup:AddSlider("FlingPower", {
    Text = "フリング威力",
    Default = 500,
    Min = 10,
    Max = 10000,
    Rounding = 0,
    Callback = function(v)
        FlingState.Power = v
        M.FlingPower = v
    end,
})

FlingGroup:AddSlider("FlingRadius", {
    Text = "フリング半径",
    Default = 20,
    Min = 5,
    Max = 100,
    Rounding = 0,
    Callback = function(v)
        FlingState.Radius = v
        M.FlingRadius = v
    end,
})

-- ====================================================================
-- 共通フリング関数
-- ====================================================================
local function flingPlayer(plr, power, mode)
    if not plr or plr == LP then return end
    local root = getRoot(plr)
    if not root then return end

    setNet(root)
    task.wait(0.03)

    if mode == "up" then
        velocity(root, Vector3.new(0, power, 0), 0.2)
    elseif mode == "down" then
        velocity(root, Vector3.new(0, -power, 0), 0.2)
    elseif mode == "forward" then
        velocity(root, CAM.CFrame.LookVector * power, 0.2)
    elseif mode == "spin" then
        angularVel(root, Vector3.new(0, FlingState.SpinSpeed, 0), 1)
        velocity(root, Vector3.new(0, power, 0), 1)
    else
        -- ランダム方向
        local dir = Vector3.new(
            math.random(-100, 100),
            math.random(50, 100),
            math.random(-100, 100)
        ).Unit
        velocity(root, dir * power, 0.2)
    end
end

-- ====================================================================
-- 1. ドロップフリング（持ち上げて急降下）
-- ====================================================================
FlingGroup:AddToggle("DropFling", {
    Text = "ドロップフリング",
    Default = false,
    Callback = function(v)
        FlingState.DropFling = v
        M.DropFling = v
        notify("shouyuhub", v and "ドロップフリング ON" or "OFF", 2)
    end,
})

FlingGroup:AddSlider("DropHeight", {
    Text = "持ち上げ高さ",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(v)
        FlingState.DropHeight = v
        M.DropHeight = v
    end,
})

-- ドロップフリング ループ
task.spawn(function()
    while task.wait(0.1) do
        if FlingState.DropFling then
            -- 掴んでいる相手を持ち上げる
            local gp = WS:FindFirstChild("GrabParts")
            if gp then
                local grabPart = gp:FindFirstChild("GrabPart")
                if grabPart then
                    local wc = grabPart:FindFirstChild("WeldConstraint")
                    if wc and wc.Part1 then
                        local part1 = wc.Part1
                        if part1.Parent then
                            local char = part1.Parent
                            local hum = char:FindFirstChildOfClass("Humanoid")
                            local root = char:FindFirstChild("HumanoidRootPart")
                            if hum and root then
                                setNet(root)
                                bodyPos(root, root.Position + Vector3.new(0, FlingState.DropHeight, 0), 1e8)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 2. スピンフリング
-- ====================================================================
FlingGroup:AddToggle("SpinFling", {
    Text = "スピンフリング",
    Default = false,
    Callback = function(v)
        FlingState.SpinFling = v
        M.SpinFling = v
        notify("shouyuhub", v and "スピンフリング ON" or "OFF", 2)
    end,
})

FlingGroup:AddSlider("SpinSpeed", {
    Text = "回転速度",
    Default = 500,
    Min = 50,
    Max = 5000,
    Rounding = 0,
    Callback = function(v)
        FlingState.SpinSpeed = v
        M.SpinSpeed = v
    end,
})

-- スピンフリング ループ
task.spawn(function()
    while task.wait(0.1) do
        if FlingState.SpinFling then
            local gp = WS:FindFirstChild("GrabParts")
            if gp then
                local grabPart = gp:FindFirstChild("GrabPart")
                if grabPart then
                    local wc = grabPart:FindFirstChild("WeldConstraint")
                    if wc and wc.Part1 then
                        local part1 = wc.Part1
                        if part1.Parent then
                            local root = part1.Parent:FindFirstChild("HumanoidRootPart")
                            if root then
                                setNet(root)
                                angularVel(root, Vector3.new(0, FlingState.SpinSpeed, 0), 0.5)
                                velocity(root, Vector3.new(0, FlingState.Power, 0), 0.5)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 3. ウォークフリング（触れた相手を弾く）
-- ====================================================================
FlingGroup:AddToggle("WalkFling", {
    Text = "ウォークフリング",
    Default = false,
    Callback = function(v)
        FlingState.WalkFling = v
        M.WalkFling = v
        notify("shouyuhub", v and "ウォークフリング ON" or "OFF", 2)
    end,
})

FlingGroup:AddSlider("WalkPower", {
    Text = "触れた時の威力",
    Default = 300,
    Min = 50,
    Max = 5000,
    Rounding = 0,
    Callback = function(v)
        FlingState.WalkPower = v
        M.WalkPower = v
    end,
})

-- ウォークフリング ループ
task.spawn(function()
    while task.wait(0.1) do
        if FlingState.WalkFling then
            local hrp = getHRP()
            if hrp then
                local nearby = getNearbyPlayers(5)
                for _, plr in ipairs(nearby) do
                    flingPlayer(plr, FlingState.WalkPower, "random")
                end
            end
        end
    end
end)

-- ====================================================================
-- 4. オーラフリング
-- ====================================================================
FlingGroup:AddToggle("AuraFling", {
    Text = "オーラフリング",
    Default = false,
    Callback = function(v)
        FlingState.AuraFling = v
        M.AuraFling = v
        notify("shouyuhub", v and "オーラフリング ON" or "OFF", 2)
    end,
})

-- オーラフリング ループ
task.spawn(function()
    while task.wait(0.3) do
        if FlingState.AuraFling then
            local nearby = getNearbyPlayers(FlingState.Radius)
            for _, plr in ipairs(nearby) do
                flingPlayer(plr, FlingState.Power, "random")
            end
        end
    end
end)

-- ====================================================================
-- 5. 全員フリング（ワンショット）
-- ====================================================================
FlingGroup:AddButton({
    Text = "▶ 全員フリング（1回）",
    Func = function()
        local count = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                flingPlayer(plr, FlingState.Power, "random")
                count = count + 1
            end
        end
        notify("shouyuhub", count .. " 人をフリング", 3)
    end,
})

-- 全員フリング ループ
FlingGroup:AddToggle("AutoFlingAll", {
    Text = "全員フリング（自動）",
    Default = false,
    Callback = function(v)
        FlingState.AutoFlingAll = v
        M.AutoFlingAll = v
        notify("shouyuhub", v and "全員フリング自動 ON" or "OFF", 2)
    end,
})

FlingGroup:AddSlider("FlingInterval", {
    Text = "フリング間隔（秒）",
    Default = 0.5,
    Min = 0.1,
    Max = 5,
    Rounding = 1,
    Callback = function(v)
        FlingState.Interval = v
        M.FlingInterval = v
    end,
})

-- 全員フリング ループ
task.spawn(function()
    while task.wait(FlingState.Interval) do
        if FlingState.AutoFlingAll then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and plr.Character then
                    flingPlayer(plr, FlingState.Power, "random")
                end
            end
        end
    end
end)

-- ====================================================================
-- 選択したターゲットをフリング（右側）
-- ====================================================================
local FlingTargetGroup = TabFling:AddRightGroupbox("ターゲットフリング")

FlingTargetGroup:AddButton({
    Text = "▶ 選択ターゲットを上空へ",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then
            notify("shouyuhub", "ターゲット未選択", 2)
            return
        end
        flingPlayer(t, FlingState.Power, "up")
        notify("shouyuhub", t.Name .. " を上空へ", 2)
    end,
})

FlingTargetGroup:AddButton({
    Text = "▶ 選択ターゲットを奈落へ",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        flingPlayer(t, FlingState.Power, "down")
        notify("shouyuhub", t.Name .. " を奈落へ", 2)
    end,
})

FlingTargetGroup:AddButton({
    Text = "▶ 選択ターゲットを前方へ",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        flingPlayer(t, FlingState.Power, "forward")
        notify("shouyuhub", t.Name .. " を前方へ", 2)
    end,
})

FlingTargetGroup:AddButton({
    Text = "▶ 選択ターゲットをスピン",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        flingPlayer(t, FlingState.Power, "spin")
        notify("shouyuhub", t.Name .. " をスピン", 2)
    end,
})

-- ====================================================================
-- 連続フリング（ボタンを押している間）
-- ====================================================================
local continuousFlingActive = false

FlingTargetGroup:AddToggle("ContinuousFling", {
    Text = "選択ターゲットを連続フリング",
    Default = false,
    Callback = function(v)
        continuousFlingActive = v
        if v then
            task.spawn(function()
                while continuousFlingActive do
                    local t = TargetState.Player
                    if t and t.Character then
                        flingPlayer(t, FlingState.Power, "random")
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

-- ====================================================================
-- 特殊フリングパターン
-- ====================================================================
local SpecialFlingGroup = TabFling:AddLeftGroupbox("特殊フリング")

SpecialFlingGroup:AddButton({
    Text = "▶ 全員を渦巻き状にフリング",
    Func = function()
        task.spawn(function()
            for i, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and plr.Character then
                    local root = getRoot(plr)
                    if root then
                        setNet(root)
                        local angle = (i / #Players:GetPlayers()) * math.pi * 2
                        local dir = Vector3.new(
                            math.cos(angle) * 100,
                            100,
                            math.sin(angle) * 100
                        ).Unit
                        velocity(root, dir * FlingState.Power)
                        task.wait(0.05)
                    end
                end
            end
        end)
        notify("shouyuhub", "渦巻きフリング実行", 3)
    end,
})

SpecialFlingGroup:AddButton({
    Text = "▶ 全員を一点集中フリング",
    Func = function()
        local center = Vector3.new(0, 100, 0)
        local hrp = getHRP()
        if hrp then center = hrp.Position + hrp.CFrame.LookVector * 50 end
        task.spawn(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and plr.Character then
                    local root = getRoot(plr)
                    if root then
                        setNet(root)
                        local dir = (center - root.Position).Unit
                        velocity(root, dir * FlingState.Power)
                        task.wait(0.05)
                    end
                end
            end
        end)
        notify("shouyuhub", "一点集中フリング実行", 3)
    end,
})

SpecialFlingGroup:AddButton({
    Text = "▶ 全員を天空に飛ばす",
    Func = function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local root = getRoot(plr)
                if root then
                    setNet(root)
                    velocity(root, Vector3.new(0, 10000, 0), 2)
                end
            end
        end
        notify("shouyuhub", "天空フリング実行", 3)
    end,
})

-- ====================================================================
-- Part 4 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 4 読み込み完了（飛ばし系）", 3)

print("[shouyuhub FTAP] Part 4 起動完了 - フリング全種")

-- ====================================================================
-- 【移動系】
-- フライ / ノークリップ / スピード / ジャンプ / 無限ジャンプ /
-- テレポート（マウス / 座標 / プレイヤー / ランダム）
-- ====================================================================

local MoveGroup = TabMove:AddLeftGroupbox("移動設定")

-- ====================================================================
-- 状態変数
-- ====================================================================
local MoveState = {
    FlyEnabled = false,
    FlySpeed = 50,
    Noclip = false,
    SpeedEnabled = false,
    SpeedValue = 16,
    JumpEnabled = false,
    JumpValue = 50,
    InfiniteJump = false,
    AutoSprint = false,
}

local flyBV, flyBG, flyConn

-- ====================================================================
-- フライ機能
-- ====================================================================
local function startFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end

    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBG.P = 9e4
    flyBG.D = 100
    flyBG.CFrame = hrp.CFrame
    flyBG.Parent = hrp

    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    flyBV.P = 1e5
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp

    flyConn = RunService.RenderStepped:Connect(function()
        if not MoveState.FlyEnabled then return end
        local c = LP.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local cam = WS.CurrentCamera
        if not cam then return end

        local dir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

        if dir.Magnitude > 0 then
            dir = dir.Unit * MoveState.FlySpeed
        end

        if flyBV and flyBV.Parent then flyBV.Velocity = dir end
        if flyBG and flyBG.Parent then flyBG.CFrame = cam.CFrame end
    end)
end

local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
end

MoveGroup:AddToggle("Fly", {
    Text = "フライ",
    Default = false,
    Callback = function(v)
        MoveState.FlyEnabled = v
        M.FlyEnabled = v
        if v then
            startFly()
            notify("shouyuhub", "フライ ON", 2)
        else
            stopFly()
            notify("shouyuhub", "フライ OFF", 2)
        end
    end,
})

MoveGroup:AddSlider("FlySpeed", {
    Text = "フライ速度",
    Default = 50,
    Min = 10,
    Max = 500,
    Rounding = 0,
    Callback = function(v)
        MoveState.FlySpeed = v
        M.FlySpeed = v
    end,
})

-- ====================================================================
-- ノークリップ
-- ====================================================================
MoveGroup:AddToggle("Noclip", {
    Text = "ノークリップ",
    Default = false,
    Callback = function(v)
        MoveState.Noclip = v
        M.Noclip = v
        notify("shouyuhub", v and "ノークリップ ON" or "OFF", 2)
    end,
})

-- ノークリップ ループ
task.spawn(function()
    while task.wait(0.1) do
        if MoveState.Noclip then
            local c = LP.Character
            if c then
                for _, v in ipairs(c:GetDescendants()) do
                    if v:IsA("BasePart") and v.CanCollide then
                        v.CanCollide = false
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- スピードハック
-- ====================================================================
MoveGroup:AddToggle("SpeedEnabled", {
    Text = "スピードハック",
    Default = false,
    Callback = function(v)
        MoveState.SpeedEnabled = v
        M.SpeedEnabled = v
        local h = getHum()
        if h then h.WalkSpeed = v and MoveState.SpeedValue or 16 end
        notify("shouyuhub", v and "スピード ON" or "OFF", 2)
    end,
})

MoveGroup:AddSlider("SpeedValue", {
    Text = "スピード値",
    Default = 16,
    Min = 16,
    Max = 500,
    Rounding = 0,
    Callback = function(v)
        MoveState.SpeedValue = v
        M.SpeedValue = v
        if MoveState.SpeedEnabled then
            local h = getHum()
            if h then h.WalkSpeed = v end
        end
    end,
})

-- ====================================================================
-- ジャンプパワー
-- ====================================================================
MoveGroup:AddToggle("JumpEnabled", {
    Text = "ジャンプパワー",
    Default = false,
    Callback = function(v)
        MoveState.JumpEnabled = v
        M.JumpEnabled = v
        local h = getHum()
        if h then
            h.UseJumpPower = true
            h.JumpPower = v and MoveState.JumpValue or 50
        end
        notify("shouyuhub", v and "ジャンプパワー ON" or "OFF", 2)
    end,
})

MoveGroup:AddSlider("JumpValue", {
    Text = "ジャンプ値",
    Default = 50,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(v)
        MoveState.JumpValue = v
        M.JumpValue = v
        if MoveState.JumpEnabled then
            local h = getHum()
            if h then h.UseJumpPower = true; h.JumpPower = v end
        end
    end,
})

-- ====================================================================
-- 無限ジャンプ
-- ====================================================================
MoveGroup:AddToggle("InfiniteJump", {
    Text = "無限ジャンプ",
    Default = false,
    Callback = function(v)
        MoveState.InfiniteJump = v
        M.InfiniteJump = v
        notify("shouyuhub", v and "無限ジャンプ ON" or "OFF", 2)
    end,
})

UIS.JumpRequest:Connect(function()
    if MoveState.InfiniteJump then
        local h = getHum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ====================================================================
-- オートスプリント
-- ====================================================================
MoveGroup:AddToggle("AutoSprint", {
    Text = "オートスプリント",
    Default = false,
    Callback = function(v)
        MoveState.AutoSprint = v
        M.AutoSprint = v
        notify("shouyuhub", v and "オートスプリント ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if MoveState.AutoSprint then
            local c = LP.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then h.WalkSpeed = MoveState.SpeedEnabled and MoveState.SpeedValue or 32 end
            end
        end
    end
end)

-- ====================================================================
-- 移動ステータス ループ
-- ====================================================================
RunService.Heartbeat:Connect(function()
    if MoveState.Noclip then
        local c = LP.Character
        if c then
            for _, v in ipairs(c:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then
                    v.CanCollide = false
                end
            end
        end
    end

    if MoveState.SpeedEnabled then
        local h = getHum()
        if h and h.WalkSpeed ~= MoveState.SpeedValue then
            h.WalkSpeed = MoveState.SpeedValue
        end
    end

    if MoveState.JumpEnabled then
        local h = getHum()
        if h then
            h.UseJumpPower = true
            if h.JumpPower ~= MoveState.JumpValue then
                h.JumpPower = MoveState.JumpValue
            end
        end
    end
end)

-- ====================================================================
-- テレポート系（右側）
-- ====================================================================
local TeleGroup = TabMove:AddRightGroupbox("テレポート")

local mouse = LP:GetMouse()

-- マウス位置TP
TeleGroup:AddButton({
    Text = "▶ マウス位置へTP",
    Func = function()
        local hrp = getHRP()
        if hrp and mouse.Hit then
            hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
            notify("shouyuhub", "マウス位置へTP", 2)
        end
    end,
})

-- 座標入力（3つ）
local tpX = "0"
local tpY = "70"
local tpZ = "0"

TeleGroup:AddInput("TPX", {
    Text = "X座標",
    Default = "0",
    Numeric = true,
    Finished = false,
    Callback = function(v) tpX = v end,
})

TeleGroup:AddInput("TPY", {
    Text = "Y座標",
    Default = "70",
    Numeric = true,
    Finished = false,
    Callback = function(v) tpY = v end,
})

TeleGroup:AddInput("TPZ", {
    Text = "Z座標",
    Default = "0",
    Numeric = true,
    Finished = false,
    Callback = function(v) tpZ = v end,
})

TeleGroup:AddButton({
    Text = "▶ 指定座標へTP",
    Func = function()
        local hrp = getHRP()
        if hrp then
            local x = tonumber(tpX) or 0
            local y = tonumber(tpY) or 70
            local z = tonumber(tpZ) or 0
            hrp.CFrame = CFrame.new(x, y, z)
            notify("shouyuhub", "座標TP: " .. x .. ", " .. y .. ", " .. z, 2)
        end
    end,
})

-- よく使う座標プリセット
TeleGroup:AddButton({
    Text = "▶ 上空 (0, 1000, 0)",
    Func = function()
        local hrp = getHRP()
        if hrp then hrp.CFrame = CFrame.new(0, 1000, 0) end
    end,
})

TeleGroup:AddButton({
    Text = "▶ 中央 (0, 70, 0)",
    Func = function()
        local hrp = getHRP()
        if hrp then hrp.CFrame = CFrame.new(0, 70, 0) end
    end,
})

TeleGroup:AddButton({
    Text = "▶ 元の位置に戻る",
    Func = function()
        local hrp = getHRP()
        if hrp and M.LastSafePos then
            hrp.CFrame = M.LastSafePos
            notify("shouyuhub", "元の位置へ", 2)
        end
    end,
})

-- 安全位置を保存
task.spawn(function()
    while task.wait(2) do
        local hrp = getHRP()
        if hrp then
            M.LastSafePos = hrp.CFrame
        end
    end
end)

-- ====================================================================
-- プレイヤーTP
-- ====================================================================
local PlayerTPGroup = TabMove:AddRightGroupbox("プレイヤーTP")

local PlayerTPDD
PlayerTPDD = PlayerTPGroup:AddDropdown("PlayerTPDD", {
    Text = "プレイヤーを選択",
    Values = getPlayerList(),
    Default = nil,
    Callback = function(v)
        TargetState.Player = getPlayerFromString(v)
        TargetState.Name = TargetState.Player and TargetState.Player.Name or nil
    end,
})

PlayerTPGroup:AddButton({
    Text = "リスト更新",
    Func = function()
        if PlayerTPDD and PlayerTPDD.SetValues then
            PlayerTPDD:SetValues(getPlayerList())
        end
    end,
})

PlayerTPGroup:AddButton({
    Text = "▶ 選択プレイヤーへTP",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then
            notify("shouyuhub", "ターゲット未選択", 2)
            return
        end
        local hrp = getHRP()
        local trp = getRoot(t)
        if hrp and trp then
            hrp.CFrame = trp.CFrame * CFrame.new(0, 0, 3)
            notify("shouyuhub", t.Name .. " の元へTP", 2)
        end
    end,
})

PlayerTPGroup:AddButton({
    Text = "▶ 選択プレイヤーを自分へTP",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        local hrp = getHRP()
        local trp = getRoot(t)
        if hrp and trp then
            setNet(trp)
            task.wait(0.05)
            trp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 3
            notify("shouyuhub", t.Name .. " を自分へTP", 2)
        end
    end,
})

-- 連続プレイヤーTP（追跡）
local followPlayer = false
PlayerTPGroup:AddToggle("FollowPlayer", {
    Text = "選択プレイヤーを追跡",
    Default = false,
    Callback = function(v)
        followPlayer = v
        if v then
            task.spawn(function()
                while followPlayer do
                    local t = TargetState.Player
                    if t and t.Character then
                        local hrp = getHRP()
                        local trp = getRoot(t)
                        if hrp and trp then
                            hrp.CFrame = trp.CFrame * CFrame.new(0, 0, 5)
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

-- ====================================================================
-- ランダムTP
-- ====================================================================
local RandomTPGroup = TabMove:AddRightGroupbox("ランダムTP")

RandomTPGroup:AddButton({
    Text = "▶ ランダム位置へTP",
    Func = function()
        local hrp = getHRP()
        if hrp then
            local x = math.random(-500, 500)
            local y = math.random(50, 300)
            local z = math.random(-500, 500)
            hrp.CFrame = CFrame.new(x, y, z)
            notify("shouyuhub", "ランダムTP", 2)
        end
    end,
})

-- 連続ランダムTP
local randomTPActive = false
RandomTPGroup:AddToggle("RandomTP", {
    Text = "連続ランダムTP",
    Default = false,
    Callback = function(v)
        randomTPActive = v
        if v then
            task.spawn(function()
                while randomTPActive do
                    local hrp = getHRP()
                    if hrp then
                        hrp.CFrame = CFrame.new(
                            math.random(-500, 500),
                            math.random(50, 300),
                            math.random(-500, 500)
                        )
                    end
                    task.wait(0.5)
                end
            end)
        end
    end,
})

-- ====================================================================
-- キャラクター再スポーン時の再適用
-- ====================================================================
LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    if MoveState.SpeedEnabled then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = MoveState.SpeedValue end
    end
    if MoveState.JumpEnabled then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.UseJumpPower = true; h.JumpPower = MoveState.JumpValue end
    end
    if MoveState.FlyEnabled then
        task.wait(0.5)
        startFly()
    end
end)

-- ====================================================================
-- Part 5 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 5 読み込み完了（移動系）", 3)

print("[shouyuhub FTAP] Part 5 起動完了 - 移動系")

-- ====================================================================
-- 【戦闘系】
-- Silent Aim / Aimbot / Triggerbot / Hitbox拡張 /
-- FOVサークル / 弾道予測 / ノックバック / スロー
-- ====================================================================

local CombatGroup = TabCombat:AddLeftGroupbox("エイム支援")

-- ====================================================================
-- 状態変数
-- ====================================================================
local CombatState = {
    SilentAim = false,
    SARange = 30,
    Aimbot = false,
    AimbotFOV = 90,
    Triggerbot = false,
    TriggerDelay = 0.05,
    HitboxExpand = false,
    HitboxSize = 3,
    FOVCircle = false,
    BulletPredict = false,
    NoKnockback = false,
    ForceSlow = false,
    SlowValue = 5,
}

-- ====================================================================
-- Silent Aim
-- ====================================================================
local saOldNamecall

local function getClosestHead(maxRange)
    local myRoot = getHRP()
    if not myRoot then return nil end
    local best, bd = nil, maxRange
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 then
                local d = (myRoot.Position - head.Position).Magnitude
                if d < bd then
                    bd = d
                    best = head
                end
            end
        end
    end
    return best
end

local function hookSilentAim()
    if saOldNamecall then return end
    saOldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
        if CombatState.SilentAim and tostring(method) == "Raycast" and self == WS then
            local target = getClosestHead(CombatState.SARange)
            if target then
                local origin = args[1] or Vector3.new()
                args[3] = (target.Position - origin).Unit
            end
        end
        return saOldNamecall(self, unpack(args))
    end)
end

CombatGroup:AddSlider("SARange", {
    Text = "Silent Aim 範囲",
    Default = 30, Min = 5, Max = 200, Rounding = 0,
    Callback = function(v) CombatState.SARange = v; M.SARange = v end,
})

CombatGroup:AddToggle("SilentAim", {
    Text = "Silent Aim",
    Default = false,
    Callback = function(v)
        CombatState.SilentAim = v
        M.SilentAim = v
        if v then hookSilentAim() end
        notify("shouyuhub", v and "Silent Aim ON" or "OFF", 2)
    end,
})

-- ====================================================================
-- Aimbot
-- ====================================================================
CombatGroup:AddSlider("AimbotFOV", {
    Text = "Aimbot FOV",
    Default = 90, Min = 10, Max = 360, Rounding = 0,
    Callback = function(v) CombatState.AimbotFOV = v; M.AimbotFOV = v end,
})

CombatGroup:AddToggle("Aimbot", {
    Text = "Aimbot (右クリックで固定)",
    Default = false,
    Callback = function(v)
        CombatState.Aimbot = v
        M.Aimbot = v
        notify("shouyuhub", v and "Aimbot ON" or "OFF", 2)
    end,
})

-- Aimbot ループ
task.spawn(function()
    while task.wait(0.01) do
        if CombatState.Aimbot and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            local cam = WS.CurrentCamera
            if cam then
                local myPos = cam.CFrame.Position
                local myLook = cam.CFrame.LookVector
                local best, bd = nil, CombatState.AimbotFOV
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character then
                        local head = p.Character:FindFirstChild("Head")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if head and hum and hum.Health > 0 then
                            local dir = (head.Position - myPos).Unit
                            local dot = myLook:Dot(dir)
                            local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
                            if angle < bd then
                                bd = angle
                                best = head
                            end
                        end
                    end
                end
                if best then
                    pcall(function()
                        cam.CFrame = CFrame.new(cam.CFrame.Position, best.Position)
                    end)
                end
            end
        end
    end
end)

-- ====================================================================
-- Triggerbot
-- ====================================================================
CombatGroup:AddSlider("TriggerDelay", {
    Text = "トリガー遅延",
    Default = 0.05, Min = 0.01, Max = 1, Rounding = 2,
    Callback = function(v) CombatState.TriggerDelay = v; M.TriggerDelay = v end,
})

CombatGroup:AddToggle("Triggerbot", {
    Text = "Triggerbot (クロスヘア上で自動発射)",
    Default = false,
    Callback = function(v)
        CombatState.Triggerbot = v
        M.Triggerbot = v
        notify("shouyuhub", v and "Triggerbot ON" or "OFF", 2)
    end,
})

-- Triggerbot ループ
task.spawn(function()
    while task.wait(CombatState.TriggerDelay) do
        if CombatState.Triggerbot then
            local cam = WS.CurrentCamera
            if cam then
                local origin = cam.CFrame.Position
                local dir = cam.CFrame.LookVector * 500
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {LP.Character}
                local result = WS:Raycast(origin, dir, params)
                if result and result.Instance then
                    local model = result.Instance:FindFirstAncestorOfClass("Model")
                    if model then
                        local hum = model:FindFirstChildOfClass("Humanoid")
                        if hum and model ~= LP.Character and hum.Health > 0 then
                            pcall(function()
                                if mouse1click then mouse1click()
                                elseif mouse1press then mouse1press(); mouse1release()
                                elseif VU.ClickButton2 then VU:ClickButton2(Vector2.new()) end
                            end)
                        end
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- ヒットボックス拡張
-- ====================================================================
CombatGroup:AddSlider("HitboxSize", {
    Text = "ヒットボックスサイズ",
    Default = 3, Min = 2, Max = 15, Rounding = 0,
    Callback = function(v) CombatState.HitboxSize = v; M.HitboxSize = v end,
})

CombatGroup:AddToggle("HitboxExpand", {
    Text = "ヒットボックス拡張",
    Default = false,
    Callback = function(v)
        CombatState.HitboxExpand = v
        M.HitboxExpand = v
        notify("shouyuhub", v and "ヒットボックス拡張 ON" or "OFF", 2)
    end,
})

-- ヒットボックス ループ
task.spawn(function()
    while task.wait(0.5) do
        if CombatState.HitboxExpand then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local s = CombatState.HitboxSize
                        hrp.Size = Vector3.new(s, s, s)
                        hrp.Transparency = 0.5
                        hrp.CanCollide = false
                    end
                end
            end
        else
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Size = Vector3.new(2, 2, 1)
                        hrp.Transparency = 1
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- FOV サークル表示
-- ====================================================================
local fovGui = Instance.new("ScreenGui")
fovGui.Name = "shouyuFOVCircle"
fovGui.ResetOnSpawn = false
pcall(function() fovGui.Parent = (gethui and gethui()) or CG end)
if not fovGui.Parent then fovGui.Parent = LP:WaitForChild("PlayerGui") end

local fovFrame = Instance.new("Frame")
fovFrame.Size = UDim2.new(0, 200, 0, 200)
fovFrame.Position = UDim2.new(0.5, -100, 0.5, -100)
fovFrame.BackgroundTransparency = 1
fovFrame.Visible = false
fovFrame.Parent = fovGui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovFrame

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 50, 50)
fovStroke.Thickness = 2
fovStroke.Transparency = 0.3
fovStroke.Parent = fovFrame

CombatGroup:AddToggle("FOVCircle", {
    Text = "FOV サークル表示",
    Default = false,
    Callback = function(v)
        CombatState.FOVCircle = v
        fovFrame.Visible = v
    end,
})

-- FOVサークル サイズ更新
task.spawn(function()
    while task.wait(0.2) do
        if CombatState.FOVCircle then
            local cam = WS.CurrentCamera
            if cam then
                local size = (CombatState.SARange / 30) * 200
                fovFrame.Size = UDim2.new(0, size, 0, size)
                fovFrame.Position = UDim2.new(0.5, -size/2, 0.5, -size/2)
            end
        end
    end
end)

-- ====================================================================
-- 弾道予測
-- ====================================================================
CombatGroup:AddToggle("BulletPredict", {
    Text = "弾道予測表示",
    Default = false,
    Callback = function(v)
        CombatState.BulletPredict = v
        M.BulletPredict = v
    end,
})

-- 弾道予測ループ
local predictParts = {}
task.spawn(function()
    while task.wait(0.1) do
        if CombatState.BulletPredict then
            local cam = WS.CurrentCamera
            local hrp = getHRP()
            if cam and hrp then
                local origin = hrp.Position
                local dir = cam.CFrame.LookVector
                for i = 1, 10 do
                    if not predictParts[i] then
                        local p = Instance.new("Part")
                        p.Size = Vector3.new(0.3, 0.3, 0.3)
                        p.Shape = Enum.PartType.Ball
                        p.Material = Enum.Material.Neon
                        p.Color = Color3.fromRGB(255, 200, 0)
                        p.Anchored = true
                        p.CanCollide = false
                        p.CanTouch = false
                        p.CanQuery = false
                        p.Parent = WS
                        predictParts[i] = p
                    end
                    predictParts[i].Position = origin + dir * (i * 8)
                end
            end
        else
            for _, p in pairs(predictParts) do
                pcall(function() p:Destroy() end)
            end
            predictParts = {}
        end
    end
end)

-- ====================================================================
-- 戦闘補助（右側）
-- ====================================================================
local CombatExtraGroup = TabCombat:AddRightGroupbox("戦闘補助")

-- ノックバック無効
CombatExtraGroup:AddToggle("NoKnockback", {
    Text = "ノックバック無効",
    Default = false,
    Callback = function(v)
        CombatState.NoKnockback = v
        M.NoKnockback = v
    end,
})

task.spawn(function()
    while task.wait(0.05) do
        if CombatState.NoKnockback then
            local c = LP.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                if hum.MoveDirection.Magnitude == 0 then
                    hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0)
                end
                hrp.RotVelocity = Vector3.zero
            end
        end
    end
end)

-- 相手をスロー
CombatExtraGroup:AddSlider("SlowValue", {
    Text = "スロー値",
    Default = 5, Min = 1, Max = 16, Rounding = 0,
    Callback = function(v) CombatState.SlowValue = v; M.SlowValue = v end,
})

CombatExtraGroup:AddToggle("ForceSlow", {
    Text = "掴んだ相手をスロー",
    Default = false,
    Callback = function(v)
        CombatState.ForceSlow = v
        M.ForceSlow = v
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if CombatState.ForceSlow then
            local gp = WS:FindFirstChild("GrabParts")
            if gp then
                local grabPart = gp:FindFirstChild("GrabPart")
                if grabPart then
                    local wc = grabPart:FindFirstChild("WeldConstraint")
                    if wc and wc.Part1 then
                        local char = wc.Part1.Parent
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hum then hum.WalkSpeed = CombatState.SlowValue end
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 連続射撃（PC）
-- ====================================================================
local rapidFireActive = false
CombatExtraGroup:AddToggle("RapidFire", {
    Text = "連続射撃",
    Default = false,
    Callback = function(v)
        rapidFireActive = v
        if v then
            task.spawn(function()
                while rapidFireActive do
                    pcall(function()
                        if mouse1click then mouse1click()
                        elseif VU.ClickButton2 then VU:ClickButton2(Vector2.new()) end
                    end)
                    task.wait(0.05)
                end
            end)
        end
    end,
})

-- ====================================================================
-- Part 6 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 6 読み込み完了（戦闘系）", 3)

print("[shouyuhub FTAP] Part 6 起動完了 - 戦闘系")

-- ====================================================================
-- 【防御系 前半】
-- アンチラグドール / アンチノックバック / アンチフリング /
-- アンチボイド / アンチキック / アンチテレポート
-- ====================================================================

local DefenseGroup = TabDefense:AddLeftGroupbox("基本防御")

-- ====================================================================
-- 状態変数
-- ====================================================================
local DefState = {
    AntiRagdoll = false,
    AntiKnockback = false,
    AntiFling = false,
    AntiVoid = false,
    AntiKick = false,
    AntiTeleport = false,
    AutoReset = false,
    AntiFreeze = false,
}

-- ====================================================================
-- 1. アンチラグドール
-- ====================================================================
DefenseGroup:AddToggle("AntiRagdoll", {
    Text = "アンチラグドール",
    Default = false,
    Callback = function(v)
        DefState.AntiRagdoll = v
        M.AntiRagdoll = v
        notify("shouyuhub", v and "アンチラグドール ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.05) do
        if DefState.AntiRagdoll then
            local h = getHum()
            if h then
                local s = h:GetState()
                if s == Enum.HumanoidStateType.Physics
                    or s == Enum.HumanoidStateType.FallingDown
                    or s == Enum.HumanoidStateType.Ragdoll then
                    pcall(function()
                        h:ChangeState(Enum.HumanoidStateType.Running)
                        h.PlatformStand = false
                        h.AutoRotate = true
                    end)
                end
            end
        end
    end
end)

-- ====================================================================
-- 2. アンチノックバック
-- ====================================================================
DefenseGroup:AddToggle("AntiKnockback", {
    Text = "アンチノックバック",
    Default = false,
    Callback = function(v)
        DefState.AntiKnockback = v
        M.AntiKnockback = v
        notify("shouyuhub", v and "アンチノックバック ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.05) do
        if DefState.AntiKnockback then
            local c = LP.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                if hum.MoveDirection.Magnitude == 0 then
                    hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, hrp.AssemblyLinearVelocity.Y, 0)
                end
                hrp.RotVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end
end)

-- ====================================================================
-- 3. アンチフリング
-- ====================================================================
DefenseGroup:AddToggle("AntiFling", {
    Text = "アンチフリング",
    Default = false,
    Callback = function(v)
        DefState.AntiFling = v
        M.AntiFling = v
        notify("shouyuhub", v and "アンチフリング ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.03) do
        if DefState.AntiFling then
            local hrp = getHRP()
            if hrp then
                local v = hrp.AssemblyLinearVelocity
                if v.Magnitude > 200 then
                    hrp.AssemblyLinearVelocity = Vector3.new(v.X * 0.2, v.Y, v.Z * 0.2)
                end
                if hrp.AssemblyAngularVelocity.Magnitude > 50 then
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    end
end)

-- ====================================================================
-- 4. アンチボイド
-- ====================================================================
local origFallHeight = WS.FallenPartsDestroyHeight

DefenseGroup:AddToggle("AntiVoid", {
    Text = "アンチボイド（奈落無効）",
    Default = false,
    Callback = function(v)
        DefState.AntiVoid = v
        M.AntiVoid = v
        if v then
            origFallHeight = WS.FallenPartsDestroyHeight
            WS.FallenPartsDestroyHeight = 0/0
        else
            WS.FallenPartsDestroyHeight = origFallHeight
        end
        notify("shouyuhub", v and "アンチボイド ON" or "OFF", 2)
    end,
})

-- 落ちた時に復帰
task.spawn(function()
    while task.wait(0.3) do
        if DefState.AntiVoid then
            local hrp = getHRP()
            if hrp and hrp.Position.Y < -200 then
                hrp.CFrame = CFrame.new(0, 70, 0)
            end
        end
    end
end)

-- ====================================================================
-- 5. アンチキック
-- ====================================================================
if type(hookmetamethod) == "function" and type(getnamecallmethod) == "function" then
    local origKick
    origKick = hookmetamethod(game, "__namecall", function(self, ...)
        if DefState.AntiKick and (type(checkcaller) ~= "function" or not checkcaller()) then
            local method = getnamecallmethod()
            if method == "Kick" and self == LP then
                return nil
            end
        end
        return origKick(self, ...)
    end)
end

DefenseGroup:AddToggle("AntiKick", {
    Text = "アンチキック",
    Default = false,
    Callback = function(v)
        DefState.AntiKick = v
        M.AntiKick = v
        notify("shouyuhub", v and "アンチキック ON" or "OFF", 2)
    end,
})

-- ====================================================================
-- 6. アンチテレポート
-- ====================================================================
DefenseGroup:AddToggle("AntiTeleport", {
    Text = "アンチテレポート",
    Default = false,
    Callback = function(v)
        DefState.AntiTeleport = v
        M.AntiTeleport = v
        if v then
            M.LastPos = getHRP() and getHRP().CFrame
        end
        notify("shouyuhub", v and "アンチテレポート ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if DefState.AntiTeleport then
            local hrp = getHRP()
            if hrp then
                if not M.LastPos then
                    M.LastPos = hrp.CFrame
                end
                local dist = (hrp.Position - M.LastPos.Position).Magnitude
                if dist > 100 then
                    hrp.CFrame = M.LastPos
                else
                    M.LastPos = hrp.CFrame
                end
            end
        end
    end
end)

-- ====================================================================
-- 7. 自動リスポーン
-- ====================================================================
DefenseGroup:AddToggle("AutoReset", {
    Text = "自動リスポーン（Flying検知）",
    Default = false,
    Callback = function(v)
        DefState.AutoReset = v
        M.AutoReset = v
        notify("shouyuhub", v and "自動リスポーン ON" or "OFF", 2)
    end,
})

local GCE = RS:FindFirstChild("GameCorrectionEvents")
local NotifyEvent = GCE and GCE:FindFirstChild("GameCorrectionsNotify")

if NotifyEvent then
    NotifyEvent.OnClientEvent:Connect(function(reason)
        if DefState.AutoReset and reason == "Flying" then
            local c = LP.Character
            if c then
                c:BreakJoints()
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then h.Health = 0 end
            end
        end
    end)
end

-- ====================================================================
-- 8. アンチフリーズ（位置固定対策）
-- ====================================================================
DefenseGroup:AddToggle("AntiFreeze", {
    Text = "アンチフリーズ",
    Default = false,
    Callback = function(v)
        DefState.AntiFreeze = v
        M.AntiFreeze = v
        notify("shouyuhub", v and "アンチフリーズ ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if DefState.AntiFreeze then
            local c = LP.Character
            if c then
                local h = c:FindFirstChildOfClass("Humanoid")
                if h and h.WalkSpeed < 5 and not h.Sit then
                    h.WalkSpeed = 16
                end
            end
        end
    end
end)

-- ====================================================================
-- 防御系 右側
-- ====================================================================
local DefExtraGroup = TabDefense:AddRightGroupbox("追加防御")

-- ====================================================================
-- 9. アンチ爆発
-- ====================================================================
local DefState2 = {
    AntiExplosion = false,
    AntiBurn = false,
    AntiSticky = false,
    AntiPoison = false,
}

DefExtraGroup:AddToggle("AntiExplosion", {
    Text = "アンチ爆発",
    Default = false,
    Callback = function(v)
        DefState2.AntiExplosion = v
        M.AntiExplosion = v
    end,
})

local antiExpConn = nil
task.spawn(function()
    while task.wait(0.2) do
        if DefState2.AntiExplosion and not antiExpConn then
            antiExpConn = WS.ChildAdded:Connect(function(obj)
                if not DefState2.AntiExplosion then return end
                if obj.Name == "Part" or obj.Name == "Explosion" then
                    task.wait(0.01)
                    local hrp = getHRP()
                    if hrp and obj:IsA("BasePart") and (obj.Position - hrp.Position).Magnitude <= 25 then
                        hrp.Anchored = true
                        task.wait(0.05)
                        hrp.Anchored = false
                    end
                end
            end)
        elseif not DefState2.AntiExplosion and antiExpConn then
            antiExpConn:Disconnect()
            antiExpConn = nil
        end
    end
end)

-- ====================================================================
-- 10. アンチバーン
-- ====================================================================
DefExtraGroup:AddToggle("AntiBurn", {
    Text = "アンチバーン",
    Default = false,
    Callback = function(v)
        DefState2.AntiBurn = v
        M.AntiBurn = v
    end,
})

task.spawn(function()
    while task.wait(0.2) do
        if DefState2.AntiBurn then
            local c = LP.Character
            if c then
                for _, o in ipairs(c:GetDescendants()) do
                    if o:IsA("Fire") or (o:IsA("ParticleEmitter") and o.Name:lower():find("fire")) then
                        o:Destroy()
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 11. アンチスティッキー
-- ====================================================================
DefExtraGroup:AddToggle("AntiSticky", {
    Text = "アンチスティッキー",
    Default = false,
    Callback = function(v)
        DefState2.AntiSticky = v
        M.AntiSticky = v
    end,
})

task.spawn(function()
    while task.wait(0.3) do
        if DefState2.AntiSticky then
            local c = LP.Character
            if c then
                for _, o in ipairs(c:GetDescendants()) do
                    if o:IsA("Weld") or o:IsA("WeldConstraint") or o:IsA("ManualWeld") then
                        -- 自分のキャラ内の正常な関節以外を削除
                        if o.Name:lower():find("sticky") then
                            pcall(function() o:Destroy() end)
                        end
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 12. アンチポイズン
-- ====================================================================
DefExtraGroup:AddToggle("AntiPoison", {
    Text = "アンチポイズン",
    Default = false,
    Callback = function(v)
        DefState2.AntiPoison = v
        M.AntiPoison = v
    end,
})

task.spawn(function()
    while task.wait(0.5) do
        if DefState2.AntiPoison then
            local h = getHum()
            if h then
                -- ダメージ無効化ではなく体力監視
                pcall(function()
                    if h:GetAttribute("Poisoned") == true then
                        h:SetAttribute("Poisoned", false)
                    end
                end)
            end
        end
    end
end)

-- ====================================================================
-- 13. アンチグラブ（防御版）
-- ====================================================================
local DefState3 = {
    AntiGrabPassive = false,
}

DefExtraGroup:AddToggle("AntiGrabPassive", {
    Text = "アンチグラブ（常時）",
    Default = false,
    Callback = function(v)
        DefState3.AntiGrabPassive = v
        M.AntiGrabPassive = v
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if DefState3.AntiGrabPassive then
            local hrp = getHRP()
            if hrp then
                pcall(function()
                    if StruggleEvent then StruggleEvent:FireServer() end
                    if RagdollRemote then RagdollRemote:FireServer(hrp, 0) end
                end)
            end
        end
    end
end)

-- ====================================================================
-- キャラクター再スポーン時
-- ====================================================================
LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    if DefState.AntiRagdoll then
        local h = char:FindFirstChildOfClass("Humanoid")
        if h then h.PlatformStand = false end
    end
end)

-- ====================================================================
-- Part 7 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 7 読み込み完了（防御系 前半）", 3)

print("[shouyuhub FTAP] Part 7 起動完了 - 防御系")

-- ====================================================================
-- 【防御系 後半】
-- アンチデコイ / アンチGucci / アンチPCLD / 位置固定 /
-- 自動脱出 / ロック解除 / アンチ入力遅延
-- ====================================================================

local DefenseGroup2 = TabDefense:AddRightGroupbox("高度防御")

-- ====================================================================
-- 状態変数
-- ====================================================================
local DefState4 = {
    AntiDecoy = false,
    AntiGucci = false,
    AntiPCLD = false,
    PositionLock = false,
    AutoEscape = false,
    UnlockOnGrab = false,
    AntiInputLag = false,
}

local lockedPos = nil

-- ====================================================================
-- 1. アンチデコイ（偽オブジェクト検出）
-- ====================================================================
DefenseGroup2:AddToggle("AntiDecoy", {
    Text = "アンチデコイ",
    Default = false,
    Callback = function(v)
        DefState4.AntiDecoy = v
        M.AntiDecoy = v
        notify("shouyuhub", v and "アンチデコイ ON" or "OFF", 2)
    end,
})

local decoyConn = nil
task.spawn(function()
    while task.wait(0.3) do
        if DefState4.AntiDecoy and not decoyConn then
            decoyConn = WS.DescendantAdded:Connect(function(obj)
                if not DefState4.AntiDecoy then return end
                if obj:IsA("BasePart") then
                    if obj.Name:lower():find("decoy") or obj.Name:lower():find("fake") then
                        obj:Destroy()
                    end
                end
            end)
        elseif not DefState4.AntiDecoy and decoyConn then
            decoyConn:Disconnect()
            decoyConn = nil
        end
    end
end)

-- ====================================================================
-- 2. アンチGucci（車やBlobmanによる飛ばし対策）
-- ====================================================================
DefenseGroup2:AddToggle("AntiGucci", {
    Text = "アンチGucci",
    Default = false,
    Callback = function(v)
        DefState4.AntiGucci = v
        M.AntiGucci = v
        notify("shouyuhub", v and "アンチGucci ON" or "OFF", 2)
    end,
})

local gucciOrigPos = nil

task.spawn(function()
    while task.wait(0.1) do
        if DefState4.AntiGucci then
            local c = LP.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if hrp and hum then
                -- Blobman/車に乗せられていたら強制解除
                if hum.Sit and hum.SeatPart then
                    local seat = hum.SeatPart
                    local parentName = seat.Parent and seat.Parent.Name or ""
                    if parentName == "CreatureBlobman"
                        or parentName:lower():find("tractor")
                        or parentName:lower():find("vehicle")
                        or parentName:lower():find("car") then
                        pcall(function()
                            hum.Sit = false
                            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                            hum.Jump = true
                        end)
                    end
                end

                -- 速度異常検知で位置を固定
                if hrp.AssemblyLinearVelocity.Magnitude > 500 then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end
        end
    end
end)

-- ====================================================================
-- 3. アンチPCLD（位置検知リセット）
-- ====================================================================
DefenseGroup2:AddToggle("AntiPCLD", {
    Text = "アンチPCLD（位置検知リセット）",
    Default = false,
    Callback = function(v)
        DefState4.AntiPCLD = v
        M.AntiPCLD = v
        notify("shouyuhub", v and "アンチPCLD ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.5) do
        if DefState4.AntiPCLD then
            for _, obj in ipairs(WS:GetChildren()) do
                if obj.Name == "PlayerCharacterLocationDetector" then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end
end)

-- ====================================================================
-- 4. 位置固定（ロック）
-- ====================================================================
DefenseGroup2:AddToggle("PositionLock", {
    Text = "位置固定",
    Default = false,
    Callback = function(v)
        DefState4.PositionLock = v
        M.PositionLock = v
        if v then
            local hrp = getHRP()
            if hrp then lockedPos = hrp.CFrame end
            notify("shouyuhub", "位置固定 ON", 2)
        else
            lockedPos = nil
            notify("shouyuhub", "位置固定 OFF", 2)
        end
    end,
})

task.spawn(function()
    while task.wait(0.05) do
        if DefState4.PositionLock and lockedPos then
            local hrp = getHRP()
            if hrp then
                hrp.CFrame = lockedPos
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end
end)

-- ====================================================================
-- 5. 自動脱出（掴まれたら逃げる）
-- ====================================================================
DefenseGroup2:AddToggle("AutoEscape", {
    Text = "自動脱出（掴まれたら逃げる）",
    Default = false,
    Callback = function(v)
        DefState4.AutoEscape = v
        M.AutoEscape = v
        notify("shouyuhub", v and "自動脱出 ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if DefState4.AutoEscape then
            local hrp = getHRP()
            if hrp then
                -- 掴まれ判定
                local isHeld = LP:FindFirstChild("IsHeld")
                local held = isHeld and isHeld.Value or false
                if held then
                    -- Struggle
                    pcall(function()
                        if StruggleEvent then StruggleEvent:FireServer() end
                    end)
                    -- 上にジャンプ
                    local h = getHum()
                    if h then
                        h.Jump = true
                        h:ChangeState(Enum.HumanoidStateType.Jumping)
                    end
                    -- ランダムテレポートで脱出
                    task.spawn(function()
                        task.wait(0.05)
                        hrp.CFrame = hrp.CFrame + Vector3.new(
                            math.random(-30, 30), 20, math.random(-30, 30)
                        )
                    end)
                end
            end
        end
    end
end)

-- ====================================================================
-- 6. 掴まれた時にロック解除
-- ====================================================================
DefenseGroup2:AddToggle("UnlockOnGrab", {
    Text = "掴まれた時に位置固定解除",
    Default = false,
    Callback = function(v)
        DefState4.UnlockOnGrab = v
        M.UnlockOnGrab = v
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if DefState4.UnlockOnGrab then
            local isHeld = LP:FindFirstChild("IsHeld")
            if isHeld and isHeld.Value then
                DefState4.PositionLock = false
                lockedPos = nil
            end
        end
    end
end)

-- ====================================================================
-- 7. アンチ入力遅延（Anti Input Lag）
-- ====================================================================
DefenseGroup2:AddToggle("AntiInputLag", {
    Text = "アンチ入力遅延",
    Default = false,
    Callback = function(v)
        DefState4.AntiInputLag = v
        M.AntiInputLag = v
        notify("shouyuhub", v and "アンチ入力遅延 ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.5) do
        if DefState4.AntiInputLag then
            -- 自分の周囲にあるFoodHamburger等を非表示
            for _, obj in ipairs(WS:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name == "SoundPart" then
                    local parent = obj.Parent
                    if parent and parent.Name:find("Food") then
                        pcall(function()
                            obj.Transparency = 1
                            obj.CanCollide = false
                            obj.CanTouch = false
                        end)
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 8. アンチコリジョン（衝突無効）
-- ====================================================================
DefenseGroup2:AddToggle("AntiCollision", {
    Text = "アンチコリジョン",
    Default = false,
    Callback = function(v)
        M.AntiCollision = v
        notify("shouyuhub", v and "アンチコリジョン ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if M.AntiCollision then
            local c = LP.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                        p.CanCollide = false
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 9. アンチアンカー（Anchored対策）
-- ====================================================================
DefenseGroup2:AddToggle("AntiAnchor", {
    Text = "アンチアンカー",
    Default = false,
    Callback = function(v)
        M.AntiAnchor = v
        notify("shouyuhub", v and "アンチアンカー ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if M.AntiAnchor then
            local c = LP.Character
            if c then
                local hrp = c:FindFirstChild("HumanoidRootPart")
                if hrp and hrp.Anchored then
                    hrp.Anchored = false
                end
            end
        end
    end
end)

-- ====================================================================
-- 10. アンチネットワーク所有権奪取
-- ====================================================================
DefenseGroup2:AddToggle("AntiNetworkSteal", {
    Text = "アンチネットワーク奪取",
    Default = false,
    Callback = function(v)
        M.AntiNetworkSteal = v
        notify("shouyuhub", v and "アンチネットワーク奪取 ON" or "OFF", 2)
    end,
})

task.spawn(function()
    while task.wait(0.2) do
        if M.AntiNetworkSteal then
            local hrp = getHRP()
            if hrp then
                pcall(function()
                    hrp:SetNetworkOwner(LP)
                end)
            end
        end
    end
end)

-- ====================================================================
-- 一括防御 ON/OFF
-- ====================================================================
local DefenseMasterGroup = TabDefense:AddLeftGroupbox("マスター")

DefenseMasterGroup:AddButton({
    Text = "▶ 全防御を有効化",
    Func = function()
        DefState.AntiRagdoll = true
        DefState.AntiKnockback = true
        DefState.AntiFling = true
        DefState.AntiVoid = true
        DefState.AntiKick = true
        DefState.AntiTeleport = true
        DefState2.AntiExplosion = true
        DefState2.AntiBurn = true
        DefState2.AntiSticky = true
        DefState3.AntiGrabPassive = true
        DefState4.AntiDecoy = true
        DefState4.AntiGucci = true
        DefState4.AntiPCLD = true
        DefState4.AutoEscape = true
        DefState4.AntiInputLag = true
        M.AntiCollision = true
        M.AntiAnchor = true
        notify("shouyuhub", "全防御 ON", 3)
    end,
})

DefenseMasterGroup:AddButton({
    Text = "▶ 全防御を無効化",
    Func = function()
        DefState.AntiRagdoll = false
        DefState.AntiKnockback = false
        DefState.AntiFling = false
        DefState.AntiVoid = false
        DefState.AntiKick = false
        DefState.AntiTeleport = false
        DefState2.AntiExplosion = false
        DefState2.AntiBurn = false
        DefState2.AntiSticky = false
        DefState3.AntiGrabPassive = false
        DefState4.AntiDecoy = false
        DefState4.AntiGucci = false
        DefState4.AntiPCLD = false
        DefState4.AutoEscape = false
        DefState4.AntiInputLag = false
        M.AntiCollision = false
        M.AntiAnchor = false
        notify("shouyuhub", "全防御 OFF", 3)
    end,
})

-- ====================================================================
-- キャラ再スポーン時の再適用
-- ====================================================================
LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    if DefState.PositionLock then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then lockedPos = hrp.CFrame end
    end
end)

-- ====================================================================
-- Part 8 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 8 読み込み完了（防御系 後半）", 3)

print("[shouyuhub FTAP] Part 8 起動完了 - 高度防御")

-- ====================================================================
-- 【ビジュアル 1〜10】
-- Fullbright / 時間停止 / スカイボックス / 星雲 / 帽子 /
-- トレイル / レインボー体 / ForceField / パーティクル / オーラ
-- ====================================================================

local VisGroup = TabVisual:AddLeftGroupbox("基本ビジュアル")

-- ====================================================================
-- 状態変数
-- ====================================================================
local VisState = {
    Fullbright = false,
    TimeFreeze = false,
    TimeValue = 12,
    SkyboxEnabled = false,
    SkyboxName = "HD",
    Nebula = false,
    HatEnabled = false,
    HatRainbow = false,
    TrailEnabled = false,
    RainbowBody = false,
    ForceFieldEnabled = false,
    ForceFieldRainbow = false,
    CustomAura = false,
    AuraID = "16699750981",
    ParticleEffect = false,
}

-- 元の設定を保存
local origLight = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient = Lighting.Ambient,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
}

-- ====================================================================
-- 1. Fullbright
-- ====================================================================
VisGroup:AddToggle("Fullbright", {
    Text = "フルブライト",
    Default = false,
    Callback = function(v)
        VisState.Fullbright = v
        M.Fullbright = v
        if v then
            Lighting.Brightness = 3
            Lighting.GlobalShadows = false
            Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
            Lighting.Ambient = Color3.new(1, 1, 1)
        else
            Lighting.Brightness = origLight.Brightness
            Lighting.GlobalShadows = origLight.GlobalShadows
            Lighting.OutdoorAmbient = origLight.OutdoorAmbient
            Lighting.Ambient = origLight.Ambient
        end
        notify("shouyuhub", v and "フルブライト ON" or "OFF", 2)
    end,
})

-- ====================================================================
-- 2. 時間停止
-- ====================================================================
VisGroup:AddToggle("TimeFreeze", {
    Text = "時間停止",
    Default = false,
    Callback = function(v)
        VisState.TimeFreeze = v
        M.TimeFreeze = v
        if not v then
            Lighting.ClockTime = origLight.ClockTime
        end
    end,
})

VisGroup:AddSlider("TimeValue", {
    Text = "時間 (0-24)",
    Default = 12,
    Min = 0,
    Max = 24,
    Rounding = 1,
    Callback = function(v)
        VisState.TimeValue = v
        M.TimeValue = v
    end,
})

task.spawn(function()
    while task.wait(0.5) do
        if VisState.TimeFreeze then
            Lighting.ClockTime = VisState.TimeValue
        end
    end
end)

-- ====================================================================
-- 3. スカイボックス
-- ====================================================================
local SkyboxList = {
    "HD", "Galaxy", "Space", "Pink", "Sunset",
    "Snow", "Stormy", "Blue Space", "Realistic", "Stylized",
}

VisGroup:AddDropdown("SkyboxDD", {
    Text = "スカイボックス",
    Values = SkyboxList,
    Default = "HD",
    Callback = function(v)
        VisState.SkyboxName = v
        M.SkyboxName = v
        if VisState.SkyboxEnabled then
            -- 適用
            local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky", Lighting)
            sky.Name = "shouyuSky"
            local SkyData = {
                HD = {bk="rbxassetid://16553658937", dn="rbxassetid://16553660713", ft="rbxassetid://16553662144", lf="rbxassetid://16553664042", rt="rbxassetid://16553665766", up="rbxassetid://16553667750"},
                Galaxy = {bk="rbxassetid://15983968922", dn="rbxassetid://15983966825", ft="rbxassetid://15983965025", lf="rbxassetid://15983967420", rt="rbxassetid://15983966246", up="rbxassetid://15983964246"},
                Space = {bk="rbxassetid://166509999", dn="rbxassetid://166510057", ft="rbxassetid://166510116", lf="rbxassetid://166510092", rt="rbxassetid://166510131", up="rbxassetid://166510114"},
                Pink = {bk="rbxassetid://12216109205", dn="rbxassetid://12216109875", ft="rbxassetid://12216109489", lf="rbxassetid://12216110170", rt="rbxassetid://12216110471", up="rbxassetid://12216108877"},
                Sunset = {bk="rbxassetid://600830446", dn="rbxassetid://600831635", ft="rbxassetid://600832720", lf="rbxassetid://600886090", rt="rbxassetid://600833862", up="rbxassetid://600835177"},
                Snow = {bk="rbxassetid://155657655", dn="rbxassetid://155674246", ft="rbxassetid://155657609", lf="rbxassetid://155657671", rt="rbxassetid://155657619", up="rbxassetid://155674931"},
                Stormy = {bk="rbxassetid://18703245834", dn="rbxassetid://18703243349", ft="rbxassetid://18703240532", lf="rbxassetid://18703237556", rt="rbxassetid://18703235430", up="rbxassetid://18703232671"},
                ["Blue Space"] = {bk="rbxassetid://15536110634", dn="rbxassetid://15536112543", ft="rbxassetid://15536116141", lf="rbxassetid://15536114370", rt="rbxassetid://15536118762", up="rbxassetid://15536117282"},
                Realistic = {bk="rbxassetid://653719502", dn="rbxassetid://653718790", ft="rbxassetid://653719067", lf="rbxassetid://653719190", rt="rbxassetid://653718931", up="rbxassetid://653719321"},
                Stylized = {bk="rbxassetid://18351376859", dn="rbxassetid://18351374919", ft="rbxassetid://18351376800", lf="rbxassetid://18351376469", rt="rbxassetid://18351376457", up="rbxassetid://18351377189"},
            }
            local d = SkyData[v]
            if d then
                sky.SkyboxBk = d.bk
                sky.SkyboxDn = d.dn
                sky.SkyboxFt = d.ft
                sky.SkyboxLf = d.lf
                sky.SkyboxRt = d.rt
                sky.SkyboxUp = d.up
            end
        end
    end,
})

VisGroup:AddToggle("SkyboxToggle", {
    Text = "スカイボックス適用",
    Default = false,
    Callback = function(v)
        VisState.SkyboxEnabled = v
        M.SkyboxEnabled = v
        if v then
            -- 適用
            local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky", Lighting)
            sky.Name = "shouyuSky"
        else
            local sky = Lighting:FindFirstChild("shouyuSky")
            if sky then sky:Destroy() end
        end
        notify("shouyuhub", v and "スカイボックス ON" or "OFF", 2)
    end,
})

-- ====================================================================
-- 4. 星雲エフェクト
-- ====================================================================
VisGroup:AddToggle("Nebula", {
    Text = "星雲エフェクト",
    Default = false,
    Callback = function(v)
        VisState.Nebula = v
        M.Nebula = v
        if v then
            local bl = Lighting:FindFirstChild("shouyuNebulaBloom") or Instance.new("BloomEffect", Lighting)
            bl.Name = "shouyuNebulaBloom"
            bl.Intensity = 0.7
            bl.Size = 24
            bl.Threshold = 1

            local cc = Lighting:FindFirstChild("shouyuNebulaCC") or Instance.new("ColorCorrectionEffect", Lighting)
            cc.Name = "shouyuNebulaCC"
            cc.Saturation = 0.5
            cc.Contrast = 0.2
            cc.TintColor = Color3.fromRGB(173, 216, 230)

            local atm = Lighting:FindFirstChild("shouyuNebulaAtm") or Instance.new("Atmosphere", Lighting)
            atm.Name = "shouyuNebulaAtm"
            atm.Density = 0.4
            atm.Offset = 0.25
            atm.Glare = 1
            atm.Haze = 2
            atm.Color = Color3.fromRGB(173, 216, 230)
            atm.Decay = Color3.fromRGB(120, 150, 200)

            Lighting.FogStart = 100
            Lighting.FogEnd = 500
            Lighting.FogColor = Color3.fromRGB(173, 216, 230)
        else
            local bl = Lighting:FindFirstChild("shouyuNebulaBloom"); if bl then bl:Destroy() end
            local cc = Lighting:FindFirstChild("shouyuNebulaCC"); if cc then cc:Destroy() end
            local atm = Lighting:FindFirstChild("shouyuNebulaAtm"); if atm then atm:Destroy() end
            Lighting.FogStart = origLight.FogStart
            Lighting.FogEnd = origLight.FogEnd
        end
        notify("shouyuhub", v and "星雲エフェクト ON" or "OFF", 2)
    end,
})

-- ====================================================================
-- 5. 帽子
-- ====================================================================
local hatInstances = {}

local function removeHat()
    for _, h in pairs(hatInstances) do
        pcall(function() h:Destroy() end)
    end
    hatInstances = {}
end

local function addHat()
    local c = LP.Character
    if not c then return end
    local head = c:FindFirstChild("Head")
    if not head then return end
    removeHat()

    local hat = Instance.new("Part")
    hat.Name = "shouyuHat"
    hat.Size = Vector3.new(2, 2, 2)
    hat.Material = Enum.Material.Neon
    hat.Color = Color3.fromRGB(0, 255, 255)
    hat.Transparency = 0.3
    hat.CanCollide = false
    hat.CanTouch = false
    hat.CanQuery = false
    hat.Massless = true

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshId = "rbxassetid://1033714"
    mesh.Scale = Vector3.new(2.4, 1.6, 2.4)
    mesh.Parent = hat

    local w = Instance.new("WeldConstraint")
    w.Part0 = head
    w.Part1 = hat
    w.Parent = hat

    hat.CFrame = head.CFrame * CFrame.new(0, 1.1, 0)
    hat.Parent = c
    table.insert(hatInstances, hat)
end

VisGroup:AddToggle("Hat", {
    Text = "帽子",
    Default = false,
    Callback = function(v)
        VisState.HatEnabled = v
        M.Hat = v
        if v then addHat() else removeHat() end
    end,
})

VisGroup:AddToggle("HatRainbow", {
    Text = "帽子レインボー",
    Default = false,
    Callback = function(v)
        VisState.HatRainbow = v
        M.HatRainbow = v
    end,
})

task.spawn(function()
    while task.wait(0.05) do
        if VisState.HatRainbow then
            local col = Color3.fromHSV((tick() % 5) / 5, 1, 1)
            for _, h in pairs(hatInstances) do
                if h and h.Parent then h.Color = col end
            end
        end
    end
end)

-- ====================================================================
-- 6. トレイル
-- ====================================================================
local trailInstances = {}

local function removeTrail()
    for _, t in pairs(trailInstances) do
        pcall(function() t:Destroy() end)
    end
    trailInstances = {}
    local c = LP.Character
    if c then
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if hrp then
            local a0 = hrp:FindFirstChild("shouyuAtt0"); if a0 then a0:Destroy() end
            local a1 = hrp:FindFirstChild("shouyuAtt1"); if a1 then a1:Destroy() end
        end
    end
end

local function addTrail()
    local c = LP.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    removeTrail()

    local a0 = Instance.new("Attachment")
    a0.Name = "shouyuAtt0"
    a0.Position = Vector3.new(0, 2, 0)
    a0.Parent = hrp

    local a1 = Instance.new("Attachment")
    a1.Name = "shouyuAtt1"
    a1.Position = Vector3.new(0, -2, 0)
    a1.Parent = hrp

    local tr = Instance.new("Trail")
    tr.Name = "shouyuTrail"
    tr.Attachment0 = a0
    tr.Attachment1 = a1
    tr.Lifetime = 0.5
    tr.LightEmission = 0.3
    tr.Color = ColorSequence.new(Color3.fromRGB(0, 255, 255))
    tr.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    tr.Parent = c
    table.insert(trailInstances, tr)
end

VisGroup:AddToggle("Trail", {
    Text = "トレイル",
    Default = false,
    Callback = function(v)
        VisState.TrailEnabled = v
        M.Trail = v
        if v then addTrail() else removeTrail() end
    end,
})

-- ====================================================================
-- 7. レインボー体
-- ====================================================================
local origColors = {}

VisGroup:AddToggle("RainbowBody", {
    Text = "レインボー体",
    Default = false,
    Callback = function(v)
        VisState.RainbowBody = v
        M.RainbowBody = v
        if v then
            local c = LP.Character
            if c then
                origColors = {}
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "shouyuHat" then
                        origColors[p] = {Color = p.Color, Material = p.Material}
                    end
                end
            end
        else
            for p, d in pairs(origColors) do
                if p and p.Parent then
                    p.Color = d.Color
                    p.Material = d.Material
                end
            end
            origColors = {}
        end
    end,
})

task.spawn(function()
    while task.wait(0.05) do
        if VisState.RainbowBody then
            local c = LP.Character
            if c then
                local hue = (tick() % 5) / 5
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "shouyuHat" then
                        p.Color = Color3.fromHSV(hue, 1, 1)
                        p.Material = Enum.Material.Neon
                    end
                end
            end
        end
    end
end)

-- ====================================================================
-- 8. ForceField
-- ====================================================================
local ffColors = {}

VisGroup:AddToggle("ForceField", {
    Text = "ForceField",
    Default = false,
    Callback = function(v)
        VisState.ForceFieldEnabled = v
        M.ForceField = v
        if v then
            local c = LP.Character
            if c then
                ffColors = {}
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "shouyuHat" then
                        ffColors[p] = {Color = p.Color, Material = p.Material}
                        p.Color = Color3.fromRGB(128, 128, 128)
                        p.Material = Enum.Material.ForceField
                    end
                end
            end
        else
            for p, d in pairs(ffColors) do
                if p and p.Parent then
                    p.Color = d.Color
                    p.Material = d.Material
                end
            end
            ffColors = {}
        end
    end,
})

VisGroup:AddToggle("ForceFieldRainbow", {
    Text = "ForceField レインボー",
    Default = false,
    Callback = function(v)
        VisState.ForceFieldRainbow = v
        M.ForceFieldRainbow = v
    end,
})

task.spawn(function()
    while task.wait(0.05) do
        if VisState.ForceFieldRainbow and VisState.ForceFieldEnabled then
            local col = Color3.fromHSV((tick() % 5) / 5, 1, 1)
            for p, _ in pairs(ffColors) do
                if p and p.Parent and p.Material == Enum.Material.ForceField then
                    p.Color = col
                end
            end
        end
    end
end)

-- ====================================================================
-- 9. パーティクルエフェクト
-- ====================================================================
local particleParts = {}

local function removeParticles()
    for _, p in pairs(particleParts) do
        pcall(function() p:Destroy() end)
    end
    particleParts = {}
end

local function addParticles()
    local c = LP.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    removeParticles()

    local holder = Instance.new("Part")
    holder.Name = "shouyuParticles"
    holder.Size = Vector3.new(1, 1, 1)
    holder.Transparency = 1
    holder.CanCollide = false
    holder.CanTouch = false
    holder.CanQuery = false
    holder.Massless = true
    holder.Parent = c
    table.insert(particleParts, holder)

    local att = Instance.new("Attachment")
    att.Parent = holder

    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxassetid://243098098"
    pe.Rate = 30
    pe.Lifetime = NumberRange.new(1, 2)
    pe.Speed = NumberRange.new(5, 10)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 0)
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(1, 1)
    })
    pe.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255))
    })
    pe.LightEmission = 1
    pe.Parent = att

    -- 位置同期
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not particleParts[1] or not particleParts[1].Parent then
            conn:Disconnect()
            return
        end
        local c2 = LP.Character
        local h2 = c2 and c2:FindFirstChild("HumanoidRootPart")
        if h2 and particleParts[1].Parent then
            particleParts[1].CFrame = h2.CFrame
        end
    end)
end

VisGroup:AddToggle("ParticleEffect", {
    Text = "パーティクルエフェクト",
    Default = false,
    Callback = function(v)
        VisState.ParticleEffect = v
        M.ParticleEffect = v
        if v then addParticles() else removeParticles() end
    end,
})

-- ====================================================================
-- 10. カスタムオーラ
-- ====================================================================
local auraModel = nil
local auraAttachments = {}

local function removeAura()
    for _, a in pairs(auraAttachments) do
        pcall(function() a:Destroy() end)
    end
    auraAttachments = {}
end

local function addAura()
    local c = LP.Character
    if not c then return end
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    removeAura()

    local att = Instance.new("Attachment")
    att.Parent = hrp

    local pe = Instance.new("ParticleEmitter")
    pe.Texture = "rbxassetid://" .. VisState.AuraID
    pe.Rate = 20
    pe.Lifetime = NumberRange.new(0.5, 1.5)
    pe.Speed = NumberRange.new(2, 5)
    pe.SpreadAngle = Vector2.new(180, 180)
    pe.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(1, 0)
    })
    pe.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1)
    })
    pe.Color = ColorSequence.new(Color3.fromRGB(255, 100, 255))
    pe.LightEmission = 1
    pe.Parent = att
    table.insert(auraAttachments, att)
    table.insert(auraAttachments, pe)
end

VisGroup:AddInput("AuraID", {
    Text = "オーラ アセットID",
    Default = "16699750981",
    Finished = true,
    Callback = function(v)
        if v and v ~= "" then
            VisState.AuraID = v
            if VisState.CustomAura then addAura() end
        end
    end,
})

VisGroup:AddToggle("CustomAura", {
    Text = "カスタムオーラ",
    Default = false,
    Callback = function(v)
        VisState.CustomAura = v
        M.CustomAura = v
        if v then addAura() else removeAura() end
    end,
})

-- ====================================================================
-- キャラ再スポーン時の再適用
-- ====================================================================
LP.CharacterAdded:Connect(function(char)
    task.wait(1.5)
    if VisState.HatEnabled then addHat() end
    if VisState.TrailEnabled then addTrail() end
    if VisState.ForceFieldEnabled then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "shouyuHat" then
                p.Color = Color3.fromRGB(128, 128, 128)
                p.Material = Enum.Material.ForceField
            end
        end
    end
    if VisState.ParticleEffect then addParticles() end
    if VisState.CustomAura then addAura() end
end)

-- ====================================================================
-- ====================================================================
-- 【ビジュアル 11〜20】
-- ESP / トレーサー / HPバー / ボックス / 名前 / 距離 /
-- レアリティカラー / FOV変更 / カメラ操作 / クリックエフェクト
-- ====================================================================

local VisGroup2 = TabVisual:AddRightGroupbox("ESP・表示系")

-- ====================================================================
-- 状態変数
-- ====================================================================
local VisState2 = {
    ESPEnabled = false,
    ESPName = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPBox = false,
    ESPTracer = false,
    ESPTeamCheck = true,
    ESPColor = "赤",
    ESPMaxDistance = 500,
    FOVEnabled = false,
    FOVValue = 70,
    CameraLocked = false,
    ClickEffect = false,
}

-- ====================================================================
-- ESP用GUI
-- ====================================================================
local espGui = Instance.new("ScreenGui")
espGui.Name = "shouyuESP"
espGui.ResetOnSpawn = false
pcall(function() espGui.Parent = (gethui and gethui()) or CG end)
if not espGui.Parent then espGui.Parent = LP:WaitForChild("PlayerGui") end

local espData = {}

-- ====================================================================
-- 色リスト
-- ====================================================================
local EspColors = {
    ["赤"] = Color3.fromRGB(255, 50, 50),
    ["緑"] = Color3.fromRGB(50, 255, 50),
    ["青"] = Color3.fromRGB(50, 150, 255),
    ["黄"] = Color3.fromRGB(255, 255, 50),
    ["紫"] = Color3.fromRGB(200, 50, 255),
    ["白"] = Color3.fromRGB(255, 255, 255),
    ["オレンジ"] = Color3.fromRGB(255, 150, 50),
    ["ピンク"] = Color3.fromRGB(255, 100, 200),
}

-- ====================================================================
-- 11. ESP本体
-- ====================================================================
VisGroup2:AddToggle("ESP", {
    Text = "プレイヤーESP",
    Default = false,
    Callback = function(v)
        VisState2.ESPEnabled = v
        M.ESP = v
        notify("shouyuhub", v and "ESP ON" or "OFF", 2)
    end,
})

-- ====================================================================
-- 12. 名前表示
-- ====================================================================
VisGroup2:AddToggle("ESPName", {
    Text = "ESP 名前表示",
    Default = true,
    Callback = function(v) VisState2.ESPName = v end,
})

-- ====================================================================
-- 13. 距離表示
-- ====================================================================
VisGroup2:AddToggle("ESPDistance", {
    Text = "ESP 距離表示",
    Default = true,
    Callback = function(v) VisState2.ESPDistance = v end,
})

-- ====================================================================
-- 14. HPバー
-- ====================================================================
VisGroup2:AddToggle("ESPHealth", {
    Text = "ESP HPバー",
    Default = true,
    Callback = function(v) VisState2.ESPHealth = v end,
})

-- ====================================================================
-- 15. ボックスESP
-- ====================================================================
VisGroup2:AddToggle("ESPBox", {
    Text = "ESP ボックス",
    Default = false,
    Callback = function(v) VisState2.ESPBox = v end,
})

-- ====================================================================
-- 16. トレーサー
-- ====================================================================
VisGroup2:AddToggle("ESPTracer", {
    Text = "ESP トレーサー",
    Default = false,
    Callback = function(v) VisState2.ESPTracer = v end,
})

-- ====================================================================
-- 17. チームチェック
-- ====================================================================
VisGroup2:AddToggle("ESPTeamCheck", {
    Text = "ESP チームチェック",
    Default = true,
    Callback = function(v) VisState2.ESPTeamCheck = v end,
})

-- ====================================================================
-- 18. ESP色
-- ====================================================================
local colorNames = {}
for k in pairs(EspColors) do table.insert(colorNames, k) end
table.sort(colorNames)

VisGroup2:AddDropdown("ESPColorDD", {
    Text = "ESP 色",
    Values = colorNames,
    Default = "赤",
    Callback = function(v) VisState2.ESPColor = v end,
})

-- ====================================================================
-- 19. 最大表示距離
-- ====================================================================
VisGroup2:AddSlider("ESPMaxDist", {
    Text = "ESP 最大距離",
    Default = 500,
    Min = 50,
    Max = 3000,
    Rounding = 0,
    Callback = function(v) VisState2.ESPMaxDistance = v end,
})

-- ====================================================================
-- ESP メインループ
-- ====================================================================
task.spawn(function()
    while task.wait(0.1) do
        if VisState2.ESPEnabled then
            local myRoot = getHRP()
            local cam = WS.CurrentCamera
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    local char = p.Character
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local head = char:FindFirstChild("Head")
                    local hum = char:FindFirstChildOfClass("Humanoid")

                    -- チームチェック
                    local skip = false
                    if VisState2.ESPTeamCheck and hum then
                        local myHum = getHum()
                        if myHum and hum.Team == myHum.Team then
                            skip = true
                        end
                    end

                    if not skip and hrp and hum and hum.Health > 0 and head and cam then
                        local dist = myRoot and (hrp.Position - myRoot.Position).Magnitude or 0
                        if dist <= VisState2.ESPMaxDistance then
                            if not espData[p] then
                                -- Highlight
                                local hl = Instance.new("Highlight")
                                hl.Name = "shouyuESP"
                                hl.FillColor = EspColors[VisState2.ESPColor] or Color3.fromRGB(255, 50, 50)
                                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                                hl.FillTransparency = 0.6
                                hl.OutlineTransparency = 0
                                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                hl.Adornee = char
                                hl.Parent = char

                                -- Billboard
                                local bb = Instance.new("BillboardGui")
                                bb.Name = "shouyuESPBillboard"
                                bb.Size = UDim2.new(0, 200, 0, 60)
                                bb.StudsOffset = Vector3.new(0, 3.5, 0)
                                bb.AlwaysOnTop = true
                                bb.Adornee = head
                                bb.Parent = head

                                local nameLbl = Instance.new("TextLabel")
                                nameLbl.Name = "ESPName"
                                nameLbl.Size = UDim2.new(1, 0, 0, 20)
                                nameLbl.BackgroundTransparency = 1
                                nameLbl.Text = p.DisplayName .. " (@" .. p.Name .. ")"
                                nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                                nameLbl.TextStrokeTransparency = 0
                                nameLbl.Font = Enum.Font.GothamBold
                                nameLbl.TextSize = 14
                                nameLbl.Parent = bb

                                local distLbl = Instance.new("TextLabel")
                                distLbl.Name = "ESPDist"
                                distLbl.Size = UDim2.new(1, 0, 0, 16)
                                distLbl.Position = UDim2.new(0, 0, 0, 20)
                                distLbl.BackgroundTransparency = 1
                                distLbl.Text = "0 studs"
                                distLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
                                distLbl.TextStrokeTransparency = 0
                                distLbl.Font = Enum.Font.Gotham
                                distLbl.TextSize = 12
                                distLbl.Parent = bb

                                local hpBg = Instance.new("Frame")
                                hpBg.Name = "ESPHpBg"
                                hpBg.Size = UDim2.new(0.8, 0, 0, 4)
                                hpBg.Position = UDim2.new(0.1, 0, 0, 38)
                                hpBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                                hpBg.BorderSizePixel = 0
                                hpBg.Parent = bb

                                local hpFill = Instance.new("Frame")
                                hpFill.Name = "ESPHpFill"
                                hpFill.Size = UDim2.new(1, 0, 1, 0)
                                hpFill.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
                                hpFill.BorderSizePixel = 0
                                hpFill.Parent = hpBg

                                -- Tracer (Line)
                                local tracer = Instance.new("Frame")
                                tracer.Name = "shouyuTracer"
                                tracer.BackgroundColor3 = EspColors[VisState2.ESPColor] or Color3.fromRGB(255, 50, 50)
                                tracer.BorderSizePixel = 0
                                tracer.Parent = espGui

                                espData[p] = {
                                    hl = hl,
                                    bb = bb,
                                    nameLbl = nameLbl,
                                    distLbl = distLbl,
                                    hpBg = hpBg,
                                    hpFill = hpFill,
                                    tracer = tracer,
                                }
                            end

                            local d = espData[p]
                            if d then
                                -- 色更新
                                if d.hl then d.hl.FillColor = EspColors[VisState2.ESPColor] or Color3.fromRGB(255, 50, 50) end
                                -- 名前
                                if d.nameLbl then d.nameLbl.Visible = VisState2.ESPName end
                                -- 距離
                                if d.distLbl then
                                    d.distLbl.Visible = VisState2.ESPDistance
                                    d.distLbl.Text = math.floor(dist) .. " studs"
                                end
                                -- HP
                                if d.hpBg then
                                    d.hpBg.Visible = VisState2.ESPHealth
                                    if hum and hum.MaxHealth > 0 then
                                        d.hpFill.Size = UDim2.new(math.clamp(hum.Health / hum.MaxHealth, 0, 1), 0, 1, 0)
                                        local ratio = hum.Health / hum.MaxHealth
                                        d.hpFill.BackgroundColor3 = ratio > 0.5 and Color3.fromRGB(50, 255, 50)
                                            or ratio > 0.25 and Color3.fromRGB(255, 200, 50)
                                            or Color3.fromRGB(255, 50, 50)
                                    end
                                end

                                -- トレーサー
                                if d.tracer then
                                    if VisState2.ESPTracer and cam then
                                        local screenPos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                                        if onScreen then
                                            local screenW = cam.ViewportSize.X
                                            local screenH = cam.ViewportSize.Y
                                            local fromX = screenW / 2
                                            local fromY = screenH
                                            local toX = screenPos.X
                                            local toY = screenPos.Y
                                            local dx = toX - fromX
                                            local dy = toY - fromY
                                            local len = math.sqrt(dx * dx + dy * dy)
                                            local angle = math.deg(math.atan2(dy, dx))
                                            d.tracer.Visible = true
                                            d.tracer.Size = UDim2.new(0, len, 0, 1)
                                            d.tracer.Position = UDim2.new(0, fromX, 0, fromY)
                                            d.tracer.Rotation = angle
                                            d.tracer.BackgroundColor3 = EspColors[VisState2.ESPColor] or Color3.fromRGB(255, 50, 50)
                                        else
                                            d.tracer.Visible = false
                                        end
                                    else
                                        d.tracer.Visible = false
                                    end
                                end
                            end
                        else
                            -- 距離外は非表示
                            local d = espData[p]
                            if d then
                                if d.hl then d.hl.Enabled = false end
                                if d.bb then d.bb.Enabled = false end
                                if d.tracer then d.tracer.Visible = false end
                            end
                        end
                    else
                        -- 死亡 or 対象外
                        local d = espData[p]
                        if d then
                            if d.hl then d.hl.Enabled = false end
                            if d.bb then d.bb.Enabled = false end
                            if d.tracer then d.tracer.Visible = false end
                        end
                    end
                end
            end
        else
            -- 全削除
            for p, d in pairs(espData) do
                if d.hl then pcall(function() d.hl:Destroy() end) end
                if d.bb then pcall(function() d.bb:Destroy() end) end
                if d.tracer then pcall(function() d.tracer:Destroy() end) end
            end
            espData = {}
        end
    end
end)

-- プレイヤー退出時のクリーンアップ
Players.PlayerRemoving:Connect(function(p)
    if espData[p] then
        local d = espData[p]
        if d.hl then pcall(function() d.hl:Destroy() end) end
        if d.bb then pcall(function() d.bb:Destroy() end) end
        if d.tracer then pcall(function() d.tracer:Destroy() end) end
        espData[p] = nil
    end
end)

-- ====================================================================
-- 20. FOV変更
-- ====================================================================
VisGroup2:AddSlider("FOVSlider", {
    Text = "FOV値",
    Default = 70,
    Min = 40,
    Max = 120,
    Rounding = 0,
    Callback = function(v)
        VisState2.FOVValue = v
        if VisState2.FOVEnabled then
            local cam = WS.CurrentCamera
            if cam then cam.FieldOfView = v end
        end
    end,
})

VisGroup2:AddToggle("FOVToggle", {
    Text = "FOV変更",
    Default = false,
    Callback = function(v)
        VisState2.FOVEnabled = v
        local cam = WS.CurrentCamera
        if cam then
            cam.FieldOfView = v and VisState2.FOVValue or 70
        end
    end,
})

-- ====================================================================
-- カメラ操作
-- ====================================================================
local CamGroup = TabVisual:AddRightGroupbox("カメラ")

CamGroup:AddToggle("CameraLocked", {
    Text = "カメラ固定（First Person）",
    Default = false,
    Callback = function(v)
        VisState2.CameraLocked = v
        if v then
            LP.CameraMode = Enum.CameraMode.LockFirstPerson
        else
            LP.CameraMode = Enum.CameraMode.Classic
        end
    end,
})

CamGroup:AddSlider("MaxZoom", {
    Text = "最大ズーム距離",
    Default = 128,
    Min = 1,
    Max = 5000,
    Rounding = 0,
    Callback = function(v)
        LP.CameraMaxZoomDistance = v
    end,
})

-- ====================================================================
-- クリックエフェクト
-- ====================================================================
local clickParts = {}

CamGroup:AddToggle("ClickEffect", {
    Text = "クリックエフェクト",
    Default = false,
    Callback = function(v)
        VisState2.ClickEffect = v
        M.ClickEffect = v
    end,
})

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if VisState2.ClickEffect and input.UserInputType == Enum.UserInputType.MouseButton1 then
        local hrp = getHRP()
        if hrp then
            local ring = Instance.new("Part")
            ring.Name = "shouyuClick"
            ring.Shape = Enum.PartType.Cylinder
            ring.Size = Vector3.new(0.2, 2, 2)
            ring.CFrame = CFrame.new(hrp.Position + Vector3.new(0, 0.1, 0))
            ring.Anchored = true
            ring.CanCollide = false
            ring.CanTouch = false
            ring.CanQuery = false
            ring.Material = Enum.Material.Neon
            ring.Color = Color3.fromHSV(math.random(), 1, 1)
            ring.Transparency = 0.3
            ring.Parent = WS
            table.insert(clickParts, ring)

            local t0 = tick()
            local conn
            conn = RunService.Heartbeat:Connect(function()
                if tick() - t0 > 1 or not ring.Parent then
                    conn:Disconnect()
                    if ring.Parent then ring:Destroy() end
                    return
                end
                local s = 2 + (tick() - t0) * 15
                pcall(function()
                    ring.Size = Vector3.new(0.2, s, s)
                    ring.Transparency = 0.3 + (tick() - t0) * 0.7
                end)
            end)
        end
    end
end)

-- ====================================================================
-- キャラ再スポーン時の再適用
-- ====================================================================
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if VisState2.FOVEnabled then
        local cam = WS.CurrentCamera
        if cam then cam.FieldOfView = VisState2.FOVValue end
    end
end)

-- ====================================================================
-- Part 10 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 10 読み込み完了（ビジュアル 11〜20）", 3)

print("[shouyuhub FTAP] Part 10 起動完了 - ESP & 表示")

-- ====================================================================
-- 【ビジュアル 21〜30 + 特殊機能】
-- オブジェクトESP / 掴みハイライト / 足跡 / スピードライン /
-- ネームタグ / 体色変更 / モーションブラー / ピクセル化 /
-- ぼかし / 特殊グラブ系
-- ====================================================================

local VisGroup3 = TabVisual:AddLeftGroupbox("追加ビジュアル")

-- ====================================================================
-- 状態変数
-- ====================================================================
local VisState3 = {
    ObjectESP = false,
    GrabHighlight = false,
    Footprint = false,
    SpeedLines = false,
    NameTag = false,
    BodyColor = false,
    BodyColorValue = Color3.fromRGB(0, 255, 255),
    MotionBlur = false,
    Pixelate = false,
    BlurEffect = false,
}

-- ====================================================================
-- 21. オブジェクトESP（掴めるオブジェクト）
-- ====================================================================
local objEspInstances = {}

VisGroup3:AddToggle("ObjectESP", {
    Text = "オブジェクトESP（掴める物）",
    Default = false,
    Callback = function(v)
        VisState3.ObjectESP = v
        M.ObjectESP = v
    end,
})

task.spawn(function()
    while task.wait(1) do
        if VisState3.ObjectESP then
            for _, obj in ipairs(WS:GetDescendants()) do
                if obj:IsA("BasePart") then
                    local grab = obj:GetAttribute("Grabbable") or obj:GetAttribute("IsGrabbable")
                    if grab == true and not objEspInstances[obj] then
                        local hl = Instance.new("Highlight")
                        hl.Name = "shouyuObjESP"
                        hl.FillColor = Color3.fromRGB(255, 200, 0)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.5
                        hl.OutlineTransparency = 0
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Adornee = obj
                        hl.Parent = obj
                        objEspInstances[obj] = hl
                    end
                end
            end
        else
            for obj, hl in pairs(objEspInstances) do
                pcall(function() hl:Destroy() end)
            end
            objEspInstances = {}
        end
    end
end)

-- ====================================================================
-- 22. 掴み可能ハイライト
-- ====================================================================
VisGroup3:AddToggle("GrabHighlight", {
    Text = "掴み可能ハイライト",
    Default = false,
    Callback = function(v)
        VisState3.GrabHighlight = v
        M.GrabHighlight = v
    end,
})

task.spawn(function()
    while task.wait(0.5) do
        if VisState3.GrabHighlight then
            for _, obj in ipairs(WS:GetDescendants()) do
                if obj:IsA("Model") and (obj.Name:lower():find("toy") or obj:findFirstChild("HoldPart")) then
                    if not obj:FindFirstChild("shouyuGrabHL") then
                        local hl = Instance.new("Highlight")
                        hl.Name = "shouyuGrabHL"
                        hl.FillColor = Color3.fromRGB(0, 255, 200)
                        hl.OutlineColor = Color3.fromRGB(0, 255, 200)
                        hl.FillTransparency = 0.7
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.Adornee = obj
                        hl.Parent = obj
                    end
                end
            end
        else
            for _, obj in ipairs(WS:GetDescendants()) do
                if obj:IsA("Model") then
                    local hl = obj:FindFirstChild("shouyuGrabHL")
                    if hl then hl:Destroy() end
                end
            end
        end
    end
end)

-- ====================================================================
-- 23. 足跡
-- ====================================================================
local footprints = {}

VisGroup3:AddToggle("Footprint", {
    Text = "足跡",
    Default = false,
    Callback = function(v)
        VisState3.Footprint = v
        M.Footprint = v
    end,
})

task.spawn(function()
    local lastPos = nil
    while task.wait(0.15) do
        if VisState3.Footprint then
            local hrp = getHRP()
            if hrp then
                if not lastPos or (hrp.Position - lastPos).Magnitude > 2 then
                    lastPos = hrp.Position
                    local fp = Instance.new("Part")
                    fp.Name = "shouyuFootprint"
                    fp.Shape = Enum.PartType.Cylinder
                    fp.Size = Vector3.new(0.05, 1, 1)
                    fp.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 2.5, 0))
                    fp.Anchored = true
                    fp.CanCollide = false
                    fp.CanTouch = false
                    fp.CanQuery = false
                    fp.Material = Enum.Material.Neon
                    fp.Color = Color3.fromHSV((tick() % 5) / 5, 1, 1)
                    fp.Transparency = 0.3
                    fp.Parent = WS
                    table.insert(footprints, fp)
                    Debris:AddItem(fp, 3)
                end
            end
        end
    end
end)

-- ====================================================================
-- 24. スピードライン
-- ====================================================================
local speedLines = {}

VisGroup3:AddToggle("SpeedLines", {
    Text = "スピードライン",
    Default = false,
    Callback = function(v)
        VisState3.SpeedLines = v
        M.SpeedLines = v
        if v then
            task.spawn(function()
                while VisState3.SpeedLines do
                    local hrp = getHRP()
                    if hrp and hrp.AssemblyLinearVelocity.Magnitude > 10 then
                        local line = Instance.new("Part")
                        line.Name = "shouyuSpeedLine"
                        line.Size = Vector3.new(0.1, 0.1, 5)
                        line.CFrame = hrp.CFrame * CFrame.new(
                            math.random(-3, 3), math.random(-3, 3), -5
                        )
                        line.Anchored = true
                        line.CanCollide = false
                        line.CanTouch = false
                        line.CanQuery = false
                        line.Material = Enum.Material.Neon
                        line.Color = Color3.fromRGB(255, 255, 255)
                        line.Transparency = 0.5
                        line.Parent = WS
                        Debris:AddItem(line, 0.3)
                    end
                    task.wait(0.05)
                end
            end)
        end
    end,
})

-- ====================================================================
-- 25. ネームタグ（頭上にカスタム名）
-- ====================================================================
local nameTagGui = nil

VisGroup3:AddInput("NameTagText", {
    Text = "ネームタグ内容",
    Default = "shouyuhub",
    Finished = true,
    Callback = function() end,
})

VisGroup3:AddToggle("NameTag", {
    Text = "ネームタグ（頭上）",
    Default = false,
    Callback = function(v)
        VisState3.NameTag = v
        M.NameTag = v
        if v then
            local c = LP.Character
            if c then
                local head = c:FindFirstChild("Head")
                if head then
                    if nameTagGui then nameTagGui:Destroy() end
                    nameTagGui = Instance.new("BillboardGui")
                    nameTagGui.Name = "shouyuNameTag"
                    nameTagGui.Size = UDim2.new(0, 150, 0, 30)
                    nameTagGui.StudsOffset = Vector3.new(0, 4, 0)
                    nameTagGui.AlwaysOnTop = true
                    nameTagGui.Adornee = head
                    nameTagGui.Parent = head
                    local lbl = Instance.new("TextLabel")
                    lbl.Name = "shouyuNameLabel"
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = "shouyuhub"
                    lbl.TextColor3 = Color3.fromRGB(0, 255, 255)
                    lbl.TextStrokeTransparency = 0
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextScaled = true
                    lbl.Parent = nameTagGui
                end
            end
        else
            if nameTagGui then nameTagGui:Destroy(); nameTagGui = nil end
        end
    end,
})

-- ====================================================================
-- 26. 体色変更
-- ====================================================================
local origBodyColors = {}

VisGroup3:AddToggle("BodyColor", {
    Text = "体色変更",
    Default = false,
    Callback = function(v)
        VisState3.BodyColor = v
        M.BodyColor = v
        if v then
            local c = LP.Character
            if c then
                origBodyColors = {}
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") and p.Name ~= "shouyuHat" then
                        origBodyColors[p] = p.Color
                        p.Color = VisState3.BodyColorValue
                    end
                end
            end
        else
            for p, col in pairs(origBodyColors) do
                if p and p.Parent then p.Color = col end
            end
            origBodyColors = {}
        end
    end,
})

-- ====================================================================
-- 27. モーションブラー
-- ====================================================================
VisGroup3:AddToggle("MotionBlur", {
    Text = "モーションブラー",
    Default = false,
    Callback = function(v)
        VisState3.MotionBlur = v
        M.MotionBlur = v
        if v then
            local blur = Lighting:FindFirstChild("shouyuMotionBlur") or Instance.new("BlurEffect", Lighting)
            blur.Name = "shouyuMotionBlur"
            blur.Size = 3
        else
            local blur = Lighting:FindFirstChild("shouyuMotionBlur")
            if blur then blur:Destroy() end
        end
    end,
})

-- ====================================================================
-- 28. ピクセル化
-- ====================================================================
VisGroup3:AddToggle("Pixelate", {
    Text = "ピクセル化",
    Default = false,
    Callback = function(v)
        VisState3.Pixelate = v
        M.Pixelate = v
        if v then
            local blur = Lighting:FindFirstChild("shouyuPixelate") or Instance.new("BlurEffect", Lighting)
            blur.Name = "shouyuPixelate"
            blur.Size = 10
        else
            local blur = Lighting:FindFirstChild("shouyuPixelate")
            if blur then blur:Destroy() end
        end
    end,
})

-- ====================================================================
-- 29. ぼかし
-- ====================================================================
VisGroup3:AddToggle("BlurEffect", {
    Text = "ぼかしエフェクト",
    Default = false,
    Callback = function(v)
        VisState3.BlurEffect = v
        M.BlurEffect = v
        if v then
            local blur = Lighting:FindFirstChild("shouyuBlur") or Instance.new("BlurEffect", Lighting)
            blur.Name = "shouyuBlur"
            blur.Size = 5
        else
            local blur = Lighting:FindFirstChild("shouyuBlur")
            if blur then blur:Destroy() end
        end
    end,
})

-- ====================================================================
-- 30. 色調補正
-- ====================================================================
VisGroup3:AddToggle("ColorCorrection", {
    Text = "色調補正",
    Default = false,
    Callback = function(v)
        M.ColorCorrection = v
        if v then
            local cc = Lighting:FindFirstChild("shouyuCC") or Instance.new("ColorCorrectionEffect", Lighting)
            cc.Name = "shouyuCC"
            cc.Saturation = 0.5
            cc.Contrast = 0.2
            cc.Brightness = 0.1
            cc.TintColor = Color3.fromRGB(200, 220, 255)
        else
            local cc = Lighting:FindFirstChild("shouyuCC")
            if cc then cc:Destroy() end
        end
    end,
})

-- ====================================================================
-- 【特殊機能】
-- ====================================================================
local SpecialGroup = TabSpecial:AddLeftGroupbox("特殊グラブ")

-- バリア貫通キック
SpecialGroup:AddButton({
    Text = "▶ バリア貫通キック（選択ターゲット）",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then
            notify("shouyuhub", "ターゲット未選択", 2)
            return
        end
        local trp = getRoot(t)
        if not trp then return end
        local hrp = getHRP()
        if not hrp then return end
        -- 相手を掴んでバリア越しに投げる
        setNet(trp)
        task.wait(0.05)
        trp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 5
        task.wait(0.1)
        velocity(trp, hrp.CFrame.LookVector * 3000 + Vector3.new(0, 300, 0))
        notify("shouyuhub", t.Name .. " を貫通キック", 2)
    end,
})

-- 3秒キック
local kick3Sec = {enabled = false, target = nil}
SpecialGroup:AddToggle("Kick3Sec", {
    Text = "3秒キック（掴んで3秒後射出）",
    Default = false,
    Callback = function(v)
        kick3Sec.enabled = v
        M.Kick3Sec = v
    end,
})

task.spawn(function()
    while task.wait(0.1) do
        if kick3Sec.enabled then
            local gp = WS:FindFirstChild("GrabParts")
            if gp then
                local grabPart = gp:FindFirstChild("GrabPart")
                if grabPart then
                    local wc = grabPart:FindFirstChild("WeldConstraint")
                    if wc and wc.Part1 then
                        local part1 = wc.Part1
                        if not kick3Sec.target or kick3Sec.target ~= part1 then
                            kick3Sec.target = part1
                            task.spawn(function()
                                task.wait(3)
                                if kick3Sec.enabled and part1.Parent then
                                    local root = part1.Parent:FindFirstChild("HumanoidRootPart") or part1
                                    setNet(root)
                                    velocity(root, Vector3.new(0, 5000, 0))
                                end
                                kick3Sec.target = nil
                            end)
                        end
                    end
                end
            end
        else
            kick3Sec.target = nil
        end
    end
end)

-- 投げる軌道予測
SpecialGroup:AddToggle("TrajectoryPredict", {
    Text = "投げる軌道予測",
    Default = false,
    Callback = function(v)
        M.TrajectoryPredict = v
    end,
})

local trajectoryParts = {}
task.spawn(function()
    while task.wait(0.1) do
        if M.TrajectoryPredict then
            local cam = WS.CurrentCamera
            local hrp = getHRP()
            if cam and hrp then
                local origin = hrp.Position
                local velocity = cam.CFrame.LookVector * 100
                for i = 1, 15 do
                    if not trajectoryParts[i] then
                        local p = Instance.new("Part")
                        p.Size = Vector3.new(0.3, 0.3, 0.3)
                        p.Shape = Enum.PartType.Ball
                        p.Material = Enum.Material.Neon
                        p.Color = Color3.fromRGB(255, 100, 0)
                        p.Anchored = true
                        p.CanCollide = false
                        p.CanTouch = false
                        p.CanQuery = false
                        p.Parent = WS
                        trajectoryParts[i] = p
                    end
                    local t = i * 0.1
                    local pos = origin + velocity * t + Vector3.new(0, -100 * t * t / 2, 0)
                    trajectoryParts[i].Position = pos
                end
            end
        else
            for _, p in pairs(trajectoryParts) do
                pcall(function() p:Destroy() end)
            end
            trajectoryParts = {}
        end
    end
end)

-- ====================================================================
-- 特殊グループ（右）
-- ====================================================================
local SpecialGroup2 = TabSpecial:AddRightGroupbox("特殊アクション")

-- 一括フリングオール
SpecialGroup2:AddButton({
    Text = "▶ 全員を上空へ一括発射",
    Func = function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local root = getRoot(plr)
                if root then
                    setNet(root)
                    velocity(root, Vector3.new(0, 8000, 0), 1)
                end
            end
        end
        notify("shouyuhub", "全員発射", 3)
    end,
})

SpecialGroup2:AddButton({
    Text = "▶ 全員を中央に引き寄せ",
    Func = function()
        local hrp = getHRP()
        if not hrp then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP and plr.Character then
                local root = getRoot(plr)
                if root then
                    setNet(root)
                    local dir = (hrp.Position - root.Position).Unit
                    velocity(root, dir * 5000, 0.5)
                end
            end
        end
        notify("shouyuhub", "全員引き寄せ", 3)
    end,
})

SpecialGroup2:AddButton({
    Text = "▶ 選択ターゲットを自分に固定",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        local trp = getRoot(t)
        local hrp = getHRP()
        if trp and hrp then
            setNet(trp)
            bodyPos(trp, hrp.Position + hrp.CFrame.LookVector * 5, 1e8)
            notify("shouyuhub", t.Name .. " を固定", 2)
        end
    end,
})

-- ====================================================================
-- キャラ再スポーン時の再適用
-- ====================================================================
LP.CharacterAdded:Connect(function()
    task.wait(1)
    if VisState3.NameTag and nameTagGui then
        nameTagGui:Destroy()
        nameTagGui = nil
    end
end)

-- ====================================================================
-- Part 11 完了通知
-- ====================================================================
notify("shouyuhub FTAP", "Part 11 読み込み完了（ビジュアル 21〜30 + 特殊）", 3)

print("[shouyuhub FTAP] Part 11 起動完了 - 追加ビジュアル & 特殊")

-- ====================================================================
-- 【ターゲット選択タブ】
-- ====================================================================

local TargetGroup = TabTarget:AddLeftGroupbox("プレイヤー選択")

-- ====================================================================
-- メインのターゲットドロップダウン
-- ====================================================================
local MainTargetDD
MainTargetDD = TargetGroup:AddDropdown("MainTargetDD", {
    Text = "ターゲットを選択",
    Values = getPlayerList(),
    Default = nil,
    Callback = function(v)
        TargetState.Player = getPlayerFromString(v)
        TargetState.Name = TargetState.Player and TargetState.Player.Name or nil
        if TargetState.Player then
            notify("shouyuhub", "ターゲット: " .. TargetState.Player.Name, 2)
        end
    end,
})

TargetGroup:AddButton({
    Text = "リスト更新",
    Func = function()
        if MainTargetDD and MainTargetDD.SetValues then
            MainTargetDD:SetValues(getPlayerList())
        end
    end,
})

-- ====================================================================
-- 自動更新
-- ====================================================================
Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    if MainTargetDD and MainTargetDD.SetValues then
        MainTargetDD:SetValues(getPlayerList())
    end
end)

Players.PlayerRemoving:Connect(function(p)
    task.wait(0.5)
    if MainTargetDD and MainTargetDD.SetValues then
        MainTargetDD:SetValues(getPlayerList())
    end
    if TargetState.Player == p then
        TargetState.Player = nil
        TargetState.Name = nil
    end
end)

-- ====================================================================
-- ターゲット一括操作
-- ====================================================================
local TargetActionGroup = TabTarget:AddRightGroupbox("ターゲット一括操作")

TargetActionGroup:AddButton({
    Text = "▶ ターゲット情報取得",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then
            notify("shouyuhub", "ターゲット未選択", 2)
            return
        end
        local hrp = getRoot(t)
        local myhrp = getHRP()
        if hrp and myhrp then
            local dist = (hrp.Position - myhrp.Position).Magnitude
            notify("shouyuhub", t.Name .. " | 距離: " .. math.floor(dist) .. " studs", 3)
        end
    end,
})

TargetActionGroup:AddButton({
    Text = "▶ ターゲットへTP",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        local hrp = getHRP()
        local trp = getRoot(t)
        if hrp and trp then
            hrp.CFrame = trp.CFrame * CFrame.new(0, 0, 5)
        end
    end,
})

TargetActionGroup:AddButton({
    Text = "▶ ターゲットを自分へTP",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        local hrp = getHRP()
        local trp = getRoot(t)
        if hrp and trp then
            setNet(trp)
            task.wait(0.05)
            trp.CFrame = hrp.CFrame + hrp.CFrame.LookVector * 3
        end
    end,
})

TargetActionGroup:AddButton({
    Text = "▶ ターゲットを奈落へ",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        local trp = getRoot(t)
        if trp then
            setNet(trp)
            task.wait(0.05)
            velocity(trp, Vector3.new(0, -10000, 0), 1)
            notify("shouyuhub", t.Name .. " を奈落へ", 2)
        end
    end,
})

TargetActionGroup:AddButton({
    Text = "▶ ターゲットを上空へ",
    Func = function()
        local t = TargetState.Player
        if not t or not t.Character then return end
        local trp = getRoot(t)
        if trp then
            setNet(trp)
            task.wait(0.05)
            velocity(trp, Vector3.new(0, 10000, 0), 1)
            notify("shouyuhub", t.Name .. " を上空へ", 2)
        end
    end,
})

-- ====================================================================
-- ターゲット監視・追跡
-- ====================================================================
local autoFollowTarget = false
TargetActionGroup:AddToggle("AutoFollow", {
    Text = "自動追跡（選択ターゲット）",
    Default = false,
    Callback = function(v)
        autoFollowTarget = v
        if v then
            task.spawn(function()
                while autoFollowTarget do
                    local t = TargetState.Player
                    if t and t.Character then
                        local hrp = getHRP()
                        local trp = getRoot(t)
                        if hrp and trp then
                            hrp.CFrame = trp.CFrame * CFrame.new(0, 0, 6)
                        end
                    end
                    task.wait(0.1)
                end
            end)
        end
    end,
})

-- ====================================================================
-- 【キーバインドタブ】
-- ====================================================================
local KeyGroup = TabSetting:AddLeftGroupbox("キーバインド")

-- ====================================================================
-- 主要機能のキーバインド
-- ====================================================================
KeyGroup:AddKeybind("KeyFling", {
    Text = "選択ターゲットをフリング",
    Default = "F",
    Callback = function()
        local t = TargetState.Player
        if t and t.Character then
            local root = getRoot(t)
            if root then
                setNet(root)
                velocity(root, Vector3.new(
                    math.random(-100, 100),
                    math.random(50, 100),
                    math.random(-100, 100)
                ).Unit * 500)
            end
        end
    end,
})

KeyGroup:AddKeybind("KeyTP", {
    Text = "マウス位置へTP",
    Default = "X",
    Callback = function()
        local hrp = getHRP()
        if hrp and mouse.Hit then
            hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
        end
    end,
})

KeyGroup:AddKeybind("KeyKill", {
    Text = "選択ターゲットをキル",
    Default = "K",
    Callback = function()
        local t = TargetState.Player
        if t and t.Character then
            local hum = t.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.Health = 0 end
        end
    end,
})

KeyGroup:AddKeybind("KeyReset", {
    Text = "キャラリセット",
    Default = "R",
    Callback = function()
        local c = LP.Character
        if c then
            local h = c:FindFirstChildOfClass("Humanoid")
            if h then h.Health = 0 end
        end
    end,
})

KeyGroup:AddKeybind("KeyNoclip", {
    Text = "ノークリップ切替",
    Default = "N",
    Callback = function()
        MoveState.Noclip = not MoveState.Noclip
        M.Noclip = MoveState.Noclip
        notify("shouyuhub", MoveState.Noclip and "ノークリップ ON" or "OFF", 2)
    end,
})

KeyGroup:AddKeybind("KeyFly", {
    Text = "フライ切替",
    Default = "V",
    Callback = function()
        MoveState.FlyEnabled = not MoveState.FlyEnabled
        M.FlyEnabled = MoveState.FlyEnabled
        if MoveState.FlyEnabled then
            startFly()
        else
            stopFly()
        end
        notify("shouyuhub", MoveState.FlyEnabled and "フライ ON" or "OFF", 2)
    end,
})

-- ====================================================================
-- 【設定タブ】
-- ====================================================================
local SetGroup = TabSetting:AddRightGroupbox("UI設定")

SetGroup:AddButton({
    Text = "▶ UIを開く",
    Func = function() Library:Open() end,
})

SetGroup:AddButton({
    Text = "▶ UIを閉じる",
    Func = function() Library:Close() end,
})

SetGroup:AddButton({
    Text = "▶ 設定をリセット",
    Func = function()
        getgenv().FTAP_Mem = {}
        notify("shouyuhub", "設定をリセットしました（リロード推奨）", 3)
    end,
})

SetGroup:AddButton({
    Text = "▶ 再読み込み",
    Func = function()
        notify("shouyuhub", "再読み込み中...", 2)
        task.wait(0.5)
        loadstring(game:HttpGet("https://raw.githubusercontent.com/shouyu356-alt/shouyu.script/main/ftap.lua"))()
    end,
})

-- ====================================================================
-- 情報表示
-- ====================================================================
local InfoGroup = TabSetting:AddRightGroupbox("情報")

InfoGroup:AddParagraph({
    Title = "shouyuhub FTAP ULTRA",
    Content = "Version: 1.0.0\nKeyless | Mobile/PC 対応\n\n機能数: 100+\n\nDeveloper: shouyuhub",
})

-- ====================================================================
-- メモリ管理 / 定期処理
-- ====================================================================
task.spawn(function()
    while task.wait(60) do
        pcall(function() collectgarbage("collect") end)
    end
end)

-- ====================================================================
-- 安全リセット（UI再表示）
-- ====================================================================
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    -- Shift + R でUI再表示
    if input.KeyCode == Enum.KeyCode.R and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
        pcall(function() Library:Open() end)
    end
end)

-- ====================================================================
-- キャラクター再スポーン時のマスター処理
-- ====================================================================
LP.CharacterAdded:Connect(function(char)
    task.wait(1.5)
    -- 各パートの再適用は既に実装済み
end)

-- ====================================================================
-- 起動完了メッセージ
-- ====================================================================
Library:Notify({
    Title = "shouyuhub FTAP",
    Content = "✅ 全12パート 読み込み完了！",
    Duration = 6,
})

task.wait(1)
Library:Notify({
    Title = "shouyuhub FTAP",
    Content = "総機能数: 100+ | 全タブ有効化済み",
    Duration = 5,
})

print("==========================================================")
print("[shouyuhub FTAP ULTRA] 完全起動")
print("==========================================================")
print("【タブ一覧】")
print("  1. 掴み          - 通常/スーパー/キル/ポイズン/ファイア/放射能/アンチ/オブジェクト/複数/レンジ")
print("  2. 飛ばし        - ドロップ/スピン/ウォーク/オーラ/全員/カスタム威力")
print("  3. 移動          - フライ/ノークリップ/スピード/ジャンプ/無限ジャンプ/TP各種")
print("  4. 戦闘          - SilentAim/Aimbot/Triggerbot/Hitbox/FOV/弾道予測/ノックバック無効")
print("  5. 防御          - ラグドール/ノックバック/フリング/ボイド/キック/テレポート/爆発/燃焼/スティッキー/デコイ/Gucci/PCLD/位置固定/自動脱出")
print("  6. ビジュアル    - Fullbright/時間停止/スカイボックス/星雲/帽子/トレイル/レインボー/ForceField/パーティクル/オーラ/ESP/トレーサー/HPバー/ボックス/オブジェクトESP/足跡/スピードライン/ネームタグ/モーションブラー/ピクセル化/ぼかし/色調補正")
print("  7. 特殊          - バリア貫通キック/3秒キック/軌道予測/一括発射/引き寄せ")
print("  8. ターゲット    - プレイヤー選択/情報/TP/追跡/各種フリング")
print("  9. 設定          - キーバインド/UI開閉/リセット/再読み込み")
print("==========================================================")
print("GitHub: shouyu356-alt/shouyu.script")
print("==========================================================")

-- ====================================================================
-- スクリプト終端
-- ===============================================================
