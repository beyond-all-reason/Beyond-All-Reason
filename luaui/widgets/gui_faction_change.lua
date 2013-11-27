
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
local px, py = 300, 300

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

local spGetTeamStartPosition = Spring.GetTeamStartPosition
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetGroundHeight = Spring.GetGroundHeight
local spSendLuaRulesMsg = Spring.SendLuaRulesMsg
local spGetSpectatingState = Spring.GetSpectatingState

local armcomDefID = UnitDefNames.armcom.id
local corcomDefID = UnitDefNames.corcom.id

local commanderDefID = spGetTeamRulesParam(myTeamID, 'startUnit')
local amNewbie = (spGetTeamRulesParam(myTeamID, 'isNewbie') == 1)

--------------------------------------------------------------------------------
-- Funcs
--------------------------------------------------------------------------------
local function QuadVerts(x, y, z, r)
	glTexCoord(0, 0); glVertex(x - r, y, z - r)
	glTexCoord(1, 0); glVertex(x + r, y, z - r)
	glTexCoord(1, 1); glVertex(x + r, y, z + r)
	glTexCoord(0, 1); glVertex(x - r, y, z + r)
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

		-- Panel
		glColor(0, 0, 0, 0.5)
		glRect(0, 0, 128, 80)

		-- Highlight
		glColor(1, 1, 0, 0.5)
		if commanderDefID == armcomDefID then
			glRect(1, 1, 63, 63)
		else
			glTexRect(65, 1, 127, 63)
		end

		-- Icons
		glColor(1, 1, 1, 1)
		glTexture('LuaUI/Images/ARM.png')
		glTexRect(8, 8, 56, 56)
		glTexture('LuaUI/Images/CORE.png')
		glTexRect(72, 8, 120, 56)
		glTexture(false)

		-- Text
		glBeginText()
			glText('Choose Your Faction', 64, 64, 12, 'cd')
			glText('ARM', 32, 0, 12, 'cd')
			glText('CORE', 96, 0, 12, 'cd')
		glEndText()
	glPopMatrix()
end

function widget:MousePress(mx, my, mButton)

	-- Check 3 of the 4 sides
	if mx >= px and my >= py and my < py + 80 then

		-- Check buttons
		if mButton == 1 then

			-- Spectator check before any action
			if spGetSpectatingState() then
				widgetHandler:RemoveWidget(self)
				return false
			end

			local newCom
			-- Which button?
			if mx < px + 64 then
				newCom = armcomDefID
			elseif mx < px + 128 then
				newCom = corcomDefID
			end
			if newCom then
				commanderDefID = newCom
				spSendLuaRulesMsg('\138' .. tostring(commanderDefID))
				if WG["faction_change"] then
					WG["faction_change"](commanderDefID)
				end
				return true
			end
		elseif (mButton == 2 or mButton == 3) and mx < px + 128 then
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
	end
end

function widget:GameStart()
	widgetHandler:RemoveWidget(self)
end

function widget:GetConfigData()
	local vsx, vsy = gl.GetViewSizes()
	return {px / vsx, py / vsy}
end
function widget:SetConfigData(data)
	local vsx, vsy = gl.GetViewSizes()
	px = math.floor(math.max(0, vsx * math.min(data[1] or 0, 0.95)))
	py = math.floor(math.max(0, vsy * math.min(data[2] or 0, 0.95)))
end

