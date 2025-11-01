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

-- Spring.Echo(Spring.GetTeamInfo(Spring.GetMyTeamID()))

local pveAllyTeamID = Spring.Utilities.GetScavAllyTeamID() or Spring.Utilities.GetRaptorAllyTeamID()

---- Config stuff ------------------
local autoReload = false -- refresh shader code every second (disable in production!)

local StartBoxes = {} -- list of xXyY 
local noRushTime = Spring.GetModOptions().norushtimer*60*30
if noRushTime == 0 then return end

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local minY, maxY = Spring.GetGroundExtremes()

local shaderSourceCache = {
		vssrcpath = "LuaUI/Shaders/norush_timer.vert.glsl",
		fssrcpath = "LuaUI/Shaders/norush_timer.frag.glsl",
		uniformInt = {
			mapDepths = 0,
			noRushTimer = Spring.GetModOptions().norushtimer*60*30,
		},
		uniformFloat = {
		},
		shaderName = "Norush Timer GL4",
		shaderConfig = {
			ALPHA = 0.5,
			NUM_BOXES = NUM_BOXES,
			MINY = minY,
			MAXY = maxY,
		}
	}
	
local fullScreenRectVAO
local norushTimerShader
-- Locals for speedups
local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local spIsGUIHidden			= Spring.IsGUIHidden

function widget:RecvLuaMsg(msg, playerID)
	--Spring.Echo("widget:RecvLuaMsg",msg)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorldPreUnit()
	if Spring.GetGameFrame() > noRushTime+150 then return end
	if autoReload then
		norushTimerShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or norushTimerShader
	end

	if chobbyInterface or spIsGUIHidden() then return end

	local _, advMapShading = Spring.HaveAdvShading()

	if advMapShading then 
		gl.Texture(0, "$map_gbuffer_zvaltex")
	else
		if WG['screencopymanager'] and WG['screencopymanager'].GetDepthCopy() then
			gl.Texture(0, WG['screencopymanager'].GetDepthCopy())
		else
			return
		end
	end
	
	glCulling(true)
	glDepthTest(false)
	gl.DepthMask(false)

	norushTimerShader:Activate()
	for i, startBox in ipairs(StartBoxes) do
		--Spring.Echo("startBoxes["..i.."]", startBox[1],startBox[2],startBox[3],startBox[4])
		norushTimerShader:SetUniform("startBoxes["..( i-1) .."]", startBox[1],startBox[2],startBox[3],startBox[4])
	end
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

function widget:Initialize()
	local gaiaAllyTeamID
	if Spring.GetGaiaTeamID() then 
		gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID() , false))
	end
	for i, teamID in ipairs(Spring.GetAllyTeamList()) do
		if teamID ~= gaiaAllyTeamID and teamID ~= pveAllyTeamID then
			local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(teamID)
			--Spring.Echo("Allyteam",teamID,"startbox",xn, zn, xp, zp)	
			StartBoxes[#StartBoxes+1] = {xn, zn, xp, zp}
		end
	end
	
	-- MANUAL OVERRIDE FOR DEBUGGING:
	-- StartBoxes = { {100, 200, 2000, 3000} , {2200, 3300, 5000, 4000}}

	shaderSourceCache.shaderConfig.NUM_BOXES = #StartBoxes

	norushTimerShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or norushTimerShader

	if not norushTimerShader then
		Spring.Echo("Error: Norush Timer GL4 shader not initialized")
		widgetHandler:RemoveWidget()
		return
	end
	fullScreenRectVAO = InstanceVBOTable.MakeTexRectVAO()
end
