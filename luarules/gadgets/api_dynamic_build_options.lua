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
-- updates what the unit can build. Changes are kept per builder unit def, for every team or for one team,
-- and applied to new units in UnitCreated and to units changing team in UnitGiven. LuaUI reads them
-- through common/dynamicBuildOptions.lua and the BuildOptionsChanged callin.

local SYNC_ACTION = "DynamicBuildOptionsChanged"

if gadgetHandler:IsSyncedCode() then
	local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
	local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
	local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
	local spGetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
	local spGetTeamUnitDefCount = Spring.GetTeamUnitDefCount
	local spGiveOrderToUnit = Spring.GiveOrderToUnit

	local CMD_REMOVE = CMD.REMOVE
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

	-- teamID -> the same per builder unit def, for one team on top of the changes for every team.
	-- A change for every team clears the teams' own changes of that option.
	---@type table<number, table<number, table<number, number|false>?>?>
	local teamAddedBuildOptions = {}
	---@type table<number, table<number, table<number, true>?>?>
	local teamRemovedBuildOptions = {}

	local function teamOptions(byTeam, teamID, builderUnitDefID)
		local byBuilder = byTeam[teamID]
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

	-- For units that may have queued the option already.
	local function removeQueuedBuildOption(unitID, builtUnitDefID, isFactory)
		removeBuildOption(unitID, builtUnitDefID)
		-- alt: by command ID; ctrl: a factory's own build queue, not the orders for its new units
		spGiveOrderToUnit(unitID, CMD_REMOVE, { -builtUnitDefID }, isFactory and { "alt", "ctrl" } or { "alt" })
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

	local function publish(builderUnitDefID, builtUnitDefID, added, teamID)
		if teamID then
			publishTeam(teamID)
		else
			buildOptionChanges.publish(addedBuildOptions, removedBuildOptions)
			for _, otherTeamID in ipairs(teamsList) do
				if teamAddedBuildOptions[otherTeamID] or teamRemovedBuildOptions[otherTeamID] then
					publishTeam(otherTeamID)
				end
			end
		end
		SendToUnsynced(SYNC_ACTION, builderUnitDefID, builtUnitDefID, added, teamID)
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

	local function clearTeamChanges(byTeam, builtUnitDefID, builderUnitDefID)
		for _, byBuilder in pairs(byTeam) do
			local options = byBuilder[builderUnitDefID]
			if options then
				options[builtUnitDefID] = nil
			end
		end
	end

	local function registerAdded(builtUnitDefID, builderUnitDefID, position, teamID)
		if teamID then
			local teamRemoved = teamOptions(teamRemovedBuildOptions, teamID, builderUnitDefID)
			if teamRemoved then
				teamRemoved[builtUnitDefID] = nil
			end
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
			local teamAdded = teamOptions(teamAddedBuildOptions, teamID, builderUnitDefID)
			if teamAdded then
				teamAdded[builtUnitDefID] = nil
			end
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

	-- Brings one unit's build option in line with the changes for its team.
	local function applyBuildOption(builtUnitDefID, unitID, unitDefID, teamID, dropQueued)
		local isFactory = isFactoryDef[unitDefID]
		if hasBuildOption(builtUnitDefID, unitDefID, teamID) then
			insertBuildOption(unitID, builtUnitDefID, isFactory, addedPosition(builtUnitDefID, unitDefID, teamID))
		elseif dropQueued then
			removeQueuedBuildOption(unitID, builtUnitDefID, isFactory)
		else
			removeBuildOption(unitID, builtUnitDefID)
		end
	end

	local function applyBuildOptions(options, unitID, unitDefID, teamID, dropQueued)
		if options then
			for builtUnitDefID in pairs(options) do
				applyBuildOption(builtUnitDefID, unitID, unitDefID, teamID, dropQueued)
			end
		end
	end

	local dynamicBuildOptions = {}

	---Gives every current and future unit of a builder or factory type a build option, or only those of one team.
	---@param builtUnitDefID UnitDefID
	---@param builderUnitDefID UnitDefID
	---@param position integer? Slot among the unit's build options; last when nil. Menus that sort options ignore it.
	---@param teamID integer? only this team's units; nil for every team
	---@return boolean applied false when the builder type cannot build
	function dynamicBuildOptions.Add(builtUnitDefID, builderUnitDefID, position, teamID)
		if not isBuilderDef(builderUnitDefID, "Add") then
			return false
		end
		registerAdded(builtUnitDefID, builderUnitDefID, position, teamID)
		position = position or addedPosition(builtUnitDefID, builderUnitDefID, teamID)
		local isFactory = isFactoryDef[builderUnitDefID]
		forEachUnitOfDef(builderUnitDefID, teamID, insertBuildOption, builtUnitDefID, isFactory, position)
		publish(builderUnitDefID, builtUnitDefID, true, teamID)
		return true
	end

	---Takes a build option away from every current and future unit of a builder or factory type, or only
	---from those of one team. Queued orders for it are dropped too.
	---@param builtUnitDefID UnitDefID
	---@param builderUnitDefID UnitDefID
	---@param teamID integer? only this team's units; nil for every team
	---@return boolean applied false when the builder type cannot build
	function dynamicBuildOptions.Remove(builtUnitDefID, builderUnitDefID, teamID)
		if not isBuilderDef(builderUnitDefID, "Remove") then
			return false
		end
		registerRemoved(builtUnitDefID, builderUnitDefID, teamID)
		local isFactory = isFactoryDef[builderUnitDefID]
		forEachUnitOfDef(builderUnitDefID, teamID, removeQueuedBuildOption, builtUnitDefID, isFactory)
		publish(builderUnitDefID, builtUnitDefID, false, teamID)
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

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		if not staticBuildOptions[unitDefID] then
			return
		end
		applyBuildOptions(removedBuildOptions[unitDefID], unitID, unitDefID, unitTeam)
		applyBuildOptions(addedBuildOptions[unitDefID], unitID, unitDefID, unitTeam)
		applyBuildOptions(teamOptions(teamRemovedBuildOptions, unitTeam, unitDefID), unitID, unitDefID, unitTeam)
		applyBuildOptions(teamOptions(teamAddedBuildOptions, unitTeam, unitDefID), unitID, unitDefID, unitTeam)
	end

	-- Only the options that either team changed for itself can differ between the two.
	function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
		if not staticBuildOptions[unitDefID] then
			return
		end
		for _, teamID in ipairs({ oldTeam, newTeam }) do
			applyBuildOptions(teamOptions(teamRemovedBuildOptions, teamID, unitDefID), unitID, unitDefID, newTeam, true)
			applyBuildOptions(teamOptions(teamAddedBuildOptions, teamID, unitDefID), unitID, unitDefID, newTeam, true)
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
