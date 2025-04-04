local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Tree feller",
		desc = "Destroys features that have 0 m and >0 energy",
		author = "Beherith",
		date = "march 201",--ye olde code
		license   = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

	local math_sqrt = math.sqrt
	local math_random = math.random

	local treefireExplosion = {
		tiny = {
			weaponDef = WeaponDefNames['treefire_tiny'].id,
			-- owner = -1,
			hitUnit = 1,
			hitFeature = 1,
			craterAreaOfEffect = 38,
			damageAreaOfEffect = 38,
			edgeEffectiveness = 0.5,
			explosionSpeed = 1,
			impactOnly = false,
			ignoreOwner = false,
			damageGround = true,
		},
		small = {
			weaponDef = WeaponDefNames['treefire_small'].id,
			-- owner = -1,
			hitUnit = 1,
			hitFeature = 1,
			craterAreaOfEffect = 44,
			damageAreaOfEffect = 44,
			edgeEffectiveness = 0.5,
			explosionSpeed = 1,
			impactOnly = false,
			ignoreOwner = false,
			damageGround = true,
		},
		medium = {
			weaponDef = WeaponDefNames['treefire_medium'].id,
			-- owner = -1,
			hitUnit = 1,
			hitFeature = 1,
			craterAreaOfEffect = 50,
			damageAreaOfEffect = 50,
			edgeEffectiveness = 0.5,
			explosionSpeed = 1,
			impactOnly = false,
			ignoreOwner = false,
			damageGround = true,
		},
		large = {
			weaponDef = WeaponDefNames['treefire_large'].id,
			-- owner = -1,
			hitUnit = 1,
			hitFeature = 1,
			craterAreaOfEffect = 58,
			damageAreaOfEffect = 58,
			edgeEffectiveness = 0.5,
			explosionSpeed = 1,
			impactOnly = false,
			ignoreOwner = false,
			damageGround = true,
		},
	}
	local treeWeapons = {}
	treeWeapons[WeaponDefNames['treefire_tiny'].id] = true
	treeWeapons[WeaponDefNames['treefire_small'].id] = true
	treeWeapons[WeaponDefNames['treefire_medium'].id] = true
	treeWeapons[WeaponDefNames['treefire_large'].id] = true

	local noFireWeapons = {}
	for id, wDefs in pairs(WeaponDefs) do
		if wDefs.customParams and wDefs.customParams.nofire then
			noFireWeapons[id] = true
		end
	end

	local GetFeaturePosition = Spring.GetFeaturePosition
	local GetFeatureHealth = Spring.GetFeatureHealth
	local GetFeatureDirection = Spring.GetFeatureDirection
	local GetFeatureResources = Spring.GetFeatureResources
	local SetFeatureDirection = Spring.SetFeatureDirection
	local SetFeatureBlocking = Spring.SetFeatureBlocking
	local SetFeaturePosition = Spring.SetFeaturePosition
	local CreateFeature = Spring.CreateFeature
	local DestroyFeature = Spring.DestroyFeature
	local GetGameFrame = Spring.GetGameFrame

	local treesdying = {}
	local falltime = 55.0 -- in frames
	local fallspeed = 25.0

	local treeMass = {}
	local treeScaleY = {}
	local treeName = {}
	local geothermals = {}
	for featureDefID, featureDef in pairs(FeatureDefs) do

		if featureDef.geoThermal then
			geothermals[featureDefID] = featureDefID
		end

		if featureDef.name:find('treetype') == nil then
			treeName[featureDefID] = featureDef.name
			treeMass[featureDefID] = math.max(1, featureDef.mass)
			if featureDef.collisionVolume then
				treeScaleY[featureDefID] = featureDef.collisionVolume.scaleY
			end
		end
	end

	local unitMass = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		unitMass[unitDefID] = unitDef.mass
	end



	local function ComSpawnDefoliate(spawnx,spawny,spawnz)
		

		local blasted_trees = Spring.GetFeaturesInCylinder ( spawnx, spawnz, 125)

		for i, tree in pairs(blasted_trees) do

			local featureDefID = Spring.GetFeatureDefID(tree)

			if geothermals[featureDefID] then
				return 0
			end


			local fx, fy, fz = GetFeaturePosition(tree)
			local dx, dy, dz = GetFeatureDirection(tree)
			if true and fx ~= nil then

					local dissapearSpeed = 1.7
					local size = 'medium'
					if treeScaleY[featureDefID] then
						if treeScaleY[featureDefID] < 40 then
							size = 'tiny'
						elseif treeScaleY[featureDefID] < 50 then
							size = 'small'
						elseif treeScaleY[featureDefID] > 65 then
							size = 'large'
						end
						dissapearSpeed = 0.15 + Spring.GetFeatureHeight(tree) / math_random(3700, 4700)
					end
		
					local destroyFrame = GetGameFrame() + falltime + 150 + (dissapearSpeed * 4000)

				local dmg = treeMass[featureDefID] * 2
				Spring.SetFeatureResources(0,0,0,0)
				Spring.SetFeatureNoSelect(tree, true)
				Spring.PlaySoundFile("treefall", 2, fx, fy, fz, 'sfx')
				treesdying[tree] = {
					frame = GetGameFrame(),
					posx = fx, posy = fy, posz = fz,
					fDefID = featureDefID,
					dirx = dx, diry = dy, dirz = dz,
					px = spawnx, py = spawny, pz = spawnz,
					strength = math.max(1, treeMass[featureDefID] / dmg),
					fire = false,
					size = size,
					dissapearSpeed = dissapearSpeed,
					destroyFrame = destroyFrame
				}
				--Spring.Debug.TableEcho(treesdying[tree])
		end
	end

	end

	

	GG.ComSpawnDefoliate = ComSpawnDefoliate
	

	function gadget:Initialize()
		return
	end



	function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam, Damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if not treeMass[featureDefID] then
			return Damage, 0
		end
		local dmg = Damage
		local fx, fy, fz = GetFeaturePosition(featureID)

		-- dying trees dont take more damage, and will be removed later
		if treesdying[featureID] then
			if weaponDefID >= 0 and not (noFireWeapons[weaponDefID]) then
				-- UNITEXPLOSION
				if fy and fy >= 0 then
					treesdying[featureID].fire = true
				end
			end
			return 0, 0
		end

		local ppx, ppy, ppz
		if fx ~= nil then

			local health, maxhealth, _ = GetFeatureHealth(featureID)
			if dmg >= health then
				local fire
				local remainingMetal, maxMetal, remainingEnergy, maxEnergy, reclaimLeft = GetFeatureResources(featureID)
				local dissapearSpeed = 1.7
				local size = 'medium'
				if treeScaleY[featureDefID] then
					if treeScaleY[featureDefID] < 40 then
						size = 'tiny'
					elseif treeScaleY[featureDefID] < 50 then
						size = 'small'
					elseif treeScaleY[featureDefID] > 65 then
						size = 'large'
					end
					dissapearSpeed = 0.15 + Spring.GetFeatureHeight(featureID) / math_random(3700, 4700)
				end
				--local destroyFrame = GetGameFrame() + (falltime * (treeMass[featureDefID] / dmg)) + 150 + (dissapearSpeed*4000)
				local destroyFrame = GetGameFrame() + falltime + 150 + (dissapearSpeed * 4000)
				--Spring.Echo("Destroyed feature at", Spring.GetGameFrame(), "destroyframe = " ,destroyFrame, "Seconds:", (destroyFrame - Spring.GetGameFrame())/30)
				--Spring.Echo("falltime = ",falltime, "treeMass=", treeMass[featureDefID], " dmg =", dmg, "dissapearSpeed", dissapearSpeed)

				-- DYING TREE
				if health ~= nil and maxMetal == 0 and maxEnergy > 0 and (health <= dmg or weaponDefID == -7) then
					-- weaponDefID == -7 is the weapon that crushes features
					--if crushed, attackerID returns unit, but projectileID is nil, if projectile destroys feature, then attackerID is nil, but projectileID contains the projectile.
					--Echo('tree dying...',featureID)
					local dx, dy, dz = GetFeatureDirection(featureID)
					SetFeatureBlocking(featureID, false, false, false, false, false, false, false) --doesnt block anything
					if weaponDefID == -7 then
						--weapon is crush
						--crushed features cannot be saved by returning 0 damage. Must create new one!
						DestroyFeature(featureID)
						treesdying[featureID] = { frame = GetGameFrame(), posx = fx, posy = fy, posz = fz, fDefID = featureDefID, dirx = dx, diry = dy, dirz = dz, px = ppx, py = ppy, pz = ppz, strength = treeMass[featureDefID] / dmg, fire = fire, size = size, dissapearSpeed = dissapearSpeed, destroyFrame = destroyFrame } -- this prevents this tobedestroyed feature to be replaced multiple times
						featureID = CreateFeature(featureDefID, fx, fy, fz)
						SetFeatureDirection(featureID, dx, dy, dz)
						SetFeatureBlocking(featureID, false, false, false, false, false, false, false)
						--Echo('tree created... ',featureID)
					else
						Damage = 0 -- so it doesnt take multiple frames for tree to get killed.
					end
					-- TREE CAUGHT FIRE FROM OTHER TREE
					if treeWeapons[weaponDefID] then
						ppx, ppy, ppz = GetFeaturePosition(featureID)
						ppx, ppy, ppz = ppx + math_random(-10, 10), ppy + math_random(-10, 10), ppz + math_random(-10, 10) -- we don't have an attacker pos/projpos
						dmg = 2
						if fy >= 0 then
							fire = true
						end

					-- PROJECTILE EXPLOSION
					elseif projectileID > 0 and weaponDefID and not (noFireWeapons[weaponDefID]) then
						ppx, ppy, ppz = Spring.GetProjectilePosition(projectileID)
						local vpx, vpy, vpz = Spring.GetProjectileVelocity(projectileID)
						ppx = ppx - 2 * vpx
						ppy = ppy - 2 * vpy
						ppz = ppz - 2 * vpz
						dmg = math.min(treeMass[featureDefID] * 2, dmg)
						if fy >= 0 then
							fire = true
						end

					-- CRUSH
					elseif attackerID and weaponDefID < 0 then
						ppx, ppy, ppz = Spring.GetUnitPosition(attackerID)
						local vpx, vpy, vpz = Spring.GetUnitVelocity(attackerID)
						ppx = ppx - 2 * vpx
						ppy = ppy - 2 * vpy
						ppz = ppz - 2 * vpz
						dmg = math.min(treeMass[featureDefID] * 2, unitMass[attackerDefID])
						fire = false

					-- UNITEXPLOSION
					elseif attackerID and weaponDefID and not (noFireWeapons[weaponDefID]) then
						ppx, ppy, ppz = Spring.GetUnitPosition(attackerID)
						dmg = math.min(treeMass[featureDefID] * 2, dmg)
						if fy >= 0 then
							fire = true
						end
					end
					Spring.SetFeatureResources(0,0,0,0)
					Spring.SetFeatureNoSelect(featureID, true)
					Spring.PlaySoundFile("treefall", 2, fx, fy, fz, 'sfx')
					treesdying[featureID] = {
						frame = GetGameFrame(),
						posx = fx, posy = fy, posz = fz,
						fDefID = featureDefID,
						dirx = dx, diry = dy, dirz = dz,
						px = ppx, py = ppy, pz = ppz,
						strength = math.max(1, treeMass[featureDefID] / dmg),
						fire = fire,
						size = size,
						dissapearSpeed = dissapearSpeed,
						destroyFrame = destroyFrame
					}
					--Spring.Echo('Hornet poi treesdying')
					--Spring.Debug.TableEcho(treesdying[featureID])
				end
			end
		end
		return Damage, 0
	end

	function gadget:GameFrame(gf)
		for featureID, featureinfo in pairs(treesdying) do
			if not GetFeaturePosition(featureID) then
				treesdying[featureID] = nil
				DestroyFeature(featureID)
			else
				Spring.SetFeatureResources(0,0,0,0)
				local thisfeaturefalltime = falltime * featureinfo.strength
				local thisfeaturefallspeed = fallspeed * featureinfo.strength
				local fireFrequency = 5
				if featureinfo.fire then
					fireFrequency = math.floor(2 + ((gf - featureinfo.frame) / 70))
				end

				-- FALLING
				if featureinfo.frame + thisfeaturefalltime > gf then
					--Spring.Echo('hornet poi: falling')
					local factor = math.max(1, ((gf - featureinfo.frame) / thisfeaturefallspeed))
					local fx, fy, fz = GetFeaturePosition(featureID)
					local px, py, pz = featureinfo.px, featureinfo.py, featureinfo.pz
					if fy ~= nil then
						if featureinfo.fire then
							if gf % fireFrequency == math.floor(fireFrequency / 1.5) then
								local firex, firey, firez = fx + math_random(-3, 3), fy + math_random(-3, 3), fz + math_random(-3, 3)
								local pos = math_random(12, 17)
								firex = firex - (featureinfo.dirx * pos)
								firez = firez - (featureinfo.dirz * pos)
								Spring.SpawnCEG('treeburn-' .. treesdying[featureID].size, firex, firey, firez, 0, 0, 0, 0, 0, 0)
							end
							if gf % fireFrequency == math.floor(fireFrequency / 3) and math_random(1, 5) == 1 then
								local firex, firey, firez = fx + math_random(-3, 3), fy + math_random(-3, 3), fz + math_random(-3, 3)
								local pos = math_random(12, 17)
								firex = firex - (featureinfo.dirx * pos)
								firez = firez - (featureinfo.dirz * pos)
								Spring.SpawnExplosion(firex, firey, firez, 0, 0, 0, treefireExplosion[featureinfo.size])
							end
						end
						if px and py and pz then
							local difx = px - fx
							local difz = pz - fz
							local dirx = (((difx * difx + difz * difz)) ~= 0) and math_sqrt((difx * difx / (difx * difx + difz * difz))) or 0
							local dirz = (((difx * difx + difz * difz)) ~= 0) and math_sqrt((difz * difz / (difx * difx + difz * difz))) or 0
							if difx < 0 then
								dirx = -dirx
							end
							if difz < 0 then
								dirz = -dirz
							end
							featureinfo.dirx = dirx
							featureinfo.diry = py - fy
							featureinfo.dirz = dirz
						end
						SetFeatureDirection(featureID, featureinfo.dirx, factor * factor, featureinfo.dirz)
					end

				-- FALLEN
				elseif featureinfo.frame + thisfeaturefalltime <= gf then
					--Spring.Echo('hornet poi: fallen')
					local fx, fy, fz = GetFeaturePosition(featureID)
					if fy ~= nil then
						if featureinfo.fire then
							if gf % fireFrequency == math.floor(fireFrequency / 1.5) then
								local firex, firey, firez = fx + math_random(-3, 3), fy + math_random(-3, 3), fz + math_random(-3, 3)
								local pos = math_random(12, 17)
								firex = firex - (featureinfo.dirx * pos)
								firez = firez - (featureinfo.dirz * pos)
								Spring.SpawnCEG('treeburn-' .. treesdying[featureID].size, firex, firey, firez, 0, 0, 0, 0, 0, 0)
							end
							if gf % fireFrequency == math.floor(fireFrequency / 3) and math_random(1, 6) == 1 then
								local firex, firey, firez = fx + math_random(-3, 3), fy + math_random(-3, 3), fz + math_random(-3, 3)
								local pos = math_random(12, 17)
								firex = firex - (featureinfo.dirx * pos)
								firez = firez - (featureinfo.dirz * pos)
								Spring.SpawnExplosion(firex, firey, firez, 0, 0, 0, treefireExplosion[featureinfo.size])
							end
						end

            local gh = Spring.GetGroundHeight(fx,fz)
            if featureinfo.destroyFrame <= gf or (gh > fy + 48) then
							treesdying[featureID] = nil
							DestroyFeature(featureID)
						elseif featureinfo.frame + thisfeaturefalltime + 250 <= gf and treesdying[featureID].fire then
							treesdying[featureID].fire = false
						elseif featureinfo.frame + thisfeaturefalltime + 100 <= gf then
							local dx, dy, dz = GetFeatureDirection(featureID)
							if treesdying[featureID].fire then
								SetFeaturePosition(featureID, fx, fy - treesdying[featureID].dissapearSpeed, fz, false)
							else
								SetFeaturePosition(featureID, fx, fy - treesdying[featureID].dissapearSpeed * 3, fz, false)
							end

							-- NOTE: this can create twitchy tree movement
              -- Note 2: disabling this because I saw no reset issue, but this does fix gimbal induced twitch.
			  -- note 3 (Hornet): enabling this because 'some trees' absolutely do need it. Eg, Tangerine is fine, but Isthmus trees are not. Might be map feature setting issue in some way?
							SetFeatureDirection(featureID, dx, dy, dz)		-- gets reset so we re-apply
						end
					end
				end
			end
		end
	end
end
