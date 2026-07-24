local ModuleHandler = VFS.Include("modules/module_handler.lua")

-- Load the real pipeline through the real loader — the spec covers both the
-- decision logic and the registration path.
ModuleHandler.ResetCaches()
local pipeline = ModuleHandler.LoadPolicies("matchflow").game_over

---@param opts table
local function makeCtx(opts)
	return {
		infos = opts.infos or {},
		scriptedWinners = opts.scriptedWinners,
		fixedallies = opts.fixedallies or false,
		sharedDynamicAllianceVictory = opts.sharedDynamicAllianceVictory or false,
		AreTeamsAllied = opts.AreTeamsAllied or function()
			return false
		end,
	}
end

local function ally(dead, teams)
	local info = { dead = dead, teams = {} }
	for _, teamID in ipairs(teams or {}) do
		info.teams[teamID] = {}
	end
	return info
end

describe("matchflow game_over pipeline", function()
	it("registers a MissionOverride gate and a LastAllyStanding terminal", function()
		assert.are.equal(2, #pipeline)
		assert.are.equal("MissionOverride", pipeline[1].name)
		assert.are.equal("LastAllyStanding", pipeline[2].name)
		assert.are.equal("game_over", pipeline[1].category)
	end)

	describe("MissionOverride", function()
		it("wins immediately with a scripted verdict, even with many alive", function()
			local verdict = ModuleHandler.Evaluate(pipeline, makeCtx({
				scriptedWinners = { 1 },
				infos = { [0] = ally(false), [1] = ally(false), [2] = ally(false) },
			}))
			assert.are.same({ winners = { 1 } }, verdict)
		end)
	end)

	describe("LastAllyStanding, single-ally mode", function()
		it("continues while more than one allyteam is alive", function()
			local verdict = ModuleHandler.Evaluate(pipeline, makeCtx({
				infos = { [0] = ally(false), [1] = ally(false) },
			}))
			assert.are.same({ continue = true }, verdict)
		end)

		it("declares the last living allyteam the winner", function()
			local verdict = ModuleHandler.Evaluate(pipeline, makeCtx({
				infos = { [0] = ally(false), [1] = ally(true) },
			}))
			assert.are.same({ winners = { 0 } }, verdict)
		end)

		it("declares a draw (empty winners) when everyone is dead", function()
			local verdict = ModuleHandler.Evaluate(pipeline, makeCtx({
				infos = { [0] = ally(true), [1] = ally(true) },
			}))
			assert.are.same({ winners = {} }, verdict)
		end)

		it("is forced by fixedallies even when shared victory is on", function()
			local verdict = ModuleHandler.Evaluate(pipeline, makeCtx({
				fixedallies = true,
				sharedDynamicAllianceVictory = true,
				infos = { [0] = ally(false), [1] = ally(false) },
			}))
			assert.are.same({ continue = true }, verdict)
		end)
	end)

	describe("LastAllyStanding, shared-dynamic-alliance mode", function()
		it("continues while living allyteams are not mutually allied", function()
			local verdict = ModuleHandler.Evaluate(pipeline, makeCtx({
				sharedDynamicAllianceVictory = true,
				infos = { [0] = ally(false, { 10 }), [1] = ally(false, { 11 }) },
			}))
			assert.are.same({ continue = true }, verdict)
		end)

		it("returns the legacy winner COUNT when all living allyteams are mutually allied", function()
			-- Quirk preserved from game_end.lua: the shared path ships a count,
			-- not a list (the list was built and commented out upstream).
			local verdict = ModuleHandler.Evaluate(pipeline, makeCtx({
				sharedDynamicAllianceVictory = true,
				AreTeamsAllied = function()
					return true
				end,
				infos = { [0] = ally(false, { 10 }), [1] = ally(false, { 11 }) },
			}))
			assert.are.same({ winners = 2 }, verdict)
		end)
	end)
end)
