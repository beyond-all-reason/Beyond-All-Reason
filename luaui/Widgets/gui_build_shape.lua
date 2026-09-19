function widget:GetInfo()
	return {
		name = "Build Shape",
		desc = "Selects the build-drag shape via the GetBuildShape callin",
		author = "uBdead",
		date = "June 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

function widget:GetBuildShape(unitDefID, facing, startX, startY, startZ, endX, endY, endZ)
	-- Note the lack of shift used. We want to be able to keep shift free so queueing is OPTIONAL!
	local alt, ctrl, meta, shift = Spring.GetModKeyState()

	if alt and ctrl then
		return "cardinalline"
	end

	if ctrl then
		-- Create a hollow box shape, or surrounds a structure if pointed at one.
		return "hollowbox"
	end

	if alt then
		return "flood"
	end

	return "freeangleline"
end
