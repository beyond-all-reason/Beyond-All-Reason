
if not Spring.GetModOptions().emprework then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
   return {
      name      = "Unit Slowing",
      desc      = "Unit movement and firerate slowing effects, used by EMP Rework",
      author    = "Google Frog , (MidKnight made orig)",
      date      = "2010-05-31",
      license   = "GNU GPL, v2 or later",
      layer     = 0,
      enabled   = true,
   }
end


if not gadgetHandler:IsSyncedCode() then
    return
end


local spValidUnitID         = Spring.ValidUnitID
local spGiveOrderToUnit     = Spring.GiveOrderToUnit
local spGetUnitHealth       = Spring.GetUnitHealth
local spSetUnitRulesParam   = Spring.SetUnitRulesParam
local spGetUnitTeam         = Spring.GetUnitTeam
local spSetUnitTarget       = Spring.SetUnitTarget
local spGetUnitNearestEnemy	= Spring.GetUnitNearestEnemy

local CMD_ATTACK = CMD.ATTACK
local CMD_REMOVE = CMD.REMOVE
local CMD_MOVE   = CMD.MOVE
local CMD_FIGHT  = CMD.FIGHT
local CMD_SET_WANTED_MAX_SPEED = CMD.SET_WANTED_MAX_SPEED
local LOS_ACCESS = {inlos = true}

include("LuaRules/Configs/customcmds.h.lua")

local gaiaTeamID = Spring.GetGaiaTeamID()

local attritionWeaponDefs, MAX_SLOW_FACTOR, DEGRADE_TIMER, DEGRADE_FACTOR, UPDATE_PERIOD = include("LuaRules/Configs/timeslow_defs.lua")
local slowedUnits = {}

Spring.SetGameRulesParam("slowState",1)

local function updateSlow(unitID, state)
	--Spring.Echo("hornet upd slow unit id " .. unitID .. "  state.slowDamage " .. state.slowDamage)--  .. "  max slow factor " .. MAX_SLOW_FACTOR)

	-- overslow seems to be a stacked slow aside from the existing, purpose unclear
	local health, maxHealth, paralyzeDamage, capture, build  = spGetUnitHealth(unitID)
	if health then
		local maxSlow = health*(MAX_SLOW_FACTOR + (state.extraSlowBound or 0))
		if paralyzeDamage > maxSlow then
			paralyzeDamage = maxSlow
		end

		--local percentSlow = state.slowDamage/health
		--maybe hook to modrules.paralyze.paralyzeOnMaxHealth
		-- 0.5  == 50% ?
		--Spring.Echo("hornet pd=" .. (paralyzeDamage or 0))

		local percentSlow = paralyzeDamage/maxHealth
		if paralyzeDamage < 5 then
			percentSlow = 0
		end

		--Spring.Echo("hornet updateSlow unit id " .. unitID .. " slowperc " .. percentSlow)
		spSetUnitRulesParam(unitID,"slowState",percentSlow, LOS_ACCESS)
		GG.UpdateUnitAttributes(unitID)

		--if paralyzeDamage < 5 then
			--Spring.Echo("hornetdebug removing unit" .. unitID)

			--slowedUnits[unitID] = nil
			----reset speeds to max in case something lingered?
			--spSetUnitRulesParam(unitID,"slowState",0, LOS_ACCESS)
			--GG.UpdateUnitAttributes(unitID)
		--end
	end
end


--nani the what now
--function gadget:UnitPreDamaged_GetWantedWeaponDef()
--	local wantedWeaponList = {}
--	for wdid = 1, #WeaponDefs do
--		if attritionWeaponDefs[wdid] then
--			wantedWeaponList[#wantedWeaponList + 1] = wdid
--		end
--	end
--	return wantedWeaponList
--end


function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, attackerID, attackerDefID, attackerTeam)
	--if (not spValidUnitID(unitID)) or (not weaponID) or (not attritionWeaponDefs[weaponID]) or ((not attackerID) and attritionWeaponDefs[weaponID].noDeathBlast)

	if not weaponID or not paralyzer or not spValidUnitID(unitID) then
		return damage
	else
		if not slowedUnits[unitID] then
			slowedUnits[unitID] = {
				slowDamage = damage,
				degradeTimer = DEGRADE_TIMER,
			}
		else
			slowedUnits[unitID].slowDamage = slowedUnits[unitID].slowDamage + damage
			slowedUnits[unitID].degradeTimer = DEGRADE_TIMER
		end
		updateSlow(unitID, slowedUnits[unitID]) -- without this unit does not fire slower, only moves slower
	end
end

local function removeUnit(unitID)
	slowedUnits[unitID] = nil
end

function gadget:GameFrame(f)
	if (f-1) % UPDATE_PERIOD == 0 then
		for unitID, state in pairs(slowedUnits) do
			--if state.extraSlowBound then
				--state.extraSlowBound = state.extraSlowBound - DEGRADE_FACTOR
				--if state.extraSlowBound <= 0 then
					--state.extraSlowBound = nil
				--end
			--end
			if state.degradeTimer <= 0 then
				--local health = spGetUnitHealth(unitID) or 0
				--state.slowDamage = state.slowDamage - health*DEGRADE_FACTOR
			else
				state.degradeTimer = state.degradeTimer-1
			end

			local _, _, paralyzeDamage = spGetUnitHealth(unitID)
			if paralyzeDamage < 5 then
				--Spring.Echo('hornet debug removing '.. unitID ..' via gameframe');
				--state.slowDamage = 0
				updateSlow(unitID, state)
				removeUnit(unitID)
			else
				updateSlow(unitID, state)
			end
		end
	end
end


function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
   removeUnit(unitID)
end
