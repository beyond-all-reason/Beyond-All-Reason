--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetProjectilesInRectangle = Spring.GetProjectilesInRectangle
local spGetVisibleProjectiles     = Spring.GetVisibleProjectiles
local spGetProjectilePosition     = Spring.GetProjectilePosition
local spGetProjectileType         = Spring.GetProjectileType
local spGetProjectileDefID        = Spring.GetProjectileDefID
local spGetPieceProjectileParams  = Spring.GetPieceProjectileParams
local spGetProjectileVelocity     = Spring.GetProjectileVelocity

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Local Variables
local previousProjectileDrawParams
local fadeProjectiles, fadeProjectileTimes = {}, {}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Config

local useLOD = false		-- Reduces the number of lights drawn based on camera distance and current fps.
local projectileFade = true
local FADE_TIME = 5


local overrideParam = {r = 1, g = 1, b = 1, radius = 200}
local doOverride = false

local globalLightMult = 1.3
local globalRadiusMult = 1.3
local globalLightMultLaser = 1.4	-- gets applied on top op globalRadiusMult
local globalRadiusMultLaser = 0.9	-- gets applied on top op globalRadiusMult
local globalLifeMult = 0.65

local enableHeatDistortion = true
local enableDeferred = true     -- else use groundflashes instead
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


local function Split(s, separator)
	local results = {}
	for part in s:gmatch("[^"..separator.."]+") do
		results[#results + 1] = part
	end
	return results
end



local weaponConf = {}
function loadWeaponDefs()
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
			params.r, params.g, params.b = 1, 0.8, 0.4
			params.radius = (WeaponDefs[i].damageAreaOfEffect*4.5) * globalRadiusMult
			params.orgMult = (0.35 + (params.radius/2400)) * globalLightMult
			params.life = (14*(0.8+ params.radius/1200))*globalLifeMult

			if customParams.expl_light_color then
				local colorList = Split(customParams.expl_light_color, " ")
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

			if customParams.expl_light_mult ~= nil then
				params.orgMult = params.orgMult * customParams.expl_light_mult
			end

			if customParams.expl_light_radius then
				params.radius = tonumber(customParams.expl_light_radius) * globalRadiusMult
			end
			if customParams.expl_light_radius_mult then
				params.radius = params.radius * tonumber(customParams.expl_light_radius_mult)
			end

			params.heatradius = (WeaponDefs[i].damageAreaOfEffect*0.5)

			if customParams.expl_light_heat_radius_mult then
				params.heatradius = (params.heatradius * tonumber(customParams.expl_light_heat_radius_mult))
			end

			params.heatlife = (13*(0.8+ params.heatradius/1200)) + (params.heatradius/4)

			if customParams.expl_light_heat_life_mult then
				params.heatlife = params.heatlife * tonumber(customParams.expl_light_heat_life_mult)
			end

			params.heatstrength = 1 + (params.heatradius/30)

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
				params.orgMult = params.orgMult * 0.66
			end
			params.wtype = WeaponDefs[i].type
			if params.wtype == 'Cannon' then
				params.cannonsize = WeaponDefs[i].size
			end

			params.yoffset = 15 + (params.radius/35)

			if WeaponDefs[i].type == 'BeamLaser' then
				local damage = 75
				params.radius = params.radius * 3.5
				for cat=0, #WeaponDefs[i].damages do
					if Game.armorTypes[cat] and Game.armorTypes[cat] == 'default' then
						damage = WeaponDefs[i].damages[cat]
						break
					end
				end
				params.life = 1
				damage = damage/WeaponDefs[i].beamtime
				params.radius = (params.radius*1.4) + (damage/2500)
				params.orgMult = (0.22 + (damage/3000))
				if params.orgMult > 0.8 then
					params.orgMult = 0.8
				end
				params.orgMult = params.orgMult * globalLightMult
				params.yoffset = 4 + (params.radius/300)
				if params.yoffset > 25 then params.yoffset = 25 end
			end

			weaponConf[i] = params
		end
	end
end
loadWeaponDefs()



--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Light Defs


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

		local lightMultiplier = 0.08
		local bMult = 1.6		-- because blue appears to be very faint
		local r,g,b = weaponDef.visuals.colorR, weaponDef.visuals.colorG, weaponDef.visuals.colorB*bMult

		local weaponData = {type=weaponDef.type, r = (r + 0.1) * lightMultiplier, g = (g + 0.1) * lightMultiplier, b = (b + 0.1) * lightMultiplier, radius = 100}
		local recalcRGB = false

		if (weaponDef.type == 'Cannon') then
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
		elseif (weaponDef.type == 'LaserCannon') then
			weaponData.radius = 70 * weaponDef.size
		elseif (weaponDef.type == 'DGun') then
			weaponData.radius = 450
			lightMultiplier = 0.55
		elseif (weaponDef.type == 'MissileLauncher') then
			weaponData.radius = 125 * weaponDef.size
			if weaponDef.damageAreaOfEffect ~= nil  then
				weaponData.radius = 125 * (weaponDef.size + (weaponDef.damageAreaOfEffect * 0.01))
			end
			lightMultiplier = 0.01 + (weaponDef.size/55)
			recalcRGB = true
		elseif (weaponDef.type == 'StarburstLauncher') then
			weaponData.radius = 250
			weaponData.radius1 = weaponData.radius
			weaponData.radius2 = weaponData.radius*0.6
		elseif (weaponDef.type == 'Flame') then
			weaponData.radius = 70 * weaponDef.size
			lightMultiplier = 0.05
			recalcRGB = true
			--skip = true
		elseif (weaponDef.type == 'LightningCannon') then
			weaponData.radius = 70 * weaponDef.size
			weaponData.beam = true
		elseif (weaponDef.type == 'BeamLaser') then
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
			local colorList = Split(customParams.light_color, " ")
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
		local h = Spring.GetGroundHeight(x + dx + finalDx, z + dz + finalDz)
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
	return camY - math.max(Spring.GetGroundHeight(camX, camZ), 0)
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
			timeToLive = timeToLive or Spring.GetProjectileTimeToLive(pID)
			if (not lightParams.maxTTL) or lightParams.maxTTL < timeToLive then
				lightParams.maxTTL = timeToLive
			end
			mult = mult * (1 - math.min(1, (timeToLive - (lightParams.maxTTL - lightParams.beamMultFrames))/lightParams.beamMultFrames))
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
		timeToLive = timeToLive or Spring.GetProjectileTimeToLive(pID)
		light.colMult = math.max(0, (timeToLive + lightParams.fadeOffset)/lightParams.fadeTime)
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
	--local timeToLive = Spring.GetProjectileTimeToLive(pID)
	--Spring.MarkerAddPoint(x,y,z,timeToLive)

	if lightParams.fadeTime and lightParams.fadeOffset then
		local timeToLive = Spring.GetProjectileTimeToLive(pID)
		light.colMult = math.max(0, (timeToLive + lightParams.fadeOffset)/lightParams.fadeTime)
	else
		light.colMult = 1
	end

	return light
end

local function GetProjectileLights(beamLights, beamLightCount, pointLights, pointLightCount)
	local cx, cy, cz = Spring.GetCameraPosition()

    if not enableDeferred then return {}, 0, {}, 0 end

	local projectiles = spGetVisibleProjectiles()
	local projectileCount = #projectiles
	if (not projectileFade) and projectileCount == 0 then
		return beamLights, beamLightCount, pointLights, pointLightCount
	end

	local fps = Spring.GetFPS()
	local cameraHeight = math.floor(GetCameraHeight()*0.01)*100
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
			if explosionflags and (explosionflags%32) > 15 then --only stuff with the FIRE explode tag gets a light
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
			lightParams = projectileLightTypes[spGetProjectileDefID(pID)]
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
					if not (lightParams.groundHeightLimit and lightParams.groundHeightLimit < (y - math.max(Spring.GetGroundHeight(y, y), 0))) then
						local drawParams = GetProjectileLight(lightParams, pID, x, y, z)
						if lightParams.radius2 ~= nil then
							local dirX,dirY,dirZ = Spring.GetProjectileDirection(pID)
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
						if enableHeatDistortion and WG['Lups'] then
							local weaponDefID = Spring.GetProjectileDefID(pID)
							if weaponDefID and weaponConf[weaponDefID] and not weaponConf[weaponDefID].noheatdistortion and Spring.IsSphereInView(x,y,z,100) then
								if weaponConf[weaponDefID].wtype == 'DGun' then
									local distance = math.diag(x-cx, y-cy, z-cz)
									local strengthMult = 1 / (distance*0.001)

									WG['Lups'].AddParticles('JitterParticles2', {
										layer = -35,
										life = weaponConf[weaponDefID].heatlife/4,
										pos = {x,y,z},
										size = weaponConf[weaponDefID].heatradius*1.5,
										sizeGrowth = 0.2,
										strength = (weaponConf[weaponDefID].heatstrength*0.5)*strengthMult,
										animSpeed = 1.3,
										heat = 1,
										force = {0,0.35,0},
									})
								end
							end
						end
					end
				end
			end
		end
	end

	local frame = Spring.GetGameFrame()
	if projectileFade then
		if previousProjectileDrawParams then
			for i = 1, #previousProjectileDrawParams do
				local pID = previousProjectileDrawParams[i].pID
				if not projectilePresent[pID] then
					local params = previousProjectileDrawParams[i]
					params.startColMul = params.colMul or 1
					params.py = params.py + 10
					fadeProjectiles[#fadeProjectiles + 1] = params
					fadeProjectileTimes[#fadeProjectileTimes + 1] = frame + FADE_TIME
				end
			end
		end

		local i = 1
		while i <= #fadeProjectiles do
			local strength = (fadeProjectileTimes[i] - frame)/FADE_TIME
			if strength <= 0 then
				fadeProjectileTimes[i] = fadeProjectileTimes[#fadeProjectileTimes]
				fadeProjectileTimes[#fadeProjectileTimes] = nil
				fadeProjectiles[i] = fadeProjectiles[#fadeProjectiles]
				fadeProjectiles[#fadeProjectiles] = nil
			else
				local params = fadeProjectiles[i]
				params.colMult = strength*params.startColMul
				if params.beam then
					beamLightCount = beamLightCount + 1
					beamLights[beamLightCount] = params
				else
					pointLightCount = pointLightCount + 1
					pointLights[pointLightCount] = params
				end
				i = i + 1
			end
		end

		previousProjectileDrawParams = projectileDrawParams
	end

	-- add custom beam lights
	local progress = 1
	--Spring.Echo(#customBeamLights..'  '..math.random())
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

function tableMerge(t1, t2)
	for k,v in pairs(t2) do if type(v) == "table" then if type(t1[k] or false) == "table" then tableMerge(t1[k] or {}, t2[k] or {}) else t1[k] = v end else t1[k] = v end end
	return t1
end

function CreateBeamLight(name, x, y, z, x2, y2, z2, radius, rgba)
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
		frame = Spring.GetGameFrame(),
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

function EditBeamLight(lightID, params)
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
		customBeamLights[lightID] = tableMerge(customBeamLights[lightID], params)
		return true
	else
		return false
	end
end

function RemoveBeamLight(lightID, life)
	if customBeamLights[lightID] then
		if life == nil then
			customBeamLights[lightID] = nil
		else
			customBeamLights[lightID].nofade = nil
			customBeamLights[lightID].life = life
			customBeamLights[lightID].frame = Spring.GetGameFrame()
		end
	end
end

function CreateLight(name, x, y, z, radius, rgba)
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
		frame = Spring.GetGameFrame(),
		px = x,
		py = y,
		pz = z,
		param = {
			type = 'explosion',
			r = rgba[1],
			g = rgba[2],
			b = rgba[3],
			radius = radius,
		},
	}
	explosionLightsCount = explosionLightsCount + 1
	explosionLights[explosionLightsCount] = params
	return explosionLightsCount
end

function EditLight(lightID, params)
	if explosionLights[lightID] then
		explosionLights[lightID] = tableMerge(explosionLights[lightID], params)
		return true
	else
		return false
	end
end

function RemoveLight(lightID, life)
	if explosionLights[lightID] then
		if life == nil then
			explosionLights[lightID] = nil
		else
			explosionLights[lightID].nofade = nil
			explosionLights[lightID].life = life
			explosionLights[lightID].frame = Spring.GetGameFrame()
		end
	end
end


-- function called by explosion_lights gadget
function GadgetWeaponExplosion(px, py, pz, weaponID, ownerID)
	if weaponConf[weaponID] ~= nil then
		--Spring.Echo(weaponConf[weaponID].orgMult..'   '..weaponConf[weaponID].radius..'  '..weaponConf[weaponID].life)
		local params = {
			life = weaponConf[weaponID].life,
			orgMult = weaponConf[weaponID].orgMult,
			frame = Spring.GetGameFrame(),
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

		if not enableDeferred then
            if WG['Lups'] then
                WG['Lups'].AddParticles('GroundFlash', {
                    worldspace = true,
                    layer = -35,
                    life = weaponConf[weaponID].life,
                    pos = {px,py+10,pz},
                    size = weaponConf[weaponID].radius/2.2,
                    sizeGrowth = 0,
                    colormap   = { {weaponConf[weaponID].r, weaponConf[weaponID].g, weaponConf[weaponID].b, weaponConf[weaponID].orgMult*1.33} },
                    texture    = 'LuaUI/Images/glow2.dds',
                })
            end
		else
			explosionLightsCount = explosionLightsCount + 1
			explosionLights[explosionLightsCount] = params
		end

		if py > 0 and enableHeatDistortion and WG['Lups'] and params.param.radius > 80 and not weaponConf[weaponID].noheatdistortion and Spring.IsSphereInView(px,py,pz,100) then

			local strength,animSpeed,life,heat,sizeGrowth,size,force

			local cx, cy, cz = Spring.GetCameraPosition()
			local distance = math.diag(px-cx, py-cy, pz-cz)
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


		-- a test to replace stumpy weapon ceg 'explosion' effect, so when maxparticles is reached, there is still this lups shown, only thing missing is the directional=true options :(
		--if WG['Lups'] then
		--	WG['Lups'].AddParticles('SimpleParticles2', {
		--		emitVector     = {0,1,0},
		--		pos            = {px,py+2,pz}, --// start pos
		--		partpos        = "0,0,0",  --//particle relative start pos (can contain lua code!)
		--		layer          = 0,
		--
		--		--// visibility check
		--		los            = true,
		--		airLos         = true,
		--		radar          = false,
		--
		--		count          = 8,
		--		force          = {0,0,0}, --// global effect force
		--		forceExp       = 1,
		--		speed          = 0.3,
		--		speedSpread    = 2.5,
		--		speedExp       = 0.3, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow
		--		life           = 6,
		--		lifeSpread     = 5,
		--		delaySpread    = 0,
		--		rotSpeed       = 0,
		--		rotSpeedSpread = 0,
		--		rotSpread      = 0,
		--		rotExp         = 1, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow;  <0 : invert x-axis (start large become smaller)
		--		emitRot        = 45,
		--		emitRotSpread  = 32,
		--		size           = 2,
		--		sizeSpread     = 3.2,
		--		sizeGrowth     = 0.4,
		--		sizeExp        = 1, --// >1 : first decrease slow, then fast;  <1 : decrease fast, then slow;  <0 : invert x-axis (start large become smaller)
		--		colormap       = { {0,0,0,0}, {1,0.9,0.6,0.09}, {0.9,0.5,0.2,0.066}, {0.66,0.28,0.04,0.033}, {0,0,0,0} }, --//max 16 entries
		--		texture        = 'bitmaps/projectiletextures/flashside2.tga',
		--		repeatEffect   = false, --can be a number,too
		--	})
		--end
	end
end

function GadgetWeaponBarrelfire(px, py, pz, weaponID, ownerID)
	if enableDeferred and weaponConf[weaponID] ~= nil then
		local params = {
			life = (2.5+(weaponConf[weaponID].life/4))*globalLifeMult,
			orgMult = 0.44 + (weaponConf[weaponID].orgMult*0.4),
			frame = Spring.GetGameFrame(),
			px = px,
			py = py,
			pz = pz,
			param = {
				type = 'explosion',
				r = weaponConf[weaponID].r,
				g = weaponConf[weaponID].g,
				b = weaponConf[weaponID].b,
				radius = 20 + weaponConf[weaponID].radius*0.44,
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
end

function widget:Initialize()
	loadWeaponDefs()

	widgetHandler:RegisterGlobal('GadgetWeaponExplosion', GadgetWeaponExplosion)
	widgetHandler:RegisterGlobal('GadgetWeaponBarrelfire', GadgetWeaponBarrelfire)
	widgetHandler:RegisterGlobal('GadgetCreateLight', CreateLight)
	widgetHandler:RegisterGlobal('GadgetEditLight', EditLight)
	widgetHandler:RegisterGlobal('GadgetRemoveLight', RemoveLight)
	widgetHandler:RegisterGlobal('GadgetCreateBeamLight', CreateBeamLight)
	widgetHandler:RegisterGlobal('GadgetEditBeamLight', EditBeamLight)
	widgetHandler:RegisterGlobal('GadgetRemoveBeamLight', RemoveBeamLight)

	if WG.DeferredLighting_RegisterFunction then
		WG.DeferredLighting_RegisterFunction(GetProjectileLights)
		projectileLightTypes = GetLightsFromUnitDefs()
	end

	WG['lighteffects'] = {}
	WG['lighteffects'].enableThrusters = enableThrusters
	WG['lighteffects'].createLight = function(name,x,y,z,radius,rgba)
		return CreateLight(name,x,y,z,radius,rgba)
	end
	WG['lighteffects'].editLight = function(lightID, params)
		return EditLight(lightID, params)
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
    WG['lighteffects'].getDeferred = function()
        return enableDeferred
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
    WG['lighteffects'].setDeferred = function(value)
        enableDeferred = value
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
		enableDeferred = enableDeferred,
		enableNanolaser = enableNanolaser,
		enableThrusters = enableThrusters,
		resetted = 1.4,
	}
	return savedTable
end

function widget:SetConfigData(data)
	if data.globalLifeMult ~= nil and data.resetted ~= nil and data.resetted == 1.4 then
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
		if data.enableDeferred ~= nil then
			enableDeferred = data.enableDeferred
		end
		if data.enableNanolaser ~= nil then
			enableNanolaser = data.enableNanolaser
		end
		if data.enableThrusters ~= nil then
			enableThrusters = data.enableThrusters
		end
	end
end