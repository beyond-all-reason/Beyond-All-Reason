--------------------------------------------------------------------------------
--
--  Proposed Command ID Ranges:
--
--    all negative:  Engine (build commands)
--       0 -   999:  Engine
--    1000 -  9999:  Group AI
--   10000 - 19999:  LuaUI
--   20000 - 29999:  LuaCob
--   30000 - 39999:  LuaRules
--

-- if you add a command, please order it by ID!

local gameCommands = {
	FACTORY_GUARD = 13921,
	AREA_GUARD = 13922, -- unused
	STOP_PRODUCTION = 13923,

	-- blueprint
	BLUEPRINT_PLACE = 18200,
	BLUEPRINT_CREATE = 18201,

	-- quota
	QUOTA_BUILD_TOGGLE = 23000,

	AREA_MEX = 30100,
	SELL_UNIT = 30101,

	CARRIER_SPAWN_ONOFF = 31200,
	MORPH = 31210,
	MANUAL_LAUNCH = 32102,
	UNIT_SET_TARGET_NO_GROUND = 34922, -- unit_target_on_the_move
	UNIT_SET_TARGET = 34923,
	UNIT_CANCEL_TARGET = 34924,
	UNIT_SET_TARGET_RECTANGLE = 34925,
	LAND_AT = 34569,
	AIR_REPAIR = 34570,
	PRIORITY = 34571,
	WANT_CLOAK = 37382,
	HOUND_WEAPON_TOGGLE = 37383, -- unused
	SMART_TOGGLE = 37384,
	AREA_ATTACK_GROUND = 39954,

	-- terraform
	RAW_MOVE = 39812,
}

local globalCmdDeprecatedShown = false

local importCommandsToObject = function(object)
	if not globalCmdDeprecatedShown and not object.gadgetHandler then
		local msg = 'Should not use customcmds.h.lua or importCommandsToObject. Use the CMD table directly, or read modules/customcommands.lua for more information.'
		Spring.Log('CMD', LOG.DEPRECATED, msg)
		globalCmdDeprecatedShown = true
	end
	for code, cmdID in pairs(gameCommands) do
		if type(code) == 'string' then
			object['CMD_' .. code] = cmdID
		end
	end

end

for code, cmdID in pairs(gameCommands) do
	if CMD[cmdID] then
		Spring.Log('CMD', LOG.ERROR, 'Duplicate command id: ' .. code .. ' ' .. tostring(cmdID) .. '!')
	end
	if CMD[code] then
		Spring.Log('CMD', LOG.ERROR, 'Duplicate command code: ' .. code .. ' ' .. tostring(cmdID) .. '!')
	end
	gameCommands[cmdID] = code
end

local getCommandCode = function(cmdID)
	return CMD[cmdID] or gameCommands[cmdID]
end

-- Command processing ----------------------------------------------------------

local bit_and = math.bit_and
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMD_INSERT = CMD.INSERT
local OPT_INTERNAL = CMD.OPT_INTERNAL
local OPT_ALT = CMD.OPT_ALT
local OPT_CTRL = CMD.OPT_CTRL
local OPT_META = CMD.OPT_META
local OPT_RIGHT = CMD.OPT_RIGHT
local OPT_SHIFT = CMD.OPT_SHIFT

---Unpack the inner command from the params of a `CMD_INSERT`.
---@param cmdParams number[]
---@return integer index if options.alt, command tag, else queue position
---@return CMD innerCommand
---@return CommandOptions innerOptions
local function getInsertedCommand(cmdParams)
	local index, innerCommand, innerOptionBits = cmdParams[1], cmdParams[2], cmdParams[3]

	-- Update in-place, and assume n >= 3:
	local n = #cmdParams
	for i = 1, n - 3 do
		cmdParams[i] = cmdParams[i + 3]
	end
	cmdParams[n    ] = nil
	cmdParams[n - 1] = nil
	cmdParams[n - 2] = nil

	local innerOptions = {
		coded    = innerOptionBits,
		internal = 0 ~= bit_and(innerOptionBits, OPT_INTERNAL),
		alt      = 0 ~= bit_and(innerOptionBits, OPT_ALT),
		ctrl     = 0 ~= bit_and(innerOptionBits, OPT_CTRL),
		meta     = 0 ~= bit_and(innerOptionBits, OPT_META),
		right    = 0 ~= bit_and(innerOptionBits, OPT_RIGHT),
		shift    = 0 ~= bit_and(innerOptionBits, OPT_SHIFT),
	}

	---@diagnostic disable-next-line:return-type-mismatch -- OK: CMD/number
	return index, innerCommand, innerOptions
end

---Efficiently repack a command's `cmdParams` table in-place to use with `CMD_INSERT`.
---@param unitID integer
---@param cmdID integer|CMD
---@param cmdParams number[]|CMD[]
---@param cmdOptions CommandOptions
---@param cmdTag integer
---@param fromInsert CommandOptions
local function giveInsertOrderToUnit(unitID, cmdID, cmdParams, cmdOptions, cmdTag, fromInsert)
	for i = #cmdParams, 1, -1 do cmdParams[i + 3] = cmdParams[i] end
	cmdParams[1], cmdParams[2], cmdParams[3] = cmdTag, cmdID, cmdOptions.coded
	spGiveOrderToUnit(unitID, CMD_INSERT, cmdParams, fromInsert.coded)
end

---Resend a modified command, repacking its `cmdParams` table if it was an inserted command.
---@param unitID integer
---@param cmdID integer|CMD
---@param cmdParams number[]|CMD[]
---@param cmdOptions CommandOptions
---@param cmdTag integer
---@param fromInsert CommandOptions
local function reissueOrder(unitID, cmdID, cmdParams, cmdOptions, cmdTag, fromInsert)
	if fromInsert ~= nil then
		giveInsertOrderToUnit(unitID, cmdID, cmdParams, cmdOptions, cmdTag, fromInsert)
	else
		spGiveOrderToUnit(unitID, cmdID, cmdParams, cmdOptions)
	end
end

-- Export module ---------------------------------------------------------------

return {
	GameCMD                = gameCommands,
	ImportCommandsToObject = importCommandsToObject,
	GetCommandCode         = getCommandCode,
	GetInsertedCommand     = getInsertedCommand,
	GiveInsertOrderToUnit  = giveInsertOrderToUnit,
	ReissueOrder           = reissueOrder,
}
