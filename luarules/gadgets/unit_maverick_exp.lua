function gadget:GetInfo()
	return {
		name		= "Maverick Exp",
		desc		= "Sets Maverick exp",
		author		= "BD",
		date		= "-",
		license		= "WTFPL",
		layer		= 0,
		enabled		= true -- loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then
    return false
end


local SetUnitExperience = Spring.SetUnitExperience
local AreTeamsAllied = Spring.AreTeamsAllied
local GetUnitHealth = Spring.GetUnitHealth
local SetUnitWeaponState = Spring.SetUnitWeaponState

local min = math.min

function getCost(unitDefID)
	return UnitDefs[unitDefID].metalCost + UnitDefs[unitDefID].energyCost/60
end

local maverickUnitDefID = UnitDefNames["armmav"].id
local maverickCost = getCost(maverickUnitDefID)
local maverickOriginalRange = WeaponDefNames["armmav_armmav_weapon"].range

local mavericks = {}

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not attackerTeam then
		return
	end
	if AreTeamsAllied(unitTeam,attackerTeam) then
		return
	end
	local curExp = mavericks[attackerID]
	if not curExp then
		return
	end
    
	local _,targetMaxHealth = GetUnitHealth(unitID)
	local damageFraction = min(damage/targetMaxHealth,1)
	local costFraction = getCost(unitDefID) / maverickCost
	local expIncrease = damageFraction*costFraction*0.3
	if curExp > 3 then expIncrease = expIncrease / (curExp/3) end --linear up to 3, then level off. exp 3 is about the point at which the health increase becomes negligable.
	if curExp > 4 then expIncrease = expIncrease / (curExp) end 
	if curExp > 5 then expIncrease = expIncrease / (curExp*10) end 
	if curExp > 6 then expIncrease = 0 end --safety
	curExp = curExp + expIncrease
    
    local newRange = maverickOriginalRange * (1+curExp/10)
    SetUnitWeaponState(attackerID, 1, "range", newRange)

	SetUnitExperience(attackerID,curExp)
    mavericks[attackerID] = curExp
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	if unitDefID == maverickUnitDefID then
		mavericks[unitID] = 0
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if unitDefID == maverickUnitDefID then
		mavericks[unitID] = nil
	end
end
