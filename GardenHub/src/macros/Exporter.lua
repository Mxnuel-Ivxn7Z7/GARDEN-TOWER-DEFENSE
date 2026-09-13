local Exporter = {}
Exporter.__index = Exporter

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local Serializer = ModuleLoader:Require("macros.Serializer")
local MacroStorage = ModuleLoader:Require("storage.MacroStorage")
local Logger = ModuleLoader:Require("core.Logger")

local function encodeShareCode(macro)
    if type(macro) ~= "table" then
        return nil, "Macro data is invalid."
    end

    local version = tonumber(macro.version) or 1
    local normalized = Serializer:MigrateVersion(macro)
    local serialized, err = Serializer:Serialize(normalized)
    if err then
        return nil, err
    end

    return string.format("GHM%d:%s", version, serialized), nil
end

function Exporter:ExportMacro(name)
    local macro = MacroStorage:LoadMacro(name)
    if not macro then
        return nil, "Macro not found."
    end

    local ok, message = Serializer:Validate(macro)
    if not ok then
        return nil, message
    end

    local code, err = encodeShareCode(macro)
    if err then
        return nil, err
    end

    Logger:Success(string.format("Macro exported: %s", name))
    return code
end

function Exporter:ExportAllMacros()
    local macros = MacroStorage:ListMacros()
    local results = {}
    for _, macro in ipairs(macros) do
        local code, err = encodeShareCode(macro)
        if code and not err then
            table.insert(results, { name = macro.name, code = code })
        end
    end

    Logger:Success(string.format("Exported %d macros.", #results))
    return results
end

return Exporter
