local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local function setup(donorCount, donorCap, takerCount, takerCap)
	local caps = { [0] = donorCap, [1] = takerCap, [2] = 500 }
	local units, rules, attempts, notices = {}, {}, {}, {}
	for id = 1, donorCount do
		units[id] = 0
	end
	for id = donorCount + 1, donorCount + takerCount do
		units[id] = 1
	end
	local take ---@type function
	local limiter ---@type table
	local function teamUnits(team)
		local result = {}
		for id, owner in pairs(units) do
			if owner == team then
				result[#result + 1] = id
			end
		end
		table.sort(result)
		return result
	end
	local env = SpecEnv.new({
		gadget = {},
		BAR = { Utilities = { Gametype = {
			IsSinglePlayer = function()
				return false
			end,
		} } },
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
			AddChatAction = function(_, _, fn)
				take = fn
			end,
			RemoveChatAction = function() end,
		},
		Spring = {
			GetModOptions = function()
				return {}
			end,
			GetGaiaTeamID = function()
				return 2
			end,
			GetTeamList = function(ally)
				return ally == 0 and { 0, 1 } or { 0, 1, 2 }
			end,
			GetTeamInfo = function(id, _)
				return id, 0, false, false, "", id == 2 and 1 or 0
			end,
			GetTeamLuaAI = function()
				return ""
			end,
			GetPlayerList = function(team)
				return (team == nil or team == 1) and { 0 } or {}
			end,
			GetPlayerInfo = function()
				return "taker", true, false, 1, 0, 0
			end,
			GetTeamRulesParam = function(team, key)
				return rules[team] and rules[team][key]
			end,
			SetTeamRulesParam = function(team, key, value)
				rules[team] = rules[team] or {}
				rules[team][key] = value
			end,
			GetTeamUnits = teamUnits,
			GetUnitTeam = function(id)
				return units[id]
			end,
			GetTeamUnitCount = function(team)
				return #teamUnits(team)
			end,
			GetTeamMaxUnits = function(team)
				return caps[team]
			end,
			IsCheatingEnabled = function()
				return false
			end,
			GetTeamResources = function()
				return 0, 1000, 0, 0, 0, 1
			end,
			ShareTeamResource = function() end,
			TransferTeamMaxUnits = function(from, to, amount)
				if amount < 0 or amount > caps[from] or caps[from] - amount < #teamUnits(from) then
					return false
				end
				caps[from], caps[to] = caps[from] - amount, caps[to] + amount
				return true
			end,
		},
	})
	local veto, linked, throw = false, false, false
	-- Engine contract: adjust capacity before AllowUnitTransfer, then callbacks around the owner change.
	env.Spring.TransferUnit = function(id, to, given, adjust)
		if throw then
			error("transfer failed")
		end
		local from = units[id]
		attempts[#attempts + 1] = id
		if adjust then
			caps[from], caps[to] = (caps[from] - 1) % 4294967296, caps[to] + 1
		end
		if not limiter:AllowUnitTransfer(id, 1, from, to, given == false) or veto then
			if adjust then
				caps[from], caps[to] = (caps[from] + 1) % 4294967296, caps[to] - 1
			end
			return false
		end
		if linked and id == 1 then
			env.Spring.TransferUnit(2, to, false)
		end
		units[id] = to
		limiter:UnitGiven(id, 1, to, from)
		return true
	end
	SpecEnv.include(env, "luarules/gadgets/game_prevent_excessive_share.lua")
	limiter = env.gadget
	env.gadget = {}
	SpecEnv.include(env, "luarules/gadgets/cmd_idle_players.lua")
	env.gadget:Initialize()
	env.gadget:RecvLuaMsg(env.validationIdle .. "idleplayers 0", 0)
	env.gadget:GameFrame(15)
	return {
		caps = caps,
		units = units,
		attempts = attempts,
		notices = notices,
		env = env,
		take = function()
			take("take2", "0", { "0" }, 0)
		end,
		veto = function(value)
			veto = value
		end,
		linked = function()
			linked = true
		end,
		throw = function()
			throw = true
		end,
		canShare = function(id)
			return limiter:AllowUnitTransfer(id, 1, units[id], 1, false)
		end,
	}
end

describe("take2 capacity accounting", function()
	it("moves one occupied slot per unit when both teams are full", function()
		local t = setup(2, 2, 2, 2)
		t.take()
		assert.same({ 1, 1, 1, 1 }, t.units)
		assert.same({ [0] = 0, [1] = 4, [2] = 500 }, t.caps)
	end)

	it("takes a unit with zero source capacity without inventing cap", function()
		local t = setup(1, 0, 4, 4)
		t.take()
		assert.equal(1, t.units[1])
		assert.same({ [0] = 0, [1] = 4, [2] = 500 }, t.caps)
	end)

	it("uses available capacity when the taker already exceeds its cap", function()
		local t = setup(1, 2, 3, 2)
		t.take()
		assert.equal(1, t.units[1])
		assert.same({ [0] = 0, [1] = 4, [2] = 500 }, t.caps)
	end)

	it("accounts for linked units moved by UnitTaken without transferring them twice", function()
		local t = setup(2, 2, 2, 2)
		t.linked()
		t.take()
		assert.same({ 1, 1, 1, 1 }, t.units)
		assert.same({ [0] = 0, [1] = 4, [2] = 500 }, t.caps)
		assert.same({ 1, 2 }, t.attempts)
		assert.same({ "TeamTaken", 0, 0, 2, 0, 0 }, t.notices[#t.notices])
	end)

	it("does not move capacity for a rejected transfer, even if the taker exceeds its cap", function()
		local t = setup(1, 2, 3, 2)
		t.veto(true)
		t.take()
		assert.equal(0, t.units[1])
		assert.same({ [0] = 2, [1] = 2, [2] = 500 }, t.caps)
		assert.is_false(t.canShare(1))
	end)

	it("clears the take exception when a transfer raises an error", function()
		local t = setup(1, 2, 2, 2)
		t.throw()
		assert.has_error(t.take)
		assert.is_false(t.canShare(1))
	end)

	it("retains unused donor capacity when the taker has space", function()
		local t = setup(1, 2, 0, 2)
		t.take()
		assert.equal(1, t.units[1])
		assert.same({ [0] = 2, [1] = 2, [2] = 500 }, t.caps)
	end)
end)
