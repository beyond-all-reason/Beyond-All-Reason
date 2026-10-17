-- The tables and graph categories the player makes on the team stats panel, kept in a file of
-- their own besides the widget's config. Every game version saves that config under the same
-- widget name, and a replay runs the version it was recorded with: a panel from before these
-- existed writes its config without them on the way out, and they were gone the next game. No
-- older version touches this file.
--
--   local store = require("luaui/Include/teamstats_store").new("LuaUI/Config/teamstats.json")
--   data = store.merge(data)                         -- the config as it is read back
--   store.write(data.tables, data.customCategories)  -- the config as it is saved
--   store.loaded()                                   -- whether merge ran

local M = {}

local Json = Json or require("common/luaUtilities/json")

-- Each part: the list it keeps, and what a shipped entry holds once the player changed it.
local PARTS = {
	tables = { "list", "columns" },
	customCategories = { "categories", "graphs" },
}

-- Whether a part holds anything the player made: an entry of their own, or the shipped one changed
-- or renamed. Left out, or saved as it ships, it does not.
local function holdsOwn(part, spec)
	if type(part) ~= "table" or type(part[spec[1]]) ~= "table" then
		return false
	end
	for _, entry in ipairs(part[spec[1]]) do
		if type(entry) == "table" and (not entry.shipped or entry[spec[2]] ~= nil or entry.name ~= nil) then
			return true
		end
	end
	return false
end

function M.new(path)
	local store = {}
	-- What the file holds, as read or last written; whether there is a file at all.
	local text, exists
	local loaded = false

	function store.loaded()
		return loaded
	end

	local function read()
		local content = VFS.LoadFile(path)
		text, exists = nil, content ~= nil
		if not content then
			return nil
		end
		local ok, decoded = pcall(Json.decode, content)
		if not ok or type(decoded) ~= "table" then
			Spring.Log("TeamStats", LOG.WARNING, "could not read " .. path .. ", using the widget config")
			return nil
		end
		text = content
		return decoded
	end

	-- The config read back, with the file's part wherever the config holds nothing of the player's
	-- own and the file does. A part the config does hold is the file's or one changed since, in a
	-- version that kept it in the config alone.
	function store.merge(data)
		loaded = true
		local kept = read()
		if not kept then
			return data
		end
		local merged
		for key, spec in pairs(PARTS) do
			if not holdsOwn(data[key], spec) and holdsOwn(kept[key], spec) then
				if not merged then
					merged = {}
					for k, v in pairs(data) do
						merged[k] = v
					end
				end
				merged[key] = kept[key]
			end
		end
		return merged or data
	end

	-- Written when it changed, and, with no file yet, only once there is something of the player's.
	-- Not before the file was read: it could hold what this config lost.
	function store.write(tablesConfig, categoriesConfig)
		if not loaded then
			return
		end
		if
			not exists
			and not holdsOwn(tablesConfig, PARTS.tables)
			and not holdsOwn(categoriesConfig, PARTS.customCategories)
		then
			return
		end
		local ok, encoded = pcall(Json.encode, { tables = tablesConfig, customCategories = categoriesConfig })
		if not ok or encoded == text then
			return
		end
		local file = io.open(path, "w")
		if not file then
			Spring.Log("TeamStats", LOG.WARNING, "could not write " .. path)
			return
		end
		file:write(encoded)
		file:close()
		text, exists = encoded, true
	end

	return store
end

return M
