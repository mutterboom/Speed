-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Auto Block Test Suite V2.0                                   ║
-- ║  Deep Probe Edition                                           ║
-- ║  - Character Snapshot (attributes, parts, sounds, anims)      ║
-- ║  - Block VFX Detection                                        ║
-- ║  - Deep State Diff                                            ║
-- ║  - File Logger + Raw Dumps                                    ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- FILE LOGGER
-- ═══════════════════════════════════════════
local Logger = {
    Lines = {},
    Enabled = true,
    FilePath = "ABTestV2_" .. os.date("%Y%m%d_%H%M%S") .. ".txt",
    RawDumpPath = "ABTestV2_raw_" .. os.date("%Y%m%d_%H%M%S") .. ".json",
    RawDumps = {},
}

local _writeFn = writefile or write_file
local _appendFn = appendfile or append_file

local function _write(path, data)
    if _writeFn then return pcall(_writeFn, path, data) end
    return false
end

local function _append(path, data)
    if _appendFn then return pcall(_appendFn, path, data) end
    if _writeFn and readfile then
        local ok, old = pcall(readfile, path)
        return pcall(_writeFn, path, (ok and old or "") .. data)
    end
    return false
end

local _origPrint = print
local function log(...)
    local args = {...}
    local parts = {}
    for i, v in ipairs(args) do
        parts[i] = tostring(v)
    end
    local line = table.concat(parts, " ")

    _origPrint(line)
    table.insert(Logger.Lines, line)

    if Logger.Enabled then
        _append(Logger.FilePath, line .. "\n")
    end
end

local function writeHeader()
    local h = {
        "═══════════════════════════════════════════",
        "  AB Test Log V2.0 — Deep Probe",
        "  Started: " .. os.date("%Y-%m-%d %H:%M:%S"),
        "  PlaceId: " .. tostring(game.PlaceId),
        "  JobId:   " .. tostring(game.JobId),
        "  Player:  " .. LP.Name,
        "═══════════════════════════════════════════",
        "",
    }
    for _, l in ipairs(h) do
        table.insert(Logger.Lines, l)
    end
    _write(Logger.FilePath, table.concat(h, "\n") .. "\n")
end

writeHeader()

-- ═══════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════
local function section(title)
    log("")
    log("════════ " .. title .. " ════════")
end

local function subSection(title)
    log("─── " .. title .. " ───")
end

local function getMyChar()
    local char = LP.Character
    if not char then return nil end
    return char
end

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
-- ★★★ DEEP SNAPSHOT ★★★
-- ═══════════════════════════════════════════
local function takeSnapshot()
    local snap = {
        time = tick(),
        timeStr = os.date("%H:%M:%S"),
    }

    local char = getMyChar()
    if not char then
        snap.char = nil
        return snap
    end

    -- 1. Attributes ทั้งหมด
    snap.attributes = {}
    local ok, attrs = pcall(function() return char:GetAttributes() end)
    if ok and attrs then
        for _, name in ipairs(attrs) do
            local v = char:GetAttribute(name)
            snap.attributes[name] = tostring(v)
        end
    end

    -- 2. Humanoid state + properties
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

    -- 3. Playing Animations (ละเอียด)
    snap.animations = {}
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                table.insert(snap.animations, {
                    name = t.Animation.Name,
                    id = t.Animation.AnimationId,
                    speed = t.Speed,
                    weight = t.WeightCurrent,
                    priority = tostring(t.Priority),
                })
            end
        end
    end

    -- 4. Parts ที่มีคำว่า "block" / "guard" / "shield"
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
                    size = tostring(obj.Size),
                    path = obj:GetFullName(),
                })
            end
        end
    end

    -- 5. Sounds ที่กำลังเล่น
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

    -- 6. จำนวน parts (เพื่อ detect spawn/despawn)
    snap.partCount = 0
    snap.visibleParts = 0
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            snap.partCount = snap.partCount + 1
            if obj.Transparency < 1 then
                snap.visibleParts = snap.visibleParts + 1
            end
        end
    end

    return snap
end

-- ═══════════════════════════════════════════
-- SNAPSHOT DIFF
-- ═══════════════════════════════════════════
local function diffSnapshots(before, after)
    local diffs = {}

    -- Humanoid diff
    if before.humanoid and after.humanoid then
        for k, v in pairs(after.humanoid) do
            if before.humanoid[k] ~= v then
                table.insert(diffs, string.format("hum.%s: %s → %s",
                    k, tostring(before.humanoid[k]), tostring(v)))
            end
        end
    elseif after.humanoid and not before.humanoid then
        table.insert(diffs, "humanoid: nil → present")
    end

    -- Attributes diff
    local beforeAttrs = before.attributes or {}
    local afterAttrs = after.attributes or {}
    for k, v in pairs(afterAttrs) do
        if beforeAttrs[k] ~= v then
            table.insert(diffs, string.format("attr.%s: %s → %s",
                k, tostring(beforeAttrs[k]), tostring(v)))
        end
    end
    for k in pairs(beforeAttrs) do
        if afterAttrs[k] == nil then
            table.insert(diffs, string.format("attr.%s: %s → nil",
                k, tostring(beforeAttrs[k])))
        end
    end

    -- Animations diff
    local beforeAnims = {}
    for _, a in ipairs(before.animations or {}) do
        beforeAnims[a.name] = a
    end
    local afterAnims = {}
    for _, a in ipairs(after.animations or {}) do
        afterAnims[a.name] = a
    end
    for name, a in pairs(afterAnims) do
        if not beforeAnims[name] then
            table.insert(diffs, string.format("anim+ %s (%s)",
                name, a.id))
        end
    end
    for name in pairs(beforeAnims) do
        if not afterAnims[name] then
            table.insert(diffs, string.format("anim- %s", name))
        end
    end

    -- Part count diff
    if before.partCount ~= after.partCount then
        table.insert(diffs, string.format("partCount: %d → %d",
            before.partCount or 0, after.partCount or 0))
    end
    if before.visibleParts ~= after.visibleParts then
        table.insert(diffs, string.format("visibleParts: %d → %d",
            before.visibleParts or 0, after.visibleParts or 0))
    end

    -- Block parts diff (สำคัญมาก!)
    local beforeBlocks = {}
    for _, p in ipairs(before.blockParts or {}) do
        beforeBlocks[p.path] = p
    end
    for _, p in ipairs(after.blockParts or {}) do
        local old = beforeBlocks[p.path]
        if not old then
            table.insert(diffs, string.format("blockPart+ %s (vis=%s, trans=%.2f)",
                p.name, tostring(p.visible), p.transparency))
        elseif old.visible ~= p.visible or old.transparency ~= p.transparency then
            table.insert(diffs, string.format("blockPart~ %s (vis %s→%s, trans %.2f→%.2f)",
                p.name, tostring(old.visible), tostring(p.visible),
                old.transparency, p.transparency))
        end
    end

    -- Sounds diff
    local beforeSounds = {}
    for _, s in ipairs(before.sounds or {}) do
        beforeSounds[s.name] = s
    end
    for _, s in ipairs(after.sounds or {}) do
        if not beforeSounds[s.name] then
            table.insert(diffs, string.format("sound+ %s (%s)",
                s.name, s.soundId))
        end
    end

    return diffs
end

local function printSnapshot(label, snap)
    log(string.format("  [%s] time=%s", label, snap.timeStr or "?"))

    if snap.humanoid then
        log(string.format("    hum.state=%s | hum.platformStand=%s | hum.sit=%s",
            snap.humanoid.state,
            tostring(snap.humanoid.platformStand),
            tostring(snap.humanoid.sit)))
        log(string.format("    hum.hp=%d/%d | walkSpeed=%d",
            math.floor(snap.humanoid.health),
            math.floor(snap.humanoid.maxHealth),
            math.floor(snap.humanoid.walkSpeed)))
    end

    -- Attributes
    local attrList = {}
    for k, v in pairs(snap.attributes or {}) do
        table.insert(attrList, k .. "=" .. v)
    end
    if #attrList > 0 then
        log("    attrs: " .. table.concat(attrList, ", "))
    else
        log("    attrs: (none)")
    end

    -- Animations
    if #(snap.animations or {}) > 0 then
        local names = {}
        for _, a in ipairs(snap.animations) do
            table.insert(names, a.name)
        end
        log("    anims: [" .. table.concat(names, ", ") .. "]")
    else
        log("    anims: []")
    end

    -- Block parts
    if #(snap.blockParts or {}) > 0 then
        for _, p in ipairs(snap.blockParts) do
            log(string.format("    blockPart: %s vis=%s trans=%.2f",
                p.name, tostring(p.visible), p.transparency))
        end
    end

    -- Counts
    log(string.format("    parts=%d visible=%d",
        snap.partCount or 0, snap.visibleParts or 0))
end

-- ═══════════════════════════════════════════
-- TEST RUNNER — Snapshot + Action + Snapshot
-- ═══════════════════════════════════════════
local function runTest(testName, actionFn, postWaitTime)
    postWaitTime = postWaitTime or 1.0

    section(testName)

    -- BEFORE
    local before = takeSnapshot()
    subSection("BEFORE")
    printSnapshot("before", before)

    -- ACTION
    subSection("ACTION")
    local actionOk, actionErr = pcall(actionFn)
    log("  action: " .. (actionOk and "OK" or ("FAIL: " .. tostring(actionErr))))

    -- ตรวจทันที
    task.wait(0.1)
    local snap100 = takeSnapshot()
    subSection("AFTER 100ms")
    printSnapshot("+100ms", snap100)

    -- ตรวจต่อ
    task.wait(0.4)
    local snap500 = takeSnapshot()
    subSection("AFTER 500ms")
    printSnapshot("+500ms", snap500)

    -- ตรวจสุดท้าย
    task.wait(postWaitTime - 0.5)
    local snapEnd = takeSnapshot()
    subSection("AFTER " .. math.floor(postWaitTime * 1000) .. "ms")
    printSnapshot("end", snapEnd)

    -- DIFFS
    subSection("DIFFS")
    local diffs1 = diffSnapshots(before, snap100)
    local diffs2 = diffSnapshots(before, snap500)
    local diffs3 = diffSnapshots(before, snapEnd)

    if #diffs1 > 0 then
        log("  [+100ms vs before]")
        for _, d in ipairs(diffs1) do log("    " .. d) end
    else
        log("  [+100ms] ไม่มีการเปลี่ยนแปลง")
    end

    if #diffs2 > 0 then
        log("  [+500ms vs before]")
        for _, d in ipairs(diffs2) do log("    " .. d) end
    else
        log("  [+500ms] ไม่มีการเปลี่ยนแปลง")
    end

    if #diffs3 > 0 then
        log("  [end vs before]")
        for _, d in ipairs(diffs3) do log("    " .. d) end
    else
        log("  [end] ไม่มีการเปลี่ยนแปลง")
    end

    -- Save raw snapshot
    table.insert(Logger.RawDumps, {
        test = testName,
        before = before,
        after100 = snap100,
        after500 = snap500,
        afterEnd = snapEnd,
        diffs100 = diffs1,
        diffs500 = diffs2,
        diffsEnd = diffs3,
    })

    section("จบ " .. testName)
    task.wait(0.5)
end

-- ═══════════════════════════════════════════
-- TESTS
-- ═══════════════════════════════════════════
local tests = {
    {
        name = "T1: Keyboard F (hold 1s)",
        action = function()
            VirtualInputManager:SendKeyEvent(true, "F", false, game)
            task.wait(1.0)
            VirtualInputManager:SendKeyEvent(false, "F", false, game)
        end,
    },
    {
        name = "T2: Keyboard F (tap 100ms)",
        action = function()
            VirtualInputManager:SendKeyEvent(true, "F", false, game)
            task.wait(0.1)
            VirtualInputManager:SendKeyEvent(false, "F", false, game)
        end,
    },
    {
        name = "T3: Remote Activated (bare)",
        action = function()
            if BlockRemote then
                BlockRemote:FireServer()
            end
        end,
    },
    {
        name = "T4: Remote Activated(true)",
        action = function()
            if BlockRemote then
                BlockRemote:FireServer(true)
            end
        end,
    },
    {
        name = "T5: Remote Activated spam (10x)",
        action = function()
            if BlockRemote then
                for i = 1, 10 do
                    BlockRemote:FireServer()
                    task.wait(0.05)
                end
            end
        end,
    },
    {
        name = "T6: Remote Activated hold (1s)",
        action = function()
            if BlockRemote then
                local t0 = tick()
                while tick() - t0 < 1 do
                    BlockRemote:FireServer()
                    task.wait(0.05)
                end
                if BlockDeact then
                    BlockDeact:FireServer()
                end
            end
        end,
    },
    {
        name = "T7: Keyboard F + Remote Activated",
        action = function()
            VirtualInputManager:SendKeyEvent(true, "F", false, game)
            if BlockRemote then
                BlockRemote:FireServer()
            end
            task.wait(0.5)
            VirtualInputManager:SendKeyEvent(false, "F", false, game)
            if BlockDeact then
                BlockDeact:FireServer()
            end
        end,
    },
}

-- ═══════════════════════════════════════════
-- LISTEN HitRemote (จับ args จริง)
-- ═══════════════════════════════════════════
local hitLog = {}

if HitRemote then
    task.spawn(function()
        local ok = pcall(function()
            HitRemote.OnClientEvent:Connect(function(...)
                local args = {...}
                local info = {}
                for i, v in ipairs(args) do
                    if typeof(v) == "Instance" then
                        info[i] = {
                            type = "Instance",
                            class = v.ClassName,
                            name = v.Name,
                            path = v:GetFullName(),
                        }
                    else
                        info[i] = { type = typeof(v), value = tostring(v) }
                    end
                end
                table.insert(hitLog, {
                    time = os.date("%H:%M:%S.%3f"),
                    tick = tick(),
                    args = info,
                })
            end)
        end)
    end)
end

-- ═══════════════════════════════════════════
-- MAIN
-- ═══════════════════════════════════════════
task.spawn(function()
    log("")
    log("═══════════════════════════════════════")
    log("✅ AB Test Suite V2.0 — Deep Probe")
    log("📁 Log: " .. Logger.FilePath)
    log("📁 Raw: " .. Logger.RawDumpPath)
    log("📋 Tests: " .. #tests)
    log("⏱️  รวมเวลา: ~" .. (#tests * 3) .. " วินาที")
    log("═══════════════════════════════════════")

    task.wait(2)

    -- Block remote status
    section("REMOTE STATUS")
    log("BlockRemote: " .. (BlockRemote and BlockRemote:GetFullName() or "❌ ไม่เจอ"))
    log("BlockDeact: " .. (BlockDeact and BlockDeact:GetFullName() or "❌ ไม่เจอ"))
    log("HitRemote: " .. (HitRemote and HitRemote:GetFullName() or "❌ ไม่เจอ"))

    -- Initial baseline
    section("BASELINE — ก่อนเริ่ม")
    printSnapshot("baseline", takeSnapshot())

    task.wait(1)

    -- Run all tests
    for i, test in ipairs(tests) do
        runTest(test.name, test.action)
    end

    -- Final
    section("HIT REMOTE LOG")
    log("รวม " .. #hitLog .. " events")
    if #hitLog > 0 then
        for i = 1, math.min(5, #hitLog) do
            local e = hitLog[i]
            log(string.format("  [%d] %s", i, e.time))
            for j, arg in ipairs(e.args) do
                log(string.format("      arg[%d] %s", j,
                    arg.path or arg.value or "?"))
            end
        end
    end

    -- Save raw dumps
    local rawJson = HttpService:JSONEncode({
        tests = Logger.RawDumps,
        hitLog = hitLog,
        meta = {
            version = "2.0",
            placeId = game.PlaceId,
            jobId = game.JobId,
            player = LP.Name,
            time = os.date("%Y-%m-%d %H:%M:%S"),
        },
    })
    _write(Logger.RawDumpPath, rawJson)

    log("")
    log("═══════════════════════════════════════")
    log("  TEST COMPLETE")
    log("  Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    log("  Log file:  " .. Logger.FilePath)
    log("  Raw file:  " .. Logger.RawDumpPath)
    log("  Total lines: " .. #Logger.Lines)
    log("═══════════════════════════════════════")

    _origPrint("[ABTest] ✅ เสร็จ!")
    _origPrint("[ABTest] 📁 " .. Logger.FilePath)
    _origPrint("[ABTest] 📁 " .. Logger.RawDumpPath)
end)
