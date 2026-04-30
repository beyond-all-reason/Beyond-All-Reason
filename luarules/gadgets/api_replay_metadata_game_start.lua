local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name    = "Replay - Game start info",
        desc    = "Logs the info of game start in replay metadata",
        author  = "uBdead",
        date    = "February 2026",
        license = "GNU GPL, v2 or later",
        layer   = 0,
        enabled = true
    }
end

if gadgetHandler:IsSyncedCode() then
    -- SYNCED --
    return
end

-- UNSYNCED --
local data = {}

function gadget:Initialize()
    data.mapName = Game.mapName
    data.gameVersion = Game.gameVersion

    if not os then
        Spring.Log("ReplayMetadata", LOG.ERROR, "os library is not (yet) available, cannot log game start time")
        return
    end

    data.gameLoaded = os.time() -- epoch

    GG.ReplayMetadata.SetReplayMetadata("gameInfo", data)
end

function gadget:GameStart()
    local teamList = Spring.GetTeamList()
    data.teams = {}
    data.gameStarted = os.time() -- epoch
    local gaiaTeamID = Spring.GetGaiaTeamID and Spring.GetGaiaTeamID() or 666
    for _, teamID in ipairs(teamList) do
        if teamID ~= gaiaTeamID then
            local x, y, z = Spring.GetTeamStartPosition(teamID)
            local _, _, _, isAI, side = Spring.GetTeamInfo(teamID, false)
            local players = {}
            if isAI then
                local _, _, _, aiName = Spring.GetAIInfo(teamID)
                local niceName = Spring.GetGameRulesParam('ainame_' .. teamID)
                if niceName then
                    aiName = tostring(niceName)
                end
                aiName = aiName or "AI"
                table.insert(players, {
                    id = teamID,
                    name = aiName,
                    isAI = true,
                })
            else
                local playerList = Spring.GetPlayerList(teamID) or {}
                for _, playerID in ipairs(playerList) do
                    local name = Spring.GetPlayerInfo(playerID, false)
                    if GG.playernames and GG.playernames.getPlayername then
                        name = GG.playernames.getPlayername(playerID) or name
                    end
                    table.insert(players, {
                        id = playerID,
                        name = name,
                        isAI = false,
                    })
                end
            end

            local r,g,b,a = Spring.GetTeamColor(teamID)
            r = math.floor(r * 255)
            g = math.floor(g * 255)
            b = math.floor(b * 255)
            a = math.floor(a * 255)

            data.teams[teamID] = {
                players = players,
                startPos = { x, y, z },
                faction = side,
                color = { r, g, b, a }
            }
        end
    end

    GG.ReplayMetadata.SetReplayMetadata("gameInfo", data)
end
