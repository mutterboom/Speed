-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Item ESP + Teleport V1.7 | PC + Mobile Responsive            ║
-- ║  - ESP label สีเหลืองเดิม ไม่มีกรอบ ไม่มีระยะ                  ║
-- ║  - ปุ่มปิด × หยุดสคริปต์ทั้งหมด                                ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LP = Players.LocalPlayer
local function p2(...) print("[ItemESP]", ...) end

-- ═══ ตรวจจับอุปกรณ์ ═══
local DEVICE = {
    IsMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled,
    IsPC = UIS.KeyboardEnabled and UIS.MouseEnabled,
    IsConsole = UIS.GamepadEnabled and not UIS.KeyboardEnabled,
    HasTouch = UIS.TouchEnabled,
    ScreenSize = workspace.CurrentCamera.ViewportSize,
}

-- ═══ ขนาด UI ตามอุปกรณ์ ═══
local UI_SCALE = {}

if DEVICE.IsMobile then
    p2("📱 อุปกรณ์: Mobile (Touch)")
    UI_SCALE = {
        MainWidth = 0.85, MainHeight = 0.55,
        FontSize = 14, SmallFontSize = 11,
        TitleHeight = 36, ButtonHeight = 36, ItemHeight = 34,
        UseScale = true,
        CollapsedWidth = 0.42, CollapsedHeight = 32, CollapsedFontSize = 12,
    }
elseif DEVICE.IsConsole then
    p2("🎮 อุปกรณ์: Console")
    UI_SCALE = {
        MainWidth = 0.6, MainHeight = 0.6,
        FontSize = 16, SmallFontSize = 13,
        TitleHeight = 40, ButtonHeight = 42, ItemHeight = 40,
        UseScale = true,
        CollapsedWidth = 0.35, CollapsedHeight = 36, CollapsedFontSize = 14,
    }
else
    p2("💻 อุปกรณ์: PC (Keyboard+Mouse)")
    UI_SCALE = {
        MainWidth = 400, MainHeight = 500,
        FontSize = 12, SmallFontSize = 10,
        TitleHeight = 30, ButtonHeight = 26, ItemHeight = 26,
        UseScale = false,
        CollapsedWidth = 180, CollapsedHeight = 28, CollapsedFontSize = 11,
    }
end

-- ═══ CONFIG ═══
local CFG = {
    ContainerPath = "Workspace.Items",
    UsePatterns = false,
    Patterns = { "coin","gem","chest","item","drop","pickup",
                 "orb","shard","token","reward","loot",
                 "fruit","crystal","scroll","key","star",
                 "gun","sniper","sword","weapon","tool" },
    ESPEnabled = true,
    ESPColor = Color3.fromRGB(255, 220, 100),   -- ★ กลับมาใช้สีเหลืองเดิม
    ESPTransparency = 0.5,
    ShowDistance = false,                        -- ★ ไม่แสดงระยะ
    MaxESPDistance = 5000,
    ScanInterval = 0.5,
    TeleportOffset = 3,
    ScanDescendants = true,
    IgnoreEffects = true,
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

-- ═══ ESP — สีเหลืองเดิม ไม่มีกรอบ ★ ═══
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
    label.BackgroundTransparency = 1              -- ★ ไม่มีกรอบ
    label.TextColor3 = CFG.ESPColor               -- ★ สีเหลืองเดิม
    label.Font = Enum.Font.GothamBold
    label.TextSize = DEVICE.IsMobile and 18 or 15
    label.TextStrokeTransparency = 0              -- ★ ใส่ stroke ดำเพื่อให้อ่านง่ายบนทุกพื้น
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
    -- ★ แสดงแค่ชื่อ ไม่มีระยะ
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

-- ═══ GUI ═══
local GUI = { enabled = false, itemButtons = {} }

local function makeGUI()
    local ok = pcall(function()
        local sizes = getSizes()

        local sg = Instance.new("ScreenGui")
        sg.Name = "ItemESPV17"
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

        -- TITLE BAR
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
        tl.Text = "🎒 Item ESP"
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

        local espMiniBtn = Instance.new("TextButton")
        espMiniBtn.Name = "EspMiniBtn"
        espMiniBtn.Size = UDim2.new(0, 36, 0, UI_SCALE.TitleHeight - 8)
        espMiniBtn.Position = UDim2.new(1, -112, 0, 4)
        espMiniBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
        espMiniBtn.BorderSizePixel = 0
        espMiniBtn.Text = "ESP"
        espMiniBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
        espMiniBtn.Font = Enum.Font.GothamBold
        espMiniBtn.TextSize = UI_SCALE.SmallFontSize
        espMiniBtn.Parent = title
        Instance.new("UICorner", espMiniBtn).CornerRadius = UDim.new(0, 4)

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
        status.Size = UDim2.new(1, -20, 0, 16)
        status.Position = UDim2.new(0, 10, 0, 4)
        status.BackgroundTransparency = 1
        status.Text = "● กำลังสแกน..."
        status.TextColor3 = Color3.fromRGB(100, 255, 120)
        status.Font = Enum.Font.Code
        status.TextSize = UI_SCALE.SmallFontSize
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Active = false
        status.Parent = body

        local stats = Instance.new("TextLabel")
        stats.Size = UDim2.new(1, -20, 0, 16)
        stats.Position = UDim2.new(0, 10, 0, 22)
        stats.BackgroundTransparency = 1
        stats.Text = "Items: 0 | วาปแล้ว: 0"
        stats.TextColor3 = Color3.fromRGB(170, 180, 200)
        stats.Font = Enum.Font.Code
        stats.TextSize = UI_SCALE.SmallFontSize
        stats.TextXAlignment = Enum.TextXAlignment.Left
        stats.Active = false
        stats.Parent = body

        local btnY = 44
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

        local refreshBtn, tpNearestBtn, clearBtn

        if DEVICE.IsMobile then
            refreshBtn = mkBtn("🔄 สแกน", 10, btnY, 120,
                Color3.fromRGB(60, 90, 160))
            tpNearestBtn = mkBtn("🚀 วาปใกล้สุด", 138, btnY, 130,
                Color3.fromRGB(140, 100, 40))
            clearBtn = mkBtn("🗑 ล้าง", 276, btnY, 80,
                Color3.fromRGB(100, 70, 40))
        else
            refreshBtn = mkBtn("🔄 สแกนใหม่", 10, btnY, 120,
                Color3.fromRGB(60, 90, 160))
            tpNearestBtn = mkBtn("🚀 วาปใกล้สุด", 135, btnY, 130,
                Color3.fromRGB(140, 100, 40))
            clearBtn = mkBtn("🗑 ล้าง", 270, btnY, 80,
                Color3.fromRGB(100, 70, 40))
        end

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -20, 0, 14)
        info.Position = UDim2.new(0, 10, 0, btnY + btnH + 4)
        info.BackgroundTransparency = 1
        info.Text = "คลิกชื่อ item เพื่อวาป"
        info.TextColor3 = Color3.fromRGB(120, 130, 150)
        info.Font = Enum.Font.Code
        info.TextSize = UI_SCALE.SmallFontSize - 1
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Active = false
        info.Parent = body

        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Size = UDim2.new(1, -20, 1, -(btnY + btnH + 30))
        listFrame.Position = UDim2.new(0, 10, 0, btnY + btnH + 22)
        listFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
        listFrame.BorderSizePixel = 0
        listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        listFrame.ScrollBarThickness = 6
        listFrame.Active = false
        listFrame.Parent = body
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)

        local layout = Instance.new("UIListLayout", listFrame)
        layout.Padding = UDim.new(0, 3)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = listFrame

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

-- ═══ อัพเดท list ═══
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
            local item = data.item
            local name = data.name
            local dist = data.dist

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, itemH)
            btn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.Parent = GUI.listFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -90, 1, 0)
            nameLabel.Position = UDim2.new(0, 8, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = string.format("%d. %s", i, name)
            nameLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextSize = UI_SCALE.FontSize
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Active = false
            nameLabel.Parent = btn

            local distLabel = Instance.new("TextLabel")
            distLabel.Size = UDim2.new(0, 85, 1, 0)
            distLabel.Position = UDim2.new(1, -90, 0, 0)
            distLabel.BackgroundTransparency = 1
            distLabel.Text = string.format("%dm  🚀", math.floor(dist))
            distLabel.TextColor3 = Color3.fromRGB(255, 220, 100)   -- ★ สีเหลืองเดิม
            distLabel.Font = Enum.Font.Code
            distLabel.TextSize = UI_SCALE.SmallFontSize
            distLabel.TextXAlignment = Enum.TextXAlignment.Right
            distLabel.Active = false
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

            btn.MouseEnter:Connect(function()
                btn.BackgroundColor3 = Color3.fromRGB(50, 80, 130)
            end)
            btn.MouseLeave:Connect(function()
                btn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
            end)

            table.insert(GUI.itemButtons, btn)
        end

        GUI.listFrame.CanvasSize = UDim2.new(0, 0, 0,
            GUI.layout.AbsoluteContentSize.Y + 8)
    end)
end

-- ═══ อัพเดท stats ═══
local function updateStats()
    if not GUI.enabled then return end
    if not State.Running then return end
    pcall(function()
        GUI.stats.Text = string.format("Items: %d | วาปแล้ว: %d",
            #State.SortedList, State.TeleportCount)

        if State.Collapsed then
            GUI.collapsedInfo.Text = string.format("%d items", #State.SortedList)
            GUI.collapsedInfo.TextColor3 = Color3.fromRGB(170, 220, 255)
        else
            GUI.collapsedInfo.Text = ""
        end
    end)
end

-- ═══ ESP Toggle ═══
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

-- ═══ พับ/กาง ═══
local function toggleCollapse()
    if not GUI.enabled then return end
    if not State.Running then return end

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
        GUI.titleLabel.Text = "🎒 ESP"

        GUI.collapseBtn.Text = "▲"
        GUI.collapseBtn.Size = UDim2.new(0, 22, 0, UI_SCALE.CollapsedHeight - 6)
        GUI.collapseBtn.Position = UDim2.new(1, -26, 0, 3)
        GUI.collapseBtn.BackgroundColor3 = Color3.fromRGB(70, 90, 120)

        if GUI.espMiniBtn then GUI.espMiniBtn.Visible = false end
        if GUI.closeBtn then GUI.closeBtn.Visible = false end

        updateStats()
    else
        GUI.frame.Size = sizes.Full
        GUI.frame.Position = sizes.Position
        GUI.frame.AnchorPoint = sizes.AnchorPoint

        GUI.titleBar.Size = UDim2.new(1, 0, 0, UI_SCALE.TitleHeight)
        GUI.titleBar.BackgroundColor3 = Color3.fromRGB(30, 45, 80)
        GUI.body.Visible = true

        GUI.titleLabel.TextSize = UI_SCALE.FontSize
        GUI.titleLabel.Text = "🎒 Item ESP"

        GUI.collapseBtn.Text = "▼"
        GUI.collapseBtn.Size = UDim2.new(0, 26, 0, UI_SCALE.TitleHeight - 8)
        GUI.collapseBtn.Position = UDim2.new(1, -72, 0, 4)
        GUI.collapseBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)

        if GUI.espMiniBtn then GUI.espMiniBtn.Visible = true end
        if GUI.closeBtn then GUI.closeBtn.Visible = true end

        GUI.collapsedInfo.Text = ""
    end
end

-- ═══ ปิดสคริปต์ทั้งหมด ═══
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
if DEVICE.IsPC then
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

-- ═══ รองรับการหมุนจอ (Mobile) ═══
if DEVICE.IsMobile then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        if not State.Running then return end
        if GUI.enabled and GUI.frame then
            local sizes = getSizes()
            if State.Collapsed then
                GUI.frame.Size = sizes.Collapsed
            else
                GUI.frame.Size = sizes.Full
            end
        end
    end)
end

-- ═══ START ═══
p2("═══════════════════════════════════════════")
p2("Item ESP + Teleport V1.7")
p2("อุปกรณ์: " .. (DEVICE.IsMobile and "📱 Mobile"
    or DEVICE.IsConsole and "🎮 Console"
    or "💻 PC"))
p2("")
if DEVICE.IsPC then
    p2("ปุ่ม:")
    p2("  ▼/▲ = พับ/กาง")
    p2("  ESP = toggle ESP")
    p2("  RightCtrl = ซ่อน GUI")
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
