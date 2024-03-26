function widget:GetInfo()
	return {
		name = "Loader testing - subfolder/a",
		enabled = true,
	}
end

function widget:GetChildPaths()
	return { "childA.lua" }
end
