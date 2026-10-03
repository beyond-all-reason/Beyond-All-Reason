local Regions = require("modules/regions/api")
local TransferEnums = require("modules/transfer/enums")

---@class MexRegionSources
local Sources = {}

local MAP_FILE = "luarules/configs/mex_regions.lua"
local EDITOR_DIR = "Terraform Brush/Regions/"

---@param modOptions table<string, any>
---@param mapSizeX number
---@param mapSizeZ number
---@return Region[]|nil regions
---@return string source
---@return string|nil reason
local function find(modOptions, mapSizeX, mapSizeZ)
	local raw = modOptions[TransferEnums.ModOptions.MexRegionsLayout]
	if type(raw) == "string" and raw ~= "" then
		local source = "modoption " .. TransferEnums.ModOptions.MexRegionsLayout
		local layout = Regions.DecodeLayout(raw)
		if layout == nil then
			return nil, source, "not a layout"
		end
		local regions, reason = Regions.ParseLayout(layout, Regions.Enums.Types.MexRegion, mapSizeX, mapSizeZ)
		return regions, source, reason
	end
	if VFS.FileExists(MAP_FILE) then
		local regions, reason =
			Regions.ParseLayout(VFS.Include(MAP_FILE), Regions.Enums.Types.MexRegion, mapSizeX, mapSizeZ)
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
---@return string|nil reason
function Sources.Load(modOptions, mapName, mapSizeX, mapSizeZ)
	local regions, source, reason = find(modOptions, mapSizeX, mapSizeZ)
	if regions == nil then
		return nil, source, reason
	end
	return regions, --[[@as MexRegion[] ]]
		source,
		nil
end

---@param raw string
---@param mapSizeX number
---@param mapSizeZ number
---@return MexRegion[]|nil regions
---@return string|nil reason
function Sources.FromBlob(raw, mapSizeX, mapSizeZ)
	local layout = Regions.DecodeLayout(raw)
	if layout == nil then
		return nil, "not a layout"
	end
	local regions, reason = Regions.ParseLayout(layout, Regions.Enums.Types.MexRegion, mapSizeX, mapSizeZ)
	if regions == nil then
		return nil, reason
	end
	return regions, --[[@as MexRegion[] ]]
		nil
end

---The terraformer's save for this map, as a layout blob. Unsynced only: the raw filesystem is closed to synced code,
---so a widget reads it and hands it to the gadget.
---@param mapName string
---@param mapSizeX number
---@param mapSizeZ number
---@return string|nil
function Sources.EditorBlob(mapName, mapSizeX, mapSizeZ)
	local editorFile = EDITOR_DIR .. mapName .. ".lua"
	if not VFS.FileExists(editorFile, VFS.RAW) then
		return nil
	end
	local ok, layout = pcall(VFS.Include, editorFile, nil, VFS.RAW)
	if not ok or type(layout) ~= "table" then
		return nil
	end
	-- the file is a layout already; it only has to hold mex regions to be worth sending
	local regions = Regions.ParseLayout(layout, Regions.Enums.Types.MexRegion, mapSizeX, mapSizeZ)
	if not regions or #regions == 0 then
		return nil
	end
	return Regions.EncodeLayout(layout)
end

return Sources
