
function widget:GetInfo()
	return {
		name	= 'Faction Change',
		desc	= 'Adds buttons to switch faction',
		author	= 'Niobium',
		date	= 'May 2011',
		license	= 'GNU GPL v2',
		layer	= -100,
		enabled	= true,
	}
end

--------------------------------------------------------------------------------
-- Var
--------------------------------------------------------------------------------
local wWidth, wHeight = Spring.GetWindowGeometry()
local px, py = 50, 0.55*wHeight


--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local teamList = Spring.GetTeamList()
local myTeamID = Spring.GetMyTeamID()

local glTexCoord = gl.TexCoord
local glVertex = gl.Vertex
local glColor = gl.Color
local glRect = gl.Rect
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glDepthTest = gl.DepthTest
local glBeginEnd = gl.BeginEnd
local GL_QUADS = GL.QUADS
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glBeginText = gl.BeginText
local glEndText = gl.EndText
local glText = gl.Text
local glCallList = gl.CallList
local glCreateList = gl.CreateList
local glDeleteList = gl.DeleteList

local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetGroundHeight = Spring.GetGroundHeight
local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
local spGetSpectatingState = Spring.GetSpectatingState

local armcomDefID = UnitDefNames.armcom.id
local corcomDefID = UnitDefNames.corcom.id

local commanderDefID = spGetTeamRulesParam(myTeamID, 'startUnit')
local amNewbie = (spGetTeamRulesParam(myTeamID, 'isNewbie') == 1)

local factionChangeList

local vsx, vsy = gl.GetViewSizes()
local widgetScale = (0.50 + (vsx*vsy / 5000000))

local bgcorner = "LuaUI/Images/bgcorner.png"

--------------------------------------------------------------------------------
-- Funcs
--------------------------------------------------------------------------------

local function QuadVerts(x, y, z, r)
	glTexCoord(0, 0); glVertex(x - r, y, z - r)
	glTexCoord(1, 0); glVertex(x + r, y, z - r)
	glTexCoord(1, 1); glVertex(x + r, y, z + r)
	glTexCoord(0, 1); glVertex(x - r, y, z + r)
end

local function DrawRectRound(px,py,sx,sy,cs)
	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)
	
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
	
	local offset = 0.05		-- texture offset, because else gaps could show
	local o = offset
	
	-- top left
	--if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	--if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	--if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	--if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)
	
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------
function widget:Initialize()
	if spGetSpectatingState() or
	   Spring.GetGameFrame() > 0 or
	   amNewbie then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:Shutdown()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('factionchange')
	end
	if factionChangeList then
		glDeleteList(factionChangeList)
	end
end

function widget:DrawWorld()
	glColor(1, 1, 1, 0.5)
	glDepthTest(false)
	for i = 1, #teamList do
		local teamID = teamList[i]
		local tsx, tsy, tsz = spGetTeamStartPosition(teamID)
		if tsx and tsx > 0 then
			if spGetTeamRulesParam(teamID, 'startUnit') == armcomDefID then
				glTexture('LuaUI/Images/arm.png')
				glBeginEnd(GL_QUADS, QuadVerts, tsx, spGetGroundHeight(tsx, tsz), tsz, 80)
			else
				glTexture('LuaUI/Images/core.png')
				glBeginEnd(GL_QUADS, QuadVerts, tsx, spGetGroundHeight(tsx, tsz), tsz, 64)
			end
		end
	end
	glTexture(false)
end

function widget:DrawScreen()

	-- Spectator check
	if spGetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end

	-- Positioning
	glPushMatrix()
	glTranslate(px, py, 0)
	--call list
	if factionChangeList then
		glCallList(factionChangeList)
	else 
		factionChangeList = glCreateList(GenerateFactionChangeList)
	end
	glPopMatrix()

	
end

function widget:ViewResize(n_vsx,n_vsy)
	vsx, vsy = gl.GetViewSizes()
	widgetScale = (0.50 + (vsx*vsy / 5000000))
end

function GenerateFactionChangeList()
	-- Panel
	glColor(0, 0, 0, 0.66)
	RectRound(0, 0, 128*widgetScale, 80*widgetScale,6*widgetScale)
	glColor(1, 1, 1, 0.025)
	RectRound(2*widgetScale, 2*widgetScale, 126*widgetScale, 78*widgetScale, 5*widgetScale)
	
	
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(px+(2*widgetScale), py+(2*widgetScale), px+(126*widgetScale), py+(78*widgetScale), 'factionchange')
	end
	
		-- Highlight
	glColor(0.8, 0.8, 0.8, 0.3)
	if commanderDefID == armcomDefID then
		RectRound(3*widgetScale, 3*widgetScale, 61*widgetScale, 61*widgetScale,4.5*widgetScale)
	else
		RectRound(65*widgetScale, 3*widgetScale, 125*widgetScale, 61*widgetScale,4.5*widgetScale)
	end
		-- Icons
	glColor(1, 1, 1, 1)
	glTexture('LuaUI/Images/ARM.png')
	glTexRect(12*widgetScale, 17*widgetScale, 52*widgetScale, 59*widgetScale)
	glTexture('LuaUI/Images/CORE.png')
	glTexRect(76*widgetScale, 20*widgetScale, 116*widgetScale, 60*widgetScale)
	glTexture(false)
	
		-- Text
	glBeginText()
		glText('Choose Your Faction', 64*widgetScale, 64*widgetScale, 11.5*widgetScale, 'ocd')
		glText('ARM', 32*widgetScale, 4*widgetScale, 12*widgetScale, 'ocd')
		glText('CORE', 96*widgetScale, 4*widgetScale, 12*widgetScale, 'ocd')
	glEndText()
end



function widget:MousePress(mx, my, mButton)

	-- Check 3 of the 4 sides
	if mx >= px and my >= py and my < py + (80*widgetScale) then

		-- Check buttons
		if mButton == 1 then

			-- Spectator check before any action
			if spGetSpectatingState() then
				widgetHandler:RemoveWidget(self)
				return false
			end

			local newCom
			-- Which button?
			if mx < px + (64*widgetScale) then
				newCom = armcomDefID
			elseif mx < px + (128*widgetScale) then
				newCom = corcomDefID
			end
			if newCom then
				commanderDefID = newCom
				-- tell initial_spawn
				spSendLuaRulesMsg('\138' .. tostring(commanderDefID)) 
				-- tell initial_queue
				if WG["faction_change"] then 
					WG["faction_change"](commanderDefID)
				end
				
				--Remake gui
				if factionChangeList then
					glDeleteList(factionChangeList)
				end
				factionChangeList = glCreateList(GenerateFactionChangeList)
			
				return true
			end
			
		elseif (mButton == 2 or mButton == 3) and mx < px + (128*widgetScale) then
			-- Dragging
			return true
		end
	end
end

function widget:MouseMove(mx, my, dx, dy, mButton)
	-- Dragging
	if mButton == 2 or mButton == 3 then
		px = px + dx
		py = py + dy
		if factionChangeList then
			glDeleteList(factionChangeList)
		end
		factionChangeList = glCreateList(FactionChangeList)
	end
end

function widget:GameStart()
	widgetHandler:RemoveWidget(self)
end

