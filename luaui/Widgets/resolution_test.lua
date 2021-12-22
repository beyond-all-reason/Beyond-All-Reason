function widget:GetInfo()
	return {
		name = "Resolution Testing",
		desc = "Debug changing fulscreen/borderless/resolution",
		layer = 0,
		enabled = true,
	}
end

local ssx, ssy, _, _ = Spring.GetScreenGeometry()

local windowType = {
	fullscreen = 1,
	borderless = 2,
	windowed   = 3,
}

local screenModes = {
	{
		name = "Fullscreen",
		type = windowType.fullscreen,
		width = ssx,
		height = ssy,
	},
	{
		name = "Borderless",
		type = windowType.borderless,
		width = ssx,
		height = ssy,
	}
}

for _, videoMode in ipairs(Platform.availableVideoModes) do
	if videoMode.display == 1 and videoMode.w >= 800 and videoMode.h > 600 then
		local resolution = {
			name = videoMode.w .. " × " .. videoMode.h,
			type = windowType.windowed,
			width = videoMode.w,
			height = videoMode.h,
		}

		table.insert(screenModes, resolution)
	end
end

local function changeScreenMode(index)
	if index > #screenModes then return end

	local screenMode = screenModes[index]

    if screenMode.type == windowType.fullscreen then
        Spring.SetConfigInt("XResolution", screenMode.width)
        Spring.SetConfigInt("YResolution", screenMode.height)
        Spring.SendCommands("Fullscreen 1")
    elseif screenMode.type == windowType.borderless then
        Spring.SetConfigInt("WindowPosX", 0)
        Spring.SetConfigInt("WindowPosY", 0)
        Spring.SetConfigInt("XResolutionWindowed", screenMode.width)
        Spring.SetConfigInt("YResolutionWindowed", screenMode.height)
        Spring.SetConfigInt("WindowBorderless", 1)
        Spring.SendCommands("Fullscreen 0")
    elseif screenMode.type == windowType.windowed then
        Spring.SetConfigInt("WindowPosX", 25)
        Spring.SetConfigInt("WindowPosY", 25)
        Spring.SetConfigInt("XResolutionWindowed", screenMode.width)
        Spring.SetConfigInt("YResolutionWindowed", screenMode.height)
        Spring.SetConfigInt("WindowBorderless", 0)
        Spring.SendCommands("Fullscreen 0")
    end
end

function widget:Initialize()
	Spring.Echo("[Resolution Test] Use command '\\res #' to change screen specs")
	for i, mode in ipairs(screenModes) do
		Spring.Echo(i .. ": " .. mode.name)
	end
end

function widget:TextCommand(command)
	if string.sub(command, 1, 4) == "res " then
		local screenModeIndex = tonumber(string.sub(command, 5))
		changeScreenMode(screenModeIndex)
	end
end
