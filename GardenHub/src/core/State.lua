local State = {}
State.__index = State

State.Values = {}
State.Listeners = {}

local function notify(key)
    local listeners = State.Listeners[key] or {}
    for _, callback in ipairs(listeners) do
        if type(callback) == "function" then
            callback(State.Values[key])
        end
    end
end

function State:Set(key, value)
    if key == nil then
        return nil
    end

    State.Values[key] = value
    notify(key)
    return value
end

function State:Get(key, defaultValue)
    if State.Values[key] == nil then
        return defaultValue
    end

    return State.Values[key]
end

function State:Subscribe(key, callback)
    if type(key) ~= "string" or type(callback) ~= "function" then
        return false
    end

    if State.Listeners[key] == nil then
        State.Listeners[key] = {}
    end

    table.insert(State.Listeners[key], callback)
    return true
end

function State:Unsubscribe(key, callback)
    if State.Listeners[key] == nil then
        return false
    end

    for index, value in ipairs(State.Listeners[key]) do
        if value == callback then
            table.remove(State.Listeners[key], index)
            return true
        end
    end

    return false
end

function State:Reset()
    State.Values = {}
    State.Listeners = {}
    return true
end

function State:Snapshot()
    local snapshot = {}
    for key, value in pairs(State.Values) do
        snapshot[key] = value
    end
    return snapshot
end

return State
