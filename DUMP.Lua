-- ╔═══════════════════════════════════════════════════════════════╗
-- ║  Dump Framework V3.5 | UNRELIABLE EDITION                     ║
-- ║  By Boomxico | Delta Executor                                 ║
-- ║  Fixed: UnreliableRemoteEvent | SmartHitbox | Filter          ║
-- ╚═══════════════════════════════════════════════════════════════╝

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 1: SESSION INFO                  ║
-- ╚═══════════════════════════════════════════╝
local SESSION = {
    Version = "3.5.0",
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
    SessionNameFormat = "V35_%s_%s",
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
        UnreliableScan    = true,   -- ★ ใหม่
        TargetedHook      = true,
        HitboxWatcher     = true,
        Analysis          = true,
        RemoteSniffer     = false,
        HitboxTracker     = false,
    },

    Limits = {
        MaxDepth     = 5,
        MaxObjects   = 40000,
        MaxStringLen = 250,
        MaxGuiDepth  = 4,
        HookLog      = 2000,
        HitboxLog    = 3000,       -- ★ เพิ่มเพราะเก็บเยอะขึ้น
    },

    Filter = {
        OnlyBaseParts    = false,
        OnlyScripts      = false,
        OnlyModels       = false,
        OnlyNameMatch    = {},
        IgnoreInvisible  = false,
        IgnoreUnanchored = false,
        MinSize          = 0,
        IgnoreClasses    = { "Decal", "Texture" },
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

    -- ★★ TargetedHook ปรับใหม่ ★★
    TargetedHook = {
        Patterns = {
            "Hitbox", "Activated", "Deactivated",
            "Block", "Parry", "M1", "M2",
            "Attack", "Combat", "Melee",
            "LOOK", "Chase", "Ultimate", "Effects",
            "Slash", "Hit", "Damage",
        },
        RunDuration = 30,
        HookClientEvent = true,
        -- ★ Hook ทุก type ที่เป็น remote
        RemoteClasses = {
            "RemoteEvent",
            "RemoteFunction",
            "UnreliableRemoteEvent",  -- ★ ใหม่!
            "BindableEvent",
            "BindableFunction",
        },
    },

    -- ★★ HitboxWatcher ปรับใหม่ ★★
    HitboxWatcher = {
        RunDuration = 30,
        PollRate    = 0.03,
        MinTransparency = 0.5,
        WatchOnlyCharacters = false,
        AlsoCheckCanCollideFalse = true,
        AlsoCheckMassless = true,
        -- ★★ ตัด body part ของตัวเอง ★★
        IgnoreNames = {
            -- body part
            "Head", "Torso", "Left Arm", "Right Arm",
            "Left Leg", "Right Leg", "UpperTorso", "LowerTorso",
            "LeftHand", "RightHand", "LeftFoot", "RightFoot",
            "LeftUpperArm", "RightUpperArm",
            "LeftLowerArm", "RightLowerArm",
            "LeftUpperLeg", "RightUpperLeg",
            "LeftLowerLeg", "RightLowerLeg",
            "HumanoidRootPart", "Collide", "RootJoint",
            "Handle", "Block", "BlockEffect",
        },
        -- ★★ ต้องมีคำเหล่านี้เท่านั้น ★★
        RequirePatterns = {
            "Hitbox", "HitGlow", "SlashHit", "ChaseHit",
            "HardHit", "RoughHit", "GrabCollision",
            "CombatTrail", "CounterSwing", "Strike",
        },
        -- ★★ ตัด owner = ตัวเอง ★★
        IgnoreSelfOwner = true,
        -- ★★ duration ต้อง ≤ 2 วิ ★★
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
            "Slime","Titan","Wyvern",
        },
        PortalPatterns = {
            "Portal","Door","Gate","Entrance","Teleport","Exit","Warp",
        },
        RemotePatterns = {
            "Attack","Parry","Block","Hit","Damage","Combat","Use",
            "Skill","Ability","Cast","Punch","Slash","Farm","Collect",
            "Claim","Equip","Buy","Sell","Trade",
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
            "CombatService",
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
    getrawmetatable   = type(rawGetGlobal("getrawmetatable")) == "function",
    setreadonly       = type(rawGetGlobal("setreadonly")) == "function",
    getgenv           = type(rawGetGlobal("getgenv")) == "function",
    gethui            = type(rawGetGlobal("gethui")) == "function",
    identifyexecutor  = type(rawGetGlobal("identifyexecutor")) == "function",
    setclipboard      = type(rawGetGlobal("setclipboard")) == "function"
                        or type(rawGetGlobal("toclipboard")) == "function",
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
local _clipboardFn  = findFn({"setclipboard","toclipboard"})

local MEMORY_STORE = {}
local USE_MEMORY_FALLBACK = (_writeFn == nil)

_G.BoomxicoDumpStore = MEMORY_STORE

function FileAPI.hasWriteSupport() return _writeFn ~= nil end
function FileAPI.hasClipboard()    return _clipboardFn ~= nil end
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
    local ok = pcall(_makeFolderFn, path)
    return ok
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

function FileAPI.copyToClipboard(text)
    if not _clipboardFn then return false end
    return pcall(_clipboardFn, text)
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
    local logLines = { "=== CLEANUP LOG ===",
        "Time: " .. os.date("%Y-%m-%d %H:%M:%S"),
        string.format("Total: %d, Delete: %d", #sessions, #toDelete) }
    for _, s in ipairs(toDelete) do
        local ok = FileAPI.deleteFolder(s.path)
        table.insert(logLines, string.format("  [%s] %s", ok and "DEL" or "FAIL", s.name))
    end
    FileAPI.mkdir(Config.BaseFolder)
    FileAPI.append(Config.BaseFolder .. "/_cleanup_log.txt",
        table.concat(logLines, "\n") .. "\n\n")
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
    if type(c) == "table" and c.R and c.G and c.B then
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

function Utils.matchAny(name, patterns)
    if not name then return false, nil end
    for _, p in ipairs(patterns) do
        if name == p then return true, p end
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

-- ★★★ ตรวจ remote ทุก type ★★★
function Utils.isRemote(obj)
    if not obj then return false end
    local cls = obj.ClassName
    if cls == "RemoteEvent" or cls == "RemoteFunction"
       or cls == "UnreliableRemoteEvent"  -- ★ ใหม่!
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
    Utils.log("🛡️  Safe Mode (ไม่แตะ game metatable)")
    if Config.Stealth.RandomStartDelay then
        local d = 0.3 + math.random() * 0.7
        Utils.log(string.format("รอเริ่ม %.2f วิ...", d))
        task.wait(d)
    end
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 9: FILTER                        ║
-- ╚═══════════════════════════════════════════╝
local Filter = {}
Filter.__index = Filter

function Filter.new(cfg)
    return setmetatable({ cfg = cfg }, Filter)
end

function Filter:shouldKeep(obj)
    local cfg = self.cfg
    for _, cls in ipairs(cfg.IgnoreClasses or {}) do
        if obj:IsA(cls) then return false end
    end
    if obj:IsA("BasePart") then
        if cfg.IgnoreInvisible and obj.Transparency >= 1 then return false end
        if cfg.IgnoreUnanchored and not obj.Anchored then return false end
    end
    return true
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 10: EXTRACTOR                    ║
-- ╚═══════════════════════════════════════════╝
local Extractor = {}
Extractor.__index = Extractor

function Extractor.new(config)
    local self = setmetatable({}, Extractor)
    self.cfg = config
    self.filter = Filter.new(config.Filter)
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
        if obj:IsA("MeshPart") then props.MeshId = obj.MeshId end
    end

    if obj:IsA("Model") then
        props.PrimaryPart = obj.PrimaryPart and obj.PrimaryPart.Name or nil
        props.ChildCount = #obj:GetChildren()
    end

    if obj:IsA("LuaSourceContainer") then
        props.Source = "[Not Accessible]"
    end

    if Utils.isRemote(obj) then
        props.RemoteType = obj.ClassName  -- ★ ใช้ ClassName จริง
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

        local props = self:getProperties(obj)
        if self.filter:shouldKeep(obj) then
            props._depth = depth
            table.insert(result, props)
            self.count = self.count + 1
        end

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
-- ║  SECTION 11: SERIALIZER                   ║
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
        SafeMode = true,
        Files = self.index,
    })
    if json then
        FileAPI.write(file, json)
        Utils.ok("Index: " .. file)
    end
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 12: COLLECTORS พื้นฐาน           ║
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
        WriteSupport = FileAPI.hasWriteSupport(),
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
                entry.RigType = tostring(hum.RigType)
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
                Parts = {}, Tools = {}, Animations = {},
                HumanoidInfo = {},
                RemoteEvents = {},
            }
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then
                    table.insert(d.Parts, {
                        Name = obj.Name, Class = obj.ClassName,
                        Position = Utils.formatVector(obj.Position),
                        Size = Utils.formatVector(obj.Size),
                        Transparency = obj.Transparency,
                    })
                elseif obj:IsA("Tool") then
                    table.insert(d.Tools, { Name = obj.Name })
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
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                d.HumanoidInfo = {
                    Health = hum.Health, MaxHealth = hum.MaxHealth,
                    WalkSpeed = hum.WalkSpeed, JumpPower = hum.JumpPower,
                    RigType = tostring(hum.RigType),
                }
            end
            result[plr.Name] = d
        end
    end
    return result
end

local function collectTerrainInfo()
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return { Exists = false } end
    local ok, info = pcall(function()
        return {
            Exists = true,
            WaterWaveSize = terrain.WaterWaveSize,
            WaterWaveSpeed = terrain.WaterWaveSpeed,
            WaterTransparency = terrain.WaterTransparency,
        }
    end)
    if ok then return info end
    return { Exists = true }
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 13: SERVICE SCANNERS             ║
-- ╚═══════════════════════════════════════════╝

local function findKnitServices()
    local knit = ReplicatedStorage:FindFirstChild("Knit")
    if not knit then return nil end
    local kk = knit:FindFirstChild("Knit")
    if not kk then return nil end
    return kk:FindFirstChild("Services")
end

-- ★★★ Service Scanner — เก็บทุก remote type ★★★
local function collectImportantServices()
    local services = findKnitServices()
    if not services then
        return { Error = "Knit.Services not found" }
    end

    local result = {}
    for _, svcName in ipairs(Config.SmartDump.ImportantServices) do
        local svc = services:FindFirstChild(svcName)
        if svc then
            local entry = { Name = svcName, Remotes = {}, Others = {} }
            for _, obj in ipairs(svc:GetDescendants()) do
                if Utils.isRemote(obj) then  -- ★ ใช้ isRemote
                    table.insert(entry.Remotes, {
                        Name = obj.Name,
                        Class = obj.ClassName,   -- ★ เก็บ class จริง
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
                if Utils.isRemote(obj) then  -- ★
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

-- ★★★ Unreliable Remote Scanner — ใหม่! ★★★
local function collectUnreliableRemotes()
    local result = {
        InReplicatedStorage = {},
        InWorkspace = {},
        InOther = {},
        Total = 0,
    }

    local function scan(container, key)
        for _, obj in ipairs(container:GetDescendants()) do
            if obj.ClassName == "UnreliableRemoteEvent" then
                table.insert(result[key], {
                    Name = obj.Name,
                    Path = Stealth.quiet(function() return obj:GetFullName() end),
                })
                result.Total = result.Total + 1
            end
        end
    end

    scan(ReplicatedStorage, "InReplicatedStorage")
    scan(workspace, "InWorkspace")

    -- Scan services ทั้งหมด (Knit)
    local services = findKnitServices()
    if services then
        for _, obj in ipairs(services:GetDescendants()) do
            if obj.ClassName == "UnreliableRemoteEvent" then
                local path = Stealth.quiet(function() return obj:GetFullName() end)
                if path and not path:find("ReplicatedStorage") then
                    table.insert(result.InOther, {
                        Name = obj.Name, Path = path,
                    })
                    result.Total = result.Total + 1
                end
            end
        end
    end

    return result
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 14: SMART SCAN                   ║
-- ╚═══════════════════════════════════════════╝
local SmartScan = {}

function SmartScan.scan()
    local cfg = Config.SmartDump
    local found = {
        Collectibles = {}, Enemies = {}, Portals = {},
        Remotes = {}, Hitboxes = {}, Spawns = {},
        AntiCheatSuspects = {},
        UnreliableRemotes = {},   -- ★ แยกเก็บ
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
                        CanCollide = obj.CanCollide,
                        Massless = obj.Massless,
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
        if Utils.isRemote(obj) then  -- ★ ใช้ isRemote เก็บทุก type
            local ok, tag = Utils.matchPattern(obj.Name, cfg.RemotePatterns)
            table.insert(found.Remotes, {
                Name = obj.Name, Class = obj.ClassName,
                Path = Stealth.quiet(function() return obj:GetFullName() end),
                Tag = tag or "none", Interested = ok,
            })

            -- ★ แยก Unreliable
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
-- ║  SECTION 15: TARGETED HOOK                ║
-- ╚═══════════════════════════════════════════╝
local TargetedHook = {
    Log = {},
    ClientLog = {},
    Hooked = {},
    HookedClient = {},
    Running = false,
    Count = 0,
}

function TargetedHook:isTargeted(obj)
    if not Utils.isRemote(obj) then return false end  -- ★ ทุก type
    local ok, tag = Utils.matchPattern(obj.Name, Config.TargetedHook.Patterns)
    return ok, tag
end

function TargetedHook:attach(remote)
    if self.Hooked[remote] then return false end
    if not caps.hookfunction then return false end

    local hookfunction = rawGetGlobal("hookfunction")
    local ok, oldFn = pcall(function() return remote.FireServer end)
    if not ok or type(oldFn) ~= "function" then return false end

    self.Hooked[remote] = true
    local name = Stealth.quiet(function() return remote:GetFullName() end) or remote.Name
    local cls = remote.ClassName

    local newFn = Stealth.wrap(function(self2, ...)
        local args = {...}
        local argsInfo = {}
        for i, v in ipairs(args) do
            local vt = typeof(v)
            if vt == "Instance" then
                argsInfo[i] = {
                    type = "Instance",
                    class = v.ClassName,
                    name = v.Name,
                    path = Stealth.quiet(function() return v:GetFullName() end),
                }
            elseif vt == "Vector3" then
                argsInfo[i] = { type = "Vector3", value = Utils.formatVector(v) }
            else
                argsInfo[i] = {
                    type = vt,
                    value = Utils.truncate(tostring(v), 150),
                }
            end
        end

        table.insert(TargetedHook.Log, {
            Remote = name,
            RemoteShort = remote.Name,
            RemoteClass = cls,      -- ★ เก็บ class
            Direction = "FireServer",
            Args = argsInfo,
            Time = os.date("%H:%M:%S"),
            Tick = tick(),
        })
        if #TargetedHook.Log > Config.Limits.HookLog then
            table.remove(TargetedHook.Log, 1)
        end

        return oldFn(self2, ...)
    end)

    local ok2 = pcall(hookfunction, oldFn, newFn)
    if not ok2 then
        self.Hooked[remote] = nil
        return false
    end
    self.Count = self.Count + 1
    return true
end

function TargetedHook:attachClient(remote)
    if self.HookedClient[remote] then return false end
    if not caps.hookfunction then return false end
    if not (remote:IsA("RemoteEvent") or remote.ClassName == "UnreliableRemoteEvent") then
        return false
    end

    local hookfunction = rawGetGlobal("hookfunction")
    local getconnections = rawGetGlobal("getconnections")
    if type(getconnections) ~= "function" then return false end

    local ok, conns = pcall(getconnections, remote.OnClientEvent)
    if not ok or type(conns) ~= "table" then return false end

    self.HookedClient[remote] = true
    local name = Stealth.quiet(function() return remote:GetFullName() end) or remote.Name

    for _, conn in ipairs(conns) do
        local ok2, oldFn = pcall(function() return conn.Function end)
        if ok2 and type(oldFn) == "function" then
            local newFn = Stealth.wrap(function(...)
                local args = {...}
                local argsInfo = {}
                for i, v in ipairs(args) do
                    local vt = typeof(v)
                    if vt == "Instance" then
                        argsInfo[i] = {
                            type = "Instance",
                            class = v.ClassName,
                            name = v.Name,
                            path = Stealth.quiet(function() return v:GetFullName() end),
                        }
                    elseif vt == "Vector3" then
                        argsInfo[i] = { type = "Vector3", value = Utils.formatVector(v) }
                    else
                        argsInfo[i] = {
                            type = vt,
                            value = Utils.truncate(tostring(v), 150),
                        }
                    end
                end
                table.insert(TargetedHook.ClientLog, {
                    Remote = name,
                    RemoteShort = remote.Name,
                    RemoteClass = remote.ClassName,
                    Direction = "OnClientEvent",
                    Args = argsInfo,
                    Time = os.date("%H:%M:%S"),
                    Tick = tick(),
                })
                if #TargetedHook.ClientLog > Config.Limits.HookLog then
                    table.remove(TargetedHook.ClientLog, 1)
                end
                return oldFn(...)
            end)
            pcall(hookfunction, oldFn, newFn)
        end
    end
    return true
end

function TargetedHook:start()
    if self.Running then return end
    self.Running = true

    Utils.log("🎯 TargetedHook: ค้นหา remote ที่ต้อง hook...")

    local count = 0
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        local ok = self:isTargeted(obj)
        if ok then
            if self:attach(obj) then count = count + 1 end
            if Config.TargetedHook.HookClientEvent then
                self:attachClient(obj)
            end
        end
    end

    local chars = workspace:FindFirstChild("Characters")
    if chars then
        for _, obj in ipairs(chars:GetDescendants()) do
            local ok = self:isTargeted(obj)
            if ok then
                if self:attach(obj) then count = count + 1 end
            end
        end
    end

    Utils.ok("🎯 Hook " .. count .. " remotes (รวม Unreliable)")

    local dur = Config.TargetedHook.RunDuration
    Utils.log("⏳ เก็บ args " .. dur .. " วิ...")
    local t0 = tick()
    while tick() - t0 < dur and scriptAlive do
        task.wait(1)
    end
    Utils.ok(string.format("🎯 เสร็จ — FireServer: %d, ClientEvent: %d",
        #self.Log, #self.ClientLog))
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 16: HITBOX WATCHER (v2)          ║
-- ╚═══════════════════════════════════════════╝
local HitboxWatcher = {
    Events = {},
    Seen = {},
    Running = false,
    Count = 0,
    Skipped = 0,
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

-- ★★★ ตรวจ hitbox แบบใหม่ ★★★
function HitboxWatcher:isHitbox(part)
    if not part:IsA("BasePart") then return false, nil end

    local cfg = Config.HitboxWatcher

    -- ★★★ ข้ามชื่อ body part ★★★
    local isIgnored = Utils.matchAny(part.Name, cfg.IgnoreNames)
    if isIgnored then return false, "ignored-name" end

    -- ★★★ ต้องมี pattern ที่ต้องการ ★★★
    local hasReq = Utils.matchPattern(part.Name, cfg.RequirePatterns)
    if not hasReq then return false, "no-require-pattern" end

    -- ★★★ owner check ★★★
    if cfg.IgnoreSelfOwner then
        local owner = getOwnerOfPart(part)
        if owner == LocalPlayer.Name then
            return false, "self-owner"
        end
    end

    -- ★★★ ตรวจคุณสมบัติ ★★★
    local isTransparent = part.Transparency >= cfg.MinTransparency
    local isCanCollideFalse = cfg.AlsoCheckCanCollideFalse
        and part.CanCollide == false
    local isMassless = cfg.AlsoCheckMassless and part.Massless == true

    if isTransparent and (isCanCollideFalse or isMassless) then
        return true, "match"
    end

    -- ถ้าชื่อ match pattern ตรง ๆ ก็เก็บ
    return true, "named"
end

function HitboxWatcher:scanOnce()
    local root = Config.HitboxWatcher.WatchOnlyCharacters
        and workspace:FindFirstChild("Characters") or workspace
    if not root then return end

    local myHRP = LocalPlayer.Character
        and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    local ok, err = pcall(function()
        for _, obj in ipairs(root:GetDescendants()) do
            if not self.Seen[obj] then
                local isHb, reason = self:isHitbox(obj)
                if isHb then
                    self.Seen[obj] = true
                    self.Count = self.Count + 1

                    local spawnTime = tick()
                    local owner = getOwnerOfPart(obj)
                    local distance = nil
                    if myHRP then
                        local ok2, d = pcall(function()
                            return math.floor(
                                (obj.Position - myHRP.Position).Magnitude)
                        end)
                        if ok2 then distance = d end
                    end

                    local event = {
                        Name = obj.Name,
                        Class = obj.ClassName,
                        Owner = owner,
                        Reason = reason,
                        Position = Utils.formatVector(obj.Position),
                        Size = Utils.formatVector(obj.Size),
                        Transparency = obj.Transparency,
                        CanCollide = obj.CanCollide,
                        Massless = obj.Massless,
                        DistanceFromMe = distance,
                        SpawnTime = spawnTime,
                        SpawnTimeStr = os.date("%H:%M:%S") ..
                            string.format(".%03d", math.floor((spawnTime % 1) * 1000)),
                        Path = Stealth.quiet(function() return obj:GetFullName() end),
                    }
                    table.insert(self.Events, event)

                    task.spawn(function()
                        local conn
                        conn = obj.AncestryChanged:Connect(function()
                            if conn then conn:Disconnect() end
                            local t = tick()
                            event.DespawnTime = t
                            event.Duration = t - spawnTime
                            event.DurationMs = math.floor(event.Duration * 1000)
                            -- ★ ลบ outlier ที่อยู่นานผิดปกติ
                            if event.DurationMs > Config.HitboxWatcher.MaxValidDurationMs then
                                event.IsOutlier = true
                            end
                        end)
                    end)

                    if #self.Events > Config.Limits.HitboxLog then
                        table.remove(self.Events, 1)
                    end
                else
                    -- นับที่ถูก skip (ไม่เก็บ)
                    if reason and reason ~= "no-require-pattern" then
                        self.Skipped = self.Skipped + 1
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

    Utils.log("📊 HitboxWatcher v2: เริ่ม (poll " ..
        (Config.HitboxWatcher.PollRate * 1000) .. "ms)")
    Utils.log("   - ตัด body part (Collide, Torso, Head, ...)")
    Utils.log("   - เฉพาะ Hitbox/HitGlow/CombatTrail/SlashHit")
    Utils.log("   - ตัด owner = ตัวเอง")
    Utils.log("   - duration ≤ " .. Config.HitboxWatcher.MaxValidDurationMs .. "ms")

    local dur = Config.HitboxWatcher.RunDuration
    local t0 = tick()
    local nextTick = t0

    while tick() - t0 < dur and scriptAlive do
        self:scanOnce()
        nextTick = nextTick + Config.HitboxWatcher.PollRate
        local wait = nextTick - tick()
        if wait > 0 then task.wait(wait) else task.wait() end
    end

    Utils.ok("📊 HitboxWatcher v2: " .. self.Count .. " hitbox events (skip " ..
        self.Skipped .. ")")
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 17: ANALYZER                     ║
-- ╚═══════════════════════════════════════════╝
local Analyzer = {}

function Analyzer.analyze(dump, extra)
    extra = extra or {}
    local report = {
        Summary = {}, Hints = {}, Recommendations = {}, Risks = {},
        TimingAnalysis = {},
        TopHookedRemotes = {},
        UnreliableCount = 0,
    }

    report.Summary.Collectibles = #(dump.Collectibles or {})
    report.Summary.Enemies = #(dump.Enemies or {})
    report.Summary.Portals = #(dump.Portals or {})
    report.Summary.Remotes = #(dump.Remotes or {})
    report.Summary.Hitboxes = #(dump.Hitboxes or {})
    report.Summary.Spawns = #(dump.Spawns or {})
    report.Summary.AntiCheat = #(dump.AntiCheatSuspects or {})
    report.Summary.UnreliableRemotes = #(dump.UnreliableRemotes or {})

    local interested = 0
    for _, r in ipairs(dump.Remotes or {}) do
        if r.Interested then interested = interested + 1 end
    end
    report.Summary.InterestedRemotes = interested
    report.Summary.HookFireServer = #(extra.HookLog or {})
    report.Summary.HookClientEvent = #(extra.ClientLog or {})
    report.Summary.HitboxEvents = #(extra.HitboxEvents or {})

    -- ★★ Timing hitbox — กรอง outlier ★★
    local durations = {}
    for _, e in ipairs(extra.HitboxEvents or {}) do
        if e.DurationMs and not e.IsOutlier
           and e.DurationMs <= Config.HitboxWatcher.MaxValidDurationMs then
            table.insert(durations, e.DurationMs)
        end
    end
    if #durations > 0 then
        table.sort(durations)
        report.TimingAnalysis = {
            Count = #durations,
            MinMs = durations[1],
            MaxMs = durations[#durations],
            MedianMs = durations[math.floor(#durations / 2) + 1],
            RecommendedParryDelayMs = math.max(20, math.floor(durations[1] / 3)),
        }
        table.insert(report.Hints, string.format(
            "🎯 Hitbox duration: %d-%dms (median %d, แนะนำ %dms)",
            report.TimingAnalysis.MinMs,
            report.TimingAnalysis.MaxMs,
            report.TimingAnalysis.MedianMs,
            report.TimingAnalysis.RecommendedParryDelayMs))
    end

    -- ★★ วิเคราะห์ hook ★★
    local byRemote = {}
    for _, log in ipairs(extra.HookLog or {}) do
        byRemote[log.RemoteShort] = (byRemote[log.RemoteShort] or 0) + 1
    end
    report.TopHookedRemotes = byRemote

    if report.Summary.UnreliableRemotes > 0 then
        table.insert(report.Hints,
            "⭐ UnreliableRemoteEvent: " .. report.Summary.UnreliableRemotes .. " ตัว")
    end

    if report.Summary.Collectibles > 0 then
        table.insert(report.Hints,
            "✅ Auto Collect: " .. report.Summary.Collectibles)
    end
    if report.Summary.Enemies > 0 then
        table.insert(report.Hints,
            "✅ Auto Farm: " .. report.Summary.Enemies)
    end
    if report.Summary.HookFireServer > 0 then
        table.insert(report.Hints,
            "✅ Hook FireServer: " .. report.Summary.HookFireServer .. " events")
    end
    if report.Summary.HookClientEvent > 0 then
        table.insert(report.Hints,
            "✅ Hook ClientEvent: " .. report.Summary.HookClientEvent .. " events")
    end
    if report.Summary.AntiCheat > 0 then
        table.insert(report.Risks,
            "⚠️ Anti-Cheat: " .. report.Summary.AntiCheat)
    end

    return report
end

-- ╔═══════════════════════════════════════════╗
-- ║  SECTION 18: MAIN                         ║
-- ╚═══════════════════════════════════════════╝

local startTime = tick()

Utils.log("═══════════════════════════════════════")
Utils.log("Dump Framework V" .. Config.Version .. " | UNRELIABLE")
Utils.log("═══════════════════════════════════════")
Utils.log("📁 Session: " .. Config.OutputFolder)
Utils.log(string.format("Write: %s | Clipboard: %s | Hook: %s | List: %s",
    tostring(FileAPI.hasWriteSupport()),
    tostring(FileAPI.hasClipboard()),
    tostring(caps.hookfunction),
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
        serializer:save("18_smart_unreliable", sData.UnreliableRemotes)  -- ★
        summary["Collectibles"] = #sData.Collectibles
        summary["Enemies"] = #sData.Enemies
        summary["Remotes"] = #sData.Remotes
        summary["Hitboxes"] = #sData.Hitboxes
        summary["AntiCheat"] = #sData.AntiCheatSuspects
        summary["Unreliable"] = #sData.UnreliableRemotes
        _G.__BoomxicoSmartData = sData
    else summary["SmartScan"] = "ERR" end
end

if Config.Targets.BlockServiceScan then
    Utils.log("═══ WAVE 3: Services ═══")
    local ok, svcData = pcall(collectImportantServices)
    if ok then
        serializer:save("24_important_services", svcData)
        summary["Services"] = "OK"
    else summary["Services"] = "ERR" end
end

if Config.Targets.CharacterRemotes then
    Utils.log("═══ WAVE 3: Character Remotes ═══")
    local ok, cr = pcall(collectCharacterRemotes)
    if ok then
        serializer:save("25_character_remotes", cr)
        local count = 0
        for _ in pairs(cr) do count = count + 1 end
        summary["CharRemotes"] = count
    else summary["CharRemotes"] = "ERR" end
end

-- ★★★ Unreliable scan แยก ★★★
if Config.Targets.UnreliableScan then
    Utils.log("═══ WAVE 3: Unreliable Scan ═══")
    local ok, ur = pcall(collectUnreliableRemotes)
    if ok then
        serializer:save("26_unreliable_remotes", ur)
        summary["UnreliableTotal"] = ur.Total
    else summary["UnreliableTotal"] = "ERR" end
end

Utils.waitBetweenWaves()

-- ╔═══ WAVE 4 ═══╗
Utils.log("═══ WAVE 4: Live Capture ═══")

if Config.Targets.TargetedHook then
    local ok = pcall(function() TargetedHook:start() end)
    if ok then
        serializer:save("27_targeted_hook_server", TargetedHook.Log)
        serializer:save("28_targeted_hook_client", TargetedHook.ClientLog)
        summary["HookServer"] = #TargetedHook.Log
        summary["HookClient"] = #TargetedHook.ClientLog
    else summary["HookServer"] = "ERR" end
end

if Config.Targets.HitboxWatcher then
    local ok = pcall(function() HitboxWatcher:start() end)
    if ok then
        serializer:save("29_hitbox_realtime", HitboxWatcher.Events)
        summary["HitboxEvents"] = #HitboxWatcher.Events
    else summary["HitboxEvents"] = "ERR" end
end

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
        for _, r in ipairs(report.Risks) do Utils.warn(r) end
        serializer:save("30_analysis_report", report)
        summary["Analysis"] = "OK"
    end
end

serializer:saveIndex()

-- สรุป
local elapsed = tick() - startTime
summary["Total Time (s)"] = string.format("%.2f", elapsed)
summary["Total Objects"] = extractor.count

Utils.printSummary(summary, "Dump V3.5 Complete")

Utils.log("═══════════════════════════════════════")
Utils.log("📂 Session: " .. Config.OutputFolder)
Utils.log("📄 ดู " .. Config.OutputFolder .. "/_INDEX.json")
Utils.log("═══════════════════════════════════════")
