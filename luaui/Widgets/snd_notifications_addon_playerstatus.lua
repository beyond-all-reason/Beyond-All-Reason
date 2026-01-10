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
local spGetSpectatingState = Spring.GetSpectatingState
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetLocalAllyTeamID = Spring.GetLocalAllyTeamID

local gameOver = false

PlayersInformationMemory = {}

function UpdatePlayerData(playerID)
    if playerID then
        local playerName = select(1, spGetPlayerInfo(playerID))
        --spEcho("Player Changed", playerID, playerName)

        if not PlayersInformationMemory[playerName] then PlayersInformationMemory[playerName] = {} end

        PlayersInformationMemory[playerName].id = playerID
        PlayersInformationMemory[playerName].spectator =  select(3, spGetPlayerInfo(playerID))
        PlayersInformationMemory[playerName].teamID =  select(4, spGetPlayerInfo(playerID))
        PlayersInformationMemory[playerName].allyTeamID =  select(5, spGetPlayerInfo(playerID))
        PlayersInformationMemory[playerName].ping =  select(6, spGetPlayerInfo(playerID))
    end
end


function ComparePlayerData(playerID)
    if playerID then
        local Differences = {}

        local playerName = select(1, spGetPlayerInfo(playerID))

        local id = playerID
        local spectator = select(3, spGetPlayerInfo(playerID))
        local teamID = select(4, spGetPlayerInfo(playerID))
        local allyTeamID = select(5, spGetPlayerInfo(playerID))
        local ping = select(6, spGetPlayerInfo(playerID))

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
    if UpdateTimer >= 1 and (not gameOver) then
        UpdateTimer = UpdateTimer - 1
        for playerName, data in pairs(PlayersInformationMemory) do
            local ping = select(6, spGetPlayerInfo(data.id))
            if ping and ping > 10 and not PlayersInformationMemory[playerName].timingout then
                if (not PlayersInformationMemory[playerName].spectator) and (not PlayersInformationMemory[playerName].resigned) then
                    if spGetSpectatingState() then
                        WG['notifications'].queueNotification("NeutralPlayerLagging")
                    elseif PlayersInformationMemory[playerName].allyTeamID == spGetLocalAllyTeamID() then
                        WG['notifications'].queueNotification("TeammateLagging")
                    else
                        WG['notifications'].queueNotification("EnemyPlayerLagging")
                    end
                end
                PlayersInformationMemory[playerName].timingout = true
            elseif ping and ping <= 2 and PlayersInformationMemory[playerName].timingout and (not PlayersInformationMemory[playerName].hasDisconnected) then
                if (not PlayersInformationMemory[playerName].spectator) and (not PlayersInformationMemory[playerName].resigned) then
                    if spGetSpectatingState() then
                        WG['notifications'].queueNotification("NeutralPlayerCaughtUp")
                    elseif PlayersInformationMemory[playerName].allyTeamID == spGetLocalAllyTeamID() then
                        WG['notifications'].queueNotification("TeammateCaughtUp")
                    else
                        WG['notifications'].queueNotification("EnemyPlayerCaughtUp")
                    end
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
    if playerID and (not gameOver) then
        local playerName = select(1, spGetPlayerInfo(playerID))
        local Differences = {}
        if PlayersInformationMemory[playerName] then
            Differences = ComparePlayerData(playerID)

            if (not PlayersInformationMemory[playerName].resigned) then
                if Differences.spectator then
                    if spGetSpectatingState() then
                        WG['notifications'].queueNotification("NeutralPlayerResigned", true)
                    elseif PlayersInformationMemory[playerName].allyTeamID == spGetLocalAllyTeamID() then
                        WG['notifications'].queueNotification("TeammateResigned", true)
                    else
                        WG['notifications'].queueNotification("EnemyPlayerResigned", true)
                    end
                    PlayersInformationMemory[playerName].resigned = true
                end
                if PlayersInformationMemory[playerName].hasDisconnected and (not (Differences.spectator or PlayersInformationMemory[playerName].spectator)) then
                    if spGetSpectatingState() then
                        WG['notifications'].queueNotification("NeutralPlayerReconnected", true)
                    elseif PlayersInformationMemory[playerName].allyTeamID == spGetLocalAllyTeamID() then
                        WG['notifications'].queueNotification("TeammateReconnected", true)
                    else
                        WG['notifications'].queueNotification("EnemyPlayerReconnected", true)
                    end
                    PlayersInformationMemory[playerName].hasDisconnected = false
                end
            end
        end
        
        UpdatePlayerData(playerID)
    end
end

function widget:PlayerRemoved(playerID)
    if playerID and (not gameOver) then
        local playerName = select(1, spGetPlayerInfo(playerID))
        --local Differences = {}
        if PlayersInformationMemory[playerName] then
            --Differences = ComparePlayerData(playerID)

            if (not PlayersInformationMemory[playerName].spectator) and (not PlayersInformationMemory[playerName].resigned) then
                if PlayersInformationMemory[playerName].timingout then
                    if spGetSpectatingState() then
                        WG['notifications'].queueNotification("NeutralPlayerTimedout", true)
                    elseif PlayersInformationMemory[playerName].allyTeamID == spGetLocalAllyTeamID() then
                        WG['notifications'].queueNotification("TeammateTimedout", true)
                    else
                        WG['notifications'].queueNotification("EnemyPlayerTimedout", true)
                    end
                else
                    if spGetSpectatingState() then
                        WG['notifications'].queueNotification("NeutralPlayerDisconnected", true)
                    elseif PlayersInformationMemory[playerName].allyTeamID == spGetLocalAllyTeamID() then
                        WG['notifications'].queueNotification("TeammateDisconnected", true)
                    else
                        WG['notifications'].queueNotification("EnemyPlayerDisconnected", true)
                    end
                end
                PlayersInformationMemory[playerName].hasDisconnected = true
            end
        end

        UpdatePlayerData(playerID)
    end
end

function widget:GameOver(winningAllyTeams)
    gameOver = true
end