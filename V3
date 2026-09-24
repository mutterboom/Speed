-- ============================================
-- By Boomxico | iOS Glass UI + Anti-Detect
-- วิ่งไว + บินได้ + มองทะลุ + เห็นชื่อ + เช็คชื่อ
-- ============================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local isPC = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
local isMobile = UserInputService.TouchEnabled

local speedEnabled, flyEnabled, espEnabled, nameEnabled = false, false, false, false
local runSpeed, flySpeed = 50, 50
local bodyVel, bodyGyro
local isOpen = true
local scriptAlive = true

local dirs = {F=false, B=false, L=false, R=false, U=false, D=false}
local pcKeys = {W=false, A=false, S=false, D=false, Space=false, Shift=false}

-- อนิเมชั่นวิ่ง
local runAnimator = humanoid:FindFirstChildOfClass("Animator")
if not runAnimator then
    runAnimator = Instance.new("Animator")
    runAnimator.Parent = humanoid
end
local runAnimTrack = nil

-- ส่องกล้อง
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
-- สร้าง Blur Effect (iOS Glass)
-- ============================================
local blur = Instance.new("BlurEffect")
blur.Name = "BoomBlur"
blur.Size = 0  -- เริ่มที่ 0 ไม่ให้เกมเบลอ
blur.Parent = Lighting

-- ============================================
-- UI หลัก (iOS Glass Style)
-- ============================================
local gui = Instance.new("ScreenGui")
gui.Name = "ByBoomMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- ปุ่มพับ (กลม โปร่งแสง)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 55, 0, 55)
toggleBtn.Position = UDim2.new(0, 20, 0, 100)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
toggleBtn.BackgroundTransparency = 0.35
toggleBtn.Text = "B"
toggleBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 24
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.Parent = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
local ts = Instance.new("UIStroke", toggleBtn)
ts.Color = Color3.fromRGB(0, 200, 255)
ts.Thickness = 1.5
ts.Transparency = 0.3

-- หน้าต่างหลัก (iOS Glass Card)
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 260, 0, 400)
main.Position = UDim2.new(0, 20, 0, 165)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
main.BackgroundTransparency = 0.25  -- โปร่งแสง
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 24)
local ms = Instance.new("UIStroke", main)
ms.Color = Color3.fromRGB(0, 200, 255)
ms.Thickness = 1.2
ms.Transparency = 0.5

-- เงานุ่มด้านใน
local shadow = Instance.new("Frame")
shadow.Size = UDim2.new(1, 0, 0, 1)
shadow.Position = UDim2.new(0, 0, 1, 0)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 1
shadow.BorderSizePixel = 0
shadow.Parent = main

-- หัวข้อ Gradient
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 44)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
title.BackgroundTransparency = 0.6
title.Text = "By Boomxico"
title.TextColor3 = Color3.fromRGB(0, 200, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 14)

local titleGrad = Instance.new("UIGradient")
titleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 200, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 100, 255))
})
titleGrad.Parent = title

-- เส้นคั่นใต้หัวข้อ
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -20, 0, 1)
divider.Position = UDim2.new(0, 10, 0, 60)
divider.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
divider.BackgroundTransparency = 0.7
divider.BorderSizePixel = 0
divider.Parent = main

-- ============================================
-- ฟังก์ชันสร้างปุ่ม iOS Glass
-- ============================================
local function mkRow(y, labelText, defaultVal)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.52, 0, 0, 34)
    btn.Position = UDim2.new(0.05, 0, y, 0)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    btn.BackgroundTransparency = 0.3
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Text = labelText
    btn.Parent = main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 14)
    local bs = Instance.new("UIStroke", btn)
    bs.Color = Color3.fromRGB(80, 80, 100)
    bs.Thickness = 1
    bs.Transparency = 0.6

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.3, 0, 0, 34)
    box.Position = UDim2.new(0.63, 0, y, 0)
    box.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    box.BackgroundTransparency = 0.3
    box.Text = defaultVal
    box.TextColor3 = Color3.fromRGB(0, 200, 255)
    box.Font = Enum.Font.GothamBold
    box.TextSize = 13
    box.Parent = main
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 14)
    local bxs = Instance.new("UIStroke", box)
    bxs.Color = Color3.fromRGB(0, 200, 255)
    bxs.Thickness = 1
    bxs.Transparency = 0.5

    return btn, box
end

local spdBtn, spdBox = mkRow(0.18, "🏃 วิ่งไว: ปิด", "50")
local flyBtn, flyBox = mkRow(0.30, "✈️ บินได้: ปิด", "50")

local espBtn = Instance.new("TextButton")
espBtn.Size = UDim2.new(0.52, 0, 0, 34)
espBtn.Position = UDim2.new(0.05, 0, 0.42, 0)
espBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
espBtn.BackgroundTransparency = 0.3
espBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
espBtn.Font = Enum.Font.Gotham
espBtn.TextSize = 13
espBtn.Text = "👁️ มองทะลุ: ปิด"
espBtn.Parent = main
Instance.new("UICorner", espBtn).CornerRadius = UDim.new(0, 14)
local es = Instance.new("UIStroke", espBtn)
es.Color = Color3.fromRGB(80, 80, 100); es.Thickness = 1; es.Transparency = 0.6

local nameBtn = Instance.new("TextButton")
nameBtn.Size = UDim2.new(0.52, 0, 0, 34)
nameBtn.Position = UDim2.new(0.05, 0, 0.54, 0)
nameBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
nameBtn.BackgroundTransparency = 0.3
nameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
nameBtn.Font = Enum.Font.Gotham
nameBtn.TextSize = 13
nameBtn.Text = "📝 เห็นชื่อ: ปิด"
nameBtn.Parent = main
Instance.new("UICorner", nameBtn).CornerRadius = UDim.new(0, 14)
local ns = Instance.new("UIStroke", nameBtn)
ns.Color = Color3.fromRGB(80, 80, 100); ns.Thickness = 1; ns.Transparency = 0.6

local distLbl = Instance.new("TextLabel")
distLbl.Size = UDim2.new(0.52, 0, 0, 34)
distLbl.Position = UDim2.new(0.05, 0, 0.66, 0)
distLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
distLbl.BackgroundTransparency = 0.3
distLbl.Text = "📏 ระยะชื่อ"
distLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
distLbl.Font = Enum.Font.Gotham
distLbl.TextSize = 13
distLbl.Parent = main
Instance.new("UICorner", distLbl).CornerRadius = UDim.new(0, 14)
local ds = Instance.new("UIStroke", distLbl)
ds.Color = Color3.fromRGB(80, 80, 100); ds.Thickness = 1; ds.Transparency = 0.6

local distBox = Instance.new("TextBox")
distBox.Size = UDim2.new(0.3, 0, 0, 34)
distBox.Position = UDim2.new(0.63, 0, 0.66, 0)
distBox.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
distBox.BackgroundTransparency = 0.3
distBox.Text = "800"
distBox.TextColor3 = Color3.fromRGB(0, 200, 255)
distBox.Font = Enum.Font.GothamBold
distBox.TextSize = 13
distBox.Parent = main
Instance.new("UICorner", distBox).CornerRadius = UDim.new(0, 14)
local dbs = Instance.new("UIStroke", distBox)
dbs.Color = Color3.fromRGB(0, 200, 255); dbs.Thickness = 1; dbs.Transparency = 0.5

-- ปุ่มปิดสคริปต์ (แดง)
local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0.9, 0, 0, 34)
killBtn.Position = UDim2.new(0.05, 0, 0.82, 0)
killBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
killBtn.BackgroundTransparency = 0.15
killBtn.Text = "🛑 ปิดสคริปต์ทั้งหมด"
killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = 13
killBtn.Parent = main
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 14)
local ks = Instance.new("UIStroke", killBtn)
ks.Color = Color3.fromRGB(255, 100, 100); ks.Thickness = 1; ks.Transparency = 0.3

-- ปุ่มซ่อนเมนู (โปร่ง)
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.9, 0, 0, 34)
closeBtn.Position = UDim2.new(0.05, 0, 0.92, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
closeBtn.BackgroundTransparency = 0.3
closeBtn.Text = "❌ ซ่อนเมนู"
closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
closeBtn.Font = Enum.Font.Gotham
closeBtn.TextSize = 13
closeBtn.Parent = main
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 14)
local cbs = Instance.new("UIStroke", closeBtn)
cbs.Color = Color3.fromRGB(100, 100, 120); cbs.Thickness = 1; cbs.Transparency = 0.5

-- ============================================
-- D-Pad บิน (iOS Glass)
-- ============================================
local pad = Instance.new("Frame")
pad.Size = UDim2.new(0, 180, 0, 180)
pad.Position = UDim2.new(1, -200, 0.5, -90)
pad.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
pad.BackgroundTransparency = 0.4
pad.Visible = false
pad.Parent = gui
Instance.new("UICorner", pad).CornerRadius = UDim.new(1, 0)
local ps = Instance.new("UIStroke", pad)
ps.Color = Color3.fromRGB(0, 200, 255); ps.Thickness = 1; ps.Transparency = 0.6

local function mkPBtn(txt, pos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 50, 0, 50)
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(0, 150, 220)
    b.BackgroundTransparency = 0.2
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 20
    b.Parent = pad
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    local s = Instance.new("UIStroke", b)
    s.Color = Color3.fromRGB(0, 220, 255); s.Thickness = 1; s.Transparency = 0.4
    return b
end

local bU = mkPBtn("⬆", UDim2.new(0.5, -25, 0, 5))
local bD = mkPBtn("⬇", UDim2.new(0.5, -25, 1, -55))
local bL = mkPBtn("⬅", UDim2.new(0, 5, 0.5, -25))
local bR = mkPBtn("➡", UDim2.new(1, -55, 0.5, -25))
local bF = mkPBtn("W", UDim2.new(0.5, -25, 0.5, -25))

local function bind(b, key)
    b.MouseButton1Down:Connect(function() dirs[key] = true; b.BackgroundColor3 = Color3.fromRGB(0, 220, 100) end)
    b.MouseButton1Up:Connect(function() dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(0, 150, 220) end)
    b.MouseLeave:Connect(function() dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(0, 150, 220) end)
end
bind(bU,"U") bind(bD,"D") bind(bL,"L") bind(bR,"R") bind(bF,"F")

-- ============================================
-- คีย์บอร์ด PC
-- ============================================
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.W then pcKeys.W = true end
    if input.KeyCode == Enum.KeyCode.A then pcKeys.A = true end
    if input.KeyCode == Enum.KeyCode.S then pcKeys.S = true end
    if input.KeyCode == Enum.KeyCode.D then pcKeys.D = true end
    if input.KeyCode == Enum.KeyCode.Space then pcKeys.Space = true end
    if input.KeyCode == Enum.KeyCode.LeftShift then pcKeys.Shift = true end
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
-- ปุ่มเช็คชื่อ (iOS Glass)
-- ============================================
local checkBtn = Instance.new("TextButton")
checkBtn.Size = UDim2.new(0, 90, 0, 55)
checkBtn.Position = UDim2.new(0, 20, 0, 165)
checkBtn.BackgroundColor3 = Color3.fromRGB(130, 60, 200)
checkBtn.BackgroundTransparency = 0.2
checkBtn.Text = "เช็คชื่อ"
checkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
checkBtn.Font = Enum.Font.GothamBold
checkBtn.TextSize = 14
checkBtn.Active = true
checkBtn.Draggable = true
checkBtn.Parent = gui
Instance.new("UICorner", checkBtn).CornerRadius = UDim.new(0, 16)
local cs = Instance.new("UIStroke", checkBtn)
cs.Color = Color3.fromRGB(200, 150, 255); cs.Thickness = 1; cs.Transparency = 0.3

-- ============================================
-- เมนูเช็คชื่อ (iOS Glass)
-- ============================================
local checkMenu = Instance.new("Frame")
checkMenu.Size = UDim2.new(0, 270, 0, 400)
checkMenu.Position = UDim2.new(0.5, -135, 0.5, -200)
checkMenu.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
checkMenu.BackgroundTransparency = 0.25
checkMenu.Active = true
checkMenu.Draggable = true
checkMenu.Visible = false
checkMenu.Parent = gui
Instance.new("UICorner", checkMenu).CornerRadius = UDim.new(0, 24)
local cms = Instance.new("UIStroke", checkMenu)
cms.Color = Color3.fromRGB(150, 80, 255); cms.Thickness = 1.2; cms.Transparency = 0.5

local cTitle = Instance.new("TextLabel")
cTitle.Size = UDim2.new(1, -20, 0, 40)
cTitle.Position = UDim2.new(0, 10, 0, 10)
cTitle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
cTitle.BackgroundTransparency = 0.6
cTitle.Text = "By Boomxico"
cTitle.TextColor3 = Color3.fromRGB(200, 150, 255)
cTitle.Font = Enum.Font.GothamBold
cTitle.TextSize = 16
cTitle.Parent = checkMenu
Instance.new("UICorner", cTitle).CornerRadius = UDim.new(0, 14)

local cTitleGrad = Instance.new("UIGradient")
cTitleGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 80, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 255))
})
cTitleGrad.Parent = cTitle

local stopSpecBtn = Instance.new("TextButton")
stopSpecBtn.Size = UDim2.new(0.9, 0, 0, 32)
stopSpecBtn.Position = UDim2.new(0.05, 0, 0, 56)
stopSpecBtn.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
stopSpecBtn.BackgroundTransparency = 0.15
stopSpecBtn.Text = "❌ ปิดส่องกล้อง"
stopSpecBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stopSpecBtn.Font = Enum.Font.GothamBold
stopSpecBtn.TextSize = 13
stopSpecBtn.Parent = checkMenu
Instance.new("UICorner", stopSpecBtn).CornerRadius = UDim.new(0, 12)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(0.9, 0, 0, 270)
scroll.Position = UDim2.new(0.05, 0, 0, 96)
scroll.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
scroll.BackgroundTransparency = 0.4
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = checkMenu
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 14)

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
cCloseBtn.Size = UDim2.new(0.9, 0, 0, 32)
cCloseBtn.Position = UDim2.new(0.05, 0, 1, -42)
cCloseBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
cCloseBtn.BackgroundTransparency = 0.3
cCloseBtn.Text = "ปิดเมนู"
cCloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
cCloseBtn.Font = Enum.Font.Gotham
cCloseBtn.TextSize = 13
cCloseBtn.Parent = checkMenu
Instance.new("UICorner", cCloseBtn).CornerRadius = UDim.new(0, 12)

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

-- ============================================
-- ปุ่มพับเมนู
-- ============================================
toggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    main.Visible = isOpen
    toggleBtn.BackgroundColor3 = isOpen and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(50, 30, 0)
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
-- วิ่งไว
-- ============================================
spdBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    speedEnabled = not speedEnabled
    spdBtn.Text = speedEnabled and "🏃 วิ่งไว: เปิด" or "🏃 วิ่งไว: ปิด"
    spdBtn.BackgroundColor3 = speedEnabled and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(30, 30, 40)
    if not speedEnabled and humanoid and humanoid.Parent then humanoid.WalkSpeed = 16 end
end)

spdBox.FocusLost:Connect(function()
    local v = tonumber(spdBox.Text)
    if v and v > 0 then runSpeed = clamp(v, 1, MAX_SPEED)
    else spdBox.Text = "50"; runSpeed = 50 end
end)

RunService.Heartbeat:Connect(function()
    if not scriptAlive then return end
    if speedEnabled and humanoid and humanoid.Parent == character then
        local jitter = 1 + (math.random() - 0.5) * 0.04
        humanoid.WalkSpeed = runSpeed * jitter
    end
end)

-- ============================================
-- บิน
-- ============================================
local function startFly()
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

local function stopFly()
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

flyBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    flyEnabled = not flyEnabled
    flyBtn.Text = flyEnabled and "✈️ บินได้: เปิด" or "✈️ บินได้: ปิด"
    flyBtn.BackgroundColor3 = flyEnabled and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(30, 30, 40)
    if flyEnabled then startFly() else stopFly() end
end)

flyBox.FocusLost:Connect(function()
    local v = tonumber(flyBox.Text)
    if v and v > 0 then flySpeed = clamp(v, 1, MAX_FLY)
    else flyBox.Text = "50"; flySpeed = 50 end
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
    hl.FillColor = Color3.fromRGB(255, 0, 0)
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
    espBtn.Text = espEnabled and "👁️ มองทะลุ: เปิด" or "👁️ มองทะลุ: ปิด"
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(30, 30, 40)
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
    lbl.TextColor3 = Color3.fromRGB(255, 255, 0)
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
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
    nameBtn.Text = nameEnabled and "📝 เห็นชื่อ: เปิด" or "📝 เห็นชื่อ: ปิด"
    nameBtn.BackgroundColor3 = nameEnabled and Color3.fromRGB(0, 150, 100) or Color3.fromRGB(30, 30, 40)
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

    for _, p in pairs(players) do
        if p ~= player then
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -8, 0, 38)
            row.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
            row.BackgroundTransparency = 0.3
            row.BorderSizePixel = 0
            row.Parent = scroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.6, 0, 1, 0)
            nameLbl.Position = UDim2.new(0.02, 0, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = p.Name
            nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLbl.Font = Enum.Font.Gotham
            nameLbl.TextSize = 13
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = row

            local distLbl = Instance.new("TextLabel")
            distLbl.Size = UDim2.new(0.25, 0, 1, 0)
            distLbl.Position = UDim2.new(0.6, 0, 0, 0)
            distLbl.BackgroundTransparency = 1
            distLbl.Text = "-"
            distLbl.TextColor3 = Color3.fromRGB(0, 200, 255)
            distLbl.Font = Enum.Font.GothamBold
            distLbl.TextSize = 11
            distLbl.Parent = row

            local specBtn = Instance.new("TextButton")
            specBtn.Size = UDim2.new(0.13, 0, 0, 28)
            specBtn.Position = UDim2.new(0.86, 0, 0, 5)
            specBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
            specBtn.BackgroundTransparency = 0.15
            specBtn.Text = "ส่อง"
            specBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            specBtn.Font = Enum.Font.GothamBold
            specBtn.TextSize = 12
            specBtn.Parent = row
            Instance.new("UICorner", specBtn).CornerRadius = UDim.new(0, 8)

            specBtn.MouseButton1Click:Connect(function()
                spectatePlayer(p)
            end)

            table.insert(playerRows, {row = row, player = p, distLbl = distLbl})
        end
    end
end

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

checkBtn.MouseButton1Click:Connect(function()
    checkMenu.Visible = not checkMenu.Visible
    if checkMenu.Visible then
        refreshPlayerList()
    end
end)

cCloseBtn.MouseButton1Click:Connect(function()
    checkMenu.Visible = false
    stopSpectate()
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
    stopFly()
    stopSpectate()
    clearESP()
    clearNames()
    if humanoid and humanoid.Parent == character then
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = 16
        humanoid.JumpPower = 50
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
    if blur then blur:Destroy() end
    if gui then gui:Destroy() end
end

killBtn.MouseButton1Click:Connect(killScript)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    isOpen = false
    toggleBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 0)
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

    speedEnabled, flyEnabled = false, false
    spdBtn.Text = "🏃 วิ่งไว: ปิด"; spdBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    flyBtn.Text = "✈️ บินได้: ปิด"; flyBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    if bodyVel then bodyVel:Destroy(); bodyVel = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    pad.Visible = false
    for k in pairs(dirs) do dirs[k] = false end
    task.wait(1)
    if not scriptAlive then return end
    refreshESP(); refreshNames()
end)

print("Boom script loaded OK | By Boomxico | iOS Glass UI | Platform:", isPC and "PC" or (isMobile and "Mobile" or "Other"))
