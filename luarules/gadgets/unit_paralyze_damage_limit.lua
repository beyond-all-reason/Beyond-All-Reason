
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

local maxTime = Spring.GetModOptions().emprework==true and 10 or 20 --- bug fixed


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
local unitOhms = {} -- rework related

for udid, ud in pairs(UnitDefs) do
	for id, v in pairs(excluded) do
		if string.find(ud.name, UnitDefs[id].name) then
			excluded[udid] = v
		end
		if ud.isBuilding then
			isBuilding[udid] = true
		end
	end

	
	if Spring.GetModOptions().emprework==true then
		unitOhms[udid] = ud.customParams.paralyzemultiplier or 1
		--Spring.Echo('ohm', ud.customParams.paralyzemultiplier)
		if tonumber(ud.customParams.paralyzemultiplier) or 0 > 0 then
		--Spring.Echo('ohm', ud.name, ud.customParams.paralyzemultiplier)
		end
	end			
	
end

	

local weaponParalyzeDamageTime = {}
for weaponDefID, def in pairs(WeaponDefs) do
    weaponParalyzeDamageTime[weaponDefID] = def.damages and def.damages.paralyzeDamageTime or maxTime
end

local spGetUnitHealth = Spring.GetUnitHealth


--Spring.Echo('hornet debug emp loaded')
--Spring.Debug.TableEcho(unitOhms)
function gadget:UnitPreDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, projID, aID, aDefID, aTeam)


    if paralyzer then
--Spring.Debug.TableEcho(isBuilding)
--Spring.Echo('hornet debug here2')
        -- restrict the max paralysis time of mobile units
        if aDefID and uDefID and weaponID and not isBuilding[uDefID] and not excluded[uDefID] then
		--Spring.Echo('hornet debug emp')
			
			
			local hp, maxHP, currentEmp = spGetUnitHealth(uID)
			local effectiveHP = Game.paralyzeOnMaxHealth and maxHP or hp
			local paralyzeDeclineRate = Game.paralyzeDeclineRate
			local thismaxtime = 0
			local ohm = 0
			if Spring.GetModOptions().emprework==true then
				ohm = unitOhms[uDefID]--	 or 0)) <= 0 and 0.6 or unitOhms[uDefID]
				-- if default resistance, maxstun cap slightly lowered
				-- if nondefault, max stun affected by resistance
				-- as drain is static this is only way to limit that variably, which is needed for T3 impact of EMP.
				--T3s now have slight weakness to EMP & can be stunned a little longer, which offsets the buff they get from high HP pool x the increased drain rate (without this, continuous sources are at huge disadvantage vs T3 units.)

				--Spring.Echo('ohm',ohm)
				--nts, useless without raised caps on cont sources, mothball pending current playtests
				--if ((0.01+ohm)>1) then --type coerce
					--ohm = ohm * 1.4 -- with 1.4, an EMP resistance of say 1.2 gains EMP only slightly faster but has nearly double max charge capacity relative to lesser units
				--end
				thismaxtime = weaponParalyzeDamageTime[weaponID] * ((ohm == 1 and 0.85) or ohm)
			else	
				thismaxtime = weaponParalyzeDamageTime[weaponID]
			end
			
			
			bufferdamage = hp / 100
			--rootdamage = (damage / 50) * hp^0.5
			--Spring.Echo('h damage rootdamage',hp,damage, rootdamage)
			damage = damage + bufferdamage --overcome relative effects drain
			
			
			--Spring.Echo('raw stuntime, ohm, using mult value, thismaxtime (pre-minumum)', weaponParalyzeDamageTime[weaponID], ohm, ((ohm == 1 and 0.5) or ohm), thismaxtime)
			--thismaxtime = math.max(1, thismaxtime)--prevent microstuns (compounds oddly with shuri unfortunately)
			
			--still obey the hard global cap though
			thismaxtime = math.min(maxTime, thismaxtime)
			--Spring.Echo('times', weaponParalyzeDamageTime[weaponID], thismaxtime, unitOhms[uDefID] or 1)
			
			--thanks to sprung for this arcane spell
			local maxEmpDamage = (1 + (thismaxtime / paralyzeDeclineRate)) * effectiveHP

			newdamage = math.max(0, math.min(damage, maxEmpDamage - currentEmp))
			--Spring.Echo('h mh ph wpt old new',hp,maxHP, currentEmp, thismaxtime, damage, newdamage)

			--Spring.Echo(Game.paralyzeDeclineRate)
			--Spring.Echo(Game.paralyzeOnMaxHealth)
			damage = newdamage
			--Spring.Debug.TableEcho(Game)
			--damage = mh +6 
			--Spring.Echo('new',h,mh, ph, max_para_damage, max_para_time, damage)
				
			
			
			
			
        end
        return damage, 1
    end
    return damage, 1
end
