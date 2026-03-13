local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Techup blocking",
		desc = "Prevents units from being built until an arbitrary tech level is reached via Catalyst buildings",
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
local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")
local t2TechPerPlayer = tonumber(modOptions.t2_tech_threshold) or 1
local t3TechPerPlayer = tonumber(modOptions.t3_tech_threshold) or 2

--- Resolve a modOption value that varies by tech level.
--- Checks _at_t3 then _at_t2 overrides before falling back to the base key.
local function resolveByTechLevel(opts, baseKey, techLevel)
	if techLevel >= 3 then
		local v = opts[baseKey .. "_at_t3"]
		if v ~= nil and v ~= "" then return v end
	end
	if techLevel >= 2 then
		local v = opts[baseKey .. "_at_t2"]
		if v ~= nil and v ~= "" then return v end
	end
	return opts[baseKey]
end

local ContextFactory = VFS.Include("common/luaUtilities/team_transfer/context_factory.lua")
ContextFactory.registerPolicyContextEnricher(function(ctx, springRepo, senderTeamID)
	local rawLevel = springRepo.GetTeamRulesParam(senderTeamID, "tech_level")
	local rawPoints = springRepo.GetTeamRulesParam(senderTeamID, "tech_points")
	local rawT2 = springRepo.GetTeamRulesParam(senderTeamID, "tech_t2_threshold")
	local rawT3 = springRepo.GetTeamRulesParam(senderTeamID, "tech_t3_threshold")
	local level = tonumber(rawLevel or 1) or 1
	local t2Thresh = tonumber(rawT2 or 0) or 0
	local t3Thresh = tonumber(rawT3 or 0) or 0
	local opts = springRepo.GetModOptions()

	local nextLevel = level < 2 and 2 or 3
	local nextThreshold = nextLevel == 2 and t2Thresh or t3Thresh

	local function findNextProgression(baseKey, currentValue, normalize)
		for scanLevel = level + 1, 3 do
			local futureValue = resolveByTechLevel(opts, baseKey, scanLevel)
			if normalize then futureValue = normalize(futureValue) end
			if futureValue ~= nil and futureValue ~= currentValue then
				local thresh = scanLevel == 2 and t2Thresh or t3Thresh
				return { unlockLevel = scanLevel, unlockThreshold = thresh, unlockValue = futureValue }
			end
		end
		return nil
	end

	-- Build cumulative sharing modes array from each tier
	local modes = {}
	local baseMode = opts["unit_sharing_mode"]
	if baseMode and baseMode ~= "" and baseMode ~= ModeEnums.UnitFilterCategory.None then
		modes[#modes + 1] = baseMode
	end
	local t2Mode = opts["unit_sharing_mode_at_t2"]
	if level >= 2 and t2Mode and t2Mode ~= "" then
		modes[#modes + 1] = t2Mode
	end
	local t3Mode = opts["unit_sharing_mode_at_t3"]
	if level >= 3 and t3Mode and t3Mode ~= "" then
		modes[#modes + 1] = t3Mode
	end
	if #modes == 0 then modes = {ModeEnums.UnitFilterCategory.None} end

	-- Find next unit sharing mode addition (what mode gets added at the next level)
	local unitUnlock = nil
	for scanLevel = level + 1, 3 do
		local nextMode = opts["unit_sharing_mode_at_t" .. scanLevel]
		if nextMode and nextMode ~= "" then
			local thresh = scanLevel == 2 and t2Thresh or t3Thresh
			unitUnlock = { unlockLevel = scanLevel, unlockThreshold = thresh, unlockValue = nextMode }
			break
		end
	end

	local currentTax = tonumber(resolveByTechLevel(opts, "tax_resource_sharing_amount", level))
	local taxUnlock = findNextProgression("tax_resource_sharing_amount", currentTax, tonumber)

	ctx.ext.techBlocking = {
		level = level,
		points = tonumber(rawPoints or 0) or 0,
		t2Threshold = t2Thresh,
		t3Threshold = t3Thresh,
		nextLevel = nextLevel,
		nextThreshold = nextThreshold,
		unitTransfer = unitUnlock,
		metalTransfer = taxUnlock,
		energyTransfer = taxUnlock,
	}

	ctx.unitSharingModes = modes
	if currentTax and currentTax >= 0 then
		ctx.taxRate = currentTax
	end

end)

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
local blockCount, coreCount = 0, 0
for unitDefID, unitDef in pairs(UnitDefs) do
	local customParams = unitDef.customParams
	if customParams then
		local techLevel = tonumber(customParams.techlevel) or 1
		if techLevel >= 2 then
			removeGadget = false
			blockTechDefs[unitDefID] = techLevel
			blockCount = blockCount + 1
		end
		if customParams.tech_core_value and tonumber(customParams.tech_core_value) > 0 then
			removeGadget = false
			techCoreValueDefs[unitDefID] = tonumber(customParams.tech_core_value)
			coreCount = coreCount + 1
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

local function getMilestoneDescription(techLevel)
	local key = techLevel >= 3 and "ui.techBlocking.milestone.t3" or "ui.techBlocking.milestone.t2"
	local sharingModeAtLevel = modOptions["unit_sharing_mode_at_t" .. techLevel] or ""
	return key, sharingModeAtLevel
end

local function increaseTechLevel(teamList, notificationEvent, techLevel)
	local milestoneKey, sharingMode = getMilestoneDescription(techLevel)
	for _, teamID in ipairs(teamList) do
		if not ignoredTeams[teamID] then
			local players = Spring.GetPlayerList(teamID)
			if players then
				for _, playerID in ipairs(players) do
					SendToUnsynced("NotificationEvent", notificationEvent, tostring(playerID))
				end
			end
			spSetTeamRulesParam(teamID, "tech_level", techLevel)

			for unitDefID, requiredLevel in pairs(blockTechDefs) do
				if requiredLevel <= techLevel then
					GG.BuildBlocking.RemoveBlockedUnit(unitDefID, teamID, "tech_level_" .. requiredLevel)
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

	local blockedCount = 0
	local teamList = Spring.GetTeamList()
	for _, teamID in ipairs(teamList) do
		if not ignoredTeams[teamID] then
			local rawLevel = spGetTeamRulesParam(teamID, "tech_level")
			local techLevel = tonumber(rawLevel or 1) or 1
			for unitDefID, requiredLevel in pairs(blockTechDefs) do
				if techLevel < requiredLevel then
					GG.BuildBlocking.AddBlockedUnit(unitDefID, teamID, "tech_level_" .. requiredLevel)
					blockedCount = blockedCount + 1
				end
			end
		end
	end

	-- Announce tech core is active with threshold info
	SendToUnsynced("TechBlockingGameStart", tostring(t2TechPerPlayer), tostring(t3TechPerPlayer))
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if techCoreValueDefs[unitDefID] and not ignoredTeams[unitTeam] then
		local allyTeam = spGetUnitAllyTeam(unitID)
		local coreValue = techCoreValueDefs[unitDefID]
		techCoreUnits[unitID] = {value = coreValue, allyTeam = allyTeam}
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
		local firstActiveTeamID

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

			local previousAllyTechLevel = spGetTeamRulesParam(firstActiveTeamID, "tech_level") or 1

			if totalTechPoints >= t3Threshold and previousAllyTechLevel < 3 then
				increaseTechLevel(teamList, "Tech3TeamReached", 3)
			elseif totalTechPoints >= t2Threshold and previousAllyTechLevel < 2 then
				increaseTechLevel(teamList, "Tech2TeamReached", 2)
			end
		end
	end
end
