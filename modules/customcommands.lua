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
	PRIORITY = 34571,
	WANT_CLOAK = 37382,
	HOUND_WEAPON_TOGGLE = 37383, -- unused
	SMART_TOGGLE = 37384,
	AREA_ATTACK_GROUND = 39954,
	SMARTFIGHT = 39955,

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

return {
	GameCMD = gameCommands,
	ImportCommandsToObject = importCommandsToObject,
	GetCommandCode = getCommandCode,
 }
