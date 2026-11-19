local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Terrain Hole Layers",
		desc = "Holes that are not painted: under labelled features and cut while the game runs. Use WG.TerrainHoles",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -9996,
		enabled = true,
		depends = { "gl4" },
	}
end

-- Merges three layers into the terrain shader's one hole mask: painted (the brush mask, saved
-- alone), feature (where a customParams.terrainhole model reaches below the ground) and
-- runtime (cut and restored through WG.TerrainHoles while the game runs).

local LuaShader = gl.LuaShader
---@type table the widget depends on gl4, which provides it
local InstanceVBOIdTable = gl.InstanceVBOIdTable
local Echo = Spring.Echo
local floor, max, min = math.floor, math.max, math.min

-- one texel per heightmap vertex, as the painted mask
local MASK_W = floor(Game.mapSizeX / 8) + 1
local MASK_H = floor(Game.mapSizeZ / 8) + 1
local DEFAULT_DEPTH = 4
local POLL_FRAMES = 30
local INSTDATA_ATTRIB_ID = 8
local VBO_LAYOUT = {
	{ id = 6, name = "params", size = 4 }, -- x = how far below the ground a part must lie, y = scale
	{ id = 7, name = "base", size = 4 }, -- where the feature stands: the brush scales it about this
	{ id = 8, name = "instData", type = GL.UNSIGNED_INT, size = 4 },
}
local shaderConfig = {
	USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
}

local featVsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000
//__DEFINES__
layout (location = 0) in vec3 pos;
layout (location = 5) in uvec2 bonesInfo;
#define pieceIndex (bonesInfo.x & 0x000000FFu)
layout (location = 6) in vec4 params;
layout (location = 7) in vec4 base;
layout (location = 8) in uvec4 instData;
//__ENGINEUNIFORMBUFFERDEFS__
#if USEQUATERNIONS == 0
	layout(std140, binding=0) buffer MatrixBuffer {
		mat4 mat[];
	};
#else
	//__QUATERNIONDEFS__
#endif
uniform vec2 maskSize;
out vec3 v_world;
out float v_depth;

void main() {
	uint baseIndex = instData.x;
	// the feature as it stands: sunk, tilted and scaled ones included
	#if USEQUATERNIONS == 0
		v_world = (mat[baseIndex] * (mat[baseIndex + pieceIndex + 1u] * vec4(pos, 1.0))).xyz;
	#else
		Transform tx = GetPieceWorldTransform(baseIndex, pieceIndex);
		v_world = ApplyTransform(tx, vec4(pos, 1.0)).xyz;
	#endif
	v_world = base.xyz + (v_world - base.xyz) * params.y;
	v_depth = params.x;
	// straight down onto the mask: texel i is world 8i
	vec2 uv = (v_world.xz / 8.0 + 0.5) / maskSize;
	gl_Position = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
}
]]

local featFsSrc = [[
#version 420
#line 20000
uniform sampler2D heightTex;
uniform vec2 groundSize;
uniform float above;
in vec3 v_world;
in float v_depth;
out vec4 fragColor;
void main() {
	float ground = texture(heightTex, v_world.xz / groundSize).r;
	// red = the model below the ground, green = the model above it (colour masked per pass)
	if (above > 0.5) {
		if (v_world.y < ground + 1.0) discard;
	} else if (v_world.y > ground - v_depth) discard;
	fragColor = vec4(1.0);
}
]]

-- keeps a below-ground texel only where the visible model surrounds it, so a cut never
-- shows outside the feature
local ENCLOSE_FS = [[
#version 150 compatibility
uniform sampler2D raw;
uniform vec2 texel;
const int REACH = 24;
const vec2 DIRS[8] = vec2[8](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.7, 0.7), vec2(-0.7, 0.7), vec2(0.7, -0.7), vec2(-0.7, -0.7));
void main() {
	vec2 uv = gl_TexCoord[0].st;
	gl_FragColor = vec4(0.0);
	if (texture2D(raw, uv).r < 0.5) return;
	int closed = 0;
	for (int d = 0; d < 8; d++) {
		for (int s = 1; s <= REACH; s++) {
			if (texture2D(raw, uv + DIRS[d] * texel * float(s)).g > 0.5) {
				closed++;
				break;
			}
		}
	}
	// one open side is let through: a notch in the rim
	// red = hole, green 0 = units are not blocked by it, blue = hard edge
	if (closed >= 7) gl_FragColor = vec4(1.0, 0.0, 1.0, 1.0);
}
]]

local QUAD_VS = [[
#version 150 compatibility
void main() {
	gl_TexCoord[0] = gl_MultiTexCoord0;
	gl_Position = gl_Vertex;
}
]]

-- the three layers, strongest wins per channel
local MERGE_FS = [[
#version 150 compatibility
uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform vec3 has;
void main() {
	vec2 uv = gl_TexCoord[0].st;
	vec4 v = vec4(0.0);
	if (has.x > 0.5) v = max(v, texture2D(tex0, uv));
	if (has.y > 0.5) v = max(v, texture2D(tex1, uv));
	if (has.z > 0.5) v = max(v, texture2D(tex2, uv));
	gl_FragColor = vec4(v.rgb, 1.0);
}
]]

-- a disc written over what is there: value 1 cuts, 0 restores
local DISC_FS = [[
#version 150 compatibility
uniform vec3 disc;   // centre and radius, in texels
uniform float value;
void main() {
	if (distance(gl_FragCoord.xy, disc.xy) > disc.z) discard;
	gl_FragColor = vec4(value, value, value, 1.0);
}
]]

---@type LuaShader?
local featShader
local mergeShader, discShader, encloseShader
local vertexVBO, indexVBO
local featTable -- one instance per labelled feature
local labels = {} -- featureDefID -> depth, or false
local featTex, runtimeTex, mergedTex
local rawTex -- the labelled models from above: red below the ground, green above it
local featCount = 0
local runtimeCount = 0
local featDirty = true
local mergeDirty = true
local paintedTex -- what the painter last handed to the terrain shader
local ours = false -- the terrain shader holds mergedTex
local lastKey = ""
local pollIn = 0
local wasPainting = false
local queue = {}
local cuts = {} -- the runtime cuts still open
---@type number[]
local instanceCache = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

local function labelOf(defID)
	local d = labels[defID]
	if d == nil then
		local cp = FeatureDefs[defID] and FeatureDefs[defID].customParams
		d = false
		if cp and cp.terrainhole and cp.terrainhole ~= "0" then
			d = tonumber(cp.terrainhole_depth) or DEFAULT_DEPTH
		end
		labels[defID] = d
	end
	return d
end

local function makeTex()
	return gl.CreateTexture(MASK_W, MASK_H, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		format = GL.RGBA8,
	})
end

local function clearTex(tex)
	gl.RenderToTexture(tex, function()
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
	end)
end

-- the labelled features on the map, as one string: any change redraws the layer
local function scan()
	local list, parts = {}, {}
	for _, fid in ipairs(Spring.GetAllFeatures()) do
		local defID = Spring.GetFeatureDefID(fid)
		local depth = defID and labelOf(defID)
		if depth then
			local x, y, z = Spring.GetFeaturePosition(fid)
			local pitch, yaw, roll = Spring.GetFeatureRotation(fid)
			local scale = Spring.GetFeatureRulesParam(fid, "visualScale") or 1
			list[#list + 1] = { fid = fid, depth = depth, scale = scale, x = x, y = y, z = z }
			parts[#parts + 1] = string.format(
				"%d:%d:%.1f:%.1f:%.1f:%.3f:%.3f:%.3f:%.1f:%.3f",
				fid,
				defID,
				x,
				y,
				z,
				pitch or 0,
				yaw or 0,
				roll or 0,
				depth,
				scale
			)
		end
	end
	return list, table.concat(parts, "|")
end

local function drawFeatures(list)
	InstanceVBOIdTable.clearInstanceTable(featTable)
	featCount = 0
	for _, f in ipairs(list) do
		instanceCache[1], instanceCache[2] = f.depth, f.scale
		instanceCache[5], instanceCache[6], instanceCache[7] = f.x, f.y, f.z
		if InstanceVBOIdTable.pushElementInstance(featTable, instanceCache, f.fid, true, nil, f.fid, "featureID") then
			featCount = featCount + 1
		end
	end
	if featCount == 0 then
		if featTex then
			clearTex(featTex)
		end
		return
	end
	featTex = featTex or makeTex()
	rawTex = rawTex or makeTex()
	if not (featTex and rawTex and featShader) then
		featCount = 0
		return
	end
	gl.RenderToTexture(rawTex, function()
		gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
		gl.DepthTest(false)
		gl.Culling(false)
		gl.Blending(false)
		gl.Texture(0, "$heightmap")
		featShader:Activate()
		featShader:SetUniformFloat("maskSize", MASK_W, MASK_H)
		featShader:SetUniformFloat("groundSize", Game.mapSizeX, Game.mapSizeZ)
		gl.ColorMask(true, false, false, false)
		featShader:SetUniformFloat("above", 0)
		featTable.VAO:Submit()
		gl.ColorMask(false, true, false, false)
		featShader:SetUniformFloat("above", 1)
		featTable.VAO:Submit()
		gl.ColorMask(true, true, true, true)
		featShader:Deactivate()
		gl.Texture(0, false)
		gl.Blending(true)
	end)
	gl.RenderToTexture(featTex, function()
		gl.Blending(false)
		gl.UseShader(encloseShader)
		gl.Uniform(gl.GetUniformLocation(encloseShader, "texel"), 1 / MASK_W, 1 / MASK_H)
		gl.Texture(0, rawTex)
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		gl.Texture(0, false)
		gl.UseShader(0)
		gl.Blending(true)
	end)
end

local function runQueue()
	if #queue == 0 then
		return
	end
	runtimeTex = runtimeTex or makeTex()
	if not runtimeTex then
		queue = {}
		return
	end
	if runtimeCount == 0 then
		clearTex(runtimeTex)
	end
	gl.RenderToTexture(runtimeTex, function()
		gl.Blending(false)
		gl.UseShader(discShader)
		local uDisc = gl.GetUniformLocation(discShader, "disc")
		local uValue = gl.GetUniformLocation(discShader, "value")
		for _, op in ipairs(queue) do
			if op.clear then
				cuts = {}
			elseif op.restore then
				-- a cut that lies whole inside the restored disc is closed
				local open = {}
				for _, c in ipairs(cuts) do
					local dx, dz = c.x - op.x, c.z - op.z
					if math.sqrt(dx * dx + dz * dz) + c.r > op.r + 0.01 then
						open[#open + 1] = c
					end
				end
				cuts = open
			else
				cuts[#cuts + 1] = op
			end
			if #cuts == 0 then
				gl.UseShader(0)
				gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
				gl.UseShader(discShader)
			else
				gl.Uniform(uDisc, op.x / 8 + 0.5, op.z / 8 + 0.5, op.r / 8)
				gl.Uniform(uValue, op.restore and 0 or 1)
				gl.TexRect(-1, -1, 1, 1)
			end
		end
		runtimeCount = #cuts
		gl.UseShader(0)
		gl.Blending(true)
	end)
	queue = {}
	mergeDirty = true
end

local function merge()
	mergedTex = mergedTex or makeTex()
	if not mergedTex then
		return false
	end
	local painted = paintedTex and gl.TextureInfo(paintedTex) and paintedTex or nil
	gl.RenderToTexture(mergedTex, function()
		gl.Blending(false)
		gl.UseShader(mergeShader)
		gl.Uniform(
			gl.GetUniformLocation(mergeShader, "has"),
			painted and 1 or 0,
			featCount > 0 and 1 or 0,
			runtimeCount > 0 and 1 or 0
		)
		if painted then
			gl.Texture(0, painted)
		end
		if featCount > 0 then
			gl.Texture(1, featTex)
		end
		if runtimeCount > 0 then
			gl.Texture(2, runtimeTex)
		end
		gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
		gl.Texture(0, false)
		gl.Texture(1, false)
		gl.Texture(2, false)
		gl.UseShader(0)
		gl.Blending(true)
	end)
	return true
end

local TerrainHoles = {}

---Cut a disc out of the ground while the game runs. Looks only: units are blocked by
---the Terraform Holes gadget, which calls this for its own runtime cuts.
---@param x number
---@param z number
---@param radius number
function TerrainHoles.cut(x, z, radius)
	queue[#queue + 1] = { x = x, z = z, r = radius }
end

---Put the ground back inside a disc (runtime cuts only, not painted or feature holes).
function TerrainHoles.restore(x, z, radius)
	queue[#queue + 1] = { x = x, z = z, r = radius, restore = true }
end

function TerrainHoles.clearRuntime()
	queue[#queue + 1] = { clear = true }
end

---Label a feature def from code, as customParams.terrainhole does.
---@param defName string
---@param depth number|false how far below the ground a part must lie to cut; false removes the label
function TerrainHoles.labelDef(defName, depth)
	local def = FeatureDefNames[defName]
	if not def then
		return false
	end
	labels[def.id] = depth and (tonumber(depth) or DEFAULT_DEPTH) or false
	pollIn = 0
	return true
end

---@return { features: integer, runtime: integer, merged: boolean }
function TerrainHoles.getState()
	return { features = featCount, runtime = runtimeCount, merged = ours }
end

---@return any? texture the labelled models from above: red below the ground, green above it
function TerrainHoles.getRawMask()
	return featCount > 0 and rawTex or nil
end

---@return any? texture the feature layer alone, nil when no labelled feature cuts
function TerrainHoles.getFeatureMask()
	return featCount > 0 and featTex or nil
end

-- /terrainhole [off] [defName] [depth]: no def name = the feature under the mouse
function widget:TextCommand(command)
	local args = {}
	for word in command:gmatch("%S+") do
		args[#args + 1] = word
	end
	if args[1] ~= "terrainhole" then
		return false
	end
	local off = args[2] == "off"
	local name = args[off and 3 or 2]
	local depth = not off and (tonumber(args[3]) or DEFAULT_DEPTH)
	if tonumber(name) then
		depth, name = tonumber(name), nil
	end
	if not name then
		local mx, my = Spring.GetMouseState()
		local kind, id = Spring.TraceScreenRay(mx, my)
		local def = kind == "feature" and FeatureDefs[Spring.GetFeatureDefID(id)]
		name = def and def.name
	end
	if name and TerrainHoles.labelDef(name, depth) then
		Echo("[Terrain Hole Layers] " .. name .. (off and ": label off" or ": cuts the ground, depth " .. depth))
	else
		Echo("[Terrain Hole Layers] no such feature def: point at a feature or give a def name")
	end
	return true
end

function widget:Initialize()
	if not (LuaShader and InstanceVBOIdTable and gl.CreateShader) then
		widgetHandler:RemoveWidget()
		return
	end
	vertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not (vertexVBO and indexVBO) then
		widgetHandler:RemoveWidget()
		return
	end
	vertexVBO:ModelsVBO()
	indexVBO:ModelsVBO()

	local engineDefs = LuaShader.GetEngineUniformBufferDefs()
	local defines = LuaShader.CreateShaderDefinesString(shaderConfig)
	local vs = featVsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
	vs = vs:gsub("//__QUATERNIONDEFS__", LuaShader.GetQuaternionDefs())
	vs = vs:gsub("//__DEFINES__", defines)
	featShader = LuaShader({
		vertex = vs,
		fragment = featFsSrc,
		uniformInt = { heightTex = 0 },
		uniformFloat = { maskSize = { MASK_W, MASK_H }, groundSize = { Game.mapSizeX, Game.mapSizeZ }, above = 0 },
	}, "Terrain Hole Layers")
	mergeShader =
		gl.CreateShader({ vertex = QUAD_VS, fragment = MERGE_FS, uniformInt = { tex0 = 0, tex1 = 1, tex2 = 2 } })
	discShader = gl.CreateShader({ vertex = QUAD_VS, fragment = DISC_FS })
	encloseShader = gl.CreateShader({ vertex = QUAD_VS, fragment = ENCLOSE_FS, uniformInt = { raw = 0 } })
	if featShader:Initialize() ~= true or not mergeShader or not discShader or not encloseShader then
		Echo("[Terrain Hole Layers] shader compilation failed: " .. tostring(gl.GetShaderLog()))
		widgetHandler:RemoveWidget()
		return
	end
	featTable =
		InstanceVBOIdTable.makeInstanceVBOTable(VBO_LAYOUT, 64, "TerrainHolesVBO", INSTDATA_ATTRIB_ID, "featureID")
	if not featTable then
		widgetHandler:RemoveWidget()
		return
	end
	featTable.VAO = InstanceVBOIdTable.makeVAOandAttach(vertexVBO, featTable.instanceVBO, indexVBO)
	WG.TerrainHoles = TerrainHoles
	-- runtime cuts ordered by the game arrive here
	widgetHandler:RegisterGlobal("TerrainHoleRuntime", function(op, x, z, radius)
		if op == "cut" then
			TerrainHoles.cut(x, z, radius)
		elseif op == "restore" then
			TerrainHoles.restore(x, z, radius)
		elseif op == "clear" then
			TerrainHoles.clearRuntime()
		end
	end)
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("TerrainHoleRuntime")
	local T = WG.TilesetTerrain
	if ours and T and T.setHoleMask and T.getHoleMask() == mergedTex then
		T.setHoleMask(paintedTex)
	end
	if featTable then
		if featTable.VAO then
			featTable.VAO:Delete()
		end
		if featTable.instanceVBO then
			featTable.instanceVBO:Delete()
		end
		if WG.VBOTableRegistry then
			WG.VBOTableRegistry[featTable.myName] = nil
		end
		featTable = nil
	end
	if featShader then
		featShader:Finalize()
		featShader = nil
	end
	if mergeShader then
		gl.DeleteShader(mergeShader)
	end
	if discShader then
		gl.DeleteShader(discShader)
	end
	if encloseShader then
		gl.DeleteShader(encloseShader)
	end
	for _, tex in pairs({ featTex, rawTex, runtimeTex, mergedTex }) do
		gl.DeleteTexture(tex)
	end
	if WG.TerrainHoles == TerrainHoles then
		WG.TerrainHoles = nil
	end
end

function widget:FeatureCreated()
	pollIn = 0
end

function widget:FeatureDestroyed()
	-- the feature is still listed during this callin
	pollIn = 1
end

function widget:DrawGenesis()
	local T = WG.TilesetTerrain
	if not (T and T.setHoleMask and T.getHoleMask) then
		return
	end
	local cur = T.getHoleMask()
	if cur ~= mergedTex then
		-- the painter handed over a new mask (or none)
		if cur ~= paintedTex then
			paintedTex = cur
			mergeDirty = true
		end
		ours = false
	end

	pollIn = pollIn - 1
	if pollIn <= 0 then
		pollIn = POLL_FRAMES
		local list, key = scan()
		if key ~= lastKey or featDirty then
			lastKey = key
			featDirty = false
			drawFeatures(list)
			mergeDirty = true
		end
	end
	runQueue()

	if featCount == 0 and runtimeCount == 0 then
		-- nothing of ours: the painted mask goes to the shader alone
		if ours then
			T.setHoleMask(paintedTex)
			ours = false
		end
		return
	end
	-- a stroke changes the painted mask in place
	local SP = WG.SurfacePainter
	local painting = SP and SP.getState and SP.getState().holeMode or false
	local push = not ours or (wasPainting and not painting)
	wasPainting = painting
	if mergeDirty or painting then
		if not merge() then
			return
		end
		-- handing it over again redraws the minimap; not on every frame of a stroke
		push = push or (mergeDirty and not painting)
		mergeDirty = false
	end
	if push then
		T.setHoleMask(mergedTex)
		ours = true
	end
end
