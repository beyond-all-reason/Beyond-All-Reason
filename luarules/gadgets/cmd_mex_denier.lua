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

local function GetClosestSpot(x, z, positions)
	local bestPos
	local bestDist = math.huge
	for i = 1, #positions do
		local pos = positions[i]
		if pos.x then
			local dx, dz = x - pos.x, z - pos.z
			local dist = dx * dx + dz * dz
			if dist < bestDist then
				bestPos = pos
				bestDist = dist
			end
		end
	end
	return bestPos
end

local metalSpotsList

function gadget:Initialize()
	metalSpotsList = GG["resource_spot_finder"] and GG["resource_spot_finder"].metalSpotsList

	-- no metal spots in map or metalmap
	-- gadget is not required
	if not metalSpotsList or #metalSpotsList <= 2 then
		Spring.Echo("<gadgets/cmd_mex_denier.lua> No, 1 or 2 metal spots found, removing self")

		gadgetHandler:RemoveGadget(self)
	end
end

-- function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
function gadget:AllowCommand(_, _, _, cmdID, cmdParams)
	if not isMex[-cmdID] then
		return true
	end

	local bx, bz = cmdParams[1], cmdParams[3]
	-- We find the closest metal spot to the assigned command position
	local closestSpot = GetClosestSpot(bx, bz, metalSpotsList)

	-- We check if current order is to build mex in closest spot
	if not (closestSpot and GG["resource_spot_finder"].IsMexPositionValid(closestSpot, bx, bz)) then
		return false
	end

	return true
end
