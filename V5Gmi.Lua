-- ===================== ปุ่ม Keybind ที่เหลือ =====================
local noclipKeyBtn, noclipModeBtn = createKeybindRow(0.52, "Noclip", "Noclip")

local kbClose = Instance.new("TextButton")
kbClose.Size = UDim2.new(0.9, 0, 0, 30)
kbClose.Position = UDim2.new(0.05, 0, 0.82, 0)
kbClose.BackgroundColor3 = COLOR_CARD
kbClose.BackgroundTransparency = 0.15
kbClose.Text = "Fold"
kbClose.TextColor3 = COLOR_TEXT
kbClose.Font = Enum.Font.GothamMedium
kbClose.TextSize = 11
kbClose.Parent = keybindFrame
Instance.new("UICorner", kbClose).CornerRadius = UDim.new(0, 8)
applyStroke(kbClose, COLOR_BORDER_DIM, 1, 0.5)

kbClose.MouseButton1Click:Connect(function()
    keybindFrame.Visible = false
    updateToggleUI(keybindMenuBtn, false)
end)

keybindMenuBtn.MouseButton1Click:Connect(function()
    keybindFrame.Visible = not keybindFrame.Visible
    updateToggleUI(keybindMenuBtn, keybindFrame.Visible)
end)

-- ====================================================
-- 🔴 FLY SYSTEM (เวอร์ชันสมบูรณ์)
-- ====================================================
local flyConn = nil

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
    bodyGyro.CFrame = workspace.CurrentCamera.CFrame
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
    updateToggleUI(flyBtn, false, "บินได้")
end

local function startFly()
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

        local cam = workspace.CurrentCamera
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

-- ====================================================
-- 🔴 ผูก Logic ปุ่มทั้งหมด
-- ====================================================

-- Speed
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
        runSpeed = clamp(v, 1, MAX_SPEED)
        spdBox.Text = tostring(runSpeed)
        if speedEnabled and humanoid then humanoid.WalkSpeed = runSpeed end
    else
        spdBox.Text = tostring(runSpeed)
    end
end)

-- Fly
flyBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    if flyEnabled then
        stopFly()
    else
        startFly()
        updateToggleUI(flyBtn, true, "บินได้")
    end
end)
flyBox.FocusLost:Connect(function()
    local v = tonumber(flyBox.Text)
    if v then
        flySpeed = clamp(v, 1, MAX_FLY)
        flyBox.Text = tostring(flySpeed)
    else
        flyBox.Text = tostring(flySpeed)
    end
end)

-- Noclip
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

-- Infinite Jump
infJumpBtn.MouseButton1Click:Connect(function()
    if not canToggle() then return end
    infJumpEnabled = not infJumpEnabled
    updateToggleUI(infJumpBtn, infJumpEnabled)
end)
addConn(UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled and humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

-- Fullbright
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

-- No Fog
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

-- ESP
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

-- Name Tags
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

distBox.FocusLost:Connect(function()
    local v = tonumber(distBox.Text)
    if v then
        NAME_MAX_DIST = clamp(v, 50, 5000)
        distBox.Text = tostring(NAME_MAX_DIST)
    else
        distBox.Text = tostring(NAME_MAX_DIST)
    end
end)

-- Player Events
addConn(Players.PlayerAdded:Connect(function(p)
    if espEnabled then createESP(p) end
    if nameEnabled then createNameTag(p) end
end))

addConn(Players.PlayerRemoving:Connect(function(p)
    removeESP(p)
    removeNameTag(p)
end))

-- ====================================================
-- 🔴 Player List / Spectate / Attach
-- ====================================================
local function stopSpectate()
    spectateEnabled = false
    spectateTarget = nil
    if humanoid then
        workspace.CurrentCamera.CameraSubject = humanoid
    end
end

local function stopAttach()
    attachEnabled = false
    attachTarget = nil
    aStatusLbl.Text = "สถานะ: ยังไม่ได้เกาะ"
    aStatusLbl.TextColor3 = COLOR_TEXT
end

local function startAttach(targetP)
    if targetP and targetP.Character and targetP.Character:FindFirstChild("HumanoidRootPart") then
        attachTarget = targetP
        attachEnabled = true
        aStatusLbl.Text = "กำลังเกาะ: " .. targetP.DisplayName
        aStatusLbl.TextColor3 = COLOR_ACCENT
    end
end

stopSpecBtn.MouseButton1Click:Connect(stopSpectate)
stopAttachBtn.MouseButton1Click:Connect(stopAttach)
aStopBtn.MouseButton1Click:Connect(stopAttach)

local function updatePlayerList()
    for _, item in pairs(playerRows) do safeDestroy(item) end
    playerRows = {}

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, 0, 0, 36)
            card.BackgroundColor3 = COLOR_CARD
            card.BackgroundTransparency = 0.2
            card.Parent = scroll
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
            applyStroke(card, COLOR_BORDER_DIM, 1, 0.6)

            local pLbl = Instance.new("TextLabel")
            pLbl.Size = UDim2.new(0.48, 0, 1, 0)
            pLbl.Position = UDim2.new(0, 8, 0, 0)
            pLbl.BackgroundTransparency = 1
            pLbl.Text = p.DisplayName
            pLbl.TextColor3 = COLOR_TEXT
            pLbl.Font = Enum.Font.GothamMedium
            pLbl.TextSize = 11
            pLbl.TextXAlignment = Enum.TextXAlignment.Left
            pLbl.TextTruncate = Enum.TextTruncate.AtEnd
            pLbl.Parent = card

            local specBtn = Instance.new("TextButton")
            specBtn.Size = UDim2.new(0.22, 0, 0, 22)
            specBtn.Position = UDim2.new(0.50, 0, 0.5, -11)
            specBtn.BackgroundColor3 = COLOR_OFF
            specBtn.Text = "ส่อง"
            specBtn.TextColor3 = COLOR_ACCENT
            specBtn.Font = Enum.Font.GothamBold
            specBtn.TextSize = 10
            specBtn.Parent = card
            Instance.new("UICorner", specBtn).CornerRadius = UDim.new(0, 5)

            local attBtn = Instance.new("TextButton")
            attBtn.Size = UDim2.new(0.24, 0, 0, 22)
            attBtn.Position = UDim2.new(0.74, 0, 0.5, -11)
            attBtn.BackgroundColor3 = COLOR_OFF
            attBtn.Text = "เกาะ"
            attBtn.TextColor3 = COLOR_ACCENT
            attBtn.Font = Enum.Font.GothamBold
            attBtn.TextSize = 10
            attBtn.Parent = card
            Instance.new("UICorner", attBtn).CornerRadius = UDim.new(0, 5)

            specBtn.MouseButton1Click:Connect(function()
                if p.Character and p.Character:FindFirstChild("Humanoid") then
                    spectateTarget = p
                    spectateEnabled = true
                    workspace.CurrentCamera.CameraSubject = p.Character.Humanoid
                end
            end)

            attBtn.MouseButton1Click:Connect(function() startAttach(p) end)

            table.insert(playerRows, card)
        end
    end
end

refreshListBtn.MouseButton1Click:Connect(updatePlayerList)
checkBtn.MouseButton1Click:Connect(function()
    checkMenu.Visible = not checkMenu.Visible
    if checkMenu.Visible then updatePlayerList() end
end)
cCloseBtn.MouseButton1Click:Connect(function() checkMenu.Visible = false end)

toggleBtn.MouseButton1Click:Connect(function()
    main.Visible = not main.Visible
end)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
end)

-- ====================================================
-- 🔴 Render Loop (NameTag / Attach / Camera Guard)
-- ====================================================
addConn(RunService.RenderStepped:Connect(function()
    if not scriptAlive then return end

    if nameEnabled and rootPart then
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
    end

    if spectateEnabled then
        if not spectateTarget or not spectateTarget.Parent
            or not spectateTarget.Character
            or not spectateTarget.Character:FindFirstChild("Humanoid") then
            stopSpectate()
        end
    end

    if attachEnabled and attachTarget and attachTarget.Character
        and attachTarget.Character:FindFirstChild("HumanoidRootPart")
        and rootPart then
        local tRoot = attachTarget.Character.HumanoidRootPart
        applyAntiDeact(character)
        rootPart.CFrame = tRoot.CFrame * CFrame.new(0, 0, attachDistance)
        sanitizePhysics(rootPart)
    end
end))

-- ====================================================
-- 🔴 Keybinds (PC)
-- ====================================================
addConn(UserInputService.InputBegan:Connect(function(input, gpe)
    if waitingForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            keybinds[waitingForKey].key = input.KeyCode
            local keyStr = keyToString(input.KeyCode)
            if waitingForKey == "Speed" then
                speedKeyBtn.Text = keyStr
                speedKeyBtn.TextColor3 = COLOR_ACCENT
            elseif waitingForKey == "Fly" then
                flyKeyBtn.Text = keyStr
                flyKeyBtn.TextColor3 = COLOR_ACCENT
            elseif waitingForKey == "Noclip" then
                noclipKeyBtn.Text = keyStr
                noclipKeyBtn.TextColor3 = COLOR_ACCENT
            end
            waitingForKey = nil
        end
        return
    end

    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

    local k = input.KeyCode
    if k == Enum.KeyCode.W then pcKeys.W = true end
    if k == Enum.KeyCode.S then pcKeys.S = true end
    if k == Enum.KeyCode.A then pcKeys.A = true end
    if k == Enum.KeyCode.D then pcKeys.D = true end
    if k == Enum.KeyCode.Space then pcKeys.Space = true end
    if k == Enum.KeyCode.LeftShift then pcKeys.Shift = true end

    for feat, data in pairs(keybinds) do
        if data.key ~= Enum.KeyCode.Unknown and k == data.key then
            if feat == "Speed" then
                if data.mode == "Toggle" then
                    speedEnabled = not speedEnabled
                else
                    speedEnabled = true
                end
                updateToggleUI(spdBtn, speedEnabled, "วิ่งไว")
                if humanoid then humanoid.WalkSpeed = speedEnabled and runSpeed or 16 end
            elseif feat == "Fly" then
                if data.mode == "Toggle" then
                    if flyEnabled then stopFly() else startFly() updateToggleUI(flyBtn, true, "บินได้") end
                else
                    startFly()
                    updateToggleUI(flyBtn, true, "บินได้")
                end
            elseif feat == "Noclip" then
                if data.mode == "Toggle" then
                    noclipEnabled = not noclipEnabled
                else
                    noclipEnabled = true
                end
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
            end
        end
    end
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

    for feat, data in pairs(keybinds) do
        if data.key ~= Enum.KeyCode.Unknown and k == data.key and data.mode == "Hold" then
            if feat == "Speed" then
                speedEnabled = false
                updateToggleUI(spdBtn, false, "วิ่งไว")
                if humanoid then humanoid.WalkSpeed = 16 end
            elseif feat == "Fly" then
                stopFly()
            elseif feat == "Noclip" then
                noclipEnabled = false
                updateToggleUI(noclipBtn, false)
                if noclipConn then noclipConn:Disconnect() noclipConn = nil end
            end
        end
    end
end))

-- ====================================================
-- 🔴 Respawn
-- ====================================================
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

-- ====================================================
-- 🔴 ปุ่ม Close Script
-- ====================================================
killBtn.MouseButton1Click:Connect(function()
    scriptAlive = false
    stopFly()
    if noclipConn then noclipConn:Disconnect() end
    stopSpectate()
    stopAttach()
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
