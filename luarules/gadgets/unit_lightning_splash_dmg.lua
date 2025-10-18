local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = 'Lightning Splash Damage',
		desc      = 'Handles Lightning Weapons Splash Damage',
		author    = 'TheFatController, Itanthias',
		version   = 'v2.1',
		date      = 'April 2011 (V1.0), Jan 2023 (V2.1)',
		license   = 'GNU GPL, v2 or later',
		layer     = 0,
		enabled   = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- Options here
local terminal_spark_effect = "genericshellexplosion-splash-lightning" -- can refactor into sparkWeapons if per-unit effects defined by customParams are desired
local visual_chain_weapon = WeaponDefNames["lightning_chain"].id -- can refactor into sparkWeapons if per-unit effects defined by customParams are desired

local spGetUnitsInSphere = Spring.GetUnitsInSphere
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spSpawnCEG = Spring.SpawnCEG
local spAddUnitDamage = Spring.AddUnitDamage
local spSpawnProjectile = Spring.SpawnProjectile
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetGroundHeight = Spring.GetGroundHeight
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity

local math_random = math.random
local math_pi = math.pi
local math_max = math.max
local math_cos = math.cos
local math_sin = math.sin

-- A fun unit test is: /luarules fightertest armclaw armclaw 200 10 1000

-- Below is a concise implementation of a pool of reusable tables, that grows on demand, but doesnt ever shrink.
local projTablePoolSize = 0
local projTablePool = {}
local function GetProjTable()
	if projTablePoolSize == 0 then
		return {
				weaponDefID = 0,
				proOwnerID = 0,
				spark_ceg = 0,
				spark_basedamage = 0,
				spark_forkdamage = 0,
				spark_range = 0,
				spark_maxunits = 0,
				x = 0,
				y = 0,
				z = 0,
			}
	else
		local free = projTablePool[projTablePoolSize]
		projTablePool[projTablePoolSize] = nil
		projTablePoolSize = projTablePoolSize -1
		return free
	end
end

local function FreeProjTable(projTable)
	projTablePoolSize = projTablePoolSize + 1
	projTablePool[projTablePoolSize] = projTable
end

-- dictionary for in-game spark weapons
local sparkWeapons = {}
for wdid, wd in pairs(WeaponDefNames) do
	if wd.customParams ~= nil then
		if wd.customParams.spark_forkdamage ~= nil then
			Script.SetWatchProjectile(wd.id, true) -- watch so ProjectileCreated works
			sparkWeapons[wd.id] = 	{
				ceg = wd.customParams.spark_ceg, -- currently overridden by above "global" options
				basedamage = tonumber(wd.damages[0]), --spark damage is assumed to be based on default damage
				forkdamage = tonumber(wd.customParams.spark_forkdamage),
				maxunits = tonumber(wd.customParams.spark_maxunits),
				range = tonumber(wd.customParams.spark_range)
			}
		end
	end
end

-- look at this later, currently this makes these units completely immune to spark damage, friend or foe
local immuneToSplash = {}
local unitRadius = {}
for udid, ud in pairs(UnitDefs) do
	unitRadius[udid] = ud.radius
	for i, v in pairs(ud.weapons) do
		if WeaponDefs[ud.weapons[i].weaponDef] and WeaponDefs[ud.weapons[i].weaponDef].type == "LightningCannon" then
			immuneToSplash[udid] = true
			break
		end
	end
end

local lightningProjectiles = {} -- stores information related to every lighting bolt created in-game
local lightning_shooter = {} -- stores information related to units directly hit by lighting bolts
local lightning_shooter_ttl = {} -- stores information related to how long ago a unit was directly hit by lighting bolts

function gadget:GameFrame(frame)
	-- keep track of unit "primary target" to avoid self-chaining
	for attackerID, value in pairs(lightning_shooter_ttl) do
		-- if lightning_shooter[attackerID] was shot by attackerID, they are immune to sparks from attackerID for 3 frames
		lightning_shooter_ttl[attackerID] = lightning_shooter_ttl[attackerID] - 1 -- decrement counter
		if lightning_shooter_ttl[attackerID] == 0 then
			-- if counter reaches zero, set nil values
			lightning_shooter_ttl[attackerID] = nil
			lightning_shooter[attackerID] = nil
		end
	end
end

-- this is a table that can be reused for each spawnprojectile
local projectileCacheTable = {pos = {0,0,0}, ["end"] = {0,0,0}, ttl = 2, owner = -1}

-- this part handles the actual spark and chaining effect and applies damage
-- for a typical lighting bolt ttl = 1, main bolt strikes frame 1, spark bolts strike frame 2
function gadget:ProjectileDestroyed(proID)
	if lightningProjectiles[proID] then
		local lightning = lightningProjectiles[proID] -- localizing
		local count = lightning.spark_maxunits
		local nearUnits = spGetUnitsInSphere(lightning.x,lightning.y,lightning.z,lightning.spark_range) -- get list of units in spark range
		local nearUnit, nearUnitDefID
		for i=1, #nearUnits do
			if count == 0 then -- exit if maximum chain is reached
				FreeProjTable(lightningProjectiles[proID])
				lightningProjectiles[proID] = nil
				return
			end

			nearUnit = nearUnits[i] -- get nearest unit
			nearUnitDefID = spGetUnitDefID(nearUnit) -- get its unitdefID
			if not immuneToSplash[nearUnitDefID] then -- check if unit is immune to sparking
				if not spGetUnitIsDead(nearUnit) then -- check if unit is in "death animation", so sparks do not chain to dying units.
					if lightning_shooter[lightning.proOwnerID] ~= nearUnit then --check if main bolt has hit this target or not
						local bx,by,bz,mx,my,mz, ex, ey, ez = spGetUnitPosition(nearUnit,true,true) -- gets aimpoint of unit
						if my+unitRadius[nearUnitDefID] > -10 then -- check if unit is above water (not underwater)
							spSpawnCEG(terminal_spark_effect,ex,ey,ez,0,0,0) -- spawns "electric aura" at spark target
							local spark_damage = lightning.spark_basedamage*lightning.spark_forkdamage -- figure out damage to apply to spark target
							-- NB: weaponDefID -1 is debris damage which gets removed by engine_hotfixes.lua, use -7 (crush damage) arbitrarily instead
							spAddUnitDamage(nearUnit, spark_damage, 0, lightning.proOwnerID, -7) -- apply damage to spark target
							-- create visual lighting arc from main bolt termination point to spark target
							-- set owner = -1 as a "spark bolt" identifier
							-- lightning.weaponDefID
							projectileCacheTable.pos[1] = lightning.x
							projectileCacheTable.pos[2] = lightning.y
							projectileCacheTable.pos[3] = lightning.z
							projectileCacheTable['end'][1] = ex
							projectileCacheTable['end'][2] = ey
							projectileCacheTable['end'][3] = ez

							--spSpawnProjectile(lightning.weaponDefID, projectileCacheTable)
							spSpawnProjectile(lightning.weaponDefID, {["pos"]={lightning.x,lightning.y,lightning.z},["end"] = {ex,ey,ez}, ["ttl"] = 2, ["owner"] = -1})
							count = count - 1 -- spark target count accounting
						end
					end
				end
			end
		end

		-- special effects, for leftover chain
		local angle, pitch, newx, newz, height1, height2
		for i=1, count, 3 do
			angle = math_random()*2*math_pi -- random angle, in radians
			pitch = math_random()*math_pi/2 -- random pitch, in radians
			-- convert to x,z and offset from main bolt termination point
			newx = lightning.x + math_cos(pitch)*math_sin(angle)*lightning.spark_range
			newz = lightning.z + math_cos(pitch)*math_cos(angle)*lightning.spark_range
			-- get height of random spark bolt termination point
			-- This may need to be tuned, steep slopes, cliffs, and uneven terrain may create weird visuals
			height1 = math_max(spGetGroundHeight(lightning.x,lightning.z),lightning.y) -- no vertical offset from ground seems needed for ground-strike bolts
			height2 = spGetGroundHeight(newx,newz)+5+(math_sin(pitch)*lightning.spark_range/2)
			-- offset by 5 units seems good for termination point of spark
			-- also pitch height is added, and squashed by a factor of 2 for an "ellipsoid" strike surface

			-- create effects
			-- using special defined thinner bolt for left-over chain bolts
			projectileCacheTable.pos[1] = lightning.x
			projectileCacheTable.pos[2] = height1
			projectileCacheTable.pos[3] = lightning.z
			projectileCacheTable['end'][1] = newx -- note, the keyword 'end' is reserved
			projectileCacheTable['end'][2] = height2
			projectileCacheTable['end'][3] = newz
			--spSpawnProjectile(visual_chain_weapon, projectileCacheTable)
			spSpawnProjectile(visual_chain_weapon, {["pos"]={lightning.x,height1,lightning.z},["end"] = {newx,height2,newz}, ["ttl"] = 2, ["owner"] = -1})
			spSpawnCEG(terminal_spark_effect,newx,height2,newz,0,0,0)
		end

		-- clear from table
		FreeProjTable(lightningProjectiles[proID])
		lightningProjectiles[proID] = nil
	end
end

-- when a lighting bolt is created by a unit, save some info to a table, to be used to figure out sparking when the bolt despawns
function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
	if sparkWeapons[weaponDefID] then -- make sure we are handling lightning weapons
		if proOwnerID ~= -1 then -- make sure we are handling a main bolt, and not a spark bolt

			local xp,yp,zp = spGetProjectilePosition(proID) -- get bolt start point
			local xv,yv,zv = spGetProjectileVelocity(proID) -- get bolt length

			-- fill table, to be used in ProjectileDestroyed

			local projTable = GetProjTable()
			projTable.weaponDefID = weaponDefID
			projTable.proOwnerID = proOwnerID
			projTable.spark_ceg = sparkWeapons[weaponDefID].ceg
			projTable.spark_basedamage = sparkWeapons[weaponDefID].basedamage
			projTable.spark_forkdamage = sparkWeapons[weaponDefID].forkdamage
			projTable.spark_range = sparkWeapons[weaponDefID].range
			projTable.spark_maxunits = sparkWeapons[weaponDefID].maxunits
			projTable.x = xp+xv
			projTable.y = yp+yv
			projTable.z = zp+zv

			--[[lightningProjectiles[proID] = {
				weaponDefID = weaponDefID,
				proOwnerID = proOwnerID,
				spark_ceg = sparkWeapons[weaponDefID].ceg,
				spark_basedamage = sparkWeapons[weaponDefID].basedamage,
				spark_forkdamage = sparkWeapons[weaponDefID].forkdamage,
				spark_range = sparkWeapons[weaponDefID].range,
				spark_maxunits = sparkWeapons[weaponDefID].maxunits,
				-- main bolt termination point
				x = xp+xv,
				y = yp+yv,
				z = zp+zv,
			}]]--
			lightningProjectiles[proID] = projTable
		end
	end
end

-- when a unit is directly hit by a lighting attack, keep track of that so the lighting weapon does not chain to the same target it hit.
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
	-- using UnitPreDamaged to try to catch a unit being hit by a lightning bolt as soon as possible. UnitDamaged should also work, if necessary
	if attackerID and sparkWeapons[weaponID] then

		-- engine does not provide a projectileID for hitscan weapons, bleh
		-- as a workaround, if a unit is shot by a lightning unit, make it immune to that unit's chaining for 3 frames
		lightning_shooter[attackerID] = unitID
		lightning_shooter_ttl[attackerID] = 3
	end
	return damage,1
end
