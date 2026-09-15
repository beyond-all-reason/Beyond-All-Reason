--- Build options changed at runtime through GG.DynamicBuildOptions (api_dynamic_build_options.lua).
--- The gadget publishes game rules params "dynamic_buildoption_<builderUnitDefID>_<builtUnitDefID>"
--- (1 = option added, 0 = option removed) so widgets can patch the build option lists they copied
--- from UnitDefs, which never change. Live changes arrive through the BuildOptionsChanged callin.
local dynamicBuildOptions = {}

--- Reads the runtime changes from the game rules params.
---@return table<number, table<number, boolean>> changes builder UnitDefID -> built UnitDefID -> true (added) / false (removed)
function dynamicBuildOptions.getChanges()
	local changes = {}
	for key, value in pairs(Spring.GetGameRulesParams() or {}) do
		local builderDefIDStr, builtDefIDStr = key:match("^dynamic_buildoption_(%d+)_(%d+)$")
		if builderDefIDStr then
			local builderDefID = tonumber(builderDefIDStr)
			local builtDefID = tonumber(builtDefIDStr)
			if builderDefID and builtDefID and UnitDefs[builderDefID] and UnitDefs[builtDefID] then
				changes[builderDefID] = changes[builderDefID] or {}
				changes[builderDefID][builtDefID] = value == 1
			end
		end
	end
	return changes
end

--- Adds or removes one build option in a build option array copied from UnitDefs.
---@param buildOptions number[] Patched in place.
---@param builtDefID number
---@param added boolean
function dynamicBuildOptions.patch(buildOptions, builtDefID, added)
	for i = #buildOptions, 1, -1 do
		if buildOptions[i] == builtDefID then
			if added then
				return
			end
			table.remove(buildOptions, i)
		end
	end
	if added then
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
