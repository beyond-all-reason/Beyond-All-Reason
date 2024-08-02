function gadget:GetInfo()
	return {
		name = "D-Gun Behaviour",
		desc = "D-Gun projectiles hug ground, volumetric damage, deterministic damage against Commanders",
		author = "Anarchid, Sprung",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetUnitShieldState = Spring.GetUnitShieldState
local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitShieldState = Spring.SetUnitShieldState
local diag = math.diag


local dgunWeaponsTTL = {}
local dgunWeapons = {}
local dgunTimeouts = {}
for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.type == 'DGun' then
		Spring.Echo(weaponDef)
		Script.SetWatchProjectile(weaponDefID, true)
		dgunWeapons[weaponDefID] = weaponDef
		--Spring.Echo("TTL added", weaponDef.name, weaponDef.range,weaponDef.projectilespeed)
		dgunWeaponsTTL[weaponDefID] = weaponDef.range/weaponDef.projectilespeed
	end
end

local isCommander = {}
local isDecoyCommander = {}
local commanderNames = {}
local frameCounter = 0
for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams.iscommander or unitDef.customParams.isscavcommander then
		isCommander[unitDefID] = true
		commanderNames[unitDef.name] = true
	end
end
for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.customParams.decoyfor and commanderNames[unitDef.customParams.decoyfor] then
		isDecoyCommander[unitDefID] = true
	end
end
commanderNames = nil

local flyingDGuns = {}
local groundedDGuns = {}

local function addVolumetricDamage(projectileID)
	local weaponDefID = Spring.GetProjectileDefID(projectileID)
	local ownerID = Spring.GetProjectileOwnerID(projectileID)
	local x,y,z = Spring.GetProjectilePosition(projectileID)
	local explosionParame ={
		weaponDef = weaponDefID,
		owner = ownerID,
		projectileID = projectileID,
		damages = dgunWeapons[weaponDefID].damages,
		hitUnit = 1,
		hitFeature = 1,
		craterAreaOfEffect = dgunWeapons[weaponDefID].craterAreaOfEffect,
		damageAreaOfEffect = dgunWeapons[weaponDefID].damageAreaOfEffect,
		edgeEffectiveness = dgunWeapons[weaponDefID].edgeEffectiveness,
		explosionSpeed = dgunWeapons[weaponDefID].explosionSpeed,
		impactOnly = dgunWeapons[weaponDefID].impactOnly,
		ignoreOwner = dgunWeapons[weaponDefID].noSelfDamage,
		damageGround = true,
	}
	Spring.SpawnExplosion(x, y ,z, 0, 0, 0, explosionParame)
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if dgunWeapons[weaponDefID] then
		flyingDGuns[proID] = true
		dgunTimeouts[proID] = (frameCounter+dgunWeaponsTTL[weaponDefID])--*Game.gameSpeed
		--Spring.Echo("projectile created", dgunTimeouts[proID], dgunWeaponsTTL[weaponDefID])
	end
end

function gadget:ProjectileDestroyed(proID)
	flyingDGuns[proID] = nil
	groundedDGuns[proID] = nil
	dgunTimeouts[proID] = nil
end

function gadget:GameFrame(frame)
	for proID in pairs(flyingDGuns) do
		-- Fireball is hitscan while in flight, engine only applies AoE damage after hitting the ground,
		-- so we need to add the AoE damage manually for flying projectiles
		addVolumetricDamage(proID)

		local x, y, z = Spring.GetProjectilePosition(proID)
		local h = Spring.GetGroundHeight(x, z)

		if y < h + 1 or y < 0 then -- assume ground or water collision
			-- normalize horizontal velocity
			local dx, _, dz, speed = Spring.GetProjectileVelocity(proID)
			local norm = speed / math.sqrt(dx^2 + dz^2)
			local ndx = dx * norm
			local ndz = dz * norm
			Spring.SetProjectileVelocity(proID, ndx, 0, ndz)

			groundedDGuns[proID] = true
			flyingDGuns[proID] = nil
		end
	end

	for proID in pairs(groundedDGuns) do
		local x, y, z = Spring.GetProjectilePosition(proID)
		-- place projectile slightly under ground to ensure fiery trail
		local verticalOffset = 1
		Spring.SetProjectilePosition(proID, x, math.max(Spring.GetGroundHeight(x, z), 0) - verticalOffset, z)

		-- NB: no removal; do this every frame so that it doesn't fly off a cliff or something
	end

	if next(dgunTimeouts) == nil then
		frameCounter = 0
    else
        frameCounter = frameCounter + 1
        for proID, timeout in pairs(dgunTimeouts) do
            if frameCounter > timeout then
                Spring.DeleteProjectile(proID)
                flyingDGuns[proID] = nil
                groundedDGuns[proID] = nil
                dgunTimeouts[proID] = nil
                --Spring.Echo("ProID")
            end
        end
    end

	if frame%15 == 0 then
		--Spring.Echo(frameCounter)
	end
end


local lastShieldFrameCheck = {}
function gadget:ShieldPreDamaged(proID, proOwnerID, shieldEmitterWeaponNum, shieldCarrierUnitID, bounceProjectile, beamEmitterWeaponNum, beamEmitterUnitID, startX, startY, startZ, hitX, hitY, hitZ)
    if proID and dgunTimeouts[proID] then
        --Spring.Echo("Start", startX, startY, startZ, "Hit", hitX, hitY, hitZ)
		local proDefID = Spring.GetProjectileDefID(proID)
		local shieldEnabledState, shieldPower = Spring.GetUnitShieldState(shieldCarrierUnitID)
		Spring.Echo("shield enabled", shieldEnabledState, "shield Power", shieldPower)
		local damage = WeaponDefs[proDefID].damages[11] or WeaponDefs[proDefID].damages[2]
		
		lastShieldFrameCheck[shieldCarrierUnitID] = lastShieldFrameCheck[shieldCarrierUnitID] or frameCounter -- deal the damage
		if lastShieldFrameCheck[shieldCarrierUnitID] == frameCounter then
		shieldPower = math.max(shieldPower - damage, 0)
		Spring.SetUnitShieldState(shieldCarrierUnitID, shieldEmitterWeaponNum, shieldEnabledState, shieldPower)
		Spring.Echo("damage", damage, "new shield power", shieldPower)
		else
			lastShieldFrameCheck[shieldCarrierUnitID] = frameCounter
		end

		if shieldPower > damage then
			-- Calculate the direction vector
			local dirX = hitX - startX
			local dirZ = hitZ - startZ

			-- Normalize the direction vector
			local length = math.sqrt(dirX * dirX + dirZ * dirZ)
			dirX = dirX / length
			--dirY = dirY / length
			dirZ = dirZ / length

			-- Move the projectile back
			local newX = hitX - (WeaponDefs[proDefID].projectilespeed*6) * dirX
			--local newY = hitY - 10 * dirY
			local newZ = hitZ - (WeaponDefs[proDefID].projectilespeed*6) * dirZ

			local verticalOffset = 1
			Spring.SetProjectilePosition(proID, newX, math.max(Spring.GetGroundHeight(newX, newZ), 0) - verticalOffset, newZ)
		end

		return false
	end
end
