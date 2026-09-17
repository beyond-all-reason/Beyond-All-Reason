local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Enums = VFS.Include("modules/regions/enums.lua")
local Records = VFS.Include("modules/transfer/mex_splitting/records.lua") ---@type MexRegionsRecords
local TransferEnums = VFS.Include("modules/transfer/enums.lua")

---@class MexRegionSources where a match's mex region layout comes from: the modoption, the map, or the terraformer's save
local Sources = {}

local MAP_FILE = "luarules/configs/mex_regions.lua"
local EDITOR_DIR = "Terraform Brush/Regions/"

---@param entries table what the terraformer saved: anchors in elmos, splines to tessellate
---@return Region[]
local function regionsFromEditor(entries)
	local SplineLib = VFS.Include("common/lib_spline.lua")
	local regions = {} ---@type Region[]
	for _, entry in ipairs(entries) do
		local anchors = type(entry) == "table" and (entry.anchors or entry.vertices) or nil
		if
			type(anchors) == "table"
			and #anchors >= 3
			and (entry.type == nil or entry.type == Enums.Types.MexRegion)
		then
			local vertices
			if entry.kind == "box" then
				vertices = {}
				for i, a in ipairs(anchors) do
					vertices[i] = { x = a.x, z = a.z }
				end
			else
				local ring = {}
				for i, a in ipairs(anchors) do
					ring[i] = { a.x, a.z, a.strength }
				end
				vertices = {}
				for i, p in ipairs(SplineLib.TessellateRing(ring)) do
					vertices[i] = { x = p[1], z = p[2] }
				end
			end
			regions[#regions + 1] = {
				type = Enums.Types.MexRegion,
				name = entry.name,
				team = entry.team,
				group = entry.group,
				vertices = vertices,
			}
		end
	end
	return regions
end

---@param modOptions table<string, any>
---@param mapName string
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]|nil regions
---@return string source where they came from, or what was looked for
---@return string|nil reason why the source gave none
local function find(modOptions, mapName, mapSizeX, mapSizeZ)
	local raw = modOptions[TransferEnums.ModOptions.MexRegionsLayout]
	if type(raw) == "string" and raw ~= "" then
		local source = "modoption " .. TransferEnums.ModOptions.MexRegionsLayout
		local layout = Regions.DecodeLayout(raw)
		if layout == nil then
			return nil, source, "not a layout"
		end
		local regions, reason = Regions.ParseLayout(layout, Enums.Types.MexRegion, mapSizeX, mapSizeZ)
		return regions, source, reason
	end
	if VFS.FileExists(MAP_FILE) then
		local regions, reason = Regions.ParseLayout(VFS.Include(MAP_FILE), Enums.Types.MexRegion, mapSizeX, mapSizeZ)
		return regions, MAP_FILE .. " (from the map)", reason
	end
	local editorFile = EDITOR_DIR .. mapName .. ".lua"
	if VFS.FileExists(editorFile, VFS.RAW) then
		local source = editorFile .. " (the terraformer's save)"
		local ok, entries = pcall(VFS.Include, editorFile, nil, VFS.RAW)
		if not ok or type(entries) ~= "table" then
			return nil, source, "could not be read"
		end
		local regions = regionsFromEditor(entries)
		if #regions == 0 then
			return nil, source, "has no mex regions"
		end
		return regions, source, nil
	end
	return nil, "no layout: not the modoption, the map's " .. MAP_FILE .. ", nor " .. editorFile, nil
end

---@param modOptions table<string, any>
---@param mapName string
---@param mapSizeX number
---@param mapSizeZ number
---@return MexRegion[]|nil regions
---@return string source
---@return string|nil reason why there are none
function Sources.Load(modOptions, mapName, mapSizeX, mapSizeZ)
	local regions, source, reason = find(modOptions, mapName, mapSizeX, mapSizeZ)
	if regions == nil then
		return nil, source, reason
	end
	return Records.From(regions), source, nil
end

return Sources
