--- Spring lives here. Nothing above spring/ may include this file.
--- Wraps damgam_lib/position_checks rather than reimplementing it, and records WHICH test refused: a caller that cannot place something needs to say why.

local Ground = {}

---@param deps { positionChecks: table }
---@return table
function Ground.New(deps)
	local checks = deps.positionChecks
	assert(type(checks) == "table", "placement ground needs positionChecks")

	local ground = {}

	--- Counting rather than returning the first reason: over a whole search the counts say what is
	--- wrong with the AREA. "312 too steep, 4 occupied" is a cliff; "0 too steep, 316 occupied" is a crowded base.
	---@return table
	function ground.NewTally()
		return { offMap = 0, steep = 0, occupied = 0, wrongSurface = 0, tried = 0 }
	end

	--- `want.surface` is "land", "sea" or "any". Mixed ground — half shore,
	--- half water — is refused for land and sea alike: a unit placed across
	--- that line is half in the sea whichever way you meant it.
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

		-- "land" / "sea" ask for one of them. "solid" asks for either, but not
		-- the shoreline between them: something spawning across that line has
		-- half its output in the water whichever side you meant. "any" asks
		-- nothing, for a caller that knows better than this module does.
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

		-- Flatness is measured over the footprint, not over some larger comfort
		-- margin. Asking for a parade ground is how a search fails on maps that
		-- had somewhere perfectly good to stand.
		local flatness = want.flatness
		if flatness ~= nil and not checks.FlatAreaCheck(x, y, z, footprint, flatness, true) then
			if tally then
				tally.steep = tally.steep + 1
			end
			return false
		end

		-- Clearance defaults to the footprint: enough not to overlap, and no
		-- more. A caller that wants elbow room asks for it.
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
