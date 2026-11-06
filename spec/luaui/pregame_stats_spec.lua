describe("Pregame statistics LuaUI wrapper", function()
	local spring, offsets, args
	before_each(function()
		offsets = { pregameUnitsProduced = -3, pregameUnitsDied = -3 }
		spring = {
			GetTeamRulesParam = function(_, key)
				return offsets[key]
			end,
			GetTeamStatsHistory = function(team, ...)
				args = { n = select("#", ...), ... }
				if team == -1 then
					return nil
				end
				if args.n > 1 and args[1] and args[1] > args[2] then
					return {}
				end
				if args.n == 0 then
					return 2
				end
				return {
					{ frame = 0, unitsProduced = 4, unitsDied = 3, unitsKilled = 0, metalUsed = 10 },
					{ frame = 450, unitsProduced = 5, unitsDied = 4, unitsKilled = 1, metalUsed = 20 },
				}
			end,
		}
		setfenv(assert(loadfile("luaui/Include/pregame_stats.lua")), { Spring = spring, type = type, ipairs = ipairs })()
	end)

	it("preserves count queries, unavailable teams and explicit nil arguments", function()
		assert.equal(2, spring.GetTeamStatsHistory(0))
		assert.is_nil(spring.GetTeamStatsHistory(-1, 0, 2))
		assert.is_table(spring.GetTeamStatsHistory(0, nil))
		assert.equal(1, args.n)
		spring.GetTeamStatsHistory(0, nil, 2)
		assert.equal(2, args.n)
		assert.is_nil(args[1])
		assert.equal(2, args[2])
	end)

	it("corrects the full Gex history export while preserving genuine later losses", function()
		local history = spring.GetTeamStatsHistory(0, 0, spring.GetTeamStatsHistory(0))
		assert.same({ 0, 2, n = 2 }, args)
		assert.same({
			{ frame = 0, unitsProduced = 1, unitsDied = 0, unitsKilled = 0, metalUsed = 10 },
			{ frame = 450, unitsProduced = 2, unitsDied = 1, unitsKilled = 1, metalUsed = 20 },
		}, history)
		assert.same(history, spring.GetTeamStatsHistory(0, 0, 2))
	end)

	it("passes through games without proxies and keeps empty results empty", function()
		offsets = {}
		local history = spring.GetTeamStatsHistory(0, 1)
		assert.equal(4, history[1].unitsProduced)
		assert.equal(3, history[1].unitsDied)
		assert.same({}, spring.GetTeamStatsHistory(0, 2, 1))
	end)
end)
