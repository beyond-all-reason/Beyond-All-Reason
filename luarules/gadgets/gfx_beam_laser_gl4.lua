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
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetProjectileTeamID = Spring.GetProjectileTeamID
local spGetTeamAllyTeamID = Spring.GetTeamAllyTeamID
local spIsPosInLos = Spring.IsPosInLos
local spIsPosInAirLos = Spring.IsPosInAirLos
local spGetMyAllyTeamID = Spring.GetLocalAllyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spGetGameFrame = Spring.GetGameFrame
local spGetProjectileOwnerID = Spring.GetProjectileOwnerID
local spGetProjectilesInRectangle = Spring.GetProjectilesInRectangle
local spIsAABBInView = Spring.IsAABBInView
local spGetUnitTransformMatrix = Spring.GetUnitTransformMatrix ---@type function

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
local mathFloor = math.floor

local LuaShader = gl.LuaShader
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

--------------------------------------------------------------------------------
-- Configuration
-- All tunables in one place. Shader #defines are injected via shaderConfig.
--------------------------------------------------------------------------------

-- Limits
local INITIAL_VBO_SIZE = 64 -- starting VBO capacity (doubles automatically when exceeded)

-- Per-weapon ghost frames: scaled by beam thickness so small lasers fade fast
local GHOST_FRAMES_MIN = 3 -- ghost frames for thinnest beams
local GHOST_FRAMES_MAX = 8 -- ghost frames for thickest beams
local GHOST_THICKNESS_MIN = 1.5 -- thickness at or below which gets min ghost frames
local GHOST_THICKNESS_MAX = 5.0 -- thickness at or above which gets max ghost frames
local FLARE_GHOST_FRAC = 0.4 -- fraction of weapon ghostFrames where flare stays visible (0..1)

-- Hardpoint bucketing: unit-local muzzle position is quantized into a coarse
-- grid and included in the tracking key. Model-space coordinates keep one
-- hardpoint stable while its unit moves and rotates, while the bucket still
-- separates multiple hardpoints that share a weaponDefID.
local HARDPOINT_BUCKET_SIZE = 12 -- elmos per bucket on each axis
local INV_HARDPOINT_BUCKET = 1 / HARDPOINT_BUCKET_SIZE
local HARDPOINT_MATCH_DISTANCE_SQ = 24 * 24 -- follow an animated muzzle across adjacent buckets
local HARDPOINT_DEDUPE_DISTANCE_SQ = 8 * 8 -- merge overlapping shots already claimed this scan

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

-- A weapon definition mounted once on a unit has only one legitimate emitter.
-- Keep model-space hardpoint separation only for definitions mounted repeatedly.
local repeatedMountWeaponDefs = {}
for _, unitDef in pairs(UnitDefs or {}) do
	local seenWeaponDefs = {}
	local weapons = unitDef.weapons
	for i = 1, #weapons do
		local weaponDefID = weapons[i].weaponDef
		if seenWeaponDefs[weaponDefID] then
			repeatedMountWeaponDefs[weaponDefID] = true
		else
			seenWeaponDefs[weaponDefID] = true
		end
	end
end

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
			local hasRepeatedMounts = repeatedMountWeaponDefs[weaponID]

			-- Per-weapon ghost frames based on thickness
			local ghostFrac =
				mathMin(1, mathMax(0, (thickness - GHOST_THICKNESS_MIN) / (GHOST_THICKNESS_MAX - GHOST_THICKNESS_MIN)))
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
				repeatedMount = hasRepeatedMounts or false,
				singleMountKey = -1 - weaponID, -- record key when the weapon has one emitter per unit
				paraFlag = isParalyzer and 1.0 or 0.0, -- flareData.y for the pulse shader
				-- Per-weapon ghost config
				ghostFrames = ghostFrames,
				flareGhostFrames = flareGhostFrames,
				invGhostFrames = 1.0 / ghostFrames,
				-- Pre-computed for hot loop
				beamWidth = thickness * BEAM_WIDTH_MULT,
				invRangeSq = 1.0 / mathMax(range * range, 1),
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
--------------------------------------------------------------------------------
-- weaponBeams is keyed two levels deep to avoid per-frame string-concat allocations:
--   weaponBeams[ownerID][innerKey] = rec
-- innerKey packs (wDefID, bx, by, bz) into a single number (see BEAM_KEY_*), or is
-- cfg.singleMountKey for weapons mounted once per unit.
-- A scan copies each emitter's live beam into its rec and stamps rec.liveStamp;
-- the build turns every live or fading rec in trackedList into one instance.
---@type table<number, table?>
local weaponBeams = {} -- [ownerID] = { [innerKey] = rec }
---@type table<integer, table>
local trackedList = {}
local trackedCount = 0
local beamCleanupFrame = 0

-- Object pools: avoid allocating fresh tracked records / ownerBeams sub-tables
-- every time a hardpoint resumes firing after a pause (or a unit fires for the
-- first time). Reused entries are reset on acquire; on release we strip cfg
-- (the only field that might pin a stale reference).
---@type table<integer, table>
local trackedPool = {}
local trackedPoolN = 0
---@type table<integer, table>
local ownerBeamsPool = {}
local ownerBeamsPoolN = 0

local function acquireTrackedBeam(cfg, ownerBeams, ownerID, innerKey)
	local rec
	if trackedPoolN > 0 then
		rec = trackedPool[trackedPoolN]
		trackedPool[trackedPoolN] = nil
		trackedPoolN = trackedPoolN - 1
		rec.liveStamp = 0
	else
		rec = {}
	end
	rec.cfg = cfg
	rec.ownerID = ownerID
	rec.innerKey = innerKey
	ownerBeams[innerKey] = rec
	trackedCount = trackedCount + 1
	trackedList[trackedCount] = rec
	return rec
end

local function releaseTrackedBeam(rec)
	rec.cfg = nil
	trackedPoolN = trackedPoolN + 1
	trackedPool[trackedPoolN] = rec
end

local function releaseOwnerBeams(t)
	ownerBeamsPoolN = ownerBeamsPoolN + 1
	ownerBeamsPool[ownerBeamsPoolN] = t
end
-- Bucket-key packing constants. Per-axis range is 4096 (12 bits) with +2048 offset
-- to handle negative bucket indices. wDefID occupies the high "digit".
-- Max value = 65535 * 4096^3 + 4095 * 4096^2 + 4095 * 4096 + 4095 ≈ 4.5e15,
-- well under Lua's 2^53 ≈ 9e15 safe-integer ceiling for doubles.
local BEAM_KEY_AXIS_OFFSET = 2048
local BEAM_KEY_BY_MUL = 4096
local BEAM_KEY_BX_MUL = 4096 * 4096
local BEAM_KEY_WDEFID_MUL = 4096 * 4096 * 4096

local function getBeamInnerKey(ownerID, wDefID, px, py, pz)
	-- The optional second argument returns the inverse affine transform.
	local m11, m12, m13, _, m21, m22, m23, _, m31, m32, m33, _, m41, m42, m43 = spGetUnitTransformMatrix(ownerID, true)
	if m11 then
		local worldX, worldY, worldZ = px, py, pz
		px = m11 * worldX + m21 * worldY + m31 * worldZ + m41
		py = m12 * worldX + m22 * worldY + m32 * worldZ + m42
		pz = m13 * worldX + m23 * worldY + m33 * worldZ + m43
	else
		local ux, uy, uz = Spring.GetUnitPosition(ownerID)
		if ux then
			px = px - ux
			py = py - uy
			pz = pz - uz
		end
	end
	local bx = mathFloor(px * INV_HARDPOINT_BUCKET)
	local by = mathFloor(py * INV_HARDPOINT_BUCKET)
	local bz = mathFloor(pz * INV_HARDPOINT_BUCKET)
	local innerKey = wDefID * BEAM_KEY_WDEFID_MUL
		+ (bx + BEAM_KEY_AXIS_OFFSET) * BEAM_KEY_BX_MUL
		+ (by + BEAM_KEY_AXIS_OFFSET) * BEAM_KEY_BY_MUL
		+ (bz + BEAM_KEY_AXIS_OFFSET)
	return innerKey, px, py, pz
end

local function resolveBeamEmitter(ownerBeams, ownerID, wDefID, px, py, pz, stamp)
	local innerKey, emitterX, emitterY, emitterZ = getBeamInnerKey(ownerID, wDefID, px, py, pz)
	local direct = ownerBeams[innerKey]
	if direct and direct.wDefID == wDefID then
		local dx = emitterX - direct.emitterX
		local dy = emitterY - direct.emitterY
		local dz = emitterZ - direct.emitterZ
		local distSq = dx * dx + dy * dy + dz * dz
		local maxDistSq = direct.liveStamp == stamp and HARDPOINT_DEDUPE_DISTANCE_SQ or HARDPOINT_MATCH_DISTANCE_SQ
		if distSq <= maxDistSq then
			return innerKey, direct, emitterX, emitterY, emitterZ
		end
	end

	local nearestKey, nearest, nearestDistSq
	for candidateKey, candidate in pairs(ownerBeams) do
		if candidate ~= direct and candidate.wDefID == wDefID then
			local dx = emitterX - candidate.emitterX
			local dy = emitterY - candidate.emitterY
			local dz = emitterZ - candidate.emitterZ
			local distSq = dx * dx + dy * dy + dz * dz
			local maxDistSq = candidate.liveStamp == stamp and HARDPOINT_DEDUPE_DISTANCE_SQ
				or HARDPOINT_MATCH_DISTANCE_SQ
			if distSq <= maxDistSq and (not nearestDistSq or distSq < nearestDistSq) then
				nearestKey = candidateKey
				nearest = candidate
				nearestDistSq = distSq
			end
		end
	end
	return nearestKey or innerKey, nearest, emitterX, emitterY, emitterZ
end

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
	float coverage;  // true beam width / inflated geometry width (0..1, =1 close, <1 far)
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
	float coverageVal = clamp(width / max(minWidth, 0.001), 0.0, 1.0);
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
	coverage = coverageVal;

	// Alpha: fade with lifetime and slight range falloff.
	// When the beam is widened to MIN_PIXEL_WIDTH (coverage < 1), we dim alpha to
	// conserve total emitted energy. Linear dim by `coverage` is energy-correct
	// but visually crushes the core at distance, while no dim at all over-bright
	// the inflated quad and produces line-ish jaggies. A sqrt curve is a good
	// middle ground: noticeably brighter than linear at small coverage, still
	// fades out gracefully, and lets fwidth-AA on the full inflated quad keep
	// edges smooth.
	float rangeFalloff = edgeColor.a;
	float alphaFalloff = 1.0 - rangeFalloff * yNorm;
	alpha = coreColor.a * lifePulse * alphaFalloff * sqrt(coverageVal);
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
	float coverage;
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

---@type InstanceVBOTable?
local beamVBO
local beamShader
local flareShader
local glowShader
local pulseShader

-- Monotonically incrementing stamp, bumped once per scanBeams() call. Used as
-- tracked.liveStamp: a record is live when the latest scan saw its emitter fire.
local scanStamp = 0

-- Set by a scan, cleared when the next draw builds the instance buffer from it
local buildPending = false

-- The scan runs once per sim frame; this asks the next draw for an extra scan
local needsRebuild = true

-- Subscription handle for the shared projectile dispatcher (set in Initialize).
-- When non-nil, GetMatches already returns the pre-filtered + per-frame-cached
-- list of beam-laser proIDs.
local dispatchHandle = nil

-- Cached ally team
local cachedAllyTeamID = spGetMyAllyTeamID()
local cachedSpecFullView = false

local function updateLosView()
	local _, specFullView = spGetSpectatingState()
	cachedSpecFullView = specFullView
	cachedAllyTeamID = specFullView and -1 or spGetMyAllyTeamID()
	needsRebuild = true
end

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

local LIVE_LIFEFRAC = BEAM_SUSTAIN_LIFEFRAC

-- The buffer holds every beam in LOS, so builds and draws are skipped while all of it is
-- off-screen. pendingBounds spans every record (recomputed by the cleanup) and grows with
-- each scanned beam, so it covers anything the next build can draw; drawBounds is its
-- copy at the last build. The pad covers the widest glow or flare plus the
-- minimum-pixel-width inflation of distant beams.
local drawBounds = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
local pendingBounds = { math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge }
local viewPad = 0
for _, cfg in pairs(weaponConfigs) do
	viewPad = mathMax(viewPad, cfg.beamWidth * GLOW_WIDTH_MULT * 1.1, cfg.liveFlareSize)
end
viewPad = viewPad + 32

local function boundsInView(b)
	return b[1] <= b[4]
		and spIsAABBInView(
			b[1] - viewPad,
			b[2] - viewPad,
			b[3] - viewPad,
			b[4] + viewPad,
			b[5] + viewPad,
			b[6] + viewPad
		)
end

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

local function scanBeams()
	scanStamp = scanStamp + 1
	local stamp = scanStamp

	local gameFrame = spGetGameFrame()

	-- Scan ALL weapon projectiles map-wide (not just camera-visible ones).
	-- GetVisibleProjectiles culls by projectile origin, which misses beams
	-- whose start is off-screen but whose middle or end is on-screen.
	-- Prefer the shared dispatcher: it caches the map-wide scan once per sim
	-- frame and pre-filters by weaponDefID so we don't iterate flamethrower/etc.
	-- projectiles here.
	local projectiles, matchDefIDs, projectileCount
	local PS = GG.ProjectileScan
	local dispatcherFiltered = (PS ~= nil and dispatchHandle ~= nil)
	if dispatcherFiltered then
		projectiles, matchDefIDs, projectileCount = PS.GetMatchesWithDefIDs(dispatchHandle)
	else
		projectiles = spGetProjectilesInRectangle(0, 0, mapSizeX, mapSizeZ, false, true)
		projectileCount = projectiles and #projectiles or 0
	end
	local myAllyTeam = cachedAllyTeamID
	local needLosCheck = not cachedSpecFullView
	local bounds = pendingBounds
	local minX, minY, minZ, maxX, maxY, maxZ = bounds[1], bounds[2], bounds[3], bounds[4], bounds[5], bounds[6]

	for i = 1, projectileCount do
		local proID = projectiles[i]
		local wDefID, cfg
		if dispatcherFiltered then
			wDefID = matchDefIDs[i]
			cfg = weaponConfigs[wDefID]
		else
			wDefID = spGetProjectileDefID(proID)
			cfg = wDefID and weaponConfigs[wDefID]
		end
		if cfg then
			local px, py, pz = spGetProjectilePosition(proID)
			if px then
				---@cast py number
				---@cast pz number
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

						local ownerID = spGetProjectileOwnerID(proID) or 0
						local ownerBeams = weaponBeams[ownerID]
						if not ownerBeams then
							if ownerBeamsPoolN > 0 then
								ownerBeams = ownerBeamsPool[ownerBeamsPoolN]
								ownerBeamsPool[ownerBeamsPoolN] = nil
								ownerBeamsPoolN = ownerBeamsPoolN - 1
							else
								ownerBeams = {}
							end
							weaponBeams[ownerID] = ownerBeams
						end
						-- Single-mount definitions always reuse one record. Repeated mounts
						-- follow nearest model-space emitters, with tighter same-scan matching.
						local innerKey, tracked, emitterX, emitterY, emitterZ
						if cfg.repeatedMount or ownerID == 0 then
							innerKey, tracked, emitterX, emitterY, emitterZ =
								resolveBeamEmitter(ownerBeams, ownerID, wDefID, origPx, origPy, origPz, stamp)
						else
							innerKey = cfg.singleMountKey
							tracked = ownerBeams[innerKey]
						end
						if not tracked then
							tracked = acquireTrackedBeam(cfg, ownerBeams, ownerID, innerKey)
						end

						-- Several projectiles of one emitter in a scan (overlapping beamttl,
						-- target switches) render as one beam: the last one seen wins.
						tracked.liveStamp = stamp
						tracked.wDefID = wDefID
						tracked.emitterX = emitterX
						tracked.emitterY = emitterY
						tracked.emitterZ = emitterZ
						tracked.px = origPx
						tracked.py = origPy
						tracked.pz = origPz
						tracked.endX = origEndX
						tracked.endY = origEndY
						tracked.endZ = origEndZ
						tracked.lastSeenFrame = gameFrame
						tracked.ownerAllyTeam = proAlly
						tracked.liveX = px
						tracked.liveY = py
						tracked.liveZ = pz
						tracked.liveEndX = endX
						tracked.liveEndY = endY
						tracked.liveEndZ = endZ
						tracked.liveClipStart = clipStart
						-- Range falloff: use squared length (avoid sqrt)
						local beamLenSq = vx * vx + vy * vy + vz * vz
						tracked.liveFalloff = BEAM_RANGE_FALLOFF_BASE
							+ BEAM_RANGE_FALLOFF_MULT * mathMin(beamLenSq * cfg.invRangeSq, 1.0)
						minX = mathMin(minX, origPx, origEndX)
						minY = mathMin(minY, origPy, origEndY)
						minZ = mathMin(minZ, origPz, origEndZ)
						maxX = mathMax(maxX, origPx, origEndX)
						maxY = mathMax(maxY, origPy, origEndY)
						maxZ = mathMax(maxZ, origPz, origEndZ)
					end -- visible
				end -- vx
			end -- px
		end -- cfg
	end
	bounds[1], bounds[2], bounds[3], bounds[4], bounds[5], bounds[6] = minX, minY, minZ, maxX, maxY, maxZ
	buildPending = true
end

-- One instance per record: live beams from the latest scan, then the fading
-- ghosts of emitters that stopped firing.
local function buildBeams()
	buildPending = false
	local stamp = scanStamp
	local gameFrame = spGetGameFrame()
	local beamData = beamVBO.instanceData
	local beamCount = 0
	local offset = 0
	local myAllyTeam = cachedAllyTeamID
	local needLosCheck = not cachedSpecFullView

	for i = 1, trackedCount do
		local tracked = trackedList[i]
		local cfg = tracked.cfg
		local sx, sy, sz, ex, ey, ez, lifeFrac, intensityFalloff, flareSize, flareG, flareB
		if tracked.liveStamp == stamp then
			sx, sy, sz = tracked.liveX, tracked.liveY, tracked.liveZ
			ex, ey, ez = tracked.liveEndX, tracked.liveEndY, tracked.liveEndZ
			lifeFrac = LIVE_LIFEFRAC
			intensityFalloff = tracked.liveFalloff
			-- Suppress flare when beam start is clipped to LOS boundary
			if tracked.liveClipStart then
				flareSize, flareG, flareB = 0, 0, 0
			else
				flareSize, flareG, flareB = cfg.liveFlareSize, cfg.liveFlareG, cfg.liveFlareB
			end
		else
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
					sx, sy, sz, ex, ey, ez = gpx, gpy, gpz, gex, gey, gez
					lifeFrac = FADE_OUT_START_CACHED + (ghostAge * cfg.invGhostFrames) * ONE_MINUS_FADE_OUT
					local vx = gex - gpx
					local vy = gey - gpy
					local vz = gez - gpz
					local beamLenSq = vx * vx + vy * vy + vz * vz
					intensityFalloff = BEAM_RANGE_FALLOFF_BASE
						+ BEAM_RANGE_FALLOFF_MULT * mathMin(beamLenSq * cfg.invRangeSq, 1.0)
					local flareVisible = ghostAge <= cfg.flareGhostFrames
					local flarePulse = (flareVisible and not ghostClipStart) and (1.0 - lifeFrac * FLARE_LIFE_DIM) or 0
					flareSize = cfg.flareSize * flarePulse * FLARE_SIZE_MULT
					flareG = cfg.flareColorG * flarePulse
					flareB = cfg.flareColorB * flarePulse
				end
			end
		end

		if sx then
			beamCount = beamCount + 1
			beamData[offset + 1] = sx
			beamData[offset + 2] = sy
			beamData[offset + 3] = sz
			beamData[offset + 4] = cfg.beamWidth
			beamData[offset + 5] = ex
			beamData[offset + 6] = ey
			beamData[offset + 7] = ez
			beamData[offset + 8] = lifeFrac
			beamData[offset + 9] = cfg.coreR
			beamData[offset + 10] = cfg.coreG
			beamData[offset + 11] = cfg.coreB
			beamData[offset + 12] = 1.0
			beamData[offset + 13] = cfg.colorR
			beamData[offset + 14] = cfg.colorG
			beamData[offset + 15] = cfg.colorB
			beamData[offset + 16] = intensityFalloff
			beamData[offset + 17] = flareSize
			beamData[offset + 18] = cfg.paraFlag -- flareData.y: paralyzer flag for pulse shader
			beamData[offset + 19] = flareG
			beamData[offset + 20] = flareB
			offset = offset + 20
		end
	end
	for k = 1, 6 do
		drawBounds[k] = pendingBounds[k]
	end

	beamVBO.usedElements = beamCount
	if beamCount > 0 then
		if beamCount > beamVBO.maxElements then
			resizeBeamVBO(beamCount)
		end
		uploadAllElements(beamVBO)
	end
end

--------------------------------------------------------------------------------
-- Gadget callins
--------------------------------------------------------------------------------

function gadget:Initialize()
	if not initGL4() then
		return
	end

	-- Subscribe to the shared projectile dispatcher (map-wide weapon scan).
	-- When loaded, GetMatches returns the pre-filtered beam projectile list
	-- once per tick, shared with the lightning cannon (same scan ID) and the
	-- other gfx_*_gl4 gadgets, eliminating duplicate engine calls.
	local PS = GG.ProjectileScan
	if PS then
		local defIDSet = {}
		for wDefID in pairs(weaponConfigs) do
			defIDSet[wDefID] = true
		end
		dispatchHandle = PS.Subscribe("beam_laser", defIDSet, PS.SCAN_MAP_WEAPONS)
	end
	updateLosView()
end

function gadget:GameFrame(n)
	-- Periodic cleanup of stale records (expired ghosts); also drops empty
	-- ownerBeams sub-tables so they don't accumulate for units that stopped firing.
	if n > beamCleanupFrame then
		beamCleanupFrame = n + 30
		local staleThreshold = GHOST_FRAMES_MAX + 2
		local kept = 0
		local bounds = pendingBounds
		bounds[1], bounds[2], bounds[3] = math.huge, math.huge, math.huge
		bounds[4], bounds[5], bounds[6] = -math.huge, -math.huge, -math.huge
		for i = 1, trackedCount do
			local rec = trackedList[i]
			if n - rec.lastSeenFrame > staleThreshold then
				-- a hardpoint bucket collision can have replaced this record in its table
				local ownerBeams = weaponBeams[rec.ownerID]
				if ownerBeams and ownerBeams[rec.innerKey] == rec then
					ownerBeams[rec.innerKey] = nil
					if next(ownerBeams) == nil then
						weaponBeams[rec.ownerID] = nil
						releaseOwnerBeams(ownerBeams)
					end
				end
				releaseTrackedBeam(rec)
			else
				kept = kept + 1
				trackedList[kept] = rec
				bounds[1] = mathMin(bounds[1], rec.px, rec.endX)
				bounds[2] = mathMin(bounds[2], rec.py, rec.endY)
				bounds[3] = mathMin(bounds[3], rec.pz, rec.endZ)
				bounds[4] = mathMax(bounds[4], rec.px, rec.endX)
				bounds[5] = mathMax(bounds[5], rec.py, rec.endY)
				bounds[6] = mathMax(bounds[6], rec.pz, rec.endZ)
			end
		end
		for i = kept + 1, trackedCount do
			trackedList[i] = nil
		end
		trackedCount = kept
	end
end

-- Beams are fired and expire during the sim frame, so scan once it is done: every
-- sim frame is seen once whatever the render rate, and draw frames replay the buffer.
function gadget:GameFramePost()
	needsRebuild = false
	scanBeams()
end

function gadget:PlayerChanged(playerID)
	updateLosView()
end

function gadget:Shutdown()
	cleanupGL4()
end

function gadget:DrawWorld()
	if needsRebuild then
		needsRebuild = false
		scanBeams()
	end
	if buildPending and boundsInView(pendingBounds) then
		buildBeams()
	end
	if not buildPending and beamVBO.usedElements > 0 and boundsInView(drawBounds) then
		drawAll()
	end
end
