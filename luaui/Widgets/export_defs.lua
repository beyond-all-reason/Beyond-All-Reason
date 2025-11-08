local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unitdefs JSON Export",
		desc = "Exports UnitDefs into JSON files.\nCommand: /exportdefs",
		author = "Wereii",
		date = "June 2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spEcho = Spring.Echo

local export_folder_path = "json_export"

local function TableToFile(tbl, filename)
	local file, err = io.open(filename, "w")
	if not file then
		spEcho("Error opening file: " .. err)
		return
	end
	file:write(Json.encode(tbl))
	file:close()
end

local function ExportDefs()
	if not VFS.FileExists(export_folder_path) then
		Spring.CreateDir(export_folder_path)
	end

	for id, unitDef in pairs(UnitDefs) do
		spEcho(string.format("Exporting unitdef: %s", unitDef.name))
		local tbl = {}

		-- embed higher-level "computed" fields like translatedHumanName, translatedTooltip, etc.
		for field_name, value in pairs(unitDef) do
			if type(value) ~= "table" or type(value) ~= "function" then
				tbl[field_name] = value
			end
		end

		-- flatten the UnitDef metatable data into plain table
		for k, v in unitDef:pairs() do
			tbl[k] = v
		end

		-- parse wDefs, a list of weaponDef metatables
		tbl["wDefs"] = {}
		for i, weaponDef in pairs(unitDef.wDefs) do
			tbl["wDefs"][weaponDef.id] = {}
			for field_name, value in weaponDef:pairs() do
				tbl["wDefs"][weaponDef.id][field_name] = value
			end
		end

		TableToFile(tbl, string.format("%s/%s.json", export_folder_path, unitDef.name))
	end
end

function widget:TextCommand(command)
	if command == "exportdefs" then
		ExportDefs()
	end
end





