local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = 'Disable Unit Sharing',
		desc    = 'Disable unit sharing when modoption is enabled',
		author  = 'Rimilel',
		date    = 'April 2024',
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


local tax_resource_sharing_enabled = Spring.GetModOptions().tax_resource_sharing_amount ~= nil and Spring.GetModOptions().tax_resource_sharing_amount > 0
local unit_sharing_mode = Spring.GetModOptions().unit_sharing_mode

local disable_share_econ_and_lab = unit_sharing_mode == "disable_econ_and_lab_sharing" or "disable_econ_and_lab_and_combat_units"
local disable_share_combat_units = unit_sharing_mode == "disable_econ_lab_and_combat_units"
local disable_share_all = unit_sharing_mode == "disable_all"

if not unit_sharing_mode or unit_sharing_mode == "enable_all" then 
	return false
end

local isEconOrLab = {} 
local isCombatUnitOrTacticalBuilding = {} 

for unitDefID, unitDef in pairs(UnitDefs) do
	local treatAsCombatUnit = unitDef.customParams.disableunitsharing_treatascombatunit == "1"
	if not treatAsCombatUnit then
		-- Mark econ units
		if unitDef.customParams.unitgroup == "energy" or unitDef.customParams.unitgroup == "metal" then
			isEconOrLab[unitDefID] = true
		elseif unitDef.canResurrect then
			isEconOrLab[unitDefID] = true
		-- Mark labs and mobile production
		elseif (unitDef.isFactory or unitDef.isBuilder) then
			isEconOrLab[unitDefID] = true
		end
	end

	-- Mark combat units and tactical buildings
	if unitDef.isBuilding and not isEconOrLab[unitDefID] then 
		isCombatUnitOrTacticalBuilding[unitDefID] = true
	elseif #unitDef.weapons > 0 or treatAsCombatUnit then
		isCombatUnitOrTacticalBuilding[unitDefID] = true
	end
end


-- Returns whether the unit is allowed to be shared according to the unit sharing restrictions.
local function unitTypeAllowedToBeShared(unitDefID)
	if disable_share_all then return false end
	if disable_share_econ_and_lab and isEconOrLab[unitDefID] then return false end
	if disable_share_combat_units and isCombatUnitOrTacticalBuilding[unitDefID] then return false end
	return true
end
GG.disable_unit_sharing_unitTypeAllowedToBeShared = unitTypeAllowedToBeShared


if Spring.GetModOptions().enable_t2con_buying or Spring.GetModOptions().unit_market then
	-- If unit market is enabled, let unit market define AllowUnitTransfer referencing unitTypeAllowedToBeShared
	return false
end


function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if(capture) then
		return true
	end
	return unitTypeAllowedToBeShared(unitDefID)
end
