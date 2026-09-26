-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Auto Block V2 | Handicap Edition                             ║
-- ║  Trigger: HandicapService.RE.Hit                              ║
-- ║  Action: Face + Block                                         ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════
local Config = {
    -- ระยะสูงสุดที่จะ auto block
    MaxDistance = 20,
    
    -- ระยะห่างจากผู้โจมตีที่ยอมรับ
    BlockDurationMs = 250,
    
    -- Cooldown ระหว่าง block (กัน spam)
    BlockCooldownMs = 150,
    
    -- Face Lerp
    FaceLerp = 0.5,
    
    -- Debug mode
    Debug = true,
    
    -- เปิดอัตโนมัติเมื่อโหลด
    AutoStart = false,
}

-- ═══════════════════════════════════════════
-- FIND REMOTES
-- ═══════════════════════════════════════════
local function findRemote(path)
    local obj = ReplicatedStorage
    for _, part in ipairs(string.split(path, ".")) do
        obj = obj:FindFirstChild(part)
        if not obj then return nil end
    end
    return obj
end

local HitRemote = findRemote("Knit.Knit.Services.HandicapService.RE.Hit")
local BlockActivated = findRemote("Knit.Knit.Services.BlockService.RE.Activated")
local BlockDeactivated = findRemote("Knit.Knit.Services.BlockService.RE.Deactivated")

if not HitRemote then
    warn("[AB V2] ❌ ไม่เจอ HandicapService.RE.Hit")
    return
end
if not BlockActivated then
    warn("[AB V2] ❌ ไม่เจอ BlockService.RE.Activated")
    return
end

print("[AB V2] ✅ เจอ remotes ครบ")

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    Enabled = false,
    LastBlock = 0,
    BlockCount = 0,
    LastAttacker = nil,
    LastDistance = 0,
    Errors = 0,
}

-- ═══════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════
local function log(...)
    if Config.Debug then
        print("[AB V2]", ...)
    end
end

local function getMyChar()
    local char = LP.Character
    if not char then return nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return char, hrp
end

local function getAttackerHRP(attacker)
    if not attacker then return nil end
    if attacker:IsA("Model") then
        return attacker:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function faceTo(targetPos)
    local _, myHRP = getMyChar()
    if not myHRP then return false end
    
    local myPos = myHRP.Position
    local look = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
    local newCF = CFrame.lookAt(myPos, look)
    
    if Config.FaceLerp >= 1 then
        myHRP.CFrame = newCF
    else
        myHRP.CFrame = myHRP.CFrame:Lerp(newCF, Config.FaceLerp)
    end
    return true
end

local function fireBlock()
    if not BlockActivated then return false end
    local ok = pcall(function()
        BlockActivated:FireServer()
    end)
    return ok
end

local function fireRelease()
    if not BlockDeactivated then return false end
    local ok = pcall(function()
        BlockDeactivated:FireServer()
    end)
    return ok
end

-- ═══════════════════════════════════════════
-- AUTO BLOCK CORE
-- ═══════════════════════════════════════════
local activeBlockToken = 0

local function doAutoBlock(attacker)
    -- Cooldown check
    local now = tick()
    if now - State.LastBlock < (Config.BlockCooldownMs / 1000) then
        return false
    end
    
    -- Distance check
    local _, myHRP = getMyChar()
    if not myHRP then return false end
    
    local atkHRP = getAttackerHRP(attacker)
    if not atkHRP then
        log("⚠️ ผู้โจมตีไม่มี HRP")
        return false
    end
    
    local dist = (atkHRP.Position - myHRP.Position).Magnitude
    if dist > Config.MaxDistance then
        log(string.format("⏭️ ไกลเกินไป (%.1f studs)", dist))
        return false
    end
    
    -- Face attacker
    faceTo(atkHRP.Position)
    
    -- Fire block
    local ok = fireBlock()
    if not ok then
        State.Errors = State.Errors + 1
        return false
    end
    
    State.LastBlock = now
    State.BlockCount = State.BlockCount + 1
    State.LastAttacker = attacker.Name
    State.LastDistance = math.floor(dist)
    
    log(string.format("🚨 BLOCK #%d ← %s (%.1f studs)",
        State.BlockCount, attacker.Name, dist))
    
    -- Release after duration
    activeBlockToken = activeBlockToken + 1
    local myToken = activeBlockToken
    
    task.delay(Config.BlockDurationMs / 1000, function()
        if myToken == activeBlockToken then
            fireRelease()
        end
    end)
    
    return true
end

-- ═══════════════════════════════════════════
-- HOOK OnClientEvent
-- ═══════════════════════════════════════════
local conn = nil

local function start()
    if State.Enabled then return end
    
    conn = HitRemote.OnClientEvent:Connect(function(attacker)
        if not State.Enabled then return end
        
        -- กรองเฉพาะ Instance ที่เป็น Model
        if typeof(attacker) ~= "Instance" then return end
        if not attacker:IsA("Model") then return end
        
        -- ตัดตัวเอง
        if attacker.Name == LP.Name then return end
        
        -- Auto block
        pcall(doAutoBlock, attacker)
    end)
    
    State.Enabled = true
    log("✅ Auto Block เปิด")
    updateGui()
end

local function stop()
    if not State.Enabled then return end
    
    if conn then
        conn:Disconnect()
        conn = nil
    end
    
    -- Release block
    fireRelease()
    
    State.Enabled = false
    log("⛔ Auto Block ปิด")
    updateGui()
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local gui, mainBtn, statusLbl, statsLbl

function updateGui()
    if not mainBtn then return end
    if State.Enabled then
        mainBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        mainBtn.Text = "AUTO BLOCK\n🟢 ON"
        statusLbl.Text = "Status: Active"
        statusLbl.TextColor3 = Color3.fromRGB(100, 255, 100)
    else
        mainBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        mainBtn.Text = "AUTO BLOCK\n🔴 OFF"
        statusLbl.Text = "Status: Idle"
        statusLbl.TextColor3 = Color3.fromRGB(255, 150, 150)
    end
end

local function buildGui()
    local pg = LP:WaitForChild("PlayerGui")
    
    local old = pg:FindFirstChild("ABV2")
    if old then old:Destroy() end
    
    gui = Instance.new("ScreenGui")
    gui.Name = "ABV2"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg
    
    -- Main button
    mainBtn = Instance.new("TextButton")
    mainBtn.Size = UDim2.new(0, 140, 0, 70)
    mainBtn.Position = UDim2.new(0, 20, 0.4, 0)
    mainBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    mainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    mainBtn.Text = "AUTO BLOCK\n🔴 OFF"
    mainBtn.TextSize = 14
    mainBtn.Font = Enum.Font.GothamBold
    mainBtn.Parent = gui
    mainBtn.Active = true
    
    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 12)
    mc.Parent = mainBtn
    
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 2
    stroke.Transparency = 0.5
    stroke.Parent = mainBtn
    
    -- Status
    statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(0, 140, 0, 24)
    statusLbl.Position = UDim2.new(0, 20, 0.4, 74)
    statusLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    statusLbl.BackgroundTransparency = 0.3
    statusLbl.TextColor3 = Color3.fromRGB(255, 150, 150)
    statusLbl.Text = "Status: Idle"
    statusLbl.TextSize = 12
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.Parent = gui
    
    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0, 6)
    sc.Parent = statusLbl
    
    -- Stats
    statsLbl = Instance.new("TextLabel")
    statsLbl.Size = UDim2.new(0, 140, 0, 24)
    statsLbl.Position = UDim2.new(0, 20, 0.4, 100)
    statsLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    statsLbl.BackgroundTransparency = 0.3
    statsLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    statsLbl.Text = "Blocks: 0"
    statsLbl.TextSize = 11
    statsLbl.Font = Enum.Font.Code
    statsLbl.Parent = gui
    
    local stc = Instance.new("UICorner")
    stc.CornerRadius = UDim.new(0, 6)
    stc.Parent = statsLbl
    
    -- Click toggle
    mainBtn.MouseButton1Click:Connect(function()
        if State.Enabled then
            stop()
        else
            start()
        end
    end)
    
    -- Drag
    local dragging = false
    local dragStart, startPos
    mainBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainBtn.Position
        end
    end)
    mainBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                         or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainBtn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            -- Sync labels
            statusLbl.Position = UDim2.new(
                mainBtn.Position.X.Scale, mainBtn.Position.X.Offset,
                mainBtn.Position.Y.Scale, mainBtn.Position.Y.Offset + 74)
            statsLbl.Position = UDim2.new(
                mainBtn.Position.X.Scale, mainBtn.Position.X.Offset,
                mainBtn.Position.Y.Scale, mainBtn.Position.Y.Offset + 100)
        end
    end)
    
    -- Stats update loop
    task.spawn(function()
        while gui and gui.Parent do
            task.wait(0.5)
            if statsLbl then
                statsLbl.Text = string.format("Blocks: %d | Last: %s",
                    State.BlockCount,
                    State.LastAttacker or "-")
            end
        end
    end)
    
    updateGui()
end

buildGui()

-- ═══════════════════════════════════════════
-- AUTO START
-- ═══════════════════════════════════════════
if Config.AutoStart then
    start()
end

print("═══════════════════════════════════════════")
print("✅ Auto Block V2 | Handicap Edition")
print("   Trigger: HandicapService.RE.Hit")
print("   Action:  Face + Block")
print("   กดปุ่มเพื่อเปิด/ปิด")
print("═══════════════════════════════════════════")
