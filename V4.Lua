-- ============================================
-- By Boomxico | Golden Glass UI V4.9
-- Auto-detect Platform: PC / Mobile
-- ชื่อเงินขาว + UI เลื่อนได้ + Hotkey PC Only
-- ============================================
if not game:IsLoaded() then game.Loaded:Wait() end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ★ Platform Detection
local isPC = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
local isMobile = UserInputService.TouchEnabled

local speedEnabled, flyEnabled, espEnabled, nameEnabled = false, false, false, false
local noclipEnabled, fpsBoostEnabled = false, false
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
    esp = false, name = false, nameDist = 800,
    noclip = false, fpsBoost = false
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

local espObjects = {}
local nameObjects = {}
local nameData = {}
local playerRows = {}
local noclipConnection = nil
local fpsBoostBackup = {}
local noclipBusy = false

-- ============================================
-- Colors
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
local COLOR_SILVER = Color3.fromRGB(220, 220, 230)
local COLOR_SILVER_DIM = Color3.fromRGB(160, 160, 175)

-- ============================================
-- Helpers
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
-- Main UI
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
