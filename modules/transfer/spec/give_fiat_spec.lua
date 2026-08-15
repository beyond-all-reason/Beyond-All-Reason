--- Give's fiat, and the callin that used to quietly overrule it.
---
--- give.lua's whole contract is "no policy question asked": a mission handing
--- an outpost to the player is not a team choosing to share, and no mode gets
--- a say. But the move goes through Spring.TransferUnit, which fires
--- AllowUnitTransfer, which asks the sharing policy — so the bypass bypassed
--- nothing, and a hand-over from a team nobody is allied with (Gaia, or the
--- enemy seat a mission parked an enclave on) was refused as an unallied
--- share. The units stayed hostile and attacked the player they were meant
--- to be given to.
---
--- The announcement is a rulesparam and not an upvalue because VFS.Include is
--- uncached: the transfer controller and the caller hold different copies of
--- api.lua and cannot share a Lua flag. isTakeInProgress solves the same
--- problem the same way.

local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("transfer give — fiat", function()
	local params, getParam, setParam

	before_each(function()
		params = {}
		getParam, setParam = Spring.GetGameRulesParam, Spring.SetGameRulesParam
		Spring.GetGameRulesParam = function(name)
			return params[name]
		end
		Spring.SetGameRulesParam = function(name, value)
			params[name] = value
		end
	end)

	after_each(function()
		Spring.GetGameRulesParam, Spring.SetGameRulesParam = getParam, setParam
	end)

	it("the policy stands aside while a give is in flight", function()
		ModuleHandler.ResetCaches()
		local TransferApi = VFS.Include("modules/transfer/api.lua")
		params.isGiveInProgress = 1
		-- Gaia to the player: no alliance, so every policy answer is no. The
		-- only thing that can make this true is the announcement itself.
		assert.is_true(TransferApi.MayTransfer(7, Spring.GetGaiaTeamID and Spring.GetGaiaTeamID() or 2, 0, false))
	end)

	it("and only while it is in flight — this is the refusal that was the bug", function()
		ModuleHandler.ResetCaches()
		local TransferApi = VFS.Include("modules/transfer/api.lua")
		params.isGiveInProgress = 0

		local saved = { Spring.GetModOptions, Spring.AreTeamsAllied, Spring.GetTeamRulesParam }
		Spring.GetModOptions = function()
			return {}
		end
		Spring.AreTeamsAllied = function()
			return false
		end
		Spring.GetTeamRulesParam = function()
			return nil
		end

		local answer = TransferApi.MayTransfer(7, 2, 0, false)

		Spring.GetModOptions, Spring.AreTeamsAllied, Spring.GetTeamRulesParam = saved[1], saved[2], saved[3]

		assert.is_false(
			answer,
			"an ordinary unallied share is refused — which is correct, and is exactly why a give has to announce itself"
		)
	end)

	it("raises the announcement for the move and lowers it after", function()
		ModuleHandler.ResetCaches()
		local registry = ModuleHandler.LoadActions("transfer")
		local duringMove
		local moved = registry.byName.give.execute({
			to = 0,
			unitIDs = { 11, 12 },
			move = function(unitIDs)
				duringMove = params.isGiveInProgress
				return #unitIDs
			end,
		})
		assert.are.equal(2, moved)
		assert.are.equal(1, duringMove, "the flag must be up while the engine is asking")
		assert.are.equal(0, params.isGiveInProgress, "and down again once the move is done")
	end)
end)
