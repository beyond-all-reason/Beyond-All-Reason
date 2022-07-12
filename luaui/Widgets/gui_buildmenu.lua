function widget:GetInfo()
	return {
		name = "Build menu",
		desc = "",
		author = "Floris",
		date = "April 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
		handler = true,
	}
end

include("keysym.h.lua")

SYMKEYS = table.invert(KEYSYMS)

local comBuildOptions
local boundUnits = {}
local stickToBottom = false

local alwaysShow = false

local cfgCellPadding = 0.007
local cfgIconPadding = 0.015 -- space between icons
local cfgIconCornerSize = 0.025
local cfgPriceFontSize = 0.19
local cfgActiveAreaMargin = 0.1 -- (# * bgpadding) space between the background border and active area

local defaultColls = 5
local dynamicIconsize = true
local minColls = 4
local maxColls = 5

local showOrderDebug = false
local smartOrderUnits = true

local maxPosY = 0.74

local disableInputWhenSpec = false		-- disable specs selecting buildoptions

local showPrice = false		-- false will still show hover
local showRadarIcon = true		-- false will still show hover
local showGroupIcon = true		-- false will still show hover
local showBuildProgress = true

local zoomMult = 1.5
local defaultCellZoom = 0.025 * zoomMult
local rightclickCellZoom = 0.033 * zoomMult
local clickCellZoom = 0.07 * zoomMult
local hoverCellZoom = 0.05 * zoomMult
local clickSelectedCellZoom = 0.125 * zoomMult
local selectedCellZoom = 0.135 * zoomMult

local bgpadding, chobbyInterface, activeAreaMargin, iconTypesMap
local dlistGuishader, dlistBuildmenuBg, dlistBuildmenu, font2, cmdsCount
local doUpdateClock, ordermenuHeight, advplayerlistPos, prevAdvplayerlistLeft
local cellPadding, iconPadding, cornerSize, cellInnerSize, cellSize, priceFontSize
local activeCmd, selBuildQueueDefID
local prevHoveredCellID, hoverDlist

local math_isInRect = math.isInRect

local facingMap = {south=0, east=1, north=2, west=3}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local unbaStartBuildoptions = {}
if Spring.GetModOptions().unba then
	VFS.Include("unbaconfigs/buildoptions.lua")
	for unitname,level in pairs(ArmBuildOptions) do
		if level == 1 then
			unbaStartBuildoptions[UnitDefNames[unitname].id] = unitname
		end
	end
	ArmBuildOptions = nil
	for unitname,level in pairs(CorBuildOptions) do
		if level == 1 then
			unbaStartBuildoptions[UnitDefNames[unitname].id] = unitname
		end
	end
	CorBuildOptions = nil
	ArmDefsBuildOptions = nil
	CorDefsBuildOptions = nil
	ArmBuildOptionsStop = nil
	CorBuildOptionsStop = nil
else
	unbaStartBuildoptions = nil
end

local playSounds = true
local sound_queue_add = 'LuaUI/Sounds/buildbar_add.wav'
local sound_queue_rem = 'LuaUI/Sounds/buildbar_rem.wav'

local fontFile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local vsx, vsy = Spring.GetViewGeometry()

local ordermenuLeft = vsx / 5
local advplayerlistLeft = vsx * 0.8

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity", 0.6) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)
local glossMult = 1 + (2 - (ui_opacity * 2))    -- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local isSpec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local startDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')

local buildQueue = {}
local disableInput = disableInputWhenSpec and isSpec
local backgroundRect = { 0, 0, 0, 0 }
local colls = 5
local rows = 5
local minimapHeight = 0.235
local posY = 0
local posY2 = 0
local posX = 0
local posX2 = 0.2
local width = 0
local height = 0
local selectedBuilders = {}
local selectedBuilderCount = 0
local selectedFactories = {}
local selectedFactoryCount = 0
local cellRects = {}
local cmds = {}
local lastUpdate = os.clock() - 1
local currentPage = 1
local pages = 1
local paginatorRects = {}
local preGamestartPlayer = Spring.GetGameFrame() == 0 and not isSpec
local unitshapes = {}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local spIsUnitSelected = Spring.IsUnitSelected
local spGetSelectedUnitsCount = Spring.GetSelectedUnitsCount
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetActiveCommand = Spring.GetActiveCommand
local spGetActiveCmdDescs = Spring.GetActiveCmdDescs
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spGetUnitDefID = Spring.GetUnitDefID
local spGetTeamRulesParam = Spring.GetTeamRulesParam
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding

local SelectedUnitsCount = spGetSelectedUnitsCount()

local string_sub = string.sub
local os_clock = os.clock

local math_floor = math.floor
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min

local glTexture = gl.Texture
local glColor = gl.Color
local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE
local GL_DST_ALPHA = GL.DST_ALPHA
local GL_ONE_MINUS_SRC_COLOR = GL.ONE_MINUS_SRC_COLOR

local RectRound, RectRoundProgress, UiUnit, UiElement, UiButton, elementCorner

-- used for pregame build queue, for switch faction buildings
local armToCor = {
	[UnitDefNames["armmex"].id] = UnitDefNames["cormex"].id,
	[UnitDefNames["armuwmex"].id] = UnitDefNames["coruwmex"].id,
	[UnitDefNames["armsolar"].id] = UnitDefNames["corsolar"].id,
	[UnitDefNames["armwin"].id] = UnitDefNames["corwin"].id,
	[UnitDefNames["armtide"].id] = UnitDefNames["cortide"].id,
	[UnitDefNames["armllt"].id] = UnitDefNames["corllt"].id,
	[UnitDefNames["armrad"].id] = UnitDefNames["corrad"].id,
	[UnitDefNames["armrl"].id] = UnitDefNames["corrl"].id,
	[UnitDefNames["armtl"].id] = UnitDefNames["cortl"].id,
	[UnitDefNames["armsonar"].id] = UnitDefNames["corsonar"].id,
	[UnitDefNames["armfrt"].id] = UnitDefNames["corfrt"].id,
	[UnitDefNames["armlab"].id] = UnitDefNames["corlab"].id,
	[UnitDefNames["armvp"].id] = UnitDefNames["corvp"].id,
	[UnitDefNames["armsy"].id] = UnitDefNames["corsy"].id,
	[UnitDefNames["armmstor"].id] = UnitDefNames["cormstor"].id,
	[UnitDefNames["armestor"].id] = UnitDefNames["corestor"].id,
	[UnitDefNames["armmakr"].id] = UnitDefNames["cormakr"].id,
	[UnitDefNames["armeyes"].id] = UnitDefNames["coreyes"].id,
	[UnitDefNames["armdrag"].id] = UnitDefNames["cordrag"].id,
	[UnitDefNames["armdl"].id] = UnitDefNames["cordl"].id,
	[UnitDefNames["armap"].id] = UnitDefNames["corap"].id,
	[UnitDefNames["armfrad"].id] = UnitDefNames["corfrad"].id,
	[UnitDefNames["armuwms"].id] = UnitDefNames["coruwms"].id,
	[UnitDefNames["armuwes"].id] = UnitDefNames["coruwes"].id,
	[UnitDefNames["armfmkr"].id] = UnitDefNames["corfmkr"].id,
	[UnitDefNames["armfdrag"].id] = UnitDefNames["corfdrag"].id,
	[UnitDefNames["armptl"].id] = UnitDefNames["corptl"].id,
}
local corToArm = table.invert(armToCor)

local function convertColor(r, g, b)
	return string.char(255, (r * 255), (g * 255), (b * 255))
end

local folder = 'LuaUI/Images/groupicons/'
local groups = {
	energy = folder..'energy.png',
	metal = folder..'metal.png',
	builder = folder..'builder.png',
	buildert2 = folder..'buildert2.png',
	buildert3 = folder..'buildert3.png',
	buildert4 = folder..'buildert4.png',
	util = folder..'util.png',
	weapon = folder..'weapon.png',
	explo = folder..'weaponexplo.png',
	weaponaa = folder..'weaponaa.png',
	aa = folder..'aa.png',
	emp = folder..'emp.png',
	sub = folder..'sub.png',
	nuke = folder..'nuke.png',
	antinuke = folder..'antinuke.png',
}

local disableWind = ((Game.windMin + Game.windMax) / 2) <= 5

local unitEnergyCost = {}
local unitMetalCost = {}
local unitGroup = {}
local unitRestricted = {}
local unitDisabled = {}
local isBuilder = {}
local isFactory = {}
local unitIconType = {}
local isMex = {}
local isWaterUnit = {}
local isGeothermalUnit = {}
local unitMaxWeaponRange = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	unitIconType[unitDefID] = unitDef.iconType
	unitEnergyCost[unitDefID] = unitDef.energyCost
	unitMetalCost[unitDefID] = unitDef.metalCost
	unitGroup[unitDefID] = unitDef.customParams.unitgroup

	if unitDef.name == 'armdl' or unitDef.name == 'cordl' or unitDef.name == 'armlance' or unitDef.name == 'cortitan'
		or (unitDef.minWaterDepth > 0 or unitDef.modCategories['ship']) then
		if not (unitDef.modCategories['hover'] or (unitDef.modCategories['mobile'] and unitDef.modCategories['canbeuw'])) then
			isWaterUnit[unitDefID] = true
		end
	end
	if unitDef.maxWeaponRange > 16 then
		unitMaxWeaponRange[unitDefID] = unitDef.maxWeaponRange
	end
	if unitDef.maxThisUnit == 0 then --or unitDef.name == 'armllt' or unitDef.name == 'armmakr' then
		unitRestricted[unitDefID] = true
	end
	if unitDef.buildSpeed > 0 and unitDef.buildOptions[1] then
		isBuilder[unitDefID] = unitDef.buildOptions
	end
	if unitDef.isFactory and #unitDef.buildOptions > 0 then
		isFactory[unitDefID] = true
	end
	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = true
	end
	if unitDef.needGeo then
		isGeothermalUnit[unitDefID] = true
	end
	if unitDef.windGenerator > 0 and disableWind then
		unitDisabled[unitDefID] = true
	end
end

local unitOrder = {}
local unitOrderManualOverrideTable = VFS.Include("luaui/configs/buildmenu_sorting.lua")

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitOrderManualOverrideTable[unitDefID] then
		unitOrder[unitDefID] = -unitOrderManualOverrideTable[unitDefID]
	else
		unitOrder[unitDefID] = 9999999
	end
end

local function getHighestOrderedUnit()
	local highest = { 0, 0, false }
	local firstOrderTest = true
	local newSortingUnit = {}
	for unitDefID, orderValue in pairs(unitOrder) do

		if unitOrderManualOverrideTable[unitDefID] then
			newSortingUnit[unitDefID] = true
		else
			newSortingUnit[unitDefID] = false
		end

		if firstOrderTest == true then
			firstOrderTest = false
			highest = { unitDefID, orderValue, newSortingUnit[unitDefID]}
		--elseif orderValue > highest[2] then
		elseif highest[3] == false and newSortingUnit[unitDefID] == true then
			highest = { unitDefID, orderValue, newSortingUnit[unitDefID]}
		elseif highest[3] == false and newSortingUnit[unitDefID] == false then
			if orderValue > highest[2] then
				highest = { unitDefID, orderValue, newSortingUnit[unitDefID]}
			end
		elseif highest[3] == true and newSortingUnit[unitDefID] == true then
			if orderValue > highest[2] then
				highest = { unitDefID, orderValue, newSortingUnit[unitDefID]}
			end
		end
	end
	return highest[1]
end

local unitsOrdered = {}
local unitOrderDebug = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local uDefID = getHighestOrderedUnit()
	unitsOrdered[#unitsOrdered + 1] = uDefID
	unitOrderDebug[uDefID] = unitOrder[uDefID]
	unitOrder[uDefID] = nil
end

if not showOrderDebug then
	unitOrderDebug = nil
end
unitOrder = unitsOrdered
unitsOrdered = nil

local voidWater = false
local success, mapinfo = pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs
if success and mapinfo then
	voidWater = mapinfo.voidwater
end

local minWaterUnitDepth = -11
local showWaterUnits = false
local _, _, mapMinWater, _ = Spring.GetGroundExtremes()
if not voidWater and mapMinWater <= minWaterUnitDepth then
	showWaterUnits = true
end
-- make them a disabled unit (instead of removing it entirely)
if not showWaterUnits then
	for unitDefID,_ in pairs(isWaterUnit) do
		unitDisabled[unitDefID] = true
	end
end

local showGeothermalUnits = false
local function checkGeothermalFeatures()
	showGeothermalUnits = false
	local geoThermalFeatures = {}
	for defID, def in pairs(FeatureDefs) do
		if def.geoThermal then
			geoThermalFeatures[defID] = true
		end
	end
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		if geoThermalFeatures[Spring.GetFeatureDefID(features[i])] then
			showGeothermalUnits = true
			break
		end
	end
	-- make them a disabled unit (instead of removing it entirely)
	for unitDefID,_ in pairs(isGeothermalUnit) do
		if not showGeothermalUnits then
			unitDisabled[unitDefID] = true
		else
			if not isWaterUnit[unitDefID] or showWaterUnits then
				unitDisabled[unitDefID] = nil
			end
		end
	end
end

local function checkGuishader(force)
	if WG['guishader'] then
		if force and dlistGuishader then
			dlistGuishader = gl.DeleteList(dlistGuishader)
		end
		if not dlistGuishader then
			dlistGuishader = gl.CreateList(function()
				RectRound(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], elementCorner)
			end)
			if selectedBuilderCount > 0 then
				WG['guishader'].InsertDlist(dlistGuishader, 'buildmenu')
			end
		end
	elseif dlistGuishader then
		dlistGuishader = gl.DeleteList(dlistGuishader)
	end
end

function widget:PlayerChanged(playerID)
	isSpec = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	myPlayerID = Spring.GetMyPlayerID()
end


local function RefreshCommands()
	cmds = {}
	cmdsCount = 0

	if preGamestartPlayer then
		if startDefID then

			local cmdUnitdefs = {}
			for i, udefid in pairs(UnitDefs[startDefID].buildOptions) do
				if not unbaStartBuildoptions or unbaStartBuildoptions[udefid] then
					cmdUnitdefs[udefid] = i
				end
			end
			for k, uDefID in pairs(unitOrder) do
				if cmdUnitdefs[uDefID] then
					cmdsCount = cmdsCount + 1
					-- mimmick output of spGetActiveCmdDescs
					cmds[cmdsCount] = {
						id = uDefID * -1,
						name = UnitDefs[uDefID].name,
						params = {}
					}
				end
			end
		end
	else

		local activeCmdDescs = spGetActiveCmdDescs()
		if smartOrderUnits then
			local cmdUnitdefs = {}
			for index, cmd in pairs(activeCmdDescs) do
				if type(cmd) == "table" then
					if not cmd.disabled and string_sub(cmd.action, 1, 10) == 'buildunit_' then
						cmdUnitdefs[cmd.id * -1] = index
					end
				end
			end
			for k, uDefID in pairs(unitOrder) do
				if cmdUnitdefs[uDefID] then
					cmdsCount = cmdsCount + 1
					cmds[cmdsCount] = activeCmdDescs[cmdUnitdefs[uDefID]]
				end
			end
		else
			for index, cmd in pairs(activeCmdDescs) do
				if type(cmd) == "table" then
					if not cmd.disabled and string_sub(cmd.action, 1, 10) == 'buildunit_' then
						cmdsCount = cmdsCount + 1
						cmds[cmdsCount] = cmd
					end
				end
			end
		end
	end
end

local function clear()
	dlistBuildmenu = gl.DeleteList(dlistBuildmenu)
	dlistBuildmenuBg = gl.DeleteList(dlistBuildmenuBg)
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	font2 = WG['fonts'].getFont(fontFile, 1.2, 0.28, 1.6)

	if WG['minimap'] then
		minimapHeight = WG['minimap'].getHeight()
	end

	local widgetSpaceMargin = WG.FlowUI.elementMargin
	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	RectRoundProgress = WG.FlowUI.Draw.RectRoundProgress
	UiUnit = WG.FlowUI.Draw.Unit
	UiButton = WG.FlowUI.Draw.Button
	UiElement = WG.FlowUI.Draw.Element

	activeAreaMargin = math_ceil(bgpadding * cfgActiveAreaMargin)

	if stickToBottom then
		posY = math_floor(0.14 * ui_scale * vsy) / vsy
		posY2 = 0
		posX = math_floor(ordermenuLeft*vsx) + widgetSpaceMargin
		posX2 = advplayerlistLeft - widgetSpaceMargin
		width = posX2 - posX
		height = posY
		minColls = math_max(8, math_floor((width/vsx)*25))
		maxColls = 30
	else
		posY = math_min(maxPosY, math_max(0.4615, (vsy - minimapHeight) / vsy) - (widgetSpaceMargin/vsy))
		posY2 = math_floor(0.14 * ui_scale * vsy) / vsy
		posY2 = posY2 + (widgetSpaceMargin/vsy)
		posX = 0
		minColls = 4
		maxColls = 5

		if WG['minimap'] then
			posY = 1 - (WG['minimap'].getHeight() / vsy) - (widgetSpaceMargin/vsy)
			if posY > maxPosY then
				posY = maxPosY
			end

			if WG['ordermenu'] then
				local oposX, oposY, owidth, oheight = WG['ordermenu'].getPosition()
				if oposY > 0.5 then
					posY = oposY - oheight - ((widgetSpaceMargin)/vsy)
				end
			end
		end

		posY = math_floor(posY * vsy) / vsy
		posX = math_floor(posX * vsx) / vsx

		height = (posY - posY2)
		width = 0.212

		width = width / (vsx / vsy) * 1.78        -- make smaller for ultrawide screens
		width = width * ui_scale

		posX2 = math_floor(width * vsx)

		-- make pixel aligned
		width = math_floor(width * vsx) / vsx
		height = math_floor(height * vsy) / vsy
	end

	backgroundRect = { posX, (posY - height) * vsy, posX2, posY * vsy }

	checkGuishader(true)
	clear()
	doUpdate = true
end

-- Spring handles buildfacing already, this is for managing pregamestart
function buildFacingHandler(_, _, args)
	if not (preGamestartPlayer and selBuildQueueDefID) then
		return
	end

	local facing = Spring.GetBuildFacing()
	if args and args[1] == "inc" then
		facing = (facing + 1) % 4
		Spring.SetBuildFacing(facing)

		return true
	elseif args and args[1] == "dec" then
		facing = (facing - 1) % 4
		Spring.SetBuildFacing(facing)

		return true

	elseif args and facingMap[args[1]] then
		Spring.SetBuildFacing(facingMap[args[1]])

		return true
	end
end

-- update queue number
function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	if spIsUnitSelected(factID) then
		doUpdateClock = os_clock() + 0.01
	end
end

local sec = 0
local updateSelection = true
function widget:Update(dt)
	if updateSelection then
		updateSelection = false
		if SelectedUnitsCount ~= spGetSelectedUnitsCount() then
			SelectedUnitsCount = spGetSelectedUnitsCount()
		end
		selectedBuilders = {}
		selectedBuilderCount = 0
		selectedFactories = {}
		selectedFactoryCount = 0
		if SelectedUnitsCount > 0 then
			local sel = Spring.GetSelectedUnits()
			for _, unitID in pairs(sel) do
				if isFactory[spGetUnitDefID(unitID)] then
					selectedFactories[unitID] = true
					selectedFactoryCount = selectedFactoryCount + 1
				end
				if isBuilder[spGetUnitDefID(unitID)] then
					selectedBuilders[unitID] = true
					selectedBuilderCount = selectedBuilderCount + 1
					doUpdate = true
				end
			end
		end
	end

	sec = sec + dt
	if sec > 0.33 then
		sec = 0
		checkGuishader()
		if ui_scale ~= Spring.GetConfigFloat("ui_scale", 1) then
			ui_scale = Spring.GetConfigFloat("ui_scale", 1)
			widget:ViewResize()
			doUpdate = true
		end
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			glossMult = 1 + (2 - (ui_opacity * 2))
			clear()
			doUpdate = true
		end
		if WG['minimap'] and minimapHeight ~= WG['minimap'].getHeight() then
			widget:ViewResize()
			doUpdate = true
		end

		local _, _, mapMinWater, _ = Spring.GetGroundExtremes()
		if not voidWater and mapMinWater <= minWaterUnitDepth then
			if not showWaterUnits then
				showWaterUnits = true

				for unitDefID,_ in pairs(isWaterUnit) do
					if not isGeothermalUnit[unitDefID] or showGeothermalUnits then	-- make sure geothermal units keep being disabled if that should be the case
						unitDisabled[unitDefID] = nil
					end
				end
			end
		end

		if stickToBottom then
			if WG['advplayerlist_api'] ~= nil then
				local prevPos = advplayerlistPos
				local advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
				local prevAdvplayerlistLeft = advplayerlistLeft
				advplayerlistLeft = advplayerlistPos[2]
			end
		end
		local prevOrdermenuLeft = ordermenuLeft
		local prevOrdermenuHeight = ordermenuHeight
		if WG['ordermenu'] then
			local oposX, oposY, owidth, oheight = WG['ordermenu'].getPosition()
			ordermenuLeft = oposX + owidth
			ordermenuHeight = oheight
		end
		if not prevAdvplayerlistLeft or advplayerlistLeft ~= prevAdvplayerlistLeft or not prevOrdermenuLeft or ordermenuLeft ~= prevOrdermenuLeft  or not prevOrdermenuHeight or ordermenuHeight ~= prevOrdermenuHeight then
			widget:ViewResize()
		end

		disableInput = disableInputWhenSpec and isSpec
		if Spring.IsGodModeEnabled() then
			disableInput = false
		end
	end
end

function drawBuildmenuBg()
	WG['buildmenu'].selectedID = nil
	UiElement(backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4], (posX > 0 and 1 or 0), 1, ((posY-height > 0 or posX <= 0) and 1 or 0), 0)
end

local function drawCell(cellRectID, usedZoom, cellColor, progress, highlightColor, edgeAlpha, disabled)
	local uDefID = cmds[cellRectID].id * -1

	-- unit icon
	if disabled then
		glColor(0.4, 0.4, 0.4, 1)
	else
		glColor(1, 1, 1, 1)
	end
	UiUnit(
		cellRects[cellRectID][1] + cellPadding + iconPadding,
		cellRects[cellRectID][2] + cellPadding + iconPadding,
		cellRects[cellRectID][3] - cellPadding - iconPadding,
		cellRects[cellRectID][4] - cellPadding - iconPadding,
		cornerSize, 1,1,1,1,
		usedZoom,
		nil, disabled and 0 or nil,
		'#' .. uDefID,
		showRadarIcon and (((unitIconType[uDefID] and iconTypesMap[unitIconType[uDefID]]) and ':l' .. (disabled and 't0.35,0.35,0.35' or '') ..':' .. iconTypesMap[unitIconType[uDefID]] or nil)) or nil,
		showGroupIcon and (groups[unitGroup[uDefID]] and ':l' .. (disabled and 'gt0.4,0.4,0.4:' or ':') ..groups[unitGroup[uDefID]] or nil) or nil,
		{unitMetalCost[uDefID], unitEnergyCost[uDefID]},
		tonumber(cmds[cellRectID].params[1])
	)

	-- colorize/highlight unit icon
	if cellColor then
		glBlending(GL_DST_ALPHA, GL_ONE_MINUS_SRC_COLOR)
		glColor(cellColor[1], cellColor[2], cellColor[3], cellColor[4])
		glTexture('#' .. uDefID)
		UiUnit(
			cellRects[cellRectID][1] + cellPadding + iconPadding,
			cellRects[cellRectID][2] + cellPadding + iconPadding,
			cellRects[cellRectID][3] - cellPadding - iconPadding,
			cellRects[cellRectID][4] - cellPadding - iconPadding,
			cornerSize, 1,1,1,1,
			usedZoom
		)
		if cellColor[4] > 0 then
			glBlending(GL_SRC_ALPHA, GL_ONE)
			UiUnit(
				cellRects[cellRectID][1] + cellPadding + iconPadding,
				cellRects[cellRectID][2] + cellPadding + iconPadding,
				cellRects[cellRectID][3] - cellPadding - iconPadding,
				cellRects[cellRectID][4] - cellPadding - iconPadding,
				cornerSize, 1,1,1,1,
				usedZoom
			)
		end
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end
	glTexture(false)

	-- price
	if showPrice then
		--doCircle(x, y, z, radius, sides)
		local text
		if disabled then
			text = "\255\125\125\125" .. unitMetalCost[uDefID] .. "\n\255\135\135\135"
		else
			text = "\255\245\245\245" .. unitMetalCost[uDefID] .. "\n\255\255\255\000"
		end
		font2:Print(text .. unitEnergyCost[uDefID], cellRects[cellRectID][1] + cellPadding + (cellInnerSize * 0.048), cellRects[cellRectID][2] + cellPadding + (priceFontSize * 1.35), priceFontSize, "o")
	end

	-- debug order value
	if showOrderDebug and smartOrderUnits and unitOrderDebug[uDefID] then
		local text = unitOrderDebug[uDefID]
		font2:Print("\255\175\175\175" .. text, cellRects[cellRectID][1] + cellPadding + (cellInnerSize * 0.05), cellRects[cellRectID][4] - cellPadding - priceFontSize, priceFontSize * 0.82, "o")
	end

	-- draw build progress pie on top of texture
	if progress and showBuildProgress then
		RectRoundProgress(cellRects[cellRectID][1] + cellPadding + iconPadding, cellRects[cellRectID][2] + cellPadding + iconPadding, cellRects[cellRectID][3] - cellPadding - iconPadding, cellRects[cellRectID][4] - cellPadding - iconPadding, cellSize * 0.03, progress, { 0.08, 0.08, 0.08, 0.6 })
	end

	-- factory queue number
	if cmds[cellRectID].params[1] then
		local pad = math_floor(cellInnerSize * 0.03)
		local textWidth = math_floor(font2:GetTextWidth(cmds[cellRectID].params[1] .. '  ') * cellInnerSize * 0.285)
		local pad2 = 0
		RectRound(cellRects[cellRectID][3] - cellPadding - iconPadding - textWidth - pad2, cellRects[cellRectID][4] - cellPadding - iconPadding - math_floor(cellInnerSize * 0.365) - pad2, cellRects[cellRectID][3] - cellPadding - iconPadding, cellRects[cellRectID][4] - cellPadding - iconPadding, cornerSize * 3.3, 0, 0, 0, 1, { 0.15, 0.15, 0.15, 0.95 }, { 0.25, 0.25, 0.25, 0.95 })
		RectRound(cellRects[cellRectID][3] - cellPadding - iconPadding - textWidth - pad2, cellRects[cellRectID][4] - cellPadding - iconPadding - math_floor(cellInnerSize * 0.15) - pad2, cellRects[cellRectID][3] - cellPadding - iconPadding, cellRects[cellRectID][4] - cellPadding - iconPadding, 0, 0, 0, 0, 0, { 1, 1, 1, 0 }, { 1, 1, 1, 0.05 })
		RectRound(cellRects[cellRectID][3] - cellPadding - iconPadding - textWidth - pad2 + pad, cellRects[cellRectID][4] - cellPadding - iconPadding - math_floor(cellInnerSize * 0.365) - pad2 + pad, cellRects[cellRectID][3] - cellPadding - iconPadding - pad2, cellRects[cellRectID][4] - cellPadding - iconPadding - pad2, cornerSize * 2.6, 0, 0, 0, 1, { 0.7, 0.7, 0.7, 0.1 }, { 1, 1, 1, 0.1 })
		font2:Print("\255\190\255\190" .. cmds[cellRectID].params[1],
			cellRects[cellRectID][1] + cellPadding + math_floor(cellInnerSize * 0.96) - pad2,
			cellRects[cellRectID][2] + cellPadding + math_floor(cellInnerSize * 0.735) - pad2,
			cellInnerSize * 0.29, "ro"
		)
	end
end

function drawBuildmenu()
	local activeArea = {
		backgroundRect[1] + (stickToBottom and bgpadding or 0) + activeAreaMargin,
		backgroundRect[2] + (stickToBottom and 0 or bgpadding) + activeAreaMargin,
		backgroundRect[3] - bgpadding - activeAreaMargin,
		backgroundRect[4] - bgpadding - activeAreaMargin
	}
	local contentHeight = activeArea[4] - activeArea[2]
	local contentWidth = activeArea[3] - activeArea[1]
	local maxCellSize = contentHeight/2
	-- determine grid size
	if not dynamicIconsize then
		colls = defaultColls
		cellSize = math_min(maxCellSize, math_floor((contentWidth / colls)))
		rows = math_floor(contentHeight / cellSize)
	else
		colls = minColls
		cellSize = math_min(maxCellSize, math_floor((contentWidth / colls)))

		rows = math_floor(contentHeight / cellSize)
		if minColls < maxColls then
			while cmdsCount > rows * colls do
				colls = colls + 1
				cellSize = math_min(maxCellSize, math_floor((contentWidth / colls)))
				rows = math_floor(contentHeight / cellSize)
				if colls == maxColls then
					break
				end
			end
		end
		if stickToBottom then
			if rows > 1 and cmdsCount <= (colls-1) * rows then
				colls = colls - 1
				cellSize = math_min(maxCellSize, math_floor((contentHeight / rows)))
			end
			--cellSize = math_min(contentHeight*0.6, math_floor((contentHeight / rows) + 0.5))
			--colls = math_min(minColls, math_floor(contentWidth / cellSize))
			--if contentWidth / colls < contentWidth / cellSize then
			--	rows = rows + 1
			--	cellSize = math_min(contentHeight*0.6, math_floor((contentHeight / rows) + 0.5))
			--	colls = math_min(minColls, math_floor(contentWidth / cellSize))
			--end
		end
	end

	-- adjust grid size when pages are needed
	local paginatorCellHeight = math_floor(contentHeight - (rows * cellSize))
	if cmdsCount > colls * rows then
		pages = math_ceil(cmdsCount / (colls * rows))
		-- when more than 1 page: reserve bottom row for paginator and calc again
		if pages > 1 then
			pages = math_ceil(cmdsCount / (colls * (rows - 1)))
		end
		if currentPage > pages then
			currentPage = pages
		end

		-- remove a row if there isnt enough room for the paginator UI
		if not stickToBottom then
			if paginatorCellHeight < (0.06 * (1 - ((colls / 4) * 0.25))) * vsy then
				rows = rows - 1
				paginatorCellHeight = math_floor(contentHeight - (rows * cellSize))
			end
		else
			if paginatorCellHeight < (0.06 * (1 - ((rows / 4) * 0.25))) * vsx then
				colls = colls - 1
				paginatorCellHeight = math_floor(contentHeight - (colls * cellSize))
			end
		end
	else
		currentPage = 1
		pages = 1
	end

	-- these are globals so it can be re-used (hover highlight)
	cellPadding = math_floor(cellSize * cfgCellPadding)
	iconPadding = math_max(1, math_floor(cellSize * cfgIconPadding))
	cornerSize = math_floor(cellSize * cfgIconCornerSize)
	cellInnerSize = cellSize - cellPadding - cellPadding
	priceFontSize = math_floor((cellInnerSize * cfgPriceFontSize) + 0.5)

	cellRects = {}
	local numCellsPerPage = rows * colls
	local cellRectID = numCellsPerPage * (currentPage - 1)
	local maxCellRectID = numCellsPerPage * currentPage
	if maxCellRectID > cmdsCount then
		maxCellRectID = cmdsCount
	end
	font2:Begin()
	local iconCount = 0
	for row = 1, rows do
		if cellRectID >= maxCellRectID then
			break
		end
		for coll = 1, colls do
			if cellRectID >= maxCellRectID then
				break
			end

			iconCount = iconCount + 1
			cellRectID = cellRectID + 1

			local uDefID = cmds[cellRectID].id * -1
			if stickToBottom then
				cellRects[cellRectID] = {
					activeArea[1] + ((coll - 1) * cellSize),
					activeArea[4] - ((row) * cellSize),
					activeArea[1] + (((coll)) * cellSize),
					activeArea[4] - ((row - 1) * cellSize)
				}
			else
				cellRects[cellRectID] = {
					activeArea[3] - ((colls - coll + 1) * cellSize),
					activeArea[4] - ((row) * cellSize),
					activeArea[3] - (((colls - coll)) * cellSize),
					activeArea[4] - ((row - 1) * cellSize)
				}
			end
			local cellIsSelected = (activeCmd and cmds[cellRectID] and activeCmd == cmds[cellRectID].name)
			local usedZoom = cellIsSelected and selectedCellZoom or defaultCellZoom

			if cellIsSelected then
				WG['buildmenu'].selectedID = uDefID
			end

			drawCell(cellRectID, usedZoom, cellIsSelected and { 1, 0.85, 0.2, 0.25 } or nil, nil, nil, nil, unitRestricted[uDefID] or unitDisabled[uDefID])
		end
	end

	-- paginator
	if pages == 1 then
		paginatorRects = {}
	else
		local paginatorFontSize = math_max(0.016 * vsy, paginatorCellHeight * 0.2)
		local paginatorCellWidth = math_floor(contentWidth * 0.3)
		local paginatorBorderSize = math_floor(cellSize * ((cfgIconPadding + cfgCellPadding)))

		paginatorRects[1] = { activeArea[1], activeArea[2], activeArea[1] + paginatorCellWidth, activeArea[2] + paginatorCellHeight - cellPadding - activeAreaMargin }
		paginatorRects[2] = { activeArea[3] - paginatorCellWidth, activeArea[2], activeArea[3], activeArea[2] + paginatorCellHeight - cellPadding - activeAreaMargin }

		UiButton(paginatorRects[1][1] + cellPadding, paginatorRects[1][2] + cellPadding, paginatorRects[1][3] - cellPadding, paginatorRects[1][4] - cellPadding, 1,1,1,1, 1,1,1,1, nil, { 0, 0, 0, 0.8 }, { 0.2, 0.2, 0.2, 0.8 }, bgpadding * 0.5)
		font2:Print("<", paginatorRects[1][1] + (paginatorCellWidth * 0.5), paginatorRects[1][2] + (paginatorCellHeight * 0.5) - (paginatorFontSize * 0.25), paginatorFontSize * 1.2, "co")
		UiButton(paginatorRects[2][1] + cellPadding, paginatorRects[2][2] + cellPadding, paginatorRects[2][3] - cellPadding, paginatorRects[2][4] - cellPadding, 1,1,1,1, 1,1,1,1, nil, { 0, 0, 0, 0.8 }, { 0.2, 0.2, 0.2, 0.8 }, bgpadding * 0.5)
		font2:Print(">", paginatorRects[2][1] + (paginatorCellWidth * 0.5), paginatorRects[2][2] + (paginatorCellHeight * 0.5) - (paginatorFontSize * 0.25), paginatorFontSize * 1.2, "co")

		font2:Print("\255\245\245\245" .. currentPage .. "  /  " .. pages, contentWidth * 0.5, activeArea[2] + (paginatorCellHeight * 0.5) - (paginatorFontSize * 0.25), paginatorFontSize, "co")
	end

	font2:End()
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

local function GetBuildingDimensions(uDefID, facing)
	local bDef = UnitDefs[uDefID]
	if (facing % 2 == 1) then
		return 4 * bDef.zsize, 4 * bDef.xsize
	else
		return 4 * bDef.xsize, 4 * bDef.zsize
	end
end

local function removeUnitShape(id)
	if unitshapes[id] then
		WG.StopDrawUnitShapeGL4(unitshapes[id])
		unitshapes[id] = nil
	end
end

local function addUnitShape(id, unitDefID, px, py, pz, rotationY, teamID)
	if unitshapes[id] then
		removeUnitShape(id)
	end
	unitshapes[id] = WG.DrawUnitShapeGL4(unitDefID, px, py, pz, rotationY, 1, teamID, nil, nil)
	return unitshapes[id]
end

local function DrawBuilding(buildData, borderColor, buildingAlpha, drawRanges)
	local bDefID, bx, by, bz, facing = buildData[1], buildData[2], buildData[3], buildData[4], buildData[5]
	local bw, bh = GetBuildingDimensions(bDefID, facing)

	gl.DepthTest(false)
	gl.Color(borderColor)

	gl.Shape(GL.LINE_LOOP, { { v = { bx - bw, by, bz - bh } },
							 { v = { bx + bw, by, bz - bh } },
							 { v = { bx + bw, by, bz + bh } },
							 { v = { bx - bw, by, bz + bh } } })

	if drawRanges then
		if isMex[bDefID] then
			gl.Color(1.0, 0.3, 0.3, 0.7)
			gl.DrawGroundCircle(bx, by, bz, Game.extractorRadius, 50)
		end

		local wRange = unitMaxWeaponRange[bDefID]
		if wRange then
			gl.Color(1.0, 0.3, 0.3, 0.7)
			gl.DrawGroundCircle(bx, by, bz, wRange, 40)
		end
	end

	if WG.StopDrawUnitShapeGL4 then
		local id = buildData[1]..'_'..buildData[2]..'_'..buildData[3]..'_'..buildData[4]..'_'..buildData[5]
		addUnitShape(id, buildData[1], buildData[2], buildData[3], buildData[4], buildData[5]*(math.pi/2), myTeamID)
	end
end

local function DoBuildingsClash(buildData1, buildData2)

	local w1, h1 = GetBuildingDimensions(buildData1[1], buildData1[5])
	local w2, h2 = GetBuildingDimensions(buildData2[1], buildData2[5])

	return math.abs(buildData1[2] - buildData2[2]) < w1 + w2 and
		math.abs(buildData1[4] - buildData2[4]) < h1 + h2
end

-- load all icons to prevent briefly showing white unit icons (will happen due to the custom texture filtering options)
local function cacheUnitIcons()
	local excludeScavs = not (Spring.Utilities.Gametype.IsScavengers() or Spring.GetModOptions().experimentalscavuniqueunits)
	local excludeChickens = not Spring.Utilities.Gametype.IsChickens()
	gl.Translate(-vsx,0,0)
	gl.Color(1, 1, 1, 0.001)
	for id, unit in pairs(UnitDefs) do
		if not excludeScavs or not string.find(unit.name,'_scav') then
			if not excludeChickens or not string.find(unit.name,'chicken') then
				gl.Texture('#'..id)
				gl.TexRect(-1, -1, 0, 0)
				if unitIconType[id] and iconTypesMap[unitIconType[id]] then
					gl.Texture(':l:' .. iconTypesMap[unitIconType[id]])
					gl.TexRect(-1, -1, 0, 0)
				end
			end
		end
	end
	gl.Color(1, 1, 1, 1)
	gl.Translate(vsx,0,0)
end

function widget:DrawScreen()
	if Spring.GetGameFrame() == 0 and not cachedUnitIcons then
		cachedUnitIcons = true
		cacheUnitIcons()
	end

	if chobbyInterface then
		return
	end

	-- refresh buildmenu if active cmd changed
	local prevActiveCmd = activeCmd
	activeCmd = select(4, spGetActiveCommand())
	if activeCmd ~= prevActiveCmd then
		doUpdate = true
	end

	WG['buildmenu'].hoverID = nil
	if not preGamestartPlayer and selectedBuilderCount == 0 and not alwaysShow then
		if WG['guishader'] and dlistGuishader then
			WG['guishader'].RemoveDlist('buildmenu')
		end
	else
		local x, y, b, b2, b3 = spGetMouseState()
		local now = os_clock()
		if doUpdate or (doUpdateClock and now >= doUpdateClock) then
			if doUpdateClock and now >= doUpdateClock then
				doUpdateClock = nil
			end
			lastUpdate = now
			clear()
			RefreshCommands()
			doUpdate = nil
		end

		-- create buildmenu drawlists
		if WG['guishader'] and dlistGuishader then
			WG['guishader'].InsertDlist(dlistGuishader, 'buildmenu')
		end
		if not dlistBuildmenu then
			dlistBuildmenuBg = gl.CreateList(function()
				drawBuildmenuBg()
			end)
			dlistBuildmenu = gl.CreateList(function()
				drawBuildmenu()
			end)
		end

		local hovering = false
		if math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
			Spring.SetMouseCursor('cursornormal')
			hovering = true
		end

		-- draw buildmenu background
		gl.CallList(dlistBuildmenuBg)
		if preGamestartPlayer or selectedBuilderCount ~= 0 then
			-- pre process + 'highlight' under the icons
			local hoveredCellID
			if not WG['topbar'] or not WG['topbar'].showingQuit() then
				if hovering then
					for cellRectID, cellRect in pairs(cellRects) do
						if math_isInRect(x, y, cellRect[1], cellRect[2], cellRect[3], cellRect[4]) then
							hoveredCellID = cellRectID
							local cellIsSelected = (activeCmd and cmds[cellRectID] and activeCmd == cmds[cellRectID].name)
							local uDefID = cmds[cellRectID].id * -1
							WG['buildmenu'].hoverID = uDefID
							gl.Color(1, 1, 1, 1)
							local alt, ctrl, meta, shift = Spring.GetModKeyState()
							if WG['tooltip'] and not meta then
								-- when meta: unitstats does the tooltip
								local text
								local textColor = "\255\215\255\215"

								if unitRestricted[uDefID] or unitDisabled[uDefID] then
									text = Spring.I18N('ui.buildMenu.disabled', { unit = UnitDefs[uDefID].translatedHumanName, textColor = textColor, warnColor = "\255\166\166\166" })
								else
									text = textColor .. UnitDefs[uDefID].translatedHumanName
								end

								text = text .. "\n\255\240\240\240" .. UnitDefs[uDefID].translatedTooltip

								WG['tooltip'].ShowTooltip('buildmenu', text)
							end

							-- highlight --if b and not disableInput then
							glBlending(GL_SRC_ALPHA, GL_ONE)
							RectRound(cellRects[cellRectID][1] + cellPadding, cellRects[cellRectID][2] + cellPadding, cellRects[cellRectID][3] - cellPadding, cellRects[cellRectID][4] - cellPadding, cellSize * 0.03, 1, 1, 1, 1, { 0, 0, 0, 0.1 * ui_opacity }, { 0, 0, 0, 0.1 * ui_opacity })
							glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
							break
						end
					end
				end
			end

			-- draw buildmenu content
			gl.CallList(dlistBuildmenu)

			-- draw highlight
			local usedZoom
			local cellColor
			if not WG['topbar'] or not WG['topbar'].showingQuit() then
				if math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then

					-- paginator buttons
					local paginatorHovered = false
					if paginatorRects[1] and math_isInRect(x, y, paginatorRects[1][1], paginatorRects[1][2], paginatorRects[1][3], paginatorRects[1][4]) then
						paginatorHovered = 1
					end
					if paginatorRects[2] and math_isInRect(x, y, paginatorRects[2][1], paginatorRects[2][2], paginatorRects[2][3], paginatorRects[2][4]) then
						paginatorHovered = 2
					end
					if paginatorHovered then
						if WG['tooltip'] then
							local text = "\255\240\240\240" .. (paginatorHovered == 1 and Spring.I18N('ui.buildMenu.previousPage') or Spring.I18N('ui.buildMenu.nextPage'))
							WG['tooltip'].ShowTooltip('buildmenu', text)
						end
						RectRound(paginatorRects[paginatorHovered][1] + cellPadding, paginatorRects[paginatorHovered][2] + cellPadding, paginatorRects[paginatorHovered][3] - cellPadding, paginatorRects[paginatorHovered][4] - cellPadding, cellSize * 0.03, 2, 2, 2, 2, { 1, 1, 1, 0 }, { 1, 1, 1, (b and 0.35 or 0.15) })
						-- gloss
						RectRound(paginatorRects[paginatorHovered][1] + cellPadding, paginatorRects[paginatorHovered][4] - cellPadding - ((paginatorRects[paginatorHovered][4] - paginatorRects[paginatorHovered][2]) * 0.5), paginatorRects[paginatorHovered][3] - cellPadding, paginatorRects[paginatorHovered][4] - cellPadding, cellSize * 0.03, 2, 2, 0, 0, { 1, 1, 1, 0.015 }, { 1, 1, 1, 0.13 })
						RectRound(paginatorRects[paginatorHovered][1] + cellPadding, paginatorRects[paginatorHovered][2] + cellPadding, paginatorRects[paginatorHovered][3] - cellPadding, paginatorRects[paginatorHovered][2] + cellPadding + ((paginatorRects[paginatorHovered][4] - paginatorRects[paginatorHovered][2]) * 0.33), cellSize * 0.03, 0, 0, 2, 2, { 1, 1, 1, 0.025 }, { 1, 1, 1, 0 })
					end

					-- draw cell hover
					if hoveredCellID then
						local uDefID = cmds[hoveredCellID].id * -1
						local cellIsSelected = (activeCmd and cmds[hoveredCellID] and activeCmd == cmds[hoveredCellID].name)
						if not prevHoveredCellID or hoveredCellID ~= prevHoveredCellID or uDefID ~= hoverUdefID or cellIsSelected ~= hoverCellSelected or b ~= prevB or b3 ~= prevB3 or cmds[hoveredCellID].params[1] ~= prevQueueNr then
							prevQueueNr = cmds[hoveredCellID].params[1]
							prevB = b
							prevB3 = b3
							prevHoveredCellID = hoveredCellID
							hoverCellSelected = cellIsSelected
							hoverUdefID = uDefID
							if hoverDlist then
								hoverDlist = gl.DeleteList(hoverDlist)
							end
							hoverDlist = gl.CreateList(function()

								-- determine zoom amount and cell color
								usedZoom = hoverCellZoom
								if not cellIsSelected then
									if (b or b2) and cellIsSelected then
										usedZoom = clickSelectedCellZoom
									elseif cellIsSelected then
										usedZoom = selectedCellZoom
									elseif (b or b2) and not disableInput then
										usedZoom = clickCellZoom
									elseif b3 and not disableInput and cmds[hoveredCellID].params[1] then
										-- has queue
										usedZoom = rightclickCellZoom
									end
									-- determine color
									if (b or b2) and not disableInput then
										cellColor = { 0.3, 0.8, 0.25, 0.2 }
									elseif b3 and not disableInput then
										cellColor = { 1, 0.35, 0.3, 0.2 }
									else
										cellColor = { 0.63, 0.63, 0.63, 0 }
									end
								else
									-- selected cell
									if (b or b2 or b3) then
										usedZoom = clickSelectedCellZoom
									else
										usedZoom = selectedCellZoom
									end
									cellColor = { 1, 0.85, 0.2, 0.25 }
								end
								if not (unitRestricted[uDefID] or unitDisabled[uDefID]) then

									local unsetShowPrice, unsetShowRadarIcon, unsetShowGroupIcon
									if not showPrice then
										unsetShowPrice = true
										showPrice = true
									end

									-- re-draw cell with hover zoom (and price shown)
									drawCell(hoveredCellID, usedZoom, cellColor, nil, { cellColor[1], cellColor[2], cellColor[3], 0.045 + (usedZoom * 0.45) }, 0.15, unitRestricted[uDefID] or unitDisabled[uDefID])

									if unsetShowPrice then
										showPrice = false
										unsetShowPrice = nil
									end
								end
							end)
						end
						if hoverDlist then
							gl.CallList(hoverDlist)
						end
					end
				end
			end

			-- draw builders buildoption progress
			if showBuildProgress then
				local numCellsPerPage = rows * colls
				local maxCellRectID = numCellsPerPage * currentPage
				if maxCellRectID > cmdsCount then
					maxCellRectID = cmdsCount
				end
				-- loop selected builders
				local drawncellRectIDs = {}
				for builderUnitID, _ in pairs(selectedBuilders) do
					local unitBuildID = spGetUnitIsBuilding(builderUnitID)
					if unitBuildID then
						local unitBuildDefID = spGetUnitDefID(unitBuildID)
						if unitBuildDefID then
							-- loop all shown cells
							local cellIsSelected
							for cellRectID, cellRect in pairs(cellRects) do
								if not drawncellRectIDs[cellRectID] then
									cellIsSelected = false
									if cellRectID > maxCellRectID then
										break
									end
									local cellUnitDefID = cmds[cellRectID].id * -1
									if unitBuildDefID == cellUnitDefID then
										drawncellRectIDs[cellRectID] = true
										local progress = 1 - select(5, spGetUnitHealth(unitBuildID))
										RectRoundProgress(cellRects[cellRectID][1] + cellPadding + iconPadding, cellRects[cellRectID][2] + cellPadding + iconPadding, cellRects[cellRectID][3] - cellPadding - iconPadding, cellRects[cellRectID][4] - cellPadding - iconPadding, cellSize * 0.03, progress, { 0.08, 0.08, 0.08, 0.6 })
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

function widget:DrawWorld()
	if not WG.StopDrawUnitShapeGL4 then return end

	if Spring.GetGameFrame() == 0 then

		-- remove unit shape queue to re-add again later
		if WG.StopDrawUnitShapeGL4 then
			for id, _ in pairs(unitshapes) do
				removeUnitShape(id)
			end
		end

		-- draw pregame build queue
		if preGamestartPlayer then
			local buildDistanceColor = { 0.3, 1.0, 0.3, 0.6 }
			local buildLinesColor = { 0.3, 1.0, 0.3, 0.6 }
			local borderNormalColor = { 0.3, 1.0, 0.3, 0.5 }
			local borderClashColor = { 0.7, 0.3, 0.3, 1.0 }
			local borderValidColor = { 0.0, 1.0, 0.0, 1.0 }
			local borderInvalidColor = { 1.0, 0.0, 0.0, 1.0 }
			local buildingQueuedAlpha = 0.5

			gl.LineWidth(1.49)

			-- We need data about currently selected building, for drawing clashes etc
			local selBuildData
			if selBuildQueueDefID then
				local x, y, b = spGetMouseState()
				local _, pos = spTraceScreenRay(x, y, true)
				if pos then
					local bx, by, bz = Spring.Pos2BuildPos(selBuildQueueDefID, pos[1], pos[2], pos[3])
					local buildFacing = Spring.GetBuildFacing()
					selBuildData = { selBuildQueueDefID, bx, by, bz, buildFacing }
				end
			end

			if startDefID ~= Spring.GetTeamRulesParam(myTeamID, 'startUnit') then
				startDefID = Spring.GetTeamRulesParam(myTeamID, 'startUnit')
				doUpdate = true
			end

			local sx, sy, sz = Spring.GetTeamStartPosition(myTeamID) -- Returns -100, -100, -100 when none chosen
			local startChosen = (sx ~= -100)
			if startChosen and startDefID then
				-- Correction for start positions in the air
				sy = Spring.GetGroundHeight(sx, sz)

				-- Draw start units build radius
				gl.Color(buildDistanceColor)
				gl.DrawGroundCircle(sx, sy, sz, UnitDefs[startDefID].buildDistance, 40)
			end

			-- Check for faction change
			for b = 1, #buildQueue do
				local buildData = buildQueue[b]
				local buildDataId = buildData[1]
				if startDefID == UnitDefNames["armcom"].id then
					if corToArm[buildDataId] ~= nil then
						buildData[1] = corToArm[buildDataId]
						buildQueue[b] = buildData
					end
				elseif startDefID == UnitDefNames["corcom"].id then
					if armToCor[buildDataId] ~= nil then
						buildData[1] = armToCor[buildDataId]
						buildQueue[b] = buildData
					end
				end
			end

			-- clean all previous frame buildings
			-- Draw all the buildings
			local queueLineVerts = startChosen and { { v = { sx, sy, sz } } } or {}
			for b = 1, #buildQueue do
				local buildData = buildQueue[b]

				if selBuildData and DoBuildingsClash(selBuildData, buildData) then
					DrawBuilding(buildData, borderClashColor, buildingQueuedAlpha)
				else
					DrawBuilding(buildData, borderNormalColor, buildingQueuedAlpha)
				end

				queueLineVerts[#queueLineVerts + 1] = { v = { buildData[2], buildData[3], buildData[4] } }
			end

			-- Draw queue lines
			glColor(buildLinesColor)
			gl.LineStipple("springdefault")
			gl.Shape(GL.LINE_STRIP, queueLineVerts)
			gl.LineStipple(false)

			-- Draw selected building
			if selBuildData then
				if Spring.TestBuildOrder(selBuildQueueDefID, selBuildData[2], selBuildData[3], selBuildData[4], selBuildData[5]) ~= 0 then
					DrawBuilding(selBuildData, borderValidColor, 1.0, true)
				else
					DrawBuilding(selBuildData, borderInvalidColor, 1.0, true)
				end
			end

			-- Reset gl
			glColor(1, 1, 1, 1)
			gl.LineWidth(1.0)
		end
	else
		if WG.StopDrawUnitShapeGL4 then
			for id, _ in pairs(unitshapes) do
				removeUnitShape(id)
			end
		end
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdOpts, cmdParams, cmdTag)
	if isFactory[unitDefID] and cmdID < 0 then
		-- filter away non build cmd's
		if doUpdateClock == nil then
			doUpdateClock = os_clock() + 0.01
		end
	end
end

function widget:SelectionChanged(sel)
	updateSelection = true
end

local function GetUnitCanCompleteQueue(uID)

	local uDefID = Spring.GetUnitDefID(uID)
	if uDefID == startDefID then
		return true
	end

	-- What can this unit build ?
	local uCanBuild = {}
	local uBuilds = UnitDefs[uDefID].buildOptions
	for i = 1, #uBuilds do
		uCanBuild[uBuilds[i]] = true
	end

	-- Can it build everything that was queued ?
	for i = 1, #buildQueue do
		if not uCanBuild[buildQueue[i][1]] then
			return false
		end
	end

	return true
end

local function unbindBuildUnits()
	for _, buildOption in ipairs(boundUnits) do
		widgetHandler.actionHandler:RemoveAction(self, "buildunit_" .. buildOption, 'p')
	end

	boundUnits = {}
end

function widget:GameFrame(n)

	if checkGeothermalFeatures then
		checkGeothermalFeatures()
		checkGeothermalFeatures = nil
	end

	if preGamestartPlayer then
		unbindBuildUnits()
	end
	-- handle the pregame build queue
	preGamestartPlayer = false
	if n <= 90 and #buildQueue > 0 then

		if n < 2 then
			return
		end -- Give the unit frames 0 and 1 to spawn

		-- inform gadget how long is our queue
		local t = 0
		for i = 1, #buildQueue do
			t = t + UnitDefs[buildQueue[i][1]].buildTime
		end
		if startDefID then
			local buildTime = t / UnitDefs[startDefID].buildSpeed
			Spring.SendCommands("luarules initialQueueTime " .. buildTime)
		end

		local tasker
		-- Search for our starting unit
		local units = Spring.GetTeamUnits(Spring.GetMyTeamID())
		for u = 1, #units do
			local uID = units[u]
			if GetUnitCanCompleteQueue(uID) then
				tasker = uID
				if Spring.GetUnitRulesParam(uID, "startingOwner") == Spring.GetMyPlayerID() then
					-- we found our com even if cooping, assigning queue to this particular unit
					break
				end
			end
		end
		if tasker then
			for b = 1, #buildQueue do
				local buildData = buildQueue[b]
				Spring.GiveOrderToUnit(tasker, -buildData[1], { buildData[2], buildData[3], buildData[4], buildData[5] }, { "shift" })
			end
			buildQueue = {}
		end
	end
end

function SetBuildFacing()
	local wx, wy, _, _ = Spring.GetScreenGeometry()
	local _, pos = spTraceScreenRay(wx / 2, wy / 2, true)
	if not pos then
		return
	end
	local x = pos[1]
	local z = pos[3]

	local facing
	if math.abs(Game.mapSizeX - 2 * x) > math.abs(Game.mapSizeZ - 2 * z) then
		if 2 * x > Game.mapSizeX then
			facing = 3
		else
			facing = 1
		end
	else
		if 2 * z > Game.mapSizeZ then
			facing = 2
		else
			facing = 0
		end
	end
	Spring.SetBuildFacing(facing)
end

local function setPreGamestartDefID(uDefID)
	selBuildQueueDefID = uDefID
	if isMex[uDefID] then
		if Spring.GetMapDrawMode() ~= "metal" then
			Spring.SendCommands("ShowMetalMap")
		end
	elseif Spring.GetMapDrawMode() == "metal" then
		Spring.SendCommands("ShowStandard")
	end
end

function widget:MousePress(x, y, button)
	if Spring.IsGUIHidden() then
		return
	end
	if WG['topbar'] and WG['topbar'].showingQuit() then
		return
	end

	if math_isInRect(x, y, backgroundRect[1], backgroundRect[2], backgroundRect[3], backgroundRect[4]) then
		if selectedBuilderCount > 0 or (preGamestartPlayer and startDefID) then
			local paginatorHovered = false
			if paginatorRects[1] and math_isInRect(x, y, paginatorRects[1][1], paginatorRects[1][2], paginatorRects[1][3], paginatorRects[1][4]) then
				currentPage = currentPage - 1
				if currentPage < 1 then
					currentPage = pages
				end
				doUpdate = true
			end
			if paginatorRects[2] and math_isInRect(x, y, paginatorRects[2][1], paginatorRects[2][2], paginatorRects[2][3], paginatorRects[2][4]) then
				currentPage = currentPage + 1
				if currentPage > pages then
					currentPage = 1
				end
				doUpdate = true
			end
			if not disableInput then
				for cellRectID, cellRect in pairs(cellRects) do
					if cmds[cellRectID].id and UnitDefs[-cmds[cellRectID].id].translatedHumanName and math_isInRect(x, y, cellRect[1], cellRect[2], cellRect[3], cellRect[4]) and not (unitRestricted[-cmds[cellRectID].id] or unitDisabled[-cmds[cellRectID].id]) then
						if button ~= 3 then
							if playSounds then
								Spring.PlaySoundFile(sound_queue_add, 0.75, 'ui')
							end
							if preGamestartPlayer then
								setPreGamestartDefID(cmds[cellRectID].id * -1)
							elseif spGetCmdDescIndex(cmds[cellRectID].id) then
								Spring.SetActiveCommand(spGetCmdDescIndex(cmds[cellRectID].id), 1, true, false, Spring.GetModKeyState())
							end
						else
							if cmds[cellRectID].params[1] and playSounds then
								-- has queue
								Spring.PlaySoundFile(sound_queue_rem, 0.75, 'ui')
							end
							if preGamestartPlayer then
								setPreGamestartDefID(cmds[cellRectID].id * -1)
							elseif spGetCmdDescIndex(cmds[cellRectID].id) then
								Spring.SetActiveCommand(spGetCmdDescIndex(cmds[cellRectID].id), 3, false, true, Spring.GetModKeyState())
							end
						end
						doUpdateClock = os_clock() + 0.01
						return true
					end
				end
			end
			return true
		elseif alwaysShow then
			return true
		end

	elseif preGamestartPlayer then

		if selBuildQueueDefID then
			if button == 1 then

				local mx, my, button = spGetMouseState()
				local _, pos = spTraceScreenRay(mx, my, true)
				if not pos then
					return
				end
				local bx, by, bz = Spring.Pos2BuildPos(selBuildQueueDefID, pos[1], pos[2], pos[3])
				local buildFacing = Spring.GetBuildFacing()

				if Spring.TestBuildOrder(selBuildQueueDefID, bx, by, bz, buildFacing) ~= 0 then

					local buildData = { selBuildQueueDefID, bx, by, bz, buildFacing }
					local _, _, meta, shift = Spring.GetModKeyState()
					if meta then
						table.insert(buildQueue, 1, buildData)

					elseif shift then

						local anyClashes = false
						for i = #buildQueue, 1, -1 do
							if DoBuildingsClash(buildData, buildQueue[i]) then
								anyClashes = true
								table.remove(buildQueue, i)
							end
						end

						if not anyClashes then
							buildQueue[#buildQueue + 1] = buildData
						end
					else
						buildQueue = { buildData }
					end

					if not shift then
						setPreGamestartDefID(nil)
					end
				end

				return true

			elseif button == 3 then
				setPreGamestartDefID(nil)
				return true
			end
		end
	end
end

-- Used for hotkeys at pregamestart
local function buildUnitHandler(_, _, _, data)
	-- sanity check
	if not preGamestartPlayer then return end
	if unitDisabled[data.unitDefID] then return end

	local comDef = UnitDefs[startDefID]

	if not comBuildOptions[comDef.name][data.unitDefID] then return end

	-- If no current active selection we can return early
	if not selBuildQueueDefID then
		setPreGamestartDefID(data.unitDefID)

		return true
	end

	-- Find the buildcycle for current key and iterate on it
	local pressedKeys = Spring.GetPressedKeys()
	local pressedKey
	for k, v in pairs(pressedKeys) do
		local key = SYMKEYS[k]

		if v and key and #key == 1 then
			pressedKey = string.lower(key)
			break
		end
	end

	-- didnt find a suitable binding to cycle from
	if not pressedKey then return end

	local buildCycle = {}

	for _, keybind in ipairs(Spring.GetKeyBindings(pressedKey)) do
		if string.sub(keybind.command, 1, 10) == 'buildunit_' then
			local uDefName = string.sub(keybind.command, 11)
			local uDef = UnitDefNames[uDefName]
			if comBuildOptions[comDef.name][uDef.id] and not unitDisabled[uDef.id] then
				table.insert(buildCycle, uDef.id)
			end
		end
	end

	if #buildCycle == 0 then return end

	local buildCycleIndex
	for i, v in ipairs(buildCycle) do
		if v == selBuildQueueDefID then
			buildCycleIndex = i
			break
		end
	end

	if not buildCycleIndex then
		setPreGamestartDefID(data.unitDefID)

		return true
	end

	buildCycleIndex = buildCycleIndex + 1
	if buildCycleIndex > #buildCycle then buildCycleIndex = 1 end

	setPreGamestartDefID(buildCycle[buildCycleIndex])

	return true
end

local function bindBuildUnits(widget)
	if not preGamestartPlayer then return end

	unbindBuildUnits()

	comBuildOptions = { armcom = {}, corcom = {} }

	for _, comDefName in ipairs({ "armcom", "corcom" }) do
		for _, buildOption in ipairs(UnitDefNames[comDefName].buildOptions) do
			if not unitDisabled[buildOption] then
				local unitDefName = UnitDefs[buildOption].name

				comBuildOptions[comDefName][buildOption] = true
				table.insert(boundUnits, unitDefName)
				widgetHandler.actionHandler:AddAction(widget, "buildunit_" .. unitDefName, buildUnitHandler, { unitDefID = buildOption }, 'p')
			end
		end
	end
end

local function buildmenuPregameDeselectHandler()
	if preGamestartPlayer and selBuildQueueDefID then
		setPreGamestartDefID()

		return true
	end
end

function widget:Initialize()
	widgetHandler.actionHandler:AddAction(self, "buildfacing", buildFacingHandler, nil, 'p')
	widgetHandler.actionHandler:AddAction(self, "buildmenu_pregame_deselect", buildmenuPregameDeselectHandler, nil, "p")

	checkGeothermalFeatures()

	iconTypesMap = {}
	if Script.LuaRules('GetIconTypes') then
		iconTypesMap = Script.LuaRules.GetIconTypes()
	end

	-- Get our starting unit
	if preGamestartPlayer then
		bindBuildUnits(self)
		SetBuildFacing()
		if not startDefID or startDefID ~= spGetTeamRulesParam(myTeamID, 'startUnit') then
			startDefID = spGetTeamRulesParam(myTeamID, 'startUnit')
			doUpdate = true
		end
	end

	widget:ViewResize()
	widget:SelectionChanged(spGetSelectedUnits())

	WG['buildmenu'] = {}
	WG['buildmenu'].getGroups = function()
		return groups, unitGroup
	end
	WG['buildmenu'].getOrder = function()
		return unitOrder
	end
	WG['buildmenu'].getShowPrice = function()
		return showPrice
	end
	WG['buildmenu'].setShowPrice = function(value)
		showPrice = value
		doUpdate = true
	end
	WG['buildmenu'].getAlwaysShow = function()
		return alwaysShow
	end
	WG['buildmenu'].setAlwaysShow = function(value)
		alwaysShow = value
		doUpdate = true
	end
	WG['buildmenu'].getShowRadarIcon = function()
		return showRadarIcon
	end
	WG['buildmenu'].setShowRadarIcon = function(value)
		showRadarIcon = value
		doUpdate = true
	end
	WG['buildmenu'].getShowGroupIcon = function()
		return showGroupIcon
	end
	WG['buildmenu'].setShowGroupIcon = function(value)
		showGroupIcon = value
		doUpdate = true
	end
	WG['buildmenu'].getDynamicIconsize = function()
		return dynamicIconsize
	end
	WG['buildmenu'].setDynamicIconsize = function(value)
		dynamicIconsize = value
		doUpdate = true
	end
	WG['buildmenu'].getMinColls = function()
		return minColls
	end
	WG['buildmenu'].setMinColls = function(value)
		minColls = value
		doUpdate = true
	end
	WG['buildmenu'].getMaxColls = function()
		return maxColls
	end
	WG['buildmenu'].setMaxColls = function(value)
		maxColls = value
		doUpdate = true
	end
	WG['buildmenu'].getDefaultColls = function()
		return defaultColls
	end

	WG['buildmenu'].setDefaultColls = function(value)
		defaultColls = value
		doUpdate = true
	end
	WG['buildmenu'].getBottomPosition = function()
		return stickToBottom
	end
	WG['buildmenu'].setBottomPosition = function(value)
		stickToBottom = value
		widget:Update(1000)
		widget:ViewResize()
		doUpdate = true
	end
	WG['buildmenu'].getSize = function()
		return posY, posY2
	end
	WG['buildmenu'].getMaxPosY = function()
		return maxPosY
	end
	WG['buildmenu'].setMaxPosY = function(value)
		maxPosY = value
		doUpdate = true
	end
	WG['buildmenu'].reloadBindings = function()
		bindBuildUnits(self)
	end
end

function widget:Shutdown()
	clear()
	hoverDlist = gl.DeleteList(hoverDlist)
	if WG['guishader'] and dlistGuishader then
		WG['guishader'].DeleteDlist('buildmenu')
		dlistGuishader = nil
	end
	WG['buildmenu'] = nil
	if WG.StopDrawUnitShapeGL4 then
		for id, _ in pairs(unitshapes) do
			removeUnitShape(id)
		end
	end
end

function widget:GetConfigData()
	return {
		showPrice = showPrice,
		showRadarIcon = showRadarIcon,
		showGroupIcon = showGroupIcon,
		dynamicIconsize = dynamicIconsize,
		minColls = minColls,
		maxColls = maxColls,
		defaultColls = defaultColls,
		buildQueue = buildQueue,
		stickToBottom = stickToBottom,
		maxPosY = maxPosY,
		gameID = Game.gameID,
		alwaysShow = alwaysShow,
	}
end

function widget:SetConfigData(data)
	if data.showPrice ~= nil then
		showPrice = data.showPrice
	end
	if data.showRadarIcon ~= nil then
		showRadarIcon = data.showRadarIcon
	end
	if data.showGroupIcon ~= nil then
		showGroupIcon = data.showGroupIcon
	end
	if data.dynamicIconsize ~= nil then
		dynamicIconsize = data.dynamicIconsize
	end
	if data.minColls ~= nil then
		minColls = data.minColls
	end
	if data.maxColls ~= nil then
		maxColls = data.maxColls
	end
	if data.defaultColls ~= nil then
		defaultColls = data.defaultColls
	end
	if data.stickToBottom ~= nil then
		stickToBottom = data.stickToBottom
	end
	if data.buildQueue and Spring.GetGameFrame() == 0 and data.gameID and data.gameID == Game.gameID then
		buildQueue = data.buildQueue
	end
	if data.alwaysShow ~= nil then
		alwaysShow = data.alwaysShow
	end
	if data.maxPosY ~= nil then
		maxPosY = data.maxPosY
	end
end
