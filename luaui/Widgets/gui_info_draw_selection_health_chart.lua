function widget:GetInfo()
	return {
		name = "Info Draw Selection Health Chart",
		desc = "Adds a unit selection info panel with a chart of units' health",
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
local spSelectUnitArray = Spring.SelectUnitArray
local glColor, glRect, glBlending = gl.Color, gl.Rect, gl.Blending

local GL_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA = GL.SRC_ALPHA, GL.ONE, GL.ONE_MINUS_SRC_ALPHA
local sound_button = "LuaUI/Sounds/buildbar_add.wav"

local tooltipTextColor = "\255\255\255\255"
local tooltipLabelTextColor = "\255\205\205\205"

-- shown while hovering the chart
local selectionHowtoChart = tooltipTextColor
	.. "Left click"
	.. tooltipLabelTextColor
	.. ": Select the units at or above the health under the cursor"
	.. "\n"
	.. tooltipTextColor
	.. "Right click"
	.. tooltipLabelTextColor
	.. ": Select the units at or below it"

---@type integer[] every selected unit, healthiest first, as plotted
local chartUnits = {} -- every selected unit, healthiest first, as plotted
---A unit to its health fraction.
---@class HealthChartHealthMap
---@field [integer] number
local chartHealth = {} -- unitID -> health fraction
---@type InfoRect the plotted area
local chartRect = { 0, 0, 0, 0 } -- the plotted area
---@type integer, integer, number
local chartCount, chartFullCount, chartAverage = 0, 0, 1
---@type number, integer
local chartSpacing, chartDot = 1, 2 -- how the dots are laid out, so the hover can find one again
---@type table?
local registeredWith

---@param unitIDa integer
---@param unitIDb integer
---@return boolean
local function healthiestFirst(unitIDa, unitIDb)
	local healthA, healthB = chartHealth[unitIDa], chartHealth[unitIDb]
	if healthA == healthB then
		return unitIDa < unitIDb -- keep equally hurt units from shuffling around between draws
	end
	return healthA > healthB
end

-- read every selected unit's health as a fraction of its maximum, so that units of different types
-- compare, and order them all by it
---@return integer count How many units were plotted.
local function sortSelectionByHealth()
	local selUnitsSorted, _, selTypes, selUnitTypes = WG.info.getSelection()
	---@cast selUnitsSorted table<integer, integer[]>
	---@cast selTypes integer[]
	---@cast selUnitTypes integer
	local count = 0
	for unitID in pairs(chartHealth) do
		chartHealth[unitID] = nil
	end
	local full, total = 0, 0
	for i = 1, selUnitTypes do
		local typeUnits = selUnitsSorted[selTypes[i]]
		for j = 1, #typeUnits do
			local unitID = typeUnits[j]
			local health, maxHealth = spGetUnitHealth(unitID)
			local fraction = (health and maxHealth and maxHealth > 0) and (health / maxHealth) or 1
			chartHealth[unitID] = fraction
			total = total + fraction
			if fraction >= 1 then
				full = full + 1
			end
			count = count + 1
			chartUnits[count] = unitID
		end
	end
	chartFullCount = full
	chartAverage = count > 0 and (total / count) or 1
	for i = #chartUnits, count + 1, -1 do
		chartUnits[i] = nil
	end
	table.sort(chartUnits, healthiestFirst)
	chartCount = count
	return count
end

-- where a unit's dot is drawn; dense charts space them closer than their own width, so the ones at
-- either end are kept from hanging off the edges
---@param index integer Which unit, counting from the healthiest.
---@return number left
local function chartDotLeft(index)
	return math_min(
		math_max(math_floor(chartRect[1] + ((index - 0.5) * chartSpacing) - (chartDot * 0.5)), chartRect[1]),
		chartRect[3] - chartDot
	)
end

-- as the dots are colored: red mixed into green by health, brightest channel scaled up to full
---@param fraction number 0 to 1.
---@return string escape A colour escape for the font to take.
local function healthColorString(fraction)
	local red, green = 1 - fraction, fraction
	local brightness = math_max(red, green)
	return BAR.Utilities.ConvertColor(red / brightness, green / brightness, 0)
end

---@param area InfoRect What the panel offers; the chart takes the whole panel instead.
local function drawSelectionChart(area)
	local count = sortSelectionByHealth()
	-- the chart takes the whole panel, not just the area the cell modes draw their icons in; what
	-- it adds up to is written over its top left corner afterwards, along with the mode button
	local panel = WG.info.getPanelArea() or area
	chartRect[1], chartRect[2], chartRect[3], chartRect[4] = panel[1], panel[2], panel[3], panel[4]

	local width, height = chartRect[3] - chartRect[1], chartRect[4] - chartRect[2]
	glColor(0.15, 0.15, 0.15, 0.5)
	glRect(chartRect[1], chartRect[2], chartRect[3], chartRect[4])
	glColor(1, 1, 1, 0.07)
	for i = 1, 3 do -- quarter lines, so the height of a dot can be read off
		local y = math_floor(chartRect[2] + ((height * i) * 0.25))
		glRect(chartRect[1], y, chartRect[3], y + 1)
	end

	chartSpacing = width / count
	-- one size however many there are, so the line they run in keeps its thickness
	chartDot = math_max(2, math_floor(height * 0.05))
	local span = height - chartDot
	for i = 1, count do
		local fraction = chartHealth[chartUnits[i]]
		-- colored like the bars drawn in the world: red mixed into green by health, with the
		-- brightest channel scaled up to full (see HealthbarsGL4.geom.glsl)
		local red, green = 1 - fraction, fraction
		local brightness = math_max(red, green)
		local x = chartDotLeft(i)
		local y = math_floor(chartRect[2] + (span * fraction))
		glColor(red / brightness, green / brightness, 0, 1)
		glRect(x, y, x + chartDot, y + chartDot)
	end
	glColor(1, 1, 1, 1)

	-- a line to each quarter of the chart, sitting between the dividers drawn across it; the
	-- header already lands about halfway up the top quarter
	local quarter = height * 0.25
	WG.info.drawSelectionHeader()
	WG.info.drawSelectionLineAt(
		tooltipTextColor .. chartFullCount .. tooltipLabelTextColor .. " full health",
		chartRect[4] - (quarter * 1.5)
	)
	WG.info.drawSelectionLineAt(
		healthColorString(chartAverage)
			.. math_floor((chartAverage * 100) + 0.5)
			.. "%"
			.. tooltipLabelTextColor
			.. " average health",
		chartRect[4] - (quarter * 2.5)
	)
end

-- the glyph on the button switching modes: three dots stepping down, like the chart's falling health
---@param left number
---@param bottom number
---@param right number
---@param _top number
local function drawSelectionChartIcon(left, bottom, right, _top)
	local size = right - left
	local inset = math_max(2, math_floor(size * 0.28))
	local dot = math_max(2, math_floor(size * 0.16))
	local span = (size - (inset * 2)) - dot
	for i = 0, 2 do
		local x = left + inset + math_floor((span * i) * 0.5)
		local y = bottom + inset + math_floor((span * (2 - i)) * 0.5)
		glRect(x, y, x + dot, y + dot)
	end
end

-- the dot nearest the cursor, or nil when the cursor is elsewhere
---@param x number
---@param y number
---@return integer? index Which unit's dot is nearest, or nil away from the chart.
local function chartIndexAt(x, y)
	if
		chartCount < 1
		or not chartRect[1]
		or not math_isInRect(x, y, chartRect[1], chartRect[2], chartRect[3], chartRect[4])
	then
		return nil
	end
	local index = math_ceil((x - chartRect[1]) / ((chartRect[3] - chartRect[1]) / chartCount))
	return math_max(1, math_min(chartCount, index))
end

---@param mouseX number
---@param mouseY number
---@param leftHeld boolean
---@param _middleHeld boolean The chart makes nothing of the middle button.
---@param rightHeld boolean
---@return string? howto
local function drawSelectionChartHover(mouseX, mouseY, leftHeld, _middleHeld, rightHeld)
	local index = chartIndexAt(mouseX, mouseY)
	if not index then
		return nil
	end
	-- through the middle of the hovered dot, which a click takes whichever way it goes
	local pivot = chartDotLeft(index) + math_floor(chartDot * 0.5)
	glBlending(GL_SRC_ALPHA, GL_ONE)
	if leftHeld or rightHeld then
		-- the side the click keeps shades green, the side it drops from the selection shades red
		local keptLeft, keptRight, droppedLeft, droppedRight = chartRect[1], pivot, pivot, chartRect[3]
		if rightHeld then
			keptLeft, keptRight, droppedLeft, droppedRight = pivot, chartRect[3], chartRect[1], pivot
		end
		glColor(0.15, 0.25, 0.05, 1)
		glRect(keptLeft, chartRect[2], keptRight, chartRect[4])
		glColor(0.25, 0.05, 0.05, 1)
		glRect(droppedLeft, chartRect[2], droppedRight, chartRect[4])
	end
	glColor(1, 1, 1, 0.35)
	glRect(pivot - 1, chartRect[2], pivot + 1, chartRect[4])
	glColor(1, 1, 1, 1)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	return selectionHowtoChart
end

---@param x number
---@param y number
---@param button integer
---@return boolean? handled True when the click was taken.
local function drawSelectionChartRelease(x, y, button)
	local index = chartIndexAt(x, y)
	if not index then
		return nil
	end
	local unitTable = {}
	if button == 1 then
		for i = 1, index do
			unitTable[#unitTable + 1] = chartUnits[i]
		end
	elseif button == 3 then
		for i = index, chartCount do
			unitTable[#unitTable + 1] = chartUnits[i]
		end
	end
	if unitTable[1] then
		spSelectUnitArray(unitTable)
		Spring.PlaySoundFile(sound_button, 0.5, "ui")
	end
	return true
end

function widget:Shutdown()
	-- hand the mode back, or the panel would keep drawing it after this widget is gone
	if WG.info and WG.info.unregister and WG.info.unregister.drawSelection then
		WG.info.unregister.drawSelection("chart")
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
		WG.info.register.drawSelection({
			draw = drawSelectionChart,
			name = "chart",
			title = "health chart",
			description = "A graph showing each unit's health",
			icon = drawSelectionChartIcon,
			hover = drawSelectionChartHover,
			mouseRelease = drawSelectionChartRelease,
		})
		registeredWith = WG.info
	end
end
