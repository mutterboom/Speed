-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Auto Block Test Suite V2.2 | TXT + JSON                      ║
-- ║  - Save .txt (human readable)                                 ║
-- ║  - Save .json (machine readable)                              ║
-- ║  - Save ทั้งคู่เมื่อ kill                                      ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- LOGGER (TXT + JSON)
-- ═══════════════════════════════════════════
local Logger = {
    Lines = {},
    FilePath = "ABTest_" .. os.date("%Y%m%d_%H%M%S") .. ".txt",
    JsonPath = "ABTest_" .. os.date("%Y%m%d_%H%M%S") .. ".json",
    Enabled = true,

    -- JSON data (structured)
    Data = {
        meta = {
            version = "2.2",
            startedAt = os.date("%Y-%m-%d %H:%M:%S"),
            placeId = game.PlaceId,
            jobId = game.JobId,
            player = LP.Name,
        },
        blockProbe = {},
        faceTest = { enabled = false, events = {} },
        blockRemoteTests = {},
        blockKeyboardTests = {},
        liveDetections = [],
        autoBlocks = [],
    },
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

-- ทุก log → txt (real-time) + lines (สำหรับ save ทั้งไฟล์)
local function log(...)
    local parts = {}
    local args = {...}
    for i = 1, #args do
        parts[i] = tostring(args[i])
    end
    local line = table.concat(parts, " ")
    print("[TEST]", line)
    table.insert(Logger.Lines, line)
    if Logger.Enabled then
        _append(Logger.FilePath, line .. "\n")
    end
end

-- เขียน JSON ทั้งไฟล์ (เรียกตอน save)
local function flushJson()
    if not Logger.Enabled then return end
    local ok, json = pcall(function()
        return HttpService:JSONEncode(Logger.Data)
    end)
    if ok and json then
        _write(Logger.JsonPath, json)
    end
end

-- Header
_write(Logger.FilePath,
    "═══════════════════════════════════════════\n" ..
    "  Auto Block Test Suite V2.2\n" ..
    "  Started: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n" ..
    "  PlaceId: " .. tostring(game.PlaceId) .. "\n" ..
    "  JobId:   " .. tostring(game.JobId) .. "\n" ..
    "  Player:  " .. LP.Name .. "\n" ..
    "═══════════════════════════════════════════\n\n")

-- ═══════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════
local function section(t)
    log("")
    log("════════ " .. t .. " ════════")
end

local function subSection(t)
    log("─── " .. t .. " ───")
end

local function fmt(v)
    if typeof(v) == "Vector3" then
        return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
    end
    return tostring(v)
end

local function getMyChar()
    local char = LP.Character
    if not char then return nil, nil, nil end
    return char,
        char:FindFirstChild("HumanoidRootPart"),
        char:FindFirstChildOfClass("Humanoid")
end

local function getServices()
    local knit = ReplicatedStorage:FindFirstChild("Knit")
    if not knit then return nil end
    local kk = knit:FindFirstChild("Knit")
    if not kk then return nil end
    return kk:FindFirstChild("Services")
end

-- ═══════════════════════════════════════════
-- DEEP SNAPSHOT
-- ═══════════════════════════════════════════
local function takeSnapshot()
    local snap = {
        time = tick(),
        timeStr = os.date("%H:%M:%S") .. "." .. string.format("%03d",
            math.floor((tick() % 1) * 1000)),
    }
    local char = LP.Character
    if not char then return snap end

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

    snap.blockParts = {}
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            local lower = string.lower(obj.Name)
            if lower:find("block") or lower:find("guard") or lower:find("shield") then
                table.insert(snap.blockParts, {
                    name = obj.Name,
                    transparency = obj.Transparency,
                    visible = obj.Transparency < 1,
                })
            end
        end
    end

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

local function diffSnapshots(before, after)
    local diffs = {}
    if before.humanoid and after.humanoid then
        for k, v in pairs(after.humanoid) do
            if before.humanoid[k] ~= v then
                table.insert(diffs, string.format("hum.%s: %s → %s",
                    k, tostring(before.humanoid[k]), tostring(v)))
            end
        end
    end

    local aa, ba = {}, {}
    for _, x in ipairs(before.animations or {}) do aa[x.name .. "|" .. x.id] = x end
    for _, x in ipairs(after.animations or {}) do ba[x.name .. "|" .. x.id] = x end
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

    local as, bs = {}, {}
    for _, x in ipairs(before.sounds or {}) do as[x.name .. "|" .. x.soundId] = x end
    for _, x in ipairs(after.sounds or {}) do bs[x.name .. "|" .. x.soundId] = x end
    for k, x in pairs(bs) do
        if not as[k] then
            table.insert(diffs, string.format("sound+ %s (%s)", x.name, x.soundId))
        end
    end

    for k, v in pairs(after.attributes or {}) do
        if (before.attributes or {})[k] ~= v then
            table.insert(diffs, string.format("attr.%s: %s → %s",
                k, tostring((before.attributes or {})[k]), tostring(v)))
        end
    end

    return diffs
end

local function printSnapshot(label, s)
    log(string.format("  [%s] %s", label, s.timeStr))
    if s.humanoid then
        log(string.format("    state=%s hp=%.0f walkSpeed=%.0f",
            s.humanoid.state, s.humanoid.health, s.humanoid.walkSpeed))
    end
    if #(s.animations or {}) > 0 then
        local n = {}
        for _, a in ipairs(s.animations) do table.insert(n, a.name) end
        log("    anims: [" .. table.concat(n, ", ") .. "]")
    end
    if #(s.sounds or {}) > 0 then
        local n = {}
        for _, x in ipairs(s.sounds) do table.insert(n, x.name) end
        log("    sounds: [" .. table.concat(n, ", ") .. "]")
    end
    if s.position then
        log(string.format("    pos: %d,%d,%d",
            s.position.x, s.position.y, s.position.z))
    end
end

-- ═══════════════════════════════════════════
-- 1) BLOCK PROBE
-- ═══════════════════════════════════════════
local function blockProbe()
    section("BLOCK PROBE")
    local services = getServices()
    if not services then log("❌ ไม่เจอ Knit.Services") return end

    local result = { blockService = {}, otherServices = {}, handicap = {} }

    subSection("BlockService descendants")
    local bs = services:FindFirstChild("BlockService")
    if bs then
        for _, obj in ipairs(bs:GetDescendants()) do
            local info = { class = obj.ClassName, path = obj:GetFullName() }
            log(string.format("  %s | %s", info.class, info.path))
            table.insert(result.blockService, info)
        end
    end

    subSection("Services เกี่ยว Block")
    for _, svc in ipairs(services:GetChildren()) do
        local lower = string.lower(svc.Name)
        if lower:find("block") or lower:find("guard") or lower:find("defend") then
            log("  ★ " .. svc.Name)
            local svcEntry = { name = svc.Name, remotes = {} }
            for _, obj in ipairs(svc:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")
                   or obj.ClassName == "UnreliableRemoteEvent" then
                    local info = { class = obj.ClassName, path = obj:GetFullName() }
                    log("     " .. info.class .. " | " .. info.path)
                    table.insert(svcEntry.remotes, info)
                end
            end
            table.insert(result.otherServices, svcEntry)
        end
    end

    subSection("HandicapService")
    local hs = services:FindFirstChild("HandicapService")
    if hs then
        for _, obj in ipairs(hs:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj.ClassName == "UnreliableRemoteEvent" then
                local info = { class = obj.ClassName, path = obj:GetFullName() }
                log("  " .. info.class .. " | " .. info.path)
                table.insert(result.handicap, info)
            end
        end
    end

    Logger.Data.blockProbe = result
    flushJson()

    section("จบ BLOCK PROBE")
end

-- ═══════════════════════════════════════════
-- 2) FACE TEST
-- ═══════════════════════════════════════════
local faceEnabled = false
local faceConn

local function findNearestEnemy(range)
    range = range or 30
    local _, myHRP = getMyChar()
    if not myHRP then return nil, math.huge end
    local nearest, minD = nil, range
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local h = plr.Character:FindFirstChild("HumanoidRootPart")
            if h then
                local d = (h.Position - myHRP.Position).Magnitude
                if d < minD then nearest = h; minD = d end
            end
        end
    end
    return nearest, minD
end

local function startFaceTest()
    if faceEnabled then log("⚠️ Face Test เปิดอยู่แล้ว") return end
    faceEnabled = true
    Logger.Data.faceTest.enabled = true
    Logger.Data.faceTest.startedAt = os.date("%Y-%m-%d %H:%M:%S")
    section("FACE TEST เปิด")

    faceConn = RunService.RenderStepped:Connect(function()
        if not faceEnabled then return end
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

local function stopFaceTest()
    faceEnabled = false
    Logger.Data.faceTest.enabled = false
    Logger.Data.faceTest.stoppedAt = os.date("%Y-%m-%d %H:%M:%S")
    if faceConn then faceConn:Disconnect(); faceConn = nil end
    flushJson()
    section("FACE TEST ปิด")
end

-- ═══════════════════════════════════════════
-- 3) BLOCK REMOTE TEST
-- ═══════════════════════════════════════════
local function testBlockRemote()
    section("BLOCK REMOTE TEST")

    local before = takeSnapshot()
    subSection("BEFORE")
    printSnapshot("before", before)

    local services = getServices()
    local bs = services and services:FindFirstChild("BlockService")
    local activated = bs and bs.RE and bs.RE:FindFirstChild("Activated")
    local deactivated = bs and bs.RE and bs.RE:FindFirstChild("Deactivated")

    subSection("Test Activated")
    local fireOk, fireErr = false, nil
    if activated then
        fireOk, fireErr = pcall(function() activated:FireServer() end)
        log("  FireServer: " .. (fireOk and "OK" or ("FAIL: " .. tostring(fireErr))))
    else
        log("  ❌ ไม่เจอ Activated")
    end

    task.wait(0.1)
    printSnapshot("+100ms", takeSnapshot())

    task.wait(0.4)
    printSnapshot("+500ms", takeSnapshot())

    task.wait(0.5)
    local after = takeSnapshot()
    printSnapshot("+1000ms", after)

    subSection("DIFFS")
    local diffs = diffSnapshots(before, after)
    if #diffs > 0 then
        for _, d in ipairs(diffs) do log("  " .. d) end
    else
        log("  ไม่เปลี่ยนแปลง")
    end

    subSection("Test Deactivated")
    if deactivated then
        pcall(function() deactivated:FireServer() end)
        log("  FireServer Deactivated: OK")
    end

    table.insert(Logger.Data.blockRemoteTests, {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        before = before,
        after = after,
        diffs = diffs,
        fireOk = fireOk,
    })
    flushJson()

    section("จบ BLOCK REMOTE TEST")
end

-- ═══════════════════════════════════════════
-- 4) BLOCK KEYBOARD TEST
-- ═══════════════════════════════════════════
local function testBlockKeyboard()
    section("BLOCK KEYBOARD TEST (F)")

    local before = takeSnapshot()
    subSection("BEFORE")
    printSnapshot("before", before)

    subSection("กด F (hold 500ms)")
    pcall(function() VirtualInputManager:SendKeyEvent(true, "F", false, game) end)

    task.wait(0.1)
    printSnapshot("+100ms", takeSnapshot())

    task.wait(0.4)
    printSnapshot("+500ms", takeSnapshot())

    subSection("ปล่อย F")
    pcall(function() VirtualInputManager:SendKeyEvent(false, "F", false, game) end)

    task.wait(0.3)
    local after = takeSnapshot()
    printSnapshot("+800ms", after)

    subSection("DIFFS")
    local diffs = diffSnapshots(before, after)
    if #diffs > 0 then
        for _, d in ipairs(diffs) do log("  " .. d) end
    else
        log("  ไม่เปลี่ยนแปลง")
    end

    table.insert(Logger.Data.blockKeyboardTests, {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        before = before,
        after = after,
        diffs = diffs,
    })
    flushJson()

    section("จบ BLOCK KEYBOARD TEST")
end

-- ═══════════════════════════════════════════
-- 5) LIVE DETECTION
-- ═══════════════════════════════════════════
local liveEnabled = false
local liveConn
local detected = {}

local function isCloseHitbox(obj, maxDist)
    if not obj:IsA("BasePart") then return false, nil end
    local _, hrp = getMyChar()
    if not hrp then return false, nil end
    local d = (obj.Position - hrp.Position).Magnitude
    if d > maxDist then return false, nil end

    local lower = string.lower(obj.Name)
    local isHit = false
    if lower:find("hitbox") or lower:find("hitglow")
       or lower:find("slashhit") or lower:find("chasehit")
       or lower:find("hardhit") or lower:find("roughhit")
       or lower:find("grabcollision") then
        isHit = true
    end
    if not isHit then
        if obj.Transparency >= 0.7 and obj.CanCollide == false
           and obj.Massless == true then
            isHit = true
        end
    end
    if not isHit then return false, nil end

    local owner = nil
    local anc = obj.Parent
    for _ = 1, 6 do
        if not anc then break end
        if anc:IsA("Model") then
            local p = Players:GetPlayerFromCharacter(anc)
            if p then owner = p.Name break end
            if anc:FindFirstChildOfClass("Humanoid") then
                owner = anc.Name break
            end
        end
        anc = anc.Parent
    end

    return true, {
        name = obj.Name, class = obj.ClassName,
        distance = math.floor(d), position = fmt(obj.Position),
        owner = owner or "?", path = obj:GetFullName(),
    }
end

local function startLiveTest()
    if liveEnabled then log("⚠️ Live เปิดอยู่") return end
    liveEnabled = true
    detected = {}
    section("LIVE DETECTION เปิด")

    local tick0 = tick()
    local nextScan = tick0

    liveConn = RunService.Heartbeat:Connect(function()
        if not liveEnabled then return end
        if tick() < nextScan then return end
        nextScan = tick() + 0.05

        local _, hrp = getMyChar()
        if not hrp then return end

        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local isHit, info = isCloseHitbox(obj, 25)
                if isHit and info then
                    local key = info.path
                    if not detected[key] then
                        detected[key] = true
                        log(string.format("🎯 [%.1fs] %s (%s) owner=%s dist=%d pos=%s",
                            tick() - tick0, info.name, info.class,
                            info.owner, info.distance, info.position))

                        table.insert(Logger.Data.liveDetections, {
                            time = os.date("%H:%M:%S"),
                            elapsed = tick() - tick0,
                            name = info.name,
                            owner = info.owner,
                            distance = info.distance,
                            path = info.path,
                        })
                        flushJson()
                    end
                end
            end
        end
    end)
end

local function stopLiveTest()
    liveEnabled = false
    if liveConn then liveConn:Disconnect(); liveConn = nil end
    section("LIVE DETECTION ปิด")
    local count = 0
    for _ in pairs(detected) do count = count + 1 end
    log("รวมที่จับได้: " .. count)
    flushJson()
end

-- ═══════════════════════════════════════════
-- 6) AUTO BLOCK PROTOTYPE
-- ═══════════════════════════════════════════
local abEnabled = false
local abConn
local lastBlock = 0
local abCount = 0

local function tryBlock()
    local services = getServices()
    local bs = services and services:FindFirstChild("BlockService")
    local act = bs and bs.RE and bs.RE:FindFirstChild("Activated")
    if act then
        local ok = pcall(function() act:FireServer() end)
        if ok then return "remote" end
    end
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
    end)
    if ok then return "keyboard" end
    return nil
end

local function releaseBlock()
    local services = getServices()
    local bs = services and services:FindFirstChild("BlockService")
    local deact = bs and bs.RE and bs.RE:FindFirstChild("Deactivated")
    if deact then pcall(function() deact:FireServer() end) end
    pcall(function() VirtualInputManager:SendKeyEvent(false, "F", false, game) end)
end

local function startAutoBlock()
    if abEnabled then log("⚠️ AB เปิดแล้ว") return end
    abEnabled = true
    abCount = 0
    section("AUTO BLOCK PROTOTYPE เปิด")

    abConn = RunService.Heartbeat:Connect(function()
        if not abEnabled then return end
        if tick() - lastBlock < 0.3 then return end

        local _, hrp = getMyChar()
        if not hrp then return end

        local closest, minD, closestInfo = nil, 15, nil
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                local isHit, info = isCloseHitbox(obj, 15)
                if isHit and info then
                    if info.distance < minD then
                        closest = obj
                        closestInfo = info
                        minD = info.distance
                    end
                end
            end
        end

        if closest then
            local dir = (closest.Position - hrp.Position).Unit
            local newCF = CFrame.lookAt(hrp.Position, hrp.Position + dir)
            hrp.CFrame = hrp.CFrame:Lerp(newCF, 0.5)

            local method = tryBlock()
            lastBlock = tick()
            abCount = abCount + 1
            log(string.format("🚨 BLOCK #%d (%s) ← %s (%s) d=%d",
                abCount, method or "?",
                closestInfo.name, closestInfo.owner, closestInfo.distance))

            table.insert(Logger.Data.autoBlocks, {
                index = abCount,
                time = os.date("%H:%M:%S"),
                method = method,
                target = closestInfo.name,
                owner = closestInfo.owner,
                distance = closestInfo.distance,
            })
            flushJson()

            task.delay(0.25, function()
                if abEnabled then releaseBlock() end
            end)
        end
    end)
end

local function stopAutoBlock()
    abEnabled = false
    if abConn then abConn:Disconnect(); abConn = nil end
    releaseBlock()
    section("AUTO BLOCK ปิด")
    log("รวม block: " .. abCount)
    flushJson()
end

-- ═══════════════════════════════════════════
-- SAVE / KILL
-- ═══════════════════════════════════════════
local function saveAll()
    log("")
    log("═══════════════════════════════════════════")
    log("  SAVE")
    log("  Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    log("  Total Lines: " .. #Logger.Lines)
    log("  TXT:  " .. Logger.FilePath)
    log("  JSON: " .. Logger.JsonPath)
    log("═══════════════════════════════════════════")

    -- Save TXT (ทั้งไฟล์)
    _write(Logger.FilePath, table.concat(Logger.Lines, "\n"))

    -- Save JSON
    Logger.Data.meta.savedAt = os.date("%Y-%m-%d %H:%M:%S")
    Logger.Data.meta.totalLines = #Logger.Lines
    flushJson()

    print("[TEST] 💾 Save TXT: " .. Logger.FilePath)
    print("[TEST] 💾 Save JSON: " .. Logger.JsonPath)
end

local function destroy()
    log("💀 DESTROY — ปิดสคริปต์")

    if faceEnabled then stopFaceTest() end
    if liveEnabled then stopLiveTest() end
    if abEnabled then stopAutoBlock() end

    saveAll()

    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local g = pg:FindFirstChild("AB_TestSuite")
        if g then pcall(function() g:Destroy() end) end
    end

    _G.ABTestSuite = nil
    print("[TEST] ✅ ปิดเรียบร้อย")
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local function buildGui()
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then pg = LP:WaitForChild("PlayerGui") end

    local old = pg:FindFirstChild("AB_TestSuite")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AB_TestSuite"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 320, 0, 580)
    frame.Position = UDim2.new(0, 20, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    title.Text = "🧪 AB Test Suite V2.2"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.Parent = frame

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 12)
    tc.Parent = title

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.Parent = frame

    local padTop = Instance.new("Frame")
    padTop.Size = UDim2.new(1, 0, 0, 45)
    padTop.BackgroundTransparency = 1
    padTop.LayoutOrder = 0
    padTop.Parent = frame

    local function makeBtn(text, color, order, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -24, 0, 42)
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

    makeBtn("1️⃣ Block Probe", Color3.fromRGB(80, 80, 120), 1, blockProbe)
    makeBtn("2️⃣ Face Test ON/OFF", Color3.fromRGB(60, 120, 80), 2, function()
        if faceEnabled then stopFaceTest() else startFaceTest() end
    end)
    makeBtn("3️⃣ Block Remote Test", Color3.fromRGB(120, 80, 60), 3, testBlockRemote)
    makeBtn("4️⃣ Block Keyboard Test (F)", Color3.fromRGB(120, 100, 60), 4, testBlockKeyboard)
    makeBtn("5️⃣ Live Detection ON/OFF", Color3.fromRGB(80, 120, 120), 5, function()
        if liveEnabled then stopLiveTest() else startLiveTest() end
    end)
    makeBtn("6️⃣ AUTO BLOCK ON/OFF", Color3.fromRGB(150, 60, 60), 6, function()
        if abEnabled then stopAutoBlock() else startAutoBlock() end
    end)
    makeBtn("💾 Save (TXT+JSON)", Color3.fromRGB(50, 100, 180), 7, saveAll)
    makeBtn("💀 ปิดสคริปต์", Color3.fromRGB(140, 30, 30), 8, destroy)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -16, 0, 60)
    info.BackgroundTransparency = 1
    info.Text = "📁 TXT:  " .. Logger.FilePath .. "\n📁 JSON: " .. Logger.JsonPath
    info.TextColor3 = Color3.fromRGB(180, 180, 200)
    info.Font = Enum.Font.Gotham
    info.TextSize = 10
    info.TextWrapped = true
    info.LayoutOrder = 10
    info.Parent = frame

    local drag = false
    local dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            drag = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    title.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
           or input.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if drag and (input.UserInputType == Enum.UserInputType.MouseMovement
                     or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

buildGui()

_G.ABTestSuite = {
    save = saveAll,
    destroy = destroy,
    logger = Logger,
}

log("═══════════════════════════════════")
log("✅ AB Test Suite V2.2 โหลดแล้ว")
log("📁 TXT:  " .. Logger.FilePath)
log("📁 JSON: " .. Logger.JsonPath)
log("📋 ลำดับที่ควรกด:")
log("  1 → Block Probe")
log("  2 → Face Test")
log("  3 → Block Remote Test")
log("  4 → Block Keyboard Test")
log("  5 → Live Detection")
log("  6 → AUTO BLOCK")
log("  💾 → Save (TXT+JSON)")
log("  💀 → Kill")
log("═══════════════════════════════════")
