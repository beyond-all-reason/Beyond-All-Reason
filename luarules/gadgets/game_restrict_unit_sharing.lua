local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Restrict Unit Sharing',
		desc    = 'Stun economy and builder units when transferred to ally when modoption enabled.',
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

if not Spring.GetModOptions().easytax then
	return false
end

-- gather all economy/builder units
local ecoUnits = {}
local commanders = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.unitgroup and (unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal" or unitDef.customParams.unitgroup == "builder" or unitDef.customParams.unitgroup == "buildert2" or unitDef.customParams.unitgroup == "buildert3") then
		ecoUnits[unitDefID] = true
	end
	if unitDef.customParams.iscommander then
		commanders[unitDefID] = true
	end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if (capture) then
		return true
	end
	beingBuilt, buildProgress = Spring.GetUnitIsBeingBuilt(unitID)
	if beingBuilt and buildProgress > 0 then
		return false -- sharing partly built nanoframes is not allowed because letting it decay bypasses taxation
	end
	if commanders[unitDefID] then
		_,_,isDead = Spring.GetTeamInfo(fromTeamID,false)
		if isDead or Spring.GetTeamRulesParam(fromTeamID, "numActivePlayers") == 0 then -- this is /take
			return true
		end
		return false
	end
    if ecoUnits[unitDefID] then
        local _, maxHealth, _ = Spring.GetUnitHealth(unitID)
        Spring.AddUnitDamage(unitID, maxHealth*5, 30) -- Stun for 30 seconds.
    end
	return true
end