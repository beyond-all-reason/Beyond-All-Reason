function widget:GetInfo()
	return {
		name		= "Clearmapmarks button",
		desc		= "clears mapmarks, located besides minimap",
		author		= "Floris",
		date		= "24 july 2016",
		license		= "GNU GPL, v2 or later",
		layer		= -5,			-- set to -5 to draw mascotte on top of advplayerlist
		enabled		= true
	}
end

local iconTexture = ":n:LuaUI/Images/mapmarksfx/eraser.dds"
local iconSize = 26

local glTranslate				= gl.Translate
local glPushMatrix          	= gl.PushMatrix
local glPopMatrix				= gl.PopMatrix
local glCreateList				= gl.CreateList
local glDeleteList				= gl.DeleteList
local glCallList				= gl.CallList

local minimapWidth
local drawlist = {}
local xPos = 0
local yPos = 0

local usedImgSize = iconSize
local chobbyInterface
local continuouslyClean = false
local math_isInRect = math.isInRect

local function RectQuad(px,py,sx,sy)
	local o = 0.008		-- texture offset, because else grey line might show at the edges
	gl.TexCoord(o,1-o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
end

local function DrawRect(px,py,sx,sy)
	gl.BeginEnd(GL.QUADS, RectQuad, px,py,sx,sy)
end

local function createList(size)
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
	drawlist[1] = glCreateList( function()
		gl.Texture(iconTexture)
		DrawRect(-usedImgSize, 0, 0, usedImgSize)
		gl.Texture(false)
	end)
	if WG['tooltip'] ~= nil then
		WG['tooltip'].AddTooltip('clearmapmarks', {xPos-usedImgSize, yPos, xPos, yPos+usedImgSize}, Spring.I18N('ui.clearMapmarks.tooltip')..'\n\255\200\200\200'..Spring.I18N('ui.clearMapmarks.tooltipctrl'))
	end
end

local function updatePosition(force)
	local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

	if WG['minimap'] ~= nil then
		local vsx, vsy = Spring.GetViewGeometry()
		local margin = WG.FlowUI.elementPadding
		local prevPos = minimapWidth
		minimapWidth = WG['minimap'].getWidth()
		usedImgSize = math.floor(iconSize * ui_scale)
		yPos = vsy - usedImgSize
		xPos = minimapWidth + usedImgSize
		if (prevPos == nil or prevPos ~= minimapWidth) or force then
			createList(usedImgSize)
		end
	end
end

function widget:Initialize()
	WG.clearmapmarks = {}
	WG.clearmapmarks.continuous = continuouslyClean
	updatePosition(true)
	WG['clearmapmarks'] = {}
	WG['clearmapmarks'].getWidth = function()
			return usedImgSize
	end
end

function widget:Shutdown()
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
	WG.clearmapmarks = nil
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > 0.5 then
		sec = 0
		updatePosition()
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
	if continuouslyClean then
		return true
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end

	if drawlist[1] ~= nil then
		local mx,my = Spring.GetMouseState()
		glPushMatrix()
			glTranslate(xPos, yPos, 0)
				if math_isInRect(mx, my, xPos-usedImgSize, yPos, xPos, yPos+usedImgSize) then
					--Spring.SetMouseCursor('cursornormal')
					gl.Color(1,1,1,1)
				else
					gl.Color(0.88,0.88,0.88,0.9)
				end
			glCallList(drawlist[1])
		glPopMatrix()
	end
end


function widget:MousePress(mx, my, mb)
	if mb == 1 and math_isInRect(mx, my, xPos-usedImgSize, yPos, xPos, yPos+usedImgSize) then
		return true
	end
end

function widget:MouseRelease(mx, my, mb)
	if mb == 1 and math_isInRect(mx, my, xPos-usedImgSize, yPos, xPos, yPos+usedImgSize) then
		Spring.SendCommands({"clearmapmarks"})
		updatePosition(true)

		local alt, ctrl, meta, shift = Spring.GetModKeyState()
		if ctrl then
			continuouslyClean = not continuouslyClean
			WG.clearmapmarks.continuous = continuouslyClean
			if continuouslyClean then
				Spring.Echo("clearmapmarks: continously cleaning all mapmarks enabled (for current game)")
			else
				Spring.Echo("clearmapmarks: continously cleaning all mapmarks disabled")
			end
		end
	end
end
