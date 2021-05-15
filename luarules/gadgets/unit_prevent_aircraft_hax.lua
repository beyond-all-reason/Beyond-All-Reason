--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name = "Prevent outside-of-map hax",
		desc = "Prevent outside-of-map hax",
		author = "Beherith",
		date = "3 27 2011",
		license = "CC BY SA",
		layer = 0,
		enabled = true  --  loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitPosition = Spring.GetUnitPosition
local spGetAllUnits = Spring.GetAllUnits

local mapX = Game.mapSizeX
local mapZ = Game.mapSizeZ

function gadget:GameFrame(f)
	if f % 61 == 0 then
		local all_units = spGetAllUnits()
		for _, unitID in pairs(all_units) do
			local x, y, z = spGetUnitPosition(unitID)
			if not (z == nil or x == nil) then
				if z < -10000 or x < -10000 or z > mapZ + 10000 or x > mapX + 10000 then
					Spring.DestroyUnit(unitID, false, true)
				end
			end
		end
	end
end
