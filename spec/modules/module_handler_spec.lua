local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("ModuleHandler", function()
	describe("Register", function()
		local manifests

		setup(function()
			ModuleHandler.ResetCaches()
			manifests = ModuleHandler.Register()
		end)

		it("finds every directory that has a manifest, keyed by directory name", function()
			for _, dir in ipairs(VFS.SubDirs("modules/", "*")) do
				local name = dir:gsub("/+$", ""):match("([^/]+)$")
				if VFS.FileExists("modules/" .. name .. "/manifest.lua") then
					assert.is_table(
						manifests[name],
						"modules/" .. name .. "/manifest.lua exists but Register() did not load it"
					)
				end
			end
		end)

		it("skips directories that have no manifest", function()
			assert.is_nil(manifests.graphics)
			assert.is_nil(manifests.i18n)
		end)
	end)

	describe("Resolve", function()
		describe("a missing requirement", function()
			local function manifest(name, requires)
				return { name = name, dir = "modules/" .. name .. "/", requires = requires or {} }
			end

			it("reports an error for a module whose requirement is missing, and still loads the rest", function()
				local failures = {}
				local loadable = ModuleHandler.Resolve({
					base = manifest("base"),
					needy = manifest("needy", { "absent" }),
				}, function(message)
					failures[#failures + 1] = message
				end)
				assert.is_table(loadable.base)
				assert.is_nil(loadable.needy)
				assert.are.same({ 'Module "needy" requires missing module "absent"; not loaded' }, failures)
			end)

			it("doesn't load modules whose dependencies failed to load", function()
				local failures = {}
				local loadable = ModuleHandler.Resolve({
					needy = manifest("needy", { "absent" }),
					downstream = manifest("downstream", { "needy" }),
					bystander = manifest("bystander", { "downstream" }),
				}, function(message)
					failures[#failures + 1] = message
				end)
				assert.is_nil(loadable.needy)
				assert.is_nil(loadable.downstream)
				assert.is_nil(loadable.bystander)
				assert.are.equal(3, #failures)
			end)
		end)
	end)
end)
