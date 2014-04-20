--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "mo_preventdraw",
    desc      = "mo_preventdraw",
    author    = "TheFatController",
    date      = "Aug 31, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
	return false
end

local preventAllCombomb = (tonumber(Spring.GetModOptions().mo_preventcombomb) or 0) ~= 0
local preventDraw = (tonumber(Spring.GetModOptions().mo_preventdraw) or 0) ~= 0

if not preventDraw and not preventAllCombomb then
	return false
end

local GetTeamInfos = Spring.GetTeamInfos
local GetUnitPosition = Spring.GetUnitPosition
local GetGroundHeight = Spring.GetGroundHeight
local MoveCtrl = Spring.MoveCtrl
local GetGameFrame = Spring.GetGameFrame
local DestroyUnit = Spring.DestroyUnit




local COM_BLAST = WeaponDefNames['commander_blast'].id

local DGUN = {
    [WeaponDefNames['armcom_arm_disintegrator'].id] = true,
    [WeaponDefNames['corcom_arm_disintegrator'].id] = true,
}

local COMMANDER = {
  [UnitDefNames["corcom"].id] = true,
  [UnitDefNames["armcom"].id] = true,
}


local allyTeamComCount = {}

local immuneDgunList = {}
local ctrlCom = {}
local cantFall = {}

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if COMMANDER[unitDefID] then
		local allyTeamID = select(6,GetTeamInfos(unitTeam))
		allyTeamComCount[allyTeamID] = (allyTeamComCount[allyTeamID] or 0) + 1
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	if COMMANDER[unitDefID] then
		local allyTeamID = select(6,GetTeamInfos(unitTeam))
		allyTeamComCount[allyTeamID] = (allyTeamComCount[allyTeamID] or 0) - 1
	end
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	gadget:UnitCreated(unitID, unitDefID, unitTeam)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam,newTeam)
	gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer,
                            weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
	--falling damage
	if weaponID < 0 and cantFall[unitID] then
		return 0, 0
	end
	if DGUN[weaponID] then
		if immuneDgunList[unitID] then
			return 0, 0
		elseif COMMANDER[attackerDefID] and COMMANDER[unitDefID] then
			local targetAllyTeamID = select(6,Spring.GetTeamInfos(unitTeam))
			if preventAllCombomb or allyTeamComCount[targetAllyTeamID] == 1 then
				--enemy's last com
				immuneDgunList[unitID] = GetGameFrame() + 30
				DestroyUnit(attackerID,false,false,unitID)
				return 0, 0
			else
				return damage
			end
		end
	elseif weaponID == COM_BLAST and COMMANDER[unitDefID] then
		local targetAllyTeamID = select(6,Spring.GetTeamInfos(unitTeam))
		if unitID ~= attackerID and (allyTeamComCount[targetAllyTeamID] == 1 or preventAllCombomb ) then
			--prevent falling damage to the unit, and lock position
			MoveCtrl.Enable(unitID)
			ctrlCom[unitID] = GetGameFrame() + 30
			cantFall[unitID] = GetGameFrame() + 30
			return 0, 0
		else
			--com blast hurts the attacker
			return damage
		end
	end
	return damage,1
end

function gadget:GameFrame(currentFrame)
	for _,expirationTime in pairs(immuneDgunList) do
		if currentFrame > expirationTime then
			expirationTime = nil
		end
	end
	for unitID,expirationTime in pairs(ctrlCom) do
		if currentFrame > expirationTime then
			--if the game was actually a draw then this unitID is not valid anymore
			--if that is the case then just remove it from the cantFall list and clear the ctrlCom flag
			local x,_,z = GetUnitPosition(unitID)
			if x then
				local y = GetGroundHeight(x,z)
				MoveCtrl.SetPosition(unitID, x,y,z)
				MoveCtrl.Disable(unitID)
				cantFall[unitID] = currentFrame + 220
			else
				cantFall[unitID] = nil
			end

			expirationTime = nil
		end
	end
	for _,expirationTime in pairs(cantFall) do
		if currentFrame > expirationTime then
			expirationTime = nil
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------