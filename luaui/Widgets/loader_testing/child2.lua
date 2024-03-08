function widget:GetInfo()
	return {
		name = "Loader testing - child 2",
		enabled = true,
	}
end

function widget:GetChildPaths()
	return { "child3.lua" }
end
