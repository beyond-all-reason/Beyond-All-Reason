local widget = widget ---@type Widget

local BpDefs = require("luaui/Include/blueprint_substitution/definitions")

local SubLogic = require("luaui/Include/blueprint_substitution/logic")

local CMD_GUARD = CMD.GUARD

-- Every order costs the sim a synced callin per gadget, and split mode used to
-- give every builder every building (builders x buildings orders). The peer
-- followups now share a fixed budget on top of the one order per building.
local MAX_TOTAL_ORDERS = 2000

-- The engine discards NETMSG_AICOMMANDS packets above 8192 bytes, so order
-- arrays are sent in chunks that stay under it (sizes from SendCommandsToUnits).
local MAX_PACKET_BYTES = 7600
local PACKET_HEADER_BYTES = 17
local PACKET_UNIT_BYTES = 2
local PACKET_ORDER_BYTES = 7 -- id, options, param count
local PACKET_PARAM_BYTES = 4

function widget:GetInfo()
	return {
		name = "Build Orders API",
		desc = "Distributes build orders for a set of buildings across builders",
		license = "GNU GPL, v2 or later",
		layer = -2, -- before api_blueprint (-1), which consumes this API
		enabled = true,
	}
end

---@class BuilderInfo
---@field unitID UnitID
---@field unitDefID UnitDefID
---@field side string
---@field buildSpeed number

---@class BuildingInfo
---@field unitDefID UnitDefID
---@field position number[] { x, y, z }
---@field facing? number

-- UnitDefs[id].buildOptions builds a new table on every access.
local buildOptionSets = {} -- builder unitDefID -> { [buildee unitDefID] = true }

local function getBuildOptionSet(unitDefID)
	local set = buildOptionSets[unitDefID]
	if not set then
		set = {}
		for _, buildeeDefID in ipairs(UnitDefs[unitDefID].buildOptions) do
			set[buildeeDefID] = true
		end
		buildOptionSets[unitDefID] = set
	end
	return set
end

local equivalentUnitDefIDs = {} -- side -> unitDefID -> substituted unitDefID, false when none

local function getEquivalentUnitDefID(unitDefID, side)
	local sideKey = side or false
	local bySide = equivalentUnitDefIDs[sideKey]
	if not bySide then
		bySide = {}
		equivalentUnitDefIDs[sideKey] = bySide
	end
	local result = bySide[unitDefID]
	if result == nil then
		result = SubLogic.getEquivalentUnitDefID(unitDefID, side) or false
		bySide[unitDefID] = result
	end
	return result or nil
end

---@param builderID UnitID
---@return BuilderInfo
local function getBuilderInfo(builderID)
	local unitDefID = Spring.GetUnitDefID(builderID)
	if not unitDefID then
		return nil
	end

	local unitDef = UnitDefs[unitDefID]
	if not unitDef then
		return nil
	end

	local side = SubLogic.getSideFromUnitName(unitDef.name)

	return {
		unitID = builderID,
		unitDefID = unitDefID,
		side = side,
		buildSpeed = unitDef.buildSpeed,
	}
end

---@param builderGroup BuilderInfo[]
---@param building BuildingInfo
---@param side string
---@param allowSubstitution boolean
---@return boolean
local function canBuild(builderGroup, building, side, allowSubstitution)
	allowSubstitution = allowSubstitution ~= false -- Defaults to true

	local substitutedUnitDefID = getEquivalentUnitDefID(building.unitDefID, side)
	if not substitutedUnitDefID then
		return false
	end

	if not allowSubstitution and substitutedUnitDefID ~= building.unitDefID then
		return false
	end

	return getBuildOptionSet(builderGroup[1].unitDefID)[substitutedUnitDefID] == true
end

---@param builders UnitID[]
---@return table<number, BuilderInfo[]> -- Groups builders by their unitDefID
local function groupBuilders(builders)
	local builderGroups = {}
	for _, builderID in ipairs(builders) do
		local builderInfo = getBuilderInfo(builderID)
		if builderInfo then
			local uDefId = builderInfo.unitDefID
			builderGroups[uDefId] = builderGroups[uDefId] or {}
			table.insert(builderGroups[uDefId], builderInfo)
		end
	end
	return builderGroups
end

---Groups builders so that each builder forms its own group, keyed by unitID.
---Used by split mode, where every builder works its own fork.
---@param builders table A list of builder info objects.
---@return table<number, table> One group per builder.
local function forkBuilders(builders)
	local forkGroups = {}
	for _, builderInfo in ipairs(builders) do
		forkGroups[builderInfo.unitID] = { builderInfo }
	end
	return forkGroups
end

---Sends orders in packets the engine accepts.
---@param unitIDs UnitID[]
---@param orders table[] { cmdID, params, options } entries
local function giveOrders(unitIDs, orders)
	local headerBytes = PACKET_HEADER_BYTES + PACKET_UNIT_BYTES * #unitIDs
	local chunk, chunkBytes = {}, headerBytes
	for _, order in ipairs(orders) do
		local orderBytes = PACKET_ORDER_BYTES + PACKET_PARAM_BYTES * #order[2]
		if #chunk > 0 and chunkBytes + orderBytes > MAX_PACKET_BYTES then
			Spring.GiveOrderArrayToUnitArray(unitIDs, chunk, false)
			chunk, chunkBytes = {}, headerBytes
		end
		chunk[#chunk + 1] = order
		chunkBytes = chunkBytes + orderBytes
	end
	if #chunk > 0 then
		Spring.GiveOrderArrayToUnitArray(unitIDs, chunk, false)
	end
end

--- Distributes a blueprint's buildings across builder groups, proportional to
--- each group's build power, with capability-aware leftover redistribution. The
--- first order issued to each group honors the user's shift state (replacing the
--- queue when shift wasn't held); the rest are queued.
---
--- When peerFollowups is true (split mode), each group also receives other
--- buildings it is capable of constructing as lower-priority followups, so a
--- builder finishes its own fork and then helps with whatever remains. When
--- builders outnumber buildings, the extras have empty own-chunks and simply
--- start helping (double-up). The engine skips orders whose positions are already
--- built, so the redundant followups self-clean.
---@param builderGroups table<number, BuilderInfo[]> Builders grouped -- by unit type for
--- the linear path, or one-per-builder for split.
---@param allBuildings BuildingInfo[] The buildings to place, with positions.
---@param cmdOpts table Command options.
---@param peerFollowups boolean|nil If true, append peers' buildings as followups.
local function distributeBuildOrders(builderGroups, allBuildings, cmdOpts, peerFollowups)
	-- A blueprint is many build orders, so every order after the first must queue
	-- (shift) or it would overwrite the previous one.
	local queuedOpts = table.copy(cmdOpts)
	queuedOpts.shift = true

	local allBuilderGroups = {}
	for key, builderGroup in pairs(builderGroups) do
		if #builderGroup > 0 and builderGroup[1].buildSpeed > 0 then
			local groupPower = #builderGroup * builderGroup[1].buildSpeed
			table.insert(allBuilderGroups, {
				group = builderGroup,
				power = groupPower,
				side = builderGroup[1].side,
				key = key,
			})
		end
	end
	table.sort(allBuilderGroups, function(a, b)
		return a.power > b.power
	end)

	-- 1. Calculate cost-based workload quotas
	local totalBuildPower = 0
	for _, groupData in ipairs(allBuilderGroups) do
		totalBuildPower = totalBuildPower + groupData.power
	end

	if totalBuildPower <= 0 then
		return
	end

	local allBuildingsWithCost = {}
	local totalBuildCost = 0
	for _, building in ipairs(allBuildings) do
		local unitDef = UnitDefs[building.unitDefID]
		local cost = (unitDef and unitDef.cost) or 0
		table.insert(allBuildingsWithCost, { building = building, cost = cost })
		totalBuildCost = totalBuildCost + cost
	end

	-- 2. Partition the blueprint into cost-based linear chunks
	local chunks = {}
	local followupStarts = {} -- groupKey -> index in allBuildings the followups continue from
	local buildingIndex = 1
	local groupCount = #allBuilderGroups
	for i, groupData in ipairs(allBuilderGroups) do
		local proportion = groupData.power / totalBuildPower
		local targetCostForGroup = totalBuildCost * proportion

		local buildingsForGroup = {}
		local accumulatedCost = 0

		if i == groupCount then
			-- Last group takes all remaining buildings
			for j = buildingIndex, #allBuildingsWithCost do
				table.insert(buildingsForGroup, allBuildingsWithCost[j].building)
			end
			buildingIndex = #allBuildingsWithCost + 1
		else
			while buildingIndex <= #allBuildingsWithCost do
				local currentBuilding = allBuildingsWithCost[buildingIndex]
				local costAfterAdding = accumulatedCost + currentBuilding.cost

				-- Stop if adding the next building makes the chunk's cost further from the target
				if
					accumulatedCost > 0
					and math.abs(costAfterAdding - targetCostForGroup)
						> math.abs(accumulatedCost - targetCostForGroup)
				then
					break
				end

				table.insert(buildingsForGroup, currentBuilding.building)
				accumulatedCost = costAfterAdding
				buildingIndex = buildingIndex + 1
			end
		end

		if #buildingsForGroup > 0 then
			followupStarts[groupData.key] = buildingIndex - 1
		else
			-- extra builders without a chunk start spread over the list
			followupStarts[groupData.key] = math.floor((i - 1) * #allBuildingsWithCost / groupCount)
		end

		table.insert(chunks, { groupData = groupData, buildings = buildingsForGroup })
	end

	-- 3. Assign each group its own chunk; what a group can't build spills over
	local assignedBuildings = {} -- groupKey -> ordered list of building objects
	for _, groupData in ipairs(allBuilderGroups) do
		assignedBuildings[groupData.key] = {}
	end

	local leftovers = {}
	for _, chunk in ipairs(chunks) do
		local groupData = chunk.groupData
		for _, building in ipairs(chunk.buildings) do
			if canBuild(groupData.group, building, groupData.side, true) then
				table.insert(assignedBuildings[groupData.key], building)
			else
				table.insert(leftovers, building)
			end
		end
	end

	-- 4. Redistribute leftovers to capable groups (round-robin within a category)
	local leftoverTracker = {} -- category -> index
	for _, building in ipairs(leftovers) do
		local capableGroups = {}
		for _, groupData in ipairs(allBuilderGroups) do
			if canBuild(groupData.group, building, groupData.side, true) then
				table.insert(capableGroups, groupData)
			end
		end

		if #capableGroups > 0 then
			local targetGroupData
			if #capableGroups == 1 then
				targetGroupData = capableGroups[1]
			else
				table.sort(capableGroups, function(a, b)
					return a.key > b.key
				end) -- deterministic sort
				local category = BpDefs.unitCategories[UnitDefs[building.unitDefID].name:lower()] or "uncategorized"
				local currentIndex = (leftoverTracker[category] or 0) + 1
				if currentIndex > #capableGroups then
					currentIndex = 1
				end
				targetGroupData = capableGroups[currentIndex]
				leftoverTracker[category] = currentIndex
			end

			if targetGroupData then
				table.insert(assignedBuildings[targetGroupData.key], building)
			end
		end
	end

	-- 5. Split only: after its own chunk, each group gets the buildings it can
	-- build as followups, so a builder helps peers once its fork is done. They
	-- continue from where the own chunk ends (the chunks are linear, so that is
	-- the neighbouring work) and wrap around, within the shared order budget.
	if peerFollowups then
		local buildingCount = #allBuildings
		local followupBudget = math.floor((MAX_TOTAL_ORDERS - buildingCount) / groupCount)
		if followupBudget > 0 then
			for _, groupData in ipairs(allBuilderGroups) do
				local assigned = assignedBuildings[groupData.key]
				local own = {}
				for _, building in ipairs(assigned) do
					own[building] = true
				end
				local start = followupStarts[groupData.key]
				local added = 0
				for offset = 0, buildingCount - 1 do
					if added >= followupBudget then
						break
					end
					local building = allBuildings[(start + offset) % buildingCount + 1]
					if not own[building] and canBuild(groupData.group, building, groupData.side, true) then
						table.insert(assigned, building)
						added = added + 1
					end
				end
			end
		end
	end

	-- 6. Issue each group's orders. The first order honors the user's real shift
	-- state (replaces the queue when not held); the rest are queued.
	for _, groupData in ipairs(allBuilderGroups) do
		local buildings = assignedBuildings[groupData.key]
		if #buildings > 0 then
			local orders = {}
			for _, building in ipairs(buildings) do
				local substitutedUnitDefID = getEquivalentUnitDefID(building.unitDefID, groupData.side)
				if substitutedUnitDefID then
					table.insert(orders, {
						-substitutedUnitDefID,
						{ building.position[1], building.position[2], building.position[3], building.facing },
						queuedOpts,
					})
				end
			end
			if #orders > 0 then
				orders[1][3] = cmdOpts
				local groupBuilderIDs = table.map(groupData.group, function(b)
					return b.unitID
				end)
				giveOrders(groupBuilderIDs, orders)
			end
		end
	end

	-- 7. Builders that can construct none of these buildings would otherwise idle.
	-- Send each to guard a working builder so it assists construction instead of
	-- sitting idle. (Builders that *can* build something but lost out on the split
	-- are left alone -- they are not ineligible, just unlucky.)
	local workingBuilderIDs = {}
	for _, groupData in ipairs(allBuilderGroups) do
		if #assignedBuildings[groupData.key] > 0 then
			for _, builder in ipairs(groupData.group) do
				table.insert(workingBuilderIDs, builder.unitID)
			end
		end
	end

	if #workingBuilderIDs > 0 then
		local guardIndex = 1
		for _, groupData in ipairs(allBuilderGroups) do
			if #assignedBuildings[groupData.key] == 0 then
				local canBuildAny = false
				for _, building in ipairs(allBuildings) do
					if canBuild(groupData.group, building, groupData.side, true) then
						canBuildAny = true
						break
					end
				end

				if not canBuildAny then
					for _, builder in ipairs(groupData.group) do
						Spring.GiveOrderToUnit(builder.unitID, CMD_GUARD, { workingBuilderIDs[guardIndex] }, cmdOpts)
						guardIndex = guardIndex % #workingBuilderIDs + 1
					end
				end
			end
		end
	end
end

--- Splits a blueprint across builders so each works its own fork first, then
--- helps peers. Building-aware: each builder only receives buildings it can
--- construct (with faction substitution), and extra builders double up.
---@param builders BuilderInfo[] A list of builder info objects.
---@param buildings BuildingInfo[] A list of building objects.
---@param cmdOpts table Command options.
local function splitBuildOrders(builders, buildings, cmdOpts)
	if #builders == 0 or #buildings == 0 then
		return
	end

	distributeBuildOrders(forkBuilders(builders), buildings, cmdOpts, true)
end

function widget:Initialize()
	WG.api_build_orders = {
		getBuilderInfo = getBuilderInfo,
		groupBuilders = groupBuilders,
		forkBuilders = forkBuilders,
		canBuild = canBuild,
		distributeBuildOrders = distributeBuildOrders,
		splitBuildOrders = splitBuildOrders,
	}
end

function widget:Shutdown()
	WG.api_build_orders = nil
end
