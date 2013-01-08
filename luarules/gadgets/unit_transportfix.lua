--in BA "commando" unit always survives being shot down during transport
--when a com dies in mid air the damage done is controlled by mo_combomb_full_damage 

--several other ways to code this do not work because:
--when UnitDestroyed() is called, Spring.GetUnitIsTransporting is already empty -> meh
--checking newDamage>health in UnitDamaged() does not work because UnitDamaged() does not trigger on selfdestruct -> meh
--with releaseHeld, on death of a transport UnitUnload is called before UnitDestroyed
--when UnitUnloaded is called due to transport death, Spring.GetUnitIsDead (transportID) is still false
--when trans is self d'ed, on the frame it dies it has both Spring.GetUnitHealth(ID)>0 and Spring.UnitSelfDTime(ID)=0
--when trans is crashing it isn't dead
--SO: we wait one frame after UnitUnload and then check if the trans is dead/alive/crashing

--DestroyUnit(ID, true, true) will trigger self d explosion, won't leave a wreck but won't cause an explosion either
--DestroyUnit(ID, true, false) won't leave a wreck but won't cause the self d explosion either
--AddUnitDamage (ID, math.huge) makes a normal death explo but leaves wreck. Calling this for the transportee on the same framce as the trans dies results in a crash.


function gadget:GetInfo()
  return {
    name      = "transportfix",
    desc      = "kills units in transports when transports dies (except commandos)",
    author    = "knorke, bluestone",
    date      = "Dec 2012",
    license   = "horse has fallen over",
    layer     = 0,
    enabled   = true
  }
end

if (not gadgetHandler:IsSyncedCode()) then return end

local COMMANDO = UnitDefNames["commando"].id

toKill = {} -- [frame][unitID]
fromtrans = {}

currentFrame = 0

--when a unit is unloaded, mark it either as a commando or for destruction on next frame
function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)

	--Spring.Echo ("unloaded " .. unitID .. " (" .. unitDefID .. "), from transport " .. transportID)
	
	--BA has no transport that "normally" releaseHeld=true, so this is commented out
	--local transDefID =Spring.GetUnitDefID(transportID)
	--local transDef = UnitDefs [transDefID]
	--if (not transDef) then Spring.Echo ("transDef = nil!!!!!!!!!!!!!!!!!!!!!!!!") end		
	--if (not (transDef.customParams and transDef.customParams.releaseheld)) then *** 
	
	if (unitDefID ~= COMMANDO) then		
		if (not toKill[currentFrame+1]) then toKill[currentFrame+1] = {} end
		toKill[currentFrame+1][unitID] = true
		if (not fromtrans[currentFrame+1]) then fromtrans[currentFrame+1] = {} end
		fromtrans[currentFrame+1][unitID] = transportID
	end
end

function gadget:GameFrame (f) 
	currentFrame = f
	if (toKill[f]) then --kill units as requested from above
		for i,u in pairs (toKill[currentFrame]) do
			t = fromtrans[currentFrame][i]
			--Spring.Echo ("delayed killing check called for unit " .. i .. " and trans " .. t .. ". ")
			--check that trans is dead/crashing and unit is still alive 
			if ((not Spring.GetUnitIsDead(i)) and (Spring.GetUnitIsDead(t) or (Spring.GetUnitMoveTypeData(t).aircraftState=="crashing")))	then	
				--Spring.Echo("killing unit " .. i)
				Spring.DestroyUnit (i, true, false) 
			end
		end
	toKill[currentFrame] = nil
	fromtrans[currentFrame] = nil
	end
end


	


