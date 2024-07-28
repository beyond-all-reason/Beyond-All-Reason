function gadget:GetInfo()
	return {
		name = "Single-Hit Fire Weapons",
		desc = "Forces marked weapons to only inflict damage once per projectile per unit (and add fire related trickery)",
		author = "Anarchid, mauled by Hornet",
		date = "25.10.2023",
		license = "Public domain",
		layer = 21,
		enabled = false
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------










--single_hit is damage from a single attacker only applied to impacted units, once per 10 frames at most

--single_hit_multi is damage once per unit only per given particle
--only these are watched and can have trails




local spGetGameFrame = Spring.GetGameFrame

local wantedWeaponList = {}

local singleHitWeapon = {}
local singleHitUnitId = {}

local singleHitMultiWeapon = {}
local singleHitProjectile = {}
local fireballWeapons = {}

local flyingFireballs = {}
local groundedFireballs = {}

function gadget:Initialize()
	for wdid = 1, #WeaponDefs do
		local wd = WeaponDefs[wdid]
		if wd.customParams then
			if wd.customParams.single_hit then
				singleHitWeapon[wd.id] = true;
				wantedWeaponList[#wantedWeaponList + 1] = wdid
			end
			if wd.customParams.single_hit_multi then
				--Spring.Echo('hornet debug wantedweapon multi')
				--Spring.Echo(wd.name, wd.id, wdid)
				singleHitMultiWeapon[wd.id] = true;
				wantedWeaponList[#wantedWeaponList + 1] = wdid
				--if wd.type == 'Flame'
					--fireballWeapons[weaponDefID] = weaponDef
				--end
				-- later move fireWeapons here
				Script.SetWatchProjectile(wd.id, true)
			end
		end
	end
end





--tried to create real 3d damage, it was weird at best. might be fixable / reusable, I wish you luck.
--[[


for weaponDefID, weaponDef in ipairs(WeaponDefs) do
	if weaponDef.customParams then
		if weaponDef.customParams.single_hit_multi and weaponDef.type == 'Flame' then
			Script.SetWatchProjectile(weaponDefID, true)
			fireballWeapons[weaponDefID] = weaponDef
		end
	end
end




local function addVolumetricDamage(projectileID)
	Spring.Echo('hornet debug AVD run')
	
	local weaponDefID = Spring.GetProjectileDefID(projectileID)
	local ownerID = Spring.GetProjectileOwnerID(projectileID)
	local x,y,z = Spring.GetProjectilePosition(projectileID)
	local explosionParams ={
		weaponDef = weaponDefID,
		owner = ownerID,
		projectileID = projectileID,
		damages = fireballWeapons[weaponDefID].damages,
		hitUnit = 1,
		hitFeature = 1,
		craterAreaOfEffect = fireballWeapons[weaponDefID].craterAreaOfEffect,
		damageAreaOfEffect = fireballWeapons[weaponDefID].damageAreaOfEffect,
		edgeEffectiveness = fireballWeapons[weaponDefID].edgeEffectiveness,
		explosionSpeed = fireballWeapons[weaponDefID].explosionSpeed,
		impactOnly = fireballWeapons[weaponDefID].impactOnly,
		ignoreOwner = fireballWeapons[weaponDefID].noSelfDamage,
		damageGround = true,
	}
	Spring.SpawnExplosion(x, y ,z, 0, 0, 0, explosionParams)
end



--dgun logic for aoe effect
function gadget:GameFrame()
	for proID in pairs(flyingFireballs) do
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

			groundedFireballs[proID] = true
			flyingFireballs[proID] = nil
		end
	end

	for proID in pairs(groundedFireballs) do
		local x, y, z = Spring.GetProjectilePosition(proID)
		-- place projectile slightly under ground to ensure fiery trail
		local verticalOffset = 1
		Spring.SetProjectilePosition(proID, x, math.max(Spring.GetGroundHeight(x, z), 0) - verticalOffset, z)

		-- NB: no removal; do this every frame so that it doesn't fly off a cliff or something
	end
end
]]--






--Spring.Echo('hornet debug ProjectileCreated')
function gadget:ProjectileCreated(proID, proOwnerID, weaponID)


	--Spring.Echo('hornet debug ProjectileCreated run')
	--if fireballWeapons[weaponID] then
		--flyingFireballs[proID] = true
		--Spring.Echo('hornet debug tracking proID', proID)
	--end

	if singleHitMultiWeapon[weaponID] then
		singleHitProjectile[proID] = {}
	end
end

function gadget:ProjectileDestroyed(proID)

	--flyingFireballs[proID] = nil
	--groundedFireballs[proID] = nil


	if singleHitMultiWeapon[proID] then
		singleHitProjectile[proID] = nil
	end
end

function gadget:UnitPreDamaged_GetWantedWeaponDef()
	return wantedWeaponList
end


function gadget:UnitPreDamaged(unitID,unitDefID,_, damage,_, weaponDefID,projectileID,attackerID,_,_)
	if singleHitWeapon[weaponDefID] then
		if attackerID then
			local frame = spGetGameFrame()
			if singleHitUnitId[attackerID] == nil then
				singleHitUnitId[attackerID] = {}
				singleHitUnitId[attackerID][unitID] = frame
			else
				if singleHitUnitId[attackerID][unitID] and frame - singleHitUnitId[attackerID][unitID] < 10 then
					singleHitUnitId[attackerID][unitID] = frame
					return 0
				else
					singleHitUnitId[attackerID][unitID] = frame
				end
			end
			return damage
		end
	end
	
	if singleHitMultiWeapon[weaponDefID] then
		if not singleHitProjectile[projectileID] then
			singleHitProjectile[projectileID] = {}
		end
			--Spring.Echo('hornet debug pid uid', projectileID, unitID)
			--Spring.Echo('hornet debug singleHitProjectile[projectileID][unitID]=', singleHitProjectile[projectileID][unitID])
		
		if singleHitProjectile[projectileID][unitID] then
			--Spring.Echo('hornet debug singleHitProjectile[projectileID][unitID] set, ignoring')
			
			return 0
		else
			--Spring.Echo('hornet debug setting singleHitProjectile[projectileID][unitID]', projectileID, unitID)
			singleHitProjectile[projectileID][unitID] = true
		end
		return damage
	end
	return damage;
end
