
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
--Spring.Echo('hornet debug here3')
            local max_para_time = weaponParalyzeDamageTime[weaponID]
            local h,mh,ph = spGetUnitHealth(uID)
            local max_para_damage = mh + ((max_para_time<maxTime) and mh or mh*maxTime/max_para_time)
			
			
			--actual_maximum_time = max_para_time<maxTime and max_para_time or maxTime
			
			
			-----paralyzeDamage may not get higher than baseHealth * (paralyzeTime + 1),
			
			--max_para_damage = mh + actual_maximum_time
			
			
			--required logic
			-- find if weapon max time or global max time is the lower
			--evaluate if incoming damage would exceed that required to stun for more than the max time
			--if so, reduce damage to the maximum permissible
            --Spring.Echo(max_para_time, maxTime, max_para_time<maxTime)
            --Spring.Echo(mh + ((max_para_time<maxTime) and mh))
            --Spring.Echo(mh*maxTime/max_para_time)
			
			--4650, 4650, 157.083923, 9300, 7, 159.609848
			
			--
            --Spring.Echo('max-ph', max_para_damage-ph)
            --Spring.Echo(h,mh, ph, max_para_damage, max_para_time, damage)
            --Spring.Echo(h,mh, ph, max_para_damage, max_para_time, damage)
            damage = math.min(damage, math.max(0,max_para_damage-ph) )
			
			--notes:
			--mh + mh = 10s stun visually
			--mh + mh/10 = 10s stun visually
			--mh - mh/2 = 10s stun visually
            --damage = mh/100 - 3% charge on a bull
            --damage = mh/20 - 12-15% charge
            --damage = mh/10 - 30% charge
            --damage = mh/5 - 60% charge
			-- /4 72% on bull
			-- /2 full and 10s stun , 3% on an afus
			
			
			
			

			
			
            --damage = mh +6 
            --Spring.Echo('new',h,mh, ph, max_para_damage, max_para_time, damage)
        end
        return damage, 1
    end
    return damage, 1
end
