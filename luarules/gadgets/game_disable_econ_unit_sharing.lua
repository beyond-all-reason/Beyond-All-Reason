local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Economic Unit Sharing',
		desc    = 'Disable sharing any economic or builder units when modoption is enabled',
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

if not Spring.GetModOptions().disable_economic_sharing then
	return false
end

Spring.Echo("Sharing restrictions on economic units are active")

local unshareable = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.canAssist or unitDef.isFactory then
		unshareable[unitDefID] = true
	end
	if unitDef.customparams and (unitDef.customparams.unitgroup == "energy" or unitDef.customparams.unitgroup == "metal") then
		unshareable[unitDefID] = true
	end
end

function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if unshareable[unitDefID] then
		return false
	end
	return true
end
