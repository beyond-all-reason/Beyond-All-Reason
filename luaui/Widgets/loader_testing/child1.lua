function widget:GetInfo()
	return {
		name = "Loader testing - child 1",
		enabled = true,
	}
end

function widget:GetChildPaths()
	return { "child2.lua" }
end
