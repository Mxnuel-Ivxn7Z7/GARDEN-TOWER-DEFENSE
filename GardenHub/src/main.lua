local GardenHub = _G.GardenHub or {}

-- Inyección de ModuleLoader dinámico para entornos remotos (Delta)
local GITHUB_USER = "Mxnuel-Ivxn7Z7"
local GITHUB_REPO = "GARDEN-TOWER-DEFENSE"
local GITHUB_BRANCH = "main"
local BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/GardenHub/src/", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH)

local loadedModulesCache = {}

local function resolveModule(modulePath)
    if loadedModulesCache[modulePath] then
        return loadedModulesCache[modulePath]
    end

    local relativePath = string.gsub(modulePath, "%.", "/") .. ".lua"
    local url = BASE_URL .. relativePath

    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    if not success or not response or string.find(response, "404: Not Found") then
        return nil, "No se encontró el módulo en GitHub: " .. relativePath
    end

    local fn, syntaxErr = loadstring(response)
    if not fn then
        return nil, "Error de sintaxis en " .. relativePath .. ": " .. tostring(syntaxErr)
    end

    local execSuccess, result = pcall(fn)
    if not execSuccess then
        return nil, "Error al ejecutar " .. relativePath .. ": " .. tostring(result)
    end

    loadedModulesCache[modulePath] = result
    return result
end

-- Creamos el ModuleLoader universal en el entorno global de la app
local ModuleLoader = {
    Require = function(self, modulePath)
        return resolveModule(modulePath)
    end
}

_G.GardenHub = GardenHub
_G.GardenHub.ModuleLoader = ModuleLoader

local function initializeCore()
    local config, configError = resolveModule("core.Config")
    local logger, loggerError = resolveModule("core.Logger")
    local state, stateError = resolveModule("core.State")
    local detector, detectorError = resolveModule("core.GameDetector")

    if not config or not logger or not state or not detector then
        return false, configError or loggerError or stateError or detectorError or "Core modules failed to load."
    end

    GardenHub.Config = config
    GardenHub.Logger = logger
    GardenHub.State = state
    GardenHub.GameDetector = detector

    if GardenHub.Config and type(GardenHub.Config.ApplyDefaults) == "function" then
        GardenHub.Config:ApplyDefaults()
    end

    if GardenHub.State then
        GardenHub.State:Set("Location", "Lobby")
        GardenHub.State:Set("Mode", "OFF")
        GardenHub.State:Set("TickSpeed", 1)
        GardenHub.State:Set("Speed", "x1")
        GardenHub.State:Set("MacroStatus", "Idle")
        GardenHub.State:Set("SelectedMacro", "")
        GardenHub.State:Set("Actions", 0)
        GardenHub.State:Set("Cash", 0)
        GardenHub.State:Set("Wave", 0)
        GardenHub.State:Set("Time", "00:00")
    end

    return true
end

local function initializeStorage()
    local macroStorage, macroError = resolveModule("storage.MacroStorage")
    local settingsStorage, settingsError = resolveModule("storage.SettingsStorage")

    if not macroStorage or not settingsStorage then
        return false, macroError or settingsError or "Storage modules failed to load."
    end

    GardenHub.MacroStorage = macroStorage
    GardenHub.SettingsStorage = settingsStorage

    if GardenHub.SettingsStorage and type(GardenHub.SettingsStorage.Load) == "function" then
        GardenHub.SettingsStorage:Load()
    end

    if GardenHub.MacroStorage and type(GardenHub.MacroStorage.LoadAll) == "function" then
        GardenHub.MacroStorage:LoadAll()
    end

    return true
end

local function initializeGame()
    local gameAdapter, adapterError = resolveModule("game.GameAdapter")
    local gameState, stateError = resolveModule("game.GameState")
    local integration, integrationError = resolveModule("game.Integration")

    if not gameAdapter or not gameState or not integration then
        return false, adapterError or stateError or integrationError or "Game modules failed to load."
    end

    GardenHub.GameAdapter = gameAdapter
    GardenHub.GameState = gameState
    GardenHub.Integration = integration

    if GardenHub.GameAdapter and type(GardenHub.GameAdapter.Initialize) == "function" then
        GardenHub.GameAdapter:Initialize()
    end

    if GardenHub.Integration and type(GardenHub.Integration.Initialize) == "function" then
        GardenHub.Integration:Initialize()
    end

    return true
end

local function initializeMacros()
    local macroManager, managerError = resolveModule("macros.MacroManager")
    local recorder, recorderError = resolveModule("macros.Recorder")
    local player, playerError = resolveModule("macros.Player")
    local serializer, serializerError = resolveModule("macros.Serializer")
    local importer, importerError = resolveModule("macros.Importer")
    local exporter, exporterError = resolveModule("macros.Exporter")

    if not macroManager or not recorder or not player or not serializer or not importer or not exporter then
        return false, managerError or recorderError or playerError or serializerError or importerError or exporterError or "Macro modules failed to load."
    end

    GardenHub.MacroManager = macroManager
    GardenHub.Recorder = recorder
    GardenHub.Player = player
    GardenHub.Serializer = serializer
    GardenHub.Importer = importer
    GardenHub.Exporter = exporter

    return true
end

local function initializeUI()
    local theme, themeError = resolveModule("ui.Theme")
    local mainUI, mainUIError = resolveModule("ui.MainUI")
    local automation, automationError = resolveModule("ui.Automation")
    local macroUI, macroUIError = resolveModule("ui.MacroUI")

    if not theme or not mainUI or not automation or not macroUI then
        return false, themeError or mainUIError or automationError or macroUIError or "UI modules failed to load."
    end

    GardenHub.Theme = theme
    GardenHub.MainUI = mainUI
    GardenHub.Automation = automation
    GardenHub.MacroUI = macroUI

    if GardenHub.MainUI and type(GardenHub.MainUI.Create) == "function" then
        GardenHub.MainUI:Create()
    end

    return true
end

local function connectControllers()
    local controllerModule, controllerError = resolveModule("controllers.AutomationController")
    if not controllerModule then return false, controllerError or "AutomationController unavailable." end
    GardenHub.AutomationController = controllerModule
    if type(controllerModule.Bind) == "function" then
        local ok, message = controllerModule:Bind()
        if not ok then return false, message end
    end
    return true
end

local function start()
    local coreOk, coreError = initializeCore()
    if not coreOk then return false, coreError end

    if not GardenHub.GameDetector or type(GardenHub.GameDetector.IsValidGame) ~= "function" then
        return false, "GameDetector is not initialized."
    end

    local validGame, gameError = GardenHub.GameDetector:IsValidGame()
    if not validGame then return false, gameError or "Unsupported Game" end

    local storageOk, storageError = initializeStorage()
    if not storageOk then return false, storageError end

    local gameOk, gameErrorMessage = initializeGame()
    if not gameOk then return false, gameErrorMessage end

    local macroOk, macroError = initializeMacros()
    if not macroOk then return false, macroError end

    local uiOk, uiError = initializeUI()
    if not uiOk then return false, uiError end

    local connectedOk, connectError = connectControllers()
    if not connectedOk then return false, connectError end

    if GardenHub.Logger and type(GardenHub.Logger.Info) == "function" then
        GardenHub.Logger:Info("Garden Hub initialized successfully.")
    end

    _G.GardenHub = GardenHub
    return true
end

local function stop()
    if GardenHub.AutomationController and type(GardenHub.AutomationController.Unbind) == "function" then
        GardenHub.AutomationController:Unbind()
    end
    if GardenHub.MainUI and type(GardenHub.MainUI.Destroy) == "function" then
        GardenHub.MainUI:Destroy()
    end
    return true
end

GardenHub.Start = start
GardenHub.Stop = stop
_G.GardenHub = GardenHub

return GardenHub
