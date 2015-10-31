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

local TRANSPORTED_MASS_SPEED_PENALTY = 1 -- higher makes unit slower
local FRAMES_PER_SECOND = 30

local airTransports = {}
local unloadedUnits = {}
	
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then
-- BEGIN SYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- add transports to table when created
function gadget:UnitLoaded(unitId, unitDefId, unitTeam, transportId, transportTeam)
	local ud = UnitDefs[Spring.GetUnitDefID(transportId)]
	if ud.canFly and not airTransports[transportId] then
		airTransports[transportId] = ud
	end
end
-- remove transports from table when destroyed
function gadget:UnitDestroyed(unitId, unitDefId, teamId, attackerId, attackerDefId, attackerTeamId)
	if airTransports[unitId] then
		airTransports[unitId] = nil
	end
	if unloadedUnits[unitId] then
		unloadedUnits[unitId] = nil
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
    
    -- for each air transport
	for unitId,ud in pairs(airTransports) do
		
		-- local currentCapacityUsage = 0 
		local currentMassUsage = 0

		-- get sum of mass and size for all transported units                                
        for _,tUnitId in pairs(Spring.GetUnitIsTransporting(unitId)) do
			local tUd = UnitDefs[Spring.GetUnitDefID(tUnitId)]
			-- currentCapacityUsage = currentCapacityUsage + tUd.xsize 
			currentMassUsage = currentMassUsage + tUd.mass
        end
		
		-- compute max allowed speed
		local vx,vy,vz,vw = Spring.GetUnitVelocity(unitId)
		local massUsageFraction = (currentMassUsage / ud.transportMass)
		local allowedSpeed = ud.speed * (1 - massUsageFraction * TRANSPORTED_MASS_SPEED_PENALTY) / FRAMES_PER_SECOND 

		--Spring.Echo("unit "..ud.name.." is air transport at  "..(massUsageFraction*100).."%".." load, curSpeed="..vw.." allowedSpeed="..allowedSpeed)

		-- reduce speed if currently greater than allowed
		if (vw > allowedSpeed) then
			local factor = allowedSpeed / vw
			Spring.SetUnitVelocity(unitId,vx * factor,vy * factor,vz * factor)
		end
	end
end


-- prevent unloaded units from sliding across the map
-- TODO remove when fixed in the engine
function gadget:UnitUnloaded(unitId, unitDefId, teamId, transportId)
	if not unloadedUnits[unitId] then
		local px,py,pz = Spring.GetUnitPosition(unitId,false,false)
		local dx,dy,dz = Spring.GetUnitDirection(unitId)
		local frame = Spring.GetGameFrame()
		unloadedUnits[unitId] = {["px"]=px,["py"]=py,["pz"]=pz,["dx"]=dx,["dy"]=dy,["dz"]=dz,["frame"]=frame}
	end
	if airTransports[transportId] and Spring.GetUnitIsTransporting(transportId)[1]) ~= nil then
		airTransports[transportId] = nil
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
