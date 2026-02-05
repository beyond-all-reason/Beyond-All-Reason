---@class ModOptionConfig
---@field value any The default value for this option
---@field locked boolean Whether this option can be changed by users
---@field bounds ModOptionBounds|nil Constraints on the option value
---@field ui string|nil UI hints (e.g., "hidden")

---@class ModOptionBounds
---@field min number|nil Minimum value (for numeric options)
---@field max number|nil Maximum value (for numeric options)
---@field step number|nil Step size for numeric options
---@field items table|nil Array of allowed values for list options

---@class SharingModeConfig
---@field key string Unique identifier for this sharing mode
---@field name string Display name for this sharing mode
---@field desc string Description of this sharing mode
---@field allowRanked boolean Whether this mode is allowed in ranked games
---@field modOptions table<string, ModOptionConfig> Map of mod option keys to their configurations
