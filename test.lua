-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Auto Block Test Suite V5.0 | 6 Buttons + Deep Capture        ║
-- ║  - เก็บข้อมูลทุกปุ่มลงไฟล์อัตโนมัติ                            ║
-- ║  - Deep snapshot + args + timing                              ║
-- ║  - ปุ่มปิดสคริปต์                                             ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- LOGGER (save อัตโนมัติทุก log)
-- ═══════════════════════════════════════════
local Logger = {
    Lines = {},
    FilePath = "ABTestV5_" .. os.date("%Y%m%d_%H%M%S") .. ".txt",
    RawPath = "ABTestV5_raw_" .. os.date("%Y%m%d_%H%M%S") .. ".json",
    RawData = {},
    Enabled = true,
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
    print("[ABTestV5]", line)
    table.insert(Logger.Lines, line)
    if Logger.Enabled then
        _append(Logger.FilePath, line .. "\n")
    end
end

local function logSection(t)
    log("")
    log("════════ " .. t .. " ════════")
end

local function logSub(t)
    log("")
    log("─── " .. t .. " ───")
end

-- ═══════════════════════════════════════════
-- HEADER
-- ═══════════════════════════════════════════
local function writeHeader()
    local h = {
        "═══════════════════════════════════════════",
        "  AB Test Suite V5.0 Log",
        "  Started: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "  PlaceId: " .. tostring(game.PlaceId),
        "  JobId:   " .. tostring(game.JobId),
        "  Player:  " .. LP.Name,
        "═══════════════════════════════════════════",
        "",
    }
    _write(Logger.FilePath, table.concat(h, "\n") .. "\n")
    for _, l in ipairs(h) do
        table.insert(Logger.Lines, l)
    end
end
writeHeader()

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

local HitRemote        = findRemote("Knit.Knit.Services.HandicapService.RE.Hit")
local BlockActivated   = findRemote("Knit.Knit.Services.BlockService.RE.Activated")
local BlockDeactivated = findRemote("Knit.Knit.Services.BlockService.RE.Deactivated")

-- ═══════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════
local State = {
    Destroyed = false,
    faceEnabled = false,
    faceConn = nil,
    liveEnabled = false,
    liveConn = nil,
    abEnabled = false,
    abConn = nil,
    hitConn = nil,
    lastBlockTime = 0,
    abCount = 0,
    detected = {},
    hitLog = {},
}

-- ═══════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════
local function getMyChar()
    local c = LP.Character
    if not c then return nil, nil, nil end
    return c, c:FindFirstChild("HumanoidRootPart"),
        c:FindFirstChildOfClass("Humanoid")
end

local function findNearestEnemy(range)
    range = range or 30
    local _, myHRP = getMyChar()
    if not myHRP then return nil, math.huge end
    local nearest, minD = nil, range
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local h = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if h and hum and hum.Health > 0 then
                local d = (h.Position - myHRP.Position).Magnitude
                if d < minD then nearest = h; minD = d end
            end
        end
    end
    return nearest, minD
end

-- ═══════════════════════════════════════════
-- DEEP SNAPSHOT
-- ═══════════════════════════════════════════
local function snapshot()
    local snap = {
        time = tick(),
        timeStr = os.date("%H:%M:%S.%3f"),
    }
    local char, hrp, hum = getMyChar()
    if not char then return snap end

    if hum then
        snap.humanoid = {
            state = tostring(hum:GetState()),
            health = hum.Health,
            maxHealth = hum.MaxHealth,
            walkSpeed = hum.WalkSpeed,
            platformStand = hum.PlatformStand,
            sit = hum.Sit,
        }
    end

    snap.anims = {}
    if hum then
        local anim = hum:FindFirstChildOfClass("Animator")
        if anim then
            for _, t in ipairs(anim:GetPlayingAnimationTracks()) do
                table.insert(snap.anims, {
                    name = t.Animation.Name,
                    id = t.Animation.AnimationId,
                    weight = t.WeightCurrent,
                    speed = t.Speed,
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

    snap.attrs = {}
    local ok, list = pcall(function() return char:GetAttributes() end)
    if ok and list then
        for _, name in ipairs(list) do
            snap.attrs[name] = tostring(char:GetAttribute(name))
        end
    end

    if hrp then
        snap.pos = {
            x = math.floor(hrp.Position.X),
            y = math.floor(hrp.Position.Y),
            z = math.floor(hrp.Position.Z),
        }
    end

    return snap
end

local function diffSnap(a, b)
    local d = {}
    if a.humanoid and b.humanoid then
        for k, v in pairs(b.humanoid) do
            if a.humanoid[k] ~= v then
                table.insert(d, string.format("hum.%s: %s → %s",
                    k, tostring(a.humanoid[k]), tostring(v)))
            end
        end
    end
    local aa, ba = {}, {}
    for _, x in ipairs(a.anims or {}) do aa[x.name .. "|" .. x.id] = x end
    for _, x in ipairs(b.anims or {}) do ba[x.name .. "|" .. x.id] = x end
    for k, x in pairs(ba) do
        if not aa[k] then
            table.insert(d, string.format("anim+ %s (%s)", x.name, x.id))
        end
    end
    for k, x in pairs(aa) do
        if not ba[k] then
            table.insert(d, string.format("anim- %s", x.name))
        end
    end
    local as, bs = {}, {}
    for _, x in ipairs(a.sounds or {}) do as[x.name .. "|" .. x.soundId] = x end
    for _, x in ipairs(b.sounds or {}) do bs[x.name .. "|" .. x.soundId] = x end
    for k, x in pairs(bs) do
        if not as[k] then
            table.insert(d, string.format("sound+ %s", x.name))
        end
    end
    for k, v in pairs(b.attrs or {}) do
        if (a.attrs or {})[k] ~= v then
            table.insert(d, string.format("attr.%s: %s → %s",
                k, tostring((a.attrs or {})[k]), tostring(v)))
        end
    end
    return d
end

local function printSnap(label, s)
    log(string.format("  [%s] %s", label, s.timeStr))
    if s.humanoid then
        log(string.format("    state=%s hp=%.0f walkSpeed=%.0f",
            s.humanoid.state, s.humanoid.health, s.humanoid.walkSpeed))
    end
    if #(s.anims or {}) > 0 then
        local n = {}
        for _, a in ipairs(s.anims) do table.insert(n, a.name) end
        log("    anims: [" .. table.concat(n, ", ") .. "]")
    end
    if #(s.sounds or {}) > 0 then
        local n = {}
        for _, x in ipairs(s.sounds) do table.insert(n, x.name) end
        log("    sounds: [" .. table.concat(n, ", ") .. "]")
    end
    if s.pos then
        log(string.format("    pos: %d,%d,%d", s.pos.x, s.pos.y, s.pos.z))
    end
end

-- ═══════════════════════════════════════════
-- BUTTON 1: BLOCK PROBE
-- ═══════════════════════════════════════════
local function btnBlockProbe()
    logSection("BUTTON 1: BLOCK PROBE")

    local knit = ReplicatedStorage:FindFirstChild("Knit")
    local services = knit and knit:FindFirstChild("Knit")
        and knit.Knit:FindFirstChild("Services")

    if not services then
        log("❌ ไม่เจอ Knit.Services")
        return
    end

    -- BlockService
    logSub("BlockService")
    local bs = services:FindFirstChild("BlockService")
    if bs then
        for _, obj in ipairs(bs:GetDescendants()) do
            log(string.format("  %s | %s", obj.ClassName, obj:GetFullName()))
        end
    else
        log("  ❌ ไม่เจอ")
    end

    -- Services เกี่ยว block
    logSub("Services เกี่ยว Block")
    for _, svc in ipairs(services:GetChildren()) do
        local lower = string.lower(svc.Name)
        if lower:find("block") or lower:find("guard") or lower:find("defend") then
            log("★ " .. svc.Name)
            for _, obj in ipairs(svc:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
                   or obj.ClassName == "UnreliableRemoteEvent" then
                    log(string.format("   %s | %s",
                        obj.ClassName, obj:GetFullName()))
                end
            end
        end
    end

    -- HandicapService
    logSub("HandicapService")
    local hs = services:FindFirstChild("HandicapService")
    if hs then
        for _, obj in ipairs(hs:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj.ClassName == "UnreliableRemoteEvent" then
                log(string.format("  %s | %s",
                    obj.ClassName, obj:GetFullName()))
            end
        end
    else
        log("  ❌ ไม่เจอ")
    end

    logSection("จบ BLOCK PROBE")
end

-- ═══════════════════════════════════════════
-- BUTTON 2: FACE TEST
-- ═══════════════════════════════════════════
local function startFace()
    if State.faceEnabled then
        log("Face Test เปิดอยู่แล้ว")
        return
    end
    State.faceEnabled = true
    logSection("BUTTON 2: FACE TEST เปิด")
    log("เดินไปใกล้เพื่อน — ดูว่าหันตามไหม")

    State.faceConn = RunService.RenderStepped:Connect(function()
        if not State.faceEnabled then return end
        local _, hrp = getMyChar()
        if not hrp then return end
        local target = findNearestEnemy(30)
        if target then
            local dir = (target.Position - hrp.Position).Unit
            local newCF = CFrame.lookAt(hrp.Position, hrp.Position + dir)
            hrp.CFrame = hrp.CFrame:Lerp(newCF, 0.35)
        end
    end)
end

local function stopFace()
    State.faceEnabled = false
    if State.faceConn then
        State.faceConn:Disconnect()
        State.faceConn = nil
    end
    log("BUTTON 2: FACE TEST ปิด")
end

-- ═══════════════════════════════════════════
-- BUTTON 3: BLOCK REMOTE TEST
-- ═══════════════════════════════════════════
local function btnBlockRemote()
    logSection("BUTTON 3: BLOCK REMOTE TEST")

    -- Snapshot before
    local before = snapshot()
    logSub("BEFORE")
    printSnap("before", before)

    -- Test Activated bare
    logSub("Test: Activated:FireServer() เปล่า")
    if BlockActivated then
        local ok = pcall(function() BlockActivated:FireServer() end)
        log("  FireServer: " .. (ok and "OK" or "FAIL"))
    else
        log("  ❌ ไม่เจอ")
    end

    task.wait(0.1)
    printSnap("+100ms", snapshot())

    task.wait(0.3)
    printSnap("+400ms", snapshot())

    task.wait(0.6)
    local after = snapshot()
    printSnap("+1000ms", after)

    -- Diff
    logSub("DIFF")
    local d = diffSnap(before, after)
    if #d > 0 then
        for _, x in ipairs(d) do log("  " .. x) end
    else
        log("  ไม่เปลี่ยน")
    end

    -- Test Deactivated
    logSub("Test: Deactivated:FireServer()")
    if BlockDeactivated then
        local ok = pcall(function() BlockDeactivated:FireServer() end)
        log("  FireServer: " .. (ok and "OK" or "FAIL"))
    end

    logSection("จบ BLOCK REMOTE TEST")

    table.insert(Logger.RawData, {
        test = "blockRemote",
        before = before,
        after = after,
        diffs = d,
    })
end

-- ═══════════════════════════════════════════
-- BUTTON 4: BLOCK KEYBOARD TEST
-- ═══════════════════════════════════════════
local function btnBlockKeyboard()
    logSection("BUTTON 4: BLOCK KEYBOARD TEST (F)")

    local before = snapshot()
    logSub("BEFORE")
    printSnap("before", before)

    logSub("กด F (hold 500ms)")
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
    end)
    log("  SendKeyEvent(true): OK")

    task.wait(0.1)
    printSnap("+100ms", snapshot())

    task.wait(0.4)
    printSnap("+500ms", snapshot())

    logSub("ปล่อย F")
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
    end)

    task.wait(0.3)
    local after = snapshot()
    printSnap("+800ms", after)

    logSub("DIFF")
    local d = diffSnap(before, after)
    if #d > 0 then
        for _, x in ipairs(d) do log("  " .. x) end
    else
        log("  ไม่เปลี่ยน")
    end

    logSection("จบ BLOCK KEYBOARD TEST")

    table.insert(Logger.RawData, {
        test = "blockKeyboard",
        before = before,
        after = after,
        diffs = d,
    })
end

-- ═══════════════════════════════════════════
-- BUTTON 5: LIVE DETECTION (Hit Remote Probe)
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
        }
    elseif t == "Vector3" then
        return { type = "Vector3", x = math.floor(v.X), y = math.floor(v.Y), z = math.floor(v.Z) }
    else
        return { type = t, value = tostring(v):sub(1, 100) }
    end
end

local function startLive()
    if State.liveEnabled then
        log("Live เปิดอยู่แล้ว")
        return
    end
    State.liveEnabled = true
    logSection("BUTTON 5: LIVE DETECTION เปิด")
    log("ให้เพื่อนยิง/ตีใส่ — args จะถูก log")

    if not HitRemote then
        log("❌ ไม่เจอ HitRemote")
        return
    end

    State.hitConn = HitRemote.OnClientEvent:Connect(function(...)
        if not State.liveEnabled then return end
        local args = {...}

        log("")
        log(string.format("⚔️ HIT [%s] args=%d",
            os.date("%H:%M:%S.%3f"), #args))

        local _, myHRP = getMyChar()
        for i, v in ipairs(args) do
            local s = serializeArg(v)
            if s.type == "Instance" then
                log(string.format("  arg[%d] %s:%s", i, s.class, s.name))
                if myHRP and s.isModel then
                    local h = v:FindFirstChild("HumanoidRootPart")
                    if h then
                        local dd = (h.Position - myHRP.Position).Magnitude
                        log(string.format("       dist=%.1f studs", dd))
                    end
                end
            else
                log(string.format("  arg[%d] %s = %s", i, s.type, s.value))
            end
        end

        table.insert(State.hitLog, {
            time = os.date("%H:%M:%S.%3f"),
            tick = tick(),
            args = (function()
                local t = {}
                for i, v in ipairs(args) do
                    t[i] = serializeArg(v)
                end
                return t
            end)(),
        })
    end)
end

local function stopLive()
    State.liveEnabled = false
    if State.hitConn then
        State.hitConn:Disconnect()
        State.hitConn = nil
    end
    log("BUTTON 5: LIVE DETECTION ปิด — รวม " .. #State.hitLog .. " events")
end

-- ═══════════════════════════════════════════
-- BUTTON 6: AUTO BLOCK PROTOTYPE
-- ═══════════════════════════════════════════
local function startAutoBlock()
    if State.abEnabled then
        log("AB เปิดอยู่แล้ว")
        return
    end
    State.abEnabled = true
    logSection("BUTTON 6: AUTO BLOCK เปิด")
    log("Logic:")
    log("  - Hook HandicapService.Hit")
    log("  - หันหน้าไปหาผู้ตี")
    log("  - Fire Activated (hold 250ms)")

    if not HitRemote or not BlockActivated then
        log("❌ ไม่เจอ remote")
        return
    end

    State.abConn = HitRemote.OnClientEvent:Connect(function(...)
        if not State.abEnabled then return end
        local args = {...}

        -- หา Model
        local attacker = nil
        for _, v in ipairs(args) do
            if typeof(v) == "Instance" and v:IsA("Model")
               and v.Name ~= LP.Name then
                attacker = v
                break
            end
        end
        if not attacker then return end

        -- HRP
        local _, myHRP = getMyChar()
        local atkHRP = attacker:FindFirstChild("HumanoidRootPart")
        if not myHRP or not atkHRP then return end

        local dist = (atkHRP.Position - myHRP.Position).Magnitude
        if dist > 25 then return end

        -- หันหน้า
        local dir = (atkHRP.Position - myHRP.Position).Unit
        local look = Vector3.new(atkHRP.Position.X, myHRP.Position.Y, atkHRP.Position.Z)
        myHRP.CFrame = CFrame.lookAt(myHRP.Position, look)

        -- Fire block
        pcall(function() BlockActivated:FireServer() end)
        State.lastBlockTime = tick()
        State.abCount = State.abCount + 1

        log(string.format("🚨 BLOCK #%d ← %s (%.1f studs)",
            State.abCount, attacker.Name, dist))

        -- Release หลัง 250ms
        task.delay(0.25, function()
            if State.abEnabled then
                pcall(function()
                    if BlockDeactivated then
                        BlockDeactivated:FireServer()
                    end
                end)
            end
        end)

        -- Snapshot
        table.insert(Logger.RawData, {
            type = "autoBlock",
            attacker = attacker.Name,
            distance = dist,
            time = os.date("%H:%M:%S.%3f"),
            snapshot = snapshot(),
        })
    end)

    log("✅ Auto Block เริ่มทำงาน")
end

local function stopAutoBlock()
    State.abEnabled = false
    if State.abConn then
        State.abConn:Disconnect()
        State.abConn = nil
    end
    if BlockDeactivated then
        pcall(function() BlockDeactivated:FireServer() end)
    end
    log("BUTTON 6: AUTO BLOCK ปิด — รวม " .. State.abCount .. " blocks")
end

-- ═══════════════════════════════════════════
-- SAVE
-- ═══════════════════════════════════════════
local function saveAll()
    -- Save raw JSON
    Logger.RawData.meta = {
        player = LP.Name,
        placeId = game.PlaceId,
        jobId = game.JobId,
        time = os.date("%Y-%m-%d %H:%M:%S"),
        hits = #State.hitLog,
        blocks = State.abCount,
    }
    local json = HttpService:JSONEncode(Logger.RawData)
    _write(Logger.RawPath, json)

    log("💾 Save:")
    log("   " .. Logger.FilePath)
    log("   " .. Logger.RawPath)
end

-- ═══════════════════════════════════════════
-- KILL SWITCH
-- ═══════════════════════════════════════════
local function destroy()
    if State.Destroyed then return end
    log("💀 ปิดสคริปต์")

    State.Destroyed = true
    stopFace()
    stopLive()
    stopAutoBlock()

    -- Save
    pcall(saveAll)

    -- ลบ GUI
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local g = pg:FindFirstChild("ABTestV5")
        if g then pcall(function() g:Destroy() end) end
    end

    print("[ABTestV5] 💀 ปิดแล้ว")
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local function buildGui()
    local pg = LP:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("ABTestV5")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ABTestV5"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 460)
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
    title.Text = "🧪 AB Test V5.0"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
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

    -- 6 Buttons
    makeBtn("1️⃣ Block Probe", Color3.fromRGB(80, 80, 120), 1, btnBlockProbe)
    makeBtn("2️⃣ Face Test ON/OFF", Color3.fromRGB(60, 120, 80), 2, function()
        if State.faceEnabled then stopFace() else startFace() end
    end)
    makeBtn("3️⃣ Block Remote Test", Color3.fromRGB(120, 80, 60), 3, btnBlockRemote)
    makeBtn("4️⃣ Block Keyboard Test", Color3.fromRGB(120, 100, 60), 4, btnBlockKeyboard)
    makeBtn("5️⃣ Live Detection ON/OFF", Color3.fromRGB(80, 120, 120), 5, function()
        if State.liveEnabled then stopLive() else startLive() end
    end)
    makeBtn("6️⃣ AUTO BLOCK ON/OFF", Color3.fromRGB(150, 60, 60), 6, function()
        if State.abEnabled then stopAutoBlock() else startAutoBlock() end
    end)

    -- Utility buttons
    makeBtn("💾 Save", Color3.fromRGB(60, 90, 160), 7, saveAll)
    makeBtn("💀 ปิดสคริปต์", Color3.fromRGB(120, 20, 20), 8, destroy)

    -- Status
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, -20, 0, 50)
    statusLbl.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
    statusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLbl.Text = "Idle"
    statusLbl.Font = Enum.Font.Code
    statusLbl.TextSize = 10
    statusLbl.TextWrapped = true
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.TextYAlignment = Enum.TextYAlignment.Top
    statusLbl.LayoutOrder = 20
    statusLbl.Parent = frame
    local sc = Instance.new("UICorner")
    sc.CornerRadius = UDim.new(0, 6)
    sc.Parent = statusLbl

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

    -- Status loop
    task.spawn(function()
        while gui and gui.Parent and not State.Destroyed do
            task.wait(0.5)
            statusLbl.Text = string.format(
                "Face: %s | Live: %s | AB: %s\nHits: %d | Blocks: %d",
                State.faceEnabled and "🟢" or "⚪",
                State.liveEnabled and "🟢" or "⚪",
                State.abEnabled and "🟢" or "⚪",
                #State.hitLog, State.abCount)
        end
    end)
end

buildGui()

-- Export
_G.ABTestV5 = {
    destroy = destroy,
    save = saveAll,
    state = State,
}

print("═══════════════════════════════════════════")
print("✅ AB Test Suite V5.0 โหลดแล้ว")
print("📁 Log: " .. Logger.FilePath)
print("📁 Raw: " .. Logger.RawPath)
print("")
print("6 ปุ่ม:")
print("  1 = Block Probe")
print("  2 = Face Test")
print("  3 = Block Remote Test")
print("  4 = Block Keyboard Test")
print("  5 = Live Detection (Hit args)")
print("  6 = AUTO BLOCK")
print("  + Save / ปิดสคริปต์")
print("═══════════════════════════════════════════")
