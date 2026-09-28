require("spec_helper")

local difficulty = VFS.Include("luarules/mission_api/difficulty.lua")

-- Ranks from luarules/mission_api/difficulties.json: Story = 1, Easy = 2, Medium = 3, Hard = 4.
local STORY, EASY, MEDIUM, HARD = 1, 2, 3, 4

describe("mission_api.difficulty", function()
	local function withDifficulty(rank)
		GG["MissionAPI"] = { Difficulty = rank }
	end

	before_each(function()
		withDifficulty(0)
	end)

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

	describe("Resolve", function()
		it("returns non-wrapped values unchanged", function()
			assert.are.equal(5, difficulty.Resolve(5))
			assert.are.equal("bot", difficulty.Resolve("bot"))
			assert.is_false(difficulty.Resolve(false))
			local area = { x = 100, z = 200, radius = 50 }
			assert.are.equal(area, difficulty.Resolve(area))
		end)

		it("picks the exact difficulty when specified", function()
			withDifficulty(MEDIUM)
			assert.are.equal(20, difficulty.Resolve({ difficulties = { Easy = 10, Medium = 20, Hard = 30 } }))
		end)

		it("falls back to the nearest specified difficulty below", function()
			withDifficulty(HARD)
			assert.are.equal(20, difficulty.Resolve({ difficulties = { Easy = 10, Medium = 20 } }))
			withDifficulty(MEDIUM)
			assert.are.equal(10, difficulty.Resolve({ difficulties = { Easy = 10, Hard = 30 } }))
		end)

		it("falls back to the lowest specified difficulty when playing below all of them", function()
			withDifficulty(STORY)
			assert.are.equal(10, difficulty.Resolve({ difficulties = { Easy = 10, Medium = 20 } }))
		end)

		it("falls back to the lowest specified difficulty when no difficulty is set", function()
			withDifficulty(0)
			assert.are.equal(10, difficulty.Resolve({ difficulties = { Easy = 10, Medium = 20 } }))
		end)

		it("ignores unknown difficulty names", function()
			withDifficulty(HARD)
			assert.are.equal(10, difficulty.Resolve({ difficulties = { Easy = 10, Bogus = 99 } }))
			assert.is_nil(difficulty.Resolve({ difficulties = { Bogus = 99 } }))
		end)

		it("preserves false values", function()
			withDifficulty(EASY)
			assert.is_false(difficulty.Resolve({ difficulties = { Easy = false, Hard = true } }))
		end)

		it("returns table values by reference", function()
			withDifficulty(EASY)
			local easyArea = { x = 100, z = 200, radius = 50 }
			assert.are.equal(easyArea, difficulty.Resolve({ difficulties = { Easy = easyArea } }))
		end)

		it("returns nil for a malformed wrapper instead of raising", function()
			assert.is_nil(difficulty.Resolve({ difficulties = 5 }))
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

		it("rekeys the settings difficulties gate from names to ranks, keeping the values", function()
			local triggers = {
				t = { settings = { difficulties = { Easy = true, Hard = false } } },
			}

			difficulty.ResolveTriggers(triggers)

			assert.are.same({ [EASY] = true, [HARD] = false }, triggers.t.settings.difficulties)
		end)

		it("drops unknown difficulty names from the settings gate", function()
			local triggers = {
				t = { settings = { difficulties = { Bogus = true, Easy = true } } },
			}

			difficulty.ResolveTriggers(triggers)

			assert.are.same({ [EASY] = true }, triggers.t.settings.difficulties)
		end)

		it("tolerates triggers without parameters or settings", function()
			local triggers = { t = {} }
			difficulty.ResolveTriggers(triggers)
			assert.are.same({ t = {} }, triggers)
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
