function gadget:GetInfo()
	return {
		name = "Loader testing - child C",
		enabled = true,
	}
end

function gadget:GetChildPaths()
	-- should error
	--return { "childC.lua" }
end
