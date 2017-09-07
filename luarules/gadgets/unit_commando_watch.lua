--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Commando Watch",
    desc      = "Commando Watch",
    author    = "TheFatController",
    date      = "Aug 17, 2010",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local MAPSIZEX = Game.mapSizeX
local MAPSIZEZ = Game.mapSizeZ
local COMMANDO = UnitDefNames["cormando"].id
local MINE2 = UnitDefNames["cormine4"].id
local MINE_BLAST = {}
MINE_BLAST[WeaponDefNames["mine_light"].id] = true
MINE_BLAST[WeaponDefNames["mine_medium"].id] = true
MINE_BLAST[WeaponDefNames["mine_heavy"].id] = true 
local mines = {}
local orderQueue = {}
local COMMANDO_MINELAYER = WeaponDefNames['cormando_commando_minelayer'].id

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
  if (unitDefID == COMMANDO) then  
    if (weaponID < 0) then
      local x,y,z = Spring.GetUnitPosition(unitID)
      if (x < 0) or (z < 0) or (x > MAPSIZEX) or (z > MAPSIZEZ) then
        Spring.DestroyUnit(unitID)
        return damage,1
      end
      local x,y,z = Spring.GetUnitVelocity(unitID)
      Spring.AddUnitImpulse(unitID,x*-0.66,y*-0.66,z*-0.66)
      return (damage*0.12),0
    elseif MINE_BLAST[weaponID] then
      return (damage*0.12),0.24
    end
  elseif mines[unitID] and (attackerID == mines[unitID]) then
    return 0,0
  elseif (weaponID == COMMANDO_MINELAYER) and (orderQueue[attackerID]==nil) and (attackerTeam) and (unitTeam) and (not Spring.AreTeamsAllied(attackerTeam,unitTeam)) and UnitDefs[unitDefID]["isBuilding"] then
	local attackerState = Spring.GetUnitStates(attackerID)
	if attackerState["movestate"] ~= 2 then return damage,1 end

	local vx,_,vz = Spring.GetUnitVelocity(unitID)
    local e,_,_,i = Spring.GetTeamResources(attackerTeam, "energy")
    local cQueue = Spring.GetCommandQueue(attackerID,20)
    local active = false
    for _,order in ipairs(cQueue) do
      if (order.id == CMD.MOVE) or (order.id < 0) then 
        active = true
        break
      end
    end
    if ((e > 1000) or (i > 1000)) and (not active) and (math.sqrt((vx*vx)+(vz*vz)) < 1.5) then
	  local x,_,z = Spring.GetUnitBasePosition(attackerID)
	  local ex,ey,ez = Spring.GetUnitBasePosition(unitID)
	  local r = Spring.GetUnitRadius(unitID)
	  for i=r/2,r+28,4 do
	    local angle = math.atan2((x-ex),(z-ez))
	    local angleMod = ((math.random(math.pi) - (math.pi/2)) * 0.25)
	    angle = (angle + angleMod)
	    tx = ex + (math.sin(angle) * i)
	    tz = ez + (math.cos(angle) * i)
	    if (Spring.TestBuildOrder(MINE2,tx,ey,tz,1) == 2) then
	  	  orderQueue[attackerID] = {tx,ey,tz}
	  	  break
	    end
	  end
	  return 0,0
	end
  end
  return damage,1
end

function gadget:GameFrame(n)
  for unitID,coords in pairs(orderQueue) do
	Spring.GiveOrderToUnit(unitID,MINE2*-1,coords,{})
    orderQueue[unitID] = nil
  end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  if builderID and (unitDefID == MINE2) and (Spring.GetUnitDefID(builderID) == COMMANDO) then
    mines[unitID] = builderID
  end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
  mines[unitID] = nil
  orderQueue[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
  mines[unitID] = nil
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transportID, transportTeam)
  if (COMMANDO == unitDefID) then
    Spring.SetUnitStealth(transportID, true)
  end
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
  if (COMMANDO == unitDefID) then
    Spring.SetUnitStealth(transportID, false)
  end
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------