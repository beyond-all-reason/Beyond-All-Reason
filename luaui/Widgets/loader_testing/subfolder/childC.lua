function widget:GetInfo()
	return {
		name = "Loader testing - child C",
		enabled = true,
	}
end

function widget:GetChildPaths()
	-- should error
	--return { "childC.lua" }
end
