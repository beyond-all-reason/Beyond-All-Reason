if not Spring.Utilities.IsDevMode() then -- and not Spring.Utilities.ShowDevUI() then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "CEG Auto Reloader",
		desc = "Auto reloads all CEGS that have changed on disk, and tries to auto-spawn the last changed ceg at cursor",
		author = "Beherith",
		date = "2024.08.29",
		license = "GNU GPL v2",
		layer = 0,
		enabled = false, --  loaded by default?
	}
end


-- Localized functions for performance
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetMouseState = Spring.GetMouseState
local spEcho = Spring.Echo

local mouseOffscreen = select(6, spGetMouseState())

-----------------------------------------------------------------------------------------------------------------
---The entire CEG bit
-- When a CEG file is changed:
-- Try parse:
	-- Try Validate:
		-- If valid:
			-- Print changes
			-- Update CEG
			-- spawn ceg at cursor
		-- else:
			-- Print validation error
-- except:
	-- Print syntax error

local cegLibrary={} --maps cegname to cegdef
local cegFileNames = {} -- maps cegname to filename
local projectileTexures = {} -- maps texture name to filename

local spawnerDefs = {
    CExpGenSpawner = {
		info = [[This is the closest thing CEG has to a function call. Instead of creating a graphical effect on its own, it creates another CEG.
	Suggested Use
    If you use a spawner a lot of times, you may want to make it a separate CEG to avoid having to copy-paste many times.
    This is the only way to truly delay a graphical effect.
    The spawned CEG still checks conditions, so if you want to, say, spawn an effect only if it is in water and doesn't hit a unit, you can give the CExpGenSpawner nounit = 1; and the spawned CEG water = 1;.
    This allows you to give a set of spawners the same (and possibly random) direction.
    You can animate an explosion flip-book style using delays and several bitmaps.]],
		properties = {'delay', 'damage', 'explosionGenerator'}
	},
    CBitmapMuzzleFlame = {
		info = [[This creates three rectangular textures at right angles to each other. The frontTexture has dir as its normal.
	Suggested Use

    Muzzle flames, obviously.
    You can use an upward-pointing CBitmapMuzzleFlame as a simple splash of water or dirt.
    Railgun trails.
    This is the only class that both obeys perspective and allows for a custom texture.]],
		properties = {'sideTexture', 'frontTexture', 'colorMap', 'size', 'length', 'sizeGrowth', 'ttl', 'frontOffset'}
	},
    CExploSpikeProjectile= {
		info = [[This creates a glowy spike. Note that the spike is two sided, i.e., symmetric about the position of the spawner.
	Suggested Use
    Anything glowy.
    For large, slow missiles, you can try using this as an extended engine flame. Set the width to something fairly large.
    Long and thin spikes will look spiky; meanwhile, shorter and wider spikes look more blobby.
    The colors of spikes add together, so if you have several spikes and all three color channels are non-zero, it will be white in the center.
    The length growth of the spike depends on the norm of the dir vector. The spike does not grow in width.]],
		properties = {'length', 'lenghGrowth', 'width', 'alpha', 'alphaDecay', 'color'}
	},
    CHeatCloudProjectile={
		info = [[Creates an expanding sprite. Simple but effective.
	Suggested Use
    As the main background to an explosion.]],
		properties = {'heat', 'maxheat', 'heatfalloff', 'size', 'sizeMod', 'sizeModMod', 'texture'},
	},
    CSimpleParticleSystem={
		info = [[Creates a sprite that can undergo complex motion. Probably the most versatile class.
		Suggested Use

    Anything moving that is not doing so at constant velocity.
    If you want something that expands (or shrinks) to some size then stops, set sizeMod to something less than 1, and sizeGrowth to something positive. The particle will grow to a size equal to sizeGrowth / (1 - sizeMod) and stop. The smaller sizeMod is, the faster it will reach this size.]],
		properties = {'emitVector', 'emitRot', 'emitRotSpread', 'emitMul', 'particleSpeed', 'particleSpeedSpread', 'gravity', 'airdrag', 'particleSize', 'particleSizeSpread', 'sizeGrowth', 'sizeMod', 'directional', 'texture', 'colorMap', 'numParticles', 'particleLife', 'particleLifeSpread'}
	},
    CSpherePartSpawner={
		info = [[Draws an expanding sphere.
	Suggested Use
    Looks like a shockwave.]],
		properties = {'alpha', 'ttl', 'expansionSpeed', 'color'}
	},
    CSimpleGroundFlash={
		info = [[Draws an expanding ground texture.
Suggested Use
A short groundflash (~8 frames) is good for any explosion that gives off light. You can also use a longer groundflash to suggest the ground is glowing from heat]],
		properties = {'size', 'sizeGrowth', 'ttl', 'texture', 'colorMap'}
	},
    CStandardGroundFlash={
		info = [[If you name a spawner "groundflash," it will always generate a standard groundflash.
	Suggested Use
	A short groundflash (~8 frames) is good for any explosion that gives off light. You can also use a longer groundflash to suggest the ground is glowing from heat. ]],
		properties = {'flashSize', 'flashAlpha', 'circleGrowth', 'circleAlpha', 'ttl', 'color'}
	},
    CSmokeProjectile2={
		info = [[Particles that begin with a hard-coded yellow-red colorfade and then fade to monochrom. (shades of grey)

Movement is influenced by the random wind. Finer details of visual and position update are best explained by looking at the formulas in CSmokeProjectile2::Update() & CSmokeProjectile2::Draw() ]],
		properties = {'color', 'size', 'ageSpeed', 'glowFallof', 'wantedPos', 'speed', 'texture'}
	},
    CSmokeProjectile={
		info = [[Monochrome particles that fade out. A more "primitive" version of CSmokeProjectile2. No hardcoded red-yellow start but it misses wantedPos to tweak the look a bit more detailed.
Suggested Use
Smoke. For a nicer stream of smoke spawn it frequently over multiple frames, otherwise it looks rather bland. ]],
		properties = {'color', 'size', 'ageSpeed', 'speed', 'texture'}
	},
    CWakeProjectile={
		info = [[New Wake ]],
		properties = {'startsize', 'sizeexpansion', 'alpha', 'alphafalloff','fadeuptime', 'texture'}
	},
}

--spawnerDefs['heatcloud'] = spawnerDefs['CHeatCloudProjectile'] -- cleand up

------------------------------------- VALIDATORS -------------------------------------

local isBoolean = function(value)
	return value == true or value == false or value == 0 or value == 1
end


local function isSpawner(value)
	if spawnerDefs[value] then
		return spawnerDefs[value]
	else
		return false, "Not a spawner class:" ..tostring(value)
	end
end


-- Define a function to parse and evaluate CEG expressions
-- Returns result, errorcode
local function parseCEGExpression(inputCegString, numFloats, countIndex, damage)
	countIndex = countIndex or 0
	damage = damage or 100

	-- Define the buffer for storing values (16 slots)
	local buffer = {}

	local results = {}

	-- Use gmatch to find all elements separated by commas
	local numExpressions = 0
	for expression in string.gmatch(inputCegString, '([^,]+)') do
		numExpressions = numExpressions + 1
		local result = 0
		local currentOp = '+'
		-- Initialize buffer with zeroes
		for i = 0, 15 do
			buffer[i] = 0
		end

		local i = 1

		while i <= #expression do
			local char = expression:sub(i,i)

			if char == ' ' then
				i = i + 1
			elseif char == 'i' or char == 'r' or char == 'd' or char == 'm' or
				char == 'k' or char == 's' or char == 'y' or char == 'x' or
				char == 'a' or char == 'p' or char == 'q' or char == '+' then
				currentOp = char
				i = i + 1
			elseif tonumber(char) or char == '-' or char == '.' then
				local operandStr = ""
				local hasDecimal = false
				while i <= #expression and (tonumber(expression:sub(i,i)) or expression:sub(i,i) == '.' or expression:sub(i,i) == '-') do
					if expression:sub(i,i) == '.' then
						if hasDecimal then
							return nil,  "Invalid syntax: multiple decimals in a number:"..tostring(operandStr)
						end
						hasDecimal = true
					end
					operandStr = operandStr .. expression:sub(i,i)
					i = i + 1
				end
				local operand = tonumber(operandStr)
				if not operand then
					return nil, "Invalid number format:"..tostring(operandStr)
				end

				if currentOp == 'i' then
					result = result + (operand * countIndex)
				elseif currentOp == 'r' then
					result = result + (operand * math.random())
				elseif currentOp == 'd' then
					result = result + (operand * damage)
				elseif currentOp == 'm' then
					result = result + (operand % 1)
				elseif currentOp == 'k' then
					result = result + math.floor(operand)
				elseif currentOp == 's' then
					result = result + math.sin(operand)
				elseif currentOp == 'y' then
					if operand < 0 or operand > 15 then
						return nil, "Invalid buffer index:"..tostring(operand)
					end
					buffer[operand] = result
					result = 0
				elseif currentOp == 'x' then
					if operand < 0 or operand > 15 then
						return nil, "Invalid buffer index:"..tostring(operand)
					end
					result = result * buffer[operand]
				elseif currentOp == 'a' then
					if operand < 0 or operand > 15 then
						return nil, "Invalid buffer index:"..tostring(operand)
					end
					result = result + buffer[operand]
				elseif currentOp == 'p' then
					result = result ^ operand
				elseif currentOp == 'q' then
					if operand < 0 or operand > 15 then
						return nil, "Invalid buffer index:"..tostring(operand)
					end
					result = result ^ buffer[operand]
				else
					result = result + operand
				end

				currentOp = '+'
			else
				return nil, "Invalid character found:"..char
			end
		end
		tableInsert(results, result)
	end
	if numFloats and (numFloats ~= numExpressions)  then
		return nil, "Invalid number of floats, expected:"..tostring(numFloats) .. " got:"..tostring(numExpressions)
	end
    return results
end



local function isFloat(value)
	if type(value) == 'number' then
		return true
	end
	if type(value) == 'string' then
		local numstring = tonumber(value)
		if numstring then
			return true
		else
			local res, err = parseCEGExpression(value, 1)
			if err then return false else
				return true
			end
		end
	end
end

local function isInteger(value)
	-- seems like cegops are allowed here too!
	local res, err = isFloat(value)
	if res then return true end
	if type(value) == 'number' then
		if value % 1 == 0 then
			return true
		else
			return false, "Number is not an integer:"..tostring(value)
		end
	else
		return false, "Value "..tostring(value).. " is not a number."
	end
end


local function isFloat3(value)
	if value == 'dir' then
		return true
	end
	return parseCEGExpression(value, 3)
end

local function isFloat4(value)
	return parseCEGExpression(value, 4)
end

-- TODO FIXME:
local generatorNames = {}
local function isExplosionGenerator(value)
	if type(value) == 'string' then
		if true then return true end -- FIXME !!!!! names are only valid after parsing all of them
		if generatorNames[value] then
			return true
		else
			if (string.sub(value,1,7) == 'custom:') and generatorNames[string.sub(value,8)] then
				return true
			else
				return false, "Explosion generator "..tostring(value) .. " does not exist."
			end
		end
		return true
	end
end

-- fuck me 'nil' and 'none' and 'null' are valid texture names?
local function isValidTexture(value)
	if (type(value) == 'string' and (projectileTexures[value] or projectileTexures[string.lower(value)] ))
		or value == 'none' or value == 'nil' or value == 'null' then
		return true
	else
		if (type(value) == 'string') and (projectileTexures[value..'-anim'] or projectileTexures[string.lower(value)..'-anim']) then
			return true
		end
		return false, "Texture does not exist in resources.lua"
	end

end


local function isColorMapValid(colormap)
	if type(colormap) ~= "string" then
		return false, 'Colormap must be a string:'..tostring(colormap)
	end
	local colorMap = {}
	local colorMapParts = {}
	for color in string.gmatch(colormap, "%S+") do
		tableInsert(colorMapParts, color)
	end
	if #colorMapParts % 4 ~= 0 then
		return false, 'Colormap must have a multiple of 4 floats but has:'..tostring(colorMapParts)
	end
	for i = 1, #colorMapParts, 4 do
		local r = tonumber(colorMapParts[i])
		local g = tonumber(colorMapParts[i+1])
		local b = tonumber(colorMapParts[i+2])
		local a = tonumber(colorMapParts[i+3])
		if not r or not g or not b or not a then
			return false, 'Colormap must have 4 floats:'..tostring(colorMap)
		end
		if r < 0 or r > 1 or g < 0 or g > 1 or b < 0 or b > 1 or a < 0 or a > 1 then
			return false, 'Colormap values must be between 0 and 1:'..tostring(colormap)
		end
	end
	return true
end


local cegDefTemplate = {
	class = {
		type = 'string',
		default = 'CSimpleParticleSystem',
		note = 'The class of the CEG. This determines the graphical effect that is created. The available classes are:',
		validator = isSpawner,
	},


	-- Explosion Level Tags
	useDefaultExplosions = {
		type = 'bool',
		default = false,
		note = 'If this is set, the CEG will use the default explosion (based on damage and area of effect) in addition to any spawners you define. The default explosions are sometimes very performance heavy, especially for large damage values (leading to higher particle counts)',
		validator = isBoolean,
	},

	-- Spawner Level Tags
	spawnerName = {
		type = 'string',
		default = 'spawner_name',
		note = 'Each spawner has a class that determines what kind of graphical effect it creates. Spring has a number of standard classes that you can choose from. Currently available classes are:',
		validator = isSpawner,
	},
	count = {
		type = 'int',
		default = 1,
		note = 'The count determines the number of times the spawner will run.',
		validator = isInteger,
	},

	-- Visibility Conditions
	air = {
		type = 'bool',
		default = false,
		note = 'The CEG will run if at least 20 elmos above ground/sea level.',
		validator = isBoolean,
	},

	water = {
		type = 'bool',
		default = false,
		note = 'The CEG will run if in water to a depth of -5 elmos.',
		validator = isBoolean,
	},

	underwater = {
		type = 'bool',
		default = false,
		note = 'The CEG will run if under water deeper than 5 elmos.',
		validator = isBoolean,
	},

	ground = {
		type = 'bool',
		default = false,
		note = 'The CEG will run if less than 20 elmos above ground.',
		validator = isBoolean,
	},

	unit = {
		type = 'bool',
		default = false,
		note = 'The CEG will run if the weapon hits a unit.',
		validator = isBoolean,
	},

	nounit = {
		type = 'bool',
		default = false,
		note = 'The CEG will run if the weapon does not hit a unit.',
		validator = isBoolean,
	},

	-- Class Level Tags
	alwaysVisible = {
		type = 'bool',
		default = false,
		note = 'If true, the spawner is always visible, ignoring LoS. Note that prior to 98.0 this did not work correctly.',
		validator = isBoolean,
	},
	useAirLos = {
		type = 'bool',
		default = false,
		note = 'Whether the spawner uses air LoS to determine if it is visible. This may allow the spawner to be seen from a further distance than normal.',
		validator = isBoolean,
	},
	pos = {
		type = 'float[3]',
		default = {0.0, 0.0, 0.0},
		note = 'The initial position vector of the spawner.',
		validator = isFloat3,
	},

	speed = {
		type = 'float[3]',
		default = {0.0, 0.0, 0.0},
		note = 'The initial speed vector of the spawner.',
		validator = isFloat3,
	},
	dir = {
		type = 'float[3]',
		default = {0.0, 0.0, 0.0},
		note = 'The initial direction vector of the spawner.',
		validator = isFloat3,
	},

	-- CExpGenSpawner
	delay = {
		type = 'int',
		default = 1,
		note = 'How long to wait (in frames?) before spawning the CEG.',
		validator = isInteger,
	},
	damage = {
		type = 'float',
		default = 0.0,
		note = 'The CEG will be called with this damage. The CEG doesn\'t actually deal any damage, but you can use this as a parameter and read it using the \'d\' operator.',
		validator = isFloat,
	},
	explosionGenerator = {
		type = 'string',
		default = '',
		note = 'The name of the CEG you want to spawn.',
		validator = isExplosionGenerator,
	},
	-- CBitmapMuzzleFlame
	sideTexture = {
		type = 'string',
		default = '',
		note = 'Texture as viewed from the side.',
		validator = isValidTexture,
	},
	frontTexture = {
		type = 'string',
		default = '',
		note = 'Texture as viewed from the front.',
		validator = isValidTexture,
	},
	colorMap = {
		type = 'string',
		default = '',
		note = 'See CColorMap.',
		validator = isColorMapValid,
	},
	size = {
		type = 'float',
		default = 0.0,
		note = 'The initial width of the muzzle flame.',
		validator = isFloat,
	},
	length = {
		type = 'float',
		default = 0.0,
		note = 'The initial length of the muzzle flame.',
		validator = isFloat,
	},
	sizeGrowth = {
		type = 'float',
		default = 0.0,
		note = 'By the end of its life, the muzzle flame grows to 1 + sizeGrowth times its initial size and length. The flame grows quickly at first and more slowly toward the end.',
		validator = isFloat,
	},
	ttl = {
		type = 'int',
		default = 0,
		note = 'How long the muzzle flame lasts.',
		validator = isInteger,
	},
	frontOffset = {
		type = 'float',
		default = 0.0,
		note = 'Where the frontTexture is along the length of the muzzle flame. 0 means it is in the back, 1 is in the front.',
		validator = isFloat,
	},

	-- CExploSpikeProjectile
	lenghGrowth = {
		type = 'float',
		default = 0.0,
		note = 'How much the length increases by per update.',
		validator = isFloat,
	},
	width = {
		type = 'float',
		default = 0.0,
		note = 'Half the initial width of of the spike. This is an absolute value.',
		validator = isFloat,
	},
	alpha = {
		type = 'float',
		default = 0.0,
		note = 'The starting alpha of the spike.',
		validator = isFloat,
	},
	alphaDecay = {
		type = 'float',
		default = 0.0,
		note = 'How quickly the alpha of the spike decreases.',
		validator = isFloat,
	},
	color = {
		type = 'float[3]',
		default = {1.0, 0.8, 0.5},
		note = 'The color of the spike.',
		validator = isFloat3,
	},

	-- CHeatCloudProjectile
	heat = {
		type = 'float',
		default = 0.0,
		note = 'The heat of the cloud.',
		validator = isFloat,
	},
	maxheat = {
		type = 'float',
		default = 0.0,
		note = 'The maximum heat of the cloud.',
		validator = isFloat,
	},
	heatfalloff = {
		type = 'float',
		default = 0.0,
		note = 'How quickly the heat of the cloud decreases.',
		validator = isFloat,
	},
	sizeMod = {
		type = 'float',
		default = 0.0,
		note = 'The size of the heatcloud is multiplied by 1 - sizeMod.',
		validator = isFloat,
	},
	sizeModMod = {
		type = 'float',
		default = 0.0,
		note = 'Each frame, sizeMod is multiplied by sizeModMod.',
		validator = isFloat,
	},
	texture = {
		type = 'string',
		default = 'heatcloud',
		note = 'The texture used for the heatcloud.',
		validator = isValidTexture,
	},
	emitVector = {
		type = 'float[3]',
		default = {0.0, 0.0, 0.0},
		note = 'The initial direction vector in which the particle is emitted. When spawning CEGs via EmitSfx you can make the particles go into the direction of the emiting piece with emitvector = dir. This is useful for e.g. fire coming out of a gun barrel.',
		validator = isFloat3,
	},
	emitRot = {
		type = 'float',
		default = 0.0,
		note = 'At what angle to emit the particle relative to emitVector. 0 means that the particle will be emitted in emitVector\'s direction; 180 will emit the particle in the opposite direction. 90 will emit the particle in a random direction perpendicular to emitVector, which is good for creating rings.',
		validator = isFloat,
	},
	emitRotSpread = {
		type = 'float',
		default = 0.0,
		note = 'For each particle, a random number between 0 and emitRotSpread is added to the emitRot.',
		validator = isFloat,
	},
	emitMul = {
		type = 'float[3]',
		default = {1.0, 1.0, 1.0},
		note = 'Scales the initial particle velocity; for this property, +y is considered to be in the direction of emitVector. Good if you want to create an egg-shaped explosion.',
		validator = isFloat3,
	},
	particleSpeed = {
		type = 'float',
		default = 0.0,
		note = 'The particle\'s initial speed.',
		validator = isFloat,
	},
	particleSpeedSpread = {
		type = 'float',
		default = 0.0,
		note = 'For each particle, a random number between 0 and particleSpeedSpread is added to the particleSpeed.',
		validator = isFloat,
	},
	gravity = {
		type = 'float[3]',
		default = {0.0, 0.0, 0.0},
		note = 'This will be added to the particle\'s velocity every frame.',
		validator = isFloat3,
	},
	airdrag = {
		type = 'float',
		default = 0.0,
		note = 'The particle\'s velocity is multiplied by this every frame.',
		validator = isFloat,
	},
	particleSize = {
		type = 'float',
		default = 0.0,
		note = 'The initial size of the particle.',
		validator = isFloat,
	},
	particleSizeSpread = {
		type = 'float',
		default = 0.0,
		note = 'For each particle, a random number between 0 and particleSizeSpread is added to the particleSize.',
		validator = isFloat,
	},
	directional = {
		type = 'bool',
		default = false,
		note = 'If true, the particle will point in the direction it is moving.',
		validator = isBoolean,
	},
	numParticles = {
		type = 'int',
		default = 0,
		note = 'How many particles to create. This is not the same as count; if you spawn multiple particles using count, any CEG:Operators will be re-evaluated for each particle, whereas if you use numParticles they will not be. However, the spread properties are evaluated separately for each particle regardless of which one you use.',
		validator = isInteger,
	},
	particleLife = {
		type = 'float',
		default = 0.0,
		note = 'How long each particle lasts.',
		validator = isFloat,
	},
	particleLifeSpread = {
		type = 'float',
		default = 0.0,
		note = 'For each particle, a random number between 0 and particleLifeSpread is added to the particleLife.',
		validator = isFloat,
	},

	-- CSpherePartSpawner
	expansionSpeed = {
		type = 'float',
		default = 0.0,
		note = 'How quickly the sphere expands.',
		validator = isFloat,
	},


	-- CStandardGroundFlash
	flashSize = {
		type = 'float',
		default = 0.0,
		note = 'The radius of the groundflash.',
		validator = isFloat,
	},
	flashAlpha = {
		type = 'float',
		default = 0.0,
		note = 'How transparent the groundflash is. Generally the higher the brighter.',
		validator = isFloat,
	},
	circleGrowth = {
		type = 'float',
		default = 0.0,
		note = 'A groundflash can have an additional circle that expands outwards. This controls how fast the circle grows.',
		validator = isFloat,
	},
	circleAlpha = {
		type = 'float',
		default = 0.0,
		note = 'How transparent the circle is.',
		validator = isFloat,
	},


	--CSmokeProjectile2

	ageSpeed = {
		type = 'float',
		default = 0.5,
		note = 'How fast the particle ages. Every frame: age += ageSpeed The particle is deleted at if (age > 1)',
		validator = isFloat,
	},
	glowFalloff = {
		type = 'float',
		default = 0.0,
		note = 'How fast the particle fades to monochrom.',
		validator = isFloat,
	},
	wantedPos = {
		type = 'float[3]',
		default = {0.0, 0.0, 0.0},
		note = 'In which direction the smoke tends to drift. Less effective in y-coordinate and influenced by random wind.',
		validator = isFloat3,
	},
	--[[
			startsize            = 10,
        sizeexpansion        = 10,
        alpha                = 0.9,
        alphafalloff         = 0.5,
        fadeuptime           = 2,
        texture            = fogdirty,
		]]--#region
	startsize = {
		type = 'float',
		default = 0.0,
		note = 'The initial size of the smoke particle.',
		validator = isFloat,
	},
	sizeexpansion = {
		type = 'float',
		default = 0.0,
		note = 'How quickly the smoke particle expands.',
		validator = isFloat,
	},
	alphafalloff = {
		type = 'float',
		default = 0.0,
		note = 'How quickly the alpha of the smoke particle decreases.',
		validator = isFloat,
	},
	fadeuptime = {
		type = 'float',
		default = 0.0,
		note = 'How long the smoke particle takes to fade in.',
		validator = isFloat,
	},

	-- New:
	animParams = {
		type = 'float[3]',
		default = {0.0, 0.0, 0.0},
		note = 'X*Y, time',
		validator = isFloat3,
	},
}
local lowerKeys = {}
for k,v in pairs(cegDefTemplate) do
	lowerKeys[string.lower(k)] = k
end
for k,v in pairs(lowerKeys) do
	cegDefTemplate[k] = cegDefTemplate[v]
end

local function validateCEG(cegTable, cegName)
	for spawnername, spawnerTable in pairs(cegTable) do
		if type(spawnerTable) == 'table' and spawnerTable['class'] then
			local class = spawnerTable['class']
			if not spawnerDefs[class] then

				local msg = string.format(
					'Error: CEG {%s = {%s = {%s = "%s" ,...}}} : %s',
					tostring(cegName),
					tostring(spawnername),
					'class',
					class,
					"class does not exist"
				)
				return false, msg
			else
				for k, v in pairs(spawnerTable) do
					--spEcho('cegDefTemplate',k)
					if cegDefTemplate[k] then
						if cegDefTemplate[k].validator then
							local res, err = cegDefTemplate[k].validator(v)
							if not res then
								--spEcho("VAL", err)

								local msg = string.format(
									'Error: CEG {%s = {%s = {%s = %s ,...}}} : %s',
									tostring(cegName),
									tostring(spawnername),
									tostring(k),
									((type(v) == 'string') and '"' or '')  .. tostring(v) .. ((type(v) == 'string') and '"' or '') ,
									tostring(err)
								)

								return false, msg

							else
								--spEcho("Valid, type:",cegDefTemplate[k].type,  k, v)
							end
						end
					elseif k == 'properties' then
						for k2, v2 in pairs(v) do
							if cegDefTemplate[k2] then
								if cegDefTemplate[k2].validator then
									local res, err = cegDefTemplate[k2].validator(v2)
									if not res then
										--spEcho("VAL", err)


										local msg = string.format(
											'Error: CEG {%s = {%s = {properties = {%s = "%s"  ...}}}} is invalid: %s',
											tostring(cegName),
											tostring(spawnername),
											tostring(k2),
											((type(v2) == 'string') and '"' or '')  ..tostring(v2) .. ((type(2) == 'string') and '"' or '')  ,
											tostring(err)
										)

										return false, msg
									else
										--spEcho("Valid, type:",cegDefTemplate[k2].type,  k2, v2)
									end
								end
							end
						end
					else
						return false, "Invalid property:"..k..'='..tostring(v)
					end
				end
			end
		end
	end
	return true
end


local function AreIntegers(t)
	for k, v in pairs(t) do
		if type(k) ~= "number" or k % 1 ~= 0 then
			return false
		end
	end
	return true
end

local function AreBooleans(t)
	for k, v in pairs(t) do
		if type(k) ~= "boolean" and k ~=1 and k ~= 0 then
			return false
		end
	end
	return true
end

local function AreStrings(t)
	for k, v in pairs(t) do
		if type(k) ~= "string" then
			return false
		end
	end
	return true
end

local function AreColorMaps(t)
	for k, v in pairs(t) do
		if not isColorMapValid(k) then
			return false
		end
	end
	return true
end

local function AreNumbers(t)
	for k, v in pairs(t) do
		if type(k) ~= "number" then
			return false
		end
	end
	return true
end

local cegFileContents = {} -- maps filename to raw file contents
local cegDefFiles = {} -- maps ceg definitions to filenames
local cegDefs = {} -- maps ceg name to its full def

local spamCeg = nil

local function tableEquals(a,b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) == 'table' then
		for k, v in pairs(a) do
			if not tableEquals(v, b[k]) then
				return false
			end
		end
		for k, v in pairs(b) do
			if not tableEquals(v, a[k]) then
				return false
			end
		end
		return true
	else
		return a == b
	end
end

local function LoadAllCegs()
	for i, dir in pairs({'effects', 'effects/lootboxes', 'effects/raptors', 'effects/scavengers'}) do
		local cegfiles = VFS.DirList(dir, "*.lua")
		for _, cegfile in pairs(cegfiles) do
			--spEcho(cegfile)
			local fileString = VFS.LoadFile(cegfile)
			cegFileContents[cegfile] = fileString

			local cegs = VFS.Include(cegfile)
			for cegDefname, cegTable in pairs(cegs) do


				--spEcho(name)
				local res, err = validateCEG(cegTable, cegDefname)
				if not res then
					spEcho(err)
				else
				end
				cegDefs[cegDefname]=  cegTable
				for genName, generator in pairs(cegTable) do
					if type(generator) == 'table' then
						generatorNames[genName] = true
					end
				end
			end
		end
	end

end

local function ScanChanges()
	local needsReload = {}
	local allok = true
	for filename, fileContent in pairs(cegFileContents) do
		local newContents = VFS.LoadFile(filename)
		if newContents ~= fileContent then
			-- attempt to loadstring it:
			cegFileContents[filename] = newContents
			local chunk, err = loadstring(newContents, filename)
			if not chunk then
				spEcho("Failed to load: " .. filename .. '  (' .. err .. ')')
			else
				local newDefs = VFS.Include(filename)

				-- VALIDATE newdefs:
				for cegDefname, cegTable in pairs(newDefs) do
					local res, err = validateCEG(cegTable, cegDefname)
					if not res then
						spEcho(filename.. ':' .. err)
						allok = false
					else
						if tableEquals(cegDefs[cegDefname], cegTable) then
							--spEcho("No changes to: " .. cegDefname)
						else
							spamCeg = cegDefname
							spEcho("Changes in: " .. cegDefname)
							needsReload[cegDefname] = cegDefFiles[cegDefname]
							cegDefs[cegDefname] = cegTable
						end
					end

				end


				-- COMPARE TABLES
				for cegDefname, cegTable in pairs(newDefs) do
					cegDefFiles[cegDefname] = filename
				end
			end
		end
	end
	if allok then
		for cegDefname, cegDefFile in pairs(needsReload) do
			spEcho("Reloading: " .. cegDefname)
			Spring.SendCommands("reloadcegs")
		end
	end
end

local function LoadResources()
	local resources = VFS.Include("gamedata/resources.lua")
	for k,v in pairs(resources.graphics.projectiletextures) do
		--spEcho("projectileTexures", k,v)
		projectileTexures[k] = v
	end
	for k,v in pairs(resources.graphics.groundfx) do
		--spEcho("groundfx", k,v)
		projectileTexures[k] = v
	end
end


function widget:Initialize()
	LoadResources()
	LoadAllCegs()
end

local lastUpdate = Spring.GetTimer()
function widget:Update()
	if Spring.DiffTimers(Spring.GetTimer() , lastUpdate) < 1 then
		return
	end
	lastUpdate = Spring.GetTimer()

	local prevMouseOffscreen = mouseOffscreen
	mouseOffscreen = select(6, spGetMouseState())

	--if not mouseOffscreen and prevMouseOffscreen then
		ScanChanges()
	--end

	if spamCeg then
		Spring.SendCommands("luarules spawnceg " .. spamCeg .. " 0")
	end
end
