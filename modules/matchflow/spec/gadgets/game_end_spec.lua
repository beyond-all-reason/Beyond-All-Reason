
local realVFS = VFS

local GADGET = "modules/matchflow/gadgets/game_end.lua"

---@param opts { modOptions: table?, ceremonyStarted: boolean?, verdict: table? }
local function newGadget(opts)
	opts = opts or {}
	local h = { log = {}, gameOver = {}, ceremonyFrames = {}, begun = nil }

	local ceremony = {
		IsStarted = function()
			return opts.ceremonyStarted == true
		end,
		GameFrame = function(gf)
			h.ceremonyFrames[#h.ceremonyFrames + 1] = gf
		end,
		Begin = function(winners, gf)
			h.begun = { winners = winners, frame = gf }
			opts.ceremonyStarted = true
		end,
	}

	local moduleHandler = {
		LoadPolicies = function()
			return { game_over = {} }
		end,
		Evaluate = function(_pipeline, ctx)
			h.lastCtx = { scriptedWinners = ctx.scriptedWinners }
			return opts.verdict
		end,
	}

	local env = {}
	local gadgetTable = {}

	local vfs = setmetatable({
		Include = function(path, fileEnv)
			if path == "modules/module_handler.lua" then
				return moduleHandler
			end
			if path == "modules/matchflow/lib/ceremony.lua" then
				return {
					New = function()
						return ceremony
					end,
				}
			end
			return realVFS.Include(path, fileEnv)
		end,
	}, { __index = realVFS })

	env.VFS = vfs
	env.gadget = gadgetTable
	env.GG = {}
	env.Game = { gameSpeed = 30 }
	env.UnitDefs = {}
	env.CMD = setmetatable({}, {
		__index = function()
			return 0
		end,
	})
	env.LOG = { INFO = "info", WARNING = "warning", ERROR = "error" }
	env.SendToUnsynced = function() end
	env.gadgetHandler = {
		IsSyncedCode = function()
			return true
		end,
		RemoveGadget = function()
			h.removed = true
		end,
	}
	env.Spring = setmetatable({
		GetModOptions = function()
			return opts.modOptions or { deathmode = "neverend" }
		end,
		GetTeamList = function()
			return { 0, 1 }
		end,
		GetAllyTeamList = function()
			return { 0, 1, 2 }
		end,
		GetGaiaTeamID = function()
			return 2
		end,
		GetGameFrame = function()
			return 0
		end,
		GameOver = function(winners)
			h.gameOver[#h.gameOver + 1] = winners
		end,
		Log = function(tag, level, message)
			h.log[#h.log + 1] = { tag = tag, level = level, message = message }
		end,
		Echo = function() end,
		AreTeamsAllied = function()
			return false
		end,
		-- Indexed, not called: the fallback below hands back functions.
		UnitScript = { GetScriptEnv = function() end, CallAsUnit = function() end },
	}, {
		__index = function()
			return function() end
		end,
	})
	-- The gadget reads BAR.Utilities, so the stub belongs on BAR, not GG.
	env.BAR = {
		Utilities = { Gametype = {
			IsFFA = function()
				return false
			end,
		} },
	}

	env._G = env
	setmetatable(env, { __index = _G })

	local chunk = assert(loadfile(GADGET))
	setfenv(chunk, env)
	chunk()

	h.gadget = gadgetTable
	h.env = env
	return h
end

---@param log table[]
---@param needle string
---@return boolean
local function logged(log, needle)
	for _, entry in ipairs(log) do
		if tostring(entry.message):find(needle, 1, true) then
			return true
		end
	end
	return false
end

describe("game end gadget", function()
	describe("the MatchFlow surface after the gadget retires", function()
		it("leaves a surface behind, so a late caller is not an assert", function()
			local h = newGadget({})
			h.gadget:Initialize()
			assert.is_table(h.env.GG.MatchFlow)

			h.gadget:Shutdown()
			assert.is_table(h.env.GG.MatchFlow)
			assert.has_no.errors(function()
				h.env.GG.MatchFlow.Victory(0)
			end)
			assert.has_no.errors(function()
				h.env.GG.MatchFlow.Defeat({ 1 })
			end)
		end)

		it("says a late verdict was ignored rather than swallowing it", function()
			local h = newGadget({})
			h.gadget:Initialize()
			h.gadget:Shutdown()
			h.env.GG.MatchFlow.Victory(0)
			assert.is_true(logged(h.log, "after the match ended"))
		end)

		it("still ends the match while the gadget is live", function()
			local h = newGadget({ verdict = { winners = { 0 } } })
			h.gadget:Initialize()
			h.env.GG.MatchFlow.Victory(0)
			h.gadget:GameFrame(30)
			assert.are.same({ winners = { 0 }, frame = 30 }, h.begun)
		end)
	end)

	describe("a verdict that arrives after the ceremony began", function()
		it("does not override the outcome already running", function()
			local h = newGadget({ ceremonyStarted = true, verdict = { winners = { 1 } } })
			h.gadget:Initialize()
			h.env.GG.MatchFlow.Victory(0)
			h.gadget:GameFrame(60)
			assert.are.same({ 60 }, h.ceremonyFrames)
			assert.is_nil(h.lastCtx)
			assert.is_nil(h.begun)
		end)

		it("logs the drop, so a lost mission defeat is not silent", function()
			local h = newGadget({ ceremonyStarted = true })
			h.gadget:Initialize()
			h.env.GG.MatchFlow.Victory(0)
			h.gadget:GameFrame(60)
			assert.is_true(logged(h.log, "after the ceremony began"))
		end)

		it("only says so once, not on every frame of the ceremony", function()
			local h = newGadget({ ceremonyStarted = true })
			h.gadget:Initialize()
			h.env.GG.MatchFlow.Victory(0)
			h.gadget:GameFrame(60)
			h.gadget:GameFrame(61)
			local count = 0
			for _, entry in ipairs(h.log) do
				if tostring(entry.message):find("after the ceremony began", 1, true) then
					count = count + 1
				end
			end
			assert.are.equal(1, count)
		end)
	end)
end)
