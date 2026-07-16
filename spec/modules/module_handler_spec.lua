local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("ModuleHandler", function()
	describe("Discover", function()
		local manifests = ModuleHandler.Discover()

		it("finds the sharing module with its manifest", function()
			local sharing = manifests.sharing
			assert.is_table(sharing)
			assert.are.equal("sharing", sharing.name)
			assert.are.equal("modules/sharing/", sharing.dir)
			assert.are.equal("modules/sharing/api.lua", sharing.provides.shared)
			assert.are.equal("modules/sharing/api_unsynced.lua", sharing.provides.unsynced)
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

		it("registers one action per file, identity from the filename", function()
			assert.is_table(actions.byName.resource_transfer)
			assert.is_table(actions.byName.unit_transfer)
			assert.are.equal("function", type(actions.byName.resource_transfer.execute))
		end)

		it("collects the optional validate precondition (before execute)", function()
			assert.are.equal("function", type(actions.byName.unit_transfer.validate))
			assert.is_nil(actions.byName.resource_transfer.validate)
		end)

		it("memoizes the registry per handler instance", function()
			assert.are.equal(actions, ModuleHandler.LoadActions("sharing"))
		end)

		it("returns an empty registry for unknown modules", function()
			local unknown = ModuleHandler.LoadActions("nope")
			assert.are.same({}, unknown.byName)
			assert.are.same({}, unknown.list)
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
		it("merges shared + unsynced contracts (busted runs unsynced)", function()
			local Sharing = ModuleHandler.Get("sharing")
			assert.is_table(Sharing.Enums) -- shared
			assert.is_table(Sharing.Take)
			assert.is_table(Sharing.Resources) -- unsynced overlay
			assert.are.equal("function", type(Sharing.Units.ShareUnits))
			assert.is_table(Sharing.PolicyViews.Helpers)
		end)

		it("omits unsynced keys from the synced view", function()
			---@diagnostic disable-next-line: global-in-non-module -- simulating the synced state
			_G.SendToUnsynced = function() end
			ModuleHandler.ResetCaches()
			local Sharing = ModuleHandler.Get("sharing")
			assert.is_table(Sharing.Enums)
			assert.is_table(Sharing.Units)
			assert.is_nil(Sharing.Resources)
			assert.is_nil(Sharing.PolicyViews)
			_G.SendToUnsynced = nil
			ModuleHandler.ResetCaches()
		end)

		it("keeps plain-path provides state-agnostic (economy)", function()
			local Economy = ModuleHandler.Get("economy")
			assert.is_table(Economy.ShareStats)
			assert.is_table(Economy.WaterfillSolver)
		end)
	end)
end)
