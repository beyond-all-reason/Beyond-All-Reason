
function gadget:GetInfo()
	return {
		name = "Load/unload",
		desc = "Sets up a constant 10 or 15 elmos load/unload radius for air transports and allows unload as soon as distance is reached (104.0.1 - maintenace 686+)",
		author = "Doo",
		date = "2018",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local transporteeWeights = {}
local airTransportWeights = {}
local airTransportDistances = {}
for udefID,def in ipairs(UnitDefs) do
	if def.canFly and def.isTransport then
		if def.customParams.techlevel then
			airTransportDistances[udefID] = 30		-- 15 elmos
		else
			airTransportDistances[udefID] = 20		-- 10 elmos
		end
		airTransportWeights[udefID] = tonumber(def.customParams.transportable_weight_class) or 3 --medium weight class fallback
	end
	if def.customParams then
		transporteeWeights[udefID] = tonumber(def.customParams.unit_weight_class) or 3 --medium weight class fallback
	end
end

if (gadgetHandler:IsSyncedCode()) then

	local math_sqrt = math.sqrt

	function gadget:Distance(pos1, pos2)
		local difX = pos1[1] - pos2[1]
		local difY = pos1[2] - pos2[2]
		local difZ = pos1[3] - pos2[3]
		local sqDist = difX*difX + difY*difY + difZ*difZ
		local dist = math_sqrt(sqDist)
		return (dist)
	end

	function gadget:AllowUnitTransportLoad(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)
		if airTransportDistances[transporterUnitDefID] then
			--local terDefs = UnitDefs[transporterUnitDefID]
			--local teeDefs = UnitDefs[transporteeUnitDefID]
			if airTransportWeights[transporterUnitDefID] and transporteeWeights[transporteeUnitDefID] then
				if airTransportWeights[transporterUnitDefID] < transporteeWeights[transporteeUnitDefID] then
					Spring.Echo("TOO FAT!")
					return false
				end
			end
			local pos1 = {Spring.GetUnitPosition(transporterID)}
			local pos2 = {goalX, goalY, goalZ}
			if gadget:Distance(pos1, pos2) <= airTransportDistances[transporterUnitDefID] then
				if Spring.AreTeamsAllied(Spring.GetUnitTeam(transporterID), Spring.GetUnitTeam(transporteeID)) or select(4, Spring.GetUnitVelocity(transporteeID)) < 0.5 then	-- make it hard for moving enemy units to be picked up
					Spring.SetUnitVelocity(transporterID, 0,0,0)
					return true
				else
					return false
				end
			else
				return false
			end
		else
			return true
		end
	end

	function gadget:AllowUnitTransportUnload(transporterID, transporterUnitDefID, transporterTeam, transporteeID, transporteeUnitDefID, transporteeTeam, goalX, goalY, goalZ)
		if airTransportDistances[transporterUnitDefID] then
			--local terDefs = UnitDefs[transporterUnitDefID]
			--local teeDefs = UnitDefs[transporteeUnitDefID]
			local pos1 = {Spring.GetUnitPosition(transporterID)}
			local pos2 = {goalX, goalY, goalZ}
			if gadget:Distance(pos1, pos2) <= airTransportDistances[transporterUnitDefID] then
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
