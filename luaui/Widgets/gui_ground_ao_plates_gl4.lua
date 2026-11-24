local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Ground AO Plates GL4",
		desc = "Draw ground ao plates under buildings",
		author = "Beherith",
		date = "2021.11.02",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
		depends = { "gl4" },
	}
end

-- Localized Spring API for performance
local spEcho = Spring.Echo

-- Configurable Parts:
local groundaoplatealpha = 1.0

local atlas = require("unittextures/decals/unitaoplates_atlas")
local plateAtlas
local unitDefIDtoInstanceData = {} -- key unitdef, the plate's instance data, with the gameframe set per push

---@type InstanceVBOTable?
local groundPlateVBO = nil
local groundPlateShader = nil

local luaShaderDir = "LuaUI/Include/"
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

local debugmode = false

-- Speedups of dubious usefulness:
local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL
local GL_POINTS = GL.POINTS
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGameFrame = Spring.GetGameFrame

local function AddPrimitiveAtUnit(unitID, unitDefID, noUpload, reason)
	unitDefID = unitDefID or spGetUnitDefID(unitID)

	local instanceData = unitDefID and unitDefIDtoInstanceData[unitDefID]
	if instanceData == nil then
		return
	end -- these can't/dont have plates

	instanceData[7] = spGetGameFrame()

	return pushElementInstance(
		groundPlateVBO, -- push into this Instance VBO Table
		instanceData, -- copied in, so one table per unitdef serves every plate
		unitID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		noUpload, -- noupload, this is used when reinitializing everything on VisibleUnitsChanged
		unitID
	) -- last one should be UNITID!
end

local firstRun = true
function widget:DrawWorldPreUnit()
	if firstRun then
		glTexture(0, atlas.atlasimage)
		glTexture(0, false)
		firstRun = false
	end
	if groundPlateVBO.usedElements > 0 then
		--spEcho(groundPlateVBO.usedElements)
		glCulling(GL_BACK)
		glDepthTest(GL_LEQUAL)
		glDepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		glTexture(0, atlas.atlasimage)
		if plateAtlas.runtimeTexture then
			glTexture(1, plateAtlas.runtimeTexture)
		end
		groundPlateShader:Activate()
		groundPlateVBO.VAO:DrawArrays(GL_POINTS, groundPlateVBO.usedElements)
		groundPlateShader:Deactivate()
		glTexture(0, false)
		if plateAtlas.runtimeTexture then
			glTexture(1, false)
		end
		glCulling(false)
		gl.DepthTest(GL.ALWAYS)
		gl.DepthTest(false)
		--gl.DepthMask(false) --"BK OpenGL state resets", already set as false
	end
end

function widget:Initialize()
	if not gl.CreateShader then
		widgetHandler:RemoveWidget()
		return
	end
	local GroundAOAtlas = VFS.Include(luaShaderDir .. "GroundAOAtlas.lua")
	plateAtlas = GroundAOAtlas.Create(atlas, "unittextures/decals", UnitDefs, "unit")
	local runtimeImages = {}
	local runtimeImageCount = 0
	for _, plate in pairs(plateAtlas.plates) do
		if plate.atlasIndex == 1 and not runtimeImages[plate.texturePath] then
			runtimeImages[plate.texturePath] = true
			runtimeImageCount = runtimeImageCount + 1
		end
	end
	local runtimeInfo = plateAtlas.runtimeTexture and gl.TextureInfo(plateAtlas.runtimeTexture)
	Spring.Echo(
		"Ground AO unit incremental atlas: "
			.. runtimeImageCount
			.. " image(s), "
			.. (runtimeInfo and (runtimeInfo.xsize .. "x" .. runtimeInfo.ysize) or "not created")
	)

	-- Init the unitDefIDtoInstanceData
	for id, plate in pairs(plateAtlas.plates) do
		local p, q, s, t = unpack(plate.uv)
		if plate.atlasIndex == 1 then
			s, t = 1 - s, 1 - t -- runtime atlas images use the opposite Y orientation
		end
		unitDefIDtoInstanceData[id] = {
			plate.sizeZ,
			plate.sizeX,
			0,
			0, -- length, width, cornersize, height
			0, -- teamID is unused here
			4, -- four vertices make a quad
			0, -- the gameFrame, set per push
			plate.atlasIndex, -- parameters.y selects the prebuilt/runtime atlas
			plate.alpha * groundaoplatealpha,
			0, -- parameters.w is filled with the glow rate in the vertex shader
			q,
			p,
			t,
			s, -- preserve the primitive renderer's UV ordering
			0,
			0,
			0,
			0,
		} -- instance data is filled by the VBO helper
	end

	-- Init GL4 things
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 0
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 1.0
	shaderConfig.ANIMATION = 0
	shaderConfig.USE_SECONDARY_TEXTURE = plateAtlas.runtimeTexture and 1 or 0
	-- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	shaderConfig.POST_VERTEX =
		"v_parameters.w = max(-0.2, sin((timeInfo.x + timeInfo.w) * 2.0/30.0 + float(UNITID) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.ZPULL = 512.0 -- send 16 elmos forward in depth buffer"
	shaderConfig.POST_GEOMETRY = "g_uv.w = dataIn[0].v_parameters.w;" -- pass the glow rate to the frag shader
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb* (1.0 + g_uv.w), texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	shaderConfig.USE_TRIANGLES = nil

	groundPlateVBO, groundPlateShader = InitDrawPrimitiveAtUnit(shaderConfig, "Ground AO Plates")
	if groundPlateVBO == nil then
		plateAtlas:Delete()
		spEcho("Error while initializing InitDrawPrimitiveAtUnit, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	-- Add all units
	if WG.unittrackerapi and WG.unittrackerapi.visibleUnits then
		widget:VisibleUnitsChanged(WG.unittrackerapi.visibleUnits, nil)
	end
end

--- Look how easy api_unit_tracker is to use!
function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	AddPrimitiveAtUnit(unitID, unitDefID, nil, "VisibleUnitAdded")
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(groundPlateVBO) -- clear all instances
	for unitID, unitDefID in pairs(extVisibleUnits) do
		AddPrimitiveAtUnit(unitID, unitDefID, true, "VisibleUnitsChanged") -- add them with noUpload = true
	end
	InstanceVBOTable.uploadAllElements(groundPlateVBO) -- upload them all
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	if debugmode then
		BAR.Debug.TraceEcho("remove", unitID)
	end
	if groundPlateVBO.instanceIDtoIndex[unitID] then
		popElementInstance(groundPlateVBO, unitID)
	end
end

function widget:Shutdown()
	if plateAtlas then
		plateAtlas:Delete()
	end
	if type(groundPlateShader) == "table" then
		groundPlateShader:Finalize()
		groundPlateShader = nil
	end
end
