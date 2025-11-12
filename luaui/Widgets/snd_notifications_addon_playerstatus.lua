function widget:GetInfo()
    return {
    name      = "Player Status Notifications",
    desc      = "Sends player status events to the Notification Widget",
    author    = "Damgam",
    date      = "2025",
    layer     = 5,
    enabled   = true  --  loaded by default?
    }
end


-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spEcho = Spring.Echo
local spGetSpectatingState = Spring.GetSpectatingState

PlayersInformationMemory = {}

function UpdatePlayerData(playerID)
    if playerID then
        local playerName = select(1, Spring.GetPlayerInfo(playerID))
        --spEcho("Player Changed", playerID, playerName)

        if not PlayersInformationMemory[playerName] then PlayersInformationMemory[playerName] = {} end

        PlayersInformationMemory[playerName].id = playerID
        PlayersInformationMemory[playerName].spectator =  select(3, Spring.GetPlayerInfo(playerID))
        PlayersInformationMemory[playerName].teamID =  select(4, Spring.GetPlayerInfo(playerID))
        PlayersInformationMemory[playerName].allyTeamID =  select(5, Spring.GetPlayerInfo(playerID))
        PlayersInformationMemory[playerName].ping =  select(6, Spring.GetPlayerInfo(playerID))
    end
end


function ComparePlayerData(playerID)
    if playerID then
        local Differences = {}

        local playerName = select(1, Spring.GetPlayerInfo(playerID))

        local id = playerID
        local spectator = select(3, Spring.GetPlayerInfo(playerID))
        local teamID = select(4, Spring.GetPlayerInfo(playerID))
        local allyTeamID = select(5, Spring.GetPlayerInfo(playerID))
        local ping = select(6, Spring.GetPlayerInfo(playerID))

        if id ~= PlayersInformationMemory[playerName].id then Differences["id"] = true end
        if spectator ~= PlayersInformationMemory[playerName].spectator then Differences["spectator"] = spectator end
        if teamID ~= PlayersInformationMemory[playerName].teamID then Differences["teamID"] = teamID end
        if allyTeamID ~= PlayersInformationMemory[playerName].allyTeamID then Differences["allyteamid"] = allyTeamID end
        if ping then Differences["ping"] = ping end

        return Differences
    end
    return {}
end

UpdateTimer = 0
function widget:Update(dt)
    UpdateTimer = UpdateTimer+dt
    if UpdateTimer >= 1 then
        UpdateTimer = UpdateTimer - 1
        for playerName, data in pairs(PlayersInformationMemory) do
            local ping = select(6, Spring.GetPlayerInfo(data.id))
            if ping and ping > 10 and not PlayersInformationMemory[playerName].timingout then
                if (not PlayersInformationMemory[playerName].spectator) and (not PlayersInformationMemory[playerName].resigned) and PlayersInformationMemory[playerName].allyTeamID == Spring.GetLocalAllyTeamID() and not spGetSpectatingState() then
                    --spEcho("Teammate Lagging", playerID, playerName)
                    WG['notifications'].queueNotification("TeammateLagging")
                end
                PlayersInformationMemory[playerName].timingout = true
            elseif ping and ping <= 2 and PlayersInformationMemory[playerName].timingout and (not PlayersInformationMemory[playerName].hasDisconnected) then
                if (not PlayersInformationMemory[playerName].spectator) and (not PlayersInformationMemory[playerName].resigned) and PlayersInformationMemory[playerName].allyTeamID == Spring.GetLocalAllyTeamID() and not spGetSpectatingState() then
                    --spEcho("Teammate Catched Up", playerID, playerName)
                    WG['notifications'].queueNotification("TeammateCaughtUp")
                end
                PlayersInformationMemory[playerName].timingout = false
            end
        end
    end
end

function widget:Initialize()
    local players = Spring.GetPlayerList()
    for i = 1,#players do
        UpdatePlayerData(players[i])
    end
end

function widget:PlayerChanged(playerID)
    if playerID then
        local playerName = select(1, Spring.GetPlayerInfo(playerID))
        local Differences = {}
        if PlayersInformationMemory[playerName] then
            Differences = ComparePlayerData(playerID)

            if (not PlayersInformationMemory[playerName].resigned) and PlayersInformationMemory[playerName].allyTeamID == Spring.GetLocalAllyTeamID() and not spGetSpectatingState() then
                if Differences.spectator then
                    --spEcho("Teammate Resigned", playerName, spGetGameFrame())
                    WG['notifications'].queueNotification("TeammateResigned", true)
                    PlayersInformationMemory[playerName].resigned = true

                    -- TeammateResigned
                end
                if PlayersInformationMemory[playerName].hasDisconnected and (not (Differences.spectator or PlayersInformationMemory[playerName].spectator)) then
                    --spEcho("Teammate Reconnected", playerName, spGetGameFrame())
                    WG['notifications'].queueNotification("TeammateReconnected", true)
                    PlayersInformationMemory[playerName].hasDisconnected = false
                    -- TeammateReconnected
                end
            end
        end
        
        UpdatePlayerData(playerID)
    end
end

function widget:PlayerRemoved(playerID)
    if playerID then
        local playerName = select(1, Spring.GetPlayerInfo(playerID))
        --local Differences = {}
        if PlayersInformationMemory[playerName] then
            --Differences = ComparePlayerData(playerID)

            if (not PlayersInformationMemory[playerName].spectator) and (not PlayersInformationMemory[playerName].resigned) and PlayersInformationMemory[playerName].allyTeamID == Spring.GetLocalAllyTeamID() and not spGetSpectatingState()then
                if PlayersInformationMemory[playerName].timingout then
                    --spEcho("Teammate Timedout", playerName, spGetGameFrame())
                    WG['notifications'].queueNotification("TeammateTimedout", true)
                    -- TeammateTimedout
                else
                    --spEcho("Teammate Disconnected", playerName, spGetGameFrame())
                    WG['notifications'].queueNotification("TeammateDisconnected", true)
                    -- TeammateDisconnected
                end
                PlayersInformationMemory[playerName].hasDisconnected = true
            end
        end

        UpdatePlayerData(playerID)
    end
end