local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map Blockout",
		desc = "Off-map background layers (blockout rings), drawn at any camera distance. Use WG.Blockout",
		author = "PtaQ",
		date = "2026-10-12",
		license = "GNU GPL, v2 or later",
		layer = -9997,
		enabled = true,
		depends = { "gl4" },
	}
end

-- A blockout is the theatre backdrop behind a map: up to three layers of large scenery
-- (near, middle, far ring), each a model from a feature def that carries
-- customparams.blockout, centred on the map at sea level. They are not map features:
-- nothing culls or fades them with distance, they never block or get selected, and
-- each layer can be turned and scaled freely. Drawn opaque with depth, so fog and other
-- screen-space passes cover them like the rest of the world; depth clamp keeps the far
-- ring from being cut by the camera's far plane.

local LuaShader = gl.LuaShader
local InstanceVBOIdTable = gl.InstanceVBOIdTable
-- Trees without the deferred featureDefID helpers fall back to the immediate element API.
local pushDefElement = InstanceVBOIdTable and InstanceVBOIdTable.pushDefElement
	or function(iT, inst, id, defID)
		InstanceVBOIdTable.pushElementInstance(iT, inst, id, true, nil, defID, "featureDefID")
	end
local popDefElement = InstanceVBOIdTable and InstanceVBOIdTable.popDefElement
	or function(iT, id)
		InstanceVBOIdTable.popElementInstance(iT, id)
	end
local flushDefElements = InstanceVBOIdTable and InstanceVBOIdTable.flushDefElements or function() end
local PreloadFeatureDefModel = Spring.PreloadFeatureDefModel
local Echo = Spring.Echo

local LAYER_COUNT = 3
local MIN_SCALE, MAX_SCALE = 0.25, 4
local INSTDATA_ATTRIB_ID = 8
local VBO_LAYOUT = {
	{ id = 6, name = "worldposyaw", size = 4 }, -- xyz = world position, w = yaw (radians)
	{ id = 7, name = "params", size = 4 }, -- x = uniform scale
	{ id = 8, name = "instData", type = GL.UNSIGNED_INT, size = 4 },
}
local shaderConfig = {
	USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
}

local vsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000
//__DEFINES__
layout (location = 0) in vec3 pos;
layout (location = 1) in vec3 normal;
layout (location = 2) in vec3 T;
layout (location = 3) in vec3 B;
layout (location = 4) in vec4 uv;
layout (location = 5) in uvec2 bonesInfo;
#define pieceIndex (bonesInfo.x & 0x000000FFu)
layout (location = 6) in vec4 worldposyaw;
layout (location = 7) in vec4 params;
layout (location = 8) in uvec4 instData;
//__ENGINEUNIFORMBUFFERDEFS__
#if USEQUATERNIONS == 0
	layout(std140, binding=0) buffer MatrixBuffer {
		mat4 mat[];
	};
#else
	//__QUATERNIONDEFS__
#endif

out vec2 v_uv;
out vec3 v_normal;
out vec3 v_tangent;
out vec3 v_bitangent;

void main() {
	uint baseIndex = instData.x;
	#if USEQUATERNIONS == 0
		mat4 pieceMatrix = mat[baseIndex + pieceIndex];
		vec4 localModelPos = pieceMatrix * vec4(pos, 1.0);
		mat3 pieceRot = mat3(pieceMatrix);
	#else
		Transform tx = GetStaticPieceModelTransform(baseIndex, pieceIndex);
		vec4 localModelPos = ApplyTransform(tx, vec4(pos, 1.0));
		mat3 pieceRot = mat3(1.0);
	#endif
	localModelPos.xyz *= params.x;

	// same yaw convention as gfx_DrawFeatureShape_GL4 (left-handed engine transforms)
	mat3 rot = rotation3dY(-worldposyaw.w) * pieceRot;
	vec3 worldPos = rot * localModelPos.xyz + worldposyaw.xyz;

	v_uv = uv.xy;
	v_normal = rot * normal;
	v_tangent = rot * T;
	v_bitangent = rot * B;
	gl_Position = cameraViewProj * vec4(worldPos, 1.0);
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform sampler2D normalTex;
uniform float hasNormalTex;
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
in vec2 v_uv;
in vec3 v_normal;
in vec3 v_tangent;
in vec3 v_bitangent;
out vec4 fragColor;
#line 25000
void main() {
	vec4 color = texture(tex1, v_uv);
	vec4 other = texture(tex2, v_uv);
	if (other.a < 0.5) discard; // CUS cut-out convention

	vec3 N = normalize(v_normal);
	if (hasNormalTex > 0.5) {
		vec3 tn = texture(normalTex, v_uv).xyz * 2.0 - 1.0;
		N = normalize(normalize(v_tangent) * tn.x + normalize(v_bitangent) * tn.y + N * tn.z);
	}
	float ndl = max(dot(N, normalize(sunDir.xyz)), 0.0);
	vec3 lit = color.rgb * (sunAmbientModel.rgb + sunDiffuseModel.rgb * ndl);
	lit += color.rgb * other.r; // emissive, as CUS: strength times albedo
	fragColor = vec4(lit, 1.0);
}
]]

local shader
local vertexVBO, indexVBO
-- Depth of the layers alone, for screen-space passes that only read the G-buffer depths (the
-- height fog): the backdrop is in neither, so without this the fog treats it as open sky.
local GL_DEPTH_COMPONENT24 = 0x81A6
local GL_R8 = 0x8229
local depth = { tex = nil, color = nil, fbo = nil, w = 0, h = 0, frame = -1 }
local tables = {} -- featureDefID -> instance table
local normalTexOf = {} -- featureDefID -> normal map path or false

---@type { def: string?, yaw: number, scale: number }[]
local layers = {}
for i = 1, LAYER_COUNT do
	layers[i] = { def = nil, yaw = 0, scale = 1 }
end
local catalog -- built on first use: { { name, label, defID }, ... }
-- one record = worldposyaw (4) + params (4) + instData (4, filled by the VBO table)
local instanceCache = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
local listeners = {}

local function buildCatalog()
	catalog = {}
	for defID, def in pairs(FeatureDefs) do
		local cp = def.customParams
		if cp and cp.blockout then
			catalog[#catalog + 1] = { name = def.name, label = cp.blockout_label or def.name, defID = defID }
		end
	end
	table.sort(catalog, function(a, b)
		return a.label < b.label
	end)
end

local function getTable(defID)
	local t = tables[defID]
	if t ~= nil then
		return t or nil
	end
	if PreloadFeatureDefModel then
		PreloadFeatureDefModel(defID)
	end
	local def = FeatureDefs[defID]
	local textures = def and def.model and def.model.textures
	if not (textures and textures.tex1 and textures.tex1 ~= "") then
		Echo("[Map Blockout] " .. tostring(def and def.name) .. " has no model textures")
		tables[defID] = false
		return nil
	end
	t = InstanceVBOIdTable.makeInstanceVBOTable(
		VBO_LAYOUT,
		4,
		"MapBlockoutVBO:" .. def.name,
		INSTDATA_ATTRIB_ID,
		"featureDefID"
	)
	if not t then
		tables[defID] = false
		return nil
	end
	t.VAO = InstanceVBOIdTable.makeVAOandAttach(vertexVBO, t.instanceVBO, indexVBO)
	t.defID = defID
	tables[defID] = t
	local nt = def.customParams and def.customParams.normaltex
	normalTexOf[defID] = (nt and VFS.FileExists(nt)) and nt or false
	return t
end

-- Rebuild every layer instance (three at most, so no partial updates).
local function refresh()
	for _, t in pairs(tables) do
		if t then
			for i = 1, LAYER_COUNT do
				if t.instanceIDtoIndex and t.instanceIDtoIndex[i] then
					popDefElement(t, i)
				end
			end
		end
	end
	if not vertexVBO then
		return
	end
	local cx, cz = Game.mapSizeX * 0.5, Game.mapSizeZ * 0.5
	for i = 1, LAYER_COUNT do
		local l = layers[i]
		local def = l.def and FeatureDefNames[l.def]
		local t = def and getTable(def.id)
		if t then
			instanceCache[1], instanceCache[2], instanceCache[3], instanceCache[4] = cx, 0, cz, math.rad(l.yaw)
			instanceCache[5], instanceCache[6], instanceCache[7], instanceCache[8] = l.scale, 0, 0, 0
			pushDefElement(t, instanceCache, i, def.id)
		end
	end
	for _, fn in pairs(listeners) do
		fn()
	end
end

local Blockout = {}

---@return { name: string, label: string, defID: integer }[] models usable as a layer
function Blockout.getCatalog()
	if not catalog then
		buildCatalog()
	end
	return catalog
end

---@param i integer layer 1..3
---@return { def: string?, yaw: number, scale: number }?
function Blockout.getLayer(i)
	local l = layers[i]
	return l and { def = l.def, yaw = l.yaw, scale = l.scale }
end

---Change one layer. Fields left nil keep their value; def = false clears the layer.
---@param i integer layer 1..3
---@param fields { def: string|false|nil, yaw: number?, scale: number? }
---@return boolean
function Blockout.setLayer(i, fields)
	local l = layers[i]
	if not l then
		return false
	end
	if fields.def == false or fields.def == "" then
		l.def = nil
	elseif fields.def then
		local fd = FeatureDefNames[fields.def]
		if not (fd and fd.customParams and fd.customParams.blockout) then
			return false
		end
		l.def = fields.def
	end
	if fields.yaw then
		l.yaw = ((tonumber(fields.yaw) or 0) % 360)
	end
	if fields.scale then
		l.scale = math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(fields.scale) or 1))
	end
	refresh()
	return true
end

---@return table state plain table for saving: { layers = { { def, yaw, scale }, ... } }
function Blockout.getState()
	local out = { layers = {} }
	for i = 1, LAYER_COUNT do
		local l = layers[i]
		out.layers[i] = { def = l.def or "", yaw = l.yaw, scale = l.scale }
	end
	return out
end

---@param state table? what getState returned; nil clears every layer
function Blockout.setState(state)
	local src = state and state.layers or {}
	for i = 1, LAYER_COUNT do
		local s = src[i] or {}
		local def = s.def
		local fd = def and def ~= "" and FeatureDefNames[def]
		layers[i] = {
			def = (fd and fd.customParams and fd.customParams.blockout) and def or nil,
			yaw = (tonumber(s.yaw) or 0) % 360,
			scale = math.max(MIN_SCALE, math.min(MAX_SCALE, tonumber(s.scale) or 1)),
		}
	end
	refresh()
end

---@param key any
---@param fn function? called after every change; nil removes
function Blockout.onChange(key, fn)
	listeners[key] = fn
end

---@return any? texture depth of the layers drawn this frame (screen sized), nil when none are drawn
function Blockout.getDepthTexture()
	if depth.tex and depth.frame == Spring.GetDrawFrame() then
		return depth.tex
	end
	return nil
end

local function releaseDepthTarget()
	if depth.fbo then
		gl.DeleteFBO(depth.fbo)
	end
	if depth.tex then
		gl.DeleteTexture(depth.tex)
	end
	if depth.color then
		gl.DeleteTexture(depth.color)
	end
	depth.fbo, depth.tex, depth.color, depth.w, depth.h = nil, nil, nil, 0, 0
end

local function ensureDepthTarget(w, h)
	if depth.fbo and depth.w == w and depth.h == h then
		return true
	end
	releaseDepthTarget()
	local opts = {
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
	}
	opts.format = GL_DEPTH_COMPONENT24
	depth.tex = gl.CreateTexture(w, h, opts)
	-- a colour attachment keeps the FBO complete on drivers that refuse depth-only targets
	opts.format = GL_R8
	depth.color = gl.CreateTexture(w, h, opts)
	if depth.tex and depth.color then
		depth.fbo = gl.CreateFBO({ color0 = depth.color, depth = depth.tex, drawbuffers = { 0x8CE0 } })
	end
	if not (depth.fbo and gl.IsValidFBO(depth.fbo)) then
		releaseDepthTarget()
		return false
	end
	depth.w, depth.h = w, h
	return true
end

function widget:Initialize()
	if not (LuaShader and InstanceVBOIdTable) then
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
	local vs = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
	vs = vs:gsub("//__QUATERNIONDEFS__", LuaShader.GetQuaternionDefs())
	vs = vs:gsub("//__DEFINES__", defines)
	local fs = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineDefs)
	fs = fs:gsub("//__DEFINES__", defines)
	shader = LuaShader({
		vertex = vs,
		fragment = fs,
		uniformInt = { tex1 = 0, tex2 = 1, normalTex = 2 },
		uniformFloat = { hasNormalTex = 0 },
	}, "Map Blockout")
	if shader:Initialize() ~= true then
		Echo("[Map Blockout] shader compilation failed")
		widgetHandler:RemoveWidget()
		return
	end
	WG.Blockout = Blockout
	refresh()
end

function widget:Shutdown()
	for _, t in pairs(tables) do
		if t then
			if t.VAO then
				t.VAO:Delete()
			end
			if t.instanceVBO then
				t.instanceVBO:Delete()
			end
			if WG.VBOTableRegistry then
				WG.VBOTableRegistry[t.myName] = nil
			end
		end
	end
	tables = {}
	if shader then
		shader:Finalize()
		shader = nil
	end
	vertexVBO, indexVBO = nil, nil
	releaseDepthTarget()
	if WG.Blockout == Blockout then
		WG.Blockout = nil
	end
end

local function submitLayers()
	for defID, t in pairs(tables) do
		if t and t.usedElements > 0 then
			local nt = normalTexOf[defID]
			shader:SetUniformFloat("hasNormalTex", nt and 1 or 0)
			if nt then
				gl.Texture(2, nt)
			end
			gl.FeatureShapeTextures(defID, true)
			t.VAO:Submit()
			gl.FeatureShapeTextures(defID, false)
			if nt then
				gl.Texture(2, false)
			end
		end
	end
end

function widget:DrawWorldPreUnit()
	local any = false
	for _, t in pairs(tables) do
		if t then
			flushDefElements(t)
			any = any or t.usedElements > 0
		end
	end
	if not any then
		return
	end
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	gl.DepthClamp(true)
	gl.Culling(false)
	shader:Activate()
	submitLayers()
	-- the same layers once more, into the depth target the fog reads
	local vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	if ensureDepthTarget(vsx, vsy) then
		gl.ActiveFBO(depth.fbo, function()
			gl.Viewport(0, 0, vsx, vsy)
			gl.Clear(GL.DEPTH_BUFFER_BIT, 1)
			submitLayers()
		end)
		gl.Viewport(vpx, vpy, vsx, vsy)
		depth.frame = Spring.GetDrawFrame()
	end
	shader:Deactivate()
	gl.DepthClamp(false)
	gl.DepthTest(false)
end
