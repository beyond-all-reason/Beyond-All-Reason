-- forward func declarations

---@param fileOrDirPath string
---@param vfsMode
---@param loaderCallback fun(filePath:string, parentModule: table | nil): table, string[] | boolean
---@param loadedModules string[] | nil
---@param parentModule table | nil
local function loadModule(fileOrDirPath, vfsMode, loaderCallback, loadedModules, parentModule) end

---@param modulePaths string[]
---@param vfsMode
---@param loaderCallback fun(filePath:string, parentModule: table | nil): table, string[] | boolean
---@param loadedModules string[] | nil
---@param parentModule table | nil
local function loadModulesFromList(modulePaths, vfsMode, loaderCallback, loadedModules, parentModule) end

---@param dirPath string
---@param vfsMode
---@param loaderCallback fun(filePath:string, parentModule: table | nil): table, string[] | boolean
---@param loadedModules string[] | nil
---@param parentModule table | nil
local function loadAllModulesInDir(dirPath, vfsMode, loaderCallback, loadedModules, parentModule) end

local recursionDepth = 0
local MAX_RECURSION_DEPTH = 10

function loadModule(fileOrDirPath, vfsMode, loaderCallback, loadedModules, parentModule)
	if loadedModules ~= nil and table.contains(loadedModules, fileOrDirPath) then
		return
	end

	local isScript = string.find(fileOrDirPath, "[%g ]-%.lua") and VFS.FileExists(fileOrDirPath)
	local isDir = not isScript -- and VFS.DirExists(filePath)

	if isScript then
		local ok, newModule, subModulesPaths = pcall(loaderCallback, fileOrDirPath, parentModule)

		if not ok then
			Spring.Log("script module loader", "fatal", newModule)
		end

		if newModule == nil then
			return
		end

		local _,_,path = string.find(fileOrDirPath, "(.*[\\/:])[^\\/:]*$")
		table.insert(loadedModules, fileOrDirPath)
		if parentModule ~= nil then
			newModule._parentModule = parentModule

			parentModule._childModules = parentModule._childModules or {}
			table.insert(parentModule._childModules, newModule)
		end

		if recursionDepth <= MAX_RECURSION_DEPTH then
			recursionDepth = recursionDepth + 1

			if type(subModulesPaths) == 'boolean' and subModulesPaths == true then
				loadAllModulesInDir(path, vfsMode, loaderCallback, loadedModules, newModule)
			elseif type(subModulesPaths) == 'table' and #subModulesPaths > 0 then
				for idx, subModulePath in ipairs(subModulesPaths) do
					if not string.find(subModulePath, path, nil, true) then
						subModulesPaths[idx] = path .. subModulePath
					end
				end
				loadModulesFromList(subModulesPaths, vfsMode, loaderCallback, loadedModules, newModule)
			end

			recursionDepth = recursionDepth - 1
		else
			Spring.Echo(string.format("[script module loader] hit maximum recursion depth (%s) when loading sub modules!", MAX_RECURSION_DEPTH))
		end

	elseif isDir then
		local moduleMainFile = VFS.DirList(fileOrDirPath, "*main.lua", vfsMode)[1]
		if moduleMainFile then
			loadModule(moduleMainFile, vfsMode, loaderCallback, loadedModules, parentModule)
		end
	end
end

function loadModulesFromList(modulePaths, vfsMode, loaderCallback, loadedModules, parentModule)
	--Spring.Echo("inside loadModulesFromList func. potential modules to load:", #modulePaths)
	loadedModules = loadedModules or {}

	for _, path in ipairs(modulePaths) do
		loadModule(path, vfsMode, loaderCallback, loadedModules, parentModule)
	end
end

function loadAllModulesInDir(dirPath, vfsMode, loaderCallback, loadedModules, parentModule)
	local lastChar = string.sub(dirPath, -1)
	if lastChar ~= "/" and lastChar ~="\\" then
		dirPath = dirPath .. "/"
	end

	--Spring.Echo("inside loadAllModulesInDir func", dirPath, vfsMode)

	local toLoad = VFS.DirList(dirPath, "*.lua", vfsMode)
	table.append(toLoad, VFS.SubDirs(dirPath, "*", vfsMode))
	loadModulesFromList(toLoad, vfsMode, loaderCallback, loadedModules, parentModule)
end

return {
	loadModule = loadModule,
	loadModulesFromList = loadModulesFromList,
	loadAllModulesInDir = loadAllModulesInDir
}
