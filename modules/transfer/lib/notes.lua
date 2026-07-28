local ModuleHandler = VFS.Include("modules/module_handler.lua")

local Notes = {}

---What other modules have to say about a record: each provision's values,
---gathered under their declared names.
---@param category string a notes token's name in transfer's contract.lua
---@param record table
---@return table<string, any>
function Notes.For(category, record)
	local notes = {}
	for _, provision in ipairs(ModuleHandler.LoadEnrichers("transfer", category)) do
		local results = { provision.evaluate(record) }
		for i, field in ipairs(provision.names) do
			notes[field] = results[i]
		end
	end
	return notes
end

return Notes
