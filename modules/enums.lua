---The modules a caller may load by name. Each module adds its own line in
---the commit that adds the module, so a rename follows every reader.
---@class Modules
---@field Defs string
---@field Modes string
local Modules = {
	Defs = "defs",
	Modes = "modes",
}

return { Modules = Modules }
