-- shouyuhub | Fling Tools Unified UI
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()

local Window = Library:CreateWindow({
    Title = "shouyuhub",
    Footer = "Fling Tools",
    Center = true,
    AutoShow = true,
    ShowMobileButtons = false,
})

local BASE = "https://raw.githubusercontent.com/shouyu356-alt/shouyuhub/main/"
local opened = {}

local function closeAll()
    for _, g in ipairs(opened) do
        pcall(function() if g and g.Parent then g:Destroy() end end)
    end
    opened = {}
    pcall(function()
        local core = (gethui and gethui()) or game:GetService("CoreGui")
        for _, c in ipairs(core:GetChildren()) do
            if c:IsA("ScreenGui") and (c.Name:find("Orion") or c.Name:find("Orbit") or c.Name:find("AKI") or c.Name:find("XOCU")) then
                table.insert(opened, c)
            end
        end
    end)
end

local function Run(name, file)
    closeAll()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(BASE .. file))()
    end)
    Library:Notify({ Title = "shouyuhub", Content = ok and ("起動: "..name) or ("失敗: "..tostring(err)), Duration = 3 })
end

-- ============================================
-- XOCO
-- ============================================
local T1 = Window:AddTab({ Name = "XOCO" })
T1:AddButton({ Name = "▶ XOCO 起動", Func = function() Run("XOCO", "XOCO%20Script%20crack.txt") end })
T1:AddParagraph({ Title = "XOCO Hub", Content = "Anti / Kick / Grab / Aura / Visuals / Black Hole 多数" })

-- ============================================
-- Drift Kick
-- ============================================
local T2 = Window:AddTab({ Name = "Drift Kick" })
T2:AddButton({ Name = "▶ Drift Kick 起動", Func = function() Run("Drift", "%E3%83%89%E3%83%AA%E3%83%95%E3%83%88%E3%82%AD%E3%83%83%E3%82%AF.txt") end })
T2:AddParagraph({ Title = "Drift Kick", Content = "Blobmanで周回しながら対象を飛ばす" })

-- ============================================
-- Aki Hub
-- ============================================
local T3 = Window:AddTab({ Name = "Aki Hub" })
T3:AddButton({ Name = "▶ Aki Hub 起動", Func = function() Run("Aki", "Akihub%E6%9C%80%E5%BC%B72.2-1.txt") end })
T3:AddParagraph({ Title = "Aki Hub", Content = "線香花火 / 羽 / 渦巻き / サイレントエイム / オーラ" })

-- ============================================
-- 6秒キック
-- ============================================
local T4 = Window:AddTab({ Name = "6秒キック" })
T4:AddButton({ Name = "▶ 6秒キック 起動", Func = function() Run("6秒", "6%E7%A7%92%E3%82%AD%E3%83%83%E3%82%AF-1.txt") end })
T4:AddParagraph({ Title = "6秒キック", Content = "Blobmanでターゲットをキック" })

-- ============================================
-- Kill all
-- ============================================
local T5 = Window:AddTab({ Name = "Kill all" })
T5:AddButton({ Name = "▶ Kill all 起動", Func = function() Run("KillAll", "Kill%20all-2.txt") end })
T5:AddParagraph({ Title = "Kill all", Content = "全プレイヤーキル系" })

-- ============================================
-- Mynxx
-- ============================================
local T6 = Window:AddTab({ Name = "Mynxx" })
T6:AddButton({ Name = "▶ Mynxx 起動", Func = function() Run("Mynxx", "Mynxx%20(1).txt") end })

-- ============================================
-- ハーレシーフリー
-- ============================================
local T7 = Window:AddTab({ Name = "ハーレシー" })
T7:AddButton({ Name = "▶ ハーレシーフリー 起動", Func = function() Run("ハーレシー", "%E3%83%8F%E3%83%BC%E3%83%AC%E3%82%B7%E3%83%BC%E3%83%95%E3%83%AA%E3%83%BC.txt") end })

Library:Notify({ Title = "shouyuhub", Content = "読み込み完了！", Duration = 4 })
