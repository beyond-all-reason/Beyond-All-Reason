local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Techup blocking",
		desc = "Prevents units from being built until an arbitrary tech level is reached",
		author = "SethDGamre",
		date = "October 2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local modOptions = Spring.GetModOptions()
local techMode = modOptions.tech_blocking
local t2TechThreshold = modOptions.t2_tech_threshold or 100
local t3TechThreshold = modOptions.t3_tech_threshold or 1000
local unitCreationRewardMultiplier = modOptions.unit_creation_reward_multiplier or 0

if not techMode then
	return
end

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spSetTeamRulesParam = Spring.SetTeamRulesParam

local UPDATE_INTERVAL = Game.gameSpeed

--static tables
local blockTechDefs = {}
local techPointsGeneratorDefs = {}
local ignoredTeams = {
	[Spring.GetGaiaTeamID()] = true,
}
local scavTeamID = Spring.Utilities.GetScavTeamID()
if scavTeamID then
	ignoredTeams[scavTeamID] = true
end
local raptorTeamID = Spring.Utilities.GetRaptorTeamID()
if raptorTeamID then
	ignoredTeams[raptorTeamID] = true
end

--active tables
local allyWatch = {}
local xpGenerators = {}
local allyGains = {}

local removeGadget = true
for unitDefID, unitDef in pairs(UnitDefs) do
	local customParams = unitDef.customParams
	if customParams then
		if customParams.tech_build_blocked_until_level then
			removeGadget = false
			local techLevel = tonumber(customParams.tech_build_blocked_until_level)
			blockTechDefs[unitDefID] = techLevel
		end
		if customParams.tech_points_gain then
			removeGadget = false
			local techXP = tonumber(customParams.tech_points_gain)
			techPointsGeneratorDefs[unitDefID] = techXP
		end
	end
end
if removeGadget then
	gadgetHandler:RemoveGadget(gadget)
end

local allyTeamList = Spring.GetAllyTeamList()
for _, allyTeamID in ipairs(allyTeamList) do
	local teamList = Spring.GetTeamList(allyTeamID)
	allyWatch[allyTeamID] = teamList
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local power = UnitDefs[unitDefID].power
	if power then
		local allyTeam = spGetUnitAllyTeam(unitID)
		for _, teamID in ipairs(allyWatch[allyTeam]) do
			allyGains[teamID] = spGetTeamRulesParam(teamID, "tech_points") + power * unitCreationRewardMultiplier
		end
	end
	if techPointsGeneratorDefs[unitDefID] and not ignoredTeams[unitTeam] then
		xpGenerators[unitID] = {gain = techPointsGeneratorDefs[unitDefID], allyTeam = spGetUnitAllyTeam(unitID)}
	end
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if ignoredTeams[unitTeam] then
		xpGenerators[unitID] = nil
		return
	elseif xpGenerators[unitID] then
		xpGenerators[unitID] = {gain = techPointsGeneratorDefs[unitDefID], allyTeam = spGetUnitAllyTeam(unitID)}
	end
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	xpGenerators[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % UPDATE_INTERVAL ~= 0 then
		return
	end

	for unitID, data in pairs(xpGenerators) do
		for _, teamID in ipairs(allyWatch[data.allyTeam]) do
			local currentTechPoints = spGetTeamRulesParam(teamID, "tech_points")
			allyGains[teamID] = currentTechPoints + data.gain
		end
	end

	for teamID, gain in pairs(allyGains) do
		spSetTeamRulesParam(teamID, "tech_points", math.floor(gain)) -- we assign it once to prevent losses from math.floor on incrimental fractions
	end
	allyGains = {}

	for allyTeamID, teamList in pairs(allyWatch) do
		local techLevel = 1
		local currentTechPoints = 0
		for _, teamID in ipairs(teamList) do
			currentTechPoints = spGetTeamRulesParam(teamID, "tech_points")
			if currentTechPoints >= t3TechThreshold then
				techLevel = 3
			elseif currentTechPoints >= t2TechThreshold then
				techLevel = 2
			end
			spSetTeamRulesParam(teamID, "tech_level", techLevel)
		end
		Spring.Echo("Ally Team " .. allyTeamID .. " tech level: " .. techLevel, "Tech points: " .. currentTechPoints)
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID)
	if cmdID < 0 then
		local buildUnitDefID = -cmdID
		if not blockTechDefs[buildUnitDefID] then
			return true
		end
		local techLevel = spGetTeamRulesParam(unitTeam, "tech_level")
		if techLevel < blockTechDefs[buildUnitDefID] then
			return false
		end
	end
	return true
end