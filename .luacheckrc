
self = false
unused = false
-- unused_args = false
global = false
allow_defined_top = true
max_line_length = false
codes = true

exclude_files = {
    "common/luaUtilities/**",
    ".lux/**",
    "recoil-lua-library/**",
}

-- Ideally reenable these warnings later
redefined = false

ignore = {
    "512", -- Loop can be executed at most once.

    "542", -- TODO: empty if branch
    "611", -- TODO: line contains only whitespace
    "612", -- TODO: line contains trailing whitespace
    "613", -- TODO: trailing whitespace in a string
    "614", -- TODO: trailing whitespace in a comment
    "621", -- TODO: inconsistent indentation
}
-- Something to think about in the future
-- max_cyclomatic_complexity = 10


-- Default is probably fine, but anyway
std=lua51

globals = {
    -- std extensions
    "math.round", "math.bit_or", "math.diag", "math.cross_product", "math.triangulate",
    "table.ifind", "table.show", "table.save", "table.echo", "table.print",
    -- Spring
    "Spring", "VFS", "gl", "GL", "Game",
    "UnitDefs", "UnitDefNames", "FeatureDefs", "FeatureDefNames",
    "WeaponDefs", "WeaponDefNames", "LOG", "KEYSYMS", "CMD", "Script",
    "SendToUnsynced", "Platform", "Engine", "include", "COB",
    -- GL
    "GL_TEXTURE_2D", "GL_HINT_BIT",
    -- Gadgets
    "GG", "gadgetHandler", "gadget",
    -- Widgets
    "WG", "widgetHandler", "widget", "LUAUI_DIRNAME", "self",
    -- Chili
    "Chili", "Checkbox", "Control", "ComboBox", "Button", "Label",
    "Line", "EditBox", "Font", "Window", "ScrollPanel", "LayoutPanel",
    "Panel", "StackPanel", "Grid", "TextBox", "Image", "TreeView", "Trackbar",
    "DetachableTabPanel", "screen0", "Progressbar",
    -- Libs
    -- "LCS", "Path", "Table", "Log", "String", "Shaders", "Time", "Array", "StartScript",

    "CMDTYPE", "COBSCALE", "CallAsTeam", "SYNCED", "loadlib",
    -- Unit scripts (LUS)
    "piece", "script", "UnitScript", "UNITSCRIPT_DIR", "Turn", "Move", "Spin", "StopSpin", "Hide",
    "Show", "Explode", "EmitSfx", "Sleep", "StartThread", "Signal", "SetSignalMask", "WaitForTurn",
    "WaitForMove", "GetUnitValue", "SetUnitValue", "x_axis", "y_axis", "z_axis", "SIG_WALK",
    "SFX", "unitID", "MultiMove", "MultiTurn",
    -- BAR namespace and shared helpers
    "BAR", "Utilities", "Debug", "I18N", "I18N_PATH", "Lava", "GetModOptionsCopy", "lowerkeys", "pairsByKeys",
    "ipairs_reverse",
    -- Handler internals
    "addon", "handler", "actionHandler", "fontHandler", "ghInfo", "CALLIN_MAP", "_G",
    -- Game data and commands
    "GameCMD", "ExplosionDefs", "GadgetCrashingAircraft", "Scenario", "SG", "CMD_AREA_MEX", "CMD_WANTED_SPEED",
    "CMD_WANT_CLOAK",
    -- Lua/runtime
    "socket", "gcinfo", "game_engine",
}