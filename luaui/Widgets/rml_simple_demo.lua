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
		handler   = false,
		enabled   = false
	}
end

local document
widget.rmlContext = nil

-- this can be overwritten later to change what code exampleEventHook calls
local eventCallback = function(ev, ...) Spring.Echo('orig function says', ...) end;

local dm_handle
local test_obj

function widget:Initialize()
	widget.rmlContext = RmlUi.CreateContext(widget.whInfo.name)

	-- use the DataModel handle to set values
	-- only keys declared at the DataModel's creation can be used
	dm_handle = widget.rmlContext:OpenDataModel("data_model_test", {
		exampleValue = 'Changes when clicked',
		-- Functions inside a DataModel cannot be changed later
		-- so instead a function variable external to the DataModel is called and _that_ can be changed
		exampleEventHook = function(...) eventCallback(...) end,
		button2Clicked = function()
			local _target = document:GetElementById('target')
			local _div = document:CreateElement('div')
			_div:SetClass('element', true)
            _div = _target:AppendChild(_div)
            _div.style.width = '20px'
            _div.style.height = '50px'

            local _div_prepend = document:CreateElement('div')
            _div_prepend.inner_rml = "p"
            _div_prepend = _target:InsertBefore(_div_prepend, _div)

            local _div_replace = document:CreateElement('div')
            _div_replace.inner_rml = "r"

            _div = _target:ReplaceChild(_div_replace, _div)
            _div.inner_rml = 'asdf'
            _div = _target:AppendChild(_div)
            _div.style.width = nil
            _div.style.height = ''
		end,
		my_rect = "",
		context_name_list = "",
	});

	eventCallback = function (ev, ...)
		--Spring.Echo(ev.parameters.mouse_x, ev.parameters.mouse_y, ev.parameters.button, ...)
		local options = {"ow", "oof!", "stop that!", "clicking go brrrr"}
		dm_handle.exampleValue = options[math.random(1, 4)]

		local textureElement = document:GetElementById('101')
		textureElement.style.color = "red"

		Spring.Echo(textureElement.style.pairs)

		for k, v in textureElement.style:__pairs() do
			Spring.Echo(k .. ': ' .. v)
		end
	end

	document = widget.rmlContext:LoadDocument("LuaUi/Widgets/rml_widget_assets/simple_demo.rml", widget)
	document:ReloadStyleSheet()
	document:Show()

	--RmlUi.SetDebugContext(widget.rmlContext)
end

function widget:Update()
	local context_names = ""

	for _, context in pairs(RmlUi.contexts()) do
		context_names = context_names .. " " .. context.name
	end

	dm_handle.context_name_list = context_names
end

function widget:Shutdown()
	--RmlUi.SetDebugContext(nil)

	if document then
		document:Close()
	end
	if widget.rmlContext then
		RmlUi.RemoveContext(widget.whInfo.name)
	end
end
