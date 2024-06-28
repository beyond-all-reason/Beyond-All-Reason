function widget:GetInfo()
	return {
		name = "Loader testing - child B2",
		enabled = true,
		layer = -500,
	}
end

local setupTestingCallins = VFS.Include('luaui/widgets/loader_testing/loader_testing_callins.lua')
setupTestingCallins(widget, false, true)
