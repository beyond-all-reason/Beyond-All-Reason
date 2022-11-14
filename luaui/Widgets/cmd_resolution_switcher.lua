function widget:GetInfo()
	return {
		name = "Screen Mode/Resolution Switcher",
		desc = "Interface for setting screen mode and resolution",
		layer = 0,
		enabled = true,
	}
end

local screenModes = {}
local screenGeometries = {}
local displays = {}
local firstPassDrawFrame
local screenModeIndex = 0

local windowType = {
	fullscreen   = 1,
	borderless   = 2,
	windowed     = 3,
	multimonitor = 4,
}

-- Gets geometries for each screen and orders them by posX (left to right)
local function refreshScreenGeometries(numDisplays)
	for displayIndex = 1, numDisplays do
		local sx, sy, px, py = Spring.GetScreenGeometry(displayIndex - 1)
		screenGeometries[displayIndex] = { px, py, sx, sy, displayIndex }
	end

	table.sort(screenGeometries, function(l, r)
		return l[1] < r[1]
	end)
end

local function getMaximalWindowGeometry(minI, maxI)
	local minX = screenGeometries[minI][1]
	local maxX = screenGeometries[maxI][1] + screenGeometries[maxI][3]
	local minY = screenGeometries[minI][2]
	local maxY = screenGeometries[minI][2] + screenGeometries[minI][4]
	local di = screenGeometries[minI][5]

	for displayNum = 2, Spring.GetNumDisplays() do
		local py = screenGeometries[displayNum][2]
		local sy = screenGeometries[displayNum][4]
		if py < minY then minY = py end
		if py+sy > maxY then maxY = py+sy end
	end

	return { minX, minY, maxX, maxY, di }
end

local function insertMaximalScreenMode(minI, maxI, modes)
	local windowGeometry = getMaximalWindowGeometry(minI, maxI)

	table.insert(modes, {
		display = windowGeometry[5],
		name = "Multimonitor " .. minI .. "-" .. maxI,
		displayName = "",
		type = windowType.multimonitor,
		x = windowGeometry[1],
		y = windowGeometry[2],
		width = windowGeometry[3] - windowGeometry[1],
		height = windowGeometry[4] - windowGeometry[2],
	})
end

local function insertMultiMonitorModes(modes)
	local numDisplays = Spring.GetNumDisplays()

	if numDisplays <= 1 then return end

	refreshScreenGeometries(numDisplays)

	-- Insert mode spanning all monitors
	insertMaximalScreenMode(1, numDisplays, modes)

	if numDisplays < 3 then return end

	-- Insert dual monitor modes
	for displayNum = 1, numDisplays - 1 do
		insertMaximalScreenMode(displayNum, displayNum + 1, modes)
	end
end

local function refreshScreenModes()
	local display = -1

	for _, videoMode in ipairs(Platform.availableVideoModes) do
		-- Only capture the first occurence of the display index, it will contain maximum supported resolution
		if display ~= videoMode.display then
			display = videoMode.display

			displays[display] = {
				name = videoMode.displayName,
				width = videoMode.w,
				height = videoMode.h,
			}

			local fullscreen = {
				display = display,
				displayName = videoMode.displayName,
				name = "Fullscreen",
				type = windowType.fullscreen,
				width = videoMode.w,
				height = videoMode.h,
			}

			local borderless = {
				display = display,
				name = "Borderless",
				displayName = videoMode.displayName,
				type = windowType.borderless,
				width = videoMode.w,
				height = videoMode.h,
			}

			table.insert(screenModes, fullscreen)
			table.insert(screenModes, borderless)
		end

		if videoMode.w >= 800 and videoMode.h > 600 then
			local windowed = {
				display = display,
				displayName = videoMode.displayName,
				name = "Window " .. videoMode.w .. " × " .. videoMode.h,
				type = windowType.windowed,
				width = videoMode.w,
				height = videoMode.h,
			}

			table.insert(screenModes, windowed)
		end
	end

	insertMultiMonitorModes(screenModes)
end

local function changeScreenMode(index)
	if index > #screenModes or index < 1 then return end

	local screenMode = screenModes[index]

	if screenMode.type == windowType.fullscreen then
		Spring.SetWindowGeometry(screenMode.display, 0, 0, screenMode.width, screenMode.height, true, false)
	elseif screenMode.type == windowType.borderless then
		Spring.SetWindowGeometry(screenMode.display, screenMode.x or 0, screenMode.y or 0, screenMode.width, screenMode.height, true, true)
	elseif screenMode.type == windowType.multimonitor then
		Spring.SetWindowGeometry(screenMode.display, screenMode.x or 0, screenMode.y or 0, screenMode.width, screenMode.height, false, true)
	elseif screenMode.type == windowType.windowed then
		-- Windowed mode has a chicken-and-egg problem, where window borders can't be known until after switching to windowed mode
		-- This cannot be done in two consecutive SetWindowGeometry() calls, as there must be a two draw frame delay
		-- (one to write, one to read), before the values of GetWindowGeometry() are updated
		local _, _, _, _ , borderTop, borderLeft, borderBottom, borderRight = Spring.GetWindowGeometry()
		local width = screenMode.width - borderLeft - borderRight
		local height = screenMode.height - borderTop - borderBottom
		Spring.SetWindowGeometry(screenMode.display, borderLeft, borderTop, width, height, false, false)

		if firstPassDrawFrame then
			firstPassDrawFrame = nil
		else
			firstPassDrawFrame = Spring.GetDrawFrame()
		end
	end
end

function widget:Update()
	if firstPassDrawFrame == nil then return end
	if Spring.GetDrawFrame() - firstPassDrawFrame <= 2 then return end -- 2 draw frame delay for engine to update window borders
	changeScreenMode(screenModeIndex)
end

function widget:Initialize()
	refreshScreenModes()

	WG['screenMode'] = { }

	WG['screenMode'].GetDisplays = function()
		return displays
	end

	WG['screenMode'].GetScreenModes = function()
		return screenModes
	end

	WG['screenMode'].SetScreenMode = function(index)
		screenModeIndex = index
		changeScreenMode(screenModeIndex)
	end
end
