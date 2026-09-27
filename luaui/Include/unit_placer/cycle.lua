-- The pick set of the shared unit placer (PtaQ, 2026-09-27: "pick multiple units in the
-- library holding Shift, then it cycles between them on each placement; choose whether the
-- cycling is a b c or random"). Pure: the owner (the mission editor's ROSTER, the terraform
-- brush's UNITS tool) keeps one, asks it what to arm with, and advances it after each drop.
--
--     local Cycle = VFS.Include("luaui/Include/unit_placer/cycle.lua")
--     local set = Cycle.new({ "armpw", "armrock", "armham" }, "abc")
--     set.current()  --> "armpw"
--     set.advance()  --> "armrock"
--
-- ORDER ("abc") walks the set in the order it was picked and wraps. RANDOM draws from the
-- whole set every time, the one just placed included, as a die would. The random source is
-- handed in (a function returning 1..n) so a spec can pin it; the default seeds math.random
-- from os.clock once, because BAR does not seed it (memory: bar-math-random-not-seeded).

local Cycle = {}

Cycle.ORDER = "abc"
Cycle.RANDOM = "random"
Cycle.MODES = { Cycle.ORDER, Cycle.RANDOM }

local seeded = false
local function defaultDraw(n)
	if not seeded then
		seeded = true
		math.randomseed(math.floor((os.clock() * 1000003) % 2147483647) + os.time())
		math.random()
	end
	return math.random(n)
end

--- The mode a stored or typed value means; anything unknown is ORDER.
function Cycle.mode(value)
	return value == Cycle.RANDOM and Cycle.RANDOM or Cycle.ORDER
end

--- The other mode (the library's CYCLE chip flips between the two).
function Cycle.other(mode)
	return Cycle.mode(mode) == Cycle.RANDOM and Cycle.ORDER or Cycle.RANDOM
end

--- A plain click picks one; Shift+click adds a name to the set, or takes it back out if it
--- is in it already. The set keeps the order names were added in. Never empties by a Shift
--- click on its last member: that is a plain pick of it (the set is what gets placed, and an
--- empty one would place nothing while the tile still reads as chosen).
---@param names string[] the set now
---@param name string
---@param additive boolean Shift held
---@return string[] the new set (a fresh table)
function Cycle.toggle(names, name, additive)
	if not additive then
		return { name }
	end
	local out, found = {}, false
	for _, existing in ipairs(names or {}) do
		if existing == name then
			found = true
		else
			out[#out + 1] = existing
		end
	end
	if not found then
		out[#out + 1] = name
	end
	if #out == 0 then
		return { name }
	end
	return out
end

--- A set to cycle through.
---@param names string[]
---@param mode string|nil "abc" (default) or "random"
---@param draw fun(n: integer): integer|nil the random source, 1..n
function Cycle.new(names, mode, draw)
	local self = {}
	local list = {}
	for index, name in ipairs(names or {}) do
		list[index] = name
	end
	mode = Cycle.mode(mode)
	draw = draw or defaultDraw
	local index = 1 ---@type number
	if mode == Cycle.RANDOM and #list > 1 then
		index = math.max(1, math.min(#list, draw(#list) or 1))
	end

	--- The name to arm with now (nil for an empty set).
	function self.current()
		return list[index]
	end

	--- Move on after a drop, and say what to arm with next.
	function self.advance()
		if #list > 1 then
			if mode == Cycle.RANDOM then
				index = math.max(1, math.min(#list, draw(#list) or 1))
			else
				index = index % #list + 1
			end
		end
		return list[index]
	end

	function self.names()
		return list
	end

	function self.mode()
		return mode
	end

	function self.size()
		return #list
	end

	--- More than one name: a drop moves on to another type.
	function self.cycles()
		return #list > 1
	end

	return self
end

return Cycle
