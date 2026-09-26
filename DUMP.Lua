-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Dump Framework V3.7 | NO STACK OVERFLOW EDITION              ║
-- ║  By Boomxico | Delta Executor                                 ║
-- ║  Fix: HitboxWatcher | Unhook Clean | Low Skip                 ║
-- ╚═══════════════════════════════════════════════════════════════╝

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 1: SESSION INFO                  ║
-- ╚═══════════════════════════════════════════╝
local SESSION = {
    Version = "3.7.0",
    StartedAt = os.date("%Y-%m-%d %H:%M:%S"),
    Timestamp = os.date("%Y%m%d_%H%M%S"),
    PlaceId = tostring(game.PlaceId),
    JobId = game.JobId,
}

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 2: CONFIG                        ║
-- ╚═══════════════════════════════════════════╝
local Config = {
    Version = SESSION.Version,
    Author  = "Boomxico",
    BaseFolder = "BoomxicoDumps",
    UseSessionFolder = true,
    SessionNameFormat = "V37_%s_%s",
    AutoCleanupOldSessions = true,
    CleanupKeepDays = 7,
    CleanupMaxSessions = 10,

    Wave = {
        DelayBetween = 3,
        SaveEach = true,
    },

    Targets = {
        Info              = true,
        Players           = true,
        PlayersCharacter  = true,
        Lighting          = true,
        SoundService      = true,
        StarterGui        = true,
        TerrainInfo       = true,
        Workspace         = true,
        ReplicatedStorage = true,
        SmartScan         = true,
        BlockServiceScan  = true,
        CharacterRemotes  = true,
        UnreliableScan    = true,
        TargetedHook      = true,
        HitboxWatcher     = true,
        Analysis          = true,
    },

    Limits = {
        MaxDepth     = 5,
        MaxObjects   = 40000,
        MaxStringLen = 250,
        MaxGuiDepth  = 4,
        HookLog      = 1500,
        HitboxLog    = 3000,
    },

    Filter = {
        IgnoreClasses = { "Decal", "Texture" },
    },

    Options = {
        StoreFullPath   = true,
        StoreCFrame     = false,
        StoreSource     = false,
        StoreAttributes = true,
        StoreTags       = true,
    },

    Stealth = {
        Enabled           = true,
        RandomizeDelay    = true,
        DelayMin          = 0.05,
        DelayMax          = 0.15,
        ChunkSize         = 40,
        ChunkDelay        = 0.1,
        RandomStartDelay  = true,
        SuppressErrors    = true,
    },

    TargetedHook = {
        WhitelistRemotes = {
            "HandicapService.RE.Hit",
            "BlockService.RE.Activated",
            "BlockService.RE.Effects",
        },
        BlacklistRemotes = {
            "AntiCheatService",
            "Camera",
        },
        RunDuration = 30,
        HookClientEvent = true,
        RemoteClasses = {
            "RemoteEvent",
            "RemoteFunction",
            "UnreliableRemoteEvent",
        },
        DedupeWindow = 0.1,
    },

    -- ★★★ V3.7: HitboxWatcher ปรับใหม่ ★★★
    HitboxWatcher = {
        RunDuration = 30,
        PollRate    = 0.05,              -- ★ 50ms (จาก 10ms)
        MinTransparency = 0.5,
        UseChildAdded = true,
        -- ★ Scan เฉพาะ Effects (ไม่ scan ทั้ง workspace)
        ScanTargets = { "Effects" },
        -- ★ Filter
        RequireNames = {
            "hitglow", "hitbox", "slashhit", "chasehit",
            "hardhit", "roughhit", "grabcollision",
            "combattrail", "counterswing", "strike",
        },
        IgnoreSelfOwner = true,
        MaxValidDurationMs = 2000,
    },

    SmartDump = {
        CollectiblePatterns = {
            "Coin","Gem","Chest","Item","Drop","Pickup","Orb","Shard",
            "Token","Reward","Loot","Seed","Fruit","Crystal","Scroll",
            "Key","Star","Box","Bag","Egg","Potion",
        },
        EnemyPatterns = {
            "Enemy","Boss","Mob","NPC","Monster","Dummy","Target",
            "Guard","Minion","Zombie","Soldier","Bandit","Goblin",
        },
        PortalPatterns = {
            "Portal","Door","Gate","Entrance","Teleport","Exit","Warp",
        },
        RemotePatterns = {
            "Attack","Parry","Block","Hit","Damage","Combat",
            "Hitbox","Activated","Deactivated","Melee","M1","M2",
            "Ultimate","Chase","LOOK",
        },
        HitboxPatterns = {
            "Hitbox","Trigger","Zone","Region","Detection","Hit","Damage","Touch",
        },
        SpawnPatterns = {
            "Spawn","SpawnPoint","SpawnLocation","Spawner",
        },
        AntiCheatSigns = {
            "AntiCheat","AC_","_AC","Watchdog",
        },
        ImportantServices = {
            "BlockService", "HitboxService", "CustomService",
            "AntiCheatService", "MovementService", "ItemService",
            "HandicapService",
        },
    },
}

if Config.UseSessionFolder then
    Config.OutputFolder = string.format(
        Config.SessionNameFormat, SESSION.PlaceId, SESSION.Timestamp)
    Config.OutputFolder = Config.BaseFolder .. "/" .. Config.OutputFolder
else
    Config.OutputFolder = Config.BaseFolder
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 3: SERVICES                      ║
-- ╚═══════════════════════════════════════════╝
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Lighting           = game:GetService("Lighting")
local SoundService       = game:GetService("SoundService")
local StarterGui         = game:GetService("StarterGui")
local HttpService        = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService  = game:GetService("CollectionService")
local RunService         = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local scriptAlive = true

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 4: ENV RESOLVER                  ║
-- ╚═══════════════════════════════════════════╝
local function resolveEnv()
    local ok, env = pcall(function()
        if type(getfenv) == "function" then return getfenv() end
        return _G
    end)
    if ok and type(env) == "table" then return env end
    return _G
end

local ENV = resolveEnv()

local function rawGetGlobal(name)
    local ok, v = pcall(function() return ENV[name] end)
    if ok and v ~= nil then return v end
    local ok2, v2 = pcall(function() return _G[name] end)
    if ok2 and v2 ~= nil then return v2 end
    return nil
end

local caps = {
    newcclosure       = type(rawGetGlobal("newcclosure")) == "function",
    hookfunction      = type(rawGetGlobal("hookfunction")) == "function",
    restorefunction   = type(rawGetGlobal("restorefunction")) == "function",
    identifyexecutor  = type(rawGetGlobal("identifyexecutor")) == "function",
    listfiles         = type(rawGetGlobal("listfiles")) == "function",
    delfolder         = type(rawGetGlobal("delfolder")) == "function",
}

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 5: FILE API                      ║
-- ╚═══════════════════════════════════════════╝
local FileAPI = {}

local function findFn(names)
    for _, name in ipairs(names) do
        local fn = rawGetGlobal(name)
        if type(fn) == "function" then return fn end
    end
    return nil
end

local _writeFn      = findFn({"writefile","write_file","WriteFile"})
local _appendFn     = findFn({"appendfile","append_file"})
local _isFolderFn   = findFn({"isfolder","is_folder","IsFolder"})
local _isFileFn     = findFn({"isfile","is_file","IsFile"})
local _makeFolderFn = findFn({"makefolder","make_folder","MakeFolder"})
local _listFilesFn  = findFn({"listfiles","list_files","ListFiles"})
local _delFolderFn  = findFn({"delfolder","del_folder","DeleteFolder"})

local MEMORY_STORE = {}
local USE_MEMORY_FALLBACK = (_writeFn == nil)

_G.BoomxicoDumpStore = MEMORY_STORE

function FileAPI.hasWriteSupport() return _writeFn ~= nil end
function FileAPI.canList()         return _listFilesFn ~= nil end
function FileAPI.canDeleteFolder() return _delFolderFn ~= nil end

function FileAPI.exists(path)
    if USE_MEMORY_FALLBACK then return MEMORY_STORE[path] ~= nil end
    if _isFolderFn then
        local ok, r = pcall(_isFolderFn, path)
        if ok and r then return true end
    end
    if _isFileFn then
        local ok, r = pcall(_isFileFn, path)
        if ok and r then return true end
    end
    return false
end

function FileAPI.mkdir(path)
    if USE_MEMORY_FALLBACK then
        MEMORY_STORE[path] = MEMORY_STORE[path] or {}
        return true
    end
    if not _makeFolderFn then return false end
    if FileAPI.exists(path) then return true end
    return pcall(_makeFolderFn, path)
end

function FileAPI.mkdirp(path)
    local parts = {}
    for part in string.gmatch(path, "[^/]+") do
        table.insert(parts, part)
    end
    local acc = ""
    for i, part in ipairs(parts) do
        if i == 1 then acc = part
        else acc = acc .. "/" .. part end
        FileAPI.mkdir(acc)
    end
    return true
end

function FileAPI.write(path, data)
    if USE_MEMORY_FALLBACK then
        MEMORY_STORE[path] = data
        return true
    end
    local ok, err = pcall(_writeFn, path, data)
    if not ok then MEMORY_STORE[path] = data end
    return ok, err
end

function FileAPI.append(path, data)
    if _appendFn then return pcall(_appendFn, path, data) end
    local old = MEMORY_STORE[path] or ""
    return FileAPI.write(path, old .. data)
end

function FileAPI.list(path)
    if not _listFilesFn then return {} end
    local ok, r = pcall(_listFilesFn, path)
    if ok and type(r) == "table" then return r end
    return {}
end

function FileAPI.deleteFolder(path)
    if _delFolderFn then return pcall(_delFolderFn, path) end
    return false
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 6: SESSION CLEANUP               ║
-- ╚═══════════════════════════════════════════╝
local Cleaner = {}

function Cleaner.parseTimestamp(name)
    local y, mo, d, h, mi, s = name:match("(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)(%d%d)")
    if not y then return nil end
    local ok, t = pcall(function()
        return os.time({
            year = tonumber(y), month = tonumber(mo), day = tonumber(d),
            hour = tonumber(h), min = tonumber(mi), sec = tonumber(s),
        })
    end)
    return ok and t or nil
end

function Cleaner.listSessions()
    if not FileAPI.canList() then return nil end
    local base = Config.BaseFolder
    if not FileAPI.exists(base) then return {} end
    local files = FileAPI.list(base)
    local sessions = {}
    for _, path in ipairs(files) do
        local name = path:match("([^/]+)$")
        if name and (name:match("^V%d") or name:match("^Session")) then
            local isFolder = true
            if _isFolderFn then
                local ok, r = pcall(_isFolderFn, path)
                isFolder = ok and r
            end
            if isFolder then
                table.insert(sessions, {
                    path = path, name = name,
                    ts = Cleaner.parseTimestamp(name),
                })
            end
        end
    end
    table.sort(sessions, function(a, b)
        if not a.ts then return false end
        if not b.ts then return true end
        return a.ts < b.ts
    end)
    return sessions
end

function Cleaner.cleanup()
    if not Config.AutoCleanupOldSessions then return end
    if not FileAPI.canDeleteFolder() then return end
    local sessions = Cleaner.listSessions()
    if not sessions then return end
    local now = os.time()
    local keepSec = Config.CleanupKeepDays * 24 * 60 * 60
    local toDelete = {}
    for _, s in ipairs(sessions) do
        if s.ts and (now - s.ts) > keepSec then
            table.insert(toDelete, s)
        end
    end
    local remaining = {}
    for _, s in ipairs(sessions) do
        local inDel = false
        for _, d in ipairs(toDelete) do
            if d.path == s.path then inDel = true break end
        end
        if not inDel then table.insert(remaining, s) end
    end
    if #remaining > Config.CleanupMaxSessions then
        local extra = #remaining - Config.CleanupMaxSessions
        for i = 1, extra do table.insert(toDelete, remaining[i]) end
    end
    for _, s in ipairs(toDelete) do
        FileAPI.deleteFolder(s.path)
    end
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 7: UTILS                         ║
-- ╚═══════════════════════════════════════════╝
local Utils = {}

function Utils.safe(fn, ...)
    local ok, r = pcall(fn, ...)
    if ok then return r, nil end
    return nil, tostring(r)
end

function Utils.truncate(s, maxLen)
    s = tostring(s)
    if #s <= maxLen then return s end
    return string.sub(s, 1, maxLen) .. "..."
end

function Utils.formatColor(c)
    if c == nil then return "?" end
    local t = typeof(c)
    if t == "BrickColor" then
        local ok, col = pcall(function() return c.Color end)
        if ok and col then
            return string.format("%.3f,%.3f,%.3f [%s]",
                col.R, col.G, col.B, tostring(c))
        end
        return tostring(c)
    end
    if t == "Color3" then
        return string.format("%.3f,%.3f,%.3f", c.R, c.G, c.B)
    end
    return tostring(c)
end

function Utils.formatVector(v)
    if not v then return "?" end
    return string.format("%.3f,%.3f,%.3f", v.X, v.Y, v.Z)
end

function Utils.formatPosition(p)
    if not p then return nil end
    return { X = p.X, Y = p.Y, Z = p.Z }
end

function Utils.makeTimestamp()
    local t = os.date("*t")
    return string.format("%04d%02d%02d_%02d%02d%02d",
        t.year, t.month, t.day, t.hour, t.min, t.sec)
end

local LP = "[DumpV3]"
function Utils.log(m)  print(LP .. " " .. tostring(m)) end
function Utils.ok(m)   print(LP .. " ✅ " .. tostring(m)) end
function Utils.warn(m) warn(LP .. " ⚠️ " .. tostring(m)) end
function Utils.hint(m) print(LP .. " 💡 " .. tostring(m)) end

function Utils.matchPattern(name, patterns)
    if not name then return false, nil end
    local lower = string.lower(name)
    for _, p in ipairs(patterns) do
        if string.find(lower, string.lower(p), 1, true) then
            return true, p
        end
    end
    return false, nil
end

function Utils.getAttributes(obj)
    local attrs = {}
    if not Config.Options.StoreAttributes then return attrs end
    local ok, list = pcall(function() return obj:GetAttributes() end)
    if not ok or not list then return attrs end
    for _, name in ipairs(list) do
        local val = Utils.safe(function() return obj:GetAttribute(name) end)
        if val ~= nil then attrs[name] = tostring(val) end
    end
    return attrs
end

function Utils.getTags(obj)
    if not Config.Options.StoreTags then return nil end
    local ok, tags = pcall(function() return CollectionService:GetTags(obj) end)
    if ok and tags and #tags > 0 then return tags end
    return nil
end

function Utils.printSummary(tbl, title)
    title = title or "Summary"
    local keys = {}
    for k in pairs(tbl) do table.insert(keys, k) end
    table.sort(keys)
    print("╔══════════════════════════════════════╗")
    print("║  " .. title)
    print("╠══════════════════════════════════════╣")
    for _, k in ipairs(keys) do
        print(string.format("║  %-26s : %-12s ║", k, tostring(tbl[k])))
    end
    print("╚══════════════════════════════════════╝")
end

function Utils.waitBetweenWaves()
    if Config.Wave.DelayBetween > 0 then
        Utils.log(string.format("💤 พัก %d วิ...", Config.Wave.DelayBetween))
        task.wait(Config.Wave.DelayBetween)
    end
end

function Utils.isRemote(obj)
    if not obj then return false end
    local cls = obj.ClassName
    if cls == "RemoteEvent" or cls == "RemoteFunction"
       or cls == "UnreliableRemoteEvent"
       or cls == "BindableEvent" or cls == "BindableFunction" then
        return true
    end
    return false
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 8: STEALTH                       ║
-- ╚═══════════════════════════════════════════╝
local Stealth = {}

function Stealth.wrap(fn)
    if not caps.newcclosure then return fn end
    local ok, wrapped = pcall(rawGetGlobal("newcclosure"), fn)
    if ok and wrapped then return wrapped end
    return fn
end

function Stealth.quiet(fn, ...)
    local ok, r = pcall(fn, ...)
    if not ok then return nil end
    return r
end

function Stealth.delay(base)
    if not Config.Stealth.RandomizeDelay then
        task.wait(base or 0); return
    end
    local jitter = Config.Stealth.DelayMin
        + math.random() * (Config.Stealth.DelayMax - Config.Stealth.DelayMin)
    task.wait((base or 0) + jitter)
end

function Stealth.init()
    if not Config.Stealth.Enabled then return end
    Utils.log("🛡️  Safe Mode")
    if Config.Stealth.RandomStartDelay then
        local d = 0.3 + math.random() * 0.7
        Utils.log(string.format("รอเริ่ม %.2f วิ...", d))
        task.wait(d)
    end
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 9: EXTRACTOR                     ║
-- ╚═══════════════════════════════════════════╝
local Extractor = {}
Extractor.__index = Extractor

function Extractor.new(config)
    local self = setmetatable({}, Extractor)
    self.cfg = config
    self.count = 0
    self.aborted = false
    return self
end

function Extractor:reset()
    self.count = 0
    self.aborted = false
end

function Extractor:getProperties(obj)
    local cfg = self.cfg
    local props = { ClassName = obj.ClassName, Name = obj.Name }

    if cfg.Options.StoreFullPath then
        props._path = Stealth.quiet(function() return obj:GetFullName() end) or "?"
    end

    local attrs = Utils.getAttributes(obj)
    if next(attrs) then props._attributes = attrs end
    local tags = Utils.getTags(obj)
    if tags then props._tags = tags end

    if obj:IsA("BasePart") then
        props.Position = Utils.formatVector(obj.Position)
        props.PositionRaw = Utils.formatPosition(obj.Position)
        props.Size = Utils.formatVector(obj.Size)
        props.Color = Utils.formatColor(obj.Color)
        props.Material = tostring(obj.Material)
        props.Transparency = obj.Transparency
        props.CanCollide = obj.CanCollide
        props.CanTouch = obj.CanTouch
        props.Anchored = obj.Anchored
        props.Massless = obj.Massless
    end

    if obj:IsA("Model") then
        props.PrimaryPart = obj.PrimaryPart and obj.PrimaryPart.Name or nil
        props.ChildCount = #obj:GetChildren()
    end

    if obj:IsA("LuaSourceContainer") then
        props.Source = "[Not Accessible]"
    end

    if Utils.isRemote(obj) then
        props.RemoteType = obj.ClassName
    end

    if obj:IsA("ValueBase") then props.Value = tostring(obj.Value) end

    if obj:IsA("GuiObject") then
        props.Visible = obj.Visible
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            props.Text = Utils.truncate(obj.Text, 80)
        end
    end

    if obj:IsA("Sound") then
        props.SoundId = obj.SoundId
        props.Volume = obj.Volume
        props.Playing = obj.Playing
    end

    return props
end

function Extractor:dumpContainer(container)
    local cfg = self.cfg
    local result = {}
    local processed = 0
    local maxObj = cfg.Limits.MaxObjects
    local maxDepth = cfg.Limits.MaxDepth

    local function recurse(obj, depth)
        if depth > maxDepth then return end
        if self.count >= maxObj then self.aborted = true; return end

        for _, cls in ipairs(cfg.Filter.IgnoreClasses or {}) do
            if obj:IsA(cls) then
                for _, child in ipairs(obj:GetChildren()) do
                    recurse(child, depth)
                end
                return
            end
        end

        local props = self:getProperties(obj)
        props._depth = depth
        table.insert(result, props)
        self.count = self.count + 1

        processed = processed + 1
        if processed % Config.Stealth.ChunkSize == 0 then
            Stealth.delay(Config.Stealth.ChunkDelay)
        end

        for _, child in ipairs(obj:GetChildren()) do
            if self.count >= maxObj then self.aborted = true; return end
            recurse(child, depth + 1)
        end
    end

    for _, child in ipairs(container:GetChildren()) do
        if self.count >= maxObj then self.aborted = true; break end
        recurse(child, 1)
    end
    return result, self.count
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 10: SERIALIZER                   ║
-- ╚═══════════════════════════════════════════╝
local Serializer = {}
Serializer.__index = Serializer

function Serializer.new(config)
    local self = setmetatable({}, Serializer)
    self.cfg = config
    self.index = {}
    return self
end

function Serializer:encode(tbl)
    local json = Utils.safe(function()
        return HttpService:JSONEncode(tbl)
    end)
    if not json then
        Utils.warn("JSON encode failed")
        return nil
    end
    return json
end

function Serializer:ensureFolder()
    FileAPI.mkdirp(self.cfg.OutputFolder)
end

function Serializer:save(name, tbl)
    local cfg = self.cfg
    local json = self:encode(tbl)
    if not json then return false end
    self:ensureFolder()
    local fileName = string.format("%s/%s.json", cfg.OutputFolder, name)
    local ok, err = FileAPI.write(fileName, json)
    if ok then
        local kb = math.floor(#json / 1024)
        Utils.ok(string.format("%-28s → %d KB", name, kb))
        table.insert(self.index, {
            name = name, file = fileName, size_kb = kb,
            count = type(tbl) == "table" and #tbl or 0,
        })
        return true
    else
        Utils.warn("writefile " .. name .. ": " .. tostring(err))
        return false
    end
end

function Serializer:saveIndex()
    local cfg = self.cfg
    self:ensureFolder()
    local file = cfg.OutputFolder .. "/_INDEX.json"
    local json = self:encode({
        Version = Config.Version,
        Session = SESSION,
        GeneratedAt = os.date("%Y-%m-%d %H:%M:%S"),
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        Files = self.index,
    })
    if json then
        FileAPI.write(file, json)
        Utils.ok("Index: " .. file)
    end
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 11: COLLECTORS                   ║
-- ╚═══════════════════════════════════════════╝

local function collectInfo()
    local name = Utils.safe(function()
        return MarketplaceService:GetProductInfo(game.PlaceId).Name
    end) or "Unknown"
    local exec = "Unknown"
    if caps.identifyexecutor then
        exec = Utils.safe(rawGetGlobal("identifyexecutor")) or "Unknown"
    end
    return {
        GameName = name,
        PlaceId = game.PlaceId,
        JobId = game.JobId,
        DumpTime = os.date("%Y-%m-%d %H:%M:%S"),
        ScriptVersion = Config.Version,
        SessionName = Config.OutputFolder,
        Executor = exec,
        PlayerCount = #Players:GetPlayers(),
        MaxPlayers = Players.MaxPlayers,
        IsStudio = RunService:IsStudio(),
        Capabilities = caps,
    }
end

local function collectPlayers()
    local result = {}
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    for _, plr in ipairs(Players:GetPlayers()) do
        local entry = {
            Name = plr.Name,
            DisplayName = plr.DisplayName,
            UserId = plr.UserId,
            AccountAge = plr.AccountAge,
            Team = plr.Team and plr.Team.Name or nil,
        }
        if plr.TeamColor then
            entry.TeamColor = Utils.formatColor(plr.TeamColor)
        end
        local char = plr.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            entry.HasCharacter = true
            if hrp then
                entry.Position = Utils.formatVector(hrp.Position)
                entry.PositionRaw = Utils.formatPosition(hrp.Position)
                if myHRP and plr ~= LocalPlayer then
                    entry.DistanceFromMe = math.floor(
                        (hrp.Position - myHRP.Position).Magnitude)
                end
            end
            if hum then
                entry.Health = hum.Health
                entry.MaxHealth = hum.MaxHealth
                entry.WalkSpeed = hum.WalkSpeed
            end
        else
            entry.HasCharacter = false
        end
        table.insert(result, entry)
    end
    return result
end

local function collectPlayerCharDetail()
    local result = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        local char = plr.Character
        if char then
            local d = {
                Name = plr.Name,
                Parts = {}, Animations = {}, RemoteEvents = {},
            }
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then
                    table.insert(d.Parts, {
                        Name = obj.Name, Class = obj.ClassName,
                        Position = Utils.formatVector(obj.Position),
                        Size = Utils.formatVector(obj.Size),
                    })
                elseif obj:IsA("Animation") then
                    table.insert(d.Animations, {
                        Name = obj.Name, AnimationId = obj.AnimationId,
                    })
                elseif Utils.isRemote(obj) then
                    table.insert(d.RemoteEvents, {
                        Name = obj.Name,
                        Class = obj.ClassName,
                        Path = Stealth.quiet(function() return obj:GetFullName() end),
                    })
                end
            end
            result[plr.Name] = d
        end
    end
    return result
end

local function collectTerrainInfo()
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return { Exists = false } end
    return {
        Exists = true,
        WaterWaveSize = terrain.WaterWaveSize,
        WaterWaveSpeed = terrain.WaterWaveSpeed,
        WaterTransparency = terrain.WaterTransparency,
    }
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 12: SERVICE SCANNERS             ║
-- ╚═══════════════════════════════════════════╝

local function findKnitServices()
    local knit = ReplicatedStorage:FindFirstChild("Knit")
    if not knit then return nil end
    local kk = knit:FindFirstChild("Knit")
    if not kk then return nil end
    return kk:FindFirstChild("Services")
end

local function collectImportantServices()
    local services = findKnitServices()
    if not services then
        return { Error = "Knit.Services not found" }
    end
    local result = {}
    for _, svcName in ipairs(Config.SmartDump.ImportantServices) do
        local svc = services:FindFirstChild(svcName)
        if svc then
            local entry = { Name = svcName, Remotes = {} }
            for _, obj in ipairs(svc:GetDescendants()) do
                if Utils.isRemote(obj) then
                    table.insert(entry.Remotes, {
                        Name = obj.Name,
                        Class = obj.ClassName,
                        Path = Stealth.quiet(function() return obj:GetFullName() end),
                    })
                end
            end
            result[svcName] = entry
        end
    end
    return result
end

local function collectCharacterRemotes()
    local result = {}
    local chars = workspace:FindFirstChild("Characters")
    if not chars then return result end
    for _, char in ipairs(chars:GetChildren()) do
        if char:IsA("Model") then
            local remotes = {}
            for _, obj in ipairs(char:GetDescendants()) do
                if Utils.isRemote(obj) then
                    table.insert(remotes, {
                        Name = obj.Name,
                        Class = obj.ClassName,
                        Path = Stealth.quiet(function() return obj:GetFullName() end),
                    })
                end
            end
            if #remotes > 0 then
                result[char.Name] = remotes
            end
        end
    end
    return result
end

local function collectUnreliableRemotes()
    local result = {
        InReplicatedStorage = {},
        InWorkspace = {},
        Total = 0,
    }
    local seen = {}
    local function scan(container, key)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj.ClassName == "UnreliableRemoteEvent" and not seen[obj] then
                seen[obj] = true
                local path = Stealth.quiet(function() return obj:GetFullName() end)
                table.insert(result[key], { Name = obj.Name, Path = path })
                result.Total = result.Total + 1
            end
        end
    end
    scan(ReplicatedStorage, "InReplicatedStorage")
    scan(workspace, "InWorkspace")
    return result
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 13: SMART SCAN                   ║
-- ╚═══════════════════════════════════════════╝
local SmartScan = {}

function SmartScan.scan()
    local cfg = Config.SmartDump
    local found = {
        Collectibles = {}, Enemies = {}, Portals = {},
        Remotes = {}, Hitboxes = {}, Spawns = {},
        AntiCheatSuspects = {}, UnreliableRemotes = {},
    }

    Utils.log("🔍 สแกน Workspace...")
    local wsList = workspace:GetDescendants()
    local processed = 0

    for _, obj in ipairs(wsList) do
        processed = processed + 1
        if processed % Config.Stealth.ChunkSize == 0 then
            Stealth.delay(Config.Stealth.ChunkDelay)
        end

        if obj:IsA("BasePart") or obj:IsA("Model") then
            local pos, posRaw
            if obj:IsA("BasePart") then
                pos = Utils.formatVector(obj.Position)
                posRaw = Utils.formatPosition(obj.Position)
            end

            local ok, tag = Utils.matchPattern(obj.Name, cfg.CollectiblePatterns)
            if ok then
                table.insert(found.Collectibles, {
                    Name = obj.Name, Class = obj.ClassName,
                    Position = pos, PositionRaw = posRaw,
                    Path = Stealth.quiet(function() return obj:GetFullName() end),
                    Tag = tag,
                })
            end

            ok, tag = Utils.matchPattern(obj.Name, cfg.EnemyPatterns)
            if ok then
                table.insert(found.Enemies, {
                    Name = obj.Name, Class = obj.ClassName,
                    Position = pos, PositionRaw = posRaw,
                    Path = Stealth.quiet(function() return obj:GetFullName() end),
                    Tag = tag,
                })
            end

            ok, tag = Utils.matchPattern(obj.Name, cfg.PortalPatterns)
            if ok then
                table.insert(found.Portals, {
                    Name = obj.Name, Class = obj.ClassName,
                    Position = pos,
                    Path = Stealth.quiet(function() return obj:GetFullName() end),
                    Tag = tag,
                })
            end

            ok, tag = Utils.matchPattern(obj.Name, cfg.SpawnPatterns)
            if ok then
                table.insert(found.Spawns, {
                    Name = obj.Name, Position = pos,
                    Path = Stealth.quiet(function() return obj:GetFullName() end),
                    Tag = tag,
                })
            end

            if obj:IsA("BasePart")
               and obj.Transparency >= 0.5 and obj.CanTouch then
                ok, tag = Utils.matchPattern(obj.Name, cfg.HitboxPatterns)
                if ok then
                    table.insert(found.Hitboxes, {
                        Name = obj.Name, Position = pos,
                        Size = Utils.formatVector(obj.Size),
                        Transparency = obj.Transparency,
                        Path = Stealth.quiet(function() return obj:GetFullName() end),
                        Tag = tag,
                    })
                end
            end

            ok, tag = Utils.matchPattern(obj.Name, cfg.AntiCheatSigns)
            if ok then
                table.insert(found.AntiCheatSuspects, {
                    Name = obj.Name, Class = obj.ClassName,
                    Path = Stealth.quiet(function() return obj:GetFullName() end),
                    Sign = tag,
                })
            end
        end
    end

    Utils.log("🔍 สแกน ReplicatedStorage...")
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if Utils.isRemote(obj) then
            local ok, tag = Utils.matchPattern(obj.Name, cfg.RemotePatterns)
            table.insert(found.Remotes, {
                Name = obj.Name, Class = obj.ClassName,
                Path = Stealth.quiet(function() return obj:GetFullName() end),
                Tag = tag or "none", Interested = ok,
            })
            if obj.ClassName == "UnreliableRemoteEvent" then
                table.insert(found.UnreliableRemotes, {
                    Name = obj.Name,
                    Path = Stealth.quiet(function() return obj:GetFullName() end),
                })
            end
        end
    end

    return found
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 14: TARGETED HOOK (V3.7 FIXED)   ║
-- ╚═══════════════════════════════════════════╝
local TargetedHook = {
    Log = {},
    ClientLog = {},
    HookedServer = {},      -- [remote] = {oldFn, newFn, name}
    HookedClient = {},
    Running = false,
    DedupeCache = {},
}

function TargetedHook:isTargeted(obj)
    if not Utils.isRemote(obj) then return false end

    local fullPath = Stealth.quiet(function() return obj:GetFullName() end) or ""

    for _, black in ipairs(Config.TargetedHook.BlacklistRemotes) do
        if string.find(fullPath, black, 1, true) then
            return false
        end
    end

    for _, white in ipairs(Config.TargetedHook.WhitelistRemotes) do
        if string.find(fullPath, white, 1, true) then
            return true
        end
    end

    return false
end

function TargetedHook:shouldLog(remote, argsKey)
    local key = remote .. "|" .. argsKey
    local now = tick()
    local last = self.DedupeCache[key]
    if last and (now - last) < Config.TargetedHook.DedupeWindow then
        return false
    end
    self.DedupeCache[key] = now
    return true
end

local function argsToKey(args)
    local parts = {}
    for i, v in ipairs(args) do
        local vt = typeof(v)
        if vt == "Instance" then
            parts[i] = "I:" .. (Stealth.quiet(function() return v:GetFullName() end) or "?")
        elseif vt == "Vector3" then
            parts[i] = string.format("V:%.0f,%.0f,%.0f", v.X, v.Y, v.Z)
        elseif vt == "number" then
            parts[i] = "N:" .. tostring(v)
        elseif vt == "string" then
            parts[i] = "S:" .. v
        else
            parts[i] = vt
        end
    end
    return table.concat(parts, "|")
end

local function serializeArgs(args)
    local info = {}
    for i, v in ipairs(args) do
        local vt = typeof(v)
        if vt == "Instance" then
            info[i] = {
                type = "Instance",
                class = v.ClassName,
                name = v.Name,
                path = Stealth.quiet(function() return v:GetFullName() end),
            }
        elseif vt == "Vector3" then
            info[i] = { type = "Vector3", value = Utils.formatVector(v) }
        else
            info[i] = {
                type = vt,
                value = Utils.truncate(tostring(v), 150),
            }
        end
    end
    return info
end

-- ★★★ Hook Server-side ★★★
function TargetedHook:attachServer(remote)
    if self.HookedServer[remote] then return false end
    if not caps.hookfunction then return false end

    local hookfunction = rawGetGlobal("hookfunction")
    local ok, oldFn = pcall(function() return remote.FireServer end)
    if not ok or type(oldFn) ~= "function" then return false end

    local name = Stealth.quiet(function() return remote:GetFullName() end) or remote.Name
    local cls = remote.ClassName

    local newFn = Stealth.wrap(function(self2, ...)
        local args = {...}
        local key = argsToKey(args)
        if TargetedHook:shouldLog(name, key) then
            table.insert(TargetedHook.Log, {
                Remote = name,
                RemoteShort = remote.Name,
                RemoteClass = cls,
                Direction = "FireServer",
                Args = serializeArgs(args),
                Time = os.date("%H:%M:%S"),
                Tick = tick(),
            })
            if #TargetedHook.Log > Config.Limits.HookLog then
                table.remove(TargetedHook.Log, 1)
            end
        end
        return oldFn(self2, ...)
    end)

    -- ★★★ Hook สำเร็จ → เก็บ oldFn + newFn ★★★
    local ok2 = pcall(hookfunction, oldFn, newFn)
    if not ok2 then
        Utils.warn("hookfunction fail: " .. name)
        return false
    end

    self.HookedServer[remote] = {
        oldFn = oldFn,
        newFn = newFn,
        name = name,
    }
    return true
end

-- ★★★ Hook Client-side ★★★
function TargetedHook:attachClient(remote)
    if self.HookedClient[remote] then return false end
    if not caps.hookfunction then return false end
    if not (remote:IsA("RemoteEvent") or remote.ClassName == "UnreliableRemoteEvent") then
        return false
    end

    local getconnections = rawGetGlobal("getconnections")
    if type(getconnections) ~= "function" then return false end

    local ok, conns = pcall(getconnections, remote.OnClientEvent)
    if not ok or type(conns) ~= "table" then return false end

    local name = Stealth.quiet(function() return remote:GetFullName() end) or remote.Name
    local cls = remote.ClassName

    -- ★★★ V3.7: Client-side hook ใช้ getconnections → ไม่ต้อง restore
    -- เพราะเราไม่แตะ metatable แค่ห่อ connection

    -- Note: V3.7 จะ log แค่ — ไม่ hook เพราะ getconnections ไม่ต้อง unhook
    self.HookedClient[remote] = name

    -- Log connection info
    table.insert(self.ClientLog, {
        Remote = name,
        RemoteShort = remote.Name,
        RemoteClass = cls,
        Direction = "OnClientEvent",
        Args = { {
            type = "info",
            value = "connected listeners: " .. #conns,
        } },
        Time = os.date("%H:%M:%S"),
        Tick = tick(),
    })

    return true
end

function TargetedHook:start()
    if self.Running then return end
    self.Running = true

    Utils.log("🎯 TargetedHook: ค้นหา remote (whitelist mode)...")

    local serverCount = 0
    local clientCount = 0

    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if self:isTargeted(obj) then
            if self:attachServer(obj) then serverCount = serverCount + 1 end
            if Config.TargetedHook.HookClientEvent then
                if self:attachClient(obj) then clientCount = clientCount + 1 end
            end
        end
    end

    Utils.ok(string.format("🎯 Hook Server=%d, Client=%d", serverCount, clientCount))

    local dur = Config.TargetedHook.RunDuration
    Utils.log("⏳ เก็บ args " .. dur .. " วิ...")
    local t0 = tick()
    while tick() - t0 < dur and scriptAlive do
        task.wait(1)
    end

    Utils.ok(string.format("🎯 เสร็จ — FireServer: %d, ClientEvent: %d",
        #self.Log, #self.ClientLog))
end

-- ★★★ V3.7: UNHOOK แบบ swap oldFn ← newFn ★★★
function TargetedHook:stop()
    if not caps.hookfunction then return end
    local hookfunction = rawGetGlobal("hookfunction")
    local restorefunction = rawGetGlobal("restorefunction")

    local restored, failed = 0, 0

    for remote, data in pairs(self.HookedServer) do
        local ok = false

        -- วิธี 1: swap ผ่าน hookfunction
        if data.newFn and data.oldFn then
            ok = pcall(hookfunction, data.newFn, data.oldFn)
        end

        -- วิธี 2: fallback restorefunction
        if not ok and restorefunction and data.oldFn then
            ok = pcall(restorefunction, data.oldFn)
        end

        if ok then restored = restored + 1
        else failed = failed + 1 end
    end

    self.HookedServer = {}
    self.HookedClient = {}
    self.Running = false

    Utils.ok(string.format("🔓 Unhook: restore=%d, fail=%d", restored, failed))
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 15: HITBOX WATCHER (V3.7 FIXED)  ║
-- ╚═══════════════════════════════════════════╝
local HitboxWatcher = {
    Events = {},
    Seen = {},
    Running = false,
    Destroyed = false,           -- ★★★ flag หยุดจริง
    Count = 0,
    Skipped = 0,
    ChildAddedConns = {},
}

local function getOwnerOfPart(part)
    local ancestor = part.Parent
    for _ = 1, 6 do
        if not ancestor then break end
        if ancestor:IsA("Model") then
            local plr = Players:GetPlayerFromCharacter(ancestor)
            if plr then return plr.Name end
            if ancestor:FindFirstChildOfClass("Humanoid") then
                return ancestor.Name
            end
        end
        ancestor = ancestor.Parent
    end
    return nil
end

function HitboxWatcher:isHitbox(obj)
    if not obj:IsA("BasePart") then return false end

    local cfg = Config.HitboxWatcher
    local hasReq = Utils.matchPattern(obj.Name, cfg.RequireNames)
    if not hasReq then return false end

    if cfg.IgnoreSelfOwner then
        local owner = getOwnerOfPart(obj)
        if owner == LocalPlayer.Name then return false end
    end

    return true
end

function HitboxWatcher:record(obj)
    if self.Destroyed then return end           -- ★★★ ออกทันที
    if self.Seen[obj] then return end

    local isHb = self:isHitbox(obj)
    if not isHb then
        self.Skipped = self.Skipped + 1
        return
    end

    self.Seen[obj] = true
    self.Count = self.Count + 1

    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")

    local spawnTime = tick()
    local owner = getOwnerOfPart(obj)
    local distance = nil
    if myHRP then
        local ok, d = pcall(function()
            return math.floor((obj.Position - myHRP.Position).Magnitude)
        end)
        if ok then distance = d end
    end

    local event = {
        Name = obj.Name,
        Class = obj.ClassName,
        Owner = owner,
        Position = Utils.formatVector(obj.Position),
        Size = Utils.formatVector(obj.Size),
        Transparency = obj.Transparency,
        DistanceFromMe = distance,
        SpawnTime = spawnTime,
        SpawnTimeStr = os.date("%H:%M:%S") ..
            string.format(".%03d", math.floor((spawnTime % 1) * 1000)),
        Path = Stealth.quiet(function() return obj:GetFullName() end),
    }
    table.insert(self.Events, event)

    if #self.Events > Config.Limits.HitboxLog then
        table.remove(self.Events, 1)
    end
end

function HitboxWatcher:setupChildAdded()
    if not Config.HitboxWatcher.UseChildAdded then return end

    -- ★★★ V3.7: เฉพาะ ScanTargets (Effects) ★★★
    for _, targetName in ipairs(Config.HitboxWatcher.ScanTargets) do
        local target = workspace:FindFirstChild(targetName)
        if target then
            local conn = target.DescendantAdded:Connect(function(obj)
                if self.Destroyed then return end        -- ★★★
                if not self.Running then return end
                if obj:IsA("BasePart") then
                    task.spawn(function()
                        pcall(function() self:record(obj) end)
                    end)
                end
            end)
            table.insert(self.ChildAddedConns, conn)
            Utils.log("📊 ChildAdded: " .. targetName)
        end
    end
end

function HitboxWatcher:scanOnce()
    -- ★★★ V3.7: scan เฉพาะ Effects (ไม่ scan ทั้ง workspace) ★★★
    if self.Destroyed then return end
    if not self.Running then return end

    local ok, err = pcall(function()
        for _, targetName in ipairs(Config.HitboxWatcher.ScanTargets) do
            local target = workspace:FindFirstChild(targetName)
            if target then
                for _, obj in ipairs(target:GetDescendants()) do
                    if self.Destroyed then return end
                    if obj:IsA("BasePart") and not self.Seen[obj] then
                        self:record(obj)
                    end
                end
            end
        end
    end)
    if not ok and not Config.Stealth.SuppressErrors then
        Utils.warn("HitboxWatcher: " .. tostring(err))
    end
end

function HitboxWatcher:start()
    if self.Running then return end
    self.Running = true
    self.Destroyed = false

    Utils.log("📊 HitboxWatcher v3.7: เริ่ม")
    Utils.log("   - Poll: " .. (Config.HitboxWatcher.PollRate * 1000) .. "ms")
    Utils.log("   - Targets: " .. table.concat(Config.HitboxWatcher.ScanTargets, ", "))

    self:setupChildAdded()
    self:scanOnce()

    local dur = Config.HitboxWatcher.RunDuration
    local t0 = tick()
    local nextTick = t0

    -- ★★★ V3.7: loop with Destroyed check ★★★
    while tick() - t0 < dur 
          and scriptAlive 
          and not self.Destroyed 
    do
        if self.Running then
            self:scanOnce()
        end
        nextTick = nextTick + Config.HitboxWatcher.PollRate
        local wait = nextTick - tick()
        if wait > 0 then task.wait(wait) else task.wait() end
    end

    Utils.ok("📊 HitboxWatcher: " .. self.Count .. " events (skip " ..
        self.Skipped .. ")")
end

function HitboxWatcher:stop()
    self.Running = false
    self.Destroyed = true                       -- ★★★ สำคัญ!
    for _, conn in ipairs(self.ChildAddedConns) do
        pcall(function() conn:Disconnect() end)
    end
    self.ChildAddedConns = {}
    Utils.ok("📊 HitboxWatcher: หยุด")
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 16: ANALYZER                     ║
-- ╚═══════════════════════════════════════════╝
local Analyzer = {}

function Analyzer.analyze(dump, extra)
    extra = extra or {}
    local report = {
        Summary = {}, Hints = {},
        TimingAnalysis = {}, TopHookedRemotes = {},
    }

    report.Summary.Collectibles = #(dump.Collectibles or {})
    report.Summary.Enemies = #(dump.Enemies or {})
    report.Summary.Portals = #(dump.Portals or {})
    report.Summary.Remotes = #(dump.Remotes or {})
    report.Summary.Hitboxes = #(dump.Hitboxes or {})
    report.Summary.Spawns = #(dump.Spawns or {})
    report.Summary.AntiCheat = #(dump.AntiCheatSuspects or {})
    report.Summary.UnreliableRemotes = #(dump.UnreliableRemotes or {})
    report.Summary.HookFireServer = #(extra.HookLog or {})
    report.Summary.HookClientEvent = #(extra.ClientLog or {})
    report.Summary.HitboxEvents = #(extra.HitboxEvents or {})

    if report.Summary.UnreliableRemotes > 0 then
        table.insert(report.Hints,
            "⭐ Unreliable: " .. report.Summary.UnreliableRemotes)
    end
    if report.Summary.HookClientEvent > 0 then
        table.insert(report.Hints,
            "⭐ Hook ClientEvent: " .. report.Summary.HookClientEvent)
    end
    if report.Summary.HitboxEvents > 0 then
        table.insert(report.Hints,
            "⭐ Hitbox Events: " .. report.Summary.HitboxEvents)
    end

    return report
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 17: MAIN                         ║
-- ╚═══════════════════════════════════════════╝

local startTime = tick()

Utils.log("═══════════════════════════════════════")
Utils.log("Dump Framework V" .. Config.Version .. " | V3.7")
Utils.log("═══════════════════════════════════════")
Utils.log("📁 Session: " .. Config.OutputFolder)
Utils.log(string.format("Hook: %s | Restore: %s | List: %s",
    tostring(caps.hookfunction),
    tostring(caps.restorefunction),
    tostring(FileAPI.canList())))

if Config.AutoCleanupOldSessions then
    pcall(Cleaner.cleanup)
end

Stealth.init()

local extractor = Extractor.new(Config)
local serializer = Serializer.new(Config)
local summary = {}

-- ╔═══ WAVE 1 ═══╗
Utils.log("═══ WAVE 1: ข้อมูลเบา ═══")

if Config.Targets.Info then
    serializer:save("01_info", collectInfo())
    summary["Info"] = "OK"
end

if Config.Targets.Players then
    local ok, players = pcall(collectPlayers)
    if ok then
        serializer:save("02_players", players)
        summary["Players"] = #players
    else summary["Players"] = "ERR" end
end

if Config.Targets.PlayersCharacter then
    local ok, d = pcall(collectPlayerCharDetail)
    if ok then
        serializer:save("03_players_character", d)
        summary["PlayersCharacter"] = "OK"
    else summary["PlayersCharacter"] = "ERR" end
end

if Config.Targets.Lighting then
    extractor:reset()
    local ok, liData, liCount = pcall(function()
        local d, c = extractor:dumpContainer(Lighting)
        return d, c
    end)
    if ok then
        serializer:save("07_lighting", liData)
        summary["Lighting"] = liCount
    end
end

if Config.Targets.SoundService then
    extractor:reset()
    local ok, sounds = pcall(function()
        return extractor:dumpContainer(SoundService)
    end)
    if ok then
        serializer:save("08_sounds", sounds)
        summary["Sounds"] = #sounds
    end
end

if Config.Targets.StarterGui then
    extractor:reset()
    local ok, guiData = pcall(function()
        return extractor:dumpContainer(StarterGui)
    end)
    if ok then
        serializer:save("09_startergui", guiData)
        summary["StarterGui"] = #guiData
    end
end

if Config.Targets.TerrainInfo then
    local ok, t = pcall(collectTerrainInfo)
    if ok then
        serializer:save("10_terrain", t)
        summary["Terrain"] = t.Exists and "OK" or "None"
    end
end

Utils.waitBetweenWaves()

-- ╔═══ WAVE 2 ═══╗
if Config.Targets.Workspace then
    Utils.log("═══ WAVE 2: Workspace ═══")
    extractor:reset()
    local ok, wsData, wsCount = pcall(function()
        local d, c = extractor:dumpContainer(workspace)
        return d, c
    end)
    if ok then
        serializer:save("04_workspace", wsData)
        summary["Workspace"] = wsCount
    else summary["Workspace"] = "ERR" end
    Utils.waitBetweenWaves()
end

-- ╔═══ WAVE 3 ═══╗
if Config.Targets.ReplicatedStorage then
    Utils.log("═══ WAVE 3: ReplicatedStorage ═══")
    extractor:reset()
    local ok, rsData, rsCount = pcall(function()
        local d, c = extractor:dumpContainer(ReplicatedStorage)
        return d, c
    end)
    if ok then
        serializer:save("06_replicatedstorage", rsData)
        summary["ReplicatedStorage"] = rsCount
    else summary["ReplicatedStorage"] = "ERR" end
end

if Config.Targets.SmartScan then
    Utils.log("═══ WAVE 3: SmartScan ═══")
    local ok, sData = pcall(SmartScan.scan)
    if ok then
        serializer:save("11_smart_collectibles", sData.Collectibles)
        serializer:save("12_smart_enemies", sData.Enemies)
        serializer:save("13_smart_portals", sData.Portals)
        serializer:save("14_smart_remotes", sData.Remotes)
        serializer:save("15_smart_hitboxes", sData.Hitboxes)
        serializer:save("16_smart_spawns", sData.Spawns)
        serializer:save("17_smart_anticheat", sData.AntiCheatSuspects)
        serializer:save("18_smart_unreliable", sData.UnreliableRemotes)
        summary["Collectibles"] = #sData.Collectibles
        summary["Enemies"] = #sData.Enemies
        summary["Remotes"] = #sData.Remotes
        summary["Hitboxes"] = #sData.Hitboxes
        summary["Unreliable"] = #sData.UnreliableRemotes
        _G.__BoomxicoSmartData = sData
    else summary["SmartScan"] = "ERR" end
end

if Config.Targets.BlockServiceScan then
    local ok, svcData = pcall(collectImportantServices)
    if ok then
        serializer:save("24_important_services", svcData)
        summary["Services"] = "OK"
    end
end

if Config.Targets.CharacterRemotes then
    local ok, cr = pcall(collectCharacterRemotes)
    if ok then
        serializer:save("25_character_remotes", cr)
        local count = 0
        for _ in pairs(cr) do count = count + 1 end
        summary["CharRemotes"] = count
    end
end

if Config.Targets.UnreliableScan then
    local ok, ur = pcall(collectUnreliableRemotes)
    if ok then
        serializer:save("26_unreliable_remotes", ur)
        summary["UnreliableTotal"] = ur.Total
    end
end

Utils.waitBetweenWaves()

-- ╔═══ WAVE 4 ═══╗
Utils.log("═══ WAVE 4: Live Capture (V3.7 Fixed) ═══")

-- ★★★ Run Hook + Hitbox (parallel) ★★★
local hookThread = nil
local hitboxThread = nil

if Config.Targets.TargetedHook then
    hookThread = task.spawn(function()
        pcall(function() TargetedHook:start() end)
        pcall(function()
            serializer:save("27_targeted_hook_server", TargetedHook.Log)
            serializer:save("28_targeted_hook_client", TargetedHook.ClientLog)
        end)
        summary["HookServer"] = #TargetedHook.Log
        summary["HookClient"] = #TargetedHook.ClientLog

        -- ★★★ UNHOOK หลังเสร็จ ★★★
        pcall(function() TargetedHook:stop() end)
    end)
end

if Config.Targets.HitboxWatcher then
    hitboxThread = task.spawn(function()
        pcall(function() HitboxWatcher:start() end)
        pcall(function()
            serializer:save("29_hitbox_realtime", HitboxWatcher.Events)
        end)
        summary["HitboxEvents"] = #HitboxWatcher.Events
        pcall(function() HitboxWatcher:stop() end)
    end)
end

-- รอ thread ทั้งคู่ (loop + destroy check)
while (TargetedHook.Running or HitboxWatcher.Running) 
      and scriptAlive 
do
    task.wait(1)
end

Utils.ok("Wave 4 เสร็จ — Hook + Hitbox ปิดหมดแล้ว")

-- ╔═══ WAVE 5 ═══╗
if Config.Targets.Analysis and _G.__BoomxicoSmartData then
    Utils.log("═══ WAVE 5: Analyze ═══")
    local ok, report = pcall(function()
        return Analyzer.analyze(_G.__BoomxicoSmartData, {
            HookLog = TargetedHook.Log,
            ClientLog = TargetedHook.ClientLog,
            HitboxEvents = HitboxWatcher.Events,
        })
    end)
    if ok then
        for _, h in ipairs(report.Hints) do Utils.hint(h) end
        serializer:save("30_analysis_report", report)
        summary["Analysis"] = "OK"
    end
end

serializer:saveIndex()

-- Cleanup
_G.__BoomxicoSmartData = nil
scriptAlive = false

-- ═══════════════════════════════════════════
-- สรุป
-- ═══════════════════════════════════════════
local elapsed = tick() - startTime
summary["Total Time (s)"] = string.format("%.2f", elapsed)
summary["Total Objects"] = extractor.count

Utils.printSummary(summary, "Dump V3.7 Complete")

Utils.log("═══════════════════════════════════════")
Utils.log("📂 Session: " .. Config.OutputFolder)
Utils.log("📄 ดู " .. Config.OutputFolder .. "/_INDEX.json")
Utils.log("═══════════════════════════════════════")
