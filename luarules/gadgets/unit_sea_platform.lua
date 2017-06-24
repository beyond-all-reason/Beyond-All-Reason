function gadget:GetInfo()
	return {
		name = "SeaPlatforms",
		desc = "Handles Sea Platforms behaviours",
		author = "[Fx]Doo",
		date = "25th of October 2016",
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
--Spring.SetUnitNoDraw(unitID, true)
Spring.SetUnitBlocking(unitID,false)
Spring.SetUnitNoSelect(unitID, true)
Spring.SetUnitNoMinimap(unitID, true)
Spring.SetUnitAlwaysVisible(unitID, true)
GroundHeight[unitID] = Spring.GetGroundHeight(x,z)
Spring.CallCOBScript(unitID, "HidePieces", 0, -GroundHeight[unitID])
Spring.SetUnitMidAndAimPos(unitID, x, GroundHeight[unitID]/2, z, x, 4, z, false)
Spring.SetUnitRadiusAndHeight(unitID, 24, -GroundHeight[unitID])
Spring.SetUnitCollisionVolumeData(unitID, 48, -GroundHeight[unitID], 48, 0,0,0,2,1,0)
Spring.LevelHeightMap(x-15,z-15,x+16,z+16, 1)
--CHECK NORTHERN GroundHeight
local i = -200
	for l = -15,16 do
	for k = 15,47 do
		i = Spring.GetGroundHeight(x+l, z - k)
			if i >= 2 and i <= 5 then
				Spring.LevelHeightMap(x+l, z, x+l, z-k,1)
				end
		end
	end
	
-- Check southern
local i = -200
	for l = -15,16 do
	for k = -15,-47 do
		i = Spring.GetGroundHeight(x+l, z - k)
			if i >= 2 and i <= 5 then
				Spring.LevelHeightMap(x+l, z, x+l, z-k,1)
				end
		end
	end
-- Check eastern
local i = -200
	for l = -15,16 do
	for k = -15,-47 do
		i = Spring.GetGroundHeight(x-k, z + l)
			if i >= 2 and i <= 5 then
				Spring.LevelHeightMap(x-k, z+l, x-k, z+l,1)
				end
		end
	end
-- Check western
local i = -200
	for l = -15,16 do
	for k = 15,47 do
		i = Spring.GetGroundHeight(x-k, z + l)
			if i >= 2 and i <= 5 then
				Spring.LevelHeightMap(x-k, z+l, x-k, z+l,1)
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
Spring.LevelHeightMap(x-15,z-15,x+16,z+16, GroundHeight[unitID])
end
end
end

end