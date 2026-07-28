local ModuleHandler = VFS.Include("modules/module_handler.lua")

local Notes = {}

---What other modules have to say about a record: each provision's values,
---gathered under their declared names.
---@param facts table the notes Facts from transfer's contract.lua
---@param record table
---@return table<string, any>
function Notes.For(facts, record)
	return ModuleHandler.Enrich(facts, Spring.GetModOptions(), record)
end

return Notes
