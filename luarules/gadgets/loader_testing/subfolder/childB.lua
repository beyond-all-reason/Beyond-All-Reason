function gadget:GetInfo()
	return {
		name = "Loader testing - child B",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	return { "childC.lua" }
end
