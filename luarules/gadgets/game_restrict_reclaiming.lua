local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Restrict unit reclaiming',
		desc    = 'If reclaiming allied unit, give resulting metal to the ally when modoption enabled.',
		author  = 'RebelNode',
		date    = 'January 2026',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

if Spring.GetModOptions().tax_resource_sharing_amount == 0 and (not Spring.GetModOptions().easytax) then
	return false
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if attackerID == nil then
		return
	end
	cmdID, targetID = Spring.GetUnitWorkerTask(attackerID)
	if cmdID == CMD.RECLAIM then -- The unit was reclaimed
		local targetTeam = Spring.GetUnitTeam(unitID)
		if targetTeam and targetTeam ~= attackerTeam and Spring.AreTeamsAllied(attackerTeam, targetTeam) then
			_,metalCost,_ =Spring.GetUnitCosts (unitID)
			Spring.ShareTeamResource(attackerTeam, targetTeam, "metal", metalCost) -- This transfer does NOT trigger AllowResourceTransfer and thus it will not get taxed
		end
	end
end