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
local disable_share_econ_and_lab = Spring.GetModOptions().disable_unit_sharing_economy_and_production or tax_resource_sharing_enabled
local disable_share_combat_units = Spring.GetModOptions().disable_unit_sharing_combat_units
local disable_share_all = Spring.GetModOptions().disable_unit_sharing_all

if not disable_share_econ_and_lab and not disable_share_combat_units and not disable_share_all then 
	return false
end



-- create a table of all mex and geo unitDefIDs
local isEconOrLab = {} 
local isCombatUnitOrTacticalBuilding = {} 


	-- List storages manually (some units or buildings may provide e or m storage but they are not primarily econ)
	local storageNames = {
		"armestor", "corestor", "legestor", "armuwes", "coruwes", "leguwes", "armuwadves", "coruwadves", "leguwadves",
		"armmstor", "cormstor", "legmstor", "armuwms", "coruwms", "leguwms", "armuwadvms", "coruwadvms", "leguwadvms",
	}


for unitDefID, unitDef in pairs(UnitDefs) do
	-- Mark econ units
	if unitDef.isBuilding and (unitDef.energyMake or unitDef.extractsMetal > 0) > 0 then
		isEconOrLab[unitDefID] = true
	elseif unitDef.canResurrect then
		isEconOrLab[unitDefID] = true
	elseif unitDef.customParams.energyconv_capacity then
		isEconOrLab[unitDefID] = true
	elseif table.contains(storageNames, unitDef.name) then
		isEconOrLab[unitDefID] = true

	-- Mark labs and mobile production
	elseif unitDef.isFactory or unitDef.isBuilder then
		isEconOrLab[unitDefID] = true
	end

	-- Mark combat units and tactical buildings
	if unitDef.isBuilding and not isEconOrLab[unitDefID] then 
		isCombatUnitOrTacticalBuilding[unitDefID] = true
	elseif #unitDef.weapons > 0 then
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

if Spring.GetModOptions().unit_market then
	-- let unit market handle unit sharing so that buying units will still work. 
	return false
end


function gadget:AllowUnitTransfer(unitID, unitDefID, fromTeamID, toTeamID, capture)
	if(capture) then
		return true
	end
	return allowedToBeShared(unitDefID)
end



