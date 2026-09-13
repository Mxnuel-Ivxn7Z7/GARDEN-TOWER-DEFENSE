local ModuleLoader = {}
ModuleLoader.__index = ModuleLoader

local GITHUB_USER = "Mxnuel-Ivxn7Z7"
local GITHUB_REPO = "GARDEN-TOWER-DEFENSE"
local GITHUB_BRANCH = "main"
local BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/GardenHub/src/", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH)

local cache = {}

function ModuleLoader:Require(modulePath)
    if cache[modulePath] then
        return cache[modulePath]
    end

    local relativePath = string.gsub(modulePath, "%.", "/") .. ".lua"
    local url = BASE_URL .. relativePath

    local success, response = pcall(function()
        return game:HttpGet(url)
    end)

    if not success or not response or string.find(response, "404: Not Found") then
        return nil, "Módulo no encontrado en GitHub: " .. relativePath
    end

    local fn, syntaxErr = loadstring(response)
    if not fn then
        return nil, "Error de sintaxis en " .. relativePath .. ": " .. tostring(syntaxErr)
    end

    local execSuccess, result = pcall(fn)
    if not execSuccess then
        return nil, "Error al ejecutar " .. relativePath .. ": " .. tostring(result)
    end

    cache[modulePath] = result
    return result
end

return ModuleLoader
