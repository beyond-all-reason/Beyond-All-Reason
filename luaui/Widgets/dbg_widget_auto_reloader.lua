if not Spring.Utilities.IsDevMode() then -- and not Spring.Utilities.ShowDevUI() then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Widget Auto Reloader",
		desc = "Reloads all widgets that have changed after the mouse returned to the game window",
		author = "Beherith, Floris",
		date = "2024.03.12",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true, --  loaded by default?
		handler = true, -- so it can remove and add widgets
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetMouseState = Spring.GetMouseState
local spEcho = Spring.Echo

local widgetContents = {} -- maps widgetname to raw code
local widgetFilesNames = {} -- maps widgetname to filename
local mouseOffscreen = select(6, spGetMouseState())

function widget:Initialize()
	local widgets = widgetHandler.widgets
	for _, widget in pairs(widgets) do
		local whInfo = widget.whInfo
		widgetFilesNames[whInfo.name] = whInfo.filename
		if not widgetContents[whInfo.name] then
			widgetContents[whInfo.name] = VFS.LoadFile(whInfo.filename)
		end
	end
end

local function CheckForChanges(widgetName, fileName)
	local newContents = VFS.LoadFile(fileName)
	if newContents ~= widgetContents[widgetName] then
		widgetContents[widgetName] = newContents
		local chunk, err = loadstring(newContents, fileName)
		if not mouseOffscreen and chunk == nil then
			spEcho('Failed to load: ' .. fileName .. '  (' .. err .. ')')
			return nil
		end
		widgetHandler:DisableWidget(widgetName)
		--spEcho("Reloading widget: " .. widgetName)
		widgetHandler:EnableWidget(widgetName)
	end
end

local lastUpdate = Spring.GetTimer()
function widget:Update()
	if Spring.DiffTimers(Spring.GetTimer() , lastUpdate) < 1 then
		return
	end
	lastUpdate = Spring.GetTimer()

	local prevMouseOffscreen = mouseOffscreen
	mouseOffscreen = select(6, spGetMouseState())

	if not mouseOffscreen and prevMouseOffscreen then
		widget:Initialize()
		for widgetName, fileName in pairs(widgetFilesNames) do
			CheckForChanges(widgetName, fileName)
		end
	end
end
