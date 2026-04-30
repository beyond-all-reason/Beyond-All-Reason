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
local spIsPosInAirLos = Spring.IsPosInAirLos
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetFrameTimeOffset = Spring.GetFrameTimeOffset

local glBlending = gl.Blending
local glTexture = gl.Texture
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling = gl.Culling

local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA = GL.SRC_ALPHA

local mathRandom = math.random
local mathSqrt = math.sqrt

local LuaShader = gl.LuaShader
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

-- Max simultaneous missile flames (should be more than enough)
local MAX_FLAMES = 4096

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
		sizeGrowth = 0.2,
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
		sizeGrowth = 0.2,
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
		sizeGrowth = 0.2,
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
		sizeGrowth = 0.2,
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
		sizeGrowth = 0.2,
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
		sizeGrowth = 0.5,
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
	cfg.sizeGrowth = cfg.sizeGrowth or 0.2
	cfg.glowSize = cfg.glowSize or 0
	cfg.glowR = cfg.glowR or 0.1
	cfg.glowG = cfg.glowG or 0.06
	cfg.glowB = cfg.glowB or 0.02
	cfg.lengthRand = cfg.lengthRand or defaultLengthRand
	cfg.widthRand = cfg.widthRand or defaultWidthRand
	cfg.hasRand = cfg.lengthRand > 0 or cfg.widthRand > 0
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
-- Shader sources: Flame (velocity-aligned quad)
--------------------------------------------------------------------------------
local flameVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

// Quad vertex: xy = corner position (-1..1), zw = UV
layout (location = 0) in vec4 position_xy_uv;

// Per-instance data
layout (location = 1) in vec4 posAndSize;      // xyz = projectile world pos, w = flame width (size)
layout (location = 2) in vec4 dirAndLength;     // xyz = normalized direction, w = flame length
layout (location = 3) in vec4 color1;           // base color (tip), a = alpha
layout (location = 4) in vec4 color2;           // end color (tail), a = unused

out DataVS {
	vec2 texCoords;
	vec4 flameColor;
};

void main()
{
	vec3 worldPos = posAndSize.xyz;
	float flameWidth = posAndSize.w;
	vec3 dir = dirAndLength.xyz;
	float flameLength = dirAndLength.w;

	// Build orientation basis from direction vector
	// The flame quad is stretched along 'dir', with width perpendicular
	vec3 forward = normalize(dir);

	// Fixed world-derived perpendicular axis (does not rotate with camera).
	// The cross pass uses the other perpendicular — together they form a
	// stable cross shape visible from all angles.
	vec3 right = cross(forward, vec3(0.0, 1.0, 0.0));
	float rightLen = length(right);
	if (rightLen < 0.001) {
		right = normalize(cross(forward, vec3(1.0, 0.0, 0.0)));
	} else {
		right = right / rightLen;
	}

	// The flame quad extends from the projectile position along the direction.
	// position_xy_uv.y: 0..1 (from makeRectVBO UV), but position_xy_uv.y vertex: -1..1
	// We want the flame to start at the projectile and extend in the flame direction.
	// flameLength sign determines direction: negative = behind projectile, positive = forward
	// Map vertex y from -1..1 to 0..1 (flame starts at projectile, extends away)
	float yNorm = position_xy_uv.y * 0.5 + 0.5;  // 0 at projectile, 1 at tip/tail

	// SizeGrowth: flame widens from base to tail (matching engine sizegrowth behavior)
	float sizeGrowth = color2.a;
	float widthScale = 1.0 + sizeGrowth * yNorm;

	// Per-instance animation phase from world position
	float phase = worldPos.x * 1.0 + worldPos.z * 1.3;

	// Width shimmer: subtle oscillation simulating re-spawned flame overlap
	float shimmer = 1.0 + SHIMMER_AMPLITUDE * sin(timeInfo.z * SHIMMER_SPEED + phase) * (SHIMMER_TAIL_BIAS + (1.0 - SHIMMER_TAIL_BIAS) * yNorm);

	float width = flameWidth * widthScale * shimmer;

	vec3 vertexWorld = worldPos
		+ right * position_xy_uv.x * width
		+ forward * yNorm * flameLength;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	// Swap UV: texture u (256px) = flame length axis, v (128px) = flame width axis
	texCoords = vec2(position_xy_uv.w, position_xy_uv.z);

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
-- Shader sources: Cross flame (90-degree rotated flame quad)
-- Uses axis2 = cross(axis1, forward) so the two flame quads form a cross.
-- Reuses the same fragment shader as the main flame pass.
--------------------------------------------------------------------------------
local crossFlameVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 50000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec4 posAndSize;
layout (location = 2) in vec4 dirAndLength;
layout (location = 3) in vec4 color1;
layout (location = 4) in vec4 color2;

out DataVS {
	vec2 texCoords;
	vec4 flameColor;
};

void main()
{
	vec3 worldPos = posAndSize.xyz;
	float flameWidth = posAndSize.w;
	vec3 dir = dirAndLength.xyz;
	float flameLength = dirAndLength.w;

	vec3 forward = normalize(dir);

	// Second perpendicular axis: cross(axis1, forward) where axis1 = cross(forward, worldUp).
	// Together with the main pass (which uses axis1) this forms a stable cross.
	vec3 axis1 = cross(forward, vec3(0.0, 1.0, 0.0));
	float axis1Len = length(axis1);
	if (axis1Len < 0.001) {
		axis1 = normalize(cross(forward, vec3(1.0, 0.0, 0.0)));
	} else {
		axis1 = axis1 / axis1Len;
	}
	vec3 right = cross(axis1, forward);

	float yNorm = position_xy_uv.y * 0.5 + 0.5;

	float sizeGrowth = color2.a;
	float widthScale = 1.0 + sizeGrowth * yNorm;

	float phase = worldPos.x * 1.0 + worldPos.z * 1.3;
	float shimmer = 1.0 + SHIMMER_AMPLITUDE * sin(timeInfo.z * SHIMMER_SPEED + phase) * (SHIMMER_TAIL_BIAS + (1.0 - SHIMMER_TAIL_BIAS) * yNorm);

	float width = flameWidth * widthScale * shimmer;

	vec3 vertexWorld = worldPos
		+ right * position_xy_uv.x * width
		+ forward * yNorm * flameLength;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	texCoords = vec2(position_xy_uv.w, position_xy_uv.z);

	float t = yNorm;
	vec3 tipColor = color1.rgb;
	vec3 endColor = color2.rgb;
	float alpha = color1.a;

	vec3 col = mix(tipColor, endColor, smoothstep(0.0, COLOR_GRADIENT_END, t));

	float breathe = BREATHE_BASE + BREATHE_RANGE * sin(timeInfo.z * BREATHE_SPEED + phase * 3.1);
	alpha *= breathe * (1.0 - smoothstep(TAIL_FADE_START, TAIL_FADE_END, t));

	flameColor = vec4(col, alpha);
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Cross-section (camera-facing circular billboard)
-- Visible when looking along the missile velocity direction (head-on).
-- Fades out from the side so it doesn't double-up with flame quads.
--------------------------------------------------------------------------------
local crossSectionVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 60000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec4 posAndSize;
layout (location = 2) in vec4 dirAndLength;
layout (location = 3) in vec4 color1;

out DataVS {
	vec2 texCoords;
	vec3 flameColor;
	float headOnFactor;
};

void main()
{
	vec3 worldPos = posAndSize.xyz;
	float flameWidth = posAndSize.w;
	vec3 dir = dirAndLength.xyz;

	vec3 forward = normalize(dir);

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
		+ camRight * position_xy_uv.x * crossSize
		+ camUp    * position_xy_uv.y * crossSize;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	texCoords = position_xy_uv.zw;
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
local glowVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 30000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;

// Per-instance (shared layout with flame VBO)
layout (location = 1) in vec4 posAndSize;      // xyz = world pos, w = flame width (unused for glow)
layout (location = 2) in vec4 dirAndLength;     // xyz = normalized direction, w = flame length
layout (location = 5) in vec4 glowData;         // x = glowSize, yzw = glow RGB

out DataVS {
	vec2 texCoords;
	vec4 color;
};

void main()
{
	vec3 worldPos = posAndSize.xyz;
	float glowSize = glowData.x;

	// Skip instances with no glow (degenerate quad off-screen)
	if (glowSize <= 0.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	// Offset glow center 1/3 along the flame length (toward the tail)
	vec3 dir = dirAndLength.xyz;
	float flameLength = dirAndLength.w;
	vec3 glowCenter = worldPos + dir * flameLength * 0.4;

	// Billboard: camera-facing quad
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	vec3 vertexWorld = glowCenter
		+ camRight * position_xy_uv.x * glowSize
		+ camUp    * position_xy_uv.y * glowSize;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);
	texCoords = position_xy_uv.zw;
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
local flameVBO
local flameShader
local crossFlameShader -- 90-degree rotated flame for volume from all angles
local crossSectionShader -- camera-facing billboard for head-on view
local glowShader

-- Per-projectile persistent state (direction + position cache for pause fallback)
local projectileCache = {} -- proID -> {dx, dy, dz, px, py, pz}
local cacheCleanupFrame = 0

-- Cross-section billboard (camera-facing, visible when looking along missile velocity)
local CROSS_SECTION_BRIGHTNESS = 0.5 -- brightness for head-on cross-section glow
local CROSS_SECTION_SIZE_MULT = 1.5 -- cross-section billboard size relative to flame width

-- Idle skip: when no missiles found, throttle GetVisibleProjectiles polling
local idleSkipCounter = 0
local IDLE_SKIP_FRAMES = 5 -- only poll every Nth draw frame when idle

-- Cached ally team (updated via PlayerChanged / spectator change)
local cachedAllyTeamID = spGetMyAllyTeamID()
local cachedSpecFullView = false

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

	-- Cross flame shader (reuses flame FS with different VS axes)
	local crossFlameShaderCache = {
		vsSrc = crossFlameVsSrc,
		fsSrc = flameFsSrc,
		shaderName = "MissileThrusterCrossFlameGL4",
		uniformInt = { flameTex = 0 },
		uniformFloat = {},
		shaderConfig = flameShaderCache.shaderConfig,
		forceupdate = true,
	}
	crossFlameShader = LuaShader.CheckShaderUpdates(crossFlameShaderCache)
	if not crossFlameShader then
		goodbye("Failed to compile cross flame shader")
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

	-- Shared quad VBOs
	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(-1, -1, 1, 1, 0, 0, 1, 1, "missileThrusterQuadVBO")
	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("missileThrusterIndexVBO")

	-- Flame VBO (combined layout: flame data + embedded glow data, UV flip via alpha sign)
	local flameLayout = {
		{ id = 1, name = "posAndSize", size = 4 },
		{ id = 2, name = "dirAndLength", size = 4 },
		{ id = 3, name = "color1", size = 4 },
		{ id = 4, name = "color2", size = 4 },
		{ id = 5, name = "glowData", size = 4 },
	}
	flameVBO = gl.InstanceVBOTable.makeInstanceVBOTable(flameLayout, MAX_FLAMES, "missileThrusterFlameVBO")
	if not flameVBO then
		goodbye("Failed to create flame VBO")
		return false
	end
	flameVBO.numVertices = numVertices
	flameVBO.vertexVBO = quadVBO
	flameVBO.VAO = flameVBO:makeVAOandAttach(quadVBO, flameVBO.instanceVBO)
	flameVBO.primitiveType = GL.TRIANGLES
	flameVBO.VAO:AttachIndexBuffer(indexVBO)
	flameVBO.indexVBO = indexVBO

	return true
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
	if flameVBO.usedElements == 0 then
		return
	end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE)

	-- Flame pass (axis1: cross(forward, worldUp))
	glTexture(0, muzzleTexture)
	flameShader:Activate()
	flameVBO:Draw()
	flameShader:Deactivate()

	-- Cross flame pass (axis2: cross(axis1, forward) — 90-degree rotated)
	crossFlameShader:Activate()
	flameVBO:Draw()
	crossFlameShader:Deactivate()

	-- Cross-section pass (camera-facing, head-on view)
	glTexture(0, glowTexture)
	crossSectionShader:Activate()
	flameVBO:Draw()
	crossSectionShader:Deactivate()

	-- Glow pass (same VBO, glow shader reads glowData; zero-size glows culled in VS)
	glowShader:Activate()
	flameVBO:Draw()
	glowShader:Deactivate()
	glTexture(0, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Per-frame projectile scan + VBO upload
-- Uses direct instanceData writes instead of pushElementInstance to avoid
-- per-instance hash lookups/writes and per-frame hash table allocations.
--------------------------------------------------------------------------------

local function updateMissiles()
	-- When idle (no missiles last check), throttle polling to every Nth draw frame
	if idleSkipCounter > 0 then
		idleSkipCounter = idleSkipCounter - 1
		return
	end

	flameVBO.usedElements = 0

	local ftoAdj = spGetFrameTimeOffset() - 1.0

	local projectiles = spGetVisibleProjectiles(-1, true, true, false)
	if not projectiles or #projectiles == 0 then
		idleSkipCounter = IDLE_SKIP_FRAMES
		return
	end

	local flameData = flameVBO.instanceData
	local flameStep = 20 -- posAndSize(4) + dirAndLength(4) + color1(4) + color2(4) + glowData(4)
	local flameCount = 0
	local myAllyTeam = cachedAllyTeamID
	local needLosCheck = not cachedSpecFullView

	for i = 1, #projectiles do
		local proID = projectiles[i]
		local cfg = weaponConfigs[spGetProjectileDefID(proID)]
		if cfg then
			-- Skip thruster if missile has run out of propulsion (TTL expired)
			local ttl = spGetProjectileTimeToLive(proID)
			if not ttl or ttl > 0 then
				local px, py, pz = spGetProjectilePosition(proID)
				if px then
					-- LOS check: own allyteam projectiles always visible, enemy ones need LOS
					local visible = true
					if needLosCheck then
						local proTeam = spGetProjectileTeamID(proID)
						local proAlly = proTeam and spGetTeamAllyTeamID(proTeam)
						if proAlly ~= myAllyTeam then
							visible = spIsPosInAirLos(px, 0, pz, myAllyTeam)
						end
					end
					if visible then
						local vx, vy, vz = spGetProjectileVelocity(proID)
						if vx then
							local speedSq = vx * vx + vy * vy + vz * vz
							local dx, dy, dz

							if speedSq > 0.0001 then
								local invSpeed = 1.0 / mathSqrt(speedSq)
								dx, dy, dz = vx * invSpeed, vy * invSpeed, vz * invSpeed
								px = px + vx * ftoAdj
								py = py + vy * ftoAdj
								pz = pz + vz * ftoAdj
								local ofs = cfg.thrusterOffset
								px = px - dx * ofs
								py = py - dy * ofs
								pz = pz - dz * ofs
								local cached = projectileCache[proID]
								if cached then
									cached[1], cached[2], cached[3] = dx, dy, dz
									cached[4], cached[5], cached[6] = px, py, pz
								else
									projectileCache[proID] = { dx, dy, dz, px, py, pz }
								end
							else
								local cached = projectileCache[proID]
								if cached then
									dx, dy, dz = cached[1], cached[2], cached[3]
									px, py, pz = cached[4], cached[5], cached[6]
								end
							end

							if dx then
								local length = cfg.length
								local size = cfg.size
								if cfg.hasRand then
									local rand = mathRandom()
									length = length * (1 + rand * cfg.lengthRand)
									size = size * (1 + rand * cfg.widthRand)
								end

								flameCount = flameCount + 1
								if flameCount > MAX_FLAMES then
									break
								end
								local offset = (flameCount - 1) * flameStep
								flameData[offset + 1] = px
								flameData[offset + 2] = py
								flameData[offset + 3] = pz
								flameData[offset + 4] = size
								flameData[offset + 5] = dx
								flameData[offset + 6] = dy
								flameData[offset + 7] = dz
								flameData[offset + 8] = length
								flameData[offset + 9] = cfg.colorR
								flameData[offset + 10] = cfg.colorG
								flameData[offset + 11] = cfg.colorB
								flameData[offset + 12] = 1.0
								flameData[offset + 13] = cfg.colorEndR
								flameData[offset + 14] = cfg.colorEndG
								flameData[offset + 15] = cfg.colorEndB
								flameData[offset + 16] = cfg.sizeGrowth
								flameData[offset + 17] = cfg.glowSizeFinal
								flameData[offset + 18] = cfg.glowRFinal
								flameData[offset + 19] = cfg.glowGFinal
								flameData[offset + 20] = cfg.glowBFinal
							end
						end
					end
				end
			end -- ttl check
		end -- cfg check
	end

	flameVBO.usedElements = flameCount
	if flameCount > 0 then
		idleSkipCounter = 0 -- missiles active, poll every frame
		uploadAllElements(flameVBO)
	else
		idleSkipCounter = IDLE_SKIP_FRAMES -- no matching missiles, throttle
	end
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	if not initGL4() then
		return
	end
	local n = 0
	for _ in pairs(weaponConfigs) do
		n = n + 1
	end
	spEcho("Missile Thruster GL4: initialized with " .. n .. " weapon configs")
end

function gadget:GameFrame(n)
	-- Periodic cache cleanup (runs in GameFrame to avoid per-draw overhead)
	if n > cacheCleanupFrame then
		cacheCleanupFrame = n + 90
		-- Two-pass cleanup: mark then sweep (avoids table alloc for removeList)
		local hasEntries = false
		for proID in pairs(projectileCache) do
			if not spGetProjectilePosition(proID) then
				projectileCache[proID] = false -- mark for removal
			else
				hasEntries = true
			end
		end
		for proID, v in pairs(projectileCache) do
			if v == false then
				projectileCache[proID] = nil
			end
		end
	end
end

function gadget:PlayerChanged(playerID)
	local _, specFullView = spGetSpectatingState()
	cachedSpecFullView = specFullView
	cachedAllyTeamID = specFullView and -1 or spGetMyAllyTeamID()
end

function gadget:Shutdown()
	cleanupGL4()
end

function gadget:DrawWorld()
	updateMissiles()
	drawAll()
end
