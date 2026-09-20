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

	describe("LiveModulesFor", function()
		-- One module on a fake VFS, so the spec stands on its own at every point in the stack:
		-- a manifest, a modoptions file with a <category>_mode option, and two presets.
		local FILES = {
			["modules/fixture/manifest.lua"] = function()
				return { name = "fixture" }
			end,
			["modules/fixture/modoptions.lua"] = function()
				return { { key = "fixture_mode", type = "list", def = "on" } }
			end,
			["modules/fixture/modes/on.lua"] = function()
				return { key = "on", category = "fixture" }
			end,
			["modules/fixture/modes/off.lua"] = function()
				return { key = "off", category = "fixture" }
			end,
		}
		local real = {}
		local includes

		setup(function()
			for _, fn in ipairs({ "SubDirs", "DirList", "FileExists", "Include" }) do
				real[fn] = VFS[fn]
			end
			VFS.SubDirs = function()
				return { "modules/fixture/" }
			end
			VFS.DirList = function(dir)
				local found = {}
				for path in pairs(FILES) do
					if path:sub(1, #dir) == dir and not path:sub(#dir + 1):find("/") then
						found[#found + 1] = path
					end
				end
				table.sort(found)
				return found
			end
			VFS.FileExists = function(path)
				return FILES[path] ~= nil
			end
			VFS.Include = function(path, ...)
				if FILES[path] then
					if path:match("/modoptions%.lua$") then
						includes = includes + 1
					end
					return FILES[path]()
				end
				return real.Include(path, ...)
			end
		end)

		teardown(function()
			for fn, original in pairs(real) do
				VFS[fn] = original
			end
			ModuleHandler.ResetCaches()
		end)

		before_each(function()
			includes = 0
			ModuleHandler.ResetCaches()
		end)

		it("reads the modoptions files once: the live set for a selection is the same table each ask", function()
			local first = ModuleHandler.LiveModulesFor({})
			local afterFirst = includes
			local second = ModuleHandler.LiveModulesFor({})
			local third = ModuleHandler.LiveModulesFor({ fixture_mode = "off" })
			assert.is_true(afterFirst > 0, "the first ask reads the modoptions files")
			assert.are.equal(afterFirst, includes, "later asks read nothing")
			assert.is_true(rawequal(first, second))
			assert.is_false(rawequal(first, third), "a different selection is its own live set")
			assert.are.same({ fixture = true }, first)
		end)

		it("forgets both on ResetCaches", function()
			local before = ModuleHandler.LiveModulesFor({})
			ModuleHandler.ResetCaches()
			assert.is_false(rawequal(before, ModuleHandler.LiveModulesFor({})))
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
