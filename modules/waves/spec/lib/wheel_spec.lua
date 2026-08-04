local Wheel = VFS.Include("modules/waves/lib/wheel.lua")
local SeededRng = VFS.Include("modules/waves/spec/support/seeded_rng.lua")

local function input(overrides)
	local i = {
		techAnger = 50,
		waveTechAnger = 50,
		airStartAnger = 0,
		spawnChance = 1,
		tier2MinAnger = 5,
	}
	for key, value in pairs(overrides or {}) do
		i[key] = value
	end
	return i
end

---@param only string
local function armedFor(only)
	local state = { base = 0, air = 1, special = 1, basic = 1, small = 1, larger = 1, huge = 1, epic = 1 }
	state[only] = 0
	return state
end

describe("waves wheel", function()
	it("opens with every counter armed and none expired", function()
		local state = Wheel.New(SeededRng.New(1))
		for _, key in ipairs({ "air", "special", "basic", "small", "larger", "huge", "epic" }) do
			assert.is_true(state[key] > 0, key .. " should start on cooldown")
		end
	end)

	it("ages every counter, including the ones that did not fire", function()
		local state = { base = 3, air = 4, special = 5, basic = 6, small = 7, larger = 8, huge = 9, epic = 10 }
		Wheel.Tick(state)
		assert.are.same({ base = 2, air = 3, special = 4, basic = 5, small = 6, larger = 7, huge = 8, epic = 9 }, state)
	end)

	describe("the opening", function()
		it("is a trickle: both multipliers pinned under the anger fraction", function()
			local state = armedFor("epic")
			local shape = Wheel.Shape(state, input({ techAnger = 3, waveTechAnger = 3 }), SeededRng.New(7))
			assert.is.near(0.3, shape.sizeMultiplier, 1e-9)
			assert.is.near(0.3, shape.timeMultiplier, 1e-9)
			assert.are.equal(0, shape.specialPercentage)
			assert.are.equal(20, shape.airPercentage)
		end)

		it("claims the wave even when the base gate has not expired", function()
			local state = { base = 99, air = 0, special = 0, basic = 0, small = 0, larger = 0, huge = 0, epic = 0 }
			local shape = Wheel.Shape(state, input({ techAnger = 1, waveTechAnger = 1 }), SeededRng.New(3))
			assert.are.equal(20, shape.airPercentage)
			assert.are.equal(99, state.base)
		end)
	end)

	describe("flavors", function()
		it("does nothing at all while the base gate holds", function()
			local state = { base = 5, air = 0, special = 0, basic = 0, small = 0, larger = 0, huge = 0, epic = 0 }
			local shape = Wheel.Shape(state, input(), SeededRng.New(11))
			assert.are.equal(1, shape.sizeMultiplier)
			assert.are.equal(1, shape.timeMultiplier)
			assert.are.equal(0, state.air)
		end)

		it("air doubles the wave, halves the gap and fills half of it with aircraft", function()
			local state = armedFor("air")
			local shape = Wheel.Shape(state, input(), SeededRng.New(5))
			assert.are.equal(50, shape.airPercentage)
			assert.are.equal(0, shape.specialPercentage)
			assert.are.equal(2, shape.sizeMultiplier)
			assert.are.equal(0.5, shape.timeMultiplier)
			assert.is_true(state.air >= 0)
		end)

		it("air stays grounded below the air threshold, so no-air games never see it", function()
			local state = armedFor("air")
			local shape = Wheel.Shape(state, input({ airStartAnger = 10000 }), SeededRng.New(5))
			assert.are_not.equal(50, shape.airPercentage)
		end)

		it("epic is five times the size and two and a half times the gap", function()
			local state = armedFor("epic")
			local shape = Wheel.Shape(state, input({ airStartAnger = 10000 }), SeededRng.New(13))
			assert.are.equal(5, shape.sizeMultiplier)
			assert.are.equal(2.5, shape.timeMultiplier)
		end)

		it("small halves both — the breather between the big ones", function()
			local state = armedFor("small")
			local shape = Wheel.Shape(state, input({ airStartAnger = 10000 }), SeededRng.New(17))
			assert.are.equal(0.5, shape.sizeMultiplier)
			assert.are.equal(0.5, shape.timeMultiplier)
		end)

		it("the claiming flavor re-arms, so the same one cannot fire twice running", function()
			local state = armedFor("huge")
			Wheel.Shape(state, input({ airStartAnger = 10000 }), SeededRng.New(23))
			assert.is_true(state.huge >= 0)
			assert.is_true(state.base >= 0)
		end)

		it("declines every flavor when the spawn chance never lands", function()
			local state = { base = 0, air = 0, special = 0, basic = 0, small = 0, larger = 0, huge = 0, epic = 0 }
			local shape = Wheel.Shape(state, input({ spawnChance = 0 }), SeededRng.New(29))
			assert.are.equal(1, shape.sizeMultiplier)
			assert.are.equal(1, shape.timeMultiplier)
		end)
	end)

	it("carries the previous wave's composing anger through untouched", function()
		local shape =
			Wheel.Shape(armedFor("epic"), input({ waveTechAnger = 412, airStartAnger = 10000 }), SeededRng.New(31))
		assert.are.equal(412, shape.techAnger)
	end)

	it("is reproducible from a seed", function()
		local first = Wheel.Shape(armedFor("larger"), input(), SeededRng.New(99))
		local second = Wheel.Shape(armedFor("larger"), input(), SeededRng.New(99))
		assert.are.same(first, second)
	end)
end)
