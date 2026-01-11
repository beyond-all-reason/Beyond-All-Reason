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

local function isAlliedUnit(teamID, unitID)
	local unitTeam = Spring.GetUnitTeam(unitID)
	return teamID and unitTeam and teamID ~= unitTeam and Spring.AreTeamsAllied(teamID, unitTeam)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	if attackerID == nil then
		return
	end
	if weaponDefID == Game.envDamageTypes.Reclaimed then -- The unit was reclaimed
		_,metalCost,_ =Spring.GetUnitCosts (unitID)
		Spring.UseTeamResource(attackerTeam, "metal", metalCost * sharingTax)
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	-- Disallow reclaiming unfinished allied units/nanoframes since we cannot tax it (UnitDestroyed isn't triggered for unfinished units)
	if (cmdID == CMD.RECLAIM and #cmdParams >= 1) then
		local targetID = cmdParams[1]
		if isAlliedUnit(unitTeam, targetID) then
			_,_,_,_,buildProgress = Spring.GetUnitHealth(targetID)
			if buildProgress < 1 then
				return false
			end
		end
	end
	return true
end