-- ============================================
-- By Boomxico | Modern Dark Crimson UI (v2.5)
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

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

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

local function clamp(v, minV, maxV)
    return math.clamp(v, minV, maxV)
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

local function keyToString(key)
    if not key or key == Enum.KeyCode.Unknown then return "None" end
    return tostring(key):gsub("Enum.KeyCode.", "")
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

-- ===================== Anti-Deact Core Engine =====================
local function sanitizePhysics(part)
    if not part then return end
    pcall(function()
        part.Velocity = Vector3.zero
        part.RotVelocity = Vector3.zero
        if part:IsA("BasePart") then
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end)
end

local function applyAntiDeact(char)
    if not char or not char.Parent then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.Sit = false
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                p.CanCollide = false
            end
        end
    end)
end

local function guardFlyPhysics()
    if not flyEnabled or not character or not rootPart or not humanoid then return end
    
    pcall(function()
        humanoid.PlatformStanding = true
        humanoid.Sit = false
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

        if not bodyVel or not bodyVel.Parent or bodyVel.Parent ~= rootPart then
            if bodyVel then safeDestroy(bodyVel) end
            bodyVel = Instance.new("BodyVelocity")
            bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            bodyVel.P = 12500
            bodyVel.Velocity = Vector3.zero
            bodyVel.Parent = rootPart
        end

        if not bodyGyro or not bodyGyro.Parent or bodyGyro.Parent ~= rootPart then
            if bodyGyro then safeDestroy(bodyGyro) end
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            bodyGyro.P = 12500
            bodyGyro.CFrame = rootPart.CFrame
            bodyGyro.Parent = rootPart
        end

        rootPart.RotVelocity = Vector3.zero
        rootPart.AssemblyAngularVelocity = Vector3.zero
    end)
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

local subTitle = Instance.new("TextLabel")
subTitle.Size = UDim2.new(0, 60, 0, 40)
subTitle.Position = UDim2.new(1, -72, 0, 3)
subTitle.BackgroundTransparency = 1
subTitle.Text = "v2.5"
subTitle.TextColor3 = COLOR_ACCENT
subTitle.Font = Enum.Font.GothamBold
subTitle.TextSize = 12
subTitle.TextXAlignment = Enum.TextXAlignment.Right
subTitle.Parent = main

local mainScroll = Instance.new("ScrollingFrame")
mainScroll.Size = UDim2.new(1, -16, 1, -95)
mainScroll.Position = UDim2.new(0, 8, 0, 45)
mainScroll.BackgroundTransparency = 1
mainScroll.BorderSizePixel = 0
mainScroll.ScrollBarThickness = 3
mainScroll.ScrollBarImageColor3 = COLOR_ACCENT
mainScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
mainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mainScroll.Parent = main

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 6)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = mainScroll

local mainPad = Instance.new("UIPadding")
mainPad.PaddingTop = UDim.new(0, 2)
mainPad.PaddingBottom = UDim.new(0, 6)
mainPad.PaddingLeft = UDim.new(0, 4)
mainPad.PaddingRight = UDim.new(0, 6)
mainPad.Parent = mainScroll

local function mkToggle(labelText)
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
    applyStroke(btn, COLOR_BORDER_DIM, 1, 0.6)

    return btn, card
end

local function mkRow(labelText, defaultVal)
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
    applyStroke(box, COLOR_BORDER, 1, 0.4)

    return btn, box
end

-- Controls
local spdBtn, spdBox        = mkRow("วิ่งไว", "50")
local flyBtn, flyBox        = mkRow("บินได้", "50")
local noclipBtn             = mkToggle("Noclip")
local infJumpBtn            = mkToggle("Infinite Jump")
local fullbrightBtn         = mkToggle("Fullbright")
local noFogBtn              = mkToggle("No Fog")
local espBtn                = mkToggle("มองทะลุ (ESP)")
local nameBtn               = mkToggle("แสดงชื่อผู้เล่น")
local attachWindowBtn       = mkToggle("เมนูเกาะผู้เล่น (Attach)")

-- Distance Card
local distCard = Instance.new("Frame")
distCard.Size = UDim2.new(1, 0, 0, 36)
distCard.BackgroundColor3 = COLOR_CARD
distCard.BackgroundTransparency = 0.2
distCard.Parent = mainScroll
Instance.new("UICorner", distCard).CornerRadius = UDim.new(0, 8)
applyStroke(distCard, COLOR_BORDER_DIM, 1, 0.6)

local distLbl = Instance.new("TextLabel")
distLbl.Size = UDim2.new(0.65, -10, 1, 0)
distLbl.Position = UDim2.new(0, 10, 0, 0)
distLbl.BackgroundTransparency = 1
distLbl.Text = "ระยะแสดงชื่อ"
distLbl.TextColor3 = COLOR_TEXT
distLbl.Font = Enum.Font.GothamMedium
distLbl.TextSize = 12
distLbl.TextXAlignment = Enum.TextXAlignment.Left
distLbl.Parent = distCard

local distBox = Instance.new("TextBox")
distBox.Size = UDim2.new(0.28, 0, 0, 24)
distBox.Position = UDim2.new(0.68, 0, 0.5, -12)
distBox.BackgroundColor3 = COLOR_OFF
distBox.Text = "800"
distBox.TextColor3 = COLOR_ACCENT
distBox.Font = Enum.Font.GothamBold
distBox.TextSize = 12
distBox.ClearTextOnFocus = false
distBox.Parent = distCard
Instance.new("UICorner", distBox).CornerRadius = UDim.new(0, 6)
applyStroke(distBox, COLOR_BORDER, 1, 0.4)

local keybindMenuBtn = mkToggle("ตั้งค่า Keybinds (PC)")

local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0.45, 0, 0, 32)
killBtn.Position = UDim2.new(0.04, 0, 1, -40)
killBtn.BackgroundColor3 = COLOR_KILL
killBtn.BackgroundTransparency = 0.15
killBtn.Text = "Close Script"
killBtn.TextColor3 = COLOR_TEXT
killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = 12
killBtn.Parent = main
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.45, 0, 0, 32)
closeBtn.Position = UDim2.new(0.51, 0, 1, -40)
closeBtn.BackgroundColor3 = COLOR_CARD
closeBtn.BackgroundTransparency = 0.15
closeBtn.Text = "Fold"
closeBtn.TextColor3 = COLOR_TEXT
closeBtn.Font = Enum.Font.GothamMedium
closeBtn.TextSize = 12
closeBtn.Parent = main
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
applyStroke(closeBtn, COLOR_BORDER_DIM, 1, 0.5)

-- ====================================================
-- 🔴 ATTACH MENU
-- ====================================================
local attachMenu = Instance.new("Frame")
attachMenu.Size = UDim2.new(0, 280, 0, 230)
attachMenu.Position = UDim2.new(0.5, -140, 0.5, -115)
attachMenu.BackgroundColor3 = COLOR_BG
attachMenu.BackgroundTransparency = 0.15
attachMenu.Active = true
attachMenu.Draggable = true
attachMenu.Visible = false
attachMenu.ClipsDescendants = true
attachMenu.Parent = gui
Instance.new("UICorner", attachMenu).CornerRadius = UDim.new(0, 14)
applyStroke(attachMenu, COLOR_BORDER, 1.2, 0.3)

local aTopLine = Instance.new("Frame")
aTopLine.Size = UDim2.new(1, 0, 0, 3)
aTopLine.BackgroundColor3 = COLOR_ACCENT
aTopLine.BorderSizePixel = 0
aTopLine.Parent = attachMenu

local aTitle = Instance.new("TextLabel")
aTitle.Size = UDim2.new(1, -20, 0, 38)
aTitle.Position = UDim2.new(0, 12, 0, 3)
aTitle.BackgroundTransparency = 1
aTitle.Text = "ATTACH SETTINGS"
aTitle.TextColor3 = COLOR_TEXT
aTitle.Font = Enum.Font.GothamBold
aTitle.TextSize = 14
aTitle.TextXAlignment = Enum.TextXAlignment.Left
aTitle.Parent = attachMenu

local aStatusCard = Instance.new("Frame")
aStatusCard.Size = UDim2.new(0.92, 0, 0, 34)
aStatusCard.Position = UDim2.new(0.04, 0, 0, 42)
aStatusCard.BackgroundColor3 = COLOR_CARD
aStatusCard.BackgroundTransparency = 0.2
aStatusCard.Parent = attachMenu
Instance.new("UICorner", aStatusCard).CornerRadius = UDim.new(0, 8)
applyStroke(aStatusCard, COLOR_BORDER_DIM, 1, 0.6)

local aStatusLbl = Instance.new("TextLabel")
aStatusLbl.Size = UDim2.new(1, -12, 1, 0)
aStatusLbl.Position = UDim2.new(0, 8, 0, 0)
aStatusLbl.BackgroundTransparency = 1
aStatusLbl.Text = "สถานะ: ยังไม่ได้เกาะ"
aStatusLbl.TextColor3 = COLOR_TEXT
aStatusLbl.Font = Enum.Font.GothamMedium
aStatusLbl.TextSize = 11
aStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
aStatusLbl.Parent = aStatusCard

local aStopBtn = Instance.new("TextButton")
aStopBtn.Size = UDim2.new(0.92, 0, 0, 30)
aStopBtn.Position = UDim2.new(0.04, 0, 0, 82)
aStopBtn.BackgroundColor3 = COLOR_KILL
aStopBtn.BackgroundTransparency = 0.15
aStopBtn.Text = "ยกเลิกการเกาะติด"
aStopBtn.TextColor3 = COLOR_TEXT
aStopBtn.Font = Enum.Font.GothamBold
aStopBtn.TextSize = 11
aStopBtn.Parent = attachMenu
Instance.new("UICorner", aStopBtn).CornerRadius = UDim.new(0, 8)

local aSliderCard = Instance.new("Frame")
aSliderCard.Size = UDim2.new(0.92, 0, 0, 60)
aSliderCard.Position = UDim2.new(0.04, 0, 0, 120)
aSliderCard.BackgroundColor3 = COLOR_CARD
aSliderCard.BackgroundTransparency = 0.2
aSliderCard.Parent = attachMenu
Instance.new("UICorner", aSliderCard).CornerRadius = UDim.new(0, 8)
applyStroke(aSliderCard, COLOR_BORDER_DIM, 1, 0.6)

local aSliderLbl = Instance.new("TextLabel")
aSliderLbl.Size = UDim2.new(0.6, 0, 0, 24)
aSliderLbl.Position = UDim2.new(0, 10, 0, 4)
aSliderLbl.BackgroundTransparency = 1
aSliderLbl.Text = "ระยะติดหลัง (Studs)"
aSliderLbl.TextColor3 = COLOR_TEXT
aSliderLbl.Font = Enum.Font.GothamMedium
aSliderLbl.TextSize = 11
aSliderLbl.TextXAlignment = Enum.TextXAlignment.Left
aSliderLbl.Parent = aSliderCard

local aDistanceBox = Instance.new("TextBox")
aDistanceBox.Size = UDim2.new(0.28, 0, 0, 22)
aDistanceBox.Position = UDim2.new(0.68, 0, 0, 5)
aDistanceBox.BackgroundColor3 = COLOR_OFF
aDistanceBox.Text = "3"
aDistanceBox.TextColor3 = COLOR_ACCENT
aDistanceBox.Font = Enum.Font.GothamBold
aDistanceBox.TextSize = 11
aDistanceBox.ClearTextOnFocus = false
aDistanceBox.Parent = aSliderCard
Instance.new("UICorner", aDistanceBox).CornerRadius = UDim.new(0, 5)
applyStroke(aDistanceBox, COLOR_BORDER, 1, 0.4)

local sliderTrack = Instance.new("TextButton")
sliderTrack.Size = UDim2.new(0.92, 0, 0, 8)
sliderTrack.Position = UDim2.new(0.04, 0, 0, 38)
sliderTrack.BackgroundColor3 = COLOR_OFF
sliderTrack.Text = ""
sliderTrack.AutoButtonColor = false
sliderTrack.Parent = aSliderCard
Instance.new("UICorner", sliderTrack).CornerRadius = UDim.new(1, 0)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.06, 0, 1, 0)
sliderFill.BackgroundColor3 = COLOR_ACCENT
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderTrack
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

local sliderKnob = Instance.new("Frame")
sliderKnob.Size = UDim2.new(0, 16, 0, 16)
sliderKnob.Position = UDim2.new(0.06, -8, 0.5, -8)
sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sliderKnob.Parent = sliderTrack
Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)
applyStroke(sliderKnob, COLOR_BORDER, 1.5, 0)

local aCloseBtn = Instance.new("TextButton")
aCloseBtn.Size = UDim2.new(0.92, 0, 0, 28)
aCloseBtn.Position = UDim2.new(0.04, 0, 1, -34)
aCloseBtn.BackgroundColor3 = COLOR_CARD
aCloseBtn.BackgroundTransparency = 0.15
aCloseBtn.Text = "Fold"
aCloseBtn.TextColor3 = COLOR_TEXT
aCloseBtn.Font = Enum.Font.GothamMedium
aCloseBtn.TextSize = 11
aCloseBtn.Parent = attachMenu
Instance.new("UICorner", aCloseBtn).CornerRadius = UDim.new(0, 8)
applyStroke(aCloseBtn, COLOR_BORDER_DIM, 1, 0.5)

local function updateToggleUI(btn, enabled, label)
    if label then btn.Text = label .. (enabled and ": เปิด" or ": ปิด") end
    if btn:IsA("TextButton") and btn.Parent and btn.Parent:IsA("Frame") and btn.Size.X.Scale < 0.5 then
        btn.Text = enabled and "เปิด" or "ปิด"
        btn.BackgroundColor3 = enabled and COLOR_ACTIVE or COLOR_OFF
        btn.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or COLOR_SUBTEXT
    end
end

local function setAttachMenuVisible(visibleState)
    attachMenu.Visible = visibleState
    updateToggleUI(attachWindowBtn, visibleState)
    
    if visibleState then
        attachMenuToggleBtn.BackgroundColor3 = COLOR_ACTIVE
        attachMenuToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        attachMenuToggleBtn.BackgroundColor3 = COLOR_BG
        attachMenuToggleBtn.TextColor3 = COLOR_ACCENT
    end
end

attachMenuToggleBtn.MouseButton1Click:Connect(function()
    setAttachMenuVisible(not attachMenu.Visible)
end)

attachWindowBtn.MouseButton1Click:Connect(function()
    setAttachMenuVisible(not attachMenu.Visible)
end)

aCloseBtn.MouseButton1Click:Connect(function()
    setAttachMenuVisible(false)
end)

local draggingSlider = false

local function setAttachDistanceValue(val, updateBox)
    val = math.clamp(val, sliderMinDist, sliderMaxDist)
    attachDistance = val
    local alpha = (val - sliderMinDist) / (sliderMaxDist - sliderMinDist)
    
    sliderFill.Size = UDim2.new(alpha, 0, 1, 0)
    sliderKnob.Position = UDim2.new(alpha, -8, 0.5, -8)
    
    if updateBox ~= false then
        aDistanceBox.Text = tostring(math.floor(val * 10) / 10)
    end
end

local function updateSliderFromInput(input)
    local trackPos = sliderTrack.AbsolutePosition.X
    local trackWidth = sliderTrack.AbsoluteSize.X
    if trackWidth <= 0 then return end
    local relX = math.clamp((input.Position.X - trackPos) / trackWidth, 0, 1)
    local newVal = sliderMinDist + (relX * (sliderMaxDist - sliderMinDist))
    setAttachDistanceValue(newVal, true)
end

sliderTrack.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = true
        updateSliderFromInput(input)
    end
end)

addConn(UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateSliderFromInput(input)
    end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingSlider = false
    end
end))

aDistanceBox.FocusLost:Connect(function()
    local v = tonumber(aDistanceBox.Text)
    if v then
        setAttachDistanceValue(v, true)
    else
        aDistanceBox.Text = tostring(attachDistance)
    end
end)

-- ====================================================
-- 🔴 PLAYER LIST MENU
-- ====================================================
local checkMenu = Instance.new("Frame")
checkMenu.Size = UDim2.new(0, 310, 0, 440)
checkMenu.Position = UDim2.new(0.5, -155, 0.5, -220)
checkMenu.BackgroundColor3 = COLOR_BG
checkMenu.BackgroundTransparency = 0.15
checkMenu.Active = true
checkMenu.Draggable = true
checkMenu.Visible = false
checkMenu.ClipsDescendants = true
checkMenu.Parent = gui
Instance.new("UICorner", checkMenu).CornerRadius = UDim.new(0, 14)
applyStroke(checkMenu, COLOR_BORDER, 1.2, 0.3)

local cTopLine = Instance.new("Frame")
cTopLine.Size = UDim2.new(1, 0, 0, 3)
cTopLine.BackgroundColor3 = COLOR_ACCENT
cTopLine.BorderSizePixel = 0
cTopLine.Parent = checkMenu

local cTitle = Instance.new("TextLabel")
cTitle.Size = UDim2.new(0.6, 0, 0, 40)
cTitle.Position = UDim2.new(0, 12, 0, 3)
cTitle.BackgroundTransparency = 1
cTitle.Text = "PLAYER LIST"
cTitle.TextColor3 = COLOR_TEXT
cTitle.Font = Enum.Font.GothamBold
cTitle.TextSize = 15
cTitle.TextXAlignment = Enum.TextXAlignment.Left
cTitle.Parent = checkMenu

local refreshListBtn = Instance.new("TextButton")
refreshListBtn.Size = UDim2.new(0, 28, 0, 24)
refreshListBtn.Position = UDim2.new(1, -40, 0, 11)
refreshListBtn.BackgroundColor3 = COLOR_CARD
refreshListBtn.Text = "🔄"
refreshListBtn.TextColor3 = COLOR_TEXT
refreshListBtn.Font = Enum.Font.GothamBold
refreshListBtn.TextSize = 12
refreshListBtn.Parent = checkMenu
Instance.new("UICorner", refreshListBtn).CornerRadius = UDim.new(0, 6)
applyStroke(refreshListBtn, COLOR_BORDER_DIM, 1, 0.5)

local stopSpecBtn = Instance.new("TextButton")
stopSpecBtn.Size = UDim2.new(0.47, -6, 0, 32)
stopSpecBtn.Position = UDim2.new(0, 12, 0, 45)
stopSpecBtn.BackgroundColor3 = COLOR_KILL
stopSpecBtn.BackgroundTransparency = 0.15
stopSpecBtn.Text = "ยกเลิกส่อง"
stopSpecBtn.TextColor3 = COLOR_TEXT
stopSpecBtn.Font = Enum.Font.GothamBold
stopSpecBtn.TextSize = 11
stopSpecBtn.Parent = checkMenu
Instance.new("UICorner", stopSpecBtn).CornerRadius = UDim.new(0, 8)

local stopAttachBtn = Instance.new("TextButton")
stopAttachBtn.Size = UDim2.new(0.47, -6, 0, 32)
stopAttachBtn.Position = UDim2.new(0.51, 0, 0, 45)
stopAttachBtn.BackgroundColor3 = COLOR_KILL
stopAttachBtn.BackgroundTransparency = 0.15
stopAttachBtn.Text = "ยกเลิกเกาะ"
stopAttachBtn.TextColor3 = COLOR_TEXT
stopAttachBtn.Font = Enum.Font.GothamBold
stopAttachBtn.TextSize = 11
stopAttachBtn.Parent = checkMenu
Instance.new("UICorner", stopAttachBtn).CornerRadius = UDim.new(0, 8)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -135)
scroll.Position = UDim2.new(0, 8, 0, 85)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = COLOR_ACCENT
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = checkMenu

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 2)
listPad.PaddingBottom = UDim.new(0, 6)
listPad.PaddingLeft = UDim.new(0, 4)
listPad.PaddingRight = UDim.new(0, 6)
listPad.Parent = scroll

local cCloseBtn = Instance.new("TextButton")
cCloseBtn.Size = UDim2.new(1, -24, 0, 32)
cCloseBtn.Position = UDim2.new(0, 12, 1, -40)
cCloseBtn.BackgroundColor3 = COLOR_CARD
cCloseBtn.BackgroundTransparency = 0.15
cCloseBtn.Text = "Fold"
cCloseBtn.TextColor3 = COLOR_TEXT
cCloseBtn.Font = Enum.Font.GothamMedium
cCloseBtn.TextSize = 12
cCloseBtn.Parent = checkMenu
Instance.new("UICorner", cCloseBtn).CornerRadius = UDim.new(0, 8)
applyStroke(cCloseBtn, COLOR_BORDER_DIM, 1, 0.5)

-- ====================================================
-- 🔴 OTHER UI PANELS
-- ====================================================
local pad = Instance.new("Frame")
pad.Size = UDim2.new(0, 170, 0, 170)
pad.Position = UDim2.new(1, -190, 0.5, -85)
pad.BackgroundColor3 = COLOR_BG
pad.BackgroundTransparency = 0.2
pad.Visible = false
pad.Parent = gui
Instance.new("UICorner", pad).CornerRadius = UDim.new(1, 0)
applyStroke(pad, COLOR_BORDER, 1.2, 0.3)

local function mkPBtn(txt, pos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 44, 0, 44)
    b.Position = pos
    b.BackgroundColor3 = COLOR_CARD
    b.BackgroundTransparency = 0.15
    b.Text = txt
    b.TextColor3 = COLOR_TEXT
    b.Font = Enum.Font.GothamBold
    b.TextSize = 18
    b.Parent = pad
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    applyStroke(b, COLOR_BORDER_DIM, 1, 0.4)
    return b
end

local bU = mkPBtn("↑", UDim2.new(0.5, -22, 0, 8))
local bD = mkPBtn("↓", UDim2.new(0.5, -22, 1, -52))
local bL = mkPBtn("←", UDim2.new(0, 8, 0.5, -22))
local bR = mkPBtn("→", UDim2.new(1, -52, 0.5, -22))
local bF = mkPBtn("W", UDim2.new(0.5, -22, 0.5, -22))

local function bindPad(btn, key)
    btn.MouseButton1Down:Connect(function() dirs[key] = true; btn.BackgroundColor3 = COLOR_ACTIVE end)
    btn.MouseButton1Up:Connect(function() dirs[key] = false; btn.BackgroundColor3 = COLOR_CARD end)
    btn.MouseLeave:Connect(function() dirs[key] = false; btn.BackgroundColor3 = COLOR_CARD end)
end
bindPad(bU,"U") bindPad(bD,"D") bindPad(bL,"L") bindPad(bR,"R") bindPad(bF,"F")

-- Keybind Frame
local keybindFrame = Instance.new("Frame")
keybindFrame.Size = UDim2.new(0, 270, 0, 230)
keybindFrame.Position = UDim2.new(0.5, -135, 0.5, -115)
keybindFrame.BackgroundColor3 = COLOR_BG
keybindFrame.BackgroundTransparency = 0.12
keybindFrame.Visible = false
keybindFrame.Active = true
keybindFrame.Draggable = true
keybindFrame.ClipsDescendants = true
keybindFrame.Parent = gui
Instance.new("UICorner", keybindFrame).CornerRadius = UDim.new(0, 14)
applyStroke(keybindFrame, COLOR_BORDER, 1.2, 0.3)

local kbTopLine = Instance.new("Frame")
kbTopLine.Size = UDim2.new(1, 0, 0, 3)
kbTopLine.BackgroundColor3 = COLOR_ACCENT
kbTopLine.BorderSizePixel = 0
kbTopLine.Parent = keybindFrame

local kbTitle = Instance.new("TextLabel")
kbTitle.Size = UDim2.new(1, -20, 0, 36)
kbTitle.Position = UDim2.new(0, 12, 0, 3)
kbTitle.BackgroundTransparency = 1
kbTitle.Text = "KEYBINDS (PC)"
kbTitle.TextColor3 = COLOR_TEXT
kbTitle.Font = Enum.Font.GothamBold
kbTitle.TextSize = 14
kbTitle.TextXAlignment = Enum.TextXAlignment.Left
kbTitle.Parent = keybindFrame

local function createKeybindRow(y, featureName, displayName)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(0.9, 0, 0, 32)
    row.Position = UDim2.new(0.05, 0, y, 0)
    row.BackgroundColor3 = COLOR_CARD
    row.BackgroundTransparency = 0.2
    row.Parent = keybindFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = displayName
    label.TextColor3 = COLOR_TEXT
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local keyBtn = Instance.new("TextButton")
    keyBtn.Size = UDim2.new(0.28, 0, 0, 22)
    keyBtn.Position = UDim2.new(0.44, 0, 0.5, -11)
    keyBtn.BackgroundColor3 = COLOR_OFF
    keyBtn.Text = "None"
    keyBtn.TextColor3 = COLOR_ACCENT
    keyBtn.Font = Enum.Font.GothamBold
    keyBtn.TextSize = 10
    keyBtn.Parent = row
    Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 5)

    local modeBtn = Instance.new("TextButton")
    modeBtn.Size = UDim2.new(0.22, 0, 0, 22)
    modeBtn.Position = UDim2.new(0.74, 0, 0.5, -11)
    modeBtn.BackgroundColor3 = COLOR_OFF
    modeBtn.Text = "Toggle"
    modeBtn.TextColor3 = COLOR_SUBTEXT
    modeBtn.Font = Enum.Font.GothamMedium
    modeBtn.TextSize = 10
    modeBtn.Parent = row
    Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 5)

    keyBtn.MouseButton1Click:Connect(function()
        waitingForKey = featureName
        keyBtn.Text = "..."
        keyBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
    end)

    modeBtn.MouseButton1Click:Connect(function()
        keybinds[featureName].mode = (keybinds[featureName].mode == "Toggle") and "Hold" or "Toggle"
        modeBtn.Text = keybinds[featureName].mode
    end)

    return keyBtn, modeBtn
end

local speedKeyBtn, speedModeBtn   = createKeybindRow(0.20, "Speed",  "วิ่งไว")
local flyKeyBtn, flyModeBtn       = createKeybindRow(0.36, "Fly",    "บินได้")
local noclipKeyBtn, noclipModeBtn = createKeybindRow(0.52, "Noclip", "Noclip")

local kbClose = Instance.new("TextButton")
kbClose.Size = UDim2.new(0.9, 0, 0, 30)
kbClose.Position = UDim2.new(0.05, 0, 0.82, 0)
kbClose.BackgroundColor3 = COLOR_CARD
kbClose.BackgroundTransparency = 0.15
kbClose.Text = "Fold"
kbClose.TextColor3 = COLOR_TEXT
kbClose.Font = Enum.Font.GothamMedium
kbClose.TextSize = 11
kbClose.Parent = keybindFrame
Instance.new("UICorner", kbClose).CornerRadius = UDim.new(0, 8)
applyStroke(kbClose, COLOR_BORDER_DIM, 1, 0.5)

kbClose.MouseButton1Click:Connect(function()
    keybindFrame.Visible = false
    updateToggleUI(keybindMenuBtn, false)
end)

keybindMenuBtn.MouseButton1Click:Connect(function()
    keybindFrame.Visible = not keybindFrame.Visible
    updateToggleUI(keybindMenuBtn, keybindFrame.Visible)
end)

-- ====================================================
-- 🔴 FEATURE IMPLEMENTATIONS
-- ====================================================

-- 1. Fly Logic
local function stopFly()
    flyEnabled = false
    updateToggleUI(flyBtn, false, "บินได้")
    pad.Visible = false
    safeDestroy(bodyVel)
    safeDestroy(bodyGyro)
    bodyVel, bodyGyro = nil, nil
    if humanoid then
        humanoid.PlatformStanding = false
    end
end

local function startFly()
    flyEnabled = true
    updateToggleUI(flyBtn, true, "บินได้")
    if isMobile then pad.Visible = true end
    guardFlyPhysics()
end

flyBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    if flyEnabled then stopFly() else startFly() end
end)

flyBox.FocusLost:Connect(function()
    local v = tonumber(flyBox.Text)
    if v then flySpeed = clamp(v, 1, MAX_FLY) else flyBox.Text = tostring(flySpeed) end
end)

-- 2. Speed Logic
local function updateSpeed()
    if humanoid then
        humanoid.WalkSpeed = speedEnabled and runSpeed or 16
    end
end

spdBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    speedEnabled = not speedEnabled
    updateToggleUI(spdBtn, speedEnabled, "วิ่งไว")
    updateSpeed()
end)

spdBox.FocusLost:Connect(function()
    local v = tonumber(spdBox.Text)
    if v then
        runSpeed = clamp(v, 1, MAX_SPEED)
        updateSpeed()
    else
        spdBox.Text = tostring(runSpeed)
    end
end)

-- 3. Noclip Logic
local function setNoclip(state)
    noclipEnabled = state
    updateToggleUI(noclipBtn, state)
    if state then
        noclipConn = addConn(RunService.Stepped:Connect(function()
            if character then
                for _, p in ipairs(character:GetDescendants()) do
                    if p:IsA("BasePart") then p.CanCollide = false end
                end
            end
        end))
    else
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    end
end

noclipBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    setNoclip(not noclipEnabled)
end)

-- 4. Infinite Jump
infJumpBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    infJumpEnabled = not infJumpEnabled
    updateToggleUI(infJumpBtn, infJumpEnabled)
end)

addConn(UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- 5. Lighting Features
local function updateLighting()
    if fullbrightEnabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Ambient = originalLighting.Ambient
    end

    if noFogEnabled then
        Lighting.FogStart = 1e6
        Lighting.FogEnd = 1e6
    else
        Lighting.FogStart = originalLighting.FogStart
        Lighting.FogEnd = originalLighting.FogEnd
    end
end

fullbrightBtn.MouseButton1Click:Connect(function()
    fullbrightEnabled = not fullbrightEnabled
    updateToggleUI(fullbrightBtn, fullbrightEnabled)
    updateLighting()
end)

noFogBtn.MouseButton1Click:Connect(function()
    noFogEnabled = not noFogEnabled
    updateToggleUI(noFogBtn, noFogEnabled)
    updateLighting()
end)

-- 6. ESP System
local function createESP(targetPlayer)
    if targetPlayer == player or espObjects[targetPlayer] then return end
    local function applyHighlight(char)
        if not char then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "BoomESP"
        highlight.FillColor = COLOR_ACCENT
        highlight.FillTransparency = 0.5
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.Adornee = char
        highlight.Parent = gui
        espObjects[targetPlayer] = highlight
    end

    if targetPlayer.Character then applyHighlight(targetPlayer.Character) end
    addConn(targetPlayer.CharacterAdded:Connect(function(c)
        if espEnabled then applyHighlight(c) end
    end))
end

local function removeESP(targetPlayer)
    if espObjects[targetPlayer] then
        safeDestroy(espObjects[targetPlayer])
        espObjects[targetPlayer] = nil
    end
end

espBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    updateToggleUI(espBtn, espEnabled)
    for _, p in ipairs(Players:GetPlayers()) do
        if espEnabled then createESP(p) else removeESP(p) end
    end
end)

-- 7. Name Tag Display System
local function createNameTag(targetPlayer)
    if targetPlayer == player or nameObjects[targetPlayer] then return end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "BoomNameTag"
    billboard.Size = UDim2.new(0, 160, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = gui

    local textLbl = Instance.new("TextLabel")
    textLbl.Size = UDim2.new(1, 0, 1, 0)
    textLbl.BackgroundTransparency = 1
    textLbl.Text = targetPlayer.DisplayName
    textLbl.TextColor3 = COLOR_ACCENT
    textLbl.Font = Enum.Font.GothamBold
    textLbl.TextSize = 12
    textLbl.TextStrokeTransparency = 0.2
    textLbl.Parent = billboard

    nameObjects[targetPlayer] = {Gui = billboard, Text = textLbl}
end

local function removeNameTag(targetPlayer)
    if nameObjects[targetPlayer] then
        safeDestroy(nameObjects[targetPlayer].Gui)
        nameObjects[targetPlayer] = nil
    end
end

nameBtn.MouseButton1Click:Connect(function()
    nameEnabled = not nameEnabled
    updateToggleUI(nameBtn, nameEnabled)
    if nameEnabled then
        for _, p in ipairs(Players:GetPlayers()) do createNameTag(p) end
    else
        for p, _ in pairs(nameObjects) do removeNameTag(p) end
    end
end)

distBox.FocusLost:Connect(function()
    local v = tonumber(distBox.Text)
    if v then NAME_MAX_DIST = math.clamp(v, 50, 5000) else distBox.Text = tostring(NAME_MAX_DIST) end
end)

-- Dynamic Auto-Hook Player Connections
addConn(Players.PlayerAdded:Connect(function(p)
    if espEnabled then createESP(p) end
    if nameEnabled then createNameTag(p) end
end))

addConn(Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
    removeNameTag(p)
    if spectateTarget == p then stopSpectate() end
    if attachTarget == p then stopAttach() end
end))

-- 8. Spectate & Attach System
local function stopSpectate()
    spectateEnabled = false
    spectateTarget = nil
    if humanoid then
        workspace.CurrentCamera.CameraSubject = humanoid
    end
end

local function stopAttach()
    attachEnabled = false
    attachTarget = nil
    aStatusLbl.Text = "สถานะ: ยังไม่ได้เกาะ"
    aStatusLbl.TextColor3 = COLOR_TEXT
end

local function startAttach(targetP)
    if targetP and targetP.Character and targetP.Character:FindFirstChild("HumanoidRootPart") then
        attachTarget = targetP
        attachEnabled = true
        aStatusLbl.Text = "กำลังเกาะ: " .. targetP.DisplayName
        aStatusLbl.TextColor3 = COLOR_ACCENT
    end
end

stopSpecBtn.MouseButton1Click:Connect(stopSpectate)
stopAttachBtn.MouseButton1Click:Connect(stopAttach)
aStopBtn.MouseButton1Click:Connect(stopAttach)

-- 9. Player List Update
local function updatePlayerList()
    for _, item in pairs(playerRows) do safeDestroy(item) end
    playerRows = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 36)
            card.BackgroundColor3 = COLOR_CARD
            card.BackgroundTransparency = 0.2
            card.Parent = scroll
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
            applyStroke(card, COLOR_BORDER_DIM, 1, 0.6)

            local pLbl = Instance.new("TextLabel")
            pLbl.Size = UDim2.new(0.48, 0, 1, 0)
            pLbl.Position = UDim2.new(0, 8, 0, 0)
            pLbl.BackgroundTransparency = 1
            pLbl.Text = p.DisplayName
            pLbl.TextColor3 = COLOR_TEXT
            pLbl.Font = Enum.Font.GothamMedium
            pLbl.TextSize = 11
            pLbl.TextXAlignment = Enum.TextXAlignment.Left
            pLbl.TextTruncate = Enum.TextTruncate.AtEnd
            pLbl.Parent = card

            local specBtn = Instance.new("TextButton")
            specBtn.Size = UDim2.new(0.22, 0, 0, 22)
            specBtn.Position = UDim2.new(0.50, 0, 0.5, -11)
            specBtn.BackgroundColor3 = COLOR_OFF
            specBtn.Text = "ส่อง"
            specBtn.TextColor3 = COLOR_ACCENT
            specBtn.Font = Enum.Font.GothamBold
            specBtn.TextSize = 10
            specBtn.Parent = card
            Instance.new("UICorner", specBtn).CornerRadius = UDim.new(0, 5)

            local attBtn = Instance.new("TextButton")
            attBtn.Size = UDim2.new(0.24, 0, 0, 22)
            attBtn.Position = UDim2.new(0.74, 0, 0.5, -11)
            attBtn.BackgroundColor3 = COLOR_OFF
            attBtn.Text = "เกาะ"
            attBtn.TextColor3 = COLOR_ACCENT
            attBtn.Font = Enum.Font.GothamBold
            attBtn.TextSize = 10
            attBtn.Parent = card
            Instance.new("UICorner", attBtn).CornerRadius = UDim.new(0, 5)

            specBtn.MouseButton1Click:Connect(function()
                if p.Character and p.Character:FindFirstChild("Humanoid") then
                    spectateTarget = p
                    spectateEnabled = true
                    workspace.CurrentCamera.CameraSubject = p.Character.Humanoid
                end
            end)

            attBtn.MouseButton1Click:Connect(function()
                startAttach(p)
            end)

            table.insert(playerRows, card)
        end
    end
end

refreshListBtn.MouseButton1Click:Connect(updatePlayerList)
checkBtn.MouseButton1Click:Connect(function()
    checkMenu.Visible = not checkMenu.Visible
    if checkMenu.Visible then updatePlayerList() end
end)
cCloseBtn.MouseButton1Click:Connect(function() checkMenu.Visible = false end)

toggleBtn.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
end)

-- Cleanup Script
killBtn.MouseButton1Click:Connect(function()
    scriptAlive = false
    stopFly()
    setNoclip(false)
    stopSpectate()
    stopAttach()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, obj in pairs(espObjects) do safeDestroy(obj) end
    for _, data in pairs(nameObjects) do safeDestroy(data.Gui) end
    safeDestroy(gui)
end)

-- ====================================================
-- 🔴 INPUT HANDLERS & MAIN ENGINE LOOP
-- ====================================================
addConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if waitingForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            keybinds[waitingForKey].key = input.KeyCode
            if waitingForKey == "Speed" then speedKeyBtn.Text = keyToString(input.KeyCode) speedKeyBtn.TextColor3 = COLOR_ACCENT end
            if waitingForKey == "Fly" then flyKeyBtn.Text = keyToString(input.KeyCode) flyKeyBtn.TextColor3 = COLOR_ACCENT end
            if waitingForKey == "Noclip" then noclipKeyBtn.Text = keyToString(input.KeyCode) noclipKeyBtn.TextColor3 = COLOR_ACCENT end
            waitingForKey = nil
        end
        return
    end

    if gpe then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local k = input.KeyCode
        if k == Enum.KeyCode.W then pcKeys.W = true end
        if k == Enum.KeyCode.S then pcKeys.S = true end
        if k == Enum.KeyCode.A then pcKeys.A = true end
        if k == Enum.KeyCode.D then pcKeys.D = true end
        if k == Enum.KeyCode.Space then pcKeys.Space = true end
        if k == Enum.KeyCode.LeftShift then pcKeys.Shift = true end

        for feat, data in pairs(keybinds) do
            if data.key ~= Enum.KeyCode.Unknown and k == data.key then
                if feat == "Speed" then
                    speedEnabled = (data.mode == "Toggle") and not speedEnabled or true
                    updateToggleUI(spdBtn, speedEnabled, "วิ่งไว")
                    updateSpeed()
                elseif feat == "Fly" then
                    if data.mode == "Toggle" then
                        if flyEnabled then stopFly() else startFly() end
                    else
                        startFly()
                    end
                elseif feat == "Noclip" then
                    setNoclip((data.mode == "Toggle") and not noclipEnabled or true)
                end
            end
        end
    end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local k = input.KeyCode
        if k == Enum.KeyCode.W then pcKeys.W = false end
        if k == Enum.KeyCode.S then pcKeys.S = false end
        if k == Enum.KeyCode.A then pcKeys.A = false end
        if k == Enum.KeyCode.D then pcKeys.D = false end
        if k == Enum.KeyCode.Space then pcKeys.Space = false end
        if k == Enum.KeyCode.LeftShift then pcKeys.Shift = false end

        for feat, data in pairs(keybinds) do
            if data.key ~= Enum.KeyCode.Unknown and k == data.key and data.mode == "Hold" then
                if feat == "Speed" then
                    speedEnabled = false
                    updateToggleUI(spdBtn, false, "วิ่งไว")
                    updateSpeed()
                elseif feat == "Fly" then
                    stopFly()
                elseif feat == "Noclip" then
                    setNoclip(false)
                end
            end
        end
    end
end))

-- Render Loop for Real-time Name Tags & Smooth Camera/Attach
addConn(RunService.RenderStepped:Connect(function()
    if not scriptAlive then return end

    -- Name Tag Positions & Distance Update
    if nameEnabled and rootPart then
        for targetP, data in pairs(nameObjects) do
            if targetP.Character and targetP.Character:FindFirstChild("HumanoidRootPart") then
                local tRoot = targetP.Character.HumanoidRootPart
                local dist = math.floor((tRoot.Position - rootPart.Position).Magnitude)
                if dist <= NAME_MAX_DIST then
                    data.Gui.Enabled = true
                    data.Gui.Adornee = tRoot
                    data.Text.Text = string.format("%s [%d m]", targetP.DisplayName, dist)
                else
                    data.Gui.Enabled = false
                end
            else
                data.Gui.Enabled = false
            end
        end
    end

    -- Spectate Target Guard
    if spectateEnabled then
        if not spectateTarget or not spectateTarget.Parent or not spectateTarget.Character or not spectateTarget.Character:FindFirstChild("Humanoid") then
            stopSpectate()
        end
    end

    -- Smooth Attach Motion
    if attachEnabled and attachTarget and attachTarget.Character and attachTarget.Character:FindFirstChild("HumanoidRootPart") then
        local tRoot = attachTarget.Character.HumanoidRootPart
        applyAntiDeact(character)
        rootPart.CFrame = tRoot.CFrame * CFrame.new(0, 0, attachDistance)
        sanitizePhysics(rootPart)
    end
end))

-- Heartbeat Physics Engine
addConn(RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end

    if flyEnabled and rootPart then
        guardFlyPhysics()

        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero

        if isPC then
            if pcKeys.W then moveDir = moveDir + cam.CFrame.LookVector end
            if pcKeys.S then moveDir = moveDir - cam.CFrame.LookVector end
            if pcKeys.A then moveDir = moveDir - cam.CFrame.RightVector end
            if pcKeys.D then moveDir = moveDir + cam.CFrame.RightVector end
            if pcKeys.Space then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if pcKeys.Shift then moveDir = moveDir - Vector3.new(0, 1, 0) end
        end

        if isMobile then
            if dirs.F then moveDir = moveDir + cam.CFrame.LookVector end
            if dirs.U then moveDir = moveDir + Vector3.new(0, 1, 0) end
            if dirs.D then moveDir = moveDir - Vector3.new(0, 1, 0) end
            if dirs.L then moveDir = moveDir - cam.CFrame.RightVector end
            if dirs.R then moveDir = moveDir + cam.CFrame.RightVector end
        end

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end

        if bodyVel then bodyVel.Velocity = moveDir * flySpeed end
        if bodyGyro then bodyGyro.CFrame = cam.CFrame end
    end
end))

-- Auto Respawn Re-hooking
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    
    task.wait(0.5)
    if flyEnabled then startFly() end
    if speedEnabled then updateSpeed() end
    if noclipEnabled then setNoclip(true) end
end)
