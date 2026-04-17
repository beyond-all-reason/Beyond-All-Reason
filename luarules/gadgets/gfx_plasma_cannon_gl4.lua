--------------------------------------------------------------------------------
-- Plasma Cannon GL4
-- GPU-instanced replacement for engine Cannon projectile rendering.
-- Renders velocity-aligned elongated quads with noise-displaced blobby
-- energy shapes that mimic the old staged trailing ball look.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then return end

function gadget:GetInfo()
	return {
		name = "Plasma Cannon GL4",
		desc = "GL4 instanced plasma cannon replacement effects",
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
local spEcho                      = Spring.Echo
local spGetVisibleProjectiles     = Spring.GetVisibleProjectiles
local spGetProjectilePosition     = Spring.GetProjectilePosition
local spGetProjectileVelocity     = Spring.GetProjectileVelocity
local spGetProjectileDefID        = Spring.GetProjectileDefID
local spGetProjectileTeamID       = Spring.GetProjectileTeamID
local spGetTeamAllyTeamID         = Spring.GetTeamAllyTeamID
local spIsPosInAirLos             = Spring.IsPosInAirLos
local spGetMyAllyTeamID           = Spring.GetMyAllyTeamID
local spGetSpectatingState        = Spring.GetSpectatingState
local spGetGameFrame              = Spring.GetGameFrame
local spGetFrameTimeOffset        = Spring.GetFrameTimeOffset

local glBlending  = gl.Blending
local glTexture   = gl.Texture
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling   = gl.Culling

local GL_ONE                  = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA  = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA            = GL.SRC_ALPHA

local mathMin    = math.min
local mathSqrt   = math.sqrt

local LuaShader = gl.LuaShader
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

-- Limits
local INITIAL_VBO_SIZE = 128   -- starting VBO capacity (doubles automatically when exceeded)
local IDLE_SKIP_FRAMES = 3    -- draw-frames to skip polling when no projectiles active

-- Textures
local plasmaTexture = "bitmaps/projectiletextures/plasmaball.tga"
local glowTexture   = "bitmaps/projectiletextures/glow2.tga"

-- Glow billboard config
local GLOW_SIZE_MULT   = 11   -- glow billboard size as multiple of projectile cross-section size
local GLOW_BRIGHTNESS  = 0.125   -- glow color multiplier (faint)
local GLOW_REF_SIZE    = 5.0   -- weapons at this size (after SIZE_MULT) get full glow; smaller ones dim proportionally

-- Cross-section billboard (camera-facing round blob, visible when looking along velocity)
local CROSS_SECTION_BRIGHTNESS = 0.7  -- brightness multiplier for the head-on cross-section

-- Projectile sizing: the quad is elongated along velocity to create the trail shape
local SIZE_MULT          = 1.5    -- global multiplier on weapon projectile size (cross-section width)
local RANGE_SIZE_BONUS   = 2.0    -- max extra size added for long-range weapons (at RANGE_SIZE_REF range)
local RANGE_SIZE_REF     = 1500   -- weapon range (elmos) at which full RANGE_SIZE_BONUS is applied

-- Core color boost
local CORE_COLOR_ADD     = 0.4  -- added to weapon RGB to create brighter core color

-- Shader config (injected as #defines)
local shaderConfig = {
	-- Shape (elongation scales with speed: min at rest, max at ELONGATION_SPEED_REF elmos/frame)
	ELONGATION_MIN     = 2.2,  -- elongation at zero speed (nearly round)
	ELONGATION_MAX     = 7.0,  -- elongation at or above reference speed
	ELONGATION_SPEED_REF = 25, -- speed (elmos/frame) at which max elongation is reached

	-- Noise displacement for blobby organic shape
	NOISE_SCALE        = 4.5,    -- frequency of noise pattern (lower = bigger blobs)
	NOISE_STRENGTH     = 1.1,   -- how much noise distorts the shape (higher = more blobby)
	NOISE_SPEED        = 50.0,    -- animation speed of noise
	SWIRL_SPEED        = 365.0,    -- rotation speed of swirl effect
	SWIRL_STRENGTH     = 5,    -- intensity of swirl distortion (higher = more visible rotation)

	-- Core/edge color blending (radially from center)
	CORE_EDGE_START    = 0.1,   -- radial distance where core-to-edge blend starts
	CORE_EDGE_END      = 0.25,    -- radial distance where blend is fully edge color
	CORE_BRIGHTNESS    = 1.0,    -- extra brightness for core center
	BRIGHTNESS_MULT    = 0.75,    -- overall brightness multiplier (compensates for 2 additive cross passes)
	EDGE_SOFTNESS      = 0.22,    -- how soft the outer edge is

	-- Trail shape: the blob is shifted forward and fades toward the back
	TRAIL_SHIFT        = 0,    -- how much the bright center shifts toward the front (0 = centered)
	TRAIL_FALLOFF      = 2,    -- how quickly brightness drops off toward the back (higher = sharper tail)
}

--------------------------------------------------------------------------------
-- Build weaponDefID -> plasma config lookup
--------------------------------------------------------------------------------
local weaponConfigs = {}

for weaponID, weaponDef in pairs(WeaponDefs) do
	local vis = weaponDef.visuals or {}
	if weaponDef.type == "Cannon" and not weaponDef.model and (not vis.modelName or vis.modelName == "") then
		local r = vis.colorR or 1
		local g = vis.colorG or 1
		local b = vis.colorB or 1

		local coreR = mathMin(1, r + CORE_COLOR_ADD)
		local coreG = mathMin(1, g + CORE_COLOR_ADD)
		local coreB = mathMin(1, b + CORE_COLOR_ADD)

		local cp = weaponDef.customParams or {}
		local size = tonumber(cp.plasma_size_orig) or weaponDef.size or 1.5
		local range = weaponDef.range or 300

		size = (size * 0.55) + (weaponDef.damageAreaOfEffect / 66)  -- add blast radius to size for better core/edge color distribution
		size = size + RANGE_SIZE_BONUS * mathMin(1, range / RANGE_SIZE_REF)  -- longer-range weapons get bigger projectiles

		weaponConfigs[weaponID] = {
			colorR = r,    colorG = g,    colorB = b,
			coreR = coreR, coreG = coreG, coreB = coreB,
			size = size * SIZE_MULT,
		}
	end
end

-- Check if we have any cannon weapons
local hasConfigs = false
for _ in pairs(weaponConfigs) do hasConfigs = true; break end
if not hasConfigs then
	function gadget:Initialize()
		gadgetHandler:RemoveGadget()
	end
	return
end

--------------------------------------------------------------------------------
-- Projectile tracking (stable noise seed per projectile)
--------------------------------------------------------------------------------
local projectileSeeds = {}  -- proID -> random seed

--------------------------------------------------------------------------------
-- Shader sources: Plasma (velocity-aligned elongated billboard)
-- The quad is stretched along the projectile's velocity direction to create
-- a comet/trail shape. The fragment shader adds noise, swirl, and a core/edge
-- color gradient to make it look like an energy blob.
--------------------------------------------------------------------------------
local plasmaVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

// Quad vertex: xy = corner position (-1..1), zw = UV
layout (location = 0) in vec4 position_xy_uv;

// Per-instance data
layout (location = 1) in vec4 posAndSize;       // xyz = world position, w = cross-section size
layout (location = 2) in vec4 coreColor;        // rgb = core color, a = alpha
layout (location = 3) in vec4 edgeColorAndSeed; // rgb = edge color, a = noise seed
layout (location = 4) in vec4 velocityAndLife;  // xyz = velocity dir (normalized), w = speed (elmap units/frame)

out DataVS {
	vec2 texCoords;
	vec4 vCoreColor;
	vec4 vEdgeColor;
	float noiseSeed;
};

void main()
{
	vec3 worldPos = posAndSize.xyz;
	float size = posAndSize.w;

	if (size <= 0.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	vec3 velDir = velocityAndLife.xyz;
	float speed = velocityAndLife.w;

	// Fixed world-derived perpendicular axis (does not rotate with camera).
	// The cross pass uses the other perpendicular — together they form a
	// stable cross shape visible from all angles.
	vec3 axis1 = cross(velDir, vec3(0.0, 1.0, 0.0));
	float axis1Len = length(axis1);
	if (axis1Len < 0.001) {
		axis1 = normalize(cross(velDir, vec3(1.0, 0.0, 0.0)));
	} else {
		axis1 = axis1 / axis1Len;
	}

	// Vertex x: across width (-1..1), vertex y: along velocity (-1..1)
	// Elongate along velocity direction, scaled by speed
	float speedFrac = clamp(speed / float(ELONGATION_SPEED_REF), 0.0, 1.0);
	float elongation = mix(float(ELONGATION_MIN), float(ELONGATION_MAX), speedFrac);
	float halfWidth  = size;
	float halfLength = size * elongation;

	// No center shift here — the FS handles TRAIL_SHIFT in UV space.
	// The quad must be large enough to contain the shifted shape at any TRAIL_SHIFT.
	// We expand the quad along velocity to guarantee no clipping.
	float paddedHalfLength = halfLength * (1.0 + abs(TRAIL_SHIFT));

	vec3 vertexWorld = worldPos
		+ axis1  * position_xy_uv.x * halfWidth
		+ velDir * position_xy_uv.y * paddedHalfLength;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	// UV: 0..1
	texCoords = position_xy_uv.zw;
	vCoreColor = coreColor;
	vEdgeColor = edgeColorAndSeed;
	noiseSeed = edgeColorAndSeed.a;
}
]]

local plasmaFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D plasmaTex;

in DataVS {
	vec2 texCoords;
	vec4 vCoreColor;
	vec4 vEdgeColor;
	float noiseSeed;
};

out vec4 fragColor;

// Hash-based gradient noise (no texture lookup needed)
vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			  dot(p, vec3(269.5, 183.3, 246.1)),
			  dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123) * 2.0 - 1.0;
}

float noise3D(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	return mix(mix(mix(dot(hash33(i + vec3(0,0,0)), f - vec3(0,0,0)),
					   dot(hash33(i + vec3(1,0,0)), f - vec3(1,0,0)), u.x),
				   mix(dot(hash33(i + vec3(0,1,0)), f - vec3(0,1,0)),
					   dot(hash33(i + vec3(1,1,0)), f - vec3(1,1,0)), u.x), u.y),
			   mix(mix(dot(hash33(i + vec3(0,0,1)), f - vec3(0,0,1)),
					   dot(hash33(i + vec3(1,0,1)), f - vec3(1,0,1)), u.x),
				   mix(dot(hash33(i + vec3(0,1,1)), f - vec3(0,1,1)),
					   dot(hash33(i + vec3(1,1,1)), f - vec3(1,1,1)), u.x), u.y), u.z);
}

// Fractal Brownian Motion - 2 octaves for performance
float fbm(vec3 p) {
	return 0.5 * noise3D(p) + 0.225 * noise3D(p * 2.2);
}

void main(void)
{
	// Centered UV: -1..1 (x = across width, y = along velocity)
	vec2 centered = texCoords * 2.0 - 1.0;
	// Scale Y to match the padded quad (VS expands by 1+TRAIL_SHIFT)
	centered.y *= (1.0 + abs(TRAIL_SHIFT));
	float dx = centered.x;
	float dy = centered.y;

	// Trail shape: front is a tight ball, back stretches into a tail
	float yShifted = dy + TRAIL_SHIFT;
	float backStretch = 1.0 + max(0.0, yShifted) * TRAIL_FALLOFF;
	float frontTighten = 1.0 + max(0.0, -yShifted) * 0.3;
	float dist = length(vec2(dx * frontTighten, yShifted * backStretch));

	if (dist > 1.6) discard;

	float time = timeInfo.z;
	float seed = noiseSeed;

	// Swirl: rotate UV around center over time for spinning energy look
	float swirlAngle = time * SWIRL_SPEED + seed * 6.28;
	float cosA = cos(swirlAngle);
	float sinA = sin(swirlAngle);
	vec2 swirled = vec2(
		centered.x * cosA - centered.y * sinA,
		centered.x * sinA + centered.y * cosA
	) * SWIRL_STRENGTH + centered * (1.0 - SWIRL_STRENGTH);

	// Domain warping: use one noise to offset the input of another for organic energy look
	vec3 noisePos1 = vec3(swirled * NOISE_SCALE, time * NOISE_SPEED + seed * 100.0);
	float warpX = noise3D(noisePos1 + vec3(5.2, 1.3, 0.0));
	float warpY = noise3D(noisePos1 + vec3(1.7, 9.2, 0.0));
	vec3 noisePos = noisePos1 + vec3(warpX, warpY, 0.0) * 0.5;
	float displacement = fbm(noisePos);

	// Displace the radial distance - creates blobby, shifting edges
	float noisedDist = dist + displacement * NOISE_STRENGTH;

	// Additional high-freq noise layer for energy tendrils inside the blob
	float tendrilNoise = noise3D(noisePos * 3.5 + vec3(0.0, 0.0, time * NOISE_SPEED * 1.3));
	float tendrils = smoothstep(0.1, 0.5, abs(tendrilNoise)) * 0.4;

	// Outer edge mask - noise makes it blobby
	float outerEdge = 1.0 - smoothstep(0.5 - EDGE_SOFTNESS, 0.5 + EDGE_SOFTNESS, noisedDist);
	if (outerEdge < 0.001) discard;

	// Trail fade: back of the blob fades out
	float trailFade = 1.0 - smoothstep(0.0, 1.0, max(0.0, yShifted) * TRAIL_FALLOFF * 0.7);
	outerEdge *= trailFade;

	// Core factor: bright center with noise-modulated boundary
	float coreFactor = 1.0 - smoothstep(CORE_EDGE_START, CORE_EDGE_END, noisedDist);

	// Tendrils brighten the inside and create visible energy structure
	coreFactor = clamp(coreFactor + tendrils * (1.0 - dist * 0.8), 0.0, 1.0);

	// Blend core and edge colors
	vec3 plasmaCol = mix(vEdgeColor.rgb, vCoreColor.rgb, coreFactor);

	// Alpha from outer edge mask
	float alpha = vCoreColor.a * outerEdge;

	vec3 color = plasmaCol * alpha * BRIGHTNESS_MULT;

	// Core brightness boost - hot center
	color *= (1.0 + coreFactor * coreFactor * CORE_BRIGHTNESS);

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.001) discard;

	// Additive blending output
	fragColor = vec4(color, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Cross billboard (90-degree rotated plasma quad)
-- Uses 'up' vector instead of 'right' so the two quads form a cross shape
-- that provides visual volume from all camera angles.
-- Reuses the same fragment shader as the main plasma pass.
--------------------------------------------------------------------------------
local crossVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 50000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec4 posAndSize;
layout (location = 2) in vec4 coreColor;
layout (location = 3) in vec4 edgeColorAndSeed;
layout (location = 4) in vec4 velocityAndLife;

out DataVS {
	vec2 texCoords;
	vec4 vCoreColor;
	vec4 vEdgeColor;
	float noiseSeed;
};

void main()
{
	vec3 worldPos = posAndSize.xyz;
	float size = posAndSize.w;

	if (size <= 0.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	vec3 velDir = velocityAndLife.xyz;

	// Second perpendicular axis: cross(axis1, velDir) where axis1 = cross(velDir, worldUp).
	// Together with the main pass (which uses axis1) this forms a stable cross.
	vec3 axis1 = cross(velDir, vec3(0.0, 1.0, 0.0));
	float axis1Len = length(axis1);
	if (axis1Len < 0.001) {
		axis1 = normalize(cross(velDir, vec3(1.0, 0.0, 0.0)));
	} else {
		axis1 = axis1 / axis1Len;
	}
	vec3 axis2 = cross(axis1, velDir);

	float speed = velocityAndLife.w;
	float speedFrac = clamp(speed / float(ELONGATION_SPEED_REF), 0.0, 1.0);
	float elongation = mix(float(ELONGATION_MIN), float(ELONGATION_MAX), speedFrac);
	float halfWidth  = size;
	float halfLength = size * elongation;
	float paddedHalfLength = halfLength * (1.0 + abs(TRAIL_SHIFT));

	vec3 vertexWorld = worldPos
		+ axis2  * position_xy_uv.x * halfWidth
		+ velDir * position_xy_uv.y * paddedHalfLength;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	texCoords = position_xy_uv.zw;
	vCoreColor = coreColor;
	vEdgeColor = edgeColorAndSeed;
	noiseSeed = edgeColorAndSeed.a;
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Cross-section (camera-facing circular billboard)
-- Visible when looking along the velocity direction (head-on).
-- Fades out when viewed from the side so it doesn't double-up with the
-- main elongated quads.
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
layout (location = 2) in vec4 coreColor;
layout (location = 3) in vec4 edgeColorAndSeed;
layout (location = 4) in vec4 velocityAndLife;

out DataVS {
	vec2 texCoords;
	vec4 vCoreColor;
	vec4 vEdgeColor;
	float noiseSeed;
	float headOnFactor;
};

void main()
{
	vec3 worldPos = posAndSize.xyz;
	float size = posAndSize.w;

	if (size <= 0.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	vec3 velDir = velocityAndLife.xyz;

	// How head-on is the camera view? (1 = looking along velocity, 0 = side view)
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCamera = normalize(camPos - worldPos);
	float headOn = abs(dot(velDir, toCamera));

	// Only visible when looking along velocity; fade out from side view
	if (headOn < 0.3) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	// Camera-facing billboard, circular (same size in both axes)
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	vec3 vertexWorld = worldPos
		+ camRight * position_xy_uv.x * size
		+ camUp    * position_xy_uv.y * size;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	texCoords = position_xy_uv.zw;
	vCoreColor = coreColor;
	vEdgeColor = edgeColorAndSeed;
	noiseSeed = edgeColorAndSeed.a;
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

in DataVS {
	vec2 texCoords;
	vec4 vCoreColor;
	vec4 vEdgeColor;
	float noiseSeed;
	float headOnFactor;
};

out vec4 fragColor;

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)),
			  dot(p, vec3(269.5, 183.3, 246.1)),
			  dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123) * 2.0 - 1.0;
}

float noise3D(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);

	return mix(mix(mix(dot(hash33(i + vec3(0,0,0)), f - vec3(0,0,0)),
					   dot(hash33(i + vec3(1,0,0)), f - vec3(1,0,0)), u.x),
				   mix(dot(hash33(i + vec3(0,1,0)), f - vec3(0,1,0)),
					   dot(hash33(i + vec3(1,1,0)), f - vec3(1,1,0)), u.x), u.y),
			   mix(mix(dot(hash33(i + vec3(0,0,1)), f - vec3(0,0,1)),
					   dot(hash33(i + vec3(1,0,1)), f - vec3(1,0,1)), u.x),
				   mix(dot(hash33(i + vec3(0,1,1)), f - vec3(0,1,1)),
					   dot(hash33(i + vec3(1,1,1)), f - vec3(1,1,1)), u.x), u.y), u.z);
}

void main(void)
{
	vec2 centered = texCoords * 2.0 - 1.0;
	float dist = length(centered);

	if (dist > 1.0) discard;

	float time = timeInfo.z;
	float seed = noiseSeed;

	// Swirling noise for blobby circular shape
	float swirlAngle = time * SWIRL_SPEED + seed * 6.28;
	float cosA = cos(swirlAngle);
	float sinA = sin(swirlAngle);
	vec2 swirled = vec2(
		centered.x * cosA - centered.y * sinA,
		centered.x * sinA + centered.y * cosA
	);

	vec3 noisePos = vec3(swirled * NOISE_SCALE, time * NOISE_SPEED + seed * 100.0);
	float displacement = noise3D(noisePos);
	float noisedDist = dist + displacement * NOISE_STRENGTH * 0.5;

	// Soft circular edge
	float outerEdge = 1.0 - smoothstep(0.4, 0.7, noisedDist);
	if (outerEdge < 0.001) discard;

	// Core factor
	float coreFactor = 1.0 - smoothstep(CORE_EDGE_START, CORE_EDGE_END, noisedDist);

	vec3 plasmaCol = mix(vEdgeColor.rgb, vCoreColor.rgb, coreFactor);

	float alpha = vCoreColor.a * outerEdge * headOnFactor * CROSS_SECTION_BRIGHTNESS;
	vec3 color = plasmaCol * alpha;
	color *= (1.0 + coreFactor * coreFactor * CORE_BRIGHTNESS);

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.001) discard;

	fragColor = vec4(color, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Glow (camera-facing billboard)
-- Reads the same VBO as the plasma shader. Uses posAndSize for position,
-- edgeColorAndSeed.rgb for tint color. Creates a camera-facing billboard.
--------------------------------------------------------------------------------
local glowVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 30000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;

// Per-instance (shared layout with plasma VBO)
layout (location = 1) in vec4 posAndSize;       // xyz = world pos, w = cross-section size
layout (location = 3) in vec4 edgeColorAndSeed; // rgb = edge color
layout (location = 4) in vec4 velocityAndLife;  // xyz = velocity dir (normalized)

out DataVS {
	vec2 texCoords;
	vec3 glowColor;
};

void main()
{
	vec3 worldPos = posAndSize.xyz;
	float size = posAndSize.w;

	if (size <= 0.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	// Offset glow center to match the visual bright center of the plasma shape,
	// which is shifted backward along velocity by TRAIL_SHIFT in UV space.
	vec3 velDir = velocityAndLife.xyz;
	float speed = velocityAndLife.w;
	float speedFrac = clamp(speed / float(ELONGATION_SPEED_REF), 0.0, 1.0);
	float elongation = mix(float(ELONGATION_MIN), float(ELONGATION_MAX), speedFrac);
	vec3 glowCenter = worldPos - velDir * (size * elongation * float(TRAIL_SHIFT));

	float glowSize = size * GLOW_SIZE_MULT;

	// Camera-facing billboard
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	vec3 vertexWorld = glowCenter
		+ camRight * position_xy_uv.x * glowSize
		+ camUp    * position_xy_uv.y * glowSize;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);
	texCoords = position_xy_uv.zw;
	float glowBright = GLOW_BRIGHTNESS * clamp(size / GLOW_REF_SIZE, 0.0, 1.0);
	glowColor = edgeColorAndSeed.rgb * glowBright;
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
	vec3 glowColor;
};

out vec4 fragColor;

void main(void)
{
	vec4 texSample = texture(glowTex, texCoords);
	vec3 col = glowColor * texSample.rgb;
	float a = texSample.a;

	if (a < 0.002) discard;

	fragColor = vec4(col * a, 0.0);
}
]]

--------------------------------------------------------------------------------
-- GL4 state
--------------------------------------------------------------------------------
local plasmaVBO
local plasmaShader
local crossShader        -- 90-degree rotated copy for volume from all angles
local crossSectionShader -- camera-facing circular billboard for head-on view
local glowShader

local idleSkipCounter = 0

local cachedAllyTeamID = spGetMyAllyTeamID()
local cachedSpecFullView = false

local function goodbye(reason)
	gadgetHandler:RemoveGadget()
end

local function initGL4()
	local plasmaShaderCache = {
		vsSrc = plasmaVsSrc,
		fsSrc = plasmaFsSrc,
		shaderName = "PlasmaCannonGL4",
		uniformInt = { plasmaTex = 0 },
		uniformFloat = {},
		shaderConfig = shaderConfig,
		forceupdate = true,
	}
	plasmaShader = LuaShader.CheckShaderUpdates(plasmaShaderCache)
	if not plasmaShader then
		goodbye("Failed to compile plasma shader")
		return false
	end

	-- Cross shader (90-degree rotated plasma quad, same FS)
	local crossShaderCache = {
		vsSrc = crossVsSrc,
		fsSrc = plasmaFsSrc,
		shaderName = "PlasmaCannonCrossGL4",
		uniformInt = { plasmaTex = 0 },
		uniformFloat = {},
		shaderConfig = shaderConfig,
		forceupdate = true,
	}
	crossShader = LuaShader.CheckShaderUpdates(crossShaderCache)
	if not crossShader then
		goodbye("Failed to compile cross shader")
		return false
	end

	-- Cross-section shader (camera-facing circular blob for head-on view)
	local crossSectionShaderCache = {
		vsSrc = crossSectionVsSrc,
		fsSrc = crossSectionFsSrc,
		shaderName = "PlasmaCannonCrossSectionGL4",
		uniformInt = {},
		uniformFloat = {},
		shaderConfig = {
			NOISE_SCALE = shaderConfig.NOISE_SCALE,
			NOISE_STRENGTH = shaderConfig.NOISE_STRENGTH,
			NOISE_SPEED = shaderConfig.NOISE_SPEED,
			SWIRL_SPEED = shaderConfig.SWIRL_SPEED,
			CORE_EDGE_START = shaderConfig.CORE_EDGE_START,
			CORE_EDGE_END = shaderConfig.CORE_EDGE_END,
			CORE_BRIGHTNESS = shaderConfig.CORE_BRIGHTNESS,
			CROSS_SECTION_BRIGHTNESS = CROSS_SECTION_BRIGHTNESS,
		},
		forceupdate = true,
	}
	crossSectionShader = LuaShader.CheckShaderUpdates(crossSectionShaderCache)
	if not crossSectionShader then
		goodbye("Failed to compile cross-section shader")
		return false
	end

	-- Glow shader (camera-facing billboard, reads same VBO)
	local glowShaderCache = {
		vsSrc = glowVsSrc,
		fsSrc = glowFsSrc,
		shaderName = "PlasmaCannonGlowGL4",
		uniformInt = { glowTex = 0 },
		uniformFloat = {},
		shaderConfig = {
			GLOW_SIZE_MULT = GLOW_SIZE_MULT,
			GLOW_BRIGHTNESS = GLOW_BRIGHTNESS,
			GLOW_REF_SIZE = GLOW_REF_SIZE,
			ELONGATION_MIN = shaderConfig.ELONGATION_MIN,
			ELONGATION_MAX = shaderConfig.ELONGATION_MAX,
			ELONGATION_SPEED_REF = shaderConfig.ELONGATION_SPEED_REF,
			TRAIL_SHIFT = shaderConfig.TRAIL_SHIFT,
		},
		forceupdate = true,
	}
	glowShader = LuaShader.CheckShaderUpdates(glowShaderCache)
	if not glowShader then
		goodbye("Failed to compile glow shader")
		return false
	end

	-- Shared quad VBOs
	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(
		-1, -1, 1, 1,
		0, 0, 1, 1,
		"plasmaQuadVBO"
	)
	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("plasmaIndexVBO")

	-- Instance VBO layout: 4 vec4s = stride 16
	local plasmaLayout = {
		{id = 1, name = 'posAndSize',       size = 4},  -- xyz = pos, w = size
		{id = 2, name = 'coreColor',        size = 4},  -- rgb = core, a = alpha
		{id = 3, name = 'edgeColorAndSeed', size = 4},  -- rgb = edge, a = noise seed
		{id = 4, name = 'velocityAndLife',  size = 4},  -- xyz = velDir (normalized), w = speed
	}
	plasmaVBO = gl.InstanceVBOTable.makeInstanceVBOTable(plasmaLayout, INITIAL_VBO_SIZE, "plasmaCannonVBO")
	if not plasmaVBO then
		goodbye("Failed to create plasma VBO")
		return false
	end
	plasmaVBO.numVertices = numVertices
	plasmaVBO.vertexVBO = quadVBO
	plasmaVBO.VAO = plasmaVBO:makeVAOandAttach(quadVBO, plasmaVBO.instanceVBO)
	plasmaVBO.primitiveType = GL.TRIANGLES
	plasmaVBO.VAO:AttachIndexBuffer(indexVBO)
	plasmaVBO.indexVBO = indexVBO

	return true
end

local function resizePlasmaVBO(needed)
	local newMax = plasmaVBO.maxElements
	while newMax < needed do newMax = newMax * 2 end
	plasmaVBO.maxElements = newMax
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	newInstanceVBO:Define(newMax, plasmaVBO.layout)
	plasmaVBO.instanceVBO:Delete()
	plasmaVBO.instanceVBO = newInstanceVBO
	local data = plasmaVBO.instanceData
	local step = plasmaVBO.instanceStep
	for i = #data + 1, step * newMax do data[i] = 0 end
	plasmaVBO.VAO:Delete()
	plasmaVBO.VAO = plasmaVBO:makeVAOandAttach(plasmaVBO.vertexVBO, plasmaVBO.instanceVBO)
	plasmaVBO.VAO:AttachIndexBuffer(plasmaVBO.indexVBO)
end

local function cleanupGL4()
	if plasmaVBO then plasmaVBO:Delete(); plasmaVBO = nil end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local function drawAll()
	if plasmaVBO.usedElements == 0 then return end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE)

	-- Plasma pass
	glTexture(0, plasmaTexture)
	plasmaShader:Activate()
	plasmaVBO:Draw()
	plasmaShader:Deactivate()

	-- Cross pass (90-degree rotated plasma quad for volume from all angles)
	crossShader:Activate()
	plasmaVBO:Draw()
	crossShader:Deactivate()

	glTexture(0, false)

	-- Cross-section pass (camera-facing circular blob for head-on view)
	crossSectionShader:Activate()
	plasmaVBO:Draw()
	crossSectionShader:Deactivate()

	-- Glow pass (same VBO, glow shader reads posAndSize + edgeColor)
	glTexture(0, glowTexture)
	glowShader:Activate()
	plasmaVBO:Draw()
	glowShader:Deactivate()
	glTexture(0, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Per-frame scan + VBO upload
--------------------------------------------------------------------------------
local mathRandom = math.random
local lastCleanupFrame = 0

local function updateProjectiles()
	if idleSkipCounter > 0 then
		idleSkipCounter = idleSkipCounter - 1
		return
	end

	plasmaVBO.usedElements = 0

	-- addSynced=false: we only need weapon (cannon) projectiles, not synced features
	local projectiles = spGetVisibleProjectiles(-1, false, true, false)
	if not projectiles or #projectiles == 0 then
		idleSkipCounter = IDLE_SKIP_FRAMES
		projectileSeeds = {}
		return
	end

	local ftoAdj = spGetFrameTimeOffset() - 1.0
	local data = plasmaVBO.instanceData
	local count = 0
	local myAllyTeam = cachedAllyTeamID
	local needLosCheck = not cachedSpecFullView
	local seeds = projectileSeeds
	local configs = weaponConfigs
	local nProj = #projectiles

	for i = 1, nProj do
		local proID = projectiles[i]
		-- GetVisibleProjectiles with addPiece=false already filters piece projectiles,
		-- so spGetProjectileType check is unnecessary. Just check config directly.
		local cfg = configs[spGetProjectileDefID(proID)]
		if cfg then
			local px, py, pz = spGetProjectilePosition(proID)
			if px then
				-- LOS check: own allyteam always visible
				if needLosCheck then
					local proTeam = spGetProjectileTeamID(proID)
					local proAlly = proTeam and spGetTeamAllyTeamID(proTeam)
					if proAlly ~= myAllyTeam and not spIsPosInAirLos(px, 0, pz, myAllyTeam) then
						cfg = nil  -- reuse variable to skip without deep nesting
					end
				end
				if cfg then
					local vx, vy, vz = spGetProjectileVelocity(proID)
					if vx then
						local speed = mathSqrt(vx*vx + vy*vy + vz*vz)
						local dirX, dirY, dirZ
						if speed > 0.001 then
							local invSpeed = 1.0 / speed
							dirX = vx * invSpeed
							dirY = vy * invSpeed
							dirZ = vz * invSpeed
							px = px + vx * ftoAdj
							py = py + vy * ftoAdj
							pz = pz + vz * ftoAdj
						else
							dirX, dirY, dirZ = 0, 1, 0
						end

						local seed = seeds[proID]
						if not seed then
							seed = mathRandom()
							seeds[proID] = seed
						end

						count = count + 1
						local offset = (count - 1) * 16
						data[offset + 1]  = px
						data[offset + 2]  = py
						data[offset + 3]  = pz
						data[offset + 4]  = cfg.size
						data[offset + 5]  = cfg.coreR
						data[offset + 6]  = cfg.coreG
						data[offset + 7]  = cfg.coreB
						data[offset + 8]  = 1.0
						data[offset + 9]  = cfg.colorR
						data[offset + 10] = cfg.colorG
						data[offset + 11] = cfg.colorB
						data[offset + 12] = seed
						data[offset + 13] = dirX
						data[offset + 14] = dirY
						data[offset + 15] = dirZ
						data[offset + 16] = speed
					end
				end
			end
		end
	end

	plasmaVBO.usedElements = count
	if count > 0 then
		idleSkipCounter = 0
		if count > plasmaVBO.maxElements then
			resizePlasmaVBO(count)
		end
		uploadAllElements(plasmaVBO)
	else
		idleSkipCounter = IDLE_SKIP_FRAMES
		projectileSeeds = {}
	end

	-- Periodic cleanup of stale seed entries (every ~2 seconds of game time)
	local gameFrame = spGetGameFrame()
	if gameFrame - lastCleanupFrame >= 60 then
		lastCleanupFrame = gameFrame
		for proID in pairs(seeds) do
			if not configs[spGetProjectileDefID(proID)] then
				seeds[proID] = nil
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	if not initGL4() then return end
	local n = 0
	for _ in pairs(weaponConfigs) do n = n + 1 end
	spEcho("Plasma Cannon GL4: initialized with " .. n .. " cannon weapon configs")
end

function gadget:Shutdown()
	cleanupGL4()
end

function gadget:PlayerChanged()
	cachedAllyTeamID = spGetMyAllyTeamID()
	local _, fullView = spGetSpectatingState()
	cachedSpecFullView = fullView
end

function gadget:DrawWorld()
	updateProjectiles()
	drawAll()
end
