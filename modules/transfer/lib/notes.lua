local ModuleHandler = require("modules/module_handler")

local Notes = {}

---@param facts table transfer's notes Facts
---@param record table
---@param modOptions table<string, any>
---@return table<string, any>
function Notes.For(facts, record, modOptions)
	local resolved = ModuleHandler.LoadEnrichers(facts)
	return ModuleHandler.EnrichWith(resolved, ModuleHandler.LiveModulesFor(modOptions), record, modOptions)
end

return Notes
