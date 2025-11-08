local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Map Info",
    desc      = "Draws map info on the bottom left of the map.  Toggle vertical position with /mapinfo_floor",
    author    = "Floris",
    date      = "20 May 2015",
    license   = "GNU GPL, v2 or later",
    layer     = -10,
    enabled   = true,
  }
end


-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry

local scale					= 1
local offset				= 5
local thickness				= 6
local fadeStartHeight		= 800
local fadeEndHeight			= 4800
local dlistAmount			= 20		-- amount of dlists created, one for each opacity value

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spGetCameraPosition	= Spring.GetCameraPosition
local spGetGroundHeight		= Spring.GetGroundHeight
local spIsAABBInView		= Spring.IsAABBInView

local glColor           = gl.Color
local glScale           = gl.Scale
local glPushMatrix      = gl.PushMatrix
local glPopMatrix       = gl.PopMatrix
local glTranslate       = gl.Translate
local glBeginEnd        = gl.BeginEnd
local glVertex          = gl.Vertex
local glBlending		= gl.Blending
local glCallList		= gl.CallList
local glDeleteList		= gl.DeleteList

local glDepthTest       = gl.DepthTest
local glRotate          = gl.Rotate

local vsx,vsy = spGetViewGeometry()

local mapInfoWidth = 400	-- minimum width
local mapinfoList = {}

local font, mapInfoBoxHeight

local success, mapinfo = pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs

function widget:ViewResize()
	vsx,vsy = spGetViewGeometry()

	font = WG['fonts'].getFont()

	for opacity, list in pairs(mapinfoList) do
		glDeleteList(list)
		mapinfoList[opacity] = nil
	end
end

local function createMapinfoList(opacityMultiplier)
	mapinfoList[opacityMultiplier] = gl.CreateList( function()
		local textOpacity = 0.85
		local textSize = 12
		local textOffsetX = 11
		local textOffsetY = 16
		local usedTextOffsetY = textOffsetY + (offset/2)
		local length = math.max(mapInfoWidth, (font:GetTextWidth(Game.mapDescription)*textSize) + 45)

		glDepthTest(true)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		glTranslate(offset, mapInfoBoxHeight-offset, Game.mapSizeZ+0.01)
		glPushMatrix()

		glScale(scale,scale,scale)
		glRotate(90,0,-1,0)
		glRotate(180,1,0,0)

		local height = 90
		local thickness = -(thickness*scale)
		glBeginEnd(GL.QUADS,function()
			glColor(0.12,0.12,0.12,0.4*opacityMultiplier*opacityMultiplier)
			glVertex( height, 0        , 0);         -- Top Right Of The Quad (Top)
			glVertex( 0     , 0        , 0);         -- Top Left Of The Quad (Top)
			glVertex( 0     , 0        , length);    -- Bottom Left Of The Quad (Top)
			glVertex( height, 0        , length);    -- Bottom Right Of The Quad (Top)

			glVertex( height, 0        , length);    -- Top Right Of The Quad (Front)
			glVertex( 0     , 0        , length);    -- Top Left Of The Quad (Front)
			glVertex( 0     ,-thickness, length);    -- Bottom Left Of The Quad (Front)
			glVertex( height,-thickness, length);    -- Bottom Right Of The Quad (Front)

			glVertex( height,-thickness, 0);         -- Top Right Of The Quad (Back)
			glVertex( 0     ,-thickness, 0);         -- Top Left Of The Quad (Back)
			glVertex( 0     , 0        , 0);         -- Bottom Left Of The Quad (Back)
			glVertex( height, 0        , 0);         -- Bottom Right Of The Quad (Back)

			glVertex( 0     , 0        , length);    -- Top Right Of The Quad (Left)
			glVertex( 0     , 0        , 0);         -- Top Left Of The Quad (Left)
			glVertex( 0     ,-thickness, 0);         -- Bottom Left Of The Quad (Left)
			glVertex( 0     ,-thickness, length);    -- Bottom Right Of The Quad (Left)

			glVertex( height, 0        , 0);         -- Top Right Of The Quad (Right)
			glVertex( height, 0        , length);    -- Top Left Of The Quad (Right)
			glVertex( height,-thickness, length);    -- Bottom Left Of The Quad (Right)
			glVertex( height,-thickness, 0);         -- Bottom Right Of The Quad (Right)


			glColor(0.05,0.05,0.05,0.4*opacityMultiplier*opacityMultiplier)
			glVertex( height,-thickness, length);    -- Top Right Of The Quad (Bottom)
			glVertex( 0     ,-thickness, length);    -- Top Left Of The Quad (Bottom)
			glVertex( 0     ,-thickness, 0);         -- Bottom Left Of The Quad (Bottom)
			glVertex( height,-thickness, 0);         -- Bottom Right Of The Quad (Bottom)
		end)

		glRotate(180,1,0,0)
		glRotate(90,0,1,0)

		glRotate(90,1,0,0)
		glTranslate(0,3,0)

		glRotate(180,1,0,0)

		-- map name
		font:Begin()
		local text = Game.mapName
		font:SetTextColor(1,1,1,(textOpacity*1.12)*opacityMultiplier)
		font:Print(text, textOffsetX,-usedTextOffsetY,14,"n")
		font:SetTextColor(0,0,0,textOpacity*0.12*opacityMultiplier)
		font:Print(text, textOffsetX+0.5,-usedTextOffsetY-0.9,14,"n")

		--map description
		usedTextOffsetY = usedTextOffsetY+textOffsetY
		text = Game.mapDescription
		font:SetTextColor(1,1,1,textOpacity*0.6*opacityMultiplier)
		font:Print(text, textOffsetX,-usedTextOffsetY,textSize,"n")


		if mapinfo and mapinfo.author and mapinfo.author ~= '' then
			usedTextOffsetY = usedTextOffsetY+textOffsetY
			text = Game.mapDescription
			font:SetTextColor(1,1,1,textOpacity*0.6*opacityMultiplier)
			font:Print(Spring.I18N('ui.mapinfo.author')..':  '..mapinfo.author, textOffsetX,-usedTextOffsetY+0.8,textSize,"n")
		end

		--map size
		usedTextOffsetY = usedTextOffsetY+textOffsetY
		text = Game.mapDescription
		font:SetTextColor(1,1,1,textOpacity*0.6*opacityMultiplier)
		font:Print(Game.mapX.. " x "..Game.mapY, textOffsetX,-usedTextOffsetY+0.8,textSize,"n")
		font:End()

		glPopMatrix()
		glTranslate(-offset, -mapInfoBoxHeight-offset, -Game.mapSizeZ)
		glColor(1,1,1,1)
		glScale(1,1,1)
		glDepthTest(false)
	end)
end

local function Init()

	if (font:GetTextWidth(Game.mapDescription) * 12) > mapInfoWidth then
		--mapInfoWidth = (font:GetTextWidth(Game.mapDescription) * 12) + 33
	end
	mapInfoBoxHeight = spGetGroundHeight(0, Game.mapSizeZ)

	-- find the lowest map height
	for i=mathFloor(offset*scale), mathFloor((mapInfoWidth+offset)*scale) do
		if spGetGroundHeight(i, Game.mapSizeZ) < mapInfoBoxHeight then
			mapInfoBoxHeight = spGetGroundHeight(i, Game.mapSizeZ)
		end
	end
end

function widget:GameFrame(gf)
	if gf == 1 then
		local prevMapInfoBoxHeight = mapInfoBoxHeight
		mapInfoBoxHeight = spGetGroundHeight(0, Game.mapSizeZ)
		if mapInfoBoxHeight ~= prevMapInfoBoxHeight then
			for opacity, list in pairs(mapinfoList) do
				glDeleteList(mapinfoList[opacity])
				mapinfoList[opacity] = nil
			end
		end
	end
end

function widget:Initialize()
	widget:ViewResize()
	Init()
end

function widget:Shutdown()
	for opacity, list in pairs(mapinfoList) do
		glDeleteList(mapinfoList[opacity])
		mapinfoList[opacity] = nil
	end
end

function widget:DrawWorld()
	if Spring.IsGUIHidden() then return end

	if spIsAABBInView(offset, mapInfoBoxHeight, Game.mapSizeZ,   mapInfoWidth*scale, mapInfoBoxHeight+(thickness*scale), Game.mapSizeZ) then
		local camX, camY, camZ = spGetCameraPosition()
		local camDistance = math.diag(camX - (mapInfoWidth/2)*scale, camY - mapInfoBoxHeight, camZ - Game.mapSizeZ)
		local opacityMultiplier = (1 - (camDistance-fadeStartHeight) / (fadeEndHeight-fadeStartHeight))
		if opacityMultiplier > 1 then
			opacityMultiplier = 1
		end
		if opacityMultiplier > 0.05 then
			opacityMultiplier = mathFloor(opacityMultiplier * dlistAmount)/dlistAmount

			if mapinfoList[opacityMultiplier] == nil then
				createMapinfoList(opacityMultiplier)
			end
			glCallList(mapinfoList[opacityMultiplier])
		end
	end
end
