function widget:GetInfo()
   return {
      name      = "Fancy Selected Units",		--(took 'UnitShapes' widget as a base for this one)
      desc      = "Shows which units are selected",
      author    = "Floris",
      date      = "04.04.2014",
      license   = "GNU GPL, v2 or later",
      layer     = -50,
      enabled   = true
   }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local currentOption					= 2

local currentRotationAngle			= 0
local currentRotationAngleOpposite	= 0
local previousOsClock				= os.clock()

local animationMultiplier			= 1
local animationMultiplierInner		= 1
local animationMultiplierAdd		= true

local clearquad
local shapes = {}
local degrot = {}

local rad_con						= 180 / math.pi
local math_acos						= math.acos

local UNITCONF						= {}

local selectedUnits					= {}
local perfSelectedUnits				= {}
local selectedUnitsInvisible		= {}

local maxSelectTime					= 0				--time at which units "new selection" animation will end
local maxDeselectedTime				= -1			--time at which units deselection animation will end

local checkSelectionChanges			= true

local glCallList					= gl.CallList
local glDrawListAtUnit				= gl.DrawListAtUnit

local spIsUnitSelected				= Spring.IsUnitSelected
local spGetSelectedUnitsCount		= Spring.GetSelectedUnitsCount
local spGetSelectedUnitsSorted		= Spring.GetSelectedUnitsSorted
local spGetUnitTeam					= Spring.GetUnitTeam
local spLoadCmdColorsConfig			= Spring.LoadCmdColorsConfig
local spGetUnitDirection			= Spring.GetUnitDirection
local spGetCameraPosition			= Spring.GetCameraPosition
local spGetUnitViewPosition			= Spring.GetUnitViewPosition
local spGetUnitDefID				= Spring.GetUnitDefID
local spIsGUIHidden					= Spring.IsGUIHidden
local spGetTeamColor				= Spring.GetTeamColor
local spGetUnitHealth 				= Spring.GetUnitHealth
local spGetUnitIsCloaked			= Spring.GetUnitIsCloaked
local spUnitInView                  = Spring.IsUnitInView
local spIsUnitVisible				= Spring.IsUnitVisible

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local OPTIONS = {}
OPTIONS.defaults = {	-- these will be loaded when switching style, but the style will overwrite the those values 
	name							= "Defaults",
	-- Quality settings
	showNoOverlap					= false,	-- set true for no line overlapping
	showBase						= true,
	showFirstLine					= true,
	showFirstLineDetails			= true,
	showSecondLine					= false,
	showExtraComLine				= true,		-- extra circle lines for the commander unit
	showExtraBuildingWeaponLine		= true,

	teamcolorOpacity				= 0.7,		-- how much teamcolor used for the base platter

	-- opacity
	spotterOpacity					= 0.95,
	baseOpacity						= 0.25,
	firstLineOpacity				= 1,
	secondLineOpacity				= 0.2,

	-- animation
	selectionStartAnimation			= true,
	selectionStartAnimationTime		= 0.045,
	selectionStartAnimationScale	= 0.82,
	-- selectionStartAnimationScale	= 1.17,
	selectionEndAnimation			= true,
	selectionEndAnimationTime		= 0.07,
	selectionEndAnimationScale		= 0.9,
	--selectionEndAnimationScale	= 1.17,

	-- animation
	rotationSpeed					= 2.5,
	animationSpeed					= 0.00045,	-- speed of scaling up/down inner and outer lines
	animateSpotterSize				= true,
	maxAnimationMultiplier			= 1.012,
	minAnimationMultiplier			= 0.99,

	-- circle shape
	solidCirclePieces				= 32,
	circlePieces					= 24,
	circlePieceDetail				= 1,		-- smoothness of each piece (1 or higher)
	circleSpaceUsage				= 0.7,		-- 1 = whole circle space gets filled
	circleInnerOffset				= 0.45,

	-- size
	scaleMultiplier					= 1,
	innersize						= 1.7,
	selectinner						= 1.66,
	outersize						= 1.8,
}
table.insert(OPTIONS, {
	name							= "Cheap Fill",
	showFirstLineDetails			= false,
	rotationSpeed					= 0,
	baseOpacity						= 0.4,
})
table.insert(OPTIONS, {
	name							= "Solid Line",
	circlePieces					= 64,
	circlePieceDetail				= 1,
	circleSpaceUsage				= 1,
	circleInnerOffset				= 0,
})
table.insert(OPTIONS, {
	name							= "Tilted Blocky Dots",
	circlePieces					= 36,
	circlePieceDetail				= 1,
	circleSpaceUsage				= 0.7,
	circleInnerOffset				= 0.45,
})
table.insert(OPTIONS, {
	name							= "Blocky Dots",
	circlePieces					= 35,
	circlePieceDetail				= 1,
	circleSpaceUsage				= 0.5,
	circleInnerOffset				= 0,
	rotationSpeed					= 1,
})
table.insert(OPTIONS, {
	name							= "Stretched Blocky Dots",
	circlePieces					= 22,
	circlePieceDetail				= 4,
	circleSpaceUsage				= 0.28,
	circleInnerOffset				= 1,
})
table.insert(OPTIONS, {
	name							= "Curvy Lines",
	circlePieces					= 5,
	circlePieceDetail				= 7,
	circleSpaceUsage				= 0.7,
	circleInnerOffset				= 0,
	rotationSpeed					= 1.8,
})
table.insert(OPTIONS, {
	name							= "Curvy Lines 2",
	circlePieces					= 7,
	circlePieceDetail				= 4,
	circleSpaceUsage				= 0.7,
	circleInnerOffset				= 0,
	rotationSpeed					= 2.5,
})
local styleList = {}
for i,_ in ipairs(OPTIONS) do
	styleList[i] = OPTIONS[i].name
end

function table.shallow_copy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end
OPTIONS_original = table.shallow_copy(OPTIONS)
OPTIONS_original.defaults = nil

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------


local function SetupCommandColors(state)
	spLoadCmdColorsConfig('unitBox  0 1 0 ' .. (state and 1 or 0))
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Creating polygons:
local function CreateDisplayLists(callback)
	local displayLists = {}

	displayLists.select = callback.fading(OPTIONS[currentOption].outersize, OPTIONS[currentOption].selectinner)
	displayLists.inner = callback.solid({0, 0, 0, 0}, OPTIONS[currentOption].innersize)
	displayLists.large = callback.solid(nil, OPTIONS[currentOption].selectinner)
	displayLists.shape = callback.fading(OPTIONS[currentOption].innersize, OPTIONS[currentOption].selectinner)

	return displayLists
end



local function DrawCircleLine(innersize, outersize)
	gl.BeginEnd(GL.QUADS, function()
		local detailPartWidth, a1,a2,a3,a4
		local width = OPTIONS[currentOption].circleSpaceUsage
		local detail = OPTIONS[currentOption].circlePieceDetail

		local radstep = (2.0 * math.pi) / OPTIONS[currentOption].circlePieces
		for i = 1, OPTIONS[currentOption].circlePieces do
			for d = 1, detail do

				detailPartWidth = ((width / detail) * d)
				a1 = ((i+detailPartWidth - (width / detail)) * radstep)
				a2 = ((i+detailPartWidth) * radstep)
				a3 = ((i+OPTIONS[currentOption].circleInnerOffset+detailPartWidth - (width / detail)) * radstep)
				a4 = ((i+OPTIONS[currentOption].circleInnerOffset+detailPartWidth) * radstep)

				--outer (fadein)
				gl.Vertex(math.sin(a4)*innersize, 1, math.cos(a4)*innersize)
				gl.Vertex(math.sin(a3)*innersize, 1, math.cos(a3)*innersize)
				--outer (fadeout)
				gl.Vertex(math.sin(a1)*outersize, 1, math.cos(a1)*outersize)
				gl.Vertex(math.sin(a2)*outersize, 1, math.cos(a2)*outersize)
			end
		end
	end)
end

local function DrawCircleSolid(size)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		local pieces = OPTIONS[currentOption].solidCirclePieces
		local radstep = (2.0 * math.pi) / pieces
		local a1
		if (color) then
			gl.Color(color)
		end
		gl.Vertex(0, 1, 0)
		for i = 0, pieces do
			a1 = (i * radstep)
			gl.Vertex(math.sin(a1)*size, 1, math.cos(a1)*size)
		end
	end)
end

local function CreateCircleLists()
	local callback = {}

	function callback.fading(innersize, outersize)
		return gl.CreateList(DrawCircleLine, innersize, outersize)
	end

	function callback.solid(color, size)
		return gl.CreateList(DrawCircleSolid, size)
	end

	shapes.circle = CreateDisplayLists(callback)
end



local function DrawSquareLine(innersize, outersize)

	gl.BeginEnd(GL.QUADS, function()
		local radstep = (2.0 * math.pi) / 4
		local width, a1,a2,a2_2
		for i = 1, 4 do
			-- straight piece
			width = 0.7
			i = i + 0.65
			a1 = (i * radstep)
			a2 = ((i+width) * radstep)

			gl.Vertex(math.sin(a2)*innersize, 1, math.cos(a2)*innersize)
			gl.Vertex(math.sin(a1)*innersize, 1, math.cos(a1)*innersize)

			gl.Vertex(math.sin(a1)*outersize, 1, math.cos(a1)*outersize)
			gl.Vertex(math.sin(a2)*outersize, 1, math.cos(a2)*outersize)

			-- corner piece
			width = 0.3
			i = i + 3
			a1 = (i * radstep)
			a2 = ((i+width) * radstep)
			i = i -0.6
			a2_2 = ((i+width) * radstep)

			gl.Vertex(math.sin(a2_2)*innersize, 1, math.cos(a2_2)*innersize)
			gl.Vertex(math.sin(a1)*innersize, 1, math.cos(a1)*innersize)

			gl.Vertex(math.sin(a1)*outersize, 1, math.cos(a1)*outersize)
			gl.Vertex(math.sin(a2_2)*outersize, 1, math.cos(a2_2)*outersize)
		end
	end)
end

local function DrawSquareSolid(size)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		local width, a1,a2,a2_2
		local radstep = (2.0 * math.pi) / 4

		for i = 1, 4 do
			--straight piece
			width = 0.7
			i = i + 0.65
			a1 = (i * radstep)
			a2 = ((i+width) * radstep)

			gl.Vertex(0, 0, 0)
			gl.Vertex(math.sin(a2)*size, 1, math.cos(a2)*size)
			gl.Vertex(math.sin(a1)*size, 1, math.cos(a1)*size)

			--corner piece
			width = 0.3
			i = i + 3
			a1 = (i * radstep)
			a2 = ((i+width) * radstep)
			i = i -0.6
			a2_2 = ((i+width) * radstep)

			gl.Vertex(0, 0, 0)
			gl.Vertex(math.sin(a2_2)*size, 1, math.cos(a2_2)*size)
			gl.Vertex(math.sin(a1)*size, 1, math.cos(a1)*size)
		end

	end)
end

local function CreateSquareLists()

	local callback = {}

	function callback.fading(innersize, outersize)
		return gl.CreateList(DrawSquareLine, innersize, outersize)
	end

	function callback.solid(color, size)
		return gl.CreateList(DrawSquareSolid, size)
	end
	shapes.square = CreateDisplayLists(callback)
end



local function DrawTriangleLine(innersize, outersize)
	gl.BeginEnd(GL.QUADS, function()
		local width, a1,a2,a2_2
		local radstep = (2.0 * math.pi) / 3

		for i = 1, 3 do
			--straight piece
			width = 0.75
			i = i + 0.625
			a1 = (i * radstep)
			a2 = ((i+width) * radstep)

			gl.Vertex(math.sin(a2)*innersize, 1, math.cos(a2)*innersize)
			gl.Vertex(math.sin(a1)*innersize, 1, math.cos(a1)*innersize)

			gl.Vertex(math.sin(a1)*outersize, 1, math.cos(a1)*outersize)
			gl.Vertex(math.sin(a2)*outersize, 1, math.cos(a2)*outersize)

			-- corner piece
			width = 0.35
			i = i + 3
			a1 = (i * radstep)
			a2 = ((i+width) * radstep)
			i = i -0.6
			a2_2 = ((i+width) * radstep)

			gl.Vertex(math.sin(a2_2)*innersize, 1, math.cos(a2_2)*innersize)
			gl.Vertex(math.sin(a1)*innersize, 1, math.cos(a1)*innersize)

			gl.Vertex(math.sin(a1)*outersize, 1, math.cos(a1)*outersize)
			gl.Vertex(math.sin(a2_2)*outersize, 1, math.cos(a2_2)*outersize)
		end

	end)
end

local function DrawTriangleSolid(size)

	gl.BeginEnd(GL.TRIANGLE_FAN, function()

		local width, a1,a2,a2_2
		local radstep = (2.0 * math.pi) / 3

		for i = 1, 3 do
			-- straight piece
			width = 0.75
			i = i + 0.625
			a1 = (i * radstep)
			a2 = ((i+width) * radstep)

			gl.Vertex(0, 0, 0)
			gl.Vertex(math.sin(a2)*size, 1, math.cos(a2)*size)
			gl.Vertex(math.sin(a1)*size, 1, math.cos(a1)*size)

			-- corner piece
			width = 0.35
			i = i + 3
			a1 = (i * radstep)
			a2 = ((i+width) * radstep)
			i = i -0.6
			a2_2 = ((i+width) * radstep)

			gl.Vertex(0, 0, 0)
			gl.Vertex(math.sin(a2_2)*size, 1, math.cos(a2_2)*size)
			gl.Vertex(math.sin(a1)*size, 1, math.cos(a1)*size)
		end

	end)
end

local function CreateTriangleLists()

	local callback = {}

	function callback.fading(innersize, outersize)
		return gl.CreateList(DrawTriangleLine, innersize, outersize)
	end

	function callback.solid(color, size)
		return gl.CreateList(DrawTriangleSolid, size)
	end
	shapes.triangle = CreateDisplayLists(callback)
end


local function DestroyShape(shape)
	gl.DeleteList(shape.select)
	gl.DeleteList(shape.inner)
	gl.DeleteList(shape.large)
	gl.DeleteList(shape.shape)
end



function widget:Initialize()

	loadConfig()

	clearquad = gl.CreateList(function()
		local size = 1000
		gl.BeginEnd(GL.QUADS, function()
			gl.Vertex( -size,0,  			-size)
			gl.Vertex( Game.mapSizeX+size,0, -size)
			gl.Vertex( Game.mapSizeX+size,0, Game.mapSizeZ+size)
			gl.Vertex( -size,0, 			Game.mapSizeZ+size)
		end)
	end)

	currentClock = os.clock()

	WG['fancyselectedunits'] = {}
	WG['fancyselectedunits'].getOpacity = function()
		return OPTIONS.defaults.spotterOpacity
	end
	WG['fancyselectedunits'].setOpacity = function(value)
		OPTIONS.defaults.spotterOpacity = value
		OPTIONS[currentOption].spotterOpacity = value
	end
	WG['fancyselectedunits'].getBaseOpacity = function()
		return OPTIONS.defaults.baseOpacity
	end
	WG['fancyselectedunits'].setBaseOpacity = function(value)
		OPTIONS.defaults.baseOpacity = value
		OPTIONS[currentOption].baseOpacity = value
	end
	WG['fancyselectedunits'].getTeamcolorOpacity = function()
		return OPTIONS.defaults.teamcolorOpacity
	end
	WG['fancyselectedunits'].setTeamcolorOpacity = function(value)
		OPTIONS.defaults.teamcolorOpacity = value
		OPTIONS[currentOption].teamcolorOpacity = value
	end
	WG['fancyselectedunits'].getSecondLine = function()
		return OPTIONS.defaults.showSecondLine
	end
	WG['fancyselectedunits'].setSecondLine = function(value)
		OPTIONS.defaults.showSecondLine = value
		OPTIONS[currentOption].showSecondLine = value
	end
	WG['fancyselectedunits'].getStyle = function()
		return currentOption
	end
	WG['fancyselectedunits'].getStyleList = function()
		return styleList
	end
	WG['fancyselectedunits'].setStyle = function(value)
		currentOption = value
		loadConfig()
	end

	SetupCommandColors(false)
end


function loadOption()
	local appliedOption = OPTIONS_original[currentOption]
	OPTIONS[currentOption] = table.shallow_copy(OPTIONS.defaults)

	for option, value in pairs(appliedOption) do
		OPTIONS[currentOption][option] = value
	end
end


function loadConfig()
	loadOption()

	CreateCircleLists()
	CreateSquareLists()
	CreateTriangleLists()

	SetUnitConf()

	Spring.Echo("Fancy Selected Units-dev:  loaded style... '"..OPTIONS[currentOption].name.."'")
end


function SetUnitConf()
	-- prefer not to change because other widgets use these values too  (highlight_units, given_units, selfd_icons, ...)
	local scaleFactor = 2.6
	local rectangleFactor = 3.25

	local name, shape, xscale, zscale, scale, xsize, zsize, weaponcount, shapeName
	for udid, unitDef in pairs(UnitDefs) do
		xsize, zsize = unitDef.xsize, unitDef.zsize
		scale = scaleFactor*( xsize^2 + zsize^2 )^0.5
		name = unitDef.name


		if (unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0) then
			shapeName = 'square'
			shape = shapes.square
			xscale, zscale = rectangleFactor * xsize, rectangleFactor * zsize
		elseif (unitDef.isAirUnit) then
			shapeName = 'triangle'
			shape = shapes.triangle
			xscale, zscale = scale*1.07, scale*1.07
		elseif (unitDef.modCategories["ship"]) then
			shapeName = 'circle'
			shape = shapes.circle
			xscale, zscale = scale*0.82, scale*0.82
		else
			shapeName = 'circle'
			shape = shapes.circle
			xscale, zscale = scale, scale
		end

		local radius = Spring.GetUnitDefDimensions(udid).radius
		xscale = (xscale*0.7) + (radius/5)
		zscale = (zscale*0.7) + (radius/5)

		weaponcount = table.getn(unitDef.weapons)

		UNITCONF[udid] = {name=name, shape=shape, shapeName=shapeName, xscale=xscale, zscale=zscale, weaponcount=weaponcount}
	end
end


function widget:Shutdown()
	if WG['teamplatter'] == nil and WG['highlightselunits'] == nil then
		SetupCommandColors(true)
	end
	WG['fancyselectedunits'] = nil

	gl.DeleteList(clearquad)

	for _, shape in pairs(shapes) do
		DestroyShape(shape)
	end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function GetUsedRotationAngle(unitID, shapeName, opposite)
	if (shapeName == 'circle') then
		if opposite then
			return currentRotationAngleOpposite
		else
			return currentRotationAngle
		end
	else
		return degrot[unitID]
	end
end


function widget:CommandsChanged()		-- gets called when selection 'changes'
	checkSelectionChanges = true
end


local function updateSelectedUnitsData()

	-- re-add selected units that became visible again
	for unitID, unitParams in pairs(selectedUnitsInvisible) do
		if spIsUnitVisible(unitID) then
			selectedUnits[unitParams.teamID][unitID] = unitParams
			selectedUnitsInvisible[unitID] = nil
		end
	end

	-- remove deselected and out-of-view units
	-- adjust unit direction
	local clockDifference
	for teamID,_ in pairs(selectedUnits) do
		for unitID,_ in pairs(selectedUnits[teamID]) do

			-- remove deselected units
			if not spIsUnitSelected(unitID) and selectedUnits[teamID][unitID].selected then
				clockDifference = OPTIONS[currentOption].selectionStartAnimationTime - (currentClock - selectedUnits[teamID][unitID].new)
				if clockDifference < 0 then
					clockDifference = 0
				end
				selectedUnits[teamID][unitID].selected = false
				selectedUnits[teamID][unitID].new = false
				selectedUnits[teamID][unitID].old = currentClock - clockDifference
			end
			selectedUnits[teamID][unitID].visible = spIsUnitVisible(unitID)

			-- check if isnt visible
			if not spIsUnitVisible(unitID) then
				selectedUnitsInvisible[unitID] = selectedUnits[teamID][unitID]
				selectedUnitsInvisible[unitID].teamID = teamID
				selectedUnits[teamID][unitID] = nil
			else
				-- logs current unit direction	(needs regular updates for air units, and for buildings only once)	for teamID,_ in pairs(perfSelectedUnits) do
				local dirx, _, dirz = spGetUnitDirection(unitID)
				if (dirz ~= nil) then
					degrot[unitID] = 180 - math_acos(dirz) * rad_con
					if dirx < 0 then
						degrot[unitID] = 180 - math_acos(dirz) * rad_con
					else
						degrot[unitID] = 180 + math_acos(dirz) * rad_con
					end
				end
			end
		end
	end

	-- add selected units
	if checkSelectionChanges and spGetSelectedUnitsCount() > 0 then
		checkSelectionChanges = false
		local units = spGetSelectedUnitsSorted()
		local clockDifference, unitID, teamID
		for uDID,_ in pairs(units) do
			if uDID ~= 'n' then --'n' returns table size
				for i=1, #units[uDID] do
					unitID = units[uDID][i]
					if (UNITCONF[uDID]) then
						teamID = spGetUnitTeam(unitID)
						if teamID then
							if not selectedUnits[teamID] then
								selectedUnits[teamID] = {}
							end
							if not selectedUnitsInvisible[unitID] then
								if not selectedUnits[teamID][unitID] then
									selectedUnits[teamID][unitID] = {}
									selectedUnits[teamID][unitID].new = currentClock
								elseif selectedUnits[teamID][unitID].old then
									clockDifference = OPTIONS[currentOption].selectionEndAnimationTime - (currentClock - selectedUnits[teamID][unitID].old)
									if clockDifference < 0 then
										clockDifference = 0
									end
									selectedUnits[teamID][unitID].new = currentClock - clockDifference
									selectedUnits[teamID][unitID].old = nil
								end
								selectedUnits[teamID][unitID].selected = true
								selectedUnits[teamID][unitID].udid = spGetUnitDefID(unitID)
								selectedUnits[teamID][unitID].visible = spIsUnitVisible(unitID)
							end
						end
					end
				end
			end
		end
	end

	-- creates has blinking problem
	--[[ create new table that has iterative keys instead of unitID (to speedup after about 300 different units have ever been selected)
	perfSelectedUnits = {}
	for teamID,_ in pairs(selectedUnits) do
		perfSelectedUnits[teamID] = {}
		for unitID,_ in pairs(selectedUnits[teamID]) do
			table.insert(perfSelectedUnits[teamID], unitID)
		end
		perfSelectedUnits[teamID]['totalUnits'] = table.getn(perfSelectedUnits[teamID])
	end
	]]--
end


function widget:Update()
	currentClock = os.clock()
	maxSelectTime = currentClock - OPTIONS[currentOption].selectionStartAnimationTime
	maxDeselectedTime = currentClock - OPTIONS[currentOption].selectionEndAnimationTime

	updateSelectedUnitsData()
end


do
	local unitID, unit, draw, unitPosX, unitPosY, unitPosZ, changedScale, usedAlpha, usedScale, usedXScale, usedZScale, usedRotationAngle
	local health,maxHealth,paralyzeDamage,captureProgress,buildProgress

	function DrawSelectionSpottersPart(teamID, type, r,g,b,a,scale, opposite, relativeScaleSchrinking, changeOpacity, drawUnitStyles)

		local OPTIONScurrentOption = OPTIONS[currentOption]

		--for unitKey=1, perfSelectedUnits[teamID]['totalUnits'] do
		--	unitID = perfSelectedUnits[teamID][unitKey]
		for unitID,unitParams in pairs(selectedUnits[teamID]) do

			unit = UNITCONF[unitParams.udid]
			if (unit) then

				changedScale = 1
				usedAlpha = a

				if (OPTIONScurrentOption.selectionEndAnimation  or  OPTIONScurrentOption.selectionStartAnimation) then
					if changeOpacity then
						gl.Color(r,g,b,a)
					end
					-- check if the unit is deselected
					if (OPTIONScurrentOption.selectionEndAnimation and not unitParams.selected) then
						if (maxDeselectedTime < unitParams.old) then
							changedScale = OPTIONScurrentOption.selectionEndAnimationScale + (((unitParams.old - maxDeselectedTime) / OPTIONScurrentOption.selectionEndAnimationTime)) * (1 - OPTIONScurrentOption.selectionEndAnimationScale)
							if (changeOpacity) then
								usedAlpha = 1 - (((unitParams.old - maxDeselectedTime) / OPTIONScurrentOption.selectionEndAnimationTime) * (1-a))
								gl.Color(r,g,b,usedAlpha)
							end
						else
							selectedUnits[teamID][unitID] = nil
							degrot[unitID] = nil
						end

					-- check if the unit is newly selected
					elseif (OPTIONScurrentOption.selectionStartAnimation and unitParams.new > maxSelectTime) then
						--spEcho(unitParams.new - maxSelectTime)
						changedScale = OPTIONScurrentOption.selectionStartAnimationScale + (((currentClock - unitParams.new) / OPTIONScurrentOption.selectionStartAnimationTime)) * (1 - OPTIONScurrentOption.selectionStartAnimationScale)
						if (changeOpacity) then
							usedAlpha = 1 - (((currentClock - unitParams.new) / OPTIONScurrentOption.selectionStartAnimationTime) * (1-a))
							gl.Color(r,g,b,usedAlpha)
						end
					end
				end

				if selectedUnits[teamID][unitID] and unitParams.visible then
					usedRotationAngle = GetUsedRotationAngle(unitID, unit.shapeName, opposite)

					if type == 'normal solid'  or  type == 'normal alpha' then

						-- special style for coms
						if drawUnitStyles and OPTIONScurrentOption.showExtraComLine and (unit.name == 'corcom'  or  unit.name == 'armcom'  or  unit.name == 'corcom_bar'  or  unit.name == 'armcom_bar') then
							gl.Color(r,g,b,(usedAlpha*usedAlpha)+0.22)
							usedScale = scale * 1.25
							glDrawListAtUnit(unitID, unit.shape.inner, false, (unit.xscale*usedScale*changedScale)-((unit.xscale*changedScale-10)/10), 1.0, (unit.zscale*usedScale*changedScale)-((unit.zscale*changedScale-10)/10), currentRotationAngleOpposite, 0, degrot[unitID], 0)
							usedScale = scale * 1.23
							gl.Color(r,g,b,(usedAlpha*usedAlpha)+0.08)
							glDrawListAtUnit(unitID, unit.shape.large, false, (unit.xscale*usedScale*changedScale)-((unit.xscale*changedScale-10)/10), 1.0, (unit.zscale*usedScale*changedScale)-((unit.zscale*changedScale-10)/10), 0, 0, degrot[unitID], 0)
						else
							-- adding style for buildings with weapons
							if drawUnitStyles and OPTIONScurrentOption.showExtraBuildingWeaponLine and unit.shapeName == 'square' then
								if (unit.weaponcount > 0) then
									gl.Color(r,g,b,usedAlpha*(usedAlpha+0.2))
									usedScale = scale * 1.1
									glDrawListAtUnit(unitID, unit.shape.select, false, (unit.xscale*usedScale*changedScale)-((unit.xscale*changedScale-10)/7.5), 1.0, (unit.zscale*usedScale*changedScale)-((unit.zscale*changedScale-10)/7.5), usedRotationAngle, 0, degrot[unitID], 0)
								end
								gl.Color(r,g,b,usedAlpha)
							end

							if relativeScaleSchrinking then
								glDrawListAtUnit(unitID, unit.shape.select, false, (unit.xscale*scale*changedScale)-((unit.xscale*changedScale-5)/10), 1.0, (unit.zscale*scale*changedScale)-((unit.zscale*changedScale-5)/10), usedRotationAngle, 0, degrot[unitID], 0)
							else
								glDrawListAtUnit(unitID, unit.shape.select, false, unit.xscale*scale*changedScale, 1.0, unit.zscale*scale*changedScale, usedRotationAngle, 0, degrot[unitID], 0)
							end
						end

					elseif type == 'solid overlap' then

						if relativeScaleSchrinking then
							glDrawListAtUnit(unitID, unit.shape.large, false, (unit.xscale*scale*changedScale)-((unit.xscale*changedScale-5)/50), 1.0, (unit.zscale*scale*changedScale)-((unit.zscale*changedScale-5)/50), usedRotationAngle, 0, degrot[unitID], 0)
						else
							glDrawListAtUnit(unitID, unit.shape.large, false, (unit.xscale*scale*changedScale)+((unit.xscale-15)/15), 1.0, (unit.zscale*scale*changedScale)+((unit.zscale-15)/15), usedRotationAngle, 0, degrot[unitID], 0)
						end

					elseif type == 'base solid'  or  type == 'base alpha' then
						usedXScale = unit.xscale
						usedZScale = unit.zscale
						if OPTIONScurrentOption.showExtraComLine and (unit.name == 'corcom'  or  unit.name == 'armcom') then
							usedXScale = usedXScale * 1.23
							usedZScale = usedZScale * 1.23
						elseif OPTIONScurrentOption.showExtraBuildingWeaponLine and unit.shapeName == 'square' then
							if (unit.weaponcount > 0) then
								usedXScale = usedXScale * 1.14
								usedZScale = usedZScale * 1.14
							end
						end
						glDrawListAtUnit(unitID, unit.shape.large, false, (usedXScale*scale*changedScale)-((usedXScale*changedScale-10)/10), 1.0, (usedZScale*scale*changedScale)-((usedZScale*changedScale-10)/10), usedRotationAngle, 0, degrot[unitID], 0)
					end
				end
			end
		end
	end
end --// end do


function widget:DrawWorldPreUnit()
	if spIsGUIHidden() then return end

	local clockDifference = (os.clock() - previousOsClock)
	previousOsClock = os.clock()

	-- animate rotation
	if OPTIONS[currentOption].rotationSpeed > 0 then
		local angleDifference = (OPTIONS[currentOption].rotationSpeed) * (clockDifference * 5)
		currentRotationAngle = currentRotationAngle + (angleDifference*0.66)
		if currentRotationAngle > 360 then
		   currentRotationAngle = currentRotationAngle - 360
		end

		currentRotationAngleOpposite = currentRotationAngleOpposite - angleDifference
		if currentRotationAngleOpposite < -360 then
		   currentRotationAngleOpposite = currentRotationAngleOpposite + 360
		end
	end

	-- animate scale
	if OPTIONS[currentOption].animateSpotterSize then
		local addedMultiplierValue = OPTIONS[currentOption].animationSpeed * (clockDifference * 50)
		if (animationMultiplierAdd  and  animationMultiplier < OPTIONS[currentOption].maxAnimationMultiplier) then
			animationMultiplier = animationMultiplier + addedMultiplierValue
			animationMultiplierInner = animationMultiplierInner - addedMultiplierValue
			if (animationMultiplier > OPTIONS[currentOption].maxAnimationMultiplier) then
				animationMultiplier = OPTIONS[currentOption].maxAnimationMultiplier
				animationMultiplierInner = OPTIONS[currentOption].minAnimationMultiplier
				animationMultiplierAdd = false
			end
		else
			animationMultiplier = animationMultiplier - addedMultiplierValue
			animationMultiplierInner = animationMultiplierInner + addedMultiplierValue
			if (animationMultiplier < OPTIONS[currentOption].minAnimationMultiplier) then
				animationMultiplier = OPTIONS[currentOption].minAnimationMultiplier
				animationMultiplierInner = OPTIONS[currentOption].maxAnimationMultiplier
				animationMultiplierAdd = true
			end
		end
	end


	local baseR, baseG, baseB, a, scale, scaleBase, scaleOuter
	scale = 1 * OPTIONS[currentOption].scaleMultiplier * animationMultiplierInner
	scaleBase = scale * 1.133
	if OPTIONS[currentOption].showSecondLine then
		scaleOuter = (1 * OPTIONS[currentOption].scaleMultiplier * animationMultiplier) * 1.16
		scaleBase = scaleOuter * 1.08
	end

	gl.PushAttrib(GL.COLOR_BUFFER_BIT)
	gl.DepthTest(false)

	-- loop teams
	for teamID,_ in pairs(selectedUnits) do

		gl.ColorMask(false, false, false, true)
		gl.BlendFunc(GL.ONE, GL.ONE)
		gl.Color(1,1,1,1)
		glCallList(clearquad)

		-- draw base background layer
		if OPTIONS[currentOption].showBase and OPTIONS[currentOption].baseOpacity > 0.009 then
			if OPTIONS[currentOption].teamcolorOpacity < 0.02 then
				baseR,baseG,baseB = 1,1,1
			else
				baseR,baseG,baseB = spGetTeamColor(teamID)
				baseR = 1-OPTIONS[currentOption].teamcolorOpacity + (baseR*OPTIONS[currentOption].teamcolorOpacity)
				baseG = 1-OPTIONS[currentOption].teamcolorOpacity + (baseG*OPTIONS[currentOption].teamcolorOpacity)
				baseB = 1-OPTIONS[currentOption].teamcolorOpacity + (baseB*OPTIONS[currentOption].teamcolorOpacity)
			end

			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			DrawSelectionSpottersPart(teamID, 'base solid', baseR,baseG,baseB,0,scaleBase, false, false, false, false)

			--  Here the inner of the selected spotters are removed
			gl.BlendFunc(GL.ONE, GL.ZERO)
			a = 1 - (OPTIONS[currentOption].baseOpacity)
			DrawSelectionSpottersPart(teamID, 'base alpha', baseR,baseG,baseB,a,scaleBase, false, false, true, false)

			--  Really draw the spotters now  (This could be optimised if we could say Draw as much as DST_ALPHA * SRC_ALPHA is)
			-- (without protecting form drawing them twice)
			gl.ColorMask(true,true,true,true)
			gl.BlendFunc(GL.ONE_MINUS_DST_ALPHA, GL.DST_ALPHA)
			glCallList(clearquad)
		end


		-- draw 1st line layer
		if OPTIONS[currentOption].showFirstLine then
			a = 1 - (OPTIONS[currentOption].firstLineOpacity * OPTIONS[currentOption].spotterOpacity)

			gl.ColorMask(false, false, false, true)
			gl.BlendFunc(GL.ONE_MINUS_SRC_ALPHA, GL.SRC_ALPHA)
			if OPTIONS[currentOption].showFirstLineDetails then
				if OPTIONS[currentOption].showNoOverlap then
					-- draw normal spotters solid
					gl.Color(1,1,1,0)
					DrawSelectionSpottersPart(teamID, 'normal solid', 1,1,1,a,scale, false, false, false, false)

					--  Here the spotters are given the alpha level (this step makes sure overlappings dont have different alpha level)
					gl.BlendFunc(GL.ONE, GL.ZERO)
				end
				gl.Color(1,1,1,a)
				DrawSelectionSpottersPart(teamID, 'normal alpha', 1,1,1,a,scale, false, false, true, false)
			end

			--  Here the inner of the selected spotters are removed
			gl.BlendFunc(GL.ONE, GL.ZERO)
			gl.Color(1,1,1,1)
			DrawSelectionSpottersPart(teamID, 'solid overlap', 1,1,1,a,scale, opposite, relativeScaleSchrinking, false, drawUnitStyles)

			--  Really draw the spotters now  (This could be optimised if we could say Draw as much as DST_ALPHA * SRC_ALPHA is)
			-- (without protecting form drawing them twice)
			gl.ColorMask(true, true, true, true)
			gl.BlendFunc(GL.ONE_MINUS_DST_ALPHA, GL.DST_ALPHA)

			-- Does not need to be drawn per Unit anymore
			glCallList(clearquad)
		end


		-- draw 2nd line layer
--		if OPTIONS[currentOption].showSecondLine then
--			--a = 1 - (OPTIONS[currentOption].secondLineOpacity * OPTIONS[currentOption].spotterOpacity)
--
--			gl.ColorMask(false, false, false, true)
--			--gl.BlendFunc(GL.ONE_MINUS_SRC_ALPHA, GL.SRC_ALPHA)
--
--			--  Here the inner of the selected spotters are removed
--			gl.BlendFunc(GL.ONE, GL.ZERO)
--			gl.Color(1,1,1,1)
--			DrawSelectionSpottersPart(teamID, 'solid overlap', 1,1,1,a,scaleOuter, false, true, false, true)
--
--			--  Really draw the spotters now  (This could be optimised if we could say Draw as much as DST_ALPHA * SRC_ALPHA is)
--			-- (without protecting form drawing them twice)
--			gl.ColorMask(true, true, true, true)
--			gl.BlendFunc(GL.ONE_MINUS_DST_ALPHA, GL.DST_ALPHA)
--
--			-- Does not need to be drawn per Unit anymore
--			glCallList(clearquad)
--		end
	end

	gl.ColorMask(false,false,false,false)
	gl.Color(1,1,1,1)
	gl.PopAttrib()
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Config related

function widget:GetConfigData(data)
    savedTable = {}
    savedTable.currentOption					= currentOption
	savedTable.spotterOpacity					= OPTIONS.defaults.spotterOpacity
	savedTable.baseOpacity						= OPTIONS.defaults.baseOpacity
	savedTable.teamcolorOpacity					= OPTIONS.defaults.teamcolorOpacity
	savedTable.showSecondLine					= OPTIONS.defaults.showSecondLine

    return savedTable
end

function widget:SetConfigData(data)
    currentOption								= data.currentOption			or currentOption
	OPTIONS.defaults.spotterOpacity				= data.spotterOpacity			or OPTIONS.defaults.spotterOpacity
	OPTIONS.defaults.baseOpacity				= data.baseOpacity				or OPTIONS.defaults.baseOpacity
	OPTIONS.defaults.teamcolorOpacity			= data.teamcolorOpacity			or OPTIONS.defaults.teamcolorOpacity
	OPTIONS.defaults.showSecondLine				= data.showSecondLine			or OPTIONS.defaults.showSecondLine
end

