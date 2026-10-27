---@diagnostic disable: undefined-field, redundant-parameter
local Commands = { ATTACK = 20, MANUALFIRE = 105, OPT_INTERNAL = 8 }
local SCRIPT = "luarules/gadgets/unit_attack_movement.lua"

describe("Lua attack movement", function()
	local api, controller, def, target, motion, actions, frame, clear, needsTurn
	local function load(mode)
		api.GetModOptions = function()
			return { attackmovementmode = mode }
		end
		controller = {}
		local testMath = setmetatable({
			bit_and = function(value, bit)
				return value % (bit * 2) >= bit and bit or 0
			end,
			normalize = function(x, y, z)
				local length = math.sqrt(x * x + y * y + z * z)
				return x / length, y / length, z / length
			end,
		}, { __index = math })
		local env = setmetatable({
			gadget = controller,
			Spring = api,
			math = testMath,
			gadgetHandler = {
				IsSyncedCode = function()
					return true
				end,
				RemoveGadget = spy.new(function() end),
			},
			UnitDefs = { [1] = def, [2] = { isImmobile = false } },
			WeaponDefs = { [1] = { targetBorder = 0, manualFire = false } },
			Game = { squareSize = 8 },
			CMD = Commands,
		}, { __index = _G })
		local chunk = assert(loadfile(SCRIPT))
		setfenv(chunk, env)
		chunk()
		return env
	end
	local function update(targetID, command, temporary)
		return controller:AttackCommandMovement(
			1,
			1,
			command or Commands.ATTACK,
			0,
			targetID,
			0,
			0,
			target.z,
			temporary
		)
	end
	before_each(function()
		frame, clear, needsTurn = 100, false, false
		target = { z = 500 }
		def = { weapons = { { weaponDef = 1 } }, stopToAttack = false, strafeToAttack = true }
		motion = { goalx = 0, goaly = 0, goalz = 0, progressState = "active", strafeLeft = true }
		actions = {}
		api = {
			GetUnitDefID = function(id)
				return id
			end,
			GetUnitStates = function()
				return 0, 1
			end,
			GetGameFrame = function()
				return frame
			end,
			GetUnitMaxRange = function()
				return 300
			end,
			GetUnitPosition = function(id)
				return 0, 0, id == 1 and 0 or target.z, 0, 0, id == 1 and 0 or target.z
			end,
			GetUnitMoveTypeData = function()
				return motion
			end,
			GetUnitRadius = function()
				return 10
			end,
			GetUnitVelocity = function()
				return 0, 0, 0, 0
			end,
			GetUnitSensorRadius = function()
				return 500
			end,
			GetUnitWeaponState = function()
				return needsTurn
			end,
			TestUnitAttackWeapon = function(_, _, options)
				assert.is_nil(options and options.avoidFlags)
				return clear
			end,
			GetUnitAttackTargetPosition = function()
				return 0, 0, target.z
			end,
			SetUnitMoveGoal = function(_, x, y, z, radius, speed, raw)
				actions[#actions + 1] = { kind = "move", x = x, y = y, z = z }
			end,
			SetUnitFacingTarget = function()
				actions[#actions + 1] = { kind = "face" }
			end,
			ClearUnitGoal = function(_, cancelRaw)
				assert.is_false(cancelRaw)
				actions[#actions + 1] = { kind = "stop" }
			end,
			SetUnitTarget = function()
				actions[#actions + 1] = { kind = "assign" }
				return true
			end,
			FinishUnitAttackCommand = function()
				actions[#actions + 1] = { kind = "finish" }
			end,
		}
	end)
	it("is opt-in and leaves native fallback free of reads and writes", function()
		load(nil)
		assert.is_false(controller:GetInfo().enabled)
		load("fallback")
		api.GetUnitDefID = function()
			error("fallback read unit state")
		end
		assert.is_false(update(2))
		assert.same({}, actions)
	end)
	it("removes itself on an unsupported engine", function()
		local env = load("lua")
		api.TestUnitAttackWeapon = nil
		controller:Initialize()
		assert.spy(env.gadgetHandler.RemoveGadget).was_called()
	end)
	it("moves towards an out-of-range target without inventing a stop", function()
		load("lua")
		assert.is_true(update(2))
		assert.equals("move", actions[1].kind)
		assert.equals(target.z, actions[1].z)
		assert.equals(1, #actions)
	end)
	it("keeps the strafe side until path failure, then changes side", function()
		load("lua")
		target.z = 180
		update(2)
		local first = actions[1].x
		motion.strafeLeft = false -- native copy is no longer the controller's state
		update(2)
		assert.equals(first, actions[2].x)
		motion.progressState = "failed"
		update(2)
		assert.equals(-first, actions[3].x)
	end)
	it("does not retain strafe memory when a destroyed unit ID is reused", function()
		load("lua")
		target.z = 180
		update(2)
		local first = actions[1].x
		controller:UnitDestroyed(1)
		motion.strafeLeft = false
		update(2)
		assert.equals(-first, actions[2].x)
	end)
	it("holds and turns for a forward-only weapon inside engagement range", function()
		load("lua")
		target.z, needsTurn = 180, true
		update(2)
		assert.same({ { kind = "stop" }, { kind = "face" } }, actions)
	end)
	it("finishes an unsuccessful temporary attack on hold position", function()
		load("lua")
		api.GetUnitStates = function()
			return 0, 0
		end
		update(2, Commands.ATTACK, true)
		assert.same({ { kind = "stop" }, { kind = "finish" } }, actions)
	end)
	it("keeps approach retry memory across updates", function()
		load("lua")
		update(2)
		actions, clear = {}, true
		frame = 110
		update(2)
		assert.same({ { kind = "stop" }, { kind = "assign" } }, actions)
		actions, frame = {}, 131
		update(2)
		assert.same({ { kind = "stop" }, { kind = "face" }, { kind = "assign" } }, actions)
	end)
	it("preserves point-before-stop ordering for manual ground fire", function()
		load("lua")
		update(nil, Commands.MANUALFIRE)
		assert.same({ { kind = "assign" }, { kind = "face" }, { kind = "stop" } }, actions)
	end)
end)
