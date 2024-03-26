function gadget:GetInfo()
	return {
		name = "Loader testing - subfolder/b",
		enabled = true,
	}
end


function gadget:GetChildPaths()
	return { "childD.lua" }
end
