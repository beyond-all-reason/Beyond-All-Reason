-- Basic mexes.
local spots = {
	{x = 12, z = 55, metal = 2},
	{x = 34, z = 55, metal = 2},
	{x = 67, z = 55, metal = 2},
	{x = 89, z = 55, metal = 2},
}

-- Extra mexes added for 5v5+ games
local extraSpots = {
	{x = 23, z = 55, metal = 2},
	{x = 78, z = 55, metal = 2},
}

if #Spring.GetTeamList() > 10 then
	for i = 1, #extraSpots do
		table.insert (spots, extraSpots[i])
	end
end

-- Mirror the mexes symmetrically on the other half of the map
for i = 1, #spots do
	local spot = spots[i]
	local mirroredSpot = {
		x = Game.mapSizeX - spot.x,
		z = spot.z,
		metal = spot.metal,
	}
	spots[#spots + 1] = mirroredSpot
end

-- If a mapoption is set, add a supermex in the middle with dynamic income based on player count
if Spring.GetMapOptions().supermex then
	spots[#spots + 1] = {
		x = Game.mapSizeX / 2,
		z = Game.mapSizeZ / 2,
		metal = 3 + #Spring.GetTeamList(),
	}
end

return {
	spots = spots,
}
