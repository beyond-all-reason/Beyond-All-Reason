function gadget:GetInfo()
  return {
    name      = "Transportee Commands and friendly damages",
    desc      = "Allows/disallows certain damages and/or cmds on transported units",
    author    = "Doo",
    date      = "03/22/18",
    license   = "GNU GPL v2",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

if (gadgetHandler:IsSyncedCode()) then
	notallowed = {[CMD.MOVE] = true,[CMD.REPAIR] = true,[CMD.FIGHT] = true,[CMD.PATROL] = true,[CMD.GUARD] = true}

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, synced)
		if (Spring.GetUnitRulesParam(unitID, "IsTranported") and Spring.GetUnitRulesParam(unitID, "IsTranported") == "true" ) then
			if notallowed[cmdID] or cmdID < 0 then
				return false
			else
				return true
			end
		end
		return true
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if attackerTeam and attackerTeam == unitTeam and (Spring.GetUnitRulesParam(unitID, "IsTranported") and Spring.GetUnitRulesParam(unitID, "IsTranported") == "true" )then
			return 0
		else
			return damage
		end
		return damage
	end
else

end


