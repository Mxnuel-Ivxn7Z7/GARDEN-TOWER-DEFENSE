local Integration = {}
Integration.__index = Integration

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local GameAdapter = ModuleLoader:Require("game.GameAdapter")
local GameState = ModuleLoader:Require("game.GameState")
local Logger = ModuleLoader:Require("core.Logger")

function Integration:Initialize()
    GameAdapter:Initialize()
    GameState:Set("status", "PendingIntegration")
    GameState:Set("pendingIntegration", true)
    Logger:Info("Game Integration layer ready. Waiting for a concrete bridge to be attached.")
    return self
end

function Integration:AttachBridge(provider)
    local ok, message = GameAdapter:SetConcreteBridge(provider)
    if not ok then
        Logger:Error(message)
        return false, message
    end

    GameState:Set("pendingIntegration", false)
    GameState:Set("connected", true)
    GameState:Set("status", "Connected")
    Logger:Success("Concrete game bridge attached successfully.")
    return true
end

function Integration:Execute(action)
    return GameAdapter:Execute(action)
end

return Integration
