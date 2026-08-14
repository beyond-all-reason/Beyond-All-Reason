local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "DrawFeatureShape GL4",
		desc = "Instanced feature ghosts at arbitrary transforms. Use WG.DrawFeatureShapeGL4",
		author = "PtaQ",
		date = "July 2026",
		license = "GNU GPL, v2 or later",
		layer = -9998,
		enabled = false,
		depends = { "gl4" },
	}
end

-- The feature counterpart of gfx_DrawUnitShape_GL4.lua, which this is modelled on.
-- Differences that matter:
--
--   * Unit ghosts bucket into four fixed VBO tables because BAR units share four
--     texture atlases. Features have one texture pair per model, so buckets are
--     keyed by that pair and created lazily -- there are ~1000 feature defs and
--     a preallocated table per def would be absurd.
--   * Instances carry full euler rotation, not just a heading, because the
--     feature gizmo can pitch and roll what it places.
--   * Drawn in DrawWorld rather than DrawWorldPreUnit: these are translucent and
--     must sort behind terrain and units that are already on screen. That also
--     keeps us out of the ghost-stencil contract gfx_DrawUnitShape_GL4 has with
--     the nano particles gadget.

local LuaShader = gl.LuaShader
local InstanceVBOIdTable = gl.InstanceVBOIdTable

local pushElementInstance = InstanceVBOIdTable.pushElementInstance
local popElementInstance = InstanceVBOIdTable.popElementInstance

local Echo = Spring.Echo
local PreloadFeatureDefModel = Spring.PreloadFeatureDefModel

local INSTDATA_ATTRIB_ID = 10
local INSTANCE_STEP = 20

local VBO_LAYOUT = {
	{ id = 6, name = "worldposyaw", size = 4 }, -- xyz = world position, w = yaw (radians)
	{ id = 7, name = "pitchroll", size = 4 }, -- x = pitch, y = roll, zw reserved
	{ id = 8, name = "parameters", size = 4 }, -- x = alpha, y = tint amount, z = highlight, w reserved
	{ id = 9, name = "tintcolor", size = 4 }, -- rgb = tint target, a reserved
	{ id = 10, name = "instData", type = GL.UNSIGNED_INT, size = 4 },
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

layout (location = 5) in uvec2 bonesInfo; // boneIDs, boneWeights
#define pieceIndex (bonesInfo.x & 0x000000FFu)

layout (location = 6) in vec4 worldposyaw;
layout (location = 7) in vec4 pitchroll;
layout (location = 8) in vec4 parameters;
layout (location = 9) in vec4 tintcolor;
layout (location = 10) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__

#line 15000

#if USEQUATERNIONS == 0
	layout(std140, binding=0) buffer MatrixBuffer {
		mat4 mat[];
	};
#else
	//__QUATERNIONDEFS__
#endif

out vec2 v_uv;
out vec4 v_parameters;
out vec4 v_tint;
out vec4 v_teamColor;

void main() {
	uint baseIndex = instData.x;

	// featureDefID instances are always static models, so unlike the unit-shape
	// shader there is no leading world matrix to skip.
	#if USEQUATERNIONS == 0
		mat4 pieceMatrix = mat[baseIndex + pieceIndex];
		vec4 localModelPos = pieceMatrix * vec4(pos, 1.0);
	#else
		Transform tx = GetStaticPieceModelTransform(baseIndex, pieceIndex);
		vec4 localModelPos = ApplyTransform(tx, vec4(pos, 1.0));
	#endif

	// Match Spring.SetFeatureRotation exactly, or the ghost does not line up with
	// the feature it previews.
	//
	// SetDirVectorsEuler feeds the angles to CMatrix44f::RotateEulerXYZ. Those
	// Rotate* methods RIGHT-multiply (verified against the index algebra in
	// System/Matrix44f.cpp), so starting from identity the composition really is
	// Rx(pitch) * Ry(yaw) * Rz(roll) -- the "R=R(Z)*R(Y)*R(X)" comment above
	// RotateEulerXYZ describes a row-vector convention and does not match the code.
	//
	// The angles are NEGATED because Recoil's object transforms are left-handed
	// while the rotation3d* helpers in the engine uniform prelude are the
	// right-handed form: rotation3dA(t) == R_engine_A(-t) on all three axes.
	// Miss this and each axis spins backwards.
	mat3 rot = rotation3dX(-pitchroll.x) * rotation3dY(-worldposyaw.w) * rotation3dZ(-pitchroll.y);
	vec3 worldModelPos = rot * localModelPos.xyz + worldposyaw.xyz;

	uint teamIndex = (instData.z & 0x000000FFu);
	v_teamColor = teamColor[teamIndex];

	v_uv = uv.xy;
	v_parameters = parameters;
	v_tint = tintcolor;
	gl_Position = cameraViewProj * vec4(worldModelPos, 1.0);
}
]]

local fsSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 20000

uniform sampler2D tex1;
uniform sampler2D tex2;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

in vec2 v_uv;
in vec4 v_parameters;
in vec4 v_tint;
in vec4 v_teamColor;

out vec4 fragColor;
#line 25000
void main() {
	vec4 modelColor = texture(tex1, v_uv.xy);
	vec4 extraColor = texture(tex2, v_uv.xy);

	// BAR's own model shader (modelmaterials_gl4/templates/cus_gl4.frag.glsl)
	// treats tex2.a as the alpha-cutout mask and tex1.a as the teamcolor mask.
	// Honour the cutout so tree foliage stays leaf-shaped instead of rendering
	// as solid cards, then let the caller own the ghost's overall alpha.
	if (extraColor.a < 0.5) discard;

	vec3 albedo = mix(modelColor.rgb, v_teamColor.rgb, modelColor.a);
	albedo += albedo * extraColor.r; // emission

	albedo = mix(albedo, v_tint.rgb, v_parameters.y);
	albedo = mix(albedo, vec3(1.0), v_parameters.z);

	fragColor = vec4(albedo, v_parameters.x);
}
]]

local featureShapeShader
local vertexVBO, indexVBO

local texKeyToBucket = {} -- "tex1|tex2" -> instance table
local buckets = {} -- array of the above, for iteration
local featureDefIDToBucket = {} -- featureDefID -> instance table
local unsupportedDefIDs = {} -- featureDefIDs with no usable model, warned about once
local uniqueIDToBucket = {}
local owners = {} -- uniqueID -> ownerID

local uniqueID = 0

local instanceCache = {}
for i = 1, INSTANCE_STEP do
	instanceCache[i] = 0
end

local function getBucket(featureDefID)
	local bucket = featureDefIDToBucket[featureDefID]
	if bucket then
		return bucket
	end

	if unsupportedDefIDs[featureDefID] then
		return nil
	end

	local featureDef = FeatureDefs[featureDefID]
	if not featureDef then
		unsupportedDefIDs[featureDefID] = true
		Echo("[DrawFeatureShape GL4] No such featureDefID: " .. tostring(featureDefID))
		return nil
	end

	-- Reading .model loads the model if it is not resident yet; preload first so
	-- the cost is explicit rather than hidden behind a table index.
	if PreloadFeatureDefModel then
		PreloadFeatureDefModel(featureDefID)
	end

	local model = featureDef.model
	local textures = model and model.textures
	local tex1 = textures and textures.tex1
	local tex2 = textures and textures.tex2
	if not tex1 or tex1 == "" then
		-- DRAWTYPE_NONE, or an engine-drawn tree with no S3O/OBJ behind it.
		unsupportedDefIDs[featureDefID] = true
		Echo("[DrawFeatureShape GL4] " .. tostring(featureDef.name) .. " has no model textures, cannot ghost it")
		return nil
	end

	local key = tex1:lower() .. "|" .. tostring(tex2 and tex2:lower())
	bucket = texKeyToBucket[key]
	if not bucket then
		bucket = InstanceVBOIdTable.makeInstanceVBOTable(
			VBO_LAYOUT,
			32,
			"DrawFeatureShapeVBO:" .. key,
			INSTDATA_ATTRIB_ID,
			"featureDefID"
		)
		if not bucket then
			unsupportedDefIDs[featureDefID] = true
			Echo("[DrawFeatureShape GL4] Failed to create an instance table for " .. key)
			return nil
		end
		bucket.vertexVBO = vertexVBO
		bucket.indexVBO = indexVBO
		bucket.VAO = InstanceVBOIdTable.makeVAOandAttach(vertexVBO, bucket.instanceVBO, indexVBO)
		-- Every def in this bucket shares a texture pair, so binding any one of
		-- them binds the right pair for all. Same trick as
		-- gfx_DrawUnitShape_GL4's UnitShapeTexturesUnitDefID.
		bucket.textureFeatureDefID = featureDefID
		texKeyToBucket[key] = bucket
		buckets[#buckets + 1] = bucket
	end

	featureDefIDToBucket[featureDefID] = bucket
	return bucket
end

---Draw a translucent copy of a feature model anywhere, at any orientation.
---Callers own the lifetime of everything they submit: pair every call that
---creates a ghost with StopDrawFeatureShapeGL4, or batch-remove with
---StopDrawFeatureShapesGL4(ownerID).
---@param featureDefID number which featureDef to draw
---@param px number world position
---@param py number world position
---@param pz number world position
---@param yaw number optional rotation around Y in radians, matching Spring.SetFeatureRotation's yaw
---@param pitch number optional rotation around X in radians
---@param roll number optional rotation around Z in radians
---@param alpha number optional opacity, default 0.55
---@param tintR number optional tint target colour
---@param tintG number optional tint target colour
---@param tintB number optional tint target colour
---@param tintAmount number optional how much to blend the tint in [0-1], default 0
---@param updateID number optional a uniqueID returned earlier, to move that ghost instead of adding one
---@param ownerID any optional tag so a widget can batch-remove everything it submitted
---@return number|nil uniqueID pass to StopDrawFeatureShapeGL4 to stop drawing it
local function DrawFeatureShapeGL4(
	featureDefID,
	px,
	py,
	pz,
	yaw,
	pitch,
	roll,
	alpha,
	tintR,
	tintG,
	tintB,
	tintAmount,
	updateID,
	ownerID
)
	local bucket = getBucket(featureDefID)
	if not bucket then
		return nil
	end

	if updateID and uniqueIDToBucket[updateID] and uniqueIDToBucket[updateID] ~= bucket then
		-- The caller reused a handle for a different def whose textures live in
		-- another bucket. Drop the old instance or it leaks in the old table.
		local oldBucket = uniqueIDToBucket[updateID]
		if oldBucket.instanceIDtoIndex[updateID] then
			popElementInstance(oldBucket, updateID)
			oldBucket.dirty = true
		end
	end

	if not updateID then
		uniqueID = uniqueID + 1
		updateID = uniqueID
	end

	if ownerID ~= nil then
		owners[updateID] = ownerID
	end

	instanceCache[1], instanceCache[2], instanceCache[3], instanceCache[4] = px, py, pz, yaw or 0
	instanceCache[5], instanceCache[6], instanceCache[7], instanceCache[8] = pitch or 0, roll or 0, 0, 0
	instanceCache[9], instanceCache[10], instanceCache[11], instanceCache[12] = alpha or 0.55, tintAmount or 0, 0, 0
	instanceCache[13], instanceCache[14], instanceCache[15], instanceCache[16] = tintR or 1, tintG or 1, tintB or 1, 1

	uniqueIDToBucket[updateID] = bucket

	-- Pushes are deferred (noUpload) and flushed once per bucket in DrawWorld:
	-- callers move whole fleets of ghosts every frame, and a per-instance Upload
	-- would be hundreds of GL calls a frame. Safe because pushElementInstance
	-- records indextoUnitID/indextoObjectType OUTSIDE its noUpload guard.
	--
	-- Pops deliberately do NOT defer. popElementInstance does its swap-with-last
	-- fixup of those same two tables INSIDE the guard, so a deferred pop leaves
	-- the def bookkeeping pointing at instances that have moved or gone -- and
	-- uploadAllElements then rebuilds the submission from that stale array,
	-- drawing phantom ghosts with the wrong models.
	pushElementInstance(bucket, instanceCache, updateID, true, true, featureDefID, "featureDefID")
	bucket.dirty = true

	return updateID
end

---@param handleID number a uniqueID returned by DrawFeatureShapeGL4
---@return any ownerID the owner the handle was registered under, if any
local function StopDrawFeatureShapeGL4(handleID)
	if handleID == nil then
		return nil
	end

	local bucket = uniqueIDToBucket[handleID]
	if bucket then
		if bucket.instanceIDtoIndex[handleID] then
			popElementInstance(bucket, handleID)
			bucket.dirty = true
		end
		uniqueIDToBucket[handleID] = nil
	end

	local owner = owners[handleID]
	owners[handleID] = nil
	return owner
end

---Remove every ghost registered under an ownerID. Pass nil to remove all of them.
---@param ownerID any
---@return number count how many ghosts were removed
local function StopDrawFeatureShapesGL4(ownerID)
	local removed = 0
	for handleID, owner in pairs(owners) do
		if ownerID == nil or owner == ownerID then
			local bucket = uniqueIDToBucket[handleID]
			if bucket and bucket.instanceIDtoIndex[handleID] then
				popElementInstance(bucket, handleID)
				bucket.dirty = true
			end
			uniqueIDToBucket[handleID] = nil
			owners[handleID] = nil
			removed = removed + 1
		end
	end
	return removed
end

-- Smoke test for the featureDefID instancing path, which nothing in the repo
-- exercised before this widget.
--
-- It ghosts the real features around the cursor at *their own* transforms, read
-- straight back from the sim. A correct shader puts each ghost exactly on top of
-- the feature it copies; any error in the euler order, the yaw sign, or the
-- per-instance element offset shows up instantly as a visible offset, a doubled
-- silhouette, or every ghost collapsing onto one spot.
local testHandles = {}

local function clearTest()
	for i = 1, #testHandles do
		StopDrawFeatureShapeGL4(testHandles[i])
	end
	testHandles = {}
end

local function drawFeatureShapeTest(_cmd, _line, args)
	if #testHandles > 0 then
		clearTest()
		Echo("[DrawFeatureShape GL4] test cleared")
		return true
	end

	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if not pos then
		Echo("[DrawFeatureShape GL4] point the cursor at the ground first")
		return true
	end

	local radius = tonumber(args and args[1]) or 400
	local featureIDs = Spring.GetFeaturesInCylinder(pos[1], pos[3], radius)
	if not featureIDs or #featureIDs == 0 then
		Echo("[DrawFeatureShape GL4] no features within " .. radius .. " of the cursor")
		return true
	end

	local offsetted = 0
	for i = 1, #featureIDs do
		local featureID = featureIDs[i]
		local featureDefID = Spring.GetFeatureDefID(featureID)
		local x, y, z = Spring.GetFeaturePosition(featureID)
		if featureDefID and x then
			local pitch, yaw, roll = Spring.GetFeatureRotation(featureID)
			if not yaw then
				yaw = (Spring.GetFeatureHeading(featureID) or 0) / 65536 * 2 * math.pi
				pitch, roll = 0, 0
			end

			-- Every other ghost is nudged 60 elmos east. The overlaid ones prove
			-- the transform matches; the nudged ones prove distinct instances get
			-- distinct positions rather than all landing on element 0.
			local nudge = (i % 2 == 0) and 60 or 0
			if nudge > 0 then
				offsetted = offsetted + 1
			end

			testHandles[#testHandles + 1] = DrawFeatureShapeGL4(
				featureDefID,
				x + nudge,
				y,
				z,
				yaw,
				pitch,
				roll,
				0.75,
				0.2,
				1.0,
				0.4,
				0.5,
				nil,
				"test"
			)
		end
	end

	Echo(
		"[DrawFeatureShape GL4] "
			.. #testHandles
			.. " ghosts ("
			.. (#testHandles - offsetted)
			.. " overlaid, "
			.. offsetted
			.. " nudged 60 east); run again to clear"
	)
	return true
end

function widget:Initialize()
	if not (LuaShader and InstanceVBOIdTable) then
		Echo("[DrawFeatureShape GL4] GL4 unavailable, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	vertexVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
	indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	if not (vertexVBO and indexVBO) then
		Echo("[DrawFeatureShape GL4] could not get model VBOs, removing widget")
		widgetHandler:RemoveWidget()
		return
	end
	vertexVBO:ModelsVBO()
	indexVBO:ModelsVBO()

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	local defines = LuaShader.CreateShaderDefinesString(shaderConfig)

	local vs = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	vs = vs:gsub("//__QUATERNIONDEFS__", LuaShader.GetQuaternionDefs())
	vs = vs:gsub("//__DEFINES__", defines)

	local fs = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fs = fs:gsub("//__DEFINES__", defines)

	featureShapeShader = LuaShader({
		vertex = vs,
		fragment = fs,
		uniformInt = {
			tex1 = 0,
			tex2 = 1,
		},
	}, "FeatureShapeGL4 API")

	if featureShapeShader:Initialize() ~= true then
		Echo("[DrawFeatureShape GL4] shader compilation failed, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	WG.DrawFeatureShapeGL4 = DrawFeatureShapeGL4
	WG.StopDrawFeatureShapeGL4 = StopDrawFeatureShapeGL4
	WG.StopDrawFeatureShapesGL4 = StopDrawFeatureShapesGL4

	widgetHandler:AddAction("drawfeatureshapetest", drawFeatureShapeTest, nil, "t")
end

function widget:Shutdown()
	clearTest()

	for i = 1, #buckets do
		local bucket = buckets[i]
		if bucket.VAO then
			bucket.VAO:Delete()
			bucket.VAO = nil
		end
		if bucket.instanceVBO then
			bucket.instanceVBO:Delete()
			bucket.instanceVBO = nil
		end
		if WG.VBOTableRegistry then
			WG.VBOTableRegistry[bucket.myName] = nil
		end
	end
	buckets = {}
	texKeyToBucket = {}
	featureDefIDToBucket = {}
	uniqueIDToBucket = {}
	owners = {}

	if featureShapeShader then
		featureShapeShader:Finalize()
		featureShapeShader = nil
	end

	-- The model VBOs belong to the engine; we only held handles to them.
	vertexVBO = nil
	indexVBO = nil

	WG.DrawFeatureShapeGL4 = nil
	WG.StopDrawFeatureShapeGL4 = nil
	WG.StopDrawFeatureShapesGL4 = nil

	widgetHandler:RemoveAction("drawfeatureshapetest", "t")
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() then
		return
	end

	local active = false

	for i = 1, #buckets do
		local bucket = buckets[i]
		-- Flush this frame's deferred pushes. uploadAllElements also rebuilds the
		-- VAO submission from indextoUnitID, but it bails early on an empty table
		-- and would leave the previous frame's submission live, so clear that case
		-- explicitly.
		if bucket.dirty then
			if bucket.usedElements > 0 then
				InstanceVBOIdTable.uploadAllElements(bucket)
			elseif bucket.VAO then
				bucket.VAO:ClearSubmission()
			end
			bucket.dirty = false
		end
		if bucket.usedElements > 0 then
			if not active then
				-- Depth-test against the world that is already on screen so
				-- ghosts hide behind terrain and units, but do not write depth:
				-- these are transparent and must not occlude later passes.
				-- Back-face culling keeps the intra-model bleed that comes with
				-- an unsorted transparent draw down to something unnoticeable at
				-- ghost alphas.
				gl.DepthTest(GL.LEQUAL)
				gl.DepthMask(false)
				gl.Culling(GL.BACK)
				gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				-- Pulled toward the camera because one caller (the feature
				-- placer's remove-mode highlight) draws a tinted ghost exactly on
				-- top of the real feature it is highlighting. Without the offset
				-- those two are coplanar and z-fight.
				gl.PolygonOffset(-2, -2)
				featureShapeShader:Activate()
				active = true
			end

			gl.FeatureShapeTextures(bucket.textureFeatureDefID, true)
			bucket.VAO:Submit()
			gl.FeatureShapeTextures(bucket.textureFeatureDefID, false)
		end
	end

	if active then
		featureShapeShader:Deactivate()
		gl.PolygonOffset(false)
		gl.Blending(false)
		gl.Culling(false)
		gl.DepthTest(false)
	end
end
