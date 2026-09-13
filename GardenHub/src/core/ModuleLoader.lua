local ModuleLoader = {}
ModuleLoader.__index = ModuleLoader
ModuleLoader.Cache = {}

local function normalizePath(path)
    if type(path) ~= "string" then return "" end
    return path:gsub("\\", "/"):gsub("^%./", ""):gsub("^src/", ""):gsub("^src%.", ""):gsub("^GardenHub%.src%.", ""):gsub("^GardenHub%.", ""):gsub("/", "."):gsub("%.lua$", ""):gsub("^%.+", "")
end
local function getSourceRoot()
    local current = script
    while current do
        if current.Name == "src" and current:IsA("Folder") then return current end
        if current.Name == "GardenHub" then return current:FindFirstChild("src") end
        current = current.Parent
    end
    return nil
end
local function findModuleScript(path)
    local current, normalized = getSourceRoot(), normalizePath(path)
    if not current or normalized == "" then return nil end
    for segment in normalized:gmatch("[^.]+") do
        current = current:FindFirstChild(segment)
        if not current then return nil end
    end
    return current:IsA("ModuleScript") and current or nil
end
function ModuleLoader:Exists(path) return findModuleScript(path) ~= nil end
function ModuleLoader:Require(path)
    local normalized = normalizePath(path)
    if normalized == "" then return nil, "Module path is invalid." end
    if self.Cache[normalized] ~= nil then return self.Cache[normalized] end
    local moduleScript = findModuleScript(normalized)
    if not moduleScript then return nil, "Module not found: " .. normalized end
    local ok, result = pcall(function() return require(moduleScript) end)
    if not ok then return nil, result end
    self.Cache[normalized] = result
    return result
end
function ModuleLoader:Get(path) return self:Require(path) end
return ModuleLoader
