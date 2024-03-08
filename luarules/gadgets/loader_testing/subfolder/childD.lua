function gadget:GetInfo()
	return {
		name = "Loader testing - child D with a really really really long name",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	return { "subfolder2" }
end
