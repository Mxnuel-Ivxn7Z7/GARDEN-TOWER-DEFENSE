-- ==========================================
-- GARDEN HUB - BOOTSTRAPPER (FIXED HTTP)
-- Target Game: Garden Tower Defense (7703614594)
-- ==========================================

local Loader = {}

local GITHUB_USER = "Mxnuel-Ivxn7Z7"
local GITHUB_REPO = "GARDEN-TOWER-DEFENSE"
local GITHUB_BRANCH = "main"
local BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/GardenHub/", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH)

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

    if not game or (typeof and typeof(game) ~= "Instance") then
        return false, "Unsupported Game"
    end

    local ok, isLoaded = pcall(function()
        return game:IsLoaded()
    end)

    if ok and isLoaded == true then
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

-- Función de descarga remota corregida
local function loadRemoteModule(relativePath)
    -- Limpiar espacios en blanco invisibles en la ruta
    relativePath = string.gsub(relativePath, "%s+", "")
    local url = BASE_URL .. relativePath

    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    -- Validar si realmente devolvió un 404 de GitHub o falló la conexión
    if not success or type(response) ~= "string" or string.find(response, "404: Not Found") == 1 then
        return nil, "Error al descargar modulo desde github: " .. relativePath
    end

    local fn, syntaxErr = loadstring(response)
    if not fn then
        return nil, "Error de sintaxis en " .. relativePath .. ": " .. tostring(syntaxErr)
    end

    local execSuccess, result = pcall(fn)
    if not execSuccess then
        return nil, "Error al ejecutar " .. relativePath .. ": " .. tostring(result)
    end

    return result
end

function Loader.Start()
    if getGlobal("GARDENHUB_RUNNING", false) then
        return false, "Loader ya se esta ejecutando."
    end

    if getGlobal("GARDENHUB_LOADED", false) then
        return false, "Garden Hub ya esta cargado."
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
        return false, loadError or "Error al esperar carga del juego"
    end

    if not game or (typeof and typeof(game) ~= "Instance") then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Unsupported Game")
        return false, "Juego no soportado"
    end

    local gameId = tonumber(game.GameId)
    if gameId ~= TARGET_GAME_ID then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Unsupported Game")
        return false, "Garden Hub solo funciona en " .. TARGET_GAME_NAME
    end

    -- Cargar src/main.lua
    local mainModule, err = loadRemoteModule("src/main.lua")
    if not mainModule or type(mainModule.Start) ~= "function" then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Error")
        return false, err or "No se pudo inicializar src/main.lua"
    end

    local started, startError = xpcall(function()
        return mainModule.Start()
    end, debug.traceback)

    if not started then
        setGlobal("GARDENHUB_RUNNING", false)
        setGlobal("GARDENHUB_ACTIVE_ROUTE", "Error")
        return false, startError
    end

    setGlobal("GARDENHUB_LOADED", true)
    setGlobal("GARDENHUB_RUNNING", false)
    setGlobal("GARDENHUB_ACTIVE_ROUTE", "Automation")

    return true
end

-- Auto-inicio al ejecutar con loadstring
local success, result = Loader.Start()
if not success then
    warn("[GardenHub Loader Error]: " .. tostring(result))
end

return Loader
