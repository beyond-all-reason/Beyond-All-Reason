function widget:GetInfo()
	return {
		name = "Loader testing",
		enabled = true,
	}
end

function widget:GetChildPaths()
	return { "child1.lua" }
end
