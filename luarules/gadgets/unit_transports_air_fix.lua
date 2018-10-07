function gadget:GetInfo()
   return {
      name = "Air Transports Fix",
      desc = "Prevents transports from moving in XZ plane when it's hitting ground and has to climb up",
      author = "Doo",
      date = "23/03/18",
      license = "",
      layer = 0,
      enabled = true,
   }
end

-- When units collide in spring, they are simply moved without any change to their velocity (ie moved -2,5,0 but keeps it's 1,0,1 velocity)
-- It causes units to keep their orientation and speed towards the obstacle.
-- For planes, they are pushed upwards and will gain altitude, but since they haven't been slowed, on the next frame they'll collide ground again and be pushed upwards again.
-- This gadget attempts to catch whenever an air transport's returned speed doesn't match it's displacement on the map (with a threshold) to apply an XZ plane full stop and allow it to climb before it starts moving again.

if (gadgetHandler:IsSyncedCode()) then
AirTransports = {[UnitDefNames["armatlas"].id]= true,[UnitDefNames["armdfly"].id] = true,[UnitDefNames["corvalk"].id] = true,[UnitDefNames["corseah"].id] = true}
Trans = {}
Positions = {}
	function gadget:UnitCreated(unitID) -- get all air transports
		local unitDefID = Spring.GetUnitDefID(unitID)
		if AirTransports[unitDefID] then
			Trans[unitID] = true
		end
	end
		
	function gadget:UnitDestroyed(unitID) -- clear on death
		Trans[unitID] = nil
		Positions[unitID] = nil
	end
	
	function gadget:GameFrame(f)
		for unitID, isTrans in pairs(Trans) do
			local px, py, pz = Spring.GetUnitPosition(unitID) -- cur position
			local vx, vy, vz = Spring.GetUnitVelocity(unitID) -- unit's own velocity
			if Positions[unitID] and Positions[unitID][1] and Positions[unitID][2] and Positions[unitID][3] then -- if stored last frame's position
				local tvx, tvy, tvz = px - Positions[unitID][1], py - Positions[unitID][2], pz - Positions[unitID][3] -- true instant velovity (pos - last post / 1 frame)
				if (tvx^2 + tvy^2 + tvz^2) > ((vx^2 + vy^2 +vz^2) + 20) then -- if true vel > unit's vel + threshold then
					Spring.SetUnitVelocity(unitID, 0,vy,0) -- Immobilize in XZ plane, let it climb up
				end
			end
			Positions[unitID] = {px, py, pz}	-- Store curFrame position (will be used as last frame's position in next gameframe)
		end
	end
	
end
