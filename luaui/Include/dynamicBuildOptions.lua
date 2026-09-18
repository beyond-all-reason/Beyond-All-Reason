--- Build options changed at runtime through GG.DynamicBuildOptions (api_dynamic_build_options.lua).
--- The gadget lists them in the game rules param "dynamic_build_options" so widgets can patch the
--- build option lists they copied from UnitDefs, which never change. Live changes arrive through
--- the BuildOptionsChanged callin.
---
--- The patched lists only answer "can this unit type build that". The order a player sees comes
--- from the unit's command descriptions, where the gadget inserts at the requested position (the
--- legacy build menu's order without smart ordering), or from the menus' own sorting (grid layout,
--- smart ordering), so an added option is simply appended here.
local dynamicBuildOptions = {}

--- Reads the runtime changes from the game rules param.
---@return table<number, table<number, boolean>> changes builder UnitDefID -> built UnitDefID -> true (added) / false (removed)
function dynamicBuildOptions.getChanges()
	local changes = {}
	local encoded = Spring.GetGameRulesParam("dynamic_build_options")
	if type(encoded) ~= "string" then
		return changes
	end
	for _, entry in ipairs(string.split(encoded, ",")) do
		local fields = string.split(entry, ":")
		local builderDefID, builtDefID = tonumber(fields[1]), tonumber(fields[2])
		if builderDefID and builtDefID then
			table.ensureTable(changes, builderDefID)[builtDefID] = fields[3] == "1"
		end
	end
	return changes
end

--- Adds or removes one build option in a build option array copied from UnitDefs.
---@param buildOptions number[] Patched in place.
---@param builtDefID number
---@param added boolean
function dynamicBuildOptions.patch(buildOptions, builtDefID, added)
	if not added then
		table.removeFirst(buildOptions, builtDefID)
	elseif not table.contains(buildOptions, builtDefID) then
		buildOptions[#buildOptions + 1] = builtDefID
	end
end

--- Applies every published runtime change to a table of build option arrays.
---@param unitBuildOptions table<number, number[]?> UnitDefID -> build option UnitDefIDs, patched in place.
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
