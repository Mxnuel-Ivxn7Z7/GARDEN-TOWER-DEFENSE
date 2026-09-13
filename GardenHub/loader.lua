local Loader = {}

local TARGET_GAME_ID = 7703614594
local TARGET_GAME_NAME = "Garden Tower Defense"

local function setGlobal(key, value)
    _G[key] = value
end

local function getGlobal(key, default)
    local value = rawget(_G, key)
    if value == nil then
        return default
    end
    return value
end

local function waitForGameLoad(timeout)
    timeout = tonumber(timeout) or 10

    if not game or typeof and typeof(game) ~= "Instance" then
        return false, "Unsupported Game"
    end

    local ok, isLoaded = pcall(function()
        return game:IsLoaded()
    end)

    if not ok then
        return false, "Game load state unavailable"
    end

    if isLoaded == true then
        return true
    end

    local startedAt = os.clock()
    while true do
        local status, ready = pcall(function()
            return game:IsLoaded()
        end)

        if status and ready == true then
            return true
        end

        if os.clock() - startedAt >= timeout then
            break
        end

        task.wait(0.1)
    end

    return false, "Game load timeout"
end

local function loadMainModule()
    local candidates = {
        "GardenHub.src.main",
        "src.main",
    }

    for _, moduleName in ipairs(candidates) do
        local ok, module = pcall(function()
            return require(moduleName)
        end)
        if ok and module then
            return module
        end
    end

    if script and script.Parent then
        local srcFolder = script.Parent:FindFirstChild("src")
        local mainModule = srcFolder and srcFolder:FindFirstChild("main")
        if mainModule then
            return require(mainModule)
        end
    end

    return nil
end

function Loader.Start()
    if getGlobal("GARDENHUB_RUNNING", false) then
        return false, "Loader already running."
    end

    if getGlobal("GARDENHUB_LOADED", false) then
        return false, "Garden Hub is already loaded."
    end

    setGlobal("GARDENHUB_RUNNING", true)
    setGlobal("GARDENHUB_STARTED_AT", os.clock())
    setGlobal("GARDENHUB_ACTIVE_ROUTE", "Boot")

    local ok, loadError = xpcall(function()
        return waitForGameLoad(10)
    end, debug.traceback)

    if not ok or loadError ~= true then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Error")
        return false, loadError or "Game load failed"
    end

    if not game or (typeof and typeof(game) ~= "Instance") then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Unsupported Game")
        return false, "Unsupported Game"
    end

    local gameId = tonumber(game.GameId)
    if gameId ~= TARGET_GAME_ID then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Unsupported Game")
        return false, "Unsupported Game"
    end

    local mainModule = loadMainModule()
    if not mainModule or type(mainModule.Start) ~= "function" then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Error")
        return false, "Unable to load Garden Hub main entry point."
    end

    local started, startError = xpcall(function()
        return mainModule.Start()
    end, debug.traceback)

    if not started then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Error")
        return false, startError
    end

    if startError == false then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Error")
        return false, "Garden Hub failed to initialize."
    end

    setGlobal("GARDENHUB_LOADED", true)
    setGlobal("GARDENHUB_RUNNING", false)
    setGlobal("GARDENHUB_ACTIVE_ROUTE", "Automation")

    return true
end

return Loader
