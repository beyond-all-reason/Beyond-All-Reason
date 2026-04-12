--------------------------------------------------------------------------------
-- Beam Laser GL4
-- GPU-instanced replacement for engine BeamLaser rendering.
-- Renders direction-aligned textured quads with animated fade in/out,
-- edge glow, and range-based intensity falloff.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then return end

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
local spEcho                      = Spring.Echo
local spGetVisibleProjectiles     = Spring.GetVisibleProjectiles
local spGetProjectilePosition     = Spring.GetProjectilePosition
local spGetProjectileVelocity     = Spring.GetProjectileVelocity
local spGetProjectileDefID        = Spring.GetProjectileDefID
local spGetProjectileType         = Spring.GetProjectileType
local spGetProjectileTeamID       = Spring.GetProjectileTeamID
local spGetTeamAllyTeamID         = Spring.GetTeamAllyTeamID
local spIsPosInLos                = Spring.IsPosInLos
local spGetMyAllyTeamID           = Spring.GetMyAllyTeamID
local spGetSpectatingState        = Spring.GetSpectatingState
local spGetGameFrame              = Spring.GetGameFrame
local spGetProjectileOwnerID      = Spring.GetProjectileOwnerID

local glBlending  = gl.Blending
local glTexture   = gl.Texture
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glCulling   = gl.Culling

local GL_ONE                  = GL.ONE
local GL_ONE_MINUS_SRC_ALPHA  = GL.ONE_MINUS_SRC_ALPHA
local GL_SRC_ALPHA            = GL.SRC_ALPHA

local mathMin    = math.min
local mathMax    = math.max

local LuaShader = gl.LuaShader
local uploadAllElements = gl.InstanceVBOTable.uploadAllElements

--------------------------------------------------------------------------------
-- Configuration
-- All tunables in one place. Shader #defines are injected via shaderConfig.
--------------------------------------------------------------------------------

-- Limits
local INITIAL_VBO_SIZE = 64    -- starting VBO capacity (doubles automatically when exceeded)
local IDLE_SKIP_FRAMES = 3     -- draw-frames to skip polling when no beams active

-- Per-weapon ghost frames: scaled by beam thickness so small lasers fade fast
local GHOST_FRAMES_MIN      = 3     -- ghost frames for thinnest beams
local GHOST_FRAMES_MAX      = 7     -- ghost frames for thickest beams
local GHOST_THICKNESS_MIN   = 1.5   -- thickness at or below which gets min ghost frames
local GHOST_THICKNESS_MAX   = 4.0   -- thickness at or above which gets max ghost frames
local FLARE_GHOST_FRAC      = 0.4   -- fraction of weapon ghostFrames where flare stays visible (0..1)

-- Textures
local beamTexture  = "bitmaps/projectiletextures/largebeam.tga"
local flareTexture = "bitmaps/projectiletextures/flare2.tga"

-- Beam body
local BEAM_WIDTH_MULT         = 0.6   -- multiplier on weapon thickness for beam quad width
local BEAM_SUSTAIN_LIFEFRAC   = 0.33   -- lifeFrac value for live beams (must be between FADE_IN_END and FADE_OUT_START)
local BEAM_RANGE_FALLOFF_BASE = 0.1   -- minimum intensity falloff along beam length
local BEAM_RANGE_FALLOFF_MULT = 0.5  -- additional falloff scaled by beam-length / weapon-range

-- Core color boost (applied in weaponConfigs build)
local CORE_COLOR_ADD = 0.5  -- added to weapon RGB to create brighter core color (clamped to 1)

-- Flare billboard
local FLARE_SIZE_MULT       = 0.66   -- multiplier on (laserflaresize * thickness)
local FLARE_COLOR_MULT      = 1.0   -- multiplier on core color for flare RGB
local FLARE_LIFE_DIM        = 0.7   -- how much flare dims over beam lifetime (0 = none, 1 = fully dark at end)

-- Shader config (injected as #defines into beam vertex+fragment shaders)
local shaderConfig = {
	FADE_IN_END        = 0.12,    -- lifeFrac where width/alpha fade-in completes
	FADE_OUT_START     = 0.8,   -- lifeFrac where width/alpha fade-out begins
	RANGE_TAPER        = 0.20,   -- width reduction at beam end (0 = none, 1 = full taper to zero)
	SHIMMER_AMPLITUDE  = 0.08,   -- width oscillation strength (0 = off)
	SHIMMER_SPEED      = 0.35,   -- width oscillation speed (timeInfo.z multiplier)
	CORE_EDGE_START    = 0.07,   -- |x| distance where core-to-edge color blend starts (0 = only center pixel)
	CORE_EDGE_END      = 0.3,    -- |x| distance where blend is fully edge color
	CORE_BRIGHTNESS    = 3.3,    -- extra brightness multiplier for core (squared falloff)
	BRIGHTNESS_MULT    = 2.5,    -- overall beam brightness multiplier
}

--------------------------------------------------------------------------------
-- Build weaponDefID -> beam config lookup
-- Reads weapon colors, thickness, flare size, range, beamtime from WeaponDefs
--------------------------------------------------------------------------------
local weaponConfigs = {}  -- weaponDefID -> config table
local LIVE_FLARE_PULSE_INIT = 1.0 - BEAM_SUSTAIN_LIFEFRAC * FLARE_LIFE_DIM  -- pre-computed for weaponConfigs

for weaponID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.type == "BeamLaser" then
		local vis = weaponDef.visuals or {}
		local r = vis.colorR or 1
		local g = vis.colorG or 1
		local b = vis.colorB or 1

		-- Core is brighter, edge is the weapon color
		local coreR = mathMin(1, r + CORE_COLOR_ADD)
		local coreG = mathMin(1, g + CORE_COLOR_ADD)
		local coreB = mathMin(1, b + CORE_COLOR_ADD)

		-- Read original visual properties from customparams (alldefs_post stores them before zeroing)
		local cp = weaponDef.customParams or {}
		local thickness     = tonumber(cp.beam_thickness_orig) or weaponDef.thickness or 2
		local corethickness = tonumber(cp.beam_corethickness_orig) or weaponDef.corethickness or 0.3
		local laserflaresize = tonumber(cp.beam_laserflaresize_orig) or weaponDef.laserflaresize or 7
		local range         = weaponDef.range or 300
		local beamttl       = weaponDef.beamttl or 3
		local beamtime      = weaponDef.beamtime or 0.1

		-- Paralyzer beams get a unique tint
		local isParalyzer = weaponDef.paralyzer or false

		-- Per-weapon ghost frames based on thickness
		local ghostFrac = mathMin(1, mathMax(0, (thickness - GHOST_THICKNESS_MIN) / (GHOST_THICKNESS_MAX - GHOST_THICKNESS_MIN)))
		local ghostFrames = math.floor(GHOST_FRAMES_MIN + ghostFrac * (GHOST_FRAMES_MAX - GHOST_FRAMES_MIN) + 0.5)
		local flareGhostFrames = mathMax(1, math.floor(ghostFrames * FLARE_GHOST_FRAC + 0.5))

		weaponConfigs[weaponID] = {
			colorR = r,     colorG = g,     colorB = b,
			coreR = coreR,  coreG = coreG,  coreB = coreB,
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

-- Check if we have any beam weapons
local hasConfigs = false
for _ in pairs(weaponConfigs) do hasConfigs = true; break end
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
local weaponBeams = {}   -- key -> { cfg, px, py, pz, endX, endY, endZ, lastSeenFrame }
local beamCleanupFrame = 0
local hasGhosts = false    -- true when weaponBeams has any entries (skip ghost loop when empty)
local liveKeys = {}        -- reused each frame, nil-cleared instead of reallocated
local liveKeysList = {}    -- tracks keys to clear

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

	// Width also narrows slightly toward the end of the beam (range falloff)
	float rangeTaper = 1.0 - RANGE_TAPER * yNorm;

	// Slight shimmer
	float phase = startPos.x * 0.7 + startPos.z * 1.1 + lifeFrac * 13.0;
	float shimmer = 1.0 + SHIMMER_AMPLITUDE * sin(timeInfo.z * SHIMMER_SPEED + phase + yNorm * 6.28);

	float width = beamWidth * lifePulse * rangeTaper * shimmer;

	vec3 vertexWorld = mix(startPos, endPos, yNorm)
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
	alpha = coreColor.a * lifePulse * alphaFalloff;
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
	float edgeDist = abs(widthPos);
	float coreFactor = 1.0 - smoothstep(CORE_EDGE_START, CORE_EDGE_END, edgeDist);

	// Blend core and edge colors per-pixel
	vec3 beamCol = mix(vEdgeColor.rgb, vCoreColor.rgb, coreFactor);

	vec3 color = texSample.rgb * beamCol * alpha;

	// Brightness boost
	color *= BRIGHTNESS_MULT;

	// Core gets extra brightness for a hot inner line
	color *= (1.0 + coreFactor * coreFactor * CORE_BRIGHTNESS);

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.001) discard;

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
	color *= (1.0 + coreFactor * coreFactor * CORE_BRIGHTNESS);

	float lum = dot(color, vec3(0.299, 0.587, 0.114));
	if (lum < 0.001) discard;

	// Additive blending (GL_ONE, GL_ONE): alpha channel unused
	fragColor = vec4(color, 0.0);
}
]]

--------------------------------------------------------------------------------
-- GL4 state
--------------------------------------------------------------------------------
local beamVBO
local beamShader
local flareShader

-- Idle skip
local idleSkipCounter = 0

-- Cached ally team
local cachedAllyTeamID = spGetMyAllyTeamID()
local cachedSpecFullView = false

local function goodbye(reason)
	gadgetHandler:RemoveGadget()
end

local function initGL4()
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

	-- Shared quad VBOs
	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(
		-1, -1, 1, 1,
		0, 0, 1, 1,
		"beamLaserQuadVBO"
	)
	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("beamLaserIndexVBO")

	-- Beam VBO layout: beam data + flare data
	local beamLayout = {
		{id = 1, name = 'startPosAndWidth', size = 4},
		{id = 2, name = 'endPosAndLife',    size = 4},
		{id = 3, name = 'coreColor',        size = 4},
		{id = 4, name = 'edgeColor',        size = 4},
		{id = 5, name = 'flareData',        size = 4},
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
	while newMax < needed do newMax = newMax * 2 end
	beamVBO.maxElements = newMax
	local newInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true)
	newInstanceVBO:Define(newMax, beamVBO.layout)
	beamVBO.instanceVBO:Delete()
	beamVBO.instanceVBO = newInstanceVBO
	-- Extend instanceData array
	local data = beamVBO.instanceData
	local step = beamVBO.instanceStep
	for i = #data + 1, step * newMax do data[i] = 0 end
	-- Reattach VAO
	beamVBO.VAO:Delete()
	beamVBO.VAO = beamVBO:makeVAOandAttach(beamVBO.vertexVBO, beamVBO.instanceVBO)
	beamVBO.VAO:AttachIndexBuffer(beamVBO.indexVBO)
end

local function cleanupGL4()
	if beamVBO then beamVBO:Delete(); beamVBO = nil end
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
local function drawAll()
	if beamVBO.usedElements == 0 then return end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE)

	-- Beam pass
	glTexture(0, beamTexture)
	beamShader:Activate()
	beamVBO:Draw()
	beamShader:Deactivate()

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

local function updateBeams()
	-- Idle skip: throttle when no beams or ghosts active
	if idleSkipCounter > 0 then
		idleSkipCounter = idleSkipCounter - 1
		return
	end

	beamVBO.usedElements = 0

	local gameFrame = spGetGameFrame()

	-- Clear liveKeys from previous frame (nil-clear, no table alloc)
	for i = 1, #liveKeysList do
		liveKeys[liveKeysList[i]] = nil
	end
	local liveKeysCount = 0

	local projectiles = spGetVisibleProjectiles(-1, true, true, false)
	local beamData = beamVBO.instanceData
	local beamCount = 0
	local myAllyTeam = cachedAllyTeamID
	local needLosCheck = not cachedSpecFullView

	if projectiles then
		for i = 1, #projectiles do
			local proID = projectiles[i]
			local weapon, piece = spGetProjectileType(proID)
			if weapon and not piece then
				local wDefID = spGetProjectileDefID(proID)
				local cfg = wDefID and weaponConfigs[wDefID]
				if cfg then
					local px, py, pz = spGetProjectilePosition(proID)
					if px then
						-- LOS check
						local visible = true
						if needLosCheck then
							local proTeam = spGetProjectileTeamID(proID)
							local proAlly = proTeam and spGetTeamAllyTeamID(proTeam)
							if proAlly ~= myAllyTeam then
								visible = spIsPosInLos(px, 0, pz, myAllyTeam)
							end
						end
						if visible then
							local vx, vy, vz = spGetProjectileVelocity(proID)
							if vx then
								local endX = px + vx
								local endY = py + vy
								local endZ = pz + vz

								local ownerID = spGetProjectileOwnerID(proID) or 0
								local wbKey = ownerID * 65536 + wDefID
								liveKeys[wbKey] = true
								liveKeysCount = liveKeysCount + 1
								liveKeysList[liveKeysCount] = wbKey

								local tracked = weaponBeams[wbKey]
								if not tracked then
									tracked = { cfg = cfg }
									weaponBeams[wbKey] = tracked
									hasGhosts = true
								end
								tracked.px = px;   tracked.py = py;   tracked.pz = pz
								tracked.endX = endX; tracked.endY = endY; tracked.endZ = endZ
								tracked.lastSeenFrame = gameFrame

								-- Range falloff: use squared length (avoid sqrt)
								local beamLenSq = vx*vx + vy*vy + vz*vz
								local rangeFracSq = beamLenSq * cfg.invRangeSq
								local intensityFalloff = BEAM_RANGE_FALLOFF_BASE + BEAM_RANGE_FALLOFF_MULT * mathMin(rangeFracSq, 1.0)

								beamCount = beamCount + 1
								local offset = (beamCount - 1) * 20
								beamData[offset + 1]  = px
								beamData[offset + 2]  = py
								beamData[offset + 3]  = pz
								beamData[offset + 4]  = cfg.beamWidth
								beamData[offset + 5]  = endX
								beamData[offset + 6]  = endY
								beamData[offset + 7]  = endZ
								beamData[offset + 8]  = LIVE_LIFEFRAC
								beamData[offset + 9]  = cfg.coreR
								beamData[offset + 10] = cfg.coreG
								beamData[offset + 11] = cfg.coreB
								beamData[offset + 12] = 1.0
								beamData[offset + 13] = cfg.colorR
								beamData[offset + 14] = cfg.colorG
								beamData[offset + 15] = cfg.colorB
								beamData[offset + 16] = intensityFalloff
								beamData[offset + 17] = cfg.liveFlareSize
								beamData[offset + 18] = cfg.liveFlareR
								beamData[offset + 19] = cfg.liveFlareG
								beamData[offset + 20] = cfg.liveFlareB
							end
						end
					end
				end
			end
		end
	end

	-- Trim liveKeysList
	for i = liveKeysCount + 1, #liveKeysList do liveKeysList[i] = nil end

	-- Ghost beams: skip entire loop when no tracked beams exist
	if hasGhosts then
		for wbKey, tracked in pairs(weaponBeams) do
			if not liveKeys[wbKey] and tracked.px then
				local cfg = tracked.cfg
				local ghostAge = gameFrame - tracked.lastSeenFrame
				if ghostAge >= 1 and ghostAge <= cfg.ghostFrames then
					local lifeFrac = FADE_OUT_START_CACHED + (ghostAge * cfg.invGhostFrames) * ONE_MINUS_FADE_OUT

					local vx = tracked.endX - tracked.px
					local vy = tracked.endY - tracked.py
					local vz = tracked.endZ - tracked.pz
					local beamLenSq = vx*vx + vy*vy + vz*vz
					local intensityFalloff = BEAM_RANGE_FALLOFF_BASE + BEAM_RANGE_FALLOFF_MULT * mathMin(beamLenSq * cfg.invRangeSq, 1.0)
					local flareVisible = ghostAge <= cfg.flareGhostFrames
					local flarePulse = flareVisible and (1.0 - lifeFrac * FLARE_LIFE_DIM) or 0

					beamCount = beamCount + 1
					local offset = (beamCount - 1) * 20
					beamData[offset + 1]  = tracked.px
					beamData[offset + 2]  = tracked.py
					beamData[offset + 3]  = tracked.pz
					beamData[offset + 4]  = cfg.beamWidth
					beamData[offset + 5]  = tracked.endX
					beamData[offset + 6]  = tracked.endY
					beamData[offset + 7]  = tracked.endZ
					beamData[offset + 8]  = lifeFrac
					beamData[offset + 9]  = cfg.coreR
					beamData[offset + 10] = cfg.coreG
					beamData[offset + 11] = cfg.coreB
					beamData[offset + 12] = 1.0
					beamData[offset + 13] = cfg.colorR
					beamData[offset + 14] = cfg.colorG
					beamData[offset + 15] = cfg.colorB
					beamData[offset + 16] = intensityFalloff
					beamData[offset + 17] = cfg.flareSize * flarePulse * FLARE_SIZE_MULT
					beamData[offset + 18] = cfg.flareColorR * flarePulse
					beamData[offset + 19] = cfg.flareColorG * flarePulse
					beamData[offset + 20] = cfg.flareColorB * flarePulse
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
	if not initGL4() then return end
	local n = 0
	for _ in pairs(weaponConfigs) do n = n + 1 end
end

function gadget:GameFrame(n)
	-- Periodic cleanup of stale weapon beam entries (expired ghosts)
	if n > beamCleanupFrame then
		beamCleanupFrame = n + 30
		local removeList
		local removeCount = 0
		local anyRemain = false
		for wbKey, tracked in pairs(weaponBeams) do
			if n - (tracked.lastSeenFrame or 0) > GHOST_FRAMES_MAX + 2 then
				removeCount = removeCount + 1
				if not removeList then removeList = {} end
				removeList[removeCount] = wbKey
			else
				anyRemain = true
			end
		end
		if removeList then
			for i = 1, removeCount do
				weaponBeams[removeList[i]] = nil
			end
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
