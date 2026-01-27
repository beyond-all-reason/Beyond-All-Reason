function gadget:GetInfo()
    return {
        name      = "Seismic Ping",
        desc      = "Notify seismic pings to widgethandler",
        author    = "Floris",
        date      = "2026",
        license   = "GNU GPL, v2 or later",
        version   = 1,
        layer     = 5,
        enabled   = true
    }
end


if gadgetHandler:IsSyncedCode() then
	return
end

function gadget:UnitSeismicPing(x, y, z, strength, allyTeam, unitID, unitDefID)
	local myAllyTeam = Spring.GetMyAllyTeamID()
	local spectating = Spring.GetSpectatingState()
	if spectating or myAllyTeam == allyTeam then
		Script.LuaUI.UnitSeismicPing(x, y, z, strength, allyTeam)
	end
end

