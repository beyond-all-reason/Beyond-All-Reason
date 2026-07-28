local AssistTax = require("modules/transfer/lib/assist_tax")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local TransferEnums = require("modules/transfer/enums")

describe("a build step an ally helps with", function()
	it("is refused by a step of transfer's on construction's build policy, ahead of its answer", function()
		local names = {}
		for i, step in ipairs(ModuleHandler.Steps(ModuleHandler.Contract(Modules.Construction).Build)) do
			names[i] = step.name
		end
		assert.are.same({ "BuilderDelayed", "UnaffordableAssistTax", "Allowed" }, names)
	end)

	describe("the quote", function()
		local opts = { [TransferEnums.ModOptions.TaxResourceSharingAmount] = 0.5 }
		---@param metal number
		---@param energy number
		---@param modOptions table? defaults to the taxed opts
		local function repo(metal, energy, modOptions)
			return {
				GetUnitIsBeingBuilt = function()
					return true
				end,
				GetUnitTeam = function()
					return 1
				end,
				AreTeamsAllied = function()
					return true
				end,
				GetTeamResources = function(_, resource)
					return resource == "metal" and metal or energy
				end,
				GetTeamRulesParam = function()
					return nil
				end,
				GetModOptions = function()
					return modOptions or opts
				end,
			}
		end
		local step = { builderID = 5, builderTeam = 0, delayed = false, unitID = 9, unitDefID = 1, part = 0.1 }

		before_each(function()
			---@diagnostic disable-next-line: global-in-non-module
			_G.UnitDefs = { [1] = { metalCost = 1000, energyCost = 200 } }
			AssistTax = require("modules/transfer/lib/assist_tax") -- imports UnitDefs when it loads
		end)

		after_each(function()
			---@diagnostic disable-next-line: global-in-non-module
			_G.UnitDefs = nil
		end)

		it("taxes an ally's step at the configured rate, and knows when the helper cannot pay", function()
			local quote = AssistTax.Quote(step, repo(1000, 1000))
			assert.are.equal(50, quote.metalTax)
			assert.are.equal(10, quote.energyTax)
			assert.is_true(quote.affordable)
			assert.is_false(AssistTax.Quote(step, repo(100, 1000)).affordable)
		end)

		it("charges nothing on your own unit or with no tax configured", function()
			local own = repo(1000, 1000)
			own.GetUnitTeam = function()
				return 0
			end
			assert.is_nil(AssistTax.Quote(step, own))
			assert.is_nil(AssistTax.Quote(step, repo(1000, 1000, {})))
		end)
	end)

	describe("utility sharing, the fact transfer provides construction", function()
		it("comes from the unit sharing mode: true when the mode lets utility buildings change hands", function()
			local Contract = ModuleHandler.Contract(Modules.Construction)
			local resolved = ModuleHandler.LoadEnrichers(Contract.PlacementFacts)
			local function sharing(mode)
				local ctx =
					{ unitDefID = 7, builderTeam = 0, x = 0, y = 0, z = 0, modOptions = { unit_sharing_mode = mode } }
				return ModuleHandler.EnrichWith(resolved, nil, ctx)[Contract.PlacementFacts.UtilitySharing]
			end
			assert.is_true(sharing("all"))
			assert.is_false(sharing("none"))
			assert.is_false(sharing(nil))
		end)
	end)
end)
