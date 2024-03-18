function widget:GetInfo()
	return {
		name = "Widget Selector2",
		desc = "Widget selection widget",
		author = "lov",
		date = "2023",
		license = "GNU GPL, v2 or later",
		layer = 999999,
		handler = true,
		enabled = true
	}
end

local document
local context
local dm
local widgetList = {
}

local function togglewidget(ev, i)
	Spring.Echo("toggle", i, ev.type)
	widgetHandler:ToggleWidget(widgetList[i].name)
	local order = widgetHandler.orderList[widgetList[i].name]
	local enabled = (order and (order > 0)) == true
	widgetList[i].enabled = enabled
	widgetList[i].active = not widgetList[i].active
	-- ev.target_element:SetClass("enabled", widgetList[i].enabled)
end

local dataModel = {
	toggleWidget = togglewidget,
	-- filterList = filterList,
	widgets = widgetList,
	filter = "",
	frame = 12
}

local function getWidgets()
	local myName = widget:GetInfo().name
	--maxWidth = 0
	-- local listelement = document:GetElementById("widgetlist")
	for name, data in pairs(widgetHandler.knownWidgets) do
		if name ~= myName and name ~= 'Write customparam.__def to files' then
			-- Spring.Echo("E", name, data)
			local order = widgetHandler.orderList[name]
			local enabled = (order and (order > 0)) == true
			widgetList[#widgetList + 1] = {
				name = name,
				data = data,
				enabled = enabled,
				active = data.active,
				filtered = false
			}
		end
	end
end

function widget:filterList(ev, elm)
	local inputText = elm:GetAttribute("value")
	local i
	Spring.Echo(inputText)
	for i = 1, #widgetList do
		local w = widgetList[i]
		local data = w.data
		w.filtered = not ((not inputText or inputText == '') or
			(data.name and string.find(string.lower(data.name), string.lower(inputText), nil, true) or
				(data.desc and string.find(string.lower(data.desc), string.lower(inputText), nil, true)) or
				(data.basename and string.find(string.lower(data.basename), string.lower(inputText), nil, true)) or
				(data.author and string.find(string.lower(data.author), string.lower(inputText), nil, true))))
	end
	dm.widgets = widgetList
	-- dm:__SetDirty("widgets")
end

function widget:Initialize()
	getWidgets()
	context = rmlui.GetContext("overlay")

	dm = context:OpenDataModel("widgetlist", dataModel)

	document = context:LoadDocument("luaui/rml/widget_selector.rml", widget)
	document:Show()
end

function widget:Shutdown()
	if document then
		document:Close()
	end
	if context then
		context:RemoveDataModel("widgetlist")
	end
end

function widget:buttonPress(str)
	-- Spring.Echo("widgetbuttonpress", str)
end

function widget:handleKey(event, elm)
	if rmlui.key_identifier.ESCAPE == event.parameters.key_identifier then
		local inputText = elm:GetAttribute("value")
		if inputText == "" then
			elm:Blur()
		else
			elm:SetAttribute("value", "")
			widget:filterList(event, elm)
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 19) == 'LobbyOverlayActive0' then
		document:Hide()
	elseif msg:sub(1, 19) == 'LobbyOverlayActive1' then
		document:Show()
	end
end
