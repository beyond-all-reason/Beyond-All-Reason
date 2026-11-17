local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Anti Stacking Hax",
		desc = "Pushes nano turrets off structures they end up stacked on",
		author = "Damgam",
		date = "2021",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTransporter = Spring.GetUnitTransporter
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitBuildFacing = Spring.GetUnitBuildFacing
local spGetUnitBlocking = Spring.GetUnitBlocking
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetGroundHeight = Spring.GetGroundHeight
local spSetUnitPosition = Spring.SetUnitPosition
local mathAbs = math.abs
local mathMax = math.max

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

-- Structures placed by a builder passed the engine build test, which knows
-- yardmaps (open corners, stackable mex/geo cells), so any overlap they have
-- is legal. Only placements that skip that test can stack: transport unloads
-- (checked against model radius, not footprint) and units spawned by Lua
-- without a builder. Those put the turrets around them on a "hot" list, and
-- hot turrets are pushed off overlapping structures every frame until clear.
-- GameFrame is switched off entirely while the hot list is empty.
local OVERLAP_TOLERANCE = 16 -- elmos per axis, legal overlaps through open yardmap cells stay within one footprint cell
local MIDPOS_MARGIN = 32 -- area queries test midPos, which can sit off the footprint center
local MAX_PUSHES = 16 -- give up on a turret that keeps landing on other structures

local halfX = {} -- unitDefID -> footprint half size in elmos at facing 0 (immobile defs only)
local halfZ = {}
local isTurret = {}
local minDepthLimit = {} -- unitDefID -> -minWaterDepth (target ground height must be below this)
local maxDepthLimit = {} -- unitDefID -> -maxWaterDepth (target ground height must be above this)
local floatOnWater = {}
local maxHalf = 0 ---@type number
local maxTurretHalf = 0 ---@type number
for udid, ud in pairs(UnitDefs) do
	if not ud.canMove then
		local hx, hz = ud.xsize * 4, ud.zsize * 4
		halfX[udid] = hx
		halfZ[udid] = hz
		maxHalf = mathMax(maxHalf, hx, hz)
		if ud.customParams.isnanoturret then
			isTurret[udid] = true
			minDepthLimit[udid] = -ud.minWaterDepth
			maxDepthLimit[udid] = -ud.maxWaterDepth
			floatOnWater[udid] = ud.floatOnWater
			maxTurretHalf = mathMax(maxTurretHalf, hx, hz)
		end
	end
end

local turretDefID = {} -- unitID -> unitDefID for every live nano turret

local hot = {} -- array of unitIDs checked every frame
local hotCount = 0
local hotPos = {} -- unitID -> index inside hot, nil when not hot
local pushes = {} -- unitID -> pushes onto another structure since it became hot

local function addHot(unitID)
	if hotPos[unitID] then
		return
	end
	hotCount = hotCount + 1
	hot[hotCount] = unitID
	hotPos[unitID] = hotCount
	pushes[unitID] = 0
	if hotCount == 1 then
		gadgetHandler:UpdateCallIn("GameFrame")
	end
end

local function removeHot(unitID)
	local pos = hotPos[unitID]
	if not pos then
		return
	end
	local last = hot[hotCount]
	hot[pos] = last
	hotPos[last] = pos
	hot[hotCount] = nil
	hotCount = hotCount - 1
	hotPos[unitID] = nil
	pushes[unitID] = nil
end

local function footprint(unitID, unitDefID)
	if (spGetUnitBuildFacing(unitID) or 0) % 2 == 1 then
		return halfZ[unitDefID], halfX[unitDefID]
	end
	return halfX[unitDefID], halfZ[unitDefID]
end

-- Returns the blocking immobile unit whose footprint overlaps the given one the
-- most, with its center and half sizes. allyTeam limits the search to it.
local function worstOverlap(unitID, x, z, hx, hz, allyTeam)
	local rx = hx + maxHalf + MIDPOS_MARGIN
	local rz = hz + maxHalf + MIDPOS_MARGIN
	local units = spGetUnitsInRectangle(x - rx, z - rz, x + rx, z + rz)
	local worst, worstArea, wx, wz, whx, whz = nil, 0, 0, 0, 0, 0
	for i = 1, #units do
		local other = units[i]
		local otherDefID = spGetUnitDefID(other)
		if
			other ~= unitID
			and halfX[otherDefID]
			and (not allyTeam or spGetUnitAllyTeam(other) == allyTeam)
			and spGetUnitBlocking(other)
		then
			local ox, _, oz = spGetUnitPosition(other)
			local ohx, ohz = footprint(other, otherDefID)
			local overlapX = hx + ohx - mathAbs(ox - x)
			local overlapZ = hz + ohz - mathAbs(oz - z)
			if overlapX > OVERLAP_TOLERANCE and overlapZ > OVERLAP_TOLERANCE and overlapX * overlapZ > worstArea then
				worst, worstArea = other, overlapX * overlapZ
				wx, wz, whx, whz = ox, oz, ohx, ohz
			end
		end
	end
	return worst, wx, wz, whx, whz
end

local function canStandAt(unitDefID, x, z, hx, hz)
	if x - hx < 0 or x + hx > mapSizeX or z - hz < 0 or z + hz > mapSizeZ then
		return false
	end
	local y = spGetGroundHeight(x, z)
	return y < minDepthLimit[unitDefID] and y > maxDepthLimit[unitDefID]
end

-- Moves the turret off the allied structure it overlaps most, to the nearest
-- spot touching that structure, preferring spots clear of every structure.
-- Returns true when it is still stacked, i.e. recheck next frame.
local function checkTurret(unitID, unitDefID)
	if spGetUnitTransporter(unitID) then
		return false -- UnitUnloaded puts it back on the hot list
	end
	local x, _, z = spGetUnitPosition(unitID)
	local hx, hz = footprint(unitID, unitDefID)
	local other, ox, oz, ohx, ohz = worstOverlap(unitID, x, z, hx, hz, spGetUnitAllyTeam(unitID))
	if not other then
		return false
	end

	local bestX, bestZ, bestDist, fallX, fallZ, fallDist
	for i = 1, 4 do
		local cx, cz = x, z
		if i == 1 then
			cx = ox + hx + ohx
		elseif i == 2 then
			cx = ox - hx - ohx
		elseif i == 3 then
			cz = oz + hz + ohz
		else
			cz = oz - hz - ohz
		end
		local dist = mathAbs(cx - x) + mathAbs(cz - z)
		if canStandAt(unitDefID, cx, cz, hx, hz) then
			if not fallDist or dist < fallDist then
				fallX, fallZ, fallDist = cx, cz, dist
			end
			if (not bestDist or dist < bestDist) and not worstOverlap(unitID, cx, cz, hx, hz) then
				bestX, bestZ, bestDist = cx, cz, dist
			end
		end
	end
	if bestX then
		spSetUnitPosition(unitID, bestX, bestZ, floatOnWater[unitDefID])
		return false
	end
	if fallX then
		-- every way out lands on another structure: take the nearest, resolve that next frame
		spSetUnitPosition(unitID, fallX, fallZ, floatOnWater[unitDefID])
		return true
	end
	return false
end

-- A unit that skipped the build test may overlap the turrets around it. When it
-- is a turret itself, only it moves, never the legally placed ones under it.
local function wakeTurretsAround(unitID, unitDefID)
	if turretDefID[unitID] then
		addHot(unitID)
		return
	end
	if not halfX[unitDefID] or next(turretDefID) == nil then
		return
	end
	local x, _, z = spGetUnitPosition(unitID)
	if not x then
		return
	end
	local hx, hz = footprint(unitID, unitDefID)
	local rx = hx + maxTurretHalf + MIDPOS_MARGIN
	local rz = hz + maxTurretHalf + MIDPOS_MARGIN
	local units = spGetUnitsInRectangle(x - rx, z - rz, x + rx, z + rz)
	for i = 1, #units do
		local uid = units[i]
		if turretDefID[uid] then
			addHot(uid)
		end
	end
end

function gadget:Initialize()
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		local unitID = units[i]
		local unitDefID = spGetUnitDefID(unitID)
		if isTurret[unitDefID] then
			turretDefID[unitID] = unitDefID
		end
	end
	gadgetHandler:RemoveCallIn("GameFrame")
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if isTurret[unitDefID] then
		turretDefID[unitID] = unitDefID
	end
	if not builderID then
		wakeTurretsAround(unitID, unitDefID)
	end
end

function gadget:UnitUnloaded(unitID, unitDefID)
	wakeTurretsAround(unitID, unitDefID)
end

function gadget:UnitDestroyed(unitID, unitDefID)
	if turretDefID[unitID] then
		removeHot(unitID)
		turretDefID[unitID] = nil
	end
end

function gadget:GameFrame()
	-- iterate backwards so swap-removal never skips an entry
	for i = hotCount, 1, -1 do
		local unitID = hot[i]
		if checkTurret(unitID, turretDefID[unitID]) and pushes[unitID] < MAX_PUSHES then
			pushes[unitID] = pushes[unitID] + 1
		else
			removeHot(unitID)
		end
	end
	if hotCount == 0 then
		gadgetHandler:RemoveCallIn("GameFrame")
	end
end
