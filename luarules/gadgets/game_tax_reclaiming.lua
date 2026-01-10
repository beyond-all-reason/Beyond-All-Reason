local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Restrict unit reclaiming',
		desc    = 'If reclaiming alive unit, resulting metal is taxed.',
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

local sharingTax = Spring.GetModOptions().tax_resource_sharing_amount
if Spring.GetModOptions().easytax then
	sharingTax = 0.3 -- 30% tax for easytax modoption
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if attackerID == nil then
		return
	end
	cmdID, targetID = Spring.GetUnitWorkerTask(attackerID)
	if cmdID == CMD.RECLAIM then -- The unit was reclaimed
		_,metalCost,_ =Spring.GetUnitCosts (unitID)
		Spring.UseTeamResource(attackerTeam, "metal", metalCost * sharingTax)
	end
end