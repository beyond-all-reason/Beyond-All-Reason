--------------------------------------------------------------------------------
-- Missile Thruster Effects GL4
-- GPU-instanced replacement for CBitmapMuzzleFlame engine effects on missiles.
-- Renders velocity-aligned textured quads (muzzle flame) + additive glow billboards.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name = "Missile Thruster GL4",
		desc = "GL4 instanced missile engine thruster flame effects",
		author = "Floris",
		date = "April 2026",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Localized functions
--------------------------------------------------------------------------------
local spEcho = Spring.Echo
local spGetVisibleProjectiles = Spring.GetVisibleProjectiles
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetProjectileTeamID = Spring.GetProjectileTeamID
local spGetProjectileTimeToLive = Spring.GetProjectileTimeToLive
local spGetTeamAllyTeamID = Spring.GetTeamAllyTeamID
local spGetTeamList = Spring.GetTeamList
local spIsPosInAirLos = Spring.IsPosInAirLos
local spGetMyAllyTeamID = Spring.GetLocalAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetGameFrame = Spring.GetGameFrame
local spGetGameSpeed = Spring.GetGameSpeed
local spGetCameraPosition = Spring.GetCameraPosition
local spGetCameraDirection = Spring.GetCameraDirection
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers

local glBlending = gl.Blending
local glTexture = gl.Texture
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling = gl.Culling

local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_TRIANGLES = GL.TRIANGLES

local LuaShader = gl.LuaShader
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

local INITIAL_VBO_SIZE = 256 -- starting VBO capacity (doubles automatically when exceeded)

-- Textures
local muzzleTexture = "bitmaps/projectiletextures/muzzleside.tga"
local glowTexture = "bitmaps/projectiletextures/glow2.tga"

-- Global glow multiplier (scales glow color intensity for all missiles)
local GLOW_MULT = 1.1
local GLOW_SIZE_MULT = 1.1 -- global multiplier on glow billboard size

--------------------------------------------------------------------------------
-- Thruster flame configs (shared config file, loadable by other gadgets/widgets)
----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Missile Thruster Flame Configs
-- Per-cegTag thruster visual parameters used by gfx_missile_thruster_gl4 and
-- available for other gadgets/widgets that need missile flame data.
--
-- Fields:
--   length     : flame length (negative = behind projectile)
--   lengthRand : random length variation as fraction of length (0.25 = ±25%)
--   size       : flame width
--   widthRand  : random width variation as fraction of size (0.15 = ±15%)
--   sizeGrowth : how much the flame widens from base to tail
--   colorR/G/B : base color (tip of flame)
--   colorEndR/G/B : end color (tail of flame)
--   glowSize   : fireglow billboard size (0 = no glow)
--   glowR/G/B  : glow color
--   thrusterOffset : backward offset along flight direction (positive = further behind model)
--------------------------------------------------------------------------------
local defaultLengthRand = 0.3
local defaultWidthRand = 0.2
local THRUSTER_CONFIGS = {
	-- Standard small missiles (orange flame trailing behind)
	missiletrailsmall = {
		length = -20,
		size = 1.8,
		sizeGrowth = 0.15,
		colorR = 1.0,
		colorG = 0.7,
		colorB = 0.4,
		colorEndR = 1.0,
		colorEndG = 0.4,
		colorEndB = 0.1,
		glowSize = 28,
		glowR = 0.09,
		glowG = 0.06,
		glowB = 0.012,
		thrusterOffset = 3,
	},
	["missiletrailsmall-simple"] = {
		length = -20,
		size = 1.8,
		sizeGrowth = 0.15,
		colorR = 1.0,
		colorG = 0.7,
		colorB = 0.4,
		colorEndR = 1.0,
		colorEndG = 0.4,
		colorEndB = 0.1,
		glowSize = 28,
		glowR = 0.09,
		glowG = 0.06,
		glowB = 0.012,
		thrusterOffset = 3,
	},
	["missiletrailsmall-red"] = {
		length = -19,
		size = 2.5,
		sizeGrowth = 0.2,
		colorR = 1.0,
		colorG = 0.33,
		colorB = 0.17,
		colorEndR = 1.0,
		colorEndG = 0.22,
		colorEndB = 0.05,
		glowSize = 28,
		glowR = 0.1,
		glowG = 0.025,
		glowB = 0.005,
		thrusterOffset = 0,
	},
	-- Tiny missiles
	missiletrailtiny = {
		length = -13,
		size = 1.2,
		sizeGrowth = 0,
		colorR = 1.0,
		colorG = 0.66,
		colorB = 0.25,
		colorEndR = 0.55,
		colorEndG = 0.3,
		colorEndB = 0.05,
		glowSize = 22,
		glowR = 0.1,
		glowG = 0.06,
		glowB = 0.01,
		thrusterOffset = -5.5,
	},
	-- Medium missiles
	missiletrailmedium = {
		length = -24,
		size = 3.3,
		sizeGrowth = 0.15,
		colorR = 1.0,
		colorG = 0.7,
		colorB = 0.4,
		colorEndR = 1.0,
		colorEndG = 0.4,
		colorEndB = 0.1,
		glowSize = 50,
		glowR = 0.12,
		glowG = 0.08,
		glowB = 0.02,
		thrusterOffset = -1,
	},
	["missiletrailmedium-red"] = {
		length = -24,
		size = 3.3,
		sizeGrowth = 0.15,
		colorR = 1.0,
		colorG = 0.33,
		colorB = 0.17,
		colorEndR = 1.0,
		colorEndG = 0.22,
		colorEndB = 0.05,
		glowSize = 50,
		glowR = 0.13,
		glowG = 0.06,
		glowB = 0.01,
		thrusterOffset = 3,
	},
	["missiletraillarge-red"] = {
		length = -28,
		size = 3.7,
		sizeGrowth = 0.15,
		colorR = 1.0,
		colorG = 0.33,
		colorB = 0.11,
		colorEndR = 1.0,
		colorEndG = 0.12,
		colorEndB = 0.05,
		glowSize = 50,
		glowR = 0.13,
		glowG = 0.06,
		glowB = 0.01,
		thrusterOffset = -2,
	},
	missiletrailviper = {
		length = -32,
		size = 2.8,
		sizeGrowth = 0.33,
		colorR = 1.0,
		colorG = 0.7,
		colorB = 0.4,
		colorEndR = 1.0,
		colorEndG = 0.4,
		colorEndB = 0.1,
		glowSize = 50,
		glowR = 0.12,
		glowG = 0.07,
		glowB = 0.02,
		thrusterOffset = 4,
	},
	-- Fighter missiles (pinkish/purple-tinted, forward-facing)
	missiletrailfighter = {
		length = -20,
		size = 1.65,
		sizeGrowth = 0,
		colorR = 1.0,
		colorG = 0.5,
		colorB = 0.85,
		colorEndR = 0.5,
		colorEndG = 0.1,
		colorEndB = 0.4,
		glowSize = 22,
		glowR = 0.1,
		glowG = 0.045,
		glowB = 0.09,
		thrusterOffset = -16,
	},
	-- AA missiles (pinkish, forward-facing, with large engineglow)
	missiletrailaa = {
		length = -32,
		size = 2.3,
		sizeGrowth = 0,
		colorR = 1.0,
		colorG = 0.5,
		colorB = 0.85,
		colorEndR = 0.5,
		colorEndG = 0.1,
		colorEndB = 0.4,
		glowSize = 32,
		glowR = 0.1,
		glowG = 0.045,
		glowB = 0.09,
		thrusterOffset = -8,
	},
	["missiletrailaa-medium"] = {
		length = -60,
		size = 3.7,
		sizeGrowth = 0,
		colorR = 1.0,
		colorG = 0.5,
		colorB = 0.85,
		colorEndR = 0.5,
		colorEndG = 0.1,
		colorEndB = 0.4,
		glowSize = 48,
		glowR = 0.11,
		glowG = 0.045,
		glowB = 0.1,
		thrusterOffset = 0,
	},
	["missiletrailaa-large"] = {
		length = -100,
		size = 7.5,
		sizeGrowth = 0,
		colorR = 1.0,
		colorG = 0.5,
		colorB = 0.85,
		colorEndR = 0.5,
		colorEndG = 0.1,
		colorEndB = 0.4,
		glowSize = 60,
		glowR = 0.14,
		glowG = 0.045,
		glowB = 0.125,
		thrusterOffset = -35,
	},
	-- Mship (corroyspecial) - larger, redder
	missiletrailmship = {
		length = -7,
		size = 4.0,
		sizeGrowth = 0.2,
		colorR = 1.0,
		colorG = 0.25,
		colorB = 0.05,
		colorEndR = 1.0,
		colorEndG = 0.15,
		colorEndB = 0.03,
		glowSize = 44,
		glowR = 0.1,
		glowG = 0.05,
		glowB = 0.02,
		thrusterOffset = 3,
	},
	["missiletrail-juno"] = {
		length = -50,
		size = 3.5,
		sizeGrowth = 0.2,
		colorR = 0.75,
		colorG = 1.0,
		colorB = 0.5,
		colorEndR = 0.15,
		colorEndG = 1.0,
		colorEndB = 0.03,
		glowSize = 44,
		glowR = 0.03,
		glowG = 0.15,
		glowB = 0.01,
		thrusterOffset = 3,
	},
	["cruisemissiletrail-tacnuke"] = {
		length = -72,
		size = 5.0,
		sizeGrowth = 0.2,
		colorR = 1.0,
		colorG = 0.3,
		colorB = 0.1,
		colorEndR = 1.0,
		colorEndG = 0.15,
		colorEndB = 0.03,
		glowSize = 44,
		glowR = 0.1,
		glowG = 0.05,
		glowB = 0.02,
		thrusterOffset = 3,
	},
	["cruisemissiletrail-emp"] = {
		length = -66,
		size = 4.5,
		sizeGrowth = 0.2,
		colorR = 0.6,
		colorG = 0.6,
		colorB = 1.0,
		colorEndR = 0.1,
		colorEndG = 0.1,
		colorEndB = 1.0,
		glowSize = 44,
		glowR = 0.03,
		glowG = 0.03,
		glowB = 0.15,
		thrusterOffset = 3,
	},
	nuketrail = {
		length = -105,
		size = 7,
		sizeGrowth = 0.2,
		colorR = 1.0,
		colorG = 0.66,
		colorB = 0.2,
		colorEndR = 1.0,
		colorEndG = 0,
		colorEndB = 0,
		glowSize = 44,
		glowR = 0.15,
		glowG = 0.06,
		glowB = 0.03,
		thrusterOffset = -8,
	},

	-- Corroyspecial (no CBitmapMuzzleFlame engine, uses CSimpleParticleSystem fire only)
	-- missiletrailcorroyspecial is intentionally NOT included here
}

-- Starburst variants share the same configs
THRUSTER_CONFIGS["missiletrailsmall-starburst"] = THRUSTER_CONFIGS.missiletrailsmall
THRUSTER_CONFIGS["missiletrailmedium-starburst"] = THRUSTER_CONFIGS.missiletrailmedium

-- Build weaponDefID -> config lookup
local weaponConfigs = {} -- weaponDefID -> thruster config table

for weaponID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.type == "MissileLauncher" or weaponDef.type == "StarburstLauncher" then
		local cp = weaponDef.customParams or {}
		if not cp.bogus then
			local tag = weaponDef.cegTag:lower()
			if tag then
				local cfg = THRUSTER_CONFIGS[tag]
				if cfg then
					weaponConfigs[weaponID] = cfg
				end
			end
		end
	end
end

-- Precompute config defaults and per-frame constants to avoid per-missile overhead
for _, cfg in pairs(weaponConfigs) do
	cfg.sizeGrowth = cfg.sizeGrowth or 0.15
	cfg.glowSize = cfg.glowSize or 0
	cfg.glowR = cfg.glowR or 0.1
	cfg.glowG = cfg.glowG or 0.06
	cfg.glowB = cfg.glowB or 0.02
	cfg.lengthRand = cfg.lengthRand or defaultLengthRand
	cfg.widthRand = cfg.widthRand or defaultWidthRand
	cfg.thrusterOffset = cfg.thrusterOffset or 0
	-- Pre-multiply glow values with global multipliers (avoids 4 muls per missile per frame)
	cfg.glowSizeFinal = cfg.glowSize * GLOW_SIZE_MULT
	cfg.glowRFinal = cfg.glowR * GLOW_MULT
	cfg.glowGFinal = cfg.glowG * GLOW_MULT
	cfg.glowBFinal = cfg.glowB * GLOW_MULT
end

-- Check if we have any missiles to render
local hasConfigs = false
for _ in pairs(weaponConfigs) do
	hasConfigs = true
	break
end
if not hasConfigs then
	function gadget:Initialize()
		spEcho("Missile Thruster GL4: No missile weapons with matching cegTags found, exiting.")
		gadgetHandler:RemoveGadget()
	end
	return
end

--------------------------------------------------------------------------------
-- Vertex shader head shared by all passes: the instance layout and the thruster
-- motion between sim frames (the instance VBO only changes once per sim frame).
--------------------------------------------------------------------------------
local vsHead = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

// Quad vertex: xy = corner position (-1..1), z = 1 on the second (crossed) flame plane
layout (location = 0) in vec4 quadVertex;

// Per-instance data
layout (location = 1) in vec4 posAndSize;       // xyz = sim frame position, w = flame width (size)
layout (location = 2) in vec4 velAndLength;     // xyz = velocity (elmos/frame), w = flame length
layout (location = 3) in vec4 color1;           // base color (tip), a = alpha
layout (location = 4) in vec4 color2;           // end color (tail), a = size growth
layout (location = 5) in vec4 glowData;         // x = glowSize, yzw = glow RGB
layout (location = 6) in vec4 shapeData;        // x = length rand, y = width rand, z = thruster offset

// Drawn thruster position (between sim frames, offset behind the model), flight direction and
// flame size. False for a missile without speed: it has no direction and is not drawn.
bool thrusterMotion(out vec3 worldPos, out vec3 dir, out float flameWidth, out float flameLength)
{
	vec3 vel = velAndLength.xyz;
	float speedSq = dot(vel, vel);
	if (speedSq <= 0.0001) {
		return false;
	}
	dir = vel * inversesqrt(speedSq);
	worldPos = posAndSize.xyz + vel * (timeInfo.w - 1.0) - dir * shapeData.z;

	// Random length/width flicker: new for every instance and draw frame, frozen while paused
	uint h = floatBitsToUint(timeInfo.z) ^ (uint(gl_InstanceID) * 0x9E3779B9u);
	h = (h ^ (h >> 16u)) * 0x7FEB352Du;
	h = (h ^ (h >> 15u)) * 0x846CA68Bu;
	h ^= h >> 16u;
	float rand = float(h >> 8u) * (1.0 / 16777216.0);
	flameWidth = posAndSize.w * (1.0 + rand * shapeData.y);
	flameLength = velAndLength.w * (1.0 + rand * shapeData.x);
	return true;
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Flame (velocity-aligned quad)
-- Each instance draws two planes turned 90 degrees about the flight direction,
-- a cross that is visible from all angles.
--------------------------------------------------------------------------------
local flameVsSrc = vsHead
	.. [[
#line 11000

out DataVS {
	vec2 texCoords;
	vec4 flameColor;
};

void main()
{
	vec3 worldPos, forward;
	float flameWidth, flameLength;
	if (!thrusterMotion(worldPos, forward, flameWidth, flameLength)) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	// Fixed world-derived perpendicular axis (does not rotate with camera).
	// The second plane uses the other perpendicular — together they form a
	// stable cross shape visible from all angles.
	vec3 axis1 = cross(forward, vec3(0.0, 1.0, 0.0));
	float axis1Len = length(axis1);
	if (axis1Len < 0.001) {
		axis1 = normalize(cross(forward, vec3(1.0, 0.0, 0.0)));
	} else {
		axis1 = axis1 / axis1Len;
	}
	vec3 right = (quadVertex.z > 0.5) ? cross(axis1, forward) : axis1;

	// The flame quad extends from the projectile position along the direction.
	// flameLength sign determines direction: negative = behind projectile, positive = forward
	// Map vertex y from -1..1 to 0..1 (flame starts at projectile, extends away)
	float yNorm = quadVertex.y * 0.5 + 0.5;  // 0 at projectile, 1 at tip/tail

	// SizeGrowth: flame widens from base to tail (matching engine sizegrowth behavior)
	float sizeGrowth = color2.a;
	float widthScale = 1.0 + sizeGrowth * yNorm;

	// Per-instance animation phase from world position
	float phase = worldPos.x * 1.0 + worldPos.z * 1.3;

	// Width shimmer: subtle oscillation simulating re-spawned flame overlap
	float shimmer = 1.0 + SHIMMER_AMPLITUDE * sin(timeInfo.z * SHIMMER_SPEED + phase) * (SHIMMER_TAIL_BIAS + (1.0 - SHIMMER_TAIL_BIAS) * yNorm);

	float width = flameWidth * widthScale * shimmer;

	vec3 vertexWorld = worldPos
		+ right * quadVertex.x * width
		+ forward * yNorm * flameLength;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	// Swap UV: texture u (256px) = flame length axis, v (128px) = flame width axis
	texCoords = vec2(yNorm, quadVertex.x * 0.5 + 0.5);

	// Interpolate color along the flame length
	float t = yNorm;  // 0 = at projectile (base), 1 = end of flame (tip)

	vec3 tipColor = color1.rgb;
	vec3 endColor = color2.rgb;
	float alpha = color1.a;

	// Color gradient: tip -> end color, then fade
	vec3 col = mix(tipColor, endColor, smoothstep(0.0, COLOR_GRADIENT_END, t));

	// Alpha: brightness pulse + fade at tail
	float breathe = BREATHE_BASE + BREATHE_RANGE * sin(timeInfo.z * BREATHE_SPEED + phase * 3.1);
	alpha *= breathe * (1.0 - smoothstep(TAIL_FADE_START, TAIL_FADE_END, t));

	flameColor = vec4(col, alpha);
}
]]

local flameFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D flameTex;

in DataVS {
	vec2 texCoords;
	vec4 flameColor;
};

out vec4 fragColor;

void main(void)
{
	vec4 texSample = texture(flameTex, texCoords);

	// Texture is near-grayscale; per-channel multiply tints it with flame color
	vec3 color = texSample.rgb * flameColor.rgb * flameColor.a;

	// Brightness boost: engine overlaps ~2 additive flames (ttl=2), we draw 1
	color *= BRIGHTNESS_MULT;

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.002) discard;

	fragColor = vec4(color, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Cross-section (camera-facing circular billboard)
-- Visible when looking along the missile velocity direction (head-on).
-- Fades out from the side so it doesn't double-up with flame quads.
--------------------------------------------------------------------------------
local crossSectionVsSrc = vsHead
	.. [[
#line 60000

out DataVS {
	vec2 texCoords;
	vec3 flameColor;
	float headOnFactor;
};

void main()
{
	vec3 worldPos, forward;
	float flameWidth, flameLength;
	if (!thrusterMotion(worldPos, forward, flameWidth, flameLength)) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	// How head-on is the camera view? (1 = looking along velocity, 0 = side view)
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCamera = normalize(camPos - worldPos);
	float headOn = abs(dot(forward, toCamera));

	// Only visible when looking along velocity; cull from side view
	if (headOn < 0.3) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	// Camera-facing billboard, circular
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	float crossSize = flameWidth * CROSS_SECTION_SIZE_MULT;

	vec3 vertexWorld = worldPos
		+ camRight * quadVertex.x * crossSize
		+ camUp    * quadVertex.y * crossSize;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	texCoords = quadVertex.xy * 0.5 + 0.5;
	flameColor = color1.rgb;
	headOnFactor = smoothstep(0.3, 0.7, headOn);
}
]]

local crossSectionFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 70000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D crossSectionTex;

in DataVS {
	vec2 texCoords;
	vec3 flameColor;
	float headOnFactor;
};

out vec4 fragColor;

void main(void)
{
	vec4 texSample = texture(crossSectionTex, texCoords);
	vec3 color = flameColor * texSample.rgb * headOnFactor * CROSS_SECTION_BRIGHTNESS;

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.002) discard;

	fragColor = vec4(color, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Glow (camera-facing billboard)
--------------------------------------------------------------------------------
local glowVsSrc = vsHead
	.. [[
#line 30000

out DataVS {
	vec2 texCoords;
	vec4 color;
};

void main()
{
	float glowSize = glowData.x;
	vec3 worldPos, dir;
	float flameWidth, flameLength;

	// Skip instances with no glow (degenerate quad off-screen)
	if (glowSize <= 0.0 || !thrusterMotion(worldPos, dir, flameWidth, flameLength)) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	// Offset glow center 1/3 along the flame length (toward the tail)
	vec3 glowCenter = worldPos + dir * flameLength * 0.4;

	// Billboard: camera-facing quad
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	vec3 vertexWorld = glowCenter
		+ camRight * quadVertex.x * glowSize
		+ camUp    * quadVertex.y * glowSize;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);
	texCoords = quadVertex.xy * 0.5 + 0.5;
	color = vec4(glowData.yzw, 1.0);
}
]]

local glowFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 40000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D glowTex;

in DataVS {
	vec2 texCoords;
	vec4 color;
};

out vec4 fragColor;

void main(void)
{
	vec4 texSample = texture(glowTex, texCoords);
	vec3 col = color.rgb * texSample.rgb;
	float a = texSample.a * color.a;

	if (a < 0.002) discard;

	fragColor = vec4(col * a, a);
}
]]

--------------------------------------------------------------------------------
-- GL4 state
--------------------------------------------------------------------------------

---@type InstanceVBOTable?
local flameVBO
---@type VAO
local flameVAO
local flameShader -- both crossed velocity-aligned flame planes
local crossSectionShader -- camera-facing billboard for head-on view
local glowShader

-- Instances are rebuilt once per sim frame; the vertex shaders move them between sim frames
local builtFrame = -1
local needsRebuild = true
local slotConfig = {} -- per instance slot: the config whose constant attributes it holds

-- Subscription handle for the shared projectile dispatcher (set in Initialize).
-- When nil, we fall back to calling Spring.GetVisibleProjectiles directly.
local dispatchHandle = nil

-- Cross-section billboard (camera-facing, visible when looking along missile velocity)
local CROSS_SECTION_BRIGHTNESS = 0.5 -- brightness for head-on cross-section glow
local CROSS_SECTION_SIZE_MULT = 1.5 -- cross-section billboard size relative to flame width

-- Paused-state camera tracking: while paused, projectiles are frozen so the
-- only thing that can change the drawn set is the camera moving.
local wasPaused = false
local pausedCamX, pausedCamY, pausedCamZ = 0, 0, 0
local pausedCamDX, pausedCamDY, pausedCamDZ = 0, 0, 0
local pausedLastRebuildTimer = nil
local PAUSED_MOVE_MIN_INTERVAL = 0.05

local myAllyTeamID = spGetMyAllyTeamID()
local specFullView = false
local alliedTeams = {} -- teamID -> true for the teams of myAllyTeamID

local function goodbye(reason)
	spEcho("Missile Thruster GL4 exiting: " .. reason)
	gadgetHandler:RemoveGadget()
end

local function initGL4()
	-- Flame shader
	local flameShaderCache = {
		vsSrc = flameVsSrc,
		fsSrc = flameFsSrc,
		shaderName = "MissileThrusterFlameGL4",
		uniformInt = { flameTex = 0 },
		uniformFloat = {},
		shaderConfig = {
			SHIMMER_AMPLITUDE = 0.2, -- width oscillation strength (0 = off)
			SHIMMER_SPEED = 0.2, -- width oscillation speed
			SHIMMER_TAIL_BIAS = 0.5, -- how much shimmer at base vs tail (0 = tail only, 1 = uniform)
			BREATHE_BASE = 0.9, -- minimum brightness (pulse trough)
			BREATHE_RANGE = 0.13, -- brightness pulse range (peak = base + range)
			BREATHE_SPEED = 0.13, -- brightness pulse speed
			COLOR_GRADIENT_END = 0.7, -- normalized position where color fully transitions to endColor
			TAIL_FADE_START = 0.6, -- normalized position where tail alpha begins fading
			TAIL_FADE_END = 0.999, -- normalized position where tail alpha reaches zero
			BRIGHTNESS_MULT = 2.0, -- overall brightness multiplier
		},
		forceupdate = true,
	}
	flameShader = LuaShader.CheckShaderUpdates(flameShaderCache)
	if not flameShader then
		goodbye("Failed to compile flame shader")
		return false
	end

	-- Cross-section shader (camera-facing head-on view)
	local crossSectionShaderCache = {
		vsSrc = crossSectionVsSrc,
		fsSrc = crossSectionFsSrc,
		shaderName = "MissileThrusterCrossSectionGL4",
		uniformInt = { crossSectionTex = 0 },
		uniformFloat = {},
		shaderConfig = {
			CROSS_SECTION_BRIGHTNESS = CROSS_SECTION_BRIGHTNESS,
			CROSS_SECTION_SIZE_MULT = CROSS_SECTION_SIZE_MULT,
		},
		forceupdate = true,
	}
	crossSectionShader = LuaShader.CheckShaderUpdates(crossSectionShaderCache)
	if not crossSectionShader then
		goodbye("Failed to compile cross-section shader")
		return false
	end

	-- Glow shader
	local glowShaderCache = {
		vsSrc = glowVsSrc,
		fsSrc = glowFsSrc,
		shaderName = "MissileThrusterGlowGL4",
		uniformInt = { glowTex = 0 },
		uniformFloat = {},
		shaderConfig = {},
		forceupdate = true,
	}
	glowShader = LuaShader.CheckShaderUpdates(glowShaderCache)
	if not glowShader then
		goodbye("Failed to compile glow shader")
		return false
	end

	-- Two crossed quads of 6 vertices (xy = corner, z = plane); the billboard passes draw the first
	local quadVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	if not quadVBO then
		goodbye("Failed to create quad VBO")
		return false
	end
	local corners = { -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1 }
	local quadVertices = {}
	for plane = 0, 1 do
		for i = 1, #corners, 2 do
			local n = #quadVertices
			quadVertices[n + 1] = corners[i]
			quadVertices[n + 2] = corners[i + 1]
			quadVertices[n + 3] = plane
			quadVertices[n + 4] = 0
		end
	end
	quadVBO:Define(12, { { id = 0, name = "quadVertex", size = 4 } })
	quadVBO:Upload(quadVertices)

	-- Flame VBO (combined layout: flame data + embedded glow data)
	local flameLayout = {
		{ id = 1, name = "posAndSize", size = 4 },
		{ id = 2, name = "velAndLength", size = 4 },
		{ id = 3, name = "color1", size = 4 },
		{ id = 4, name = "color2", size = 4 },
		{ id = 5, name = "glowData", size = 4 },
		{ id = 6, name = "shapeData", size = 4 },
	}
	flameVBO = gl.InstanceVBOTable.makeInstanceVBOTable(flameLayout, INITIAL_VBO_SIZE, "missileThrusterFlameVBO")
	if not flameVBO then
		goodbye("Failed to create flame VBO")
		return false
	end
	flameVAO = flameVBO:makeVAOandAttach(quadVBO, flameVBO.instanceVBO)

	return true
end

local function resizeFlameVBO(needed)
	local newMax = flameVBO.maxElements
	while newMax < needed do
		newMax = newMax * 2
	end
	flameVBO.maxElements = newMax
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	newInstanceVBO:Define(newMax, flameVBO.layout)
	flameVBO.instanceVBO:Delete()
	flameVBO.instanceVBO = newInstanceVBO
	local data = flameVBO.instanceData
	local step = flameVBO.instanceStep
	for i = #data + 1, step * newMax do
		data[i] = 0
	end
	flameVAO:Delete()
	flameVAO = flameVBO:makeVAOandAttach(flameVBO.vertexVBO, flameVBO.instanceVBO)
end

local function cleanupGL4()
	if flameVBO then
		flameVBO:Delete()
		flameVBO = nil
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local function drawAll()
	local count = flameVBO.usedElements
	if count == 0 then
		return
	end
	local vao = flameVAO

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE)

	-- Flame pass: both crossed planes
	glTexture(0, muzzleTexture)
	flameShader:Activate()
	vao:DrawArrays(GL_TRIANGLES, 12, 0, count)
	flameShader:Deactivate()

	-- Cross-section pass (camera-facing, head-on view)
	glTexture(0, glowTexture)
	crossSectionShader:Activate()
	vao:DrawArrays(GL_TRIANGLES, 6, 0, count)
	crossSectionShader:Deactivate()

	-- Glow pass (same VBO, glow shader reads glowData; zero-size glows culled in VS)
	glowShader:Activate()
	vao:DrawArrays(GL_TRIANGLES, 6, 0, count)
	glowShader:Deactivate()
	glTexture(0, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Per-sim-frame projectile scan + VBO upload
-- Uses direct instanceData writes instead of pushElementInstance to avoid
-- per-instance hash lookups/writes and per-frame hash table allocations.
--------------------------------------------------------------------------------
local INSTANCE_STEP = 24 -- posAndSize, velAndLength, color1, color2, glowData, shapeData

local function rebuildInstances()
	-- Pull the pre-filtered missile projectile list from the shared dispatcher.
	-- When the dispatcher is loaded it has already called GetProjectileDefID
	-- once per projectile (shared with every other gfx_*_gl4 consumer) and
	-- handed us a parallel defID array, so we skip the per-projectile defID
	-- query that this loop used to do. Fallback to direct engine call when
	-- the dispatcher isn't loaded.
	local projectiles, matchDefIDs, nProj
	local PS = GG.ProjectileScan
	local dispatcherFiltered = (PS ~= nil and dispatchHandle ~= nil)
	if dispatcherFiltered then
		projectiles, matchDefIDs, nProj = PS.GetMatchesWithDefIDs(dispatchHandle)
	else
		projectiles = spGetVisibleProjectiles(-1, true, true, false)
		nProj = projectiles and #projectiles or 0
	end

	local data = flameVBO.instanceData
	local count = 0
	local myAllyTeam = myAllyTeamID
	local allied = alliedTeams
	local needLosCheck = not specFullView
	local configs = weaponConfigs
	local slots = slotConfig

	for i = 1, nProj do
		local proID = projectiles[i]
		local cfg
		if dispatcherFiltered then
			cfg = configs[matchDefIDs[i]]
		else
			cfg = configs[spGetProjectileDefID(proID)]
		end
		if cfg then
			-- Skip thruster if missile has run out of propulsion (TTL expired)
			local ttl = spGetProjectileTimeToLive(proID)
			if not ttl or ttl > 0 then
				local px, py, pz = spGetProjectilePosition(proID)
				local visible = px ~= nil
				-- LOS check: own allyteam projectiles always visible, enemy ones need LOS
				-- (LOS is tested first, so missiles in LOS need no team lookup)
				if visible and needLosCheck and not spIsPosInAirLos(px, 0, pz, myAllyTeam) then
					visible = allied[spGetProjectileTeamID(proID)]
				end
				if visible then
					local vx, vy, vz = spGetProjectileVelocity(proID)
					if vx then
						local offset = count * INSTANCE_STEP
						count = count + 1
						data[offset + 1] = px
						data[offset + 2] = py
						data[offset + 3] = pz
						data[offset + 5] = vx
						data[offset + 6] = vy
						data[offset + 7] = vz
						if slots[count] ~= cfg then
							slots[count] = cfg
							data[offset + 4] = cfg.size
							data[offset + 8] = cfg.length
							data[offset + 9] = cfg.colorR
							data[offset + 10] = cfg.colorG
							data[offset + 11] = cfg.colorB
							data[offset + 12] = 1.0
							data[offset + 13] = cfg.colorEndR
							data[offset + 14] = cfg.colorEndG
							data[offset + 15] = cfg.colorEndB
							data[offset + 16] = cfg.sizeGrowth
							data[offset + 17] = cfg.glowSizeFinal
							data[offset + 18] = cfg.glowRFinal
							data[offset + 19] = cfg.glowGFinal
							data[offset + 20] = cfg.glowBFinal
							data[offset + 21] = cfg.lengthRand
							data[offset + 22] = cfg.widthRand
							data[offset + 23] = cfg.thrusterOffset
							data[offset + 24] = 0
						end
					end
				end
			end
		end
	end

	flameVBO.usedElements = count
	if count > 0 then
		if count > flameVBO.maxElements then
			resizeFlameVBO(count)
		end
		uploadAllElements(flameVBO)
	end
end

-- While paused only the camera can change which projectiles are visible: rebuild when it
-- moves (throttled, paused FPS is uncapped) so missiles panned back on-screen reappear.
local function pausedViewChanged()
	local _, _, isPaused = spGetGameSpeed()
	local firstPausedDraw = isPaused and not wasPaused
	wasPaused = isPaused
	if not isPaused then
		return false
	end
	local cx, cy, cz = spGetCameraPosition()
	local dx, dy, dz = spGetCameraDirection()
	if firstPausedDraw then
		pausedLastRebuildTimer = nil
	else
		if
			cx == pausedCamX
			and cy == pausedCamY
			and cz == pausedCamZ
			and dx == pausedCamDX
			and dy == pausedCamDY
			and dz == pausedCamDZ
		then
			return false
		end
		local now = spGetTimer()
		if pausedLastRebuildTimer and spDiffTimers(now, pausedLastRebuildTimer) < PAUSED_MOVE_MIN_INTERVAL then
			return false
		end
		pausedLastRebuildTimer = now
	end
	pausedCamX, pausedCamY, pausedCamZ = cx, cy, cz
	pausedCamDX, pausedCamDY, pausedCamDZ = dx, dy, dz
	return true
end

local function updateLosView()
	myAllyTeamID = spGetMyAllyTeamID()
	local _, fullView = spGetSpectatingState()
	specFullView = fullView
	alliedTeams = {}
	local teams = spGetTeamList()
	---@cast teams -?
	for i = 1, #teams do
		if spGetTeamAllyTeamID(teams[i]) == myAllyTeamID then
			alliedTeams[teams[i]] = true
		end
	end
	needsRebuild = true
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	if not initGL4() then
		return
	end
	-- PlayerChanged does not fire at game start
	updateLosView()
	local n = 0
	for _ in pairs(weaponConfigs) do
		n = n + 1
	end

	-- Subscribe to the shared projectile dispatcher so we share the per-frame
	-- GetVisibleProjectiles + GetProjectileDefID scan with the other gfx_*_gl4
	-- gadgets instead of each calling them independently.
	local PS = GG.ProjectileScan
	if PS then
		local defIDSet = {}
		for wDefID in pairs(weaponConfigs) do
			defIDSet[wDefID] = true
		end
		dispatchHandle = PS.Subscribe("missile_thruster", defIDSet, PS.SCAN_VISIBLE)
	end

	spEcho("Missile Thruster GL4: initialized with " .. n .. " weapon configs")
end

function gadget:PlayerChanged()
	updateLosView()
end

function gadget:Shutdown()
	cleanupGL4()
end

function gadget:DrawWorld()
	local gameFrame = spGetGameFrame()
	if pausedViewChanged() or gameFrame ~= builtFrame or needsRebuild then
		builtFrame = gameFrame
		needsRebuild = false
		rebuildInstances()
	end
	drawAll()
end
