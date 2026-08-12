require("spec_helper")

GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}

local objectives = VFS.Include('luarules/mission_api/objectives.lua')
local objectivesLoader = VFS.Include('luarules/mission_api/objectives_loader.lua')

describe("mission_api.objectives", function()

	local stageChanges, invokedActions

	before_each(function()
		stageChanges = {}
		invokedActions = {}

		GG['MissionAPI'].Stages = {
			first = { objectives = { 'alpha', 'beta' } },
		}
		GG['MissionAPI'].CurrentStageID = 'first'
		GG['MissionAPI'].Objectives = {}

		GG['MissionAPI'].Modules.Stages = {
			GetCurrentStageID = function() return GG['MissionAPI'].CurrentStageID end,
			GetStage = function(stageID) return GG['MissionAPI'].Stages[stageID] end,
			ChangeStage = function(stageID) stageChanges[#stageChanges + 1] = stageID end,
		}
		GG['MissionAPI'].Modules.ActionsDispatcher = {
			Invoke = function(actionID) invokedActions[#invokedActions + 1] = actionID end,
		}
	end)

	local function objective(fields)
		fields.completed = fields.completed or false
		fields.progress = fields.progress or 0
		return fields
	end

	describe("Complete", function()
		it("marks the objective completed", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 1 })

			objectives.Complete('alpha')

			assert.is_true(GG['MissionAPI'].Objectives.alpha.completed)
		end)

		it("sets progress to the target", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 3 })

			objectives.Complete('alpha')

			assert.are.equal(3, GG['MissionAPI'].Objectives.alpha.progress)
		end)

		it("runs onComplete actions", function()
			GG['MissionAPI'].Objectives.alpha = objective({
				textKey = 'a', target = 1,
				onComplete = { actions = { 'spawnStuff', 'playSound' } },
			})

			objectives.Complete('alpha')

			assert.are.same({ 'spawnStuff', 'playSound' }, invokedActions)
		end)

		it("is idempotent: a completed objective never completes twice", function()
			GG['MissionAPI'].Objectives.alpha = objective({
				textKey = 'a', target = 1,
				onComplete = { actions = { 'once' } },
			})

			objectives.Complete('alpha')
			objectives.Complete('alpha')

			assert.are.same({ 'once' }, invokedActions)
		end)

		it("ignores an unknown objective", function()
			assert.has_no.errors(function() objectives.Complete('nope') end)
		end)
	end)

	describe("stage advancement", function()
		it("advances when every objective sharing the nextStage is complete", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 1, onComplete = { nextStage = 'second' } })
			GG['MissionAPI'].Objectives.beta  = objective({ textKey = 'b', target = 1, onComplete = { nextStage = 'second' } })

			objectives.Complete('alpha')
			assert.are.same({}, stageChanges)

			objectives.Complete('beta')
			assert.are.same({ 'second' }, stageChanges)
		end)

		it("does not advance when the objective has no nextStage", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 1 })
			GG['MissionAPI'].Objectives.beta  = objective({ textKey = 'b', target = 1 })

			objectives.Complete('alpha')
			objectives.Complete('beta')

			assert.are.same({}, stageChanges)
		end)

		it("ignores objectives heading to a different nextStage", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 1, onComplete = { nextStage = 'second' } })
			GG['MissionAPI'].Objectives.beta  = objective({ textKey = 'b', target = 1, onComplete = { nextStage = 'third' } })

			objectives.Complete('alpha')

			assert.are.same({ 'second' }, stageChanges)
		end)
	end)

	describe("ReportProgress", function()
		it("records progress", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 5 })

			objectives.ReportProgress('alpha', 2)

			assert.are.equal(2, GG['MissionAPI'].Objectives.alpha.progress)
		end)

		it("does not report progress for a completed objective", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 5 })
			objectives.Complete('alpha')

			objectives.ReportProgress('alpha', 2)

			assert.are.equal(5, GG['MissionAPI'].Objectives.alpha.progress)
		end)
	end)

	describe("Update", function()
		it("completes when told to", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 1 })

			objectives.Update('alpha', true, nil)

			assert.is_true(GG['MissionAPI'].Objectives.alpha.completed)
		end)

		it("changes the textKey without completing", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 1 })

			objectives.Update('alpha', false, 'newText')

			assert.are.equal('newText', GG['MissionAPI'].Objectives.alpha.textKey)
			assert.is_false(GG['MissionAPI'].Objectives.alpha.completed)
		end)

		it("does nothing to an already completed objective", function()
			GG['MissionAPI'].Objectives.alpha = objective({ textKey = 'a', target = 1 })
			objectives.Complete('alpha')

			objectives.Update('alpha', false, 'newText')

			assert.are.equal('a', GG['MissionAPI'].Objectives.alpha.textKey)
		end)
	end)
end)

describe("mission_api.objectives_loader", function()

	local function load(rawObjectives, stages)
		local rawTriggers = {}
		local result = objectivesLoader.ProcessRawObjectives(rawObjectives, rawTriggers, {}, stages or {})
		return result, rawTriggers
	end

	it("contributes a condition record per objective", function()
		local _, rawTriggers = load({
			alpha = { textKey = 'a', type = 1, parameters = { seconds = 3 } },
		})

		assert.is_not_nil(rawTriggers['__objective_alpha'])
	end)

	it("copies the condition and its threshold onto the record", function()
		local _, rawTriggers = load({
			alpha = { textKey = 'a', type = 7, parameters = { teamID = 0 }, count = 3 },
		})
		local record = rawTriggers['__objective_alpha']

		assert.are.equal(7, record.type)
		assert.are.same({ teamID = 0 }, record.parameters)
		assert.are.equal(3, record.count)
	end)

	it("carries metric bounds onto the record", function()
		local _, rawTriggers = load({
			alpha = { textKey = 'a', type = 7, parameters = {}, atMost = 0 },
		})

		assert.are.equal(0, rawTriggers['__objective_alpha'].atMost)
	end)

	it("gives the record onActivate instead of actions", function()
		local _, rawTriggers = load({
			alpha = { textKey = 'a', type = 1, parameters = {} },
		})
		local record = rawTriggers['__objective_alpha']

		assert.is_function(record.onActivate)
		assert.is_nil(record.actions)
	end)

	it("restricts the record to the stages its objective appears in", function()
		local _, rawTriggers = load(
			{ alpha = { textKey = 'a', type = 1, parameters = {} } },
			{ first = { objectives = { 'alpha' } }, second = { objectives = { 'alpha' } } }
		)
		local stages = rawTriggers['__objective_alpha'].settings.stages
		table.sort(stages)

		assert.are.same({ 'first', 'second' }, stages)
	end)

	it("initialises runtime bookkeeping on the objective", function()
		local result = load({
			alpha = { textKey = 'a', type = 1, parameters = {}, count = 4 },
		})

		assert.is_false(result.alpha.completed)
		assert.are.equal(0, result.alpha.progress)
		assert.are.equal(4, result.alpha.target)
	end)

	it("targets the metric bound when there is no count", function()
		local byAtLeast = load({ a = { textKey = 'a', type = 1, parameters = {}, atLeast = 9 } })
		local byAtMost  = load({ b = { textKey = 'b', type = 1, parameters = {}, atMost = 0 } })

		assert.are.equal(9, byAtLeast.a.target)
		assert.are.equal(0, byAtMost.b.target)
	end)

	it("targets a single occurrence for an event with no count", function()
		-- Otherwise completing it would report a nil target and nil progress.
		local result = load({ once = { textKey = 'a', type = 1, parameters = {} } })

		assert.are.equal(1, result.once.target)
	end)

	it("skips entries that declare no condition type", function()
		local _, rawTriggers = load({ alpha = { textKey = 'a' } })

		assert.is_nil(rawTriggers['__objective_alpha'])
	end)
end)
