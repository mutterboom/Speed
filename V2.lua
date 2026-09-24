-- ============================================
-- By boom | วิ่งไว + บินได้ (จอยเดิม) + มองทะลุ + เห็นชื่อ
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
local flyUp, flyDown = false, false

local espObjects, nameObjects = {}, {}

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
main.Size = UDim2.new(0, 240, 0, 320)
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

local spdBtn, spdBox = mkRow(0.16)
spdBtn.Text = "วิ่งไว: ปิด"; spdBox.Text = "50"

local flyBtn, flyBox = mkRow(0.34)
flyBtn.Text = "บินได้: ปิด"; flyBox.Text = "50"

local espBtn, espBox = mkRow(0.52)
espBtn.Text = "มองทะลุ: ปิด"; espBox.Visible = false

local nameBtn, nameBox = mkRow(0.70)
nameBtn.Text = "เห็นชื่อ: ปิด"; nameBox.Visible = false

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0.9, 0, 0, 34)
closeBtn.Position = UDim2.new(0.05, 0, 0.88, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "ปิดเมนู"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 14
closeBtn.Parent = main
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 17)

-- ============ ปุ่มขึ้น/ลง ลอย (เฉพาะตอนบิน) ============
local upBtn = Instance.new("TextButton")
upBtn.Size = UDim2.new(0, 55, 0, 55)
upBtn.Position = UDim2.new(1, -80, 0.5, -70)
upBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
upBtn.Text = "⬆"
upBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
upBtn.Font = Enum.Font.SourceSansBold
upBtn.TextSize = 24
upBtn.Visible = false
upBtn.Parent = gui
Instance.new("UICorner", upBtn).CornerRadius = UDim.new(1, 0)

local dnBtn = Instance.new("TextButton")
dnBtn.Size = UDim2.new(0, 55, 0, 55)
dnBtn.Position = UDim2.new(1, -80, 0.5, 10)
dnBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
dnBtn.Text = "⬇"
dnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
dnBtn.Font = Enum.Font.SourceSansBold
dnBtn.TextSize = 24
dnBtn.Visible = false
dnBtn.Parent = gui
Instance.new("UICorner", dnBtn).CornerRadius = UDim.new(1, 0)

upBtn.MouseButton1Down:Connect(function() flyUp = true; upBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100) end)
upBtn.MouseButton1Up:Connect(function() flyUp = false; upBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200) end)
upBtn.MouseLeave:Connect(function() flyUp = false; upBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200) end)

dnBtn.MouseButton1Down:Connect(function() flyDown = true; dnBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100) end)
dnBtn.MouseButton1Up:Connect(function() flyDown = false; dnBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200) end)
dnBtn.MouseLeave:Connect(function() flyDown = false; dnBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200) end)

-- ============ ปุ่มพับ ============
toggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    main.Visible = isOpen
    toggleBtn.BackgroundColor3 = isOpen and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(200, 100, 0)
end)

-- ============ วิ่งไว ============
spdBtn.MouseButton1Click:Connect(function()
    speedEnabled = not speedEnabled
    spdBtn.Text = speedEnabled and "วิ่งไว: เปิด" or "วิ่งไว: ปิด"
    spdBtn.BackgroundColor3 = speedEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 70)
    if not speedEnabled and humanoid and humanoid.Parent then humanoid.WalkSpeed = 16 end
end)

spdBox.FocusLost:Connect(function()
    local v = tonumber(spdBox.Text)
    if v and v > 0 then runSpeed = v else spdBox.Text = "50"; runSpeed = 50 end
end)

RunService.Heartbeat:Connect(function()
    if speedEnabled and humanoid and humanoid.Parent == character then
        humanoid.WalkSpeed = runSpeed
    end
end)

-- ============ บิน (ใช้ Humanoid.MoveDirection จากจอยเดิม) ============
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
    humanoid.PlatformStand = true
    upBtn.Visible = true
    dnBtn.Visible = true
end

local function stopFly()
    if bodyVel then bodyVel:Destroy(); bodyVel = nil end
    if bodyGyro then bodyGyro:Destroy(); bodyGyro = nil end
    if humanoid and humanoid.Parent == character then
        humanoid.PlatformStand = false
        humanoid.WalkSpeed = speedEnabled and runSpeed or 16
    end
    upBtn.Visible = false
    dnBtn.Visible = false
    flyUp, flyDown = false, false
end

flyBtn.MouseButton1Click:Connect(function()
    flyEnabled = not flyEnabled
    flyBtn.Text = flyEnabled and "บินได้: เปิด" or "บินได้: ปิด"
    flyBtn.BackgroundColor3 = flyEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 70)
    if flyEnabled then startFly() else stopFly() end
end)

flyBox.FocusLost:Connect(function()
    local v = tonumber(flyBox.Text)
    if v and v > 0 then flySpeed = v else flyBox.Text = "50"; flySpeed = 50 end
end)

RunService.RenderStepped:Connect(function()
    if flyEnabled and bodyVel and rootPart.Parent == character then
        if not humanoid.PlatformStand then humanoid.PlatformStand = true end
        if bodyGyro then bodyGyro.CFrame = workspace.CurrentCamera.CFrame end

        local cam = workspace.CurrentCamera
        local mv = Vector3.new(0, 0, 0)

        -- ใช้ทิศทางจากจอยเดินเดิม (Humanoid.MoveDirection)
        local move = humanoid.MoveDirection
        if move.Magnitude > 0 then
            -- แปลงทิศจาก world → camera-relative
            local camLook = cam.CFrame.LookVector
            local camRight = cam.CFrame.RightVector
            local flatLook = Vector3.new(camLook.X, 0, camLook.Z).Unit
            local flatRight = Vector3.new(camRight.X, 0, camRight.Z).Unit
            mv = (flatLook * move.Z + flatRight * move.X)
        end

        -- ปุ่มขึ้น/ลง
        if flyUp then mv = mv + Vector3.new(0, 1, 0) end
        if flyDown then mv = mv - Vector3.new(0, 1, 0) end

        bodyVel.Velocity = mv.Magnitude > 0 and (mv.Unit * flySpeed) or Vector3.new(0, 0, 0)
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
    espEnabled = not espEnabled
    espBtn.Text = espEnabled and "มองทะลุ: เปิด" or "มองทะลุ: ปิด"
    espBtn.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 70)
    refreshESP()
end)

-- ============ เห็นชื่อ (เล็กตามระยะ) ============
local function clearNames()
    for _, obj in pairs(nameObjects) do if obj then obj:Destroy() end end
    nameObjects = {}
end

local function applyName(char, pName)
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local bg = Instance.new("BillboardGui")
    bg.Name = "BoomName"
    bg.Size = UDim2.new(0, 100, 0, 24)     -- เล็กลง
    bg.StudsOffset = Vector3.new(0, 2.5, 0)
    bg.AlwaysOnTop = false                  -- ปิด → เล็กลงตามระยะ
    bg.LightInfluence = 1
    bg.MaxDistance = 150                    -- มองเห็นไม่เกิน 150 studs
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
    lbl.TextSize = 14                       -- คงที่ ไม่ขยาย
    lbl.Parent = bg

    table.insert(nameObjects, bg)
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
    nameEnabled = not nameEnabled
    nameBtn.Text = nameEnabled and "เห็นชื่อ: เปิด" or "เห็นชื่อ: ปิด"
    nameBtn.BackgroundColor3 = nameEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 70)
    refreshNames()
end)

-- ผู้เล่นเข้า/ออก
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(c)
        task.wait(0.5)
        if espEnabled then applyESP(c) end
        if nameEnabled then applyName(c, p.Name) end
    end)
end)
Players.PlayerRemoving:Connect(function() refreshESP(); refreshNames() end)

for _, p in pairs(Players:GetPlayers()) do
    if p ~= player then
        p.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            if espEnabled then applyESP(c) end
            if nameEnabled then applyName(c, p.Name) end
        end)
    end
end

-- ============ ปิดเมนู ============
closeBtn.MouseButton1Click:Connect(function()
    stopFly()
    speedEnabled, espEnabled, nameEnabled = false, false, false
    clearESP(); clearNames()
    if humanoid and humanoid.Parent == character then humanoid.WalkSpeed = 16 end
    gui:Destroy()
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
    upBtn.Visible = false; dnBtn.Visible = false
    task.wait(1)
    refreshESP(); refreshNames()
end)
