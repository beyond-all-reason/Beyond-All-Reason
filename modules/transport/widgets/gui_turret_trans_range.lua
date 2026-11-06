local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Nano range on transport",
		desc = "Draw a circle around a transport carrying a nano when its about to unload",
		author = "Cheva",
		date = "December 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--------------------------------------------------------------------------------
--vars
--------------------------------------------------------------------------------
local circleDivisions = 96
local range
local isTransportableBuilding = {}
local turretRange = {}
local transportWithBuilding = {}
local isTurret = {}
local color

--------------------------------------------------------------------------------
--speedups
--------------------------------------------------------------------------------
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local spGetActiveCmd = Spring.GetActiveCommand
local GetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle

--------------------------------------------------------------------------------
--configurations
--------------------------------------------------------------------------------
local colors = {
	tower = { 1.0, 0.22, 0.05, 0.5 },
	turret = { 0.24, 1.0, 0.2, 0.40 },
}

for unitDefId, unitDef in pairs(UnitDefs) do
	if unitDef.isStaticBuilder and not unitDef.isFactory then
		isTransportableBuilding[unitDefId] = true
		turretRange[unitDefId] = unitDef.buildDistance
		isTurret[unitDefId] = true
	end
	if unitDef.isBuilding and not unitDef.cantBeTransported then
		isTransportableBuilding[unitDefId] = true
		turretRange[unitDefId] = unitDef.maxWeaponRange
	end
end

--------------------------------------------------------------------------------
--Transported Turret Range
--------------------------------------------------------------------------------
local function DrawNanoRange(x, y, z, range)
	glLineWidth(1)
	glColor(color[1], color[2], color[3], color[4])
	glDrawGroundCircle(x, y, z, range, circleDivisions)
	glColor(1, 1, 1, 1)
	glLineWidth(1)
end

function widget:UnitLoaded(unitID, unitDefID, teamID, transportID)
	if isTransportableBuilding[unitDefID] then
		range = turretRange[unitDefID]
		transportWithBuilding[transportID] = unitDefID
	end
end

function widget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
	transportWithBuilding[transportID] = nil
end

function widget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	transportWithBuilding[unitID] = nil
end

local tractorBeamMode = Spring.GetModOptions().beta_tractorbeam
local tractorBeams = tractorBeamMode and tractorBeamMode ~= "disabled"

-- tractor beam transports carry several buildings and set them down on the unload preview's pads
local function drawTractorRanges()
	local pads = WG.UnloadSnap and WG.UnloadSnap.GetPads()
	if not pads then
		return
	end
	for i = 1, #pads do
		local pad = pads[i]
		local passengers = pad[6] and { pad[6] } or Spring.GetUnitIsTransporting(pad[1]) or {}
		for j = 1, #passengers do
			local unitDefID = Spring.GetUnitDefID(passengers[j])
			if unitDefID and isTransportableBuilding[unitDefID] and turretRange[unitDefID] then
				color = isTurret[unitDefID] and colors.turret or colors.tower
				DrawNanoRange(pad[3], pad[4], pad[5], turretRange[unitDefID])
			end
		end
	end
end

function widget:DrawWorldPreUnit()
	if tractorBeams then
		drawTractorRanges()
		return
	end
	local _, cmdId, _, _ = spGetActiveCmd()
	if cmdId ~= CMD_UNLOAD_UNITS then
		return
	end
	local sel = GetSelectedUnitsSorted()
	local ranges = {}
	for _, unitIds in pairs(sel) do
		for _, unitId in pairs(unitIds) do
			if transportWithBuilding[unitId] then
				table.insert(ranges, {
					unitDefID = transportWithBuilding[unitId],
					range = turretRange[transportWithBuilding[unitId]],
				})
			end
		end
	end
	if #ranges == 0 then
		return
	end
	table.sort(ranges, function(a, b)
		return a.range < b.range
	end)
	range = ranges[1].range
	if range == nil then
		return
	end
	local turret = isTurret[ranges[1].unitDefID]
	color = turret and colors.turret or colors.tower
	--Spring.Echo(transportWithBuilding[unitId])
	local mouseX, mouseY = Spring.GetMouseState()
	local desc, args = Spring.TraceScreenRay(mouseX, mouseY, true)
	if desc == nil then
		return
	end
	local x, y, z = args[1], args[2], args[3]
	DrawNanoRange(x, y, z, range)
end
