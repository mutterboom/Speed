-- ============================================
-- By Boomxico | Modern Dark Crimson UI (v2.2 FIXED)
-- Main Menu + Player List + Spectate + Keybind
-- + Speed Animation Boost + Stability Protection
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
local isOpen = true
local scriptAlive = true

local dirs   = {F=false, B=false, L=false, R=false, U=false, D=false}
local pcKeys = {W=false, A=false, S=false, D=false, Space=false, Shift=false}

-- Animation
local animator = humanoid:FindFirstChildOfClass("Animator")
if not animator then
    animator = Instance.new("Animator")
    animator.Parent = humanoid
end
local activeRunTrack, originalAnimSpeed = nil, 1

-- Spectate
local spectateTarget, spectateEnabled = nil, false
local spectateYaw, spectatePitch, spectateDist = 0, -10, 12
local lastMouseX, lastMouseY, mouseDown = 0, 0, false

local MAX_SPEED, MAX_FLY = 200, 300
local TOGGLE_COOLDOWN    = 0.35
local lastToggleTime     = 0
local NAME_MAX_DIST      = 800

local espObjects, nameObjects, nameData, playerRows, connections = {}, {}, {}, {}, {}
local noclipConn, infJumpConn = nil, nil
local heldFeatures = {}

-- Lighting originals
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

-- ===================== Theme =====================
local COLOR_BG         = Color3.fromRGB(10, 10, 14)
local COLOR_CARD       = Color3.fromRGB(20, 20, 26)
local COLOR_BORDER     = Color3.fromRGB(220, 30, 40)
local COLOR_BORDER_DIM = Color3.fromRGB(60, 20, 25)
local COLOR_TEXT       = Color3.fromRGB(245, 245, 250)
local COLOR_SUBTEXT    = Color3.fromRGB(140, 140, 150)
local COLOR_ACCENT     = Color3.fromRGB(235, 35, 45)
local COLOR_ACTIVE     = Color3.fromRGB(190, 20, 30)
local COLOR_OFF        = Color3.fromRGB(30, 30, 38)
local COLOR_KILL       = Color3.fromRGB(180, 25, 25)

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

-- ===================== Stability Protection =====================
local function safeCall(fn, ...)
    local args = {...}
    local ok, err = pcall(function()
        return fn(table.unpack(args))
    end)
    if not ok then
        warn("[BoomMenu] Error: " .. tostring(err))
    end
    return ok
end

local function isCharacterValid()
    return character and character.Parent
        and humanoid and humanoid.Parent
        and rootPart and rootPart.Parent
end

-- ===================== Animation Speed System =====================
local RUN_ANIM_IDS = {
    "rbxassetid://507767714",
    "rbxassetid://913376220",
    "rbxassetid://180426354",
    "rbxassetid://656118852",
}

local function findGameRunTrack()
    if not animator then return nil end
    local ok, tracks = pcall(function() return animator:GetPlayingAnimationTracks() end)
    if not ok or not tracks then return nil end

    for _, track in ipairs(tracks) do
        local id = track.Animation and track.Animation.AnimationId or ""
        local name = track.Name or ""
        if name == "run" or name == "Run" or name == "RunAnim"
           or string.find(string.lower(name), "run") then
            return track
        end
        for _, runId in ipairs(RUN_ANIM_IDS) do
            if id == runId then return track end
        end
    end
    return nil
end

local function loadFallbackRunAnim()
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://507767714"
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if ok and track then
        track.Priority = Enum.AnimationPriority.Movement
        track.Looped = true
        return track
    end
    return nil
end

local function startRunAnimation()
    activeRunTrack = findGameRunTrack()
    if activeRunTrack then
        originalAnimSpeed = activeRunTrack.Speed or 1
        local ratio = runSpeed / 16
        activeRunTrack.Speed = clamp(ratio * 0.8, 0.5, 4)
    else
        activeRunTrack = loadFallbackRunAnim()
        if activeRunTrack then
            pcall(function() activeRunTrack:Play(0.1) end)
        end
    end
end

local function updateRunAnimation()
    if not activeRunTrack then return end
    local ratio = runSpeed / 16
    local newSpeed = clamp(ratio * 0.8, 0.5, 5)
    if math.abs((activeRunTrack.Speed or 1) - newSpeed) > 0.05 then
        pcall(function() activeRunTrack.Speed = newSpeed end)
    end
end

local function stopRunAnimation()
    if activeRunTrack then
        pcall(function() activeRunTrack.Speed = originalAnimSpeed or 1 end)
        activeRunTrack = nil
    end
end

-- ===================== GUI Root =====================
local gui = Instance.new("ScreenGui")
gui.Name = "ByBoomMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Floating Buttons
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

-- ====================================================
-- MAIN MENU
-- ====================================================
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 280, 0, 480)
main.Position = UDim2.new(0, 20, 0, 235)
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
subTitle.Text = "v2.2"
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

-- Features
local spdBtn, spdBox = mkRow("วิ่งไว", "50")
local flyBtn, flyBox = mkRow("บินได้", "50")
local noclipBtn      = mkToggle("Noclip")
local infJumpBtn     = mkToggle("Infinite Jump")
local fullbrightBtn  = mkToggle("Fullbright")
local noFogBtn       = mkToggle("No Fog")
local espBtn         = mkToggle("มองทะลุ (ESP)")
local nameBtn        = mkToggle("แสดงชื่อผู้เล่น")

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
-- PLAYER LIST MENU
-- ====================================================
local checkMenu = Instance.new("Frame")
checkMenu.Size = UDim2.new(0, 290, 0, 440)
checkMenu.Position = UDim2.new(0.5, -145, 0.5, -220)
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
stopSpecBtn.Size = UDim2.new(1, -24, 0, 32)
stopSpecBtn.Position = UDim2.new(0, 12, 0, 45)
stopSpecBtn.BackgroundColor3 = COLOR_KILL
stopSpecBtn.BackgroundTransparency = 0.15
stopSpecBtn.Text = "ยกเลิกส่องกล้อง"
stopSpecBtn.TextColor3 = COLOR_TEXT
stopSpecBtn.Font = Enum.Font.GothamBold
stopSpecBtn.TextSize = 12
stopSpecBtn.Parent = checkMenu
Instance.new("UICorner", stopSpecBtn).CornerRadius = UDim.new(0, 8)

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
-- MOBILE PAD + KEYBIND FRAME
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
kbClose.Position = UDim2.new(0.05, 0, 1, -38)
kbClose.BackgroundColor3 = COLOR_CARD
kbClose.BackgroundTransparency = 0.15
kbClose.Text = "Fold"
kbClose.TextColor3 = COLOR_TEXT
kbClose.Font = Enum.Font.GothamMedium
kbClose.TextSize = 12
kbClose.Parent = keybindFrame
Instance.new("UICorner", kbClose).CornerRadius = UDim.new(0, 8)
applyStroke(kbClose, COLOR_BORDER_DIM, 1, 0.5)

kbClose.MouseButton1Click:Connect(function()
    keybindFrame.Visible = false
    waitingForKey = nil
end)

keybindMenuBtn.MouseButton1Click:Connect(function()
    keybindFrame.Visible = not keybindFrame.Visible
end)

-- UI Feedback
local function updateToggleUI(btn, enabled, label)
    if label then btn.Text = label .. (enabled and ": เปิด" or ": ปิด") end
    if btn:IsA("TextButton") and btn.Parent and btn.Parent:IsA("Frame") and btn.Size.X.Scale < 0.5 then
        btn.Text = enabled and "เปิด" or "ปิด"
        btn.BackgroundColor3 = enabled and COLOR_ACTIVE or COLOR_OFF
        btn.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or COLOR_SUBTEXT
    end
end

-- ===================== SPEED (with Animation) =====================
local function applySpeed()
    if not humanoid or not humanoid.Parent then return end
    pcall(function() humanoid.WalkSpeed = speedEnabled and runSpeed or 16 end)
end

local function toggleSpeed(forceState)
    if forceState ~= nil then speedEnabled = forceState
    else speedEnabled = not speedEnabled end

    updateToggleUI(spdBtn, speedEnabled, "วิ่งไว")

    if speedEnabled then
        applySpeed()
        safeCall(startRunAnimation)
    else
        if humanoid and humanoid.Parent then
            pcall(function() humanoid.WalkSpeed = 16 end)
        end
        safeCall(stopRunAnimation)
    end
end

spdBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    toggleSpeed()
end)

spdBox.FocusLost:Connect(function()
    local v = tonumber(spdBox.Text)
    if v and v > 0 then
        runSpeed = clamp(v, 16, MAX_SPEED)
        spdBox.Text = tostring(runSpeed)
        if speedEnabled then
            applySpeed()
            safeCall(updateRunAnimation)
        end
    else
        spdBox.Text = tostring(runSpeed)
    end
end)

-- ===================== FLY =====================
local function startFly()
    if bodyVel then safeDestroy(bodyVel) end
    if bodyGyro then safeDestroy(bodyGyro) end
    if not rootPart or not rootPart.Parent then return end

    bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVel.Velocity = Vector3.zero
    bodyVel.P = 1250
    bodyVel.Parent = rootPart

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.P = 3000
    bodyGyro.D = 50
    bodyGyro.CFrame = workspace.CurrentCamera.CFrame
    bodyGyro.Parent = rootPart

    if humanoid then humanoid.PlatformStand = false end
    if isMobile then pad.Visible = true end
end

local function stopFly()
    if bodyVel then safeDestroy(bodyVel) bodyVel = nil end
    if bodyGyro then safeDestroy(bodyGyro) bodyGyro = nil end
    if humanoid and humanoid.Parent == character then
        humanoid.PlatformStand = false
        pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        humanoid.WalkSpeed = speedEnabled and runSpeed or 16
    end
    pad.Visible = false
    for k in pairs(dirs) do dirs[k] = false end
end

flyBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    flyEnabled = not flyEnabled
    updateToggleUI(flyBtn, flyEnabled, "บินได้")
    if flyEnabled then startFly() else stopFly() end
end)

flyBox.FocusLost:Connect(function()
    local v = tonumber(flyBox.Text)
    if v and v > 0 then
        flySpeed = clamp(v, 1, MAX_FLY)
        flyBox.Text = tostring(flySpeed)
    else
        flyBox.Text = tostring(flySpeed)
    end
end)

addConn(RunService.RenderStepped:Connect(function()
    if not scriptAlive or not flyEnabled then return end
    if not isCharacterValid() then return end
    if not bodyVel or not bodyVel.Parent then return end

    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        humanoid.PlatformStand = false
    end
    if bodyGyro then bodyGyro.CFrame = workspace.CurrentCamera.CFrame end

    local cam = workspace.CurrentCamera
    local mv = Vector3.zero
    if isMobile then
        if dirs.F then mv = mv + cam.CFrame.LookVector end
        if dirs.B then mv = mv - cam.CFrame.LookVector end
        if dirs.L then mv = mv - cam.CFrame.RightVector end
        if dirs.R then mv = mv + cam.CFrame.RightVector end
        if dirs.U then mv = mv + Vector3.new(0,1,0) end
        if dirs.D then mv = mv - Vector3.new(0,1,0) end
    end
    if isPC then
        if pcKeys.W then mv = mv + cam.CFrame.LookVector end
        if pcKeys.S then mv = mv - cam.CFrame.LookVector end
        if pcKeys.A then mv = mv - cam.CFrame.RightVector end
        if pcKeys.D then mv = mv + cam.CFrame.RightVector end
        if pcKeys.Space then mv = mv + Vector3.new(0,1,0) end
        if pcKeys.Shift then mv = mv - Vector3.new(0,1,0) end
    end
    bodyVel.Velocity = (mv.Magnitude > 0) and (mv.Unit * flySpeed) or Vector3.zero
end))

-- ===================== NOCLIP =====================
local function applyNoclipState()
    if not character or not character.Parent then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not noclipEnabled
        end
    end
end

local function startNoclip()
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    applyNoclipState()
    noclipConn = RunService.Stepped:Connect(function()
        if not scriptAlive or not noclipEnabled then return end
        if not character or not character.Parent then return end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

local function stopNoclip()
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    applyNoclipState()
end

noclipBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    noclipEnabled = not noclipEnabled
    updateToggleUI(noclipBtn, noclipEnabled)
    if noclipEnabled then startNoclip() else stopNoclip() end
end)

-- ===================== INFINITE JUMP =====================
local function startInfJump()
    if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
    infJumpConn = UserInputService.JumpRequest:Connect(function()
        if not scriptAlive or not infJumpEnabled then return end
        if not humanoid or not humanoid.Parent then return end
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end)
end

local function stopInfJump()
    if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
end

infJumpBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    infJumpEnabled = not infJumpEnabled
    updateToggleUI(infJumpBtn, infJumpEnabled)
    if infJumpEnabled then startInfJump() else stopInfJump() end
end)

-- ===================== LIGHTING =====================
fullbrightBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    fullbrightEnabled = not fullbrightEnabled
    updateToggleUI(fullbrightBtn, fullbrightEnabled)
    if fullbrightEnabled then
        Lighting.Brightness = 2.2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.Ambient = Color3.fromRGB(140, 140, 140)
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.GlobalShadows = originalLighting.GlobalShadows
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.Ambient = originalLighting.Ambient
    end
end)

noFogBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    noFogEnabled = not noFogEnabled
    updateToggleUI(noFogBtn, noFogEnabled)
    if noFogEnabled then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    else
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
    end
end)

-- ===================== ESP =====================
local function clearESP()
    for _, obj in pairs(espObjects) do safeDestroy(obj) end
    for k in pairs(espObjects) do espObjects[k] = nil end
end

local function applyESP(char)
    if not char or not char.Parent or char:FindFirstChild("BoomESP") then return end
    local hl = Instance.new("Highlight")
    hl.Name = "BoomESP"
    hl.Adornee = char
    hl.FillColor = COLOR_ACCENT
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = char
    table.insert(espObjects, hl)
end

local function refreshESP()
    clearESP()
    if not espEnabled then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then applyESP(p.Character) end
    end
end

espBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    espEnabled = not espEnabled
    updateToggleUI(espBtn, espEnabled)
    refreshESP()
end)

-- ===================== NAME TAGS =====================
local function clearNames()
    for _, obj in pairs(nameObjects) do safeDestroy(obj) end
    for k in pairs(nameObjects) do nameObjects[k] = nil end
    for i = #nameData, 1, -1 do nameData[i] = nil end
end

local function applyName(char, pName)
    if not char or not char.Parent then return end
    local head = char:FindFirstChild("Head")
    if not head or head:FindFirstChild("BoomName") then return end
    local bg = Instance.new("BillboardGui")
    bg.Name = "BoomName"
    bg.Size = UDim2.new(0, 120, 0, 24)
    bg.StudsOffset = Vector3.new(0, 2.8, 0)
    bg.AlwaysOnTop = true
    bg.LightInfluence = 0
    bg.Adornee = head
    bg.Parent = head
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = pName or "?"
    lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.2
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.Parent = bg
    table.insert(nameObjects, bg)
    table.insert(nameData, {gui = bg, head = head})
end

local function refreshNames()
    clearNames()
    if not nameEnabled then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then applyName(p.Character, p.Name) end
    end
end

nameBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    nameEnabled = not nameEnabled
    updateToggleUI(nameBtn, nameEnabled)
    refreshNames()
end)

distBox.FocusLost:Connect(function()
    local v = tonumber(distBox.Text)
    if v and v > 0 then
        NAME_MAX_DIST = v
        distBox.Text = tostring(NAME_MAX_DIST)
    else
        distBox.Text = "800"
        NAME_MAX_DIST = 800
    end
end)

addConn(RunService.RenderStepped:Connect(function()
    if not scriptAlive or not nameEnabled then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camPos, camLook, viewport = cam.CFrame.Position, cam.CFrame.LookVector, cam.ViewportSize
    for i = #nameData, 1, -1 do
        local data = nameData[i]
        local bg, head = data.gui, data.head
        if not head or not head.Parent or not bg or not bg.Parent then
            safeDestroy(bg)
            table.remove(nameData, i)
        else
            local delta = head.Position - camPos
            local dist = delta.Magnitude
            if dist > NAME_MAX_DIST then
                bg.Enabled = false
            else
                local dot = camLook:Dot(delta.Unit)
                if dot < 0.15 then
                    bg.Enabled = false
                else
                    local sp, onScreen = cam:WorldToViewportPoint(head.Position)
                    bg.Enabled = onScreen and sp.Z > 0
                        and sp.X > -50 and sp.X < viewport.X + 50
                        and sp.Y > -50 and sp.Y < viewport.Y + 50
                end
            end
        end
    end
end))

-- ===================== SPECTATE =====================
local function stopSpectate()
    spectateEnabled = false
    spectateTarget = nil
    local cam = workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
        if player.Character then
            local myHum = player.Character:FindFirstChildOfClass("Humanoid")
            if myHum then cam.CameraSubject = myHum end
        end
    end
end

local function spectatePlayer(targetPlayer)
    if not targetPlayer then return end
    local targetChar = targetPlayer.Character
    if not targetChar or not targetChar:FindFirstChild("Head") then return end
    spectateEnabled = true
    spectateTarget = targetPlayer
    spectateYaw, spectatePitch, spectateDist = 0, -10, 12
end

local function teleportToPlayer(targetPlayer)
    if not targetPlayer or not rootPart or not rootPart.Parent then return end
    local targetChar = targetPlayer.Character
    if not targetChar then return end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    local offset = targetRoot.CFrame.LookVector * -5
    rootPart.CFrame = CFrame.new(targetRoot.Position + offset + Vector3.new(0, 2, 0), targetRoot.Position)
end

RunService:BindToRenderStep("BoomSpectate", Enum.RenderPriority.Camera.Value + 1, function()
    if not scriptAlive or not spectateEnabled or not spectateTarget then return end
    local targetChar = spectateTarget.Character
    if not targetChar then return end
    local targetHead = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHead then return end

    local cam = workspace.CurrentCamera
    if not cam then return end
    cam.CameraType = Enum.CameraType.Scriptable

    local radYaw = math.rad(spectateYaw)
    local radPitch = math.rad(spectatePitch)
    local rotCFrame = CFrame.Angles(0, radYaw, 0) * CFrame.Angles(radPitch, 0, 0)
    local targetPos = targetHead.Position
    local camPos = targetPos + (rotCFrame * Vector3.new(0, 0, spectateDist))
    cam.CFrame = CFrame.new(camPos, targetPos)
end)

addConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
        mouseDown = true
        lastMouseX, lastMouseY = input.Position.X, input.Position.Y
    end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
        mouseDown = false
    end
end))

addConn(UserInputService.InputChanged:Connect(function(input, gpe)
    if gpe then return end
    if mouseDown and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local deltaX = input.Position.X - lastMouseX
        local deltaY = input.Position.Y - lastMouseY
        lastMouseX, lastMouseY = input.Position.X, input.Position.Y
        spectateYaw = spectateYaw - deltaX * 0.4
        spectatePitch = math.clamp(spectatePitch - deltaY * 0.4, -80, 80)
    elseif input.UserInputType == Enum.UserInputType.MouseWheel then
        spectateDist = math.clamp(spectateDist - input.Position.Z * 2, 3, 50)
    end
end))

-- ===================== PLAYER LIST =====================
local function refreshPlayerList()
    for _, child in ipairs(scroll:GetChildren()) do
        if child:IsA("Frame") then safeDestroy(child) end
    end
    for i = #playerRows, 1, -1 do playerRows[i] = nil end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, 0, 0, 38)
            row.BackgroundColor3 = COLOR_CARD
            row.BackgroundTransparency = 0.2
            row.Parent = scroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
            applyStroke(row, COLOR_BORDER_DIM, 1, 0.6)

            local pLbl = Instance.new("TextLabel")
            pLbl.Size = UDim2.new(0.52, -5, 1, 0)
            pLbl.Position = UDim2.new(0, 8, 0, 0)
            pLbl.BackgroundTransparency = 1
            pLbl.Text = p.DisplayName .. "\n(@" .. p.Name .. ")"
            pLbl.TextColor3 = COLOR_TEXT
            pLbl.Font = Enum.Font.GothamMedium
            pLbl.TextSize = 10
            pLbl.TextXAlignment = Enum.TextXAlignment.Left
            pLbl.ClipsDescendants = true
            pLbl.Parent = row

            local specB = Instance.new("TextButton")
            specB.Size = UDim2.new(0.2, 0, 0, 24)
            specB.Position = UDim2.new(0.54, 0, 0.5, -12)
            specB.BackgroundColor3 = COLOR_OFF
            specB.Text = "ส่อง"
            specB.TextColor3 = COLOR_TEXT
            specB.Font = Enum.Font.GothamBold
            specB.TextSize = 10
            specB.Parent = row
            Instance.new("UICorner", specB).CornerRadius = UDim.new(0, 6)
            applyStroke(specB, COLOR_BORDER_DIM, 1, 0.6)

            local tpB = Instance.new("TextButton")
            tpB.Size = UDim2.new(0.2, 0, 0, 24)
            tpB.Position = UDim2.new(0.76, 0, 0.5, -12)
            tpB.BackgroundColor3 = COLOR_ACCENT
            tpB.Text = "วาร์ป"
            tpB.TextColor3 = Color3.fromRGB(255, 255, 255)
            tpB.Font = Enum.Font.GothamBold
            tpB.TextSize = 10
            tpB.Parent = row
            Instance.new("UICorner", tpB).CornerRadius = UDim.new(0, 6)

            specB.MouseButton1Click:Connect(function() spectatePlayer(p) end)
            tpB.MouseButton1Click:Connect(function() teleportToPlayer(p) end)

            table.insert(playerRows, row)
        end
    end
end

refreshListBtn.MouseButton1Click:Connect(refreshPlayerList)

checkBtn.MouseButton1Click:Connect(function()
    checkMenu.Visible = not checkMenu.Visible
    if checkMenu.Visible then refreshPlayerList() end
end)

stopSpecBtn.MouseButton1Click:Connect(stopSpectate)
cCloseBtn.MouseButton1Click:Connect(function() checkMenu.Visible = false end)

-- ===================== MAIN TOGGLE =====================
toggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    main.Visible = isOpen
end)

closeBtn.MouseButton1Click:Connect(function()
    isOpen = false
    main.Visible = false
end)

-- ===================== KEYBIND LISTENER (FIXED) =====================
local function onKeybindDown(feature)
    local data = keybinds[feature]
    if not data or data.key == Enum.KeyCode.Unknown then return end

    if feature == "Speed" then
        if data.mode == "Toggle" then
            toggleSpeed()
        else
            heldFeatures[feature] = true
            toggleSpeed(true)
        end
    elseif feature == "Fly" then
        if data.mode == "Toggle" then
            if flyEnabled then
                stopFly()
                updateToggleUI(flyBtn, false, "บินได้")
            else
                flyEnabled = true
                startFly()
                updateToggleUI(flyBtn, true, "บินได้")
            end
        else
            heldFeatures[feature] = true
            if not flyEnabled then
                flyEnabled = true
                startFly()
                updateToggleUI(flyBtn, true, "บินได้")
            end
        end
    elseif feature == "Noclip" then
        if data.mode == "Toggle" then
            noclipEnabled = not noclipEnabled
            updateToggleUI(noclipBtn, noclipEnabled)
            if noclipEnabled then startNoclip() else stopNoclip() end
        else
            heldFeatures[feature] = true
            noclipEnabled = true
            updateToggleUI(noclipBtn, true)
            startNoclip()
        end
    end
end

local function onKeybindUp(feature)
    local data = keybinds[feature]
    if not data or data.mode ~= "Hold" then return end
    if not heldFeatures[feature] then return end
    heldFeatures[feature] = nil

    if feature == "Speed" then
        toggleSpeed(false)
    elseif feature == "Fly" then
        if flyEnabled then
            stopFly()
            updateToggleUI(flyBtn, false, "บินได้")
        end
    elseif feature == "Noclip" then
        if noclipEnabled then
            noclipEnabled = false
            updateToggleUI(noclipBtn, false)
            stopNoclip()
        end
    end
end

addConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if waitingForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            keybinds[waitingForKey].key = input.KeyCode
            local btnToUpdate =
                (waitingForKey == "Speed" and speedKeyBtn) or
                (waitingForKey == "Fly" and flyKeyBtn) or
                (waitingForKey == "Noclip" and noclipKeyBtn)
            if btnToUpdate then
                btnToUpdate.Text = keyToString(input.KeyCode)
                btnToUpdate.TextColor3 = COLOR_ACCENT
            end
            waitingForKey = nil
        end
        return
    end

    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    for feature, data in pairs(keybinds) do
        if data.key ~= Enum.KeyCode.Unknown and input.KeyCode == data.key then
            onKeybindDown(feature)
        end
    end

    if isPC then
        if input.KeyCode == Enum.KeyCode.W then pcKeys.W = true end
        if input.KeyCode == Enum.KeyCode.S then pcKeys.S = true end
        if input.KeyCode == Enum.KeyCode.A then pcKeys.A = true end
        if input.KeyCode == Enum.KeyCode.D then pcKeys.D = true end
        if input.KeyCode == Enum.KeyCode.Space then pcKeys.Space = true end
        if input.KeyCode == Enum.KeyCode.LeftShift then pcKeys.Shift = true end
    end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    for feature, data in pairs(keybinds) do
        if data.key ~= Enum.KeyCode.Unknown and input.KeyCode == data.key then
            onKeybindUp(feature)
        end
    end

    if isPC then
        if input.KeyCode == Enum.KeyCode.W then pcKeys.W = false end
        if input.KeyCode == Enum.KeyCode.S then pcKeys.S = false end
        if input.KeyCode == Enum.KeyCode.A then pcKeys.A = false end
        if input.KeyCode == Enum.KeyCode.D then pcKeys.D = false end
        if input.KeyCode == Enum.KeyCode.Space then pcKeys.Space = false end
        if input.KeyCode == Enum.KeyCode.LeftShift then pcKeys.Shift = false end
    end
end))

-- ===================== HEARTBEAT (Speed Guard + Animation) =====================
addConn(RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end
    if not speedEnabled then return end
    if not humanoid or not humanoid.Parent then return end

    -- บังคับ WalkSpeed ทุกเฟรม (กัน anti-cheat reset)
    if humanoid.WalkSpeed ~= runSpeed then
        pcall(function() humanoid.WalkSpeed = runSpeed end)
    end

    -- ถ้า animation หลุด ให้เริ่มใหม่
    if not activeRunTrack or (not activeRunTrack.IsPlaying and humanoid.MoveDirection.Magnitude > 0.1) then
        safeCall(startRunAnimation)
    end
    safeCall(updateRunAnimation)
end))

-- ===================== PLAYER EVENTS =====================
addConn(Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c)
        task.wait(0.5)
        if espEnabled then applyESP(c) end
        if nameEnabled then applyName(c, p.Name) end
    end)
    if checkMenu.Visible then refreshPlayerList() end
end))

addConn(Players.PlayerRemoving:Connect(function(p)
    if spectateTarget == p then stopSpectate() end
    if checkMenu.Visible then refreshPlayerList() end
end))

-- ===================== RESPAWN GUARD =====================
addConn(player.CharacterAdded:Connect(function(newChar)
    safeCall(function()
        character = newChar
        humanoid = newChar:WaitForChild("Humanoid", 10)
        rootPart = newChar:WaitForChild("HumanoidRootPart", 10)

        if not humanoid or not rootPart then return end

        animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        activeRunTrack = nil

        task.wait(0.5)

        if flyEnabled then startFly() end
        if noclipEnabled then startNoclip() end
        if speedEnabled and humanoid and humanoid.Parent then
            pcall(function() humanoid.WalkSpeed = runSpeed end)
            startRunAnimation()
        end
    end)
end))

-- ===================== CLEANUP =====================
local function destroyScript()
    scriptAlive = false
    safeCall(stopFly)
    safeCall(stopNoclip)
    safeCall(stopInfJump)
    safeCall(stopSpectate)
    safeCall(stopRunAnimation)
    safeCall(clearESP)
    safeCall(clearNames)

    Lighting.Brightness = originalLighting.Brightness
    Lighting.ClockTime = originalLighting.ClockTime
    Lighting.GlobalShadows = originalLighting.GlobalShadows
    Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
    Lighting.Ambient = originalLighting.Ambient
    Lighting.FogEnd = originalLighting.FogEnd
    Lighting.FogStart = originalLighting.FogStart

    pcall(function() RunService:UnbindFromRenderStep("BoomSpectate") end)

    for _, conn in ipairs(connections) do
        if conn and conn.Connected then
            pcall(function() conn:Disconnect() end)
        end
    end
    for i = #connections, 1, -1 do connections[i] = nil end

    safeDestroy(gui)
    print("[BoomMenu v2.2] ปิดสคริปต์แล้ว")
end

killBtn.MouseButton1Click:Connect(destroyScript)

game:BindToClose(function()
    safeCall(destroyScript)
end)

print("[BoomMenu v2.2] ✅ โหลดสำเร็จ")
