-- ============================================
-- By Boomxico | Modern Dark Crimson UI (v2.5 FIXED)
-- ============================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Workspace        = game:GetService("Workspace")

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

local MAX_SPEED, MAX_FLY = 200, 300
local TOGGLE_COOLDOWN    = 0.35
local lastToggleTime     = 0
local NAME_MAX_DIST      = 800

local espObjects, nameObjects, playerRows, connections = {}, {}, {}, {}
local noclipConn, flyConn = nil, nil

local originalLighting = {
    Brightness     = Lighting.Brightness,
    ClockTime      = Lighting.ClockTime,
    FogEnd         = Lighting.FogEnd,
    FogStart       = Lighting.FogStart,
    GlobalShadows  = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient        = Lighting.Ambient,
}

-- ===================== Colors =====================
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

-- ===================== Character Respawn =====================
local function onCharacterAdded(newChar)
    character = newChar
    humanoid  = character:WaitForChild("Humanoid")
    rootPart  = character:WaitForChild("HumanoidRootPart")

    task.wait(0.5)
    if flyEnabled then
        startFly() -- รีสตาร์ทบินหลังเกิดใหม่
    end
    if speedEnabled and humanoid then
        humanoid.WalkSpeed = runSpeed
    end
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

function stopFly()
    flyEnabled = false
    if flyConn then flyConn:Disconnect() flyConn = nil end
    if bodyVel then safeDestroy(bodyVel) bodyVel = nil end
    if bodyGyro then safeDestroy(bodyGyro) bodyGyro = nil end
    if humanoid and humanoid.Parent then
        pcall(function() humanoid.PlatformStanding = false end)
    end
end

function startFly()
    if not rootPart or not rootPart.Parent then
        warn("[BoomFly] rootPart หาย"); return
    end
    if not humanoid or not humanoid.Parent then
        warn("[BoomFly] humanoid หาย"); return
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
end

-- ===================== Input (PC) =====================
addConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.W then pcKeys.W = true end
    if input.KeyCode == Enum.KeyCode.S then pcKeys.S = true end
    if input.KeyCode == Enum.KeyCode.A then pcKeys.A = true end
    if input.KeyCode == Enum.KeyCode.D then pcKeys.D = true end
    if input.KeyCode == Enum.KeyCode.Space then pcKeys.Space = true end
    if input.KeyCode == Enum.KeyCode.LeftShift then pcKeys.Shift = true end
end))

addConn(UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then pcKeys.W = false end
    if input.KeyCode == Enum.KeyCode.S then pcKeys.S = false end
    if input.KeyCode == Enum.KeyCode.A then pcKeys.A = false end
    if input.KeyCode == Enum.KeyCode.D then pcKeys.D = false end
    if input.KeyCode == Enum.KeyCode.Space then pcKeys.Space = false end
    if input.KeyCode == Enum.KeyCode.LeftShift then pcKeys.Shift = false end
end))

-- ===================== GUI =====================
local gui = Instance.new("ScreenGui")
gui.Name = "ByBoomMenu"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Floating Button
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

-- Main Menu
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

local mainTopLine = Instance.new("Frame")
mainTopLine.Size = UDim2.new(1, 0, 0, 3)
mainTopLine.BackgroundColor3 = COLOR_ACCENT
mainTopLine.BorderSizePixel = 0
mainTopLine.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 40)
title.Position = UDim2.new(0, 12, 0, 3)
title.BackgroundTransparency = 1
title.Text = "BY BOOMXICO (FIXED)"
title.TextColor3 = COLOR_TEXT
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local mainScroll = Instance.new("ScrollingFrame")
mainScroll.Size = UDim2.new(1, -16, 1, -50)
mainScroll.Position = UDim2.new(0, 8, 0, 45)
mainScroll.BackgroundTransparency = 1
mainScroll.BorderSizePixel = 0
mainScroll.ScrollBarThickness = 3
mainScroll.ScrollBarImageColor3 = COLOR_ACCENT
mainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
mainScroll.CanvasSize = UDim2.new(0,0,0,0)
mainScroll.Parent = main

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding = UDim.new(0, 6)
mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainLayout.Parent = mainScroll

-- ===================== UI Helpers =====================
local function updateToggleUI(btn, enabled)
    btn.Text = enabled and "เปิด" or "ปิด"
    btn.BackgroundColor3 = enabled and COLOR_ACTIVE or COLOR_OFF
    btn.TextColor3 = enabled and Color3.fromRGB(255,255,255) or COLOR_SUBTEXT
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
        if callback then callback(state) end
    end)

    return btn, card
end

local function mkRow(labelText, defaultVal, callback)
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
        if callback then callback(state) end
    end)

    box.FocusLost:Connect(function()
        local val = tonumber(box.Text)
        if val then
            box.Text = tostring(math.clamp(val, 1, MAX_SPEED))
        end
    end)

    return btn, box, function() return state end
end

-- ===================== สร้างปุ่มทั้งหมด =====================

-- Speed
local spdBtn, spdBox = mkRow("วิ่งไว", "50", function(state)
    speedEnabled = state
    if humanoid then humanoid.WalkSpeed = state and runSpeed or 16 end
end)
spdBox.FocusLost:Connect(function()
    local v = tonumber(spdBox.Text)
    if v then runSpeed = math.clamp(v, 1, MAX_SPEED) end
end)

-- Fly (สำคัญ!)
local flyBtn, flyBox = mkRow("บินได้", "50", function(state)
    if state then
        if not flyEnabled then startFly() end
    else
        if flyEnabled then stopFly() end
    end
end)
flyBox.FocusLost:Connect(function()
    local v = tonumber(flyBox.Text)
    if v then flySpeed = math.clamp(v, 1, MAX_FLY) end
end)

-- Noclip
mkToggle("Noclip", function(state)
    noclipEnabled = state
    if state then
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

-- Infinite Jump
mkToggle("Infinite Jump", function(state)
    infJumpEnabled = state
end)

-- Fullbright
mkToggle("Fullbright", function(state)
    fullbrightEnabled = state
    if state then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
        Lighting.Ambient = Color3.fromRGB(128,128,128)
    else
        for k, v in pairs(originalLighting) do Lighting[k] = v end
    end
end)

-- No Fog
mkToggle("No Fog", function(state)
    noFogEnabled = state
    if state then
        Lighting.FogStart = 1e6
        Lighting.FogEnd = 1e6
    else
        Lighting.FogStart = originalLighting.FogStart
        Lighting.FogEnd = originalLighting.FogEnd
    end
end)

-- ESP
mkToggle("มองทะลุ (ESP)", function(state)
    espEnabled = state
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            if state then
                if not espObjects[p] and p.Character then
                    local hl = Instance.new("Highlight")
                    hl.FillColor = COLOR_ACCENT
                    hl.FillTransparency = 0.5
                    hl.OutlineColor = Color3.fromRGB(255,255,255)
                    hl.Adornee = p.Character
                    hl.Parent = gui
                    espObjects[p] = hl
                end
            else
                if espObjects[p] then safeDestroy(espObjects[p]) espObjects[p] = nil end
            end
        end
    end
end)

-- Name Tags
mkToggle("แสดงชื่อผู้เล่น", function(state)
    nameEnabled = state
end)

-- ปุ่ม Toggle Main Menu
toggleBtn.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

-- Infinite Jump Logic
addConn(UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- Auto-reconnect Character
player.CharacterAdded:Connect(onCharacterAdded)

-- Cleanup
game:BindToClose(function()
    stopFly()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
end)

-- ค้นหาปุ่ม Noclip ในสคริปต์จริงต้องเป็น local variable
-- ถ้าอยากเก็บ Noclip button ไว้ใช้อ้างอิง ให้เปลี่ยนเป็น:
-- local noclipBtn = mkToggle("Noclip", function(state) ... end)
