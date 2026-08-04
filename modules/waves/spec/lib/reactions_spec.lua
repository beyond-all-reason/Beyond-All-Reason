local Reactions = VFS.Include("modules/waves/lib/reactions.lua")

local function always()
	return 0
end

local function never()
	return 1
end

local POLICY = Reactions.Policy({
	skirmish = { spiker = { chance = 0.5, distance = 270 } },
	coward = { healer = { chance = 1, distance = 500 } },
	berserk = { assault = { chance = 0.2, distance = 1500, teleport = true, teleportCooldown = 10 } },
})

describe("wave reactions", function()
	it("fills the dials a policy leaves out", function()
		local policy = Reactions.Policy({})
		assert.are.equal(2, policy.timeout)
		assert.are.equal(30, policy.fleeSeconds)
		assert.are.equal(0.8, policy.cowardHealthFraction)
		assert.are.same({}, policy.skirmish)
	end)

	it("a skirmisher that landed a hit backs off", function()
		local decision = Reactions.Decide(POLICY, { attackerDef = "spiker", attackerIsWave = true }, always)
		assert.are.equal("flee", decision.kind)
		assert.are.equal("attacker", decision.actor)
		assert.are.equal(270, decision.record.distance)
	end)

	it("a berserker charges from either side of the hit", function()
		local landed = Reactions.Decide(POLICY, { attackerDef = "assault", attackerIsWave = true }, always)
		assert.are.equal("charge", landed.kind)
		assert.are.equal("attacker", landed.actor)
		local taken = Reactions.Decide(POLICY, { unitDef = "assault", unitIsWave = true }, always)
		assert.are.equal("charge", taken.kind)
		assert.are.equal("unit", taken.actor)
	end)

	it("a coward runs only below its health line, but the hit still counts as answered", function()
		local hurt = Reactions.Decide(POLICY, { unitDef = "healer", unitIsWave = true, healthFraction = 0.5 }, always)
		assert.are.equal("flee", hurt.kind)
		local fine = Reactions.Decide(POLICY, { unitDef = "healer", unitIsWave = true, healthFraction = 0.9 }, always)
		assert.are.equal("none", fine.kind)
	end)

	it("the dice can say no", function()
		assert.is_nil(Reactions.Decide(POLICY, { attackerDef = "spiker", attackerIsWave = true }, never))
	end)

	it("a def with no reaction provokes nothing", function()
		assert.is_nil(Reactions.Decide(POLICY, { unitDef = "tank", unitIsWave = true, attackerDef = "tank" }, always))
	end)

	it("only the director's own units react", function()
		assert.is_nil(Reactions.Decide(POLICY, { attackerDef = "spiker", attackerIsWave = false }, always))
	end)

	it("flees away from the source by roughly the record's distance", function()
		local tx, tz = Reactions.FleeTarget({ distance = 100 }, 0, 0, 0, -100, function(lo, hi)
			return hi
		end)
		assert.is_near(0, tx, 0.001)
		assert.is_near(125, tz, 0.001)
	end)
end)
