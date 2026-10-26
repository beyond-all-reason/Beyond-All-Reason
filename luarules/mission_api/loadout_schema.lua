---
--- Named fields of unit and feature loadout entries, in the order validation reports them.
---

local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types
local schemaUtils = VFS.Include("luarules/mission_api/schema_utils.lua")

local unitEntryFields = {
	{ name = "unitDefName", type = Types.UnitDefName, required = true },
	{ name = "teamName", type = Types.TeamName, required = true },
	{ name = "facing", type = Types.Facing },
	{ name = "unitName", type = Types.String },
	{ name = "construction", type = Types.Boolean },
	{ name = "quantity", type = Types.Number },
	{ name = "spacing", type = Types.Number },
	{ name = "neutral", type = Types.Boolean },
	{ name = "orders", type = Types.Orders },
}
schemaUtils.SetInternalFields("UnitLoadout", unitEntryFields)

local featureEntryFields = {
	{ name = "featureDefName", type = Types.FeatureDefName, required = true },
	{ name = "facing", type = Types.Facing },
	{ name = "featureName", type = Types.String },
}

return {
	UnitEntryFields = unitEntryFields,
	FeatureEntryFields = featureEntryFields,
}
