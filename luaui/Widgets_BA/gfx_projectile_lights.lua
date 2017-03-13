--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Projectile Lights",
		version   = 3,
		desc      = "Collects projectiles and sends them to the deferred renderer.",
		author    = "GoogleFrog (beherith orgional)",
		date      = "5 March 2016",
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
local lightsEnabled = true
local FADE_TIME = 5

local colorOverride = {1, 1, 1}
local colorBrightness = 1
local radiusOverride = 200
local overrideParam = {r = 1, g = 1, b = 1, radius = 200}
local doOverride = false

local wantLoadParams = false


local function Format(value)
	return string.format("%.2f", value)
end

local function ApplySetting()
	overrideParam.r = colorOverride[1] * colorBrightness
	overrideParam.g = colorOverride[2] * colorBrightness
	overrideParam.b = colorOverride[3] * colorBrightness
	overrideParam.radius = radiusOverride
	Spring.Utilities.TableEcho(overrideParam)
	Spring.Echo("light_color = [[" .. Format(overrideParam.r) .. " " .. Format(overrideParam.g) .. " " .. Format(overrideParam.b) .. "]]")
	Spring.Echo("light_radius = " .. Format(radiusOverride) .. ",")
end

local function LoadParams(param)
	options.light_radius.value = param.radius
	options.light_brightness.value = math.max(param.r, param.g, param.b)
	options.light_color.value = {
		param.r / options.light_brightness.value,
		param.g / options.light_brightness.value,
		param.b / options.light_brightness.value,
	}
	radiusOverride = options.light_radius.value
	colorBrightness = options.light_brightness.value
	colorOverride = options.light_color.value
	
	Spring.Echo("Loading Settings")
	ApplySetting()
	wantLoadParams = false
	WG.RemakeEpicMenu()
end

options = {
	light_projectile_enable = {
		name = "Enable Projectile Lights",
		type = 'bool',
		value = true,
		OnChange = function (self) 
			lightsEnabled = self.value
		end,
		noHotkey = true,
	},
	useLOD = {
		name = 'Use LOD',
		type = 'bool',
		desc = 'Reduces the number of lights drawn based on camera distance and current fps.',
		value = true,
	},
	projectileFade = {
		name = 'Fade Projectiles',
		type = 'bool',
		desc = 'Projectile lights smoothly fade out after the projectile disappears.',
		value = true,
	},
	light_override = {
		name = "Override Parameters",
		desc = "Override lights with the following parameters.",
		type = 'bool',
		value = false,
		OnChange = function (self) 
			doOverride = self.value
		end,
		noHotkey = true,
		advanced = true
	},
	light_radius = {
		name = 'Light Radius',
		type = 'number',
		value = 3,
		min = 20, max = 1000, step = 10,
		OnChange = function (self)
			radiusOverride = self.value
			ApplySetting()
		end,
		advanced = true
	},
	light_brightness = {
		name = 'Light Brightness',
		type = 'number',
		value = 2,
		min = 0.05, max = 5, step = 0.05,
		OnChange = function (self) 
			colorBrightness = self.value
			ApplySetting()
		end,
		advanced = true
	},
	light_color = {
		name = 'Light Color',
		type = 'colors',
		value = { 0.8, 0.8, 0.8, 1},
		OnChange = function (self)
			colorOverride = self.value
			ApplySetting()
		end,
		advanced = true
	},
	light_reload = {
		name = 'Reload',
		type = 'button',
		desc = "Reload settings from the next projectile fired.",
		OnChange = function (self)
			wantLoadParams = true
		end,
		advanced = true
	},
}

local gibParams = {r = 0.22, g = 0.15, b = 0.1, radius = 75, gib = true}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local projectileLightTypes = {}
	--[1] red
	--[2] green
	--[3] blue
	--[4] radius
	--[5] BEAMTYPE, true if BEAM

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
		--Shouldnt:
			--AircraftBomb
			--Shield
			--TorpedoLauncher
		
		local weaponDef = WeaponDefs[weaponDefID]
		local customParams = weaponDef.customParams or {}
		
		local skip = false
		
		local lightMultiplier = 0.045
		local r,g,b = weaponDef.visuals.colorR, weaponDef.visuals.colorG, weaponDef.visuals.colorB

		local weaponData = {type=weaponDef.type, r = (r + 0.1) * lightMultiplier, g = (g + 0.1) * lightMultiplier, b = (b + 0.1) * lightMultiplier, radius = 100}
		local recalcRGB = false
		
		if (weaponDef.type == 'Cannon') then
			if customParams.single_hit then
				weaponData.beamOffset = 1
				weaponData.beam = true
			else
				weaponData.radius = 230 * weaponDef.size
				if weaponDef.damageAreaOfEffect ~= nil  then
					weaponData.radius = 230 * ((weaponDef.size*0.6)  + weaponDef.damageAreaOfEffect * 0.009)
				end
				lightMultiplier = 0.066
				recalcRGB = true
			end
		elseif (weaponDef.type == 'LaserCannon') then
			weaponData.radius = 70 * weaponDef.size
		elseif (weaponDef.type == 'DGun') then
			weaponData.radius = 320
		elseif (weaponDef.type == 'MissileLauncher') then
			weaponData.radius = 260 * weaponDef.size
			if weaponDef.damageAreaOfEffect ~= nil  then
				weaponData.radius = 260 * ((weaponDef.size*0.6)  + weaponDef.damageAreaOfEffect * 0.009)
			end
			lightMultiplier = 0.02 + (weaponDef.size/30)
			recalcRGB = true
		elseif (weaponDef.type == 'StarburstLauncher') then
			weaponData.radius = 220
		elseif (weaponDef.type == 'Flame') then
			weaponData.radius = 70 * weaponDef.size
			lightMultiplier = 0.05
			recalcRGB = true
			skip = true
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
		
		if customParams.light_multiplier ~= nil then
			recalcRGB = true 
			lightMultiplier = customParams.light_multiplier
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
			b = colorList[3]
		end
		
		if recalcRGB then
			weaponData.r = (r + 0.1) * lightMultiplier
			weaponData.g = (g + 0.1) * lightMultiplier
			weaponData.b = (b + 0.1) * lightMultiplier
		end
		
		if weaponData.radius > 0 and not customParams.fake_weapon and skip == false then
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

	if not lightsEnabled then
		return beamLights, beamLightCount, pointLights, pointLightCount
	end

	local projectiles = spGetVisibleProjectiles()
	local projectileCount = #projectiles
	if (not options.projectileFade.value) and projectileCount == 0 then
		return beamLights, beamLightCount, pointLights, pointLightCount
	end
	
	local fps = Spring.GetFPS()
	local cameraHeight = math.floor(GetCameraHeight()*0.01)*100
	--Spring.Echo("cameraHeight", cameraHeight, "fps", fps)
	local projectilePresent = {}
	local projectileDrawParams = options.projectileFade.value and {}
	
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
			if wantLoadParams and lightParams then
				LoadParams(lightParams)
			end
			if lightParams and (not options.useLOD.value or ProjectileLevelOfDetailCheck(lightParams, pID, fps, cameraHeight)) then
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
	
	if options.projectileFade.value then
		local frame = Spring.GetGameFrame()
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
	
	return beamLights, beamLightCount, pointLights, pointLightCount
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	if WG.DeferredLighting_RegisterFunction then
		WG.DeferredLighting_RegisterFunction(GetProjectileLights)
		projectileLightTypes = GetLightsFromUnitDefs()
	end
end