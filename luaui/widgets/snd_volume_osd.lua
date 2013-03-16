--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    	snd_volume_osd.lua
--  brief:   	volume control OSD
-- version: 	1.0
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
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local TEST_SOUND = LUAUI_DIRNAME .. 'Sounds/pop.wav'
local volume
local TextDraw            		 			= fontHandler.Draw
local vsx,vsy                    			= gl.GetViewSizes()
local widgetPosX 							= 600
local widgetPosY 							= 600
local widgetWidth							= 400
local widgetHeight							= 50
local pressedToMove		 					= false
local font         							= "LuaUI/Fonts/FreeSansBold_14"
local step 									= 2
local pluskey								= 0x10E -- numpad+
local minuskey								= 0x10D -- numpad-
local altdown
local dframe								= -1
local dtime									= 3 --in seconds
local ftime 								= 2 --in seconds
function widget:Initialize()
  volume = Spring.GetConfigInt("snd_volmaster", 60)
  Spring.Echo("Volume = " .. volume)
  fontHandler.UseFont(font)
end

function widget:KeyPress(key, mods, isRepeat)
	if (key == pluskey) and mods.alt and (not mods.shift) then -- KEY = Alt + pluskey
		volume = Spring.GetConfigInt("snd_volmaster", 60)
		volume = volume + step
		if volume < 0 then volume = 0 end
		if volume > 100 then volume = 100 end
		Spring.SetConfigInt("snd_volmaster", volume)
		--if not isRepeat then Spring.PlaySoundFile(TEST_SOUND, 1.0) end
		--Spring.Echo("Volume = " .. volume)
		dframe = Spring.GetGameFrame()
		return true
		
	elseif (key == minuskey) and mods.alt and (not mods.shift) then -- KEY = Alt + minuskey
		volume = Spring.GetConfigInt("snd_volmaster", 60)
		volume = volume - step
		if volume < 0 then volume = 0 end
		if volume > 100 then volume = 100 end
		Spring.SetConfigInt("snd_volmaster", volume)
		--pring.Echo("Volume = " .. volume)
		--if not isRepeat then Spring.PlaySoundFile(TEST_SOUND, 1.0) end
		dframe = Spring.GetGameFrame()
		return true
	elseif key == 0x134 then --ALT
		altdown = true
	end
	return false
end

function widget:KeyRelease(key)
	if altdown and (key == pluskey or key == minuskey) then
		Spring.PlaySoundFile(TEST_SOUND, 1.0)
		return true
	elseif key == 0x134 then --ALT
		altdown = false
		return true
	end
	return false
end

function widget:DrawScreen()
		local y1 = widgetPosY 
		local y2 = widgetPosY + widgetHeight
		local x1 = widgetPosX
		local x2 = widgetPosX + widgetWidth
		local frame = Spring.GetGameFrame()
		fontHandler.UseFont(font)
		local t = (frame - dframe) / 30
		
		if t < dtime and dframe >= 0 then --dtime = 3
			local alpha
			if t < ftime then --ftime = 2
				alpha = 1
			else
				alpha = 3*(dtime-t)/dtime
			end
			gl.Color(0,0,0,0.1*alpha)                              -- draws background rectangle
			gl.Rect(x1,y1,x2-1,y2)
			gl.Color(0.5,1,0.5,alpha)
			TextDraw("Volume: ".. volume .. "%",x1+5,y2+5)
			gl.Color(0.3,0.3,0.3,0.6*alpha)                              -- draws empty rectangles
			for i = 1,50 do
				local u1 = x1+(i-1)*8
				local u2= u1+6
				gl.Rect(u1,y1,u2,y2)
			end
			
			local vol2 = math.floor(volume/2)
			gl.Color(0,0.8,0,alpha)                              -- draws filled rectangles
			for i = 1,vol2 do
				local u1 = x1+(i-1)*8
				local u2= u1+6
				gl.Color(0,0.7,0,alpha)                              
				gl.Rect(u1+1,y1+1,u1+2,y2-1)
				gl.Color(0,0.8,0,alpha)                              
				gl.Rect(u1+2,y1+1,u2-1,y2-1)
			end
		end
	end

function widget:TweakDrawScreen()
	local y1 = widgetPosY 
	local y2 = widgetPosY + widgetHeight
	local x1 = widgetPosX
	local x2 = widgetPosX + widgetWidth
	fontHandler.UseFont(font)
	gl.Color(0,0,0.5,1)
	gl.Rect(x1-1,y1-1,x1,y2+1)
	gl.Rect(x2-1,y1-1,x2,y2+1)
	gl.Rect(x1-1,y1-1,x2,y1)
	gl.Rect(x1-1,y2,x2,y2+1)
	gl.Color(0.5,1,0.5,1)
	TextDraw("Volume: ".. volume .. "%",x1+5,y2+5)
	gl.Color(0,0,0,0.2)                              -- draws empty rectangles
	for i = 1,40 do
		local u1 = x1+(i-1)*10
		local u2= u1+8
		gl.Rect(u1,y1,u2,y2)
	end
	
	local vol2 = math.floor(volume/2.5)
	gl.Color(0,0.8,0,1)                              -- draws filled rectangles
	for i = 1,vol2 do
		local u1 = x1+(i-1)*10
		local u2= u1+8
		gl.Rect(u1+1,y1+1,u2-1,y2-1)
	end	
end

	-----------------
	-- AID --
	-----------------

function widget:TweakMouseMove(x,y,dx,dy,button)
		if pressedToMove then
		if moveStartX == nil then                                                      -- move widget on y axis
			moveStartX = x - widgetPosX
		end
		if moveStartY == nil then                                                      -- move widget on y axis
			moveStartY = y - widgetPosY
		end
		widgetPosX = widgetPosX + dx
		widgetPosY = widgetPosY + dy

		if widgetPosY <= 0 then
			widgetPosY = 0
		end
		if widgetPosY + widgetHeight >= vsy then
			widgetPosY = vsy - widgetHeight
		end
		if widgetPosX < 5 then
			widgetPosX = 5
		end
		if widgetPosX + widgetWidth + 5 > vsx then
			widgetPosX = vsx - widgetWidth - 5
		end
	end
	
end

function widget:TweakMousePress(x, y, button)
	if button == 1 then
		if IsOnButton(x,y,widgetPosX,widgetPosY,widgetPosX+widgetWidth,widgetPosY+widgetHeight) then
			pressedToMove = true
			return true
		end
	else
		return false
	end
end

function widget:TweakMouseRelease(x,y,button)
	pressedToMove = false                                             
end

function IsOnButton(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	if BLcornerX == nil then return false end
	-- check if the mouse is in a rectangle

	return x >= BLcornerX and x <= TRcornerX
						  and y >= BLcornerY
						  and y <= TRcornerY

end

	-----------------
	-- SAVE/LOAD --
	-----------------

function widget:GetConfigData(data)      -- save
	return {
		widgetPosX         = widgetPosX,
		widgetPosY         = widgetPosY,
	}
end

function widget:SetConfigData(data)      -- load
	widgetPosX         	= data.widgetPosX or widgetPosX
	widgetPosY         	= data.widgetPosY or widgetPosY
end
