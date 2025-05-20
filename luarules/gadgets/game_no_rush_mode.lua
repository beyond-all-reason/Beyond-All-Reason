local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "No Rush Mode",
		desc    = "Stops players from getting out of their startbox for a set amount of time.",
		author  = "Damgam",
		date    = "2022",
		license = "GNU GPL, v2 or later",
		layer   = -100,
		enabled = Spring.GetModOptions().norushtimer > 0,
	}
end

-- Get Startbox Area of every player
local positionCheckLibrary = VFS.Include("luarules/utilities/damgam_lib/position_checks.lua")
local norushtimer = Spring.GetModOptions().norushtimer * 1800 -- modoption is stating minutes, and we need frames. 60 seconds * 30 frames = 1800

local CommandsToCatchMap = {                                -- CMDTYPES: ICON_MAP, ICON_AREA, ICON_UNIT_OR_MAP, ICON_UNIT_OR_AREA, ICON_UNIT_FEATURE_OR_AREA, ICON_BUILDING
	[CMD.MOVE] = true,
	[CMD.PATROL] = true,
	[CMD.FIGHT] = true,
	[CMD.ATTACK] = true,
	[CMD.AREA_ATTACK] = true,
	[CMD.REPAIR] = true,
	[CMD.LOAD_UNITS] = true,
	[CMD.UNLOAD_UNITS] = true,
	[CMD.UNLOAD_UNIT] = true,
	[CMD.RECLAIM] = true,
	[CMD.DGUN] = true,
	[CMD.RESTORE] = true,
	[CMD.RESURRECT] = true,
	[CMD.CAPTURE] = true,
	[34923] = true, -- Set Target
}

local CommandsToCatchUnit = { -- CMDTYPES: ICON_UNIT, ICON_UNIT_OR_MAP, ICON_UNIT_OR_AREA
	[CMD.ATTACK] = true,
	[CMD.GUARD] = true,
	[CMD.REPAIR] = true,
	[CMD.LOAD_UNITS] = true,
	[CMD.LOAD_ONTO] = true,
	[CMD.UNLOAD_UNITS] = true,
	[CMD.RECLAIM] = true,
	[CMD.DGUN] = true,
	[CMD.CAPTURE] = true,
	[34923] = true, -- Set Target
}

local CommandsToCatchFeature = { -- CMDTYPES: ICON_UNIT_FEATURE_OR_AREA
	[CMD.RECLAIM] = true,
	[CMD.RESURRECT] = true,
}

local LuaAIsToExclude = {
	["ScavengersAI"] = true,
	["RaptorsAI"] = true,
}

local TeamIDsToExclude = {} -- dynamically filled below

for _, teamID in ipairs(Spring.GetTeamList()) do
	local teamLuaAI = Spring.GetTeamLuaAI(teamID)
	if (teamLuaAI and LuaAIsToExclude[teamLuaAI]) then
		TeamIDsToExclude[teamID] = true
	end
end


if gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		gadgetHandler:RegisterAllowCommand(CMD.ANY)
	end
	function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
		local allowed = true
		local frame = Spring.GetGameFrame()

		if frame < norushtimer and (not TeamIDsToExclude[unitTeam]) then
			local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(unitTeam)
			if cmdID == CMD.INSERT then
			  -- CMD.INSERT wraps another command, so we need to extract it
			  cmdID = cmdParams[2]
			  -- Area commands have an extra radius parameter, so they shift by 4 instead of 3
			  local paramCountToShift = #cmdParams - 3
			  -- Shift the parameters to remove the CMD.INSERT wrapper and match normal command format
			  for i = 1, paramCountToShift do
			    cmdParams[i] = cmdParams[i + 3]
			  end
			  -- Clear any unused parameters after the shift
			  for i = paramCountToShift + 1, #cmdParams do
			    cmdParams[i] = nil
			  end
			end
			if cmdID < 0 then
				if cmdParams[1] and cmdParams[2] and cmdParams[3] then
					if not positionCheckLibrary.StartboxCheck(cmdParams[1], cmdParams[2], cmdParams[3], allyTeamID) then
						allowed = false
					end
				end
			elseif CommandsToCatchMap[cmdID] and #cmdParams >= 3 then
				if not positionCheckLibrary.StartboxCheck(cmdParams[1], cmdParams[2], cmdParams[3], allyTeamID) then
					allowed = false
				end

				if cmdParams[4] and not cmdParams[6] then -- might be map pos with radius, check radius range too
					if not positionCheckLibrary.StartboxCheck(cmdParams[1] + cmdParams[4], cmdParams[2], cmdParams[3], allyTeamID) or
						not positionCheckLibrary.StartboxCheck(cmdParams[1] - cmdParams[4], cmdParams[2], cmdParams[3], allyTeamID) or
						not positionCheckLibrary.StartboxCheck(cmdParams[1], cmdParams[2], cmdParams[3] + cmdParams[4], allyTeamID) or
						not positionCheckLibrary.StartboxCheck(cmdParams[1], cmdParams[2], cmdParams[3] - cmdParams[4], allyTeamID) then
						allowed = false
					end
				end
			elseif CommandsToCatchUnit[cmdID] and #cmdParams == 1 then
				local targetUnitID = cmdParams[1]
				if Spring.GetUnitDefID(targetUnitID) then
					local x, y, z = Spring.GetUnitPosition(targetUnitID)
					if not positionCheckLibrary.StartboxCheck(x, y, z, allyTeamID) then
						allowed = false
					end
				elseif Spring.GetFeatureDefID(targetUnitID - Game.maxUnits) and CommandsToCatchFeature[cmdID] then -- maybe it's a feature that we want to reclaim?
					local x, y, z = Spring.GetFeaturePosition(targetUnitID - Game.maxUnits)
					if not positionCheckLibrary.StartboxCheck(x, y, z, allyTeamID) then
						allowed = false
					end
				end
			elseif CommandsToCatchFeature[cmdID] and #cmdParams == 1 then
				local targetFeatureID = cmdParams[1]
				if Spring.GetFeatureDefID(targetFeatureID - Game.maxUnits) then
					local x, y, z = Spring.GetFeaturePosition(targetFeatureID - Game.maxUnits)
					if not positionCheckLibrary.StartboxCheck(x, y, z, allyTeamID) then
						allowed = false
					end
				end
			end
		end

		return allowed
	end
end
