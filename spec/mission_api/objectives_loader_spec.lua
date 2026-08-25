require("spec_helper")
local registerMissionApiModules = require("mission_api.spec_helper")

-- Trigger and action definition files read the Mission API modules from GG at include time.
registerMissionApiModules()
local actionDefinitions  = VFS.Include('luarules/mission_api/actions_loader.lua').LoadActionDefinitions()
local triggerDefinitions = VFS.Include('luarules/mission_api/triggers_loader.lua').LoadTriggerDefinitions()
GG['MissionAPI'] = nil

local objectivesLoader = VFS.Include('luarules/mission_api/objectives_loader.lua')
local triggerTypes = triggerDefinitions.Types
local actionTypes  = actionDefinitions.Types

--- Triggers and actions synthesized here are not validated by the Mission API validation,
--- which only sees the raw mission data, so they are covered by this spec instead.
describe("mission_api.objectives_loader", function()
	before_each(function()
		GG['MissionAPI'] = {
			ActionDefinitions  = actionDefinitions,
			TriggerDefinitions = triggerDefinitions,
			ManagedObjectives  = {},
		}
	end)

	after_each(function()
		GG['MissionAPI'] = nil
	end)

	describe("synthesized triggers and actions", function()
		it("creates a trigger and an UpdateObjective action for an objective with a trigger", function()
			local rawTriggers, rawActions = {}, {}
			objectivesLoader.ProcessRawObjectives({
				killBot = {
					textKey = "kill the bot",
					trigger = {
						type       = triggerTypes.UnitKilled,
						parameters = { unitName = 'bot' },
					},
				},
			}, rawTriggers, rawActions, {})

			local trigger = rawTriggers['__objective_killBot']
			assert.is_table(trigger)
			assert.are.equal(triggerTypes.UnitKilled, trigger.type)
			assert.are.same({ unitName = 'bot' }, trigger.parameters)
			assert.are.same({ '__updateObjective_killBot' }, trigger.actions)

			local action = rawActions['__updateObjective_killBot']
			assert.is_table(action)
			assert.are.equal(actionTypes.UpdateObjective, action.type)
			assert.are.same({ objectiveID = 'killBot' }, action.parameters)
		end)

		it("defaults parameters to an empty table when the trigger has none", function()
			local rawTriggers = {}
			objectivesLoader.ProcessRawObjectives({
				obj = { textKey = "ok", trigger = { type = triggerTypes.UnitKilled } },
			}, rawTriggers, {}, {})

			assert.are.same({}, rawTriggers['__objective_obj'].parameters)
		end)

		it("marks the trigger as non-repeating when the objective has no amount", function()
			local rawTriggers = {}
			objectivesLoader.ProcessRawObjectives({
				obj = { textKey = "ok", trigger = { type = triggerTypes.UnitKilled, parameters = {} } },
			}, rawTriggers, {}, {})

			local settings = rawTriggers['__objective_obj'].settings
			assert.is_false(settings.repeating)
			assert.is_nil(settings.maxRepeats)
		end)

		it("repeats amount - 1 times for an objective with an amount above one", function()
			local rawTriggers = {}
			objectivesLoader.ProcessRawObjectives({
				obj = { textKey = "ok", amount = 3, trigger = { type = triggerTypes.UnitKilled, parameters = {} } },
			}, rawTriggers, {}, {})

			local settings = rawTriggers['__objective_obj'].settings
			assert.is_true(settings.repeating)
			assert.are.equal(2, settings.maxRepeats)
		end)

		it("repeats without a maxRepeats limit for an amount of one", function()
			local rawTriggers = {}
			objectivesLoader.ProcessRawObjectives({
				obj = { textKey = "ok", amount = 1, trigger = { type = triggerTypes.UnitKilled, parameters = {} } },
			}, rawTriggers, {}, {})

			local settings = rawTriggers['__objective_obj'].settings
			assert.is_true(settings.repeating)
			assert.is_nil(settings.maxRepeats)
		end)

		it("restricts the trigger to the stages the objective belongs to", function()
			local rawTriggers = {}
			objectivesLoader.ProcessRawObjectives({
				obj = { textKey = "ok", trigger = { type = triggerTypes.UnitKilled, parameters = {} } },
			}, rawTriggers, {}, {
				stageA = { objectives = { 'obj' } },
				stageB = { objectives = { 'obj' } },
			})

			local stages = rawTriggers['__objective_obj'].settings.stages
			table.sort(stages)
			assert.are.same({ 'stageA', 'stageB' }, stages)
		end)

		it("synthesizes nothing for objectives without a trigger", function()
			local rawTriggers, rawActions = {}, {}
			objectivesLoader.ProcessRawObjectives({
				obj = { textKey = "ok" },
			}, rawTriggers, rawActions, {})

			assert.are.same({}, rawTriggers)
			assert.are.same({}, rawActions)
		end)

		it("returns the objectives it was given", function()
			local objectives = { obj = { textKey = "ok" } }
			assert.are.equal(objectives, objectivesLoader.ProcessRawObjectives(objectives, {}, {}, {}))
		end)
	end)

	describe("managed objectives", function()
		it("registers statistics objectives instead of synthesizing a trigger and action", function()
			local rawTriggers, rawActions = {}, {}
			objectivesLoader.ProcessRawObjectives({
				ownBots = {
					textKey   = "own bots",
					amount    = 5,
					nextStage = 'stageB',
					trigger   = {
						type       = triggerTypes.UnitsOwned,
						parameters = { teamID = 0, unitName = 'bot' },
					},
				},
			}, rawTriggers, rawActions, { stageA = { objectives = { 'ownBots' } } })

			assert.are.same({}, rawTriggers)
			assert.are.same({}, rawActions)

			local managed = GG['MissionAPI'].ManagedObjectives[triggerTypes.UnitsOwned]
			assert.are.equal(1, #managed)
			assert.are.same({
				objectiveID = 'ownBots',
				amount      = 5,
				nextStage   = 'stageB',
				stages      = { 'stageA' },
				parameters  = { teamID = 0, unitName = 'bot' },
			}, managed[1])
		end)

		it("groups several managed objectives under their trigger type", function()
			objectivesLoader.ProcessRawObjectives({
				a = { textKey = "a", trigger = { type = triggerTypes.UnitsOwned, parameters = { teamID = 0 } } },
				b = { textKey = "b", trigger = { type = triggerTypes.UnitsOwned, parameters = { teamID = 1 } } },
			}, {}, {}, {})

			assert.are.equal(2, #GG['MissionAPI'].ManagedObjectives[triggerTypes.UnitsOwned])
		end)
	end)
end)
