--in BA "commando" unit always survives being shot down during transport
--when a com dies in mid air the damage done is controlled by unit_combomb_full_damage 

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
--AddUnitDamage (ID, math.huge) makes a normal death explo but leaves wreck. Calling this for the transportee on the same frame as the trans dies results in a crash.


function gadget:GetInfo()
  return {
    name      = "transport_dies_load_dies",
    desc      = "kills units in transports when transports dies (except commandos)",
    author    = "knorke, bluestone",
    date      = "Dec 2012",
    license   = "horse has fallen over",
    layer     = 0,
    enabled   = true
  }
end

if (not gadgetHandler:IsSyncedCode()) then return end

local COMMANDO = UnitDefNames["cormando"].id

toKill = {} -- [frame][unitID]
fromtrans = {}

currentFrame = 0

--when a unit is unloaded, mark it either as a commando or for possible destruction on next frame
function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)

	--Spring.Echo ("unloaded " .. unitID .. " (" .. unitDefID .. "), from transport " .. transportID)
	
	if (unitDefID ~= COMMANDO) then	
		currentFrame = Spring.GetGameFrame()
		if (not toKill[currentFrame+1]) then toKill[currentFrame+1] = {} end
		toKill[currentFrame+1][unitID] = true
		if (not fromtrans[currentFrame+1]) then fromtrans[currentFrame+1] = {} end
		fromtrans[currentFrame+1][unitID] = transportID
		--Spring.Echo("added killing request for " .. unitID .. " on frame " .. currentFrame+1 .. " from transport " .. transportID )
	else
		--commandos are given a move order to the location of the ground below where the transport died; remove it
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, {})
	end
end

function gadget:GameFrame (currentFrame) 
	if (toKill[currentFrame]) then --kill units as requested from above
		for uID,_ in pairs (toKill[currentFrame]) do
			tID = fromtrans[currentFrame][uID]
			--Spring.Echo ("delayed killing check called for unit " .. uID .. " and trans " .. tID .. ". ")
			--check that trans is dead/crashing and unit is still alive 
			if ((not Spring.GetUnitIsDead(uID)) and (Spring.GetUnitIsDead(tID) or (Spring.GetUnitMoveTypeData(tID).aircraftState=="crashing")))	then	
				--Spring.Echo("killing unit " .. uID)
				if UnitDefs[Spring.GetUnitDefID(uID)].deathExplosion and WeaponDefNames[UnitDefs[Spring.GetUnitDefID(uID)].deathExplosion].id and WeaponDefs[WeaponDefNames[UnitDefs[Spring.GetUnitDefID(uID)].deathExplosion].id] then
				local tabledamages = WeaponDefs[WeaponDefNames[UnitDefs[Spring.GetUnitDefID(uID)].deathExplosion].id]
				Spring.SetUnitWeaponDamages(uID, "selfDestruct", tabledamages)
				local tabledamages = WeaponDefs[WeaponDefNames[UnitDefs[Spring.GetUnitDefID(uID)].deathExplosion].id].damages
				Spring.SetUnitWeaponDamages(uID, "selfDestruct", tabledamages)
				end
				Spring.DestroyUnit (uID, true, false)
			end
		end
	toKill[currentFrame] = nil
	fromtrans[currentFrame] = nil
	end
end


	


