local Player = {}
Player.__index = Player

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local Logger = ModuleLoader:Require("core.Logger")
local State = ModuleLoader:Require("core.State")
local GameAdapter = ModuleLoader:Require("game.GameAdapter")

Player.Status = "Idle"
Player.CurrentMacro = nil
Player.CurrentActionIndex = 0
Player.TaskHandle = nil
Player.IsPaused = false
Player.StopRequested = false
Player.WorkerActive = false
Player.PauseStartedAt = nil
Player.TotalPausedTime = 0
Player.RepeatEnabled = false

local function safeRunMacro(macro)
    if type(macro) ~= "table" or type(macro.actions) ~= "table" then
        return false, "Invalid macro payload."
    end

    return true
end

function Player:WaitInterruptible(seconds)
    local elapsed = 0
    local target = tonumber(seconds) or 0

    while elapsed < target do
        if self.StopRequested then
            return false
        end

        if self.Status == "Paused" then
            task.wait(0.05)
        else
            local step = math.min(0.05, target - elapsed)
            task.wait(step)
            elapsed = elapsed + step
        end
    end

    return true
end

local function completePlayback(self)
    self.Status = "Completed"
    self.WorkerActive = false
    self.StopRequested = false
    self.IsPaused = false
    self.PauseStartedAt = nil
    State:Set("MacroStatus", "Completed")
    Logger:Success("Macro completed successfully.")
end

function Player:Load(macro)
    local ok, message = safeRunMacro(macro)
    if not ok then
        return false, message
    end

    self.CurrentMacro = macro
    self.CurrentActionIndex = 0
    self.Status = "Loaded"
    self.IsPaused = false
    self.StopRequested = false
    self.WorkerActive = false
    self.PauseStartedAt = nil
    self.TotalPausedTime = 0
    State:Set("MacroStatus", "Loaded")
    return true
end

function Player:Start()
    local macroStatus = State:Get("MacroStatus")
    if macroStatus == "Recording" or macroStatus == "RecordingPaused" then return false, "Cannot play while recording." end

    if type(self.CurrentMacro) ~= "table" then
        return false, "No macro selected to play."
    end

    local ok, message = safeRunMacro(self.CurrentMacro)
    if not ok then
        self.Status = "Error"
        State:Set("MacroStatus", "Error")
        Logger:Error(message)
        return false, message
    end

    if self.WorkerActive then
        return true
    end

    self.Status = "Playing"
    self.CurrentActionIndex = 0
    self.IsPaused = false
    self.StopRequested = false
    self.WorkerActive = true
    self.PauseStartedAt = nil
    State:Set("MacroStatus", "Playing")
    Logger:Play("Macro started")

    self.TaskHandle = task.spawn(function()
        while self.WorkerActive do
            if self.StopRequested then
                break
            end

            if self.Status == "Paused" then
                task.wait(0.05)
            elseif self.Status == "Playing" then
                local actions = self.CurrentMacro and self.CurrentMacro.actions or {}
                local total = #actions
                if total == 0 then
                    completePlayback(self)
                    break
                end

                if self.CurrentActionIndex >= total then
                    if self.RepeatEnabled then
                        self.CurrentActionIndex = 0
                        State:Set("Actions", 0)
                        Logger:Play("Macro repeating from action 1.")
                    else
                        completePlayback(self)
                        break
                    end
                end

                self.CurrentActionIndex = self.CurrentActionIndex + 1
                local action = actions[self.CurrentActionIndex]
                if action then
                    State:Set("Actions", self.CurrentActionIndex)
                    local delaySeconds = tonumber(action.delay) or 0
                    if delaySeconds > 0 then
                        local waitOk = self:WaitInterruptible(delaySeconds)
                        if not waitOk then
                            break
                        end

                        while self.Status == "Paused" and not self.StopRequested do
                            task.wait(0.05)
                        end
                    end

                    if self.StopRequested then
                        break
                    end

                    while self.Status == "Paused" and not self.StopRequested do
                        task.wait(0.05)
                    end
                    if self.StopRequested then
                        break
                    elseif self.Status == "Playing" then
                        local actionOk, actionResult = GameAdapter:Execute(action)
                        if not actionOk then
                            self.Status = "Error"
                            self.WorkerActive = false
                            self.StopRequested = false
                            State:Set("MacroStatus", "Error")
                            Logger:Error(string.format("Macro action failed: %s", tostring(actionResult)))
                            break
                        end
                    end
                end
            else
                task.wait(0.05)
            end
        end

        if self.TaskHandle then
            self.TaskHandle = nil
        end
    end)

    return true
end

function Player:Pause()
    if self.Status ~= "Playing" then
        return false, "Playback is not active."
    end

    self.Status = "Paused"
    self.IsPaused = true
    self.PauseStartedAt = os.clock()
    State:Set("MacroStatus", "PlaybackPaused")
    Logger:Warning("Playback paused")
    return true
end

function Player:Resume()
    if self.Status ~= "Paused" then
        return false, "Playback is not paused."
    end

    if self.PauseStartedAt then
        self.TotalPausedTime = self.TotalPausedTime + (os.clock() - self.PauseStartedAt)
        self.PauseStartedAt = nil
    end

    self.Status = "Playing"
    self.IsPaused = false
    State:Set("MacroStatus", "Playing")
    Logger:Play("Playback resumed")
    return true
end

function Player:Stop()
    self.StopRequested = true
    self.WorkerActive = false
    self.Status = "Stopped"
    self.IsPaused = false
    self.PauseStartedAt = nil
    State:Set("MacroStatus", "Stopped")
    Logger:Warning("Playback stopped")

    if self.TaskHandle then
        task.cancel(self.TaskHandle)
        self.TaskHandle = nil
    end

    return true
end

function Player:Repeat()
    if not self.CurrentMacro then
        return false, "No macro available to repeat."
    end

    self.RepeatEnabled = true
    if self.WorkerActive then return true end
    if self.Status == "Completed" or self.Status == "Stopped" or self.Status == "Idle" then
        self.CurrentActionIndex = 0
        return self:Start()
    end
    return true
end

function Player:SetRepeat(enabled)
    self.RepeatEnabled = enabled == true
    return true
end

function Player:Reset()
    self.CurrentMacro = nil
    self.CurrentActionIndex = 0
    self.Status = "Idle"
    self.IsPaused = false
    self.StopRequested = true
    self.WorkerActive = false
    self.PauseStartedAt = nil
    self.TotalPausedTime = 0
    self.RepeatEnabled = false
    State:Set("MacroStatus", "Idle")
    if self.TaskHandle then
        task.cancel(self.TaskHandle)
        self.TaskHandle = nil
    end
    return true
end

return Player
