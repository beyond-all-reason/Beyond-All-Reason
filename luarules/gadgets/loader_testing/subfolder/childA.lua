function gadget:GetInfo()
	return {
		name = "Loader testing - child A",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	return { "childB.lua" }
end
