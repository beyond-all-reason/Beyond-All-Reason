--------------------------------------------------------------------------------
-- Missile Thruster Effects GL4
-- GPU-instanced replacement for CBitmapMuzzleFlame engine effects on missiles.
-- Renders velocity-aligned textured quads (muzzle flame) + additive glow billboards.
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then return end

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
local spEcho                      = Spring.Echo
local spGetVisibleProjectiles     = Spring.GetVisibleProjectiles
local spGetProjectilePosition     = Spring.GetProjectilePosition
local spGetProjectileVelocity     = Spring.GetProjectileVelocity
local spGetProjectileDefID        = Spring.GetProjectileDefID
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

local mathRandom = math.random
local mathSqrt   = math.sqrt

local LuaShader = gl.LuaShader
local uploadAllElements      = gl.InstanceVBOTable.uploadAllElements

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------

-- Max simultaneous missile flames (should be more than enough)
local MAX_FLAMES = 4096

-- Textures
local muzzleTexture = "bitmaps/projectiletextures/muzzleside.tga"
local glowTexture   = "bitmaps/projectiletextures/glow2.tga"

--------------------------------------------------------------------------------
-- Thruster flame configs per cegTag
-- Fields:
--   length     : flame length (negative = behind projectile)
--   size       : flame width
--   colorR/G/B : base color (tip of flame, first colormap entry)
--   colorEndR/G/B : end color (last non-black colormap entry)
--   glowSize   : fireglow billboard size (0 = no glow)
--   glowR/G/B  : glow color
--   thrusterOffset : backward offset along flight direction (positive = further behind model)
--------------------------------------------------------------------------------
local THRUSTER_CONFIGS = {
	-- Standard small missiles (orange flame trailing behind)
	missiletrailsmall = {
		length = -16, lengthRand = 3.5,
		size = 2.1, sizeGrowth = 0.2,
		colorR = 1.0, colorG = 0.7, colorB = 0.4,
		colorEndR = 1.0, colorEndG = 0.4, colorEndB = 0.1,
		glowSize = 30, glowR = 0.12, glowG = 0.085, glowB = 0.017,
	},
	["missiletrailsmall-simple"] = {
		length = -18, lengthRand = 3.8,
		size = 2.0, sizeGrowth = 0.2,
		colorR = 1.0, colorG = 0.7, colorB = 0.4,
		colorEndR = 1.0, colorEndG = 0.4, colorEndB = 0.1,
		glowSize = 30, glowR = 0.12, glowG = 0.085, glowB = 0.017,
		thrusterOffset = 3,
	},
	["missiletrailsmall-red"] = {
		length = -21, lengthRand = 6,
		size = 3.45, sizeGrowth = 0.2,
		colorR = 1.0, colorG = 0.33, colorB = 0.17,
		colorEndR = 1.0, colorEndG = 0.22, colorEndB = 0.05,
		glowSize = 30, glowR = 0.2, glowG = 0.075, glowB = 0.075,
	},
	-- Tiny missiles
	missiletrailtiny = {
		length = -16, lengthRand = 4,
		size = 1.6, sizeGrowth = 0,
		colorR = 1.0, colorG = 0.66, colorB = 0.25,
		colorEndR = 0.55, colorEndG = 0.3, colorEndB = 0.05,
		glowSize = 22, glowR = 0.1, glowG = 0.06, glowB = 0.01,
		thrusterOffset = 3,
	},
	-- Medium missiles
	missiletrailmedium = {
		length = -24, lengthRand = 6,
		size = 3.3, sizeGrowth = 0.2,
		colorR = 1.0, colorG = 0.7, colorB = 0.4,
		colorEndR = 1.0, colorEndG = 0.4, colorEndB = 0.1,
		glowSize = 50, glowR = 0.15, glowG = 0.08, glowB = 0.02,
	},
	["missiletrailmedium-red"] = {
		length = -24, lengthRand = 6,
		size = 3.3, sizeGrowth = 0.2,
		colorR = 1.0, colorG = 0.33, colorB = 0.17,
		colorEndR = 1.0, colorEndG = 0.22, colorEndB = 0.05,
		glowSize = 50, glowR = 0.25, glowG = 0.1, glowB = 0.01,
	},
	missiletrailviper = {
		length = -24, lengthRand = 6,
		size = 3.3, sizeGrowth = 0.2,
		colorR = 1.0, colorG = 0.7, colorB = 0.4,
		colorEndR = 1.0, colorEndG = 0.4, colorEndB = 0.1,
		glowSize = 50, glowR = 0.15, glowG = 0.08, glowB = 0.02,
	},
	-- Fighter missiles (pinkish/purple-tinted, forward-facing)
	missiletrailfighter = {
		length = -20, lengthRand = 0,
		size = 1.65, sizeGrowth = 0,
		colorR = 1.0, colorG = 0.5, colorB = 0.85,
		colorEndR = 0.5, colorEndG = 0.1, colorEndB = 0.4,
		glowSize = 22, glowR = 0.1, glowG = 0.04, glowB = 0.08,
		thrusterOffset = -16,
	},
	-- AA missiles (pinkish, forward-facing, with large engineglow)
	missiletrailaa = {
		length = -32, lengthRand = 0,
		size = 2.3, sizeGrowth = 0,
		colorR = 1.0, colorG = 0.5, colorB = 0.85,
		colorEndR = 0.5, colorEndG = 0.1, colorEndB = 0.4,
		glowSize = 32, glowR = 0.14, glowG = 0.045, glowB = 0.125,
		thrusterOffset = -8,
	},
	-- Mship (corroyspecial) - larger, redder
	missiletrailmship = {
		length = -7, lengthRand = 2,
		size = 4.0, sizeGrowth = 0.2,
		colorR = 1.0, colorG = 0.25, colorB = 0.05,
		colorEndR = 1.0, colorEndG = 0.15, colorEndB = 0.03,
		glowSize = 44, glowR = 0.1, glowG = 0.05, glowB = 0.02,
	},

	-- Corroyspecial (no CBitmapMuzzleFlame engine, uses CSimpleParticleSystem fire only)
	-- missiletrailcorroyspecial is intentionally NOT included here
}

-- Also add starburst variants that share the same CBitmapMuzzleFlame configs
THRUSTER_CONFIGS["missiletrailsmall-starburst"] = THRUSTER_CONFIGS["missiletrailsmall"]
THRUSTER_CONFIGS["missiletrailmedium-starburst"] = THRUSTER_CONFIGS["missiletrailmedium"]


-- Build weaponDefID -> config lookup
local weaponConfigs = {}    -- weaponDefID -> thruster config table

for weaponID, weaponDef in pairs(WeaponDefs) do
	if weaponDef.type == "MissileLauncher" or weaponDef.type == "StarburstLauncher" then
		local tag = weaponDef.cegTag
		if tag then
			local cfg = THRUSTER_CONFIGS[tag]
			if cfg then
				weaponConfigs[weaponID] = cfg
			end
		end
	end
end

-- Precompute config defaults to avoid per-frame 'or' fallbacks
for _, cfg in pairs(weaponConfigs) do
	cfg.sizeGrowth     = cfg.sizeGrowth or 0.2
	cfg.glowSize       = cfg.glowSize or 0
	cfg.glowR          = cfg.glowR or 0.1
	cfg.glowG          = cfg.glowG or 0.06
	cfg.glowB          = cfg.glowB or 0.02
	cfg.lengthRand     = cfg.lengthRand or 0
	cfg.hasRand        = cfg.lengthRand > 0
	cfg.thrusterOffset = cfg.thrusterOffset or 4
end

-- Check if we have any missiles to render
local hasConfigs = false
for _ in pairs(weaponConfigs) do hasConfigs = true; break end
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

	// Use camera-facing perpendicular for width (ensures flame always visible from any angle)
	vec3 camPos = cameraViewInv[3].xyz;
	vec3 toCamera = normalize(camPos - worldPos);
	vec3 right = normalize(cross(forward, toCamera));
	// If forward and toCamera are parallel, fall back
	if (length(right) < 0.001) {
		right = normalize(cross(forward, vec3(0.0, 1.0, 0.0)));
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

	// Billboard: camera-facing quad
	vec3 camRight = cameraViewInv[0].xyz;
	vec3 camUp    = cameraViewInv[1].xyz;

	vec3 vertexWorld = worldPos
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
local glowShader

-- Per-projectile persistent state (direction + position cache for pause fallback)
local projectileCache = {}  -- proID -> {dx, dy, dz, px, py, pz}
local cacheCleanupFrame = 0

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
			SHIMMER_AMPLITUDE  = 0.15,   -- width oscillation strength (0 = off)
			SHIMMER_SPEED      = 0.17,   -- width oscillation speed
			SHIMMER_TAIL_BIAS  = 0.5,    -- how much shimmer at base vs tail (0 = tail only, 1 = uniform)
			BREATHE_BASE       = 0.88,   -- minimum brightness (pulse trough)
			BREATHE_RANGE      = 0.12,   -- brightness pulse range (peak = base + range)
			BREATHE_SPEED      = 0.13,   -- brightness pulse speed
			COLOR_GRADIENT_END = 0.7,    -- normalized position where color fully transitions to endColor
			TAIL_FADE_START    = 0.6,    -- normalized position where tail alpha begins fading
			TAIL_FADE_END      = 0.999,  -- normalized position where tail alpha reaches zero
			BRIGHTNESS_MULT    = 2.0,    -- overall brightness multiplier
		},
		forceupdate = true,
	}
	flameShader = LuaShader.CheckShaderUpdates(flameShaderCache)
	if not flameShader then
		goodbye("Failed to compile flame shader")
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
	local quadVBO, numVertices = gl.InstanceVBOTable.makeRectVBO(
		-1, -1, 1, 1,
		0, 0, 1, 1,
		"missileThrusterQuadVBO"
	)
	local indexVBO = gl.InstanceVBOTable.makeRectIndexVBO("missileThrusterIndexVBO")

	-- Flame VBO (combined layout: flame data + embedded glow data, UV flip via alpha sign)
	local flameLayout = {
		{id = 1, name = 'posAndSize',   size = 4},
		{id = 2, name = 'dirAndLength', size = 4},
		{id = 3, name = 'color1',       size = 4},
		{id = 4, name = 'color2',       size = 4},
		{id = 5, name = 'glowData',     size = 4},
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
	if flameVBO then flameVBO:Delete(); flameVBO = nil end
end

--------------------------------------------------------------------------------
-- Drawing helpers
--------------------------------------------------------------------------------
local function drawFlames()
	if flameVBO.usedElements == 0 then return end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE)  -- Pure additive: flames only add light, never darken

	glTexture(0, muzzleTexture)
	flameShader:Activate()
	flameVBO:Draw()
	flameShader:Deactivate()
	glTexture(0, false)

	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	glDepthMask(true)
	glDepthTest(false)
end

local function drawGlows()
	if flameVBO.usedElements == 0 then return end

	glDepthTest(true)
	glDepthMask(false)
	glCulling(false)
	glBlending(GL_ONE, GL_ONE)  -- Pure additive blending for glow

	glTexture(0, glowTexture)
	glowShader:Activate()
	flameVBO:Draw()  -- same VBO; glow shader reads glowData attribute
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
	flameVBO.usedElements = 0

	local ftoAdj = spGetFrameTimeOffset() - 1.0

	local _, specFullView = spGetSpectatingState()
	local allyTeamID = specFullView and -1 or spGetMyAllyTeamID()
	local projectiles = spGetVisibleProjectiles(allyTeamID, true, true, false)
	if not projectiles then return end

	local flameData = flameVBO.instanceData
	local flameStep = 20  -- posAndSize(4) + dirAndLength(4) + color1(4) + color2(4) + glowData(4)
	local flameCount = 0

	for i = 1, #projectiles do
		local proID = projectiles[i]
		local cfg = weaponConfigs[spGetProjectileDefID(proID)]
		if cfg then
			local px, py, pz = spGetProjectilePosition(proID)
			if px then
				local vx, vy, vz = spGetProjectileVelocity(proID)
				if vx then
					local speedSq = vx*vx + vy*vy + vz*vz
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
							projectileCache[proID] = {dx, dy, dz, px, py, pz}
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
							if length < 0 then
								length = length - rand * cfg.lengthRand
							else
								length = length + rand * cfg.lengthRand
							end
							size = size * (0.85 + 0.3 * mathRandom())
						end

						flameCount = flameCount + 1
						if flameCount <= MAX_FLAMES then
							local offset = (flameCount - 1) * flameStep
							flameData[offset + 1]  = px
							flameData[offset + 2]  = py
							flameData[offset + 3]  = pz
							flameData[offset + 4]  = size
							flameData[offset + 5]  = dx
							flameData[offset + 6]  = dy
							flameData[offset + 7]  = dz
							flameData[offset + 8]  = length
							flameData[offset + 9]  = cfg.colorR
							flameData[offset + 10] = cfg.colorG
							flameData[offset + 11] = cfg.colorB
							flameData[offset + 12] = 1.0
							flameData[offset + 13] = cfg.colorEndR
							flameData[offset + 14] = cfg.colorEndG
							flameData[offset + 15] = cfg.colorEndB
							flameData[offset + 16] = cfg.sizeGrowth
							flameData[offset + 17] = cfg.glowSize
							flameData[offset + 18] = cfg.glowR
							flameData[offset + 19] = cfg.glowG
							flameData[offset + 20] = cfg.glowB
						end
					end
				end
			end
		end
	end

	flameVBO.usedElements = flameCount
	if flameCount > 0 then
		uploadAllElements(flameVBO)
	end

	-- Periodic cache cleanup
	local frame = spGetGameFrame()
	if frame > cacheCleanupFrame then
		cacheCleanupFrame = frame + 90
		for proID in pairs(projectileCache) do
			if not spGetProjectilePosition(proID) then
				projectileCache[proID] = nil
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
	spEcho("Missile Thruster GL4: initialized with " .. n .. " weapon configs")
end

function gadget:Shutdown()
	cleanupGL4()
end

function gadget:DrawWorld()
	updateMissiles()
	drawFlames()
	drawGlows()
end
