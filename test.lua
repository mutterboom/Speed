-- ╔══════════════════════════════════════╗
-- ║  AB Test Suite V2.3                  ║
-- ╚══════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer

local Logger = {
    Lines = {},
    FilePath = "ABTest_" .. os.date("%Y%m%d_%H%M%S") .. ".txt",
    JsonPath = "ABTest_" .. os.date("%Y%m%d_%H%M%S") .. ".json",
    Enabled = true,
    Data = {
        meta = {
            version = "2.3",
            startedAt = os.date("%Y-%m-%d %H:%M:%S"),
            placeId = game.PlaceId,
            jobId = game.JobId,
            player = LP.Name,
        },
        blockProbe = {},
        faceTest = {},
        blockRemoteTests = {},
        blockKeyboardTests = {},
        liveDetections = {},
        autoBlocks = {},
    },
}

local _writeFn = writefile or write_file
local _appendFn = appendfile or append_file

local function _write(path, data)
    if _writeFn then pcall(_writeFn, path, data) end
end

local function _append(path, data)
    if _appendFn then pcall(_appendFn, path, data) end
end

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

local function flushJson()
    local ok, json = pcall(HttpService.JSONEncode, HttpService, Logger.Data)
    if ok and json then
        _write(Logger.JsonPath, json)
    end
end

_write(Logger.FilePath, "AB Test Suite V2.3\nStarted: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")

local function section(t)
    log("")
    log("======== " .. t .. " ========")
end

local function getMyChar()
    local char = LP.Character
    if not char then return nil, nil, nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    return char, hrp, hum
end

local function getServices()
    local knit = ReplicatedStorage:FindFirstChild("Knit")
    if not knit then return nil end
    local kk = knit:FindFirstChild("Knit")
    if not kk then return nil end
    return kk:FindFirstChild("Services")
end

local function takeSnapshot()
    local snap = {
        timeStr = os.date("%H:%M:%S"),
    }
    local char, hrp, hum = getMyChar()
    if not char then return snap end

    if hum then
        snap.hp = hum.Health
        snap.state = tostring(hum:GetState())
        snap.walkspeed = hum.WalkSpeed
    end

    snap.anims = {}
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
                table.insert(snap.anims, t.Animation.Name)
            end
        end
    end

    snap.sounds = {}
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("Sound") and obj.Playing then
            table.insert(snap.sounds, obj.Name)
        end
    end

    if hrp then
        snap.pos = tostring(math.floor(hrp.Position.X)) .. "," ..
                   tostring(math.floor(hrp.Position.Y)) .. "," ..
                   tostring(math.floor(hrp.Position.Z))
    end

    return snap
end

local function diffSnapshots(a, b)
    local diffs = {}
    if a.hp ~= b.hp then
        table.insert(diffs, "hp: " .. tostring(a.hp) .. " -> " .. tostring(b.hp))
    end
    if a.state ~= b.state then
        table.insert(diffs, "state: " .. tostring(a.state) .. " -> " .. tostring(b.state))
    end
    if a.walkspeed ~= b.walkspeed then
        table.insert(diffs, "walkspeed: " .. tostring(a.walkspeed) .. " -> " .. tostring(b.walkspeed))
    end

    local aa = {}
    for _, x in ipairs(a.anims or {}) do aa[x] = true end
    for _, x in ipairs(b.anims or {}) do
        if not aa[x] then
            table.insert(diffs, "anim+ " .. x)
        end
    end

    local as = {}
    for _, x in ipairs(a.sounds or {}) do as[x] = true end
    for _, x in ipairs(b.sounds or {}) do
        if not as[x] then
            table.insert(diffs, "sound+ " .. x)
        end
    end

    return diffs
end

local function printSnapshot(label, s)
    log("  [" .. label .. "] " .. (s.timeStr or "?"))
    log("    hp=" .. tostring(s.hp) .. " state=" .. tostring(s.state))
    if #(s.anims or {}) > 0 then
        log("    anims: " .. table.concat(s.anims, ", "))
    end
    if #(s.sounds or {}) > 0 then
        log("    sounds: " .. table.concat(s.sounds, ", "))
    end
end

-- ═══════════════════════════════════════
-- 1. BLOCK PROBE
-- ═══════════════════════════════════════
local function blockProbe()
    section("BLOCK PROBE")
    local services = getServices()
    if not services then
        log("No Knit.Services")
        return
    end

    local result = {}
    local bs = services:FindFirstChild("BlockService")
    if bs then
        result.blockService = {}
        for _, obj in ipairs(bs:GetDescendants()) do
            log(obj.ClassName .. " | " .. obj:GetFullName())
            table.insert(result.blockService, {
                class = obj.ClassName,
                path = obj:GetFullName(),
            })
        end
    end

    local hs = services:FindFirstChild("HandicapService")
    if hs then
        result.handicap = {}
        for _, obj in ipairs(hs:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj.ClassName == "UnreliableRemoteEvent" then
                log(obj.ClassName .. " | " .. obj:GetFullName())
                table.insert(result.handicap, {
                    class = obj.ClassName,
                    path = obj:GetFullName(),
                })
            end
        end
    end

    Logger.Data.blockProbe = result
    flushJson()
    section("END BLOCK PROBE")
end

-- ═══════════════════════════════════════
-- 2. FACE TEST
-- ═══════════════════════════════════════
local faceEnabled = false
local faceConn = nil

local function findNearestEnemy(range)
    range = range or 30
    local _, myHRP = getMyChar()
    if not myHRP then return nil end
    local nearest = nil
    local minD = range
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local h = plr.Character:FindFirstChild("HumanoidRootPart")
            if h then
                local d = (h.Position - myHRP.Position).Magnitude
                if d < minD then
                    nearest = h
                    minD = d
                end
            end
        end
    end
    return nearest
end

local function startFaceTest()
    if faceEnabled then return end
    faceEnabled = true
    Logger.Data.faceTest.enabled = true
    section("FACE TEST ON")

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
    if faceConn then
        faceConn:Disconnect()
        faceConn = nil
    end
    flushJson()
    section("FACE TEST OFF")
end

-- ═══════════════════════════════════════
-- 3. BLOCK REMOTE TEST
-- ═══════════════════════════════════════
local function testBlockRemote()
    section("BLOCK REMOTE TEST")

    local before = takeSnapshot()
    log("BEFORE")
    printSnapshot("before", before)

    local services = getServices()
    local bs = services and services:FindFirstChild("BlockService")
    local activated = bs and bs.RE and bs.RE:FindFirstChild("Activated")
    local deactivated = bs and bs.RE and bs.RE:FindFirstChild("Deactivated")

    if activated then
        local ok = pcall(function() activated:FireServer() end)
        log("Activated FireServer: " .. tostring(ok))
    else
        log("No Activated remote")
    end

    task.wait(0.5)
    local after = takeSnapshot()
    printSnapshot("after", after)

    log("DIFFS")
    local diffs = diffSnapshots(before, after)
    for _, d in ipairs(diffs) do
        log("  " .. d)
    end

    if deactivated then
        pcall(function() deactivated:FireServer() end)
    end

    table.insert(Logger.Data.blockRemoteTests, {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        before = before,
        after = after,
        diffs = diffs,
    })
    flushJson()

    section("END BLOCK REMOTE TEST")
end

-- ═══════════════════════════════════════
-- 4. BLOCK KEYBOARD TEST
-- ═══════════════════════════════════════
local function testBlockKeyboard()
    section("BLOCK KEYBOARD TEST")

    local before = takeSnapshot()
    log("BEFORE")
    printSnapshot("before", before)

    pcall(function()
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
    end)

    task.wait(0.5)

    pcall(function()
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
    end)

    task.wait(0.3)
    local after = takeSnapshot()
    printSnapshot("after", after)

    log("DIFFS")
    local diffs = diffSnapshots(before, after)
    for _, d in ipairs(diffs) do
        log("  " .. d)
    end

    table.insert(Logger.Data.blockKeyboardTests, {
        time = os.date("%Y-%m-%d %H:%M:%S"),
        before = before,
        after = after,
        diffs = diffs,
    })
    flushJson()

    section("END BLOCK KEYBOARD TEST")
end

-- ═══════════════════════════════════════
-- 5. LIVE DETECTION
-- ═══════════════════════════════════════
local liveEnabled = false
local liveConn = nil
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
            if p then
                owner = p.Name
                break
            end
            if anc:FindFirstChildOfClass("Humanoid") then
                owner = anc.Name
                break
            end
        end
        anc = anc.Parent
    end

    return true, {
        name = obj.Name,
        class = obj.ClassName,
        distance = math.floor(d),
        position = tostring(math.floor(obj.Position.X)) .. "," ..
                   tostring(math.floor(obj.Position.Y)) .. "," ..
                   tostring(math.floor(obj.Position.Z)),
        owner = owner or "?",
        path = obj:GetFullName(),
    }
end

local function startLiveTest()
    if liveEnabled then return end
    liveEnabled = true
    detected = {}
    section("LIVE DETECTION ON")

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
                        log(string.format("%.1fs | %s | owner=%s | d=%d",
                            tick() - tick0, info.name, info.owner, info.distance))

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
    if liveConn then
        liveConn:Disconnect()
        liveConn = nil
    end
    local count = 0
    for _ in pairs(detected) do count = count + 1 end
    log("Live detected: " .. count)
    flushJson()
    section("LIVE DETECTION OFF")
end

-- ═══════════════════════════════════════
-- 6. AUTO BLOCK
-- ═══════════════════════════════════════
local abEnabled = false
local abConn = nil
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
    if deact then
        pcall(function() deact:FireServer() end)
    end
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
    end)
end

local function startAutoBlock()
    if abEnabled then return end
    abEnabled = true
    abCount = 0
    section("AUTO BLOCK ON")

    abConn = RunService.Heartbeat:Connect(function()
        if not abEnabled then return end
        if tick() - lastBlock < 0.3 then return end

        local _, hrp = getMyChar()
        if not hrp then return end

        local closest = nil
        local minD = 15
        local closestInfo = nil

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
            log("BLOCK #" .. abCount .. " (" .. tostring(method) ..
                ") <- " .. closestInfo.name .. " d=" .. closestInfo.distance)

            table.insert(Logger.Data.autoBlocks, {
                index = abCount,
                time = os.date("%H:%M:%S"),
                method = method,
                target = closestInfo.name,
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
    if abConn then
        abConn:Disconnect()
        abConn = nil
    end
    releaseBlock()
    log("Total blocks: " .. abCount)
    flushJson()
    section("AUTO BLOCK OFF")
end

-- ═══════════════════════════════════════
-- SAVE / KILL
-- ═══════════════════════════════════════
local function saveAll()
    log("")
    log("======== SAVE ========")
    log("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    log("Lines: " .. #Logger.Lines)

    _write(Logger.FilePath, table.concat(Logger.Lines, "\n"))

    Logger.Data.meta.savedAt = os.date("%Y-%m-%d %H:%M:%S")
    flushJson()

    print("[TEST] TXT:  " .. Logger.FilePath)
    print("[TEST] JSON: " .. Logger.JsonPath)
end

local function destroy()
    log("DESTROY")

    if faceEnabled then stopFaceTest() end
    if liveEnabled then stopLiveTest() end
    if abEnabled then stopAutoBlock() end

    saveAll()

    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local g = pg:FindFirstChild("AB_TestSuite")
        if g then
            pcall(function() g:Destroy() end)
        end
    end

    _G.ABTestSuite = nil
end

-- ═══════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════
local function buildGui()
    local pg = LP:WaitForChild("PlayerGui")

    local old = pg:FindFirstChild("AB_TestSuite")
    if old then
        pcall(function() old:Destroy() end)
    end

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
    title.Text = "AB Test Suite V2.3"
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
            b.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.3)
            task.delay(0.15, function()
                if b then
                    b.BackgroundColor3 = color
                end
            end)
            pcall(onClick)
        end)
        return b
    end

    makeBtn("1 Block Probe", Color3.fromRGB(80, 80, 120), 1, blockProbe)
    makeBtn("2 Face Test ON/OFF", Color3.fromRGB(60, 120, 80), 2, function()
        if faceEnabled then stopFaceTest() else startFaceTest() end
    end)
    makeBtn("3 Block Remote Test", Color3.fromRGB(120, 80, 60), 3, testBlockRemote)
    makeBtn("4 Block Keyboard Test", Color3.fromRGB(120, 100, 60), 4, testBlockKeyboard)
    makeBtn("5 Live Detection ON/OFF", Color3.fromRGB(80, 120, 120), 5, function()
        if liveEnabled then stopLiveTest() else startLiveTest() end
    end)
    makeBtn("6 AUTO BLOCK ON/OFF", Color3.fromRGB(150, 60, 60), 6, function()
        if abEnabled then stopAutoBlock() else startAutoBlock() end
    end)
    makeBtn("Save (TXT+JSON)", Color3.fromRGB(50, 100, 180), 7, saveAll)
    makeBtn("Kill Script", Color3.fromRGB(140, 30, 30), 8, destroy)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -16, 0, 60)
    info.BackgroundTransparency = 1
    info.Text = "TXT:  " .. Logger.FilePath .. "\nJSON: " .. Logger.JsonPath
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

log("===============================")
log("AB Test Suite V2.3 Loaded")
log("TXT:  " .. Logger.FilePath)
log("JSON: " .. Logger.JsonPath)
log("===============================")
