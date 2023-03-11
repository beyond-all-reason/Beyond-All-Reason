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

function gadget:GameFrame(n)
	for unitID in pairs(updateList) do
		local currentXP = GetUnitExperience(unitID)
        if currentXP then
			local unitDef = UnitDefs[GetUnitDefID(unitID)]

			local rangeXPScale = unitDef.customParams.rangexpscale

            local limitXP = ((3*currentXP)/(1+3*currentXP))*rangeXPScale

            local newRange = WeaponDefs[unitDef.weapons[1].weaponDef].range  * ( 1 + limitXP )

            SetUnitWeaponState(unitID, 1, "range", newRange)
            SetUnitMaxRange(unitID,newRange)
        end
    end
	updateList = {}
end

function GG.requestMaverickExpUpdate(unitID)	
	local unitDef = UnitDefs[GetUnitDefID(unitID)]
	if(unitDef.customParams.rangexpscale == nil) then
		return
	end

	--schedule an update of range next frame when exp has been updated
    updateList[unitID] = true
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	--Check if it doesn't exist anymore
	if(UnitDefs[attackerDefID] == nil) then
		return
	end

	if(UnitDefs[attackerDefID].customParams.rangexpscale ~= nil) then
		updateList[attackerID] = true	--schedule an update of range next frame when exp has been updated
	end
end

function gadget:UnitDestroyed(unitID)
	updateList[unitID] = nil
end
