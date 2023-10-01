--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
   return {
      name      = "Time slow v2",
      desc      = "Time slow Weapon",
      author    = "Google Frog , (MidKnight made orig)",
      date      = "2010-05-31",
      license   = "GNU GPL, v2 or later",
      layer     = 0,
      enabled   = true
   }
end



if not gadgetHandler:IsSyncedCode() then
    return false
end


--SYNCED
if (gadgetHandler:IsSyncedCode()) then
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local spValidUnitID         = Spring.ValidUnitID
local spGiveOrderToUnit     = Spring.GiveOrderToUnit
local spGetUnitHealth       = Spring.GetUnitHealth
local spSetUnitRulesParam   = Spring.SetUnitRulesParam
local spGetUnitTeam         = Spring.GetUnitTeam
local spSetUnitTarget       = Spring.SetUnitTarget
local spGetUnitNearestEnemy	= Spring.GetUnitNearestEnemy
local GetUnitCost           = Spring.Utilities.GetUnitCost

local CMD_ATTACK = CMD.ATTACK
local CMD_REMOVE = CMD.REMOVE
local CMD_MOVE   = CMD.MOVE
local CMD_FIGHT  = CMD.FIGHT
local CMD_SET_WANTED_MAX_SPEED = CMD.SET_WANTED_MAX_SPEED
local LOS_ACCESS = {inlos = true}

include("LuaRules/Configs/customcmds.h.lua")

local gaiaTeamID = Spring.GetGaiaTeamID()

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local attritionWeaponDefs, MAX_SLOW_FACTOR, DEGRADE_TIMER, DEGRADE_FACTOR, UPDATE_PERIOD = include("LuaRules/Configs/timeslow_defs.lua")
local slowedUnits = {}

Spring.SetGameRulesParam("slowState",1)

local function updateSlow(unitID, state)
Spring.Echo(unitID)
	local health = spGetUnitHealth(unitID)

	if health then
		local maxSlow = health*(MAX_SLOW_FACTOR + (state.extraSlowBound or 0))
		if state.slowDamage > maxSlow then
			state.slowDamage = maxSlow
		end
		
		local percentSlow = state.slowDamage/health

		spSetUnitRulesParam(unitID,"slowState",percentSlow, LOS_ACCESS)
		GG.UpdateUnitAttributes(unitID)
	end
end

function gadget:UnitPreDamaged_GetWantedWeaponDef()
	local wantedWeaponList = {}
	for wdid = 1, #WeaponDefs do
		if attritionWeaponDefs[wdid] then
			wantedWeaponList[#wantedWeaponList + 1] = wdid
		end
	end
	return wantedWeaponList
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID,
                            attackerID, attackerDefID, attackerTeam)

	if (not spValidUnitID(unitID)) or (not weaponID) or (not attritionWeaponDefs[weaponID]) or ((not attackerID) and attritionWeaponDefs[weaponID].noDeathBlast)
		or (attritionWeaponDefs[weaponID].scaleSlow and damage == 0) then
		return damage
	end

	-- add stats that the unit requires for this gadget
	if not slowedUnits[unitID] then
		slowedUnits[unitID] = {
			slowDamage = 0,
			degradeTimer = DEGRADE_TIMER,
		}
	end
	local slowDef = attritionWeaponDefs[weaponID]

	-- add slow damage
	local slowdown = slowDef.slowDamage
	if slowDef.scaleSlow then
		slowdown = slowdown * (damage / slowDef.rawDamage)
	end --scale slow damage based on real damage (i.e. take into account armortypes etc.)

	slowedUnits[unitID].slowDamage = slowedUnits[unitID].slowDamage + slowdown
	slowedUnits[unitID].degradeTimer = DEGRADE_TIMER
	
	if slowDef.overslow then
		slowedUnits[unitID].extraSlowBound = math.max(slowedUnits[unitID].extraSlowBound or 0, slowDef.overslow)
	end

	if GG.Awards and GG.Awards.AddAwardPoints then
		local _, maxHp = spGetUnitHealth(unitID)
		local cost_slowdown = (slowdown / maxHp) * GetUnitCost(unitID)
		GG.Awards.AddAwardPoints ('slow', attackerTeam, cost_slowdown)
	end

	-- check if a target change is needed
	-- only changes target if the target is fully slowed and next order is an attack order
	-- also only change if the units health is above the health threshold smartRetargetHealth
	if spValidUnitID(attackerID) and slowDef.smartRetarget then
		local health = spGetUnitHealth(unitID)
		if slowedUnits[unitID].slowDamage > health*slowDef.smartRetarget and health > (slowDef.smartRetargetHealth or 0) then
			-- set order by player
			local cID_1, cOpt_1, cTag_1, cp_1, cp_2 = Spring.GetUnitCurrentCommand(attackerID)
			if cID_1 == CMD_ATTACK and (not cp_2) and cp_1 == unitID then
				local cID_2, cOpt_2, cTag_2, cps_1, cps_2 = Spring.GetUnitCurrentCommand(attackerID, 2)
				local cID_3 = Spring.GetUnitCurrentCommand(attackerID, 3)
				if cID_2 and (cID_2 == CMD_ATTACK or (cID_3 and cID_2 == CMD_SET_WANTED_MAX_SPEED and cID_3 == CMD_ATTACK)) then
					local re = Spring.Utilities.GetUnitRepeat(attackerID)
					if cID_2 == CMD_SET_WANTED_MAX_SPEED then
						spGiveOrderToUnit(attackerID,CMD_REMOVE,{cTag_1, cTag_2}, 0)
					else
						spGiveOrderToUnit(attackerID,CMD_REMOVE,cTag_1,0)
					end
					if re then
						spGiveOrderToUnit(attackerID,CMD_ATTACK, cp_1,CMD.OPT_SHIFT)
					end
				end
			end

			-- if attack is a non-player command
			if (not cID_1) or cID_1 ~= CMD_ATTACK or (cID_1 == CMD_ATTACK and Spring.Utilities.CheckBit(gadget:GetInfo().name, cOpt_1, CMD.OPT_INTERNAL)) then
				local newTargetID = spGetUnitNearestEnemy(attackerID,UnitDefs[attackerDefID].range, true)
				if newTargetID ~= unitID and spValidUnitID(attackerID) and spValidUnitID(newTargetID) then
					
					local team = spGetUnitTeam(newTargetID)
					if (not team) or team ~= gaiaTeamID then
						spSetUnitTarget(attackerID, newTargetID)
						if cID_1 and cID_1 == CMD_ATTACK then
							local cID_2, cOpt_2, cTag_2, cps_1, cps_2 = Spring.GetUnitCurrentCommand(attackerID, 2)
							if cID_2 and cID_2 == CMD_SET_WANTED_MAX_SPEED then
								spGiveOrderToUnit(attackerID,CMD_REMOVE,{cTag_1,cTag_2}, 0)
							else
								spGiveOrderToUnit(attackerID,CMD_REMOVE,cTag_1,0)
							end
						elseif cID_2 and (cID_1 == CMD_MOVE or cID_1 == CMD_RAW_MOVE or cID_1 == CMD_RAW_BUILD) then
							local cID_2, cOpt_2, cTag_2, cps_1, cps_2 = Spring.GetUnitCurrentCommand(attackerID, 2)
							if cID_2 == CMD_FIGHT and Spring.Utilities.CheckBit(gadget:GetInfo().name, cOpt_2, CMD.OPT_INTERNAL) and (not cps_2) and cps_1 == unitID then
								spGiveOrderToUnit(attackerID,CMD_REMOVE,cTag_2,0)
							end
						end
					end
				end
			end
		end
	end

	-- write to unit rules param
	updateSlow( unitID, slowedUnits[unitID])

	if slowDef.onlySlow then
		return 0
	else
		return damage
	end
end


local function addSlowDamage(unitID, damage, overslow)
	-- add stats that the unit requires for this gadget
	local su = slowedUnits[unitID]
	if not su then
		su = {
			slowDamage = 0,
		}
		slowedUnits[unitID] = su
	end

	-- add slow damage
	su.slowDamage = su.slowDamage + damage
	su.degradeTimer = DEGRADE_TIMER
	if overslow then
		su.extraSlowBound = math.max(overslow * DEGRADE_FACTOR, su.extraSlowBound or 0)
	end

	updateSlow(unitID, su) -- without this unit does not fire slower, only moves slower
end

local function getSlowDamage(unitID)
	if slowedUnits[unitID] then
		return slowedUnits[unitID].slowDamage
	end
	return false
end


-- morph uses this
GG.getSlowDamage = getSlowDamage
GG.addSlowDamage = addSlowDamage

local function removeUnit(unitID)
	slowedUnits[unitID] = nil
end

function gadget:GameFrame(f)
    if (f-1) % UPDATE_PERIOD == 0 then
        for unitID, state in pairs(slowedUnits) do
			if state.extraSlowBound then
				state.extraSlowBound = state.extraSlowBound - DEGRADE_FACTOR
				if state.extraSlowBound <= 0 then
					state.extraSlowBound = nil
				end
			end
			if state.degradeTimer <= 0 then
				local health = spGetUnitHealth(unitID) or 0
				state.slowDamage = state.slowDamage - health*DEGRADE_FACTOR
			else
				state.degradeTimer = state.degradeTimer-1
			end
			if state.slowDamage < 0 then
				state.slowDamage = 0
				updateSlow(unitID, state)
				removeUnit(unitID)
			else
				updateSlow(unitID, state)
			end
        end
    end
end


function gadget:UnitDestroyed(unitID)
   removeUnit(unitID)
end

end
