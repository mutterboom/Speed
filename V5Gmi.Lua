-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Item ESP + Teleport V1.3                                     ║
-- ║  - ปุ่มพับ/กางที่ header                                       ║
-- ║  - ปุ่ม ESP toggle ที่ header                                  ║
-- ║  - คลิกชื่อ item → วาป                                          ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")

local LP = Players.LocalPlayer
local function p2(...) print("[ItemESP]", ...) end

-- ═══ CONFIG ═══
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
    ShowDistance = true,
    MaxESPDistance = 5000,
    ScanInterval = 0.5,
    TeleportOffset = 3,
}

-- ═══ STATE ═══
local State = {
    Running = true,
    Items = {},
    SortedList = {},
    LastGUIRefresh = 0,
    TeleportCount = 0,
    Collapsed = false,      -- ★ สถานะพับ
    LastSelected = nil,
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
    local part = item.PrimaryPart
        or item:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position or nil
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
    bb.Size = UDim2.new(0, 220, 0, 36)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = CFG.MaxESPDistance
    bb.Parent = item
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 0.3
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.TextColor3 = CFG.ESPColor
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = item.Name
    label.Parent = bb
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = label
    
    return {
        highlight = hl,
        billboard = bb,
        label = label,
        part = part,
    }
end

local function updateESP(item, esp, dist)
    if not esp or not esp.label then return end
    local text = item.Name
    if CFG.ShowDistance and dist then
        text = string.format("%s [%dm]", item.Name, math.floor(dist))
    end
    esp.label.Text = text
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
    local container = getContainer()
    if not container then return {} end
    
    local found = {}
    
    for _, item in ipairs(container:GetChildren()) do
        if matchPattern(item.Name) then
            local pos = getItemPosition(item)
            if pos then
                local dist = getDistanceTo(item) or 999999
                found[item] = { pos = pos, dist = dist }
            end
        end
    end
    
    -- ลบ ESP ที่ไม่มีแล้ว
    for item, esp in pairs(State.Items) do
        if not found[item] or not esp.highlight or not esp.highlight.Parent then
            destroyESP(esp)
            State.Items[item] = nil
        end
    end
    
    -- เพิ่ม/อัพเดท
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
    
    -- Sorted list
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

-- ═══ GUI ═══
local GUI = { enabled = false, itemButtons = {} }

-- ขนาด GUI
local SIZE_FULL = UDim2.new(0, 400, 0, 500)
local SIZE_COLLAPSED = UDim2.new(0, 400, 0, 30)

local function makeGUI()
    local ok = pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Name = "ItemESPV13"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        pcall(function() sg.Parent = game:GetService("CoreGui") end)
        if not sg.Parent then
            sg.Parent = LP:WaitForChild("PlayerGui", 5)
        end
        
        local f = Instance.new("Frame")
        f.Size = SIZE_FULL
        f.Position = UDim2.new(0, 15, 0, 15)
        f.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
        f.BackgroundTransparency = 0.1
        f.BorderSizePixel = 0
        f.Active = true
        f.Draggable = true
        f.Parent = sg
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        
        local stroke = Instance.new("UIStroke", f)
        stroke.Color = Color3.fromRGB(70, 110, 200)
        
        -- ═══════ TITLE BAR ═══════
        local title = Instance.new("Frame")
        title.Size = UDim2.new(1, 0, 0, 30)
        title.BackgroundColor3 = Color3.fromRGB(30, 45, 80)
        title.BorderSizePixel = 0
        title.Active = true
        title.Parent = f
        Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)
        
        -- Title text
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, -180, 0, 30)
        tl.Position = UDim2.new(0, 8, 0, 0)
        tl.BackgroundTransparency = 1
        tl.Text = "🎒 Item ESP"
        tl.TextColor3 = Color3.fromRGB(220, 230, 255)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 12
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.Active = false
        tl.Parent = title
        
        -- ★ สถานะบน title bar (โชว์ตอนพับ)
        local collapsedInfo = Instance.new("TextLabel")
        collapsedInfo.Name = "CollapsedInfo"
        collapsedInfo.Size = UDim2.new(0, 100, 0, 30)
        collapsedInfo.Position = UDim2.new(1, -180, 0, 0)
        collapsedInfo.BackgroundTransparency = 1
        collapsedInfo.Text = ""
        collapsedInfo.TextColor3 = Color3.fromRGB(150, 220, 150)
        collapsedInfo.Font = Enum.Font.Code
        collapsedInfo.TextSize = 11
        collapsedInfo.TextXAlignment = Enum.TextXAlignment.Right
        collapsedInfo.Active = false
        collapsedInfo.Parent = title
        
        -- ★ ปุ่ม ESP บน title bar
        local espMiniBtn = Instance.new("TextButton")
        espMiniBtn.Size = UDim2.new(0, 40, 0, 22)
        espMiniBtn.Position = UDim2.new(1, -120, 0, 4)
        espMiniBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
        espMiniBtn.BorderSizePixel = 0
        espMiniBtn.Text = "ESP"
        espMiniBtn.TextColor3 = Color3.fromRGB(240, 240, 255)
        espMiniBtn.Font = Enum.Font.GothamBold
        espMiniBtn.TextSize = 10
        espMiniBtn.Parent = title
        Instance.new("UICorner", espMiniBtn).CornerRadius = UDim.new(0, 4)
        
        -- ★ ปุ่มพับ (−)
        local collapseBtn = Instance.new("TextButton")
        collapseBtn.Size = UDim2.new(0, 22, 0, 22)
        collapseBtn.Position = UDim2.new(1, -75, 0, 4)
        collapseBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)
        collapseBtn.BorderSizePixel = 0
        collapseBtn.Text = "−"
        collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        collapseBtn.Font = Enum.Font.GothamBold
        collapseBtn.TextSize = 16
        collapseBtn.Parent = title
        Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 4)
        
        -- ปุ่ม close (×)
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 22, 0, 22)
        closeBtn.Position = UDim2.new(1, -50, 0, 4)
        closeBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
        closeBtn.BorderSizePixel = 0
        closeBtn.Text = "×"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 16
        closeBtn.Parent = title
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
        
        -- ═══════ BODY ═══════
        local body = Instance.new("Frame")
        body.Name = "Body"
        body.Size = UDim2.new(1, 0, 1, -30)
        body.Position = UDim2.new(0, 0, 0, 30)
        body.BackgroundTransparency = 1
        body.Active = false
        body.Parent = f
        
        -- Status
        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -20, 0, 16)
        status.Position = UDim2.new(0, 10, 0, 4)
        status.BackgroundTransparency = 1
        status.Text = "● กำลังสแกน..."
        status.TextColor3 = Color3.fromRGB(100, 255, 120)
        status.Font = Enum.Font.Code
        status.TextSize = 11
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Active = false
        status.Parent = body
        
        -- Stats
        local stats = Instance.new("TextLabel")
        stats.Size = UDim2.new(1, -20, 0, 16)
        stats.Position = UDim2.new(0, 10, 0, 22)
        stats.BackgroundTransparency = 1
        stats.Text = "Items: 0 | วาปแล้ว: 0"
        stats.TextColor3 = Color3.fromRGB(170, 180, 200)
        stats.Font = Enum.Font.Code
        stats.TextSize = 11
        stats.TextXAlignment = Enum.TextXAlignment.Left
        stats.Active = false
        stats.Parent = body
        
        -- ปุ่มแถว
        local function mkBtn(text, x, w, color)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, w, 0, 24)
            btn.Position = UDim2.new(0, x, 0, 44)
            btn.BackgroundColor3 = color
            btn.BorderSizePixel = 0
            btn.Text = text
            btn.TextColor3 = Color3.fromRGB(240, 240, 255)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 11
            btn.Parent = body
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            return btn
        end
        
        local refreshBtn = mkBtn("🔄 สแกนใหม่", 10, 120,
            Color3.fromRGB(60, 90, 160))
        local tpNearestBtn = mkBtn("🚀 วาปใกล้สุด", 135, 130,
            Color3.fromRGB(140, 100, 40))
        local clearBtn = mkBtn("🗑 ล้าง", 270, 80,
            Color3.fromRGB(100, 70, 40))
        
        -- Info
        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -20, 0, 14)
        info.Position = UDim2.new(0, 10, 0, 72)
        info.BackgroundTransparency = 1
        info.Text = "คลิกชื่อ item เพื่อวาป"
        info.TextColor3 = Color3.fromRGB(120, 130, 150)
        info.Font = Enum.Font.Code
        info.TextSize = 9
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Active = false
        info.Parent = body
        
        -- List
        local listFrame = Instance.new("ScrollingFrame")
        listFrame.Size = UDim2.new(1, -20, 1, -100)
        listFrame.Position = UDim2.new(0, 10, 0, 92)
        listFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
        listFrame.BorderSizePixel = 0
        listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        listFrame.ScrollBarThickness = 4
        listFrame.Active = false
        listFrame.Parent = body
        Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 4)
        
        local layout = Instance.new("UIListLayout", listFrame)
        layout.Padding = UDim.new(0, 2)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = listFrame
        
        GUI.sg = sg
        GUI.frame = f
        GUI.titleBar = title
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

-- ═══ อัพเดท list GUI ═══
local function updateItemList()
    if not GUI.enabled or not GUI.listFrame then return end
    
    pcall(function()
        for _, btn in ipairs(GUI.itemButtons) do
            btn:Destroy()
        end
        GUI.itemButtons = {}
        
        for i, data in ipairs(State.SortedList) do
            local item = data.item
            local name = data.name
            local dist = data.dist
            
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -4, 0, 26)
            btn.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
            btn.BorderSizePixel = 0
            btn.Text = ""
            btn.Parent = GUI.listFrame
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, -100, 1, 0)
            nameLabel.Position = UDim2.new(0, 8, 0, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Text = string.format("%d. %s", i, name)
            nameLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextSize = 11
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Active = false
            nameLabel.Parent = btn
            
            local distLabel = Instance.new("TextLabel")
            distLabel.Size = UDim2.new(0, 90, 1, 0)
            distLabel.Position = UDim2.new(1, -95, 0, 0)
            distLabel.BackgroundTransparency = 1
            distLabel.Text = string.format("%dm  🚀", math.floor(dist))
            distLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
            distLabel.Font = Enum.Font.Code
            distLabel.TextSize = 11
            distLabel.TextXAlignment = Enum.TextXAlignment.Right
            distLabel.Active = false
            distLabel.Parent = btn
            
            btn.MouseButton1Click:Connect(function()
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
            GUI.layout.AbsoluteContentSize.Y + 6)
    end)
end

-- ═══ อัพเดท stats ═══
local function updateStats()
    if not GUI.enabled then return end
    pcall(function()
        GUI.stats.Text = string.format("Items: %d | วาปแล้ว: %d",
            #State.SortedList, State.TeleportCount)
        
        -- ★ อัพเดท collapsed info
        if State.Collapsed then
            GUI.collapsedInfo.Text = string.format("%d items | tp:%d",
                #State.SortedList, State.TeleportCount)
        else
            GUI.collapsedInfo.Text = ""
        end
    end)
end

-- ═══ ESP Toggle (ใช้ร่วมกัน) ═══
local function toggleESP()
    CFG.ESPEnabled = not CFG.ESPEnabled
    
    if CFG.ESPEnabled then
        -- สร้าง ESP ใหม่
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
    
    State.Collapsed = not State.Collapsed
    
    if State.Collapsed then
        GUI.frame.Size = SIZE_COLLAPSED
        GUI.body.Visible = false
        GUI.collapseBtn.Text = "+"
        GUI.collapseBtn.BackgroundColor3 = Color3.fromRGB(70, 90, 120)
        updateStats()  -- อัพเดท collapsed info
    else
        GUI.frame.Size = SIZE_FULL
        GUI.body.Visible = true
        GUI.collapseBtn.Text = "−"
        GUI.collapseBtn.BackgroundColor3 = Color3.fromRGB(90, 120, 70)
        GUI.collapsedInfo.Text = ""
    end
end

makeGUI()

-- ═══ BIND ═══
if GUI.enabled then
    -- ESP toggle (บน title bar)
    GUI.espMiniBtn.MouseButton1Click:Connect(toggleESP)
    
    -- พับ
    GUI.collapseBtn.MouseButton1Click:Connect(toggleCollapse)
    
    -- close
    GUI.closeBtn.MouseButton1Click:Connect(function()
        State.Running = false
        clearAllESP()
        task.wait(0.2)
        pcall(function() GUI.sg:Destroy() end)
    end)
    
    -- refresh
    GUI.refreshBtn.MouseButton1Click:Connect(function()
        scanItems()
        updateItemList()
        updateStats()
        GUI.refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 140, 80)
        task.wait(0.2)
        GUI.refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 160)
    end)
    
    -- วาปใกล้สุด
    GUI.tpNearestBtn.MouseButton1Click:Connect(function()
        if #State.SortedList > 0 then
            teleportTo(State.SortedList[1].pos)
        end
    end)
    
    -- clear log
    GUI.clearBtn.MouseButton1Click:Connect(function()
        State.TeleportCount = 0
        updateStats()
    end)
end

-- ═══ KEYBIND ═══
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.RightControl then
        -- toggle GUI
        if GUI.enabled and GUI.frame then
            GUI.frame.Visible = not GUI.frame.Visible
        end
    elseif input.KeyCode == Enum.KeyCode.Delete then
        State.Running = false
        clearAllESP()
        if GUI.enabled then
            pcall(function() GUI.sg:Destroy() end)
        end
    elseif input.KeyCode == Enum.KeyCode.RightShift then
        -- ★ RightShift = toggle ESP
        toggleESP()
    end
end)

-- ═══ LOOP ═══
task.spawn(function()
    while State.Running do
        task.wait(CFG.ScanInterval)
        
        scanItems()
        updateStats()
        
        if tick() - State.LastGUIRefresh > 1.5 then
            State.LastGUIRefresh = tick()
            updateItemList()
        end
    end
end)

-- ═══ START ═══
p2("═══════════════════════════════════════════")
p2("Item ESP + Teleport V1.3")
p2("ปุ่มใหม่:")
p2("  −  = พับ/กาง GUI")
p2("  ESP = toggle ESP (บน header)")
p2("  RightCtrl = ซ่อน GUI")
p2("  RightShift = toggle ESP")
p2("  Delete = ปิดทั้งหมด")
p2("═══════════════════════════════════════════")

task.wait(0.5)
scanItems()
updateItemList()
updateStats()
p2(string.format("🔍 เจอ %d item", #State.SortedList))
