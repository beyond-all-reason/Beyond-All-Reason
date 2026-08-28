local Boss = VFS.Include("modules/waves/lib/boss.lua")

describe("waves boss", function()
	describe("when a boss is due", function()
		it("is due when the countdown reaches a hundred", function()
			assert.is_true(Boss.IsDue(100, 8, 2000, 180))
			assert.is_false(Boss.IsDue(99, 8, 2000, 180))
		end)

		it("is due early when the map is down to one burrow well past grace", function()
			-- The escape hatch: the players won the attrition fight, so the
			-- director has no way left to spend its clock.
			assert.is_true(Boss.IsDue(20, 1, 300, 180))
			assert.is_true(Boss.IsDue(20, 0, 300, 180))
		end)

		it("does not take the escape hatch during or just after grace", function()
			assert.is_false(Boss.IsDue(20, 0, 100, 180))
			assert.is_false(Boss.IsDue(20, 0, 240, 180))
		end)

		it("stops once every boss of the cycle is out", function()
			assert.is_true(Boss.CanSpawnMore({ spawned = 2, killed = 0 }, { count = 3 }))
			assert.is_false(Boss.CanSpawnMore({ spawned = 3, killed = 0 }, { count = 3 }))
		end)
	end)

	describe("spawn health", function()
		it("scales with the roster clock", function()
			assert.are.equal(6000, Boss.SpawnHealth(10000, 60, 0.2))
		end)

		it("floors, so an early boss is still a boss", function()
			assert.are.equal(2000, Boss.SpawnHealth(10000, 5, 0.2))
		end)

		it("arrives at full health once the clock is past a hundred", function()
			assert.are.equal(10000, Boss.SpawnHealth(10000, 100, 0.2))
			assert.are.equal(20000, Boss.SpawnHealth(10000, 200, 0.2))
		end)
	end)

	describe("the shared health bar", function()
		it("is one number across every boss of the cycle", function()
			local percent = Boss.HealthPercent({
				["1"] = { health = 500, maxHealth = 1000 },
				["2"] = { health = 1000, maxHealth = 1000 },
			})
			assert.are.equal(75, percent)
		end)

		it("keeps dead bosses in the denominator, so killing one does not reset it", function()
			local percent = Boss.HealthPercent({
				["1"] = { isDead = true, maxHealth = 1000, health = 0 },
				["2"] = { health = 1000, maxHealth = 1000 },
			})
			assert.are.equal(50, percent)
		end)

		it("reports the alive maximum separately — the resistance denominator", function()
			local _, aliveMax = Boss.HealthPercent({
				["1"] = { isDead = true, maxHealth = 1000 },
				["2"] = { health = 400, maxHealth = 1000 },
			})
			assert.are.equal(1000, aliveMax)
		end)

		it("is zero, not a division by zero, before any boss exists", function()
			local percent, aliveMax = Boss.HealthPercent({})
			assert.are.equal(0, percent)
			assert.are.equal(0, aliveMax)
		end)
	end)

	it("calls the cycle complete only when every boss is down", function()
		assert.is_false(Boss.CycleComplete({ spawned = 3, killed = 2 }, { count = 3 }))
		assert.is_true(Boss.CycleComplete({ spawned = 3, killed = 3 }, { count = 3 }))
	end)

	it("opens with nothing spawned and nothing killed", function()
		local state = Boss.NewState()
		assert.are.equal(0, state.spawned)
		assert.are.equal(0, state.killed)
		assert.are.same({}, state.ids)
	end)
end)
