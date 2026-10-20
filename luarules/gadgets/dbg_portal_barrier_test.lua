-- This file is part of Zero-K (GPL v2 or later), see LICENSE.
function gadget:GetInfo()
	return { name = "Portal compact barrier regression", layer = -100, enabled = true }
end
if not gadgetHandler:IsSyncedCode() or Spring.GetModOptions().portal_worlds_test ~= "barriers" then
	return false
end
local world = VFS.Include("luarules/Utilities/portal_worlds.lua")
local cases = {}
local function Check(name, value, detail)
	Spring.Echo("[BAR_BARRIER_TEST] ASSERT " .. name .. " pass=" .. tostring(not not value) .. " " .. (detail or ""))
end
local function Team(region)
	for _, entry in ipairs(world.teams) do
		if entry.region == region then
			return entry.team
		end
	end
end
local function Spawn(name, x, z, region)
	local id = assert(Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, 0, Team(region)))
	Spring.GiveOrderToUnit(id, CMD.FIRE_STATE, { 0 }, 0)
	return id
end
local function Points(a, b)
	if a.x1 <= b.x0 and math.min(a.z1, b.z1) > math.max(a.z0, b.z0) then
		local z = (math.min(a.z1, b.z1) + math.max(a.z0, b.z0)) / 2
		return { a.x1 - 64, z, b.x0 + 128, z, (a.x1 + b.x0) / 2, z, -1, 0 }
	end
	if a.z1 <= b.z0 and math.min(a.x1, b.x1) > math.max(a.x0, b.x0) then
		local x = (math.min(a.x1, b.x1) + math.max(a.x0, b.x0)) / 2
		return { x, a.z1 - 64, x, b.z0 + 128, x, (a.z1 + b.z0) / 2, 0, -1 }
	end
end
function gadget:GameFrame(f)
	if f == 1 then
		for _, id in ipairs(Spring.GetAllUnits()) do
			Spring.GiveOrderToUnit(id, CMD.FIRE_STATE, { 0 }, 0)
		end
	end
	if f == 30 then
		Check("compact_strip", world.minimumGap == world.gap and world.gap <= 512)
		-- Flat lanes exist only in this opt-in fixture. Movement rejection must
		-- come from barrier terrain, rather than the source maps' cliff slopes.
		Spring.LevelHeightMap(8, 8, world.size[1] - 8, world.size[2] - 8, 200)
		for i, a in ipairs(world.regions) do
			for j, b in ipairs(world.regions) do
				local p = i ~= j and Points(a, b)
				if p then
					cases[#cases + 1] = { a = i, b = j, p = p }
				end
			end
		end
		Check("adjacent_barriers_present", #cases >= 4)
	end
	for index, c in ipairs(cases) do
		local start = 60 + (index - 1) * 180
		local p = c.p
		local x, z, fx, fz, bx, bz, dx, dz = unpack(p)
		if f == start then
			c.owner = Spawn("armsolar", x + dx * 500, z + dz * 500, c.a)
			c.target = Spawn("armsolar", fx, fz, c.b)
			c.health = Spring.GetUnitHealth(c.target)
			c.targetY = select(2, Spring.GetUnitPosition(c.target))
			c.air = Spawn("armpeep", x + dx * 500, z + dz * 500, c.a)
			for _, kind in ipairs({ "armflea", "armflash", "armsh", "armamph", "armpt" }) do
				Check(
					"strip_blocks_" .. index .. "_" .. kind,
					not Spring.TestMoveOrder(
						UnitDefNames[kind].id,
						bx,
						Spring.GetGroundHeight(bx, bz),
						bz,
						0,
						0,
						0,
						true,
						false,
						true
					)
				)
			end
			Check(
				"strip_blocks_building_" .. index,
				Spring.TestBuildOrder(UnitDefNames.armsolar.id, bx, Spring.GetGroundHeight(bx, bz), bz, 0) == 0
			)
			-- Extractors intentionally ignore native building masks. The normal
			-- portal command gate must still reject their orders into the strip.
			local builder = Spawn("armck", x + dx * 850, z + dz * 850, c.a)
			Spring.GiveOrderToUnit(builder, -UnitDefNames.armmex.id, { bx, 200, bz, 0 }, 0)
			Check("strip_rejects_mex_order_" .. index, #Spring.GetUnitCommands(builder, -1) == 0)
			c.localX, c.localZ = x + dx * 550 - dz * 180, z + dz * 550 + dx * 180
			c.localWalker = Spawn("armflea", x + dx * 350 - dz * 180, z + dz * 350 + dx * 180, c.a)
			c.foreignWalker = Spawn("armflea", x + dx * 300 + dz * 180, z + dz * 300 - dx * 180, c.a)
			Spring.SetUnitMoveGoal(c.localWalker, c.localX, 200, c.localZ, 16)
			Spring.SetUnitMoveGoal(c.foreignWalker, fx, 200, fz, 16)

			Spring.SetUnitPosition(c.air, fx, 400, fz)
		end
		if f == start + 90 then
			Check("air_cannot_cross_without_portal_" .. index, GG.PortalWorlds.home[c.air] == c.a and (function()
				local ax, _, az = Spring.GetUnitPosition(c.air)
				return world.Region(ax, az) == c.a
			end)())
			local lx, _, lz = Spring.GetUnitPosition(c.localWalker)
			Check("local_path_works_" .. index, (lx - c.localX) ^ 2 + (lz - c.localZ) ^ 2 < 64 ^ 2)
			local wx, _, wz = Spring.GetUnitPosition(c.foreignWalker)
			local foreignPath = false
			for _, point in ipairs(Spring.GetUnitEstimatedPath(c.foreignWalker) or {}) do
				if world.Region(point[1], point[3]) == c.b then
					foreignPath = true
				end
			end
			Check("foreign_path_blocked_" .. index, world.Region(wx, wz) == c.a and not foreignPath)
			c.samples = {}
			for sx = math.max(0, x - 1400), math.min(world.size[1] - 8, x + 1400), 64 do
				for sz = math.max(0, z - 1400), math.min(world.size[2] - 8, z + 1400), 64 do
					if world.Region(sx, sz) ~= c.a then
						c.samples[#c.samples + 1] = { sx, sz, Spring.GetGroundHeight(sx, sz) }
					end
				end
			end
			c.localGround = Spring.GetGroundHeight(x + dx * 200, z + dz * 200)
			local shot = assert(Spring.SpawnProjectile(WeaponDefNames.armsilo_nuclear_missile.id, {
				pos = { x, Spring.GetGroundHeight(x, z) + 1, z },
				speed = { 0, 0, 0 },
				owner = c.owner,
				ttl = 300,
			}))
			Spring.SetProjectileCollision(shot)
		end
		if f == start + 125 then
			local maxDiff = 0
			for _, s in ipairs(c.samples) do
				maxDiff = math.max(maxDiff, math.abs(Spring.GetGroundHeight(s[1], s[2]) - s[3]))
			end
			Check(
				"nuke_keeps_foreign_and_barrier_height_" .. index,
				maxDiff == 0,
				"samples=" .. #c.samples .. " maxDiff=" .. maxDiff
			)
			Check(
				"nuke_keeps_foreign_building_health_" .. index,
				Spring.ValidUnitID(c.target) and Spring.GetUnitHealth(c.target) == c.health
			)
			Check(
				"nuke_keeps_foreign_building_height_" .. index,
				Spring.ValidUnitID(c.target) and select(2, Spring.GetUnitPosition(c.target)) == c.targetY
			)
			Check(
				"local_nuke_crater_works_" .. index,
				math.abs(Spring.GetGroundHeight(x + dx * 200, z + dz * 200) - c.localGround) > 0.01
			)
		end
	end
end
