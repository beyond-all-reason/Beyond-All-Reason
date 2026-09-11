local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local Traits = VFS.Include("modules/transport/lib/traits.lua") ---@type TransportTraits

describe("transport's actions", function()
	local actions = ModuleHandler.LoadActions(Modules.Transport)
	local savedSpring, savedUnitDefs
	local calls
	local nearby, defOf

	before_each(function()
		ModuleHandler.ResetCaches()
		calls = {}
		nearby, defOf = {}, {}
		savedSpring, savedUnitDefs = _G.Spring, _G.UnitDefs
		local function record(name)
			return function(...)
				calls[#calls + 1] = { name, ... }
			end
		end
		---@diagnostic disable-next-line: global-in-non-module
		_G.Spring = setmetatable({
			SetUnitStealth = record("SetUnitStealth"),
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
		}, { __index = savedSpring })
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
	end)

	after_each(function()
		---@diagnostic disable-next-line: global-in-non-module
		_G.Spring, _G.UnitDefs = savedSpring, savedUnitDefs
	end)

	it("ships loaded, unloaded and halt, each with a validate", function()
		for _, name in ipairs({ "loaded", "unloaded", "halt" }) do
			assert.is_not_nil(actions.byName[name], name)
			assert.is_function(actions.byName[name].validate, name)
		end
	end)

	it("validate refuses a request with no units in it", function()
		assert.is_false((actions.byName.loaded.validate({})))
		assert.is_false((actions.byName.unloaded.validate({ unitID = 1 })))
		assert.is_false((actions.byName.halt.validate({})))
	end)

	it("loaded hides a passenger on a stealthy carrier and drops its ghost, and records the loaded speed", function()
		local state = VFS.Include("modules/transport/state.lua")
		local request =
			{ unitID = 7, transportID = 9, carrier = Traits.Of(1), passenger = Traits.Of(2), loadedSpeed = 4 }
		assert.is_true((actions.byName.loaded.validate(request)))
		actions.byName.loaded.execute(request)
		assert.are.same({ "SetUnitStealth", 7, true }, calls[1])
		assert.are.same({ "SetUnitLeavesGhost", 7, false, true }, calls[2])
		assert.are.equal(4, state.loadedSpeed[9])
	end)

	it("unloaded reverses that and pins the unit where it landed a few frames on", function()
		local state = VFS.Include("modules/transport/state.lua")
		local request = {
			unitID = 7,
			unitDefID = 2,
			transportID = 9,
			carrier = Traits.Of(1),
			passenger = Traits.Of(2),
			loadedSpeed = false,
			frame = 100,
		}
		assert.is_true((actions.byName.unloaded.validate(request)))
		actions.byName.unloaded.execute(request)
		assert.are.same({ "SetUnitStealth", 7, false }, calls[1])
		assert.are.same({ "SetUnitLeavesGhost", 7, true }, calls[2])
		assert.is_nil(state.loadedSpeed[9])
		assert.are.equal(110, state.settling[7].frame)
		assert.are.equal(9, state.maybeDead[7])
	end)

	it("unloaded wakes the nano turrets an immobile unit was set down onto, and only those", function()
		local state = VFS.Include("modules/transport/state.lua")
		state.unstacking = {}
		nearby, defOf = { 7, 8, 11 }, { [8] = 3 }
		local request = {
			unitID = 7,
			unitDefID = 2,
			transportID = 9,
			carrier = Traits.Of(1),
			passenger = Traits.Of(2),
			loadedSpeed = false,
			frame = 100,
		}
		actions.byName.unloaded.execute(request)
		assert.are.same({ [8] = 3 }, state.unstacking)
	end)
end)
