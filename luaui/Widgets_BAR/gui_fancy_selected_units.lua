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
local selectedUnitsInvisible		= {}

local maxSelectTime					= 0				--time at which units "new selection" animation will end
local maxDeselectedTime				= -1			--time at which units deselection animation will end

local checkSelectionChanges			= true
local limitDetails					= false

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

local OPTIONS = {	-- these will be loaded when switching style, but the style will overwrite the those values
	showExtraComLine				= true,		-- extra circle lines for the commander unit
	showExtraBuildingWeaponLine		= true,

	teamcolorOpacity				= 0.55,		-- how much teamcolor used for the base platter

	-- opacity
	spotterOpacity					= 0.95,
	baseOpacity						= 0.15,		-- setting to 0: wont be rendered
	firstLineOpacity				= 1,

	-- animation
	selectionStartAnimation			= true,
	selectionStartAnimationTime		= 0.05,
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
	circlePieces					= 64,
	circlePieceDetail				= 1,
	circleSpaceUsage				= 1,
	circleInnerOffset				= 0,

	-- size
	innersize						= 1.7,
	selectinner						= 1.66,
	outersize						= 1.8,
}

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

	displayLists.select = callback.fading(OPTIONS.outersize, OPTIONS.selectinner)
	displayLists.inner = callback.solid({0, 0, 0, 0}, OPTIONS.innersize)
	displayLists.large = callback.solid(nil, OPTIONS.selectinner)
	displayLists.shape = callback.fading(OPTIONS.innersize, OPTIONS.selectinner)

	return displayLists
end



local function DrawCircleLine(innersize, outersize)
	gl.BeginEnd(GL.QUADS, function()
		local detailPartWidth, a1,a2,a3,a4
		local width = OPTIONS.circleSpaceUsage
		local detail = OPTIONS.circlePieceDetail

		local radstep = (2.0 * math.pi) / OPTIONS.circlePieces
		for i = 1, OPTIONS.circlePieces do
			for d = 1, detail do

				detailPartWidth = ((width / detail) * d)
				a1 = ((i+detailPartWidth - (width / detail)) * radstep)
				a2 = ((i+detailPartWidth) * radstep)
				a3 = ((i+OPTIONS.circleInnerOffset+detailPartWidth - (width / detail)) * radstep)
				a4 = ((i+OPTIONS.circleInnerOffset+detailPartWidth) * radstep)

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
		local pieces = OPTIONS.solidCirclePieces
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
		return OPTIONS.spotterOpacity
	end
	WG['fancyselectedunits'].setOpacity = function(value)
		OPTIONS.spotterOpacity = value
		OPTIONS.spotterOpacity = value
	end
	WG['fancyselectedunits'].getBaseOpacity = function()
		return OPTIONS.baseOpacity
	end
	WG['fancyselectedunits'].setBaseOpacity = function(value)
		OPTIONS.baseOpacity = value
		OPTIONS.baseOpacity = value
	end
	WG['fancyselectedunits'].getTeamcolorOpacity = function()
		return OPTIONS.teamcolorOpacity
	end
	WG['fancyselectedunits'].setTeamcolorOpacity = function(value)
		OPTIONS.teamcolorOpacity = value
		OPTIONS.teamcolorOpacity = value
	end

	SetupCommandColors(false)
end


function loadConfig()

	CreateCircleLists()
	CreateSquareLists()
	CreateTriangleLists()

	SetUnitConf()
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


local selectedUnitsSorted = Spring.GetSelectedUnitsSorted()
local selectedUnitsCount = Spring.GetSelectedUnitsCount()
function widget:SelectionChanged(sel)
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
	local visibleUnitCount = 0
	for teamID,_ in pairs(selectedUnits) do
		for unitID,_ in pairs(selectedUnits[teamID]) do

			-- remove deselected units
			if not spIsUnitSelected(unitID) and selectedUnits[teamID][unitID].selected then
				clockDifference = OPTIONS.selectionStartAnimationTime - (currentClock - selectedUnits[teamID][unitID].new)
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
				visibleUnitCount = visibleUnitCount + 1
				-- logs current unit direction	(needs regular updates for air units, and for buildings only once)
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
	if selectedUnitsCount > 0 then
		local units = selectedUnitsSorted
		local clockDifference, unitID, teamID
		for uDID,_ in pairs(units) do
			if uDID ~= 'n' then --'n' returns table size
				for i=1, #units[uDID] do
					unitID = units[uDID][i]
					if UNITCONF[uDID] then
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
									clockDifference = OPTIONS.selectionEndAnimationTime - (currentClock - selectedUnits[teamID][unitID].old)
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
end

local selChangedSec = 0
function widget:Update(dt)
	currentClock = os.clock()
	maxSelectTime = currentClock - OPTIONS.selectionStartAnimationTime
	maxDeselectedTime = currentClock - OPTIONS.selectionEndAnimationTime

	selChangedSec = selChangedSec + dt
	if checkSelectionChanges and selChangedSec >= 0.05 then
		selChangedSec = 0
		selectedUnitsSorted = Spring.GetSelectedUnitsSorted()
		selectedUnitsCount = Spring.GetSelectedUnitsCount()
		updateSelectedUnitsData()
		checkSelectionChanges = false
	end
end


do
	local unitID, unit, draw, unitPosX, unitPosY, unitPosZ, changedScale, usedAlpha, usedScale, usedXScale, usedZScale, usedRotationAngle
	local health,maxHealth,paralyzeDamage,captureProgress,buildProgress

	function DrawSelectionSpottersPart(teamID, type, r,g,b,a,scale, opposite, relativeScaleSchrinking, changeOpacity, drawUnitStyles)

		for unitID,unitParams in pairs(selectedUnits[teamID]) do

			unit = UNITCONF[unitParams.udid]
			changedScale = 1
			usedAlpha = a

			if (OPTIONS.selectionEndAnimation  or  OPTIONS.selectionStartAnimation) then
				if changeOpacity then
					gl.Color(r,g,b,a)
				end
				-- check if the unit is deselected
				if (OPTIONS.selectionEndAnimation and not unitParams.selected) then
					if (maxDeselectedTime < unitParams.old) then
						changedScale = OPTIONS.selectionEndAnimationScale + (((unitParams.old - maxDeselectedTime) / OPTIONS.selectionEndAnimationTime)) * (1 - OPTIONS.selectionEndAnimationScale)
						if (changeOpacity) then
							usedAlpha = 1 - (((unitParams.old - maxDeselectedTime) / OPTIONS.selectionEndAnimationTime) * (1-a))
							gl.Color(r,g,b,usedAlpha)
						end
					else
						selectedUnits[teamID][unitID] = nil
						degrot[unitID] = nil
					end

				-- check if the unit is newly selected
				elseif (OPTIONS.selectionStartAnimation and unitParams.new > maxSelectTime) then
					--spEcho(unitParams.new - maxSelectTime)
					changedScale = OPTIONS.selectionStartAnimationScale + (((currentClock - unitParams.new) / OPTIONS.selectionStartAnimationTime)) * (1 - OPTIONS.selectionStartAnimationScale)
					if (changeOpacity) then
						usedAlpha = 1 - (((currentClock - unitParams.new) / OPTIONS.selectionStartAnimationTime) * (1-a))
						gl.Color(r,g,b,usedAlpha)
					end
					if not degrot[unitID] then
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

			if selectedUnits[teamID][unitID] and unitParams.visible then
				usedRotationAngle = GetUsedRotationAngle(unitID, unit.shapeName, opposite)

				if type == 'normal solid' then

					-- special style for coms
					if drawUnitStyles and OPTIONS.showExtraComLine and (unit.name == 'corcom'  or  unit.name == 'armcom') then
						gl.Color(r,g,b,(usedAlpha*usedAlpha)+0.22)
						usedScale = scale * 1.25
						glDrawListAtUnit(unitID, unit.shape.inner, false, (unit.xscale*usedScale*changedScale)-((unit.xscale*changedScale-10)/10), 1.0, (unit.zscale*usedScale*changedScale)-((unit.zscale*changedScale-10)/10), currentRotationAngleOpposite, 0, degrot[unitID], 0)
						usedScale = scale * 1.23
						gl.Color(r,g,b,(usedAlpha*usedAlpha)+0.08)
						glDrawListAtUnit(unitID, unit.shape.large, false, (unit.xscale*usedScale*changedScale)-((unit.xscale*changedScale-10)/10), 1.0, (unit.zscale*usedScale*changedScale)-((unit.zscale*changedScale-10)/10), 0, 0, degrot[unitID], 0)
					else
						-- adding style for buildings with weapons
						if drawUnitStyles and OPTIONS.showExtraBuildingWeaponLine and unit.shapeName == 'square' then
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

				elseif type == 'base' then
					usedXScale = unit.xscale
					usedZScale = unit.zscale
					if OPTIONS.showExtraComLine and (unit.name == 'corcom'  or  unit.name == 'armcom') then
						usedXScale = usedXScale * 1.23
						usedZScale = usedZScale * 1.23
					elseif OPTIONS.showExtraBuildingWeaponLine and unit.shapeName == 'square' then
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
end --// end do


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorldPreUnit()
	if chobbyInterface then return end
	if spIsGUIHidden() then return end

	local clockDifference = (os.clock() - previousOsClock)
	previousOsClock = os.clock()

	-- animate rotation
	if OPTIONS.rotationSpeed > 0 then
		local angleDifference = (OPTIONS.rotationSpeed) * (clockDifference * 5)
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
	if OPTIONS.animateSpotterSize then
		local addedMultiplierValue = OPTIONS.animationSpeed * (clockDifference * 50)
		if (animationMultiplierAdd  and  animationMultiplier < OPTIONS.maxAnimationMultiplier) then
			animationMultiplier = animationMultiplier + addedMultiplierValue
			animationMultiplierInner = animationMultiplierInner - addedMultiplierValue
			if (animationMultiplier > OPTIONS.maxAnimationMultiplier) then
				animationMultiplier = OPTIONS.maxAnimationMultiplier
				animationMultiplierInner = OPTIONS.minAnimationMultiplier
				animationMultiplierAdd = false
			end
		else
			animationMultiplier = animationMultiplier - addedMultiplierValue
			animationMultiplierInner = animationMultiplierInner + addedMultiplierValue
			if (animationMultiplier < OPTIONS.minAnimationMultiplier) then
				animationMultiplier = OPTIONS.minAnimationMultiplier
				animationMultiplierInner = OPTIONS.maxAnimationMultiplier
				animationMultiplierAdd = true
			end
		end
	end


	local baseR, baseG, baseB, a, scale, scaleBase, scaleOuter
	scale = 1 * animationMultiplierInner
	scaleBase = scale * 1.133

	gl.PushAttrib(GL.COLOR_BUFFER_BIT)
	gl.DepthTest(false)

	-- loop teams
	for teamID,_ in pairs(selectedUnits) do

		gl.ColorMask(false, false, false, true)
		gl.BlendFunc(GL.ONE, GL.ONE)
		gl.Color(1,1,1,1)
		glCallList(clearquad)

		-- draw base background layer
		if OPTIONS.baseOpacity > 0.009 then
			if OPTIONS.teamcolorOpacity < 0.02 then
				baseR,baseG,baseB = 1,1,1
			else
				baseR,baseG,baseB = spGetTeamColor(teamID)
				baseR = 1-OPTIONS.teamcolorOpacity + (baseR*OPTIONS.teamcolorOpacity)
				baseG = 1-OPTIONS.teamcolorOpacity + (baseG*OPTIONS.teamcolorOpacity)
				baseB = 1-OPTIONS.teamcolorOpacity + (baseB*OPTIONS.teamcolorOpacity)
			end

			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			DrawSelectionSpottersPart(teamID, 'base', baseR,baseG,baseB,0,scaleBase, false, false, false, false)

			--  Here the inner of the selected spotters are removed
			gl.BlendFunc(GL.ONE, GL.ZERO)
			a = 1 - (OPTIONS.baseOpacity)
			DrawSelectionSpottersPart(teamID, 'base', baseR,baseG,baseB,a,scaleBase, false, false, true, false)

			--  Really draw the spotters now  (This could be optimised if we could say Draw as much as DST_ALPHA * SRC_ALPHA is)
			-- (without protecting form drawing them twice)
			gl.ColorMask(true,true,true,true)
			gl.BlendFunc(GL.ONE_MINUS_DST_ALPHA, GL.DST_ALPHA)
			glCallList(clearquad)
		end

		-- draw line layer
		a = 1 - (OPTIONS.firstLineOpacity * OPTIONS.spotterOpacity)

		gl.ColorMask(false, false, false, true)
		gl.BlendFunc(GL.ONE_MINUS_SRC_ALPHA, GL.SRC_ALPHA)

		gl.Color(1,1,1,a)
		DrawSelectionSpottersPart(teamID, 'normal solid', 1,1,1,a,scale, false, false, true, false)

		--  Here the inner of the selected spotters are removed
		gl.BlendFunc(GL.ONE, GL.ZERO)
		gl.Color(1,1,1,1)
		DrawSelectionSpottersPart(teamID, 'solid overlap', 1,1,1,a,scale, false, false, false, false)

		--  Really draw the spotters now  (This could be optimised if we could say Draw as much as DST_ALPHA * SRC_ALPHA is)
		-- (without protecting form drawing them twice)
		gl.ColorMask(true, true, true, true)
		gl.BlendFunc(GL.ONE_MINUS_DST_ALPHA, GL.DST_ALPHA)

		-- Does not need to be drawn per Unit anymore
		glCallList(clearquad)
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
	savedTable.spotterOpacity					= OPTIONS.spotterOpacity
	savedTable.baseOpacity						= OPTIONS.baseOpacity
	savedTable.teamcolorOpacity					= OPTIONS.teamcolorOpacity

    return savedTable
end

function widget:SetConfigData(data)
	OPTIONS.spotterOpacity				= data.spotterOpacity			or OPTIONS.spotterOpacity
	OPTIONS.baseOpacity				= data.baseOpacity				or OPTIONS.baseOpacity
	OPTIONS.teamcolorOpacity			= data.teamcolorOpacity			or OPTIONS.teamcolorOpacity
end

