
function gadget:GetInfo()
    return {
        name      = 'Mobile Unit Paralyze Damage Handler',
        desc      = 'Limit mobile units max paralysis time',
        author    = 'Bluestone',
        version   = '',
        date      = 'Monkeya',
        license   = 'GNU GPL, v2 or later',
        layer     = 100,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local maxTime = Spring.GetModOptions().emprework==true and 10 or 20 --- this is ignored in EMP rework and vanilla, bug is probably below, maybe L56


local excluded = {
    -- mobile units that are excluded from the maxTime limit
    [UnitDefNames.armscab.id] = true,
    [UnitDefNames.cormabm.id] = true,
    [UnitDefNames.corcarry.id] = true,
    [UnitDefNames.armcarry.id] = true,
	[UnitDefNames.armantiship.id] = true,
	[UnitDefNames.corantiship.id] = true,
}
local isBuilding = {}
for udid, ud in pairs(UnitDefs) do
    for id, v in pairs(excluded) do
        if string.find(ud.name, UnitDefs[id].name) then
            excluded[udid] = v
        end
        if ud.isBuilding then
            isBuilding[udid] = true
        end
    end
end

local weaponParalyzeDamageTime = {}
for weaponDefID, def in pairs(WeaponDefs) do
    weaponParalyzeDamageTime[weaponDefID] = def.damages and def.damages.paralyzeDamageTime or maxTime
end

local spGetUnitHealth = Spring.GetUnitHealth



function gadget:UnitPreDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, projID, aID, aDefID, aTeam)


    if paralyzer then
--Spring.Echo('hornet debug here2')
        -- restrict the max paralysis time of mobile units to 15 sec
        if aDefID and uDefID and weaponID and not isBuilding[uDefID] and not excluded[uDefID] then
		Spring.Echo('hornet debug emp')
			
			--local hp, maxHP, currentEmp = spGetUnitHealth(uID)
			--local effectiveHP = maxHP --Game.paralyzeOnMaxHealth and maxHP or hp
			--local paralyzeDeclineRate = 30 --Game.modrules.paralyze.paralyzeDeclineRate
			--local maxEmpDamage = (1 + (weaponParalyzeDamageTime[weaponID] / paralyzeDeclineRate)) * effectiveHP
            --Spring.Echo(Game.paralyze.paralyzeDeclineRate)
            --Spring.Echo('old',h,mh, ph, damage)
			--damage = math.max(0, math.min(damage, maxEmpDamage - currentEmp))
           -- Spring.Echo('new',h,mh, ph, damage)

            --Spring.Echo(Game.paralyzeDeclineRate)
            --Spring.Echo(Game.paralyzeOnMaxHealth)
			--Spring.Debug.TableEcho(Game)
            --damage = mh +6 
            --Spring.Echo('new',h,mh, ph, max_para_damage, max_para_time, damage)
        end
        return damage, 1
    end
    return damage, 1
end
