---
--- Named fields of a unit filter, in the order validation reports them.
---

local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

local unitFilterFields = {
	{ name = "unitName", type = Types.UnitName },
	{ name = "unitDefName", type = Types.UnitDefNames },
	{ name = "teamName", type = Types.TeamName },
	{ name = "allianceName", type = Types.AllianceName },
}

return {
	UnitFilterFields = unitFilterFields,
	AtMostOneOf = { "teamName", "allianceName" },
}
