-- ============================================
-- By boom | วิ่งไว + บินได้ (D-Pad 6 ทิศ) + มองทะลุ + เห็นชื่อทะลุกำแพง
-- + Anti-Detection Layer + ปุ่มปิดสคริปต์ + ปรับระยะชื่อใน UI
-- ============================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local speedEnabled, flyEnabled, espEnabled, nameEnabled = false, false, false, false
local runSpeed, flySpeed = 50, 50
local bodyVel, bodyGyro
local isOpen = true
local scriptAlive = true

-- D-Pad ทิศทางบิน
local dirs = {F=false, B=false, L=false, R=false, U=false, D=false}

-- Anti-detect
local MAX_SPEED = 200
local MAX_FLY = 300
local lastToggleTime = 0
local TOGGLE_COOLDOWN = 0.4
local NAME_MAX_DIST = 800

local espObjects, nameObjects = {}, {}
local nameData = {}

-- ============ UI ============
local gui = Instance.new("ScreenGui")
gui.Name = "ByBoomMenu"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0, 55, 0, 55)
toggleBtn.Position = UDim2.new(0, 20, 0, 100)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
toggleBtn.Text = "B"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 24
toggleBtn.Active = true
toggleBtn.Draggable = true
toggleBtn.Parent = gui
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
local ts = Instance.new("UIStroke", toggleBtn)
ts.Color = Color3.fromRGB(255, 255, 255); ts.Thickness = 2

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 240, 0, 400)
main.Position = UDim2.new(0, 20, 0, 165)
main.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 20)
local ms = Instance.new("UIStroke", main)
ms.Color = Color3.fromRGB(0, 170, 255); ms.Thickness = 2

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 38)
title.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
title.Text = "Tricky | By boom"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 17
title.Parent = main
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 20)

local function mkRow(y)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.55, 0, 0, 36)
    btn.Position = UDim2.new(0.05, 0, y, 0)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 14
    btn.Parent = main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 18)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.3, 0, 0, 36)
    box.Position = UDim2.new(0.65, 0, y, 0)
    box.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 14
    box.Parent = main
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 18)
    return btn, box
end

local spdBtn, spdBox = mkRow(0.12)
spdBtn.Text = "วิ่งไว: ปิด"; spdBox.Text = "50"

local flyBtn, flyBox = mkRow(0.26)
flyBtn.Text = "บินได้: ปิด"; flyBox.Text = "50"

local espBtn, espBox = mkRow(0.40)
espBtn.Text = "มองทะลุ: ปิด"; espBox.Visible = false

local nameBtn, nameBox = mkRow(0.54)
nameBtn.Text = "เห็นชื่อ: ปิด"; nameBox.Visible = false

local distBtn = Instance.new("TextButton")
distBtn.Size = UDim2.new(0.55, 0, 0, 36)
distBtn.Position = UDim2.new(0.05, 0, 0.68, 0)
distBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
distBtn.Text = "ระยะชื่อ"
distBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
distBtn.Font = Enum.Font.SourceSans
distBtn.TextSize = 14
distBtn.Parent = main
Instance.new("UICorner", distBtn).CornerRadius = UDim.new(0, 18)

local distBox = Instance.new("TextBox")
distBox.Size = UDim2.new(0.3, 0, 0, 36)
distBox.Position = UDim2.new(0.65, 0, 0.68, 0)
distBox.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
distBox.Text = "800"
distBox.TextColor3 = Color3.fromRGB(255, 255, 255)
distBox.Font = Enum.Font.SourceSans
distBox.TextSize = 14
distBox.Parent = main
Instance.new("UICorner", distBox).CornerRadius = UDim.new(0, 18)

local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0.9, 0, 0, 34)
killBtn.Position = UDim2.new(0.05, 0, 0.83, 0)
killBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 0)
killBtn.Text = "ปิดสคริปต์ทั้งหมด"
killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
killBtn.Font = Enum.Font.SourceSansBold
killBtn.TextSize = 14
killBtn.Parent = main
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 17)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.9, 0, 0, 34)
closeBtn.Position = UDim2.new(0.05, 0, 0.93, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "ซ่อนเมนู"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 14
closeBtn.Parent = main
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 17)

-- ============ D-Pad บิน 6 ทิศ ============
local pad = Instance.new("Frame")
pad.Size = UDim2.new(0, 180, 0, 180)
pad.Position = UDim2.new(1, -200, 0.5, -90)
pad.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
pad.BackgroundTransparency = 0.3
pad.Visible = false
pad.Parent = gui
Instance.new("UICorner", pad).CornerRadius = UDim.new(1, 0)

local function mkPBtn(txt, pos)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 50, 0, 50)
    b.Position = pos
    b.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    b.Text = txt
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.SourceSansBold
    b.TextSize = 20
    b.Parent = pad
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    return b
end

local bU = mkPBtn("⬆", UDim2.new(0.5, -25, 0, 5))
local bD = mkPBtn("⬇", UDim2.new(0.5, -25, 1, -55))
local bL = mkPBtn("⬅", UDim2.new(0, 5, 0.5, -25))
local bR = mkPBtn("➡", UDim2.new(1, -55, 0.5, -25))
local bF = mkPBtn("W", UDim2.new(0.5, -25, 0.5, -25))

local function bind(b, key)
    b.MouseButton1Down:Connect(function() dirs[key] = true; b.BackgroundColor3 = Color3.fromRGB(0, 200, 100) end)
    b.MouseButton1Up:Connect(function() dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(0, 120, 200) end)
    b.MouseLeave:Connect(function() dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(0, 120, 200) end)
end
bind(bU,"U") bind(bD,"D") bind(bL,"L") bind(bR,"R") bind(bF,"F")

-- ============ ปุ่มพับ ============
toggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    main.Visible = isOpen
    toggleBtn.BackgroundColor3 = isOpen and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(200, 100, 0)
end)

-- ============ Helper ============
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

-- ============ วิ่งไว ============
spdBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    speedEnabled = not speedEnabled
    spdBtn.Text = speedEnabled and "วิ่งไว: เปิด" or "วิ่งไว: ปิด"
    spdBtn.BackgroundColor3 = speedEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 70)
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

-- ============ บิน (D-Pad 6 ทิศ) ============
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
    bodyGyro.CFrame = rootPart.CFrame
    bodyGyro.Parent = rootPart

    humanoid.PlatformStand = false
    humanoid:ChangeState(Enum.HumanoidStateType.Running)

    pad.Visible = true
end

local function stopFly()
    if bodyVel then bodyVel:Destroy(); bodyVel = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end

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
    flyBtn.Text = flyEnabled and "บินได้: เปิด" or "บินได้: ปิด"
    flyBtn.BackgroundColor3 = flyEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 70)
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
        local state = humanoid:GetState()
        if state ~= Enum.HumanoidStateType.Running then
            humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end
        humanoid.PlatformStand = false

        -- หันตัวตามกล้อง
        if bodyGyro then bodyGyro.CFrame = workspace.CurrentCamera.CFrame end

        local cam = workspace.CurrentCamera
        local mv = Vector3.new(0, 0, 0)

        -- คำนวณทิศจาก D-Pad + กล้อง
        if dirs.F then mv = mv + cam.CFrame.LookVector end
        if dirs.B then mv = mv - cam.CFrame.LookVector end
        if dirs.L then mv = mv - cam.CFrame.RightVector end
        if dirs.R then mv = mv + cam.CFrame.RightVector end
        if dirs.U then mv = mv + Vector3.new(0, 1, 0) end
        if dirs.D then mv = mv - Vector3.new(0, 1, 0) end

        local jitter = 1 + (math.random() - 0.5) * 0.03
        bodyVel.Velocity = mv.Magnitude > 0 and (mv.Unit * flySpeed * jitter) or Vector3.new(0, 0, 0)
    end
end)

-- ============ มองทะลุ (ESP) ============
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
    espBtn.Text = espEnabled and "มองทะลุ: เปิด" or "มองทะลุ: ปิด"
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 70)
    refreshESP()
end)

-- ============ เห็นชื่อ ============
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
    lbl.Font = Enum.Font.SourceSansBold
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
    nameBtn.BackgroundColor3 = nameEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 70)
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
            local dirToHead = delta.Unit
            local dot = camLook:Dot(dirToHead)

            if dot < 0.15 then
                bg.Enabled = false
            else
                local screenPoint, onScreen = cam:WorldToViewportPoint(headPos)
                if onScreen and screenPoint.Z > 0
                   and screenPoint.X > -50 and screenPoint.X < viewport.X + 50
                   and screenPoint.Y > -50 and screenPoint.Y < viewport.Y + 50 then
                    bg.Enabled = true
                else
                    bg.Enabled = false
                end
            end
        end
    end
end)

-- ============ ผู้เล่นเข้า/ออก ============
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

-- ============ ปุ่มปิดสคริปต์ทั้งหมด ============
local function killScript()
    scriptAlive = false
    speedEnabled, flyEnabled, espEnabled, nameEnabled = false, false, false, false
    stopFly()
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

-- ============ ซ่อนเมนู ============
closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    isOpen = false
    toggleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
end)

-- ============ เกิดใหม่ ============
player.CharacterAdded:Connect(function(nc)
    character = nc
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    speedEnabled, flyEnabled = false, false
    spdBtn.Text = "วิ่งไว: ปิด"; spdBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    flyBtn.Text = "บินได้: ปิด"; flyBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    if bodyVel then bodyVel:Destroy(); bodyVel = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    pad.Visible = false
    for k in pairs(dirs) do dirs[k] = false end
    task.wait(1)
    if not scriptAlive then return end
    refreshESP(); refreshNames()
end)
