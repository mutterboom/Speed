-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Boomxico V8.6 FIXED                                          ║
-- ║  ฟีเจอร์: Speed / Fly / Stick / ESP / Names / Noclip / FPS    ║
-- ╚═══════════════════════════════════════════════════════════════╝
do
    if not game:IsLoaded() then game.Loaded:Wait() end
    local P = game:GetService("Players")
    local R = game:GetService("RunService")
    local U = game:GetService("UserInputService")
    local C = game:GetService("ContextActionService")
    local LP = P.LocalPlayer
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    local isPC = U.KeyboardEnabled and not U.TouchEnabled
    local isMobile = U.TouchEnabled

    local vp = workspace.CurrentCamera.ViewportSize
    local mS = math.min(vp.X, vp.Y)
    local dev, scale = "PC", 1.0
    if isMobile then
        if mS < 380 then dev, scale = "M-S", 0.65
        elseif mS < 450 then dev, scale = "M-M", 0.78
        elseif mS < 600 then dev, scale = "M-L", 0.88
        else dev, scale = "Tablet", 0.95 end
    else
        if vp.Y < 700 then scale = 0.85
        elseif vp.Y < 900 then scale = 0.95
        elseif vp.Y < 1200 then scale = 1.0
        else scale = 1.15 end
    end
    local function S(px) return math.floor(px * scale) end

    local B = {}
    B.st = {speed=false, fly=false, esp=false, name=false, noclip=false,
            fps=false, team=false, stick=false, alive=true, open=true,
            espOpen=false,
            runSpd=50, flySpd=50, nameDist=800, espIdx=1, stickDist=3,
            stickTarget=nil, stickHK=nil, stickWait=false,
            waitSpeedHK=false, waitFlyHK=false,
            lastHK=0, spectateTarget=nil, spectateOn=false, specYaw=0,
            specPitch=-10, specDist=12, mouseDown=false, lastMX=0, lastMY=0}

    B.dirs = {F=false, B=false, L=false, R=false, U=false, D=false}
    B.pcK = {W=false, A=false, S=false, D=false, Space=false, Shift=false}
    B.hotkeys = {speed={key=nil, pressed=false}, fly={key=nil, pressed=false}}
    B.saved = {speed=false, speedVal=50, fly=false, flyVal=50,
               esp=false, name=false, nameDist=800, noclip=false,
               fps=false, espIdx=1, team=false, stickDist=3}

    B.colors = {
        bg=Color3.fromRGB(8,8,10), bgL=Color3.fromRGB(22,22,28),
        brd=Color3.fromRGB(255,180,0), txt=Color3.fromRGB(255,230,140),
        txtD=Color3.fromRGB(180,150,60), acc=Color3.fromRGB(255,200,0),
        glow=Color3.fromRGB(255,230,100), act=Color3.fromRGB(120,90,0),
        dgr=Color3.fromRGB(80,15,15), stk=Color3.fromRGB(60,150,90),
        sil=Color3.fromRGB(230,230,240), silD=Color3.fromRGB(160,160,175),
    }
    local CC = B.colors

    B.espColors = {
        {c=Color3.fromRGB(255,180,0)}, {c=Color3.fromRGB(255,40,40)},
        {c=Color3.fromRGB(40,255,80)}, {c=Color3.fromRGB(60,170,255)},
        {c=Color3.fromRGB(180,60,255)}, {c=Color3.fromRGB(255,80,200)},
        {c=Color3.fromRGB(255,255,255)}, {c=Color3.fromRGB(30,30,30)},
    }

    B.espObj = {}; B.nameObj = {}; B.nameData = {}
    B.rows = {}; B.glows = {}; B.cBtns = {}
    B.conns = {speed=nil, speedRS=nil, speedHB=nil, fly=nil, stick=nil,
               noclip=nil, bodyVel=nil, bodyGyro=nil, animTrack=nil}

    B.STICK_ACT = "BoomStickHK_V86"
    pcall(function()
        for _, n in ipairs({"StickTP_Hotkey","StickTP_Hotkey_v13","StickTP_Hotkey_v14", B.STICK_ACT}) do
            pcall(function() C:UnbindAction(n) end)
        end
    end)

    local function canT()
        local n = tick()
        if n - B.st.lastHK < 0.4 then return false end
        B.st.lastHK = n
        return true
    end
    local function clamp(v, a, b) if v<a then return a end if v>b then return b end return v end
    local function getHRP(p) if not p or not p.Parent then return nil end local c = p.Character return c and c:FindFirstChild("HumanoidRootPart") end
    local function espColor() return (B.espColors[B.st.espIdx] or B.espColors[1]).c end

    B.anim = hum:FindFirstChildOfClass("Animator")
    if not B.anim then B.anim = Instance.new("Animator"); B.anim.Parent = hum end

    local function addGlow(t, base, title)
        local s = Instance.new("UIStroke", t)
        s.Color = CC.brd; s.Thickness = title and 1.5 or 1
        s.Transparency = base or 0.7
        table.insert(B.glows, {stroke=s, base=base or 0.7, title=title})
        return s
    end

    task.spawn(function()
        while B.st.alive do
            local t = tick()
            for _, o in ipairs(B.glows) do
                if o.stroke and o.stroke.Parent then
                    local p = math.sin(t*2)*0.5+0.5
                    o.stroke.Transparency = o.title and (0.3+p*0.25) or (o.base+p*0.1)
                end
            end
            task.wait(0.05)
        end
    end)

    -- ═══ SPEED ═══
    local function applySpd()
        if not B.st.alive or not B.st.speed or B.st.fly or B.st.stick then return end
        if not hum or not hum.Parent or hum.Health <= 0 then return end
        if hum.WalkSpeed ~= B.st.runSpd then hum.WalkSpeed = B.st.runSpd end
    end
    local function startSpd()
        if B.conns.speed then return end
        B.conns.speed = R.Heartbeat:Connect(applySpd)
        if B.conns.speedRS then B.conns.speedRS:Disconnect() end
        B.conns.speedRS = R.RenderStepped:Connect(applySpd)
        if B.conns.speedHB then B.conns.speedHB:Disconnect() end
        B.conns.speedHB = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if B.st.speed and not B.st.fly and not B.st.stick and hum.WalkSpeed ~= B.st.runSpd then
                hum.WalkSpeed = B.st.runSpd
            end
        end)
        applySpd()
    end
    local function stopSpd()
        if B.conns.speed then B.conns.speed:Disconnect(); B.conns.speed=nil end
        if B.conns.speedRS then B.conns.speedRS:Disconnect(); B.conns.speedRS=nil end
        if B.conns.speedHB then B.conns.speedHB:Disconnect(); B.conns.speedHB=nil end
    end

    -- ═══ FLY ═══
    local function getRunTrack()
        if not B.anim then return nil end
        for _, tr in pairs(B.anim:GetPlayingAnimationTracks()) do
            local id = tr.Animation and tr.Animation.AnimationId or ""
            if id == "rbxassetid://507767714" or tr.Name=="run" or tr.Name=="RunAnim" or string.find(id,"run") then return tr end
        end
        local fb = Instance.new("Animation"); fb.AnimationId = "rbxassetid://507767714"
        local ok, tr = pcall(function() return B.anim:LoadAnimation(fb) end)
        if ok then return tr end
        return nil
    end
    local function startFly()
        if B.conns.bodyVel then B.conns.bodyVel:Destroy() end
        if B.conns.bodyGyro then B.conns.bodyGyro:Destroy() end
        B.conns.bodyVel = Instance.new("BodyVelocity")
        B.conns.bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        B.conns.bodyVel.Velocity = Vector3.zero; B.conns.bodyVel.P = 1250
        B.conns.bodyVel.Parent = hrp
        B.conns.bodyGyro = Instance.new("BodyGyro")
        B.conns.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        B.conns.bodyGyro.P = 3000; B.conns.bodyGyro.D = 50
        B.conns.bodyGyro.CFrame = workspace.CurrentCamera.CFrame
        B.conns.bodyGyro.Parent = hrp
        hum.PlatformStand = false
        hum:ChangeState(Enum.HumanoidStateType.Running)
        task.wait(0.1)
        B.conns.animTrack = getRunTrack()
        if B.conns.animTrack then
            B.conns.animTrack.Priority = Enum.AnimationPriority.Action
            B.conns.animTrack.Looped = true
            pcall(function() B.conns.animTrack:Play(0.1) end)
        end
        if isMobile and B.UI.pad then B.UI.pad.Visible = true end
        if B.conns.fly then B.conns.fly:Disconnect() end
        B.conns.fly = R.RenderStepped:Connect(function()
            if not B.st.alive or not B.st.fly then return end
            if not B.conns.bodyVel or not B.conns.bodyGyro or not hrp or not hrp.Parent then return end
            if not hum or not hum.Parent then return end
            hum:ChangeState(Enum.HumanoidStateType.Running)
            hum.PlatformStand = false
            if B.conns.animTrack then
                if not B.conns.animTrack.IsPlaying then pcall(function() B.conns.animTrack:Play(0.1) end) end
                pcall(function() B.conns.animTrack:AdjustSpeed(math.clamp(B.st.flySpd/50, 0.5, 3)) end)
            end
            B.conns.bodyGyro.CFrame = workspace.CurrentCamera.CFrame
            local cam = workspace.CurrentCamera
            local mv = Vector3.zero
            if isMobile then
                if B.dirs.F then mv = mv + cam.CFrame.LookVector end
                if B.dirs.B then mv = mv - cam.CFrame.LookVector end
                if B.dirs.L then mv = mv - cam.CFrame.RightVector end
                if B.dirs.R then mv = mv + cam.CFrame.RightVector end
                if B.dirs.U then mv = mv + Vector3.new(0,1,0) end
                if B.dirs.D then mv = mv - Vector3.new(0,1,0) end
            end
            if isPC then
                if B.pcK.W then mv = mv + cam.CFrame.LookVector end
                if B.pcK.S then mv = mv - cam.CFrame.LookVector end
                if B.pcK.A then mv = mv - cam.CFrame.RightVector end
                if B.pcK.D then mv = mv + cam.CFrame.RightVector end
                if B.pcK.Space then mv = mv + Vector3.new(0,1,0) end
                if B.pcK.Shift then mv = mv - Vector3.new(0,1,0) end
            end
            if mv.Magnitude > 0 then
                local j = 1 + (math.random()-0.5)*0.03
                B.conns.bodyVel.Velocity = mv.Unit * B.st.flySpd * j
            else B.conns.bodyVel.Velocity = Vector3.zero end
        end)
    end
    local function stopFly()
        if B.conns.fly then B.conns.fly:Disconnect(); B.conns.fly=nil end
        if B.conns.bodyVel then B.conns.bodyVel:Destroy(); B.conns.bodyVel=nil end
        if B.conns.bodyGyro then B.conns.bodyGyro:Destroy(); B.conns.bodyGyro=nil end
        if B.conns.animTrack then pcall(function() B.conns.animTrack:Stop(0.1) end); B.conns.animTrack=nil end
        if hum and hum.Parent == char then
            hum.PlatformStand = false
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            if B.st.speed and not B.st.stick then
                hum.WalkSpeed = B.st.runSpd; stopSpd(); startSpd()
            else hum.WalkSpeed = 16 end
        end
        if B.UI.pad then B.UI.pad.Visible = false end
        for k in pairs(B.dirs) do B.dirs[k] = false end
    end

    -- ═══ STICK ═══
    local function getNearestPlayer()
        local myHRP = getHRP(LP); if not myHRP then return nil end
        local nearest, minD = nil, math.huge
        for _, p in ipairs(P:GetPlayers()) do
            if p ~= LP then
                local h = getHRP(p)
                if h then
                    local d = (h.Position - myHRP.Position).Magnitude
                    if d < minD then minD = d; nearest = p end
                end
            end
        end
        return nearest
    end
    local function stickLoop()
        if not B.st.stick or not B.st.alive then return end
        local myHRP = getHRP(LP); if not myHRP then return end
        if not B.st.stickTarget or not getHRP(B.st.stickTarget) then
            B.st.stickTarget = getNearestPlayer()
            if not B.st.stickTarget then return end
            if B.UI.refreshStickStatus then B.UI.refreshStickStatus() end
        end
        local tgtHRP = getHRP(B.st.stickTarget); if not tgtHRP then return end
        local look = tgtHRP.CFrame.LookVector
        myHRP.CFrame = CFrame.new(tgtHRP.Position - look*B.st.stickDist, tgtHRP.Position)
        myHRP.AssemblyLinearVelocity = Vector3.zero
        myHRP.AssemblyAngularVelocity = Vector3.zero
    end
    local function startStick(t)
        if B.st.stick then return end
        B.st.stick = true
        B.st.stickTarget = t or B.st.stickTarget or getNearestPlayer()
        if not B.st.stickTarget then B.st.stick=false; return end
        if B.conns.stick then pcall(function() B.conns.stick:Disconnect() end) end
        B.conns.stick = R.Heartbeat:Connect(stickLoop)
        if B.UI.refreshStickUI then B.UI.refreshStickUI() end
        if B.UI.refreshStickStatus then B.UI.refreshStickStatus() end
    end
    local function stopStick()
        if not B.st.stick then return end
        B.st.stick = false; B.st.stickTarget = nil
        if B.conns.stick then pcall(function() B.conns.stick:Disconnect() end); B.conns.stick=nil end
        if hum and hum.Parent == char then
            if B.st.speed and not B.st.fly then
                hum.WalkSpeed = B.st.runSpd; stopSpd(); startSpd()
            else hum.WalkSpeed = 16 end
        end
        if B.UI.refreshStickUI then B.UI.refreshStickUI() end
        if B.UI.refreshStickStatus then B.UI.refreshStickStatus() end
    end

    local function getFromAim()
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
    local function getInSight()
        local cam = workspace.CurrentCamera
        local cp, cl = cam.CFrame.Position, cam.CFrame.LookVector
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
    local function onStickHK()
        if not B.st.alive then return end
        local n = tick(); if n - B.st.lastHK < 0.15 then return end
        B.st.lastHK = n
        if B.st.stick then stopStick(); return end
        local t = getFromAim() or getInSight() or getNearestPlayer()
        if t then startStick(t) end
    end
    local function bindStickHK(k)
        pcall(function() C:UnbindAction(B.STICK_ACT) end)
        B.st.stickHK = k
        if k then
            pcall(function()
                C:BindAction(B.STICK_ACT, function(_, s)
                    if s == Enum.UserInputState.Begin then onStickHK() end
                    return Enum.ContextActionResult.Pass
                end, false, k)
            end)
        end
        if B.UI.refreshStickHKBtn then B.UI.refreshStickHKBtn() end
    end

    -- ═══ NOCLIP ═══
    local function enableNoclip()
        if B.conns.noclip then return end
        B.conns.noclip = R.Stepped:Connect(function()
            if not B.st.noclip or not char or not char.Parent then return end
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end)
    end
    local function disableNoclip()
        if B.conns.noclip then B.conns.noclip:Disconnect(); B.conns.noclip=nil end
        if char and char.Parent then
            for _, p in ipairs(char:GetDescendants()) do
                if p:IsA("BasePart") then pcall(function() p.CanCollide = true end) end
            end
        end
    end

    -- ═══ FPS BOOST ═══
    B.fpsBackup = {}
    local function enableFPS()
        if not B.st.fps then return end
        for _, o in ipairs(workspace:GetDescendants()) do
            if o:IsA("ParticleEmitter") or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles") then
                if o.Enabled then table.insert(B.fpsBackup, {o=o, p="Enabled", v=true}); o.Enabled=false end
            end
        end
        local L = game:GetService("Lighting")
        table.insert(B.fpsBackup, {o=L, p="GlobalShadows", v=L.GlobalShadows})
        L.GlobalShadows = false
    end
    local function disableFPS()
        for _, d in ipairs(B.fpsBackup) do
            if d.o and d.o.Parent ~= nil then pcall(function() d.o[d.p] = d.v end) end
        end
        B.fpsBackup = {}
    end

    -- ═══ ESP ═══
    local function clearESP()
        for _, o in ipairs(B.espObj) do
            if o.hl and o.hl.Parent then o.hl:Destroy() end
        end
        B.espObj = {}
    end
    local function applyESP(c, tp)
        if not c or not c.Parent then return end
        if B.st.team and tp.Team == LP.Team then return end
        for i = #B.espObj, 1, -1 do
            if B.espObj[i].player == tp then
                if B.espObj[i].hl and B.espObj[i].hl.Parent then B.espObj[i].hl:Destroy() end
                table.remove(B.espObj, i)
            end
        end
        local hl = Instance.new("Highlight")
        hl.Name = "BoomESP"; hl.Adornee = c
        hl.FillColor = espColor()
        hl.OutlineColor = Color3.fromRGB(255,255,255)
        hl.FillTransparency = 0.4; hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = c
        table.insert(B.espObj, {hl=hl, player=tp})
    end
    local function refreshESP()
        clearESP()
        if not B.st.esp then return end
        for _, p in pairs(P:GetPlayers()) do
            if p ~= LP and p.Character then applyESP(p.Character, p) end
        end
    end

    -- ═══ NAMES ═══
    local function clearNames()
        for _, o in pairs(B.nameObj) do if o then o:Destroy() end end
        B.nameObj = {}; B.nameData = {}
    end
    local function applyName(c, n, tp)
        if not c then return end
        if B.st.team and tp.Team == LP.Team then return end
        local h = c:FindFirstChild("Head"); if not h then return end
        local bg = Instance.new("BillboardGui")
        bg.Name = "BoomName"
        bg.Size = UDim2.new(0, S(110), 0, S(24))
        bg.StudsOffset = Vector3.new(0, 2.8, 0)
        bg.AlwaysOnTop = true; bg.LightInfluence = 0
        bg.MaxDistance = B.st.nameDist; bg.Adornee = h; bg.Parent = h
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,0,1,0); l.BackgroundTransparency = 1
        l.Text = n or "?"; l.TextColor3 = CC.sil
        l.TextStrokeTransparency = 0; l.TextStrokeColor3 = Color3.fromRGB(40,40,50)
        l.Font = Enum.Font.GothamBold; l.TextSize = S(14); l.Parent = bg
        table.insert(B.nameObj, bg)
        table.insert(B.nameData, {gui=bg, head=h})
    end
    local function refreshNames()
        clearNames()
        if not B.st.name then return end
        for _, p in pairs(P:GetPlayers()) do
            if p ~= LP and p.Character then applyName(p.Character, p.Name, p) end
        end
    end

    -- ═══════════════════════════════════════════
    -- UI
    -- ═══════════════════════════════════════════
    B.UI = {}
    local UI = B.UI

    UI.gui = Instance.new("ScreenGui")
    UI.gui.Name = "ByBoomMenu"
    UI.gui.ResetOnSpawn = false
    UI.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    UI.gui.Parent = LP:WaitForChild("PlayerGui")

    UI.toggle = Instance.new("TextButton")
    UI.toggle.Size = UDim2.new(0, S(55), 0, S(55))
    UI.toggle.Position = UDim2.new(0, 20, 0, 100)
    UI.toggle.BackgroundColor3 = CC.bg; UI.toggle.BackgroundTransparency = 0.4
    UI.toggle.Text = "B"; UI.toggle.TextColor3 = CC.txt
    UI.toggle.Font = Enum.Font.GothamBold; UI.toggle.TextSize = S(24)
    UI.toggle.TextStrokeTransparency = 0.4
    UI.toggle.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    UI.toggle.Active = true; UI.toggle.Draggable = true
    UI.toggle.Parent = UI.gui
    Instance.new("UICorner", UI.toggle).CornerRadius = UDim.new(1,0)
    addGlow(UI.toggle, 0.5, true)

    local mainW = S(280)
    local mainH = math.floor(math.min(520*scale, vp.Y*0.72))
    local mainY = math.max(S(70), (vp.Y - mainH)/2)

    UI.main = Instance.new("Frame")
    UI.main.Size = UDim2.new(0, mainW, 0, mainH)
    UI.main.Position = UDim2.new(0, 15, 0, mainY)
    UI.main.BackgroundColor3 = CC.bg; UI.main.BackgroundTransparency = 0.4
    UI.main.Active = false; UI.main.ClipsDescendants = true
    UI.main.Parent = UI.gui
    Instance.new("UICorner", UI.main).CornerRadius = UDim.new(0,18)
    addGlow(UI.main, 0.7, false)

    local topLine = Instance.new("Frame")
    topLine.Size = UDim2.new(1,-30,0,2); topLine.Position = UDim2.new(0,15,0,0)
    topLine.BackgroundColor3 = CC.acc; topLine.BorderSizePixel = 0
    topLine.Parent = UI.main
    Instance.new("UICorner", topLine).CornerRadius = UDim.new(1,0)

    local title = Instance.new("TextButton")
    title.Size = UDim2.new(1,-20,0,S(42)); title.Position = UDim2.new(0,10,0,S(8))
    title.BackgroundTransparency = 1; title.Text = "BY BOOMXICO V8.6"
    title.TextColor3 = CC.txt; title.TextStrokeTransparency = 0.4
    title.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    title.Font = Enum.Font.GothamBold; title.TextSize = S(20)
    title.Active = true; title.Parent = UI.main

    local drag = {on=false, start=nil, pos=nil}
    title.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag.on = true; drag.start = i.Position; drag.pos = UI.main.Position
        end
    end)
    title.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag.on = false
        end
    end)
    U.InputChanged:Connect(function(i)
        if drag.on and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - drag.start
            UI.main.Position = UDim2.new(drag.pos.X.Scale, drag.pos.X.Offset+d.X, drag.pos.Y.Scale, drag.pos.Y.Offset+d.Y)
        end
    end)

    local tGlow = Instance.new("UIStroke", title)
    tGlow.Color = CC.glow; tGlow.Thickness = 1; tGlow.Transparency = 0.5
    table.insert(B.glows, {stroke=tGlow, base=0.5, title=true})

    local scF = Instance.new("ScrollingFrame")
    scF.Size = UDim2.new(1,-S(20),1,-S(62)); scF.Position = UDim2.new(0,0,0,S(58))
    scF.BackgroundTransparency = 1; scF.BorderSizePixel = 0
    scF.ScrollBarThickness = 6; scF.ScrollBarImageColor3 = CC.acc
    scF.CanvasSize = UDim2.new(0,0,0,0)
    scF.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scF.Parent = UI.main

    local scPad = Instance.new("UIPadding", scF)
    scPad.PaddingTop = UDim.new(0,6); scPad.PaddingBottom = UDim.new(0,6)
    scPad.PaddingRight = UDim.new(0,4)

    local cont = Instance.new("Frame")
    cont.Size = UDim2.new(1,0,0,0); cont.BackgroundTransparency = 1
    cont.Parent = scF; cont.AutomaticSize = Enum.AutomaticSize.Y

    local contL = Instance.new("UIListLayout", cont)
    contL.Padding = UDim.new(0,6); contL.SortOrder = Enum.SortOrder.LayoutOrder
    contL.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local function newBtn(txt)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.9,0,0,S(36))
        b.BackgroundColor3 = CC.bgL; b.BackgroundTransparency = 0.5
        b.TextColor3 = CC.txt; b.TextStrokeTransparency = 0.5
        b.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        b.Font = Enum.Font.GothamMedium; b.TextSize = S(13)
        b.Text = txt
        b.LayoutOrder = #cont:GetChildren() + 1
        b.Parent = cont
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,10)
        addGlow(b, 0.7, false)
        return b
    end

    -- Stick Row
    local stickRow = Instance.new("Frame")
    stickRow.Size = UDim2.new(0.9,0,0,S(82))
    stickRow.BackgroundColor3 = Color3.fromRGB(20,30,40)
    stickRow.BackgroundTransparency = 0.4
    stickRow.LayoutOrder = 0
    stickRow.Parent = cont
    Instance.new("UICorner", stickRow).CornerRadius = UDim.new(0,10)
    addGlow(stickRow, 0.7, false)

    UI.stickBtn = Instance.new("TextButton")
    UI.stickBtn.BackgroundColor3 = Color3.fromRGB(60,90,160)
    UI.stickBtn.BackgroundTransparency = 0.2
    UI.stickBtn.Text = "🎯 เกาะ: ปิด"; UI.stickBtn.TextColor3 = Color3.fromRGB(255,255,255)
    UI.stickBtn.Font = Enum.Font.GothamBold; UI.stickBtn.TextSize = S(12)
    UI.stickBtn.Parent = stickRow
    Instance.new("UICorner", UI.stickBtn).CornerRadius = UDim.new(0,10)
    if isPC then
        UI.stickBtn.Size = UDim2.new(0.65,0,0,S(28)); UI.stickBtn.Position = UDim2.new(0,0,0,S(4))
    else
        UI.stickBtn.Size = UDim2.new(0.98,0,0,S(28)); UI.stickBtn.Position = UDim2.new(0.01,0,0,S(4))
    end

    UI.stickHK = Instance.new("TextButton")
    UI.stickHK.BackgroundColor3 = Color3.fromRGB(90,60,60)
    UI.stickHK.BackgroundTransparency = 0.2
    UI.stickHK.Text = "⌨ ตั้งปุ่ม"; UI.stickHK.TextColor3 = Color3.fromRGB(255,255,255)
    UI.stickHK.Font = Enum.Font.GothamBold; UI.stickHK.TextSize = S(10)
    UI.stickHK.Parent = stickRow
    Instance.new("UICorner", UI.stickHK).CornerRadius = UDim.new(0,10)
    if isPC then
        UI.stickHK.Size = UDim2.new(0.32,0,0,S(28)); UI.stickHK.Position = UDim2.new(0.68,0,0,S(4))
    else
        UI.stickHK.Size = UDim2.new(0,0,0,0); UI.stickHK.Visible = false
    end

    UI.stickStat = Instance.new("TextLabel")
    UI.stickStat.Size = UDim2.new(1,-10,0,S(18)); UI.stickStat.Position = UDim2.new(0,5,0,S(34))
    UI.stickStat.BackgroundTransparency = 1
    UI.stickStat.Text = "🎯 เป้า: -"
    UI.stickStat.TextColor3 = Color3.fromRGB(200,220,255)
    UI.stickStat.Font = Enum.Font.Code; UI.stickStat.TextSize = S(11)
    UI.stickStat.TextXAlignment = Enum.TextXAlignment.Left
    UI.stickStat.TextTruncate = Enum.TextTruncate.AtEnd
    UI.stickStat.Parent = stickRow

    local stSliderRow = Instance.new("Frame")
    stSliderRow.Size = UDim2.new(1,-10,0,S(22)); stSliderRow.Position = UDim2.new(0,5,0,S(56))
    stSliderRow.BackgroundTransparency = 1; stSliderRow.Parent = stickRow

    UI.stDistLbl = Instance.new("TextLabel")
    UI.stDistLbl.Size = UDim2.new(0.42,0,1,0); UI.stDistLbl.BackgroundTransparency = 1
    UI.stDistLbl.Text = "ระยะเกาะ: 3"; UI.stDistLbl.TextColor3 = Color3.fromRGB(200,220,255)
    UI.stDistLbl.Font = Enum.Font.Code; UI.stDistLbl.TextSize = S(11)
    UI.stDistLbl.TextXAlignment = Enum.TextXAlignment.Left
    UI.stDistLbl.Parent = stSliderRow

    local stSliderBg = Instance.new("Frame")
    stSliderBg.Size = UDim2.new(0.56,0,0,S(6)); stSliderBg.Position = UDim2.new(0.44,0,0.5,-S(3))
    stSliderBg.BackgroundColor3 = Color3.fromRGB(40,40,50)
    stSliderBg.BorderSizePixel = 0; stSliderBg.Parent = stSliderRow
    Instance.new("UICorner", stSliderBg).CornerRadius = UDim.new(1,0)

    local stSliderFill = Instance.new("Frame")
    stSliderFill.Size = UDim2.new(0.142,0,1,0)
    stSliderFill.BackgroundColor3 = CC.acc; stSliderFill.BorderSizePixel = 0
    stSliderFill.Parent = stSliderBg
    Instance.new("UICorner", stSliderFill).CornerRadius = UDim.new(1,0)

    local stSliderKnob = Instance.new("Frame")
    stSliderKnob.Size = UDim2.new(0,S(14),0,S(14))
    stSliderKnob.Position = UDim2.new(0.142,-S(7),0.5,-S(7))
    stSliderKnob.BackgroundColor3 = Color3.fromRGB(255,230,100)
    stSliderKnob.BorderSizePixel = 0; stSliderKnob.ZIndex = 5
    stSliderKnob.Parent = stSliderBg
    Instance.new("UICorner", stSliderKnob).CornerRadius = UDim.new(1,0)

    local stSliderHB = Instance.new("TextButton")
    stSliderHB.Size = UDim2.new(1,0,0,S(24)); stSliderHB.Position = UDim2.new(0,0,0.5,-S(12))
    stSliderHB.BackgroundTransparency = 1; stSliderHB.Text = ""; stSliderHB.ZIndex = 10
    stSliderHB.Parent = stSliderBg

    local function setStDist(v)
        v = clamp(v, 1, 15)
        B.st.stickDist = v; B.saved.stickDist = v
        local p = (v - 1) / 14
        stSliderFill.Size = UDim2.new(p,0,1,0)
        stSliderKnob.Position = UDim2.new(p,-S(7),0.5,-S(7))
        local txt = v == math.floor(v) and tostring(math.floor(v)) or tostring(v)
        UI.stDistLbl.Text = "ระยะเกาะ: " .. txt
    end

    local dragS = false
    local function updateSliderFromPos(px)
        local r = clamp((px - stSliderBg.AbsolutePosition.X) / stSliderBg.AbsoluteSize.X, 0, 1)
        setStDist(math.floor((1 + r*14)*10+0.5)/10)
    end
    stSliderHB.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragS = true
            updateSliderFromPos(i.Position.X)
        end
    end)
    stSliderHB.InputChanged:Connect(function(i)
        if dragS and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            updateSliderFromPos(i.Position.X)
        end
    end)
    stSliderHB.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragS = false
        end
    end)
    U.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then dragS = false end
    end)
    setStDist(3)

    UI.refreshStickUI = function()
        if B.st.stick then
            UI.stickBtn.Text = "🎯 เกาะ: เปิด"
            UI.stickBtn.BackgroundColor3 = CC.stk
        else
            UI.stickBtn.Text = "🎯 เกาะ: ปิด"
            UI.stickBtn.BackgroundColor3 = Color3.fromRGB(60,90,160)
        end
    end
    UI.refreshStickStatus = function()
        if B.st.stick and B.st.stickTarget then
            UI.stickStat.Text = "🎯 เป้า: " .. B.st.stickTarget.Name
            UI.stickStat.TextColor3 = Color3.fromRGB(150,255,180)
        elseif B.st.stick then
            UI.stickStat.Text = "🎯 กำลังหาเป้า..."
            UI.stickStat.TextColor3 = Color3.fromRGB(255,200,100)
        else
            UI.stickStat.Text = "🎯 เป้า: -"
            UI.stickStat.TextColor3 = Color3.fromRGB(180,180,180)
        end
    end
    UI.refreshStickHKBtn = function()
        if B.st.stickWait then
            UI.stickHK.Text = "⌨ กดปุ่ม..."
            UI.stickHK.BackgroundColor3 = Color3.fromRGB(200,130,40)
        elseif B.st.stickHK then
            UI.stickHK.Text = "⌨ " .. B.st.stickHK.Name
            UI.stickHK.BackgroundColor3 = Color3.fromRGB(60,140,90)
        else
            UI.stickHK.Text = "⌨ ตั้งปุ่ม"
            UI.stickHK.BackgroundColor3 = Color3.fromRGB(90,60,60)
        end
    end

    UI.stickBtn.MouseButton1Click:Connect(function()
        if B.st.stick then stopStick() else startStick(nil) end
    end)
    UI.stickHK.MouseButton1Click:Connect(function()
        B.st.stickWait = true
        B.st.waitSpeedHK = false
        B.st.waitFlyHK = false
        UI.refreshStickHKBtn()
    end)

    -- Speed Row
    local row1 = Instance.new("Frame")
    row1.Size = UDim2.new(0.9,0,0,S(36))
    row1.BackgroundTransparency = 1; row1.LayoutOrder = 1; row1.Parent = cont

    UI.spdBtn = Instance.new("TextButton")
    UI.spdBtn.Size = UDim2.new(0.62,0,1,0); UI.spdBtn.BackgroundColor3 = CC.bgL
    UI.spdBtn.BackgroundTransparency = 0.5
    UI.spdBtn.TextColor3 = CC.txt; UI.spdBtn.TextStrokeTransparency = 0.5
    UI.spdBtn.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    UI.spdBtn.Font = Enum.Font.GothamMedium; UI.spdBtn.TextSize = S(13)
    UI.spdBtn.Text = "วิ่งไว: ปิด"; UI.spdBtn.Parent = row1
    Instance.new("UICorner", UI.spdBtn).CornerRadius = UDim.new(0,10)
    addGlow(UI.spdBtn, 0.7, false)

    UI.spdBox = Instance.new("TextBox")
    UI.spdBox.Size = UDim2.new(0.34,0,1,0); UI.spdBox.Position = UDim2.new(0.66,0,0,0)
    UI.spdBox.BackgroundColor3 = CC.bgL; UI.spdBox.BackgroundTransparency = 0.5
    UI.spdBox.Text = "50"; UI.spdBox.TextColor3 = CC.acc
    UI.spdBox.TextStrokeTransparency = 0.5; UI.spdBox.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    UI.spdBox.Font = Enum.Font.GothamBold; UI.spdBox.TextSize = S(13)
    UI.spdBox.ClearTextOnFocus = false
    UI.spdBox.Parent = row1
    Instance.new("UICorner", UI.spdBox).CornerRadius = UDim.new(0,10)
    addGlow(UI.spdBox, 0.7, false)

    -- Fly Row
    local row2 = Instance.new("Frame")
    row2.Size = UDim2.new(0.9,0,0,S(36))
    row2.BackgroundTransparency = 1; row2.LayoutOrder = 2; row2.Parent = cont

    UI.flyBtn = Instance.new("TextButton")
    UI.flyBtn.Size = UDim2.new(0.62,0,1,0); UI.flyBtn.BackgroundColor3 = CC.bgL
    UI.flyBtn.BackgroundTransparency = 0.5
    UI.flyBtn.TextColor3 = CC.txt; UI.flyBtn.TextStrokeTransparency = 0.5
    UI.flyBtn.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    UI.flyBtn.Font = Enum.Font.GothamMedium; UI.flyBtn.TextSize = S(13)
    UI.flyBtn.Text = "บินได้: ปิด"; UI.flyBtn.Parent = row2
    Instance.new("UICorner", UI.flyBtn).CornerRadius = UDim.new(0,10)
    addGlow(UI.flyBtn, 0.7, false)

    UI.flyBox = Instance.new("TextBox")
    UI.flyBox.Size = UDim2.new(0.34,0,1,0); UI.flyBox.Position = UDim2.new(0.66,0,0,0)
    UI.flyBox.BackgroundColor3 = CC.bgL; UI.flyBox.BackgroundTransparency = 0.5
    UI.flyBox.Text = "50"; UI.flyBox.TextColor3 = CC.acc
    UI.flyBox.TextStrokeTransparency = 0.5; UI.flyBox.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    UI.flyBox.Font = Enum.Font.GothamBold; UI.flyBox.TextSize = S(13)
    UI.flyBox.ClearTextOnFocus = false
    UI.flyBox.Parent = row2
    Instance.new("UICorner", UI.flyBox).CornerRadius = UDim.new(0,10)
    addGlow(UI.flyBox, 0.7, false)

    -- Hotkey Row
    local hkRow = Instance.new("Frame")
    hkRow.Size = UDim2.new(0.9,0,0,S(28))
    hkRow.BackgroundTransparency = 1; hkRow.LayoutOrder = 3
    hkRow.Visible = isPC; hkRow.Parent = cont

    local function mkHK(txt, x)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.32,0,1,0); b.Position = UDim2.new(x,0,0,0)
        b.BackgroundColor3 = CC.bgL; b.BackgroundTransparency = 0.5
        b.Text = txt; b.TextColor3 = CC.txtD
        b.TextStrokeTransparency = 0.5; b.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        b.Font = Enum.Font.Gotham; b.TextSize = S(11); b.Parent = hkRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,8)
        addGlow(b, 0.75, false)
        return b
    end

    local hkSpdB, hkFlyB, hkClr
    local function refreshHKLabels()
        if hkSpdB then
            hkSpdB.Text = B.hotkeys.speed.key and ("⌨ " .. B.hotkeys.speed.key.Name) or "Hotkey วิ่ง"
            hkSpdB.BackgroundColor3 = B.hotkeys.speed.key and Color3.fromRGB(60,140,90) or CC.bgL
        end
        if hkFlyB then
            hkFlyB.Text = B.hotkeys.fly.key and ("⌨ " .. B.hotkeys.fly.key.Name) or "Hotkey บิน"
            hkFlyB.BackgroundColor3 = B.hotkeys.fly.key and Color3.fromRGB(60,140,90) or CC.bgL
        end
    end

    hkSpdB = mkHK("Hotkey วิ่ง", 0)
    hkFlyB = mkHK("Hotkey บิน", 0.34)

    hkClr = Instance.new("TextButton")
    hkClr.Size = UDim2.new(0.32,0,1,0); hkClr.Position = UDim2.new(0.68,0,0,0)
    hkClr.BackgroundColor3 = CC.dgr; hkClr.BackgroundTransparency = 0.5
    hkClr.Text = "ลบ Hotkey"; hkClr.TextColor3 = Color3.fromRGB(255,130,130)
    hkClr.Font = Enum.Font.Gotham; hkClr.TextSize = S(11); hkClr.Parent = hkRow
    Instance.new("UICorner", hkClr).CornerRadius = UDim.new(0,8)

    hkSpdB.MouseButton1Click:Connect(function()
        B.st.waitSpeedHK = true
        B.st.waitFlyHK = false
        B.st.stickWait = false
        hkSpdB.Text = "⌨ กดปุ่ม..."
        hkSpdB.BackgroundColor3 = Color3.fromRGB(200,130,40)
        if UI.refreshStickHKBtn then UI.refreshStickHKBtn() end
    end)
    hkFlyB.MouseButton1Click:Connect(function()
        B.st.waitFlyHK = true
        B.st.waitSpeedHK = false
        B.st.stickWait = false
        hkFlyB.Text = "⌨ กดปุ่ม..."
        hkFlyB.BackgroundColor3 = Color3.fromRGB(200,130,40)
        if UI.refreshStickHKBtn then UI.refreshStickHKBtn() end
    end)
    hkClr.MouseButton1Click:Connect(function()
        B.hotkeys.speed.key = nil; B.hotkeys.speed.pressed = false
        B.hotkeys.fly.key = nil;   B.hotkeys.fly.pressed = false
        refreshHKLabels()
    end)
    refreshHKLabels()
    B.UI.refreshHKLabels = refreshHKLabels

    -- ESP Header
    local espH = Instance.new("TextButton")
    espH.Size = UDim2.new(0.9,0,0,S(34)); espH.BackgroundColor3 = Color3.fromRGB(35,28,10)
    espH.BackgroundTransparency = 0.3
    espH.Text = "▶ ESP / มองทะลุ"; espH.TextColor3 = CC.acc
    espH.TextStrokeTransparency = 0.5; espH.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    espH.Font = Enum.Font.GothamBold; espH.TextSize = S(13)
    espH.LayoutOrder = 4; espH.Parent = cont
    Instance.new("UICorner", espH).CornerRadius = UDim.new(0,10)
    addGlow(espH, 0.5, true)

    local espC = Instance.new("Frame")
    espC.Size = UDim2.new(0.9,0,0,0); espC.BackgroundColor3 = Color3.fromRGB(15,15,20)
    espC.BackgroundTransparency = 0.5
    espC.LayoutOrder = 5; espC.Parent = cont
    Instance.new("UICorner", espC).CornerRadius = UDim.new(0,10)

    local espPad = Instance.new("UIPadding", espC)
    espPad.PaddingTop = UDim.new(0,6); espPad.PaddingBottom = UDim.new(0,6)

    local espL = Instance.new("UIListLayout", espC)
    espL.Padding = UDim.new(0,5); espL.SortOrder = Enum.SortOrder.LayoutOrder
    espL.HorizontalAlignment = Enum.HorizontalAlignment.Center
    espC.AutomaticSize = Enum.AutomaticSize.Y
    espC.Visible = false
    B.st.espOpen = false

    UI.espBtn = Instance.new("TextButton")
    UI.espBtn.Size = UDim2.new(1,-12,0,S(32)); UI.espBtn.BackgroundColor3 = CC.bgL
    UI.espBtn.BackgroundTransparency = 0.5
    UI.espBtn.Text = "มองทะลุ: ปิด"; UI.espBtn.TextColor3 = CC.txt
    UI.espBtn.TextStrokeTransparency = 0.5; UI.espBtn.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    UI.espBtn.Font = Enum.Font.GothamMedium; UI.espBtn.TextSize = S(12)
    UI.espBtn.LayoutOrder = 1; UI.espBtn.Parent = espC
    Instance.new("UICorner", UI.espBtn).CornerRadius = UDim.new(0,8)
    addGlow(UI.espBtn, 0.7, false)

    local colorL = Instance.new("TextLabel")
    colorL.Size = UDim2.new(1,-12,0,S(18)); colorL.BackgroundTransparency = 1
    colorL.Text = "สี ESP:"; colorL.TextColor3 = CC.txtD
    colorL.Font = Enum.Font.GothamMedium; colorL.TextSize = S(11)
    colorL.TextXAlignment = Enum.TextXAlignment.Left
    colorL.LayoutOrder = 2; colorL.Parent = espC

    local colorG = Instance.new("Frame")
    colorG.Size = UDim2.new(1,-12,0,S(60)); colorG.BackgroundTransparency = 1
    colorG.LayoutOrder = 3; colorG.Parent = espC

    local cGrid = Instance.new("UIGridLayout", colorG)
    cGrid.CellSize = UDim2.new(0,S(28),0,S(28))
    cGrid.CellPadding = UDim2.new(0,4,0,4)
    cGrid.SortOrder = Enum.SortOrder.LayoutOrder
    cGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left

    for i, e in ipairs(B.espColors) do
        local w = Instance.new("Frame")
        w.Size = UDim2.new(0,S(28),0,S(28)); w.BackgroundColor3 = e.c
        w.BorderSizePixel = 0; w.LayoutOrder = i; w.Parent = colorG
        Instance.new("UICorner", w).CornerRadius = UDim.new(1,0)
        local s = Instance.new("UIStroke", w)
        s.Color = Color3.fromRGB(255,255,255); s.Thickness = 3
        s.Transparency = (i == B.st.espIdx) and 0 or 1
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        local cb = Instance.new("TextButton")
        cb.Size = UDim2.new(1,0,1,0); cb.BackgroundTransparency = 1
        cb.Text = ""; cb.ZIndex = 10; cb.AutoButtonColor = false
        cb.Parent = w
        local chk = Instance.new("TextLabel")
        chk.Size = UDim2.new(1,0,1,0); chk.BackgroundTransparency = 1
        chk.Text = "✓"; chk.TextColor3 = Color3.fromRGB(255,255,255)
        chk.TextStrokeTransparency = 0; chk.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        chk.Font = Enum.Font.GothamBold; chk.TextSize = S(14)
        chk.Visible = (i == B.st.espIdx); chk.ZIndex = 11; chk.Parent = w
        B.cBtns[i] = {stroke=s, check=chk, entry=e}
        cb.MouseButton1Click:Connect(function()
            B.st.espIdx = i; B.saved.espIdx = i
            for j, x in ipairs(B.cBtns) do
                x.stroke.Transparency = (j == i) and 0 or 1
                x.check.Visible = (j == i)
            end
            for _, o in ipairs(B.espObj) do
                if o.hl and o.hl.Parent then o.hl.FillColor = e.c end
            end
        end)
    end

    local teamRow = Instance.new("Frame")
    teamRow.Size = UDim2.new(1,-12,0,S(32)); teamRow.BackgroundTransparency = 1
    teamRow.LayoutOrder = 4; teamRow.Parent = espC

    UI.teamBtn = Instance.new("TextButton")
    UI.teamBtn.Size = UDim2.new(1,0,1,0); UI.teamBtn.BackgroundColor3 = CC.bgL
    UI.teamBtn.BackgroundTransparency = 0.5
    UI.teamBtn.Text = "เช็คทีม: ปิด"; UI.teamBtn.TextColor3 = CC.txt
    UI.teamBtn.TextStrokeTransparency = 0.5; UI.teamBtn.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    UI.teamBtn.Font = Enum.Font.GothamMedium; UI.teamBtn.TextSize = S(12)
    UI.teamBtn.Parent = teamRow
    Instance.new("UICorner", UI.teamBtn).CornerRadius = UDim.new(0,8)
    addGlow(UI.teamBtn, 0.7, false)

    local nDistRow = Instance.new("Frame")
    nDistRow.Size = UDim2.new(1,-12,0,S(32)); nDistRow.BackgroundTransparency = 1
    nDistRow.LayoutOrder = 5; nDistRow.Parent = espC

    local nDistLbl = Instance.new("TextLabel")
    nDistLbl.Size = UDim2.new(0.62,0,1,0); nDistLbl.BackgroundColor3 = CC.bgL
    nDistLbl.BackgroundTransparency = 0.5
    nDistLbl.Text = "ระยะชื่อ"; nDistLbl.TextColor3 = CC.txt
    nDistLbl.TextStrokeTransparency = 0.5; nDistLbl.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    nDistLbl.Font = Enum.Font.GothamMedium; nDistLbl.TextSize = S(12)
    nDistLbl.Parent = nDistRow
    Instance.new("UICorner", nDistLbl).CornerRadius = UDim.new(0,8)
    addGlow(nDistLbl, 0.7, false)

    UI.distBox = Instance.new("TextBox")
    UI.distBox.Size = UDim2.new(0.34,0,1,0); UI.distBox.Position = UDim2.new(0.66,0,0,0)
    UI.distBox.BackgroundColor3 = CC.bgL; UI.distBox.BackgroundTransparency = 0.5
    UI.distBox.Text = "800"; UI.distBox.TextColor3 = CC.acc
    UI.distBox.TextStrokeTransparency = 0.5; UI.distBox.TextStrokeColor3 = Color3.fromRGB(0,0,0)
    UI.distBox.Font = Enum.Font.GothamBold; UI.distBox.TextSize = S(12)
    UI.distBox.ClearTextOnFocus = false
    UI.distBox.Parent = nDistRow
    Instance.new("UICorner", UI.distBox).CornerRadius = UDim.new(0,10)
    addGlow(UI.distBox, 0.7, false)

    espH.MouseButton1Click:Connect(function()
        B.st.espOpen = not B.st.espOpen
        espC.Visible = B.st.espOpen
        espH.Text = (B.st.espOpen and "▼ " or "▶ ") .. "ESP / มองทะลุ"
    end)

    UI.nameBtn = newBtn("เห็นชื่อ: ปิด"); UI.nameBtn.LayoutOrder = 6
    UI.noclipBtn = newBtn("Noclip: ปิด"); UI.noclipBtn.LayoutOrder = 7
    UI.fpsBtn = newBtn("FPS Boost: ปิด"); UI.fpsBtn.LayoutOrder = 8
    local openListBtn = newBtn("เปิดเมนูรายชื่อ"); openListBtn.LayoutOrder = 9
    local killBtn = newBtn("ปิดสคริปต์ทั้งหมด"); killBtn.LayoutOrder = 10
    killBtn.BackgroundColor3 = CC.dgr; killBtn.BackgroundTransparency = 0.3
    killBtn.TextColor3 = Color3.fromRGB(255,130,130); killBtn.Font = Enum.Font.GothamBold
    local closeBtn = newBtn("ซ่อนเมนู"); closeBtn.LayoutOrder = 11
    closeBtn.TextColor3 = CC.txtD

    -- Pad
    UI.pad = Instance.new("Frame")
    UI.pad.Size = UDim2.new(0,S(180),0,S(180))
    UI.pad.Position = UDim2.new(1,-S(200),0.5,-S(90))
    UI.pad.BackgroundColor3 = CC.bg; UI.pad.BackgroundTransparency = 0.4
    UI.pad.Visible = false; UI.pad.Parent = UI.gui
    Instance.new("UICorner", UI.pad).CornerRadius = UDim.new(1,0)
    addGlow(UI.pad, 0.5, false)

    local function mkPB(txt, pos)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0,S(50),0,S(50)); b.Position = pos
        b.BackgroundColor3 = Color3.fromRGB(60,40,0)
        b.BackgroundTransparency = 0.3
        b.Text = txt; b.TextColor3 = CC.txt
        b.TextStrokeTransparency = 0.5; b.TextStrokeColor3 = Color3.fromRGB(0,0,0)
        b.Font = Enum.Font.GothamBold; b.TextSize = S(20)
        b.Parent = UI.pad
        Instance.new("UICorner", b).CornerRadius = UDim.new(1,0)
        addGlow(b, 0.6, false)
        return b
    end
    local hs = S(25)
    local bU = mkPB("↑", UDim2.new(0.5,-hs,0,5))
    local bD = mkPB("↓", UDim2.new(0.5,-hs,1,-S(55)))
    local bL = mkPB("←", UDim2.new(0,5,0.5,-hs))
    local bR = mkPB("→", UDim2.new(1,-S(55),0.5,-hs))
    local bF = mkPB("W", UDim2.new(0.5,-hs,0.5,-S(55)))
    local bB = mkPB("S", UDim2.new(0.5,-hs,0.5,S(5)))

    local function bindP(b, k)
        b.MouseButton1Down:Connect(function() B.dirs[k] = true; b.BackgroundColor3 = CC.act end)
        b.MouseButton1Up:Connect(function() B.dirs[k] = false; b.BackgroundColor3 = Color3.fromRGB(60,40,0) end)
        b.MouseLeave:Connect(function() B.dirs[k] = false; b.BackgroundColor3 = Color3.fromRGB(60,40,0) end)
        b.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                B.dirs[k] = false; b.BackgroundColor3 = Color3.fromRGB(60,40,0)
            end
        end)
    end
    bindP(bU,"U"); bindP(bD,"D"); bindP(bL,"L"); bindP(bR,"R"); bindP(bF,"F"); bindP(bB,"B")

    local function toggleSpeed()
        if not canT() or not hum or not hum.Parent then return end
        B.st.speed = not B.st.speed
        UI.spdBtn.Text = B.st.speed and "วิ่งไว: เปิด" or "วิ่งไว: ปิด"
        UI.spdBtn.BackgroundColor3 = B.st.speed and CC.act or CC.bgL
        B.saved.speed = B.st.speed; B.saved.speedVal = B.st.runSpd
        if B.st.speed then stopSpd(); hum.WalkSpeed = B.st.runSpd; startSpd()
        else stopSpd(); hum.WalkSpeed = 16 end
    end
    local function toggleFly()
        if not canT() then return end
        B.st.fly = not B.st.fly
        UI.flyBtn.Text = B.st.fly and "บินได้: เปิด" or "บินได้: ปิด"
        UI.flyBtn.BackgroundColor3 = B.st.fly and CC.act or CC.bgL
        B.saved.fly = B.st.fly; B.saved.flyVal = B.st.flySpd
        if B.st.fly then startFly() else stopFly() end
    end

    UI.spdBtn.MouseButton1Click:Connect(toggleSpeed)
    UI.flyBtn.MouseButton1Click:Connect(toggleFly)

    UI.spdBox.FocusLost:Connect(function()
        local v = tonumber(UI.spdBox.Text)
        if v and v > 0 then B.st.runSpd = clamp(v,1,200)
        else UI.spdBox.Text = "50"; B.st.runSpd = 50 end
        B.saved.speedVal = B.st.runSpd
        if B.st.speed and hum and hum.Parent then hum.WalkSpeed = B.st.runSpd end
    end)
    UI.flyBox.FocusLost:Connect(function()
        local v = tonumber(UI.flyBox.Text)
        if v and v > 0 then B.st.flySpd = clamp(v,1,300)
        else UI.flyBox.Text = "50"; B.st.flySpd = 50 end
        B.saved.flyVal = B.st.flySpd
    end)

    -- Main input
    U.InputBegan:Connect(function(i, gp)
        if gp then return end

        if B.st.waitSpeedHK then
            if i.KeyCode == Enum.KeyCode.Escape then
                B.st.waitSpeedHK = false
            elseif i.KeyCode == Enum.KeyCode.Backspace or i.KeyCode == Enum.KeyCode.Delete then
                B.hotkeys.speed.key = nil; B.st.waitSpeedHK = false
            elseif i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode ~= Enum.KeyCode.Unknown then
                B.hotkeys.speed.key = i.KeyCode; B.st.waitSpeedHK = false
            end
            if B.UI.refreshHKLabels then B.UI.refreshHKLabels() end
            return
        end
        if B.st.waitFlyHK then
            if i.KeyCode == Enum.KeyCode.Escape then
                B.st.waitFlyHK = false
            elseif i.KeyCode == Enum.KeyCode.Backspace or i.KeyCode == Enum.KeyCode.Delete then
                B.hotkeys.fly.key = nil; B.st.waitFlyHK = false
            elseif i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode ~= Enum.KeyCode.Unknown then
                B.hotkeys.fly.key = i.KeyCode; B.st.waitFlyHK = false
            end
            if B.UI.refreshHKLabels then B.UI.refreshHKLabels() end
            return
        end
        if B.st.stickWait then
            if i.KeyCode == Enum.KeyCode.Escape then B.st.stickWait=false; UI.refreshStickHKBtn(); return end
            if i.KeyCode == Enum.KeyCode.Backspace or i.KeyCode == Enum.KeyCode.Delete then
                B.st.stickWait=false; bindStickHK(nil); return
            end
            if i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode ~= Enum.KeyCode.Unknown then
                B.st.stickWait=false; bindStickHK(i.KeyCode)
            end
            return
        end

        if i.KeyCode == Enum.KeyCode.W then B.pcK.W = true end
        if i.KeyCode == Enum.KeyCode.A then B.pcK.A = true end
        if i.KeyCode == Enum.KeyCode.S then B.pcK.S = true end
        if i.KeyCode == Enum.KeyCode.D then B.pcK.D = true end
        if i.KeyCode == Enum.KeyCode.Space then B.pcK.Space = true end
        if i.KeyCode == Enum.KeyCode.LeftShift then B.pcK.Shift = true end
        if i.KeyCode == Enum.KeyCode.X and U:IsKeyDown(Enum.KeyCode.LeftControl) then
            if B.noclipBusy then return end
            B.noclipBusy = true
            B.st.noclip = not B.st.noclip
            UI.noclipBtn.Text = B.st.noclip and "Noclip: เปิด" or "Noclip: ปิด"
            UI.noclipBtn.BackgroundColor3 = B.st.noclip and CC.act or CC.bgL
            B.saved.noclip = B.st.noclip
            if B.st.noclip then enableNoclip() else disableNoclip() end
            B.noclipBusy = false
        end
        if isPC then
            if B.hotkeys.speed.key and i.KeyCode == B.hotkeys.speed.key then
                if not B.hotkeys.speed.pressed then
                    B.hotkeys.speed.pressed = true
                    toggleSpeed()
                end
            end
            if B.hotkeys.fly.key and i.KeyCode == B.hotkeys.fly.key then
                if not B.hotkeys.fly.pressed then
                    B.hotkeys.fly.pressed = true
                    toggleFly()
                end
            end
        end
    end)

    U.InputEnded:Connect(function(i)
        if i.KeyCode == Enum.KeyCode.W then B.pcK.W = false end
        if i.KeyCode == Enum.KeyCode.A then B.pcK.A = false end
        if i.KeyCode == Enum.KeyCode.S then B.pcK.S = false end
        if i.KeyCode == Enum.KeyCode.D then B.pcK.D = false end
        if i.KeyCode == Enum.KeyCode.Space then B.pcK.Space = false end
        if i.KeyCode == Enum.KeyCode.LeftShift then B.pcK.Shift = false end
        if B.hotkeys.speed.key and i.KeyCode == B.hotkeys.speed.key then B.hotkeys.speed.pressed = false end
        if B.hotkeys.fly.key and i.KeyCode == B.hotkeys.fly.key then B.hotkeys.fly.pressed = false end
        if i.UserInputType == Enum.UserInputType.Touch then
            for k in pairs(B.dirs) do B.dirs[k] = false end
        end
    end)

    -- ESP events
    UI.espBtn.MouseButton1Click:Connect(function()
        if not canT() then return end
        B.st.esp = not B.st.esp
        UI.espBtn.Text = B.st.esp and "มองทะลุ: เปิด" or "มองทะลุ: ปิด"
        UI.espBtn.BackgroundColor3 = B.st.esp and CC.act or CC.bgL
        B.saved.esp = B.st.esp
        refreshESP()
    end)
    UI.teamBtn.MouseButton1Click:Connect(function()
        B.st.team = not B.st.team
        B.saved.team = B.st.team
        UI.teamBtn.Text = B.st.team and "เช็คทีม: เปิด" or "เช็คทีม: ปิด"
        UI.teamBtn.BackgroundColor3 = B.st.team and CC.act or CC.bgL
        if B.st.esp then refreshESP() end
        if B.st.name then refreshNames() end
    end)
    UI.distBox.FocusLost:Connect(function()
        local v = tonumber(UI.distBox.Text)
        if v and v > 0 then B.st.nameDist = v
        else UI.distBox.Text = "800"; B.st.nameDist = 800 end
        B.saved.nameDist = B.st.nameDist
        for _, d in ipairs(B.nameData) do
            if d.gui and d.gui.Parent then d.gui.MaxDistance = B.st.nameDist end
        end
    end)
    UI.nameBtn.MouseButton1Click:Connect(function()
        if not canT() then return end
        B.st.name = not B.st.name
        UI.nameBtn.Text = B.st.name and "เห็นชื่อ: เปิด" or "เห็นชื่อ: ปิด"
        UI.nameBtn.BackgroundColor3 = B.st.name and CC.act or CC.bgL
        B.saved.name = B.st.name
        refreshNames()
    end)
    UI.noclipBtn.MouseButton1Click:Connect(function()
        if B.noclipBusy then return end
        B.noclipBusy = true
        B.st.noclip = not B.st.noclip
        UI.noclipBtn.Text = B.st.noclip and "Noclip: เปิด" or "Noclip: ปิด"
        UI.noclipBtn.BackgroundColor3 = B.st.noclip and CC.act or CC.bgL
        B.saved.noclip = B.st.noclip
        if B.st.noclip then enableNoclip() else disableNoclip() end
        B.noclipBusy = false
    end)
    UI.fpsBtn.MouseButton1Click:Connect(function()
        B.st.fps = not B.st.fps
        UI.fpsBtn.Text = B.st.fps and "FPS Boost: เปิด" or "FPS Boost: ปิด"
        UI.fpsBtn.BackgroundColor3 = B.st.fps and CC.act or CC.bgL
        B.saved.fps = B.st.fps
        if B.st.fps then enableFPS() else disableFPS() end
    end)
    UI.toggle.MouseButton1Click:Connect(function()
        B.st.open = not B.st.open; UI.main.Visible = B.st.open
    end)
    closeBtn.MouseButton1Click:Connect(function()
        UI.main.Visible = false; B.st.open = false
    end)

    -- Name loop
    R.RenderStepped:Connect(function()
        if not B.st.alive or not B.st.name then return end
        local cam = workspace.CurrentCamera
        local cp = cam.CFrame.Position; local cl = cam.CFrame.LookVector
        local v = cam.ViewportSize
        for i = #B.nameData, 1, -1 do
            local d = B.nameData[i]
            local bg = d.gui; local h = d.head
            if not h or not h.Parent then
                if bg then bg:Destroy() end
                table.remove(B.nameData, i)
                continue
            end
            local hp = h.Position; local del = hp - cp
            local dist = del.Magnitude
            if dist > B.st.nameDist then bg.Enabled = false
            else
                local dot = cl:Dot(del.Unit)
                if dot < 0.15 then bg.Enabled = false
                else
                    local sp, on = cam:WorldToViewportPoint(hp)
                    bg.Enabled = on and sp.Z > 0 and sp.X > -50 and sp.X < v.X+50 and sp.Y > -50 and sp.Y < v.Y+50
                end
            end
        end
    end)

    -- Spectate
    local function stopSpec()
        B.st.spectateOn = false; B.st.spectateTarget = nil
        local cam = workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            if LP.Character then
                local mh = LP.Character:FindFirstChildOfClass("Humanoid")
                if mh then cam.CameraSubject = mh end
            end
        end
    end
    local function specPlayer(tp)
        if not tp then return end
        local tc = tp.Character
        if not tc then
            local ok
            ok, tc = pcall(function() return tp.CharacterAdded:Wait() end)
            if not ok or not tc then return end
        end
        B.st.spectateOn = true; B.st.spectateTarget = tp
        B.st.specYaw = 0; B.st.specPitch = -10; B.st.specDist = 12
    end
    local function tpTo(tp)
        if not tp then return end
        local tc = tp.Character
        if not tc then
            local ok
            ok, tc = pcall(function() return tp.CharacterAdded:Wait() end)
            if not ok or not tc then return end
        end
        local tr = tc:FindFirstChild("HumanoidRootPart"); if not tr then return end
        if not hrp or not hrp.Parent then return end
        local off = tr.CFrame.LookVector * -5
        hrp.CFrame = CFrame.new(tr.Position + off + Vector3.new(0,2,0), tr.Position)
    end

    R:BindToRenderStep("BoomSpec", Enum.RenderPriority.Camera.Value + 1, function()
        if not B.st.alive or not B.st.spectateOn or not B.st.spectateTarget then return end
        local tc = B.st.spectateTarget.Character; if not tc then return end
        local th = tc:FindFirstChild("Head"); if not th then return end
        local cam = workspace.CurrentCamera
        cam.CameraType = Enum.CameraType.Scriptable
        local yr = math.rad(B.st.specYaw); local pr = math.rad(B.st.specPitch)
        local off = Vector3.new(
            math.sin(yr)*math.cos(pr)*B.st.specDist,
            -math.sin(pr)*B.st.specDist + 2,
            math.cos(yr)*math.cos(pr)*B.st.specDist)
        cam.CFrame = CFrame.new(th.Position + off, th.Position)
    end)

    U.InputBegan:Connect(function(i, gp)
        if gp or not B.st.spectateOn then return end
        if i.UserInputType == Enum.UserInputType.MouseButton2 then
            B.st.mouseDown = true; B.st.lastMX = i.Position.X; B.st.lastMY = i.Position.Y
        end
        if i.UserInputType == Enum.UserInputType.Touch then
            B.st.mouseDown = true; B.st.lastMX = i.Position.X; B.st.lastMY = i.Position.Y
        end
        if i.UserInputType == Enum.UserInputType.MouseWheel then
            B.st.specDist = clamp(B.st.specDist - i.Position.Z*2, 4, 50)
        end
    end)
    U.InputChanged:Connect(function(i)
        if not B.st.spectateOn or not B.st.mouseDown then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            local dx = i.Position.X - B.st.lastMX; local dy = i.Position.Y - B.st.lastMY
            B.st.lastMX = i.Position.X; B.st.lastMY = i.Position.Y
            B.st.specYaw = B.st.specYaw + dx*0.3
            B.st.specPitch = clamp(B.st.specPitch - dy*0.3, -80, 80)
        end
    end)
    U.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.Touch then
            B.st.mouseDown = false
        end
    end)

    -- Player List
    local chk = Instance.new("Frame")
    chk.Size = UDim2.new(0,S(280),0,math.floor(math.min(410, vp.Y*0.6)))
    chk.Position = UDim2.new(0.5,-S(140),0.5,-math.floor(math.min(410,vp.Y*0.6)/2))
    chk.BackgroundColor3 = CC.bg; chk.BackgroundTransparency = 0.4
    chk.Active = true; chk.Draggable = true; chk.Visible = false
    chk.Parent = UI.gui
    Instance.new("UICorner", chk).CornerRadius = UDim.new(0,18)
    addGlow(chk, 0.7, false)

    local cTL = Instance.new("Frame")
    cTL.Size = UDim2.new(1,-30,0,2); cTL.Position = UDim2.new(0,15,0,0)
    cTL.BackgroundColor3 = CC.acc; cTL.BorderSizePixel = 0
    cTL.Parent = chk
    Instance.new("UICorner", cTL).CornerRadius = UDim.new(1,0)

    local cT = Instance.new("TextLabel")
    cT.Size = UDim2.new(1,-20,0,S(42)); cT.Position = UDim2.new(0,10,0,S(12))
    cT.BackgroundTransparency = 1; cT.Text = "PLAYERS | BOOMXICO"
    cT.TextColor3 = CC.txt; cT.Font = Enum.Font.GothamBold; cT.TextSize = S(16)
    cT.Parent = chk

    local sSpec = Instance.new("TextButton")
    sSpec.Size = UDim2.new(0.9,0,0,S(34)); sSpec.Position = UDim2.new(0.05,0,0,S(60))
    sSpec.BackgroundColor3 = CC.dgr; sSpec.BackgroundTransparency = 0.3
    sSpec.Text = "ปิดส่องกล้อง"; sSpec.TextColor3 = Color3.fromRGB(255,130,130)
    sSpec.Font = Enum.Font.GothamBold; sSpec.TextSize = S(13)
    sSpec.Parent = chk
    Instance.new("UICorner", sSpec).CornerRadius = UDim.new(0,10)

    local scr = Instance.new("ScrollingFrame")
    scr.Size = UDim2.new(0.9,0,0,S(250)); scr.Position = UDim2.new(0.05,0,0,S(102))
    scr.BackgroundColor3 = Color3.fromRGB(15,15,20)
    scr.BackgroundTransparency = 0.4
    scr.BorderSizePixel = 0; scr.ScrollBarThickness = 6
    scr.ScrollBarImageColor3 = CC.acc
    scr.CanvasSize = UDim2.new(0,0,0,0)
    scr.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scr.Parent = chk
    Instance.new("UICorner", scr).CornerRadius = UDim.new(0,12)

    local scrL = Instance.new("UIListLayout", scr)
    scrL.Padding = UDim.new(0,4); scrL.SortOrder = Enum.SortOrder.LayoutOrder
    local scrP = Instance.new("UIPadding", scr)
    scrP.PaddingTop = UDim.new(0,6); scrP.PaddingLeft = UDim.new(0,6); scrP.PaddingRight = UDim.new(0,6)

    local cCls = Instance.new("TextButton")
    cCls.Size = UDim2.new(0.9,0,0,S(34)); cCls.Position = UDim2.new(0.05,0,1,-S(42))
    cCls.BackgroundColor3 = CC.bgL; cCls.BackgroundTransparency = 0.5
    cCls.Text = "ซ่อนเมนู"; cCls.TextColor3 = CC.txtD
    cCls.Font = Enum.Font.GothamMedium; cCls.TextSize = S(13)
    cCls.Parent = chk
    Instance.new("UICorner", cCls).CornerRadius = UDim.new(0,10)

    local function refreshList()
        for _, d in pairs(B.rows) do if d and d.row then d.row:Destroy() end end
        B.rows = {}
        local ps = P:GetPlayers()
        table.sort(ps, function(a,b) return a.Name:lower() < b.Name:lower() end)
        for _, p in pairs(ps) do
            if p ~= LP then
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1,-S(8),0,S(46)); row.BackgroundColor3 = CC.bgL
                row.BackgroundTransparency = 0.5; row.BorderSizePixel = 0
                row.Parent = scr
                Instance.new("UICorner", row).CornerRadius = UDim.new(0,8)
                local av = Instance.new("ImageLabel")
                av.Size = UDim2.new(0,S(30),0,S(30)); av.Position = UDim2.new(0.02,0,0.5,-S(15))
                av.BackgroundColor3 = Color3.fromRGB(40,40,50); av.BorderSizePixel = 0
                av.Image = ""; av.Parent = row
                Instance.new("UICorner", av).CornerRadius = UDim.new(1,0)
                task.spawn(function()
                    local ok, th = pcall(function()
                        return P:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
                    end)
                    if ok and th and av and av.Parent then av.Image = th end
                end)
                local nL = Instance.new("TextLabel")
                nL.Size = UDim2.new(0.30,0,0.5,0); nL.Position = UDim2.new(0.14,0,0.02,0)
                nL.BackgroundTransparency = 1; nL.Text = p.DisplayName
                nL.TextColor3 = CC.sil; nL.Font = Enum.Font.GothamMedium
                nL.TextSize = S(11); nL.TextXAlignment = Enum.TextXAlignment.Left
                nL.TextTruncate = Enum.TextTruncate.AtEnd; nL.Parent = row
                local uL = Instance.new("TextLabel")
                uL.Size = UDim2.new(0.30,0,0.4,0); uL.Position = UDim2.new(0.14,0,0.52,0)
                uL.BackgroundTransparency = 1; uL.Text = "@" .. p.Name
                uL.TextColor3 = CC.silD; uL.Font = Enum.Font.Gotham
                uL.TextSize = S(9); uL.TextXAlignment = Enum.TextXAlignment.Left
                uL.TextTruncate = Enum.TextTruncate.AtEnd; uL.Parent = row
                local dL = Instance.new("TextLabel")
                dL.Size = UDim2.new(0.10,0,1,0); dL.Position = UDim2.new(0.44,0,0,0)
                dL.BackgroundTransparency = 1; dL.Text = "-"
                dL.TextColor3 = CC.acc; dL.Font = Enum.Font.GothamBold
                dL.TextSize = S(9); dL.Parent = row
                local tp = Instance.new("TextButton")
                tp.Size = UDim2.new(0.10,0,0,S(28)); tp.Position = UDim2.new(0.55,0,0.5,-S(14))
                tp.BackgroundColor3 = Color3.fromRGB(100,70,0); tp.BackgroundTransparency = 0.3
                tp.Text = "TP"; tp.TextColor3 = Color3.fromRGB(255,255,255)
                tp.Font = Enum.Font.GothamBold; tp.TextSize = S(11); tp.Parent = row
                Instance.new("UICorner", tp).CornerRadius = UDim.new(0,8)
                tp.MouseButton1Click:Connect(function() tpTo(p) end)
                local sp = Instance.new("TextButton")
                sp.Size = UDim2.new(0.13,0,0,S(28)); sp.Position = UDim2.new(0.66,0,0.5,-S(14))
                sp.BackgroundColor3 = Color3.fromRGB(60,40,0); sp.BackgroundTransparency = 0.3
                sp.Text = "ส่อง"; sp.TextColor3 = Color3.fromRGB(255,255,255)
                sp.Font = Enum.Font.GothamBold; sp.TextSize = S(11); sp.Parent = row
                Instance.new("UICorner", sp).CornerRadius = UDim.new(0,8)
                sp.MouseButton1Click:Connect(function() specPlayer(p) end)
                local sb = Instance.new("TextButton")
                sb.Size = UDim2.new(0.19,0,0,S(28)); sb.Position = UDim2.new(0.80,0,0.5,-S(14))
                local isSt = (B.st.stick and B.st.stickTarget == p)
                sb.BackgroundColor3 = isSt and Color3.fromRGB(60,150,90) or Color3.fromRGB(70,100,180)
                sb.BackgroundTransparency = 0.3
                sb.Text = isSt and "หยุด" or "เกาะ"; sb.TextColor3 = Color3.fromRGB(255,255,255)
                sb.Font = Enum.Font.GothamBold; sb.TextSize = S(11); sb.Parent = row
                Instance.new("UICorner", sb).CornerRadius = UDim.new(0,8)
                sb.MouseButton1Click:Connect(function()
                    if B.st.stick and B.st.stickTarget == p then stopStick()
                    else
                        if B.st.stick then stopStick() end
                        startStick(p)
                    end
                    refreshList()
                end)
                table.insert(B.rows, {row=row, player=p, distLbl=dL})
            end
        end
    end

    openListBtn.MouseButton1Click:Connect(function()
        chk.Visible = not chk.Visible
        if chk.Visible then task.wait(0.05); refreshList() end
    end)
    cCls.MouseButton1Click:Connect(function() chk.Visible = false end)
    sSpec.MouseButton1Click:Connect(stopSpec)

    task.spawn(function()
        while B.st.alive do
            task.wait(2)
            if chk.Visible then refreshList() end
        end
    end)
    task.spawn(function()
        while B.st.alive do
            task.wait(0.5)
            if chk.Visible then
                for _, d in pairs(B.rows) do
                    local p = d.player; local dL = d.distLbl
                    if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") and hrp and hrp.Parent then
                        dL.Text = math.floor((p.Character.HumanoidRootPart.Position - hrp.Position).Magnitude) .. "m"
                    else dL.Text = "-" end
                end
            end
        end
    end)
    task.spawn(function()
        while B.st.alive do
            task.wait(0.3)
            if B.st.stick then UI.refreshStickStatus() end
        end
    end)
    task.spawn(function()
        while B.st.alive do
            task.wait(0.5)
            if B.st.spectateOn and B.st.spectateTarget then
                if not B.st.spectateTarget.Parent or not B.st.spectateTarget.Character or not B.st.spectateTarget.Character:FindFirstChild("Head") then
                    stopSpec()
                end
            end
        end
    end)
    task.spawn(function()
        while B.st.alive do
            task.wait(1)
            if B.st.esp then
                for _, p in pairs(P:GetPlayers()) do
                    if p ~= LP and p.Character and p.Character.Parent then
                        if not (B.st.team and p.Team == LP.Team) then
                            local found = false
                            for _, o in ipairs(B.espObj) do
                                if o.player == p and o.hl and o.hl.Parent then found = true; break end
                            end
                            if not found then applyESP(p.Character, p) end
                        end
                    end
                end
            end
        end
    end)

    P.PlayerAdded:Connect(function(p)
        task.wait(0.5)
        if chk.Visible then refreshList() end
        p.CharacterAdded:Connect(function(c)
            task.wait(0.5)
            if not B.st.alive then return end
            if B.st.esp then applyESP(c, p) end
            if B.st.name then applyName(c, p.Name, p) end
        end)
    end)
    P.PlayerRemoving:Connect(function(p)
        task.wait(0.3)
        if B.st.spectateTarget == p then stopSpec() end
        if B.st.stickTarget == p then stopStick() end
        for i = #B.espObj, 1, -1 do
            if B.espObj[i].player == p then
                if B.espObj[i].hl and B.espObj[i].hl.Parent then B.espObj[i].hl:Destroy() end
                table.remove(B.espObj, i)
            end
        end
        if chk.Visible then refreshList() end
    end)
    for _, p in pairs(P:GetPlayers()) do
        if p ~= LP then
            p.CharacterAdded:Connect(function(c)
                task.wait(0.5)
                if not B.st.alive then return end
                if B.st.esp then applyESP(c, p) end
                if B.st.name then applyName(c, p.Name, p) end
            end)
        end
    end

    local function killScript()
        B.st.alive = false
        stopSpd()
        if B.conns.fly then B.conns.fly:Disconnect(); B.conns.fly=nil end
        if B.conns.stick then B.conns.stick:Disconnect(); B.conns.stick=nil end
        pcall(function() C:UnbindAction(B.STICK_ACT) end)
        stopFly(); stopStick(); stopSpec(); disableNoclip()
        if B.st.fps then B.st.fps=false; disableFPS() end
        clearESP(); clearNames()
        if hum and hum.Parent == char then
            hum.PlatformStand = false; hum.WalkSpeed = 16
            hum.JumpPower = 50; hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        if UI.gui then UI.gui:Destroy() end
    end
    killBtn.MouseButton1Click:Connect(killScript)

    LP.CharacterAdded:Connect(function(nc)
        stopSpd()
        char = nc
        hum = char:WaitForChild("Humanoid")
        hrp = char:WaitForChild("HumanoidRootPart")
        B.anim = hum:FindFirstChildOfClass("Animator")
        if not B.anim then B.anim = Instance.new("Animator"); B.anim.Parent = hum end
        B.conns.animTrack = nil
        if B.conns.bodyVel then B.conns.bodyVel:Destroy(); B.conns.bodyVel=nil end
        if B.conns.bodyGyro then B.conns.bodyGyro:Destroy(); B.conns.bodyGyro=nil end
        if B.conns.fly then B.conns.fly:Disconnect(); B.conns.fly=nil end
        task.wait(1)
        if not B.st.alive then return end
        if B.saved.speed then
            B.st.speed = true; B.st.runSpd = B.saved.speedVal
            UI.spdBox.Text = tostring(B.st.runSpd)
            UI.spdBtn.Text = "วิ่งไว: เปิด"; UI.spdBtn.BackgroundColor3 = CC.act
            hum.WalkSpeed = B.st.runSpd; startSpd()
        end
        if B.saved.fly then
            B.st.fly = true; B.st.flySpd = B.saved.flyVal
            UI.flyBox.Text = tostring(B.st.flySpd)
            UI.flyBtn.Text = "บินได้: เปิด"; UI.flyBtn.BackgroundColor3 = CC.act
            startFly()
        end
        if B.saved.esp then
            B.st.esp = true; B.st.espIdx = B.saved.espIdx or 1
            B.st.team = B.saved.team or false
            UI.espBtn.Text = "มองทะลุ: เปิด"; UI.espBtn.BackgroundColor3 = CC.act
            UI.teamBtn.Text = B.st.team and "เช็คทีม: เปิด" or "เช็คทีม: ปิด"
            UI.teamBtn.BackgroundColor3 = B.st.team and CC.act or CC.bgL
            refreshESP()
        end
        if B.saved.name then
            B.st.name = true; B.st.nameDist = B.saved.nameDist
            UI.distBox.Text = tostring(B.st.nameDist)
            UI.nameBtn.Text = "เห็นชื่อ: เปิด"; UI.nameBtn.BackgroundColor3 = CC.act
            refreshNames()
        end
        if B.saved.noclip then
            B.st.noclip = true
            UI.noclipBtn.Text = "Noclip: เปิด"; UI.noclipBtn.BackgroundColor3 = CC.act
            enableNoclip()
        end
        if B.saved.fps then
            B.st.fps = true
            UI.fpsBtn.Text = "FPS Boost: เปิด"; UI.fpsBtn.BackgroundColor3 = CC.act
            enableFPS()
        end
        if B.saved.stickDist then setStDist(B.saved.stickDist) end
        for k in pairs(B.dirs) do B.dirs[k] = false end
        if B.UI.refreshHKLabels then B.UI.refreshHKLabels() end
        if UI.refreshStickHKBtn then UI.refreshStickHKBtn() end
    end)

    print("[Boomxico V8.6] โหลดเสร็จ | Device:", dev, "| Scale:", scale)
end
