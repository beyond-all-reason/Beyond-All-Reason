function gadget:GetInfo()
	return {
		name = "Loader testing",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	return { "child1.lua" }
end
