local SettingsStorage = {}
SettingsStorage.__index = SettingsStorage

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
}

SettingsStorage.Provider = MemoryStorage
SettingsStorage.Settings = {}

local function getProvider()
    if type(SettingsStorage.Provider) == "table" then
        return SettingsStorage.Provider
    end
    return MemoryStorage
end

local function ensureTable()
    if type(SettingsStorage.Settings) ~= "table" then
        SettingsStorage.Settings = {}
    end
end

function SettingsStorage:SetProvider(provider)
    if type(provider) ~= "table" then
        return false, "Storage provider must be a table."
    end

    if type(provider.GetAll) ~= "function" or type(provider.SetAll) ~= "function" then
        return false, "Storage provider must implement GetAll/SetAll."
    end

    SettingsStorage.Provider = provider
    ensureTable()
    return true
end

function SettingsStorage:Load()
    ensureTable()
    local provider = getProvider()
    if provider and type(provider.GetAll) == "function" then
        local data = provider:GetAll()
        if type(data) == "table" then
            SettingsStorage.Settings = data
        end
    end
    return SettingsStorage.Settings
end

function SettingsStorage:Save(settingTable)
    if type(settingTable) ~= "table" then
        return false
    end

    ensureTable()
    SettingsStorage.Settings = settingTable

    local provider = getProvider()
    if provider and type(provider.SetAll) == "function" then
        provider:SetAll(SettingsStorage.Settings)
    end

    return true
end

function SettingsStorage:Reset()
    SettingsStorage.Settings = {}

    local provider = getProvider()
    if provider and type(provider.SetAll) == "function" then
        provider:SetAll(SettingsStorage.Settings)
    end

    return true
end

return SettingsStorage
