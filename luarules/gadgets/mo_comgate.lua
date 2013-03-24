function gadget:GetInfo()
  return {
    name      = "Comgate",
    desc      = "Commander gate effect.",
    author    = "quantum, TheFatController",
    date      = "June 22, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------

local enabled = tonumber(Spring.GetModOptions().mo_comgate) or 0

if (enabled == 0) then 
  return false
end

if (gadgetHandler:IsSyncedCode()) then

local hiddenUnits = {}
local initdone = false
local gameStart = false

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
  if (not gameStart) and (UnitDefs[unitDefID].name == 'armcom') or (UnitDefs[unitDefID].name == 'corcom') then
    Spring.SetUnitNoDraw(unitID, true)
    Spring.SetUnitNeutral(unitID, true)
    Spring.SetUnitNoMinimap(unitID, true)
    local x,y,z = Spring.GetUnitPosition(unitID)
    Spring.MoveCtrl.Enable(unitID)
    Spring.MoveCtrl.SetPosition(unitID, x, y+32000, z)
    Spring.SetUnitHealth(unitID, {paralyze=3180})
    table.insert(hiddenUnits, {unitID=unitID,x=x,y=y,z=z})    
  end
end

function gadget:GameFrame(n)
  if (not gameStart) and (n > 5) then
    gameStart = true
    Spring.Echo("Initializing Commander Gate")   
  end
  if (n == 20) then
    for _, defs in ipairs(hiddenUnits) do
      Spring.SpawnCEG("COMGATE",defs.x,defs.y,defs.z,0,0,0)
      SendToUnsynced("gatesound", Spring.GetUnitTeam(defs.unitID), defs.x, defs.y+90, defs.z)
    end
  end
  if (n == 105) then
    for _, defs in ipairs(hiddenUnits) do
	if Spring.ValidUnitID(defs.unitID) then
		local x,_,z = Spring.GetUnitPosition(defs.unitID)
		local y = Spring.GetGroundHeight(x,z)
		Spring.MoveCtrl.SetPosition(defs.unitID, x, y, z)
        Spring.MoveCtrl.Disable(defs.unitID)
        Spring.SetUnitNoDraw(defs.unitID, false)
        Spring.SetUnitNeutral(defs.unitID, false)
        Spring.SetUnitNoMinimap(defs.unitID, false)
        Spring.SetUnitHealth(defs.unitID, {paralyze=0})
        Spring.GiveOrderToUnit(defs.unitID, CMD.INSERT, {0, CMD.STOP, CMD.OPT_SHIFT, defs.unitID}, CMD.OPT_ALT)
      end
    end
    Spring.Echo("Commander Gate Complete")
    gadgetHandler:RemoveGadget()
  end
end

else

local preloadmodels = (UnitDefNames["corcom"].radius + UnitDefNames["armcom"].radius)

function gadget:Initialize()
  gadgetHandler:AddSyncAction("gatesound", GateSound)
end

function GateSound(_,unitTeam,x,y,z)
  if (unitTeam == Spring.GetMyTeamID()) then
    Spring.PlaySoundFile("sounds/comgate.wav", 100, x,y,z)
  end
end

end
