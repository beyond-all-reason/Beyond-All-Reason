local Rules = VFS.Include("modules/transport/lib/rules.lua")

local function def(fields)
	fields.customParams = fields.customParams or {}
	return fields
end

describe("transport rules", function()
	describe("reach", function()
		it("is an air transport's business only, and a tech transport reaches further", function()
			assert.is_nil(Rules.Reach(def({ canFly = false, isTransport = true })))
			assert.is_nil(Rules.Reach(def({ canFly = true, isTransport = false })))
			assert.are.equal(20, Rules.Reach(def({ canFly = true, isTransport = true })))
			assert.are.equal(
				30,
				Rules.Reach(def({ canFly = true, isTransport = true, customParams = { techlevel = "2" } }))
			)
		end)

		it("gates the load on distance, and never for a ground transport", function()
			assert.is_true(Rules.WithinReach(19, 20))
			assert.is_false(Rules.WithinReach(21, 20))
			assert.is_true(Rules.WithinReach(500, nil))
		end)
	end)

	it("nothing loads or unloads under water", function()
		assert.is_true(Rules.Submerged(-30, 10))
		assert.is_false(Rules.Submerged(-5, 10))
		assert.is_true(Rules.Submerged(0, nil))
	end)

	it("a paratrooper keeps only a little of the carrier's momentum", function()
		assert.are.equal(10, Rules.ClampParatrooperVelocity(40))
		assert.are.equal(-10, Rules.ClampParatrooperVelocity(-40))
		assert.are.equal(3, Rules.ClampParatrooperVelocity(3))
	end)

	describe("what a carrier can take", function()
		local carrier = def({
			isTransport = true,
			transportSize = 3,
			minTransportSize = 0,
			transportMass = 2500,
			minTransportMass = 0,
		})

		it("answers by footprint and mass, the engine's way", function()
			assert.is_true(Rules.CanCarry(carrier, def({ xsize = 4, mass = 1000 })))
			assert.is_false(Rules.CanCarry(carrier, def({ xsize = 8, mass = 1000 })), "too wide")
			assert.is_false(Rules.CanCarry(carrier, def({ xsize = 4, mass = 3000 })), "too heavy")
			assert.is_false(Rules.CanCarry(carrier, def({ xsize = 4, mass = 1000, cantBeTransported = true })))
		end)

		it("counts what is already aboard", function()
			assert.is_true(Rules.CanCarry(carrier, def({ xsize = 4, mass = 1000 }), 1500))
			assert.is_false(Rules.CanCarry(carrier, def({ xsize = 4, mass = 1000 }), 1501))
		end)

		it("a full transport takes no more, when its def declares a capacity", function()
			local oneSeat = def({
				isTransport = true,
				transportSize = 3,
				minTransportSize = 0,
				transportMass = 2500,
				minTransportMass = 0,
				transportCapacity = 1,
			})
			assert.is_true(Rules.CanCarry(oneSeat, def({ xsize = 4, mass = 1000 }), 0, 0))
			assert.is_false(Rules.CanCarry(oneSeat, def({ xsize = 4, mass = 1000 }), 0, 1))
			assert.is_true(Rules.CanCarry(carrier, def({ xsize = 4, mass = 1000 }), 0, 5))
		end)

		it("a thing that is not a transport carries nothing", function()
			assert.is_false(Rules.CanCarry(def({ isTransport = false }), def({ xsize = 1, mass = 1 })))
		end)
	end)
end)
