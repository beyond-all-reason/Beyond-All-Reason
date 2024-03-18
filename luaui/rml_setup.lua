--  file:    rml.lua
--  brief:   RmlUi Setup
--  author:  lov
--
--  Copyright (C) 2023.
--  Licensed under the terms of the GNU GPL, v2 or later.

if (RmlGuard or not RmlUi) then
	return
end
RmlGuard = true

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
RmlUi.SetMouseCursorAlias("pointer", 'Move') -- command cursors use the command name
RmlUi.SetMouseCursorAlias("move", 'uimove')
RmlUi.SetMouseCursorAlias("nesw-resize", 'uiresized2')
RmlUi.SetMouseCursorAlias("nwse-resize", 'uiresized1')
RmlUi.SetMouseCursorAlias("ns-resize", 'uiresizev')
RmlUi.SetMouseCursorAlias("ew-resize", 'uiresizeh')
