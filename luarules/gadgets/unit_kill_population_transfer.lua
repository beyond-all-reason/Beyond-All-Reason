

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

-- Local long running variables
local killedTeamToCountTable = {} -- either the teamID of the killed player in gaia-mode, or killedTeam..attackerTeam to count in transfer mode

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


