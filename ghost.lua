-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Ghost Stick V5 | Hide + Stick + Camera + Auto UI             ║
-- ║  - ซ่อนตัวเองเฉพาะ client                                     ║
-- ║  - เกาะใต้+หลังเป้า ปรับได้                                   ║
-- ║  - กล้อง Spectate + Smooth (แก้สั่น)                          ║
-- ║  - Preset กล้อง 8 แบบ                                          ║
-- ║  - ปุ่ม พับ / ปิดสคริปต์                                      ║
-- ║  - Auto UI Scale (PC / Mobile / Tablet)                       ║
-- ║  - ซ่อน Hotkey บน Mobile                                      ║
-- ╚═══════════════════════════════════════════════════════════════╝
do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ContextActionService = game:GetService("ContextActionService")

    local LP = Players.LocalPlayer
    local Camera = workspace.CurrentCamera

    -- ═══════════════════════════════════════════
    -- DEVICE DETECTION + AUTO UI SCALE
    -- ═══════════════════════════════════════════
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local isPC = UserInputService.KeyboardEnabled
    local isConsole = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled

    local viewport = Camera.ViewportSize
    local screenX = viewport.X
    local screenY = viewport.Y
    local minSide = math.min(screenX, screenY)

    local deviceType = "PC"
    local uiScale = 1.0

    if isMobile then
        if minSide < 380 then
            deviceType = "Mobile-Small"
            uiScale = 0.65
        elseif minSide < 450 then
            deviceType = "Mobile-Mid"
            uiScale = 0.78
        elseif minSide < 600 then
            deviceType = "Mobile-Large"
            uiScale = 0.88
        else
            deviceType = "Tablet"
            uiScale = 0.95
        end
    elseif isConsole then
        deviceType = "Console"
        uiScale = 1.1
    else
        -- PC: ปรับตามความสูงจอ
        if screenY < 700 then
            uiScale = 0.85
        elseif screenY < 900 then
            uiScale = 0.95
        elseif screenY < 1200 then
            uiScale = 1.0
        else
            uiScale = 1.15
        end
    end

    local function sz(px) return math.floor(px * uiScale) end

    print("[Ghost V5] Device:", deviceType, "| Scale:", uiScale, "| Screen:", screenX, "x", screenY)

    -- ล้าง GUI เก่า
    pcall(function()
        for _, g in ipairs(LP:WaitForChild("PlayerGui"):GetChildren()) do
            if g.Name:find("^GhostStick") then g:Destroy() end
        end
    end)

    -- ═══════════════════════════════════════════
    -- STATE
    -- ═══════════════════════════════════════════
    local S = {
        enabled = false,
        target = nil,
        stickConn = nil,
        alive = true,
        collapsed = false,

        distance = 3,
        backOffset = 2,

        hideLocal = true,
        savedTransparency = {},
        charListener = nil,

        hotkey = nil,
        hotkeyWaiting = false,
        lastHotkeyTime = 0,
        HOTKEY_ACTION = "GhostStick_Hotkey_V5",

        spectateYaw = 0,
        spectatePitch = -10,
        spectateDist = 12,
        spectateMouseDown = false,
        spectateLastMouseX = 0,
        spectateLastMouseY = 0,
        spectateBound = false,
        spectateSmooth = 0.25,
        spectateActive = true,

        mode = "aim",
    }

    local UI = {}

    -- ═══════════════════════════════════════════
    -- UTIL
    -- ═══════════════════════════════════════════
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
        if mouse and mouse.Hit then
            local origin = Camera.CFrame.Position
            local dir = (mouse.Hit.Position - origin)
            if dir.Magnitude > 0.1 then
                dir = dir.Unit * 500
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {LP.Character, Camera}
                params.IgnoreWater = true
                local result = workspace:Raycast(origin, dir, params)
                if result and result.Instance then
                    local model = result.Instance:FindFirstAncestorOfClass("Model")
                    while model do
                        local plr = Players:GetPlayerFromCharacter(model)
                        if plr and plr ~= LP then return plr end
                        model = model:FindFirstAncestorOfClass("Model")
                    end
                end
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

    -- ═══════════════════════════════════════════
    -- HIDE / RESTORE
    -- ═══════════════════════════════════════════
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

    -- ═══════════════════════════════════════════
    -- STICK LOOP
    -- ═══════════════════════════════════════════
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
        local stickPos = tgtHRP.Position
            + Vector3.new(0, -S.distance, 0)
            - (look * S.backOffset)

        myHRP.CFrame = CFrame.new(stickPos, stickPos + look)
        myHRP.AssemblyLinearVelocity = Vector3.zero
        myHRP.AssemblyAngularVelocity = Vector3.zero
    end

    -- ═══════════════════════════════════════════
    -- SPECTATE CAMERA
    -- ═══════════════════════════════════════════
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

        if S.spectateDist < 6 then
            local tgtHRP = targetChar:FindFirstChild("HumanoidRootPart")
            if tgtHRP then
                local posStable = tgtHRP.Position + Vector3.new(0, 1.5, 0)
                local camPos2 = posStable + offset
                local stableCF = CFrame.new(camPos2, posStable)
                cam.CFrame = cam.CFrame:Lerp(stableCF, smooth * 0.8)
            end
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

    local currentPresetIdx = 0

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

    -- ═══════════════════════════════════════════
    -- START / STOP
    -- ═══════════════════════════════════════════
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

        print("[Ghost] ON | target:", S.target.Name)
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

    -- ═══════════════════════════════════════════
    -- SHUTDOWN (ปิดสคริปต์ทั้งหมด)
    -- ═══════════════════════════════════════════
    local function shutdown()
        S.alive = false
        -- ปิด Ghost
        if S.enabled then
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
        end
        -- ลบ hotkey
        pcall(function() ContextActionService:UnbindAction(S.HOTKEY_ACTION) end)
        -- ลบ GUI
        if UI.gui then
            pcall(function()
                UI.gui:Destroy()
            end)
            UI.gui = nil
        end
        print("[Ghost] ปิดสคริปต์เรียบร้อย")
    end

    -- ═══════════════════════════════════════════
    -- UI
    -- ═══════════════════════════════════════════
    local gui = Instance.new("ScreenGui")
    gui.Name = "GhostStickUI_V5"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LP:WaitForChild("PlayerGui")
    UI.gui = gui

    local mainW = sz(300)
    local mainH = sz(600)
    local collapsedW = sz(180)
    local collapsedH = sz(36)

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, mainW, 0, mainH)
    main.Position = UDim2.new(0, 20, 0, 40)
    main.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
    main.BackgroundTransparency = 0.1
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    UI.main = main

    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(150, 100, 255)
    stroke.Thickness = 1.5

    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, sz(36))
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundTransparency = 1
    titleBar.Active = true
    titleBar.Parent = main
    UI.titleBar = titleBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -sz(150), 0, sz(34))
    title.Position = UDim2.new(0, sz(10), 0, sz(1))
    title.BackgroundTransparency = 1
    title.Text = "👻 GHOST V5"
    title.TextColor3 = Color3.fromRGB(200, 170, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = sz(15)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    UI.title = title

    -- Collapse Button
    local collapseBtn = Instance.new("TextButton")
    collapseBtn.Size = UDim2.new(0, sz(30), 0, sz(28))
    collapseBtn.Position = UDim2.new(1, -sz(106), 0, sz(4))
    collapseBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)
    collapseBtn.BorderSizePixel = 0
    collapseBtn.Text = "▼"
    collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    collapseBtn.Font = Enum.Font.GothamBold
    collapseBtn.TextSize = sz(14)
    collapseBtn.Parent = titleBar
    Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 6)
    UI.collapseBtn = collapseBtn

    -- Kill Button
    local killBtn = Instance.new("TextButton")
    killBtn.Size = UDim2.new(0, sz(30), 0, sz(28))
    killBtn.Position = UDim2.new(1, -sz(72), 0, sz(4))
    killBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
    killBtn.BorderSizePixel = 0
    killBtn.Text = "✕"
    killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    killBtn.Font = Enum.Font.GothamBold
    killBtn.TextSize = sz(14)
    killBtn.Parent = titleBar
    Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 6)
    UI.killBtn = killBtn

    -- Minimize Toggle (ย่อเหลือเล็ก)
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, sz(30), 0, sz(28))
    minimizeBtn.Position = UDim2.new(1, -sz(36), 0, sz(4))
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.Text = "−"
    minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.TextSize = sz(14)
    minimizeBtn.Parent = titleBar
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 6)
    UI.minimizeBtn = minimizeBtn

    -- ===== BODY (จะถูกซ่อนตอน collapsed) =====
    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 1, -sz(36))
    body.Position = UDim2.new(0, 0, 0, sz(36))
    body.BackgroundTransparency = 1
    body.Parent = main
    UI.body = body

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -20, 0, sz(18))
    statusLbl.Position = UDim2.new(0, 10, 0, sz(6))
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "● ปิด"
    statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLbl.Font = Enum.Font.Code
    statusLbl.TextSize = sz(12)
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
    targetLbl.TextSize = sz(12)
    targetLbl.TextXAlignment = Enum.TextXAlignment.Left
    targetLbl.Parent = body
    UI.targetLbl = targetLbl

    -- Toggle Button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -20, 0, sz(36))
    toggleBtn.Position = UDim2.new(0, 10, 0, sz(52))
    toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 130)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "👻 เปิด Ghost (Aim)"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = sz(13)
    toggleBtn.Parent = body
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
    UI.toggleBtn = toggleBtn

    -- Hotkey Button (PC only)
    local hotkeyBtn = Instance.new("TextButton")
    hotkeyBtn.Size = UDim2.new(1, -20, 0, sz(32))
    hotkeyBtn.Position = UDim2.new(0, 10, 0, sz(94))
    hotkeyBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 60)
    hotkeyBtn.BorderSizePixel = 0
    hotkeyBtn.Text = "⌨ ตั้งปุ่ม Hotkey"
    hotkeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hotkeyBtn.Font = Enum.Font.GothamBold
    hotkeyBtn.TextSize = sz(12)
    hotkeyBtn.Visible = isPC
    hotkeyBtn.Parent = body
    Instance.new("UICorner", hotkeyBtn).CornerRadius = UDim.new(0, 8)
    UI.hotkeyBtn = hotkeyBtn

    -- Adjust layout based on device
    local sliderStartY = isPC and sz(134) or sz(94)

    -- Slider: ระยะใต้
    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, -20, 0, sz(18))
    distLbl.Position = UDim2.new(0, 10, 0, sliderStartY)
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "📏 ใต้เป้า: 3.0 studs"
    distLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
    distLbl.Font = Enum.Font.Code
    distLbl.TextSize = sz(12)
    distLbl.TextXAlignment = Enum.TextXAlignment.Left
    distLbl.Parent = body
    UI.distLbl = distLbl

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -20, 0, sz(8))
    sliderBg.Position = UDim2.new(0, 10, 0, sliderStartY + sz(22))
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

    local sliderKnob = Instance.new("Frame")
    sliderKnob.Size = UDim2.new(0, sz(16), 0, sz(16))
    sliderKnob.Position = UDim2.new(0.2, -sz(8), 0.5, -sz(8))
    sliderKnob.BackgroundColor3 = Color3.fromRGB(220, 200, 255)
    sliderKnob.BorderSizePixel = 0
    sliderKnob.ZIndex = 5
    sliderKnob.Parent = sliderBg
    Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

    local sliderHitbox = Instance.new("TextButton")
    sliderHitbox.Size = UDim2.new(1, 0, 0, sz(24))
    sliderHitbox.Position = UDim2.new(0, 0, 0.5, -sz(12))
    sliderHitbox.BackgroundTransparency = 1
    sliderHitbox.Text = ""
    sliderHitbox.ZIndex = 10
    sliderHitbox.Parent = sliderBg

    -- Slider: Offset หลัง
    local offLbl = Instance.new("TextLabel")
    offLbl.Size = UDim2.new(1, -20, 0, sz(18))
    offLbl.Position = UDim2.new(0, 10, 0, sliderStartY + sz(46))
    offLbl.BackgroundTransparency = 1
    offLbl.Text = "↩ หลังเป้า: 2.0 studs"
    offLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
    offLbl.Font = Enum.Font.Code
    offLbl.TextSize = sz(12)
    offLbl.TextXAlignment = Enum.TextXAlignment.Left
    offLbl.Parent = body
    UI.offLbl = offLbl

    local sliderBg2 = Instance.new("Frame")
    sliderBg2.Size = UDim2.new(1, -20, 0, sz(8))
    sliderBg2.Position = UDim2.new(0, 10, 0, sliderStartY + sz(68))
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
    sliderKnob2.Size = UDim2.new(0, sz(16), 0, sz(16))
    sliderKnob2.Position = UDim2.new(0.2, -sz(8), 0.5, -sz(8))
    sliderKnob2.BackgroundColor3 = Color3.fromRGB(220, 240, 255)
    sliderKnob2.BorderSizePixel = 0
    sliderKnob2.ZIndex = 5
    sliderKnob2.Parent = sliderBg2
    Instance.new("UICorner", sliderKnob2).CornerRadius = UDim.new(1, 0)

    local sliderHitbox2 = Instance.new("TextButton")
    sliderHitbox2.Size = UDim2.new(1, 0, 0, sz(24))
    sliderHitbox2.Position = UDim2.new(0, 0, 0.5, -sz(12))
    sliderHitbox2.BackgroundTransparency = 1
    sliderHitbox2.Text = ""
    sliderHitbox2.ZIndex = 10
    sliderHitbox2.Parent = sliderBg2

    -- ===== Spectate Controls =====
    local specLabel = Instance.new("TextLabel")
    specLabel.Size = UDim2.new(1, -20, 0, sz(16))
    specLabel.Position = UDim2.new(0, 10, 0, sliderStartY + sz(88))
    specLabel.BackgroundTransparency = 1
    specLabel.Text = "🎥 กล้อง Spectate"
    specLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
    specLabel.Font = Enum.Font.GothamBold
    specLabel.TextSize = sz(11)
    specLabel.TextXAlignment = Enum.TextXAlignment.Left
    specLabel.Parent = body

    local toggleSpectateBtn = Instance.new("TextButton")
    toggleSpectateBtn.Size = UDim2.new(0.48, 0, 0, sz(28))
    toggleSpectateBtn.Position = UDim2.new(0, 10, 0, sliderStartY + sz(108))
    toggleSpectateBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
    toggleSpectateBtn.BorderSizePixel = 0
    toggleSpectateBtn.Text = "🎥 ปิดกล้อง"
    toggleSpectateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleSpectateBtn.Font = Enum.Font.GothamBold
    toggleSpectateBtn.TextSize = sz(11)
    toggleSpectateBtn.Parent = body
    Instance.new("UICorner", toggleSpectateBtn).CornerRadius = UDim.new(0, 6)
    UI.toggleSpectateBtn = toggleSpectateBtn

    local smoothBtn = Instance.new("TextButton")
    smoothBtn.Size = UDim2.new(0.48, 0, 0, sz(28))
    smoothBtn.Position = UDim2.new(0.52, 0, 0, sliderStartY + sz(108))
    smoothBtn.BackgroundColor3 = Color3.fromRGB(80, 90, 140)
    smoothBtn.BorderSizePixel = 0
    smoothBtn.Text = "✨ นุ่ม: 0.25"
    smoothBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    smoothBtn.Font = Enum.Font.GothamBold
    smoothBtn.TextSize = sz(11)
    smoothBtn.Parent = body
    Instance.new("UICorner", smoothBtn).CornerRadius = UDim.new(0, 6)
    UI.smoothBtn = smoothBtn

    local presetOpenBtn = Instance.new("TextButton")
    presetOpenBtn.Size = UDim2.new(1, -20, 0, sz(28))
    presetOpenBtn.Position = UDim2.new(0, 10, 0, sliderStartY + sz(142))
    presetOpenBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 120)
    presetOpenBtn.BorderSizePixel = 0
    presetOpenBtn.Text = "📐 สเปคจอ (แสดง)"
    presetOpenBtn.TextColor3 = Color3.fromRGB(220, 220, 255)
    presetOpenBtn.Font = Enum.Font.GothamBold
    presetOpenBtn.TextSize = sz(11)
    presetOpenBtn.Parent = body
    Instance.new("UICorner", presetOpenBtn).CornerRadius = UDim.new(0, 6)
    UI.presetOpenBtn = presetOpenBtn

    local presetFrame = Instance.new("Frame")
    presetFrame.Size = UDim2.new(1, -20, 0, sz(94))
    presetFrame.Position = UDim2.new(0, 10, 0, sliderStartY + sz(176))
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
    presetGrid.CellPadding = UDim2.new(0, 4, 0, 4)
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

    UI.refreshPresets = function(activeIdx)
        for i, btn in ipairs(presetButtons) do
            if i == activeIdx and S.spectateActive then
                btn.BackgroundColor3 = Color3.fromRGB(80, 140, 90)
                btn.TextColor3 = Color3.fromRGB(255, 255, 200)
            else
                btn.BackgroundColor3 = Color3.fromRGB(50, 60, 90)
                btn.TextColor3 = Color3.fromRGB(220, 220, 255)
            end
        end
    end

    local presetOpen = false
    presetOpenBtn.MouseButton1Click:Connect(function()
        presetOpen = not presetOpen
        presetFrame.Visible = presetOpen
        if presetOpen then
            presetOpenBtn.Text = "📐 สเปคจอ (ซ่อน)"
            presetOpenBtn.BackgroundColor3 = Color3.fromRGB(90, 70, 140)
        else
            presetOpenBtn.Text = "📐 สเปคจอ (แสดง)"
            presetOpenBtn.BackgroundColor3 = Color3.fromRGB(70, 80, 120)
        end
    end)

    -- ===== List =====
    local listY = sliderStartY + sz(280)

    local listTitle = Instance.new("TextLabel")
    listTitle.Size = UDim2.new(1, -20, 0, sz(18))
    listTitle.Position = UDim2.new(0, 10, 0, listY)
    listTitle.BackgroundTransparency = 1
    listTitle.Text = "👥 เลือกเป้า (คลิกเพื่อเกาะ)"
    listTitle.TextColor3 = Color3.fromRGB(180, 200, 255)
    listTitle.Font = Enum.Font.GothamBold
    listTitle.TextSize = sz(11)
    listTitle.TextXAlignment = Enum.TextXAlignment.Left
    listTitle.Parent = body

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 0, sz(90))
    scroll.Position = UDim2.new(0, 10, 0, listY + sz(22))
    scroll.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    scroll.BackgroundTransparency = 0.6
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
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

    -- Bottom buttons
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(0.48, 0, 0, sz(28))
    refreshBtn.Position = UDim2.new(0, 10, 1, -sz(38))
    refreshBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
    refreshBtn.BorderSizePixel = 0
    refreshBtn.Text = "🔄 รีเฟรช"
    refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshBtn.Font = Enum.Font.GothamBold
    refreshBtn.TextSize = sz(11)
    refreshBtn.Parent = body
    Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)

    local clearHotkeyBtn = Instance.new("TextButton")
    clearHotkeyBtn.Size = UDim2.new(0.48, 0, 0, sz(28))
    clearHotkeyBtn.Position = UDim2.new(0.52, 0, 1, -sz(38))
    clearHotkeyBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
    clearHotkeyBtn.BorderSizePixel = 0
    clearHotkeyBtn.Text = "🗑 ลบ Hotkey"
    clearHotkeyBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
    clearHotkeyBtn.Font = Enum.Font.GothamBold
    clearHotkeyBtn.TextSize = sz(11)
    clearHotkeyBtn.Visible = isPC
    clearHotkeyBtn.Parent = body
    Instance.new("UICorner", clearHotkeyBtn).CornerRadius = UDim.new(0, 6)

    -- ═══════════════════════════════════════════
    -- COLLAPSE LOGIC
    -- ═══════════════════════════════════════════
    local function toggleCollapse()
        S.collapsed = not S.collapsed
        if S.collapsed then
            main.Size = UDim2.new(0, collapsedW, 0, collapsedH)
            main.Position = UDim2.new(0, 20, 0, 40)
            body.Visible = false
            title.Text = "👻 Ghost"
            collapseBtn.Text = "▲"
            killBtn.Position = UDim2.new(1, -sz(36), 0, sz(4))
            minimizeBtn.Visible = false
        else
            main.Size = UDim2.new(0, mainW, 0, mainH)
            body.Visible = true
            title.Text = "👻 GHOST V5"
            collapseBtn.Text = "▼"
            killBtn.Position = UDim2.new(1, -sz(72), 0, sz(4))
            minimizeBtn.Visible = true
        end
    end

    -- Minimize (ซ่อนเหลือปุ่มเล็ก)
    local isMinimized = false
    local function toggleMinimize()
        isMinimized = not isMinimized
        if isMinimized then
            main.Size = UDim2.new(0, sz(40), 0, sz(40))
            main.Position = UDim2.new(0, 20, 0, 40)
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

    -- ═══════════════════════════════════════════
    -- SLIDER LOGIC
    -- ═══════════════════════════════════════════
    local DIST_MIN, DIST_MAX = 0, 15
    local OFF_MIN, OFF_MAX = 0, 10

    local dragDist = false
    local dragOff = false

    local function setDistance(val)
        val = clamp(val, DIST_MIN, DIST_MAX)
        S.distance = val
        local pct = (val - DIST_MIN) / (DIST_MAX - DIST_MIN)
        sliderFill.Size = UDim2.new(pct, 0, 1, 0)
        sliderKnob.Position = UDim2.new(pct, -sz(8), 0.5, -sz(8))
        UI.distLbl.Text = string.format("📏 ใต้เป้า: %.1f studs", val)
    end

    local function setBackOffset(val)
        val = clamp(val, OFF_MIN, OFF_MAX)
        S.backOffset = val
        local pct = (val - OFF_MIN) / (OFF_MAX - OFF_MIN)
        sliderFill2.Size = UDim2.new(pct, 0, 1, 0)
        sliderKnob2.Position = UDim2.new(pct, -sz(8), 0.5, -sz(8))
        UI.offLbl.Text = string.format("↩ หลังเป้า: %.1f studs", val)
    end

    local function updateDistFromX(x)
        local rel = clamp((x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        setDistance(DIST_MIN + rel * (DIST_MAX - DIST_MIN))
    end

    local function updateOffFromX(x)
        local rel = clamp((x - sliderBg2.AbsolutePosition.X) / sliderBg2.AbsoluteSize.X, 0, 1)
        setBackOffset(OFF_MIN + rel * (OFF_MAX - OFF_MIN))
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

    setDistance(3)
    setBackOffset(2)

    -- ═══════════════════════════════════════════
    -- REFRESH UI
    -- ═══════════════════════════════════════════
    function UI.refreshStatus()
        if S.enabled and S.target then
            UI.statusLbl.Text = "● เปิด (ซ่อนตัว)"
            UI.statusLbl.TextColor3 = Color3.fromRGB(150, 255, 150)
            UI.targetLbl.Text = "🎯 เป้า: " .. S.target.Name
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
        if not UI.hotkeyBtn then return end
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
        UI.smoothBtn.Text = string.format("✨ นุ่ม: %.2f", S.spectateSmooth)
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
            row.Size = UDim2.new(1, -4, 0, sz(32))
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
            nameLbl.TextSize = sz(12)
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
            actionLbl.TextSize = sz(11)
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
    end

    -- ═══════════════════════════════════════════
    -- HOTKEY
    -- ═══════════════════════════════════════════
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

    -- ═══════════════════════════════════════════
    -- BUTTONS
    -- ═══════════════════════════════════════════
    toggleBtn.MouseButton1Click:Connect(function()
        if not S.alive then return end
        toggleGhost()
    end)

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

    -- ═══════════════════════════════════════════
    -- SPECTATE INPUT
    -- ═══════════════════════════════════════════
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

    -- ═══════════════════════════════════════════
    -- KEYBOARD INPUT (Hotkey waiting) - PC only
    -- ═══════════════════════════════════════════
    if isPC then
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

    -- ═══════════════════════════════════════════
    -- RESPAWN HANDLER
    -- ═══════════════════════════════════════════
    LP.CharacterAdded:Connect(function()
        if not S.alive then return end
        if S.enabled then
            task.wait(0.5)
            if S.enabled and S.alive then
                stopGhost()
            end
        end
    end)

    -- ═══════════════════════════════════════════
    -- AUTO REFRESH
    -- ═══════════════════════════════════════════
    task.spawn(function()
        while S.alive do
            task.wait(2)
            if not S.alive then break end
            if UI.refreshStatus then UI.refreshStatus() end
            if UI.refreshList then UI.refreshList() end
        end
    end)

    -- ═══════════════════════════════════════════
    -- INIT
    -- ═══════════════════════════════════════════
    UI.refreshAll()
    print("[Ghost Stick V5] โหลดเสร็จ | Device:", deviceType)
end
