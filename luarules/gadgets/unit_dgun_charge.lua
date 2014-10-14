function gadget:GetInfo()
  return {
    name      = "Limit Dgun Use (Charge)",
    desc      = "DGun must charge before it fires",
    author    = "Bluestone",
    date      = "Sept 2014",
    license   = "GNU GPL, v3 or later",
    layer     = 0, 
    enabled   = true  
  }
end


-----------------------------
if gadgetHandler:IsSyncedCode() then 
-----------------------------

local shotCost = 10 -- %
local reloadRate = 1 -- % per sec

local CMD_MANUALFIRE = CMD.MANUALFIRE
local CMD_INSERT = CMD.INSERT

local coms = {} -- coms[unitID] = charge
local blocked = {}

function isCom(uDID)
    return UnitDefs[uDID].customParams.iscommander
end

local dgunWeapons = {
    [WeaponDefNames["corcom_arm_disintegrator"].id] = true,
    [WeaponDefNames["armcom_arm_disintegrator"].id] = true,    
}
local weaponNum = {}

function SetWeaponNum(uID, uDID)
    local weapons = UnitDefs[uDID].weapons
    local w
    for wID,_ in ipairs(weapons) do
        if WeaponDefs[weapons[wID].weaponDef].type=="DGun" then
            w = wID
            break
        end
    end
    weaponNum[uID] = w
end

function gadget:Initialize()
    for wDID,_ in pairs(dgunWeapons) do
        Script.SetWatchWeapon(wDID, true)
    end    

    local units = Spring.GetAllUnits()
    for _,uID in pairs(units) do
        local uDID = Spring.GetUnitDefID(uID)
        if isCom(uDID) then
            coms[uID] = 0
            SetWeaponNum(uID, uDID)
        end
    end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
    -- add the com, give it full charge
    if isCom(unitDefID) then
        coms[unitID] = 0
        SetWeaponNum(unitID, unitDefID)
        -- if the game has only just started, set charge to full
        if Spring.GetGameFrame()<10 then
            coms[unitID] = 100
        end
    end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
    -- remove the com
    if isCom(unitDefID) then
        coms[unitID] = nil
        weaponNum[unitID] = nil
        -- no need to remove the UnitRulesParam, engine will do that
    end
end

function gadget:ProjectileCreated(proID, proOwnerID, weaponDefID)
    if dgunWeapons[weaponDefID] and coms[proOwnerID] then
        coms[proOwnerID] = coms[proOwnerID] - shotCost
        if coms[proOwnerID]<shotCost then
            --Spring.GiveOrderToUnit(proOwnerID, CMD.REMOVE, {CMD.MANUALFIRE}, {"alt"}) -- remove all other dgun commands if we have too little charge left
            Spring.SetUnitWeaponState(proOwnerID, weaponNum[proOwnerID], "reloadState", Spring.GetGameFrame()+10) --GameFrame will take over from here
            local teamID = Spring.GetUnitTeam(proOwnerID)
            Spring.SendMessageToTeam(teamID, "Your D-Gun cannot fire without more charge!")
        end
    end    
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
    if not (cmdID == CMD_MANUALFIRE or (cmdID==CMD_INSERT and cmdParams[2]==CMD_MANUALFIRE)) then 
        return true
	end

    -- allow the command if we have enough charge
    if isCom(unitDefID) and coms[unitID] and coms[unitID] < shotCost then
        Spring.SendMessageToTeam(teamID, "Your D-Gun cannot fire without more charge!")
        return true -- this would not be a foolproof way to prevent the D-Gun, but it's still a sensible place to print a warning
    end
    return true
end

function gadget:UnitUnloaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
    -- set charge to 0 
    if coms[unitID] then
        coms[unitID] = 0 --safety
    end
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
    -- set charge to 0 
    if coms[unitID] then
        coms[unitID] = 0
    end
end


function gadget:GameFrame(n)
    -- increment the charge, set UnitRulesParam
    if n%5==0 then
        for uID,_ in pairs(coms) do
            if coms[uID]<100 and not Spring.GetUnitTransporter(uID) then
                coms[uID] = coms[uID] + (reloadRate/6)
            end
            if coms[uID]>100 then coms[uID] = 100 end
            Spring.SetUnitRulesParam(uID,"charge",coms[uID])
            if coms[uID]<shotCost and Spring.GetUnitWeaponState(uID, weaponNum[uID], "reloadState") < n+10 then
                Spring.SetUnitWeaponState(uID, weaponNum[uID], "reloadState", n+10)
            end
        end
    end
end


-----------------------------
else -- begin unsynced section
-----------------------------

-----------------------------
end -- end unsynced section
-----------------------------
