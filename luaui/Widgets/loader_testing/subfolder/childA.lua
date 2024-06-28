function widget:GetInfo()
	return {
		name = "Loader testing - child A",
		enabled = true,
	}
end

function widget:GetChildPaths()
	return { "childB.lua" }
end
