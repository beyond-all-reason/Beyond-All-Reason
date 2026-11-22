-- Exact heightmap vertex heights, edges included.
--
-- Spring.GetGroundHeight clamps x and z to mapSize - 1 (rts/Map/Ground.cpp), so on the far
-- column (x = mapSizeX) and row (z = mapSizeZ) it returns a blend 7/8 of the way from the inner
-- vertex to the edge vertex, not the edge vertex. Code that walks every vertex and writes the
-- heights back (project save, heightmap export, whole-map undo) then drags the far edges toward
-- their neighbours on every pass. The engine's own triangle interpolation is linear there, so the
-- edge vertex comes back exactly from the blend and the exact inner neighbour.
--
--   local vertexHeight = VFS.Include("common/vertex_height.lua")(Spring.GetGroundHeight)
--   local h = vertexHeight(x, z) -- x, z multiples of Game.squareSize, 0..mapSize

return function(getHeight)
	local sq = Game.squareSize
	local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
	local f = (sq - 1) / sq -- where the clamped lookup lands inside the last square
	local g = 1 - f

	local function vertexHeight(x, z)
		local edgeX, edgeZ = x >= mapX, z >= mapZ
		if not (edgeX or edgeZ) then
			return getHeight(x, z)
		end
		if not edgeZ then
			local inner = getHeight(x - sq, z)
			return inner + (getHeight(x - 1, z) - inner) / f
		elseif not edgeX then
			local inner = getHeight(x, z - sq)
			return inner + (getHeight(x, z - 1) - inner) / f
		end
		-- the far corner: the lookup lands in the bottom-right triangle, which weighs the
		-- corner by 1 - 2g and its two edge neighbours by g each
		local left, up = vertexHeight(x - sq, z), vertexHeight(x, z - sq)
		return (getHeight(x - 1, z - 1) - g * (left + up)) / (1 - 2 * g)
	end

	return vertexHeight
end
