local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function setup()
	local teams = {
		{ cap = 4, count = 4, ally = 1 },
		{ cap = 0, count = 0, ally = 1 },
	}
	local rules = {}
	local env = SpecEnv.new({
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
		},
		Spring = {
			GetTeamRulesParam = function(team, key)
				return rules[team] and rules[team][key]
			end,
			SetTeamRulesParam = function(team, key, value)
				rules[team] = rules[team] or {}
				rules[team][key] = value
			end,
			GetModOptions = function()
				return { maxunits = 2 }
			end,
			GetGameFrame = function()
				return 30
			end,
			GetGaiaTeamID = function()
				return 99
			end,
			GetTeamList = function()
				return { 1, 2 }
			end,
			GetTeamInfo = function(id, _)
				return id, 0, teams[id].dead or false, false, "", teams[id].ally
			end,
			GetTeamLuaAI = function(id)
				return teams[id].luaAI or ""
			end,
			GetPlayerList = function(id)
				return teams[id].inactive and {} or { id }
			end,
			GetPlayerInfo = function(id)
				return "player", true, false, id
			end,
			GetTeamMaxUnits = function(id)
				return teams[id].cap
			end,
			GetTeamUnitCount = function(id)
				return teams[id].count
			end,
			IsCheatingEnabled = function()
				return false
			end,
			TransferTeamMaxUnits = function(from, to, amount)
				if teams[from].cap - amount < teams[from].count then
					return false
				end
				teams[from].cap = teams[from].cap - amount
				teams[to].cap = teams[to].cap + amount
				return true
			end,
		},
	})
	SpecEnv.include(env, "luarules/gadgets/game_dynamic_maxunits.lua")
	env.gadget:Initialize()
	local dynamic = env.gadget
	env.gadget = {}
	SpecEnv.include(env, "luarules/gadgets/game_prevent_excessive_share.lua")
	local function give(id, capture, veto)
		if dynamic.AllowUnitTransfer then
			dynamic:AllowUnitTransfer(id, 1, 1, 2, capture or false)
		end
		if not env.gadget:AllowUnitTransfer(id, 1, 1, 2, capture or false) or veto then
			return false
		end
		teams[1].count = teams[1].count - 1
		teams[2].count = teams[2].count + 1
		if env.gadget.UnitGiven then
			env.gadget:UnitGiven(id, 1, 2, 1)
		end
		if dynamic.UnitGiven then
			dynamic:UnitGiven(id, 1, 2, 1)
		end
		return true
	end
	return teams, give, env, dynamic
end

describe("Sharing units with a depleted team cap", function()
	it("returns occupied capacity with units, stopping at the equal share", function()
		local teams, give = setup()
		assert.is_true(give(10))
		assert.same({ cap = 3, count = 3, ally = 1 }, teams[1])
		assert.same({ cap = 1, count = 1, ally = 1 }, teams[2])
		assert.is_true(give(11))
		assert.is_false(give(12))
		assert.equal(2, teams[1].cap)
		assert.equal(2, teams[2].cap)
	end)

	it("does not move capacity on a veto and can retry the same unit", function()
		local teams, give = setup()
		assert.is_false(give(10, false, true))
		assert.equal(4, teams[1].cap)
		assert.equal(0, teams[2].cap)
		assert.is_true(give(10))
		assert.equal(3, teams[1].cap)
		assert.equal(1, teams[2].cap)
	end)

	it("clears a vetoed request when the next attempt captures the unit", function()
		local teams, give = setup()
		assert.is_false(give(10, false, true))
		assert.is_true(give(10, true))
		assert.equal(4, teams[1].cap)
		assert.equal(0, teams[2].cap)
	end)

	it("uses the existing slot when take2 has already moved capacity", function()
		local teams, give = setup()
		teams[1].cap, teams[2].cap = 3, 1
		assert.is_true(give(10))
		assert.equal(3, teams[1].cap)
		assert.equal(1, teams[2].cap)
	end)

	it("only returns capacity between eligible live teammates", function()
		local teams, give, env = setup()
		teams[2].ally = 2
		assert.is_false(give(10))
		teams[2].ally, teams[2].inactive = 1, true
		assert.is_false(give(10))
		teams[2].inactive, teams[2].dead = false, true
		assert.is_false(give(10))
		teams[2].dead, teams[1].luaAI = false, "ScavengersAI"
		assert.is_false(give(10))
		teams[1].luaAI, teams[1].count = "", 5
		assert.is_false(give(10))
		teams[1].count = 4
		assert.is_true(give(10))
		env.GG.CanShareUnitCap = nil
		assert.is_false(give(11))
	end)
end)

describe("Restoring capacity after a take", function()
	it("waits for the first successful share even while the taken player stays connected", function()
		local teams, give, env, dynamic = setup()
		env.Spring.SetTeamRulesParam(2, "unitCapRestorePending", 1)
		teams[1].count = 2
		dynamic:GameFrame(30)
		assert.equal(0, teams[2].cap)
		assert.is_false(give(10, false, true))
		dynamic:GameFrame(60)
		assert.equal(0, teams[2].cap)
		assert.is_true(give(10))
		dynamic:GameFrame(90)
		assert.equal(2, teams[2].cap)
		assert.equal(2, teams[1].cap)
	end)

	it("unlocks with a share from a full donor and retries as capacity becomes available", function()
		local teams, give, env, dynamic = setup()
		env.Spring.SetTeamRulesParam(2, "unitCapRestorePending", 1)
		assert.is_true(give(10))
		assert.equal(0, env.Spring.GetTeamRulesParam(2, "unitCapRestorePending"))
		dynamic:GameFrame(30)
		assert.equal(1, teams[2].cap)
		teams[1].count = 2
		dynamic:GameFrame(60)
		assert.equal(2, teams[2].cap)
	end)

	it("does not unlock on capture or take, and waits again after another take", function()
		local teams, give, env, dynamic = setup()
		env.Spring.SetTeamRulesParam(2, "unitCapRestorePending", 1)
		teams[1].count = 2
		assert.is_true(give(10, true))
		dynamic:GameFrame(30)
		assert.equal(0, teams[2].cap)
		env.GG.IsTakingTeam = function()
			return true
		end
		assert.is_true(give(11))
		dynamic:GameFrame(60)
		assert.equal(1, env.Spring.GetTeamRulesParam(2, "unitCapRestorePending"))
		env.GG.IsTakingTeam = nil
		teams[2].count = 0
		teams[1].count = 2
		assert.is_true(give(12))
		assert.equal(0, env.Spring.GetTeamRulesParam(2, "unitCapRestorePending"))
		env.Spring.SetTeamRulesParam(2, "unitCapRestorePending", 1)
		dynamic:GameFrame(90)
		assert.equal(1, teams[2].cap)
	end)
end)
