-- ============================================
-- By Boomxico | Golden Glass UI V8.5
-- FIX: Out of local registers (do...end block)
-- UPDATE: Sync Stick UI + Hide Hotkey on Mobile + Distance Slider
-- ============================================
do
    if not game:IsLoaded() then game.Loaded:Wait() end

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local ContextActionService = game:GetService("ContextActionService")

    local player = Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    local isPC = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
    local isMobile = UserInputService.TouchEnabled

    -- ✅ State table (ลด local vars)
    local S = {
        speedEnabled = false,
        flyEnabled = false,
        espEnabled = false,
        nameEnabled = false,
        noclipEnabled = false,
        fpsBoostEnabled = false,
        teamCheckEnabled = false,
        stickEnabled = false,
        scriptAlive = true,
        isOpen = true,
        runSpeed = 50,
        flySpeed = 50,
        NAME_MAX_DIST = 800,
        espColorIndex = 1,
        STICK_DISTANCE = 3,
        STICK_DISTANCE_MIN = 1,
        STICK_DISTANCE_MAX = 15,
        bodyVel = nil,
        bodyGyro = nil,
        runAnimator = nil,
        runAnimTrack = nil,
        noclipConnection = nil,
        speedConnection = nil,
        speedConn = nil,
        speedHeartbeat = nil,
        flyConnection = nil,
        stickConnection = nil,
        fpsBoostBackup = {},
        stickTarget = nil,
        stickHotkey = nil,
        stickLastHotkey = 0,
        stickHotkeyWaiting = false,
        lastToggleTime = 0,
        TOGGLE_COOLDOWN = 0.4,
        spectateTarget = nil,
        spectateEnabled = false,
        spectateYaw = 0,
        spectatePitch = -10,
        spectateDist = 12,
        lastMouseX = 0,
        lastMouseY = 0,
        mouseDown = false,
        noclipBusy = false,
        dragging = false,
        dragStart = nil,
        startPos = nil,
        hotkeyEditTarget = nil,
        espOpen = false,
    }

    S.STICK_ACTION = "BoomStickHotkeyV85"

    local UI = {}

    S.dirs = {F=false, B=false, L=false, R=false, U=false, D=false}
    S.pcKeys = {W=false, A=false, S=false, D=false, Space=false, Shift=false}

    S.hotkeys = {
        speed = {key = nil, pressed = false},
        fly = {key = nil, pressed = false}
    }

    S.savedState = {
        speed = false, speedVal = 50,
        fly = false, flyVal = 50,
        esp = false, name = false, nameDist = 800,
        noclip = false, fpsBoost = false,
        espColorIdx = 1, teamCheck = false,
        stickDist = 3
    }

    local ESP_COLORS = {
        {name = "ทอง",   color = Color3.fromRGB(255, 180, 0)},
        {name = "แดง",   color = Color3.fromRGB(255, 40, 40)},
        {name = "เขียว", color = Color3.fromRGB(40, 255, 80)},
        {name = "ฟ้า",   color = Color3.fromRGB(60, 170, 255)},
        {name = "ม่วง",  color = Color3.fromRGB(180, 60, 255)},
        {name = "ชมพู",  color = Color3.fromRGB(255, 80, 200)},
        {name = "ขาว",   color = Color3.fromRGB(255, 255, 255)},
        {name = "ดำ",    color = Color3.fromRGB(30, 30, 30)},
    }

    local espObjects = {}
    local nameObjects = {}
    local nameData = {}
    local playerRows = {}
    local glowObjects = {}
    local colorButtons = {}

    local COLOR_BG = Color3.fromRGB(8, 8, 10)
    local COLOR_BG_LIGHT = Color3.fromRGB(22, 22, 28)
    local COLOR_BORDER = Color3.fromRGB(255, 180, 0)
    local COLOR_TEXT = Color3.fromRGB(255, 230, 140)
    local COLOR_TEXT_DIM = Color3.fromRGB(180, 150, 60)
    local COLOR_ACCENT = Color3.fromRGB(255, 200, 0)
    local COLOR_GLOW = Color3.fromRGB(255, 230, 100)
    local COLOR_ACTIVE_BG = Color3.fromRGB(120, 90, 0)
    local COLOR_DANGER_BG = Color3.fromRGB(80, 15, 15)
    local COLOR_STICK_ACTIVE = Color3.fromRGB(60, 150, 90)
    local COLOR_SILVER = Color3.fromRGB(230, 230, 240)
    local COLOR_SILVER_DIM = Color3.fromRGB(160, 160, 175)

    local viewport = workspace.CurrentCamera.ViewportSize
    local screenX = viewport.X
    local screenY = viewport.Y
    local minSide = math.min(screenX, screenY)

    local deviceType = "PC"
    if isMobile then
        if minSide < 380 then deviceType = "Mobile-Small"
        elseif minSide < 450 then deviceType = "Mobile-Mid"
        elseif minSide < 600 then deviceType = "Mobile-Large"
        else deviceType = "Tablet" end
    end

    local uiScale
    if deviceType == "Mobile-Small" then uiScale = 0.65
    elseif deviceType == "Mobile-Mid" then uiScale = 0.8
    elseif deviceType == "Mobile-Large" then uiScale = 0.9
    elseif deviceType == "Tablet" then uiScale = 1.0
    else uiScale = 1.0 end

    local mainWidth = math.floor(280 * uiScale)
    local mainHeight = math.floor(math.min(520, screenY * 0.72))
    local mainX = 15
    local mainY = math.max(60, (screenY - mainHeight) / 2)

    print("[Boom V8.5] Platform:", deviceType, "| Scale:", uiScale)

    pcall(function()
        for _, name in ipairs({"StickTP_Hotkey", "StickTP_Hotkey_v13", "StickTP_Hotkey_v14", S.STICK_ACTION}) do
            pcall(function() ContextActionService:UnbindAction(name) end)
        end
    end)

    -- Helpers
    local function canToggle()
        local now = tick()
        if now - S.lastToggleTime < S.TOGGLE_COOLDOWN then return false end
        S.lastToggleTime = now
        return true
    end

    local function clamp(v, minV, maxV)
        if v < minV then return minV end
        if v > maxV then return maxV end
        return v
    end

    local function scaledSize(px)
        return math.floor(px * uiScale)
    end

    local function getCurrentESPColor()
        local entry = ESP_COLORS[S.espColorIndex] or ESP_COLORS[1]
        return entry.color
    end

    local function getHRP(plr)
        if not plr or not plr.Parent then return nil end
        local c = plr.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    S.runAnimator = humanoid:FindFirstChildOfClass("Animator")
    if not S.runAnimator then
        S.runAnimator = Instance.new("Animator")
        S.runAnimator.Parent = humanoid
    end

    local function addGlow(target, baseTransparency, isTitle)
        local stroke = Instance.new("UIStroke", target)
        stroke.Color = COLOR_BORDER
        stroke.Thickness = isTitle and 1.5 or 1
        stroke.Transparency = baseTransparency or 0.7
        table.insert(glowObjects, {stroke = stroke, base = baseTransparency or 0.7, title = isTitle})
        return stroke
    end

    task.spawn(function()
        while S.scriptAlive do
            local t = tick()
            for _, obj in ipairs(glowObjects) do
                if obj.stroke and obj.stroke.Parent then
                    local pulse = math.sin(t * 2) * 0.5 + 0.5
                    local target
                    if obj.title then
                        target = 0.3 + pulse * 0.25
                    else
                        target = obj.base + pulse * 0.1
                    end
                    obj.stroke.Transparency = target
                end
            end
            task.wait(0.05)
        end
    end)

    -- ============================================
    -- Speed (3-layer guard)
    -- ============================================
    local function applySpeedNow()
        if not S.scriptAlive then return end
        if not S.speedEnabled then return end
        if S.flyEnabled then return end
        if S.stickEnabled then return end
        if not humanoid or not humanoid.Parent then return end
        if humanoid.Health <= 0 then return end
        if humanoid.WalkSpeed ~= S.runSpeed then
            humanoid.WalkSpeed = S.runSpeed
        end
    end

    local function startSpeedLoop()
        if S.speedConnection then return end
        S.speedConnection = RunService.Heartbeat:Connect(applySpeedNow)
        if S.speedConn then S.speedConn:Disconnect() end
        S.speedConn = RunService.RenderStepped:Connect(applySpeedNow)
        if S.speedHeartbeat then S.speedHeartbeat:Disconnect() end
        S.speedHeartbeat = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if S.speedEnabled and not S.flyEnabled and not S.stickEnabled then
                if humanoid.WalkSpeed ~= S.runSpeed then
                    humanoid.WalkSpeed = S.runSpeed
                end
            end
        end)
        applySpeedNow()
    end

    local function stopSpeedLoop()
        if S.speedConnection then S.speedConnection:Disconnect(); S.speedConnection = nil end
        if S.speedConn then S.speedConn:Disconnect(); S.speedConn = nil end
        if S.speedHeartbeat then S.speedHeartbeat:Disconnect(); S.speedHeartbeat = nil end
    end

    local function toggleSpeed()
        if not canToggle() then return end
        if not humanoid or not humanoid.Parent then
            warn("[Speed] Humanoid not ready")
            return
        end
        S.speedEnabled = not S.speedEnabled
        UI.spdBtn.Text = S.speedEnabled and "วิ่งไว: เปิด" or "วิ่งไว: ปิด"
        UI.spdBtn.BackgroundColor3 = S.speedEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
        S.savedState.speed = S.speedEnabled
        S.savedState.speedVal = S.runSpeed
        if S.speedEnabled then
            stopSpeedLoop()
            humanoid.WalkSpeed = S.runSpeed
            startSpeedLoop()
            print("[Speed] ON", S.runSpeed)
        else
            stopSpeedLoop()
            if humanoid and humanoid.Parent then
                humanoid.WalkSpeed = 16
            end
            print("[Speed] OFF")
        end
    end

    -- ============================================
    -- Fly
    -- ============================================
    local function getGameRunTrack()
        if not S.runAnimator then return nil end
        local tracks = S.runAnimator:GetPlayingAnimationTracks()
        for _, track in pairs(tracks) do
            local nm = track.Name or ""
            local anim = track.Animation
            local id = anim and anim.AnimationId or ""
            if nm == "run" or nm == "RunAnim" or id == "rbxassetid://507767714" or string.find(id, "run") then
                return track
            end
        end
        local fb = Instance.new("Animation")
        fb.AnimationId = "rbxassetid://507767714"
        local ok, track = pcall(function() return S.runAnimator:LoadAnimation(fb) end)
        if ok then return track end
        return nil
    end

    local function startFly()
        if S.bodyVel then S.bodyVel:Destroy() end
        if S.bodyGyro then S.bodyGyro:Destroy() end

        S.bodyVel = Instance.new("BodyVelocity")
        S.bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        S.bodyVel.Velocity = Vector3.new(0, 0, 0)
        S.bodyVel.P = 1250
        S.bodyVel.Parent = rootPart

        S.bodyGyro = Instance.new("BodyGyro")
        S.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        S.bodyGyro.P = 3000
        S.bodyGyro.D = 50
        S.bodyGyro.CFrame = workspace.CurrentCamera.CFrame
        S.bodyGyro.Parent = rootPart

        humanoid.PlatformStand = false
        humanoid:ChangeState(Enum.HumanoidStateType.Running)

        task.wait(0.1)

        S.runAnimTrack = getGameRunTrack()
        if S.runAnimTrack then
            S.runAnimTrack.Priority = Enum.AnimationPriority.Action
            S.runAnimTrack.Looped = true
            pcall(function() S.runAnimTrack:Play(0.1) end)
        end

        if isMobile and UI.pad then UI.pad.Visible = true end

        if S.flyConnection then S.flyConnection:Disconnect() end
        S.flyConnection = RunService.RenderStepped:Connect(function()
            if not S.scriptAlive then return end
            if not S.flyEnabled then return end
            if not S.bodyVel or not S.bodyGyro then return end
            if not rootPart or not rootPart.Parent then return end
            if not humanoid or not humanoid.Parent then return end

            humanoid:ChangeState(Enum.HumanoidStateType.Running)
            humanoid.PlatformStand = false

            if S.runAnimTrack then
                if not S.runAnimTrack.IsPlaying then
                    pcall(function() S.runAnimTrack:Play(0.1) end)
                end
                local ratio = math.clamp(S.flySpeed / 50, 0.5, 3)
                pcall(function() S.runAnimTrack:AdjustSpeed(ratio) end)
            end

            S.bodyGyro.CFrame = workspace.CurrentCamera.CFrame

            local cam = workspace.CurrentCamera
            local mv = Vector3.new(0, 0, 0)

            if isMobile then
                if S.dirs.F then mv = mv + cam.CFrame.LookVector end
                if S.dirs.B then mv = mv - cam.CFrame.LookVector end
                if S.dirs.L then mv = mv - cam.CFrame.RightVector end
                if S.dirs.R then mv = mv + cam.CFrame.RightVector end
                if S.dirs.U then mv = mv + Vector3.new(0, 1, 0) end
                if S.dirs.D then mv = mv - Vector3.new(0, 1, 0) end
            end

            if isPC then
                if S.pcKeys.W then mv = mv + cam.CFrame.LookVector end
                if S.pcKeys.S then mv = mv - cam.CFrame.LookVector end
                if S.pcKeys.A then mv = mv - cam.CFrame.RightVector end
                if S.pcKeys.D then mv = mv + cam.CFrame.RightVector end
                if S.pcKeys.Space then mv = mv + Vector3.new(0, 1, 0) end
                if S.pcKeys.Shift then mv = mv - Vector3.new(0, 1, 0) end
            end

            if mv.Magnitude > 0 then
                local jitter = 1 + (math.random() - 0.5) * 0.03
                S.bodyVel.Velocity = mv.Unit * S.flySpeed * jitter
            else
                S.bodyVel.Velocity = Vector3.new(0, 0, 0)
            end
        end)
    end

    local function stopFly()
        if S.flyConnection then S.flyConnection:Disconnect(); S.flyConnection = nil end
        if S.bodyVel then S.bodyVel:Destroy(); S.bodyVel = nil end
        if S.bodyGyro then S.bodyGyro:Destroy(); S.bodyGyro = nil end
        if S.runAnimTrack then
            pcall(function() S.runAnimTrack:Stop(0.1) end)
            S.runAnimTrack = nil
        end
        if humanoid and humanoid.Parent == character then
            humanoid.PlatformStand = false
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            if S.speedEnabled and not S.stickEnabled then
                humanoid.WalkSpeed = S.runSpeed
                stopSpeedLoop()
                startSpeedLoop()
            else
                humanoid.WalkSpeed = 16
            end
        end
        if UI.pad then UI.pad.Visible = false end
        for k in pairs(S.dirs) do S.dirs[k] = false end
    end

    -- ============================================
    -- Stick
    -- ============================================
    local function getPlayerFromAim()
        local mouse = player:GetMouse()
        if mouse and mouse.Target then
            local part = mouse.Target
            local model = part:FindFirstAncestorOfClass("Model")
            while model do
                local plr = Players:GetPlayerFromCharacter(model)
                if plr and plr ~= player then return plr end
                model = model:FindFirstAncestorOfClass("Model")
            end
        end
        if mouse and mouse.Hit then
            local cam = workspace.CurrentCamera
            local origin = cam.CFrame.Position
            local direction = (mouse.Hit.Position - origin)
            if direction.Magnitude > 0.1 then
                direction = direction.Unit * 500
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Exclude
                params.FilterDescendantsInstances = {player.Character, cam}
                params.IgnoreWater = true
                local result = workspace:Raycast(origin, direction, params)
                if result and result.Instance then
                    local model = result.Instance:FindFirstAncestorOfClass("Model")
                    while model do
                        local plr = Players:GetPlayerFromCharacter(model)
                        if plr and plr ~= player then return plr end
                        model = model:FindFirstAncestorOfClass("Model")
                    end
                end
            end
        end
        return nil
    end

    local function getPlayerInSight()
        local cam = workspace.CurrentCamera
        local camPos = cam.CFrame.Position
        local camLook = cam.CFrame.LookVector
        local best, bestScore = nil, -1
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                local hrp = getHRP(plr)
                if hrp then
                    local toTarget = (hrp.Position - camPos)
                    local dist = toTarget.Magnitude
                    if dist > 0 then
                        local dot = camLook:Dot(toTarget.Unit)
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
        local myHRP = getHRP(player)
        if not myHRP then return nil end
        local nearest, minDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player then
                local hrp = getHRP(plr)
                if hrp then
                    local d = (hrp.Position - myHRP.Position).Magnitude
                    if d < minDist then minDist = d; nearest = plr end
                end
            end
        end
        return nearest
    end

    local function stickLoop()
        if not S.stickEnabled or not S.scriptAlive then return end
        local myHRP = getHRP(player)
        if not myHRP then return end
        if not S.stickTarget or not getHRP(S.stickTarget) then
            S.stickTarget = getNearestPlayer()
            if not S.stickTarget then return end
            if UI.refreshStickStatus then UI.refreshStickStatus() end
        end
        local tgtHRP = getHRP(S.stickTarget)
        if not tgtHRP then return end
        local lookVec = tgtHRP.CFrame.LookVector
        local stickPos = tgtHRP.Position - (lookVec * S.STICK_DISTANCE)
        local cf = CFrame.new(stickPos, tgtHRP.Position)
        myHRP.CFrame = cf
        myHRP.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        myHRP.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
    end

    local function startStick(target)
        if S.stickEnabled then return end
        S.stickEnabled = true
        S.stickTarget = target or S.stickTarget or getNearestPlayer()
        if not S.stickTarget then
            S.stickEnabled = false
            return
        end
        if S.stickConnection then
            pcall(function() S.stickConnection:Disconnect() end)
            S.stickConnection = nil
        end
        S.stickConnection = RunService.Heartbeat:Connect(stickLoop)
        print("[Stick] ON | target:", S.stickTarget.Name)
        if UI.refreshStickUI then UI.refreshStickUI() end
        if UI.refreshStickStatus then UI.refreshStickStatus() end
    end

    local function stopStick()
        if not S.stickEnabled then return end
        S.stickEnabled = false
        S.stickTarget = nil
        if S.stickConnection then
            pcall(function() S.stickConnection:Disconnect() end)
            S.stickConnection = nil
        end
        if humanoid and humanoid.Parent == character then
            if S.speedEnabled and not S.flyEnabled then
                humanoid.WalkSpeed = S.runSpeed
                stopSpeedLoop()
                startSpeedLoop()
            else
                humanoid.WalkSpeed = 16
            end
        end
        print("[Stick] OFF")
        if UI.refreshStickUI then UI.refreshStickUI() end
        if UI.refreshStickStatus then UI.refreshStickStatus() end
    end

    local function onStickHotkeyPress()
        if not S.scriptAlive then return end
        local now = tick()
        if now - S.stickLastHotkey < 0.15 then return end
        S.stickLastHotkey = now
        if S.stickEnabled then
            stopStick()
            return
        end
        local aimPlr = getPlayerFromAim() or getPlayerInSight() or getNearestPlayer()
        if aimPlr then
            startStick(aimPlr)
        end
    end

    local function rebindStickHotkey(newKey)
        pcall(function() ContextActionService:UnbindAction(S.STICK_ACTION) end)
        S.stickHotkey = newKey
        if newKey then
            pcall(function()
                ContextActionService:BindAction(
                    S.STICK_ACTION,
                    function(_, state)
                        if state == Enum.UserInputState.Begin then
                            onStickHotkeyPress()
                        end
                        return Enum.ContextActionResult.Pass
                    end,
                    false,
                    newKey
                )
            end)
        end
        if UI.refreshStickHotkeyBtn then UI.refreshStickHotkeyBtn() end
    end

    -- ============================================
    -- Noclip
    -- ============================================
    local function enableNoclip()
        if S.noclipConnection then return end
        S.noclipConnection = RunService.Stepped:Connect(function()
            if not S.noclipEnabled then return end
            if not character or not character.Parent then return end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
    end

    local function disableNoclip()
        if S.noclipConnection then
            S.noclipConnection:Disconnect()
            S.noclipConnection = nil
        end
        if character and character.Parent then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function() part.CanCollide = true end)
                end
            end
        end
    end

    -- ============================================
    -- FPS Boost
    -- ============================================
    local function enableFPSBoost()
        if not S.fpsBoostEnabled then return end
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                if obj.Enabled then
                    table.insert(S.fpsBoostBackup, {obj = obj, prop = "Enabled", val = true})
                    obj.Enabled = false
                end
            end
        end
        local Lighting = game:GetService("Lighting")
        table.insert(S.fpsBoostBackup, {obj = Lighting, prop = "GlobalShadows", val = Lighting.GlobalShadows})
        Lighting.GlobalShadows = false
    end

    local function disableFPSBoost()
        for _, data in ipairs(S.fpsBoostBackup) do
            if data.obj and data.obj.Parent ~= nil then
                pcall(function() data.obj[data.prop] = data.val end)
            end
        end
        S.fpsBoostBackup = {}
    end

    -- ============================================
    -- Team Check
    -- ============================================
    local function isSameTeam(targetPlayer)
        if not S.teamCheckEnabled then return false end
        if not targetPlayer then return false end
        if targetPlayer == player then return true end
        local myTeam = player.Team
        local targetTeam = targetPlayer.Team
        if myTeam ~= nil and targetTeam ~= nil then
            return myTeam == targetTeam
        end
        return false
    end

    -- ============================================
    -- ESP
    -- ============================================
    local function clearESP()
        for _, obj in ipairs(espObjects) do
            if obj and obj.hl and obj.hl.Parent then
                obj.hl:Destroy()
            end
        end
        espObjects = {}
    end

    local function applyESP(char, targetPlayer)
        if not char or not char.Parent then return end
        if isSameTeam(targetPlayer) then return end
        for i = #espObjects, 1, -1 do
            if espObjects[i].player == targetPlayer then
                if espObjects[i].hl and espObjects[i].hl.Parent then
                    espObjects[i].hl:Destroy()
                end
                table.remove(espObjects, i)
            end
        end
        local hl = Instance.new("Highlight")
        hl.Name = "BoomESP"
        hl.Adornee = char
        hl.FillColor = getCurrentESPColor()
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.4
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
        table.insert(espObjects, {hl = hl, player = targetPlayer})
    end

    local function refreshESP()
        clearESP()
        if not S.espEnabled then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character.Parent then
                applyESP(p.Character, p)
            end
        end
    end

    -- ============================================
    -- Names
    -- ============================================
    local function clearNames()
        for _, obj in pairs(nameObjects) do
            if obj then obj:Destroy() end
        end
        nameObjects = {}
        nameData = {}
    end

    local function applyName(char, pName, targetPlayer)
        if not char then return end
        if isSameTeam(targetPlayer) then return end
        local head = char:FindFirstChild("Head")
        if not head then return end
        local bg = Instance.new("BillboardGui")
        bg.Name = "BoomName"
        bg.Size = UDim2.new(0, scaledSize(110), 0, scaledSize(24))
        bg.StudsOffset = Vector3.new(0, 2.8, 0)
        bg.AlwaysOnTop = true
        bg.LightInfluence = 0
        bg.MaxDistance = S.NAME_MAX_DIST
        bg.Adornee = head
        bg.Parent = head
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = pName or "?"
        lbl.TextColor3 = COLOR_SILVER
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(40, 40, 50)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = scaledSize(14)
        lbl.Parent = bg
        table.insert(nameObjects, bg)
        table.insert(nameData, {gui = bg, head = head})
    end

    local function refreshNames()
        clearNames()
        if not S.nameEnabled then return end
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                applyName(p.Character, p.Name, p)
            end
        end
    end

    -- ============================================
    -- UI
    -- ============================================
    local gui = Instance.new("ScreenGui")
    gui.Name = "ByBoomMenu"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = player:WaitForChild("PlayerGui")
    UI.gui = gui

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, scaledSize(55), 0, scaledSize(55))
    toggleBtn.Position = UDim2.new(0, 20, 0, 100)
    toggleBtn.BackgroundColor3 = COLOR_BG
    toggleBtn.BackgroundTransparency = 0.4
    toggleBtn.Text = "B"
    toggleBtn.TextColor3 = COLOR_TEXT
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = scaledSize(24)
    toggleBtn.TextStrokeTransparency = 0.4
    toggleBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    toggleBtn.Active = true
    toggleBtn.Draggable = true
    toggleBtn.Parent = gui
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)
    addGlow(toggleBtn, 0.5, true)

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, mainWidth, 0, mainHeight)
    main.Position = UDim2.new(0, mainX, 0, mainY)
    main.BackgroundColor3 = COLOR_BG
    main.BackgroundTransparency = 0.4
    main.Active = false
    main.ClipsDescendants = true
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 18)
    addGlow(main, 0.7, false)
    UI.main = main

    local topLine = Instance.new("Frame")
    topLine.Size = UDim2.new(1, -30, 0, 2)
    topLine.Position = UDim2.new(0, 15, 0, 0)
    topLine.BackgroundColor3 = COLOR_ACCENT
    topLine.BorderSizePixel = 0
    topLine.Parent = main
    Instance.new("UICorner", topLine).CornerRadius = UDim.new(1, 0)

    local title = Instance.new("TextButton")
    title.Size = UDim2.new(1, -20, 0, scaledSize(42))
    title.Position = UDim2.new(0, 10, 0, scaledSize(8))
    title.BackgroundTransparency = 1
    title.Text = "BY BOOMXICO V8.5"
    title.TextColor3 = COLOR_TEXT
    title.TextStrokeTransparency = 0.4
    title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = scaledSize(20)
    title.Active = true
    title.Parent = main

    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            S.dragging = true
            S.dragStart = input.Position
            S.startPos = main.Position
        end
    end)

    title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            S.dragging = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if S.dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - S.dragStart
            main.Position = UDim2.new(
                S.startPos.X.Scale, S.startPos.X.Offset + delta.X,
                S.startPos.Y.Scale, S.startPos.Y.Offset + delta.Y
            )
        end
    end)

    local titleGlow = Instance.new("UIStroke", title)
    titleGlow.Color = COLOR_GLOW
    titleGlow.Thickness = 1
    titleGlow.Transparency = 0.5
    table.insert(glowObjects, {stroke = titleGlow, base = 0.5, title = true})

    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, -math.floor(20 * uiScale), 1, -math.floor(62 * uiScale))
    scrollFrame.Position = UDim2.new(0, 0, 0, scaledSize(58))
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = COLOR_ACCENT
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scrollFrame.Parent = main

    local scrollPad = Instance.new("UIPadding")
    scrollPad.PaddingTop = UDim.new(0, 6)
    scrollPad.PaddingBottom = UDim.new(0, 6)
    scrollPad.PaddingRight = UDim.new(0, 4)
    scrollPad.Parent = scrollFrame

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 0)
    container.BackgroundTransparency = 1
    container.Parent = scrollFrame
    container.AutomaticSize = Enum.AutomaticSize.Y

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = container

    local function mkBtn(labelText)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0.9, 0, 0, scaledSize(36))
        btn.BackgroundColor3 = COLOR_BG_LIGHT
        btn.BackgroundTransparency = 0.5
        btn.TextColor3 = COLOR_TEXT
        btn.TextStrokeTransparency = 0.5
        btn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = scaledSize(13)
        btn.Text = labelText
        btn.LayoutOrder = #container:GetChildren() + 1
        btn.Parent = container
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
        addGlow(btn, 0.7, false)
        return btn
    end

    -- ============================================
    -- Stick Row (มี Slider)
    -- ============================================
    local stickRow = Instance.new("Frame")
    stickRow.Size = UDim2.new(0.9, 0, 0, scaledSize(82))
    stickRow.BackgroundColor3 = Color3.fromRGB(20, 30, 40)
    stickRow.BackgroundTransparency = 0.4
    stickRow.LayoutOrder = 0
    stickRow.Parent = container
    Instance.new("UICorner", stickRow).CornerRadius = UDim.new(0, 10)
    addGlow(stickRow, 0.7, false)

    local stickToggleBtn = Instance.new("TextButton")
    stickToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    stickToggleBtn.BackgroundTransparency = 0.2
    stickToggleBtn.Text = "🎯 เกาะ: ปิด"
    stickToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stickToggleBtn.Font = Enum.Font.GothamBold
    stickToggleBtn.TextSize = scaledSize(12)
    stickToggleBtn.Parent = stickRow
    Instance.new("UICorner", stickToggleBtn).CornerRadius = UDim.new(0, 10)

    if isPC then
        stickToggleBtn.Size = UDim2.new(0.65, 0, 0, scaledSize(28))
        stickToggleBtn.Position = UDim2.new(0, 0, 0, scaledSize(4))
    else
        stickToggleBtn.Size = UDim2.new(0.98, 0, 0, scaledSize(28))
        stickToggleBtn.Position = UDim2.new(0.01, 0, 0, scaledSize(4))
    end

    local stickHotkeyBtn = Instance.new("TextButton")
    stickHotkeyBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 60)
    stickHotkeyBtn.BackgroundTransparency = 0.2
    stickHotkeyBtn.Text = "⌨ ตั้งปุ่ม"
    stickHotkeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stickHotkeyBtn.Font = Enum.Font.GothamBold
    stickHotkeyBtn.TextSize = scaledSize(10)
    stickHotkeyBtn.Parent = stickRow
    Instance.new("UICorner", stickHotkeyBtn).CornerRadius = UDim.new(0, 10)

    if isPC then
        stickHotkeyBtn.Size = UDim2.new(0.32, 0, 0, scaledSize(28))
        stickHotkeyBtn.Position = UDim2.new(0.68, 0, 0, scaledSize(4))
        stickHotkeyBtn.Visible = true
    else
        stickHotkeyBtn.Size = UDim2.new(0, 0, 0, 0)
        stickHotkeyBtn.Visible = false
    end

    local stickStatusLbl = Instance.new("TextLabel")
    stickStatusLbl.Size = UDim2.new(1, -10, 0, scaledSize(18))
    stickStatusLbl.Position = UDim2.new(0, 5, 0, scaledSize(34))
    stickStatusLbl.BackgroundTransparency = 1
    stickStatusLbl.Text = "🎯 เป้า: -"
    stickStatusLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
    stickStatusLbl.Font = Enum.Font.Code
    stickStatusLbl.TextSize = scaledSize(11)
    stickStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
    stickStatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
    stickStatusLbl.Parent = stickRow

    -- ===== Slider ระยะเกาะ =====
    local stickSliderRow = Instance.new("Frame")
    stickSliderRow.Size = UDim2.new(1, -10, 0, scaledSize(22))
    stickSliderRow.Position = UDim2.new(0, 5, 0, scaledSize(56))
    stickSliderRow.BackgroundTransparency = 1
    stickSliderRow.Parent = stickRow

    local stickDistLbl = Instance.new("TextLabel")
    stickDistLbl.Size = UDim2.new(0.42, 0, 1, 0)
    stickDistLbl.BackgroundTransparency = 1
    stickDistLbl.Text = "ระยะเกาะ: 3"
    stickDistLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
    stickDistLbl.Font = Enum.Font.Code
    stickDistLbl.TextSize = scaledSize(11)
    stickDistLbl.TextXAlignment = Enum.TextXAlignment.Left
    stickDistLbl.Parent = stickSliderRow

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(0.56, 0, 0, scaledSize(6))
    sliderBg.Position = UDim2.new(0.44, 0, 0.5, -scaledSize(3))
    sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = stickSliderRow
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0.142, 0, 1, 0)
    sliderFill.BackgroundColor3 = COLOR_ACCENT
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

    local sliderKnob = Instance.new("Frame")
    sliderKnob.Size = UDim2.new(0, scaledSize(14), 0, scaledSize(14))
    sliderKnob.Position = UDim2.new(0.142, -scaledSize(7), 0.5, -scaledSize(7))
    sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 230, 100)
    sliderKnob.BorderSizePixel = 0
    sliderKnob.ZIndex = 5
    sliderKnob.Parent = sliderBg
    Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

    local sliderStroke = Instance.new("UIStroke", sliderKnob)
    sliderStroke.Color = Color3.fromRGB(120, 90, 0)
    sliderStroke.Thickness = 2

    local sliderHitbox = Instance.new("TextButton")
    sliderHitbox.Size = UDim2.new(1, 0, 0, scaledSize(24))
    sliderHitbox.Position = UDim2.new(0, 0, 0.5, -scaledSize(12))
    sliderHitbox.BackgroundTransparency = 1
    sliderHitbox.Text = ""
    sliderHitbox.ZIndex = 10
    sliderHitbox.Parent = sliderBg

    local sliderDragging = false

    local function setStickDistance(val)
        val = clamp(val, S.STICK_DISTANCE_MIN, S.STICK_DISTANCE_MAX)
        S.STICK_DISTANCE = val
        S.savedState.stickDist = val
        local pct = (val - S.STICK_DISTANCE_MIN) / (S.STICK_DISTANCE_MAX - S.STICK_DISTANCE_MIN)
        sliderFill.Size = UDim2.new(pct, 0, 1, 0)
        sliderKnob.Position = UDim2.new(pct, -scaledSize(7), 0.5, -scaledSize(7))
        local txt = tostring(val)
        if val == math.floor(val) then txt = tostring(math.floor(val)) end
        stickDistLbl.Text = "ระยะเกาะ: " .. txt
    end
    UI.setStickDistance = setStickDistance

    local function updateStickSlider(inputX)
        local barAbs = sliderBg.AbsolutePosition.X
        local barW = sliderBg.AbsoluteSize.X
        if barW <= 0 then return end
        local pct = clamp((inputX - barAbs) / barW, 0, 1)
        local val = S.STICK_DISTANCE_MIN + pct * (S.STICK_DISTANCE_MAX - S.STICK_DISTANCE_MIN)
        val = math.floor(val * 10 + 0.5) / 10
        setStickDistance(val)
    end

    sliderHitbox.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = true
            updateStickSlider(input.Position.X)
        end
    end)

    sliderHitbox.InputChanged:Connect(function(input)
        if sliderDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateStickSlider(input.Position.X)
        end
    end)

    sliderHitbox.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliderDragging = false
        end
    end)

    setStickDistance(S.STICK_DISTANCE)

    -- ===== Refresh UI functions =====
    UI.refreshStickUI = function()
        if S.stickEnabled then
            stickToggleBtn.Text = "🎯 เกาะ: เปิด"
            stickToggleBtn.BackgroundColor3 = COLOR_STICK_ACTIVE
        else
            stickToggleBtn.Text = "🎯 เกาะ: ปิด"
            stickToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
        end
    end

    UI.refreshStickStatus = function()
        if S.stickEnabled and S.stickTarget then
            stickStatusLbl.Text = "🎯 เป้า: " .. S.stickTarget.Name
            stickStatusLbl.TextColor3 = Color3.fromRGB(150, 255, 180)
        elseif S.stickEnabled then
            stickStatusLbl.Text = "🎯 กำลังหาเป้า..."
            stickStatusLbl.TextColor3 = Color3.fromRGB(255, 200, 100)
        else
            stickStatusLbl.Text = "🎯 เป้า: -"
            stickStatusLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
    end

    UI.refreshStickHotkeyBtn = function()
        if S.stickHotkeyWaiting then
            stickHotkeyBtn.Text = "⌨ กดปุ่ม..."
            stickHotkeyBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 40)
            stickHotkeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        elseif S.stickHotkey then
            stickHotkeyBtn.Text = "⌨ " .. S.stickHotkey.Name
            stickHotkeyBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 90)
            stickHotkeyBtn.TextColor3 = Color3.fromRGB(255, 255, 200)
        else
            stickHotkeyBtn.Text = "⌨ ตั้งปุ่ม"
            stickHotkeyBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 60)
            stickHotkeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
    end

    stickToggleBtn.MouseButton1Click:Connect(function()
        if S.stickEnabled then
            stopStick()
        else
            startStick(nil)
        end
    end)

    stickHotkeyBtn.MouseButton1Click:Connect(function()
        S.stickHotkeyWaiting = true
        UI.refreshStickHotkeyBtn()
    end)

    -- Row 1: Speed
    local row1 = Instance.new("Frame")
    row1.Size = UDim2.new(0.9, 0, 0, scaledSize(36))
    row1.BackgroundTransparency = 1
    row1.LayoutOrder = 1
    row1.Parent = container

    local spdBtn = Instance.new("TextButton")
    spdBtn.Size = UDim2.new(0.62, 0, 1, 0)
    spdBtn.BackgroundColor3 = COLOR_BG_LIGHT
    spdBtn.BackgroundTransparency = 0.5
    spdBtn.TextColor3 = COLOR_TEXT
    spdBtn.TextStrokeTransparency = 0.5
    spdBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    spdBtn.Font = Enum.Font.GothamMedium
    spdBtn.TextSize = scaledSize(13)
    spdBtn.Text = "วิ่งไว: ปิด"
    spdBtn.Parent = row1
    Instance.new("UICorner", spdBtn).CornerRadius = UDim.new(0, 10)
    addGlow(spdBtn, 0.7, false)
    UI.spdBtn = spdBtn

    local spdBox = Instance.new("TextBox")
    spdBox.Size = UDim2.new(0.34, 0, 1, 0)
    spdBox.Position = UDim2.new(0.66, 0, 0, 0)
    spdBox.BackgroundColor3 = COLOR_BG_LIGHT
    spdBox.BackgroundTransparency = 0.5
    spdBox.Text = "50"
    spdBox.TextColor3 = COLOR_ACCENT
    spdBox.TextStrokeTransparency = 0.5
    spdBox.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    spdBox.Font = Enum.Font.GothamBold
    spdBox.TextSize = scaledSize(13)
    spdBox.Parent = row1
    Instance.new("UICorner", spdBox).CornerRadius = UDim.new(0, 10)
    addGlow(spdBox, 0.7, false)
    UI.spdBox = spdBox

    -- Row 2: Fly
    local row2 = Instance.new("Frame")
    row2.Size = UDim2.new(0.9, 0, 0, scaledSize(36))
    row2.BackgroundTransparency = 1
    row2.LayoutOrder = 2
    row2.Parent = container

    local flyBtn = Instance.new("TextButton")
    flyBtn.Size = UDim2.new(0.62, 0, 1, 0)
    flyBtn.BackgroundColor3 = COLOR_BG_LIGHT
    flyBtn.BackgroundTransparency = 0.5
    flyBtn.TextColor3 = COLOR_TEXT
    flyBtn.TextStrokeTransparency = 0.5
    flyBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    flyBtn.Font = Enum.Font.GothamMedium
    flyBtn.TextSize = scaledSize(13)
    flyBtn.Text = "บินได้: ปิด"
    flyBtn.Parent = row2
    Instance.new("UICorner", flyBtn).CornerRadius = UDim.new(0, 10)
    addGlow(flyBtn, 0.7, false)
    UI.flyBtn = flyBtn

    local flyBox = Instance.new("TextBox")
    flyBox.Size = UDim2.new(0.34, 0, 1, 0)
    flyBox.Position = UDim2.new(0.66, 0, 0, 0)
    flyBox.BackgroundColor3 = COLOR_BG_LIGHT
    flyBox.BackgroundTransparency = 0.5
    flyBox.Text = "50"
    flyBox.TextColor3 = COLOR_ACCENT
    flyBox.TextStrokeTransparency = 0.5
    flyBox.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    flyBox.Font = Enum.Font.GothamBold
    flyBox.TextSize = scaledSize(13)
    flyBox.Parent = row2
    Instance.new("UICorner", flyBox).CornerRadius = UDim.new(0, 10)
    addGlow(flyBox, 0.7, false)
    UI.flyBox = flyBox

    -- Row 3: Hotkey (PC only)
    local hotkeyRow = Instance.new("Frame")
    hotkeyRow.Size = UDim2.new(0.9, 0, 0, scaledSize(28))
    hotkeyRow.BackgroundTransparency = 1
    hotkeyRow.LayoutOrder = 3
    hotkeyRow.Visible = isPC
    hotkeyRow.Parent = container

    local function mkHotkeyBtn(text, xPos)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.32, 0, 1, 0)
        b.Position = UDim2.new(xPos, 0, 0, 0)
        b.BackgroundColor3 = COLOR_BG_LIGHT
        b.BackgroundTransparency = 0.5
        b.Text = text
        b.TextColor3 = COLOR_TEXT_DIM
        b.TextStrokeTransparency = 0.5
        b.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        b.Font = Enum.Font.Gotham
        b.TextSize = scaledSize(11)
        b.Parent = hotkeyRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        addGlow(b, 0.75, false)
        return b
    end

    local hotkeySpdBtn = mkHotkeyBtn("Hotkey วิ่ง", 0)
    local hotkeyFlyBtn = mkHotkeyBtn("Hotkey บิน", 0.34)

    local hotkeyClearBtn = Instance.new("TextButton")
    hotkeyClearBtn.Size = UDim2.new(0.32, 0, 1, 0)
    hotkeyClearBtn.Position = UDim2.new(0.68, 0, 0, 0)
    hotkeyClearBtn.BackgroundColor3 = COLOR_DANGER_BG
    hotkeyClearBtn.BackgroundTransparency = 0.5
    hotkeyClearBtn.Text = "ลบ Hotkey"
    hotkeyClearBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
    hotkeyClearBtn.Font = Enum.Font.Gotham
    hotkeyClearBtn.TextSize = scaledSize(11)
    hotkeyClearBtn.Parent = hotkeyRow
    Instance.new("UICorner", hotkeyClearBtn).CornerRadius = UDim.new(0, 8)

    -- ESP Header
    local espHeader = Instance.new("TextButton")
    espHeader.Size = UDim2.new(0.9, 0, 0, scaledSize(34))
    espHeader.BackgroundColor3 = Color3.fromRGB(35, 28, 10)
    espHeader.BackgroundTransparency = 0.3
    espHeader.Text = "▶ ESP / มองทะลุ"
    espHeader.TextColor3 = COLOR_ACCENT
    espHeader.TextStrokeTransparency = 0.5
    espHeader.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    espHeader.Font = Enum.Font.GothamBold
    espHeader.TextSize = scaledSize(13)
    espHeader.LayoutOrder = 4
    espHeader.Parent = container
    Instance.new("UICorner", espHeader).CornerRadius = UDim.new(0, 10)
    addGlow(espHeader, 0.5, true)

    local espContent = Instance.new("Frame")
    espContent.Size = UDim2.new(0.9, 0, 0, 0)
    espContent.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    espContent.BackgroundTransparency = 0.5
    espContent.LayoutOrder = 5
    espContent.Parent = container
    Instance.new("UICorner", espContent).CornerRadius = UDim.new(0, 10)

    local espContentPad = Instance.new("UIPadding", espContent)
    espContentPad.PaddingTop = UDim.new(0, 6)
    espContentPad.PaddingBottom = UDim.new(0, 6)

    local espList = Instance.new("UIListLayout", espContent)
    espList.Padding = UDim.new(0, 5)
    espList.SortOrder = Enum.SortOrder.LayoutOrder
    espList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    espContent.AutomaticSize = Enum.AutomaticSize.Y
    espContent.Visible = false

    local espBtn = Instance.new("TextButton")
    espBtn.Size = UDim2.new(1, -12, 0, scaledSize(32))
    espBtn.BackgroundColor3 = COLOR_BG_LIGHT
    espBtn.BackgroundTransparency = 0.5
    espBtn.Text = "มองทะลุ: ปิด"
    espBtn.TextColor3 = COLOR_TEXT
    espBtn.TextStrokeTransparency = 0.5
    espBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    espBtn.Font = Enum.Font.GothamMedium
    espBtn.TextSize = scaledSize(12)
    espBtn.LayoutOrder = 1
    espBtn.Parent = espContent
    Instance.new("UICorner", espBtn).CornerRadius = UDim.new(0, 8)
    addGlow(espBtn, 0.7, false)
    UI.espBtn = espBtn

    local colorLabel = Instance.new("TextLabel")
    colorLabel.Size = UDim2.new(1, -12, 0, scaledSize(18))
    colorLabel.BackgroundTransparency = 1
    colorLabel.Text = "สี ESP:"
    colorLabel.TextColor3 = COLOR_TEXT_DIM
    colorLabel.Font = Enum.Font.GothamMedium
    colorLabel.TextSize = scaledSize(11)
    colorLabel.TextXAlignment = Enum.TextXAlignment.Left
    colorLabel.LayoutOrder = 2
    colorLabel.Parent = espContent

    local colorGrid = Instance.new("Frame")
    colorGrid.Size = UDim2.new(1, -12, 0, scaledSize(60))
    colorGrid.BackgroundTransparency = 1
    colorGrid.LayoutOrder = 3
    colorGrid.Parent = espContent

    local colorGridLayout = Instance.new("UIGridLayout", colorGrid)
    colorGridLayout.CellSize = UDim2.new(0, scaledSize(28), 0, scaledSize(28))
    colorGridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
    colorGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    colorGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

    for i, entry in ipairs(ESP_COLORS) do
        local wrap = Instance.new("Frame")
        wrap.Size = UDim2.new(0, scaledSize(28), 0, scaledSize(28))
        wrap.BackgroundColor3 = entry.color
        wrap.BorderSizePixel = 0
        wrap.LayoutOrder = i
        wrap.Parent = colorGrid
        Instance.new("UICorner", wrap).CornerRadius = UDim.new(1, 0)

        local stroke = Instance.new("UIStroke", wrap)
        stroke.Color = Color3.fromRGB(255, 255, 255)
        stroke.Thickness = 3
        stroke.Transparency = (i == S.espColorIndex) and 0 or 1
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        local cbtn = Instance.new("TextButton")
        cbtn.Size = UDim2.new(1, 0, 1, 0)
        cbtn.BackgroundTransparency = 1
        cbtn.Text = ""
        cbtn.ZIndex = 10
        cbtn.AutoButtonColor = false
        cbtn.Parent = wrap

        local check = Instance.new("TextLabel")
        check.Size = UDim2.new(1, 0, 1, 0)
        check.BackgroundTransparency = 1
        check.Text = "✓"
        check.TextColor3 = Color3.fromRGB(255, 255, 255)
        check.TextStrokeTransparency = 0
        check.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        check.Font = Enum.Font.GothamBold
        check.TextSize = scaledSize(14)
        check.Visible = (i == S.espColorIndex)
        check.ZIndex = 11
        check.Parent = wrap

        colorButtons[i] = {wrap = wrap, stroke = stroke, check = check, entry = entry}

        cbtn.MouseButton1Click:Connect(function()
            S.espColorIndex = i
            S.savedState.espColorIdx = i
            for j, cb in ipairs(colorButtons) do
                local selected = (j == i)
                cb.stroke.Transparency = selected and 0 or 1
                cb.check.Visible = selected
            end
            for _, obj in ipairs(espObjects) do
                if obj.hl and obj.hl.Parent then
                    obj.hl.FillColor = entry.color
                end
            end
        end)
    end

    local teamRow = Instance.new("Frame")
    teamRow.Size = UDim2.new(1, -12, 0, scaledSize(32))
    teamRow.BackgroundTransparency = 1
    teamRow.LayoutOrder = 4
    teamRow.Parent = espContent

    local teamBtn = Instance.new("TextButton")
    teamBtn.Size = UDim2.new(1, 0, 1, 0)
    teamBtn.BackgroundColor3 = COLOR_BG_LIGHT
    teamBtn.BackgroundTransparency = 0.5
    teamBtn.Text = "เช็คทีม: ปิด"
    teamBtn.TextColor3 = COLOR_TEXT
    teamBtn.TextStrokeTransparency = 0.5
    teamBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    teamBtn.Font = Enum.Font.GothamMedium
    teamBtn.TextSize = scaledSize(12)
    teamBtn.Parent = teamRow
    Instance.new("UICorner", teamBtn).CornerRadius = UDim.new(0, 8)
    addGlow(teamBtn, 0.7, false)
    UI.teamBtn = teamBtn

    local nameDistRow = Instance.new("Frame")
    nameDistRow.Size = UDim2.new(1, -12, 0, scaledSize(32))
    nameDistRow.BackgroundTransparency = 1
    nameDistRow.LayoutOrder = 5
    nameDistRow.Parent = espContent

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(0.62, 0, 1, 0)
    distLbl.BackgroundColor3 = COLOR_BG_LIGHT
    distLbl.BackgroundTransparency = 0.5
    distLbl.Text = "ระยะชื่อ"
    distLbl.TextColor3 = COLOR_TEXT
    distLbl.TextStrokeTransparency = 0.5
    distLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLbl.Font = Enum.Font.GothamMedium
    distLbl.TextSize = scaledSize(12)
    distLbl.Parent = nameDistRow
    Instance.new("UICorner", distLbl).CornerRadius = UDim.new(0, 8)
    addGlow(distLbl, 0.7, false)

    local distBox = Instance.new("TextBox")
    distBox.Size = UDim2.new(0.34, 0, 1, 0)
    distBox.Position = UDim2.new(0.66, 0, 0, 0)
    distBox.BackgroundColor3 = COLOR_BG_LIGHT
    distBox.BackgroundTransparency = 0.5
    distBox.Text = "800"
    distBox.TextColor3 = COLOR_ACCENT
    distBox.TextStrokeTransparency = 0.5
    distBox.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distBox.Font = Enum.Font.GothamBold
    distBox.TextSize = scaledSize(12)
    distBox.Parent = nameDistRow
    Instance.new("UICorner", distBox).CornerRadius = UDim.new(0, 8)
    addGlow(distBox, 0.7, false)
    UI.distBox = distBox

    espHeader.MouseButton1Click:Connect(function()
        S.espOpen = not S.espOpen
        espContent.Visible = S.espOpen
        espHeader.Text = (S.espOpen and "▼ " or "▶ ") .. "ESP / มองทะลุ"
    end)

    local nameBtn = mkBtn("เห็นชื่อ: ปิด")
    nameBtn.LayoutOrder = 6
    UI.nameBtn = nameBtn

    local noclipBtn = mkBtn("Noclip: ปิด")
    noclipBtn.LayoutOrder = 7
    UI.noclipBtn = noclipBtn

    local fpsBoostBtn = mkBtn("FPS Boost: ปิด")
    fpsBoostBtn.LayoutOrder = 8
    UI.fpsBoostBtn = fpsBoostBtn

    local openListBtn = mkBtn("เปิดเมนูรายชื่อ")
    openListBtn.LayoutOrder = 9

    local killBtn = mkBtn("ปิดสคริปต์ทั้งหมด")
    killBtn.LayoutOrder = 10
    killBtn.BackgroundColor3 = COLOR_DANGER_BG
    killBtn.BackgroundTransparency = 0.3
    killBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
    killBtn.Font = Enum.Font.GothamBold

    local closeBtn = mkBtn("ซ่อนเมนู")
    closeBtn.LayoutOrder = 11
    closeBtn.TextColor3 = COLOR_TEXT_DIM

    -- Pad (Mobile fly)
    local pad = Instance.new("Frame")
    pad.Size = UDim2.new(0, scaledSize(180), 0, scaledSize(180))
    pad.Position = UDim2.new(1, -scaledSize(200), 0.5, -scaledSize(90))
    pad.BackgroundColor3 = COLOR_BG
    pad.BackgroundTransparency = 0.4
    pad.Visible = false
    pad.Parent = gui
    Instance.new("UICorner", pad).CornerRadius = UDim.new(1, 0)
    addGlow(pad, 0.5, false)
    UI.pad = pad

    local function mkPBtn(txt, pos)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, scaledSize(50), 0, scaledSize(50))
        b.Position = pos
        b.BackgroundColor3 = Color3.fromRGB(60, 40, 0)
        b.BackgroundTransparency = 0.3
        b.Text = txt
        b.TextColor3 = COLOR_TEXT
        b.TextStrokeTransparency = 0.5
        b.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        b.Font = Enum.Font.GothamBold
        b.TextSize = scaledSize(20)
        b.Parent = pad
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        addGlow(b, 0.6, false)
        return b
    end

    local halfSize = scaledSize(25)
    local bU = mkPBtn("↑", UDim2.new(0.5, -halfSize, 0, 5))
    local bD = mkPBtn("↓", UDim2.new(0.5, -halfSize, 1, -scaledSize(55)))
    local bL = mkPBtn("←", UDim2.new(0, 5, 0.5, -halfSize))
    local bR = mkPBtn("→", UDim2.new(1, -scaledSize(55), 0.5, -halfSize))
    local bF = mkPBtn("W", UDim2.new(0.5, -halfSize, 0.5, -halfSize))

    local function bind(b, key)
        b.MouseButton1Down:Connect(function() S.dirs[key] = true; b.BackgroundColor3 = COLOR_ACTIVE_BG end)
        b.MouseButton1Up:Connect(function() S.dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(60, 40, 0) end)
        b.MouseLeave:Connect(function() S.dirs[key] = false; b.BackgroundColor3 = Color3.fromRGB(60, 40, 0) end)
    end
    bind(bU, "U"); bind(bD, "D"); bind(bL, "L"); bind(bR, "R"); bind(bF, "F")

    -- Toggle Fly
    local function toggleFly()
        if not canToggle() then return end
        S.flyEnabled = not S.flyEnabled
        flyBtn.Text = S.flyEnabled and "บินได้: เปิด" or "บินได้: ปิด"
        flyBtn.BackgroundColor3 = S.flyEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
        S.savedState.fly = S.flyEnabled
        S.savedState.flyVal = S.flySpeed
        if S.flyEnabled then
            startFly()
        else
            stopFly()
        end
    end    spdBtn.MouseButton1Click:Connect(toggleSpeed)
    flyBtn.MouseButton1Click:Connect(toggleFly)

    spdBox.FocusLost:Connect(function()
        local v = tonumber(spdBox.Text)
        if v and v > 0 then
            S.runSpeed = clamp(v, 1, 200)
        else
            spdBox.Text = "50"
            S.runSpeed = 50
        end
        S.savedState.speedVal = S.runSpeed
        if S.speedEnabled and humanoid and humanoid.Parent then
            humanoid.WalkSpeed = S.runSpeed
        end
    end)

    flyBox.FocusLost:Connect(function()
        local v = tonumber(flyBox.Text)
        if v and v > 0 then
            S.flySpeed = clamp(v, 1, 300)
        else
            flyBox.Text = "50"
            S.flySpeed = 50
        end
        S.savedState.flyVal = S.flySpeed
    end)

    -- Input
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end

        if S.stickHotkeyWaiting then
            if input.KeyCode == Enum.KeyCode.Escape then
                S.stickHotkeyWaiting = false
                UI.refreshStickHotkeyBtn()
                return
            end
            if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
                S.stickHotkeyWaiting = false
                rebindStickHotkey(nil)
                return
            end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if input.KeyCode ~= Enum.KeyCode.Unknown then
                    S.stickHotkeyWaiting = false
                    rebindStickHotkey(input.KeyCode)
                end
            end
            return
        end

        if input.KeyCode == Enum.KeyCode.W then S.pcKeys.W = true end
        if input.KeyCode == Enum.KeyCode.A then S.pcKeys.A = true end
        if input.KeyCode == Enum.KeyCode.S then S.pcKeys.S = true end
        if input.KeyCode == Enum.KeyCode.D then S.pcKeys.D = true end
        if input.KeyCode == Enum.KeyCode.Space then S.pcKeys.Space = true end
        if input.KeyCode == Enum.KeyCode.LeftShift then S.pcKeys.Shift = true end

        if input.KeyCode == Enum.KeyCode.X and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            if S.noclipBusy then return end
            S.noclipBusy = true
            S.noclipEnabled = not S.noclipEnabled
            noclipBtn.Text = S.noclipEnabled and "Noclip: เปิด" or "Noclip: ปิด"
            noclipBtn.BackgroundColor3 = S.noclipEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
            S.savedState.noclip = S.noclipEnabled
            if S.noclipEnabled then enableNoclip() else disableNoclip() end
            S.noclipBusy = false
        end

        if isPC then
            if S.hotkeys.speed.key ~= nil and input.KeyCode == S.hotkeys.speed.key then
                if not S.hotkeys.speed.pressed then
                    S.hotkeys.speed.pressed = true
                    toggleSpeed()
                end
            end
            if S.hotkeys.fly.key ~= nil and input.KeyCode == S.hotkeys.fly.key then
                if not S.hotkeys.fly.pressed then
                    S.hotkeys.fly.pressed = true
                    toggleFly()
                end
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.W then S.pcKeys.W = false end
        if input.KeyCode == Enum.KeyCode.A then S.pcKeys.A = false end
        if input.KeyCode == Enum.KeyCode.S then S.pcKeys.S = false end
        if input.KeyCode == Enum.KeyCode.D then S.pcKeys.D = false end
        if input.KeyCode == Enum.KeyCode.Space then S.pcKeys.Space = false end
        if input.KeyCode == Enum.KeyCode.LeftShift then S.pcKeys.Shift = false end
        if S.hotkeys.speed.key ~= nil and input.KeyCode == S.hotkeys.speed.key then
            S.hotkeys.speed.pressed = false
        end
        if S.hotkeys.fly.key ~= nil and input.KeyCode == S.hotkeys.fly.key then
            S.hotkeys.fly.pressed = false
        end
    end)

    -- Player List Menu
    local checkMenu = Instance.new("Frame")
    checkMenu.Size = UDim2.new(0, scaledSize(280), 0, math.floor(math.min(410, screenY * 0.6)))
    checkMenu.Position = UDim2.new(0.5, -scaledSize(140), 0.5, -math.floor(math.min(410, screenY * 0.6) / 2))
    checkMenu.BackgroundColor3 = COLOR_BG
    checkMenu.BackgroundTransparency = 0.4
    checkMenu.Active = true
    checkMenu.Draggable = true
    checkMenu.Visible = false
    checkMenu.Parent = gui
    Instance.new("UICorner", checkMenu).CornerRadius = UDim.new(0, 18)
    addGlow(checkMenu, 0.7, false)

    local cTopLine = Instance.new("Frame")
    cTopLine.Size = UDim2.new(1, -30, 0, 2)
    cTopLine.Position = UDim2.new(0, 15, 0, 0)
    cTopLine.BackgroundColor3 = COLOR_ACCENT
    cTopLine.BorderSizePixel = 0
    cTopLine.Parent = checkMenu
    Instance.new("UICorner", cTopLine).CornerRadius = UDim.new(1, 0)

    local cTitle = Instance.new("TextLabel")
    cTitle.Size = UDim2.new(1, -20, 0, scaledSize(42))
    cTitle.Position = UDim2.new(0, 10, 0, scaledSize(12))
    cTitle.BackgroundTransparency = 1
    cTitle.Text = "PLAYERS | BOOMXICO"
    cTitle.TextColor3 = COLOR_TEXT
    cTitle.Font = Enum.Font.GothamBold
    cTitle.TextSize = scaledSize(16)
    cTitle.Parent = checkMenu

    local stopSpecBtn = Instance.new("TextButton")
    stopSpecBtn.Size = UDim2.new(0.9, 0, 0, scaledSize(34))
    stopSpecBtn.Position = UDim2.new(0.05, 0, 0, scaledSize(60))
    stopSpecBtn.BackgroundColor3 = COLOR_DANGER_BG
    stopSpecBtn.BackgroundTransparency = 0.3
    stopSpecBtn.Text = "ปิดส่องกล้อง"
    stopSpecBtn.TextColor3 = Color3.fromRGB(255, 130, 130)
    stopSpecBtn.Font = Enum.Font.GothamBold
    stopSpecBtn.TextSize = scaledSize(13)
    stopSpecBtn.Parent = checkMenu
    Instance.new("UICorner", stopSpecBtn).CornerRadius = UDim.new(0, 10)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(0.9, 0, 0, scaledSize(250))
    scroll.Position = UDim2.new(0.05, 0, 0, scaledSize(102))
    scroll.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    scroll.BackgroundTransparency = 0.4
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 6
    scroll.ScrollBarImageColor3 = COLOR_ACCENT
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = checkMenu
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 12)

    local listLayout2 = Instance.new("UIListLayout")
    listLayout2.Padding = UDim.new(0, 4)
    listLayout2.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout2.Parent = scroll

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop = UDim.new(0, 6)
    listPad.PaddingLeft = UDim.new(0, 6)
    listPad.PaddingRight = UDim.new(0, 6)
    listPad.Parent = scroll

    local cCloseBtn = Instance.new("TextButton")
    cCloseBtn.Size = UDim2.new(0.9, 0, 0, scaledSize(34))
    cCloseBtn.Position = UDim2.new(0.05, 0, 1, -scaledSize(42))
    cCloseBtn.BackgroundColor3 = COLOR_BG_LIGHT
    cCloseBtn.BackgroundTransparency = 0.5
    cCloseBtn.Text = "ซ่อนเมนู"
    cCloseBtn.TextColor3 = COLOR_TEXT_DIM
    cCloseBtn.Font = Enum.Font.GothamMedium
    cCloseBtn.TextSize = scaledSize(13)
    cCloseBtn.Parent = checkMenu
    Instance.new("UICorner", cCloseBtn).CornerRadius = UDim.new(0, 10)

    -- Hotkey Popup
    local hotkeyPopup = Instance.new("Frame")
    hotkeyPopup.Size = UDim2.new(0, scaledSize(260), 0, scaledSize(200))
    hotkeyPopup.Position = UDim2.new(0.5, -scaledSize(130), 0.5, -scaledSize(100))
    hotkeyPopup.BackgroundColor3 = COLOR_BG
    hotkeyPopup.BackgroundTransparency = 0.15
    hotkeyPopup.Active = true
    hotkeyPopup.Draggable = true
    hotkeyPopup.Visible = false
    hotkeyPopup.Parent = gui
    Instance.new("UICorner", hotkeyPopup).CornerRadius = UDim.new(0, 14)

    local hpTitle = Instance.new("TextLabel")
    hpTitle.Size = UDim2.new(1, -20, 0, scaledSize(32))
    hpTitle.Position = UDim2.new(0, 10, 0, scaledSize(10))
    hpTitle.BackgroundTransparency = 1
    hpTitle.Text = "SET HOTKEY"
    hpTitle.TextColor3 = COLOR_TEXT
    hpTitle.Font = Enum.Font.GothamBold
    hpTitle.TextSize = scaledSize(16)
    hpTitle.Parent = hotkeyPopup

    local hpTarget = Instance.new("TextLabel")
    hpTarget.Size = UDim2.new(1, -20, 0, scaledSize(20))
    hpTarget.Position = UDim2.new(0, 10, 0, scaledSize(42))
    hpTarget.BackgroundTransparency = 1
    hpTarget.Text = "Target: วิ่งไว"
    hpTarget.TextColor3 = COLOR_TEXT_DIM
    hpTarget.Font = Enum.Font.Gotham
    hpTarget.TextSize = scaledSize(12)
    hpTarget.Parent = hotkeyPopup

    local hpKeyBox = Instance.new("TextBox")
    hpKeyBox.Size = UDim2.new(0.6, 0, 0, scaledSize(30))
    hpKeyBox.Position = UDim2.new(0.35, 0, 0, scaledSize(68))
    hpKeyBox.BackgroundColor3 = COLOR_BG_LIGHT
    hpKeyBox.BackgroundTransparency = 0.4
    hpKeyBox.Text = ""
    hpKeyBox.PlaceholderText = "Q / + / - / 1-9"
    hpKeyBox.TextColor3 = COLOR_ACCENT
    hpKeyBox.Font = Enum.Font.GothamBold
    hpKeyBox.TextSize = scaledSize(13)
    hpKeyBox.Parent = hotkeyPopup
    Instance.new("UICorner", hpKeyBox).CornerRadius = UDim.new(0, 8)

    local hpSaveBtn = Instance.new("TextButton")
    hpSaveBtn.Size = UDim2.new(0.42, 0, 0, scaledSize(30))
    hpSaveBtn.Position = UDim2.new(0.05, 0, 1, -scaledSize(40))
    hpSaveBtn.BackgroundColor3 = COLOR_ACTIVE_BG
    hpSaveBtn.Text = "บันทึก"
    hpSaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    hpSaveBtn.Font = Enum.Font.GothamBold
    hpSaveBtn.TextSize = scaledSize(13)
    hpSaveBtn.Parent = hotkeyPopup
    Instance.new("UICorner", hpSaveBtn).CornerRadius = UDim.new(0, 8)

    local hpCloseBtn = Instance.new("TextButton")
    hpCloseBtn.Size = UDim2.new(0.42, 0, 0, scaledSize(30))
    hpCloseBtn.Position = UDim2.new(0.53, 0, 1, -scaledSize(40))
    hpCloseBtn.BackgroundColor3 = COLOR_BG_LIGHT
    hpCloseBtn.Text = "ปิด"
    hpCloseBtn.TextColor3 = COLOR_TEXT_DIM
    hpCloseBtn.Font = Enum.Font.GothamMedium
    hpCloseBtn.TextSize = scaledSize(13)
    hpCloseBtn.Parent = hotkeyPopup
    Instance.new("UICorner", hpCloseBtn).CornerRadius = UDim.new(0, 8)

    local function openHotkeyPopup(target)
        S.hotkeyEditTarget = target
        local data = S.hotkeys[target]
        hpTarget.Text = "Target: " .. (target == "speed" and "วิ่งไว" or "บินได้")
        hpKeyBox.Text = data.key and data.key.Name or ""
        hotkeyPopup.Visible = true
    end

    if isPC then
        hotkeySpdBtn.MouseButton1Click:Connect(function() openHotkeyPopup("speed") end)
        hotkeyFlyBtn.MouseButton1Click:Connect(function() openHotkeyPopup("fly") end)
        hotkeyClearBtn.MouseButton1Click:Connect(function()
            S.hotkeys.speed.key = nil
            S.hotkeys.fly.key = nil
            hotkeyPopup.Visible = false
        end)
    end

    local numpadMap = {
        ["+"] = "KeypadPlus", ["-"] = "KeypadMinus",
        ["*"] = "KeypadMultiply", ["/"] = "KeypadDivide",
        ["."] = "KeypadPeriod",
        ["0"] = "KeypadZero", ["1"] = "KeypadOne", ["2"] = "KeypadTwo",
        ["3"] = "KeypadThree", ["4"] = "KeypadFour", ["5"] = "KeypadFive",
        ["6"] = "KeypadSix", ["7"] = "KeypadSeven", ["8"] = "KeypadEight",
        ["9"] = "KeypadNine"
    }

    hpSaveBtn.MouseButton1Click:Connect(function()
        if not S.hotkeyEditTarget then return end
        local raw = string.gsub(hpKeyBox.Text, "%s", "")
        if raw == "" then
            S.hotkeys[S.hotkeyEditTarget].key = nil
            hotkeyPopup.Visible = false
            return
        end
        local text = string.upper(raw)
        local keyCode = nil
        if numpadMap[raw] then
            keyCode = Enum.KeyCode[numpadMap[raw]]
        elseif numpadMap[text] then
            keyCode = Enum.KeyCode[numpadMap[text]]
        else
            local ok, kc = pcall(function() return Enum.KeyCode[text] end)
            if ok then keyCode = kc end
        end
        if keyCode then
            S.hotkeys[S.hotkeyEditTarget].key = keyCode
            hotkeyPopup.Visible = false
        else
            hpTarget.Text = "ปุ่มไม่ถูกต้อง!"
            task.wait(2)
            hpTarget.Text = "Target: " .. (S.hotkeyEditTarget == "speed" and "วิ่งไว" or "บินได้")
        end
    end)

    hpCloseBtn.MouseButton1Click:Connect(function() hotkeyPopup.Visible = false end)

    espBtn.MouseButton1Click:Connect(function()
        if not canToggle() then return end
        S.espEnabled = not S.espEnabled
        espBtn.Text = S.espEnabled and "มองทะลุ: เปิด" or "มองทะลุ: ปิด"
        espBtn.BackgroundColor3 = S.espEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
        S.savedState.esp = S.espEnabled
        refreshESP()
    end)

    teamBtn.MouseButton1Click:Connect(function()
        S.teamCheckEnabled = not S.teamCheckEnabled
        S.savedState.teamCheck = S.teamCheckEnabled
        teamBtn.Text = S.teamCheckEnabled and "เช็คทีม: เปิด" or "เช็คทีม: ปิด"
        teamBtn.BackgroundColor3 = S.teamCheckEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
        if S.espEnabled then refreshESP() end
        if S.nameEnabled then refreshNames() end
    end)

    distBox.FocusLost:Connect(function()
        local v = tonumber(distBox.Text)
        if v and v > 0 then
            S.NAME_MAX_DIST = v
        else
            distBox.Text = "800"
            S.NAME_MAX_DIST = 800
        end
        S.savedState.nameDist = S.NAME_MAX_DIST
        for _, data in ipairs(nameData) do
            if data.gui and data.gui.Parent then
                data.gui.MaxDistance = S.NAME_MAX_DIST
            end
        end
    end)

    nameBtn.MouseButton1Click:Connect(function()
        if not canToggle() then return end
        S.nameEnabled = not S.nameEnabled
        nameBtn.Text = S.nameEnabled and "เห็นชื่อ: เปิด" or "เห็นชื่อ: ปิด"
        nameBtn.BackgroundColor3 = S.nameEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
        S.savedState.name = S.nameEnabled
        refreshNames()
    end)

    noclipBtn.MouseButton1Click:Connect(function()
        if S.noclipBusy then return end
        S.noclipBusy = true
        S.noclipEnabled = not S.noclipEnabled
        noclipBtn.Text = S.noclipEnabled and "Noclip: เปิด" or "Noclip: ปิด"
        noclipBtn.BackgroundColor3 = S.noclipEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
        S.savedState.noclip = S.noclipEnabled
        if S.noclipEnabled then enableNoclip() else disableNoclip() end
        S.noclipBusy = false
    end)

    fpsBoostBtn.MouseButton1Click:Connect(function()
        S.fpsBoostEnabled = not S.fpsBoostEnabled
        fpsBoostBtn.Text = S.fpsBoostEnabled and "FPS Boost: เปิด" or "FPS Boost: ปิด"
        fpsBoostBtn.BackgroundColor3 = S.fpsBoostEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
        S.savedState.fpsBoost = S.fpsBoostEnabled
        if S.fpsBoostEnabled then enableFPSBoost() else disableFPSBoost() end
    end)

    toggleBtn.MouseButton1Click:Connect(function()
        S.isOpen = not S.isOpen
        main.Visible = S.isOpen
    end)

    closeBtn.MouseButton1Click:Connect(function()
        main.Visible = false
        S.isOpen = false
    end)

    -- Name display loop
    RunService.RenderStepped:Connect(function()
        if not S.scriptAlive or not S.nameEnabled then return end
        local cam = workspace.CurrentCamera
        local camPos = cam.CFrame.Position
        local camLook = cam.CFrame.LookVector
        local vp = cam.ViewportSize
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
            if dist > S.NAME_MAX_DIST then
                bg.Enabled = false
            else
                local dot = camLook:Dot(delta.Unit)
                if dot < 0.15 then
                    bg.Enabled = false
                else
                    local sp, onScreen = cam:WorldToViewportPoint(headPos)
                    bg.Enabled = onScreen and sp.Z > 0 and sp.X > -50 and sp.X < vp.X + 50 and sp.Y > -50 and sp.Y < vp.Y + 50
                end
            end
        end
    end)

    -- Spectate
    local function stopSpectate()
        S.spectateEnabled = false
        S.spectateTarget = nil
        local cam = workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            if player.Character then
                local myHum = player.Character:FindFirstChildOfClass("Humanoid")
                if myHum then cam.CameraSubject = myHum end
            end
        end
    end

    local function spectatePlayer(targetPlayer)
        if not targetPlayer then return end
        local targetChar = targetPlayer.Character
        if not targetChar then
            local ok = pcall(function() targetChar = targetPlayer.CharacterAdded:Wait() end)
            if not ok or not targetChar then return end
        end
        S.spectateEnabled = true
        S.spectateTarget = targetPlayer
        S.spectateYaw = 0
        S.spectatePitch = -10
        S.spectateDist = 12
    end

    local function teleportToPlayer(targetPlayer)
        if not targetPlayer then return end
        local targetChar = targetPlayer.Character
        if not targetChar then
            local ok = pcall(function() targetChar = targetPlayer.CharacterAdded:Wait() end)
            if not ok or not targetChar then return end
        end
        local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
        if not targetRoot then return end
        if not rootPart or not rootPart.Parent then return end
        local offset = targetRoot.CFrame.LookVector * -5
        local newPos = targetRoot.Position + offset + Vector3.new(0, 2, 0)
        rootPart.CFrame = CFrame.new(newPos, targetRoot.Position)
    end

    RunService:BindToRenderStep("BoomSpectate", Enum.RenderPriority.Camera.Value + 1, function(dt)
        if not S.scriptAlive then return end
        if not S.spectateEnabled or not S.spectateTarget then return end
        local targetChar = S.spectateTarget.Character
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
        local lookAt = targetHead.Position
        cam.CFrame = CFrame.new(camPos, lookAt)
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if not S.spectateEnabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            S.mouseDown = true
            S.lastMouseX = input.Position.X
            S.lastMouseY = input.Position.Y
        end
        if input.UserInputType == Enum.UserInputType.Touch then
            S.mouseDown = true
            S.lastMouseX = input.Position.X
            S.lastMouseY = input.Position.Y
        end
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            S.spectateDist = clamp(S.spectateDist - input.Position.Z * 2, 4, 50)
        end
    end)

    UserInputService.InputChanged:Connect(function(input, gp)
        if not S.spectateEnabled then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement and S.mouseDown then
            local dx = input.Position.X - S.lastMouseX
            local dy = input.Position.Y - S.lastMouseY
            S.lastMouseX = input.Position.X
            S.lastMouseY = input.Position.Y
            S.spectateYaw = S.spectateYaw + dx * 0.3
            S.spectatePitch = clamp(S.spectatePitch - dy * 0.3, -80, 80)
        end
        if input.UserInputType == Enum.UserInputType.Touch and S.mouseDown then
            local dx = input.Position.X - S.lastMouseX
            local dy = input.Position.Y - S.lastMouseY
            S.lastMouseX = input.Position.X
            S.lastMouseY = input.Position.Y
            S.spectateYaw = S.spectateYaw + dx * 0.5
            S.spectatePitch = clamp(S.spectatePitch - dy * 0.5, -80, 80)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
            S.mouseDown = false
        end
    end)

    -- Player List
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
                row.Size = UDim2.new(1, -scaledSize(8), 0, scaledSize(44))
                row.BackgroundColor3 = COLOR_BG_LIGHT
                row.BackgroundTransparency = 0.5
                row.BorderSizePixel = 0
                row.Parent = scroll
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
                local avatar = Instance.new("ImageLabel")
                avatar.Size = UDim2.new(0, scaledSize(30), 0, scaledSize(30))
                avatar.Position = UDim2.new(0.02, 0, 0.5, -scaledSize(15))
                avatar.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
                avatar.BorderSizePixel = 0
                avatar.Image = ""
                avatar.Parent = row
                Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)
                task.spawn(function()
                    local ok, thumb = pcall(function()
                        return Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                    end)
                    if ok and thumb and avatar and avatar.Parent then
                        avatar.Image = thumb
                    end
                end)
                local nameLbl = Instance.new("TextLabel")
                nameLbl.Size = UDim2.new(0.32, 0, 0.5, 0)
                nameLbl.Position = UDim2.new(0.14, 0, 0.05, 0)
                nameLbl.BackgroundTransparency = 1
                nameLbl.Text = p.DisplayName
                nameLbl.TextColor3 = COLOR_SILVER
                nameLbl.Font = Enum.Font.GothamMedium
                nameLbl.TextSize = scaledSize(11)
                nameLbl.TextXAlignment = Enum.TextXAlignment.Left
                nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
                nameLbl.Parent = row
                local userLbl = Instance.new("TextLabel")
                userLbl.Size = UDim2.new(0.32, 0, 0.4, 0)
                userLbl.Position = UDim2.new(0.14, 0, 0.52, 0)
                userLbl.BackgroundTransparency = 1
                userLbl.Text = "@" .. p.Name
                userLbl.TextColor3 = COLOR_SILVER_DIM
                userLbl.Font = Enum.Font.Gotham
                userLbl.TextSize = scaledSize(9)
                userLbl.TextXAlignment = Enum.TextXAlignment.Left
                userLbl.TextTruncate = Enum.TextTruncate.AtEnd
                userLbl.Parent = row
                local distLbl2 = Instance.new("TextLabel")
                distLbl2.Size = UDim2.new(0.10, 0, 1, 0)
                distLbl2.Position = UDim2.new(0.46, 0, 0, 0)
                distLbl2.BackgroundTransparency = 1
                distLbl2.Text = "-"
                distLbl2.TextColor3 = COLOR_ACCENT
                distLbl2.Font = Enum.Font.GothamBold
                distLbl2.TextSize = scaledSize(9)
                distLbl2.Parent = row

                local tpBtn = Instance.new("TextButton")
                tpBtn.Size = UDim2.new(0.10, 0, 0, scaledSize(28))
                tpBtn.Position = UDim2.new(0.57, 0, 0.5, -scaledSize(14))
                tpBtn.BackgroundColor3 = Color3.fromRGB(100, 70, 0)
                tpBtn.BackgroundTransparency = 0.3
                tpBtn.Text = "TP"
                tpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                tpBtn.Font = Enum.Font.GothamBold
                tpBtn.TextSize = scaledSize(11)
                tpBtn.Parent = row
                Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 8)
                tpBtn.MouseButton1Click:Connect(function() teleportToPlayer(p) end)

                local specBtn = Instance.new("TextButton")
                specBtn.Size = UDim2.new(0.13, 0, 0, scaledSize(28))
                specBtn.Position = UDim2.new(0.68, 0, 0.5, -scaledSize(14))
                specBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 0)
                specBtn.BackgroundTransparency = 0.3
                specBtn.Text = "ส่อง"
                specBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                specBtn.Font = Enum.Font.GothamBold
                specBtn.TextSize = scaledSize(11)
                specBtn.Parent = row
                Instance.new("UICorner", specBtn).CornerRadius = UDim.new(0, 8)
                specBtn.MouseButton1Click:Connect(function() spectatePlayer(p) end)

                local stickRowBtn = Instance.new("TextButton")
                stickRowBtn.Size = UDim2.new(0.17, 0, 0, scaledSize(28))
                stickRowBtn.Position = UDim2.new(0.82, 0, 0.5, -scaledSize(14))
                local isSticking = (S.stickEnabled and S.stickTarget == p)
                stickRowBtn.BackgroundColor3 = isSticking
                    and Color3.fromRGB(60, 150, 90)
                    or Color3.fromRGB(70, 100, 180)
                stickRowBtn.BackgroundTransparency = 0.3
                stickRowBtn.Text = isSticking and "หยุด" or "เกาะ"
                stickRowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                stickRowBtn.Font = Enum.Font.GothamBold
                stickRowBtn.TextSize = scaledSize(11)
                stickRowBtn.Parent = row
                Instance.new("UICorner", stickRowBtn).CornerRadius = UDim.new(0, 8)
                stickRowBtn.MouseButton1Click:Connect(function()
                    if S.stickEnabled and S.stickTarget == p then
                        stopStick()
                    else
                        if S.stickEnabled then stopStick() end
                        startStick(p)
                    end
                    refreshPlayerList()
                end)

                table.insert(playerRows, {row = row, player = p, distLbl = distLbl2})
            end
        end
    end

    openListBtn.MouseButton1Click:Connect(function()
        checkMenu.Visible = not checkMenu.Visible
        if checkMenu.Visible then
            task.wait(0.05)
            refreshPlayerList()
        end
    end)

    cCloseBtn.MouseButton1Click:Connect(function()
        checkMenu.Visible = false
    end)

    stopSpecBtn.MouseButton1Click:Connect(stopSpectate)

    -- Loops
    task.spawn(function()
        while S.scriptAlive do
            task.wait(2)
            if checkMenu.Visible then refreshPlayerList() end
        end
    end)

    task.spawn(function()
        while S.scriptAlive do
            task.wait(0.5)
            if checkMenu.Visible then
                for _, data in pairs(playerRows) do
                    local p = data.player
                    local dLbl = data.distLbl
                    if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and rootPart and rootPart.Parent then
                        local d = (p.Character.HumanoidRootPart.Position - rootPart.Position).Magnitude
                        dLbl.Text = math.floor(d) .. "m"
                    else
                        dLbl.Text = "-"
                    end
                end
            end
        end
    end)

    task.spawn(function()
        while S.scriptAlive do
            task.wait(0.3)
            if S.stickEnabled then
                UI.refreshStickStatus()
            end
        end
    end)

    task.spawn(function()
        while S.scriptAlive do
            task.wait(0.5)
            if S.spectateEnabled and S.spectateTarget then
                if not S.spectateTarget.Parent or not S.spectateTarget.Character or not S.spectateTarget.Character:FindFirstChild("Head") then
                    stopSpectate()
                end
            end
        end
    end)

    task.spawn(function()
        while S.scriptAlive do
            task.wait(1)
            if S.espEnabled then
                for _, p in pairs(Players:GetPlayers()) do
                    if p ~= player and p.Character and p.Character.Parent then
                        if not isSameTeam(p) then
                            local found = false
                            for _, obj in ipairs(espObjects) do
                                if obj.player == p and obj.hl and obj.hl.Parent then
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                applyESP(p.Character, p)
                            end
                        end
                    end
                end
            end
        end
    end)

    Players.PlayerAdded:Connect(function(p)
        task.wait(0.5)
        if checkMenu.Visible then refreshPlayerList() end
        p.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            if not S.scriptAlive then return end
            if S.espEnabled then applyESP(c, p) end
            if S.nameEnabled then applyName(c, p.Name, p) end
        end)
    end)

    Players.PlayerRemoving:Connect(function(p)
        task.wait(0.3)
        if S.spectateTarget == p then stopSpectate() end
        if S.stickTarget == p then
            stopStick()
        end
        for i = #espObjects, 1, -1 do
            if espObjects[i].player == p then
                if espObjects[i].hl and espObjects[i].hl.Parent then
                    espObjects[i].hl:Destroy()
                end
                table.remove(espObjects, i)
            end
        end
        if checkMenu.Visible then refreshPlayerList() end
    end)

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            p.CharacterAdded:Connect(function(c)
                task.wait(0.5)
                if not S.scriptAlive then return end
                if S.espEnabled then applyESP(c, p) end
                if S.nameEnabled then applyName(c, p.Name, p) end
            end)
        end
    end

    -- Kill
    local function killScript()
        S.scriptAlive = false
        stopSpeedLoop()
        if S.flyConnection then S.flyConnection:Disconnect(); S.flyConnection = nil end
        if S.stickConnection then S.stickConnection:Disconnect(); S.stickConnection = nil end
        pcall(function() ContextActionService:UnbindAction(S.STICK_ACTION) end)
        S.speedEnabled = false
        S.flyEnabled = false
        S.espEnabled = false
        S.nameEnabled = false
        S.noclipEnabled = false
        S.stickEnabled = false
        if S.fpsBoostEnabled then
            S.fpsBoostEnabled = false
            disableFPSBoost()
        end
        stopFly()
        stopStick()
        stopSpectate()
        disableNoclip()
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

    -- Respawn
    player.CharacterAdded:Connect(function(nc)
        stopSpeedLoop()

        character = nc
        humanoid = character:WaitForChild("Humanoid")
        rootPart = character:WaitForChild("HumanoidRootPart")
        S.runAnimator = humanoid:FindFirstChildOfClass("Animator")
        if not S.runAnimator then
            S.runAnimator = Instance.new("Animator")
            S.runAnimator.Parent = humanoid
        end
        S.runAnimTrack = nil
        if S.bodyVel then S.bodyVel:Destroy(); S.bodyVel = nil end
        if S.bodyGyro then S.bodyGyro:Destroy(); S.bodyGyro = nil end
        if S.flyConnection then S.flyConnection:Disconnect(); S.flyConnection = nil end
        task.wait(1)
        if not S.scriptAlive then return end
        if S.savedState.speed then
            S.speedEnabled = true
            S.runSpeed = S.savedState.speedVal
            spdBox.Text = tostring(S.runSpeed)
            spdBtn.Text = "วิ่งไว: เปิด"
            spdBtn.BackgroundColor3 = COLOR_ACTIVE_BG
            humanoid.WalkSpeed = S.runSpeed
            startSpeedLoop()
        end
        if S.savedState.fly then
            S.flyEnabled = true
            S.flySpeed = S.savedState.flyVal
            flyBox.Text = tostring(S.flySpeed)
            flyBtn.Text = "บินได้: เปิด"
            flyBtn.BackgroundColor3 = COLOR_ACTIVE_BG
            startFly()
        end
        if S.savedState.esp then
            S.espEnabled = true
            S.espColorIndex = S.savedState.espColorIdx or 1
            S.teamCheckEnabled = S.savedState.teamCheck or false
            espBtn.Text = "มองทะลุ: เปิด"
            espBtn.BackgroundColor3 = COLOR_ACTIVE_BG
            teamBtn.Text = S.teamCheckEnabled and "เช็คทีม: เปิด" or "เช็คทีม: ปิด"
            teamBtn.BackgroundColor3 = S.teamCheckEnabled and COLOR_ACTIVE_BG or COLOR_BG_LIGHT
            refreshESP()
        end
        if S.savedState.name then
            S.nameEnabled = true
            S.NAME_MAX_DIST = S.savedState.nameDist
            distBox.Text = tostring(S.NAME_MAX_DIST)
            nameBtn.Text = "เห็นชื่อ: เปิด"
            nameBtn.BackgroundColor3 = COLOR_ACTIVE_BG
            refreshNames()
        end
        if S.savedState.noclip then
            S.noclipEnabled = true
            noclipBtn.Text = "Noclip: เปิด"
            noclipBtn.BackgroundColor3 = COLOR_ACTIVE_BG
            enableNoclip()
        end
        if S.savedState.fpsBoost then
            S.fpsBoostEnabled = true
            fpsBoostBtn.Text = "FPS Boost: เปิด"
            fpsBoostBtn.BackgroundColor3 = COLOR_ACTIVE_BG
            enableFPSBoost()
        end
        -- กู้ระยะเกาะ
        if S.savedState.stickDist and UI.setStickDistance then
            UI.setStickDistance(S.savedState.stickDist)
        end
        for k in pairs(S.dirs) do S.dirs[k] = false end
    end)

    print("[Boom V8.5] Loaded OK")
end
