local Ground = {}

---@param deps { positionChecks: table }
---@return table
function Ground.New(deps)
	local checks = deps.positionChecks
	assert(type(checks) == "table", "placement ground needs positionChecks")

	local ground = {}

	--- Counts rather than the first reason: "312 too steep, 4 occupied" is a cliff; "0 too steep, 316 occupied" is a crowded base.
	---@return table
	function ground.NewTally()
		return { offMap = 0, steep = 0, occupied = 0, wrongSurface = 0, tried = 0 }
	end

	---@param x number
	---@param z number
	---@param want { footprint: number, surface: string|nil, flatness: number|nil, clearance: number|nil }
	---@param tally table|nil
	---@return boolean ok, number|nil y
	function ground.Usable(x, z, want, tally)
		if tally then
			tally.tried = tally.tried + 1
		end
		local footprint = want.footprint or 64
		local y = Spring.GetGroundHeight(x, z)

		if not checks.MapEdgeCheck(x, y, z, footprint) then
			if tally then
				tally.offMap = tally.offMap + 1
			end
			return false
		end

		-- "solid" is land or sea but not the shoreline between them: something
		-- spawning across that line has half its output in the water
		local surface = want.surface or "land"
		if surface ~= "any" then
			local found = checks.LandOrSeaCheck(x, y, z, footprint)
			local ok
			if surface == "solid" then
				ok = found == "land" or found == "sea"
			else
				ok = found == surface
			end
			if not ok then
				if tally then
					tally.wrongSurface = tally.wrongSurface + 1
				end
				return false
			end
		end

		-- flatness over the footprint, not a larger margin: asking for a parade
		-- ground is how a search fails on maps with somewhere perfectly good to stand
		local flatness = want.flatness
		if flatness ~= nil and not checks.FlatAreaCheck(x, y, z, footprint, flatness, true) then
			if tally then
				tally.steep = tally.steep + 1
			end
			return false
		end

		local clearance = want.clearance or footprint
		if clearance > 0 and not checks.OccupancyCheck(x, y, z, clearance) then
			if tally then
				tally.occupied = tally.occupied + 1
			end
			return false
		end

		return true, y
	end

	---@param tally table
	---@return string
	function ground.Explain(tally)
		if tally == nil or tally.tried == 0 then
			return "nowhere was tried"
		end
		return string.format(
			"%d tried: %d off the map, %d wrong surface, %d too steep, %d too close to something",
			tally.tried,
			tally.offMap,
			tally.wrongSurface,
			tally.steep,
			tally.occupied
		)
	end

	return ground
end

return Ground
