-- SPDX-License-Identifier: GPL-2.0-or-later
function widget:GetInfo()
	return {
		name = "Portal metal spot tests",
		desc = "Opt-in GPU checks of BAR metal spot region clipping",
		author = "Codex",
		license = "GPL v2 or later",
		layer = 10003,
		enabled = true,
		handler = true,
	}
end
if Spring.GetModOptions().portal_worlds_test ~= "four" then
	return false
end
local world = VFS.Include("luarules/Utilities/portal_worlds.lua")
local stage, drawAfter, target, finished = 0, nil, nil, false
local texture, framebuffer, query
local checks, failures = 0, 0
local function Check(key, value, detail)
	checks = checks + 1
	if not value then
		failures = failures + 1
	end
	Spring.Echo("[BAR_METAL_UI] ASSERT " .. key .. " pass=" .. tostring(not not value) .. " " .. tostring(detail or ""))
end
local function TargetSpot(region)
	local r = world.regions[region]
	local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	local nearest, distance
	for _, spot in ipairs(WG.resource_spot_finder.metalSpotsList) do
		-- The ordinary renderer omits very large deposits and metal-map patches.
		-- Aim at an eligible deposit so a zero-sample result is meaningful.
		local scale = 0.77 + math.abs(spot.maxX - spot.minX) * math.abs(spot.maxZ - spot.minZ) / 10000
		if world.Region(spot.x, spot.z) == region and scale < 4 and spot.worth > 1 and spot.worth < 15000 then
			local d = (spot.x - cx) ^ 2 + (spot.z - cz) ^ 2
			if not distance or d < distance then
				nearest, distance = spot, d
			end
		end
	end
	return assert(nearest, "Fixture needs a drawable metal spot in each region")
end
function widget:Update()
	if finished or drawAfter or not WG.PortalWorldsUITestsDone then
		return
	end
	stage = stage + 1
	if stage > #world.regions then
		finished = true
		return
	end
	target = TargetSpot(stage)
	WG.PortalWorlds.View(stage, {
		name = "ta",
		mode = 1,
		px = target.x,
		py = Spring.GetGroundHeight(target.x, target.z),
		pz = target.z,
		height = 650,
		angle = 0.05,
		flipped = 0,
	})
	drawAfter = Spring.GetDrawFrame() + 5
end
function widget:DrawScreenPost()
	if not drawAfter or Spring.GetDrawFrame() < drawAfter then
		return
	end
	drawAfter = nil
	if not framebuffer then
		texture = gl.CreateTexture(256, 256, { format = GL.RGBA8, min_filter = GL.NEAREST, mag_filter = GL.NEAREST })
		framebuffer = gl.CreateFBO({ color0 = texture })
		query = gl.CreateQuery()
		Check("metal_framebuffer", framebuffer and gl.IsValidFBO(framebuffer) and query)
	end
	local metal = assert(widgetHandler:FindWidget("Metalspots"))
	local savedView = WG.PortalWorldView
	local other = world.regions[stage % #world.regions + 1]
	-- Draw the real widget's VAO/shader into an empty framebuffer. GPU sample
	-- counts test actual rasterization; terrain and other UI cannot mask leaks.
	local function Samples(view, underwater, name)
		WG.PortalWorldView = view
		metal:LavaRenderState(underwater and 10000 or -10000)
		local samples
		gl.ActiveFBO(framebuffer, function()
			gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
			gl.RunQuery(query, function()
				if underwater then
					metal:DrawWorld()
				else
					metal:DrawWorldPreUnit()
				end
			end)
			samples = gl.GetQuery(query)
			if name then
				gl.SaveImage(0, 0, 256, 256, "screenshots/metalspots-" .. stage .. "-" .. name .. ".png")
			end
		end)
		return samples
	end
	for _, underwater in ipairs({ false, true }) do
		local pass = underwater and "underwater" or "above"
		local ordinary = Samples(nil, underwater)
		local localSamples = Samples(savedView, underwater, pass)
		local foreign = Samples({ rect = other }, underwater)
		Check("metal_ordinary_" .. pass .. "_" .. stage, ordinary > 0, ordinary)
		Check("metal_local_" .. pass .. "_" .. stage, localSamples > 0, localSamples)
		Check("metal_foreign_hidden_" .. pass .. "_" .. stage, foreign == 0, foreign)
	end
	WG.PortalWorldView = savedView
	metal:LavaRenderState(nil)
	gl.DepthTest(false)
	gl.DepthMask(true)
	if stage == #world.regions then
		finished = true
		Spring.Echo("[BAR_METAL_UI] DONE checks=" .. checks .. " failures=" .. failures)
	end
end
function widget:Shutdown()
	if query then
		gl.DeleteQuery(query)
	end
	if framebuffer then
		gl.DeleteFBO(framebuffer)
	end
	if texture then
		gl.DeleteTexture(texture)
	end
end
