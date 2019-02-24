function widget:GetInfo()
	return {
		name		= "Discord icon",
		desc		= "located next to advplayerlist",
		author		= "Floris",
		date		= "24 july 2016",
		license		= "GNU GPL, v2 or later",
		layer		= -4,			-- set to -5 to draw mascotte on top of advplayerlist
		enabled		= true,
	}
end

local discordLink = 'balancedannihilation.com/discord'

local iconTexture = ":n:LuaUI/Images/discord.png"
local iconSize = 32

local spGetGameFrame		= Spring.GetGameFrame

local glText	          = gl.Text
local glGetTextWidth		= gl.GetTextWidth
local glTranslate				= gl.Translate
local glPushMatrix      = gl.PushMatrix
local glPopMatrix				= gl.PopMatrix

local glCreateList			= gl.CreateList
local glDeleteList			= gl.DeleteList
local glCallList				= gl.CallList

local drawlist = {}
local xPos = 0
local yPos = 0

local mouseover = false
local usedImgSize = iconSize

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

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

function DrawRect(px,py,sx,sy)
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
end

local parentPos = {}
function updatePosition(force)
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = parentPos
		if WG['displayinfo'] ~= nil then
			parentPos = WG['displayinfo'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		elseif WG['music'] ~= nil then
			parentPos = WG['music'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		else
			parentPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		end
		usedImgSize = iconSize * parentPos[5]
		xPos = parentPos[4]
		yPos = parentPos[1]
		local vsx,vsy = Spring.GetViewGeometry()
		if xPos > vsx then xPos = vsx end
		if (prevPos[1] == nil or prevPos[1] ~= parentPos[1] or prevPos[2] ~= parentPos[2] or prevPos[5] ~= parentPos[5]) or force then
			createList(usedImgSize)
		end
	end
end

function widget:Initialize()
	if spGetGameFrame() > 0 then widgetHandler:RemoveWidget(self) return end
	updatePosition()
end

function widget:Shutdown()
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
end

function widget:GameFrame(n)
	if n > 0 then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:DrawScreen()
	updatePosition()
	if drawlist[1] ~= nil then
		glPushMatrix()
			glTranslate(xPos, yPos, 0)
				if mouseover then
					gl.Color(1,1,1,1)
				else
					gl.Color(1,1,1,0.55)
				end
			glCallList(drawlist[1])
			local mx,my = Spring.GetMouseState()
			if widget:IsAbove(mx,my) then
				local textWidth = glGetTextWidth(discordLink) * 13
				glText(discordLink, -(textWidth+6+iconSize)*parentPos[5], 12*parentPos[5], 13*parentPos[5], "no")
			end
		glPopMatrix()
		mouseover = false
	end
end

function isInBox(mx, my, box)
    return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:MousePress(mx, my, mb)
	if mb == 1 and isInBox(mx, my, {xPos-usedImgSize, yPos, xPos, yPos+usedImgSize}) then
		Spring.SendCommands("say BA's discord server: https://"..discordLink)
		widgetHandler:RemoveWidget(self)
		return true
	end
end

function widget:MouseRelease(mx, my, mb)
	if mb == 1 and isInBox(mx, my, {xPos-usedImgSize, yPos, xPos, yPos+usedImgSize}) then
		updatePosition(true)
	end
end

function widget:IsAbove(mx, my)
	if isInBox(mx, my, {xPos-usedImgSize, yPos, xPos, yPos+usedImgSize}) then
		mouseover = true
	end
	return mouseover
end

function widget:GetTooltip(mx, my)
	if widget:IsAbove(mx,my) then
		return string.format("We have our own Discord server now!\nour central community hub (chat/voice/info)\n\n"..discordLink)
	end
end