-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Ghost Stick V7 | Multi-Device                                 ║
-- ║  - Auto-Detect: PC / iOS / Android / Tablet / Console          ║
-- ║  - Auto UI Scale + Safe Zone + Rotate Handler                  ║
-- ║  - 3 โหมด: เกาะ / ซ่อนลึก / หลังไกล                            ║
-- ║  - Touch-friendly (ปุ่มใหญ่ขึ้นบน Mobile)                      ║
-- ╚═══════════════════════════════════════════════════════════════╝

print("[Ghost V7] ========== LOADING ==========")

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ═══════════════════════════════════════════
-- DEVICE DETECTION (ละเอียด)
-- ═══════════════════════════════════════════
local uis = UserInputService

local isTouch = uis.TouchEnabled
local isKeyboard = uis.KeyboardEnabled
local isMouse = uis.MouseEnabled
local isGamepad = uis.GamepadEnabled
local isTenFoot = false

pcall(function()
    isTenFoot = uis:IsTenFootInterface()
end)

-- Platform
local platform = "PC"
if isTenFoot then
    platform = "Console"
elseif isTouch and not isKeyboard then
    platform = "Mobile"
elseif isKeyboard and isMouse then
    platform = "PC"
elseif isGamepad and not isKeyboard then
    platform = "Console"
end

-- Screen size
local screenX = Camera.ViewportSize.X
local screenY = Camera.ViewportSize.Y
local minSide = math.min(screenX, screenY)

-- iOS / Android Detection
local isIOS = false
local isAndroid = false
if platform == "Mobile" then
    local aspect = screenX / screenY
    -- iOS aspect ratios:
    --   iPhone portrait: 0.46-0.50 (19.5:9, 16:9)
    --   iPad portrait:   0.70-0.80 (4:3)
    --   iPhone landscape: 2.00-2.16
    --   iPad landscape:   1.30-1.40
    isIOS = (aspect > 0.44 and aspect < 0.51) or
            (aspect > 0.70 and aspect < 0.80) or
            (aspect > 1.30 and aspect < 1.41) or
            (aspect > 1.95 and aspect < 2.20)
    isAndroid = not isIOS
end

-- Device Type + UI Scale
local deviceType = "PC"
local uiScale = 1.0
local touchMode = false
local showHotkey = true

if platform == "Console" then
    deviceType = "Console"
    uiScale = 1.15
    touchMode = false
    showHotkey = false
elseif platform == "Mobile" then
    touchMode = true
    showHotkey = false

    if minSide < 350 then
        deviceType = "Mobile-XS"
        uiScale = 0.55
    elseif minSide < 400 then
        deviceType = "Mobile-Small"
        uiScale = 0.65
    elseif minSide < 480 then
        deviceType = "Mobile-Mid"
        uiScale = 0.78
    elseif minSide < 600 then
        deviceType = "Mobile-Large"
        uiScale = 0.88
    elseif minSide < 800 then
        deviceType = "Tablet-Small"
        uiScale = 0.95
    else
        deviceType = "Tablet-Large"
        uiScale = 1.05
    end

    if isIOS then
        deviceType = deviceType .. " (iOS)"
    elseif isAndroid then
        deviceType = deviceType .. " (Android)"
    end
else
    deviceType = "PC"
    touchMode = false
    showHotkey = true

    if screenY < 700 then
        uiScale = 0.85; deviceType = "PC-Small"
    elseif screenY < 900 then
        uiScale = 0.95; deviceType = "PC-Mid"
    elseif screenY < 1200 then
        uiScale = 1.0; deviceType = "PC"
    else
        uiScale = 1.15; deviceType = "PC-4K"
    end
end

local function sz(px) return math.floor(px * uiScale) end

-- Safe Zone (GuiInset)
local topInset, bottomInset = 0, 0
pcall(function()
    topInset, bottomInset = GuiService:GetGuiInset()
end)

local safeTop = topInset
local safeBottom = bottomInset
local safeLeft = 0
local safeRight = 0

if touchMode then
    safeLeft = math.max(10, screenX * 0.02)
    safeRight = math.max(10, screenX * 0.02)
    safeTop = math.max(topInset, screenY * 0.03)
    safeBottom = math.max(bottomInset, screenY * 0.03)
end

print("[Ghost V7] Platform:", platform)
print("[Ghost V7] Device:", deviceType)
print("[Ghost V7] UI Scale:", uiScale)
print("[Ghost V7] Screen:", screenX, "x", screenY)
print("[Ghost V7] Touch:", touchMode, "| Hotkey:", showHotkey)
print("[Ghost V7] iOS:", isIOS, "| Android:", isAndroid)

-- ล้าง GUI เก่า
pcall(function()
    local pg = LP:WaitForChild("PlayerGui")
    for _, g in ipairs(pg:GetChildren()) do
        if g.Name:find("^GhostStick") then g:Destroy() end
    end
end)

-- ═══ STATE ═══
local S = {
    enabled = false,
    target = nil,
    stickConn = nil,
    alive = true,
    collapsed = false,

    posMode = "stick",
    distance = 3,
    backOffset = 2,
    deepY = 50,
    behindDist = 15,

    hideLocal = true,
    savedTransparency = {},
    charListener = nil,

    hotkey = nil,
    hotkeyWaiting = false,
    lastHotkeyTime = 0,
    HOTKEY_ACTION = "GhostStick_HK_V7",

    spectateYaw = 0,
    spectatePitch = -10,
    spectateDist = 12,
    spectateMouseDown = false,
    spectateLastMouseX = 0,
    spectateLastMouseY = 0,
    spectateBound = false,
    spectateSmooth = 0.25,
    spectateActive = true,
}

local UI = {}
local currentPresetIdx = 0

-- ═══ UTIL ═══
local function clamp(v, mn, mx)
    if v < mn then return mn end
    if v > mx then return mx end
    return v
end

local function getHRP(plr)
    if not plr or not plr.Parent then return nil end
    local c = plr.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getPlayerFromAim()
    local mouse = LP:GetMouse()
    if mouse and mouse.Target then
        local part = mouse.Target
        local model = part:FindFirstAncestorOfClass("Model")
        while model do
            local plr = Players:GetPlayerFromCharacter(model)
            if plr and plr ~= LP then return plr end
            model = model:FindFirstAncestorOfClass("Model")
        end
    end
    return nil
end

local function getPlayerInSight()
    local camPos = Camera.CFrame.Position
    local camLook = Camera.CFrame.LookVector
    local best, bestScore = nil, -1
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local hrp = getHRP(plr)
            if hrp then
                local toT = (hrp.Position - camPos)
                local dist = toT.Magnitude
                if dist > 0 then
                    local dot = camLook:Dot(toT.Unit)
                    if dot > 0.7 and dist < 200 then
                        local score = dot * (1 / dist)
                        if score > bestScore then
                            bestScore = score
                            best = plr
                        end
                    end
                end
            end
        end
    end
    return best
end

local function getNearestPlayer()
    local myHRP = getHRP(LP)
    if not myHRP then return nil end
    local nearest, minD = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local hrp = getHRP(plr)
            if hrp then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < minD then minD = d; nearest = plr end
            end
        end
    end
    return nearest
end

-- ═══ HIDE ═══
local function hideCharacter()
    local char = LP.Character
    if not char then return end
    S.savedTransparency = {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(S.savedTransparency, {
                part = part,
                oldLocal = part.LocalTransparencyModifier,
            })
            part.LocalTransparencyModifier = 1
        elseif part:IsA("Decal") or part:IsA("Texture") then
            table.insert(S.savedTransparency, {
                part = part,
                oldTrans = part.Transparency,
            })
            part.Transparency = 1
        end
    end
    if S.charListener then S.charListener:Disconnect() end
    S.charListener = char.DescendantAdded:Connect(function(desc)
        if S.enabled and S.hideLocal then
            if desc:IsA("BasePart") then
                desc.LocalTransparencyModifier = 1
            elseif desc:IsA("Decal") or desc:IsA("Texture") then
                desc.Transparency = 1
            end
        end
    end)
end

local function restoreCharacter()
    for _, data in ipairs(S.savedTransparency) do
        if data.part and data.part.Parent then
            pcall(function()
                if data.oldLocal ~= nil then
                    data.part.LocalTransparencyModifier = data.oldLocal
                end
                if data.oldTrans ~= nil then
                    data.part.Transparency = data.oldTrans
                end
            end)
        end
    end
    S.savedTransparency = {}
    if S.charListener then
        S.charListener:Disconnect()
        S.charListener = nil
    end
end

-- ═══ STICK LOOP ═══
local function stickLoop()
    if not S.enabled or not S.alive then return end
    local myHRP = getHRP(LP)
    if not myHRP then return end

    if not S.target or not getHRP(S.target) then
        S.target = getNearestPlayer()
        if not S.target then return end
        if UI.refreshStatus then UI.refreshStatus() end
    end

    local tgtHRP = getHRP(S.target)
    if not tgtHRP then return end

    local look = tgtHRP.CFrame.LookVector
    local stickPos

    if S.posMode == "deep" then
        stickPos = Vector3.new(
            tgtHRP.Position.X,
            tgtHRP.Position.Y - S.deepY,
            tgtHRP.Position.Z
        )
    elseif S.posMode == "behind" then
        stickPos = tgtHRP.Position
            + Vector3.new(0, -S.distance, 0)
            - (look * S.behindDist)
    else
        stickPos = tgtHRP.Position
            + Vector3.new(0, -S.distance, 0)
            - (look * S.backOffset)
    end

    myHRP.CFrame = CFrame.new(stickPos, stickPos + look)
    myHRP.AssemblyLinearVelocity = Vector3.zero
    myHRP.AssemblyAngularVelocity = Vector3.zero
end

-- ═══ SPECTATE ═══
local function spectateUpdate(dt)
    if not S.enabled or not S.alive then return end
    if not S.spectateActive then return end
    if not S.target then return end

    local targetChar = S.target.Character
    if not targetChar then return end
    local targetHead = targetChar:FindFirstChild("Head")
    if not targetHead then return end

    local cam = workspace.CurrentCamera
    cam.CameraType = Enum.CameraType.Scriptable

    local yawRad = math.rad(S.spectateYaw)
    local pitchRad = math.rad(S.spectatePitch)

    local offset = Vector3.new(
        math.sin(yawRad) * math.cos(pitchRad) * S.spectateDist,
        -math.sin(pitchRad) * S.spectateDist + 2,
        math.cos(yawRad) * math.cos(pitchRad) * S.spectateDist
    )

    local camPos = targetHead.Position + offset
    local targetCF = CFrame.new(camPos, targetHead.Position)

    local smooth = S.spectateSmooth
    if smooth >= 1 then
        cam.CFrame = targetCF
    else
        cam.CFrame = cam.CFrame:Lerp(targetCF, smooth)
    end
end

local function stopSpectate()
    local cam = workspace.CurrentCamera
    if cam then
        cam.CameraType = Enum.CameraType.Custom
        if LP.Character then
            local myHum = LP.Character:FindFirstChildOfClass("Humanoid")
            if myHum then cam.CameraSubject = myHum end
        end
    end
end

local function disableSpectate()
    S.spectateActive = false
    stopSpectate()
    if UI.refreshAll then UI.refreshAll() end
end

local function enableSpectate()
    S.spectateActive = true
    if UI.refreshAll then UI.refreshAll() end
end

local SPECTATE_PRESETS = {
    {name = "ปิดกล้อง",  dist = 0,   pitch = 0,   yaw = 0},
    {name = "ใกล้",     dist = 6,   pitch = -10, yaw = 0},
    {name = "กลาง",     dist = 12,  pitch = -10, yaw = 0},
    {name = "ไกล",      dist = 20,  pitch = -15, yaw = 0},
    {name = "หลังบน",   dist = 15,  pitch = -30, yaw = 0},
    {name = "ข้างขวา",  dist = 12,  pitch = -10, yaw = 90},
    {name = "ข้างซ้าย", dist = 12,  pitch = -10, yaw = -90},
    {name = "หน้า",     dist = 12,  pitch = -10, yaw = 180},
}

local function applyPreset(idx)
    local p = SPECTATE_PRESETS[idx]
    if not p then return end
    currentPresetIdx = idx
    if p.dist == 0 then
        disableSpectate()
        if UI.refreshPresets then UI.refreshPresets(idx) end
        return
    end
    enableSpectate()
    S.spectateDist = p.dist
    S.spectatePitch = p.pitch
    S.spectateYaw = p.yaw
    if UI.refreshPresets then UI.refreshPresets(idx) end
end

-- ═══ START / STOP ═══
local function startGhost(target)
    if S.enabled then return end
    S.target = target
    if not S.target then
        print("[Ghost] ไม่พบเป้า")
        return
    end
    S.enabled = true

    if S.hideLocal then hideCharacter() end

    if S.stickConn then S.stickConn:Disconnect() end
    S.stickConn = RunService.RenderStepped:Connect(stickLoop)

    S.spectateActive = true
    S.spectateYaw = 0
    S.spectatePitch = -10
    S.spectateDist = 12
    S.spectateSmooth = 0.25
    currentPresetIdx = 3
    if not S.spectateBound then
        RunService:BindToRenderStep(
            "GhostStickSpectate",
            Enum.RenderPriority.Camera.Value + 1,
            spectateUpdate
        )
        S.spectateBound = true
    end

    print("[Ghost] ON | target:", S.target.Name, "| mode:", S.posMode)
    if UI.refreshAll then UI.refreshAll() end
end

local function stopGhost()
    if not S.enabled then return end
    S.enabled = false
    S.target = nil
    if S.stickConn then
        S.stickConn:Disconnect()
        S.stickConn = nil
    end

    if S.spectateBound then
        pcall(function()
            RunService:UnbindFromRenderStep("GhostStickSpectate")
        end)
        S.spectateBound = false
    end
    stopSpectate()

    restoreCharacter()
    print("[Ghost] OFF")
    if UI.refreshAll then UI.refreshAll() end
end

local function toggleGhost(target)
    if S.enabled then
        stopGhost()
    else
        if not target then
            target = getPlayerFromAim() or getPlayerInSight() or getNearestPlayer()
        end
        startGhost(target)
    end
end

local function shutdown()
    S.alive = false
    S.enabled = false
    if S.stickConn then
        pcall(function() S.stickConn:Disconnect() end)
        S.stickConn = nil
    end
    if S.spectateBound then
        pcall(function()
            RunService:UnbindFromRenderStep("GhostStickSpectate")
        end)
        S.spectateBound = false
    end
    stopSpectate()
    restoreCharacter()
    pcall(function() ContextActionService:UnbindAction(S.HOTKEY_ACTION) end)
    if UI.gui then
        pcall(function() UI.gui:Destroy() end)
        UI.gui = nil
    end
    print("[Ghost] ปิดสคริปต์เรียบร้อย")
end

-- ═══════════════════════════════════════════
-- UI (Multi-Device)
-- ═══════════════════════════════════════════
local gui = Instance.new("ScreenGui")
gui.Name = "GhostStickUI_V7"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 100
gui.IgnoreGuiInset = false
gui.Parent = LP:WaitForChild("PlayerGui")
UI.gui = gui

-- ขนาด
local mainW = sz(300)
local mainH = sz(680)
local collapsedW = sz(180)
local collapsedH = sz(36)

-- ตำแหน่งเริ่มต้น (ปลอดภัย)
local startX, startY
if touchMode then
    startX = math.floor((screenX - mainW) / 2)
    startY = math.floor(safeTop + 10)
else
    startX = safeLeft + 15
    startY = safeTop + 15
end

-- ไม่ให้ล้นจอ
if startX + mainW > screenX - safeRight then
    startX = screenX - safeRight - mainW - 10
end
if startY + mainH > screenY - safeBottom then
    mainH = screenY - safeBottom - startY - 10
end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, mainW, 0, mainH)
main.Position = UDim2.new(0, startX, 0, startY)
main.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
main.BackgroundTransparency = 0.1
main.BorderSizePixel = 0
main.Active = true
main.Draggable = not touchMode
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
UI.main = main

local stroke = Instance.new("UIStroke", main)
stroke.Color = Color3.fromRGB(150, 100, 255)
stroke.Thickness = 1.5

-- Title Bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, sz(38))
titleBar.BackgroundTransparency = 1
titleBar.Active = true
titleBar.Parent = main

-- ✅ Drag on touch
if touchMode then
    local dragging = false
    local dragStart, startPos
    titleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = i.Position
            startPos = main.Position
        end
    end)
    titleBar.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                      startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -sz(150), 0, sz(36))
title.Position = UDim2.new(0, sz(10), 0, sz(1))
title.BackgroundTransparency = 1
title.Text = "👻 GHOST V7"
title.TextColor3 = Color3.fromRGB(200, 170, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = sz(15)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar
UI.title = title

-- ✅ ปุ่มขนาดใหญ่ขึ้นบน Mobile
local btnSize = touchMode and sz(34) or sz(30)
local btnH = touchMode and sz(34) or sz(30)

local collapseBtn = Instance.new("TextButton")
collapseBtn.Size = UDim2.new(0, btnSize, 0, btnH)
collapseBtn.Position = UDim2.new(1, -sz(106), 0, sz(4))
collapseBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)
collapseBtn.BorderSizePixel = 0
collapseBtn.Text = "▼"
collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextSize = sz(15)
collapseBtn.Parent = titleBar
Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 6)
UI.collapseBtn = collapseBtn

local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(0, btnSize, 0, btnH)
killBtn.Position = UDim2.new(1, -sz(72), 0, sz(4))
killBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
killBtn.BorderSizePixel = 0
killBtn.Text = "✕"
killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = sz(15)
killBtn.Parent = titleBar
Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 6)
UI.killBtn = killBtn

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, btnSize, 0, btnH)
minimizeBtn.Position = UDim2.new(1, -sz(36), 0, sz(4))
minimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
minimizeBtn.BorderSizePixel = 0
minimizeBtn.Text = "−"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.TextSize = sz(15)
minimizeBtn.Parent = titleBar
Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)
UI.minimizeBtn = minimizeBtn

-- Body
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -sz(38))
body.Position = UDim2.new(0, 0, 0, sz(38))
body.BackgroundTransparency = 1
body.Parent = main
UI.body = body

-- ขนาดปุ่มและฟอนต์ตามอุปกรณ์
local smallFont = touchMode and sz(12) or sz(11)
local normalFont = touchMode and sz(14) or sz(12)
local bigBtnH = touchMode and sz(42) or sz(36)
local smallBtnH = touchMode and sz(32) or sz(28)
local listItemH = touchMode and sz(38) or sz(32)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -20, 0, sz(18))
statusLbl.Position = UDim2.new(0, 10, 0, sz(6))
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "● ปิด"
statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLbl.Font = Enum.Font.Code
statusLbl.TextSize = normalFont
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = body
UI.statusLbl = statusLbl

local targetLbl = Instance.new("TextLabel")
targetLbl.Size = UDim2.new(1, -20, 0, sz(18))
targetLbl.Position = UDim2.new(0, 10, 0, sz(26))
targetLbl.BackgroundTransparency = 1
targetLbl.Text = "🎯 เป้า: -"
targetLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
targetLbl.Font = Enum.Font.Code
targetLbl.TextSize = normalFont
targetLbl.TextXAlignment = Enum.TextXAlignment.Left
targetLbl.Parent = body
UI.targetLbl = targetLbl

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -20, 0, bigBtnH)
toggleBtn.Position = UDim2.new(0, 10, 0, sz(52))
toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 130)
toggleBtn.BorderSizePixel = 0
toggleBtn.Text = "👻 เปิด Ghost (Aim)"
toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = normalFont + 1
toggleBtn.Parent = body
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
UI.toggleBtn = toggleBtn

-- ✅ Hotkey button (แสดงเฉพาะ PC)
local hotkeyBtn = Instance.new("TextButton")
hotkeyBtn.Size = UDim2.new(1, -20, 0, smallBtnH)
hotkeyBtn.Position = UDim2.new(0, 10, 0, sz(52) + bigBtnH + sz(6))
hotkeyBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 60)
hotkeyBtn.BorderSizePixel = 0
hotkeyBtn.Text = "⌨ ตั้งปุ่ม Hotkey"
hotkeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hotkeyBtn.Font = Enum.Font.GothamBold
hotkeyBtn.TextSize = normalFont
hotkeyBtn.Visible = showHotkey
hotkeyBtn.Parent = body
Instance.new("UICorner", hotkeyBtn).CornerRadius = UDim.new(0, 8)
UI.hotkeyBtn = hotkeyBtn

local startY2 = showHotkey and (sz(52) + bigBtnH + sz(6) + smallBtnH + sz(6)) or (sz(52) + bigBtnH + sz(6))

-- Mode Selector
local modeLbl = Instance.new("TextLabel")
modeLbl.Size = UDim2.new(1, -20, 0, sz(16))
modeLbl.Position = UDim2.new(0, 10, 0, startY2)
modeLbl.BackgroundTransparency = 1
modeLbl.Text = "🎭 โหมด"
modeLbl.TextColor3 = Color3.fromRGB(180, 200, 255)
modeLbl.Font = Enum.Font.GothamBold
modeLbl.TextSize = smallFont
modeLbl.TextXAlignment = Enum.TextXAlignment.Left
modeLbl.Parent = body

local modeRow = Instance.new("Frame")
modeRow.Size = UDim2.new(1, -20, 0, smallBtnH)
modeRow.Position = UDim2.new(0, 10, 0, startY2 + sz(20))
modeRow.BackgroundTransparency = 1
modeRow.Parent = body

local modeStick = Instance.new("TextButton")
modeStick.Size = UDim2.new(0.32, 0, 1, 0)
modeStick.Position = UDim2.new(0, 0, 0, 0)
modeStick.BackgroundColor3 = Color3.fromRGB(80, 60, 140)
modeStick.BorderSizePixel = 0
modeStick.Text = "เกาะ"
modeStick.TextColor3 = Color3.fromRGB(255, 255, 255)
modeStick.Font = Enum.Font.GothamBold
modeStick.TextSize = smallFont
modeStick.Parent = modeRow
Instance.new("UICorner", modeStick).CornerRadius = UDim.new(0, 6)
UI.modeStick = modeStick

local modeDeep = Instance.new("TextButton")
modeDeep.Size = UDim2.new(0.32, 0, 1, 0)
modeDeep.Position = UDim2.new(0.34, 0, 0, 0)
modeDeep.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
modeDeep.BorderSizePixel = 0
modeDeep.Text = "ซ่อนลึก"
modeDeep.TextColor3 = Color3.fromRGB(200, 200, 220)
modeDeep.Font = Enum.Font.GothamBold
modeDeep.TextSize = smallFont
modeDeep.Parent = modeRow
Instance.new("UICorner", modeDeep).CornerRadius = UDim.new(0, 6)
UI.modeDeep = modeDeep

local modeBehind = Instance.new("TextButton")
modeBehind.Size = UDim2.new(0.32, 0, 1, 0)
modeBehind.Position = UDim2.new(0.68, 0, 0, 0)
modeBehind.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
modeBehind.BorderSizePixel = 0
modeBehind.Text = "หลังไกล"
modeBehind.TextColor3 = Color3.fromRGB(200, 200, 220)
modeBehind.Font = Enum.Font.GothamBold
modeBehind.TextSize = smallFont
modeBehind.Parent = modeRow
Instance.new("UICorner", modeBehind).CornerRadius = UDim.new(0, 6)
UI.modeBehind = modeBehind

-- Slider 1: ใต้เป้า
local y1 = startY2 + sz(54)

local distLbl = Instance.new("TextLabel")
distLbl.Size = UDim2.new(1, -20, 0, sz(18))
distLbl.Position = UDim2.new(0, 10, 0, y1)
distLbl.BackgroundTransparency = 1
distLbl.Text = "📏 ใต้เป้า: 3.0 studs"
distLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
distLbl.Font = Enum.Font.Code
distLbl.TextSize = normalFont
distLbl.TextXAlignment = Enum.TextXAlignment.Left
distLbl.Parent = body
UI.distLbl = distLbl

local sliderBg = Instance.new("Frame")
sliderBg.Size = UDim2.new(1, -20, 0, sz(10))
sliderBg.Position = UDim2.new(0, 10, 0, y1 + sz(22))
sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
sliderBg.BorderSizePixel = 0
sliderBg.Parent = body
Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

local sliderFill = Instance.new("Frame")
sliderFill.Size = UDim2.new(0.2, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg
Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

local knobSize = touchMode and sz(20) or sz(16)
local sliderKnob = Instance.new("Frame")
sliderKnob.Size = UDim2.new(0, knobSize, 0, knobSize)
sliderKnob.Position = UDim2.new(0.2, -knobSize/2, 0.5, -knobSize/2)
sliderKnob.BackgroundColor3 = Color3.fromRGB(220, 200, 255)
sliderKnob.BorderSizePixel = 0
sliderKnob.ZIndex = 5
sliderKnob.Parent = sliderBg
Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

local sliderHitbox = Instance.new("TextButton")
sliderHitbox.Size = UDim2.new(1, 0, 0, sz(30))
sliderHitbox.Position = UDim2.new(0, 0, 0.5, -sz(15))
sliderHitbox.BackgroundTransparency = 1
sliderHitbox.Text = ""
sliderHitbox.ZIndex = 10
sliderHitbox.Parent = sliderBg

-- Slider 2: หลังเป้า
local y2 = y1 + sz(46)

local offLbl = Instance.new("TextLabel")
offLbl.Size = UDim2.new(1, -20, 0, sz(18))
offLbl.Position = UDim2.new(0, 10, 0, y2)
offLbl.BackgroundTransparency = 1
offLbl.Text = "↩ หลังเป้า: 2.0 studs"
offLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
offLbl.Font = Enum.Font.Code
offLbl.TextSize = normalFont
offLbl.TextXAlignment = Enum.TextXAlignment.Left
offLbl.Parent = body
UI.offLbl = offLbl

local sliderBg2 = Instance.new("Frame")
sliderBg2.Size = UDim2.new(1, -20, 0, sz(10))
sliderBg2.Position = UDim2.new(0, 10, 0, y2 + sz(22))
sliderBg2.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
sliderBg2.BorderSizePixel = 0
sliderBg2.Parent = body
Instance.new("UICorner", sliderBg2).CornerRadius = UDim.new(1, 0)

local sliderFill2 = Instance.new("Frame")
sliderFill2.Size = UDim2.new(0.2, 0, 1, 0)
sliderFill2.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
sliderFill2.BorderSizePixel = 0
sliderFill2.Parent = sliderBg2
Instance.new("UICorner", sliderFill2).CornerRadius = UDim.new(1, 0)

local sliderKnob2 = Instance.new("Frame")
sliderKnob2.Size = UDim2.new(0, knobSize, 0, knobSize)
sliderKnob2.Position = UDim2.new(0.2, -knobSize/2, 0.5, -knobSize/2)
sliderKnob2.BackgroundColor3 = Color3.fromRGB(220, 240, 255)
sliderKnob2.BorderSizePixel = 0
sliderKnob2.ZIndex = 5
sliderKnob2.Parent = sliderBg2
Instance.new("UICorner", sliderKnob2).CornerRadius = UDim.new(1, 0)

local sliderHitbox2 = Instance.new("TextButton")
sliderHitbox2.Size = UDim2.new(1, 0, 0, sz(30))
sliderHitbox2.Position = UDim2.new(0, 0, 0.5, -sz(15))
sliderHitbox2.BackgroundTransparency = 1
sliderHitbox2.Text = ""
sliderHitbox2.ZIndex = 10
sliderHitbox2.Parent = sliderBg2

-- Slider 3: ความลึก
local y3 = y2 + sz(46)

local deepLbl = Instance.new("TextLabel")
deepLbl.Size = UDim2.new(1, -20, 0, sz(18))
deepLbl.Position = UDim2.new(0, 10, 0, y3)
deepLbl.BackgroundTransparency = 1
deepLbl.Text = "🕳 ความลึก: 50 studs"
deepLbl.TextColor3 = Color3.fromRGB(255, 180, 200)
deepLbl.Font = Enum.Font.Code
deepLbl.TextSize = normalFont
deepLbl.TextXAlignment = Enum.TextXAlignment.Left
deepLbl.Parent = body
UI.deepLbl = deepLbl

local sliderBg3 = Instance.new("Frame")
sliderBg3.Size = UDim2.new(1, -20, 0, sz(10))
sliderBg3.Position = UDim2.new(0, 10, 0, y3 + sz(22))
sliderBg3.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
sliderBg3.BorderSizePixel = 0
sliderBg3.Parent = body
Instance.new("UICorner", sliderBg3).CornerRadius = UDim.new(1, 0)

local sliderFill3 = Instance.new("Frame")
sliderFill3.Size = UDim2.new(0.25, 0, 1, 0)
sliderFill3.BackgroundColor3 = Color3.fromRGB(200, 80, 120)
sliderFill3.BorderSizePixel = 0
sliderFill3.Parent = sliderBg3
Instance.new("UICorner", sliderFill3).CornerRadius = UDim.new(1, 0)

local sliderKnob3 = Instance.new("Frame")
sliderKnob3.Size = UDim2.new(0, knobSize, 0, knobSize)
sliderKnob3.Position = UDim2.new(0.25, -knobSize/2, 0.5, -knobSize/2)
sliderKnob3.BackgroundColor3 = Color3.fromRGB(255, 200, 220)
sliderKnob3.BorderSizePixel = 0
sliderKnob3.ZIndex = 5
sliderKnob3.Parent = sliderBg3
Instance.new("UICorner", sliderKnob3).CornerRadius = UDim.new(1, 0)

local sliderHitbox3 = Instance.new("TextButton")
sliderHitbox3.Size = UDim2.new(1, 0, 0, sz(30))
sliderHitbox3.Position = UDim2.new(0, 0, 0.5, -sz(15))
sliderHitbox3.BackgroundTransparency = 1
sliderHitbox3.Text = ""
sliderHitbox3.ZIndex = 10
sliderHitbox3.Parent = sliderBg3

-- Spectate
local y4 = y3 + sz(46)

local specLabel = Instance.new("TextLabel")
specLabel.Size = UDim2.new(1, -20, 0, sz(16))
specLabel.Position = UDim2.new(0, 10, 0, y4)
specLabel.BackgroundTransparency = 1
specLabel.Text = "🎥 กล้อง Spectate"
specLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
specLabel.Font = Enum.Font.GothamBold
specLabel.TextSize = smallFont
specLabel.TextXAlignment = Enum.TextXAlignment.Left
specLabel.Parent = body

local toggleSpectateBtn = Instance.new("TextButton")
toggleSpectateBtn.Size = UDim2.new(0.48, 0, 0, smallBtnH)
toggleSpectateBtn.Position = UDim2.new(0, 10, 0, y4 + sz(20))
toggleSpectateBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
toggleSpectateBtn.BorderSizePixel = 0
toggleSpectateBtn.Text = "🎥 ปิดกล้อง"
toggleSpectateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleSpectateBtn.Font = Enum.Font.GothamBold
toggleSpectateBtn.TextSize = smallFont
toggleSpectateBtn.Parent = body
Instance.new("UICorner", toggleSpectateBtn).CornerRadius = UDim.new(0, 6)
UI.toggleSpectateBtn = toggleSpectateBtn

local smoothBtn = Instance.new("TextButton")
smoothBtn.Size = UDim2.new(0.48, 0, 0, smallBtnH)
smoothBtn.Position = UDim2.new(0.52, 0, 0, y4 + sz(20))
smoothBtn.BackgroundColor3 = Color3.fromRGB(80, 90, 140)
smoothBtn.BorderSizePixel = 0
smoothBtn.Text = "✨ 0.25"
smoothBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
smoothBtn.Font = Enum.Font.GothamBold
smoothBtn.TextSize = smallFont
smoothBtn.Parent = body
Instance.new("UICorner", smoothBtn).CornerRadius = UDim.new(0, 6)
UI.smoothBtn = smoothBtn

local presetOpenBtn = Instance.new("TextButton")
presetOpenBtn.Size = UDim2.new(1, -20, 0, smallBtnH)
presetOpenBtn.Position = UDim2.new(0, 10, 0, y4 + sz(54))
presetOpenBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 120)
presetOpenBtn.BorderSizePixel = 0
presetOpenBtn.Text = "📐 สเปคจอ"
presetOpenBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
presetOpenBtn.Font = Enum.Font.GothamBold
presetOpenBtn.TextSize = smallFont
presetOpenBtn.Parent = body
Instance.new("UICorner", presetOpenBtn).CornerRadius = UDim.new(0, 6)
UI.presetOpenBtn = presetOpenBtn

local presetFrame = Instance.new("Frame")
presetFrame.Size = UDim2.new(1, -20, 0, sz(94))
presetFrame.Position = UDim2.new(0, 10, 0, y4 + sz(88))
presetFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
presetFrame.BackgroundTransparency = 0.4
presetFrame.BorderSizePixel = 0
presetFrame.Visible = false
presetFrame.Parent = body
Instance.new("UICorner", presetFrame).CornerRadius = UDim.new(0, 8)
UI.presetFrame = presetFrame

local presetPad = Instance.new("UIPadding", presetFrame)
presetPad.PaddingTop = UDim.new(0, 6)
presetPad.PaddingLeft = UDim.new(0, 6)
presetPad.PaddingRight = UDim.new(0, 6)
presetPad.PaddingBottom = UDim.new(0, 6)

local presetGrid = Instance.new("UIGridLayout", presetFrame)
presetGrid.CellSize = UDim2.new(0, sz(80), 0, sz(24))
presetGrid.CellPadding = UDim.new(0, 4, 0, 4)
presetGrid.SortOrder = Enum.SortOrder.LayoutOrder
presetGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left

local presetButtons = {}
for i, preset in ipairs(SPECTATE_PRESETS) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, sz(80), 0, sz(24))
    btn.BackgroundColor3 = Color3.fromRGB(50, 60, 90)
    btn.BorderSizePixel = 0
    btn.Text = preset.name
    btn.TextColor3 = Color3.fromRGB(220, 220, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = sz(10)
    btn.LayoutOrder = i
    btn.Parent = presetFrame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    presetButtons[i] = btn

    btn.MouseButton1Click:Connect(function()
        applyPreset(i)
    end)
end

local presetOpen = false
presetOpenBtn.MouseButton1Click:Connect(function()
    presetOpen = not presetOpen
    presetFrame.Visible = presetOpen
    if presetOpen then
        presetOpenBtn.Text = "📐 สเปคจอ (ซ่อน)"
        presetOpenBtn.BackgroundColor3 = Color3.fromRGB(90, 70, 140)
    else
        presetOpenBtn.Text = "📐 สเปคจอ"
        presetOpenBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 120)
    end
end)

-- List
local listY = y4 + sz(192)

local listTitle = Instance.new("TextLabel")
listTitle.Size = UDim2.new(1, -20, 0, sz(18))
listTitle.Position = UDim2.new(0, 10, 0, listY)
listTitle.BackgroundTransparency = 1
listTitle.Text = "👥 เลือกเป้า"
listTitle.TextColor3 = Color3.fromRGB(180, 200, 255)
listTitle.Font = Enum.Font.GothamBold
listTitle.TextSize = smallFont
listTitle.TextXAlignment = Enum.TextXAlignment.Left
listTitle.Parent = body

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 0, sz(100))
scroll.Position = UDim2.new(0, 10, 0, listY + sz(22))
scroll.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scroll.BackgroundTransparency = 0.6
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = touchMode and 10 or 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = body
Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 8)

local listLayout = Instance.new("UIListLayout", scroll)
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

local listPad = Instance.new("UIPadding", scroll)
listPad.PaddingTop = UDim.new(0, 6)
listPad.PaddingLeft = UDim.new(0, 6)
listPad.PaddingRight = UDim.new(0, 6)
listPad.PaddingBottom = UDim.new(0, 6)

local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0.48, 0, 0, smallBtnH)
refreshBtn.Position = UDim2.new(0, 10, 1, -sz(38))
refreshBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
refreshBtn.BorderSizePixel = 0
refreshBtn.Text = "🔄 รีเฟรช"
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.Font = Enum.Font.GothamBold
refreshBtn.TextSize = smallFont
refreshBtn.Parent = body
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)

local clearHotkeyBtn = Instance.new("TextButton")
clearHotkeyBtn.Size = UDim2.new(0.48, 0, 0, smallBtnH)
clearHotkeyBtn.Position = UDim2.new(0.52, 0, 1, -sz(38))
clearHotkeyBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
clearHotkeyBtn.BorderSizePixel = 0
clearHotkeyBtn.Text = "🗑 ลบ Hotkey"
clearHotkeyBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
clearHotkeyBtn.Font = Enum.Font.GothamBold
clearHotkeyBtn.TextSize = smallFont
clearHotkeyBtn.Visible = showHotkey
clearHotkeyBtn.Parent = body
Instance.new("UICorner", clearHotkeyBtn).CornerRadius = UDim.new(0, 6)

-- ═══ COLLAPSE ═══
local function toggleCollapse()
    S.collapsed = not S.collapsed
    if S.collapsed then
        main.Size = UDim2.new(0, collapsedW, 0, collapsedH)
        body.Visible = false
        title.Text = "👻 Ghost"
        collapseBtn.Text = "▲"
        killBtn.Position = UDim2.new(1, -sz(36), 0, sz(4))
        minimizeBtn.Visible = false
    else
        main.Size = UDim2.new(0, mainW, 0, mainH)
        body.Visible = true
        title.Text = "👻 GHOST V7"
        collapseBtn.Text = "▼"
        killBtn.Position = UDim2.new(1, -sz(72), 0, sz(4))
        minimizeBtn.Visible = true
    end
end

local isMinimized = false
local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        main.Size = UDim2.new(0, sz(44), 0, sz(44))
        body.Visible = false
        title.Visible = false
        collapseBtn.Visible = false
        minimizeBtn.Text = "□"
        killBtn.Visible = false
    else
        main.Size = UDim2.new(0, mainW, 0, mainH)
        body.Visible = true
        title.Visible = true
        collapseBtn.Visible = true
        minimizeBtn.Text = "−"
        killBtn.Visible = true
    end
end

collapseBtn.MouseButton1Click:Connect(toggleCollapse)
minimizeBtn.MouseButton1Click:Connect(toggleMinimize)

-- ═══ SLIDER LOGIC ═══
local DIST_MIN, DIST_MAX = 0, 15
local OFF_MIN, OFF_MAX = 0, 10
local DEEP_MIN, DEEP_MAX = 5, 200

local dragDist = false
local dragOff = false
local dragDeep = false

local function setDistance(val)
    val = clamp(val, DIST_MIN, DIST_MAX)
    S.distance = val
    local pct = (val - DIST_MIN) / (DIST_MAX - DIST_MIN)
    sliderFill.Size = UDim2.new(pct, 0, 1, 0)
    sliderKnob.Position = UDim2.new(pct, -knobSize/2, 0.5, -knobSize/2)
    UI.distLbl.Text = string.format("📏 ใต้เป้า: %.1f studs", val)
end

local function setBackOffset(val)
    val = clamp(val, OFF_MIN, OFF_MAX)
    S.backOffset = val
    local pct = (val - OFF_MIN) / (OFF_MAX - OFF_MIN)
    sliderFill2.Size = UDim2.new(pct, 0, 1, 0)
    sliderKnob2.Position = UDim2.new(pct, -knobSize/2, 0.5, -knobSize/2)
    UI.offLbl.Text = string.format("↩ หลังเป้า: %.1f studs", val)
end

local function setDeep(val)
    val = clamp(val, DEEP_MIN, DEEP_MAX)
    S.deepY = val
    local pct = (val - DEEP_MIN) / (DEEP_MAX - DEEP_MIN)
    sliderFill3.Size = UDim2.new(pct, 0, 1, 0)
    sliderKnob3.Position = UDim2.new(pct, -knobSize/2, 0.5, -knobSize/2)
    UI.deepLbl.Text = string.format("🕳 ความลึก: %.0f studs", val)
end

local function updateDistFromX(x)
    local rel = clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
    setDistance(DIST_MIN + rel * (DIST_MAX - DIST_MIN))
end

local function updateOffFromX(x)
    local rel = clamp((x - sliderBg2.AbsolutePosition.X) / sliderBg2.AbsoluteSize.X, 0, 1)
    setBackOffset(OFF_MIN + rel * (OFF_MAX - OFF_MIN))
end

local function updateDeepFromX(x)
    local rel = clamp((x - sliderBg3.AbsolutePosition.X) / sliderBg3.AbsoluteSize.X, 0, 1)
    setDeep(DEEP_MIN + rel * (DEEP_MAX - DEEP_MIN))
end

sliderHitbox.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragDist = true
        updateDistFromX(input.Position.X)
    end
end)
sliderHitbox.InputChanged:Connect(function(input)
    if dragDist and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        updateDistFromX(input.Position.X)
    end
end)
sliderHitbox.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragDist = false
    end
end)

sliderHitbox2.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragOff = true
        updateOffFromX(input.Position.X)
    end
end)
sliderHitbox2.InputChanged:Connect(function(input)
    if dragOff and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        updateOffFromX(input.Position.X)
    end
end)
sliderHitbox2.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragOff = false
    end
end)

sliderHitbox3.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragDeep = true
        updateDeepFromX(input.Position.X)
    end
end)
sliderHitbox3.InputChanged:Connect(function(input)
    if dragDeep and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        updateDeepFromX(input.Position.X)
    end
end)
sliderHitbox3.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragDeep = false
    end
end)

setDistance(3)
setBackOffset(2)
setDeep(50)

-- Refresh Sliders
local function refreshSliders()
    local dimColor = Color3.fromRGB(60, 60, 70)
    if S.posMode == "stick" then
        sliderFill.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
        sliderFill2.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
        sliderFill3.BackgroundColor3 = dimColor
    elseif S.posMode == "deep" then
        sliderFill.BackgroundColor3 = dimColor
        sliderFill2.BackgroundColor3 = dimColor
        sliderFill3.BackgroundColor3 = Color3.fromRGB(200, 80, 120)
    else
        sliderFill.BackgroundColor3 = dimColor
        sliderFill2.BackgroundColor3 = dimColor
        sliderFill3.BackgroundColor3 = dimColor
    end
end

local function setMode(m)
    S.posMode = m
    local active = Color3.fromRGB(80, 60, 140)
    local inactive = Color3.fromRGB(50, 50, 70)
    local white = Color3.fromRGB(255, 255, 255)
    local grey = Color3.fromRGB(200, 200, 220)
    modeStick.BackgroundColor3 = (m == "stick") and active or inactive
    modeDeep.BackgroundColor3 = (m == "deep") and active or inactive
    modeBehind.BackgroundColor3 = (m == "behind") and active or inactive
    modeStick.TextColor3 = (m == "stick") and white or grey
    modeDeep.TextColor3 = (m == "deep") and white or grey
    modeBehind.TextColor3 = (m == "behind") and white or grey
    refreshSliders()
    if UI.refreshStatus then UI.refreshStatus() end
    print("[Ghost] Mode:", m)
end

modeStick.MouseButton1Click:Connect(function() setMode("stick") end)
modeDeep.MouseButton1Click:Connect(function() setMode("deep") end)
modeBehind.MouseButton1Click:Connect(function() setMode("behind") end)

-- ═══ REFRESH UI ═══
function UI.refreshStatus()
    if S.enabled and S.target then
        local modeName = S.posMode == "deep" and "ซ่อนลึก" or S.posMode == "behind" and "หลังไกล" or "เกาะ"
        UI.statusLbl.Text = "● เปิด (" .. modeName .. ")"
        UI.statusLbl.TextColor3 = Color3.fromRGB(150, 255, 150)
        UI.targetLbl.Text = "🎯 " .. S.target.Name
        UI.targetLbl.TextColor3 = Color3.fromRGB(150, 255, 180)
    elseif S.enabled then
        UI.statusLbl.Text = "● กำลังหาเป้า..."
        UI.statusLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
        UI.targetLbl.Text = "🎯 เป้า: -"
    else
        UI.statusLbl.Text = "● ปิด"
        UI.statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
        UI.targetLbl.Text = "🎯 เป้า: -"
        UI.targetLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
    end

    if S.enabled then
        UI.toggleBtn.Text = "🛑 ปิด Ghost"
        UI.toggleBtn.BackgroundColor3 = Color3.fromRGB(130, 40, 40)
    else
        UI.toggleBtn.Text = "👻 เปิด Ghost (Aim)"
        UI.toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 130)
    end
end

function UI.refreshHotkey()
    if not UI.hotkeyBtn or not showHotkey then return end
    if S.hotkeyWaiting then
        UI.hotkeyBtn.Text = "⌨ กดปุ่ม..."
        UI.hotkeyBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
    elseif S.hotkey then
        UI.hotkeyBtn.Text = "⌨ " .. S.hotkey.Name .. " (คลิกเปลี่ยน)"
        UI.hotkeyBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 90)
    else
        UI.hotkeyBtn.Text = "⌨ ตั้งปุ่ม Hotkey"
        UI.hotkeyBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 60)
    end
end

function UI.refreshSpectate()
    if S.spectateActive then
        UI.toggleSpectateBtn.Text = "🎥 ปิดกล้อง"
        UI.toggleSpectateBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
    else
        UI.toggleSpectateBtn.Text = "🎥 เปิดกล้อง"
        UI.toggleSpectateBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 60)
    end
    UI.smoothBtn.Text = string.format("✨ %.2f", S.spectateSmooth)
end

function UI.refreshList()
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("TextButton") or c:IsA("Frame") then
            c:Destroy()
        end
    end

    local players = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                table.insert(players, p)
            end
        end
    end
    table.sort(players, function(a, b) return a.Name:lower() < b.Name:lower() end)

    if #players == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, sz(30))
        empty.BackgroundTransparency = 1
        empty.Text = "(ไม่มีผู้เล่นอื่น)"
        empty.TextColor3 = Color3.fromRGB(180, 180, 180)
        empty.Font = Enum.Font.Gotham
        empty.TextSize = sz(11)
        empty.Parent = scroll
        return
    end

    for i, p in ipairs(players) do
        local isTarget = (S.enabled and S.target == p)
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -4, 0, listItemH)
        row.BackgroundColor3 = isTarget
            and Color3.fromRGB(60, 140, 90)
            or Color3.fromRGB(40, 40, 60)
        row.BorderSizePixel = 0
        row.Text = ""
        row.LayoutOrder = i
        row.Parent = scroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -80, 1, 0)
        nameLbl.Position = UDim2.new(0, 8, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = p.DisplayName
        nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = normalFont
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local actionLbl = Instance.new("TextLabel")
        actionLbl.Size = UDim2.new(0, 70, 1, 0)
        actionLbl.Position = UDim2.new(1, -74, 0, 0)
        actionLbl.BackgroundTransparency = 1
        actionLbl.Text = isTarget and "▶ หยุด" or "▶ เกาะ"
        actionLbl.TextColor3 = isTarget
            and Color3.fromRGB(255, 200, 100)
            or Color3.fromRGB(180, 220, 255)
        actionLbl.Font = Enum.Font.GothamBold
        actionLbl.TextSize = smallFont
        actionLbl.Parent = row

        row.MouseButton1Click:Connect(function()
            if not S.alive then return end
            if S.enabled and S.target == p then
                stopGhost()
            else
                if S.enabled then stopGhost() end
                startGhost(p)
            end
            UI.refreshList()
        end)
    end
end

function UI.refreshAll()
    if not S.alive then return end
    UI.refreshStatus()
    UI.refreshHotkey()
    UI.refreshList()
    UI.refreshSpectate()
    refreshSliders()
end

-- ═══ HOTKEY ═══
local function onHotkeyPress()
    if not S.alive then return end
    local now = tick()
    if now - S.lastHotkeyTime < 0.15 then return end
    S.lastHotkeyTime = now

    if S.enabled then
        stopGhost()
    else
        local target = getPlayerFromAim() or getPlayerInSight() or getNearestPlayer()
        if target then
            startGhost(target)
        else
            print("[Ghost] ไม่พบเป้า")
        end
    end
end

local function rebindHotkey(newKey)
    pcall(function() ContextActionService:UnbindAction(S.HOTKEY_ACTION) end)
    S.hotkey = newKey
    if newKey then
        pcall(function()
            ContextActionService:BindAction(
                S.HOTKEY_ACTION,
                function(_, state)
                    if state == Enum.UserInputState.Begin then
                        onHotkeyPress()
                    end
                    return Enum.ContextActionResult.Pass
                end,
                false,
                newKey
            )
        end)
        print("[Ghost] Hotkey =", newKey.Name)
    else
        print("[Ghost] ลบ hotkey")
    end
    UI.refreshHotkey()
end

-- ═══ BUTTONS ═══
toggleBtn.MouseButton1Click:Connect(function()
    if not S.alive then return end
    toggleGhost()
end)

if showHotkey then
    hotkeyBtn.MouseButton1Click:Connect(function()
        if not S.alive then return end
        S.hotkeyWaiting = true
        UI.refreshHotkey()
    end)

    clearHotkeyBtn.MouseButton1Click:Connect(function()
        if not S.alive then return end
        S.hotkeyWaiting = false
        rebindHotkey(nil)
    end)
end

refreshBtn.MouseButton1Click:Connect(function()
    if not S.alive then return end
    UI.refreshList()
end)

toggleSpectateBtn.MouseButton1Click:Connect(function()
    if not S.alive then return end
    if S.spectateActive then
        disableSpectate()
    else
        enableSpectate()
    end
end)

local smoothLevels = {0.15, 0.25, 0.4, 0.6, 1.0}
local smoothIdx = 2
smoothBtn.MouseButton1Click:Connect(function()
    if not S.alive then return end
    smoothIdx = smoothIdx + 1
    if smoothIdx > #smoothLevels then smoothIdx = 1 end
    S.spectateSmooth = smoothLevels[smoothIdx]
    UI.refreshSpectate()
end)

killBtn.MouseButton1Click:Connect(function()
    shutdown()
end)

-- ═══ SPECTATE INPUT ═══
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not S.alive then return end
    if not S.enabled then return end
    if not S.spectateActive then return end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        S.spectateMouseDown = true
        S.spectateLastMouseX = input.Position.X
        S.spectateLastMouseY = input.Position.Y
    end
    if input.UserInputType == Enum.UserInputType.Touch then
        S.spectateMouseDown = true
        S.spectateLastMouseX = input.Position.X
        S.spectateLastMouseY = input.Position.Y
    end
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        S.spectateDist = clamp(S.spectateDist - input.Position.Z * 2, 4, 50)
        currentPresetIdx = 0
        if UI.refreshPresets then UI.refreshPresets(0) end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not S.alive then return end
    if not S.enabled then return end
    if not S.spectateActive then return end
    if not S.spectateMouseDown then return end

    if input.UserInputType == Enum.UserInputType.MouseMovement then
        local dx = input.Position.X - S.spectateLastMouseX
        local dy = input.Position.Y - S.spectateLastMouseY
        S.spectateLastMouseX = input.Position.X
        S.spectateLastMouseY = input.Position.Y
        S.spectateYaw = S.spectateYaw + dx * 0.3
        S.spectatePitch = clamp(S.spectatePitch - dy * 0.3, -80, 80)
        currentPresetIdx = 0
    end
    if input.UserInputType == Enum.UserInputType.Touch then
        local dx = input.Position.X - S.spectateLastMouseX
        local dy = input.Position.Y - S.spectateLastMouseY
        S.spectateLastMouseX = input.Position.X
        S.spectateLastMouseY = input.Position.Y
        S.spectateYaw = S.spectateYaw + dx * 0.5
        S.spectatePitch = clamp(S.spectatePitch - dy * 0.5, -80, 80)
        currentPresetIdx = 0
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2
        or input.UserInputType == Enum.UserInputType.Touch then
        S.spectateMouseDown = false
    end
end)

-- ═══ KEYBOARD INPUT (PC only) ═══
if showHotkey then
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not S.alive then return end

        if S.hotkeyWaiting then
            if input.KeyCode == Enum.KeyCode.Escape then
                S.hotkeyWaiting = false
                UI.refreshHotkey()
                return
            end
            if input.KeyCode == Enum.KeyCode.Backspace
                or input.KeyCode == Enum.KeyCode.Delete then
                S.hotkeyWaiting = false
                rebindHotkey(nil)
                return
            end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode ~= Enum.KeyCode.Unknown then
                    S.hotkeyWaiting = false
                    rebindHotkey(input.KeyCode)
                end
            end
        end
    end)
end

-- ═══ RESPAWN ═══
LP.CharacterAdded:Connect(function()
    if not S.alive then return end
    if S.enabled then
        task.wait(0.5)
        if S.enabled and S.alive then
            stopGhost()
        end
    end
end)

-- ═══ AUTO REFRESH ═══
task.spawn(function()
    while S.alive do
        task.wait(2)
        if not S.alive then break end
        if UI.refreshStatus then UI.refreshStatus() end
        if UI.refreshList then UI.refreshList() end
    end
end)

-- ═══ ROTATE HANDLER (Mobile) ═══
pcall(function()
    Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if not S.alive then return end
        if not UI.main then return end

        local vp = Camera.ViewportSize
        if not vp then return end

        -- อัปเดตค่าจอ
        screenX = vp.X
        screenY = vp.Y
        minSide = math.min(screenX, screenY)

        -- อัปเดต safe zone
        local newTop, newBottom = 0, 0
        pcall(function()
            newTop, newBottom = GuiService:GetGuiInset()
        end)
        safeTop = touchMode and math.max(newTop, screenY * 0.03) or newTop
        safeBottom = touchMode and math.max(newBottom, screenY * 0.03) or newBottom

        -- Resize ถ้าไม่ minimized
        if not S.collapsed and not isMinimized then
            local mw = mainW
            local mh = mainH
            if mh > screenY - safeTop - safeBottom - 20 then
                mh = screenY - safeTop - safeBottom - 20
            end
            UI.main.Size = UDim2.new(0, mw, 0, mh)

            -- ปรับตำแหน่งถ้าล้น
            local posX = UI.main.Position.X.Offset
            local posY = UI.main.Position.Y.Offset
            if posX + mw > screenX - safeRight then
                UI.main.Position = UDim2.new(0, screenX - safeRight - mw - 10, 0, posY)
            end
            if posY + mh > screenY - safeBottom then
                UI.main.Position = UDim2.new(0, posX, 0, screenY - safeBottom - mh - 10)
            end
        end
    end)
end)

-- ═══ INIT ═══
UI.refreshAll()
setMode("stick")

print("[Ghost V7] ════════════════════════════")
print("[Ghost V7] โหลดเสร็จ")
print("[Ghost V7] Platform:", platform)
print("[Ghost V7] Device:", deviceType)
print("[Ghost V7] UI Scale:", uiScale)
print("[Ghost V7] Touch:", touchMode, "| Hotkey:", showHotkey)
print("[Ghost V7] ════════════════════════════")
