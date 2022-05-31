

function gadget:GameFrame(frame)

end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)

end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)

end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)

end

function gadget:UnitGiven(unitID, unitDefID, unitNewTeam, unitOldTeam)

end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)

end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if damage then
        return damage
    else
        return 0
    end
end

function gadget:GameOver()
	gadgetHandler:RemoveGadget(self)
end