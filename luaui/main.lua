--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    main.lua
--  brief:   the entry point from gui.lua, relays call-ins to the widget manager
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- set default gaia teamcolor
Spring.SetTeamColor(Spring.GetGaiaTeamID(), 0.3, 0.3, 0.3)

local spSendCommands = Spring.SendCommands
spSendCommands("ctrlpanel " .. LUAUI_DIRNAME .. "ctrlpanel.txt")

VFS.Include("init.lua", nil, VFS.ZIP)

VFS.Include(LUAUI_DIRNAME .. "rml_setup.lua",  nil, VFS.ZIP)
Spring.I18N.setLanguage( Spring.GetConfigString('language', 'en') )

VFS.Include(LUAUI_DIRNAME .. "utils.lua",      nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "setupdefs.lua",  nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "savetable.lua",  nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "debug.lua",      nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "layout.lua",     nil, VFS.ZIP)
VFS.Include(LUAUI_DIRNAME .. "barwidgets.lua", nil, VFS.ZIP)

--------------------------------------------------------------------------------
-------------------------------------------------------------------------------

function Say(msg)
	spSendCommands('say ' .. msg)
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

--  Update()  --  called every frame
function Update()
	widgetHandler:Update()
	return
end


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--
--  WidgetHandler fixed calls
--

function Shutdown()
	return widgetHandler:Shutdown()
end

function ConfigureLayout(command)
	return widgetHandler:ConfigureLayout(command)
end

function CommandNotify(id, params, options)
	return widgetHandler:CommandNotify(id, params, options)
end

function DrawScreen(vsx, vsy)
	widgetHandler:SetViewSize(vsx, vsy)
	return widgetHandler:DrawScreen()
end

function KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
	return widgetHandler:KeyPress(key, mods, isRepeat, label, unicode, scanCode, actions)
end

function KeyRelease(key, mods, label, unicode, scanCode, actions)
	return widgetHandler:KeyRelease(key, mods, label, unicode, scanCode, actions)
end

function TextInput(utf8, ...)
	return widgetHandler:TextInput(utf8, ...)
end

function MouseMove(x, y, dx, dy, button)
	return widgetHandler:MouseMove(x, y, dx, dy, button)
end

function MousePress(x, y, button)
	return widgetHandler:MousePress(x, y, button)
end

function MouseRelease(x, y, button)
	return widgetHandler:MouseRelease(x, y, button)
end

function ControllerAdded(deviceIndex)
	return widgetHandler:ControllerAdded(deviceIndex)
end

function ControllerRemoved(instanceId)
	return widgetHandler:ControllerRemoved(instanceId)
end

function ControllerConnected(instanceId)
	return widgetHandler:ControllerConnected(instanceId)
end

function ControllerDisconnected(instanceId)
	return widgetHandler:ControllerDisconnected(instanceId)
end

function ControllerRemapped(instanceId)
	return widgetHandler:ControllerRemapped(instanceId)
end

function ControllerButtonUp(instanceId, button, value, name)
	return widgetHandler:ControllerButtonUp(instanceId, button, value, name)
end

function ControllerButtonDown(instanceId, button, value, name)
	return widgetHandler:ControllerButtonDown(instanceId, button, value, name)
end

function ControllerAxisMotion(instanceId, axis, value, name)
	return widgetHandler:ControllerAxisMotion(instanceId, axis, value, name)
end

function IsAbove(x, y)
	return widgetHandler:IsAbove(x, y)
end

function GetTooltip(x, y)
	return widgetHandler:GetTooltip(x, y)
end

function AddConsoleLine(msg, priority)
	return widgetHandler:AddConsoleLine(msg, priority)
end

function GroupChanged(groupID)
	return widgetHandler:GroupChanged(groupID)
end


--
-- The unit (and some of the Draw) call-ins are handled
-- differently (see LuaUI/widgets.lua / UpdateCallIns())
--


--------------------------------------------------------------------------------

