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
		depends = {'gl4'},
	}
end

-- Configurable Parts:
local groundaoplatealpha = 1.0

local atlas = VFS.Include("unittextures/decals/unitaoplates_atlas.lua")
local getUVCoords = atlas.getUVCoords
atlas.flip(atlas)
local unitDefIDtoDecalInfo = {} -- key unitdef, table of {texfile = "", sizex = 4 , sizez = 4}

local groundPlateVBO = nil
local groundPlateShader = nil
local luaShaderDir = "LuaUI/Include/"

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
local spGetGameFrame = Spring.GetGameFrame
local glGetAtlasTexture = gl.GetAtlasTexture

local function AddPrimitiveAtUnit(unitID, unitDefID, noUpload,reason)
	local gf = spGetGameFrame()
	unitDefID = unitDefID or spGetUnitDefID(unitID)

	if unitDefID == nil or unitDefIDtoDecalInfo[unitDefID] == nil then return end -- these cant/dont have plates

	local decalInfo = unitDefIDtoDecalInfo[unitDefID]

	local p,q,s,t = getUVCoords(atlas, decalInfo.texfile)
	--Spring.Echo(decalInfo.texfile, p,q,s,t)

	return pushElementInstance(
		groundPlateVBO, -- push into this Instance VBO Table
			{decalInfo.sizey, decalInfo.sizex, 0, 0,  -- length, width, cornersize, height
			0, -- Spring.GetUnitTeam(unitID), -- teamID, but its not used here so just pass zero
			4, -- how many vertices should we make (4 is a quad)
			gf, 0, decalInfo.alpha, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			q,p,t,s, -- These are our default UV atlas tranformations, note how Y axis is flipped for atlas
			0, 0, 0, 0}, -- these are just padding zeros, that will get filled in
		unitID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		noUpload, -- noupload, this is used when reinitializing everything on VisibleUnitsChanged
		unitID) -- last one should be UNITID!
end

local firstRun = true
function widget:DrawWorldPreUnit()
	if firstRun then
		glTexture(0, atlas.atlasimage)
		glTexture(0, false)
		firstRun = false
	end
	if groundPlateVBO.usedElements > 0 then
		--Spring.Echo(groundPlateVBO.usedElements)
		glCulling(GL_BACK)
		glDepthTest(GL_LEQUAL)
		glDepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		glTexture(0, atlas.atlasimage)
		groundPlateShader:Activate()
		groundPlateVBO.VAO:DrawArrays(GL_POINTS,groundPlateVBO.usedElements)
		groundPlateShader:Deactivate()
		glTexture(0, false)
		glCulling(false)
		gl.DepthTest(GL.ALWAYS)
		gl.DepthTest(false)
		--gl.DepthMask(false) --"BK OpenGL state resets", already set as false
	end
end

function widget:Initialize()
	-- Init texture atlas
	--makeAtlas()

	-- Init the unitDefIDtoDecalInfo
	for id , UD in pairs(UnitDefs) do
		if UD.customParams and UD.customParams.usebuildinggrounddecal and UD.customParams.buildinggrounddecaltype then
			--local UD.name
			local texname = "unittextures/" .. UD.customParams.buildinggrounddecaltype
			--Spring.Echo(texname)
			if atlas[texname] then
				unitDefIDtoDecalInfo[id] = {
						texfile = texname,
						-- note that this is hacky, as customparams are always strings, but multiplying number with stringnumber is number
						sizex  = (UD.customParams.buildinggrounddecalsizex or 0.0 ) * 16,
						sizey  = (UD.customParams.buildinggrounddecalsizey or 0.0 ) * 16,
						alpha  = (UD.customParams.buildinggrounddecalalpha or 1.0 ) * groundaoplatealpha,
					}
			end
		end
	end

	-- Init GL4 things
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 0
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 1.0
	shaderConfig.ANIMATION = 0
	-- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin((timeInfo.x + timeInfo.w) * 2.0/30.0 + float(UNITID) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.ZPULL = 512.0 -- send 16 elmos forward in depth buffer"
	shaderConfig.POST_GEOMETRY = "g_uv.w = dataIn[0].v_parameters.w;" -- pass the glow rate to the frag shader
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb* (1.0 + g_uv.w), texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	shaderConfig.USE_TRIANGLES = nil

	groundPlateVBO, groundPlateShader = InitDrawPrimitiveAtUnit(shaderConfig, "Ground AO Plates")
	if groundPlateVBO == nil then
		Spring.Echo("Error while initializing InitDrawPrimitiveAtUnit, removing widget")
		widgetHandler:RemoveWidget()
		return
	end

	-- Add all units
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end

--- Look how easy api_unit_tracker is to use!
function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	AddPrimitiveAtUnit(unitID, unitDefID, nil, "VisibleUnitAdded")
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	clearInstanceTable(groundPlateVBO) -- clear all instances
	for unitID, unitDefID in pairs(extVisibleUnits) do
		AddPrimitiveAtUnit(unitID, unitDefID, true, "VisibleUnitsChanged") -- add them with noUpload = true
	end
	uploadAllElements(groundPlateVBO) -- upload them all
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	if debugmode then Spring.Debug.TraceEcho("remove",unitID,reason) end
	if groundPlateVBO.instanceIDtoIndex[unitID] then
		popElementInstance(groundPlateVBO, unitID)
	end
end

