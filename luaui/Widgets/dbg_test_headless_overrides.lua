local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Headless environment overrides",
		desc = "Overrides for running on headless environment",
		license = "GNU GPL, v2 or later",
		layer = -9999999999,
		enabled = true,
	}
end

if not Spring.Utilities.IsDevMode() or not Spring.Utilities.Gametype.IsSinglePlayer() or Platform.gl then
	return
end

Spring.SetConfigInt("ui_rendertotexture", 0)

-- PushMatrix and PopMatrix still perform accounting and can generate errors on headless.
-- Problem here is CallList won't really call dlists, so when a PushMatrix or PopMatrix
-- is placed inside a display list, this can cause problems.
gl.PushMatrix = function() end
gl.PopMatrix = function() end

