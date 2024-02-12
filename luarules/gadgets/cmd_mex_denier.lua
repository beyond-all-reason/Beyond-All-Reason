function gadget:GetInfo()
	return {
		name = "Deny Invalid Mex Orders",
		desc = "Denies mex build orders where there's no 100% yield",
		author = "badosu",
		version = "v1.0",
		date = "December 2023",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end


if not gadgetHandler:IsSyncedCode() then
	return
end

local isMex = {}
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.extractsMetal > 0 then
		isMex[uDefID] = true
	end
end

local metalSpotsList

function gadget:Initialize()
	local isMetalMap = GG["resource_spot_finder"].isMetalMap
	if isMetalMap then
		Spring.Echo(gadget:GetInfo().name, "Metal map detected, removing self")
		gadgetHandler:RemoveGadget(self)
	end
	metalSpotsList = GG["resource_spot_finder"].metalSpotsList
end

-- function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
function gadget:AllowCommand(_, _, _, cmdID, cmdParams)
	if not isMex[-cmdID] then
		return true
	end

	local bx, bz = cmdParams[1], cmdParams[3]
	-- We find the closest metal spot to the assigned command position
	local closestSpot = math.getClosestPosition(bx, bz, metalSpotsList)

	-- We check if current order is to build mex in closest spot
	if not (closestSpot and GG["resource_spot_finder"].IsMexPositionValid(closestSpot, bx, bz)) then
		return false
	end

	return true
end
