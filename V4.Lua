-- ============================================
-- By Boomxico | Golden Glass UI V4.2
-- วิ่งไว + บินได้ + มองทะลุ + เห็นชื่อ + เช็คชื่อ + TP
-- + Noclip + Infinite Jump + FPS Boost + Custom Hotkey
-- ============================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local isPC = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
local isMobile = UserInputService.TouchEnabled

local speedEnabled, flyEnabled, espEnabled, nameEnabled = false, false, false, false
local noclipEnabled, infJumpEnabled, fpsBoostEnabled = false, false, false
local runSpeed, flySpeed = 50, 50
local bodyVel, bodyGyro
local isOpen = true
local scriptAlive = true

local dirs = {F=false, B=false, L=false, R=false, U=false, D=false}
local pcKeys = {W=false, A=false, S=false, D=false, Space=false, Shift=false}

local hotkeys = {
    speed = {key = nil, pressed = false},
    fly = {key = nil, pressed = false}
}

local runAnimator = humanoid:FindFirstChildOfClass("Animator")
if not runAnimator then
    runAnimator = Instance.new("Animator")
    runAnimator.Parent = humanoid
end
local runAnimTrack = nil

local savedState = {
    speed = false, speedVal = 50,
    fly = false, flyVal = 50,
    esp = false,
    name = false, nameDist = 800,
    noclip = false,
    infJump = false,
    fpsBoost = false
}

local spectateTarget = nil
local spectateEnabled = false
local spectateYaw = 0
local spectatePitch = -10
local spectateDist = 12
local lastMouseX = 0
local lastMouseY = 0
local mouseDown = false

local MAX_SPEED = 200
local MAX_FLY = 300
local lastToggleTime = 0
local TOGGLE_COOLDOWN = 0.4
local NAME_MAX_DIST = 800

local espObjects, nameObjects = {}, {}
local nameData = {}
local playerRows = {}
local noclipConnection = nil
local infJumpConnection = nil
local fpsBoostBackup = {}
local noclipBusy = false

-- ============================================
-- สีหลัก (Golden Theme)
-- ============================================
local COLOR_BG = Color3.fromRGB(8, 8, 10)
local COLOR_BG_LIGHT = Color3.fromRGB(22, 22, 28)
local COLOR_BORDER = Color3.fromRGB(255, 180, 0)
local COLOR_BORDER_DIM = Color3.fromRGB(120, 80, 0)
local COLOR_TEXT = Color3.fromRGB(255, 230, 140)
local COLOR_TEXT_DIM = Color3.fromRGB(180, 150, 60)
local COLOR_ACCENT = Color3.fromRGB(255, 200, 0)
local COLOR_GLOW = Color3.fromRGB(255, 230, 100)
local COLOR_ACTIVE_BG = Color3.fromRGB(120, 90, 0)
local COLOR_DANGER_BG = Color3.fromRGB(80, 15, 15)

-- ============================================
-- Glow Animation
-- ============================================
local glowObjects = {}

local function addGlow(target, baseTransparency, isTitle)
    local stroke = Instance.new("UIStroke", target)
    stroke.Color = COLOR_BORDER
    stroke.Thickness = isTitle and 1.5 or 1
    stroke.Transparency = baseTransparency or 0.7
    table.insert(glowObjects, {stroke = stroke, base = baseTransparency or 0.7, title = isTitle})
    return stroke
end

task.spawn(function()
    while scriptAlive do
        local t = tick()
        for _, obj in ipairs(glowObjects) do
            if obj.stroke and obj.stroke.Parent then
                local pulse = math.sin(t * 2) * 0.5 + 0.5
                local target = obj.title
                    and (0.3 + pulse * 0.25)
                    or (obj.base + pulse * 0.1)
                obj.stroke.Transparency = target
            end
        end
        task.wait(0.05)
    end
end)

-- ============================================
-- UI หลัก
-- ============================================
local gui = Instance.new("ScreenGui")
gui.Name = "ByBoomMenu"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 55, 0, 55)
toggleBtn.Position = UDim2.new(0, 20, 0, 100)
toggleBtn.BackgroundColor3 = COLOR_BG
toggleBtn.BackgroundTransparency = 0.4
toggleBtn.Text = "B"
toggleBtn.TextColor3 = COLOR_TEXT
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 24
toggleBtn.TextStrokeTransparency = 0.4
toggleBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.Parent = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
addGlow(toggleBtn, 0.5, true)

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 270, 0, 650)
main.Position = UDim2.new(0, 20, 0, 165)
main.BackgroundColor3 = COLOR_BG
main.BackgroundTransparency = 0.4
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 18)
addGlow(main, 0.7, false)

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, -30, 0, 2)
topLine.Position = UDim2.new(0, 15, 0, 0)
topLine.BackgroundColor3 = COLOR_ACCENT
topLine.BorderSizePixel = 0
topLine.Parent = main
Instance.new("UICorner", topLine).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 42)
title.Position = UDim2.new(0, 10, 0, 12)
title.BackgroundTransparency = 1
title.Text = "BY BOOMXICO"
title.TextColor3 = COLOR_TEXT
title.TextStrokeTransparency = 0.4
title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.Parent = main

local titleGlow = Instance.new("UIStroke", title)
titleGlow.Color = COLOR_GLOW
titleGlow.Thickness = 1
titleGlow.Transparency = 0.5
table.insert(glowObjects, {stroke = titleGlow, base = 0.5, title = true})

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -30, 0, 1)
divider.Position = UDim2.new(0, 15, 0, 58)
divider.BackgroundColor3 = COLOR_BORDER_DIM
divider.BackgroundTransparency = 0.5
divider.BorderSizePixel = 0
divider.Parent = main

-- ============================================
-- ฟังก์ชันสร้าง UI
-- ============================================
local function mkBtn(y, labelText, fullWidth)
    local btn = Instance.new("TextButton")
    if fullWidth then
        btn.Size = UDim2.new(0.9, 0, 0, 34)
        btn.Position = UDim2.new(0.05, 0, y, 0)
    else
        btn.Size = UDim2.new(0.55, 0, 0, 34)
        btn.Position = UDim2.new(0.05, 0, y, 0)
    end
    btn.BackgroundColor3 = COLOR_BG_LIGHT
    btn.BackgroundTransparency = 0.5
    btn.TextColor3 = COLOR_TEXT
    btn.TextStrokeTransparency = 0.5
    btn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.Text = labelText
    btn.Parent = main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    addGlow(btn, 0.7, false)
    return btn
end

local function mkBox(y, defaultVal)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.3, 0, 0, 34)
    box.Position = UDim2.new(0.65, 0, y, 0)
    box.BackgroundColor3 = COLOR_BG_LIGHT
    box.BackgroundTransparency = 0.5
    box.Text = defaultVal
    box.TextColor3 = COLOR_ACCENT
    box.TextStrokeTransparency = 0.5
    box.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 13
    box.Parent = main
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
    addGlow(box, 0.7, false)
    return box
end

-- แถวที่ 1-2 : วิ่งไว + บินได้
local spdBtn = mkBtn(0.11, "วิ่งไว: ปิด")
local spdBox = mkBox(0.11, "50")
local flyBtn = mkBtn(0.18, "บินได้: ปิด")
local flyBox = mkBox(0.18, "50")

-- แถวที่ 3 : Hotkey
local hotkeyRow = Instance.new("Frame")
hotkeyRow.Size = UDim2.new(0.9, 0, 0, 28)
hotkeyRow.Position = UDim2.new(0.05, 0, 0.25, 0)
hotkeyRow.BackgroundTransparency = 1
hotkeyRow.Parent = main

local function mkHotkeyBtn(text, xPos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.32, 0, 0, 28)
    b.Position = UDim2.new(xPos, 0, 0, 0)
    b.BackgroundColor3 = COLOR_BG_LIGHT
    b.BackgroundTransparency = 0.5
    b.Text = text
    b.TextColor3 = COLOR_TEXT_DIM
    b.TextStrokeTransparency = 0.5
    b.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    b.Font = Enum.Font.Gotham
    b.TextSize = 11
    b.Parent = hotkeyRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    addGlow(b, 0.75, false)
    return b
end

local hotkeySpdBtn = mkHotkeyBtn("Hotkey วิ่ง", 0)
local hotkeyFlyBtn = mkHotkeyBtn("Hotkey บิน", 0.34)

local hotkeyClearBtn = Instance.new("TextButton")
hotkeyClearBtn.Size = UDim2.new(0.32, 0, 0, 28)
hotkeyClearBtn.Position = UDim2.new(0.68, 0, 0, 0)
hotkeyClearBtn.BackgroundColor3 = COLOR_DANGER_BG
hotkeyClearBtn.BackgroundTransparency = 0.5
hotkeyClearBtn.Text = "ลบ Hotkey"
hotkeyClearBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
hotkeyClearBtn.TextStrokeTransparency = 0.5
hotkeyClearBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
hotkeyClearBtn.Font = Enum.Font.Gotham
hotkeyClearBtn.TextSize = 11
hotkeyClearBtn.Parent = hotkeyRow
Instance.new("UICorner", hotkeyClearBtn).CornerRadius = UDim.new(0, 8)

-- แถว 4-8 : ฟีเจอร์หลัก
local espBtn = mkBtn(0.32, "มองทะลุ: ปิด")
local nameBtn = mkBtn(0.39, "เห็นชื่อ: ปิด")
local infJumpBtn = mkBtn(0.46, "กระโดดไม่จำกัด: ปิด")
local noclipBtn = mkBtn(0.53, "Noclip: ปิด")
local fpsBoostBtn = mkBtn(0.60, "FPS Boost: ปิด")

local distLbl = Instance.new("TextLabel")
distLbl.Size = UDim2.new(0.55, 0, 0, 34)
distLbl.Position = UDim2.new(0.05, 0, 0.67, 0)
distLbl.BackgroundColor3 = COLOR_BG_LIGHT
distLbl.BackgroundTransparency = 0.5
distLbl.Text = "ระยะชื่อ"
distLbl.TextColor3 = COLOR_TEXT
distLbl.TextStrokeTransparency = 0.5
distLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
distLbl.Font = Enum.Font.GothamMedium
distLbl.TextSize = 13
distLbl.Parent = main
Instance.new("UICorner", distLbl).CornerRadius = UDim.new(0, 10)
addGlow(distLbl, 0.7, false)

local distBox = mkBox(0.67, "800")

local openListBtn = mkBtn(0.76, "เปิดเมนูรายชื่อ", true)
local killBtn = mkBtn(0.83, "ปิดสคริปต์ทั้งหมด", true)
killBtn.BackgroundColor3 = COLOR_DANGER_BG
killBtn.BackgroundTransparency = 0.3
killBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
killBtn.Font = Enum.Font.GothamBold
local killStroke = Instance.new("UIStroke", killBtn)
killStroke.Color = Color3.fromRGB(255, 60, 60)
killStroke.Thickness = 1.5
killStroke.Transparency = 0.4

local closeBtn = mkBtn(0.90, "ซ่อนเมนู", true)
closeBtn.TextColor3 = COLOR_TEXT_DIM

-- ============================================
-- D-Pad บิน
-- ============================================
local pad = Instance.new("Frame")
pad.Size = UDim2.new(0, 180, 0, 180)
pad.Position = UDim2.new(1, -200, 0.5, -90)
pad.BackgroundColor3 = COLOR_BG
pad.BackgroundTransparency = 0.4
pad.Visible = false
pad.Parent = gui
Instance.new("UICorner", pad).CornerRadius = UDim.new(1, 0)
addGlow(pad, 0.5, false)

local function mkPBtn(txt, pos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 50, 0, 50)
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(60, 40, 0)
    b.BackgroundTransparency = 0.3
    b.Text = txt
    b.TextColor3 = COLOR_TEXT
    b.TextStrokeTransparency = 0.5
    b.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 20
    b.Parent = pad
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    addGlow(b, 0.6, false)
    return b
end

local bU = mkPBtn("↑", UDim2.new(0.5, -25, 0, 5))
local bD = mkPBtn("↓", UDim2.new(0.5, -25, 1, -55))
local bL = mkPBtn("←", UDim2.new(0, 5, 0.5, -25))
local bR = mkPBtn("→", UDim2.new(1, -55, 0.5, -25))
local bF = mkPBtn("W", UDim2.new(0.5, -25, 0.5, -25))

local function bind(b, key)
    b.MouseButton1Down:Connect(function() dirs[key] = true; b.BackgroundColor3 = COLOR_ACTIVE_BG end)
    b.MouseButton1Up:Connect(function() dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(60, 40, 0) end)
    b.MouseLeave:Connect(function() dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(60, 40, 0) end)
end
bind(bU,"U") bind(bD,"D") bind(bL,"L") bind(bR,"R") bind(bF,"F")

-- ============================================
-- Input PC
-- ============================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.W then pcKeys.W = true end
    if input.KeyCode == Enum.KeyCode.A then pcKeys.A = true end
    if input.KeyCode == Enum.KeyCode.S then pcKeys.S = true end
    if input.KeyCode == Enum.KeyCode.D then pcKeys.D = true end
    if input.KeyCode == Enum.KeyCode.Space then pcKeys.Space = true end
    if input.KeyCode == Enum.KeyCode.LeftShift then pcKeys.Shift = true end
    
    if input.KeyCode == Enum.KeyCode.X 
       and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        if noclipBusy then return end
        noclipBusy = true
        task.wait(math.random() * 0.1)
        noclipEnabled = not noclipEnabled
        noclipBtn.Text = noclipEnabled and "Noclip: เปิด" or "Noclip: ปิด"
        noclipBtn.BackgroundColor3 = noclipEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
        savedState.noclip = noclipEnabled
        if noclipEnabled then enableNoclip() else disableNoclip() end
        task.wait(0.05)
        noclipBusy = false
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then pcKeys.W = false end
    if input.KeyCode == Enum.KeyCode.A then pcKeys.A = false end
    if input.KeyCode == Enum.KeyCode.S then pcKeys.S = false end
    if input.KeyCode == Enum.KeyCode.D then pcKeys.D = false end
    if input.KeyCode == Enum.KeyCode.Space then pcKeys.Space = false end
    if input.KeyCode == Enum.KeyCode.LeftShift then pcKeys.Shift = false end
end)

-- ============================================
-- เมนูรายชื่อ
-- ============================================
local checkMenu = Instance.new("Frame")
checkMenu.Size = UDim2.new(0, 280, 0, 410)
checkMenu.Position = UDim2.new(0.5, -140, 0.5, -205)
checkMenu.BackgroundColor3 = COLOR_BG
checkMenu.BackgroundTransparency = 0.4
checkMenu.Active = true
checkMenu.Draggable = true
checkMenu.Visible = false
checkMenu.Parent = gui
Instance.new("UICorner", checkMenu).CornerRadius = UDim.new(0, 18)
addGlow(checkMenu, 0.7, false)

local cTopLine = Instance.new("Frame")
cTopLine.Size = UDim2.new(1, -30, 0, 2)
cTopLine.Position = UDim2.new(0, 15, 0, 0)
cTopLine.BackgroundColor3 = COLOR_ACCENT
cTopLine.BorderSizePixel = 0
cTopLine.Parent = checkMenu
Instance.new("UICorner", cTopLine).CornerRadius = UDim.new(1, 0)

local cTitle = Instance.new("TextLabel")
cTitle.Size = UDim2.new(1, -20, 0, 42)
cTitle.Position = UDim2.new(0, 10, 0, 12)
cTitle.BackgroundTransparency = 1
cTitle.Text = "PLAYERS | BOOMXICO"
cTitle.TextColor3 = COLOR_TEXT
cTitle.TextStrokeTransparency = 0.4
cTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
cTitle.Font = Enum.Font.GothamBold
cTitle.TextSize = 16
cTitle.Parent = checkMenu

local stopSpecBtn = Instance.new("TextButton")
stopSpecBtn.Size = UDim2.new(0.9, 0, 0, 34)
stopSpecBtn.Position = UDim2.new(0.05, 0, 0, 60)
stopSpecBtn.BackgroundColor3 = COLOR_DANGER_BG
stopSpecBtn.BackgroundTransparency = 0.3
stopSpecBtn.Text = "ปิดส่องกล้อง"
stopSpecBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
stopSpecBtn.TextStrokeTransparency = 0.5
stopSpecBtn.Font = Enum.Font.GothamBold
stopSpecBtn.TextSize = 13
stopSpecBtn.Parent = checkMenu
Instance.new("UICorner", stopSpecBtn).CornerRadius = UDim.new(0, 10)
local sss = Instance.new("UIStroke", stopSpecBtn)
sss.Color = Color3.fromRGB(255, 60, 60); sss.Thickness = 1.5; sss.Transparency = 0.4

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(0.9, 0, 0, 250)
scroll.Position = UDim2.new(0.05, 0, 0, 102)
scroll.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
scroll.BackgroundTransparency = 0.4
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = COLOR_ACCENT
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = checkMenu
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 12)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0, 6)
listPad.PaddingLeft = UDim.new(0, 6)
listPad.PaddingRight = UDim.new(0, 6)
listPad.Parent = scroll

local cCloseBtn = Instance.new("TextButton")
cCloseBtn.Size = UDim2.new(0.9, 0, 0, 34)
cCloseBtn.Position = UDim2.new(0.05, 0, 1, -42)
cCloseBtn.BackgroundColor3 = COLOR_BG_LIGHT
cCloseBtn.BackgroundTransparency = 0.5
cCloseBtn.Text = "ซ่อนเมนู"
cCloseBtn.TextColor3 = COLOR_TEXT_DIM
cCloseBtn.TextStrokeTransparency = 0.5
cCloseBtn.Font = Enum.Font.GothamMedium
cCloseBtn.TextSize = 13
cCloseBtn.Parent = checkMenu
Instance.new("UICorner", cCloseBtn).CornerRadius = UDim.new(0, 10)

-- ============================================
-- Popup ตั้ง Hotkey
-- ============================================
local hotkeyPopup = Instance.new("Frame")
hotkeyPopup.Size = UDim2.new(0, 260, 0, 200)
hotkeyPopup.Position = UDim2.new(0.5, -130, 0.5, -100)
hotkeyPopup.BackgroundColor3 = COLOR_BG
hotkeyPopup.BackgroundTransparency = 0.15
hotkeyPopup.Active = true
hotkeyPopup.Draggable = true
hotkeyPopup.Visible = false
hotkeyPopup.Parent = gui
Instance.new("UICorner", hotkeyPopup).CornerRadius = UDim.new(0, 14)
local hps = Instance.new("UIStroke", hotkeyPopup)
hps.Color = COLOR_BORDER
hps.Thickness = 1.5
hps.Transparency = 0.3

local hpTopLine = Instance.new("Frame")
hpTopLine.Size = UDim2.new(1, -30, 0, 2)
hpTopLine.Position = UDim2.new(0, 15, 0, 0)
hpTopLine.BackgroundColor3 = COLOR_ACCENT
hpTopLine.BorderSizePixel = 0
hpTopLine.Parent = hotkeyPopup
Instance.new("UICorner", hpTopLine).CornerRadius = UDim.new(1, 0)

local hpTitle = Instance.new("TextLabel")
hpTitle.Size = UDim2.new(1, -20, 0, 32)
hpTitle.Position = UDim2.new(0, 10, 0, 10)
hpTitle.BackgroundTransparency = 1
hpTitle.Text = "SET HOTKEY"
hpTitle.TextColor3 = COLOR_TEXT
hpTitle.TextStrokeTransparency = 0.4
hpTitle.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
hpTitle.Font = Enum.Font.GothamBold
hpTitle.TextSize = 16
hpTitle.Parent = hotkeyPopup

local hpTarget = Instance.new("TextLabel")
hpTarget.Size = UDim2.new(1, -20, 0, 20)
hpTarget.Position = UDim2.new(0, 10, 0, 42)
hpTarget.BackgroundTransparency = 1
hpTarget.Text = "Target: วิ่งไว"
hpTarget.TextColor3 = COLOR_TEXT_DIM
hpTarget.Font = Enum.Font.Gotham
hpTarget.TextSize = 12
hpTarget.Parent = hotkeyPopup

local hpKeyLbl = Instance.new("TextLabel")
hpKeyLbl.Size = UDim2.new(0.3, 0, 0, 30)
hpKeyLbl.Position = UDim2.new(0.05, 0, 0, 68)
hpKeyLbl.BackgroundTransparency = 1
hpKeyLbl.Text = "ปุ่ม:"
hpKeyLbl.TextColor3 = COLOR_TEXT
hpKeyLbl.Font = Enum.Font.GothamMedium
hpKeyLbl.TextSize = 13
hpKeyLbl.TextXAlignment = Enum.TextXAlignment.Left
hpKeyLbl.Parent = hotkeyPopup

local hpKeyBox = Instance.new("TextBox")
hpKeyBox.Size = UDim2.new(0.6, 0, 0, 30)
hpKeyBox.Position = UDim2.new(0.35, 0, 0, 68)
hpKeyBox.BackgroundColor3 = COLOR_BG_LIGHT
hpKeyBox.BackgroundTransparency = 0.4
hpKeyBox.Text = ""
hpKeyBox.PlaceholderText = "เช่น Q, F, X, +, -"
hpKeyBox.TextColor3 = COLOR_ACCENT
hpKeyBox.Font = Enum.Font.GothamBold
hpKeyBox.TextSize = 13
hpKeyBox.Parent = hotkeyPopup
Instance.new("UICorner", hpKeyBox).CornerRadius = UDim.new(0, 8)

local hpSaveBtn = Instance.new("TextButton")
hpSaveBtn.Size = UDim2.new(0.42, 0, 0, 30)
hpSaveBtn.Position = UDim2.new(0.05, 0, 1, -40)
hpSaveBtn.BackgroundColor3 = COLOR_ACTIVE_BG
hpSaveBtn.BackgroundTransparency = 0.2
hpSaveBtn.Text = "บันทึก"
hpSaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hpSaveBtn.Font = Enum.Font.GothamBold
hpSaveBtn.TextSize = 13
hpSaveBtn.Parent = hotkeyPopup
Instance.new("UICorner", hpSaveBtn).CornerRadius = UDim.new(0, 8)

local hpCloseBtn = Instance.new("TextButton")
hpCloseBtn.Size = UDim2.new(0.42, 0, 0, 30)
hpCloseBtn.Position = UDim2.new(0.53, 0, 1, -40)
hpCloseBtn.BackgroundColor3 = COLOR_BG_LIGHT
hpCloseBtn.BackgroundTransparency = 0.4
hpCloseBtn.Text = "ปิด"
hpCloseBtn.TextColor3 = COLOR_TEXT_DIM
hpCloseBtn.Font = Enum.Font.GothamMedium
hpCloseBtn.TextSize = 13
hpCloseBtn.Parent = hotkeyPopup
Instance.new("UICorner", hpCloseBtn).CornerRadius = UDim.new(0, 8)

local hotkeyEditTarget = nil

local function openHotkeyPopup(target)
    hotkeyEditTarget = target
    local data = hotkeys[target]
    hpTarget.Text = "Target: " .. (target == "speed" and "วิ่งไว" or "บินได้")
    hpKeyBox.Text = data.key and data.key.Name or ""
    hotkeyPopup.Visible = true
end

hotkeySpdBtn.MouseButton1Click:Connect(function()
    openHotkeyPopup("speed")
end)

hotkeyFlyBtn.MouseButton1Click:Connect(function()
    openHotkeyPopup("fly")
end)

-- ★ Numpad Map
local numpadMap = {
    ["+"] = "KeypadPlus",
    ["-"] = "KeypadMinus",
    ["*"] = "KeypadMultiply",
    ["/"] = "KeypadDivide",
    ["."] = "KeypadPeriod",
    ["0"] = "KeypadZero",
    ["1"] = "KeypadOne",
    ["2"] = "KeypadTwo",
    ["3"] = "KeypadThree",
    ["4"] = "KeypadFour",
    ["5"] = "KeypadFive",
    ["6"] = "KeypadSix",
    ["7"] = "KeypadSeven",
    ["8"] = "KeypadEight",
    ["9"] = "KeypadNine"
}

hpSaveBtn.MouseButton1Click:Connect(function()
    if not hotkeyEditTarget then return end
    local raw = string.gsub(hpKeyBox.Text, "%s", "")
    if raw == "" then
        hotkeys[hotkeyEditTarget].key = nil
        hotkeyPopup.Visible = false
        return
    end
    
    local text = string.upper(raw)
    local keyCode = nil
    
    if numpadMap[raw] then
        keyCode = Enum.KeyCode[numpadMap[raw]]
    else
        local ok, kc = pcall(function() return Enum.KeyCode[text] end)
        if ok then keyCode = kc end
    end
    
    if keyCode then
        hotkeys[hotkeyEditTarget].key = keyCode
        hotkeyPopup.Visible = false
        print("[Boom] Hotkey set:", hotkeyEditTarget, "=", keyCode.Name)
    else
        hpTarget.Text = "ปุ่มไม่ถูกต้อง!"
        task.wait(1.5)
        hpTarget.Text = "Target: " .. (hotkeyEditTarget == "speed" and "วิ่งไว" or "บินได้")
    end
end)

hpCloseBtn.MouseButton1Click:Connect(function()
    hotkeyPopup.Visible = false
end)

hotkeyClearBtn.MouseButton1Click:Connect(function()
    hotkeys.speed.key = nil
    hotkeys.fly.key = nil
    hotkeyPopup.Visible = false
end)

-- ============================================
-- Helper Functions
-- ============================================
local function canToggle()
    local now = tick()
    if now - lastToggleTime < TOGGLE_COOLDOWN then return false end
    lastToggleTime = now
    return true
end

local function clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

toggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    main.Visible = isOpen
end)

-- ============================================
-- ดึงอนิเมชั่นวิ่ง
-- ============================================
local function getGameRunTrack()
    if not runAnimator then return nil end
    local tracks = runAnimator:GetPlayingAnimationTracks()
    for _, track in pairs(tracks) do
        local nm = track.Name or ""
        local anim = track.Animation
        local id = anim and anim.AnimationId or ""
        if nm == "run" or nm == "RunAnim"
           or id == "rbxassetid://507767714"
           or string.find(id, "run") then
            return track
        end
    end
    local animateScript = character:FindFirstChild("Animate")
    if animateScript then
        local runNode = animateScript:FindFirstChild("run")
        local runAnimObj = runNode and runNode:FindFirstChild("RunAnim")
        if runAnimObj and runAnimObj.AnimationId ~= "" then
            local anim = Instance.new("Animation")
            anim.AnimationId = runAnimObj.AnimationId
            local ok, track = pcall(function() return runAnimator:LoadAnimation(anim) end)
            if ok and track then return track end
        end
    end
    local fb = Instance.new("Animation")
    fb.AnimationId = "rbxassetid://507767714"
    local ok, track = pcall(function() return runAnimator:LoadAnimation(fb) end)
    if ok then return track end
    return nil
end

-- ============================================
-- Noclip System
-- ============================================
function enableNoclip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if not noclipEnabled then return end
        if not character or not character.Parent then return end
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end)
end

function disableNoclip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if character and character.Parent then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.CanCollide = true end)
            end
        end
    end
end

noclipBtn.MouseButton1Click:Connect(function()
    if noclipBusy then return end
    noclipBusy = true
    task.wait(math.random() * 0.1)
    noclipEnabled = not noclipEnabled
    noclipBtn.Text = noclipEnabled and "Noclip: เปิด" or "Noclip: ปิด"
    noclipBtn.BackgroundColor3 = noclipEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
    savedState.noclip = noclipEnabled
    if noclipEnabled then enableNoclip() else disableNoclip() end
    task.wait(0.05)
    noclipBusy = false
end)

-- ============================================
-- Infinite Jump System
-- ============================================
function enableInfJump()
    if infJumpConnection then return end
    infJumpConnection = UserInputService.JumpRequest:Connect(function()
        if not infJumpEnabled then return end
        if humanoid and humanoid.Parent == character then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
end

function disableInfJump()
    if infJumpConnection then
        infJumpConnection:Disconnect()
        infJumpConnection = nil
    end
end

infJumpBtn.MouseButton1Click:Connect(function()
    infJumpEnabled = not infJumpEnabled
    infJumpBtn.Text = infJumpEnabled and "กระโดดไม่จำกัด: เปิด" or "กระโดดไม่จำกัด: ปิด"
    infJumpBtn.BackgroundColor3 = infJumpEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
    savedState.infJump = infJumpEnabled
    if infJumpEnabled then enableInfJump() else disableInfJump() end
end)

-- ============================================
-- ★ FPS Boost System
-- ============================================
local function enableFPSBoost()
    if not fpsBoostEnabled then return end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") 
           or obj:IsA("Fire") 
           or obj:IsA("Smoke") 
           or obj:IsA("Sparkles") then
            if obj.Enabled then
                table.insert(fpsBoostBackup, {obj = obj, prop = "Enabled", val = true})
                obj.Enabled = false
            end
        end
        if obj:IsA("Decal") or obj:IsA("Texture") then
            if obj.Transparency < 1 then
                table.insert(fpsBoostBackup, {obj = obj, prop = "Transparency", val = obj.Transparency})
                obj.Transparency = 1
            end
        end
    end
    
    local Lighting = game:GetService("Lighting")
    table.insert(fpsBoostBackup, {obj = Lighting, prop = "GlobalShadows", val = Lighting.GlobalShadows})
    table.insert(fpsBoostBackup, {obj = Lighting, prop = "FogEnd", val = Lighting.FogEnd})
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
    
    for _, obj in ipairs(Lighting:GetChildren()) do
        if obj:IsA("PostEffect") and obj.Enabled then
            table.insert(fpsBoostBackup, {obj = obj, prop = "Enabled", val = true})
            obj.Enabled = false
        end
    end
    
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    if Terrain then
        table.insert(fpsBoostBackup, {obj = Terrain, prop = "WaterWaveSize", val = Terrain.WaterWaveSize})
        table.insert(fpsBoostBackup, {obj = Terrain, prop = "WaterWaveSpeed", val = Terrain.WaterWaveSpeed})
        Terrain.WaterWaveSize = 0
        Terrain.WaterWaveSpeed = 0
    end
    
    print("[Boom] FPS Boost enabled:", #fpsBoostBackup, "objects modified")
end

local function disableFPSBoost()
    for _, data in ipairs(fpsBoostBackup) do
        if data.obj and data.obj.Parent ~= nil then
            pcall(function()
                data.obj[data.prop] = data.val
            end)
        end
    end
    fpsBoostBackup = {}
    print("[Boom] FPS Boost disabled")
end

fpsBoostBtn.MouseButton1Click:Connect(function()
    fpsBoostEnabled = not fpsBoostEnabled
    fpsBoostBtn.Text = fpsBoostEnabled and "FPS Boost: เปิด" or "FPS Boost: ปิด"
    fpsBoostBtn.BackgroundColor3 = fpsBoostEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
    savedState.fpsBoost = fpsBoostEnabled
    if fpsBoostEnabled then
        enableFPSBoost()
    else
        disableFPSBoost()
    end
end)

-- ============================================
-- Toggle Functions
-- ============================================
local function toggleSpeed()
    if not canToggle() then return end
    speedEnabled = not speedEnabled
    spdBtn.Text = speedEnabled and "วิ่งไว: เปิด" or "วิ่งไว: ปิด"
    spdBtn.BackgroundColor3 = speedEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
    savedState.speed = speedEnabled
    savedState.speedVal = runSpeed
    if not speedEnabled and humanoid and humanoid.Parent then humanoid.WalkSpeed = 16 end
end

local function toggleFly()
    if not canToggle() then return end
    flyEnabled = not flyEnabled
    flyBtn.Text = flyEnabled and "บินได้: เปิด" or "บินได้: ปิด"
    flyBtn.BackgroundColor3 = flyEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
    savedState.fly = flyEnabled
    savedState.flyVal = flySpeed
    if flyEnabled then startFly() else stopFly() end
end

-- ============================================
-- วิ่งไว
-- ============================================
spdBtn.MouseButton1Click:Connect(toggleSpeed)

spdBox.FocusLost:Connect(function()
    local v = tonumber(spdBox.Text)
    if v and v > 0 then runSpeed = clamp(v, 1, MAX_SPEED)
    else spdBox.Text = "50"; runSpeed = 50 end
    savedState.speedVal = runSpeed
end)

RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end
    if speedEnabled and humanoid and humanoid.Parent == character then
        if not flyEnabled then
            local jitter = 1 + (math.random() - 0.5) * 0.04
            humanoid.WalkSpeed = runSpeed * jitter
        end
    end
end)

-- ============================================
-- บิน
-- ============================================
function startFly()
    if bodyVel then bodyVel:Destroy() end
    if bodyGyro then bodyGyro:Destroy() end
    rootPart.CFrame = rootPart.CFrame + Vector3.new(0, 3, 0)

    bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVel.Velocity = Vector3.new(0, 0, 0)
    bodyVel.P = 1250
    bodyVel.Parent = rootPart

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bodyGyro.P = 3000
    bodyGyro.D = 50
    bodyGyro.CFrame = workspace.CurrentCamera.CFrame
    bodyGyro.Parent = rootPart

    humanoid.PlatformStand = false

    task.wait(0.15)
    runAnimTrack = getGameRunTrack()
    if runAnimTrack then
        runAnimTrack.Priority = Enum.AnimationPriority.Action
        runAnimTrack.Looped = true
        pcall(function() runAnimTrack:Play(0.1) end)
    end

    if isMobile then pad.Visible = true end
end

function stopFly()
    if bodyVel then bodyVel:Destroy(); bodyVel = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    if runAnimTrack then
        pcall(function() runAnimTrack:Stop(0.1) end)
        runAnimTrack = nil
    end
    if humanoid and humanoid.Parent == character then
        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        humanoid.WalkSpeed = speedEnabled and runSpeed or 16
    end
    pad.Visible = false
    for k in pairs(dirs) do dirs[k] = false end
end

flyBtn.MouseButton1Click:Connect(toggleFly)

flyBox.FocusLost:Connect(function()
    local v = tonumber(flyBox.Text)
    if v and v > 0 then flySpeed = clamp(v, 1, MAX_FLY)
    else flyBox.Text = "50"; flySpeed = 50 end
    savedState.flyVal = flySpeed
end)

RunService.RenderStepped:Connect(function()
    if not scriptAlive then return end
    if flyEnabled and bodyVel and rootPart.Parent == character then
        humanoid:ChangeState(Enum.HumanoidStateType.Running)
        humanoid.PlatformStand = false

        if runAnimTrack then
            if not runAnimTrack.IsPlaying then
                pcall(function() runAnimTrack:Play(0.1) end)
            end
            local ratio = math.clamp(flySpeed / 50, 0.5, 3)
            pcall(function() runAnimTrack:AdjustSpeed(ratio) end)
        end

        if bodyGyro then bodyGyro.CFrame = workspace.CurrentCamera.CFrame end

        local cam = workspace.CurrentCamera
        local mv = Vector3.new(0, 0, 0)

        if isMobile then
            if dirs.F then mv = mv + cam.CFrame.LookVector end
            if dirs.B then mv = mv - cam.CFrame.LookVector end
            if dirs.L then mv = mv - cam.CFrame.RightVector end
            if dirs.R then mv = mv + cam.CFrame.RightVector end
            if dirs.U then mv = mv + Vector3.new(0, 1, 0) end
            if dirs.D then mv = mv - Vector3.new(0, 1, 0) end
        end

        if isPC then
            if pcKeys.W then mv = mv + cam.CFrame.LookVector end
            if pcKeys.S then mv = mv - cam.CFrame.LookVector end
            if pcKeys.A then mv = mv - cam.CFrame.RightVector end
            if pcKeys.D then mv = mv + cam.CFrame.RightVector end
            if pcKeys.Space then mv = mv + Vector3.new(0, 1, 0) end
            if pcKeys.Shift then mv = mv - Vector3.new(0, 1, 0) end
        end

        local jitter = 1 + (math.random() - 0.5) * 0.03
        bodyVel.Velocity = mv.Magnitude > 0 and (mv.Unit * flySpeed * jitter) or Vector3.new(0, 0, 0)
    end
end)

-- ============================================
-- Hotkey Listener
-- ============================================
if isPC then
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        
        if hotkeys.speed.key and input.KeyCode == hotkeys.speed.key then
            if not hotkeys.speed.pressed then
                hotkeys.speed.pressed = true
                toggleSpeed()
            end
        end
        
        if hotkeys.fly.key and input.KeyCode == hotkeys.fly.key then
            if not hotkeys.fly.pressed then
                hotkeys.fly.pressed = true
                toggleFly()
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if hotkeys.speed.key and input.KeyCode == hotkeys.speed.key then
            hotkeys.speed.pressed = false
        end
        if hotkeys.fly.key and input.KeyCode == hotkeys.fly.key then
            hotkeys.fly.pressed = false
        end
    end)
end

-- ============================================
-- มองทะลุ
-- ============================================
local function clearESP()
    for _, obj in pairs(espObjects) do if obj then obj:Destroy() end end
    espObjects = {}
end

local function applyESP(char)
    if not char then return end
    local hl = Instance.new("Highlight")
    hl.Name = "BoomESP"
    hl.Adornee = char
    hl.FillColor = Color3.fromRGB(255, 180, 0)
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
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then applyESP(p.Character) end
    end
end

espBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    espEnabled = not espEnabled
    espBtn.Text = espEnabled and "มองทะลุ: เปิด" or "มองทะลุ: ปิด"
    espBtn.BackgroundColor3 = espEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
    savedState.esp = espEnabled
    refreshESP()
end)

-- ============================================
-- เห็นชื่อ
-- ============================================
local function clearNames()
    for _, obj in pairs(nameObjects) do if obj then obj:Destroy() end end
    nameObjects = {}
    nameData = {}
end

local function applyName(char, pName)
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bg = Instance.new("BillboardGui")
    bg.Name = "BoomName"
    bg.Size = UDim2.new(0, 110, 0, 24)
    bg.StudsOffset = Vector3.new(0, 2.8, 0)
    bg.AlwaysOnTop = true
    bg.LightInfluence = 0
    bg.MaxDistance = math.huge
    bg.Adornee = head
    bg.Parent = head

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = pName or "?"
    lbl.TextColor3 = Color3.fromRGB(255, 230, 120)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(60, 30, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextScaled = false
    lbl.TextSize = 14
    lbl.Parent = bg

    table.insert(nameObjects, bg)
    table.insert(nameData, {gui = bg, head = head})
end

function refreshNames()
    clearNames()
    if not nameEnabled then return end
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            applyName(p.Character, p.Name)
        end
    end
end

nameBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    nameEnabled = not nameEnabled
    nameBtn.Text = nameEnabled and "เห็นชื่อ: เปิด" or "เห็นชื่อ: ปิด"
    nameBtn.BackgroundColor3 = nameEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
    savedState.name = nameEnabled
    refreshNames()
end)

distBox.FocusLost:Connect(function()
    local v = tonumber(distBox.Text)
    if v and v > 0 then
        NAME_MAX_DIST = v
    else
        distBox.Text = "800"
        NAME_MAX_DIST = 800
    end
    savedState.nameDist = NAME_MAX_DIST
end)

RunService.RenderStepped:Connect(function()
    if not scriptAlive or not nameEnabled then return end
    local cam = workspace.CurrentCamera
    local camPos = cam.CFrame.Position
    local camLook = cam.CFrame.LookVector
    local viewport = cam.ViewportSize

    for i = #nameData, 1, -1 do
        local data = nameData[i]
        local bg = data.gui
        local head = data.head

        if not head or not head.Parent then
            if bg then bg:Destroy() end
            table.remove(nameData, i)
            continue
        end

        local headPos = head.Position
        local delta = headPos - camPos
        local dist = delta.Magnitude

        if dist > NAME_MAX_DIST then
            bg.Enabled = false
        else
            local dot = camLook:Dot(delta.Unit)
            if dot < 0.15 then
                bg.Enabled = false
            else
                local sp, onScreen = cam:WorldToViewportPoint(headPos)
                bg.Enabled = onScreen and sp.Z > 0
                    and sp.X > -50 and sp.X < viewport.X + 50
                    and sp.Y > -50 and sp.Y < viewport.Y + 50
            end
        end
    end
end)

-- ============================================
-- ส่องกล้อง
-- ============================================
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
    if not targetChar then
        local ok = pcall(function() targetChar = targetPlayer.CharacterAdded:Wait() end)
        if not ok or not targetChar then return end
    end

    spectateEnabled = true
    spectateTarget = targetPlayer
    spectateYaw = 0
    spectatePitch = -10
    spectateDist = 12
end

local function teleportToPlayer(targetPlayer)
    if not targetPlayer then return end
    local targetChar = targetPlayer.Character
    if not targetChar then
        local ok = pcall(function() targetChar = targetPlayer.CharacterAdded:Wait() end)
        if not ok or not targetChar then return end
    end
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end
    if not rootPart or not rootPart.Parent then return end

    local offset = targetRoot.CFrame.LookVector * -5
    local newPos = targetRoot.Position + offset + Vector3.new(0, 2, 0)
    rootPart.CFrame = CFrame.new(newPos, targetRoot.Position)
end

RunService:BindToRenderStep("BoomSpectate", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not scriptAlive then return end
    if not spectateEnabled or not spectateTarget then return end

    local targetChar = spectateTarget.Character
    if not targetChar then return end
    local targetHead = targetChar:FindFirstChild("Head")
    if not targetHead then return end

    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Scriptable

    local yawRad = math.rad(spectateYaw)
    local pitchRad = math.rad(spectatePitch)
    local offset = Vector3.new(
        math.sin(yawRad) * math.cos(pitchRad) * spectateDist,
        -math.sin(pitchRad) * spectateDist + 2,
        math.cos(yawRad) * math.cos(pitchRad) * spectateDist
    )
    local camPos = targetHead.Position + offset
    local lookAt = targetHead.Position

    cam.CFrame = CFrame.new(camPos, lookAt)
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not spectateEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        mouseDown = true
        lastMouseX = input.Position.X
        lastMouseY = input.Position.Y
    end
    if input.UserInputType == Enum.UserInputType.Touch then
        mouseDown = true
        lastMouseX = input.Position.X
        lastMouseY = input.Position.Y
    end
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        spectateDist = math.clamp(spectateDist - input.Position.Z * 2, 4, 50)
    end
end)

UserInputService.InputChanged:Connect(function(input, gp)
    if not spectateEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement and mouseDown then
        local dx = input.Position.X - lastMouseX
        local dy = input.Position.Y - lastMouseY
        lastMouseX = input.Position.X
        lastMouseY = input.Position.Y
        spectateYaw = spectateYaw + dx * 0.3
        spectatePitch = math.clamp(spectatePitch - dy * 0.3, -80, 80)
    end
    if input.UserInputType == Enum.UserInputType.Touch and mouseDown then
        local dx = input.Position.X - lastMouseX
        local dy = input.Position.Y - lastMouseY
        lastMouseX = input.Position.X
        lastMouseY = input.Position.Y
        spectateYaw = spectateYaw + dx * 0.5
        spectatePitch = math.clamp(spectatePitch - dy * 0.5, -80, 80)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2
       or input.UserInputType == Enum.UserInputType.Touch then
        mouseDown = false
    end
end)

-- ============================================
-- รายชื่อผู้เล่น
-- ============================================
local function refreshPlayerList()
    for _, data in pairs(playerRows) do
        if data and data.row then data.row:Destroy() end
    end
    playerRows = {}

    local players = Players:GetPlayers()
    table.sort(players, function(a, b) return a.Name:lower() < b.Name:lower() end)

    local count = 0
    for _, p in pairs(players) do
        if p ~= player then
            count = count + 1

            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -8, 0, 44)
            row.BackgroundColor3 = COLOR_BG_LIGHT
            row.BackgroundTransparency = 0.5
            row.BorderSizePixel = 0
            row.Parent = scroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

            local avatar = Instance.new("ImageLabel")
            avatar.Size = UDim2.new(0, 30, 0, 30)
            avatar.Position = UDim2.new(0.02, 0, 0.5, -15)
            avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
            avatar.BorderSizePixel = 0
            avatar.Image = ""
            avatar.Parent = row
            Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
            local avStroke = Instance.new("UIStroke", avatar)
            avStroke.Color = COLOR_ACCENT
            avStroke.Thickness = 1
            avStroke.Transparency = 0.3

            task.spawn(function()
                local ok, thumb = pcall(function()
                    return Players:GetUserThumbnailAsync(
                        p.UserId,
                        Enum.ThumbnailType.HeadShot,
                        Enum.ThumbnailSize.Size100x100
                    )
                end)
                if ok and thumb and avatar and avatar.Parent then
                    avatar.Image = thumb
                end
            end)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.42, 0, 0.5, 0)
            nameLbl.Position = UDim2.new(0.14, 0, 0.05, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = p.DisplayName
            nameLbl.TextColor3 = COLOR_TEXT
            nameLbl.Font = Enum.Font.GothamMedium
            nameLbl.TextSize = 12
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nameLbl.Parent = row

            local userLbl = Instance.new("TextLabel")
            userLbl.Size = UDim2.new(0.42, 0, 0.4, 0)
            userLbl.Position = UDim2.new(0.14, 0, 0.52, 0)
            userLbl.BackgroundTransparency = 1
            userLbl.Text = "@" .. p.Name
            userLbl.TextColor3 = COLOR_TEXT_DIM
            userLbl.Font = Enum.Font.Gotham
            userLbl.TextSize = 10
            userLbl.TextXAlignment = Enum.TextXAlignment.Left
            userLbl.TextTruncate = Enum.TextTruncate.AtEnd
            userLbl.Parent = row

            local distLbl2 = Instance.new("TextLabel")
            distLbl2.Size = UDim2.new(0.13, 0, 1, 0)
            distLbl2.Position = UDim2.new(0.57, 0, 0, 0)
            distLbl2.BackgroundTransparency = 1
            distLbl2.Text = "-"
            distLbl2.TextColor3 = COLOR_ACCENT
            distLbl2.Font = Enum.Font.GothamBold
            distLbl2.TextSize = 10
            distLbl2.Parent = row

            local tpBtn = Instance.new("TextButton")
            tpBtn.Size = UDim2.new(0.13, 0, 0, 28)
            tpBtn.Position = UDim2.new(0.71, 0, 0.5, -14)
            tpBtn.BackgroundColor3 = Color3.fromRGB(100, 70, 0)
            tpBtn.BackgroundTransparency = 0.3
            tpBtn.Text = "TP"
            tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            tpBtn.Font = Enum.Font.GothamBold
            tpBtn.TextSize = 12
            tpBtn.Parent = row
            Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 8)

            tpBtn.MouseButton1Click:Connect(function()
                teleportToPlayer(p)
            end)

            local specBtn = Instance.new("TextButton")
            specBtn.Size = UDim2.new(0.13, 0, 0, 28)
            specBtn.Position = UDim2.new(0.85, 0, 0.5, -14)
            specBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 0)
            specBtn.BackgroundTransparency = 0.3
            specBtn.Text = "ส่อง"
            specBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            specBtn.Font = Enum.Font.GothamBold
            specBtn.TextSize = 12
            specBtn.Parent = row
            Instance.new("UICorner", specBtn).CornerRadius = UDim.new(0, 8)

            specBtn.MouseButton1Click:Connect(function()
                spectatePlayer(p)
            end)

            table.insert(playerRows, {row = row, player = p, distLbl = distLbl2})
        end
    end
    print("[Boom] Player list refreshed:", count, "players")
end

openListBtn.MouseButton1Click:Connect(function()
    checkMenu.Visible = not checkMenu.Visible
    if checkMenu.Visible then
        task.wait(0.05)
        refreshPlayerList()
    end
end)

task.spawn(function()
    while scriptAlive do
        task.wait(2)
        if checkMenu.Visible then refreshPlayerList() end
    end
end)

task.spawn(function()
    while scriptAlive do
        task.wait(0.5)
        if checkMenu.Visible then
            for _, data in pairs(playerRows) do
                local p = data.player
                local dLbl = data.distLbl
                if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                   and rootPart and rootPart.Parent then
                    local d = (p.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
                    dLbl.Text = math.floor(d) .. "m"
                else
                    dLbl.Text = "-"
                end
            end
        end
    end
end)

task.spawn(function()
    while scriptAlive do
        task.wait(0.5)
        if spectateEnabled and spectateTarget then
            if not spectateTarget.Parent
               or not spectateTarget.Character
               or not spectateTarget.Character:FindFirstChild("Head") then
                stopSpectate()
            end
        end
    end
end)

cCloseBtn.MouseButton1Click:Connect(function()
    checkMenu.Visible = false
end)

stopSpecBtn.MouseButton1Click:Connect(stopSpectate)

Players.PlayerAdded:Connect(function()
    task.wait(0.5)
    if checkMenu.Visible then refreshPlayerList() end
end)
Players.PlayerRemoving:Connect(function(p)
    task.wait(0.3)
    if spectateTarget == p then stopSpectate() end
    if checkMenu.Visible then refreshPlayerList() end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c)
        task.wait(0.5)
        if not scriptAlive then return end
        if espEnabled then applyESP(c) end
        if nameEnabled then applyName(c, p.Name) end
    end)
end)
Players.PlayerRemoving:Connect(function() refreshESP(); refreshNames() end)

for _, p in pairs(Players:GetPlayers()) do
    if p ~= player then
        p.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            if not scriptAlive then return end
            if espEnabled then applyESP(c) end
            if nameEnabled then applyName(c, p.Name) end
        end)
    end
end

-- ============================================
-- ปุ่มปิดสคริปต์
-- ============================================
local function killScript()
    scriptAlive = false
    speedEnabled, flyEnabled, espEnabled, nameEnabled = false, false, false, false
    noclipEnabled, infJumpEnabled = false, false
    if fpsBoostEnabled then
        fpsBoostEnabled = false
        disableFPSBoost()
    end
    stopFly()
    stopSpectate()
    disableNoclip()
    disableInfJump()
    clearESP()
    clearNames()
    if humanoid and humanoid.Parent == character then
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    if gui then gui:Destroy() end
end

killBtn.MouseButton1Click:Connect(killScript)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    isOpen = false
end)

-- ============================================
-- เกิดใหม่ — คืนค่าสถานะ
-- ============================================
player.CharacterAdded:Connect(function(nc)
    character = nc
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")

    runAnimator = humanoid:FindFirstChildOfClass("Animator")
    if not runAnimator then
        runAnimator = Instance.new("Animator")
        runAnimator.Parent = humanoid
    end
    runAnimTrack = nil

    if bodyVel then bodyVel:Destroy(); bodyVel = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end

    task.wait(1)
    if not scriptAlive then return end

    if savedState.speed then
        speedEnabled = true
        runSpeed = savedState.speedVal
        spdBox.Text = tostring(runSpeed)
        spdBtn.Text = "วิ่งไว: เปิด"
        spdBtn.BackgroundColor3 = COLOR_ACTIVE_BG
        humanoid.WalkSpeed = runSpeed
    else
        speedEnabled = false
        spdBtn.Text = "วิ่งไว: ปิด"
        spdBtn.BackgroundColor3 = COLOR_BG_LIGHT
        humanoid.WalkSpeed = 16
    end

    if savedState.fly then
        flyEnabled = true
        flySpeed = savedState.flyVal
        flyBox.Text = tostring(flySpeed)
        flyBtn.Text = "บินได้: เปิด"
        flyBtn.BackgroundColor3 = COLOR_ACTIVE_BG
        startFly()
    else
        flyEnabled = false
        flyBtn.Text = "บินได้: ปิด"
        flyBtn.BackgroundColor3 = COLOR_BG_LIGHT
        pad.Visible = false
    end

    if savedState.esp then
        espEnabled = true
        espBtn.Text = "มองทะลุ: เปิด"
        espBtn.BackgroundColor3 = COLOR_ACTIVE_BG
        refreshESP()
    else
        espEnabled = false
        espBtn.Text = "มองทะลุ: ปิด"
        espBtn.BackgroundColor3 = COLOR_BG_LIGHT
    end

    if savedState.name then
        nameEnabled = true
        NAME_MAX_DIST = savedState.nameDist
        distBox.Text = tostring(NAME_MAX_DIST)
        nameBtn.Text = "เห็นชื่อ: เปิด"
        nameBtn.BackgroundColor3 = COLOR_ACTIVE_BG
        refreshNames()
    else
        nameEnabled = false
        nameBtn.Text = "เห็นชื่อ: ปิด"
        nameBtn.BackgroundColor3 = COLOR_BG_LIGHT
    end

    if savedState.infJump then
        infJumpEnabled = true
        infJumpBtn.Text = "กระโดดไม่จำกัด: เปิด"
        infJumpBtn.BackgroundColor3 = COLOR_ACTIVE_BG
        enableInfJump()
    else
        infJumpEnabled = false
        infJumpBtn.Text = "กระโดดไม่จำกัด: ปิด"
        infJumpBtn.BackgroundColor3 = COLOR_BG_LIGHT
    end    if savedState.noclip then
        noclipEnabled = true
        noclipBtn.Text = "Noclip: เปิด"
        noclipBtn.BackgroundColor3 = COLOR_ACTIVE_BG
        enableNoclip()
    else
        noclipEnabled = false
        noclipBtn.Text = "Noclip: ปิด"
        noclipBtn.BackgroundColor3 = COLOR_BG_LIGHT
    end

    if savedState.fpsBoost then
        fpsBoostEnabled = true
        fpsBoostBtn.Text = "FPS Boost: เปิด"
        fpsBoostBtn.BackgroundColor3 = COLOR_ACTIVE_BG
        enableFPSBoost()
    else
        fpsBoostEnabled = false
        fpsBoostBtn.Text = "FPS Boost: ปิด"
        fpsBoostBtn.BackgroundColor3 = COLOR_BG_LIGHT
    end

    for k in pairs(dirs) do dirs[k] = false end
end)

print("Boom script V4.2 loaded OK | By Boomxico | Platform:", isPC and "PC" or (isMobile and "Mobile" or "Other"))
