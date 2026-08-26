require("spec_helper")

-- Ambient state that the mission_api modules read at load time, kept out of the shared
-- root spec_helper. Requiring this installs the stubs and returns RegisterMissionApiModules.

-- math.bit_and is one of Recoil's MathExtra additions, not standard Lua, so it needs a
-- stand-in here. Engine-side it takes a varargs list and folds it over 24-bit integers.
_G.math.bit_and = _G.math.bit_and
	or function(...)
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

-- Team layout, for modules that read it once at load rather than per call. Two playing
-- allyTeams and Gaia on its own, which is the arrangement a mission likely runs under.
_G.Spring.GetGaiaTeamID = _G.Spring.GetGaiaTeamID or function()
	return 2
end
_G.Spring.GetAllyTeamList = _G.Spring.GetAllyTeamList or function()
	return { 0, 1, 2 }
end
_G.Spring.GetTeamAllyTeamID = _G.Spring.GetTeamAllyTeamID or function(teamID)
	return teamID
end

-- Sim frames per second, which seismic_contacts reads at load for its update interval.
_G.Game.gameSpeed = _G.Game.gameSpeed or 30

-- validation.lua reads both command tables at load; specs fill in real IDs as needed.
_G.CMD = _G.CMD or {}
_G.GameCMD = _G.GameCMD or {}

-- Build the modules and shims and shams for the Mission API. These have a specific load order.
local function registerMissionApiModules()
	_G.GG["MissionAPI"] = _G.GG["MissionAPI"] or {}
	local modules = _G.GG["MissionAPI"].Modules or {}
	_G.GG["MissionAPI"].Modules = modules
	modules.ParameterTypes = modules.ParameterTypes or VFS.Include("luarules/mission_api/parameter_types.lua")
	modules.SeismicContacts = modules.SeismicContacts or VFS.Include("luarules/mission_api/seismic_contacts.lua")
	modules.DetectionLevels = modules.DetectionLevels or VFS.Include("luarules/mission_api/detection_levels.lua")
	return modules
end

return registerMissionApiModules
