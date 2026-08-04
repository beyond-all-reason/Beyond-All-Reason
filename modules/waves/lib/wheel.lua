
local Wheel = {}

---@alias WaveRng fun(m: number?, n: number?): number

---@param rng WaveRng
---@return WaveWheelState
function Wheel.New(rng)
	return {
		base = 5,
		air = rng(5, 15),
		special = rng(5, 15),
		basic = rng(5, 15),
		small = rng(5, 15),
		larger = rng(10, 30),
		huge = rng(15, 50),
		epic = rng(20, 75),
	}
end

---Every wave ages every counter, including the ones that did not fire —
---this runs before any decision, so a wave the director declines to spawn
---still moves the wheel.
---@param state WaveWheelState
function Wheel.Tick(state)
	state.base = state.base - 1
	state.air = state.air - 1
	state.special = state.special - 1
	state.basic = state.basic - 1
	state.small = state.small - 1
	state.larger = state.larger - 1
	state.huge = state.huge - 1
	state.epic = state.epic - 1
end

---@class WaveWheelInput
---@field techAnger number the live roster clock
---@field waveTechAnger number the PREVIOUS wave's composing anger — what the air gate reads
---@field airStartAnger number
---@field spawnChance number
---@field tier2MinAnger number below this the game is still opening

---The opening is special-cased: below the second tier's threshold the wave is
---deliberately a trickle — size and time scale straight off anger — so the
---first minutes are pressure, not a fight. Above it, the wheel picks.
---@param state WaveWheelState mutated: the claiming flavor re-arms
---@param input WaveWheelInput
---@param rng WaveRng
---@return WaveShape
function Wheel.Shape(state, input, rng)
	local shape = {
		sizeMultiplier = 1,
		timeMultiplier = 1,
		airPercentage = rng(10, 25),
		specialPercentage = rng(5, 50),
		techAnger = input.waveTechAnger,
	}

	local anger = math.max(1, input.techAnger)
	local opening = anger < input.tier2MinAnger
	if not (state.base <= 0 or opening) then
		return shape
	end

	if opening then
		-- A trickle, and a slow one: both multipliers are pinned under the
		-- anger fraction, so wave one is a handful of units, not a wave.
		shape.sizeMultiplier = math.min(shape.sizeMultiplier, anger * 0.1)
		shape.timeMultiplier = math.min(shape.timeMultiplier, anger * 0.1)
		shape.airPercentage = 20
		shape.specialPercentage = 0
		return shape
	end

	if input.waveTechAnger > input.airStartAnger and state.air <= 0 and rng() <= input.spawnChance then
		state.base = rng(0, 2)
		state.air = rng(0, 10)
		shape.specialPercentage = 0
		shape.airPercentage = 50
		shape.sizeMultiplier = 2
		shape.timeMultiplier = 0.5
	elseif state.special <= 0 and rng() <= input.spawnChance then
		state.base = rng(0, 2)
		state.special = rng(0, 10)
		shape.specialPercentage = 50
		shape.airPercentage = 0
	elseif state.basic <= 0 and rng() <= input.spawnChance then
		state.base = rng(0, 2)
		state.basic = rng(0, 10)
		shape.specialPercentage = 0
		shape.airPercentage = 0
	elseif state.small <= 0 and rng() <= input.spawnChance then
		state.base = rng(0, 2)
		state.small = rng(0, 10)
		shape.sizeMultiplier = 0.5
		shape.timeMultiplier = 0.5
	elseif state.larger <= 0 and rng() <= input.spawnChance then
		state.base = rng(0, 2)
		state.larger = rng(0, 25)
		shape.sizeMultiplier = 1.5
		shape.timeMultiplier = 1.25
		shape.airPercentage = rng(5, 20)
		shape.specialPercentage = rng(5, 40)
	elseif state.huge <= 0 and rng() <= input.spawnChance then
		state.base = rng(0, 2)
		state.huge = rng(0, 50)
		shape.sizeMultiplier = 3
		shape.timeMultiplier = 1.5
		shape.airPercentage = rng(5, 15)
		shape.specialPercentage = rng(5, 25)
	elseif state.epic <= 0 and rng() <= input.spawnChance then
		state.base = rng(0, 2)
		state.epic = rng(0, 100)
		shape.sizeMultiplier = 5
		shape.timeMultiplier = 2.5
		shape.airPercentage = rng(5, 10)
		shape.specialPercentage = rng(5, 10)
	end

	return shape
end

return Wheel
