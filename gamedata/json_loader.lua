--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    json_loader.lua
--  brief:   shared JSON definition file loader
--  note:    loads .json def files alongside .lua files for units, weapons,
--           and features. Requires the Json global from init.lua.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local section = 'json_loader'

--------------------------------------------------------------------------------
-- Load JSON definition files from a directory.
--
-- Each .json file must contain an object keyed by definition name, e.g.:
--   { "armck": { "health": 690, ... } }
--
-- Collision guard: errors if both name.lua and name.json exist in the same
-- directory — callers must remove one before the game will load.
--
---@param directory string  directory to scan (e.g. 'units/', 'weapons/')
---@param filterFn? fun(filename: string): boolean  optional filename filter
---@return table<string, table> defs  map of def names to def tables
--------------------------------------------------------------------------------
local function loadJsonDefs(directory, filterFn)
	local defs = {}
	local jsonFiles = VFS.DirList(directory, '*.json', nil, true)

	for _, filename in ipairs(jsonFiles) do
		if not filterFn or filterFn(filename) then
			-- Collision guard
			local luaFilename = filename:gsub('%.json$', '.lua')
			if VFS.FileExists(luaFilename) then
				local msg = 'Both .lua and .json exist: ' .. filename
					.. ' — remove one to resolve conflict'
				Spring.Log(section, LOG.ERROR, msg)
				error(msg)
			end

			local jsonStr = VFS.LoadFile(filename)
			if jsonStr then
				local success, result = pcall(Json.decode, jsonStr)
				if not success then
					Spring.Log(section, LOG.ERROR,
						'Error parsing ' .. filename .. ': ' .. tostring(result))
				elseif type(result) ~= 'table' then
					Spring.Log(section, LOG.ERROR,
						'Bad JSON table from: ' .. filename)
				else
					for defName, def in pairs(result) do
						if type(defName) == 'string' and type(def) == 'table' then
							defs[defName] = def
						else
							Spring.Log(section, LOG.ERROR,
								'Bad entry in: ' .. filename)
						end
					end
				end
			end
		end
	end

	return defs
end

return {
	loadJsonDefs = loadJsonDefs,
}
