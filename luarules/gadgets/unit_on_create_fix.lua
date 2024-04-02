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

if Spring.GetModOptions().april1 ~= true then
	return false
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local needsFixing,s = {},1
for k, v in pairs({
	corak=7,
	corstorm=7,
	corck=6,
	corack=6,
	correap=6,
	corllt=8,
	corhllt=8,
	cordemon=4,
	armpw=7,
	armcv=5,
	armrock=6,
	armbull=6,
	armllt=6,
	corwin=7,
	armwin=6,
	armham=5,
	corthud=6,
}) do
	local tmp = UnitDefNames[k]
	if tmp and tmp.id then
		needsFixing[tmp.id] = v
	end
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
	local amountToFix
	amountToFix,s = needsFixing[unitDefID],(s+7)%11
	if amountToFix then
		local pieceID = Spring.GetUnitPieceMap(unitID)
		for i = 1, amountToFix do if i~=s then
				Spring.SetUnitPieceVisible(unitID, pieceID["h"..i], false)
		else Spring.SetUnitPieceMatrix(unitID, pieceID["h"..i], { 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1})
			end
		end
	end
end
