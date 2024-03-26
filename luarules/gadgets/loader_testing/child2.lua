function gadget:GetInfo()
	return {
		name = "Loader testing - child 2",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	return { "child3.lua" }
end
