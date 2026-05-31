--------------------------------------------------------------------------------
-- Fire GL4
-- GPU-instanced fire / smoke / ember particle system with a reusable API.
--
--  * Provides GG.Fire so other (unsynced) gadgets can spawn fire effects
--    instead of relying on engine CEG effects.
--  * Three particle "types":
--        0 = fire flame   (fire texture atlas, light buoyancy, grows)
--        1 = smoke        (smoke texture atlas, strong buoyancy, long-lived)
--        2 = ember        (procedural glowing dot, rises with strong wobble
--                          and a flickering "flaky" alpha)
--  * Automatic fire-hit damage effect: when a unit is hit by a Flame
--    weapontype weapon it gains a fire+smoke+ember emitter ATTACHED to the
--    unit, so the spawn location follows the unit while it keeps burning.
--    Each fresh hit refreshes the burn timer.
--  * Automatic wreckage effect: when a unit that leaves a corpse dies, a
--    short fire + longer smoke emitter is spawned at the wreckage position.
--
-- Modeled on gfx_flamethrower_gl4.lua (Floris) for the GL4 instancing pipeline.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo()
	return {
		name    = "Fire GL4",
		desc    = "GL4 instanced fire/smoke/ember particle effects + GG.Fire API",
		author  = "Floris",
		date    = "May 2026",
		license = "GNU GPL v2",
		layer   = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Localized engine functions
--------------------------------------------------------------------------------
local spEcho              = Spring.Echo
local spGetUnitPosition   = Spring.GetUnitPosition
local spIsSphereInView    = Spring.IsSphereInView
local spGetWind           = Spring.GetWind
local spGetFPS            = Spring.GetFPS
-- Unsynced-only: forces a feature's draw matrix to refresh each frame so that
-- synced SetFeatureDirection spins (e.g. falling trees) are actually rendered.
local spSetFeatureAlwaysUpdateMatrix = Spring.SetFeatureAlwaysUpdateMatrix

local glBlending  = gl.Blending
local glTexture   = gl.Texture
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling   = gl.Culling

local GL_ONE                 = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA           = GL.SRC_ALPHA

local mathRandom = math.random
local mathMin    = math.min
local mathMax    = math.max
local mathFloor  = math.floor
local mathCeil   = math.ceil
local mathSqrt   = math.sqrt
local mathSin    = math.sin
local mathCos    = math.cos
local mathPi     = math.pi
local TWO_PI     = mathPi * 2

local LuaShader = gl.LuaShader
local pushElementInstance = gl.InstanceVBOTable.pushElementInstance
local popElementInstance  = gl.InstanceVBOTable.popElementInstance

--------------------------------------------------------------------------------
-- CONFIG
--------------------------------------------------------------------------------
local CONFIG = {
	enabled       = true,
	maxParticles  = 6000,    -- VBO capacity / hard cap

	-- Fire (ptype 0)
	fireSizeBase  = 8.0,
	fireSizeRand  = 6.0,
	fireGrowth    = 4,
	fireBuoyancy  = 8.5,     -- shader rise: FIRE_BUOY * t*t
	fireLifeMin   = 8,
	fireLifeSpan  = 12,      -- life in [min, min+span]
	fireAlpha     = 0.95,
	fireBrightness = 1.55,
	fireWobbleMin = 0.5,
	fireWobbleMax = 2.5,

	-- Smoke (ptype 1)
	smokeSizeBase = 3.0,
	smokeSizeRand = 3.3,
	smokeGrowth   = 4.0,
	smokeBuoyancy = 0.02,   -- shader rise: SMOKE_BUOY * age*age
	smokeLifeMin  = 40,
	smokeLifeSpan = 70,
	smokeAlpha    = 0.2,
	smokeWobble   = 3.5,
	smokeTint     = { 0.3, 0.28, 0.26 },
	smokeUpVelMin = 0.20,
	smokeUpVelSpan = 0.30,

	-- Ember (ptype 2) -- upward wobbly flaky glowing flecks
	emberSizeBase = 2.0,
	emberSizeRand = 1.6,
	emberGrowth   = 0.0,
	emberBuoyancy = 0.004,
	emberLifeMin  = 16,
	emberLifeSpan = 26,
	emberAlpha    = 0.9,
	emberBrightness = 1.5,
	emberWobble   = 1.6,     -- strong constant wobble => flaky drifting
	emberVyMin    = 1.8,
	emberVySpan   = 3.0,

	-- Wind influence
	windFlameMult = 0.0008,
	windSmokeMult = 0.0030,
	windEmberMult = 0.0016,

	-- Default emitter timings (frames @30Hz)
	unitFireFrames   = 45,   -- how long after a hit a unit keeps burning
	unitSmokeExtra   = 120,  -- smoke lingers this much longer than the fire
	wreckFireFrames  = 50,   -- short fire on wreckage
	wreckSmokeFrames = 320,  -- long smoke on wreckage

	-- Bonus multipliers for flamethrower units (stacks on top of other multipliers)
	ftScaleMult = 2.0,       -- extra fire duration when a flamethrower unit dies
	ftDurationMult = 1.2,    -- extra fire duration when a flamethrower unit dies

	-- Bonus multipliers for self-destructed units (stacks on top of other multipliers)
	sdScaleMult    = 1.4,    -- extra visual scale when a unit self-destructs
	sdDurationMult = 1.2,    -- extra fire duration when a unit self-destructs

	-- Default emitter emission rates (particles per sim frame, fractional ok)
	fireRate  = 1.1,
	smokeRate = 0.35,
	emberRate = 0.5,

	-- Tree fire: a column of flame that grows up a burning tree and topples
	-- with it into a line of fire on the ground (driven by gfx_tree_feller).
	treeFire = {
		growFrames      = 55,    -- fallback climb time if synced sends none
		startHeightFrac = 0.18,  -- fire height at ignite (fraction of tree height)
		canopyFrac      = 0.60,  -- default height fraction of canopy (where fuel is)
		trunkRadiusFrac = 0.18,  -- trunk radius vs canopy radius
		fireRate        = 1.8,
		smokeRate       = 0.5,
		emberRate       = 0.5,
		fireSizeMult    = 0.4,  -- individual flames are small; volume comes from many particles
		smokeSizeMult   = 1.8,
		smokeTail       = 150,   -- smoke lingers this long after the fire stops
	},

	-- Culling
	cullPad = 60,
}

if not CONFIG.enabled then
	function gadget:Initialize() gadgetHandler:RemoveGadget() end
	return
end

--------------------------------------------------------------------------------
-- Shaders
--------------------------------------------------------------------------------
local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform vec3 windVelocity;

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec4 worldPos;    // xyz spawn pos, w birthFrame
layout (location = 2) in vec4 velLife;     // xyz initial vel, w lifetime frames
layout (location = 3) in vec4 sizeData;    // x baseSize, y type (0 fire,1 smoke,2 ember), z seed, w rotation
layout (location = 4) in vec4 tintAlpha;   // rgb tint, a alpha multiplier

out DataVS {
	vec2 texCoords;
	vec4 particleColor;
	float animFrame;
	float rowVariant;
	flat float ptype;
};

void main() {
	float currentFrame = timeInfo.x + timeInfo.w;
	float age = currentFrame - worldPos.w;
	float life = velLife.w;
	float t = clamp(age / life, 0.0, 1.0);

	if (t >= 1.0 || age < 0.0) {
		gl_Position = vec4(-9999.0);
		particleColor = vec4(0.0);
		texCoords = vec2(0.0);
		animFrame = 0.0;
		rowVariant = 0.0;
		ptype = 0.0;
		return;
	}

	float type = sizeData.y;
	float seed = sizeData.z;
	float baseSize = sizeData.x;

	// Drag-integrated forward motion
	float drag = exp(age * -0.10);
	float dragFactor = (1.0 - drag) * 10.0; // 1 / 0.10
	vec3 pos = worldPos.xyz + velLife.xyz * dragFactor;

	// Per-type vertical buoyancy
	if (type < 0.5) {
		pos.y += FIRE_BUOY * t * t;
	} else if (type < 1.5) {
		pos.y += SMOKE_BUOY * age * age;
	} else {
		pos.y += EMBER_BUOY * age * age;
	}

	// Wind drift
	float windMult = (type < 0.5) ? WIND_FLAME_MULT
				   : ((type < 1.5) ? WIND_SMOKE_MULT : WIND_EMBER_MULT);
	pos.x += windVelocity.x * age * windMult;
	pos.z += windVelocity.z * age * windMult;

	// Turbulence
	float wobAmp;
	if (type < 0.5) {
		wobAmp = mix(FIRE_WOBBLE_MIN, FIRE_WOBBLE_MAX, t);
	} else if (type < 1.5) {
		wobAmp = SMOKE_WOBBLE * t;
	} else {
		wobAmp = EMBER_WOBBLE;
	}
	float ph = seed * 6.283185;
	float aw = (type > 1.5) ? 0.30 : 0.11; // embers wobble faster (flaky)
	pos.x += sin(age * aw + ph * 2.7) * wobAmp;
	pos.z += cos(age * (aw * 0.85) + ph * 3.8) * wobAmp;
	pos.y += sin(age * (aw * 0.65) + ph * 1.7) * wobAmp * 0.35;

	// Size growth varies by type
	float growth;
	if (type < 0.5) growth = FIRE_GROWTH;
	else if (type < 1.5) growth = SMOKE_GROWTH;
	else growth = EMBER_GROWTH;
	float curve = t * (1.0 + t * 0.6);
	float size = baseSize * (1.0 + curve * growth);
	if (type > 1.5) size = baseSize * (1.0 - t * 0.45); // embers shrink as they cool

	// Billboard (camera-aligned, with rotation)
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;
	float rotSpeed = (seed - 0.5) * 0.8;
	float rot = sizeData.w + age * rotSpeed * 0.02;
	float cr = cos(rot);
	float sr = sin(rot);
	vec3 rR =  camRight * cr + camUp * sr;
	vec3 rU = -camRight * sr + camUp * cr;
	vec3 off = (rR * position_xy_uv.x + rU * position_xy_uv.y) * size;

	gl_Position = cameraViewProj * vec4(pos + off, 1.0);
	texCoords = position_xy_uv.zw;
	ptype = type;

	vec3 col = tintAlpha.rgb;

	// Alpha curve: ease-in, long mid, soft fade-out.
	float aIn  = clamp(t * 8.0, 0.0, 1.0);
	float aOut = 1.0 - smoothstep(0.6, 1.0, t);
	float a = tintAlpha.a * aIn * aOut;

	// Ember flaky flicker
	if (type > 1.5) {
		float fl = 0.55 + 0.45 * sin(age * 0.9 + ph * 5.0);
		a *= clamp(fl, 0.0, 1.0);
	}

	particleColor = vec4(col, a);

	// Animation atlas frame selection
	if (type < 0.5) {
		// fire atlas (16 cols x 6 rows)
		animFrame = floor(t * 15.0 + 0.5);
		rowVariant = floor(seed * 6.0);
	} else {
		// smoke atlas (8 cols x 8 rows)
		float rawFrame = age * 0.13 + seed * 8.0;
		animFrame = mod(floor(rawFrame), 8.0);
		rowVariant = floor(seed * 8.0);
	}
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D fireTex;
uniform sampler2D smokeTex;

in DataVS {
	vec2 texCoords;
	vec4 particleColor;
	float animFrame;
	float rowVariant;
	flat float ptype;
};

out vec4 fragColor;

void main() {
	if (particleColor.a <= 0.001) discard;

	vec3 color;
	float a;

	if (ptype > 1.5) {
		// Ember: procedural glowing radial disc, no texture sample.
		vec2 d = texCoords - vec2(0.5);
		float r2 = dot(d, d) * 4.0;
		float core = exp(-r2 * 4.0);
		float halo = exp(-r2 * 1.6) * 0.4;
		float shape = core + halo;
		color = mix(particleColor.rgb, vec3(1.0, 0.95, 0.7), core * 0.5);
		a = shape * particleColor.a;
	} else if (ptype < 0.5) {
		// fire
		vec2 uv = vec2(
			(animFrame + texCoords.x) * 0.0625,
			(clamp(rowVariant, 0.0, 5.0) + texCoords.y) * 0.16667
		);
		vec4 texSample = texture(fireTex, uv);
		color = particleColor.rgb * texSample.rgb;
		float coreBright = texSample.r * texSample.r;
		color += coreBright * particleColor.rgb * 0.6;
		a = texSample.a * particleColor.a;
	} else {
		// smoke
		vec2 uv = vec2(
			(animFrame + texCoords.x) * 0.125,
			(clamp(rowVariant, 0.0, 7.0) + texCoords.y) * 0.125
		);
		vec4 texSample = texture(smokeTex, uv);
		color = particleColor.rgb * texSample.rgb;
		a = texSample.a * particleColor.a;
	}

	// Premultiplied additive-friendly output
	fragColor = vec4(color * a, a);
	if (fragColor.a < 0.004) discard;
}
]]

--------------------------------------------------------------------------------
-- GL state
--------------------------------------------------------------------------------
local fireTexture  = "bitmaps/projectiletextures/BARFlame02.tga"
local smokeTexture = "bitmaps/projectiletextures/smoke-beh-anim.tga"

local particleVBO    = nil
local particleShader = nil
local nextParticleID = 0

local particleRemoveQueue = {}  -- [deathFrame] = { n = count, id, id, ... }
local lastRemovedFrame    = 0

local cachedGameFrame = 0
local windX, windZ = 0, 0

local MAX_PARTICLES = CONFIG.maxParticles

--------------------------------------------------------------------------------
-- Init / cleanup
--------------------------------------------------------------------------------
local function goodbye(reason)
	spEcho("[Fire GL4] removing: " .. reason)
	gadgetHandler:RemoveGadget()
end

local function initGL4()
	local shaderSource = {
		vsSrc       = vsSrc,
		fsSrc       = fsSrc,
		shaderName  = "FireGL4",
		uniformInt  = { fireTex = 0, smokeTex = 1 },
		uniformFloat = {},
		shaderConfig = {
			FIRE_BUOY       = CONFIG.fireBuoyancy,
			SMOKE_BUOY      = CONFIG.smokeBuoyancy,
			EMBER_BUOY      = CONFIG.emberBuoyancy,
			WIND_FLAME_MULT = CONFIG.windFlameMult,
			WIND_SMOKE_MULT = CONFIG.windSmokeMult,
			WIND_EMBER_MULT = CONFIG.windEmberMult,
			FIRE_WOBBLE_MIN = CONFIG.fireWobbleMin,
			FIRE_WOBBLE_MAX = CONFIG.fireWobbleMax,
			SMOKE_WOBBLE    = CONFIG.smokeWobble,
			EMBER_WOBBLE    = CONFIG.emberWobble,
			FIRE_GROWTH     = CONFIG.fireGrowth,
			SMOKE_GROWTH    = CONFIG.smokeGrowth,
			EMBER_GROWTH    = CONFIG.emberGrowth,
		},
		forceupdate = true,
	}

	particleShader = LuaShader.CheckShaderUpdates(shaderSource)
	if not particleShader then
		goodbye("shader compile failed")
		return false
	end

	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(
		-1, -1, 1, 1,
		0, 0, 1, 1,
		"fireQuadVBO"
	)

	local layout = {
		{ id = 1, name = "worldPos",  size = 4 },
		{ id = 2, name = "velLife",   size = 4 },
		{ id = 3, name = "sizeData",  size = 4 },
		{ id = 4, name = "tintAlpha", size = 4 },
	}

	particleVBO = gl.InstanceVBOTable.makeInstanceVBOTable(
		layout, CONFIG.maxParticles, "fireParticleVBO"
	)
	if not particleVBO then
		goodbye("VBO creation failed")
		return false
	end

	particleVBO.numVertices   = numVertices
	particleVBO.vertexVBO     = quadVBO
	particleVBO.VAO           = particleVBO:makeVAOandAttach(quadVBO, particleVBO.instanceVBO)
	particleVBO.primitiveType = GL.TRIANGLES

	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("fireIndexVBO")
	particleVBO.VAO:AttachIndexBuffer(indexVBO)
	particleVBO.indexVBO = indexVBO

	return true
end

local function cleanupGL4()
	if particleVBO then
		particleVBO:Delete()
		particleVBO = nil
	end
end

--------------------------------------------------------------------------------
-- Particle spawn / expiry
--------------------------------------------------------------------------------
local particleData = { 0,0,0,0, 0,0,0,0, 0,0,0,0, 1,1,1,1 }

local function spawnParticle(px, py, pz, vx, vy, vz, size, ptype, life, r, g, b, alpha)
	if particleVBO.usedElements >= MAX_PARTICLES then
		return nil
	end
	local deathFrame = cachedGameFrame + mathCeil(life) + 2

	particleData[1]  = px
	particleData[2]  = py
	particleData[3]  = pz
	particleData[4]  = cachedGameFrame
	particleData[5]  = vx
	particleData[6]  = vy
	particleData[7]  = vz
	particleData[8]  = life
	particleData[9]  = size
	particleData[10] = ptype
	particleData[11] = mathRandom()
	particleData[12] = (mathRandom() * 2 - 1) * mathPi
	particleData[13] = r
	particleData[14] = g
	particleData[15] = b
	particleData[16] = alpha

	-- Wrap nextParticleID well below the float32 precision ceiling (2^23) and
	-- skip any still-live IDs (see gfx_flamethrower_gl4.lua for the rationale).
	local nid = nextParticleID + 1
	if nid >= 8388608 then nid = 1 end
	local idToIndex = particleVBO.instanceIDtoIndex
	while idToIndex[nid] do
		nid = nid + 1
		if nid >= 8388608 then nid = 1 end
	end
	nextParticleID = nid
	local id = nid
	pushElementInstance(particleVBO, particleData, id, true)

	local q = particleRemoveQueue[deathFrame]
	if not q then
		q = { n = 0 }
		particleRemoveQueue[deathFrame] = q
	end
	local qn = q.n + 1
	q[qn] = id
	q.n   = qn
	return id
end

local function removeExpiredParticles(gameFrame)
	local startFrame = lastRemovedFrame + 1
	if gameFrame - startFrame > 600 then
		for f = startFrame, gameFrame - 601 do particleRemoveQueue[f] = nil end
		startFrame = gameFrame - 600
	end
	for f = startFrame, gameFrame do
		local q = particleRemoveQueue[f]
		if q then
			local idToIndex = particleVBO.instanceIDtoIndex
			local qn = q.n
			for i = 1, qn do
				local id = q[i]
				if idToIndex[id] then
					popElementInstance(particleVBO, id)
				end
				q[i] = nil
			end
			particleRemoveQueue[f] = nil
		end
	end
	lastRemovedFrame = gameFrame
end

--------------------------------------------------------------------------------
-- Color helpers (pre-multiplied by brightness)
--------------------------------------------------------------------------------
local FIRE_BRI  = CONFIG.fireBrightness
local EMBER_BRI = CONFIG.emberBrightness

local function fireColor()
	return FIRE_BRI,
	       (0.37 + 0.22 * mathRandom()) * FIRE_BRI,
	       (0.07 + 0.12 * mathRandom()) * FIRE_BRI
end

local function emberColor()
	return EMBER_BRI,
	       (0.62 + 0.30 * mathRandom()) * EMBER_BRI,
	       (0.14 + 0.24 * mathRandom()) * EMBER_BRI
end

local SMOKE_R = CONFIG.smokeTint[1]
local SMOKE_G = CONFIG.smokeTint[2]
local SMOKE_B = CONFIG.smokeTint[3]

-- Hot-loop CONFIG constants hoisted to upvalues. Particle emit functions spawn
-- hundreds of particles per frame; a direct upvalue read is much cheaper than a
-- per-particle CONFIG table hash lookup.
local FIRE_SIZE_BASE  = CONFIG.fireSizeBase
local FIRE_SIZE_RAND  = CONFIG.fireSizeRand
local FIRE_LIFE_MIN   = CONFIG.fireLifeMin
local FIRE_LIFE_SPAN  = CONFIG.fireLifeSpan
local FIRE_ALPHA      = CONFIG.fireAlpha
local EMBER_SIZE_BASE = CONFIG.emberSizeBase
local EMBER_SIZE_RAND = CONFIG.emberSizeRand
local EMBER_LIFE_MIN  = CONFIG.emberLifeMin
local EMBER_LIFE_SPAN = CONFIG.emberLifeSpan
local EMBER_ALPHA     = CONFIG.emberAlpha
local EMBER_VY_MIN    = CONFIG.emberVyMin
local EMBER_VY_SPAN   = CONFIG.emberVySpan
local SMOKE_SIZE_BASE = CONFIG.smokeSizeBase
local SMOKE_SIZE_RAND = CONFIG.smokeSizeRand
local SMOKE_LIFE_MIN  = CONFIG.smokeLifeMin
local SMOKE_LIFE_SPAN = CONFIG.smokeLifeSpan
local SMOKE_UPVEL_MIN = CONFIG.smokeUpVelMin
local SMOKE_UPVEL_SPAN = CONFIG.smokeUpVelSpan
local SMOKE_ALPHA     = CONFIG.smokeAlpha
local TREE_SMOKE_SIZE_MULT = CONFIG.treeFire.smokeSizeMult or 1.0
local CULL_PAD        = CONFIG.cullPad

--------------------------------------------------------------------------------
-- Emitters
--------------------------------------------------------------------------------
-- Each emitter spawns fire / smoke / ember particles at a position each frame
-- until its per-type end frame passes. Emitters can be attached to a unit, in
-- which case the spawn position follows the unit while it burns.
local emitters       = {}    -- dense array
local emitterCount   = 0
local unitFireEmitter = {}   -- [unitID] = emitter   (for hit-refresh dedupe)
local treeFireEmitters = {}  -- [featureID] = emitter (burning trees)

local function rateCount(rate)
	if rate <= 0 then return 0 end
	local n = mathFloor(rate)
	if mathRandom() < (rate - n) then n = n + 1 end
	return n
end

local SMOKE_TR = CONFIG.smokeTint[1]
local SMOKE_TG = CONFIG.smokeTint[2]
local SMOKE_TB = CONFIG.smokeTint[3]

-- Tree fire emission: distributes fire along the tree's vertical axis, which
-- tilts from upright toward the fall direction as the tree topples, so the
-- flames climb the standing tree and then lie down as a line of fire on the
-- ground. Particle density is biased toward the canopy (the most 'fuel').
local function emitTreeFire(e, n)
	local elapsed = n - e.startFrame
	local fallT = elapsed / e.fallFrames
	if fallT < 0 then fallT = 0 elseif fallT > 1 then fallT = 1 end
	local growT = elapsed / e.growFrames
	if growT < 0 then growT = 0 elseif growT > 1 then growT = 1 end

	-- Fade factor: 1.0 at full burn, ramps down to 0 as the fallen tree sinks.
	local fadeMult = 1.0
	if e.fadeStart then
		fadeMult = 1.0 - mathMin(1.0, (n - e.fadeStart) / (e.fadeDuration or 150))
		if fadeMult < 0.0 then fadeMult = 0.0 end
	end

	local sHF = CONFIG.treeFire.startHeightFrac
	local curH = e.height * (sHF + (1.0 - sHF) * growT)
	if curH < 1 then curH = 1 end

	-- Axis interpolates from straight up (fallT 0) to horizontal fall dir (fallT 1).
	local ang    = fallT * (mathPi * 0.5)
	local axisUp = mathCos(ang)
	local axisH  = mathSin(ang)
	local dirx, dirz = e.dirx, e.dirz

	local cf      = e.canopyFrac
	local trunkR  = e.trunkR
	local canopyR = e.canopyR
	local scale     = e.scale
	local lifeScale = e.lifeScale or scale
	local inten     = e.intensity

	-- FIRE -- denser and larger toward the center of the tree's length, tapering at both ends.
	if n <= e.fireEnd then
		local cnt = rateCount(e.fireRate * inten * fadeMult)
		for _ = 1, cnt do
			local hf
			if mathRandom() < 0.75 then
				-- Triangle distribution centered on 0.5 → dense mid-length cluster.
				hf = 0.5 + (mathRandom() - mathRandom()) * 0.38
			else
				hf = mathRandom()
			end
			if hf < 0 then hf = 0 elseif hf > 1 then hf = 1 end
			local rad
			if hf < cf then
				rad = trunkR + (canopyR - trunkR) * (hf / cf)
			else
				rad = canopyR + (canopyR * 0.25 - canopyR) * ((hf - cf) / (1.0 - cf))
			end
			local along = hf * curH
			local cx = e.x + dirx * along * axisH
			local cy = e.y + along * axisUp
			local cz = e.z + dirz * along * axisH
			local a2 = mathRandom() * TWO_PI
			local rr = mathSqrt(mathRandom()) * rad
			-- Particles near the center of the length are significantly larger.
			local centerProx = 1.0 - 2.0 * mathMin(0.5, math.abs(hf - 0.5)) -- 1 at center, 0 at ends
			local sizeCenterMult = 0.55 + 0.95 * centerProx
			local size = (FIRE_SIZE_BASE + (mathRandom() - 0.5) * FIRE_SIZE_RAND) * scale * e.fireSizeMult * (0.35 + 0.65 * fadeMult) * sizeCenterMult
			local life = (FIRE_LIFE_MIN + mathRandom() * FIRE_LIFE_SPAN) * lifeScale
			local vy = (0.4 + mathRandom() * 0.8) * scale
			local r, g, b = fireColor()
			spawnParticle(cx + mathCos(a2) * rr, cy + mathRandom() * rad * 0.3, cz + mathSin(a2) * rr,
				(mathRandom() - 0.5) * 0.4, vy, (mathRandom() - 0.5) * 0.4,
				size, 0, life, r, g, b, FIRE_ALPHA * (0.82 + 0.18 * mathRandom()))
		end
	end

	-- EMBERS
	if n <= e.emberEnd then
		local cnt = rateCount(e.emberRate * inten * fadeMult)
		for _ = 1, cnt do
			local hf = cf + (mathRandom() - mathRandom()) * 0.5
			if hf < 0 then hf = 0 elseif hf > 1 then hf = 1 end
			local rad = trunkR + (canopyR - trunkR) * mathMin(1.0, hf / cf)
			local along = hf * curH
			local cx = e.x + dirx * along * axisH
			local cy = e.y + along * axisUp
			local cz = e.z + dirz * along * axisH
			local a2 = mathRandom() * TWO_PI
			local rr = mathSqrt(mathRandom()) * rad * 0.8
			local size = (EMBER_SIZE_BASE + (mathRandom() - 0.5) * EMBER_SIZE_RAND) * scale
			local life = (EMBER_LIFE_MIN + mathRandom() * EMBER_LIFE_SPAN) * lifeScale
			local vy = EMBER_VY_MIN + mathRandom() * EMBER_VY_SPAN
			local r, g, b = emberColor()
			spawnParticle(cx + mathCos(a2) * rr, cy, cz + mathSin(a2) * rr,
				(mathRandom() - 0.5) * 0.5, vy, (mathRandom() - 0.5) * 0.5,
				size, 2, life, r, g, b, EMBER_ALPHA)
		end
	end

	-- SMOKE -- rises mainly from the canopy; decays after the fire stops.
	if n <= e.smokeEnd then
		local smokeDecayMult = 1.0
		if e.smokeDecayStart and n > e.smokeDecayStart then
			local span = e.smokeEnd - e.smokeDecayStart
			if span > 0 then
				smokeDecayMult = 1.0 - (n - e.smokeDecayStart) / span * 0.80
				if smokeDecayMult < 0.20 then smokeDecayMult = 0.20 end
			end
		end
		local cnt = rateCount(e.smokeRate * inten * smokeDecayMult)
		for _ = 1, cnt do
			local hf = cf + mathRandom() * (1.0 - cf) * 0.8 + 0.1
			if hf > 1 then hf = 1 end
			local rad = canopyR
			local along = hf * curH
			local cx = e.x + dirx * along * axisH
			local cy = e.y + along * axisUp
			local cz = e.z + dirz * along * axisH
			local a2 = mathRandom() * TWO_PI
			local rr = mathSqrt(mathRandom()) * rad
			local size = (SMOKE_SIZE_BASE + mathRandom() * SMOKE_SIZE_RAND) * scale * TREE_SMOKE_SIZE_MULT
			local life = (SMOKE_LIFE_MIN + mathRandom() * SMOKE_LIFE_SPAN) * lifeScale
			local svy = SMOKE_UPVEL_MIN + mathRandom() * SMOKE_UPVEL_SPAN
			local sv  = 0.25 + mathRandom() * 1.10
			spawnParticle(cx + mathCos(a2) * rr, cy + rad * 0.4, cz + mathSin(a2) * rr,
				(mathRandom() - 0.5) * 0.15, svy, (mathRandom() - 0.5) * 0.15,
				size, 1, life, SMOKE_TR * sv, SMOKE_TG * sv, SMOKE_TB * sv,
				SMOKE_ALPHA * smokeDecayMult)
		end
	end
end

local function emitFromEmitter(e, n)
	if e.treeFire then return emitTreeFire(e, n) end
	local x, y, z = e.x, e.y, e.z
	local radius    = e.radius
	local scale     = e.scale
	local lifeScale = e.lifeScale or scale  -- lifetime scales with unit size, NOT with scaleMult boost
	local inten     = e.intensity

	-- Fire -- with optional gradual decay for wreckage emitters.
	if n <= e.fireEnd then
		local fireDecayMult = 1.0
		if e.fireDecayStart then
			local decaySpan = e.fireEnd - e.fireDecayStart
			if decaySpan > 0 and n > e.fireDecayStart then
				fireDecayMult = 1.0 - (n - e.fireDecayStart) / decaySpan
				if fireDecayMult < 0 then fireDecayMult = 0 end
			end
		end
		local cnt = rateCount(e.fireRate * inten * fireDecayMult)
		for _ = 1, cnt do
			local ang = mathRandom() * TWO_PI
			local rr  = mathSqrt(mathRandom()) * radius
			local ox  = mathCos(ang) * rr
			local oz  = mathSin(ang) * rr
			local oy  = mathRandom() * radius * 0.3
			local size = (FIRE_SIZE_BASE + (mathRandom() - 0.5) * FIRE_SIZE_RAND) * scale
			local life = (FIRE_LIFE_MIN + mathRandom() * FIRE_LIFE_SPAN) * lifeScale
			local vx = (mathRandom() - 0.5) * 0.4
			local vy = (0.4 + mathRandom() * 0.8) * scale  -- rise height scales with fire size
			local vz = (mathRandom() - 0.5) * 0.4
			local r, g, b = fireColor()
			spawnParticle(x + ox, y + oy, z + oz, vx, vy, vz, size, 0, life,
				r, g, b, FIRE_ALPHA * fireDecayMult * (0.82 + 0.18 * mathRandom()))
		end
	end

	-- Embers -- with optional gradual decay for wreckage emitters.
	if n <= e.emberEnd then
		local emberDecayMult = 1.0
		if e.emberDecayStart and n > e.emberDecayStart then
			local decaySpan = e.emberEnd - e.emberDecayStart
			if decaySpan > 0 then
				emberDecayMult = 1.0 - (n - e.emberDecayStart) / decaySpan * 0.85
				if emberDecayMult < 0.05 then emberDecayMult = 0.05 end
			end
		end
		local cnt = rateCount(e.emberRate * inten * emberDecayMult)
		for _ = 1, cnt do
			local ang = mathRandom() * TWO_PI
			local rr  = mathSqrt(mathRandom()) * radius * 0.8
			local ox  = mathCos(ang) * rr
			local oz  = mathSin(ang) * rr
			local oy  = radius * 0.2 + mathRandom() * radius * 0.3
			local size = (EMBER_SIZE_BASE + (mathRandom() - 0.5) * EMBER_SIZE_RAND) * scale
			local life = (EMBER_LIFE_MIN + mathRandom() * EMBER_LIFE_SPAN) * lifeScale
			local vx = (mathRandom() - 0.5) * 0.5
			local vy = EMBER_VY_MIN + mathRandom() * EMBER_VY_SPAN
			local vz = (mathRandom() - 0.5) * 0.5
			local r, g, b = emberColor()
			spawnParticle(x + ox, y + oy, z + oz, vx, vy, vz, size, 2, life,
				r, g, b, EMBER_ALPHA * emberDecayMult)
		end
	end

	-- Smoke -- with optional gradual decay of rate + alpha for wreckage emitters.
	if n <= e.smokeEnd then
		-- Compute a 0..1 decay factor over the smoke-only window (after fire ends).
		local smokeDecayMult = 1.0
		if e.smokeDecayStart and n > e.smokeDecayStart then
			local decaySpan = e.smokeEnd - e.smokeDecayStart
			if decaySpan > 0 then
				smokeDecayMult = 1.0 - (n - e.smokeDecayStart) / decaySpan * 0.80
				if smokeDecayMult < 0.20 then smokeDecayMult = 0.20 end
			end
		end
		local cnt = rateCount(e.smokeRate * inten * smokeDecayMult)
		for _ = 1, cnt do
			local ang = mathRandom() * TWO_PI
			local rr  = mathSqrt(mathRandom()) * radius
			local ox  = mathCos(ang) * rr
			local oz  = mathSin(ang) * rr
			local oy  = radius * 0.4 + mathRandom() * radius * 0.6
			local size = (SMOKE_SIZE_BASE + mathRandom() * SMOKE_SIZE_RAND) * scale
			local life = (SMOKE_LIFE_MIN + mathRandom() * SMOKE_LIFE_SPAN) * lifeScale
			local svy  = SMOKE_UPVEL_MIN + mathRandom() * SMOKE_UPVEL_SPAN
			-- Per-particle brightness: dark sooty cores (~0.25) to lighter billows (~1.35)
			local sv   = 0.25 + mathRandom() * 1.10
			spawnParticle(x + ox, y + oy, z + oz,
				(mathRandom() - 0.5) * 0.15, svy, (mathRandom() - 0.5) * 0.15,
				size, 1, life, SMOKE_R * sv, SMOKE_G * sv, SMOKE_B * sv,
				SMOKE_ALPHA * smokeDecayMult)
		end
	end
end

local function addEmitter(e)
	emitterCount = emitterCount + 1
	emitters[emitterCount] = e
	return e
end

local function removeEmitterAt(i)
	local e = emitters[i]
	if e.mappedUnit and unitFireEmitter[e.mappedUnit] == e then
		unitFireEmitter[e.mappedUnit] = nil
	end
	if e.featureID and treeFireEmitters[e.featureID] == e then
		treeFireEmitters[e.featureID] = nil
	end
	emitters[i] = emitters[emitterCount]
	emitters[emitterCount] = nil
	emitterCount = emitterCount - 1
end

local function updateEmitters(n)
	for i = emitterCount, 1, -1 do
		local e = emitters[i]
		if e.unitID then
			local ux, uy, uz = spGetUnitPosition(e.unitID)
			if ux then
				e.x = ux
				e.y = uy + e.yOffset
				e.z = uz
			else
				-- Unit gone (died / out of view): stop following, let it expire.
				-- Wreckage fire (UnitDestroyed) takes over if it left a corpse.
				e.unitID = nil
				if e.mappedUnit and unitFireEmitter[e.mappedUnit] == e then
					unitFireEmitter[e.mappedUnit] = nil
					e.mappedUnit = nil
				end
				e.fireEnd  = mathMin(e.fireEnd, n)
				e.emberEnd = mathMin(e.emberEnd, n)
				e.smokeEnd = mathMin(e.smokeEnd, n + 10)
			end
		end

		if n > e.fireEnd and n > e.smokeEnd and n > e.emberEnd then
			removeEmitterAt(i)
		elseif spIsSphereInView(e.x, e.y, e.z, e.radius + CULL_PAD) then
			emitFromEmitter(e, n)
		end
	end
end

--------------------------------------------------------------------------------
-- Per-unitDef precomputed emit params + wreckage detection
--------------------------------------------------------------------------------
local unitFireParams = {}   -- [unitDefID] = { radius, yOffset, scale }
local leavesWreck    = {}   -- [unitDefID] = true

for udid, ud in pairs(UnitDefs) do
	local r = ud.radius or 32
	local sc = r / 42
	if sc < 0.55 then sc = 0.55 elseif sc > 2.4 then sc = 2.4 end
	unitFireParams[udid] = {
		radius  = mathMax(6, r * 0.34),
		yOffset = (ud.height or r) * 0.4,
		scale   = sc,
	}
	if ud.corpse and FeatureDefNames and FeatureDefNames[ud.corpse] then
		leavesWreck[udid] = true
	end
end

-- Flame weapontype weapons trigger the unit fire-hit effect.
local flameWeapons = {}
for wDefID, wd in pairs(WeaponDefs) do
	if wd.type == "Flame" then
		flameWeapons[wDefID] = true
	end
end

-- Units that carry at least one Flame weapon get a bigger wreckage explosion.
local flamethrowerUnit = {}
for udid, ud in pairs(UnitDefs) do
	for _, wp in ipairs(ud.weapons or {}) do
		local wdid = wp.weaponDef
		if wdid and WeaponDefs[wdid] and WeaponDefs[wdid].type == "Flame" then
			flamethrowerUnit[udid] = true
			break
		end
	end
end

--------------------------------------------------------------------------------
-- Public spawn helpers (also drive GG.Fire)
--------------------------------------------------------------------------------
-- Spawn a free-standing fire effect. Returns an opaque handle usable with
-- StopFire. opts (all optional):
--   duration, smokeDuration, emberDuration (frames)
--   radius, scale, intensity
--   unitID  (attach to a unit; position follows it)
--   yOffset (vertical emit offset, default 0 / unit param)
--   fire, smoke, embers (booleans to enable each, default all true)
local function spawnFire(x, y, z, opts)
	opts = opts or {}
	local now = cachedGameFrame
	local fireDur  = opts.duration       or CONFIG.unitFireFrames
	local smokeDur = opts.smokeDuration  or (fireDur + CONFIG.unitSmokeExtra)
	local emberDur = opts.emberDuration  or fireDur
	local e = {
		unitID     = opts.unitID,
		mappedUnit = nil,
		x = x or 0, y = y or 0, z = z or 0,
		yOffset    = opts.yOffset or 0,
		radius     = opts.radius or 14,
		scale      = opts.scale or 1.0,
		intensity  = opts.intensity or 1.0,
		fireRate   = (opts.fire  == false) and 0 or (opts.fireRate  or CONFIG.fireRate),
		smokeRate  = (opts.smoke == false) and 0 or (opts.smokeRate or CONFIG.smokeRate),
		emberRate  = (opts.embers == false) and 0 or (opts.emberRate or CONFIG.emberRate),
		fireEnd    = now + fireDur,
		smokeEnd   = now + smokeDur,
		emberEnd   = now + emberDur,
	}
	return addEmitter(e)
end

-- Attach (or refresh) a burning effect to a unit -- used by the flamethrower
-- hit handler and exposed via GG.Fire.AddUnitFire.
local function addUnitFire(unitID, unitDefID, durationFrames)
	local now = cachedGameFrame
	local p = unitFireParams[unitDefID]
	local fireDur = durationFrames or CONFIG.unitFireFrames
	local e = unitFireEmitter[unitID]
	if e then
		-- Refresh burn timers (continuous flame keeps it alight).
		e.fireEnd  = now + fireDur
		e.emberEnd = now + fireDur
		e.smokeEnd = mathMax(e.smokeEnd, now + fireDur + CONFIG.unitSmokeExtra)
		return e
	end
	local radius  = p and p.radius  or 14
	local yOffset = p and p.yOffset or 12
	local scale   = p and p.scale   or 1.0
	e = {
		unitID     = unitID,
		mappedUnit = unitID,
		x = 0, y = 0, z = 0,
		yOffset    = yOffset,
		radius     = radius,
		scale      = scale,
		intensity  = 1.0,
		fireRate   = CONFIG.fireRate,
		smokeRate  = CONFIG.smokeRate,
		emberRate  = CONFIG.emberRate,
		fireEnd    = now + fireDur,
		emberEnd   = now + fireDur,
		smokeEnd   = now + fireDur + CONFIG.unitSmokeExtra,
	}
	local ux, uy, uz = spGetUnitPosition(unitID)
	if ux then
		e.x = ux; e.y = uy + yOffset; e.z = uz
	end
	unitFireEmitter[unitID] = e
	return addEmitter(e)
end

-- Short fire + long smoke at a wreckage position.
-- Smoke gradually decays in spawn rate and alpha after the fire dies out.
-- opts: scaleMult (default 1), durationMult (default 1)
local function spawnWreckageFire(x, y, z, scale, opts)
	local now = cachedGameFrame
	scale = scale or 1.0
	local sm = (opts and opts.scaleMult)    or 1.0
	local dm = (opts and opts.durationMult) or 1.0
	local fireDur  = CONFIG.wreckFireFrames * dm
	-- Smoke tail (after fire) stays the same fixed length regardless of durationMult.
	local smokeDur = fireDur + (CONFIG.wreckSmokeFrames - CONFIG.wreckFireFrames)
	return addEmitter({
		unitID           = nil,
		mappedUnit       = nil,
		x = x, y = y, z = z,
		yOffset          = 0,
		radius           = mathMax(8, 12 * scale * sm),
		scale            = scale * sm,
		lifeScale        = scale,       -- lifetime uses only unit scale, not scaleMult boost
		intensity        = 1.0,
		fireRate         = CONFIG.fireRate  * 0.9 * sm,
		smokeRate        = CONFIG.smokeRate * 1.3 * sm,
		emberRate        = CONFIG.emberRate * 0.7 * sm,
		fireEnd          = now + fireDur,
		emberEnd         = now + fireDur,
		smokeEnd         = now + smokeDur,
		-- Smoke starts decaying once the fire dies; fades out over the remaining smoke window.
		smokeDecayStart  = now + fireDur,
		-- Embers start fading halfway through the fire window so they peter out gracefully.
		emberDecayStart  = now + fireDur * 0.5,
		-- Fire decays linearly from the start so it dies out completely by fireEnd.
		fireDecayStart   = now,
	})
end

-- Start (or refresh) a growing tree fire keyed by featureID. Driven by the
-- synced gfx_tree_feller gadget via RecvFromSynced. The column climbs the tree
-- and tilts into a ground line as the tree falls. Geometry (height/radius/
-- canopyFrac) is derived from the tree's model mesh on the synced side.
local function spawnTreeFire(featureID, x, y, z, height, radius, canopyFrac, dirx, dirz, fallFrames)
	if not x or not featureID then return end
	-- Force the engine to refresh this feature's UNSYNCED (draw) matrix every
	-- frame. Spring.SetFeatureDirection on the synced side only updates the synced
	-- transform; without this the falling tree's mesh stays visually upright even
	-- though the simulation rotates it. This call is unsynced-only, which is why
	-- the synced tree-feller routes it here.
	if spSetFeatureAlwaysUpdateMatrix then
		spSetFeatureAlwaysUpdateMatrix(featureID, true)
	end
	if not height or height < 4 then height = 20 end
	if not radius or radius < 2 then radius = mathMax(6, height * 0.2) end
	local now = cachedGameFrame
	local existing = treeFireEmitters[featureID]
	if existing then
		-- Re-ignite / keep burning: extend timers, keep geometry & fall progress.
		existing.fireEnd  = now + 1000000
		existing.emberEnd = now + 1000000
		existing.smokeEnd = now + 1000000
		existing.smokeDecayStart = nil
		return existing
	end
	dirx = dirx or 1; dirz = dirz or 0
	local dl = mathSqrt(dirx * dirx + dirz * dirz)
	if dl > 0.0001 then dirx, dirz = dirx / dl, dirz / dl else dirx, dirz = 1, 0 end
	local tf = CONFIG.treeFire
	if not canopyFrac or canopyFrac <= 0 then canopyFrac = tf.canopyFrac end
	-- heightNorm: 0 at h=20 (small tree), 1 at h=60 (large tree), clamped.
	local heightNorm = mathMax(0.0, mathMin(1.0, (height - 20) / 40))
	-- scale drives particle base size and rise velocity; grows with tree height.
	local scale = 0.45 + 0.55 * heightNorm   -- 0.45 (small) .. 1.0 (large)
	-- fireSizeMult: individual flame billboard size, also grows with height.
	local fireSizeMult = tf.fireSizeMult * (1.0 + 0.9 * heightNorm)  -- 1.8 .. 3.4
	-- More particles for bigger trees so density feels consistent.
	local fireRate  = tf.fireRate  * (0.8 + 1.4 * heightNorm)   -- 2.0 .. 5.5
	local smokeRate = tf.smokeRate * (0.8 + 0.6 * heightNorm)
	local emberRate = tf.emberRate * (0.8 + 0.6 * heightNorm)
	local frames = (fallFrames and fallFrames > 1) and fallFrames or tf.growFrames
	local e = {
		treeFire      = true,
		featureID     = featureID,
		x = x, y = y, z = z,
		yOffset       = 0,
		height        = height,
		canopyR       = radius,
		trunkR        = mathMax(2, radius * tf.trunkRadiusFrac),
		canopyFrac    = canopyFrac,
		dirx = dirx, dirz = dirz,
		startFrame    = now,
		fallFrames    = frames,
		growFrames    = frames,
		scale         = scale,
		lifeScale     = scale,
		intensity     = 1.0,
		radius        = height,   -- cull sphere radius around the base
		fireRate      = fireRate,
		smokeRate     = smokeRate,
		emberRate     = emberRate,
		fireSizeMult  = fireSizeMult,
		fireEnd       = now + 1000000,
		emberEnd      = now + 1000000,
		smokeEnd      = now + 1000000,
	}
	treeFireEmitters[featureID] = e
	return addEmitter(e)
end

-- Begin a gradual fade of fire size and spawn rate (called when the felled tree starts sinking).
local function fadeTreeFire(featureID)
	local e = treeFireEmitters[featureID]
	if not e or e.fadeStart then return end
	e.fadeStart    = cachedGameFrame
	e.fadeDuration = 150   -- ~5 seconds to fully taper off
end

-- Stop a tree fire: kill flames/embers immediately, let smoke fade out.
local function stopTreeFire(featureID)
	if spSetFeatureAlwaysUpdateMatrix then
		spSetFeatureAlwaysUpdateMatrix(featureID, false)
	end
	local e = treeFireEmitters[featureID]
	if not e then return end
	local now = cachedGameFrame
	e.fireEnd  = now
	e.emberEnd = now
	e.smokeDecayStart = now
	e.smokeEnd = now + CONFIG.treeFire.smokeTail
	treeFireEmitters[featureID] = nil  -- detach so a later re-ignite makes a fresh one
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------
local function drawParticles()
	if not particleVBO or particleVBO.usedElements == 0 then return end
	if not particleShader then return end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE_MINUS_SRC_ALPHA)

	glTexture(0, fireTexture)
	glTexture(1, smokeTexture)

	particleShader:Activate()
	particleShader:SetUniformFloat("windVelocity", windX, 0, windZ)
	particleVBO:Draw()
	particleShader:Deactivate()

	glTexture(0, false)
	glTexture(1, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------
function gadget:Initialize()
	if not gl.CreateShader then
		goodbye("OpenGL shaders not supported")
		return
	end
	if not initGL4() then return end

	GG.Fire = {
		-- SpawnFire(x, y, z, opts) -> handle. See spawnFire above for opts.
		SpawnFire = function(x, y, z, opts) return spawnFire(x, y, z, opts) end,
		-- StopFire(handle): immediately stop spawning new particles (existing
		-- ones fade out naturally).
		StopFire = function(handle)
			if type(handle) == "table" then
				handle.fireEnd  = cachedGameFrame
				handle.smokeEnd = cachedGameFrame
				handle.emberEnd = cachedGameFrame
			end
		end,
		-- AddUnitFire(unitID[, durationFrames]): attach a burning effect that
		-- follows the unit. Refreshes the timer if already burning.
		AddUnitFire = function(unitID, durationFrames)
			local udid = Spring.GetUnitDefID(unitID)
			if udid then return addUnitFire(unitID, udid, durationFrames) end
		end,
		-- SpawnWreck(x, y, z[, scale]): short fire + long smoke at a position.
		SpawnWreck = function(x, y, z, scale) return spawnWreckageFire(x, y, z, scale) end,
		GetParticleCount = function() return particleVBO and particleVBO.usedElements or 0 end,
		GetMaxParticles  = function() return MAX_PARTICLES end,
		GetConfig        = function() return CONFIG end,
	}
end

function gadget:Shutdown()
	cleanupGL4()
	GG.Fire = nil
end

-- A unit hit by a Flame weapon catches fire (effect follows the unit).
function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID)
	if not weaponDefID or not flameWeapons[weaponDefID] then return end
	if damage and damage < 1 then return end
	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux or uy < 0 then return end  -- underwater: no fire
	addUnitFire(unitID, unitDefID)
end

-- A unit that leaves a wreckage spawns short fire + long smoke at its position.
function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	-- Skip effects when the unit was reclaimed: attacker exists, is a different
	-- unit, and no combat weapon was involved (weaponDefID nil or negative).
	local isReclaimed = attackerID and attackerID ~= unitID and (not weaponDefID or weaponDefID < 0)
	-- Skip effects for unfinished (still-being-built) units.
	local _, _, _, _, buildProgress = Spring.GetUnitHealth(unitID)
	local isUnfinished = buildProgress and buildProgress < 1.0
	local e = unitFireEmitter[unitID]
	if e then
		-- stop the follow emitter; wreckage emitter takes over
		e.unitID = nil
		unitFireEmitter[unitID] = nil
		e.mappedUnit = nil
		e.fireEnd  = mathMin(e.fireEnd, cachedGameFrame)
		e.emberEnd = mathMin(e.emberEnd, cachedGameFrame)
	end
	if isReclaimed or isUnfinished then return end
	if leavesWreck[unitDefID] then
		local x, y, z = spGetUnitPosition(unitID)
		if x and y >= -4 then  -- no wreck fire underwater
			local p    = unitFireParams[unitDefID]
			local sm   = 1.0
			local dm   = 1.0
			-- Flamethrower units burn hotter when they die.
			if flamethrowerUnit[unitDefID] then
				sm = sm * CONFIG.ftScaleMult
				dm = dm * CONFIG.ftDurationMult
			end
			-- Self-destructed units get an additional bonus on top.
			local selfDestruct = (attackerID == nil or attackerID == unitID)
			if selfDestruct then
				sm = sm * CONFIG.sdScaleMult
				dm = dm * CONFIG.sdDurationMult
			end
			local opts = (sm ~= 1.0 or dm ~= 1.0) and { scaleMult = sm, durationMult = dm } or nil
			spawnWreckageFire(x, y, z, p and p.scale or 1.0, opts)
		end
	end
end

-- Bridge so SYNCED gadgets can request fire effects via SendToUnsynced:
--   SendToUnsynced("fire_spawn", x, y, z, scale, duration)
--   SendToUnsynced("fire_wreck", x, y, z, scale)
--   SendToUnsynced("treefire_start", featureID, x, y, z, height, radius, canopyFrac, dirx, dirz, fallFrames)
--   SendToUnsynced("treefire_stop", featureID)
--   SendToUnsynced("treefire_fade", featureID)
function gadget:RecvFromSynced(name, a, b, c, d, e, f, g, h, i, j)
	if name == "fire_spawn" then
		spawnFire(a, b, c, { scale = d, duration = e })
	elseif name == "fire_wreck" then
		spawnWreckageFire(a, b, c, d)
	elseif name == "treefire_start" then
		spawnTreeFire(a, b, c, d, e, f, g, h, i, j)
	elseif name == "treefire_stop" then
		stopTreeFire(a)
	elseif name == "treefire_fade" then
		fadeTreeFire(a)
	end
end

local fpsUpdateInterval = 1
local lastFpsCheckFrame = 0

function gadget:GameFrame(n)
	if not particleVBO then return end

	cachedGameFrame = n

	if n % 10 == 0 then
		local _, _, _, _, wx, _, wz = spGetWind()
		windX = wx or 0
		windZ = wz or 0
	end

	-- FPS-based throttling for the emit pass (rendering still runs every frame)
	if n - lastFpsCheckFrame >= 15 then
		lastFpsCheckFrame = n
		local fps = spGetFPS()
		if fps > 0 then
			fpsUpdateInterval = mathMax(1, mathCeil(40 / fps))
		end
	end

	removeExpiredParticles(n)

	if n % fpsUpdateInterval == 0 then
		updateEmitters(n)
	end
end

function gadget:DrawWorld()
	drawParticles()
end
