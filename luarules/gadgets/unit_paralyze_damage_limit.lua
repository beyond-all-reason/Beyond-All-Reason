
local gadget = gadget ---@type Gadget

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

local modOptions = Spring.GetModOptions()

local maxTime = modOptions.emprework==true and 10 or 20 --- bug fixed


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

local weaponParalyzeDamageTime = {}
local weaponsWithCustomStunLogic = {}
local weaponFixedStunDurations = {}
local weaponParalyzeTimeExceptions = {}

-- Custom Stun Logic: Parse the stun condition strings in customparams (Using CSV since customparams doesn't support tables of tables)
local function ParseStunConditionString(str)
	local result = {}
	if type(str) ~= "string" then return result end

	for entry in string.gmatch(str, "[^,]+") do
		local keyVal, dur = string.match(entry, "([^:]+):([^:]+)")
		if keyVal and dur then
			local key, val = string.match(keyVal, "([^=]+)=([^=]+)")
			if key and val then
				-- Convert val to boolean if needed
				if val == "true" then val = true elseif val == "false" then val = false end
				table.insert(result, {
					unitconditionkey = key,
					unitconditionvalue = val,
					stunduration = tonumber(dur),
				})
			end
		end
	end
	return result
end


for weaponDefID, def in pairs(WeaponDefs) do
    weaponParalyzeDamageTime[weaponDefID] = def.damages and def.damages.paralyzeDamageTime or maxTime

	-- Custom Stun Logic: Identify weapons with custom stun logic to avoid looping over all weapons again
	if def.customParams and (def.customParams.paralyzetime_exception or def.customParams.fixed_stun_duration) then
		weaponsWithCustomStunLogic[weaponDefID] = {
			paralyzetime_exception = ParseStunConditionString(def.customParams.paralyzetime_exception),
			fixed_stun_duration = ParseStunConditionString(def.customParams.fixed_stun_duration)
		}
	end

end

-- Custom Stun Logic: Evaluate custom conditions to determine the stun duration of a weapon on a specific unit
local function EvaluateCustomStunCondition(unitDef, unitConditionKey, unitConditionValue)
	if unitConditionKey == nil or unitConditionValue == nil then
		return false
	end

	-- Check customParams (ie: unitGroup) conditions
	if unitConditionKey:sub(1, 13) == "customparams." then
		local param = unitConditionKey:sub(14)
		return unitDef.customParams and tostring(unitDef.customParams[param]) == tostring(unitConditionValue)
	else
		-- Check unitDef property (ie: isBuilding) condition
		local fieldVal = unitDef[unitConditionKey]
		if type(fieldVal) == "boolean" then
			return fieldVal == unitConditionValue or tostring(fieldVal) == tostring(unitConditionValue)
		end
		if fieldVal ~= nil then
			return tostring(fieldVal) == tostring(unitConditionValue)
		end
	end

	return false
end


for udid, ud in pairs(UnitDefs) do
	for id, v in pairs(excluded) do
		if string.find(ud.name, UnitDefs[id].name) then
			excluded[udid] = v
		end
		if ud.isBuilding then
			isBuilding[udid] = true
		end
	end

	-- Precompute our fixed_stun_duration and paralyzetime_exceptions to save on computation during the game
	for weaponID, stunData in pairs(weaponsWithCustomStunLogic) do
		if stunData.paralyzetime_exception then
			weaponParalyzeTimeExceptions[weaponID] = weaponParalyzeTimeExceptions[weaponID] or {}
			for _, cond in ipairs(stunData.paralyzetime_exception) do
				local stunDuration = tonumber(cond.stunduration)
				if EvaluateCustomStunCondition(ud, cond.unitconditionkey, cond.unitconditionvalue) then
					weaponParalyzeTimeExceptions[weaponID][udid] = stunDuration
				end
			end
		end

		if stunData.fixed_stun_duration then
			weaponFixedStunDurations[weaponID] = weaponFixedStunDurations[weaponID] or {}
			for _, cond in ipairs(stunData.fixed_stun_duration) do
				local stunDuration = tonumber(cond.stunduration)
				if EvaluateCustomStunCondition(ud, cond.unitconditionkey, cond.unitconditionvalue) then
					weaponFixedStunDurations[weaponID][udid] = stunDuration
				end
			end
		end
	end

	if modOptions.emprework==true then
		unitOhms[udid] = ud.customParams.paralyzemultiplier == nil and 1 or tonumber(ud.customParams.paralyzemultiplier)--it arrives as a string because WHY NOT

		if tonumber(ud.customParams.paralyzemultiplier) or 0 > 0 then
		--Spring.Echo('ohm', ud.name, ud.customParams.paralyzemultiplier)
		end
	end

end

	


local spGetUnitHealth = Spring.GetUnitHealth

function gadget:UnitPreDamaged(uID, uDefID, uTeam, damage, paralyzer, weaponID, projID, aID, aDefID, aTeam)
	if not paralyzer then
		return damage, 1
	end

	if not uDefID or not weaponID then
		return damage, 1
	end

	local thismaxtime = 0
	local paralyzeTimeException = weaponParalyzeTimeExceptions[weaponID] and weaponParalyzeTimeExceptions[weaponID][uDefID]
	local hp, maxHP, currentEmp = spGetUnitHealth(uID)
	local effectiveHP = Game.paralyzeOnMaxHealth and maxHP or hp
	local paralyzeDeclineRate = Game.paralyzeDeclineRate

	if paralyzeTimeException then
		-- Custom Stun Logic: ParalyzeTime_Exception - Restrict a specific weapon-unit combination to a reduced paralyzetime
		thismaxtime = math.min(maxTime, paralyzeTimeException)
		local maxEmpDamage = (1 + (thismaxtime / paralyzeDeclineRate)) * effectiveHP
		damage = math.max(0, math.min(damage, maxEmpDamage - currentEmp))
		return damage, 1
	else
		-- restrict the max paralysis time of mobile units
		if not isBuilding[uDefID] and not excluded[uDefID] then
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


				if ohm>0 then
					bufferdamage = hp / 200
					--rootdamage = (damage / 50) * hp^0.5
					--Spring.Echo('h damage rootdamage',hp,damage, rootdamage)
					damage = damage + bufferdamage --overcome relative effects drain (eg stunned unit with 90000 hp loses 900 emp damage a tick, whereas unit with 900 hp loses 9 a tick. impossible to balance low damage emp weapons to overcome this without making them OP vs low HP units)
				end

			else
				thismaxtime = weaponParalyzeDamageTime[weaponID]
			end



			--Spring.Echo('raw stuntime, ohm, using mult value, thismaxtime (pre-minumum)', weaponParalyzeDamageTime[weaponID], ohm, ((ohm == 1 and 0.5) or ohm), thismaxtime)
			--thismaxtime = math.max(1, thismaxtime)--prevent microstuns (compounds oddly with shuri unfortunately)

			--still obey the hard global cap though
			thismaxtime = math.min(maxTime, thismaxtime)
			--Spring.Echo('times', weaponParalyzeDamageTime[weaponID], thismaxtime, unitOhms[uDefID] or 1)

			--thanks to sprung for this arcane spell
			local maxEmpDamage = (1 + (thismaxtime / paralyzeDeclineRate)) * effectiveHP

			newdamage = math.max(0, math.min(damage, maxEmpDamage - currentEmp))
			--Spring.Echo('h mh ph wpt old new',hp,maxHP, currentEmp, thismaxtime, damage, newdamage)

			damage = newdamage
			--damage = mh +6 
			--Spring.Echo('new',h,mh, ph, max_para_damage, max_para_time, damage)

		end
		return damage, 1
	end
	return damage, 1
end

--
-- Custom Stun Logic: Fixed_Stun_Duration - For specific weapon-unit combinations, apply a fixed stun duration, potentially exceeding the paralyzetime of the weapon by applying paralyzeDamage directly.
--
-- Implementation Note: You can only exceed a weapon's paralyzetime by applying the paralyzedamage AFTER the ApplyDamage Spring Engine function (which 
--	clamps the paralyzedamage to paralyzetime.) The UnitDamaged event handler happens right after ApplyDamage so we hook that for this feature.
--	paralyzetime clamp: https://github.com/beyond-all-reason/spring/blob/95d591b7c91f26313b58187692bd4485b39cb050/rts/Sim/Units/Unit.cpp#L1257

function gadget:UnitDamaged(unitID,unitDefID,unitTeam,damage,paralyzer,weaponDefID,projectileID,attackerID,attackerDefID,attackerTeam)
	if not paralyzer then
		return
	end
	if not weaponDefID or not unitDefID then
		return
	end

	local stunDuration = weaponFixedStunDurations[weaponDefID] and weaponFixedStunDurations[weaponDefID][unitDefID]

	if not stunDuration then
		return
	end

	local uHealth, uMaxHealth, uParalyze = Spring.GetUnitHealth(unitID)

	-- Support for paralyzeOnMaxHealth Feature
	local effectiveHP = Game.paralyzeOnMaxHealth and uMaxHealth or uHealth

	-- Still obey the EMP global hard-cap
	local applyTime = math.min(maxTime, stunDuration)

	-- Calculate the paralyzeDamage required for the fixed stun duration
	local paralyzeDamage = (1 + (applyTime / Game.paralyzeDeclineRate)) * effectiveHP

	-- Override the paralyzeDamage of the target to apply the fixed duration stun
	Spring.SetUnitHealth(unitID, { paralyze = paralyzeDamage })
end