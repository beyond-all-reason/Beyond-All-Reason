--- Build options changed at runtime by api_dynamic_build_options.lua, published as "dynamic_build_options"
--- "<builderUnitDefID>:<builtUnitDefID>:<1 added / 0 removed>" entries: a game rules param for the changes for
--- every team, and a team rules param for a team's own changes on top of them.
local dynamicBuildOptions = {}

local RULES_PARAM = "dynamic_build_options"

--- Publishes the changes (synced).
---@param added table<number, table<number, any>?> builder UnitDefID -> added built UnitDefIDs (keys)
---@param removed table<number, table<number, any>?> builder UnitDefID -> removed built UnitDefIDs (keys)
---@param teamID integer? the team the changes are for; nil for every team
function dynamicBuildOptions.publish(added, removed, teamID)
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
	local encoded = entries[1] and table.concat(entries, ",") or nil
	if teamID then
		Spring.SetTeamRulesParam(teamID, RULES_PARAM, encoded)
	else
		Spring.SetGameRulesParam(RULES_PARAM, encoded)
	end
end

local function decode(changes, encoded)
	for _, entry in ipairs(string.split(encoded or "", ",")) do
		local fields = string.split(entry, ":")
		table.ensureTable(changes, tonumber(fields[1]))[tonumber(fields[2])] = fields[3] == "1"
	end
end

--- Reads the published changes; the params are unset while there are none.
---@param teamID integer? also that team's own changes, which win over the ones for every team
---@return table<number, table<number, boolean>> changes builder UnitDefID -> built UnitDefID -> added
function dynamicBuildOptions.getChanges(teamID)
	local changes = {}
	decode(changes, Spring.GetGameRulesParam(RULES_PARAM))
	if teamID then
		decode(changes, Spring.GetTeamRulesParam(teamID, RULES_PARAM))
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
---@param teamID integer? also apply that team's own changes
function dynamicBuildOptions.apply(unitBuildOptions, teamID)
	for builderDefID, options in pairs(dynamicBuildOptions.getChanges(teamID)) do
		local buildOptions = unitBuildOptions[builderDefID]
		if buildOptions then
			for builtDefID, added in pairs(options) do
				dynamicBuildOptions.patch(buildOptions, builtDefID, added)
			end
		end
	end
end

return dynamicBuildOptions
