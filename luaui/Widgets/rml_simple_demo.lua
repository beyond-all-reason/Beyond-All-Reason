if not RmlUi then
	return false
end

function widget:GetInfo()
	return {
		name      = "Demo RML Gui",
		desc      = "A sandbox for the Rml powered GUI.",
		author    = "ChrisFloofyKitsune",
		date      = "2024-03-17",
		license   = "https://unlicense.org/",
		layer     = -828888,
		handler   = true,
		enabled   = true
	}
end

local document
widget.rmlContext = nil

-- this can be overwritten later to change what code exampleEventHook calls
local eventCallback = function(ev, ...) Spring.Echo('orig function says', ...) end;

local dm_handle

function widget:Initialize()
	widget.rmlContext = RmlUi.CreateContext(widget.whInfo.name)

	-- use the DataModel handle to set values
	-- only keys declared at the DataModel's creation can be used
	dm_handle = widget.rmlContext:OpenDataModel("data_model_test", {
		exampleValue = 'Changes when clicked',
		-- Functions inside a DataModel cannot be changed later
		-- so instead a function variable external to the DataModel is called and _that_ can be changed
		exampleEventHook = function(...) eventCallback(...) end
	});

	eventCallback = function (ev, ...)
		Spring.Echo(ev.parameters.mouse_x, ev.parameters.mouse_y, ev.parameters.button, ...)
		options = {"ow", "oof!", "stop that!", "clicking go brrrr"}
		dm_handle.exampleValue = options[math.random(1, 4)]
	end

	document = widget.rmlContext:LoadDocument("LuaUi/Widgets/rml_widget_assets/simple_demo.rml", widget)
	document:ReloadStyleSheet()
	document:Show()
end

function widget:Shutdown()
	if document then
		document:Close()
	end
	if widget.rmlContext then
		RmlUi.RemoveContext(widget.whInfo.name)
	end
end
