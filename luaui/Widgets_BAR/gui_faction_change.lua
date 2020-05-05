
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

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 25
local fontfileOutlineSize = 5
local fontfileOutlineStrength = 1.1
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

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


--------------------------------------------------------------------------------
-- Funcs
--------------------------------------------------------------------------------

local function QuadVerts(x, y, z, r)
	glTexCoord(0, 0); glVertex(x - r, y, z - r)
	glTexCoord(1, 0); glVertex(x + r, y, z - r)
	glTexCoord(1, 1); glVertex(x + r, y, z + r)
	glTexCoord(0, 1); glVertex(x - r, y, z + r)
end

local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
	local csyMult = 1 / ((sy-py)/cs)

	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)

	-- left side
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)

	-- right side
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)

	local offset = 0.15		-- texture offset, because else gaps could show

	-- bottom left
	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then
		gl.Vertex(px, py, 0)
	else
		gl.Vertex(px+cs, py, 0)
	end
	gl.Vertex(px+cs, py, 0)
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px, py+cs, 0)
	-- bottom right
	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
		gl.Vertex(sx, py, 0)
	else
		gl.Vertex(sx-cs, py, 0)
	end
	gl.Vertex(sx-cs, py, 0)
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx, py+cs, 0)
	-- top left
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
		gl.Vertex(px, sy, 0)
	else
		gl.Vertex(px+cs, sy, 0)
	end
	gl.Vertex(px+cs, sy, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2 then
		gl.Vertex(sx, sy, 0)
	else
		gl.Vertex(sx-cs, sy, 0)
	end
	gl.Vertex(sx-cs, sy, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(false)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
end

function updateGuishader()
	if WG['guishader'] then
		if backgroundGuishader then
			glDeleteList(backgroundGuishader)
		end
		backgroundGuishader = glCreateList( function()
			RectRound(px+(2*widgetScale), py+(2*widgetScale), px+(126*widgetScale), py+(78*widgetScale), 6*widgetScale)
		end)
		WG['guishader'].InsertDlist(backgroundGuishader, 'factionchange')
	end
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
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('factionchange')
	end
	if factionChangeList then
		glDeleteList(factionChangeList)
	end
	gl.DeleteFont(font)
end

local function DrawUnitDef(uDefID, uTeam, ux, uy, uz, scale)

	gl.Color(1.0, 1.0, 1.0, 1.0)
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	gl.Lighting(true)

	gl.PushMatrix()
	gl.Translate(ux, uy, uz)
	if scale then
		gl.Scale(scale, scale, scale)
	end
	gl.UnitShape(uDefID, uTeam, false, true, true)
	gl.PopMatrix()

	gl.Lighting(false)
	gl.DepthTest(false)
	gl.DepthMask(false)
end

function widget:DrawWorld()
	if chobbyInterface then return end
	glColor(1, 1, 1, 0.5)
	glDepthTest(false)
	for i = 1, #teamList do
		local teamID = teamList[i]
		local tsx, tsy, tsz = spGetTeamStartPosition(teamID)
		if tsx and tsx > 0 then
			if spGetTeamRulesParam(teamID, 'startUnit') == armcomDefID then
				--glTexture('unitpics/alternative/armcom.png')
				--glBeginEnd(GL_QUADS, QuadVerts, tsx, spGetGroundHeight(tsx, tsz), tsz, 64)
				DrawUnitDef(armcomDefID, teamID, tsx, spGetGroundHeight(tsx, tsz), tsz)
			else
				--glTexture('unitpics/alternative/corcom.png')
				--glBeginEnd(GL_QUADS, QuadVerts, tsx, spGetGroundHeight(tsx, tsz), tsz, 64)
				DrawUnitDef(corcomDefID, teamID, tsx, spGetGroundHeight(tsx, tsz), tsz)
			end
		end
	end
	glColor(1, 1, 1, 1)
	glTexture(false)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end

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
		updateGuishader()
	end
	glPopMatrix()


end

function widget:ViewResize(n_vsx,n_vsy)
	vsx, vsy = gl.GetViewSizes()
	widgetScale = (0.50 + (vsx*vsy / 5000000))
  local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
  if (fontfileScale ~= newFontfileScale) then
    fontfileScale = newFontfileScale
    gl.DeleteFont(font)
    font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
  end
end

function GenerateFactionChangeList()
	-- Panel
	glColor(0, 0, 0, 0.66)
	RectRound(0, 0, 128*widgetScale, 80*widgetScale,6*widgetScale)
	glColor(1, 1, 1, 0.025)
	RectRound(2*widgetScale, 2*widgetScale, 126*widgetScale, 78*widgetScale, 5*widgetScale)


		-- Highlight
	glColor(0.8, 0.8, 0.8, 0.3)
	if commanderDefID == armcomDefID then
		RectRound(3*widgetScale, 3*widgetScale, 61*widgetScale, 61*widgetScale,4.5*widgetScale)
	else
		RectRound(65*widgetScale, 3*widgetScale, 125*widgetScale, 61*widgetScale,4.5*widgetScale)
	end
		-- Icons
	glColor(1, 1, 1, 1)
	glTexture(':lr96,96:unitpics/alternative/armcom.png')
	glTexRect(8*widgetScale, 12*widgetScale, 54*widgetScale, 60*widgetScale)
	glTexture(':lr96,96:unitpics/alternative/corcom.png')
	glTexRect(72*widgetScale, 12*widgetScale, 120*widgetScale, 60*widgetScale)
	glTexture(false)

		-- Text
	font:Begin()
	font:Print('Choose Your Faction', 64*widgetScale, 64*widgetScale, 11.5*widgetScale, 'ocd')
	font:Print('ARM', 32*widgetScale, 4*widgetScale, 12*widgetScale, 'ocd')
	font:Print('CORE', 96*widgetScale, 4*widgetScale, 12*widgetScale, 'ocd')
	font:End()
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
				updateGuishader()

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
		factionChangeList = glCreateList(GenerateFactionChangeList)
	end
end

function widget:GameStart()
	widgetHandler:RemoveWidget(self)
end

