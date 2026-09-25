-- ============================================
-- By Boomxico | Golden Glass UI + Noclip + Hotkey
-- วิ่งไว + บินได้ + มองทะลุ + เห็นชื่อ + เช็คชื่อ + TP + Noclip
-- V4 : UI มืออาชีพ + Noclip + Hotkey (Q/E + Numpad)
-- ============================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local isPC = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
local isMobile = UserInputService.TouchEnabled

local speedEnabled, flyEnabled, espEnabled, nameEnabled, noclipEnabled = false, false, false, false, false
local runSpeed, flySpeed = 50, 50
local bodyVel, bodyGyro
local isOpen = true
local scriptAlive = true

local dirs = {F=false, B=false, L=false, R=false, U=false, D=false}
local pcKeys = {W=false, A=false, S=false, D=false, Space=false, Shift=false}

-- ★ Hotkey ระบบ (Q/E + Numpad)
local hotkeys = {
    speed = {
        keys = {
            Enum.KeyCode.Q,
            Enum.KeyCode.KeypadPlus,
            Enum.KeyCode.KeypadOne
        },
        pressed = false
    },
    fly = {
        keys = {
            Enum.KeyCode.E,
            Enum.KeyCode.KeypadMinus,
            Enum.KeyCode.KeypadTwo
        },
        pressed = false
    }
}

local runAnimator = humanoid:FindFirstChildOfClass("Animator")
if not runAnimator then
    runAnimator = Instance.new("Animator")
    runAnimator.Parent = humanoid
end
local runAnimTrack = nil

local savedState = {
    speed = false,
    speedVal = 50,
    fly = false,
    flyVal = 50,
    esp = false,
    name = false,
    nameDist = 800,
    noclip = false
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

-- ============================================
-- 🎨 สีหลัก (Golden Theme)
-- ============================================
local COLOR_BG = Color3.fromRGB(8, 8, 10)
local COLOR_BG_LIGHT = Color3.fromRGB(18, 18, 22)
local COLOR_BORDER = Color3.fromRGB(255, 180, 0)
local COLOR_BORDER_DIM = Color3.fromRGB(120, 80, 0)
local COLOR_TEXT = Color3.fromRGB(255, 220, 100)
local COLOR_TEXT_DIM = Color3.fromRGB(180, 150, 60)
local COLOR_ACCENT = Color3.fromRGB(255, 200, 0)
local COLOR_ACTIVE = Color3.fromRGB(255, 180, 0)
local COLOR_GLOW = Color3.fromRGB(255, 230, 100)

-- ============================================
-- 🎬 Glow Animation
-- ============================================
local glowObjects = {}

local function addGlow(target, baseTransparency, isTitle)
    local stroke = Instance.new("UIStroke", target)
    stroke.Color = COLOR_BORDER
    stroke.Thickness = isTitle and 2 or 1.5
    stroke.Transparency = baseTransparency or 0.3
    table.insert(glowObjects, {stroke = stroke, base = baseTransparency or 0.3, title = isTitle})
    return stroke
end

task.spawn(function()
    while scriptAlive do
        local t = tick()
        for _, obj in ipairs(glowObjects) do
            if obj.stroke and obj.stroke.Parent then
                local pulse = math.sin(t * 2) * 0.5 + 0.5
                local target = obj.title 
                    and (0.1 + pulse * 0.4)
                    or (obj.base + pulse * 0.15)
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
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.Parent = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
addGlow(toggleBtn, 0.2, true)

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 510)
main.Position = UDim2.new(0, 20, 0, 165)
main.BackgroundColor3 = COLOR_BG
main.BackgroundTransparency = 0.4
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 18)
addGlow(main, 0.4, false)

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, -30, 0, 2)
topLine.Position = UDim2.new(0, 15, 0, 0)
topLine.BackgroundColor3 = COLOR_ACCENT
topLine.BorderSizePixel = 0
topLine.Parent = main
Instance.new("UICorner", topLine).CornerRadius = UDim.new(1, 0)

local topLineGlow = Instance.new("UIStroke", topLine)
topLineGlow.Color = COLOR_GLOW
topLineGlow.Thickness = 3
topLineGlow.Transparency = 0.5

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 42)
title.Position = UDim2.new(0, 10, 0, 12)
title.BackgroundTransparency = 1
title.Text = "BY BOOMXICO"
title.TextColor3 = COLOR_TEXT
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.Parent = main

local titleGlow = Instance.new("UIStroke", title)
titleGlow.Color = COLOR_GLOW
titleGlow.Thickness = 1
titleGlow.Transparency = 0.3
table.insert(glowObjects, {stroke = titleGlow, base = 0.3, title = true})

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -30, 0, 1)
divider.Position = UDim2.new(0, 15, 0, 60)
divider.BackgroundColor3 = COLOR_BORDER_DIM
divider.BackgroundTransparency = 0.5
divider.BorderSizePixel = 0
divider.Parent = main

-- ============================================
-- ฟังก์ชันสร้างปุ่ม
-- ============================================
local function mkRow(y, labelText, defaultVal)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.52, 0, 0, 34)
    btn.Position = UDim2.new(0.05, 0, y, 0)
    btn.BackgroundColor3 = COLOR_BG_LIGHT
    btn.BackgroundTransparency = 0.5
    btn.TextColor3 = COLOR_TEXT
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.Text = labelText
    btn.Parent = main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    addGlow(btn, 0.6, false)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.3, 0, 0, 34)
    box.Position = UDim2.new(0.63, 0, y, 0)
    box.BackgroundColor3 = COLOR_BG_LIGHT
    box.BackgroundTransparency = 0.5
    box.Text = defaultVal
    box.TextColor3 = COLOR_ACCENT
    box.Font = Enum.Font.GothamBold
    box.TextSize = 13
    box.Parent = main
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 10)
    addGlow(box, 0.5, false)

    return btn, box
end

local spdBtn, spdBox = mkRow(0.14, "วิ่งไว: ปิด", "50")
local flyBtn, flyBox = mkRow(0.22, "บินได้: ปิด", "50")

-- ★ Hotkey Display
local hotkeyLbl = Instance.new("TextLabel")
hotkeyLbl.Size = UDim2.new(0.9, 0, 0, 16)
hotkeyLbl.Position = UDim2.new(0.05, 0, 0.28, 0)
hotkeyLbl.BackgroundTransparency = 1
hotkeyLbl.Text = "Hotkey: Q/+/1=วิ่ง  E/-/2=บิน"
hotkeyLbl.TextColor3 = COLOR_TEXT_DIM
hotkeyLbl.Font = Enum.Font.Gotham
hotkeyLbl.TextSize = 10
hotkeyLbl.TextXAlignment = Enum.TextXAlignment.Center
hotkeyLbl.Parent = main

local espBtn = Instance.new("TextButton")
espBtn.Size = UDim2.new(0.52, 0, 0, 34)
espBtn.Position = UDim2.new(0.05, 0, 0.34, 0)
espBtn.BackgroundColor3 = COLOR_BG_LIGHT
espBtn.BackgroundTransparency = 0.5
espBtn.TextColor3 = COLOR_TEXT
espBtn.Font = Enum.Font.GothamMedium
espBtn.TextSize = 13
espBtn.Text = "มองทะลุ: ปิด"
espBtn.Parent = main
Instance.new("UICorner", espBtn).CornerRadius = UDim.new(0, 10)
addGlow(espBtn, 0.6, false)

local nameBtn = Instance.new("TextButton")
nameBtn.Size = UDim2.new(0.52, 0, 0, 34)
nameBtn.Position = UDim2.new(0.05, 0, 0.42, 0)
nameBtn.BackgroundColor3 = COLOR_BG_LIGHT
nameBtn.BackgroundTransparency = 0.5
nameBtn.TextColor3 = COLOR_TEXT
nameBtn.Font = Enum.Font.GothamMedium
nameBtn.TextSize = 13
nameBtn.Text = "เห็นชื่อ: ปิด"
nameBtn.Parent = main
Instance.new("UICorner", nameBtn).CornerRadius = UDim.new(0, 10)
addGlow(nameBtn, 0.6, false)

local noclipBtn = Instance.new("TextButton")
noclipBtn.Size = UDim2.new(0.52, 0, 0, 34)
noclipBtn.Position = UDim2.new(0.05, 0, 0.50, 0)
noclipBtn.BackgroundColor3 = COLOR_BG_LIGHT
noclipBtn.BackgroundTransparency = 0.5
noclipBtn.TextColor3 = COLOR_TEXT
noclipBtn.Font = Enum.Font.GothamMedium
noclipBtn.TextSize = 13
noclipBtn.Text = "Noclip: ปิด"
noclipBtn.Parent = main
Instance.new("UICorner", noclipBtn).CornerRadius = UDim.new(0, 10)
addGlow(noclipBtn, 0.6, false)

local distLbl = Instance.new("TextLabel")
distLbl.Size = UDim2.new(0.52, 0, 0, 34)
distLbl.Position = UDim2.new(0.05, 0, 0.58, 0)
distLbl.BackgroundColor3 = COLOR_BG_LIGHT
distLbl.BackgroundTransparency = 0.5
distLbl.Text = "ระยะชื่อ"
distLbl.TextColor3 = COLOR_TEXT
distLbl.Font = Enum.Font.GothamMedium
distLbl.TextSize = 13
distLbl.Parent = main
Instance.new("UICorner", distLbl).CornerRadius = UDim.new(0, 10)
addGlow(distLbl, 0.6, false)

local distBox = Instance.new("TextBox")
distBox.Size = UDim2.new(0.3, 0, 0, 34)
distBox.Position = UDim2.new(0.63, 0, 0.58, 0)
distBox.BackgroundColor3 = COLOR_BG_LIGHT
distBox.BackgroundTransparency = 0.5
distBox.Text = "800"
distBox.TextColor3 = COLOR_ACCENT
distBox.Font = Enum.Font.GothamBold
distBox.TextSize = 13
distBox.Parent = main
Instance.new("UICorner", distBox).CornerRadius = UDim.new(0, 10)
addGlow(distBox, 0.5, false)

local openListBtn = Instance.new("TextButton")
openListBtn.Size = UDim2.new(0.9, 0, 0, 34)
openListBtn.Position = UDim2.new(0.05, 0, 0.68, 0)
openListBtn.BackgroundColor3 = COLOR_BG_LIGHT
openListBtn.BackgroundTransparency = 0.5
openListBtn.Text = "เปิดเมนูรายชื่อ"
openListBtn.TextColor3 = COLOR_TEXT
openListBtn.Font = Enum.Font.GothamMedium
openListBtn.TextSize = 13
openListBtn.Parent = main
Instance.new("UICorner", openListBtn).CornerRadius = UDim.new(0, 10)
addGlow(openListBtn, 0.6, false)

local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0.9, 0, 0, 34)
killBtn.Position = UDim2.new(0.05, 0, 0.77, 0)
killBtn.BackgroundColor3 = Color3.fromRGB(80, 15, 15)
killBtn.BackgroundTransparency = 0.3
killBtn.Text = "ปิดสคริปต์ทั้งหมด"
killBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = 13
killBtn.Parent = main
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 10)
local ks = Instance.new("UIStroke", killBtn)
ks.Color = Color3.fromRGB(255, 60, 60)
ks.Thickness = 1.5
ks.Transparency = 0.4

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.9, 0, 0, 34)
closeBtn.Position = UDim2.new(0.05, 0, 0.86, 0)
closeBtn.BackgroundColor3 = COLOR_BG_LIGHT
closeBtn.BackgroundTransparency = 0.5
closeBtn.Text = "ซ่อนเมนู"
closeBtn.TextColor3 = COLOR_TEXT_DIM
closeBtn.Font = Enum.Font.GothamMedium
closeBtn.TextSize = 13
closeBtn.Parent = main
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)
addGlow(closeBtn, 0.7, false)

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
addGlow(pad, 0.4, false)

local function mkPBtn(txt, pos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 50, 0, 50)
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(60, 40, 0)
    b.BackgroundTransparency = 0.3
    b.Text = txt
    b.TextColor3 = COLOR_TEXT
    b.Font = Enum.Font.GothamBold
    b.TextSize = 20
    b.Parent = pad
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    addGlow(b, 0.4, false)
    return b
end

local bU = mkPBtn("↑", UDim2.new(0.5, -25, 0, 5))
local bD = mkPBtn("↓", UDim2.new(0.5, -25, 1, -55))
local bL = mkPBtn("←", UDim2.new(0, 5, 0.5, -25))
local bR = mkPBtn("→", UDim2.new(1, -55, 0.5, -25))
local bF = mkPBtn("W", UDim2.new(0.5, -25, 0.5, -25))

local function bind(b, key)
    b.MouseButton1Down:Connect(function() dirs[key] = true; b.BackgroundColor3 = COLOR_ACTIVE end)
    b.MouseButton1Up:Connect(function() dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(60, 40, 0) end)
    b.MouseLeave:Connect(function() dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(60, 40, 0) end)
end
bind(bU,"U") bind(bD,"D") bind(bL,"L") bind(bR,"R") bind(bF,"F")

-- ============================================
-- Input (PC)
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
        noclipEnabled = not noclipEnabled
        noclipBtn.Text = noclipEnabled and "Noclip: เปิด" or "Noclip: ปิด"
        noclipBtn.BackgroundColor3 = noclipEnabled and Color3.fromRGB(120, 90, 0) or COLOR_BG_LIGHT
        savedState.noclip = noclipEnabled
        if noclipEnabled then
            enableNoclip()
        else
            disableNoclip()
        end
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
-- เมนูเช็คชื่อ
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
addGlow(checkMenu, 0.4, false)

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
cTitle.Font = Enum.Font.GothamBold
cTitle.TextSize = 16
cTitle.Parent = checkMenu

local stopSpecBtn = Instance.new("TextButton")
stopSpecBtn.Size = UDim2.new(0.9, 0, 0, 34)
stopSpecBtn.Position = UDim2.new(0.05, 0, 0, 60)
stopSpecBtn.BackgroundColor3 = Color3.fromRGB(80, 15, 15)
stopSpecBtn.BackgroundTransparency = 0.3
stopSpecBtn.Text = "ปิดส่องกล้อง"
stopSpecBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
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
cCloseBtn.Font = Enum.Font.GothamMedium
cCloseBtn.TextSize = 13
cCloseBtn.Parent = checkMenu
Instance.new("UICorner", cCloseBtn).CornerRadius = UDim.new(0, 10)
addGlow(cCloseBtn, 0.7, false)

-- ============================================
-- Helper
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
            local ok, track = pcall(function()
                return runAnimator:LoadAnimation(anim)
            end)
            if ok and track then return track end
        end
    end
    local fb = Instance.new("Animation")
    fb.AnimationId = "rbxassetid://507767714"
    local ok, track = pcall(function()
        return runAnimator:LoadAnimation(fb)
    end)
    if ok then return track end
    return nil
end

-- ============================================
-- Noclip System
-- ============================================
local noclipConnection = nil

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
                pcall(function()
                    part.CanCollide = true
                end)
            end
        end
    end
end

noclipBtn.MouseButton1Click:Connect(function()
    noclipEnabled = not noclipEnabled
    noclipBtn.Text = noclipEnabled and "Noclip: เปิด" or "Noclip: ปิด"
    noclipBtn.BackgroundColor3 = noclipEnabled and Color3.fromRGB(120, 90, 0) or COLOR_BG_LIGHT
    savedState.noclip = noclipEnabled
    if noclipEnabled then
        enableNoclip()
    else
        disableNoclip()
    end
end)

-- ============================================
-- ★ Toggle Functions (เรียกใช้ได้จากหลายที่)
-- ============================================
local function toggleSpeed()
    if not canToggle() then return end
    speedEnabled = not speedEnabled
    spdBtn.Text = speedEnabled and "วิ่งไว: เปิด" or "วิ่งไว: ปิด"
    spdBtn.BackgroundColor3 = speedEnabled and Color3.fromRGB(120, 90, 0) or COLOR_BG_LIGHT
    savedState.speed = speedEnabled
    savedState.speedVal = runSpeed
    if not speedEnabled and humanoid and humanoid.Parent then humanoid.WalkSpeed = 16 end
end

local function toggleFly()
    if not canToggle() then return end
    flyEnabled = not flyEnabled
    flyBtn.Text = flyEnabled and "บินได้: เปิด" or "บินได้: ปิด"
    flyBtn.BackgroundColor3 = flyEnabled and Color3.fromRGB(120, 90, 0) or COLOR_BG_LIGHT
    savedState.fly = flyEnabled
    savedState.flyVal = flySpeed
    if flyEnabled then startFly() else stopFly() end
end

-- ============================================
-- ★ วิ่งไว
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
-- ★ บิน
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

    if isMobile then
        pad.Visible = true
    end
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
        if speedEnabled then
            humanoid.WalkSpeed = runSpeed
        else
            humanoid.WalkSpeed = 16
        end
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

        if isPC then            if pcKeys.W then mv = mv + cam.CFrame.LookVector end
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
-- ★ Hotkey Listener (Q/E + Numpad) — หลัง startFly พร้อมใช้
-- ============================================
local function isHotkeyPressed(inputKey, keyList)
    for _, k in ipairs(keyList) do
        if inputKey == k then return true end
    end
    return false
end

if isPC then
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        
        if isHotkeyPressed(input.KeyCode, hotkeys.speed.keys) then
            if not hotkeys.speed.pressed then
                hotkeys.speed.pressed = true
                toggleSpeed()
            end
        end
        
        if isHotkeyPressed(input.KeyCode, hotkeys.fly.keys) then
            if not hotkeys.fly.pressed then
                hotkeys.fly.pressed = true
                toggleFly()
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if isHotkeyPressed(input.KeyCode, hotkeys.speed.keys) then
            hotkeys.speed.pressed = false
        end
        if isHotkeyPressed(input.KeyCode, hotkeys.fly.keys) then
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
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(120, 90, 0) or COLOR_BG_LIGHT
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
    lbl.TextColor3 = Color3.fromRGB(255, 220, 100)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(80, 40, 0)
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
    nameBtn.BackgroundColor3 = nameEnabled and Color3.fromRGB(120, 90, 0) or COLOR_BG_LIGHT
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
            if myHum then
                cam.CameraSubject = myHum
            end
        end
    end
end

local function spectatePlayer(targetPlayer)
    if not targetPlayer then return end
    local targetChar = targetPlayer.Character
    if not targetChar then
        local ok = pcall(function()
            targetChar = targetPlayer.CharacterAdded:Wait()
        end)
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
        local ok = pcall(function()
            targetChar = targetPlayer.CharacterAdded:Wait()
        end)
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

            local distLbl = Instance.new("TextLabel")
            distLbl.Size = UDim2.new(0.13, 0, 1, 0)
            distLbl.Position = UDim2.new(0.57, 0, 0, 0)
            distLbl.BackgroundTransparency = 1
            distLbl.Text = "-"
            distLbl.TextColor3 = COLOR_ACCENT
            distLbl.Font = Enum.Font.GothamBold
            distLbl.TextSize = 10
            distLbl.Parent = row

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
            local tps = Instance.new("UIStroke", tpBtn)
            tps.Color = COLOR_ACCENT; tps.Thickness = 1; tps.Transparency = 0.3

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
            local sps = Instance.new("UIStroke", specBtn)
            sps.Color = COLOR_ACCENT; sps.Thickness = 1; sps.Transparency = 0.3

            specBtn.MouseButton1Click:Connect(function()
                spectatePlayer(p)
            end)

            table.insert(playerRows, {row = row, player = p, distLbl = distLbl})
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
        if checkMenu.Visible then
            refreshPlayerList()
        end
    end
end)

task.spawn(function()
    while scriptAlive do
        task.wait(0.5)
        if checkMenu.Visible then
            for _, data in pairs(playerRows) do
                local p = data.player
                local distLbl = data.distLbl
                if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                   and rootPart and rootPart.Parent then
                    local d = (p.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
                    distLbl.Text = math.floor(d) .. "m"
                else
                    distLbl.Text = "-"
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

local function killScript()
    scriptAlive = false
    speedEnabled, flyEnabled, espEnabled, nameEnabled, noclipEnabled = false, false, false, false, false
    stopFly()
    stopSpectate()
    disableNoclip()
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
        spdBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 0)
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
        flyBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 0)
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
        espBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 0)
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
        nameBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 0)
        refreshNames()
    else
        nameEnabled = false
        nameBtn.Text = "เห็นชื่อ: ปิด"
        nameBtn.BackgroundColor3 = COLOR_BG_LIGHT
    end

    if savedState.noclip then
        noclipEnabled = true
        noclipBtn.Text = "Noclip: เปิด"
        noclipBtn.BackgroundColor3 = Color3.fromRGB(120, 90, 0)
        enableNoclip()
    else
        noclipEnabled = false
        noclipBtn.Text = "Noclip: ปิด"
        noclipBtn.BackgroundColor3 = COLOR_BG_LIGHT
    end

    for k in pairs(dirs) do dirs[k] = false end
end)

print("Boom script loaded OK | By Boomxico | V4 Golden + Hotkey | Platform:", isPC and "PC" or (isMobile and "Mobile" or "Other"))
