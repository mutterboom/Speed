-- ============================================
-- By Boomxico | Modern Dark Crimson UI (v2.5 Fully Fixed Fly)
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

-- Keybinds & Cooldowns
local TOGGLE_COOLDOWN = 0.2
local lastToggleTime  = 0

local connections = {}

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

-- อัปเดตตัวละครเมื่อตาย/เกิดใหม่
player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    if flyEnabled then
        task.wait(0.5)
        startFly()
    end
end)

-- ===================== Input Handlers (PC Keyboard) =====================
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.W then pcKeys.W = true end
    if input.KeyCode == Enum.KeyCode.S then pcKeys.S = true end
    if input.KeyCode == Enum.KeyCode.A then pcKeys.A = true end
    if input.KeyCode == Enum.KeyCode.D then pcKeys.D = true end
    if input.KeyCode == Enum.KeyCode.Space then pcKeys.Space = true end
    if input.KeyCode == Enum.KeyCode.LeftShift then pcKeys.Shift = true end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.W then pcKeys.W = false end
    if input.KeyCode == Enum.KeyCode.S then pcKeys.S = false end
    if input.KeyCode == Enum.KeyCode.A then pcKeys.A = false end
    if input.KeyCode == Enum.KeyCode.D then pcKeys.D = false end
    if input.KeyCode == Enum.KeyCode.Space then pcKeys.Space = false end
    if input.KeyCode == Enum.KeyCode.LeftShift then pcKeys.Shift = false end
end)

-- ===================== Fly Core System (FIXED) =====================
function stopFly()
    flyEnabled = false
    if bodyVel then safeDestroy(bodyVel) bodyVel = nil end
    if bodyGyro then safeDestroy(bodyGyro) bodyGyro = nil end
    if humanoid then
        humanoid.PlatformStanding = false
    end
end

function startFly()
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
    bodyGyro.CFrame = camera.CFrame
    bodyGyro.Parent = rootPart
end

-- Loop ประมวลผลการบิน (RenderStepped)
RunService.RenderStepped:Connect(function()
    if flyEnabled and rootPart and bodyVel and bodyGyro then
        humanoid.PlatformStanding = true
        bodyGyro.CFrame = camera.CFrame

        local moveDir = Vector3.zero
        local camCF = camera.CFrame

        -- คำนวณการกดปุ่มบน PC
        if pcKeys.W or dirs.F then moveDir = moveDir + camCF.LookVector end
        if pcKeys.S or dirs.B then moveDir = moveDir - camCF.LookVector end
        if pcKeys.A or dirs.L then moveDir = moveDir - camCF.RightVector end
        if pcKeys.D or dirs.R then moveDir = moveDir + camCF.RightVector end
        if pcKeys.Space or dirs.U then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if pcKeys.Shift or dirs.D then moveDir = moveDir - Vector3.new(0, 1, 0) end

        -- คำนวณจอยสติ๊กมือถือ (Touch Controller Support)
        if isMobile and humanoid.MoveDirection.Magnitude > 0 then
            local touchDir = humanoid.MoveDirection
            moveDir = moveDir + (camCF.LookVector * -touchDir.Z) + (camCF.RightVector * touchDir.X)
        end

        if moveDir.Magnitude > 0 then
            bodyVel.Velocity = moveDir.Unit * flySpeed
        else
            bodyVel.Velocity = Vector3.zero
        end
    end
end)

-- ===================== GUI Setup =====================
local gui = Instance.new("ScreenGui")
gui.Name = "ByBoomMenu"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 280, 0, 350)
main.Position = UDim2.new(0, 20, 0, 120)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
main.Active = true
main.Draggable = true
main.Parent = gui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.Text = "BY BOOMXICO (v2.5 Fixed)"
title.TextColor3 = Color3.fromRGB(235, 35, 45)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = main

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -50)
scroll.Position = UDim2.new(0, 8, 0, 45)
scroll.BackgroundTransparency = 1
scroll.Parent = main

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.Parent = scroll

-- ปุ่ม Toggle บินได้
local flyCard = Instance.new("Frame")
flyCard.Size = UDim2.new(1, 0, 0, 36)
flyCard.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
flyCard.Parent = scroll

local flyLbl = Instance.new("TextLabel")
flyLbl.Size = UDim2.new(0.6, 0, 1, 0)
flyLbl.Position = UDim2.new(0, 10, 0, 0)
flyLbl.Text = "บินได้ (Fly)"
flyLbl.TextColor3 = Color3.fromRGB(245, 245, 250)
flyLbl.Font = Enum.Font.GothamMedium
flyLbl.TextSize = 12
flyLbl.TextXAlignment = Enum.TextXAlignment.Left
flyLbl.BackgroundTransparency = 1
flyLbl.Parent = flyCard

local flyBtn = Instance.new("TextButton")
flyBtn.Size = UDim2.new(0.3, 0, 0, 24)
flyBtn.Position = UDim2.new(0.68, 0, 0.5, -12)
flyBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
flyBtn.Text = "ปิด"
flyBtn.TextColor3 = Color3.fromRGB(140, 140, 150)
flyBtn.Font = Enum.Font.GothamBold
flyBtn.TextSize = 11
flyBtn.Parent = flyCard

flyBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    if flyEnabled then
        stopFly()
        flyBtn.Text = "ปิด"
        flyBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
        flyBtn.TextColor3 = Color3.fromRGB(140, 140, 150)
    else
        startFly()
        flyBtn.Text = "เปิด"
        flyBtn.BackgroundColor3 = Color3.fromRGB(190, 20, 30)
        flyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end)
