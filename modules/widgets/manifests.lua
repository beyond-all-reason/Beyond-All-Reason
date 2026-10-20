-- Widget hub manifests; the format is BAR-Widgets/builder/schemas/manifests.schema.json.

local MANIFEST_FILE = "manifest.json"

local WidgetManifests = {}

-- The hub schema's widgetId rule.
function WidgetManifests.IsValidId(id)
	return type(id) == "string"
		and id:match("^[a-z][a-z0-9_]*$") ~= nil
		and id:find("_", 1, true) ~= nil
		and id:find("__", 1, true) == nil
		and id:sub(-1) ~= "_"
end

local function withTrailingSlash(dir)
	if dir:sub(-1) == "/" then
		return dir
	end

	return dir .. "/"
end

function WidgetManifests.ReadJson(path, vfsMode)
	if not VFS.FileExists(path, vfsMode) then
		return nil, nil
	end

	local text = VFS.LoadFile(path, vfsMode)
	if type(text) ~= "string" then
		return nil, "could not be read"
	end

	-- Windows editors can save a byte order mark, which the decoder reads as a syntax error.
	text = text:gsub("^\239\187\191", "")
	local ok, data = pcall(Json.decode, text)
	if not ok or type(data) ~= "table" then
		return nil, "is not valid JSON"
	end

	return data, nil
end

function WidgetManifests.Discover(folders, vfsMode)
	if type(folders) == "string" then
		folders = { folders }
	end

	local widgets = {}
	local warnings = {}
	local byId = {}

	for _, folder in ipairs(folders) do
		local dirs = VFS.SubDirs(folder, "*", vfsMode)
		table.sort(dirs)

		for _, dir in ipairs(dirs) do
			local widgetDir = withTrailingSlash(dir)
			local manifestFile = widgetDir .. MANIFEST_FILE
			local manifest, problem = WidgetManifests.ReadJson(manifestFile, vfsMode)

			if problem then
				warnings[#warnings + 1] = string.format("%s %s; manifest ignored", manifestFile, problem)
			elseif manifest then
				local id = manifest.id
				if not WidgetManifests.IsValidId(id) then
					warnings[#warnings + 1] = string.format(
						"%s: id %s is not a valid widget id; manifest ignored",
						manifestFile,
						tostring(id)
					)
				elseif byId[id] then
					warnings[#warnings + 1] = string.format(
						"%s: widget id %s is already claimed by %s; manifest ignored",
						manifestFile,
						id,
						byId[id].dir
					)
				else
					local widget = { id = id, dir = widgetDir, manifest = manifest, loaded = false }
					byId[id] = widget
					widgets[#widgets + 1] = widget
				end
			end
		end
	end

	return widgets, warnings
end

function WidgetManifests.MarkLoaded(widgets, filenames)
	local moved = {}

	local lowered = {}
	for i, filename in ipairs(filenames) do
		lowered[i] = filename:lower()
	end

	for _, widget in ipairs(widgets) do
		local dir = widget.dir:lower()
		local loaded = false
		for _, filename in ipairs(lowered) do
			if filename:sub(1, #dir) == dir then
				loaded = true
				break
			end
		end

		if widget.loaded ~= loaded then
			widget.loaded = loaded
			moved[#moved + 1] = widget
		end
	end

	return #moved > 0
end

return WidgetManifests
