--------------------------------------------------------------------------------
-- Beam Laser GL4
-- GPU-instanced replacement for engine BeamLaser rendering.
-- Renders direction-aligned textured quads with animated fade in/out,
-- edge glow, and range-based intensity falloff.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
	return {
		name = "Beam Laser GL4",
		desc = "GL4 instanced beam laser replacement effects",
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
local spEcho = SpringShared.Echo
local spGetProjectilePosition = SpringShared.GetProjectilePosition
local spGetProjectileVelocity = SpringShared.GetProjectileVelocity
local spGetProjectileDefID = SpringShared.GetProjectileDefID
local spGetProjectileTeamID = SpringShared.GetProjectileTeamID
local spGetTeamAllyTeamID = SpringShared.GetTeamAllyTeamID
local spIsPosInLos = SpringShared.IsPosInLos
local spIsPosInAirLos = SpringShared.IsPosInAirLos
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetSpectatingState = SpringUnsynced.GetSpectatingState
local spGetGameFrame = SpringShared.GetGameFrame
local spGetFrameTimeOffset = SpringUnsynced.GetFrameTimeOffset
local spGetProjectileOwnerID = SpringShared.GetProjectileOwnerID
local spGetProjectilesInRectangle = SpringShared.GetProjectilesInRectangle
local spIsAABBInView = SpringUnsynced.IsAABBInView

local glBlending = gl.Blending
local glTexture = gl.Texture
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling = gl.Culling

local GL_ONE = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA = GL.SRC_ALPHA

local mathMin = math.min
local mathMax = math.max
local mathSqrt = math.sqrt

local LuaShader = gl.LuaShader
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

--------------------------------------------------------------------------------
-- Configuration
-- All tunables in one place. Shader #defines are injected via shaderConfig.
--------------------------------------------------------------------------------

-- Limits
local INITIAL_VBO_SIZE = 64 -- starting VBO capacity (doubles automatically when exceeded)
local IDLE_SKIP_FRAMES = 3 -- draw-frames to skip polling when no beams active

-- Per-weapon ghost frames: scaled by beam thickness so small lasers fade fast
local GHOST_FRAMES_MIN = 3 -- ghost frames for thinnest beams
local GHOST_FRAMES_MAX = 8 -- ghost frames for thickest beams
local GHOST_THICKNESS_MIN = 1.5 -- thickness at or below which gets min ghost frames
local GHOST_THICKNESS_MAX = 5.0 -- thickness at or above which gets max ghost frames
local FLARE_GHOST_FRAC = 0.4 -- fraction of weapon ghostFrames where flare stays visible (0..1)

-- Textures
local beamTexture = "bitmaps/projectiletextures/largebeam.tga"
local flareTexture = "bitmaps/projectiletextures/flare2.tga"

-- LOS clipping
local CLIP_BEAM_TO_LOS = true -- when true, only the portion of enemy beams inside LOS is rendered
local USE_AIR_LOS = true -- use air los instead of regular los
local LOS_CLIP_STEPS = 6 -- binary search iterations to find the LOS boundary (6 ≈ 1.5% precision)
local LOS_BONUS_RANGE = 100 -- when not USE_AIR_LOS then extra elmos of beam shown beyond strict LOS boundary (so beams always render a bit more)

-- Resolve LOS check function once (avoids per-call branch in hot loop)
local spLosCheck = USE_AIR_LOS and spIsPosInAirLos or spIsPosInLos

-- Retarget transition removed: an earlier version smoothly swept the beam
-- endpoint over a few frames when the engine moved a beam to a new target.
-- That looked good for sustained beams tracking a moving unit, but on real
-- multi-weapon turrets with fastautoretargeting (corhllt etc.) it produced
-- a visible beam sweep across the screen between two unrelated targets on
-- every target switch, which was more disruptive than the original snap.

-- Beam body
local BEAM_WIDTH_MULT = 0.3 -- multiplier on weapon thickness for beam quad width
local BEAM_SUSTAIN_LIFEFRAC = 0.33 -- lifeFrac value for live beams (must be between FADE_IN_END and FADE_OUT_START)
local BEAM_RANGE_FALLOFF_BASE = 0.1 -- minimum intensity falloff along beam length
local BEAM_RANGE_FALLOFF_MULT = 0.5 -- additional falloff scaled by beam-length / weapon-range

-- Core color boost (applied in weaponConfigs build)
local CORE_COLOR_ADD = 0.5 -- added to weapon RGB to create brighter core color (clamped to 1)

-- Flare billboard
local FLARE_SIZE_MULT = 0.7 -- multiplier on (laserflaresize * thickness)
local FLARE_COLOR_MULT = 1.0 -- multiplier on core color for flare RGB
local FLARE_LIFE_DIM = 0.7 -- how much flare dims over beam lifetime (0 = none, 1 = fully dark at end)

-- Beam glow halo
local GLOW_WIDTH_MULT = 8.0 -- glow quad width as multiple of beam width
local GLOW_BRIGHTNESS = 0.17 -- glow intensity (additive)
local GLOW_FALLOFF_POWER = 1.8 -- falloff curve exponent (<1 = fast initial drop + long tail, 1 = linear, >1 = slow start + sharp cutoff)
local GLOW_THICKNESS_DIM = 2.0 -- beams thinner than this get minimum glow
local GLOW_THICKNESS_FULL = 4.0 -- beams thicker than this get full glow
local GLOW_DIM_FACTOR = 0.2 -- glow brightness multiplier for thinnest beams (0..1)

-- Traveling pulse
local PULSE_WIDTH_MULT = 2.0 -- pulse quad width as multiple of beam width
local PULSE_BRIGHTNESS = 3.3 -- pulse intensity (additive, on top of beam)
local PULSE_SPEED = 950.0 -- pulse travel speed in world units (elmos) per second
local PULSE_SPACING = 200.0 -- distance between pulse centers in world units (elmos)
local PULSE_SIGMA = 35.0 -- gaussian half-width of each pulse in world units (elmos)
local PULSE_CORE_FRAC = 0.3 -- fraction of pulse width that is bright core (0..1)

-- Paralyzer beam pulse overrides (faster, brighter, tighter)
local PULSE_PARA_BRIGHTNESS = 8.0 -- pulse intensity for paralyzer beams
local PULSE_PARA_SPEED = 250.0 -- pulse travel speed for paralyzer beams (elmos/sec)
local PULSE_PARA_SPACING = 15.0 -- distance between pulses for paralyzer beams (elmos)
local PULSE_PARA_SIGMA = 1.1 -- gaussian half-width of each pulse for paralyzer beams (elmos)
local PULSE_PARA_WIDTH_MULT = 2.5 -- pulse quad width as multiple of beam width for paralyzer beams

-- Shader config (injected as #defines into beam vertex+fragment shaders)
local shaderConfig = {
	FADE_IN_END = 0.1, -- lifeFrac where width/alpha fade-in completes
	FADE_OUT_START = 0.85, -- lifeFrac where width/alpha fade-out begins
	RANGE_TAPER = 0.3, -- width reduction at beam end (0 = none, 1 = full taper to zero)
	SHIMMER_AMPLITUDE = 0.13, -- width oscillation strength (0 = off)
	SHIMMER_SPEED = 40.0, -- width oscillation speed (timeInfo.z multiplier)
	CORE_EDGE_START = 0.02, -- |x| distance where core-to-edge color blend starts (0 = only center pixel)
	CORE_EDGE_END = 0.44, -- |x| distance where blend is fully edge color
	CORE_BRIGHTNESS = 1.1, -- extra brightness multiplier for core (squared falloff)
	BRIGHTNESS_MULT = 1.5, -- overall beam brightness multiplier
	MIN_PIXEL_WIDTH = 0.0018, -- minimum beam width as fraction of camera distance (prevents sub-pixel aliasing at distance)
	TIP_FADE_START = 0.93, -- beam length fraction (0..1) where tip fade-out begins
}

--------------------------------------------------------------------------------
-- Build weaponDefID -> beam config lookup
-- Reads weapon colors, thickness, flare size, range, beamtime from WeaponDefs
--------------------------------------------------------------------------------
local weaponConfigs = {} -- weaponDefID -> config table
local LIVE_FLARE_PULSE_INIT = 1.0 - BEAM_SUSTAIN_LIFEFRAC * FLARE_LIFE_DIM -- pre-computed for weaponConfigs

for weaponID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.type == "BeamLaser" then
		local cp = weaponDef.customParams or {}
		if not cp.bogus then
			local vis = weaponDef.visuals or {}
			local r = vis.colorR or 1
			local g = vis.colorG or 1
			local b = vis.colorB or 1

			-- Core is brighter, edge is the weapon color
			local coreR = mathMin(1, r + CORE_COLOR_ADD)
			local coreG = mathMin(1, g + CORE_COLOR_ADD)
			local coreB = mathMin(1, b + CORE_COLOR_ADD)

			-- Read original visual properties from customparams (alldefs_post stores them before zeroing)
			local thickness = tonumber(cp.beam_thickness_orig) or weaponDef.thickness or 2
			local corethickness = tonumber(cp.beam_corethickness_orig) or weaponDef.corethickness or 0.3
			local laserflaresize = tonumber(cp.beam_laserflaresize_orig) or weaponDef.laserflaresize or 7
			local range = weaponDef.range or 300
			local beamttl = weaponDef.beamttl or 3
			local beamtime = weaponDef.beamtime or 0.1

			-- Paralyzer beams get a unique tint
			local isParalyzer = weaponDef.paralyzer or false

			-- Per-weapon ghost frames based on thickness
			local ghostFrac = mathMin(1, mathMax(0, (thickness - GHOST_THICKNESS_MIN) / (GHOST_THICKNESS_MAX - GHOST_THICKNESS_MIN)))
			local ghostFrames = math.floor(GHOST_FRAMES_MIN + ghostFrac * (GHOST_FRAMES_MAX - GHOST_FRAMES_MIN) + 0.5)
			local flareGhostFrames = mathMax(1, math.floor(ghostFrames * FLARE_GHOST_FRAC + 0.5))

			weaponConfigs[weaponID] = {
				colorR = r,
				colorG = g,
				colorB = b,
				coreR = coreR,
				coreG = coreG,
				coreB = coreB,
				thickness = thickness,
				corethickness = corethickness,
				flareSize = laserflaresize * thickness,
				range = range,
				beamttl = beamttl,
				beamtime = beamtime,
				isParalyzer = isParalyzer,
				-- Per-weapon ghost config
				ghostFrames = ghostFrames,
				flareGhostFrames = flareGhostFrames,
				invGhostFrames = 1.0 / ghostFrames,
				-- Pre-computed for hot loop
				beamWidth = thickness * BEAM_WIDTH_MULT,
				invRangeSq = 1.0 / mathMax(range * range, 1),
				aabbPad = thickness * BEAM_WIDTH_MULT * GLOW_WIDTH_MULT, -- padding for AABB view check (covers glow quad)
				flareColorR = coreR * FLARE_COLOR_MULT,
				flareColorG = coreG * FLARE_COLOR_MULT,
				flareColorB = coreB * FLARE_COLOR_MULT,
				liveFlareSize = laserflaresize * thickness * LIVE_FLARE_PULSE_INIT * FLARE_SIZE_MULT,
				liveFlareR = coreR * FLARE_COLOR_MULT * LIVE_FLARE_PULSE_INIT,
				liveFlareG = coreG * FLARE_COLOR_MULT * LIVE_FLARE_PULSE_INIT,
				liveFlareB = coreB * FLARE_COLOR_MULT * LIVE_FLARE_PULSE_INIT,
			}
		end
	end
end

-- Check if we have any beam weapons
local hasConfigs = false
for _ in pairs(weaponConfigs) do
	hasConfigs = true
	break
end
if not hasConfigs then
	function gadget:Initialize()
		gadgetHandler:RemoveGadget()
	end
	return
end

--------------------------------------------------------------------------------
-- Beam tracking
-- Tracked per unit+weapon (not per projectile) so a moving unit only ever
-- has ONE ghost beam per weapon, at its most recent position.
-- Key = unitID * 65536 + weaponDefID  (fast integer key, no string alloc)
--------------------------------------------------------------------------------
local weaponBeams = {} -- key -> { cfg, px, py, pz, endX, endY, endZ, lastSeenFrame }
local beamCleanupFrame = 0
local hasGhosts = false -- true when weaponBeams has any entries (skip ghost loop when empty)
local liveKeys = {} -- reused each frame, nil-cleared instead of reallocated
local liveKeysList = {} -- tracks keys to clear
local liveBeamSlot = {} -- wbKey -> offset slot in beamData (dedupe multiple projectiles per emitter)
local removeList = {} -- reused across cleanup cycles
local removeCount = 0

--------------------------------------------------------------------------------
-- Shader sources: Beam (direction-aligned quad)
--------------------------------------------------------------------------------
local beamVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

// Quad vertex: xy = corner position (-1..1), zw = UV
layout (location = 0) in vec4 position_xy_uv;

// Per-instance data
layout (location = 1) in vec4 startPosAndWidth;   // xyz = beam start, w = beam width (thickness)
layout (location = 2) in vec4 endPosAndLife;       // xyz = beam end,   w = life fraction (0=new, 1=expired)
layout (location = 3) in vec4 coreColor;           // rgb = core color, a = alpha
layout (location = 4) in vec4 edgeColor;           // rgb = edge color, a = range falloff factor

out DataVS {
	vec2 texCoords;
	vec4 vCoreColor;
	vec4 vEdgeColor;
	float alpha;
	float widthPos;  // -1..1 across beam width (for per-pixel core calc)
};

void main()
{
	vec3 startPos = startPosAndWidth.xyz;
	float beamWidth = startPosAndWidth.w;
	vec3 endPos = endPosAndLife.xyz;
	float lifeFrac = endPosAndLife.w;

	// Beam direction
	vec3 beamDir = endPos - startPos;
	float beamLength = length(beamDir);
	if (beamLength < 0.01) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}
	vec3 forward = beamDir / beamLength;

	// Camera-facing perpendicular for width
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCamera = normalize(camPos - mix(startPos, endPos, 0.5));
	vec3 right = cross(forward, toCamera);
	float rightLen = length(right);
	if (rightLen < 0.3) {
		vec3 fallback = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
		if (length(fallback) < 0.001) {
			fallback = normalize(cross(forward, vec3(1.0, 0.0, 0.0)));
		}
		float blend = clamp(rightLen / 0.3, 0.0, 1.0);
		right = normalize(mix(fallback, right / max(rightLen, 0.001), blend));
	} else {
		right = right / rightLen;
	}

	// Map vertex x: -1..1 = across beam width
	// Map vertex y: -1..1 = along beam length (0..1 normalized)
	float yNorm = position_xy_uv.y * 0.5 + 0.5;  // 0 = start, 1 = end

	// Animated width: pulse in/out over lifetime
	float fadeIn  = smoothstep(0.0, FADE_IN_END, lifeFrac);
	float fadeOut = 1.0 - smoothstep(FADE_OUT_START, 1.0, lifeFrac);
	float lifePulse = fadeIn * fadeOut;
	if (lifePulse < 0.001) { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); return; }

	// Width also narrows slightly toward the end of the beam (range falloff)
	float rangeTaper = 1.0 - RANGE_TAPER * yNorm;

	// Slight shimmer
	float phase = startPos.x * 0.7 + startPos.z * 1.1 + lifeFrac * 13.0;
	float shimmer = 1.0 + SHIMMER_AMPLITUDE * sin(timeInfo.z * SHIMMER_SPEED + phase + yNorm * 6.28);

	float width = beamWidth * lifePulse * rangeTaper * shimmer;

	// Minimum screen-space width: prevent the beam from becoming sub-pixel
	// at distance, which causes aliasing/jaggedness. If the beam would be
	// thinner than MIN_PIXEL_WIDTH pixels, expand it and dim alpha to compensate.
	vec3 vertPos = mix(startPos, endPos, yNorm);
	// Use beam midpoint for camDist so min-pixel-width is uniform along the
	// entire beam (per-vertex camDist causes start to appear narrower than middle)
	float camDist = length(camPos - mix(startPos, endPos, 0.5));
	float minWidth = camDist * MIN_PIXEL_WIDTH;
	float coverage = clamp(width / max(minWidth, 0.001), 0.0, 1.0);
	width = max(width, minWidth);

	vec3 vertexWorld = vertPos
		+ right * position_xy_uv.x * width;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	// UV: u = along length, v = across width
	texCoords = vec2(yNorm, position_xy_uv.z);

	// Pass raw data to FS for per-pixel core calculation
	vCoreColor = coreColor;
	vEdgeColor = edgeColor;
	widthPos = position_xy_uv.x;  // -1..1

	// Alpha: fade with lifetime and slight range falloff
	float rangeFalloff = edgeColor.a;
	float alphaFalloff = 1.0 - rangeFalloff * yNorm;
	alpha = coreColor.a * lifePulse * alphaFalloff * coverage;
}
]]

local beamFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D beamTex;

in DataVS {
	vec2 texCoords;
	vec4 vCoreColor;
	vec4 vEdgeColor;
	float alpha;
	float widthPos;
};

out vec4 fragColor;

void main(void)
{
	vec4 texSample = texture(beamTex, texCoords);

	// Per-pixel core factor from widthPos (-1..1), center = core
	// Use fwidth() to ensure the core-to-edge transition always spans at least 1 pixel,
	// preventing jagged/aliased core lines on low-resolution screens or thin beams.
	float edgeDist = abs(widthPos);
	float fw = fwidth(edgeDist);
	float aaStart = CORE_EDGE_START - fw * 0.5;
	float aaEnd   = max(CORE_EDGE_END, CORE_EDGE_START + fw);
	float coreFactor = 1.0 - smoothstep(aaStart, aaEnd, edgeDist);

	// Blend core and edge colors per-pixel
	vec3 beamCol = mix(vEdgeColor.rgb, vCoreColor.rgb, coreFactor);

	vec3 color = texSample.rgb * beamCol * alpha;

	// Brightness boost
	color *= BRIGHTNESS_MULT;

	// Core gets extra brightness for a hot inner line
	color *= (1.0 + coreFactor * CORE_BRIGHTNESS);

	// Fade beam tip over final few % of length for a soft end instead of hard cutoff
	float tipFade = 1.0 - smoothstep(TIP_FADE_START, 1.0, texCoords.x);
	color *= tipFade;

	// Soft discard: fade out near-black fragments instead of hard discard
	// to avoid aliased edges on the outer boundary of the beam
	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.0005) discard;
	float edgeSoft = smoothstep(0.0005, 0.003, lum);
	color *= edgeSoft;

	fragColor = vec4(color, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Flare (camera-facing billboard at beam start)
-- Renders the same core/edge color pattern as the beam, but radially.
--------------------------------------------------------------------------------
local flareVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 30000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;

// Per-instance (shared layout with beam VBO)
layout (location = 1) in vec4 startPosAndWidth;   // xyz = beam start, w = beam width
layout (location = 3) in vec4 coreColor;           // rgb = core color, a = alpha
layout (location = 4) in vec4 edgeColor;           // rgb = edge color, a = unused
layout (location = 5) in vec4 flareData;           // x = flareSize, yzw = unused

out DataVS {
	vec2 texCoords;
	vec4 vCoreColor;
	vec4 vEdgeColor;
};

void main()
{
	vec3 worldPos = startPosAndWidth.xyz;
	float flareSize = flareData.x;

	// Skip instances with no flare
	if (flareSize <= 0.0) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}

	// Billboard: camera-facing quad
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	vec3 vertexWorld = worldPos
		+ camRight * position_xy_uv.x * flareSize
		+ camUp    * position_xy_uv.y * flareSize;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);
	texCoords = position_xy_uv.zw;
	vCoreColor = coreColor;
	vEdgeColor = edgeColor;
}
]]

local flareFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 40000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D flareTex;

in DataVS {
	vec2 texCoords;
	vec4 vCoreColor;
	vec4 vEdgeColor;
};

out vec4 fragColor;

void main(void)
{
	vec4 texSample = texture(flareTex, texCoords);
	float shape = max(texSample.a, dot(texSample.rgb, vec3(0.299, 0.587, 0.114)));

	if (shape < 0.001) discard;

	// Radial core factor: same logic as beam but using radial distance
	vec2 centered = texCoords * 2.0 - 1.0;
	float dist = length(centered);
	float coreFactor = 1.0 - smoothstep(CORE_EDGE_START, CORE_EDGE_END, dist);

	// Blend core and edge colors per-pixel (same as beam)
	vec3 flareCol = mix(vEdgeColor.rgb, vCoreColor.rgb, coreFactor);

	vec3 color = flareCol * shape * BRIGHTNESS_MULT;

	// Core gets extra brightness for a hot center (same as beam)
	color *= (1.0 + coreFactor * CORE_BRIGHTNESS);

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.001) discard;

	// Additive blending (GL_ONE, GL_ONE): alpha channel unused
	fragColor = vec4(color, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Glow (wide direction-aligned quad for soft halo around beam)
-- Reuses the same VBO as beam/flare. Width is GLOW_WIDTH_MULT * beamWidth.
-- Smooth radial falloff + soft ends at both start and tip.
--------------------------------------------------------------------------------
local glowShaderConfig = {
	FADE_IN_END = shaderConfig.FADE_IN_END,
	FADE_OUT_START = shaderConfig.FADE_OUT_START,
	SHIMMER_AMPLITUDE = shaderConfig.SHIMMER_AMPLITUDE * 0.5,
	SHIMMER_SPEED = shaderConfig.SHIMMER_SPEED,
	GLOW_WIDTH_MULT = GLOW_WIDTH_MULT,
	GLOW_BRIGHTNESS = GLOW_BRIGHTNESS,
	GLOW_FALLOFF_POWER = GLOW_FALLOFF_POWER,
	GLOW_WIDTH_DIM = GLOW_THICKNESS_DIM * BEAM_WIDTH_MULT,
	GLOW_WIDTH_FULL = GLOW_THICKNESS_FULL * BEAM_WIDTH_MULT,
	GLOW_DIM_FACTOR = GLOW_DIM_FACTOR,
	MIN_PIXEL_WIDTH = shaderConfig.MIN_PIXEL_WIDTH,
}

local glowVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 80000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec4 startPosAndWidth;
layout (location = 2) in vec4 endPosAndLife;
layout (location = 3) in vec4 coreColor;
layout (location = 4) in vec4 edgeColor;

out DataVS {
	vec2 localPos;    // x = across width (-1..1), y = along length (extends past 0..1)
	vec3 glowColor;
	float alpha;
	float glowHalfWidth; // in normalized beam-length units, for capsule distance calc
};

void main()
{
	vec3 startPos = startPosAndWidth.xyz;
	float beamWidth = startPosAndWidth.w;
	vec3 endPos = endPosAndLife.xyz;
	float lifeFrac = endPosAndLife.w;

	vec3 beamDir = endPos - startPos;
	float beamLength = length(beamDir);
	if (beamLength < 0.01) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}
	vec3 forward = beamDir / beamLength;

	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCamera = normalize(camPos - mix(startPos, endPos, 0.5));
	vec3 right = cross(forward, toCamera);
	float rightLen = length(right);
	if (rightLen < 0.3) {
		vec3 fallback = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
		if (length(fallback) < 0.001) {
			fallback = normalize(cross(forward, vec3(1.0, 0.0, 0.0)));
		}
		float blend = clamp(rightLen / 0.3, 0.0, 1.0);
		right = normalize(mix(fallback, right / max(rightLen, 0.001), blend));
	} else {
		right = right / rightLen;
	}

	float fadeIn  = smoothstep(0.0, FADE_IN_END, lifeFrac);
	float fadeOut = 1.0 - smoothstep(FADE_OUT_START, 1.0, lifeFrac);
	float lifePulse = fadeIn * fadeOut;
	if (lifePulse < 0.001) { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); return; }

	float phase = startPos.x * 0.7 + startPos.z * 1.1 + lifeFrac * 13.0;
	float yNorm = position_xy_uv.y * 0.5 + 0.5;
	float shimmer = 1.0 + SHIMMER_AMPLITUDE * sin(timeInfo.z * SHIMMER_SPEED + phase + yNorm * 6.28);

	float glowWorldWidth = beamWidth * GLOW_WIDTH_MULT * lifePulse * shimmer;

	// No min-pixel-width clamping for glow: it is a soft additive halo that degrades
	// gracefully at distance. Inflating it at zoom-out made it disproportionately
	// large relative to the beam; removing inflation keeps proportions consistent.

	// Extend quad past beam endpoints by glowWorldWidth along forward direction
	// This creates the capsule-like rounded ends
	float extension = glowWorldWidth / max(beamLength, 0.01);
	float yExtended = mix(-extension, 1.0 + extension, yNorm);

	vec3 vertPos = startPos + forward * (yExtended * beamLength)
		+ right * position_xy_uv.x * glowWorldWidth;

	gl_Position = cameraViewProj * vec4(vertPos, 1.0);

	// Pass local coordinates: x = -1..1 across width, y = extended along length
	localPos = vec2(position_xy_uv.x, yExtended);

	// Ratio of glow width to beam length (for capsule distance in FS)
	glowHalfWidth = glowWorldWidth / max(beamLength, 0.01);

	glowColor = edgeColor.rgb;

	// Scale glow brightness by beam thickness: thin beams get dimmer glow
	float glowScale = mix(float(GLOW_DIM_FACTOR), 1.0, smoothstep(float(GLOW_WIDTH_DIM), float(GLOW_WIDTH_FULL), beamWidth));

	float rangeFalloff = edgeColor.a;
	float yBeamClamped = clamp(yExtended, 0.0, 1.0);
	float alphaFalloff = 1.0 - rangeFalloff * yBeamClamped;
	alpha = coreColor.a * lifePulse * alphaFalloff * glowScale;
}
]]

local glowFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 90000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec2 localPos;
	vec3 glowColor;
	float alpha;
	float glowHalfWidth;
};

out vec4 fragColor;

void main(void)
{
	// Capsule-shaped distance: find closest point on beam axis (0..1 segment),
	// then compute normalized distance from that point
	float yOnBeam = clamp(localPos.y, 0.0, 1.0);
	float dy = localPos.y - yOnBeam;  // overshoot past beam ends
	float dx = localPos.x;            // -1..1 across width

	// Normalize both axes to glow radius units
	// dx is already -1..1 (= full glow width), dy needs scaling relative to width
	float dyNorm = dy / max(glowHalfWidth, 0.001);

	// 2D distance from beam axis (capsule shape)
	float distSq = dx * dx + dyNorm * dyNorm;
	if (distSq >= 1.0) discard;
	float dist = sqrt(distSq);

	// Radial falloff with configurable power curve
	float falloff = pow(1.0 - dist, GLOW_FALLOFF_POWER);

	vec3 color = glowColor * (falloff * alpha * GLOW_BRIGHTNESS);

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.0003) discard;

	fragColor = vec4(color, 0.0);
}
]]

--------------------------------------------------------------------------------
-- Shader sources: Pulse (traveling energy blobs along beam)
-- Reuses the same VBO. Renders bright spots that travel from origin to target.
--------------------------------------------------------------------------------
local pulseShaderConfig = {
	FADE_IN_END = shaderConfig.FADE_IN_END,
	FADE_OUT_START = shaderConfig.FADE_OUT_START,
	PULSE_WIDTH_MULT = PULSE_WIDTH_MULT,
	PULSE_BRIGHTNESS = PULSE_BRIGHTNESS,
	PULSE_SPEED = PULSE_SPEED,
	PULSE_SPACING = PULSE_SPACING,
	PULSE_SIGMA = PULSE_SIGMA,
	PULSE_CORE_FRAC = PULSE_CORE_FRAC,
	PULSE_PARA_BRIGHTNESS = PULSE_PARA_BRIGHTNESS,
	PULSE_PARA_SPEED = PULSE_PARA_SPEED,
	PULSE_PARA_SPACING = PULSE_PARA_SPACING,
	PULSE_PARA_SIGMA = PULSE_PARA_SIGMA,
	PULSE_PARA_WIDTH_MULT = PULSE_PARA_WIDTH_MULT,
	MIN_PIXEL_WIDTH = shaderConfig.MIN_PIXEL_WIDTH,
}

local pulseVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 50000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec4 position_xy_uv;

layout (location = 1) in vec4 startPosAndWidth;
layout (location = 2) in vec4 endPosAndLife;
layout (location = 3) in vec4 coreColor;
layout (location = 4) in vec4 edgeColor;
layout (location = 5) in vec4 flareData;           // y = isParalyzer flag (0 or 1)

out DataVS {
	float yWorld;        // world-space position along beam (elmos)
	float widthPos;      // -1..1 across beam width
	vec3 pulseColor;     // bright core color
	float alpha;
	float phase;         // per-beam phase offset for pulse animation
	float beamLen;       // total beam length in world units
	float isParalyzer;   // 1.0 for paralyzer beams, 0.0 otherwise
	float coverage;      // beam width / min-pixel width (0..1), used to scale pulse length
};

void main()
{
	vec3 startPos = startPosAndWidth.xyz;
	float beamWidth = startPosAndWidth.w;
	vec3 endPos = endPosAndLife.xyz;
	float lifeFrac = endPosAndLife.w;

	vec3 beamDir = endPos - startPos;
	float beamLength = length(beamDir);
	if (beamLength < 0.01) {
		gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
		return;
	}
	vec3 forward = beamDir / beamLength;

	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCamera = normalize(camPos - mix(startPos, endPos, 0.5));
	vec3 right = cross(forward, toCamera);
	float rightLen = length(right);
	if (rightLen < 0.3) {
		vec3 fallback = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
		if (length(fallback) < 0.001) {
			fallback = normalize(cross(forward, vec3(1.0, 0.0, 0.0)));
		}
		float blend = clamp(rightLen / 0.3, 0.0, 1.0);
		right = normalize(mix(fallback, right / max(rightLen, 0.001), blend));
	} else {
		right = right / rightLen;
	}

	float yNorm = position_xy_uv.y * 0.5 + 0.5;

	float fadeIn  = smoothstep(0.0, FADE_IN_END, lifeFrac);
	float fadeOut = 1.0 - smoothstep(FADE_OUT_START, 1.0, lifeFrac);
	float lifePulse = fadeIn * fadeOut;
	if (lifePulse < 0.001) { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); return; }

	float paraFlag = flareData.y;  // 1.0 for paralyzer beams, 0.0 otherwise

	float pulseWidth = beamWidth * PULSE_WIDTH_MULT * lifePulse;

	vec3 vertPos = mix(startPos, endPos, yNorm);
	// Use beam midpoint for camDist so min-pixel-width is uniform along beam
	float camDist = length(camPos - mix(startPos, endPos, 0.5));
	// Track the beam body's effective width so pulse stays proportional at all distances
	float baseWidth = beamWidth * lifePulse;
	float minWidth = camDist * MIN_PIXEL_WIDTH;
	float coverageVal = clamp(baseWidth / max(minWidth, 0.001), 0.0, 1.0);
	// Per-beam width multiplier: paralyzer uses PULSE_PARA_WIDTH_MULT
	float widthMult = mix(float(PULSE_WIDTH_MULT), float(PULSE_PARA_WIDTH_MULT), paraFlag);
	// Lerp width multiplier toward 0.3 at distance so pulse shrinks below beam width
	// when both are at sub-pixel sizes (avoids pulse dominating a thin beam)
	float effectiveMult = 0.3 + (widthMult - 0.3) * coverageVal;
	pulseWidth = max(baseWidth, minWidth) * effectiveMult;

	vec3 vertexWorld = vertPos + right * position_xy_uv.x * pulseWidth;

	gl_Position = cameraViewProj * vec4(vertexWorld, 1.0);

	widthPos = position_xy_uv.x;
	yWorld = yNorm * beamLength;
	beamLen = beamLength;

	// Use edge (weapon) color for pulse to avoid color shift from CORE_COLOR_ADD
	pulseColor = edgeColor.rgb;

	// Per-beam unique phase derived from start position
	phase = startPos.x * 0.31 + startPos.y * 0.17 + startPos.z * 0.43;

	isParalyzer = paraFlag;

	coverage = coverageVal;

	float rangeFalloff = edgeColor.a;
	float alphaFalloff = 1.0 - rangeFalloff * yNorm;
	// coverage dims pulse at distance so it doesn't dominate a sub-pixel beam
	alpha = coreColor.a * lifePulse * lifePulse * alphaFalloff * coverageVal;
}
]]

local pulseFsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 60000

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	float yWorld;
	float widthPos;
	vec3 pulseColor;
	float alpha;
	float phase;
	float beamLen;
	float isParalyzer;
	float coverage;
};

out vec4 fragColor;

void main(void)
{
	// Select pulse parameters: paralyzer beams get faster, brighter, tighter pulses
	// float() casts needed because Lua tostring() strips ".0" from whole numbers,
	// making #defines integer literals which break mix() overload resolution.
	float pulseSpeed   = mix(float(PULSE_SPEED),      float(PULSE_PARA_SPEED),      isParalyzer);
	float pulseSpacing = mix(float(PULSE_SPACING),     float(PULSE_PARA_SPACING),    isParalyzer);
	float pulseSigma   = mix(float(PULSE_SIGMA),       float(PULSE_PARA_SIGMA),      isParalyzer);
	float pulseBright  = mix(float(PULSE_BRIGHTNESS),  float(PULSE_PARA_BRIGHTNESS), isParalyzer);

	// Radial falloff across beam width
	float edgeDist = abs(widthPos);
	float radial = 1.0 - smoothstep(PULSE_CORE_FRAC, 1.0, edgeDist);
	if (radial < 0.001) discard;

	// World-space distance to nearest pulse center (repeating pattern)
	float scrolledY = yWorld - timeInfo.z * pulseSpeed - phase * 100.0;
	float halfSpacing = pulseSpacing * 0.5;

	// Per-pulse random offset: hash the pulse index for organic irregularity
	float pulseIndex = floor(scrolledY / pulseSpacing + 0.5);
	float jitter = fract(sin(pulseIndex * 127.1 + phase * 311.7) * 43758.5453) - 0.5;
	float jitteredY = scrolledY + jitter * pulseSpacing * 0.3;

	float distToPulse = abs(mod(jitteredY + halfSpacing, pulseSpacing) - halfSpacing);

	// Gaussian falloff in world units
	float invSigmaSq = 1.0 / (2.0 * pulseSigma * pulseSigma);
	float pulseVal = exp(-distToPulse * distToPulse * invSigmaSq);

	// Fade at beam tip so pulses disappear smoothly (no fade at start — flare covers origin)
	float fadeDist = pulseSigma * 2.0;
	float edgeFade = 1.0 - smoothstep(beamLen - fadeDist, beamLen, yWorld);

	vec3 color = pulseColor * (pulseVal * radial * edgeFade * alpha * pulseBright);

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.0005) discard;

	fragColor = vec4(color, 0.0);
}
]]

--------------------------------------------------------------------------------
-- GL4 state
--------------------------------------------------------------------------------
local beamVBO
local beamShader
local flareShader
local glowShader
local pulseShader

-- Idle skip
local idleSkipCounter = 0

-- Cached ally team
local cachedAllyTeamID = spGetMyAllyTeamID()
local cachedSpecFullView = false

local function goodbye(reason)
	gadgetHandler:RemoveGadget()
end

-- Ensure all numeric values in a shader config table will produce GLSL float
-- literals. Lua's tostring() strips ".0" from whole numbers (e.g. 3.0 → "3"),
-- which becomes a GLSL integer literal and breaks functions like mix/smoothstep.
-- Adding a tiny epsilon forces Lua to keep the decimal point.
local function ensureFloatDefines(config)
	for k, v in pairs(config) do
		if type(v) == "number" and v == math.floor(v) then
			config[k] = v + 0.00001
		end
	end
	return config
end

local function initGL4()
	-- Sanitize all shader config tables to prevent integer #define values
	ensureFloatDefines(shaderConfig)
	ensureFloatDefines(glowShaderConfig)
	ensureFloatDefines(pulseShaderConfig)

	-- Beam shader
	local beamShaderCache = {
		vsSrc = beamVsSrc,
		fsSrc = beamFsSrc,
		shaderName = "BeamLaserGL4",
		uniformInt = { beamTex = 0 },
		uniformFloat = {},
		shaderConfig = shaderConfig,
		forceupdate = true,
	}
	beamShader = LuaShader.CheckShaderUpdates(beamShaderCache)
	if not beamShader then
		goodbye("Failed to compile beam shader")
		return false
	end

	-- Flare shader
	local flareShaderCache = {
		vsSrc = flareVsSrc,
		fsSrc = flareFsSrc,
		shaderName = "BeamLaserFlareGL4",
		uniformInt = { flareTex = 0 },
		uniformFloat = {},
		shaderConfig = shaderConfig,
		forceupdate = true,
	}
	flareShader = LuaShader.CheckShaderUpdates(flareShaderCache)
	if not flareShader then
		goodbye("Failed to compile flare shader")
		return false
	end

	-- Glow shader (wide soft halo around beam)
	local glowShaderCache = {
		vsSrc = glowVsSrc,
		fsSrc = glowFsSrc,
		shaderName = "BeamLaserGlowGL4",
		uniformFloat = {},
		shaderConfig = glowShaderConfig,
		forceupdate = true,
	}
	glowShader = LuaShader.CheckShaderUpdates(glowShaderCache)
	if not glowShader then
		goodbye("Failed to compile glow shader")
		return false
	end

	-- Pulse shader (traveling energy blobs along beam)
	local pulseShaderCache = {
		vsSrc = pulseVsSrc,
		fsSrc = pulseFsSrc,
		shaderName = "BeamLaserPulseGL4",
		uniformFloat = {},
		shaderConfig = pulseShaderConfig,
		forceupdate = true,
	}
	pulseShader = LuaShader.CheckShaderUpdates(pulseShaderCache)
	if not pulseShader then
		goodbye("Failed to compile pulse shader")
		return false
	end

	-- Shared quad VBOs
	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(-1, -1, 1, 1, 0, 0, 1, 1, "beamLaserQuadVBO")
	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("beamLaserIndexVBO")

	-- Beam VBO layout: beam data + flare data
	local beamLayout = {
		{ id = 1, name = "startPosAndWidth", size = 4 },
		{ id = 2, name = "endPosAndLife", size = 4 },
		{ id = 3, name = "coreColor", size = 4 },
		{ id = 4, name = "edgeColor", size = 4 },
		{ id = 5, name = "flareData", size = 4 },
	}
	beamVBO = gl.InstanceVBOTable.makeInstanceVBOTable(beamLayout, INITIAL_VBO_SIZE, "beamLaserVBO")
	if not beamVBO then
		goodbye("Failed to create beam VBO")
		return false
	end
	beamVBO.numVertices = numVertices
	beamVBO.vertexVBO = quadVBO
	beamVBO.VAO = beamVBO:makeVAOandAttach(quadVBO, beamVBO.instanceVBO)
	beamVBO.primitiveType = GL.TRIANGLES
	beamVBO.VAO:AttachIndexBuffer(indexVBO)
	beamVBO.indexVBO = indexVBO

	return true
end

local function resizeBeamVBO(needed)
	local newMax = beamVBO.maxElements
	while newMax < needed do
		newMax = newMax * 2
	end
	beamVBO.maxElements = newMax
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	newInstanceVBO:Define(newMax, beamVBO.layout)
	beamVBO.instanceVBO:Delete()
	beamVBO.instanceVBO = newInstanceVBO
	-- Extend instanceData array
	local data = beamVBO.instanceData
	local step = beamVBO.instanceStep
	for i = #data + 1, step * newMax do
		data[i] = 0
	end
	-- Reattach VAO
	beamVBO.VAO:Delete()
	beamVBO.VAO = beamVBO:makeVAOandAttach(beamVBO.vertexVBO, beamVBO.instanceVBO)
	beamVBO.VAO:AttachIndexBuffer(beamVBO.indexVBO)
end

local function cleanupGL4()
	if beamVBO then
		beamVBO:Delete()
		beamVBO = nil
	end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local function drawAll()
	if beamVBO.usedElements == 0 then
		return
	end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE)

	-- Glow pass (wide soft halo, drawn first so it's behind the beam)
	glowShader:Activate()
	beamVBO:Draw()
	glowShader:Deactivate()

	-- Beam pass (texture stays bound through flare pass since both use slot 0)
	glTexture(0, beamTexture)
	beamShader:Activate()
	beamVBO:Draw()
	beamShader:Deactivate()

	-- Pulse pass (traveling energy blobs, drawn on top of beam)
	pulseShader:Activate()
	beamVBO:Draw()
	pulseShader:Deactivate()

	-- Flare pass (same VBO, flare shader reads flareData; zero-size flares culled in VS)
	glTexture(0, flareTexture)
	flareShader:Activate()
	beamVBO:Draw()
	flareShader:Deactivate()
	glTexture(0, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

--------------------------------------------------------------------------------
-- Per-frame beam scan + VBO upload
--------------------------------------------------------------------------------

-- Cache config values as locals for hot loop
local FADE_OUT_START_CACHED = shaderConfig.FADE_OUT_START
local ONE_MINUS_FADE_OUT = 1.0 - FADE_OUT_START_CACHED

-- Pre-computed constants for live beams (lifeFrac is fixed at BEAM_SUSTAIN_LIFEFRAC)
local LIVE_LIFEFRAC = BEAM_SUSTAIN_LIFEFRAC
local LIVE_FLARE_PULSE = 1.0 - LIVE_LIFEFRAC * FLARE_LIFE_DIM

local mapSizeX = Game.mapSizeX
local mapSizeZ = Game.mapSizeZ

-- Binary search along a beam to find the LOS boundary.
-- Returns the interpolation fraction (0..1 from start to end) where LOS flips.
-- 'startInLos' indicates whether the start point is in LOS.
local function findLosBoundary(sx, sz, ex, ez, allyTeam, startInLos)
	local lo, hi = 0, 1
	for _ = 1, LOS_CLIP_STEPS do
		local mid = (lo + hi) * 0.5
		local mx = sx + (ex - sx) * mid
		local mz = sz + (ez - sz) * mid
		local midInLos = spLosCheck(mx, 0, mz, allyTeam)
		if (midInLos and startInLos) or (not midInLos and not startInLos) then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) * 0.5
end

local function updateBeams()
	-- Idle skip: throttle when no beams or ghosts active
	if idleSkipCounter > 0 then
		idleSkipCounter = idleSkipCounter - 1
		return
	end

	beamVBO.usedElements = 0

	local gameFrame = spGetGameFrame()
	local dto = spGetFrameTimeOffset()

	-- Clear liveKeys from previous frame (nil-clear, no table alloc)
	for i = 1, #liveKeysList do
		liveKeys[liveKeysList[i]] = nil
		liveBeamSlot[liveKeysList[i]] = nil
	end
	local liveKeysCount = 0

	-- Scan ALL weapon projectiles map-wide (not just camera-visible ones).
	-- GetVisibleProjectiles culls by projectile origin, which misses beams
	-- whose start is off-screen but whose middle or end is on-screen.
	local projectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ, false, true)
	local beamData = beamVBO.instanceData
	local beamCount = 0
	local offset = 0
	local myAllyTeam = cachedAllyTeamID
	local needLosCheck = not cachedSpecFullView

	if projectiles then
		for i = 1, #projectiles do
			local proID = projectiles[i]
			local wDefID = spGetProjectileDefID(proID)
			local cfg = wDefID and weaponConfigs[wDefID]
			if cfg then
				local px, py, pz = spGetProjectilePosition(proID)
				if px then
					local vx, vy, vz = spGetProjectileVelocity(proID)
					if vx then
						local endX = px + vx
						local endY = py + vy
						local endZ = pz + vz

						-- LOS check: beam is visible if start OR end is in LOS
						local visible = true
						local startInLos = true
						local endInLos = true
						local proAlly
						if needLosCheck then
							local proTeam = spGetProjectileTeamID(proID)
							proAlly = proTeam and spGetTeamAllyTeamID(proTeam)
							if proAlly ~= myAllyTeam then
								startInLos = spLosCheck(px, 0, pz, myAllyTeam)
								endInLos = spLosCheck(endX, 0, endZ, myAllyTeam)
								visible = startInLos or endInLos
							end
						end
						if visible then
							-- Save original (unclipped) positions for ghost beam tracking
							local origPx, origPy, origPz = px, py, pz
							local origEndX, origEndY, origEndZ = endX, endY, endZ

							-- Clip beam to LOS boundary when only one end is visible
							local clipStart = false
							if CLIP_BEAM_TO_LOS and needLosCheck and startInLos ~= endInLos then
								local t = findLosBoundary(px, pz, endX, endZ, myAllyTeam, startInLos)
								-- Extend visible portion by bonus range (ground LOS only)
								if not USE_AIR_LOS and LOS_BONUS_RANGE > 0 then
									local beamLen = mathSqrt(vx * vx + vy * vy + vz * vz)
									local bonusFrac = LOS_BONUS_RANGE / mathMax(beamLen, 1)
									if startInLos then
										t = mathMin(1, t + bonusFrac)
									else
										t = mathMax(0, t - bonusFrac)
									end
								end
								if startInLos then
									-- Clip the end (keep start)
									endX = px + vx * t
									endY = py + vy * t
									endZ = pz + vz * t
								else
									-- Clip the start (keep end)
									px = px + vx * t
									py = py + vy * t
									pz = pz + vz * t
									clipStart = true
								end
							end

							-- Check if any part of the beam is in the camera view (padded for glow quad)
							local pad = cfg.aabbPad
							if spIsAABBInView(mathMin(px, endX) - pad, mathMin(py, endY) - pad, mathMin(pz, endZ) - pad, mathMax(px, endX) + pad, mathMax(py, endY) + pad, mathMax(pz, endZ) + pad) then
								local ownerID = spGetProjectileOwnerID(proID) or 0
								-- Key = "ownerID|wDefID". Muzzle position deliberately
								-- excluded: turrets rotate between shots, so including the
								-- muzzle would give every shot a fresh key, and the previous
								-- shot's tracked entry would linger as a ghost beam while the
								-- new one renders -- looking like a stuttering rapid-fire
								-- trail instead of a single moving beam.
								-- Different beam weapons on the same unit (e.g. corhllt's
								-- hllt_top + hllt_bottom) have distinct wDefIDs, so owner+wDef
								-- already disambiguates them. Multiple hardpoints sharing the
								-- SAME wDefID on one unit (rare for beam lasers) would alias,
								-- but the result -- one of the two beams winning per frame --
								-- is less visually disruptive than the ghost-stacking trail.
								local wbKey = ownerID .. "|" .. wDefID
								if not liveKeys[wbKey] then
									liveKeys[wbKey] = true
									liveKeysCount = liveKeysCount + 1
									liveKeysList[liveKeysCount] = wbKey
								end

								local tracked = weaponBeams[wbKey]
								if not tracked then
									tracked = { cfg = cfg }
									weaponBeams[wbKey] = tracked
									hasGhosts = true
								end

								tracked.px = origPx
								tracked.py = origPy
								tracked.pz = origPz
								tracked.endX = origEndX
								tracked.endY = origEndY
								tracked.endZ = origEndZ
								tracked.lastSeenFrame = gameFrame
								tracked.ownerAllyTeam = proAlly

								-- Range falloff: use squared length (avoid sqrt)
								local beamLenSq = vx * vx + vy * vy + vz * vz
								local rangeFracSq = beamLenSq * cfg.invRangeSq
								local intensityFalloff = BEAM_RANGE_FALLOFF_BASE + BEAM_RANGE_FALLOFF_MULT * mathMin(rangeFracSq, 1.0)

								-- Dedupe: if this emitter already wrote a beam this frame
								-- (target-switch creates overlapping projectiles), reuse its
								-- slot so the newest projectile overwrites the previous one
								-- instead of rendering as a parallel beam.
								local slotOffset = liveBeamSlot[wbKey]
								local savedOffset
								if slotOffset then
									savedOffset = offset
									offset = slotOffset
								else
									beamCount = beamCount + 1
									liveBeamSlot[wbKey] = offset
								end
								beamData[offset + 1] = px
								beamData[offset + 2] = py
								beamData[offset + 3] = pz
								beamData[offset + 4] = cfg.beamWidth
								beamData[offset + 5] = endX
								beamData[offset + 6] = endY
								beamData[offset + 7] = endZ
								beamData[offset + 8] = LIVE_LIFEFRAC
								beamData[offset + 9] = cfg.coreR
								beamData[offset + 10] = cfg.coreG
								beamData[offset + 11] = cfg.coreB
								beamData[offset + 12] = 1.0
								beamData[offset + 13] = cfg.colorR
								beamData[offset + 14] = cfg.colorG
								beamData[offset + 15] = cfg.colorB
								beamData[offset + 16] = intensityFalloff
								-- Suppress flare when beam start is clipped to LOS boundary
								if clipStart then
									beamData[offset + 17] = 0
									beamData[offset + 18] = 0
									beamData[offset + 19] = 0
									beamData[offset + 20] = 0
								else
									beamData[offset + 17] = cfg.liveFlareSize
									beamData[offset + 18] = cfg.isParalyzer and 1.0 or 0.0 -- flareData.y: paralyzer flag for pulse shader
									beamData[offset + 19] = cfg.liveFlareG
									beamData[offset + 20] = cfg.liveFlareB
								end
								if savedOffset then
									offset = savedOffset
								else
									offset = offset + 20
								end
							end -- spIsAABBInView
						end -- visible
					end -- vx
				end -- px
			end -- cfg
		end
	end

	-- Trim liveKeysList
	for i = liveKeysCount + 1, #liveKeysList do
		liveKeysList[i] = nil
	end

	-- Ghost beams: skip entire loop when no tracked beams exist
	if hasGhosts then
		for wbKey, tracked in pairs(weaponBeams) do
			if not liveKeys[wbKey] and tracked.px then
				local cfg = tracked.cfg
				local ghostAge = gameFrame - tracked.lastSeenFrame
				if ghostAge >= 1 and ghostAge <= cfg.ghostFrames then
					local gpx, gpy, gpz = tracked.px, tracked.py, tracked.pz
					local gex, gey, gez = tracked.endX, tracked.endY, tracked.endZ

					-- LOS check for ghost beams (skip for own allyteam)
					local ghostVisible = true
					local ghostClipStart = false
					if needLosCheck and tracked.ownerAllyTeam ~= myAllyTeam then
						local startInLos = spLosCheck(gpx, 0, gpz, myAllyTeam)
						local endInLos = spLosCheck(gex, 0, gez, myAllyTeam)
						ghostVisible = startInLos or endInLos
						if ghostVisible and CLIP_BEAM_TO_LOS and startInLos ~= endInLos then
							local dvx = gex - gpx
							local dvy = gey - gpy
							local dvz = gez - gpz
							local t = findLosBoundary(gpx, gpz, gex, gez, myAllyTeam, startInLos)
							-- Extend visible portion by bonus range (ground LOS only)
							if not USE_AIR_LOS and LOS_BONUS_RANGE > 0 then
								local beamLen = mathSqrt(dvx * dvx + dvy * dvy + dvz * dvz)
								local bonusFrac = LOS_BONUS_RANGE / mathMax(beamLen, 1)
								if startInLos then
									t = mathMin(1, t + bonusFrac)
								else
									t = mathMax(0, t - bonusFrac)
								end
							end
							if startInLos then
								gex = gpx + dvx * t
								gey = gpy + dvy * t
								gez = gpz + dvz * t
							else
								gpx = gpx + dvx * t
								gpy = gpy + dvy * t
								gpz = gpz + dvz * t
								ghostClipStart = true
							end
						end
					end

					if ghostVisible then
						-- Check if any part of the ghost beam is in the camera view (padded for glow quad)
						local pad = cfg.aabbPad
						if spIsAABBInView(mathMin(gpx, gex) - pad, mathMin(gpy, gey) - pad, mathMin(gpz, gez) - pad, mathMax(gpx, gex) + pad, mathMax(gpy, gey) + pad, mathMax(gpz, gez) + pad) then
							local lifeFrac = FADE_OUT_START_CACHED + (ghostAge * cfg.invGhostFrames) * ONE_MINUS_FADE_OUT

							local vx = gex - gpx
							local vy = gey - gpy
							local vz = gez - gpz
							local beamLenSq = vx * vx + vy * vy + vz * vz
							local intensityFalloff = BEAM_RANGE_FALLOFF_BASE + BEAM_RANGE_FALLOFF_MULT * mathMin(beamLenSq * cfg.invRangeSq, 1.0)
							local flareVisible = ghostAge <= cfg.flareGhostFrames
							local flarePulse = (flareVisible and not ghostClipStart) and (1.0 - lifeFrac * FLARE_LIFE_DIM) or 0

							beamCount = beamCount + 1
							beamData[offset + 1] = gpx
							beamData[offset + 2] = gpy
							beamData[offset + 3] = gpz
							beamData[offset + 4] = cfg.beamWidth
							beamData[offset + 5] = gex
							beamData[offset + 6] = gey
							beamData[offset + 7] = gez
							beamData[offset + 8] = lifeFrac
							beamData[offset + 9] = cfg.coreR
							beamData[offset + 10] = cfg.coreG
							beamData[offset + 11] = cfg.coreB
							beamData[offset + 12] = 1.0
							beamData[offset + 13] = cfg.colorR
							beamData[offset + 14] = cfg.colorG
							beamData[offset + 15] = cfg.colorB
							beamData[offset + 16] = intensityFalloff
							beamData[offset + 17] = cfg.flareSize * flarePulse * FLARE_SIZE_MULT
							beamData[offset + 18] = cfg.isParalyzer and 1.0 or 0.0 -- flareData.y: paralyzer flag for pulse shader
							beamData[offset + 19] = cfg.flareColorG * flarePulse
							beamData[offset + 20] = cfg.flareColorB * flarePulse
							offset = offset + 20
						end
					end -- ghostVisible
				end
			end
		end
	end

	beamVBO.usedElements = beamCount
	if beamCount > 0 then
		idleSkipCounter = 0
		if beamCount > beamVBO.maxElements then
			resizeBeamVBO(beamCount)
			beamData = beamVBO.instanceData
		end
		uploadAllElements(beamVBO)
	else
		idleSkipCounter = IDLE_SKIP_FRAMES
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
end

function gadget:GameFrame(n)
	-- Periodic cleanup of stale weapon beam entries (expired ghosts)
	if n > beamCleanupFrame then
		beamCleanupFrame = n + 30
		removeCount = 0
		local anyRemain = false
		for wbKey, tracked in pairs(weaponBeams) do
			if n - (tracked.lastSeenFrame or 0) > GHOST_FRAMES_MAX + 2 then
				removeCount = removeCount + 1
				removeList[removeCount] = wbKey
			else
				anyRemain = true
			end
		end
		for i = 1, removeCount do
			weaponBeams[removeList[i]] = nil
		end
		hasGhosts = anyRemain
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
	updateBeams()
	drawAll()
end
