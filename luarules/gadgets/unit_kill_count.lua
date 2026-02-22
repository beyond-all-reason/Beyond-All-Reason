local gadget = gadget ---@type Gadget

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

	local GetUnitRulesParam = Spring.GetUnitRulesParam
	local SetUnitRulesParam = Spring.SetUnitRulesParam
	
	local teamAllyteam = {}
	local teamList = Spring.GetTeamList()
	for i = 1, #teamList do
		teamAllyteam[teamList[i]] = select(6, Spring.GetTeamInfo(teamList[i]))
	end

	-- crashing planes are handled in crashing_aircraft gadget
	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		if attackerID and teamAllyteam[unitTeam] ~= teamAllyteam[attackerTeam] then
			local kills = GetUnitRulesParam(attackerID, "kills") or 0
			SetUnitRulesParam(attackerID, "kills", kills + 1)
		end
	end

end
