---@type Builders
local Builders = VFS.Include("spec/builders/index.lua")

local function armed()
	local m = Builders.Mission.new():WithMission("cm8_ashfall"):Arm()
	return m, m:Includes()
end

describe("cm8_ashfall roster", function()
	it("every handle the story files reference stands in the world", function()
		local m, Units = armed()
		for _, handle in ipairs({ Units.hub, Units.beacon, Units.device, Units.armadaCommander, Units.playerCommander }) do
			assert.is_number(m:UnitOf(handle), handle.name)
		end
	end)

	it("claims both commanders, and knows where to build one if a seat is empty", function()
		local m, Units = armed()
		assert.is_true(m:Entry(Units.playerCommander).claim)
		assert.are.equal("player", m:Entry(Units.playerCommander).team)
		assert.is_true(m:Entry(Units.armadaCommander).claim)
		assert.are.equal("enemy", m:Entry(Units.armadaCommander).team)
		assert.are.equal(0.77, m:Entry(Units.armadaCommander).fx)
	end)

	it("binds the enemy commander to the one already standing", function()
		local m = Builders.Mission.new():WithMission("cm8_ashfall")
		local incumbent = m:WithExistingUnit(1, "armcom")
		m:Arm()
		local Units = m:Includes()
		assert.are.equal(incumbent, m:UnitOf(Units.armadaCommander))
	end)

	it("builds one when the seat is empty, and it belongs to the mission", function()
		local m, Units = armed()
		local enemy = m:TeamUnits("enemy")
		local commander = m:UnitOf(Units.armadaCommander)
		local built
		for _, unit in ipairs(enemy) do
			if unit.id == commander then
				built = unit
			end
		end
		assert.are.equal("armcom", built.def)
	end)

	it("the whole outpost starts inert on gaia, holding fire", function()
		local m = armed()
		local outpost = m:TeamUnits("gaia")
		assert.are.equal(6, #outpost)
		for _, unit in ipairs(outpost) do
			assert.is_true(unit.neutral, unit.def .. " must not be shot at before it is handed over")
			assert.is_true(unit.holdsFire, unit.def .. " must hold fire")
		end
	end)

	it("the enclave is hostile and nothing there is claimed", function()
		local m, Units = armed()
		assert.are.equal("enemy", m:Entry(Units.beacon).team)
		assert.are.equal("enemy", m:Entry(Units.device).team)
		assert.is_nil(m:Entry(Units.beacon).neutral)
		assert.is_nil(m:Entry(Units.hub).claim)
	end)

	it("the beacon sits on the enclave's rim, nearer than the device", function()
		-- A push from the outpost (0.42) meets the beacon first, so the
		-- discovery order is the objective order.
		local m, Units = armed()
		assert.is_true(m:Entry(Units.beacon).fx < m:Entry(Units.device).fx)
		assert.is_true(m:Entry(Units.beacon).fz < m:Entry(Units.device).fz)
	end)

	it("the protected hub travels with the transferred outpost group", function()
		local m, Units = armed()
		m:Spot(Units.hub):Step()
		local gives = {}
		for _, call in ipairs(m:Calls("transfer")) do
			if call.method == "Give" then
				gives[#gives + 1] = call
			end
		end
		assert.are.equal(1, #gives)
		assert.are.equal(6, #gives[1].args[1])
		assert.are.equal(0, gives[1].args[2])
		local hub = m:UnitOf(Units.hub)
		local moved = false
		for _, unitID in ipairs(gives[1].args[1]) do
			moved = moved or unitID == hub
		end
		assert.is_true(moved, "the hub is part of the group that changes hands")
	end)
end)
