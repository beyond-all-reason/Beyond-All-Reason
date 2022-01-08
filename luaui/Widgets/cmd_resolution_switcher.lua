function widget:GetInfo()
	return {
		name = "Screen Mode/Resolution Switcher",
		desc = "Interface for setting screen mode and resolution",
		layer = 0,
		enabled = true,
	}
end

local screenModes = {}
local displays = {}
local firstPassDrawFrame
local screenModeIndex = 0

local windowType = {
	fullscreen = 1,
	borderless = 2,
	windowed   = 3,
}

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
				name = videoMode.w .. " × " .. videoMode.h,
				type = windowType.windowed,
				width = videoMode.w,
				height = videoMode.h,
			}

			table.insert(screenModes, windowed)
		end
	end
end

local function changeScreenMode(index)
	if index > #screenModes or index < 1 then return end

	local screenMode = screenModes[index]

	if screenMode.type == windowType.fullscreen then
		Spring.Echo("foo Fullscreen", screenMode.display, 0, 0, screenMode.width, screenMode.height, true, false)
		Spring.SetWindowGeometry(screenMode.display, 0, 0, screenMode.width, screenMode.height, true, false)
	elseif screenMode.type == windowType.borderless then
		Spring.Echo("foo Borderless", screenMode.display, 0, 0, screenMode.width, screenMode.height, true, true)
		Spring.SetWindowGeometry(screenMode.display, 0, 0, screenMode.width, screenMode.height, true, true)
	-- Windowed mode has a chicken-and-egg problem, where window borders can't be known until after switching to windowed mode
	-- This cannot be done in two consecutive SetWindowGeometry() calls, as there must be a two draw frame delay
	-- (one to write, one to read), before the values of GetWindowGeometry() are updated
	elseif screenMode.type == windowType.windowed then
		local _, _, _, _ , borderTop, borderLeft, borderBottom, borderRight = Spring.GetWindowGeometry()
		local width = screenMode.width - borderLeft - borderRight
		local height = screenMode.height - borderTop - borderBottom
		Spring.Echo("foo Windowed", screenMode.display, borderLeft, borderTop, width, height, false, false)
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
	if Spring.GetDrawFrame() - firstPassDrawFrame <= 1 then return end
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
		Spring.Echo("foo Changing screen mode", index)
		screenModeIndex = index
		changeScreenMode(screenModeIndex)
	end
end
