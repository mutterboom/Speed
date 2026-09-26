-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Auto Block V2.2 | Debug Edition                              ║
-- ║  - Debug ทุกขั้นตอน                                          ║
-- ║  - Verbose log                                                ║
-- ║  - Fix: args handling + cooldown                              ║
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
    MaxDistance = 50,          -- ★ เพิ่มเป็น 50 (เผื่อผู้ตีอยู่ไกล)
    BlockHoldMs = 400,         -- ★ เพิ่มเป็น 400
    ReFireIntervalMs = 40,     -- ★ เร็วขึ้น
    TriggerCooldownMs = 30,    -- ★ ลดเป็น 30
    FaceLerp = 1.0,
    Debug = true,
    Verbose = true,            -- ★ เปิด verbose
    LogSkips = true,           -- ★ log ทุก skip + เหตุผล
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
    warn("[AB V2.2] ❌ ไม่เจอ HitRemote")
    return
end

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    Enabled = false,
    Blocking = false,
    LastTrigger = 0,
    TriggerCount = 0,
    BlockFireCount = 0,
    SkipCount = 0,
    LastAttacker = nil,
    LastDistance = 0,
    LastSkipReason = nil,
    HitConn = nil,
    BlockThread = nil,
    Destroyed = false,
    AllHits = {},          -- ★ เก็บทุก hit ดิบ
}

-- ═══════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════
local function log(...)
    if Config.Debug then
        local parts = {"[AB V2.2]"}
        for _, v in ipairs({...}) do
            table.insert(parts, tostring(v))
        end
        print(table.concat(parts, " "))
    end
end

local function logSkip(reason)
    State.SkipCount = State.SkipCount + 1
    State.LastSkipReason = reason
    if Config.LogSkips then
        log("⏭️  SKIP:", reason)
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
-- BLOCK HOLD
-- ═══════════════════════════════════════════
local function startBlockHold()
    if State.Blocking then
        if Config.Verbose then log("(block already active)") end
        return
    end

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
            task.wait(refireSec)
        end

        fireRelease()
        State.Blocking = false
    end)
end

-- ═══════════════════════════════════════════
-- AUTO BLOCK — Debug ทุกขั้นตอน
-- ═══════════════════════════════════════════
local function onHit(...)
    if State.Destroyed then return end

    -- ★★★ เก็บ args ดิบทุกครั้ง ★★★
    local rawArgs = {...}
    table.insert(State.AllHits, {
        time = os.date("%H:%M:%S.%3f"),
        tick = tick(),
        argCount = #rawArgs,
        argTypes = (function()
            local t = {}
            for i, v in ipairs(rawArgs) do
                t[i] = typeof(v) .. (typeof(v) == "Instance" and (":" .. v.ClassName) or "")
            end
            return t
        end)(),
    })
    if #State.AllHits > 100 then table.remove(State.AllHits, 1) end

    -- Verbose: log ทุก hit ที่เข้ามา
    if Config.Verbose then
        local sig = {}
        for i, v in ipairs(rawArgs) do
            local vt = typeof(v)
            if vt == "Instance" then
                table.insert(sig, string.format("arg%d=%s:%s", i, v.ClassName, v.Name))
            else
                table.insert(sig, string.format("arg%d=%s:%s", i, vt, tostring(v):sub(1,30)))
            end
        end
        log("📥 HIT:", table.concat(sig, " | "))
    end

    if not State.Enabled then
        if Config.Verbose then log("  (disabled — ignore)") end
        return
    end

    -- ★★★ หา Instance ใน args ทุกตัว ★★★
    local attacker = nil
    for i, v in ipairs(rawArgs) do
        if typeof(v) == "Instance" then
            if v:IsA("Model") then
                -- Model = candidate
                attacker = v
                break
            end
        end
    end

    if not attacker then
        logSkip("no Model in args")
        return
    end

    -- Skip: ตัวเอง
    if attacker.Name == LP.Name then
        logSkip("attacker = self")
        return
    end

    -- Skip: ผู้เล่น
    if Players:GetPlayerFromCharacter(attacker) then
        local plr = Players:GetPlayerFromCharacter(attacker)
        if plr == LP then
            logSkip("attacker player = self")
            return
        end
    end

    -- Cooldown
    local now = tick()
    local since = now - State.LastTrigger
    if since < (Config.TriggerCooldownMs / 1000) then
        logSkip(string.format("cooldown (%.0fms < %dms)",
            since * 1000, Config.TriggerCooldownMs))
        return
    end

    -- HRP check
    local myHRP = getMyHRP()
    local atkHRP = getAttackerHRP(attacker)

    if not myHRP then
        logSkip("no myHRP")
        return
    end
    if not atkHRP then
        logSkip("no atkHRP (attacker=" .. attacker.Name .. ")")
        return
    end

    -- Distance
    local dist = (atkHRP.Position - myHRP.Position).Magnitude
    if dist > Config.MaxDistance then
        logSkip(string.format("too far (%.1f > %d)", dist, Config.MaxDistance))
        return
    end

    -- ★★★ PASS — ทำ Auto Block ★★★
    State.LastTrigger = now
    State.TriggerCount = State.TriggerCount + 1
    State.LastAttacker = attacker.Name
    State.LastDistance = math.floor(dist)
    State.LastSkipReason = nil

    -- 1. หันหน้า
    faceTo(atkHRP.Position)

    -- 2. Block hold
    startBlockHold()

    log(string.format("🚨 BLOCK #%d ← %s (%.1f studs)",
        State.TriggerCount, attacker.Name, dist))
end

-- ═══════════════════════════════════════════
-- START / STOP
-- ═══════════════════════════════════════════
local function start()
    if State.Enabled or State.Destroyed then return end
    State.HitConn = HitRemote.OnClientEvent:Connect(onHit)
    State.Enabled = true
    log("🟢 Auto Block เปิด")
    if updateGui then updateGui() end
end

local function stop()
    if not State.Enabled then return end
    if State.HitConn then
        State.HitConn:Disconnect()
        State.HitConn = nil
    end
    State.Blocking = false
    if State.BlockThread then
        pcall(function() task.cancel(State.BlockThread) end)
        State.BlockThread = nil
    end
    fireRelease()
    State.Enabled = false
    log("🔴 Auto Block ปิด")
    if updateGui then updateGui() end
end

local function destroy()
    log("💀 DESTROY")
    State.Destroyed = true
    stop()
    if State.HitConn then
        pcall(function() State.HitConn:Disconnect() end)
    end
    if State.BlockThread then
        pcall(function() task.cancel(State.BlockThread) end)
    end
    pcall(fireRelease)
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local g = pg:FindFirstChild("ABV22")
        if g then pcall(function() g:Destroy() end) end
    end
    _G.AB_V22 = nil
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local gui, mainBtn, statusLbl, statsLbl, hitsLbl, killBtn

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
    local old = pg:FindFirstChild("ABV22")
    if old then old:Destroy() end

    gui = Instance.new("ScreenGui")
    gui.Name = "ABV22"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg

    mainBtn = Instance.new("TextButton")
    mainBtn.Size = UDim2.new(0, 170, 0, 74)
    mainBtn.Position = UDim2.new(0, 20, 0.3, 0)
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

    statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(0, 170, 0, 24)
    statusLbl.Position = UDim2.new(0, 20, 0.3, 78)
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

    statsLbl = Instance.new("TextLabel")
    statsLbl.Size = UDim2.new(0, 170, 0, 68)
    statsLbl.Position = UDim2.new(0, 20, 0.3, 104)
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

    -- Hits log panel
    hitsLbl = Instance.new("TextLabel")
    hitsLbl.Size = UDim2.new(0, 170, 0, 80)
    hitsLbl.Position = UDim2.new(0, 20, 0.3, 176)
    hitsLbl.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    hitsLbl.BackgroundTransparency = 0.3
    hitsLbl.TextColor3 = Color3.fromRGB(150, 200, 255)
    hitsLbl.Text = "Hits: 0"
    hitsLbl.TextSize = 10
    hitsLbl.Font = Enum.Font.Code
    hitsLbl.TextWrapped = true
    hitsLbl.TextYAlignment = Enum.TextYAlignment.Top
    hitsLbl.TextXAlignment = Enum.TextXAlignment.Left
    hitsLbl.Parent = gui
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0, 6)
    hc.Parent = hitsLbl

    killBtn = Instance.new("TextButton")
    killBtn.Size = UDim2.new(0, 170, 0, 34)
    killBtn.Position = UDim2.new(0, 20, 0.3, 260)
    killBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
    killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    killBtn.Text = "💀 ปิดสคริปต์"
    killBtn.TextSize = 12
    killBtn.Font = Enum.Font.GothamBold
    killBtn.Parent = gui

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(0, 8)
    kc.Parent = killBtn

    mainBtn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        if State.Enabled then stop() else start() end
    end)

    killBtn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        killBtn.Text = "💀 ปิด..."
        task.wait(0.2)
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
            local np = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            mainBtn.Position = np
            statusLbl.Position = UDim2.new(np.X.Scale, np.X.Offset, np.Y.Scale, np.Y.Offset + 78)
            statsLbl.Position = UDim2.new(np.X.Scale, np.X.Offset, np.Y.Scale, np.Y.Offset + 104)
            hitsLbl.Position = UDim2.new(np.X.Scale, np.X.Offset, np.Y.Scale, np.Y.Offset + 176)
            killBtn.Position = UDim2.new(np.X.Scale, np.X.Offset, np.Y.Scale, np.Y.Offset + 260)
        end
    end)

    -- Update loop
    task.spawn(function()
        while gui and gui.Parent and not State.Destroyed do
            task.wait(0.3)
            if statsLbl then
                statsLbl.Text = string.format(
                    "Triggers: %d\nFires: %d | Skip: %d\nReason: %s\nLast: %s | %.0f",
                    State.TriggerCount,
                    State.BlockFireCount,
                    State.SkipCount,
                    State.LastSkipReason or "-",
                    State.LastAttacker or "-",
                    State.LastDistance)
            end
            if hitsLbl then
                local lines = {}
                local total = #State.AllHits
                local start = math.max(1, total - 5)
                for i = start, total do
                    local h = State.AllHits[i]
                    table.insert(lines, string.format("[%s] %s",
                        h.time,
                        table.concat(h.argTypes or {}, ",")))
                end
                hitsLbl.Text = "📥 Hits (" .. total .. "):\n" ..
                    table.concat(lines, "\n")
            end
        end
    end)

    updateGui()
end

buildGui()

_G.AB_V22 = {
    start = start,
    stop = stop,
    destroy = destroy,
    state = State,
    config = Config,
}

print("═══════════════════════════════════════════")
print("✅ Auto Block V2.2 | Debug Edition")
print("   MaxDistance:", Config.MaxDistance)
print("   BlockHoldMs:", Config.BlockHoldMs)
print("   TriggerCooldown:", Config.TriggerCooldownMs)
print("   GUI แสดง Hits ล่าสุด 5 ครั้ง")
print("═══════════════════════════════════════════")
