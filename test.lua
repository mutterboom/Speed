-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Full Test Suite V4.0 | Complete Edition                      ║
-- ║  - Hit Remote Probe (args + timing)                           ║
-- ║  - Block Mechanism Test                                       ║
-- ║  - Deep Snapshot                                              ║
-- ║  - File Logger                                                ║
-- ║  - GUI: Start / Stop / Save / Kill                            ║
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
    FilePath = "FullTest_" .. os.date("%Y%m%d_%H%M%S") .. ".txt",
    RawPath = "FullTest_raw_" .. os.date("%Y%m%d_%H%M%S") .. ".json",
    RawData = { hits = {}, tests = {}, snapshots = {} },
    Enabled = false,
}

local _writeFn = writefile or write_file
local _appendFn = appendfile or append_file

local function _write(path, data)
    if _writeFn then return pcall(_writeFn, path, data) end
end

local function _append(path, data)
    if _appendFn then return pcall(_appendFn, path, data) end
    if _writeFn and readfile then
        local ok, old = pcall(readfile, path)
        return pcall(_writeFn, path, (ok and old or "") .. data)
    end
end

local function log(...)
    local parts = {}
    for i, v in ipairs({...}) do
        parts[i] = tostring(v)
    end
    local line = table.concat(parts, " ")
    print("[FT4.0]", line)
    table.insert(Logger.Lines, line)
    if Logger.Enabled then
        _append(Logger.FilePath, line .. "\n")
    end
end

local function section(t)
    log("")
    log("════════ " .. t .. " ════════")
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

local HitRemote       = findRemote("Knit.Knit.Services.HandicapService.RE.Hit")
local BlockActivated  = findRemote("Knit.Knit.Services.BlockService.RE.Activated")
local BlockDeactivated= findRemote("Knit.Knit.Services.BlockService.RE.Deactivated")

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    Running = false,
    Destroyed = false,
    HitConn = nil,
    TestThread = nil,

    -- Counters
    HitCount = 0,
    BlockCount = 0,
    TestCount = 0,
    SkipCount = 0,

    -- Last event
    LastHit = nil,
    LastTest = nil,
    LastError = nil,

    -- Recent hits (display)
    RecentHits = {},
}

-- ═══════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════
local function getMyChar()
    local c = LP.Character
    if not c then return nil, nil end
    return c, c:FindFirstChild("HumanoidRootPart")
end

local function getHRP(model)
    if not model or typeof(model) ~= "Instance" then return nil end
    if model:IsA("Model") then
        return model:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- ═══════════════════════════════════════════
-- SNAPSHOT
-- ═══════════════════════════════════════════
local function takeSnapshot()
    local snap = {
        time = tick(),
        timeStr = os.date("%H:%M:%S.%3f"),
    }

    local char = LP.Character
    if not char then return snap end

    -- Humanoid
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        snap.humanoid = {
            state = tostring(hum:GetState()),
            health = hum.Health,
            maxHealth = hum.MaxHealth,
            walkSpeed = hum.WalkSpeed,
            jumpPower = hum.JumpPower,
            platformStand = hum.PlatformStand,
            sit = hum.Sit,
        }
    end

    -- Animations
    snap.animations = {}
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                table.insert(snap.animations, {
                    name = t.Animation.Name,
                    id = t.Animation.AnimationId,
                    weight = t.WeightCurrent,
                    speed = t.Speed,
                })
            end
        end
    end

    -- Sounds
    snap.sounds = {}
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Sound") and obj.Playing then
            table.insert(snap.sounds, {
                name = obj.Name,
                soundId = obj.SoundId,
                volume = obj.Volume,
            })
        end
    end

    -- Attributes
    snap.attributes = {}
    local ok, attrs = pcall(function() return char:GetAttributes() end)
    if ok and attrs then
        for _, name in ipairs(attrs) do
            snap.attributes[name] = tostring(char:GetAttribute(name))
        end
    end

    -- Block-related parts
    snap.blockParts = {}
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            local lower = obj.Name:lower()
            if lower:find("block") or lower:find("guard")
               or lower:find("shield") or lower:find("barrier") then
                table.insert(snap.blockParts, {
                    name = obj.Name,
                    transparency = obj.Transparency,
                    visible = obj.Transparency < 1,
                })
            end
        end
    end

    -- Position
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        snap.position = {
            x = math.floor(hrp.Position.X),
            y = math.floor(hrp.Position.Y),
            z = math.floor(hrp.Position.Z),
        }
    end

    return snap
end

-- ═══════════════════════════════════════════
-- DIFF SNAPSHOTS
-- ═══════════════════════════════════════════
local function diffSnap(a, b)
    local diffs = {}
    if a.humanoid and b.humanoid then
        for k, v in pairs(b.humanoid) do
            if a.humanoid[k] ~= v then
                table.insert(diffs, string.format("hum.%s: %s → %s",
                    k, tostring(a.humanoid[k]), tostring(v)))
            end
        end
    end

    -- anims
    local aa, ba = {}, {}
    for _, x in ipairs(a.animations or {}) do aa[x.name .. "|" .. x.id] = x end
    for _, x in ipairs(b.animations or {}) do ba[x.name .. "|" .. x.id] = x end
    for k, x in pairs(ba) do
        if not aa[k] then
            table.insert(diffs, string.format("anim+ %s (%s)", x.name, x.id))
        end
    end
    for k, x in pairs(aa) do
        if not ba[k] then
            table.insert(diffs, string.format("anim- %s", x.name))
        end
    end

    -- sounds
    local as, bs = {}, {}
    for _, x in ipairs(a.sounds or {}) do as[x.name .. "|" .. x.soundId] = x end
    for _, x in ipairs(b.sounds or {}) do bs[x.name .. "|" .. x.soundId] = x end
    for k, x in pairs(bs) do
        if not as[k] then
            table.insert(diffs, string.format("sound+ %s (%s)", x.name, x.soundId))
        end
    end

    -- attributes
    for k, v in pairs(b.attributes or {}) do
        if (a.attributes or {})[k] ~= v then
            table.insert(diffs, string.format("attr.%s: %s → %s",
                k, tostring((a.attributes or {})[k]), tostring(v)))
        end
    end

    return diffs
end

local function printSnapshot(label, snap)
    log(string.format("  [%s] %s", label, snap.timeStr))
    if snap.humanoid then
        log(string.format("    hum.state=%s hp=%.0f walkSpeed=%.0f",
            snap.humanoid.state,
            snap.humanoid.health,
            snap.humanoid.walkSpeed))
    end
    if #(snap.animations or {}) > 0 then
        local n = {}
        for _, a in ipairs(snap.animations) do table.insert(n, a.name) end
        log("    anims: [" .. table.concat(n, ", ") .. "]")
    end
    if #(snap.sounds or {}) > 0 then
        local n = {}
        for _, s in ipairs(snap.sounds) do table.insert(n, s.name) end
        log("    sounds: [" .. table.concat(n, ", ") .. "]")
    end
    if snap.position then
        log(string.format("    pos: %d,%d,%d",
            snap.position.x, snap.position.y, snap.position.z))
    end
end

-- ═══════════════════════════════════════════
-- HIT REMOTE PROBE
-- ═══════════════════════════════════════════
local function serializeArg(v)
    local t = typeof(v)
    if t == "Instance" then
        return {
            type = "Instance",
            class = v.ClassName,
            name = v.Name,
            path = v:GetFullName(),
            isModel = v:IsA("Model"),
            isPlayerChar = Players:GetPlayerFromCharacter(v) ~= nil,
        }
    elseif t == "Vector3" then
        return { type = "Vector3",
            x = math.floor(v.X), y = math.floor(v.Y), z = math.floor(v.Z) }
    else
        return { type = t, value = tostring(v):sub(1, 200) }
    end
end

local function onHit(...)
    if State.Destroyed then return end

    State.HitCount = State.HitCount + 1
    local args = {...}

    local serialized = {}
    for i, v in ipairs(args) do
        serialized[i] = serializeArg(v)
    end

    -- เก็บข้อมูล
    local entry = {
        index = State.HitCount,
        time = os.date("%H:%M:%S.%3f"),
        tick = tick(),
        argCount = #args,
        args = serialized,
    }
    table.insert(Logger.RawData.hits, entry)
    if #Logger.RawData.hits > 200 then
        table.remove(Logger.RawData.hits, 1)
    end

    -- GUI display
    table.insert(State.RecentHits, entry)
    if #State.RecentHits > 8 then
        table.remove(State.RecentHits, 1)
    end

    -- Log
    if Logger.Enabled then
        log(string.format("⚔️ HIT #%d [%s] args=%d",
            State.HitCount, entry.time, #args))
        for i, s in ipairs(serialized) do
            if s.type == "Instance" then
                log(string.format("    arg[%d] %s:%s | isModel=%s | path=%s",
                    i, s.class, s.name, tostring(s.isModel), s.path))
            else
                log(string.format("    arg[%d] %s = %s",
                    i, s.type, s.value))
            end
        end

        -- Distance
        local _, myHRP = getMyChar()
        if myHRP then
            for i, v in ipairs(args) do
                if typeof(v) == "Instance" and v:IsA("Model") then
                    local h = getHRP(v)
                    if h then
                        local d = (h.Position - myHRP.Position).Magnitude
                        log(string.format("    arg[%d] dist=%.1f studs", i, d))
                    end
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════
-- BLOCK MECHANISM TESTS
-- ═══════════════════════════════════════════
local function runBlockTest(name, actionFn, waitTime)
    if State.Destroyed then return end

    State.TestCount = State.TestCount + 1
    State.LastTest = name
    section(string.format("TEST #%d: %s", State.TestCount, name))

    -- BEFORE
    local before = takeSnapshot()
    log("─── BEFORE ───")
    printSnapshot("before", before)

    -- ACTION
    log("─── ACTION ───")
    local ok, err = pcall(actionFn)
    log("  action: " .. (ok and "OK" or ("FAIL: " .. tostring(err))))

    -- Track at intervals
    local snaps = { before = before }
    local intervals = { 0.1, 0.3, 0.6, 1.0 }
    local elapsed = 0

    for _, t in ipairs(intervals) do
        if t > (waitTime or 1.0) then break end
        task.wait(t - elapsed)
        elapsed = t
        local snap = takeSnapshot()
        snaps["at_" .. t] = snap
        log(string.format("─── +%dms ───", math.floor(t * 1000)))
        printSnapshot("+" .. math.floor(t * 1000) .. "ms", snap)
    end

    -- DIFFS
    log("─── DIFFS (vs BEFORE) ───")
    local allDiffs = {}
    for key, snap in pairs(snaps) do
        if key ~= "before" then
            local d = diffSnap(before, snap)
            if #d > 0 then
                log("  [" .. key .. "]")
                for _, x in ipairs(d) do
                    log("    " .. x)
                    table.insert(allDiffs, key .. ": " .. x)
                end
            else
                log("  [" .. key .. "] ไม่เปลี่ยนแปลง")
            end
        end
    end

    -- Save raw
    table.insert(Logger.RawData.tests, {
        name = name,
        before = before,
        snaps = snaps,
        diffs = allDiffs,
    })

    log("─── จบ " .. name .. " ───")
    task.wait(0.5)
end

local function runAllBlockTests()
    if State.Destroyed then return end

    section("เริ่ม Block Mechanism Tests")

    -- T1: Keyboard F hold
    runBlockTest("T1: Keyboard F hold 1s", function()
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
        task.wait(1.0)
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
    end, 1.5)

    if State.Destroyed then return end

    -- T2: Keyboard F tap
    runBlockTest("T2: Keyboard F tap 100ms", function()
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
        task.wait(0.1)
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
    end, 1.5)

    if State.Destroyed then return end

    -- T3: Remote bare
    runBlockTest("T3: Remote Activated bare", function()
        if BlockActivated then
            BlockActivated:FireServer()
        end
    end, 1.5)

    if State.Destroyed then return end

    -- T4: Remote true
    runBlockTest("T4: Remote Activated(true)", function()
        if BlockActivated then
            BlockActivated:FireServer(true)
        end
    end, 1.5)

    if State.Destroyed then return end

    -- T5: Remote spam 10x
    runBlockTest("T5: Remote spam 10x", function()
        if BlockActivated then
            for i = 1, 10 do
                BlockActivated:FireServer()
                task.wait(0.05)
            end
        end
    end, 2.0)

    if State.Destroyed then return end

    -- T6: Remote hold 1s
    runBlockTest("T6: Remote hold 1s", function()
        if not BlockActivated then return end
        local t0 = tick()
        while tick() - t0 < 1 do
            BlockActivated:FireServer()
            task.wait(0.05)
        end
        if BlockDeactivated then
            BlockDeactivated:FireServer()
        end
    end, 2.0)

    if State.Destroyed then return end

    -- T7: Keyboard + Remote combo
    runBlockTest("T7: Keyboard F + Remote", function()
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
        if BlockActivated then BlockActivated:FireServer() end
        task.wait(0.5)
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
        if BlockDeactivated then BlockDeactivated:FireServer() end
    end, 2.0)

    section("จบ Block Tests ทั้งหมด")
end

-- ═══════════════════════════════════════════
-- START / STOP / SAVE / KILL
-- ═══════════════════════════════════════════
local function saveAll()
    -- Text log
    local header = {
        "═══════════════════════════════════════════",
        "  Full Test Suite V4.0",
        "  Player: " .. LP.Name,
        "  PlaceId: " .. tostring(game.PlaceId),
        "  JobId: " .. tostring(game.JobId),
        "  Time: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "  Hits: " .. State.HitCount,
        "  Tests: " .. State.TestCount,
        "═══════════════════════════════════════════",
        "",
    }
    _write(Logger.FilePath,
        table.concat(header, "\n") .. "\n" .. table.concat(Logger.Lines, "\n"))

    -- Raw JSON
    Logger.RawData.meta = {
        player = LP.Name,
        placeId = game.PlaceId,
        jobId = game.JobId,
        time = os.date("%Y-%m-%d %H:%M:%S"),
        totalHits = State.HitCount,
        totalTests = State.TestCount,
    }
    local json = HttpService:JSONEncode(Logger.RawData)
    _write(Logger.RawPath, json)

    log("💾 Save 2 files:")
    log("   " .. Logger.FilePath)
    log("   " .. Logger.RawPath)
end

local function startCapture()
    if State.Destroyed then return end
    if State.Running then
        log("⚠️ กำลังรันอยู่")
        return
    end

    State.Running = true
    Logger.Enabled = true

    -- Header
    log("")
    log("═══════════════════════════════════════")
    log("🚀 เริ่มเก็บข้อมูล")
    log("  Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    log("  Hits: 0")
    log("═══════════════════════════════════════")

    -- Hook Hit Remote
    if HitRemote then
        State.HitConn = HitRemote.OnClientEvent:Connect(onHit)
        log("✅ Hook Hit Remote สำเร็จ")
    else
        log("❌ ไม่เจอ Hit Remote")
    end

    -- Run Block Tests
    State.TestThread = task.spawn(function()
        runAllBlockTests()

        if State.Destroyed then return end

        State.Running = false
        log("")
        log("═══════════════════════════════════════")
        log("✅ เสร็จ — Hits: " .. State.HitCount ..
            " | Tests: " .. State.TestCount)
        log("═══════════════════════════════════════")

        saveAll()
        updateGui()
    end)

    updateGui()
end

local function stopCapture()
    if not State.Running then return end

    State.Running = false
    Logger.Enabled = false

    if State.HitConn then
        State.HitConn:Disconnect()
        State.HitConn = nil
    end
    if State.TestThread then
        pcall(function() task.cancel(State.TestThread) end)
        State.TestThread = nil
    end

    log("⛔ หยุดเก็บข้อมูล")
    updateGui()
end

local function destroy()
    if State.Destroyed then return end

    log("💀 ปิดสคริปต์")

    State.Destroyed = true
    stopCapture()

    -- Save ก่อนปิด
    pcall(saveAll)

    -- ลบ GUI
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local g = pg:FindFirstChild("FullTest")
        if g then pcall(function() g:Destroy() end) end
    end

    _G.FullTest = nil

    print("[FT4.0] 💀 ปิดแล้ว")
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local gui, startBtn, stopBtn, saveBtn, killBtn, statusLbl, statsLbl, hitsLbl

function updateGui()
    if not startBtn then return end

    if State.Running then
        startBtn.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
        statusLbl.Text = "Status: 🟢 กำลังเก็บข้อมูล"
        statusLbl.TextColor3 = Color3.fromRGB(100, 255, 100)
    else
        startBtn.BackgroundColor3 = Color3.fromRGB(50, 130, 50)
        statusLbl.Text = "Status: ⚪ ว่าง"
        statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    end
end

local function buildGui()
    local pg = LP:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("FullTest")
    if old then old:Destroy() end

    gui = Instance.new("ScreenGui")
    gui.Name = "FullTest"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 400)
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
    title.Text = "🧪 Full Test V4.0"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.Parent = frame
    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 12)
    tc.Parent = title

    -- Layout
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = frame

    local padTop = Instance.new("Frame")
    padTop.Size = UDim2.new(1, 0, 0, 42)
    padTop.BackgroundTransparency = 1
    padTop.LayoutOrder = 0
    padTop.Parent = frame

    local function makeBtn(text, color, order, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -20, 0, 40)
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

    startBtn = makeBtn("▶  เริ่มเก็บข้อมูล", Color3.fromRGB(50, 130, 50), 1, startCapture)
    stopBtn  = makeBtn("⏸  หยุด", Color3.fromRGB(180, 130, 40), 2, stopCapture)
    saveBtn  = makeBtn("💾  บันทึกไฟล์", Color3.fromRGB(50, 100, 180), 3, saveAll)
    killBtn  = makeBtn("💀  ปิดสคริปต์", Color3.fromRGB(140, 30, 30), 4, destroy)

    -- Status
    statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -20, 0, 26)
    statusLbl.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLbl.Text = "Status: ⚪ ว่าง"
    statusLbl.Font = Enum.Font.Gotham
    statusLbl.TextSize = 12
    statusLbl.LayoutOrder = 10
    statusLbl.Parent = frame
    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0, 6)
    sc.Parent = statusLbl

    -- Stats
    statsLbl = Instance.new("TextLabel")
    statsLbl.Size = UDim2.new(1, -20, 0, 60)
    statsLbl.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    statsLbl.TextColor3 = Color3.fromRGB(150, 220, 150)
    statsLbl.Text = "Hits: 0 | Tests: 0"
    statsLbl.Font = Enum.Font.Code
    statsLbl.TextSize = 11
    statsLbl.TextWrapped = true
    statsLbl.TextXAlignment = Enum.TextXAlignment.Left
    statsLbl.TextYAlignment = Enum.TextYAlignment.Top
    statsLbl.LayoutOrder = 11
    statsLbl.Parent = frame
    local ssc = Instance.new("UICorner")
    ssc.CornerRadius = UDim.new(0, 6)
    ssc.Parent = statsLbl

    -- Recent Hits
    hitsLbl = Instance.new("TextLabel")
    hitsLbl.Size = UDim2.new(1, -20, 0, 130)
    hitsLbl.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    hitsLbl.TextColor3 = Color3.fromRGB(150, 200, 255)
    hitsLbl.Text = "📥 Recent Hits:\n(none)"
    hitsLbl.Font = Enum.Font.Code
    hitsLbl.TextSize = 10
    hitsLbl.TextWrapped = true
    hitsLbl.TextXAlignment = Enum.TextXAlignment.Left
    hitsLbl.TextYAlignment = Enum.TextYAlignment.Top
    hitsLbl.LayoutOrder = 12
    hitsLbl.Parent = frame
    local hc = Instance.new("UICorner")
    hc.CornerRadius = UDim.new(0, 6)
    hc.Parent = hitsLbl

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

    -- Update loop
    task.spawn(function()
        while gui and gui.Parent and not State.Destroyed do
            task.wait(0.3)

            if statsLbl then
                statsLbl.Text = string.format(
                    "Hits: %d | Tests: %d\nLast: %s",
                    State.HitCount,
                    State.TestCount,
                    State.LastTest or "-")
            end

            if hitsLbl then
                local lines = {}
                local start = math.max(1, #State.RecentHits - 5)
                for i = start, #State.RecentHits do
                    local h = State.RecentHits[i]
                    local argStr = ""
                    if h.args and h.args[1] then
                        local a = h.args[1]
                        if a.type == "Instance" then
                            argStr = a.name or a.class
                        else
                            argStr = a.type .. ":" .. tostring(a.value):sub(1, 15)
                        end
                    end
                    table.insert(lines, string.format("#%d %s → %s",
                        h.index, h.time, argStr))
                end
                hitsLbl.Text = "📥 Recent Hits:\n" ..
                    (#lines > 0 and table.concat(lines, "\n") or "(none)")
            end
        end
    end)

    updateGui()
end

buildGui()

-- ═══════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════
_G.FullTest = {
    start = startCapture,
    stop = stopCapture,
    save = saveAll,
    destroy = destroy,
    state = State,
}

print("═══════════════════════════════════════════")
print("✅ Full Test Suite V4.0 โหลดแล้ว")
print("📁 Log: " .. Logger.FilePath)
print("📁 Raw: " .. Logger.RawPath)
print("")
print("📋 ขั้นตอน:")
print("  1. กด ▶ เริ่มเก็บข้อมูล")
print("  2. ให้เพื่อนตีใส่ 5-10 ครั้ง (ระหว่าง test รัน)")
print("  3. รอ ~15 วิ (Block Tests อัตโนมัติ)")
print("  4. กด 💾 บันทึกไฟล์")
print("  5. ส่ง 2 ไฟล์")
print("═══════════════════════════════════════════")
