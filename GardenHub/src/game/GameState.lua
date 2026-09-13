local GameState = {}
GameState.__index = GameState

GameState.Data = {
    connected = false,
    status = "Idle",
    lastAction = nil,
    lastError = nil,
    pendingIntegration = true,
    availableActions = {},
    lastTimestamp = 0,
    Cash = 0,
    Wave = 0,
    Location = "Unknown",
    Mode = "OFF",
}

function GameState:Reset()
    self.Data = {
        connected = false,
        status = "Idle",
        lastAction = nil,
        lastError = nil,
        pendingIntegration = true,
        availableActions = {},
        lastTimestamp = 0,
        Cash = 0,
        Wave = 0,
        Location = "Unknown",
        Mode = "OFF",
    }
    return self.Data
end

function GameState:Set(key, value)
    if type(key) ~= "string" then
        return false
    end

    self.Data[key] = value
    return value
end

function GameState:Get(key, defaultValue)
    if self.Data[key] == nil then
        return defaultValue
    end

    return self.Data[key]
end

function GameState:MarkConnected(isConnected, reason)
    self.Data.connected = isConnected == true
    self.Data.pendingIntegration = not self.Data.connected
    self.Data.status = self.Data.connected and "Connected" or "PendingIntegration"
    if reason then
        self.Data.lastError = reason
    end
    return self.Data.connected
end

function GameState:RecordAction(action)
    if type(action) ~= "table" then
        return false
    end

    self.Data.lastAction = action.type or "UNKNOWN"
    self.Data.lastTimestamp = tonumber(action.timestamp) or self.Data.lastTimestamp
    self.Data.status = "Ready"
    self.Data.pendingIntegration = false
    return true
end

return GameState
