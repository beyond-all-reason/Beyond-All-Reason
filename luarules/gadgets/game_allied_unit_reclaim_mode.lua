local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Allied Reclaim Control",
		desc = "Controls reclaiming allied units based on modoption",
		author = "Rimilel",
		date = "October 2025",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local ModeEnums = VFS.Include("modes/sharing_mode_enums.lua")

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

local reclaimEnabled = Spring.GetModOptions()[ModeEnums.ModOptions.AlliedUnitReclaimMode] == ModeEnums.AlliedUnitReclaimMode.Enabled
if reclaimEnabled then
	return
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.RECLAIM)
	gadgetHandler:RegisterAllowCommand(CMD.GUARD)
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID == CMD.RECLAIM and #cmdParams >= 1 then
		local targetID = cmdParams[1]
		local targetTeam

		if targetID >= Game.maxUnits then
			return true
		end

		targetTeam = Spring.GetUnitTeam(targetID)
		if targetTeam == nil then
			return true -- shouldn't happen; GetUnitTeam is nullable
		end

		if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			return false
		end
	elseif cmdID == CMD.GUARD and #cmdParams >= 1 then
		local targetID = cmdParams[1]

		if targetID >= Game.maxUnits then
			return true
		end

		local targetTeam = Spring.GetUnitTeam(targetID)
		if targetTeam == nil then
			return true -- shouldn't happen; GetUnitTeam is nullable
		end

		local targetUnitDef = UnitDefs[Spring.GetUnitDefID(targetID)]

		if unitTeam ~= targetTeam and Spring.AreTeamsAllied(unitTeam, targetTeam) then
			-- labs count as canReclaim, so guarding them is blocked too
			if targetUnitDef and targetUnitDef.canReclaim then
				return false
			end
		end
	end
	return true
end
