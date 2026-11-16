-- ============================================================
-- SHOUYU HUB — STEAL AN EGG (PART 1/3)
-- ============================================================

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local LocalPlayer = Players.LocalPlayer
local RS = ReplicatedStorage
local Terrain = Workspace:FindFirstChildOfClass("Terrain")

-- ============================================================
-- 設定 & 状態管理
-- ============================================================
local CFG = {
    Version = "v2.0.0",
    AutoSteal = false,
    AutoPlant = true,
    FastMode = true,
    SkipPvP = true,
    TPMinDist = 80,
    AntiRagdoll = true,
    AntiTrap = true,
    AntiDeath = true,
    Potato = false,
    WalkSpeed = 200,
}

local EggState, PlotState, AreaEggSlotIdentity, Mutations, AssetEarnings
local Networking, AssetsDir
local GuardAreas

task.spawn(function()
    local Packages = RS:WaitForChild("Packages", 15)
    Networking = Packages and Packages:WaitForChild("Networking", 10)
    
    EggState = require(RS.Client.EggState)
    PlotState = require(RS.Client.PlotState)
    AreaEggSlotIdentity = require(RS.Shared.Util.AreaEggSlotIdentity)
    Mutations = require(RS.Shared.Modules.Mutations)
    AssetEarnings = require(RS.Shared.Util.AssetEarnings)
    local assets = require(RS.Data.Assets)
    AssetsDir = assets.Directory
    
    local objects = Workspace:WaitForChild("__OBJECTS", 10)
    local areas = objects and objects:WaitForChild("Areas", 10)
    GuardAreas = areas and areas:WaitForChild("GuardAreas", 10)
end)

-- ============================================================
-- Shouyu Hub UI (完全自作 / シアンテーマ)
-- ============================================================
local C = {
    BG        = Color3.fromRGB(12, 16, 20),
    Sidebar   = Color3.fromRGB(18, 24, 30),
    Card      = Color3.fromRGB(24, 32, 40),
    Line      = Color3.fromRGB(42, 54, 66),
    Accent    = Color3.fromRGB(34, 211, 238),
    Accent2   = Color3.fromRGB(56, 189, 248),
    Green     = Color3.fromRGB(74, 222, 128),
    Red       = Color3.fromRGB(239, 68, 68),
    Orange    = Color3.fromRGB(251, 146, 60),
    Text      = Color3.fromRGB(235, 245, 250),
    Sub       = Color3.fromRGB(140, 158, 175),
    White     = Color3.new(1, 1, 1),
}

local function New(class, props, children)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do if k ~= "Parent" then inst[k] = v end end
    for _, c in ipairs(children or {}) do c.Parent = inst end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function Round(p, px) return New("UICorner", {CornerRadius = UDim.new(0, px), Parent = p}) end
local function Stroke(p, c, t, tr) return New("UIStroke", {Color = c, Thickness = t or 1, Transparency = tr or 0, Parent = p}) end

local parent = (gethui and gethui()) or CoreGui or LocalPlayer:WaitForChild("PlayerGui")
for _, n in ipairs({"ShouyuHub_UI", "ShouyuHub_Toast"}) do
    local old = parent:FindFirstChild(n)
    if old then old:Destroy() end
end

local Gui = New("ScreenGui", {Name = "ShouyuHub_UI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999999})
pcall(function() Gui.Parent = parent end)
if not Gui.Parent then Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local ToastGui = New("ScreenGui", {Name = "ShouyuHub_Toast", ResetOnSpawn = false, DisplayOrder = 999998})
pcall(function() ToastGui.Parent = parent end)
if not ToastGui.Parent then ToastGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

local BASE_W, BASE_H = 580, 400
local Main = New("Frame", {Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0, BASE_W, 0, BASE_H), Position = UDim2.new(0.5, 0, 0.5, 0), BackgroundColor3 = C.BG, BorderSizePixel = 0, ClipsDescendants = true, Parent = Gui})
Round(Main, 16)
local MainScale = New("UIScale", {Scale = 1, Parent = Main})
Stroke(Main, C.Accent, 1.4, 0.25)

local function updateScale()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local s = math.clamp(math.min((cam.ViewportSize.X - 40)/BASE_W, (cam.ViewportSize.Y - 40)/BASE_H), 0.5, 1.0)
    TweenService:Create(MainScale, TweenInfo.new(0.2), {Scale = s}):Play()
end
updateScale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)

-- ドラッグ機能
local dragging, dragStart, startPos
Main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = Main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

-- ヘッダー
local Header = New("Frame", {Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.Sidebar, BorderSizePixel = 0, Parent = Main})
Round(Header, 16)
New("Frame", {Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -18), BackgroundColor3 = C.Sidebar, BorderSizePixel = 0, Parent = Header})
New("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(24, 34, 44), Color3.fromRGB(18, 24, 30)), Rotation = 90, Parent = Header})
local AccentBar = New("Frame", {Size = UDim2.new(0, 4, 0, 20), Position = UDim2.new(0, 16, 0.5, -10), BackgroundColor3 = C.Accent, Parent = Header})
Round(AccentBar, 2)
New("UIGradient", {Color = ColorSequence.new(C.Accent, C.Accent2), Rotation = 90, Parent = AccentBar})

New("TextLabel", {Size = UDim2.new(0, 260, 0, 18), Position = UDim2.new(0, 28, 0, 8), BackgroundTransparency = 1, Text = "SHOUYU HUB", TextColor3 = C.Text, TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = Header})
New("TextLabel", {Size = UDim2.new(0, 260, 0, 12), Position = UDim2.new(0, 28, 0, 26), BackgroundTransparency = 1, Text = "Steal An Egg · " .. CFG.Version, TextColor3 = C.Accent, TextSize = 9, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left, Parent = Header})

local StatusDot = New("Frame", {Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(1, -118, 0.5, -4), BackgroundColor3 = C.Green, Parent = Header})
Round(StatusDot, 4)
RunService.RenderStepped:Connect(function() StatusDot.BackgroundTransparency = 0.4 + math.sin(tick() * 3) * 0.3 end)
New("TextLabel", {Size = UDim2.new(0, 60, 0, 12), Position = UDim2.new(1, -106, 0.5, -6), BackgroundTransparency = 1, Text = "READY", TextColor3 = C.Green, TextSize = 8, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = Header})

local CloseBtn = New("TextButton", {Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -34, 0.5, -13), BackgroundColor3 = C.Card, Text = "X", TextColor3 = C.Sub, TextSize = 12, Font = Enum.Font.GothamBold, AutoButtonColor = false, Parent = Header})
Round(CloseBtn, 8)
CloseBtn.MouseButton1Click:Connect(function() Gui:Destroy(); ToastGui:Destroy() end)

-- サイドバー & コンテンツ
local Sidebar = New("Frame", {Size = UDim2.new(0, 140, 1, -46), Position = UDim2.new(0, 0, 0, 46), BackgroundColor3 = C.Sidebar, BorderSizePixel = 0, Parent = Main})
New("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundColor3 = C.Line, BorderSizePixel = 0, Parent = Sidebar})
New("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Sidebar})
New("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = Sidebar})

local Content = New("Frame", {Size = UDim2.new(1, -144, 1, -46), Position = UDim2.new(0, 140, 0, 46), BackgroundTransparency = 1, Parent = Main})
New("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8), Parent = Content})

local tabs, pages, activeTab = {}, {}, nil
local function SelectTab(id)
    for tid, page in pairs(pages) do page.Visible = (tid == id) end
    for tid, btn in pairs(tabs) do
        local on = (tid == id)
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = on and C.Card or C.Sidebar}):Play()
        for _, ch in ipairs(btn:GetChildren()) do
            if ch:IsA("TextLabel") then TweenService:Create(ch, TweenInfo.new(0.15), {TextColor3 = on and C.Text or C.Sub}):Play() end
        end
    end
    activeTab = id
end

local function AddTab(id, icon, label)
    local btn = New("TextButton", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.Sidebar, Text = "", AutoButtonColor = false, LayoutOrder = #tabs + 1, Parent = Sidebar})
    Round(btn, 8)
    New("Frame", {Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 2, 0.5, -9), BackgroundColor3 = C.Accent, BackgroundTransparency = 1, Parent = btn})
    New("TextLabel", {Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = icon, TextColor3 = C.Sub, TextSize = 14, Parent = btn})
    New("TextLabel", {Size = UDim2.new(1, -44, 1, 0), Position = UDim2.new(0, 38, 0, 0), BackgroundTransparency = 1, Text = label, TextColor3 = C.Sub, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = btn})
    local page = New("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = Content})
    tabs[id] = btn; pages[id] = page
    btn.MouseButton1Click:Connect(function() SelectTab(id) end)
    if not activeTab then SelectTab(id) end
    return page
end

-- ログ & トースト
local LogLines, LogBox
local function Log(msg, col)
    col = col or C.Sub
    table.insert(LogLines, 1, {t = os.date("%H:%M:%S"), m = tostring(msg), c = col})
    if #LogLines > 50 then table.remove(LogLines) end
    if LogBox then
        for _, ch in ipairs(LogBox:GetChildren()) do if ch:IsA("TextLabel") then ch:Destroy() end end
        local y = 4
        for i, L in ipairs(LogLines) do
            if i > 12 then break end
            New("TextLabel", {Size = UDim2.new(1, -8, 0, 14), Position = UDim2.new(0, 4, 0, y), BackgroundTransparency = 1, Text = "["..L.t.."] "..L.m, TextColor3 = L.c, TextSize = 9, Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = LogBox})
            y = y + 14
        end
    end
    print("[SHOUYU] " .. msg)
end

local function Toast(text, color)
    local old = ToastGui:FindFirstChild("T")
    if old then old:Destroy() end
    local t = New("Frame", {Name = "T", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 280, 0, 36), Position = UDim2.new(0.5, 0, 0, -60), BackgroundColor3 = C.Card, Parent = ToastGui})
    Round(t, 10); Stroke(t, color or C.Accent, 1.2)
    New("TextLabel", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = text, TextColor3 = C.Text, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, Parent = t})
    TweenService:Create(t, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0, 20)}):Play()
    task.delay(2.4, function()
        if t and t.Parent then
            local tw = TweenService:Create(t, TweenInfo.new(0.25), {Position = UDim2.new(0.5, 0, 0, -60)})
            tw.Completed:Connect(function() t:Destroy() end); tw:Play()
        end
    end)
end

-- ============================================================
-- 基本モジュール (Anti-Lag / Anti-Ragdoll / Anti-Trap / Discバイパス)
-- ============================================================
task.spawn(function() -- Anti-Lag / Potato
    local applied = setmetatable({}, {__mode = "k"})
    local function isProtected(inst)
        local char = LocalPlayer.Character
        return (char and inst:IsDescendantOf(char)) or (LocalPlayer:FindFirstChild("Backpack") and inst:IsDescendantOf(LocalPlayer.Backpack))
    end
    local function applyLag()
        pcall(function()
            if settings and settings().Rendering then settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end
            Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9
            for _, e in ipairs(Lighting:GetChildren()) do if e:IsA("PostEffect") or e:IsA("Atmosphere") or e:IsA("Sky") then e:Destroy() end end
        end)
        if Terrain then pcall(function() Terrain.WaterWaveSize = 0; Terrain.WaterTransparency = 1 end) end
    end
    local function strip(obj)
        if applied[obj] or isProtected(obj) then return end
        pcall(function()
            if obj:IsA("BasePart") then obj.Material = Enum.Material.SmoothPlastic; obj.CastShadow = false
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Highlight") then obj.Enabled = false; obj:Destroy() end
            applied[obj] = true
        end)
    end
    applyLag()
    for _, d in ipairs(Workspace:GetDescendants()) do strip(d) end
    Workspace.DescendantAdded:Connect(strip)
    while true do task.wait(1) pcall(applyLag) end
end)

task.spawn(function() -- Anti-Ragdoll
    local loopConn
    local function setup(char)
        if not char then return end
        if loopConn then loopConn:Disconnect() end
        local hum = char:WaitForChild("Humanoid", 5)
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if not hum or not hrp then return end
        for _, st in ipairs({Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.PlatformStanding, Enum.HumanoidStateType.Physics}) do
            pcall(function() hum:SetStateEnabled(st, false) end)
        end
        local motors = {}
        for _, d in ipairs(char:GetDescendants()) do if d:IsA("Motor6D") then motors[d] = true; d.Enabled = true end end
        char.DescendantAdded:Connect(function(d) if d:IsA("Motor6D") then motors[d] = true; d.Enabled = true end end)
        loopConn = RunService.Stepped:Connect(function()
            if not CFG.AntiRagdoll then return end
            if not char.Parent or not hum.Parent then loopConn:Disconnect() return end
            if hum.PlatformStand then hum.PlatformStand = false end
            if hum.Sit then hum.Sit = false end
            for m in pairs(motors) do if m.Parent and not m.Enabled then m.Enabled = true end end
            local st = hum:GetState()
            if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.Physics then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end)
    end
    if LocalPlayer.Character then setup(LocalPlayer.Character) end
    LocalPlayer.CharacterAdded:Connect(setup)
end)

task.spawn(function() -- Anti-Trap
    local kws = {"trap","mine","turret","spike"}
    Workspace.DescendantAdded:Connect(function(inst)
        if not CFG.AntiTrap then return end
        pcall(function()
            local name = inst.Name:lower()
            for _, k in ipairs(kws) do
                if name:find(k, 1, true) then
                    if inst:IsA("BasePart") then inst.CanTouch = false; inst.CanCollide = false end
                    break
                end
            end
        end)
    end)
end)

task.spawn(function() -- ProximityPrompt即時化 & Discバイパス
    local function optimizePrompt(p)
        if p:IsA("ProximityPrompt") then p.HoldDuration = 0; p.RequiresLineOfSight = false end
    end
    for _, d in ipairs(Workspace:GetDescendants()) do optimizePrompt(d) end
    Workspace.DescendantAdded:Connect(optimizePrompt)
    ProximityPromptService.PromptButtonHoldBegan:Connect(function(p) if fireproximityprompt then pcall(function() fireproximityprompt(p, 0) end) end end)
    
    -- Discバイパス
    local function click(btn) if firesignal then pcall(function() firesignal(btn.MouseButton1Click) end) end end
    local roots = {CoreGui, LocalPlayer:FindFirstChild("PlayerGui")}
    for _, r in ipairs(roots) do
        if r then
            r.DescendantAdded:Connect(function(inst)
                if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text then
                    if inst.Text:find("CONTINUE TO HUB",1,true) or inst.Text:find("JOIN OUR DISCORD",1,true) then
                        local top = inst
                        while top.Parent and not top.Parent:IsA("ScreenGui") and top.Parent ~= game do top = top.Parent end
                        if top and top:IsA("GuiObject") then
                            top.Visible = false
                            for _, ch in ipairs(top:GetDescendants()) do
                                if (ch:IsA("TextButton")) and ch.Text:find("CONTINUE TO HUB",1,true) then
                                    task.spawn(function() for i=1,5 do click(ch) task.wait(0.1) end end)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)-- ============================================================
-- SHOUYU HUB — STEAL AN EGG (PART 2/3)
-- コアロジック：卵スキャン・価値計算・自動移動・キャリー
-- ※ このコードはPART 1のすぐ下に続けて貼り付けてください
-- ============================================================

local stolenUids = {}
local eggCache = {}
local eggCacheAt = 0
local EGG_CACHE_TTL = 3

local function getHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- 卵の価値計算 (CRZHubロジック)
local function calcEggValue(rec)
    local item = {
        Category = rec.AssetCategory,
        Scale = tonumber(rec.AssetScale) or 1,
        Mutations = rec.Mutations or {},
    }
    if AssetEarnings then
        local ok, rate = pcall(AssetEarnings.LiveRatePerSecond, item, nil, nil, LocalPlayer)
        if ok and type(rate) == "number" then return rate end
    end
    local dir = AssetsDir and AssetsDir[rec.AssetCategory]
    if not dir then return 0 end
    local baseRate = tonumber(dir.EarningRate) or 0
    local scale = item.Scale
    local scaleFactor = scale <= 5 and scale ^ 1.85 or (scale / 5) ^ 1.2 * 19.63
    local mutMult = 1
    if Mutations then pcall(function() mutMult = Mutations.EarningsFor(item.Mutations) end) end
    return math.max(1, math.round(baseRate * scaleFactor * (tonumber(mutMult) or 1)))
end

local function getEggName(rec)
    local dir = AssetsDir and AssetsDir[rec.AssetCategory]
    return dir and dir.DisplayName or rec.AssetCategory
end

-- 卵のスナップショット取得
local function snapshotEggs(force)
    local now = os.clock()
    if not force and #eggCache > 0 and (now - eggCacheAt) < EGG_CACHE_TTL then
        return eggCache
    end

    local records = {}
    local data
    pcall(function()
        data = EggState and EggState.ReadFieldEggs and EggState.ReadFieldEggs()
    end)
    
    if type(data) == "table" and type(data.Records) == "table" then
        for _, rec in ipairs(data.Records) do
            if type(rec) == "table" and rec.Uid then
                table.insert(records, rec)
            end
        end
    end

    -- 古いstolenUidsのクリーンアップ
    local nowTick = tick()
    for uid, at in pairs(stolenUids) do
        if (nowTick - at) > 120 then stolenUids[uid] = nil end
    end

    local eggs = {}
    for _, rec in ipairs(records) do
        local grabbable = (rec.State == "Slot" or rec.State == "Dropped")
        local visible = grabbable or rec.State == "GuardCarried"

        if stolenUids[rec.Uid] and grabbable then
            stolenUids[rec.Uid] = nil
        end

        if rec.Uid and rec.BoundsCFrame and typeof(rec.BoundsCFrame) == "CFrame" and visible and not stolenUids[rec.Uid] then
            table.insert(eggs, {
                uid = rec.Uid,
                state = rec.State,
                grabbable = grabbable,
                pet = rec.AssetCategory,
                name = getEggName(rec),
                area = rec.AreaId,
                value = calcEggValue(rec),
                position = rec.BoundsCFrame.Position,
                record = rec,
            })
        end
    end

    -- 価値順にソート
    table.sort(eggs, function(a, b) return a.value > b.value end)
    eggCache = eggs
    eggCacheAt = now
    return eggs
end

-- 移動・テレポート (簡易版)
local function teleportTo(pos)
    local char = LocalPlayer.Character
    if not char or not pos then return false end
    local targetCF = CFrame.new(pos + Vector3.new(0, 5, 0))
    pcall(function() char:PivotTo(targetCF) end)
    task.wait(0.15)
    return true
end

local function walkTo(pos, timeout)
    local hum = getHumanoid()
    local hrp = getHRP()
    if not hum or not hrp then return false end
    timeout = timeout or 5
    local t0 = os.clock()
    hum:MoveTo(pos)
    while os.clock() - t0 < timeout do
        local h = getHRP()
        if not h then return false end
        if (h.Position - pos).Magnitude < 8 then return true end
        task.wait(0.1)
    end
    return false
end

-- 卵をキャリーする
local function carryEgg(uid, areaId, nestId)
    if not EggState or not EggState.CarryFieldEgg then return false end
    local slotKey = AreaEggSlotIdentity and AreaEggSlotIdentity.SlotKey and AreaEggSlotIdentity.SlotKey(areaId, nestId) or nil
    
    local ok, res = pcall(function() return EggState.CarryFieldEgg(uid, slotKey) end)
    if ok and res == true then return true end
    
    -- プロンプトを探して発火
    local hrp = getHRP()
    if hrp then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                local part = d:FindFirstAncestorOfClass("BasePart") or d.Parent
                if part and part:IsA("BasePart") then
                    if (hrp.Position - part.Position).Magnitude < 15 then
                        if fireproximityprompt then pcall(function() fireproximityprompt(d, 0) end) end
                        task.wait(0.2)
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- 卵をプロットに植える
local function plantEgg(uid)
    if not EggState or not EggState.PlantEgg or not PlotState then return false end
    local plot
    local okP = pcall(function() plot = PlotState.ResolvePlot() end)
    if not okP or type(plot) ~= "table" or not plot.PetArea then return false end
    
    local area = plot.PetArea
    local localCF = CFrame.new(0, area.Size.Y * 0.5, 0) -- 簡易配置
    local ok, a = pcall(function() return EggState.PlantEgg(uid, localCF) end)
    return ok and a == true
end

-- ============================================================
-- メイン自動盗みループ
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.5)
        if not CFG.AutoSteal then continue end
        if not EggState or not PlotState then continue end
        
        local hrp = getHRP()
        if not hrp then continue end
        
        pcall(function()
            local eggs = snapshotEggs()
            if #eggs == 0 then return end
            
            local target = eggs[1] -- 価値が一番高い卵
            
            -- ターゲットに近づく
            if (target.position - hrp.Position).Magnitude > CFG.TPMinDist and CFG.TPEnabled then
                teleportTo(target.position)
                Log("TP: " .. target.name, C.Accent)
            else
                walkTo(target.position, 5)
            end
            
            -- キャリー
            local carried = carryEgg(target.uid, target.area, target.record.NestId)
            if carried then
                Log("盗み成功: " .. target.name, C.Green)
                stolenUids[target.uid] = tick()
                
                -- プロットに帰還
                if CFG.AutoPlant then
                    local plot = PlotState.ResolvePlot()
                    if plot and plot.RespawnPointCFrame then
                        teleportTo(plot.RespawnPointCFrame.Position)
                        task.wait(0.5)
                        plantEgg(target.uid)
                        Log("設置完了: " .. target.name, C.Green)
                    end
                end
            else
                Log("盗み失敗: " .. target.name, C.Red)
            end
        end)
    end
end)

-- ============================================================
-- UI タブ構築
-- ============================================================
local pageFarm = AddTab("farm", "🎣", "FARM")
local yF = 0

-- セクションとウィジェット生成用の関数
local function Section(parent, y, text)
    New("TextLabel", {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 4, 0, y), BackgroundTransparency = 1, Text = text, TextColor3 = C.Accent, TextSize = 9, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent})
    New("Frame", {Size = UDim2.new(1, -100, 0, 1), Position = UDim2.new(0, 100, 0, y + 7), BackgroundColor3 = C.Line, Parent = parent})
    return y + 22
end

local function Toggle(parent, y, label, desc, default, cb)
    local row = New("Frame", {Size = UDim2.new(1, -4, 0, 42), Position = UDim2.new(0, 2, 0, y), BackgroundColor3 = C.Card, Parent = parent})
    Round(row, 8); Stroke(row, C.Line, 1, 0.5)
    New("TextLabel", {Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 10, 0, 6), BackgroundTransparency = 1, Text = label, TextColor3 = C.Text, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, Parent = row})
    if desc then New("TextLabel", {Size = UDim2.new(1, -60, 0, 14), Position = UDim2.new(0, 10, 0, 22), BackgroundTransparency = 1, Text = desc, TextColor3 = C.Sub, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Left, Parent = row}) end
    local btn = New("TextButton", {Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, -46, 0.5, -9), BackgroundColor3 = default and C.Accent or Color3.fromRGB(36, 46, 56), Text = "", AutoButtonColor = false, Parent = row})
    Round(btn, 9)
    local knob = New("Frame", {Size = UDim2.new(0, 14, 0, 14), Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = C.White, Parent = btn})
    Round(knob, 7)
    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = state and C.Accent or Color3.fromRGB(36, 46, 56)}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
        if cb then pcall(cb, state) end
    end)
    return y + 46
end

local function Button(parent, y, label, color, cb)
    local btn = New("TextButton", {Size = UDim2.new(1, -4, 0, 36), Position = UDim2.new(0, 2, 0, y), BackgroundColor3 = color, Text = label, TextColor3 = C.White, TextSize = 11, Font = Enum.Font.GothamBold, AutoButtonColor = false, Parent = parent})
    Round(btn, 8)
    btn.MouseButton1Click:Connect(function() if cb then pcall(cb) end end)
    return y + 40
end

yF = Section(pageFarm, yF, "自動化設定")
yF = Toggle(pageFarm, yF, "自動盗み", "近傍の卵を自動で盗む", CFG.AutoSteal, function(v) CFG.AutoSteal = v end)
yF = Toggle(pageFarm, yF, "自動設置", "持ち帰った卵を自動で設置", CFG.AutoPlant, function(v) CFG.AutoPlant = v end)
yF = Toggle(pageFarm, yF, "テレポート使用", "遠距離の卵へTPする", CFG.TPEnabled, function(v) CFG.TPEnabled = v end)

yF = Section(pageFarm, yF, "クイックアクション")
yF = Button(pageFarm, yF, "手動スキャン", C.Accent2, function()
    local eggs = snapshotEggs(true)
    Log("スキャン完了: " .. #eggs .. "個の卵を検知", C.Accent)
    if #eggs > 0 then
        Toast("一番高い卵: " .. eggs[1].name, C.Green)
    end
end)
yF = Button(pageFarm, yF, "プロットへ帰還", C.Green, function()
    if PlotState then
        local plot = PlotState.ResolvePlot()
        if plot and plot.RespawnPointCFrame then
            teleportTo(plot.RespawnPointCFrame.Position)
            Log("帰還しました", C.Green)
        end
    end
end)-- ============================================================
-- SHOUYU HUB — STEAL AN EGG (PART 3/3)
-- セーフティ・設定・ログ・初期化
-- ※ このコードはPART 2のすぐ下に続けて貼り付けてください
-- ============================================================

-- 念のためCFGの欠損を補完
CFG.AntiLag = true

-- ============================================================
-- セーフティタブ
-- ============================================================
local pageSafe = AddTab("safe", "🛡", "SAFE")
local yS = 0

yS = Section(pageSafe, yS, "アンチ検出")
yS = Toggle(pageSafe, yS, "Anti-Ragdoll", "ダウン状態を強制解除", CFG.AntiRagdoll, function(v) CFG.AntiRagdoll = v end)
yS = Toggle(pageSafe, yS, "Anti-Trap", "トラップ/地雷を無効化", CFG.AntiTrap, function(v) CFG.AntiTrap = v end)
yS = Toggle(pageSafe, yS, "Anti-Death", "死亡を無効化", CFG.AntiDeath, function(v) CFG.AntiDeath = v end)

yS = Section(pageSafe, yS, "パフォーマンス")
yS = Toggle(pageSafe, yS, "Anti-Lag / FPS Boost", "描画を最低限に削ってFPS向上", true, function(v)
    CFG.AntiLag = v
    if not v then
        Log("Anti-Lag: OFF (再起動で完全復帰)", C.Orange)
    else
        Log("Anti-Lag: ON", C.Green)
    end
end)

-- ============================================================
-- 設定・情報タブ
-- ============================================================
local pageInfo = AddTab("info", "⚙", "INFO")
local yI = 0

yI = Section(pageInfo, yI, "ステータス")
local infoBox = New("Frame", {Size = UDim2.new(1, -4, 0, 140), Position = UDim2.new(0, 2, 0, yI), BackgroundColor3 = C.Card, Parent = pageInfo})
Round(infoBox, 8); Stroke(infoBox, C.Line, 1, 0.5)
New("TextLabel", {
    Size = UDim2.new(1, -20, 1, -16), Position = UDim2.new(0, 10, 0, 8),
    BackgroundTransparency = 1, RichText = true, TextColor3 = C.Sub, TextSize = 9, Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    Text = "<b><font color='#22D3EE'>SHOUYU HUB "..CFG.Version.."</font></b>\n"
        .."────────────────────\n"
        .."Executor: "..tostring(identifyexecutor and identifyexecutor() or "不明").."\n"
        .."EggState: "..tostring(EggState ~= nil).."\n"
        .."PlotState: "..tostring(PlotState ~= nil).."\n"
        .."Networking: "..tostring(Networking ~= nil).."\n"
        .."GuardAreas: "..tostring(GuardAreas ~= nil).."\n"
        .."Players: "..#Players:GetPlayers(),
    Parent = infoBox
})
yI = yI + 148

yI = Button(pageInfo, yI, "UIを閉じる", C.Red, function()
    Gui:Destroy(); ToastGui:Destroy()
end)

-- ============================================================
-- ログパネル (右下配置)
-- ============================================================
local LogPanel = New("Frame", {
    Size = UDim2.new(0, 240, 0, 120), Position = UDim2.new(1, -252, 1, -132),
    BackgroundColor3 = Color3.fromRGB(8, 12, 16), BorderSizePixel = 0, Parent = Content
})
Round(LogPanel, 10); Stroke(LogPanel, C.Line, 1, 0.4)
New("TextLabel", {
    Size = UDim2.new(1, -16, 0, 14), Position = UDim2.new(0, 8, 0, 4),
    BackgroundTransparency = 1, Text = "📋 LOG",
    TextColor3 = C.Accent, TextSize = 9, Font = Enum.Font.GothamBlack,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = LogPanel
})
LogBox = New("Frame", {
    Size = UDim2.new(1, -8, 1, -24), Position = UDim2.new(0, 4, 0, 20),
    BackgroundTransparency = 1, Parent = LogPanel
})

-- ============================================================
-- 初期化 & 起動ログ
-- ============================================================
Log("SHOUYU HUB "..CFG.Version.." 起動", C.Accent)
Log("EggState: "..tostring(EggState ~= nil), EggState and C.Green or C.Red)
Log("PlotState: "..tostring(PlotState ~= nil), PlotState and C.Green or C.Red)
Log("Anti-Lag / FPS Boost: 稼働中", C.Green)
Log("Bキーで手動吸い取り可能", C.Sub)

Toast("🎣 SHOUYU HUB 起動完了", C.Accent)

-- 起動直後にテレポート用の安全確認
task.spawn(function()
    task.wait(3)
    if PlotState then
        local ok, plot = pcall(function() return PlotState.ResolvePlot() end)
        if ok and plot then
            Log("プロット検出完了。準備万端。", C.Green)
        else
            Log("プロット未検出。ゲームロードを待機中...", C.Orange)
        end
    end
end)
