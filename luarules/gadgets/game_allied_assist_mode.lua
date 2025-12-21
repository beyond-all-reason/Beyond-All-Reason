local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Assist Ally Construction',
		desc    = 'Disable assisting allied units (e.g. labs and units/buildings under construction) when modoption is enabled',
		author  = 'Rimilel',
		date    = 'April 2024',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

local SharedEnums = VFS.Include("sharing_modes/shared_enums.lua")

if not gadgetHandler:IsSyncedCode() then
	return false
end

local modOptValue = Spring.GetModOptions()[SharedEnums.ModOptions.AlliedAssistMode]
local assistEnabled = modOptValue == SharedEnums.AlliedAssistMode.Enabled
Spring.Echo("[AlliedAssistMode] modoption key=" .. tostring(SharedEnums.ModOptions.AlliedAssistMode) .. " value=" .. tostring(modOptValue) .. " expected=" .. tostring(SharedEnums.AlliedAssistMode.Enabled) .. " assistEnabled=" .. tostring(assistEnabled))
if assistEnabled then
	Spring.Echo("[AlliedAssistMode] Assist is ENABLED - gadget will NOT block commands")
	return
end
Spring.Echo("[AlliedAssistMode] Assist is DISABLED - gadget WILL block guard/assist commands to allies")

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)

	-- Disallow guard commands onto labs, units that have buildOptions or can assist
	if cmdID == CMD.GUARD then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)
		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]

		if targetTeam and unitTeam ~= Spring.GetUnitTeam(targetID) and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			if #targetUnitDef.buildOptions > 0 or targetUnitDef.canAssist then
				return false
			end
		end
	-- Also disallow assisting building (caused by a repair command) units under construction
	-- Area repair doesn't cause assisting, so it's fine that we can't properly filter it
	elseif (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
		local targetID = cmdParams[1]
		local targetTeam = Spring.GetUnitTeam(targetID)
		if targetTeam and unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			return false
		end
	end

	return true
end
