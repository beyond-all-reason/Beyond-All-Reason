local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function setup()
	local units = { [10] = 2, [11] = 2, [20] = 1 }
	local caps = { [1] = 4, [2] = 4, [3] = 4, [99] = 500 }
	local teamRules, unitRules, actions, notices = {}, {}, {}, {}
	local players = {
		[1] = { active = true, team = 1 },
		[2] = { active = false, team = 2 },
		[3] = { active = true, team = 3 },
	}
	local gadgets = {}
	local veto, linked, fail = {}, {}, false
	local resourcesShared = 0
	local function teamUnits(team)
		local result = {}
		for unit, owner in pairs(units) do
			if owner == team then
				result[#result + 1] = unit
			end
		end
		table.sort(result)
		return result
	end
	local env = SpecEnv.new({
		gadget = {},
		BAR = {
			Utilities = {
				Gametype = {
					IsSinglePlayer = function()
						return false
					end,
				},
				CanTeamReceiveUnits = function(team, amount)
					return #teamUnits(team) + amount <= caps[team]
				end,
			},
		},
		string = {
			randomString = function()
				return "xx"
			end,
		},
		SendToUnsynced = function(...)
			notices[#notices + 1] = { ... }
		end,
		gadgetHandler = {
			IsSyncedCode = function()
				return true
			end,
			AddChatAction = function(_, name, fn)
				actions[name] = fn
			end,
			RemoveChatAction = function(_, name)
				actions[name] = nil
			end,
		},
		Spring = {
			GetModOptions = function()
				return { maxunits = 4 }
			end,
			GetGameFrame = function()
				return 30
			end,
			GetGaiaTeamID = function()
				return 99
			end,
			GetTeamList = function(ally)
				if ally == 1 then
					return { 1, 2 }
				end
				if ally == 2 then
					return { 3 }
				end
				return { 1, 2, 3, 99 }
			end,
			GetTeamInfo = function(id)
				if caps[id] then
					return id, id, false, false, "", id == 3 and 2 or 1
				end
			end,
			GetTeamLuaAI = function()
				return ""
			end,
			GetPlayerList = function()
				return { 1, 2, 3 }
			end,
			GetPlayerInfo = function(id)
				local player = players[id]
				if player then
					return "player" .. id,
						player.active,
						player.spec or false,
						player.team,
						player.team == 3 and 2 or 1,
						0
				end
			end,
			GetTeamRulesParam = function(id, key)
				return teamRules[id] and teamRules[id][key]
			end,
			SetTeamRulesParam = function(id, key, value)
				teamRules[id] = teamRules[id] or {}
				teamRules[id][key] = value
			end,
			GetUnitRulesParam = function(id, key)
				return unitRules[id] and unitRules[id][key]
			end,
			SetUnitRulesParam = function(id, key, value)
				unitRules[id] = unitRules[id] or {}
				unitRules[id][key] = value
			end,
			GetTeamUnits = teamUnits,
			GetTeamUnitCount = function(team)
				return #teamUnits(team)
			end,
			GetUnitTeam = function(id)
				return units[id]
			end,
			GetTeamMaxUnits = function(team)
				return caps[team]
			end,
			TransferTeamMaxUnits = function(from, to, amount)
				assert.is_true(amount > 0)
				if caps[from] - amount < #teamUnits(from) then
					return false
				end
				caps[from], caps[to] = caps[from] - amount, caps[to] + amount
				return true
			end,
			IsCheatingEnabled = function()
				return false
			end,
			GetTeamResources = function()
				return 100, 1000, 0, 0, 0, 1
			end,
			ShareTeamResource = function()
				resourcesShared = resourcesShared + 1
			end,
		},
	})
	env.Spring.TransferUnit = function(id, to, given)
		if fail then
			error("transfer failed")
		end
		local from = units[id]
		local unitDefID = env.Spring.GetUnitDefID and env.Spring.GetUnitDefID(id) or 1
		if not from or from == to then
			return false
		end
		for _, gadget in ipairs(gadgets) do
			if gadget.AllowUnitTransfer and not gadget:AllowUnitTransfer(id, unitDefID, from, to, given == false) then
				return false
			end
		end
		if veto[id] then
			return false
		end
		units[id] = to
		-- Simulate nested UnitGiven transfers before the limiter receives the parent's callback.
		for _, child in ipairs(linked[id] or {}) do
			if units[child] ~= to then
				env.Spring.TransferUnit(child, to, given)
			end
		end
		for _, gadget in ipairs(gadgets) do
			if gadget.UnitGiven then
				gadget:UnitGiven(id, unitDefID, to, from)
			end
		end
		return true
	end
	local function loadGadget(path)
		env.gadget = {}
		SpecEnv.include(env, path)
		local gadget = env.gadget
		gadget:Initialize()
		gadgets[#gadgets + 1] = gadget
		return gadget
	end
	local limiter = loadGadget("luarules/gadgets/game_prevent_excessive_share.lua")
	local idle = loadGadget("luarules/gadgets/cmd_idle_players.lua")
	local dynamic = loadGadget("luarules/gadgets/game_dynamic_maxunits.lua")
	local function refresh()
		for id in pairs(players) do
			idle:RecvLuaMsg(env.validationIdle .. "idleplayers 0", id)
		end
		idle:GameFrame(30)
	end
	refresh()
	local function command(name, target, player)
		local words = target == nil and {} or { tostring(target) }
		actions[name](name, table.concat(words, " "), words, player or 1)
	end
	return {
		units = units,
		caps = caps,
		rules = teamRules,
		unitRules = unitRules,
		players = players,
		veto = veto,
		linked = linked,
		notices = notices,
		env = env,
		idle = idle,
		reload = function()
			idle:Shutdown()
			env.gadget = {}
			SpecEnv.include(env, "luarules/gadgets/cmd_idle_players.lua")
			idle = env.gadget
			gadgets[2] = idle
			idle:Initialize()
			refresh()
		end,
		dynamic = dynamic,
		limiter = limiter,
		loadGadget = loadGadget,
		command = command,
		refresh = refresh,
		resume = function()
			players[2].active = true
			refresh()
		end,
		destroy = function(id)
			for _, gadget in ipairs(gadgets) do
				if gadget.UnitDestroyed then
					gadget:UnitDestroyed(id, env.Spring.GetUnitDefID and env.Spring.GetUnitDefID(id) or 1, units[id])
				end
			end
			units[id], unitRules[id] = nil, nil
		end,
		resourceCount = function()
			return resourcesShared
		end,
		fail = function(value)
			fail = value
		end,
	}
end

describe("Giving back taken units", function()
	it("keeps provenance and player-list availability across a gadget reload", function()
		local t = setup()
		t.command("take2", 2)
		t.resume()
		t.reload()
		assert.equal(2, t.rules[1].givebackUnits2)
		t.command("giveback", 2)
		assert.equal(2, t.units[10])
		assert.equal(2, t.units[11])
	end)

	it("returns only surviving taken units, keeping newly built units and all resources", function()
		local t = setup()
		t.command("take2", 2)
		assert.equal(8, t.caps[1])
		assert.equal(0, t.caps[2])
		t.destroy(11) -- lost original unit
		t.units[21] = 1 -- built after take
		t.resume()
		t.dynamic:GameFrame(30)
		assert.equal(0, t.caps[2]) -- reconnect alone does not restore cap
		local resources = t.resourceCount()
		t.command("giveback", 2)
		assert.equal(2, t.units[10])
		assert.equal(1, t.units[20])
		assert.equal(1, t.units[21])
		assert.equal(resources, t.resourceCount())
		assert.equal(0, t.rules[2].unitCapRestorePending)
		assert.equal(0, t.rules[1].givebackUnits2)
		assert.equal(1, t.caps[2])
		t.dynamic:GameFrame(60)
		assert.equal(4, t.caps[2])
		assert.equal(4, t.caps[1])
	end)

	it("returns a full army beyond an equal share and transfers exactly the needed slots", function()
		local t = setup()
		t.units[12], t.units[13] = 2, 2
		t.caps[1], t.caps[2] = 1, 4
		t.command("take2", 2)
		t.resume()
		t.command("giveback", 2)
		for id = 10, 13 do
			assert.equal(2, t.units[id])
		end
		assert.equal(4, t.caps[2])
		assert.equal(1, t.caps[1])
	end)

	it("a successful manual share unlocks redistribution and clears that unit's provenance", function()
		local t = setup()
		t.command("take2", 2)
		t.resume()
		assert.is_true(t.env.Spring.TransferUnit(10, 2))
		assert.equal(-1, t.unitRules[10].takenFromTeam)
		assert.equal(0, t.rules[2].unitCapRestorePending)
		t.dynamic:GameFrame(60)
		assert.equal(4, t.caps[2])
	end)

	it("does not allow an enemy, spectator, inactive giver, self or invalid target", function()
		local t = setup()
		t.command("take2", 2)
		for _, target in ipairs({ 1, 2, 3, 999, -1, 1.5, "invalid" }) do
			t.command("giveback", target)
		end
		t.command("giveback", nil)
		t.resume()
		t.players[1].spec = true
		t.refresh()
		t.command("giveback", 2)
		t.players[1].spec = false
		t.players[1].active = false
		t.refresh()
		t.command("giveback", 2)
		assert.equal(1, t.units[10])
		assert.equal(1, t.units[11])
		assert.equal(0, t.caps[2])
		assert.equal(1, t.rules[2].unitCapRestorePending)
	end)

	it("keeps rejected units available for retry and never duplicates capacity", function()
		local t = setup()
		t.command("take2", 2)
		t.resume()
		t.veto[10], t.veto[11] = true, true
		t.command("giveback", 2)
		assert.equal(8, t.caps[1])
		assert.equal(0, t.caps[2])
		assert.equal(2, t.rules[1].givebackUnits2)
		assert.equal(1, t.rules[2].unitCapRestorePending)
		assert.same({ "NotifyError", 1, "giveBackBlocked" }, t.notices[#t.notices])
		t.dynamic:GameFrame(60)
		assert.equal(0, t.caps[2])
		t.veto[10], t.veto[11] = nil, nil
		t.command("giveback", 2)
		t.command("giveback", 2)
		assert.equal(6, t.caps[1])
		assert.equal(2, t.caps[2])
	end)

	it("does not unlock redistribution after all taken units were lost", function()
		local t = setup()
		t.command("take2", 2)
		t.resume()
		t.destroy(10)
		assert.equal(1, t.rules[1].givebackUnits2)
		t.destroy(11)
		assert.equal(0, t.rules[1].givebackUnits2)
		t.command("giveback", 2)
		t.dynamic:GameFrame(60)
		assert.equal(8, t.caps[1])
		assert.equal(0, t.caps[2])
		assert.equal(1, t.rules[2].unitCapRestorePending)
		assert.same({ "NotifyError", 1, "nothingToGiveBack" }, t.notices[#t.notices])
		-- A newly built unit can still be shared manually to restart the player.
		t.units[21] = 1
		assert.is_true(t.env.Spring.TransferUnit(21, 2))
		assert.equal(0, t.rules[2].unitCapRestorePending)
		t.dynamic:GameFrame(90)
		assert.equal(4, t.caps[2])
	end)

	it("does not offer or unlock giveback after a capacity-only take", function()
		local t = setup()
		t.destroy(10)
		t.destroy(11)
		t.command("take2", 2)
		t.resume()
		assert.equal(0, t.rules[1].givebackUnits2)
		t.command("giveback", 2)
		t.dynamic:GameFrame(60)
		assert.equal(0, t.caps[2])
		assert.equal(1, t.rules[2].unitCapRestorePending)
	end)

	it("unlocks on a partial giveback and keeps only the rejected unit available", function()
		local t = setup()
		t.command("take2", 2)
		t.resume()
		t.veto[11] = true
		t.command("giveback", 2)
		assert.equal(2, t.units[10])
		assert.equal(1, t.units[11])
		assert.equal(1, t.rules[1].givebackUnits2)
		assert.equal(0, t.rules[2].unitCapRestorePending)
	end)

	it("removes availability as taken units are returned manually", function()
		local t = setup()
		t.command("take2", 2)
		t.resume()
		assert.is_true(t.env.Spring.TransferUnit(10, 2))
		assert.equal(1, t.rules[1].givebackUnits2)
		assert.is_true(t.env.Spring.TransferUnit(11, 2))
		assert.equal(0, t.rules[1].givebackUnits2)
	end)

	it("does not transfer new drones through a carrier's nested callbacks", function()
		local t = setup()
		t.linked[10] = { 11 }
		t.command("take2", 2)
		t.resume()
		t.units[21] = 1
		t.linked[10] = { 11, 21 }
		t.command("giveback", 2)
		assert.equal(2, t.units[10])
		assert.equal(2, t.units[11])
		assert.equal(1, t.units[21])
		assert.equal(2, t.caps[2])
		assert.equal(6, t.caps[1])
	end)

	it("clears giveback restrictions after a transfer error", function()
		local t = setup()
		t.command("take2", 2)
		t.resume()
		t.fail(true)
		assert.has_error(function()
			t.command("giveback", 2)
		end)
		t.fail(false)
		assert.is_true(t.env.Spring.TransferUnit(20, 2)) -- own unit, normal share
	end)

	it("does not return units lost through capture and later recaptured", function()
		local t = setup()
		t.command("take2", 2)
		t.resume()
		assert.is_true(t.env.Spring.TransferUnit(10, 3, false))
		assert.equal(1, t.rules[1].givebackUnits2)
		assert.is_true(t.env.Spring.TransferUnit(10, 1, false))
		t.command("giveback", 2)
		assert.equal(1, t.units[10])
		assert.equal(2, t.units[11])
	end)

	it("a second take pauses redistribution again and records the returned units", function()
		local t = setup()
		t.command("take2", 2)
		t.resume()
		t.command("giveback", 2)
		t.players[2].active = false
		t.refresh()
		t.command("take2", 2)
		assert.equal(1, t.rules[2].unitCapRestorePending)
		assert.equal(2, t.unitRules[10].takenFromTeam)
		assert.equal(8, t.caps[1])
		assert.equal(0, t.caps[2])
	end)
end)

describe("Taken units completed with construction helpers", function()
	local function setupHelpers(mex)
		local t = setup()
		local env, sp = t.env, t.env.Spring
		local defs = { [10] = 1, [11] = 4, [20] = 4 }
		local created, attachments = {}, {}
		env.UnitDefs = {
			{
				id = 1,
				name = "chassis",
				extractsMetal = 0,
				customParams = {
					attached_con_turret = "turret",
					attached_con_turret_mex = mex and "extractor" or nil,
				},
			},
			{ id = 2, name = "turret", extractsMetal = 0, customParams = {} },
			{ id = 3, name = "extractor", extractsMetal = 1, customParams = {} },
			{ id = 4, name = "ordinary", extractsMetal = 0, customParams = {} },
		}
		env.UnitDefNames = { chassis = env.UnitDefs[1], turret = env.UnitDefs[2], extractor = env.UnitDefs[3] }
		sp.GetUnitDefID = function(id)
			return defs[id]
		end
		sp.GetUnitPieceMap = function()
			return { attach = 1 }
		end
		sp.GetUnitPosition = function()
			return 0, 0, 0
		end
		sp.GetUnitDefDimensions = function()
			return { radius = 1 }
		end
		sp.GetAllUnits = function()
			return {}
		end
		sp.GetUnitNeutral = function()
			return false
		end
		sp.GetUnitHealth = function()
			return 100
		end
		sp.GetUnitCosts = function()
			return 1, 100, 100
		end
		sp.GetUnitBuildFacing = function()
			return 0
		end
		sp.GetUnitIsDead = function(id)
			return t.units[id] == nil
		end
		sp.GetUnitMetalExtraction = function()
			return 1
		end
		sp.AreTeamsAllied = function(a, b)
			return a ~= 3 and b ~= 3
		end
		sp.GetTeamMaxUnits = function(team)
			return t.caps[team], #sp.GetTeamUnits(team)
		end
		sp.CreateUnit = function(def, _, _, _, _, team)
			local id = 30 + #created
			defs[id] = type(def) == "number" and def or env.UnitDefNames[def].id
			t.units[id] = team
			created[#created + 1] = id
			return id
		end
		sp.DestroyUnit = t.destroy
		sp.UnitAttach = function(host, child)
			attachments[child] = host
		end
		for _, name in ipairs({
			"SetUnitBlocking",
			"SetUnitNoSelect",
			"SetUnitHealth",
			"SetUnitNoMinimap",
			"SetUnitIconDraw",
			"SetUnitNoDraw",
			"CallCOBScript",
		}) do
			sp[name] = function() end
		end
		env.GG.UnitAttributes = { SetUnitAttribute = function() end }
		env.gadgetHandler.RegisterAllowCommand = function() end
		local path = mex and "unit_attached_con_turret_mex.lua" or "unit_attached_con_turret.lua"
		local gadget = t.loadGadget("luarules/gadgets/" .. path)
		local function finish()
			gadget:UnitFinished(10, 1, t.units[10])
			if mex then
				gadget:GameFrame(33)
			end
		end
		return t, created, attachments, finish
	end

	for _, mex in ipairs({ false, true }) do
		local kind = mex and "replacement extractor pair" or "attached turret"
		it("returns the " .. kind .. " created after taking its unfinished chassis", function()
			local t, created, attachments, finish = setupHelpers(mex)
			t.command("take2", 2)
			finish()
			assert.equal(mex and 2 or 1, #created)
			for _, id in ipairs(created) do
				assert.equal(2, t.env.Spring.GetUnitRulesParam(id, "takenFromTeam"))
			end
			assert.equal(3, t.rules[1].givebackUnits2)
			t.reload()
			assert.equal(3, t.rules[1].givebackUnits2)
			t.resume()
			t.command("giveback", 2)
			for _, id in ipairs(created) do
				assert.equal(2, t.units[id])
			end
			for child, host in pairs(attachments) do
				assert.equal(t.units[host], t.units[child])
			end
			assert.equal(0, t.rules[1].givebackUnits2)
			assert.equal(0, t.rules[2].unitCapRestorePending)
		end)

		it("keeps a newly built " .. kind .. " with the taker", function()
			local t, created, _, finish = setupHelpers(mex)
			t.command("take2", 2)
			-- A fresh chassis built by the taker has no takeover provenance.
			t.destroy(10)
			t.units[10] = 1
			finish()
			t.resume()
			t.command("giveback", 2)
			assert.equal(2, t.units[11])
			for _, id in ipairs(created) do
				assert.equal(1, t.units[id])
			end
		end)
	end
end)
