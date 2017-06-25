function gadget:GetInfo()
	return {
		name = "SeaPlatforms",
		desc = "Handles Sea Platforms behaviours",
		author = "[Fx]Doo",
		date = "25th of October 2032",
		license = "Free",
		layer = 0,
		enabled = true
	}
end


if (gadgetHandler:IsSyncedCode()) then
GroundHeight = {}
function gadget:UnitFinished(unitID)
unitDefID = Spring.GetUnitDefID(unitID)
unitName = UnitDefs[unitDefID].name
x,y,z = Spring.GetUnitPosition(unitID)
if unitName == "armcube" then
-- Spring.Echo("go")
--Spring.SetUnitNoDraw(unitID, true)
Spring.SetUnitBlocking(unitID,false)
Spring.SetUnitNoSelect(unitID, true)
Spring.SetUnitNoMinimap(unitID, true)
Spring.SetUnitAlwaysVisible(unitID, true)
GroundHeight[unitID] = Spring.GetGroundHeight(x,z)
Spring.CallCOBScript(unitID, "HidePieces", 0, -GroundHeight[unitID])
Spring.SetUnitMidAndAimPos(unitID, x, GroundHeight[unitID]/2, z, x, 4, z, false)
Spring.SetUnitRadiusAndHeight(unitID, 24, -GroundHeight[unitID])
Spring.SetUnitCollisionVolumeData(unitID, 96, -GroundHeight[unitID], 96, 0,0,0,2,1,0)
Spring.LevelHeightMap(x-31,z-31,x+32,z+32, 1)
--CHECK NORTHERN GroundHeight
local i = -200
	for l = -31,32 do

	for k = 31,79 do

		i = Spring.GetGroundHeight(x+l, z - k)
			if i > 1 and i < 3 then
				Spring.LevelHeightMap(x-31, z, x+32, z-k,1)
										-- Spring.Echo(i)
				end
		end	
	end
	
	
-- Check southern
local i = -200
	for l = -31,32 do
	for k = -80,-32 do
		i = Spring.GetGroundHeight(x+l, z - k)

			if i > 1 and i < 3 then
			-- Spring.Echo(x+l)
			-- Spring.Echo(z-k)
				Spring.LevelHeightMap(x-31, z, x+32, z-k,1)
				end
		end
	end
-- Check eastern
local i = -200
	for l = -32,31 do
	for k = -80,-32 do
		i = Spring.GetGroundHeight(x-k, z + l)
			if i > 1 and i < 3 then
				Spring.LevelHeightMap(x, z-31, x-k, z+32,1)
				end
		end
	end
-- Check western
local i = -200
	for l = -32,31 do
	for k = 31,79 do
		i = Spring.GetGroundHeight(x-k, z + l)
			if i >1  and i < 3 then
				Spring.LevelHeightMap(x, z-31, x-k, z+32,1)
				end
		end
	end



end
end

function gadget:UnitDestroyed(unitID)
unitDefID = Spring.GetUnitDefID(unitID)
unitName = UnitDefs[unitDefID].name
x,y,z = Spring.GetUnitPosition(unitID)
if unitName == "armcube" then
if (GroundHeight[unitID]) then
Spring.LevelHeightMap(x-31,z-31,x+32,z+32, GroundHeight[unitID])
end
end
end

end