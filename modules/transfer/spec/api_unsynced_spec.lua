local TransferEnums = require("modules/transfer/enums")

-- What a widget may ask of transfer in the unsynced handle: the terms for sharing with another team.
describe("transfer's unsynced api", function()
	local savedSpring

	before_each(function()
		savedSpring = _G.Spring
	end)

	after_each(function()
		---@diagnostic disable-next-line: global-in-non-module
		_G.Spring = savedSpring
	end)

	---@param modOptions table
	local function springWith(modOptions)
		---@diagnostic disable-next-line: global-in-non-module
		_G.Spring = setmetatable({
			GetMyTeamID = function()
				return 0
			end,
			GetModOptions = function()
				return modOptions
			end,
			GetTeamRulesParam = function()
				return nil
			end,
			AreTeamsAllied = function()
				return true
			end,
			IsCheatingEnabled = function()
				return false
			end,
		}, { __index = savedSpring })
	end

	it("says resources may not be shared when the mode denies it", function()
		springWith({ [TransferEnums.ModOptions.ResourceSharingEnabled] = "0" })
		local Unsynced = require("modules/transfer/api_unsynced")
		local terms = Unsynced.Resources.Terms(1, TransferEnums.ResourceType.METAL)
		assert.is_false(terms.canShare)
		assert.are.equal(TransferEnums.ResourceType.METAL, terms.resourceType)
	end)

	it("says units may not be shared when the mode shares none", function()
		springWith({ unit_sharing_mode = "none" })
		local Unsynced = require("modules/transfer/api_unsynced")
		local terms = Unsynced.Units.Terms(1)
		assert.is_false(terms.canShare)
	end)
end)
