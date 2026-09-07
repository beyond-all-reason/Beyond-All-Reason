require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

-- The loader is the authority on what a trigger looks like once a mission is running,
-- so the builder is checked against it rather than against a copy of its defaults.
local triggersLoader = VFS.Include("luarules/mission_api/triggers_loader.lua")

describe("TriggerBuilder", function()
	it("builds the trigger shape the call-in handlers receive", function()
		local trigger = Builders.Trigger.new():Build()

		assert.are.same({}, trigger.parameters)
		assert.are.same({
			prerequisites = {},
			repeating = false,
			coop = false,
			active = true,
			stages = {},
		}, trigger.settings)
		assert.is_false(trigger.triggered)
		assert.are.equal(0, trigger.repeatCount)
	end)

	it("normalises exactly as triggers_loader does, so fixtures cannot drift from it", function()
		local builder = Builders.Trigger.new():WithParameters({ unitDefName = "armpw" })
		builder:WithSettings({ maxRepeats = 2 })

		local loaded = triggersLoader.ProcessRawTriggers({ t = builder:BuildRaw() })

		assert.are.same(loaded.t, builder:Build())
	end)

	it("normalises a repeating, inactive trigger as the loader does", function()
		local builder = Builders.Trigger.new():WithSettings({ repeating = true, active = false })

		local loaded = triggersLoader.ProcessRawTriggers({ t = builder:BuildRaw() })

		assert.are.same(loaded.t, builder:Build())
	end)

	it("collects parameters and settings", function()
		local builder = Builders.Trigger.new():WithParameters({ unitDefName = "armpw" })
		builder:WithParameters({ teamID = 0 }):WithSettings({ repeating = true, maxRepeats = 2 })

		local trigger = builder:Build()

		assert.are.same({ unitDefName = "armpw", teamID = 0 }, trigger.parameters)
		assert.is_true(trigger.settings.repeating)
		assert.are.equal(2, trigger.settings.maxRepeats)
	end)

	it("ignores a nil parameter table, for specs that build a bare trigger", function()
		assert.are.same({}, Builders.Trigger.new():WithParameters(nil):Build().parameters)
	end)

	it("leaves the raw table as a mission declares it, before the loader fills it in", function()
		local raw = Builders.Trigger.new():WithParameters({ teamID = 0 }):BuildRaw()

		assert.are.same({ teamID = 0 }, raw.parameters)
		assert.are.same({}, raw.settings)
		assert.is_nil(raw.triggered)
	end)

	it("gives each built trigger its own tables", function()
		local builder = Builders.Trigger.new():WithParameters({ teamID = 0 })
		local first = builder:Build()
		local second = builder:Build()

		first.parameters.teamID = 9
		first.settings.stages[1] = "briefing"

		assert.are.equal(0, second.parameters.teamID)
		assert.are.same({}, second.settings.stages)
	end)
end)
