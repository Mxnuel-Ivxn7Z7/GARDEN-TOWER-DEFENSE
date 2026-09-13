local Importer = {}
Importer.__index = Importer

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local Serializer = ModuleLoader:Require("macros.Serializer")
local Logger = ModuleLoader:Require("core.Logger")
local MacroStorage = ModuleLoader:Require("storage.MacroStorage")

local function stripPrefix(code)
    if type(code) ~= "string" then
        return ""
    end

    return string.gsub(string.gsub(code, '^%s+', ''), '%s+$', '')
end

local function parseShareCode(code)
    local cleaned = stripPrefix(code)
    if cleaned == "" then
        return nil, "Share code is empty."
    end

    local prefix = "GHM1:"
    if string.sub(cleaned, 1, #prefix) ~= prefix then
        return nil, "Unsupported macro prefix."
    end

    local payload = string.sub(cleaned, #prefix + 1)
    if payload == "" then
        return nil, "Missing macro payload."
    end

    local decoded, err = Serializer:Deserialize(payload)
    if err or type(decoded) ~= "table" then
        return nil, err or "Malformed macro payload."
    end

    return decoded
end

function Importer:Validate(code)
    local macro, err = parseShareCode(code)
    if err then
        return false, err
    end

    local ok, validationMessage = Serializer:Validate(macro)
    if not ok then
        return false, validationMessage
    end

    return true
end

function Importer:Import(code, duplicateAction)
    if type(code) ~= "string" then
        return false, "Import data is invalid."
    end

    local macro, err = parseShareCode(code)
    if err then
        return false, err
    end

    local ok, validationMessage = Serializer:Validate(macro)
    if not ok then
        return false, validationMessage
    end

    local exists = MacroStorage:Exists(macro.name)
    if exists then
        if duplicateAction == "rename" then
            macro.name = macro.name .. " Imported"
        elseif duplicateAction == "cancel" then
            Logger:Warning("Import cancelled due to duplicate macro name.")
            return false, "Import cancelled."
        elseif duplicateAction == "replace" then
            MacroStorage:DeleteMacro(macro.name)
        else
            return false, "Duplicate macro found; choose rename, replace, or cancel."
        end
    end

    local saved = MacroStorage:SaveMacro(macro)
    if not saved then
        return false, "Macro import failed."
    end

    Logger:Success(string.format("Macro imported: %s", macro.name))
    return macro
end

return Importer
