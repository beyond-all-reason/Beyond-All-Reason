
function widget:GetInfo()
	return {
		name      = "Dummy Script.LuaUI",
		desc      = "Inserts dummy Script.LuaUI calls to prevent engine thinking unattached ones are errors",
		author    = "Bluestone",
		version   = "",
		date      = "",
		license   = "Horses",
		layer     = 0,
		enabled   = true
	}
end

function widget:Initialize()
	-- list of all Script.LuaUI calls in BA
	widgetHandler:RegisterGlobal('PlayerReadyStateChanged', Foo)
	widgetHandler:RegisterGlobal('CameraBroadcastEvent', Foo)
	widgetHandler:RegisterGlobal('MouseCursorEvent', Foo)
	widgetHandler:RegisterGlobal('SendMetalSpots', Foo)
	widgetHandler:RegisterGlobal('registerUPgradePairs', Foo)
end 

function Foo()
	--Bar
	--This wtf widget exists because of http://springrts.com/mantis/view.php?id=4368
end