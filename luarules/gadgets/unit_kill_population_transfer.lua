

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

-- Local copies of spring/recoil functions
local spTransferTeamMaxUnits = Spring.TransferTeamMaxUnits

-- One-off spring calls
local modOptions = Spring.GetModOptions()
local GaiaTeamID = Spring.GetGaiaTeamID()
local GaiaAllyTeamID = select(6, Spring.GetTeamInfo(GaiaTeamID))

-- Local long running variables
local killedTeamToCountTable = {} -- either the teamID of the killed player in gaia-mode, or killedTeam..attackerTeam to count in transfer mode

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
    if modOptions.population_transfer == "disabled" or modOptions.population_transfer == nil then
        return
    end

    -- could argue in gaia mode you might not need an attackerTeam but lava cases could punish you unnecessarily then
    if unitTeam == nil or attackerTeam == nil then
        return
    end

    local transferIncrement = nil
    if modOptions.population_transfer == "reduce" then
        killedTeamToCountTable[unitTeam] = (killedTeamToCountTable[unitTeam] == nil and modOptions.population_transfer_ratio) or killedTeamToCountTable[unitTeam] + modOptions.population_transfer_ratio;
        if killedTeamToCountTable[unitTeam] / modOptions.population_transfer_ratio > 1 then
            transferIncrement = 1
            killedTeamToCountTable[unitTeam] = 0
        end
    elseif modOptions.population_transfer == "transfer" then
        killedTeamToCountTable[unitTeam..attackerTeam] = (killedTeamToCountTable[unitTeam..attackerTeam] == nil and 1) or killedTeamToCountTable[unitTeam..attackerTeam] + 1;
        if killedTeamToCountTable[unitTeam..attackerTeam] / modOptions.population_transfer_ratio > 1 then
            transferIncrement = 1
            killedTeamToCountTable[unitTeam..attackerTeam] = 0
        end
    end

    if (transferIncrement < 1) then
        return
    end

    if modOptions.population_transfer_ratio > 0 then
        if modOptions.population_transfer == "reduce" then
            spTransferTeamMaxUnits(unitTeam, GaiaTeamID, 1);
        elseif modOptions.population_transfer == "transfer" then
            spTransferTeamMaxUnits(unitTeam, attackerTeam, 1);
        end
    else
        -- is this legit? Can I reduce from Gaia?
        if modOptions.population_transfer == "reduce" then
            -- spTransferTeamMaxUnits(unitTeam, GaiaTeamID, -1);
        elseif modOptions.population_transfer == "transfer" then
            spTransferTeamMaxUnits(unitTeam, attackerTeam, -1);
        end
    end
end


