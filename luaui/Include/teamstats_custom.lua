-- The team stats panel's custom categories: the player's own lists of graphs, each graph with
-- the settings it is drawn with, shown above the built-in categories in the sidebar. The
-- table takes a custom category's graphs as its columns. One ships with the game - the
-- overview - editable like any other and put back as it came by a reset.
--
--   local custom = VFS.Include("luaui/Include/teamstats_custom.lua").new(ctx)
--   custom.setConfig(saved)                     -- or nothing, for the shipped overview alone
--   custom.add("overview", "metalProduced", settings)
--   saved = custom.getConfig()
--
-- ctx: GROUPS and groupByKey (the panel's, custom categories are kept at their front),
-- COLUMNS, i18n.

local M = {}

-- The key of the category that ships with the game.
local SHIPPED_KEY = "overview"

-- What it holds - one page of twelve: every team's shape and when things happened to them;
-- the economy each built (metal, energy, build power) and what it has on the field; what
-- it produced and fought with; where its metal comes from; how well it traded, which weighs
-- a kill by what it cost where unit counts and damage do not; and how fast it played. A
-- ranked game adds the standing, second: it is left out where there is none.
local SHIPPED_STATS = {
	"profile",
	"ranking",
	"timeline",
	"metalProduced",
	"energyProduced",
	"buildPower",
	"unitValue",
	"frontLine",
	"damageDealt",
	"incomeMetal",
	"composition",
	"valueEfficiency",
	"actionsPerMinute",
}

-- The charts that are not one column's: listed by the page, never a table column.
---@type table<string, boolean>
local CHART_ONLY = {
	ranking = true,
	incomeMetal = true,
	incomeEnergy = true,
	tech = true,
	profile = true,
	timeline = true,
	composition = true,
	wind = true,
	losses = true,
	built = true,
	lostTo = true,
	killedWith = true,
	unitReport = true,
}

-- The first field of a category written out as text: what it is, and in which version.
local FORMAT = "teamstats1"

-- A graph's settings as they come when nothing says otherwise: the switches' defaults.
local function defaultSettings()
	return { grouped = true, share = false, milestones = true, off = {} }
end

-- A copy of settings, so a graph never shares a table with the switches it was made from.
local function copySettings(from)
	local off = {}
	for kind, on in pairs(from and from.off or {}) do
		if on then
			off[kind] = true
		end
	end
	return {
		grouped = not from or from.grouped ~= false,
		share = from and from.share == true or false,
		milestones = not from or from.milestones ~= false,
		off = off,
	}
end

function M.new(ctx)
	---@type table<string, any>
	local custom = {
		-- The categories in their order, each { key, name?, shipped?, graphs = { ... } }.
		---@type table[]
		list = {},
		nextId = 1,
		nextGraph = 1,
	}

	local function newGraph(stat, settings)
		local s = copySettings(settings)
		local graph = {
			id = custom.nextGraph,
			stat = stat,
			grouped = s.grouped,
			share = s.share,
			milestones = s.milestones,
			off = s.off,
		}
		custom.nextGraph = custom.nextGraph + 1
		return graph
	end

	local function shipped()
		local graphs = {}
		for _, stat in ipairs(SHIPPED_STATS) do
			graphs[#graphs + 1] = newGraph(stat, defaultSettings())
		end
		return { key = SHIPPED_KEY, shipped = true, graphs = graphs }
	end

	-- What a category is called: the name it was given, the overview's own otherwise.
	function custom.label(category)
		if category.name and category.name ~= "" then
			return category.name
		end
		if category.shipped then
			return ctx.i18n("ui.teamStats.group.overview")
		end
		return ctx.i18n("ui.teamStats.custom.defaultName", { number = category.number or 1 })
	end

	-- The categories put where the panel reads its groups: at the front of GROUPS, each
	-- with the columns its graphs give the table.
	function custom.apply()
		local groups, byKey = ctx.GROUPS, ctx.groupByKey
		for i = #groups, 1, -1 do
			if groups[i].custom then
				byKey[groups[i].key] = nil
				table.remove(groups, i)
			end
		end
		for i, category in ipairs(custom.list) do
			local columns = {}
			local seen = {}
			for _, graph in ipairs(category.graphs) do
				if not CHART_ONLY[graph.stat] and ctx.COLUMNS[graph.stat] and not seen[graph.stat] then
					columns[#columns + 1] = graph.stat
					seen[graph.stat] = true
				end
			end
			category.columns = columns
			category.custom = true
			category.label = custom.label(category)
			table.insert(groups, i, category)
			byKey[category.key] = category
		end
	end

	function custom.byKey(key)
		for _, category in ipairs(custom.list) do
			if category.key == key then
				return category
			end
		end
		return nil
	end

	function custom.graphById(id)
		for _, category in ipairs(custom.list) do
			for _, graph in ipairs(category.graphs) do
				if graph.id == id then
					return graph, category
				end
			end
		end
		return nil
	end

	-- A new category, at the end of the custom ones, named after its number until renamed:
	-- the lowest one no other category has, so a deleted one's number comes back first.
	function custom.create()
		local taken = {}
		for _, category in ipairs(custom.list) do
			if category.number then
				taken[category.number] = true
			end
		end
		local number = 1
		while taken[number] do
			number = number + 1
		end
		local category = { key = "custom" .. custom.nextId, number = number, graphs = {} }
		custom.nextId = custom.nextId + 1
		custom.list[#custom.list + 1] = category
		custom.apply()
		return category
	end

	-- A graph added with the settings it is drawn with right now.
	function custom.add(key, stat, settings)
		local category = custom.byKey(key)
		if not category then
			return nil
		end
		local graph = newGraph(stat, settings)
		category.graphs[#category.graphs + 1] = graph
		custom.apply()
		return graph
	end

	function custom.removeGraph(id)
		local _, category = custom.graphById(id)
		if not category then
			return false
		end
		for i, graph in ipairs(category.graphs) do
			if graph.id == id then
				table.remove(category.graphs, i)
				break
			end
		end
		custom.apply()
		return true
	end

	-- Moves a graph up (-1) or down (1) its category's list; false at either end.
	function custom.moveGraph(id, delta)
		local _, category = custom.graphById(id)
		if not category then
			return false
		end
		local graphs = category.graphs
		for i, graph in ipairs(graphs) do
			if graph.id == id then
				local j = i + delta
				if j < 1 or j > #graphs then
					return false
				end
				graphs[i], graphs[j] = graphs[j], graphs[i]
				custom.apply()
				return true
			end
		end
		return false
	end

	-- Moves a graph in front of another of its category's, or to the end without one: where
	-- a drag lets it go.
	function custom.placeGraph(id, beforeId)
		local _, category = custom.graphById(id)
		if not category then
			return false
		end
		local graphs = category.graphs
		local moved
		for i, graph in ipairs(graphs) do
			if graph.id == id then
				moved = table.remove(graphs, i)
				break
			end
		end
		local at = #graphs + 1
		for i, graph in ipairs(graphs) do
			if graph.id == beforeId then
				at = i
				break
			end
		end
		table.insert(graphs, at, moved)
		custom.apply()
		return true
	end

	function custom.rename(key, name)
		local category = custom.byKey(key)
		if not category then
			return false
		end
		name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
		category.name = name ~= "" and name or nil
		custom.apply()
		return true
	end

	-- Moves a category up (-1) or down (1) the custom list; false at either end.
	function custom.move(key, delta)
		for i, category in ipairs(custom.list) do
			if category.key == key then
				local j = i + delta
				if j < 1 or j > #custom.list then
					return false
				end
				custom.list[i], custom.list[j] = custom.list[j], custom.list[i]
				custom.apply()
				return true
			end
		end
		return false
	end

	-- A category of the player's own goes; the overview is put back as it shipped instead.
	function custom.delete(key)
		for i, category in ipairs(custom.list) do
			if category.key == key and not category.shipped then
				table.remove(custom.list, i)
				custom.apply()
				return true
			end
		end
		return false
	end

	function custom.reset(key)
		for i, category in ipairs(custom.list) do
			if category.key == key and category.shipped then
				custom.list[i] = shipped()
				custom.apply()
				return true
			end
		end
		return false
	end

	----------------------------------------------------------------
	-- Shared as text
	----------------------------------------------------------------

	-- A category as one line, for the clipboard: its name, then each graph's stat, its
	-- switches as letters (g grouped, s % of total, m milestones) and the milestone kinds it
	-- leaves off, e.g. "teamstats1;Eco;metalProduced,gs;damageDealt,m,nuke+lrpc".
	function custom.export(key)
		local category = custom.byKey(key)
		if not category then
			return nil
		end
		local parts = { FORMAT, (custom.label(category):gsub("[;,]", " ")) }
		for _, graph in ipairs(category.graphs) do
			local flags = (graph.grouped and "g" or "")
				.. (graph.share and "s" or "")
				.. (graph.milestones and "m" or "")
			local off = {}
			for kind, on in pairs(graph.off) do
				if on then
					off[#off + 1] = kind
				end
			end
			table.sort(off)
			parts[#parts + 1] = graph.stat .. "," .. flags .. (#off > 0 and ("," .. table.concat(off, "+")) or "")
		end
		return table.concat(parts, ";")
	end

	-- Text read back as a category, or nil for text that is not one. A stat this game does
	-- not have is left out.
	function custom.parse(text)
		if type(text) ~= "string" then
			return nil
		end
		text = text:gsub("^%s+", ""):gsub("%s+$", "")
		local fields = {}
		for field in (text .. ";"):gmatch("([^;]*);") do
			fields[#fields + 1] = field
		end
		if fields[1] ~= FORMAT or #fields < 2 then
			return nil
		end
		local out = { name = fields[2]:sub(1, 32), graphs = {} }
		for i = 3, #fields do
			local stat, flags, off = fields[i]:match("^(%w+),?([gsm]*),?([%w+]*)$")
			if stat and (CHART_ONLY[stat] or ctx.COLUMNS[stat]) then
				local offSet = {}
				for kind in off:gmatch("[^+]+") do
					offSet[kind] = true
				end
				out.graphs[#out.graphs + 1] = {
					stat = stat,
					grouped = flags:find("g", 1, true) ~= nil,
					share = flags:find("s", 1, true) ~= nil,
					milestones = flags:find("m", 1, true) ~= nil,
					off = offSet,
				}
			end
		end
		return out
	end

	-- A parsed category made a new one, at the end of the player's own.
	-- A name no category has yet: pasted next to the one it was copied off, "Overview"
	-- comes in as "Overview 2".
	local function freeName(name)
		local taken = {}
		for _, category in ipairs(custom.list) do
			taken[custom.label(category):lower()] = true
		end
		local n, free = 1, name
		while taken[free:lower()] do
			n = n + 1
			free = name .. " " .. n
		end
		return free
	end

	function custom.import(parsed)
		local name = parsed.name ~= "" and freeName(parsed.name) or nil
		local category = custom.create()
		category.name = name
		for _, g in ipairs(parsed.graphs) do
			category.graphs[#category.graphs + 1] = newGraph(g.stat, g)
		end
		custom.apply()
		return category
	end

	----------------------------------------------------------------
	-- Kept between games
	----------------------------------------------------------------

	-- Whether the overview holds what it shipped with, as it shipped: then it is kept as
	-- that rather than as a list, so a game that ships another one reaches it too.
	local function asShipped(category)
		if not category.shipped or #category.graphs ~= #SHIPPED_STATS then
			return false
		end
		for i, graph in ipairs(category.graphs) do
			if
				graph.stat ~= SHIPPED_STATS[i]
				or not graph.grouped
				or graph.share
				or not graph.milestones
				or next(graph.off)
			then
				return false
			end
		end
		return true
	end

	function custom.getConfig()
		local out = {}
		for _, category in ipairs(custom.list) do
			local kept = {
				key = category.key,
				name = category.name,
				shipped = category.shipped or nil,
				number = category.number,
			}
			if not asShipped(category) then
				local graphs = {}
				for _, graph in ipairs(category.graphs) do
					local off = {}
					for kind, on in pairs(graph.off) do
						if on then
							off[#off + 1] = kind
						end
					end
					table.sort(off)
					graphs[#graphs + 1] = {
						stat = graph.stat,
						grouped = graph.grouped,
						share = graph.share,
						milestones = graph.milestones,
						off = off,
					}
				end
				kept.graphs = graphs
			end
			out[#out + 1] = kept
		end
		return { categories = out, nextId = custom.nextId }
	end

	-- What was kept, checked as it is read: a stat the game no longer has is left out, and
	-- the overview is there whatever was kept.
	function custom.setConfig(data)
		custom.list = {}
		custom.nextGraph = 1
		local haveShipped = false
		if type(data) == "table" and type(data.categories) == "table" then
			custom.nextId = tonumber(data.nextId) or 1
			for _, saved in ipairs(data.categories) do
				if type(saved) == "table" and type(saved.key) == "string" then
					local category = {
						key = saved.key,
						name = type(saved.name) == "string" and saved.name or nil,
						shipped = saved.shipped == true or nil,
						number = tonumber(saved.number),
						graphs = {},
					}
					for _, g in ipairs(type(saved.graphs) == "table" and saved.graphs or {}) do
						if
							type(g) == "table"
							and type(g.stat) == "string"
							and (CHART_ONLY[g.stat] or ctx.COLUMNS[g.stat])
						then
							local off = {}
							for _, kind in ipairs(type(g.off) == "table" and g.off or {}) do
								off[kind] = true
							end
							category.graphs[#category.graphs + 1] = newGraph(g.stat, {
								grouped = g.grouped ~= false,
								share = g.share == true,
								milestones = g.milestones ~= false,
								off = off,
							})
						end
					end
					if category.shipped then
						-- Kept as it shipped: what this game ships.
						if type(saved.graphs) ~= "table" then
							category.graphs = shipped().graphs
						end
						if not haveShipped then
							haveShipped = true
							category.key = SHIPPED_KEY
							custom.list[#custom.list + 1] = category
						end
					elseif category.key ~= SHIPPED_KEY and not custom.byKey(category.key) then
						custom.list[#custom.list + 1] = category
					end
				end
			end
		end
		if not haveShipped then
			table.insert(custom.list, 1, shipped())
		end
		-- A new category's key is never one already kept, whatever the count read back said.
		for _, category in ipairs(custom.list) do
			local n = tonumber(category.key:match("^custom(%d+)$"))
			if n and n >= custom.nextId then
				custom.nextId = n + 1
			end
		end
		custom.apply()
	end

	custom.SHIPPED_KEY = SHIPPED_KEY
	custom.CHART_ONLY = CHART_ONLY
	custom.copySettings = copySettings

	-- The overview is there from the start, before any settings are read.
	custom.setConfig(nil)
	return custom
end

return M
