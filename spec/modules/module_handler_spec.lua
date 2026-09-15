local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("ModuleHandler", function()
	describe("Discover", function()
		local manifests

		setup(function()
			ModuleHandler.ResetCaches()
			manifests = ModuleHandler.Discover()
		end)

		it("every directory that ships a manifest is discovered under its own name", function()
			for _, dir in ipairs(VFS.SubDirs("modules/", "*")) do
				local name = dir:gsub("/+$", ""):match("([^/]+)$")
				if VFS.FileExists("modules/" .. name .. "/manifest.lua") then
					assert.is_table(
						manifests[name],
						"modules/" .. name .. "/manifest.lua exists but Discover() did not load it"
					)
				end
			end
		end)

		it("skips directories that ship no manifest", function()
			assert.is_nil(manifests.graphics)
			assert.is_nil(manifests.i18n)
		end)

		it("every declared requirement resolves to a discovered module", function()
			for name, manifest in pairs(manifests) do
				for _, required in ipairs(manifest.requires or {}) do
					assert.is_table(manifests[required], name .. " requires missing module " .. required)
				end
			end
		end)
	end)

	describe("Resolve", function()
		describe("a missing requirement", function()
			local function manifest(name, requires)
				return { name = name, dir = "modules/" .. name .. "/", requires = requires or {} }
			end

			it("refuses the module and names both, and loads the rest", function()
				local refused = {}
				local loadable = ModuleHandler.Resolve({
					base = manifest("base"),
					needy = manifest("needy", { "absent" }),
				}, function(message)
					refused[#refused + 1] = message
				end)
				assert.is_table(loadable.base)
				assert.is_nil(loadable.needy)
				assert.are.same({ 'Module "needy" requires missing module "absent"; not loaded' }, refused)
			end)

			it("refuses whatever required the refused module, in turn", function()
				local refused = {}
				local loadable = ModuleHandler.Resolve({
					needy = manifest("needy", { "absent" }),
					downstream = manifest("downstream", { "needy" }),
					bystander = manifest("bystander", { "downstream" }),
				}, function(message)
					refused[#refused + 1] = message
				end)
				assert.is_nil(loadable.needy)
				assert.is_nil(loadable.downstream)
				assert.is_nil(loadable.bystander)
				assert.are.equal(3, #refused)
			end)
		end)
	end)
end)
