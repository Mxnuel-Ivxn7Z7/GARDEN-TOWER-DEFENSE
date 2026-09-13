local Recorder = {}
Recorder.__index = Recorder

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local Logger = ModuleLoader:Require("core.Logger")
local State = ModuleLoader:Require("core.State")

local function deepClone(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = deepClone(item) end
    return copy
end

Recorder.Status = "Idle"
Recorder.Actions = {}
Recorder.StartedAt = nil
Recorder.LastActionAt = nil
Recorder.CurrentMacroName = nil
Recorder.PauseStartedAt = nil
Recorder.TotalPausedTime = 0

local function normalizeActionType(actionType)
    if type(actionType) ~= "string" then
        return "UNKNOWN"
    end

    return string.upper(string.gsub(actionType, "%s+", "_"))
end

local function makeAction(actionType, data)
    local timestamp = 0
    if Recorder.StartedAt then
        timestamp = math.max(0, os.clock() - Recorder.StartedAt - Recorder.TotalPausedTime)
    end

    local previous = Recorder.Actions[#Recorder.Actions]
    local delay = timestamp
    if previous then
        delay = math.max(0, timestamp - previous.timestamp)
    end

    return {
        id = tostring(os.clock() * 1000000),
        type = normalizeActionType(actionType),
        timestamp = timestamp,
        delay = delay,
        data = type(data) == "table" and data or {},
    }
end

function Recorder:Start(name)
    if self.Status == "Recording" or self.Status == "Paused" then
        return false, "Recorder is already active."
    end
    local status = State:Get("MacroStatus")
    if status == "Playing" or status == "PlaybackPaused" then
        return false, "Cannot record during playback."
    end

    self.Actions = {}
    self.StartedAt = os.clock()
    self.LastActionAt = self.StartedAt
    self.CurrentMacroName = name or "Untitled Macro"
    self.PauseStartedAt = nil
    self.TotalPausedTime = 0
    self.Status = "Recording"
    State:Set("MacroStatus", "Recording")
    Logger:Record("Recording started")
    return true
end

function Recorder:Pause()
    if self.Status ~= "Recording" then
        return false, "No active recording to pause."
    end

    self.PauseStartedAt = os.clock()
    self.Status = "Paused"
    State:Set("MacroStatus", "RecordingPaused")
    Logger:Warning("Recording paused")
    return true
end

function Recorder:Resume()
    if self.Status ~= "Paused" then
        return false, "Recording is not paused."
    end

    if self.PauseStartedAt then
        self.TotalPausedTime = self.TotalPausedTime + (os.clock() - self.PauseStartedAt)
        self.PauseStartedAt = nil
    end

    self.Status = "Recording"
    State:Set("MacroStatus", "Recording")
    Logger:Record("Recording resumed")
    return true
end

function Recorder:RegisterAction(actionType, data)
    if self.Status ~= "Recording" then
        return false, "Recording is not active."
    end

    local action = makeAction(actionType, data)
    table.insert(self.Actions, action)
    self.LastActionAt = os.clock()
    State:Set("Actions", #self.Actions)
    Logger:Record(string.format("Action added: %s", actionType or "input"))
    return action
end

function Recorder:Stop()
    if self.Status == "Idle" then
        return false, "No recording available to stop."
    end

    if self.PauseStartedAt then
        self.TotalPausedTime = self.TotalPausedTime + (os.clock() - self.PauseStartedAt)
        self.PauseStartedAt = nil
    end
    local macroName = self.CurrentMacroName or "Untitled Macro"
    local replayMode = State:Get("ReplayMode", "Once")
    if replayMode ~= "Once" and replayMode ~= "Repeat" then replayMode = "Once" end
    local macro = {
        name = macroName,
        format = "GHM",
        version = 1,
        game = {
            name = "Garden Tower Defense",
            gameId = 7703614594,
        },
        createdAt = os.time(),
        updatedAt = os.time(),
        settings = {
            replayMode = replayMode,
        },
        actions = deepClone(self.Actions),
    }

    self.Status = "Stopped"
    self.StartedAt = nil
    self.LastActionAt = nil
    self.PauseStartedAt = nil
    self.CurrentMacroName = nil
    self.TotalPausedTime = 0
    State:Set("MacroStatus", "Stopped")
    Logger:Success("Recording stopped and macro prepared.")

    return macro
end

function Recorder:Reset()
    self.Status = "Idle"
    self.Actions = {}
    self.StartedAt = nil
    self.LastActionAt = nil
    self.CurrentMacroName = nil
    self.PauseStartedAt = nil
    self.TotalPausedTime = 0
    State:Set("MacroStatus", "Idle")
    State:Set("Actions", 0)
    return true
end

return Recorder
