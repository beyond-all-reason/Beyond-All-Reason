local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("module manifests", function()
	local manifests

	setup(function()
		ModuleHandler.ResetCaches()
		manifests = ModuleHandler.Discover()
	end)

	it("every directory that ships a manifest is discovered under its own name", function()
		-- a manifest the loader refuses is a module that silently vanishes from the game
		for _, dir in ipairs(VFS.SubDirs("modules/", "*")) do
			local name = dir:gsub("/+$", ""):match("([^/]+)$")
			if VFS.FileExists("modules/" .. name .. "/module.lua") then
				assert.is_table(
					manifests[name],
					"modules/" .. name .. "/module.lua exists but Discover() did not load it"
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
