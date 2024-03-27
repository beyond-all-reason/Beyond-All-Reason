function gadget:GetInfo()
	return {
		name		= "On Create Fix",
		desc		= "Fixes some Models when the unit is created",
		author		= "",
		date		= "1st Of April",
		license		= "GNU GPL, v2 or later",
		layer		= 0,
		enabled		= true
	}
end

if false then
	return
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local needsFixing,s = {},1
for k, v in pairs({
	corak=7,
	armpw=7,
	cordemon=3,
	correap=6,
	corack=4,
	corstorm=6,
}) do
	local tmp = UnitDefNames[k].id
	if tmp then
		needsFixing[tmp] = v
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	local amountToFix
	amountToFix,s = needsFixing[unitDefID],(s+7)%11
	if amountToFix then
		local pieceID = Spring.GetUnitPieceMap(unitID)
		for i = 1, amountToFix do if i~=s then
				Spring.SetUnitPieceVisible(unitID, pieceID["h"..i], false)
			end
		end
	end
end