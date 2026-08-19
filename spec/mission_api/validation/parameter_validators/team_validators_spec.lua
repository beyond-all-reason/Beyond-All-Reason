---
--- Team parameter validators: TeamID, AllyTeamID and AllyTeamIDs.
---

local V = require("mission_api.validation.validation_spec_helper")

describe("mission_api.validation.team_validators", function()
	before_each(V.mockEngineGlobals)

	--- Validates the allyTeamIDs parameter of the action under test.
	local function validateAllyTeamIDs(allyTeamIDs)
		return V.validateAction({ type = V.actionTypes.Victory, parameters = { allyTeamIDs = allyTeamIDs } })
	end

	describe("TeamID", function()
		it("rejects the wrong type", function()
			local result = V.validateAction({ type = V.actionTypes.AddResources, parameters = { teamID = 'bad' } })

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Action: a, Parameter: teamID")
		end)

		it("rejects a team that does not exist", function()
			Spring.GetTeamAllyTeamID = function() return nil end

			local result = V.validateAction({ type = V.actionTypes.AddResources, parameters = { teamID = 99 } })

			V.assertMessage(result, "Invalid teamID: 99. Action: a, Parameter: teamID")
		end)
	end)

	describe("AllyTeamID", function()
		it("rejects the wrong type", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitSpotted, {
				unitName           = 'x',
				spottingAllyTeamID = 'bad',
			}))

			V.assertMessage(result, "Unexpected parameter type, expected number, got string. Trigger: t, Parameter: spottingAllyTeamID")
		end)

		it("rejects an ally team that does not exist", function()
			local result = V.validateTrigger(V.trigger(V.triggerTypes.UnitSpotted, {
				unitName           = 'x',
				spottingAllyTeamID = 99,
			}))

			V.assertMessage(result, "Invalid allyTeamID: 99. Trigger: t, Parameter: spottingAllyTeamID")
		end)
	end)

	describe("AllyTeamIDs", function()
		it("rejects the wrong type", function()
			V.assertMessage(validateAllyTeamIDs('bad'),
				"Unexpected parameter type, expected table, got string. Action: a, Parameter: allyTeamIDs")
		end)

		it("rejects an empty table", function()
			V.assertMessage(validateAllyTeamIDs({}), "allyTeamIDs table is empty. Action: a, Parameter: allyTeamIDs")
		end)

		it("rejects an entry that is not a number", function()
			V.assertMessage(validateAllyTeamIDs({ 'bad' }),
				"Unexpected parameter type, expected number, got string. Action: a, Parameter: allyTeamIDs[1]")
		end)

		it("rejects an entry that does not exist", function()
			V.assertMessage(validateAllyTeamIDs({ 99 }),
				"Invalid allyTeamID: 99. Action: a, Parameter: allyTeamIDs[1]")
		end)

		-- Entries are validated by the AllyTeamID validator, so every bad one is reported.
		it("reports each entry that does not exist", function()
			local result = validateAllyTeamIDs({ 0, 98, 99 })

			V.assertMessage(result, "Invalid allyTeamID: 98. Action: a, Parameter: allyTeamIDs[2]")
			V.assertMessage(result, "Invalid allyTeamID: 99. Action: a, Parameter: allyTeamIDs[3]")
		end)

		it("accepts existing ally teams", function()
			V.assertNoMessageContaining(validateAllyTeamIDs({ 0 }), "allyTeamID")
		end)
	end)
end)
