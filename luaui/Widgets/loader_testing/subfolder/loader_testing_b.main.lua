function widget:GetInfo()
	return {
		name = "Loader testing - subfolder/b",
		enabled = true,
	}
end


function widget:GetChildPaths()
	return { "childD.lua" }
end
