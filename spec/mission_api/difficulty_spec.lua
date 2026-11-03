local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

local difficulty = MissionSpecEnv.registerModules(env).Difficulty ---@type table

-- Difficulties from luarules/mission_api/difficulties.json: Story = 1, Easy = 2, Medium = 3, Hard = 4.
local STORY, EASY, MEDIUM, HARD = 1, 2, 3, 4

describe("mission_api.difficulty", function()
	local function withDifficulty(currentDifficulty)
		GG["MissionAPI"] = {
			Difficulty = currentDifficulty,
			Modules = GG["MissionAPI"].Modules,
			ObjectiveTriggers = {},
			Triggers = {},
		}
	end

	before_each(function()
		withDifficulty(STORY)
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

	describe("FromName", function()
		local savedLog, logged

		before_each(function()
			savedLog = env.Spring.Log
			logged = {}
			env.Spring.Log = function(_, level, message)
				logged[#logged + 1] = { level = level, message = message }
			end
		end)

		after_each(function()
			env.Spring.Log = savedLog
		end)

		it("returns the difficulty with that name", function()
			assert.are.equal(STORY, difficulty.FromName("Story"))
			assert.are.equal(EASY, difficulty.FromName("Easy"))
			assert.are.equal(MEDIUM, difficulty.FromName("Medium"))
			assert.are.equal(HARD, difficulty.FromName("Hard"))
			assert.are.same({}, logged)
		end)

		it("returns the lowest difficulty without logging when no name is given", function()
			assert.are.equal(STORY, difficulty.FromName(nil))
			assert.are.same({}, logged)
		end)

		it("logs an unknown name and returns the lowest difficulty", function()
			assert.are.equal(STORY, difficulty.FromName("Nightmare"))
			assert.are.same({ { level = LOG.ERROR, message = "[Mission API] Unknown difficulty: Nightmare" } }, logged)
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

		it("resolves wrapped thresholds on the trigger itself", function()
			withDifficulty(HARD)
			local triggers = {
				t = { count = { difficulties = { Easy = 2, Hard = 6 } }, atMost = 10, settings = {} },
			}

			difficulty.ResolveTriggers(triggers)

			assert.are.equal(6, triggers.t.count)
			assert.are.equal(10, triggers.t.atMost)
		end)

		it("converts the settings difficulties names into difficulty values in place", function()
			local triggers = {
				t = { settings = { difficulties = { "Easy", "Hard" } } },
			}

			difficulty.ResolveTriggers(triggers)

			assert.are.same({ EASY, HARD }, triggers.t.settings.difficulties)
		end)

		it("leaves an empty difficulties setting empty", function()
			local triggers = {
				t = { settings = { difficulties = {} } },
			}

			difficulty.ResolveTriggers(triggers)

			assert.are.same({}, triggers.t.settings.difficulties)
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
					nextStage = { difficulties = { Easy = "s1", Hard = "s2" } },
				},
			}

			difficulty.ResolveObjectives(objectives)

			assert.are.equal("hardText", objectives.o.textKey)
			assert.are.equal("s2", objectives.o.nextStage)
		end)

		it("resolves inline condition parameters, in the same shared table", function()
			withDifficulty(MEDIUM)
			local parameters = { seconds = { difficulties = { Easy = 60, Medium = 45 } } }
			local objectives = { o = { type = 1, parameters = parameters } }

			difficulty.ResolveObjectives(objectives)

			assert.are.equal(45, parameters.seconds)
		end)

		it("copies a wrapped count onto the objective's condition record and target", function()
			withDifficulty(HARD)
			GG["MissionAPI"].ObjectiveTriggers.o = "__objective_o"
			GG["MissionAPI"].Triggers.__objective_o = { settings = {} }
			local objectives = { o = { type = 1, count = { difficulties = { Easy = 2, Hard = 4 } } } }

			difficulty.ResolveObjectives(objectives)

			assert.are.equal(4, objectives.o.count)
			assert.are.equal(4, objectives.o.target)
			assert.are.equal(4, GG["MissionAPI"].Triggers.__objective_o.count)
		end)

		it("copies wrapped metric bounds onto the condition record", function()
			withDifficulty(EASY)
			GG["MissionAPI"].ObjectiveTriggers.o = "__objective_o"
			GG["MissionAPI"].Triggers.__objective_o = { settings = {} }
			local objectives = { o = { type = 1, atLeast = { difficulties = { Easy = 500, Hard = 2000 } } } }

			difficulty.ResolveObjectives(objectives)

			local record = GG["MissionAPI"].Triggers.__objective_o
			assert.are.equal(500, record.atLeast)
			assert.is_nil(record.atMost)
			assert.are.equal(500, objectives.o.target)
		end)

		it("sets a target of one on an objective without a condition", function()
			local objectives = { o = { textKey = "t" } }

			difficulty.ResolveObjectives(objectives)

			assert.are.equal(1, objectives.o.target)
		end)

		describe("ResolveCutscenes", function()
			it("resolves wrapped cutscene fields in place and leaves plain ones alone", function()
				withDifficulty(HARD)
				local cutscenes = {
					intro = { videoFile = { difficulties = { Easy = "videos/easy.mp4", Hard = "videos/hard.mp4" } } },
					landing = { script = "landingParty" },
				}

				difficulty.ResolveCutscenes(cutscenes)

				assert.are.same({
					intro = { videoFile = "videos/hard.mp4" },
					landing = { script = "landingParty" },
				}, cutscenes)
			end)
		end)
	end)
end)
