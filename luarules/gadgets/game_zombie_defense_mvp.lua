function gadget:GetInfo()
	return {
		name = "BAR Zombie Defense MVP Core",
		desc = "Continuous Zombie Horde, Spot Capture, Autonomous Military AI (Garrison/Patrol/Morale/Last Stand), Physics Knockback, Infection, and Auto-Support C-130/A-10",
		author = "BAR Zombie Defense",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -5, -- Run before gfx_tree_feller (layer 0) so infantry bullets never burn trees!
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	--------------------------------------------------------------------------------
	-- SYNCED GAMEPLAY LOGIC
	--------------------------------------------------------------------------------
	local spCreateUnit = Spring.CreateUnit
	local spDestroyUnit = Spring.DestroyUnit
	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetUnitHealth = Spring.GetUnitHealth
	local spSetUnitHealth = Spring.SetUnitHealth
	local spGetUnitTeam = Spring.GetUnitTeam
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spGetFeaturesInCylinder = Spring.GetFeaturesInCylinder
	local spGetFeaturePosition = Spring.GetFeaturePosition
	local spGetFeatureResources = Spring.GetFeatureResources
	local spGetFeatureDefID = Spring.GetFeatureDefID
	local spDestroyFeature = Spring.DestroyFeature
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGiveOrderToUnit = Spring.GiveOrderToUnit
	local spAddUnitImpulse = Spring.AddUnitImpulse
	local spGetUnitVelocity = Spring.GetUnitVelocity
	local spSetGameRulesParam = Spring.SetGameRulesParam
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local spGetHeadingFromVector = Spring.GetHeadingFromVector
	local spSetUnitDirection = Spring.SetUnitDirection
	local rawSpawnCEG = Spring.SpawnCEG
	local cegFxEnabled = true
	local function spSpawnCEG(...)
		if not cegFxEnabled or not rawSpawnCEG then return end
		return rawSpawnCEG(...)
	end
	local spSpawnExplosion = Spring.SpawnExplosion
	local spEcho = Spring.Echo
	local mdSetGroundMoveTypeData = Spring.MoveCtrl and Spring.MoveCtrl.SetGroundMoveTypeData
	local mcEnable = Spring.MoveCtrl and Spring.MoveCtrl.Enable
	local mcSetPosition = Spring.MoveCtrl and Spring.MoveCtrl.SetPosition
	local mcSetVelocity = Spring.MoveCtrl and Spring.MoveCtrl.SetVelocity
	local mcSetHeading = Spring.MoveCtrl and Spring.MoveCtrl.SetHeading
	local mcSetTrackLimits = Spring.MoveCtrl and Spring.MoveCtrl.SetTrackLimits
	local mcSetTrackGround = Spring.MoveCtrl and Spring.MoveCtrl.SetTrackGround
	local mcSetTrackSlope = Spring.MoveCtrl and Spring.MoveCtrl.SetTrackSlope
	local mcSetLimitsStop = Spring.MoveCtrl and Spring.MoveCtrl.SetLimitsStop
	local mcSetCollideStop = Spring.MoveCtrl and Spring.MoveCtrl.SetCollideStop
	local mcSetNoBlocking = Spring.MoveCtrl and Spring.MoveCtrl.SetNoBlocking
	local mcSetGravity = Spring.MoveCtrl and Spring.MoveCtrl.SetGravity
	local mcSetWindFactor = Spring.MoveCtrl and Spring.MoveCtrl.SetWindFactor
	local mcSetLimits = Spring.MoveCtrl and Spring.MoveCtrl.SetLimits

	local CMD_MOVE = CMD.MOVE
	local CMD_FIGHT = CMD.FIGHT
	local CMD_PATROL = CMD.PATROL
	local CMD_STOP = CMD.STOP

	local HUMAN_TEAM = 0
	local ZOMBIE_TEAM = 1

	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ

	-- UnitDef IDs (populated in Initialize)
	local UDEF = {}
	local isZombieDef = {}
	local isHumanMilitaryDef = {}
	local isInfectableDef = {}
	local isNoTreeFireUnitDef = {}
	local isTreeFireWeaponDef = {}
	local unitPower = {}
	local unitThreat = {}

	-- Global State
	local commandPoints = 220
	local autoSupportEnabled = true -- DEFAULT ON as requested by user!
	local fullSightEnabled = true -- DEFAULT ON: Full Map Sight option!
	local maxZombiesCap = 900
	local zombieLifespanFrames = 150 * 30 -- 150 seconds decay lifespan
	local activeZombies = {} -- unitID -> { spawnFrame, lastCombatFrame, ztype }
	local activeZombieCount = 0

	local militaryUnits = {} -- unitID -> { role = "garrison"|"patrol", spotIdx = nil, morale = 85, state = "HOLD", defName = "" }
	local pendingInfections = {} -- list of { frame, x, y, z }
	local activeAirMissions = {} -- list of { unitID, mtype, tx, tz, endFrame, nextTickFrame }
	local activeAirProjectiles = {} -- list of { ptype = "missile"|"bomb", x, y, z, vx, vy, vz, tx, ty, tz, ownerID }
	local persistentC130 = nil -- Single persistent C-130 / AC-130 orbiting the battlefield!
	local spots = {} -- list of { id, x, y, z, owner = 0(neutral)|1(human), capture = 0..100, contested = false, garrison = {} }
	local hqUnitID = nil
	local hqX, hqZ = 600, 600
	local enemyStartX, enemyStartZ = nil, nil
	local totalZombiesKilled = 0
	local totalSoldiersInfected = 0
	local totalAirSorties = 0
	local currentWaveNum = 1
	local prevSurgeState = false
	local hqLastDamagedFrame = -9999
	local gameOverState = false

	-- Push a real-time tactical radio alert for the overhauled HUD toast banner
	local function pushTacticalAlert(text, alertType, frame)
		spSetGameRulesParam("zdef_alert_text", text or "")
		spSetGameRulesParam("zdef_alert_type", alertType or "info")
		spSetGameRulesParam("zdef_alert_frame", frame or Spring.GetGameFrame() or 0)
	end

	-- Temporarily disabled until dedicated parachute / paradrop assets are available
	local ENABLE_C130_PARADROP = false
	local lastHqInfRallyFrame = -9999

	-- Support Package Costs & Cooldowns (Balanced for Infantry-Heavy RTT Combat & Rare Armor!)
	local PACKAGES = {
		para = { cost = 65, cd = 6 * 30, lastFrame = -9999, name = "C-130 Paratrooper Squad Drop (6 Soldiers)" },
		armor = { cost = 190, cd = 26 * 30, lastFrame = -9999, name = "C-130 Armored Patrol / Tank Airdrop" },
		a10 = { cost = 150, cd = 12 * 30, lastFrame = -9999, name = "A-10 Attack Jet 30mm Trench Strafe" },
		ac130 = { cost = 180, cd = 16 * 30, lastFrame = -9999, name = "F-16V Strike Fighter Dive Missile & Bomb Strike" },
	}

	local MAX_ACTIVE_TANKS = 2
	local MAX_ACTIVE_MRAPS = 3

	local function clampMap(x, z, margin)
		margin = margin or 96
		return math.max(margin, math.min(mapSizeX - margin, x)), math.max(margin, math.min(mapSizeZ - margin, z))
	end

	local function dist2DSq(x1, z1, x2, z2)
		local dx = x1 - x2
		local dz = z1 - z2
		return dx * dx + dz * dz
	end

	local function dist2D(x1, z1, x2, z2)
		local dx = x1 - x2
		local dz = z1 - z2
		return math.sqrt(dx * dx + dz * dz)
	end

	local function countActiveVehicleTypes()
		local tanks, mraps, inf = 0, 0, 0
		for uid, mdata in pairs(militaryUnits) do
			if spGetUnitHealth(uid) then
				if mdata.defID == UDEF.zdef_tank then
					tanks = tanks + 1
				elseif mdata.defID == UDEF.zdef_mrap then
					mraps = mraps + 1
				else
					inf = inf + 1
				end
			end
		end
		return tanks, mraps, inf
	end

	local spTestBuildOrder = Spring.TestBuildOrder
	local spTestMoveOrder = Spring.TestMoveOrder
	local spGetTeamStartPosition = Spring.GetTeamStartPosition
	local spGetStartBox = Spring.GetStartBox

	-- Check local terrain flatness & above-water safety so HQ and squads NEVER spawn trapped on steep ridges or in water!
	local function getTerrainSlopeSpan(x, z, sampleR)
		sampleR = sampleR or 28
		local y0 = spGetGroundHeight(x, z) or 0
		local y1 = spGetGroundHeight(math.min(mapSizeX - 16, x + sampleR), z) or y0
		local y2 = spGetGroundHeight(math.max(16, x - sampleR), z) or y0
		local y3 = spGetGroundHeight(x, math.min(mapSizeZ - 16, z + sampleR)) or y0
		local y4 = spGetGroundHeight(x, math.max(16, z - sampleR)) or y0
		local maxD = math.max(math.abs(y1 - y0), math.abs(y2 - y0), math.abs(y3 - y0), math.abs(y4 - y0))
		return y0, maxD
	end

	-- Find a flat, buildable HQ coordinate right at (or immediately adjacent to) the map's official Team 0 Start Position!
	local function findFlatHQPos(startX, startZ)
		local bestX, bestZ, bestScore = clampMap(startX, startZ, 160), nil, 999999
		bestX, bestZ = clampMap(startX, startZ, 160)
		for ring = 0, 12 do
			local r = ring * 34
			local steps = (ring == 0) and 1 or (ring * 6)
			for s = 0, steps - 1 do
				local ang = (s / steps) * math.pi * 2.0
				local tx, tz = clampMap(startX + math.cos(ang) * r, startZ + math.sin(ang) * r, 150)
				local ty, slopeD = getTerrainSlopeSpan(tx, tz, 44)
				if ty > 4 then
					local buildOk = true
					if spTestBuildOrder and UDEF.zdef_hq then
						local res = spTestBuildOrder(UDEF.zdef_hq, tx, ty, tz, 1)
						buildOk = (res ~= 0)
					end
					if buildOk then
						local score = slopeD * 18.0 + r * 0.25
						if score < bestScore then
							bestScore = score
							bestX, bestZ = tx, tz
						end
						if ring == 0 and slopeD <= 10.0 then
							return tx, tz
						end
					end
				end
			end
			if bestScore < 160 then
				return bestX, bestZ
			end
		end
		return bestX, bestZ
	end

	-- Resolve official Map Start Position for Human Military (Team 0) and opposing Zombie Horde (Team 1)
	local function resolveMapStartPositions()
		local sx, sy, sz = nil, nil, nil
		if spGetTeamStartPosition then
			local rx, ry, rz = spGetTeamStartPosition(HUMAN_TEAM)
			if rx and rz and (rx > 1 or rz > 1) then
				sx, sy, sz = rx, ry, rz
			end
		end
		if (not sx or not sz) and spGetStartBox then
			local xmin, zmin, xmax, zmax = spGetStartBox(0)
			if xmin and xmax and zmin and zmax and (xmax > xmin) and (zmax > zmin) then
				sx = (xmin + xmax) * 0.5
				sz = (zmin + zmax) * 0.5
			end
		end
		if not sx or not sz then
			sx = math.min(mapSizeX * 0.22, 700)
			sz = mapSizeZ * 0.5
		end
		local fx, fz = findFlatHQPos(sx, sz)

		-- Resolve opposing enemy start position (Team 1 startpos or mirror across map center)
		local ex, ez = nil, nil
		if spGetTeamStartPosition then
			local rx, _, rz = spGetTeamStartPosition(ZOMBIE_TEAM)
			if rx and rz and (rx > 1 or rz > 1) and dist2DSq(rx, rz, fx, fz) > (500 * 500) then
				ex, ez = rx, rz
			end
		end
		if not ex or not ez then
			ex, ez = clampMap(mapSizeX - fx, mapSizeZ - fz, 140)
		end
		return fx, fz, ex, ez
	end

	-- Find a guaranteed passable, flat, non-overlapping spawn coordinate for Infantry / MRAP / Tank (NEVER stuck on cliffs/HQ/water!)
	local function findNonOverlappingDropPos(cx, cz, minDist, uDefID)
		minDist = minDist or 76
		local checkDefID = uDefID or UDEF.zdef_tank
		local isVeh = (checkDefID == UDEF.zdef_tank or checkDefID == UDEF.zdef_mrap)
		local maxSlope = isVeh and 14.0 or 20.0
		local bestX, bestZ, bestSlope = nil, nil, 9999
		for attempt = 0, 28 do
			local r = (attempt == 0) and 0 or (48 + attempt * 18)
			local ang = attempt * 1.15
			local tx, tz = clampMap(cx + math.cos(ang) * r, cz + math.sin(ang) * r, 88)
			local ty, slopeD = getTerrainSlopeSpan(tx, tz, isVeh and 30 or 18)
			if ty > 3 then
				local moveOk = true
				if spTestMoveOrder and checkDefID then
					moveOk = (spTestMoveOrder(checkDefID, tx, ty, tz) == true)
				end
				if moveOk then
					local near = spGetUnitsInCylinder(tx, tz, minDist) or {}
					local blocked = false
					for i = 1, #near do
						local ndef = spGetUnitDefID(near[i])
						if ndef and (ndef == UDEF.zdef_hq or (isVeh and (ndef == UDEF.zdef_tank or ndef == UDEF.zdef_mrap))) then
							blocked = true
							break
						end
					end
					if not blocked then
						if slopeD <= maxSlope then
							return tx, tz
						elseif slopeD < bestSlope then
							bestSlope, bestX, bestZ = slopeD, tx, tz
						end
					end
				end
			end
		end
		if bestX and bestZ then
			return bestX, bestZ
		end
		return clampMap(cx + math.random(-120, 120), cz + math.random(-120, 120), 90)
	end

	local function discoverStrategicSpots()
		spots = {}
		if GG.metalSpots and #GG.metalSpots > 0 then
			for i, ms in ipairs(GG.metalSpots) do
				local y = spGetGroundHeight(ms.x, ms.z)
				spots[#spots + 1] = {
					id = i,
					x = ms.x,
					y = y,
					z = ms.z,
					owner = 0,
					capture = 0,
					contested = false,
				}
			end
		end

		-- Fallback grid scan if map has no metal spot table
		if #spots < 4 then
			spots = {}
			local cols, rows = 3, 3
			for cx = 1, cols do
				for cz = 1, rows do
					local sx = (mapSizeX / (cols + 1)) * cx
					local sz = (mapSizeZ / (rows + 1)) * cz
					local sy = spGetGroundHeight(sx, sz)
					spots[#spots + 1] = {
						id = #spots + 1,
						x = sx,
						y = sy,
						z = sz,
						owner = 0,
						capture = 0,
						contested = false,
					}
				end
			end
		end

		spSetGameRulesParam("zdef_spot_count", #spots)
		for i, s in ipairs(spots) do
			spSetGameRulesParam("zdef_spot_x_" .. i, math.floor(s.x))
			spSetGameRulesParam("zdef_spot_z_" .. i, math.floor(s.z))
			spSetGameRulesParam("zdef_spot_owner_" .. i, s.owner)
			spSetGameRulesParam("zdef_spot_contested_" .. i, 0)
		end
	end

	local burnZones = {} -- list of { x, y, z, radius, expireFrame, nextTickFrame }
	local burningTrees = {} -- featureID -> { x, y, z, expireFrame }
	local burningZombies = {} -- unitID -> expireFrame
	local doomedAirborneZombies = {} -- unitID -> { killFrame, attackerID }
	local zombieCorpses = {} -- featureID -> expireFrame

	local function isTreeFeature(fid)
		if not spGetFeatureResources then return false end
		local _, maxM, _, maxE = spGetFeatureResources(fid)
		return (maxM == 0 and (maxE or 0) > 0)
	end

	local function setCharacterGait(uid, defID, gait)
		-- Switch between realistic Walk speed & Run speed, and notify zdef_character.lua to play Walk vs Run animation clip!
		spSetUnitRulesParam(uid, "zdef_gait", gait)
		if not mdSetGroundMoveTypeData then return end
		local walkSpd, runSpd = 18.0, 29.0
		if defID == UDEF.zdef_infantry then
			walkSpd, runSpd = 19.5, 32.0
		elseif defID == UDEF.zdef_paratrooper then
			walkSpd, runSpd = 21.0, 35.0
		elseif defID == UDEF.zdef_zombie_walker then
			walkSpd, runSpd = 13.5, 23.0
		elseif defID == UDEF.zdef_zombie_soldier then
			walkSpd, runSpd = 15.5, 26.0
		elseif defID == UDEF.zdef_zombie_bloater then
			walkSpd, runSpd = 11.5, 18.5
		elseif defID == UDEF.zdef_zombie_brute then
			walkSpd, runSpd = 12.5, 20.5
		else
			return
		end
		local targetElmosPerSec = (gait == "run") and runSpd or walkSpd
		-- NOTE: Spring.MoveCtrl.SetGroundMoveTypeData(uid, "maxSpeed", val) takes elmos/SECOND (same as UnitDefs[id].speed)
		-- and automatically divides by GAME_SPEED (30) internally in C++!
		mdSetGroundMoveTypeData(uid, "maxSpeed", targetElmosPerSec)
	end

	local function igniteTreesAndZombiesInRadius(cx, cz, radius, frame)
		-- Trigger BAR's native gfx_tree_feller (tree toppling, charcoal bark shader, and flame column)
		-- via Spring.SpawnExplosion with treefire_large weaponDef, plus track in burningTrees!
		local cy = spGetGroundHeight(cx, cz)
		if spSpawnExplosion and WeaponDefNames and WeaponDefNames["treefire_large"] then
			spSpawnExplosion(cx, cy + 8, cz, 0, 0, 0, {
				weaponDef = WeaponDefNames["treefire_large"].id,
				hitUnit = 0,
				hitFeature = 1,
				craterAreaOfEffect = radius + 25,
				damageAreaOfEffect = radius + 25,
				edgeEffectiveness = 0.85,
				explosionSpeed = 4,
				impactOnly = false,
				ignoreOwner = true,
				damageGround = false,
			})
		end
		if spGetFeaturesInCylinder then
			local feats = spGetFeaturesInCylinder(cx, cz, radius + 30)
			if feats then
				for i = 1, #feats do
					local fid = feats[i]
					if isTreeFeature(fid) then
						local fx, fy, fz = spGetFeaturePosition(fid)
						if fx then
							if spSpawnExplosion and WeaponDefNames and WeaponDefNames["treefire_medium"] then
								spSpawnExplosion(fx, fy + 6, fz, 0, 0, 0, {
									weaponDef = WeaponDefNames["treefire_medium"].id,
									hitUnit = 0,
									hitFeature = 1,
									craterAreaOfEffect = 45,
									damageAreaOfEffect = 45,
									edgeEffectiveness = 0.9,
									explosionSpeed = 2,
									impactOnly = false,
									ignoreOwner = true,
									damageGround = false,
								})
							end
							burningTrees[fid] = {
								x = fx,
								y = fy,
								z = fz,
								expireFrame = frame + 300, -- Tree burns for 10 seconds and can ignite nearby zombies
							}
						end
					end
				end
			end
		end
	end

	local function launchZombiesInRadius(cx, cz, radius, upImpulse, outImpulse, damageAmount, attackerID)
		local units = spGetUnitsInCylinder(cx, cz, radius)
		if not units then return end
		for i = 1, #units do
			local uid = units[i]
			local defID = spGetUnitDefID(uid)
			if defID and isZombieDef[defID] then
				local ux, uy, uz = spGetUnitPosition(uid)
				if ux then
					local dx = ux - cx
					local dz = uz - cz
					local d = math.sqrt(dx * dx + dz * dz)
					local falloff = math.max(0.28, 1.0 - (d / (radius + 12)))
					local nx = (d > 1) and (dx / d) or (math.random() - 0.5)
					local nz = (d > 1) and (dz / d) or (math.random() - 0.5)

					-- Realistic mass scaling:
					-- Walker (38) & Soldier (46) launch into the air (~18-32 elmos high, 1.1-1.5s hangtime);
					-- Bloater (65) launches moderately; Brute (5000) resists airborne launch and only staggers!
					local massFactor = 1.0
					if defID == UDEF.zdef_zombie_brute then
						massFactor = 0.14
					elseif defID == UDEF.zdef_zombie_bloater then
						massFactor = 0.72
					elseif defID == UDEF.zdef_zombie_soldier then
						massFactor = 0.88
					end

					-- Clamp total velocity so multiple overlapping shells never send zombies into orbit
					local curVx, curVy, curVz = 0, 0, 0
					if spGetUnitVelocity then
						curVx, curVy, curVz = spGetUnitVelocity(uid)
						curVx, curVy, curVz = curVx or 0, curVy or 0, curVz or 0
					end

					local addVx = nx * outImpulse * falloff * massFactor
					local addVy = upImpulse * falloff * massFactor
					local addVz = nz * outImpulse * falloff * massFactor

					if curVy + addVy > 3.3 then
						addVy = math.max(0, 3.3 - curVy)
					end
					local horizSpd = math.sqrt((curVx + addVx) ^ 2 + (curVz + addVz) ^ 2)
					if horizSpd > 2.8 then
						local scaleH = 2.8 / horizSpd
						addVx = addVx * scaleH
						addVz = addVz * scaleH
					end

					spAddUnitImpulse(uid, addVx, addVy, addVz)

					-- User rule: Once a zombie is launched/tossed into the air by an explosion, it is GUARANTEED to die and be torn into flying pieces!
					local frame = Spring.GetGameFrame()
					spSetUnitRulesParam(uid, "zdef_gib_death", 1)
					if addVy >= 0.85 and massFactor > 0.25 then
						-- If fatal or mid-range blast, shred immediately into flying pieces (head, arms, torso) while body is tossed;
						-- outer-edge zombies fly for ~0.45s then burst apart on landing!
						local hp = spGetUnitHealth(uid) or 100
						if (damageAmount and (damageAmount * falloff) >= hp * 0.75) or (d <= radius * 0.55) then
							spDestroyUnit(uid, false, false, attackerID or hqUnitID)
						else
							spSetUnitHealth(uid, 1)
							doomedAirborneZombies[uid] = {
								killFrame = frame + 14,
								attackerID = attackerID or hqUnitID,
							}
						end
					elseif damageAmount and damageAmount > 0 then
						local hp = spGetUnitHealth(uid)
						if hp then
							local newHp = hp - (damageAmount * falloff)
							if newHp <= 0 then
								spDestroyUnit(uid, false, false, attackerID or hqUnitID)
							else
								spSetUnitHealth(uid, newHp)
							end
						end
					end
				end
			end
		end
	end

	local function boostFriendlyMoraleNear(cx, cz, radius, boost)
		local rSq = radius * radius
		for uid, mdata in pairs(militaryUnits) do
			local ux, _, uz = spGetUnitPosition(uid)
			if ux and dist2DSq(ux, uz, cx, cz) <= rSq then
				mdata.morale = math.min(100, mdata.morale + boost)
				spSetUnitRulesParam(uid, "zdef_morale", math.floor(mdata.morale))
			end
		end
	end

	local function initOffMapAircraft(unitName, startX, startY, startZ, initVx, initVy, initVz)
		-- Spawn inside valid map bounds first so Recoil Engine's CUnitLoader never clamps or perturbs AirMoveType,
		-- then immediately enable MoveCtrl, disable all ground/limit/wind/gravity interference, and place at off-map entry!
		local safeX, safeZ = clampMap(startX, startZ, 64)
		local uid = spCreateUnit(unitName, safeX, startY, safeZ, 1, HUMAN_TEAM)
		if uid and mcEnable then
			mcEnable(uid)
			if mcSetTrackLimits then mcSetTrackLimits(uid, false) end
			if mcSetTrackGround then mcSetTrackGround(uid, false) end
			if mcSetTrackSlope then mcSetTrackSlope(uid, false) end
			if mcSetLimitsStop then mcSetLimitsStop(uid, false) end
			if mcSetCollideStop then mcSetCollideStop(uid, false) end
			if mcSetNoBlocking then mcSetNoBlocking(uid, true) end
			if mcSetGravity then mcSetGravity(uid, 0.0) end
			if mcSetWindFactor then mcSetWindFactor(uid, 0.0) end
			if mcSetLimits then
				mcSetLimits(uid, -4000, -1000, -4000, mapSizeX + 4000, 6000, mapSizeZ + 4000)
			end
			mcSetPosition(uid, startX, startY, startZ)
			mcSetVelocity(uid, initVx or 7.5, initVy or 0.0, initVz or 0.0)
			if spGetHeadingFromVector and mcSetHeading then
				mcSetHeading(uid, spGetHeadingFromVector(initVx or 7.5, initVz or 0.0))
			end
			spSetUnitRulesParam(uid, "zdef_flight_pitch", 0.0)
			spSetUnitRulesParam(uid, "zdef_flight_roll", 0.0)
		end
		return uid
	end

	-- Compute a stable reference ground elevation across the sortie corridor so off-map mountain ridges
	-- at x = 0 never cause the aircraft to bob up and down or jump altitude on frame 1!
	local function getCorridorRefGroundY(tx, tz)
		local hTarget = spGetGroundHeight(tx, tz) or 100
		local hWest = spGetGroundHeight(64, tz) or hTarget
		local hMid = spGetGroundHeight(math.min(mapSizeX - 64, math.max(64, tx * 0.5)), tz) or hTarget
		return math.max(hTarget, (hTarget * 0.6 + math.max(hWest, hMid) * 0.4))
	end

	local function ensureSingleOrbitingC130()
		if persistentC130 and persistentC130.unitID and spGetUnitHealth(persistentC130.unitID) then
			return persistentC130
		end
		local cx = math.min(mapSizeX - 650, math.max(650, ( spots[1] and spots[1].x ) or (hqX + 550)))
		local cz = math.min(mapSizeZ - 650, math.max(650, ( spots[1] and spots[1].z ) or hqZ))
		local refY = getCorridorRefGroundY(cx, cz)
		local orbitR = 520
		local theta = 0.0
		local px = cx + orbitR * math.sin(theta)
		local pz = cz + orbitR * math.cos(theta)
		local py = refY + 335
		local speed = 6.4
		local uid = initOffMapAircraft("zdef_c130", px, py, pz, speed, 0.0, 0.0)
		if uid then
			persistentC130 = {
				unitID = uid,
				cx = cx,
				cz = cz,
				targetCX = cx,
				targetCZ = cz,
				refY = refY,
				orbitR = orbitR,
				theta = theta,
				speed = speed,
				prevX = px,
				prevY = py,
				prevZ = pz,
				nextGatlingFrame = 0,
				nextHowitzerFrame = 0,
				pendingDrops = {},
			}
		end
		return persistentC130
	end

	local function executeSupportPackage(pkgKey, tx, tz, frame, isAuto)
		if pkgKey == "para" and not ENABLE_C130_PARADROP then
			return false
		end
		local pkg = PACKAGES[pkgKey]
		if not pkg then return false end
		if pkgKey == "armor" then
			local activeTanks, activeMraps = countActiveVehicleTypes()
			if activeTanks >= MAX_ACTIVE_TANKS and activeMraps >= MAX_ACTIVE_MRAPS then
				return false
			end
		end
		if commandPoints < pkg.cost or (frame - pkg.lastFrame) < pkg.cd then
			return false
		end

		commandPoints = commandPoints - pkg.cost
		pkg.lastFrame = frame
		tx, tz = clampMap(tx, tz, 140)
		local ty = spGetGroundHeight(tx, tz)
		local refY = getCorridorRefGroundY(tx, tz)

		local tag = isAuto and "[AUTO-SUPPORT]" or "[MANUAL-SUPPORT]"
		spEcho(string.format("%s Dispatching %s at (%.0f, %.0f)!", tag, pkg.name, tx, tz))
		if pkgKey == "para" then
			pushTacticalAlert("C-130 THẢ TIỂU ĐỘI LÍNH DÙ (6 QUÂN)", "air", frame)
		elseif pkgKey == "armor" then
			pushTacticalAlert("C-130 THẢ CHI VIỆN THIẾT GIÁP", "air", frame)
		elseif pkgKey == "a10" then
			pushTacticalAlert("A-10 THUNDERBOLT CÀY XỚI 30MM ĐANG TỚI!", "air", frame)
		elseif pkgKey == "ac130" then
			pushTacticalAlert("F-16V BỔ NHÀO PHÓNG TÊN LỬA & BOM NAPALM!", "air", frame)
		end

		local turnSign = (tz > mapSizeZ * 0.5) and -1 or 1
		totalAirSorties = totalAirSorties + 1
		spSetGameRulesParam("zdef_air_sorties", totalAirSorties)

		if pkgKey == "para" or pkgKey == "armor" then
			-- STRICT SINGLE C-130 RULE: Never spawn a second C-130!
			-- Instead, our single persistent orbiting C-130 smoothly shifts its orbit center toward (tx, tz)
			-- and drops the Paratrooper squad or Armored Vehicle directly from its airborne loiter orbit!
			local c130State = ensureSingleOrbitingC130()
			if c130State then
				c130State.targetCX, c130State.targetCZ = clampMap(tx, tz, 480)
				c130State.pendingDrops[#c130State.pendingDrops + 1] = {
					dtype = pkgKey,
					tx = tx,
					tz = tz,
					dropFrame = frame + 35, -- Releases payload 1.15s after command as C-130 banks over drop zone
				}
			end
		elseif pkgKey == "a10" then
			-- ARCHETYPE 2: CƯỜNG KÍCH (A-10 Thunderbolt II — Low-Altitude Battlefield Trench Strafe / "Cày xới chiến trường"):
			-- Approaches straight along the combat front line, descends to low altitude (refY + 115),
			-- pitches nose down (-18 deg), and plows a long 14-round stitched trench (~620 elmos long!) of 30mm GAU-8 shells
			-- across the zombie horde before pulling up (+25 deg) and banking out!
			local a10StartX = -420
			local attackAngle = (tz > mapSizeZ * 0.5) and -0.10 or 0.10
			local dirX = math.cos(attackAngle)
			local dirZ = math.sin(attackAngle)
			local approachDist = (tx - a10StartX) / dirX
			local a10StartZ = tz - dirZ * approachDist
			local speed = 9.8
			local strikeFrames = math.floor(approachDist / speed)
			local egressDist = (mapSizeX + 480 - tx) / dirX
			local egressFrames = math.floor(math.max(200, egressDist) / speed)
			local totalFrames = strikeFrames + egressFrames
			local startY = refY + 280
			local initVx = dirX * speed
			local initVz = dirZ * speed

			local a10 = initOffMapAircraft("zdef_a10", a10StartX, startY, a10StartZ, initVx, 0.0, initVz)
			if a10 then
				activeAirMissions[#activeAirMissions + 1] = {
					unitID = a10,
					mtype = "a10",
					startFrame = frame,
					strikeFrames = strikeFrames,
					egressFrames = egressFrames,
					totalFrames = totalFrames,
					startX = a10StartX,
					startZ = a10StartZ,
					tx = tx,
					ty = ty,
					refY = refY,
					tz = tz,
					dirX = dirX,
					dirZ = dirZ,
					speed = speed,
					turnSign = turnSign,
					prevX = a10StartX,
					prevY = startY,
					prevZ = a10StartZ,
					strikesDone = 0,
					maxStrikes = 14, -- Long 14-round stitched 30mm trench plowing across the battlefield!
				}
			end
			boostFriendlyMoraleNear(tx, tz, 550, 30)
		elseif pkgKey == "ac130" then
			-- ARCHETYPE 3: TIÊM KÍCH (F-16V Strike Fighter — High-Speed Steep Dive Missile & Bomb Strike / "Bổ nhào phóng tên lửa hoặc thả bom"):
			-- Streaks in at supersonic speed (14.2 elmos/frame) and high altitude (refY + 510),
			-- executes a steep -34 deg attack dive toward (tx, tz), releases a salvo of 4 AGM Missiles + 2 Heavy Cluster/Napalm Bombs
			-- that visibly streak down from its wings into (tx, tz), and immediately pulls a high-G +38 deg climb & 62 deg breakaway turn!
			local fStartX = -440
			local attackAngle = (tz > mapSizeZ * 0.5) and -0.16 or 0.16
			local dirX = math.cos(attackAngle)
			local dirZ = math.sin(attackAngle)
			-- Release point is 260 elmos BEFORE (tx, tz) during the steep dive!
			local releaseX = tx - dirX * 260
			local releaseZ = tz - dirZ * 260
			local approachDist = math.max(250, (releaseX - fStartX) / dirX)
			local fStartZ = releaseZ - dirZ * approachDist
			local speed = 14.2
			local diveFrames = math.floor(approachDist / speed)
			local egressDist = (mapSizeX + 520 - releaseX) / dirX
			local egressFrames = math.floor(math.max(180, egressDist) / speed)
			local totalFrames = diveFrames + egressFrames
			local startY = refY + 510
			local initVx = dirX * speed
			local initVz = dirZ * speed

			local fighter = initOffMapAircraft("zdef_fighter", fStartX, startY, fStartZ, initVx, 0.0, initVz)
			if fighter then
				activeAirMissions[#activeAirMissions + 1] = {
					unitID = fighter,
					mtype = "fighter_dive",
					startFrame = frame,
					diveFrames = diveFrames,
					egressFrames = egressFrames,
					totalFrames = totalFrames,
					startX = fStartX,
					startZ = fStartZ,
					releaseX = releaseX,
					releaseZ = releaseZ,
					tx = tx,
					ty = ty,
					refY = refY,
					tz = tz,
					dirX = dirX,
					dirZ = dirZ,
					speed = speed,
					turnSign = turnSign,
					prevX = fStartX,
					prevY = startY,
					prevZ = fStartZ,
					missilesLaunched = false,
					bombsDropped = false,
				}
			end
			boostFriendlyMoraleNear(tx, tz, 650, 40)
		end

		return true
	end

	function gadget:Initialize()
		for name, def in pairs(UnitDefNames) do
			if name:find("^zdef_") then
				UDEF[name] = def.id
				local cp = def.customParams or {}
				if cp.zdef_role == "zombie" then
					isZombieDef[def.id] = true
					isNoTreeFireUnitDef[def.id] = true
					unitThreat[def.id] = tonumber(cp.zdef_threat) or 10
				elseif cp.zdef_role == "infantry" or cp.zdef_role == "armor" then
					isHumanMilitaryDef[def.id] = true
					unitPower[def.id] = tonumber(cp.zdef_power) or 20
					if cp.zdef_infectable == "1" then
						isInfectableDef[def.id] = true
						isNoTreeFireUnitDef[def.id] = true
					elseif name == "zdef_mrap" then
						isNoTreeFireUnitDef[def.id] = true
					end
				end
			end
		end

		for _, wname in ipairs({ "treefire_tiny", "treefire_small", "treefire_medium", "treefire_large" }) do
			if WeaponDefNames[wname] then
				isTreeFireWeaponDef[WeaponDefNames[wname].id] = true
			end
		end

		discoverStrategicSpots()
		local modOpts = Spring.GetModOptions and Spring.GetModOptions() or {}
		if modOpts.full_sight == "0" or modOpts.full_sight == 0 then
			fullSightEnabled = false
		end
		if Spring.SetGlobalLos then
			Spring.SetGlobalLos(0, fullSightEnabled)
		end
		spSetGameRulesParam("zdef_auto_support", autoSupportEnabled and 1 or 0)
		spSetGameRulesParam("zdef_full_sight", fullSightEnabled and 1 or 0)
		spSetGameRulesParam("zdef_command_points", math.floor(commandPoints))
		spSetGameRulesParam("zdef_zombie_count", 0)
		spSetGameRulesParam("zdef_zombie_cap", maxZombiesCap)
		spSetGameRulesParam("zdef_zombies_killed", 0)
		spSetGameRulesParam("zdef_soldiers_infected", 0)
		spSetGameRulesParam("zdef_air_sorties", 0)
		spSetGameRulesParam("zdef_hq_id", 0)
		spSetGameRulesParam("zdef_hq_hp", 15000)
		spSetGameRulesParam("zdef_hq_maxhp", 15000)
		spSetGameRulesParam("zdef_hq_under_attack", 0)
		spSetGameRulesParam("zdef_surge_progress", 0)
		spSetGameRulesParam("zdef_wave_num", 1)
		spSetGameRulesParam("zdef_game_over", 0)
		spSetGameRulesParam("zdef_c130_mode", "ORBIT")
		spSetGameRulesParam("zdef_active_air_count", 1)
		pushTacticalAlert("CHIẾN DỊCH PHÒNG THỦ BẮT ĐẦU — QUÂN ĐỘI TỰ ĐỘNG TÁC CHIẾN", "info", 0)
	end

	function gadget:GameStart()
		-- Place Military HQ & initial army at the Map's official Team 0 Start Position on guaranteed flat, buildable ground!
		hqX, hqZ, enemyStartX, enemyStartZ = resolveMapStartPositions()
		spSetGameRulesParam("zdef_hq_x", math.floor(hqX))
		spSetGameRulesParam("zdef_hq_z", math.floor(hqZ))
		spEcho(string.format("[ZOMBIE DEFENSE] Map StartPos resolved: HQ=(%.0f, %.0f), HordeOrigin=(%.0f, %.0f)", hqX, hqZ, enemyStartX, enemyStartZ))

		if #spots > 0 then
			-- Sort spots by distance to HQ so Spot 1 & 2 are natural starting spots nearest the map's Team 0 StartPos!
			table.sort(spots, function(a, b)
				return dist2D(a.x, a.z, hqX, hqZ) < dist2D(b.x, b.z, hqX, hqZ)
			end)
			for i, s in ipairs(spots) do
				s.id = i
				spSetGameRulesParam("zdef_spot_x_" .. i, math.floor(s.x))
				spSetGameRulesParam("zdef_spot_z_" .. i, math.floor(s.z))
				spSetGameRulesParam("zdef_spot_capture_" .. i, s.capture or 0)
			end
		end

		local hqY = spGetGroundHeight(hqX, hqZ)
		hqUnitID = spCreateUnit("zdef_hq", hqX, hqY, hqZ, 1, HUMAN_TEAM)
		if hqUnitID then
			spSetGameRulesParam("zdef_hq_id", hqUnitID)
		end

		-- Direction vector from HQ toward map center / front line so starting army deploys facing the enemy!
		local fdx = (enemyStartX or (mapSizeX * 0.5)) - hqX
		local fdz = (enemyStartZ or (mapSizeZ * 0.5)) - hqZ
		local fLen = math.max(1.0, math.sqrt(fdx * fdx + fdz * fdz))
		local fwdX, fwdZ = fdx / fLen, fdz / fLen
		local sideX, sideZ = -fwdZ, fwdX

		-- Spawn initial Autonomous Military Force on guaranteed flat, passable terrain around Map StartPos (12 Rifle Infantry, 1 MRAP, 1 Tank)
		for i = 1, 12 do
			local ring = (i <= 6) and 130 or 175
			local angle = ((i - 1) % 6) / 6 * math.pi * 2 + ((i > 6) and 0.52 or 0)
			local rawX = hqX + math.cos(angle) * ring
			local rawZ = hqZ + math.sin(angle) * ring
			local sx, sz = findNonOverlappingDropPos(rawX, rawZ, 26, UDEF.zdef_infantry)
			local uid = spCreateUnit("zdef_infantry", sx, spGetGroundHeight(sx, sz), sz, 1, HUMAN_TEAM)
			if uid and spots[1] then
				spGiveOrderToUnit(uid, CMD_FIGHT, { spots[1].x + math.cos(angle) * 55, spots[1].y, spots[1].z + math.sin(angle) * 55 }, {})
			end
		end
		local mx, mz = findNonOverlappingDropPos(hqX + fwdX * 175 + sideX * 105, hqZ + fwdZ * 175 + sideZ * 105, 85, UDEF.zdef_mrap)
		local mrapID = spCreateUnit("zdef_mrap", mx, spGetGroundHeight(mx, mz), mz, 1, HUMAN_TEAM)
		if mrapID and spots[2] then
			spGiveOrderToUnit(mrapID, CMD_MOVE, { spots[2].x, spots[2].y, spots[2].z }, {})
		end
		local tx, tz = findNonOverlappingDropPos(hqX + fwdX * 195 - sideX * 105, hqZ + fwdZ * 195 - sideZ * 105, 90, UDEF.zdef_tank)
		local tankID = spCreateUnit("zdef_tank", tx, spGetGroundHeight(tx, tz), tz, 1, HUMAN_TEAM)
		if tankID and spots[1] then
			spGiveOrderToUnit(tankID, CMD_MOVE, { spots[1].x + 55, spots[1].y, spots[1].z }, {})
		end

		-- Pre-capture nearest spot
		if spots[1] then
			spots[1].owner = 1
			spots[1].capture = 100
			spSetGameRulesParam("zdef_spot_owner_1", 1)
			spSetGameRulesParam("zdef_spot_capture_1", 100)
		end

		-- Spawn the SINGLE Persistent C-130 / AC-130 Gunship & Airlifter circling the battlefield!
		ensureSingleOrbitingC130()
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam)
		local frame = Spring.GetGameFrame()
		if isZombieDef[unitDefID] then
			activeZombies[unitID] = {
				spawnFrame = frame,
				lastCombatFrame = frame,
				defID = unitDefID,
			}
			activeZombieCount = activeZombieCount + 1
			setCharacterGait(unitID, unitDefID, "walk")
		elseif isHumanMilitaryDef[unitDefID] and unitTeam == HUMAN_TEAM then
			militaryUnits[unitID] = {
				role = "patrol",
				spotIdx = nil,
				morale = 90,
				state = "PATROL",
				defID = unitDefID,
			}
			spSetUnitRulesParam(unitID, "zdef_morale", 90)
			spSetUnitRulesParam(unitID, "zdef_state", "PATROL")
			setCharacterGait(unitID, unitDefID, "walk")
		end
	end

	-- Prevent infantry bullets & zombie attacks from ever burning or felling trees;
	-- record trees ignited by heavy explosions/fire so nearby zombies catch fire!
	function gadget:FeaturePreDamaged(featureID, featureDefID, featureTeam, damage, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if isTreeFeature(featureID) then
			if attackerDefID and isNoTreeFireUnitDef[attackerDefID] then
				return 0, 0
			end
			if weaponDefID and WeaponDefs[weaponDefID] and WeaponDefs[weaponDefID].customParams and WeaponDefs[weaponDefID].customParams.nofire then
				return 0, 0
			end
			-- Heavy ordnance / fire weapon hit a tree -> track as burning tree so nearby zombies catch fire!
			local fx, fy, fz = spGetFeaturePosition(featureID)
			if fx then
				burningTrees[featureID] = {
					x = fx,
					y = fy,
					z = fz,
					expireFrame = Spring.GetGameFrame() + 300,
				}
			end
		end
		return damage, 1
	end

	-- High-impulse physics knockback whenever Tank 120mm HE Cannon fires/hits, plus tree-fire ignition on zombies
	function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		local frame = Spring.GetGameFrame()
		if hqUnitID and unitID == hqUnitID and attackerTeam == ZOMBIE_TEAM then
			if (frame - hqLastDamagedFrame) > 150 then
				pushTacticalAlert("CẢNH BÁO: CĂN CỨ HQ ĐANG BỊ ZOMBIE TẤN CÔNG!", "danger", frame)
			end
			hqLastDamagedFrame = frame
			spSetGameRulesParam("zdef_hq_under_attack", 1)
		end
		if activeZombies[unitID] then
			activeZombies[unitID].lastCombatFrame = frame
			-- If zombie is hit by BAR's treefire explosion or incendiary weapon, ignite the zombie!
			if weaponDefID and isTreeFireWeaponDef[weaponDefID] then
				burningZombies[unitID] = frame + 180
			end
		end
		if attackerID and activeZombies[attackerID] then
			activeZombies[attackerID].lastCombatFrame = frame
		end

		-- If hit by M1 Battle Tank 120mm HE cannon, mark for heavy dismemberment & apply upward/outward shockwave toss
		-- (The explosion visual comes solely from the 120mm HE shell hitting the ground, never from the zombie's body!)
		if attackerDefID and attackerDefID == UDEF.zdef_tank and isZombieDef[unitDefID] then
			spSetUnitRulesParam(unitID, "zdef_gib_death", 1)
			local ux, uy, uz = spGetUnitPosition(unitID)
			if ux then
				igniteTreesAndZombiesInRadius(ux, uz, 120, frame)
				launchZombiesInRadius(ux, uz, 115, 2.2, 1.6, 0, attackerID)
			end
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		local frame = Spring.GetGameFrame()
		if activeZombies[unitID] then
			local zinfo = activeZombies[unitID]
			activeZombies[unitID] = nil
			burningZombies[unitID] = nil
			doomedAirborneZombies[unitID] = nil
			activeZombieCount = math.max(0, activeZombieCount - 1)

			-- Award Command Points if killed in combat (not lifespan decay)
			if not zinfo.decayed then
				local reward = (unitDefID == UDEF.zdef_zombie_brute) and 18 or 3
				commandPoints = commandPoints + reward
				totalZombiesKilled = totalZombiesKilled + 1
				spSetGameRulesParam("zdef_zombies_killed", totalZombiesKilled)
			end

			-- Flesh-and-blood zombies NEVER explode in fire or smoke on death!
			-- (Bloater rupture only splashes organic bio-fluid/knockback without any fire/smoke explosion)
			if unitDefID == UDEF.zdef_zombie_bloater then
				local bx, by, bz = spGetUnitPosition(unitID)
				if bx then
					launchZombiesInRadius(bx, bz, 65, 0.95, 0.85, 60, unitID)
				end
			end
		elseif hqUnitID and unitID == hqUnitID then
			hqUnitID = nil
			gameOverState = true
			spSetGameRulesParam("zdef_hq_id", 0)
			spSetGameRulesParam("zdef_hq_hp", 0)
			spSetGameRulesParam("zdef_game_over", 1)
			pushTacticalAlert("CĂN CỨ HQ ĐÃ THẤT THỦ — NHIỆM VỤ THẤT BẠI!", "danger", frame)
		elseif militaryUnits[unitID] then
			local ux, uy, uz = spGetUnitPosition(unitID)
			militaryUnits[unitID] = nil

			-- INFECTION MECHANIC: Infantry killed by Zombie turns into zdef_zombie_soldier!
			-- (If killed by friendly bomb/artillery, no infection!)
			if isInfectableDef[unitDefID] and attackerTeam == ZOMBIE_TEAM and ux then
				totalSoldiersInfected = totalSoldiersInfected + 1
				spSetGameRulesParam("zdef_soldiers_infected", totalSoldiersInfected)
				pendingInfections[#pendingInfections + 1] = {
					frame = frame + 65, -- 2.2 seconds later, rises as Zombie Soldier
					x = ux,
					y = uy,
					z = uz,
				}
				-- Lower morale of nearby witnesses (squared distance — zero sqrt!)
				local witnessRSq = 280 * 280
				for mID, mdata in pairs(militaryUnits) do
					local mx, _, mz = spGetUnitPosition(mID)
					if mx and dist2DSq(mx, mz, ux, uz) < witnessRSq then
						mdata.morale = math.max(10, mdata.morale - 14)
					end
				end
			end
		end
	end

	-- Continuous Zombie Stream + Periodic Surge Tide + Lifespan Decay
	local function updateContinuousZombies(frame)
		-- 1. Process pending Infantry -> Zombie Soldier infections
		for i = #pendingInfections, 1, -1 do
			local inf = pendingInfections[i]
			if frame >= inf.frame then
				table.remove(pendingInfections, i)
				if activeZombieCount < maxZombiesCap + 30 then
					local zid = spCreateUnit("zdef_zombie_soldier", inf.x, inf.y, inf.z, math.random(0, 3), ZOMBIE_TEAM)
					if zid then
						spEcho("[INFECTION] A fallen soldier has reanimated as an Infected Soldier Zombie!")
					end
				end
			end
		end

		-- 2. Lifespan Decay check (zombies die after lifespan to prevent stuck units & guarantee FPS)
		for zid, zinfo in pairs(activeZombies) do
			if (frame - zinfo.lastCombatFrame) > zombieLifespanFrames then
				zinfo.decayed = true
				spDestroyUnit(zid, false, true)
			end
		end

		-- 3. Continuous Stream + Sine-Wave Surge Tide
		if activeZombieCount >= maxZombiesCap then
			return
		end

		local minutes = frame / (30 * 60)
		local surgeWave = math.sin(frame / (30 * 25))
		local isSurge = (surgeWave > 0.45) -- Surge tide every ~1.5 min
		if isSurge and not prevSurgeState then
			currentWaveNum = currentWaveNum + 1
			spSetGameRulesParam("zdef_wave_num", currentWaveNum)
			pushTacticalAlert(string.format("LÀN SÓNG ZOMBIE #%d (SURGE TIDE) ĐANG TRÀN TỚI!", currentWaveNum), "danger", frame)
		end
		prevSurgeState = isSurge
		spSetGameRulesParam("zdef_surge_active", isSurge and 1 or 0)
		spSetGameRulesParam("zdef_surge_progress", math.floor(math.max(0, math.min(100, (surgeWave + 1.0) * 50))))

		local spawnCount = isSurge and math.min(10, 4 + math.floor(minutes * 2)) or math.min(5, 2 + math.floor(minutes))
		for s = 1, spawnCount do
			if activeZombieCount >= maxZombiesCap then break end

			-- Spawn zombies dynamically from the opposing map side / Team 1 StartPos (works cleanly on ANY BAR map!)
			local sx, sz
			local minSafeHqSq = 1150 * 1150
			local mode = math.random(1, 3)
			if mode == 1 and enemyStartX and enemyStartZ then
				local ang = math.random() * math.pi * 2.0
				local rad = math.random(60, 380)
				sx, sz = clampMap(enemyStartX + math.cos(ang) * rad, enemyStartZ + math.sin(ang) * rad, 110)
			else
				-- Pick a random map edge point guaranteed far away from HQ (on the opposite half of the map!)
				local hqIsLeft = (hqX < mapSizeX * 0.5)
				local hqIsTop = (hqZ < mapSizeZ * 0.5)
				for _ = 1, 6 do
					local pick = math.random(1, 2)
					if pick == 1 then
						sx = hqIsLeft and (mapSizeX - 95 - math.random(0, 140)) or (95 + math.random(0, 140))
						sz = math.random(140, mapSizeZ - 140)
					else
						sx = math.random(140, mapSizeX - 140)
						sz = hqIsTop and (mapSizeZ - 95 - math.random(0, 140)) or (95 + math.random(0, 140))
					end
					if dist2DSq(sx, sz, hqX, hqZ) >= minSafeHqSq then
						break
					end
				end
			end
			-- Ensure zombies also spawn on passable ground (never stuck inside water or sheer cliffs!)
			if spTestMoveOrder and UDEF.zdef_zombie_walker then
				local syCheck = spGetGroundHeight(sx, sz)
				if syCheck <= 2 or not spTestMoveOrder(UDEF.zdef_zombie_walker, sx, syCheck, sz) then
					sx, sz = findNonOverlappingDropPos(enemyStartX or (mapSizeX - hqX), enemyStartZ or (mapSizeZ - hqZ), 20, UDEF.zdef_zombie_walker)
				end
			end
			local sy = spGetGroundHeight(sx, sz)

			local roll = math.random(1, 100)
			local zName = "zdef_zombie_walker"
			if isSurge and roll <= 10 then
				zName = "zdef_zombie_brute"
			elseif roll <= 22 then
				zName = "zdef_zombie_bloater"
			elseif roll <= 34 then
				zName = "zdef_zombie_soldier"
			end

			local zid = spCreateUnit(zName, sx, sy, sz, math.random(0, 3), ZOMBIE_TEAM)
			if zid then
				-- Order zombie toward nearest captured Spot or HQ
				local targetX, targetZ = hqX, hqZ
				local bestDist = 999999
				for _, spot in ipairs(spots) do
					if spot.owner == 1 then
						local d = dist2D(sx, sz, spot.x, spot.z)
						if d < bestDist then
							bestDist = d
							targetX, targetZ = spot.x, spot.z
						end
					end
				end
				spGiveOrderToUnit(zid, CMD_FIGHT, { targetX, spGetGroundHeight(targetX, targetZ), targetZ }, {})
			end
		end
	end

	-- Update Spot Capture & Command Point Economy
	local function updateSpotsAndEconomy(frame)
		local capturedCount = 0
		for i, s in ipairs(spots) do
			local near = spGetUnitsInCylinder(s.x, s.z, 220) or {}
			local humanCount, zombieCount = 0, 0
			for j = 1, #near do
				local uid = near[j]
				local defID = spGetUnitDefID(uid)
				if defID then
					if isHumanMilitaryDef[defID] then
						humanCount = humanCount + 1
					elseif isZombieDef[defID] then
						zombieCount = zombieCount + 1
					end
				end
			end

			local prevOwner = s.owner
			local prevContested = s.contested
			s.contested = (s.owner == 1 and zombieCount > humanCount and zombieCount >= 2)
			if humanCount > 0 and zombieCount == 0 then
				s.capture = math.min(100, s.capture + 15 + humanCount * 5)
				if s.capture >= 100 then
					s.owner = 1
					if prevOwner ~= 1 then
						pushTacticalAlert(string.format("ĐÃ KIỂM SOÁT CỨ ĐIỂM S%d (+3.5 CP/s)!", i), "good", frame)
					end
				end
			elseif zombieCount > humanCount * 2 and zombieCount >= 3 then
				s.capture = math.max(0, s.capture - 20)
				if s.capture <= 0 then
					s.owner = 0
					if prevOwner == 1 then
						pushTacticalAlert(string.format("MẤT QUYỀN KIỂM SOÁT CỨ ĐIỂM S%d!", i), "danger", frame)
					end
				end
			end
			if s.contested and not prevContested then
				pushTacticalAlert(string.format("CỨ ĐIỂM S%d ĐANG GIAO TRANH DỮ DỘI!", i), "warn", frame)
			end

			if s.owner == 1 then
				capturedCount = capturedCount + 1
			end
			spSetGameRulesParam("zdef_spot_owner_" .. i, s.owner)
			spSetGameRulesParam("zdef_spot_contested_" .. i, s.contested and 1 or 0)
			spSetGameRulesParam("zdef_spot_capture_" .. i, math.floor(s.capture or 0))
		end

		-- Sync HQ health telemetry & under-attack decay
		spSetGameRulesParam("zdef_hq_under_attack", ((frame - hqLastDamagedFrame) <= 120) and 1 or 0)
		if hqUnitID and spGetUnitHealth(hqUnitID) then
			local hqHp, hqMaxHp = spGetUnitHealth(hqUnitID)
			spSetGameRulesParam("zdef_hq_hp", math.floor(hqHp or 0))
			spSetGameRulesParam("zdef_hq_maxhp", math.floor(hqMaxHp or 15000))
		else
			spSetGameRulesParam("zdef_hq_hp", 0)
		end

		-- Base HQ Passive Income (4 CP/sec) + 3.5 CP/sec per uncontested captured Spot
		local activeSpots = 0
		for _, s in ipairs(spots) do
			if s.owner == 1 and not s.contested then
				activeSpots = activeSpots + 1
			end
		end
		local incomePerSec = 4.0 + activeSpots * 3.5
		commandPoints = commandPoints + incomePerSec
		spSetGameRulesParam("zdef_command_points", math.floor(commandPoints))
		spSetGameRulesParam("zdef_cp_income", math.floor(incomePerSec))
		spSetGameRulesParam("zdef_captured_spots", capturedCount)
		local activeTanks, activeMraps, activeInf = countActiveVehicleTypes()
		spSetGameRulesParam("zdef_active_tanks", activeTanks)
		spSetGameRulesParam("zdef_active_mraps", activeMraps)
		spSetGameRulesParam("zdef_active_inf", activeInf)
		for pkgKey, pkg in pairs(PACKAGES) do
			local cdRem = math.max(0, math.ceil(((pkg.lastFrame + pkg.cd) - frame) / 30))
			spSetGameRulesParam("zdef_cd_" .. pkgKey, cdRem)
		end
		return capturedCount
	end

	-- Autonomous Military AI: Garrison, Continuous Patrol, Search & Destroy, Morale & Last Stand
	local function updateAutonomousMilitaryAI(frame, capturedCount)
		-- 1. Evaluate Garrison quotas per captured spot (at least 2 units per captured spot)
		local spotGarrisonCount = {}
		for i = 1, #spots do spotGarrisonCount[i] = 0 end

		for uid, mdata in pairs(militaryUnits) do
			if mdata.role == "garrison" and mdata.spotIdx and spots[mdata.spotIdx] and spots[mdata.spotIdx].owner == 1 then
				spotGarrisonCount[mdata.spotIdx] = spotGarrisonCount[mdata.spotIdx] + 1
			else
				mdata.role = "patrol"
				mdata.spotIdx = nil
			end
		end

		-- Assign surplus infantry ONLY to under-garrisoned captured spots (at least 3 infantry per spot);
		-- Tanks and MRAPs NEVER stay as static garrison so they always roam and patrol across the map!
		for i, s in ipairs(spots) do
			if s.owner == 1 and spotGarrisonCount[i] < 3 then
				for uid, mdata in pairs(militaryUnits) do
					if mdata.role == "patrol" and mdata.defID ~= UDEF.zdef_mrap and mdata.defID ~= UDEF.zdef_tank then
						mdata.role = "garrison"
						mdata.spotIdx = i
						spotGarrisonCount[i] = spotGarrisonCount[i] + 1
						if spotGarrisonCount[i] >= 3 then break end
					end
				end
			end
		end

		-- Active anti-stacking repulsion for vehicles (Tanks & MRAPs): if two vehicles are within 58 elmos, nudge them apart!
		local vehicleList = {}
		for uid, mdata in pairs(militaryUnits) do
			if mdata.defID == UDEF.zdef_tank or mdata.defID == UDEF.zdef_mrap then
				local vx, vy, vz = spGetUnitPosition(uid)
				if vx then
					vehicleList[#vehicleList + 1] = { uid = uid, x = vx, y = vy, z = vz }
				end
			end
		end
		for i = 1, #vehicleList do
			for j = i + 1, #vehicleList do
				local v1, v2 = vehicleList[i], vehicleList[j]
				local d = dist2D(v1.x, v1.z, v2.x, v2.z)
				if d < 58 then
					local nx = (d > 1) and ((v2.x - v1.x) / d) or 1.0
					local nz = (d > 1) and ((v2.z - v1.z) / d) or 0.0
					local pushX, pushZ = clampMap(v2.x + nx * 75, v2.z + nz * 75, 85)
					spGiveOrderToUnit(v2.uid, CMD_MOVE, { pushX, spGetGroundHeight(pushX, pushZ), pushZ }, {})
				end
			end
		end

		-- Strategic Criticality: fewer captured spots remaining -> higher Resolve (lower retreat threshold)
		local scarcityBonus = (capturedCount <= 2) and 22 or ((capturedCount <= 4) and 10 or 0)

		-- 2. Evaluate each military unit's local threat, Morale, and tactical orders
		--    Cache zombie positions once per AI tick so overlapping squads avoid redundant C++ position queries!
		local zPosX, zPosZ = {}, {}
		local closeZDistSq = 115 * 115
		local nearHqDistSq = 420 * 420
		local hotspotX, hotspotZ, highestThreatRatio = nil, nil, 0

		for uid, mdata in pairs(militaryUnits) do
			local ux, uy, uz = spGetUnitPosition(uid)
			if ux and uz then
				local nearby = spGetUnitsInCylinder(ux, uz, 460) or {}
				local friendlyPwr, zombieThr = 0, 0
				local closeZombies = 0
				local avgZX, avgZZ = 0, 0
				local zCount = 0
				local hasArmorSupport = false

				for j = 1, #nearby do
					local nid = nearby[j]
					local ndef = spGetUnitDefID(nid)
					if ndef then
						if isHumanMilitaryDef[ndef] then
							friendlyPwr = friendlyPwr + (unitPower[ndef] or 15)
							if ndef == UDEF.zdef_tank or ndef == UDEF.zdef_mrap then
								hasArmorSupport = true
							end
						elseif isZombieDef[ndef] then
							zombieThr = zombieThr + (unitThreat[ndef] or 8)
							zCount = zCount + 1
							local zx = zPosX[nid]
							local zz = zPosZ[nid]
							if not zx then
								zx, _, zz = spGetUnitPosition(nid)
								zPosX[nid] = zx or false
								zPosZ[nid] = zz
							end
							if zx and zz then
								avgZX = avgZX + zx
								avgZZ = avgZZ + zz
								if dist2DSq(ux, uz, zx, zz) < closeZDistSq then
									closeZombies = closeZombies + 1
								end
							end
						end
					end
				end

				local threatRatio = zombieThr / math.max(15, friendlyPwr)
				if threatRatio > highestThreatRatio and zCount >= 4 then
					highestThreatRatio = threatRatio
					hotspotX, hotspotZ = avgZX / zCount, avgZZ / zCount
				end

				-- Update Morale (0..100)
				local nearHQ = (dist2DSq(ux, uz, hqX, hqZ) < nearHqDistSq)
				if threatRatio > 1.4 then
					mdata.morale = math.max(5, mdata.morale - (threatRatio * 4.5))
				else
					local recover = 4 + (hasArmorSupport and 4 or 0) + (nearHQ and 5 or 0)
					mdata.morale = math.min(100, mdata.morale + recover)
				end

				-- Retreat threshold adjusts dynamically based on Spot Criticality & HQ proximity
				local retreatThreshold = math.max(12, 38 - scarcityBonus - (nearHQ and 18 or 0))

				if nearHQ and threatRatio > 1.3 then
					-- LAST STAND at HQ perimeter: fight to the death!
					mdata.state = "LAST_STAND"
					if zCount > 0 then
						spGiveOrderToUnit(uid, CMD_FIGHT, { avgZX / zCount, uy, avgZZ / zCount }, {})
					end
				elseif mdata.morale < retreatThreshold and threatRatio > 1.35 and mdata.defID ~= UDEF.zdef_tank then
					-- Check if escape path toward HQ is blocked by zombies
					local dirX = hqX - ux
					local dirZ = hqZ - uz
					local dLen = math.max(1, math.sqrt(dirX * dirX + dirZ * dirZ))
					local escX, escZ = clampMap(ux + (dirX / dLen) * 260, uz + (dirZ / dLen) * 260, 80)
					local blockUnits = spGetUnitsInCylinder(escX, escZ, 120) or {}
					local blockers = 0
					for k = 1, #blockUnits do
						local bdef = spGetUnitDefID(blockUnits[k])
						if bdef and isZombieDef[bdef] then blockers = blockers + 1 end
					end

					if blockers >= 6 then
						-- Surrounded with no escape -> LAST STAND (fight to the death!)
						mdata.state = "LAST_STAND"
						spGiveOrderToUnit(uid, CMD_FIGHT, { avgZX / math.max(1, zCount), uy, avgZZ / math.max(1, zCount) }, {})
					else
						-- TACTICAL RETREAT back toward HQ or safest rear Spot
						mdata.state = "RETREAT"
						spGiveOrderToUnit(uid, CMD_MOVE, { escX, spGetGroundHeight(escX, escZ), escZ }, {})
					end
				elseif closeZombies >= 2 and isInfectableDef[mdata.defID] and zCount > 0 then
					-- SELF-PRESERVATION SPACING: kite back slightly away from slow zombies
					mdata.state = "HOLD"
					local zx, zz = avgZX / zCount, avgZZ / zCount
					local kx, kz = ux - (zx - ux) * 0.9, uz - (zz - uz) * 0.9
					kx, kz = clampMap(kx, kz, 80)
					spGiveOrderToUnit(uid, CMD_MOVE, { kx, spGetGroundHeight(kx, kz), kz }, {})
				elseif mdata.role == "garrison" and mdata.spotIdx and spots[mdata.spotIdx] then
					-- GARRISON: defend assigned Spot, or engage small feasible group nearby
					local sp = spots[mdata.spotIdx]
					if zCount > 0 and friendlyPwr >= zombieThr * 1.8 and dist2D(ux, uz, sp.x, sp.z) < 340 then
						mdata.state = "SEARCH_DESTROY"
						spGiveOrderToUnit(uid, CMD_FIGHT, { avgZX / zCount, uy, avgZZ / zCount }, {})
					else
						mdata.state = "HOLD"
						if dist2D(ux, uz, sp.x, sp.z) > 130 then
							spGiveOrderToUnit(uid, CMD_FIGHT, { sp.x, sp.y, sp.z }, {})
						end
					end
				else
					-- PATROL / QRF / SEARCH & DESTROY
					local isVehicle = (mdata.defID == UDEF.zdef_tank or mdata.defID == UDEF.zdef_mrap)
					-- Give each unit a unique angular formation offset around waypoints so tanks/infantry never stack on the same point!
					local formAngle = (uid * 2.39996) % (math.pi * 2)
					local formRadius = isVehicle and 68 or 38
					local offX = math.cos(formAngle) * formRadius
					local offZ = math.sin(formAngle) * formRadius

					if zCount > 0 and (friendlyPwr >= zombieThr * 1.4 or mdata.defID == UDEF.zdef_tank) then
						-- Proactive forward defense: Tanks advance toward zombie clusters to shell them, keeping ~140 elmos standoff!
						mdata.state = "SEARCH_DESTROY"
						local zx, zz = avgZX / zCount, avgZZ / zCount
						if isVehicle then
							local dx, dz = zx - ux, zz - uz
							local d = math.max(1, math.sqrt(dx * dx + dz * dz))
							if d > 210 then
								local ax, az = clampMap(zx - (dx / d) * 140 + offX * 0.5, zz - (dz / d) * 140 + offZ * 0.5, 85)
								spGiveOrderToUnit(uid, CMD_MOVE, { ax, spGetGroundHeight(ax, az), az }, {})
							else
								spGiveOrderToUnit(uid, CMD_FIGHT, { zx + offX * 0.4, uy, zz + offZ * 0.4 }, {})
							end
						else
							spGiveOrderToUnit(uid, CMD_FIGHT, { zx + offX * 0.4, uy, zz + offZ * 0.4 }, {})
						end
					else
						-- Check for any contested Spot needing QRF, or uncaptured Spot, or rotate patrol between captured Spots
						local targetSpot = nil
						local bestScore = 999999
						for _, sp in ipairs(spots) do
							local d = dist2D(ux, uz, sp.x, sp.z)
							if sp.contested then
								if d * 0.4 < bestScore then
									bestScore = d * 0.4
									targetSpot = sp
								end
							elseif sp.owner == 0 and d < bestScore then
								bestScore = d
								targetSpot = sp
							end
						end
						if not targetSpot and #spots > 0 then
							local patrolIdx = ((uid + math.floor(frame / 180)) % #spots) + 1
							targetSpot = spots[patrolIdx]
						end
						if targetSpot then
							mdata.state = (targetSpot.owner == 0) and "CAPTURE" or "PATROL"
							local wx, wz = clampMap(targetSpot.x + offX, targetSpot.z + offZ, 85)
							local wy = spGetGroundHeight(wx, wz)
							-- Use CMD_MOVE for vehicles when travelling > 160 elmos to waypoint so Tank turret can aim independently while hull keeps driving!
							if isVehicle and dist2D(ux, uz, wx, wz) > 160 then
								spGiveOrderToUnit(uid, CMD_MOVE, { wx, wy, wz }, {})
							else
								spGiveOrderToUnit(uid, CMD_FIGHT, { wx, wy, wz }, {})
							end
						end
					end
				end

					spSetUnitRulesParam(uid, "zdef_morale", math.floor(mdata.morale))
				spSetUnitRulesParam(uid, "zdef_state", mdata.state)
				-- Set realistic Walk vs Run gait based on tactical state:
				-- HOLD / PATROL -> tactical Walk; SEARCH_DESTROY / CAPTURE / RETREAT / LAST_STAND -> combat Run!
				local infGait = (mdata.state == "HOLD" or mdata.state == "PATROL") and "walk" or "run"
				setCharacterGait(uid, mdata.defID, infGait)
			end
		end

		-- Re-target idle zombies toward nearest human spot/HQ periodically & update Walk vs Run gait
		local isSurgeNow = ((Spring.GetGameRulesParam("zdef_surge_active") or 0) == 1)
		for zid, zinfo in pairs(activeZombies) do
			if (zid + math.floor(frame / 60)) % 4 == 0 then
				local zx, _, zz = spGetUnitPosition(zid)
				if zx then
					local tx, tz = hqX, hqZ
					local bestD = dist2D(zx, zz, hqX, hqZ)
					for _, s in ipairs(spots) do
						if s.owner == 1 then
							local d = dist2D(zx, zz, s.x, s.z)
							if d < bestD then
								bestD = d
								tx, tz = s.x, s.z
							end
						end
					end
					-- Zombies shamble (Walk) normally, and break into an aggressive Run when close to human targets (< 230 elmos),
					-- recently wounded in combat, or during a Surge Tide (for infected soldiers & runners)!
					local recentlyShot = ((frame - (zinfo.lastCombatFrame or 0)) < 120) and ((zid % 2) == 0)
					local closeChase = (bestD < 230) and (zinfo.defID == UDEF.zdef_zombie_soldier or (zid % 2 == 0))
					local surgeSprint = isSurgeNow and (zinfo.defID == UDEF.zdef_zombie_soldier or (zid % 3 == 0))
					local zGait = (closeChase or recentlyShot or surgeSprint) and "run" or "walk"
					setCharacterGait(zid, zinfo.defID, zGait)
					spGiveOrderToUnit(zid, CMD_FIGHT, { tx, spGetGroundHeight(tx, tz), tz }, {})
				end
			end
		end

		-- 3. AUTO-SUPPORT DISPATCHER (Enabled by default!)
		if autoSupportEnabled then
			-- Steer the single orbiting C-130 toward the highest-threat combat hotspot!
			if hotspotX and persistentC130 then
				persistentC130.targetCX, persistentC130.targetCZ = clampMap(hotspotX, hotspotZ, 480)
			end
			-- Priority 1: Heavy Air Support (F-16 Dive Fighter or A-10 Trench Strafe) when a hotspot or contested Spot is under heavy pressure
			if hotspotX and highestThreatRatio >= 1.25 then
				if not executeSupportPackage("ac130", hotspotX, hotspotZ, frame, true) then
					executeSupportPackage("a10", hotspotX, hotspotZ, frame, true)
				end
			end

			-- Priority 2: Infantry-First Reinforcement! Drop 6-man Paratrooper squads frequently (up to 36 infantry),
			-- and only drop Armor when under strict vehicle caps (MAX 2 Tanks, MAX 3 MRAPs)!
			local activeTanks, activeMraps, activeInf = countActiveVehicleTypes()

			local dropSpot = spots[1]
			for _, s in ipairs(spots) do
				if s.contested or s.owner == 0 then
					dropSpot = s
					break
				end
			end
			if dropSpot then
				if ENABLE_C130_PARADROP then
					if activeInf < 36 and commandPoints >= PACKAGES.para.cost then
						local px_d, pz_d = clampMap(dropSpot.x - 80 + math.random(-45, 45), dropSpot.z + math.random(-45, 45), 85)
						executeSupportPackage("para", px_d, pz_d, frame, true)
					end
				elseif hqUnitID and spGetUnitHealth(hqUnitID) and activeInf < 28 and commandPoints >= 65 and (frame - lastHqInfRallyFrame) >= 300 then
					-- Ground Infantry Reinforcement directly from Military HQ (replaces C-130 paradrop while paradrop assets are pending)
					commandPoints = commandPoints - 65
					lastHqInfRallyFrame = frame
					local fdx = (dropSpot.x or (mapSizeX * 0.5)) - hqX
					local fdz = (dropSpot.z or (mapSizeZ * 0.5)) - hqZ
					local fLen = math.max(1.0, math.sqrt(fdx * fdx + fdz * fdz))
					local fwdX, fwdZ = fdx / fLen, fdz / fLen
					local sideX, sideZ = -fwdZ, fwdX
					for p = 1, 4 do
						local col = (p - 2.5) * 32
						local sx, sz = findNonOverlappingDropPos(hqX + fwdX * 118 + sideX * col, hqZ + fwdZ * 118 + sideZ * col, 24, UDEF.zdef_infantry)
						local sy = spGetGroundHeight(sx, sz)
						local iid = spCreateUnit("zdef_infantry", sx, sy, sz, 1, HUMAN_TEAM)
						if iid then
							local wx, wz = clampMap(dropSpot.x + math.random(-65, 65), dropSpot.z + math.random(-65, 65), 80)
							spGiveOrderToUnit(iid, CMD_FIGHT, { wx, spGetGroundHeight(wx, wz), wz }, {})
						end
					end
					pushTacticalAlert("CĂN CỨ HQ TRIỂN KHAI TIỂU ĐỘI BỘ BINH (4 QUÂN)", "good", frame)
					spEcho(string.format("[HQ-REINFORCE] Deployed 4 Rifle Infantry at HQ (%.0f, %.0f) -> Spot (%.0f, %.0f)", hqX, hqZ, dropSpot.x, dropSpot.z))
				end
				if (activeTanks < MAX_ACTIVE_TANKS or activeMraps < MAX_ACTIVE_MRAPS) and commandPoints >= PACKAGES.armor.cost + 70 then
					local ax_d, az_d = findNonOverlappingDropPos(dropSpot.x - 110, dropSpot.z, 85)
					executeSupportPackage("armor", ax_d, az_d, frame, true)
				end
			end
		end
	end

	-- Update the SINGLE Persistent Orbiting C-130 + A-10 Trench Strafes + F-16 Dive Fighter Missile/Bomb Sorties!
	local function updateAirMissions(frame)
		-- 1. Update the 1 Single Persistent C-130 / AC-130 continuously circling the battlefield (Pylon-Turn Orbit)
		local c130 = ensureSingleOrbitingC130()
		if c130 and c130.unitID and spGetUnitHealth(c130.unitID) then
			local uid = c130.unitID
			-- Smoothly glide orbit center (cx, cz) toward active front line / drop target (targetCX, targetCZ)
			local dcx = (c130.targetCX or c130.cx) - c130.cx
			local dcz = (c130.targetCZ or c130.cz) - c130.cz
			local dLen = math.sqrt(dcx * dcx + dcz * dcz)
			if dLen > 1.5 then
				local stepC = math.min(dLen, 2.2)
				c130.cx = c130.cx + (dcx / dLen) * stepC
				c130.cz = c130.cz + (dcz / dLen) * stepC
			end
			c130.refY = c130.refY * 0.98 + getCorridorRefGroundY(c130.cx, c130.cz) * 0.02

			local R = c130.orbitR
			local omega = c130.speed / R
			c130.theta = (c130.theta + omega) % (math.pi * 2.0)
			local px = c130.cx + R * math.sin(c130.theta)
			local pz = c130.cz + R * math.cos(c130.theta)
			local py = c130.refY + 335 + 8 * math.sin(c130.theta * 2.0)

			local vx = px - (c130.prevX or px)
			local vy = py - (c130.prevY or py)
			local vz = pz - (c130.prevZ or pz)
			c130.prevX, c130.prevY, c130.prevZ = px, py, pz

			if mcSetPosition then
				mcSetPosition(uid, px, py, pz)
				mcSetVelocity(uid, vx, vy, vz)
				local hLen = math.sqrt(vx * vx + vz * vz)
				if hLen > 0.02 and spGetHeadingFromVector and mcSetHeading then
					mcSetHeading(uid, spGetHeadingFromVector(vx, vz))
				end
			end
			-- Constant -26 deg port-wing-down pylon bank toward the interior of the battlefield orbit!
			spSetUnitRulesParam(uid, "zdef_flight_pitch", 0.04)
			spSetUnitRulesParam(uid, "zdef_flight_roll", -0.46)

			-- Process any pending Armor airdrops from the single orbiting C-130 (Paratrooper drop temporarily disabled)
			for dIdx = #c130.pendingDrops, 1, -1 do
				local pd = c130.pendingDrops[dIdx]
				if frame >= pd.dropFrame then
					table.remove(c130.pendingDrops, dIdx)
					if pd.dtype == "para" then
						if ENABLE_C130_PARADROP then
							for p = 1, 6 do
								local row = math.floor((p - 1) / 2) - 1
								local col = ((p - 1) % 2) - 0.5
								local dpx, dpz = clampMap(pd.tx + row * 34 + math.random(-8, 8), pd.tz + col * 36 + math.random(-8, 8), 68)
								local dpy = spGetGroundHeight(dpx, dpz)
								local pid = spCreateUnit("zdef_paratrooper", dpx, dpy, dpz, 1, HUMAN_TEAM)
								if pid then
									local fx, fz = clampMap(pd.tx + 90 + row * 30, pd.tz + col * 40, 75)
									spGiveOrderToUnit(pid, CMD_FIGHT, { fx, spGetGroundHeight(fx, fz), fz }, {})
								end
							end
						end
					else
						local activeTanks, activeMraps = countActiveVehicleTypes()
						local vName = nil
						if activeTanks < MAX_ACTIVE_TANKS and (activeMraps >= MAX_ACTIVE_MRAPS or math.random(1, 100) <= 35) then
							vName = "zdef_tank"
						elseif activeMraps < MAX_ACTIVE_MRAPS then
							vName = "zdef_mrap"
						end
						if vName then
							local vx_d, vz_d = findNonOverlappingDropPos(pd.tx, pd.tz, 82, UDEF[vName])
							local vy_d = spGetGroundHeight(vx_d, vz_d)
							local vid = spCreateUnit(vName, vx_d, vy_d, vz_d, 1, HUMAN_TEAM)
							if vid then
								local targetSpot = spots[math.random(1, math.max(1, #spots))]
								if targetSpot then
									spGiveOrderToUnit(vid, CMD_MOVE, { targetSpot.x + math.random(-65, 65), targetSpot.y, targetSpot.z + math.random(-65, 65) }, {})
								end
							end
						else
							-- Cap already reached while payload was in transit: refund CP cleanly instead of spawning paratroopers
							commandPoints = commandPoints + PACKAGES.armor.cost
						end
					end
				end
			end

			-- Side-mounted 20mm M61 Vulcan & 105mm Howitzer engagement from the orbiting C-130 against zombies inside its orbit!
			local c130TargetX, c130TargetZ = nil, nil
			if #c130.pendingDrops > 0 then
				c130TargetX, c130TargetZ = c130.pendingDrops[1].tx, c130.pendingDrops[1].tz
			end
			if frame >= (c130.nextGatlingFrame or 0) then
				c130.nextGatlingFrame = frame + 9
				local nearZ = spGetUnitsInCylinder(c130.cx, c130.cz, 640) or {}
				local targetZID = nil
				for k = 1, #nearZ do
					local zdef = spGetUnitDefID(nearZ[k])
					if zdef and isZombieDef[zdef] then
						targetZID = nearZ[k]
						break
					end
				end
				if targetZID then
					local gx, gy, gz = spGetUnitPosition(targetZID)
					if gx then
						c130TargetX, c130TargetZ = gx, gz
						c130.lastLaserX, c130.lastLaserZ, c130.lastLaserFrame = gx, gz, frame
						local toTX, toTY, toTZ = gx - px, gy - py, gz - pz
						local toLen = math.max(1, math.sqrt(toTX * toTX + toTY * toTY + toTZ * toTZ))
						toTX, toTY, toTZ = toTX / toLen, toTY / toLen, toTZ / toLen
						spSpawnCEG("barrelshot-tiny", px + toTX * 14, py - 5, pz + toTZ * 14, toTX, toTY, toTZ, 14, 0)
						spSpawnCEG("genericshellexplosion-small", gx, gy + 4, gz, 0, 1, 0, 22, 0)
						launchZombiesInRadius(gx, gz, 52, 0.85, 0.65, 85, uid)

						-- Periodic 105mm Howitzer shell from side port (every 54 frames)
						if frame >= (c130.nextHowitzerFrame or 0) then
							c130.nextHowitzerFrame = frame + 54
							spSpawnCEG("barrelshot-large-impulse", px + toTX * 16, py - 6, pz + toTZ * 16, toTX, toTY, toTZ, 28, 0)
							spSpawnCEG("genericshellexplosion-large-bomb", gx, gy + 10, gz, 0, 1, 0, 80, 0)
							igniteTreesAndZombiesInRadius(gx, gz, 130, frame)
							launchZombiesInRadius(gx, gz, 135, 2.55, 1.85, 360, uid)
						end
					end
				end
			end
			if not c130TargetX and c130.lastLaserFrame and (frame - c130.lastLaserFrame) <= 24 then
				c130TargetX, c130TargetZ = c130.lastLaserX, c130.lastLaserZ
			end
			if c130TargetX and c130TargetZ then
				spSetUnitRulesParam(uid, "zdef_laser_active", 1)
				spSetUnitRulesParam(uid, "zdef_laser_tx", c130TargetX)
				spSetUnitRulesParam(uid, "zdef_laser_tz", c130TargetZ)
				spSetGameRulesParam("zdef_c130_mode", (#c130.pendingDrops > 0) and "AIRDROP" or "GUNSHIP")
			else
				spSetUnitRulesParam(uid, "zdef_laser_active", 0)
				spSetGameRulesParam("zdef_c130_mode", "ORBIT")
			end
		end
		spSetGameRulesParam("zdef_active_air_count", (persistentC130 and 1 or 0) + #activeAirMissions)

		-- 2. Update in-flight AGM Missiles & Dropped Cluster/Napalm Bombs from the F-16V Strike Fighter!
		for pIdx = #activeAirProjectiles, 1, -1 do
			local pr = activeAirProjectiles[pIdx]
			pr.x = pr.x + pr.vx
			pr.y = pr.y + pr.vy
			pr.z = pr.z + pr.vz
			if pr.ptype == "bomb" then
				pr.vy = pr.vy - 0.36 -- Gravity acceleration on free-fall bomb
				spSpawnCEG("fire-flames-small", pr.x, pr.y, pr.z, 0, 1, 0, 12, 0)
			else
				-- AGM Missile rocket motor trail
				spSpawnCEG("barrelshot-tiny", pr.x, pr.y, pr.z, -pr.vx, -pr.vy, -pr.vz, 16, 0)
			end
			local gY = spGetGroundHeight(clampMap(pr.x, pr.z, 16))
			if pr.y <= gY + 10 or (frame >= pr.maxFrame) then
				table.remove(activeAirProjectiles, pIdx)
				local ix, iz = clampMap(pr.x, pr.z, 48)
				local iy = spGetGroundHeight(ix, iz)
				if pr.ptype == "bomb" then
					spSpawnCEG("genericshellexplosion-large-bomb", ix, iy + 10, iz, 0, 1, 0, 95, 0)
					spSpawnCEG("fire-explosion-large", ix, iy + 12, iz, 0, 1, 0, 95, 0)
					spSpawnCEG("fire-area-75", ix, iy + 4, iz, 0, 1, 0, 75, 0)
					igniteTreesAndZombiesInRadius(ix, iz, 155, frame)
					launchZombiesInRadius(ix, iz, 145, 2.85, 2.10, 420, pr.ownerID)
					burnZones[#burnZones + 1] = {
						x = ix, y = iy, z = iz, radius = 105,
						expireFrame = frame + 240, nextTickFrame = frame + 25,
					}
				else
					spSpawnCEG("genericshellexplosion-medium-aoe", ix, iy + 8, iz, 0, 1, 0, 65, 0)
					spSpawnCEG("fire-explosion-medium", ix, iy + 8, iz, 0, 1, 0, 65, 0)
					igniteTreesAndZombiesInRadius(ix, iz, 115, frame)
					launchZombiesInRadius(ix, iz, 110, 2.15, 1.65, 310, pr.ownerID)
				end
			end
		end

		-- 3. Update active A-10 Trench Strafe & F-16V Dive Fighter Sorties
		for i = #activeAirMissions, 1, -1 do
			local m = activeAirMissions[i]
			local uid = m.unitID
			local elapsed = frame - m.startFrame

			if not uid or not spGetUnitHealth(uid) or elapsed >= m.totalFrames then
				if uid and spGetUnitHealth(uid) then
					spDestroyUnit(uid, false, true)
				end
				table.remove(activeAirMissions, i)
			else
				local px, py, pz = 0, 300, 0
				local vx, vy, vz = 10.0, 0, 0
				local pitchRad, rollRad = 0.0, 0.0
				local refY = m.refY or m.ty or 120
				local turnSign = m.turnSign or 1
				local dirX = m.dirX or 1.0
				local dirZ = m.dirZ or 0.0
				local perpX = -dirZ * turnSign
				local perpZ = dirX * turnSign

				if m.mtype == "a10" then
					-- ARCHETYPE 2: CƯỜNG KÍCH (A-10 Thunderbolt II — Low-Altitude Sweeping Trench Strafe / "Cày xới chiến trường"):
					-- Descends to low altitude (refY + 115) and plows a long 14-round stitched trench (~620 elmos!) of 30mm GAU-8 shells across the battlefield!
					if elapsed <= m.strikeFrames then
						local t = elapsed / math.max(1, m.strikeFrames)
						local distAlong = elapsed * m.speed
						px = m.startX + dirX * distAlong
						pz = m.startZ + dirZ * distAlong

						local s = t * t * (3.0 - 2.0 * t)
						py = refY + 280 - 165 * s
						pitchRad = -0.31 * math.sin(t * math.pi) -- -18 deg low-altitude strafing pitch
						rollRad = 0.0

						-- Plow a long 14-shot 30mm GAU-8 trench across the battlefield (t in [0.38, 0.98])
						-- Continuously sweep A-10's RED laser designator right along the advancing strafe line!
						if t >= 0.20 then
							local sweepStep = ((math.max(0.38, t) - 0.38) / 0.60 - 0.5) * (m.maxStrikes * 44)
							m.laserX, m.laserZ = clampMap(m.tx + dirX * sweepStep, m.tz + dirZ * sweepStep, 64)
						end
						if t >= 0.38 and m.strikesDone < m.maxStrikes then
							local expectedStrike = math.floor(((t - 0.38) / 0.60) * m.maxStrikes) + 1
							if expectedStrike > m.strikesDone then
								m.strikesDone = expectedStrike
								local step = m.strikesDone - (m.maxStrikes * 0.5)
								local sx, sz = clampMap(m.tx + dirX * (step * 44) + math.random(-14, 14), m.tz + dirZ * (step * 44) + math.random(-14, 14), 64)
								local sy = spGetGroundHeight(sx, sz)
								m.laserX, m.laserZ = sx, sz
								spSpawnCEG("barrelshot-medium", px + dirX * 18, py - 4, pz + dirZ * 18, dirX, -0.32, dirZ, 22, 0)
								spSpawnCEG("genericshellexplosion-medium-aoe", sx, sy + 6, sz, 0, 1, 0, 50, 0)
								spSpawnCEG("genericshellexplosion-debris2", sx, sy + 5, sz, 0, 1, 0, 45, 0)
								igniteTreesAndZombiesInRadius(sx, sz, 105, frame)
								launchZombiesInRadius(sx, sz, 105, 1.95, 1.50, 260, uid)
							end
						end
					else
						local egElapsed = elapsed - m.strikeFrames
						local t = egElapsed / math.max(1, m.egressFrames)
						local s = t * t * (3.0 - 2.0 * t)
						local forwardDist = egElapsed * m.speed
						local lateralDrift = 380 * (t * t)
						px = m.tx + dirX * forwardDist + perpX * lateralDrift
						pz = m.tz + dirZ * forwardDist + perpZ * lateralDrift
						py = refY + 115 + 310 * s
						pitchRad = 0.42 * math.sin(math.min(1.0, t * 1.3) * math.pi * 0.65)
						rollRad = -0.78 * turnSign * math.sin(t * math.pi)
					end

				elseif m.mtype == "fighter_dive" then
					-- ARCHETYPE 3: TIÊM KÍCH (F-16V Strike Fighter — High-Speed Steep Dive Missile & Bomb Strike / "Bổ nhào phóng tên lửa hoặc thả bom"):
					-- Dives steeply (-34 deg) from refY + 510 down to release point (refY + 235), launches 4 AGM missiles + drops 2 heavy bombs,
					-- then immediately pulls a high-G +38 deg climb & 62 deg afterburner breakaway turn!
					if elapsed <= m.diveFrames then
						local t = elapsed / math.max(1, m.diveFrames)
						local distAlong = elapsed * m.speed
						px = m.startX + dirX * distAlong
						pz = m.startZ + dirZ * distAlong

						local s = t * t * (3.0 - 2.0 * t)
						py = refY + 510 - 275 * s
						pitchRad = -0.60 * math.sin(t * math.pi * 0.88) -- Steep -34 deg attack dive!
						rollRad = 0.0

						-- At t >= 0.68 during dive, launch salvo of 4 AGM Missiles from wing pylons toward (tx, tz)!
						if t >= 0.68 and not m.missilesLaunched then
							m.missilesLaunched = true
							for k = 1, 4 do
								local side = ((k % 2 == 0) and 1 or -1) * (12 + k * 4)
								local mx0 = px + perpX * side
								local mz0 = pz + perpZ * side
								local my0 = py - 4
								local tx_m, tz_m = clampMap(m.tx + (k - 2.5) * 48, m.tz + ((k % 2) - 0.5) * 48, 60)
								local ty_m = spGetGroundHeight(tx_m, tz_m)
								local flightF = 11 + k * 2
								activeAirProjectiles[#activeAirProjectiles + 1] = {
									ptype = "missile",
									x = mx0, y = my0, z = mz0,
									vx = (tx_m - mx0) / flightF,
									vy = (ty_m - my0) / flightF,
									vz = (tz_m - mz0) / flightF,
									maxFrame = frame + flightF,
									ownerID = uid,
								}
							end
						end

						-- At t >= 0.92 (bottom of dive at releaseX, releaseZ), drop 2 Heavy Cluster/Napalm Bombs!
						if t >= 0.92 and not m.bombsDropped then
							m.bombsDropped = true
							for b = -1, 1, 2 do
								local bx0 = px + perpX * (b * 10)
								local bz0 = pz + perpZ * (b * 10)
								local by0 = py - 6
								local tx_b, tz_b = clampMap(m.tx + b * 42, m.tz - b * 32, 60)
								local ty_b = spGetGroundHeight(tx_b, tz_b)
								local flightF = 18
								activeAirProjectiles[#activeAirProjectiles + 1] = {
									ptype = "bomb",
									x = bx0, y = by0, z = bz0,
									vx = (tx_b - bx0) / flightF,
									vy = ((ty_b - by0) / flightF) + 0.18 * flightF,
									vz = (tz_b - bz0) / flightF,
									maxFrame = frame + flightF + 4,
									ownerID = uid,
								}
							end
						end
					else
						-- High-G pull-up climb (+38 deg pitch) & sharp 62-deg wing-bank afterburner breakaway!
						local egElapsed = elapsed - m.diveFrames
						local t = egElapsed / math.max(1, m.egressFrames)
						local s = t * t * (3.0 - 2.0 * t)
						local forwardDist = egElapsed * m.speed
						local lateralDrift = 540 * (t * t)
						px = m.releaseX + dirX * forwardDist + perpX * lateralDrift
						pz = m.releaseZ + dirZ * forwardDist + perpZ * lateralDrift
						py = refY + 235 + 420 * s
						pitchRad = 0.66 * math.sin(math.min(1.0, t * 1.35) * math.pi * 0.65)
						rollRad = -1.08 * turnSign * math.sin(t * math.pi)
					end
				end

				vx = px - (m.prevX or px)
				vy = py - (m.prevY or py)
				vz = pz - (m.prevZ or pz)
				m.prevX, m.prevY, m.prevZ = px, py, pz

				if mcSetPosition then
					mcSetPosition(uid, px, py, pz)
					mcSetVelocity(uid, vx, vy, vz)
					local hLen = math.sqrt(vx * vx + vz * vz)
					if hLen > 0.02 and spGetHeadingFromVector and mcSetHeading then
						mcSetHeading(uid, spGetHeadingFromVector(vx, vz))
					end
				end
				spSetUnitRulesParam(uid, "zdef_flight_pitch", pitchRad)
				spSetUnitRulesParam(uid, "zdef_flight_roll", rollRad)
				local isAttackingPhase = (m.mtype == "a10" and elapsed <= m.strikeFrames) or (m.mtype == "fighter_dive" and elapsed <= m.diveFrames)
				if isAttackingPhase and (m.laserX or m.tx) and (m.laserZ or m.tz) then
					spSetUnitRulesParam(uid, "zdef_laser_active", 1)
					spSetUnitRulesParam(uid, "zdef_laser_tx", m.laserX or m.tx)
					spSetUnitRulesParam(uid, "zdef_laser_tz", m.laserZ or m.tz)
				else
					spSetUnitRulesParam(uid, "zdef_laser_active", 0)
				end
			end
		end

		-- Update lingering Napalm / Fire burn zones from A-10 & explosions (every 15 frames, with CEG budget cap for silky 60+ FPS!)
		if frame % 15 == 0 then
			local fireCegBudget = 22
			for i = #burnZones, 1, -1 do
				local bz = burnZones[i]
				if frame >= bz.expireFrame then
					table.remove(burnZones, i)
				elseif frame >= bz.nextTickFrame then
					bz.nextTickFrame = frame + 30
					if fireCegBudget > 0 then
						fireCegBudget = fireCegBudget - 2
						spSpawnCEG("fire-burnground", bz.x, bz.y + 4, bz.z, 0, 1, 0, 45, 0)
						spSpawnCEG("fire-flames", bz.x, bz.y + 6, bz.z, 0, 1, 0, 40, 0)
					end
					local zlist = spGetUnitsInCylinder(bz.x, bz.z, bz.radius) or {}
					for k = 1, #zlist do
						local zid = zlist[k]
						local zdef = spGetUnitDefID(zid)
						if zdef and isZombieDef[zdef] then
							burningZombies[zid] = frame + 180
						end
					end
					launchZombiesInRadius(bz.x, bz.z, bz.radius, 0.35, 0.25, 65, hqUnitID)
				end
			end

			-- Burning Trees ignite nearby zombies (within 95 elmos)!
			for fid, tinfo in pairs(burningTrees) do
				if frame >= tinfo.expireFrame then
					burningTrees[fid] = nil
				else
					if fireCegBudget > 0 then
						fireCegBudget = fireCegBudget - 1
						spSpawnCEG("fire-flames-small", tinfo.x, tinfo.y + 16, tinfo.z, 0, 1, 0, 22, 0)
					end
					local nearUnits = spGetUnitsInCylinder(tinfo.x, tinfo.z, 95)
					if nearUnits then
						for k = 1, #nearUnits do
							local zid = nearUnits[k]
							local zdef = spGetUnitDefID(zid)
							if zdef and isZombieDef[zdef] then
								burningZombies[zid] = frame + 180
							end
						end
					end
				end
			end

			-- Process Burning Zombies (throttled CEG budget + fire DoT + contact spread)
			local spreadChecks = 0
			for zid, expFrame in pairs(burningZombies) do
				if frame >= expFrame or not activeZombies[zid] then
					burningZombies[zid] = nil
				else
					local zx, zy, zz = spGetUnitPosition(zid)
					if zx then
						if fireCegBudget > 0 then
							fireCegBudget = fireCegBudget - 1
							spSpawnCEG("fire-flames-small", zx, zy + 9, zz, 0, 1, 0, 16, 0)
						end
						local hp = spGetUnitHealth(zid)
						if hp then
							if hp <= 30 then
								spDestroyUnit(zid, false, false, hqUnitID)
							else
								spSetUnitHealth(zid, hp - 30)
							end
						end
						if spreadChecks < 16 then
							spreadChecks = spreadChecks + 1
							local touch = spGetUnitsInCylinder(zx, zz, 36)
							if touch then
								for k = 1, #touch do
									local nzid = touch[k]
									if nzid ~= zid and activeZombies[nzid] and not burningZombies[nzid] then
										burningZombies[nzid] = frame + 135
									end
								end
							end
						end
					end
				end
			end
		end
	end

	function gadget:FeatureCreated(featureID, allyTeam)
		if spGetFeatureDefID then
			local fdefID = spGetFeatureDefID(featureID)
			local fdef = fdefID and FeatureDefs[fdefID]
			if fdef and fdef.name and fdef.name:find("^zdef_zombie_") then
				zombieCorpses[featureID] = Spring.GetGameFrame() + 390 -- Lying zombie corpses stay on ground for 13s before cleanup
			end
		end
	end

	-- Authoritative zero-manual-control lock:
	-- Block 100% of direct FPS control AND all human-issued individual unit orders (Move, Attack, Fight, Patrol, Stop, Guard, Self-D, States),
	-- while preserving 100% of Synced Autonomous Military AI (fromSynced == true) and C++ CMobileCAI internal target engagements!
	function gadget:AllowDirectUnitControl(unitID, unitDefID, unitTeam, playerID)
		return false
	end

	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
		if (not fromSynced) and (not (cmdOptions and cmdOptions.internal)) and playerID and playerID >= 0 then
			return false
		end
		return true
	end

	local function restartOperation(frame)
		-- Cleanly reset battlefield for a fresh defense operation without leaving the engine!
		for zid in pairs(activeZombies) do
			spDestroyUnit(zid, false, true)
		end
		for mid in pairs(militaryUnits) do
			spDestroyUnit(mid, false, true)
		end
		for i = #activeAirMissions, 1, -1 do
			local m = activeAirMissions[i]
			if m.unitID and spGetUnitHealth(m.unitID) then
				spDestroyUnit(m.unitID, false, true)
			end
			activeAirMissions[i] = nil
		end
		activeAirProjectiles = {}
		pendingInfections = {}
		burnZones = {}
		burningTrees = {}
		burningZombies = {}
		doomedAirborneZombies = {}
		if hqUnitID and spGetUnitHealth(hqUnitID) then
			spDestroyUnit(hqUnitID, false, true)
		end
		hqUnitID = nil
		commandPoints = 220
		totalZombiesKilled = 0
		totalSoldiersInfected = 0
		totalAirSorties = 0
		currentWaveNum = 1
		prevSurgeState = false
		gameOverState = false
		hqLastDamagedFrame = -9999
		for _, pkg in pairs(PACKAGES) do
			pkg.lastFrame = -9999
		end
		for i, s in ipairs(spots) do
			s.owner = (i == 1) and 1 or 0
			s.capture = (i == 1) and 100 or 0
			s.contested = false
			spSetGameRulesParam("zdef_spot_owner_" .. i, s.owner)
			spSetGameRulesParam("zdef_spot_capture_" .. i, s.capture)
			spSetGameRulesParam("zdef_spot_contested_" .. i, 0)
		end
		spSetGameRulesParam("zdef_zombies_killed", 0)
		spSetGameRulesParam("zdef_soldiers_infected", 0)
		spSetGameRulesParam("zdef_air_sorties", 0)
		spSetGameRulesParam("zdef_wave_num", 1)
		spSetGameRulesParam("zdef_game_over", 0)
		spSetGameRulesParam("zdef_hq_under_attack", 0)
		spSetGameRulesParam("zdef_command_points", 220)
		lastHqInfRallyFrame = -9999

		-- Respawn HQ + Fresh Defense Force at Map StartPos on verified flat, passable terrain
		local hqY = spGetGroundHeight(hqX, hqZ)
		hqUnitID = spCreateUnit("zdef_hq", hqX, hqY, hqZ, 1, HUMAN_TEAM)
		if hqUnitID then
			spSetGameRulesParam("zdef_hq_id", hqUnitID)
			spSetGameRulesParam("zdef_hq_hp", 15000)
			spSetGameRulesParam("zdef_hq_maxhp", 15000)
		end
		local fdx = (enemyStartX or (mapSizeX * 0.5)) - hqX
		local fdz = (enemyStartZ or (mapSizeZ * 0.5)) - hqZ
		local fLen = math.max(1.0, math.sqrt(fdx * fdx + fdz * fdz))
		local fwdX, fwdZ = fdx / fLen, fdz / fLen
		local sideX, sideZ = -fwdZ, fwdX
		for i = 1, 12 do
			local ring = (i <= 6) and 130 or 175
			local angle = ((i - 1) % 6) / 6 * math.pi * 2 + ((i > 6) and 0.52 or 0)
			local sx, sz = findNonOverlappingDropPos(hqX + math.cos(angle) * ring, hqZ + math.sin(angle) * ring, 26, UDEF.zdef_infantry)
			local uid = spCreateUnit("zdef_infantry", sx, spGetGroundHeight(sx, sz), sz, 1, HUMAN_TEAM)
			if uid and spots[1] then
				spGiveOrderToUnit(uid, CMD_FIGHT, { spots[1].x + math.cos(angle) * 55, spots[1].y, spots[1].z + math.sin(angle) * 55 }, {})
			end
		end
		local mx, mz = findNonOverlappingDropPos(hqX + fwdX * 175 + sideX * 105, hqZ + fwdZ * 175 + sideZ * 105, 85, UDEF.zdef_mrap)
		local mrapID = spCreateUnit("zdef_mrap", mx, spGetGroundHeight(mx, mz), mz, 1, HUMAN_TEAM)
		if mrapID and spots[2] then
			spGiveOrderToUnit(mrapID, CMD_MOVE, { spots[2].x, spots[2].y, spots[2].z }, {})
		end
		local tx, tz = findNonOverlappingDropPos(hqX + fwdX * 195 - sideX * 105, hqZ + fwdZ * 195 - sideZ * 105, 90, UDEF.zdef_tank)
		local tankID = spCreateUnit("zdef_tank", tx, spGetGroundHeight(tx, tz), tz, 1, HUMAN_TEAM)
		if tankID and spots[1] then
			spGiveOrderToUnit(tankID, CMD_MOVE, { spots[1].x + 55, spots[1].y, spots[1].z }, {})
		end
		ensureSingleOrbitingC130()
		pushTacticalAlert("ĐÃ KHỞI ĐỘNG LẠI CHIẾN DỊCH PHÒNG THỦ!", "good", frame)
	end

	function gadget:GameFrame(frame)
		-- Execute guaranteed death on landing for airborne-launched zombies & clean up old zombie corpses
		if frame % 5 == 0 then
			for uid, dinfo in pairs(doomedAirborneZombies) do
				if frame >= dinfo.killFrame then
					doomedAirborneZombies[uid] = nil
					if activeZombies[uid] then
						spDestroyUnit(uid, false, false, dinfo.attackerID)
					end
				end
			end
		end
		if frame % 30 == 0 and spDestroyFeature then
			for fid, expFrame in pairs(zombieCorpses) do
				if frame >= expFrame then
					zombieCorpses[fid] = nil
					spDestroyFeature(fid)
				end
			end
		end
		-- Update aerodynamic aircraft flight trajectories every single frame (30 Hz) for smooth continuous motion!
		updateAirMissions(frame)
		if frame % 30 == 0 then
			local capturedCount = updateSpotsAndEconomy(frame)
			updateContinuousZombies(frame)
			spSetGameRulesParam("zdef_zombie_count", activeZombieCount)
			if frame % 60 == 0 then
				updateAutonomousMilitaryAI(frame, capturedCount)
			end
		end
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if not msg then return end
		local frame = Spring.GetGameFrame()
		if msg == "zdef_restart_op" then
			restartOperation(frame)
		elseif msg == "zdef_gfx_spots:0" or msg == "zdef_gfx_spots:1" then
			local v = (msg == "zdef_gfx_spots:1") and 1 or 0
			spSetGameRulesParam("zdef_gfx_spots", v)
		elseif msg == "zdef_gfx_ceg:0" or msg == "zdef_gfx_ceg:1" then
			cegFxEnabled = (msg == "zdef_gfx_ceg:1")
			spSetGameRulesParam("zdef_gfx_ceg", cegFxEnabled and 1 or 0)
		elseif msg == "zdef_toggle_auto" then
			autoSupportEnabled = not autoSupportEnabled
			spSetGameRulesParam("zdef_auto_support", autoSupportEnabled and 1 or 0)
			pushTacticalAlert("AUTO-SUPPORT AI: " .. (autoSupportEnabled and "BẬT (TỰ ĐỘNG)" or "TẮT (THỦ CÔNG)"), "info", frame)
			spEcho("[ZOMBIE DEFENSE] Auto-Support is now: " .. (autoSupportEnabled and "ON (Default)" or "OFF (Manual)"))
		elseif msg == "zdef_toggle_sight" then
			fullSightEnabled = not fullSightEnabled
			if Spring.SetGlobalLos then
				Spring.SetGlobalLos(0, fullSightEnabled)
			end
			spSetGameRulesParam("zdef_full_sight", fullSightEnabled and 1 or 0)
			pushTacticalAlert("TẦM NHÌN VỆ TINH: " .. (fullSightEnabled and "TOÀN BẢN ĐỒ" or "SƯƠNG MÙ CHIẾN TRẬN"), "info", frame)
			spEcho("[ZOMBIE DEFENSE] Full Map Sight is now: " .. (fullSightEnabled and "ON (Full Map Visible)" or "OFF (Fog of War)"))
		elseif msg:find("^zdef_call_") then
			-- Support both "zdef_call_para" and targeted "zdef_call_para:1850:2100"
			local pkgKey, coordX, coordZ = msg:match("^zdef_call_([%a%d_]+):([%-%d%.]+):([%-%d%.]+)$")
			if pkgKey and coordX and coordZ then
				local tx, tz = clampMap(tonumber(coordX) or (hqX + 260), tonumber(coordZ) or hqZ, 120)
				executeSupportPackage(pkgKey, tx, tz, frame, false)
			else
				pkgKey = msg:gsub("^zdef_call_", "")
				-- Pick best target location for instant hotkey/button press
				local tx, tz = hqX + 260, hqZ
				for _, s in ipairs(spots) do
					if s.contested or (pkgKey == "para" and s.owner == 0) then
						tx, tz = s.x, s.z
						break
					end
				end
				executeSupportPackage(pkgKey, tx, tz, frame, false)
			end
		end
	end

else
	--------------------------------------------------------------------------------
	-- UNSYNCED: Draw 3D Strategic Spot Capture Circles & Squad AI State Badges
	--------------------------------------------------------------------------------
	local spGetGameRulesParam = Spring.GetGameRulesParam
	local spGetUnitRulesParam = Spring.GetUnitRulesParam
	local spGetUnitViewPosition = Spring.GetUnitViewPosition
	local spGetAllUnits = Spring.GetAllUnits
	local spGetGroundHeight = Spring.GetGroundHeight
	local glColor = gl.Color
	local glDrawGroundCircle = gl.DrawGroundCircle
	local glPushMatrix = gl.PushMatrix
	local glTranslate = gl.Translate
	local glBillboard = gl.Billboard
	local glText = gl.Text
	local glPopMatrix = gl.PopMatrix

	function gadget:DrawWorldPreUnit()
		if (spGetGameRulesParam("zdef_gfx_spots") or 1) == 0 then
			return
		end
		local count = spGetGameRulesParam("zdef_spot_count") or 0
		for i = 1, count do
			local sx = spGetGameRulesParam("zdef_spot_x_" .. i)
			local sz = spGetGameRulesParam("zdef_spot_z_" .. i)
			local owner = spGetGameRulesParam("zdef_spot_owner_" .. i) or 0
			local contested = spGetGameRulesParam("zdef_spot_contested_" .. i) or 0
			local capture = spGetGameRulesParam("zdef_spot_capture_" .. i) or 0
			if sx and sz then
				local sy = spGetGroundHeight(sx, sz)
				if contested == 1 then
					glColor(1.0, 0.58, 0.12, 0.88)
				elseif owner == 1 then
					glColor(0.18, 0.78, 1.0, 0.80)
				else
					glColor(0.70, 0.74, 0.80, 0.45)
				end
				glDrawGroundCircle(sx, sy, sz, 180, 36)
				if owner == 1 or capture > 0 then
					glDrawGroundCircle(sx, sy, sz, 180 * math.max(0.15, capture / 100.0), 28)
				end
			end
		end
		glColor(1, 1, 1, 1)
	end

	function gadget:DrawWorld()
		if (spGetGameRulesParam("zdef_gfx_spots") or 1) == 0 then
			return
		end
		local count = spGetGameRulesParam("zdef_spot_count") or 0
		for i = 1, count do
			local sx = spGetGameRulesParam("zdef_spot_x_" .. i)
			local sz = spGetGameRulesParam("zdef_spot_z_" .. i)
			local owner = spGetGameRulesParam("zdef_spot_owner_" .. i) or 0
			local contested = spGetGameRulesParam("zdef_spot_contested_" .. i) or 0
			local capture = spGetGameRulesParam("zdef_spot_capture_" .. i) or 0
			if sx and sz then
				local sy = spGetGroundHeight(sx, sz)
				glPushMatrix()
				glTranslate(sx, sy + 42, sz)
				glBillboard()
				local statusStr
				if contested == 1 then
					statusStr = string.format("\255\255\150\50[SPOT #%d — CONTESTED %d%%]", i, capture)
				elseif owner == 1 then
					statusStr = string.format("\255\95\225\255[SPOT #%d — SECURED +3.5 CP/s]", i)
				else
					statusStr = string.format("\255\195\205\215[SPOT #%d — NEUTRAL %d%%]", i, capture)
				end
				glText(statusStr, 0, 0, 11.5, "co")
				glPopMatrix()
			end
		end
	end
end
