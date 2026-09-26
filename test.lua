-- ╔══════════════════════════════════════╗
-- ║  Auto Block Minimal + GUI            ║
-- ║  Base: Minimal (รันได้)              ║
-- ║  + Save Button + Kill Button         ║
-- ╚══════════════════════════════════════╝

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer
local VIM = VirtualInputManager
local RS = ReplicatedStorage

-- ═══════════════════════════════════════
-- FIND REMOTES
-- ═══════════════════════════════════════
local function findRemote(path)
    local ok, obj = pcall(function()
        local cur = RS
        for _, part in ipairs(string.split(path, ".")) do
            cur = cur:FindFirstChild(part)
            if not cur then return nil end
        end
        return cur
    end)
    if ok then return obj end
    return nil
end

local HitRemote = findRemote("Knit.Knit.Services.HandicapService.RE.Hit")
local BlockRemote = findRemote("Knit.Knit.Services.BlockService.RE.Activated")
local BlockDeact = findRemote("Knit.Knit.Services.BlockService.RE.Deactivated")

-- ═══════════════════════════════════════
-- LOGGER
-- ═══════════════════════════════════════
local Logger = {
    Lines = {},
    FilePath = "ABMin_" .. os.date("%Y%m%d_%H%M%S") .. ".txt",
    JsonPath = "ABMin_" .. os.date("%Y%m%d_%H%M%S") .. ".json",
    Data = {
        meta = {
            version = "3.0",
            startedAt = os.date("%Y-%m-%d %H:%M:%S"),
            placeId = game.PlaceId,
            jobId = game.JobId,
            player = LP.Name,
        },
        blocks = {},
    },
}

local writeFn = writefile or write_file
local appendFn = appendfile or append_file

local function writeFile(path, data)
    if writeFn then return pcall(writeFn, path, data) end
    return false
end

local function appendFile(path, data)
    if appendFn then return pcall(appendFn, path, data) end
    if writeFn and readfile then
        local ok, old = pcall(readfile, path)
        return pcall(writeFn, path, (ok and old or "") .. data)
    end
    return false
end

local function log(...)
    local parts = {}
    local args = {...}
    for i = 1, #args do
        parts[i] = tostring(args[i])
    end
    local line = table.concat(parts, " ")
    print("[AB]", line)
    table.insert(Logger.Lines, line)
    appendFile(Logger.FilePath, line .. "\n")
end

-- Header
writeFile(Logger.FilePath,
    "===========================================\n" ..
    "  Auto Block Minimal + GUI\n" ..
    "  Started: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n" ..
    "  PlaceId: " .. tostring(game.PlaceId) .. "\n" ..
    "  JobId:   " .. tostring(game.JobId) .. "\n" ..
    "  Player:  " .. LP.Name .. "\n" ..
    "===========================================\n\n")

-- ═══════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════
local State = {
    Enabled = false,
    Destroyed = false,
    BlockCount = 0,
    FaceCount = 0,
    SkipCount = 0,
    LastEnemy = "-",
    LastDistance = 0,
    HitConn = nil,
    LastFaceLoop = nil,
}

-- ═══════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════
local function getMyChar()
    local c = LP.Character
    if not c then return nil, nil end
    return c, c:FindFirstChild("HumanoidRootPart")
end

local function findEnemy()
    local char, myHRP = getMyChar()
    if not myHRP then return nil, math.huge, "-" end

    local chars = workspace:FindFirstChild("Characters")
    if not chars then return nil, math.huge, "-" end

    local nearest = nil
    local minD = 30
    local name = "-"
    for _, c in ipairs(chars:GetChildren()) do
        if c:IsA("Model") and c.Name ~= LP.Name then
            local h = c:FindFirstChild("HumanoidRootPart")
            if h then
                local hum = c:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health > 0 then
                    local d = (h.Position - myHRP.Position).Magnitude
                    if d < minD then
                        nearest = h
                        minD = d
                        name = c.Name
                    end
                end
            end
        end
    end
    return nearest, minD, name
end

local function doFace()
    local enemy = findEnemy()
    if not enemy then return false end
    local _, myHRP = getMyChar()
    if not myHRP then return false end

    local ok = pcall(function()
        myHRP.CFrame = CFrame.lookAt(myHRP.Position,
            Vector3.new(enemy.Position.X, myHRP.Position.Y, enemy.Position.Z))
    end)
    if ok then
        State.FaceCount = State.FaceCount + 1
    end
    return ok
end

-- ═══════════════════════════════════════
-- BLOCK ACTIONS
-- ═══════════════════════════════════════
local function pressKeyF()
    return pcall(function()
        VIM:SendKeyEvent(true, "F", false, game)
    end)
end

local function releaseKeyF()
    return pcall(function()
        VIM:SendKeyEvent(false, "F", false, game)
    end)
end

local function fireBlockRemote()
    if not BlockRemote then return false end
    return pcall(function() BlockRemote:FireServer() end)
end

local function fireReleaseRemote()
    if not BlockDeact then return false end
    return pcall(function() BlockDeact:FireServer() end)
end

-- ═══════════════════════════════════════
-- ON HIT
-- ═══════════════════════════════════════
local function onHit(victim)
    if State.Destroyed then return end
    if not State.Enabled then return end

    if typeof(victim) ~= "Instance" then
        State.SkipCount = State.SkipCount + 1
        return
    end
    if victim.Name ~= LP.Name then
        State.SkipCount = State.SkipCount + 1
        return
    end

    -- Find enemy
    local enemy, dist, name = findEnemy()
    if not enemy then
        log("Hit at " .. os.date("%H:%M:%S") .. " - no enemy")
        State.SkipCount = State.SkipCount + 1
        return
    end

    -- Update state
    State.BlockCount = State.BlockCount + 1
    State.LastEnemy = name
    State.LastDistance = math.floor(dist)

    -- 1. Face
    doFace()

    -- 2. Block (keyboard + remote)
    pressKeyF()
    fireBlockRemote()

    -- 3. Release after 500ms
    task.delay(0.5, function()
        releaseKeyF()
        fireReleaseRemote()
    end)

    -- Log
    log("Block #" .. State.BlockCount .. " vs " .. name ..
        " (d=" .. math.floor(dist) .. ") at " .. os.date("%H:%M:%S"))

    -- Save to JSON
    table.insert(Logger.Data.blocks, {
        index = State.BlockCount,
        time = os.date("%H:%M:%S"),
        enemy = name,
        distance = math.floor(dist),
    })

    if updateGui then updateGui() end
end

-- ═══════════════════════════════════════
-- FACE LOOP (หันตลอด)
-- ═══════════════════════════════════════
local function startFaceLoop()
    if State.LastFaceLoop then return end
    State.LastFaceLoop = task.spawn(function()
        while not State.Destroyed and State.Enabled do
            doFace()
            task.wait(0.1)
        end
        State.LastFaceLoop = nil
    end)
end

-- ═══════════════════════════════════════
-- START / STOP / SAVE / DESTROY
-- ═══════════════════════════════════════
local updateGui

local function start()
    if State.Destroyed or State.Enabled then return end

    if HitRemote then
        State.HitConn = HitRemote.OnClientEvent:Connect(onHit)
        log("Hook Hit: OK")
    else
        log("Hook Hit: FAIL - no remote")
        return
    end

    State.Enabled = true
    startFaceLoop()
    log("========== START ==========")
    if updateGui then updateGui() end
end

local function stop()
    if not State.Enabled then return end

    if State.HitConn then
        State.HitConn:Disconnect()
        State.HitConn = nil
    end

    releaseKeyF()
    State.Enabled = false
    log("========== STOP ==========")
    log("Total blocks: " .. State.BlockCount)
    if updateGui then updateGui() end
end

local function saveAll()
    -- Save TXT
    log("")
    log("========== SAVE at " .. os.date("%H:%M:%S") .. " ==========")
    log("Blocks: " .. State.BlockCount)
    log("Faces: " .. State.FaceCount)
    log("Skips: " .. State.SkipCount)

    writeFile(Logger.FilePath, table.concat(Logger.Lines, "\n"))

    -- Save JSON
    Logger.Data.meta.savedAt = os.date("%Y-%m-%d %H:%M:%S")
    Logger.Data.meta.totalBlocks = State.BlockCount
    Logger.Data.meta.totalFaces = State.FaceCount
    local ok, json = pcall(function()
        return HttpService:JSONEncode(Logger.Data)
    end)
    if ok and json then
        writeFile(Logger.JsonPath, json)
    end

    print("[AB] Saved TXT:  " .. Logger.FilePath)
    print("[AB] Saved JSON: " .. Logger.JsonPath)
end

local function destroy()
    if State.Destroyed then return end
    log("========== DESTROY ==========")
    State.Destroyed = true
    stop()
    saveAll()

    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        local g = pg:FindFirstChild("ABMin")
        if g then pcall(function() g:Destroy() end) end
    end

    _G.ABMIN = nil
end

-- ═══════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════
local gui, mainBtn, statusLbl, statsLbl, saveBtn, killBtn

function updateGui()
    if not mainBtn then return end
    if State.Enabled then
        mainBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
        mainBtn.Text = "AUTO BLOCK\nON"
        statusLbl.Text = "Status: Active"
        statusLbl.TextColor3 = Color3.fromRGB(100, 255, 100)
    else
        mainBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        mainBtn.Text = "AUTO BLOCK\nOFF"
        statusLbl.Text = "Status: Idle"
        statusLbl.TextColor3 = Color3.fromRGB(255, 150, 150)
    end
end

local function buildGui()
    local pg = LP:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("ABMin")
    if old then pcall(function() old:Destroy() end) end

    gui = Instance.new("ScreenGui")
    gui.Name = "ABMin"
    gui.ResetOnSpawn = false
    gui.Parent = pg

    -- Main button
    mainBtn = Instance.new("TextButton")
    mainBtn.Size = UDim2.new(0, 180, 0, 74)
    mainBtn.Position = UDim2.new(0, 20, 0.32, 0)
    mainBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    mainBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    mainBtn.Text = "AUTO BLOCK\nOFF"
    mainBtn.TextSize = 15
    mainBtn.Font = Enum.Font.GothamBold
    mainBtn.Parent = gui
    mainBtn.Active = true

    local mc = Instance.new("UICorner")
    mc.CornerRadius = UDim.new(0, 12)
    mc.Parent = mainBtn

    -- Status
    statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(0, 180, 0, 26)
    statusLbl.Position = UDim2.new(0, 20, 0.32, 78)
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
    statsLbl.Size = UDim2.new(0, 180, 0, 90)
    statsLbl.Position = UDim2.new(0, 20, 0.32, 108)
    statsLbl.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    statsLbl.BackgroundTransparency = 0.3
    statsLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    statsLbl.Text = "Blocks: 0\nFaces: 0\nSkip: 0"
    statsLbl.TextSize = 11
    statsLbl.Font = Enum.Font.Code
    statsLbl.TextWrapped = true
    statsLbl.TextYAlignment = Enum.TextYAlignment.Top
    statsLbl.TextXAlignment = Enum.TextXAlignment.Left
    statsLbl.Parent = gui
    local stc = Instance.new("UICorner")
    stc.CornerRadius = UDim.new(0, 6)
    stc.Parent = statsLbl

    -- Save button
    saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0, 180, 0, 38)
    saveBtn.Position = UDim2.new(0, 20, 0.32, 202)
    saveBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 180)
    saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveBtn.Text = "Save TXT"
    saveBtn.TextSize = 13
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.Parent = gui
    local sb = Instance.new("UICorner")
    sb.CornerRadius = UDim.new(0, 8)
    sb.Parent = saveBtn

    -- Kill button
    killBtn = Instance.new("TextButton")
    killBtn.Size = UDim2.new(0, 180, 0, 38)
    killBtn.Position = UDim2.new(0, 20, 0.32, 246)
    killBtn.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
    killBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    killBtn.Text = "Kill Script"
    killBtn.TextSize = 13
    killBtn.Font = Enum.Font.GothamBold
    killBtn.Parent = gui
    local kb = Instance.new("UICorner")
    kb.CornerRadius = UDim.new(0, 8)
    kb.Parent = killBtn

    -- Events
    mainBtn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        if State.Enabled then stop() else start() end
    end)

    saveBtn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        saveAll()
    end)

    killBtn.MouseButton1Click:Connect(function()
        if State.Destroyed then return end
        killBtn.Text = "Killing..."
        task.wait(0.2)
        destroy()
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
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
                         or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local np = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            mainBtn.Position = np
            statusLbl.Position = UDim2.new(np.X.Scale, np.X.Offset, np.Y.Scale, np.Y.Offset + 78)
            statsLbl.Position = UDim2.new(np.X.Scale, np.X.Offset, np.Y.Scale, np.Y.Offset + 108)
            saveBtn.Position = UDim2.new(np.X.Scale, np.X.Offset, np.Y.Scale, np.Y.Offset + 202)
            killBtn.Position = UDim2.new(np.X.Scale, np.X.Offset, np.Y.Scale, np.Y.Offset + 246)
        end
    end)

    -- Update loop
    task.spawn(function()
        while gui and gui.Parent and not State.Destroyed do
            task.wait(0.3)
            if statsLbl then
                pcall(function()
                    statsLbl.Text = string.format(
                        "Blocks: %d\nFaces: %d\nSkip: %d\nLast: %s (%.0f)",
                        State.BlockCount,
                        State.FaceCount,
                        State.SkipCount,
                        State.LastEnemy,
                        State.LastDistance)
                end)
            end
        end
    end)

    updateGui()
end

buildGui()

-- ═══════════════════════════════════════
-- EXPORT API
-- ═══════════════════════════════════════
_G.ABMIN = {
    start = start,
    stop = stop,
    save = saveAll,
    destroy = destroy,
    state = State,
    logger = Logger,
}

print("===========================================")
print("AB Minimal + GUI Loaded")
print("TXT:  " .. Logger.FilePath)
print("JSON: " .. Logger.JsonPath)
print("===========================================")
