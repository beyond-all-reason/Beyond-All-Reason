--------------------------------------------------------------------------------
-- commands.lua ----------------------------------------------------------------

local bit_and = math.bit_and

local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMD_INSERT = CMD.INSERT

local OPT_INTERNAL = CMD.OPT_INTERNAL
local OPT_ALT = CMD.OPT_ALT
local OPT_CTRL = CMD.OPT_CTRL
local OPT_META = CMD.OPT_META
local OPT_RIGHT = CMD.OPT_RIGHT
local OPT_SHIFT = CMD.OPT_SHIFT

local function packInsertParams(cmdID, cmdParams, cmdOptions, cmdIndex)
	for i = #cmdParams, 1, -1 do
		cmdParams[i + 3] = cmdParams[i]
	end
	cmdParams[1], cmdParams[2], cmdParams[3] = cmdIndex, cmdID, cmdOptions.coded
	return cmdParams
end

-- Module functions ------------------------------------------------------------

---Unpack the inner command from the params of a `CMD_INSERT`.
---@param cmdParams number[]
---@return integer index If `options.alt`, the command tag, else queue position.
---@return CMD innerCommand
---@return CommandOptions innerOptions
local function unpackInsertParams(cmdParams)
	local index, innerCommand, innerOptionBits = cmdParams[1], cmdParams[2], cmdParams[3]

	-- Update in-place, and assume n >= 3:
	local n = #cmdParams
	for i = 1, n - 3 do
		cmdParams[i] = cmdParams[i + 3]
	end
	cmdParams[n    ] = nil
	cmdParams[n - 1] = nil
	cmdParams[n - 2] = nil

	local band = bit_and

	local innerOptions = {
		coded    = innerOptionBits,
		internal = 0 ~= band(innerOptionBits, OPT_INTERNAL),
		alt      = 0 ~= band(innerOptionBits, OPT_ALT),
		ctrl     = 0 ~= band(innerOptionBits, OPT_CTRL),
		meta     = 0 ~= band(innerOptionBits, OPT_META),
		right    = 0 ~= band(innerOptionBits, OPT_RIGHT),
		shift    = 0 ~= band(innerOptionBits, OPT_SHIFT),
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
---@param insertOptions CommandOptions|integer
local function giveInsertOrderToUnit(unitID, cmdID, cmdParams, cmdOptions, cmdTag, insertOptions)
	packInsertParams(cmdID, cmdParams, cmdOptions, cmdTag)
	spGiveOrderToUnit(unitID, CMD_INSERT, cmdParams, insertOptions)
end

---Resend a modified command, repacking its `cmdParams` table if it was an inserted command.
---@param unitID integer
---@param cmdID integer|CMD
---@param cmdParams number[]|CMD[]
---@param cmdOptions CommandOptions
---@param cmdTag integer
---@param fromInsert CommandOptions
local function reissueOrder(unitID, cmdID, cmdParams, cmdOptions, cmdTag, fromInsert)
	if fromInsert then
		giveInsertOrderToUnit(unitID, cmdID, cmdParams, cmdOptions, cmdTag, fromInsert.coded)
	else
		spGiveOrderToUnit(unitID, cmdID, cmdParams, cmdOptions)
	end
end

-- Export module ---------------------------------------------------------------

return {
	UnpackInsertParams    = unpackInsertParams,
	GiveInsertOrderToUnit = giveInsertOrderToUnit,
	ReissueOrder          = reissueOrder,
}
