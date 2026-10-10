local Traits = require("modules/transport/lib/traits")

describe("transport's api in the synced handle", function()
	local Synced = require("modules/transport/api_synced")
	local savedSpring, savedUnitDefs, savedGG
	local calls = {} ---@type table[]
	local nearby, defOf = {}, {} ---@type integer[], table<integer, integer>

	before_each(function()
		calls = {}
		nearby, defOf = {}, {}
		savedSpring, savedUnitDefs, savedGG = _G.Spring, _G.UnitDefs, _G.GG
		local function record(name)
			return function(...)
				calls[#calls + 1] = { name, ... }
			end
		end
		---@diagnostic disable-next-line: global-in-non-module
		_G.Spring = setmetatable({
			SetUnitLeavesGhost = record("SetUnitLeavesGhost"),
			SetUnitVelocity = record("SetUnitVelocity"),
			GetUnitRulesParam = function()
				return nil
			end,
			GetUnitPosition = function()
				return 10, 20, 30
			end,
			GetUnitDirection = function()
				return 1, 0, 0, 0, 1, 0
			end,
			GetUnitsInCylinder = function()
				return nearby
			end,
			GetUnitDefID = function(unitID)
				return defOf[unitID] or 2
			end,
			GetUnitIsTransporting = function()
				return nil
			end,
			GetGameFrame = function()
				return 100
			end,
		}, { __index = savedSpring })
		---@diagnostic disable-next-line: global-in-non-module
		_G.GG = { UnitAttributes = { SetUnitAttribute = record("SetUnitAttribute") } }
		---@diagnostic disable-next-line: global-in-non-module
		_G.UnitDefs = {
			[1] = {
				customParams = { stealths_passengers = "1" },
				xsize = 2,
				zsize = 2,
				canFly = true,
				isTransport = true,
			},
			[2] = { customParams = {}, xsize = 2, zsize = 2, leavesGhost = true },
			[3] = { customParams = { isnanoturret = "1" }, xsize = 2, zsize = 2 },
		}
		Synced = require("modules/transport/api_synced")
	end)

	after_each(function()
		---@diagnostic disable-next-line: global-in-non-module
		_G.Spring, _G.UnitDefs, _G.GG = savedSpring, savedUnitDefs, savedGG
	end)

	it("halts a carrier dead", function()
		Synced.Halt(9)
		assert.are.same({ "SetUnitVelocity", 9, 0, 0, 0 }, calls[1])
	end)

	it("loaded hides a passenger on a stealthy carrier and drops its ghost", function()
		defOf[9] = 1
		Synced.Loaded(7, 2, 9)
		assert.are.same({ "SetUnitAttribute", 7, "stealth", true, "stealthy_passengers" }, calls[1])
		assert.are.same({ "SetUnitLeavesGhost", 7, false, true }, calls[2])
	end)

	it("unloaded reverses that and pins the unit where it landed a few frames on", function()
		local state = require("modules/transport/state")
		defOf[9] = 1
		Synced.Unloaded(7, 2, 9)
		assert.are.same({ "SetUnitAttribute", 7, "stealth", nil, "stealthy_passengers" }, calls[1])
		assert.are.same({ "SetUnitLeavesGhost", 7, true }, calls[2])
		assert.are.equal(110, state.settling[7].frame)
		assert.are.equal(9, state.maybeDead[7])
	end)

	it("unloaded wakes the nano turrets an immobile unit was set down onto, and only those", function()
		local state = require("modules/transport/state")
		state.unstacking = {}
		nearby, defOf = { 7, 8, 11 }, { [8] = 3, [9] = 1 }
		Synced.Unloaded(7, 2, 9)
		assert.are.same({ [8] = 3 }, state.unstacking)
	end)
end)
