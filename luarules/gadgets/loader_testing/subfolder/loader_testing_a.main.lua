function gadget:GetInfo()
	return {
		name = "Loader testing - subfolder/a",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	return { "childA.lua" }
end
