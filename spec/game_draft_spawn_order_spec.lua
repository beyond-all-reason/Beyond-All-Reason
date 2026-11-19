local function newDraft(mode, teams)
	local messages = {}
	local teamIDs = {}
	for teamID in pairs(teams) do
		teamIDs[#teamIDs + 1] = teamID
	end
	table.sort(teamIDs)
	teamIDs[#teamIDs + 1] = 999 -- Gaia

	local spring = {
		GetModOptions = function()
			return { draft_mode = mode }
		end,
		GetGaiaTeamID = function()
			return 999
		end,
		GetTeamInfo = function(teamID)
			local team = teams[teamID]
			return teamID, nil, nil, team and team.ai or false, nil, team and team.ally or 99
		end,
		GetTeamList = function(ally)
			local result = {}
			for _, teamID in ipairs(teamIDs) do
				if not ally or (teams[teamID] and teams[teamID].ally == ally) then
					result[#result + 1] = teamID
				end
			end
			return result
		end,
		GetPlayerList = function()
			return teamIDs
		end,
		GetPlayerInfo = function(playerID)
			local team = teams[playerID]
			if team then
				return "player" .. playerID, nil, nil, playerID, nil, nil, nil, nil, nil, nil,
					{ skill = tostring(team.skill) }
			end
		end,
		SendLuaUIMsg = function(message)
			messages[#messages + 1] = message
		end,
		Log = function() end,
	}
	local mathMock = setmetatable({
		random = function(_, maximum)
			return maximum
		end,
	}, { __index = math })
	local env = setmetatable({
		Spring = spring,
		math = mathMock,
		LOG = { INFO = "info" },
		gadget = { GetInfo = function() return { name = "draft" } end },
	}, { __index = _G })
	local chunk = assert(loadfile("luarules/gadgets/game_draft_spawn_order.lua"))
	setfenv(chunk, env)
	chunk()
	env.draftModeInitialize()

	local function join(teamID)
		env.DraftRecvLuaMsg("i_have_joined_fair", teamID, false, teamID, teams[teamID].ally)
	end
	local function order(ally)
		local prefix = "DraftOrderPlayersOrder " .. ally .. " "
		for _, message in ipairs(messages) do
			if message:sub(1, #prefix) == prefix then
				local result = {}
				for playerID in message:sub(#prefix + 1):gmatch("%d+") do
					result[#result + 1] = tonumber(playerID)
				end
				return result
			end
		end
	end
	return env, join, order
end

describe("random draft spawn order", function()
	it("shares the same random skill ranks across teams regardless of join order", function()
		local _, join, order = newDraft("random", {
			[1] = { ally = 1, skill = 30 },
			[2] = { ally = 1, skill = 10 },
			[3] = { ally = 1, skill = 40 },
			[4] = { ally = 1, skill = 20 },
			[5] = { ally = 2, skill = 90 },
			[6] = { ally = 2, skill = 70 },
			[7] = { ally = 2, skill = 60 },
			[8] = { ally = 2, skill = 80 },
			[9] = { ally = 3, skill = 15 },
			[10] = { ally = 3, skill = 45 },
			[11] = { ally = 3, skill = 35 },
			[12] = { ally = 3, skill = 25 },
			[13] = { ally = 3, skill = 100, ai = true },
		})
		for _, id in ipairs({ 8, 5, 7, 6, 12, 10, 11, 9, 2, 4, 1, 3 }) do
			join(id)
		end
		-- The shared permutation is 4th, 1st, 2nd, 3rd.
		assert.same({ 2, 3, 1, 4 }, order(1))
		assert.same({ 7, 5, 8, 6 }, order(2))
		assert.same({ 9, 10, 11, 12 }, order(3))
	end)

	it("preserves relative rank order for smaller teams and breaks skill ties by team ID", function()
		local _, join, order = newDraft("random", {
			[1] = { ally = 1, skill = 40 },
			[2] = { ally = 1, skill = 30 },
			[3] = { ally = 1, skill = 20 },
			[4] = { ally = 1, skill = 10 },
			[5] = { ally = 2, skill = 20 },
			[6] = { ally = 2, skill = 20 },
			[7] = { ally = 2, skill = 0 },
		})
		for _, id in ipairs({ 7, 6, 5, 4, 3, 2, 1 }) do
			join(id)
		end
		assert.same({ 4, 1, 2, 3 }, order(1))
		assert.same({ 5, 6, 7 }, order(2))
	end)

	it("keeps late joiners last when a team votes to start early", function()
		local env, join, order = newDraft("random", {
			[1] = { ally = 1, skill = 40 },
			[2] = { ally = 1, skill = 30 },
			[3] = { ally = 1, skill = 20 },
			[4] = { ally = 1, skill = 10 },
		})
		join(1)
		join(2)
		join(3)
		env.DraftRecvLuaMsg("vote_wait_too_long", 1, false, 1, 1)
		env.DraftRecvLuaMsg("vote_wait_too_long", 2, false, 2, 1)
		assert.same({ 1, 2, 3, 4 }, order(1))
	end)

	it("does not change captain or skill draft ordering", function()
		local teams = {
			[1] = { ally = 1, skill = 40 },
			[2] = { ally = 1, skill = 30 },
			[3] = { ally = 1, skill = 20 },
			[4] = { ally = 1, skill = 10 },
		}
		local _, joinCaptain, captainOrder = newDraft("captain", teams)
		local _, joinSkill, skillOrder = newDraft("skill", teams)
		for _, id in ipairs({ 1, 2, 3, 4 }) do
			joinCaptain(id)
			joinSkill(id)
		end
		assert.same({ 1, 4, 2, 3 }, captainOrder(1))
		assert.same({ 1, 2, 3, 4 }, skillOrder(1))
	end)
end)
