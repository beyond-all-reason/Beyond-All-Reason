function widget:GetInfo()
	return {
		name = "Unitdefs JSON Export",
		desc = "Exports UnitDefs into JSON files.",
		author = "Wereii",
		date = "June 2023",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = false
	}
end

local export_folder_path = "json_export"

local function TableToFile(tbl, filename)
	local file, err = io.open(filename, "w")
	if not file then
		Spring.Echo("Error opening file: " .. err)
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
		Spring.Echo(string.format("Exporting unitdef: %s", unitDef.name))
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

		TableToFile(tbl, string.format("%s/%s.json", export_folder_path, unitDef.name))
	end
end

function widget:TextCommand(command)
	if string.find(command, "exportdefs", nil, true) == 1 and string.len(command) == 10 then
		ExportDefs()
	end
end





