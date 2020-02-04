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
]]--

local advSettings = false

local maxNanoParticles = 4000

local cameraTransitionTime = 0.2
local cameraPanTransitionTime = 0.03

local widgetOptionColor = '\255\160\160\160'

local playSounds = true
local buttonclick = 'LuaUI/Sounds/tock.wav'
local paginatorclick = 'LuaUI/Sounds/buildbar_waypoint.wav'
local sliderdrag = 'LuaUI/Sounds/buildbar_rem.wav'
local selectclick = 'LuaUI/Sounds/buildbar_click.wav'
local selectunfoldclick = 'LuaUI/Sounds/buildbar_hover.wav'
local selecthoverclick = 'LuaUI/Sounds/hover.wav'
local toggleonclick = 'LuaUI/Sounds/switchon.wav'
local toggleoffclick = 'LuaUI/Sounds/switchoff.wav'

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 36
local fontfileOutlineSize = 9
local fontfileOutlineStrength = 1.4
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
local fontfileScale2 = fontfileScale * 1.2
local fontfile2 = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale2, fontfileOutlineSize*fontfileScale2, fontfileOutlineStrength)

local bgcorner = "LuaUI/Images/bgcorner.png"
local backwardTex = ":l:LuaUI/Images/backward.dds"
local forwardTex = ":l:LuaUI/Images/forward.dds"
local glowTex = ":l:LuaUI/Images/glow2.dds"

local bgMargin = 6
local screenHeight = 520-bgMargin-bgMargin
local screenWidth = 1050-bgMargin-bgMargin

local customScale = 1.1
local centerPosX = 0.51	-- note: dont go too far from 0.5
local centerPosY = 0.49		-- note: dont go too far from 0.5
local screenX = (vsx*centerPosX) - (screenWidth/2)
local screenY = (vsy*centerPosY) + (screenHeight/2)

local wsx,wsy,wpx,wpy = Spring.GetWindowGeometry()
local ssx,ssy,spx,spy = Spring.GetScreenGeometry()

local changesRequireRestart = false

local customMapSunPos = {}

local spIsGUIHidden = Spring.IsGUIHidden

local glColor = gl.Color
local glTexRect = gl.TexRect
local glRotate = gl.Rotate
local glTexture = gl.Texture
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale


local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.5 + (vsx*vsy / 5700000)) * customScale
WG.uiScale = widgetScale

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)

local defaultMapSunPos = {gl.GetSun("pos")}

local options = {}
local optionGroups = {}
local optionButtons = {}
local optionHover = {}
local optionSelect = {}

local showOnceMore = false		-- used because of GUI shader delay

local presetNames = {'lowest','low','medium','high','ultra'}	-- defined so these get listed in the right order
local presets = {
	lowest = {
		bloom = false,
		bloomdeferred = false,
		--cas = false,
		ssao = false,
		water = 1,
		mapedgeextension = false,
		lighteffects = false,
		lups = false,
		lupsreflectionrefraction = false,
		snow = false,
		particles = 15000,
		nanoparticles = 1500,
		nanobeamamount = 5,
		treeradius = 0,
		--treewind = false,
		guishader = false,
		--shadows = false,
		decals = 0,
		grounddetail = 70,
		darkenmap_darkenfeatures = false,
		enemyspotter_highlight = false,
	},
	low = {
		bloom = false,
		bloomdeferred = true,
		--cas = true,
		ssao = false,
		water = 2,
		mapedgeextension = false,
		lighteffects = true,
		lups = true,
		lupsreflectionrefraction = false,
		snow = false,
		particles = 20000,
		nanoparticles = 3000,
		nanobeamamount = 7,
		treeradius = 200,
		--treewind = false,
		guishader = false,
		--shadows = true,
		decals = 0,
		grounddetail = 100,
		darkenmap_darkenfeatures = false,
		enemyspotter_highlight = false,
	},
	medium = {
		bloom = true,
		bloomdeferred = true,
		--cas = true,
		ssao = false,
		water = 4,
		mapedgeextension = true,
		lighteffects = true,
		lups = true,
		lupsreflectionrefraction = false,
		snow = true,
		particles = 25000,
		nanoparticles = 5000,
		nanobeamamount = 10,
		treeradius = 400,
		--treewind = false,
		guishader = false,
		--shadows = true,
		decals = 1,
		grounddetail = 140,
		darkenmap_darkenfeatures = false,
		enemyspotter_highlight = false,
	},
	high = {
		bloom = true,
		bloomdeferred = true,
		--cas = true,
		ssao = true,
		water = 3,
		mapedgeextension = true,
		lighteffects = true,
		lups = true,
		lupsreflectionrefraction = true,
		snow = true,
		particles = 30000,
		nanoparticles = 9000,
		nanobeamamount = 14,
		treeradius = 800,
		--treewind = true,
		guishader = true,
		--shadows = true,
		decals = 2,
		grounddetail = 180,
		darkenmap_darkenfeatures = false,
		enemyspotter_highlight = false,
	},
	ultra = {
		bloom = true,
		bloomdeferred = true,
		--cas = true,
		ssao = true,
		water = 5,
		mapedgeextension = true,
		lighteffects = true,
		lups = true,
		lupsreflectionrefraction = true,
		snow = true,
		particles = 40000,
		nanoparticles = 15000,
		nanobeamamount = 20,
		treeradius = 800,
		--treewind = true,
		guishader = true,
		--shadows = true,
		decals = 3,
		grounddetail = 200,
		darkenmap_darkenfeatures = true,
		enemyspotter_highlight = true,
	},
}
local customPresets = {}


function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
  screenX = (vsx*centerPosX) - (screenWidth/2)
  screenY = (vsy*centerPosY) + (screenHeight/2)
  widgetScale = (0.5 + (vsx*vsy / 5700000)) * customScale
  WG.uiScale = widgetScale
	local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
	if (fontfileScale ~= newFontfileScale) then
		fontfileScale = newFontfileScale
		fontfileScale2 = fontfileScale * 1.2
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
		font2 = gl.LoadFont(fontfile2, fontfileSize*fontfileScale2, fontfileOutlineSize*fontfileScale2, fontfileOutlineStrength)
	end
  if windowList then gl.DeleteList(windowList) end
  windowList = gl.CreateList(DrawWindow)
end


local engineVersion = 104 -- just filled this in here incorrectly but old engines arent used anyway
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
		--if advSettings or group.id ~= 'dev' then
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
		--end
	end
	options = deepcopy(newOptions)
end


function mouseoverGroupTab(id)
	if optionGroups[id].id == currentGroupTab then return end

	local tabFontSize = 16
	local groupMargin = bgMargin/1.7
	gl.Color(0.4,0.4,0.4,0.3)
	RectRound(groupRect[id][1]+groupMargin, groupRect[id][2], groupRect[id][3]-groupMargin, groupRect[id][4]-groupMargin, groupMargin*1.8, 1,1,0,0)
	font2:Begin()
	font2:SetTextColor(1,0.85,0.55,1)
	font2:SetOutlineColor(0.4,0.3,0.15,0.4)
	font2:Print(optionGroups[id].name, groupRect[id][1]+((groupRect[id][3]-groupRect[id][1])/2), screenY+bgMargin+8, tabFontSize, "con")
	font2:End()
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
	if WG['guishader'] then
		gl.Color(0,0,0,0.8)
	else
		gl.Color(0,0,0,0.85)
	end
	RectRound(x-bgMargin,y-screenHeight-bgMargin,x+screenWidth+bgMargin,y+bgMargin,8, 0,1,1,1)
	-- content area
	if currentGroupTab then
		gl.Color(0.4,0.4,0.4,0.15)
	else
		gl.Color(0.33,0.33,0.33,0.15)
	end
	RectRound(x,y-screenHeight,x+screenWidth,y,5.5)

	-- title
	local title = "Basic settings"
	if advSettings then
		title = "Advanced settings"
	end
	local titleFontSize = 18
	titleRect = {x-bgMargin, y+bgMargin, x+(font2:GetTextWidth(title)*titleFontSize)+27-bgMargin, y+37 }

	-- group tabs
	local tabFontSize = 16
	local xpos = titleRect[3]
	local groupMargin = bgMargin/1.7
	groupRect = {}
	for id,group in pairs(optionGroups) do
		groupRect[id] = {xpos, y+(bgMargin/2), xpos+(font2:GetTextWidth(group.name)*tabFontSize)+27, y+37}
			if advSettings or group.id ~= 'dev' then
			xpos = groupRect[id][3]
			if currentGroupTab == nil or currentGroupTab ~= group.id then
				if WG['guishader'] then
					gl.Color(0,0,0,0.8)
				else
					gl.Color(0,0,0,0.85)
				end
				RectRound(groupRect[id][1], groupRect[id][2]+(bgMargin/2), groupRect[id][3], groupRect[id][4], 8, 1,1,0,0)
				gl.Color(0.62,0.5,0.22,0.18)
				RectRound(groupRect[id][1]+groupMargin, groupRect[id][2], groupRect[id][3]-groupMargin, groupRect[id][4]-groupMargin, groupMargin*1.8, 1,1,0,0)
				font2:Begin()
				font2:SetTextColor(0.6,0.51,0.38,1)
				font2:SetOutlineColor(0,0,0,0.4)
				font2:Print(group.name, groupRect[id][1]+((groupRect[id][3]-groupRect[id][1])/2), y+bgMargin+8, tabFontSize, "con")
				font2:End()
			else
				if WG['guishader'] then
					gl.Color(0,0,0,0.8)
				else
					gl.Color(0,0,0,0.85)
				end
				RectRound(groupRect[id][1], groupRect[id][2]+(bgMargin/2), groupRect[id][3], groupRect[id][4], 8, 1,1,0,0)
				gl.Color(0.4,0.4,0.4,0.15)
				RectRound(groupRect[id][1]+groupMargin, groupRect[id][2]+(bgMargin/2)-bgMargin, groupRect[id][3]-groupMargin, groupRect[id][4]-groupMargin, groupMargin*1.8, 1,1,0,0)
				font2:Begin()
				font2:SetTextColor(1,0.75,0.4,1)
				font2:SetOutlineColor(0,0,0,0.4)
				font2:Print(group.name, groupRect[id][1]+((groupRect[id][3]-groupRect[id][1])/2), y+bgMargin+8, tabFontSize, "con")
				font2:End()
			end
		end
	end

	-- title drawing
	if WG['guishader'] then
		gl.Color(0,0,0,0.8)
	else
		gl.Color(0,0,0,0.85)
	end
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 8, 1,1,0,0)

	font2:Begin()
	font2:SetTextColor(1,1,1,1)
	font2:SetOutlineColor(0,0,0,0.4)
	font2:Print(title, x-bgMargin+(titleFontSize*0.75), y+bgMargin+8, titleFontSize, "on")
	font2:End()

	font:Begin()
	local width = screenWidth/3
	--gl.Color(0.66,0.66,0.66,0.08)
	--RectRound(x+width+width+6,y-screenHeight,x+width+width+width,y,6)

	-- description background
	--gl.Color(0.55,0.48,0.22,0.14)
	gl.Color(1,0.85,0.55,0.04)
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
			if option.group == currentGroupTab and (advSettings or option.basic) then
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
		local buttonMargin = 18
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

		font:SetTextColor(1,1,1,0.4)
		font:Print(math.ceil(startColumn/maxShownColumns)..' / '..math.ceil(totalColumns/maxShownColumns), startX-(buttonSize*2.6)-buttonMargin, startY+buttonSize/2.6, buttonSize/2.9, "rn")
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

	-- require restart notification
	if changesRequireRestart then
		font:SetTextColor(1,0.35,0.35,1)
		font:SetOutlineColor(0,0,0,0.4)
		font:Print("...made changes that require restart", x+screenWidth-3, screenY-screenHeight+3, 15, "rn")
	end

	-- draw options
	for oid,option in pairs(options) do
		if advSettings or option.basic and option.group ~= 'Dev' then
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

					font:SetTextColor(1,1,1,1)
					font:Print(color..option.name, xPos+(oPadding/2), yPos-(oHeight/3)-oPadding, oHeight, "no")

					-- define hover area
					optionHover[oid] = {xPos, yPos-oHeight-oPadding, xPosMax, yPos+oPadding}

					-- option controller
					local rightPadding = 4
					if option.type == 'bool' then
						optionButtons[oid] = {}
						optionButtons[oid] = {xPosMax-boolWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos}
						glColor(1,1,1,0.11)
						RectRound(xPosMax-boolWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos, 2)
						if option.value == true then
							glColor(0.66,0.92,0.66,1)
							RectRound(xPosMax-oHeight+boolPadding-rightPadding, yPos-oHeight+boolPadding, xPosMax-boolPadding-rightPadding, yPos-boolPadding, 1)
							local boolGlow = boolPadding*3.5
							glColor(0.66,1,0.66,0.5)
							glTexture(glowTex)
							glTexRect(xPosMax-oHeight+boolPadding-rightPadding-boolGlow, yPos-oHeight+boolPadding-boolGlow, xPosMax-boolPadding-rightPadding+boolGlow, yPos-boolPadding+boolGlow)
							glColor(0.55,1,0.55,0.09)
							glTexture(glowTex)
							glTexRect(xPosMax-oHeight+boolPadding-rightPadding-(boolGlow*3), yPos-oHeight+boolPadding-(boolGlow*3), xPosMax-boolPadding-rightPadding+(boolGlow*3), yPos-boolPadding+(boolGlow*3))
						elseif option.value == 0.5 then
							glColor(0.91,0.82,0.66,1)
							RectRound(xPosMax-(boolWidth/1.9)+boolPadding-rightPadding, yPos-oHeight+boolPadding, xPosMax-(boolWidth/1.9)+oHeight-boolPadding-rightPadding, yPos-boolPadding, 1)
						else
							glColor(0.9,0.66,0.66,1)
							RectRound(xPosMax-boolWidth+boolPadding-rightPadding, yPos-oHeight+boolPadding, xPosMax-boolWidth+oHeight-boolPadding-rightPadding, yPos-boolPadding, 1)
						end

					elseif option.type == 'slider' then
						local sliderSize = oHeight*0.75
						local sliderPos = 0
						if option.steps then
							local min, max = option.steps[1], option.steps[1]
							for k, v in ipairs(option.steps) do
								if v > max then max = v end
								if v < min then min = v end
							end
							sliderPos = (option.value-min) / (max-min)
						else
							sliderPos = (option.value-option.min) / (option.max-option.min)
						end
						glColor(1,1,1,0.11)
						RectRound(xPosMax-(sliderSize/2)-sliderWidth-rightPadding, yPos-((oHeight/7)*4.2), xPosMax-(sliderSize/2)-rightPadding, yPos-((oHeight/7)*2.8), 1)
						glColor(0.8,0.8,0.8,1)
						RectRound(xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)-(sliderSize/2)-rightPadding, yPos-oHeight+((oHeight-sliderSize)/2), xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)+(sliderSize/2)-rightPadding, yPos-((oHeight-sliderSize)/2), 1)
						optionButtons[oid] = {xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)-(sliderSize/2)-rightPadding, yPos-oHeight+((oHeight-sliderSize)/2), xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)+(sliderSize/2)-rightPadding, yPos-((oHeight-sliderSize)/2)}
						optionButtons[oid].sliderXpos = {xPosMax-(sliderSize/2)-sliderWidth-rightPadding, xPosMax-(sliderSize/2)-rightPadding}

					elseif option.type == 'select' then
						optionButtons[oid] = {xPosMax-selectWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos}
						glColor(1,1,1,0.11)
						RectRound(xPosMax-selectWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos, 2)
						if option.options[tonumber(option.value)] ~= nil then
							if option.id == 'font2' then
								font:End()
								font2:Begin()
								font2:SetTextColor(1,1,1,1)
								font2:Print(option.options[tonumber(option.value)], xPosMax-selectWidth+5-rightPadding, yPos-(oHeight/3)-oPadding, oHeight*0.85, "no")
								font2:End()
								font:Begin()
							else
								font:SetTextColor(1,1,1,1)
								font:Print(option.options[tonumber(option.value)], xPosMax-selectWidth+5-rightPadding, yPos-(oHeight/3)-oPadding, oHeight*0.85, "no")
							end
						end
						glColor(1,1,1,0.11)
						RectRound(xPosMax-oHeight-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos, 1)
						glColor(1,1,1,0.16)
						glTexture(bgcorner)
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
	font:End()
end


function correctMouseForScaling(x,y)
	x = x - (((x/vsx)-0.5) * vsx)*((widgetScale-1)/widgetScale)
	y = y - (((y/vsy)-0.5) * vsy)*((widgetScale-1)/widgetScale)
	return x,y
end

local sec = 0
local lastUpdate = 0
function widget:Update(dt)
	if WG['advplayerlist_api'] and not WG['advplayerlist_api'].GetLockPlayerID() then
		--if select(7, Spring.GetMouseState()) then	-- when camera panning
		--	Spring.SetCameraState(Spring.GetCameraState(), cameraPanTransitionTime)
		--else
			Spring.SetCameraState(Spring.GetCameraState(), cameraTransitionTime)
		--end
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
			if WG['music'] and WG['music'].GetMusicVolume then
				options[getOptionByID('sndvolmusic')].value = WG['music'].GetMusicVolume()
			else
				options[getOptionByID('sndvolmusic')].value = tonumber(Spring.GetConfigInt("snd_volmusic",20) or 20)
			end
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
		elseif titleRect and IsOnRect(cx, cy, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
			return true
		elseif groupRect ~= nil then
			for id,group in pairs(optionGroups) do
				if advSettings or group.id ~= 'dev' then
					if IsOnRect(cx, cy, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
						return true
					end
				end
			end
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
  if chobbyInterface then return end
  if spIsGUIHidden() then return end

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

  if selectOptionsList then
  	if WG['guishader'] then
  		WG['guishader'].RemoveScreenRect('options_select')
  		WG['guishader'].removeRenderDlist(selectOptionsList)
  	end
  	glDeleteList(selectOptionsList)
  	selectOptionsList = nil
  end

  if (show or showOnceMore) and windowList then

	  --on window
	  local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
	  local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
	  local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
	  local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
	  local x,y,ml = Spring.GetMouseState()
	  local cx, cy = correctMouseForScaling(x,y)
	  if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
		  Spring.SetMouseCursor('cursornormal')
	  end
	  if groupRect ~= nil then
		  for id,group in pairs(optionGroups) do
			  if advSettings or group.id ~= 'dev' then
				  if IsOnRect(cx, cy, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
					  Spring.SetMouseCursor('cursornormal')
					  break
				  end
			  end
		  end
	  end
	  if titleRect ~= nil and IsOnRect(cx, cy, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
		  Spring.SetMouseCursor('cursornormal')
	  end

		-- draw the options panel
	  	  glPushMatrix()
			glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
			glScale(widgetScale, widgetScale, 1)
			glCallList(windowList)
			if WG['guishader'] then
				local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
				local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
				local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
				local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
				if backgroundGuishader ~= nil then
					glDeleteList(backgroundGuishader)
				end
				backgroundGuishader = glCreateList( function()
					-- background
					RectRound(rectX1, rectY2, rectX2, rectY1, 9*widgetScale, 0,1,1,1)
					-- title
					rectX1 = (titleRect[1] * widgetScale) - ((vsx * (widgetScale-1))/2)
					rectY1 = (titleRect[2] * widgetScale) - ((vsy * (widgetScale-1))/2)
					rectX2 = (titleRect[3] * widgetScale) - ((vsx * (widgetScale-1))/2)
					rectY2 = (titleRect[4] * widgetScale) - ((vsy * (widgetScale-1))/2)
					RectRound(rectX1, rectY1, rectX2, rectY2, 9*widgetScale, 1,1,0,0)
					-- tabs
					for id,group in pairs(optionGroups) do
						if advSettings or group.id ~= 'dev' then
							if groupRect[id] then
								rectX1 = (groupRect[id][1] * widgetScale) - ((vsx * (widgetScale-1))/2)
								rectY1 = (groupRect[id][2] * widgetScale) - ((vsy * (widgetScale-1))/2)
								rectX2 = (groupRect[id][3] * widgetScale) - ((vsx * (widgetScale-1))/2)
								rectY2 = (groupRect[id][4] * widgetScale) - ((vsy * (widgetScale-1))/2)
								RectRound(rectX1, rectY1, rectX2, rectY2, 9*widgetScale, 1,1,0,0)
							end
						end
					end
				end)
				WG['guishader'].InsertDlist(backgroundGuishader, 'options')
			end
			showOnceMore = false

			-- draw button hover
			local usedScreenX = (vsx*centerPosX) - ((screenWidth/2)*widgetScale)
			local usedScreenY = (vsy*centerPosY) + ((screenHeight/2)*widgetScale)

			-- mouseover (highlight and tooltip)

		  	local description = ''
			--local x,y,ml = Spring.GetMouseState()
			--local cx, cy = correctMouseForScaling(x,y)
			if titleRect ~= nil and IsOnRect(cx, cy, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
				local groupMargin = bgMargin/1.7
				gl.Color(1,1,1,0.1)
				RectRound(titleRect[1]+groupMargin, titleRect[2], titleRect[3]-groupMargin, titleRect[4]-groupMargin, groupMargin*1.8, 1,1,0,0)
			end
			if groupRect ~= nil then
				for id,group in pairs(optionGroups) do
					if advSettings or group.id ~= 'dev' then
						if IsOnRect(cx, cy, groupRect[id][1], groupRect[id][2], groupRect[id][3], groupRect[id][4]) then
							mouseoverGroupTab(id)
						end
					end
				end
			end
			if optionButtonForward ~= nil and IsOnRect(cx, cy, optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4]) then
				if ml then
					glColor(1,0.91,0.66,0.36)
				else
					glColor(1,1,1,0.14)
				end
				RectRound(optionButtonForward[1], optionButtonForward[2], optionButtonForward[3], optionButtonForward[4], (optionButtonForward[4]-optionButtonForward[2])/12)
			end
			if optionButtonBackward ~= nil and IsOnRect(cx, cy, optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4]) then
				if ml then
					glColor(1,0.91,0.66,0.36)
				else
					glColor(1,1,1,0.14)
				end
				RectRound(optionButtonBackward[1], optionButtonBackward[2], optionButtonBackward[3], optionButtonBackward[4], (optionButtonBackward[4]-optionButtonBackward[2])/12)
			end

			if not showSelectOptions then
				for i, o in pairs(optionHover) do
					if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) and options[i].type ~= 'label' then
						glColor(1,1,1,0.055)
						RectRound(o[1]-4, o[2], o[3]+4, o[4], 2)
						font:Begin()
						if options[i].description ~= nil then
							description = options[i].description
							font:Print('\255\235\190\122'..options[i].description, screenX+15, screenY-screenHeight+64.5, 16, "no")
						end
						font:SetTextColor(0.46,0.4,0.3,0.45)
						font:Print('/option '..options[i].id, screenX+screenWidth*0.659, screenY-screenHeight+8, 14, "nr")
						font:End()
					end
				end
				for i, o in pairs(optionButtons) do
					if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						gl.Color(0,0,0,0.08)
						RectRound(o[1], o[2], o[3], o[4], 1)
						if WG['tooltip'] ~= nil and options[i].type == 'slider' then
							local value = options[i].value
							if options[i].steps then
								value = NearestValue(options[i].steps, value)
							else
								local decimalValue, floatValue = math.modf(options[i].step)
								if floatValue ~= 0 then
									value = string.format("%."..string.len(string.sub(''..options[i].step, 3)).."f", value)	-- do rounding via a string because floats show rounding errors at times
								end
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
					glColor(1,1,1,0.07)
					for optionID, _ in pairs(presets['lowest']) do
						optionKey = getOptionByID(optionID)
						if optionHover[optionKey] ~= nil then
							RectRound(optionHover[optionKey][1], optionHover[optionKey][2]+1.33, optionHover[optionKey][3], optionHover[optionKey][4]-1.33, 1)
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

				selectOptionsList = glCreateList(function()
					if WG['guishader'] then
						glPushMatrix()
						glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
						glScale(widgetScale, widgetScale, 1)
                        glColor(0.25,0.25,0.25,0.7)
                    else
                        glColor(0.25,0.25,0.25,0.85)
                    end
					RectRound(optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4], 2)
					glColor(1,1,1,0.07)
					RectRound(optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4], 2)
					for i, option in pairs(options[showSelectOptions].options) do
						yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
						if IsOnRect(cx, cy, optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding) then
							glColor(1,1,1,0.18)
							RectRound(optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding, 2)
							if playSounds and (prevSelectHover == nil or prevSelectHover ~= i) then
								Spring.PlaySoundFile(selecthoverclick, 0.04, 'ui')
							end
							prevSelectHover = i
						end
						optionSelect[#optionSelect+1] = {optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding, i }

						if options[showSelectOptions].optionsFont and fontOption then
							fontOption[i]:Begin()
							fontOption[i]:Print('\255\255\255\255'..option, optionButtons[showSelectOptions][1]+7, yPos-(oHeight/2.25)-oPadding, oHeight*0.85, "no")
							fontOption[i]:End()
						else
							font:Begin()
							font:Print('\255\255\255\255'..option, optionButtons[showSelectOptions][1]+7, yPos-(oHeight/2.25)-oPadding, oHeight*0.85, "no")
							font:End()
						end
					end
					if WG['guishader'] then
						glPopMatrix()
					end
				end)
				if WG['guishader'] then
					local interfaceScreenCenterPosX = (screenX+(screenWidth/2))/vsx
					local interfaceScreenCenterPosY = (screenY-(screenHeight/2))/vsy

					-- translate coordinates to actual screen coords (because we applied glscale/gltranlate above)
					local x1 = (vsx*0.5) - (((vsx/2) - optionButtons[showSelectOptions][1]) * widgetScale)
					local x2 = (vsx*0.5) - (((vsx/2) - optionButtons[showSelectOptions][3]) * widgetScale)
					local y1 = (vsy*0.5) - (((vsy/2) - (yPos-oHeight-oPadding)) * widgetScale)
					local y2 = (vsy*0.5) - (((vsy/2) - optionButtons[showSelectOptions][4]) * widgetScale)
					WG['guishader'].InsertScreenRect(x1, y1, x2, y2, 'options_select')
					WG['guishader'].insertRenderDlist(selectOptionsList)
				else
					glCallList(selectOptionsList)
				end
			elseif prevSelectHover ~= nil then
				prevSelectHover = nil
			end
	  	glPopMatrix()
	else
		if WG['guishader'] then
			WG['guishader'].DeleteDlist('options')
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
		if showSelectOptions then
			showSelectOptions = nil
		--elseif draggingSlider ~= nil then
		--	options[draggingSlider].value = draggingSliderPreDragValue
		--	draggingSlider = nil
		--	sliderValueChanged = nil
		--	draggingSliderPreDragValue = nil
		else
			show = false
		end
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

function NearestValue(table, number)
	local smallestSoFar, smallestIndex
	for i, y in ipairs(table) do
		if not smallestSoFar or (math.abs(number-y) < smallestSoFar) then
			smallestSoFar = math.abs(number-y)
			smallestIndex = i
		end
	end
	return table[smallestIndex]
end

function getSliderValue(draggingSlider, cx)
	local sliderWidth = optionButtons[draggingSlider].sliderXpos[2] - optionButtons[draggingSlider].sliderXpos[1]
	local value = (cx - optionButtons[draggingSlider].sliderXpos[1]) / sliderWidth
	local min, max
	if options[draggingSlider].steps then
		min, max = options[draggingSlider].steps[1], options[draggingSlider].steps[1]
		for k, v in ipairs(options[draggingSlider].steps) do
			if v > max then max = v end
			if v < min then min = v end
		end
	else
		min = options[draggingSlider].min
		max = options[draggingSlider].max
	end
	value = min + ((max - min) * value)
	if value < min then value = min end
	if value > max then value = max end
	if options[draggingSlider].steps ~= nil then
		value = NearestValue(options[draggingSlider].steps, value)
	elseif options[draggingSlider].step ~= nil then
		value = math.floor((value+(options[draggingSlider].step/2)) / options[draggingSlider].step) * options[draggingSlider].step
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
			applyOptionValue(draggingSlider)	-- disabled so only on release it gets applied
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

	local cx, cy = correctMouseForScaling(x,y)
	if show then
		local cx, cy = correctMouseForScaling(x,y)
		if button == 3 then
			if titleRect ~= nil and IsOnRect(cx, cy, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
				return
			end
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

				if titleRect ~= nil and IsOnRect(cx, cy, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then	-- showhow rightmouse doesnt get triggered :S
					advSettings = not advSettings
					startColumn = 1
					if currentGroupTab == 'dev' then
						currentGroupTab = 'gfx'
					end
					return
				end
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
					draggingSliderPreDragValue = nil
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
					if advSettings or group.id ~= 'dev' then
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
								draggingSliderPreDragValue = options[draggingSlider].value
								local newValue = getSliderValue(draggingSlider,cx)
								if options[draggingSlider].value ~= newValue then
									options[draggingSlider].value = getSliderValue(draggingSlider,cx)
									applyOptionValue(draggingSlider)	-- disabled so only on release it gets applied
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


function lines(str)
	local t = {}
	local function helper(line) table.insert(t, line) return "" end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

function applyOptionValue(i, skipRedrawWindow)
	if options[i] == nil then return end

	if options[i].restart then
		changesRequireRestart = true
	end

	local id = options[i].id

	if options[i].widget ~= nil then
		if options[i].value then
			if widgetHandler.orderList[options[i].widget] < 0.5 then
				widgetHandler:EnableWidget(options[i].widget)
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

	if options[i].onchange then
		options[i].onchange(i, options[i].value)
	end

	if skipRedrawWindow == nil then
		if windowList then gl.DeleteList(windowList) end
		windowList = gl.CreateList(DrawWindow)
	end
end


-- loads values via stored game config in luaui/configs
function loadAllWidgetData()

	for oid,option in pairs(options) do
		if option.onload then
			option.onload()
		end
	end
end


function init()

	local supportedResolutions = {}
	local infolog = VFS.LoadFile("infolog.txt")
	if infolog then
		local fileLines = lines(infolog)
		local desktop = ''
		for i, line in ipairs(fileLines) do
			if addResolutions then
				local resolution = string.match(line, '[0-9]*x[0-9]*')
				if resolution and string.len(resolution) >= 7 then
					local resolution = string.gsub(resolution, "x", " x ")
					local resolutionX = string.match(resolution, '[0-9]*')
					local resolutionY = string.gsub(string.match(resolution, 'x [0-9]*'), 'x ', '')
					if tonumber(resolutionX) >= 640 and tonumber(resolutionY) >= 480 and resolution ~= desktop then
						supportedResolutions[#supportedResolutions+1] = resolution
					end
				else
					addResolutions = nil
					--break
				end
			end
			if string.find(line, '	display=') and not supportedResolutions[1] then
				if addResolutions then
					break
				end
				addResolutions = true
				local width = string.sub(string.match(line, 'w=([0-9]*)'), 1)
				local height = string.sub(string.match(line, 'h=([0-9]*)'), 1)
				desktop = width..' x '..height
				supportedResolutions[#supportedResolutions+1] = desktop
			end

			-- scan for shader version error
			if string.find(line, 'error: GLSL 1.50 is not supported') then
				Spring.SetConfigInt("ShaderVersionErrorDetected", 1)
				Spring.SetConfigInt("ForceShaders", 0)
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
		{id='dev', name='Dev'},
	}
	if (Spring.GetModOptions and (tonumber(Spring.GetModOptions().scavengers) or 0) ~= 0) then
		optionGroups[#optionGroups+1] = {id='scav', name='Scavengers'}
	end

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
		{id="preset", group="gfx", basic=true, name="Load graphics preset", type="select", options=presetNames, value=0, description='Wont reapply the preset every time you restart a game.\n\nSave custom preset with /savepreset name\nRightclick to delete a custom preset',
		  onload = function() end,
		  onchange = function(i, value)
			  Spring.Echo('Loading preset:   '..options[i].options[value])
			  options[i].value = 0
			  loadPreset(presetNames[value])
		  end,
		},
		--GFX
		{id="resolution", group="gfx", basic=true, name="Resolution", type="select", options=supportedResolutions, value=0, description='WARNING: sometimes freezes game engine in windowed mode',
		 onchange = function(i, value)
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
			 checkResolution()
		 end,
		},
		{id="fullscreen", group="gfx", basic=true, name="Fullscreen", type="bool", value=tonumber(Spring.GetConfigInt("Fullscreen",1) or 1) == 1,
		 onchange = function(i, value)
			 if value then
				 options[getOptionByID('borderless')].value = false
				 applyOptionValue(getOptionByID('borderless'))
				 local xres = tonumber(Spring.GetConfigInt('XResolutionWindowed',ssx))
				 local yres = tonumber(Spring.GetConfigInt('YResolutionWindowed',ssy))
				 Spring.SetConfigInt("XResolution", xres)
				 Spring.SetConfigInt("YResolution", yres)
			 else
				 local xres = tonumber(Spring.GetConfigInt('XResolution',ssx))
				 local yres = tonumber(Spring.GetConfigInt('YResolution',ssy))
				 Spring.SetConfigInt("XResolutionWindowed", xres)
				 Spring.SetConfigInt("YResolutionWindowed", yres)
			 end
			 checkResolution()
			 Spring.SendCommands("Fullscreen "..(value and 1 or 0))
			 Spring.SetConfigInt("Fullscreen",(value and 1 or 0))
		 end,},
		{id="borderless", group="gfx", basic=true, name="Borderless window", type="bool", value=tonumber(Spring.GetConfigInt("WindowBorderless",1) or 1) == 1, description="Changes will be applied next game.\n\n(dont forget to turn off the \'fullscreen\' option next game)",
		 onchange = function(i, value)
			 Spring.SetConfigInt("WindowBorderless",(value and 1 or 0))
			 if value then
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
			 checkResolution()
		 end,
		},
		{id="windowpos", group="gfx", basic=true, widget="Move Window Position", name="Move window position", type="bool", value=GetWidgetToggleValue("Move Window Position"), description='Toggle and move window position with the arrow keys or by dragging',
		 onchange = function(i, value)
			 Spring.SetConfigInt("FullscreenEdgeMove",(value and 1 or 0))
			 Spring.SetConfigInt("WindowedEdgeMove",(value and 1 or 0))
		 end,
		},
		{id="vsync", group="gfx", basic=true, name="V-sync", type="bool", value=tonumber(Spring.GetConfigInt("VSync",1) or 1) == 1, description='',
		 onchange=function(i,value)
			 Spring.SendCommands("Vsync "..(value and 1 or 0))
			 Spring.SetConfigInt("VSync",(value and 1 or 0))
		 end,
		},
		{id="msaa", group="gfx", basic=true, name="Anti Aliasing", type="slider", steps={0,1,2,4,8}, restart=true, value=tonumber(Spring.GetConfigInt("MSAALevel",1) or 2), description='Enables multisample anti-aliasing. NOTE: Can be expensive!\n\nChanges will be applied next game',
		 onchange=function(i,value)
			 Spring.SetConfigInt("MSAALevel",value)
		 end,
		},

		--{id="cas", group="gfx", widget="Contrast Adaptive Sharpen", name="Contrast Adaptive Sharpen", type="bool", value=GetWidgetToggleValue("Contrast Adaptive Sharpen"), description='Decreases blurriness and brings back details'},
		{id="cas_sharpness", group="gfx", name="Contrast Adaptive Sharpen", min=0.2, max=0.9, step=0.01, type="slider", value=0.6, description='How much sharpening should be applied to the image',
		 onload=function() loadWidgetData("Contrast Adaptive Sharpen", "cas_sharpness", {'SHARPNESS'}) end,
		 onchange=function(i, value)
			 saveOptionValue('Contrast Adaptive Sharpen', 'cas', 'setSharpness', {'SHARPNESS'}, options[getOptionByID('cas_sharpness')].value)
		 end,
		},

		{id="shadowslider", group="gfx", basic=true, name="Shadows", type="slider", steps={1024,2048,4096,8192}, value=tonumber(Spring.GetConfigInt("ShadowMapSize",1) or 4096), description='Set shadow detail',
		 onchange=function(i,value)
			 local enabled = (value < 1000) and 0 or 1
			 Spring.SendCommands("shadows "..enabled.." "..value)
			 Spring.SetConfigInt("shadows", value)
		 end,
		},
		{id="shadows_opacity", group="gfx", name=widgetOptionColor.."   opacity", type="slider", min=0.3, max=1, step=0.01, value=gl.GetSun("shadowDensity"), description='',
		 onchange=function(i,value)
			 Spring.SetSunLighting({groundShadowDensity = value, modelShadowDensity = value})
		 end,
		},
		{id="sun_y", group="gfx", name="Sun height", type="slider", min=0.05, max=0.9999, step=0.0001, value=select(2,gl.GetSun("pos")), description='',
		 onload = function() end,
		 onchange = function(i, value)
			 local sunX,sunY,sunZ = gl.GetSun("pos")
			 sunY = value
			 if sunY < options[getOptionByID('sun_y')].min then
				 sunY = options[getOptionByID('sun_y')].min
			 end
			 if sunY > options[getOptionByID('sun_y')].max then
				 sunY = options[getOptionByID('sun_y')].max
			 end
			 options[getOptionByID('sun_y')].value = sunY
			 Spring.SetSunDirection(sunX,sunY,sunZ)
			 -- just so that map/model lighting gets updated
			 Spring.SetSunLighting({groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity")})
			 customMapSunPos[Game.mapName] = {gl.GetSun("pos")}
		 end,
		},
		{id="sun_x", group="gfx", name=widgetOptionColor.."   pos X", type="slider", min=-0.9999, max=0.9999, step=0.0001, value=select(1,gl.GetSun("pos")), description='',
		 onload = function() end,
		 onchange = function(i, value)
			 local sunX,sunY,sunZ = gl.GetSun("pos")
			 sunX = value
			 if sunX < options[getOptionByID('sun_x')].min then
				 sunX = options[getOptionByID('sun_x')].min
			 end
			 if sunX > options[getOptionByID('sun_x')].max then
				 sunX = options[getOptionByID('sun_x')].max
			 end
			 options[getOptionByID('sun_x')].value = sunX
			 Spring.SetSunDirection(sunX,sunY,sunZ)
			 -- just so that map/model lighting gets updated
			 Spring.SetSunLighting({groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity")})
			 customMapSunPos[Game.mapName] = {gl.GetSun("pos")}
		 end,
		},
		{id="sun_z", group="gfx", name=widgetOptionColor.."   pos Z", type="slider", min=-0.9999, max=0.9999, step=0.0001, value=select(3,gl.GetSun("pos")), description='',
		 onload = function() end,
		 onchange = function(i, value)
			 local sunX,sunY,sunZ = gl.GetSun("pos")
			 sunZ = value
			 if sunZ < options[getOptionByID('sun_z')].min then
				 sunZ = options[getOptionByID('sun_z')].min
			 end
			 if sunZ > options[getOptionByID('sun_z')].max then
				 sunZ = options[getOptionByID('sun_z')].max
			 end
			 options[getOptionByID('sun_z')].value = sunZ
			 Spring.SetSunDirection(sunX,sunY,sunZ)
			 -- just so that map/model lighting gets updated
			 Spring.SetSunLighting({groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity")})
			 customMapSunPos[Game.mapName] = {gl.GetSun("pos")}
		 end,
		},
		{id="sun_reset", group="gfx", name=widgetOptionColor.."   reset map default", type="bool", value=false, description='',
		 onload = function() end,
		 onchange = function(i, value)
			 options[getOptionByID('sun_x')].value = defaultMapSunPos[1]
			 options[getOptionByID('sun_y')].value = defaultMapSunPos[2]
			 options[getOptionByID('sun_z')].value = defaultMapSunPos[3]
			 options[getOptionByID('sun_reset')].value = false
			 Spring.SetSunDirection(defaultMapSunPos[1],defaultMapSunPos[2],defaultMapSunPos[3])
			 -- just so that map/model lighting gets updated
			 Spring.SetSunLighting({groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity")})
			 Spring.Echo('resetted map sun defaults')
			 customMapSunPos[Game.mapName] = nil
		 end,
		},

		{id="darkenmap", group="gfx", name="Darken map", min=0, max=0.5, step=0.01, type="slider", value=0, description='Darkens the whole map (not the units)\n\nRemembers setting per map\nUse /resetmapdarkness if you want to reset all stored map settings',
		 onload = function() end,
		 onchange = function(i, value) saveOptionValue('Darken map', 'darkenmap', 'setMapDarkness', {'maps',Game.mapName:lower()}, value) end,
		},
		{id="darkenmap_darkenfeatures", group="gfx", name=widgetOptionColor.."   darken features", type="bool", value=false, description='Darkens features (trees, wrecks, ect..) along with darken map slider above\n\nNOTE: Can be CPU intensive: it cycles through all visible features \nand renders them another time.',
		 onload = function() end,
		 onchange = function(i, value) saveOptionValue('Darken map', 'darkenmap', 'setDarkenFeatures', {'darkenFeatures'}, value) end,
		},

		{id="ssao", group="gfx", basic=true, widget="SSAO", name="SSAO", type="bool", value=GetWidgetToggleValue("SSAO"), description='Screen-Space Ambient Occlusion.'},
		{id="ssao_strength", group="gfx", name=widgetOptionColor.."   strength", type="slider", min=4, max=15, step=1, value=8, description='',
		 onchange=function(i,value) saveOptionValue('SSAO', 'ssao', 'setStrength', {'strength'}, value) end,
		 onload=function() loadWidgetData("SSAO", "ssao_strength", {'strength'}) end,
		},
		{id="ssao_radius", group="gfx", name=widgetOptionColor.."   radius", type="slider", min=4, max=6, step=1, value=5, description='',
		 onchange=function(i,value) saveOptionValue('SSAO', 'ssao', 'setRadius', {'radius'}, value) end,
		 onload=function() loadWidgetData("SSAO", "ssao_radius", {'radius'}) end,
		},

		{id="outline", group="gfx", basic=true, widget="Outline", name="Unit outline", type="bool", value=GetWidgetToggleValue("Outline"), description='Adds a small outline to all units which makes them crisp.'},
		{id="outline_width", group="gfx", basic=true, name=widgetOptionColor.."   width", min=1, max=4, step=1, type="slider", value=1, description='Set the width of the outline',
		 onload=function() loadWidgetData("Outline", "outline_width", {'DILATE_HALF_KERNEL_SIZE'}) end,
		 onchange=function(i,value) saveOptionValue('Outline', 'outline', 'setWidth', {'DILATE_HALF_KERNEL_SIZE'}, value) end
		},
		{id="outline_mult", group="gfx", basic=true, name=widgetOptionColor.."   opacity", min=0.1, max=1, step=0.1, type="slider", value=0.5, description='Set the relative strength of the outline',
		 onload=function() loadWidgetData("Outline", "outline_mult", {'STRENGTH_MULT'}) end,
		 onchange=function(i,value) saveOptionValue('Outline', 'outline', 'setMult', {'STRENGTH_MULT'}, value) end,
		},
		{id="outline_color", group="gfx", name=widgetOptionColor.."   white", type="bool", value=false, description="Black (off) or white (on) colored outline ",
		 onload=function() loadWidgetData("Outline", "outline_color", {'whiteColored'}) end,
		 onchange=function(i, value)
			 saveOptionValue('Outline', 'outline', 'setColor', {'whiteColored'}, value)
		 end,
		},

		{id="bloomdeferred", group="gfx", basic=true, widget="Bloom Shader Deferred", name="Bloom (unit)", type="bool", value=GetWidgetToggleValue("Bloom Shader Deferred"), description='Unit highlights and lights will glow.\n\n(via deferred rendering = less lag)'},
		{id="bloomdeferredbrightness", group="gfx", name=widgetOptionColor.."   brightness", type="slider", min=0.4, max=1.1, step=0.05, value=1, description='',
		 onchange=function(i,value) saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setBrightness', {'glowAmplifier'}, value) end,
		 onload=function() loadWidgetData("Bloom Shader Deferred", "bloomdeferredbrightness", {'glowAmplifier'}) end,
		},
		--{id="bloomdeferredsize", group="gfx", name=widgetOptionColor.."   size", type="slider", min=0.8, max=1.5, step=0.05, value=1, description='',
		-- onchange=saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setBlursize', {'globalBlursizeMult'}, value) end,
		-- onload=function() loadWidgetData("Bloom Shader Deferred", "bloomdeferredsize", {'qualityBlursizeMult'}) end
		--},
		--{id="bloomdeferredquality", group="gfx", name=widgetOptionColor.."   quality", type="select", options={'low','medium'}, value=1, description='Render quality',
		-- onload=function() loadWidgetData("Bloom Shader Deferred", "bloomdeferredquality", {'qualityPreset'}) end,
		-- onchange=function(i,value) saveOptionValue('Bloom Shader Deferred', 'bloomdeferred', 'setPreset', {'qualityPreset'}, value) end
		--},

		{id="bloom", group="gfx", basic=true, widget="Bloom Shader", name="Bloom (global)", type="bool", value=GetWidgetToggleValue("Bloom Shader"), description='Bloom will make the map and units glow\n\n(might result in more laggy experience)'},
		{id="bloombrightness", group="gfx", name=widgetOptionColor.."   brightness", type="slider", min=0.15, max=0.5, step=0.05, value=0.25, description='',
		 onchange=function(i,value) saveOptionValue('Bloom Shader', 'bloom', 'setBrightness', {'basicAlpha'}, value) end,
		 onload=function() loadWidgetData("Bloom Shader", "bloombrightness", {'basicAlpha'}) end,
		},
		--{id="bloomsize", group="gfx", name=widgetOptionColor.."   size", type="slider", min=0.9, max=1.5, step=0.05, value=1.1, description='',
		--	onchange=saveOptionValue('Bloom Shader', 'bloom', 'setBlursize', {'globalBlursizeMult'}, value) end,
		-- onload=function() loadWidgetData("Bloom Shader", "bloomsize", {'globalBlursizeMult'}) end
		--},
		--{id="bloomquality", group="gfx", name=widgetOptionColor.."   quality", type="select", options={'low','medium'}, value=1, description='Render quality',
		-- onload=function() saveOptionValue('Bloom Shader', 'bloom', 'setPreset', {'qualityPreset'}, value) end,
		-- onchange=function(i,value) saveOptionValue('Bloom Shader', 'bloom', 'setPreset', {'qualityPreset'}, value) end
		--},

		{id="mapedgeextension", group="gfx", basic=true, widget="Map Edge Extension", name="Map edge extension", type="bool", value=GetWidgetToggleValue("Map Edge Extension"), description='Mirrors the map at screen edges and darkens and decolorizes them\n\nEnable shaders for best result'},


		{id="water", group="gfx", basic=true, name="Water type", type="select", options={'basic','reflective','dynamic','reflective&refractive','bump-mapped'}, value=(tonumber(Spring.GetConfigInt("Water",1) or 1)+1),
		 onchange=function(i,value)
			 Spring.SendCommands("water "..(value-1))
			 --Spring.SendCommands("water "..(value-1)) -- dont know why i applied it twice, so disabling for now
		 end,
		},

		{id="decals", group="gfx", basic=true, name="Ground decals", type="slider", min=0, max=5, step=1, value=tonumber(Spring.GetConfigInt("GroundDecals",1) or 1), description='Set how long map decals will stay.\n\nDecals are ground scars, footsteps/tracks and shading under buildings',
		 onload = function() end,
		 onchange = function(i, value)
			 Spring.SetConfigInt("GroundDecals", value)
			 Spring.SendCommands("GroundDecals "..value)
			 Spring.SetConfigInt("GroundScarAlphaFade", 1)
		 end,
		},
		{id="grounddetail", group="gfx", basic=true, name="Ground detail", type="slider", min=75, max=200, step=1, value=tonumber(Spring.GetConfigInt("GroundDetail",1) or 1), description='Set how detailed the map mesh/model is',
		 onload = function() end,
		 onchange = function(i, value)
			 Spring.SetConfigInt("GroundDetail", value)
			 Spring.SendCommands("GroundDetail "..value)
		 end,
		},

		{id="disticon", group="gfx", basic=true, name="Strategic icon distance", type="slider", min=0, max=900, step=10, value=tonumber(Spring.GetConfigInt("UnitIconDist",1) or 400), description='Set a lower value to get better performance',
		 onload = function() end,
		 onchange = function(i, value)
			 if Spring.GetConfigInt("distdraw",1) < 10000 then
				 Spring.SendCommands("distdraw 10000")
			 end
			 Spring.SendCommands("disticon "..value)
		 end,
		},
		{id="iconscale", group="gfx", basic=true, name=widgetOptionColor.."   scale", type="slider", min=0.85, max=1.35, step=0.05, value=tonumber(Spring.GetConfigFloat("UnitIconScale",1.15) or 1.05), description='Note that the minimap icon size is affected as well',
		 onload = function() end,
		 onchange = function(i, value) Spring.SendCommands("luarules uniticonscale "..value) end,
		},
		{id="minimapiconsize", group="gfx", name=widgetOptionColor.."   minimap scale", type="slider", min=1.5, max=5, step=0.25, value=tonumber(Spring.GetConfigFloat("MinimapIconScale",3.5) or 1), description='',
		 onload = function() end,
		 onchange = function(i, value) minimapIconsize = value
			 Spring.SetConfigFloat("MinimapIconScale", value)
			 Spring.SendCommands("minimap unitsize "..value)		-- spring wont remember what you set with '/minimap iconssize #'
		 end,
		},

		{id="featuredrawdist", group="gfx", name="Feature draw distance", type="slider", min=2500, max=15000, step=500, value=tonumber(Spring.GetConfigInt("FeatureDrawDistance",6000) or 400), description='Features (trees, stones, wreckage) stop being displayed at this distance',
		 onload = function() end,
		 onchange = function(i, value)
			 if getOptionByID('featurefadedist') and value < options[getOptionByID('featurefadedist')].value then
				 options[getOptionByID('featurefadedist')].value = value
				 Spring.SetConfigInt("FeatureFadeDistance",value)
			 end
			 Spring.SetConfigInt("FeatureDrawDistance",value)
		 end,
		},
		--{id="featurefadedist", group="gfx", name=widgetOptionColor.."   fade distance", type="slider", min=2500, max=15000, step=500, value=tonumber(Spring.GetConfigInt("FeatureFadeDistance",4500) or 400), description='Features (trees, stones, wreckage) start fading away from this distance',
		--	onload = function() end,
		--	onchange = function(i, value)
		--		if getOptionByID('featuredrawdist') and value > options[getOptionByID('featuredrawdist')].value then
		--			options[getOptionByID('featuredrawdist')].value = value
		--			Spring.SetConfigInt("FeatureDrawDistance",value)
		--		end
		--		Spring.SetConfigInt("FeatureFadeDistance",value)
		--	end,
		--},

		{id="particles", group="gfx", basic=true, name="Particle limit", type="slider", min=10000, max=40000, step=1000, value=tonumber(Spring.GetConfigInt("MaxParticles",1) or 15000), description='Particle limit used for explosions, smoke, fire and missiletrails\n\nBeware, a too low value can result in the particle bugdget being reached,\nand effects no longer show up',
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigInt("MaxParticles",value) end,
		},

		{id="lighteffects", group="gfx", basic=true, name="Lights", type="bool", value=GetWidgetToggleValue("Light Effects"), description='Adds lights to projectiles, lasers and explosions.\n\nRequires shaders.',
		 onload = function() end,
		 onchange = function(i, value)
			 if value  then
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
		 end,
		},
		{id="lighteffects_life", group="gfx", name=widgetOptionColor.."   lifetime", min=0.4, max=0.9, step=0.05, type="slider", value=0.75, description='lifetime of explosion lights',
		 onload = function() loadWidgetData("Light Effects", "lighteffects_life", {'globalLifeMult'}) end,
		 onchange = function(i, value) saveOptionValue('Light Effects', 'lighteffects', 'setLife', {'globalLifeMult'}, value) end,
		},
		{id="lighteffects_brightness", group="gfx", name=widgetOptionColor.."   brightness", min=0.8, max=2, step=0.1, type="slider", value=1.3, description='Set the brightness of the lights',
		 onload = function() loadWidgetData("Light Effects", "lighteffects_brightness", {'globalLightMult'}) end,
		 onchange = function(i, value) saveOptionValue('Light Effects', 'lighteffects', 'setGlobalBrightness', {'globalLightMult'}, value) end,
		},
		{id="lighteffects_radius", group="gfx", name=widgetOptionColor.."   radius", min=1, max=1.6, step=0.1, type="slider", value=1.3, description='Set the radius of the lights\n\nWARNING: the bigger the radius the heavier on the GPU',
		 onload = function() loadWidgetData("Light Effects", "lighteffects_radius", {'globalRadiusMult'}) end,
		 onchange = function(i, value) saveOptionValue('Light Effects', 'lighteffects', 'setGlobalRadius', {'globalRadiusMult'}, value) end,
		},
		--{id="lighteffects_laserbrightness", group="gfx", name=widgetOptionColor.."   laser brightness", min=0.4, max=2, step=0.1, type="slider", value=1.2, description='laser lights brightness RELATIVE to global light brightness set above\n\n(only applies to real map and model lighting)',
		--		 onload = function() loadWidgetData("Light Effects", "lighteffects_laserbrightness", {'globalLightMultLaser'}) end,
		--		 onchange = function(i, value) saveOptionValue('Light Effects', 'lighteffects', 'setLaserBrightness', {'globalLightMultLaser'}, value) end,
		--		},
		--{id="lighteffects_laserradius", group="gfx", name=widgetOptionColor.."   laser radius", min=0.5, max=1.6, step=0.1, type="slider", value=1, description='laser lights radius RELATIVE to global light radius set above\n\n(only applies to real map and model lighting)',
		--		 onload = function() loadWidgetData("Light Effects", "lighteffects_laserradius", {'globalRadiusMultLaser'}) end,
		--		 onchange = function(i, value) saveOptionValue('Light Effects', 'lighteffects', 'setLaserRadius', {'globalRadiusMultLaser'}, value) end,
		--		},

		{id="dof", group="gfx", widget="Depth of Field", name="Depth of Field", type="bool", value=GetWidgetToggleValue("Depth of Field"), description='Applies out of focus blur'},
		{id="dof_autofocus", group="gfx", name=widgetOptionColor.."   autofocus", type="bool", value=true, description='Disable to have mouse position focus',
		 onload = function() loadWidgetData("Depth of Field", "dof_autofocus", {'autofocus'}) end,
		 onchange = function(i, value) saveOptionValue('Depth of Field', 'dof', 'setAutofocus', {'autofocus'}, value) end,
		},
		{id="dof_fstop", group="gfx", name=widgetOptionColor.."   f-stop", type="slider", min=1, max=6, step=0.1, value=2, description='Set amount of blur\n\nOnly works if autofocus is off',
		 onload = function() loadWidgetData("Depth of Field", "dof_fstop", {'fStop'}) end,
		 onchange = function(i, value) saveOptionValue('Depth of Field', 'dof', 'setFstop', {'fStop'}, value) end,
		},

		{id="nanoeffect", group="gfx", name="Nano effect", type="select", options={'beam','particles'}, value=tonumber(Spring.GetConfigInt("NanoEffect",1) or 1), description='Sets nano effect\n\nBeams more expensive than particles',
		 onload = function() end,
		 onchange = function(i, value)
			 Spring.SetConfigInt("NanoEffect",value)
			 if value == 1 then
				 Spring.SetConfigInt("MaxNanoParticles",0)
			 else
				 Spring.SetConfigInt("MaxNanoParticles",maxNanoParticles)
			 end
		 end,
		},
		--{id="lighteffects_nanolaser", group="gfx", name=widgetOptionColor.."   beam light  (needs 'Lights')", type="bool", value=true, description='Shows a light for every build/reclaim nanolaser',
		--		 onload = function() loadWidgetData("Light Effects", "lighteffects_nanolaser", {'enableNanolaser'}) end,
		--		 onchange = function(i, value) saveOptionValue('Light Effects', 'lighteffects', 'setNanolaser', {'enableNanolaser'}, value) end,
		--		},
		--{id="nanobeamicon", group="gfx", name=widgetOptionColor.."   beam when uniticon", type="bool", value=tonumber(Spring.GetConfigInt("NanoLaserIcon",0) or 0) == 1, description='Shows nano beams when unit is displayed as icon',
		--		 onload = function() end,
		--		 onchange = function(i, value) Spring.SendCommands("luarules uniticonlasers "..value) end,
		--		},
		{id="nanobeamamount", group="gfx", name=widgetOptionColor.."   beam amount", type="slider", min=5, max=20, step=1, value=tonumber(Spring.GetConfigInt("NanoBeamAmount",10) or 10), description='Not number of total beams (but total of new beams per gameframe)\n\nBeams aren\'t cheap so lower this setting for better performance',
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigInt("NanoBeamAmount",value) end,
		},
		{id="nanoparticles", group="gfx", name=widgetOptionColor.."   max nano particles", type="slider", min=1000, max=15000, step=100, value=maxNanoParticles, description='',
		 onload = function() end,
		 onchange = function(i, value)
			 maxNanoParticles = value
			 if options[getOptionByID('nanoeffect')].value == 2 then
				 Spring.SetConfigInt("MaxNanoParticles",value)
			 end
		 end,
		},

		{id="lups", group="gfx", widget="LupsManager", name="Particle / shader FX", type="bool", value=GetWidgetToggleValue("LupsManager"), description='Jet engine thrusters, additional lighting.'},
		{id="lupsdistortedshields", group="gfx", name=widgetOptionColor.."   distorted shields", type="bool", value=tonumber(Spring.GetConfigInt("lupsdistortedshields",0) or 0) == 1, description='Make the shields distorted, like water',
		 onload = function() end,
		 onchange = function(i, value)
			 Spring.SetConfigInt("lupsdistortedshields",(value and 1 or 0))
			 local widgetname = "LupsManager"
			 if GetWidgetToggleValue(widgetname) then
				 widgetHandler:DisableWidget(widgetname)
				 widgetHandler:EnableWidget(widgetname)
			 end
		 end,
		},
		{id="lupsreflectionrefraction", group="gfx", name=widgetOptionColor.."   reflection and refraction pass", type="bool", value=tonumber(Spring.GetConfigInt("lupsreflectionrefraction",0) or 0) == 1, description='The settings seem only relevant near water\nand disabling them reduces draw passes',
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigInt("lupsreflectionrefraction",(value and 1 or 0)) end,
		},
		{id="lighteffects_thrusters", group="gfx", name=widgetOptionColor.."   air thruster light  (needs 'Lights')", type="bool", value=true, description='Shows a light for air engine thrusters (fighters and scouts excluded)',
		 onload = function() loadWidgetData("Light Effects", "lighteffects_thrusters", {'enableThrusters'}) end,
		 onchange = function(i, value)
			 saveOptionValue('Light Effects', 'lighteffects', 'setThrusters', {'enableThrusters'}, value)
		 end,
		},

		--{id="treeradius", group="gfx", name="Tree render distance", type="slider", min=0, max=2000, step=50, restart=true, value=tonumber(Spring.GetConfigInt("TreeRadius",1) or 1000), description='Applies to SpringRTS engine default trees\n\nChanges will be applied next game',
		--		 onload = function() end,
		--		 onchange = function(i, value) Spring.SetConfigInt("TreeRadius",value) end,
		--		},
		--{id="treewind", group="gfx", basic=true, name="Tree Wind", type="bool", value=tonumber(Spring.GetConfigInt("TreeWind",1) or 1) == 1, description='Makes trees wave in the wind.\n\n(will not apply too every tree type)',
		-- onload = function() end,
		-- onchange = function(i, value)
		--	 Spring.SendCommands("luarules treewind "..(value and 1 or 0))
		--	 Spring.SetConfigInt("TreeWind",(value and 1 or 0))
		-- end,
		--},

		{id="snow", group="gfx", basic=true, widget="Snow", name="Snow", type="bool", value=GetWidgetToggleValue("Snow"), description='Snow widget (By default.. maps with wintery names have snow applied)'},
		{id="snowmap", group="gfx", name=widgetOptionColor.."   enabled on this map", type="bool", value=true, description='It will remember what you toggled for every map\n\n\(by default: maps with wintery names have this toggled)',
		 onload = function() loadWidgetData("Snow", "snowmap", {'snowMaps',Game.mapName:lower()}) end,
		 onchange = function(i, value) saveOptionValue('Snow', 'snow', 'setSnowMap', {'snowMaps',Game.mapName:lower()}, value) end,
		},
		{id="snowautoreduce", group="gfx", name=widgetOptionColor.."   auto reduce", type="bool", value=true, description='Automaticly reduce snow when average FPS gets lower\n\n(re-enabling this needs time to readjust  to average fps again',
		 onload = function() loadWidgetData("Snow", "snowautoreduce", {'autoReduce'}) end,
		 onchange = function(i, value) saveOptionValue('Snow', 'snow', 'setAutoReduce', {'autoReduce'}, value) end,
		},
		{id="snowamount", group="gfx", name=widgetOptionColor.."   amount", type="slider", min=0.2, max=2, step=0.2, value=1, description='disable "auto reduce" option to see the max snow amount you have set',
		 onload = function() loadWidgetData("Snow", "snowamount", {'customParticleMultiplier'}) end,
		 onchange = function(i, value) saveOptionValue('Snow', 'snow', 'setMultiplier', {'customParticleMultiplier'}, value) end,
		},

		{id="resurrectionhalos", group="gfx", widget="Resurrection Halos", name="Resurrected unit halos", type="bool", value=GetWidgetToggleValue("Resurrection Halos"), description='Gives units have have been resurrected a little halo above it.'},
		{id="tombstones", group="gfx", widget="Tombstones", name="Tombstones", type="bool", value=GetWidgetToggleValue("Tombstones"), description='Displays tombstones where commanders died'},

		-- SND
		{id="sndvolmaster", group="snd", basic=true, name="Master volume", type="slider", min=0, max=200, step=2, value=tonumber(Spring.GetConfigInt("snd_volmaster",1) or 100),
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigInt("snd_volmaster", value) end,
		},
		{id="sndvolgeneral", group="snd", basic=true, name=widgetOptionColor.."   general", type="slider", min=0, max=100, step=2, value=tonumber(Spring.GetConfigInt("snd_volgeneral",1) or 100),
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigInt("snd_volgeneral", value) end,
		},
		{id="sndvolbattle", group="snd", basic=true, name=widgetOptionColor.."   battle", type="slider", min=0, max=100, step=2, value=tonumber(Spring.GetConfigInt("snd_volbattle",1) or 100),
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigInt("snd_volbattle", value) end,
		},
		{id="sndvolui", group="snd", basic=true, name=widgetOptionColor.."   interface", type="slider", min=0, max=100, step=2, value=tonumber(Spring.GetConfigInt("snd_volui",1) or 100),
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigInt("snd_volui", value) end,
		},
		{id="sndvolunitreply", group="snd", basic=true, name=widgetOptionColor.."   unit reply", type="slider", min=0, max=100, step=2, value=tonumber(Spring.GetConfigInt("snd_volunitreply",1) or 100),
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigInt("snd_volunitreply", value) end,
		},
		{id="sndvolmusic", group="snd", basic=true, name=widgetOptionColor.."   music", type="slider", min=0, max=50, step=2, value=tonumber(Spring.GetConfigInt("snd_volmusic",20) or 20),
		 onload = function() end,
		 onchange = function(i, value)
			 if WG['music'] and WG['music'].SetMusicVolume then
				 WG['music'].SetMusicVolume(value)
			 else
				 Spring.SetConfigInt("snd_volmusic", value)
			 end
		 end,
		},
		--{id="sndairabsorption", group="snd", name="Air absorption", type="slider", min=0, max=1, step=0.01, value=tonumber(Spring.GetConfigFloat("snd_airAbsorption",1) or.1),
		--		 onload = function() end,
		--		 onchange = function(i, value) Spring.SetConfigFloat("snd_airAbsorption", value) end,
		--		},
		--{id="buildmenusounds", group="snd", name="Buildmenu click sounds", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigPlaySounds~= nil and WG['red_buildmenu'].getConfigPlaySounds()), description='Plays a sound when clicking on orders or buildmenu icons',
		--		 onload = function() end,
		--		 onchange=function(i,value) saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigPlaySounds', {'playSounds'}, value) end
		--		},

		{id="voicenotifs", group="snd", basic=true, widget="Voice Notifs", name="Voice notifications", type="bool", value=GetWidgetToggleValue("Voice Notifs"), description='Plays various voice notifications\n\nAdjust volume with the interface volume slider'},
		{id="voicenotifs_playtrackedplayernotifs", group="snd", name=widgetOptionColor.."   tracked cam/player notifs",type="bool", value=(WG['voicenotifs']~=nil and WG['voicenotifs'].getPlayTrackedPlayerNotifs()), description='Play voice notifs from the perspective of the currently camera tracked player',
		 onload = function() loadWidgetData("Voice Notifs", "voicenotifs_playtrackedplayernotifs", {'playTrackedPlayerNotifs'}) end,
		 onchange = function(i, value) saveOptionValue('Voice Notifs', 'voicenotifs', 'setPlayTrackedPlayerNotifs', {'playTrackedPlayerNotifs'}, value) end,
		},
		{id="voicenotifs_volume", group="snd", basic=true, name=widgetOptionColor.."   volume", type="slider", min=0.05, max=1, step=0.05, value=1, description='NOTE: It uses interface volume channel',
		 onload = function() loadWidgetData("Voice Notifs", "voicenotifs_volume", {'volume'}) end,
		 onchange = function(i, value) saveOptionValue('Voice Notifs', 'voicenotifs', 'setVolume', {'volume'}, value) end,
		},

		{id="scav_voicenotifs", group="scav", basic=true, widget="Scavenger Audio Reciever", name="Scavenger voice notifications", type="bool", value=GetWidgetToggleValue("Scavenger Audio Reciever"), description='Toggle the scavenger announcer voice'},


		-- CONTROL
		{id="hwcursor", group="control", basic=true, name="Hardware cursor", type="bool", value=tonumber(Spring.GetConfigInt("hardwareCursor",1) or 1) == 1, description="When disabled: mouse cursor refresh rate will equal to your ingame fps",
		 onload = function() end,
		 onchange = function(i, value)
			 Spring.SendCommands("HardwareCursor "..(value and 1 or 0))
			 Spring.SetConfigInt("HardwareCursor",(value and 1 or 0))
		 end,
		},
		--{id="cursor", group="control", basic=true, name="Cursor", type="select", options={}, value=1, description='Choose a different mouse cursor style and/or size',
		-- onchange=function(i, value)
		--	 saveOptionValue('Cursors', 'cursors', 'setcursor', {'cursorSet'}, options[i].options[value])
		-- end,
		--},
		{id="cursorsize", group="control", basic=true, name="Cursor size", type="slider", min=0.3, max=1.7, step=0.1, value=1, description='Note that cursor already auto scales according to screen resolution\n\nFurther adjust size and snap to a smaller/larger size',
		 onload = function() end,
		 onchange = function(i, value) if WG['cursors'] then WG['cursors'].setsizemult(value) end end,
		},
		{id="crossalpha", group="control", name="Cursor 'cross' alpha", type="slider", min=0, max=1, step=0.05, value=tonumber(Spring.GetConfigString("CrossAlpha",1) or 1), description='Opacity of mouse icon in center of screen when you are in camera pan mode\n\n(The\'icon\' has a dot in center with 4 arrows pointing in all directions)',
		 onload = function() end,
		 onchange = function(i, value) Spring.SendCommands("cross "..tonumber(Spring.GetConfigInt("CrossSize",1) or 10).." "..value) end,
		},

		{id="containmouse", group="control", basic=true, widget="Grabinput", name="Contain mouse", type="bool", value=GetWidgetToggleValue("Grabinput"), description='When in windowed mode, this prevents your mouse from moving out of it'},

		{id="screenedgemove", group="control", basic=true, name="Screen edge moves camera", type="bool", restart=true, value=tonumber(Spring.GetConfigInt("FullscreenEdgeMove",1) or 1) == 1, description="If mouse is close to screen edge this will move camera\n\nChanges will be applied next game",
		 onchange=function(i, value)
			 Spring.SetConfigInt("FullscreenEdgeMove", (value and 1 or 0))
			 Spring.SetConfigInt("WindowedEdgeMove", (value and 1 or 0))
		 end,
		},
		{id="screenedgemovewidth", group="control", basic=true, name=widgetOptionColor.."   edge width", type="slider", min=0, max=0.1, step=0.01, value=tonumber(Spring.GetConfigFloat("EdgeMoveWidth",1) or 1), description="In percentage of screen border",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("EdgeMoveWidth", value)
		 end,
		},
		{id="screenedgemovedynamic", group="control", name=widgetOptionColor.."   variable speed", type="bool", restart=true, value=tonumber(Spring.GetConfigInt("EdgeMoveDynamic",1) or 1) == 1, description="Enable if scrolling speed should fade with edge distance.",
		 onchange=function(i, value)
			 Spring.SetConfigInt("EdgeMoveDynamic", (value and 1 or 0))
		 end,
		},

		{id="camera", group="control", basic=true, name="Camera", type="select", options={'fps','overhead','spring','rot overhead','free'}, value=(tonumber((Spring.GetConfigInt("CamMode",1)+1) or 2)),
		 onchange = function(i, value)
			Spring.SetConfigInt("CamMode",(value-1))
			if value == 1 then Spring.SendCommands('viewfps')
			elseif value == 2 then Spring.SendCommands('viewta')
			elseif value == 3 then Spring.SendCommands('viewspring')
			elseif value == 4 then Spring.SendCommands('viewrot')
			elseif value == 5 then Spring.SendCommands('viewfree')
			end
		 end,
		},
		{id="camerashake", group="control", basic=true, widget="CameraShake", name=widgetOptionColor.."   shake", type="bool", value=GetWidgetToggleValue("CameraShake"), description='Shakes camera on explosions'},
		{id="camerasmoothness", group="control", name=widgetOptionColor.."   smoothing", type="slider", min=0, max=3, step=0.01, value=cameraTransitionTime, description="How smooth should the transitions between camera movement be?",
		 onload = function() end,
		 onchange = function(i, value)
			 cameraTransitionTime = value
			 --Spring.SetConfigFloat("CamTimeFactor", value)
		 end,
		},
		{id="camerapanspeed", group="control", basic=true, name=widgetOptionColor.."   middleclick grab speed", type="slider", min=-0.01, max=-0.00195, step=0.0001, value=Spring.GetConfigFloat("MiddleClickScrollSpeed", 0.0035), description="Smoothness of camera panning mode",
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigFloat("MiddleClickScrollSpeed", value) end,
		},
		{id="cameramovespeed", group="control", basic=true, name=widgetOptionColor.."   move speed", type="slider", min=0, max=50, step=1, value=Spring.GetConfigInt("CamSpringScrollSpeed", 10), description="Smoothness of camera moving mode",
		 onload = function() end,
		 onchange = function(i, value)
			 --cameraPanTransitionTime = value
			 Spring.SetConfigInt("FPSScrollSpeed", value)			-- spring default: 10
			 Spring.SetConfigInt("OverheadScrollSpeed", value)		-- spring default: 10
			 Spring.SetConfigInt("RotOverheadScrollSpeed", value)	-- spring default: 10
			 Spring.SetConfigFloat("CamFreeScrollSpeed", value*50)	-- spring default: 500
			 Spring.SetConfigInt("CamSpringScrollSpeed", value)		-- spring default: 10
		 end,
		},
		{id="scrollspeed", group="control", basic=true, name=widgetOptionColor.."   scroll zoom speed", type="slider", min=1, max=50, step=1, value=math.abs(tonumber(Spring.GetConfigInt("ScrollWheelSpeed",1) or 25)), description='',
		 onload = function() end,
		 onchange = function(i, value)
			 if options[getOptionByID('scrollinverse')].value then
				 Spring.SetConfigInt("ScrollWheelSpeed",-value)
			 else
				 Spring.SetConfigInt("ScrollWheelSpeed",value)
			 end
		 end,
		},
		{id="scrollinverse", group="control", basic=true, name=widgetOptionColor.."   reverse scrolling", type="bool", value=(tonumber(Spring.GetConfigInt("ScrollWheelSpeed",1) or 25) < 0), description="",
		 onload = function() end,
		 onchange = function(i, value)
			 if value then
				 Spring.SetConfigInt("ScrollWheelSpeed",-options[getOptionByID('scrollspeed')].value)
			 else
				 Spring.SetConfigInt("ScrollWheelSpeed",options[getOptionByID('scrollspeed')].value)
			 end
		 end,
		},

		--{id="fov", group="control", name=widgetOptionColor.."   FOV", type="slider", min=15, max=75, step=1, value=Spring.GetCameraFOV(), description="Camera field of view\n\nDefault: 45",
		-- onload = function() end,
		-- onchange = function(i, value)
		--	local current_cam_state = Spring.GetCameraState()
		--	if (current_cam_state.fov) then
		--		current_cam_state.fov = value
		--		Spring.SetCameraState(current_cam_state,0)
		--	end
		-- end,
		--},

		{id="lockcamera_transitiontime", group="control", name="Tracking cam smoothing", type="slider", min=0.4, max=1.5, step=0.01, value=(WG['advplayerlist_api']~=nil and WG['advplayerlist_api'].GetLockTransitionTime~=nil and WG['advplayerlist_api'].GetLockTransitionTime()), description="When viewing a players camera...\nhow smooth should the transitions between camera movement be?",
		 onload = function() loadWidgetData("AdvPlayersList", "lockcamera_transitiontime", {'transitionTime'}) end,
		 onchange = function(i, value) saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetLockTransitionTime', {'transitionTime'}, value) end,
		},

		-- INTERFACE
		{id="teamcolors", group="ui", basic=true, widget="Player Color Palette", name="Team colors based on a palette", type="bool", value=GetWidgetToggleValue("Player Color Palette"), description='Replaces lobby team colors for a color palette based one\n\nNOTE: reloads all widgets because these need to update their teamcolors'},
		{id="sameteamcolors", group="ui", basic=true, name=widgetOptionColor.."   same team colors", type="bool", value=(WG['playercolorpalette']~=nil and WG['playercolorpalette'].getSameTeamColors~=nil and WG['playercolorpalette'].getSameTeamColors()), description='Use the same teamcolor for all the players in a team\n\nNOTE: reloads all widgets because these need to update their teamcolors',
		 onload = function() end,
		 onchange = function(i, value) saveOptionValue('Player Color Palette', 'playercolorpalette', 'setSameTeamColors', {'useSameTeamColors'}, value) end,
		},
		{id="simpleminimapcolors", group="ui", name="Simple minimap colors", type="bool", value=tonumber(Spring.GetConfigInt("SimpleMiniMapColors",0) or 0) == 1, description="Enable simple minimap teamcolors\nRed is enemy,blue is ally and you are green!",
		 onload = function() end,
		 onchange = function(i, value)
			 Spring.SendCommands("minimap simplecolors  "..(value and 1 or 0))
			 Spring.SetConfigInt("SimpleMiniMapColors",(value and 1 or 0))
		 end,
		},

		{id="font", group="ui", name="Font", type="select", options={}, value=1, description='Regular read friendly font used for text',
		 onload = function() end,
		 onchange = function(i, value)
			 if VFS.FileExists(LUAUI_DIRNAME..'fonts/'..options[i].optionsFont[value]) then
				 Spring.SetConfigString("ui_font", options[i].optionsFont[value])
				 Spring.SendCommands("luarules reloadluaui")
			 end
		 end,
		},
		{id="font2", group="ui", name="Font 2", type="select", options={}, value=1, description='Stylistic font mainly used for names/buttons/titles',
		 onload = function() end,
		 onchange = function(i, value)
			 if VFS.FileExists(LUAUI_DIRNAME..'fonts/'..options[i].optionsFont[value]) then
				 Spring.SetConfigString("ui_font2", options[i].optionsFont[value])
				 Spring.SendCommands("luarules reloadluaui")
			 end
		 end,
		},
		{id="guiopacity", group="ui", basic=true, name="GUI opacity", type="slider", min=0, max=1, step=0.01, value=Spring.GetConfigFloat("ui_opacity",0.66), description='',
		 onload = function() end,
		 onchange = function(i, value) Spring.SetConfigFloat("ui_opacity", value) end,
		},

		{id="guishader", group="ui", basic=true, widget="GUI Shader", name="GUI blur", type="bool", value=GetWidgetToggleValue("GUI Shader"), description='Blurs the world under every user interface element'},
		{id="guishaderintensity", group="ui", name=widgetOptionColor.."   intensity", type="slider", min=0.001, max=0.003, step=0.0001, value=0.002, description='',
		 onload = function() loadWidgetData("GUI Shader", "guishaderintensity", {'blurIntensity'}) end,
		 onchange = function(i, value) saveOptionValue('GUI Shader', 'guishader', 'setBlurIntensity', {'blurIntensity'}, value) end,
		},

		{id="metalspots", group="ui", widget="Metalspots", name="Metalspot indicators", type="bool", value=GetWidgetToggleValue("Metalspots"), description='Shows a circle around metal spots with the amount of metal in it'},
		{id="metalspots_opacity", group="ui", name=widgetOptionColor.."   opacity", type="slider", min=0.1, max=1, step=0.01, value=0.5, description='Display metal values in the center',
		 onload=function() loadWidgetData("Metalspots", "metalspots_opacity", {'opacity'}) end,
		 onchange=function(i, value)
			 WG.metalspots.setShowValue(value)
			 saveOptionValue('Metalspots', 'metalspots', 'setOpacity', {'opacity'}, options[getOptionByID('metalspots_opacity')].value)
		 end,
		},
		{id="metalspots_values", group="ui", name=widgetOptionColor.."   show values", type="bool", value=true, description='Display metal values (during game))\n\nPre-gamestart or when in metalmap view (f4) this will always be shown',
		 onload=function() loadWidgetData("Metalspots", "metalspots_values", {'showValues'}) end,
		 onchange=function(i, value)
			 WG.metalspots.setShowValue(value)
			 saveOptionValue('Metalspots', 'metalspots', 'setShowValue', {'showValue'}, options[getOptionByID('metalspots_values')].value)
		 end,
		},
		{id="metalspots_metalviewonly", group="ui", name=widgetOptionColor.."   limit to F4 view", type="bool", value=false, description='Limit display to only during pre-gamestart or when in metalmap view (f4)',
		 onload=function() loadWidgetData("Metalspots", "metalspots_metalviewonly", {'metalViewOnly'}) end,
		 onchange=function(i, value)
			 saveOptionValue('Metalspots', 'metalspots', 'setMetalViewOnly', {'showValue'}, options[getOptionByID('metalspots_metalviewonly')].value)
		 end,
		},

		{id="cursorlight", group="ui", basic=true, widget="Cursor Light", name="Cursor light", type="bool", value=GetWidgetToggleValue("Cursor Light"), description='Adds a light at/above your cursor position'},
		{id="cursorlight_lightradius", group="ui", name=widgetOptionColor.."   radius", type="slider", min=0.15, max=1, step=0.05, value=1.5, description='',
		 onload=function() loadWidgetData("Cursor Light", "cursorlight_lightradius", {'lightRadiusMult'}) end,
		 onchange=function(i,value) saveOptionValue('Cursor Light', 'cursorlight', 'setLightRadius', {'lightRadiusMult'}, value) end,
		},
		{id="cursorlight_lightstrength", group="ui", name=widgetOptionColor.."   strength", type="slider", min=0.1, max=1.2, step=0.05, value=0.2, description='',
		 onload=function() loadWidgetData("Cursor Light", "cursorlight_lightstrength", {'lightStrengthMult'}) end,
		 onchange=function(i,value) saveOptionValue('Cursor Light', 'cursorlight', 'setLightStrength', {'lightStrengthMult'}, value) end,
		},

		{id="allycursors", group="ui", basic=true, widget="AllyCursors", name="Ally cursors", type="bool", value=GetWidgetToggleValue("AllyCursors"), description='Shows the position of ally cursors'},
		{id="allycursors_playername", group="ui",  name=widgetOptionColor.."   player name", type="bool", value=true, description='Shows the player name next to the cursor',
		 onload=function() loadWidgetData("AllyCursors", "allycursors_playername", {'showPlayerName'}) end,
		 onchange=function(i,value) saveOptionValue('AllyCursors', 'allycursors', 'setPlayerNames', {'showPlayerName'}, value) end,
		},
		{id="allycursors_spectatorname", group="ui",  name=widgetOptionColor.."   spectator name", type="bool", value=true, description='Shows the spectator name next to the cursor',
		 onload=function() loadWidgetData("AllyCursors", "allycursors_spectatorname", {'showSpectatorName'}) end,
		 onchange=function(i,value) saveOptionValue('AllyCursors', 'allycursors', 'setSpectatorNames', {'showSpectatorName'}, value) end,
		},
		{id="allycursors_showdot", group="ui",  name=widgetOptionColor.."   cursor dot", type="bool", value=true, description='Shows a dot at the center of ally cursor position',
		 onload=function() loadWidgetData("AllyCursors", "allycursors_showdot", {'showCursorDot'}) end,
		 onchange=function(i,value) saveOptionValue('AllyCursors', 'allycursors', 'setCursorDot', {'showCursorDot'}, value) end,
		},
		{id="allycursors_lights", group="ui", name=widgetOptionColor.."   lights (non-specs)", type="bool", value=true, description='Adds a colored light to every ally cursor',
		 onload=function() loadWidgetData("AllyCursors", "allycursors_lights", {'addLights'}) end,
		 onchange=function(i, value)
			 saveOptionValue('AllyCursors', 'allycursors', 'setLights', {'addLights'}, options[getOptionByID('allycursors_lights')].value)
		 end,
		},
		{id="allycursors_lightradius", group="ui", name=widgetOptionColor.."      radius", type="slider", min=0.15, max=1, step=0.05, value=0.5, description='',
		 onload=function() loadWidgetData("AllyCursors", "allycursors_lightradius", {'lightRadiusMult'}) end,
		 onchange=function(i,value) saveOptionValue('AllyCursors', 'allycursors', 'setLightRadius', {'lightRadiusMult'}, value) end,
		},
		{id="allycursors_lightstrength", group="ui", name=widgetOptionColor.."      strength", type="slider", min=0.1, max=1.2, step=0.05, value=0.85, description='',
		 onload=function() loadWidgetData("AllyCursors", "allycursors_lightstrength", {'lightStrengthMult'}) end,
		 onchange=function(i,value) saveOptionValue('AllyCursors', 'allycursors', 'setLightStrength', {'lightStrengthMult'}, value) end,
		},

		{id="showbuilderqueue", group="ui", basic=true, widget="Show builder queue", name="Show Builder Queue", type="bool", value=GetWidgetToggleValue("Show Builder Queue"), description='Shows ghosted buildings about to be built on the map'},

		{id="unitenergyicons", group="ui", basic=true, widget="Unit energy icons", name="Unit insufficient energy icons", type="bool", value=GetWidgetToggleValue("Unit energy icons"), description='Shows a red power bolt above units that cant fire their most e consuming weapon\nwhen you haven\'t enough energy availible.'},
		{id="unitenergyicons_self", group="ui", name=widgetOptionColor.."   limit to own units", type="bool", value=(WG['unitenergyicons']~=nil and WG['unitenergyicons'].getOnlyShowOwnTeam()), description='Only show above your own units',
		 onload = function() loadWidgetData("Unit energy icons", "unitenergyicons_self", {'onlyShowOwnTeam'}) end,
		 onchange = function(i, value) saveOptionValue('Unit energy icons', 'unitenergyicons', 'setOnlyShowOwnTeam', {'onlyShowOwnTeam'}, value) end,
		},

		{id="healthbarsscale", group="ui", name="Health bar scale", type="slider", min=0.7, max=1.31, step=0.1, value=1, description='',
		 onload=function() loadWidgetData("Health Bars", "healthbarsscale", {'barScale'}) end,
		 onchange=function(i,value) saveOptionValue('Health Bars', 'healthbars', 'setScale', {'barScale'}, value) end,
		},

		{id="nametags_icon", group="ui", name="Commander name on icon", type="bool", value=(WG['nametags']~=nil and WG['nametags'].getDrawForIcon()), description='Show commander name when its displayed as icon',
		 onload = function() loadWidgetData("Commander Name Tags", "nametags_icon", {'drawForIcon'}) end,
		 onchange = function(i, value) saveOptionValue('Commander Name Tags', 'nametags', 'setDrawForIcon', {'drawForIcon'}, value) end,
		},

		{id="consolemaxlines", group="ui", name="Console max lines", type="slider", min=3, max=9, step=1, value=6, description='',
		 onload = function()
			 loadWidgetData("Red Console (In-game chat only)", "consolemaxlines", {'Config','console','maxlines'})
		 end,
		 onchange = function(i, value)
			 saveOptionValue('Red Console (In-game chat only)', 'red_chatonlyconsole', 'setMaxLines', {'Config','console','maxlines'}, value)
			 saveOptionValue('Red Console (old)', 'red_console', 'setMaxLines', {'Config','console','maxlines'}, value)
		 end,
		},
		{id="consolefontsize", group="ui", name=widgetOptionColor.."   font size", type="slider", min=0.9, max=1.1, step=0.05, value=1, description='',
		 onload = function()
			 loadWidgetData("Red Console (In-game chat only)", "consolefontsize", {'fontsizeMultiplier'})
		 end,
		 onchange = function(i, value)
			 saveOptionValue('Red Console (In-game chat only)', 'red_chatonlyconsole', 'setFontsize', {'fontsizeMultiplier'}, value)
			 saveOptionValue('Red Console (old)', 'red_console', 'setFontsize', {'fontsizeMultiplier'}, value)
		 end,
		},

        {id="buildmenushortcuts", group="ui", name="Buildmenu shortcuts", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigShortcutsInfo()), description='Enables and shows shortcut keys in the buildmenu\n\n(reselect something to see the change applied)',
         onload = function() end,
         onchange = function(i, value) saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigShortcutsInfo', {'shortcutsInfo'}, value) end,
        },
		{id="buildmenuprices", group="ui", name=widgetOptionColor.."   prices", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigUnitPrice~=nil and WG['red_buildmenu'].getConfigUnitPrice()), description='Enables and shows unit prices in the buildmenu\n\n(reselect something to see the change applied)',
		 onload = function() end,
		 onchange = function(i, value) saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigUnitPrice', {'drawPrice'}, value) end,
		},
		{id="buildmenuradaricons", group="ui", name=widgetOptionColor.."   radar icons", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigUnitRadaricon~=nil and WG['red_buildmenu'].getConfigUnitRadaricon()), description='Shows unit radar icon in the buildmenu\n\n(reselect something to see the change applied)',
		 onload = function() end,
		 onchange = function(i, value) saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigUnitRadaricon', {'drawRadaricon'}, value) end,
		},
        {id="buildmenualternativeicons", group="ui", name=widgetOptionColor.."   alternative icons", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigAlternativeIcons()), description='Switch to a different unit icon set',
         onload = function() end,
         onchange = function(i, value)
             saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigAlternativeIcons', {'alternativeUnitpics'}, value)
             saveOptionValue('Selected Units Buttons', 'selunitbuttons', 'setAlternativeIcons', {'alternativeUnitpics'}, value)
             saveOptionValue('BuildBar', 'buildbar', 'setAlternativeIcons', {'alternativeUnitpics'}, value)
             saveOptionValue('Unit Stats', 'unitstats', 'setAlternativeIcons', {'alternativeUnitpics'}, value)
             saveOptionValue('Initial Queue', 'initialqueue', 'setAlternativeIcons', {'alternativeUnitpics'}, value)
         end,
        },
        --{id="buildmenulargeicons", group="ui", name=widgetOptionColor.."   enlarged", type="bool", value=(WG['red_buildmenu']~=nil and WG['red_buildmenu'].getConfigLargeUnitIcons~=nil and WG['red_buildmenu'].getConfigLargeUnitIcons()), description='Use large unit icons',
		-- onload = function() end,
		-- onchange = function(i, value) saveOptionValue('Red Build/Order Menu', 'red_buildmenu', 'setConfigLargeUnitIcons', {'largeUnitIons'}, value) end,
		--},
		{id="mascotte", group="ui", basic=true, widget="AdvPlayersList Mascotte", name="Playerlist mascotte", type="bool", value=GetWidgetToggleValue("AdvPlayersList Mascotte"), description='Shows a mascotte on top of the playerslist'},
		{id="unittotals", group="ui", basic=true, widget="AdvPlayersList Unit Totals", name=widgetOptionColor.."   unit totals", type="bool", value=GetWidgetToggleValue("AdvPlayersList Unit Totals"), description='Show your unit totals on top of the playerlist'},
		{id="musicplayer", group="ui", basic=true, widget="AdvPlayersList Music Player", name=widgetOptionColor.."   music player", type="bool", value=GetWidgetToggleValue("AdvPlayersList Music Player"), description='Show music player on top of playerlist',
		 onload = function() end,
		 onchange = function(i,value) if value then Spring.StopSoundStream() end end
		},

		{id="displaydps", group="ui", basic=true, name="Display DPS", type="bool", value=tonumber(Spring.GetConfigInt("DisplayDPS",0) or 0) == 1, description='Display the \'Damage Per Second\' done where target are hit',
		  onload = function()  end,
		  onchange = function(i, value)
			  Spring.SetConfigInt("DisplayDPS",(value and 1 or 0))
		  end,
		},

		{id="rankicons", group="ui", basic=true, widget="Rank Icons", name="Rank icons", type="bool", value=GetWidgetToggleValue("Rank Icons"), description='Shows a rank icon depending on experience next to units'},

		{id="idlebuilders", group="ui", basic=true, widget="Idle Builders", name="List idle builders", type="bool", value=GetWidgetToggleValue("Idle Builders"), description='Displays a row of idle builder units at the bottom of the screen'},
		--{id="commanderhurt", group="ui", widget="Commander Hurt Vignette", name="Commander hurt vignette", type="bool", value=GetWidgetToggleValue("Commander Hurt Vignette"), description='Shows a red vignette when commander is out of view and gets damaged'},

		{id="commandsfx", group="ui", basic=true, widget="Commands FX", name="Command FX", type="bool", value=GetWidgetToggleValue("Commands FX"), description='Shows unit target lines when you give orders\n\nThe commands from your teammates are shown as well'},
		{id="commandsfxfilterai", group="ui", name=widgetOptionColor.."   filter AI teams", type="bool", value=true, description='Hide commands for AI teams',
		 onload = function() loadWidgetData("Commands FX", "commandsfxfilterai", {'filterAIteams'}) end,
		 onchange = function(i, value) saveOptionValue('Commands FX', 'commandsfx', 'setFilterAI', {'filterAIteams'}, value) end,
		},
		{id="commandsfxopacity", group="ui", name=widgetOptionColor.."   opacity", type="slider", min=0.25, max=1, step=0.1, value=1, description='',
		 onload = function() loadWidgetData("Commands FX", "commandsfxopacity", {'opacity'}) end,
		 onchange = function(i, value) saveOptionValue('Commands FX', 'commandsfx', 'setOpacity', {'opacity'}, value) end,
		},

		{id="teamplatter", group="ui", basic=true, widget="TeamPlatter", name="Unit team platters", type="bool", value=GetWidgetToggleValue("TeamPlatter"), description='Shows a team color platter above all visible units'},
		{id="teamplatter_opacity", basic=true, group="ui", name=widgetOptionColor.."   opacity", min=0.15, max=0.4, step=0.01, type="slider", value=0.3, description='Set the opacity of the team spotters',
		 onload = function() loadWidgetData("TeamPlatter", "teamplatter_opacity", {'spotterOpacity'}) end,
		 onchange = function(i, value) saveOptionValue('TeamPlatter', 'teamplatter', 'setOpacity', {'spotterOpacity'}, value) end,
		},
		{id="teamplatter_skipownteam", group="ui", name=widgetOptionColor.."   skip own units", type="bool", value=false, description='Doesnt draw platters for yourself',
		 onload = function() loadWidgetData("TeamPlatter", "teamplatter_skipownteam", {'skipOwnTeam'}) end,
		 onchange = function(i, value) saveOptionValue('TeamPlatter', 'teamplatter', 'setSkipOwnTeam', {'skipOwnTeam'}, value) end,
		},

		{id="enemyspotter", group="ui", basic=true, widget="EnemySpotter", name="Enemy spotters", type="bool", value=GetWidgetToggleValue("EnemySpotter"), description='Draws smoothed circles under enemy units\n\nDisables when enemy is single colored or alone'},
		{id="enemyspotter_opacity", basic=true, group="ui", name=widgetOptionColor.."   opacity", min=0.12, max=0.4, step=0.01, type="slider", value=0.15, description='Set the opacity of the enemy-spotter rings',
		 onload = function() loadWidgetData("EnemySpotter", "enemyspotter_opacity", {'spotterOpacity'}) end,
		 onchange = function(i, value) saveOptionValue('EnemySpotter', 'enemyspotter', 'setOpacity', {'spotterOpacity'}, value) end,
		},
		--{id="enemyspotter_highlight", group="ui", name=widgetOptionColor.."   unit highlight", type="bool", value=false, description='Colorize/highlight enemy units',
		--		 onload = function() loadWidgetData("EnemySpotter", "enemyspotter_highlight", {'useXrayHighlight'}) end,
		--		 onchange = function(i, value) saveOptionValue('EnemySpotter', 'enemyspotter', 'setHighlight', {'useXrayHighlight'}, value) end,
		--		},

		{id="highlightselunits", group="ui", basic=true, widget="Highlight Selected Units", name="Highlight selected units", type="bool", value=GetWidgetToggleValue("Highlight Selected Units"), description='Highlights unit models when selected'},
		{id="highlightselunits_opacity", group="ui", basic=true, name=widgetOptionColor.."   opacity", min=0.05, max=0.3, step=0.01, type="slider", value=0.1, description='Set the opacity of the highlight on selected units',
		 onload = function() loadWidgetData("Highlight Selected Units", "highlightselunits_opacity", {'highlightAlpha'}) end,
		 onchange = function(i, value) saveOptionValue('Highlight Selected Units', 'highlightselunits', 'setOpacity', {'highlightAlpha'}, value) end,
		},
		--{id="highlightselunits_shader", group="ui", name=widgetOptionColor.."   use shader", type="bool", value=false, description='Highlight model edges a bit',
		--		 onload = function() loadWidgetData("Highlight Selected Units", "highlightselunits_shader", {'useHighlightShader'}) end,
		--		 onchange = function(i, value) saveOptionValue('Highlight Selected Units', 'highlightselunits', 'setShader', {'useHighlightShader'}, value) end,
		--		},
		{id="highlightselunits_teamcolor", group="ui", basic=true, name=widgetOptionColor.."   use teamcolor", type="bool", value=false, description='Use teamcolor instead of unit health coloring',
		 onload = function() loadWidgetData("Highlight Selected Units", "highlightselunits_teamcolor", {'useTeamcolor'}) end,
		 onchange = function(i, value)
			 saveOptionValue('Highlight Selected Units', 'highlightselunits', 'setTeamcolor', {'useTeamcolor'}, value)
		 end,
		},

		{id="fancyselectedunits", group="ui", basic=true, widget="Fancy Selected Units", name="Fancy selected units", type="bool", value=GetWidgetToggleValue("Fancy Selected Units"), description='Draws a platter under selected units\n\n\NOTE: this widget can be heavy when having lots of units selected'},
		--{id="fancyselectedunits_opacity", group="ui", name=widgetOptionColor.."   line opacity", min=0.8, max=1, step=0.01, type="slider", value=0.95, description='Set the opacity of the highlight on selected units',
		-- onload = function() loadWidgetData("Fancy Selected Units", "fancyselectedunits_opacity", {'spotterOpacity'}) end,
		-- onchange = function(i, value) saveOptionValue('Fancy Selected Units', 'fancyselectedunits', 'setOpacity', {'spotterOpacity'}, value) end,
		--},
		{id="fancyselectedunits_baseopacity", group="ui", name=widgetOptionColor.."   base opacity", min=0, max=0.5, step=0.01, type="slider", value=0.15, description='Set the opacity of the highlight on selected units',
		 onload = function() loadWidgetData("Fancy Selected Units", "fancyselectedunits_baseopacity", {'baseOpacity'}) end,
		 onchange = function(i, value) saveOptionValue('Fancy Selected Units', 'fancyselectedunits', 'setBaseOpacity', {'baseOpacity'}, value) end,
		},
		{id="fancyselectedunits_teamcoloropacity", group="ui", name=widgetOptionColor.."   teamcolor amount", min=0, max=1, step=0.01, type="slider", value=0.55, description='Set the amount of teamcolor used for the base platter',
		 onload = function() loadWidgetData("Fancy Selected Units", "fancyselectedunits_teamcoloropacity", {'teamcolorOpacity'}) end,
		 onchange = function(i, value) saveOptionValue('Fancy Selected Units', 'fancyselectedunits', 'setTeamcolorOpacity', {'teamcolorOpacity'}, value) end,
		},

		{id="givenunits", group="ui", widget="Given Units", name="Given unit icons", type="bool", value=GetWidgetToggleValue("Given Units"), description='Tags given units with \'new\' icon'},

		{id="defrange", group="ui", widget="Defense Range", name="Defense ranges", type="bool", value=GetWidgetToggleValue("Defense Range"), description='Displays range of defenses (enemy and ally)'},
		{id="defrange_allyair", group="ui", name=widgetOptionColor.."   Ally Air", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getAllyAir~=nil and WG['defrange'].getAllyAir()), description='Show Range For Ally Air',
		 onload = function() loadWidgetData("Defense Range", "defrange_allyair", {'enabled','ally','air'}) end,
		 onchange = function(i, value)
			 if widgetHandler.configData["Defense Range"] == nil then
				 widgetHandler.configData["Defense Range"] = {}
			 end
			 if widgetHandler.configData["Defense Range"].enabled == nil then
				 widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			 end
			 saveOptionValue('Defense Range', 'defrange', 'setAllyAir', {'enabled','ally','air'}, value)
		 end,
		},
		{id="defrange_allyground", group="ui", name=widgetOptionColor.."   Ally Ground", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getAllyGround~=nil and WG['defrange'].getAllyGround()), description='Show Range For Ally Ground',
		 onload = function() loadWidgetData("Defense Range", "defrange_allyground", {'enabled','ally','ground'}) end,
		 onchange = function(i, value)
			 if widgetHandler.configData["Defense Range"] == nil then
				 widgetHandler.configData["Defense Range"] = {}
			 end
			 if widgetHandler.configData["Defense Range"].enabled == nil then
				 widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			 end
			 saveOptionValue('Defense Range', 'defrange', 'setAllyGround', {'enabled','ally','ground'}, value)
		 end,
		},
		{id="defrange_allynuke", group="ui", name=widgetOptionColor.."   Ally Nuke", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getAllyNuke~=nil and WG['defrange'].getAllyNuke()), description='Show Range For Ally Air Nuke',
		 onload = function() loadWidgetData("Defense Range", "defrange_allynuke", {'enabled','ally','nuke'}) end,
		 onchange = function(i, value)
			 if widgetHandler.configData["Defense Range"] == nil then
				 widgetHandler.configData["Defense Range"] = {}
			 end
			 if widgetHandler.configData["Defense Range"].enabled == nil then
				 widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			 end
			 saveOptionValue('Defense Range', 'defrange', 'setAllyNuke', {'enabled','ally','nuke'}, value)
		 end,
		},
		{id="defrange_enemyair", group="ui", name=widgetOptionColor.."   Enemy Air", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getEnemyAir~=nil and WG['defrange'].getEnemyAir()), description='Show Range For Enemy Air',
		 onload = function() loadWidgetData("Defense Range", "defrange_enemyair", {'enabled','enemy','air'}) end,
		 onchange = function(i, value)
			 if widgetHandler.configData["Defense Range"] == nil then
				 widgetHandler.configData["Defense Range"] = {}
			 end
			 if widgetHandler.configData["Defense Range"].enabled == nil then
				 widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			 end
			 saveOptionValue('Defense Range', 'defrange', 'setEnemyAir', {'enabled','enemy','air'}, value)
		 end,
		},
		{id="defrange_enemyground", group="ui", name=widgetOptionColor.."   Enemy Ground", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getEnemyGround~=nil and WG['defrange'].getEnemyGround()), description='Show Range For Enemy Ground',
		 onload = function() loadWidgetData("Defense Range", "defrange_enemyground", {'enabled','enemy','ground'}) end,
		 onchange = function(i, value)
			 if widgetHandler.configData["Defense Range"] == nil then
				 widgetHandler.configData["Defense Range"] = {}
			 end
			 if widgetHandler.configData["Defense Range"].enabled == nil then
				 widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			 end
			 saveOptionValue('Defense Range', 'defrange', 'setEnemyGround', {'enabled','enemy','ground'}, value)
		 end,
		},
		{id="defrange_enemynuke", group="ui", name=widgetOptionColor.."   Enemy Nuke", type="bool", value=(WG['defrange']~=nil and WG['defrange'].getEnemyNuke~=nil and WG['defrange'].getEnemyNuke()), description='Show Range For Enemy Nuke',
		 onload = function() loadWidgetData("Defense Range", "defrange_enemynuke", {'enabled','enemy','nuke'}) end,
		 onchange = function(i, value)
			 if widgetHandler.configData["Defense Range"] == nil then
				 widgetHandler.configData["Defense Range"] = {}
			 end
			 if widgetHandler.configData["Defense Range"].enabled == nil then
				 widgetHandler.configData["Defense Range"].enabled = {ally={air=false,ground=false,nuke=false}, enemy={air=true,ground=true,nuke=true}}
			 end
			 saveOptionValue('Defense Range', 'defrange', 'setEnemyNuke', {'enabled','enemy','nuke'}, value)
		 end,
		},

		{id="allyselunits_select", group="ui", name="Tracking player: select units", type="bool", value=(WG['allyselectedunits']~=nil and WG['allyselectedunits'].getSelectPlayerUnits()), description="When viewing a players camera, this selects what the player has selected",
		 onload = function() loadWidgetData("Ally Selected Units", "allyselunits_select", {'selectPlayerUnits'}) end,
		 onchange = function(i, value) saveOptionValue('Ally Selected Units', 'allyselectedunits', 'setSelectPlayerUnits', {'selectPlayerUnits'}, value) end,
		},
		{id="lockcamera_hideenemies", group="ui", name=widgetOptionColor.."   only show tracked player viewpoint", type="bool", value=(WG['advplayerlist_api']~=nil and WG['advplayerlist_api'].GetLockHideEnemies()), description="When viewing a players camera, this will display what the tracked player sees",
		 onload = function() loadWidgetData("AdvPlayersList", "lockcamera_hideenemies", {'lockcameraHideEnemies'}) end,
		 onchange = function(i, value) saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetLockHideEnemies', {'lockcameraHideEnemies'}, value) end,
		},
		{id="lockcamera_los", group="ui", name=widgetOptionColor.."   show tracked player LoS", type="bool", value=(WG['advplayerlist_api']~=nil and WG['advplayerlist_api'].GetLockLos()), description="When viewing a players camera and los, shows shaded los ranges too",
		 onload = function() loadWidgetData("AdvPlayersList", "lockcamera_los", {'lockcameraLos'}) end,
		 onchange = function(i, value) saveOptionValue('AdvPlayersList', 'advplayerlist_api', 'SetLockLos', {'lockcameraLos'}, value) end,
		},

		{id="playertv_countdown", group="ui", name="Player TV countdown", type="slider", min=8, max=60, step=1, value=(WG['playertv']~=nil and WG['playertv'].GetPlayerChangeDelay()) or 40, description="Countdown time before it switches player",
		 onload = function() loadWidgetData("Player-TV", "playertv_countdown", {'playerChangeDelay'}) end,
		 onchange = function(i, value) saveOptionValue('Player-TV', 'playertv', 'SetPlayerChangeDelay', {'playerChangeDelay'}, value) end,
		},

		{id="scav_messages", group="scav", basic=true, name="Scavenger messages", type="bool", value=tonumber(Spring.GetConfigInt("scavmessages",1) or 1) == 1, description="",
		 onchange = function(i, value)
			 Spring.SetConfigInt("scavmessages",(value and 1 or 0))
		 end,
		},


		-- GAME
		{id="autoquit", group="game", basic=true, widget="Autoquit", name="Auto quit", type="bool", value=GetWidgetToggleValue("Autoquit"), description='Automatically quits after the game ends.\n...unless the mouse has been moved within a few seconds.'},

		{id="smartselect_includebuildings", group="game", basic=true, name="Include structures in area-selection", type="bool", value=false, description='When rectangle-drag-selecting an area, include building units too?\n\ndisabled: non-mobile units will be excluded\n(except: nanos always will be selected)',
		 onload = function() end,
		 onchange = function(i, value)
			 saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuildings', {'selectBuildingsWithMobile'}, value)
		 end,
		},
		{id="smartselect_includebuilders", group="game", basic=true, name=widgetOptionColor.."   include builders   (if above is off)", type="bool", value=true, description='When rectangle-drag-selecting an area, exclude builder units',
		 onload = function() end,
		 onchange = function(i, value)
			 saveOptionValue('SmartSelect', 'smartselect', 'setIncludeBuilders', {'includeBuilders'}, value)
		 end,
		},

		{id="onlyfighterspatrol", group="game", basic=true, widget="OnlyFightersPatrol", name="Only fighters patrol", type="bool", value=GetWidgetToggleValue("Autoquit"), description='Only fighters obey a factory\'s patrol route after leaving airlab.'},
		{id="fightersfly", group="game", basic=true, widget="Set fighters on Fly mode", name="Set fighters on Fly mode", type="bool", value=GetWidgetToggleValue("Set fighters on Fly mode"), description='Setting fighters on Fly mode when created'},

		{id="passivebuilders", group="game", basic=true, widget="Passive builders", name="Passive builders", type="bool", value=GetWidgetToggleValue("Passive builders"), description='Sets builders (nanos, labs and cons) on passive mode\n\nPassive mode means that builders will only spend energy when its availible.\nUsage: Set the most important builders on active and leave the rest passive'},
		{id="passivebuilders_nanos", group="game", name=widgetOptionColor.."   nanos", type="bool", value=(WG['passivebuilders']~=nil and WG['passivebuilders'].getPassiveNanos~=nil and WG['passivebuilders'].getPassiveNanos()), description='',
		 onload = function() loadWidgetData("Passive builders", "passivebuilders_nanos", {'passiveNanos'}) end,
		 onchange = function(i, value)
			 saveOptionValue('Passive builders', 'passivebuilders', 'setPassiveNanos', {'passiveNanos'}, value)
		 end,
		},
		{id="passivebuilders_cons", group="game", name=widgetOptionColor.."   cons", type="bool", value=(WG['passivebuilders']~=nil and WG['passivebuilders'].getPassiveCons~=nil and WG['passivebuilders'].getPassiveCons()), description='',
		 onload = function() loadWidgetData("Passive builders", "passivebuilders_cons", {'passiveCons'}) end,
		 onchange = function(i, value)
			 saveOptionValue('Passive builders', 'passivebuilders', 'setPassiveCons', {'passiveCons'}, value)
		 end,
		},
		{id="passivebuilders_labs", group="game", name=widgetOptionColor.."   labs", type="bool", value=(WG['passivebuilders']~=nil and WG['passivebuilders'].getPassiveLabs~=nil and WG['passivebuilders'].getPassiveLabs()), description='',
		 onload = function() loadWidgetData("Passive builders", "passivebuilders_labs", {'passiveLabs'}) end,
		 onchange = function(i, value)
			 saveOptionValue('Passive builders', 'passivebuilders', 'setPassiveLabs', {'passiveLabs'}, value)
		 end,
		},

		{id="autocloakpopups", group="game", basic=true, widget="Auto Cloak Popups", name="Auto cloak popups", type="bool", value=GetWidgetToggleValue("Auto Cloak Popups"), description='Auto cloaks Pit Bull and Ambusher'},

		{id="unitreclaimer", group="game", basic=true, widget="Unit Reclaimer", name="Unit Reclaimer", type="bool", value=GetWidgetToggleValue("Unit Reclaimer"), description='Reclaim units in an area. Hover over a unit and drag an area-reclaim circle'},

		{id="autogroup_immediate", group="game", basic=true, name="Autogroup immediate mode", type="bool", value=(WG['autogroup']~=nil and WG['autogroup'].getImmediate~=nil and WG['autogroup'].getImmediate()), description='Units built/resurrected/received are added to autogroups immediately,\ninstead when they get to be idle.\n\n(add units to autogroup with ALT+number)',
		 onload = function() loadWidgetData("Auto Group", "autogroup_immediate", {'config','immediate','value'}) end,
		 onchange = function(i, value)
			 if widgetHandler.configData["Auto Group"] == nil then
				 widgetHandler.configData["Auto Group"] = {}
			 end
			 if widgetHandler.configData["Auto Group"].config == nil then
				 widgetHandler.configData["Auto Group"].config = {immediate={value=value}}
			 else
				 widgetHandler.configData["Auto Group"].config.immediate.value = value
			 end
			 saveOptionValue('Auto Group', 'autogroup', 'setImmediate', {'config','immediate','value'}, value)
		 end,
		},

		{id="factoryguard", group="game", basic=true, widget="FactoryGuard", name="Factory guard (builders)", type="bool", value=GetWidgetToggleValue("FactoryGuard"), description='Newly created builders will assist their source factory'},
		{id="factoryholdpos", group="game", basic=true, widget="Factory hold position", name="Factory hold position", type="bool", value=GetWidgetToggleValue("Factory hold position"), description='Sets factories and units they produce, to hold position automatically (not aircraft)'},
		{id="factoryrepeat", group="game", basic=true, widget="Factory Auto-Repeat", name="Factory auto-repeat", type="bool", value=GetWidgetToggleValue("Factory Auto-Repeat"), description='Sets new factories on Repeat mode'},

		{id="transportai", group="game", basic=true, widget="Transport AI", name="Transport AI", type="bool", value=GetWidgetToggleValue("Transport AI"), description='Transport units automatically pick up new units going to factory waypoint.'},
		{id="settargetdefault", group="game", basic=true, widget="Set target default", name="Set-target as default", type="bool", value=GetWidgetToggleValue("Set target default"), description='Replace default attack command to a set-target command\n(when rightclicked on enemy unit)'},
		{id="dgunnogroundenemies", group="game", widget="DGun no ground enemies", name="Dont snap DGun to ground units", type="bool", value=GetWidgetToggleValue("DGun no ground enemies"), description='Prevents dgun aim to snap onto enemy ground units.\nholding SHIFT will still target units\n\nWill still snap to air, ships and hovers (when on water)'},

		{id="profiler", group="dev", widget="Widget Profiler", name="Widget profiler", type="bool", value=GetWidgetToggleValue("Widget Profiler"), description=""},

		-- DEV
		{id="tonemapA", group="dev", name="Unit tonemapping var 1", type="slider", min=0, max=20, step=0.01, value=Spring.GetConfigFloat("tonemapA", 0.0), description="",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("tonemapA", value)
			 Spring.SendCommands("luarules updatesun")
			 Spring.SendCommands("luarules GlassUpdateSun")
		 end,
		},
		{id="tonemapB", group="dev", name=widgetOptionColor.."   var 2", type="slider", min=0, max=5, step=0.01, value=Spring.GetConfigFloat("tonemapB", 1.0), description="",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("tonemapB", value)
			 Spring.SendCommands("luarules updatesun")
			 Spring.SendCommands("luarules GlassUpdateSun")
		 end,
		},
		{id="tonemapC", group="dev", name=widgetOptionColor.."   var 3", type="slider", min=0, max=20, step=0.01, value=Spring.GetConfigFloat("tonemapC", 0.0), description="",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("tonemapC", value)
			 Spring.SendCommands("luarules updatesun")
			 Spring.SendCommands("luarules GlassUpdateSun")
		 end,
		},
		{id="tonemapD", group="dev", name=widgetOptionColor.."   var 4", type="slider", min=0, max=5, step=0.01, value=Spring.GetConfigFloat("tonemapD", 0.0), description="",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("tonemapD", value)
			 Spring.SendCommands("luarules updatesun")
			 Spring.SendCommands("luarules GlassUpdateSun")
		 end,
		},
		{id="tonemapE", group="dev", name=widgetOptionColor.."   var 5", type="slider", min=0, max=5, step=0.01, value=Spring.GetConfigFloat("tonemapE", 1.0), description="",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("tonemapE", value)
			 Spring.SendCommands("luarules updatesun")
			 Spring.SendCommands("luarules GlassUpdateSun")
		 end,
		},
		{id="envAmbient", group="dev", name="Unit env ambient %", type="slider", min=0, max=1, step=0.01, value=Spring.GetConfigFloat("envAmbient", 0.5), description="",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("envAmbient", value)
			 Spring.SendCommands("luarules updatesun")
			 Spring.SendCommands("luarules GlassUpdateSun")
		end,
		},
		{id="unitSunMult", group="dev", name="Units sun mult", type="slider", min=0, max=4, step=0.1, value=Spring.GetConfigFloat("unitSunMult", 1.5), description="",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("unitSunMult", value)
			 Spring.SendCommands("luarules updatesun")
			 Spring.SendCommands("luarules GlassUpdateSun")
		end,
		},
		{id="unitExposureMult", group="dev", name="Units exposure mult", type="slider", min=0, max=4, step=0.1, value=Spring.GetConfigFloat("unitExposureMult", 1.0), description="",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("unitExposureMult", value)
			 Spring.SendCommands("luarules updatesun")
			 Spring.SendCommands("luarules GlassUpdateSun")
		end,
		},
		{id="tonemapDefaults", group="dev", name=widgetOptionColor.."   restore defaults", type="bool", value=GetWidgetToggleValue("Unit Reclaimer"), description="",
		 onchange=function(i, value)
			 Spring.SetConfigFloat("tonemapA", 0.0)
			 Spring.SetConfigFloat("tonemapB", 1.0)
			 Spring.SetConfigFloat("tonemapC", 0.0)
			 Spring.SetConfigFloat("tonemapD", 0.0)
			 Spring.SetConfigFloat("tonemapE", 1.0)
			 Spring.SetConfigFloat("envAmbient", 0.5)
			 Spring.SetConfigFloat("unitSunMult", 1.5)
			 Spring.SetConfigFloat("unitExposureMult", 1.0)
			 options[getOptionByID('tonemapA')].value = Spring.GetConfigFloat("tonemapA")
			 options[getOptionByID('tonemapB')].value = Spring.GetConfigFloat("tonemapB")
			 options[getOptionByID('tonemapC')].value = Spring.GetConfigFloat("tonemapC")
			 options[getOptionByID('tonemapD')].value = Spring.GetConfigFloat("tonemapD")
			 options[getOptionByID('tonemapE')].value = Spring.GetConfigFloat("tonemapE")
			 options[getOptionByID('envAmbient')].value = Spring.GetConfigFloat("envAmbient")
			 options[getOptionByID('unitSunMult')].value = Spring.GetConfigFloat("unitSunMult")
			 options[getOptionByID('unitExposureMult')].value = Spring.GetConfigFloat("unitExposureMult")
			 Spring.SendCommands("luarules updatesun")
			 Spring.SendCommands("luarules GlassUpdateSun")
			 options[getOptionByID('tonemapDefaults')].value = false
		 end,
		},

	}

	-- dynamic sun settings applied by gadget: disable user controls
	if Spring.GetModOptions and (tonumber(Spring.GetModOptions().night) or 0) ~= 0 then
		options[getOptionByID('shadows_opacity')] = nil
		options[getOptionByID('sun_y')] = nil
		options[getOptionByID('sun_x')] = nil
		options[getOptionByID('sun_z')] = nil
		options[getOptionByID('sun_reset')] = nil
	end


	if not (Spring.GetModOptions and (tonumber(Spring.GetModOptions().scavengers) or 0) ~= 0) then
		options[getOptionByID('scav_voicenotifs')] = nil
		options[getOptionByID('scav_messages')] = nil
	end

	-- set lowest quality shadows for Intel GPU (they eat fps but dont show)
	--if Platform ~= nil and Platform.gpuVendor == 'Intel' then
	--	options[getOptionByID('shadowslider')] = nil
	--	options[getOptionByID('shadows_opacity')] = nil
	--end

	-- add fonts
	if getOptionByID('font') then
		local fonts = {}
		local fontsFull = {}
		local fontsn = {}
		local files = VFS.DirList(LUAUI_DIRNAME..'fonts', '*')
		fontOption = {}
		for k, file in ipairs(files) do
			local name = string.sub(file, 13)
			local ext = string.sub(name, string.len(name) - 2)
			if ext == 'otf' or ext == 'ttf' then
				name = string.sub(name, 1, string.len(name) - 4)
				if not fontsn[name:lower()] then
					fonts[#fonts+1] = name
					fontsFull[#fontsFull+1] = string.sub(file, 13)
					fontsn[name:lower()] = true
					local fontScale = (0.5 + (vsx*vsy / 5700000))
					fontOption[#fonts] = gl.LoadFont(LUAUI_DIRNAME .. "fonts/"..fontsFull[#fontsFull], 20*fontScale, 5*fontScale, 1.5)
				end
			end
		end

		options[getOptionByID('font')].options = fonts
		options[getOptionByID('font')].optionsFont = fontsFull
		local fname = Spring.GetConfigString("bar_font", "Poppins-Regular.otf"):lower()
		options[getOptionByID('font')].value = getSelectKey(getOptionByID('font'), string.sub(fname, 1, string.len(fname) - 4))

		options[getOptionByID('font2')].options = fonts
		options[getOptionByID('font2')].optionsFont = fontsFull
		local fname = Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf"):lower()
		options[getOptionByID('font2')].value = getSelectKey(getOptionByID('font2'), string.sub(fname, 1, string.len(fname) - 4))
	end

	-- set sun minimal height
	if getOptionByID('sun_y') then
		if select(2,gl.GetSun("pos")) < options[getOptionByID('sun_y')].min then
			Spring.SetSunDirection(select(1,gl.GetSun("pos")), options[getOptionByID('sun_y')].min, select(3,gl.GetSun("pos")))
		end
	end

	-- set minimal shadow opacity
	if getOptionByID('shadows_opacity') then
		if gl.GetSun("shadowDensity") < options[getOptionByID('shadows_opacity')].min then
			Spring.SetSunLighting({groundShadowDensity = options[getOptionByID('shadows_opacity')].min, modelShadowDensity = options[getOptionByID('shadows_opacity')].min})
		end
	end

	-- fsaa is deprecated in 104.x
	if tonumber(Spring.GetConfigInt("FSAALevel",0)) > 0 then
		local fsaa = tonumber(Spring.GetConfigInt("FSAALevel",0))
		if fsaa > 8 then
			fsaa = 8
		end
		Spring.SetConfigInt("MSAALevel", fsaa)
		Spring.SetConfigInt("FSAALevel", 0)
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
		changesRequireRestart = false
	end

	-- detect AI
	local aiDetected = false
	local t = Spring.GetTeamList()
	for _,teamID in ipairs(t) do
		if select(4,Spring.GetTeamInfo(teamID,false)) then
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
			soundList = WG['voicenotifs'].getSoundList()
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
						newOptions[count] = {id="voicenotifs_snd_"..sound, group="snd", name=widgetOptionColor.."   "..sound, type="bool", value=enabled, description='',
							onchange = function(i, value) saveOptionValue('Voice Notifs', 'voicenotifs', 'setSound'..sound, {'soundList'}, value) end,
						}
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
		options[getOptionByID('cursorsize')] = nil
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
		if getOptionByID('cursor') then
			options[getOptionByID('cursor')].options = cursorsets
			options[getOptionByID('cursor')].value = cursor
		end
		if WG['cursors'].getsizemult then
			options[getOptionByID('cursorsize')].value = WG['cursors'].getsizemult()
		else
			options[getOptionByID('cursorsize')] = nil
		end
	end
	if widgetHandler.knownWidgets["SSAO"] == nil then
		options[getOptionByID('ssao')] = nil
		options[getOptionByID('ssao_strength')] = nil
		options[getOptionByID('ssao_radius')] = nil
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

	if not widgetHandler.knownWidgets["Commander Name Tags"] then
		options[getOptionByID('nametags_icon')] = nil
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
	if WG['red_buildmenu'] == nil or WG['red_buildmenu'].getConfigLargeUnitIcons == nil then
		options[getOptionByID('buildmenulargeicons')] = nil
	end

	if WG['playercolorpalette'] == nil or WG['playercolorpalette'].getSameTeamColors == nil then
		options[getOptionByID('sameteamcolors')] = nil
	end

	if WG['advplayerlist_api']==nil or WG['advplayerlist_api'].GetLockTransitionTime==nil then
		options[getOptionByID('lockcamera_transitiontime')] = nil
	end

	-- disable options when widget isnt availible
	if widgetHandler.knownWidgets["Outline"] == nil then
		options[getOptionByID('outline')] = nil
		options[getOptionByID("outline_width")] = nil
		options[getOptionByID("outline_mult")] = nil
		options[getOptionByID("outline_color")] = nil
	end

	if widgetHandler.knownWidgets["Contrast Adaptive Sharpen"] == nil then
		options[getOptionByID("cas_sharpness")] = nil
	end

	if widgetHandler.knownWidgets["Fancy Selected Units"] == nil then
		options[getOptionByID('fancyselectedunits')] = nil
		options[getOptionByID("fancyselectedunits_opacity")] = nil
		options[getOptionByID("fancyselectedunits_baseopacity")] = nil
		options[getOptionByID("fancyselectedunits_teamcoloropacity")] = nil
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

	if widgetHandler.knownWidgets["Light Effects"] == nil or widgetHandler.knownWidgets["Deferred rendering"] == nil then
		options[getOptionByID('lighteffects')] = nil
		options[getOptionByID("lighteffects_brightness")] = nil
		options[getOptionByID("lighteffects_laserbrightness")] = nil
		options[getOptionByID("lighteffects_radius")] = nil
		options[getOptionByID("lighteffects_laserradius")] = nil
		options[getOptionByID("lighteffects_nanolaser")] = nil
		options[getOptionByID("lighteffects_thrusters")] = nil
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
		if option.type == 'slider' and not option.steps then
		if option.value < option.min then option.value = option.min end
		if option.value > option.max then option.value = option.max end
		end
		if option.widget ~= nil and widgetHandler.knownWidgets[option.widget] == nil then
			insert = false
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

function checkResolution()
	-- resize resolution if is larger than screen resolution
	wsx,wsy,wpx,wpy = Spring.GetWindowGeometry()
	ssx,ssy,spx,spy = Spring.GetScreenGeometry()
	if wsx > ssx or wsy > ssy then
		if tonumber(Spring.GetConfigInt("Fullscreen",1) or 1) == 1 then
			Spring.SendCommands("Fullscreen 0")
		else
			Spring.SendCommands("Fullscreen 1")
		end
		Spring.SetConfigInt("XResolution", tonumber(ssx))
		Spring.SetConfigInt("YResolution", tonumber(ssy))
		Spring.SetConfigInt("XResolutionWindowed", tonumber(ssx))
		Spring.SetConfigInt("YResolutionWindowed", tonumber(ssy))
		if tonumber(Spring.GetConfigInt("Fullscreen",1) or 1) == 1 then
			Spring.SendCommands("Fullscreen 0")
		else
			Spring.SendCommands("Fullscreen 1")
		end
	end
end

function widget:Initialize()

	Spring.SetConfigFloat("CamTimeFactor", 1)

	if Spring.GetGameFrame() == 0 then
	-- set minimum particle amount
	if tonumber(Spring.GetConfigInt("MaxParticles",1) or 10000) <= 10000 then
		Spring.SetConfigInt("MaxParticles",10000)
	end

	-- enable lua shaders
	if not tonumber(Spring.GetConfigInt("ForceShaders",1) or 0) and not tonumber(Spring.GetConfigInt("ShaderVersionErrorDetected",1) or 0) then
		Spring.SetConfigInt("ForceShaders", 1)
	end

	-- enable map/model shading
	if Spring.GetConfigInt("AdvMapShading",0) ~= 1 then
		Spring.SetConfigInt("AdvMapShading",1)
	end
	if Spring.GetConfigInt("AdvModelShading",0) ~= 1 then
		Spring.SetConfigInt("AdvModelShading",1)
	end
	-- enable normal mapping
	if Spring.GetConfigInt("NormalMapping",0) ~= 1 then
		Spring.SetConfigInt("NormalMapping",1)
		Spring.SendCommands("luarules normalmapping 1")
	end
	-- disable clouds
	if Spring.GetConfigInt("AdvSky",0) ~= 0 then
		Spring.SetConfigInt("AdvSky",0)
	end
	-- disable grass
	if Spring.GetConfigInt("GrassDetail",0) ~= 0 then
		Spring.SetConfigInt("GrassDetail",0)
	end
	-- limit MSAA
	if Spring.GetConfigInt("MSAALevel",0) > 8 then
		Spring.SetConfigInt("MSAALevel",8)
	end

	--if Platform ~= nil and Platform.gpuVendor ~= 'Nvidia' then	-- because UsePBO displays tiled map texture bug for ATI/AMD cards
	--Spring.SetConfigInt("UsePBO",0)
	--end

	-- Setting basic map mesh rendering cause of performance tanking bug: https://springrts.com/mantis/view.php?id=6340
	-- /mapmeshdrawer    (unsynced)  Switch map-mesh rendering modes: 0=GCM, 1=HLOD, 2=ROAM
	Spring.SendCommands("mapmeshdrawer 1")

	-- enable shadows at gamestart
	if Spring.GetConfigInt("Shadows",0) ~= 1 then
		Spring.SetConfigInt("Shadows",1)
		Spring.SendCommands("Shadows 1")
	end
	-- set lowest quality shadows for Intel GPU (they eat fps but dont really show, but without any shadows enables it looks glitchy)
	if Platform ~= nil and Platform.gpuVendor == 'Intel' then
		Spring.SendCommands("Shadows 1 1000")
	end

	-- set custom user map sun position
	if customMapSunPos[Game.mapName] and customMapSunPos[Game.mapName][1] then
		Spring.SetSunDirection(customMapSunPos[Game.mapName][1],customMapSunPos[Game.mapName][2],customMapSunPos[Game.mapName][3])
		Spring.SetSunLighting({groundShadowDensity = gl.GetSun("shadowDensity"), modelShadowDensity = gl.GetSun("shadowDensity")})
	end

	-- disable fog
	Spring.SetAtmosphere({fogStart = 0.99999, fogEnd = 1.0, fogColor = {1.0, 1.0, 1.0, 0.0}})
	end

	Spring.SendCommands("minimap unitsize "..(Spring.GetConfigFloat("MinimapIconScale", 3.5)))		-- spring wont remember what you set with '/minimap iconssize #'

	Spring.SendCommands({"bind f10 options"})

	checkResolution()

	WG['options'] = {}
	WG['options'].toggle = function(state)
		if state ~= nil then
			show = state
		else
			show = not show
		end
	end
	WG['options'].isvisible = function() return show end
	WG['options'].getCameraSmoothness = function() return cameraTransitionTime end
	WG['options'].disallowEsc = function()
		if showSelectOptions then --or draggingSlider then
			return true
		else
			return false
		end
	end

	presets = tableMerge(presets, customPresets)
	for preset,_ in pairs(customPresets) do
		table.insert(presetNames, preset)
	end

	init()
end

function widget:Shutdown()
	if windowList then
		glDeleteList(windowList)
	end
	if fontOption then
		for i, font in pairs(fontOption) do
			gl.DeleteFont(fontOption[i])
		end
	end
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('options')
	end
	if selectOptionsList then
		if WG['guishader'] then
			WG['guishader'].RemoveScreenRect('options_select')
			WG['guishader'].removeRenderDlist(selectOptionsList)
		end
		glDeleteList(selectOptionsList)
		selectOptionsList = nil
	end
	gl.DeleteFont(font)
	gl.DeleteFont(font2)
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
	savedTable.cameraPanTransitionTime = cameraPanTransitionTime
	savedTable.maxNanoParticles = maxNanoParticles
	savedTable.currentGroupTab = currentGroupTab
	savedTable.show = show
	savedTable.advSettings = advSettings
	savedTable.defaultMapSunPos = defaultMapSunPos
	savedTable.mapName = Game.mapName
	savedTable.customMapSunPos = customMapSunPos
	savedTable.savedConfig = {
		vsync = {'VSync', tonumber(Spring.GetConfigInt("VSync",1) or 1)},
		water = {'Water', tonumber(Spring.GetConfigInt("Water",1) or 1)},
		disticon = {'UnitIconDist', tonumber(Spring.GetConfigInt("UnitIconDist",1) or 400)},
		particles = {'MaxParticles', tonumber(Spring.GetConfigInt("MaxParticles",1) or 15000)},
		--nanoparticles = {'MaxNanoParticles', tonumber(Spring.GetConfigInt("MaxNanoParticles",1) or 500)},	-- already saved above in: maxNanoParticles
		decals = {'GroundDecals', tonumber(Spring.GetConfigInt("GroundDecals",1) or 1)},
		grounddetail = {'GroundDetail', tonumber(Spring.GetConfigInt("GroundDetail",1) or 1)},
		camera = {'CamMode', tonumber(Spring.GetConfigInt("CamMode",1) or 1)},
		--treewind = {'TreeWind', tonumber(Spring.GetConfigInt("TreeWind",1) or 1)},
		hwcursor = {'HardwareCursor', tonumber(Spring.GetConfigInt("HardwareCursor",1) or 1)},
		sndvolmaster = {'snd_volmaster', tonumber(Spring.GetConfigInt("snd_volmaster",40) or 40)},
		sndvolbattle = {'snd_volbattle', tonumber(Spring.GetConfigInt("snd_volbattle",40) or 40)},
		sndvolunitreply = {'snd_volunitreply', tonumber(Spring.GetConfigInt("snd_volunitreply",40) or 40)},
		--sndvolmusic = {'snd_volmusic', tonumber(Spring.GetConfigInt("snd_volmusic",20) or 20)},
		guiopacity = {'ui_opacity', tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)},
		scrollwheelspeed = {'ScrollWheelSpeed', tonumber(Spring.GetConfigInt("ScrollWheelSpeed",25) or 25)},
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
	if data.cameraPanTransitionTime ~= nil then
		cameraPanTransitionTime = data.cameraPanTransitionTime
	end
	if data.maxNanoParticles ~= nil then
		maxNanoParticles = data.maxNanoParticles
	end
	if data.currentGroupTab ~= nil then
		currentGroupTab = data.currentGroupTab
	end
	if data.show ~= nil and Spring.GetGameFrame() > 0 then
		show = data.show
	end
	if data.advSettings ~= nil then
		advSettings = data.advSettings
	end
	if data.savedConfig ~= nil then
		savedConfig = data.savedConfig
		for k, v in pairs(savedConfig) do
			Spring.SetConfigFloat(v[1],v[2])
		end
	end
	if data.defaultMapSunPos ~= nil and data.mapName == Game.mapName then
		defaultMapSunPos = data.defaultMapSunPos
	end
	if data.customMapSunPos then
		customMapSunPos = data.customMapSunPos
	end
end
