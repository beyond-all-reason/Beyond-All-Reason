function gadget:GetInfo()
	return {
		name = "Loader testing - child 1",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	return { "child2.lua" }
end
