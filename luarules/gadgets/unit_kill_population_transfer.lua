

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Killed Population Count Transfer",
		desc = "Allows modifying population count to or from killed units allyteam or to Gaia",
		author = "Chemdude8",
		date = "2026-05-06",
		license = "None",
		layer = 49,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end




-- Can use Spring.GetTeamMaxUnits to get number of popcap
-- how do we listen on chat messages?


-- Local copies of spring/recoil functions
local spTransferTeamMaxUnits = Spring.TransferTeamMaxUnits
local spGetTeamMaxUnits = Spring.GetTeamMaxUnits
local spGetPlayerInfo = Spring.GetPlayerInfo
local spGetTeamList = Spring.GetTeamList

-- One-off spring calls
local modOptions = Spring.GetModOptions()
local GaiaTeamID = Spring.GetGaiaTeamID()

-- Local long running variables
local killedTeamToCountTable = {} -- either the teamID of the killed player in gaia-mode, or killedTeam..attackerTeam to count in transfer mode
local rebalanceCommand = 'rebalancepopulation'


-- Only intended to fix the pop-cap loss on take/take2 player reconnect
	local function rebalancePopulation(cmd, line, words, playerID)
		
        -- get the allyPlayerIds for the allyTeam which contains the playerID
        local _, _, _, allyTeamID = spGetPlayerInfo(playerID)
        local allyIDs = spGetTeamList(allyTeamID)
        -- looks like {1: {2000, 100}}, {teamID: {currentMaxPop, currentInUsePop}}
        local allyPlayerIDsToPopInfo = {}
        local totalAllyTeamPop = 0
        if not allyIDs then
            return
        end

        for i in #allyIDs do
            allyPlayerIDsToPopInfo[allyIDs[i]].popInfo = {spGetTeamMaxUnits(allyIDs[i])}
            totalAllyTeamPop = totalAllyTeamPop + allyPlayerIDsToPopInfo[allyIDs[i]].popInfo[1]
        end

        local averageTeamPop = totalAllyTeamPop / #allyIDs
        -- woot, eep might want to hold the totals for available/needed here in case they dont line up.
        -- teamID to positive amount to send
        local capfrom = {}
        -- teamID to negative amount needed
        local capto = {}
        for i in #allyIDs do
            -- allyPlayerIDsToPopInfo[allyIDs[i]].popInfo.capdiff = averageTeamPop - allyPlayerIDsToPopInfo[allyIDs[i]].popInfo[1]
            local capdiff = averageTeamPop - allyPlayerIDsToPopInfo[allyIDs[i]].popInfo[1]
            if capdiff > 0 then
                if allyPlayerIDsToPopInfo[allyIDs[i]].popInfo[2] < averageTeamPop then
                    local availtosend = averageTeamPop - allyPlayerIDsToPopInfo[allyIDs[i]].popInfo[2]
                    allyPlayerIDsToPopInfo[allyIDs[i]].popInfo.shouldsend = (capdiff < availtosend and capdiff) or availtosend
                    capfrom[allyIDs[i] ] = allyPlayerIDsToPopInfo[allyIDs[i]].popInfo.shouldsend

                end
            else if allyPlayerIDsToPopInfo[allyIDs[i]].popInfo.capdiff < 0 then
                capto[allyIDs[i] ] = capdiff
            end
        end

        -- need the average amount we actually have to make other teams whole based on available pop


        
        -- divide by allyTeamCount, initiate transfers to teams that have less than average from teams above average (checking for available)




        
	end

	function gadget:Initialize()
		gadgetHandler:AddChatAction(rebalanceCommand, rebalancePopulation, "Evenly rebalance allyTeam population counts if possible.")
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction(rebalanceCommand)
	end



function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    if modOptions.populationtransfer == "disabled" or modOptions.populationtransfer == nil or modOptions.populationtransferratio == 0 then
        return
    end

    -- could argue in gaia mode you might not need an attackerTeam but lava cases could punish you unnecessarily then
    if unitTeam == nil or attackerTeam == nil then
        return
    end

    local transferIncrement = nil
    if modOptions.populationtransfer == "reduce" then
        
        killedTeamToCountTable[unitTeam] = (killedTeamToCountTable[unitTeam] == nil and modOptions.populationtransferratio) or killedTeamToCountTable[unitTeam] + modOptions.populationtransferratio;
        if math.abs(killedTeamToCountTable[unitTeam]) >= 1 then
            transferIncrement = 1
            killedTeamToCountTable[unitTeam] = 0
        end
    elseif modOptions.populationtransfer == "transfer" then
        killedTeamToCountTable[unitTeam..attackerTeam] = (killedTeamToCountTable[unitTeam..attackerTeam] == nil and modOptions.populationtransferratio) or killedTeamToCountTable[unitTeam..attackerTeam] + modOptions.populationtransferratio;
        if math.abs(killedTeamToCountTable[unitTeam..attackerTeam]) >= 1 then
            transferIncrement = 1
            killedTeamToCountTable[unitTeam..attackerTeam] = 0
        end
    end

    if (transferIncrement == nil or math.abs(transferIncrement) < 1) then
        return
    end

    if modOptions.populationtransferratio > 0 then
        if modOptions.populationtransfer == "reduce" then
            spTransferTeamMaxUnits(unitTeam, GaiaTeamID, 1);
        elseif modOptions.populationtransfer == "transfer" then
            spTransferTeamMaxUnits(unitTeam, attackerTeam, 1);
        end
    else
        -- is this legit? Can I reduce/take from Gaia? not allowing this for now.
        if modOptions.populationtransfer == "reduce" then
            -- spTransferTeamMaxUnits(GaiaTeamID, unitTeam, 1);
        elseif modOptions.populationtransfer == "transfer" then
            spTransferTeamMaxUnits(attackerTeam, unitTeam, 1);
        end
    end
end


