-- forward func declarations

---@param fileOrDirPath string
---@param vfsMode
---@param loaderCallback fun(filePath:string, parentWupget: table | nil): table, string[] | boolean
---@param loadedWupgets string[] | nil
---@param parentWupget table | nil
local function loadFromPath(fileOrDirPath, vfsMode, loaderCallback, loadedWupgets, parentWupget)
end

---@param modulePaths string[]
---@param vfsMode
---@param loaderCallback fun(filePath:string, parentWupget: table | nil): table, string[] | boolean
---@param loadedWupgets string[] | nil
---@param parentWupget table | nil
local function loadFromList(modulePaths, vfsMode, loaderCallback, loadedWupgets, parentWupget)
end

---@param dirPath string
---@param vfsMode
---@param loaderCallback fun(filePath:string, parentWupget: table | nil): table, string[] | boolean
---@param loadedWupgets string[] | nil
---@param parentWupget table | nil
local function loadAllInDir(dirPath, vfsMode, loaderCallback, loadedWupgets, parentWupget)
end

local recursionDepth = 0
local MAX_RECURSION_DEPTH = 10

function loadFromPath(fileOrDirPath, vfsMode, loaderCallback, loadedWupgets, parentWupget)
	loadedWupgets = loadedWupgets or {}
	if table.contains(loadedWupgets, fileOrDirPath) then
		return
	end

	local isScript = string.find(fileOrDirPath, "[%g ]-%.lua") and VFS.FileExists(fileOrDirPath)
	local isDir = not isScript -- and VFS.DirExists(filePath)

	if isScript then
		local ok, newWupget, subModulesPaths = pcall(loaderCallback, fileOrDirPath, parentWupget)

		if not ok then
			Spring.Log("[Wupget Loader]", LOG.ERROR, newWupget)
		end

		if newWupget == nil then
			return
		end

		local _, _, path = string.find(fileOrDirPath, "(.*[\\/:])[^\\/:]*$")
		table.insert(loadedWupgets, fileOrDirPath)
		if parentWupget ~= nil then
			newWupget._parent = parentWupget

			parentWupget._children = parentWupget._children or {}
			table.insert(parentWupget._children, newWupget)
		end

		if recursionDepth <= MAX_RECURSION_DEPTH then
			recursionDepth = recursionDepth + 1

			if type(subModulesPaths) == 'boolean' and subModulesPaths == true then
				loadAllInDir(path, vfsMode, loaderCallback, loadedWupgets, newWupget)
			elseif type(subModulesPaths) == 'table' and #subModulesPaths > 0 then
				for idx, subModulePath in ipairs(subModulesPaths) do
					-- check for ../ or ..\
					if string.find(subModulePath, "%.%.[\\/]") then
						error(string.format('children cannot be loaded from a parent directory!! Attempted path: %s', subModulePath), 2)
					end

					if not string.find(subModulePath, path, nil, true) then
						subModulesPaths[idx] = path .. subModulePath
					end
				end
				loadFromList(subModulesPaths, vfsMode, loaderCallback, loadedWupgets, newWupget)
			end

			recursionDepth = recursionDepth - 1
		else
			Spring.Echo(string.format("[Wupget Loader] hit maximum recursion depth (%s) when loading child wupgets!", MAX_RECURSION_DEPTH))
		end

	elseif isDir then
		local mainFileCandidates = VFS.DirList(fileOrDirPath, "*.main.lua", vfsMode)

		if #mainFileCandidates >= 2 then
			Spring.Echo(string.format("[Wupget Loader] more than one file found matching the pattern '*.main.lua'. skipping directory: %s", fileOrDirPath));
			return
		end

		if #mainFileCandidates == 1 then
			loadFromPath(mainFileCandidates[1], vfsMode, loaderCallback, loadedWupgets, parentWupget)
		end
	end
end

function loadFromList(wupgetPaths, vfsMode, loaderCallback, loadedWupgets, parentWupget)
	loadedWupgets = loadedWupgets or {}

	for _, path in ipairs(wupgetPaths) do
		loadFromPath(path, vfsMode, loaderCallback, loadedWupgets, parentWupget)
	end
end

function loadAllInDir(dirPath, vfsMode, loaderCallback, loadedWupgets, parentWupget)
	loadedWupgets = loadedWupgets or {}

	local lastChar = string.sub(dirPath, -1)
	if lastChar ~= "/" and lastChar ~= "\\" then
		dirPath = dirPath .. "/"
	end

	local toLoad = VFS.DirList(dirPath, "*.lua", vfsMode)
	table.append(toLoad, VFS.SubDirs(dirPath, "*", vfsMode))
	loadFromList(toLoad, vfsMode, loaderCallback, loadedWupgets, parentWupget)
end

return {
	loadFromPath = loadFromPath,
	loadFromList = loadFromList,
	loadAllInDir = loadAllInDir
}
