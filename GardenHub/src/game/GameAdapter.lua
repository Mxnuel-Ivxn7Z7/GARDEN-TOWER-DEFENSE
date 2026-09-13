local GameAdapter = {}
GameAdapter.__index = GameAdapter

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local ActionRegistry = ModuleLoader:Require("game.ActionRegistry")
local GameState = ModuleLoader:Require("game.GameState")
local Logger = ModuleLoader:Require("core.Logger")

GameAdapter.Registry = ActionRegistry
GameAdapter.ConcreteBridge = nil

local function buildDefaultActions()
    local defaultActions = {
        "SELECT_UNIT",
        "PLACE_UNIT",
        "UPGRADE_UNIT",
        "SELL_UNIT",
        "SKIP_WAVE",
        "PLAY_AGAIN",
    }

    for _, actionType in ipairs(defaultActions) do
        GameAdapter.Registry:Register(actionType, {
            id = actionType,
            name = actionType,
            description = "Pending integration action",
            requiredData = { "unit" },
            handler = function(action)
                return GameAdapter:Pending(action)
            end,
        })
    end

    GameState:Set("availableActions", defaultActions)
    return defaultActions
end

function GameAdapter:SetConcreteBridge(provider)
    if type(provider) ~= "table" then
        return false, "Concrete bridge must be a table."
    end

    if type(provider.Execute) ~= "function" then
        return false, "Concrete bridge must expose Execute(action)."
    end

    self.ConcreteBridge = provider
    GameState:MarkConnected(true, "Concrete bridge attached.")
    return true
end

function GameAdapter:Pending(action)
    local actionType = action and action.type or "UNKNOWN"
    local message = string.format("Pending integration for action %s. Concrete game bridge not available yet.", tostring(actionType))
    GameState:Set("status", "PendingIntegration")
    GameState:Set("lastError", message)
    Logger:Warning(message)
    return false, message
end

function GameAdapter:Execute(action)
    if type(action) ~= "table" then
        local message = "Action payload is invalid."
        GameState:Set("status", "Error")
        GameState:Set("lastError", message)
        Logger:Error(message)
        return false, message
    end

    local actionType = tostring(action.type or "")
    if actionType == "" then
        local message = "Action type is required."
        GameState:Set("status", "Error")
        GameState:Set("lastError", message)
        Logger:Error(message)
        return false, message
    end

    if self.ConcreteBridge and type(self.ConcreteBridge.Execute) == "function" then
        GameState:RecordAction(action)
        local ok, result = xpcall(function()
            return self.ConcreteBridge:Execute(action)
        end, debug.traceback)

        if not ok then
            local message = string.format("Concrete bridge execution failed for %s: %s", actionType, tostring(result))
            GameState:Set("status", "Error")
            GameState:Set("lastError", message)
            Logger:Error(message)
            return false, message
        end

        GameState:Set("status", "Ready")
        GameState:Set("lastAction", actionType)
        return true, result
    end

    local definition = self.Registry:Get(actionType)
    if not definition then
        return self:Pending(action)
    end

    local valid, errorMessage = self.Registry:Validate(action)
    if not valid then
        GameState:Set("status", "Error")
        GameState:Set("lastError", errorMessage)
        Logger:Error(errorMessage)
        return false, errorMessage
    end

    if type(definition.handler) ~= "function" then
        return self:Pending(action)
    end

    GameState:RecordAction(action)
    local ok, result = xpcall(function()
        return definition.handler(action)
    end, debug.traceback)

    if not ok then
        local message = string.format("Action handler failed for %s: %s", actionType, tostring(result))
        GameState:Set("status", "Error")
        GameState:Set("lastError", message)
        Logger:Error(message)
        return false, message
    end

    GameState:Set("status", "Ready")
    GameState:Set("lastAction", actionType)
    return true, result
end

function GameAdapter:Initialize()
    self.Registry:Clear()
    buildDefaultActions()
    GameState:MarkConnected(false, "Awaiting concrete integration binding.")
    Logger:Info("Game adapter initialized with abstract actions ready for game integration.")
    return self
end

function GameAdapter:GetSupportedActions()
    return self.Registry:GetSupported()
end

return GameAdapter
