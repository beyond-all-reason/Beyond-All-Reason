function widget:GetInfo()
	return {
		name = "RML UI sandbox",
		desc = "Just messing about",
		author = "ChrisFloofyKitsune",
		date = "Jan 2024",
		license = "Unlicense",
		layer = 0,
		handler = true,
		enabled = true
	}
end

local contextName
local context
local dm
local document

local dataModel = {
	-- You must declare all the variables you want to use in here ahead of time
}

function widget:Initialize()
	Spring.Echo('Hello, I am "' .. widget.whInfo.name .. '" and I live at: ' .. widget.whInfo.path)
	contextName = widget.whInfo.name .. " context"
	rmlui.CreateContext(contextName)
	context = rmlui.GetContext(contextName)
	Spring.Echo('RML UI Sandbox', context ~= nil, context)
	dm = context:OpenDataModel('data', dataModel)
	document = context:LoadDocument(widget.whInfo.path .. 'sandbox.rml', widget)
	document:Show()
end

function widget:Shutdown()
	if document then
		Spring.Echo('RML UI Sandbox', 'Closing Document')
		document:Close()
	end
	if context then
		Spring.Echo('RML UI Sandbox', 'Removing data model')
		context:RemoveDataModel("data")
		Spring.Echo('RML UI Sandbox', 'Removing Context...')
		rmlui.RemoveContext(contextName)
	end
end
