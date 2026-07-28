--- Give went through Spring.TransferUnit, whose AllowUnitTransfer asked the policy: an unallied (Gaia) hand-over was refused and the units attacked their new owner.
--- The announcement is a rulesparam, not an upvalue: VFS.Include is uncached, so the controller and the caller hold different copies of api.lua.

local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("transfer give — fiat", function()
	local params = {} ---@type table<string, integer>
	local getParam, setParam

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
		assert.is_true(TransferApi.MayTransfer(7, Spring.GetGaiaTeamID and Spring.GetGaiaTeamID() or 2, 0, false))
	end)

	it("and only while it is in flight", function()
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
		local duringMove = {}
		local savedTransfer = Spring.TransferUnit
		Spring.TransferUnit = function(unitID, toTeamID, given)
			duringMove[#duringMove + 1] =
				{ unitID = unitID, to = toTeamID, given = given, flag = params.isGiveInProgress }
			return true
		end
		local moved = registry.byName.give.execute({ to = 0, unitIDs = { 11, 12 } })
		Spring.TransferUnit = savedTransfer

		assert.are.equal(2, moved)
		assert.are.same({
			{ unitID = 11, to = 0, given = true, flag = 1 },
			{ unitID = 12, to = 0, given = true, flag = 1 },
		}, duringMove, "the flag must be up while the engine is asking")
		assert.are.equal(0, params.isGiveInProgress, "and down again once the move is done")
	end)
end)
