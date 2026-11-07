local SpecEnv = VFS.Include("spec/support/spec_env.lua")

-- Two ally teams, the viewer's of two players.
local ALLY_OF = { [0] = 0, [1] = 0, [2] = 1 }
local STATS = {
	[0] = { damageDealt = 100, damageReceived = 50, metalExcess = 200 },
	[1] = { damageDealt = 300, damageReceived = 0, metalExcess = 10 },
	[2] = { damageDealt = 200, damageReceived = 400, metalExcess = 0 },
}

local function engineEntry(teamID)
	local s = STATS[teamID]
	return {
		frame = 900,
		metalUsed = 500,
		metalProduced = 1000,
		metalExcess = s.metalExcess,
		metalReceived = 0,
		metalSent = 0,
		energyUsed = 0,
		energyProduced = 0,
		energyExcess = 0,
		energyReceived = 0,
		energySent = 0,
		damageDealt = s.damageDealt,
		damageReceived = s.damageReceived,
		unitsProduced = 10,
		unitsDied = 2,
		unitsReceived = 0,
		unitsSent = 0,
		unitsCaptured = 0,
		unitsOutCaptured = 0,
		unitsKilled = 4,
	}
end

-- A model over the stubs, with the window's calls counted and a stand-in for the page and the tables.
---@return table<string, any> model, table<string, integer> calls, table<string, any> page, table<string, any> viewer
local function newModel()
	local viewer = { team = 0, spec = false }
	local env = SpecEnv.new({
		Spring = {
			GetGameFrame = function()
				return 900
			end,
			GetTeamStatsHistory = function(teamID, from)
				if not from then
					return 1
				end
				return { engineEntry(teamID) }
			end,
			GetTeamInfo = function(teamID)
				return teamID, teamID, false, false
			end,
			GetPlayerInfo = function(playerID)
				return "player" .. playerID, true
			end,
			GetPlayerList = function()
				return { 0, 1, 2 }
			end,
			GetTeamColor = function()
				return 0.5, 0.5, 0.5
			end,
			GetGameRulesParam = function() end,
			GetLocalTeamID = function()
				return viewer.team
			end,
			GetSpectatingState = function()
				return viewer.spec
			end,
			GetAllyTeamList = function()
				return { 0, 1 }
			end,
			GetTeamList = function(allyID)
				local out = {}
				for _, teamID in ipairs({ 0, 1, 2 }) do
					if not allyID or ALLY_OF[teamID] == allyID then
						out[#out + 1] = teamID
					end
				end
				return out
			end,
			GetGaiaTeamID = function()
				return 99
			end,
			GetTeamResources = function()
				return 100, 1000, 0, 5, 3
			end,
			GetTeamRulesParam = function() end,
			PlaySoundFile = function() end,
			GetModOptions = function()
				return { teamcolors_anonymous_mode = "disabled" }
			end,
			GetConfigInt = function(_, default)
				return default
			end,
		},
		BAR = {
			I18N = function(key)
				return key
			end,
			Utilities = {
				Gametype = {
					IsTeams = function()
						return true
					end,
					IsPvE = function()
						return false
					end,
				},
				GetAllyTeamCount = function()
					return 2
				end,
			},
		},
		WG = {},
		Game = { gameID = "spec" },
		string = {
			formatSI = function(v)
				return string.format("%.1fk", v / 1000)
			end,
		},
		UnitDefs = {},
		widgetHandler = {},
		includes = {
			["mapinfo.lua"] = {},
			["luaui/Include/teamstats_store.lua"] = {
				new = function()
					return {
						merge = function(data)
							return data
						end,
						write = function() end,
						loaded = function()
							return true
						end,
					}
				end,
			},
		},
	})
	local model = SpecEnv.include(env, "luaui/Include/teamstats_model.lua")
	local calls = {}
	local function count(name)
		return function()
			calls[name] = (calls[name] or 0) + 1
		end
	end
	local view = model.view
	view.isShown = function()
		return true
	end
	view.layout, view.layoutColumns, view.dropLists = count("layout"), count("layoutColumns"), count("dropLists")
	view.entriesChanged, view.revealEntry, view.teamsRead = count("entries"), count("reveal"), count("read")
	local page = {
		open = false,
		custom = { apply = function() end },
		invalidate = count("invalidate"),
		refresh = function() end,
		askAgain = function() end,
		setTrendRows = function() end,
		getConfig = function()
			return {}
		end,
		setConfig = function() end,
	}
	local tables = {
		list = { { key = "tableSummary" } },
		byKey = { tableSummary = { key = "tableSummary" } },
		current = "tableSummary",
		label = function(t)
			return t.key
		end,
		sortOf = function()
			return "damageDealt", false
		end,
		setSort = function() end,
		closeCard = function() end,
		getConfig = function()
			return {}
		end,
		setConfig = function() end,
	}
	model.attach(page, tables)
	return model, calls, page, viewer
end

describe("teamstats model", function()
	---@type table<string, any>, table<string, integer>, table<string, any>, table<string, any>
	local model, calls, page, viewer

	before_each(function()
		model, calls, page, viewer = newModel()
		model.refresh()
	end)

	it("reads every team under its ally team, and knows the viewer's", function()
		assert.equals(2, #model.allies)
		local allyOf = {}
		for _, ally in ipairs(model.allies) do
			for _, team in ipairs(ally.teams) do
				allyOf[team.id] = ally.id
			end
		end
		assert.same(ALLY_OF, allyOf)
		assert.equals(0, model.allies.me.id)
		assert.equals(1, calls.read)
	end)

	it("makes a band per ally team and sorts by the column, largest first", function()
		local bands = {}
		for _, row in ipairs(model.rows) do
			if row.type == "band" then
				bands[#bands + 1] = row.ally.id
			end
		end
		-- Ally 0's damage is 400 together, ally 1's 200.
		assert.same({ 0, 1 }, bands)
		assert.equals("team", model.rows[2].type)
		assert.equals(1, model.rows[2].team.id)
	end)

	it("lays the teams out flat without the grouping, sorted across the ally teams", function()
		model.filters.groupByTeam = false
		model.rebuildRows()
		local order = {}
		for _, row in ipairs(model.rows) do
			order[#order + 1] = row.team.id
		end
		assert.same({ 1, 2, 0 }, order)
	end)

	it("sorts the other way on a second press of the sorted column", function()
		model.filters.groupByTeam = false
		model.sortBy(model.COLUMNS.damageDealt)
		assert.is_true(model.sortAscending)
		assert.equals(0, model.rows[1].team.id)
	end)

	it("adds an ally team's total up, and makes its ratios from the sums", function()
		local ally = model.allies[1]
		assert.equals(400, ally.total.damageDealt)
		assert.equals(50, ally.total.damageReceived)
		assert.equals(800, ally.total.damageEfficiency)
	end)

	it("prints a value as its column says", function()
		local c = model.COLUMNS
		assert.equals("-", (model.formatCell(c.damageDealt, 0 / 0)))
		assert.equals("75%", (model.formatCell(c.damageEfficiency, 75)))
		assert.equals("1,234,567", model.formatExact(c.damageDealt, 1234567))
		local text, color = model.formatCell(c.damageDealt, 300, false, 100)
		assert.equals("+200", text)
		assert.equals(model.colors.good, color)
	end)

	it("colours a ratio against even, and excess past a share of what was produced", function()
		local c = model.COLUMNS
		assert.equals(model.colors.good, model.tone(c.damageEfficiency, {}, 150))
		assert.equals(model.colors.bad, model.tone(c.damageEfficiency, {}, 50))
		assert.is_nil(model.tone(c.damageEfficiency, {}, 100.2))
		assert.equals(model.colors.bad, model.tone(c.metalExcess, { metalExcess = 200, metalProduced = 1000 }, 200))
		assert.is_nil(model.tone(c.metalExcess, { metalExcess = 10, metalProduced = 1000 }, 10))
	end)

	it("takes a colour a window gave it", function()
		model.colors.good = "x"
		assert.equals("x", model.tone(model.COLUMNS.damageEfficiency, {}, 150))
	end)

	it("fills a row's cells for the columns a window shows", function()
		local columns = { model.COLUMNS.name, model.COLUMNS.damageDealt, model.COLUMNS.damageEfficiency }
		local row = { type = "team", team = model.allies[2].teams[1] }
		model.fillRow(row, columns)
		assert.equals(200, row.vals[2])
		assert.equals("200", row.cells[2])
		assert.equals("50%", row.cells[3])
		assert.equals(model.colors.bad, row.tones[3])
	end)

	it("marks who leads a column, for the rows as they are", function()
		model.columnFacts({ model.COLUMNS.name, model.COLUMNS.damageDealt })
		assert.equals(300, model.colMax.damageDealt)
		local top = model.allies[1].teams[1]
		assert.equals(1, top.id)
		assert.is_true(top.leads.damageDealt)
		assert.is_true(model.allies[1].leads.damageDealt)
		assert.is_nil(model.allies[2].leads.damageDealt)
	end)

	it("lists the tables and the categories in the column, and follows a pick", function()
		model.loadLabels()
		local keys = {}
		for _, e in ipairs(model.entries) do
			if e.key then
				keys[e.key] = true
			end
		end
		assert.is_true(keys.tableSummary)
		assert.is_true(keys.combat)
		assert.is_true(keys.newTable)
		assert.is_true((calls.entries or 0) > 0)
		calls.layout, calls.reveal = nil, nil
		model.selectEntry("combat", true)
		assert.equals("combat", model.selectedGroup)
		assert.is_true(page.open)
		assert.equals(1, calls.layout)
		assert.equals(1, calls.reveal)
	end)

	it("hides the gadget's columns while it is gone", function()
		assert.is_true(model.handover.shows(model.COLUMNS.buildPower))
		model.handover.on = false
		assert.is_false(model.handover.shows(model.COLUMNS.buildPower))
		assert.is_true(model.handover.shows(model.COLUMNS.damageDealt))
	end)

	it("keeps the switches, the pick and the names between loads", function()
		model.filters.bars = true
		model.selectedGroup = "combat"
		local saved = model.getConfig()
		assert.is_true(saved.bars)
		assert.equals("combat", saved.group)
		assert.equals("player0", saved.names[0])
		local other = newModel()
		other.setConfig({ gameID = "spec", bars = true, group = "combat", names = { [5] = "gone" } })
		assert.is_true(other.filters.bars)
		assert.equals("combat", other.selectedGroup)
		assert.equals("gone", other.teamControllers[5])
	end)

	it("says a cell in a table row: its whole number, under its column's name", function()
		model.loadLabels()
		local row = model.rows[2]
		local column = model.COLUMNS.damageDealt
		local tip = model.cellTip(column, row, 1234567)
		assert.equals(1, #tip.rows)
		assert.equals(model.columnTitle(column), tip.rows[1][1])
		assert.equals("1,234,567", tip.rows[1][2])
	end)

	it("says what a share is of, in rows of its own", function()
		model.loadLabels()
		model.filters.shareOfTotal = true
		model.rebuildRows()
		local row = model.rows[2]
		local column = model.COLUMNS.damageDealt
		local tip = model.cellTip(column, row, 50)
		assert.equals(3, #tip.rows)
		assert.equals(model.formatExact(column, row.team.stats.damageDealt), tip.rows[1][2])
		assert.equals("50.0%", tip.rows[2][2])
		assert.is_true(tip.rows[2].dim)
		assert.equals(model.formatExact(column, model.ratio.grand(column.key)), tip.rows[3][2])
	end)

	it("makes a player's card a table with the time in the game as its note", function()
		model.loadLabels()
		local team = model.rows[2].team
		local card = model.nameCard(team)
		assert.is_true(#card.rows > 0)
		for _, row in ipairs(card.rows) do
			assert.is_string(row[1])
			assert.is_string(row[2])
		end
		assert.is_string(card.note)
		assert.equals(card, model.nameCard(team))
	end)

	it("wraps a tooltip's text and note and leaves its rows alone", function()
		local font = {
			WrapText = function(_, text)
				return (text:gsub(" ", "\n"))
			end,
		}
		assert.equals("a\nb", model.wrapTip("a b", font, 100))
		local rows = { { "x y", "z w" } }
		local tip = { text = "a b", note = "c \255\1\2\3d e", rows = rows }
		local wrapped = model.wrapTip(tip, font, 100)
		assert.equals("a\nb", wrapped.text)
		assert.equals("c\n\255\1\2\3d\n\255\1\2\3e", wrapped.note)
		assert.equals(rows, wrapped.rows)
		assert.equals("a b", tip.text)
	end)

	it("stays on the team the viewer played when they turn spectator", function()
		viewer.spec, viewer.team = true, 2
		model.playerChanged()
		assert.equals(0, model.handover.played)
		assert.equals(0, model.allies.me.id)
	end)
end)
