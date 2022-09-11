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
			r = 1, g = 1, b = 1, a = 0.17, 
			color2r = 0.5, color2g = 0.5, color2b = 0.5, colortime = 2, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.5, specular = 1.2, scattering = 0.5, lensflare = 0, 
			lifetime = 0, sustain = 0, 	aninmtype = 0, -- unused
		},
	},

	
	MissileProjectile = {
		lightType = 'point', -- or cone or beam
		lightConfig = {
			posx = 0, posy = 0, posz = 0, radius = 150, 
			r = 1, g = 1, b = 1, a = 0.15, 
			color2r = 0.75, color2g = 0.75, color2b = 0.75, colortime = 0.6, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 1, specular = 0.2, scattering = 0.6, lensflare = 0, 
			lifetime = 0, sustain = 1, 	aninmtype = 0, -- unused
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
		lightConfig = {
			posx = 0, posy = 15, posz = 0, radius = 30, 
			r = 1, g = 1, b = 1, a = 0.075, 
			color2r = 0.75, color2g = 0.6, color2b = 0.5, colortime = 0.6, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.2, specular = 0.5, scattering = 0.5, lensflare = 0, 
			lifetime = 0, sustain = 1, 	aninmtype = 0, -- unused
		},
	},
	
	Explosion = { -- spawned on explosions
		lightType = 'point', -- or cone or beam
		yOffset = 0, -- Y offsets are only ever used for explosions!
		lightConfig = {
			posx = 0, posy = 0, posz = 0, radius = 250, 
			r = 2, g = 2, b = 2, a = 0.3, 
			color2r = 0.8, color2g = 0.55, color2b = 0.28, colortime = 1.2, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.15, specular = 0.15, scattering = 0.4, lensflare = 1, 
			lifetime = 12, sustain = 4, 	aninmtype = 0, -- unused
		},
	},
	
	MuzzleFlash = { -- spawned on projectilecreated
		lightType = 'point', -- or cone or beam
		lightConfig = {
			posx = 0, posy = 0, posz = 0, radius = 150, 
			r = 2, g = 2, b = 2, a = 0.7, 
			color2r = 0.75, color2g = 0.6, color2b = 0.3, colortime = 20, -- point lights only, colortime in seconds for unit-attached
			modelfactor = 0.8, specular = 0.5, scattering = 0.6, lensflare = 1, 
			lifetime = 4, sustain = 0.005, 	aninmtype = 0, -- unused
		},
	},
}


local SizeRadius = {Tiny = 55, Smaller = 75, Small = 100, Small150 = 150, Medium = 200, Medium250 = 250, Medium300 = 300, Medium350 = 350, Large = 400, Larger = 500, Largest = 650, Mega = 800, Mega1000 = 1000, Mega1300 = 1500, Giga = 1600, Tera = 3600}
local ColorSets = { -- TODO add advanced dual-color sets!
	Red = 		{r = 1, g = 0, b = 0},
	Green = 	{r = 0, g = 1, b = 0},
	Blue = 		{r = 0, g = 0, b = 1},
	Yellow = 	{r = 1, g = 1, b = 0},
	White = 	{r = 1, g = 1, b = 1},
	Plasma  = 	{r = 0.84, g = 0.75, b = 0.15},
	Fire  = 	{r = 0.8, g = 0.3, b = 0.05},
	Warm  = 	{r = 0.7, g = 0.7, b = 0.1},
	Cold  = 	{r = 0.5, g = 0.75, b = 1.0},
	Team  = 	{r = -1, g = -1, b = -1},
}

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
		posx = 0, posy = 0, posz = 0, radius = 75, 
		r = 1, g = 1, b = 0.5, a = 0.25, 
		color2r = 0.8, color2g = 0.5, color2b = 0.1, colortime = 0.2, -- point lights only, colortime in seconds for unit-attache
		modelfactor = 1, specular = 1, scattering = 0.3, lensflare = 1, 
		lifetime = 0, sustain = 10, 	aninmtype = 0 -- unused
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
		local customParams = weaponDef.customParams or {}
		local damage = 100
		for cat=0, #weaponDef.damages do
			if Game.armorTypes[cat] and Game.armorTypes[cat] == 'default' then
				damage = weaponDef.damages[cat]
				break
			end
		end
		local radius = ((weaponDef.damageAreaOfEffect*2) + (weaponDef.damageAreaOfEffect * weaponDef.edgeEffectiveness * 1.25)) 
		local orgMult = (math.max(0.25, math.min(damage/1600, 0.6)) + (radius/2800)) 
		local life = (9.5*(1.0+radius/2500)+(orgMult * 5)) 
		radius = (orgMult * 75) + (radius * 2.4)
		local r, g, b = 1, 0.8, 0.45
		if weaponDef.visuals ~= nil and weaponDef.visuals.colorR ~= nil then
			r = weaponDef.visuals.colorR
			g = weaponDef.visuals.colorG
			b = weaponDef.visuals.colorB
		end
		local muzzleFlash = true
		local explosionLight = true
		local sizeclass = 'Tiny'
		
		if weaponDef.type == 'BeamLaser' then 
			muzzleFlash = false
			explosionLight = false
			local beamcolor = 'White'
			if r > g + b then beamcolor = 'Red'
			elseif g > r + b then beamcolor = 'Green'
			elseif b > r + g then beamcolor = 'Blue'
			elseif b < (r + g)/2 then beamcolor = 'Yellow'
			end
 

			for newsize, sizerad in pairs(SizeRadius) do 
				--Spring.Echo(weaponID, damage, sizeclass, sizerad, newsize)
				if damage > sizerad and SizeRadius[sizeclass] < sizerad then sizeclass = newsize end
			end
			projectileDefLights[weaponID] = GetLightClass("LaserProjectile", beamcolor, sizeclass)
		elseif weaponDef.type == 'LightningCannon' then
			if damage < 500 then sizeclass = 'Medium' end 
			if damage > 500 then sizeclass = 'Large' end 
			projectileDefLights[weaponID] = GetLightClass("LaserProjectile", "Cold", sizeclass)
		elseif weaponDef.type == 'MissileLauncher' or weaponDef.type == 'StarburstLauncher' then 
			for newsize, sizerad in pairs(SizeRadius) do 
				if damage > sizerad and SizeRadius[sizeclass] > sizerad then sizeclass = newsize end
			end
			projectileDefLights[weaponID] = GetLightClass("MissileProjectile", "Cold", sizeclass)
		elseif weaponDef.type == 'Cannon' then 
			for newsize, sizerad in pairs(SizeRadius) do 
				if damage > sizerad and SizeRadius[sizeclass] > sizerad then sizeclass = newsize end
			end
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Plasma", sizeclass)
		elseif weaponDef.type == 'DGun' then 
			sizeclass = "Medium"
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Warm", sizeclass)
		elseif weaponDef.type == 'LaserCannon' then 
			if damage < 25 then sizeclass = 'Small' end
			if damage > 25 then sizeclass = 'Medium' end 
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Warm", sizeclass)
		elseif weaponDef.type == 'TorpedoLauncher' then 
			sizeclass = "Small"
			projectileDefLights[weaponID] = GetLightClass("TorpedoProjectile", "Cold", sizeclass)
		elseif weaponDef.type == 'Shield' then 
			sizeclass = "Large"
			projectileDefLights[weaponID] = GetLightClass("CannonProjectile", "Cold", sizeclass)
		elseif weaponDef.type == 'Flame' then 
			sizeclass = "Small"
			projectileDefLights[weaponID] = GetLightClass("FlameProjectile", "Fire", sizeclass)
		end 
		
		
		if muzzleFlash then 
			muzzleFlashLights[weaponID] = GetLightClass("MuzzleFlash", "White", sizeclass, nil)
			muzzleFlashLights[weaponID].yOffset = muzzleFlashLights[weaponID].lightConfig.radius / 5
		end
		if explosionLight then 
			explosionLights[weaponID] = GetLightClass("Explosion", nil, sizeclass, nil)
			explosionLights[weaponID].yOffset = explosionLights[weaponID].lightConfig.radius / 5
		end
	end
	Spring.Echo(Spring.GetGameFrame(),"DLGL4 weapons conf using",usedclasses,"light types")
end
AssignLightsToAllWeapons()

-----------------Manual Overrides--------------------

muzzleFlashLights[WeaponDefNames["armbull_arm_bull"].id] = 
GetLightClass("MuzzleFlash", nil, "Small", {r = 2, g = 1, b = 1, scattering = 0.2})
explosionLights[WeaponDefNames["armbull_arm_bull"].id] =
GetLightClass("Explosion", nil, "Small", {r = 3.8, g = 3.2, b = 2.2, colortime = 2.8, sustain = 14, lifetime = 22, scattering = 0.7})
explosionLights[WeaponDefNames["armbull_arm_bull"].id].yOffset = 4

explosionLights[WeaponDefNames["corgol_cor_gol"].id] =
GetLightClass("Explosion", nil, "Medium", {r = 4, g = 3.5, b = 2.5, colortime = 3.8, sustain = 14, lifetime = 26, scattering = 0.7,})

muzzleFlashLights[WeaponDefNames["armmg_armmg_weapon"].id] = 
GetLightClass("MuzzleFlash", nil, "Medium", {r = 0.4, g = 0.4, b = 0.4, scattering = 0.1, specular = 0.4,})
explosionLights[WeaponDefNames["armmg_armmg_weapon"].id] =
GetLightClass("Explosion", nil, "Small", {r = 3.8, g = 3.2, b = 2.2, colortime = 2.8, sustain = 14, lifetime = 22, scattering = 0.7})

muzzleFlashLights[WeaponDefNames["corint_cor_intimidator"].id] = 
GetLightClass("MuzzleFlash", nil, "Tiny", {posx = -7, posy = 16, posz = 5, radius = 45,
											color2r = 0.5, color2g = 0.1, color2b = 0, colortime = 85,
											r = 1, g = 0.2, b = 0, a = 0.69999999,
											modelfactor = 2, specular = 1, scattering = 0, lensflare = 0,
											lifetime = 200, sustain = 4})
muzzleFlashLights[WeaponDefNames["corint_cor_intimidator"].id].yOffset = 16

-- hue hue turning these on will completely break the game...
--projectileDefLights[WeaponDefNames["armrock_arm_bot_rocket"].id] = GetLightClass("LaserAimProjectile", "Red", "Large")
--projectileDefLights[WeaponDefNames["corstorm_cor_bot_rocket"].id] = GetLightClass("LaserAimProjectile", "Red", "Large")



-- verification questions:
-- colortime determines how slow the initial rgb color(1) fades to color2 ?
-- too low colortime can induce flicker, why?

-- sustain determines how long color1 + color2 remain fully visible (before going into fade-out)
-- lifetime determines total life length and gets removed after this


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Projectile Collection
return {muzzleFlashLights = muzzleFlashLights, projectileDefLights = projectileDefLights, explosionLights = explosionLights, gibLight = gibLight}