-- ============================================
-- By Boomxico | Modern Dark Crimson UI (v3.0 FIXED)
-- Single File | Run Ready | Fly Working
-- ============================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")

local isMobile = UserInputService.TouchEnabled

-- ===================== STATE =====================
local speedEnabled, flyEnabled, noclipEnabled = false, false, false
local infJumpEnabled, espEnabled, nameEnabled = false, false, false
local fullbrightEnabled, noFogEnabled = false, false

local runSpeed, flySpeed = 50, 50
local bodyVel, bodyGyro, flyConn, noclipConn = nil, nil, nil, nil
local scriptAlive = true

local pcKeys = {W=false, A=false, S=false, D=false, Space=false, Shift=false}
local dirs   = {F=false, B=false, L=false, R=false, U=false, D=false}

local MAX_SPEED, MAX_FLY = 200, 300
local TOGGLE_COOLDOWN = 0.3
local lastToggleTime = 0
local NAME_MAX_DIST = 800

local espObjects, nameObjects, connections = {}, {}, {}

local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient = Lighting.Ambient,
}

-- ===================== COLORS =====================
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

-- ===================== HELPERS =====================
local function canToggle()
    local now = tick()
    if now - lastToggleTime < TOGGLE_COOLDOWN then return false end
    lastToggleTime = now
    return true
end

local function safeDestroy(obj)
    if obj and obj.Parent then pcall(function() obj:Destroy() end) end
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

-- ===================== FLY SYSTEM (FIXED v3) =====================
local function applyFlyProtection()
    if not humanoid or not humanoid.Parent then return end
    pcall(function()
        humanoid.PlatformStanding = true
        humanoid.Sit = false
        humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
        humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    end)
end

local function createFlyBodies()
    if not rootPart or not rootPart.Parent then return end
    if bodyVel then safeDestroy(bodyVel) end
    if bodyGyro then safeDestroy(bodyGyro) end

    bodyVel = Instance.new("BodyVelocity")
    bodyVel.Name = "BoomFlyVel"
    bodyVel.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bodyVel.P = 12500
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = rootPart

    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "BoomFlyGyro"
    bodyGyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
    bodyGyro.P = 12500
    bodyGyro.CFrame = Workspace.CurrentCamera.CFrame
    bodyGyro.Parent = rootPart
end

local function stopFly()
    flyEnabled = false
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if bodyVel then safeDestroy(bodyVel) bodyVel = nil end
    if bodyGyro then safeDestroy(bodyGyro) bodyGyro = nil end
    if humanoid and humanoid.Parent then
        pcall(function() humanoid.PlatformStanding = false end)
    end
    if flyBtn then
        flyBtn.Text = "บินได้: ปิด"
        flyBtn.TextColor3 = COLOR_TEXT
    end
end

local function startFly()
    if not rootPart or not rootPart.Parent then
        warn("[Fly] rootPart หาย")
        return false
    end
    if not humanoid or not humanoid.Parent then
        warn("[Fly] humanoid หาย")
        return false
    end

    flyEnabled = true
    applyFlyProtection()
    createFlyBodies()

    if flyConn then flyConn:Disconnect() end
    flyConn = RunService.RenderStepped:Connect(function()
        if not flyEnabled then return end
        if not rootPart or not rootPart.Parent then stopFly() return end
        if not humanoid or not humanoid.Parent then stopFly() return end
        if not bodyVel or not bodyVel.Parent then createFlyBodies() end
        if not bodyGyro or not bodyGyro.Parent then createFlyBodies() end

        applyFlyProtection()

        local cam = Workspace.CurrentCamera
        bodyGyro.CFrame = cam.CFrame

        local moveDir = Vector3.zero
        local camCF = cam.CFrame

        if pcKeys.W then moveDir = moveDir + camCF.LookVector end
        if pcKeys.S then moveDir = moveDir - camCF.LookVector end
        if pcKeys.A then moveDir = moveDir - camCF.RightVector end
        if pcKeys.D then moveDir = moveDir + camCF.RightVector end
        if pcKeys.Space then moveDir = moveDir + Vector3.new(0,1,0) end
        if pcKeys.Shift then moveDir = moveDir - Vector3.new(0,1,0) end

        if dirs.F then moveDir = moveDir + camCF.LookVector end
        if dirs.B then moveDir = moveDir - camCF.LookVector end
        if dirs.L then moveDir = moveDir - camCF.RightVector end
        if dirs.R then moveDir = moveDir + camCF.RightVector end
        if dirs.U then moveDir = moveDir + Vector3.new(0,1,0) end
        if dirs.D then moveDir = moveDir - Vector3.new(0,1,0) end

        if isMobile and humanoid.MoveDirection.Magnitude > 0.1 then
            local md = humanoid.MoveDirection
            moveDir = moveDir + (camCF.LookVector * -md.Z) + (camCF.RightVector * md.X)
        end

        if moveDir.Magnitude > 0 then
            bodyVel.Velocity = moveDir.Unit * flySpeed
        else
            bodyVel.Velocity = Vector3.zero
        end

        pcall(function()
            rootPart.RotVelocity = Vector3.zero
            rootPart.AssemblyAngularVelocity = Vector3.zero
        end)
    end)

    return true
end

-- ===================== GUI =====================
local gui = Instance.new("ScreenGui")
gui.Name = "ByBoomMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Toggle Button
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

-- Main
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 280, 0, 480)
main.Position = UDim2.new(0, 20, 0, 180)
main.BackgroundColor3 = COLOR_BG
main.BackgroundTransparency = 0.15
main.Active = true
main.Draggable = true
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
applyStroke(main, COLOR_BORDER, 1.2, 0.3)

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, 0, 0, 3)
topLine.BackgroundColor3 = COLOR_ACCENT
topLine.BorderSizePixel = 0
topLine.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 12, 0, 3)
title.BackgroundTransparency = 1
title.Text = "BY BOOMXICO (v3.0)"
title.TextColor3 = COLOR_TEXT
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local mainScroll = Instance.new("ScrollingFrame")
mainScroll.Size = UDim2.new(1, -16, 1, -50)
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

-- ===================== UI BUILDERS =====================
local function updateToggleUI(btn, enabled, label)
    if label then
        btn.Text = label .. (enabled and ": เปิด" or ": ปิด")
    else
        btn.Text = enabled and "เปิด" or "ปิด"
        btn.BackgroundColor3 = enabled and COLOR_ACTIVE or COLOR_OFF
        btn.TextColor3 = enabled and Color3.fromRGB(255,255,255) or COLOR_SUBTEXT
    end
end

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

    return btn, box, card
end

-- ===================== สร้างปุ่ม =====================
local spdBtn, spdBox = mkRow("วิ่งไว", "50")
local flyBtn, flyBox = mkRow("บินได้", "50")
local noclipBtn = mkToggle("Noclip")
local infJumpBtn = mkToggle("Infinite Jump")
local fullbrightBtn = mkToggle("Fullbright")
local noFogBtn = mkToggle("No Fog")
local espBtn = mkToggle("มองทะลุ (ESP)")
local nameBtn = mkToggle("แสดงชื่อผู้เล่น")

local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0.92, 0, 0, 32)
killBtn.Position = UDim2.new(0.04, 0, 1, -40)
killBtn.BackgroundColor3 = COLOR_KILL
killBtn.BackgroundTransparency = 0.15
killBtn.Text = "Close Script"
killBtn.TextColor3 = COLOR_TEXT
killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = 12
killBtn.Parent = main
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 8)

toggleBtn.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

-- ===================== SPEED =====================
spdBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    speedEnabled = not speedEnabled
    updateToggleUI(spdBtn, speedEnabled, "วิ่งไว")
    if humanoid then
        humanoid.WalkSpeed = speedEnabled and runSpeed or 16
    end
end)

spdBox.FocusLost:Connect(function()
    local v = tonumber(spdBox.Text)
    if v then
        runSpeed = math.clamp(v, 1, MAX_SPEED)
        spdBox.Text = tostring(runSpeed)
        if speedEnabled and humanoid then humanoid.WalkSpeed = runSpeed end
    else
        spdBox.Text = tostring(runSpeed)
    end
end)

-- ===================== FLY =====================
flyBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    if flyEnabled then
        stopFly()
    else
        local ok = startFly()
        if ok then
            flyBtn.Text = "บินได้: เปิด"
            flyBtn.TextColor3 = COLOR_ACCENT
        end
    end
end)

flyBox.FocusLost:Connect(function()
    local v = tonumber(flyBox.Text)
    if v then
        flySpeed = math.clamp(v, 1, MAX_FLY)
        flyBox.Text = tostring(flySpeed)
    else
        flyBox.Text = tostring(flySpeed)
    end
end)

-- ===================== NOCLIP =====================
noclipBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    noclipEnabled = not noclipEnabled
    updateToggleUI(noclipBtn, noclipEnabled)
    if noclipEnabled then
        if noclipConn then noclipConn:Disconnect() end
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
end)

-- ===================== INFINITE JUMP =====================
infJumpBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    infJumpEnabled = not infJumpEnabled
    updateToggleUI(infJumpBtn, infJumpEnabled)
end)

addConn(UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and humanoid and humanoid.Parent then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- ===================== LIGHTING =====================
fullbrightBtn.MouseButton1Click:Connect(function()
    fullbrightEnabled = not fullbrightEnabled
    updateToggleUI(fullbrightBtn, fullbrightEnabled)
    if fullbrightEnabled then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
        Lighting.Ambient = Color3.fromRGB(128,128,128)
    else
        for k, v in pairs(originalLighting) do Lighting[k] = v end
    end
end)

noFogBtn.MouseButton1Click:Connect(function()
    noFogEnabled = not noFogEnabled
    updateToggleUI(noFogBtn, noFogEnabled)
    if noFogEnabled then
        Lighting.FogStart = 1e6
        Lighting.FogEnd = 1e6
    else
        Lighting.FogStart = originalLighting.FogStart
        Lighting.FogEnd = originalLighting.FogEnd
    end
end)

-- ===================== ESP =====================
local function createESP(targetPlayer)
    if targetPlayer == player or espObjects[targetPlayer] then return end
    if not targetPlayer.Character then return end
    local hl = Instance.new("Highlight")
    hl.Name = "BoomESP"
    hl.FillColor = COLOR_ACCENT
    hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.fromRGB(255,255,255)
    hl.Adornee = targetPlayer.Character
    hl.Parent = gui
    espObjects[targetPlayer] = hl
end

local function removeESP(targetPlayer)
    if espObjects[targetPlayer] then
        safeDestroy(espObjects[targetPlayer])
        espObjects[targetPlayer] = nil
    end
end

espBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    espEnabled = not espEnabled
    updateToggleUI(espBtn, espEnabled)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            if espEnabled then createESP(p) else removeESP(p) end
        end
    end
end)

-- ===================== NAME TAGS =====================
local function createNameTag(targetPlayer)
    if targetPlayer == player or nameObjects[targetPlayer] then return end
    local bb = Instance.new("BillboardGui")
    bb.Name = "BoomNameTag"
    bb.Size = UDim2.new(0, 160, 0, 30)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = gui

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 1
    txt.Text = targetPlayer.DisplayName
    txt.TextColor3 = COLOR_ACCENT
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 12
    txt.TextStrokeTransparency = 0.2
    txt.Parent = bb

    nameObjects[targetPlayer] = {Gui = bb, Text = txt}
end

local function removeNameTag(targetPlayer)
    if nameObjects[targetPlayer] then
        safeDestroy(nameObjects[targetPlayer].Gui)
        nameObjects[targetPlayer] = nil
    end
end

nameBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    nameEnabled = not nameEnabled
    updateToggleUI(nameBtn, nameEnabled)
    if nameEnabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then createNameTag(p) end
        end
    else
        for p, _ in pairs(nameObjects) do removeNameTag(p) end
    end
end)

-- ===================== PLAYER EVENTS =====================
addConn(Players.PlayerAdded:Connect(function(p)
    if espEnabled then createESP(p) end
    if nameEnabled then createNameTag(p) end
end))

addConn(Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
    removeNameTag(p)
end))

-- ===================== NAME TAG LOOP =====================
addConn(RunService.RenderStepped:Connect(function()
    if not scriptAlive then return end
    if not nameEnabled or not rootPart or not rootPart.Parent then return end

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
end))

-- ===================== INPUT (PC) =====================
addConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.W then pcKeys.W = true end
    if k == Enum.KeyCode.S then pcKeys.S = true end
    if k == Enum.KeyCode.A then pcKeys.A = true end
    if k == Enum.KeyCode.D then pcKeys.D = true end
    if k == Enum.KeyCode.Space then pcKeys.Space = true end
    if k == Enum.KeyCode.LeftShift then pcKeys.Shift = true end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.W then pcKeys.W = false end
    if k == Enum.KeyCode.S then pcKeys.S = false end
    if k == Enum.KeyCode.A then pcKeys.A = false end
    if k == Enum.KeyCode.D then pcKeys.D = false end
    if k == Enum.KeyCode.Space then pcKeys.Space = false end
    if k == Enum.KeyCode.LeftShift then pcKeys.Shift = false end
end))

-- ===================== MOBILE PAD =====================
if isMobile then
    local pad = Instance.new("Frame")
    pad.Size = UDim2.new(0, 170, 0, 170)
    pad.Position = UDim2.new(1, -190, 0.5, -85)
    pad.BackgroundColor3 = COLOR_BG
    pad.BackgroundTransparency = 0.2
    pad.Visible = false
    pad.Parent = gui
    Instance.new("UICorner", pad).CornerRadius = UDim.new(1, 0)
    applyStroke(pad, COLOR_BORDER, 1.2, 0.3)

    local function mkPBtn(txt, pos, key)
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

        b.MouseButton1Down:Connect(function() dirs[key] = true; b.BackgroundColor3 = COLOR_ACTIVE end)
        b.MouseButton1Up:Connect(function() dirs[key] = false; b.BackgroundColor3 = COLOR_CARD end)
        b.MouseLeave:Connect(function() dirs[key] = false; b.BackgroundColor3 = COLOR_CARD end)
    end

    mkPBtn("↑", UDim2.new(0.5, -22, 0, 8), "U")
    mkPBtn("↓", UDim2.new(0.5, -22, 1, -52), "D")
    mkPBtn("←", UDim2.new(0, 8, 0.5, -22), "L")
    mkPBtn("→", UDim2.new(1, -52, 0.5, -22), "R")
    mkPBtn("W", UDim2.new(0.5, -22, 0.5, -22), "F")

    -- แสดง pad เมื่อเปิด fly
    flyBtn.MouseButton1Click:Connect(function()
        task.wait(0.1)
        pad.Visible = flyEnabled
    end)
end

-- ===================== RESPAWN =====================
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    task.wait(0.5)
    if flyEnabled then startFly() end
    if speedEnabled and humanoid then humanoid.WalkSpeed = runSpeed end
    if noclipEnabled then
        if noclipConn then noclipConn:Disconnect() end
        noclipConn = addConn(RunService.Stepped:Connect(function()
            for _, p in ipairs(character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end))
    end
end)

-- ===================== CLEANUP =====================
killBtn.MouseButton1Click:Connect(function()
    scriptAlive = false
    stopFly()
    if noclipConn then noclipConn:Disconnect() end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    for _, obj in pairs(espObjects) do safeDestroy(obj) end
    for _, data in pairs(nameObjects) do safeDestroy(data.Gui) end
    safeDestroy(gui)
end)

game:BindToClose(function()
    stopFly()
    if noclipConn then noclipConn:Disconnect() end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
end)

print("[BoomMenu v3.0] โหลดสำเร็จ ✅")
