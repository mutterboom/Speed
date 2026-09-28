-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Item ESP + Teleport V1.8 | Multi-Device                       ║
-- ║  - Auto-Detect: PC / iOS / Android / Tablet / Console          ║
-- ║  - Auto UI Scale ตามขนาดจอ                                    ║
-- ║  - Safe Zone (notch/dynamic island)                            ║
-- ║  - Rotate Screen Detection (Mobile)                            ║
-- ║  - ESP สีเหลือง ไม่มีกรอบ ไม่มีระยะ                            ║
-- ║  - ปุ่ม ✕ หยุดสคริปต์ทั้งหมด                                    ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer
local CAM = workspace.CurrentCamera

local function p2(...) print("[ItemESP]", ...) end

-- ═══════════════════════════════════════════
-- DEVICE DETECTION (ละเอียด)
-- ═══════════════════════════════════════════
local uis = UIS

local isTouch = uis.TouchEnabled
local isKeyboard = uis.KeyboardEnabled
local isMouse = uis.MouseEnabled
local isGamepad = uis.GamepadEnabled
local isTenFoot = uis:IsTenFootInterface()

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

-- ขนาดจอ
local vp = CAM.ViewportSize
local screenX = vp.X
local screenY = vp.Y
local minSide = math.min(screenX, screenY)

-- แยก iOS / Android (heuristic)
local isIOS = false
local isAndroid = false
if platform == "Mobile" then
    local aspect = screenX / screenY
    -- iPad aspect ~1.33, iPhone ~0.46-0.56 (portrait), Android หลากหลาย
    -- ใช้ขนาด + aspect ในการแยก
    isIOS = (aspect > 0.70 and aspect < 0.80) or
            (aspect > 1.30 and aspect < 1.40) or
            (aspect > 0.45 and aspect < 0.50 and minSide > 350)
    isAndroid = not isIOS
end

-- ═══════════════════════════════════════════
-- AUTO UI SCALE
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
    if isIOS then deviceType = deviceType .. " (iOS)"
    elseif isAndroid then deviceType = deviceType .. " (Android)" end
else
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

-- Safe zone (GuiInset)
local topInset, bottomInset = GuiService:GetGuiInset()
local safeTop = topInset
local safeBottom = bottomInset
local safeLeft = 0
local safeRight = 0

-- บน Mobile ให้ margin เพิ่มจาก notch
if touchMode then
    safeLeft = math.max(20, screenX * 0.02)
    safeRight = math.max(20, screenX * 0.02)
    safeTop = math.max(topInset, screenY * 0.03)
    safeBottom = math.max(bottomInset, screenY * 0.03)
end

local function S(px) return math.floor(px * uiScale) end

p2("═══════════════════════════════════════")
p2("Device:", deviceType)
p2("Platform:", platform)
p2("UI Scale:", uiScale)
p2("Screen:", screenX, "x", screenY)
p2("Safe: T=" .. topInset .. " B=" .. bottomInset)
p2("Touch Mode:", touchMode)
p2("═══════════════════════════════════════")

-- ═══════════════════════════════════════════
-- UI SIZES
-- ═══════════════════════════════════════════
local UI_SIZES = {
    MainWidth  = touchMode and S(300) or S(400),
    MainHeight = touchMode and S(400) or S(500),
    FontSize   = touchMode and S(13) or S(12),
    SmallFontSize = touchMode and S(11) or S(10),
    TitleHeight = touchMode and S(38) or S(30),
    ButtonHeight = touchMode and S(40) or S(28),
    ItemHeight = touchMode and S(38) or S(28),
    CollapsedWidth = touchMode and S(160) or S(180),
    CollapsedHeight = touchMode and S(32) or S(28),
    ScrollThickness = touchMode and 10 or 6,
}

-- ═══════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════
local CFG = {
    ContainerPath = "Workspace.Items",
    UsePatterns = false,
    Patterns = { "coin","gem","chest","item","drop","pickup",
                 "orb","shard","token","reward","loot",
                 "fruit","crystal","scroll","key","star",
                 "gun","sniper","sword","weapon","tool" },
    ESPEnabled = true,
    ESPColor = Color3.fromRGB(255, 220, 100),
    ESPTransparency = 0.5,
    ShowDistance = false,
    MaxESPDistance = 5000,
    ScanInterval = 0.5,
    TeleportOffset = 3,
    ScanDescendants = true,
    IgnoreEffects = true,
    MaxItems = 300,
}

local State = {
    Running = true,
    Items = {},
    SortedList = {},
    LastGUIRefresh = 0,
    TeleportCount = 0,
    Collapsed = false,
}

-- ═══ CLEANUP ═══
pcall(function()
    for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if g.Name:find("^ItemESP") or g.Name:find("^AutoCollect") then
            g:Destroy()
        end
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "AC_ESP" or obj.Name == "AC_Label" then
            obj:Destroy()
        end
    end
end)

-- ═══ UTILS ═══
local function getHRP()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getContainer()
    local parts = {}
    for p in CFG.ContainerPath:gmatch("[^%.]+") do
        table.insert(parts, p)
    end
    local obj = game
    for _, p in ipairs(parts) do
        obj = obj:FindFirstChild(p)
        if not obj then return nil end
    end
    return obj
end

local function matchPattern(name)
    if not CFG.UsePatterns then return true end
    local lname = name:lower()
    for _, p in ipairs(CFG.Patterns) do
        if lname:find(p, 1, true) then return true end
    end
    return false
end

local function getItemPosition(item)
    if item:IsA("BasePart") then return item.Position end
    if item.PrimaryPart then return item.PrimaryPart.Position end
    local parts = {}
    for _, d in ipairs(item:GetDescendants()) do
        if d:IsA("BasePart") then table.insert(parts, d) end
    end
    if #parts == 0 then return nil end
    local sum = Vector3.new(0, 0, 0)
    for _, p in ipairs(parts) do sum = sum + p.Position end
    return sum / #parts
end

local function getItemPart(item)
    if item:IsA("BasePart") then return item end
    return item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart", true)
end

local function getDistanceTo(item)
    local hrp = getHRP()
    if not hrp then return nil end
    local pos = getItemPosition(item)
    if not pos then return nil end
    return (pos - hrp.Position).Magnitude
end

local function isRealItem(item)
    if CFG.IgnoreEffects then
        if item:IsA("Sound") or item:IsA("ParticleEmitter")
            or item:IsA("Attachment") or item:IsA("BillboardGui")
            or item:IsA("Beam") or item:IsA("Trail")
            or item:IsA("Fire") or item:IsA("Smoke")
            or item:IsA("Sparkles") or item:IsA("PointLight")
            or item:IsA("SpotLight") or item:IsA("SurfaceLight") then
            return false
        end
    end
    return true
end

-- ═══ ESP ═══
local function createESP(item)
    local part = getItemPart(item)
    if not part then return nil end

    local hl = Instance.new("Highlight")
    hl.Name = "AC_ESP"
    hl.FillColor = CFG.ESPColor
    hl.OutlineColor = CFG.ESPColor
    hl.FillTransparency = CFG.ESPTransparency
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = item

    local bb = Instance.new("BillboardGui")
    bb.Name = "AC_Label"
    bb.Adornee = part
    bb.Size = UDim2.new(0, 200, 0, 22)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = CFG.MaxESPDistance
    bb.Parent = item

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = CFG.ESPColor
    label.Font = Enum.Font.GothamBold
    label.TextSize = touchMode and 18 or 15
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = item.Name
    label.Parent = bb

    return {
        highlight = hl,
        billboard = bb,
        label = label,
        part = part,
    }
end

local function updateESP(item, esp, dist)
    if not esp or not esp.label then return end
    esp.label.Text = item.Name
end

local function destroyESP(esp)
    if esp.highlight then pcall(function() esp.highlight:Destroy() end) end
    if esp.billboard then pcall(function() esp.billboard:Destroy() end) end
end

local function clearAllESP()
    for item, esp in pairs(State.Items) do
        destroyESP(esp)
    end
    State.Items = {}
end

-- ═══ SCAN ═══
local function scanItems()
    if not State.Running then return {} end
    local container = getContainer()
    if not container then return {} end

    local found = {}
    local list = CFG.ScanDescendants
        and container:GetDescendants()
        or container:GetChildren()

    for _, item in ipairs(list) do
        if (item:IsA("BasePart") or item:IsA("Model"))
            and matchPattern(item.Name)
            and isRealItem(item) then
            local pos = getItemPosition(item)
            if pos then
                local dist = getDistanceTo(item) or 999999
                if dist <= CFG.MaxESPDistance then
                    found[item] = { pos = pos, dist = dist }
                end
            end
        end
        if CFG.MaxItems > 0 then
            local count = 0
            for _ in pairs(found) do count = count + 1 end
            if count >= CFG.MaxItems then break end
        end
    end

    for item, esp in pairs(State.Items) do
        if not found[item] or not esp.highlight or not esp.highlight.Parent then
            destroyESP(esp)
            State.Items[item] = nil
        end
    end

    for item, data in pairs(found) do
        if CFG.ESPEnabled then
            if not State.Items[item] then
                local esp = createESP(item)
                if esp then State.Items[item] = esp end
            end
            local esp = State.Items[item]
            if esp then updateESP(item, esp, data.dist) end
        end
    end

    local sorted = {}
    for item, data in pairs(found) do
        table.insert(sorted, {
            item = item,
            name = item.Name,
            dist = data.dist,
            pos = data.pos,
        })
    end
    table.sort(sorted, function(a, b) return a.dist < b.dist end)
    State.SortedList = sorted
    return found
end

-- ═══ TELEPORT ═══
local function teleportTo(position)
    local hrp = getHRP()
    if not hrp then return false end
    local target = position + Vector3.new(0, CFG.TeleportOffset, 0)
    local ok = pcall(function() hrp.CFrame = CFrame.new(target) end)
    if ok then
        State.TeleportCount = State.TeleportCount + 1
        p2("🚀 วาป #" .. State.TeleportCount)
        return true
    end
    return false
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local GUI = { enabled = false, itemButtons = {} }

local function getMainSize()
    local w = UI_SIZES.MainWidth
    local h = UI_SIZES.MainHeight
    -- ✅ ปรับไม่ให้ล้นจอ
    if h > screenY - safeTop - safeBottom - S(20) then
        h = screenY - safeTop - safeBottom - S(20)
    end
    if w > screenX - safeLeft - safeRight - S(20) then
        w = screenX - safeLeft - safeRight - S(20)
    end
    return w, h
end

local function makeGUI()
    local ok = pcall(function()
        local mw, mh = getMainSize()

        local sg = Instance.new("ScreenGui")
        sg.Name = "ItemESPV18"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = false
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

        if touchMode then
            sg.Parent = LP:WaitForChild("PlayerGui", 5)
        else
            pcall(function() sg.Parent = game:GetService("CoreGui") end)
            if not sg.Parent then
                sg.Parent = LP:WaitForChild("PlayerGui", 5)
            end
        end

        -- ✅ ตำแหน่งเริ่มต้น (ปลอดภัย)
        local startX, startY, anchorX, anchorY
        if touchMode then
            -- Mobile: กลางจอส่วนบน
            startX = (screenX - mw) / 2
            startY = safeTop + S(10)
            anchorX = 0
            anchorY = 0
        else
            -- PC: มุมซ้ายบน
            startX = safeLeft + S(15)
            startY = safeTop + S(15)
            anchorX = 0
            anchorY = 0
        end

        local f = Instance.new("Frame")
        f.Name = "Main"
        f.Size = UDim2.new(0, mw, 0, mh)
        f.Position = UDim2.new(0, startX, 0, startY)
        f.AnchorPoint = Vector2.new(anchorX, anchorY)
        f.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
        f.BackgroundTransparency = 0.1
        f.BorderSizePixel = 0
        f.Active = true
        f.Draggable = not touchMode
        f.Parent = sg
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", f)
        stroke.Color = Color3.fromRGB(70, 110, 200)
        stroke.Thickness = 1.5

        -- ═══ TITLE BAR ═══
        local title = Instance.new("Frame")
        title.Name = "TitleBar"
        title.Size = UDim2.new(1, 0, 0, UI_SIZES.TitleHeight)
        title.BackgroundColor3 = Color3.fromRGB(30, 45, 80)
        title.BorderSizePixel = 0
        title.Active = true
        title.Parent = f
        Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

        -- ✅ Drag on touch
        if touchMode then
            local dragging = false
            local dragStart, startPos
            title.InputBegan:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    dragStart = i.Position
                    startPos = f.Position
                end
            end)
            title.InputEnded:Connect(function(i)
                if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)
            UIS.InputChanged:Connect(function(i)
                if dragging and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
                    local d = i.Position - dragStart
                    f.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                          startPos.Y.Scale, startPos.Y.Offset + d.Y)
                end
            end)
        end

        local tl = Instance.new("TextLabel")
        tl.Name = "TitleLabel"
        tl.Size = UDim2.new(1, -S(130), 0, UI_SIZES.TitleHeight)
        tl.Position = UDim2.new(0, S(10), 0, 0)
        tl.BackgroundTransparency = 1
        tl.Text = "🎒 Item ESP"
        tl.TextColor3 = Color3.fromRGB(170, 220, 255)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = UI_SIZES.FontSize
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.Active = false
        tl.Parent = title

        local collapsedInfo = Instance.new("TextLabel")
        collapsedInfo.Size = UDim2.new(0, S(80), 0, UI_SIZES.TitleHeight)
        collapsedInfo.Position = UDim2.new(1, -S(120), 0, 0)
        collapsedInfo.BackgroundTransparency = 1
        collapsedInfo.Text = ""
        collapsedInfo.TextColor3 = Color3.fromRGB(170, 220, 255)
        collapsedInfo.Font = Enum.Font.Code
        collapsedInfo.TextSize = UI_SIZES.SmallFontSize
        collapsedInfo.TextXAlignment = Enum.TextXAlignment.Right
        collapsedInfo.Active = false
        collapsedInfo.Parent = title

        -- ESP mini button
        local espMiniBtn = Instance.new("TextButton")
        espMiniBtn.Size = UDim2.new(0, S(38), 0, UI_SIZES.TitleHeight - S(8))
        espMiniBtn.Position = UDim2.new(1, -S(112), 0, S(4))
        espMiniBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
        espMiniBtn.BorderSizePixel = 0
        espMiniBtn.Text = "ESP"
        espMiniBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
        espMiniBtn.Font = Enum.Font.GothamBold
        espMiniBtn.TextSize = UI_SIZES.SmallFontSize
        espMiniBtn.Parent = title
        Instance.new("UICorner", espMiniBtn).CornerRadius = UDim.new(0, 6)

        -- Collapse
        local collapseBtn = Instance.new("TextButton")
        collapseBtn.Size = UDim2.new(0, S(30), 0, UI_SIZES.TitleHeight - S(8))
        collapseBtn.Position = UDim2.new(1, -S(72), 0, S(4))
        collapseBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)
        collapseBtn.BorderSizePixel = 0
        collapseBtn.Text = "▼"
        collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        collapseBtn.Font = Enum.Font.GothamBold
        collapseBtn.TextSize = UI_SIZES.SmallFontSize + S(2)
        collapseBtn.Parent = title
        Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 6)

        -- ✅ ปุ่ม ✕ (ไม่มีข้อความ)
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, S(30), 0, UI_SIZES.TitleHeight - S(8))
        closeBtn.Position = UDim2.new(1, -S(36), 0, S(4))
        closeBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
        closeBtn.BorderSizePixel = 0
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = UI_SIZES.SmallFontSize + S(4)
        closeBtn.Parent = title
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

        -- ═══ BODY ═══
        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, 0, 1, -UI_SIZES.TitleHeight)
        body.Position = UDim2.new(0, 0, 0, UI_SIZES.TitleHeight)
        body.BackgroundTransparency = 1
        body.Parent = f

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -S(20), 0, S(16))
        status.Position = UDim2.new(0, S(10), 0, S(4))
        status.BackgroundTransparency = 1
        status.Text = "● กำลังสแกน..."
        status.TextColor3 = Color3.fromRGB(100, 255, 120)
        status.Font = Enum.Font.Code
        status.TextSize = UI_SIZES.SmallFontSize
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Parent = body

        local stats = Instance.new("TextLabel")
        stats.Size = UDim2.new(1, -S(20), 0, S(16))
        stats.Position = UDim2.new(0, S(10), 0, S(22))
        stats.BackgroundTransparency = 1
        stats.Text = "Items: 0 | วาปแล้ว: 0"
        stats.TextColor3 = Color3.fromRGB(170, 180, 200)
        stats.Font = Enum.Font.Code
        stats.TextSize = UI_SIZES.SmallFontSize
        stats.TextXAlignment = Enum.TextXAlignment.Left
        stats.Parent = body

        -- ═══ BUTTONS ═══
        local btnY = S(44)
        local btnH = UI_SIZES.ButtonHeight

        local function mkBtn(text, x, y, w, color)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, w, 0, btnH)
            btn.Position = UDim2.new(0, x, 0, y)
            btn.BackgroundColor3 = color
            btn.BorderSizePixel = 0
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(240, 240, 255)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = UI_SIZES.SmallFontSize
            btn.Parent = body
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            return btn
        end

        -- ✅ Layout buttons ตามขนาดจอ
        local bw1, bw2, bw3
        local gap = S(6)
        local availW = mw - S(20)

        if touchMode then
            -- Mobile: แบ่ง 3 ปุ่ม
            bw1 = math.floor(availW * 0.36)
            bw2 = math.floor(availW * 0.40)
            bw3 = math.floor(availW * 0.20)
        else
            bw1 = math.floor(availW * 0.35)
            bw2 = math.floor(availW * 0.42)
            bw3 = math.floor(availW * 0.20)
        end

        local refreshBtn = mkBtn("🔄 สแกน", S(10), btnY, bw1, Color3.fromRGB(60, 90, 160))
        local tpNearestBtn = mkBtn("🚀 วาปใกล้สุด", S(10) + bw1 + gap, btnY, bw2, Color3.fromRGB(140, 100, 40))
        local clearBtn = mkBtn("🗑 ล้าง", S(10) + bw1 + bw2 + gap*2, btnY, bw3, Color3.fromRGB(100, 70, 40))

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -S(20), 0, S(14))
        info.Position = UDim2.new(0, S(10), 0, btnY + btnH + S(4))
        info.BackgroundTransparency = 1
        info.Text = "แตะชื่อ item เพื่อวาป"
        info.TextColor3 = Color3.fromRGB(120, 130, 150)
        info.Font = Enum.Font.Code
        info.TextSize = UI_SIZES.SmallFontSize - S(1)
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Parent = body

        -- ═══ LIST ═══
        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Size = UDim2.new(1, -S(20), 1, -(btnY + btnH + S(30)))
        listFrame.Position = UDim2.new(0, S(10), 0, btnY + btnH + S(22))
        listFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
        listFrame.BorderSizePixel = 0
        listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        listFrame.ScrollBarThickness = UI_SIZES.ScrollThickness
        listFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
        listFrame.Active = true
        listFrame.Parent = body
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 6)

        local layout = Instance.new("UIListLayout", listFrame)
        layout.Padding = UDim.new(0, S(3))
        layout.SortOrder = Enum.SortOrder.LayoutOrder

        GUI.sg = sg
        GUI.frame = f
        GUI.titleBar = title
        GUI.titleLabel = tl
        GUI.body = body
        GUI.status = status
        GUI.stats = stats
        GUI.collapsedInfo = collapsedInfo
        GUI.listFrame = listFrame
        GUI.layout = layout
        GUI.espMiniBtn = espMiniBtn
        GUI.collapseBtn = collapseBtn
        GUI.closeBtn = closeBtn
        GUI.refreshBtn = refreshBtn
        GUI.tpNearestBtn = tpNearestBtn
        GUI.clearBtn = clearBtn
        GUI.enabled = true
    end)
    if not ok then GUI.enabled = false end
end

-- ═══ UPDATE LIST ═══
local function updateItemList()
    if not GUI.enabled or not GUI.listFrame then return end
    if not State.Running then return end

    pcall(function()
        for _, btn in ipairs(GUI.itemButtons) do
            btn:Destroy()
        end
        GUI.itemButtons = {}

        local itemH = UI_SIZES.ItemHeight

        for i, data in ipairs(State.SortedList) do
            local item = data.item
            local name = data.name
            local dist = data.dist

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -S(4), 0, itemH)
            btn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.Parent = GUI.listFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -S(90), 1, 0)
            nameLabel.Position = UDim2.new(0, S(8), 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = string.format("%d. %s", i, name)
            nameLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextSize = UI_SIZES.FontSize
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Parent = btn

            local distLabel = Instance.new("TextLabel")
            distLabel.Size = UDim2.new(0, S(85), 1, 0)
            distLabel.Position = UDim2.new(1, -S(90), 0, 0)
            distLabel.BackgroundTransparency = 1
            distLabel.Text = string.format("%dm  🚀", math.floor(dist))
            distLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
            distLabel.Font = Enum.Font.Code
            distLabel.TextSize = UI_SIZES.SmallFontSize
            distLabel.TextXAlignment = Enum.TextXAlignment.Right
            distLabel.Parent = btn

            btn.MouseButton1Click:Connect(function()
                if not State.Running then return end
                local pos = getItemPosition(item)
                if pos then
                    teleportTo(pos)
                    btn.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
                    task.wait(0.3)
                    if btn.Parent then
                        btn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
                    end
                end
            end)

            table.insert(GUI.itemButtons, btn)
        end

        GUI.listFrame.CanvasSize = UDim2.new(0, 0, 0,
            GUI.layout.AbsoluteContentSize.Y + S(8))
    end)
end

-- ═══ UPDATE STATS ═══
local function updateStats()
    if not GUI.enabled then return end
    if not State.Running then return end
    pcall(function()
        GUI.stats.Text = string.format("Items: %d | วาปแล้ว: %d",
            #State.SortedList, State.TeleportCount)

        if State.Collapsed then
            GUI.collapsedInfo.Text = string.format("%d items", #State.SortedList)
        else
            GUI.collapsedInfo.Text = ""
        end
    end)
end

-- ═══ ESP TOGGLE ═══
local function toggleESP()
    if not State.Running then return end
    CFG.ESPEnabled = not CFG.ESPEnabled

    if CFG.ESPEnabled then
        scanItems()
        if GUI.enabled and GUI.espMiniBtn then
            GUI.espMiniBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
            GUI.espMiniBtn.Text = "ESP"
        end
        p2("ESP: ON")
    else
        clearAllESP()
        if GUI.enabled and GUI.espMiniBtn then
            GUI.espMiniBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
            GUI.espMiniBtn.Text = "OFF"
        end
        p2("ESP: OFF")
    end
end

-- ═══ COLLAPSE ═══
local function toggleCollapse()
    if not GUI.enabled then return end
    if not State.Running then return end

    State.Collapsed = not State.Collapsed

    if State.Collapsed then
        GUI.frame.Size = UDim2.new(0, UI_SIZES.CollapsedWidth, 0, UI_SIZES.CollapsedHeight)
        GUI.body.Visible = false
        GUI.titleBar.Size = UDim2.new(1, 0, 0, UI_SIZES.CollapsedHeight)
        GUI.titleLabel.TextSize = UI_SIZES.SmallFontSize
        GUI.titleLabel.Text = "🎒 ESP"
        GUI.collapseBtn.Text = "▲"
        if GUI.espMiniBtn then GUI.espMiniBtn.Visible = false end
        if GUI.closeBtn then GUI.closeBtn.Visible = false end
        updateStats()
    else
        local mw, mh = getMainSize()
        GUI.frame.Size = UDim2.new(0, mw, 0, mh)
        GUI.body.Visible = true
        GUI.titleBar.Size = UDim2.new(1, 0, 0, UI_SIZES.TitleHeight)
        GUI.titleLabel.TextSize = UI_SIZES.FontSize
        GUI.titleLabel.Text = "🎒 Item ESP"
        GUI.collapseBtn.Text = "▼"
        if GUI.espMiniBtn then GUI.espMiniBtn.Visible = true end
        if GUI.closeBtn then GUI.closeBtn.Visible = true end
        GUI.collapsedInfo.Text = ""
    end
end

-- ═══ SHUTDOWN ═══
local function shutdown()
    if not State.Running then return end
    State.Running = false
    p2("🛑 กำลังปิดสคริปต์...")

    clearAllESP()

    if GUI.enabled and GUI.sg then
        pcall(function() GUI.sg:Destroy() end)
    end
    GUI.enabled = false

    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "AC_ESP" or obj.Name == "AC_Label" then
                obj:Destroy()
            end
        end
    end)

    p2("✅ ปิดสคริปต์เรียบร้อย")
end

makeGUI()

-- ═══ BIND ═══
if GUI.enabled then
    GUI.espMiniBtn.MouseButton1Click:Connect(toggleESP)
    GUI.collapseBtn.MouseButton1Click:Connect(toggleCollapse)
    GUI.closeBtn.MouseButton1Click:Connect(shutdown)

    GUI.refreshBtn.MouseButton1Click:Connect(function()
        if not State.Running then return end
        scanItems()
        updateItemList()
        updateStats()
        GUI.refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 80)
        task.wait(0.2)
        if GUI.enabled then
            GUI.refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
        end
    end)

    GUI.tpNearestBtn.MouseButton1Click:Connect(function()
        if not State.Running then return end
        if #State.SortedList > 0 then
            teleportTo(State.SortedList[1].pos)
        end
    end)

    GUI.clearBtn.MouseButton1Click:Connect(function()
        if not State.Running then return end
        State.TeleportCount = 0
        updateStats()
    end)
end

-- ═══ KEYBIND (เฉพาะ PC) ═══
if showHotkey then
    UIS.InputBegan:Connect(function(input, processed)
        if processed then return end
        if not State.Running then return end

        if input.KeyCode == Enum.KeyCode.RightControl then
            if GUI.enabled and GUI.frame then
                GUI.frame.Visible = not GUI.frame.Visible
            end
        elseif input.KeyCode == Enum.KeyCode.Delete then
            shutdown()
        elseif input.KeyCode == Enum.KeyCode.RightShift then
            toggleESP()
        end
    end)
end

-- ═══ LOOP ═══
task.spawn(function()
    while State.Running do
        task.wait(CFG.ScanInterval)
        if not State.Running then break end

        scanItems()
        updateStats()

        if tick() - State.LastGUIRefresh > 1.5 then
            State.LastGUIRefresh = tick()
            updateItemList()
        end
    end
    p2("🔚 Loop จบการทำงาน")
end)

-- ═══ ROTATE HANDLER (Mobile) ═══
CAM:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    if not State.Running then return end
    if not GUI.enabled or not GUI.frame then return end

    -- อัปเดตขนาดจอ
    vp = CAM.ViewportSize
    screenX = vp.X
    screenY = vp.Y
    minSide = math.min(screenX, screenY)

    -- อัปเดต safe zone
    local newTop, newBottom = GuiService:GetGuiInset()
    safeTop = touchMode and math.max(newTop, screenY * 0.03) or newTop
    safeBottom = touchMode and math.max(newBottom, screenY * 0.03) or newBottom

    -- Resize
    if not State.Collapsed then
        local mw, mh = getMainSize()
        GUI.frame.Size = UDim2.new(0, mw, 0, mh)
        -- ปรับตำแหน่งถ้าล้น
        local pos = GUI.frame.Position
        if pos.X.Offset + mw > screenX then
            GUI.frame.Position = UDim2.new(0, screenX - mw - S(10), pos.Y.Scale, pos.Y.Offset)
        end
        if pos.Y.Offset + mh > screenY - safeBottom then
            GUI.frame.Position = UDim2.new(pos.X.Scale, pos.X.Offset, 0, screenY - mh - safeBottom - S(10))
        end
    end
end)

-- ═══ START ═══
p2("═══════════════════════════════════════════")
p2("Item ESP + Teleport V1.8")
p2("Device: " .. deviceType)
p2("Platform: " .. platform)
p2("UI Scale: " .. uiScale)
if showHotkey then
    p2("ปุ่ม:")
    p2("  RightCtrl = ซ่อน/แสดง GUI")
    p2("  RightShift = toggle ESP")
    p2("  Delete = ปิดทั้งหมด")
else
    p2("กดปุ่มบน GUI")
end
p2("═══════════════════════════════════════════")

task.wait(0.5)
if State.Running then
    scanItems()
    updateItemList()
    updateStats()
    p2(string.format("🔍 เจอ %d item", #State.SortedList))
end
