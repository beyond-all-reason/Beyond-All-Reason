local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Unit Hit Decals (Textured)",
		desc      = "Piece-attached textured decals at unit hit points. Quads orient with the piece (rotate with rotating turrets). GL4 instanced — scales to thousands.",
		author    = "Phase 3 (decals)",
		date      = "2026-05-03",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true,
		depends   = { 'gl4' },
	}
end

------------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------------

local MIN_TECHLEVEL = 1

-- Per-kind tuning. lifetime/fadeIn in game frames (30 = 1s).
-- atlasUV = {u0, v0, du, dv} in atlas (0..1 normalized). For now we use a single
-- texture per kind; replace with a real atlas later.
local KIND = {
	plasma = {
		texture = "luaui/images/unit_hit_decals/plasma-hit.tga",
		size    = 9,
		r = 1.0, g = 0.55, b = 0.15, a = 1.0,
		lifetime = 240,    -- 8s
		fadeIn   = 4,
		cooldown = 2,
		atlasUV  = { 0, 0, 1, 1 },
	},
	laser = {
		texture = "luaui/images/unit_hit_decals/plasma-hit.tga",  -- placeholder
		size    = 12,
		a = 1.2,                                  -- color filled per-weapon
		lifetime = 300,
		fadeIn   = 6,
		cooldown = 6,
		atlasUV  = { 0, 0, 1, 1 },
	},
	bomb = {
		texture = "luaui/images/unit_hit_decals/plasma-hit.tga",  -- placeholder
		size    = 16,
		r = 1.0, g = 0.55, b = 0.15, a = 1.0,
		lifetime = 240,
		fadeIn   = 5,
		cooldown = 0,
		atlasUV  = { 0, 0, 1, 1 },
	},
	flame = {
		texture = "luaui/images/unit_hit_decals/plasma-hit.tga",  -- placeholder
		size    = 10,
		r = 1.0, g = 0.4, b = 0.1, a = 0.8,
		lifetime = 180,
		fadeIn   = 4,
		cooldown = 8,
		atlasUV  = { 0, 0, 1, 1 },
	},
}

local WEAPON_TYPE_DEFAULTS = {
	Cannon            = "plasma",
	MissileLauncher   = "plasma",
	StarburstLauncher = "plasma",
	TorpedoLauncher   = "plasma",
	EmgCannon         = "plasma",
	AircraftBomb      = "bomb",
	BeamLaser         = "laser",
	LaserCannon       = "laser",
	LightningCannon   = "laser",
	Flame             = "flame",
}

local MAX_DECALS = 2000  -- VBO capacity; auto-grows but pre-size for typical end-game

------------------------------------------------------------------------------
-- LOCALS
------------------------------------------------------------------------------

local spGetGameFrame      = Spring.GetGameFrame
local spGetUnitPosition   = Spring.GetUnitPosition
local spValidUnitID       = Spring.ValidUnitID
local spGetUnitPieceList  = Spring.GetUnitPieceList
local spGetUnitPiecePos   = Spring.GetUnitPiecePosition
local spGetUnitPieceInfo  = Spring.GetUnitPieceInfo
local spGetUnitPieceMatrix    = Spring.GetUnitPieceMatrix
local spGetUnitTransformMatrix = Spring.GetUnitTransformMatrix

local glTexture     = gl.Texture
local glDepthTest   = gl.DepthTest
local glDepthMask   = gl.DepthMask
local glBlending    = gl.Blending
local glCulling     = gl.Culling
local GL_SRC_ALPHA  = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local mathSqrt = math.sqrt
local mathMax  = math.max
local mathAbs  = math.abs

local LuaShader           = gl.LuaShader
local InstanceVBOTable    = gl.InstanceVBOTable
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance
local drawInstanceVBO     = InstanceVBOTable.drawInstanceVBO

------------------------------------------------------------------------------
-- LOOKUPS (built in Initialize)
------------------------------------------------------------------------------

local unitEligible    = {}
local weaponDecalKind = {}
local weaponColor     = {}

local function buildLookups()
	for udid, ud in pairs(UnitDefs) do
		local tech = tonumber(ud.customParams and ud.customParams.techlevel) or 1
		if tech >= MIN_TECHLEVEL then
			unitEligible[udid] = true
		end
	end
	for wdid, wd in pairs(WeaponDefs) do
		local cp = wd.customParams or {}
		local override = cp.bar_hit_decal_type
		local kind
		if override == "none" then
			kind = nil
		elseif KIND[override] then
			kind = override
		else
			kind = WEAPON_TYPE_DEFAULTS[wd.type]
		end
		weaponDecalKind[wdid] = kind
		if kind == "laser" then
			local c = wd.visuals and (wd.visuals.color or wd.visuals.rgbColor1)
			if type(c) == "table" and #c >= 3 then
				weaponColor[wdid] = { c[1], c[2], c[3] }
			else
				weaponColor[wdid] = { 1.0, 0.3, 0.2 }
			end
		end
	end
end

------------------------------------------------------------------------------
-- PIECE CACHE (per-unitDefID AABB + name)
------------------------------------------------------------------------------

local pieceCache = {}

local function getPieceCache(unitID, unitDefID)
	local c = pieceCache[unitDefID]
	if c then return c end
	local names = spGetUnitPieceList(unitID)
	if not names then return nil end
	local cache = { pieceCount = #names }
	for i = 1, #names do
		local info = spGetUnitPieceInfo(unitID, i)
		local empty = true
		local cx, cy, cz = 0, 0, 0
		local minx, miny, minz, maxx, maxy, maxz = 0, 0, 0, 0, 0, 0
		local pieceRadius = 0
		if info and info.min and info.max then
			empty = info.empty == true
			minx, miny, minz = info.min[1], info.min[2], info.min[3]
			maxx, maxy, maxz = info.max[1], info.max[2], info.max[3]
			cx = (minx + maxx) * 0.5
			cy = (miny + maxy) * 0.5
			cz = (minz + maxz) * 0.5
			local ax = mathMax(mathAbs(minx), mathAbs(maxx))
			local ay = mathMax(mathAbs(miny), mathAbs(maxy))
			local az = mathMax(mathAbs(minz), mathAbs(maxz))
			pieceRadius = mathSqrt(ax*ax + ay*ay + az*az)
		end
		-- Skip pieces with absurd AABB radii (sentinel "infinite" markers, ±10000).
		-- DO NOT skip on the "empty" flag alone — many models mark the main body
		-- piece as empty (it's a parent bone) while it still has valid AABB and
		-- represents the unit's main bulk geometrically.
		local sane = pieceRadius < 200 and pieceRadius > 0.5
		cache[i] = {
			name = names[i] or "?",
			empty = not sane,
			cx = cx, cy = cy, cz = cz,
			minx = minx, miny = miny, minz = minz,
			maxx = maxx, maxy = maxy, maxz = maxz,
			radius = pieceRadius,
		}
	end
	pieceCache[unitDefID] = cache
	return cache
end

-- Convert world impact to piece-local. Same math as the lights widget:
-- world = M_unit * M_piece * local  →  local = (M_unit * M_piece)^-1 * world
-- For orthonormal rotation, inverse is transpose; project (world - pieceWorldPos)
-- onto each combined-rotation column.
local function worldToPieceLocal(unitID, pieceIndex, wx, wy, wz)
	local plx, ply, plz = spGetUnitPiecePos(unitID, pieceIndex)
	if not plx then return nil end
	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then return nil end
	local pwx, pwy, pwz = ux + plx, uy + ply, uz + plz

	local u11,u12,u13,_, u21,u22,u23,_, u31,u32,u33,_, _,_,_,_ = spGetUnitTransformMatrix(unitID)
	if not u11 then return nil end
	local p11,p12,p13,_, p21,p22,p23,_, p31,p32,p33,_, _,_,_,_ = spGetUnitPieceMatrix(unitID, pieceIndex)
	if not p11 then return nil end

	-- Combined R = R_unit * R_piece, columns = world basis vectors of piece
	local cx_x = u11*p11 + u21*p12 + u31*p13
	local cx_y = u12*p11 + u22*p12 + u32*p13
	local cx_z = u13*p11 + u23*p12 + u33*p13
	local cy_x = u11*p21 + u21*p22 + u31*p23
	local cy_y = u12*p21 + u22*p22 + u32*p23
	local cy_z = u13*p21 + u23*p22 + u33*p23
	local cz_x = u11*p31 + u21*p32 + u31*p33
	local cz_y = u12*p31 + u22*p32 + u32*p33
	local cz_z = u13*p31 + u23*p32 + u33*p33

	local rx, ry, rz = wx - pwx, wy - pwy, wz - pwz
	-- inverse rotation = transpose: project onto each column.
	local lx = cx_x * rx + cx_y * ry + cx_z * rz
	local ly = cy_x * rx + cy_y * ry + cy_z * rz
	local lz = cz_x * rx + cz_y * ry + cz_z * rz
	return lx, ly, lz
end

-- Pick the best piece for this impact using DIRECTIONAL scoring.
-- The impact world position is often FAR outside the visible mesh (BAR collision
-- volumes are much larger than meshes). Distance-based scoring then picks weird
-- pieces because all distances are large and small piece-size differences dominate.
--
-- Instead: compute the direction from unit center → impact, and the direction
-- from unit center → each piece. Score = dot product (cosine similarity).
-- A back hit picks the back piece, a top hit picks a top piece, etc — regardless
-- of how far the impact is reported beyond the unit.
local debugRemainingHits = 0  -- /unithitdecalstextured debug -> sets to 5

-- Pick the piece whose bounding sphere best contains the impact, in WORLD frame.
-- THEORY B: Spring.GetUnitPiecePosition returns piece coords in UNIT-LOCAL space
-- (pre-rotation), so to get the piece's world position we apply R_unit:
--     piece_world_pos = unit_world_pos + R_unit * piece_unit_local_pos
-- Earlier we used (unit_pos + plx) which only works for unrotated units; the
-- mirror-flip bug for L/R pieces on rotated units points to that being wrong.
local function pickBestPiece(unitID, unitDefID, wx, wy, wz)
	local cache = getPieceCache(unitID, unitDefID)
	if not cache then return nil end
	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then return nil end
	local u11,u12,u13,_, u21,u22,u23,_, u31,u32,u33,_, _,_,_,_ = spGetUnitTransformMatrix(unitID)

	local verbose = debugRemainingHits > 0
	if verbose then
		Spring.Echo(string.format("  pickBestPiece %s @ impact (%.0f,%.0f,%.0f) unit (%.0f,%.0f,%.0f):",
			(UnitDefs[unitDefID] and UnitDefs[unitDefID].name) or "?", wx, wy, wz, ux, uy, uz))
	end

	local bestIdx, bestScore, bestDist = nil, math.huge, math.huge
	for i = 1, cache.pieceCount do
		local p = cache[i]
		if p and not p.empty then
			local plx, ply, plz = spGetUnitPiecePos(unitID, i)
			if plx then
				-- World piece position via R_unit (theory B).
				local pwx, pwy, pwz
				if u11 then
					pwx = ux + u11*plx + u21*ply + u31*plz
					pwy = uy + u12*plx + u22*ply + u32*plz
					pwz = uz + u13*plx + u23*ply + u33*plz
				else
					pwx, pwy, pwz = ux + plx, uy + ply, uz + plz
				end
				local dx, dy, dz = pwx - wx, pwy - wy, pwz - wz
				local dist = mathSqrt(dx*dx + dy*dy + dz*dz)
				local outside = dist - p.radius
				if outside < 0 then outside = 0 end
				if verbose then
					Spring.Echo(string.format("    [%d] %-20s plx=(%5.1f,%5.1f,%5.1f) pwx=(%5.0f,%4.0f,%5.0f) r=%5.1f dist=%6.1f score=%5.1f",
						i, p.name, plx, ply, plz, pwx, pwy, pwz, p.radius, dist, outside))
				end
				if outside < bestScore or (outside == bestScore and dist < bestDist) then
					bestScore, bestDist, bestIdx = outside, dist, i
				end
			end
		end
	end
	if bestIdx and verbose then
		Spring.Echo(string.format("  -> WINNER: piece [%d] %s", bestIdx, cache[bestIdx].name))
	end
	return bestIdx
end

-- Old name kept for compat in case anything else calls it.
local pickClosestPieceByOrigin = pickBestPiece

-- Clamp piece-local point to the piece's AABB. Returns clamped point + outward
-- face normal (vec3, piece-local). The normal direction is the AABB face the
-- point was outside of (or nearest to, if inside).
local function clampToAABBSurface(p, lx, ly, lz)
	-- How far outside the AABB on each axis (negative if inside).
	local outx = (lx < p.minx) and (p.minx - lx) or ((lx > p.maxx) and (lx - p.maxx) or -math.huge)
	local outy = (ly < p.miny) and (p.miny - ly) or ((ly > p.maxy) and (ly - p.maxy) or -math.huge)
	local outz = (lz < p.minz) and (p.minz - lz) or ((lz > p.maxz) and (lz - p.maxz) or -math.huge)

	-- Clamp into the box.
	if lx < p.minx then lx = p.minx elseif lx > p.maxx then lx = p.maxx end
	if ly < p.miny then ly = p.miny elseif ly > p.maxy then ly = p.maxy end
	if lz < p.minz then lz = p.minz elseif lz > p.maxz then lz = p.maxz end

	-- If point is inside (all outs are -inf), pick the nearest face.
	if outx == -math.huge and outy == -math.huge and outz == -math.huge then
		local dxMin = lx - p.minx; local dxMax = p.maxx - lx
		local dyMin = ly - p.miny; local dyMax = p.maxy - ly
		local dzMin = lz - p.minz; local dzMax = p.maxz - lz
		local best, axis, sign = dxMin, "x", -1
		if dxMax < best then best, axis, sign = dxMax, "x", 1 end
		if dyMin < best then best, axis, sign = dyMin, "y", -1 end
		if dyMax < best then best, axis, sign = dyMax, "y", 1 end
		if dzMin < best then best, axis, sign = dzMin, "z", -1 end
		if dzMax < best then best, axis, sign = dzMax, "z", 1 end
		if axis == "x" then return lx, ly, lz, sign, 0, 0
		elseif axis == "y" then return lx, ly, lz, 0, sign, 0
		else return lx, ly, lz, 0, 0, sign end
	end

	-- Outside: pick the axis with the largest "out" — that's the face we crossed.
	local nx, ny, nz = 0, 0, 0
	if outx >= outy and outx >= outz then
		nx = (lx == p.minx) and -1 or 1
	elseif outy >= outz then
		ny = (ly == p.miny) and -1 or 1
	else
		nz = (lz == p.minz) and -1 or 1
	end
	return lx, ly, lz, nx, ny, nz
end

------------------------------------------------------------------------------
-- SHADERS (inline)
------------------------------------------------------------------------------

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10000

uniform float currentFrame;
uniform int reflectionPass = 0;

// Static quad geometry: position.xy in [-1,1], uv in [0,1].
layout (location = 0) in vec4 position_xy_uv;

// Per-instance:
layout (location = 1) in vec4 localPosSize;     // piece-local pos.xyz, quad half-size
layout (location = 2) in vec4 localNormalRoll;  // piece-local outward normal.xyz, roll angle
layout (location = 3) in vec4 instColor;
layout (location = 4) in vec4 instTimes;        // spawnFrame, lifetime, fadeIn, _
layout (location = 5) in vec4 instAtlasUV;      // u0, v0, du, dv
layout (location = 6) in uint pieceIndex;
layout (location = 7) in uvec4 instData;        // matOffset, uniformOffset, ...

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

// Quaternion-based piece transforms (when supported by the engine). Replaced
// at compile time with the engine's Transform type + GetPieceWorldTransform helper.
#if USEQUATERNIONS == 1
	//__QUATERNIONDEFS__
#else
	layout(std140, binding=0) readonly buffer MatrixBuffer {
		mat4 UnitPieces[];
	};
#endif

// Per-unit uniforms (drawFlag, team, etc.) — manually declared, not auto-injected.
struct SUniformsBuffer {
	uint composite; // packed: drawFlag, unused1, id (u8 + u8 + u16)
	uint unused2;
	uint unused3;
	uint unused4;
	float maxHealth;
	float health;
	float unused5;
	float unused6;
	vec4 drawPos;
	vec4 speed;
	vec4[4] userDefined;
};
layout(std140, binding=1) readonly buffer UniformsBuffer {
	SUniformsBuffer uni[];
};

out DataVS {
	vec2 v_uv;
	vec4 v_color;
	float v_age;
	float v_fadeIn;
};

void main() {
	// pieceIndex == 0 → attach to unit only (no piece transform). This lets the
	// decal live in unit-local space and follow unit translation+rotation, but
	// not track per-piece animations (turrets, walking limbs).
	#if USEQUATERNIONS == 0
		uint baseIndex = instData.x;
		mat4 modelMatrix = UnitPieces[baseIndex];
		mat4 worldMat;
		if (pieceIndex == 0u) {
			worldMat = modelMatrix;
		} else {
			mat4 pieceMatrix = mat4mix(mat4(1.0), UnitPieces[baseIndex + pieceIndex + 1u], modelMatrix[3][3]);
			worldMat = modelMatrix * pieceMatrix;
		}
	#else
		mat4 worldMat;
		if (pieceIndex == 0u) {
			Transform unitTX = GetPieceWorldTransform(instData.x, -1);
			worldMat = TransformToMatrix(unitTX);
		} else {
			Transform pieceWorldTX = GetPieceWorldTransform(instData.x, pieceIndex);
			worldMat = TransformToMatrix(pieceWorldTX);
		}
	#endif

	// Build quad orientation from the piece-local outward normal.
	vec3 normal = normalize(localNormalRoll.xyz);
	vec3 up = abs(normal.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangent = normalize(cross(up, normal));
	vec3 bitangent = cross(normal, tangent);

	// Apply roll around the normal (random orientation per spawn).
	float roll = localNormalRoll.w;
	float c = cos(roll);
	float s = sin(roll);
	vec3 t2 = tangent * c + bitangent * s;
	vec3 b2 = -tangent * s + bitangent * c;
	tangent = t2;
	bitangent = b2;

	// Tiny outward push along the normal so the decal sits just above the AABB
	// face (avoid z-fighting with the model surface).
	float size = localPosSize.w;
	vec3 vertLocal = localPosSize.xyz
	               + tangent * (position_xy_uv.x * size)
	               + bitangent * (position_xy_uv.y * size)
	               + normal * 1.0;

	mat4 VP = (reflectionPass == 0) ? cameraViewProj : reflectionViewProj;
	gl_Position = VP * worldMat * vec4(vertLocal, 1.0);

	v_uv = vec2(instAtlasUV.x + position_xy_uv.z * instAtlasUV.z,
	            instAtlasUV.y + position_xy_uv.w * instAtlasUV.w);
	v_color = instColor;

	float lifetime = max(instTimes.y, 1.0);
	v_age = clamp((currentFrame - instTimes.x) / lifetime, 0.0, 1.0);
	v_fadeIn = max(instTimes.z, 1.0);

	// (Cloak/visibility check disabled for now — was suspected of clipping
	// everything off-screen. Re-enable later once we confirm rendering works.)
	// if ((uni[instData.y].composite & 0x0000001fu) == 0u) {
	//     gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
	// }
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#line 20000

uniform sampler2D atlasTex;

in DataVS {
	vec2 v_uv;
	vec4 v_color;
	float v_age;
	float v_fadeIn;
};

out vec4 fragColor;

void main() {
	// DEBUG: solid yellow, depth-test still on. Lets us see where each quad is
	// in the world without the texture's alpha hiding most pixels.
	fragColor = vec4(1.0, 1.0, 0.0, 0.8);
}
]]

------------------------------------------------------------------------------
-- VBO + SHADER STATE
------------------------------------------------------------------------------

local decalShader
local decalVBOByTexture = {}  -- one VBO per texture (so we can do texture switches by batching)
local autoInstanceID  = 0
local removeQueue = {}        -- [frame] = { {vbo, instanceID}, ... }

local VBO_LAYOUT = {
	{ id = 1, name = 'localPosSize',     size = 4 },
	{ id = 2, name = 'localNormalRoll',  size = 4 },
	{ id = 3, name = 'instColor',        size = 4 },
	{ id = 4, name = 'instTimes',        size = 4 },
	{ id = 5, name = 'instAtlasUV',      size = 4 },
	{ id = 6, name = 'pieceIndex',       type = GL.UNSIGNED_INT, size = 1 },
	{ id = 7, name = 'instData',         type = GL.UNSIGNED_INT, size = 4 },
}

local function makeDecalVBO(name)
	local quadVBO, numVertices = InstanceVBOTable.makeRectVBO(-1, -1, 1, 1, 0, 0, 1, 1)
	local vbo = InstanceVBOTable.makeInstanceVBOTable(VBO_LAYOUT, MAX_DECALS, name, 7)
	vbo.numVertices = numVertices
	vbo.vertexVBO = quadVBO
	vbo.indexVBO = InstanceVBOTable.makeRectIndexVBO()
	vbo.VAO = InstanceVBOTable.makeVAOandAttach(vbo.vertexVBO, vbo.instanceVBO, vbo.indexVBO)
	vbo.primitiveType = GL.TRIANGLES
	return vbo
end

local function getVBOForTexture(texturePath)
	local vbo = decalVBOByTexture[texturePath]
	if vbo then return vbo end
	vbo = makeDecalVBO("UnitHitDecals: " .. texturePath)
	vbo.texture = texturePath
	decalVBOByTexture[texturePath] = vbo
	return vbo
end

------------------------------------------------------------------------------
-- SPAWN PATH (called by gadget bridge via UnitHitDecalTextured global)
------------------------------------------------------------------------------

local stats = {
	hitsReceived = 0, rejected = 0, spawned = 0,
}

-- per-unit per-kind cooldown
local lastSpawnFrame = {}
for kind, _ in pairs(KIND) do lastSpawnFrame[kind] = {} end

local instCacheTable = {}  -- reused per spawn (avoid GC)

local function spawnDecal(unitID, unitDefID, pieceIndex, lx, ly, lz, nx, ny, nz, kind, weaponDefID)
	local cfg = KIND[kind]
	if not cfg or not decalShader then return end

	local now = spGetGameFrame()

	-- Cooldown
	if cfg.cooldown > 0 then
		local last = lastSpawnFrame[kind][unitID]
		if last and (now - last) < cfg.cooldown then
			stats.rejected = stats.rejected + 1
			return
		end
	end

	-- Color (laser uses weapon color)
	local r, g, b = cfg.r or 1, cfg.g or 1, cfg.b or 1
	if kind == "laser" then
		local c = weaponColor[weaponDefID]
		if c then r, g, b = c[1], c[2], c[3] end
	end

	-- Random roll for visual variation
	local roll = math.random() * 6.2831853

	autoInstanceID = autoInstanceID + 1
	local instanceID = autoInstanceID

	local uv = cfg.atlasUV
	-- Layout: 4+4+4+4+4 + 1 + 4 = 25 floats. Plus 4 instData = 29.
	instCacheTable[1]  = lx
	instCacheTable[2]  = ly
	instCacheTable[3]  = lz
	instCacheTable[4]  = cfg.size
	instCacheTable[5]  = nx
	instCacheTable[6]  = ny
	instCacheTable[7]  = nz
	instCacheTable[8]  = roll
	instCacheTable[9]  = r
	instCacheTable[10] = g
	instCacheTable[11] = b
	instCacheTable[12] = cfg.a
	instCacheTable[13] = now
	instCacheTable[14] = cfg.lifetime
	instCacheTable[15] = cfg.fadeIn
	instCacheTable[16] = 0
	instCacheTable[17] = uv[1]
	instCacheTable[18] = uv[2]
	instCacheTable[19] = uv[3]
	instCacheTable[20] = uv[4]
	instCacheTable[21] = pieceIndex
	-- instData filled by InstanceDataFromUnitIDs
	instCacheTable[22] = 0
	instCacheTable[23] = 0
	instCacheTable[24] = 0
	instCacheTable[25] = 0

	local vbo = getVBOForTexture(cfg.texture)
	pushElementInstance(vbo, instCacheTable, instanceID, true, false, unitID)

	-- Schedule removal
	local deathFrame = now + cfg.lifetime + 1
	local q = removeQueue[deathFrame]
	if not q then q = {}; removeQueue[deathFrame] = q end
	q[#q + 1] = { vbo, instanceID }

	lastSpawnFrame[kind][unitID] = now
	stats.spawned = stats.spawned + 1
end

local function UnitHitDecalTextured(unitID, unitDefID, weaponDefID, attackerID, damage,
                                    hx, hy, hz, vx, vy, vz, hitPiece)
	stats.hitsReceived = stats.hitsReceived + 1
	if not unitEligible[unitDefID] then stats.rejected = stats.rejected + 1; return end
	local kind = weaponDecalKind[weaponDefID]
	if not kind then stats.rejected = stats.rejected + 1; return end
	if not decalShader then stats.rejected = stats.rejected + 1; return end

	-- Piece selection
	local pieceIndex
	-- Use directional picker (engine's GetUnitLastAttackedPiece is unreliable
	-- — reports wrong pieces consistently for many units).
	if hx then
		pieceIndex = pickBestPiece(unitID, unitDefID, hx, hy, hz)
	end
	-- Last-resort: engine's pick if directional picker found nothing.
	if not pieceIndex and hitPiece and hitPiece > 0 then
		local cache = getPieceCache(unitID, unitDefID)
		if cache and cache[hitPiece] and not cache[hitPiece].empty then
			pieceIndex = hitPiece
		end
	end
	if debugRemainingHits > 0 then debugRemainingHits = debugRemainingHits - 1 end
	if not pieceIndex then stats.rejected = stats.rejected + 1; return end

	local cache = pieceCache[unitDefID]
	local p = cache and cache[pieceIndex]
	if not p then stats.rejected = stats.rejected + 1; return end

	-- SPHERICAL PROJECTION on the chosen piece's bounding sphere.
	-- The sphere is centered at the piece's AABB center (in piece-local) with
	-- radius = piece.radius. We project the world impact onto that sphere's surface.
	--
	-- Math (theory B: GetUnitPiecePosition returns unit-local pre-rotation):
	--   sphere_center_world = unit_pos + R_unit * (T_piece + R_piece * AABB_center)
	--   world_dir = normalize(impact - sphere_center_world)
	--   piece_local_dir = R_piece^T * R_unit^T * world_dir  (rotates direction into piece frame)
	--   decal_position_piece_local = AABB_center + piece_local_dir * radius
	--   decal_normal_piece_local = piece_local_dir
	--
	-- The engine then renders at: M_unit * M_piece * decal_position
	-- = piece_world_pos + R_unit * R_piece * (AABB_center + dir_local * radius)
	-- = sphere_center_world + (R_unit * R_piece * dir_local) * radius
	-- = sphere_center_world + world_dir * radius     (since R_unit*R_piece*dir_local = world_dir)
	-- → exactly on the sphere surface, in the world direction of the impact.

	local posX, posY, posZ = p.cx, p.cy, p.cz
	local nx, ny, nz = 0, 1, 0

	if hx then
		local ux, uy, uz = spGetUnitPosition(unitID)
		local u11,u12,u13,_, u21,u22,u23,_, u31,u32,u33,_, _,_,_,_ = spGetUnitTransformMatrix(unitID)
		local p11,p12,p13,_, p21,p22,p23,_, p31,p32,p33,_, pT1,pT2,pT3,_ = spGetUnitPieceMatrix(unitID, pieceIndex)
		if ux and u11 and p11 then
			-- AABB center in unit-local: T_piece + R_piece * (cx, cy, cz)
			local aclx = pT1 + (p11*p.cx + p21*p.cy + p31*p.cz)
			local acly = pT2 + (p12*p.cx + p22*p.cy + p32*p.cz)
			local aclz = pT3 + (p13*p.cx + p23*p.cy + p33*p.cz)
			-- AABB center in world: unit_pos + R_unit * unit_local_center
			local acwx = ux + u11*aclx + u21*acly + u31*aclz
			local acwy = uy + u12*aclx + u22*acly + u32*aclz
			local acwz = uz + u13*aclx + u23*acly + u33*aclz

			-- World direction from sphere center to impact
			local wdx, wdy, wdz = hx - acwx, hy - acwy, hz - acwz
			local wlen = mathSqrt(wdx*wdx + wdy*wdy + wdz*wdz)
			if wlen > 0.01 then
				wdx, wdy, wdz = wdx/wlen, wdy/wlen, wdz/wlen

				-- Convert world direction → unit-local via R_unit^T
				local udx = u11*wdx + u12*wdy + u13*wdz
				local udy = u21*wdx + u22*wdy + u23*wdz
				local udz = u31*wdx + u32*wdy + u33*wdz

				-- Convert unit-local direction → piece-local via R_piece^T
				nx = p11*udx + p12*udy + p13*udz
				ny = p21*udx + p22*udy + p23*udz
				nz = p31*udx + p32*udy + p33*udz

				-- Decal position on the piece's sphere surface (piece-local).
				local r = p.radius
				posX = p.cx + nx * r
				posY = p.cy + ny * r
				posZ = p.cz + nz * r
			end
		end
	end

	spawnDecal(unitID, unitDefID, pieceIndex, posX, posY, posZ, nx, ny, nz, kind, weaponDefID)
end

------------------------------------------------------------------------------
-- LIFETIME
------------------------------------------------------------------------------

function widget:GameFrame(n)
	local q = removeQueue[n]
	if not q then return end
	for i = 1, #q do
		local entry = q[i]
		local vbo, id = entry[1], entry[2]
		if vbo and vbo.instanceIDtoIndex[id] then
			popElementInstance(vbo, id)
		end
	end
	removeQueue[n] = nil
end

------------------------------------------------------------------------------
-- DRAW
------------------------------------------------------------------------------

local function drawAll()
	local hasAny = false
	for _, vbo in pairs(decalVBOByTexture) do
		if vbo.usedElements > 0 then hasAny = true; break end
	end
	if not hasAny then return end

	glCulling(false)
	glDepthTest(false)   -- DEBUG: see decals through walls
	glDepthMask(false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	decalShader:Activate()
	decalShader:SetUniform("currentFrame", spGetGameFrame())
	decalShader:SetUniformInt("reflectionPass", 0)

	for _, vbo in pairs(decalVBOByTexture) do
		if vbo.usedElements > 0 then
			glTexture(0, vbo.texture)
			drawInstanceVBO(vbo)
		end
	end

	decalShader:Deactivate()
	glTexture(0, false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
end

function widget:DrawWorld()
	if decalShader then drawAll() end
end

------------------------------------------------------------------------------
-- LIFECYCLE
------------------------------------------------------------------------------

-- shadersourcecache structure used by LuaShader.CheckShaderUpdates. This API
-- (vs the LuaShader{} constructor) substitutes engine placeholders like
-- //__ENGINEUNIFORMBUFFERDEFS__ and //__DEFINES__ before compiling, which is
-- how UnitPieces[], cameraViewProj, mat4mix(), and uni[] become defined.
local shaderSourceCache = {
	vsSrc = vsSrc,
	fsSrc = fsSrc,
	shaderName = "UnitHitDecalsTextured GL4",
	uniformInt   = { atlasTex = 0 },
	uniformFloat = { currentFrame = 0 },
	shaderConfig = {
		USEQUATERNIONS = (Engine.FeatureSupport and Engine.FeatureSupport.transformsInGL4) and "1" or "0",
	},
	forceupdate = true,
}

local function initShader()
	decalShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	if not decalShader then
		Spring.Echo("[UnitHitDecals Textured] Shader compile FAILED — see infolog above")
		return false
	end
	return true
end

function widget:Initialize()
	if not gl.InstanceVBOTable then
		Spring.Echo("[UnitHitDecals Textured] gl.InstanceVBOTable missing — disabling")
		widgetHandler:RemoveWidget()
		return
	end
	if not initShader() then
		widgetHandler:RemoveWidget()
		return
	end
	buildLookups()
	widgetHandler:RegisterGlobal("UnitHitDecalTextured", UnitHitDecalTextured)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("UnitHitDecalTextured")
	if decalShader then decalShader:Finalize() end
	for _, vbo in pairs(decalVBOByTexture) do
		if vbo.VAO then vbo.VAO:Delete() end
	end
end

function widget:TextCommand(command)
	if command == "unithitdecalstextured stats" then
		local total = 0
		for _, vbo in pairs(decalVBOByTexture) do total = total + (vbo.usedElements or 0) end
		Spring.Echo(string.format(
			"[UnitHitDecals Textured] hits=%d rejected=%d spawned=%d active=%d",
			stats.hitsReceived, stats.rejected, stats.spawned, total))
		return true
	end
	if command == "unithitdecalstextured debug" then
		debugRemainingHits = 5
		Spring.Echo("[UnitHitDecals Textured] verbose: dumping piece scoring for next 5 hits")
		return true
	end
	return false
end
