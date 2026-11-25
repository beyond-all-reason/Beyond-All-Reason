---
--- The shape of a stage, kept as data so that tools, the mission editor included,
--- have a single source of truth for it. validation/sections.lua validates against it.
---

local Types = VFS.Include("luarules/mission_api/parameter_types.lua").Types

local fields = {
	objectives = Types.ObjectiveIDs,
}

return {
	Settings = fields,
}
