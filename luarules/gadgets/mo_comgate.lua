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

--synced
if (gadgetHandler:IsSyncedCode()) then

local hiddenUnits = {}
local initdone = false
local gameStart = false
local gaiaTeamID = Spring.GetGaiaTeamID()


function gadget:UnitCreated(unitID, unitDefID, teamID)
	if (not gameStart) then
		local x,y,z = Spring.GetUnitPosition(unitID)
		hiddenUnits[unitID] = {x,y,z,teamID}
		Spring.SetUnitNoDraw(unitID,true) 
	end
end

function gadget:GameFrame(n)
  if (not gameStart) and (n > 5) then
    gameStart = true
    Spring.Echo("Initializing Commander Gate")   
  end
  if (n == 20) then
    for _,data in pairs(hiddenUnits) do
		Spring.SpawnCEG("COMGATE",data[1],data[2],data[3],0,0,0)
		SendToUnsynced("gatesound", data[4], data[1], data[2]+90, data[3])
    end
  end
  if (n == 105) then
    for unitID,_ in pairs(hiddenUnits) do
		Spring.SetUnitNoDraw(unitID,false)
    end
    Spring.Echo("Commander Gate Complete")
    gadgetHandler:RemoveGadget(self)
  end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	local n = Spring.GetGameFrame()
	if n < 105 then return false end
	return true
end


--unsynced
else

function gadget:Initialize()
  gadgetHandler:AddSyncAction("gatesound", GateSound)
end

function GateSound(_,unitTeam,x,y,z)
  if (unitTeam == Spring.GetMyTeamID()) then
    Spring.PlaySoundFile("sounds/comgate.wav", 100, x,y,z)
  end
end

end
