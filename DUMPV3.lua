-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Dump V2.4 | VERIFY + RETRY                                    ║
-- ║  - ตรวจก่อน save ถ้าน้อย → รอ                                      ║
-- ║  - Retry สูงสุด 3 ครั้ง                                          ║
-- ║  - Skip ถ้ายังว่าง                                              ║
-- ╚═══════════════════════════════════════════════════════════════╝

local Debug = { Log = {} }
Debug.Add = function(msg)
    if Debug and Debug.Log then
        table.insert(Debug.Log, os.date("%H:%M:%S") .. " " .. tostring(msg))
    end
end

local function G(n)
    local ok, v = pcall(function() return getfenv()[n] end)
    if ok and v ~= nil then return v end
    return _G[n]
end

local CAPS = {
    mt = type(G("getrawmetatable")) == "function",
    ro = type(G("setreadonly")) == "function",
    nc = type(G("newcclosure")) == "function",
    gnc = type(G("getnamecallmethod")) == "function",
    wf = type(G("writefile")) == "function",
    mkf = type(G("makefolder")) == "function",
    lsf = type(G("listfiles")) == "function",
    gc = type(G("getconnections")) == "function",
    ide = type(G("identifyexecutor")) == "function",
}

local function wrap(fn)
    if not CAPS.nc then return fn end
    local ok, w = pcall(G("newcclosure"), fn)
    return ok and w or fn
end

local function p2(...) print("[V2.4]", ...) end

local EXEC = "Unknown"
if CAPS.ide then
    local ok, n = pcall(G("identifyexecutor"))
    if ok then EXEC = tostring(n) end
end

p2("Dump V2.4 | " .. EXEC)

pcall(function()
    for _, g in ipairs(game:GetService("CoreGui"):GetChildren()) do
        if g.Name:find("^DumpV") then g:Destroy() end
    end
end)

-- ANTIKICK
local AntiKick = { KicksBlocked = 0, TeleportBlocked = 0 }
do
    if CAPS.mt and CAPS.ro and CAPS.gnc then
        local Players = game:GetService("Players")
        local LP = Players.LocalPlayer
        local ok, mt = pcall(G("getrawmetatable"), game)
        if ok and mt then
            local oldNC = rawget(mt, "__namecall")
            if type(oldNC) == "function" then
                local ro = G("setreadonly")
                local gnc = G("getnamecallmethod")
                pcall(ro, mt, false)
                mt.__namecall = wrap(function(self, ...)
                    local ok2, method = pcall(gnc)
                    if ok2 then
                        if method == "Kick" and (self == LP or self == Players) then
                            AntiKick.KicksBlocked = AntiKick.KicksBlocked + 1
                            return nil
                        end
                    end
                    return oldNC(self, ...)
                end)
                pcall(ro, mt, true)
                p2("AntiKick OK")
            end
        end
    end
end

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local LP = Players.LocalPlayer

-- FOLDER
local function sanitize(name)
    if not name or name == "" then return "UnknownGame" end
    name = tostring(name)
    name = name:gsub("[^%w%s%-_]", "")
    name = name:gsub("%s+", "_")
    name = name:gsub("_+", "_")
    name = name:gsub("^_", ""):gsub("_$", "")
    if #name > 40 then name = name:sub(1, 40) end
    if #name == 0 then name = "UnknownGame" end
    return name
end

local function getGameName()
    local ok, info = pcall(function()
        return MarketplaceService:GetProductInfo(game.PlaceId)
    end)
    if ok and info and info.Name and info.Name ~= "" then
        return sanitize(info.Name)
    end
    return "Place_" .. tostring(game.PlaceId)     -- ★ fallback
end

local function getNextSession(basePath)
    if not CAPS.lsf then return 1 end
    local ok, files = pcall(G("listfiles"), basePath)
    if not ok or type(files) ~= "table" then return 1 end
    local maxNum = 0
    for _, path in ipairs(files) do
        local n = path:match("session_(%d+)")
        if n then
            local num = tonumber(n)
            if num and num > maxNum then maxNum = num end
        end
    end
    return maxNum + 1
end

local function mkdirp(path)
    if not CAPS.mkf then return end
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end
    local acc = ""
    for i, part in ipairs(parts) do
        if i == 1 then acc = part
        else acc = acc .. "/" .. part end
        pcall(G("makefolder"), acc)
    end
end

local SESSION = {
    Version = "2.4.0",
    Timestamp = os.date("%Y%m%d_%H%M%S"),
    PlaceId = tostring(game.PlaceId),
    JobId = game.JobId,
    GameName = "Unknown",
    SessionNum = 1,
}

local CFG = { BaseFolder = "DumpV1" }

local function setupSession()
    SESSION.GameName = getGameName()
    p2("GameName: " .. SESSION.GameName)
    
    mkdirp(CFG.BaseFolder)
    local gameFolder = CFG.BaseFolder .. "/" .. SESSION.GameName
    mkdirp(gameFolder)
    
    SESSION.SessionNum = getNextSession(gameFolder)
    
    local sessionName = string.format("session_%03d_%s",
        SESSION.SessionNum, SESSION.Timestamp)
    CFG.OutputFolder = gameFolder .. "/" .. sessionName
    mkdirp(CFG.OutputFolder)
    
    p2("Session: #" .. SESSION.SessionNum)
end

setupSession()

-- FILE
local function writeFile(path, data)
    if not CAPS.wf then return false end
    return pcall(G("writefile"), path, data)
end

-- UTILS
local function vec(v)
    if not v then return nil end
    return string.format("%.1f,%.1f,%.1f", v.X, v.Y, v.Z)
end

local function dist(part)
    local myChar = LP.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHRP or not part then return nil end
    local ok, d = pcall(function()
        return math.floor((part.Position - myHRP.Position).Magnitude)
    end)
    return ok and d or nil
end

-- SAVE
local Index = {}

local function saveJSON(name, data)
    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return false end
    
    local path = CFG.OutputFolder .. "/" .. name .. ".json"
    local wok = writeFile(path, json)
    
    if wok then
        local kb = #json / 1024
        local cnt = 0
        if type(data) == "table" then
            if #data > 0 then cnt = #data
            else
                for _ in pairs(data) do cnt = cnt + 1 end
            end
        end
        p2(string.format("  %-22s → %6.1fKB | %d", name, kb, cnt))
        table.insert(Index, {
            name = name, path = path,
            size_bytes = #json, count = cnt,
        })
        return true
    end
    return false
end

local function saveIndexFile()
    local path = CFG.OutputFolder .. "/_INDEX.json"
    local json = HttpService:JSONEncode({
        Version = SESSION.Version,
        Session = SESSION,
        Files = Index,
        AntiKick = AntiKick,
        Debug = Debug.Log,
    })
    writeFile(path, json)
end

-- ★★★ ตรวจ Characters ★★★
local function verifyCharacters()
    local folder = workspace:FindFirstChild("Characters")
    if folder then
        local count = 0
        for _, c in ipairs(folder:GetChildren()) do
            if c:IsA("Model") then count = count + 1 end
        end
        if count > 0 then return count, folder end
    end
    
    -- Fallback: count models with Humanoid
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") 
           and obj:FindFirstChildOfClass("Humanoid")
           and obj:FindFirstChild("HumanoidRootPart") then
            count = count + 1
        end
    end
    return count, nil
end

-- ★★★ DUMP FUNCTIONS ★★★

local function dump_info()
    saveJSON("01_info", {
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        Executor = EXEC,
        GameName = SESSION.GameName,
        SessionNum = SESSION.SessionNum,
        PlayerCount = #Players:GetPlayers(),
        MaxPlayers = Players.MaxPlayers,
        MyName = LP.Name,
        Time = os.date("%Y-%m-%d %H:%M:%S"),
    })
end

local function dump_players()
    local result = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local e = {
            Name = plr.Name,
            DisplayName = plr.DisplayName,
            UserId = plr.UserId,
            HasCharacter = plr.Character ~= nil,
        }
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hrp then
                e.Position = vec(hrp.Position)
                e.Distance = dist(hrp)
            end
            if hum then
                e.Health = hum.Health
                e.MaxHealth = hum.MaxHealth
            end
        end
        table.insert(result, e)
    end
    saveJSON("02_players", result)
end

local function dump_characters()
    local result = {}
    local folder = workspace:FindFirstChild("Characters")
    
    p2("  Characters: " .. (folder and (#folder:GetChildren() .. " children") or "NIL"))
    
    if folder then
        for _, char in ipairs(folder:GetChildren()) do
            if char:IsA("Model") then
                local e = {
                    Name = char.Name,
                    Path = char:GetFullName(),
                    Children = {},
                    ValueObjects = {},
                }
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    e.Position = vec(hrp.Position)
                    e.Distance = dist(hrp)
                end
                for _, c in ipairs(char:GetChildren()) do
                    table.insert(e.Children, { Name = c.Name, Class = c.ClassName })
                end
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("ValueBase") then
                        table.insert(e.ValueObjects, {
                            Name = d.Name, Class = d.ClassName,
                            Value = tostring(d.Value),
                        })
                    end
                end
                table.insert(result, e)
            end
        end
    else
        -- Fallback
        p2("  Fallback: scan Model+Humanoid")
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") 
               and obj:FindFirstChildOfClass("Humanoid")
               and obj:FindFirstChild("HumanoidRootPart") then
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                local hum = obj:FindFirstChildOfClass("Humanoid")
                table.insert(result, {
                    Name = obj.Name,
                    Path = obj:GetFullName(),
                    Position = vec(hrp.Position),
                    Distance = dist(hrp),
                    Health = hum.Health,
                    MaxHealth = hum.MaxHealth,
                    Source = "fallback",
                })
            end
        end
    end
    saveJSON("03_characters", result)
end

local function dump_all_models()
    local result = {}
    local charsFolder = workspace:FindFirstChild("Characters")
    local charNames = {}
    if charsFolder then
        for _, c in ipairs(charsFolder:GetChildren()) do
            charNames[c] = true
        end
    end
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and not charNames[obj] then
            local e = {
                Name = obj.Name,
                Class = obj.ClassName,
                Path = obj:GetFullName(),
                ChildCount = #obj:GetChildren(),
            }
            local part = obj.PrimaryPart
                or obj:FindFirstChildWhichIsA("BasePart", true)
            if part then
                e.Position = vec(part.Position)
                e.Distance = dist(part)
            end
            local hum = obj:FindFirstChildOfClass("Humanoid")
            if hum then
                e.HasHumanoid = true
                e.Health = hum.Health
                e.MaxHealth = hum.MaxHealth
            end
            table.insert(result, e)
        end
    end
    saveJSON("04_all_models", result)
end

local function dump_workspace_tree()
    local result = {}
    local LIMIT = 20000
    local function walk(obj, depth)
        if depth > 4 then return end
        if #result >= LIMIT then return end
        local entry = {
            Name = obj.Name,
            Class = obj.ClassName,
            Path = obj:GetFullName(),
            ChildCount = #obj:GetChildren(),
            Depth = depth,
        }
        if obj:IsA("BasePart") then
            entry.Position = vec(obj.Position)
        end
        table.insert(result, entry)
        for _, child in ipairs(obj:GetChildren()) do
            if #result >= LIMIT then return end
            walk(child, depth + 1)
        end
    end
    for _, top in ipairs(workspace:GetChildren()) do
        if not top:IsA("Camera") then walk(top, 1) end
    end
    saveJSON("05_workspace_tree", result)
end

local function dump_by_class()
    local byClass = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        local c = obj.ClassName
        if not byClass[c] then byClass[c] = {} end
        table.insert(byClass[c], obj)
    end
    local result = {}
    for cls, list in pairs(byClass) do
        if #list >= 1 then
            local items = {}
            local limit = math.min(#list, 500)
            for i = 1, limit do
                local obj = list[i]
                local e = { Name = obj.Name, Path = obj:GetFullName() }
                if obj:IsA("BasePart") then
                    e.Position = vec(obj.Position)
                    e.Distance = dist(obj)
                end
                table.insert(items, e)
            end
            result[cls] = { total = #list, sample = items }
        end
    end
    saveJSON("06_by_class", result)
end

local function dump_char_detail()
    local result = {}
    local folder = workspace:FindFirstChild("Characters")
    if not folder then
        p2("  skip char detail")
        saveJSON("07_char_detail", result)
        return
    end
    for _, char in ipairs(folder:GetChildren()) do
        if char:IsA("Model") then
            local info = { Name = char.Name, Children = {} }
            for _, c in ipairs(char:GetChildren()) do
                local childInfo = { Name = c.Name, Class = c.ClassName }
                if c:IsA("Folder") then
                    childInfo.SubChildren = {}
                    for _, sc in ipairs(c:GetChildren()) do
                        table.insert(childInfo.SubChildren, {
                            Name = sc.Name, Class = sc.ClassName,
                        })
                    end
                end
                table.insert(info.Children, childInfo)
            end
            table.insert(result, info)
        end
    end
    saveJSON("07_char_detail", result)
end

local function dump_rs()
    local result = { TopLevel = {}, Total = 0 }
    for _, obj in ipairs(RS:GetChildren()) do
        table.insert(result.TopLevel, {
            Name = obj.Name,
            Class = obj.ClassName,
            ChildCount = #obj:GetChildren(),
            DescendantCount = #obj:GetDescendants(),
            Path = obj:GetFullName(),
        })
        result.Total = result.Total + 1
    end
    saveJSON("11_replicatedstorage", result)
end

local function dump_remotes()
    local result = {}
    for _, obj in ipairs(game:GetDescendants()) do
        local c = obj.ClassName
        if c == "RemoteEvent" or c == "RemoteFunction"
           or c == "UnreliableRemoteEvent" then
            table.insert(result, {
                Name = obj.Name,
                Class = c,
                Path = obj:GetFullName(),
            })
        end
    end
    saveJSON("12_remotes_list", result)
end

local function dump_spy()
    if not CAPS.gc then
        saveJSON("13_passive_spy", { error = "no getconnections" })
        return
    end
    local gc = G("getconnections")
    local result = {}
    for _, obj in ipairs(game:GetDescendants()) do
        local c = obj.ClassName
        if c == "RemoteEvent" or c == "UnreliableRemoteEvent" then
            local ok, conns = pcall(gc, obj.OnClientEvent)
            if ok and type(conns) == "table" and #conns > 0 then
                result[obj.Name] = {
                    path = obj:GetFullName(),
                    class = c,
                    listeners = #conns,
                }
            end
        end
    end
    saveJSON("13_passive_spy", result)
end

-- ★★★ RUN ALL + VERIFY ★★★
local function runFullDump()
    p2("")
    p2("═══════════════════════════════════════════")
    p2("🚀 FULL DUMP V2.4")
    p2("═══════════════════════════════════════════")
    
    local t0 = tick()
    
    -- ★★★ VERIFY: รอ Characters ★★★
    p2("🔍 รอให้เกมพร้อม...")
    local attempts = 0
    local maxAttempts = 6
    local charCount = 0
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        charCount = verifyCharacters()
        p2(string.format("  ลองครั้งที่ %d: Characters = %d", attempts, charCount))
        
        if charCount > 0 then
            p2("  ✅ พร้อมแล้ว")
            break
        end
        
        if attempts < maxAttempts then
            p2("  ⏳ รอ 3 วิ...")
            task.wait(3)
        end
    end
    
    if charCount == 0 then
        p2("  ⚠️ ไม่เจอ Characters — ลองรันใหม่ในเซิร์ฟที่มีคน")
    end
    
    task.wait(0.5)
    
    p2("[1] Info")
    dump_info()
    
    p2("[2] Players")
    dump_players()
    
    p2("[3] Characters")
    dump_characters()
    
    p2("[4] All Models")
    dump_all_models()
    
    p2("[5] Workspace Tree")
    dump_workspace_tree()
    
    p2("[6] By Class")
    dump_by_class()
    
    p2("[7] Char Detail")
    dump_char_detail()
    
    p2("[8] RS")
    dump_rs()
    
    p2("[9] Remotes")
    dump_remotes()
    
    p2("[10] Spy")
    dump_spy()
    
    saveIndexFile()
    
    local elapsed = tick() - t0
    p2("")
    p2("═══════════════════════════════════════════")
    p2("✅ DONE in " .. string.format("%.2fs", elapsed))
    p2("📁 " .. CFG.OutputFolder)
    p2("═══════════════════════════════════════════")
end

-- DIAG
local function runDiag()
    p2("═══ DIAG ═══")
    local chars = workspace:FindFirstChild("Characters")
    if chars then
        p2("Characters: " .. #chars:GetChildren() .. " children")
        local models = 0
        for _, c in ipairs(chars:GetChildren()) do
            if c:IsA("Model") then models = models + 1 end
        end
        p2("  Models: " .. models)
    else
        p2("Characters: NIL")
    end
    
    local remotes = 0
    for _, obj in ipairs(game:GetDescendants()) do
        local c = obj.ClassName
        if c == "RemoteEvent" or c == "RemoteFunction"
           or c == "UnreliableRemoteEvent" then
            remotes = remotes + 1
        end
    end
    p2("Remotes: " .. remotes)
    p2("Players: " .. #Players:GetPlayers())
    p2("GameName: " .. SESSION.GameName)
    p2("Session: #" .. SESSION.SessionNum)
    
    -- เช็ค fallback characters
    local fb = verifyCharacters()
    p2("Fallback char count: " .. fb)
    
    p2("═══ END ═══")
end

-- GUI
local GUI = { enabled = false, lines = {} }

local function makeGUI()
    local ok = pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Name = "DumpV2"
        sg.ResetOnSpawn = false
        pcall(function() sg.Parent = game:GetService("CoreGui") end)
        if not sg.Parent then
            sg.Parent = LP:WaitForChild("PlayerGui", 5)
        end
        
        local f = Instance.new("Frame")
        f.Size = UDim2.new(0, 460, 0, 380)
        f.Position = UDim2.new(0, 15, 0, 15)
        f.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
        f.BackgroundTransparency = 0.1
        f.BorderSizePixel = 0
        f.Active = true
        f.Draggable = true
        f.Parent = sg
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        
        local st = Instance.new("UIStroke", f)
        st.Color = Color3.fromRGB(70, 110, 200)
        
        local title = Instance.new("Frame")
        title.Size = UDim2.new(1, 0, 0, 28)
        title.BackgroundColor3 = Color3.fromRGB(30, 45, 80)
        title.BorderSizePixel = 0
        title.Active = true
        title.Parent = f
        Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)
        
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.new(1, -80, 0, 28)
        tl.Position = UDim2.new(0, 8, 0, 0)
        tl.BackgroundTransparency = 1
        tl.Text = "Dump V2.4 VERIFY"
        tl.TextColor3 = Color3.fromRGB(220, 230, 255)
        tl.Font = Enum.Font.GothamBold
        tl.TextSize = 12
        tl.TextXAlignment = Enum.TextXAlignment.Left
        tl.Active = false
        tl.Parent = title
        
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 22, 0, 22)
        closeBtn.Position = UDim2.new(1, -25, 0, 3)
        closeBtn.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
        closeBtn.BorderSizePixel = 0
        closeBtn.Text = "×"
        closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeBtn.Font = Enum.Font.GothamBold
        closeBtn.TextSize = 16
        closeBtn.Parent = title
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 4)
        
        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, 0, 1, -28)
        body.Position = UDim2.new(0, 0, 0, 28)
        body.BackgroundTransparency = 1
        body.Active = false
        body.Parent = f
        
        local status = Instance.new("TextLabel")
        status.Size = UDim2.new(1, -20, 0, 16)
        status.Position = UDim2.new(0, 10, 0, 2)
        status.BackgroundTransparency = 1
        status.Text = "● READY"
        status.TextColor3 = Color3.fromRGB(100, 255, 120)
        status.Font = Enum.Font.Code
        status.TextSize = 11
        status.TextXAlignment = Enum.TextXAlignment.Left
        status.Active = false
        status.Parent = body
        
        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -20, 0, 14)
        info.Position = UDim2.new(0, 10, 0, 20)
        info.BackgroundTransparency = 1
        info.Text = "📁 " .. SESSION.GameName
            .. " | Session #" .. SESSION.SessionNum
        info.TextColor3 = Color3.fromRGB(140, 150, 180)
        info.Font = Enum.Font.Code
        info.TextSize = 9
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextTruncate = Enum.TextTruncate.AtEnd
        info.Active = false
        info.Parent = body
        
        local function mkBtn(text, x, y, w, color)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, w, 0, 26)
            b.Position = UDim2.new(0, x, 0, y)
            b.BackgroundColor3 = color
            b.BorderSizePixel = 0
            b.Text = text
            b.TextColor3 = Color3.fromRGB(240, 240, 255)
            b.Font = Enum.Font.GothamBold
            b.TextSize = 11
            b.Parent = body
            Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
            return b
        end
        
        local runBtn = mkBtn("▶ FULL DUMP", 10, 44, 130, Color3.fromRGB(50, 120, 60))
        local diagBtn = mkBtn("📋 DIAG", 145, 44, 80, Color3.fromRGB(140, 90, 40))
        local clearBtn = mkBtn("🗑 CLEAR", 230, 44, 90, Color3.fromRGB(100, 70, 40))
        local close2Btn = mkBtn("× CLOSE", 325, 44, 100, Color3.fromRGB(160, 50, 50))
        
        local logFrame = Instance.new("ScrollingFrame")
        logFrame.Size = UDim2.new(1, -20, 1, -110)
        logFrame.Position = UDim2.new(0, 10, 0, 80)
        logFrame.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
        logFrame.BorderSizePixel = 0
        logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        logFrame.ScrollBarThickness = 3
        logFrame.Active = false
        logFrame.Parent = body
        Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 4)
        
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 1)
        layout.Parent = logFrame
        
        GUI.sg = sg
        GUI.status = status
        GUI.info = info
        GUI.logFrame = logFrame
        GUI.layout = layout
        GUI.runBtn = runBtn
        GUI.diagBtn = diagBtn
        GUI.clearBtn = clearBtn
        GUI.close2Btn = close2Btn
        GUI.closeBtn = closeBtn
        GUI.enabled = true
    end)
end

makeGUI()

local function logGUI(msg, color)
    if not GUI.enabled or not GUI.logFrame then return end
    pcall(function()
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -4, 0, 12)
        l.BackgroundTransparency = 1
        l.Text = " " .. msg
        l.TextColor3 = color or Color3.fromRGB(140, 200, 140)
        l.Font = Enum.Font.Code
        l.TextSize = 9
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Active = false
        l.Parent = GUI.logFrame
        table.insert(GUI.lines, l)
        if #GUI.lines > 60 then
            local old = table.remove(GUI.lines, 1)
            if old then old:Destroy() end
        end
        GUI.logFrame.CanvasSize = UDim2.new(0, 0, 0,
            GUI.layout.AbsoluteContentSize.Y + 4)
        GUI.logFrame.CanvasPosition = Vector2.new(0,
            GUI.layout.AbsoluteContentSize.Y)
    end)
end

local origP2 = p2
p2 = function(...)
    local parts = {}
    for _, v in ipairs({...}) do
        table.insert(parts, tostring(v))
    end
    local msg = table.concat(parts, " ")
    origP2(msg)
    logGUI(msg)
end

if GUI.enabled then
    GUI.runBtn.MouseButton1Click:Connect(function()
        if GUI.status then
            GUI.status.Text = "● DUMPING..."
            GUI.status.TextColor3 = Color3.fromRGB(255, 220, 100)
        end
        task.spawn(function()
            pcall(runFullDump)
            if GUI.status then
                GUI.status.Text = "● DONE"
                GUI.status.TextColor3 = Color3.fromRGB(100, 255, 120)
            end
        end)
    end)
    
    GUI.diagBtn.MouseButton1Click:Connect(function()
        task.spawn(runDiag)
    end)
    
    GUI.clearBtn.MouseButton1Click:Connect(function()
        for _, l in ipairs(GUI.lines) do l:Destroy() end
        GUI.lines = {}
        GUI.logFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    end)
    
    GUI.close2Btn.MouseButton1Click:Connect(function()
        pcall(function() GUI.sg:Destroy() end)
    end)
    GUI.closeBtn.MouseButton1Click:Connect(function()
        pcall(function() GUI.sg:Destroy() end)
    end)
end

p2("═══════════════════════════════════════════")
p2("Dump V2.4 | " .. EXEC)
p2("═══════════════════════════════════════════")
p2("")
p2("📁 " .. CFG.OutputFolder)
p2("")
p2("★ กด 📋 DIAG ก่อน → ดู console")
p2("★ ถ้า Characters > 0 → กด ▶ FULL DUMP")
p2("")
