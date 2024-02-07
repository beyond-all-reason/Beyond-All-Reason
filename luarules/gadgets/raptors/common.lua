local Set                   = VFS.Include('common/SetList.lua').NewSetListMin

local GetGaiaTeamID = Spring.GetGaiaTeamID
local GetTeamList = Spring.GetTeamList
local GetTeamLuaAI = Spring.GetTeamLuaAI

local WALLS                     = Set()
WALLS:Add("armdrag")
WALLS:Add("armfort")
WALLS:Add("cordrag")
WALLS:Add("corfort")
WALLS:Add("scavdrag")
WALLS:Add("scavfort")

local raptorTeamID
local teams = GetTeamList()
for _, teamID in ipairs(teams) do
	local teamLuaAI = GetTeamLuaAI(teamID)
	if (teamLuaAI and string.find(teamLuaAI, "Raptors")) then
		raptorTeamID = teamID
	end
end
if not raptorTeamID then
	raptorTeamID = GetGaiaTeamID()
end


function IsWall(unitDef)
    return WALLS.hash[unitDef.name] ~= nil
end

-- Calculate an eco value based on energy and metal production
-- Echo("Built units eco value: " .. ecoValue)

-- Ends up building an object like:
-- {
--  0: [non-eco]
--	25: [t1 windmill, t1 solar, t1 mex],
--	75: [adv solar]
--	1000: [fusion]
--	3000: [adv fusion]
-- }
function EcoValueDef(unitDef)

    if IsValidEcoUnitDef(unitDef) then
		return 0
	end

	local ecoValue = 1
	if unitDef.energyMake then
		ecoValue = ecoValue + unitDef.energyMake
	end
	if unitDef.energyUpkeep and unitDef.energyUpkeep < 0 then
		ecoValue = ecoValue - unitDef.energyUpkeep
	end
	if unitDef.windGenerator then
		ecoValue = ecoValue + unitDef.windGenerator * 0.75
	end
	if unitDef.tidalGenerator then
		ecoValue = ecoValue + unitDef.tidalGenerator * 15
	end
	if unitDef.extractsMetal and unitDef.extractsMetal > 0 then
		ecoValue = ecoValue + 200
	end
	if unitDef.customParams and unitDef.customParams.energyconv_capacity then
		ecoValue = ecoValue + tonumber(unitDef.customParams.energyconv_capacity) / 2
	end

	-- Decoy fusion support
	if unitDef.customParams and unitDef.customParams.decoyfor == "armfus" then
		ecoValue = ecoValue + 1000
	end

	-- Make it extra risky to build T2 eco
	if unitDef.customParams and unitDef.customParams.techlevel and tonumber(unitDef.customParams.techlevel) > 1 then
		ecoValue = ecoValue * tonumber(unitDef.customParams.techlevel) * 2
	end

	-- Anti-nuke - add value to force players to go T2 economy, rather than staying T1
	if unitDef.customParams and (unitDef.customParams.unitgroup == "antinuke" or unitDef.customParams.unitgroup == "nuke") then
		ecoValue = 1000
	end

	return ecoValue
end

function IsValidEcoUnitDef(unitDef, teamID)
	-- skip Raptor AI, moving units and player built walls
	if (teamID and teamID == raptorTeamID) or unitDef.canMove or WALLS.hash[unitDef.name] ~= nil then
		return false
	end
	return true
end