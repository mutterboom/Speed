-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  AB Test Suite V3.0 | Menu Edition                            ║
-- ║  - ปุ่มเริ่ม/หยุด test                                        ║
-- ║  - ปุ่มเซฟไฟล์                                                 ║
-- ║  - Live status                                                 ║
-- ║  - Manual trigger tests                                        ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- LOGGER
-- ═══════════════════════════════════════════
local Logger = {
    Lines = {},
    Enabled = false,
    FilePath = "ABTestV3_" .. os.date("%Y%m%d_%H%M%S") .. ".txt",
    RawDumpPath = "ABTestV3_raw_" .. os.date("%Y%m%d_%H%M%S") .. ".json",
    RawDumps = {},
    SessionActive = false,
}

local _writeFn = writefile or write_file
local _appendFn = appendfile or append_file

local function _write(path, data)
    if _writeFn then return pcall(_writeFn, path, data) end
    return false
end

local function _append(path, data)
    if _appendFn then return pcall(_appendFn, path, data) end
    return false
end

local function log(...)
    local parts = {}
    for i, v in ipairs({...}) do
        parts[i] = tostring(v)
    end
    local line = table.concat(parts, " ")
    print("[AB V3]", line)
    table.insert(Logger.Lines, line)
    if Logger.Enabled and Logger.SessionActive then
        _append(Logger.FilePath, line .. "\n")
    end
end

local function section(title)
    log("")
    log("════════ " .. title .. " ════════")
end

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

local BlockRemote = findRemote("Knit.Knit.Services.BlockService.RE.Activated")
local BlockDeact = findRemote("Knit.Knit.Services.BlockService.RE.Deactivated")
local HitRemote = findRemote("Knit.Knit.Services.HandicapService.RE.Hit")

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    Running = false,
    LastBlockTime = 0,
    BlockCount = 0,
    HitCount = 0,
    LastTest = "-",
    HitConn = nil,
}

-- ═══════════════════════════════════════════
-- SNAPSHOT
-- ═══════════════════════════════════════════
local function takeSnapshot()
    local snap = { time = tick(), timeStr = os.date("%H:%M:%S.%3f") }
    local char = LP.Character
    if not char then return snap end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        snap.humanoid = {
            state = tostring(hum:GetState()),
            health = hum.Health,
            platformStand = hum.PlatformStand,
            sit = hum.Sit,
            walkSpeed = hum.WalkSpeed,
        }
    end

    snap.animations = {}
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                table.insert(snap.animations, {
                    name = t.Animation.Name,
                    id = t.Animation.AnimationId,
                    weight = t.WeightCurrent,
                })
            end
        end
    end

    snap.sounds = {}
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Sound") and obj.Playing then
            table.insert(snap.sounds, {
                name = obj.Name,
                soundId = obj.SoundId,
            })
        end
    end

    snap.attributes = {}
    local ok, attrs = pcall(function() return char:GetAttributes() end)
    if ok and attrs then
        for _, name in ipairs(attrs) do
            snap.attributes[name] = tostring(char:GetAttribute(name))
        end
    end

    return snap
end

local function diffSnap(before, after)
    local diffs = {}
    if before.humanoid and after.humanoid then
        for k, v in pairs(after.humanoid) do
            if before.humanoid[k] ~= v then
                table.insert(diffs, string.format("hum.%s: %s → %s",
                    k, tostring(before.humanoid[k]), tostring(v)))
            end
        end
    end

    local beforeAnims = {}
    for _, a in ipairs(before.animations or {}) do
        beforeAnims[a.name .. "|" .. a.id] = a
    end
    for _, a in ipairs(after.animations or {}) do
        if not beforeAnims[a.name .. "|" .. a.id] then
            table.insert(diffs, string.format("anim+ %s (%s)", a.name, a.id))
        end
    end

    local beforeSounds = {}
    for _, s in ipairs(before.sounds or {}) do
        beforeSounds[s.name .. "|" .. s.soundId] = s
    end
    for _, s in ipairs(after.sounds or {}) do
        if not beforeSounds[s.name .. "|" .. s.soundId] then
            table.insert(diffs, string.format("sound+ %s (%s)", s.name, s.soundId))
        end
    end

    return diffs
end

local function printSnap(label, snap)
    log(string.format("  [%s] %s", label, snap.timeStr or "?"))
    if snap.humanoid then
        log(string.format("    state=%s hp=%.0f walkSpeed=%.0f",
            snap.humanoid.state,
            snap.humanoid.health,
            snap.humanoid.walkSpeed))
    end
    if #(snap.sounds or {}) > 0 then
        local s = {}
        for _, snd in ipairs(snap.sounds) do
            table.insert(s, snd.name)
        end
        log("    sounds: [" .. table.concat(s, ", ") .. "]")
    end
end

-- ═══════════════════════════════════════════
-- TESTS
-- ═══════════════════════════════════════════
local function runTest(name, actionFn, waitTime)
    waitTime = waitTime or 1.0
    section(name)
    State.LastTest = name

    local before = takeSnapshot()
    log("─── BEFORE ───")
    printSnap("before", before)

    log("─── ACTION ───")
    local ok, err = pcall(actionFn)
    log("  action: " .. (ok and "OK" or ("FAIL: " .. tostring(err))))

    task.wait(0.15)
    local snap100 = takeSnapshot()
    log("─── +150ms ───")
    printSnap("+150ms", snap100)

    task.wait(waitTime - 0.15)
    local snapEnd = takeSnapshot()
    log("─── +" .. math.floor(waitTime * 1000) .. "ms ───")
    printSnap("end", snapEnd)

    log("─── DIFFS ───")
    local d1 = diffSnap(before, snap100)
    if #d1 > 0 then
        for _, d in ipairs(d1) do log("  " .. d) end
    else
        log("  [+150ms] ไม่เปลี่ยน")
    end

    local d2 = diffSnap(before, snapEnd)
    if #d2 > 0 then
        for _, d in ipairs(d2) do log("  " .. d) end
    else
        log("  [end] ไม่เปลี่ยน")
    end

    table.insert(Logger.RawDumps, {
        test = name, before = before,
        after100 = snap100, afterEnd = snapEnd,
        diffs100 = d1, diffsEnd = d2,
    })

    section("จบ " .. name)
    task.wait(0.5)
end

-- Test functions
local TESTS = {
    {
        name = "T1: Keyboard F hold 1s",
        fn = function()
            VirtualInputManager:SendKeyEvent(true, "F", false, game)
            task.wait(1.0)
            VirtualInputManager:SendKeyEvent(false, "F", false, game)
        end,
        wait = 2.0,
    },
    {
        name = "T2: Remote Activated bare",
        fn = function()
            if BlockRemote then BlockRemote:FireServer() end
        end,
        wait = 2.0,
    },
    {
        name = "T3: Remote Activated hold 1s",
        fn = function()
            if not BlockRemote then return end
            local t0 = tick()
            while tick() - t0 < 1 do
                BlockRemote:FireServer()
                task.wait(0.05)
            end
            if BlockDeact then BlockDeact:FireServer() end
        end,
        wait = 2.0,
    },
    {
        name = "T4: Keyboard F + Remote (combo)",
        fn = function()
            VirtualInputManager:SendKeyEvent(true, "F", false, game)
            if BlockRemote then BlockRemote:FireServer() end
            task.wait(0.5)
            VirtualInputManager:SendKeyEvent(false, "F", false, game)
            if BlockDeact then BlockDeact:FireServer() end
        end,
        wait = 2.0,
    },
    {
        name = "T5: Hold remote 3s (sustained)",
        fn = function()
            if not BlockRemote then return end
            local t0 = tick()
            while tick() - t0 < 3 do
                BlockRemote:FireServer()
                task.wait(0.05)
            end
            if BlockDeact then BlockDeact:FireServer() end
        end,
        wait = 4.0,
    },
}

-- ═══════════════════════════════════════════
-- RUN ALL TESTS
-- ═══════════════════════════════════════════
local function runAllTests()
    if State.Running then
        log("⚠️ กำลังรันอยู่")
        return
    end
    State.Running = true
    Logger.Enabled = true
    Logger.SessionActive = true

    log("")
    log("═══════════════════════════════════════")
    log("🚀 เริ่ม test session")
    log("  File: " .. Logger.FilePath)
    log("  Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    log("═══════════════════════════════════════")

    task.spawn(function()
        for _, test in ipairs(TESTS) do
            if not State.Running then break end
            runTest(test.name, test.fn, test.wait)
        end

        State.Running = false
        log("")
        log("═══════════════════════════════════════")
        log("✅ Test session เสร็จ")
        log("  Hits: " .. State.HitCount)
        log("  Blocks: " .. State.BlockCount)
        log("═══════════════════════════════════════")

        saveSession()
    end)
end

function saveSession()
    -- Save text log
    local h = {
        "═══════════════════════════════════════════",
        "  AB Test V3.0 Log",
        "  Started: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "  PlaceId: " .. tostring(game.PlaceId),
        "  Player:  " .. LP.Name,
        "═══════════════════════════════════════════",
        "",
    }
    _write(Logger.FilePath, table.concat(h, "\n") .. "\n" .. table.concat(Logger.Lines, "\n"))

    -- Save raw JSON
    local raw = HttpService:JSONEncode({
        meta = {
            version = "3.0",
            time = os.date("%Y-%m-%d %H:%M:%S"),
            placeId = game.PlaceId,
            jobId = game.JobId,
            player = LP.Name,
            hits = State.HitCount,
            blocks = State.BlockCount,
        },
        tests = Logger.RawDumps,
    })
    _write(Logger.RawDumpPath, raw)

    log("💾 Save 2 files:")
    log("   " .. Logger.FilePath)
    log("   " .. Logger.RawDumpPath)
end

function stopSession()
    State.Running = false
    Logger.SessionActive = false
    log("⛔ หยุด test")
    saveSession()
end

-- ═══════════════════════════════════════════
-- HIT REMOTE LISTENER
-- ═══════════════════════════════════════════
if HitRemote then
    State.HitConn = HitRemote.OnClientEvent:Connect(function(attacker)
        State.HitCount = State.HitCount + 1
        local name = typeof(attacker) == "Instance"
            and (attacker:IsA("Model") and attacker.Name or attacker:GetFullName())
            or tostring(attacker)
        if Logger.SessionActive then
            log(string.format("⚔️ Hit #%d ← %s", State.HitCount, name))
        end
    end)
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local function buildGui()
    local pg = LP:WaitForChild("PlayerGui")

    local old = pg:FindFirstChild("ABTestV3")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ABTestV3"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 380)
    frame.Position = UDim2.new(0, 20, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    title.Text = "🧪 AB Test V3.0"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = frame
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 12)
    tc.Parent = title

    -- Buttons layout
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame
    layout.Padding = UDim.new(0, 8)

    local padTop = Instance.new("Frame")
    padTop.Size = UDim2.new(1, 0, 0, 45)
    padTop.BackgroundTransparency = 1
    padTop.LayoutOrder = 0
    padTop.Parent = frame

    -- Button maker
    local function makeBtn(text, color, order, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, 42)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Text = text
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 13
        b.LayoutOrder = order
        b.Parent = frame
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 8)
        bc.Parent = b
        b.MouseButton1Click:Connect(function()
            b.BackgroundColor3 = color:Lerp(Color3.new(1,1,1), 0.3)
            task.delay(0.15, function()
                if b then b.BackgroundColor3 = color end
            end)
            pcall(onClick)
        end)
        return b
    end

    makeBtn("▶  เริ่มทดสอบทั้งหมด", Color3.fromRGB(50, 160, 50), 1, runAllTests)

    makeBtn("⛔  หยุด", Color3.fromRGB(180, 50, 50), 2, stopSession)

    makeBtn("💾  เซฟไฟล์", Color3.fromRGB(50, 100, 180), 3, function()
        saveSession()
    end)

    -- Individual tests
    local i = 4
    for idx, test in ipairs(TESTS) do
        makeBtn("▸ " .. test.name, Color3.fromRGB(80, 80, 120), i, function()
            if State.Running then return end
            Logger.Enabled = true
            Logger.SessionActive = true
            task.spawn(function()
                runTest(test.name, test.fn, test.wait)
                saveSession()
            end)
        end)
        i = i + 1
    end

    -- Status label
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 50)
    status.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    status.TextColor3 = Color3.fromRGB(200, 200, 200)
    status.Text = "Status: Idle"
    status.Font = Enum.Font.Code
    status.TextSize = 11
    status.TextWrapped = true
    status.LayoutOrder = 20
    status.Parent = frame
    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0, 6)
    sc.Parent = status

    -- Update loop
    task.spawn(function()
        while gui.Parent do
            task.wait(0.5)
            status.Text = string.format(
                "Status: %s\nHits: %d | Blocks: %d\nLast: %s",
                State.Running and "🟢 Running" or "⚪ Idle",
                State.HitCount,
                State.BlockCount,
                State.LastTest)
        end
    end)

    -- Drag
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                         or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

buildGui()

print("═══════════════════════════════════════════")
print("✅ AB Test Suite V3.0 | Menu Edition")
print("📁 Log: " .. Logger.FilePath)
print("📁 Raw: " .. Logger.RawDumpPath)
print("   กด ▶ เริ่มทดสอบทั้งหมด")
print("═══════════════════════════════════════════")
