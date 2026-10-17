-- The engine's select command, as CSelectionKeyHandler::DoSelection reads it, as data and in words.

local M = {}

---@type { id: string, arg: string? }[]
M.sources = {
	{ id = "AllMap" },
	{ id = "Visible" },
	{ id = "PrevSelection" },
	{ id = "FromMouse", arg = "number" },
	{ id = "FromMouseC", arg = "number" },
}

-- NameContain, Category and RulesParamEquals are left out: in BAR they don't select what they say.
---@type { id: string, args: string[]? }[]
M.filters = {
	{ id = "Builder" },
	{ id = "Buildoptions" },
	{ id = "Building" },
	{ id = "Aircraft" },
	{ id = "Transport" },
	{ id = "Weapons" },
	{ id = "ManualFireUnit" },
	{ id = "Resurrect" },
	{ id = "Radar" },
	{ id = "Jammer" },
	{ id = "Stealth" },
	{ id = "Cloak" },
	{ id = "Cloaked" },
	{ id = "Idle" },
	{ id = "Waiting" },
	{ id = "Guarding" },
	{ id = "Patrolling" },
	{ id = "InHotkeyGroup" },
	{ id = "InPrevSel" },
	{ id = "InGroup", args = { "whole" } },
	{ id = "RelativeHealth", args = { "number" } },
	{ id = "AbsoluteHealth", args = { "number" } },
	{ id = "WeaponRange", args = { "number" } },
	{ id = "IdMatches", args = { "text" } },
}

---@type { id: string, arg: string? }[]
M.conclusions = {
	{ id = "SelectAll" },
	{ id = "SelectOne" },
	{ id = "SelectClosestToCursor" },
	{ id = "SelectNum", arg = "whole" },
	{ id = "SelectPart", arg = "number" },
}

local function byId(list)
	local out = {}
	for _, entry in ipairs(list) do
		out[entry.id] = entry
	end

	return out
end

---@type table<string, { id: string, arg: string? }>
local sourceById = byId(M.sources)
---@type table<string, { id: string, args: string[]? }>
local filterById = byId(M.filters)
---@type table<string, { id: string, arg: string? }>
local conclusionById = byId(M.conclusions)

M.sourceById, M.filterById, M.conclusionById = sourceById, filterById, conclusionById

-- Walks the string the way the engine's ReadToken and ReadDelimiter do.
local function reader(text)
	local pos = 1
	local r = {}

	function r.token()
		local stop = text:find("[_+]", pos) or (#text + 1)
		local token = text:sub(pos, stop - 1)
		pos = stop

		return token
	end

	function r.delimiter()
		local d = text:sub(pos, pos)
		pos = pos + 1

		return d
	end

	return r
end

-- The parts of a select command, or nil when the builder can't read it.
function M.parse(action)
	if type(action) ~= "string" then
		return nil
	end

	local body = action:match("^%s*select%s+(%S+)%s*$") or action:match("^(%S+)$")
	if not body then
		return nil
	end

	local r = reader(body)
	local spec = { filters = {}, clear = false }

	spec.source = r.token()
	local source = sourceById[spec.source]
	if not source then
		return nil
	end
	if source.arg then
		r.delimiter()
		spec.sourceArg = r.token()
	end
	if r.delimiter() ~= "+" then
		return nil
	end

	while true do
		local d = r.delimiter()
		if d == "+" then
			break
		end
		if d ~= "_" then
			return nil
		end

		local name = r.token()
		local negate = false
		if name == "Not" then
			negate = true
			r.delimiter()
			name = r.token()
		end

		local filter = filterById[name]
		if not filter then
			return nil
		end

		local entry = { id = name, negate = negate, args = {} }
		for i = 1, filter.args and #filter.args or 0 do
			r.delimiter()
			entry.args[i] = r.token()
		end
		spec.filters[#spec.filters + 1] = entry
	end

	r.delimiter()
	local conclusion = r.token()
	if conclusion == "ClearSelection" then
		spec.clear = true
		r.delimiter()
		conclusion = r.token()
	end
	if not conclusionById[conclusion] then
		return nil
	end
	spec.conclusion = conclusion
	if conclusionById[conclusion].arg then
		r.delimiter()
		spec.conclusionArg = r.token()
	end

	return spec
end

-- The bind action for a spec, spelled the way the shipped presets spell theirs.
function M.format(spec)
	local out = { "select ", spec.source }
	if spec.sourceArg then
		out[#out + 1] = "_" .. spec.sourceArg
	end
	out[#out + 1] = "+"
	for _, f in ipairs(spec.filters or {}) do
		out[#out + 1] = f.negate and "_Not_" or "_"
		out[#out + 1] = f.id
		for _, arg in ipairs(f.args or {}) do
			out[#out + 1] = "_" .. arg
		end
	end
	out[#out + 1] = "+"
	if spec.clear then
		out[#out + 1] = "_ClearSelection"
	end
	out[#out + 1] = "_" .. spec.conclusion
	if spec.conclusionArg then
		out[#out + 1] = "_" .. spec.conclusionArg
	end
	out[#out + 1] = "+"

	return table.concat(out)
end

-- A filter with a value can be taken as Is and as Not at once, which is how a range is written.
function M.bothWays(id)
	return filterById[id].args ~= nil
end

-- Whether the builder can hold a spec without changing it.
function M.editable(spec)
	local seen = {}
	for _, f in ipairs(spec.filters) do
		if f.id ~= "IdMatches" then
			local way = f.id .. (f.negate and "-" or "+")
			local oneWay = not M.bothWays(f.id)
			if seen[way] or (oneWay and seen[f.id]) then
				return false
			end
			seen[way], seen[f.id] = true, true
		end
	end

	return true
end

-- Filters in any order select the same units, so an edit that only reorders them is no edit.
function M.sameSelection(a, b)
	local function canonical(action)
		local spec = M.parse(action)
		if not spec then
			return action
		end

		local keys = {}
		for i, f in ipairs(spec.filters) do
			keys[i] = { f = f, key = f.id .. (f.negate and "-" or "+") .. table.concat(f.args or {}, "_") }
		end
		table.sort(keys, function(x, y)
			return x.key < y.key
		end)
		for i, k in ipairs(keys) do
			spec.filters[i] = k.f
		end

		return M.format(spec)
	end

	return canonical(a) == canonical(b)
end

-- A value the engine reads as one token: nothing that would end it early, nothing it would lose.
function M.validArg(value, kind)
	if type(value) ~= "string" or value == "" or value:find("[%s_+]") then
		return false
	end
	if kind == "whole" then
		return value:find("^%d+$") ~= nil
	end

	return kind ~= "number" or tonumber(value) ~= nil
end

local KEY = "ui.keybinds.select."

local function filterWords(f, t)
	local words = t(KEY .. "filter." .. f.id, { value = (f.args or {})[1] })

	return f.negate and t(KEY .. "not", { filter = words }) or words
end

function M.describe(spec, t)
	---@type fun(key: string, values: table?): string
	t = t or BAR.I18N
	local conclusion = t(KEY .. "conclusion." .. spec.conclusion, { value = spec.conclusionArg })
	local source = t(KEY .. "source." .. spec.source, { value = spec.sourceArg })

	-- The engine ORs plain IdMatches and ANDs the rest, so those names read as one choice.
	local filters, units, unitsAt = {}, {}, nil
	for _, f in ipairs(spec.filters or {}) do
		if f.id == "IdMatches" and not f.negate then
			units[#units + 1] = filterWords(f, t)
			unitsAt = unitsAt or #filters + 1
			filters[unitsAt] = units[1]
		else
			filters[#filters + 1] = filterWords(f, t)
		end
	end
	if #units > 1 then
		local last = table.remove(units)
		filters[unitsAt] = t(KEY .. "anyOf", { units = table.concat(units, ", "), last = last })
	end

	local words
	if #filters > 0 then
		words = t(KEY .. "summary", { conclusion = conclusion, filters = table.concat(filters, ", "), source = source })
	else
		words = t(KEY .. "summaryAll", { conclusion = conclusion, source = source })
	end
	if not spec.clear then
		words = t(KEY .. "keepSelection", { summary = words })
	end

	return words
end

return M
