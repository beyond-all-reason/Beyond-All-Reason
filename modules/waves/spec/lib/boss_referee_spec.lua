local BossReferee = VFS.Include("modules/waves/lib/boss_referee.lua")

local function referee(overrides)
	local policy = { resistanceMult = 1, stagger = { health = 1000, time = 10 }, expectedBosses = 1 }
	for key, value in pairs(overrides or {}) do
		policy[key] = value
	end
	local r = BossReferee.New(policy)
	r.Track(7)
	r.UpdateHealth(function()
		return 10000, 10000
	end)
	return r
end

describe("the boss referee", function()
	it("shapes the fight: a healthy boss takes double, a dying one a quarter", function()
		-- the bank is seeded at five times the first hit, so even the first blow is resisted a tenth
		local r = referee()
		assert.are.equal(180, (r.Incoming(100, 1, 42, 1)))
		r.UpdateHealth(function()
			return 300, 10000
		end)
		local taken = r.Incoming(100, 1, 43, 1)
		assert.is_true(taken < 30, "expected a quarter or less, got " .. taken)
	end)

	it("caps unattributed and collision damage at a scratch", function()
		local r = referee()
		assert.are.equal(1, (r.Incoming(500, 1, nil, 1)))
		assert.is_near(2, (r.Incoming(500, -1, 42, 1)), 0.01)
	end)

	it("banks resistance per weapon and tells the UI once it crosses half", function()
		local r = referee()
		local notified = 0
		for _ = 1, 40 do
			local _, notify = r.Incoming(1000, 1, 42, 1)
			if notify then
				notified = notified + 1
			end
		end
		assert.are.equal(1, notified)
		assert.is_true(r.resistances["42"].percent > 0.5)
		local fresh = r.Incoming(100, 1, 43, 1)
		assert.is_true(
			fresh > (r.Incoming(100, 1, 42, 1)),
			"a fresh weapon is barely resisted; the old one nearly fully"
		)
	end)

	it("drains the stagger bank by the policy's divisor", function()
		local sqrt = referee({ expectedBosses = 4 })
		local linear = referee({ expectedBosses = 4, staggerDivisor = "linear" })
		sqrt.Incoming(100, 1, 42, 1)
		linear.Incoming(100, 1, 42, 1)
		assert.is_true(linear.stagger.currentHealth > sqrt.stagger.currentHealth, "linear drains slower against four")
	end)

	it("staggers when the bank empties, recovers, and escalates", function()
		local r = referee({ stagger = { health = 100, time = 3 } })
		r.Incoming(1000, 1, 42, 1)
		assert.is_true(r.stagger.currentHealth <= 0)
		local down = r.TickStagger()
		assert.is_true(down.down and down.active)
		-- The tick that took the boss down already counted one second.
		local up
		for _ = 1, 2 do
			up = r.TickStagger()
		end
		assert.is_true(up.up and not up.active)
		assert.are.equal(8, r.stagger.time)
		assert.is_near(110, r.stagger.health, 0.001)
	end)

	it("keeps the damage tally across cycles and nothing else", function()
		local r = referee()
		r.Incoming(100, 1, 42, 1)
		r.Tally(0, 100)
		r.NextCycle()
		assert.is_nil(next(r.resistances))
		assert.is_nil(next(r.statuses))
		assert.are.equal(100, r.playerDamages["0"])
	end)

	it("mirrors the curve for damage from the boss", function()
		local r = referee()
		assert.are.equal(25, r.Outgoing(100))
		r.UpdateHealth(function()
			return 300, 10000
		end)
		assert.are.equal(200, r.Outgoing(100))
	end)
end)
