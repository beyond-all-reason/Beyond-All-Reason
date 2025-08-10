local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Restrict Unit Sharing',
		desc    = 'Disable unit sharing based on different rules',
		author  = 'Hobo Joe',
		date    = 'August 2025',
		license = 'GNU GPL, v2 or later',
		layer   = 0,
		enabled = true
	}
end

----------------------------------------------------------------
-- Synced only
----------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return false
end

----------------------------------------------------------------
-- Modoption behavior
----------------------------------------------------------------

-- Each modoption defines its own *restricted* units
local unshareable = {}

-- No econ or builder sharing
local disableEconSharing = Spring.GetModOptions().disable_economic_sharing
if disableEconSharing then
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.canAssist or unitDef.isFactory then
			unshareable[unitDefID] = true
		end
		if unitDef.customparams and (unitDef.customparams.unitgroup == "energy" or unitDef.customparams.unitgroup == "metal") then
			unshareable[unitDefID] = true
		end
	end
end


-- No building sharing
if false then -- for demonstration
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isBuilding then
			unshareable[unitDefID] = true
		elseif unitDef.isBuilder and not unitDef.canMove and not unitDef.isFactory then
			-- nanos
			unshareable[unitDefID] = true
		end
	end
end


-- kill if empty array
if #unshareable == 0 then
	return false
end


function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if (capture) then
		return true
	elseif (unshareable[unitDefID]) then
		return false
	else
		return true
	end
end
