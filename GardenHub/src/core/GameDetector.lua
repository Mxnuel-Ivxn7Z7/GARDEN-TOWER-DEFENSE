local GameDetector = {}
GameDetector.__index = GameDetector

local TARGET_GAME_ID = 7703614594
local TARGET_GAME_NAME = "Garden Tower Defense"

local function safeGameId()
    if game == nil or (typeof and typeof(game) ~= "Instance") then return nil end
    local ok, gameId = pcall(function() return game.GameId end)
    return ok and tonumber(gameId) or nil
end

function GameDetector:IsValidGame()
    local detectedId = safeGameId()
    if detectedId == nil then
        return false, "Unable to read GameId."
    end

    if detectedId ~= TARGET_GAME_ID then
        return false, string.format(
            "Invalid game detected. Expected %s (%s), got %s.",
            TARGET_GAME_ID,
            TARGET_GAME_NAME,
            tostring(detectedId)
        )
    end

    return true, TARGET_GAME_NAME
end

function GameDetector:GetGameInfo()
    return {
        id = safeGameId(),
        name = TARGET_GAME_NAME,
        expectedId = TARGET_GAME_ID,
    }
end

return GameDetector
