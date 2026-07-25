require("spec_helper")

local statistics = VFS.Include('luarules/mission_api/statistics.lua')

describe("mission_api.statistics", function()
	local triggers          -- triggerID -> trigger
	local activated         -- ordered list of activated triggers
	local objectiveUpdates  -- ordered list of managed-objective update calls

	-- Fakes injected in place of the gadget's trigger core:
	local function processTriggersOfType(triggerType, func)
		for triggerID, trigger in pairs(triggers) do
			if trigger.type == triggerType then
				func(trigger, triggerID)
			end
		end
	end

	local function activateTrigger(trigger)
		activated[#activated + 1] = trigger
		-- Mimic a valid repeating activation so milestone thresholds advance.
		trigger.triggered = true
		trigger.repeatCount = trigger.repeatCount + 1
		return true
	end

	local function makeTrigger(triggerType, parameters)
		return { type = triggerType, parameters = parameters, triggered = false, repeatCount = 0 }
	end

	before_each(function()
		triggers         = {}
		activated        = {}
		objectiveUpdates = {}
		GG['MissionAPI'] = {
			ManagedObjectives = {},
			Modules = {
				Objectives = {
					UpdateObjectiveProgress = function(objectiveID, teamID, unitDefName, unitNames, direction)
						objectiveUpdates[#objectiveUpdates + 1] = { objectiveID = objectiveID, direction = direction }
					end,
				},
			},
		}
		statistics.Init({ processTriggersOfType = processTriggersOfType, activateTrigger = activateTrigger })
	end)

	-- Note: statisticsTriggerCounts is module-private and persists for the whole
	-- run, so each test uses a unique triggerID to stay isolated.

	it("fires when the count reaches quantity", function()
		triggers.reach = makeTrigger(1, { teamID = 0, quantity = 2 })

		statistics.Increment(1, 0, 'armwar', {})
		assert.are.equal(0, #activated)

		statistics.Increment(1, 0, 'armwar', {})
		assert.are.equal(1, #activated)
	end)

	it("re-fires at each quantity milestone (2*q, 3*q, ...)", function()
		triggers.milestones = makeTrigger(1, { teamID = 0, quantity = 2 })

		for _ = 1, 6 do statistics.Increment(1, 0, 'armwar', {}) end

		-- milestones crossed at counts 2, 4, 6
		assert.are.equal(3, #activated)
	end)

	it("does not fire before the next milestone", function()
		triggers.partial = makeTrigger(1, { teamID = 0, quantity = 3 })

		statistics.Increment(1, 0, 'armwar', {})
		statistics.Increment(1, 0, 'armwar', {})
		assert.are.equal(0, #activated)
	end)

	it("with quantity 0, fires when the count returns to 0", function()
		triggers.zero = makeTrigger(1, { teamID = 0, quantity = 0 })

		-- quantity 0 uses count >= 0, so an increment already fires...
		statistics.Increment(1, 0, 'armwar', {})
		assert.are.equal(1, #activated)

		-- ...and the special case fires again when the count decrements back to 0.
		statistics.Decrement(1, 0, 'armwar', {})
		assert.are.equal(2, #activated)
	end)

	it("filters by teamID, unitDefName, and unitName", function()
		triggers.filterTeam  = makeTrigger(1, { teamID = 5, quantity = 1 })
		triggers.filterDef   = makeTrigger(1, { teamID = 0, quantity = 1, unitDefName = 'armcom' })
		triggers.filterNamed = makeTrigger(1, { teamID = 0, quantity = 1, unitName = 'boss' })

		-- Wrong team / wrong def / missing name: nothing matches.
		statistics.Increment(1, 0, 'armwar', {})
		assert.are.equal(0, #activated)

		-- Right team, matching def, and the required unit name is present.
		statistics.Increment(1, 0, 'armcom', { boss = true })
		assert.are.equal(2, #activated)
	end)

	it("forwards events to managed objectives even with no matching triggers", function()
		GG['MissionAPI'].ManagedObjectives[1] = { { objectiveID = 'obj' } }

		statistics.Increment(1, 0, 'armwar', {})

		assert.are.equal(1, #objectiveUpdates)
		assert.are.equal('obj', objectiveUpdates[1].objectiveID)
		assert.are.equal(1, objectiveUpdates[1].direction)
	end)
end)
