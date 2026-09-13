local MacroStorage = {}
MacroStorage.__index = MacroStorage

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local Serializer = ModuleLoader:Require("macros.Serializer")

local MemoryStorage = {
    Data = {},
    GetAll = function(self)
        if type(self.Data) ~= "table" then
            self.Data = {}
        end
        return self.Data
    end,
    SetAll = function(self, value)
        if type(value) ~= "table" then
            value = {}
        end
        self.Data = value
        return self.Data
    end,
    GetItem = function(self, key, default)
        if self.Data[key] == nil then
            return default
        end
        return self.Data[key]
    end,
    SetItem = function(self, key, value)
        self.Data[key] = value
        return value
    end,
    DeleteItem = function(self, key)
        self.Data[key] = nil
    end,
}

MacroStorage.Provider = MemoryStorage
MacroStorage.Macros = {}

local function storageKey(name)
    return tostring(name)
end

local function getProvider()
    if type(MacroStorage.Provider) == "table" then
        return MacroStorage.Provider
    end
    return MemoryStorage
end

local function ensureLoaded()
    local provider = getProvider()
    if provider and type(provider.GetAll) == "function" then
        local data = provider:GetAll()
        if type(data) ~= "table" then
            provider:SetAll({})
        end
    end
    if type(MacroStorage.Macros) ~= "table" then
        MacroStorage.Macros = {}
    end
end

function MacroStorage:SetProvider(provider)
    if type(provider) ~= "table" then
        return false, "Storage provider must be a table."
    end

    if type(provider.GetAll) ~= "function" or type(provider.SetAll) ~= "function" then
        return false, "Storage provider must implement GetAll/SetAll."
    end

    MacroStorage.Provider = provider
    ensureLoaded()
    return true
end

function MacroStorage:LoadAll()
    ensureLoaded()
    local provider = getProvider()
    if provider and type(provider.GetAll) == "function" then
        local data = provider:GetAll()
        if type(data) == "table" then
            MacroStorage.Macros = data
        end
    end
    return MacroStorage.Macros
end

function MacroStorage:SaveMacro(macro)
    if type(macro) ~= "table" or type(macro.name) ~= "string" then
        return false
    end

    ensureLoaded()
    local normalized = Serializer:MigrateVersion(macro)
    local key = storageKey(normalized.name)
    MacroStorage.Macros[key] = normalized

    local provider = getProvider()
    if provider and type(provider.SetAll) == "function" then
        provider:SetAll(MacroStorage.Macros)
    end

    return true
end

function MacroStorage:LoadMacro(name)
    ensureLoaded()
    return MacroStorage.Macros[storageKey(name)]
end

function MacroStorage:ListMacros()
    ensureLoaded()
    local list = {}
    for _, macro in pairs(MacroStorage.Macros) do
        table.insert(list, macro)
    end
    table.sort(list, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function MacroStorage:DeleteMacro(name)
    ensureLoaded()
    if self:Exists(name) then
        MacroStorage.Macros[storageKey(name)] = nil

        local provider = getProvider()
        if provider and type(provider.SetAll) == "function" then
            provider:SetAll(MacroStorage.Macros)
        end

        return true
    end
    return false
end

function MacroStorage:Exists(name)
    ensureLoaded()
    return MacroStorage.Macros[storageKey(name)] ~= nil
end

function MacroStorage:UpdateMacro(name, macro)
    if type(macro) ~= "table" then
        return false
    end

    if not self:Exists(name) then
        return false
    end

    macro.name = name
    return self:SaveMacro(macro)
end

return MacroStorage
