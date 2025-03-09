-- This configures all the lights weapon effects, including:
	-- Projectile attached lights
	-- Muzzle flashes
	-- Explosion lights
	-- Pieceprojectiles (gibs on death) lights
-- note that weapondef customparams need to be moved out of unitdefs, for ease of configability.
	-- customparams= {
		-- expl_light_skip = bool , -- no explosion on projectile death
		-- expl_light_color = {rgba} , -- color of the explosion light at peak?
		-- expl_light_opacity = a, -- alpha or power of the light
		-- expl_light_mult = ,-- fuck if i know?
		-- expl_light_radius = , -- radius
		-- expl_light_radius_mult = , -- why?
		-- expl_light_life = , life of the expl light?
-- concept is:
	-- Make a few base classes of lights
	-- auto-assign the majority
	-- offer overrideability
-- note that Y offset will be very different for points and for beams!
-- (c) Beherith (mysterme@gmail.com)

local exampleLight = {
	lightType = 'point', -- or cone or beam
	pieceName = nil, -- optional
	yOffset = 10, -- optional, gives extra Y height
	fraction = 3, -- optional, only every nth projectile gets the effect (randomly)
	lightConfig = {
		posx = 0, posy = 0, posz = 0, radius = 0,
		r = 1, g = 1, b = 1, a = 1,
		color2r = 1, color2g = 1, color2b = 1, colortime = 15, -- point lights only, colortime in seconds for unit-attached
		dirx = 0, diry = 0, dirz = 1, theta = 0.5,  -- cone lights only, specify direction and half-angle in radians
		pos2x = 100, pos2y = 100, pos2z = 100, -- beam lights only, specifies the endpoint of the beam
		modelfactor = 1, specular = 1, scattering = 1, lensflare = 1,
		lifetime = 0, sustain = 1, 	aninmtype = 0, -- unused
	},
}


-- Local Variables

--------------------------------------------------------------------------------
-- Config

-- Config order is:
-- Auto-assign a lightclass to each weaponDefID
-- Override on a per-weaponDefID basis, and copy table before overriding

--------------------------------General Base Light Classes for further useage --------
local BaseClasses = {
	LaserProjectile = {
		lightType = 'beam', -- or cone or beam
		lightConfig = {
			posx = 0, posy = 10, posz = 0, radius = 100,
			r = 1, g = 1, b = 1, a = 0.075,
			pos2x = 100, pos2y = 1000, pos2z = 100, -- beam lights only, specifies the endpoint of the beam
			modelfactor = 1, specular = 0.5, scattering = 0.1, lensflare = 1,
			lifetime = 0, sustain = 1, 	aninmtype = 0, -- unused
		},
	},

	CannonProjectile = {
		lightType = 'point', -- or cone or beam
		lightConfig = {
			posx = 0, posy = 10, posz = 0, radius = 125,
			r = 1, g = 0.8, b = 0.45, a = 0.11,
			--color2r = 0.5, color2g = 0.4, color2b = 0.23, colortime = 1.5, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.5, specular = 0.6, scattering = 0.5, lensflare = 0,
			lifetime = 0, sustain = 0, 	aninmtype = 0, -- unused
		},
	},


	MissileProjectile = {
		lightType = 'point', -- or cone or beam
		lightConfig = {
			posx = 0, posy = 0, posz = 0, radius = 150,
			r = 1, g = 0.7, b = 0.2, a = 0.15,
			color2r = 0.6, color2g = 0.4, color2b = 0.10, colortime = 1.6, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.3, specular = 0.1, scattering = 0.6, lensflare = 8,
			lifetime = 0, sustain = 0, 	aninmtype = 0, -- unused
		},
	},

	LaserAimProjectile = {
		lightType = 'cone', -- or cone or beam
		lightConfig = {
			posx = 0, posy = 0, posz = 0, radius = 500,
			r = 5, g = 0, b = 0, a = 1,
			dirx = 1, diry = 0, dirz = 1, theta = 0.02,  -- cone lights only, specify direction and half-angle in radians
			modelfactor = 10, specular = 0.5, scattering = 1, lensflare = 1,
			lifetime = 0, sustain = 1, 	aninmtype = 0, -- unused
		},
	},

	TorpedoProjectile = {
		lightType = 'cone', -- or cone or beam
		lightConfig = {
			posx = 0, posy = 0, posz = 0, radius = 100,
			r = 1, g = 1, b = 1, a = 1,
			dirx = 1, diry = 0, dirz = 1, theta = 0.15,  -- cone lights only, specify direction and half-angle in radians
			modelfactor = 1, specular = 0, scattering = 1, lensflare = 1,
			lifetime = 0, sustain = 1, 	aninmtype = 0, -- unused
		},
	},

	FlameProjectile = {
		lightType = 'point', -- or cone or beam
		fraction = 2, -- only spawn every nth light
		lightConfig = {
			posx = 0, posy = 15, posz = 0, radius = 25,
			r = 1.0, g = 0.9, b = 0.6, a = 0.086,
			color2r = 0.75, color2g = 0.45, color2b = 0.22, colortime = 15, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.2, specular = 0.5, scattering = 0.8, lensflare = 0,
			lifetime = 23, sustain = 0, aninmtype = 0, -- unused
		},
	},

	Explosion = { -- spawned on explosions
		lightType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		lightConfig = {
			posx = 0, posy = 0, posz = 0, radius = 240,
			r = 2, g = 2, b = 2, a = 0.6,
			color2r = 0.7, color2g = 0.55, color2b = 0.28, colortime = 0.1, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.15, specular = 0.15, scattering = 0.4, lensflare = 1,
			lifetime = 12, sustain = 3, aninmtype = 0, -- unused
		},
	},

	MuzzleFlash = { -- spawned on projectilecreated
		lightType = 'point', -- or cone or beam
		lightConfig = {
			posx = 0, posy = 0, posz = 0, radius = 150,
			r = 2, g = 2, b = 2, a = 0.7,
			color2r = 0.75, color2g = 0.72, color2b = 0.6, colortime = 0, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.8, specular = 0.5, scattering = 0.6, lensflare = 8,
			lifetime = 6, sustain = 0.0035, aninmtype = 0, -- unused
		},
	},
}


local SizeRadius = {
	Pico = 			26,
	Nano = 			34,
	Micro = 		44,
	Tiniest = 		56,
	Tiny = 			72,
	Smallest = 		90,
	Smaller = 		115,
	Small = 		140,
	Smallish = 		165,
	SmallMedium = 	190,
	Medium = 		220,
	Mediumer = 		260,
	MediumLarge = 	300,
	Large = 		400,
	Larger = 		500,
	Largest = 		650,
	Mega = 			800,
	MegaXL = 		1000,
	MegaXXL = 		1500,
	Giga = 			2000,
	Tera = 			3500,
	Planetary = 	5000,
}
local ColorSets = { -- TODO add advanced dual-color sets!
	Red = 		{r = 1, g = 0, b = 0},
	Green = 	{r = 0, g = 1, b = 0},
	Blue = 		{r = 0, g = 0, b = 1},
	Purple = 	{r = 0.7, g = 0.3, b = 1},
	Yellow = 	{r = 1, g = 1, b = 0},
	White = 	{r = 1, g = 1, b = 1},
	Plasma  = 	{r = 1, g = 0.8, b = 0.45},
	HeatRay  = 	{r = 0.88, g = 0.65, b = 0.10},
	Emg  = 		{r = 0.42, g = 0.32, b = 0.07},
	Fire  = 	{r = 0.8, g = 0.3, b = 0.05},
	Warm  = 	{r = 0.7, g = 0.7, b = 0.1},
	Cold  = 	{r = 0.5, g = 0.75, b = 1.0},
	Team  = 	{r = -1, g = -1, b = -1},
}

local globalDamageMult = Spring.GetModOptions().multiplier_weapondamage or 1

local function GetClosestSizeClass(desiredsize)
	local delta = math.huge
	local best = nil
	for classname, size in pairs(SizeRadius) do
		if math.abs(size-desiredsize) < delta then
			delta = math.abs(size-desiredsize)
			best = classname
		end
	end
	return best, SizeRadius[best]
end

local Lifetimes = {Fast = 5, Quick = 10, Moderate = 30, Long = 90, Glacial = 270}

local lightClasses = {}

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		--setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end
local usedclasses = 0
local function GetLightClass(baseClassname, colorkey, sizekey, additionaloverrides)
	local lightClassKey = baseClassname .. (colorkey or "") .. (sizekey or "")
	if additionaloverrides and type(additionaloverrides) == 'table' then
		for k,v in pairs(additionaloverrides) do
			lightClassKey = lightClassKey .. "_" .. tostring(k) .. "=" .. tostring(v)
		end
	end

	if lightClasses[lightClassKey] then
		return lightClasses[lightClassKey]
	else
		lightClasses[lightClassKey] = deepcopy(BaseClasses[baseClassname])
		lightClasses[lightClassKey].lightClassName = lightClassKey
		usedclasses = usedclasses + 1
		local lightConfig = lightClasses[lightClassKey].lightConfig
		if sizekey then
			lightConfig.radius = SizeRadius[sizekey]
		end
		if colorkey then
			lightConfig.r = ColorSets[colorkey].r
			lightConfig.g = ColorSets[colorkey].g
			lightConfig.b = ColorSets[colorkey].b
			if lightClasses[lightClassKey].lightType == 'point' then
				lightConfig.color2r = ColorSets[colorkey].color2r or lightConfig.color2r
				lightConfig.color2g = ColorSets[colorkey].color2g or lightConfig.color2g
				lightConfig.color2b = ColorSets[colorkey].color2b or lightConfig.color2b
				lightConfig.colortime = ColorSets[colorkey].colortime or lightConfig.colortime
			end
		end
		if additionaloverrides then
			for k,v in pairs(additionaloverrides) do
				lightConfig[k] = v
			end
		end
	end
	return lightClasses[lightClassKey]
end

--------------------------------------------------------------------------------

local gibLight = {
	lightType = 'point', -- or cone or beam
	pieceName = nil, -- optional
	lightConfig = {
		posx = 0, posy = 0, posz = 0, radius = 36,
		r = 1, g = 0.9, b = 0.5, a = 0.08,
		color2r = 0.9, color2g = 0.75, color2b = 0.25, colortime = 0.3, -- point lights only, colortime in seconds for unit-attache
		modelfactor = 0.4, specular = 0.5, scattering = 0.5, lensflare = 0,
		lifetime = 300, sustain = 3, aninmtype = 0 -- unused
	},
}

--------------------------------------------------------------------------------

local muzzleFlashLights = {}
local explosionLights = {}
local projectileDefLights  = {
	['default'] = {
		lightType = 'point',
		lightConfig = { posx = 0, posy = 16, posz = 0, radius = 420,
			color2r = 1, color2g = 1, color2b = 1, colortime = 15,
			r = -1, g = 1, b = 1, a = 1,
			modelfactor = 0.2, specular = 1, scattering = 1, lensflare = 1,
			lifetime = 50, sustain = 20, animtype = 0},
	}
}

-----------------------------------

local function AssignLightsToAllWeapons()
	for weaponID=1, #WeaponDefs do
		local weaponDef = WeaponDefs[weaponID]
		local damage = 100
		for cat=0, #weaponDef.damages do
			if Game.armorTypes[cat] and Game.armorTypes[cat] == 'default' then
				damage = weaponDef.damages[cat]
				break
			end
		end

		-- correct damage multiplier modoption to more sane value
		damage = (damage / globalDamageMult) + ((damage * (globalDamageMult-1))*0.25)

		local radius = ((weaponDef.damageAreaOfEffect*2) + (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.35))
		local orgMult = math.clamp(damage/1600, 0.1, 0.6) + (radius/2800)
		local life = 8 + (5*(radius/2000)+(orgMult * 5))
		radius = ((orgMult * 75) + (radius * 2.4)) * 0.33

		local r, g, b = 1, 0.8, 0.45
		local weaponVisuals = weaponDef.visuals
		if weaponVisuals ~= nil and weaponVisuals.colorR ~= nil then
			r = weaponVisuals.colorR
			g = weaponVisuals.colorG
			b = weaponVisuals.colorB
		end
		local muzzleFlash = true
		local explosionLight = true
		local sizeclass = GetClosestSizeClass(radius)
		local t = {}
		local aa = string.find(weaponDef.cegTag, 'aa')
		if aa then
			r, g, b = 1, 0.5, 0.6
			t.color2r, t.color2g, t.color2b = 1, 0.5, 0.6
		end
		if weaponDef.paralyzer then
			r, g, b = 0.5, 0.5, 1
			t.color2r, t.color2g, t.color2b = 0.25, 0.25, 1
		end
		local scavenger = string.find(weaponDef.name, '_scav')
		if scavenger then
			r, g, b = 0.96, 0.3, 1
			t.color2r, t.color2g, t.color2b = 0.96, 0.3, 1
		end
		t.r, t.g, t.b = r, g, b

		-- if string.find(weaponDef.name, 'juno') then
		-- 	radius = 140
		-- 	orgMult = 1
		-- 	r, g, b = 0.45, 1, 0.45
		-- end

		if weaponDef.type == 'BeamLaser' then
			muzzleFlash = false


			if not weaponDef.paralyzer then
				t.r, t.g, t.b = math.min(1, r+0.3), math.min(1, g+0.3), math.min(1, b+0.3)
				t.color2r, t.color2g, t.color2b = r, g, b
			end

			radius = (3.5 * (weaponDef.size * weaponDef.size * weaponDef.size)) + (5 * radius * orgMult)
			t.a = (orgMult * 0.1) / (0.2 + weaponDef.beamtime)
			--projectileDefLights[weaponID].yOffset = 64

			if weaponDef.paralyzer then
				radius = radius * 0.5
			end
			sizeclass = GetClosestSizeClass(radius)
			projectileDefLights[weaponID] = GetLightClass("LaserProjectile", nil, sizeclass, t)

			if not weaponDef.paralyzer then
				radius = ((orgMult * 2500) + radius) * 0.2
				sizeclass = GetClosestSizeClass(radius)
			end

		elseif weaponDef.type == 'LaserCannon' then
			radius = (4 * (weaponDef.size * weaponDef.size * weaponDef.size)) + (3 * radius * orgMult)
			t.a = (orgMult * 0.1) + weaponDef.duration

			sizeclass = GetClosestSizeClass(radius)
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Warm", sizeclass, t)

		elseif weaponDef.type == 'LightningCannon' then
			if not scavenger then
				t.r, t.g, t.b = 0.2, 0.45, 1
			end
			t.a = 0.13 + (orgMult * 0.5)
			sizeclass = GetClosestSizeClass(33 + (radius*2.5))
			projectileDefLights[weaponID] = GetLightClass("LaserProjectile", "Cold", sizeclass, t)

		elseif weaponDef.type == 'MissileLauncher'then
			t.a = orgMult * 0.33
			projectileDefLights[weaponID] = GetLightClass("MissileProjectile", "Warm", sizeclass, t)

		elseif weaponDef.type == 'StarburstLauncher' then
			t.a = orgMult * 0.44
			projectileDefLights[weaponID] = GetLightClass("MissileProjectile", "Warm", sizeclass, t)
			sizeclass = GetClosestSizeClass(radius)
			radius = ((orgMult * 75) + (radius * 4)) * 0.4
			life = 8 + (5*(radius/2000)+(orgMult * 5))

		elseif weaponDef.type == 'Cannon' then
			t.a = orgMult*0.17
			radius = (radius + (weaponDef.size * 35)) * 0.44
			sizeclass = GetClosestSizeClass(radius)
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Plasma", sizeclass, t)
			radius = ((weaponDef.damageAreaOfEffect*2) + (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.35))

		elseif weaponDef.type == 'DGun' then
			muzzleFlash = true --doesnt work
			sizeclass = "Medium"
			t.a = orgMult*0.66
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Warm", sizeclass, t)
			projectileDefLights[weaponID].yOffset = 32

		elseif weaponDef.type == 'TorpedoLauncher' then
			sizeclass = "Small"
			projectileDefLights[weaponID] = GetLightClass("TorpedoProjectile", "Cold", sizeclass, t)

		elseif weaponDef.type == 'Shield' then
			sizeclass = "Large"
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Cold", sizeclass, t)

		-- elseif weaponDef.type == 'AircraftBomb' then
		-- 	t.a = life * 1.8
		-- 	projectileDefLights[weaponID] = GetLightClass("MissileProjectile", "Warm", sizeclass, t)

		elseif weaponDef.type == 'Flame' then
			--sizeclass = "Small"
			sizeclass = GetClosestSizeClass(radius*3)
			t.a = orgMult*0.17 * 2
			projectileDefLights[weaponID] = GetLightClass("FlameProjectile", "Fire", sizeclass, t)
		end

		if muzzleFlash then
			if aa then
				t.r, t.g, t.b = 1, 0.7, 0.85
			end
			if scavenger then
				t.r, t.g, t.b = 0.99, 0.9, 1
			end
			t.a = orgMult*1.15
			t.colortime = 2
			muzzleFlashLights[weaponID] = GetLightClass("MuzzleFlash", "White", GetClosestSizeClass(radius*0.6), t)
			muzzleFlashLights[weaponID].yOffset = muzzleFlashLights[weaponID].lightConfig.radius / 5
		end

		if explosionLight then
			if aa then
				t.r, t.g, t.b = 1, 0.7, 0.85
			end
			if scavenger then
				t.r, t.g, t.b = 0.99, 0.9, 1
			end
			t.lifetime = life
			t.colortime = 25 / life --t.colortime = life * 0.17
			t.a = orgMult

			if weaponDef.type == 'DGun' then
				t.a = orgMult*0.17
			elseif weaponDef.type == 'Flame' then
				t.a = orgMult*0.17
			elseif weaponDef.type == 'BeamLaser' then
				local mult = 0.85
				t.color2r, t.color2g, t.color2b = r*mult, g*mult, b*mult
				t.colortime = 2
				t.lifetime = life * 0.5
				t.a = 0.02 + ((orgMult*0.055) / weaponDef.beamtime) + (weaponDef.range*0.000035)
				radius = 1.2 * ((weaponDef.damageAreaOfEffect*4) + (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.1)) + (weaponDef.range*0.08)
				sizeclass = GetClosestSizeClass(radius)
			elseif weaponDef.type == 'LightningCannon' then
				t.a = orgMult*1.25
				t.color2r = 0.1
				t.color2g = 0.3
				t.color2b = 0.9
				sizeclass = GetClosestSizeClass(radius*1.2)
			else
				if weaponDef.type == 'AircraftBomb' then
					if weaponDef.paralyzer then
						t.r = t.r * 1.7	-- make more red
						t.g = t.g * 0.4	-- make more red
						t.b = t.b * 0.4	-- make more red
						life = life * 1.1	-- too high and it will flicker somehow!
						orgMult = orgMult * 0.15
						t.colortime = 31 / life
					else
						t.r = t.r * 1.7	-- make more red
						t.g = t.g * 0.4	-- make more red
						t.b = t.b * 0.4	-- make more red
						life = life * 1.2
						t.colortime = 19 / life
					end
					t.lifetime = life

				end
				radius = ((weaponDef.damageAreaOfEffect*1.9) + (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.35))
				if string.find(weaponDef.name, 'juno') then
					radius = 675
					orgMult = 0.25
					t.r = 1.05
					t.g = 1.3
					t.b = 0.6
					t.color2r = 0.32
					t.color2g = 0.5
					t.color2b = 0.12
					t.colortime = 200
					t.lifetime = 500
				end
				if weaponDef.customParams.unitexplosion then
					radius = radius * 1.25
					-- make more white
					t.r = (1.7 + t.r) / 2.7
					t.g = (1.7 + t.g) / 2.7
					t.b = (1.7 + t.b) / 2.7
					-- t.r = 3
					-- t.g = 3
					-- t.b = 3
					-- t.color2r = (1.5 + t.color2r) / 2.3
					-- t.color2g = (1.5 + t.color2g) / 2.3
					-- t.color2b = (1.5 + t.color2b) / 2.3
					t.a = orgMult*2.8
					t.lifetime = life * 1.15
					--t.colortime = 8
				else
					-- make more white
					t.r = (1.4 + t.r) / 2.3
					t.g = (1.4 + t.g) / 2.3
					t.b = (1.4 + t.b) / 2.3
					t.a = orgMult*1.6
				end
				local mult = 0.55
				t.color2r, t.color2g, t.color2b = r*mult, g*mult, b*mult
				sizeclass = GetClosestSizeClass(radius)
			end
			if not weaponDef.customParams.noexplosionlight then
				explosionLights[weaponID] = GetLightClass("Explosion", nil, sizeclass, t)
				explosionLights[weaponID].yOffset = explosionLights[weaponID].lightConfig.radius / 5
			end
		end
	end
	Spring.Echo(Spring.GetGameFrame(),"DLGL4 weapons conf using",usedclasses,"light types")
end
AssignLightsToAllWeapons()


-----------------Manual Overrides--------------------
local explosionLightsNames = {}
local muzzleFlashLightsNames = {}
local projectileDefLightsNames = {}

--cortrem
explosionLightsNames["cortrem_tremor_focus_fire"] =
GetLightClass("Explosion", nil, "Tiny", {colortime = 3.5, sustain = 1, lifetime = 1, scattering = 0.7})

explosionLightsNames["cortrem_tremor_spread_fire"] =
GetLightClass("Explosion", nil, "Tiny", {colortime = 3.5, sustain = 1, lifetime = 1, scattering = 0.7})

--corforge
projectileDefLightsNames["corforge_flamethrower_ce"] =
GetLightClass("FlameProjectile", "Fire", "Micro", {r = 1, a = 0.02791886, g = 0.94, b = 0.88})

--armthor
explosionLightsNames["armthor_thunder"] =
GetLightClass("Explosion", nil, "Smallish", {r = 1.5, g = 1.5, b = 1.5, a = 0.08, radius = 120,
										 color2r = 0.3, color2g = 0.3, color2b = 0.4, colortime = 5,
										 sustain = 1.5, lifetime = 5,
										 modelfactor = 0.1, specular = 0.4, scattering = 0.1, lensflare = 4})

--corint
muzzleFlashLightsNames["corint_lrpc"] =
GetLightClass("MuzzleFlash", nil, "Large", {posx = 0, posy = 0, posz = 0, radius = 240,
											color2r = 0.5, color2g = 0.1, color2b = 0, colortime = 50,
											r = 1.2, g = 1.0, b = 0.9, a = 0.5,
											modelfactor = 0.5, specular = 0.3, scattering = 0.3, lensflare = 0,
											lifetime = 17, sustain = 2})
muzzleFlashLightsNames["corint_lrpc"].yOffset = 16

explosionLightsNames["corint_lrpc"] =
GetLightClass("Explosion", nil, "Large", {colortime = 4, sustain = 12, lifetime = 26, scattering = 0.7})

-- muzzleFlashLightsNames["corint_lrpc"] =
-- GetLightClass("MuzzleFlash", nil, "Large", {posx = 0, posy = 0, posz = 0, radius = 240,
-- 											color2r = 0.5, color2g = 0.1, color2b = 0, colortime = 50,
-- 											r = 1.2, g = 1.0, b = 0.9, a = 0.5,
-- 											modelfactor = 0.5, specular = 0.3, scattering = 0.3, lensflare = 0,
-- 											lifetime = 17, sustain = 2})
-- muzzleFlashLightsNames["corint_lrpc"].yOffset = 16



--armbrtha
muzzleFlashLightsNames["armbrtha_lrpc"] =
GetLightClass("MuzzleFlash", nil, "Medium", {posx = 0, posy = 0, posz = 0,
											 color2r = 0.3, color2g = 0.1, color2b = 0.05, colortime = 13,
											 r = 1.2, g = 1.1, b = 1.0, a = 0.6,
											 modelfactor = 0.5, specular = 0.3, scattering = 0.3, lensflare = 0,
											 lifetime = 20, sustain = 2})
muzzleFlashLightsNames["armbrtha_lrpc"].yOffset = 8
explosionLightsNames["armbrtha_lrpc"] =
GetLightClass("Explosion", nil, "Large", {colortime = 4, sustain = 12, lifetime = 26, scattering = 0.7})

--armvulc
muzzleFlashLightsNames["armvulc_rflrpc"] =
GetLightClass("MuzzleFlash", nil, "Medium", {posx = 0, posy = 0, posz = 0,
											 r = 1.2, g = 1.1, b = 1.0, a = 0.5,
											 color2r = 0.3, color2g = 0.12, color2b = 0.05, colortime = 4,
											 modelfactor = 0.5, specular = 0.3, scattering = 2.8, lensflare = 4,
											 lifetime = 20, sustain = 2})
muzzleFlashLightsNames["armvulc_rflrpc"].yOffset = 4
explosionLightsNames["armvulc_rflrpc"] =
GetLightClass("Explosion", nil, "Large", {colortime = 3.5, sustain = 14, lifetime = 26, scattering = 0.7})

--corbuzz
muzzleFlashLightsNames["corbuzz_rflrpc"] =
GetLightClass("MuzzleFlash", nil, "Medium", {posx = 0, posy = 0, posz = 0,
											 r = 1.2, g = 1.1, b = 1.0, a = 0.5,
											 color2r = 0.3, color2g = 0.12, color2b = 0.05, colortime = 4,
											 modelfactor = 0.5, specular = 0.3, scattering = 2.8, lensflare = 4,
											 lifetime = 20, sustain = 2})
muzzleFlashLightsNames["corbuzz_rflrpc"].yOffset = 4
explosionLightsNames["corbuzz_rflrpc"] =
GetLightClass("Explosion", nil, "Large", {colortime = 3.5, sustain = 14, lifetime = 26, scattering = 0.7})


--corsilo
explosionLightsNames["corsilo_crblmssl"] =
GetLightClass("Explosion", nil, "Tera", {r = 3, g = 3, b = 2.8, a = 0.2,
										 color2r = 1.0, color2g = 0.6, color2b = 0.18, colortime = 120,
										 sustain = 30, lifetime = 200,
										 modelfactor = 0.1, specular = 0.2, scattering = 0.1, lensflare = 4})

--corsilo engine
projectileDefLightsNames["corsilo_crblmssl"] =
GetLightClass("MissileProjectile", "Warm", "Large", {a = 0.6,
										modelfactor = 0.1, specular = 0.1, scattering = 0.5, lensflare = 0})

--corsilo SCAV
explosionLightsNames["corsilo_scav_crblmssl"] =
GetLightClass("Explosion", nil, "Tera", {r = 2, g = 1, b = 3, a = 0.18,
										 color2r = 0.6, color2g = 0.3, color2b = 1, colortime = 120,
										 sustain = 30, lifetime = 200,
										 modelfactor = 0.1, specular = 0.2, scattering = 0.1, lensflare = 4})

--corsilo engine SCAV
projectileDefLightsNames["corsilo_scav_crblmssl"] =
GetLightClass("MissileProjectile", nil, "Large", {r = 2, g = 1, b = 3, a = 0.4,
										color2r = 0.75, color2g = 0.3, color2b = 0.9,
										modelfactor = 0.1, specular = 0.1, scattering = 0.5, lensflare = 0})

--armsilo
explosionLightsNames["armsilo_nuclear_missile"] =
GetLightClass("Explosion", nil, "Giga", {r = 3, g = 3, b = 2.8, a = 0.18,
										 color2r = 1.0, color2g = 0.6, color2b = 0.18, colortime = 110,
										 sustain = 25, lifetime = 180,
										 modelfactor = 0.1, specular = 0.2, scattering = 0.1, lensflare = 4})

--armsilo engine
projectileDefLightsNames["armsilo_nuclear_missile"] =
GetLightClass("MissileProjectile", "Warm", "Large", {a = 0.6,
													 modelfactor = 0.1, specular = 0.1, scattering = 0.5, lensflare = 0})

--armsilo SCAV
explosionLightsNames["armsilo_scav_nuclear_missile"] =
GetLightClass("Explosion", nil, "Giga", {r = 2, g = 1, b = 3, a = 0.18,
										 color2r = 0.6, color2g = 0.3, color2b = 1, colortime = 110,
										 sustain = 25, lifetime = 180,
										 modelfactor = 0.1, specular = 0.2, scattering = 0.1, lensflare = 4})

--armsilo engine SCAV
projectileDefLightsNames["armsilo_scav_nuclear_missile"] =
GetLightClass("MissileProjectile", nil, "Large", {r = 2, g = 1, b = 3, a = 0.4,
										color2r = 0.75, color2g = 0.3, color2b = 0.9,
										modelfactor = 0.1, specular = 0.1, scattering = 0.4, lensflare = 0})

--cortron
explosionLightsNames["cortron_cortron_weapon"] =
GetLightClass("Explosion", nil, "Large", {r = 3, g = 2.5, b = 2.0, a = 0.25,
										  color2r = 0.5, color2g = 0.2, color2b = 0.09, colortime = 10,
										  sustain = 4, lifetime = 120,
										  modelfactor = 0.1, specular = 0.2, scattering = 0.1, lensflare = 4})

--legbart
explosionLightsNames["legbart_clusternapalm"] =
GetLightClass("Explosion", "Fire", "SmallMedium", {r = 0.32, g = 0.24, b = 0.1, a = 0.1,
										 color2r = 0.8, color2g = 0.4, color2b = 0.1, colortime = 44,
										 sustain = 120, lifetime = 180,
										 modelfactor = -0.3, specular = -0.3, scattering = 0.3, lensflare = 0})

--legbar
explosionLightsNames["legbar_clusternapalm"] =
GetLightClass("Explosion", "Fire", "Small", {r = 0.32, g = 0.24, b = 0.1, a = 0.005,
										 color2r = 0.8, color2g = 0.4, color2b = 0.1, colortime = 44,
										 sustain = 120, lifetime = 180,
										 modelfactor = -0.3, specular = -0.3, scattering = 0.3, lensflare = 0})

--leginf
explosionLightsNames["leginf_rapidnapalm"] =
GetLightClass("Explosion", "Fire", "Small", {r = 0.32, g = 0.24, b = 0.1, a = 0.001,
										 color2r = 0.8, color2g = 0.4, color2b = 0.1, colortime = 180,
										 sustain = 30, lifetime = 180,
										 modelfactor = -0.3, specular = -0.3, scattering = 0.3, lensflare = 0})

--legnap
explosionLightsNames["legnap_napalmbombs"] =
GetLightClass("Explosion", "Fire", "Small", {r = 0.32, g = 0.24, b = 0.1, a = 0.1,
										 color2r = 0.8, color2g = 0.4, color2b = 0.1, colortime = 44,
										 sustain = 120, lifetime = 180,
										 modelfactor = -0.3, specular = -0.3, scattering = 0.3, lensflare = 0})

--legperdition
explosionLightsNames["legperdition_napalmmissile"] =
GetLightClass("Explosion", "Fire", "Large", {r = 0.32, g = 0.24, b = 0.1, a = 0.1,
										 color2r = 0.8, color2g = 0.4, color2b = 0.1, colortime = 44,
										 sustain = 120, lifetime = 180,
										 modelfactor = -0.3, specular = -0.3, scattering = 0.3, lensflare = 0})

--legphoenix
explosionLightsNames["legphoenix_skybeam"] =
GetLightClass("Explosion", "Fire", "Small", {r = 0.54, g = 0.45, b = 0.12, a = 0.35,
										 color2r = 1.2, color2g = 0.5, color2b = 0.2, colortime = 0.25,
										 sustain = 2, lifetime = 3,
										 modelfactor = -0.3, specular = -0.3, scattering = 0.45, lensflare = 0})

projectileDefLightsNames["legphoenix_skybeam"] =
GetLightClass("LaserProjectile", "Warm", "Tiny", {a = 0.25,
											r = 1.0, g = 0.65, b = 0.1,
											color2r = 0.3, color2g = 0.1, color2b = 0.03, colortime = 15,
											pos2x = 0, pos2y = 0, pos2z = 0,
											modelfactor = 0.5, specular = 0.05, scattering = 1.3, lensflare = 16,
											lifetime = 3, sustain = 2,})

--legbastion
explosionLightsNames["legbastion_pineappleofdoom"] =
GetLightClass("Explosion", "Fire", "Medium", {r = 0.26, g = 0.22, b = 0.06, a = 0.25,
										 color2r = 1.2, color2g = 0.5, color2b = 0.2, colortime = 0.3,
										 sustain = 2, lifetime = 4,
										 modelfactor = -0.3, specular = -0.3, scattering = 0.55, lensflare = 0})

explosionLightsNames["legbastion_pineappleofdoom"].yOffset = 38

projectileDefLightsNames["legbastion_pineappleofdoom"] =
GetLightClass("LaserProjectile", "Warm", "Smaller", {r = 1.0, g = 0.65, b = 0.1, a = 0.18,
											color2r = 0.15, color2g = 0.04, color2b = 0.015, colortime = 0.03,
											--pos2x = 0, pos2y = 0, pos2z = 0,
											modelfactor = 0.5, specular = 0.05, scattering = 0.3, lensflare = 0,
											lifetime = 3, sustain = 2})

--leginc
explosionLightsNames["leginc_heatraylarge"] =
GetLightClass("Explosion", "Fire", "Smaller", {r = 0.54, g = 0.45, b = 0.12, a = 0.15,
										 color2r = 1.2, color2g = 0.5, color2b = 0.2, colortime = 0.3,
										 sustain = 2, lifetime = 3,
										 modelfactor = -0.3, specular = -0.1, scattering = 1.95, lensflare = 0})

explosionLightsNames["leginc_heatraylarge"].yOffset = 32

projectileDefLightsNames["leginc_heatraylarge"] =
GetLightClass("LaserProjectile", "Warm", "Smallest", {r = 1.0, g = 0.65, b = 0.1, a = 0.15,
											color2r = 0.15, color2g = 0.05, color2b = 0.015, colortime = 0.03,
											--pos2x = 0, pos2y = 0, pos2z = 0,
											modelfactor = 0.3, specular = -0.05, scattering = 0.3, lensflare = 16,
											sustain = 2, lifetime = 3, })

--legeheatraymech
explosionLightsNames["legeheatraymech_heatray1"] =
GetLightClass("Explosion", "Fire", "Smaller", {r = 0.54, g = 0.45, b = 0.12, a = 0.15,
										 color2r = 1.2, color2g = 0.5, color2b = 0.2, colortime = 0.3,
										 sustain = 2, lifetime = 3,
										 modelfactor = -0.3, specular = -0.1, scattering = 1.95, lensflare = 0})

explosionLightsNames["legeheatraymech_heatray1"].yOffset = 32

projectileDefLightsNames["legeheatraymech_heatray1"] =
GetLightClass("LaserProjectile", "Warm", "Smallest", {r = 1.0, g = 0.65, b = 0.1, a = 0.15,
											color2r = 0.15, color2g = 0.05, color2b = 0.015, colortime = 0.03,
											--pos2x = 0, pos2y = 0, pos2z = 0,
											modelfactor = 0.3, specular = -0.05, scattering = 0.3, lensflare = 16,
											sustain = 2, lifetime = 3, })


--armthundt4
explosionLightsNames["armthundt4_armbomb"] =
GetLightClass("Explosion", nil, "Large", {r = 2, g = 1.5, b = 1.0, a = 0.22,
										  color2r = 0.9, color2g = 0.5, color2b = 0.15, colortime = 65,
										  sustain = 4, lifetime = 55,
										  modelfactor = 0.1, specular = 0.4, scattering = 0.4, lensflare = 6})

--armmerl
projectileDefLightsNames["armmerl_armtruck_rocket"] =
GetLightClass("MissileProjectile", "Warm", "Small", {a = 0.60,
											modelfactor = 0.1, specular = 0.01, scattering = 0.5, lensflare = 8})

--armmerl
projectileDefLightsNames["corvroc_cortruck_rocket"] =
GetLightClass("MissileProjectile", "Warm", "Small", {a = 0.60,
											modelfactor = 0.1, specular = 0.01, scattering = 0.5, lensflare = 8})

--corkorg
projectileDefLightsNames["corkorg_corkorg_laser"] =
GetLightClass("LaserProjectile", nil, "Medium", {a = 0.08,
											r = 1.0, g = 0.65, b = 0.1,
											color2r = 0.3, color2g = 0.1, color2b = 0.03, colortime = 10,
											pos2x = 0, pos2y = 100, pos2z = 0,
											modelfactor = 0.5, specular = 0.05, scattering = 0.05, lensflare = 16,
											lifetime = 60, sustain = 4})

muzzleFlashLightsNames["corkorg_corkorg_laser"] =
GetLightClass("MuzzleFlash", nil, "Large", {posx = 0, posy = 48, posz = 0,
											 r = 1.2, g = 1.1, b = 0.5, a = 0.9,
											 color2r = 0.3, color2g = 0.12, color2b = 0.05, colortime = 10,
											 modelfactor = 0.5, specular = 0.3, scattering = 2.8, lensflare = 9,
											 lifetime = 120, sustain = 4})

muzzleFlashLightsNames["corkorg_corkorg_laser"].yOffset = 32

--corkorg_shotgun
projectileDefLightsNames["corkorg_corkorg_fire"] =
GetLightClass("CannonProjectile", "Plasma", "Smaller", {a = 0.04,
											modelfactor = 0.2, specular = 0.05, scattering = 0.3, lensflare = 3})

--corkorg_rocket
projectileDefLightsNames["corkorg_corkorg_rocket"] =
GetLightClass("MissileProjectile", "Warm", "SmallMedium", {a = 0.60,
											modelfactor = 0.5, specular = 0.05, scattering = 0.45, lensflare = 5})

--corkorg_scav
projectileDefLightsNames["corkorg_scav_corkorg_laser"] =
GetLightClass("LaserProjectile", "Purple", "Large", {a = 0.15,
											color2r = 0.5, color2g = 0.3, color2b = 0.2, colortime = 10,
											modelfactor = 0.5, specular = 0.2, scattering = 0.1, lensflare = 0,
											lifetime = 4, sustain = 0})

--cordoomt3
projectileDefLightsNames["cordoomt3_armagmheat"] =
GetLightClass("LaserProjectile", "HeatRay", "Mediumer", {a = 0.09,
											color2r = 0.5, color2g = 0.3, color2b = 0.2, colortime = 10,
											modelfactor = 0.5, specular = 0.1, scattering = 0.1, lensflare = 0,
											lifetime = 4, sustain = 0})

--armjuno
projectileDefLightsNames["armjuno_juno_pulse"] =
GetLightClass("MissileProjectile", "Green", "SmallMedium", {r = 0.02, g = 0.05, b = 0.01, a = 0.25,
											color2r = 0.88, color2g = 1.5, color2b = 0.6, colortime = 150,
											--lifetime = 200,
											--color2r = 0.75, color2g = 0.9, color2b = 0.3, colortime = 25,
											modelfactor = 0.3, specular = 0.1, scattering = 0.4, lensflare = 7})
explosionLightsNames["armjuno_juno_pulse"] =
GetLightClass("Explosion", "Green", "Largest", {a = 0.6,
											posx = 0, posy = 100, posz = 0,
											r = 0.9, g = 1.1, b = 0.45,
	 										color2r = 0.32, color2g = 0.5, color2b = 0.12, colortime = 100,
											sustain = 15, lifetime = 500,
    										modelfactor = 0.1, specular = 0.2, scattering = 0.3, lensflare = 6})

--armjuno SCAV
projectileDefLightsNames["armjuno_scav_juno_pulse"] =
GetLightClass("MissileProjectile", "Green", "Medium", {r = 0.8, g = 0.4, b = 1.5, a = 0.45,
											color2r = 0.75, color2g = 0.3, color2b = 0.9, colortime = 25,
											modelfactor = 0.3, specular = 0.1, scattering = 0.3, lensflare = 8})
explosionLightsNames["armjuno_scav_juno_pulse"] =
GetLightClass("Explosion", "Green", "Largest", {a = 0.6,
											posx = 0, posy = 100, posz = 0,
											r = 0.75, g = 0.6, b = 1.0,
	 										color2r = 0.36, color2g = 0.12, color2b = 0.48, colortime = 75,
											sustain = 15, lifetime = 500,
    										modelfactor = 0.1, specular = 0.2, scattering = 0.3, lensflare = 6})

--corjuno
projectileDefLightsNames["corjuno_juno_pulse"] =
GetLightClass("MissileProjectile", "Green", "SmallMedium", {r = 0.02, g = 0.05, b = 0.01, a = 0.25,
											color2r = 0.88, color2g = 1.5, color2b = 0.6, colortime = 150,
											--lifetime = 200,
											--color2r = 0.75, color2g = 0.9, color2b = 0.3, colortime = 25,
											modelfactor = 0.3, specular = 0.1, scattering = 0.4, lensflare = 7})
explosionLightsNames["corjuno_juno_pulse"] =
GetLightClass("Explosion", "Green", "Largest", {a = 0.6,
											posx = 0, posy = 100, posz = 0,
											r = 0.9, g = 1.1, b = 0.45,
	 										color2r = 0.32, color2g = 0.5, color2b = 0.12, colortime = 50,
											sustain = 10, lifetime = 400,
    										modelfactor = 0.1, specular = 0.2, scattering = 0.3, lensflare = 6})

--corjuno SCAV
projectileDefLightsNames["corjuno_scav_juno_pulse"] =
GetLightClass("MissileProjectile", "Green", "Medium", {r = 0.8, g = 0.4, b = 1.5, a = 0.45,
											color2r = 0.75, color2g = 0.3, color2b = 0.9, colortime = 25,
											modelfactor = 0.3, specular = 0.1, scattering = 0.3, lensflare = 8})
explosionLightsNames["corjuno_scav_juno_pulse"] =
GetLightClass("Explosion", "Green", "Largest", {a = 0.6,
											posx = 0, posy = 100, posz = 0,
											r = 0.75, g = 0.6, b = 1.0,
	 										color2r = 0.36, color2g = 0.12, color2b = 0.48, colortime = 75,
											sustain = 10, lifetime = 400,
    										modelfactor = 0.1, specular = 0.2, scattering = 0.3, lensflare = 6})
--scavengerbossv4
explosionLightsNames['scavengerbossv4_normal_turbo_napalm'] =
GetLightClass("Explosion", "Fire", "SmallMedium", {r = 0.54, g = 0.45, b = 0.12, a = 0.29,
										 color2r = 1.2, color2g = 0.5, color2b = 0.2, colortime = 0.03,
										 sustain = 40, lifetime = 150,
										 modelfactor = 0.3, specular = 0.8, scattering = 1.5, lensflare = 0})
--duplicate lights from scavengerbossv4_normal_turbo_napalm for all scavengerbossv4 variants, including _scav
local scavengerBossV4Table = {'scavengerbossv4_veryeasy_turbo_napalm', 'scavengerbossv4_easy_turbo_napalm', 'scavengerbossv4_hard_turbo_napalm', 'scavengerbossv4_veryhard_turbo_napalm', 'scavengerbossv4_epic_turbo_napalm',
 'scavengerbossv4_veryeasy_scav_turbo_napalm', 'scavengerbossv4_easy_scav_turbo_napalm', 'scavengerbossv4_normal_scav_turbo_napalm', 'scavengerbossv4_hard_scav_turbo_napalm', 'scavengerbossv4_veryhard_scav_turbo_napalm', 'scavengerbossv4_epic_scav_turbo_napalm'}
for _, name in pairs(scavengerBossV4Table) do
	explosionLightsNames[name] = table.copy(explosionLightsNames['scavengerbossv4_normal_turbo_napalm'])
end
-- --armanni
-- projectileDefLightsNames["armanni_ata"] =
-- GetLightClass("LaserProjectile", "Blue", "Medium", {a = 0.09,
-- 											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 4,
-- 											modelfactor = 0.5, specular = 0.1, scattering = 0.1, lensflare = 0,
-- 											lifetime = 0, sustain = 0})

-- --armannit3
-- projectileDefLightsNames["armannit3_ata"] =
-- GetLightClass("LaserProjectile", "Blue", "Mediumer", {a = 0.09,
-- 											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 4,
-- 											modelfactor = 0.4, specular = 0.1, scattering = 0.1, lensflare = 0,
-- 											lifetime = 0, sustain = 0})

-- --armannit3_scav
-- projectileDefLightsNames["armannit3_scav_ata"] =
-- GetLightClass("LaserProjectile", "Purple", "Mediumer", {a = 0.09,
-- 											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 4,
-- 											modelfactor = 0.4, specular = 0.1, scattering = 0.1, lensflare = 0,
-- 											lifetime = 0, sustain = 0})

--[[
--armpw
explosionLightsNames["armpw_emg"] =
GetLightClass("Explosion", nil, "Micro", {r = 2.4, g = 1.8, b = 1.0, a = 0.12, colortime = 2.4,
											sustain = 8, lifetime = 14,
											modelfactor = 0.2, specular = 0.2, scattering = 0.4})
projectileDefLightsNames["armpw_emg"] =
GetLightClass("CannonProjectile", "Emg", "Tiny", {a = 0.1, radius = 25,
											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 2,
											modelfactor = 0.5, specular = 0.2, scattering = 0.1, lensflare = 0,
											lifetime = 3, sustain = 0})

--armfast
explosionLightsNames["armfast_arm_fast"] =
GetLightClass("Explosion", nil, "Micro", {r = 2.8, g = 2.2, b = 1.2, a = 0.14, colortime = 2.8,
											sustain = 8, lifetime = 22, scattering = 0.7})
projectileDefLightsNames["armfast_arm_fast"] =
GetLightClass("CannonProjectile", "Emg", "Tiny", {a = 0.1, radius = 25,
											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 2,
											modelfactor = 0.5, specular = 0.2, scattering = 0.1, lensflare = 0,
											lifetime = 3, sustain = 0})

--armanni_scav
-- could use a custom script that replaces color for all _scav units with "purple"
projectileDefLightsNames["armanni_scav_ata"] =
GetLightClass("LaserProjectile", "Purple", "Larger", {a = 0.12,
											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 4,
											modelfactor = 0.5, specular = 0.2, scattering = 0.1, lensflare = 0,
											lifetime = 0, sustain = 0})


--cordoom
projectileDefLightsNames["cordoom_atadr"] =
GetLightClass("LaserProjectile", "Blue", "Large", {a = 0.14,
											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 4,
											modelfactor = 0.5, specular = 0.2, scattering = 0.1, lensflare = 0,
											lifetime = 0, sustain = 0})

--cordoom_scav
projectileDefLightsNames["cordoom_scav_atadr"] =
GetLightClass("LaserProjectile", "Purple", "Large", {a = 0.14,
											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 4,
											modelfactor = 0.5, specular = 0.2, scattering = 0.1, lensflare = 0,
											lifetime = 0, sustain = 0})

--cordoomt3
projectileDefLightsNames["cordoomt3_armagmheat"] =
GetLightClass("LaserProjectile", "HeatRay", "Larger", {a = 0.14,
											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 4,
											modelfactor = 0.5, specular = 0.2, scattering = 0.1, lensflare = 0,
											lifetime = 0, sustain = 0})

--cordoomt3_scav
projectileDefLightsNames["cordoomt3_scav_armagmheat"] =
GetLightClass("LaserProjectile", "Purple", "Larger", {a = 0.14,
											color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 4,
											modelfactor = 0.5, specular = 0.2, scattering = 0.1, lensflare = 0,
											lifetime = 0, sustain = 0})
--armcom
muzzleFlashLightsNames["armcom_disintegrator"] =
GetLightClass("MuzzleFlash", nil, "Medium", {posx = 0, posy = 0, posz = 0,
											color2r = 0.3, color2g = 0.1, color2b = 0.05, colortime = 13,
											r = 1.2, g = 1.1, b = 1.0, a = 0.6,
											modelfactor = 0.5, specular = 0.3, scattering = 0.3, lensflare = 0,
											lifetime = 20, sustain = 2})

--armmg
muzzleFlashLightsNames["armmg_armmg_weapon"] =
GetLightClass("MuzzleFlash", nil, "SmallMedium", {r = 0.4, g = 0.4, b = 0.4,
											lifetime = 3, colortime = 4,
											scattering = 0.1, specular = 0.4,})
explosionLightsNames["armmg_armmg_weapon"] =
GetLightClass("Explosion", nil, "Micro", {	r = 1.8, g = 1.8, b = 1.8, a = 0.2,
											color2r = 0.6, color2g = 0.6, color2b = 0.6, colortime = 4.8,
											sustain = 8, lifetime = 20, scattering = 0.4})
projectileDefLightsNames["armmg_armmg_weapon"] =
GetLightClass("CannonProjectile", "Warm", "Micro", {r = 1, g = 1, b = 1, a = 0.1,
											modelfactor = 0.1, specular = 0.1, scattering = 0.2, lensflare = 0})

--leggat
muzzleFlashLightsNames["leggat_armmg_weapon"] =
GetLightClass("MuzzleFlash", nil, "SmallMedium", {r = 0.4, g = 0.4, b = 0.4, scattering = 0.1, specular = 0.4, lensflare = 3,})
explosionLightsNames["leggat_armmg_weapon"] =
GetLightClass("Explosion", nil, "Micro", {	r = 3.8, g = 3.2, b = 2.2, colortime = 2.8, sustain = 14, lifetime = 22, scattering = 0.4})

--armkam
explosionLightsNames["armkam_med_emg"] =
GetLightClass("Explosion", nil, "Micro", {	r = 1.8, g = 1.8, b = 1.8, a = 0.2,
											colortime = 2.8,
											sustain = 12, lifetime = 20, scattering = 0.4})
projectileDefLightsNames["armkam_med_emg"] =
GetLightClass("CannonProjectile", "Warm", "Micro", {r = 1, g = 1, b = 1, a = 0.1,
											modelfactor = 0.1, specular = 0.1, scattering = 0.2, lensflare = 0})

--corcat
explosionLightsNames["corcat_exp_heavyrocket"] =
GetLightClass("Explosion", nil, "Mediumer", {r = 3, g = 2.5, b = 2.0, a = 0.25,
										color2r = 0.8, color2g = 0.43, color2b = 0.11, colortime = 5,
										sustain = 10, lifetime = 38,
										modelfactor = 0.1, specular = 0.2, scattering = 0.1, lensflare = 4})

--armrl engine
projectileDefLightsNames["armrl_armrl_missile"] =
GetLightClass("MissileProjectile", "Purple", "Tiny", {a = 0.7,
										color2r = 0.5, color2g = 0.2, color2b = 0.8, colortime = 1.6,
										modelfactor = 0.1, specular = 0.1, scattering = 0.5, lensflare = 2})

--cordemon
projectileDefLightsNames["cordemont4_dmaw"] =
GetLightClass("FlameProjectile", nil, "SmallMedium", {posy = 80, a = 0.08, colortime = 15, lifetime = 40})

--corjugg
explosionLightsNames["corjugg_juggernaut_fire"] =
GetLightClass("Explosion", nil, "Small", {r = 1.3, g = 1.1, b = 0.8, a = 0.75,
										color2r = 0.35, color2g = 0.20, color2b = 0.05, colortime = 7,
										sustain = 8, lifetime = 26, scattering = 0.7})
]]


-- hue hue turning these on will completely break the game...
--projectileDefLightsNames["armrock_arm_bot_rocket"] = GetLightClass("LaserAimProjectile", "Red", "Large")
--projectileDefLightsNames["corstorm_cor_bot_rocket"] = GetLightClass("LaserAimProjectile", "Red", "Large")



-- convert weaponname -> weaponDefID
for name, params in pairs(explosionLightsNames) do
	if WeaponDefNames[name] then
		explosionLights[WeaponDefNames[name].id] = params
	end
end
explosionLightsNames = nil
-- convert weaponname -> weaponDefID
for name, params in pairs(muzzleFlashLightsNames) do
	if WeaponDefNames[name] then
		muzzleFlashLights[WeaponDefNames[name].id] = params
	end
end
muzzleFlashLightsNames = nil
-- convert weaponname -> weaponDefID
for name, params in pairs(projectileDefLightsNames) do
	if WeaponDefNames[name] then
		projectileDefLights[WeaponDefNames[name].id] = params
	end
end
projectileDefLightsNames = nil



-- verification questions:
-- colortime determines how slow the initial rgb color(1) fades to color2 ?
-- too low colortime can induce flicker, why?

-- sustain determines how long color1 + color2 remain fully visible (before going into fade-out)
-- lifetime determines total life length and gets removed after this

-- Icexuick Check-list

-- 1.	posy on FlameProjectile does not have any effect
-- 2.	Cannon/Missile Projectiles with color2 seem to not loop the effect, but only play it once, making it hard(er) to use it
--		currently disabled this for CannonProjectile, so lights don't disappear half-way down trajectory
--		For FlameProjectile this does work very nice to add more colorvariation - and with manual lifetime tweaks makes it work for pyro + cordemont4
-- 3.	DGun only has explosion GL4 lights, projectile lights do not seem to show/work properly (also muzzleflash does not work on DGun weapons)
-- 4.	When projectiles hit water, they get asigned a different explosion CEG, but also lighting is removed. I think some subtle blue-ish explo light on water can make it look better.. but how?


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Projectile Collection
return {muzzleFlashLights = muzzleFlashLights, projectileDefLights = projectileDefLights, explosionLights = explosionLights, gibLight = gibLight}
