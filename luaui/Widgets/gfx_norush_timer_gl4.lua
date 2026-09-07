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

local StartboxLib = VFS.Include("luarules/gadgets/include/startbox_utilities.lua")
local StartPolygonSDF = VFS.Include("luaui/Include/startpolygon_sdf_gl4.lua")

local pveAllyTeamID = BAR.Utilities.GetScavAllyTeamID() or BAR.Utilities.GetRaptorAllyTeamID()

---- Config stuff ------------------
local autoReload = false -- refresh shader code every second (disable in production!)

local StartPolygons = {} -- list of { team = teamID, poly = { {x, z}, ... } }
local startPolygonBuffer
local startPolygonSDF -- baked distance field the fullscreen pass samples, see startpolygon_sdf_gl4.lua
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
		startPolygonSDF = 1,
		noRushTimer = Spring.GetModOptions().norushtimer * 60 * 30,
	},
	uniformFloat = {},
	shaderName = "Norush Timer GL4",
	shaderConfig = {
		ALPHA = 0.5,
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
		-- Fully faded out; free the distance field and the shader.
		widgetHandler:RemoveWidget()
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

	-- The polygons never change, so this runs once. It has to happen in a world draw
	-- callin (gl.RenderToTexture), hence not in Initialize.
	if not startPolygonSDF:IsBakedFor(-1) then
		startPolygonSDF:Bake(startPolygonBuffer, fullScreenRectVAO, -1)
	end
	glTexture(1, startPolygonSDF.texture)

	glCulling(true)
	glDepthTest(false)
	gl.DepthMask(false)

	norushTimerShader:Activate()
	norushTimerShader:SetUniform("noRushTimer", noRushTime)
	fullScreenRectVAO:DrawArrays(GL.TRIANGLES)
	norushTimerShader:Deactivate()
	glTexture(0, false)
	glTexture(1, false)
	glCulling(false)
	glDepthTest(false)
end

-- teamColor in the shader is indexed by team, so each polygon carries a team from its
-- allyteam rather than the allyteam id itself.
local function ColourTeamOf(allyTeamID)
	local teams = Spring.GetTeamList(allyTeamID)

	return (teams and teams[1]) or 0
end

-- Must match map_startbox.lua
local function BuildStartPolygons()
	local gaiaAllyTeamID
	if Spring.GetGaiaTeamID() then
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID(), false))
	end

	local polygons = {}

	-- isExplicit is false for the hardcoded fallback, which the gadget does not enforce
	-- either; the engine rectangles stay authoritative in that case.
	local startBoxConfig, _, isExplicit = StartboxLib.GetConfig()
	if startBoxConfig and isExplicit then
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
	if not startPolygonBuffer then
		spEcho("Error: Norush Timer GL4 could not allocate its start polygon buffer")
		widgetHandler:RemoveWidget()
		return
	end

	startPolygonBuffer:Define(numVertices, { { id = 0, name = "startpolygons", size = 4 } })
	startPolygonBuffer:Upload(bufferdata)

	-- Only the bake walks the polygons; the draw shader reads the baked field.
	local sdfError
	startPolygonSDF, sdfError = StartPolygonSDF.Create({
		format = GL.RG32F, -- x = signed distance, y = team; the ripple wants full float precision
		shaderName = "Norush Timer SDF bake GL4",
		shaderConfig = {
			NUM_POLYGONS = #StartPolygons,
			NUM_POINTS = numVertices,
		},
	})
	if not startPolygonSDF then
		spEcho("Error: Norush Timer GL4 " .. tostring(sdfError))
		widgetHandler:RemoveWidget()
		return
	end

	norushTimerShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or norushTimerShader

	if not norushTimerShader then
		spEcho("Error: Norush Timer GL4 shader not initialized")
		widgetHandler:RemoveWidget()
		return
	end
	fullScreenRectVAO = InstanceVBOTable.MakeTexRectVAO()
end

function widget:Shutdown()
	if startPolygonSDF then
		startPolygonSDF:Delete()
		startPolygonSDF = nil
	end
	if norushTimerShader then
		norushTimerShader:Delete()
		norushTimerShader = nil
	end
end
