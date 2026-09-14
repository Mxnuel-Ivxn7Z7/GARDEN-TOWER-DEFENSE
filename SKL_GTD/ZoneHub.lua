--[[
    ZONE HUB GTD - Macro Recorder / Player
    Version: 3.0.0
    Target: Garden Tower Defense

    Goals:
      * Lightweight responsive UI for PC/mobile.
      * Macro recording from client -> server remote traffic when executor hooks are available.
      * Records player position before placement/upgrade actions.
      * Records abilities without forcing player movement.
      * Smart/Hybrid playback: wave + relative-time gating.
      * Auto Play loops the selected macro after each new match.
      * Game Speed and Auto Skip are applied ONCE per match, not stored in exported macros.
      * Map + level are separate from the exported macro.
      * Local save/load/rename/delete + compact export/import.
      * Live console with ACTION/WARN/ERROR filters.

    Important:
      * This script does NOT include stealth/anti-detection behavior.
      * No humanization/jitter/Bezier mouse movement is used.
      * Remote capture is diagnostic/recording-oriented and depends on executor capabilities.
]]

--------------------------------------------------------------------------------
-- 0. BOOT / CLEANUP
--------------------------------------------------------------------------------
local ENV = (getgenv and getgenv()) or _G

if ENV.ZoneHubUnload then
    pcall(ENV.ZoneHubUnload)
    task.wait(0.15)
end

ENV.ZoneHubRunning = true
ENV.ZoneHubLoaded = true

--------------------------------------------------------------------------------
-- 1. SERVICES
--------------------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local ParentGui = CoreGui
local coreOk = pcall(function()
    local probe = Instance.new("Folder")
    probe.Parent = CoreGui
    probe:Destroy()
end)

if not coreOk then
    ParentGui = PlayerGui
end

--------------------------------------------------------------------------------
-- 2. APP
--------------------------------------------------------------------------------
local ZH = {
    Version = "8.0.0",
    Connections = {},
    ReplayGuard = false,
    RoundToken = 0,

    Theme = {
        Bg = Color3.fromRGB(17, 15, 22),
        Card = Color3.fromRGB(26, 22, 33),
        Card2 = Color3.fromRGB(33, 28, 41),
        Border = Color3.fromRGB(83, 55, 98),
        Accent = Color3.fromRGB(218, 112, 200),
        Text = Color3.fromRGB(245, 245, 248),
        Sub = Color3.fromRGB(170, 160, 182),
        Good = Color3.fromRGB(42, 190, 95),
        Warn = Color3.fromRGB(235, 164, 52),
        Bad = Color3.fromRGB(225, 75, 75),
    },

    Themes = {
        ["Pink / Purple"] = {
            Bg=Color3.fromRGB(17,15,22), Card=Color3.fromRGB(26,22,33),
            Card2=Color3.fromRGB(33,28,41), Border=Color3.fromRGB(83,55,98),
            Accent=Color3.fromRGB(218,112,200), Text=Color3.fromRGB(245,245,248),
            Sub=Color3.fromRGB(170,160,182)
        },
        ["Blue / Yellow"] = {
            Bg=Color3.fromRGB(11,22,35), Card=Color3.fromRGB(16,34,52),
            Card2=Color3.fromRGB(21,44,66), Border=Color3.fromRGB(51,111,158),
            Accent=Color3.fromRGB(244,196,48), Text=Color3.fromRGB(238,247,255),
            Sub=Color3.fromRGB(155,184,207)
        },
        ["White / Black"] = {
            Bg=Color3.fromRGB(235,235,235), Card=Color3.fromRGB(250,250,250),
            Card2=Color3.fromRGB(220,220,220), Border=Color3.fromRGB(80,80,80),
            Accent=Color3.fromRGB(25,25,25), Text=Color3.fromRGB(20,20,20),
            Sub=Color3.fromRGB(90,90,90)
        },
        ["Green / Black"] = {
            Bg=Color3.fromRGB(8,13,10), Card=Color3.fromRGB(14,23,17),
            Card2=Color3.fromRGB(20,32,24), Border=Color3.fromRGB(43,100,58),
            Accent=Color3.fromRGB(66,210,105), Text=Color3.fromRGB(235,245,238),
            Sub=Color3.fromRGB(145,175,152)
        },
    },

    Paths = {
        Root = "ZoneHubGTD",
        Macros = "ZoneHubGTD/Macros",
        Config = "ZoneHubGTD/config.json",
    },

    Maps = {
        ["Farm Frenzy"] = 4,
        ["Enchanted Encounter"] = 5,
        ["Tropical Takedown"] = 5,
        ["Radioactive Rampage"] = 5,
        ["Graveyard Gauntlet"] = 5,
        ["Garden Grind"] = 5,
        ["Space Showdown"] = 6,
        ["Dojo Dynasty"] = 6,
        ["Winter Wonderland"] = 6,
        ["Aqua Ambush"] = 6,
        ["Volcano Vengeance"] = 7,
    },

    MapOrder = {
        "Farm Frenzy",
        "Enchanted Encounter",
        "Tropical Takedown",
        "Radioactive Rampage",
        "Graveyard Gauntlet",
        "Garden Grind",
        "Space Showdown",
        "Dojo Dynasty",
        "Winter Wonderland",
        "Aqua Ambush",
        "Volcano Vengeance",
    },

    State = {
        SelectedMap = "Farm Frenzy",
        SelectedLevel = 1,
        Speed = "x3",
        AutoSkip = true,
        AntiAFK = true,
        ThemeName = "Pink / Purple",
        AutoPlayMacro = false,

        MacroName = "DefaultMacro",
        SelectedMacro = nil,
        IsRecording = false,
        IsRecordingPaused = false,
        IsPlaying = false,
        RecordingStartedAt = 0,
        RecordingPauseStartedAt = 0,
        RecordingPausedTotal = 0,

        ConsoleFilter = "ALL",
        DiagnosticCapture = false,
        CurrentWave = 0,
    },

    Runtime = {
        Actions = {},
        LoadedMacro = nil,
        Console = {},
        MacroNames = {},
        RoundStarted = false,
        LastRoundSignature = nil,
        LastEndClick = 0,
        LastApplyOptions = 0,
        HookInstalled = false,
        LastActionKey = nil,
        LastActionAt = 0,
        DeleteConfirmUntil = 0,
        ReplayUnitMap = {},
        LastRecordedPlaces = {},
        TargetHooksInstalled = false,
        TargetHookConnections = {},
        RecordedIdToRef = {},
        NextMacroUnitRef = 1,
    },

    UI = {}
}

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(ZH.Connections, c)
    return c
end

local function safeNotify(title, text)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = 3
        })
    end)
end

--------------------------------------------------------------------------------
-- 3. STORAGE
--------------------------------------------------------------------------------
local function ensureFolders()
    if type(isfolder) == "function" and type(makefolder) == "function" then
        if not isfolder(ZH.Paths.Root) then
            pcall(makefolder, ZH.Paths.Root)
        end
        if not isfolder(ZH.Paths.Macros) then
            pcall(makefolder, ZH.Paths.Macros)
        end
    end
end

ensureFolders()

local function sanitizeName(name)
    name = tostring(name or "Macro")
    name = name:gsub("[^%w%-%_ ]", "_")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        name = "Macro"
    end
    return name
end

local function macroPath(name)
    return ZH.Paths.Macros .. "/" .. sanitizeName(name) .. ".json"
end

local function fileExists(path)
    return type(isfile) == "function" and isfile(path)
end

local function uniqueMacroName(base)
    base = sanitizeName(base)
    if not fileExists(macroPath(base)) then
        return base
    end

    local i = 2
    while fileExists(macroPath(base .. "_" .. i)) do
        i += 1
    end
    return base .. "_" .. i
end

--------------------------------------------------------------------------------
-- 4. SERIALIZATION OF ROBLOX VALUES
--------------------------------------------------------------------------------
local function encodeValue(v, depth)
    depth = depth or 0
    if depth > 6 then
        return { __t = "Unsupported", v = "max_depth" }
    end

    local tv = typeof(v)

    if tv == "nil" then
        return { __t = "Nil" }
    elseif tv == "boolean" or tv == "number" or tv == "string" then
        return v
    elseif tv == "Vector3" then
        return { __t = "Vector3", x = v.X, y = v.Y, z = v.Z }
    elseif tv == "Vector2" then
        return { __t = "Vector2", x = v.X, y = v.Y }
    elseif tv == "CFrame" then
        return { __t = "CFrame", c = { v:GetComponents() } }
    elseif tv == "Color3" then
        return { __t = "Color3", r = v.R, g = v.G, b = v.B }
    elseif tv == "EnumItem" then
        return { __t = "EnumItem", e = tostring(v.EnumType), n = v.Name }
    elseif tv == "Instance" then
        return { __t = "Instance", path = v:GetFullName(), class = v.ClassName }
    elseif tv == "table" then
        local out = {}
        for k, val in pairs(v) do
            out[tostring(k)] = encodeValue(val, depth + 1)
        end
        return { __t = "Table", v = out }
    end

    return { __t = "Unsupported", v = tv }
end

local function findByFullName(full)
    if not full then return nil end

    local parts = string.split(full, ".")
    local current = game

    if parts[1] == "game" then
        table.remove(parts, 1)
    end

    for _, part in ipairs(parts) do
        current = current and current:FindFirstChild(part)
        if not current then return nil end
    end

    return current
end

local function decodeValue(v)
    if type(v) ~= "table" or v.__t == nil then
        return v
    end

    if v.__t == "Nil" then
        return nil
    elseif v.__t == "Vector3" then
        return Vector3.new(v.x, v.y, v.z)
    elseif v.__t == "Vector2" then
        return Vector2.new(v.x, v.y)
    elseif v.__t == "CFrame" then
        return CFrame.new(unpack(v.c))
    elseif v.__t == "Color3" then
        return Color3.new(v.r, v.g, v.b)
    elseif v.__t == "Instance" then
        return findByFullName(v.path)
    elseif v.__t == "Table" then
        local out = {}
        for k, val in pairs(v.v or {}) do
            out[k] = decodeValue(val)
        end
        return out
    end

    return nil
end

local function encodeArgs(args)
    local out = {}
    for i, v in ipairs(args) do
        out[i] = encodeValue(v)
    end
    return out
end

local function decodeArgs(args)
    local out = {}
    for i, v in ipairs(args or {}) do
        out[i] = decodeValue(v)
    end
    return out
end

--------------------------------------------------------------------------------
-- 5. LOGGER
--------------------------------------------------------------------------------
local function log(level, text)
    level = level or "ACTION"
    local row = {
        t = os.date("%H:%M:%S"),
        level = level,
        text = tostring(text)
    }

    table.insert(ZH.Runtime.Console, 1, row)
    if #ZH.Runtime.Console > 250 then
        table.remove(ZH.Runtime.Console)
    end

    if ZH.UI.RefreshConsole then
        ZH.UI.RefreshConsole()
    end
end

--------------------------------------------------------------------------------
-- 6. PLAYER / WAVE / GUI HELPERS
--------------------------------------------------------------------------------
local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getPlayerCFrame()
    local root = getRoot()
    return root and root.CFrame or nil
end

local function teleportPlayer(cf)
    if typeof(cf) ~= "CFrame" then
        return false, "invalid cframe"
    end

    local root = getRoot()
    if not root then
        return false, "HumanoidRootPart missing"
    end

    local ok, err = pcall(function()
        root.CFrame = cf
    end)

    if ok then
        task.wait(0.12)
    end

    return ok, err
end

local function isOwnGuiObject(obj)
    return gui and obj and obj:IsDescendantOf(gui)
end

local function visibleTextObjects()
    local list = {}
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if not isOwnGuiObject(obj) and obj:IsA("GuiObject") and obj.Visible then
            local text = nil
            if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
                text = obj.Text
            end
            if text and text ~= "" then
                table.insert(list, { obj = obj, text = text })
            end
        end
    end
    return list
end

local function parseWave()
    local best = 0

    for _, item in ipairs(visibleTextObjects()) do
        local s = tostring(item.text)
        local n =
            s:match("[Ww]ave%s*[:%-]?%s*(%d+)") or
            s:match("(%d+)%s*/%s*%d+")

        if n then
            best = math.max(best, tonumber(n) or 0)
        end
    end

    ZH.State.CurrentWave = best
    return best
end

local function normalizeText(s)
    return tostring(s or ""):lower():gsub("%s+", " ")
end

local function scoreButton(obj, wanted)
    if not obj:IsA("GuiButton") or not obj.Visible then
        return -1
    end

    local text = ""
    if obj:IsA("TextButton") then
        text = normalizeText(obj.Text)
    end

    wanted = normalizeText(wanted)

    if text == wanted then
        return 100
    elseif text:find(wanted, 1, true) then
        return 70
    end

    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("TextLabel") then
            local ct = normalizeText(child.Text)
            if ct == wanted then
                return 90
            elseif ct:find(wanted, 1, true) then
                return 60
            end
        end
    end

    return -1
end

local function findButton(wantedList)
    local best, bestScore = nil, -1

    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if not isOwnGuiObject(obj) and obj:IsA("GuiButton") and obj.Visible then
            for _, wanted in ipairs(wantedList) do
                local s = scoreButton(obj, wanted)
                if s > bestScore then
                    best, bestScore = obj, s
                end
            end
        end
    end

    return best
end

local function clickButton(btn)
    if not btn or not btn:IsA("GuiButton") then
        return false
    end

    if type(firesignal) == "function" then
        local ok = pcall(function()
            firesignal(btn.MouseButton1Click)
        end)
        if ok then return true end
    end

    local okActivate = pcall(function()
        btn:Activate()
    end)
    if okActivate then
        return true
    end

    local pos = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    local x = pos.X + size.X / 2
    local y = pos.Y + size.Y / 2

    return pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.04)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
end

--------------------------------------------------------------------------------
-- 7. GAME OPTIONS: SPEED / AUTO SKIP
--------------------------------------------------------------------------------
local function applyGameSpeed()
    local wanted = ZH.State.Speed
    if wanted ~= "x1" and wanted ~= "x2" and wanted ~= "x3" then
        return false
    end

    -- PC usually exposes x1/x2/x3 directly.
    local direct = findButton({ wanted })
    if direct and clickButton(direct) then
        log("ACTION", "Game Speed -> " .. wanted)
        return true
    end

    -- Mobile may require opening the Game Speed control first.
    local opener = findButton({ "Game Speed", "Game Speed:" })
    if opener then
        clickButton(opener)
        task.wait(0.15)
        direct = findButton({ wanted })
        if direct and clickButton(direct) then
            log("ACTION", "Game Speed -> " .. wanted .. " (mobile menu)")
            return true
        end
    end

    log("WARN", "Could not find Game Speed button " .. wanted)
    return false
end

local function readAutoSkipState()
    for _, item in ipairs(visibleTextObjects()) do
        local s = normalizeText(item.text)
        if s:find("auto skip", 1, true) then
            if s:find("off", 1, true) then return false end
            if s:find("on", 1, true) then return true end
        end
    end
    return nil
end

local function applyAutoSkip()
    local desired = ZH.State.AutoSkip
    local current = readAutoSkipState()

    if current ~= nil and current == desired then
        log("ACTION", "Auto Skip already " .. (desired and "ON" or "OFF"))
        return true
    end

    local btn = findButton({
        "Auto Skip: Off", "Auto Skip Off",
        "Auto Skip: On", "Auto Skip On",
        "Auto Skip"
    })

    if btn and clickButton(btn) then
        task.wait(0.12)
        log("ACTION", "Auto Skip -> " .. (desired and "ON" or "OFF"))
        return true
    end

    log("WARN", "Could not change Auto Skip")
    return false
end

local function applyRoundOptionsOnce()
    local now = os.clock()
    if now - ZH.Runtime.LastApplyOptions < 4 then
        return
    end

    ZH.Runtime.LastApplyOptions = now
    task.wait(0.25)
    applyGameSpeed()
    task.wait(0.18)
    applyAutoSkip()
end

--------------------------------------------------------------------------------
-- 8. MAP / LEVEL CONFIG
--------------------------------------------------------------------------------
local function currentMaxLevel()
    return ZH.Maps[ZH.State.SelectedMap] or 1
end

local function clampSelectedLevel()
    ZH.State.SelectedLevel = math.clamp(
        tonumber(ZH.State.SelectedLevel) or 1,
        1,
        currentMaxLevel()
    )
end

local function cleanChoiceText(s)
    s = tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #s < 2 or #s > 42 then return nil end
    return s
end

local function collectGameChoices(kind)
    local found = {}

    if kind == "map" then
        for _, name in ipairs(ZH.MapOrder) do
            table.insert(found, name)
        end
        return found
    end

    for i = 1, currentMaxLevel() do
        table.insert(found, tostring(i))
    end
    return found
end

local function selectConfiguredMapAndLevel()
    local mapButton = findButton({ ZH.State.SelectedMap })
    if mapButton then
        clickButton(mapButton)
        log("ACTION", "Selected map: " .. ZH.State.SelectedMap)
        task.wait(0.2)
    else
        log("WARN", "Game map menu is not open; skipped map selection")
        return false
    end

    clampSelectedLevel()

    local levelText = "Level " .. tostring(ZH.State.SelectedLevel)
    local levelButton = findButton({ levelText, tostring(ZH.State.SelectedLevel) })

    if levelButton then
        clickButton(levelButton)
        log("ACTION", "Selected " .. levelText)
        task.wait(0.15)
    else
        log("WARN", "Level button not visible: " .. levelText)
    end
end

--------------------------------------------------------------------------------
-- 9. REMOTE RECORDING
--------------------------------------------------------------------------------
local ACTION_KEYWORDS = {
    Place = { "place", "spawn", "summon", "deploy", "plant" },
    Upgrade = { "upgrade", "levelup", "improve" },
    Ability = { "ability", "skill", "special", "ultimate", "ult" },
    Sell = { "sell", "remove" },
    Target = { "target", "priority" },
}

local function classifyRemote(remote)
    local n = normalizeText(remote and remote:GetFullName() or "")

    for actionType, words in pairs(ACTION_KEYWORDS) do
        for _, word in ipairs(words) do
            if n:find(word, 1, true) then
                return actionType
            end
        end
    end

    return "Remote"
end

local function shouldRecordRemote(remote)
    local class = classifyRemote(remote)
    local name = normalizeText(remote:GetFullName())

    local ignored = {
        "renotifyevent",
        "sandboxaddenemytoqueue",
        "skipwave",
        "analytics",
        "telemetry",
        "heartbeat",
        "ping",
        "chat",
        "voice",
        "replication",
        "stats",
        "purchase",
        "product"
    }

    for _, bad in ipairs(ignored) do
        if name:find(bad, 1, true) then
            return false
        end
    end

    -- Normal mode only records recognized gameplay actions.
    if class ~= "Remote" then
        return true
    end

    -- Diagnostic mode is intentionally opt-in.
    return ZH.State.DiagnosticCapture == true
end

local function compactActionKey(remote, method, args, actionType)
    local parts = { remote:GetFullName(), method, actionType }

    if actionType == "Place" then
        local unit = tostring(args[1] or "")
        table.insert(parts, unit)

        local payload = args[2]
        local pos = nil
        if type(payload) == "table" then
            pos = payload.Position
            if typeof(pos) ~= "Vector3" and typeof(payload.CF) == "CFrame" then
                pos = payload.CF.Position
            end
        end

        if typeof(pos) == "Vector3" then
            table.insert(parts, string.format("%.1f,%.1f,%.1f", pos.X, pos.Y, pos.Z))
        end
    elseif actionType == "Upgrade" or actionType == "Ability" or actionType == "Sell" or actionType == "Target" then
        table.insert(parts, tostring(args[1]))
        table.insert(parts, tostring(args[2]))
    end

    return table.concat(parts, "|")
end

local function recordingElapsed()
    local elapsed = os.clock() - ZH.State.RecordingStartedAt - (ZH.State.RecordingPausedTotal or 0)
    return math.max(0, elapsed)
end

local function extractPossibleUnitId(results)
    for _, v in ipairs(results or {}) do
        if type(v) == "number" or type(v) == "string" then
            return v
        elseif typeof(v) == "Instance" then
            local id = v:GetAttribute("UnitId") or v:GetAttribute("Id") or v:GetAttribute("ID")
            if id ~= nil then return id end
        elseif type(v) == "table" then
            local id = v.UnitId or v.unitId or v.Id or v.id or v.ID
            if id ~= nil then return id end
        end
    end
    return nil
end

local function getPlacementPositionFromArgs(args)
    local payload = args and args[2]
    if type(payload) == "table" then
        if typeof(payload.Position) == "Vector3" then
            return payload.Position
        end
        if typeof(payload.CF) == "CFrame" then
            return payload.CF.Position
        end
    end
    return nil
end

local function attachUpgradeToNearestPlace(oldUnitId, playerCF)
    if oldUnitId == nil or typeof(playerCF) ~= "CFrame" then return end

    local bestAction, bestDist = nil, math.huge
    for i = #ZH.Runtime.Actions, 1, -1 do
        local a = ZH.Runtime.Actions[i]
        if a.Type == "Place" and not a.RecordedUnitId then
            local p = a.UnitPosition and decodeValue(a.UnitPosition)
            if typeof(p) == "Vector3" then
                local d = (p - playerCF.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    bestAction = a
                end
            end
        end
    end

    if bestAction and bestDist <= 35 then
        bestAction.RecordedUnitId = oldUnitId
        log("ACTION", "Linked recorded unit id " .. tostring(oldUnitId) .. " to nearest placement")
    end
end

local function pushRecordedRemote(remote, method, args, results)
    if not ZH.State.IsRecording or ZH.State.IsRecordingPaused or ZH.ReplayGuard then
        return
    end

    if not remote or not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
        return
    end

    if not shouldRecordRemote(remote) then
        return
    end

    local now = os.clock()
    local actionType = classifyRemote(remote)
    local key = compactActionKey(remote, method, args, actionType)

    if ZH.Runtime.LastActionKey == key and (now - (ZH.Runtime.LastActionAt or 0)) < 0.4 then
        return
    end
    ZH.Runtime.LastActionKey = key
    ZH.Runtime.LastActionAt = now

    local action = {
        Type = actionType,
        Method = method,
        RemotePath = remote:GetFullName(),
        Args = encodeArgs(args),
        Sync = { RelativeTime = recordingElapsed() }
    }

    local playerCF = getPlayerCFrame()

    if actionType == "Place" then
        local pos = getPlacementPositionFromArgs(args)
        if typeof(pos) == "Vector3" then
            action.UnitPosition = encodeValue(pos)
        end

        local returnedId = extractPossibleUnitId(results)
        if returnedId ~= nil then
            action.RecordedUnitId = returnedId
        end
    end

    if playerCF and (
        actionType == "Place" or
        actionType == "Upgrade" or
        actionType == "Sell" or
        actionType == "Target"
    ) then
        action.PlayerPosition = encodeValue(playerCF)
    end

    table.insert(ZH.Runtime.Actions, action)

    if actionType == "Upgrade" then
        attachUpgradeToNearestPlace(args and args[1], playerCF)
    end

    log("ACTION", string.format(
        "REC #%d %s | %.2fs | %s",
        #ZH.Runtime.Actions,
        actionType,
        action.Sync.RelativeTime,
        remote.Name
    ))
end

local function findRemoteByName(name)
    local rf = ReplicatedStorage:FindFirstChild("RemoteFunctions")
    if rf then
        local obj = rf:FindFirstChild(name, true)
        if obj then return obj end
    end
    return ReplicatedStorage:FindFirstChild(name, true)
end

local function getAbilityRemotes()
    local out = {}
    for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteFunction") or obj:IsA("RemoteEvent") then
            local n = normalizeText(obj.Name)
            if n:find("ability", 1, true)
                or n:find("skill", 1, true)
                or n:find("special", 1, true)
                or n:find("ultimate", 1, true)
            then
                table.insert(out, obj)
            end
        end
    end
    return out
end

local function nextMacroRef()
    local ref = "U" .. tostring(ZH.Runtime.NextMacroUnitRef or 1)
    ZH.Runtime.NextMacroUnitRef = (ZH.Runtime.NextMacroUnitRef or 1) + 1
    return ref
end

local function getMacroRefForRecordedId(id)
    if id == nil then return nil end
    return ZH.Runtime.RecordedIdToRef[tostring(id)]
end

local function rememberRecordedId(id, ref)
    if id ~= nil and ref ~= nil then
        ZH.Runtime.RecordedIdToRef[tostring(id)] = ref
    end
end

local function targetedRecord(remote, method, args, results)
    if not ZH.State.IsRecording or ZH.State.IsRecordingPaused or ZH.ReplayGuard then
        return
    end

    local actionType = classifyRemote(remote)
    if actionType == "Remote" then return end

    local now = os.clock()
    local key = compactActionKey(remote, method, args, actionType)
    if ZH.Runtime.LastActionKey == key and (now - (ZH.Runtime.LastActionAt or 0)) < 0.4 then
        return
    end
    ZH.Runtime.LastActionKey = key
    ZH.Runtime.LastActionAt = now

    local action = {
        Type = actionType,
        Method = method,
        RemotePath = remote:GetFullName(),
        Args = encodeArgs(args),
        Sync = { RelativeTime = recordingElapsed() },
    }

    local playerCF = getPlayerCFrame()
    if playerCF and (actionType == "Place" or actionType == "Upgrade") then
        action.PlayerPosition = encodeValue(playerCF)
    end

    if actionType == "Place" then
        action.UnitRef = nextMacroRef()
        local p = getPlacementPositionFromArgs(args)
        if typeof(p) == "Vector3" then
            action.UnitPosition = encodeValue(p)
        end

        local id = extractPossibleUnitId(results)
        if id ~= nil then
            action.RecordedUnitId = id
            rememberRecordedId(id, action.UnitRef)
        end

    elseif actionType == "Upgrade" or actionType == "Ability" or actionType == "Sell" or actionType == "Target" then
        local recordedId = args and args[1]
        action.UnitRef = getMacroRefForRecordedId(recordedId)
        action.RecordedUnitId = recordedId
    end

    table.insert(ZH.Runtime.Actions, action)
    log("ACTION", string.format(
        "REC #%d %s%s | %.2fs",
        #ZH.Runtime.Actions,
        actionType,
        action.UnitRef and (" " .. tostring(action.UnitRef)) or "",
        action.Sync.RelativeTime
    ))
end

local function installTargetHook(remote)
    if not remote then return false end
    if type(hookfunction) ~= "function" then return false end

    if remote:IsA("RemoteFunction") then
        local oldInvoke
        local ok = pcall(function()
            oldInvoke = hookfunction(remote.InvokeServer, function(self, ...)
                local args = {...}

                -- Only inspect the exact remotes selected by this recorder.
                if self ~= remote then
                    return oldInvoke(self, ...)
                end

                local results = {oldInvoke(self, ...)}
                task.defer(function()
                    pcall(targetedRecord, remote, "InvokeServer", args, results)
                end)
                return unpack(results)
            end)
        end)
        return ok
    end

    if remote:IsA("RemoteEvent") then
        local oldFire
        local ok = pcall(function()
            oldFire = hookfunction(remote.FireServer, function(self, ...)
                local args = {...}

                if self ~= remote then
                    return oldFire(self, ...)
                end

                local result = oldFire(self, ...)
                task.defer(function()
                    pcall(targetedRecord, remote, "FireServer", args, nil)
                end)
                return result
            end)
        end)
        return ok
    end

    return false
end

local function installRemoteHook()
    if ZH.Runtime.TargetHooksInstalled then
        return true
    end

    local targets = {}
    local place = findRemoteByName("PlaceUnit")
    local upgrade = findRemoteByName("UpgradeUnit")

    if place then table.insert(targets, place) end
    if upgrade then table.insert(targets, upgrade) end

    for _, remote in ipairs(getAbilityRemotes()) do
        table.insert(targets, remote)
    end

    local hooked = 0
    local seen = {}
    for _, remote in ipairs(targets) do
        if remote and not seen[remote] then
            seen[remote] = true
            if installTargetHook(remote) then
                hooked += 1
            end
        end
    end

    ZH.Runtime.TargetHooksInstalled = hooked > 0
    if hooked > 0 then
        log("ACTION", "Targeted recorder ready (" .. tostring(hooked) .. " remotes)")
        return true
    end

    log("WARN", "Targeted recorder unsupported by this executor")
    return false
end

--------------------------------------------------------------------------------
-- 10. MACRO PERSISTENCE
--------------------------------------------------------------------------------
local function buildMacroObject(name, actions)
    return {
        format = "ZHMACRO",
        version = 2,
        name = sanitizeName(name),
        createdAt = os.time(),
        actions = actions or {},
    }
end

local function saveMacro(name, actions, forceExactName)
    if type(writefile) ~= "function" then
        log("ERROR", "writefile is unavailable")
        return nil
    end

    local finalName = sanitizeName(name)
    if not forceExactName then
        finalName = uniqueMacroName(finalName)
    end

    local obj = buildMacroObject(finalName, actions)
    local ok, encoded = pcall(HttpService.JSONEncode, HttpService, obj)

    if not ok then
        log("ERROR", "JSON encode failed")
        return nil
    end

    local okWrite, err = pcall(writefile, macroPath(finalName), encoded)
    if not okWrite then
        log("ERROR", "Save failed: " .. tostring(err))
        return nil
    end

    ZH.State.MacroName = finalName
    ZH.State.SelectedMacro = finalName
    log("ACTION", string.format("Saved %s (%d actions)", finalName, #actions))
    return finalName
end

local function readMacro(name)
    if type(readfile) ~= "function" then
        return nil, "readfile unavailable"
    end

    local path = macroPath(name)
    if not fileExists(path) then
        return nil, "macro file not found"
    end

    local okRead, raw = pcall(readfile, path)
    if not okRead then
        return nil, raw
    end

    local okJson, obj = pcall(HttpService.JSONDecode, HttpService, raw)
    if not okJson or type(obj) ~= "table" then
        return nil, "invalid JSON"
    end

    if obj.format ~= "ZHMACRO" or type(obj.actions) ~= "table" then
        return nil, "not a ZH macro"
    end

    return obj
end

local function refreshMacroNames()
    local names = {}

    if type(listfiles) == "function" then
        local ok, files = pcall(listfiles, ZH.Paths.Macros)
        if ok and type(files) == "table" then
            for _, path in ipairs(files) do
                local name = path:match("([^/\\]+)%.json$")
                if name then
                    table.insert(names, name)
                end
            end
        end
    end

    table.sort(names)
    ZH.Runtime.MacroNames = names

    if not ZH.State.SelectedMacro and #names > 0 then
        ZH.State.SelectedMacro = names[1]
    end

    if ZH.UI.RefreshMacroSelect then
        ZH.UI.RefreshMacroSelect()
    end
end

local function loadMacro(name)
    local obj, err = readMacro(name)
    if not obj then
        log("ERROR", "Load failed: " .. tostring(err))
        return false
    end

    ZH.Runtime.LoadedMacro = obj
    ZH.Runtime.Actions = obj.actions or {}
    ZH.State.SelectedMacro = name
    ZH.State.MacroName = obj.name or name

    log("ACTION", string.format("Loaded %s (%d actions)", name, #ZH.Runtime.Actions))
    return true
end

local function deleteMacro(name)
    if not name then return false end
    if type(delfile) ~= "function" then
        log("ERROR", "delfile unavailable")
        return false
    end

    local path = macroPath(name)
    if not fileExists(path) then
        log("WARN", "Macro does not exist: " .. tostring(name))
        return false
    end

    local ok, err = pcall(delfile, path)
    if not ok then
        log("ERROR", "Delete failed: " .. tostring(err))
        return false
    end

    if ZH.State.SelectedMacro == name then
        ZH.State.SelectedMacro = nil
    end

    log("ACTION", "Deleted macro: " .. name)
    refreshMacroNames()
    return true
end

local function renameMacro(oldName, newName)
    newName = sanitizeName(newName)

    if not oldName or oldName == "" then
        log("WARN", "No macro selected")
        return false
    end

    local obj, err = readMacro(oldName)
    if not obj then
        log("ERROR", "Rename load failed: " .. tostring(err))
        return false
    end

    newName = uniqueMacroName(newName)
    obj.name = newName

    local okJson, encoded = pcall(HttpService.JSONEncode, HttpService, obj)
    if not okJson then
        log("ERROR", "Rename encode failed")
        return false
    end

    local okWrite, errWrite = pcall(writefile, macroPath(newName), encoded)
    if not okWrite then
        log("ERROR", "Rename write failed: " .. tostring(errWrite))
        return false
    end

    if type(delfile) == "function" then
        pcall(delfile, macroPath(oldName))
    end

    ZH.State.SelectedMacro = newName
    ZH.State.MacroName = newName
    log("ACTION", oldName .. " -> " .. newName)
    refreshMacroNames()
    return true
end

--------------------------------------------------------------------------------
-- 11. EXPORT / IMPORT
--------------------------------------------------------------------------------
local function exportSelectedMacro()
    local name = ZH.State.SelectedMacro
    if not name then
        return nil, "No macro selected"
    end

    local obj, err = readMacro(name)
    if not obj then
        return nil, err
    end

    -- Export intentionally contains the route/actions only.
    local portable = {
        format = "ZHMACRO",
        version = 2,
        name = obj.name or name,
        actions = obj.actions or {},
    }

    local ok, json = pcall(HttpService.JSONEncode, HttpService, portable)
    if not ok then
        return nil, "encode failed"
    end

    -- Hex keeps the format dependency-free and portable across executors.
    local hex = json:gsub(".", function(c)
        return string.format("%02X", string.byte(c))
    end)

    return "ZHMACRO:2:" .. hex
end

local function fromHex(hex)
    if #hex % 2 ~= 0 then
        return nil
    end

    return (hex:gsub("%x%x", function(cc)
        return string.char(tonumber(cc, 16))
    end))
end

local function importMacroCode(code)
    code = tostring(code or ""):gsub("%s+", "")

    local ver, payload = code:match("^ZHMACRO:(%d+):(.+)$")
    if ver ~= "2" or not payload then
        return false, "Invalid ZHMACRO header"
    end

    local json = fromHex(payload)
    if not json then
        return false, "Invalid payload"
    end

    local ok, obj = pcall(HttpService.JSONDecode, HttpService, json)
    if not ok or type(obj) ~= "table" then
        return false, "Invalid macro JSON"
    end

    if obj.format ~= "ZHMACRO" or type(obj.actions) ~= "table" then
        return false, "Invalid macro object"
    end

    local finalName = saveMacro(obj.name or "ImportedMacro", obj.actions, false)
    if not finalName then
        return false, "Could not save imported macro"
    end

    refreshMacroNames()
    return true, finalName
end

--------------------------------------------------------------------------------
-- 12. RECORD CONTROLS
--------------------------------------------------------------------------------
local function startRecording()
    if ZH.State.IsPlaying then
        log("WARN", "Stop playback before recording")
        return
    end

    ZH.Runtime.Actions = {}
    ZH.Runtime.LastActionKey = nil
    ZH.Runtime.LastActionAt = 0
    ZH.Runtime.RecordedIdToRef = {}
    ZH.Runtime.NextMacroUnitRef = 1

    installRemoteHook()

    ZH.State.IsRecording = true
    ZH.State.IsRecordingPaused = false
    ZH.State.RecordingStartedAt = os.clock()
    ZH.State.RecordingPauseStartedAt = 0
    ZH.State.RecordingPausedTotal = 0

    log("ACTION", "Recording started: " .. sanitizeName(ZH.State.MacroName))
    if ZH.UI.RefreshMacroState then ZH.UI.RefreshMacroState() end
end

local function toggleRecordingPause()
    if not ZH.State.IsRecording then
        log("WARN", "Recorder is not running")
        return
    end

    if ZH.State.IsRecordingPaused then
        local pausedFor = os.clock() - (ZH.State.RecordingPauseStartedAt or os.clock())
        ZH.State.RecordingPausedTotal = (ZH.State.RecordingPausedTotal or 0) + pausedFor
        ZH.State.RecordingPauseStartedAt = 0
        ZH.State.IsRecordingPaused = false
        log("ACTION", "Recording resumed")
    else
        ZH.State.IsRecordingPaused = true
        ZH.State.RecordingPauseStartedAt = os.clock()
        log("ACTION", "Recording paused")
    end

    if ZH.UI.RefreshMacroState then ZH.UI.RefreshMacroState() end
end

local function stopAndSaveRecording()
    if not ZH.State.IsRecording then
        log("WARN", "Recorder is not running")
        return
    end

    if ZH.State.IsRecordingPaused and (ZH.State.RecordingPauseStartedAt or 0) > 0 then
        ZH.State.RecordingPausedTotal = (ZH.State.RecordingPausedTotal or 0)
            + (os.clock() - ZH.State.RecordingPauseStartedAt)
    end

    ZH.State.IsRecording = false
    ZH.State.IsRecordingPaused = false
    ZH.State.RecordingPauseStartedAt = 0

    if #ZH.Runtime.Actions == 0 then
        log("WARN", "No Place/Upgrade/Ability actions were captured")
    end

    local saved = saveMacro(ZH.State.MacroName, ZH.Runtime.Actions, false)
    if saved then
        refreshMacroNames()
        ZH.State.SelectedMacro = saved
        if ZH.UI.NameBox then ZH.UI.NameBox.Text = saved end
        loadMacro(saved)
        log("ACTION", string.format("Macro ready: %s (%d actions)", saved, #ZH.Runtime.Actions))
    end

    log("ACTION", "Recording stopped")
    if ZH.UI.RefreshMacroState then ZH.UI.RefreshMacroState() end
end

--------------------------------------------------------------------------------
-- 13. SMART/HYBRID PLAYBACK
--------------------------------------------------------------------------------
local function waitHybrid(action, startTime)
    local targetTime = tonumber(action.Sync and action.Sync.RelativeTime) or 0

    while ENV.ZoneHubRunning and ZH.State.IsPlaying do
        if (os.clock() - startTime) >= targetTime then
            return true
        end
        task.wait(0.05)
    end

    return false
end

local function resolveRemote(path)
    local direct = findByFullName(path)
    if direct and (direct:IsA("RemoteEvent") or direct:IsA("RemoteFunction")) then
        return direct
    end

    -- Fallback by last segment.
    local last = path and path:match("([^%.]+)$")
    if last then
        return ReplicatedStorage:FindFirstChild(last, true)
    end

    return nil
end

local function runAction(action, index)
    local actionType = action.Type or "Remote"

    if (actionType == "Place" or actionType == "Upgrade" or actionType == "Sell" or actionType == "Target")
       and action.PlayerPosition then
        local cf = decodeValue(action.PlayerPosition)
        if typeof(cf) == "CFrame" then
            local okMove, moveErr = teleportPlayer(cf)
            if not okMove then
                log("WARN", string.format("#%d teleport skipped: %s", index, tostring(moveErr)))
            else
                local root = getRoot()
                local deadline = os.clock() + 1.25
                while root and (root.Position - cf.Position).Magnitude > 5 and os.clock() < deadline do
                    root.CFrame = cf
                    task.wait(0.06)
                end
                log("ACTION", string.format("#%d teleport confirmed", index))
            end
        end
    end

    local remote = resolveRemote(action.RemotePath)
    if not remote then
        log("WARN", string.format("#%d remote missing; action skipped", index))
        return false
    end

    local args = decodeArgs(action.Args or {})

    -- Replace recorded per-round ids with the current match id.
    if actionType == "Upgrade" or actionType == "Ability" or actionType == "Sell" or actionType == "Target" then
        local mapped = action.UnitRef and ZH.Runtime.ReplayUnitMap[action.UnitRef]
        if mapped ~= nil then
            args[1] = mapped
        elseif action.RecordedUnitId ~= nil and ZH.Runtime.ReplayUnitMap[tostring(action.RecordedUnitId)] ~= nil then
            args[1] = ZH.Runtime.ReplayUnitMap[tostring(action.RecordedUnitId)]
        end
    end

    if (actionType == "Upgrade" or actionType == "Ability") and action.UnitRef and ZH.Runtime.ReplayUnitMap[action.UnitRef] == nil then
        log("WARN", string.format("PLAY #%d %s skipped: no current id for %s", index, actionType, tostring(action.UnitRef)))
        return false
    end

    local ok, resultOrErr
    ZH.ReplayGuard = true

    if action.Method == "InvokeServer" and remote:IsA("RemoteFunction") then
        ok, resultOrErr = pcall(function()
            return remote:InvokeServer(unpack(args))
        end)
    elseif remote:IsA("RemoteEvent") then
        ok, resultOrErr = pcall(function()
            remote:FireServer(unpack(args))
            return true
        end)
    elseif remote:IsA("RemoteFunction") then
        ok, resultOrErr = pcall(function()
            return remote:InvokeServer(unpack(args))
        end)
    else
        ok = false
        resultOrErr = "unsupported remote"
    end

    ZH.ReplayGuard = false

    if ok then
        if actionType == "Place" then
            local newId = extractPossibleUnitId({resultOrErr})
            if newId ~= nil then
                if action.UnitRef then
                    ZH.Runtime.ReplayUnitMap[action.UnitRef] = newId
                end
                if action.RecordedUnitId ~= nil then
                    ZH.Runtime.ReplayUnitMap[tostring(action.RecordedUnitId)] = newId
                end
                log("ACTION", "Mapped " .. tostring(action.UnitRef or action.RecordedUnitId) .. " -> " .. tostring(newId))
            else
                log("WARN", "Place succeeded but returned no unit id; later upgrades may be skipped")
            end
        end

        log("ACTION", string.format("PLAY #%d %s", index, actionType))
    else
        log("WARN", string.format("PLAY #%d skipped: %s", index, tostring(resultOrErr)))
    end

    return ok
end

local function playLoadedMacro()
    if ZH.State.IsRecording or ZH.State.IsPlaying then
        return false
    end

    local obj = ZH.Runtime.LoadedMacro

    if not obj and ZH.State.SelectedMacro then
        if not loadMacro(ZH.State.SelectedMacro) then
            return false
        end
        obj = ZH.Runtime.LoadedMacro
    end

    if not obj or type(obj.actions) ~= "table" or #obj.actions == 0 then
        log("WARN", "No loaded macro to play")
        return false
    end

    ZH.State.IsPlaying = true
    ZH.Runtime.ReplayUnitMap = {}
    local startTime = os.clock()

    log("ACTION", string.format("Playback started: %s (%d actions)", obj.name or "Macro", #obj.actions))
    if #obj.actions == 0 then
        log("WARN", "Loaded macro has 0 actions")
    end

    for i, action in ipairs(obj.actions) do
        if not ENV.ZoneHubRunning or not ZH.State.IsPlaying then
            break
        end

        if waitHybrid(action, startTime) then
            runAction(action, i)
        else
            break
        end
    end

    ZH.State.IsPlaying = false
    log("ACTION", "Playback finished")
    return true
end

--------------------------------------------------------------------------------
-- 14. MATCH DETECTION / AUTO PLAY LOOP
--------------------------------------------------------------------------------
local MatchGuiCache = {
    LastScan = 0,
    Hud = false,
    Ended = false,
}

local function refreshMatchGuiCache()
    local now = os.clock()
    if now - MatchGuiCache.LastScan < 1.25 then
        return
    end
    MatchGuiCache.LastScan = now

    MatchGuiCache.Hud =
        findButton({ "x1", "x2", "x3", "Game Speed", "Auto Skip" }) ~= nil

    MatchGuiCache.Ended =
        findButton({ "Play Again", "Replay", "Continue", "Next Match" }) ~= nil
end

local function hasMatchHud()
    refreshMatchGuiCache()
    return MatchGuiCache.Hud
end

local function hasEndScreen()
    refreshMatchGuiCache()
    return MatchGuiCache.Ended
end

local function clickEndContinue()
    local now = os.clock()
    if now - ZH.Runtime.LastEndClick < 3 then
        return false
    end

    local btn = findButton({ "Play Again", "Replay", "Continue", "Next Match" })
    if not btn then
        return false
    end

    ZH.Runtime.LastEndClick = now

    if clickButton(btn) then
        log("ACTION", "End-of-match continue button pressed")
        return true
    end

    return false
end

task.spawn(function()
    local wasHud = false

    while ENV.ZoneHubRunning do
        parseWave()

        local hud = hasMatchHud()
        local endScreen = hasEndScreen()

        if hud and not wasHud then
            ZH.RoundToken += 1
            local thisRound = ZH.RoundToken

            log("ACTION", "New match detected #" .. thisRound)
            task.spawn(function()
                task.wait(0.8)

                if not ENV.ZoneHubRunning or ZH.RoundToken ~= thisRound then
                    return
                end

                applyRoundOptionsOnce()

                if ZH.State.AutoPlayMacro then
                    task.wait(0.35)
                    playLoadedMacro()
                end
            end)
        end

        if ZH.State.AutoPlayMacro and endScreen then
            if clickEndContinue() then
                task.wait(0.8)
                selectConfiguredMapAndLevel()
            end
        end

        wasHud = hud
        task.wait(1.5)
    end
end)

--------------------------------------------------------------------------------
-- 14.5 ANTI-AFK
--------------------------------------------------------------------------------
connect(LocalPlayer.Idled, function()
    if not ZH.State.AntiAFK then return end

    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        task.wait(0.12)
        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    end)

    log("ACTION", "Anti-AFK pulse")
end)

--------------------------------------------------------------------------------
-- 15. CONFIG
--------------------------------------------------------------------------------
local function saveConfig()
    if type(writefile) ~= "function" then return end

    local data = {
        SelectedMap = ZH.State.SelectedMap,
        SelectedLevel = ZH.State.SelectedLevel,
        Speed = ZH.State.Speed,
        AutoSkip = ZH.State.AutoSkip,
        AntiAFK = ZH.State.AntiAFK,
        ThemeName = ZH.State.ThemeName,
        AutoPlayMacro = ZH.State.AutoPlayMacro,
        SelectedMacro = ZH.State.SelectedMacro,
        MacroName = ZH.State.MacroName,
    }

    local ok, raw = pcall(HttpService.JSONEncode, HttpService, data)
    if ok then
        pcall(writefile, ZH.Paths.Config, raw)
    end
end

local function loadConfig()
    if type(readfile) ~= "function" or not fileExists(ZH.Paths.Config) then
        return
    end

    local okRead, raw = pcall(readfile, ZH.Paths.Config)
    if not okRead then return end

    local okJson, data = pcall(HttpService.JSONDecode, HttpService, raw)
    if not okJson or type(data) ~= "table" then return end

    for k, v in pairs(data) do
        if ZH.State[k] ~= nil then
            ZH.State[k] = v
        end
    end

    clampSelectedLevel()
end

loadConfig()
do
    local preset = ZH.Themes[ZH.State.ThemeName]
    if preset then
        for k,v in pairs(preset) do ZH.Theme[k] = v end
    end
end
refreshMacroNames()

--------------------------------------------------------------------------------
-- 16. UI HELPERS
--------------------------------------------------------------------------------
local function New(className, props, parent)
    local x = Instance.new(className)
    for k, v in pairs(props or {}) do
        x[k] = v
    end
    if parent then
        x.Parent = parent
    end
    return x
end

local function round(obj, px)
    New("UICorner", { CornerRadius = UDim.new(0, px or 8) }, obj)
end

local function stroke(obj)
    New("UIStroke", {
        Color = ZH.Theme.Border,
        Thickness = 1,
        Transparency = 0.15
    }, obj)
end

local function makeButton(parent, text, callback, width)
    local b = New("TextButton", {
        Size = UDim2.new(width or 1, 0, 0, 34),
        BackgroundColor3 = ZH.Theme.Card2,
        Text = text,
        TextColor3 = ZH.Theme.Text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
        AutoButtonColor = true,
    }, parent)
    round(b, 7)
    stroke(b)
    connect(b.MouseButton1Click, callback)
    return b
end

local function makeLabel(parent, text, size)
    return New("TextLabel", {
        Size = UDim2.new(1, 0, 0, size or 18),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = ZH.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
    }, parent)
end

local function makeSection(parent, title)
    local frame = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = ZH.Theme.Card,
        BorderSizePixel = 0,
    }, parent)

    round(frame, 9)
    stroke(frame)

    New("UIPadding", {
        PaddingTop = UDim.new(0, 9),
        PaddingBottom = UDim.new(0, 9),
        PaddingLeft = UDim.new(0, 9),
        PaddingRight = UDim.new(0, 9),
    }, frame)

    New("UIListLayout", {
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, frame)

    local titleLabel = makeLabel(frame, title, 20)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextColor3 = ZH.Theme.Accent

    return frame
end

local function makeToggle(parent, label, getter, setter)
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
    }, parent)

    local lab = New("TextLabel", {
        Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = ZH.Theme.Text,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local b = New("TextButton", {
        Size = UDim2.new(0, 64, 0, 28),
        Position = UDim2.new(1, -64, 0.5, -14),
        BackgroundColor3 = ZH.Theme.Card2,
        TextColor3 = ZH.Theme.Text,
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        BorderSizePixel = 0,
    }, row)
    round(b, 7)
    stroke(b)

    local function refresh()
        local on = getter()
        b.Text = on and "ON" or "OFF"
        b.BackgroundColor3 = on and ZH.Theme.Good or ZH.Theme.Card2
    end

    connect(b.MouseButton1Click, function()
        setter(not getter())
        refresh()
        saveConfig()
    end)

    refresh()
    return row, refresh
end

local function makeTextInput(parent, placeholder, initial, onChanged, height)
    local box = New("TextBox", {
        Size = UDim2.new(1, 0, 0, height or 34),
        BackgroundColor3 = ZH.Theme.Card2,
        Text = initial or "",
        PlaceholderText = placeholder or "",
        TextColor3 = ZH.Theme.Text,
        PlaceholderColor3 = ZH.Theme.Sub,
        TextSize = 12,
        Font = Enum.Font.Gotham,
        ClearTextOnFocus = false,
        BorderSizePixel = 0,
        MultiLine = (height or 34) > 40,
        TextWrapped = (height or 34) > 40,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
    }, parent)
    round(box, 7)
    stroke(box)

    connect(box.FocusLost, function()
        if onChanged then
            onChanged(box.Text)
        end
    end)

    return box
end

local function makeCycle(parent, labelText, getOptions, getter, setter)
    local row = New("Frame", {
        Size = UDim2.new(1, 0, 0, 58),
        BackgroundTransparency = 1,
    }, parent)

    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = ZH.Theme.Sub,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.new(0, 0, 0, 22),
        BackgroundColor3 = ZH.Theme.Card2,
        TextColor3 = ZH.Theme.Text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        BorderSizePixel = 0,
    }, row)
    round(b, 7)
    stroke(b)

    local function refresh()
        b.Text = tostring(getter()) .. "  ▼"
    end

    connect(b.MouseButton1Click, function()
        local options = getOptions()
        if #options == 0 then return end

        local current = tostring(getter())
        local idx = 1

        for i, opt in ipairs(options) do
            if tostring(opt) == current then
                idx = i
                break
            end
        end

        idx = (idx % #options) + 1
        setter(options[idx])
        refresh()
        saveConfig()
    end)

    refresh()
    return row, refresh
end

--------------------------------------------------------------------------------
-- 17. BUILD RESPONSIVE UI
--------------------------------------------------------------------------------
local oldGui = ParentGui:FindFirstChild("ZoneHub_GTD_V3")
if oldGui then
    oldGui:Destroy()
end

local gui = New("ScreenGui", {
    Name = "ZoneHub_GTD_V3",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset = false,
}, ParentGui)

ZH.UI.Gui = gui

local cam = workspace.CurrentCamera
local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
local mobile = vp.X < 820

local w = mobile and math.min(math.max(310, vp.X - 20), 620) or 760
local h = mobile and math.min(math.max(380, vp.Y - 60), 650) or 520

local main = New("Frame", {
    Size = UDim2.fromOffset(w, h),
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = ZH.Theme.Bg,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, gui)

round(main, 12)
stroke(main)

local header = New("Frame", {
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundColor3 = ZH.Theme.Card,
    BorderSizePixel = 0,
    Active = true,
}, main)

local title = New("TextLabel", {
    Size = UDim2.new(1, -90, 1, 0),
    Position = UDim2.new(0, 12, 0, 0),
    BackgroundTransparency = 1,
    Text = "ZONE HUB GTD  •  MACRO v" .. ZH.Version,
    TextColor3 = ZH.Theme.Text,
    TextSize = 14,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local closeBtn = New("TextButton", {
    Size = UDim2.fromOffset(32, 28),
    Position = UDim2.new(1, -38, 0.5, -14),
    BackgroundColor3 = ZH.Theme.Bad,
    Text = "×",
    TextColor3 = ZH.Theme.Text,
    TextSize = 18,
    Font = Enum.Font.GothamBold,
    BorderSizePixel = 0,
}, header)
round(closeBtn, 7)

local floatBtn = New("TextButton", {
    Size = UDim2.fromOffset(58, 42),
    Position = UDim2.new(0, 10, 0.5, -22),
    BackgroundColor3 = ZH.Theme.Bg,
    Text = "SKL",
    TextColor3 = ZH.Theme.Accent,
    TextSize = 14,
    Font = Enum.Font.GothamBlack,
    BorderSizePixel = 0,
    Visible = false,
}, gui)
round(floatBtn, 22)
stroke(floatBtn)

connect(closeBtn.MouseButton1Click, function()
    main.Visible = false
    floatBtn.Visible = true
end)

connect(floatBtn.MouseButton1Click, function()
    main.Visible = true
    floatBtn.Visible = false
end)

-- Floating SKL button can be dragged anywhere.
do
    local dragging = false
    local moved = false
    local dragStart
    local startPos

    connect(floatBtn.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = floatBtn.Position
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch
        ) then
            local d = input.Position - dragStart
            if d.Magnitude > 4 then moved = true end
            floatBtn.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseButton1 or
            input.UserInputType == Enum.UserInputType.Touch
        ) then
            dragging = false
        end
    end)
end

-- Drag main window.
do
    local dragging = false
    local dragStart
    local startPos

    connect(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

local content = New("ScrollingFrame", {
    Size = UDim2.new(1, -16, 1, -54),
    Position = UDim2.new(0, 8, 0, 48),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.fromOffset(0, 0),
}, main)

New("UIListLayout", {
    Padding = UDim.new(0, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, content)


local function openChoicePopup(anchor, titleText, options, onSelect)
    local old = gui:FindFirstChild("SKL_ChoicePopup")
    if old then old:Destroy() end

    local popup = New("Frame", {
        Name = "SKL_ChoicePopup",
        Size = UDim2.fromOffset(math.min(360, w - 30), math.min(360, h - 40)),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = ZH.Theme.Card,
        BorderSizePixel = 0,
        ZIndex = 50,
    }, gui)
    round(popup, 10)
    stroke(popup)

    New("TextLabel", {
        Size = UDim2.new(1, -50, 0, 38),
        Position = UDim2.fromOffset(12, 4),
        BackgroundTransparency = 1,
        Text = titleText,
        TextColor3 = ZH.Theme.Text,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 51,
    }, popup)

    local close = New("TextButton", {
        Size = UDim2.fromOffset(32, 28),
        Position = UDim2.new(1, -38, 0, 8),
        BackgroundColor3 = ZH.Theme.Bad,
        BorderSizePixel = 0,
        Text = "×",
        TextColor3 = ZH.Theme.Text,
        TextSize = 17,
        Font = Enum.Font.GothamBold,
        ZIndex = 52,
    }, popup)
    round(close, 7)
    connect(close.MouseButton1Click, function() popup:Destroy() end)

    local list = New("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -50),
        Position = UDim2.fromOffset(8, 44),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 3,
        ZIndex = 51,
    }, popup)
    New("UIListLayout", {Padding=UDim.new(0,5)}, list)

    for _, value in ipairs(options) do
        local item = makeButton(list, tostring(value), function()
            onSelect(value)
            popup:Destroy()
        end)
        item.ZIndex = 52
    end
end

local function applyTheme(name)
    local preset = ZH.Themes[name]
    if not preset then return end
    ZH.State.ThemeName = name
    for k,v in pairs(preset) do ZH.Theme[k] = v end

    -- Rebuild on next execution for a fully consistent theme.
    saveConfig()
    log("ACTION", "Theme selected: " .. name .. " (reopen/reload to apply everywhere)")
end

--------------------------------------------------------------------------------
-- 18. TABBED UI
--------------------------------------------------------------------------------
-- Remove the old vertical content layout and replace it with lazy tabs.
content.Visible = false

local tabBar = New("Frame", {
    Size = UDim2.new(1, -16, 0, 38),
    Position = UDim2.new(0, 8, 0, 48),
    BackgroundTransparency = 1,
}, main)

New("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, tabBar)

local tabHost = New("Frame", {
    Size = UDim2.new(1, -16, 1, -98),
    Position = UDim2.new(0, 8, 0, 92),
    BackgroundTransparency = 1,
}, main)

local tabPages = {}
local tabButtons = {}
local builtTabs = {}

for _, tabName in ipairs({ "Macro", "Match", "Settings" }) do
    local b = makeButton(tabBar, tabName, function() end)
    b.Size = UDim2.new(0, mobile and 90 or 120, 0, 34)
    tabButtons[tabName] = b

    tabPages[tabName] = New("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
    }, tabHost)
end

local function buildMacroTab(page)
    if builtTabs.Macro then return end
    builtTabs.Macro = true

    local controlsParent, consoleParent, shareParent

    if mobile then
        local scroll = New("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarThickness = 3,
        }, page)
        New("UIListLayout", { Padding = UDim.new(0, 10) }, scroll)

        controlsParent = makeSection(scroll, "Macro")
        consoleParent = makeSection(scroll, "Console")
        shareParent = makeSection(scroll, "Share")
    else
        local left = New("Frame", {
            Size = UDim2.new(0.48, 0, 1, 0),
            BackgroundTransparency = 1,
        }, page)

        local right = New("Frame", {
            Size = UDim2.new(0.50, 0, 1, 0),
            Position = UDim2.new(0.50, 0, 0, 0),
            BackgroundTransparency = 1,
        }, page)

        controlsParent = makeSection(left, "Macro")
        controlsParent.Size = UDim2.new(1, 0, 1, 0)
        controlsParent.AutomaticSize = Enum.AutomaticSize.None

        consoleParent = makeSection(right, "Console")
        consoleParent.Size = UDim2.new(1, 0, 0.49, 0)
        consoleParent.AutomaticSize = Enum.AutomaticSize.None

        shareParent = makeSection(right, "Share")
        shareParent.Size = UDim2.new(1, 0, 0.49, 0)
        shareParent.Position = UDim2.new(0, 0, 0.51, 0)
        shareParent.AutomaticSize = Enum.AutomaticSize.None
    end

    makeLabel(controlsParent, "1. Macro name", 18)

    local nameBox = makeTextInput(
        controlsParent,
        "Macro name",
        ZH.State.MacroName,
        function(text)
            ZH.State.MacroName = sanitizeName(text)
            saveConfig()
        end
    )
    ZH.UI.NameBox = nameBox

    local selectLabel = makeLabel(
        controlsParent,
        "Saved: " .. tostring(ZH.State.SelectedMacro or "none"),
        20
    )
    selectLabel.Font = Enum.Font.GothamBold

    local selectBtn = makeButton(controlsParent, "Select Macro  ▼", function()
        refreshMacroNames()
        local names = ZH.Runtime.MacroNames

        if #names == 0 then
            ZH.State.SelectedMacro = nil
            selectLabel.Text = "Saved: none"
            return
        end

        local idx = 0
        for i, n in ipairs(names) do
            if n == ZH.State.SelectedMacro then
                idx = i
                break
            end
        end

        idx = (idx % #names) + 1
        ZH.State.SelectedMacro = names[idx]
        selectLabel.Text = "Saved: " .. names[idx]
        saveConfig()
    end)

    ZH.UI.RefreshMacroSelect = function()
        selectLabel.Text = "Saved: " .. tostring(ZH.State.SelectedMacro or "none")
    end

    makeButton(controlsParent, "2. Start Recording", startRecording)

    local pauseBtn = makeButton(controlsParent, "3. Pause", toggleRecordingPause)
    ZH.UI.PauseButton = pauseBtn

    makeButton(controlsParent, "4. Save & Stop", stopAndSaveRecording)

    makeButton(controlsParent, "5. Load", function()
        if ZH.State.SelectedMacro then
            loadMacro(ZH.State.SelectedMacro)
        else
            log("WARN", "No macro selected")
        end
    end)

    makeButton(controlsParent, "▶ Play Now", function()
        if ZH.State.IsRecording then
            log("WARN", "Stop recording before playback")
            return
        end

        if not ZH.Runtime.LoadedMacro and ZH.State.SelectedMacro then
            loadMacro(ZH.State.SelectedMacro)
        end

        task.spawn(function()
            local ok = playLoadedMacro()
            if not ok then
                log("WARN", "Playback did not start")
            end
        end)
    end)

    local deleteBtn
    deleteBtn = makeButton(controlsParent, "6. Delete", function()
        local name = ZH.State.SelectedMacro
        if not name then
            log("WARN", "No macro selected")
            return
        end

        local now = os.clock()
        if now > (ZH.Runtime.DeleteConfirmUntil or 0) then
            ZH.Runtime.DeleteConfirmUntil = now + 3
            deleteBtn.Text = "6. CONFIRM DELETE"
            log("WARN", "Press Delete again within 3 seconds to confirm: " .. name)

            task.delay(3, function()
                if deleteBtn and os.clock() > (ZH.Runtime.DeleteConfirmUntil or 0) then
                    deleteBtn.Text = "6. Delete"
                end
            end)
            return
        end

        deleteBtn.Text = "6. Delete"
        ZH.Runtime.DeleteConfirmUntil = 0
        deleteMacro(name)
    end)
    deleteBtn.BackgroundColor3 = ZH.Theme.Bad
    ZH.UI.DeleteButton = deleteBtn

    makeToggle(
        controlsParent,
        "Auto Play Macro",
        function() return ZH.State.AutoPlayMacro end,
        function(v)
            ZH.State.AutoPlayMacro = v
            if v and ZH.State.SelectedMacro then
                loadMacro(ZH.State.SelectedMacro)
            end
            log("ACTION", "Auto Play Macro -> " .. (v and "ON" or "OFF"))
        end
    )

    local statusLabel = makeLabel(controlsParent, "Status: Idle", 20)
    statusLabel.Font = Enum.Font.GothamBold

    ZH.UI.RefreshMacroState = function()
        if ZH.State.IsRecording then
            if ZH.State.IsRecordingPaused then
                pauseBtn.Text = "3. Resume"
                statusLabel.Text = "Status: Recording Paused"
                statusLabel.TextColor3 = ZH.Theme.Warn
            else
                pauseBtn.Text = "3. Pause"
                statusLabel.Text = "Status: Recording"
                statusLabel.TextColor3 = ZH.Theme.Good
            end
        elseif ZH.State.IsPlaying then
            pauseBtn.Text = "3. Pause"
            statusLabel.Text = "Status: Playing"
            statusLabel.TextColor3 = ZH.Theme.Accent
        else
            pauseBtn.Text = "3. Pause"
            statusLabel.Text = "Status: Idle"
            statusLabel.TextColor3 = ZH.Theme.Text
        end
    end
    ZH.UI.RefreshMacroState()

    -- Console: newest messages appear at the top.
    local consoleBox = New("TextLabel", {
        Size = UDim2.new(1, 0, 1, -72),
        BackgroundColor3 = Color3.fromRGB(10, 9, 13),
        BorderSizePixel = 0,
        Text = "",
        TextColor3 = ZH.Theme.Text,
        TextSize = 11,
        Font = Enum.Font.Code,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = false,
    }, consoleParent)
    round(consoleBox, 7)
    stroke(consoleBox)

    ZH.UI.RefreshConsole = function()
        local lines = {}
        local maxRows = mobile and 12 or 15

        for i = 1, math.min(#ZH.Runtime.Console, maxRows) do
            local row = ZH.Runtime.Console[i]
            table.insert(lines, string.format(
                "[%s] [%s] %s",
                row.t,
                row.level,
                row.text
            ))
        end

        consoleBox.Text = table.concat(lines, "\n")
    end

    local clearBtn = makeButton(consoleParent, "Clear Console", function()
        ZH.Runtime.Console = {}
        ZH.UI.RefreshConsole()
    end)
    clearBtn.Size = UDim2.new(1, 0, 0, 32)

    ZH.UI.RefreshConsole()

    -- Share area.
    local exportBox = makeTextInput(
        shareParent,
        "Export code",
        "",
        nil,
        mobile and 70 or 58
    )

    makeButton(shareParent, "Export Selected", function()
        local code, err = exportSelectedMacro()
        if not code then
            log("ERROR", "Export failed: " .. tostring(err))
            return
        end

        exportBox.Text = code
        if type(setclipboard) == "function" then
            pcall(setclipboard, code)
            safeNotify("Zone Hub", "Macro copied")
        end
        log("ACTION", "Export ready")
    end)

    local importBox = makeTextInput(
        shareParent,
        "Paste ZHMACRO code",
        "",
        nil,
        mobile and 70 or 58
    )

    makeButton(shareParent, "Import", function()
        local ok, result = importMacroCode(importBox.Text)
        if ok then
            importBox.Text = ""
            refreshMacroNames()
            log("ACTION", "Imported macro: " .. tostring(result))
        else
            log("ERROR", "Import failed: " .. tostring(result))
        end
    end)
end

local function buildMatchTab(page)
    if builtTabs.Match then return end
    builtTabs.Match = true

    local scroll = New("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 3,
    }, page)
    New("UIListLayout", { Padding = UDim.new(0, 10) }, scroll)

    local matchSection = makeSection(scroll, "Match")

    makeLabel(matchSection, "Map", 18)
    local mapBtn
    mapBtn = makeButton(matchSection, tostring(ZH.State.SelectedMap) .. "  ▼", function()
        local options = collectGameChoices("map")
        openChoicePopup(mapBtn, "Select Map", options, function(v)
            ZH.State.SelectedMap = tostring(v)
            mapBtn.Text = tostring(v) .. "  ▼"
            saveConfig()
        end)
    end)

    makeLabel(matchSection, "Level / Difficulty", 18)
    local levelBtn
    levelBtn = makeButton(matchSection, tostring(ZH.State.SelectedLevel) .. "  ▼", function()
        local options = collectGameChoices("level")
        openChoicePopup(levelBtn, "Select Level / Difficulty", options, function(v)
            local n = tonumber(tostring(v):match("%d+"))
            ZH.State.SelectedLevel = n or v
            levelBtn.Text = tostring(v) .. "  ▼"
            saveConfig()
        end)
    end)

    makeLabel(matchSection, "Game Speed", 18)

    local speedRow = New("Frame", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundTransparency = 1,
    }, matchSection)

    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
    }, speedRow)

    local speedBtns = {}
    local function refreshSpeedButtons()
        for speed, b in pairs(speedBtns) do
            b.BackgroundColor3 =
                (speed == ZH.State.Speed) and ZH.Theme.Accent or ZH.Theme.Card2
        end
    end

    for _, speed in ipairs({ "x1", "x2", "x3" }) do
        local b = makeButton(speedRow, speed, function()
            ZH.State.Speed = speed
            refreshSpeedButtons()
            saveConfig()
            task.spawn(applyGameSpeed)
        end)
        b.Size = UDim2.new(0.31, 0, 0, 34)
        speedBtns[speed] = b
    end
    refreshSpeedButtons()

    makeToggle(
        matchSection,
        "Auto Skip",
        function() return ZH.State.AutoSkip end,
        function(v)
            ZH.State.AutoSkip = v
            task.spawn(applyAutoSkip)
        end
    )

    makeToggle(
        matchSection,
        "Anti AFK",
        function() return ZH.State.AntiAFK end,
        function(v)
            ZH.State.AntiAFK = v
            log("ACTION", "Anti AFK -> " .. (v and "ON" or "OFF"))
        end
    )
end

local function buildSettingsTab(page)
    if builtTabs.Settings then return end
    builtTabs.Settings = true

    local scroll = New("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollBarThickness = 3,
    }, page)
    New("UIListLayout", { Padding = UDim.new(0, 10) }, scroll)

    local settings = makeSection(scroll, "Settings")

    makeLabel(settings, "Interface Theme", 18)
    local themeBtn
    themeBtn = makeButton(settings, tostring(ZH.State.ThemeName or "Pink / Purple") .. "  ▼", function()
        local options = {"Pink / Purple","Blue / Yellow","White / Black","Green / Black"}
        openChoicePopup(themeBtn, "Select Theme", options, function(v)
            applyTheme(v)
            themeBtn.Text = tostring(v) .. "  ▼"
        end)
    end)

    makeToggle(
        settings,
        "Diagnostic Mode",
        function() return ZH.State.DiagnosticCapture end,
        function(v)
            ZH.State.DiagnosticCapture = v
            log("ACTION", "Diagnostic Mode -> " .. (v and "ON" or "OFF") .. " (no global remote hook in v6)")
        end
    )

    local info = makeLabel(
        settings,
        "v7 does not use a global __namecall hook. Recording targets only PlaceUnit, UpgradeUnit "
        .. "and ability-like remotes to reduce lag and avoid blocking plant placement.",
        48
    )
    info.TextWrapped = true
    info.TextColor3 = ZH.Theme.Sub

    local unload = makeButton(settings, "Unload Zone Hub", function()
        if ENV.ZoneHubUnload then ENV.ZoneHubUnload() end
    end)
    unload.BackgroundColor3 = ZH.Theme.Bad
end

local builders = {
    Macro = buildMacroTab,
    Match = buildMatchTab,
    Settings = buildSettingsTab,
}

local function openTab(name)
    for tabName, page in pairs(tabPages) do
        page.Visible = (tabName == name)
        tabButtons[tabName].BackgroundColor3 =
            (tabName == name) and ZH.Theme.Accent or ZH.Theme.Card2
    end

    builders[name](tabPages[name])
end

for tabName, btn in pairs(tabButtons) do
    connect(btn.MouseButton1Click, function()
        openTab(tabName)
    end)
end

openTab("Macro")

task.spawn(function()
    while ENV.ZoneHubRunning do
        if ZH.UI.RefreshMacroState then
            ZH.UI.RefreshMacroState()
        end
        task.wait(0.4)
    end
end)

--------------------------------------------------------------------------------
-- 22. INITIALIZATION / UNLOAD
--------------------------------------------------------------------------------
refreshMacroNames()
saveConfig()

log("ACTION", "Zone Hub GTD v" .. ZH.Version .. " initialized")
log("ACTION", "v8 ready: own GUI excluded from game detection; manual Play Now added")

ENV.ZoneHubUnload = function()
    ENV.ZoneHubRunning = false
    ENV.ZoneHubLoaded = false

    ZH.State.IsRecording = false
    ZH.State.IsRecordingPaused = false
    ZH.State.IsPlaying = false

    saveConfig()

    for _, c in ipairs(ZH.Connections) do
        pcall(function()
            c:Disconnect()
        end)
    end

    if ZH.UI.Gui then
        pcall(function()
            ZH.UI.Gui:Destroy()
        end)
    end
end

safeNotify("Zone Hub GTD", "Macro engine v" .. ZH.Version .. " loaded")
