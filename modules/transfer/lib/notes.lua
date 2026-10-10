local ModuleHandler = require("modules/module_handler")

local Notes = {}

-- The notes other modules attach to a terms record for the player to read. A provider gets the record, the
-- modoptions and the engine as its context, and nothing else.
---@param facts table transfer's notes Facts
---@param terms TransferTerms
---@param modOptions table<string, any>
---@param springRepo Spring
---@return table<string, any>
function Notes.For(facts, terms, modOptions, springRepo)
	local resolved = ModuleHandler.LoadEnrichers(facts)
	---@type TransferNotesContext
	local ctx = { terms = terms, modOptions = modOptions, springRepo = springRepo }
	return ModuleHandler.EnrichWith(resolved, ModuleHandler.LiveModulesFor(modOptions), ctx)
end

return Notes
