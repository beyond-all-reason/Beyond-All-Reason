
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

local additionalLightingFlashes = true
local additionalLightingFlashesMult = 0.6
local additionalNukeLightingFlashes = true

local globalLightMult = 1.4
local globalRadiusMult = 1.4
local globalLightMultLaser = 1.35	-- gets applied on top op globalRadiusMult
local globalRadiusMultLaser = 0.9	-- gets applied on top op globalRadiusMult
local globalLifeMult = 0.58

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

			params.yoffset = 15 + (params.radius/25)

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


			params.explosion = {
				life = params.life,
				orgMult = params.orgMult,
				py = params.yoffset,
				param = {
					type = 'explosion',
					r = params.r,
					g = params.g,
					b = params.b,
					radius = params.radius,
				},
			}

			if params.wtype == 'Cannon' then
				params.barrelflare = {
					life = (3+(params.life/2.5)) * globalLifeMult,
					orgMult = 0.33 + (params.orgMult*0.19),
					param = {
						type = 'explosion',
						r = (params.r + 1) / 2,
						g = (params.g + 1) / 2,
						b = (params.b + 1) / 2,
						radius = 20 + (params.radius*0.8)
					},
				}
			end

			if params.wtype == 'LaserCannon' then
				params.barrelflare = {
					life = (4+(params.life/2)) * globalLifeMult,
					orgMult = 0.38 + (params.orgMult*0.6),
					param = {
						type = 'explosion',
						r = (params.r + 1) / 2,
						g = (params.g + 1) / 2,
						b = (params.b + 1) / 2,
						radius = 115 + (params.radius*5)
					},
				}
			end

			if not params.noheatdistortion and params.radius > 75 then
				local strength,animSpeed,life,heat,sizeGrowth,size,force
				if params.type == 'paralyzer' then
					strength = 10
					animSpeed = 0.1
					life = params.life*0.6 + (params.radius/80)
					sizeGrowth = 0
					heat = 15
					size =  params.radius/16
					force = {0,0.15,0}
				else
					animSpeed = 1.3
					sizeGrowth = 0.6
					if params.type == 'flame' then
						strength = 1 + (params.life/25)
						size = params.radius/2.35
						life = params.life*0.64 + (params.radius/90)
						force = {1,5.5,1}
						heat = 8
					else
						strength = params.heatstrength
						size = params.heatradius
						life = params.heatlife
						force = {0,0.35,0}
						heat = 1
					end
				end

				params.explosionJitterparticle = {
					layer = -35,
					life = life,
					py = 10,
					size = size,
					sizeGrowth = sizeGrowth,
					strength = strength,
					animSpeed = animSpeed,
					heat = heat,
					force = force,
				}
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
		local r,g,b = weaponDef.visuals.colorR, weaponDef.visuals.colorG, weaponDef.visuals.colorB

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
			weaponData.radius = 77 * weaponDef.size
			weaponData.beam = true
			lightMultiplier = 0.18
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
			b = colorList[3]
		end

		if recalcRGB or globalLightMult ~= 1 or globalLightMultLaser ~= 1 then
			local laserMult = 1
			if weaponDef.type == 'BeamLaser' or weaponDef.type == 'LightningCannon' or weaponDef.type ==  'LaserCannon' then
				laserMult = globalLightMultLaser
			end
			weaponData.r = (r + 0.1) * lightMultiplier * globalLightMult * laserMult
			weaponData.g = (g + 0.1) * lightMultiplier * globalLightMult * laserMult
			weaponData.b = (b + 0.1) * lightMultiplier * globalLightMult * laserMult
		end


		if (weaponDef.type == 'Cannon') then
			weaponData.glowradius = weaponData.radius
		end

		weaponData.radius = weaponData.radius * globalRadiusMult
		if weaponDef.type == 'BeamLaser' or weaponDef.type == 'LightningCannon' or weaponDef.type ==  'LaserCannon' then
			weaponData.radius = weaponData.radius * globalRadiusMultLaser
		end


		if not skip and weaponData ~= nil and weaponData.radius > 0 and customParams.fake_weapon == nil then

			plighttable[weaponDefID] = weaponData
		end
	end

	return plighttable
end


local plighttable = GetLightsFromUnitDefs()

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
return {weaponConf, plighttable}