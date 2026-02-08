local widget = widget ---@type Widget

function widget:GetInfo()
    return {
      name = "Replay - Game start info",
      desc = "Logs the info of game start in replay metadata",
      author = "uBdead",
      date = "February 2026",
      license = "GNU GPL, v2 or later",
      layer = 0,
      enabled = true
    }
end

function widget:GameStart()
    local teamList = Spring.GetTeamList()
    local gameStart = {
        map = Game.mapName,
        datetimeGameStart = os.date("!%Y-%m-%dT%H:%M:%SZ"), -- use UTC time to avoid timezone issues
        teams = {}
    }
    for _, teamID in ipairs(teamList) do
        local x, y, z = Spring.GetTeamStartPosition(teamID)
        local playerName = Spring.GetPlayerInfo(Spring.GetTeamList()[1], false) -- get the name of the first player in the team
        gameStart['teams'][teamID] = {
            playerName = playerName,
            startPos = {x, y, z},
        }
    end
    if WG.ReplayMetadata then
        local metadata = WG.ReplayMetadata.GetReplayMetadata() or {}
        metadata.gameStart = gameStart
        WG.ReplayMetadata.SetReplayMetadata(metadata)
        
        WG.ReplayMetadata.SaveReplayMetadata() -- debug 
    else
        Spring.Echo("ReplayMetadata API is not available, cannot save start positions")
    end
end
