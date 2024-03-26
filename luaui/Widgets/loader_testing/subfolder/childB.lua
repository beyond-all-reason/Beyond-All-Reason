function widget:GetInfo()
	return {
		name = "Loader testing - child B",
		enabled = true,
	}
end

function widget:GetChildPaths()
	return { "childC.lua" }
end
