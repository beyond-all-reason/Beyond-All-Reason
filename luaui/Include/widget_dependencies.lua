-- What a widget shares with others through WG, read out of its source.
--
-- Widgets hand each other functionality through tables on WG - gui_fonthandler sets WG.fonts, and
-- dozens of widgets reach for it - and nothing declares any of that. So it is read out of the
-- source: the keys a widget assigns (`provides`), the keys it reaches for (`uses`), and whether it
-- ever checks a key is there before using it (`guards`). A use that is never checked breaks when
-- whatever provides it is switched off; a checked one only loses what it offered.
--
-- A static reading, so a good guess rather than a fact. A key looked up through a variable is
-- invisible, and "checks it" means the file tests it somewhere, not that every use is covered. The
-- LuaUI files a widget VFS.Includes are read as well, since a fair part of what widgets share is
-- reached through those.
--
-- Pure Lua with no engine calls: `load(path)` hands back an included file's source, or nil, so the
-- same code runs in the game and in the offline tests. It reads every widget there is, so it finds
-- things with plain searches and reads patterns only where those land. A pattern search over the
-- seven megabytes of widget source, or a copy of it with the comments taken out, is what made the
-- first version take a third of a second.

local M = {}

local find, sub, match, byte, lower = string.find, string.sub, string.match, string.byte, string.lower

-- Directory variables the game sets for widgets, for include paths built from them.
---@type table<string, string>
local KNOWN_DIRS = { LUAUI_DIRNAME = "LuaUI/" }

local MAX_INCLUDE_DEPTH = 4

-- Each included file is read once and its reading kept, since LuaShader.lua and the like are
-- included by dozens of widgets. `false` while a file is being read, so one that includes itself
-- back gets nothing rather than looping.
local included = {}

function M.clearCache()
	included = {}
end

-- Whether a byte is one a Lua name can be made of.
local function isNameByte(b)
	return b ~= nil and (b == 95 or (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122))
end

-- Whether position `s` comes after a `--` on the same line. Comments name keys all the time
-- without using them. Read backwards to the start of the line, a few dozen bytes, rather than
-- copying every source without its comments first.
local function inComment(src, s)
	local i = s - 1
	while i > 1 do
		local b = byte(src, i)
		if b == 10 or b == 13 then
			return false
		end
		if b == 45 and byte(src, i - 1) == 45 then
			return true
		end
		i = i - 1
	end

	return false
end

-- Calls fn(start, finish, key) for every WG.name, WG["name"] or WG['name'] outside a comment. A
-- match inside a longer name, like myWG.x, is not WG.
local function eachKey(src, fn)
	local init = 1
	while true do
		local s = find(src, "WG", init, true)
		if not s then
			return
		end
		init = s + 2
		if not isNameByte(byte(src, s - 1)) then
			local _, e, key = find(src, "^%.([%a_][%w_]*)", s + 2)
			if not e then
				_, e, key = find(src, "^%[%s*[\"']([%a_][%w_]*)[\"']%s*%]", s + 2)
			end
			if e then
				init = e + 1
				if not inComment(src, s) then
					fn(s, e, key)
				end
			end
		end
	end
end

-- Whether the name between `s` and `e` is being tested rather than used: followed by then, and,
-- or or a comparison; behind a not, or handed to type(); or the last operand inside a condition,
-- as in `not (a or WG.x)`. `if WG.x.y then` is not a test of WG.x - it fails without it - and
-- neither is passing it along to something else.
local function isCheck(src, s, e)
	local after = sub(src, e + 1, e + 16)
	if
		find(after, "^%s*then%f[^%w_]")
		or find(after, "^%s*and%f[^%w_]")
		or find(after, "^%s*or%f[^%w_]")
		or find(after, "^%s*[~=]=")
	then
		return true
	end
	local before = sub(src, math.max(1, s - 16), s - 1)
	if find(before, "%f[%w_]not%s*%(?%s*$") or find(before, "%f[%w_]type%s*%(%s*$") then
		return true
	end

	return find(after, "^%s*%)") ~= nil
		and (find(before, "%f[%w_]or%s*$") ~= nil or find(before, "%f[%w_]and%s*$") ~= nil)
end

-- The variable a key is put in on a line of its own, like `local grid = WG.gridmenu`, or nil.
local function assignedTo(src, s, e)
	if not find(sub(src, e + 1, e + 8), "^%s*;?[ \t]*[\r\n]") then
		return nil
	end

	return match(sub(src, math.max(1, s - 48), s - 1), "([%a_][%w_]*)%s*=%s*$")
end

-- Whether a variable a key was put in is tested somewhere, so `if not grid then return end` checks
-- WG.gridmenu through the variable.
local function variableChecked(src, name)
	local init, length = 1, #name
	while true do
		local s = find(src, name, init, true)
		if not s then
			return false
		end
		local e = s + length - 1
		if
			not isNameByte(byte(src, s - 1))
			and not isNameByte(byte(src, e + 1))
			and isCheck(src, s, e)
			and not inComment(src, s)
		then
			return true
		end
		init = e + 1
	end
end

-- The LuaUI files a source includes, where the path can be read without running anything: a
-- literal, or a literal added to a directory variable the file sets itself or the game provides.
-- Only LuaUI's own: gamedata and config tables are large and cannot reach WG.
local function includePaths(src)
	local paths = {}
	local init = 1
	while true do
		local s, e = find(src, "VFS.Include", init, true)
		if not s then
			return paths
		end
		init = e + 1
		if not inComment(src, s) then
			local _, _, path = find(src, "^%s*[%(,]%s*[\"']([^\"'\r\n]+)[\"']", e + 1)
			if not path then
				local _, _, name, rest = find(src, "^%s*[%(,]%s*([%a_][%w_]*)%s*%.%.%s*[\"']([^\"'\r\n]+)[\"']", e + 1)
				if name then
					local base = KNOWN_DIRS[name]
						or match(src, "%f[%w_]" .. name .. '%s*=%s*"([^"\r\n]*)"')
						or match(src, "%f[%w_]" .. name .. "%s*=%s*'([^'\r\n]*)'")
					path = base and base .. rest
				end
			end
			local key = path and lower(path)
			if key and find(key, "^luaui/") and find(key, "%.lua$") then
				paths[#paths + 1] = path
			end
		end
	end
end

local function merge(into, from)
	for key in pairs(from) do
		into[key] = true
	end
end

local function read(text, load, depth)
	local provides, uses, guards = {}, {}, {}
	local follow = load and depth < MAX_INCLUDE_DEPTH and find(text, "VFS.Include", 1, true) ~= nil
	if not (follow or find(text, "WG", 1, true)) then
		return { provides = provides, uses = uses, guards = guards }
	end

	local variables = {}
	eachKey(text, function(s, e, key)
		if find(sub(text, e + 1, e + 16), "^%s*=[^=]") then
			provides[key] = true
			return
		end
		uses[key] = true
		if isCheck(text, s, e) then
			guards[key] = true
		else
			local name = assignedTo(text, s, e)
			if name then
				variables[#variables + 1] = { name, key }
			end
		end
	end)
	for _, v in ipairs(variables) do
		if not guards[v[2]] and variableChecked(text, v[1]) then
			guards[v[2]] = true
		end
	end

	if follow then
		for _, path in ipairs(includePaths(text)) do
			local key = lower(path)
			local result = included[key]
			if result == nil then
				included[key] = false
				local ok, source = pcall(load, path)
				result = ok and type(source) == "string" and read(source, load, depth + 1) or false
				included[key] = result
			end
			if result then
				merge(provides, result.provides)
				merge(uses, result.uses)
				merge(guards, result.guards)
			end
		end
	end

	return { provides = provides, uses = uses, guards = guards }
end

-- Reads a widget's source, and the LuaUI sources it includes, into three sets of WG keys.
function M.scan(src, load)
	local result = read(src, load, 0)
	-- What a widget provides is not something it depends on, even where it reads it back.
	for key in pairs(result.provides) do
		result.uses[key] = nil
	end

	return result
end

return M
