local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Map Decals (Terraform Brush)",
		desc = "Places the ground decals a map exported from a Terraform Brush project carries (mapconfig/decals.lua)",
		author = "PtaQ",
		date = "2026-11-05",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- The file is the decal placer's project format ({tex, x, z, sx, sz, rot}), copied by the map
-- export; the calls are the placer's applyDecal with its defaults (the file keeps no alpha or
-- tint). Textures come from the game's decal atlas, built at startup from gamedata/resources.lua:
-- a map cannot add any, so a name the atlas lacks is skipped and counted. When the editor is open
-- on such a map, the decal placer adopts them, so they are editable and saved with a project.
local FILE = "mapconfig/decals.lua"
if not VFS.FileExists(FILE, VFS.MAP) or not Spring.CreateGroundDecal then
	return false
end

local made = {} -- { {id=, d=} }
local handed = false

local function isNormalName(n)
	return n:find("^norm")
		or n:find("^nrm")
		or n:find("_norm$")
		or n:find("_nrm$")
		or n:find("_normal$")
		or n:find("_n$")
end

-- the placer's pair key: "mainscar_5" and "normscar_5" -> "scar_5"
local function pairKey(n)
	return (
		n:gsub("^main", "")
			:gsub("^norm", "")
			:gsub("^nrm", "")
			:gsub("_norm$", "")
			:gsub("_nrm$", "")
			:gsub("_normal$", "")
			:gsub("_n$", "")
	)
end

function widget:Initialize()
	local ok, list = pcall(VFS.Include, FILE, {}, VFS.MAP)
	if not (ok and type(list) == "table") then
		Spring.Echo("[Map Decals] " .. FILE .. " not applied: " .. tostring(ok and "bad format" or list))
		widgetHandler:RemoveWidget(self)
		return
	end
	---@type table<string, string>
	local known = {}
	---@type table<string, string>
	local norms = {}
	for _, n in ipairs(Spring.GetGroundDecalTextures(true, true) or {}) do
		local l = n:lower()
		known[l] = n
		if isNormalName(l) then
			norms[pairKey(l)] = n
		end
	end
	local missing = 0
	for _, d in ipairs(list) do
		local tex = type(d) == "table" and type(d.tex) == "string" and known[d.tex:lower()]
		if tex and tonumber(d.x) and tonumber(d.z) then
			local id = Spring.CreateGroundDecal()
			if id then
				Spring.SetGroundDecalTexture(id, tex, true)
				local norm = norms[pairKey(tex:lower())]
				if norm then
					Spring.SetGroundDecalTexture(id, norm, false)
				end
				Spring.SetGroundDecalPosAndDims(id, d.x, d.z, d.sx or 64, d.sz or 64)
				Spring.SetGroundDecalRotation(id, d.rot or 0)
				Spring.SetGroundDecalAlpha(id, 0.85, 0)
				Spring.SetGroundDecalTint(id, 0.5, 0.5, 0.5, 0.5)
				Spring.SetGroundDecalNormal(id, 0, 0, 0)
				made[#made + 1] = { id = id, d = d }
			end
		elseif type(d) == "table" then
			missing = missing + 1
		end
	end
	if missing > 0 then
		Spring.Echo(string.format("[Map Decals] %d decal(s) name a texture this game's atlas does not have", missing))
	end
end

function widget:Update()
	local dp = WG.DecalPlacer
	if not handed and dp and dp.adopt then
		-- the editor is open: the placer owns these decals from now on
		handed = true
		dp.adopt(made)
	end
end

function widget:Shutdown()
	if handed then
		return
	end
	for _, m in ipairs(made) do
		Spring.DestroyGroundDecal(m.id)
	end
end
