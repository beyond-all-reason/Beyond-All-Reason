function gadget:GetInfo()
    return {
        name      = 'game_No_Gib_Damage.lua',
        desc      = 'Removes damage from unit gibs',
        author    = '',
        version   = 'v1.0',
        date      = 'April 2011',
        license   = 'GNU GPL, v2 or later',
        layer     = 0,
        enabled   = true
    }
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
	
	--Remove damage hardcoded in the engine of gibbed pieces of units (hardcoded to 50 damage in engine)
	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
		if weaponDefID == -1 then
			return 0, 0
		end
		return damage
	end

end

	--UNSYNCED