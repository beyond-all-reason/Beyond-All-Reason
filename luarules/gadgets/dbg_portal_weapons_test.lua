-- SPDX-License-Identifier: GPL-2.0-or-later
function gadget:GetInfo()
	return {
		name = "Portal strategic weapons verification",
		desc = "Opt-in real stockpiled launches, interception and provenance",
		author = "Codex",
		license = "GPL v2 or later",
		layer = -100,
		enabled = true,
	}
end
if not gadgetHandler:IsSyncedCode() or Spring.GetModOptions().portal_worlds_test ~= "weapons" then
	return false
end
local world = VFS.Include("luarules/Utilities/portal_worlds.lua")
local silos, targets, health, launched, anti = {}, {}, {}, {}, nil
local movingOwner, movingProjectile, movingTarget, movingHealth
local feature, featureHealth
local antiShots = 0
local nukeDef = WeaponDefNames.armsilo_nuclear_missile.id
local function Check(name, pass, detail)
	Spring.Echo(
		"[BAR_WEAPON_TEST] ASSERT " .. name .. " pass=" .. tostring(not not pass) .. " " .. (detail or "")
	)
end
local function Spawn(name, region, x, z, team)
	local r = world.regions[region]
	x, z = r.x0 + x, r.z0 + z
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, 0, team)
	assert(id, "Could not spawn " .. name)
	Spring.GiveOrderToUnit(id, CMD.FIRE_STATE, { 0 }, 0)
	Spring.GiveOrderToUnit(id, CMD.MOVE_STATE, { 0 }, 0)
	return id
end
function gadget:ProjectileCreated(id, owner, weapon)
	if owner == anti and WeaponDefs[weapon].interceptor > 0 then
		antiShots = antiShots + 1
		Spring.Echo("[BAR_WEAPON_TEST] INTERCEPTOR frame=" .. Spring.GetGameFrame())
	end
	if weapon == nukeDef then
		for i, silo in pairs(silos) do
			if owner == silo then
				launched[i] = (launched[i] or 0) + 1
				Spring.Echo(
					"[BAR_WEAPON_TEST] LAUNCH case="
						.. i
						.. " frame="
						.. Spring.GetGameFrame()
						.. " projectile="
						.. id
				)
			end
		end
	end
end
function gadget:GameFrame(f)
	if f == 1 then
		for _, id in ipairs(Spring.GetAllUnits()) do
			Spring.GiveOrderToUnit(id, CMD.FIRE_STATE, { 0 }, 0)
			Spring.GiveOrderToUnit(id, CMD.MOVE_STATE, { 0 }, 0)
		end
	end
	if f == 60 then
		for i = 1, 3 do
			silos[i] = Spawn("armsilo", i, 1100, 1100, (i - 1) * 2)
			Spring.SetUnitStockpile(silos[i], 1)
			Check("stockpiled_" .. i, Spring.GetUnitStockpile(silos[i]) == 1)
			local destination = i == 3 and 4 or i
			targets[i] = Spawn("armsolar", destination, 2900, 2900, i * 2)
			health[i] = Spring.GetUnitHealth(targets[i])
		end
		anti = Spawn("armamd", 2, 2700, 2900, 4)
		Spring.SetUnitStockpile(anti, 1)
		Spring.GiveOrderToUnit(anti, CMD.FIRE_STATE, { 2 }, 0)
		for i = 1, 2 do
			local x, y, z = Spring.GetUnitPosition(targets[i])
			Spring.GiveOrderToUnit(silos[i], CMD.FIRE_STATE, { 2 }, 0)
			Spring.GiveOrderToUnit(silos[i], CMD.ATTACK, { x, y, z }, 0)
		end
		local x, y, z = Spring.GetUnitPosition(targets[3])
		Spring.GiveOrderToUnit(silos[3], CMD.ATTACK, { x, y, z }, 0)
		Check(
			"remote_order_preserves_stockpile",
			Spring.GetUnitStockpile(silos[3]) == 1 and #Spring.GetUnitCommands(silos[3], -1) == 0
		)
		-- Bypass player command handling to exercise the projectile safety net.
		Spring.GiveOrderToUnit(silos[3], CMD.FIRE_STATE, { 2 }, 0)
		Spring.SetUnitTarget(silos[3], x, y, z, false, true)
		local r = world.regions[3]
		feature = Spring.CreateFeature(
			"armmex_dead",
			r.x0 + 1900,
			Spring.GetGroundHeight(r.x0 + 1900, r.z0 + 1700),
			r.z0 + 1700,
			0,
			Spring.GetGaiaTeamID()
		)
		assert(feature, "Fixture wreck missing")
		featureHealth = Spring.GetFeatureHealth(feature)
		Spring.AddFeatureDamage(feature, 10, 0, silos[1], -1)
		Check("foreign_wreck_damage_blocked", Spring.GetFeatureHealth(feature) == featureHealth)
		Spring.AddFeatureDamage(feature, 10, 0, silos[3], -1)
		Check("local_wreck_damage_allowed", Spring.GetFeatureHealth(feature) < featureHealth)
	end
	if f == 240 then
		local id
		for _, unit in ipairs(Spring.GetTeamUnits(1)) do
			if UnitDefs[Spring.GetUnitDefID(unit)].customParams.iscommander then
				id = unit
				break
			end
		end
		Spring.DestroyUnit(id, false, false)
	end
	if f == 300 then
		local m = GG.PortalWorlds.mouths[1][1]
		movingOwner = Spring.CreateUnit("armpeep", m.x, m.y + 150, m.z, 0, 0)
		Spring.GiveOrderToUnit(movingOwner, CMD.FIRE_STATE, { 0 }, 0)
		movingTarget = Spawn("armsolar", 1, 2800, 1300, 2)
		movingHealth = Spring.GetUnitHealth(movingTarget)
		local x, y, z = Spring.GetUnitPosition(movingTarget)
		movingProjectile = Spring.SpawnProjectile(
			nukeDef,
			{
				pos = { m.x, m.y + 500, m.z },
				["end"] = { x, y, z },
				speed = { 0, 2, 0 },
				owner = movingOwner,
				team = 0,
				ttl = 1800,
				upTime = 900,
			}
		)
		Spring.GiveOrderToUnit(movingOwner, GameCMD.PORTAL_TRAVEL, { 1 }, 0)
	end
	if f == 420 then
		Check("missile_owner_travelled", GG.PortalWorlds.home[movingOwner] == 2)
		local record = GG.PortalIsolation.projectiles[movingProjectile]
		Check("launch_region_survives_owner_transit", record and record.region == 1)
		local x, y, z = Spring.GetUnitPosition(movingTarget)
		Spring.SetProjectilePosition(movingProjectile, x, y + 25, z)
		Spring.SetProjectileCollision(movingProjectile)
	end
	if f == 600 then
		Check(
			"old_map_missile_still_damages_after_owner_transit",
			not Spring.ValidUnitID(movingTarget)
				or Spring.GetUnitIsDead(movingTarget)
				or Spring.GetUnitHealth(movingTarget) < movingHealth
		)
	end
	if f == 1800 then
		for i = 1, 3 do
			Check("real_silo_launched_" .. i, (launched[i] or 0) > 0, "count=" .. tostring(launched[i]))
		end
		Check(
			"local_nuke_damaged_target",
			not Spring.ValidUnitID(targets[1])
				or Spring.GetUnitIsDead(targets[1])
				or Spring.GetUnitHealth(targets[1]) < health[1]
		)
		Check(
			"local_antinuke_protected_target",
			Spring.ValidUnitID(targets[2]) and Spring.GetUnitHealth(targets[2]) == health[2]
		)
		Check("local_antinuke_fired_interceptor", antiShots > 0, "shots=" .. antiShots)
		Check(
			"forced_remote_nuke_no_damage",
			Spring.ValidUnitID(targets[3]) and Spring.GetUnitHealth(targets[3]) == health[3]
		)
		Check(
			"forced_remote_projectile_removed",
			(Spring.GetGameRulesParam("portal_deleted_projectiles") or 0) > 0
		)
	end
end
