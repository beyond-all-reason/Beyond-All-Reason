-- SPDX-License-Identifier: GPL-2.0-or-later
function widget:GetInfo()
	return {
		name = "Portal map materials",
		desc = "Apply the viewed map's DNTS, sun and atmosphere",
		author = "Codex",
		license = "GPL v2 or later",
		layer = 10000,
		enabled = true,
		handler = true,
	}
end
local modOptions = Spring.GetModOptions()
if not modOptions.portal_worlds or modOptions.portal_worlds == "off" then
	return false
end
local world = VFS.Include("luarules/Utilities/portal_worlds.lua")
if not world then
	return false
end
local profiles = world.profiles
local applied, updates, loaded = nil, 0, {}
local function Environment(profile)
	local d = profile.direction
	Spring.SetSunDirection(d[1], d[2], d[3])
	Spring.SetSunLighting(profile.sun)
	Spring.SetAtmosphere(profile.atmosphere)
	if profile.water then
		Spring.SetWaterParams(profile.water)
	end

end
local function Apply(region)
	local profile = profiles[region]
	for _, texture in ipairs(profile.textures) do
		local path = texture[2]
		if not loaded[path] then
			-- SetMapShadingTexture uses named textures that are already loaded.
			local list = gl.CreateList(function()
				assert(gl.Texture(path), "Could not load portal map texture " .. path)
				gl.Texture(false)
			end)
			gl.DeleteList(list)
			loaded[path] = true
		end
		assert(
			Spring.SetMapShadingTexture(texture[1], path, texture[3] or 0),
			"Could not set portal map texture " .. path
		)
	end
	Spring.SetMapRenderingParams(profile.rendering)
	Spring.SetDrawWater(profile.drawWater ~= false)
	Environment(profile)
	applied = region
	WG.PortalMapMaterial = { region = region, profile = profile }
end
function widget:Update()
	updates = updates + 1
	local view = WG.PortalWorldView
	if not view or not view.rect then
		return
	end
	local region = view.region
	if applied ~= region then
		Apply(region)
	-- Default lighting widgets may finish their setup during the first updates.
	elseif updates <= 30 then
		Environment(profiles[region])
	end
end
function widget:Shutdown()
	for _, texture in ipairs(profiles[1].textures) do
		Spring.SetMapShadingTexture(texture[1], "", texture[3] or 0)
	end
	Spring.SetDrawWater(true)
	WG.PortalMapMaterial = nil
end
