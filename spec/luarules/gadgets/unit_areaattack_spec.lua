---@diagnostic disable: undefined-field

local GADGET_PATH = "luarules/gadgets/unit_areaattack.lua"

local CMD_ATTACK = 20
local CMD_INSERT = 1
local CMD_REMOVE = 2
local CMD_OPT_INTERNAL = 8
local CMD_OPT_ALT = 128
local CMD_AREA_ATTACK_GROUND = 39999
local WEAPON_DEF_ID = 5
local UNIT_DEF_ID = 1
local UNIT_ID = 7

local function loadGadget(commands, repeatOrders, salvoSize, groundAttackAfterSalvos, canAreaAttack)
	local orders = {}
	local insertedOrders = {}
	local finishedUnits = {}
	local env = {
		gadget = {},
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			RegisterCMDID = function() end,
			RegisterAllowCommand = function() end,
		},
		GameCMD = { AREA_ATTACK_GROUND = CMD_AREA_ATTACK_GROUND },
		CMD = {
			ATTACK = CMD_ATTACK,
			INSERT = CMD_INSERT,
			REMOVE = CMD_REMOVE,
			OPT_INTERNAL = CMD_OPT_INTERNAL,
			OPT_ALT = CMD_OPT_ALT,
		},
		CMDTYPE = { ICON_AREA = 5 },
		Game = {
			Commands = {
				ReissueOrder = function() end,
				GiveInsertOrderToUnit = function(...)
					insertedOrders[#insertedOrders + 1] = { ... }
				end,
			},
		},
		UnitDefs = {
			[UNIT_DEF_ID] = {
				weapons = { { weaponDef = WEAPON_DEF_ID } },
				customParams = {
					canareaattack = canAreaAttack ~= false,
					groundattackaftersalvos = groundAttackAfterSalvos,
				},
			},
		},
		WeaponDefs = {
			[WEAPON_DEF_ID] = { range = 1000, salvoSize = salvoSize or 1 },
		},
		Script = { SetWatchProjectile = function() end },
		Spring = {
			GetUnitCommands = function()
				return commands
			end,
			GetUnitCurrentCommand = function()
				local command = commands[1]
				if command then
					return command.id, command.options.coded, command.tag
				end
			end,
			GetUnitDefID = function()
				return UNIT_DEF_ID
			end,
			GetUnitPosition = function()
				return 0, 0, 0
			end,
			GetUnitStates = function()
				return { ["repeat"] = repeatOrders }
			end,
			GiveOrderToUnit = function(...)
				orders[#orders + 1] = { ... }
			end,
			UnitFinishCommand = function(unitID)
				finishedUnits[#finishedUnits + 1] = unitID
			end,
			InsertUnitCmdDesc = function() end,
			SetUnitMoveGoal = function() end,
		},
	}
	setmetatable(env, { __index = _G })

	local chunk = assert(loadfile(GADGET_PATH))
	setfenv(chunk, env)
	chunk()

	return env.gadget, orders, insertedOrders, finishedUnits
end

local function queuedGroundAttacks()
	return {
		{
			id = CMD_ATTACK,
			tag = 41,
			params = { 100, 0, 200 },
			options = { coded = 32, shift = true, internal = false },
		},
		{ id = CMD_ATTACK, tag = 42, params = { 300, 0, 400 }, options = { coded = 32 } },
	}
end

local function generatedAreaCommands()
	return {
		{
			id = CMD_ATTACK,
			tag = 43,
			params = { 5, 0, 5 },
			options = { coded = CMD_OPT_INTERNAL, internal = true },
		},
		{ id = CMD_AREA_ATTACK_GROUND, tag = 44, params = { 0, 0, 0, 10 }, options = { coded = 0 } },
	}
end

describe("unit_areaattack", function()
	it("advances an opted-in player attack after the configured complete salvos", function()
		local commands = queuedGroundAttacks()
		local gadget, _, _, finishedUnits = loadGadget(commands, false, 2, 2, false)

		for projectileID = 1, 3 do
			gadget:ProjectileCreated(projectileID, UNIT_ID, WEAPON_DEF_ID)
			gadget:GameFrame(projectileID)
			assert.equals(0, #finishedUnits)
		end

		gadget:ProjectileCreated(4, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFrame(4)
		assert.same({ UNIT_ID }, finishedUnits)
	end)

	it("keeps queued player attacks persistent when advancement is disabled", function()
		local commands = queuedGroundAttacks()
		local gadget, orders, insertedOrders, finishedUnits = loadGadget(commands, true, 1, 0)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFrame(1)

		assert.equals(0, #finishedUnits)
		assert.equals(0, #insertedOrders)
		assert.equals(0, #orders)
	end)

	it("finishes an opted-in player attack with the engine's repeat handling", function()
		local commands = queuedGroundAttacks()
		local gadget, orders, insertedOrders, finishedUnits = loadGadget(commands, true, 1, 1)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFrame(1)

		assert.same({ UNIT_ID }, finishedUnits)
		assert.equals(0, #insertedOrders)
		assert.equals(0, #orders)
	end)

	it("ignores unrelated weapon projectiles", function()
		local commands = queuedGroundAttacks()
		local gadget, orders, insertedOrders, finishedUnits = loadGadget(commands, false, 1, 1)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID + 1)
		gadget:GameFrame(1)

		assert.equals(0, #finishedUnits)
		assert.equals(0, #insertedOrders)
		assert.equals(0, #orders)
	end)

	it("keeps a final ground attack persistent", function()
		local commands = { queuedGroundAttacks()[1] }
		local gadget, orders, insertedOrders, finishedUnits = loadGadget(commands, false, 1, 1)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFrame(1)

		assert.equals(0, #finishedUnits)
		assert.equals(0, #insertedOrders)
		assert.equals(0, #orders)
	end)

	it("removes only the completed attack if another command was inserted ahead of it", function()
		local commands = queuedGroundAttacks()
		local completedAttack = commands[1]
		local gadget, orders, insertedOrders, finishedUnits = loadGadget(commands, true, 1, 1)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		commands[1] = { id = 10, tag = 99, params = { 0, 0, 0 }, options = { coded = 0 } }
		gadget:GameFrame(1)

		assert.equals(0, #finishedUnits)
		assert.same(
			{ UNIT_ID, CMD_ATTACK, completedAttack.params, completedAttack.options, -1, CMD_OPT_ALT },
			insertedOrders[1]
		)
		assert.same({ UNIT_ID, CMD_REMOVE, { completedAttack.tag }, 0 }, orders[1])
	end)

	it("changes area target after the configured number of complete salvos", function()
		local commands = generatedAreaCommands()
		local gadget, _, _, finishedUnits = loadGadget(commands, false, 2, 2)

		for projectileID = 1, 3 do
			gadget:ProjectileCreated(projectileID, UNIT_ID, WEAPON_DEF_ID)
			gadget:GameFrame(projectileID)
			assert.equals(0, #finishedUnits)
		end

		gadget:ProjectileCreated(4, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFrame(4)
		assert.same({ UNIT_ID }, finishedUnits)
	end)

	it("defaults generated area targets to one salvo when advancement is disabled", function()
		local commands = generatedAreaCommands()
		local gadget, _, _, finishedUnits = loadGadget(commands, false, 1, 0)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFrame(1)

		assert.same({ UNIT_ID }, finishedUnits)
	end)

	it("marks generated area shots internal so repeat does not retain them", function()
		local commands = {}
		local gadget, orders = loadGadget(commands, true, 1, 0)

		gadget:CommandFallback(UNIT_ID, UNIT_DEF_ID, 0, CMD_AREA_ATTACK_GROUND, { 0, 0, 0, 10 }, {})
		gadget:GameFrame(1)

		assert.equals(CMD_INSERT, orders[1][2])
		assert.equals(CMD_OPT_INTERNAL, orders[1][3][3])
	end)

	it("does not requeue an internal area shot when another command moves ahead of it", function()
		local commands = generatedAreaCommands()
		local generatedAttack = commands[1]
		local gadget, orders, insertedOrders, finishedUnits = loadGadget(commands, true, 1, 1)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		commands[1] = { id = 10, tag = 99, params = { 0, 0, 0 }, options = { coded = 0 } }
		gadget:GameFrame(1)

		assert.equals(0, #finishedUnits)
		assert.equals(0, #insertedOrders)
		assert.same({ UNIT_ID, CMD_REMOVE, { generatedAttack.tag }, 0 }, orders[1])
	end)
end)
