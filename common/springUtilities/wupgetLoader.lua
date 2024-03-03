-- returns:  fileName, dirPath
local function pathParts(fullpath)
	local _, _, basename = string.find(fullpath, "([^\\/:]*)$")
	local _, _, path = string.find(fullpath, "(.*[\\/:])[^\\/:]*$")
	return basename or "", path or ""
end

---@class WupgetInfo a copy of the table returned by the GetInfo() callin with additional file system and parent/child hierarchy info
---@field name string name from GetInfo()
---@field layer number layer from GetInfo()
---@field desc string description from GetInfo()
---@field author string author from GetInfo()
---@field date string date from GetInfo()
---@field filename string Full path to file from content root including file name
---@field basename string Name of the file
---@field path string Path to directory containing the wupget
---@field childPaths nil | string[] | boolean local paths to children files or directories **OR** boolean true to signal that all other .lua files in this folder are children of this wupget. Result of GetChildPaths() callin.
---@field parent nil | WupgetInfo parent info
---@field children nil | WupgetInfo[] child infos

---@param wupget
---@param filename
---@param parentInfo
---@return WupgetInfo
local function extractInfo(wupget, filename, parentInfo)
	local basename, path = pathParts(filename)
	local info = {
		filename = filename,
		basename = basename,
		path = path
	}

	if wupget.GetInfo == nil then
		info.name = basename
		info.layer = 0
	else
		local wpInfo = wupget:GetInfo()
		info.name = wpInfo.name or basename
		info.layer = wpInfo.layer or 0
		info.desc = wpInfo.desc or ""
		info.author = wpInfo.author or ""
		info.date = wpInfo.date or ""
		info.license = wpInfo.license or ""
		info.enabled = wpInfo.enabled or false

		if wupget.GetChildPaths then
			info.childPaths = wupget:GetChildPaths()
		end

		if parentInfo ~= nil then
			info.parent = parentInfo
			-- don't insert the new info into the parentInfo just yet,
			-- the current wupget may still fail the loading process
		end
	end

	return info;
end

--- sorts wupgets by layer, then orderList entry, then name
---
--- child wupgets _will_ be placed after their parent wupgets
---@return table[] a new list of sorted wupgets
local function sortedWupgetList(wupgets, orderList, infoAccessor)

	-- prepare tables and local functions

	---@type table[]
	local resultsList = {}
	---@type table<WupgetInfo, table>
	local infoToWupget = {}
	---@type table<table, WupgetInfo>
	local wupgetToInfo = {}

	for _, wupget in ipairs(wupgets) do
		local info = infoAccessor(wupget)
		infoToWupget[info] = wupget
		wupgetToInfo[wupget] = info
		if not info.parent then
			resultsList[#resultsList + 1] = wupget
		end
	end

	local function infoComp(w1, w2)
		local info1 = wupgetToInfo[w1]
		local info2 = wupgetToInfo[w2]

		local l1 = info1.layer
		local l2 = info2.layer
		if l1 ~= l2 then
			return (l1 < l2)
		end
		local n1 = info1.name
		local n2 = info2.name
		local o1 = orderList[n1]
		local o2 = orderList[n2]
		if o1 ~= o2 then
			return (o1 < o2)
		else
			return (n1 < n2)
		end
	end

	local function insertChildren(parentIndex, parentInfo)
		if parentInfo.children and #parentInfo.children > 0 then
			local childrenToAdd = {}

			for _, childInfo in ipairs(parentInfo.children) do
				local child = infoToWupget[childInfo]
				if child ~= nil then
					childrenToAdd[#childrenToAdd + 1] =  child
				end
			end

			table.sort(childrenToAdd, infoComp)

			for childIdx = #childrenToAdd, 1, -1 do
				local child = childrenToAdd[childIdx]
				table.insert(resultsList, parentIndex + 1, child)
				insertChildren(parentIndex + 1, wupgetToInfo[child])
			end
		end
	end

	-- sort the wupgets!
	table.sort(resultsList, infoComp)

	-- iterating backwards is the only way this loop is certain to end
	-- also makes it much easier to insert into the list
	-- since new entries will keep pushing existing ones back
	for idx = #resultsList, 1, -1 do
		insertChildren(idx, wupgetToInfo[resultsList[idx]])
	end

	return resultsList
end

-- forward declarations as these functions all rely on each other

---@param fileOrDirPath string
---@param vfsMode
---@param loaderCallback fun(filePath:string, parentInfo: WupgetInfo | nil): WupgetInfo
---@param loadedFilePaths WupgetInfo[] | nil
---@param parentInfo WupgetInfo | nil
local function loadFromPath(fileOrDirPath, vfsMode, loaderCallback, loadedFilePaths, parentInfo)
end

---@param modulePaths string[]
---@param vfsMode
---@param loaderCallback fun(filePath:string, parentInfo: WupgetInfo | nil): WupgetInfo
---@param loadedFilePaths WupgetInfo[] | nil
---@param parentInfo WupgetInfo | nil
local function loadFromList(modulePaths, vfsMode, loaderCallback, loadedFilePaths, parentInfo)
end

---@param dirPath string
---@param vfsMode
---@param loaderCallback fun(filePath:string, parentInfo: WupgetInfo | nil): WupgetInfo
---@param loadedFilePaths WupgetInfo[] | nil
---@param parentInfo WupgetInfo | nil
local function loadAllInDir(dirPath, vfsMode, loaderCallback, loadedFilePaths, parentInfo)
end


local recursionDepth = 0
local MAX_RECURSION_DEPTH = 10

function loadFromPath(fileOrDirPath, vfsMode, loaderCallback, loadedFilePaths, parentInfo)
	loadedFilePaths = loadedFilePaths or {}
	if table.contains(loadedFilePaths, fileOrDirPath) then
		return
	end

	local isScript = string.find(fileOrDirPath, "[%g ]-%.lua") and VFS.FileExists(fileOrDirPath)
	local isDir = not isScript -- and VFS.DirExists(filePath)

	if isScript then
		local ok, newInfo = pcall(loaderCallback, fileOrDirPath, parentInfo)

		if not ok then
			Spring.Log("[Wupget Loader]", LOG.ERROR, newInfo)
			return
		end

		if newInfo == nil then
			return
		end

		-- Insert the new info into the children of the parentInfo now that it was successfully loaded
		if parentInfo then
			parentInfo.children = parentInfo.children or {}
			table.insert(parentInfo.children, info)
		end

		local path = newInfo.path
		table.insert(loadedFilePaths, fileOrDirPath)

		if recursionDepth <= MAX_RECURSION_DEPTH then
			recursionDepth = recursionDepth + 1

			if type(subModulesPaths) == 'boolean' and subModulesPaths == true then
				loadAllInDir(path, vfsMode, loaderCallback, loadedFilePaths, newInfo)
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
				loadFromList(subModulesPaths, vfsMode, loaderCallback, loadedFilePaths, newWupget)
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
			loadFromPath(mainFileCandidates[1], vfsMode, loaderCallback, loadedFilePaths, parentInfo)
		end
	end
end

function loadFromList(wupgetPaths, vfsMode, loaderCallback, loadedFilePaths, parentInfo)
	loadedFilePaths = loadedFilePaths or {}

	for _, path in ipairs(wupgetPaths) do
		loadFromPath(path, vfsMode, loaderCallback, loadedFilePaths, parentInfo)
	end
end

function loadAllInDir(dirPath, vfsMode, loaderCallback, loadedFilePaths, parentInfo)
	loadedFilePaths = loadedFilePaths or {}

	local lastChar = string.sub(dirPath, -1)
	if lastChar ~= "/" and lastChar ~= "\\" then
		dirPath = dirPath .. "/"
	end

	local toLoad = VFS.DirList(dirPath, "*.lua", vfsMode)
	table.append(toLoad, VFS.SubDirs(dirPath, "*", vfsMode))
	loadFromList(toLoad, vfsMode, loaderCallback, loadedFilePaths, parentInfo)
end



return {
	extractInfo = extractInfo,
	sortedWupgetList = sortedWupgetList,
	loadFromPath = loadFromPath,
	loadFromList = loadFromList,
	loadAllInDir = loadAllInDir,
}
