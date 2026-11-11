local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Explosion Deformation Fix",
		desc = "Restore surviving building foundations after explosion deformation",
		author = "Damgam, GoogleFrog",
		date = "2022",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- Adapted from Zero-K's unit_terraform.lua (GoogleFrog, GPL v2 or later):
-- https://github.com/ZeroK-RTS/Zero-K/blob/7b4cbf2447be3eab19d76c2ebc032153c34f643a/LuaRules/Gadgets/unit_terraform.lua
-- Keep engine foundation protection disabled so delayed lethal explosion damage
-- does not leave flat patches in craters. Periodically restore survivors instead.
local checkFrames = 300
local squareSize = Game.squareSize
local heightParam = "explosion_foundation_height"
local structures = {}
local buckets = {}
local pending = {}
local deformingWeapons = {}
local maxHalfSize = 0
for _, ud in pairs(UnitDefs) do
	if ud.isImmobile and ud.levelGround then
		maxHalfSize = math.max(maxHalfSize, ud.xsize * squareSize / 2, ud.zsize * squareSize / 2)
	end
end
for weaponDefID, wd in pairs(WeaponDefs) do
	if wd.craterAreaOfEffect >= squareSize and wd.damages.craterMult > 0 then
		-- The engine deforms terrain over ten frames and queues damage in a
		-- 128-frame ring. Wait for both before restoring an affected survivor.
		local damageFrames = wd.explosionSpeed > 0 and math.ceil(wd.damageAreaOfEffect / wd.explosionSpeed) or 128
		deformingWeapons[weaponDefID] =
			{ radius = wd.craterAreaOfEffect, wait = math.max(10, math.min(128, damageFrames)) + 1 }
	end
end

local function registerStructure(unitID, unitDefID)
	local ud = UnitDefs[unitDefID]
	if not ud.isImmobile or not ud.levelGround or ud.customParams.mobilebuilding then
		return
	end
	local x, _, z = Spring.GetUnitPosition(unitID)
	if not x or (ud.floatOnWater and Spring.GetGroundHeight(x, z) < 0) then
		return
	end
	local halfX, halfZ = ud.xsize * squareSize / 2, ud.zsize * squareSize / 2
	if Spring.GetUnitBuildFacing(unitID) % 2 == 1 then
		halfX, halfZ = halfZ, halfX
	end
	-- Capture only after initial engine/builder terraforming, not in UnitCreated.
	local height = Spring.GetUnitRulesParam(unitID, heightParam) or Spring.GetGroundHeight(x, z)
	Spring.SetUnitRulesParam(unitID, heightParam, height, { private = true })
	structures[unitID] = {
		height = height,
		restoreAfter = 0,
		minx = math.max(0, x - halfX),
		maxx = math.min(Game.mapSizeX, x + halfX),
		minz = math.max(0, z - halfZ),
		maxz = math.min(Game.mapSizeZ, z + halfZ),
	}
	local phase = unitID % checkFrames
	buckets[phase] = buckets[phase] or {}
	buckets[phase][#buckets[phase] + 1] = unitID
end

function gadget:UnitCreated(unitID, unitDefID)
	if not Spring.ValidUnitID(unitID) or Spring.GetUnitIsDead(unitID) then
		return
	end
	local b1, b2, b3, b4, b5, b6 = Spring.GetUnitBlocking(unitID)
	Spring.SetUnitBlocking(unitID, b1, b2, b3, b4, b5, b6, false)
	if not structures[unitID] then
		pending[#pending + 1] = { unitID, unitDefID }
	end
end

function gadget:UnitDestroyed(unitID)
	for i = #pending, 1, -1 do
		if pending[i][1] == unitID then
			table.remove(pending, i)
		end
	end
	if not structures[unitID] then
		return
	end
	structures[unitID] = nil
	local bucket = buckets[unitID % checkFrames]
	for i = #bucket, 1, -1 do
		if bucket[i] == unitID then
			table.remove(bucket, i)
			break
		end
	end
end

function gadget:Explosion(weaponDefID, x, _, z)
	local weapon = deformingWeapons[weaponDefID]
	if not weapon then
		return false
	end
	local radius = weapon.radius
	local searchRadius = radius + maxHalfSize
	local restoreAfter = Spring.GetGameFrame() + weapon.wait
	for _, unitID in
		ipairs(Spring.GetUnitsInRectangle(x - searchRadius, z - searchRadius, x + searchRadius, z + searchRadius))
	do
		local s = structures[unitID]
		if s and s.minx <= x + radius and s.maxx >= x - radius and s.minz <= z + radius and s.maxz >= z - radius then
			s.restoreAfter = math.max(s.restoreAfter, restoreAfter)
		end
	end
	return false
end

local function needsRestoration(s)
	-- Checking only the center misses explosions that just clip a factory exit.
	for x = s.minx, s.maxx, squareSize do
		for z = s.minz, s.maxz, squareSize do
			if math.abs(Spring.GetGroundHeight(x, z) - s.height) > 0.001 then
				return true
			end
		end
	end
	return false
end

function gadget:GameFrame(frame)
	-- UnitCreated and UnitFinished may run before FlattenGround. Wait until the
	-- next frame, and until construction has advanced beyond terraforming.
	for i = #pending, 1, -1 do
		local unitID, unitDefID = pending[i][1], pending[i][2]
		local health, _, _, _, progress = Spring.GetUnitHealth(unitID)
		if not health or Spring.GetUnitIsDead(unitID) then
			table.remove(pending, i)
		elseif progress > 0 then
			registerStructure(unitID, unitDefID)
			table.remove(pending, i)
		end
	end
	local bucket = buckets[frame % checkFrames]
	if not bucket then
		return
	end
	for i = 1, #bucket do
		local unitID = bucket[i]
		local s = structures[unitID]
		-- Do not bypass the builder's paid, gradual foundation terraforming.
		if
			frame >= s.restoreAfter
			and not Spring.GetUnitIsDead(unitID)
			and not Spring.GetUnitIsBeingBuilt(unitID)
			and needsRestoration(s)
		then
			Spring.LevelHeightMap(s.minx, s.minz, s.maxx, s.maxz, s.height)
		end
	end
end

function gadget:Initialize()
	if not Game.mapDamage then
		gadgetHandler:RemoveGadget(self)
		return
	end
	for weaponDefID in pairs(deformingWeapons) do
		Script.SetWatchExplosion(weaponDefID, true)
	end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		self:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end
