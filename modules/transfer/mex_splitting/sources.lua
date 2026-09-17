local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Enums = VFS.Include("modules/regions/enums.lua")
local Records = VFS.Include("modules/transfer/mex_splitting/records.lua") ---@type MexRegionsRecords
local TransferEnums = VFS.Include("modules/transfer/enums.lua")

---@class MexRegionSources where a match's mex region layout comes from: the modoption or the map; a lone player's terraformer save reaches the gadget through their widget
local Sources = {}

local MAP_FILE = "luarules/configs/mex_regions.lua"
local EDITOR_DIR = "Terraform Brush/Regions/"

---@param modOptions table<string, any>
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]|nil regions
---@return string source where they came from, or what was looked for
---@return string|nil reason why the source gave none
local function find(modOptions, mapSizeX, mapSizeZ)
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
	return nil, "no layout: not the modoption, nor the map's " .. MAP_FILE, nil
end

---@param modOptions table<string, any>
---@param mapName string
---@param mapSizeX number
---@param mapSizeZ number
---@return MexRegion[]|nil regions
---@return string source
---@return string|nil reason why there are none
function Sources.Load(modOptions, mapName, mapSizeX, mapSizeZ)
	local regions, source, reason = find(modOptions, mapSizeX, mapSizeZ)
	if regions == nil then
		return nil, source, reason
	end
	return Records.From(regions), source, nil
end

---@param raw string a layout as the modoption carries it
---@param mapSizeX number
---@param mapSizeZ number
---@return MexRegion[]|nil regions
---@return string|nil reason why not
function Sources.FromBlob(raw, mapSizeX, mapSizeZ)
	local layout = Regions.DecodeLayout(raw)
	if layout == nil then
		return nil, "not a layout"
	end
	local regions, reason = Regions.ParseLayout(layout, Enums.Types.MexRegion, mapSizeX, mapSizeZ)
	if regions == nil then
		return nil, reason
	end
	return Records.From(regions), nil
end

---The terraformer's save for this map, as a layout blob. Unsynced only: the raw filesystem is closed to synced code,
---so a widget reads it and hands it to the gadget.
---@param mapName string
---@param mapSizeX number
---@param mapSizeZ number
---@return string|nil blob
function Sources.EditorBlob(mapName, mapSizeX, mapSizeZ)
	local editorFile = EDITOR_DIR .. mapName .. ".lua"
	if not VFS.FileExists(editorFile, VFS.RAW) then
		return nil
	end
	local ok, data = pcall(VFS.Include, editorFile, nil, VFS.RAW)
	if not ok or type(data) ~= "table" then
		return nil
	end
	local all = Regions.ReadEditorFile(data)
	local regions = {}
	for _, region in ipairs(all) do
		if region.type == Enums.Types.MexRegion then
			regions[#regions + 1] = region
		end
	end
	if #regions == 0 then
		return nil
	end
	return Regions.EncodeLayout(Regions.ExportLayout(regions, mapSizeX, mapSizeZ))
end

return Sources
