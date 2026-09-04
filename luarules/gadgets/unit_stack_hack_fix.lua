local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Anti Stacking Hax",
		desc = "Nudges nano turrets apart when they end up stacked on top of another structure",
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

local spGetUnitNearestAlly = Spring.GetUnitNearestAlly
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTransporter = Spring.GetUnitTransporter
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetGroundHeight = Spring.GetGroundHeight
local spSetUnitPosition = Spring.SetUnitPosition
local mathRandom = math.random

local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ

-- Turrets are static, so a turret with nothing inside its search radius only
-- needs an occasional recheck. Each turret is assigned to one of SLOW_INTERVAL
-- frame buckets (by unitID) so the slow checks are spread evenly over frames.
-- A turret that had an ally in range is put on the "hot" list and rechecked
-- every frame until it is clear again. Placing or unloading an immobile unit
-- wakes the turrets around it immediately, so stacking is still caught on the
-- frame it happens.
local SLOW_INTERVAL = 30
local WAKE_MARGIN = 32

local searchRadius = {} -- unitDefID -> nearest-ally search radius (nano turrets only)
local minDepthLimit = {} -- unitDefID -> -minWaterDepth (target ground height must be below this)
local maxDepthLimit = {} -- unitDefID -> -maxWaterDepth (target ground height must be above this)
local canMove = {}
local maxSearchRadius = 0
for udid, ud in pairs(UnitDefs) do
	if ud.customParams.isnanoturret then
		local radius = math.floor(((ud.xsize + ud.zsize) * 0.5) * 6)
		searchRadius[udid] = radius
		minDepthLimit[udid] = -ud.minWaterDepth
		maxDepthLimit[udid] = -ud.maxWaterDepth
		if radius > maxSearchRadius then
			maxSearchRadius = radius
		end
	end
	if ud.canMove then
		canMove[udid] = true
	end
end
local wakeRadius = maxSearchRadius + WAKE_MARGIN

local turretDefID = {} -- unitID -> unitDefID for every live nano turret

local buckets = {} -- frame slot -> array of unitIDs checked on that slot
for i = 0, SLOW_INTERVAL - 1 do
	buckets[i] = {}
end
local bucketPos = {} -- unitID -> index inside its bucket

local hot = {} -- array of unitIDs checked every frame
local hotCount = 0
local hotPos = {} -- unitID -> index inside hot, nil when not hot

local function addHot(unitID)
	if hotPos[unitID] then
		return
	end
	hotCount = hotCount + 1
	hot[hotCount] = unitID
	hotPos[unitID] = hotCount
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
end

local function registerTurret(unitID, unitDefID)
	turretDefID[unitID] = unitDefID
	local bucket = buckets[unitID % SLOW_INTERVAL]
	local n = #bucket + 1
	bucket[n] = unitID
	bucketPos[unitID] = n
	addHot(unitID)
end

local function unregisterTurret(unitID)
	removeHot(unitID)
	local bucket = buckets[unitID % SLOW_INTERVAL]
	local pos = bucketPos[unitID]
	local n = #bucket
	local last = bucket[n]
	bucket[pos] = last
	bucketPos[last] = pos
	bucket[n] = nil
	bucketPos[unitID] = nil
	turretDefID[unitID] = nil
end

-- Returns true when any ally is inside the turret's search radius, i.e. the
-- turret needs rechecking next frame.
local function checkTurret(unitID, unitDefID)
	local nearestAlly = spGetUnitNearestAlly(unitID, searchRadius[unitDefID])
	if not nearestAlly then
		return false
	end
	if canMove[spGetUnitDefID(nearestAlly)] or spGetUnitTransporter(unitID) then
		return true
	end

	local x, _, z = spGetUnitPosition(unitID)
	local ax, _, az = spGetUnitPosition(nearestAlly)
	local dx, dz = 0, 0
	local r = mathRandom(1, 3)
	if r == 1 then
		if x == ax or z == az then
			local testRange = searchRadius[unitDefID] * 2
			dx = mathRandom(-testRange, testRange)
			dz = mathRandom(-testRange, testRange)
		end
	elseif r == 2 then
		if x > ax then
			dx = mathRandom(1, 10)
		elseif x < ax then
			dx = -mathRandom(1, 10)
		end
	else
		if z > az then
			dz = mathRandom(1, 10)
		elseif z < az then
			dz = -mathRandom(1, 10)
		end
	end
	if dx == 0 and dz == 0 then
		return true
	end

	local tx, tz = x + dx, z + dz
	if tx < 0 or tx > mapsizeX or tz < 0 or tz > mapsizeZ then
		return true
	end
	local ty = spGetGroundHeight(tx, tz)
	if ty < minDepthLimit[unitDefID] and ty > maxDepthLimit[unitDefID] then
		spSetUnitPosition(unitID, tx, tz)
	end
	return true
end

-- An immobile unit that just appeared may be sitting on top of a turret.
local function wakeTurretsNear(unitID, unitDefID)
	if canMove[unitDefID] or next(turretDefID) == nil then
		return
	end
	local x, _, z = spGetUnitPosition(unitID)
	if not x then
		return
	end
	local units = spGetUnitsInCylinder(x, z, wakeRadius)
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
		if searchRadius[unitDefID] then
			registerTurret(unitID, unitDefID)
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if searchRadius[unitDefID] then
		registerTurret(unitID, unitDefID)
	end
	wakeTurretsNear(unitID, unitDefID)
end

function gadget:UnitUnloaded(unitID, unitDefID)
	wakeTurretsNear(unitID, unitDefID)
end

function gadget:UnitDestroyed(unitID, unitDefID)
	if turretDefID[unitID] then
		unregisterTurret(unitID)
	end
end

function gadget:GameFrame(n)
	-- idle turrets: once every SLOW_INTERVAL frames; ones with an ally in range go hot
	local hotBefore = hotCount
	local bucket = buckets[n % SLOW_INTERVAL]
	for i = 1, #bucket do
		local unitID = bucket[i]
		if not hotPos[unitID] and checkTurret(unitID, turretDefID[unitID]) then
			addHot(unitID)
		end
	end

	-- turrets that had an ally in range on an earlier frame: every frame
	-- (turrets added above start next frame; iterate backwards so
	-- swap-removal never skips an entry)
	for i = hotBefore, 1, -1 do
		local unitID = hot[i]
		if not checkTurret(unitID, turretDefID[unitID]) then
			removeHot(unitID)
		end
	end
end
