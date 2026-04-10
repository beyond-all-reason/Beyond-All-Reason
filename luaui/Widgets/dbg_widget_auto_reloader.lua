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


-- Localized Spring API for performance
local spGetMouseState = SpringUnsynced.GetMouseState
local spEcho = SpringShared.Echo

local widgetContents = {} -- maps widgetname to raw code
local widgetFilesNames = {} -- maps widgetname to filename
local widgetDependents = {} -- maps widgetname to {dependentName1, ...}
local mouseOffscreen = select(6, spGetMouseState())

function widget:Initialize()
	local widgets = widgetHandler.widgets
	for _, widget in pairs(widgets) do
		local whInfo = widget.whInfo
		widgetFilesNames[whInfo.name] = whInfo.filename
		if not widgetContents[whInfo.name] then
			widgetContents[whInfo.name] = VFS.LoadFile(whInfo.filename)
		end
		if widget.GetInfo then
			local info = widget:GetInfo()
			if info.dependents then
				widgetDependents[whInfo.name] = info.dependents
			end
		end
	end
end

local function ReloadWidget(widgetName)
	spEcho("Reloading widget: " .. widgetName)
	widgetHandler:DisableWidget(widgetName)
	widgetHandler:EnableWidget(widgetName)
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
		ReloadWidget(widgetName)
		local deps = widgetDependents[widgetName]
		if deps then
			for i = 1, #deps do
				local depName = deps[i]
				if widgetHandler:FindWidget(depName) then
					spEcho("Reloading dependent widget: " .. depName .. " (of " .. widgetName .. ")")
					ReloadWidget(depName)
				end
			end
		end
	end
end

local lastUpdate = SpringUnsynced.GetTimer()
function widget:Update()
	if SpringUnsynced.DiffTimers(SpringUnsynced.GetTimer() , lastUpdate) < 1 then
		return
	end
	lastUpdate = SpringUnsynced.GetTimer()

	local prevMouseOffscreen = mouseOffscreen
	mouseOffscreen = select(6, spGetMouseState())

	if not mouseOffscreen and prevMouseOffscreen then
		widget:Initialize()
		for widgetName, fileName in pairs(widgetFilesNames) do
			CheckForChanges(widgetName, fileName)
		end
	end
end
