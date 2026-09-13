--[[
    ================================================================================
    GARDEN HUB - Single-File Architecture (v1.1.0)
    Target Game: Garden Tower Defense (GameId: 7703614594)
    Designed for Mobile (Delta, Codex, Hydrogen) & Desktop Executors
    ================================================================================
--]]

-- Suppress duplicate executions cleanly
if getgenv().GardenHubLoaded then
    if typeof(getgenv().GardenHubUnload) == "function" then
        pcall(getgenv().GardenHubUnload)
    end
end
getgenv().GardenHubLoaded = true

--------------------------------------------------------------------------------
-- SERVICES & EXECUTOR ENVIRONMENT
--------------------------------------------------------------------------------
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Helper to safely mount ScreenGui
local ParentGui = CoreGui
local successParent = pcall(function()
    local test = Instance.new("Folder")
    test.Parent = CoreGui
    test:Destroy()
end)
if not successParent then
    ParentGui = PlayerGui
end

--------------------------------------------------------------------------------
-- 1. BASE64 / SHARE CODE UTILITIES
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 1. BASE64 / SHARE CODE UTILITIES
--------------------------------------------------------------------------------
local Base64 = {}
local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function Base64.Encode(data)
    return ((data:gsub('.', function(x) 
        local r, b = '', x:byte()
        for i = 8, 1, -1 do r = r .. (b % 2^i - b % 2^(i-1) > 0 and '1' or '0') end
        return r
    end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c = 0
        for i = 1, 6 do c = c + (x:sub(i,i) == '1' and 2^(6-i) or 0) end
        return b64chars:sub(c+1, c+1)
    end) .. ({ '', '==', '=' })[#data % 3 + 1])
end

function Base64.Decode(data)
    data = string.gsub(data, '[^'..b64chars..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r, f = '', (b64chars:find(x) - 1)
        for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
        return r
    end):gsub('%d%d%d%d%d%d%d%d', function(x)
        local c = 0
        for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

--------------------------------------------------------------------------------
-- 2. CORE MODULES (Config, Logger, State, GameDetector)
--------------------------------------------------------------------------------

-- Config Module
local Config = {
    Version = "1.1.0-alpha",
    TargetGameId = 7703614594,
    TargetGameName = "Garden Tower Defense",
    IgnoreGameIdCheck = false,
    DefaultTickSpeed = 20,
    TickSpeeds = { 10, 20, 60 },
    DefaultReplayMode = "By Cash",
    ReplayModes = { "By Cash", "By Time" },
    Theme = {
        Background = Color3.fromRGB(14, 14, 18),
        Surface    = Color3.fromRGB(22, 22, 34),
        Card       = Color3.fromRGB(31, 31, 48),
        Border     = Color3.fromRGB(45, 45, 68),
        Accent     = Color3.fromRGB(0, 162, 255),
        AccentHover= Color3.fromRGB(59, 130, 246),
        Text       = Color3.fromRGB(255, 255, 255),
        SubText    = Color3.fromRGB(148, 163, 184),
        Success    = Color3.fromRGB(16, 185, 129),
        Danger     = Color3.fromRGB(239, 68, 68),
        Warning    = Color3.fromRGB(245, 158, 11),
    }
}

-- Logger Module
local Logger = {}
Logger.History = {}
Logger.OnLog = nil

function Logger.Log(level, message)
    local timestamp = os.date("%H:%M:%S")
    local entry = string.format("[%s] [%s] %s", timestamp, level, tostring(message))
    table.insert(Logger.History, entry)
    if #Logger.History > 100 then
        table.remove(Logger.History, 1)
    end
    print("[GardenHub] " .. entry)
    if Logger.OnLog then
        pcall(Logger.OnLog, entry, level, message)
    end
end

function Logger.Info(msg) Logger.Log("INFO", msg) end
function Logger.Warn(msg) Logger.Log("WARN", msg) end
function Logger.Error(msg) Logger.Log("ERROR", msg) end

-- State Store Module (Reactive Pub/Sub)
local State = {}
local _stateData = {
    isRecording = false,
    isPlaying = false,
    isPaused = false,
    farmModeEnabled = false,
    autoSkipWave = false,
    autoReplay = false,
    autoSell = false,
    tickSpeed = Config.DefaultTickSpeed,
    replayMode = Config.DefaultReplayMode,
    activeMacroName = nil,
    macrosList = {},
    macroStatus = "Idle",
    cash = 0,
    wave = 0
}
local _subscribers = {}

function State.Get(key)
    return _stateData[key]
end

function State.Set(key, value)
    if _stateData[key] == value then return end
    _stateData[key] = value
    if _subscribers[key] then
        for _, callback in ipairs(_subscribers[key]) do
            task.spawn(callback, value)
        end
    end
end

function State.Subscribe(key, callback)
    if not _subscribers[key] then
        _subscribers[key] = {}
    end
    table.insert(_subscribers[key], callback)
    callback(_stateData[key])
    return function()
        for i, cb in ipairs(_subscribers[key]) do
            if cb == callback then
                table.remove(_subscribers[key], i)
                break
            end
        end
    end
end

-- Game Detector Module
local GameDetector = {}
function GameDetector.Validate()
    local currentGameId = game.GameId
    local isValid = (currentGameId == Config.TargetGameId) or Config.IgnoreGameIdCheck
    return isValid, currentGameId, Config.TargetGameName
end

--------------------------------------------------------------------------------
-- 3. STORAGE MODULES (MacroStorage, SettingsStorage)
--------------------------------------------------------------------------------

local StorageProvider = {}
StorageProvider.HasFS = (type(readfile) == "function" and type(writefile) == "function" and type(isfolder) == "function" and type(makefolder) == "function")
StorageProvider.MemoryStore = {
    macros = {},
    settings = {}
}

if StorageProvider.HasFS then
    pcall(function()
        if not isfolder("GardenHub") then makefolder("GardenHub") end
        if not isfolder("GardenHub/macros") then makefolder("GardenHub/macros") end
    end)
end

-- MacroStorage
local MacroStorage = {}

function MacroStorage.Save(macroData)
    if not macroData or not macroData.name then return false, "Invalid macro" end
    macroData.updatedAt = os.time()
    local jsonStr = HttpService:JSONEncode(macroData)
    
    if StorageProvider.HasFS then
        local filename = "GardenHub/macros/" .. macroData.name:gsub("[^%w%s_]", "") .. ".json"
        local success, err = pcall(function() writefile(filename, jsonStr) end)
        if success then return true end
        Logger.Warn("FS write failed, falling back to memory: " .. tostring(err))
    end
    StorageProvider.MemoryStore.macros[macroData.name] = jsonStr
    return true
end

function MacroStorage.LoadAll()
    local macros = {}
    if StorageProvider.HasFS then
        local success, files = pcall(function() return listfiles("GardenHub/macros") end)
        if success and files then
            for _, filePath in ipairs(files) do
                if filePath:sub(-5) == ".json" then
                    pcall(function()
                        local content = readfile(filePath)
                        local data = HttpService:JSONDecode(content)
                        if data and data.name then
                            macros[data.name] = data
                        end
                    end)
                end
            end
        end
    end
    -- Merge memory store
    for name, jsonStr in pairs(StorageProvider.MemoryStore.macros) do
        if not macros[name] then
            pcall(function()
                local data = HttpService:JSONDecode(jsonStr)
                if data then macros[name] = data end
            end)
        end
    end
    return macros
end

function MacroStorage.Delete(macroName)
    if StorageProvider.HasFS then
        local filename = "GardenHub/macros/" .. macroName:gsub("[^%w%s_]", "") .. ".json"
        pcall(function() if delfile then delfile(filename) end end)
    end
    StorageProvider.MemoryStore.macros[macroName] = nil
    return true
end

-- SettingsStorage
local SettingsStorage = {}
function SettingsStorage.Save(settingsTable)
    local jsonStr = HttpService:JSONEncode(settingsTable)
    if StorageProvider.HasFS then
        pcall(function() writefile("GardenHub/settings.json", jsonStr) end)
    else
        StorageProvider.MemoryStore.settings = settingsTable
    end
end

function SettingsStorage.Load()
    if StorageProvider.HasFS then
        local success, content = pcall(function() return readfile("GardenHub/settings.json") end)
        if success and content then
            local successDec, data = pcall(function() return HttpService:JSONDecode(content) end)
            if successDec and data then return data end
        end
    end
    return StorageProvider.MemoryStore.settings or {}
end

--------------------------------------------------------------------------------
-- 4. GAME INTEGRATION LAYER (ActionRegistry, GameState, Integration, GameAdapter)
--------------------------------------------------------------------------------

local ActionRegistry = {
    SELECT_UNIT  = "SELECT_UNIT",
    PLACE_UNIT   = "PLACE_UNIT",
    UPGRADE_UNIT = "UPGRADE_UNIT",
    SELL_UNIT    = "SELL_UNIT",
    SKIP_WAVE    = "SKIP_WAVE",
    PLAY_AGAIN   = "PLAY_AGAIN"
}

function ActionRegistry.CreatePayload(actionType, data, timestamp, delay)
    return {
        id = HttpService:GenerateGUID(false),
        type = actionType,
        timestamp = timestamp or 0,
        delay = delay or 0,
        data = data or {}
    }
end

-- GameState Reader Abstraction
local GameState = {}
function GameState.GetCash()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Cash") then
        return leaderstats.Cash.Value
    end
    return State.Get("cash") or 0
end

function GameState.GetWave()
    local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
    if leaderstats and leaderstats:FindFirstChild("Wave") then
        return leaderstats.Wave.Value
    end
    return State.Get("wave") or 0
end

-- Concrete Bridge Isolation (Safe execution guard for game remotes)
local Integration = {
    BridgeConnected = false
}

function Integration.ExecuteAction(payload)
    -- Abstract adapter layer guard: safely handles abstract actions
    -- Concrete game remote triggers are linked here when bound.
    Logger.Info("GameBridge Executing Action: " .. tostring(payload.type))
    if payload.type == ActionRegistry.SKIP_WAVE then
        -- Placeholder for concrete Skip Wave remote
    elseif payload.type == ActionRegistry.PLACE_UNIT then
        -- Placeholder for unit placement remote
    elseif payload.type == ActionRegistry.UPGRADE_UNIT then
        -- Placeholder for unit upgrade remote
    elseif payload.type == ActionRegistry.SELL_UNIT then
        -- Placeholder for unit sell remote
    elseif payload.type == ActionRegistry.PLAY_AGAIN then
        -- Placeholder for replay lobby remote
    end
    return true
end

-- GameAdapter
local GameAdapter = {}
function GameAdapter.Execute(actionPayload)
    if not actionPayload or not actionPayload.type then
        return false, "Invalid payload"
    end
    local success, err = pcall(function()
        return Integration.ExecuteAction(actionPayload)
    end)
    if not success then
        Logger.Error("GameAdapter execution failed: " .. tostring(err))
        return false, err
    end
    return true
end

--------------------------------------------------------------------------------
-- 5. MACRO SYSTEM (Serializer, Exporter, Importer, Recorder, Player, MacroManager)
--------------------------------------------------------------------------------

-- Serializer
local Serializer = {}
function Serializer.Serialize(macro)
    return HttpService:JSONEncode(macro)
end

function Serializer.Deserialize(jsonStr)
    return HttpService:JSONDecode(jsonStr)
end

-- Exporter
local Exporter = {}
function Exporter.ExportToShareCode(macro)
    local jsonStr = Serializer.Serialize(macro)
    local encoded = Base64.Encode(jsonStr)
    return "GHM1:" .. encoded
end

-- Importer
local Importer = {}
function Importer.Validate(macro)
    if type(macro) ~= "table" then return false, "Not a table" end
    if macro.format ~= "GHM" then return false, "Invalid format (Expected GHM)" end
    if not macro.name or #macro.name == 0 then return false, "Missing macro name" end
    if type(macro.actions) ~= "table" then return false, "Invalid actions list" end
    return true
end

function Importer.ImportFromShareCode(shareCode)
    if not shareCode or type(shareCode) ~= "string" then return false, "Invalid share code" end
    local prefix, payload = shareCode:match("^(GHM%d):(.+)$")
    if not prefix or not payload then
        return false, "Malformed share code format (expected GHM1:...)"
    end
    
    local decodedJson
    local successDec, errDec = pcall(function()
        decodedJson = Base64.Decode(payload)
    end)
    if not successDec or not decodedJson then
        return false, "Base64 decoding failed"
    end
    
    local macroData
    local successJson, errJson = pcall(function()
        macroData = HttpService:JSONDecode(decodedJson)
    end)
    if not successJson or not macroData then
        return false, "JSON parse error: " .. tostring(errJson)
    end
    
    local isValid, valErr = Importer.Validate(macroData)
    if not isValid then
        return false, valErr
    end
    
    return true, macroData
end

-- Recorder
local Recorder = {
    ActiveRecording = nil,
    StartTime = 0,
    LastActionTime = 0
}

function Recorder.Start(macroName)
    if State.Get("isPlaying") then
        return false, "Cannot record while player is running"
    end
    Recorder.ActiveRecording = {
        format = "GHM",
        version = 1,
        name = macroName or ("Macro_" .. os.time()),
        game = {
            name = Config.TargetGameName,
            gameId = Config.TargetGameId
        },
        createdAt = os.time(),
        updatedAt = os.time(),
        settings = {
            replayMode = State.Get("replayMode") or "By Cash"
        },
        actions = {}
    }
    Recorder.StartTime = os.clock()
    Recorder.LastActionTime = Recorder.StartTime
    State.Set("isRecording", true)
    State.Set("macroStatus", "Recording: " .. Recorder.ActiveRecording.name)
    Logger.Info("Started recording: " .. Recorder.ActiveRecording.name)
    return true
end

function Recorder.RecordAction(actionType, data)
    if not State.Get("isRecording") or not Recorder.ActiveRecording then return end
    local now = os.clock()
    local timestamp = now - Recorder.StartTime
    local delay = now - Recorder.LastActionTime
    Recorder.LastActionTime = now
    
    local payload = ActionRegistry.CreatePayload(actionType, data, timestamp, delay)
    table.insert(Recorder.ActiveRecording.actions, payload)
    Logger.Info(string.format("Recorded action: %s (Delay: %.2fs)", actionType, delay))
end

function Recorder.Stop()
    if not State.Get("isRecording") or not Recorder.ActiveRecording then return end
    local macro = Recorder.ActiveRecording
    Recorder.ActiveRecording = nil
    State.Set("isRecording", false)
    State.Set("macroStatus", "Idle")
    MacroStorage.Save(macro)
    Logger.Info("Stopped recording and saved macro: " .. macro.name)
    return macro
end

-- Player
local Player = {
    CurrentTask = nil,
    IsPaused = false
}

function Player.Play(macroData)
    if State.Get("isRecording") then
        return false, "Cannot play while recorder is active"
    end
    if not macroData or #macroData.actions == 0 then
        return false, "Macro contains no actions"
    end
    
    State.Set("isPlaying", true)
    State.Set("isPaused", false)
    State.Set("macroStatus", "Playing: " .. macroData.name)
    Logger.Info("Started playback: " .. macroData.name)
    
    Player.CurrentTask = task.spawn(function()
        local replayMode = macroData.settings and macroData.settings.replayMode or "By Cash"
        for i, action in ipairs(macroData.actions) do
            while State.Get("isPaused") do
                task.wait(0.2)
                if not State.Get("isPlaying") then return end
            end
            if not State.Get("isPlaying") then break end
            
            -- Wait for delay
            local delayTime = action.delay or 0
            if delayTime > 0 then
                task.wait(delayTime)
            end
            
            -- Cash requirement guard for "By Cash" mode
            if replayMode == "By Cash" and action.data and action.data.cost then
                while GameState.GetCash() < action.data.cost do
                    task.wait(0.5)
                    if not State.Get("isPlaying") then return end
                end
            end
            
            State.Set("macroStatus", string.format("Playing [%d/%d]: %s", i, #macroData.actions, action.type))
            GameAdapter.Execute(action)
        end
        
        State.Set("isPlaying", false)
        State.Set("isPaused", false)
        State.Set("macroStatus", "Completed: " .. macroData.name)
        Logger.Info("Completed playback: " .. macroData.name)
    end)
    return true
end

function Player.Pause()
    if State.Get("isPlaying") then
        State.Set("isPaused", true)
        State.Set("macroStatus", "Paused")
        Logger.Info("Playback paused")
    end
end

function Player.Resume()
    if State.Get("isPlaying") and State.Get("isPaused") then
        State.Set("isPaused", false)
        State.Set("macroStatus", "Playing")
        Logger.Info("Playback resumed")
    end
end

function Player.Stop()
    if State.Get("isPlaying") then
        State.Set("isPlaying", false)
        State.Set("isPaused", false)
        State.Set("macroStatus", "Idle")
        if Player.CurrentTask then
            pcall(function() task.cancel(Player.CurrentTask) end)
            Player.CurrentTask = nil
        end
        Logger.Info("Playback stopped")
    end
end

-- MacroManager
local MacroManager = {}
MacroManager.LoadedMacros = {}

function MacroManager.Refresh()
    MacroManager.LoadedMacros = MacroStorage.LoadAll()
    local names = {}
    for name, _ in pairs(MacroManager.LoadedMacros) do
        table.insert(names, name)
    end
    table.sort(names)
    State.Set("macrosList", names)
    if not State.Get("activeMacroName") and #names > 0 then
        State.Set("activeMacroName", names[1])
    end
end

function MacroManager.GetActive()
    local name = State.Get("activeMacroName")
    return name and MacroManager.LoadedMacros[name] or nil
end

function MacroManager.Duplicate(macroName, newName)
    local original = MacroManager.LoadedMacros[macroName]
    if not original then return false, "Macro not found" end
    local copy = HttpService:JSONDecode(Serializer.Serialize(original))
    copy.name = newName
    copy.createdAt = os.time()
    MacroStorage.Save(copy)
    MacroManager.Refresh()
    State.Set("activeMacroName", newName)
    return true
end

function MacroManager.Delete(macroName)
    MacroStorage.Delete(macroName)
    MacroManager.Refresh()
    local names = State.Get("macrosList")
    State.Set("activeMacroName", names[1] or nil)
    return true
end

--------------------------------------------------------------------------------
-- 6. UI SYSTEM (Theme, MainUI, AutomationUI, MacroUI)
--------------------------------------------------------------------------------

local UI = {}
local Connections = {}

local function Create(className, properties, children)
    local inst = Instance.new(className)
    for k, v in pairs(properties or {}) do
        inst[k] = v
    end
    for _, child in ipairs(children or {}) do
        child.Parent = inst
    end
    return inst
end

function UI.Build()
    -- Clean existing UI instance if present
    local existing = ParentGui:FindFirstChild("GardenHubGui")
    if existing then existing:Destroy() end

    local ScreenGui = Create("ScreenGui", {
        Name = "GardenHubGui",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = ParentGui
    })

    -- Main Container Frame
    local MainFrame = Create("Frame", {
        Name = "MainFrame",
        Size = UDim2.new(0, 480, 0, 360),
        Position = UDim2.new(0.5, -240, 0.5, -180),
        BackgroundColor3 = Config.Theme.Background,
        BorderSizePixel = 0,
        Active = true,
        Parent = ScreenGui
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
        Create("UIStroke", { Color = Config.Theme.Border, Thickness = 1.5 })
    })

    ----------------------------------------------------------------------------
    -- DRAG LOGIC (Touch + Mouse Support)
    ----------------------------------------------------------------------------
    local Header = Create("Frame", {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 45),
        BackgroundColor3 = Config.Theme.Surface,
        BorderSizePixel = 0,
        Parent = MainFrame
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 10) }),
        Create("TextLabel", {
            Text = "  🌱 Garden Hub  <font color=\"#00A2FF\">v" .. Config.Version .. "</font>",
            RichText = true,
            Font = Enum.Font.GothamBold,
            TextSize = 16,
            TextColor3 = Config.Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(0.6, 0, 1, 0),
            Position = UDim2.new(0, 12, 0, 0),
            BackgroundTransparency = 1
        })
    })

    local dragging, dragInput, dragStart, startPos
    local function updateDrag(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end

    table.insert(Connections, Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end))

    table.insert(Connections, Header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            updateDrag(input)
        end
    end))

    -- Close Button
    local CloseBtn = Create("TextButton", {
        Text = "✕",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Config.Theme.SubText,
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -38, 0.5, -15),
        BackgroundColor3 = Config.Theme.Card,
        Parent = Header
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 6) })
    })
    table.insert(Connections, CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
    end))

    ----------------------------------------------------------------------------
    -- TAB NAVIGATION BAR
    ----------------------------------------------------------------------------
    local TabBar = Create("Frame", {
        Name = "TabBar",
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.new(0, 12, 0, 52),
        BackgroundColor3 = Config.Theme.Surface,
        Parent = MainFrame
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) })
    })

    local AutomationTabBtn = Create("TextButton", {
        Name = "AutoTab",
        Text = "⚡ Automation",
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = Config.Theme.Text,
        Size = UDim2.new(0.5, -4, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = Config.Theme.Accent,
        Parent = TabBar
    }, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

    local MacroTabBtn = Create("TextButton", {
        Name = "MacroTab",
        Text = "📹 Macros",
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = Config.Theme.SubText,
        Size = UDim2.new(0.5, -4, 1, -6),
        Position = UDim2.new(0.5, 1, 0, 3),
        BackgroundColor3 = Config.Theme.Surface,
        Parent = TabBar
    }, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

    ----------------------------------------------------------------------------
    -- PAGES CONTAINER
    ----------------------------------------------------------------------------
    local PagesContainer = Create("Frame", {
        Name = "Pages",
        Size = UDim2.new(1, -24, 1, -100),
        Position = UDim2.new(0, 12, 0, 94),
        BackgroundTransparency = 1,
        Parent = MainFrame
    })

    ----------------------------------------------------------------------------
    -- PAGE 1: AUTOMATION PANEL
    ----------------------------------------------------------------------------
    local AutoPage = Create("ScrollingFrame", {
        Name = "AutoPage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Config.Theme.Border,
        Visible = true,
        Parent = PagesContainer
    }, {
        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8)
        })
    })

    local function CreateToggleCard(title, description, stateKey)
        local Card = Create("Frame", {
            Size = UDim2.new(1, -6, 0, 48),
            BackgroundColor3 = Config.Theme.Surface,
            Parent = AutoPage
        }, {
            Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
            Create("TextLabel", {
                Text = title,
                Font = Enum.Font.GothamBold,
                TextSize = 13,
                TextColor3 = Config.Theme.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.new(0, 12, 0, 8),
                Size = UDim2.new(0.7, 0, 0, 16),
                BackgroundTransparency = 1
            }),
            Create("TextLabel", {
                Text = description,
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextColor3 = Config.Theme.SubText,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.new(0, 12, 0, 24),
                Size = UDim2.new(0.7, 0, 0, 16),
                BackgroundTransparency = 1
            })
        })

        local ToggleSwitch = Create("TextButton", {
            Text = "",
            Size = UDim2.new(0, 44, 0, 22),
            Position = UDim2.new(1, -54, 0.5, -11),
            BackgroundColor3 = Config.Theme.Card,
            Parent = Card
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) })
        })

        local Knob = Create("Frame", {
            Size = UDim2.new(0, 18, 0, 18),
            Position = UDim2.new(0, 2, 0.5, -9),
            BackgroundColor3 = Config.Theme.SubText,
            Parent = ToggleSwitch
        }, {
            Create("UICorner", { CornerRadius = UDim.new(1, 0) })
        })

        State.Subscribe(stateKey, function(enabled)
            TweenService:Create(Knob, TweenInfo.new(0.2), {
                Position = enabled and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
                BackgroundColor3 = enabled and Config.Theme.Text or Config.Theme.SubText
            }):Play()
            TweenService:Create(ToggleSwitch, TweenInfo.new(0.2), {
                BackgroundColor3 = enabled and Config.Theme.Accent or Config.Theme.Card
            }):Play()
        end)

        table.insert(Connections, ToggleSwitch.MouseButton1Click:Connect(function()
            State.Set(stateKey, not State.Get(stateKey))
        end))
    end

    CreateToggleCard("Auto Farm Mode", "Automates unit placement and upgrades", "farmModeEnabled")
    CreateToggleCard("Auto Skip Wave", "Automatically skips wave delay timers", "autoSkipWave")
    CreateToggleCard("Auto Replay", "Replays game immediately upon match end", "autoReplay")

    -- Tick Speed Selector Card
    local SpeedCard = Create("Frame", {
        Size = UDim2.new(1, -6, 0, 52),
        BackgroundColor3 = Config.Theme.Surface,
        Parent = AutoPage
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("TextLabel", {
            Text = "Automation Tick Speed",
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Config.Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.new(0, 12, 0, 16),
            Size = UDim2.new(0.4, 0, 0, 20),
            BackgroundTransparency = 1
        })
    })

    local speeds = { 10, 20, 60 }
    for i, spd in ipairs(speeds) do
        local Btn = Create("TextButton", {
            Text = spd .. "Hz",
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = Config.Theme.Text,
            Size = UDim2.new(0, 50, 0, 28),
            Position = UDim2.new(1, -170 + ((i-1) * 55), 0.5, -14),
            BackgroundColor3 = Config.Theme.Card,
            Parent = SpeedCard
        }, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

        State.Subscribe("tickSpeed", function(val)
            Btn.BackgroundColor3 = (val == spd) and Config.Theme.Accent or Config.Theme.Card
        end)

        table.insert(Connections, Btn.MouseButton1Click:Connect(function()
            State.Set("tickSpeed", spd)
        end))
    end

    ----------------------------------------------------------------------------
    -- PAGE 2: MACRO MANAGEMENT PANEL
    ----------------------------------------------------------------------------
    local MacroPage = Create("ScrollingFrame", {
        Name = "MacroPage",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Config.Theme.Border,
        Visible = false,
        Parent = PagesContainer
    }, {
        Create("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 8)
        })
    })

    -- Status Header Banner
    local StatusCard = Create("Frame", {
        Size = UDim2.new(1, -6, 0, 36),
        BackgroundColor3 = Config.Theme.Surface,
        Parent = MacroPage
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) })
    })

    local StatusText = Create("TextLabel", {
        Text = "Status: Idle",
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = Config.Theme.Accent,
        Position = UDim2.new(0, 12, 0, 0),
        Size = UDim2.new(1, -24, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundTransparency = 1,
        Parent = StatusCard
    })

    State.Subscribe("macroStatus", function(st)
        StatusText.Text = "Status: " .. tostring(st)
    end)

    -- Controls Grid (Record, Play, Pause, Stop)
    local ControlGrid = Create("Frame", {
        Size = UDim2.new(1, -6, 0, 36),
        BackgroundTransparency = 1,
        Parent = MacroPage
    }, {
        Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6)
        })
    })

    local function CreateControlBtn(text, color, widthScale)
        return Create("TextButton", {
            Text = text,
            Font = Enum.Font.GothamBold,
            TextSize = 12,
            TextColor3 = Config.Theme.Text,
            Size = UDim2.new(widthScale, -4, 1, 0),
            BackgroundColor3 = color,
            Parent = ControlGrid
        }, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
    end

    local RecordBtn = CreateControlBtn("⏺ Record", Config.Theme.Danger, 0.25)
    local PlayBtn   = CreateControlBtn("▶ Play", Config.Theme.Success, 0.25)
    local PauseBtn  = CreateControlBtn("⏸ Pause", Config.Theme.Warning, 0.25)
    local StopBtn   = CreateControlBtn("⏹ Stop", Config.Theme.Card, 0.25)

    table.insert(Connections, RecordBtn.MouseButton1Click:Connect(function()
        if State.Get("isRecording") then
            Recorder.Stop()
            MacroManager.Refresh()
        else
            local activeName = State.Get("activeMacroName") or ("Macro_" .. os.time())
            Recorder.Start(activeName)
        end
    end))

    table.insert(Connections, PlayBtn.MouseButton1Click:Connect(function()
        local active = MacroManager.GetActive()
        if active then
            Player.Play(active)
        else
            Logger.Warn("No macro selected to play")
        end
    end))

    table.insert(Connections, PauseBtn.MouseButton1Click:Connect(function()
        if State.Get("isPaused") then
            Player.Resume()
        else
            Player.Pause()
        end
    end))

    table.insert(Connections, StopBtn.MouseButton1Click:Connect(function()
        if State.Get("isRecording") then Recorder.Stop() end
        if State.Get("isPlaying") then Player.Stop() end
        MacroManager.Refresh()
    end))

    -- Share Code Modal Helper
    local ModalFrame = Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.5,
        Visible = false,
        ZIndex = 10,
        Parent = MainFrame
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 10) })
    })

    local ModalBox = Create("Frame", {
        Size = UDim2.new(0.85, 0, 0.6, 0),
        Position = UDim2.new(0.075, 0, 0.2, 0),
        BackgroundColor3 = Config.Theme.Surface,
        Parent = ModalFrame
    }, {
        Create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Create("UIStroke", { Color = Config.Theme.Border })
    })

    local ModalTitle = Create("TextLabel", {
        Text = "Macro Share Code",
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextColor3 = Config.Theme.Text,
        Position = UDim2.new(0, 12, 0, 10),
        Size = UDim2.new(1, -24, 0, 20),
        BackgroundTransparency = 1,
        Parent = ModalBox
    })

    local ModalInput = Create("TextBox", {
        Text = "",
        PlaceholderText = "Paste GHM1: code here...",
        Font = Enum.Font.Code,
        TextSize = 11,
        TextColor3 = Config.Theme.Text,
        ClearTextOnFocus = false,
        MultiLine = true,
        TextWrapped = true,
        Position = UDim2.new(0, 12, 0, 36),
        Size = UDim2.new(1, -24, 0, 110),
        BackgroundColor3 = Config.Theme.Card,
        Parent = ModalBox
    }, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

    local ModalActionBtn = Create("TextButton", {
        Text = "Confirm",
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Config.Theme.Text,
        Position = UDim2.new(0.5, -50, 1, -38),
        Size = UDim2.new(0, 100, 0, 28),
        BackgroundColor3 = Config.Theme.Accent,
        Parent = ModalBox
    }, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

    local ModalCloseBtn = Create("TextButton", {
        Text = "✕",
        Position = UDim2.new(1, -26, 0, 8),
        Size = UDim2.new(0, 20, 0, 20),
        BackgroundTransparency = 1,
        TextColor3 = Config.Theme.SubText,
        Parent = ModalBox
    })
    table.insert(Connections, ModalCloseBtn.MouseButton1Click:Connect(function()
        ModalFrame.Visible = false
    end))

    -- Import / Export Bar
    local ShareBar = Create("Frame", {
        Size = UDim2.new(1, -6, 0, 32),
        BackgroundTransparency = 1,
        Parent = MacroPage
    }, {
        Create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6)
        })
    })

    local ImportBtn = Create("TextButton", {
        Text = "📥 Import GHM1",
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = Config.Theme.Text,
        Size = UDim2.new(0.5, -3, 1, 0),
        BackgroundColor3 = Config.Theme.Card,
        Parent = ShareBar
    }, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

    local ExportBtn = Create("TextButton", {
        Text = "📤 Export Code",
        Font = Enum.Font.GothamMedium,
        TextSize = 11,
        TextColor3 = Config.Theme.Text,
        Size = UDim2.new(0.5, -3, 1, 0),
        BackgroundColor3 = Config.Theme.Card,
        Parent = ShareBar
    }, { Create("UICorner", { CornerRadius = UDim.new(0, 6) }) })

    table.insert(Connections, ImportBtn.MouseButton1Click:Connect(function()
        ModalTitle.Text = "Import GHM Share Code"
        ModalInput.Text = ""
        ModalInput.PlaceholderText = "Paste GHM1: code here..."
        ModalActionBtn.Text = "Import"
        ModalFrame.Visible = true
        
        local conn
        conn = ModalActionBtn.MouseButton1Click:Connect(function()
            conn:Disconnect()
            local code = ModalInput.Text
            local ok, result = Importer.ImportFromShareCode(code)
            if ok then
                MacroStorage.Save(result)
                MacroManager.Refresh()
                State.Set("activeMacroName", result.name)
                Logger.Info("Successfully imported macro: " .. result.name)
            else
                Logger.Error("Import failed: " .. tostring(result))
            end
            ModalFrame.Visible = false
        end)
    end))

    table.insert(Connections, ExportBtn.MouseButton1Click:Connect(function()
        local active = MacroManager.GetActive()
        if not active then
            Logger.Warn("Select a macro to export")
            return
        end
        local shareCode = Exporter.ExportToShareCode(active)
        ModalTitle.Text = "Exported GHM1 Share Code"
        ModalInput.Text = shareCode
        ModalActionBtn.Text = "Copy Code"
        ModalFrame.Visible = true
        
        local conn
        conn = ModalActionBtn.MouseButton1Click:Connect(function()
            conn:Disconnect()
            if type(setclipboard) == "function" then
                setclipboard(shareCode)
                Logger.Info("Share code copied to clipboard!")
            end
            ModalFrame.Visible = false
        end)
    end))

    ----------------------------------------------------------------------------
    -- TAB SWITCHING
    ----------------------------------------------------------------------------
    table.insert(Connections, AutomationTabBtn.MouseButton1Click:Connect(function()
        AutoPage.Visible = true
        MacroPage.Visible = false
        AutomationTabBtn.BackgroundColor3 = Config.Theme.Accent
        AutomationTabBtn.TextColor3 = Config.Theme.Text
        MacroTabBtn.BackgroundColor3 = Config.Theme.Surface
        MacroTabBtn.TextColor3 = Config.Theme.SubText
    end))

    table.insert(Connections, MacroTabBtn.MouseButton1Click:Connect(function()
        AutoPage.Visible = false
        MacroPage.Visible = true
        MacroTabBtn.BackgroundColor3 = Config.Theme.Accent
        MacroTabBtn.TextColor3 = Config.Theme.Text
        AutomationTabBtn.BackgroundColor3 = Config.Theme.Surface
        AutomationTabBtn.TextColor3 = Config.Theme.SubText
    end))

    return ScreenGui
end

--------------------------------------------------------------------------------
-- 7. INITIALIZATION & SELF-TEST BOOTSTRAP
--------------------------------------------------------------------------------

local function Main()
    Logger.Info("Initializing Garden Hub v" .. Config.Version)
    
    -- Validate GameId
    local isValidGame, currentGameId, gameName = GameDetector.Validate()
    if not isValidGame then
        Logger.Error(string.format("GameId Mismatch! Expected: %d (%s), Got: %d", Config.TargetGameId, gameName, currentGameId))
        StarterGui:SetCore("SendNotification", {
            Title = "Garden Hub",
            Text = "Error: Invalid Game! Garden Tower Defense required.",
            Duration = 5
        })
        getgenv().GardenHubLoaded = false
        return
    end

    -- Run Lightweight Self-Test
    local testMacro = {
        format = "GHM", version = 1, name = "SelfTest",
        game = { name = Config.TargetGameName, gameId = Config.TargetGameId },
        actions = {}
    }
    local code = Exporter.ExportToShareCode(testMacro)
    local okImp, impData = Importer.ImportFromShareCode(code)
    assert(okImp and impData.name == "SelfTest", "Self-test ShareCode Import/Export check failed")

    -- Load Saved Macros & Refresh
    MacroManager.Refresh()

    -- Mount UI
    local ScreenGui = UI.Build()

    -- Setup Unload Handler for Re-executions
    getgenv().GardenHubUnload = function()
        for _, conn in ipairs(Connections) do
            pcall(function() conn:Disconnect() end)
        end
        if ScreenGui then ScreenGui:Destroy() end
        getgenv().GardenHubLoaded = false
        Logger.Info("Garden Hub Unloaded cleanly.")
    end

    Logger.Info("Garden Hub v" .. Config.Version .. " successfully loaded!")
    StarterGui:SetCore("SendNotification", {
        Title = "Garden Hub",
        Text = "Loaded successfully!",
        Duration = 3
    })
end

-- Launch
Main()
