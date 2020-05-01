
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

local maxTime = 20 -- in seconds

local excluded = {
    -- mobile units that are excluded from the maxTime limit
    [UnitDefNames.armscab.id] = true,
    [UnitDefNames.cormabm.id] = true,
    [UnitDefNames.corcarry.id] = true,
    [UnitDefNames.armcarry.id] = true,
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
        -- restrict the max paralysis time of mobile units to 15 sec
        if aDefID and uDefID and weaponID and not isBuilding[uDefID] and not excluded[uDefID] then
            local max_para_time = weaponParalyzeDamageTime[weaponID]
            local h,mh,ph = spGetUnitHealth(uID)
            local max_para_damage = mh + ((max_para_time<maxTime) and mh or mh*maxTime/max_para_time)
            damage = math.min(damage, math.max(0,max_para_damage-ph) )
            --Spring.Echo(h,mh, ph, max_para_damage, max_para_time, damage)
        end
        return damage, 1
    end
    return damage, 1
end
