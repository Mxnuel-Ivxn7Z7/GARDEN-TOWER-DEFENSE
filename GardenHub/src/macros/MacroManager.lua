local MacroManager = {}
MacroManager.__index = MacroManager

local ModuleLoader = _G.GardenHub and _G.GardenHub.ModuleLoader or error("GardenHub ModuleLoader not initialized")
local State = ModuleLoader:Require("core.State")
local Logger = ModuleLoader:Require("core.Logger")
local Serializer = ModuleLoader:Require("macros.Serializer")
local MacroStorage = ModuleLoader:Require("storage.MacroStorage")

MacroManager.SelectedName = nil
MacroManager.Macros = {}

local function normalizeName(name)
    if type(name) ~= "string" then
        return ""
    end

    return string.gsub(name, "%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

function MacroManager:SetSelected(name)
    local cleanedName = normalizeName(name)
    self.SelectedName = cleanedName ~= "" and cleanedName or nil
    State:Set("SelectedMacro", self.SelectedName)
    return cleanedName
end

function MacroManager:GetSelected()
    if self.SelectedName then
        return self:Get(self.SelectedName)
    end

    local first = self:GetAll()[1]
    if first then
        self.SelectedName = first.name
        State:Set("SelectedMacro", first.name)
        return first
    end

    return nil
end

function MacroManager:GetAll()
    local macros = MacroStorage:ListMacros()
    self.Macros = macros
    return macros
end

function MacroManager:Get(name)
    local cleanedName = normalizeName(name)
    if cleanedName == "" then
        return nil
    end

    return MacroStorage:LoadMacro(cleanedName)
end

function MacroManager:Validate(name, macro)
    if type(name) == "string" then
        local cleanedName = normalizeName(name)
        if cleanedName == "" then
            return false, "Macro name cannot be empty."
        end

        if #cleanedName > 64 then
            return false, "Macro name is too long."
        end

        if string.find(cleanedName, "[\x00-	\x0B\x0C\x0E-\x1F\x7F]") then
            return false, "Macro name contains invalid characters."
        end
    end

    if type(macro) == "table" then
        local ok, message = Serializer:Validate(macro)
        if not ok then
            return false, message
        end
    end

    return true
end

function MacroManager:Create(name)
    local cleanedName = normalizeName(name)
    local ok, message = self:Validate(cleanedName)
    if not ok then
        return false, message
    end

    if MacroStorage:Exists(cleanedName) then
        return false, "A macro with the same name already exists."
    end

    local macro = {
        format = "GHM",
        version = 1,
        name = cleanedName,
        game = {
            name = "Garden Tower Defense",
            gameId = 7703614594,
        },
        createdAt = os.time(),
        updatedAt = os.time(),
        settings = {
            replayMode = "Once",
        },
        actions = {},
    }

    local saved, saveError = MacroStorage:SaveMacro(macro)
    if not saved then
        local errorMessage = saveError or "Failed to create macro."
        Logger:Error(errorMessage)
        return false, errorMessage
    end
    self.SelectedName = cleanedName
    State:Set("SelectedMacro", cleanedName)
    Logger:Success(string.format("Macro created: %s", cleanedName))

    return macro
end

function MacroManager:Save(macro)
    if type(macro) ~= "table" then
        return false, "Macro is invalid."
    end

    local ok, message = self:Validate(macro.name, macro)
    if not ok then
        return false, message
    end

    macro.updatedAt = os.time()
    macro.actionCount = #(macro.actions or {})
    local result = MacroStorage:SaveMacro(macro)
    if not result then
        Logger:Error("Failed to save macro.")
        return false, "Failed to save macro."
    end
    State:Set("SelectedMacro", macro.name)
    Logger:Success(string.format("Macro saved: %s", macro.name))
    return true, "Saved"
end

function MacroManager:Delete(name)
    local cleanedName = normalizeName(name)
    if cleanedName == "" then
        return false, "Invalid macro name."
    end

    local deleted = MacroStorage:DeleteMacro(cleanedName)
    if deleted then
        if self.SelectedName == cleanedName then
            self.SelectedName = nil
            State:Set("SelectedMacro", nil)
        end
        Logger:Warning(string.format("Macro deleted: %s", cleanedName))
    end

    return deleted
end

function MacroManager:Duplicate(name)
    local source = self:Get(name)
    if not source then
        return false, "Macro not found."
    end

    local duplicateName = string.format("%s Copy", source.name)
    local index = 1
    while MacroStorage:Exists(duplicateName) do
        index = index + 1
        duplicateName = string.format("%s Copy %d", source.name, index)
    end

    local clone = Serializer:Clone(source)
    if not clone then
        return false, "Failed to clone macro."
    end
    clone.name = duplicateName
    clone.createdAt = os.time()
    clone.updatedAt = os.time()

    local ok = MacroStorage:SaveMacro(clone)
    if ok then
        Logger:Info(string.format("Macro duplicated: %s", duplicateName))
    end

    if not ok then return false, "Failed to duplicate macro." end
    return clone
end

function MacroManager:Load(name)
    local macro = self:Get(name)
    if not macro then
        return false, "Macro not found."
    end

    self.SelectedName = macro.name
    State:Set("SelectedMacro", macro.name)
    return macro
end

return MacroManager
