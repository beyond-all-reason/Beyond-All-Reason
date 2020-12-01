--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    	snd_volume_osd.lua
--  brief:   	volume control OSD
-- version: 	1.1
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Volume OSD",
    desc      = "A sound control OSD",
    author    = "Jools",
    date      = "Jan 10, 2012",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

include('keysym.h.lua')
local pluskey								= KEYSYMS.PLUS
local equalskey								= KEYSYMS.EQUALS -- same key as + on most qwerty keyboards
local minuskey								= KEYSYMS.MINUS
local pluskey2								= KEYSYMS.KP_PLUS
local minuskey2								= KEYSYMS.KP_MINUS

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- SETTINGS, internal, don't edit
--------------------------------------------------------------------------------
local volume
local vsx,vsy                    			= gl.GetViewSizes()
local widgetPosX 							= vsx/2.5
local widgetPosY 							= vsy/7.5
local pressedToMove		 					= false
local dt									= -1

--------------------------------------------------------------------------------
-- SETTINGS, configurable
--------------------------------------------------------------------------------
local TEST_SOUND 							= 'LuaUI/sounds/volume_osd/pop.wav'
local step 									= 8 -- how many steps to change sound volume on one key press
local dtime									= 3 --How long time the volume display is drawn, in seconds
local ftime 								= 2.5 --How long time before the volume display starts fading, in seconds
local widgetWidth							= vsx/4.5 -- in pixels (changed from 400)
local widgetHeight							= vsy/27 -- in pixels (changed from 40)
local rectangles 							= 25 -- number of boxes in volume bar
local boxspacing 							= 5 -- space between boxes
local red									= 0.1 -- volume bar colour, 0 to 1.
local green									= 0.7 -- volume bar colour, 0 to 1.
local blue									= 0 -- volume bar colour, 0 to 1.
--------------------------------------------------------------------------------

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local chobbyInterface

function widget:Initialize()
  volume = Spring.GetConfigInt("snd_volmaster", 60)
end

function widget:KeyPress(key, mods, isRepeat)
	if (key == pluskey or key == pluskey2 or key == equalskey) and (not mods.alt) and (not mods.shift) then -- KEY = pluskey
		volume = Spring.GetConfigInt("snd_volmaster", 80)
		volume = volume + step
		if volume < 0 then volume = 0 end
		if volume > 200 then volume = 200 end
		Spring.SetConfigInt("snd_volmaster", volume)
		--Spring.Echo("Volume = " .. volume)
		if not isRepeat then Spring.PlaySoundFile(TEST_SOUND, 1.0, 'ui') end
		dt = os.clock()
		return true
	elseif (key == minuskey or key == minuskey2) and (not mods.alt) and (not mods.shift) then -- KEY = minuskey
		volume = Spring.GetConfigInt("snd_volmaster", 80)
		volume = volume - step
		if volume < 0 then volume = 0 end
		if volume > 200 then volume = 200 end
		Spring.SetConfigInt("snd_volmaster", volume)
		--Spring.Echo("Volume = " .. volume)
		if not isRepeat then Spring.PlaySoundFile(TEST_SOUND, 1.0, 'ui') end
		dt = os.clock()
		return true
	end
	return false
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

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
	local y1 = widgetPosY
	local y2 = widgetPosY + widgetHeight
	local x1 = widgetPosX
	local x2 = widgetPosX + widgetWidth
	local ostime = os.clock()
	local t = ostime - dt
	local boxwidth = widgetWidth/rectangles

	if t < dtime and dt >= 0 then --dtime = 3
		local alpha
		if t < ftime then --ftime = 2
			alpha = 1
		else
			alpha = 3*(dtime-t)/dtime
		end

		local padding = boxwidth / 17
		for i = 1,rectangles do
			local u1 = x1+(i-1)*boxwidth
			local u2= u1+boxwidth-boxspacing
			--gl.Rect(u1,y1,u2,y2)
			RectRound(u1,y1,u2,y2,(u2-u1)/4, 1,1,1,1, {0.1,0.1,0.1,0.6*alpha}, {0,0,0,0.4*alpha})
			RectRound(u1+padding,y1+padding,u2-padding,y2-padding,(u2-u1)/5.5, 1,1,1,1, {1,1,1,0.035*alpha}, {1,1,1,0.02*alpha})
		end
		local vol2 = math.floor((volume/(100/rectangles))/2)
		gl.Color(0,0.85,0,alpha)                              -- draws filled rectangles
		local spacer2 = boxwidth / 10
		for i = 1,vol2 do
			local u1 = x1+(i-1)*boxwidth
			local u2= u1+boxwidth-boxspacing
			RectRound(u1+spacer2,y1+spacer2,u2-spacer2,y2-spacer2,((u2-spacer2)-(u1+spacer2))/5.5, 1,1,1,1, {0,0.5,0,alpha*0.8}, {0,1,0,alpha*0.8})
			RectRound(u1+spacer2+padding,y1+spacer2+padding,u2-spacer2-padding,y2-spacer2-padding,((u2-spacer2)-(u1+spacer2))/6.5, 1,1,1,1, {1,1,1,alpha*0.25}, {1,1,1,alpha*0.25})
			-- gloss
			glBlending(GL_SRC_ALPHA, GL_ONE)
			RectRound(u1+spacer2,y2-spacer2-((y2-y1)*0.23),u2-spacer2,y2-spacer2,((u2-spacer2)-(u1+spacer2))/5.5, 1,1,0,0, {1,1,1,alpha*0.035}, {1,1,1,alpha*0.13})
			RectRound(u1+spacer2,y1+spacer2,u2-spacer2,y1+spacer2+((y2-y1)*0.13),((u2-spacer2)-(u1+spacer2))/5.5, 0,0,1,1, {1,1,1,alpha*0.05}, {1,1,1,alpha*0})
			glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		end
	end
end


function IsOnButton(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	if BLcornerX == nil then return false end
	-- check if the mouse is in a rectangle

	return x >= BLcornerX and x <= TRcornerX
						  and y >= BLcornerY
						  and y <= TRcornerY
end


function widget:ViewResize(viewSizeX, viewSizeY)
	vsx = viewSizeX
	vsy = viewSizeY

	widgetWidth		= vsx/4.5 -- in pixels (changed from 400)
	widgetHeight	= vsy/27 -- in pixels (changed from 40)

	widgetPosX 							= vsx/2.5
	widgetPosY 							= vsy/7.5
end
