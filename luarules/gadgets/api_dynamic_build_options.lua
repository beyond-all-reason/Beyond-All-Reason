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
-- updates what the unit can build. Changes are kept per builder unit def and applied to new units in
-- UnitCreated. LuaUI reads them through common/dynamicBuildOptions.lua and the BuildOptionsChanged callin.

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

	local buildOptionChanges = VFS.Include("common/dynamicBuildOptions.lua")

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

	local function forEachUnitOfDef(unitDefID, callback, ...)
		for _, teamID in ipairs(teamsList) do
			if (spGetTeamUnitDefCount(teamID, unitDefID) or 0) > 0 then
				local unitIDs = spGetTeamUnitsByDefs(teamID, unitDefID)
				for i = 1, #unitIDs do
					callback(unitIDs[i], ...)
				end
			end
		end
	end

	local function isStaticOption(builtUnitDefID, builderUnitDefID)
		local options = staticBuildOptions[builderUnitDefID]
		return options ~= nil and options[builtUnitDefID] == true
	end

	local function publish(builderUnitDefID, builtUnitDefID, added)
		buildOptionChanges.publish(addedBuildOptions, removedBuildOptions)
		SendToUnsynced(SYNC_ACTION, builderUnitDefID, builtUnitDefID, added)
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

	local function registerAdded(builtUnitDefID, builderUnitDefID, position)
		local removed = removedBuildOptions[builderUnitDefID]
		if removed then
			removed[builtUnitDefID] = nil
		end
		if not isStaticOption(builtUnitDefID, builderUnitDefID) then
			table.ensureTable(addedBuildOptions, builderUnitDefID)[builtUnitDefID] = position or false
		end
	end

	local function registerRemoved(builtUnitDefID, builderUnitDefID)
		local added = addedBuildOptions[builderUnitDefID]
		if added then
			added[builtUnitDefID] = nil
		end
		if isStaticOption(builtUnitDefID, builderUnitDefID) then
			table.ensureTable(removedBuildOptions, builderUnitDefID)[builtUnitDefID] = true
		end
	end

	local dynamicBuildOptions = {}

	---Gives every current and future unit of a builder or factory type a build option.
	---@param builtUnitDefID UnitDefID
	---@param builderUnitDefID UnitDefID
	---@param position integer? Slot among the unit's build options; last when nil. Menus that sort options ignore it.
	---@return boolean applied false when the builder type cannot build
	function dynamicBuildOptions.Add(builtUnitDefID, builderUnitDefID, position)
		if not isBuilderDef(builderUnitDefID, "Add") then
			return false
		end
		registerAdded(builtUnitDefID, builderUnitDefID, position)
		forEachUnitOfDef(builderUnitDefID, insertBuildOption, builtUnitDefID, isFactoryDef[builderUnitDefID], position)
		publish(builderUnitDefID, builtUnitDefID, true)
		return true
	end

	---Takes a build option away from every current and future unit of a builder or factory type.
	---The engine also drops queued orders for it.
	---@param builtUnitDefID UnitDefID
	---@param builderUnitDefID UnitDefID
	---@return boolean applied false when the builder type cannot build
	function dynamicBuildOptions.Remove(builtUnitDefID, builderUnitDefID)
		if not isBuilderDef(builderUnitDefID, "Remove") then
			return false
		end
		registerRemoved(builtUnitDefID, builderUnitDefID)
		forEachUnitOfDef(builderUnitDefID, removeBuildOption, builtUnitDefID)
		publish(builderUnitDefID, builtUnitDefID, false)
		return true
	end

	---Whether units of a builder or factory type currently have a build option.
	---@param builtUnitDefID UnitDefID
	---@param builderUnitDefID UnitDefID
	---@return boolean
	function dynamicBuildOptions.HasBuildOption(builtUnitDefID, builderUnitDefID)
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

	function gadget:UnitCreated(unitID, unitDefID)
		local removed = removedBuildOptions[unitDefID]
		if removed then
			for builtUnitDefID in pairs(removed) do
				removeBuildOption(unitID, builtUnitDefID)
			end
		end
		local added = addedBuildOptions[unitDefID]
		if added then
			for builtUnitDefID, position in pairs(added) do
				insertBuildOption(unitID, builtUnitDefID, isFactoryDef[unitDefID], position or nil)
			end
		end
	end

	function gadget:Initialize()
		GG.DynamicBuildOptions = dynamicBuildOptions
	end

	function gadget:Shutdown()
		GG.DynamicBuildOptions = nil
	end
else
	local function handleBuildOptionsChanged(_, builderUnitDefID, builtUnitDefID, added)
		if Script.LuaUI.BuildOptionsChanged then
			Script.LuaUI.BuildOptionsChanged(builderUnitDefID, builtUnitDefID, added)
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
