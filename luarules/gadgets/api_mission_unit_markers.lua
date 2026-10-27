local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mission unit markers",
		desc = "Draws the Mission API's unit markers as lines above their units",
		author = "efrec",
		date = "2026-09-15",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then
	return false
end

local SYNC_ACTION = "MissionUnitMarkers"

local LINE_HEIGHT = 16
local LINE_GAP = 8
local LINE_WIDTH = 2
local LINE_COLOR = { 1, 1, 1, 1 }

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spIsGUIHidden = Spring.IsGUIHidden
local spIsUnitVisible = Spring.IsUnitVisible

local glBeginEnd = gl.BeginEnd
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glVertex = gl.Vertex
local GL_LINES = GL.LINES

local unitHeight = table.map(UnitDefs, function(unitDef, unitDefID)
	return unitDef.height, unitDefID
end)

---Marker types per unit. An untyped marker is the empty string.
---@type table<UnitID, string[]?>
local markedUnits = {}

local function handleUnitMarkers(_, unitID, markerTypes)
	markedUnits[unitID] = #markerTypes > 0 and markerTypes or nil
end

local function drawUnitMarkers(x, y, z, count)
	for i = 1, count do
		local base = y + (i - 1) * (LINE_HEIGHT + LINE_GAP)
		glVertex(x, base, z)
		glVertex(x, base + LINE_HEIGHT, z)
	end
end

function gadget:Initialize()
	gadgetHandler:AddSyncAction(SYNC_ACTION, handleUnitMarkers)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction(SYNC_ACTION)
end

function gadget:UnitDestroyed(unitID)
	markedUnits[unitID] = nil
end

function gadget:DrawWorld()
	if spIsGUIHidden() then
		return
	end

	local drawing = false
	for unitID, markerTypes in pairs(markedUnits) do
		if spIsUnitVisible(unitID) then
			local x, y, z = spGetUnitPosition(unitID)
			if x then
				if not drawing then
					drawing = true
					glLineWidth(LINE_WIDTH)
					glColor(LINE_COLOR)
				end
				-- Radar blips have no unit def, so they get the lines at their own height.
				local height = unitHeight[spGetUnitDefID(unitID)] or 10
				glBeginEnd(GL_LINES, drawUnitMarkers, x, y + height, z, #markerTypes)
			end
		end
	end

	if drawing then
		glColor(1, 1, 1, 1)
		glLineWidth(1)
	end
end
