-------------------------------------------------------------------------------
-- Squad Selection — stateless utility helpers
--
-- Pulled in via: local Util = VFS.Include("luaui/Include/squad_selection_util.lua")
-------------------------------------------------------------------------------

local spGetUnitPosition = Spring.GetUnitPosition
---@type fun(unitID: number, count: integer): commands: Command[]
local spGetUnitCommands = Spring.GetUnitCommands
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetMiniMapGeometry = Spring.GetMiniMapGeometry
local spGetMiniMapRotation = Spring.GetMiniMapRotation

-------------------------------------------------------------------------------
-- Numeric
-------------------------------------------------------------------------------

---@param x number
---@param min number
---@param max number
---@return number
local function constrain(x, min, max)
	return math.max(min, math.min(max, x))
end

-- Move `current` toward `target` by at most `step` (for animated blends).
---@param current number
---@param target number
---@param step number
---@return number
local function approach(current, target, step)
	if current < target then
		return math.min(current + step, target)
	end
	return math.max(current - step, target)
end

-------------------------------------------------------------------------------
-- Color
-------------------------------------------------------------------------------

local GOLDEN_HUE_STEP = 0.381966
local SQUAD_SAT = 0.75
local SQUAD_VAL = 0.7

---@param h number hue 0..1
---@param s number saturation 0..1
---@param v number value 0..1
---@return number r, number g, number b
local function hsvToRgb(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p = v * (1 - s)
	local q = v * (1 - f * s)
	local t = v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then
		return v, t, p
	elseif i == 1 then
		return q, v, p
	elseif i == 2 then
		return p, v, t
	elseif i == 3 then
		return p, q, v
	elseif i == 4 then
		return t, p, v
	else
		return v, p, q
	end
end

-- Deterministic per-squad color: golden-ratio hue step spreads consecutive
-- indices ~0.618 of the hue circle apart.
---@param idx number
---@return number r, number g, number b
local function indexToColor(idx)
	local h = ((idx - 1) * GOLDEN_HUE_STEP) % 1
	return hsvToRgb(h, SQUAD_SAT, SQUAD_VAL)
end

-------------------------------------------------------------------------------
-- Selection helpers
-------------------------------------------------------------------------------

-- Resolve a step value into a unit count against a pool size.
-- step <= 1 -> fraction (but min 1 unit); step > 1 -> number of units
---@param step number
---@param poolSize number
---@return number
local function stepToCount(step, poolSize)
	if poolSize <= 0 then
		return 0
	end
	if step <= 0 then
		return 1
	end
	if step <= 1 then
		return math.max(1, math.ceil(step * poolSize))
	end
	return math.min(math.floor(step), poolSize)
end

-- Parse portion action args: optional "append"/"append_domain" keyword,
-- optional "distance_<N>" modifier that caps selection to units within N
-- world-distance of the cursor, plus step numbers. "append_domain" implies
-- append and restricts to domains present in the current selection.
---@param args (string|number)[]? Raw action args.
---@return boolean append, boolean useDomainFilter, number[] steps, number? maxDistance, boolean retarget
local function parsePortionArgs(args)
	if not args then
		return false, false, {}, nil, false
	end
	local append = false
	local useDomainFilter = false
	local retarget = false
	local steps = {}
	local maxDistance
	for i = 1, #args do
		local arg = args[i]
		if arg == "append" then
			append = true
		elseif arg == "append_domain" then
			append = true
			useDomainFilter = true
		elseif arg == "retarget" then
			retarget = true
		elseif type(arg) == "string" and arg:sub(1, 9) == "distance_" then
			local d = tonumber(arg:sub(10))
			if d and d > 0 then
				maxDistance = d
			end
		else
			local n = tonumber(arg)
			if n then
				steps[#steps + 1] = n
			end
		end
	end
	return append, useDomainFilter, steps, maxDistance, retarget
end

-- Sort a unit array in-place by distance to a world point.
---@param units number[]
---@param wx number
---@param wz number
local function sortUnitsByDistance(units, wx, wz)
	local distCache = {}
	for i = 1, #units do
		local u = units[i]
		local x, _, z = spGetUnitPosition(u)
		if x then
			distCache[u] = (x - wx) * (x - wx) + (z - wz) * (z - wz)
		else
			distCache[u] = math.huge
		end
	end
	table.sort(units, function(a, b)
		return distCache[a] < distCache[b]
	end)
end

-- Returns true if every unit in `sq` is present in `selectedSet`.
-- Empty squads return false.
---@param sq number[] Squad member unitIDs.
---@param selectedSet table<number, boolean>
---@return boolean
local function squadFullySelected(sq, selectedSet)
	if #sq == 0 then
		return false
	end
	for i = 1, #sq do
		if not selectedSet[sq[i]] then
			return false
		end
	end
	return true
end

-- Count how many pool units are already selected.
---@param pool number[]
---@param selectedSet table<number, boolean>
---@return integer
local function countSelectedIn(pool, selectedSet)
	local n = 0
	for i = 1, #pool do
		if selectedSet[pool[i]] then
			n = n + 1
		end
	end
	return n
end

-- True when every unit in pool is in selectedSet.
---@param pool number[]
---@param selectedSet table<number, boolean>
---@return boolean
local function poolFullySelected(pool, selectedSet)
	for i = 1, #pool do
		if not selectedSet[pool[i]] then
			return false
		end
	end
	return true
end

-- Walk the step progression: return the first resolved count greater than
-- `currentInPool`, or the last step's count once we're past the end (no-op repeat).
---@param steps number[]
---@param poolSize number
---@param currentInPool number
---@return number
local function resolveTargetCount(steps, poolSize, currentInPool)
	for i = 1, #steps do
		local c = stepToCount(steps[i], poolSize)
		if c > currentInPool then
			return c
		end
	end
	return stepToCount(steps[#steps], poolSize)
end

-- Given a distance-sorted pool, pick which units go to SelectUnitArray.
-- Replace mode: first `targetCount` pool units.
-- Append mode: up to `targetCount` closest pool units that aren't already
-- selected (so repeated presses accumulate).
---@param pool number[] Distance-sorted candidate units.
---@param targetCount number
---@param selectedSet table<number, boolean>
---@param append boolean?
---@return number[] toSelect
local function pickUnits(pool, targetCount, selectedSet, append)
	local toSelect = {}
	if append then
		for i = 1, #pool do
			if not selectedSet[pool[i]] then
				toSelect[#toSelect + 1] = pool[i]
				if #toSelect >= targetCount then
					break
				end
			end
		end
	else
		for i = 1, targetCount do
			toSelect[i] = pool[i]
		end
	end
	return toSelect
end

-------------------------------------------------------------------------------
-- Command queue
-------------------------------------------------------------------------------

-- Returns true if `unitId`'s command queue contains a CMD_WAIT anywhere.
-- Used by the uncategorized-reserve path in UnitCreated to skip the selection
-- auto-extend feature for a freshly resurrected unit (rez bots leave units in
-- CMD_WAIT until fully healed).
---@param unitId number
---@return boolean
local function unitQueueHasWait(unitId)
	local cmds = spGetUnitCommands(unitId, -1)
	if not cmds then
		return false
	end
	for i = 1, #cmds do
		if cmds[i].id == CMD.WAIT then
			return true
		end
	end
	return false
end

-- Returns true if the factory's command queue ends with CMD_WAIT or
-- CMD_PATROL — i.e. the rally's last waypoint is a "stay busy here" signal.
-- Used to opt the reserve out of the selection auto-extend feature.
---@param factoryId number
---@return boolean
local function factoryRallyEndsWithWaitOrPatrol(factoryId)
	local cmds = spGetUnitCommands(factoryId, -1)
	if not cmds or #cmds == 0 then
		return false
	end

	local lastId = cmds[#cmds].id
	return lastId == CMD.WAIT or lastId == CMD.PATROL
end

-------------------------------------------------------------------------------
-- Mouse / world position
-------------------------------------------------------------------------------

-- Resolve the mouse cursor to a world (x, z). Reads the PIP minimap (via the
-- WG API), then the standard engine minimap geometry, then falls back to a
-- screen ray into the 3D world. Both minimap paths account for minimap
-- rotation.
---@return number? wx, number? wz
local function getMouseWorldPos()
	local mx, my = spGetMouseState()

	-- PIP minimap: when active, the engine minimap is hidden/minimized so
	-- spGetMiniMapGeometry() returns stale data. Use the WG API instead.
	local wgMinimap = WG and WG["minimap"]
	local wgPip0 = WG and WG["pip0"]
	local pipMinimized = wgPip0 and wgPip0.IsMinimized and wgPip0.IsMinimized()
	if wgMinimap and wgMinimap.isPipMinimapActive and wgMinimap.isPipMinimapActive() and not pipMinimized then
		local getBounds = wgMinimap.getScreenBounds ---@type function?
		local getWorldArea = wgMinimap.getVisibleWorldArea ---@type function?
		if getBounds and getWorldArea then
			local l, b, r, t = getBounds()
			if l and r > l and t > b and mx >= l and mx <= r and my >= b and my <= t then
				local normX = (mx - l) / (r - l)
				local normY = (my - b) / (t - b)

				-- (mirrors gui_pip's PipToWorldCoords).
				local getRotation = wgMinimap.getRotation ---@type function?
				local rot = getRotation and getRotation() or 0
				if rot ~= 0 then
					local dx, dy = normX - 0.5, normY - 0.5
					local cosR, sinR = math.cos(-rot), math.sin(-rot)
					normX = dx * cosR - dy * sinR + 0.5
					normY = dx * sinR + dy * cosR + 0.5
				end

				local wl, wr, wb, wt = getWorldArea()
				local wx = wl + (wr - wl) * normX
				local wz = wb + (wt - wb) * normY
				return wx, wz
			end
		end
	end

	-- Standard minimap (engine geometry).
	local mmX, mmY, mmW, mmH, minimized, maximized = spGetMiniMapGeometry()
	if mmX and mmW > 0 and mmH > 0 and not minimized and not maximized then
		local rx = (mx - mmX) / mmW
		local ry = (my - mmY) / mmH
		if rx >= 0 and rx <= 1 and ry >= 0 and ry <= 1 then
			local relX = rx
			local relY = 1 - ry

			-- (mirrors gui_pip's standard-minimap click handling).
			local rot = spGetMiniMapRotation and spGetMiniMapRotation() or 0
			if rot ~= 0 then
				local dx, dy = relX - 0.5, relY - 0.5
				local cosR, sinR = math.cos(rot), math.sin(rot)
				relX = dx * cosR - dy * sinR + 0.5
				relY = dx * sinR + dy * cosR + 0.5
			end

			local wx = Game.mapSizeX * relX
			local wz = Game.mapSizeZ * relY
			return wx, wz
		end
	end

	-- Normal path: trace screen ray into the 3D world.
	local _, coords = spTraceScreenRay(mx, my, true)
	if not coords then
		return nil
	end
	return coords[1], coords[3] -- world x, world z
end

-------------------------------------------------------------------------------
-- String
-------------------------------------------------------------------------------

-- Parse a comma-separated name list into `set[name] = true` (whitespace trimmed).
---@param set table<string, boolean>
---@param csv string
local function addExcludedNames(set, csv)
	for name in csv:gmatch("[^,]+") do
		set[name:match("^%s*(.-)%s*$")] = true
	end
end

return {
	constrain = constrain,
	approach = approach,
	hsvToRgb = hsvToRgb,
	indexToColor = indexToColor,
	stepToCount = stepToCount,
	parsePortionArgs = parsePortionArgs,
	sortUnitsByDistance = sortUnitsByDistance,
	squadFullySelected = squadFullySelected,
	countSelectedIn = countSelectedIn,
	poolFullySelected = poolFullySelected,
	resolveTargetCount = resolveTargetCount,
	pickUnits = pickUnits,
	unitQueueHasWait = unitQueueHasWait,
	factoryRallyEndsWithWaitOrPatrol = factoryRallyEndsWithWaitOrPatrol,
	getMouseWorldPos = getMouseWorldPos,
	addExcludedNames = addExcludedNames,
}
