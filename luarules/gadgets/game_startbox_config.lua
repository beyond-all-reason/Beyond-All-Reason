local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = 'Startbox Config',
		desc = 'Loads polygon startbox configurations and provides containment checks via GG',
		author = 'Harkenn',
		date = '2026',
		license = 'GNU GPL, v2 or later',
		layer = -999, -- after FFA start setup (-1000), before initial spawn (0) and no-rush (-100)
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local PolygonLib = VFS.Include("common/lib_polygon.lua")

local EXPLICIT_SOURCES = {
	modside = true,
	mapside = true,
	autohost_polygon = true,
}

local startBoxConfig
local configSource
local isExplicitConfig = false

function gadget:Initialize()
	local ParseBoxes = VFS.Include("luarules/gadgets/include/startbox_utilities.lua")
	local ok, config, source = pcall(ParseBoxes)
	if ok then
		startBoxConfig = config
		configSource = source
	else
		Spring.Log(gadget:GetInfo().name, LOG.WARNING, 'Failed to parse startbox config: ' .. tostring(config))
	end

	isExplicitConfig = EXPLICIT_SOURCES[configSource] or false

	-- Expand the engine AABB for each active allyTeam to cover the polygon bounds.
	-- Without this, the engine silently drops clicks outside its default AABB and never
	-- calls AllowStartPosition, making polygons that extend beyond the lobby's
	-- rectangle unreachable.
	if isExplicitConfig and startBoxConfig then
		local allyTeamList = Spring.GetAllyTeamList()
		for _, allyTeamID in ipairs(allyTeamList) do
			local entry = startBoxConfig[allyTeamID]
			if entry and entry.boxes then
				local xmin, zmin, xmax, zmax = PolygonLib.GetStartboxBounds(entry)
				Spring.SetAllyTeamStartBox(allyTeamID, xmin, zmin, xmax, zmax)
			end
		end
	end

	GG.startBoxConfig = startBoxConfig
	GG.startBoxConfigSource = configSource

	GG.IsInsideStartbox = function(x, z, allyTeamID)
		if not isExplicitConfig then
			return nil -- caller should fall back to engine AABB
		end

		local entry = startBoxConfig[allyTeamID]
		if not entry then
			return nil -- no polygon config for this allyTeam
		end

		return PolygonLib.PointInStartbox(x, z, entry)
	end

	GG.GetStartboxBounds = function(allyTeamID)
		if not isExplicitConfig then
			return nil -- caller should fall back to engine AABB
		end

		local entry = startBoxConfig[allyTeamID]
		if not entry then
			return nil
		end

		return PolygonLib.GetStartboxBounds(entry)
	end

	GG.GetStartboxPolygons = function(allyTeamID)
		if not isExplicitConfig then
			return nil
		end

		local entry = startBoxConfig[allyTeamID]
		if not entry then
			return nil
		end

		return entry.boxes
	end
end
