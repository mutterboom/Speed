-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Ghost Stick V3 | Hide + Stick + Aim/List + Hotkey + Spectate ║
-- ║  - ซ่อนตัวเองเฉพาะ client (LocalTransparencyModifier)         ║
-- ║  - เกาะใต้+หลังเป้า ปรับระยะได้                                ║
-- ║  - กล้อง Spectate แบบ Boomxico V8.5                           ║
-- ║  - เลือกเป้าจาก aim หรือ list + Hotkey                        ║
-- ╚═══════════════════════════════════════════════════════════════╝
do
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ContextActionService = game:GetService("ContextActionService")

    local LP = Players.LocalPlayer
    local Camera = workspace.CurrentCamera

    -- Device
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local isPC = UserInputService.KeyboardEnabled

    local uiScale = isMobile and 0.85 or 1.0
    local function sz(px) return math.floor(px * uiScale) end

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

        distance = 3,
        backOffset = 2,

        hideLocal = true,
        savedTransparency = {},
        charListener = nil,

        hotkey = nil,
        hotkeyWaiting = false,
        lastHotkeyTime = 0,
        HOTKEY_ACTION = "GhostStick_Hotkey_V3",

        -- Spectate
        spectateYaw = 0,
        spectatePitch = -10,
        spectateDist = 12,
        spectateMouseDown = false,
        spectateLastMouseX = 0,
        spectateLastMouseY = 0,
        spectateBound = false,

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
        cam.CFrame = CFrame.new(camPos, targetHead.Position)
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

        -- Spectate
        S.spectateYaw = 0
        S.spectatePitch = -10
        S.spectateDist = 12
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
    -- UI
    -- ═══════════════════════════════════════════
    local gui = Instance.new("ScreenGui")
    gui.Name = "GhostStickUI_V3"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LP:WaitForChild("PlayerGui")
    UI.gui = gui

    local mainW = sz(280)
    local mainH = sz(520)

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, mainW, 0, mainH)
    main.Position = UDim2.new(0, 20, 0, 60)
    main.BackgroundColor3 = Color3.fromRGB(10, 8, 18)
    main.BackgroundTransparency = 0.1
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(150, 100, 255)
    stroke.Thickness = 1.5

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -20, 0, sz(34))
    title.Position = UDim2.new(0, 10, 0, sz(6))
    title.BackgroundTransparency = 1
    title.Text = "👻 GHOST STICK V3"
    title.TextColor3 = Color3.fromRGB(200, 170, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = sz(16)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = main

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -20, 0, sz(18))
    statusLbl.Position = UDim2.new(0, 10, 0, sz(42))
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "● ปิด"
    statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLbl.Font = Enum.Font.Code
    statusLbl.TextSize = sz(12)
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = main
    UI.statusLbl = statusLbl

    local targetLbl = Instance.new("TextLabel")
    targetLbl.Size = UDim2.new(1, -20, 0, sz(18))
    targetLbl.Position = UDim2.new(0, 10, 0, sz(62))
    targetLbl.BackgroundTransparency = 1
    targetLbl.Text = "🎯 เป้า: -"
    targetLbl.TextColor3 = Color3.fromRGB(255, 220, 100)
    targetLbl.Font = Enum.Font.Code
    targetLbl.TextSize = sz(12)
    targetLbl.TextXAlignment = Enum.TextXAlignment.Left
    targetLbl.Parent = main
    UI.targetLbl = targetLbl

    -- Toggle Button
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, -20, 0, sz(36))
    toggleBtn.Position = UDim2.new(0, 10, 0, sz(88))
    toggleBtn.BackgroundColor3 = Color3.fromRGB(80, 40, 130)
    toggleBtn.BorderSizePixel = 0
    toggleBtn.Text = "👻 เปิด Ghost (Aim)"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = sz(13)
    toggleBtn.Parent = main
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
    UI.toggleBtn = toggleBtn

    -- Hotkey Button
    local hotkeyBtn = Instance.new("TextButton")
    hotkeyBtn.Size = UDim2.new(1, -20, 0, sz(32))
    hotkeyBtn.Position = UDim2.new(0, 10, 0, sz(130))
    hotkeyBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 60)
    hotkeyBtn.BorderSizePixel = 0
    hotkeyBtn.Text = "⌨ ตั้งปุ่ม Hotkey"
    hotkeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hotkeyBtn.Font = Enum.Font.GothamBold
    hotkeyBtn.TextSize = sz(12)
    hotkeyBtn.Visible = isPC
    hotkeyBtn.Parent = main
    Instance.new("UICorner", hotkeyBtn).CornerRadius = UDim.new(0, 8)
    UI.hotkeyBtn = hotkeyBtn

    -- Slider: ระยะใต้
    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1, -20, 0, sz(18))
    distLbl.Position = UDim2.new(0, 10, 0, sz(170))
    distLbl.BackgroundTransparency = 1
    distLbl.Text = "📏 ใต้เป้า: 3.0 studs"
    distLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
    distLbl.Font = Enum.Font.Code
    distLbl.TextSize = sz(12)
    distLbl.TextXAlignment = Enum.TextXAlignment.Left
    distLbl.Parent = main
    UI.distLbl = distLbl

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -20, 0, sz(8))
    sliderBg.Position = UDim2.new(0, 10, 0, sz(192))
    sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = main
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
    offLbl.Position = UDim2.new(0, 10, 0, sz(216))
    offLbl.BackgroundTransparency = 1
    offLbl.Text = "↩ หลังเป้า: 2.0 studs"
    offLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
    offLbl.Font = Enum.Font.Code
    offLbl.TextSize = sz(12)
    offLbl.TextXAlignment = Enum.TextXAlignment.Left
    offLbl.Parent = main
    UI.offLbl = offLbl

    local sliderBg2 = Instance.new("Frame")
    sliderBg2.Size = UDim2.new(1, -20, 0, sz(8))
    sliderBg2.Position = UDim2.new(0, 10, 0, sz(238))
    sliderBg2.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    sliderBg2.BorderSizePixel = 0
    sliderBg2.Parent = main
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

    -- List
    local listTitle = Instance.new("TextLabel")
    listTitle.Size = UDim2.new(1, -20, 0, sz(18))
    listTitle.Position = UDim2.new(0, 10, 0, sz(256))
    listTitle.BackgroundTransparency = 1
    listTitle.Text = "👥 เลือกเป้า (คลิกเพื่อเกาะ)"
    listTitle.TextColor3 = Color3.fromRGB(180, 200, 255)
    listTitle.Font = Enum.Font.GothamBold
    listTitle.TextSize = sz(11)
    listTitle.TextXAlignment = Enum.TextXAlignment.Left
    listTitle.Parent = main

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 0, sz(180))
    scroll.Position = UDim2.new(0, 10, 0, sz(278))
    scroll.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    scroll.BackgroundTransparency = 0.6
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = main
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
    refreshBtn.Parent = main
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
    clearHotkeyBtn.Parent = main
    Instance.new("UICorner", clearHotkeyBtn).CornerRadius = UDim.new(0, 6)

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
        UI.refreshStatus()
        UI.refreshHotkey()
        UI.refreshList()
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
        toggleGhost()
    end)

    hotkeyBtn.MouseButton1Click:Connect(function()
        S.hotkeyWaiting = true
        UI.refreshHotkey()
    end)

    clearHotkeyBtn.MouseButton1Click:Connect(function()
        S.hotkeyWaiting = false
        rebindHotkey(nil)
    end)

    refreshBtn.MouseButton1Click:Connect(function()
        UI.refreshList()
    end)

    -- ═══════════════════════════════════════════
    -- SPECTATE INPUT (Mouse drag + Zoom)
    -- ═══════════════════════════════════════════
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not S.enabled or not S.alive then return end

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
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not S.enabled or not S.alive then return end
        if not S.spectateMouseDown then return end

        if input.UserInputType == Enum.UserInputType.MouseMovement then
            local dx = input.Position.X - S.spectateLastMouseX
            local dy = input.Position.Y - S.spectateLastMouseY
            S.spectateLastMouseX = input.Position.X
            S.spectateLastMouseY = input.Position.Y
            S.spectateYaw = S.spectateYaw + dx * 0.3
            S.spectatePitch = clamp(S.spectatePitch - dy * 0.3, -80, 80)
        end
        if input.UserInputType == Enum.UserInputType.Touch then
            local dx = input.Position.X - S.spectateLastMouseX
            local dy = input.Position.Y - S.spectateLastMouseY
            S.spectateLastMouseX = input.Position.X
            S.spectateLastMouseY = input.Position.Y
            S.spectateYaw = S.spectateYaw + dx * 0.5
            S.spectatePitch = clamp(S.spectatePitch - dy * 0.5, -80, 80)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2
            or input.UserInputType == Enum.UserInputType.Touch then
            S.spectateMouseDown = false
        end
    end)

    -- ═══════════════════════════════════════════
    -- KEYBOARD INPUT (Hotkey waiting)
    -- ═══════════════════════════════════════════
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

    -- ═══════════════════════════════════════════
    -- RESPAWN HANDLER
    -- ═══════════════════════════════════════════
    LP.CharacterAdded:Connect(function()
        if S.enabled then
            task.wait(0.5)
            if S.enabled then
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
            if UI.refreshStatus then UI.refreshStatus() end
            if UI.refreshList then UI.refreshList() end
        end
    end)

    -- ═══════════════════════════════════════════
    -- INIT
    -- ═══════════════════════════════════════════
    UI.refreshAll()
    print("[Ghost Stick V3] โหลดเสร็จ")
end
