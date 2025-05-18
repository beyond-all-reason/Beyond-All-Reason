local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Rank Icons GL4",
		desc = "Shows a rank icon depending on experience next to units",
		author = "trepan (idea quantum,jK), Floris, Beherith",
		date = "Feb, 2008",
		license = "GNU GPL, v2 or later",
		layer = 5,
		enabled = true
	}
end

local iconsize = 1
local iconoffset = 24

local cutoffDistance = 2300

local distanceMult = 1
local usedCutoffDistance = cutoffDistance * distanceMult
local iconsizeMult = 1
local usedIconsize = iconsize * iconsizeMult

local maximumRankXP = 0.8
local numRanks = #VFS.DirList('LuaUI/Images/ranks', '*.png')
local rankTextures = {}
for i = 1,numRanks do
	rankTextures[i] = 'LuaUI/Images/ranks/rank'..i..'.png'
end
local xpPerLevel = maximumRankXP/(numRanks-1)

local unitHeights = {}
local spec, fullview = Spring.GetSpectatingState()

-- GL4 stuff:
local atlasID = nil
local atlasSize = 2048
--local atlassedImages = {}

local rankVBO = nil
local rankShader = nil
local luaShaderDir = "LuaUI/Include/"

local debugmode = false

local function addDirToAtlas(atlas, path)
	local imgExts = {bmp = true,tga = true,jpg = true,png = true,dds = true, tif = true}
	local files = VFS.DirList(path, '*.png')
	if debugmode then Spring.Echo("Adding",#files, "images to atlas from", path) end
	for i=1, #files do
		if imgExts[string.sub(files[i],-3,-1)] then
			gl.AddAtlasTexture(atlas,files[i])
			--atlassedImages[files[i]] = true
			--if debugmode then Spring.Echo("added", files[i]) end
		end
	end
end

local function makeAtlas()
	atlasID = gl.CreateTextureAtlas(atlasSize,atlasSize,1)
	addDirToAtlas(atlasID, "LuaUI/Images/ranks")
	local result = gl.FinalizeTextureAtlas(atlasID)
	if debugmode then
		--Spring.Echo("atlas result", result)
	end
end

local GetUnitDefID = Spring.GetUnitDefID
local GetUnitExperience = Spring.GetUnitExperience
local GetAllUnits = Spring.GetAllUnits
local IsUnitAllied = Spring.IsUnitAllied
local GetUnitTeam = Spring.GetUnitTeam

local glDepthTest = gl.DepthTest
local glDepthMask = gl.DepthMask
local glAlphaTest = gl.AlphaTest
local glTexture = gl.Texture

local GL_GREATER = GL.GREATER

local ignoreTeams = {}
for _, teamID in ipairs(Spring.GetTeamList()) do
	if select(4, Spring.GetTeamInfo(teamID,false)) then	-- is AI?
		local luaAI = Spring.GetTeamLuaAI(teamID)
		if luaAI and luaAI ~= "" and (string.find(luaAI, 'Scavengers') or string.find(luaAI, 'Raptors')) then
			ignoreTeams[teamID] = true
		end
	end
end

local unitIconMult = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if not unitDef.customParams.drone then
		unitIconMult[unitDefID] = math.clamp((Spring.GetUnitDefDimensions(unitDefID).radius / 40) + math.min(unitDef.power / 400, 2), 1.25, 1.4)
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
for i = 1, 18 do vbocachetable[i] = 0 end -- init this caching table to preserve mem allocs

local function AddPrimitiveAtUnit(unitID, unitDefID, noUpload, reason, rank, flash)
	if debugmode then Spring.Debug.TraceEcho("add",unitID,reason) end
	if Spring.ValidUnitID(unitID) ~= true or Spring.GetUnitIsDead(unitID) == true then
		if debugmode then Spring.Echo("Warning: Rank Icons GL4 attempted to add an invalid unitID:", unitID) end
		return nil
	end
	local gf = (flash and Spring.GetGameFrame()) or 0
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)

	--if unitDefID == nil or unitDefIDtoDecalInfo[unitDefID] == nil then return end -- these cant have plates
	--local decalInfo = unitDefIDtoDecalInfo[unitDefID]

	--local texname = "unittextures/decals/".. UnitDefs[unitDefID].name .. "_aoplane.dds" --unittextures/decals/armllt_aoplane.dds

	--Spring.Echo (rank, rankTextures[rank], unitIconMult[unitDefID])
	local p,q,s,t = gl.GetAtlasTexture(atlasID, rankTextures[rank])

	vbocachetable[1] = usedIconsize -- length
	vbocachetable[2] = usedIconsize -- widgth
	vbocachetable[3] = 0 -- cornersize
	vbocachetable[4] = (unitHeights[unitDefID] or iconoffset) - 8 + ((debugmode and math.random()*16 ) or 0)-- height

	--vbocachetable[5] = 0 -- Spring.GetUnitTeam(unitID)
	vbocachetable[6] = 4 -- numvertices

	vbocachetable[7] = gf-(doRefresh and 200 or 0) -- gameframe for animations
	vbocachetable[8] = unitIconMult[unitDefID] -- size mult
	vbocachetable[9] = 1.0 -- alpha
	--vbocachetable[10] = 0 -- unused

	vbocachetable[11] = q -- uv's of the atlas
	vbocachetable[12] = p
	vbocachetable[13] = t
	vbocachetable[14] = s


	return pushElementInstance(
		rankVBO, -- push into this Instance VBO Table
		vbocachetable, -- yes we save 1 table alloc this way
		unitID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		noUpload, -- noupload, dont use unless you know what you want to batch push/pop
		unitID) -- last one should be UNITID!
end

local function RemovePrimitive(unitID,reason)
	if debugmode then Spring.Debug.TraceEcho("remove",unitID,reason) end
	if rankVBO.instanceIDtoIndex[unitID] then
		popElementInstance(rankVBO, unitID)
	end
end

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
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
	shaderConfig.POST_VERTEX = "v_lengthwidthcornerheight.xy *= parameters.y * 4.5 + (1250 - abs(cameraDistance-1250))*0.016;"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil

	if debugmode then shaderConfig.POST_SHADING = shaderConfig.POST_SHADING .. " fragColor.a += 0.25;" end
	rankVBO, rankShader = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit(shaderConfig, "Rank Icons")
	if rankVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	makeAtlas()

	if debugmode then rankVBO.debug = true end
	--ProcessAllUnits()
	return true
end

local function getRank(unitDefID, xp)
	local rankLevel = math.ceil(xp/xpPerLevel)
	if rankLevel == 0 then
		return 1
	elseif rankLevel <= numRanks then
		return rankLevel
	else
		return numRanks
	end
end

local function updateUnitRank(unitID, unitDefID, noUpload)
	if not unitIconMult[unitDefID] or ignoreTeams[GetUnitTeam(unitID)] then
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
	clearInstanceTable(rankVBO)
	local units = Spring.GetAllUnits()
	--Spring.Echo("Refreshing Ground Plates", #units)
	for _, unitID in ipairs(units) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if unitDefID then
			updateUnitRank(unitID, unitDefID, true)
		end
	end
	uploadAllElements(rankVBO)
end

function widget:PlayerChanged(playerID)
	spec, fullview = Spring.GetSpectatingState()
end


function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	WG['rankicons'] = {}
	WG['rankicons'].getDrawDistance = function()
		return distanceMult
	end
	WG['rankicons'].setDrawDistance = function(value)
		distanceMult = value
		usedCutoffDistance = cutoffDistance * distanceMult
	end
	WG['rankicons'].getScale = function()
		return iconsizeMult
	end
	WG['rankicons'].setScale = function(value)
		iconsizeMult = value
		usedIconsize = iconsize * iconsizeMult
		doRefresh = true
	end
	WG['rankicons'].getRank = function(unitDefID, xp)
		return getRank(unitDefID, xp)
	end
	WG['rankicons'].getRankTextures = function(unitDefID, xp)
		return rankTextures
	end

	for unitDefID, ud in pairs(UnitDefs) do
		unitHeights[unitDefID] = ud.height + iconoffset
	end

	if not initGL4() then return end

	local allUnits = GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		updateUnitRank(unitID, GetUnitDefID(unitID))
	end
end

function widget:Shutdown()
	for _, rankTexture in ipairs(rankTextures) do
		gl.DeleteTexture(rankTexture)
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
		RemovePrimitive(unitID, "promoted")
		AddPrimitiveAtUnit(unitID, unitDefID, false, "promoted", rank, 1)
	end
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	RemovePrimitive(unitID, "UnitDestroyed")
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if fullview or IsUnitAllied(unitID) then
		updateUnitRank(unitID, GetUnitDefID(unitID))
	end
end

function widget:VisibleUnitRemoved(unitID) -- E.g. when a unit dies
	RemovePrimitive(unitID, "UnitDestroyed")
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	clearInstanceTable(rankVBO)
	doRefresh = true
	for unitID, unitDefID in pairs(extVisibleUnits) do
		updateUnitRank(unitID, unitDefID, true)
	end
	uploadAllElements(rankVBO)
	doRefresh = false
end


function widget:DrawWorld()
	if Spring.IsGUIHidden() then
		return
	end
	if doRefresh then
		ProcessAllUnits()
		doRefresh = false
	end
	if rankVBO.usedElements > 0 then
		--Spring.Echo(rankVBO.usedElements)
		--gl.Culling(GL.BACK)

		glDepthMask(true)
		glDepthTest(true)
		glAlphaTest(GL_GREATER, 0.001)
		--gl.DepthTest(GL.LEQUAL)
		--gl.DepthMask(false)
		glTexture(0, atlasID)
		rankShader:Activate()
		rankShader:SetUniform("iconDistance",usedCutoffDistance)
		rankShader:SetUniform("addRadius",0)
		rankVBO.VAO:DrawArrays(GL.POINTS,rankVBO.usedElements)
		rankShader:Deactivate()
		glTexture(0, false)
		--gl.Culling(false)
		--gl.DepthTest(false)

		glAlphaTest(false)
		glDepthTest(false)
		glDepthMask(false)
	end
end
