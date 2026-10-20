-- SPDX-License-Identifier: GPL-2.0-or-later
function gadget:GetInfo()
	return {
		name = "Portal weapon isolation",
		desc = "Keep weapons, damage and interception in their launch map",
		author = "Codex",
		license = "GPL v2 or later",
		layer = -60,
		enabled = true,
	}
end
local options = Spring.GetModOptions()
if not gadgetHandler:IsSyncedCode() or not options.portal_worlds or options.portal_worlds == "off" then
	return false
end
local world = VFS.Include("luarules/Utilities/portal_worlds.lua")
if not world then
	return false
end
local projectiles, units, retired = {}, {}, {}
local blocked, deleted = 0, 0
local damageRegion
local function UnitRegion(id)
	local portal = GG.PortalWorlds
	if portal and portal.home[id] then
		return portal.home[id]
	end
	local x, _, z = Spring.GetUnitPosition(id)
	return world.Region(x, z) or units[id]
end
local function TargetRegion(id)
	local kind, target = Spring.GetProjectileTarget(id)
	if kind == string.byte("g") and type(target) == "table" then
		-- Scripted projectiles often start with an unset zero target.
		if target[1] ~= 0 or target[3] ~= 0 then
			return world.Region(target[1], target[3])
		end
	end
	if kind == string.byte("u") then
		return UnitRegion(target)
	end
	if kind == string.byte("f") then
		local x, _, z = Spring.GetFeaturePosition(target)
		return world.Region(x, z)
	end
end
local function Delete(id)
	local p = projectiles[id]
	if p and not p.deleted then
		p.deleted = true
		deleted = deleted + 1
		-- Some scripted weapons force collision immediately after spawning. A
		-- delete request is deferred by the engine; move rejected projectiles
		-- beyond terrain/AOE reach first so that collision cannot crater a map.
		Spring.SetProjectilePosition(id, -world.size[1] - world.gap, 100000, -world.size[2] - world.gap)
		Spring.SetProjectileVelocity(id, 0, 0, 0)
		Spring.DeleteProjectile(id)
	end
end
local function DamageAllowed(targetRegion, attacker, projectile)
	local p = projectile and projectiles[projectile]
	local source = (p and p.region) or damageRegion or (attacker and UnitRegion(attacker))
	if source and targetRegion and source ~= targetRegion then
		blocked = blocked + 1
		return false
	end
	return true
end
-- Persistent area damage belongs to its physical origin; attached statuses
-- belong to their victim. Preserve that provenance when no projectile ID exists.
local function Pack(...)
	return { n = select("#", ...), ... }
end
local function DamageInRegion(region, callback, ...)
	if not region then
		return
	end
	local previous = damageRegion
	damageRegion = region
	local result = Pack(pcall(callback, ...))
	damageRegion = previous
	if not result[1] then
		error(result[2])
	end
	return unpack(result, 2, result.n)
end
function gadget:AllowWeaponTarget(attacker, target, weaponNum, weaponDef, priority)
	if GG.PortalWorlds and GG.PortalWorlds.beacons[target] then
		return false, priority
	end
	local source, destination = UnitRegion(attacker), UnitRegion(target)
	return source ~= nil and source == destination, priority
end
function gadget:Initialize()
	local maxCrater, maxArea = 0, 0
	for id, wd in pairs(WeaponDefs) do
		Script.SetWatchProjectile(id, true)
		Script.SetWatchAllowTarget(id, true)
		maxCrater = math.max(maxCrater, wd.craterAreaOfEffect or 0)
		maxArea = math.max(maxArea, wd.damageAreaOfEffect or 0)
	end
	-- The engine clips native craters to their impact region. Game-side damage
	-- filtering alone cannot protect the heightmap across compact barriers.
	assert(Engine.FeatureSupport.mapDamageRegions, "Portal worlds require native crater-region support")
	Spring.Echo(
		"[PORTAL_ISOLATION] maxCrater=" .. maxCrater .. " maxDamageRadius=" .. maxArea .. " gap=" .. world.minimumGap
	)
	GG.PortalIsolation = {
		projectiles = projectiles,
		DeleteProjectile = Delete,
		ProjectilePositionAllowed = function(id, x, z)
			local p = projectiles[id]
			return p and not p.deleted and p.region ~= nil and world.Region(x, z) == p.region
		end,
		UnitRegion = UnitRegion,
		Region = world.Region,
		DamageAllowed = DamageAllowed,
		DamageInRegion = DamageInRegion,
		UnitDamageAllowed = function(id, attacker, projectile)
			if GG.PortalWorlds and GG.PortalWorlds.beacons[id] then
				return false
			end
			return DamageAllowed(UnitRegion(id), attacker, projectile)
		end,
	}
end
function gadget:UnitCreated(id)
	local x, _, z = Spring.GetUnitPosition(id)
	units[id] = world.Region(x, z)
	retired[id] = nil
end
function gadget:UnitDestroyed(id)
	local x, _, z = Spring.GetUnitPosition(id)
	units[id] = world.Region(x, z) or units[id]
	retired[id] = Spring.GetGameFrame() + 900
end
function gadget:ProjectileCreated(id, owner, weapon)
	local x, _, z = Spring.GetProjectilePosition(id)
	-- Root scripted shots must originate with their owner. Explosion/death
	-- dispatch supplies the parent region for children after an owner travels.
	local positionRegion = world.Region(x, z)
	local region = damageRegion or (owner and UnitRegion(owner)) or positionRegion
	projectiles[id] = { region = region, owner = owner, weapon = weapon }
	-- Lua gadgets may set the target immediately after SpawnProjectile returns.
	-- Validate it on the next frame, after that initialization has completed.
	if not region or positionRegion ~= region then
		Delete(id)
	end
end
function gadget:ProjectileDestroyed(id)
	local p = projectiles[id]
	-- Explosion damage can arrive after destruction (expanding shock waves).
	-- Keep launch provenance long enough for those callbacks; IDs reset on reuse.
	if p then
		p.expires = Spring.GetGameFrame() + 900
	end
end
-- The gadget dispatcher rejects foreign damage before any status/capture/impulse
-- gadget receives it. A normal UnitPreDamaged return cannot stop their side effects.
function gadget:AllowWeaponInterceptTarget(id, weapon, projectile)
	local p = projectiles[projectile]
	return p and p.region == UnitRegion(id) or false
end
function gadget:GameFrame(f)
	for id, p in pairs(projectiles) do
		if p.expires then
			if f >= p.expires then
				projectiles[id] = nil
			end
		elseif not p.deleted then
			local x, _, z = Spring.GetProjectilePosition(id)
			if not x or not z or world.Region(x, z) ~= p.region then
				Delete(id)
			else
				local vx, _, vz = Spring.GetProjectileVelocity(id)
				-- Remove before a fast projectile can cross a boundary during the
				-- next simulation step and deform or spawn effects on another map.
				if vx and vz and world.Region(x + vx, z + vz) ~= p.region then
					Delete(id)
				else
					local target = TargetRegion(id)
					if target and target ~= p.region then
						Delete(id)
					end
				end
			end
		end
	end
	if f % 30 == 0 then
		local portal = GG.PortalWorlds
		if portal then
			for id, region in pairs(portal.home) do
				units[id] = region
			end
		end
		for id, expires in pairs(retired) do
			if f >= expires then
				retired[id] = nil
				units[id] = nil
			end
		end
		Spring.SetGameRulesParam("portal_blocked_damage", blocked)
		Spring.SetGameRulesParam("portal_deleted_projectiles", deleted)
	end
end
-- Keep this callin subscribed even when no other gadget uses feature damage.
-- The dispatcher applies the isolation gate before invoking gadget callbacks.
function gadget:FeaturePreDamaged(id, def, team, damage)
	return damage, 1
end
function gadget:Shutdown()
	GG.PortalIsolation = nil
end
