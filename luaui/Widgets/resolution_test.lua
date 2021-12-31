function widget:GetInfo()
	return {
		name = "Resolution Testing",
		desc = "Debug changing fulscreen/borderless/resolution",
		layer = 0,
		enabled = true,
	}
end

local screenModeIndex = 0
local staleWindow = false
local windowedFirstPass = true

local windowType = {
	fullscreen = 1,
	borderless = 2,
	windowed   = 3,
}

local screenModes = {}
local display = -1
for _, videoMode in ipairs(Platform.availableVideoModes) do
	-- only capture the first occurance of the display index. Will contain maximum supported resolution
	if display ~= videoMode.display then
		display = videoMode.display
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

local function changeScreenMode(index)
	if index > #screenModes or index < 1 then return end

	local screenMode = screenModes[index]

	if screenMode.type == windowType.fullscreen then
		Spring.Echo("windowType.fullscreen", screenMode.width, screenMode.height)
		Spring.SetWindowGeometry(screenMode.display, 0, 0, screenMode.width, screenMode.height, true, true)
	elseif screenMode.type == windowType.borderless then
		Spring.Echo("windowType.borderless", 0, 0, screenMode.width, screenMode.height)
		Spring.SetWindowGeometry(screenMode.display, 0, 0, screenMode.width, screenMode.height, false, true)
	elseif screenMode.type == windowType.windowed then
		local w, h, x, y , borderTop, borderLeft, borderBottom, borderRight = Spring.GetWindowGeometry()
		local width = screenMode.width - borderLeft - borderRight
		local height = screenMode.height - borderTop - borderBottom
		Spring.Echo("windowType.windowed", borderLeft, borderTop, width, height)
		Spring.SetWindowGeometry(screenMode.display, borderLeft, borderTop, width, height, false, false)

		if windowedFirstPass then
			staleWindow = true
			windowedFirstPass = false
			return
		end

		windowedFirstPass = true
	end

	staleWindow = false
end

function widget:Update(delta)
	if delta <= 0 then return end

	if staleWindow then
		changeScreenMode(screenModeIndex)
	end

end

function widget:Initialize()
	Spring.Echo("[Resolution Test] Use command '\\res #' to change screen specs")
	local displayName
	for i, mode in ipairs(screenModes) do
		if mode.displayName ~= displayName then
			Spring.Echo(mode.displayName)
			displayName = mode.displayName
		end
		Spring.Echo(i .. ": " .. mode.name)
	end
end

function widget:TextCommand(command)
	if string.sub(command, 1, 4) == "res " then
		screenModeIndex = tonumber(string.sub(command, 5))
		staleWindow = true
	end
end