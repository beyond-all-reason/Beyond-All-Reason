-- Exports a Terraform Brush map project to the files of a map archive, without the game.
-- The same translator as the brush's FILE > EXPORT MAP (common/map_export.lua).
--
--   lua5.1 tools/map_export/export.lua <project folder> <output folder>
--       [--name "Map Name"] [--version 1.0] [--description "..."] [--author "..."] [--asset-dir <folder>]...
--
-- --asset-dir: where to look for files the project only names, such as the skybox or the ramp image (repeatable).
-- Writes <output>/archive, <output>/compile and <output>/export_report.txt; exits 1 on errors.

local scriptDir = ((arg[0] or ""):gsub("\\", "/"):match("^(.*)/[^/]*$")) or "."
package.path = scriptDir .. "/../../common/?.lua;" .. package.path
local MapExport = require("map_export")

local windows = package.config:sub(1, 1) == "\\"

local fs = {}
function fs.read(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local data = f:read("*a")
	f:close()
	return data
end
function fs.write(path, data)
	local f = io.open(path, "wb")
	if not f then
		return false
	end
	f:write(data)
	f:close()
	return true
end
function fs.exists(path)
	local f = io.open(path, "rb")
	if f then
		f:close()
		return true
	end
	return false
end
function fs.mkdir(path)
	if windows then
		os.execute('if not exist "' .. path:gsub("/", "\\") .. '" mkdir "' .. path:gsub("/", "\\") .. '"')
	else
		os.execute("mkdir -p '" .. path:gsub("'", "'\\''") .. "'")
	end
end

---@type string[]
local positional = {}
---@type table
local opts = { assetDirs = {} }
local i = 1
while i <= #arg do
	local a = arg[i] or ""
	if a == "--asset-dir" then
		opts.assetDirs[#opts.assetDirs + 1] = arg[i + 1]
		i = i + 1
	elseif a:match("^%-%-") then
		opts[a:sub(3)] = arg[i + 1]
		i = i + 1
	else
		positional[#positional + 1] = a
	end
	i = i + 1
end
if #positional < 2 then
	io.stderr:write(
		"usage: lua5.1 export.lua <project folder> <output folder> [--name N] [--version V] [--asset-dir D]\n"
	)
	os.exit(2)
end

fs.mkdir(positional[2])
local report = MapExport.run({
	project = positional[1],
	out = positional[2],
	io = fs,
	name = opts.name,
	version = opts.version,
	description = opts.description,
	author = opts.author,
	assetDirs = opts.assetDirs,
})
print(MapExport.formatReport(report))
os.exit(report.ok and 0 or 1)
