function gadget:GetInfo()
	return {
		name = "SeaPlatforms",
		desc = "Handles Sea Platforms behaviours",
		author = "[Fx]Doo",
		date = "25 of June 2017",
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
if unitName == "seaplatform" then
-- Spring.Echo("go")
--Spring.SetUnitNoDraw(unitID, true)

Spring.SetUnitNoSelect(unitID, true)
Spring.SetUnitNoMinimap(unitID, true)
Spring.SetUnitAlwaysVisible(unitID, true)
GroundHeight[unitID] = Spring.GetGroundHeight(x,z)
Spring.CallCOBScript(unitID, "HidePieces", 0, -GroundHeight[unitID])
Spring.SetUnitMidAndAimPos(unitID, x, GroundHeight[unitID]/2, z+0, x, 4, z, false)
Spring.SetUnitRadiusAndHeight(unitID, 48, -GroundHeight[unitID])
Spring.SetUnitCollisionVolumeData(unitID, 96, -GroundHeight[unitID], 96, 0,0,0,2,1,0)
Spring.LevelHeightMap(x-31,z-31,x+32,z+32, 1)
Spring.SetUnitBlocking(unitID,false, false, true, false, false, true, true)
Spring.SetUnitCosts(unitID, {buildTime = 10000})
--CHECK NORTHERN GroundHeight
local i = -200
	for l = -31,32 do

	for k = 31,95 do

		i = Spring.GetGroundHeight(x+l, z - k)
			if i > 1 and i < 3 then
				Spring.LevelHeightMap(x-31, z, x+32, z-k,1)
										-- Spring.Echo(i)
				end
		end	
	end

--CHECK NORTHWEST GroundHeight
local i = -200
	for l = -79,-31 do

	for k = 31,95 do

		i = Spring.GetGroundHeight(x+l, z - k)
			if i > 1 and i < 3 then
				Spring.LevelHeightMap(x-79, z-31, x-31, z-k,1)
										-- Spring.Echo(i)
				end
		end	
	end

--CHECK NORTHEAST GroundHeight
local i = -200
	for l = 32,80 do

	for k = 31,95 do

		i = Spring.GetGroundHeight(x+l, z - k)
			if i > 1 and i < 3 then
				Spring.LevelHeightMap(x+32, z-31, x+80, z-k,1)
										-- Spring.Echo(i)
				end
		end	
	end
	
	
-- Check southern
local i = -200
	for l = -31,32 do
	for k = -96,-32 do
		i = Spring.GetGroundHeight(x+l, z - k)

			if i > 1 and i < 3 then
			-- Spring.Echo(x+l)
			-- Spring.Echo(z-k)
				Spring.LevelHeightMap(x-31, z, x+32, z-k,1)
				end
		end
	end
	
-- Check southwest
local i = -200
	for l = -79,-31 do
	for k = -96,-32 do
		i = Spring.GetGroundHeight(x+l, z - k)

			if i > 1 and i < 3 then
			-- Spring.Echo(x+l)
			-- Spring.Echo(z-k)
				Spring.LevelHeightMap(x-79, z+32, x-31, z-k,1)
				end
		end
	end
-- Check southeast	
local i = -200
	for l = 32,80 do
	for k = -96,-32 do
		i = Spring.GetGroundHeight(x+l, z - k)

			if i > 1 and i < 3 then
			-- Spring.Echo(x+l)
			-- Spring.Echo(z-k)
				Spring.LevelHeightMap(x+32, z+32, x+80, z-k,1)
				end
		end
	end
	
-- Check eastern
local i = -200
	for l = -32,31 do
	for k = -96,-32 do
		i = Spring.GetGroundHeight(x-k, z + l)
			if i > 1 and i < 3 then
				Spring.LevelHeightMap(x, z-31, x-k, z+32,1)
				end
		end
	end
-- Check western
local i = -200
	for l = -32,31 do
	for k = 31,95 do
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
if unitName == "seaplatform" then
if (GroundHeight[unitID]) then
Spring.LevelHeightMap(x-31,z-31,x+32,z+32, GroundHeight[unitID])
end
end
end

end