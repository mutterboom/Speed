-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Item ESP V2.0 | Mobile Ninja Compatible                       ║
-- ║  - บังคับ PlayerGui (ไม่ใช้ CoreGui)                           ║
-- ║  - Fallback สำหรับทุก API                                      ║
-- ║  - ปลอดภัยสำหรับ Mobile Ninja / Delta / Fluxus                 ║
-- ╚═══════════════════════════════════════════════════════════════╝

print("[ItemESP] ========== START V2.0 ==========")

-- ═══ SERVICES ═══
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local LP = Players.LocalPlayer

print("[ItemESP] Services loaded")

-- ═══ DEVICE DETECTION (ปลอดภัย) ═══
local isMobile = false
local isPC = false
local isConsole = false

pcall(function()
    isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
    isPC = UIS.KeyboardEnabled and UIS.MouseEnabled
    isConsole = UIS.GamepadEnabled and not UIS.KeyboardEnabled
end)

-- ถ้าตรวจไม่ได้ → default PC
if not isMobile and not isPC and not isConsole then
    isPC = true
end

print("[ItemESP] Touch:", UIS.TouchEnabled, "| Keyboard:", UIS.KeyboardEnabled, "| Mouse:", UIS.MouseEnabled)
print("[ItemESP] Detected:", isMobile and "Mobile" or isPC and "PC" or "Console")

-- ═══ SCREEN SIZE (Fallback) ═══
local screenX = 800
local screenY = 600

pcall(function()
    local cam = workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        if vp and vp.X and vp.Y then
            screenX = vp.X
            screenY = vp.Y
        end
    end
end)

print("[ItemESP] Screen:", screenX .. "x" .. screenY)

local minSide = math.min(screenX, screenY)

-- ═══ UI SCALE (Mobile Ninja) ═══
local uiScale = 1.0
local deviceName = "PC"

if isMobile then
    if minSide < 350 then
        uiScale = 0.55; deviceName = "Mobile-XS"
    elseif minSide < 400 then
        uiScale = 0.65; deviceName = "Mobile-Small"
    elseif minSide < 480 then
        uiScale = 0.78; deviceName = "Mobile-Mid"
    elseif minSide < 600 then
        uiScale = 0.88; deviceName = "Mobile-Large"
    elseif minSide < 800 then
        uiScale = 0.95; deviceName = "Tablet-Small"
    else
        uiScale = 1.05; deviceName = "Tablet-Large"
    end
elseif isConsole then
    uiScale = 1.15; deviceName = "Console"
else
    if screenY < 700 then
        uiScale = 0.85; deviceName = "PC-Small"
    elseif screenY < 900 then
        uiScale = 0.95; deviceName = "PC-Mid"
    elseif screenY < 1200 then
        uiScale = 1.0; deviceName = "PC"
    else
        uiScale = 1.15; deviceName = "PC-4K"
    end
end

print("[ItemESP] Device:", deviceName, "| Scale:", uiScale)

local function S(px) return math.floor(px * uiScale) end

-- ═══ UI SIZES ═══
local UI_SCALE = {
    MainWidth = isMobile and S(280) or S(400),
    MainHeight = isMobile and S(380) or S(500),
    FontSize = isMobile and S(13) or S(12),
    SmallFontSize = isMobile and S(11) or S(10),
    TitleHeight = isMobile and S(40) or S(30),
    ButtonHeight = isMobile and S(42) or S(28),
    ItemHeight = isMobile and S(40) or S(28),
    CollapsedWidth = isMobile and S(160) or S(180),
    CollapsedHeight = isMobile and S(32) or S(28),
    ScrollThickness = isMobile and 10 or 6,
}

-- ═══ CONFIG ═══
local CFG = {
    ContainerPath = "Workspace.Items",
    UsePatterns = false,
    Patterns = { "coin","gem","chest","item","drop","pickup",
                 "orb","shard","token","reward","loot" },
    ESPEnabled = true,
    ESPColor = Color3.fromRGB(255, 220, 100),
    ESPTransparency = 0.5,
    MaxESPDistance = 5000,
    ScanInterval = 0.5,
    TeleportOffset = 3,
    MaxItems = 300,
}

-- ═══ STATE ═══
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
    local playerGui = LP:FindFirstChild("PlayerGui")
    if playerGui then
        for _, g in ipairs(playerGui:GetChildren()) do
            if g.Name:find("^ItemESP") or g.Name:find("^AutoCollect") then
                g:Destroy()
            end
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
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
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

local function getItemPosition(item)
    if not item then return nil end
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
    if not item then return nil end
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

-- ═══ ESP ═══
local function createESP(item)
    local part = getItemPart(item)
    if not part then return nil end

    local esp = {}

    -- Highlight (optional - fallback ถ้าไม่ได้)
    local hlOk = pcall(function()
        local hl = Instance.new("Highlight")
        hl.Name = "AC_ESP"
        hl.FillColor = CFG.ESPColor
        hl.OutlineColor = CFG.ESPColor
        hl.FillTransparency = CFG.ESPTransparency
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = item
        hl.Parent = item
        esp.highlight = hl
    end)
    if not hlOk then
        esp.highlight = nil
    end

    -- Billboard label
    local bbOk = pcall(function()
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
        label.TextSize = isMobile and 18 or 15
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.Text = item.Name
        label.Parent = bb

        esp.billboard = bb
        esp.label = label
    end)
    if not bbOk then
        if esp.highlight then esp.highlight:Destroy() end
        return nil
    end

    esp.part = part
    return esp
end

local function destroyESP(esp)
    if not esp then return end
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
    local list = container:GetDescendants()

    for _, item in ipairs(list) do
        if (item:IsA("BasePart") or item:IsA("Model")) then
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

    -- ลบ ESP ที่หายไป
    for item, esp in pairs(State.Items) do
        if not found[item] then
            destroyESP(esp)
            State.Items[item] = nil
        end
    end

    -- เพิ่ม ESP ใหม่
    if CFG.ESPEnabled then
        for item, data in pairs(found) do
            if not State.Items[item] then
                local esp = createESP(item)
                if esp then State.Items[item] = esp end
            end
        end
    end

    -- Sort
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
        print("[ItemESP] 🚀 วาป #" .. State.TeleportCount)
        return true
    end
    return false
end

-- ═══ GUI ═══
local GUI = { enabled = false, itemButtons = {} }

local function makeGUI()
    local ok, err = pcall(function()
        -- ✅ บังคับ PlayerGui (Mobile Ninja)
        local playerGui = LP:WaitForChild("PlayerGui", 5)
        if not playerGui then
            print("[ItemESP] ❌ ไม่เจอ PlayerGui")
            return
        end

        local sg = Instance.new("ScreenGui")
        sg.Name = "ItemESPV20"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = false
        sg.DisplayOrder = 10
        sg.Parent = playerGui

        print("[ItemESP] ✅ ScreenGui สร้าง + parent = PlayerGui")

        -- ✅ Position ปลอดภัย
        local mw = UI_SCALE.MainWidth
        local mh = UI_SCALE.MainHeight

        -- ให้ Mobile อยู่กลางบน, PC มุมซ้ายบน
        local startX, startY
        if isMobile then
            startX = math.floor((screenX - mw) / 2)
            startY = math.floor(screenY * 0.05)
        else
            startX = 15
            startY = 60
        end

        local f = Instance.new("Frame")
        f.Name = "Main"
        f.Size = UDim2.new(0, mw, 0, mh)
        f.Position = UDim2.new(0, startX, 0, startY)
        f.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
        f.BackgroundTransparency = 0.05
        f.BorderSizePixel = 0
        f.Active = true
        f.Draggable = true
        f.Parent = sg
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

        local stroke = Instance.new("UIStroke", f)
        stroke.Color = Color3.fromRGB(70, 110, 200)
        stroke.Thickness = 2
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

        -- ═══ TITLE BAR ═══
        local title = Instance.new("Frame")
        title.Name = "TitleBar"
        title.Size = UDim2.new(1, 0, 0, UI_SCALE.TitleHeight)
        title.BackgroundColor3 = Color3.fromRGB(30, 45, 80)
        title.BorderSizePixel = 0
        title.Active = true
        title.Parent = f
        Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, -S(120), 0, UI_SCALE.TitleHeight)
        tl.Position = UDim2.new(0, S(10), 0, 0)
        tl.BackgroundTransparency = 1
        tl.Text = "🎒 Item ESP"
        tl.TextColor3 = Color3.fromRGB(170, 220, 255)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = UI_SCALE.FontSize
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.Parent = title

        local espMiniBtn = Instance.new("TextButton")
        espMiniBtn.Size = UDim2.new(0, S(40), 0, UI_SCALE.TitleHeight - S(8))
        espMiniBtn.Position = UDim2.new(1, -S(110), 0, S(4))
        espMiniBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
        espMiniBtn.BorderSizePixel = 0
        espMiniBtn.Text = "ESP"
        espMiniBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
        espMiniBtn.Font = Enum.Font.GothamBold
        espMiniBtn.TextSize = UI_SCALE.SmallFontSize
        espMiniBtn.Parent = title
        Instance.new("UICorner", espMiniBtn).CornerRadius = UDim.new(0, 4)

        local collapseBtn = Instance.new("TextButton")
        collapseBtn.Size = UDim2.new(0, S(30), 0, UI_SCALE.TitleHeight - S(8))
        collapseBtn.Position = UDim2.new(1, -S(68), 0, S(4))
        collapseBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)
        collapseBtn.BorderSizePixel = 0
        collapseBtn.Text = "▼"
        collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        collapseBtn.Font = Enum.Font.GothamBold
        collapseBtn.TextSize = UI_SCALE.SmallFontSize + S(2)
        collapseBtn.Parent = title
        Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 4)

        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, S(32), 0, UI_SCALE.TitleHeight - S(8))
        closeBtn.Position = UDim2.new(1, -S(36), 0, S(4))
        closeBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
        closeBtn.BorderSizePixel = 0
        closeBtn.Text = "✕"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = UI_SCALE.SmallFontSize + S(4)
        closeBtn.Parent = title
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)

        -- ═══ BODY ═══
        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, 0, 1, -UI_SCALE.TitleHeight)
        body.Position = UDim2.new(0, 0, 0, UI_SCALE.TitleHeight)
        body.BackgroundTransparency = 1
        body.Parent = f

        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -S(20), 0, S(16))
        status.Position = UDim2.new(0, S(10), 0, S(4))
        status.BackgroundTransparency = 1
        status.Text = "● กำลังสแกน..."
        status.TextColor3 = Color3.fromRGB(100, 255, 120)
        status.Font = Enum.Font.Code
        status.TextSize = UI_SCALE.SmallFontSize
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Parent = body

        local stats = Instance.new("TextLabel")
        stats.Size = UDim2.new(1, -S(20), 0, S(16))
        stats.Position = UDim2.new(0, S(10), 0, S(22))
        stats.BackgroundTransparency = 1
        stats.Text = "Items: 0 | วาปแล้ว: 0"
        stats.TextColor3 = Color3.fromRGB(170, 180, 200)
        stats.Font = Enum.Font.Code
        stats.TextSize = UI_SCALE.SmallFontSize
        stats.TextXAlignment = Enum.TextXAlignment.Left
        stats.Parent = body

        -- ═══ BUTTONS ═══
        local btnY = S(44)
        local btnH = UI_SCALE.ButtonHeight

        local function mkBtn(text, x, y, w, color)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, w, 0, btnH)
            btn.Position = UDim2.new(0, x, 0, y)
            btn.BackgroundColor3 = color
            btn.BorderSizePixel = 0
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(240, 240, 255)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = UI_SCALE.SmallFontSize
            btn.Parent = body
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            return btn
        end

        -- คำนวณ layout
        local availW = mw - S(20)
        local gap = S(6)
        local bw1 = math.floor((availW - gap * 2) / 3)
        local bw2 = bw1
        local bw3 = availW - bw1 - bw2 - gap * 2

        local refreshBtn = mkBtn("🔄 สแกน", S(10), btnY, bw1, Color3.fromRGB(60, 90, 160))
        local tpNearestBtn = mkBtn("🚀 วาป", S(10) + bw1 + gap, btnY, bw2, Color3.fromRGB(140, 100, 40))
        local clearBtn = mkBtn("🗑 ล้าง", S(10) + bw1 + bw2 + gap*2, btnY, bw3, Color3.fromRGB(100, 70, 40))

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -S(20), 0, S(14))
        info.Position = UDim2.new(0, S(10), 0, btnY + btnH + S(4))
        info.BackgroundTransparency = 1
        info.Text = "แตะชื่อ item เพื่อวาป"
        info.TextColor3 = Color3.fromRGB(120, 130, 150)
        info.Font = Enum.Font.Code
        info.TextSize = UI_SCALE.SmallFontSize
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Parent = body

        -- ═══ LIST ═══
        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Size = UDim2.new(1, -S(20), 1, -(btnY + btnH + S(30)))
        listFrame.Position = UDim2.new(0, S(10), 0, btnY + btnH + S(22))
        listFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
        listFrame.BorderSizePixel = 0
        listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        listFrame.ScrollBarThickness = UI_SCALE.ScrollThickness
        listFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
        listFrame.Active = true
        listFrame.Parent = body
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)

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
        GUI.listFrame = listFrame
        GUI.layout = layout
        GUI.espMiniBtn = espMiniBtn
        GUI.collapseBtn = collapseBtn
        GUI.closeBtn = closeBtn
        GUI.refreshBtn = refreshBtn
        GUI.tpNearestBtn = tpNearestBtn
        GUI.clearBtn = clearBtn
        GUI.enabled = true

        print("[ItemESP] ✅ GUI สร้างสำเร็จ")
    end)

    if not ok then
        print("[ItemESP] ❌ GUI error:", tostring(err))
        GUI.enabled = false
    end
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

        local itemH = UI_SCALE.ItemHeight

        for i, data in ipairs(State.SortedList) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -S(4), 0, itemH)
            btn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.Parent = GUI.listFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -S(80), 1, 0)
            nameLabel.Position = UDim2.new(0, S(8), 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = i .. ". " .. data.name
            nameLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextSize = UI_SCALE.FontSize
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Parent = btn

            local distLabel = Instance.new("TextLabel")
            distLabel.Size = UDim2.new(0, S(75), 1, 0)
            distLabel.Position = UDim2.new(1, -S(80), 0, 0)
            distLabel.BackgroundTransparency = 1
            distLabel.Text = math.floor(data.dist) .. "m 🚀"
            distLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
            distLabel.Font = Enum.Font.Code
            distLabel.TextSize = UI_SCALE.SmallFontSize
            distLabel.TextXAlignment = Enum.TextXAlignment.Right
            distLabel.Parent = btn

            local capturedItem = data.item
            btn.MouseButton1Click:Connect(function()
                if not State.Running then return end
                local pos = getItemPosition(capturedItem)
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
    if not GUI.enabled or not GUI.stats then return end
    if not State.Running then return end
    pcall(function()
        GUI.stats.Text = "Items: " .. #State.SortedList .. " | วาปแล้ว: " .. State.TeleportCount
    end)
end

-- ═══ TOGGLE ESP ═══
local function toggleESP()
    if not State.Running then return end
    CFG.ESPEnabled = not CFG.ESPEnabled

    if CFG.ESPEnabled then
        scanItems()
        if GUI.enabled and GUI.espMiniBtn then
            GUI.espMiniBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
        end
        print("[ItemESP] ESP: ON")
    else
        clearAllESP()
        if GUI.enabled and GUI.espMiniBtn then
            GUI.espMiniBtn.BackgroundColor3 = Color3.fromRGB(120, 50, 50)
        end
        print("[ItemESP] ESP: OFF")
    end
end

-- ═══ COLLAPSE ═══
local function toggleCollapse()
    if not GUI.enabled then return end
    if not State.Running then return end

    State.Collapsed = not State.Collapsed

    if State.Collapsed then
        GUI.frame.Size = UDim2.new(0, UI_SCALE.CollapsedWidth, 0, UI_SCALE.CollapsedHeight)
        GUI.body.Visible = false
        GUI.titleLabel.Text = "🎒 ESP"
        GUI.collapseBtn.Text = "▲"
        if GUI.espMiniBtn then GUI.espMiniBtn.Visible = false end
        if GUI.closeBtn then GUI.closeBtn.Visible = false end
    else
        GUI.frame.Size = UDim2.new(0, UI_SCALE.MainWidth, 0, UI_SCALE.MainHeight)
        GUI.body.Visible = true
        GUI.titleLabel.Text = "🎒 Item ESP"
        GUI.collapseBtn.Text = "▼"
        if GUI.espMiniBtn then GUI.espMiniBtn.Visible = true end
        if GUI.closeBtn then GUI.closeBtn.Visible = true end
    end
end

-- ═══ SHUTDOWN ═══
local function shutdown()
    if not State.Running then return end
    State.Running = false
    print("[ItemESP] 🛑 ปิดสคริปต์...")

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

    print("[ItemESP] ✅ ปิดเรียบร้อย")
end

-- ═══ BUILD GUI ═══
makeGUI()

-- ═══ BIND BUTTONS ═══
if GUI.enabled then
    pcall(function()
        GUI.espMiniBtn.MouseButton1Click:Connect(toggleESP)
        GUI.collapseBtn.MouseButton1Click:Connect(toggleCollapse)
        GUI.closeBtn.MouseButton1Click:Connect(shutdown)

        GUI.refreshBtn.MouseButton1Click:Connect(function()
            if not State.Running then return end
            scanItems()
            updateItemList()
            updateStats()
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
    end)
    print("[ItemESP] ✅ ปุ่มทั้งหมดผูกสำเร็จ")
end

-- ═══ KEYBIND (เฉพาะ PC) ═══
if isPC then
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
    print("[ItemESP] 🔚 Loop จบ")
end)

-- ═══ ROTATE HANDLER ═══
pcall(function()
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if not State.Running then return end
        if not GUI.enabled or not GUI.frame then return end

        local vp = workspace.CurrentCamera.ViewportSize
        if not vp then return end

        local newX = vp.X
        local newY = vp.Y

        if not State.Collapsed then
            local mw = UI_SCALE.MainWidth
            local mh = UI_SCALE.MainHeight

            if mh > newY - 40 then mh = newY - 40 end
            if mw > newX - 20 then mw = newX - 20 end

            GUI.frame.Size = UDim2.new(0, mw, 0, mh)
        end
    end)
end)

-- ═══ START ═══
print("[ItemESP] ════════════════════════════════")
print("[ItemESP] Item ESP V2.0")
print("[ItemESP] Device:", deviceName)
print("[ItemESP] Platform:", isMobile and "Mobile" or isPC and "PC" or "Console")
print("[ItemESP] Scale:", uiScale)
print("[ItemESP] ════════════════════════════════")

task.wait(0.5)
if State.Running then
    scanItems()
    updateItemList()
    updateStats()
    print("[ItemESP] 🔍 เจอ " .. #State.SortedList .. " item")
end

print("[ItemESP] ========== READY V2.0 ==========")
