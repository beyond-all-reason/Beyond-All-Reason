function gadget:GetInfo()
	return {
		name		= "Unit Range XP Update",
		desc		= "Applies weapon range bonus when unit earns XP",
		author		= "BrainDamage, lonewolfdesign",
		date		= "",
		license		= "WTFPL",
		layer		= 0,
		enabled		= true -- loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local SetUnitWeaponState = Spring.SetUnitWeaponState
local GetUnitExperience = Spring.GetUnitExperience
local SetUnitMaxRange = Spring.SetUnitMaxRange
local GetUnitDefID = Spring.GetUnitDefID

local updateList = {}
local XPDefs = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.rangexpscale ~= nil then
		XPDefs[unitDefID] = {unitDef.customParams.rangexpscale, WeaponDefs[unitDef.weapons[1].weaponDef].range}
	end
end

function gadget:GameFrame(n)
	for unitID, unitDefID in pairs(updateList) do
		local currentXP = GetUnitExperience(unitID)
        if currentXP then
			local rangeXPScale, originalRange = unpack(XPDefs[unitDefID])

            local limitXP = ((3*currentXP)/(1+3*currentXP))*rangeXPScale

            local newRange = originalRange  * ( 1 + limitXP )

            SetUnitWeaponState(unitID, 1, "range", newRange)
            SetUnitMaxRange(unitID,newRange)
        end
    end

	updateList = {}
end

function GG.requestMaverickExpUpdate(unitID)	
	local unitDefID = GetUnitDefID(unitID)
	if(XPDefs[unitDefID] == nil) then
		return
	end

	--schedule an update of range next frame when exp has been updated
    updateList[unitID] = unitDefID
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if(XPDefs[attackerDefID]) then		
		updateList[attackerID] = attackerDefID	--schedule an update of range next frame when exp has been updated
	end
end

function gadget:UnitDestroyed(unitID)
	updateList[unitID] = nil
end
