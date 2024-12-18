function widget:GetInfo()
	return {
		name = "Start Polygons",
		desc = "Displays Start Polygons",
		author = "Beherith",
		date = "2024.08.16",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false,
	}
end

-- Note: this is now updated to support arbitrary start polygons via GL.SHADER_STORAGE_BUFFER

-- The format of the buffer is the following:
-- Triplets of :teamID, triangleID, x, z

-- Spring.Echo(Spring.GetTeamInfo(Spring.GetMyTeamID()))

-- TODO:
-- [ ] Handle overlapping of boxes and myAllyTeamID
-- [X] Handle Minimap drawing too 
	-- [X] handle flipped minimaps 
-- [ ] Pass in my team too
-- [ ] Handle Scavengers in scavenger color
-- [ ] Handle Raptors in raptor color

local scavengerStartBoxTexture = "LuaUI/Images/scav-tileable_v002_small.tga"

local raptorStartBoxTexture = "LuaUI/Images/rapt-tileable_v002_small.tga"

local getMiniMapFlipped = VFS.Include("luaui/Widgets/Include/minimap_utils.lua").getMiniMapFlipped

local scavengerAITeamID = 999
local raptorsAITeamID = 999
local scavengerAIAllyTeamID
local raptorsAIAllyTeamID
local teams = Spring.GetTeamList()

for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengerAITeamID = i - 1
		scavengerAIAllyTeamID = select(6, Spring.GetTeamInfo(scavengerAITeamID))
		break
	end
end
for i = 1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'RaptorsAI' then
		raptorsAITeamID = i - 1
		raptorsAIAllyTeamID = select(6, Spring.GetTeamInfo(raptorsAITeamID))
		break
	end
end

---- Config stuff ------------------
local autoReload = true -- refresh shader code every second (disable in production!)

local StartPolygons = {} -- list of points in clockwise order

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local minY, maxY = Spring.GetGroundExtremes()

local shaderSourceCache = {
		vssrcpath = "LuaUI/Widgets/Shaders/map_startpolygon_gl4.vert.glsl",
		fssrcpath = "LuaUI/Widgets/Shaders/map_startpolygon_gl4.frag.glsl",
		uniformInt = {
			mapDepths = 0,
			myAllyTeamID = -1,
			isMiniMap = 0,
			flipMiniMap = 0,
			mapNormals = 1,
			heightMapTex = 2, 
			scavTexture = 3,
			raptorTexture = 4,
		},
		uniformFloat = {
			pingData = {0,0,0,-10000}, -- x,y,z, time
		},
		shaderName = "Start Polygons GL4",
		shaderConfig = {
			ALPHA = 0.5,
			NUM_POLYGONS = 0,
			NUM_POINTS = 0,
			MINY = minY - 10,
			MAXY = maxY + 100,
			MAX_STEEPNESS = 0.5877, -- 45 degrees yay (cos is 0.7071? (54 degrees, so cos of that is 0.5877	)
			SCAV_ALLYTEAM_ID = scavengerAIAllyTeamID, -- these neatly become undefined if not present
			RAPTOR_ALLYTEAM_ID = raptorsAIAllyTeamID,
		},
	}

local fullScreenRectVAO
local startPolygonShader
local startPolygonBuffer = nil -- GL.SHADER_STORAGE_BUFFER for polygon

local function DrawStartPolygons(inminimap)	
	local advUnitShading, advMapShading = Spring.HaveAdvShading()

	if advMapShading then 
		gl.Texture(0, "$map_gbuffer_zvaltex")
	else
		if WG['screencopymanager'] and WG['screencopymanager'].GetDepthCopy() then
			gl.Texture(0, WG['screencopymanager'].GetDepthCopy())
		else 
			Spring.Echo("Start Polygons: Adv map shading not available, and no depth copy available")
			return
		end
	end
	
	gl.Texture(1, "$normals")
	gl.Texture(2, "$heightmap")-- Texture file
	gl.Texture(3, scavengerStartBoxTexture)
	gl.Texture(4, raptorStartBoxTexture)

	startPolygonBuffer:BindBufferRange(4)

	gl.Culling(GL.FRONT)
	gl.DepthTest(false)
	gl.DepthMask(false)

	startPolygonShader:Activate()

	startPolygonShader:SetUniform("noRushTimer", noRushTime)
	startPolygonShader:SetUniformInt("isMiniMap", inminimap and 1 or 0)
	startPolygonShader:SetUniformInt("flipMiniMap", getMiniMapFlipped() and 1 or 0)
	startPolygonShader:SetUniformInt("myAllyTeamID", Spring.GetMyAllyTeamID() or -1) 

	fullScreenRectVAO:DrawArrays(GL.TRIANGLES)
	startPolygonShader:Deactivate()
	gl.Texture(0, false)
	gl.Culling(false)
	gl.DepthTest(false)
end

function widget:DrawInMiniMap(sx, sz)
	DrawStartPolygons(true)
end

function widget:DrawWorldPreUnit()
	if autoReload then
		startPolygonShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or startPolygonShader
	end
	DrawStartPolygons(false)
end

function widget:GameFrame(n)
	-- TODO: Remove the widget when the timer is up?
end

function widget:Initialize()
	local gaiaAllyTeamID
	if Spring.GetGaiaTeamID() then 
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID() , false))
	end
	for i, teamID in ipairs(Spring.GetAllyTeamList()) do
		if teamID ~= gaiaAllyTeamID then 
			--and teamID ~= scavengerAIAllyTeamID and teamID ~= raptorsAIAllyTeamID then
			local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(teamID)
			--Spring.Echo("Allyteam",teamID,"startbox",xn, zn, xp, zp)	
			StartPolygons[teamID] = {{xn, zn}, {xp, zn}, {xp, zp}, {xn, zp}}
		end
	end
	
	if autoReload and false then
		-- MANUAL OVERRIDE FOR DEBUGGING
		-- lets add a bunch of silly StartPolygons:
		StartPolygons = {}
		for i = 2,8 do
			local x0 = math.random(0, Game.mapSizeX)
			local y0 = math.random(0, Game.mapSizeZ)
			local polygon = {{x0, y0}}

			for j = 2, math.ceil(math.random() * 10) do 
				local x1 = math.random(0, Game.mapSizeX / 5)
				local y1 = math.random(0, Game.mapSizeZ / 5)
				polygon[#polygon+1] = {x0+x1, y0+y1}
			end
			StartPolygons[#StartPolygons+1] = polygon
		end
	end

	shaderSourceCache.shaderConfig.NUM_BOXES = #StartPolygons

	local numvertices = 0
	local bufferdata = {}
	local numPolygons = 0
	for teamID, polygon in pairs(StartPolygons) do
		numPolygons = numPolygons + 1
		local numPoints = #polygon
		local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(teamID)
		--Spring.Echo("teamID", teamID, "at " ,xn, zn, xp, zp)
		for vertexID, vertex in ipairs(polygon) do
			local x, z = vertex[1], vertex[2]
			bufferdata[#bufferdata+1] = teamID
			bufferdata[#bufferdata+1] = numPoints
			bufferdata[#bufferdata+1] = x
			bufferdata[#bufferdata+1] = z
			numvertices = numvertices + 1
		end
	end

	-- SHADER_STORAGE_BUFFER MUST HAVE 64 byte aligned data 
	if numvertices % 4 ~= 0 then 
		for i=1, ((4 - (numvertices % 4)) * 4) do bufferdata[#bufferdata+1] = -1 end
		numvertices = numvertices + (4 - numvertices % 4)
	end

	startPolygonBuffer = gl.GetVBO(GL.SHADER_STORAGE_BUFFER, false) -- not updated a lot
	startPolygonBuffer:Define(numvertices, {{id = 0, name = 'starttriangles', size = 4}})
	startPolygonBuffer:Upload(bufferdata)--, -1, 0, 0, numvertices-1)

	shaderSourceCache.shaderConfig.NUM_POLYGONS = numPolygons
	shaderSourceCache.shaderConfig.NUM_POINTS = numvertices
	startPolygonShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or startPolygonShader

	if not startPolygonShader then
		Spring.Echo("Error: Norush Timer GL4 shader not initialized")
		widgetHandler:RemoveWidget()
		return
	end
	fullScreenRectVAO = MakeTexRectVAO()
end
