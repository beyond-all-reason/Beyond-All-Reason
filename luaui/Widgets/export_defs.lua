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

local function BuildSoundIndex()
	-- Index keyed by lowercased basename; engine sound-name resolution is case-insensitive
	-- (e.g. unitdefs reference "Rockhvy1" but the file on disk is sounds/weapons/rockhvy1.wav).
	local index = {}
	local function scanDir(dir)
		for _, ext in ipairs({ "wav", "ogg" }) do
			for _, file in ipairs(VFS.DirList(dir, "*." .. ext) or {}) do
				local basename = file:match("([^/\\]+)%.[^.]+$")
				if basename then
					local key = basename:lower()
					if not index[key] then index[key] = file end
				end
			end
		end
		for _, sub in ipairs(VFS.SubDirs(dir) or {}) do
			scanDir(sub)
		end
	end
	scanDir("sounds/")
	local ok, soundsModule = pcall(VFS.Include, "gamedata/sounds.lua")
	if ok and type(soundsModule) == "table" and type(soundsModule.SoundItems) == "table" then
		for name, def in pairs(soundsModule.SoundItems) do
			if type(def) == "table" and type(def.file) == "string" then
				index[name:lower()] = def.file
			end
		end
	end
	return index
end

local function BuildIconTypeIndex()
	local ok, result = pcall(VFS.Include, "gamedata/icontypes.lua")
	if ok and type(result) == "table" then return result end
	return {}
end

local function ResolveSoundPath(soundIndex, name)
	if type(name) ~= "string" or name == "" then return nil end
	return soundIndex[name:lower()]
end

local function ResolveBuildPicPath(buildPic)
	if type(buildPic) ~= "string" or buildPic == "" then return nil end
	for _, candidate in ipairs({ "unitpics/" .. buildPic, "unitpics/" .. buildPic:lower() }) do
		if VFS.FileExists(candidate) then return candidate end
	end
	return nil
end

local function AnnotateSoundArray(soundArray, soundIndex)
	if type(soundArray) ~= "table" then return end
	for _, entry in ipairs(soundArray) do
		if type(entry) == "table" then
			entry.path = ResolveSoundPath(soundIndex, entry.name)
		end
	end
end

local function AnnotateWeaponDefAssets(wd, soundIndex)
	AnnotateSoundArray(wd.fireSound, soundIndex)
	AnnotateSoundArray(wd.hitSound, soundIndex)
end

local function AnnotateUnitDefAssets(ud, soundIndex, iconTypeIndex)
	ud.buildPicPath = ResolveBuildPicPath(ud.buildPic)
	local iconEntry = iconTypeIndex[ud.iconType]
	ud.iconTypePath = (type(iconEntry) == "table" and type(iconEntry.bitmap) == "string") and iconEntry.bitmap or nil
	if type(ud.sounds) == "table" then
		for _, soundArr in pairs(ud.sounds) do
			AnnotateSoundArray(soundArr, soundIndex)
		end
	end
end

local function FlattenWeaponDef(weaponDef)
	local tbl = {}
	for field_name, value in pairs(weaponDef) do
		if type(value) ~= "table" and type(value) ~= "function" then
			tbl[field_name] = value
		end
	end
	for k, v in weaponDef:pairs() do
		tbl[k] = v
	end
	return tbl
end

local function ExportWeaponDefs(soundIndex)
	local subdir = export_folder_path .. "/weaponDefs"
	Spring.CreateDir(subdir)
	for _, weaponDef in pairs(WeaponDefs) do
		spEcho(string.format("Exporting weapondef: %s", weaponDef.name))
		local flattened = FlattenWeaponDef(weaponDef)
		AnnotateWeaponDefAssets(flattened, soundIndex)
		TableToFile(flattened, string.format("%s/%s.json", subdir, weaponDef.name))
	end
end

local function ExportDefs()
	if not VFS.FileExists(export_folder_path) then
		Spring.CreateDir(export_folder_path)
	end
	local unit_subdir = export_folder_path .. "/unitDefs"
	Spring.CreateDir(unit_subdir)

	spEcho("Building asset indices")
	local soundIndex = BuildSoundIndex()
	local iconTypeIndex = BuildIconTypeIndex()

	ExportWeaponDefs(soundIndex)

	for id, unitDef in pairs(UnitDefs) do
		spEcho(string.format("Exporting unitdef: %s", unitDef.name))
		local tbl = {}

		-- embed higher-level "computed" fields like translatedHumanName, translatedTooltip, etc.
		for field_name, value in pairs(unitDef) do
			if type(value) ~= "table" and type(value) ~= "function" then
				tbl[field_name] = value
			end
		end

		-- flatten the UnitDef metatable data into plain table
		for k, v in unitDef:pairs() do
			tbl[k] = v
		end

		-- wDefs is a parallel array of weapondef names indexed by mount slot
		-- (matches unit.weapons[i]); full weapondef data lives in weaponDefs.json
		tbl["wDefs"] = {}
		for i, weaponDef in pairs(unitDef.wDefs) do
			tbl["wDefs"][i] = weaponDef.name
		end

		-- annotate each weapons[] mount entry with its weapondef name so consumers
		-- can dereference into weaponDefs.json without needing the parallel wDefs array
		if type(tbl.weapons) == "table" then
			for _, weapon in pairs(tbl.weapons) do
				if type(weapon) == "table" then
					local wd = type(weapon.weaponDef) == "number" and WeaponDefs[weapon.weaponDef] or nil
					if wd then weapon.weaponDefName = wd.name end
				end
			end
		end

		AnnotateUnitDefAssets(tbl, soundIndex, iconTypeIndex)

		TableToFile(tbl, string.format("%s/%s.json", unit_subdir, unitDef.name))
	end
end

function widget:TextCommand(command)
	if command == "exportdefs" then
		ExportDefs()
	end
end





