function gadget:GetInfo()
    return {
        name      = "Unit kill count",
        desc      = "",
        author    = "Floris",
        date      = "February 2022",
        license   = "GNU GPL, v2 or later",
        layer     = 5,
        enabled   = true
    }
end

if gadgetHandler:IsSyncedCode() then

	-- crashing planes are handled in crashing_aircraft gadget
	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
		if attackerID then
			local kills = Spring.GetUnitRulesParam(attackerID, "kills") or 0
			Spring.SetUnitRulesParam(attackerID, "kills", kills + 1)
		end
	end

end
