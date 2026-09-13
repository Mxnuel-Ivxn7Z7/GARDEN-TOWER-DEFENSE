local ActionRegistry = {}
ActionRegistry.__index = ActionRegistry

ActionRegistry.Actions = {}

local function normalizeActionType(actionType)
    if type(actionType) ~= "string" then
        return ""
    end

    return string.upper(string.gsub(actionType, "%s+", "_"))
end

local function ensureActionDefinition(definition)
    if type(definition) == "function" then
        return {
            id = "UNKNOWN",
            name = "Unknown Action",
            description = "Action handler",
            requiredData = {},
            handler = definition,
            validate = function(data)
                return true
            end,
        }
    end

    if type(definition) ~= "table" then
        return nil
    end

    return {
        id = definition.id or "UNKNOWN",
        name = definition.name or "Unknown Action",
        description = definition.description or "Action",
        requiredData = definition.requiredData or {},
        handler = definition.handler or function()
            return true
        end,
        validate = definition.validate or function(data)
            return true
        end,
    }
end

function ActionRegistry:Clear()
    self.Actions = {}
    return true
end

function ActionRegistry:Register(actionType, definition)
    local normalizedType = normalizeActionType(actionType)
    if normalizedType == "" then
        return false, "Action type is required."
    end

    local actionDef = ensureActionDefinition(definition)
    if not actionDef then
        return false, "Action definition is invalid."
    end

    actionDef.id = normalizedType
    self.Actions[normalizedType] = actionDef
    return true
end

function ActionRegistry:Unregister(actionType)
    local normalizedType = normalizeActionType(actionType)
    if self.Actions[normalizedType] == nil then
        return false
    end

    self.Actions[normalizedType] = nil
    return true
end

function ActionRegistry:Get(actionType)
    local normalizedType = normalizeActionType(actionType)
    return self.Actions[normalizedType]
end

function ActionRegistry:Has(actionType)
    return self:Get(actionType) ~= nil
end

function ActionRegistry:Validate(action)
    if type(action) ~= "table" then
        return false, "Invalid Action Data"
    end

    local actionType = normalizeActionType(action.type)
    local definition = self:Get(actionType)
    if not definition then
        return false, "Unknown action type"
    end

    if type(action.data) ~= "table" then
        action.data = {}
    end

    for _, requiredField in ipairs(definition.requiredData or {}) do
        if action.data[requiredField] == nil then
            return false, "Missing required field: " .. tostring(requiredField)
        end
    end

    if type(definition.validate) == "function" then
        local ok, message = definition.validate(action)
        if ok == false then
            return false, message or "Action validation failed."
        end
    end

    return true
end

function ActionRegistry:GetSupported()
    local supported = {}
    for actionType in pairs(self.Actions) do
        table.insert(supported, actionType)
    end
    table.sort(supported)
    return supported
end

return ActionRegistry
