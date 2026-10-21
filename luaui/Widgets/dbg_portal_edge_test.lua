-- This file is part of the Spring engine (GPL v2 or later), see LICENSE.html
function widget:GetInfo()
	return { name = "Portal edge flight capture", layer = 10010, enabled = true }
end
if Spring.GetModOptions().portal_worlds_test ~= "edges" then
	return false
end
local world = VFS.Include("luarules/Utilities/portal_worlds.lua")
local r, bounds = world.regions[1], world.objectBounds[1]
local initialized, captures, outsideVisible = false, 0, 0
local function Check(name, value)
	Spring.Echo("[PORTAL_EDGE_UI] ASSERT " .. name .. " pass=" .. tostring(not not value))
end
function widget:Update()
	if not initialized and Spring.GetGameFrame() >= 120 and WG.PortalWorldView then
		initialized = true
		local z = (r.z0 + r.z1) / 2
		Spring.SetCameraState({
			name = "ta",
			mode = 1,
			px = r.x1 - 120,
			py = Spring.GetGroundHeight(r.x1, z),
			pz = z,
			height = 1150,
			angle = 0.35,
			flipped = 0,
		}, 0)
		Spring.SendCommands("minimap min 1", "disticon 100000", "hideinterface 1")
	end
	if Spring.GetGameRulesParam("edge_test_done") == 1 then
		Check("outside_aircraft_has_model_draw_flags", outsideVisible > 30)
		Check("video_frames_captured", captures > 100)
		Spring.Echo("[PORTAL_EDGE_UI] CAPTURES " .. captures)
		Spring.SendCommands("quitforce")
	end
end
function widget:DrawWorld()
	if not initialized then
		return
	end
	local z = (r.z0 + r.z1) / 2
	local y = Spring.GetGroundHeight(r.x1, z) + 2
	gl.DepthTest(false)
	gl.Color(1, 0.85, 0.2, 0.9)
	gl.LineWidth(2)
	gl.BeginEnd(GL.LINES, function()
		gl.Vertex(r.x1, y, z - 500)
		gl.Vertex(r.x1, y, z + 500)
	end)
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(true)
end
local function DrawOverlay()
	if not initialized then
		return
	end
	local w, h = Spring.GetViewGeometry()
	gl.Color(0.02, 0.025, 0.035, 0.9)
	gl.Rect(16, h - 116, w - 16, h - 16)
	gl.Color(1, 1, 1, 1)
	gl.Text("BAR: aircraft and projectiles crossing the terrain edge", 32, h - 45, 20, "o")
	gl.Text("Yellow line = fixed terrain edge. Object margin = " .. bounds.margin .. " elmos.", 32, h - 72, 17, "o")
	gl.Text("Scripted flight for a repeatable render test; normal world isolation stays enabled.", 32, h - 96, 15, "o")
	local id = Spring.GetGameRulesParam("edge_aircraft_1")
	if type(id) == "number" then
		---@cast id UnitID
		local x, y, z = Spring.GetUnitPosition(id)
		if x then
			local sx, sy = Spring.WorldToScreenCoords(x, y + 55, z)
			local outside = x >= r.x1
			gl.Color(outside and 0.4 or 1, 1, outside and 0.6 or 1, 1)
			gl.Text(outside and "OUTSIDE terrain - still visible" or "Inside terrain", sx, sy, 16, "oc")
			if outside and (Spring.GetUnitDrawFlag(id) or 0) % 16 ~= 0 then
				outsideVisible = outsideVisible + 1
			end
		end
	end
	gl.Color(1, 1, 1, 1)
end
function widget:DrawScreenPost()
	local f = Spring.GetGameFrame()
	if initialized and f >= 150 and f <= 600 then
		DrawOverlay()
		local w, h = Spring.GetViewGeometry()
		assert(gl.SaveImage(0, 0, w, h, string.format("screenshots/edge-%05d.png", captures)))
		captures = captures + 1
	end
end
