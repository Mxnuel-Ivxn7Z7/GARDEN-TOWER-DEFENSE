local Logger = {}
Logger.__index = Logger

Logger.Entries = {}
Logger.MaxEntries = 200
Logger.Listeners = {}

local levels = {
    INFO = "INFO",
    SUCCESS = "SUCCESS",
    WARNING = "WARNING",
    ERROR = "ERROR",
    RECORD = "RECORD",
    PLAY = "PLAY",
}

function Logger:Now()
    local timestamp = os.date("%H:%M:%S")
    return timestamp
end

local function emit(entry)
    for _, callback in ipairs(Logger.Listeners) do
        if type(callback) == "function" then
            callback(entry)
        end
    end
end

function Logger:Log(level, message)
    if level == nil then
        level = levels.INFO
    end

    if message == nil then
        message = ""
    end

    local entry = {
        timestamp = self:Now(),
        level = level,
        message = tostring(message),
    }

    table.insert(Logger.Entries, entry)

    if #Logger.Entries > Logger.MaxEntries then
        table.remove(Logger.Entries, 1)
    end

    emit(entry)
    return entry
end

function Logger:Info(message)
    return self:Log(levels.INFO, message)
end

function Logger:Success(message)
    return self:Log(levels.SUCCESS, message)
end

function Logger:Warning(message)
    return self:Log(levels.WARNING, message)
end

function Logger:Error(message)
    return self:Log(levels.ERROR, message)
end

function Logger:Record(message)
    return self:Log(levels.RECORD, message)
end

function Logger:Play(message)
    return self:Log(levels.PLAY, message)
end

function Logger:GetEntries()
    return Logger.Entries
end

function Logger:Clear()
    Logger.Entries = {}
    return true
end

function Logger:Subscribe(callback)
    if type(callback) ~= "function" then
        return false
    end

    table.insert(Logger.Listeners, callback)
    return callback
end

function Logger:Unsubscribe(callback)
    for index, listener in ipairs(Logger.Listeners) do
        if listener == callback then
            table.remove(Logger.Listeners, index)
            return true
        end
    end
    return false
end

return Logger
