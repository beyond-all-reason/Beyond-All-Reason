function widget:GetInfo()
	return {
		name = "Attack Target List Scenario Camera",
		desc = "Restores the view and selects the Sheldons",
		author = "local test setup",
		layer = 1000000,
		enabled = true,
	}
end

local positioned = false

function widget:Update()
	if Spring.GetModOptions().attacktargetlistscenario ~= true then
		widgetHandler:RemoveWidget(self)
		return
	end
	if positioned or Spring.GetGameFrame() < 5 then
		return
	end
	positioned = true

	Spring.SetCameraState({
		mode = 2,
		name = "spring",
		px = 810.389648,
		py = 227.514221,
		pz = 2590.49756,
		dx = 0.0000000014704,
		dy = -0.9995065,
		dz = -0.0314107,
		rx = 3.1101768,
		ry = 0.47123894,
		rz = 0,
		dist = 1664.40771,
		fov = 45,
	}, 0)

	local sheldons = {}
	for _, unitID in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID())) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if unitDefID and UnitDefs[unitDefID].name == "cormort" then
			sheldons[#sheldons + 1] = unitID
		end
	end
	Spring.SelectUnitArray(sheldons)
end
