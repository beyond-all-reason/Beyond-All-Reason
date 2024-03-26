function widget:GetInfo()
	return {
		name = "Loader testing - subfolder2",
		enabled = true,
		layer = 100,
		handler = true,
	}
end

function widget:GetChildPaths()
	return true
end

local setupTestingCallins = VFS.Include('luaui/widgets/loader_testing/loader_testing_callins.lua')
setupTestingCallins(widget, true, true)
