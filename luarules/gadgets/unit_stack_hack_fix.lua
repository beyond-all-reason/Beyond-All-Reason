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

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTransporter = Spring.GetUnitTransporter
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetGroundHeight = Spring.GetGroundHeight
local spSetUnitPosition = Spring.SetUnitPosition
local mathRandom = math.random

local mapsizeX = Game.mapSizeX
local mapsizeZ = Game.mapSizeZ

-- Fully event driven: turrets are static and only end up stacked when a
-- structure is created or unloaded on top of them, so those events put the
-- turrets around the new unit on a "hot" list. Hot turrets are nudged every
-- frame until no immobile ally is left inside their search radius. GameFrame
-- is switched off entirely while the hot list is empty, so an idle base costs
-- nothing per frame.
local WAKE_MARGIN = 32

local searchRadius = {} -- unitDefID -> search radius (nano turrets only)
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
end

-- Nudges the turret away from the nearest immobile ally inside its search
-- radius. Returns true when such an ally exists, i.e. recheck next frame.
local function checkTurret(unitID, unitDefID)
	local x, _, z = spGetUnitPosition(unitID)
	local radius = searchRadius[unitDefID]
	local allyTeam = spGetUnitAllyTeam(unitID)
	local units = spGetUnitsInCylinder(x, z, radius)
	local ax, az, nearestSq = nil, nil, radius * radius + 1
	for i = 1, #units do
		local other = units[i]
		if other ~= unitID and not canMove[spGetUnitDefID(other)] and spGetUnitAllyTeam(other) == allyTeam then
			local ox, _, oz = spGetUnitPosition(other)
			local ddx, ddz = ox - x, oz - z
			local distSq = ddx * ddx + ddz * ddz
			if distSq < nearestSq then
				ax, az, nearestSq = ox, oz, distSq
			end
		end
	end
	if not ax then
		return false
	end
	if spGetUnitTransporter(unitID) then
		return true
	end

	local dx, dz = 0, 0
	local r = mathRandom(1, 3)
	if r == 1 then
		if x == ax or z == az then
			local testRange = radius * 2
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
			turretDefID[unitID] = unitDefID
			addHot(unitID)
		end
	end
	if hotCount == 0 then
		gadgetHandler:RemoveCallIn("GameFrame")
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if searchRadius[unitDefID] then
		turretDefID[unitID] = unitDefID
		addHot(unitID)
	end
	wakeTurretsNear(unitID, unitDefID)
end

function gadget:UnitUnloaded(unitID, unitDefID)
	wakeTurretsNear(unitID, unitDefID)
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
		if not checkTurret(unitID, turretDefID[unitID]) then
			removeHot(unitID)
		end
	end
	if hotCount == 0 then
		gadgetHandler:RemoveCallIn("GameFrame")
	end
end
