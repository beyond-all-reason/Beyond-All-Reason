local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "KeySelect",
		desc = "Selects units on keypress.",
		author = "woss (Tyson Buzza)",
		date = "Aug 24, 2024",
		license = "Public Domain",
		layer = 1,
		enabled = false
	}
end

local selectApi = VFS.Include("luaui/Include/select_api.lua")

local function handleSetCommand(_, commandDef)
	local command = selectApi.getCommand(commandDef)
	command()
end

function widget:Initialize()
	widgetHandler:AddAction("select", handleSetCommand, nil, "p")
end

function widget:Shutdown()
	WG['keyselect'] = nil
end
