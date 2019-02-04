
function gadget:GetInfo()
   return {
	  name = "Load/unload",
	  desc = "Sets up a constant 8 elmos load/unload radius for air transports and allows unload as soon as distance is reached (104.0.1 - maintenace 686+)",
	  author = "Doo",
	  date = "2018",
	  license = "PD",
	  layer = 0,
	  enabled = true,
   }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local AirTransports = {
	[UnitDefNames["armatlas"].id] = true,
	[UnitDefNames["armdfly"].id] = true,
	[UnitDefNames["corvalk"].id] = true,
	[UnitDefNames["corseah"].id] = true,
}


if (gadgetHandler:IsSyncedCode()) then
	function gadget:Distance(pos1, pos2)
		local difX = pos1[1] - pos2[1]
		local difY = pos1[2] - pos2[2]
		local difZ = pos1[3] - pos2[3]
		local sqDist = difX^2 + difY^2 + difZ^2
		local dist = math.sqrt(sqDist)
		return (dist)
	end

	function gadget:AllowUnitTransportLoad(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)
		if AirTransports[transporterUnitDefID] then
			--local terDefs = UnitDefs[transporterUnitDefID]
			--local teeDefs = UnitDefs[transporteeUnitDefID]
			local pos1 = {Spring.GetUnitPosition(transporterID)}
			local pos2 = {goalX, goalY, goalZ}
			if gadget:Distance(pos1, pos2) <= 16 then
				Spring.SetUnitVelocity(transporterID, 0,0,0)
				return true
			else
				return false
			end			
		else
			return true
		end
	end
	
	function gadget:AllowUnitTransportUnload(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)
		if AirTransports[transporterUnitDefID] then
			--local terDefs = UnitDefs[transporterUnitDefID]
			--local teeDefs = UnitDefs[transporteeUnitDefID]
			local pos1 = {Spring.GetUnitPosition(transporterID)}
			local pos2 = {goalX, goalY, goalZ}
			if gadget:Distance(pos1, pos2) <= 16 then
				Spring.SetUnitVelocity(transporterID, 0,0,0)
				return true
			else
				return false
			end
		else
			return true
		end
	end
end