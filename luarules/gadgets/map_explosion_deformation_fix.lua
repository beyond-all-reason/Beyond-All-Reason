local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Explosion Deformation Fix",
		desc = "Settle surviving structures onto their deformed foundations",
		author = "Damgam, GoogleFrog, BAR contributors",
		license = "GNU GPL, v2 or later",
		layer = -100,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- Recoil source references use https://github.com/beyond-all-reason/RecoilEngine/commit/a397adc5ea6a931f861e2b36f6b243df37b5e9be

local square = Game.squareSize
local moveTag = 0x464E44 -- "FND"
local move = Spring.MoveCtrl
local ground = Spring.GetGroundHeight
local pending = {}
local halfSizes = {}
local maxHalfSize = 0.0
local weapons = {}

-- Builder bounds use half the footprint in map squares on either side of the building center.
-- Odd build facings exchange the X and Z sizes (see footprint below).
-- Builder.cpp:862-865, BuildInfo.cpp:73-83
for id, ud in pairs(UnitDefs) do
	if ud.isImmobile and ud.levelGround and not ud.customParams.mobilebuilding then
		local x, z = ud.xsize * square / 2, ud.zsize * square / 2
		halfSizes[id] = { x, z }
		maxHalfSize = math.max(maxHalfSize, x, z)
	end
end

for id, wd in pairs(WeaponDefs) do
	if wd.craterAreaOfEffect >= square and wd.damages.craterMult > 0 then
		-- Recoil spreads deformation over 10 frames and queues blast damage by distance / speed in a 128-slot ring.
		-- This gadget uses the whole damage radius as a conservative delay and settles one frame later.
		-- BasicMapDamage.h:65, GameHelper.cpp:166-172, GameHelper.h:273
		local travel = wd.explosionSpeed > 0 and math.ceil(wd.damageAreaOfEffect / wd.explosionSpeed) or 128
		weapons[id] = { radius = wd.craterAreaOfEffect, wait = math.max(10, math.min(128, travel)) + 1 }
	end
end

local function footprint(id)
	local def = Spring.GetUnitDefID(id)
	local half = halfSizes[def]
	if not half or Spring.GetUnitIsDead(id) then
		return
	end
	local x, _, z = Spring.GetUnitPosition(id)
	local facing = Spring.GetUnitBuildFacing(id)
	if not (x and z and facing) then
		return
	end
	if UnitDefs[def].floatOnWater and ground(x, z) < 0 then
		return
	end
	local hx, hz = half[1], half[2]
	if facing % 2 == 1 then
		hx, hz = hz, hx
	end
	return {
		x1 = math.max(0, x - hx),
		x2 = math.min(Game.mapSizeX, x + hx),
		z1 = math.max(0, z - hz),
		z2 = math.min(Game.mapSizeZ, z + hz),
	}
end

-- Average the whole footprint so an off-center crater contributes in proportion to the area it affects.
-- At build time Recoil averages the four corners of one 8 x 8 elmo square at the build position, then applies height limits.
-- GameHelper.cpp:1206-1243
local function heights(s)
	local values, sum = {}, 0.0
	for x = s.x1, s.x2, square do
		for z = s.z1, s.z2, square do
			local h = ground(x, z)
			values[#values + 1] = h
			sum = sum + h
		end
	end
	return values, sum / #values
end

local function allowDeformation(id)
	local b1, b2, b3, b4, b5, b6 = Spring.GetUnitBlocking(id)
	Spring.SetUnitBlocking(id, b1, b2, b3, b4, b5, b6, false)
end

function gadget.UnitCreated(_, id)
	allowDeformation(id)
end

function gadget.Explosion(_, def, x, y, z)
	local w = weapons[def]
	if not w then
		return false
	end
	-- The engine calls Explosion before damage and subtracts height above terrain from crater AOE.
	-- Basic map damage skips radii below eight elmos. This candidate test can include hits too weak to deform.
	-- GameHelper.cpp:263-270, GameHelper.cpp:306-316, BasicMapDamage.cpp:90-104
	local altitude = y - ground(x, z)
	local radius = w.radius - altitude
	if altitude < -1 or radius < square then
		return false
	end
	local reach = radius + maxHalfSize
	local deadline = Spring.GetGameFrame() + w.wait
	for _, id in ipairs(Spring.GetUnitsInRectangle(x - reach, z - reach, x + reach, z + reach)) do
		local s = pending[id] or footprint(id)
		if s and not Spring.GetUnitIsBeingBuilt(id) then
			-- Squared distance from the impact to the nearest point on the footprint rectangle.
			-- A point inside an axis interval contributes zero on that axis.
			local dx = math.max(s.x1 - x, 0.0, x - s.x2)
			local dz = math.max(s.z1 - z, 0.0, z - s.z2)
			if dx * dx + dz * dz <= radius * radius then
				if pending[id] then
					s.deadline = math.max(s.deadline, deadline)
				elseif not move.IsEnabled(id) then
					s.before = heights(s)
					s.deadline = deadline
					pending[id] = s
					move.Enable(id)
					move.SetTag(id, moveTag)
					move.SetExtrapolate(id, false)
					move.SetTrackGround(id, false)
				end
			end
		end
	end
	return false
end

local function neighbors(id, s)
	local near = {}
	local padding = maxHalfSize + 3 * square
	for _, other in ipairs(Spring.GetUnitsInRectangle(s.x1 - padding, s.z1 - padding, s.x2 + padding, s.z2 + padding)) do
		if other ~= id then
			local area = footprint(other)
			if area then
				near[#near + 1] = area
			end
		end
	end
	return near
end

local function protected(near, x, z)
	for _, n in ipairs(near) do
		if x >= n.x1 and x <= n.x2 and z >= n.z1 and z <= n.z2 then
			return true
		end
	end
	return false
end

-- Use the final linear profile of the builder’s four side strips, three map squares wide.
-- This gadget shortens a strip if it reaches a neighboring foundation.
-- Builder.h:65, Builder.cpp:160-201
local function slope(x, z, dx, dz, near)
	local ax, az = x + 3 * dx, z + 3 * dz
	if ax < 0 or az < 0 or ax >= Game.mapSizeX or az >= Game.mapSizeZ then
		return
	end
	local steps = 3
	for i = 1, 2 do
		if protected(near, x + i * dx, z + i * dz) then
			steps = i
			break
		end
	end
	local h, outer = ground(x, z), ground(x + steps * dx, z + steps * dz)
	for i = 1, steps - 1 do
		Spring.SetHeightMap(x + i * dx, z + i * dz, h + (outer - h) * i / steps)
	end
end

local function level(s, target, near)
	for x = s.x1, s.x2, square do
		for z = s.z1, s.z2, square do
			if not protected(near, x, z) then
				Spring.SetHeightMap(x, z, target)
			end
		end
	end
	for z = s.z1, s.z2, square do
		slope(s.x1, z, -square, 0, near)
		slope(s.x2, z, square, 0, near)
	end
	for x = s.x1, s.x2, square do
		slope(x, s.z1, 0, -square, near)
		slope(x, s.z2, 0, square, near)
	end
end

local function release(id)
	if move.GetTag(id) ~= moveTag then
		return
	end
	local blocking = Spring.GetUnitBlocking(id)
	local yard = blocking and Spring.GetUnitCOBValue(id, COB.YARD_OPEN)
	move.Disable(id)
	-- The script move type destructor unblocks the unit.
	if blocking then
		Spring.SetUnitBlocking(id, true)
		if yard == 1 then
			Spring.SetUnitCOBValue(id, COB.YARD_OPEN, 1)
		end
	end
end

local function settle(id, s)
	if move.GetTag(id) ~= moveTag then
		return
	end
	local after, target = heights(s)
	for i, h in ipairs(after) do
		if math.abs(h - s.before[i]) > 0.00001 then
			local x, _, z = Spring.GetUnitPosition(id)
			if x and z then
				local near = neighbors(id, s)
				Spring.SetHeightMapFunc(function()
					level(s, target, near)
				end)
				move.SetPosition(id, x, ground(x, z), z)
			end
			break
		end
	end
	release(id)
end

function gadget.GameFrame(_, frame)
	if not next(pending) then
		return
	end
	local due = {}
	for id, s in pairs(pending) do
		if frame >= s.deadline then
			due[#due + 1] = id
		end
	end
	table.sort(due)
	for _, id in ipairs(due) do
		if not Spring.GetUnitIsDead(id) then
			settle(id, pending[id])
		end
		pending[id] = nil
	end
end

function gadget.UnitDestroyed(_, id)
	pending[id] = nil
end

function gadget.UnitReverseBuilt(_, id)
	if pending[id] then
		pending[id] = nil
		release(id)
	end
end

function gadget.Shutdown()
	for id in pairs(pending) do
		release(id)
	end
end

function gadget:Initialize()
	if not Game.mapDamage then
		gadgetHandler:RemoveGadget(self)
		return
	end
	for id in pairs(weapons) do
		gadgetHandler:RegisterExplosion(id)
	end
	for _, id in ipairs(Spring.GetAllUnits()) do
		allowDeformation(id)
	end
end
