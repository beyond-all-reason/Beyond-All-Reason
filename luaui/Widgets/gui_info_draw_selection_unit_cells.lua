function widget:GetInfo()
	return {
		name = "Info Draw Selection Unit Cells",
		desc = "Adds a unit selection info panel showing each individual unit, aggregating units by type with full health or moderate health if there are too many to show.",
		author = "Sparr",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local math_min, math_max, math_floor, math_ceil = math.min, math.max, math.floor, math.ceil
local math_isInRect = math.isInRect
local spGetUnitHealth = Spring.GetUnitHealth
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetModKeyState = Spring.GetModKeyState
local glColor, glRect, glVertex, glBeginEnd, glBlending = gl.Color, gl.Rect, gl.Vertex, gl.BeginEnd, gl.Blending
local GL_TRIANGLE_FAN, GL_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA =
	GL.TRIANGLE_FAN, GL.SRC_ALPHA, GL.ONE, GL.ONE_MINUS_SRC_ALPHA

local tooltipTextColor = "\255\255\255\255"
local tooltipLabelTextColor = "\255\205\205\205"

-- shown while hovering a cell holding one unit
local selectionHowtoUnit = tooltipTextColor
	.. "Left click"
	.. tooltipLabelTextColor
	.. ": Select this unit"
	.. "\n"
	.. tooltipTextColor
	.. "    + CTRL"
	.. tooltipLabelTextColor
	.. ": Select units of this type on map"
	.. "\n"
	.. tooltipTextColor
	.. "Right click"
	.. tooltipLabelTextColor
	.. ": Remove this unit from the selection"
	.. "\n"
	.. tooltipTextColor
	.. "Middle click"
	.. tooltipLabelTextColor
	.. ": Move to this unit"
	.. "\n"
	.. tooltipTextColor
	.. "    + CTRL"
	.. tooltipLabelTextColor
	.. ": Move to center off whole selection"

-- shown for a row button whose row holds several unit types, leaving the by type actions out
local selectionHowtoRow = tooltipTextColor
	.. "Left click"
	.. tooltipLabelTextColor
	.. ": Select\n "
	.. tooltipTextColor
	.. "   + ALT"
	.. tooltipLabelTextColor
	.. ": Select 1 single unit\n "
	.. tooltipTextColor
	.. "Right click"
	.. tooltipLabelTextColor
	.. ": Remove\n "
	.. tooltipTextColor
	.. "    + CTRL"
	.. tooltipLabelTextColor
	.. ": Remove only 1 unit\n "
	.. tooltipTextColor
	.. "Middle click"
	.. tooltipLabelTextColor
	.. ": Move to center location\n "
	.. tooltipTextColor
	.. "    + CTRL"
	.. tooltipLabelTextColor
	.. ": Move to center off whole selection"

-- shown for a cell aggregating several units of one type, or a row button whose row holds only one
local selectionHowtoType = tooltipTextColor
	.. "Left click"
	.. tooltipLabelTextColor
	.. ": Select\n "
	.. tooltipTextColor
	.. "   + CTRL"
	.. tooltipLabelTextColor
	.. ": Select units of this type on map\n "
	.. tooltipTextColor
	.. "   + ALT"
	.. tooltipLabelTextColor
	.. ": Select 1 single unit of this unit type\n "
	.. tooltipTextColor
	.. "Right click"
	.. tooltipLabelTextColor
	.. ": Remove\n "
	.. tooltipTextColor
	.. "    + CTRL"
	.. tooltipLabelTextColor
	.. ": Remove only 1 unit from that unit type\n "
	.. tooltipTextColor
	.. "Middle click"
	.. tooltipLabelTextColor
	.. ": Move to center location\n "
	.. tooltipTextColor
	.. "    + CTRL"
	.. tooltipLabelTextColor
	.. ": Move to center off whole selection"

local zoomMult = 1.5
local hoverCellZoom = 0.03 * zoomMult
local clickCellZoom = 0.065 * zoomMult
local rightclickCellZoom = 0.065 * zoomMult
local maxUnitCellRows = 4 -- keeps the per unit icons from getting too small to recognize

-- every row is preceded by a half hexagon button acting on the whole row, half a cell wide
local rowButtonColor, rowButtonCenterColor = { 0, 0, 0, 0.7 }, { 0.13, 0.13, 0.13, 0.7 }
local rowButtonWidth = 0.5
-- unit offsets of its corners, from the top of the flat side counterclockwise to its bottom
local rowButtonCorners = {}
for i = 0, 3 do
	local angle = (math.pi * 0.5) + (i * (math.pi / 3))
	rowButtonCorners[i + 1] = { math.cos(angle), math.sin(angle) }
end

---A cell to the unit it shows, or false where it stands for several of them.
---@class UnitCellSlotMap
---@field [integer] integer|false

---A unit to its UnitDef.
---@class UnitCellUnitDefMap
---@field [integer] integer

---A UnitDef to a tally of its units.
---@class UnitCellCountMap
---@field [integer] integer

---A unit or UnitDef to a health fraction.
---@class UnitCellHealthMap
---@field [integer] number

---Where a row button sits, and which cells it acts on.
---@class RowButtonRect
---@field [1] number Left.
---@field [2] number Bottom.
---@field [3] number Right.
---@field [4] number Top.
---@field [5] integer First cell of the row it acts on.
---@field [6] integer Last cell of that row.

---How the cells are handed out between the units of the selection.
---@class UnitCellGrid
---@field fullCells integer Cells 1 to this one aggregate the units at full health, one per type.
---@field remainderFirst integer First of the cells aggregating what didn't fit, one per type.
---@field remainderLast integer Last of them; below `remainderFirst` when there are none.
---@field bandFirst integer First of the damagedUnits those cells stand for.
---@field bandLast integer Last of them.
---@field cellUnits UnitCellSlotMap Cell to the unit it shows, false when it aggregates.
---@field damagedUnits integer[] Every unit below full health, healthiest first.
---@field unitType UnitCellUnitDefMap unitID to unitDefID.
---@field fullTypes integer[] Unit types with units at full health, in cell order.
---@field fullCount UnitCellCountMap unitDefID to how many of its units are at full health.
---@field remainderTypes integer[] Unit types with units left over, in cell order.
---@field remainderCount UnitCellCountMap unitDefID to how many of its units are left over.
---@field remainderHealth UnitCellHealthMap unitDefID to their average health fraction.
---@field rowRect RowButtonRect[] One button per row of cells.

---@type UnitCellGrid
-- the units at full health are aggregated per type at the top, the healthiest and the most damaged
-- get a cell of their own, and what is left over is aggregated per type in the middle
local grid = {
	fullCells = 0, -- cells 1 to this one aggregate the units at full health, one per unit type
	remainderFirst = 0, -- the cells in this range aggregate what didn't fit, one per unit type
	remainderLast = -1,
	bandFirst = 0, -- the damagedUnits those cells stand for
	bandLast = -1,
	cellUnits = {}, -- cell -> the unit it shows, false when it aggregates several
	damagedUnits = {}, -- every unit below full health, healthiest first
	unitType = {}, -- unitID -> unitDefID
	fullTypes = {}, -- unit types with units at full health, in cell order
	fullCount = {}, -- unitDefID -> how many of its units are at full health
	remainderTypes = {}, -- unit types with units left over, in cell order
	remainderCount = {}, -- unitDefID -> how many of its units are left over
	remainderHealth = {}, -- unitDefID -> their average health fraction
	rowRect = {}, -- one button per row of cells
}
---@class UnitCellDefMap cell -> the unit type it shows
---@field [integer] integer
local cellDefID = {}
---@class UnitCellRectMap cell -> its corners
---@field [integer] InfoRect
local cellRect = {}
---@class UnitCellUnitHealthMap unitID -> health fraction
---@field [integer] number
local unitCellHealth = {}
---@type InfoUnitCellOpts
local cellOpts = {} -- reused, so drawing a cell doesn't allocate
---@type table<integer, integer[]>, integer[], integer
local selUnitsSorted, selTypes, selUnitTypes = {}, {}, 0
local cellsize, cellPadding, cornerSize, texOffset, gridHeight, numCells = 0, 1, 1, 0, 0, 0
---@type table?, fun(px: number, py: number, sx: number, sy: number, cs: number?, tl: number?, tr: number?, br: number?, bl: number?, c1: number[]?, c2: number[]?)?
local registeredWith, RectRound

---@param areaWidth number
---@param areaHeight number
---@param cellCount integer How many cells the grid would like to have.
---@return integer cells How many it can show.
---@return integer rows
---@return integer colls
---@return number cellSize
local function getUnitCellLayout(areaWidth, areaHeight, cellCount)
	local minCellSize = areaHeight / maxUnitCellRows
	local maxCellSize = areaHeight / 2 -- don't grow beyond what the aggregated grid uses
	-- each row is as wide as its cells plus the row button in front of them
	local maxColls = math_max(1, math_floor((areaWidth / minCellSize) - rowButtonWidth))
	local bestCells, bestRows, bestColls, bestSize = 0, 1, 1, 0
	for rows = 1, maxUnitCellRows do
		local colls = math_min(math_ceil(cellCount / rows), maxColls)
		local cells = math_min(rows * colls, cellCount)
		local size = math_min(areaWidth / (colls + rowButtonWidth), areaHeight / rows, maxCellSize)
		if cells > bestCells or (cells == bestCells and size > bestSize) then
			bestCells, bestRows, bestColls, bestSize = cells, rows, colls, size
		end
	end
	return bestCells, bestRows, bestColls, bestSize
end

---@param x number Middle of the flat side.
---@param y number
---@param radius number
---@param color1 number[] Colour at the middle.
---@param color2 number[] Colour at the corners.
local function drawRowButtonShape(x, y, radius, color1, color2)
	glColor(color1)
	glVertex(x, y, 0)
	glColor(color2)
	for i = 1, #rowButtonCorners do
		local offset = rowButtonCorners[i]
		glVertex(x + (radius * offset[1]), y + (radius * offset[2]), 0)
	end
end

---@param rect RowButtonRect
---@param color1 number[]
---@param color2 number[]
local function drawRowButton(rect, color1, color2)
	local radius = math_min((rect[4] - rect[2] - cellPadding) * 0.5, rect[3] - rect[1] - cellPadding)
	glBeginEnd(
		GL_TRIANGLE_FAN,
		drawRowButtonShape,
		rect[3],
		(rect[2] + cellPadding + rect[4]) * 0.5,
		radius,
		color1,
		color2
	)
end

---@param unitIDa integer
---@param unitIDb integer
---@return boolean
local function healthiestFirst(unitIDa, unitIDb)
	local healthA, healthB = unitCellHealth[unitIDa], unitCellHealth[unitIDb]
	if healthA == healthB then
		return unitIDa < unitIDb -- keep equally hurt units from shuffling around between draws
	end
	return healthA > healthB
end

---@return integer cellsWanted How many cells the grid would like to have.
---@return integer damagedCount How many of the selected units are below full health.
local function splitSelectionByHealth()
	for unitID in pairs(unitCellHealth) do
		unitCellHealth[unitID] = nil
		grid.unitType[unitID] = nil
	end
	for uDefID in pairs(grid.fullCount) do
		grid.fullCount[uDefID] = nil
	end

	local damagedCount, fullTypes = 0, 0
	for i = 1, selUnitTypes do
		local uDefID = selTypes[i]
		local units = selUnitsSorted[uDefID]
		local fullCount = 0
		for j = 1, #units do
			local unitID = units[j]
			local health, maxHealth = spGetUnitHealth(unitID)
			local fraction = (health and maxHealth and maxHealth > 0) and (health / maxHealth) or 1
			unitCellHealth[unitID] = fraction
			grid.unitType[unitID] = uDefID
			if fraction < 1 then
				damagedCount = damagedCount + 1
				grid.damagedUnits[damagedCount] = unitID
			else
				fullCount = fullCount + 1
			end
		end
		if fullCount > 0 then
			fullTypes = fullTypes + 1
			grid.fullTypes[fullTypes] = uDefID
			grid.fullCount[uDefID] = fullCount
		end
	end
	for i = #grid.fullTypes, fullTypes + 1, -1 do
		grid.fullTypes[i] = nil
	end
	for i = #grid.damagedUnits, damagedCount + 1, -1 do
		grid.damagedUnits[i] = nil
	end
	table.sort(grid.damagedUnits, healthiestFirst)

	return fullTypes + damagedCount, damagedCount
end

---@param units integer[] Appended to.
---@param cellID integer
local function appendCellUnits(units, cellID)
	local uDefID = cellDefID[cellID]
	if cellID <= grid.fullCells then
		local typeUnits = selUnitsSorted[uDefID]
		for i = 1, #typeUnits do
			local unitID = typeUnits[i]
			if not unitCellHealth[unitID] or unitCellHealth[unitID] >= 1 then
				units[#units + 1] = unitID
			end
		end
	elseif cellID >= grid.remainderFirst and cellID <= grid.remainderLast then
		for i = grid.bandFirst, math_min(grid.bandLast, #grid.damagedUnits) do
			local unitID = grid.damagedUnits[i]
			if grid.unitType[unitID] == uDefID then
				units[#units + 1] = unitID
			end
		end
	elseif grid.cellUnits[cellID] then
		units[#units + 1] = grid.cellUnits[cellID]
	end
end

---@param buttonRect RowButtonRect
---@return boolean mixed
local function rowHasMixedTypes(buttonRect)
	local unitDefID = cellDefID[buttonRect[5]]
	for cellID = buttonRect[5] + 1, buttonRect[6] do
		if cellDefID[cellID] ~= unitDefID then
			return true
		end
	end
	return false
end

---@param numCells integer How many cells there are to hand out.
---@param cellsWanted integer How many the grid would like to have.
---@param damagedCount integer
---@param rows integer
---@param colls integer
local function setSelectionUnitCells(numCells, cellsWanted, damagedCount, rows, colls)
	local fullCells = math_min(#grid.fullTypes, numCells)
	grid.fullCells = fullCells
	grid.remainderFirst, grid.remainderLast = 0, -1
	grid.bandFirst, grid.bandLast = 0, -1

	local highCells, lowCells, remainderCells = damagedCount, 0, 0
	if numCells < cellsWanted then
		-- the remainder cells start a row of their own, halfway down the grid, so that they line up
		-- with the left edge; an odd row is left to the more damaged half below them
		local remainderStart = rows > 1 and ((math_floor(rows / 2) * colls) + 1) or numCells
		remainderStart = math_max(remainderStart, fullCells + 1)
		highCells = remainderStart - 1 - fullCells
		for uDefID in pairs(grid.remainderCount) do
			grid.remainderCount[uDefID] = nil
			grid.remainderHealth[uDefID] = nil
		end
		-- walk the units that didn't fit; every type met costs one more cell here, which is one
		-- less for the most damaged half, so the walk reaches a little further
		local band = highCells
		local bandEnd = damagedCount - (numCells - remainderStart + 1)
		while band < bandEnd and band < damagedCount do
			band = band + 1
			local unitID = grid.damagedUnits[band]
			local uDefID = grid.unitType[unitID]
			if not grid.remainderCount[uDefID] then
				if remainderStart + remainderCells > numCells then
					break -- no cell left to aggregate this type into
				end
				remainderCells = remainderCells + 1
				grid.remainderTypes[remainderCells] = uDefID
				grid.remainderCount[uDefID] = 0
				grid.remainderHealth[uDefID] = 0
				bandEnd = bandEnd + 1
			end
			grid.remainderCount[uDefID] = grid.remainderCount[uDefID] + 1
			grid.remainderHealth[uDefID] = grid.remainderHealth[uDefID] + unitCellHealth[unitID]
		end
		for i = 1, remainderCells do
			local uDefID = grid.remainderTypes[i]
			grid.remainderHealth[uDefID] = grid.remainderHealth[uDefID] / grid.remainderCount[uDefID]
		end
		for i = #grid.remainderTypes, remainderCells + 1, -1 do
			grid.remainderTypes[i] = nil
		end
		grid.remainderFirst = remainderStart
		grid.remainderLast = remainderStart + remainderCells - 1
		grid.bandFirst, grid.bandLast = highCells + 1, band
		lowCells = math_max(0, math_min(numCells - grid.remainderLast, damagedCount - band))
	end

	for i = 1, fullCells do
		cellDefID[i] = grid.fullTypes[i]
		grid.cellUnits[i] = false -- aggregating cells have no unit of their own
	end
	for i = 1, highCells do
		local unitID = grid.damagedUnits[i]
		cellDefID[fullCells + i] = grid.unitType[unitID]
		grid.cellUnits[fullCells + i] = unitID
	end
	for i = 1, remainderCells do
		cellDefID[grid.remainderFirst + i - 1] = grid.remainderTypes[i]
		grid.cellUnits[grid.remainderFirst + i - 1] = false
	end
	for i = 1, lowCells do
		local unitID = grid.damagedUnits[damagedCount - lowCells + i]
		cellDefID[grid.remainderLast + i] = grid.unitType[unitID]
		grid.cellUnits[grid.remainderLast + i] = unitID
	end
	for i = #cellDefID, numCells + 1, -1 do
		cellDefID[i] = nil
	end
	for i = #grid.cellUnits, numCells + 1, -1 do
		grid.cellUnits[i] = nil
	end
end
-- what a cell shows, over and above its unit picture
---@param cellID integer
---@return integer uDefID What the cell shows.
local function setCellOpts(cellID)
	local uDefID = cellDefID[cellID]
	local unitID = grid.cellUnits[cellID]
	cellOpts.padding = cellPadding
	cellOpts.corner = cornerSize
	cellOpts.fontCap = gridHeight * 0.17
	cellOpts.countAtTop = true
	cellOpts.outline = not unitID
	cellOpts.count = nil
	cellOpts.health = nil
	cellOpts.kills = nil
	if cellID <= grid.fullCells then
		-- no health bar needed, every unit in this cell is at full health
		cellOpts.count = grid.fullCount[uDefID]
	elseif cellID >= grid.remainderFirst and cellID <= grid.remainderLast then
		cellOpts.count = grid.remainderCount[uDefID]
		cellOpts.health = grid.remainderHealth[uDefID]
	elseif unitID then
		cellOpts.health = unitCellHealth[unitID]
		cellOpts.kills = spGetUnitRulesParam(unitID, "kills") or 0
	end
	return uDefID
end

---@param cellID integer
---@param zoom number
local function drawCell(cellID, zoom)
	local uDefID = setCellOpts(cellID)
	cellOpts.zoom = zoom
	WG.info.drawUnitCell(
		cellRect[cellID][1],
		cellRect[cellID][2],
		cellRect[cellID][3],
		cellRect[cellID][4],
		uDefID,
		cellOpts
	)
end

---@param area InfoRect
local function drawSelectionUnitCells(area)
	local sorted, _, types, typeCount = WG.info.getSelection()
	---@cast sorted table<integer, integer[]>
	---@cast types integer[]
	---@cast typeCount integer
	selUnitsSorted, selTypes, selUnitTypes = sorted, types, typeCount

	-- take the whole panel, not just the part the built in mode leaves over once it has listed its
	-- totals; the inset it keeps on the right is mirrored onto the left so the icons sit evenly
	local panel = WG.info.getPanelArea() or area
	local right, bottom = area[3], area[2]
	local left = panel[1] + (panel[3] - right)
	local gridWidth = right - left
	gridHeight = area[4] - bottom

	local cellsWanted, damagedCount = splitSelectionByHealth()
	local rows, colls
	numCells, rows, colls, cellsize = getUnitCellLayout(gridWidth, gridHeight, cellsWanted)
	cellsize = math_floor(cellsize)
	setSelectionUnitCells(numCells, cellsWanted, damagedCount, rows, colls)

	-- leave some space at the top and at the right side
	cellsize = math_floor((cellsize * (1 - (0.04 / rows))) + 0.5)
	cellPadding = math_max(1, math_floor(cellsize * 0.03))
	-- the rows start that padding above the bottom, so it comes off the height they have to fill,
	-- otherwise the top row spills onto the panel's border
	cellsize = math_min(cellsize, math_floor((gridHeight - cellPadding) / rows))
	cornerSize = math_max(1, cellPadding * 0.9)
	texOffset = math_min(0.25, (0.03 * rows) * zoomMult)
	right = right - cellPadding
	for i = #cellRect, 1, -1 do
		cellRect[i] = nil
	end

	local numRowButtons = 0
	rowButtonColor[4] = math.clamp(WG.FlowUI.opacity, 0.55, 0.95)
	rowButtonCenterColor[4] = rowButtonColor[4]
	for row = 1, rows do
		-- cells run left to right and top to bottom, so the last row is the one left short
		local rowFirstCell = ((rows - row) * colls) + 1
		local rowLastCell = math_min(rowFirstCell + colls - 1, numCells)
		-- row button, sitting left of the row it acts on
		if rowFirstCell <= numCells then
			numRowButtons = numRowButtons + 1
			local buttonRect = grid.rowRect[numRowButtons]
			if not buttonRect then
				buttonRect = { 0, 0, 0, 0, 0, 0 }
				grid.rowRect[numRowButtons] = buttonRect
			end
			buttonRect[1] = math_ceil(right - cellPadding - ((colls + rowButtonWidth) * cellsize))
			buttonRect[2] = math_ceil(bottom + cellPadding + ((row - 1) * cellsize))
			buttonRect[3] = math_ceil(right - cellPadding - (colls * cellsize))
			buttonRect[4] = math_ceil(bottom + cellPadding + (row * cellsize))
			buttonRect[5] = rowFirstCell
			buttonRect[6] = rowLastCell
			drawRowButton(buttonRect, rowButtonCenterColor, rowButtonColor)
		end
		for coll = 1, colls do
			local cellID = rowFirstCell + colls - coll -- coll 1 is the rightmost one
			if cellID <= rowLastCell and cellDefID[cellID] then
				local rect = cellRect[cellID]
				if not rect then
					rect = { 0, 0, 0, 0 }
					cellRect[cellID] = rect
				end
				rect[1] = math_ceil(right - cellPadding - (coll * cellsize))
				rect[2] = math_ceil(bottom + cellPadding + ((row - 1) * cellsize))
				rect[3] = math_ceil(right - cellPadding - ((coll - 1) * cellsize))
				rect[4] = math_ceil(bottom + cellPadding + (row * cellsize))
				drawCell(cellID, texOffset)
			end
		end
	end
	for i = #grid.rowRect, numRowButtons + 1, -1 do
		grid.rowRect[i] = nil
	end
	glColor(1, 1, 1, 1)
end

-- the glyph on the button switching modes: a dense grid, one cell per unit
---@param left number
---@param bottom number
---@param right number
---@param _top number
local function drawSelectionUnitCellsIcon(left, bottom, right, _top)
	local size = right - left
	local inset = math_max(2, math_floor(size * 0.28))
	local inner = size - (inset * 2)
	local gap = math_max(1, math_floor(inner * 0.12))
	local cell = math_max(1, math_floor((inner - (gap * 2)) / 3))
	local step = cell + gap
	for row = 0, 2 do
		for col = 0, 2 do
			local x, y = left + inset + (col * step), bottom + inset + (row * step)
			glRect(x, y, x + cell, y + cell)
		end
	end
end

---@param x number
---@param y number
---@return integer? cellID
local function hoveredCell(x, y)
	for cellID = 1, numCells do
		local rect = cellRect[cellID]
		if rect and math_isInRect(x, y, rect[1], rect[2], rect[3], rect[4]) then
			return cellID
		end
	end
end

---@param x number
---@param y number
---@return RowButtonRect?
local function hoveredRowButton(x, y)
	for row = 1, #grid.rowRect do
		local rect = grid.rowRect[row]
		if math_isInRect(x, y, rect[1], rect[2], rect[3], rect[4]) then
			return rect
		end
	end
end

---@param mouseX number
---@param mouseY number
---@param leftHeld boolean
---@param middleHeld boolean
---@param rightHeld boolean
---@return string? howto Help text for whatever is under the cursor.
local function drawSelectionUnitCellsHover(mouseX, mouseY, leftHeld, middleHeld, rightHeld)
	local cellID = hoveredCell(mouseX, mouseY)
	if cellID then
		local color = { 1, 1, 1 }
		local cellZoom = hoverCellZoom
		if leftHeld then
			cellZoom, color = clickCellZoom, { 0.36, 0.8, 0.3 }
		elseif middleHeld then
			cellZoom, color = clickCellZoom, { 1, 0.66, 0.1 }
		elseif rightHeld then
			cellZoom, color = rightclickCellZoom, { 1, 0.1, 0.1 }
		end
		cellZoom = cellZoom + math_min(0.33 * cellZoom * ((gridHeight / cellsize) - 2), 0.15) -- add extra zoom when small icons
		drawCell(cellID, texOffset + cellZoom)
		local rect = cellRect[cellID]
		local held = leftHeld or middleHeld or rightHeld
		glBlending(GL_SRC_ALPHA, GL_ONE)
		RectRound(
			rect[1] + cellPadding,
			rect[2] + cellPadding,
			rect[3],
			rect[4],
			cellPadding * 0.9,
			1,
			1,
			1,
			1,
			{ color[1], color[2], color[3], held and 0.4 or 0.08 },
			{ color[1], color[2], color[3], held and 0.07 or 0.08 }
		)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		return grid.cellUnits[cellID] and selectionHowtoUnit or selectionHowtoType
	end

	local buttonRect = hoveredRowButton(mouseX, mouseY)
	if buttonRect then
		local color = { 1, 1, 1 }
		if leftHeld then
			color = { 0.36, 0.8, 0.3 }
		elseif middleHeld then
			color = { 1, 0.66, 0.1 }
		elseif rightHeld then
			color = { 1, 0.1, 0.1 }
		end
		local held = leftHeld or middleHeld or rightHeld
		glBlending(GL_SRC_ALPHA, GL_ONE)
		drawRowButton(
			buttonRect,
			{ color[1], color[2], color[3], held and 0.4 or 0.2 },
			{ color[1], color[2], color[3], held and 0.07 or 0.04 }
		)
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		return rowHasMixedTypes(buttonRect) and selectionHowtoRow or selectionHowtoType
	end
end

---@param x number
---@param y number
---@param button integer
---@return boolean? handled True when the click was taken.
local function drawSelectionUnitCellsRelease(x, y, button)
	local buttonRect = hoveredRowButton(x, y)
	if buttonRect then
		local unitTable = {}
		for cellID = buttonRect[5], buttonRect[6] do
			appendCellUnits(unitTable, cellID)
		end
		if unitTable[1] then
			local unitDefID = cellDefID[buttonRect[5]]
			if button == 1 and rowHasMixedTypes(buttonRect) then
				-- ctrl selects every unit of the type on the map, which a row holding several
				-- types has no answer for, so it does nothing there
				local _, ctrl = spGetModKeyState()
				if ctrl then
					return true
				end
			end
			WG.info.clickCellUnits(button, unitDefID, unitTable)
		end
		return true
	end

	local cellID = hoveredCell(x, y)
	if cellID then
		local unitTable = {}
		appendCellUnits(unitTable, cellID)
		if unitTable[1] then
			WG.info.clickCellUnits(button, cellDefID[cellID], unitTable)
		end
		return true
	end
end

function widget:Shutdown()
	-- hand the mode back, or the panel would keep drawing it after this widget is gone
	if WG.info and WG.info.unregister and WG.info.unregister.drawSelection then
		WG.info.unregister.drawSelection("units")
	end
	registeredWith = nil
end

function widget:Update()
	-- register with whichever info panel is up, including one that reloaded under us: comparing the
	-- api it published catches that, where a flag of our own would miss it
	if WG.info == registeredWith then
		return
	end
	registeredWith = nil
	if WG.info and WG.info.register and WG.info.register.drawSelection then
		RectRound = WG.FlowUI.Draw.RectRound
		WG.info.register.drawSelection({
			draw = drawSelectionUnitCells,
			name = "units",
			title = "unit icons",
			description = "An icon per unit, with those at full health and those that don't fit grouped by unit type",
			icon = drawSelectionUnitCellsIcon,
			hover = drawSelectionUnitCellsHover,
			mouseRelease = drawSelectionUnitCellsRelease,
		})
		registeredWith = WG.info
	end
end
