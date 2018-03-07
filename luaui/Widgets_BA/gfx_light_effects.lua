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
		enabled   = true
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


local function Split(s, separator)
	local results = {}
	for part in s:gmatch("[^"..separator.."]+") do
		results[#results + 1] = part
	end
	return results
end

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
			weaponData.radius = 500
			lightMultiplier = 0.28
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

	-- add explosion lights
	for i, params in pairs(explosionLights) do
		local progress = 1-((frame-params.frame)/params.life)
		progress = ((progress * (progress*progress)) + (progress*1.4)) / 2.4
		params.colMult = params.orgMult * progress
		if params.colMult <= 0 then
			explosionLights[i] = nil
		else
			pointLightCount = pointLightCount + 1
			pointLights[pointLightCount] = params
		end
	end

	return beamLights, beamLightCount, pointLights, pointLightCount
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
			elseif WeaponDefs[i].rgbColor ~= nil then
				local colorList = Split(WeaponDefs[i].rgbColor, " ")
				params.r = colorList[1]
				params.g = colorList[2]
				params.b = colorList[3]
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
			if customParams.expl_light_life then
				params.life = tonumber(customParams.expl_light_life)
			end
			if customParams.expl_light_life_mult then
				params.life = params.life * tonumber(customParams.expl_light_life_mult)
			end

			weaponConf[i] = params
		end
	end
end
loadWeaponDefs()


-- function called by explosion_lights gadget
function GadgetWeaponExplosion(px, py, pz, weaponID, ownerID)
	if weaponConf[weaponID] ~= nil then
		local params = {param={type='explosion'}}
		params.param.r, params.param.g, params.param.b = weaponConf[weaponID].r, weaponConf[weaponID].g, weaponConf[weaponID].b
		params.life = weaponConf[weaponID].life
		params.orgMult = weaponConf[weaponID].orgMult
		params.param.radius = weaponConf[weaponID].radius

		params.frame = Spring.GetGameFrame()
		params.px, params.py, params.pz = px, py, pz
		params.py = params.py + 16 + (params.param.radius/35)

		--Spring.Echo(UnitDefs[unitDefID].name..'    '..params.orgMult)
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
	if WG.DeferredLighting_RegisterFunction then
		WG.DeferredLighting_RegisterFunction(GetProjectileLights)
		projectileLightTypes = GetLightsFromUnitDefs()
	end

	WG['lighteffects'] = {}
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

end


function widget:GetConfigData(data)
	savedTable = {}
	savedTable.globalLightMult = globalLightMult
	savedTable.globalRadiusMult = globalRadiusMult
	savedTable.globalLightMultLaser = globalLightMultLaser
	savedTable.globalRadiusMultLaser = globalRadiusMultLaser
	savedTable.globalLifeMult = globalLifeMult
	savedTable.resetted = 1.4
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
	end
end