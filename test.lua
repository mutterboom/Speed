-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Auto Block Test Suite V1.1                                   ║
-- ║  + File Logger | + Clipboard | + Clear                        ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- FILE LOGGER
-- ═══════════════════════════════════════════
local Logger = {
    Lines = {},
    Enabled = true,
    FilePath = nil,
    StartTime = tick(),
    SessionId = os.date("%Y%m%d_%H%M%S"),
}

-- หา writefile
local _writeFn = writefile or write_file
local _appendFn = appendfile or append_file

if _writeFn then
    Logger.FilePath = "ABTest_" .. Logger.SessionId .. ".txt"
end

local function _write(path, data)
    if _writeFn then
        local ok = pcall(_writeFn, path, data)
        return ok
    end
    return false
end

local function _append(path, data)
    if _appendFn then
        return pcall(_appendFn, path, data)
    end
    -- fallback: อ่านเก่า + เขียนใหม่
    if _writeFn and readfile then
        local ok, old = pcall(readfile, path)
        local content = (ok and old or "") .. data
        return pcall(_writeFn, path, content)
    end
    return false
end

local function log(...)
    local args = {...}
    local parts = {}
    for i, v in ipairs(args) do
        parts[i] = tostring(v)
    end
    local line = "[TEST] " .. table.concat(parts, " ")

    -- print
    print(line)

    -- save memory
    table.insert(Logger.Lines, line)

    -- save file
    if Logger.Enabled and Logger.FilePath then
        _append(Logger.FilePath, line .. "\n")
    end
end

local function logRaw(line)
    print(line)
    table.insert(Logger.Lines, line)
    if Logger.Enabled and Logger.FilePath then
        _append(Logger.FilePath, line .. "\n")
    end
end

-- Header
local function writeHeader()
    if not Logger.FilePath then return end
    local header = {}
    table.insert(header, "═══════════════════════════════════════════")
    table.insert(header, "  AB Test Log")
    table.insert(header, "  Session: " .. Logger.SessionId)
    table.insert(header, "  Started: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(header, "  PlaceId: " .. tostring(game.PlaceId))
    table.insert(header, "  JobId:   " .. tostring(game.JobId))
    table.insert(header, "  Player:  " .. LP.Name)
    table.insert(header, "═══════════════════════════════════════════")
    table.insert(header, "")
    _write(Logger.FilePath, table.concat(header, "\n") .. "\n")
end

writeHeader()

-- ═══════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════
local function fmt(v)
    if typeof(v) == "Vector3" then
        return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
    end
    return tostring(v)
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

local function section(title)
    log("")
    log("════════ " .. title .. " ════════")
end

-- ═══════════════════════════════════════════
-- 1) BLOCK PROBE
-- ═══════════════════════════════════════════
local function blockProbe()
    section("BLOCK PROBE")
    local services = getServices()
    if not services then
        log("❌ ไม่เจอ Knit.Services")
        return
    end

    log("─── BlockService descendants ───")
    local bs = services:FindFirstChild("BlockService")
    if bs then
        for _, obj in ipairs(bs:GetDescendants()) do
            log("  " .. obj.ClassName .. " | " .. obj:GetFullName())
        end
    else
        log("  ❌ ไม่เจอ BlockService")
    end

    log("─── Services เกี่ยว Block/Guard/Defend/Parry ───")
    for _, svc in ipairs(services:GetChildren()) do
        local lower = string.lower(svc.Name)
        if lower:find("block") or lower:find("guard")
           or lower:find("defend") or lower:find("parry") then
            log("★ " .. svc.Name)
            for _, obj in ipairs(svc:GetDescendants()) do
                if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                    log("   " .. obj.ClassName .. " | " .. obj:GetFullName())
                end
            end
        end
    end

    log("─── ItemService.Remotes ───")
    local is = services:FindFirstChild("ItemService")
    if is then
        for _, obj in ipairs(is:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                log("  " .. obj.Name .. " | " .. obj:GetFullName())
            end
        end
    end

    log("─── Remotes ชื่อ Activated/Deactivated ใน RS ───")
    local count = 0
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
           and (obj.Name == "Activated" or obj.Name == "Deactivated") then
            log("  " .. obj.Name .. " | " .. obj:GetFullName())
            count = count + 1
        end
    end
    log("  รวม: " .. count)

    log("════════ จบ BLOCK PROBE ════════")
    log("")
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
    section("FACE TEST เปิด")
    log("เดินไปใกล้เพื่อน → ตัวละครต้องหันตาม")
    log("")
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
    if faceConn then faceConn:Disconnect(); faceConn = nil end
    section("FACE TEST ปิด")
end

-- ═══════════════════════════════════════════
-- 3) BLOCK REMOTE TEST
-- ═══════════════════════════════════════════
local function testBlockRemote()
    section("BLOCK REMOTE TEST")
    local services = getServices()
    if not services then log("❌ ไม่เจอ Services") return end

    local bs = services:FindFirstChild("BlockService")
    if not bs then log("❌ ไม่เจอ BlockService") return end

    local activated = bs.RE and bs.RE:FindFirstChild("Activated")
    local deactivated = bs.RE and bs.RE:FindFirstChild("Deactivated")

    if activated then
        log("★ ยิง Activated:FireServer()")
        local ok, err = pcall(function() activated:FireServer() end)
        log("  → " .. (ok and "✅ สำเร็จ" or ("❌ " .. tostring(err))))
    else
        log("⚠️ ไม่เจอ Activated")
    end

    task.wait(1)

    if deactivated then
        log("★ ยิง Deactivated:FireServer()")
        local ok, err = pcall(function() deactivated:FireServer() end)
        log("  → " .. (ok and "✅ สำเร็จ" or ("❌ " .. tostring(err))))
    else
        log("⚠️ ไม่เจอ Deactivated")
    end

    section("จบ BLOCK REMOTE TEST")
end

-- ═══════════════════════════════════════════
-- 4) BLOCK KEYBOARD TEST
-- ═══════════════════════════════════════════
local function testBlockKeyboard()
    section("BLOCK KEYBOARD TEST (F)")
    log("★ ส่งปุ่ม F (กด)")
    local ok1 = pcall(function()
        VirtualInputManager:SendKeyEvent(true, "F", false, game)
    end)
    task.wait(0.5)
    log("★ ส่งปุ่ม F (ปล่อย)")
    local ok2 = pcall(function()
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
    end)
    log("  กด: " .. (ok1 and "✅" or "❌"))
    log("  ปล่อย: " .. (ok2 and "✅" or "❌"))
    log("  → ดูว่าตัวละคร block ไหม")
    section("จบ KEYBOARD TEST")
end

-- ═══════════════════════════════════════════
-- 5) LIVE DETECTION
-- ═══════════════════════════════════════════
local liveEnabled = false
local liveConn
local detected = {}
local detectCount = 0

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
        name = obj.Name,
        class = obj.ClassName,
        distance = math.floor(d),
        position = fmt(obj.Position),
        owner = owner or "?",
        path = obj:GetFullName(),
    }
end

local function startLiveTest()
    if liveEnabled then log("⚠️ Live เปิดแล้ว") return end
    liveEnabled = true
    detected = {}
    detectCount = 0
    section("LIVE DETECTION เปิด")
    log("ไปยืนใกล้ศัตรู → ให้เขาตีใส่")
    log("")
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
                        detectCount = detectCount + 1
                        log(string.format(
                            "🎯 [%.1fs] %s (%s) owner=%s dist=%d",
                            tick() - tick0,
                            info.name, info.class,
                            info.owner, info.distance))
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
    log("รวมที่จับได้: " .. detectCount .. " events")
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
    pcall(function()
        VirtualInputManager:SendKeyEvent(false, "F", false, game)
    end)
end

local function startAutoBlock()
    if abEnabled then log("⚠️ AB เปิดแล้ว") return end
    abEnabled = true
    abCount = 0
    section("AUTO BLOCK PROTOTYPE เปิด")
    log("Logic:")
    log("  1. หา Hitbox/HitGlow ใกล้ตัว < 15 studs")
    log("  2. หันหน้าไปทางนั้น")
    log("  3. กด F / ยิง remote")
    log("  4. รอ 250ms แล้วปล่อย")
    log("")

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
                closestInfo.name, closestInfo.owner,
                closestInfo.distance))

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
    log("รวม block: " .. abCount .. " ครั้ง")
end

-- ═══════════════════════════════════════════
-- UTILITY: SAVE / CLEAR
-- ═══════════════════════════════════════════
local function saveToClipboard()
    local text = table.concat(Logger.Lines, "\n")
    local fn = setclipboard or toclipboard
    if fn then
        local ok = pcall(fn, text)
        if ok then
            print("[TEST] 📋 Copy log ลง clipboard (" .. #text .. " ตัวอักษร)")
        else
            print("[TEST] ❌ Copy ไม่สำเร็จ")
        end
    else
        print("[TEST] ❌ Delta ไม่มี setclipboard")
    end
end

local function clearLog()
    Logger.Lines = {}
    if Logger.FilePath and _writeFn then
        pcall(_writeFn, Logger.FilePath, "")
        writeHeader()
    end
    print("[TEST] 🗑️ ล้าง log แล้ว")
end

local function finalizeLog()
    log("")
    log("═══════════════════════════════════════════")
    log("  END OF SESSION")
    log("  Time: " .. os.date("%Y-%m-%d %H:%M:%S"))
    log("  Duration: " .. string.format("%.1fs", tick() - Logger.StartTime))
    log("  Total lines: " .. #Logger.Lines)
    log("═══════════════════════════════════════════")
    print("[TEST] ✅ Log saved to: " .. (Logger.FilePath or "(no file)"))
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local function buildGui()
    local pg = LP:WaitForChild("PlayerGui")

    local old = pg:FindFirstChild("AB_TestSuite")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "AB_TestSuite"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 340, 0, 620)
    frame.Position = UDim2.new(0, 20, 0, 60)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 44)
    title.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    title.Text = "🧪 AB Test Suite V1.1"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 15
    title.Parent = frame

    local tc = Instance.new("UICorner")
    tc.CornerRadius = UDim.new(0, 12)
    tc.Parent = title

    -- File path label
    local pathLabel = Instance.new("TextLabel")
    pathLabel.Size = UDim2.new(1, -16, 0, 32)
    pathLabel.Position = UDim2.new(0, 8, 0, 50)
    pathLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    pathLabel.Text = Logger.FilePath and ("📁 " .. Logger.FilePath)
        or "⚠️ ไม่มี writefile"
    pathLabel.TextColor3 = Logger.FilePath
        and Color3.fromRGB(150, 220, 150)
        or Color3.fromRGB(220, 150, 150)
    pathLabel.Font = Enum.Font.Code
    pathLabel.TextSize = 11
    pathLabel.TextWrapped = true
    pathLabel.Parent = frame

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1, -16, 1, -230)
    listFrame.Position = UDim2.new(0, 8, 0, 90)
    listFrame.BackgroundTransparency = 1
    listFrame.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = listFrame

    local function makeBtn(text, color, order, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 42)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Text = text
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 13
        b.LayoutOrder = order
        b.Parent = listFrame
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
    makeBtn("4️⃣ Block Keyboard Test", Color3.fromRGB(120, 100, 60), 4, testBlockKeyboard)
    makeBtn("5️⃣ Live Detection ON/OFF", Color3.fromRGB(80, 120, 120), 5, function()
        if liveEnabled then stopLiveTest() else startLiveTest() end
    end)
    makeBtn("6️⃣ AUTO BLOCK ON/OFF", Color3.fromRGB(150, 60, 60), 6, function()
        if abEnabled then stopAutoBlock() else startAutoBlock() end
    end)

    -- Utility buttons
    local utilFrame = Instance.new("Frame")
    utilFrame.Size = UDim2.new(1, -16, 0, 100)
    utilFrame.Position = UDim2.new(0, 8, 1, -105)
    utilFrame.BackgroundTransparency = 1
    utilFrame.Parent = frame

    local ulayout = Instance.new("UIListLayout")
    ulayout.Padding = UDim.new(0, 6)
    ulayout.SortOrder = Enum.SortOrder.LayoutOrder
    ulayout.Parent = utilFrame

    local function makeUtilBtn(text, color, order, onClick)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 34)
        b.BackgroundColor3 = color
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Text = text
        b.Font = Enum.Font.GothamMedium
        b.TextSize = 12
        b.LayoutOrder = order
        b.Parent = utilFrame
        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 8)
        bc.Parent = b
        b.MouseButton1Click:Connect(function()
            pcall(onClick)
        end)
    end

    makeUtilBtn("💾 Save + ปิด Session", Color3.fromRGB(60, 90, 60), 1, finalizeLog)
    makeUtilBtn("📋 Copy log ลง clipboard", Color3.fromRGB(70, 70, 100), 2, saveToClipboard)
    makeUtilBtn("🗑️ Clear log", Color3.fromRGB(100, 60, 60), 3, clearLog)

    -- Drag
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

log("")
log("═══════════════════════════════════")
log("✅ Test Suite V1.1 โหลดแล้ว")
if Logger.FilePath then
    log("📁 Save ไปที่: " .. Logger.FilePath)
else
    log("⚠️ Delta ไม่มี writefile — ใช้ปุ่ม Copy clipboard แทน")
end
log("")
log("📋 ลำดับที่ควรกด:")
log("  1 → Block Probe")
log("  2 → Face Test (เดินผ่านเพื่อน)")
log("  3 → Block Remote Test")
log("  4 → Block Keyboard Test")
log("  5 → Live Detection (สู้กับเพื่อน)")
log("  6 → AUTO BLOCK Prototype")
log("")
log("💾 หลังเทสเสร็จ → กด 'Save + ปิด Session'")
log("═══════════════════════════════════")
