-- recoil-lua cannot load C modules, so busted takes these instead. LUA_INIT runs this file first.

package.preload["mediator"] = function(...)
	-- mediator_lua reads a subscriber's id from the address in stock Lua's tostring.
	local idCount = 0
	local function tostring()
		idCount = idCount + 1
		return string.format("table: 0x%08x", idCount)
	end
	local loader = package.loaders[2]("mediator")
	setfenv(loader, setmetatable({ tostring = tostring }, { __index = _G }))
	return loader(...)
end

package.preload["system"] = function()
	return { gettime = os.time, monotime = os.clock }
end

package.preload["term.core"] = function()
	local function isatty()
		return false
	end
	return { isatty = isatty }
end

package.preload["lfs"] = function()
	local modes = {}
	local entryNames = {} ---@type table<string, string[]?>

	local function addEntry(path, mode)
		if modes[path] then
			return
		end
		modes[path] = mode
		if mode == "directory" then
			entryNames[path] = { ".", ".." }
		end
		if path ~= "." then
			local parent, name = path:match("^(.*)/([^/]+)$")
			parent = parent or "."
			addEntry(parent, "directory")
			table.insert(entryNames[parent] --[[@as string[] ]], name or path)
		end
	end

	for path in io.lines(os.getenv("SPEC_FILE_LIST")) do
		addEntry(path, "file")
	end

	local root = (os.getenv("PWD") --[[@as string]]):gsub("\\", "/")

	local function getListedPath(path)
		path = path:gsub("\\", "/"):gsub("/%.?$", "")
		if path == "" or path == root then
			return "."
		elseif path:sub(1, #root + 1) == root .. "/" then
			return path:sub(#root + 2)
		end
		return (path:gsub("^%./", ""))
	end

	local function attributes(path, name)
		local mode = modes[getListedPath(path)]
		if not mode then
			return nil, "No such file or directory: " .. path
		end
		return name == "mode" and mode or { mode = mode }
	end

	local function dir(path)
		local names = assert(entryNames[getListedPath(path)], "No such directory: " .. path)
		local index = 0
		return function()
			index = index + 1
			return names[index]
		end
	end

	local function currentdir()
		return root
	end

	local function chdir(path)
		assert(getListedPath(path) == ".", path)
		return true
	end

	return { attributes = attributes, dir = dir, currentdir = currentdir, chdir = chdir }
end
