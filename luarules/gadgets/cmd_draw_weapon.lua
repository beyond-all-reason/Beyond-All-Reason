function gadget:GetInfo()
	return {
		name = "DrawWeapon",
		desc = "Forces aimweapon script in neutral direction when an attack order is queued",
		author = "[Fx]Doo",
		date = "25 of June 2017",
		license = "Free",
		layer = 0,
		enabled = false
	}
end


if (gadgetHandler:IsSyncedCode()) then
function gadget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
--Needs unit list for units that shouldn't act like this (i.e nuke silos)
if cmdID == 20 then
	Spring.CallCOBScript(unitID, "AimPrimary", 0, 0, 0) --Should be bypassed if an aimweapon script is already running. (Avoid overriding current aim with a fake one)
end
end
end