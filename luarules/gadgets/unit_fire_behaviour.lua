function gadget:GetInfo()
	return {
		name = "Fire Behaviour",
		desc = "Fire does volumetric damage, rate limited",
		author = "Itanthias (used Anarchid + Sprung Dgun code)",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local fireWeapons = {}

for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	--Spring.Echo(weaponDef.name)
	if weaponDef.customParams.fire_volume == "true" then
		Spring.Echo(weaponDef.name)
		Script.SetWatchProjectile(weaponDefID, true)
		fireWeapons[weaponDefID] = weaponDef
	end
end

local flyingFire = {}
local recently_damaged = {}

local function addVolumetricDamage(projectileID)
	local weaponDefID = Spring.GetProjectileDefID(projectileID)
	local ownerID = Spring.GetProjectileOwnerID(projectileID)
	local x,y,z = Spring.GetProjectilePosition(projectileID)

	local explosionParame ={
		weaponDef = weaponDefID,
		owner = ownerID,
		projectileID = projectileID,
		damages = fireWeapons[weaponDefID].damages,
		hitUnit = 1,
		hitFeature = 1,
		craterAreaOfEffect = fireWeapons[weaponDefID].craterAreaOfEffect,
		damageAreaOfEffect = fireWeapons[weaponDefID].damageAreaOfEffect,
		edgeEffectiveness = fireWeapons[weaponDefID].edgeEffectiveness,
		explosionSpeed = fireWeapons[weaponDefID].explosionSpeed,
		impactOnly = fireWeapons[weaponDefID].impactOnly,
		ignoreOwner = fireWeapons[weaponDefID].noSelfDamage,
		damageGround = true,
	}

	Spring.SpawnExplosion(x, y ,z, 0, 0, 0, explosionParame)
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if fireWeapons[weaponDefID] then
		flyingFire[proID] = true
		--Spring.Echo("hello world",fireWeapons[weaponDefID].reload)
		--for key,value in pairs(fireWeapons[weaponDefID].damages) do --actualcode
		--	Spring.Echo("hello world",key,value)
		--end
		--for V1, V2 in ipairs(fireWeapons[weaponDefID]) do
		--Spring.Echo("hello world",V1,V2)
		--end
	end
end

function gadget:ProjectileDestroyed(proID)
	flyingFire[proID] = nil
end

function gadget:GameFrame()
	for proID in pairs(flyingFire) do
		-- Fireball is hitscan while in flight, engine only applies AoE damage after hitting the ground,
		-- so we need to add the AoE damage manually for flying projectiles
		addVolumetricDamage(proID)
	end
end

function UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	recently_damaged[unitID] = nil
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if fireWeapons[weaponDefID] then
		if recently_damaged[unitID] == nil then
			recently_damaged[unitID] = {}
		end
		if recently_damaged[unitID][attackerID] == nil then
			recently_damaged[unitID][attackerID] = 0
		end
		local game_seconds = Spring.GetGameSeconds()
		if recently_damaged[unitID][attackerID] < game_seconds then
			recently_damaged[unitID][attackerID] = game_seconds + 0.5*fireWeapons[weaponDefID].reload
			return damage
		end
		return 0
	end

	return damage
end
