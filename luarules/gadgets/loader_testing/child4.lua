function gadget:GetInfo()
	return {
		name = "Loader testing - child 4",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	return { "subfolder" }
end
