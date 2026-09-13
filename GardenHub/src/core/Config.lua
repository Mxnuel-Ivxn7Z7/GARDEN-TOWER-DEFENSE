local Config = {}
Config.__index = Config

Config.GameId = 7703614594
Config.GameName = "Garden Tower Defense"

Config.UI = {
    ThemeName = "Garden",
    MinimizeOnStart = false,
    ShowNotifications = true,
    ShowDebugInfo = false,
    RoundedCorners = true,
    PanelPadding = 12,
    TitleBarHeight = 32,
}

Config.Macro = {
    AutoPlay = false,
    ReplayMode = "Once",
    MaxActions = 2500,
    MaxLogEntries = 200,
    AutoSave = true,
    RequireNameValidation = true,
}

Config.Storage = {
    AutoSaveDelay = 1,
    FolderName = "GardenHub",
    MacroFile = "gardenhub_macros.json",
    SettingsFile = "gardenhub_settings.json",
}

Config.Debug = {
    Enabled = false,
    LogLevels = { "INFO", "SUCCESS", "WARNING", "ERROR", "RECORD", "PLAY" },
}

function Config:ApplyDefaults()
    self.UI = self.UI or {}
    self.Macro = self.Macro or {}
    self.Storage = self.Storage or {}
    self.Debug = self.Debug or {}

    local defaults = {
        UI = {
            ThemeName = "Garden",
            MinimizeOnStart = false,
            ShowNotifications = true,
            ShowDebugInfo = false,
            RoundedCorners = true,
            PanelPadding = 12,
            TitleBarHeight = 32,
        },
        Macro = {
            AutoPlay = false,
            ReplayMode = "Once",
            MaxActions = 2500,
            MaxLogEntries = 200,
            AutoSave = true,
            RequireNameValidation = true,
        },
        Storage = {
            AutoSaveDelay = 1,
            FolderName = "GardenHub",
            MacroFile = "gardenhub_macros.json",
            SettingsFile = "gardenhub_settings.json",
        },
        Debug = {
            Enabled = false,
            LogLevels = { "INFO", "SUCCESS", "WARNING", "ERROR", "RECORD", "PLAY" },
        },
    }

    for sectionName, sectionDefaults in pairs(defaults) do
        local currentSection = self[sectionName] or {}
        for key, value in pairs(sectionDefaults) do
            if currentSection[key] == nil then
                currentSection[key] = value
            end
        end
        self[sectionName] = currentSection
    end

    return self
end

function Config:Get(path, defaultValue)
    local current = self
    if path == nil or path == "" then
        return current
    end

    for segment in string.gmatch(path, "[^.]+") do
        if type(current) ~= "table" or current[segment] == nil then
            return defaultValue
        end
        current = current[segment]
    end

    return current
end

function Config:Set(path, value)
    local current = self
    local segments = {}

    for segment in string.gmatch(path, "[^.]+") do
        table.insert(segments, segment)
    end

    for index = 1, #segments - 1 do
        local segment = segments[index]
        if type(current[segment]) ~= "table" then
            current[segment] = {}
        end
        current = current[segment]
    end

    current[segments[#segments]] = value
    return value
end

function Config:Reset()
    self.UI = {
        ThemeName = "Garden",
        MinimizeOnStart = false,
        ShowNotifications = true,
        ShowDebugInfo = false,
        RoundedCorners = true,
        PanelPadding = 12,
        TitleBarHeight = 32,
    }

    self.Macro = {
        AutoPlay = false,
        ReplayMode = "Once",
        MaxActions = 2500,
        MaxLogEntries = 200,
        AutoSave = true,
        RequireNameValidation = true,
    }

    self.Storage = {
        AutoSaveDelay = 1,
        FolderName = "GardenHub",
        MacroFile = "gardenhub_macros.json",
        SettingsFile = "gardenhub_settings.json",
    }

    self.Debug = {
        Enabled = false,
        LogLevels = { "INFO", "SUCCESS", "WARNING", "ERROR", "RECORD", "PLAY" },
    }

    return self
end

return Config
