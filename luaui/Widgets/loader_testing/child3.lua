function widget:GetInfo()
	return {
		name = "Loader testing - child 3",
		enabled = true,
	}
end

function widget:GetChildPaths()
	-- first path should do nothing
	return { "loader_testing.main.lua", "child4.lua" }
end
