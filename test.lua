-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Stick TP V1.2 | Real Players Only + Refresh + Hotkey Toggle   ║
-- ║  - กรองเฉพาะผู้เล่นจริง (Players:GetPlayers)                    ║
-- ║  - ปุ่มรีเฟรช + auto refresh ทุก 3 วิ                          ║
-- ║  - ปุ่ม "เกาะ" toggle ได้ด้วย hotkey เดียวกัน                   ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local LP = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local function p2(...) print("[StickTP]", ...) end

-- ═══ DEVICE ═══
local DEVICE = {
    IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled,
    IsPC = UIS.KeyboardEnabled and UIS.MouseEnabled,
    IsConsole = UIS.GamepadEnabled and not UIS.KeyboardEnabled,
}

local UI_SCALE
if DEVICE.IsMobile then
    UI_SCALE = {
        MainWidth = 0.85, MainHeight = 0.6,
        FontSize = 14, SmallFontSize = 12,
        TitleHeight = 36, ButtonHeight = 34, ItemHeight = 38,
        UseScale = true,
        CollapsedWidth = 0.45, CollapsedHeight = 32, CollapsedFontSize = 12,
    }
elseif DEVICE.IsConsole then
    UI_SCALE = {
        MainWidth = 0.6, MainHeight = 0.6,
        FontSize = 16, SmallFontSize = 13,
        TitleHeight = 40, ButtonHeight = 40, ItemHeight = 42,
        UseScale = true,
        CollapsedWidth = 0.35, CollapsedHeight = 36, CollapsedFontSize = 14,
    }
else
    UI_SCALE = {
        MainWidth = 400, MainHeight = 520,
        FontSize = 13, SmallFontSize = 11,
        TitleHeight = 30, ButtonHeight = 28, ItemHeight = 30,
        UseScale = false,
        CollapsedWidth = 180, CollapsedHeight = 28, CollapsedFontSize = 11,
    }
end

-- ═══ CONFIG ═══
local CFG = {
    Enabled = false,
    Distance = 3,
    YOffset = 0,
    UpdateRate = 0,
    TargetName = nil,
    Hotkey = Enum.KeyCode.T,
    Mode = "list",
}

-- ═══ STATE ═══
local State = {
    Running = true,
    Target = nil,
    Connection = nil,
    LoopThread = nil,
    Collapsed = false,
}

-- ═══ CLEANUP ═══
pcall(function()
    for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if g.Name:find("^StickTP") then g:Destroy() end
    end
    for _, g in ipairs(LP:WaitForChild("PlayerGui"):GetChildren()) do
        if g.Name:find("^StickTP") then g:Destroy() end
    end
end)

-- ═══ UTILS ═══
local function getHRP(plr)
    if not plr or not plr.Parent then return nil end
    local char = plr.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

-- ★ หา player จาก aim
local function getPlayerFromAim()
    if not DEVICE.IsPC then return nil end
    local mouse = LP:GetMouse()
    if not mouse or not mouse.Target then return nil end

    local part = mouse.Target
    local model = part:FindFirstAncestorOfClass("Model")
    while model do
        local plr = Players:GetPlayerFromCharacter(model)
        if plr and plr ~= LP then return plr end
        model = model:FindFirstAncestorOfClass("Model")
    end
    return nil
end

local function getNearestPlayer()
    local myHRP = getHRP(LP)
    if not myHRP then return nil end
    local nearest, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local hrp = getHRP(plr)
            if hrp then
                local d = (hrp.Position - myHRP.Position).Magnitude
                if d < minDist then minDist = d; nearest = plr end
            end
        end
    end
    return nearest
end

-- ★★★ กรองเฉพาะผู้เล่นจริง (แก้ปัญหารายชื่อเกิน) ★★★
local function getAllPlayers()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        -- ต้องไม่ใช่ตัวเอง
        if plr ~= LP then
            -- ต้องมี Character และ HRP จริง
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                -- ต้องไม่ใช่ NPC/Dummy
                local humanoid = plr.Character:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    table.insert(list, plr.Name)
                end
            end
        end
    end
    table.sort(list)
    return list
end

-- ★ เกาะหลังเป้า
local function getStickCFrame()
    if not State.Target then return nil end
    local tgtHRP = getHRP(State.Target)
    if not tgtHRP then return nil end

    local lookVec = tgtHRP.CFrame.LookVector
    local stickPos = tgtHRP.Position
        - (lookVec * CFG.Distance)
        + Vector3.new(0, CFG.YOffset, 0)

    return CFrame.new(stickPos, tgtHRP.Position)
end

local function stickLoop()
    if not CFG.Enabled or not State.Running then return end
    local myHRP = getHRP(LP)
    if not myHRP then return end

    if not State.Target or not getHRP(State.Target) then
        if CFG.Mode == "aim" then
            State.Target = getPlayerFromAim() or getNearestPlayer()
        else
            State.Target = CFG.TargetName
                and Players:FindFirstChild(CFG.TargetName)
                or getNearestPlayer()
        end
    end

    if not State.Target then return end
    local cf = getStickCFrame()
    if cf then
        pcall(function() myHRP.CFrame = cf end)
    end
end

-- ═══ START/STOP ═══
local function startStick()
    if CFG.Enabled then return end
    CFG.Enabled = true

    if State.Connection then
        pcall(function() State.Connection:Disconnect() end)
        State.Connection = nil
    end
    if State.LoopThread then
        pcall(function() task.cancel(State.LoopThread) end)
        State.LoopThread = nil
    end

    if CFG.UpdateRate > 0 then
        State.LoopThread = task.spawn(function()
            while CFG.Enabled and State.Running do
                task.wait(CFG.UpdateRate)
                stickLoop()
            end
        end)
    else
        State.Connection = RunService.RenderStepped:Connect(stickLoop)
    end

    p2("✅ เริ่มเกาะ:", State.Target and State.Target.Name or "?", "ระยะ:", CFG.Distance)
end

local function stopStick()
    if not CFG.Enabled then return end
    CFG.Enabled = false
    if State.Connection then
        pcall(function() State.Connection:Disconnect() end)
        State.Connection = nil
    end
    if State.LoopThread then
        pcall(function() task.cancel(State.LoopThread) end)
        State.LoopThread = nil
    end
    p2("🛑 หยุดเกาะ")
end

local function toggleStick()
    if CFG.Enabled then stopStick() else startStick() end
end

-- ★★★ ปุ่มปิดสคริปต์ ★★★
local function shutdown()
    if not State.Running then return end
    State.Running = false

    CFG.Enabled = false
    if State.Connection then
        pcall(function() State.Connection:Disconnect() end)
        State.Connection = nil
    end
    if State.LoopThread then
        pcall(function() task.cancel(State.LoopThread) end)
        State.LoopThread = nil
    end

    if GUI and GUI.sg then
        pcall(function()
            GUI.sg.Parent = nil
            GUI.sg:Destroy()
        end)
        GUI.enabled = false
        GUI.sg = nil
    end

    if HotkeyState then HotkeyState.Waiting = false end
    State.Target = nil

    p2("✅ ปิดสคริปต์เรียบร้อย")
end

-- ═══ GUI ═══
local GUI = { enabled = false }

local function getSizes()
    if UI_SCALE.UseScale then
        return {
            Full = UDim2.new(UI_SCALE.MainWidth, 0, UI_SCALE.MainHeight, 0),
            Collapsed = UDim2.new(UI_SCALE.CollapsedWidth, 0, 0, UI_SCALE.CollapsedHeight),
            Position = UDim2.new(0.5, 0, 0.05, 0),
            AnchorPoint = Vector2.new(0.5, 0),
        }
    else
        return {
            Full = UDim2.new(0, UI_SCALE.MainWidth, 0, UI_SCALE.MainHeight),
            Collapsed = UDim2.new(0, UI_SCALE.CollapsedWidth, 0, UI_SCALE.CollapsedHeight),
            Position = UDim2.new(0, 15, 0, 15),
            AnchorPoint = Vector2.new(0, 0),
        }
    end
end

local function makeGUI()
    local ok = pcall(function()
        local sizes = getSizes()

        local sg = Instance.new("ScreenGui")
        sg.Name = "StickTPV12"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = false

        if DEVICE.IsMobile or DEVICE.IsConsole then
            sg.Parent = LP:WaitForChild("PlayerGui", 5)
        else
            pcall(function() sg.Parent = game:GetService("CoreGui") end)
            if not sg.Parent then
                sg.Parent = LP:WaitForChild("PlayerGui", 5)
            end
        end

        local f = Instance.new("Frame")
        f.Name = "Main"
        f.Size = sizes.Full
        f.Position = sizes.Position
        f.AnchorPoint = sizes.AnchorPoint
        f.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
        f.BackgroundTransparency = 0.1
        f.BorderSizePixel = 0
        f.Active = true
        f.Draggable = not DEVICE.IsMobile
        f.Parent = sg
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", f)
        stroke.Color = Color3.fromRGB(70, 110, 200)

        -- TITLE
        local title = Instance.new("Frame")
        title.Name = "TitleBar"
        title.Size = UDim2.new(1, 0, 0, UI_SCALE.TitleHeight)
        title.BackgroundColor3 = Color3.fromRGB(30, 45, 80)
        title.BorderSizePixel = 0
        title.Active = true
        title.Parent = f
        Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

        local tl = Instance.new("TextLabel")
        tl.Name = "TitleLabel"
        tl.Size = UDim2.new(1, -130, 0, UI_SCALE.TitleHeight)
        tl.Position = UDim2.new(0, 8, 0, 0)
        tl.BackgroundTransparency = 1
        tl.Text = "🎯 Stick TP v1.2"
        tl.TextColor3 = Color3.fromRGB(170, 220, 255)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = UI_SCALE.FontSize
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.Active = false
        tl.Parent = title

        local collapsedInfo = Instance.new("TextLabel")
        collapsedInfo.Name = "CollapsedInfo"
        collapsedInfo.Size = UDim2.new(0, 80, 0, UI_SCALE.TitleHeight)
        collapsedInfo.Position = UDim2.new(1, -120, 0, 0)
        collapsedInfo.BackgroundTransparency = 1
        collapsedInfo.Text = ""
        collapsedInfo.TextColor3 = Color3.fromRGB(170, 220, 255)
        collapsedInfo.Font = Enum.Font.Code
        collapsedInfo.TextSize = UI_SCALE.SmallFontSize
        collapsedInfo.TextXAlignment = Enum.TextXAlignment.Right
        collapsedInfo.Active = false
        collapsedInfo.Parent = title

        local toggleBtn = Instance.new("TextButton")
        toggleBtn.Name = "ToggleBtn"
        toggleBtn.Size = UDim2.new(0, 50, 0, UI_SCALE.TitleHeight - 8)
        toggleBtn.Position = UDim2.new(1, -124, 0, 4)
        toggleBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
        toggleBtn.BorderSizePixel = 0
        toggleBtn.Text = "OFF"
        toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleBtn.Font = Enum.Font.GothamBold
        toggleBtn.TextSize = UI_SCALE.SmallFontSize
        toggleBtn.Parent = title
        Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 4)

        local collapseBtn = Instance.new("TextButton")
        collapseBtn.Name = "CollapseBtn"
        collapseBtn.Size = UDim2.new(0, 26, 0, UI_SCALE.TitleHeight - 8)
        collapseBtn.Position = UDim2.new(1, -72, 0, 4)
        collapseBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)
        collapseBtn.BorderSizePixel = 0
        collapseBtn.Text = "▼"
        collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        collapseBtn.Font = Enum.Font.GothamBold
        collapseBtn.TextSize = UI_SCALE.SmallFontSize + 2
        collapseBtn.Parent = title
        Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 4)

        local closeBtn = Instance.new("TextButton")
        closeBtn.Name = "CloseBtn"
        closeBtn.Size = UDim2.new(0, 26, 0, UI_SCALE.TitleHeight - 8)
        closeBtn.Position = UDim2.new(1, -42, 0, 4)
        closeBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
        closeBtn.BorderSizePixel = 0
        closeBtn.Text = "×"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = UI_SCALE.SmallFontSize + 4
        closeBtn.Parent = title
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

        -- BODY
        local body = Instance.new("Frame")
        body.Name = "Body"
        body.Size = UDim2.new(1, 0, 1, -UI_SCALE.TitleHeight)
        body.Position = UDim2.new(0, 0, 0, UI_SCALE.TitleHeight)
        body.BackgroundTransparency = 1
        body.Active = false
        body.Parent = f

        local status = Instance.new("TextLabel")
        status.Name = "Status"
        status.Size = UDim2.new(1, -20, 0, 16)
        status.Position = UDim2.new(0, 10, 0, 4)
        status.BackgroundTransparency = 1
        status.Text = "● ว่าง"
        status.TextColor3 = Color3.fromRGB(200, 200, 200)
        status.Font = Enum.Font.Code
        status.TextSize = UI_SCALE.SmallFontSize
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Active = false
        status.Parent = body

        local targetLabel = Instance.new("TextLabel")
        targetLabel.Name = "TargetLabel"
        targetLabel.Size = UDim2.new(1, -20, 0, 16)
        targetLabel.Position = UDim2.new(0, 10, 0, 22)
        targetLabel.BackgroundTransparency = 1
        targetLabel.Text = "🎯 เป้า: -"
        targetLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
        targetLabel.Font = Enum.Font.Code
        targetLabel.TextSize = UI_SCALE.SmallFontSize
        targetLabel.TextXAlignment = Enum.TextXAlignment.Left
        targetLabel.Active = false
        targetLabel.Parent = body

        -- SLIDER
        local distLabel = Instance.new("TextLabel")
        distLabel.Size = UDim2.new(1, -20, 0, 16)
        distLabel.Position = UDim2.new(0, 10, 0, 44)
        distLabel.BackgroundTransparency = 1
        distLabel.Text = "📏 ระยะเกาะ: 3.0 studs"
        distLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
        distLabel.Font = Enum.Font.GothamBold
        distLabel.TextSize = UI_SCALE.SmallFontSize
        distLabel.TextXAlignment = Enum.TextXAlignment.Left
        distLabel.Active = false
        distLabel.Parent = body

        local sliderBg = Instance.new("Frame")
        sliderBg.Name = "SliderBg"
        sliderBg.Size = UDim2.new(1, -20, 0, 10)
        sliderBg.Position = UDim2.new(0, 10, 0, 64)
        sliderBg.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
        sliderBg.BorderSizePixel = 0
        sliderBg.Active = true
        sliderBg.Parent = body
        Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 5)

        local sliderFill = Instance.new("Frame")
        sliderFill.Name = "Fill"
        sliderFill.Size = UDim2.new(0.069, 0, 1, 0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(80, 140, 220)
        sliderFill.BorderSizePixel = 0
        sliderFill.Parent = sliderBg
        Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 5)

        local sliderKnob = Instance.new("TextButton")
        sliderKnob.Name = "Knob"
        sliderKnob.Size = UDim2.new(0, 20, 0, 20)
        sliderKnob.Position = UDim2.new(0.069, -10, 0.5, -10)
        sliderKnob.BackgroundColor3 = Color3.fromRGB(170, 220, 255)
        sliderKnob.BorderSizePixel = 0
        sliderKnob.Text = ""
        sliderKnob.Parent = sliderBg
        Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

        local DIST_MIN, DIST_MAX = 1, 30
        local dragging = false

        local function updateSliderFromX(x)
            local rel = math.clamp(
                (x - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X,
                0, 1)
            local val = DIST_MIN + (DIST_MAX - DIST_MIN) * rel
            CFG.Distance = math.floor(val * 10) / 10
            sliderFill.Size = UDim2.new(rel, 0, 1, 0)
            sliderKnob.Position = UDim2.new(rel, -10, 0.5, -10)
            distLabel.Text = string.format("📏 ระยะเกาะ: %.1f studs", CFG.Distance)
        end

        sliderKnob.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)
        sliderBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                updateSliderFromX(input.Position.X)
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then
                updateSliderFromX(input.Position.X)
            end
        end)
        UIS.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)

        -- ★ ROW: HOTKEY + REFRESH ★
        local rowY = 84
        local rowH = UI_SCALE.ButtonHeight

        local hotkeyBtn = Instance.new("TextButton")
        hotkeyBtn.Name = "HotkeyBtn"
        hotkeyBtn.Size = UDim2.new(1, -90, 0, rowH)
        hotkeyBtn.Position = UDim2.new(0, 10, 0, rowY)
        hotkeyBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
        hotkeyBtn.BorderSizePixel = 0
        hotkeyBtn.Text = "⌨️ Hotkey: T"
        hotkeyBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
        hotkeyBtn.Font = Enum.Font.GothamBold
        hotkeyBtn.TextSize = UI_SCALE.SmallFontSize
        hotkeyBtn.Parent = body
        Instance.new("UICorner", hotkeyBtn).CornerRadius = UDim.new(0, 4)

        -- ★ ปุ่มรีเฟรช
        local refreshBtn = Instance.new("TextButton")
        refreshBtn.Name = "RefreshBtn"
        refreshBtn.Size = UDim2.new(0, 70, 0, rowH)
        refreshBtn.Position = UDim2.new(1, -80, 0, rowY)
        refreshBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
        refreshBtn.BorderSizePixel = 0
        refreshBtn.Text = "🔄 รีเฟรช"
        refreshBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
        refreshBtn.Font = Enum.Font.GothamBold
        refreshBtn.TextSize = UI_SCALE.SmallFontSize
        refreshBtn.Parent = body
        Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 4)

        -- LIST TITLE
        local listTitle = Instance.new("TextLabel")
        listTitle.Size = UDim2.new(1, -20, 0, 16)
        listTitle.Position = UDim2.new(0, 10, 0, rowY + rowH + 6)
        listTitle.BackgroundTransparency = 1
        listTitle.Text = "👥 เลือกเป้า (คลิกเกาะ)"
        listTitle.TextColor3 = Color3.fromRGB(170, 220, 255)
        listTitle.Font = Enum.Font.GothamBold
        listTitle.TextSize = UI_SCALE.SmallFontSize
        listTitle.TextXAlignment = Enum.TextXAlignment.Left
        listTitle.Active = false
        listTitle.Parent = body

        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Name = "ListFrame"
        local listY = rowY + rowH + 24
        listFrame.Size = UDim2.new(1, -20, 1, -(listY + 10))
        listFrame.Position = UDim2.new(0, 10, 0, listY)
        listFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        listFrame.BackgroundTransparency = 0.35
        listFrame.BorderSizePixel = 0
        listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        listFrame.ScrollBarThickness = 6
        listFrame.Active = true
        listFrame.Parent = body
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)

        local layout = Instance.new("UIListLayout", listFrame)
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = listFrame

        -- ═══ ★ สร้างรายชื่อ ★ ═══
        local function refreshList()
            pcall(function()
                for _, c in ipairs(listFrame:GetChildren()) do
                    if c:IsA("Frame") then c:Destroy() end
                end

                local players = getAllPlayers()
                if #players == 0 then
                    local empty = Instance.new("TextLabel")
                    empty.Size = UDim2.new(1, 0, 0, 30)
                    empty.BackgroundTransparency = 1
                    empty.Text = "(ไม่มีผู้เล่นอื่น)"
                    empty.TextColor3 = Color3.fromRGB(180, 180, 180)
                    empty.Font = Enum.Font.Gotham
                    empty.TextSize = UI_SCALE.SmallFontSize
                    empty.Parent = listFrame
                end

                for i, pname in ipairs(players) do
                    local row = Instance.new("Frame")
                    row.Size = UDim2.new(1, -4, 0, UI_SCALE.ItemHeight)
                    row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                    row.BackgroundTransparency = 0.5
                    row.BorderSizePixel = 0
                    row.Parent = listFrame
                    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

                    local nl = Instance.new("TextLabel")
                    nl.Size = UDim2.new(1, -80, 1, 0)
                    nl.Position = UDim2.new(0, 8, 0, 0)
                    nl.BackgroundTransparency = 1
                    nl.Text = string.format("%d. %s", i, pname)
                    nl.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nl.Font = Enum.Font.GothamBold
                    nl.TextSize = UI_SCALE.FontSize
                    nl.TextXAlignment = Enum.TextXAlignment.Left
                    nl.TextTruncate = Enum.TextTruncate.AtEnd
                    nl.TextStrokeTransparency = 0.5
                    nl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    nl.Active = false
                    nl.Parent = row

                    local isTarget = (pname == CFG.TargetName and CFG.Enabled)
                    local stickBtn = Instance.new("TextButton")
                    stickBtn.Name = "StickBtn_" .. pname
                    stickBtn.Size = UDim2.new(0, 60, 1, -4)
                    stickBtn.Position = UDim2.new(1, -64, 0, 2)
                    stickBtn.BackgroundColor3 = isTarget
                        and Color3.fromRGB(60, 160, 90)
                        or Color3.fromRGB(60, 90, 160)
                    stickBtn.BorderSizePixel = 0
                    stickBtn.Text = isTarget and "หยุด" or "เกาะ"
                    stickBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    stickBtn.Font = Enum.Font.GothamBold
                    stickBtn.TextSize = UI_SCALE.SmallFontSize
                    stickBtn.Parent = row
                    Instance.new("UICorner", stickBtn).CornerRadius = UDim.new(0, 4)

                    -- ★★★ คลิก = toggle ★★★
                    stickBtn.MouseButton1Click:Connect(function()
                        if not State.Running then return end

                        -- ถ้าเกาะคนนี้อยู่แล้ว → หยุด
                        if CFG.Enabled and CFG.TargetName == pname then
                            stopStick()
                            p2("🛑 หยุดเกาะ:", pname)
                            updateToggleBtn()
                            updateStatus()
                            refreshList()
                            return
                        end

                        -- ถ้าไม่ได้เกาะคนนี้ → เกาะ (สลับเป้าถ้าจำเป็น)
                        local plr = Players:FindFirstChild(pname)
                        if not plr then return end

                        CFG.TargetName = pname
                        CFG.Mode = "list"
                        State.Target = plr

                        if not CFG.Enabled then
                            startStick()
                            p2("▶️ เกาะ:", pname)
                        else
                            p2("🔄 เปลี่ยนเป้า:", pname)
                        end

                        updateToggleBtn()
                        updateStatus()
                        refreshList()
                    end)

                    stickBtn.MouseEnter:Connect(function()
                        if not State.Running then return end
                        local t = (CFG.Enabled and CFG.TargetName == pname)
                        stickBtn.BackgroundColor3 = t
                            and Color3.fromRGB(80, 180, 110)
                            or Color3.fromRGB(80, 130, 210)
                    end)
                    stickBtn.MouseLeave:Connect(function()
                        local t = (CFG.Enabled and CFG.TargetName == pname)
                        stickBtn.BackgroundColor3 = t
                            and Color3.fromRGB(60, 160, 90)
                            or Color3.fromRGB(60, 90, 160)
                    end)
                end

                listFrame.CanvasSize = UDim2.new(0, 0, 0,
                    layout.AbsoluteContentSize.Y + 8)
            end)
        end

        -- Auto refresh
        task.spawn(function()
            while State.Running do
                task.wait(3)
                if listFrame.Parent and not State.Collapsed then
                    refreshList()
                end
            end
        end)

        GUI.sg = sg
        GUI.frame = f
        GUI.titleBar = title
        GUI.titleLabel = tl
        GUI.body = body
        GUI.status = status
        GUI.targetLabel = targetLabel
        GUI.distLabel = distLabel
        GUI.hotkeyBtn = hotkeyBtn
        GUI.refreshBtn = refreshBtn
        GUI.listFrame = listFrame
        GUI.toggleBtn = toggleBtn
        GUI.collapseBtn = collapseBtn
        GUI.closeBtn = closeBtn
        GUI.collapsedInfo = collapsedInfo
        GUI.refreshList = refreshList
        GUI.enabled = true

        refreshList()
    end)
    if not ok then GUI.enabled = false end
end

-- ═══ UPDATE ═══
local function updateStatus()
    if not GUI.enabled or not State.Running then return end
    pcall(function()
        if CFG.Enabled then
            GUI.status.Text = "● กำลังเกาะ"
            GUI.status.TextColor3 = Color3.fromRGB(100, 255, 120)
        else
            GUI.status.Text = "● ว่าง"
            GUI.status.TextColor3 = Color3.fromRGB(200, 200, 200)
        end

        if State.Target then
            GUI.targetLabel.Text = "🎯 เป้า: " .. State.Target.Name
                .. " (" .. CFG.Mode .. ")"
        else
            GUI.targetLabel.Text = "🎯 เป้า: -"
        end

        if State.Collapsed then
            GUI.collapsedInfo.Text = CFG.Enabled and "ON" or "OFF"
            GUI.collapsedInfo.TextColor3 = CFG.Enabled
                and Color3.fromRGB(100, 255, 120)
                or Color3.fromRGB(200, 200, 200)
        else
            GUI.collapsedInfo.Text = ""
        end
    end)
end

local function updateToggleBtn()
    if not GUI.enabled or not State.Running then return end
    if CFG.Enabled then
        GUI.toggleBtn.Text = "ON"
        GUI.toggleBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
    else
        GUI.toggleBtn.Text = "OFF"
        GUI.toggleBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
    end
end

local function toggleCollapse()
    if not GUI.enabled or not State.Running then return end
    State.Collapsed = not State.Collapsed
    local sizes = getSizes()

    if State.Collapsed then
        GUI.frame.Size = sizes.Collapsed
        GUI.frame.Position = UDim2.new(0, 10, 0, 10)
        GUI.frame.AnchorPoint = Vector2.new(0, 0)
        GUI.body.Visible = false

        GUI.titleBar.Size = UDim2.new(1, 0, 0, UI_SCALE.CollapsedHeight)
        GUI.titleBar.BackgroundColor3 = Color3.fromRGB(25, 35, 60)
        GUI.titleLabel.TextSize = UI_SCALE.CollapsedFontSize
        GUI.titleLabel.Text = "🎯 Stick"

        GUI.collapseBtn.Text = "▲"
        GUI.collapseBtn.Size = UDim2.new(0, 22, 0, UI_SCALE.CollapsedHeight - 6)
        GUI.collapseBtn.Position = UDim2.new(1, -26, 0, 3)
        GUI.collapseBtn.BackgroundColor3 = Color3.fromRGB(70, 90, 120)

        GUI.toggleBtn.Visible = false
        GUI.closeBtn.Visible = false
        updateStatus()
    else
        GUI.frame.Size = sizes.Full
        GUI.frame.Position = sizes.Position
        GUI.frame.AnchorPoint = sizes.AnchorPoint

        GUI.titleBar.Size = UDim2.new(1, 0, 0, UI_SCALE.TitleHeight)
        GUI.titleBar.BackgroundColor3 = Color3.fromRGB(30, 45, 80)
        GUI.body.Visible = true

        GUI.titleLabel.TextSize = UI_SCALE.FontSize
        GUI.titleLabel.Text = "🎯 Stick TP v1.2"

        GUI.collapseBtn.Text = "▼"
        GUI.collapseBtn.Size = UDim2.new(0, 26, 0, UI_SCALE.TitleHeight - 8)
        GUI.collapseBtn.Position = UDim2.new(1, -72, 0, 4)
        GUI.collapseBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)

        GUI.toggleBtn.Visible = true
        GUI.closeBtn.Visible = true
        GUI.collapsedInfo.Text = ""
    end
end

makeGUI()

-- ═══ HOTKEY ═══
local HotkeyState = { Waiting = false }

local function updateHotkeyBtn()
    if GUI.enabled and GUI.hotkeyBtn and State.Running then
        if HotkeyState.Waiting then
            GUI.hotkeyBtn.Text = "⌨️ กดปุ่ม..."
            GUI.hotkeyBtn.BackgroundColor3 = Color3.fromRGB(160, 100, 40)
        else
            GUI.hotkeyBtn.Text = "⌨️ Hotkey: " .. CFG.Hotkey.Name
            GUI.hotkeyBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
        end
    end
end

local function startHotkeyWait()
    if not State.Running then return end
    HotkeyState.Waiting = true
    updateHotkeyBtn()
    p2("⌨️ รอปุ่ม hotkey...")
end

UIS.InputBegan:Connect(function(input, processed)
    if not State.Running then return end

    -- โหมดรอ hotkey
    if HotkeyState.Waiting then
        if input.KeyCode == Enum.KeyCode.Escape then
            HotkeyState.Waiting = false
            updateHotkeyBtn()
            p2("❌ ยกเลิก")
            return
        end
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            CFG.Hotkey = input.KeyCode
            HotkeyState.Waiting = false
            updateHotkeyBtn()
            p2("✅ ตั้ง hotkey:", CFG.Hotkey.Name)
            return
        end
        return
    end

    if processed then return end

    -- ★★★ HOTKEY = เกาะคนที่เล็ง / ถ้าเกาะอยู่แล้ว → หยุด ★★★
    if input.KeyCode == CFG.Hotkey then
        -- ถ้ากำลังเกาะอยู่ → หยุด
        if CFG.Enabled then
            stopStick()
            p2("🛑 หยุดเกาะ (hotkey)")
            updateToggleBtn()
            updateStatus()
            if GUI.enabled and GUI.refreshList then GUI.refreshList() end
            return
        end

        -- ถ้ายังไม่เกาะ → เกาะคนที่เล็ง
        local aimPlr = getPlayerFromAim()
        if aimPlr then
            CFG.Mode = "aim"
            CFG.TargetName = aimPlr.Name
            State.Target = aimPlr
            startStick()
            p2("▶️ เกาะ (aim):", aimPlr.Name)
            updateToggleBtn()
            updateStatus()
            if GUI.enabled and GUI.refreshList then GUI.refreshList() end
        else
            p2("ℹ️ ไม่พบเป้าเล็ง")
        end
    end
end)

-- ═══ BIND ═══
if GUI.enabled then
    GUI.toggleBtn.MouseButton1Click:Connect(function()
        if not State.Running then return end
        toggleStick()
        updateToggleBtn()
        updateStatus()
        if GUI.refreshList then GUI.refreshList() end
    end)

    GUI.collapseBtn.MouseButton1Click:Connect(toggleCollapse)
    GUI.hotkeyBtn.MouseButton1Click:Connect(startHotkeyWait)

    -- ★ ปุ่มรีเฟรช
    GUI.refreshBtn.MouseButton1Click:Connect(function()
        if not State.Running then return end
        if GUI.refreshList then GUI.refreshList() end
        GUI.refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 100)
        task.wait(0.15)
        if GUI.enabled then
            GUI.refreshBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
        end
        p2("🔄 รีเฟรชรายชื่อ")
    end)

    GUI.closeBtn.MouseButton1Click:Connect(shutdown)
end

-- ═══ LOOP ═══
task.spawn(function()
    while State.Running do
        task.wait(0.3)
        if not State.Running then break end
        updateStatus()

        if GUI.enabled then
            local want = CFG.Enabled and "ON" or "OFF"
            if GUI.toggleBtn.Text ~= want then
                updateToggleBtn()
            end
        end
    end
    p2("🔚 Loop จบ")
end)

-- ═══ START ═══
p2("═══════════════════════════════════════════")
p2("Stick TP v1.2")
p2("อุปกรณ์: " .. (DEVICE.IsMobile and "📱 Mobile"
    or DEVICE.IsConsole and "🎮 Console"
    or "💻 PC"))
p2("")
p2("🎯 HOTKEY = เกาะคนที่เล็ง / กดซ้ำ = หยุด")
p2("👥 รายชื่อ = คลิกเกาะ (คลิกซ้ำ = หยุด)")
p2("🔄 ปุ่มรีเฟรช + auto ทุก 3 วิ")
p2("═══════════════════════════════════════════")
