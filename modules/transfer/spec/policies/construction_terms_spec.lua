local ModuleHandler = VFS.Include("modules/module_handler.lua")
local Modules = VFS.Include("modules/enums.lua").Modules
local AssistTax = VFS.Include("modules/transfer/lib/assist_tax.lua")
local TransferEnums = VFS.Include("modules/transfer/enums.lua")

describe("transfer's gate on construction's build pipeline", function()
	it("sits on the pipeline, ahead of the terminal", function()
		local names = {}
		for i, stage in ipairs(ModuleHandler.LoadPolicies(Modules.Construction).build) do
			names[i] = stage.name
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
end)
