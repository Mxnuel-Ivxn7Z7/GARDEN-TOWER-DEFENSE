    local Serializer = {}

local function deepClone(value, seen)
    seen = seen or {}

    local valueType = type(value)
    if valueType ~= "table" then
        return value
    end

    if seen[value] then
        return seen[value]
    end

    local clone = {}
    seen[value] = clone

    for key, item in pairs(value) do
        clone[key] = deepClone(item, seen)
    end

    return clone
end

local function getHttpService()
    if game == nil then
        return nil
    end

    local ok, service = pcall(function()
        return game:GetService("HttpService")
    end)

    if not ok or service == nil then
        return nil
    end

    return service
end

local function normalizeTable(value)
    if type(value) ~= "table" then
        return {}
    end

    return deepClone(value)
end

function Serializer:Serialize(data)
    if type(data) ~= "table" then
        return nil, "Macro is invalid."
    end

    local structured = self:MigrateVersion(data)
    local service = getHttpService()
    if service ~= nil then
        local ok, encoded = pcall(function()
            return service:JSONEncode(structured)
        end)

        if ok and type(encoded) == "string" and encoded ~= "" then
            return encoded
        end

        return nil, "HttpService JSONEncode failed."
    end

    return nil, "HttpService unavailable"
end

function Serializer:Deserialize(data)
    if type(data) ~= "string" or data == "" then
        return nil, "No macro data supplied."
    end

    local service = getHttpService()
    if service ~= nil then
        local ok, decoded = pcall(function()
            return service:JSONDecode(data)
        end)

        if ok and type(decoded) == "table" then
            return decoded
        end

        return nil, "Unable to decode macro data."
    end

    return nil, "Unable to decode macro data."
end

function Serializer:Validate(data)
    if type(data) ~= "table" then
        return false, "Macro payload must be a table."
    end

    if data.format ~= "GHM" then
        return false, "Invalid macro format."
    end

    if tonumber(data.version) ~= 1 then
        return false, "Unsupported macro version."
    end

    if type(data.name) ~= "string" or data.name == "" then
        return false, "Macro name is required."
    end

    if type(data.actions) ~= "table" then
        return false, "Macro actions are missing."
    end

    for index, action in ipairs(data.actions) do
        if type(action) ~= "table" then
            return false, "Invalid action at index " .. tostring(index)
        end

        if type(action.type) ~= "string" or action.type == "" then
            return false, "Invalid action at index " .. tostring(index)
        end

        if type(action.timestamp) ~= "number" or action.timestamp < 0 then
            return false, "Invalid action at index " .. tostring(index)
        end

        if type(action.delay) ~= "number" or action.delay < 0 then
            return false, "Invalid action at index " .. tostring(index)
        end

        if type(action.data) ~= "table" then
            return false, "Invalid action at index " .. tostring(index)
        end
    end

    return true
end

function Serializer:Clone(data)
    if type(data) ~= "table" then
        return nil
    end

    return deepClone(data)
end

function Serializer:MigrateVersion(data)
    if type(data) ~= "table" then
        return nil
    end

    local migrated = normalizeTable(data)
    migrated.format = migrated.format or "GHM"
    migrated.version = tonumber(migrated.version) or 1
    migrated.name = migrated.name or "Untitled Macro"
    migrated.actions = type(migrated.actions) == "table" and migrated.actions or {}

    if type(migrated.game) ~= "table" then
        migrated.game = {
            name = "Garden Tower Defense",
            gameId = 7703614594,
        }
    end

    return migrated
end

return Serializer
