require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

-- difficulty.lua reads the difficulties enum from Modules.ParameterTypes at include time.
RegisterMissionApiModules()
local difficulty = VFS.Include("luarules/mission_api/difficulty.lua")

-- Difficulties from luarules/mission_api/difficulties.json: Story = 1, Easy = 2, Medium = 3, Hard = 4.
local STORY, EASY, MEDIUM, HARD = 1, 2, 3, 4

describe("mission_api.difficulty", function()
	local function withDifficulty(currentDifficulty)
		GG["MissionAPI"] = {
			Difficulty = currentDifficulty,
			Modules = GG["MissionAPI"].Modules,
			ObjectiveTriggers = {},
			ManagedObjectives = {},
			Triggers = {},
		}
	end

	before_each(function()
		withDifficulty(0)
	end)

	-- Runs one wrapped value through ResolveActions and returns what it resolved to.
	local function resolveValue(wrapper, currentDifficulty)
		withDifficulty(currentDifficulty)
		local actions = { a = { parameters = { p = wrapper } } }
		difficulty.ResolveActions(actions)
		return actions.a.parameters.p
	end

	describe("IsDifficultiesTable", function()
		it("detects a table with a non-nil difficulties key", function()
			assert.is_true(difficulty.IsDifficultiesTable({ difficulties = { Easy = 1 } }))
		end)

		it("rejects plain values and tables without the key", function()
			assert.is_false(difficulty.IsDifficultiesTable(5))
			assert.is_false(difficulty.IsDifficultiesTable("Easy"))
			assert.is_false(difficulty.IsDifficultiesTable(nil))
			assert.is_false(difficulty.IsDifficultiesTable({ x = 100, z = 200, radius = 50 }))
		end)
	end)

	describe("resolution", function()
		it("leaves non-wrapped parameters unchanged", function()
			withDifficulty(HARD)
			local area = { x = 100, z = 200, radius = 50 }
			local actions = { a = { parameters = { n = 5, s = "bot", b = false, area = area } } }

			difficulty.ResolveActions(actions)

			local parameters = actions.a.parameters
			assert.are.equal(5, parameters.n)
			assert.are.equal("bot", parameters.s)
			assert.is_false(parameters.b)
			assert.are.equal(area, parameters.area)
		end)

		it("picks the exact difficulty when specified", function()
			assert.are.equal(20, resolveValue({ difficulties = { Easy = 10, Medium = 20, Hard = 30 } }, MEDIUM))
		end)

		it("falls back to the highest specified difficulty below the current one", function()
			assert.are.equal(20, resolveValue({ difficulties = { Easy = 10, Medium = 20 } }, HARD))
			assert.are.equal(10, resolveValue({ difficulties = { Easy = 10, Hard = 30 } }, MEDIUM))
		end)

		it("falls back to the lowest specified difficulty when playing below all of them", function()
			assert.are.equal(10, resolveValue({ difficulties = { Easy = 10, Medium = 20 } }, STORY))
		end)

		it("falls back to the lowest specified difficulty when no difficulty is set", function()
			assert.are.equal(10, resolveValue({ difficulties = { Easy = 10, Medium = 20 } }, nil))
		end)

		it("preserves false values", function()
			assert.is_false(resolveValue({ difficulties = { Easy = false, Hard = true } }, EASY))
		end)

		it("returns table values by reference", function()
			local easyArea = { x = 100, z = 200, radius = 50 }
			assert.are.equal(easyArea, resolveValue({ difficulties = { Easy = easyArea } }, EASY))
		end)
	end)

	describe("ResolveTriggers", function()
		it("resolves wrapped parameters in place and leaves plain ones alone", function()
			withDifficulty(HARD)
			local triggers = {
				t = {
					parameters = { seconds = { difficulties = { Easy = 60, Hard = 30 } }, interval = 5 },
					settings = {},
				},
			}

			difficulty.ResolveTriggers(triggers)

			assert.are.equal(30, triggers.t.parameters.seconds)
			assert.are.equal(5, triggers.t.parameters.interval)
		end)

		it("converts the settings difficulties array into a set keyed by difficulty", function()
			local triggers = {
				t = { settings = { difficulties = { "Easy", "Hard" } } },
			}

			difficulty.ResolveTriggers(triggers)

			assert.are.same({ [EASY] = true, [HARD] = true }, triggers.t.settings.difficulties)
		end)

		it("turns an empty difficulties array into no gate at all", function()
			local triggers = {
				t = { settings = { difficulties = {} } },
			}

			difficulty.ResolveTriggers(triggers)

			assert.is_nil(triggers.t.settings.difficulties)
		end)

		it("tolerates triggers without parameters", function()
			local triggers = { t = { settings = {} } }
			difficulty.ResolveTriggers(triggers)
			assert.are.same({ t = { settings = {} } }, triggers)
		end)
	end)

	describe("ResolveActions", function()
		it("resolves wrapped parameters in place", function()
			withDifficulty(EASY)
			local actions = {
				a = { parameters = { message = { difficulties = { Easy = "hi", Hard = "gl" } } } },
			}

			difficulty.ResolveActions(actions)

			assert.are.equal("hi", actions.a.parameters.message)
		end)
	end)

	describe("ResolveObjectives", function()
		it("resolves wrapped objective fields in place", function()
			withDifficulty(HARD)
			local objectives = {
				o = {
					textKey = { difficulties = { Easy = "easyText", Hard = "hardText" } },
					amount = { difficulties = { Easy = 2, Hard = 5 } },
				},
			}

			difficulty.ResolveObjectives(objectives)

			assert.are.equal("hardText", objectives.o.textKey)
			assert.are.equal(5, objectives.o.amount)
		end)

		it("resolves inline trigger parameters, in the same shared table", function()
			withDifficulty(MEDIUM)
			local parameters = { seconds = { difficulties = { Easy = 60, Medium = 45 } } }
			local objectives = { o = { trigger = { type = 1, parameters = parameters } } }

			difficulty.ResolveObjectives(objectives)

			assert.are.equal(45, parameters.seconds)
		end)

		it("fills in the maxRepeats that the loader derived from a wrapped amount", function()
			withDifficulty(HARD)
			GG["MissionAPI"].ObjectiveTriggers.o = "__objective_o"
			GG["MissionAPI"].Triggers.__objective_o = { settings = { repeating = true } }
			local objectives = { o = { amount = { difficulties = { Easy = 2, Hard = 4 } } } }

			difficulty.ResolveObjectives(objectives)

			assert.are.equal(4, objectives.o.amount)
			assert.are.equal(3, GG["MissionAPI"].Triggers.__objective_o.settings.maxRepeats)
		end)

		it("resolves wrapped amount and nextStage in managed objective metadata", function()
			withDifficulty(HARD)
			GG["MissionAPI"].ManagedObjectives = {
				[7] = {
					{
						objectiveID = "kills",
						amount = { difficulties = { Easy = 2, Hard = 5 } },
						nextStage = { difficulties = { Easy = "s1", Hard = "s2" } },
					},
				},
			}

			difficulty.ResolveObjectives({})

			local metadata = GG["MissionAPI"].ManagedObjectives[7][1]
			assert.are.equal(5, metadata.amount)
			assert.are.equal("s2", metadata.nextStage)
		end)

		it("leaves the trigger field itself untouched, even when wrapper-shaped", function()
			local trigger = { difficulties = { Easy = { type = 1 } } }
			local objectives = { o = { trigger = trigger } }

			difficulty.ResolveObjectives(objectives)

			assert.are.equal(trigger, objectives.o.trigger)
		end)

		it("tolerates non-table objectives", function()
			difficulty.ResolveObjectives({ bad = "nope" })
		end)
	end)
end)
