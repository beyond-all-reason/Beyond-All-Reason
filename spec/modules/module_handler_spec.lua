local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("ModuleHandler", function()
	describe("Discover", function()
		local manifests = ModuleHandler.Discover()

		it("finds the sharing module with its manifest", function()
			local sharing = manifests.sharing
			assert.is_table(sharing)
			assert.are.equal("sharing", sharing.name)
			assert.are.equal("modules/sharing/", sharing.dir)
			assert.are.equal("modules/sharing/api.lua", sharing.provides)
		end)

		it("finds the economy module and validates sharing's dependency on it", function()
			local economy = manifests.economy
			assert.is_table(economy)
			assert.are.equal("modules/economy/", economy.dir)
			assert.are.same({ "economy" }, manifests.sharing.requires)
		end)

		it("does not mistake plain shared-lib directories for modules", function()
			assert.is_nil(manifests.i18n)
			assert.is_nil(manifests.graphics)
			assert.is_nil(manifests.types)
		end)
	end)

	describe("LoadActions", function()
		local actions = ModuleHandler.LoadActions("sharing")

		it("auto-registers one action per file in actions/", function()
			assert.is_table(actions.byName.ResourceTransfer)
			assert.is_table(actions.byName.UnitTransfer)
			assert.are.equal("function", type(actions.byName.ResourceTransfer.execute))
		end)

		it("registers the action files themselves (include-once)", function()
			local Action = ModuleHandler.Include("modules/sharing/actions/resource_transfer.lua")
			assert.are.equal(Action.execute, actions.byName.ResourceTransfer.execute)
		end)

		it("returns an empty registry for unknown modules", function()
			local unknown = ModuleHandler.LoadActions("nope")
			assert.are.same({}, unknown.byName)
			assert.are.same({}, unknown.list)
		end)
	end)

	describe("ValidateActionArgs", function()
		local action = ModuleHandler.LoadActions("sharing").byName.ResourceTransfer

		it("accepts args matching the declared schema", function()
			assert.is_true(ModuleHandler.ValidateActionArgs(action, { ctx = {} }))
		end)

		it("rejects missing required parameters and type mismatches", function()
			assert.is_false(ModuleHandler.ValidateActionArgs(action, {}))
			assert.is_false(ModuleHandler.ValidateActionArgs(action, { ctx = "not a table" }))
		end)
	end)

	describe("LoadPolicies", function()
		local policies = ModuleHandler.LoadPolicies("sharing")

		it("loads categories from policies/ subdirectories", function()
			assert.is_table(policies.resource)
			assert.is_table(policies.unit)
		end)

		it("keeps pipeline declaration order with the compute terminal last", function()
			local names = {}
			for _, policy in ipairs(policies.resource) do
				names[#names + 1] = policy.name
			end
			assert.are.same({ "SharingEnabled", "AlliedOrNonPlayerSender", "ReceiverActive", "ComputeResourceTransfer" }, names)
			assert.are.equal("ComputeUnitPolicy", policies.unit[#policies.unit].name)
		end)

		it("stamps the category from the pipeline filename", function()
			assert.are.equal("resource", policies.resource[1].category)
			assert.are.equal("unit", policies.unit[1].category)
		end)
	end)

	describe("ModeDirs", function()
		it("surfaces module surrogate-mode directories", function()
			local dirs = ModuleHandler.ModeDirs()
			local found = false
			for _, dir in ipairs(dirs) do
				if dir:find("modules/sharing/modes/", 1, true) then
					found = true
				end
			end
			assert.is_true(found)
		end)
	end)

	describe("ModOptions", function()
		it("merges module modoption fragments (sharing section + options)", function()
			local options = ModuleHandler.ModOptions()
			local byKey = {}
			for _, option in ipairs(options) do
				byKey[option.key] = option
			end
			assert.is_table(byKey["sharing"])
			assert.are.equal("section", byKey["sharing"].type)
			assert.is_table(byKey["sharing_mode"])
		end)

		it("is pulled in by the game's modoptions.lua", function()
			local all = VFS.Include("modoptions.lua")
			local found = false
			for _, option in ipairs(all) do
				if option.key == "sharing_mode" then
					found = true
				end
			end
			assert.is_true(found)
		end)
	end)

	describe("Get", function()
		it("resolves the sharing contract lazily", function()
			local Sharing = ModuleHandler.Get("sharing")
			assert.is_table(Sharing)
			assert.is_table(Sharing.TransferEnums)
			local Economy = ModuleHandler.Get("economy")
			assert.is_table(Economy.ShareStats)
			assert.is_table(Economy.WaterfillSolver)
		end)
	end)
end)
