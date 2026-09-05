local ModuleHandler = VFS.Include("modules/module_handler.lua")

local Notes = {}

---What other modules have to say about a record: each provision's values,
---gathered under their declared names.
---@param category string a notes facts' name in transfer's contract.lua
---@param record table
---@return table<string, any>
function Notes.For(category, record)
	return ModuleHandler.Enrich("transfer", category, Spring.GetModOptions(), record)
end

return Notes
