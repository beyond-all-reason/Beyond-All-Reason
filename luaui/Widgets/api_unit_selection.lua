local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "API Unit Selection",
		desc = "Shared views of the current selection: a unit array, grouped by unitdef, and by capability.",
		author = "efrec",
		date = "September 2026",
		license = "GNU GPL, v2 or later",
		layer = -999999, -- Reads SelectionChanged before widgets that rewrite it.
		enabled = true,
		hidden = true, -- disable toggling off the API
	}
end

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetUnitDefID = Spring.GetUnitDefID

local UnitSelection = table.ensureTable(WG, "UnitSelection")

--------------------------------------------------------------------------------
-- Capability sets -------------------------------------------------------------

-- TODO: In a mixed selection of factories and non-factories, how to group them?

---@type table<string, fun(unitDef: table): boolean>
local capabilityTests = {
	attack = function(unitDef)
		return unitDef.canAttack and unitDef.maxWeaponRange > 0
	end,
	capture = function(unitDef)
		return unitDef.canCapture
	end,
	guard = function(unitDef)
		return unitDef.canGuard
	end,
	repairs = function(unitDef)
		-- Assist without repair is buildframes only, so has to check its target.
		return unitDef.canRepair or unitDef.canAssist
	end,
	reclaim = function(unitDef)
		return unitDef.canReclaim
	end,
	resurrect = function(unitDef)
		return unitDef.canResurrect
	end,
	transport = function(unitDef)
		return unitDef.transportSize and unitDef.transportSize > 0
	end,
}

local capableDefs = {} ---@type table<string?, table<UnitDefID, true>?>

---Lazy-build unitdef capability sets on first use.
---@param key string
---@return table<UnitDefID, true>|nil
local function getCapableDefs(key)
	local defs = capableDefs[key]
	if defs then
		return defs
	end

	local test = capabilityTests[key]
	if not test then
		return nil
	end

	defs = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if test(unitDef) then
			defs[unitDefID] = true
		end
	end
	capableDefs[key] = defs
	return defs
end

--------------------------------------------------------------------------------
-- Selection state -------------------------------------------------------------

local selectionCount = 0
local version = 0
local stale = true

-- Each view is stamped with the version it was built from, the flat array included.
local selection, selectionVersion = {}, -1 ---@type UnitID[], integer
local byUnitDefID, byUnitDefIDVersion = nil, -1
local capableUnits, capableUnitsVersion = {}, {}

local function update()
	stale = false
	version = version + 1
	selectionCount = spGetSelectedUnitsCount()
end

local function currentVersion()
	if stale then
		update()
	end
	return version
end

local function currentSelection()
	if selectionVersion ~= currentVersion() then
		selection, selectionVersion = spGetSelectedUnits(), version
	end
	return selection
end

--------------------------------------------------------------------------------
-- Interface methods -----------------------------------------------------------

---Increments when the cached selection is rebuilt.
---@return integer
function UnitSelection.GetVersion()
	return currentVersion()
end

---Marks the cache stale for a widget to call `Spring.SelectUnitArray`.
function UnitSelection.Invalidate()
	stale = true
end

---The number of units in-selection.
---@return integer
function UnitSelection.GetCount()
	currentVersion()
	return selectionCount
end

---Gets the current selection. This is shared across callers, so copy as needed.
---@return UnitID[]
function UnitSelection.GetUnits()
	return currentSelection()
end

---Gets the current selection, grouped by unitDefID.
---@return table<UnitDefID?, UnitID[]?>
function UnitSelection.GetUnitsByDefID()
	if byUnitDefIDVersion ~= currentVersion() then
		byUnitDefID, byUnitDefIDVersion = spGetSelectedUnitsSorted(), version
	end
	return byUnitDefID ---@as table<UnitDefID?, UnitID[]?>
end

---Gets the selected units that can perform the named capability; nil when empty.
---
---This has an odd edge for better performance: When all units have the required
---capability, the base selection is returned, which is a commonly shared table.
---Copy that table as needed when mutating it.
---@param name string
---@return UnitID[]|nil
function UnitSelection.GetCapableUnits(name)
	local units = currentSelection()
	if capableUnitsVersion[name] == version then
		return capableUnits[name]
	end

	local defs = getCapableDefs(name)
	if not defs then
		Spring.Log("UnitSelection", LOG.WARN, "unknown capability " .. tostring(name))
		return nil
	end

	local capable = units ---@as UnitID[]?
	local firstDrop
	for index = 1, selectionCount do
		if not defs[spGetUnitDefID(units[index])] then
			firstDrop = index
			break
		end
	end

	---@cast firstDrop integer?

	if firstDrop then
		local keep, count = {}, firstDrop - 1
		for index = 1, count do
			keep[index] = units[index]
		end
		for index = firstDrop + 1, selectionCount do
			local unitID = units[index]
			if defs[spGetUnitDefID(unitID)] then
				count = count + 1
				keep[count] = unitID
			end
		end
		capable = count > 0 and keep or nil
	elseif selectionCount == 0 then
		capable = nil
	end

	capableUnits[name], capableUnitsVersion[name] = capable, version
	return capable
end

---Add a capability that GetCapableUnits then uses in filters.
---
---Takes either a set of unit defs or a test for building one.
---@param name string
---@param defsOrTest table<UnitDefID, true>|fun(unitDef: UnitDef): boolean
function UnitSelection.RegisterCapability(name, defsOrTest)
	local defs, test
	if type(defsOrTest) == "table" then
		defs = defsOrTest
	elseif type(defsOrTest) == "function" then
		test = defsOrTest
	end
	if not defs and not test then
		return false
	end
	capableDefs[name] = defs
	capabilityTests[name] = test
	capableUnitsVersion[name] = nil
	return true
end

--------------------------------------------------------------------------------
-- Engine callins --------------------------------------------------------------

function widget:SelectionChanged()
	stale = true
end

function widget:PlayerChanged()
	stale = true
end

function widget:Initialize()
	WG.UnitSelection = UnitSelection
end

function widget:Shutdown()
	WG.UnitSelection = nil
end
