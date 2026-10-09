local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Rank Icons GL4",
		desc = "Shows a rank icon depending on experience next to units",
		author = "trepan (idea quantum,jK), Floris, Beherith",
		date = "Feb, 2008",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetUnitDefID = Spring.GetUnitDefID
local spEcho = Spring.Echo
local spGetUnitTeam = Spring.GetUnitTeam
local spGetAllUnits = Spring.GetAllUnits
local spGetSpectatingState = Spring.GetSpectatingState
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetGameFrame = Spring.GetGameFrame
local spIsGUIHidden = Spring.IsGUIHidden
local mathCeil = math.ceil

local iconsize = 1
local iconoffset = 24

local cutoffDistance = 2300

local distanceMult = 1
local usedCutoffDistance = cutoffDistance * distanceMult
local iconsizeMult = 1
local usedIconsize = iconsize * iconsizeMult

local maximumRankXP = 0.8
local numRanks = #VFS.DirList("LuaUI/Images/ranks", "*.png")
local rankTextures = {}
for i = 1, numRanks do
	rankTextures[i] = "LuaUI/Images/ranks/rank" .. i .. ".png"
end
local xpPerLevel = maximumRankXP / (numRanks - 1)
local rankUVs = {} -- atlas coordinates, 4 per rank in instance attribute order

local unitHeights = {}
local spec, fullview = spGetSpectatingState()
local doRefresh = false

-- GL4 stuff:
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

local atlasID = nil
local atlasSize = 2048
--local atlassedImages = {}

---@type InstanceVBOTable?
local rankVBO = nil
local rankShader = nil
local shaderIconDistance = nil
local luaShaderDir = "LuaUI/Include/"

local debugmode = false

local function addDirToAtlas(atlas, path)
	local imgExts = { bmp = true, tga = true, jpg = true, png = true, dds = true, tif = true }
	local files = VFS.DirList(path, "*.png")
	if debugmode then
		spEcho("Adding", #files, "images to atlas from", path)
	end
	for i = 1, #files do
		if imgExts[string.sub(files[i], -3, -1)] then
			gl.AddAtlasTexture(atlas, files[i])
			--atlassedImages[files[i]] = true
			--if debugmode then spEcho("added", files[i]) end
		end
	end
end

local function makeAtlas()
	atlasID = gl.CreateTextureAtlas(atlasSize, atlasSize, 1)
	addDirToAtlas(atlasID, "LuaUI/Images/ranks")
	local result = gl.FinalizeTextureAtlas(atlasID)
	if debugmode then
		--spEcho("atlas result", result)
	end
	for rank = 1, numRanks do
		local p, q, s, t = gl.GetAtlasTexture(atlasID, rankTextures[rank])
		local i = rank * 4
		rankUVs[i - 3], rankUVs[i - 2], rankUVs[i - 1], rankUVs[i] = q, p, t, s
	end
end

local GetUnitDefID = spGetUnitDefID
local GetUnitExperience = Spring.GetUnitExperience
local GetAllUnits = spGetAllUnits
local IsUnitAllied = Spring.IsUnitAllied
local GetUnitTeam = spGetUnitTeam

local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glTexture = gl.Texture

local GL_POINTS = GL.POINTS

local ignoreTeams = {}
for _, teamID in ipairs(Spring.GetTeamList()) do
	if select(4, Spring.GetTeamInfo(teamID, false)) then -- is AI?
		local luaAI = Spring.GetTeamLuaAI(teamID)
		if luaAI and luaAI ~= "" and (string.find(luaAI, "Scavengers") or string.find(luaAI, "Raptors")) then
			ignoreTeams[teamID] = true
		end
	end
end
local hasIgnoredTeams = next(ignoreTeams) ~= nil

local unitIconMult = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if not unitDef.customParams.drone then
		unitIconMult[unitDefID] = math.clamp(
			(Spring.GetUnitDefDimensions(unitDefID).radius / 40) + math.min(unitDef.power / 400, 2),
			1.25,
			1.4
		)
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:GetConfigData()
	return {
		distanceMult = distanceMult,
		iconsizeMult = iconsizeMult,
	}
end

function widget:SetConfigData(data)
	if data.distanceMult ~= nil then
		distanceMult = data.distanceMult
		usedCutoffDistance = cutoffDistance * distanceMult
	end
	if data.iconsizeMult ~= nil then
		iconsizeMult = data.iconsizeMult
		usedIconsize = iconsize * iconsizeMult
	end
end

local vbocachetable = {}
for i = 1, 18 do
	vbocachetable[i] = 0
end -- init this caching table to preserve mem allocs

local drawCallInActive = true

-- DrawScreenEffects is only registered while there are icons
local function updateDrawCallIn()
	local active = rankVBO.usedElements > 0
	if active ~= drawCallInActive then
		drawCallInActive = active
		if active then
			widgetHandler:UpdateCallIn("DrawScreenEffects")
		else
			doRefresh = false
			widgetHandler:RemoveCallIn("DrawScreenEffects")
		end
	end
end

local function AddPrimitiveAtUnit(unitID, unitDefID, noUpload, reason, rank, flash)
	if debugmode then
		BAR.Debug.TraceEcho("add", unitID, reason)
	end
	if spValidUnitID(unitID) ~= true or spGetUnitIsDead(unitID) == true then
		if debugmode then
			spEcho("Warning: Rank Icons GL4 attempted to add an invalid unitID:", unitID)
		end
		return nil
	end
	local gf = (flash and spGetGameFrame()) or 0
	unitDefID = unitDefID or spGetUnitDefID(unitID)

	--if unitDefID == nil or unitDefIDtoDecalInfo[unitDefID] == nil then return end -- these can't have plates
	--local decalInfo = unitDefIDtoDecalInfo[unitDefID]

	--local texname = "unittextures/decals/".. UnitDefs[unitDefID].name .. "_aoplane.dds" --unittextures/decals/armllt_aoplane.dds

	--spEcho (rank, rankTextures[rank], unitIconMult[unitDefID])
	local uv = rank * 4

	vbocachetable[1] = usedIconsize -- length
	vbocachetable[2] = usedIconsize -- widgth
	vbocachetable[3] = 0 -- cornersize
	vbocachetable[4] = (unitHeights[unitDefID] or iconoffset) - 8 + ((debugmode and math.random() * 16) or 0) -- height

	--vbocachetable[5] = 0 -- spGetUnitTeam(unitID)
	vbocachetable[6] = 4 -- numvertices

	vbocachetable[7] = gf - (doRefresh and 200 or 0) -- gameframe for animations
	vbocachetable[8] = unitIconMult[unitDefID] -- size mult
	vbocachetable[9] = 1.0 -- alpha
	--vbocachetable[10] = 0 -- unused

	vbocachetable[11] = rankUVs[uv - 3] -- uv's of the atlas
	vbocachetable[12] = rankUVs[uv - 2]
	vbocachetable[13] = rankUVs[uv - 1]
	vbocachetable[14] = rankUVs[uv]

	pushElementInstance(
		rankVBO, -- push into this Instance VBO Table
		vbocachetable, -- yes we save 1 table alloc this way
		unitID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		noUpload, -- noupload, dont use unless you know what you want to batch push/pop
		unitID
	) -- last one should be UNITID!
	updateDrawCallIn()
end

local function RemovePrimitive(unitID, reason)
	if debugmode then
		BAR.Debug.TraceEcho("remove", unitID, reason)
	end
	if rankVBO.instanceIDtoIndex[unitID] then
		popElementInstance(rankVBO, unitID)
		updateDrawCallIn()
	end
end

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 1.0
	shaderConfig.ANIMATION = 1
	shaderConfig.INITIALSIZE = 0.25
	shaderConfig.BREATHERATE = 0.0
	shaderConfig.BREATHESIZE = 0.0
	shaderConfig.GROWTHRATE = 16.0

	-- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin((timeInfo.x + timeInfo.w) * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	--shaderConfig.POST_GEOMETRY = "g_uv.w = dataIn[0].v_parameters.w; gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in depth buffer"
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb* (1.0 + g_uv.w), texcolor.a * g_uv.z);" -- i have no idea what this does
	shaderConfig.POST_VERTEX =
		"v_lengthwidthcornerheight.xy *= parameters.y * 4.5 + (1250 - abs(cameraDistance-1250))*0.016;"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil

	if debugmode then
		shaderConfig.POST_SHADING = shaderConfig.POST_SHADING .. " fragColor.a += 0.25;"
	end
	-- replaces gl.AlphaTest(GL.GREATER, 0.001), which the engine ran with its reference truncated to 0
	shaderConfig.POST_SHADING = shaderConfig.POST_SHADING .. " if (fragColor.a <= 0.0) discard;"
	rankVBO, rankShader = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit(shaderConfig, "Rank Icons")
	if rankVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	makeAtlas()

	if debugmode then
		rankVBO.debug = true
	end
	--ProcessAllUnits()
	return true
end

local function getRank(unitDefID, xp)
	local rankLevel = mathCeil(xp / xpPerLevel)
	if rankLevel == 0 then
		return 1
	elseif rankLevel <= numRanks then
		return rankLevel
	else
		return numRanks
	end
end

local function updateUnitRank(unitID, unitDefID, noUpload, unitTeam)
	if not unitIconMult[unitDefID] or (hasIgnoredTeams and ignoreTeams[unitTeam or GetUnitTeam(unitID)]) then
		return
	end
	local xp = GetUnitExperience(unitID)
	if xp then
		local newrank = getRank(unitDefID, xp)
		if newrank > 1 then
			AddPrimitiveAtUnit(unitID, unitDefID, noUpload, "updateUnitRank", newrank, false)
		end
	end
end

local function ProcessAllUnits()
	InstanceVBOTable.clearInstanceTable(rankVBO)
	local units = spGetAllUnits()
	--spEcho("Refreshing Ground Plates", #units)
	for _, unitID in ipairs(units) do
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID then
			updateUnitRank(unitID, unitDefID, true)
		end
	end
	InstanceVBOTable.uploadAllElements(rankVBO)
end

function widget:PlayerChanged(playerID)
	spec, fullview = spGetSpectatingState()
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	WG.rankicons = {}
	WG.rankicons.getDrawDistance = function()
		return distanceMult
	end
	WG.rankicons.setDrawDistance = function(value)
		distanceMult = value
		usedCutoffDistance = cutoffDistance * distanceMult
	end
	WG.rankicons.getScale = function()
		return iconsizeMult
	end
	WG.rankicons.setScale = function(value)
		iconsizeMult = value
		usedIconsize = iconsize * iconsizeMult
		if drawCallInActive then -- without icons the new size simply applies to the next ones
			doRefresh = true
		end
	end
	WG.rankicons.getRank = function(unitDefID, xp)
		return getRank(unitDefID, xp)
	end
	WG.rankicons.getRankTextures = function(unitDefID, xp)
		return rankTextures
	end

	for unitDefID, ud in pairs(UnitDefs) do
		unitHeights[unitDefID] = ud.height + iconoffset
	end

	if not initGL4() then
		return
	end

	local allUnits = GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		updateUnitRank(unitID, GetUnitDefID(unitID))
	end
	updateDrawCallIn()
end

function widget:Shutdown()
	for _, rankTexture in ipairs(rankTextures) do
		gl.DeleteTexture(rankTexture)
	end
	if rankVBO then
		rankVBO:Delete()
		rankShader:Delete()
		gl.DeleteTextureAtlas(atlasID)
	end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function widget:UnitExperience(unitID, unitDefID, teamID, xp, oldXP)
	if not unitIconMult[unitDefID] or ignoreTeams[teamID] then
		return
	end
	if xp < 0 then
		xp = 0
	end
	if oldXP < 0 then
		oldXP = 0
	end

	local rank = getRank(unitDefID, xp)
	local oldRank = getRank(unitDefID, oldXP)

	if oldRank < rank then
		AddPrimitiveAtUnit(unitID, unitDefID, false, "promoted", rank, 1)
	end
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	RemovePrimitive(unitID, "UnitDestroyed")
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if fullview or IsUnitAllied(unitID) then
		updateUnitRank(unitID, unitDefID, nil, unitTeam)
	end
end

function widget:VisibleUnitRemoved(unitID) -- E.g. when a unit dies
	RemovePrimitive(unitID, "UnitDestroyed")
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(rankVBO)
	doRefresh = true
	for unitID, unitDefID in pairs(extVisibleUnits) do
		updateUnitRank(unitID, unitDefID, true)
	end
	InstanceVBOTable.uploadAllElements(rankVBO)
	doRefresh = false
	updateDrawCallIn()
end

function widget:DrawScreenEffects()
	-- DrawScreenEffects so rank icons render after deferred lighting/distortion/bloom/tonemap;
	-- shader still uses engine cameraViewProj UBO and depth-test for terrain occlusion.
	if spIsGUIHidden() then
		return
	end
	if doRefresh then
		ProcessAllUnits()
		doRefresh = false
		updateDrawCallIn()
	end
	if rankVBO.usedElements > 0 then
		--spEcho(rankVBO.usedElements)
		--gl.Culling(GL.BACK)

		glDepthMask(true)
		glDepthTest(true)
		--gl.DepthTest(GL.LEQUAL)
		--gl.DepthMask(false)
		glTexture(0, atlasID)
		rankShader:Activate()
		-- addRadius stays at its default of 0
		if shaderIconDistance ~= usedCutoffDistance then
			shaderIconDistance = usedCutoffDistance
			rankShader:SetUniform("iconDistance", usedCutoffDistance)
		end
		rankVBO.VAO:DrawArrays(GL_POINTS, rankVBO.usedElements)
		rankShader:Deactivate()
		glTexture(0, false)
		--gl.Culling(false)
		--gl.DepthTest(false)

		glDepthTest(false)
		glDepthMask(false)
	end
end
