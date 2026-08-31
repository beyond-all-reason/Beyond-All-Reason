---@diagnostic disable: undefined-field

local GADGET_PATH = "luarules/gadgets/unit_areaattack.lua"

local CMD_ATTACK = 20
local CMD_INSERT = 1
local CMD_REMOVE = 2
local CMD_OPT_INTERNAL = 8
local CMD_AREA_ATTACK_GROUND = 39999
local WEAPON_DEF_ID = 5
local UNIT_DEF_ID = 1
local UNIT_ID = 7

local function loadGadget(commands, weaponState)
	local orders = {}
	local finishedUnits = {}
	local currentFrame = 1
	local unitDefLookups = 0
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
		},
		CMDTYPE = { ICON_AREA = 5 },
		Game = { Commands = { ReissueOrder = function() end } },
		UnitDefs = {
			[UNIT_DEF_ID] = {
				weapons = { { weaponDef = WEAPON_DEF_ID } },
				customParams = { canareaattack = true },
			},
		},
		WeaponDefs = { [WEAPON_DEF_ID] = { range = 1000 } },
		math = setmetatable({
			bit_and = function(a, b)
				return a % (b * 2) >= b and b or 0
			end,
		}, { __index = math }),
		Script = { SetWatchProjectile = function() end },
		Spring = {
			GetGameFrame = function()
				return currentFrame
			end,
			GetUnitCurrentCommand = function(_, index)
				local command = commands[index or 1]
				if command then
					return command.id, command.options.coded, command.tag, unpack(command.params)
				end
			end,
			GetUnitDefID = function()
				unitDefLookups = unitDefLookups + 1
				return UNIT_DEF_ID
			end,
			GetUnitWeaponState = function(_, _, stateName)
				return weaponState[stateName]
			end,
			GetUnitPosition = function()
				return 0, 0, 0
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

	return env.gadget,
		orders,
		finishedUnits,
		function(frame)
			currentFrame = frame
		end,
		function()
			return unitDefLookups
		end
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
	it("changes area target after one complete salvo", function()
		local commands = generatedAreaCommands()
		local weaponState = { salvoLeft = 1, nextSalvo = 2 }
		local gadget, _, finishedUnits, setFrame = loadGadget(commands, weaponState)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFramePost(1)
		assert.equals(0, #finishedUnits)

		weaponState.salvoLeft = 0
		setFrame(2)
		gadget:GameFramePost(2)
		assert.same({ UNIT_ID }, finishedUnits)
	end)

	it("does not process every projectile in a burst", function()
		local commands = generatedAreaCommands()
		local weaponState = { salvoLeft = 2, nextSalvo = 2 }
		local gadget, _, _, _, getUnitDefLookups = loadGadget(commands, weaponState)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:ProjectileCreated(2, UNIT_ID, WEAPON_DEF_ID)
		gadget:ProjectileCreated(3, UNIT_ID, WEAPON_DEF_ID)

		assert.equals(1, getUnitDefLookups())
	end)

	it("finishes after a canceled final shot without another projectile", function()
		local commands = generatedAreaCommands()
		local weaponState = { salvoLeft = 1, nextSalvo = 2 }
		local gadget, _, finishedUnits = loadGadget(commands, weaponState)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFramePost(1)
		weaponState.salvoLeft = 0
		gadget:GameFramePost(2)

		assert.same({ UNIT_ID }, finishedUnits)
	end)

	it("follows a delayed next-salvo frame", function()
		local commands = generatedAreaCommands()
		local weaponState = { salvoLeft = 1, nextSalvo = 2 }
		local gadget, _, finishedUnits = loadGadget(commands, weaponState)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFramePost(1)
		weaponState.nextSalvo = 4
		gadget:GameFramePost(2)
		weaponState.salvoLeft = 0
		gadget:GameFramePost(3)
		assert.equals(0, #finishedUnits)
		gadget:GameFramePost(4)

		assert.same({ UNIT_ID }, finishedUnits)
	end)

	it("ignores unrelated weapon projectiles", function()
		local commands = generatedAreaCommands()
		local gadget, orders, finishedUnits = loadGadget(commands, {})

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID + 1)
		gadget:GameFramePost(1)

		assert.equals(0, #finishedUnits)
		assert.equals(0, #orders)
	end)

	it("ignores player-issued ground attacks", function()
		local commands = generatedAreaCommands()
		commands[1].options = { coded = 0, internal = false }
		local weaponState = { salvoLeft = 0, nextSalvo = 1 }
		local gadget, orders, finishedUnits = loadGadget(commands, weaponState)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFramePost(1)

		assert.equals(0, #finishedUnits)
		assert.equals(0, #orders)
	end)

	it("keeps a generated attack persistent without its area command", function()
		local commands = { generatedAreaCommands()[1] }
		local weaponState = { salvoLeft = 0, nextSalvo = 1 }
		local gadget, orders, finishedUnits = loadGadget(commands, weaponState)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		gadget:GameFramePost(1)

		assert.equals(0, #finishedUnits)
		assert.equals(0, #orders)
	end)

	it("marks generated area shots internal so repeat does not retain them", function()
		local commands = {}
		local gadget, orders = loadGadget(commands, {})

		gadget:CommandFallback(UNIT_ID, UNIT_DEF_ID, 0, CMD_AREA_ATTACK_GROUND, { 0, 0, 0, 10 }, {})
		gadget:GameFrame(1)

		assert.equals(CMD_INSERT, orders[1][2])
		assert.equals(CMD_OPT_INTERNAL, orders[1][3][3])
	end)

	it("removes only the generated shot if another command moves ahead of it", function()
		local commands = generatedAreaCommands()
		local generatedAttack = commands[1]
		local weaponState = { salvoLeft = 0, nextSalvo = 1 }
		local gadget, orders, finishedUnits = loadGadget(commands, weaponState)

		gadget:ProjectileCreated(1, UNIT_ID, WEAPON_DEF_ID)
		commands[1] = { id = 10, tag = 99, params = { 0, 0, 0 }, options = { coded = 0 } }
		gadget:GameFramePost(1)

		assert.equals(0, #finishedUnits)
		assert.same({ UNIT_ID, CMD_REMOVE, { generatedAttack.tag }, 0 }, orders[1])
	end)
end)
