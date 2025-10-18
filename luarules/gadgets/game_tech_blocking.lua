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

local blockTechDefs = {}
local techPointsGeneratorDefs = {}
local techCoreValueDefs = {}
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

local allyWatch = {}
local xpGenerators = {}
local techCoreUnits = {}
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
		if customParams.tech_core_value then
			removeGadget = false
			local coreValue = tonumber(customParams.tech_core_value)
			techCoreValueDefs[unitDefID] = coreValue
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

function gadget:Initialize()
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		if not ignoredTeams[teamID] then
			spSetTeamRulesParam(teamID, "tech_points", 0)
			spSetTeamRulesParam(teamID, "tech_level", 1)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local power = UnitDefs[unitDefID].power
	if power then
		local allyTeam = spGetUnitAllyTeam(unitID)
		for _, teamID in ipairs(allyWatch[allyTeam]) do
			local currentPoints = spGetTeamRulesParam(teamID, "tech_points") or 0
			allyGains[teamID] = (allyGains[teamID] or currentPoints) + power * unitCreationRewardMultiplier
		end
	end
	if techPointsGeneratorDefs[unitDefID] and not ignoredTeams[unitTeam] then
		xpGenerators[unitID] = {gain = techPointsGeneratorDefs[unitDefID], allyTeam = spGetUnitAllyTeam(unitID)}
	end
	if techCoreValueDefs[unitDefID] and not ignoredTeams[unitTeam] then
		local allyTeam = spGetUnitAllyTeam(unitID)
		local coreValue = techCoreValueDefs[unitDefID]
		for _, teamID in ipairs(allyWatch[allyTeam]) do
			local currentPoints = spGetTeamRulesParam(teamID, "tech_points") or 0
			allyGains[teamID] = (allyGains[teamID] or currentPoints) + coreValue
		end
		techCoreUnits[unitID] = {value = coreValue, allyTeam = allyTeam}
	end
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if ignoredTeams[unitTeam] then
		xpGenerators[unitID] = nil
		techCoreUnits[unitID] = nil
		return
	elseif xpGenerators[unitID] then
		xpGenerators[unitID] = {gain = techPointsGeneratorDefs[unitDefID], allyTeam = spGetUnitAllyTeam(unitID)}
	end
	if techCoreUnits[unitID] then
		local coreData = techCoreUnits[unitID]
		local newAllyTeam = spGetUnitAllyTeam(unitID)
		if coreData.allyTeam ~= newAllyTeam then
			for _, teamID in ipairs(allyWatch[coreData.allyTeam]) do
				local currentPoints = spGetTeamRulesParam(teamID, "tech_points") or 0
				allyGains[teamID] = (allyGains[teamID] or currentPoints) - coreData.value
			end
			for _, teamID in ipairs(allyWatch[newAllyTeam]) do
				local currentPoints = spGetTeamRulesParam(teamID, "tech_points") or 0
				allyGains[teamID] = (allyGains[teamID] or currentPoints) + coreData.value
			end
			techCoreUnits[unitID].allyTeam = newAllyTeam
		end
	end
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	xpGenerators[unitID] = nil
	if techCoreUnits[unitID] then
		local coreData = techCoreUnits[unitID]
		for _, teamID in ipairs(allyWatch[coreData.allyTeam]) do
			local currentPoints = spGetTeamRulesParam(teamID, "tech_points") or 0
			allyGains[teamID] = (allyGains[teamID] or currentPoints) - coreData.value
		end
		techCoreUnits[unitID] = nil
	end
end

function gadget:GameFrame(frame)
	if frame % UPDATE_INTERVAL ~= 0 then
		return
	end

	for unitID, data in pairs(xpGenerators) do
		for _, teamID in ipairs(allyWatch[data.allyTeam]) do
			local currentTechPoints = spGetTeamRulesParam(teamID, "tech_points") or 0
			allyGains[teamID] = (allyGains[teamID] or currentTechPoints) + data.gain
		end
	end

	for teamID, gain in pairs(allyGains) do
		spSetTeamRulesParam(teamID, "tech_points", math.floor(gain))
	end
	allyGains = {}

	for allyTeamID, teamList in pairs(allyWatch) do
		local totalTechPoints = 0
		local activeTeamCount = 0
		local teamTechPoints = {}

		for _, teamID in ipairs(teamList) do
			if not ignoredTeams[teamID] then
				local currentTechPoints = spGetTeamRulesParam(teamID, "tech_points") or 0
				teamTechPoints[teamID] = currentTechPoints
				totalTechPoints = totalTechPoints + currentTechPoints
				activeTeamCount = activeTeamCount + 1
			end
		end

		local adjustedT2Threshold = t2TechThreshold * activeTeamCount
		local adjustedT3Threshold = t3TechThreshold * activeTeamCount

		local techLevel = 1
		if totalTechPoints >= adjustedT3Threshold then
			techLevel = 3
		elseif totalTechPoints >= adjustedT2Threshold then
			techLevel = 2
		end

		for teamID, currentTechPoints in pairs(teamTechPoints) do
			spSetTeamRulesParam(teamID, "tech_level", techLevel)
		end
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