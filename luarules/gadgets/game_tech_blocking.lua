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
local techBlockingPerTeam = modOptions.tech_blocking_per_team or false
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
local allyXPGains = {}
local allyTechCorePoints = {}

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
			Spring.Echo("Tech points gain found for ", unitDef.name, ": ", tostring(customParams.tech_points_gain))
			removeGadget = false
			local techXP = tonumber(customParams.tech_points_gain)
			techPointsGeneratorDefs[unitDefID] = techXP
		end
		if customParams.tech_core_value then
			Spring.Echo("Tech core value found for ", unitDef.name, ": ", tostring(customParams.tech_core_value))
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

local function increaseTechLevel(teamList, notificationEvent, techLevel)
	for _, teamID in ipairs(teamList) do
		if not ignoredTeams[teamID] then
			local players = Spring.GetPlayerList(teamID)
			if players then
				for _, playerID in ipairs(players) do
					SendToUnsynced("NotificationEvent", notificationEvent, tostring(playerID))
				end
			end
			spSetTeamRulesParam(teamID, "tech_level", techLevel)
		end
	end
end

function gadget:Initialize()
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		if not ignoredTeams[teamID] then
			spSetTeamRulesParam(teamID, "tech_points", 0)
			spSetTeamRulesParam(teamID, "tech_level", 1)
		end
	end

	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeam = Spring.GetUnitTeam(unitID)
		if unitDefID and unitTeam then
			gadget:UnitFinished(unitID, unitDefID, unitTeam)
		end
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	local power = UnitDefs[unitDefID].power
	if power then
		local allyTeam = spGetUnitAllyTeam(unitID)
		for _, teamID in ipairs(allyWatch[allyTeam]) do
			local currentPoints = spGetTeamRulesParam(teamID, "tech_points") or 0
			allyXPGains[teamID] = (allyXPGains[teamID] or currentPoints) + power * unitCreationRewardMultiplier
		end
	end
	if techPointsGeneratorDefs[unitDefID] and not ignoredTeams[unitTeam] then
		xpGenerators[unitID] = {gain = techPointsGeneratorDefs[unitDefID], allyTeam = spGetUnitAllyTeam(unitID)}
	end
	if techCoreValueDefs[unitDefID] and not ignoredTeams[unitTeam] then
		local allyTeam = spGetUnitAllyTeam(unitID)
		local coreValue = techCoreValueDefs[unitDefID]
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
		local newAllyTeam = spGetUnitAllyTeam(unitID)
		techCoreUnits[unitID].allyTeam = newAllyTeam
	end
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	xpGenerators[unitID] = nil
	techCoreUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % UPDATE_INTERVAL ~= 0 then
		return
	end

	for unitID, data in pairs(xpGenerators) do
		for _, teamID in ipairs(allyWatch[data.allyTeam]) do
			allyXPGains[data.allyTeam] = (allyXPGains[data.allyTeam] or 0) + data.gain
		end
	end

	allyTechCorePoints = {}
	for unitID, data in pairs(techCoreUnits) do
		allyTechCorePoints[data.allyTeam] = (allyTechCorePoints[data.allyTeam] or 0) + data.value
	end


	for allyTeamID, teamList in pairs(allyWatch) do
		local techCorePoints = allyTechCorePoints[allyTeamID] or 0
		local techXPPoints = allyXPGains[allyTeamID] or 0
		local totalTechPoints = techCorePoints + techXPPoints
		local activeTeamCount = 0

		for _, teamID in ipairs(teamList) do
			if not ignoredTeams[teamID] then
				activeTeamCount = activeTeamCount + 1
				spSetTeamRulesParam(teamID, "tech_points", totalTechPoints)
			end
		end

		local adjustedT2Threshold = techBlockingPerTeam and t2TechThreshold or (t2TechThreshold * activeTeamCount)
		local adjustedT3Threshold = techBlockingPerTeam and t3TechThreshold or (t3TechThreshold * activeTeamCount)

		if activeTeamCount > 0 then
			local previousAllyTechLevel = spGetTeamRulesParam(teamList[1], "tech_level") or 1
			local techLevel = 1
			if totalTechPoints >= adjustedT3Threshold then
				techLevel = 3
				if techLevel > previousAllyTechLevel then
					increaseTechLevel(teamList, "Tech3TeamReached", techLevel)
				end
			elseif totalTechPoints >= adjustedT2Threshold then
				techLevel = 2
				if techLevel > previousAllyTechLevel then
					increaseTechLevel(teamList, "Tech2TeamReached", techLevel)
				end
			end
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