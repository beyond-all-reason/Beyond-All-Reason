--  file:    rml.lua
--  brief:   RmlUi Setup
--  author:  lov + ChrisFloofyKitsune
--
--  Copyright (C) 2024.
--  Licensed under the terms of the GNU GPL, v2 or later.

if (RmlGuard or not RmlUi) then
	return
end
-- don't allow this initialization code to be run multiple times
RmlGuard = true

--[[
	Recoil uses a custom set of Lua bindings (check out rts/Rml/SolLua/bind folder in the C++ engine code)
	Aside from the Lua API, the rest of the RmlUi documentation is still relevant
		https://mikke89.github.io/RmlUiDoc/index.html
]]

-- create a common context to be used, data models must have unique name within the same context though
RmlUi.CreateContext("common")

-- Load fonts
RmlUi.LoadFontFace("fonts/Poppins-Regular.otf", true)
RmlUi.LoadFontFace("fonts/Exo2-SemiBold.otf", true)
RmlUi.LoadFontFace("fonts/SourceHanSans-Regular.ttc", true)
RmlUi.LoadFontFace("fonts/monospaced/SourceCodePro-Medium.otf")

-- Mouse Cursor Aliases
--[[
	These let standard CSS cursor names be used when doing styling.
	If a cursor set via RCSS does not have an alias, it is unchanged.
	CSS cursor list: https://developer.mozilla.org/en-US/docs/Web/CSS/cursor
	RmlUi documentation: https://mikke89.github.io/RmlUiDoc/pages/rcss/user_interface.html#cursor
]]

-- when "cursor: normal" is set via RCSS, "cursornormal" will be sent to the engine... and so on for the rest
RmlUi.SetMouseCursorAlias("default", 'cursornormal')
RmlUi.SetMouseCursorAlias("pointer", 'Move') -- command cursors use the command name. TODO: replace with actual pointer cursor
RmlUi.SetMouseCursorAlias("move", 'uimove')
RmlUi.SetMouseCursorAlias("nesw-resize", 'uiresized2')
RmlUi.SetMouseCursorAlias("nwse-resize", 'uiresized1')
RmlUi.SetMouseCursorAlias("ns-resize", 'uiresizev')
RmlUi.SetMouseCursorAlias("ew-resize", 'uiresizeh')
