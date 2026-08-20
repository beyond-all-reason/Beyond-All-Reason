local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Debug GetUnitsInPlanes Test",
		desc = "Calls Spring.GetUnitsInPlanes with a simple plane and echoes the number of units returned.",
		author = "Codex",
		date = "2026-08-13",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false,
	}
end
-- FIXME delete this
if gadgetHandler:IsSyncedCode() then
	return false
end

local spGetUnitsInPlanes = Spring.GetUnitsInPlanes
local spEcho = Spring.Echo

local function RunTest()
	local planes = {
		{
			normalVecX = 1,
			normalVecY = 0,
			normalVecZ = 0,
			d = 10,
		},
		{
			normalVecX = 0,
			normalVecY = 1,
			normalVecZ = 0,
			d = 10,
		},
	}

	local units = spGetUnitsInPlanes(planes, Spring.ALLY_UNITS)
	-- local units = spGetUnitsInPlanes(planes)
	spEcho("GetUnitsInPlanes test returned", #units, "units")
end

function gadget:MousePress(x, y, button)
	if button ~= 3 then
		return false
	end

	RunTest()
	return false
end
