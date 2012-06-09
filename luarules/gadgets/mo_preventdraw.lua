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

if (Spring.GetModOptions().deathmode~="com") and (not Game.commEnds) then
  return false
end

local enabled = tonumber(Spring.GetModOptions().mo_preventdraw) or 0

if (enabled == 0) then 
  return false
end

local GetAllUnits = Spring.GetAllUnits

local COM_BLAST = WeaponDefNames['commander_blast'].id

local DGUN = {
    [WeaponDefNames['armcom_arm_disintegrator'].id] = true,
    [WeaponDefNames['corcom_arm_disintegrator'].id] = true,
}

local COMMANDER = {
  [UnitDefNames["corcom"].id] = true,
  [UnitDefNames["armcom"].id] = true,
}

local watchList = {}

local immuneCom = nil
local ctrlCom = nil
local cantFall = nil

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, 
                            weaponID, attackerID, attackerDefID, attackerTeam)  
  if cantFall and (cantFall == unitID) and (weaponID < 0) then      
    return 0, 0
  end     
  if DGUN[weaponID] then
    if (immuneCom == unitID) then
      return 0, 0
    elseif COMMANDER[attackerDefID] and COMMANDER[unitDefID] then
      for _, uID in ipairs(GetAllUnits()) do
        if (uID ~= unitID) and (uID ~= attackerID) then
          if COMMANDER[Spring.GetUnitDefID(uID)] then
            return damage
          end
        end
      end
      immuneCom = unitID
      watchList[unitID] = Spring.GetGameFrame() + 30
      Spring.DestroyUnit(attackerID,false,false,unitID)
      Spring.Echo("Commander Ends No Draw: Reversal of Fortune!")
      return 0, 0
    end             
  elseif (weaponID == COM_BLAST) and COMMANDER[unitDefID] then
    for _, uID in ipairs(GetAllUnits()) do
      if uID ~= unitID then
        if COMMANDER[Spring.GetUnitDefID(uID)] and (not Spring.GetUnitIsDead(uID)) then
          return damage
        end
      end
    end
    Spring.MoveCtrl.Enable(unitID)
    ctrlCom = unitID
    cantFall = unitID
    watchList[unitID] = Spring.GetGameFrame() + 30
    return 0, 0
  end
  return damage,1
end

function gadget:GameFrame(n)
  for unitID,t in pairs(watchList) do
    if (n > t) then
      if (immuneCom == unitID) then
        immuneCom = nil
        break
      elseif (ctrlCom == unitID) then
        --if the game was actually a draw then this unitID is not valid anymore
        --if that is the case then just remove it from the watchList and clear the ctrlCom flag		
        local x,_,z = Spring.GetUnitPosition(unitID)
        if (x) then
            local y = Spring.GetGroundHeight(x,z) 
            Spring.MoveCtrl.SetPosition(unitID, x,y,z)
            Spring.MoveCtrl.Disable(unitID)
            watchList[unitID] = Spring.GetGameFrame() + 220
        else
            watchList[unitID] = nil
        end
        
        ctrlCom = nil
        break
      elseif (cantFall == unitID) then
        cantFall = nil
        break
      else
        watchList[unitID] = nil
      end     
    end
  end 
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------