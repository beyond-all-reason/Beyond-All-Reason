function gadget:GetInfo()
	return {
		name = "Loader testing - child 3",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	-- first path should do nothing
	return { "loader_testing.main.lua", "child4.lua" }
end
