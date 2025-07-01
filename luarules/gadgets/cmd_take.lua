--------------------------------------------------------------------------------
-- V2
--------------------------------------------------------------------------------
--
--  name      = "Take Command",
--  desc      = "Provides the /take command to transfer units and resources from allied teams without active players.",
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name = "Take Command",
        desc = "Provides the /take command to transfer units and resources from allied teams without active players.",
        author = "Google",
        date = "2024-07-17",
        license = "GNU GPL, v2 or later",
        layer = 1,
        enabled = true,
    }
end

--------------------------------------------------------------------------------
-- SYNCED
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
    local spGetPlayerInfo = Spring.GetPlayerInfo
    local spGetTeamInfo = Spring.GetTeamInfo
    local spGetTeamList = Spring.GetTeamList
    local spGetPlayerList = Spring.GetPlayerList
    local spGetTeamUnits = Spring.GetTeamUnits
    local spTransferUnit = Spring.TransferUnit
    local spAddTeamResource = Spring.AddTeamResource
    local spSendToPlayer = Spring.SendMessageToPlayer
    local GG = gadgetHandler.GG

    local function takeCommand(playerID, targetTeamID_str, playerData)
        local pTeamID, pAllyTeamID = playerData.teamID, playerData.allyTeamID
        if not pTeamID then
            return
        end

        local targetTeamID = (targetTeamID_str and targetTeamID_str ~= "") and tonumber(targetTeamID_str) or nil

        local takeableTeamIDs = {}

        if targetTeamID then
            local _, _, _, _, _, targetAllyTeamID = spGetTeamInfo(targetTeamID)
            if pAllyTeamID ~= targetAllyTeamID then
                spSendToPlayer(playerID, "You can only take from allied teams.")
                return
            end
            table.insert(takeableTeamIDs, targetTeamID)
        else
            for _, teamID in ipairs(spGetTeamList(pAllyTeamID)) do
                if teamID ~= pTeamID then
                    local hasHumanPlayer = false
                    for _, playerIDOnTeam in ipairs(spGetPlayerList(teamID, false)) do
                        local _, _, _, _, _, _, isAI = spGetPlayerInfo(playerIDOnTeam)
                        if type(isAI) ~= 'boolean' or isAI == false then
                            hasHumanPlayer = true
                            break
                        end
                    end

                    if not hasHumanPlayer then
                        table.insert(takeableTeamIDs, teamID)
                    end
                end
            end
        end

        if #takeableTeamIDs == 0 then
            spSendToPlayer(playerID, "No uncontrolled teams to take from.")
            return
        end

        for _, teamID in ipairs(takeableTeamIDs) do
            local teamUnits = spGetTeamUnits(teamID)
            for _, unitID in ipairs(teamUnits) do
                spTransferUnit(unitID, pTeamID, false, 0)
            end

            for _, resType in ipairs({ "metal", "energy" }) do
                local resValue = select(1, Spring.GetTeamResources(teamID, resType))
                if resValue and resValue > 0 then
                    spAddTeamResource(teamID, resType, -resValue)
                    spAddTeamResource(pTeamID, resType, resValue)
                end
            end
        end
    end

    function gadget:GotChatMsg(msg, playerID)
        if string.sub(msg, 1, 4) == "take" then
            local targetTeam = string.sub(msg, 5):match("^%s*(%d*)%s*$")

            local actualPlayerID = -1
            local playerData = {}
            if playerID == 0 then
                for _, pid in ipairs(Spring.GetPlayerList()) do
                    local name, active, spec, teamID, allyTeamID, income, isAI = Spring.GetPlayerInfo(pid)
                    if type(isAI) ~= 'boolean' or isAI == false then
                        actualPlayerID = pid
                        playerData = { teamID = teamID, allyTeamID = allyTeamID }
                        break
                    end
                end
            else
				actualPlayerID = playerID
                _, _, _, playerData.teamID, playerData.allyTeamID = Spring.GetPlayerInfo(actualPlayerID)
			end
			
			if actualPlayerID == -1 then
				return
			end

            takeCommand(actualPlayerID, targetTeam, playerData)
            return true
        end
        return false
    end

else -- UNSYNCED

    function gadget:GotChatMsg(msg, playerID)
        if string.sub(msg, 1, 4) == "take" then
            local targetTeam = string.sub(msg, 5):match("^%s*(%d*)%s*$")
            Spring.SendLuaRulesMsg("take:" .. (targetTeam or ""))
            return true
        end
        return false
    end

end 