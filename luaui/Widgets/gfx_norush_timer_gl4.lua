local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Norush Timer GL4",
		desc = "Draws Norush Timer Areas",
		author = "Beherith",
		date = "2024.08.12",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spEcho = Spring.Echo

-- spEcho(Spring.GetTeamInfo(Spring.GetMyTeamID()))

local pveAllyTeamID = BAR.Utilities.GetScavAllyTeamID() or BAR.Utilities.GetRaptorAllyTeamID()

---- Config stuff ------------------
local autoReload = false -- refresh shader code every second (disable in production!)

local StartPolygons = {} -- list of { team = teamID, poly = { {x, z}, ... } }
local startPolygonBuffer
local GL_SHADER_STORAGE_BUFFER = GL.SHADER_STORAGE_BUFFER
local noRushTime = Spring.GetModOptions().norushtimer * 60 * 30
if noRushTime == 0 then
	return
end

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local minY, maxY = Spring.GetGroundExtremes()

local shaderSourceCache = {
	vssrcpath = "LuaUI/Shaders/norush_timer.vert.glsl",
	fssrcpath = "LuaUI/Shaders/norush_timer.frag.glsl",
	uniformInt = {
		mapDepths = 0,
		noRushTimer = Spring.GetModOptions().norushtimer * 60 * 30,
	},
	uniformFloat = {},
	shaderName = "Norush Timer GL4",
	shaderConfig = {
		ALPHA = 0.5,
		NUM_POLYGONS = 0,
		NUM_POINTS = 0,
		MINY = minY,
		MAXY = maxY,
	},
}

local fullScreenRectVAO
local norushTimerShader
-- Locals for speedups
local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local spIsGUIHidden = Spring.IsGUIHidden

function widget:RecvLuaMsg(msg, playerID)
	--spEcho("widget:RecvLuaMsg",msg)
	if msg:sub(1, 18) == "LobbyOverlayActive" then
		chobbyInterface = (msg:sub(1, 19) == "LobbyOverlayActive1")
	end
end

function widget:DrawWorldPreUnit()
	if Spring.GetGameFrame() > noRushTime + 150 then
		return
	end
	if autoReload then
		norushTimerShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or norushTimerShader
	end

	if chobbyInterface or spIsGUIHidden() then
		return
	end

	local _, advMapShading = Spring.HaveAdvShading()

	if advMapShading then
		gl.Texture(0, "$map_gbuffer_zvaltex")
	else
		if WG.screencopymanager and WG.screencopymanager.GetDepthCopy() then
			gl.Texture(0, WG.screencopymanager.GetDepthCopy())
		else
			return
		end
	end

	startPolygonBuffer:BindBufferRange(4)

	glCulling(true)
	glDepthTest(false)
	gl.DepthMask(false)

	norushTimerShader:Activate()
	norushTimerShader:SetUniform("noRushTimer", noRushTime)
	fullScreenRectVAO:DrawArrays(GL.TRIANGLES)
	norushTimerShader:Deactivate()
	glTexture(0, false)
	glCulling(false)
	glDepthTest(false)
end

function widget:GameFrame(n)
	-- TODO: Remove the widget when the timer is up?
end

-- teamColor in the shader is indexed by team, so each polygon carries a team from its
-- allyteam rather than the allyteam id itself.
local function ColourTeamOf(allyTeamID)
	local teams = Spring.GetTeamList(allyTeamID)

	return (teams and teams[1]) or 0
end

-- Spring.GetAllyTeamStartBox only ever reports the bounding box of a polygon startbox, so
-- drawing from it marked out a larger area than game_no_rush_mode actually enforces. The
-- gadget's own parser is included here instead, the way map_startbox.lua does it, so the
-- overlay and the enforcement cannot describe different shapes.
local function BuildStartPolygons()
	local gaiaAllyTeamID
	if Spring.GetGaiaTeamID() then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
	end

	local polygons = {}
	local ok, ParseBoxes = pcall(VFS.Include, "luarules/gadgets/include/startbox_utilities.lua")
	if ok and ParseBoxes then
		-- isExplicit is false for the hardcoded fallback, which the gadget does not enforce
		-- either; the engine rectangles stay authoritative in that case.
		local pok, startBoxConfig, _, isExplicit = pcall(ParseBoxes)
		if pok and startBoxConfig and isExplicit then
			-- Walked in allyteam order rather than with pairs(): the buffer order decides which
			-- colour each zone gets, and pairs() would let two clients disagree about it.
			for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
				local entry = startBoxConfig[allyTeamID]
				if allyTeamID ~= gaiaAllyTeamID and allyTeamID ~= pveAllyTeamID and entry and entry.boxes then
					for _, polygon in ipairs(entry.boxes) do
						polygons[#polygons + 1] = { team = ColourTeamOf(allyTeamID), poly = polygon }
					end
				end
			end
		end
	end
	if #polygons > 0 then
		return polygons
	end

	for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		if allyTeamID ~= gaiaAllyTeamID and allyTeamID ~= pveAllyTeamID then
			local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(allyTeamID)
			if xn then
				-- Expressed as a ring so the shader keeps a single code path.
				polygons[#polygons + 1] =
					{ team = ColourTeamOf(allyTeamID), poly = { { xn, zn }, { xp, zn }, { xp, zp }, { xn, zp } } }
			end
		end
	end

	return polygons
end

function widget:Initialize()
	StartPolygons = BuildStartPolygons()
	if #StartPolygons == 0 then
		widgetHandler:RemoveWidget()
		return
	end

	local bufferdata = {}
	local numVertices = 0
	for _, entry in ipairs(StartPolygons) do
		local polygon = entry.poly
		local numPoints = #polygon
		for _, vertex in ipairs(polygon) do
			bufferdata[#bufferdata + 1] = entry.team
			bufferdata[#bufferdata + 1] = numPoints
			bufferdata[#bufferdata + 1] = vertex[1]
			bufferdata[#bufferdata + 1] = vertex[2]
			numVertices = numVertices + 1
		end
	end

	-- SHADER_STORAGE_BUFFER data has to be 64 byte aligned.
	if numVertices % 4 ~= 0 then
		local pad = 4 - (numVertices % 4)
		for _ = 1, pad * 4 do
			bufferdata[#bufferdata + 1] = -1
		end
		numVertices = numVertices + pad
	end

	startPolygonBuffer = gl.GetVBO(GL_SHADER_STORAGE_BUFFER, false)
	startPolygonBuffer:Define(numVertices, { { id = 0, name = "startpolygons", size = 4 } })
	startPolygonBuffer:Upload(bufferdata)

	shaderSourceCache.shaderConfig.NUM_POLYGONS = #StartPolygons
	shaderSourceCache.shaderConfig.NUM_POINTS = numVertices

	norushTimerShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or norushTimerShader

	if not norushTimerShader then
		spEcho("Error: Norush Timer GL4 shader not initialized")
		widgetHandler:RemoveWidget()
		return
	end
	fullScreenRectVAO = InstanceVBOTable.MakeTexRectVAO()
end
