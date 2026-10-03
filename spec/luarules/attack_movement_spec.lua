---@diagnostic disable: undefined-field, redundant-parameter
local Builders = VFS.Include("spec/builders/index.lua")
local SCRIPT = "luarules/gadgets/unit_attack_movement.lua"

describe("Lua attack movement", function()
	---@type table<string, any>
	local state = {}
	---@type table[]
	local weapons = {}
	---@type string[]
	local actions = {}
	local reads = 0
	---@type table<string, any>
	local spring = {}
	---@type table<string, any>
	local handler = {}
	---@type table<string, any>
	local instance = {}
	local function load(mode)
		spring = Builders.Spring.new():WithModOption("attackmovementmode", mode):Build()
		spring.GetUnitAttackMovementState = function()
			reads = reads + 1
			return state
		end
		spring.GetUnitAttackWeaponState = function(_, weaponNum, flags)
			assert.is_nil(flags) -- the equivalent port must retain each weapon's native filters
			return unpack(weapons[weaponNum])
		end
		spring.SetUnitAttackMovement = function(_, operation)
			actions[#actions + 1] = operation
			if operation == "attack" then
				return true
			end
		end
		handler = {
			IsSyncedCode = function()
				return true
			end,
			RemoveGadget = spy.new(function() end),
		}
		instance = {}
		local env = setmetatable({ Spring = spring, gadgetHandler = handler, gadget = instance }, { __index = _G })
		local chunk = assert(loadfile(SCRIPT))
		setfenv(chunk, env)
		chunk()
		return instance
	end
	before_each(function()
		actions, reads = {}, 0
		state = {
			object = true,
			manual = false,
			skipParalyze = false,
			temporary = false,
			holdPosition = false,
			hovering = false,
			stopToAttack = true,
			strafeToAttack = false,
			targetBehind = false,
			numWeapons = 1,
			distance = 200,
			distanceSq = 40000,
			range90 = 270,
			range90Sq = 72900,
			frame = 1000,
			lastCloseInTry = 0,
			retryTicks = 30,
			goalDistanceSq = 0,
			goalThresholdSq = 100,
		}
		weapons = { { true, true, true, false, 0, "clear", "clear" } }
	end)
	it("is opt-in and does not install replay speed or quit controls", function()
		local g = load(nil)
		assert.is_false(g:GetInfo().enabled)
		assert.is_nil(g.GameFrame)
		assert.is_nil(g.RecvFromSynced)
	end)
	it("removes itself on an engine without the new APIs", function()
		local g = load("lua")
		-- Reload so the missing function is also absent from the cached locals.
		spring.GetUnitAttackWeaponState = nil
		local chunk = assert(loadfile(SCRIPT))
		setfenv(chunk, setmetatable({ Spring = spring, gadgetHandler = handler, gadget = g }, { __index = _G }))
		chunk()
		g:Initialize()
		assert.spy(handler.RemoveGadget).was_called_with(handler, g)
	end)
	it("returns false without querying or changing movement in fallback mode", function()
		assert.is_false(load("fallback"):AttackCommandMovement(1))
		assert.equals(0, reads)
		assert.same({}, actions)
	end)
	it("stops, points and assigns an object target with a solution", function()
		assert.is_true(load("lua"):AttackCommandMovement(1))
		assert.same({ "stop", "point", "attack" }, actions)
	end)
	for _, reason in ipairs({ "terrain", "friendly" }) do
		it("preserves legacy close-range behavior for " .. reason, function()
			weapons = { { true, false, false, true, 0, reason, reason } }
			assert.is_true(load("lua"):AttackCommandMovement(1))
			assert.same({ "stop", "point" }, actions)
		end)
	end
	it("finishes a temporary hold-position order without a solution", function()
		state.temporary, state.holdPosition = true, true
		weapons = { { true, false, false, false, 0, "range", "range" } }
		load("lua"):AttackCommandMovement(1)
		assert.same({ "finish" }, actions)
	end)
	it("assigns a ground target before stopping and pointing", function()
		state.object = false
		load("lua"):AttackCommandMovement(1)
		assert.same({ "attack", "stopPoint" }, actions)
	end)
	it("retains the special point-before-stop order for manual ground fire", function()
		state.object, state.manual = false, true
		load("lua"):AttackCommandMovement(1)
		assert.same({ "attack", "point", "stop" }, actions)
	end)
end)
