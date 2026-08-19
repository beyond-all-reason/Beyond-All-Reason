---
--- Mission level unit and feature loadout validation.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.loadouts_validation", function()
	before_each(V.mockEngineGlobals)

	it("passes for a mission without loadouts", function()
		V.assertValid(V.validate(V.mission()))
	end)

	it("validates loadout entries", function()
		local result = V.validate(V.mission()
			:WithUnitLoadout({ { unitDefName = 'noSuch', x = 0, z = 0, team = 0 } })
			:WithFeatureLoadout({ { featureDefName = 'rockdef', z = 0 } }))

		V.assertMessage(result, "Invalid unitDefName: noSuch. Loadout: UnitLoadout[1].unitDefName")
		V.assertMessage(result, "Missing required parameter. Loadout: FeatureLoadout[1].x")
	end)

	it("reports loadouts that are not tables", function()
		local result = V.validate(V.mission()
			:WithUnitLoadout('notATable')
			:WithFeatureLoadout(42))

		V.assertMessage(result, "UnitLoadout must be a table, got string")
		V.assertMessage(result, "FeatureLoadout must be a table, got number")
	end)
end)
