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
local gaiaTeamID = Spring.GetGaiaTeamID()

function gadget:UnitCreated(unitID, unitDefID, teamID)
  if (not gameStart) and (UnitDefs[unitDefID].name == 'armcom') or (UnitDefs[unitDefID].name == 'corcom') then
    Spring.SetUnitNoDraw(unitID, true)
    Spring.SetUnitNeutral(unitID, true)
    Spring.SetUnitNoMinimap(unitID, true)
	Spring.SetUnitCloak(unitID, 4)
	Spring.TransferUnit(unitID, gaiaTeamID)
    hiddenUnits[unitID] = teamID
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
    for unitID, teamID in ipairs(hiddenUnits) do
	if Spring.ValidUnitID(defs.unitID) then
		Spring.SetUnitCloak(unitID, false)
		Spring.TransferUnit(unitID,teamID,false)
        Spring.SetUnitNoDraw(unitID, false)
        Spring.SetUnitNeutral(unitID, false)
        Spring.SetUnitNoMinimap(unitID, false)
        Spring.SetUnitHealth(unitID, {paralyze=0})
        Spring.GiveOrderToUnit(unitID, CMD.INSERT, {0, CMD.STOP, CMD.OPT_SHIFT, defs.unitID}, CMD.OPT_ALT)
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
