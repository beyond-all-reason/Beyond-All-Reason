
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Startbox Editor",
		desc    = "cruder than yo momma",
		author  = "git blame",
		date    = "git log",
		license = "PD",
		layer   = 999999,
		enabled = false,
	}
end

-- this is not ZK copy, its is modified

--[[ tl;dr
LMB to draw (either clicks or drag)
RMB to accept a polygon
D to remove last polygon
S to export and add team boxes to file startboxes_mapname.txt

how to apply the export, see: http://zero-k.info/mediawiki/index.php?title=Startbox_API
]]

local polygon = { }
local final_polygons = { }
local exportedTeam = 0
local exported = ''
local exportPrefix = "return {\n"
local exportSuffix = "}\n"

function widget:MousePress(mx, my, button)
	widgetHandler:UpdateCallIn("MapDrawCmd")

	local pos = select(2, Spring.TraceScreenRay(mx, my, true, true))
	if not pos then
		return true
	end

	if #polygon == 0 then
		polygon[#polygon+1] = pos
	else
		local dx = math.abs(pos[1] - polygon[#polygon][1])
		local dz = math.abs(pos[3] - polygon[#polygon][3])
		if (dx > 10 or dz > 10) then
			polygon[#polygon+1] = pos
		end
	end

	if button ~= 1 then
		final_polygons[#final_polygons+1] = polygon
		polygon = {}
	end
	return true
end

function widget:MouseRelease(mx, my, button)
	widgetHandler:RemoveCallIn("MapDrawCmd")
	return true
end

function widget:MouseMove(mx, my)
	local pos = select(2, Spring.TraceScreenRay(mx, my, true))
	if not pos then
		return
	end

	if #polygon == 0 then
		polygon[1] = pos
	else
		local dx = math.abs(pos[1] - polygon[#polygon][1])
		local dz = math.abs(pos[3] - polygon[#polygon][3])
		if dx > 10 or dz > 10 then
			polygon[#polygon+1] = pos
		end
	end
	return true
end

include("keysym.h.lua")

function widget:KeyPress(key)
	if key == KEYSYMS.S then
		local str = "\t["..exportedTeam.."] = {\n"
		str = str .. "\t\tnameLong = \"\",\n"
		str = str .. "\t\tnameShort = \"\",\n"
		str = str .. "\t\tstartpoints = {},\n"
		str = str .. "\t\tboxes = {\n" -- not as separate echoes because timestamp keeps getting in the way
		for j = 1, #final_polygons do
			str = str .. "\t\t\t{\n"
			local polygon = final_polygons[j]
			for i = 1, #polygon do
				local pos = polygon[i]
				str = str .. "\t\t\t\t{" .. math.floor(pos[1]) .. ", " .. math.floor(pos[3]) .. "},\n"
			end
			str = str .. "\t\t\t},\n"
		end
		str = str .. "\t\t},\n"
		str = str .. "\t},\n"

		exported = exported .. str
		local filename = 'startboxes_'..Game.mapName..'.txt'
		local file = assert(io.open(filename, 'w'), 'Unable to save '..filename)
		file:write(exportPrefix..exported..exportSuffix)
		file:close()
		Spring.Echo((exportedTeam == 0 and 'saved' or 'added')..' team '..exportedTeam..' startboxes to '..filename)

		final_polygons = {}
		exportedTeam = exportedTeam + 1
	end
	if key == KEYSYMS.D and #final_polygons > 0 then
		final_polygons[#final_polygons] = nil
	end
end

local function DrawLine()
	for i = 1, #polygon do
		local x = polygon[i][1]
		local z = polygon[i][3]
		local y = Spring.GetGroundHeight(x, z)
		gl.Vertex(x,y,z)
	end

	local mx,my = Spring.GetMouseState()
	local pos = select(2, Spring.TraceScreenRay(mx, my, true))
	if pos then
		gl.Vertex(pos[1],pos[2],pos[3])
	end
end

local function DrawFinalLine(fpi)
	local poly = final_polygons[fpi]
	for i = 1, #poly do
		local x = poly[i][1]
		local z = poly[i][3]
		local y = Spring.GetGroundHeight(x, z)
		gl.Vertex(x,y,z)
	end

	gl.Vertex(poly[1][1], poly[1][2], poly[1][3])
end

function widget:DrawWorld()
	if #final_polygons == 0 and #polygon == 0 then return end
	gl.LineWidth(3.0)
	gl.Color(0, 1, 0, 0.5)
	for i = 1, #final_polygons do
		gl.BeginEnd(GL.LINE_STRIP, DrawFinalLine, i)
	end
	gl.Color(0, 1, 0, 1)
	gl.BeginEnd(GL.LINE_STRIP, DrawLine)
	gl.LineWidth(1.0)
	gl.Color(1, 1, 1, 1)
end

function widget:Initialize()
	widgetHandler:RemoveCallIn("MapDrawCmd")
end
