--- Build options changed at runtime by api_dynamic_build_options.lua, published in the game rules param
--- "dynamic_build_options" as "<builderUnitDefID>:<builtUnitDefID>:<1 added / 0 removed>" entries.
local dynamicBuildOptions = {}

local RULES_PARAM = "dynamic_build_options"

--- Publishes the changes (synced).
---@param added table<number, table<number, any>?> builder UnitDefID -> added built UnitDefIDs (keys)
---@param removed table<number, table<number, any>?> builder UnitDefID -> removed built UnitDefIDs (keys)
function dynamicBuildOptions.publish(added, removed)
	local entries = {}
	for builderDefID, options in pairs(added) do
		for builtDefID in pairs(options) do
			entries[#entries + 1] = builderDefID .. ":" .. builtDefID .. ":1"
		end
	end
	for builderDefID, options in pairs(removed) do
		for builtDefID in pairs(options) do
			entries[#entries + 1] = builderDefID .. ":" .. builtDefID .. ":0"
		end
	end
	Spring.SetGameRulesParam(RULES_PARAM, entries[1] and table.concat(entries, ",") or nil)
end

--- Reads the published changes; the param is unset while there are none.
---@return table<number, table<number, boolean>> changes builder UnitDefID -> built UnitDefID -> added
function dynamicBuildOptions.getChanges()
	local changes = {}
	local encoded = Spring.GetGameRulesParam(RULES_PARAM) or ""
	for _, entry in ipairs(string.split(encoded, ",")) do
		local fields = string.split(entry, ":")
		table.ensureTable(changes, tonumber(fields[1]))[tonumber(fields[2])] = fields[3] == "1"
	end
	return changes
end

--- Adds or removes a build option in a copy of a unit def's build options. The copies are only
--- used for membership checks (the menus order options themselves), so an addition is appended.
---@param buildOptions number[]
---@param builtDefID number
---@param added boolean
function dynamicBuildOptions.patch(buildOptions, builtDefID, added)
	if not added then
		table.removeFirst(buildOptions, builtDefID)
	elseif not table.contains(buildOptions, builtDefID) then
		buildOptions[#buildOptions + 1] = builtDefID
	end
end

--- Applies all published changes to copies of unit defs' build options.
---@param unitBuildOptions table<number, number[]?> UnitDefID -> build options, patched in place
function dynamicBuildOptions.apply(unitBuildOptions)
	for builderDefID, options in pairs(dynamicBuildOptions.getChanges()) do
		local buildOptions = unitBuildOptions[builderDefID]
		if buildOptions then
			for builtDefID, added in pairs(options) do
				dynamicBuildOptions.patch(buildOptions, builtDefID, added)
			end
		end
	end
end

return dynamicBuildOptions
