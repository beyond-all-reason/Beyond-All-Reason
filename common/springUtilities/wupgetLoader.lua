---@return string, string basename, path
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
---@field license string license from GetInfo()
---@field enabled string enabled from GetInfo(), true if the wupget is to be enabled by default
---@field handler string handler field from GetInfo(), true if the wupget wants access to the widget/gadget handler
---@field filename string Full path to file from content root including file name
---@field basename string Name of the file
---@field path string Path to directory containing the wupget
---@field childPaths nil | string[] | boolean local paths to children files or directories **OR** boolean true to signal that all other .lua files in this folder are children of this wupget. Result of GetChildPaths() callin.
---@field parent nil | WupgetInfo parent info
---@field children nil | WupgetInfo[] child infos

---@param wupget
---@param filename
---@return WupgetInfo
local function extractInfo(wupget, filename)
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
		for k, v in pairs(wupget:GetInfo() or {}) do
			info[k] = v
		end

		info.name = info.name or basename
		info.layer = info.layer or 0

		if wupget.GetChildPaths then
			info.childPaths = wupget:GetChildPaths(path)
		end
	end

	return info;
end

--- sorts wupgets by layer, then orderList entry, then name
---
--- child wupgets are placed after their parent wupgets and sorted amongst themselves
---@return table[] a new list of sorted wupgets
local function sortedWupgetList(wupgets, orderList, infoAccessor)

	-- prepare tables and local functions

	---@type table[]
	local resultsList = {}
	---@type table<table, WupgetInfo>
	local wupgetToInfo = {}
	---@type table<string, table>
	local childrenToAdd = {}

	for _, wupget in ipairs(wupgets) do
		---@type WupgetInfo
		local info = infoAccessor(wupget)
		wupgetToInfo[wupget] = info
		if info.parent == nil then
			resultsList[#resultsList + 1] = wupget
		else
			childrenToAdd[info.filename] = wupget
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
			local currentChildren = {}

			for _, childInfo in ipairs(parentInfo.children) do
				local child = childrenToAdd[childInfo.filename]
				if child ~= nil then
					currentChildren[#currentChildren + 1] = child
					childrenToAdd[childInfo.filename] = nil
				end
			end

			table.sort(currentChildren, infoComp)

			for childIdx = #currentChildren, 1, -1 do
				local child = currentChildren[childIdx]
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

	if #childrenToAdd > 0 then
		Spring.Log('Wupget Loader :: sortWupgets()', LOG.ERROR, "Not all child wupgets were placed into sorted list! Count: " .. #childrenToAdd)
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


function loadFromPath(fileOrDirPath, vfsMode, loaderCallback, loadedFilePaths, parentInfo)
	loadedFilePaths = loadedFilePaths or {}
	if loadedFilePaths[fileOrDirPath] then
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

		if parentInfo then
			newInfo.parent = parentInfo
			parentInfo.children = parentInfo.children or {}
			table.insert(parentInfo.children, newInfo)
		end

		local path = newInfo.path
		local childPaths = newInfo.childPaths
		loadedFilePaths[fileOrDirPath] = true

		if childPaths ~= nil then
			if type(childPaths) == 'boolean' and childPaths == true then
				loadAllInDir(path, vfsMode, loaderCallback, loadedFilePaths, newInfo)
			elseif type(childPaths) == 'table' and #childPaths > 0 then
				for idx, childPath in ipairs(childPaths) do
					-- check for ../ or ..\
					if string.find(childPath, "%.%.[\\/]") then
						error(string.format('children cannot be loaded from a parent directory!! Attempted path: %s', childPath), 2)
					end

					if not string.find(childPath, path, nil, true) then
						childPaths[idx] = path .. childPath
					end
				end
				loadFromList(childPaths, vfsMode, loaderCallback, loadedFilePaths, newInfo)
			end
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
