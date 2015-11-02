function gadget:GetInfo()
   return {
      name = "Air Transports Handler",
      desc = "Slows down transport depending on loaded mass (up to 50%) and fixes unloaded units sliding bug",
      author = "raaar",
      date = "2015",
      license = "PD",
      layer = 0,
      enabled = true,
   }
end

local TRANSPORTED_MASS_SPEED_PENALTY = 0.2 -- higher makes unit slower
local FRAMES_PER_SECOND = Game.gameSpeed

local airTransports = {}
local airTransportMaxSpeeds = {}
local unloadedUnits = {}
	
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-- BEGIN SYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local massUsageFraction = 0
local allowedSpeed = 0
local currentMassUsage = 0
-- update allowed speed for transport
function updateAllowedSpeed(transportId, transportUnitDef)
	
	-- get sum of mass and size for all transported units                                
	currentMassUsage = 0
	for _,tUnitId in pairs(Spring.GetUnitIsTransporting(transportId)) do
		local tUd = UnitDefs[Spring.GetUnitDefID(tUnitId)]
		-- currentCapacityUsage = currentCapacityUsage + tUd.xsize 
		currentMassUsage = currentMassUsage + tUd.mass
	end
	massUsageFraction = (currentMassUsage / transportUnitDef.transportMass)
	allowedSpeed = transportUnitDef.speed * (1 - massUsageFraction * TRANSPORTED_MASS_SPEED_PENALTY) / FRAMES_PER_SECOND 
	--Spring.Echo("unit "..transportUnitDef.name.." is air transport at  "..(massUsageFraction*100).."%".." load, curSpeed="..vw.." allowedSpeed="..allowedSpeed)

	airTransportMaxSpeeds[transportId] = allowedSpeed
end


-- add transports to table when they load a unit
function gadget:UnitLoaded(unitId, unitDefId, unitTeam, transportId, transportTeam)
	local ud = UnitDefs[Spring.GetUnitDefID(transportId)]
	if ud.canFly and not airTransports[transportId] then
		airTransports[transportId] = ud

		-- update allowed speed
		updateAllowedSpeed(transportId, ud)
	end
end

-- cleanup transports and unloaded unit tables when destroyed
function gadget:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
	if airTransports[unitId] then
		airTransports[unitId] = nil
	end
	if unloadedUnits[unitId] then
		unloadedUnits[unitId] = nil
	end
	if airTransportMaxSpeeds[unitId] then
		airTransportMaxSpeeds[unitId] = nil
	end
end

-- every frame, adjust speed of air transports according to transported mass, if any
function gadget:GameFrame(n)
    
	-- prevent unloaded units from sliding across the map
	-- TODO remove when fixed in the engine
	for unitId,data in pairs(unloadedUnits) do
    	if (n > data.frame + 10 ) then
			-- reset position
			Spring.SetUnitPhysics(unitId,data.px,data.py,data.pz,0,0,0,0,0,0,0,0,0)
			Spring.SetUnitDirection(unitId,data.dx,data.dy,data.dz)
			Spring.GiveOrderToUnit(unitId,CMD.MOVE,{data.px+10*data.dx,data.py,data.pz+10*data.dz},CMD.OPT_SHIFT)

			-- remove from table
			unloadedUnits[unitId] = nil
		end
	end
    
	-- for each air transport with units loaded, reduce speed if currently greater than allowed
	local factor = 1
	local vx,vy,vz,vw = 0
	local alSpeed = 0
	for unitId,ud in pairs(airTransports) do
		vx,vy,vz,vw = Spring.GetUnitVelocity(unitId)
		alSpeed = airTransportMaxSpeeds[unitId]
		if (alSpeed and vw > alSpeed) then
			factor = alSpeed / vw
			Spring.SetUnitVelocity(unitId,vx * factor,vy * factor,vz * factor)
		end
	end
end


function gadget:UnitUnloaded(unitId, unitDefId, teamId, transportId)

	-- prevent unloaded units from sliding across the map
	-- TODO remove when fixed in the engine
	if not unloadedUnits[unitId] then
		local px,py,pz = Spring.GetUnitPosition(unitId,false,false)
		local dx,dy,dz = Spring.GetUnitDirection(unitId)
		local frame = Spring.GetGameFrame()
		unloadedUnits[unitId] = {["px"]=px,["py"]=py,["pz"]=pz,["dx"]=dx,["dy"]=dy,["dz"]=dz,["frame"]=frame}
	end

	if airTransports[transportId] and not Spring.GetUnitIsTransporting(transportId)[1] then
		-- transport is empty, cleanup tables
		airTransports[transportId] = nil
		airTransportMaxSpeeds[transportId] = nil
	else
		-- update allowed speed
		updateAllowedSpeed(transportId, airTransports[transportId])
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
else

	
-- END SYNCED
-- BEGIN UNSYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- nothing to do here
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
end
-- END UNSYNCED
--------------------------------------------------------------------------------
