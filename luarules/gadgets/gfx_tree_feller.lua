local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Tree feller",
		desc = "Destroys features that have 0 m and >0 energy",
		author = "Beherith",
		date = "march 201",--ye olde code
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

	local math_sqrt = math.sqrt
	local math_random = math.random
	local math_max = math.max
	local math_min = math.min
	local math_floor = math.floor
	local math_abs = math.abs
	local math_huge = math.huge

	local spSendToUnsynced = SendToUnsynced

	local TREEFELLER_DEBUG = false
	local function dbg(...)
		if TREEFELLER_DEBUG then
			Spring.Echo("[treefeller]", ...)
		end
	end

	local spSpawnCEG = Spring.SpawnCEG
	local spSpawnExplosion = Spring.SpawnExplosion
	local spSetFeatureResources = Spring.SetFeatureResources
	local spGetGroundHeight = Spring.GetGroundHeight

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
	-- Visual topple duration (frames). Kept independent of `strength` so that
	-- fire-killed trees (which take tiny damage and thus have a huge strength /
	-- falltime) still visibly fall over in a consistent ~1.3s instead of creeping
	-- over many seconds.
	local fallVisualFrames = 40.0

	local treeMass = {}
	local treeScaleY = {}
	local treeRadius = {}
	local treeName = {}
	local geothermals = {}
	for featureDefID, featureDef in pairs(FeatureDefs) do

		if featureDef.geoThermal then
			geothermals[featureDefID] = featureDefID
		end

		--if featureDef.name:find('treetype') == nil then
			treeName[featureDefID] = featureDef.name
				treeMass[featureDefID] = math_max(1, featureDef.mass)
			if featureDef.collisionVolume then
				treeScaleY[featureDefID] = featureDef.collisionVolume.scaleY
				local sx = featureDef.collisionVolume.scaleX or 0
				local sz = featureDef.collisionVolume.scaleZ or 0
				treeRadius[featureDefID] = math_max(6, math_max(sx, sz) * 0.5)
			end
		--end
	end

	local unitMass = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		unitMass[unitDefID] = unitDef.mass
	end

	-- Derive a fire profile (height, canopy radius, canopy height fraction) from
	-- the tree's actual model mesh so the flames sit where there's the most
	-- 'fuel'. Recoil exposes per-piece bounding boxes via GetFeaturePieceInfo;
	-- most BAR trees are a single piece, in which case this is just the model
	-- bounding box, but it still gives a far better height/canopy estimate than
	-- the collision volume alone. Falls back to the collision volume / feature
	-- height when no mesh data is available.
	local GetFeaturePieceList = Spring.GetFeaturePieceList
	local GetFeaturePieceInfo = Spring.GetFeaturePieceInfo
	local GetFeatureHeight = Spring.GetFeatureHeight
	local function getTreeFireProfile(featureID, featureDefID)
		local height = GetFeatureHeight(featureID) or 0
		local radius = treeRadius[featureDefID]
		local canopyFrac = 0.6
		local pieces = GetFeaturePieceList(featureID)
		if pieces and #pieces > 0 then
			local minY, maxY = math_huge, -math_huge
			local widestR, widestY = 0, nil
			for i = 1, #pieces do
				local info = GetFeaturePieceInfo(featureID, i)
				if info and info.min and info.max then
					local ox = info.offset and info.offset[1] or 0
					local oy = info.offset and info.offset[2] or 0
					local oz = info.offset and info.offset[3] or 0
					local lo = info.min[2] + oy
					local hi = info.max[2] + oy
					if lo < minY then minY = lo end
					if hi > maxY then maxY = hi end
					local rx = math_max(math_abs(info.min[1] + ox), math_abs(info.max[1] + ox))
					local rz = math_max(math_abs(info.min[3] + oz), math_abs(info.max[3] + oz))
					local r = math_max(rx, rz)
					if r > widestR then widestR = r; widestY = (lo + hi) * 0.5 end
				end
			end
			if maxY > minY then
				height = maxY - minY
				if widestR > 1 then radius = widestR end
				if widestY then
					canopyFrac = math_min(0.85, math_max(0.3, (widestY - minY) / height))
				end
			end
		end
		if not radius or radius < 2 then radius = math_max(6, height * 0.2) end
		if height < 4 then height = 20 end
		return height, radius, canopyFrac
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
					strength = math_max(1, treeMass[featureDefID] / dmg),
					fire = false,
					size = size,
					treeburnCEG = 'treeburn-' .. size,
					dissapearSpeed = dissapearSpeed,
					destroyFrame = destroyFrame
				}
				--Spring.Debug.TableEcho(treesdying[tree])
		end
	end

	end



	GG.ComSpawnDefoliate = ComSpawnDefoliate


	local lastLavaLevel = -99999
	local lavaCheckInterval = 30

	local function checkLavaTreesDestroy()
		local lavaLevel = Spring.GetGameRulesParam("lavaLevel")
		if not lavaLevel or lavaLevel <= -99999 then
			return
		end
		local allFeatures = Spring.GetAllFeatures()
		for i = 1, #allFeatures do
			local featureID = allFeatures[i]
			local featureDefID = Spring.GetFeatureDefID(featureID)
			if treeMass[featureDefID] and not geothermals[featureDefID] then
				local remainingMetal, maxMetal, remainingEnergy, maxEnergy = GetFeatureResources(featureID)
				if maxMetal == 0 and maxEnergy > 0 then
					local fx, fy, fz = GetFeaturePosition(featureID)
					if fx and fy <= lavaLevel then
						DestroyFeature(featureID)
					end
				end
			end
		end
		lastLavaLevel = lavaLevel
	end

	local function checkLavaTreesFire(gf)
		local lavaLevel = Spring.GetGameRulesParam("lavaLevel")
		if not lavaLevel or lavaLevel <= -99999 or lavaLevel <= lastLavaLevel then
			return
		end
		local allFeatures = Spring.GetAllFeatures()
		for i = 1, #allFeatures do
			local featureID = allFeatures[i]
			if not treesdying[featureID] then
				local featureDefID = Spring.GetFeatureDefID(featureID)
				if treeMass[featureDefID] and not geothermals[featureDefID] then
					local remainingMetal, maxMetal, remainingEnergy, maxEnergy = GetFeatureResources(featureID)
					if maxMetal == 0 and maxEnergy > 0 then
						local fx, fy, fz = GetFeaturePosition(featureID)
						if fx and fy <= lavaLevel then
							local dx, dy, dz = GetFeatureDirection(featureID)
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
							local destroyFrame = gf + falltime + 150 + (dissapearSpeed * 4000)
							SetFeatureBlocking(featureID, false, false, false, false, false, false, false)
							spSetFeatureResources(0, 0, 0, 0)
							Spring.SetFeatureNoSelect(featureID, true)
							treesdying[featureID] = {
								frame = gf,
								posx = fx, posy = fy, posz = fz,
								fDefID = featureDefID,
								dirx = dx, diry = dy, dirz = dz,
								px = fx + math_random(-10, 10), py = fy, pz = fz + math_random(-10, 10),
								strength = 1,
								fire = true,
								size = size,
								treeburnCEG = 'treeburn-' .. size,
								dissapearSpeed = dissapearSpeed,
								destroyFrame = destroyFrame,
							}
						end
					end
				end
			end
		end
		lastLavaLevel = lavaLevel
	end

	function gadget:Initialize()
		-- At game start, just remove trees already submerged by lava (no fire animation)
		checkLavaTreesDestroy()
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
						treesdying[featureID] = { frame = GetGameFrame(), posx = fx, posy = fy, posz = fz, fDefID = featureDefID, dirx = dx, diry = dy, dirz = dz, px = ppx, py = ppy, pz = ppz, strength = treeMass[featureDefID] / dmg, fire = fire, size = size, treeburnCEG = 'treeburn-' .. size, dissapearSpeed = dissapearSpeed, destroyFrame = destroyFrame } -- this prevents this tobedestroyed feature to be replaced multiple times
						featureID = CreateFeature(featureDefID, fx, fy, fz)
						SetFeatureDirection(featureID, dx, dy, dz)
						SetFeatureBlocking(featureID, false, false, false, false, false, false, false)
						--Echo('tree created... ',featureID)
					else
						Damage = 0 -- so it doesnt take multiple frames for tree to get killed.
						-- Map-placed tree features are treated as STATIC geometry by the GL4
						-- renderer: their draw matrix is baked once and never refreshed, so
						-- the per-frame Spring.SetFeatureDirection spin that topples the trunk
						-- stays invisible. Replace the original with a freshly Lua-created
						-- feature, which renders dynamically and visibly falls. (This is the
						-- same reason the crush path above must recreate.)
						DestroyFeature(featureID)
						featureID = CreateFeature(featureDefID, fx, fy, fz)
						SetFeatureDirection(featureID, dx, dy, dz)
						SetFeatureBlocking(featureID, false, false, false, false, false, false, false)
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
						dmg = math_min(treeMass[featureDefID] * 2, dmg)
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
						dmg = math_min(treeMass[featureDefID] * 2, unitMass[attackerDefID])
						fire = false

					-- UNITEXPLOSION
					elseif attackerID and weaponDefID and not (noFireWeapons[weaponDefID]) then
						ppx, ppy, ppz = Spring.GetUnitPosition(attackerID)
						dmg = math_min(treeMass[featureDefID] * 2, dmg)
						if fy >= 0 then
							fire = true
						end
					end
					spSetFeatureResources(0,0,0,0)
					Spring.SetFeatureNoSelect(featureID, true)
					Spring.PlaySoundFile("treefall", 2, fx, fy, fz, 'sfx')
					treesdying[featureID] = {
						frame = GetGameFrame(),
						posx = fx, posy = fy, posz = fz,
						fDefID = featureDefID,
						dirx = dx, diry = dy, dirz = dz,
						px = ppx, py = ppy, pz = ppz,
						strength = math_max(1, treeMass[featureDefID] / dmg),
						fire = fire,
						size = size,
						treeburnCEG = 'treeburn-' .. size,
						dissapearSpeed = dissapearSpeed,
						destroyFrame = destroyFrame
					}
					if TREEFELLER_DEBUG then
						local pdx, pdz = (ppx or fx) - fx, (ppz or fz) - fz
						dbg("ADD fID=" .. tostring(featureID),
							"fire=" .. tostring(fire),
							"strength=" .. string.format("%.2f", math_max(1, treeMass[featureDefID] / dmg)),
							"dir=(" .. string.format("%.2f,%.2f,%.2f", dx or -99, dy or -99, dz or -99) .. ")",
							"px/pz=" .. tostring(ppx) .. "/" .. tostring(ppz),
							"fallDir=(" .. string.format("%.1f,%.1f", pdx, pdz) .. ")",
							"weaponDefID=" .. tostring(weaponDefID))
					end
					--Spring.Echo('Hornet poi treesdying')
					--Spring.Debug.TableEcho(treesdying[featureID])
				end
			end
		end
		return Damage, 0
	end

	function gadget:GameFrame(gf)
		-- Periodically check for lava rise and ignite newly submerged trees
		if gf % lavaCheckInterval == 0 then
			checkLavaTreesFire(gf)
		end

		local removeFeatures
		local removeCount = 0
		for featureID, featureinfo in pairs(treesdying) do
			local fx, fy, fz = GetFeaturePosition(featureID)
			if not fx then
				if featureinfo.fireSent then
					spSendToUnsynced("treefire_stop", featureID)
					featureinfo.fireSent = false
				end
				if not removeFeatures then removeFeatures = {} end
				removeCount = removeCount + 1
				removeFeatures[removeCount] = featureID
				DestroyFeature(featureID)
			else
				spSetFeatureResources(0,0,0,0)
				-- Resolve a SINGLE, stable fall direction once and cache it. Recomputing
				-- this every frame (and having separate fallbacks in the fire-send vs the
				-- trunk tilt) is what let the trunk and the line of fire point different
				-- ways, and what made some trees "fight" over where to fall. The trunk
				-- leans TOWARD the blast/attacker source (px,pz).
				if not featureinfo.falldirx then
					local ddx = (featureinfo.px or fx) - fx
					local ddz = (featureinfo.pz or fz) - fz
					local d2 = ddx * ddx + ddz * ddz
					if d2 > 0.0001 then
						local inv = 1 / math_sqrt(d2)
						featureinfo.falldirx = ddx * inv
						featureinfo.falldirz = ddz * inv
					else
						-- No meaningful blast direction (e.g. fire that spread between
						-- trees): fall along the tree's own heading, else a fixed default.
						local hx, hz = featureinfo.dirx or 0, featureinfo.dirz or 0
						local h2 = hx * hx + hz * hz
						if h2 > 0.0001 then
							local inv = 1 / math_sqrt(h2)
							featureinfo.falldirx = hx * inv
							featureinfo.falldirz = hz * inv
						else
							featureinfo.falldirx = 1
							featureinfo.falldirz = 0
						end
					end
					dbg("FALLDIR fID=" .. tostring(featureID),
						"dir=(" .. string.format("%.2f,%.2f", featureinfo.falldirx, featureinfo.falldirz) .. ")",
						"fromBlast=" .. tostring(d2 > 0.0001))
				end
				-- Hand the burning visual to the GL4 fire gadget: a flame column that
				-- climbs the tree and topples into a line of fire as it falls.
				if featureinfo.fire and not featureinfo.fireSent then
					local height, radius, canopyFrac = getTreeFireProfile(featureID, featureinfo.fDefID)
					-- IMPORTANT: SetFeatureDirection sets the model FRONT, but the engine
					-- derives the trunk (up vector) as leaning along the NEGATIVE of the
					-- front's horizontal component. So the trunk actually topples toward
					-- -falldir. The line of fire must lie down that same way.
					local fdx = -featureinfo.falldirx
					local fdz = -featureinfo.falldirz
					spSendToUnsynced("treefire_start", featureID, fx, fy, fz, height, radius, canopyFrac,
						fdx, fdz, fallVisualFrames)
					featureinfo.fireSent = true
					dbg("FIRE_SEND fID=" .. tostring(featureID),
						"h=" .. string.format("%.0f", height or -1),
						"r=" .. string.format("%.0f", radius or -1),
						"canopy=" .. string.format("%.2f", canopyFrac or -1),
						"fireDir=(" .. string.format("%.1f,%.1f", fdx, fdz) .. ")")
				end
				local thisfeaturefalltime = falltime * featureinfo.strength
				local fireFrequency = 5
				if featureinfo.fire then
					fireFrequency = math_floor(2 + ((gf - featureinfo.frame) / 70))
				end

				-- FALLING
				if featureinfo.frame + thisfeaturefalltime > gf then
					--Spring.Echo('hornet poi: falling')
					-- Smooth eased topple over a FIXED duration (independent of strength),
					-- so every tree visibly falls promptly. 0 = upright, accelerates like a
					-- real toppling tree and reaches strongly horizontal.
					local vt = (gf - featureinfo.frame) / fallVisualFrames
					if vt < 0 then vt = 0 elseif vt > 1 then vt = 1 end
					local fallY = 0.1 + (vt * vt) * 6.0
					if fy ~= nil then
						if featureinfo.fire then
							if gf % fireFrequency == math_floor(fireFrequency / 3) and math_random(1, 5) == 1 then
								local firex, firey, firez = fx + math_random(-3, 3), fy + math_random(-3, 3), fz + math_random(-3, 3)
								local pos = math_random(5, 9)
								firex = firex - (featureinfo.falldirx * pos)
								firez = firez - (featureinfo.falldirz * pos)
								spSpawnExplosion(firex, firey, firez, 0, 0, 0, treefireExplosion[featureinfo.size])
							end
						end
						-- Use the cached, stable fall direction so the trunk lean always
						-- matches the line of fire (no per-frame recompute / fight).
						-- NOTE: SetFeatureDirection only writes the SYNCED transform; the
						-- unsynced/draw matrix of a static feature is not refreshed, so the
						-- rotation is invisible. The unsynced fire gadget enables
						-- Spring.SetFeatureAlwaysUpdateMatrix on this feature (via the
						-- treefire_start message) which forces the draw matrix to track our
						-- per-frame spin. (Do NOT nudge SetFeaturePosition here: its
						-- ForcedMove re-derives orientation from the ground normal.)
						SetFeatureDirection(featureID, featureinfo.falldirx, fallY, featureinfo.falldirz)
						if TREEFELLER_DEBUG and (gf % 5 == 0) then
							local rdx, rdy, rdz, _, _, _, udx, udy, udz = GetFeatureDirection(featureID)
							dbg("FALL fID=" .. tostring(featureID),
								"vt=" .. string.format("%.2f", vt),
								"fallY=" .. string.format("%.2f", fallY),
								"front=(" .. string.format("%.2f,%.2f,%.2f", rdx or -99, rdy or -99, rdz or -99) .. ")",
								"up=(" .. string.format("%.2f,%.2f,%.2f", udx or -99, udy or -99, udz or -99) .. ")")
						end
					end

				-- FALLEN
				elseif featureinfo.frame + thisfeaturefalltime <= gf then
					--Spring.Echo('hornet poi: fallen')
					if fy ~= nil then
						if featureinfo.fire then
							if gf % fireFrequency == math_floor(fireFrequency / 3) and math_random(1, 6) == 1 then
								local firex, firey, firez = fx + math_random(-3, 3), fy + math_random(-3, 3), fz + math_random(-3, 3)
							local pos = math_random(5, 9)
								firex = firex - ((featureinfo.falldirx or featureinfo.dirx) * pos)
								firez = firez - ((featureinfo.falldirz or featureinfo.dirz) * pos)
								spSpawnExplosion(firex, firey, firez, 0, 0, 0, treefireExplosion[featureinfo.size])
							end
						end

						local gh = spGetGroundHeight(fx, fz)
						if featureinfo.destroyFrame <= gf or (gh > fy + 48) then
						if featureinfo.fireSent then
							spSendToUnsynced("treefire_stop", featureID)
							featureinfo.fireSent = false
						end
						if not removeFeatures then removeFeatures = {} end
						removeCount = removeCount + 1
						removeFeatures[removeCount] = featureID
							DestroyFeature(featureID)
						elseif featureinfo.frame + thisfeaturefalltime + 250 <= gf and featureinfo.fire then
							featureinfo.fire = false
							if featureinfo.fireSent then
								spSendToUnsynced("treefire_stop", featureID)
								featureinfo.fireSent = false
							end
						elseif featureinfo.frame + thisfeaturefalltime + 100 <= gf then
							local dx, dy, dz = GetFeatureDirection(featureID)
							if featureinfo.fire then
								SetFeaturePosition(featureID, fx, fy - featureinfo.dissapearSpeed, fz, false)
							else
								SetFeaturePosition(featureID, fx, fy - featureinfo.dissapearSpeed * 3, fz, false)
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
		for i = 1, removeCount do
			treesdying[removeFeatures[i]] = nil
		end
	end
end
