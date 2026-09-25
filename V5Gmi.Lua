-- ============================================
-- By Boomxico | Modern Dark Crimson UI (v2.5 Fixed)
-- Main Menu + Player List + Dedicated Attach Menu
-- Added: Anti-Deact Protection, Full Name Tags, Auto ESP
-- ============================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

local camera    = Workspace.CurrentCamera

local isPC     = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
local isMobile = UserInputService.TouchEnabled

-- ===================== State =====================
local speedEnabled, flyEnabled, noclipEnabled = false, false, false
local infJumpEnabled, espEnabled, nameEnabled = false, false, false
local fullbrightEnabled, noFogEnabled         = false, false

local runSpeed, flySpeed = 50, 50
local bodyVel, bodyGyro
local scriptAlive = true

local dirs   = {F=false, B=false, L=false, R=false, U=false, D=false}
local pcKeys = {W=false, A=false, S=false, D=false, Space=false, Shift=false}

-- Spectate & Attach System
local spectateTarget, spectateEnabled = nil, false
local attachTarget, attachEnabled     = nil, false
local attachDistance = 3
local sliderMinDist, sliderMaxDist = 0, 50

local MAX_SPEED, MAX_FLY = 200, 300
local TOGGLE_COOLDOWN    = 0.35
local lastToggleTime     = 0
local NAME_MAX_DIST      = 800

local espObjects, nameObjects, playerRows, connections = {}, {}, {}, {}
local noclipConn = nil

-- Lighting Originals
local originalLighting = {
    Brightness     = Lighting.Brightness,
    ClockTime      = Lighting.ClockTime,
    FogEnd         = Lighting.FogEnd,
    FogStart       = Lighting.FogStart,
    GlobalShadows  = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient        = Lighting.Ambient,
}

-- Keybinds
local keybinds = {
    Speed  = {key = Enum.KeyCode.Unknown, mode = "Toggle"},
    Fly    = {key = Enum.KeyCode.Unknown, mode = "Toggle"},
    Noclip = {key = Enum.KeyCode.Unknown, mode = "Toggle"},
}
local waitingForKey = nil

-- ===================== Theme Palette =====================
local COLOR_BG         = Color3.fromRGB(10, 10, 14)      -- Deep Black Translucent
local COLOR_CARD       = Color3.fromRGB(20, 20, 26)      -- Inner Container
local COLOR_BORDER     = Color3.fromRGB(220, 30, 40)     -- Vibrant Red Stroke
local COLOR_BORDER_DIM = Color3.fromRGB(60, 20, 25)      -- Subtle Crimson Line
local COLOR_TEXT       = Color3.fromRGB(245, 245, 250)    -- Bright Text
local COLOR_SUBTEXT    = Color3.fromRGB(140, 140, 150)    -- Muted Text
local COLOR_ACCENT     = Color3.fromRGB(235, 35, 45)     -- Primary Red Accent
local COLOR_ACTIVE     = Color3.fromRGB(190, 20, 30)     -- Active Toggle Red
local COLOR_OFF        = Color3.fromRGB(30, 30, 38)      -- Off State Dark Grey
local COLOR_KILL       = Color3.fromRGB(180, 25, 25)     -- Alert / Close Red

-- ===================== Helpers =====================
local function canToggle()
    local now = tick()
    if now - lastToggleTime < TOGGLE_COOLDOWN then return false end
    lastToggleTime = now
    return true
end

local function safeDestroy(obj)
    if obj and obj.Parent then
        pcall(function() obj:Destroy() end)
    end
end

local function addConn(conn)
    table.insert(connections, conn)
    return conn
end

local function applyStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or COLOR_BORDER
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.3
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

-- Update Character Elements on Respawn
local function onCharacterAdded(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
end
player.CharacterAdded:Connect(onCharacterAdded)

-- ===================== Fly System (FIXED) =====================
local function stopFly()
    flyEnabled = false
    if bodyVel then safeDestroy(bodyVel) bodyVel = nil end
    if bodyGyro then safeDestroy(bodyGyro) bodyGyro = nil end
    if humanoid then
        humanoid.PlatformStanding = false
    end
end

local function startFly()
    if not rootPart or not humanoid then return end
    flyEnabled = true

    humanoid.PlatformStanding = true

    if bodyVel then safeDestroy(bodyVel) end
    if bodyGyro then safeDestroy(bodyGyro) end

    bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVel.P = 12500
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = rootPart

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.P = 12500
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.Parent = rootPart
end

-- ===================== GUI Root =====================
local gui = Instance.new("ScreenGui")
gui.Name = "ByBoomMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- 📌 Floating Toggle Buttons
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 46, 0, 46)
toggleBtn.Position = UDim2.new(0, 20, 0, 120)
toggleBtn.BackgroundColor3 = COLOR_BG
toggleBtn.BackgroundTransparency = 0.15
toggleBtn.Text = "B"
toggleBtn.TextColor3 = COLOR_ACCENT
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 20
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.Parent = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 10)
applyStroke(toggleBtn, COLOR_BORDER, 1.2, 0.2)

local checkBtn = Instance.new("TextButton")
checkBtn.Size = UDim2.new(0, 46, 0, 46)
checkBtn.Position = UDim2.new(0, 20, 0, 175)
checkBtn.BackgroundColor3 = COLOR_BG
checkBtn.BackgroundTransparency = 0.15
checkBtn.Text = "P"
checkBtn.TextColor3 = COLOR_ACCENT
checkBtn.Font = Enum.Font.GothamBold
checkBtn.TextSize = 20
checkBtn.Active = true
checkBtn.Draggable = true
checkBtn.Parent = gui
Instance.new("UICorner", checkBtn).CornerRadius = UDim.new(0, 10)
applyStroke(checkBtn, COLOR_BORDER, 1.2, 0.2)

local attachMenuToggleBtn = Instance.new("TextButton")
attachMenuToggleBtn.Size = UDim2.new(0, 46, 0, 46)
attachMenuToggleBtn.Position = UDim2.new(0, 20, 0, 230)
attachMenuToggleBtn.BackgroundColor3 = COLOR_BG
attachMenuToggleBtn.BackgroundTransparency = 0.15
attachMenuToggleBtn.Text = "A"
attachMenuToggleBtn.TextColor3 = COLOR_ACCENT
attachMenuToggleBtn.Font = Enum.Font.GothamBold
attachMenuToggleBtn.TextSize = 20
attachMenuToggleBtn.Active = true
attachMenuToggleBtn.Draggable = true
attachMenuToggleBtn.Parent = gui
Instance.new("UICorner", attachMenuToggleBtn).CornerRadius = UDim.new(0, 10)
applyStroke(attachMenuToggleBtn, COLOR_BORDER, 1.2, 0.2)

-- ====================================================
-- 🔴 MAIN MENU
-- ====================================================
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 280, 0, 480)
main.Position = UDim2.new(0, 20, 0, 285)
main.BackgroundColor3 = COLOR_BG
main.BackgroundTransparency = 0.15
main.Active = true
main.Draggable = true
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
applyStroke(main, COLOR_BORDER, 1.2, 0.3)

local mainTopLine = Instance.new("Frame")
mainTopLine.Size = UDim2.new(1, 0, 0, 3)
mainTopLine.BackgroundColor3 = COLOR_ACCENT
mainTopLine.BorderSizePixel = 0
mainTopLine.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 12, 0, 3)
title.BackgroundTransparency = 1
title.Text = "BY BOOMXICO"
title.TextColor3 = COLOR_TEXT
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local mainScroll = Instance.new("ScrollingFrame")
mainScroll.Size = UDim2.new(1, -16, 1, -95)
mainScroll.Position = UDim2.new(0, 8, 0, 45)
mainScroll.BackgroundTransparency = 1
mainScroll.BorderSizePixel = 0
mainScroll.ScrollBarThickness = 3
mainScroll.ScrollBarImageColor3 = COLOR_ACCENT
mainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mainScroll.Parent = main

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 6)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = mainScroll

local function updateToggleUI(btn, enabled)
    btn.Text = enabled and "เปิด" or "ปิด"
    btn.BackgroundColor3 = enabled and COLOR_ACTIVE or COLOR_OFF
    btn.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or COLOR_SUBTEXT
end

local function mkToggle(labelText, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 36)
    card.BackgroundColor3 = COLOR_CARD
    card.BackgroundTransparency = 0.2
    card.Parent = mainScroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    applyStroke(card, COLOR_BORDER_DIM, 1, 0.6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, -10, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = COLOR_TEXT
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = card

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.3, 0, 0, 24)
    btn.Position = UDim2.new(0.68, 0, 0.5, -12)
    btn.BackgroundColor3 = COLOR_OFF
    btn.Text = "ปิด"
    btn.TextColor3 = COLOR_SUBTEXT
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = card
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local state = false
    btn.MouseButton1Click:Connect(function()
        if not canToggle() then return end
        state = not state
        updateToggleUI(btn, state)
        callback(state)
    end)

    return btn, card
end

local function mkRow(labelText, defaultVal, callback, toggleCallback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 36)
    card.BackgroundColor3 = COLOR_CARD
    card.BackgroundTransparency = 0.2
    card.Parent = mainScroll
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
    applyStroke(card, COLOR_BORDER_DIM, 1, 0.6)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.65, -10, 1, 0)
    btn.Position = UDim2.new(0, 10, 0, 0)
    btn.BackgroundTransparency = 1
    btn.Text = labelText .. ": ปิด"
    btn.TextColor3 = COLOR_TEXT
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = card

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.28, 0, 0, 24)
    box.Position = UDim2.new(0.68, 0, 0.5, -12)
    box.BackgroundColor3 = COLOR_OFF
    box.Text = defaultVal
    box.TextColor3 = COLOR_ACCENT
    box.Font = Enum.Font.GothamBold
    box.TextSize = 12
    box.ClearTextOnFocus = false
    box.Parent = card
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local state = false
    btn.MouseButton1Click:Connect(function()
        if not canToggle() then return end
        state = not state
        btn.Text = labelText .. (state and ": เปิด" or ": ปิด")
        btn.TextColor3 = state and COLOR_ACCENT or COLOR_TEXT
        toggleCallback(state)
    end)

    box.FocusLost:Connect(function()
        local val = tonumber(box.Text)
        if val then callback(val) end
    end)

    return btn, box
