
function widget:GetInfo()
	return {
		name      = "Light Effects",
		version   = 4,
		desc      = "Creates projectile, laser and explosion lights and sends them to the deferred renderer.",
		author    = "Floris (original by beherith)",
		date      = "May 2017",
		license   = "GPL V2",
		layer     = 0,
		enabled   = true,
	}
end

local spGetProjectilesInRectangle	= Spring.GetProjectilesInRectangle
local spGetVisibleProjectiles		= Spring.GetVisibleProjectiles
local spGetProjectilePosition		= Spring.GetProjectilePosition
local spGetProjectileType			= Spring.GetProjectileType
local spGetProjectileDefID			= Spring.GetProjectileDefID
local spGetProjectileVelocity		= Spring.GetProjectileVelocity
local spGetProjectileDirection		= Spring.GetProjectileDirection
local spGetProjectileTimeToLive		= Spring.GetProjectileTimeToLive
local spGetPieceProjectileParams	= Spring.GetPieceProjectileParams
local spGetGroundHeight				= Spring.GetGroundHeight
local spIsSphereInView				= Spring.IsSphereInView
local spGetGameFrame				= Spring.GetGameFrame

local math_random = math.random
local math_diag = math.diag
local math_min = math.min
local math_max = math.max
local math_floor = math.floor

-- Local Variables
local previousProjectileDrawParams
local fadeProjectiles, fadeProjectileTimes = {}, {}

--------------------------------------------------------------------------------
-- Config
--------------------------------------------------------------------------------

local useLOD = false		-- Reduces the number of lights drawn based on camera distance and current fps.
local projectileFade = true
local FADE_TIME = 5

local overrideParam = {r = 1, g = 1, b = 1, radius = 200}
local doOverride = false

local globalLightMult = 1.5
local globalRadiusMult = 1.4
local globalLightMultLaser = 1.35	-- gets applied on top op globalRadiusMult
local globalRadiusMultLaser = 0.9	-- gets applied on top op globalRadiusMult
local globalLifeMult = 0.55

local enableHeatDistortion = true
local enableNanolaser = true
local enableThrusters = true
local nanolaserLights = {}
local thrusterLights = {}

local gibParams = {r = 0.145*globalLightMult, g = 0.1*globalLightMult, b = 0.05*globalLightMult, radius = 75*globalRadiusMult, gib = true}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local projectileLightTypes = {}
--[1] red
--[2] green
--[3] blue
--[4] radius
--[5] BEAMTYPE, true if BEAM

local explosionLightsCount = 0
local explosionLights = {}

local customBeamLightsCount = 0
local customBeamLights = {}

local deferredFunctionID

local weaponConf = {}
local function loadWeaponDefs()
	weaponConf = {}
	for i=1, #WeaponDefs do
		local customParams = WeaponDefs[i].customParams or {}
		if customParams.expl_light_skip == nil then
			local params = {}
			--local maxDamage = 0
			--for armortype, value in pairs(WeaponDefs[i].damages) do
			--	maxDamage = math.max(maxDamage, value)
			--end
			--local dmgBonus = math.sqrt(math.sqrt(math.sqrt(maxDamage)))
			local damage = 100
			for cat=0, #WeaponDefs[i].damages do
				if Game.armorTypes[cat] and Game.armorTypes[cat] == 'default' then
					damage = WeaponDefs[i].damages[cat]
					break
				end
			end
			params.radius = ((WeaponDefs[i].damageAreaOfEffect*2) + (WeaponDefs[i].damageAreaOfEffect * WeaponDefs[i].edgeEffectiveness * 1.25)) * globalRadiusMult
			params.orgMult = (math.max(0.25, math.min(damage/1600, 0.6)) + (params.radius/2800)) * globalLightMult
			params.life = (9.5*(1.0+params.radius/2500)+(params.orgMult * 5)) * globalLifeMult
			params.radius = (params.orgMult * 75) + (params.radius * 2.4)
			params.r, params.g, params.b = 1, 0.8, 0.45

			if customParams.expl_light_color then
				local colorList = string.split(customParams.expl_light_color, " ")
				params.r = colorList[1]
				params.g = colorList[2]
				params.b = colorList[3]
			elseif WeaponDefs[i].visuals ~= nil and WeaponDefs[i].visuals.colorR ~= nil then
				params.r = WeaponDefs[i].visuals.colorR
				params.g = WeaponDefs[i].visuals.colorG
				params.b = WeaponDefs[i].visuals.colorB
			end

			if customParams.expl_light_opacity ~= nil then
				params.orgMult = customParams.expl_light_opacity * globalLightMult
			end

			if customParams.expl_light_nuke ~= nil then
				params.nuke = true
			end

			if customParams.expl_light_mult ~= nil then
				params.orgMult = params.orgMult * customParams.expl_light_mult
			end

			if customParams.expl_light_radius then
				params.radius = tonumber(customParams.expl_light_radius) * globalRadiusMult
			end
			if customParams.expl_light_radius_mult then
				params.radius = params.radius * tonumber(customParams.expl_light_radius_mult)
			end

			params.heatradius = (WeaponDefs[i].damageAreaOfEffect*0.6)

			if customParams.expl_light_heat_radius then
				params.heatradius = tonumber(customParams.expl_light_heat_radius) * globalRadiusMult
			end
			if customParams.expl_light_heat_radius_mult then
				params.heatradius = (params.heatradius * tonumber(customParams.expl_light_heat_radius_mult))
			end

			params.heatlife = (7*(0.8+ params.heatradius/1200)) + (params.heatradius/4)

			if customParams.expl_light_heat_life_mult then
				params.heatlife = params.heatlife * tonumber(customParams.expl_light_heat_life_mult)
			end

			params.heatstrength = math_min(3, 0.8 + (params.heatradius/50))

			if customParams.expl_light_heat_strength_mult then
				params.heatstrength = params.heatstrength * customParams.expl_light_heat_strength_mult
			end
			if customParams.expl_noheatdistortion then
				params.noheatdistortion = true
			end

			if customParams.expl_light_life then
				params.life = tonumber(customParams.expl_light_life)
			end
			if customParams.expl_light_life_mult then
				params.life = params.life * tonumber(customParams.expl_light_life_mult)
			end
			if WeaponDefs[i].paralyzer then
				params.type = 'paralyzer'
			end
			if WeaponDefs[i].type == 'Flame' then
				params.type = 'flame'
				params.radius = params.radius * 0.66
				params.orgMult = params.orgMult * 0.90
			end
			params.wtype = WeaponDefs[i].type
			if params.wtype == 'Cannon' then
				params.cannonsize = WeaponDefs[i].size
			end

			params.yoffset = 15 + (params.radius/35)

			if WeaponDefs[i].type == 'BeamLaser' then
				if not WeaponDefs[i].paralyzer then
					params.noheatdistortion = true
				end
				params.life = 1
				damage = damage/WeaponDefs[i].beamtime
				params.radius = (params.radius*3) + (damage/150)
				params.orgMult = math.min(0.6, (0.15 + (damage/5000))) * globalLightMult
				params.yoffset = 6 + (params.radius/700)
				if params.yoffset > 25 then params.yoffset = 25 end
			end

			weaponConf[i] = params
		end
	end
end
loadWeaponDefs()

--------------------------------------------------------------------------------
-- Light Defs
--------------------------------------------------------------------------------

local function GetLightsFromUnitDefs()
	--Spring.Echo('GetLightsFromUnitDefs init')
	local plighttable = {}
	for weaponDefID = 1, #WeaponDefs do
		--These projectiles should have lights:
		--Cannon (projectile size: tempsize = 2.0f + std::min(wd.customParams.shield_damage * 0.0025f, wd.damageAreaOfEffect * 0.1f);)
		--Dgun
		--MissileLauncher
		--StarburstLauncher
		--LaserCannon
		--LightningCannon
		--BeamLaser
		--Flame
		--Shouldnt:
		--AircraftBomb
		--Shield
		--TorpedoLauncher
		local weaponDef = WeaponDefs[weaponDefID]

		local customParams = weaponDef.customParams or {}

		local skip = false
		if customParams.light_skip ~= nil and customParams.light_skip then
			skip = true
		end

		local lightMultiplier = 0.07
		local bMult = 1		-- because blue appears to be very faint
		local r,g,b = weaponDef.visuals.colorR, weaponDef.visuals.colorG, weaponDef.visuals.colorB*bMult

		local weaponData = {type=weaponDef.type, r = (r + 0.1) * lightMultiplier, g = (g + 0.1) * lightMultiplier, b = (b + 0.1) * lightMultiplier, radius = 100}
		local recalcRGB = false

		if weaponDef.type == 'Cannon' then
			if customParams.single_hit then
				weaponData.beamOffset = 1
				weaponData.beam = true
			else
				weaponData.radius = 120 * weaponDef.size
				if weaponDef.damageAreaOfEffect ~= nil  then
					weaponData.radius = 120 * ((weaponDef.size*0.4) + (weaponDef.damageAreaOfEffect * 0.025))
				end
				lightMultiplier = 0.02 * ((weaponDef.size*0.66) + (weaponDef.damageAreaOfEffect * 0.012))
				if lightMultiplier > 0.08 then
					lightMultiplier = 0.08
				end
				recalcRGB = true
			end
		elseif weaponDef.type == 'LaserCannon' then
			weaponData.radius = 70 * weaponDef.size
		elseif weaponDef.type == 'DGun' then
			weaponData.radius = 365
			lightMultiplier = 0.7
		elseif weaponDef.type == 'MissileLauncher' then
			weaponData.radius = 125 * weaponDef.size
			if weaponDef.damageAreaOfEffect ~= nil  then
				weaponData.radius = 125 * (weaponDef.size + (weaponDef.damageAreaOfEffect * 0.01))
			end
			lightMultiplier = 0.01 + (weaponDef.size/55)
			recalcRGB = true
		elseif weaponDef.type == 'StarburstLauncher' then
			weaponData.radius = 250
			weaponData.radius1 = weaponData.radius
			weaponData.radius2 = weaponData.radius*0.6
		elseif weaponDef.type == 'Flame' then
			weaponData.radius = 70 * weaponDef.size
			lightMultiplier = 0.07
			recalcRGB = true
			--skip = true
		elseif weaponDef.type == 'LightningCannon' then
			weaponData.radius = 70 * weaponDef.size
			weaponData.beam = true
		elseif weaponDef.type == 'BeamLaser' then
			weaponData.radius = 16 * (weaponDef.size * weaponDef.size * weaponDef.size)
			weaponData.beam = true
			if weaponDef.beamTTL > 2 then
				weaponData.fadeTime = weaponDef.beamTTL
				weaponData.fadeOffset = 0
			end
		end

		if customParams.light_opacity then
			lightMultiplier = customParams.light_opacity
		end
		if customParams.light_mult ~= nil then
			recalcRGB = true
			lightMultiplier = lightMultiplier * tonumber(customParams.light_mult)
		end

		-- For long lasers or projectiles
		if customParams.light_beam_mult then
			weaponData.beamOffset = 1
			weaponData.beam = true
			weaponData.beamMult = tonumber(customParams.light_beam_mult)
			weaponData.beamMultFrames = tonumber(customParams.light_beam_mult_frames)
		end

		if customParams.light_fade_time and customParams.light_fade_offset then
			weaponData.fadeTime = tonumber(customParams.light_fade_time)
			weaponData.fadeOffset = tonumber(customParams.light_fade_offset)
		end

		if customParams.light_radius then
			weaponData.radius = tonumber(customParams.light_radius)
		end

		if customParams.light_radius_mult then
			weaponData.radius = weaponData.radius * tonumber(customParams.light_radius_mult)
			if weaponData.radius1 and weaponData.radius2 then
				weaponData.radius1 = weaponData.radius * tonumber(customParams.light_radius_mult)
				weaponData.radius2 = weaponData.radius * tonumber(customParams.light_radius_mult)
			end
		end

		if customParams.light_ground_height then
			weaponData.groundHeightLimit = tonumber(customParams.light_ground_height)
		end

		if customParams.light_camera_height then
			weaponData.cameraHeightLimit = tonumber(customParams.light_camera_height)
		end

		if customParams.light_beam_start then
			weaponData.beamStartOffset = tonumber(customParams.light_beam_start)
		end

		if customParams.light_beam_offset then
			weaponData.beamOffset = tonumber(customParams.light_beam_offset)
		end

		if customParams.light_color then
			local colorList = string.split(customParams.light_color, " ")
			r = colorList[1]
			g = colorList[2]
			b = colorList[3]*bMult
		end

		if recalcRGB or globalLightMult ~= 1 or globalLightMultLaser ~= 1 then
			local laserMult = 1
			if (weaponDef.type == 'BeamLaser' or weaponDef.type == 'LightningCannon' or weaponDef.type ==  'LaserCannon') then
				laserMult = globalLightMultLaser
			end
			weaponData.r = (r + 0.1) * lightMultiplier * globalLightMult * laserMult
			weaponData.g = (g + 0.1) * lightMultiplier * globalLightMult * laserMult
			weaponData.b = (b + 0.1) * lightMultiplier*bMult * globalLightMult * laserMult
		end


		if (weaponDef.type == 'Cannon') then
			weaponData.glowradius = weaponData.radius
		end

		weaponData.radius = weaponData.radius * globalRadiusMult
		if (weaponDef.type == 'BeamLaser' or weaponDef.type == 'LightningCannon' or weaponDef.type ==  'LaserCannon') then
			weaponData.radius = weaponData.radius * globalRadiusMultLaser
		end


		if not skip and weaponData ~= nil and weaponData.radius > 0 and customParams.fake_weapon == nil then

			plighttable[weaponDefID] = weaponData
		end
	end

	return plighttable
end




--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utilities

local function InterpolateBeam(x, y, z, dx, dy, dz)
	local finalDx, finalDy, finalDz = 0, 0, 0
	for i = 1, 10 do
		local h = spGetGroundHeight(x + dx + finalDx, z + dz + finalDz)
		local mult
		dx, dy, dz = dx*0.5, dy*0.5, dz*0.5
		if h < y + dy + finalDy then
			finalDx, finalDy, finalDz = finalDx + dx, finalDy + dy, finalDz + dz
		end
	end
	return finalDx, finalDy, finalDz
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Projectile Collection

local function GetCameraHeight()
	local camX, camY, camZ = Spring.GetCameraPosition()
	return camY - math_max(spGetGroundHeight(camX, camZ), 0)
end

local function ProjectileLevelOfDetailCheck(param, proID, fps, height)
	if param.cameraHeightLimit and param.cameraHeightLimit < height then
		if param.cameraHeightLimit*3 > height then
			local fraction = param.cameraHeightLimit/height
			if fps < 60 then
				fraction = fraction*fps/60
			end
			local ratio = 1/fraction
			return (proID%ratio < 1)
		else
			return false
		end
	end

	if param.beam then
		return true
	end

	if fps < 60 then
		local fraction = fps/60
		local ratio = 1/fraction
		return (proID%ratio < 1)
	end
	return true
end

local function GetBeamLights(lightParams, pID, x, y, z)
	local deltax, deltay, deltaz = spGetProjectileVelocity(pID) -- for beam types, this returns the endpoint of the beam]
	local timeToLive

	if lightParams.beamMult then
		local mult = lightParams.beamMult
		if lightParams.beamMultFrames then
			timeToLive = timeToLive or spGetProjectileTimeToLive(pID)
			if not lightParams.maxTTL or lightParams.maxTTL < timeToLive then
				lightParams.maxTTL = timeToLive
			end
			mult = mult * (1 - math_min(1, (timeToLive - (lightParams.maxTTL - lightParams.beamMultFrames))/lightParams.beamMultFrames))
		end
		deltax, deltay, deltaz = mult*deltax, mult*deltay, mult*deltaz
	end

	if y + deltay < -800 then
		-- The beam has fallen through the world
		deltax, deltay, deltaz = InterpolateBeam(x, y, z, deltax, deltay, deltaz)
	end

	if lightParams.beamOffset then
		local m = lightParams.beamOffset
		x, y, z = x - deltax*m, y - deltay*m, z - deltaz*m
	end
	if lightParams.beamStartOffset then
		local m = lightParams.beamStartOffset
		x, y, z = x + deltax*m, y + deltay*m, z + deltaz*m
		deltax, deltay, deltaz = deltax*(1 - m), deltay*(1 - m), deltaz*(1 - m)
	end

	local light = {
		pID = pID,
		px = x, py = y, pz = z,
		dx = deltax, dy = deltay, dz = deltaz,
		param = (doOverride and overrideParam) or lightParams,
		beam = true
	}

	if lightParams.fadeTime then
		timeToLive = timeToLive or spGetProjectileTimeToLive(pID)
		light.colMult = math_max(0, (timeToLive + lightParams.fadeOffset)/lightParams.fadeTime)
	else
		light.colMult = 1
	end

	return light
end

local function GetProjectileLight(lightParams, pID, x, y, z)
	local light = {
		pID = pID,
		px = x, py = y, pz = z,
		param = (doOverride and overrideParam) or lightParams
	}
	-- Use the following to check heatray fadeout parameters.
	--local timeToLive = spGetProjectileTimeToLive(pID)
	--Spring.MarkerAddPoint(x,y,z,timeToLive)

	if lightParams.fadeTime and lightParams.fadeOffset then
		local timeToLive = spGetProjectileTimeToLive(pID)
		light.colMult = math_max(0, (timeToLive + lightParams.fadeOffset)/lightParams.fadeTime)
	else
		light.colMult = 1
	end

	return light
end

local function GetProjectileLights(beamLights, beamLightCount, pointLights, pointLightCount)
	local cx, cy, cz = Spring.GetCameraPosition()

	local projectiles = spGetVisibleProjectiles()
	local projectileCount = #projectiles
	if not projectileFade and projectileCount == 0 then
		return beamLights, beamLightCount, pointLights, pointLightCount
	end

	local fps = Spring.GetFPS()
	local cameraHeight = math_floor(GetCameraHeight()*0.01)*100
	--Spring.Echo("cameraHeight", cameraHeight, "fps", fps)
	local projectilePresent = {}
	local projectileDrawParams = projectileFade and {}

	for i = 1, projectileCount do
		local pID = projectiles[i]
		local x, y, z = spGetProjectilePosition(pID)
		--Spring.Echo("projectilepos = ", x, y, z, 'id', pID)
		projectilePresent[pID] = true
		local weapon, piece = spGetProjectileType(pID)
		if piece then
			local explosionflags = spGetPieceProjectileParams(pID)
			if explosionflags and explosionflags%32 > 15 then --only stuff with the FIRE explode tag gets a light
				--Spring.Echo('explosionflag = ', explosionflags)
				local drawParams = {pID = pID, px = x, py = y, pz = z, param = (doOverride and overrideParam) or gibParams, colMult = 1}
				if drawParams.param.gib == true or drawParams.param.gib == nil then
					pointLightCount = pointLightCount + 1
					pointLights[pointLightCount] = drawParams
					if projectileDrawParams then
						projectileDrawParams[#projectileDrawParams + 1] = drawParams
					end
				end
			end
		else
			local lightParams = projectileLightTypes[spGetProjectileDefID(pID)]
			if lightParams and (not useLOD or ProjectileLevelOfDetailCheck(lightParams, pID, fps, cameraHeight)) then
				if lightParams.beam then --BEAM type
					local drawParams = GetBeamLights(lightParams, pID, x, y, z)
					beamLightCount = beamLightCount + 1
					beamLights[beamLightCount] = drawParams
					if projectileDrawParams then
						-- Don't add beams (for now?)
						--projectileDrawParams[#projectileDrawParams + 1] = drawParams
					end
				else -- point type
					if not (lightParams.groundHeightLimit and lightParams.groundHeightLimit < (y - math_max(spGetGroundHeight(y, y), 0))) then
						local drawParams = GetProjectileLight(lightParams, pID, x, y, z)
						if lightParams.radius2 ~= nil then
							local dirX,dirY,dirZ = spGetProjectileDirection(pID)
							if dirX == 0 and dirZ == 0 then
								drawParams.param.radius = lightParams.radius1
							else
								drawParams.param.radius = lightParams.radius2
							end
						end
						pointLightCount = pointLightCount + 1
						pointLights[pointLightCount] = drawParams
						if projectileDrawParams then
							projectileDrawParams[#projectileDrawParams + 1] = drawParams
						end
						--if enableHeatDistortion and WG['Lups'] then
						--	local weaponDefID = spGetProjectileDefID(pID)
						--	if weaponDefID and weaponConf[weaponDefID] and not weaponConf[weaponDefID].noheatdistortion and spIsSphereInView(x,y,z,100) then
						--		if weaponConf[weaponDefID].wtype == 'DGun' then
						--			local distance = math_diag(x-cx, y-cy, z-cz)
						--			local strengthMult = 1 / (distance*0.001)
						--
						--			WG['Lups'].AddParticles('JitterParticles2', {
						--				layer = -35,
						--				life = weaponConf[weaponDefID].heatlife,
						--				pos = {x,y,z},
						--				size = weaponConf[weaponDefID].heatradius*3.5,
						--				sizeGrowth = 0.2,
						--				strength = (weaponConf[weaponDefID].heatstrength*1.25)*strengthMult,
						--				animSpeed = 1.3,
						--				heat = 1,
						--				force = {0,0.35,0},
						--			})
						--		end
						--	end
						--end
					end
				end
			end
		end
	end

	local frame = spGetGameFrame()

	-- note sure why this was done, but when paused, and camera was moved it added additional lights on top of lights
	--if projectileFade then
	--	if previousProjectileDrawParams then
	--		for i = 1, #previousProjectileDrawParams do
	--			local pID = previousProjectileDrawParams[i].pID
	--			if not projectilePresent[pID] then
	--				local params = previousProjectileDrawParams[i]
	--				params.startColMul = params.colMul or 1
	--				params.py = params.py + 10
	--				fadeProjectiles[#fadeProjectiles + 1] = params
	--				fadeProjectileTimes[#fadeProjectileTimes + 1] = frame + FADE_TIME
	--			end
	--		end
	--	end
	--
	--	local i = 1
	--	while i <= #fadeProjectiles do
	--		local strength = (fadeProjectileTimes[i] - frame)/FADE_TIME
	--		if strength <= 0 then
	--			fadeProjectileTimes[i] = fadeProjectileTimes[#fadeProjectileTimes]
	--			fadeProjectileTimes[#fadeProjectileTimes] = nil
	--			fadeProjectiles[i] = fadeProjectiles[#fadeProjectiles]
	--			fadeProjectiles[#fadeProjectiles] = nil
	--		else
	--			local params = fadeProjectiles[i]
	--			params.colMult = strength*params.startColMul
	--			if params.beam then
	--				beamLightCount = beamLightCount + 1
	--				beamLights[beamLightCount] = params
	--			else
	--				pointLightCount = pointLightCount + 1
	--				pointLights[pointLightCount] = params
	--			end
	--			i = i + 1
	--		end
	--	end
	--
	--	previousProjectileDrawParams = projectileDrawParams
	--end

	-- add custom beam lights
	local progress = 1
	--Spring.Echo(#customBeamLights..'  '..math_random())
	for i, params in pairs(customBeamLights) do
		if not params.life then
			params.colMult = params.orgMult
		else
			progress = 1-((frame-params.frame)/params.life)
			progress = ((progress * (progress*progress)) + (progress*1.4)) / 2.4    -- fade out fast, but ease out at the end
			params.colMult = params.orgMult
			if not params.nofade then
				params.colMult = params.orgMult * progress
			end
		end
		if params.colMult <= 0 then
			customBeamLights[i] = nil
		else
			beamLightCount = beamLightCount + 1
			beamLights[beamLightCount] = params
		end
	end

	-- add explosion/custom lights
	for i, params in pairs(explosionLights) do
		if params.randomOffset then
			if not params.opx then
				params.opx = params.px
				params.opy = params.py
				params.opz = params.pz
			end
			params.px = params.opx + (0.5 - math_random()) * params.randomOffset
			params.py = params.opy + (0.5 - math_random()) * params.randomOffset
			params.pz = params.opz + (0.5 - math_random()) * params.randomOffset
		end
		if not params.life then
			params.colMult = params.orgMult
		else
			progress = 1-((frame-params.frame)/params.life)
			progress = ((progress * (progress*progress)) + (progress*1.4)) / 2.4    -- fade out fast, but ease out at the end
			params.colMult = params.orgMult
			if not params.nofade then
				params.colMult = params.orgMult * progress
			end
		end
		if params.colMult <= 0 then
			explosionLights[i] = nil
		else
			pointLightCount = pointLightCount + 1
			pointLights[pointLightCount] = params
		end
	end

	return beamLights, beamLightCount, pointLights, pointLightCount
end

local function CreateBeamLight(name, x, y, z, x2, y2, z2, radius, rgba)
	if name == 'nano' then
		if enableNanolaser then
			nanolaserLights[#nanolaserLights+1] = explosionLightsCount + 1
		else
			return false
		end
	end
	if y + y2 < -800 then
		-- The beam has fallen through the world
		x2, y2, z2 = InterpolateBeam(x, y, z, x2, y2, z2)
	end
	local params = {
		nofade = true,
		beam = true,
		frame = spGetGameFrame(),
		px = x, py = y, pz = z,
		dx = x2, dy = y2, dz = z2,
		orgMult = rgba[4],--*globalLightMult,
		colMult = rgba[4],
		param = {
			r = rgba[1],
			g = rgba[2],
			b = rgba[3],
			radius = radius,--*globalRadiusMult,
		},
	}

	customBeamLightsCount = customBeamLightsCount + 1
	customBeamLights[customBeamLightsCount] = params
	--Spring.Echo('created light: '..customBeamLightsCount..'  '..x..'  '..y..'  '..z..'  '..radius..'  '..rgba[1]..','..rgba[2]..','..rgba[3]..','..rgba[4])
	return customBeamLightsCount
end

local function EditBeamLight(lightID, params)
	--if params.orgMult then
	--	params.orgMult = params.orgMult * globalLightMult
	--end
	--if params.param and params.param.radius then
	--	params.param.radius = params.param.radius * globalRadiusMult
	--end
	--if params.py and params.dy and params.py + params.dy < -800 then
	--	-- The beam has fallen through the world
	--	params.dx, params.dy, params.dz = InterpolateBeam(params.px, params.py, params.pz, params.dx, params.dy, params.dz)
	--end
	--Spring.Echo('editing: '..lightID..'  '..params.px..'  '..params.py..'  '..params.pz..'    '..params.dx..'  '..params.dy..'  '..params.dz)
	if customBeamLights[lightID] then
		table.mergeInPlace(customBeamLights[lightID], params)
		return true
	else
		return false
	end
end

local function RemoveBeamLight(lightID, life)
	if customBeamLights[lightID] then
		if life == nil then
			customBeamLights[lightID] = nil
		else
			customBeamLights[lightID].nofade = nil
			customBeamLights[lightID].life = life
			customBeamLights[lightID].frame = spGetGameFrame()
		end
	elseif lightID == -1 then	-- gadget does this when doing /luarules reload
		customBeamLights = {}
	end
end

local function CreateLight(name, x, y, z, radius, rgba, falloffsquared)
  --Spring.Echo("CreateLight(name, x, y, z, radius, rgba, falloffsquared)",name, x, y, z, radius, rgba, falloffsquared)
  falloffsquared = falloffsquared or 1.0
	if name == 'thruster' then
		if enableThrusters then
			thrusterLights[#thrusterLights+1] = explosionLightsCount + 1
		else
			return false
		end
	end
	local params = {
		orgMult = rgba[4],
		nofade = true,
		frame = spGetGameFrame(),
		px = x,
		py = y,
		pz = z,
		param = {
			type = 'explosion',
			r = rgba[1],
			g = rgba[2],
			b = rgba[3],
			radius = radius,
      falloffsquared = falloffsquared,
		},
	}
	explosionLightsCount = explosionLightsCount + 1
	explosionLights[explosionLightsCount] = params
	return explosionLightsCount
end

local function EditLight(lightID, params)
	if explosionLights[lightID] then
		table.mergeInPlace(explosionLights[lightID], params)
		return true
	else
		return false
	end
end

local function EditLightPos(lightID, x,y,z)
	if explosionLights[lightID] then
		explosionLights[lightID].px = x
		explosionLights[lightID].py = y
		explosionLights[lightID].pz = z
		return true
	else
		return false
	end
end

local function RemoveLight(lightID, life)
	if explosionLights[lightID] then
		if life == nil then
			explosionLights[lightID] = nil
		else
			explosionLights[lightID].nofade = nil
			explosionLights[lightID].life = life
			explosionLights[lightID].frame = spGetGameFrame()
		end
	end
end

local function tablecopy(self)
	local copy = {}
	for key, value in pairs(self) do
		if type(value) == "table" then
			copy[key] = table.copy(value)
		else
			copy[key] = value
		end
	end
	return copy
end

-- function called by explosion_lights gadget
local function GadgetWeaponExplosion(px, py, pz, weaponID, ownerID)
	if weaponConf[weaponID] ~= nil then
		local params = {
			life = weaponConf[weaponID].life,
			orgMult = weaponConf[weaponID].orgMult,
			frame = spGetGameFrame(),
			px = px,
			py = py + weaponConf[weaponID].yoffset,
			pz = pz,
			param = {
				type = 'explosion',
				r = weaponConf[weaponID].r,
				g = weaponConf[weaponID].g,
				b = weaponConf[weaponID].b,
				radius = weaponConf[weaponID].radius,
			},
		}
		explosionLightsCount = explosionLightsCount + 1
		explosionLights[explosionLightsCount] = params

		if py > 0 and enableHeatDistortion and WG['Lups'] and params.param.radius > 80 and not weaponConf[weaponID].noheatdistortion and spIsSphereInView(px,py,pz,100) then

			local strength,animSpeed,life,heat,sizeGrowth,size,force

			local cx, cy, cz = Spring.GetCameraPosition()
			local distance = math_diag(px-cx, py-cy, pz-cz)
			local strengthMult = 1 / (distance*0.001)

			if weaponConf[weaponID].type == 'paralyzer' then
				strength = 10
				animSpeed = 0.1
				life = params.life*0.6 + (params.param.radius/80)
				sizeGrowth = 0
				heat = 15
				size =  params.param.radius/16
				force = {0,0.15,0}
			else
				animSpeed = 1.3
				sizeGrowth = 0.6
				if weaponConf[weaponID].type == 'flame' then
					strength = 1 + (params.life/25)
					size = params.param.radius/2.35
					life = params.life*0.64 + (params.param.radius/90)
					force = {1,5.5,1}
					heat = 8
				else
					strength = weaponConf[weaponID].heatstrength
					size = weaponConf[weaponID].heatradius
					life = weaponConf[weaponID].heatlife
					force = {0,0.35,0}
					heat = 1
				end
			end
			if size*strengthMult > 5 then
				WG['Lups'].AddParticles('JitterParticles2', {
					layer = -35,
					life = life,
					pos = {px,py+10,pz},
					size = size,
					sizeGrowth = sizeGrowth,
					strength = strength*strengthMult,
					animSpeed = animSpeed,
					heat = heat,
					force = force,
				})
			end
		end

		-- bright short nuke flash (unsure why it gets blue-ified sometimes)
		if weaponConf[weaponID].nuke then
			local params = tablecopy(params)
			params.py = params.py + 80 + math.min(180, params.param.radius / 30)
			params.life = 1.5 + math.min(1.6, params.param.radius / 800)
			params.orgMult = 0.66 + math.min(1.6, params.param.radius / 2500)
			params.param.radius = 400 + (params.param.radius * 18)
			params.param.r = 1
			params.param.g = 1
			params.param.b = 1
			explosionLightsCount = explosionLightsCount + 1
			explosionLights[explosionLightsCount] = params
		end
	end
end

local function GadgetWeaponBarrelfire(px, py, pz, weaponID, ownerID)
	if weaponConf[weaponID] ~= nil then
		local mult = (weaponConf[weaponID].wtype == 'Cannon' and 1 or 0.3)
		local params = {
			life = (3+(weaponConf[weaponID].life/2.5))*globalLifeMult * mult,
			orgMult = 0.3 + (weaponConf[weaponID].orgMult*0.2) * mult,
			frame = spGetGameFrame(),
			px = px,
			py = py,
			pz = pz,
			param = {
				type = 'explosion',
				r = weaponConf[weaponID].r,
				g = weaponConf[weaponID].g,
				b = weaponConf[weaponID].b,
				radius = 25 + (weaponConf[weaponID].radius*0.85) * mult,
			},
		}
		explosionLightsCount = explosionLightsCount + 1
		explosionLights[explosionLightsCount] = params
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Shutdown()
	WG['lighteffects'] = nil
	widgetHandler:DeregisterGlobal('GadgetWeaponExplosion')
	widgetHandler:DeregisterGlobal('GadgetWeaponBarrelfire')
	widgetHandler:DeregisterGlobal('GadgetCreateLight')
	widgetHandler:DeregisterGlobal('GadgetEditLight')
	widgetHandler:DeregisterGlobal('GadgetEditLightPos')
	widgetHandler:DeregisterGlobal('GadgetRemoveLight')
	widgetHandler:DeregisterGlobal('GadgetCreateBeamLight')
	widgetHandler:DeregisterGlobal('GadgetEditBeamLight')
	widgetHandler:DeregisterGlobal('GadgetRemoveBeamLight')

	if deferredFunctionID and WG.DeferredLighting_UnRegisterFunction then
		WG.DeferredLighting_UnRegisterFunction(deferredFunctionID)
	end
end

function widget:Initialize()
	loadWeaponDefs()

	widgetHandler:RegisterGlobal('GadgetWeaponExplosion', GadgetWeaponExplosion)
	widgetHandler:RegisterGlobal('GadgetWeaponBarrelfire', GadgetWeaponBarrelfire)
	widgetHandler:RegisterGlobal('GadgetCreateLight', CreateLight)
	widgetHandler:RegisterGlobal('GadgetEditLight', EditLight)
	widgetHandler:RegisterGlobal('GadgetEditLightPos', EditLightPos)
	widgetHandler:RegisterGlobal('GadgetRemoveLight', RemoveLight)
	widgetHandler:RegisterGlobal('GadgetCreateBeamLight', CreateBeamLight)
	widgetHandler:RegisterGlobal('GadgetEditBeamLight', EditBeamLight)
	widgetHandler:RegisterGlobal('GadgetRemoveBeamLight', RemoveBeamLight)

	if WG.DeferredLighting_RegisterFunction then
		deferredFunctionID = WG.DeferredLighting_RegisterFunction(GetProjectileLights)
		projectileLightTypes = GetLightsFromUnitDefs()
	end

	WG['lighteffects'] = {}
	WG['lighteffects'].enableThrusters = enableThrusters
	WG['lighteffects'].createLight = function(name,x,y,z,radius,rgba,falloffsquared)
		return CreateLight(name,x,y,z,radius,rgba,falloffsquared)
	end
	WG['lighteffects'].editLight = function(lightID, params)
		return EditLight(lightID, params)
	end
	WG['lighteffects'].editLightPos = function(lightID, x,y,z)
		return EditLightPos(lightID, x,y,z)
	end
	WG['lighteffects'].removeLight = function(lightID, life)
		return RemoveLight(lightID, life)
	end
	WG['lighteffects'].createBeamLight = function(name,x,y,z,x2,y2,z2,radius,rgba)
		return CreateBeamLight(name,x,y,z,x2,y2,z2,radius,rgba)
	end
	WG['lighteffects'].editBeamLight = function(lightID, params)
		return EditBeamLight(lightID, params)
	end
	WG['lighteffects'].removeBeamLight = function(lightID, life)
		return RemoveBeamLight(lightID, life)
	end
	WG['lighteffects'].getGlobalBrightness = function()
		return globalLightMult
	end
	WG['lighteffects'].getGlobalRadius = function()
		return globalRadiusMult
	end
	WG['lighteffects'].getGlobalBrightness = function()
		return globalLightMultLaser
	end
	WG['lighteffects'].getLaserRadius = function()
		return globalRadiusMultLaser
	end
	WG['lighteffects'].getLife = function()
		return globalLifeMult
	end
	WG['lighteffects'].getHeatDistortion = function()
		return enableHeatDistortion
	end
	WG['lighteffects'].getNanolaser = function()
		return enableNanolaser
	end
	WG['lighteffects'].getThrusters = function()
		return enableThrusters
	end
	WG['lighteffects'].setGlobalBrightness = function(value)
		globalLightMult = value
		projectileLightTypes = GetLightsFromUnitDefs()
		loadWeaponDefs()
	end
	WG['lighteffects'].setGlobalRadius = function(value)
		globalRadiusMult = value
		projectileLightTypes = GetLightsFromUnitDefs()
		loadWeaponDefs()
	end
	WG['lighteffects'].setLaserBrightness = function(value)
		globalLightMultLaser = value
		projectileLightTypes = GetLightsFromUnitDefs()
	end
	WG['lighteffects'].setLaserRadius = function(value)
		globalRadiusMultLaser = value
		projectileLightTypes = GetLightsFromUnitDefs()
	end
	WG['lighteffects'].setLife = function(value)
		globalLifeMult = value
		loadWeaponDefs()
	end
	WG['lighteffects'].setHeatDistortion = function(value)
		enableHeatDistortion = value
	end
	WG['lighteffects'].setNanolaser = function(value)
		enableNanolaser = value
		if not enableNanolaser then
			for i=1, #nanolaserLights do
				RemoveBeamLight(nanolaserLights[i])
			end
		end
	end
	WG['lighteffects'].setThrusters = function(value)
		enableThrusters = value
		WG['lighteffects'].enableThrusters = enableThrusters
		if not enableThrusters then
			for i=1, #thrusterLights do
				RemoveLight(thrusterLights[i])
			end
		end
	end

end


function widget:GetConfigData(data)
	local savedTable = {
		globalLightMult = globalLightMult,
		globalRadiusMult = globalRadiusMult,
		globalLightMultLaser = globalLightMultLaser,
		globalRadiusMultLaser = globalRadiusMultLaser,
		globalLifeMult = globalLifeMult,
		enableHeatDistortion = enableHeatDistortion,
		enableNanolaser = enableNanolaser,
		enableThrusters = enableThrusters,
		resetted = 1.65,
	}
	return savedTable
end

function widget:SetConfigData(data)
	if data.globalLifeMult ~= nil and data.resetted ~= nil and data.resetted == 1.65 then
		if data.globalLightMult ~= nil then
			globalLightMult = data.globalLightMult
		end
		if data.globalRadiusMult ~= nil then
			globalRadiusMult = data.globalRadiusMult
		end
		if data.globalLightMultLaser ~= nil then
			globalLightMultLaser = data.globalLightMultLaser
		end
		if data.globalRadiusMultLaser ~= nil then
			globalRadiusMultLaser = data.globalRadiusMultLaser
		end
		if data.globalLifeMult ~= nil then
			globalLifeMult = data.globalLifeMult
		end
        if data.enableHeatDistortion ~= nil then
            enableHeatDistortion = data.enableHeatDistortion
        end
		if data.enableNanolaser ~= nil then
			enableNanolaser = data.enableNanolaser
		end
		if data.enableThrusters ~= nil then
			enableThrusters = data.enableThrusters
		end
	end
end
