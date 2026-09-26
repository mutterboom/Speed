-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Auto Block V2.1 | Test Edition + Kill Switch                 ║
-- ║  Trigger: HandicapService.RE.Hit                              ║
-- ║  Action:  Face + Hold Block                                   ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- CONFIG
-- ═══════════════════════════════════════════
local Config = {
    -- ระยะสูงสุดที่จะ auto block
    MaxDistance = 25,
    
    -- ระยะเวลาที่ block ค้างไว้ (ms) หลัง trigger
    BlockHoldMs = 300,
    
    -- Fire Activated ซ้ำทุกกี่ ms (hold)
    ReFireIntervalMs = 50,
    
    -- Cooldown ระหว่าง trigger
    TriggerCooldownMs = 80,
    
    -- Face
    FaceLerp = 1.0,     -- 1.0 = หันทันที
    
    -- Debug
    Debug = true,
    Verbose = false,
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
    warn("[AB V2.1] ❌ ไม่เจอ HandicapService.RE.Hit")
    return
end
if not BlockActivated then
    warn("[AB V2.1] ❌ ไม่เจอ BlockService.RE.Activated")
    return
end

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    Enabled = false,
    Blocking = false,
    LastTrigger = 0,
    LastBlockFire = 0,
    TriggerCount = 0,
    BlockFireCount = 0,
    SkipCount = 0,
    LastAttacker = nil,
    LastDistance = 0,
    LastTriggerTime = 0,
    HitConn = nil,
    BlockThread = nil,
    Destroyed = false,
}

-- ═══════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════
local function log(...)
    if Config.Debug then
        local parts = {"[AB V2.1]"}
        for _, v in ipairs({...}) do
            table.insert(parts, tostring(v))
        end
        print(table.concat(parts, " "))
    end
end

local function getMyHRP()
    local char = LP.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function getAttackerHRP(attacker)
    if not attacker or typeof(attacker) ~= "Instance" then return nil end
    if attacker:IsA("Model") then
        return attacker:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function faceTo(targetPos)
    local myHRP = getMyHRP()
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
    return pcall(function() BlockActivated:FireServer() end)
end

local function fireRelease()
    if not BlockDeactivated then return false end
    return pcall(function() BlockDeactivated:FireServer() end)
end

-- ═══════════════════════════════════════════
-- BLOCK HOLD LOGIC
-- ═══════════════════════════════════════════
local function startBlockHold()
    -- ถ้ากำลัง block อยู่ ไม่ต้องเริ่มใหม่
    if State.Blocking then return end

    State.Blocking = true

    State.BlockThread = task.spawn(function()
        local startTime = tick()
        local holdSec = Config.BlockHoldMs / 1000
        local refireSec = Config.ReFireIntervalMs / 1000

        while State.Blocking 
              and State.Enabled 
              and not State.Destroyed
              and (tick() - startTime) < holdSec 
        do
            fireBlock()
            State.BlockFireCount = State.BlockFireCount + 1
            State.LastBlockFire = tick()
            task.wait(refireSec)
        end

        -- Release
        fireRelease()
        State.Blocking = false
        if Config.Verbose then
            log(string.format("🔓 Block released (fired %d times)", State.BlockFireCount))
        end
    end)
end

-- ═══════════════════════════════════════════
-- AUTO BLOCK TRIGGER
-- ═══════════════════════════════════════════
local function onHit(attacker)
    if State.Destroyed then return end
    if not State.Enabled then return end

    -- Cooldown check
    local now = tick()
    if now - State.LastTrigger < (Config.TriggerCooldownMs / 1000) then
        State.SkipCount = State.SkipCount + 1
        return
    end

    -- กรอง Instance
    if typeof(attacker) ~= "Instance" then
        State.SkipCount = State.SkipCount + 1
        return
    end
    if not attacker:IsA("Model") then
        State.SkipCount = State.SkipCount + 1
        return
    end
    if attacker.Name == LP.Name then
        State.SkipCount = State.SkipCount + 1
        return
    end

    -- Distance check
    local myHRP = getMyHRP()
    local atkHRP = getAttackerHRP(attacker)
    if not myHRP or not atkHRP then
        State.SkipCount = State.SkipCount + 1
        return
    end

    local dist = (atkHRP.Position - myHRP.Position).Magnitude
    if dist > Config.MaxDistance then
        State.SkipCount = State.SkipCount + 1
        return
    end

    -- ★★★ ทำ auto block ★★★
    State.LastTrigger = now
    State.TriggerCount = State.TriggerCount + 1
    State.LastAttacker = attacker.Name
    State.LastDistance = math.floor(dist)
    State.LastTriggerTime = os.date("%H:%M:%S")

    -- 1. หันหน้า
    faceTo(atkHRP.Position)

    -- 2. เริ่ม block hold
    startBlockHold()

    if Config.Debug then
        log(string.format("🚨 BLOCK #%d ← %s (%.1f studs)",
            State.TriggerCount, attacker.Name, dist))
    end
end

-- ═══════════════════════════════════════════
-- START / STOP
-- ═══════════════════════════════════════════
local function start()
    if State.Enabled or State.Destroyed then return end

    State.HitConn = HitRemote.OnClientEvent:Connect(onHit)

    State.Enabled = true
    log("🟢 Auto Block เปิด")
    updateGui()
end

local function stop()
    if not State.Enabled then return end

    if State.HitConn then
        State.HitConn:Disconnect()
        State.HitConn = nil
    end

    -- หยุด block thread
    State.Blocking = false
    if State.BlockThread then
        pcall(function() task.cancel(State.BlockThread) end)
        State.BlockThread = nil
    end

    fireRelease()
    State.Enabled = false
    log("🔴 Auto Block ปิด")
    updateGui()
end

-- ═══════════════════════════════════════════
-- KILL SWITCH — ปิดสคริปต์ทั้งหมด
-- ═══════════════════════════════════════════
local function destroy()
    log("💀 DESTROY — ปิดสคริปต์ทั้งหมด")

    State.Destroyed = true
    stop()

    -- disconnect ทั้งหมด
    if State.HitConn then
        pcall(function() State.HitConn:Disconnect() end)
        State.HitConn = nil
    end

    -- kill threads
    if State.BlockThread then
        pcall(function() task.cancel(State.BlockThread) end)
        State.BlockThread = nil
    end

    -- release block
    pcall(fireRelease)

    -- ลบ GUI
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local gui = pg:FindFirstChild("ABV21")
        if gui then
            pcall(function() gui:Destroy() end)
        end
    end

    -- clear global
    if _G.AB_V21 then
        _G.AB_V21 = nil
    end

    print("[AB V2.1] 💀 สคริปต์ถูกปิดแล้ว")
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local gui, mainBtn, statusLbl, statsLbl, killBtn

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

    local old = pg:FindFirstChild("ABV21")
    if old then old:Destroy() end

    gui = Instance.new("ScreenGui")
    gui.Name = "ABV21"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg

    -- Main button
    mainBtn = Instance.new("TextButton")
    mainBtn.Size = UDim2.new(0, 150, 0, 74)
    mainBtn.Position = UDim2.new(0, 20, 0.35, 0)
    mainBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    mainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    mainBtn.Text = "AUTO BLOCK\n🔴 OFF"
    mainBtn.TextSize = 15
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
    statusLbl.Size = UDim2.new(0, 150, 0, 24)
    statusLbl.Position = UDim2.new(0, 20, 0.35, 78)
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
    statsLbl.Size = UDim2.new(0, 150, 0, 56)
    statsLbl.Position = UDim2.new(0, 20, 0.35, 104)
    statsLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    statsLbl.BackgroundTransparency = 0.3
    statsLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    statsLbl.Text = "Triggers: 0\nBlock Fires: 0"
    statsLbl.TextSize = 11
    statsLbl.Font = Enum.Font.Code
    statsLbl.TextWrapped = true
    statsLbl.TextYAlignment = Enum.TextYAlignment.Top
    statsLbl.Parent = gui
    local stc = Instance.new("UICorner")
    stc.CornerRadius = UDim.new(0, 6)
    stc.Parent = statsLbl

    -- Kill Switch button
    killBtn = Instance.new("TextButton")
    killBtn.Size = UDim2.new(0, 150, 0, 34)
    killBtn.Position = UDim2.new(0, 20, 0.35, 164)
    killBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
    killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    killBtn.Text = "💀 ปิดสคริปต์"
    killBtn.TextSize = 12
    killBtn.Font = Enum.Font.GothamBold
    killBtn.Parent = gui

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(0, 8)
    kc.Parent = killBtn

    local kstroke = Instance.new("UIStroke")
    kstroke.Color = Color3.fromRGB(255, 50, 50)
    kstroke.Thickness = 1.5
    kstroke.Parent = killBtn

    -- Click handlers
    mainBtn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        if State.Enabled then stop() else start() end
    end)

    killBtn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        killBtn.Text = "💀 กำลังปิด..."
        task.wait(0.3)
        destroy()
    end)

    -- Drag
    local dragging, dragStart, startPos
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
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                         or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            mainBtn.Position = newPos
            -- sync
            statusLbl.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset,
                newPos.Y.Scale, newPos.Y.Offset + 78)
            statsLbl.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset,
                newPos.Y.Scale, newPos.Y.Offset + 104)
            killBtn.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset,
                newPos.Y.Scale, newPos.Y.Offset + 164)
        end
    end)

    -- Update loop
    task.spawn(function()
        while gui and gui.Parent and not State.Destroyed do
            task.wait(0.3)
            if statsLbl then
                statsLbl.Text = string.format(
                    "Triggers: %d\nBlock Fires: %d\nSkip: %d\nLast: %s | %.0f studs",
                    State.TriggerCount,
                    State.BlockFireCount,
                    State.SkipCount,
                    State.LastAttacker or "-",
                    State.LastDistance)
            end
        end
    end)

    updateGui()
end

buildGui()

-- ═══════════════════════════════════════════
-- AUTO-START (optional)
-- ═══════════════════════════════════════════
-- start()  -- เปิด comment ถ้าอยากให้เปิดอัตโนมัติ

-- Export API
_G.AB_V21 = {
    start = start,
    stop = stop,
    destroy = destroy,
    state = State,
    config = Config,
}

print("═══════════════════════════════════════════")
print("✅ Auto Block V2.1 | Test Edition")
print("   Trigger: HandicapService.RE.Hit")
print("   Action:  Face + Hold Block 300ms")
print("   Config:")
print(string.format("     MaxDistance: %d studs", Config.MaxDistance))
print(string.format("     BlockHold: %d ms", Config.BlockHoldMs))
print(string.format("     ReFireInterval: %d ms", Config.ReFireIntervalMs))
print("   GUI: กดปุ่ม AUTO BLOCK เพื่อเปิด/ปิด")
print("   API: _G.AB_V21.start() / .stop() / .destroy()")
print("═══════════════════════════════════════════")
