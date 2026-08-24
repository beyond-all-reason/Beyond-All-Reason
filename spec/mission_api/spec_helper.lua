require("spec_helper")

-- Ambient state that the mission_api modules read at load time, kept out of the shared
-- root spec_helper. Requiring this installs the stubs and returns RegisterMissionApiModules.

-- math.bit_and is one of Recoil's MathExtra additions, not standard Lua, so it needs a
-- stand-in here. Engine-side it takes a varargs list and folds it over 24-bit integers.
_G.math.bit_and = _G.math.bit_and or function(...)
	local result
	for _, value in ipairs({ ... }) do
		if result == nil then
			result = value
		else
			local folded, bit = 0, 1
			while result > 0 and value > 0 do
				if result % 2 == 1 and value % 2 == 1 then
					folded = folded + bit
				end
				result = math.floor(result / 2)
				value = math.floor(value / 2)
				bit = bit * 2
			end
			result = folded
		end
	end
	return result or 0
end

-- Command ids and option bits, as numbered in rts/Sim/Units/CommandAI/Command.h.
-- idle_states keys a table by CMD.MOVE and CMD.REPAIR at load, so a bare `CMD = {}`
-- fails there with "table index is nil". Specs that swap CMD out for their own table
-- get these put back by RegisterMissionApiModules, which reloads the modules anyway.
local function installCommandIDs()
	_G.CMD     = _G.CMD or {}
	_G.GameCMD = _G.GameCMD or {}

	local CMD = _G.CMD
	CMD.MOVE         = CMD.MOVE         or 10
	CMD.REPAIR       = CMD.REPAIR       or 40
	CMD.OPT_META     = CMD.OPT_META     or 4
	CMD.OPT_INTERNAL = CMD.OPT_INTERNAL or 8
	CMD.OPT_RIGHT    = CMD.OPT_RIGHT    or 16
	CMD.OPT_SHIFT    = CMD.OPT_SHIFT    or 32
	CMD.OPT_CTRL     = CMD.OPT_CTRL     or 64
	CMD.OPT_ALT      = CMD.OPT_ALT      or 128
end

installCommandIDs()

-- Build the modules and shims and shams for the Mission API. These have a specific load
-- order: trigger files read GG['MissionAPI'].Modules at include time, and the modules
-- they name read the engine globals above at theirs.
local function registerMissionApiModules()
	installCommandIDs()

	_G.GG['MissionAPI'] = _G.GG['MissionAPI'] or {}
	local modules = _G.GG['MissionAPI'].Modules or {}
	_G.GG['MissionAPI'].Modules = modules
	modules.ParameterTypes = modules.ParameterTypes or VFS.Include('luarules/mission_api/parameter_types.lua')
	modules.IdleStates     = modules.IdleStates     or VFS.Include('luarules/mission_api/idle_states.lua')
	return modules
end

return registerMissionApiModules
