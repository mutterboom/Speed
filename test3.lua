-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Ghost Stick V7 | Multi-Device (PC/Mobile/Tablet)              ║
-- ║  - Auto-detect: PC / iOS / Android / Tablet / Console          ║
-- ║  - Auto UI Scale ตามขนาดจอ                                    ║
-- ║  - Touch-friendly (ปุ่มใหญ่ขึ้นบน Mobile)                      ║
-- ║  - ซ่อน Hotkey บน Mobile                                       ║
-- ║  - Auto-Combo (M1 + Skill + Mix)                               ║
-- ║  - TP Behind รวมกับ Ghost                                      ║
-- ║  - Anti-Detect + Dynamic Scroll                                ║
-- ╚═══════════════════════════════════════════════════════════════╝
do
    local P = game:GetService("Players")
    local R = game:GetService("RunService")
    local U = game:GetService("UserInputService")
    local C = game:GetService("ContextActionService")
    local VIM = game:GetService("VirtualInputManager")
    local GuiService = game:GetService("GuiService")
    local LP = P.LocalPlayer
    local cam = workspace.CurrentCamera

    -- ═══════════════════════════════════════════
    -- DEVICE DETECTION (ละเอียด)
    -- ═══════════════════════════════════════════
    local uis = U

    -- ตรวจ OS
    local isTouch = uis.TouchEnabled
    local isKeyboard = uis.KeyboardEnabled
    local isMouse = uis.MouseEnabled
    local isGamepad = uis.GamepadEnabled

    -- ตรวจ Platform
    local platform = "Unknown"
    if uis:IsTenFootInterface() then
        platform = "Console"
    elseif isTouch and not isKeyboard then
        -- Mobile: iOS หรือ Android
        local ok, result = pcall(function()
            return game:GetService("RunService"):IsStudio() and "Studio" or 
                   (game:GetService("GuiService"):IsTenFootInterface() and "Console" or 
                   (isTouch and "Mobile" or "PC"))
        end)
        platform = ok and result or "Mobile"
    elseif isKeyboard and isMouse then
        platform = "PC"
    elseif isGamepad and not isKeyboard then
        platform = "Console"
    end

    -- ตรวจขนาดจอ
    local vp = cam.ViewportSize
    local screenX = vp.X
    local screenY = vp.Y
    local minSide = math.min(screenX, screenY)

    -- ตรวจ OS แยก iOS/Android (จาก UserInputService)
    local isIOS = false
    local isAndroid = false
    if isTouch and not isKeyboard then
        -- ตรวจจาก TouchEnabled + TouchPressure (iOS ปกติไม่มี)
        local hasPressure = uis.TouchEnabled and uis:GetDeviceRotation ~= nil
        -- ตรวจจากขนาด - iPad/iOS มักจะมีอัตราส่วนเฉพาะ
        local aspectRatio = screenX / screenY
        -- iOS มักเป็น 4:3 หรือ 16:9 (iPad/iPhone)
        -- Android หลากหลาย
        -- ใช้ได้แค่ heuristic
        isIOS = (aspectRatio > 0.7 and aspectRatio < 0.8) or (aspectRatio > 1.3 and aspectRatio < 1.4)
        isAndroid = not isIOS
    end

    -- ═══════════════════════════════════════════
    -- UI SCALE TABLE (ปรับตามอุปกรณ์)
    -- ═══════════════════════════════════════════
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
        -- แยกย่อยตามขนาดจอ
        if minSide < 350 then
            deviceType = "Mobile-XS"      -- iPhone SE, จอเล็กมาก
            uiScale = 0.55
        elseif minSide < 400 then
            deviceType = "Mobile-Small"   -- iPhone 8, Android เล็ก
            uiScale = 0.65
        elseif minSide < 480 then
            deviceType = "Mobile-Mid"     -- iPhone 12/13, Android กลาง
            uiScale = 0.78
        elseif minSide < 600 then
            deviceType = "Mobile-Large"   -- iPhone Pro Max, Android ใหญ่
            uiScale = 0.88
        elseif minSide < 800 then
            deviceType = "Tablet-Small"   -- iPad Mini, Android Tablet
            uiScale = 0.95
        else
            deviceType = "Tablet-Large"   -- iPad Pro
            uiScale = 1.05
        end
        if isIOS then
            deviceType = deviceType .. " (iOS)"
        elseif isAndroid then
            deviceType = deviceType .. " (Android)"
        end
    else
        -- PC
        deviceType = "PC"
        touchMode = false
        showHotkey = true
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

    -- ✅ ปรับ scale ตาม guiInset (safe zone)
    local topInset, bottomInset = GuiService:GetGuiInset()
    local safeAreaReduce = (topInset + bottomInset) / screenY

    -- ✅ Function สำหรับ scale px
    local function S(px) return math.floor(px * uiScale) end

    print("[Ghost V7] Device:", deviceType)
    print("[Ghost V7] Platform:", platform, "| Scale:", uiScale)
    print("[Ghost V7] Screen:", screenX, "x", screenY, "| Safe:", string.format("%.2f", safeAreaReduce))

    pcall(function()
        for _, g in ipairs(LP:WaitForChild("PlayerGui"):GetChildren()) do
            if g.Name == "GhostStickUI" then g:Destroy() end
        end
    end)

    local G = {
        enabled=false, target=nil, stickConn=nil, alive=true,
        distance=3, backOffset=2, hideLocal=true,
        savedTrans={}, charListener=nil,
        specYaw=0, specPitch=-10, specDist=12,
        specDown=false, specMX=0, specMY=0,
        specBound=false, specSmooth=0.25, specActive=true,
        hotkey=nil, hotkeyWait=false, lastHK=0,
        HK_ACTION="GhostStick_HK_V7MD", collapsed=false, presetIdx=0,
        posMode = "stick",

        antiDetect = true,
        jitterX = 0, jitterZ = 0,
        lastJitterUpdate = 0,
        jitterInterval = 0.15,
        jitterAmount = 0.3,
        patternSpoof = true,

        autoCombo = false,
        comboDelay = 0.35,
        comboJitter = 0.15,
        comboAttackType = "M1",
        comboLastAtk = 0,
        comboActiveCount = 0,
        comboMaxHits = 3,
        comboRest = 0.8,
        comboBurst = false,

        tpBehind = false,
        tpOffset = 3,
        tpCooldown = 0.3,
        tpLast = 0,
    }
    local UI = {}
    local Ghost = {}

    local function clamp(v,a,b) if v<a then return a end if v>b then return b end return v end
    local function rand(a,b) return a + math.random() * (b-a) end
    local function getHRP(p)
        if not p or not p.Parent then return nil end
        local c = p.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function fromAim()
        local m = LP:GetMouse()
        if m and m.Target then
            local mdl = m.Target:FindFirstAncestorOfClass("Model")
            while mdl do
                local pl = P:GetPlayerFromCharacter(mdl)
                if pl and pl ~= LP then return pl end
                mdl = mdl:FindFirstAncestorOfClass("Model")
            end
        end
        return nil
    end
    local function inSight()
        local cp = cam.CFrame.Position
        local cl = cam.CFrame.LookVector
        local best, bs = nil, -1
        for _, p in ipairs(P:GetPlayers()) do
            if p ~= LP then
                local h = getHRP(p)
                if h then
                    local toT = h.Position - cp
                    local d = toT.Magnitude
                    if d > 0 and cl:Dot(toT.Unit) > 0.7 and d < 200 then
                        local sc = cl:Dot(toT.Unit)/d
                        if sc > bs then bs = sc; best = p end
                    end
                end
            end
        end
        return best
    end
    local function nearest()
        local m = getHRP(LP); if not m then return nil end
        local n, md = nil, math.huge
        for _, p in ipairs(P:GetPlayers()) do
            if p ~= LP then
                local h = getHRP(p)
                if h then
                    local d = (h.Position - m.Position).Magnitude
                    if d < md then md = d; n = p end
                end
            end
        end
        return n
    end

    local function hideChar()
        local c = LP.Character; if not c then return end
        G.savedTrans = {}
        for _, part in ipairs(c:GetDescendants()) do
            if part:IsA("BasePart") then
                table.insert(G.savedTrans, {p=part, oL=part.LocalTransparencyModifier})
                part.LocalTransparencyModifier = 1
            elseif part:IsA("Decal") or part:IsA("Texture") then
                table.insert(G.savedTrans, {p=part, oT=part.Transparency})
                part.Transparency = 1
            end
        end
        if G.charListener then G.charListener:Disconnect() end
        G.charListener = c.DescendantAdded:Connect(function(d)
            if G.enabled and G.hideLocal then
                if d:IsA("BasePart") then d.LocalTransparencyModifier = 1
                elseif d:IsA("Decal") or d:IsA("Texture") then d.Transparency = 1 end
            end
        end)
    end
    local function restoreChar()
        for _, d in ipairs(G.savedTrans) do
            if d.p and d.p.Parent then
                pcall(function()
                    if d.oL ~= nil then d.p.LocalTransparencyModifier = d.oL end
                    if d.oT ~= nil then d.p.Transparency = d.oT end
                end)
            end
        end
        G.savedTrans = {}
        if G.charListener then G.charListener:Disconnect(); G.charListener=nil end
    end

    local function updateJitter()
        if not G.antiDetect then
            G.jitterX = 0; G.jitterZ = 0
            return
        end
        local now = tick()
        if now - G.lastJitterUpdate < G.jitterInterval then return end
        G.lastJitterUpdate = now
        G.jitterX = rand(-G.jitterAmount, G.jitterAmount)
        G.jitterZ = rand(-G.jitterAmount, G.jitterAmount)
    end

    local function stickLoop()
        if not G.enabled or not G.alive then return end
        local m = getHRP(LP); if not m then return end
        if not G.target or not getHRP(G.target) then
            G.target = nearest()
            if not G.target then return end
            if Ghost.refreshStatus then Ghost.refreshStatus() end
        end
        local t = getHRP(G.target); if not t then return end
        local lk = t.CFrame.LookVector

        updateJitter()

        local pos
        if G.posMode == "deep" then
            pos = t.Position + Vector3.new(0, -2.5, 0) - lk * 1.5
        elseif G.posMode == "behind" then
            pos = t.Position + Vector3.new(0, -G.distance, 0) - lk * (G.backOffset + 10)
        else
            pos = t.Position + Vector3.new(0, -G.distance, 0) - lk * G.backOffset
        end

        pos = pos + Vector3.new(G.jitterX, 0, G.jitterZ)
        m.CFrame = CFrame.new(pos, pos + lk)
        m.AssemblyLinearVelocity = Vector3.zero
        m.AssemblyAngularVelocity = Vector3.zero
    end

    -- ═══ Auto-Combo ═══
    local function simulateClick()
        pcall(function()
            local x, y = cam.ViewportSize.X/2, cam.ViewportSize.Y/2
            VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
            task.wait(0.03)
            VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
        end)
    end

    local function simulateKeyPress(key)
        pcall(function()
            VIM:SendKeyEvent(true, key, false, game)
            task.wait(0.03)
            VIM:SendKeyEvent(false, key, false, game)
        end)
    end

    task.spawn(function()
        local hitCount = 0
        while G.alive do
            task.wait(0.05)
            if not G.autoCombo or not G.enabled then
                hitCount = 0
                continue
            end

            local now = tick()
            local delay = G.comboDelay
            if G.patternSpoof and not G.comboBurst then
                delay = delay + rand(-G.comboJitter, G.comboJitter)
                delay = math.max(0.15, delay)
            end
            if G.comboBurst then
                delay = 0.15
            end

            if now - G.comboLastAtk >= delay then
                G.comboLastAtk = now

                if G.comboAttackType == "M1" then
                    simulateClick()
                elseif G.comboAttackType == "Skill1" then
                    simulateKeyPress(Enum.KeyCode.One)
                elseif G.comboAttackType == "Skill2" then
                    simulateKeyPress(Enum.KeyCode.Two)
                elseif G.comboAttackType == "Skill3" then
                    simulateKeyPress(Enum.KeyCode.Three)
                elseif G.comboAttackType == "Skill4" then
                    simulateKeyPress(Enum.KeyCode.Four)
                elseif G.comboAttackType == "Mix" then
                    local r = math.random(1, 3)
                    if r == 1 then simulateClick()
                    elseif r == 2 then simulateKeyPress(Enum.KeyCode.One)
                    else simulateKeyPress(Enum.KeyCode.Two) end
                end

                hitCount = hitCount + 1

                if not G.comboBurst and hitCount >= G.comboMaxHits then
                    local rest = G.comboRest
                    if G.patternSpoof then rest = rest + rand(-0.2, 0.2) end
                    task.wait(math.max(0.3, rest))
                    hitCount = 0
                end
            end
        end
    end)

    -- ═══ TP Behind (รวม Ghost) ═══
    task.spawn(function()
        while G.alive do
            task.wait(0.1)
            if G.tpBehind and G.enabled and G.target then
                local now = tick()
                if now - G.tpLast >= G.tpCooldown then
                    G.tpLast = now
                    local m = getHRP(LP)
                    local t = getHRP(G.target)
                    if m and t then
                        local lk = t.CFrame.LookVector
                        local tpPos = t.Position - lk * G.tpOffset + Vector3.new(0, 2, 0)
                        pcall(function()
                            m.CFrame = CFrame.new(tpPos, t.Position)
                        end)
                    end
                end
            end
        end
    end)

    local function specUpdate()
        if not G.enabled or not G.alive or not G.specActive or not G.target then return end
        local tc = G.target.Character; if not tc then return end
        local th = tc:FindFirstChild("Head"); if not th then return end
        cam.CameraType = Enum.CameraType.Scriptable
        local yr = math.rad(G.specYaw); local pr = math.rad(G.specPitch)
        local off = Vector3.new(
            math.sin(yr)*math.cos(pr)*G.specDist,
            -math.sin(pr)*G.specDist + 2,
            math.cos(yr)*math.cos(pr)*G.specDist)
        local tcf = CFrame.new(th.Position + off, th.Position)
        if G.specSmooth >= 1 then cam.CFrame = tcf
        else cam.CFrame = cam.CFrame:Lerp(tcf, G.specSmooth) end
        if G.specDist < 6 then
            local thr = tc:FindFirstChild("HumanoidRootPart")
            if thr then
                local ps = thr.Position + Vector3.new(0,1.5,0)
                local scf = CFrame.new(ps + off, ps)
                cam.CFrame = cam.CFrame:Lerp(scf, G.specSmooth * 0.8)
            end
        end
    end
    local function stopSpec()
        cam.CameraType = Enum.CameraType.Custom
        if LP.Character then
            local mh = LP.Character:FindFirstChildOfClass("Humanoid")
            if mh then cam.CameraSubject = mh end
        end
    end

    function Ghost.start(t)
        if G.enabled then return end
        G.target = t or fromAim() or inSight() or nearest()
        if not G.target then warn("[Ghost] ไม่พบเป้า"); return end
        G.enabled = true
        if G.hideLocal then hideChar() end
        if G.stickConn then G.stickConn:Disconnect() end
        G.stickConn = R.RenderStepped:Connect(stickLoop)
        G.specActive = true; G.specYaw = 0; G.specPitch = -10
        G.specDist = 12; G.specSmooth = 0.25; G.presetIdx = 3
        if not G.specBound then
            R:BindToRenderStep("GhostSpec", Enum.RenderPriority.Camera.Value + 1, specUpdate)
            G.specBound = true
        end
        if Ghost.refreshAll then Ghost.refreshAll() end
    end
    function Ghost.stop()
        if not G.enabled then return end
        G.enabled = false; G.target = nil
        if G.stickConn then G.stickConn:Disconnect(); G.stickConn=nil end
        if G.specBound then
            pcall(function() R:UnbindFromRenderStep("GhostSpec") end)
            G.specBound = false
        end
        stopSpec(); restoreChar()
        if Ghost.refreshAll then Ghost.refreshAll() end
    end
    function Ghost.toggle(t) if G.enabled then Ghost.stop() else Ghost.start(t) end end
    function Ghost.shutdown()
        if G.enabled then Ghost.stop() end
        pcall(function() C:UnbindAction(G.HK_ACTION) end)
        if UI.gui then UI.gui:Destroy() end
    end
    function Ghost.onHK()
        if not G.alive then return end
        local n = tick(); if n - G.lastHK < 0.15 then return end
        G.lastHK = n
        if G.enabled then Ghost.stop()
        else
            local t = fromAim() or inSight() or nearest()
            if t then Ghost.start(t) end
        end
    end
    function Ghost.rebind(k)
        pcall(function() C:UnbindAction(G.HK_ACTION) end)
        G.hotkey = k
        if k then
            pcall(function()
                C:BindAction(G.HK_ACTION, function(_, s)
                    if s == Enum.UserInputState.Begin then Ghost.onHK() end
                    return Enum.ContextActionResult.Pass
                end, false, k)
            end)
        end
        if Ghost.refreshHK then Ghost.refreshHK() end
    end

    -- ═══════════════════════════════════════════
    -- UI (Multi-Device)
    -- ═══════════════════════════════════════════
    local gui = Instance.new("ScreenGui")
    gui.Name = "GhostStickUI"; gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = false
    gui.Parent = LP:WaitForChild("PlayerGui")
    UI.gui = gui

    -- ✅ ขนาดตามอุปกรณ์
    local mW = S(320)
    local BASE_H = S(720)

    -- ✅ ตำแหน่งเริ่มต้น (ปลอดภัย)
    local startX = touchMode and (screenX - mW - S(10)) or S(340)
    local startY = S(40)

    -- ✅ ปรับให้อยู่ในหน้าจอ
    if startX < S(10) then startX = S(10) end
    if startX + mW > screenX then startX = screenX - mW - S(10) end
    if startY + BASE_H > screenY then
        BASE_H = screenY - startY - S(20)
    end

    local ROW_H       = S(36)
    local SCROLL_MIN  = S(60)
    local SCROLL_MAX  = S(200)
    local SCROLL_PAD  = S(12)

    -- ✅ ปุ่มขนาดตาม touch mode
    local BTN_H = touchMode and S(42) or S(36)
    local ITEM_H = touchMode and S(38) or S(32)
    local FONT_N = touchMode and S(13) or S(12)

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, mW, 0, BASE_H)
    main.Position = UDim2.new(0, startX, 0, startY)
    main.BackgroundColor3 = Color3.fromRGB(10,8,18)
    main.BackgroundTransparency = 0.1
    main.BorderSizePixel = 0; main.Active = true
    main.Draggable = not touchMode  -- ✅ Mobile: drag ที่ title bar
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0,12)
    UI.main = main

    local ms = Instance.new("UIStroke", main)
    ms.Color = Color3.fromRGB(150,100,255); ms.Thickness = 1.5

    -- Title bar (draggable)
    local tb = Instance.new("Frame")
    tb.Size = UDim2.new(1,0,0,S(36)); tb.BackgroundTransparency = 1
    tb.Active = true
    tb.Parent = main

    -- ✅ Title drag (สำหรับ Mobile)
    if touchMode then
        local dragging = false
        local dragStart, startPos
        tb.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = i.Position
                startPos = main.Position
            end
        end)
        tb.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
        U.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
                local d = i.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                          startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
    end

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,-S(90),0,S(34)); title.Position = UDim2.new(0,S(10),0,S(1))
    title.BackgroundTransparency = 1; title.Text = "👻 GHOST V7 | " .. platform
    title.TextColor3 = Color3.fromRGB(200,170,255)
    title.Font = Enum.Font.GothamBold; title.TextSize = S(14)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = tb
    UI.title = title

    local colBtn = Instance.new("TextButton")
    colBtn.Size = UDim2.new(0,S(30),0,S(28))
    colBtn.Position = UDim2.new(1,-S(72),0,S(4))
    colBtn.BackgroundColor3 = Color3.fromRGB(90,120,70)
    colBtn.BorderSizePixel = 0; colBtn.Text = "▼"
    colBtn.TextColor3 = Color3.fromRGB(255,255,255)
    colBtn.Font = Enum.Font.GothamBold; colBtn.TextSize = S(14)
    colBtn.Parent = tb
    Instance.new("UICorner", colBtn).CornerRadius = UDim.new(0,6)

    local clsBtn = Instance.new("TextButton")
    clsBtn.Size = UDim2.new(0,S(30),0,S(28))
    clsBtn.Position = UDim2.new(1,-S(36),0,S(4))
    clsBtn.BackgroundColor3 = Color3.fromRGB(160,50,50)
    clsBtn.BorderSizePixel = 0; clsBtn.Text = "✕"
    clsBtn.TextColor3 = Color3.fromRGB(255,255,255)
    clsBtn.Font = Enum.Font.GothamBold; clsBtn.TextSize = S(16)
    clsBtn.Parent = tb
    Instance.new("UICorner", clsBtn).CornerRadius = UDim.new(0,6)

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1,0,1,-S(36))
    body.Position = UDim2.new(0,0,0,S(36))
    body.BackgroundTransparency = 1
    body.Parent = main
    UI.body = body

    local y = S(6)

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1,-20,0,S(18)); statusLbl.Position = UDim2.new(0,10,0,y)
    statusLbl.BackgroundTransparency = 1; statusLbl.Text = "● ปิด"
    statusLbl.TextColor3 = Color3.fromRGB(200,200,200)
    statusLbl.Font = Enum.Font.Code; statusLbl.TextSize = FONT_N
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = body
    UI.statusLbl = statusLbl
    y = y + S(20)

    local tgtLbl = Instance.new("TextLabel")
    tgtLbl.Size = UDim2.new(1,-20,0,S(18)); tgtLbl.Position = UDim2.new(0,10,0,y)
    tgtLbl.BackgroundTransparency = 1; tgtLbl.Text = "🎯 เป้า: -"
    tgtLbl.TextColor3 = Color3.fromRGB(255,220,100)
    tgtLbl.Font = Enum.Font.Code; tgtLbl.TextSize = FONT_N
    tgtLbl.TextXAlignment = Enum.TextXAlignment.Left
    tgtLbl.Parent = body
    UI.tgtLbl = tgtLbl
    y = y + S(24)

    -- ✅ ปุ่มใหญ่ขึ้นบน Mobile
    local tglBtn = Instance.new("TextButton")
    tglBtn.Size = UDim2.new(1,-20,0,BTN_H); tglBtn.Position = UDim2.new(0,10,0,y)
    tglBtn.BackgroundColor3 = Color3.fromRGB(80,40,130)
    tglBtn.BorderSizePixel = 0; tglBtn.Text = "👻 เปิด Ghost (Aim)"
    tglBtn.TextColor3 = Color3.fromRGB(255,255,255)
    tglBtn.Font = Enum.Font.GothamBold; tglBtn.TextSize = FONT_N
    tglBtn.Parent = body
    Instance.new("UICorner", tglBtn).CornerRadius = UDim.new(0,8)
    UI.tglBtn = tglBtn
    y = y + BTN_H + S(6)

    -- ✅ Hotkey แสดงเฉพาะ PC
    local hkBtn = Instance.new("TextButton")
    hkBtn.Size = UDim2.new(1,-20,0,S(32)); hkBtn.Position = UDim2.new(0,10,0,y)
    hkBtn.BackgroundColor3 = Color3.fromRGB(90,60,60)
    hkBtn.BorderSizePixel = 0; hkBtn.Text = "⌨ ตั้งปุ่ม Hotkey"
    hkBtn.TextColor3 = Color3.fromRGB(255,255,255)
    hkBtn.Font = Enum.Font.GothamBold; hkBtn.TextSize = S(12)
    hkBtn.Visible = showHotkey
    hkBtn.Parent = body
    Instance.new("UICorner", hkBtn).CornerRadius = UDim.new(0,8)
    UI.hkBtn = hkBtn
    if showHotkey then y = y + S(38) end

    -- AUTO-COMBAT
    local combatLbl = Instance.new("TextLabel")
    combatLbl.Size = UDim2.new(1,-20,0,S(16)); combatLbl.Position = UDim2.new(0,10,0,y)
    combatLbl.BackgroundTransparency = 1; combatLbl.Text = "⚔️ AUTO-COMBAT"
    combatLbl.TextColor3 = Color3.fromRGB(255,150,100)
    combatLbl.Font = Enum.Font.GothamBold; combatLbl.TextSize = S(12)
    combatLbl.TextXAlignment = Enum.TextXAlignment.Left
    combatLbl.Parent = body
    y = y + S(20)

    local comboRow = Instance.new("Frame")
    comboRow.Size = UDim2.new(1,-20,0,BTN_H); comboRow.Position = UDim2.new(0,10,0,y)
    comboRow.BackgroundTransparency = 1; comboRow.Parent = body

    local comboBtn = Instance.new("TextButton")
    comboBtn.Size = UDim2.new(0.6,0,1,0); comboBtn.Position = UDim2.new(0,0,0,0)
    comboBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
    comboBtn.BorderSizePixel = 0; comboBtn.Text = "⚔️ Auto-Combo: ปิด"
    comboBtn.TextColor3 = Color3.fromRGB(255,200,150)
    comboBtn.Font = Enum.Font.GothamBold; comboBtn.TextSize = S(11)
    comboBtn.Parent = comboRow
    Instance.new("UICorner", comboBtn).CornerRadius = UDim.new(0,6)
    UI.comboBtn = comboBtn

    local comboTypeBtn = Instance.new("TextButton")
    comboTypeBtn.Size = UDim2.new(0.38,0,1,0); comboTypeBtn.Position = UDim2.new(0.62,0,0,0)
    comboTypeBtn.BackgroundColor3 = Color3.fromRGB(60,50,80)
    comboTypeBtn.BorderSizePixel = 0; comboTypeBtn.Text = "M1"
    comboTypeBtn.TextColor3 = Color3.fromRGB(220,200,255)
    comboTypeBtn.Font = Enum.Font.GothamBold; comboTypeBtn.TextSize = S(11)
    comboTypeBtn.Parent = comboRow
    Instance.new("UICorner", comboTypeBtn).CornerRadius = UDim.new(0,6)
    UI.comboTypeBtn = comboTypeBtn
    y = y + BTN_H + S(4)

    local burstBtn = Instance.new("TextButton")
    burstBtn.Size = UDim2.new(0.48,0,0,S(26)); burstBtn.Position = UDim2.new(0,10,0,y)
    burstBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
    burstBtn.BorderSizePixel = 0; burstBtn.Text = "💥 Burst: ปิด"
    burstBtn.TextColor3 = Color3.fromRGB(255,150,150)
    burstBtn.Font = Enum.Font.GothamBold; burstBtn.TextSize = S(10)
    burstBtn.Parent = body
    Instance.new("UICorner", burstBtn).CornerRadius = UDim.new(0,6)
    UI.burstBtn = burstBtn

    local tpBtn = Instance.new("TextButton")
    tpBtn.Size = UDim2.new(0.48,0,0,S(26)); tpBtn.Position = UDim2.new(0.52,0,0,y)
    tpBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
    tpBtn.BorderSizePixel = 0; tpBtn.Text = "🚀 TP: ปิด"
    tpBtn.TextColor3 = Color3.fromRGB(200,255,200)
    tpBtn.Font = Enum.Font.GothamBold; tpBtn.TextSize = S(10)
    tpBtn.Parent = body
    Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0,6)
    UI.tpBtn = tpBtn
    y = y + S(30)

    -- Combo delay slider
    local comboDelayLbl = Instance.new("TextLabel")
    comboDelayLbl.Size = UDim2.new(1,-20,0,S(16)); comboDelayLbl.Position = UDim2.new(0,10,0,y)
    comboDelayLbl.BackgroundTransparency = 1; comboDelayLbl.Text = "⏱ Delay: 0.35 วิ"
    comboDelayLbl.TextColor3 = Color3.fromRGB(200,200,220)
    comboDelayLbl.Font = Enum.Font.Code; comboDelayLbl.TextSize = S(11)
    comboDelayLbl.TextXAlignment = Enum.TextXAlignment.Left
    comboDelayLbl.Parent = body
    UI.comboDelayLbl = comboDelayLbl
    y = y + S(18)

    local comboDelayBg = Instance.new("Frame")
    comboDelayBg.Size = UDim2.new(1,-20,0,S(10)); comboDelayBg.Position = UDim2.new(0,10,0,y)
    comboDelayBg.BackgroundColor3 = Color3.fromRGB(40,40,55)
    comboDelayBg.BorderSizePixel = 0; comboDelayBg.Parent = body
    Instance.new("UICorner", comboDelayBg).CornerRadius = UDim.new(1,0)

    local comboDelayFill = Instance.new("Frame")
    comboDelayFill.Size = UDim2.new(0.3,0,1,0)
    comboDelayFill.BackgroundColor3 = Color3.fromRGB(255,150,100)
    comboDelayFill.BorderSizePixel = 0; comboDelayFill.Parent = comboDelayBg
    Instance.new("UICorner", comboDelayFill).CornerRadius = UDim.new(1,0)

    local comboDelayKnob = Instance.new("Frame")
    comboDelayKnob.Size = UDim2.new(0,S(18),0,S(18)); comboDelayKnob.Position = UDim2.new(0.3,-S(9),0.5,-S(9))
    comboDelayKnob.BackgroundColor3 = Color3.fromRGB(255,200,150)
    comboDelayKnob.BorderSizePixel = 0; comboDelayKnob.ZIndex = 5
    comboDelayKnob.Parent = comboDelayBg
    Instance.new("UICorner", comboDelayKnob).CornerRadius = UDim.new(1,0)

    local comboDelayHB = Instance.new("TextButton")
    comboDelayHB.Size = UDim2.new(1,0,0,S(30)); comboDelayHB.Position = UDim2.new(0,0,0.5,-S(15))
    comboDelayHB.BackgroundTransparency = 1; comboDelayHB.Text = ""; comboDelayHB.ZIndex = 10
    comboDelayHB.Parent = comboDelayBg
    y = y + S(30)

    -- ANTI-DETECT
    local antiLbl = Instance.new("TextLabel")
    antiLbl.Size = UDim2.new(1,-20,0,S(16)); antiLbl.Position = UDim2.new(0,10,0,y)
    antiLbl.BackgroundTransparency = 1; antiLbl.Text = "🛡️ ANTI-DETECT"
    antiLbl.TextColor3 = Color3.fromRGB(150,200,255)
    antiLbl.Font = Enum.Font.GothamBold; antiLbl.TextSize = S(12)
    antiLbl.TextXAlignment = Enum.TextXAlignment.Left
    antiLbl.Parent = body
    y = y + S(20)

    local antiBtn = Instance.new("TextButton")
    antiBtn.Size = UDim2.new(0.48,0,0,S(26)); antiBtn.Position = UDim2.new(0,10,0,y)
    antiBtn.BackgroundColor3 = Color3.fromRGB(50,80,60)
    antiBtn.BorderSizePixel = 0; antiBtn.Text = "🛡️ Jitter: เปิด"
    antiBtn.TextColor3 = Color3.fromRGB(200,255,200)
    antiBtn.Font = Enum.Font.GothamBold; antiBtn.TextSize = S(10)
    antiBtn.Parent = body
    Instance.new("UICorner", antiBtn).CornerRadius = UDim.new(0,6)
    UI.antiBtn = antiBtn

    local spoofBtn = Instance.new("TextButton")
    spoofBtn.Size = UDim2.new(0.48,0,0,S(26)); spoofBtn.Position = UDim2.new(0.52,0,0,y)
    spoofBtn.BackgroundColor3 = Color3.fromRGB(50,80,60)
    spoofBtn.BorderSizePixel = 0; spoofBtn.Text = "🎭 Spoof: เปิด"
    spoofBtn.TextColor3 = Color3.fromRGB(200,255,200)
    spoofBtn.Font = Enum.Font.GothamBold; spoofBtn.TextSize = S(10)
    spoofBtn.Parent = body
    Instance.new("UICorner", spoofBtn).CornerRadius = UDim.new(0,6)
    UI.spoofBtn = spoofBtn
    y = y + S(30)

    -- MODE
    local modeLbl = Instance.new("TextLabel")
    modeLbl.Size = UDim2.new(1,-20,0,S(16)); modeLbl.Position = UDim2.new(0,10,0,y)
    modeLbl.BackgroundTransparency = 1; modeLbl.Text = "🎭 โหมด"
    modeLbl.TextColor3 = Color3.fromRGB(180,200,255)
    modeLbl.Font = Enum.Font.GothamBold; modeLbl.TextSize = S(11)
    modeLbl.TextXAlignment = Enum.TextXAlignment.Left
    modeLbl.Parent = body
    y = y + S(20)

    local modeRow = Instance.new("Frame")
    modeRow.Size = UDim2.new(1,-20,0,S(30)); modeRow.Position = UDim2.new(0,10,0,y)
    modeRow.BackgroundTransparency = 1; modeRow.Parent = body

    local modeStick = Instance.new("TextButton")
    modeStick.Size = UDim2.new(0.32,0,1,0); modeStick.Position = UDim2.new(0,0,0,0)
    modeStick.BackgroundColor3 = Color3.fromRGB(80,60,140)
    modeStick.BorderSizePixel = 0; modeStick.Text = "เกาะ"
    modeStick.TextColor3 = Color3.fromRGB(255,255,255)
    modeStick.Font = Enum.Font.GothamBold; modeStick.TextSize = S(11)
    modeStick.Parent = modeRow
    Instance.new("UICorner", modeStick).CornerRadius = UDim.new(0,6)

    local modeDeep = Instance.new("TextButton")
    modeDeep.Size = UDim2.new(0.32,0,1,0); modeDeep.Position = UDim2.new(0.34,0,0,0)
    modeDeep.BackgroundColor3 = Color3.fromRGB(50,50,70)
    modeDeep.BorderSizePixel = 0; modeDeep.Text = "ลึก"
    modeDeep.TextColor3 = Color3.fromRGB(200,200,220)
    modeDeep.Font = Enum.Font.GothamBold; modeDeep.TextSize = S(11)
    modeDeep.Parent = modeRow
    Instance.new("UICorner", modeDeep).CornerRadius = UDim.new(0,6)

    local modeBehind = Instance.new("TextButton")
    modeBehind.Size = UDim2.new(0.32,0,1,0); modeBehind.Position = UDim2.new(0.68,0,0,0)
    modeBehind.BackgroundColor3 = Color3.fromRGB(50,50,70)
    modeBehind.BorderSizePixel = 0; modeBehind.Text = "หลังไกล"
    modeBehind.TextColor3 = Color3.fromRGB(200,200,220)
    modeBehind.Font = Enum.Font.GothamBold; modeBehind.TextSize = S(11)
    modeBehind.Parent = modeRow
    Instance.new("UICorner", modeBehind).CornerRadius = UDim.new(0,6)
    y = y + S(36)

    local function setMode(m)
        G.posMode = m
        local active = Color3.fromRGB(80,60,140)
        local inactive = Color3.fromRGB(50,50,70)
        modeStick.BackgroundColor3 = (m=="stick") and active or inactive
        modeDeep.BackgroundColor3 = (m=="deep") and active or inactive
        modeBehind.BackgroundColor3 = (m=="behind") and active or inactive
    end

    modeStick.MouseButton1Click:Connect(function() setMode("stick") end)
    modeDeep.MouseButton1Click:Connect(function() setMode("deep") end)
    modeBehind.MouseButton1Click:Connect(function() setMode("behind") end)

    local distLbl = Instance.new("TextLabel")
    distLbl.Size = UDim2.new(1,-20,0,S(16)); distLbl.Position = UDim2.new(0,10,0,y)
    distLbl.BackgroundTransparency = 1; distLbl.Text = "📏 ใต้เป้า: 3.0 studs"
    distLbl.TextColor3 = Color3.fromRGB(200,220,255)
    distLbl.Font = Enum.Font.Code; distLbl.TextSize = S(11)
    distLbl.TextXAlignment = Enum.TextXAlignment.Left
    distLbl.Parent = body
    UI.distLbl = distLbl
    y = y + S(18)

    local dslBg = Instance.new("Frame")
    dslBg.Size = UDim2.new(1,-20,0,S(10)); dslBg.Position = UDim2.new(0,10,0,y)
    dslBg.BackgroundColor3 = Color3.fromRGB(40,40,55)
    dslBg.BorderSizePixel = 0; dslBg.Parent = body
    Instance.new("UICorner", dslBg).CornerRadius = UDim.new(1,0)

    local dslFill = Instance.new("Frame")
    dslFill.Size = UDim2.new(0.2,0,1,0)
    dslFill.BackgroundColor3 = Color3.fromRGB(150,100,255)
    dslFill.BorderSizePixel = 0; dslFill.Parent = dslBg
    Instance.new("UICorner", dslFill).CornerRadius = UDim.new(1,0)

    local dslKnob = Instance.new("Frame")
    dslKnob.Size = UDim2.new(0,S(18),0,S(18)); dslKnob.Position = UDim2.new(0.2,-S(9),0.5,-S(9))
    dslKnob.BackgroundColor3 = Color3.fromRGB(220,200,255)
    dslKnob.BorderSizePixel = 0; dslKnob.ZIndex = 5
    dslKnob.Parent = dslBg
    Instance.new("UICorner", dslKnob).CornerRadius = UDim.new(1,0)

    local dslHB = Instance.new("TextButton")
    dslHB.Size = UDim2.new(1,0,0,S(30)); dslHB.Position = UDim2.new(0,0,0.5,-S(15))
    dslHB.BackgroundTransparency = 1; dslHB.Text = ""; dslHB.ZIndex = 10
    dslHB.Parent = dslBg
    y = y + S(24)

    -- Spectate
    local specLbl = Instance.new("TextLabel")
    specLbl.Size = UDim2.new(1,-20,0,S(16)); specLbl.Position = UDim2.new(0,10,0,y)
    specLbl.BackgroundTransparency = 1; specLbl.Text = "🎥 Spectate"
    specLbl.TextColor3 = Color3.fromRGB(180,200,255)
    specLbl.Font = Enum.Font.GothamBold; specLbl.TextSize = S(11)
    specLbl.TextXAlignment = Enum.TextXAlignment.Left
    specLbl.Parent = body
    y = y + S(20)

    local specTgl = Instance.new("TextButton")
    specTgl.Size = UDim2.new(0.48,0,0,S(28)); specTgl.Position = UDim2.new(0,10,0,y)
    specTgl.BackgroundColor3 = Color3.fromRGB(70,130,90)
    specTgl.BorderSizePixel = 0; specTgl.Text = "🎥 ปิดกล้อง"
    specTgl.TextColor3 = Color3.fromRGB(255,255,255)
    specTgl.Font = Enum.Font.GothamBold; specTgl.TextSize = S(11)
    specTgl.Parent = body
    Instance.new("UICorner", specTgl).CornerRadius = UDim.new(0,6)
    UI.specTgl = specTgl

    local smBtn = Instance.new("TextButton")
    smBtn.Size = UDim2.new(0.48,0,0,S(28)); smBtn.Position = UDim2.new(0.52,0,0,y)
    smBtn.BackgroundColor3 = Color3.fromRGB(80,90,140)
    smBtn.BorderSizePixel = 0; smBtn.Text = "✨ 0.25"
    smBtn.TextColor3 = Color3.fromRGB(255,255,255)
    smBtn.Font = Enum.Font.GothamBold; smBtn.TextSize = S(11)
    smBtn.Parent = body
    Instance.new("UICorner", smBtn).CornerRadius = UDim.new(0,6)
    UI.smBtn = smBtn
    y = y + S(34)

    -- List
    local listTitle = Instance.new("TextLabel")
    listTitle.Size = UDim2.new(1,-20,0,S(18)); listTitle.Position = UDim2.new(0,10,0,y)
    listTitle.BackgroundTransparency = 1
    listTitle.Text = "👥 เลือกเป้า"
    listTitle.TextColor3 = Color3.fromRGB(180,200,255)
    listTitle.Font = Enum.Font.GothamBold; listTitle.TextSize = S(11)
    listTitle.TextXAlignment = Enum.TextXAlignment.Left
    listTitle.Parent = body
    UI.listTitle = listTitle
    y = y + S(22)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1,-20,0,SCROLL_MIN)
    scroll.Position = UDim2.new(0,10,0,y)
    scroll.BackgroundColor3 = Color3.fromRGB(0,0,0)
    scroll.BackgroundTransparency = 0.6
    scroll.BorderSizePixel = 0; scroll.ScrollBarThickness = touchMode and 10 or 6
    scroll.ScrollBarImageColor3 = Color3.fromRGB(150,100,255)
    scroll.CanvasSize = UDim2.new(0,0,0,0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = body
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0,8)
    UI.scroll = scroll

    local slL = Instance.new("UIListLayout", scroll)
    slL.Padding = UDim.new(0,4); slL.SortOrder = Enum.SortOrder.LayoutOrder
    local slP = Instance.new("UIPadding", scroll)
    slP.PaddingTop = UDim.new(0,6); slP.PaddingLeft = UDim.new(0,6)
    slP.PaddingRight = UDim.new(0,6); slP.PaddingBottom = UDim.new(0,6)

    local refBtn = Instance.new("TextButton")
    refBtn.Size = UDim2.new(0.48,0,0,S(28))
    refBtn.Position = UDim2.new(0,10,1,-S(38))
    refBtn.BackgroundColor3 = Color3.fromRGB(70,130,90)
    refBtn.BorderSizePixel = 0; refBtn.Text = "🔄 รีเฟรช"
    refBtn.TextColor3 = Color3.fromRGB(255,255,255)
    refBtn.Font = Enum.Font.GothamBold; refBtn.TextSize = S(11)
    refBtn.Parent = body
    Instance.new("UICorner", refBtn).CornerRadius = UDim.new(0,6)

    local clrBtn = Instance.new("TextButton")
    clrBtn.Size = UDim2.new(0.48,0,0,S(28))
    clrBtn.Position = UDim2.new(0.52,0,1,-S(38))
    clrBtn.BackgroundColor3 = Color3.fromRGB(90,40,40)
    clrBtn.BorderSizePixel = 0; clrBtn.Text = "🗑 ลบ HK"
    clrBtn.TextColor3 = Color3.fromRGB(255,200,200)
    clrBtn.Font = Enum.Font.GothamBold; clrBtn.TextSize = S(11)
    clrBtn.Visible = showHotkey
    clrBtn.Parent = body
    Instance.new("UICorner", clrBtn).CornerRadius = UDim.new(0,6)
    UI.clrBtn = clrBtn

    function Ghost.resizeScroll(count)
        local contentH = count * ROW_H + SCROLL_PAD
        local newH = clamp(contentH, SCROLL_MIN, SCROLL_MAX)
        scroll.Size = UDim2.new(1, -20, 0, newH)
        local extraScroll = newH - SCROLL_MIN
        local totalH = BASE_H + extraScroll
        -- ✅ ไม่ให้เกินจอ
        if startY + totalH > screenY - S(10) then
            totalH = screenY - startY - S(20)
        end
        main.Size = UDim2.new(0, mW, 0, totalH)
    end

    local function setDist(v)
        v = clamp(v, 0, 15)
        G.distance = v
        local p = v/15
        dslFill.Size = UDim2.new(p,0,1,0)
        dslKnob.Position = UDim2.new(p,-S(9),0.5,-S(9))
        UI.distLbl.Text = string.format("📏 ใต้เป้า: %.1f studs", v)
    end

    local dD = false
    dslHB.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dD = true
            local r = clamp((i.Position.X - dslBg.AbsolutePosition.X)/dslBg.AbsoluteSize.X, 0, 1)
            setDist(math.floor(r*15*10+0.5)/10)
        end
    end)
    dslHB.InputChanged:Connect(function(i)
        if dD and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local r = clamp((i.Position.X - dslBg.AbsolutePosition.X)/dslBg.AbsoluteSize.X, 0, 1)
            setDist(math.floor(r*15*10+0.5)/10)
        end
    end)
    dslHB.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dD = false end
    end)

    local function setComboDelay(v)
        v = clamp(v, 0.15, 1.0)
        G.comboDelay = v
        local p = (v - 0.15) / 0.85
        comboDelayFill.Size = UDim2.new(p, 0, 1, 0)
        comboDelayKnob.Position = UDim2.new(p, -S(9), 0.5, -S(9))
        UI.comboDelayLbl.Text = string.format("⏱ Delay: %.2f วิ", v)
    end

    local cD = false
    comboDelayHB.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            cD = true
            local r = clamp((i.Position.X - comboDelayBg.AbsolutePosition.X)/comboDelayBg.AbsoluteSize.X, 0, 1)
            setComboDelay(0.15 + r*0.85)
        end
    end)
    comboDelayHB.InputChanged:Connect(function(i)
        if cD and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local r = clamp((i.Position.X - comboDelayBg.AbsolutePosition.X)/comboDelayBg.AbsoluteSize.X, 0, 1)
            setComboDelay(0.15 + r*0.85)
        end
    end)
    comboDelayHB.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then cD = false end
    end)

    setDist(3)
    setComboDelay(0.35)

    function Ghost.refreshStatus()
        if G.enabled and G.target then
            UI.statusLbl.Text = "● เปิด (" .. G.posMode .. ")"
            UI.statusLbl.TextColor3 = Color3.fromRGB(150,255,150)
            UI.tgtLbl.Text = "🎯 " .. G.target.Name
            UI.tgtLbl.TextColor3 = Color3.fromRGB(150,255,180)
        elseif G.enabled then
            UI.statusLbl.Text = "● หาเป้า..."
            UI.statusLbl.TextColor3 = Color3.fromRGB(255,200,100)
            UI.tgtLbl.Text = "🎯 -"
        else
            UI.statusLbl.Text = "● ปิด"
            UI.statusLbl.TextColor3 = Color3.fromRGB(200,200,200)
            UI.tgtLbl.Text = "🎯 -"
            UI.tgtLbl.TextColor3 = Color3.fromRGB(255,220,100)
        end
        if G.enabled then
            UI.tglBtn.Text = "🛑 ปิด Ghost"
            UI.tglBtn.BackgroundColor3 = Color3.fromRGB(130,40,40)
        else
            UI.tglBtn.Text = "👻 เปิด Ghost (Aim)"
            UI.tglBtn.BackgroundColor3 = Color3.fromRGB(80,40,130)
        end
    end

    function Ghost.refreshHK()
        if not UI.hkBtn then return end
        if G.hotkeyWait then
            UI.hkBtn.Text = "⌨ กดปุ่ม..."
            UI.hkBtn.BackgroundColor3 = Color3.fromRGB(200,130,40)
        elseif G.hotkey then
            UI.hkBtn.Text = "⌨ " .. G.hotkey.Name
            UI.hkBtn.BackgroundColor3 = Color3.fromRGB(60,140,90)
        else
            UI.hkBtn.Text = "⌨ ตั้งปุ่ม Hotkey"
            UI.hkBtn.BackgroundColor3 = Color3.fromRGB(90,60,60)
        end
    end

    function Ghost.refreshCombat()
        if G.autoCombo then
            UI.comboBtn.Text = "⚔️ Auto-Combo: เปิด"
            UI.comboBtn.BackgroundColor3 = Color3.fromRGB(100,60,40)
        else
            UI.comboBtn.Text = "⚔️ Auto-Combo: ปิด"
            UI.comboBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
        end
        UI.comboTypeBtn.Text = G.comboAttackType
        if G.comboBurst then
            UI.burstBtn.Text = "💥 Burst: เปิด"
            UI.burstBtn.BackgroundColor3 = Color3.fromRGB(100,50,50)
        else
            UI.burstBtn.Text = "💥 Burst: ปิด"
            UI.burstBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
        end
        if G.tpBehind then
            UI.tpBtn.Text = "🚀 TP: เปิด"
            UI.tpBtn.BackgroundColor3 = Color3.fromRGB(60,100,80)
        else
            UI.tpBtn.Text = "🚀 TP: ปิด"
            UI.tpBtn.BackgroundColor3 = Color3.fromRGB(50,50,70)
        end
        if G.antiDetect then
            UI.antiBtn.Text = "🛡️ Jitter: เปิด"
            UI.antiBtn.BackgroundColor3 = Color3.fromRGB(50,90,60)
        else
            UI.antiBtn.Text = "🛡️ Jitter: ปิด"
            UI.antiBtn.BackgroundColor3 = Color3.fromRGB(80,50,50)
        end
        if G.patternSpoof then
            UI.spoofBtn.Text = "🎭 Spoof: เปิด"
            UI.spoofBtn.BackgroundColor3 = Color3.fromRGB(50,90,60)
        else
            UI.spoofBtn.Text = "🎭 Spoof: ปิด"
            UI.spoofBtn.BackgroundColor3 = Color3.fromRGB(80,50,50)
        end
    end

    function Ghost.refreshSpec()
        if G.specActive then
            UI.specTgl.Text = "🎥 ปิดกล้อง"
            UI.specTgl.BackgroundColor3 = Color3.fromRGB(70,130,90)
        else
            UI.specTgl.Text = "🎥 เปิดกล้อง"
            UI.specTgl.BackgroundColor3 = Color3.fromRGB(90,60,60)
        end
        UI.smBtn.Text = string.format("✨ %.2f", G.specSmooth)
    end

    function Ghost.refreshList()
        for _, c in ipairs(UI.scroll:GetChildren()) do
            if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
        end
        local ps = {}
        for _, p in ipairs(P:GetPlayers()) do
            if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                local h = p.Character:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then table.insert(ps, p) end
            end
        end
        table.sort(ps, function(a,b) return a.Name:lower() < b.Name:lower() end)
        Ghost.resizeScroll(#ps)
        if #ps == 0 then
            local e = Instance.new("TextLabel")
            e.Size = UDim2.new(1,0,0,S(30)); e.BackgroundTransparency = 1
            e.Text = "(ไม่มีผู้เล่นอื่น)"; e.TextColor3 = Color3.fromRGB(180,180,180)
            e.Font = Enum.Font.Gotham; e.TextSize = S(11)
            e.Parent = UI.scroll
            return
        end
        for i, p in ipairs(ps) do
            local isT = (G.enabled and G.target == p)
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1,-4,0,ITEM_H)
            row.BackgroundColor3 = isT and Color3.fromRGB(60,140,90) or Color3.fromRGB(40,40,60)
            row.BorderSizePixel = 0; row.Text = ""; row.LayoutOrder = i
            row.Parent = UI.scroll
            Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)
            local n = Instance.new("TextLabel")
            n.Size = UDim2.new(1,-70,1,0); n.Position = UDim2.new(0,8,0,0)
            n.BackgroundTransparency = 1; n.Text = p.DisplayName
            n.TextColor3 = Color3.fromRGB(255,255,255)
            n.Font = Enum.Font.GothamBold; n.TextSize = FONT_N
            n.TextXAlignment = Enum.TextXAlignment.Left
            n.TextTruncate = Enum.TextTruncate.AtEnd
            n.Parent = row
            local a = Instance.new("TextLabel")
            a.Size = UDim2.new(0,60,1,0); a.Position = UDim2.new(1,-64,0,0)
            a.BackgroundTransparency = 1
            a.Text = isT and "▶ หยุด" or "▶ เกาะ"
            a.TextColor3 = isT and Color3.fromRGB(255,200,100) or Color3.fromRGB(180,220,255)
            a.Font = Enum.Font.GothamBold; a.TextSize = S(11)
            a.Parent = row
            row.MouseButton1Click:Connect(function()
                if not G.alive then return end
                if G.enabled and G.target == p then Ghost.stop()
                else
                    if G.enabled then Ghost.stop() end
                    Ghost.start(p)
                end
                Ghost.refreshList()
            end)
        end
    end

    function Ghost.refreshAll()
        if not G.alive then return end
        Ghost.refreshStatus()
        if showHotkey then Ghost.refreshHK() end
        Ghost.refreshCombat()
        Ghost.refreshSpec()
        Ghost.refreshList()
    end

    -- Events
    UI.tglBtn.MouseButton1Click:Connect(function() if G.alive then Ghost.toggle() end end)
    if showHotkey then
        UI.hkBtn.MouseButton1Click:Connect(function() if G.alive then G.hotkeyWait = true; Ghost.refreshHK() end end)
        UI.clrBtn.MouseButton1Click:Connect(function()
            if G.alive then G.hotkeyWait = false; Ghost.rebind(nil) end
        end)
    end
    refBtn.MouseButton1Click:Connect(function() if G.alive then Ghost.refreshList() end end)

    UI.specTgl.MouseButton1Click:Connect(function()
        if not G.alive then return end
        if G.specActive then G.specActive = false; stopSpec()
        else G.specActive = true end
        Ghost.refreshSpec()
    end)

    local smoothLevels = {0.15, 0.25, 0.4, 0.6, 1.0}
    local smIdx = 2
    UI.smBtn.MouseButton1Click:Connect(function()
        if not G.alive then return end
        smIdx = smIdx + 1
        if smIdx > #smoothLevels then smIdx = 1 end
        G.specSmooth = smoothLevels[smIdx]
        Ghost.refreshSpec()
    end)

    UI.comboBtn.MouseButton1Click:Connect(function()
        G.autoCombo = not G.autoCombo
        Ghost.refreshCombat()
    end)

    local comboTyps = {"M1", "Skill1", "Skill2", "Skill3", "Skill4", "Mix"}
    local ctIdx = 1
    UI.comboTypeBtn.MouseButton1Click:Connect(function()
        ctIdx = ctIdx + 1
        if ctIdx > #comboTyps then ctIdx = 1 end
        G.comboAttackType = comboTyps[ctIdx]
        Ghost.refreshCombat()
    end)

    UI.burstBtn.MouseButton1Click:Connect(function()
        G.comboBurst = not G.comboBurst
        if G.comboBurst then setComboDelay(0.15) else setComboDelay(0.35) end
        Ghost.refreshCombat()
    end)

    UI.tpBtn.MouseButton1Click:Connect(function()
        G.tpBehind = not G.tpBehind
        Ghost.refreshCombat()
        Ghost.refreshStatus()
    end)

    UI.antiBtn.MouseButton1Click:Connect(function()
        G.antiDetect = not G.antiDetect
        Ghost.refreshCombat()
    end)

    UI.spoofBtn.MouseButton1Click:Connect(function()
        G.patternSpoof = not G.patternSpoof
        Ghost.refreshCombat()
    end)

    colBtn.MouseButton1Click:Connect(function()
        G.collapsed = not G.collapsed
        if G.collapsed then
            main.Size = UDim2.new(0,S(180),0,S(36))
            UI.body.Visible = false
            UI.title.Text = "👻 Ghost"
            colBtn.Text = "▲"
        else
            Ghost.resizeScroll(#P:GetPlayers() - 1)
            UI.body.Visible = true
            UI.title.Text = "👻 GHOST V7 | " .. platform
            colBtn.Text = "▼"
        end
    end)

    clsBtn.MouseButton1Click:Connect(function() Ghost.shutdown() end)

    U.InputBegan:Connect(function(i, gp)
        if gp or not G.alive then return end

        -- ✅ Hotkeys ทำงานเฉพาะ PC
        if showHotkey then
            if i.KeyCode == Enum.KeyCode.RightControl then
                G.autoCombo = not G.autoCombo
                Ghost.refreshCombat()
            end
            if i.KeyCode == Enum.KeyCode.RightShift then
                G.comboBurst = not G.comboBurst
                if G.comboBurst then setComboDelay(0.15) else setComboDelay(0.35) end
                Ghost.refreshCombat()
            end
            if i.KeyCode == Enum.KeyCode.RightAlt then
                G.tpBehind = not G.tpBehind
                Ghost.refreshCombat()
                Ghost.refreshStatus()
            end
            if G.hotkeyWait then
                if i.KeyCode == Enum.KeyCode.Escape then G.hotkeyWait=false; Ghost.refreshHK(); return end
                if i.KeyCode == Enum.KeyCode.Backspace or i.KeyCode == Enum.KeyCode.Delete then
                    G.hotkeyWait=false; Ghost.rebind(nil); return
                end
                if i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode ~= Enum.KeyCode.Unknown then
                    G.hotkeyWait = false; Ghost.rebind(i.KeyCode)
                end
                return
            end
        end

        -- Spectate input (ทั้ง PC + Mobile)
        if not G.enabled or not G.specActive then return end
        if i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.Touch then
            G.specDown = true; G.specMX = i.Position.X; G.specMY = i.Position.Y
        end
        if i.UserInputType == Enum.UserInputType.MouseWheel then
            G.specDist = clamp(G.specDist - i.Position.Z*2, 4, 50)
        end
    end)

    U.InputChanged:Connect(function(i)
        if not G.alive or not G.enabled or not G.specActive or not G.specDown then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local dx = i.Position.X - G.specMX; local dy = i.Position.Y - G.specMY
            G.specMX = i.Position.X; G.specMY = i.Position.Y
            G.specYaw = G.specYaw + dx*0.3
            G.specPitch = clamp(G.specPitch - dy*0.3, -80, 80)
        end
    end)

    U.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.Touch then
            G.specDown = false
        end
    end)

    LP.CharacterAdded:Connect(function()
        if G.enabled then
            task.wait(0.5)
            if G.enabled then Ghost.stop() end
        end
    end)

    task.spawn(function()
        while G.alive do
            task.wait(2)
            Ghost.refreshStatus()
            Ghost.refreshList()
        end
    end)

    task.wait(0.1)
    Ghost.refreshAll()
    setMode("stick")

    print("[Ghost V7 MD] โหลดเสร็จ | Device:", deviceType)
    print("[Ghost V7 MD] Platform:", platform, "| Scale:", uiScale, "| Touch:", touchMode)
end
