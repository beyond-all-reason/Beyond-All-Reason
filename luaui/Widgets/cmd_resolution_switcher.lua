local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Screen Mode/Resolution Switcher",
		desc = "Interface for setting screen mode and resolution",
		layer = 0,
		enabled = true,
	}
end

-- these are set in widget:Initialize()
local screenModes, screenGeometries, displays, firstPassDrawFrame, screenModeIndex

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
		display = #displays,
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
		if displays[display] then
			if videoMode.hz > displays[display].hz then
				displays[display].hz = videoMode.hz
			end
		end
		-- Only capture the first occurence of the display index, it will contain maximum supported resolution
		if display ~= videoMode.display then
			display = videoMode.display
			local w, h, x, y = Spring.GetScreenGeometry(display-1)
			displays[display] = {
				name = videoMode.displayName,
				width = w, --videoMode.w,
				height = h, --videoMode.h,
				hz = videoMode.hz,
				x = x,
				y = y,
			}

			local fullscreen = {
				display = display,
				displayName = videoMode.displayName,
				name = Spring.I18N('ui.resolutionswitcher.fullscreen'),
				type = windowType.fullscreen,
				width = videoMode.w,
				height = videoMode.h,
			}

			local borderless = {
				display = display,
				name = Spring.I18N('ui.resolutionswitcher.borderless'),
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
				name = Spring.I18N('ui.resolutionswitcher.window').." " .. videoMode.w .. " × " .. videoMode.h.."  (" .. videoMode.hz.."hz)",
				type = windowType.windowed,
				width = videoMode.w,
				height = videoMode.h,
				hz = videoMode.hz
			}

			table.insert(screenModes, windowed)
		end
	end


	local numDisplays = Spring.GetNumDisplays()
	if numDisplays > 1 then
		refreshScreenGeometries(numDisplays)

		-- Insert mode spanning all monitors
		--insertMaximalScreenMode(1, numDisplays, screenModes)

		local addedDisplayCombo = {}
		for display = 1, numDisplays do
			for display2 = 1, numDisplays do
				if display ~= display2 then
					local w, h, x, y = Spring.GetScreenGeometry(display-1)
					local w2, h2, x2, y2 = Spring.GetScreenGeometry(display2-1)
					if w > 0 and w2 > 0 then
						if x+w == x2 or x2+w2 == x or x2-w == x or x-w2 == x2 then	-- make sure they are next to eachother
							if not addedDisplayCombo[display] or addedDisplayCombo[display] ~= display2 then
								addedDisplayCombo[display] = display2
								addedDisplayCombo[display2] = display
								table.insert(screenModes, {
									display = #displays+1,	-- not actual display number
									actualDisplay = (x < x2 and display or display2),
									name = Spring.I18N('ui.resolutionswitcher.displays').." " .. display .. " + " .. display2.." ("..w + w2 .." x "..math.min(h, h2)..")",
									displayName = "",
									type = windowType.multimonitor,
									x = math.min(x, x2),
									y = math.max(y, y2),
									width = w + w2,
									height = math.min(h, h2),
								})
								-- the screenmode above was restricted to minimum height in case one display has lower vertical resolution
								if h ~= h2 then
									table.insert(screenModes, {
										display = #displays+1,	-- not actual display number
										actualDisplay = (x < x2 and display or display2),
										name = Spring.I18N('ui.resolutionswitcher.displays').." " .. display .. " + " .. display2.." ("..w + w2 .." x "..math.max(h, h2)..")",
										displayName = "",
										type = windowType.multimonitor,
										x = math.min(x, x2),
										y = math.min(y, y2),
										width = w + w2,
										height = math.max(h, h2),
									})
								end
							end
						end
					end
				end
			end
		end

		-- only add the "Multi Display" option when there are valid display combos to choose from
		for k,v in pairs(addedDisplayCombo) do
			displays[#displays+1] = {
				name = Spring.I18N('ui.resolutionswitcher.multidisplay'),
				width = 0,
				height = 0,
				hz = 0,
				x = 0,
				y = 0,
			}
			break
		end
		--insertMultiMonitorModes(screenModes)
	end
end

local function changeScreenMode(index)
	if index > #screenModes or index < 1 then return end

	local screenMode = screenModes[index]

	if screenMode.type == windowType.fullscreen then
		Spring.SetWindowGeometry(screenMode.display, 0, 0, screenMode.width, screenMode.height, true, false)
	elseif screenMode.type == windowType.borderless then
		Spring.SetWindowGeometry(screenMode.display, screenMode.x or 0, screenMode.y or 0, screenMode.width, screenMode.height, true, true)
	elseif screenMode.type == windowType.multimonitor then
		Spring.SetWindowGeometry(screenMode.actualDisplay, screenMode.x or 0, screenMode.y or 0, screenMode.width, screenMode.height, false, true)
	elseif screenMode.type == windowType.windowed then
		-- Windowed mode has a raptor-and-egg problem, where window borders can't be known until after switching to windowed mode
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
	screenModes = {}
	screenGeometries = {}
	displays = {}
	firstPassDrawFrame = nil
	screenModeIndex = 0
	
	refreshScreenModes()

	WG['screenMode'] = { }

	WG['screenMode'].GetDisplays = function()
		return displays
	end

	WG['screenMode'].GetScreenModes = function()
		return screenModes
	end

	WG['screenMode'].SetScreenMode = function(index)
		local prevScreenmode = screenModeIndex
		screenModeIndex = index
		if screenModeIndex ~= prevScreenmode then
			changeScreenMode(screenModeIndex)
		end
	end
end

function widget:LanguageChanged()
	widget:Initialize()
end
