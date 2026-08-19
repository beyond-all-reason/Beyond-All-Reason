---
--- Loadout parameter validators, for the unitLoadout and featureLoadout parameters
--- of actions. Mission level loadouts are covered by loadouts_validation_spec.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.loadout_validators", function()
	before_each(V.mockEngineGlobals)

	--- Validates the unitLoadout parameter of the action under test.
	local function validateUnitLoadout(unitLoadout)
		return V.validateAction({ type = V.actionTypes.SpawnUnits, parameters = { unitLoadout = unitLoadout } })
	end

	--- Validates the featureLoadout parameter of the action under test.
	local function validateFeatureLoadout(featureLoadout)
		return V.validateAction({ type = V.actionTypes.CreateFeatures, parameters = { featureLoadout = featureLoadout } })
	end

	describe("UnitLoadout", function()
		it("passes for a well-formed entry", function()
			local result = validateUnitLoadout({ { unitDefName = 'armwar', team = 0, x = 0, z = 0 } })

			V.assertNoMessageContaining(result, "unitLoadout entry")
		end)

		it("rejects the wrong type", function()
			V.assertMessage(validateUnitLoadout('notATable'),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: unitLoadout")
		end)

		it("reports a missing required field", function()
			local result = validateUnitLoadout({ { unitDefName = 'armwar', x = 0, z = 0 } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: unitLoadout[1].team")
		end)

		it("reports a missing position coordinate", function()
			local result = validateUnitLoadout({ { unitDefName = 'armwar', team = 0, x = 0 } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: unitLoadout[1].z")
		end)

		it("reports a field of the wrong type", function()
			local result = validateUnitLoadout({ { unitDefName = 'armwar', team = 'notANumber', x = 0, z = 0 } })

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Action: a, Parameter: unitLoadout[1].team")
		end)
	end)

	describe("FeatureLoadout", function()
		it("passes for a well-formed entry", function()
			local result = validateFeatureLoadout({ { featureDefName = 'rockdef', x = 0, z = 0 } })

			V.assertNoMessageContaining(result, "featureLoadout entry")
		end)

		it("rejects the wrong type", function()
			V.assertMessage(validateFeatureLoadout('notATable'),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: featureLoadout")
		end)

		it("reports a missing position coordinate", function()
			local result = validateFeatureLoadout({ { featureDefName = 'rockdef', z = 0 } })

			V.assertMessage(result, "Missing required parameter. Action: a, Parameter: featureLoadout[1].x")
		end)
	end)
end)
