function widget:GetInfo()
	return {
		name = "Loader testing - child 4",
		enabled = true,
	}
end

function widget:GetChildPaths()
	return { "subfolder" }
end
