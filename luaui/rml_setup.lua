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

--[[ create a common Context to be used for widgets
	pros:
		* Documents in the same Context can make use of the same DataModels, allowing for less duplicate data
		* Documents can be arranged in front/behind of each other dynamically
	cons:
		* Documents in the same Context can make use of the same data models, leading to side effects
		* DataModels must have unique names within the same Context

	If you have lots of DataModel use you may want to create your own Context
	otherwise you should be able to just use the shared Context

	Contexts created with the Lua API are automatically disposed of when the LuaUi environment is unloaded
]]

local oldCreateContext = RmlUi.CreateContext

local function NewCreateContext(name)
	local context = oldCreateContext(name)
	local viewSizeY = Spring.GetViewGeometry()
    local userScale = Spring.GetConfigFloat("ui_scale", 1)
    local baseHeight = 1080
    local resFactor = viewSizeY / baseHeight
    local dpRatio = resFactor * userScale
    context.dp_ratio = math.floor(dpRatio * 100) / 100
	return context
end

RmlUi.CreateContext = NewCreateContext

-- Load fonts
RmlUi.LoadFontFace("fonts/Poppins-Regular.otf", true)
local font_files = VFS.DirList('fonts/exo2', '*.ttf')
for _, file in ipairs(font_files) do
	Spring.Echo("loading font", file)
	RmlUi.LoadFontFace(file, true)
end

--RmlUi.LoadFontFace("fonts/fallbacks/SourceHanSans-Regular.ttc", true)
--RmlUi.LoadFontFace("fonts/monospaced/SourceCodePro-Medium.otf")

-- Mouse Cursor Aliases
--[[
	These let standard CSS cursor names be used when doing styling.
	If a cursor set via RCSS does not have an alias, it is unchanged.
	CSS cursor list: https://developer.mozilla.org/en-US/docs/Web/CSS/cursor
	RmlUi documentation: https://mikke89.github.io/RmlUiDoc/pages/rcss/user_interface.html#cursor
]]

-- when "cursor: normal" is set via RCSS, "cursornormal" will be sent to the engine... and so on for the rest
RmlUi.SetMouseCursorAlias("default", 'cursornormal')
RmlUi.SetMouseCursorAlias("pointer", 'Move') -- command cursors use the command name. TODO: replace with actual pointer cursor?
RmlUi.SetMouseCursorAlias("move", 'uimove')
RmlUi.SetMouseCursorAlias("nesw-resize", 'uiresized2')
RmlUi.SetMouseCursorAlias("nwse-resize", 'uiresized1')
RmlUi.SetMouseCursorAlias("ns-resize", 'uiresizev')
RmlUi.SetMouseCursorAlias("ew-resize", 'uiresizeh')

RmlUi.CreateContext("shared")
