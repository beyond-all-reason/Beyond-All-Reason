local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Techup blocking",
		desc = "Tech-gates the labs/factories themselves (not the units they build) until an arbitrary tech level is reached via Keystone buildings",
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

if techMode == "0" or techMode == 0 or techMode == false or techMode == nil then
	return
end
local ModeEnums = VFS.Include("modules/context/mode_enums.lua")
local TechTier = VFS.Include("modules/tech/tier.lua")
local t2TechPerPlayer = tonumber(modOptions.t2_tech_threshold) or 1
local t3TechPerPlayer = tonumber(modOptions.t3_tech_threshold) or 2

local resolveByTechLevel = TechTier.resolveByTechLevel

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spSetTeamRulesParam = Spring.SetTeamRulesParam

local UPDATE_INTERVAL = Game.gameSpeed

local blockTechDefs = {}
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
local techCoreUnits = {}

local removeGadget = true
for unitDefID, unitDef in pairs(UnitDefs) do
	local customParams = unitDef.customParams
	if customParams then
		local techLevel = tonumber(customParams.techlevel) or 1
		-- only labs/factories are gated, never the units they build; build-menu tree still gates progression
		if techLevel >= 2 and unitDef.isFactory then
			removeGadget = false
			blockTechDefs[unitDefID] = techLevel
		end
		if customParams.tech_core_value and tonumber(customParams.tech_core_value) > 0 then
			removeGadget = false
			techCoreValueDefs[unitDefID] = tonumber(customParams.tech_core_value)
		end
	end
end
if removeGadget then
	gadgetHandler:RemoveGadget(gadget)
end

local ModuleHandler = VFS.Include("modules/module_handler.lua")
local ContextFactory = VFS.Include("modules/context/context_factory.lua")
ContextFactory.registerPolicyContextEnricher(function(ctx, springRepo, senderTeamID)
	local rawLevel = springRepo.GetTeamRulesParam(senderTeamID, "tech_level")
	local rawPoints = springRepo.GetTeamRulesParam(senderTeamID, "tech_points")
	local rawT2 = springRepo.GetTeamRulesParam(senderTeamID, "tech_t2_threshold")
	local rawT3 = springRepo.GetTeamRulesParam(senderTeamID, "tech_t3_threshold")
	local level = tonumber(rawLevel or 1) or 1
	local t2Thresh = tonumber(rawT2 or 0) or 0
	local t3Thresh = tonumber(rawT3 or 0) or 0
	local opts = springRepo.GetModOptions()

	-- The decision is declared in policies/tier.lua; this reads the rules
	-- params and hands them over, so the same answer is available to anything
	-- that can describe a team's tier — including a UI with no game running.
	local tier = ModuleHandler.Evaluate(ModuleHandler.LoadPolicies("tech").tech_core, {
		opts = opts,
		level = level,
		points = tonumber(rawPoints or 0) or 0,
		t2Threshold = t2Thresh,
		t3Threshold = t3Thresh,
	})

	ctx.ext.techBlocking = tier.blocking
	ctx.unitSharingModes = tier.modes
	if tier.taxRate and tier.taxRate >= 0 then
		ctx.taxRate = tier.taxRate
	end
end)

local allyTeamList = Spring.GetAllyTeamList()
for _, allyTeamID in ipairs(allyTeamList) do
	local teamList = Spring.GetTeamList(allyTeamID)
	allyWatch[allyTeamID] = teamList
end

-- set ally-group tech level: unlock labs <= level, re-block higher ones (reverts when Keystones lost)
local function setTechLevel(teamList, techLevel, notificationEvent)
	for _, teamID in ipairs(teamList) do
		if not ignoredTeams[teamID] then
			if notificationEvent then
				local players = Spring.GetPlayerList(teamID)
				if players then
					for _, playerID in ipairs(players) do
						SendToUnsynced("NotificationEvent", notificationEvent, tostring(playerID))
					end
				end
			end
			spSetTeamRulesParam(teamID, "tech_level", techLevel)

			for unitDefID, requiredLevel in pairs(blockTechDefs) do
				if requiredLevel <= techLevel then
					GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, "tech_level_" .. requiredLevel)
				else
					GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "tech_level_" .. requiredLevel)
				end
			end
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

function gadget:GameStart()
	local hasAPI = GG.BuildBlocking and GG.BuildBlocking.AddBlockedUnit

	if not hasAPI then
		return
	end

	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		if not ignoredTeams[teamID] then
			local rawLevel = spGetTeamRulesParam(teamID, "tech_level")
			local techLevel = tonumber(rawLevel or 1) or 1
			for unitDefID, requiredLevel in pairs(blockTechDefs) do
				if techLevel < requiredLevel then
					GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "tech_level_" .. requiredLevel)
				end
			end
		end
	end

	SendToUnsynced("TechBlockingGameStart", tostring(t2TechPerPlayer), tostring(t3TechPerPlayer))
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if techCoreValueDefs[unitDefID] and not ignoredTeams[unitTeam] then
		local allyTeam = spGetUnitAllyTeam(unitID)
		local coreValue = techCoreValueDefs[unitDefID]
		techCoreUnits[unitID] = { value = coreValue, allyTeam = allyTeam }
	end
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if ignoredTeams[unitTeam] then
		techCoreUnits[unitID] = nil
		return
	end
	if techCoreUnits[unitID] then
		techCoreUnits[unitID].allyTeam = spGetUnitAllyTeam(unitID)
	end
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	techCoreUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	if frame % UPDATE_INTERVAL ~= 0 then
		return
	end

	local allyTechCorePoints = {}
	for _, data in pairs(techCoreUnits) do
		allyTechCorePoints[data.allyTeam] = (allyTechCorePoints[data.allyTeam] or 0) + data.value
	end

	for allyTeamID, teamList in pairs(allyWatch) do
		local totalTechPoints = allyTechCorePoints[allyTeamID] or 0
		local activePlayerCount = 0
		local firstActiveTeamID ---@type integer?

		for _, teamID in ipairs(teamList) do
			if not ignoredTeams[teamID] then
				activePlayerCount = activePlayerCount + 1
				if not firstActiveTeamID then
					firstActiveTeamID = teamID
				end
				spSetTeamRulesParam(teamID, "tech_points", totalTechPoints)
			end
		end

		if firstActiveTeamID then
			local t2Threshold = t2TechPerPlayer * activePlayerCount
			local t3Threshold = t3TechPerPlayer * activePlayerCount

			for _, teamID in ipairs(teamList) do
				if not ignoredTeams[teamID] then
					spSetTeamRulesParam(teamID, "tech_t2_threshold", t2Threshold)
					spSetTeamRulesParam(teamID, "tech_t3_threshold", t3Threshold)
				end
			end

			local previousAllyTechLevel = tonumber(spGetTeamRulesParam(firstActiveTeamID, "tech_level")) or 1

			local targetTechLevel = 1
			if totalTechPoints >= t3Threshold then
				targetTechLevel = 3
			elseif totalTechPoints >= t2Threshold then
				targetTechLevel = 2
			end

			if targetTechLevel > previousAllyTechLevel then
				local notificationEvent = targetTechLevel == 3 and "Tech3TeamReached" or "Tech2TeamReached"
				setTechLevel(teamList, targetTechLevel, notificationEvent)
			elseif targetTechLevel < previousAllyTechLevel then
				local notificationEvent = previousAllyTechLevel == 3 and "Tech3TeamLost" or "Tech2TeamLost"
				setTechLevel(teamList, targetTechLevel, notificationEvent)
			end
		end
	end
end
