function gadget:GetInfo()
	return {
		name		= "Maverick Exp",
		desc		= "Sets Maverick exp effect",
		author		= "BrainDamage",
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

local isMaverick = {}
for udid, ud in pairs(UnitDefs) do
	if string.find(ud.name, 'armmav') then
		isMaverick[udid] = true
	end
end
local maverickOriginalRange = WeaponDefNames["armmav_armmav_weapon"].range

local updateList = {}

function gadget:GameFrame(n)
	for unitID in pairs(updateList) do
		local curExp = GetUnitExperience(unitID)
        if curExp then
            local limExp = (curExp/(1+curExp))*0.6
            local newRange = maverickOriginalRange * ( 1 + limExp )
            SetUnitWeaponState(unitID, 1, "range", newRange)
            SetUnitMaxRange(unitID,newRange)
        end
    end
	updateList = {}
end

function GG.requestMaverickExpUpdate(unitID)
	if not isMaverick[GetUnitDefID(unitID)] then
		return
	end
	--schedule an update of range next frame when exp has been updated
    updateList[unitID] = true
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if isMaverick[attackerDefID] then
		updateList[attackerID] = true	--schedule an update of range next frame when exp has been updated
	end
end

function gadget:UnitDestroyed(unitID)
	updateList[unitID] = nil
end
