--several other ways do not work because:
--when UnitDestroyed() is called, Spring.GetUnitIsTransporting is already empty -> meh
--checking newDamage>health in UnitDamaged() does not work because UnitDamaged() does not trigger on selfdestruct -> meh
--with releaseHeld, on death of a transport UnitUnload is called before UnitDestroyed
--when UnitUnloaded is called due to transport death, Spring.GetUnitIsDead (transportID) is still false
--when trans is self d'ed, on the frame it dies it has both Spring.GetUnitHealth(ID)>0 and Spring.UnitSelfDTime(ID)=0
--when trans is crashing it isn't dead

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

--in BA "commando" unit survives being shot down during transport, but nothing else
--a commando falling out of a trans will recieve a move order to the point at which the trans died, that order should be cancelled
local COMMANDO = UnitDefNames["commando"].id

toKill = {} -- [frame][unitID]
fromtrans = {}
clearorders = {}

currentFrame = 0
function gadget:GameFrame (f)
	currentFrame = f
	if (toKill[f]) then
		for i,u in pairs (toKill[currentFrame]) do
			t = fromtrans[currentFrame][i]
			--Spring.Echo ("delayed killing check called for unit " .. i .. " and trans " .. t .. ". ")
			
			--check that trans is dead (or crashing) and unit is still alive 
			if ((not Spring.GetUnitIsDead(i)) and (Spring.GetUnitIsDead(t) or (Spring.GetUnitMoveTypeData(t).aircraftState=="crashing")))	then	
				--Spring.AddUnitDamage (i, math.huge) -- would make a normal death explo but would leave wreck
				--Spring.Echo("killing unit " .. i)
				Spring.DestroyUnit (i, true, false)
			end
		end
	toKill[currentFrame] = nil
	fromtrans[currentFrame] = nil
	end

	if (clearorders[f])	then
		for i,u in pairs (clearorders[currentFrame]) do
			--check that unit is still alive 
			if (not Spring.GetUnitIsDead(i))	then	
				--Spring.Echo("giving stop order to  unit ".. i)
				Spring.GiveOrderToUnit(i, CMD.STOP, {}, {})
			end
		end
	clearorders[currentFrame] = nil
	end
end


function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)

	--Spring.Echo ("unloaded " .. unitID .. " from transport " .. transportID)
	
	--BA has no transport that "normally" releaseHeld=true, so this is commented out
	--local transDefID =Spring.GetUnitDefID(transportID)
	--local transDef = UnitDefs [transDefID]
	--if (not transDef) then Spring.Echo ("transDef = nil!!!!!!!!!!!!!!!!!!!!!!!!") end		
	--if (not (transDef.customParams and transDef.customParams.releaseheld)) then *** 
	
	if (unitDefID ~= COMMANDO) then
		--Spring.AddUnitDamage (unitID, math.huge)	--simply doing this here will result in a crash

		if (not toKill[currentFrame+1]) then toKill[currentFrame+1] = {} end
		toKill[currentFrame+1][unitID] = true
		if (not fromtrans[currentFrame+1]) then fromtrans[currentFrame+1] = {} end
		fromtrans[currentFrame+1][unitID] = transportID

	else
		if (not clearorders[currentFrame+2]) then clearorders[currentFrame+2] = {} end 
		clearorders[currentFrame+2][unitID] = true
	end


end


