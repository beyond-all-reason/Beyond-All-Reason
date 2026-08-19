---
--- Mission level unit and feature loadout validation.
---
--- Loadouts in actions are validated as action parameters instead of here.
---

local SECTION = VFS.Include('luarules/mission_api/validation/validation_report.lua').Sections.Loadouts
local LABEL = 'Loadout'

local function validate(context, report, parameterValidators)
	local Types = context.Types
	local loadouts = {
		{ name = 'UnitLoadout',    value = context.UnitLoadout,    type = Types.UnitLoadout },
		{ name = 'FeatureLoadout', value = context.FeatureLoadout, type = Types.FeatureLoadout },
	}

	for _, loadout in ipairs(loadouts) do
		for _, result in ipairs(parameterValidators[loadout.type](loadout.value) or {}) do
			report.Error(SECTION, LABEL, loadout.name .. (result.parameterNameSuffix or ''), result.message)
		end
	end
end

return {
	Validate = validate,
}
