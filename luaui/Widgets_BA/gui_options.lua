
function widget:GetInfo()
return {
	name    = "Options",
	desc    = "",
	author  = "Floris",
	date    = "September 2016",
	layer   = 20000,
	enabled = true,
	handler = true,
}
end

--[[
--   Add option, at:
--   function init
--
--   Apply new option value:
--   function applyOptionValue
--
--	 Load widget data (to get settings for when widget is disabled):
--   function loadAllWidgetData
--
]]--

local maxNanoParticles = 4000

local cameraTransitionTime = 0.2
local cameraPanTransitionTime = 0.03

local playSounds = true
local buttonclick = 'LuaUI/Sounds/tock.wav'
local paginatorclick = 'LuaUI/Sounds/buildbar_waypoint.wav'
local sliderdrag = 'LuaUI/Sounds/buildbar_rem.wav'
local selectclick = 'LuaUI/Sounds/buildbar_click.wav'
local selectunfoldclick = 'LuaUI/Sounds/buildbar_hover.wav'
local selecthoverclick = 'LuaUI/Sounds/hover.wav'
local toggleonclick = 'LuaUI/Sounds/switchon.wav'
local toggleoffclick = 'LuaUI/Sounds/switchoff.wav'

local loadedFontSize = 32
local font = gl.LoadFont("LuaUI/Fonts/FreeSansBold.otf", loadedFontSize, 16,2)

local bgcorner = "LuaUI/Images/bgcorner.png"
local bgcorner1 = ":n:".."LuaUI/Images/bgcorner1.png" -- only used to draw dropdown arrow
local backwardTex = "LuaUI/Images/backward.dds"
local forwardTex = "LuaUI/Images/forward.dds"
local glowTex = "LuaUI/Images/glow2.dds"

local bgMargin = 6

local closeButtonSize = 30
local screenHeight = 520-bgMargin-bgMargin
local screenWidth = 1050-bgMargin-bgMargin

local textareaMinLines = 10		-- wont scroll down more, will show at least this amount of lines 

local customScale = 1

local startLine = 1

local vsx,vsy = Spring.GetViewGeometry()
local screenX = (vsx*0.5) - (screenWidth/2)
local screenY = (vsy*0.5) + (screenHeight/2)

local wsx,wsy,wpx,wpy = Spring.GetWindowGeometry()
local ssx,ssy,spx,spy = Spring.GetScreenGeometry()

local spIsGUIHidden = Spring.IsGUIHidden

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glRect = gl.Rect
local glTexRect = gl.TexRect
local glRotate = gl.Rotate
local glTexture = gl.Texture
local glText = gl.Text
local glShape = gl.Shape
local glGetTextWidth = gl.GetTextWidth
local glGetTextHeight = gl.GetTextHeight

local bgColorMultiplier = 0

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale

local GL_FILL = GL.FILL
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_LINE_STRIP = GL.LINE_STRIP

local widgetScale = 1
local vsx, vsy = Spring.GetViewGeometry()
local resolutionX, resolutionY = Spring.GetScreenGeometry()

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)

local options = {}
local optionGroups = {}
local optionButtons = {}
local optionHover = {}
local optionSelect = {}

local widgetOptionColor = '\255\160\160\160'

local luaShaders = tonumber(Spring.GetConfigInt("ForceShaders",1) or 0)

local presetNames = {'lowest','low','medium','high','ultra'}	-- defined so these get listed in the right order
local presets = {
	lowest = {
		bloom = false,
		bloomdeferred = false,
		water = 1,
		mapedgeextension = false,
		lighteffects = false,
		lighteffects_deferred = false,
		lighteffects_heatdistortion = false,
		lups = false,
		lupsreflectionrefraction = false,
		snow = false,
		particles = 10000,
		nanoparticles = 1500,
		nanobeamamount = 2,
		grassdetail = 0,
		treeradius = 0,
		treewind = false,
		advsky = false,
		outline = false,
		guishader = false,
		shadows = false,
		advmapshading = false,
		advmodelshading = false,
		normalmapping = false,
		decals = 0,
		grounddetail = 60,
		darkenmap_darkenfeatures = false,
		enemyspotter_highlight = false,
	},
	low = {
		bloom = false,
		bloomdeferred = false,
		water = 2,
		mapedgeextension = false,
		lighteffects = true,
		lighteffects_deferred = false,
		lighteffects_heatdistortion = false,
		lups = true,
		lupsreflectionrefraction = false,
		snow = false,
		particles = 15000,
		nanoparticles = 3000,
		nanobeamamount = 4,
		grassdetail = 0,
		treeradius = 200,
		treewind = false,
		advsky = false,
		outline = false,
		guishader = false,
		shadows = false,
		advmapshading = true,
		advmodelshading = true,
		normalmapping = false,
		decals = 0,
		grounddetail = 90,
		darkenmap_darkenfeatures = false,
		enemyspotter_highlight = false,
	},
	medium = {
		bloom = false,
		bloomdeferred = true,
		water = 4,
		mapedgeextension = true,
		lighteffects = true,
		lighteffects_deferred = true,
		lighteffects_heatdistortion = true,
		lups = true,
		lupsreflectionrefraction = false,
		snow = true,
		particles = 20000,
		nanoparticles = 5000,
		nanobeamamount = 7,
		grassdetail = 0,
		treeradius = 400,
		treewind = true,
		advsky = false,
		outline = false,
		guishader = false,
		shadows = false,
		advmapshading = true,
		advmodelshading = true,
		normalmapping = true,
		decals = 1,
		grounddetail = 140,
		darkenmap_darkenfeatures = false,
		enemyspotter_highlight = false,
	},
	high = {
		bloom = true,
		bloomdeferred = true,
		water = 3,
		mapedgeextension = true,
		lighteffects = true,
		lighteffects_deferred = true,
		lighteffects_heatdistortion = true,
		lups = true,
		lupsreflectionrefraction = true,
		snow = true,
		particles = 30000,
		nanoparticles = 9000,
		nanobeamamount = 12,
		grassdetail = 0,
		treeradius = 800,
		treewind = true,
		advsky = true,
		outline = true,
		guishader = true,
		shadows = true,
		advmapshading = true,
		advmodelshading = true,
		normalmapping = true,
		decals = 2,
		grounddetail = 180,
		darkenmap_darkenfeatures = false,
		enemyspotter_highlight = false,
	},
	ultra = {
		bloom = true,
		bloomdeferred = true,
		water = 5,
		mapedgeextension = true,
		lighteffects = true,
		lighteffects_deferred = true,
		lighteffects_heatdistortion = true,
		lups = true,
		lupsreflectionrefraction = true,
		snow = true,
		particles = 40000,
		nanoparticles = 15000,
		nanobeamamount = 20,
		grassdetail = 0,
		treeradius = 800,
		treewind = true,
		advsky = true,
		outline = true,
		guishader = true,
		shadows = true,
		advmapshading = true,
		advmodelshading = true,
		normalmapping = true,
		decals = 3,
		grounddetail = 200,
		darkenmap_darkenfeatures = true,
		enemyspotter_highlight = true,
	},
}
local customPresets = {}

--if VFS.FileExists("LuaUI/configs/options.lua",VFS.ZIP) then
----if io.open("LuaUI/configs/options.lua",'r') ~= nil then -- file exists?
--	Spring.Echo("Options: loading external options config")
--	include("configs/options.lua")
--end

function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
  screenX = (vsx*0.5) - (screenWidth/2)
  screenY = (vsy*0.5) + (screenHeight/2)
  widgetScale = (0.5 + (vsx*vsy / 5700000)) * customScale
  if windowList then gl.DeleteList(windowList) end
  windowList = gl.CreateList(DrawWindow)
end

local showOnceMore = false		-- used because of GUI shader delay

local showOptionsToggleButton = false
local textSize		= 1
local textMargin	= 0.25
local lineWidth		= 0.0625

local posX = 0.947
local posY = 0.965
local buttonGL
local startPosX = posX


local engineVersion = 100 -- just filled this in here incorrectly but old engines arent used anyway
if Engine and Engine.version then
	local function Split(s, separator)
		local results = {}
		for part in s:gmatch("[^"..separator.."]+") do
			results[#results + 1] = part
		end
		return results
	end
	engineVersion = Split(Engine.version, '-')
	if engineVersion[2] ~= nil and engineVersion[3] ~= nil then
		engineVersion = tonumber(string.gsub(engineVersion[1], '%.', '')..engineVersion[2])
	else
		engineVersion = tonumber(Engine.version)
	end
elseif Game and Game.version then
	engineVersion = tonumber(Game.version)
end


local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl)
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

	local offset = 0.07		-- texture offset, because else gaps could show

	-- bottom left
	if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- bottom right
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- top left
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl)
	gl.Texture(false)
end

function DrawButton()
  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
	gl.Color(0,0,0,0.8) 
	RectRound(-1,-0.5,5.5,1.5,0.25, 2,2,2,2)
	local vertices = {
		{v = {0, 1, 0}},
		{v = {0, 0, 0}},
		{v = {1, 0, 0}},
	}
	glShape(GL_LINE_STRIP, vertices)
  glText("Settings", textMargin, textMargin, textSize, "nos")
end

function lines(str)
  local t = {}
  local function helper(line) t[#t+1]=line return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

function tableMerge(t1, t2)
	for k,v in pairs(t2) do
		if type(v) == "table" then
			if type(t1[k] or false) == "table" then
				tableMerge(t1[k] or {}, t2[k] or {})
			else
				t1[k] = v
			end
		else
			t1[k] = v
		end
	end
	return t1
end

function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function getOptionByID(id)
	for i, option in pairs(options) do
		if option.id == id then
			return i
		end
	end
	return false
end


function orderOptions()
	local groupOptions = {}
	for id,group in pairs(optionGroups) do
		groupOptions[group.id] = {}
	end
	for oid,option in pairs(options) do
		if option.type ~= 'label' then
			groupOptions[option.group][#groupOptions[option.group]+1] = option
		end
	end
	local newOptions = {}
	local newOptionsCount = 0
	for id,group in pairs(optionGroups) do
		grOptions = groupOptions[group.id]
		if #grOptions > 0 then
			local name = group.name
			if group.id == 'gfx' then
				name = group.name..'                                          \255\130\130\130'..vsx..' x '..vsy
			end
			newOptionsCount = newOptionsCount +1
			newOptions[newOptionsCount] = {id="group_"..group.id, name=name, type="label"}
		end
		for oid,option in pairs(grOptions) do
			newOptionsCount = newOptionsCount +1
			newOptions[newOptionsCount] = option
		end
	end
	options = deepcopy(newOptions)
end


function mouseoverGroupTab(id)
	if optionGroups[id].id == currentGroupTab then return end

	local tabFontSize = 16
	local groupMargin = bgMargin/1.7
	gl.Color(0.4,0.4,0.4,0.3)
	RectRound(groupRect[id][1]+groupMargin, groupRect[id][2], groupRect[id][3]-groupMargin, groupRect[id][4]-groupMargin, 8, 1,1,0,0)
	font:Begin()
	font:SetTextColor(1,0.88,0.6,1)
	font:SetOutlineColor(0,0,0,0.4)
	font:Print(optionGroups[id].name, groupRect[id][1]+((groupRect[id][3]-groupRect[id][1])/2), screenY+bgMargin+8, tabFontSize, "con")
	font:End()
end

local startColumn = 1		-- used for navigation
local maxShownColumns = 3
local maxColumnRows = 0 	-- gets calculated
local totalColumns = 0 		-- gets calculated
function DrawWindow()

	orderOptions()

	local x = screenX --rightwards
	local y = screenY --upwards
	-- background
	gl.Color(0,0,0,0.8)
	RectRound(x-bgMargin,y-screenHeight-bgMargin,x+screenWidth+bgMargin,y+bgMargin,8, 0,1,1,1)
	-- content area
	if currentGroupTab then
		gl.Color(0.4,0.4,0.4,0.15)
	else
		gl.Color(0.33,0.33,0.33,0.15)
	end
	RectRound(x,y-screenHeight,x+screenWidth,y,6)

	--[[ close button
	local size = closeButtonSize*0.7
	local width = size*0.055
  gl.Color(1,1,1,1)
	gl.PushMatrix()
		gl.Translate(screenX+screenWidth-(closeButtonSize/2),screenY-(closeButtonSize/2),0)
  	gl.Rotate(-45,0,0,1)
  	gl.Rect(-width,size/2,width,-size/2)
  	gl.Rotate(90,0,0,1)
  	gl.Rect(-width,size/2,width,-size/2)
	gl.PopMatrix()]]--

	-- title
	local title = "Options"
	local titleFontSize = 18
	titleRect = {x-bgMargin, y+bgMargin, x+(glGetTextWidth(title)*titleFontSize)+27-bgMargin, y+37 }

	-- group tabs
	local tabFontSize = 16
	local xpos = titleRect[3]
	local groupMargin = bgMargin/1.7
	groupRect = {}
	for id,group in pairs(optionGroups) do
		groupRect[id] = {xpos, y+(bgMargin/2), xpos+(glGetTextWidth(group.name)*tabFontSize)+27, y+37}
		xpos = groupRect[id][3]
		if currentGroupTab == nil or currentGroupTab ~= group.id then
			gl.Color(0,0,0,0.8)
			RectRound(groupRect[id][1], groupRect[id][2]+(bgMargin/2), groupRect[id][3], groupRect[id][4], 8, 1,1,0,0)
			gl.Color(0.62,0.5,0.22,0.18)
			RectRound(groupRect[id][1]+groupMargin, groupRect[id][2], groupRect[id][3]-groupMargin, groupRect[id][4]-groupMargin, 8, 1,1,0,0)
			font:Begin()
			font:SetTextColor(0.6,0.51,0.38,1)
			font:SetOutlineColor(0,0,0,0.4)
			font:Print(group.name, groupRect[id][1]+((groupRect[id][3]-groupRect[id][1])/2), y+bgMargin+8, tabFontSize, "con")
			font:End()
		else
			gl.Color(0,0,0,0.8)
			RectRound(groupRect[id][1], groupRect[id][2]+(bgMargin/2), groupRect[id][3], groupRect[id][4], 8, 1,1,0,0)
			gl.Color(0.4,0.4,0.4,0.15)
			RectRound(groupRect[id][1]+groupMargin, groupRect[id][2]+(bgMargin/2)-bgMargin, groupRect[id][3]-groupMargin, groupRect[id][4]-groupMargin, 8, 1,1,0,0)
			font:Begin()
			font:SetTextColor(1,0.75,0.4,1)
			font:SetOutlineColor(0,0,0,0.4)
			font:Print(group.name, groupRect[id][1]+((groupRect[id][3]-groupRect[id][1])/2), y+bgMargin+8, tabFontSize, "con")
			font:End()
		end
	end

	-- title drawing
	gl.Color(0,0,0,0.8)
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 8, 1,1,0,0)

	font:Begin()
	font:SetTextColor(1,1,1,1)
	font:SetOutlineColor(0,0,0,0.4)
	font:Print(title, x-bgMargin+(titleFontSize*0.75), y+bgMargin+8, titleFontSize, "on")
	font:End()

	local width = screenWidth/3
	--gl.Color(0.66,0.66,0.66,0.08)
	--RectRound(x+width+width+6,y-screenHeight,x+width+width+width,y,6)

	-- description background
	gl.Color(0.55,0.48,0.22,0.14)
	RectRound(x,y-screenHeight,x+width+width,y-screenHeight+90,6)

	-- draw options
	local oHeight = 15
	local oPadding = 6
	y = y - oPadding - 11
	local oWidth = (screenWidth/3)-oPadding-oPadding
	local yHeight = screenHeight-102-oPadding
	local xPos = x + oPadding + 5
	local xPosMax = xPos + oWidth - oPadding - oPadding
	local yPosMax = y-yHeight
	local boolPadding = 3.5
	local boolWidth = 40
	local sliderWidth = 110
	local selectWidth = 140
	local i = 0
	local rows = 0
	local column = 1
	local drawColumnPos = 1

	maxColumnRows = math.floor((y-yPosMax+oPadding) / (oHeight+oPadding+oPadding))
	local numOptions = #options
	if currentGroupTab ~= nil then
		numOptions = 0
		for oid,option in pairs(options) do
			if option.group == currentGroupTab then
				numOptions = numOptions + 1
			end
		end
	end
	totalColumns = math.ceil(numOptions / maxColumnRows)

	optionButtons = {}
	optionHover = {}


	-- draw navigation... backward/forward
	if totalColumns > maxShownColumns then
		local buttonSize = 52
		local buttonMargin = 13
		local startX = x+screenWidth
		local startY = screenY-screenHeight+buttonMargin

		glColor(1,1,1,1)

		if (startColumn-1) + maxShownColumns  <  totalColumns then
			optionButtonForward = {startX-buttonSize-buttonMargin, startY, startX-buttonMargin, startY+buttonSize}
			glColor(1,1,1,1)
			glTexture(forwardTex)
			glTexRect(optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4])
		else
			optionButtonForward = nil
		end

		glColor(1,1,1,0.4)
		glText(math.ceil(startColumn/maxShownColumns)..' / '..math.ceil(totalColumns/maxShownColumns), startX-(buttonSize*2.6)-buttonMargin, startY+buttonSize/2.6, buttonSize/2.9, "rn")

		if startColumn > 1 then
			if optionButtonForward == nil then
				optionButtonBackward = {startX-buttonSize-buttonMargin, startY, startX-buttonMargin, startY+buttonSize }
			else
				optionButtonBackward = {startX-(buttonSize*2)-buttonMargin-(buttonMargin/1.5), startY, startX-(buttonSize*1)-buttonMargin-(buttonMargin/1.5), startY+buttonSize}
			end
			glColor(1,1,1,1)
			glTexture(backwardTex)
			glTexRect(optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4])
		else
			optionButtonBackward = nil
		end
	end

	-- draw options
	for oid,option in pairs(options) do
		if currentGroupTab == nil or option.group == currentGroupTab then
			yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
			if yPos-oHeight < yPosMax then
				i = 0
				column = column + 1
				if column >= startColumn and rows > 0 then
					drawColumnPos = drawColumnPos + 1
				end
				if drawColumnPos > 3 then
					break
				end
				if rows > 0 then
					xPos = x + (( (screenWidth/3))*(drawColumnPos-1))
					xPosMax = xPos + oWidth
				end
				yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
			end

			if column >= startColumn then
				rows = rows + 1
				--option name
				color = '\255\225\225\225  '
				if option.type == 'label' then
					color = '\255\235\200\125'
				end
				glText(color..option.name, xPos+(oPadding/2), yPos-(oHeight/3)-oPadding, oHeight, "no")

				-- define hover area
				optionHover[oid] = {xPos, yPos-oHeight-oPadding, xPosMax, yPos+oPadding}

				-- option controller
				local rightPadding = 4
				if option.type == 'bool' then
					optionButtons[oid] = {}
					optionButtons[oid] = {xPosMax-boolWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos}
					glColor(1,1,1,0.11)
					RectRound(xPosMax-boolWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos, 3)
					if option.value == true then
						glColor(0.66,0.92,0.66,1)
						RectRound(xPosMax-oHeight+boolPadding-rightPadding, yPos-oHeight+boolPadding, xPosMax-boolPadding-rightPadding, yPos-boolPadding, 2.5)
						local boolGlow = boolPadding*3.5
						glColor(0.66,1,0.66,0.5)
						glTexture(glowTex)
						glTexRect(xPosMax-oHeight+boolPadding-rightPadding-boolGlow, yPos-oHeight+boolPadding-boolGlow, xPosMax-boolPadding-rightPadding+boolGlow, yPos-boolPadding+boolGlow)
						glColor(0.55,1,0.55,0.09)
						glTexture(glowTex)
						glTexRect(xPosMax-oHeight+boolPadding-rightPadding-(boolGlow*3), yPos-oHeight+boolPadding-(boolGlow*3), xPosMax-boolPadding-rightPadding+(boolGlow*3), yPos-boolPadding+(boolGlow*3))
					elseif option.value == 0.5 then
						glColor(0.91,0.82,0.66,1)
						RectRound(xPosMax-(boolWidth/1.9)+boolPadding-rightPadding, yPos-oHeight+boolPadding, xPosMax-(boolWidth/1.9)+oHeight-boolPadding-rightPadding, yPos-boolPadding, 2.5)
					else
						glColor(0.9,0.66,0.66,1)
						RectRound(xPosMax-boolWidth+boolPadding-rightPadding, yPos-oHeight+boolPadding, xPosMax-boolWidth+oHeight-boolPadding-rightPadding, yPos-boolPadding, 2.5)
				   end

				elseif option.type == 'slider' then
					local sliderSize = oHeight*0.75
					local sliderPos = (option.value-option.min) / (option.max-option.min)
					glColor(1,1,1,0.11)
					RectRound(xPosMax-(sliderSize/2)-sliderWidth-rightPadding, yPos-((oHeight/7)*4.2), xPosMax-(sliderSize/2)-rightPadding, yPos-((oHeight/7)*2.8), 1)
					glColor(0.8,0.8,0.8,1)
					RectRound(xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)-(sliderSize/2)-rightPadding, yPos-oHeight+((oHeight-sliderSize)/2), xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)+(sliderSize/2)-rightPadding, yPos-((oHeight-sliderSize)/2), 3)
					optionButtons[oid] = {xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)-(sliderSize/2)-rightPadding, yPos-oHeight+((oHeight-sliderSize)/2), xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)+(sliderSize/2)-rightPadding, yPos-((oHeight-sliderSize)/2)}
					optionButtons[oid].sliderXpos = {xPosMax-(sliderSize/2)-sliderWidth-rightPadding, xPosMax-(sliderSize/2)-rightPadding}

				elseif option.type == 'select' then
					optionButtons[oid] = {xPosMax-selectWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos}
					glColor(1,1,1,0.11)
					RectRound(xPosMax-selectWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos, 3)
					if option.options[tonumber(option.value)] ~= nil then
					glText(option.options[tonumber(option.value)], xPosMax-selectWidth+5-rightPadding, yPos-(oHeight/3)-oPadding, oHeight*0.85, "no")
				end
					glColor(1,1,1,0.11)
					RectRound(xPosMax-oHeight-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos, 2.5)
					glColor(1,1,1,0.16)
					glTexture(bgcorner1)
					glPushMatrix()
					glTranslate(xPosMax-(oHeight*0.5)-rightPadding, yPos-(oHeight*0.33), 0)
						glRotate(-45,0,0,1)
						glTexRect(-(oHeight*0.25),-(oHeight*0.25),(oHeight*0.25),(oHeight*0.25))
					glPopMatrix()
				end
			end
			i = i + 1
		end
	end
end


function correctMouseForScaling(x,y)
	local interfaceScreenCenterPosX = (screenX+(screenWidth/2))/vsx
	local interfaceScreenCenterPosY = (screenY-(screenHeight/2))/vsy
	x = x - (((x/vsx)-interfaceScreenCenterPosX) * vsx)*((widgetScale-1)/widgetScale)
	y = y - (((y/vsy)-interfaceScreenCenterPosY) * vsy)*((widgetScale-1)/widgetScale)
	return x,y
end

local sec = 0
local lastUpdate = 0
function widget:Update(dt)
	if WG['advplayerlist_api'] and not WG['advplayerlist_api'].GetLockPlayerID() then
		if select(7, Spring.GetMouseState()) then	-- when camera panning
			Spring.SetCameraState(Spring.GetCameraState(), math.min(cameraPanTransitionTime, cameraTransitionTime))
		else
			Spring.SetCameraState(Spring.GetCameraState(), cameraTransitionTime)
		end
	end
	sec = sec + dt
	if show and (sec > lastUpdate + 0.5 or forceUpdate) then
		forceUpdate = nil
		lastUpdate = sec
		local changes = true
		for i, option in ipairs(options) do
			if options[i].widget ~= nil and options[i].type == 'bool' and options[i].value ~= GetWidgetToggleValue(options[i].widget) then
				options[i].value = GetWidgetToggleValue(options[i].widget)
				changes = true
			end
		end
		if changes then
			if windowList then
				gl.DeleteList(windowList)
			end
			windowList = gl.CreateList(DrawWindow)
		end
		options[getOptionByID('sndvolmaster')].value = tonumber(Spring.GetConfigInt("snd_volmaster",40) or 40)	-- update value because other widgets can adjust this too
		if getOptionByID('sndvolmusic') then
			options[getOptionByID('sndvolmusic')].value = tonumber(Spring.GetConfigInt("snd_volmusic",40) or 40)
		end
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOptions)
	if show then
		--on window
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local x,y,ml = Spring.GetMouseState()
		local cx, cy = correctMouseForScaling(x,y)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
			return true
		elseif groupRect ~= nil then
			for id,group in pairs(optionGroups) do
				if IsOnRect(cx, cy, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
					return true
				end
			end
		end
	end
end

function widget:DrawScreen()

  if spIsGUIHidden() then return end

  -- draw the button
  if not buttonGL then
    buttonGL = gl.CreateList(DrawButton)
  end

  if showOptionsToggleButton then
	  glPushMatrix()
		glTranslate(posX*vsx, posY*vsy, 0)
		glScale(17*widgetScale, 17*widgetScale, 1)
		glColor(0, 0, 0, (0.3*bgColorMultiplier))
		glCallList(buttonGL)
	  glPopMatrix()
  end

  -- draw the window
  if not windowList then
    --windowList = gl.CreateList(DrawWindow)
  end

  -- update new slider value
	if sliderValueChanged then
		gl.DeleteList(windowList)
		windowList = gl.CreateList(DrawWindow)
		sliderValueChanged = nil
  end

  if show or showOnceMore then

	  --on window
	  local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
	  local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
	  local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
	  local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
	  local x,y,ml = Spring.GetMouseState()
	  local cx, cy = correctMouseForScaling(x,y)
	  if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
	  	Spring.SetMouseCursor('cursornormal')
	  elseif groupRect ~= nil then
		  for id,group in pairs(optionGroups) do
			  if IsOnRect(cx, cy, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
				  Spring.SetMouseCursor('cursornormal')
				  break
			  end
		  end
	  end
		-- draw the options panel
		glPushMatrix()
			glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
			glScale(widgetScale, widgetScale, 1)
			glCallList(windowList)
			if (WG['guishader_api'] ~= nil) then
				local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
				local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
				local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
				local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
				WG['guishader_api'].InsertRect(rectX1, rectY2, rectX2, rectY1, 'options')
				--WG['guishader_api'].setBlurIntensity(0.0017)
				--WG['guishader_api'].setScreenBlur(true)

				if (WG['guishader_api'] ~= nil and titleRect ~= nil) then
					rectX1 = (titleRect[1] * widgetScale) - ((vsx * (widgetScale-1))/2)
					rectY1 = (titleRect[2] * widgetScale) - ((vsy * (widgetScale-1))/2)
					rectX2 = (titleRect[3] * widgetScale) - ((vsx * (widgetScale-1))/2)
					rectY2 = (titleRect[4] * widgetScale) - ((vsy * (widgetScale-1))/2)
					if groupRect ~= nil then
						local lastID = false
						for id,rect in pairs(groupRect) do
							lastID = id
						end
						if lastID then
							rectX2 = (groupRect[lastID][3] * widgetScale) - ((vsx * (widgetScale-1))/2)
							rectY2 = (groupRect[lastID][4] * widgetScale) - ((vsy * (widgetScale-1))/2)
						end
					end
					WG['guishader_api'].InsertRect(rectX1, rectY2, rectX2, rectY1, 'options_top')
				end
			end
			showOnceMore = false

			-- draw button hover
			local usedScreenX = (vsx*0.5) - ((screenWidth/2)*widgetScale)
			local usedScreenY = (vsy*0.5) + ((screenHeight/2)*widgetScale)

			-- mouseover (highlight and tooltip)

		  	local description = ''
			local x,y,ml = Spring.GetMouseState()
			local cx, cy = correctMouseForScaling(x,y)

			if groupRect ~= nil then
				for id,group in pairs(optionGroups) do
					if IsOnRect(cx, cy, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
						  mouseoverGroupTab(id)
					end
				end
			end
			if optionButtonForward ~= nil and IsOnRect(cx, cy, optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4]) then
				if ml then
					glColor(1,0.91,0.66,0.36)
				else
					glColor(1,1,1,0.14)
				end
				RectRound(optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4], (optionButtonForward[4]-optionButtonForward[2])/8)
			end
			if optionButtonBackward ~= nil and IsOnRect(cx, cy, optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4]) then
				if ml then
					glColor(1,0.91,0.66,0.36)
				else
					glColor(1,1,1,0.14)
				end
				RectRound(optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4], (optionButtonBackward[4]-optionButtonBackward[2])/8)
			end

			if not showSelectOptions then
				for i, o in pairs(optionHover) do
					if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) and options[i].type ~= 'label' then
						glColor(1,1,1,0.055)
						RectRound(o[1]-4, o[2], o[3]+4, o[4], 4)
						if options[i].description ~= nil then
							description = options[i].description
							glText('\255\235\200\125'..options[i].description, screenX+15, screenY-screenHeight+64.5, 16, "no")
						end
						glColor(0.46,0.4,0.3,0.45)
						glText('/option '..options[i].id, screenX+screenWidth*0.659, screenY-screenHeight+8, 14, "nr")
					end
				end
				for i, o in pairs(optionButtons) do
					if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						glColor(1,1,1,0.08)
						RectRound(o[1], o[2], o[3], o[4], 2.5)
						if WG['tooltip'] ~= nil and options[i].type == 'slider' then
							local value = options[i].value
							local decimalValue, floatValue = math.modf(options[i].step)
							if floatValue ~= 0 then
								value = string.format("%."..string.len(string.sub(''..options[i].step, 3)).."f", value)	-- do rounding via a string because floats show rounding errors at times
							end
							WG['tooltip'].ShowTooltip('options_showvalue', value)
						end
					end
				end
			end

			-- draw select options
			if showSelectOptions ~= nil then

				-- highlight all that are affected by presets
				if options[showSelectOptions].id == 'preset' then
					glColor(1,1,1,0.08)
					for optionID, _ in pairs(presets['lowest']) do
						optionKey = getOptionByID(optionID)
						if optionHover[optionKey] ~= nil then
							RectRound(optionHover[optionKey][1], optionHover[optionKey][2]+1.33, optionHover[optionKey][3], optionHover[optionKey][4]-1.33, 2.5)
						end
					end
				end

				local oHeight = optionButtons[showSelectOptions][4] - optionButtons[showSelectOptions][2]
				local oPadding = 4
				y = optionButtons[showSelectOptions][4] -oPadding
				local yPos = y
				--Spring.Echo(oHeight)
				optionSelect = {}
				for i, option in pairs(options[showSelectOptions].options) do
					yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
				end
				glColor(0.22,0.22,0.22,0.85)
				RectRound(optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4], 4)
				glColor(1,1,1,0.07)
				RectRound(optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4], 4)
				for i, option in pairs(options[showSelectOptions].options) do
					yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
					if IsOnRect(cx, cy, optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding) then
						glColor(1,1,1,0.1)
						RectRound(optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding, 4)
						if playSounds and (prevSelectHover == nil or prevSelectHover ~= i) then
							Spring.PlaySoundFile(selecthoverclick, 0.04, 'ui')
						end
						prevSelectHover = i
					end
					optionSelect[#optionSelect+1] = {optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding, i}
					glText('\255\255\255\255'..option, optionButtons[showSelectOptions][1]+7, yPos-(oHeight/2.25)-oPadding, oHeight*0.85, "no")
				end
			elseif prevSelectHover ~= nil then
				prevSelectHover = nil
			end
	 	glPopMatrix()
	else
		if (WG['guishader_api'] ~= nil) then
			local removed = WG['guishader_api'].RemoveRect('options')
			local removed = WG['guishader_api'].RemoveRect('options_top')
			if removed then
				--WG['guishader_api'].setBlurIntensity()
			  WG['guishader_api'].setScreenBlur(false)
			end
		end
  end
	if checkedWidgetDataChanges == nil then
		checkedWidgetDataChanges = true
		loadAllWidgetData()
	end
end

function saveOptionValue(widgetName, widgetApiName, widgetApiFunction, configVar, configValue)
	if widgetHandler.configData[widgetName] == nil then
		widgetHandler.configData[widgetName] = {}
	end
	if widgetHandler.configData[widgetName][configVar[1]] == nil then
		widgetHandler.configData[widgetName][configVar[1]] = {}
	end
	if configVar[2] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]] == nil then
		widgetHandler.configData[widgetName][configVar[1]][configVar[2]] = {}
	end
	if configVar[2] ~= nil then
		if configVar[3] ~= nil then
			widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]] = configValue
		else
			widgetHandler.configData[widgetName][configVar[1]][configVar[2]] = configValue
		end
	else
		widgetHandler.configData[widgetName][configVar[1]] = configValue
	end
	if widgetApiName ~= nil and WG[widgetApiName] ~= nil and WG[widgetApiName][widgetApiFunction] ~= nil then
		WG[widgetApiName][widgetApiFunction](configValue)
	end
end

function applyOptionValue(i, skipRedrawWindow)
	if options[i] == nil then return end

	local id = options[i].id
	if options[i].type == 'bool' then
		local value = 0
		if options[i].value then
			value = 1
		end
		if id == 'advmapshading' then
			Spring.SendCommands("AdvMapShading "..value)
			Spring.SetConfigInt("AdvMapShading",value)

		elseif id == 'advmodelshading' then
			Spring.SendCommands("AdvModelShading "..value)
			Spring.SetConfigInt("AdvModelShading",value)
		elseif id == 'normalmapping' then
			if (Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) ~= 0) or UnitDefNames["armcom_bar"] then
				Spring.SendCommands("luarules normalmapping "..value)
			end
			Spring.SetConfigInt("NormalMapping",value)
		elseif id == 'lupsdynamic' then
			Spring.SetConfigInt("DynamicLups",value)
		elseif id == 'lupsreflectionrefraction' then
			Spring.SetConfigInt("lupsreflectionrefraction",value)
		elseif id == 'treewind' then
			Spring.SendCommands("luarules treewind "..value)
			Spring.SetConfigInt("TreeWind",value)
		elseif id == 'advsky' then
			Spring.SetConfigInt("AdvSky",value)
		elseif id == 'shadows' then
			Spring.SendCommands("Shadows "..value)
		elseif id == 'vsync' then
			Spring.SendCommands("Vsync "..value)
			Spring.SetConfigInt("VSync",value)
		elseif id == 'fullscreen' then
			if value == 1 then
				options[getOptionByID('borderless')].value = false
				applyOptionValue(getOptionByID('borderless'))
			end
			Spring.SendCommands("Fullscreen "..value)
			Spring.SetConfigInt("Fullscreen",value)
		elseif id == 'borderless' then
			Spring.SetConfigInt("WindowBorderless",value)
			if value == 1 then
				options[getOptionByID('fullscreen')].value = false
				applyOptionValue(getOptionByID('fullscreen'))
				Spring.SetConfigInt("WindowPosX",0)
				Spring.SetConfigInt("WindowPosY",0)
				Spring.SetConfigInt("WindowState",0)
			else
				Spring.SetConfigInt("WindowPosX",0)
				Spring.SetConfigInt("WindowPosY",0)
				Spring.SetConfigInt("WindowState",1)
			end
		elseif id == 'screenedgemove' then
			Spring.SetConfigInt("FullscreenEdgeMove",value)
			Spring.SetConfigInt("WindowedEdgeMove",value)
		elseif id == 'scrollinverse' then
			if value == 1 then
				Spring.SetConfigInt("ScrollWheelSpeed",-options[getOptionByID('scrollspeed')].value)
			else
				Spring.SetConfigInt("ScrollWheelSpeed",options[getOptionByID('scrollspeed')].value)
			end
		elseif id == 'simpleminimapcolors' then
			Spring.SendCommands("minimap simplecolors  "..value)
			Spring.SetConfigInt("SimpleMiniMapColors",value)
		elseif id == 'hwcursor' then
			Spring.SendCommands("HardwareCursor "..value)
			Spring.SetConfigInt("HardwareCursor",value)
		elseif id == 'fpstimespeed' then
			Spring.SendCommands("fps "..value)
			Spring.SendCommands("clock "..value)
			Spring.SendCommands("speed "..value)

		elseif id == 'resourcebarcoloring' then
			saveOptionValue('Top Bar', 'topbar', 'setResourceBgTint', {'resourcebarBgTint'}, options[i].value)
		elseif id == 'playerlistcollapse' then
			saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetCollapsable', {'collapsable'}, options[i].value)
		elseif id == 'lockcamera_hideenemies' then
			saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetLockHideEnemies', {'lockcameraHideEnemies'}, options[i].value)
		elseif id == 'lockcamera_los' then
			saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetLockLos', {'lockcameraLos'}, options[i].value)
		elseif id == 'allyselunits_select' then
			saveOptionValue('Ally Selected Units', 'allyselectedunits', 'setSelectPlayerUnits', {'selectPlayerUnits'}, options[i].value)
		elseif id == 'voicenotifs_playtrackedplayernotifs' then
			saveOptionValue('Voice Notifs', 'voicenotifs', 'setPlayTrackedPlayerNotifs', {'playTrackedPlayerNotifs'}, options[i].value)
		elseif id == 'oldicons' then
			saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigOldUnitIcons', {'oldUnitpics'}, options[i].value)
			saveOptionValue('Selected Units Buttons', 'selunitbuttons', 'setOldUnitIcons', {'oldUnitpics'}, options[i].value)
			saveOptionValue('BuildBar', 'buildbar', 'setOldUnitIcons', {'oldUnitpics'}, options[i].value)
			saveOptionValue('Unit Stats', 'unitstats', 'setOldUnitIcons', {'oldUnitpics'}, options[i].value)
			saveOptionValue('Initial Queue', 'initialqueue', 'setOldUnitIcons', {'oldUnitpics'}, options[i].value)
		elseif id == 'buildmenushortcuts' then
			saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigShortcutsInfo', {'shortcutsInfo'}, options[i].value)
		elseif id == 'buildmenuprices' then
			saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigUnitPrice', {'drawPrice'}, options[i].value)
		elseif id == 'buildmenuradaricons' then
			saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigUnitRadaricon', {'drawRadaricon'}, options[i].value)
		elseif id == 'buildmenusounds' then
			saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigPlaySounds', {'playSounds'}, options[i].value)
		elseif id == 'buildmenutooltip' then
			saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigUnitTooltip', {'drawTooltip'}, options[i].value)
		elseif id == 'buildmenubigtooltip' then
			saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigUnitBigTooltip', {'drawBigTooltip'}, options[i].value)
		elseif id == 'buildmenulargeicons' then
			saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigLargeUnitIcons', {'largeUnitIons'}, options[i].value)
		elseif id == 'sameteamcolors' then
			saveOptionValue('Player Color Palette', 'playercolorpalette', 'setSameTeamColors', {'useSameTeamColors'}, options[i].value)
		elseif id == 'commandsfxfilterai' then
			saveOptionValue('Commands FX', 'commandsfx', 'setFilterAI', {'filterAIteams'}, options[i].value)
		elseif id == 'snowmap' then
			saveOptionValue('Snow', 'snow', 'setSnowMap', {'snowMaps',Game.mapName:lower()}, options[i].value)
		elseif id == 'snowautoreduce' then
			saveOptionValue('Snow', 'snow', 'setAutoReduce', {'autoReduce'}, options[i].value)
		elseif id == 'darkenmap_darkenfeatures' then
			saveOptionValue('Darken map', 'darkenmap', 'setDarkenFeatures', {'darkenFeatures'}, options[i].value)
		elseif id == 'teamplatter_skipownteam' then
			saveOptionValue('TeamPlatter', 'teamplatter', 'setSkipOwnTeam', {'skipOwnTeam'}, options[i].value)
		elseif id == 'enemyspotter_highlight' then
			saveOptionValue('EnemySpotter', 'enemyspotter', 'setHighlight', {'useXrayHighlight'}, options[i].value)
		elseif id == 'underconstructiongfx_shader' then
			saveOptionValue('Highlight Selected Units', 'underconstructiongfx', 'setShader', {'useHighlightShader'}, options[i].value)
        elseif id == 'highlightselunits_shader' then
			saveOptionValue('Highlight Selected Units', 'highlightselunits', 'setShader', {'useHighlightShader'}, options[i].value)
		elseif id == 'highlightselunits_teamcolor' then
			saveOptionValue('Highlight Selected Units', 'highlightselunits', 'setTeamcolor', {'useTeamcolor'}, options[i].value)
		elseif id == 'fancyselectedunits_secondline' then
			saveOptionValue('Fancy Selected Units', 'fancyselectedunits', 'setSecondLine', {'showSecondLine'}, options[i].value)
		elseif id == 'lighteffects_heatdistortion' then
			saveOptionValue('Light Effects', 'lighteffects', 'setHeatDistortion', {'enableHeatDistortion'}, options[i].value)
		elseif id == 'lighteffects_nanolaser' then
			saveOptionValue('Light Effects', 'lighteffects', 'setNanolaser', {'enableNanolaser'}, options[i].value)
		elseif id == 'nanobeamicon' then
			Spring.SendCommands("luarules uniticonlasers "..value)
		elseif id == 'lighteffects_thrusters' then
			saveOptionValue('Light Effects', 'lighteffects', 'setThrusters', {'enableThrusters'}, options[i].value)
		elseif id == 'lighteffects_deferred' then
			saveOptionValue('Light Effects', 'lighteffects', 'setDeferred', {'enableDeferred'}, options[i].value)
		elseif id == 'passivebuilders_nanos' then
			saveOptionValue('Passive builders', 'passivebuilders', 'setPassiveNanos', {'passiveNanos'}, options[i].value)
		elseif id == 'passivebuilders_cons' then
			saveOptionValue('Passive builders', 'passivebuilders', 'setPassiveCons', {'passiveCons'}, options[i].value)
		elseif id == 'passivebuilders_labs' then
			saveOptionValue('Passive builders', 'passivebuilders', 'setPassiveLabs', {'passiveLabs'}, options[i].value)
		elseif id == 'defrange_allyair' then
			if widgetHandler.configData["Defense Range"] == nil then
				widgetHandler.configData["Defense Range"] = {}
			end
			if widgetHandler.configData["Defense Range"].enabled == nil then
				widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			end
			saveOptionValue('Defense Range', 'defrange', 'setAllyAir', {'enabled','ally','air'}, options[i].value)
		elseif id == 'defrange_allyground' then
			saveOptionValue('', '', '', {''}, options[i].value)
			if widgetHandler.configData["Defense Range"] == nil then
				widgetHandler.configData["Defense Range"] = {}
			end
			if widgetHandler.configData["Defense Range"].enabled == nil then
				widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			end
			saveOptionValue('Defense Range', 'defrange', 'setAllyGround', {'enabled','ally','ground'}, options[i].value)
		elseif id == 'defrange_allynuke' then
			if widgetHandler.configData["Defense Range"] == nil then
				widgetHandler.configData["Defense Range"] = {}
			end
			if widgetHandler.configData["Defense Range"].enabled == nil then
				widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			end
			saveOptionValue('Defense Range', 'defrange', 'setAllyNuke', {'enabled','ally','nuke'}, options[i].value)
		elseif id == 'defrange_enemyair' then
			if widgetHandler.configData["Defense Range"] == nil then
				widgetHandler.configData["Defense Range"] = {}
			end
			if widgetHandler.configData["Defense Range"].enabled == nil then
				widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			end
			saveOptionValue('Defense Range', 'defrange', 'setEnemyAir', {'enabled','enemy','air'}, options[i].value)
		elseif id == 'defrange_enemyground' then
			if widgetHandler.configData["Defense Range"] == nil then
				widgetHandler.configData["Defense Range"] = {}
			end
			if widgetHandler.configData["Defense Range"].enabled == nil then
				widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			end
			saveOptionValue('Defense Range', 'defrange', 'setEnemyGround', {'enabled','enemy','ground'}, options[i].value)
		elseif id == 'defrange_enemynuke' then
			if widgetHandler.configData["Defense Range"] == nil then
				widgetHandler.configData["Defense Range"] = {}
			end
			if widgetHandler.configData["Defense Range"].enabled == nil then
				widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			end
			saveOptionValue('Defense Range', 'defrange', 'setEnemyNuke', {'enabled','enemy','nuke'}, options[i].value)
		elseif id == 'smartselect_includebuildings' then
			saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuildings', {'selectBuildingsWithMobile'}, options[i].value)
		elseif id == 'smartselect_includebuilders' then
			saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuilders', {'includeBuilders'}, options[i].value)
		elseif id == 'lighteffects' then
			if value ~= 0 then
				if widgetHandler.orderList["Deferred rendering"] ~= nil then
					widgetHandler:EnableWidget("Deferred rendering")
				end
				widgetHandler:EnableWidget("Light Effects")
			else
				if widgetHandler.orderList["Deferred rendering"] ~= nil then
					widgetHandler:DisableWidget("Deferred rendering")
				end
				widgetHandler:DisableWidget("Light Effects")
			end
		elseif id == 'autogroup_immediate' then
			if widgetHandler.configData["Auto Group"] == nil then
				widgetHandler.configData["Auto Group"] = {}
			end
			if widgetHandler.configData["Auto Group"].config == nil then
				widgetHandler.configData["Auto Group"].config = {immediate={value=options[i].value}}
			else
				widgetHandler.configData["Auto Group"].config.immediate.value = options[i].value
			end
			saveOptionValue('Auto Group', 'autogroup', 'setImmediate', {'config','immediate','value'}, options[i].value)
		elseif id == 'resourceprompts' then
			Spring.SetConfigInt("evo_resourceprompts",value)
		elseif string.sub(id, 1, 19) == 'voicenotifs_' then
			local sound = string.sub(id, 20)
			saveOptionValue('Voice Notifs', 'voicenotifs', 'setSound'..sound, {'soundList'}, options[i].value)
		end

		if options[i].widget ~= nil then
			if value == 1 then
				if id == 'bloom' or id == 'bloomdeferred' or id == 'guishader' or id == 'xrayshader' or id == 'snow' or id == 'mapedgeextension' then
					if luaShaders ~= 1 and not enabledLuaShaders then
						Spring.SetConfigInt("ForceShaders", 1)
						enabledLuaShaders = true
					end
				end
			end
			if value == 1 then
				if widgetHandler.orderList[options[i].widget] < 0.5 then
					widgetHandler:EnableWidget(options[i].widget)
				end
				if id == "fancyselectedunits" and getOptionByID('fancyselectedunits_style') then
					options[getOptionByID('fancyselectedunits_style')].options = WG['fancyselectedunits'].getStyleList()
				end
			else
				if widgetHandler.orderList[options[i].widget] > 0 then
					widgetHandler:ToggleWidget(options[i].widget)
				else
					widgetHandler:DisableWidget(options[i].widget)
				end
			end
			forceUpdate = true
			if id == "teamcolors" then
      			Spring.SendCommands("luarules reloadluaui")	-- cause several widgets are still using old colors
			end
		end
	
	elseif options[i].type == 'slider' then
		local value =  options[i].value
		if id == 'msaa' then
			if value > 0 then
				Spring.SetConfigInt("MSAALevel",1)
			else
				Spring.SetConfigInt("MSAALevel",0)
			end
			Spring.SetConfigInt("FSAALevel",0)		-- engine deprecated it in 104.x
			Spring.SetConfigInt("MSAALevel",value)
		elseif id == 'shadowslider' then
			local enabled = 1
			if value == options.min then 
				enabled = 0
			end
			Spring.SendCommands("shadows "..enabled.." "..value)
			Spring.SetConfigInt("shadows", value)
		elseif id == 'shadows_maxquality' then
			if value < options[getOptionByID('shadows_minquality')].value then
				options[getOptionByID('shadows_minquality')].value = value
				saveOptionValue('Shadow Quality Manager', 'shadowmanager', 'setMinQuality', {'maxQuality'}, value)
			end
			saveOptionValue('Shadow Quality Manager', 'shadowmanager', 'setMaxQuality', {'maxQuality'}, value)
		elseif id == 'shadows_minquality' then
			if value > options[getOptionByID('shadows_maxquality')].value then
				options[getOptionByID('shadows_maxquality')].value = value
				saveOptionValue('Shadow Quality Manager', 'shadowmanager', 'setMaxQuality', {'maxQuality'}, value)
			end
			saveOptionValue('Shadow Quality Manager', 'shadowmanager', 'setMinQuality', {'minQuality'}, value)
		elseif id == 'shadows_disablefps' then
			saveOptionValue('Shadow Quality Manager', 'shadowmanager', 'setDisableFps', {'disableFps'}, value)
		elseif id == 'decals' then
			Spring.SetConfigInt("GroundDecals", value)
			Spring.SendCommands("GroundDecals "..value)
			Spring.SetConfigInt("GroundScarAlphaFade", 1)
		elseif id == 'scrollspeed' then
			if options[getOptionByID('scrollinverse')].value then
				Spring.SetConfigInt("ScrollWheelSpeed",-value)
			else
				Spring.SetConfigInt("ScrollWheelSpeed",value)
			end
		elseif id == 'disticon' then
			if Spring.GetConfigInt("distdraw",1) < 10000 then
				Spring.SendCommands("distdraw 10000")
			end
			Spring.SendCommands("disticon "..value)
		elseif id == 'iconscale' then
			Spring.SendCommands("luarules uniticonscale "..value)
		elseif id == 'treeradius' then
			Spring.SetConfigInt("TreeRadius",value)
		elseif id == 'particles' then
			Spring.SetConfigInt("MaxParticles",value)


		elseif id == 'nanobeamamount' then
			Spring.SetConfigInt("NanoBeamAmount",value)
		elseif id == 'nanoparticles' then
			maxNanoParticles = value
			if options[getOptionByID('nanoeffect')].value == 2 then
				Spring.SetConfigInt("MaxNanoParticles",value)
			end
		elseif id == 'grassdetail' then
			Spring.SetConfigInt("GrassDetail",value)
		elseif id == 'grounddetail' then
			Spring.SetConfigInt("GroundDetail", value)
			Spring.SendCommands("GroundDetail "..value)
		elseif id == 'sndvolmaster' then
			Spring.SetConfigInt("snd_volmaster", value)
		elseif id == 'sndvolbattle' then
			Spring.SetConfigInt("snd_volbattle", value)
		elseif id == 'sndvolgeneral' then
			Spring.SetConfigInt("snd_volgeneral", value)
		elseif id == 'sndvolui' then
			Spring.SetConfigInt("snd_volui", value)
		elseif id == 'sndvolunitreply' then
			Spring.SetConfigInt("snd_volunitreply", value)
		elseif id == 'sndairabsorption' then
			Spring.SetConfigInt("snd_airAbsorption", value)
		elseif id == 'sndvolmusic' then
			Spring.SetConfigInt("snd_volmusic", value)
		elseif id == 'crossalpha' then
			Spring.SendCommands("cross "..tonumber(Spring.GetConfigInt("CrossSize",1) or 10).." "..value)
		elseif id == 'darkenmap' then
			saveOptionValue('Darken map', 'darkenmap', 'setMapDarkness', {'maps',Game.mapName:lower()}, value)
		elseif id == 'healthbarsscale' then
			saveOptionValue('Health Bars', 'healthbars', 'setScale', {'barScale'}, value)
		elseif id == 'bloomdeferredbrightness' then
			saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setBrightness', {'glowAmplifier'}, value)
		elseif id == 'bloomdeferredsize' then
			saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setBlursize', {'globalBlursizeMult'}, value)
		elseif id == 'bloombrightness' then
			saveOptionValue('Bloom Shader', 'bloom', 'setBrightness', {'basicAlpha'}, value)
		elseif id == 'bloomsize' then
			saveOptionValue('Bloom Shader', 'bloom', 'setBlursize', {'globalBlursizeMult'}, value)
		elseif id == 'consolemaxlines' then
			saveOptionValue('Red Console (In-game chat only)', 'red_chatonlyconsole', 'setMaxLines', {'Config','console','maxlines'}, value)
			saveOptionValue('Red Console (old)', 'red_console', 'setMaxLines', {'Config','console','maxlines'}, value)
		elseif id == 'consolefontsize' then
			saveOptionValue('Red Console (In-game chat only)', 'red_chatonlyconsole', 'setFontsize', {'fontsizeMultiplier'}, value)
			saveOptionValue('Red Console (old)', 'red_console', 'setFontsize', {'fontsizeMultiplier'}, value)
		elseif id == 'guishaderintensity' then
			saveOptionValue('GUI-Shader', 'guishader_api', 'setBlurIntensity', {'blurIntensity'}, value)
		elseif id == 'guiopacity' then
			Spring.SetConfigFloat("ui_opacity", value)
		elseif id == 'snowamount' then
			saveOptionValue('Snow', 'snow', 'setMultiplier', {'customParticleMultiplier'}, value)
		elseif id == 'commandsfxopacity' then
			saveOptionValue('Commands FX', 'commandsfx', 'setOpacity', {'opacity'}, value)
		elseif id == 'dofintensity' then
			saveOptionValue('Depth of Field', 'dof', 'setIntensity', {'intensity'}, value)
		elseif id == 'minimapiconsize' then
			minimapIconsize = value
			Spring.SetConfigFloat("MinimapIconScale", value)
			Spring.SendCommands("minimap unitsize "..value)		-- spring wont remember what you set with '/minimap iconssize #'
		elseif id == 'lighteffects_brightness' then
			saveOptionValue('Light Effects', 'lighteffects', 'setGlobalBrightness', {'globalLightMult'}, value)
		elseif id == 'lighteffects_radius' then
			saveOptionValue('Light Effects', 'lighteffects', 'setGlobalRadius', {'globalRadiusMult'}, value)
		elseif id == 'lighteffects_laserbrightness' then
			saveOptionValue('Light Effects', 'lighteffects', 'setLaserBrightness', {'globalLightMultLaser'}, value)
		elseif id == 'lighteffects_laserradius' then
			saveOptionValue('Light Effects', 'lighteffects', 'setLaserRadius', {'globalRadiusMultLaser'}, value)
		elseif id == 'lighteffects_life' then
			saveOptionValue('Light Effects', 'lighteffects', 'setLife', {'globalLifeMult'}, value)
		elseif id == 'teamplatter_opacity' then
			saveOptionValue('TeamPlatter', 'teamplatter', 'setOpacity', {'spotterOpacity'}, value)
		elseif id == 'enemyspotter_opacity' then
			saveOptionValue('EnemySpotter', 'enemyspotter', 'setOpacity', {'spotterOpacity'}, value)
		elseif id == 'outline_size' then
			saveOptionValue('Outline', 'outline', 'setSize', {'customSize'}, value)
		elseif id == 'underconstructiongfx_opacity' then
			saveOptionValue('Highlight Selected Units', 'underconstructiongfx', 'setOpacity', {'highlightAlpha'}, value)
		elseif id == 'highlightselunits_opacity' then
			saveOptionValue('Highlight Selected Units', 'highlightselunits', 'setOpacity', {'highlightAlpha'}, value)
		elseif id == 'fancyselectedunits_opacity' then
			saveOptionValue('Fancy Selected Units', 'fancyselectedunits', 'setOpacity', {'spotterOpacity'}, value)
		elseif id == 'fancyselectedunits_baseopacity' then
			saveOptionValue('Fancy Selected Units', 'fancyselectedunits', 'setBaseOpacity', {'baseOpacity'}, value)
		elseif id == 'fancyselectedunits_teamcoloropacity' then
			saveOptionValue('Fancy Selected Units', 'fancyselectedunits', 'setTeamcolorOpacity', {'teamcolorOpacity'}, value)
		elseif id == 'voicenotifs_volume' then
			saveOptionValue('Voice Notifs', 'voicenotifs', 'setVolume', {'volume'}, value)
		elseif id == 'lockcamera_transitiontime' then
			saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetLockTransitionTime', {'transitionTime'}, value)
		elseif id == 'playertv_countdown' then
			saveOptionValue('Player-TV', 'playertv', 'SetPlayerChangeDelay', {'playerChangeDelay'}, value)
		elseif id == 'camerasmoothness' then
			cameraTransitionTime = value
		end

	elseif options[i].type == 'select' then
		local value =  options[i].value
		if id == 'preset' then
			Spring.Echo('Loading preset:   '..options[i].options[value])
			options[i].value = 0
			loadPreset(presetNames[value])
		elseif id == 'water' then
			Spring.SendCommands("water "..(value-1))
			Spring.SendCommands("water "..(value-1))
		elseif id == 'lupseffectlevel' then
			if WG.Lups then
				Spring.SetConfigInt("LupsPriority",value)
				--Spring.Echo("option for lups",value,WG.LupsPriority)
			end
		elseif id == 'nanoeffect' then
			Spring.SetConfigInt("NanoEffect",value)
			if value == 1 then
				Spring.SetConfigInt("MaxNanoParticles",0)
			else
				Spring.SetConfigInt("MaxNanoParticles",maxNanoParticles)
			end
		elseif id == 'iconset' then
			Spring.SendCommands("luarules uniticonset "..options[i].options[value])
		elseif id == 'bloomdeferredquality' then
			saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setPreset', {'qualityPreset'}, value)
		elseif id == 'bloomquality' then
			saveOptionValue('Bloom Shader', 'bloom', 'setPreset', {'qualityPreset'}, value)
		elseif id == 'camera' then
			Spring.SetConfigInt("CamMode",(value-1))
			if value == 1 then
				Spring.SendCommands('viewfps')
			elseif value == 2 then
				Spring.SendCommands('viewta')
			elseif value == 3 then
				Spring.SendCommands('viewspring')
			elseif value == 4 then
				Spring.SendCommands('viewrot')
			elseif value == 5 then
				Spring.SendCommands('viewfree')
			end
		elseif id == 'cursor' then
			saveOptionValue('Cursors', 'cursors', 'setcursor', {'cursorSet'}, options[i].options[value])
		elseif id == 'fancyselectedunits_style' then
			saveOptionValue('Fancy Selected Units', 'fancyselectedunits', 'setStyle', {'currentOption'}, value)
		elseif id == 'resolution' then
			local resolutionX = string.match(options[i].options[options[i].value], '[0-9]*')
			local resolutionY = string.gsub(string.match(options[i].options[options[i].value], 'x [0-9]*'), 'x ', '')
			if tonumber(Spring.GetConfigInt("Fullscreen",1) or 1) == 1 then
				Spring.SendCommands("Fullscreen 0")
				Spring.SetConfigInt("XResolution", tonumber(resolutionX))
				Spring.SetConfigInt("YResolution", tonumber(resolutionY))
				Spring.SendCommands("Fullscreen 1")
			else
				Spring.SendCommands("Fullscreen 1")
				Spring.SetConfigInt("XResolutionWindowed", tonumber(resolutionX))
				Spring.SetConfigInt("YResolutionWindowed", tonumber(resolutionY))
				Spring.SendCommands("Fullscreen 0")
			end
			--options[i].value = 0
		end
	end
	if skipRedrawWindow == nil then
		if windowList then gl.DeleteList(windowList) end
		windowList = gl.CreateList(DrawWindow)
	end
end

function loadPreset(preset)
	for optionID, value in pairs(presets[preset]) do
		local i = getOptionByID(optionID)
		if options[i] ~= nil then
			options[i].value = value
			applyOptionValue(i, true)
		end
	end

	if windowList then gl.DeleteList(windowList) end
	windowList = gl.CreateList(DrawWindow)
end


function widget:KeyPress(key)
	if key == 27 then	-- ESC
		show = false
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)

	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY
end


function round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    if num >= 0 then return math.floor(num * mult + 0.5) / mult
    else return math.ceil(num * mult - 0.5) / mult end
end

function getSliderValue(draggingSlider, cx)
	local sliderWidth = optionButtons[draggingSlider].sliderXpos[2] - optionButtons[draggingSlider].sliderXpos[1]
	local value = (cx - optionButtons[draggingSlider].sliderXpos[1]) / sliderWidth
	value = options[draggingSlider].min + ((options[draggingSlider].max - options[draggingSlider].min) * value)
	if value < options[draggingSlider].min then value = options[draggingSlider].min end
	if value > options[draggingSlider].max then value = options[draggingSlider].max end
	if options[draggingSlider].step ~= nil then
		value = math.floor(value / options[draggingSlider].step) * options[draggingSlider].step
	end
	return value	-- is a string now :(
end

function widget:MouseWheel(up, value)
	local x,y = Spring.GetMouseState()
	local cx, cy = correctMouseForScaling(x,y)
	if show then
		return true
	end
end

function widget:MouseMove(x, y)
	if draggingSlider ~= nil then
		local cx, cy = correctMouseForScaling(x,y)
		local newValue = getSliderValue(draggingSlider,cx)
		if options[draggingSlider].value ~= newValue then
			options[draggingSlider].value = newValue
			sliderValueChanged = true
			applyOptionValue(draggingSlider)
			if playSounds and (lastSliderSound == nil or os.clock() - lastSliderSound > 0.04) then
				lastSliderSound = os.clock()
				Spring.PlaySoundFile(sliderdrag, 0.4, 'ui')
			end
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end


function mouseEvent(x, y, button, release)
	if spIsGUIHidden() then return false end

	if show then
		local cx, cy = correctMouseForScaling(x,y)

		if button == 3 then
			if showSelectOptions ~= nil and options[showSelectOptions].id == 'preset' then
				for i, o in pairs(optionSelect) do
					if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						if presetNames[o[5]] and customPresets[presetNames[o[5]]] ~= nil then
							deletePreset(presetNames[o[5]])
							if playSounds then
								Spring.PlaySoundFile(selectclick, 0.5, 'ui')
							end
							if selectClickAllowHide ~= nil or not IsOnRect(cx, cy, optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4]) then
								showSelectOptions = nil
								selectClickAllowHide = nil
							else
								selectClickAllowHide = true
							end
							return
						end
					end
				end
			end
		elseif button == 1 then
			if release then

				-- navigation buttons
				if optionButtonForward ~=nil and IsOnRect(cx, cy, optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4]) then
					startColumn = startColumn + maxShownColumns
					if startColumn > totalColumns + (maxShownColumns-1) then
						startColumn = (totalColumns-maxShownColumns) + 1
					end
					if playSounds then
						Spring.PlaySoundFile(paginatorclick, 0.6, 'ui')
					end
					showSelectOptions = nil
					selectClickAllowHide = nil
					if windowList then gl.DeleteList(windowList) end
					windowList = gl.CreateList(DrawWindow)
					return
				end
				if optionButtonBackward ~= nil and IsOnRect(cx, cy, optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4]) then
					startColumn = startColumn - maxShownColumns
					if startColumn < 1 then startColumn = 1 end
					if playSounds then
						Spring.PlaySoundFile(paginatorclick, 0.6, 'ui')
					end
					showSelectOptions = nil
					selectClickAllowHide = nil
					if windowList then gl.DeleteList(windowList) end
					windowList = gl.CreateList(DrawWindow)
					return
				end

				-- apply new slider value
				if draggingSlider ~= nil then
					options[draggingSlider].value = getSliderValue(draggingSlider,cx)
					applyOptionValue(draggingSlider)
					draggingSlider = nil
					return
				end

				-- select option
				if showSelectOptions ~= nil then
					for i, o in pairs(optionSelect) do
						if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
							options[showSelectOptions].value = o[5]
							applyOptionValue(showSelectOptions)
							if playSounds then
								Spring.PlaySoundFile(selectclick, 0.5, 'ui')
							end
						end
					end
					if selectClickAllowHide ~= nil or not IsOnRect(cx, cy, optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4]) then
						showSelectOptions = nil
						selectClickAllowHide = nil
					else
						selectClickAllowHide = true
					end
					return
				end
			end


			local tabClicked = false
            if show and groupRect ~= nil then
                for id,group in pairs(optionGroups) do
                    if IsOnRect(cx, cy, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
                        if not release then
                            currentGroupTab = group.id
                            startColumn = 1
                            showSelectOptions = nil
                            selectClickAllowHide = nil
                            if playSounds then
                                Spring.PlaySoundFile(paginatorclick, 0.9, 'ui')
                            end
                        end
                        tabClicked = true
                        returnTrue = true
                    end
                end
            end

			-- on window
			local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			if tabClicked then

			elseif IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then


				if release then

					-- select option
					if showSelectOptions == nil then
						if showPresetButtons then
							for preset, pp in pairs(presets) do
								if IsOnRect(cx, cy, pp.pos[1], pp.pos[2], pp.pos[3], pp.pos[4]) then
									loadPreset(preset)
								end
							end
						end

						for i, o in pairs(optionButtons) do
							if options[i].type == 'bool' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
								options[i].value = not options[i].value
								applyOptionValue(i)
								if playSounds then
									if options[i].value then
										Spring.PlaySoundFile(toggleonclick, 0.75, 'ui')
									else
										Spring.PlaySoundFile(toggleoffclick, 0.75, 'ui')
									end
								end
							elseif options[i].type == 'slider' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then

							elseif options[i].type == 'select' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
							end
						end
					end
				else -- mousepress

					if not showSelectOptions then
						for i, o in pairs(optionButtons) do
							if options[i].type == 'slider' and (IsOnRect(cx, cy, o.sliderXpos[1], o[2], o.sliderXpos[2], o[4]) or IsOnRect(cx, cy, o[1], o[2], o[3], o[4])) then
								draggingSlider = i
								local newValue = getSliderValue(draggingSlider,cx)
								if options[draggingSlider].value ~= newValue then
									options[draggingSlider].value = getSliderValue(draggingSlider,cx)
									applyOptionValue(draggingSlider)
									if playSounds then
										Spring.PlaySoundFile(sliderdrag, 0.3, 'ui')
									end
								end
							elseif options[i].type == 'select' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then

								if playSounds then
									Spring.PlaySoundFile(selectunfoldclick, 0.6, 'ui')
								end
								if showSelectOptions == nil then
									showSelectOptions = i
								elseif showSelectOptions == i then
									--showSelectOptions = nil
								end
							end
						end
					end
				end

				if button == 1 or button == 3 then
					return true
				end
			-- on title
			elseif titleRect ~= nil and IsOnRect(x, y, (titleRect[1] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[2] * widgetScale) - ((vsy * (widgetScale-1))/2), (titleRect[3] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[4] * widgetScale) - ((vsy * (widgetScale-1))/2)) then
				--currentGroupTab = nil
				--startColumn = 1
				returnTrue = true
			elseif not tabClicked then
				if release and draggingSlider == nil then
					showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
					show = false
				end
				return true
			end

			if show then
				if windowList then gl.DeleteList(windowList) end
				windowList = gl.CreateList(DrawWindow)
			end
			if returnTrue then
				return true
			end
		end
	elseif showOptionsToggleButton then
		tx = (x - posX*vsx)/(17*widgetScale)
		ty = (y - posY*vsy)/(17*widgetScale)
		if tx < 0 or tx > 5.25 or ty < -0.25 or ty > 1.4 then return false end
		if release then
			showOnceMore = show		-- show once more because the guishader lags behind, though this will not fully fix it
			show = not show
		end
		if show then
			if windowList then gl.DeleteList(windowList) end
			windowList = gl.CreateList(DrawWindow)
		end
		return true
	end
end

function GetWidgetToggleValue(widgetname)
	if widgetHandler.orderList[widgetname] == nil or widgetHandler.orderList[widgetname] == 0 then
		return false
	elseif widgetHandler.orderList[widgetname] >= 1
			and widgetHandler.knownWidgets ~= nil
			and widgetHandler.knownWidgets[widgetname] ~= nil then
		if widgetHandler.knownWidgets[widgetname].active then
			return true
		else
			return 0.5
		end
	end
end

-- configVar = table, add more entries the deeper the configdata table var is: example: {'Config','console','maxlines'}  (limit = 3 deep)
function loadWidgetData(widgetName, optionId, configVar)
	if widgetHandler.knownWidgets[widgetName] ~= nil then
		if getOptionByID(optionId) and widgetHandler.configData[widgetName] ~= nil and widgetHandler.configData[widgetName][configVar[1]] ~= nil then
			if configVar[2] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]] ~= nil then
				if configVar[3] ~= nil and widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]] ~= nil then
					options[getOptionByID(optionId)].value = widgetHandler.configData[widgetName][configVar[1]][configVar[2]][configVar[3]]
					return true
				else
					options[getOptionByID(optionId)].value = widgetHandler.configData[widgetName][configVar[1]][configVar[2]]
					return true
				end
			elseif options[getOptionByID(optionId)].value ~= widgetHandler.configData[widgetName][configVar[1]] then
				options[getOptionByID(optionId)].value = widgetHandler.configData[widgetName][configVar[1]]
				return true
			end
		end
	end
end


-- loads values via stored game config in luaui/configs
function loadAllWidgetData()
	loadWidgetData("Health Bars", "healthbarsscale", {'barScale'})

	loadWidgetData("Shadow Quality Manager", "shadows_maxquality", {'maxQuality'})
	loadWidgetData("Shadow Quality Manager", "shadows_minquality", {'minQuality'})
	loadWidgetData("Shadow Quality Manager", "shadows_disablefps", {'disableFps'})

	loadWidgetData("Bloom Shader Deferred", "bloomdeferredbrightness", {'glowAmplifier'})
	loadWidgetData("Bloom Shader Deferred", "bloomdeferredsize", {'qualityBlursizeMult'})
	loadWidgetData("Bloom Shader Deferred", "bloomdeferredquality", {'qualityPreset'})

	loadWidgetData("Bloom Shader", "bloombrightness", {'basicAlpha'})
	loadWidgetData("Bloom Shader", "bloomsize", {'globalBlursizeMult'})
	loadWidgetData("Bloom Shader", "bloomquality", {'qualityPreset'})

	loadWidgetData("Red Console (In-game chat only)", "consolemaxlines", {'Config','console','maxlines'})
	loadWidgetData("Red Console (In-game chat only)", "consolefontsize", {'fontsizeMultiplier'})

	loadWidgetData("AdvPlayersList", "lockcamera_hideenemies", {'lockcameraHideEnemies'})
	loadWidgetData("AdvPlayersList", "lockcamera_los", {'lockcameraLos'})
	loadWidgetData("AdvPlayersList", "lockcamera_transitiontime", {'transitionTime'})
	loadWidgetData("AdvPlayersList", "playerlistcollapse", {'collapsable'})

	loadWidgetData("Top Bar", "resourcebarcoloring", {'resourcebarBgTint'})

	loadWidgetData("Ally Selected Units", "allyselunits_select", {'selectPlayerUnits'})

	loadWidgetData("Voice Notifs", "voicenotifs_playtrackedplayernotifs", {'playTrackedPlayerNotifs'})

	loadWidgetData("GUI-Shader", "guishaderintensity", {'blurIntensity'})

	loadWidgetData("Snow", "snowamount", {'customParticleMultiplier'})
	loadWidgetData("Snow", "snowmap", {'snowMaps',Game.mapName:lower()})
	loadWidgetData("Snow", "snowautoreduce", {'autoReduce'})

	loadWidgetData("Commands FX", "commandsfxopacity", {'opacity'})
	loadWidgetData("Commands FX", "commandsfxfilterai", {'filterAIteams'})

	loadWidgetData("Depth of Field", "dofintensity", {'intensity'})

	loadWidgetData("TeamPlatter", "teamplatter_opacity", {'spotterOpacity'})
	loadWidgetData("TeamPlatter", "teamplatter_skipownteam", {'skipOwnTeam'})

	loadWidgetData("EnemySpotter", "enemyspotter_opacity", {'spotterOpacity'})
	loadWidgetData("EnemySpotter", "enemyspotter_highlight", {'useXrayHighlight'})

	loadWidgetData("Outline", "outline_size", {'customSize'})

	loadWidgetData("Under construction gfx", "underconstructiongfx_opacity", {'highlightAlpha'})
	loadWidgetData("Under construction gfx", "underconstructiongfx_shader", {'useHighlightShader'})

	loadWidgetData("Highlight Selected Units", "highlightselunits_opacity", {'highlightAlpha'})
	loadWidgetData("Highlight Selected Units", "highlightselunits_shader", {'useHighlightShader'})
	loadWidgetData("Highlight Selected Units", "highlightselunits_teamcolor", {'useTeamcolor'})

	loadWidgetData("Fancy Selected Units", "fancyselectedunits_style", {'currentOption'})
	loadWidgetData("Fancy Selected Units", "fancyselectedunits_opacity", {'spotterOpacity'})
	loadWidgetData("Fancy Selected Units", "fancyselectedunits_baseopacity", {'baseOpacity'})
	loadWidgetData("Fancy Selected Units", "fancyselectedunits_teamcoloropacity", {'teamcolorOpacity'})
	loadWidgetData("Fancy Selected Units", "fancyselectedunits_secondline", {'showSecondLine'})

	loadWidgetData("Voice Notifs", "voicenotifs_volume", {'volume'})
	loadWidgetData("Player-TV", "playertv_countdown", {'playerChangeDelay'})

	loadWidgetData("Passive builders", "passivebuilders_nanos", {'passiveNanos'})
	loadWidgetData("Passive builders", "passivebuilders_cons", {'passiveCons'})
	loadWidgetData("Passive builders", "passivebuilders_labs", {'passiveLabs'})

	loadWidgetData("Defense Range", "defrange_allyair", {'enabled','ally','air'})
	loadWidgetData("Defense Range", "defrange_allyground", {'enabled','ally','ground'})
	loadWidgetData("Defense Range", "defrange_allynuke", {'enabled','ally','nuke'})
	loadWidgetData("Defense Range", "defrange_enemyair", {'enabled','enemy','air'})
	loadWidgetData("Defense Range", "defrange_enemyground", {'enabled','enemy','ground'})
	loadWidgetData("Defense Range", "defrange_enemynuke", {'enabled','enemy','nuke'})

	loadWidgetData("Light Effects", "lighteffects_brightness", {'globalLightMult'})
	loadWidgetData("Light Effects", "lighteffects_radius", {'globalRadiusMult'})
	loadWidgetData("Light Effects", "lighteffects_laserbrightness", {'globalLightMultLaser'})
	loadWidgetData("Light Effects", "lighteffects_laserradius", {'globalRadiusMultLaser'})
	loadWidgetData("Light Effects", "lighteffects_life", {'globalLifeMult'})
	loadWidgetData("Light Effects", "lighteffects_heatdistortion", {'enableHeatDistortion'})
	loadWidgetData("Light Effects", "lighteffects_deferred", {'enableDeferred'})
	loadWidgetData("Light Effects", "lighteffects_nanolaser", {'enableNanolaser'})
	loadWidgetData("Light Effects", "lighteffects_thrusters", {'enableThrusters'})

	loadWidgetData("Auto Group", "autogroup_immediate", {'config','immediate','value'})

	return changes
end

function lines(str)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

function init()

	local supportedResolutions = {}
	local infolog = VFS.LoadFile("infolog.txt")
	if infolog then
		local fileLines = lines(infolog)
		for i, line in ipairs(fileLines) do
			if addResolutions then
				local resolution = string.match(line, '[0-9]*x[0-9]*')
				if resolution and string.len(resolution) >= 7 then
					local resolution = string.gsub(resolution, "x", " x ")
					local resolutionX = string.match(resolution, '[0-9]*')
					local resolutionY = string.gsub(string.match(resolution, 'x [0-9]*'), 'x ', '')
					if tonumber(resolutionX) >= 640 and tonumber(resolutionY) >= 480 then
						supportedResolutions[#supportedResolutions+1] = resolution
					end
				else
					break
				end
			end
			if string.find(line, '	display=') then
				if addResolutions then
					break
				end
				addResolutions = true
			end
		end
	end

	-- if you want to add an option it should be added here, and in applyOptionValue(), if option needs shaders than see the code below the options definition
	optionGroups = {
		{id='gfx', name='Graphics'},
		{id='ui', name='Interface'},
		{id='snd', name='Sound'},
		{id='control', name='Control'},
		{id='game', name='Game'},
	}
	if not currentGroupTab or Spring.GetGameFrame() == 0 then
		currentGroupTab = optionGroups[1].id
	else
		-- check if group exists
		local found = false
		for id,group in pairs(optionGroups) do
			if group.id == currentGroupTab then
				found = true
				break
			end
		end
		if not found then
			currentGroupTab = optionGroups[1].id
		end
	end

	options = {
		-- PRESET
		{id="preset", group="gfx", name="Load graphics preset", type="select", options=presetNames, value=0, description='This wont set the preset every time you restart a game. So feel free to adjust things.\n\nSave custom preset with /savepreset name\nRightclick to delete a custom preset'},

		--GFX
		{id="resolution", group="gfx", name="Resolution", type="select", options=supportedResolutions, value=0, description='WARNING: sometimes freezes game engine in windowed mode'},
		{id="fullscreen", group="gfx", name="Fullscreen", type="bool", value=tonumber(Spring.GetConfigInt("Fullscreen",1) or 1) == 1},
		{id="borderless", group="gfx", name="Borderless window", type="bool", value=tonumber(Spring.GetConfigInt("WindowBorderless",1) or 1) == 1, description="Changes will be applied next game.\n\n(dont forget to turn off the \'fullscreen\' option next game)"},
		{id="windowpos", group="gfx", widget="Move Window Position", name="Move window position", type="bool", value=GetWidgetToggleValue("Move Window Position"), description='Toggle and move window position with the arrow keys or by dragging'},
		{id="vsync", group="gfx", name="V-sync", type="bool", value=tonumber(Spring.GetConfigInt("VSync",1) or 1) == 1, description=''},
		{id="msaa", group="gfx", name="Anti Aliasing", type="slider", min=0, max=8, step=1, value=tonumber(Spring.GetConfigInt("MSAALevel",1) or 2), description='Enables multisample anti-aliasing. NOTE: Can be expensive!\n\nChanges will be applied next game'},
		{id="advmapshading", group="gfx", name="Advanced map shading", type="bool", value=tonumber(Spring.GetConfigInt("AdvMapShading",1) or 1) == 1, description='When disabled: map shadows aren\'t rendered as well'},
		{id="advmodelshading", group="gfx", name="Advanced model shading", type="bool", value=tonumber(Spring.GetConfigInt("AdvModelShading",1) or 1) == 1},
		{id="normalmapping", group="gfx", name="Extra unit shading", type="bool", value=tonumber(Spring.GetConfigInt("NormalMapping",1) or 1) == 1, description='Adds highlights/darker areas, and even blinking lights to some units'},

		-- only one of these shadow options are shown, depending if "Shadow Quality Manager" widget is active
		{id="shadows", group="gfx", name="Shadows", type="bool", value=tonumber(Spring.GetConfigInt("Shadows",1) or 1) == 1, description='Shadow detail is currently controlled by "Shadow Quality Manager" widget\n...this widget will auto reduce detail when fps gets low.\n\nShadows requires "Advanced map shading" option to be enabled'},
		{id="shadowslider", group="gfx", name="Shadows", type="slider", min=1500, max=6000, step=500, value=tonumber(Spring.GetConfigInt("ShadowMapSize",1) or 2000), description='Set shadow detail\nSlider positioned the very left means shadows will be disabled\n\nShadows requires "Advanced map shading" option to be enabled'},
		{id="shadows_maxquality", group="gfx", name=widgetOptionColor.."   max quality", min=2000, max=8000, step=500, type="slider", value=8000, description='Maximum shadow detail when having high Frames Per Second'},
		{id="shadows_minquality", group="gfx", name=widgetOptionColor.."   min quality", min=2000, max=8000, step=500, type="slider", value=2000, description='Minimum shadow detail when having low Frames Per Second'},
		{id="shadows_disablefps", group="gfx", name=widgetOptionColor.."   disable at FPS", min=0, max=30, step=1, type="slider", value=0, description='Automaticly disables shadows at this average FPS value'},

		{id="water", group="gfx", name="Water type", type="select", options={'basic','reflective','dynamic','reflective&refractive','bump-mapped'}, value=(tonumber(Spring.GetConfigInt("Water",1) or 1)+1)},

		{id="advsky", group="gfx", name="Advanced sky", type="bool", value=tonumber(Spring.GetConfigInt("AdvSky",1) or 1) == 1, description='Enables high resolution clouds\n\nChanges will be applied next game'},

		{id="darkenmap", group="gfx", name="Darken map", min=0, max=0.5, step=0.01, type="slider", value=0, description='Darkens the whole map (not the units)\n\nRemembers setting per map\nUse /resetmapdarkness if you want to reset all stored map settings'},
		{id="darkenmap_darkenfeatures", group="gfx", name=widgetOptionColor.."   darken features", type="bool", value=false, description='Darkens features (trees, wrecks, ect..) along with darken map slider above\n\nNOTE: This setting can be CPU intensive because it cycles through all visible features \nand renders then another time.'},

		{id="bloomdeferred", group="gfx", widget="Bloom Shader Deferred", name="Bloom (unit)", type="bool", value=GetWidgetToggleValue("Bloom Shader Deferred"), description='Unit highlights and lights will glow.\n\n(via deferred rendering = less lag)'},
		{id="bloomdeferredbrightness", group="gfx", name=widgetOptionColor.."   brightness", type="slider", min=0.4, max=1.1, step=0.05, value=1, description=''},
		--{id="bloomdeferredsize", group="gfx", name=widgetOptionColor.."   size", type="slider", min=0.8, max=1.5, step=0.05, value=1, description=''},
		--{id="bloomdeferredquality", group="gfx", name=widgetOptionColor.."   quality", type="select", options={'low','medium'}, value=1, description='Render quality'},

		{id="bloom", group="gfx", widget="Bloom Shader", name="Bloom (global)", type="bool", value=GetWidgetToggleValue("Bloom Shader"), description='Bloom will make the map and units glow\n\n(might result in more laggy experience)'},
		{id="bloombrightness", group="gfx", name=widgetOptionColor.."   brightness", type="slider", min=0.15, max=0.5, step=0.05, value=0.3, description=''},
		{id="bloomsize", group="gfx", name=widgetOptionColor.."   size", type="slider", min=0.75, max=1.5, step=0.05, value=1, description=''},
		--{id="bloomquality", group="gfx", name=widgetOptionColor.."   quality", type="select", options={'low','medium'}, value=1, description='Render quality'},

		{id="outline", group="gfx", widget="Outline", name="Unit outline (expensive)", type="bool", value=GetWidgetToggleValue("Outline"), description='Adds a small outline to all units which makes them crisp\n\nLimits total outlined units to 1000.\nStops rendering outlines when average fps falls below 13.'},
		{id="outline_size", group="gfx", name=widgetOptionColor.."   thickness", min=0.8, max=1.5, step=0.05, type="slider", value=1, description='Set the size of the outline'},

		{id="iconset", group="gfx", name="Icon set", type="select", options={'old','modern','modern_simplified'}, value=1, description='NOTE: when icon edges look jagged: enable more Anti-Aliasing\n...or pick the \'old\' iconset'},
		{id="disticon", group="gfx", name=widgetOptionColor.."   render distance", type="slider", min=0, max=900, step=10, value=tonumber(Spring.GetConfigInt("UnitIconDist",1) or 400), description='Set a lower value to get better performance'},
		{id="iconscale", group="gfx", name=widgetOptionColor.."   scale", type="slider", min=0.85, max=1.35, step=0.05, value=tonumber(Spring.GetConfigFloat("UnitIconScale",1.15) or 1.05), description='Note that the minimap icon size is affected as well'},
		{id="minimapiconsize", group="gfx", name=widgetOptionColor.."   minimap scale", type="slider", min=1.5, max=5, step=0.25, value=tonumber(Spring.GetConfigFloat("MinimapIconScale",3.5) or 1), description=''},

		{id="decals", group="gfx", name="Ground decals", type="slider", min=0, max=5, step=1, value=tonumber(Spring.GetConfigInt("GroundDecals",1) or 1), description='Set how long map decals will stay.\n\nDecals are ground scars, footsteps/tracks and shading under buildings'},
		{id="grounddetail", group="gfx", name="Ground detail", type="slider", min=60, max=200, step=1, value=tonumber(Spring.GetConfigInt("GroundDetail",1) or 1), description='Set how detailed the map mesh/model is'},
		{id="mapedgeextension", group="gfx", widget="Map Edge Extension", name="Map edge extension", type="bool", value=GetWidgetToggleValue("Map Edge Extension"), description='Mirrors the map at screen edges and darkens and decolorizes them\n\nEnable shaders for best result'},

		{id="particles", group="gfx", name="Max particles", type="slider", min=10000, max=40000, step=1000, value=tonumber(Spring.GetConfigInt("MaxParticles",1) or 15000), description='Particles used for explosions, smoke, fire and missiletrails\n\nSetting a low value will mean that various effects wont show properly'},
		{id="grassdetail", group="gfx", name="Grass", type="slider", min=0, max=10, step=1, value=tonumber(Spring.GetConfigInt("GrassDetail",1) or 5), description='Amount of grass rendered\n\nChanges will be applied next game'},

		{id="lighteffects", group="gfx", name="Lights", type="bool", value=GetWidgetToggleValue("Light Effects"), description='Adds lights to projectiles, lasers and explosions.\n\nRequires shaders.'},
		{id="lighteffects_deferred", group="gfx", name=widgetOptionColor.."   real lights", type="bool", value=true, description='Otherwise simple ground flashes instead of actual map and model lighting.\n\nExpensive for the gpu when lots of (big) lights are there or when you zoom in on them.'},
		{id="lighteffects_heatdistortion", group="gfx", name=widgetOptionColor.."   apply heat distortion", type="bool", value=true, description='Enables a distortion on top of explosions to simulate heat'},
		{id="lighteffects_life", group="gfx", name=widgetOptionColor.."   lifetime", min=0.4, max=0.9, step=0.05, type="slider", value=0.65, description='lifetime of explosion lights'},
		{id="lighteffects_brightness", group="gfx", name=widgetOptionColor.."   brightness", min=0.8, max=2, step=0.1, type="slider", value=1.2, description='Set the brightness of the lights'},
		{id="lighteffects_radius", group="gfx", name=widgetOptionColor.."   radius", min=1, max=1.6, step=0.1, type="slider", value=1.2, description='Set the radius of the lights\n\nWARNING: the bigger the radius the heavier on the GPU'},
		{id="lighteffects_laserbrightness", group="gfx", name=widgetOptionColor.."   laser brightness", min=0.4, max=2, step=0.1, type="slider", value=1.2, description='laser lights brightness RELATIVE to global light brightness set above\n\n(only applies to real map and model lighting)'},
		{id="lighteffects_laserradius", group="gfx", name=widgetOptionColor.."   laser radius", min=0.5, max=1.6, step=0.1, type="slider", value=1, description='laser lights radius RELATIVE to global light radius set above\n\n(only applies to real map and model lighting)'},

		{id="nanoeffect", group="gfx", name="Nano effect", type="select", options={'beam','particles'}, value=tonumber(Spring.GetConfigInt("NanoEffect",1) or 1), description='Sets nano effect\n\nBeams more expensive than particles'},
		{id="lighteffects_nanolaser", group="gfx", name=widgetOptionColor.."   beam light  (needs 'Lights')", type="bool", value=true, description='Shows a light for every build/reclaim nanolaser'},
		{id="nanobeamicon", group="gfx", name=widgetOptionColor.."   beam when uniticon", type="bool", value=tonumber(Spring.GetConfigInt("NanoLaserIcon",0) or 0) == 1, description='Shows nano beams when unit is displayed as icon'},
		{id="nanobeamamount", group="gfx", name=widgetOptionColor.."   beam amount", type="slider", min=2, max=20, step=1, value=tonumber(Spring.GetConfigInt("NanoBeamAmount",6) or 6), description='Not number of total beams (but total of new beams per gameframe)\n\nBeams aren\'t cheap so lower this setting for better performance'},
		{id="nanoparticles", group="gfx", name=widgetOptionColor.."   max nano particles", type="slider", min=1000, max=15000, step=100, value=maxNanoParticles, description=''},

		{id="lups", group="gfx", widget="LupsManager", name="Particle / shader FX", type="bool", value=GetWidgetToggleValue("LupsManager"), description='Toggle unit particle effects: jet engine thrusters, ground flashes, fusion energy balls'},
		{id="lupsreflectionrefraction", group="gfx", name=widgetOptionColor.."   reflection and refraction pass", type="bool", value=tonumber(Spring.GetConfigInt("lupsreflectionrefraction",1) or 0) == 1, description='The settings seem only relevant near water\nand disabling them reduces draw passes'},
		{id="lighteffects_thrusters", group="gfx", name=widgetOptionColor.."   air thrusters light  (needs 'Lights')", type="bool", value=true, description='Shows a light for air engine thrusters (fighters and scouts excluded)'},

		{id="underconstructiongfx", group="gfx", widget="Under construction gfx", name="Under construction shader", type="bool", value=GetWidgetToggleValue("Under construction gfx"), description='Highlights unit models when under construction'},
		{id="underconstructiongfx_opacity", group="gfx", name=widgetOptionColor.."   opacity", min=0.25, max=0.5, step=0.01, type="slider", value=0.2, description='Set the opacity of the highlight on selected units'},
		{id="underconstructiongfx_shader", group="gfx", name=widgetOptionColor.."   use shader", type="bool", value=false, description='Highlight model edges a bit'},

		{id="xrayshader", group="gfx", widget="XrayShader", name="Unit xray shader", type="bool", value=GetWidgetToggleValue("XrayShader"), description='Highlights all units, highlight effect dissolves on close camera range.\n\nFades out and disables at low fps\nWorks less on dark teamcolors'},

		--{id="treeradius", group="gfx", name="Tree render distance", type="slider", min=0, max=2000, step=50, value=tonumber(Spring.GetConfigInt("TreeRadius",1) or 1000), description='Applies to SpringRTS engine default trees\n\nChanges will be applied next game'},
		{id="treewind", group="gfx", name="Tree Wind", type="bool", value=tonumber(Spring.GetConfigInt("TreeWind",1) or 1) == 1, description='Makes trees wave in the wind.\n\n(will not apply too every tree type)'},

		{id="snow", group="gfx", widget="Snow", name="Snow", type="bool", value=GetWidgetToggleValue("Snow"), description='Snow widget (By default.. maps with wintery names have snow applied)'},
		{id="snowmap", group="gfx", name=widgetOptionColor.."   enabled on this map", type="bool", value=true, description='It will remember what you toggled for every map\n\n\(by default: maps with wintery names have this toggled)'},
		{id="snowautoreduce", group="gfx", name=widgetOptionColor.."   auto reduce", type="bool", value=true, description='Automaticly reduce snow when average FPS gets lower\n\n(re-enabling this needs time to readjust  to average fps again'},
		{id="snowamount", group="gfx", name=widgetOptionColor.."   amount", type="slider", min=0.2, max=2, step=0.2, value=1, description='Tip: disable "auto reduce" option temporarily to see the max snow amount you have set'},

		{id="dofintensity", group="gfx", name="DoF intensity", type="slider", min=0.05, max=5, step=0.01, value=1.5, description='Enable Depth of Field with F8 first'},

		{id="resurrectionhalos", group="gfx", widget="Resurrection Halos", name="Resurrected unit halos", type="bool", value=GetWidgetToggleValue("Resurrection Halos"), description='Gives units have have been resurrected a little halo above it.'},
        {id="tombstones", group="gfx", widget="Tombstones", name="Tombstones", type="bool", value=GetWidgetToggleValue("Tombstones"), description='Displays tombstones where commanders died'},

		-- SND
		{id="sndvolmaster", group="snd", name="Master volume", type="slider", min=0, max=200, step=2, value=tonumber(Spring.GetConfigInt("snd_volmaster",1) or 100)},
		--{id="sndvolgeneral", group="snd", name="General volume", type="slider", min=0, max=100, step=2, value=tonumber(Spring.GetConfigInt("snd_volgeneral",1) or 100)},
		{id="sndvolbattle", group="snd", name="Battle volume", type="slider", min=0, max=100, step=2, value=tonumber(Spring.GetConfigInt("snd_volbattle",1) or 100)},
		{id="sndvolui", group="snd", name="Interface volume", type="slider", min=0, max=100, step=2, value=tonumber(Spring.GetConfigInt("snd_volui",1) or 100)},
		{id="sndvolunitreply", group="snd", name="Unit reply volume", type="slider", min=0, max=100, step=2, value=tonumber(Spring.GetConfigInt("snd_volunitreply",1) or 100)},
		--{id="sndvolmusic", group="snd", name="Music volume", type="slider", min=0, max=100, step=2, value=tonumber(Spring.GetConfigInt("snd_volmusic",1) or 100)},
		--{id="sndairabsorption", group="snd", name="Air absorption", type="slider", min=0, max=0.5, step=0.01, value=tonumber(Spring.GetConfigInt("snd_airAbsorption",1) or.1)},
        {id="musicplayer", group="snd", widget="Music Player", name="Music player", type="bool", value=GetWidgetToggleValue("Music Player"), description='Enable music player (on top of advplayerlist)\n\nMusic not included by default. (downloadable from springfiles.com)\nPlace music files in "spring/widgets_ba/music/peace"  and  ".../war'},
		{id="buildmenusounds", group="snd", name="Buildmenu click sounds", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigPlaySounds~= nil and WG['red_buildmenu'].getConfigPlaySounds()), description='Plays a sound when clicking on orders or buildmenu icons'},

        {id="voicenotifs", group="snd", widget="Voice Notifs", name="Voice notifications", type="bool", value=GetWidgetToggleValue("Voice Notifs"), description='Plays various voice notifications\n\nAdjust volume with the interface volume slider'},
		{id="voicenotifs_playtrackedplayernotifs", group="snd", name=widgetOptionColor.."   tracked cam/player notifs",type="bool", value=(WG['voicenotifs']~=nil and WG['voicenotifs'].getPlayTrackedPlayerNotifs()), description='Play voice notifs from the perspective of the currently camera tracked player'},
		{id="voicenotifs_volume", group="snd", name=widgetOptionColor.."   volume", type="slider", min=0.05, max=1, step=0.05, value=1, description='NOTE: It uses interface volume channel'},

		-- CONTROL
		{id="camera", group="control", name="Camera", type="select", options={'fps','overhead','spring','rot overhead','free'}, value=(tonumber((Spring.GetConfigInt("CamMode",1)+1) or 2))},
		{id="camerashake", group="control", widget="CameraShake", name="Camera shake", type="bool", value=GetWidgetToggleValue("CameraShake"), description='Shakes camera on explosions'},
		{id="camerasmoothness", group="control", name="Camera smoothing", type="slider", min=0, max=1, step=0.01, value=cameraTransitionTime, description="How smooth should the transitions between camera movement be?"},
		{id="lockcamera_transitiontime", group="control", name="Tracking cam smoothing", type="slider", min=0.4, max=1.5, step=0.01, value=(WG['advplayerlist_api']~=nil and WG['advplayerlist_api'].GetLockTransitionTime~=nil and WG['advplayerlist_api'].GetLockTransitionTime()), description="When viewing a players camera...\nhow smooth should the transitions between camera movement be?"},

		{id="scrollspeed", group="control", name="Scroll zoom speed", type="slider", min=1, max=45, step=1, value=math.abs(tonumber(Spring.GetConfigInt("ScrollWheelSpeed",1) or 25)), description=''},
		{id="scrollinverse", group="control", name="Scroll inversed", type="bool", value=(tonumber(Spring.GetConfigInt("ScrollWheelSpeed",1) or 25) < 0), description=""},

		{id="hwcursor", group="control", name="Hardware cursor", type="bool", value=tonumber(Spring.GetConfigInt("hardwareCursor",1) or 1) == 1, description="When disabled: the mouse cursor refresh rate will be the same as your ingame fps"},
		{id="cursor", group="control", name="Cursor", type="select", options={}, value=1, description='Choose a different mouse cursor style and/or size'},
		{id="crossalpha", group="control", name="Mouse cross alpha", type="slider", min=0, max=1, step=0.05, value=tonumber(Spring.GetConfigString("CrossAlpha",1) or 1), description='Opacity of mouse icon in center of screen when you are in camera pan mode\n\n(The\'icon\' has a dot in center with 4 arrows pointing in all directions)'},
		{id="screenedgemove", group="control", name="Screen edge moves camera", type="bool", value=tonumber(Spring.GetConfigInt("FullscreenEdgeMove",1) or 1) == 1, description="If mouse is close to screen edge this will move camera\n\nChanges will be applied next game"},
		{id="containmouse", group="control", widget="Grabinput", name="Contain mouse", type="bool", value=GetWidgetToggleValue("Grabinput"), description='When you are in windowed mode, this will keep your mouse from moving out of it'},
		{id="allyselunits_select", group="control", name="Select units of tracked player", type="bool", value=(WG['allyselectedunits']~=nil and WG['allyselectedunits'].getSelectPlayerUnits()), description="When viewing a players camera, this will also select the units the player has selected"},
		{id="lockcamera_hideenemies", group="control", name="Only show tracked player viewpoint", type="bool", value=(WG['advplayerlist_api']~=nil and WG['advplayerlist_api'].GetLockHideEnemies()), description="When viewing a players camera, this will only display what the tracked player sees"},
		{id="lockcamera_los", group="control", name=widgetOptionColor.."   show tracked player LoS", type="bool", value=(WG['advplayerlist_api']~=nil and WG['advplayerlist_api'].GetLockLos()), description="When viewing a players camera and los, shows shaded los ranges too"},
		{id="playertv_countdown", group="control", name="Player TV countdown", type="slider", min=8, max=60, step=1, value=(WG['playertv']~=nil and WG['playertv'].GetPlayerChangeDelay()) or 40, description="Countdown time before it switches player"},

		-- UI
		{id="teamcolors", group="ui", widget="Player Color Palette", name="Team colors based on a palette", type="bool", value=GetWidgetToggleValue("Player Color Palette"), description='Replaces lobby team colors for a color palette based one\n\nNOTE: reloads all widgets because these need to update their teamcolors'},
		{id="sameteamcolors", group="ui", name=widgetOptionColor.."   same team colors", type="bool", value=(WG['playercolorpalette']~=nil and WG['playercolorpalette'].getSameTeamColors~=nil and WG['playercolorpalette'].getSameTeamColors()), description='Use the same teamcolor for all the players in a team\n\nNOTE: reloads all widgets because these need to update their teamcolors'},
		{id="simpleminimapcolors", group="ui", name="Simple minimap colors", type="bool", value=tonumber(Spring.GetConfigInt("SimpleMiniMapColors",0) or 0) == 1, description="Enable simple minimap teamcolors\nRed is enemy,blue is ally and you are green!"},

		{id="guiopacity", group="ui", name="GUI opacity", type="slider", min=0, max=1, step=0.01, value=Spring.GetConfigFloat("ui_opacity",0.66), description=''},

		{id="guishader", group="ui", widget="GUI-Shader", name="GUI background blur", type="bool", value=GetWidgetToggleValue("GUI-Shader"), description='Blurs the world under every user interface element\n\nIntel Graphics have trouble with this'},
		{id="guishaderintensity", group="ui", name=widgetOptionColor.."   intensity", type="slider", min=0.0007, max=0.003, step=0.0001, value=0.0014, description='NOTE: does 2nd blur when value is above 0.0015'},

		{id="showbuilderqueue", group="ui", widget="Show builder queue", name="Show Builder Queue", type="bool", value=GetWidgetToggleValue("Show Builder Queue"), description='Shows ghosted buildings about to be built on the map'},

		{id="healthbarsscale", group="ui", name="Health bars scale", type="slider", min=0.7, max=1.31, step=0.1, value=1, description=''},

		{id="consolemaxlines", group="ui", name="Console max lines", type="slider", min=3, max=9, step=1, value=6, description=''},
		{id="consolefontsize", group="ui", name="Console font size", type="slider", min=0.9, max=1.2, step=0.05, value=1, description=''},

		{id="oldicons", group="ui", name="Old unit icons", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigOldUnitIcons()), description='Use the old unit icons in the buildmenu\n\n(reselect something to see the change applied)'},
		{id="buildmenushortcuts", group="ui", name="Buildmenu shortcuts", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigShortcutsInfo()), description='Enables and shows shortcut keys in the buildmenu\n\n(reselect something to see the change applied)'},
		{id="buildmenuprices", group="ui", name="Buildmenu prices", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigUnitPrice~=nil and WG['red_buildmenu'].getConfigUnitPrice()), description='Enables and shows unit prices in the buildmenu\n\n(reselect something to see the change applied)'},
		{id="buildmenuradaricons", group="ui", name="Buildmenu radar icons", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigUnitRadaricon~=nil and WG['red_buildmenu'].getConfigUnitRadaricon()), description='Shows unit radar icon in the buildmenu\n\n(reselect something to see the change applied)'},
		{id="buildmenulargeicons", group="ui", name="Buildmenu enlarged", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigLargeUnitIcons~=nil and WG['red_buildmenu'].getConfigLargeUnitIcons()), description='Use large unit icons'},
		{id="buildmenutooltip", group="ui", name="Buildmenu tooltip", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigUnitTooltip~=nil and WG['red_buildmenu'].getConfigUnitTooltip()), description='Enables unit tooltip when hovering over unit in buildmenu'},
		{id="buildmenubigtooltip", group="ui", name=widgetOptionColor.."   extensive unit info", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigUnitBigTooltip~=nil and WG['red_buildmenu'].getConfigUnitBigTooltip()), description='Displays elaborative unit description when availible'},

		--{id="resourceprompts", group="ui", name="Audio/Visual Resource Prompts", type="bool", value=tonumber(Spring.GetConfigInt("evo_resourceprompts",1) or 1) == 1, description="If enabled, messages will be sent to the chat as well as\naudio cues when your resources need attention"},

		--{id="fpstimespeed", group="ui", name="Display FPS, GameTime and Speed", type="bool", value=tonumber(Spring.GetConfigInt("ShowFPS",1) or 1) == 1, description='Located at the top right of the screen\n\nIndividually toggle them with /fps /clock /speed'},
		{id="resourcebarcoloring", group="ui", name="Resource bar background coloring", type="bool", value=true, description='Colors the resourcebar background when overflowing or low on energy (when playing)'},
		{id="playerlistcollapse", group="ui", name="Playerlist auto collapses", type="bool", value=false, description='Auto collapses the playerlist, mouseover will show it again'},
		{id="fpstimespeed-widget", group="ui", widget="AdvPlayersList info", name="Playerlist time/speed/fps", type="bool", value=GetWidgetToggleValue("AdvPlayersList info"), description='Shows time, gamespeed and fps on top of the (adv)playerslist'},
		{id="mascotte", group="ui", widget="AdvPlayersList mascotte", name="Playerlist mascotte", type="bool", value=GetWidgetToggleValue("AdvPlayersList mascotte"), description='Shows a mascotte on top of the (adv)playerslist'},

		{id="displaydps", group="ui", widget="Display DPS", name="Display DPS", type="bool", value=GetWidgetToggleValue("Display DPS"), description='Display the \'Damage Per Second\' done where target are hit'},
		{id="rankicons", group="ui", widget="Rank Icons", name="Rank icons", type="bool", value=GetWidgetToggleValue("Rank Icons"), description='Shows a rank icon depending on experience next to units'},

		{id="idlebuilders", group="ui", widget="Idle Builders", name="List idle builders", type="bool", value=GetWidgetToggleValue("Idle Builders"), description='Displays a row containing a list of idle builder units (if there are any)'},
		{id="betfrontend", group="ui", widget="Bet-Frontend", name="Bet interface", type="bool", value=GetWidgetToggleValue("Bet-Frontend"), description='When spectator: display a betting interface.\nIt allows betting on when you think a unit will be destroyed.\nBeware... you have a limited supply of chips.'},
		{id="commanderhurt", group="ui", widget="Commander Hurt Vignette", name="Commander hurt vignette", type="bool", value=GetWidgetToggleValue("Commander Hurt Vignette"), description='Shows a red vignette when commander is out of view and gets damaged'},

		{id="commandsfx", group="ui", widget="Commands FX", name="Command FX", type="bool", value=GetWidgetToggleValue("Commands FX"), description='Shows unit target lines when you give orders\n\nThe commands from your teammates are shown as well'},
		{id="commandsfxfilterai", group="ui", name=widgetOptionColor.."   filter AI teams", type="bool", value=true, description='Hide commands for AI teams'},
		{id="commandsfxopacity", group="ui", name=widgetOptionColor.."   opacity", type="slider", min=0.3, max=1, step=0.1, value=1, description=''},

		{id="teamplatter", group="ui", widget="TeamPlatter", name="Unit team platters", type="bool", value=GetWidgetToggleValue("TeamPlatter"), description='Shows a team color platter above all visible units'},
		{id="teamplatter_opacity", group="ui", name=widgetOptionColor.."   opacity", min=0.15, max=0.4, step=0.01, type="slider", value=0.3, description='Set the opacity of the team spotters'},
		{id="teamplatter_skipownteam", group="ui", name=widgetOptionColor.."   skip own units", type="bool", value=false, description='Doesnt draw platters for yourself'},

        {id="enemyspotter", group="ui", widget="EnemySpotter", name="Enemy spotters", type="bool", value=GetWidgetToggleValue("EnemySpotter"), description='Draws smoothed circles under enemy units'},
		{id="enemyspotter_opacity", group="ui", name=widgetOptionColor.."   opacity", min=0.12, max=0.4, step=0.01, type="slider", value=0.15, description='Set the opacity of the enemy-spotter rings'},
		--{id="enemyspotter_highlight", group="ui", name=widgetOptionColor.."   unit highlight", type="bool", value=false, description='Colorize/highlight enemy units'},

		{id="highlightselunits", group="ui", widget="Highlight Selected Units", name="Highlight selected units", type="bool", value=GetWidgetToggleValue("Highlight Selected Units"), description='Highlights unit models when selected'},
		{id="highlightselunits_opacity", group="ui", name=widgetOptionColor.."   opacity", min=0.08, max=0.3, step=0.01, type="slider", value=0.2, description='Set the opacity of the highlight on selected units'},
        {id="highlightselunits_shader", group="ui", name=widgetOptionColor.."   use shader", type="bool", value=false, description='Highlight model edges a bit'},
        {id="highlightselunits_teamcolor", group="ui", name=widgetOptionColor.."   use teamcolor", type="bool", value=false, description='Use teamcolor instead of unit health coloring'},

		{id="fancyselectedunits", group="ui", widget="Fancy Selected Units", name="Fancy selected units", type="bool", value=GetWidgetToggleValue("Fancy Selected Units"), description='Draws a platter under selected units\n\n\NOTE: this widget can be heavy when having lots of units selected'},
		--{id="fancyselectedunits_style", group="ui", name=widgetOptionColor.."   style", type="select", options={}, value=1},
		{id="fancyselectedunits_opacity", group="ui", name=widgetOptionColor.."   line opacity", min=0.8, max=1, step=0.01, type="slider", value=0.9, description='Set the opacity of the highlight on selected units'},
		{id="fancyselectedunits_baseopacity", group="ui", name=widgetOptionColor.."   base opacity", min=0, max=0.5, step=0.01, type="slider", value=0.25, description='Set the opacity of the highlight on selected units'},
		{id="fancyselectedunits_teamcoloropacity", group="ui", name=widgetOptionColor.."   teamcolor opacity", min=0, max=1, step=0.01, type="slider", value=0.1, description='Set the amount of teamcolor used for the base platter'},
		--{id="fancyselectedunits_secondline", group="ui", name=widgetOptionColor.."   add second line", type="bool", value=false, description='Adds a second line'},

		{id="pausescreen", group="ui", widget="Pause Screen", name="Pause screen", type="bool", value=GetWidgetToggleValue("Pause Screen"), description='Displays an overlay when the game is paused'},
		{id="givenunits", group="ui", widget="Given Units", name="Given unit icons", type="bool", value=GetWidgetToggleValue("Given Units"), description='Tags given units with \'new\' icon'},

		{id="defrange", group="ui", widget="Defense Range", name="Defense ranges", type="bool", value=GetWidgetToggleValue("Defense Range"), description='Displays range of defenses (enemy and ally)'},
		{id="defrange_allyair", group="ui", name=widgetOptionColor.."   Ally Air", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getAllyAir~=nil and WG['defrange'].getAllyAir()), description='Show Range For Ally Air'},
		{id="defrange_allyground", group="ui", name=widgetOptionColor.."   Ally Ground", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getAllyGround~=nil and WG['defrange'].getAllyGround()), description='Show Range For Ally Ground'},
		{id="defrange_allynuke", group="ui", name=widgetOptionColor.."   Ally Nuke", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getAllyNuke~=nil and WG['defrange'].getAllyNuke()), description='Show Range For Ally Air Nuke'},
		{id="defrange_enemyair", group="ui", name=widgetOptionColor.."   Enemy Air", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getEnemyAir~=nil and WG['defrange'].getEnemyAir()), description='Show Range For Enemy Air'},
		{id="defrange_enemyground", group="ui", name=widgetOptionColor.."   Enemy Ground", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getEnemyGround~=nil and WG['defrange'].getEnemyGround()), description='Show Range For Enemy Ground'},
		{id="defrange_enemynuke", group="ui", name=widgetOptionColor.."   Enemy Nuke", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getEnemyNuke~=nil and WG['defrange'].getEnemyNuke()), description='Show Range For Enemy Nuke'},

		-- GAME
		{id="autoquit", group="game", widget="Autoquit", name="Auto quit", type="bool", value=GetWidgetToggleValue("Autoquit"), description='Automatically quits after the game ends.\n...unless the mouse has been moved within a few seconds.'},

		{id="smartselect_includebuildings", group="game", name="Include structures in area-selection", type="bool", value=false, description='When rectangle-drag-selecting an area, include building units too?\n\ndisabled: non-mobile units will not be selected\n(except: nanos always will be selected)'},
		{id="smartselect_includebuilders", group="game", name=widgetOptionColor.."   include builders   (if above is off)", type="bool", value=true, description='When rectangle-drag-selecting an area, exclude builder units from the selection'},

		{id="onlyfighterspatrol", group="game", widget="OnlyFightersPatrol", name="Only fighters patrol", type="bool", value=GetWidgetToggleValue("Autoquit"), description='Only fighters obey a factory\'s patrol route after leaving airlab.'},
		{id="fightersfly", group="game", widget="Set fighters on Fly mode", name="Set fighters on Fly mode", type="bool", value=GetWidgetToggleValue("Set fighters on Fly mode"), description='Setting fighters on Fly mode when created'},

		{id="passivebuilders", group="game", widget="Passive builders", name="Passive builders", type="bool", value=GetWidgetToggleValue("Passive builders"), description='Sets builders (nanos, labs and cons) on passive mode\n\nPassive mode means that builders will only spend energy when its availible.\nUsage: You could set your most important builders on active and leave the rest on passive'},
		{id="passivebuilders_nanos", group="game", name=widgetOptionColor.."   nanos", type="bool", value=(WG['passivebuilders']~=nil and WG['passivebuilders'].getPassiveNanos~=nil and WG['passivebuilders'].getPassiveNanos()), description=''},
		{id="passivebuilders_cons", group="game", name=widgetOptionColor.."   cons", type="bool", value=(WG['passivebuilders']~=nil and WG['passivebuilders'].getPassiveCons~=nil and WG['passivebuilders'].getPassiveCons()), description=''},
		{id="passivebuilders_labs", group="game", name=widgetOptionColor.."   labs", type="bool", value=(WG['passivebuilders']~=nil and WG['passivebuilders'].getPassiveLabs~=nil and WG['passivebuilders'].getPassiveLabs()), description=''},

		{id="autocloakpopups", group="game", widget="Auto Cloak Popups", name="Auto cloak popups", type="bool", value=GetWidgetToggleValue("Auto Cloak Popups"), description='Auto cloaks Pit Bull and Ambusher'},

		{id="unitreclaimer", group="game", widget="Unit Reclaimer", name="Unit Reclaimer", type="bool", value=GetWidgetToggleValue("Unit Reclaimer"), description='Reclaim units in an area. Hover over a unit and drag an area-reclaim circle'},

		{id="autogroup_immediate", group="game", name="Autogroup immediate mode", type="bool", value=(WG['autogroup']~=nil and WG['autogroup'].getImmediate~=nil and WG['autogroup'].getImmediate()), description='Units built/resurrected/received are added to autogroups immediately instead of waiting them to be idle.\n\n(add units to autogroup with ALT+number)'},

		{id="factoryguard", group="game", widget="FactoryGuard", name="Factory guard (builders)", type="bool", value=GetWidgetToggleValue("FactoryGuard"), description='Newly created builders will assist their source factory'},
		{id="factoryholdpos", group="game", widget="Factory hold position", name="Factory hold position", type="bool", value=GetWidgetToggleValue("Factory hold position"), description='Sets new factories, and all units they build, to hold position automatically (not aircraft)'},
		{id="factoryrepeat", group="game", widget="Factory Auto-Repeat", name="Factory auto-repeat", type="bool", value=GetWidgetToggleValue("Factory Auto-Repeat"), description='Sets new factories on Repeat mode'},

        {id="transportai", group="game", widget="Transport AI", name="Transport AI", type="bool", value=GetWidgetToggleValue("Transport AI"), description='Transport units automatically pick up new units going to factory waypoint.'},
		{id="settargetdefault", group="game", widget="Set target default", name="Set-target as default", type="bool", value=GetWidgetToggleValue("Set target default"), description='Replace default attack command to a set-target command\n(when rightclicked on enemy unit)'},
		{id="dgunnogroundenemies", group="game", widget="DGun no ground enemies", name="Dont snap DGun to ground units", type="bool", value=GetWidgetToggleValue("DGun no ground enemies"), description='Prevents dgun aim to snap onto enemy ground units, holding SHIFT will still target units\n\nWill still snap to air, ships and hovers (when on water)'},
	}


	-- fsaa is deprecated in 104.x
	if tonumber(Spring.GetConfigInt("FSAALevel",0)) > 0 then
		local fsaa = tonumber(Spring.GetConfigInt("FSAALevel",0))
		if fsaa > options[getOptionByID('msaa')].max then
			fsaa = options[getOptionByID('msaa')].max
		end
		Spring.SetConfigInt("MSAALevel", fsaa)
		Spring.SetConfigInt("FSAALevel", 0)
	end

	if options[getOptionByID('iconset')] and #VFS.SubDirs('icons') > 1 then
		local opts = {}
		local optsValues = {}
		for i, v in pairs(VFS.SubDirs('icons')) do
			if optsValues[string.sub(v, 7, #v-1)] == nil then	-- to prevent duplicated when gamefolder and spring folder have the same icons subfolder
				optsValues[string.sub(v, 7, #v-1)] = i
				opts[i] = string.sub(v, 7, #v-1)
			end
		end
		options[getOptionByID('iconset')].options = opts
		options[getOptionByID('iconset')].value = getSelectKey(getOptionByID('iconset'), Spring.GetConfigString("UnitIconFolder",'modern'))
	else
		options[getOptionByID('iconset')] = nil
		options[getOptionByID('disticon')].name = "Icon render distance"
	end

	-- remove engine particles if nano beams are enabled
	if options[getOptionByID('nanoeffect')] and options[getOptionByID('nanoeffect')].value == 1 then
		Spring.SetConfigInt("MaxNanoParticles", 0)
	end

	-- loads values via stored game config in luaui/configs
	loadAllWidgetData()

	-- while we have set config-ints, that isnt enough to have these settings applied ingame
	if savedConfig and Spring.GetGameFrame() == 0 then
		for k, v in pairs(savedConfig) do
			if getOptionByID(k) then
				applyOptionValue(getOptionByID(k))
			end
		end
	end

	if UnitDefNames["armcom_bar"] and options[getOptionByID('normalmapping')] then
		options[getOptionByID('normalmapping')].description = options[getOptionByID('normalmapping')].description..'\n\nOnly applies to remodelled units'
	end

    -- detect AI
    local aiDetected = false
    local t = Spring.GetTeamList()
    for _,teamID in ipairs(t) do
        if select(4,Spring.GetTeamInfo(teamID)) then
            aiDetected = true
        end
    end
    if not aiDetected then
        options[getOptionByID('commandsfxfilterai')] = nil
	end

	if #supportedResolutions < 2 then
		options[getOptionByID('resolution')] = nil
	else
		for id,res in pairs(options[getOptionByID('resolution')].options) do
			if res == vsx..' x '..vsy then
				options[getOptionByID('resolution')].value = id
				break
			end
		end
	end

	-- add sound notification widget sound toggle options
	if widgetHandler.knownWidgets["Voice Notifs"] then
		local soundList
		if WG['voicenotifs'] ~= nil then
			soundList =  WG['voicenotifs'].getSoundList()
		elseif widgetHandler.configData["Voice Notifs"] ~= nil and widgetHandler.configData["Voice Notifs"].soundList ~= nil then
			soundList = widgetHandler.configData["Voice Notifs"].soundList
		end
		if type(soundList) == 'table' then
			local newOptions = {}
			local count = 0
			for i, option in pairs(options) do
				count = count + 1
				newOptions[count] = option
				if option.id == 'voicenotifs_volume' then
					for sound, enabled in pairs(soundList) do
						count = count + 1
						newOptions[count] = {id="voicenotifs_snd_"..sound, group="snd", name=widgetOptionColor.."   "..sound, type="bool", value=enabled, description=''}
					end
				end
			end
			options = newOptions
		end
	else
		options[getOptionByID('voicenotifs')] = nil
		options[getOptionByID('voicenotifs_volume')] = nil
		options[getOptionByID('voicenotifs_playtrackedplayernotifs')] = nil
	end

	if not widgetHandler.knownWidgets["Player-TV"] then
		options[getOptionByID('playertv_countdown')] = nil
	end

	-- cursors
	if (WG['cursors'] == nil) then
		options[getOptionByID('cursor')] = nil
	else
		local cursorsets = {}
		local cursor = 1
		local cursoroption
		cursorsets = WG['cursors'].getcursorsets()
		local cursorname = WG['cursors'].getcursor()
		for i,c in pairs(cursorsets) do
			if c == cursorname then
				cursor = i
				break
			end
		end
		options[getOptionByID('cursor')].options = cursorsets
		options[getOptionByID('cursor')].value = cursor
	end

	if (Spring.GetModOptions and (tonumber(Spring.GetModOptions().barmodels) or 0) == 0) and not UnitDefNames["armcom_bar"] then
		options[getOptionByID('normalmapping')] = nil
		options[getOptionByID('oldicons')] = nil
	end

	if widgetHandler.knownWidgets["Bloom Shader"] == nil then
		options[getOptionByID('bloombrightness')] = nil
		options[getOptionByID('bloomsize')] = nil
		options[getOptionByID('bloomquality')] = nil
	end
	if widgetHandler.knownWidgets["Bloom Shader Deferred"] == nil then
		options[getOptionByID('bloomdeferredbrightness')] = nil
		options[getOptionByID('bloomdeferredsize')] = nil
		options[getOptionByID('bloomdeferredquality')] = nil
	end

	if (WG['healthbars'] == nil) then
		options[getOptionByID('healthbarsscale')] = nil
	elseif WG['healthbars'].getScale ~= nil then
		options[getOptionByID('healthbarsscale')].value = WG['healthbars'].getScale()
	end

	if (WG['smartselect'] == nil) then
		options[getOptionByID('smartselect_includebuildings')] = nil
		options[getOptionByID('smartselect_includebuilders')] = nil
	else
		options[getOptionByID('smartselect_includebuildings')].value = WG['smartselect'].getIncludeBuildings()
		options[getOptionByID('smartselect_includebuilders')].value = WG['smartselect'].getIncludeBuilders()
	end

	if WG['snow'] ~= nil and WG['snow'].getSnowMap ~= nil then
		options[getOptionByID('snowmap')].value = WG['snow'].getSnowMap()
	end
	if (WG['LupsPriority'] ~= nil) then
		options[getOptionByID('lupseffectlevel')].value = WG['LupsPriority']
	end

	if (WG['darkenmap'] == nil) then
		options[getOptionByID('darkenmap')] = nil
		options[getOptionByID('darkenmap_darkenfeatures')] = nil
	else
		options[getOptionByID('darkenmap')].value = WG['darkenmap'].getMapDarkness()
		options[getOptionByID('darkenmap_darkenfeatures')].value = WG['darkenmap'].getDarkenFeatures()
	end

	-- not sure if needed: remove vsync option when its done by monitor (freesync/gsync) -> config value is set as 'x'
	if Spring.GetConfigInt("VSync",1) == 'x' then
		options[getOptionByID('vsync')] = nil
	end

	if WG['red_buildmenu'] == nil or WG['red_buildmenu'].getConfigShortcutsInfo == nil then
		options[getOptionByID('buildmenushortcuts')] = nil
	end
	if WG['red_buildmenu'] == nil or WG['red_buildmenu'].getConfigUnitPrice == nil then
		options[getOptionByID('buildmenuprices')] = nil
	end
	if WG['red_buildmenu'] == nil or WG['red_buildmenu'].getConfigUnitRadaricon == nil then
		options[getOptionByID('buildmenuradaricons')] = nil
	end
	if WG['red_buildmenu'] == nil or WG['red_buildmenu'].getConfigPlaySounds == nil then
		options[getOptionByID('buildmenusounds')] = nil
	end
	if WG['red_buildmenu'] == nil or WG['red_buildmenu'].getConfigUnitTooltip == nil then
		options[getOptionByID('buildmenutooltip')] = nil
	end
	if WG['red_buildmenu'] == nil or WG['red_buildmenu'].getConfigUnitBigTooltip == nil then
		options[getOptionByID('buildmenubigtooltip')] = nil
	end
	if WG['red_buildmenu'] == nil or WG['red_buildmenu'].getConfigLargeUnitIcons == nil then
		options[getOptionByID('buildmenulargeicons')] = nil
	end

	if WG['playercolorpalette'] == nil or WG['playercolorpalette'].getSameTeamColors == nil then
		options[getOptionByID('sameteamcolors')] = nil
	end

	if (WG['dof'] == nil) then
		options[getOptionByID('dofintensity')] = nil
	end


	if WG['advplayerlist_api']==nil or WG['advplayerlist_api'].GetLockTransitionTime==nil then
		options[getOptionByID('lockcamera_transitiontime')] = nil
	end

	-- disable options when widget isnt availible
	if widgetHandler.knownWidgets["Outline"] == nil then
		options[getOptionByID('outline')] = nil
		options[getOptionByID("outline_size")] = nil
	end

	if widgetHandler.knownWidgets["Fancy Selected Units"] == nil then
		options[getOptionByID('fancyselectedunits')] = nil
		options[getOptionByID("fancyselectedunits_style")] = nil
		options[getOptionByID("fancyselectedunits_opacity")] = nil
		options[getOptionByID("fancyselectedunits_baseopacity")] = nil
		options[getOptionByID("fancyselectedunits_teamcoloropacity")] = nil
		options[getOptionByID("fancyselectedunits_secondline")] = nil
	end

	if widgetHandler.knownWidgets["Defense Range"] == nil then
		options[getOptionByID('defrange')] = nil
		options[getOptionByID("defrange_allyair")] = nil
		options[getOptionByID("defrange_allyground")] = nil
		options[getOptionByID("defrange_allynuke")] = nil
		options[getOptionByID("defrange_enemyair")] = nil
		options[getOptionByID("defrange_enemyground")] = nil
		options[getOptionByID("defrange_enemynuke")] = nil
	end

	if widgetHandler.knownWidgets["Auto Group"] == nil then
		options[getOptionByID("autogroup_immediate")] = nil
	end

	if widgetHandler.knownWidgets["Highlight Selected Units"] == nil then
		options[getOptionByID('highlightselunits')] = nil
		options[getOptionByID("highlightselunits_opacity")] = nil
		options[getOptionByID("highlightselunits_shader")] = nil
		options[getOptionByID("highlightselunits_teamcolor")] = nil
	end

	if widgetHandler.knownWidgets["Under construction gfx"] == nil then
		options[getOptionByID('underconstructiongfx')] = nil
		options[getOptionByID("underconstructiongfx_opacity")] = nil
		options[getOptionByID("underconstructiongfx_shader")] = nil
	end

	if widgetHandler.knownWidgets["Light Effects"] == nil or widgetHandler.knownWidgets["Deferred rendering"] == nil then
		options[getOptionByID('lighteffects')] = nil
		options[getOptionByID("lighteffects_brightness")] = nil
		options[getOptionByID("lighteffects_laserbrightness")] = nil
		options[getOptionByID("lighteffects_radius")] = nil
		options[getOptionByID("lighteffects_laserradius")] = nil
		options[getOptionByID("lighteffects_heatdistortion")] = nil
		options[getOptionByID("lighteffects_nanolaser")] = nil
		options[getOptionByID("lighteffects_thrusters")] = nil
		options[getOptionByID("lighteffects_deferred")] = nil
	end

	if widgetHandler.knownWidgets["TeamPlatter"] == nil then
		options[getOptionByID('teamplatter_opacity')] = nil
		options[getOptionByID('teamplatter_skipownunits')] = nil
	end

	if widgetHandler.knownWidgets["EnemySpotter"] == nil then
		options[getOptionByID('enemyspotter_opacity')] = nil
		options[getOptionByID('enemyspotter_highlight')] = nil
	end

	local processedOptions = {}
	local processedOptionsCount = 0
	local insert = true
	for oid,option in pairs(options) do
		insert = true
		if option.type == 'slider' then
			if option.value < option.min then option.value = option.min end
			if option.value > option.max then option.value = option.max end
		end
		if (option.id == "shadows" or option.id == "shadows_maxquality" or option.id == "shadows_minquality" or option.id == "shadows_disablefps") and (widgetHandler.knownWidgets["Shadow Quality Manager"] == nil or (widgetHandler.orderList["Shadow Quality Manager"] == 0)) then
			insert = false
		end
		if option.id == "shadowslider" and widgetHandler.knownWidgets["Shadow Quality Manager"] ~= nil and (widgetHandler.orderList["Shadow Quality Manager"] > 0) then
			insert = false
		end
		if option.widget ~= nil and widgetHandler.knownWidgets[option.widget] == nil then
			insert = false
		end
		if luaShaders ~= 1 then
			if option.id == "advmapshading" or option.id == "advmodelshading" or option.id == "bloom" or option.id == "bloomdeferred" or option.id == "guishader" or option.id == "xrayshader" or option.id == "mapedgeextension" or option.id == "snow" then
				option.description = 'You dont have shaders enabled, we will enable it for you but...\n\nChanges will be applied next game'
			end
		end
		if insert then
			processedOptionsCount = processedOptionsCount + 1
			processedOptions[processedOptionsCount] = option
		end
	end
	options = processedOptions
end


function deletePreset(name)
	Spring.Echo('deleted preset:  '..name)
	customPresets[name] = nil
	presets[name] = nil
	local newPresetNames = {}
	for _, presetName in ipairs(presetNames) do
		if presetName ~= name then
			table.insert(newPresetNames, presetName)
		end
	end
	presetNames = newPresetNames
	options[getOptionByID('preset')].options = presetNames
	if windowList then gl.DeleteList(windowList) end
	windowList = gl.CreateList(DrawWindow)
end

function savePreset(name)
	if name == nil then
		name = 'custom'
		local i = 1
		while customPresets[name] ~= nil do
			i = i + 1
			name = 'custom'..i
		end
	end
	if presets[name] ~= nil then
		Spring.Echo("preset '"..name.."' already exists")
	else
		local preset = {}
		for optionID, _ in pairs(presets['lowest']) do
			if options[getOptionByID(optionID)] ~= nil then
				preset[optionID] = options[getOptionByID(optionID)].value
			end
		end
		customPresets[name] = preset
		presets[name] = preset
		table.insert(presetNames, name)
		options[getOptionByID('preset')].options = presetNames
		Spring.Echo('saved preset: '..name)
		if windowList then gl.DeleteList(windowList) end
		windowList = gl.CreateList(DrawWindow)
	end
end


function widget:Initialize()
	if tonumber(Spring.GetConfigInt("MaxParticles",1) or 10000) <= 10000 then
		Spring.SetConfigInt("MaxParticles",10000)
	end

	--if Platform ~= nil and Platform.gpuVendor ~= 'Nvidia' then	-- because UsePBO displays tiled map texture bug for ATI/AMD cards
		Spring.SetConfigInt("UsePBO",0)
	--end

	Spring.SendCommands("minimap unitsize "..(Spring.GetConfigFloat("MinimapIconScale", 3.5)))		-- spring wont remember what you set with '/minimap iconssize #'

	Spring.SendCommands({"bind f10 options"})

	WG['options'] = {}
	WG['options'].toggle = function(state)
		if state ~= nil then
			show = state
		else
			show = not show
		end
	end
	WG['options'].isvisible = function()
		return show
	end

	presets = tableMerge(presets, customPresets)
	for preset,_ in pairs(customPresets) do
		table.insert(presetNames, preset)
	end

	init()
end

function widget:Shutdown()
    if buttonGL then
        glDeleteList(buttonGL)
    end
    if windowList then
        glDeleteList(windowList)
	end
	WG['options'] = nil
end


local function Split(s, separator)
	local results = {}
	for part in s:gmatch("[^"..separator.."]+") do
		results[#results + 1] = part
	end
	return results
end

local lastOptionCommand = 0
function widget:TextCommand(command)
	if (string.find(command, "options") == 1  and  string.len(command) == 7) then
		show = not show
	end
	if os.clock() > lastOptionCommand+1 and string.sub(command, 1, 7) == "option " then		-- clock check is needed because toggling widget will somehow do an identical call of widget:TextCommand(command)
		local option = string.sub(command, 8)
		local optionID = getOptionByID(option)
		if optionID then
			if options[optionID].type == 'bool' then
				lastOptionCommand = os.clock()
				options[optionID].value = not options[optionID].value
				applyOptionValue(optionID)
			else
				show = true
			end
		else
			option = Split(option, ' ')
			optionID = option[1]
			if optionID then
				optionID = getOptionByID(optionID)
				if optionID and option[2] then
					lastOptionCommand = os.clock()
					if options[optionID].type == 'select' then
						local selectKey = getSelectKey(optionID, option[2])
						if selectKey then
							options[optionID].value = selectKey
							applyOptionValue(optionID)
						end
					elseif options[optionID].type == 'bool' then
						if option[2] == '0' then
							options[optionID].value = false
						else
							options[optionID].value = true
						end
						applyOptionValue(optionID)
					else
						options[optionID].value = tonumber(option[2])
						applyOptionValue(optionID)
					end
				end
			end
		end
	end
	if (string.find(command, "savepreset") == 1)  then
		local words = Split(command, ' ')
		if words[2] then
			savePreset(words[2])
		else
			savePreset()
		end
	end
end

function getSelectKey(i, value)
	for k, v in pairs(options[i].options) do
		if v == value then
			return k
		end
	end
	return false
end


function widget:GetConfigData(data)
	savedTable = {}
	savedTable.customPresets = customPresets
	savedTable.cameraTransitionTime = cameraTransitionTime
	savedTable.maxNanoParticles = maxNanoParticles
	savedTable.currentGroupTab = currentGroupTab
	savedTable.savedConfig = {
		vsync = {'VSync', tonumber(Spring.GetConfigInt("VSync",1) or 1)},
		water = {'Water', tonumber(Spring.GetConfigInt("Water",1) or 1)},
		disticon = {'UnitIconDist', tonumber(Spring.GetConfigInt("UnitIconDist",1) or 400)},
		particles = {'MaxParticles', tonumber(Spring.GetConfigInt("MaxParticles",1) or 15000)},
		--nanoparticles = {'MaxNanoParticles', tonumber(Spring.GetConfigInt("MaxNanoParticles",1) or 500)},	-- already saved above in: maxNanoParticles
		decals = {'GroundDecals', tonumber(Spring.GetConfigInt("GroundDecals",1) or 1)},
		grounddetail = {'GroundDetail', tonumber(Spring.GetConfigInt("GroundDetail",1) or 1)},
		grassdetail = {'GrassDetail', tonumber(Spring.GetConfigInt("GrassDetail",1) or 5)},
		shadows = {'Shadows', tonumber(Spring.GetConfigInt("Shadows",1) or 1)},
		advsky = {'AdvSky', tonumber(Spring.GetConfigInt("AdvSky",1) or 1)},
		camera = {'CamMode', tonumber(Spring.GetConfigInt("CamMode",1) or 1)},
		advmodelshading = {'AdvModelShading', tonumber(Spring.GetConfigInt("AdvModelShading",1) or 1)},
		advmapshading = {'AdvMapShading', tonumber(Spring.GetConfigInt("AdvMapShading",1) or 1)},
		normalmapping = {'NormalMapping', tonumber(Spring.GetConfigInt("NormalMapping",1) or 1)},
		treewind = {'TreeWind', tonumber(Spring.GetConfigInt("TreeWind",1) or 1)},
		hwcursor = {'HardwareCursor', tonumber(Spring.GetConfigInt("HardwareCursor",1) or 1)},
		sndvolmaster = {'snd_volmaster', tonumber(Spring.GetConfigInt("snd_volmaster",40) or 40)},
		sndvolbattle = {'snd_volbattle', tonumber(Spring.GetConfigInt("snd_volbattle",40) or 40)},
		sndvolunitreply = {'snd_volunitreply', tonumber(Spring.GetConfigInt("snd_volunitreply",40) or 40)},
		sndvolmusic = {'snd_volmusic', tonumber(Spring.GetConfigInt("snd_volmusic",40) or 40)},
		guiopacity = {'ui_opacity', tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)},
	}
	return savedTable
end

function widget:SetConfigData(data)
	if data.customPresets ~= nil then
		customPresets = data.customPresets
	end
	if data.cameraTransitionTime ~= nil then
		cameraTransitionTime = data.cameraTransitionTime
	end
	if data.maxNanoParticles ~= nil then
		maxNanoParticles = data.maxNanoParticles
	end
	if data.currentGroupTab ~= nil then
		currentGroupTab = data.currentGroupTab
	end
	if data.savedConfig ~= nil then
		savedConfig = data.savedConfig
		for k, v in pairs(savedConfig) do
			Spring.SetConfigFloat(v[1],v[2])
		end
	end
end
