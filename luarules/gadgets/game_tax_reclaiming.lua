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

-- We don't use UnitDestroyed because then we can't find out how much metal is in a partially built unit
function gadget:AllowUnitBuildStep(builderID, builderTeam, unitID, unitDefID, step)
	local hp,maxhp,_,_,currentBuild = Spring.GetUnitHealth(unitID)
	local objectTeam = Spring.GetUnitTeam(unitID)
    if step < 0 then -- reclaim step
		if (hp + step * maxhp) <= 0 then -- we only care about the last bit
			local metalCost = UnitDefs[unitDefID].metalCost * currentBuild
			Spring.AddTeamResource(builderTeam, "metal", metalCost * (1- sharingTax))
			Spring.DestroyUnit(unitID, false, true, nil, true)
			return false
		end
	end
	return true
end