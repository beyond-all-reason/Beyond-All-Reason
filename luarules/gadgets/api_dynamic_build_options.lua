local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Dynamic Build Options API",
		desc = "Adds and removes build options of builder and factory unit types at runtime, for existing and future units",
		date = "2026.09.15",
		license = "GNU GPL, v2 or later",
		layer = -1, -- before unit_prevent_strange_orders.lua, which uses GG.DynamicBuildOptions
		enabled = true,
	}
end

-- Build options are per-unit command descriptions (id = -unitDefID); inserting or removing one also
-- updates what the unit can build. Changes are kept per builder unit def, for all teams or one team, and
-- applied to new and given units. LuaUI reads them through common/dynamicBuildOptions.lua and the
-- BuildOptionsChanged callin.

local SYNC_ACTION = "DynamicBuildOptionsChanged"

if gadgetHandler:IsSyncedCode() then
	local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
	local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
	local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
	local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
	local spGetTeamUnitDefCount = Spring.GetTeamUnitDefCount

	local CMDTYPE_ICON = CMDTYPE.ICON
	local CMDTYPE_ICON_BUILDING = CMDTYPE.ICON_BUILDING

	local buildOptionChanges = require("common/dynamicBuildOptions")

	local teamsList = Spring.GetTeamList()
	---@cast teamsList -?

	-- builderUnitDefID -> { builtUnitDefID = true } from the unit defs, for builders and factories only
	---@type table<number, table<number, true>?>
	local staticBuildOptions = {}
	---@type table<number, boolean>
	local isFactoryDef = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isBuilder then
			local options = {}
			for _, builtUnitDefID in ipairs(unitDef.buildOptions) do
				options[builtUnitDefID] = true
			end
			staticBuildOptions[unitDefID] = options
			isFactoryDef[unitDefID] = unitDef.isFactory == true
		end
	end

	-- builderUnitDefID -> { builtUnitDefID = position or false }
	---@type table<number, table<number, number|false>?>
	local addedBuildOptions = {}
	-- builderUnitDefID -> { builtUnitDefID = true }
	---@type table<number, table<number, true>?>
	local removedBuildOptions = {}

	-- teamID -> the same, for one team on top of the changes for all teams
	---@type table<number, table<number, table<number, number|false>?>?>
	local teamAddedBuildOptions = {}
	---@type table<number, table<number, table<number, true>?>?>
	local teamRemovedBuildOptions = {}

	local function teamOptions(changesByTeam, teamID, builderUnitDefID)
		local byBuilder = changesByTeam[teamID]
		return byBuilder and byBuilder[builderUnitDefID]
	end

	---@param builtUnitDefID integer
	---@param isFactory boolean
	local function buildOptionCmdDesc(builtUnitDefID, isFactory)
		local builtUnitDef = UnitDefs[builtUnitDefID]
		---@cast builtUnitDef table
		local name = tostring(builtUnitDef.name)
		return {
			id = -builtUnitDefID,
			type = isFactory and CMDTYPE_ICON or CMDTYPE_ICON_BUILDING,
			name = name,
			action = "buildunit_" .. string.lower(name),
			cursor = name,
			disabled = builtUnitDef.maxThisUnit <= 0,
		}
	end

	---Command description index that makes the option the `position`-th build option; nil appends.
	local function resolveInsertIndex(unitID, position)
		local cmdDescs = spGetUnitCmdDescs(unitID)
		if not cmdDescs then
			return nil
		end
		local buildOptionCount = 0
		local lastBuildOptionIndex
		for i = 1, #cmdDescs do
			if cmdDescs[i].id < 0 then
				buildOptionCount = buildOptionCount + 1
				if position and buildOptionCount == position then
					return i
				end
				lastBuildOptionIndex = i
			end
		end
		return lastBuildOptionIndex and (lastBuildOptionIndex + 1) or nil
	end

	local function insertBuildOption(unitID, builtUnitDefID, isFactory, position)
		if spFindUnitCmdDesc(unitID, -builtUnitDefID) then
			return
		end
		local index = resolveInsertIndex(unitID, position)
		local cmdDesc = buildOptionCmdDesc(builtUnitDefID, isFactory)
		if index then
			spInsertUnitCmdDesc(unitID, index, cmdDesc)
		else
			spInsertUnitCmdDesc(unitID, cmdDesc)
		end
	end

	local function removeBuildOption(unitID, builtUnitDefID)
		local index = spFindUnitCmdDesc(unitID, -builtUnitDefID)
		if index then
			spRemoveUnitCmdDesc(unitID, index)
		end
	end

	local function forEachTeamUnitOfDef(teamID, unitDefID, callback, ...)
		if (spGetTeamUnitDefCount(teamID, unitDefID) or 0) > 0 then
			local unitIDs = spGetTeamUnitsByDefs(teamID, unitDefID)
			for i = 1, #unitIDs do
				callback(unitIDs[i], ...)
			end
		end
	end

	---@param teamID integer? only this team's units; nil for every team
	local function forEachUnitOfDef(unitDefID, teamID, callback, ...)
		if teamID then
			forEachTeamUnitOfDef(teamID, unitDefID, callback, ...)
			return
		end
		for _, unitTeamID in ipairs(teamsList) do
			forEachTeamUnitOfDef(unitTeamID, unitDefID, callback, ...)
		end
	end

	local function isStaticOption(builtUnitDefID, builderUnitDefID)
		local options = staticBuildOptions[builderUnitDefID]
		return options ~= nil and options[builtUnitDefID] == true
	end

	local function hasBuildOption(builtUnitDefID, builderUnitDefID, teamID)
		if teamID then
			local teamRemoved = teamOptions(teamRemovedBuildOptions, teamID, builderUnitDefID)
			if teamRemoved and teamRemoved[builtUnitDefID] then
				return false
			end
			local teamAdded = teamOptions(teamAddedBuildOptions, teamID, builderUnitDefID)
			if teamAdded and teamAdded[builtUnitDefID] ~= nil then
				return true
			end
		end
		local removed = removedBuildOptions[builderUnitDefID]
		if removed and removed[builtUnitDefID] then
			return false
		end
		if isStaticOption(builtUnitDefID, builderUnitDefID) then
			return true
		end
		local added = addedBuildOptions[builderUnitDefID]
		return added ~= nil and added[builtUnitDefID] ~= nil
	end

	local function anyTeamHasBuildOption(builtUnitDefID, builderUnitDefID)
		if hasBuildOption(builtUnitDefID, builderUnitDefID) then
			return true
		end
		for teamID in pairs(teamAddedBuildOptions) do
			if hasBuildOption(builtUnitDefID, builderUnitDefID, teamID) then
				return true
			end
		end
		return false
	end

	local function addedPosition(builtUnitDefID, builderUnitDefID, teamID)
		local teamAdded = teamID and teamOptions(teamAddedBuildOptions, teamID, builderUnitDefID)
		if teamAdded and teamAdded[builtUnitDefID] then
			return teamAdded[builtUnitDefID]
		end
		local added = addedBuildOptions[builderUnitDefID]
		return added and added[builtUnitDefID] or nil
	end

	local function publishTeam(teamID)
		buildOptionChanges.publish(teamAddedBuildOptions[teamID] or {}, teamRemovedBuildOptions[teamID] or {}, teamID)
	end

	local function publish(teamID)
		if teamID then
			publishTeam(teamID)
			return
		end
		buildOptionChanges.publish(addedBuildOptions, removedBuildOptions)
		-- a change for all teams can clear the teams' own
		for _, otherTeamID in ipairs(teamsList) do
			publishTeam(otherTeamID)
		end
	end

	local function isBuilderDef(builderUnitDefID, caller)
		if staticBuildOptions[builderUnitDefID] then
			return true
		end
		Spring.Log(
			gadget:GetInfo().name,
			LOG.WARNING,
			caller .. ": unitDefID " .. tostring(builderUnitDefID) .. " is not a builder or factory"
		)
		return false
	end

	local function clearTeamChange(changesByTeam, teamID, builtUnitDefID, builderUnitDefID)
		local byBuilder = changesByTeam[teamID]
		local options = byBuilder and byBuilder[builderUnitDefID]
		if not options then
			return
		end
		options[builtUnitDefID] = nil
		if next(options) == nil then
			byBuilder[builderUnitDefID] = nil
			if next(byBuilder) == nil then
				changesByTeam[teamID] = nil
			end
		end
	end

	local function clearTeamChanges(changesByTeam, builtUnitDefID, builderUnitDefID)
		for teamID in pairs(changesByTeam) do
			clearTeamChange(changesByTeam, teamID, builtUnitDefID, builderUnitDefID)
		end
	end

	local function registerAdded(builtUnitDefID, builderUnitDefID, position, teamID)
		if teamID then
			clearTeamChange(teamRemovedBuildOptions, teamID, builtUnitDefID, builderUnitDefID)
			if not hasBuildOption(builtUnitDefID, builderUnitDefID) then
				local teamAdded = table.ensureTable(teamAddedBuildOptions, teamID)
				table.ensureTable(teamAdded, builderUnitDefID)[builtUnitDefID] = position or false
			end
			return
		end
		clearTeamChanges(teamAddedBuildOptions, builtUnitDefID, builderUnitDefID)
		clearTeamChanges(teamRemovedBuildOptions, builtUnitDefID, builderUnitDefID)
		local removed = removedBuildOptions[builderUnitDefID]
		if removed then
			removed[builtUnitDefID] = nil
		end
		if not isStaticOption(builtUnitDefID, builderUnitDefID) then
			table.ensureTable(addedBuildOptions, builderUnitDefID)[builtUnitDefID] = position or false
		end
	end

	local function registerRemoved(builtUnitDefID, builderUnitDefID, teamID)
		if teamID then
			clearTeamChange(teamAddedBuildOptions, teamID, builtUnitDefID, builderUnitDefID)
			if hasBuildOption(builtUnitDefID, builderUnitDefID) then
				local teamRemoved = table.ensureTable(teamRemovedBuildOptions, teamID)
				table.ensureTable(teamRemoved, builderUnitDefID)[builtUnitDefID] = true
			end
			return
		end
		clearTeamChanges(teamAddedBuildOptions, builtUnitDefID, builderUnitDefID)
		clearTeamChanges(teamRemovedBuildOptions, builtUnitDefID, builderUnitDefID)
		local added = addedBuildOptions[builderUnitDefID]
		if added then
			added[builtUnitDefID] = nil
		end
		if isStaticOption(builtUnitDefID, builderUnitDefID) then
			table.ensureTable(removedBuildOptions, builderUnitDefID)[builtUnitDefID] = true
		end
	end

	local function applyBuildOption(builtUnitDefID, unitID, unitDefID, teamID)
		local isFactory = isFactoryDef[unitDefID]
		if hasBuildOption(builtUnitDefID, unitDefID, teamID) then
			insertBuildOption(unitID, builtUnitDefID, isFactory, addedPosition(builtUnitDefID, unitDefID, teamID))
		else
			removeBuildOption(unitID, builtUnitDefID)
		end
	end

	local function applyBuildOptions(options, unitID, unitDefID, teamID)
		if options then
			for builtUnitDefID in pairs(options) do
				applyBuildOption(builtUnitDefID, unitID, unitDefID, teamID)
			end
		end
	end

	local function addToBuilderType(builtUnitDefID, builderUnitDefID, position, teamID)
		registerAdded(builtUnitDefID, builderUnitDefID, position, teamID)
		position = position or addedPosition(builtUnitDefID, builderUnitDefID, teamID)
		local isFactory = isFactoryDef[builderUnitDefID]
		forEachUnitOfDef(builderUnitDefID, teamID, insertBuildOption, builtUnitDefID, isFactory, position)
		SendToUnsynced(SYNC_ACTION, builderUnitDefID, builtUnitDefID, true, teamID)
	end

	local function removeFromBuilderType(builtUnitDefID, builderUnitDefID, teamID)
		registerRemoved(builtUnitDefID, builderUnitDefID, teamID)
		forEachUnitOfDef(builderUnitDefID, teamID, removeBuildOption, builtUnitDefID)
		SendToUnsynced(SYNC_ACTION, builderUnitDefID, builtUnitDefID, false, teamID)
	end

	local dynamicBuildOptions = {}

	---Gives every current and future unit of a builder or factory type a build option, or only those of one team.
	---With a team and no builder type: every builder type that builds it by its unit def or was given it for every team.
	---@param builtUnitDefID UnitDefID
	---@param builderUnitDefID UnitDefID? nil only with a teamID
	---@param position integer? Slot among the unit's build options; last when nil. Menus that sort options ignore it.
	---@param teamID integer? only this team's units; nil for every team
	---@return boolean applied false when the builder type cannot build
	function dynamicBuildOptions.Add(builtUnitDefID, builderUnitDefID, position, teamID)
		if builderUnitDefID == nil and teamID then
			for builderID in pairs(staticBuildOptions) do
				if
					(isStaticOption(builtUnitDefID, builderID) or hasBuildOption(builtUnitDefID, builderID))
					and not hasBuildOption(builtUnitDefID, builderID, teamID)
				then
					addToBuilderType(builtUnitDefID, builderID, nil, teamID)
				end
			end
			publishTeam(teamID)
			return true
		end
		if not isBuilderDef(builderUnitDefID, "Add") then
			return false
		end
		addToBuilderType(builtUnitDefID, builderUnitDefID, position, teamID)
		publish(teamID)
		return true
	end

	---Takes a build option away from every current and future unit of a builder or factory type, or only
	---from those of one team. The engine also drops queued orders for it.
	---@param builtUnitDefID UnitDefID
	---@param builderUnitDefID UnitDefID? nil for every builder type that has it
	---@param teamID integer? only this team's units; nil for every team
	---@return boolean applied false when the builder type cannot build
	function dynamicBuildOptions.Remove(builtUnitDefID, builderUnitDefID, teamID)
		if builderUnitDefID == nil then
			for builderID in pairs(staticBuildOptions) do
				local hasIt
				if teamID then
					hasIt = hasBuildOption(builtUnitDefID, builderID, teamID)
				else
					hasIt = anyTeamHasBuildOption(builtUnitDefID, builderID)
				end
				if hasIt then
					removeFromBuilderType(builtUnitDefID, builderID, teamID)
				end
			end
			publish(teamID)
			return true
		end
		if not isBuilderDef(builderUnitDefID, "Remove") then
			return false
		end
		removeFromBuilderType(builtUnitDefID, builderUnitDefID, teamID)
		publish(teamID)
		return true
	end

	---Whether units of a builder or factory type currently have a build option.
	---@param builtUnitDefID UnitDefID
	---@param builderUnitDefID UnitDefID
	---@param teamID integer? with this team's own changes; nil for the changes for every team only
	---@return boolean
	function dynamicBuildOptions.HasBuildOption(builtUnitDefID, builderUnitDefID, teamID)
		return hasBuildOption(builtUnitDefID, builderUnitDefID, teamID)
	end

	local function applyTeamChanges(changedTeamID, unitID, unitDefID, unitTeam)
		applyBuildOptions(teamOptions(teamRemovedBuildOptions, changedTeamID, unitDefID), unitID, unitDefID, unitTeam)
		applyBuildOptions(teamOptions(teamAddedBuildOptions, changedTeamID, unitDefID), unitID, unitDefID, unitTeam)
	end

	-- A given or captured unit still carries its old team's changes, and that team is not passed here.
	function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
		if not staticBuildOptions[unitDefID] then
			return
		end
		applyBuildOptions(removedBuildOptions[unitDefID], unitID, unitDefID, unitTeam)
		applyBuildOptions(addedBuildOptions[unitDefID], unitID, unitDefID, unitTeam)
		for _, changedTeamID in ipairs(teamsList) do
			applyTeamChanges(changedTeamID, unitID, unitDefID, unitTeam)
		end
	end

	function gadget:Initialize()
		GG.DynamicBuildOptions = dynamicBuildOptions
	end

	function gadget:Shutdown()
		GG.DynamicBuildOptions = nil
	end
else
	local function handleBuildOptionsChanged(_, builderUnitDefID, builtUnitDefID, added, teamID)
		if Script.LuaUI.BuildOptionsChanged then
			Script.LuaUI.BuildOptionsChanged(builderUnitDefID, builtUnitDefID, added, teamID)
		end
		return true
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction(SYNC_ACTION, handleBuildOptionsChanged)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction(SYNC_ACTION)
	end
end
