function gadget:GetInfo()
	return {
		name 	= "Registers Nanos positions",
		desc	= "Used for AI retreat scripts",
		author	= "Doo",
		date	= "Sept 19th 2017",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

local isNanoTC = {}
local NanoTC = {}
local ClosestNanoTC = {}

for unitDefID, defs in pairs(UnitDefs) do
	if string.find(defs.name, "nanotc") then
		isNanoTC[unitDefID] = true
	end
end

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
	local unitDefID = Spring.GetUnitDefID(unitID)
	local unitTeam = Spring.GetUnitTeam(unitID)
		gadget:UnitFinished(unitID, unitDefID, unitTeam)
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isNanoTC[unitDefID] then
		if not NanoTC[unitTeam] then NanoTC[unitTeam] = {} end
		NanoTC[unitTeam][unitID] = {Spring.GetUnitPosition(unitID)}
		UpdateClosestNanoTCTable(unitTeam)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		if not NanoTC[unitTeam] then NanoTC[unitTeam] = {} end
		NanoTC[unitTeam][unitID] = nil
		UpdateClosestNanoTCTable(unitTeam)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
		gadget:UnitDestroyed(unitID, unitDefID, oldTeam)
		gadget:UnitFinished(unitID, unitDefID, newTeam)	

end

local function Distance(x1,z1, x2,z2)
	local vectx = x2 - x1
	local vectz = z2 - z1
	local dis = math.sqrt(vectx^2+vectz^2)
	return dis
end

GG.GetClosestNanoTC = function (unitID)
	local bestx, besty, bestz
	local teamID = Spring.GetUnitTeam(unitID)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local bestID
	local mindis = math.huge
	local x, y, z = math.floor(ux/256), math.floor(uy/256), math.floor(uz/256)
	if ClosestNanoTC and ClosestNanoTC[teamID] and ClosestNanoTC[teamID][x] and ClosestNanoTC[teamID][x][z] and Spring.ValidUnitID(ClosestNanoTC[teamID][x][z]) then
		bestID = ClosestNanoTC[teamID][x][z]
	elseif NanoTC and NanoTC[teamID] then
		for uid, pos in pairs (NanoTC[teamID]) do
			local gx, gy, gz = pos[1], pos[2], pos[3]
			local dis = Distance(ux, uz, gx, gz)
			if dis< mindis then
				mindis = dis
				bestID = uid
				if not ClosestNanoTC then ClosestNanoTC = {} end
				if not ClosestNanoTC[teamID] then ClosestNanoTC[teamID] = {} end		
				if not ClosestNanoTC[teamID][x] then ClosestNanoTC[teamID][x] = {} end						
				ClosestNanoTC[teamID][x][z] = uid
			end
		end
	end
	bestx, besty, bestz = Spring.GetUnitPosition(bestID)
	return bestx, besty, bestz
end

function UpdateClosestNanoTCTable(teamID)
	if teamID then
		ClosestNanoTC[teamID] = nil
	end
end
end